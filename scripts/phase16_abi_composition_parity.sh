#!/usr/bin/env bash
set -euo pipefail
python3 scripts/phase16_abi_composition.py --check >/dev/null
build_dir="build/guards/phase16_abi_composition"
request="/tmp/gust-phase16-abi-composition.request"
expected="/tmp/gust-phase16-abi-composition.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
rm -f "$request" "$expected"
XDG_RUNTIME_DIR=/tmp TMPDIR=/tmp bash scripts/run-gust-file.sh compiler/future/p16_complete_abi_differential_source.gst
test -s to.log
./gust compiler/future/p16_complete_abi_differential_source.gst >"$build_dir/default.c"
./gust --backend mir-to-c compiler/future/p16_complete_abi_differential_source.gst >"$build_dir/explicit.c"
cmp -s "$build_dir/default.c" "$build_dir/explicit.c"
XDG_RUNTIME_DIR=/tmp TMPDIR=/tmp bash scripts/run-gust-file.sh compiler/mir_abi_composition_parity_smoke_test_entry.gst
grep -F 'SUCCESS: Phase 16.13 ABI composition parity smoke passed' to.log >/dev/null
test -s "$request" && test -s "$expected"
cargo build --quiet --manifest-path compiler/experiments/cranelift/Cargo.toml
"$worker" phase16-abi-composition-witness "$request" >"$build_dir/cranelift.witness"
diff -u "$expected" "$build_dir/cranelift.witness"
grep -F 'abi_composition_case: id=phase16:complete_abi_composition covered_entries=12' "$build_dir/cranelift.witness" >/dev/null
grep -F 'default_explicit_mir_to_c_byte_identity=1 mir_to_c_cranelift_witness_identity=1' "$build_dir/cranelift.witness" >/dev/null
mutated="$build_dir/coverage-mismatch.request"
output="$build_dir/coverage-mismatch.output"
temporary="$build_dir/coverage-mismatch.tmp"
cp "$request" "$mutated"
sed -i 's/p16_abi_metadata_validation/p16_missing/' "$mutated"
printf 'sentinel: preserve-existing-output\n' >"$output"
if "$worker" phase16-abi-composition-witness "$mutated" >"$temporary" 2>"$build_dir/coverage-mismatch.stderr"; then
  echo 'invalid composition unexpectedly succeeded' >&2
  exit 1
fi
grep -F 'reason=abi_composition_coverage_mismatch' "$build_dir/coverage-mismatch.stderr" >/dev/null
grep -F 'sentinel: preserve-existing-output' "$output" >/dev/null
echo "guard-cranelift-phase16-composition-differential: ok (Level 2)"
