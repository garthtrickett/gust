#!/usr/bin/env bash
set -euo pipefail

validator="scripts/cranelift_registry.py"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
build_root="build/guards/phase14_integer_conversion"
cargo_target="$build_root/cargo-target"
all_targets="${PHASE14_INTEGER_CONVERSION_ALL_TARGETS:-${PHASE14_ALL_TARGETS:-0}}"

for required_file in \
  "$validator" "$rust_manifest" \
  compiler/mir_integer_conversion.gst \
  compiler/mir_integer_conversion_mir_to_c.gst \
  compiler/mir_integer_conversion_smoke_test_entry.gst \
  ./gust
do
  if [ ! -e "$required_file" ]; then
    echo "Phase 14 integer conversion differential is missing $required_file" >&2
    exit 1
  fi
done
if [ ! -x ./gust ]; then
  echo "Phase 14 integer conversion differential requires the rebuilt ./gust compiler." >&2
  exit 1
fi

rm -rf "$build_root"
mkdir -p "$build_root"
while IFS= read -r target; do
  [ -n "$target" ] || continue
  mkdir -p "$build_root/$target"
done < <(python3 "$validator" phase14-conversion-targets)

just guard compiler/mir_integer_conversion_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 14 signed unsigned and width conversion rules' to.log >/dev/null

CARGO_TARGET_DIR="$cargo_target" cargo build \
  --locked \
  --quiet \
  --manifest-path "$rust_manifest"
driver="$cargo_target/debug/gust-cranelift-experiment"
if [ ! -x "$driver" ]; then
  echo "Phase 14 integer conversion differential did not build $driver" >&2
  exit 1
fi

source scripts/phase14_target_selection.sh
phase14_select_targets \
  "$validator" \
  "phase14-conversion-targets" \
  "phase14-conversion-primary-target" \
  "$all_targets"
if [ "${#targets[@]}" = "0" ]; then
  echo "Phase 14 integer conversion differential selected no targets." >&2
  exit 1
fi

expect_worker_failure() {
  local request_path="$1"
  local context="$2"
  local stdout_path="$3"
  local stderr_path="$4"
  set +e
  "$driver" phase14-integer-conversion-witness "$request_path" \
    >"$stdout_path" 2>"$stderr_path"
  local status="$?"
  set -e
  if [ "$status" = "0" ]; then
    echo "Phase 14 integer conversion negative unexpectedly passed: $context" >&2
    exit 1
  fi
  rg -n -F 'gust_backend_request_failure:' "$stderr_path" >/dev/null
}

for target in "${targets[@]}"; do
  case_dir="$build_root/$target"
  request_path="$case_dir/integer-conversions.request"
  expected="$case_dir/expected.witness"
  c_source="$case_dir/mir-to-c-conversions.c"
  for generated in "$request_path" "$expected" "$c_source"; do
    if [ ! -f "$generated" ] || [ -L "$generated" ]; then
      echo "Missing generated Phase 14 integer conversion artifact: $generated" >&2
      exit 1
    fi
  done

  "$driver" phase14-integer-conversion-witness "$request_path" \
    >"$case_dir/cranelift.witness" \
    2>"$case_dir/cranelift.stderr"
  if [ -s "$case_dir/cranelift.stderr" ]; then
    cat "$case_dir/cranelift.stderr" >&2
    exit 1
  fi
  if ! cmp -s "$expected" "$case_dir/cranelift.witness"; then
    diff -u "$expected" "$case_dir/cranelift.witness" >&2 || true
    echo "Cranelift conversion witness differs from compiler authority for $target." >&2
    exit 1
  fi

  CC_BIN="${CC:-cc}"
  CFLAGS_VAL="${CFLAGS:--O0 -w}"
  "$CC_BIN" $CFLAGS_VAL "$c_source" -o "$case_dir/mir-to-c-conversions"
  "$case_dir/mir-to-c-conversions" \
    >"$case_dir/mir-to-c.witness" \
    2>"$case_dir/mir-to-c.stderr"
  if [ -s "$case_dir/mir-to-c.stderr" ]; then
    cat "$case_dir/mir-to-c.stderr" >&2
    exit 1
  fi
  if ! cmp -s "$expected" "$case_dir/mir-to-c.witness"; then
    diff -u "$expected" "$case_dir/mir-to-c.witness" >&2 || true
    echo "MIR-to-C conversion witness differs from compiler authority for $target." >&2
    exit 1
  fi

  python3 - "$request_path" "$case_dir/unsupported-implicit.request" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text(encoding="utf-8")
old = "conversion_rule_0_kind: sign_extend\n"
if source.count(old) != 1:
    raise SystemExit("expected one sign-extension rule")
Path(sys.argv[2]).write_text(source.replace(old, "conversion_rule_0_kind: implicit\n", 1), encoding="utf-8")
PY
  expect_worker_failure "$case_dir/unsupported-implicit.request" \
    "$target unsupported implicit conversion" \
    "$case_dir/unsupported-implicit.stdout" \
    "$case_dir/unsupported-implicit.stderr"
  rg -n -F 'stage=canonical_mir_validation kind=invalid_canonical_mir' \
    "$case_dir/unsupported-implicit.stderr" >/dev/null

  python3 - "$request_path" "$case_dir/width-mismatch.request" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text(encoding="utf-8")
old = "conversion_rule_0_destination_width: 64\n"
if source.count(old) != 1:
    raise SystemExit("expected one sign-extension destination width")
Path(sys.argv[2]).write_text(source.replace(old, "conversion_rule_0_destination_width: 32\n", 1), encoding="utf-8")
PY
  expect_worker_failure "$case_dir/width-mismatch.request" \
    "$target conversion width mismatch" \
    "$case_dir/width-mismatch.stdout" \
    "$case_dir/width-mismatch.stderr"

  python3 - "$request_path" "$case_dir/narrowing-policy.request" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text(encoding="utf-8")
old = "conversion_rule_2_policy: explicit_truncate_low_bits\n"
if source.count(old) != 1:
    raise SystemExit("expected one truncate policy")
Path(sys.argv[2]).write_text(source.replace(old, "conversion_rule_2_policy: implicit_narrowing\n", 1), encoding="utf-8")
PY
  expect_worker_failure "$case_dir/narrowing-policy.request" \
    "$target narrowing without allowed policy" \
    "$case_dir/narrowing-policy.stdout" \
    "$case_dir/narrowing-policy.stderr"

  python3 - "$request_path" "$case_dir/invalid-bool.request" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text(encoding="utf-8")
needle = "conversion_sample_20_expect_success: 0\n"
if source.count(needle) != 1:
    raise SystemExit("expected invalid bool boundary sample")
Path(sys.argv[2]).write_text(source.replace(needle, "conversion_sample_20_expect_success: 1\n", 1), encoding="utf-8")
PY
  expect_worker_failure "$case_dir/invalid-bool.request" \
    "$target invalid boolean conversion" \
    "$case_dir/invalid-bool.stdout" \
    "$case_dir/invalid-bool.stderr"

  python3 - "$request_path" "$case_dir/pointer-integer.request" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text(encoding="utf-8")
old = "conversion_rule_0_source_type_id: type:gust:i32\n"
if source.count(old) != 1:
    raise SystemExit("expected one source type")
Path(sys.argv[2]).write_text(source.replace(old, "conversion_rule_0_source_type_id: type:gust:pointer\n", 1), encoding="utf-8")
PY
  expect_worker_failure "$case_dir/pointer-integer.request" \
    "$target deferred pointer/integer conversion" \
    "$case_dir/pointer-integer.stdout" \
    "$case_dir/pointer-integer.stderr"

  python3 - "$request_path" "$case_dir/target-disagreement.request" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text(encoding="utf-8")
old = next(line for line in source.splitlines() if line.startswith("conversion_target_triple: ")) + "\n"
Path(sys.argv[2]).write_text(source.replace(old, "conversion_target_triple: phase14-mismatched-target\n", 1), encoding="utf-8")
PY
  expect_worker_failure "$case_dir/target-disagreement.request" \
    "$target request target/conversion disagreement" \
    "$case_dir/target-disagreement.stdout" \
    "$case_dir/target-disagreement.stderr"
  rg -n -F 'stage=target_validation kind=target_mismatch' \
    "$case_dir/target-disagreement.stderr" >/dev/null

  echo "✅ Phase 14 integer conversion parity passed: $target"
done

if [ "$all_targets" = "1" ]; then
  echo "✅ Phase 14 integer conversion all-target parity passed: targets=${#targets[@]}"
else
  echo "✅ Phase 14 integer conversion focused parity passed: target=$primary_target"
fi
