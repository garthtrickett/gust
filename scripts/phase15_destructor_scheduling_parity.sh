#!/usr/bin/env bash
set -euo pipefail
request="/tmp/gust-phase15-destructor-scheduling.request"
mir_to_c="/tmp/gust-phase15-destructor-scheduling.mir-to-c.witness"
build_dir="build/guards/phase15_destructor_scheduling"
worker_manifest="compiler/experiments/cranelift/Cargo.toml"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
rm -rf "$build_dir"; rm -f "$request" "$mir_to_c"; mkdir -p "$build_dir"
bash scripts/run-gust-file.sh compiler/mir_destructor_scheduling_state_smoke_test_entry.gst
grep -F 'SUCCESS: Phase 15.7 destructor scheduling state policy passed' to.log >/dev/null
bash scripts/run-gust-file.sh compiler/mir_destructor_scheduling_parity_smoke_test_entry.gst
grep -F 'SUCCESS: Phase 15.7 destructor scheduling parity smoke passed' to.log >/dev/null
test -s "$request"; test -s "$mir_to_c"
cargo build --quiet --manifest-path "$worker_manifest"
"$worker" phase15-destructor-scheduling-witness "$request" >"$build_dir/cranelift.witness"
diff -u "$mir_to_c" "$build_dir/cranelift.witness"
for token in 'resource=resource:scope:inner destructor=destructor:file reason=scope_exit schedule_count=1 cancel_count=0 execution_count=1 order=1' 'resource=resource:scope:outer destructor=destructor:file reason=scope_exit schedule_count=1 cancel_count=0 execution_count=1 order=2' 'resource=resource:early:return destructor=destructor:socket reason=early_return schedule_count=1 cancel_count=0 execution_count=1 order=3' 'resource=resource:transferred destructor=destructor:socket reason=ownership_transfer schedule_count=1 cancel_count=1 execution_count=0 order=0' 'destructor_scheduling_exactly_once_witness: schedule_count=4 cancel_count=1 execution_count=3 order_preserved=1 observable_effects_preserved=1 exactly_once=1'; do grep -F "$token" "$build_dir/cranelift.witness" >/dev/null; done
cp "$request" "$build_dir/base.request"
mutate() {
  local mode="$1" output="$2"
  python3 - "$build_dir/base.request" "$output" "$mode" <<'PYM'
from pathlib import Path
import sys
source=Path(sys.argv[1]).read_text(); output=Path(sys.argv[2]); mode=sys.argv[3]
def value(k):
 p=k+": "; return next(line[len(p):] for line in source.splitlines() if line.startswith(p))
def replace(k,n):
 global source; source=source.replace(f"{k}: {value(k)}",f"{k}: {n}",1)
m={"duplicate-live-schedule":("destructor_scheduling_entry_0_schedule_count","2"),"execute-without-schedule":("destructor_scheduling_entry_0_schedule_count","0"),"schedule-after-destroy":("destructor_scheduling_entry_0_schedule_sequence","22"),"destructor-mismatch":("destructor_scheduling_entry_0_execution_destructor_id","destructor:wrong"),"skipped-destruction":("destructor_scheduling_entry_0_execution_count","0"),"destroy-moved":("destructor_scheduling_entry_3_execution_count","1"),"order-drift":("destructor_scheduling_entry_1_execution_order","3"),"missing-transfer-cancel":("destructor_scheduling_entry_3_cancel_count","0")}
replace(*m[mode]); output.write_text(source)
PYM
}
expect_failure() { local mode="$1" reason="$2" path="$build_dir/$mode.request"; mutate "$mode" "$path"; if "$worker" phase15-destructor-scheduling-witness "$path" >"$build_dir/$mode.stdout" 2>"$build_dir/$mode.stderr"; then echo "Phase 15.7 mutation unexpectedly passed: $mode" >&2; exit 1; fi; grep -F "reason=$reason" "$build_dir/$mode.stderr" >/dev/null || { cat "$build_dir/$mode.stderr" >&2; exit 1; }; }
expect_failure duplicate-live-schedule destructor_duplicate_live_schedule
expect_failure execute-without-schedule destructor_execution_without_schedule
expect_failure schedule-after-destroy destructor_schedule_after_destroy
expect_failure destructor-mismatch destructor_identity_mismatch
expect_failure skipped-destruction destructor_live_resource_skipped
expect_failure destroy-moved destructor_moved_ownership_destroyed
expect_failure order-drift destructor_order_drift
expect_failure missing-transfer-cancel destructor_transfer_schedule_not_canceled
echo "guard-cranelift-phase15-destructor-scheduling-parity: ok (Level 2)"