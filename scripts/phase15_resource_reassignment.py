#!/usr/bin/env python3
"""Level 1 contract and reduced review for Patch 15.4 resource reassignment."""

from __future__ import annotations

import argparse
import csv
import json
from collections import Counter
from pathlib import Path
import sys

GUARD_ID = "guard-cranelift-phase15-resource-reassignment-contract"
PARITY_GUARD_ID = "guard-cranelift-phase15-resource-reassignment-parity"
TEST_LEVEL = "level1"
CONTRACT = Path("tests/cranelift/phase15_resource_reassignment_contract.tsv")
REVIEW = Path("tests/cranelift/phase15_resource_reassignment_review.txt")
AUTHORITY = Path("compiler/mir_resource_authority.gst")
MODEL = Path("compiler/mir_resource_reassignment.gst")
MIR_TO_C = Path("compiler/mir_resource_reassignment_mir_to_c.gst")
REQUEST = Path("compiler/mir_native_backend_resource_mir_request.gst")
FIXTURE = Path("compiler/mir_resource_reassignment_parity_smoke_test_entry.gst")
TRANSITION_SMOKE = Path("compiler/mir_resource_reassignment_state_smoke_test_entry.gst")
WORKER = Path("compiler/experiments/cranelift/src/resource_mir.rs")
PARITY = Path("scripts/phase15_resource_reassignment_parity.sh")
GUARD = Path("scripts/guard-cranelift-phase15-resource-reassignment-contract.sh")
WORKFLOW = Path(".github/workflows/phase15-resource-reassignment.yml")
LEVELS = Path("scripts/cranelift_test_levels.json")
JUSTFILE = Path("justfile")

EXPECTED = {
    "form": {"live_local", "reinitialized_moved_local", "aggregate_field", "conditional", "selected_loop"},
    "resolution": {"immediate_destroy", "scheduled_cleanup", "transfer_before_replacement"},
    "metadata": {"old_resource_id", "replacement_resource_id", "cleanup_obligation_id", "source_location", "destruction_order", "storage_id", "replacement_source_kind"},
    "rejection": {"old_live_unresolved", "old_resolution_not_in_canonical_mir", "duplicate_old_cleanup", "immutable_storage", "after_destroy_without_reinitialization", "layout_or_kind_mismatch", "copy_move_only", "old_resolved_more_than_once"},
    "comparison": {"destructor_count", "destructor_order", "resulting_resource_state", "observable_runtime_effect"},
    "composition": {"conditional_reassignment", "selected_loop_reassignment"},
    "positive": {"single_live_local_replacement", "moved_local_reinitialized_then_reassigned", "aggregate_field_replacement", "conditional_replacement", "selected_loop_replacement"},
    "consumer": {"mir_to_c_reassignment_lowering", "cranelift_reassignment_lowering"},
    "boundary": {"compiler_owned_replacement_transaction", "pre_driver_reassignment_validation", "exactly_one_live_replacement"},
    "test": {"level1_resource_reassignment_contract", "level2_resource_reassignment_parity"},
}

REASONS = {
    "resource_reassignment_old_live_unresolved",
    "resource_reassignment_duplicate_old_cleanup",
    "resource_reassignment_immutable_storage",
    "resource_reassignment_after_destroy_without_reinitialization",
    "resource_reassignment_layout_or_kind_mismatch",
    "resource_reassignment_copy_move_only",
    "resource_reassignment_old_resolved_more_than_once",
    "resource_reassignment_cleanup_obligation_missing",
    "resource_reassignment_destruction_order_invalid",
    "resource_reassignment_transfer_resolution_invalid",
    "resource_reassignment_old_resolution_not_in_canonical_mir",
}


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD_ID}: {message}")


def read(root: Path, path: Path) -> str:
    try:
        return (root / path).read_text(encoding="utf-8")
    except FileNotFoundError:
        fail(f"missing required file: {path}")


def rows(root: Path) -> list[dict[str, str]]:
    with (root / CONTRACT).open(encoding="utf-8", newline="") as handle:
        result = list(csv.DictReader(handle, delimiter="\t"))
    if not result or set(result[0]) != {"kind", "id", "owner", "test_level", "disposition"}:
        fail("contract schema mismatch")
    seen: set[tuple[str, str]] = set()
    grouped: dict[str, set[str]] = {}
    for row in result:
        key = (row["kind"], row["id"])
        if key in seen:
            fail(f"duplicate contract row: {key}")
        seen.add(key)
        if row["test_level"] != TEST_LEVEL:
            fail(f"non-Level-1 row: {key}")
        grouped.setdefault(row["kind"], set()).add(row["id"])
    if grouped != EXPECTED:
        fail(f"contract inventory mismatch: {grouped}")
    return result


def require(source: str, tokens: tuple[str, ...], owner: Path) -> None:
    for token in tokens:
        if token not in source:
            fail(f"{owner} is missing: {token}")


def check_model(root: Path) -> None:
    authority = read(root, AUTHORITY)
    require(authority, (
        "func mir_resource_cleanup_matches_resource(",
        "std.str_eq(cleanups[index].resource_id, resource_id) == 1",
        'resource_row = std.Concat(resource_row, ";kind=")',
    ), AUTHORITY)
    source = read(root, MODEL)
    require(source, (
        "type MirResourceReassignment[ctx] struct",
        "type MirResourceReassignmentTable[ctx] struct",
        'table.semantic_authority = std.Clone(ctx, "compiler_owned_replacement_transaction")',
        'table.selected_forms = std.Clone(ctx, "live_local,reinitialized_moved_local,aggregate_field,conditional,selected_loop")',
        'table.resolution_policy = std.Clone(ctx, "immediate_destroy,scheduled_cleanup,transfer_before_replacement")',
        "old_resource_id: str",
        "replacement_resource_id: str",
        "cleanup_obligation_id: str",
        "source_location: str",
        "destruction_order: int",
        "replacement_source_kind: str",
        "authority.mir_resource_cleanup_matches_resource(",
        "resource_mir.mir_resource_storage_has_moved_then_fresh_identity(",
        "resource_mir.mir_resource_reassignment_replacement_source_exists(",
        "resource_mir.mir_resource_reassignment_old_resolution_exists(",
        "resource_mir.mir_resource_reassignment_control_flow_region_exists(",
        "func mir_validate_resource_reassignment_transition(",
        "func mir_resource_reassignment_entry_count(",
        "func mir_resource_reassignment_entry_at(",
        "func mir_resource_reassignment_validate(",
        "func mir_serialize_resource_reassignment_for_request(",
        "func mir_resource_reassignment_append_to_request(",
        "func mir_resource_reassignment_witness(",
        'row = std.Concat(row, " old_result=")',
        'row = std.Concat(row, " replacement_state=")',
        'row = std.Concat(row, " effect=")',
    ), MODEL)
    for reason in REASONS:
        if reason not in source:
            fail(f"compiler reassignment validator is missing {reason}")


def check_request(root: Path) -> None:
    source = read(root, REQUEST)
    require(source, (
        "resource_mir_table: resource_mir.MirResourceMirTable[ctx]",
        "Phase 15.3 move-state validation is compiler-owned",
        "resource_mir.mir_resource_move_state_validate(",
        "func mir_serialize_native_backend_resource_mir_request(",
    ), REQUEST)
    forbidden = (
        'import "mir_resource_reassignment.gst" as reassignment;',
        "resource_reassignment_table: reassignment.MirResourceReassignmentTable[ctx]",
        "mir_native_backend_resource_mir_request_with_reassignment(",
        "request.resource_reassignment_table",
        "mir_native_backend_resource_reassignment_witness(",
    )
    for token in forbidden:
        if token in source:
            fail(f"shared resource-MIR request must not embed the reassignment sidecar: {token}")

    model = read(root, MODEL)
    fixture = read(root, FIXTURE)
    require(model, (
        "Reassignment remains a request-local sidecar owned by this defining module.",
        "func mir_resource_reassignment_append_to_request(",
        "mir_resource_reassignment_validate(table, resource_table, authority_table, ctx)",
        "mir_serialize_resource_reassignment_for_request(table, resource_table, authority_table, ctx)",
    ), MODEL)
    require(fixture, (
        "reassignment.mir_resource_reassignment_append_to_request(",
        "authority.mir_serialize_resource_authority_table_for_request(",
    ), FIXTURE)
    validate_pos = model.find("func mir_resource_reassignment_append_to_request(")
    serialize_pos = model.find("mir_serialize_resource_reassignment_for_request(table, resource_table, authority_table, ctx)", validate_pos)
    if validate_pos < 0 or serialize_pos < 0 or validate_pos > serialize_pos:
        fail("reassignment sidecar validation must precede sidecar serialization")


def check_consumers(root: Path) -> None:
    fixture = read(root, FIXTURE)
    mir_to_c = read(root, MIR_TO_C)
    worker = read(root, WORKER)
    require(fixture, (
        'replacement_reassign.form = std.Clone(ctx, "live_local")',
        'replacement_reassign.resolution_policy = std.Clone(ctx, "immediate_destroy")',
        'import "mir_resource_reassignment_mir_to_c.gst" as reassignment_mir_to_c;',
        "replacement_reassign.old_resource_id",
        "replacement_reassign.replacement_resource_id",
        "replacement_reassign.cleanup_obligation_id",
        "replacement_reassign.destruction_order = 1",
        '"carrier:reassignment:predecessor:source"',
        '"carrier:reassignment:old"',
        '"carrier:reassignment:replacement"',
        '"carrier:reassignment:old:transfer"',
        '"edge:reassignment:branch"',
        '"edge:reassignment:loop"',
        "make_flow_edge(",
        '"/tmp/gust-phase15-resource-reassignment.request"',
        '"/tmp/gust-phase15-resource-reassignment.mir-to-c.witness"',
        "reassignment.mir_resource_reassignment_append_to_request(",
        "reassignment.mir_resource_reassignment_witness(",
        "reassignment_mir_to_c.mir_resource_reassignment_to_c_source(",
        "reassignment_mir_to_c.mir_resource_reassignment_mir_to_c_witness(",
        "SUCCESS: Phase 15.4 resource reassignment parity smoke passed",
    ), FIXTURE)
    require(mir_to_c, (
        "func mir_resource_reassignment_entry_to_c(",
        "func mir_resource_reassignment_to_c_source(",
        "func mir_resource_reassignment_lowering_witness(",
        "func mir_resource_reassignment_mir_to_c_witness(",
        "reassignment.mir_resource_reassignment_entry_count(table, ctx)",
        "reassignment.mir_resource_reassignment_entry_at(table, entry_index, ctx)",
        'return "destroy_then_replace"',
        'return "schedule_then_replace"',
        'return "transfer_then_replace"',
        'row = std.Concat(row, " runtime_symbol=")',
    ), MIR_TO_C)
    if "std.Vector[reassignment.MirResourceReassignment" in mir_to_c or "ctx[table.entries]" in mir_to_c:
        fail("MIR-to-C must access reassignment entries through defining-module helpers")
    require(worker, (
        "struct ResourceReassignment",
        "resource_kind: String",
        "fn parse_resource_reassignments(",
        "fn reassignment_error(",
        "fn has_moved_then_fresh_history(",
        "fn replacement_source_exists(",
        "fn old_resolution_exists(",
        'edge.edge_id == entry.control_flow_region',
        'edge.resource_id == entry.replacement_resource_id',
        "struct CraneliftResourceReassignmentAction",
        "fn lower_resource_reassignments(",
        "fn reassignment_witness(",
        "fn reassignment_lowering_witness(",
        'key.starts_with("resource_reassignment_")',
        '"resource_reassignment_diagnostic: reassignment={} old={} replacement={} storage={} source={} policy={} order={}"',
        "parse_resource_reassignments(&contents, &table, &authority)?",
        "output.push_str(&reassignment_witness(&reassignments));",
        "output.push_str(&reassignment_lowering_witness(&reassignment_actions));",
    ), WORKER)
    for reason in REASONS:
        if reason not in worker:
            fail(f"Cranelift reassignment consumer is missing {reason}")


def check_parity(root: Path) -> None:
    transition_smoke = read(root, TRANSITION_SMOKE)
    require(transition_smoke, (
        'expect_transition("immediate_destroy", 1, "live", "destroyed"',
        'expect_transition("scheduled_cleanup", 1, "live", "cleanup_scheduled"',
        'expect_transition("transfer_before_replacement", 1, "live", "moved"',
        "resource_reassignment_old_live_unresolved",
        "resource_reassignment_immutable_storage",
        "resource_reassignment_after_destroy_without_reinitialization",
        "resource_reassignment_copy_move_only",
        "resource_reassignment_old_destroy_resolution_invalid",
        "resource_reassignment_old_schedule_resolution_invalid",
        "resource_reassignment_transfer_resolution_invalid",
        "SUCCESS: Phase 15.4 resource reassignment transitions passed",
    ), TRANSITION_SMOKE)
    source = read(root, PARITY)
    require(source, (
        "compiler/mir_resource_reassignment_state_smoke_test_entry.gst",
        "compiler/mir_resource_reassignment_parity_smoke_test_entry.gst",
        'request="/tmp/gust-phase15-resource-reassignment.request"',
        'mir_to_c_witness="/tmp/gust-phase15-resource-reassignment.mir-to-c.witness"',
        "grep '^resource_reassignment'",
        "Phase 15.4 MIR-to-C and Cranelift reassignment witnesses differ.",
        "resource_reassignment_lowering_witness: accepted",
        "action=destroy_then_replace",
        "runtime_symbol=gust_phase15_reassignment_resource_destroy",
        "destructor=destructor:phase15:reassignment_resource",
        "id=reassignment:phase15:live-local",
        "order=1",
        "replacement_state=live",
        "aggregate-field",
        "conditional",
        "selected-loop",
        "reinitialized-moved-local",
        '"edge:reassignment:branch"',
        '"edge:reassignment:loop"',
        'predecessor_carrier = "carrier:reassignment:predecessor:source"',
        'set_field(prefix + "predecessor_moved_resource_id", predecessor_resource)',
        "scheduled-cleanup",
        "transfer-before-replacement",
        'transfer_carrier = "carrier:reassignment:old:transfer"',
        'set_field(schedule_base + "_kind", "move")',
        'set_field(destroy_base + "_kind", "read")',
        "old-unresolved",
        "duplicate-cleanup",
        "immutable-storage",
        "after-destroyed",
        "layout-mismatch",
        "kind-mismatch",
        "copy-move-only",
        "missing-cleanup",
        "missing-resolution-operation",
        "old-resolved-twice",
        "bad-order",
        "bad-transfer",
        "guard-cranelift-phase15-resource-reassignment-parity: ok (Level 2)",
    ), PARITY)


def check_wiring(root: Path) -> None:
    levels = json.loads(read(root, LEVELS))
    mapping = levels.get("guards", levels)
    if mapping.get(GUARD_ID) != 1 or mapping.get(PARITY_GUARD_ID) != 2:
        fail("test-level registry must classify contract=1 and parity=2")
    justfile = read(root, JUSTFILE)
    require(justfile, (
        f"{GUARD_ID}:",
        f"{PARITY_GUARD_ID}:",
        "python3 scripts/phase15_resource_reassignment.py --check",
        "bash scripts/phase15_resource_reassignment_parity.sh",
        f"grep -F $'{GUARD_ID}\\t1\\t'",
        f"grep -F $'{PARITY_GUARD_ID}\\t2\\t'",
    ), JUSTFILE)
    workflow = read(root, WORKFLOW)
    require(workflow, (
        "name: Cranelift Phase 15 Resource Reassignment",
        "compiler/mir_resource_value.gst",
        "compiler/mir_resource_reassignment_mir_to_c.gst",
        "compiler/mir_resource_reassignment_parity_smoke_test_entry.gst",
        "Phase 15.4 resource reassignment contract (Level 1)",
        "Phase 15.4 resource reassignment parity (Level 2)",
        f"run: just {GUARD_ID}",
        f"run: just {PARITY_GUARD_ID}",
    ), WORKFLOW)
    if "python3 scripts/phase15_resource_reassignment.py --check" not in read(root, GUARD):
        fail("guard shell does not invoke checker")


def render(result: list[dict[str, str]]) -> str:
    counts = Counter(row["kind"] for row in result)
    lines = [
        "Phase 15.4 — Resource Reassignment Semantics",
        f"guard: {GUARD_ID}",
        f"parity_guard: {PARITY_GUARD_ID}",
        f"rows: {len(result)}",
        "test_levels: contract=Level 1 parity=Level 2",
        "",
        "Inventory",
    ]
    for kind in EXPECTED:
        lines.append(f"- {kind}: {counts[kind]}")
    lines.extend([
        "",
        "Replacement authority",
        "- each transaction names old and replacement resource identities and one shared mutable storage",
        "- the old value is destroyed, scheduled, or transferred exactly once before replacement publication",
        "- immediate and scheduled destruction use explicit monotonically ordered destructor slots",
        "",
        "Rejection",
        "- unresolved old ownership, duplicate cleanup, immutable storage, destroyed old values, mismatched layout/kind, and move-only copies reject",
        "- validation runs before driver discovery and request publication",
        "",
        "Parity",
        "- MIR-to-C and Cranelift emit the same reassignment witness",
        "- destructor count, order, resulting state, and observable effect are compared",
        "- branch, selected-loop, aggregate-field, moved-storage reinitialization, scheduling, and transfer forms are exercised",
    ])
    return "\n".join(lines) + "\n"


def run(root: Path, write: bool) -> None:
    result = rows(root)
    check_model(root)
    check_request(root)
    check_consumers(root)
    check_parity(root)
    check_wiring(root)
    review = render(result)
    path = root / REVIEW
    if write:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(review, encoding="utf-8")
    elif path.read_text(encoding="utf-8") != review:
        fail(f"generated review is stale: run {Path(__file__).as_posix()} --write")
    print(f"{GUARD_ID}: ok ({len(result)} rows, Level 1)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--write", action="store_true")
    args = parser.parse_args()
    run(args.root.resolve(), args.write)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"{GUARD_ID}: {error}", file=sys.stderr)
        raise SystemExit(1)
