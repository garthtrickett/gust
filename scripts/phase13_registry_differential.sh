#!/usr/bin/env bash
set -euo pipefail

requested_family="${1:-all}"
registry_json="scripts/cranelift_feature_registry.json"
family_runner="scripts/cranelift_ci_family.py"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
build_root="build/guards/cranelift_phase13_registry_differential/${requested_family}"
cargo_target="$build_root/cargo-target"

if [ "$requested_family" != "all" ]; then
  python3 "$family_runner" validate-family "$requested_family" >/dev/null
fi

for required_file in \
  "$registry_json" "$family_runner" "$rust_manifest" \
  src/runtime.c ./gust
do
  if [ ! -e "$required_file" ]; then
    echo "Registry differential harness is missing $required_file" >&2
    exit 1
  fi
done
if [ ! -x ./gust ]; then
  echo "Registry differential harness requires the rebuilt ./gust compiler." >&2
  exit 1
fi

rm -rf "$build_root"
mkdir -p "$build_root"

CARGO_TARGET_DIR="$cargo_target" cargo build \
  --locked \
  --quiet \
  --manifest-path "$rust_manifest"
driver_bin="$cargo_target/debug/gust-cranelift-experiment"
if [ ! -x "$driver_bin" ]; then
  echo "Registry differential harness did not build $driver_bin" >&2
  exit 1
fi
driver_abs="$(cd "$(dirname "$driver_bin")" && pwd)/$(basename "$driver_bin")"
CC_BIN="${CC:-cc}"
CFLAGS_VAL="${CFLAGS:--O0 -w -pthread}"

execute_and_capture() {
  local binary="$1"
  local prefix="$2"
  local workdir="$3"
  local binary_abs
  binary_abs="$(cd "$(dirname "$binary")" && pwd)/$(basename "$binary")"
  mkdir -p "$workdir"
  set +e
  (
    cd "$workdir"
    "$binary_abs"
  ) >"$prefix.stdout" 2>"$prefix.stderr"
  local status="$?"
  set -e
  printf '%s\n' "$status" >"$prefix.status"
}

assert_side_effects() {
  local policy="$1"
  local mir_workdir="$2"
  local native_workdir="$3"
  local context="$4"
  case "$policy" in
    none)
      if find "$mir_workdir" -mindepth 1 -print -quit | grep -q . ||
         find "$native_workdir" -mindepth 1 -print -quit | grep -q .
      then
        echo "❌ Registry differential failure [$context]: undeclared side effects were produced" >&2
        find "$mir_workdir" "$native_workdir" -mindepth 1 -print >&2
        exit 1
      fi
      ;;
    compare_tree)
      if ! diff -ru "$mir_workdir" "$native_workdir" >/dev/null; then
        diff -ru "$mir_workdir" "$native_workdir" >&2 || true
        echo "❌ Registry differential failure [$context]: declared side-effect trees differ" >&2
        exit 1
      fi
      ;;
    *)
      echo "❌ Registry differential failure [$context]: unknown side-effect policy $policy" >&2
      exit 1
      ;;
  esac
}

case_count=0
individual_count=0
composition_count=0
while IFS=$'\t' read -r \
  case_id case_kind owner_entry_id ci_family source_fixture failure_fixture \
  positive_expectation stderr_policy side_effect_policy related_entry_ids
do
  case_count=$((case_count + 1))
  case "$case_kind" in
    individual) individual_count=$((individual_count + 1)) ;;
    composition) composition_count=$((composition_count + 1)) ;;
    *)
      echo "Unknown registry differential case kind: $case_kind" >&2
      exit 1
      ;;
  esac

  context="case=$case_id kind=$case_kind owner=$owner_entry_id ci_family=$ci_family related=$related_entry_ids source=$source_fixture"

  fail_case() {
    echo "❌ Registry differential failure [$context]: $*" >&2
    exit 1
  }

  if [ -z "$case_id" ] || [ -z "$owner_entry_id" ] ||
     [ -z "$ci_family" ] || [ -z "$positive_expectation" ] ||
     [ ! -f "$source_fixture" ] || [ ! -f "$failure_fixture" ]; then
    fail_case "registry fields or fixtures are incomplete"
  fi

  safe_case_id="$(printf '%s' "$case_id" | tr ':/' '__')"
  case_dir="$build_root/$safe_case_id"
  mkdir -p "$case_dir"

  if ! ./gust --backend c "$source_fixture" \
      >"$case_dir/default.c" \
      2>"$case_dir/default.compiler.stderr"; then
    cat "$case_dir/default.compiler.stderr" >&2
    fail_case "C-alias MIR-to-C compilation failed"
  fi
  if ! ./gust --backend mir-to-c "$source_fixture" \
      >"$case_dir/explicit.c" \
      2>"$case_dir/explicit.compiler.stderr"; then
    cat "$case_dir/explicit.compiler.stderr" >&2
    fail_case "explicit MIR-to-C compilation failed"
  fi
  if [ -s "$case_dir/default.compiler.stderr" ] ||
     [ -s "$case_dir/explicit.compiler.stderr" ]; then
    cat "$case_dir/default.compiler.stderr" \
        "$case_dir/explicit.compiler.stderr" >&2
    fail_case "successful MIR-to-C compilation emitted diagnostics"
  fi
  if ! cmp -s "$case_dir/default.c" "$case_dir/explicit.c"; then
    diff -u "$case_dir/default.c" "$case_dir/explicit.c" >&2 || true
    fail_case "both explicit MIR-to-C spellings are not byte-identical"
  fi

  cat src/runtime.c "$case_dir/default.c" >"$case_dir/mir-to-c.final.c"
  if ! "$CC_BIN" $CFLAGS_VAL -Isrc \
      "$case_dir/mir-to-c.final.c" \
      -o "$case_dir/mir-to-c-program"; then
    fail_case "emitted C did not build"
  fi
  execute_and_capture \
    "$case_dir/mir-to-c-program" \
    "$case_dir/mir-to-c" \
    "$case_dir/mir-workdir"

  if ! GUST_NATIVE_BACKEND_DRIVER="$driver_abs" \
      ./gust --backend cranelift \
        -o "$case_dir/native-program" \
        "$source_fixture" \
        >"$case_dir/native.compiler.stdout" \
        2>"$case_dir/native.compiler.stderr"; then
    cat "$case_dir/native.compiler.stdout" \
        "$case_dir/native.compiler.stderr" >&2
    fail_case "explicit Cranelift compilation failed"
  fi
  if [ -s "$case_dir/native.compiler.stdout" ] ||
     [ -s "$case_dir/native.compiler.stderr" ]; then
    cat "$case_dir/native.compiler.stdout" \
        "$case_dir/native.compiler.stderr" >&2
    fail_case "successful Cranelift compilation emitted diagnostics"
  fi
  if [ ! -x "$case_dir/native-program" ]; then
    fail_case "Cranelift did not publish an executable"
  fi
  execute_and_capture \
    "$case_dir/native-program" \
    "$case_dir/native" \
    "$case_dir/native-workdir"

  mir_status="$(cat "$case_dir/mir-to-c.status")"
  native_status="$(cat "$case_dir/native.status")"
  if [ "$mir_status" != "$native_status" ]; then
    fail_case "exit status differs: MIR-to-C=$mir_status Cranelift=$native_status"
  fi
  if [[ "$positive_expectation" =~ ^exit_([0-9]+)_ ]]; then
    expected_status="${BASH_REMATCH[1]}"
    if [ "$mir_status" != "$expected_status" ]; then
      fail_case "exit status $mir_status does not match registry expectation $expected_status"
    fi
  else
    fail_case "registry expectation does not declare an exit status"
  fi
  if ! cmp -s "$case_dir/mir-to-c.stdout" "$case_dir/native.stdout"; then
    diff -u "$case_dir/mir-to-c.stdout" "$case_dir/native.stdout" >&2 || true
    fail_case "runtime stdout bytes differ"
  fi
  case "$stderr_policy" in
    stable_bytes)
      if ! cmp -s "$case_dir/mir-to-c.stderr" "$case_dir/native.stderr"; then
        diff -u "$case_dir/mir-to-c.stderr" "$case_dir/native.stderr" >&2 || true
        fail_case "runtime stderr bytes differ"
      fi
      ;;
    ignored) ;;
    *) fail_case "unknown stderr policy $stderr_policy" ;;
  esac
  assert_side_effects \
    "$side_effect_policy" \
    "$case_dir/mir-workdir" \
    "$case_dir/native-workdir" \
    "$context"

  if [ -e "$case_dir/native-program.phase10.bundle" ] ||
     [ -e "$case_dir/native-program.phase10.request" ]; then
    fail_case "successful native compilation left transient request artifacts"
  fi

  protected_output="$case_dir/existing-output"
  printf 'phase13-registry-differential-output-sentinel\n' >"$protected_output"
  cp "$protected_output" "$protected_output.expected"
  missing_driver="/phase13/missing/registry-differential-driver"
  set +e
  GUST_NATIVE_BACKEND_DRIVER="$missing_driver" \
    ./gust --backend cranelift \
      -o "$protected_output" \
      "$failure_fixture" \
      >"$case_dir/failure.compiler.stdout" \
      2>"$case_dir/failure.compiler.stderr"
  failure_status="$?"
  set -e
  if [ "$failure_status" = "0" ]; then
    fail_case "failure probe unexpectedly compiled natively"
  fi
  if ! cmp -s "$protected_output.expected" "$protected_output"; then
    fail_case "failed native compilation changed the existing output"
  fi
  cat "$case_dir/failure.compiler.stdout" \
      "$case_dir/failure.compiler.stderr" \
      >"$case_dir/failure.compiler.combined"
  if rg -n -F "$missing_driver" "$case_dir/failure.compiler.combined" >/dev/null ||
     rg -n -F 'Native backend driver discovery error:' \
       "$case_dir/failure.compiler.combined" >/dev/null; then
    cat "$case_dir/failure.compiler.combined" >&2
    fail_case "deferred, invalid, or unsupported source reached driver discovery"
  fi
  if [ -e "$protected_output.phase10.bundle" ] ||
     [ -e "$protected_output.phase10.request" ]; then
    fail_case "failed native compilation left transient request artifacts"
  fi

  echo "✅ Registry differential case passed [$context]"
done < <(
  python3 "$family_runner" differential-cases "$requested_family"
)

if [ "$case_count" = "0" ] || [ "$individual_count" = "0" ]; then
  echo "Registry differential family $requested_family selected incomplete evidence." >&2
  exit 1
fi
if [ "$requested_family" != "all" ] && [ "$composition_count" = "0" ]; then
  echo "Registry differential family $requested_family selected no composition case." >&2
  exit 1
fi

echo "✅ Phase 13 registry differential harness passed: family=$requested_family cases=$case_count individual=$individual_count composition=$composition_count"
