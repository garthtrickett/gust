#!/usr/bin/env bash
set -euo pipefail

requested_family="${1:-all}"
registry_json="scripts/cranelift_feature_registry.json"
family_runner="scripts/cranelift_ci_family.py"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
route_deferred_fixture="compiler/phase13_scalar_unsupported_divide_source.gst"
build_root="build/guards/cranelift_phase11_registry_differential/${requested_family}"
cargo_target="$build_root/cargo-target"

if [ "$requested_family" != "all" ]; then
  python3 "$family_runner" validate-family "$requested_family" >/dev/null
fi

for required_file in \
  "$registry_json" "$family_runner" "$rust_manifest" \
  "$route_deferred_fixture" src/runtime.c ./gust
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
  set +e
  "$binary" >"$prefix.stdout" 2>"$prefix.stderr"
  local status="$?"
  set -e
  printf '%s\n' "$status" >"$prefix.status"
}

entry_count=0
while IFS=$'\t' read -r \
  id route_owner ci_family source_fixture deferred_fixture positive_expectation
do
  entry_count=$((entry_count + 1))
  context="parity_entry=$id ci_family=$ci_family source=$source_fixture"

  fail_entry() {
    echo "❌ Registry differential failure [$context]: $*" >&2
    exit 1
  }

  if [ -z "$id" ] || [ -z "$ci_family" ] ||
     [ -z "$deferred_fixture" ] || [ ! -f "$source_fixture" ]; then
    fail_entry "registry fields or supported source fixture are incomplete"
  fi
  case "$deferred_fixture" in
    none|none_*) ;;
    *)
      if [ ! -f "$deferred_fixture" ]; then
        fail_entry "registry deferred fixture is missing: $deferred_fixture"
      fi
      ;;
  esac

  case_dir="$build_root/$id"
  mkdir -p "$case_dir"

  if ! ./gust "$source_fixture" \
      >"$case_dir/default.c" \
      2>"$case_dir/default.compiler.stderr"; then
    cat "$case_dir/default.compiler.stderr" >&2
    fail_entry "default MIR-to-C compilation failed"
  fi
  if ! ./gust --backend mir-to-c "$source_fixture" \
      >"$case_dir/explicit.c" \
      2>"$case_dir/explicit.compiler.stderr"; then
    cat "$case_dir/explicit.compiler.stderr" >&2
    fail_entry "explicit MIR-to-C compilation failed"
  fi
  if [ -s "$case_dir/default.compiler.stderr" ] ||
     [ -s "$case_dir/explicit.compiler.stderr" ]; then
    cat "$case_dir/default.compiler.stderr" \
        "$case_dir/explicit.compiler.stderr" >&2
    fail_entry "successful MIR-to-C compilation emitted diagnostics"
  fi
  if ! cmp -s "$case_dir/default.c" "$case_dir/explicit.c"; then
    diff -u "$case_dir/default.c" "$case_dir/explicit.c" >&2 || true
    fail_entry "default and explicit MIR-to-C output are not byte-identical"
  fi

  cat src/runtime.c "$case_dir/default.c" >"$case_dir/mir-to-c.final.c"
  if ! "$CC_BIN" $CFLAGS_VAL -Isrc \
      "$case_dir/mir-to-c.final.c" \
      -o "$case_dir/mir-to-c-program"; then
    fail_entry "emitted C did not build"
  fi
  execute_and_capture \
    "$case_dir/mir-to-c-program" \
    "$case_dir/mir-to-c"

  if ! GUST_NATIVE_BACKEND_DRIVER="$driver_abs" \
      ./gust --backend cranelift \
        -o "$case_dir/native-program" \
        "$source_fixture" \
        >"$case_dir/native.compiler.stdout" \
        2>"$case_dir/native.compiler.stderr"; then
    cat "$case_dir/native.compiler.stdout" \
        "$case_dir/native.compiler.stderr" >&2
    fail_entry "explicit Cranelift compilation failed"
  fi
  if [ -s "$case_dir/native.compiler.stdout" ] ||
     [ -s "$case_dir/native.compiler.stderr" ]; then
    cat "$case_dir/native.compiler.stdout" \
        "$case_dir/native.compiler.stderr" >&2
    fail_entry "successful Cranelift compilation emitted diagnostics"
  fi
  if [ ! -x "$case_dir/native-program" ]; then
    fail_entry "Cranelift did not publish an executable"
  fi
  execute_and_capture \
    "$case_dir/native-program" \
    "$case_dir/native"

  mir_status="$(cat "$case_dir/mir-to-c.status")"
  native_status="$(cat "$case_dir/native.status")"
  if [ "$mir_status" != "$native_status" ]; then
    fail_entry "exit status differs: MIR-to-C=$mir_status Cranelift=$native_status"
  fi
  if [[ "$positive_expectation" =~ ^exit_([0-9]+)_ ]]; then
    expected_status="${BASH_REMATCH[1]}"
    if [ "$mir_status" != "$expected_status" ]; then
      fail_entry "exit status $mir_status does not match registry expectation $expected_status"
    fi
  fi
  if ! cmp -s "$case_dir/mir-to-c.stdout" "$case_dir/native.stdout"; then
    diff -u "$case_dir/mir-to-c.stdout" "$case_dir/native.stdout" >&2 || true
    fail_entry "runtime stdout bytes differ"
  fi
  if ! cmp -s "$case_dir/mir-to-c.stderr" "$case_dir/native.stderr"; then
    diff -u "$case_dir/mir-to-c.stderr" "$case_dir/native.stderr" >&2 || true
    fail_entry "runtime stderr bytes differ"
  fi
  if [ -e "$case_dir/native-program.phase10.bundle" ] ||
     [ -e "$case_dir/native-program.phase10.request" ]; then
    fail_entry "successful native compilation left transient request artifacts"
  fi

  protected_output="$case_dir/existing-output"
  printf 'phase11-route-retirement-output-sentinel\n' >"$protected_output"
  cp "$protected_output" "$protected_output.expected"
  missing_driver="/phase11/missing/registry-differential-driver"
  set +e
  GUST_NATIVE_BACKEND_DRIVER="$missing_driver" \
    ./gust --backend cranelift \
      -o "$protected_output" \
      "$route_deferred_fixture" \
      >"$case_dir/deferred.compiler.stdout" \
      2>"$case_dir/deferred.compiler.stderr"
  deferred_status="$?"
  set -e
  if [ "$deferred_status" = "0" ]; then
    fail_entry "route-deferred probe unexpectedly compiled natively"
  fi
  if ! cmp -s "$protected_output.expected" "$protected_output"; then
    fail_entry "failed native compilation changed the existing output"
  fi
  cat "$case_dir/deferred.compiler.stdout" \
      "$case_dir/deferred.compiler.stderr" \
      >"$case_dir/deferred.compiler.combined"
  if rg -n -F "$missing_driver" "$case_dir/deferred.compiler.combined" >/dev/null ||
     rg -n -F 'Native backend driver discovery error:' \
       "$case_dir/deferred.compiler.combined" >/dev/null; then
    cat "$case_dir/deferred.compiler.combined" >&2
    fail_entry "deferred or unsupported source reached driver discovery"
  fi
  if [ -e "$protected_output.phase10.bundle" ] ||
     [ -e "$protected_output.phase10.request" ]; then
    fail_entry "failed native compilation left transient request artifacts"
  fi

  echo "✅ Registry differential entry passed [$context]"
done < <(
  python3 "$family_runner" differential-rows "$requested_family"
)

if [ "$entry_count" = "0" ]; then
  echo "Registry differential family $requested_family selected no migrated registry entries." >&2
  exit 1
fi

echo "✅ Registry differential harness passed: family=$requested_family entries=$entry_count"
