#!/usr/bin/env python3
"""Level 1 contract and reduced review for Patch 15.2 canonical resource MIR."""

from __future__ import annotations

import argparse
import csv
from collections import Counter
from pathlib import Path
import re
import sys

GUARD_ID = "guard-cranelift-phase15-resource-mir-contract"
PARITY_GUARD_ID = "guard-cranelift-phase15-resource-mir-parity"
TEST_LEVEL = "level1"
CONTRACT = Path("tests/cranelift/phase15_resource_mir_contract.tsv")
REVIEW = Path("tests/cranelift/phase15_resource_mir_review.txt")
RESOURCE_MIR = Path("compiler/mir_resource_value.gst")
AUTHORITY = Path("compiler/mir_resource_authority.gst")
MIR = Path("compiler/mir.gst")
REQUEST = Path("compiler/mir_native_backend_resource_mir_request.gst")
MIR_TO_C = Path("compiler/mir_resource_value_mir_to_c.gst")
WORKER = Path("compiler/experiments/cranelift/src/resource_mir.rs")
WORKER_MAIN = Path("compiler/experiments/cranelift/src/main.rs")
SMOKE = Path("compiler/mir_resource_value_smoke_test_entry.gst")
PARITY = Path("scripts/phase15_resource_mir_parity.sh")
WORKFLOW = Path(".github/workflows/phase15-resource-mir.yml")
LEVELS = Path("scripts/cranelift_test_levels.json")
JUSTFILE = Path("justfile")

EXPECTED_OPERATIONS = {
    "resource_declaration": ("Declare", 'return "declare";'),
    "resource_initialization": ("Initialize", 'return "initialize";'),
    "resource_read": ("Read", 'return "read";'),
    "resource_move": ("Move", 'return "move";'),
    "explicit_close": ("ExplicitClose", 'return "explicit_close";'),
    "cleanup_scheduling": ("ScheduleCleanup", 'return "schedule_cleanup";'),
    "destructor_invocation": ("InvokeDestructor", 'return "invoke_destructor";'),
    "destroyed_state_marker": ("MarkDestroyed", 'return "mark_destroyed";'),
}
EXPECTED_METADATA = {
    "resource_id": "resource_id: str",
    "resource_type": "resource_type_id: str",
    "layout_id": "layout_id: str",
    "owning_scope": "owning_scope: str",
    "source_location": "source_location: str",
    "current_state": "current_state: str",
    "destructor_or_close_policy": "cleanup_policy: str",
}
EXPECTED_CARRIERS = {
    "local_assignment": ("Local", 'return "local";'),
    "stack_slot": ("StackSlot", 'return "stack_slot";'),
    "branch_argument": ("BranchArgument", 'return "branch_argument";'),
    "selected_loop_carry": ("LoopCarry", 'return "loop_carry";'),
    "layout_supported_aggregate_field": ("AggregateField", 'return "aggregate_field";'),
}
EXPECTED_REJECTIONS = {
    "resource_value_without_metadata": "resource_mir_value_metadata_missing",
    "copy_non_copy_resource": "resource_mir_copy_forbidden",
    "duplicate_resource_identity": "resource_mir_duplicate_resource_identity",
    "state_missing_at_control_flow_edge": "resource_mir_state_missing_at_control_flow_edge",
    "resource_type_layout_identity_mismatch": "resource_mir_type_layout_identity_mismatch",
}
EXPECTED_CONSUMERS = {
    "mir_to_c_canonical_operations": "func mir_resource_operation_to_c(",
    "cranelift_canonical_operations": "fn lower_for_cranelift(",
}
EXPECTED_HARD_BANS = {
    "worker_no_source_text_identity",
    "worker_no_local_name_identity",
    "worker_no_fixture_name_identity",
}
EXPECTED_TESTS = {
    "level1_resource_mir_contract",
    "level2_resource_value_parity",
}


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD_ID}: {message}")


def read_text(root: Path, path: Path) -> str:
    full = root / path
    try:
        return full.read_text(encoding="utf-8")
    except FileNotFoundError:
        fail(f"missing required file: {path}")


def load_rows(root: Path) -> list[dict[str, str]]:
    path = root / CONTRACT
    try:
        with path.open(encoding="utf-8", newline="") as handle:
            rows = list(csv.DictReader(handle, delimiter="\t"))
    except FileNotFoundError:
        fail(f"missing required file: {CONTRACT}")
    required = {"kind", "id", "owner", "test_level", "disposition"}
    if not rows or set(rows[0]) != required:
        fail(f"{CONTRACT} has an unexpected schema")
    seen: set[tuple[str, str]] = set()
    for row in rows:
        key = (row["kind"], row["id"])
        if key in seen:
            fail(f"duplicate contract row: {key[0]}:{key[1]}")
        seen.add(key)
        if row["test_level"] != TEST_LEVEL:
            fail(f"non-Level-1 row: {row['id']}")
    return rows


def require_inventory(rows: list[dict[str, str]]) -> None:
    by_kind: dict[str, set[str]] = {}
    for row in rows:
        by_kind.setdefault(row["kind"], set()).add(row["id"])
    expected = {
        "operation": set(EXPECTED_OPERATIONS),
        "metadata": set(EXPECTED_METADATA),
        "carrier": set(EXPECTED_CARRIERS),
        "rejection": set(EXPECTED_REJECTIONS),
        "consumer": set(EXPECTED_CONSUMERS),
        "hard_ban": EXPECTED_HARD_BANS,
        "test": EXPECTED_TESTS,
    }
    for kind, ids in expected.items():
        actual = by_kind.get(kind, set())
        if actual != ids:
            fail(f"{kind} inventory mismatch: expected {sorted(ids)}, got {sorted(actual)}")


def check_resource_mir(root: Path) -> None:
    source = read_text(root, RESOURCE_MIR)
    for token in (
        "type MirResourceValue[ctx] struct",
        "type MirResourceCarrier[ctx] struct",
        "type MirResourceOperation[ctx] struct",
        "type MirResourceFlowEdge[ctx] struct",
        "type MirResourceMirTable[ctx] struct",
        'table.format = std.Clone(ctx, "gust.compiler_resource_mir.v1")',
        'table.semantic_authority = std.Clone(ctx, "compiler_owned_resource_identity_and_state")',
        'table.identity_policy = std.Clone(ctx, "explicit_resource_id_only_no_backend_derivation")',
        'table.copy_policy = std.Clone(ctx, "non_copy_resources_move_only")',
        'table.edge_state_policy = std.Clone(ctx, "explicit_state_on_every_selected_resource_edge")',
        "func mir_resource_mir_table_validate(",
        "authority.mir_resource_by_id(",
        "authority.mir_validate_resource_transition(",
        "layout.mir_layout_of(",
        "func mir_serialize_resource_mir_for_request(",
        "func mir_resource_mir_witness(",
    ):
        if token not in source:
            fail(f"canonical resource MIR is missing: {token}")
    for item, (variant, spelling) in EXPECTED_OPERATIONS.items():
        if variant not in source or spelling not in source:
            fail(f"missing canonical resource operation {item}")
    for item, token in EXPECTED_METADATA.items():
        if token not in source:
            fail(f"missing resource value metadata {item}")
    for item, (variant, spelling) in EXPECTED_CARRIERS.items():
        if variant not in source or spelling not in source:
            fail(f"missing resource carrier {item}")
    for item, reason in EXPECTED_REJECTIONS.items():
        if reason == "resource_mir_copy_forbidden":
            continue
        if reason not in source:
            fail(f"missing compiler rejection {item}")
    if re.search(r"\bCopy\b", source):
        fail("canonical resource operation enum must not contain a copy operation")


def check_authority_extension(root: Path) -> None:
    source = read_text(root, AUTHORITY)
    for token in (
        "func mir_resource_cleanup_has_terminal_transition(",
        'mut state_row := "resource_state: resource=";',
        'resource_row = std.Concat(resource_row, ";close=");',
        'mut destructor_row := "destructor_record: id=";',
        'mut close_row := "close_capability_record: id=";',
    ):
        if token not in source:
            fail(f"Phase 15.1 authority extension is missing: {token}")


def check_mir_integration(root: Path) -> None:
    source = read_text(root, MIR)
    for token in (
        'import "mir_resource_value.gst" as resource_mir;',
        "The complete resource MIR table remains a",
        "request-local sidecar owned by mir_resource_value.gst",
        "ResourceOperation {",
        "operation: Index[resource_mir.MirResourceOperation[ctx], ctx]",
        "ResourceRead {",
        "value: Index[resource_mir.MirResourceValue[ctx], ctx]",
        "func mir_make_stmt_resource_operation(",
        "func mir_make_value_resource_read(",
    ):
        if token not in source:
            fail(f"canonical MIR integration is missing: {token}")

    forbidden_program_table_tokens = (
        "resource_value_references:",
        "resource_carrier_references:",
        "resource_operation_references:",
        "resource_flow_edge_references:",
        "func mir_empty_resource_value_reference_vector(",
        "func mir_empty_resource_carrier_reference_vector(",
        "func mir_empty_resource_operation_reference_vector(",
        "func mir_empty_resource_flow_edge_reference_vector(",
        "func mir_program_resource_mir_table(",
    )
    for token in forbidden_program_table_tokens:
        if token in source:
            fail(
                "MirProgram must not embed module-qualified resource table vectors: "
                + token
            )


def check_request(root: Path) -> None:
    source = read_text(root, REQUEST)
    for token in (
        "type MirNativeBackendResourceMirRequest[ctx] struct",
        "resource_mir_table:",
        "func mir_native_backend_resource_mir_request_is_valid(",
        "resource_mir.mir_resource_mir_table_validate(",
        "func mir_serialize_native_backend_resource_mir_request(",
        "resource_mir.mir_serialize_resource_mir_for_request(",
        "resource_request.mir_serialize_native_backend_resource_request(",
    ):
        if token not in source:
            fail(f"native request resource MIR transport is missing: {token}")
    resource_pos = source.find("resource_mir.mir_serialize_resource_mir_for_request(")
    authority_pos = source.find("resource_request.mir_serialize_native_backend_resource_request(")
    if resource_pos < 0 or authority_pos < 0 or resource_pos > authority_pos:
        fail("canonical resource MIR must serialize before the Phase 15.1 request envelope")


def check_consumers(root: Path) -> None:
    c_source = read_text(root, MIR_TO_C)
    worker = read_text(root, WORKER)
    main = read_text(root, WORKER_MAIN)
    for token in (
        "func mir_resource_operation_to_c(",
        "func mir_resource_mir_to_c_source(",
        "resource_mir.mir_resource_mir_table_validate(",
        "resource_mir.mir_resource_mir_witness(",
    ):
        if token not in c_source:
            fail(f"MIR-to-C canonical consumer is missing: {token}")
    for tag in range(8):
        token = f"operation.operation_kind.tag == {tag}"
        if token not in c_source:
            fail(f"MIR-to-C does not consume canonical operation tag {tag}")
    for token in (
        "enum ResourceOperationKind",
        '"copy" => Err(ResourceMirError::new(',
        '"resource_mir_copy_forbidden"',
        "enum CraneliftResourceAction",
        "fn parse_authority_tables(",
        "fn validate_operation_transition(",
        "fn lower_for_cranelift(",
        "runtime_symbol: close.runtime_symbol.clone()",
        "runtime_symbol: destructor.runtime_symbol.clone()",
        '"resource_lowering: id={} action={}',
        "pub fn lower_resource_mir_witness_path(",
        "required_field(&fields, &format!(\"{prefix}_resource_id\"))",
    ):
        if token not in worker:
            fail(f"Cranelift canonical consumer is missing: {token}")
    if "mod resource_mir;" not in main or '"phase15-resource-mir-witness"' not in main:
        fail("Cranelift CLI does not expose the canonical resource MIR witness")

    # Only explicit names are banned so ordinary Rust derives and HashMaps remain valid.
    banned_tokens = (
        "derive_resource_id",
        "resource_id_from_source",
        "resource_id_from_source_text",
        "resource_id_from_local",
        "resource_id_from_local_name",
        "resource_id_from_fixture",
        "resource_id_from_fixture_name",
        "infer_resource_identity",
        "reconstruct_resource_identity",
    )
    combined = worker + "\n" + main
    for token in banned_tokens:
        if token in combined:
            fail(f"worker identity hard ban violated: {token}")


def check_tests_and_wiring(root: Path) -> None:
    smoke = read_text(root, SMOKE)
    parity = read_text(root, PARITY)
    workflow = read_text(root, WORKFLOW)
    justfile = read_text(root, JUSTFILE)
    levels = read_text(root, LEVELS)
    for token in (
        'make_operation("operation:declare:a", 0',
        'make_operation("operation:initialize:a:local", 1',
        'make_operation("operation:read:a", 2',
        'make_operation("operation:move:a", 3',
        'make_operation("operation:close:b", 4',
        'make_operation("operation:schedule:a", 5',
        'make_operation("operation:destroy:a", 6',
        'make_operation("operation:mark_destroyed:b", 7',
        'make_carrier("carrier:a:stack", resource_a_id, "mir.value.resource.cleanup", 1',
        'make_carrier("carrier:a:branch", resource_a_id, "mir.value.resource.cleanup", 2',
        'make_carrier("carrier:a:loop", resource_a_id, "mir.value.resource.cleanup", 3',
        'make_carrier("carrier:a:field", resource_a_id, "mir.value.resource.cleanup", 4',
        "/tmp/gust-phase15-resource-mir.request",
        "/tmp/gust-phase15-resource-mir.mir-to-c.witness",
    ):
        if token not in smoke:
            fail(f"resource MIR smoke is missing: {token}")
    for token in (
        "phase15-resource-mir-witness",
        "resource_mir_copy_forbidden",
        "resource_mir_duplicate_resource_identity",
        "resource_mir_state_missing_at_control_flow_edge",
        "resource_mir_type_layout_identity_mismatch",
        "explicit-resource-id",
        "resource:v1:compiler-selected:999",
        "resource_lowering:",
        "cmp -s",
    ):
        if token not in parity:
            fail(f"Level 2 parity guard is missing: {token}")
    for token in (
        GUARD_ID + ":",
        PARITY_GUARD_ID + ":",
        "python3 scripts/phase15_resource_mir.py --check",
        "bash scripts/phase15_resource_mir_parity.sh",
        "grep -F $'guard-cranelift-phase15-resource-mir-contract",
        "grep -F $'guard-cranelift-phase15-resource-mir-parity",
    ):
        if token not in justfile:
            fail(f"justfile wiring is missing: {token}")
    if "rg -n -F $'guard-cranelift-phase15-resource-mir-" in justfile:
        fail("Phase 15.2 level checks must not require ripgrep in the Level 1 job")
    if f'"{GUARD_ID}": 1' not in levels or f'"{PARITY_GUARD_ID}": 2' not in levels:
        fail("resource MIR guards are missing from the canonical test-level registry")
    for token in (
        "Cranelift Phase 15 Resource MIR",
        "Phase 15.2 resource MIR contract (Level 1)",
        "Phase 15.2 resource value parity (Level 2)",
        f"just {GUARD_ID}",
        f"just {PARITY_GUARD_ID}",
    ):
        if token not in workflow:
            fail(f"resource MIR workflow is missing: {token}")


def render_review(rows: list[dict[str, str]]) -> str:
    counts = Counter(row["kind"] for row in rows)
    lines = [
        "Phase 15.2 — Resource Values in Canonical MIR",
        f"guard: {GUARD_ID}",
        f"parity_guard: {PARITY_GUARD_ID}",
        f"test_level: {TEST_LEVEL}",
        "format: gust.compiler_resource_mir.v1",
        "identity: explicit compiler-produced resource_id only",
        "copy_policy: non-copy resources move only",
        "edge_policy: explicit resource state on every selected control-flow edge",
        "",
        "counts:",
    ]
    for kind in sorted(counts):
        lines.append(f"  {kind}: {counts[kind]}")
    lines.extend(["", "active contract:"])
    for row in rows:
        lines.append(f"  {row['kind']}\t{row['id']}\t{row['owner']}\t{row['disposition']}")
    lines.extend(
        [
            "",
            "exit gate:",
            "  selected resource-bearing values have one compiler-owned identity and canonical MIR representation",
            "  MIR-to-C and Cranelift consume the same serialized operation table without reconstructing identity",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()

    rows = load_rows(root)
    require_inventory(rows)
    check_resource_mir(root)
    check_authority_extension(root)
    check_mir_integration(root)
    check_request(root)
    check_consumers(root)
    check_tests_and_wiring(root)
    expected = render_review(rows)

    if args.write:
        path = root / REVIEW
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(expected, encoding="utf-8")
    else:
        actual = read_text(root, REVIEW)
        if actual != expected:
            fail("generated review is stale; run python3 scripts/phase15_resource_mir.py --write")

    print(f"{GUARD_ID}: ok ({len(rows)} rows, {TEST_LEVEL})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
