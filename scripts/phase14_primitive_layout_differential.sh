#!/usr/bin/env bash
set -euo pipefail

registry="scripts/cranelift_feature_registry.json"
validator="scripts/cranelift_registry.py"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
build_root="build/guards/phase14_primitive_layout"
cargo_target="$build_root/cargo-target"
all_targets="${PHASE14_PRIMITIVE_LAYOUT_ALL_TARGETS:-0}"

for required_file in \
  "$registry" "$validator" "$rust_manifest" \
  compiler/mir_primitive_layout.gst \
  compiler/mir_primitive_layout_smoke_test_entry.gst \
  ./gust
do
  if [ ! -e "$required_file" ]; then
    echo "Phase 14 primitive layout differential is missing $required_file" >&2
    exit 1
  fi
done
if [ ! -x ./gust ]; then
  echo "Phase 14 primitive layout differential requires the rebuilt ./gust compiler." >&2
  exit 1
fi

rm -rf "$build_root"
mkdir -p "$build_root"
while IFS= read -r target; do
  [ -n "$target" ] || continue
  mkdir -p "$build_root/$target"
done < <(python3 "$validator" phase14-primitive-targets)

just guard compiler/mir_primitive_layout_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 14 declared targets and primitive scalar layouts' to.log >/dev/null

CARGO_TARGET_DIR="$cargo_target" cargo build \
  --locked \
  --quiet \
  --manifest-path "$rust_manifest"
driver="$cargo_target/debug/gust-cranelift-experiment"
if [ ! -x "$driver" ]; then
  echo "Phase 14 primitive layout differential did not build $driver" >&2
  exit 1
fi

primary_target="$(python3 "$validator" phase14-primitive-primary-target)"
if [ "$all_targets" = "1" ]; then
  mapfile -t targets < <(python3 "$validator" phase14-primitive-targets)
else
  targets=("$primary_target")
fi
if [ "${#targets[@]}" = "0" ]; then
  echo "Phase 14 primitive layout differential selected no declared targets." >&2
  exit 1
fi

expect_worker_failure() {
  local request_path="$1"
  local context="$2"
  local stdout_path="$3"
  local stderr_path="$4"
  set +e
  "$driver" phase14-primitive-layout-witness "$request_path" \
    >"$stdout_path" 2>"$stderr_path"
  local status="$?"
  set -e
  if [ "$status" = "0" ]; then
    echo "Phase 14 primitive layout negative unexpectedly passed: $context" >&2
    exit 1
  fi
  rg -n -F 'gust_backend_request_failure:' "$stderr_path" >/dev/null
}

for target in "${targets[@]}"; do
  case_dir="$build_root/$target"
  request_path="$case_dir/primitive-layout.request"
  expected="$case_dir/expected.witness"
  c_source="$case_dir/mir-to-c-witness.c"
  for generated in "$request_path" "$expected" "$c_source"; do
    if [ ! -f "$generated" ] || [ -L "$generated" ]; then
      echo "Missing generated Phase 14 primitive artifact: $generated" >&2
      exit 1
    fi
  done

  "$driver" phase14-primitive-layout-witness "$request_path" \
    >"$case_dir/cranelift.witness" \
    2>"$case_dir/cranelift.stderr"
  if [ -s "$case_dir/cranelift.stderr" ]; then
    cat "$case_dir/cranelift.stderr" >&2
    exit 1
  fi
  if ! cmp -s "$expected" "$case_dir/cranelift.witness"; then
    diff -u "$expected" "$case_dir/cranelift.witness" >&2 || true
    echo "Cranelift did not consume the compiler primitive layout witness for $target." >&2
    exit 1
  fi

  "$driver" phase14-primitive-validate-value \
    "$request_path" type:gust:bool 0 \
    >"$case_dir/bool-zero.stdout" 2>"$case_dir/bool-zero.stderr"
  "$driver" phase14-primitive-validate-value \
    "$request_path" type:gust:bool 1 \
    >"$case_dir/bool-one.stdout" 2>"$case_dir/bool-one.stderr"
  if [ -s "$case_dir/bool-zero.stderr" ] || [ -s "$case_dir/bool-one.stderr" ]; then
    cat "$case_dir/bool-zero.stderr" "$case_dir/bool-one.stderr" >&2
    exit 1
  fi
  set +e
  "$driver" phase14-primitive-validate-value \
    "$request_path" type:gust:bool 2 \
    >"$case_dir/bool-two.stdout" 2>"$case_dir/bool-two.stderr"
  bool_status="$?"
  set -e
  if [ "$bool_status" = "0" ]; then
    echo "Invalid boolean memory value was accepted for $target." >&2
    exit 1
  fi
  rg -n -F 'invalid boolean memory value: 2' "$case_dir/bool-two.stderr" >/dev/null
  rg -n -F 'stage=canonical_mir_validation kind=invalid_canonical_mir' \
    "$case_dir/bool-two.stderr" >/dev/null

  python3 - "$request_path" "$case_dir/target-mismatch.request" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text(encoding="utf-8")
old = next(line for line in source.splitlines() if line.startswith("layout_target_triple: "))
replacement = "layout_target_triple: phase14-mismatched-target"
Path(sys.argv[2]).write_text(source.replace(old, replacement, 1), encoding="utf-8")
PY
  expect_worker_failure \
    "$case_dir/target-mismatch.request" \
    "$target target/layout disagreement" \
    "$case_dir/target-mismatch.stdout" \
    "$case_dir/target-mismatch.stderr"
  rg -n -F 'stage=target_validation kind=target_mismatch' \
    "$case_dir/target-mismatch.stderr" >/dev/null

  python3 - "$request_path" "$case_dir/width-mismatch.request" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text(encoding="utf-8")
old = "layout_1_bit_width: 32\n"
if source.count(old) != 1:
    raise SystemExit("expected one i32 bit-width field")
Path(sys.argv[2]).write_text(source.replace(old, "layout_1_bit_width: 64\n", 1), encoding="utf-8")
PY
  expect_worker_failure \
    "$case_dir/width-mismatch.request" \
    "$target scalar width mismatch" \
    "$case_dir/width-mismatch.stdout" \
    "$case_dir/width-mismatch.stderr"

  python3 - "$request_path" "$case_dir/alignment-mismatch.request" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text(encoding="utf-8")
old = "layout_1_alignment: 4\n"
if source.count(old) != 1:
    raise SystemExit("expected one i32 alignment field")
Path(sys.argv[2]).write_text(source.replace(old, "layout_1_alignment: 3\n", 1), encoding="utf-8")
PY
  expect_worker_failure \
    "$case_dir/alignment-mismatch.request" \
    "$target scalar alignment mismatch" \
    "$case_dir/alignment-mismatch.stdout" \
    "$case_dir/alignment-mismatch.stderr"

  if [ "$target" = "$primary_target" ]; then
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$c_source" -o "$case_dir/mir-to-c-witness"
    "$case_dir/mir-to-c-witness" \
      >"$case_dir/mir-to-c.witness" \
      2>"$case_dir/mir-to-c.stderr"
    if [ -s "$case_dir/mir-to-c.stderr" ]; then
      cat "$case_dir/mir-to-c.stderr" >&2
      exit 1
    fi
    if ! cmp -s "$expected" "$case_dir/mir-to-c.witness"; then
      diff -u "$expected" "$case_dir/mir-to-c.witness" >&2 || true
      echo "MIR-to-C storage witness differs from compiler layout for $target." >&2
      exit 1
    fi
  fi

  echo "✅ Phase 14 primitive layout witness passed: $target"
done

if [ "$all_targets" = "1" ]; then
  echo "✅ Phase 14 primitive layout all-target differential passed: targets=${#targets[@]}"
else
  echo "✅ Phase 14 primitive layout focused differential passed: target=$primary_target"
fi