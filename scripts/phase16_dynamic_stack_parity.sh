#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)";cd "$root";build_dir="build/guards/phase16_dynamic_stack";request="/tmp/gust-phase16-dynamic-stack.request";mir_to_c="/tmp/gust-phase16-dynamic-stack.mir-to-c.witness";worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment";mkdir -p "$build_dir"
stage="compile dynamic stack fixture";trap 'status=$?;echo "Phase 16.9 dynamic stack parity failed: stage=$stage status=$status line=$LINENO" >&2;exit $status' ERR
bash scripts/run-gust-file.sh compiler/mir_dynamic_stack_smoke_test_entry.gst;rg -n -F 'SUCCESS: Phase 16.9 dynamic stack smoke passed' to.log >/dev/null
stage="build Cranelift dynamic stack consumer";cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1
stage="compare dynamic stack witnesses";"$worker" phase16-dynamic-stack-witness "$request" >"$build_dir/cranelift.witness";cmp -s "$mir_to_c" "$build_dir/cranelift.witness"
for token in 'form=bounded_vla_normal_exit' 'form=bounded_vla_early_return' 'form=bounded_nested_vla' 'checked_size=16' 'element_count=0' 'zero_size_policy=allow_zero_bytes_preserve_restore_marker' 'cleanup_order=resource_cleanup_then_lifetime_end_then_stack_restore';do rg -n -F "$token" "$build_dir/cranelift.witness" >/dev/null;done
reject_mutation(){ local label="$1" reason="$2" expression="$3" mutated="$build_dir/$1.request" output="$build_dir/$1.output" temporary="$build_dir/$1.tmp";cp "$request" "$mutated";sed -i "$expression" "$mutated";printf 'sentinel: preserve-existing-output\n' >"$output";if "$worker" phase16-dynamic-stack-witness "$mutated" >"$temporary" 2>"$build_dir/$label.stderr";then echo "mutation unexpectedly succeeded: $label" >&2;false;fi;rg -n -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null;rg -n -F 'sentinel: preserve-existing-output' "$output" >/dev/null;}
stage="reject malformed dynamic stack plan before output replacement"
reject_mutation dominates dynamic_stack_non_dominating_size '0,/size_dominates=1/ s/size_dominates=1/size_dominates=0/'
reject_mutation overflow dynamic_stack_unchecked_overflow '0,/overflow_checked=1/ s/overflow_checked=1/overflow_checked=0/'
reject_mutation limit dynamic_stack_size_limit_exceeded '0,/actual_size=16/ s/actual_size=16/actual_size=5000/'
reject_mutation alignment dynamic_stack_unsupported_alignment '0,/actual_alignment=4/ s/actual_alignment=4/actual_alignment=8/'
reject_mutation lifetime dynamic_stack_use_outside_lifetime '0,/use_within_lifetime=1/ s/use_within_lifetime=1/use_within_lifetime=0/'
reject_mutation restoration dynamic_stack_missing_restoration '0,/restoration_present=1/ s/restoration_present=1/restoration_present=0/'
reject_mutation cleanup dynamic_stack_restore_before_cleanup '0,/restoration_after_cleanup=1/ s/restoration_after_cleanup=1/restoration_after_cleanup=0/'
reject_mutation target dynamic_stack_unsupported_target '0,/actual_target=target:x86_64-unknown-linux-gnu/ s/actual_target=target:x86_64-unknown-linux-gnu/actual_target=target:unsupported/'
reject_mutation invented dynamic_stack_backend_invented_size '0,/aligned_stack_allocate/ s/aligned_stack_allocate/backend_stack_allocate/'
echo "guard-cranelift-phase16-dynamic-stack-parity: ok (Level 2)"
