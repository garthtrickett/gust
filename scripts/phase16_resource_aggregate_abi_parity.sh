#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)";cd "$root";build_dir="build/guards/phase16_resource_aggregate_abi";request="/tmp/gust-phase16-resource-aggregate-abi.request";mir_to_c="/tmp/gust-phase16-resource-aggregate-abi.mir-to-c.witness";worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment";mkdir -p "$build_dir"
stage="compile resource aggregate ABI fixture";trap 'status=$?;echo "Phase 16.10 resource aggregate ABI parity failed: stage=$stage status=$status line=$LINENO" >&2;exit $status' ERR
bash scripts/run-gust-file.sh compiler/mir_resource_aggregate_abi_smoke_test_entry.gst;rg -n -F 'SUCCESS: Phase 16.10 resource aggregate ABI smoke passed' to.log >/dev/null
stage="build Cranelift resource aggregate consumer";cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1
stage="compare resource aggregate witnesses";"$worker" phase16-resource-aggregate-abi-witness "$request" >"$build_dir/cranelift.witness";cmp -s "$mir_to_c" "$build_dir/cranelift.witness"
for token in 'scenario=move_into_call' 'scenario=aggregate_return_new_owner' 'scenario=nested_resource_aggregate' 'scenario=early_return_after_receipt' 'scenario=reassign_returned_aggregate' 'live_owner_count=1' 'destructor_count=1';do rg -n -F "$token" "$build_dir/cranelift.witness" >/dev/null;done
reject_mutation(){ local label="$1" reason="$2" expression="$3" mutated="$build_dir/$1.request" output="$build_dir/$1.output" temporary="$build_dir/$1.tmp";cp "$request" "$mutated";sed -i "$expression" "$mutated";printf 'sentinel: preserve-existing-output\n' >"$output";if "$worker" phase16-resource-aggregate-abi-witness "$mutated" >"$temporary" 2>"$build_dir/$label.stderr";then echo "mutation unexpectedly succeeded: $label" >&2;false;fi;rg -n -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null;rg -n -F 'sentinel: preserve-existing-output' "$output" >/dev/null;}
stage="reject malformed resource aggregate transfer before output replacement"
reject_mutation copy resource_aggregate_silent_copy '0,/silent_copy=0/ s/silent_copy=0/silent_copy=1/'
reject_mutation owners resource_aggregate_two_live_owners '0,/live_owner_count=1/ s/live_owner_count=1/live_owner_count=2/'
reject_mutation destination resource_aggregate_missing_destination_identity '0,/destination_resource=resource:destination:resource_aggregate:param/ s/destination_resource=resource:destination:resource_aggregate:param/destination_resource=resource:source:resource_aggregate:param/'
reject_mutation stale resource_aggregate_stale_source_cleanup '0,/old_cleanup_cancelled=1/ s/old_cleanup_cancelled=1/old_cleanup_cancelled=0/'
reject_mutation publication resource_aggregate_uninitialized_publication '/scenario=nested_resource_aggregate/ s/publication_initialized=1/publication_initialized=0/'
reject_mutation destructor resource_aggregate_destructor_mismatch '0,/actual_destructor=destructor:resource_aggregate/ s/actual_destructor=destructor:resource_aggregate/actual_destructor=destructor:wrong/'
reject_mutation disagreement resource_aggregate_caller_callee_disagreement '0,/callee_policy=move_only_exact_transfer/ s/callee_policy=move_only_exact_transfer/callee_policy=copy/'
echo "guard-cranelift-phase16-resource-aggregate-abi-parity: ok (Level 2)"
