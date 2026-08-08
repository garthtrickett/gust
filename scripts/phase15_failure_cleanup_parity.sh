#!/usr/bin/env bash
set -euo pipefail
echo "🧪 Running Phase 15.12 failure cleanup parity..."
python3 scripts/cranelift_test_levels.py validate
python3 scripts/cranelift_test_levels.py level guard-cranelift-phase15-failure-cleanup-parity | grep -F $'guard-cranelift-phase15-failure-cleanup-parity\t2\t' >/dev/null
python3 scripts/phase15_failure_cleanup.py --check >/dev/null

request="/tmp/gust-phase15-failure-cleanup.request"
mir_to_c="/tmp/gust-phase15-failure-cleanup.mir-to-c.witness"
build_dir="build/guards/phase15_failure_cleanup"
worker_manifest="compiler/experiments/cranelift/Cargo.toml"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
rm -rf "$build_dir"
rm -f "$request" "$mir_to_c"
mkdir -p "$build_dir"

XDG_RUNTIME_DIR=/tmp TMPDIR=/tmp bash scripts/run-gust-file.sh compiler/future/p15_selected_failure_cleanup_source.gst
grep -F 'SUCCESS: Phase 15.12 selected failure cleanup source passed' to.log >/dev/null
XDG_RUNTIME_DIR=/tmp TMPDIR=/tmp bash scripts/run-gust-file.sh compiler/mir_failure_cleanup_state_smoke_test_entry.gst
grep -F 'SUCCESS: Phase 15.12 failure cleanup state policy passed' to.log >/dev/null
XDG_RUNTIME_DIR=/tmp TMPDIR=/tmp bash scripts/run-gust-file.sh compiler/mir_failure_cleanup_parity_smoke_test_entry.gst
grep -F 'SUCCESS: Phase 15.12 failure cleanup parity smoke passed' to.log >/dev/null
test -s "$request"
test -s "$mir_to_c"

cargo build --quiet --manifest-path "$worker_manifest"
"$worker" phase15-failure-cleanup-witness "$request" >"$build_dir/cranelift.witness"
diff -u "$mir_to_c" "$build_dir/cranelift.witness"

for token in \
  'failure_cleanup_policy: authority=compiler selected_forms=trap_before_exec,runtime_failure_return,selected_panic,native_op_failure_edge deferred_forms=async_unwind,foreign_exception,cancellation order=reverse_declaration_inner_before_outer exactly_once=1 backend_cleanup_planner=0' \
  'failure_cleanup: form=trap_before_exec stage=before_driver_discovery terminal=compiler_rejection stable_authority=compiler_resource_cleanup_verifier cleanup_policy=no_cleanup_resource_not_initialized final_state=uninitialized cleanup_count=0 destructor_count=0 exit_status=65 output_preserved=1' \
  'failure_cleanup: form=runtime_failure_return stage=runtime_failure_status_edge terminal=failure_return stable_authority=canonical_mir_failure_return.v1 cleanup_policy=cleanup_live_resources_then_terminate final_state=destroyed cleanup_count=1 destructor_count=1 exit_status=82 output_preserved=1' \
  'failure_cleanup: form=selected_panic stage=compiler_selected_panic_edge terminal=trap_after_cleanup stable_authority=gust.compiler_panic.v1 cleanup_policy=cleanup_live_resources_then_terminate final_state=destroyed cleanup_count=1 destructor_count=1 exit_status=101 output_preserved=1' \
  'failure_cleanup: form=native_op_failure_edge stage=canonical_mir_native_failure_edge terminal=propagate_native_status stable_authority=gust.compiler_native_failure.v1 cleanup_policy=cleanup_live_resources_then_terminate final_state=destroyed cleanup_count=1 destructor_count=1 exit_status=74 output_preserved=1' \
  'failure_cleanup_witness: selected_form_count=4 cleanup_count=3 destructor_count=3 exactly_once=1 order=reverse_declaration_inner_before_outer output_preserved=1 generic_authority=1'
do
  grep -F "$token" "$build_dir/cranelift.witness" >/dev/null
done

echo "guard-cranelift-phase15-failure-cleanup-parity: ok (Level 2)"
