#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

build_dir="build/guards/phase15_resource_mir"
request="/tmp/gust-phase15-resource-mir.request"
mir_to_c_witness="/tmp/gust-phase15-resource-mir.mir-to-c.witness"
worker_manifest="compiler/experiments/cranelift/Cargo.toml"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"

bash scripts/run-gust-file.sh compiler/mir_resource_value_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 15.2 canonical resource MIR smoke passed' to.log >/dev/null
for artifact in "$request" "$mir_to_c_witness"; do
  if [ ! -s "$artifact" ]; then
    echo "Phase 15.2 resource MIR smoke did not produce $artifact" >&2
    exit 1
  fi
done

cargo build --quiet --manifest-path "$worker_manifest"
"$worker" phase15-resource-mir-witness "$request" > "$build_dir/cranelift.witness"
cmp -s "$mir_to_c_witness" "$build_dir/cranelift.witness" || {
  diff -u "$mir_to_c_witness" "$build_dir/cranelift.witness" >&2 || true
  echo "Phase 15.2 MIR-to-C and Cranelift resource witnesses differ." >&2
  exit 1
}

for token in \
  'resource_operation: id=operation:declare:a kind=declare' \
  'resource_operation: id=operation:initialize:a:local kind=initialize' \
  'resource_operation: id=operation:read:a kind=read' \
  'resource_operation: id=operation:move:a kind=move' \
  'resource_operation: id=operation:close:b kind=explicit_close' \
  'resource_operation: id=operation:schedule:a kind=schedule_cleanup' \
  'resource_operation: id=operation:destroy:a kind=invoke_destructor' \
  'resource_operation: id=operation:mark_destroyed:b kind=mark_destroyed' \
  'resource_carrier: id=carrier:a:local kind=local' \
  'resource_carrier: id=carrier:a:stack kind=stack_slot' \
  'resource_carrier: id=carrier:a:branch kind=branch_argument' \
  'resource_carrier: id=carrier:a:loop kind=loop_carry' \
  'resource_carrier: id=carrier:a:field kind=aggregate_field' \
  'resource_edge: id=edge:a:loop from=loop_body to=loop_header' \
  'resource_lowering: id=operation:declare:a action=declare' \
  'resource_lowering: id=operation:move:a action=move' \
  'resource_lowering: id=operation:close:b action=explicit_close' \
  'runtime_symbol=gust_phase15_selected_resource_close' \
  'resource_lowering: id=operation:schedule:a action=schedule_cleanup' \
  'runtime_symbol=gust_resource_schedule_cleanup' \
  'resource_lowering: id=operation:destroy:a action=invoke_destructor' \
  'runtime_symbol=gust_phase15_selected_resource_destroy'
do
  rg -n -F "$token" "$mir_to_c_witness" >/dev/null
done

mutate() {
  local source="$1"
  local destination="$2"
  local mode="$3"
  python3 - "$source" "$destination" "$mode" <<'PY'
from pathlib import Path
import sys
source, destination, mode = map(Path, sys.argv[1:])
text = source.read_text()
if mode.name == "missing-resource-id":
    text = text.replace("resource_mir_value_0_resource_id: ", "resource_mir_value_0_resource_id_removed: ", 1)
elif mode.name == "copy-operation":
    text = text.replace("resource_mir_operation_3_kind: move", "resource_mir_operation_3_kind: copy", 1)
elif mode.name == "duplicate-resource-id":
    first = next(line.split(": ", 1)[1] for line in text.splitlines() if line.startswith("resource_mir_value_0_resource_id: "))
    second_line = next(line for line in text.splitlines() if line.startswith("resource_mir_value_1_resource_id: "))
    text = text.replace(second_line, f"resource_mir_value_1_resource_id: {first}", 1)
elif mode.name == "missing-edge-state":
    text = "\n".join(line for line in text.splitlines() if not line.startswith("resource_mir_edge_0_state: ")) + "\n"
elif mode.name == "layout-mismatch":
    line = next(line for line in text.splitlines() if line.startswith("resource_mir_value_0_layout_id: "))
    text = text.replace(line, "resource_mir_value_0_layout_id: layout:phase15:mismatch", 1)
elif mode.name == "explicit-resource-id":
    old_id = next(line.split(": ", 1)[1] for line in text.splitlines() if line.startswith("resource_mir_value_0_resource_id: "))
    text = text.replace(old_id, "resource:v1:compiler-selected:999")
else:
    raise SystemExit(f"unknown mutation {mode.name}")
destination.write_text(text)
PY
}

expect_failure() {
  local request_path="$1"
  local reason="$2"
  local label="$3"
  if "$worker" phase15-resource-mir-witness "$request_path" \
      > "$build_dir/$label.stdout" 2> "$build_dir/$label.stderr"
  then
    echo "Expected Phase 15.2 worker rejection for $label" >&2
    exit 1
  fi
  rg -n -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null
}


mutate "$request" "$build_dir/explicit-resource-id.request" explicit-resource-id
"$worker" phase15-resource-mir-witness "$build_dir/explicit-resource-id.request" > "$build_dir/explicit-resource-id.witness"
rg -n -F 'resource:v1:compiler-selected:999' "$build_dir/explicit-resource-id.witness" >/dev/null
rg -n -F 'local:cleanup_resource' "$build_dir/explicit-resource-id.request" >/dev/null
rg -n -F 'compiler/phase15_resource_value_source.gst:10:5' "$build_dir/explicit-resource-id.request" >/dev/null
rg -n -F 'phase15_resource_mir_fixture' "$build_dir/explicit-resource-id.request" >/dev/null

mutate "$request" "$build_dir/missing-resource-id.request" missing-resource-id
expect_failure "$build_dir/missing-resource-id.request" resource_mir_value_metadata_missing missing-resource-id

mutate "$request" "$build_dir/copy-operation.request" copy-operation
expect_failure "$build_dir/copy-operation.request" resource_mir_copy_forbidden copy-operation

mutate "$request" "$build_dir/duplicate-resource-id.request" duplicate-resource-id
expect_failure "$build_dir/duplicate-resource-id.request" resource_mir_duplicate_resource_identity duplicate-resource-id

mutate "$request" "$build_dir/missing-edge-state.request" missing-edge-state
expect_failure "$build_dir/missing-edge-state.request" resource_mir_state_missing_at_control_flow_edge missing-edge-state

mutate "$request" "$build_dir/layout-mismatch.request" layout-mismatch
expect_failure "$build_dir/layout-mismatch.request" resource_mir_type_layout_identity_mismatch layout-mismatch

echo "guard-cranelift-phase15-resource-mir-parity: ok (Level 2)"