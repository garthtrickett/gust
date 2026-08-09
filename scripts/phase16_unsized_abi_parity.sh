#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)";cd "$root";build_dir="build/guards/phase16_unsized_abi";request="/tmp/gust-phase16-unsized-abi.request";mir_to_c="/tmp/gust-phase16-unsized-abi.mir-to-c.witness";worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment";mkdir -p "$build_dir"
stage="compile unsized ABI fixture";trap 'status=$?;echo "Phase 16.8 unsized ABI parity failed: stage=$stage status=$status line=$LINENO" >&2;exit $status' ERR
bash scripts/run-gust-file.sh compiler/mir_unsized_abi_smoke_test_entry.gst;rg -n -F 'SUCCESS: Phase 16.8 unsized ABI smoke passed' to.log >/dev/null
stage="build Cranelift unsized consumer";cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1
stage="compare unsized ABI witnesses";"$worker" phase16-unsized-abi-witness "$request" >"$build_dir/cranelift.witness";cmp -s "$mir_to_c" "$build_dir/cranelift.witness"
for token in 'form=borrowed_slice_parameter' 'form=borrowed_slice_result' 'form=fixed_backing_local_slice_view' 'transport=fat_pointer_data_and_length' 'length=4' 'checked_size=16' 'bounds=checked_index_less_than_length' 'resource=borrowed_no_transfer_state_live';do rg -n -F "$token" "$build_dir/cranelift.witness" >/dev/null;done
reject_mutation(){ local label="$1" reason="$2" expression="$3" mutated="$build_dir/$1.request" output="$build_dir/$1.output" temporary="$build_dir/$1.tmp";cp "$request" "$mutated";sed -i "$expression" "$mutated";printf 'sentinel: preserve-existing-output\n' >"$output";if "$worker" phase16-unsized-abi-witness "$mutated" >"$temporary" 2>"$build_dir/$label.stderr";then echo "mutation unexpectedly succeeded: $label" >&2;false;fi;rg -n -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null;rg -n -F 'sentinel: preserve-existing-output' "$output" >/dev/null;}
stage="reject malformed unsized ABI before output replacement"
reject_mutation by_value unsized_by_value_without_storage_plan '0,/transport=fat_pointer_data_and_length/ s/transport=fat_pointer_data_and_length/transport=by_value/'
reject_mutation missing unsized_missing_metadata '0,/metadata_present=1/ s/metadata_present=1/metadata_present=0/'
reject_mutation length unsized_inconsistent_length_or_layout '0,/actual_length=4/ s/actual_length=4/actual_length=3/'
reject_mutation overflow unsized_size_overflow '0,/overflow_checked=1/ s/overflow_checked=1/overflow_checked=0/'
reject_mutation alignment unsized_insufficient_alignment '0,/actual_alignment=4/ s/actual_alignment=4/actual_alignment=2/'
reject_mutation bounds unsized_bounds_violation '0,/access_index=1/ s/access_index=1/access_index=4/'
reject_mutation owner unsized_invalid_result_ownership '/form=borrowed_slice_result/ s/owner=caller_backing_borrowed_result;actual_owner=caller_backing_borrowed_result/owner=callee_temporary;actual_owner=callee_temporary/'
reject_mutation invented unsized_backend_invented_size '0,/operations=bind_unsized_data/ s/operations=bind_unsized_data/operations=backend_size_guess/'
echo "guard-cranelift-phase16-unsized-abi-parity: ok (Level 2)"
