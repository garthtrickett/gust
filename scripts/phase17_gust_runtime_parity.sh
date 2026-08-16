#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase17_gust_runtime"
request="/tmp/gust-phase17-gust-runtime.request"
mir_to_c="/tmp/gust-phase17-gust-runtime.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
module="src/runtime/gust/char_predicates.gst"
mkdir -p "$build_dir"
stage="compile the pure Gust runtime module through the generic route"
trap 'status=$?; echo "Phase 17.8 gust runtime parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_gust_runtime_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 17.8 gust runtime module smoke passed' to.log >/dev/null

# The exit gate turns on "without bespoke compiler recognition". The evidence is
# that no compiler or backend source mentions this module by name or by path.
stage="confirm no bespoke recognition of the runtime module"
if rg -n -e 'char_predicates' -e 'gust_rt_is_alpha' -e 'runtime/gust/' \
     compiler/experiments/cranelift/src/main.rs compiler/driver.gst 2>/dev/null | rg -v '^\s*$' >/dev/null; then
  echo "compiler or backend recognises the runtime module by name" >&2; false
fi
test -f "$module"

stage="build Cranelift gust runtime consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned gust runtime witnesses"
"$worker" phase17-gust-runtime-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"
for token in 'lowering_route=generic_parse_typecheck_canonical_mir_abi_cranelift' \
             'initialization=none_required_pure_functions' \
             'linkage=generic_canonical_mir_route_no_bespoke_recognition'; do
  rg -n -F "$token" "$build_dir/cranelift.witness" >/dev/null
done

reject_mutation() {
  local label="$1" reason="$2" expression="$3"
  local mutated="$build_dir/$1.request" output="$build_dir/$1.output" temporary="$build_dir/$1.tmp"
  cp "$request" "$mutated"; sed -i "$expression" "$mutated"
  printf 'sentinel: preserve-existing-output\n' >"$output"
  if "$worker" phase17-gust-runtime-witness "$mutated" >"$temporary" 2>"$build_dir/$label.stderr"; then
    echo "mutation unexpectedly succeeded: $label" >&2; false
  fi
  rg -n -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null
  rg -n -F 'sentinel: preserve-existing-output' "$output" >/dev/null
}

stage="reject malformed gust runtime metadata before object or link access"
reject_mutation non_generic runtime_gust_non_generic_lowering \
  '0,/lowering_route=generic_parse_typecheck_canonical_mir_abi_cranelift/ s/lowering_route=generic_parse_typecheck_canonical_mir_abi_cranelift/lowering_route=runtime_module_special_case/'
reject_mutation missing_export runtime_gust_missing_requirement \
  '0,/;exports=[^;]*;/ s/;exports=[^;]*;/;exports=none;/'
reject_mutation generated_c runtime_gust_hidden_generated_c \
  '0,\|;source=[^;]*;| s|;source=[^;]*;|;source=build/generated/runtime_shim.c;|'
reject_mutation unknown_format runtime_gust_missing_requirement \
  '0,/format: gust.compiler_gust_runtime.v1/ s/format: gust.compiler_gust_runtime.v1/format: gust.compiler_gust_runtime.v9/'

echo "guard-cranelift-phase17-gust-runtime-parity: ok (Level 2)"
