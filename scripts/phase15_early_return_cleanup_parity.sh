#!/usr/bin/env bash
set -euo pipefail

request="/tmp/gust-phase15-early-return-cleanup.request"
mir_to_c="/tmp/gust-phase15-early-return-cleanup.mir-to-c.witness"
build_dir="build/guards/phase15_early_return_cleanup"
worker_manifest="compiler/experiments/cranelift/Cargo.toml"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"

rm -rf "$build_dir"
rm -f "$request" "$mir_to_c"
mkdir -p "$build_dir"

bash scripts/run-gust-file.sh compiler/mir_early_exit_cleanup_state_smoke_test_entry.gst
grep -F 'SUCCESS: Phase 15.6 early-return cleanup state policy passed' to.log >/dev/null
bash scripts/run-gust-file.sh compiler/mir_early_exit_cleanup_parity_smoke_test_entry.gst
grep -F 'SUCCESS: Phase 15.6 early-return cleanup parity smoke passed' to.log >/dev/null
test -s "$request"
test -s "$mir_to_c"

cargo build --quiet --manifest-path "$worker_manifest"
"$worker" phase15-early-return-cleanup-witness "$request" >"$build_dir/cranelift.witness"
diff -u "$mir_to_c" "$build_dir/cranelift.witness"

for token in \
  'kind=direct_return' \
  'kind=nested_conditional_return' \
  'kind=selected_loop_return' \
  'kind=selected_break' \
  'kind=selected_continue' \
  'scope=scope:branch resource=resource:branch:second order=1' \
  'scope=scope:branch resource=resource:branch:first order=2' \
  'scope=scope:function resource=resource:function order=3' \
  'return_value_evaluated_before_cleanup=1' \
  'cleanup_before_terminator=1' \
  'scalar_return_abi_preserved=1' \
  'output_preserved=1'
do
  grep -F "$token" "$build_dir/cranelift.witness" >/dev/null
done

cp "$request" "$build_dir/base.request"

mutate() {
  local mode="$1"
  local output="$2"
  python3 - "$build_dir/base.request" "$output" "$mode" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
output = Path(sys.argv[2])
mode = sys.argv[3]

def value(key):
    prefix = key + ": "
    return next(line[len(prefix):] for line in source.splitlines() if line.startswith(prefix))

def replace(key, new):
    global source
    source = source.replace(f"{key}: {value(key)}", f"{key}: {new}", 1)

if mode == "missing-cleanup":
    replace("early_exit_cleanup_entry_count", "8")
elif mode == "after-terminator":
    replace("early_exit_cleanup_entry_0_execution_order", "4")
elif mode == "duplicate-shared-edge":
    replace("early_exit_cleanup_entry_1_cleanup_operation_id", value("early_exit_cleanup_entry_0_cleanup_operation_id"))
elif mode == "wrong-scope":
    replace("early_exit_cleanup_entry_1_scope_id", "scope:not-exited")
elif mode == "state-disagreement":
    replace("early_exit_cleanup_entry_1_prior_state", "moved")
elif mode == "bad-inner-outer":
    replace("early_exit_cleanup_entry_1_scope_depth", "0")
elif mode == "aggregate-return":
    replace("early_exit_cleanup_edge_0_return_abi", "aggregate")
else:
    raise SystemExit(mode)
output.write_text(source)
PY
}

expect_failure() {
  local mode="$1"
  local reason="$2"
  local path="$build_dir/$mode.request"
  mutate "$mode" "$path"
  if "$worker" phase15-early-return-cleanup-witness "$path" >"$build_dir/$mode.stdout" 2>"$build_dir/$mode.stderr"; then
    echo "Phase 15.6 mutation unexpectedly passed: $mode" >&2
    exit 1
  fi
  grep -F "reason=$reason" "$build_dir/$mode.stderr" >/dev/null || {
    cat "$build_dir/$mode.stderr" >&2
    exit 1
  }
}

expect_failure missing-cleanup early_return_cleanup_missing
expect_failure after-terminator early_return_cleanup_after_terminator
expect_failure duplicate-shared-edge early_return_cleanup_duplicate_shared_edge
expect_failure wrong-scope early_return_cleanup_resource_not_in_exited_scope
expect_failure state-disagreement early_return_cleanup_non_live_resource
expect_failure bad-inner-outer early_return_cleanup_inner_outer_order_invalid
expect_failure aggregate-return early_return_cleanup_aggregate_return_deferred

echo "guard-cranelift-phase15-early-return-cleanup-parity: ok (Level 2)"