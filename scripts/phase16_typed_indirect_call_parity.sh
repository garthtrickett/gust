#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)";cd "$root";build_dir="build/guards/phase16_typed_indirect_call";request="/tmp/gust-phase16-typed-indirect-call.request";mir_to_c="/tmp/gust-phase16-typed-indirect-call.mir-to-c.witness";worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment";mkdir -p "$build_dir"
stage="compile typed indirect call fixture";trap 'status=$?;echo "Phase 16.6 typed indirect parity failed: stage=$stage status=$status line=$LINENO" >&2;exit $status' ERR
bash scripts/run-gust-file.sh compiler/mir_typed_indirect_call_smoke_test_entry.gst;rg -n -F 'SUCCESS: Phase 16.6 typed indirect call smoke passed' to.log >/dev/null
stage="build Cranelift typed indirect consumer";cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1
stage="compare typed indirect witnesses";"$worker" phase16-typed-indirect-call-witness "$request" >"$build_dir/cranelift.witness";cmp -s "$mir_to_c" "$build_dir/cranelift.witness"
for token in 'form=compatible_function_selection' 'form=typed_function_value_parameter' 'select_compatible_function' 'pass_typed_function_value' 'pointer_policy=compiler_typed_function_value_no_pointer_cast';do rg -n -F "$token" "$build_dir/cranelift.witness" >/dev/null;done
reject_mutation(){ local label="$1" reason="$2" expression="$3" mutated="$build_dir/$1.request" output="$build_dir/$1.output" temporary="$build_dir/$1.tmp";cp "$request" "$mutated";sed -i "$expression" "$mutated";printf 'sentinel: preserve-existing-output\n' >"$output";if "$worker" phase16-typed-indirect-call-witness "$mutated" >"$temporary" 2>"$build_dir/$label.stderr";then echo "mutation unexpectedly succeeded: $label" >&2;false;fi;rg -n -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null;rg -n -F 'sentinel: preserve-existing-output' "$output" >/dev/null;}
stage="reject invalid typed indirect calls before output replacement"
reject_mutation unknown typed_indirect_unknown_signature '0,/expected_signature=sig:scalar_to_scalar/ s/expected_signature=sig:scalar_to_scalar/expected_signature=/'
reject_mutation erased typed_indirect_signature_erasure '0,/operations=create_typed_function_value/ s/operations=create_typed_function_value/operations=erased_function_pointer/'
reject_mutation incompatible typed_indirect_incompatible_function_value '0,/actual_signature=sig:scalar_to_scalar/ s/actual_signature=sig:scalar_to_scalar/actual_signature=sig:other/'
reject_mutation null typed_indirect_null_call '0,/is_null=0/ s/is_null=0/is_null=1/'
reject_mutation convention typed_indirect_unsupported_calling_convention '0,/cc=gust/ s/cc=gust/cc=foreign/'
reject_mutation variadic typed_indirect_variadic_not_selected '0,/variadic=0/ s/variadic=0/variadic=1/'
reject_mutation cast typed_indirect_unvalidated_pointer_cast '0,/pointer_policy=compiler_typed_function_value_no_pointer_cast/ s/pointer_policy=compiler_typed_function_value_no_pointer_cast/pointer_policy=unvalidated_pointer_cast/'
echo "guard-cranelift-phase16-typed-indirect-call-parity: ok (Level 2)"
