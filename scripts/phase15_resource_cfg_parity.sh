#!/usr/bin/env bash
set -euo pipefail
echo "🧪 Running Phase 15.9 conditional and loop-carried resource state parity..."

request="/tmp/gust-phase15-resource-cfg.request"
mir_to_c="/tmp/gust-phase15-resource-cfg.mir-to-c.witness"
build_dir="build/guards/phase15_resource_cfg"
worker_manifest="compiler/experiments/cranelift/Cargo.toml"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"

rm -rf "$build_dir"
rm -f "$request" "$mir_to_c"
mkdir -p "$build_dir"

bash scripts/run-gust-file.sh compiler/mir_resource_cfg_state_smoke_test_entry.gst
grep -F 'SUCCESS: Phase 15.9 resource CFG state policy passed' to.log >/dev/null
bash scripts/run-gust-file.sh compiler/mir_resource_cfg_parity_smoke_test_entry.gst
grep -F 'SUCCESS: Phase 15.9 resource CFG parity smoke passed' to.log >/dev/null
test -s "$request"
test -s "$mir_to_c"

cargo build --quiet --manifest-path "$worker_manifest"
"$worker" phase15-resource-cfg-witness "$request" >"$build_dir/cranelift.witness"
diff -u "$mir_to_c" "$build_dir/cranelift.witness"

for token in \
  'resource_cfg_policy: authority=compiler_owned_join_policy' \
  'resource_cfg_valid_joins: live/live,moved/moved,closed/closed,reinitialized/reinitialized' \
  'resource_cfg_invalid_joins: live/moved,live/closed,destroyed/live,incompatible_resource_identities' \
  'resource_cfg_loop_policies: resource_remains_live_across_iterations,resource_moves_exactly_once_before_loop_exit,resource_is_replaced_each_iteration_with_prior_cleanup,resource_is_closed_on_all_exiting_paths' \
  'join: join_id=join:cfg:live_live' \
  'join: join_id=join:cfg:moved_moved' \
  'join: join_id=join:cfg:closed_closed' \
  'loop: loop_id=loop:cfg:live_across' \
  'loop: loop_id=loop:cfg:move_once' \
  'loop: loop_id=loop:cfg:replace_each' \
  'loop: loop_id=loop:cfg:closed_all' \
  'resource_state_witness_after_join: join_id=join:cfg:live_live' \
  'resource_state_witness_after_loop_exit: loop_id=loop:cfg:live_across' \
  'resource_cfg_witness: join_count=5 loop_count=4' \
  'cleanup_behavior_equivalent=1' \
  'block_params_used=1' \
  'nested_branches=1' \
  'selected_loops=1' \
  'resource_cfg_interaction_witness: compiler_owned_join_policy_with_equivalent_cleanup_behavior_through_mir_to_c_and_cranelift'
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

if mode == "live-moved":
    replace("resource_cfg_join_0_incoming_state_b", "moved")
elif mode == "incompatible-identities":
    # add second resource id that differs
    source = source.replace("resource_cfg_join_0_incoming_state_a: live", "resource_cfg_join_0_incoming_state_a: live\nresource_cfg_join_0_incoming_resource_id_second: resource:cfg:other", 1)
    # if already exists, replace
    if "resource_cfg_join_0_incoming_resource_id_second: resource:cfg:other" not in source:
        replace("resource_cfg_join_0_incoming_resource_id_second", "resource:cfg:other")
elif mode == "destroyed-live":
    replace("resource_cfg_join_0_incoming_state_a", "destroyed")
elif mode == "loop-backedge-mismatch":
    replace("resource_cfg_loop_0_backedge_state", "moved")
elif mode == "destructor-disagreement":
    replace("resource_cfg_loop_3_exit_state", "live")
elif mode == "use-after-moved":
    replace("resource_cfg_loop_1_exit_state", "live")
elif mode == "cleanup-mismatch":
    replace("resource_cfg_loop_2_cleanup_obligation_id", "")
elif mode == "missing-block-param":
    replace("resource_cfg_join_0_block_param_ids", "")
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
  if "$worker" phase15-resource-cfg-witness "$path" >"$build_dir/$mode.stdout" 2>"$build_dir/$mode.stderr"; then
    echo "Phase 15.9 mutation unexpectedly passed: $mode" >&2
    exit 1
  fi
  grep -F "reason=$reason" "$build_dir/$mode.stderr" >/dev/null || {
    cat "$build_dir/$mode.stderr" >&2
    exit 1
  }
}

expect_failure live-moved path_dependent_liveness_without_selected_policy
expect_failure incompatible-identities incompatible_resource_identities
expect_failure destroyed-live resource_cfg_destroyed_live_invalid
expect_failure loop-backedge-mismatch loop_backedge_state_mismatch
expect_failure destructor-disagreement destructor_schedule_disagreement
expect_failure use-after-moved use_after_conditionally_moved_state
expect_failure cleanup-mismatch cleanup_obligation_mismatch_at_join
expect_failure missing-block-param resource_cfg_missing_block_param

echo "guard-cranelift-phase15-resource-cfg-parity: ok (Level 2)"
