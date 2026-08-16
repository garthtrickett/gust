#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase17_runtime_import"
request="/tmp/gust-phase17-runtime-import.request"
mir_to_c="/tmp/gust-phase17-runtime-import.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile runtime import fixture"
trap 'status=$?; echo "Phase 17.5 runtime import parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_runtime_import_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 17.5 runtime import smoke passed' to.log >/dev/null

stage="build Cranelift runtime import consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned runtime import witnesses"
"$worker" phase17-runtime-import-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

stage="confirm every selected import is compiler-owned and glue-free"
for token in 'spelling=tiny_host_add_one_i32' 'spelling=tiny_host_add_i32' \
             'spelling=tiny_host_is_positive_i32' 'version=gust-runtime-symbol-v1' \
             'linkage=direct_external_call_no_generated_c_glue'; do
  rg -n -F "$token" "$build_dir/cranelift.witness" >/dev/null
done

# Cranelift must declare and call the compiler-selected symbol directly. The
# emitted object is the evidence: the imports appear as undefined symbols with
# no generated C wrapper standing between the caller and the runtime.
stage="emit Cranelift object that imports the compiler-selected symbols"
"$worker" phase17-runtime-import-object "$request" "$build_dir/imports.o"
nm -u "$build_dir/imports.o" >"$build_dir/undefined.symbols"
for symbol in tiny_host_add_one_i32 tiny_host_add_i32 tiny_host_is_positive_i32; do
  rg -n -F "U $symbol" "$build_dir/undefined.symbols" >/dev/null
done
if rg -n -e 'gust_generated_c_shim' -e 'gust_runtime_wrapper' "$build_dir/undefined.symbols" >/dev/null; then
  echo "generated C glue reached the native import path" >&2; false
fi

reject_mutation() {
  local label="$1" reason="$2" expression="$3"
  local mutated="$build_dir/$1.request" output="$build_dir/$1.output" temporary="$build_dir/$1.tmp"
  cp "$request" "$mutated"; sed -i "$expression" "$mutated"
  printf 'sentinel: preserve-existing-output\n' >"$output"
  if "$worker" phase17-runtime-import-witness "$mutated" >"$temporary" 2>"$build_dir/$label.stderr"; then
    echo "mutation unexpectedly succeeded: $label" >&2; false
  fi
  rg -n -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null
  rg -n -F 'sentinel: preserve-existing-output' "$output" >/dev/null
  # The object path must refuse the same malformed request before writing.
  if "$worker" phase17-runtime-import-object "$mutated" "$build_dir/$label.o" \
      >/dev/null 2>"$build_dir/$label.object.stderr"; then
    echo "object mutation unexpectedly succeeded: $label" >&2; false
  fi
  rg -n -F "reason=$reason" "$build_dir/$label.object.stderr" >/dev/null
}

stage="reject malformed runtime imports before object or link access"
reject_mutation missing_symbol runtime_import_missing_symbol \
  '0,/;spelling=tiny_host_add_one_i32;/ s/;spelling=tiny_host_add_one_i32;/;spelling=;/'
reject_mutation incompatible_version runtime_import_incompatible_version \
  '0,/;version=gust-runtime-symbol-v1;/ s/;version=gust-runtime-symbol-v1;/;version=gust-runtime-symbol-v9;/'
reject_mutation abi_mismatch runtime_import_abi_mismatch \
  '0,/function_abi=function_abi:runtime:tiny_host_add_one_i32:i32_to_i32:/ s/function_abi=function_abi:runtime:tiny_host_add_one_i32:i32_to_i32:/function_abi=function_abi:runtime:tiny_host_add_one_i32:i64_to_i64:/'
reject_mutation wrong_component runtime_import_wrong_target_component \
  '0,/kind=stable_runtime_library_function/ s/kind=stable_runtime_library_function/kind=retained_c_runtime_component/'
reject_mutation undeclared_policy runtime_import_undeclared \
  '0,/side_effects=pure_scalar_no_side_effects/ s/side_effects=pure_scalar_no_side_effects/side_effects=assume_pure/'
reject_mutation unknown_format runtime_import_undeclared \
  '0,/format: gust.compiler_runtime_import.v1/ s/format: gust.compiler_runtime_import.v1/format: gust.compiler_runtime_import.v9/'

echo "guard-cranelift-phase17-runtime-import-parity: ok (Level 2)"
