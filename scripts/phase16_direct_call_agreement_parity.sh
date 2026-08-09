#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase16_direct_call_agreement"; request="/tmp/gust-phase16-direct-call-agreement.request"; mir_to_c="/tmp/gust-phase16-direct-call-agreement.mir-to-c.witness"; worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"; mkdir -p "$build_dir"
stage="compile direct-call agreement fixture"; trap 'status=$?; echo "Phase 16.5 direct-call parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR
bash scripts/run-gust-file.sh compiler/mir_direct_call_agreement_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 16.5 direct-call agreement smoke passed' to.log >/dev/null
stage="build Cranelift direct-call agreement consumer"; cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1
stage="compare compiler-owned direct-call agreement witnesses"; "$worker" phase16-direct-call-agreement-witness "$request" >"$build_dir/cranelift.witness"; cmp -s "$mir_to_c" "$build_dir/cranelift.witness"
for token in 'kind=nested_direct' 'kind=direct_recursion' 'kind=mixed_scalar_aggregate' 'kind=aggregate_result_chain' 'flow=producer_result_to_consumer_argument' 'expected_hidden=hidden_pointer:0'; do rg -n -F "$token" "$build_dir/cranelift.witness" >/dev/null; done
reject_mutation() {
  local label="$1" reason="$2" expression="$3" mutated="$build_dir/$1.request" output="$build_dir/$1.output" temporary="$build_dir/$1.tmp"
  cp "$request" "$mutated"; sed -i "$expression" "$mutated"; printf 'sentinel: preserve-existing-output\n' >"$output"
  if "$worker" phase16-direct-call-agreement-witness "$mutated" >"$temporary" 2>"$build_dir/$label.stderr"; then echo "mutation unexpectedly succeeded: $label" >&2; false; fi
  rg -n -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null; rg -n -F 'sentinel: preserve-existing-output' "$output" >/dev/null
}
stage="reject caller/callee ABI drift before output replacement"
reject_mutation signature direct_call_signature_drift '0,/actual_signature=sig:add:scalar/ s/actual_signature=sig:add:scalar/actual_signature=sig:add:stale/'
reject_mutation stale direct_call_stale_plan '0,/freshness=current_compiler_plan/ s/freshness=current_compiler_plan/freshness=stale_compiler_plan/'
reject_mutation parameter direct_call_parameter_permutation '0,/actual_parameters=abi_placement:v1:phase16:scalar:param:0,abi_placement:v1:phase16:pair:param:1/ s/actual_parameters=abi_placement:v1:phase16:scalar:param:0,abi_placement:v1:phase16:pair:param:1/actual_parameters=abi_placement:v1:phase16:pair:param:1,abi_placement:v1:phase16:scalar:param:0/'
reject_mutation result direct_call_result_permutation '0,/actual_results=abi_placement:v1:phase16:pair:result:0/ s/actual_results=abi_placement:v1:phase16:pair:result:0/actual_results=abi_placement:v1:phase16:scalar:result:0/'
reject_mutation layout direct_call_layout_mismatch '0,/actual_layouts=layout:i32->layout:i32/ s/actual_layouts=layout:i32->layout:i32/actual_layouts=layout:i64->layout:i32/'
reject_mutation convention direct_call_calling_convention_mismatch '0,/actual_cc=gust/ s/actual_cc=gust/actual_cc=foreign/'
reject_mutation target direct_call_target_mismatch '0,/actual_target=target:x86_64-unknown-linux-gnu/ s/actual_target=target:x86_64-unknown-linux-gnu/actual_target=target:aarch64-unknown-linux-gnu/'
reject_mutation hidden direct_call_hidden_result_mismatch '0,/actual_hidden=hidden_pointer:0/ s/actual_hidden=hidden_pointer:0/actual_hidden=none/'
reject_mutation transfer direct_call_resource_transfer_mismatch '0,/actual_transfers=non_resource_copy/ s/actual_transfers=non_resource_copy/actual_transfers=resource_move/'
echo "guard-cranelift-phase16-direct-call-agreement-parity: ok (Level 2)"
