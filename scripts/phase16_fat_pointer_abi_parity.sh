#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)";cd "$root";build_dir="build/guards/phase16_fat_pointer_abi";request="/tmp/gust-phase16-fat-pointer-abi.request";mir_to_c="/tmp/gust-phase16-fat-pointer-abi.mir-to-c.witness";worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment";mkdir -p "$build_dir"
stage="compile fat pointer ABI fixture";trap 'status=$?;echo "Phase 16.7 fat pointer ABI parity failed: stage=$stage status=$status line=$LINENO" >&2;exit $status' ERR
bash scripts/run-gust-file.sh compiler/mir_fat_pointer_abi_smoke_test_entry.gst;rg -n -F 'SUCCESS: Phase 16.7 fat pointer ABI smoke passed' to.log >/dev/null
stage="build Cranelift fat pointer consumer";cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1
stage="compare fat pointer ABI witnesses";"$worker" phase16-fat-pointer-abi-witness "$request" >"$build_dir/cranelift.witness";cmp -s "$mir_to_c" "$build_dir/cranelift.witness"
for token in 'representation=two_word_data_and_vtable' 'data_placement=fat_pointer.word0.data' 'metadata_placement=fat_pointer.word1.vtable' 'slot=vtable_slot:DisplayLike:value:0' 'operations=construct_fat_pointer,extract_vtable_method,typed_indirect_call' 'resource=borrowed_no_transfer_state_live' 'expected_result=42' 'actual_result=42';do rg -n -F "$token" "$build_dir/cranelift.witness" >/dev/null;done
reject_mutation(){ local label="$1" reason="$2" expression="$3" mutated="$build_dir/$1.request" output="$build_dir/$1.output" temporary="$build_dir/$1.tmp";cp "$request" "$mutated";sed -i "$expression" "$mutated";printf 'sentinel: preserve-existing-output\n' >"$output";if "$worker" phase16-fat-pointer-abi-witness "$mutated" >"$temporary" 2>"$build_dir/$label.stderr";then echo "mutation unexpectedly succeeded: $label" >&2;false;fi;rg -n -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null;rg -n -F 'sentinel: preserve-existing-output' "$output" >/dev/null;}
stage="reject malformed fat pointer calls before output replacement"
reject_mutation missing fat_pointer_missing_metadata '0,/metadata_present=1/ s/metadata_present=1/metadata_present=0/'
reject_mutation pairing fat_pointer_component_mismatch '0,/actual_pair=pair:object_7:DisplayLike/ s/actual_pair=pair:object_7:DisplayLike/actual_pair=pair:other/'
reject_mutation signature fat_pointer_unknown_method_signature '0,/actual_signature=sig:borrowed_trait_object_to_i32/ s/actual_signature=sig:borrowed_trait_object_to_i32/actual_signature=sig:other/'
reject_mutation slot fat_pointer_invalid_slot_identity '0,/actual_slot=vtable_slot:DisplayLike:value:0/ s/actual_slot=vtable_slot:DisplayLike:value:0/actual_slot=vtable_slot:other/'
reject_mutation untyped fat_pointer_untyped_dispatch '0,/operations=construct_fat_pointer,extract_vtable_method,typed_indirect_call/ s/operations=construct_fat_pointer,extract_vtable_method,typed_indirect_call/operations=backend_vtable_guess/'
reject_mutation representation fat_pointer_unsupported_target_representation '0,/representation=two_word_data_and_vtable/ s/representation=two_word_data_and_vtable/representation=backend_private/'
reject_mutation alignment fat_pointer_insufficient_alignment '0,/actual_alignment=8/ s/actual_alignment=8/actual_alignment=4/'
reject_mutation resource fat_pointer_resource_disposition_mismatch '0,/resource=borrowed_no_transfer_state_live/ s/resource=borrowed_no_transfer_state_live/resource=backend_owned/'
echo "guard-cranelift-phase16-fat-pointer-abi-parity: ok (Level 2)"
