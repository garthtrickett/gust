#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

build_dir="build/guards/phase15_resource_reassignment"
request="/tmp/gust-phase15-resource-reassignment.request"
mir_to_c_witness="/tmp/gust-phase15-resource-reassignment.mir-to-c.witness"
worker_manifest="compiler/experiments/cranelift/Cargo.toml"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"

bash scripts/run-gust-file.sh compiler/mir_resource_reassignment_state_smoke_test_entry.gst
grep -F 'SUCCESS: Phase 15.4 resource reassignment transitions passed' to.log >/dev/null
bash scripts/run-gust-file.sh compiler/mir_resource_reassignment_parity_smoke_test_entry.gst
grep -F 'SUCCESS: Phase 15.4 resource reassignment parity smoke passed' to.log >/dev/null
for artifact in "$request" "$mir_to_c_witness"; do
  test -s "$artifact" || { echo "Phase 15.4 fixture did not produce $artifact" >&2; exit 1; }
done

cargo build --quiet --manifest-path "$worker_manifest"
"$worker" phase15-resource-mir-witness "$request" >"$build_dir/cranelift.full.witness"
grep '^resource_reassignment' "$mir_to_c_witness" >"$build_dir/mir-to-c.reassignment.witness"
grep '^resource_reassignment' "$build_dir/cranelift.full.witness" >"$build_dir/cranelift.reassignment.witness"
cmp -s "$build_dir/mir-to-c.reassignment.witness" "$build_dir/cranelift.reassignment.witness" || {
  diff -u "$build_dir/mir-to-c.reassignment.witness" "$build_dir/cranelift.reassignment.witness" >&2 || true
  echo "Phase 15.4 MIR-to-C and Cranelift reassignment witnesses differ." >&2
  exit 1
}

for token in \
  'resource_reassignment_witness: accepted' \
  'resource_reassignment_lowering_witness: accepted' \
  'action=destroy_then_replace' \
  'runtime_symbol=gust_phase15_reassignment_resource_destroy' \
  'id=reassignment:phase15:live-local' \
  'form=live_local' \
  'policy=immediate_destroy' \
  'cleanup=cleanup:' \
  'destructor=destructor:phase15:reassignment_resource' \
  'order=1' \
  'old_result=destroyed' \
  'replacement_state=live' \
  'effect=destroy_old_then_publish_replacement'
do
  grep -F "$token" "$build_dir/mir-to-c.reassignment.witness" >/dev/null
done
if [ "$(grep -c '^resource_reassignment: ' "$build_dir/mir-to-c.reassignment.witness")" != "1" ]; then
  echo "Phase 15.4 expected exactly one compiler-owned replacement transaction." >&2
  exit 1
fi
if [ "$(grep -c '^resource_reassignment_lowering: ' "$build_dir/mir-to-c.reassignment.witness")" != "1" ]; then
  echo "Phase 15.4 expected exactly one backend replacement action." >&2
  exit 1
fi

mutate() {
  local source="$1"
  local destination="$2"
  local mode="$3"
  python3 - "$source" "$destination" "$mode" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1])
destination = Path(sys.argv[2])
mode = sys.argv[3]
lines = source.read_text().splitlines()


def split_field(line: str):
    return line.split(": ", 1) if ": " in line else (line, "")


def set_field(key: str, value: str):
    for index, line in enumerate(lines):
        current, _ = split_field(line)
        if current == key:
            lines[index] = f"{key}: {value}"
            return
    raise SystemExit(f"missing field {key}")


def get_field(key: str) -> str:
    for line in lines:
        current, value = split_field(line)
        if current == key:
            return value
    raise SystemExit(f"missing field {key}")


def carrier_prefix(carrier_id: str) -> str:
    for line in lines:
        key, value = split_field(line)
        if key.startswith("resource_mir_carrier_") and key.endswith("_carrier_id") and value == carrier_id:
            return key[:-len("_carrier_id")]
    raise SystemExit(f"missing carrier {carrier_id}")


def value_prefix(value_id: str) -> str:
    for line in lines:
        key, value = split_field(line)
        if key.startswith("resource_mir_value_") and key.endswith("_value_id") and value == value_id:
            return key[:-len("_value_id")]
    raise SystemExit(f"missing value {value_id}")


def operation_prefix(operation_id: str) -> str:
    for line in lines:
        key, value = split_field(line)
        if key.startswith("resource_mir_operation_") and key.endswith("_operation_id") and value == operation_id:
            return key[:-len("_operation_id")]
    raise SystemExit(f"missing operation {operation_id}")


def clone_entry(index: int, overrides: dict[str, str]):
    fields = {}
    source_prefix = "resource_reassignment_0_"
    for line in lines:
        key, value = split_field(line)
        if key.startswith(source_prefix):
            fields[key[len(source_prefix):]] = value
    fields.update(overrides)
    for field, value in fields.items():
        lines.append(f"resource_reassignment_{index}_{field}: {value}")


def replace_authority_state(resource_id: str, point: str, state: str):
    prefix = f"resource_state: resource={resource_id};point={point};state="
    for index, line in enumerate(lines):
        if line.startswith(prefix):
            lines[index] = prefix + state
            return
    raise SystemExit(f"missing authority state {resource_id} {point}")


def replace_authority_transition(resource_id: str, point: str, operation: str, prior: str, result: str, cleanup_id: str = ""):
    needle = f";resource={resource_id};"
    point_needle = f";point={point}"
    for index, line in enumerate(lines):
        if line.startswith("resource_transition: ") and needle in line and point_needle in line:
            transition_id = f"resource_transition:v1:resource={resource_id}:operation={operation}:point={point}"
            lines[index] = (
                f"resource_transition: id={transition_id};resource={resource_id};prior={prior};"
                f"operation={operation};result={result};point={point}"
            )
            if cleanup_id:
                lines[index] += f";cleanup={cleanup_id}"
            return
    raise SystemExit(f"missing authority transition {resource_id} {point}")


prefix = "resource_reassignment_0_"
old_resource = get_field(prefix + "old_resource_id")
old_value = get_field(prefix + "old_value_id")
old_carrier = get_field(prefix + "old_carrier_id")
replacement_resource = get_field(prefix + "replacement_resource_id")
replacement_value = get_field(prefix + "replacement_value_id")
replacement_carrier = get_field(prefix + "replacement_carrier_id")

if mode == "aggregate-field":
    set_field(prefix + "form", "aggregate_field")
    set_field(carrier_prefix(old_carrier) + "_kind", "aggregate_field")
    set_field(carrier_prefix(replacement_carrier) + "_kind", "aggregate_field")
elif mode == "conditional":
    set_field(prefix + "form", "conditional")
    set_field(prefix + "control_flow_region", "edge:reassignment:branch")
elif mode == "selected-loop":
    set_field(prefix + "form", "selected_loop")
    set_field(prefix + "control_flow_region", "edge:reassignment:loop")
elif mode == "reinitialized-moved-local":
    predecessor_carrier = "carrier:reassignment:predecessor:source"
    predecessor_resource = get_field(carrier_prefix(predecessor_carrier) + "_resource_id")
    set_field(prefix + "form", "reinitialized_moved_local")
    set_field(prefix + "predecessor_moved_resource_id", predecessor_resource)
elif mode == "scheduled-cleanup":
    set_field(prefix + "resolution_policy", "scheduled_cleanup")
    set_field(prefix + "old_resulting_state", "cleanup_scheduled")
    set_field(prefix + "observable_effect", "schedule_old_then_publish_replacement")
elif mode == "transfer-before-replacement":
    transfer_carrier = "carrier:reassignment:old:transfer"
    schedule_base = operation_prefix("operation:reassignment:old:schedule")
    destroy_base = operation_prefix("operation:reassignment:old:destroy")
    schedule_point = get_field(schedule_base + "_program_point")
    destroy_point = get_field(destroy_base + "_program_point")

    set_field(schedule_base + "_kind", "move")
    set_field(schedule_base + "_source_carrier_id", old_carrier)
    set_field(schedule_base + "_destination_carrier_id", transfer_carrier)
    set_field(schedule_base + "_prior_state", "live")
    set_field(schedule_base + "_resulting_state", "moved")
    set_field(schedule_base + "_cleanup_id", "")
    set_field(schedule_base + "_destructor_id", "")
    set_field(schedule_base + "_close_capability_id", "")

    set_field(destroy_base + "_kind", "read")
    set_field(destroy_base + "_source_carrier_id", transfer_carrier)
    set_field(destroy_base + "_destination_carrier_id", "")
    set_field(destroy_base + "_prior_state", "live")
    set_field(destroy_base + "_resulting_state", "live")
    set_field(destroy_base + "_cleanup_id", "")
    set_field(destroy_base + "_destructor_id", "")
    set_field(destroy_base + "_close_capability_id", "")

    set_field(value_prefix(old_value) + "_current_state", "live")
    set_field(carrier_prefix(old_carrier) + "_current_state", "moved")
    set_field(carrier_prefix(transfer_carrier) + "_current_state", "live")
    replace_authority_state(old_resource, destroy_point, "live")
    replace_authority_transition(old_resource, schedule_point, "move", "live", "moved")
    replace_authority_transition(old_resource, destroy_point, "use", "live", "live")

    set_field(prefix + "resolution_policy", "transfer_before_replacement")
    set_field(prefix + "transfer_destination_carrier_id", transfer_carrier)
    set_field(prefix + "destructor_id", "")
    set_field(prefix + "destruction_order", "0")
    set_field(prefix + "old_resulting_state", "moved")
    set_field(prefix + "observable_effect", "transfer_old_then_publish_replacement")
elif mode == "old-unresolved":
    set_field(prefix + "resolution_policy", "silent_replace")
elif mode == "duplicate-cleanup":
    set_field("resource_reassignment_count", "2")
    clone_entry(1, {
        "id": "reassignment:phase15:duplicate-cleanup",
        "old_resource_id": replacement_resource,
        "old_value_id": replacement_value,
        "old_carrier_id": replacement_carrier,
        "replacement_resource_id": old_resource,
        "replacement_value_id": old_value,
        "replacement_carrier_id": old_carrier,
        "destruction_order": "2",
    })
elif mode == "immutable-storage":
    set_field(prefix + "mutable_storage", "0")
elif mode == "after-destroyed":
    set_field(prefix + "old_prior_state", "destroyed")
elif mode == "layout-mismatch":
    replacement_layout = "layout:phase15:reassignment:mismatch"
    set_field(value_prefix(replacement_value) + "_layout_id", replacement_layout)
    for line in list(lines):
        key, value = split_field(line)
        if key.startswith("resource_mir_carrier_") and key.endswith("_resource_id") and value == replacement_resource:
            set_field(key[:-len("_resource_id")] + "_layout_id", replacement_layout)
    for index, line in enumerate(lines):
        if line.startswith("resource_record: ") and f"id={replacement_resource};" in line:
            head, _ = line.rsplit(";layout=", 1)
            lines[index] = head + ";layout=" + replacement_layout
            break
    else:
        raise SystemExit("replacement authority record missing")
elif mode == "kind-mismatch":
    for index, line in enumerate(lines):
        if line.startswith("resource_record: ") and f"id={replacement_resource};" in line:
            head, tail = line.split(";kind=", 1)
            _, remainder = tail.split(";", 1)
            lines[index] = head + ";kind=directory_resource;" + remainder
            break
    else:
        raise SystemExit("replacement authority record missing")
elif mode == "copy-move-only":
    set_field(prefix + "replacement_source_kind", "copy")
elif mode == "missing-cleanup":
    set_field(prefix + "cleanup_obligation_id", "cleanup:phase15:missing")
elif mode == "missing-resolution-operation":
    replacement_cleanup = "cleanup:phase15:reassignment:unlinked"
    destructor_id = get_field(prefix + "destructor_id")
    lines.append(
        f"cleanup_record: id={replacement_cleanup};resource={old_resource};"
        f"destructor={destructor_id};scope_exit=scope_exit:phase15_reassignment_unlinked;order=1"
    )
    set_field("resource_authority_cleanup_count", str(int(get_field("resource_authority_cleanup_count")) + 1))
    set_field(prefix + "cleanup_obligation_id", replacement_cleanup)
elif mode == "old-resolved-twice":
    set_field("resource_reassignment_count", "2")
    clone_entry(1, {
        "id": "reassignment:phase15:old-twice",
        "cleanup_obligation_id": "cleanup:phase15:unique-old-twice",
        "destruction_order": "2",
    })
elif mode == "bad-order":
    set_field(prefix + "destruction_order", "0")
elif mode == "bad-transfer":
    set_field(prefix + "resolution_policy", "transfer_before_replacement")
    set_field(prefix + "old_resulting_state", "moved")
    set_field(prefix + "destruction_order", "0")
    set_field(prefix + "destructor_id", "")
    set_field(prefix + "transfer_destination_carrier_id", "")
else:
    raise SystemExit(f"unknown mutation {mode}")

destination.write_text("\n".join(lines) + "\n")
PY
}

expect_success() {
  local mode="$1"
  local token="$2"
  local path="$build_dir/$mode.request"
  mutate "$request" "$path" "$mode"
  "$worker" phase15-resource-mir-witness "$path" >"$build_dir/$mode.stdout" 2>"$build_dir/$mode.stderr"
  grep '^resource_reassignment: ' "$build_dir/$mode.stdout" | grep -F "$token" >/dev/null
  grep '^resource_reassignment_lowering: ' "$build_dir/$mode.stdout" >/dev/null
}

expect_failure() {
  local mode="$1"
  local reason="$2"
  local path="$build_dir/$mode.request"
  mutate "$request" "$path" "$mode"
  if "$worker" phase15-resource-mir-witness "$path" >"$build_dir/$mode.stdout" 2>"$build_dir/$mode.stderr"; then
    echo "Expected Phase 15.4 reassignment rejection for $mode" >&2
    exit 1
  fi
  grep -F "reason=$reason" "$build_dir/$mode.stderr" >/dev/null
  grep -F 'resource_reassignment_diagnostic:' "$build_dir/$mode.stderr" >/dev/null
}

expect_success aggregate-field 'form=aggregate_field'
expect_success conditional 'form=conditional'
expect_success selected-loop 'form=selected_loop'
expect_success reinitialized-moved-local 'form=reinitialized_moved_local'
expect_success scheduled-cleanup 'policy=scheduled_cleanup'
expect_success transfer-before-replacement 'policy=transfer_before_replacement'

expect_failure old-unresolved resource_reassignment_old_live_unresolved
expect_failure duplicate-cleanup resource_reassignment_duplicate_old_cleanup
expect_failure immutable-storage resource_reassignment_immutable_storage
expect_failure after-destroyed resource_reassignment_after_destroy_without_reinitialization
expect_failure layout-mismatch resource_reassignment_layout_or_kind_mismatch
expect_failure kind-mismatch resource_reassignment_layout_or_kind_mismatch
expect_failure copy-move-only resource_reassignment_copy_move_only
expect_failure missing-cleanup resource_reassignment_cleanup_obligation_missing
expect_failure missing-resolution-operation resource_reassignment_old_resolution_not_in_canonical_mir
expect_failure old-resolved-twice resource_reassignment_old_resolved_more_than_once
expect_failure bad-order resource_reassignment_destruction_order_invalid
expect_failure bad-transfer resource_reassignment_transfer_resolution_invalid

echo "guard-cranelift-phase15-resource-reassignment-parity: ok (Level 2)"