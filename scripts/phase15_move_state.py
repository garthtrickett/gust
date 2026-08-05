#!/usr/bin/env python3
"""Level 1 contract and reduced review for Patch 15.3 move-state semantics."""

from __future__ import annotations

import argparse
import csv
import json
from collections import Counter
from pathlib import Path
import sys

GUARD_ID = "guard-cranelift-phase15-move-state-contract"
PARITY_GUARD_ID = "guard-cranelift-phase15-move-state-parity"
TEST_LEVEL = "level1"
CONTRACT = Path("tests/cranelift/phase15_move_state_contract.tsv")
REVIEW = Path("tests/cranelift/phase15_move_state_review.txt")
AUTHORITY = Path("compiler/mir_resource_authority.gst")
RESOURCE_MIR = Path("compiler/mir_resource_value.gst")
REQUEST = Path("compiler/mir_native_backend_resource_mir_request.gst")
MIR_TO_C = Path("compiler/mir_resource_value_mir_to_c.gst")
WORKER = Path("compiler/experiments/cranelift/src/resource_mir.rs")
TRANSITION_SMOKE = Path("compiler/mir_resource_move_state_smoke_test_entry.gst")
PARITY_SMOKE = Path("compiler/mir_resource_move_parity_smoke_test_entry.gst")
PARITY = Path("scripts/phase15_move_state_parity.sh")
GUARD_SCRIPT = Path("scripts/guard-cranelift-phase15-move-state-contract.sh")
WORKFLOW = Path(".github/workflows/phase15-move-state.yml")
LEVELS = Path("scripts/cranelift_test_levels.json")
JUSTFILE = Path("justfile")

EXPECTED = {
    "move_form": {
        "local_to_local",
        "local_to_aggregate_field",
        "aggregate_field_to_local",
        "branch_edge_move",
        "selected_loop_carried_move",
    },
    "transition": {
        "live_to_moved",
        "moved_storage_to_fresh_identity_live",
        "live_to_closed",
        "closed_to_destroyed",
        "cleanup_scheduled_to_destroyed",
        "invalid_transition_rejection",
    },
    "rejection": {
        "use_after_move",
        "close_after_move",
        "second_move",
        "cleanup_after_move",
        "destructor_after_move",
        "move_from_uninitialized",
        "copy_move_only",
        "inconsistent_join",
    },
    "diagnostic": {
        "resource_id",
        "resource_declaration",
        "move_site",
        "invalid_use_site",
        "prior_state",
        "attempted_operation",
        "reason_code",
    },
    "positive": {
        "single_ownership_transfer",
        "move_followed_by_destination_use",
        "move_followed_by_source_reinitialization",
        "move_through_branches",
        "selected_loop_carried_move",
    },
    "boundary": {
        "compiler_owned_carrier_state",
        "pre_driver_validation",
        "poisoned_driver_evidence",
        "sentinel_output_evidence",
        "no_artifact_evidence",
    },
    "consumer": {"mir_to_c_move_lowering", "cranelift_move_lowering"},
    "test": {"level1_move_state_contract", "level2_move_state_parity"},
}

REASON_CODES = {
    "resource_use_after_move",
    "resource_close_after_move",
    "resource_second_move",
    "resource_cleanup_after_move",
    "resource_destructor_after_move",
    "resource_move_from_uninitialized",
    "resource_copy_of_move_only",
    "resource_move_join_state_inconsistent",
    "resource_reinitialize_requires_fresh_identity",
}


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD_ID}: {message}")


def read_text(root: Path, path: Path) -> str:
    try:
        return (root / path).read_text(encoding="utf-8")
    except FileNotFoundError:
        fail(f"missing required file: {path}")


def load_rows(root: Path) -> list[dict[str, str]]:
    try:
        with (root / CONTRACT).open(encoding="utf-8", newline="") as handle:
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
    if set(by_kind) != set(EXPECTED):
        fail(f"contract kinds mismatch: expected {sorted(EXPECTED)}, got {sorted(by_kind)}")
    for kind, expected in EXPECTED.items():
        actual = by_kind.get(kind, set())
        if actual != expected:
            fail(f"{kind} inventory mismatch: expected {sorted(expected)}, got {sorted(actual)}")


def require_tokens(source: str, tokens: tuple[str, ...], owner: Path) -> None:
    for token in tokens:
        if token not in source:
            fail(f"{owner} is missing: {token}")


def check_authority(root: Path) -> None:
    source = read_text(root, AUTHORITY)
    require_tokens(
        source,
        (
            "func mir_validate_resource_transition_from_state(",
            "func mir_validate_resource_reinitialization(",
            'std.str_eq(prior, "live") == 1',
            'mir_resource_transition_validation(1, "moved", "resource_transition_valid"',
            'std.str_eq(prior_storage_state, "moved") == 0',
            'std.str_eq(previous_resource_id, new_resource_id) == 1',
            'mir_resource_transition_validation(1, "live", "resource_reinitialization_valid"',
            "resource_move_join_state_inconsistent",
        ),
        AUTHORITY,
    )
    for reason in REASON_CODES:
        if reason not in source and reason != "resource_move_join_state_inconsistent":
            fail(f"compiler transition policy is missing reason code: {reason}")


def check_resource_mir(root: Path) -> None:
    source = read_text(root, RESOURCE_MIR)
    require_tokens(
        source,
        (
            "move_state_policy: str",
            'table.move_state_policy = std.Clone(ctx, "carrier_state_transitions_before_driver_discovery")',
            "type MirResourceMoveDiagnostic[ctx] struct",
            "type MirResourceMoveValidation[ctx] struct",
            "type MirResourceStorageState[ctx] struct",
            "func mir_resource_move_form_name(",
            'return "local_to_local";',
            'return "local_to_aggregate_field";',
            'return "aggregate_field_to_local";',
            'return "branch_edge_move";',
            'return "selected_loop_carried_move";',
            "func mir_resource_carrier_state_before_operation(",
            "func mir_resource_storage_state_before_operation(",
            "func mir_resource_move_state_validate(",
            "authority.mir_validate_resource_reinitialization(",
            "func mir_resource_move_diagnostic_text(",
            'output = std.Concat(output, " declaration=")',
            'output = std.Concat(output, " move_site=")',
            'output = std.Concat(output, " invalid_use_site=")',
            'output = std.Concat(output, " prior_state=")',
            'output = std.Concat(output, " attempted_operation=")',
        ),
        RESOURCE_MIR,
    )
    for reason in (
        "resource_move_join_state_inconsistent",
        "resource_reinitialization_state_mismatch",
        "resource_move_state_trace_disagreement",
        "resource_move_destination_not_empty",
        "resource_move_form_unsupported",
    ):
        if reason not in source:
            fail(f"canonical MIR move validator is missing reason code: {reason}")


def check_request_boundary(root: Path) -> None:
    source = read_text(root, REQUEST)
    require_tokens(
        source,
        (
            "Phase 15.3 move-state validation is compiler-owned",
            "before any",
            "driver discovery, request publication, object creation, or output access",
            "resource_mir.mir_resource_move_state_validate(",
            "func mir_native_backend_resource_move_diagnostic(",
        ),
        REQUEST,
    )
    move_pos = source.find("resource_mir.mir_resource_move_state_validate(")
    table_pos = source.find("resource_mir.mir_resource_mir_table_validate(")
    serialize_pos = source.find("func mir_serialize_native_backend_resource_mir_request(")
    if min(move_pos, table_pos, serialize_pos) < 0 or not (move_pos < table_pos < serialize_pos):
        fail("move-state validation must run before table serialization and driver-facing publication")


def check_consumers(root: Path) -> None:
    mir_to_c = read_text(root, MIR_TO_C)
    worker = read_text(root, WORKER)
    require_tokens(
        mir_to_c,
        (
            'row = std.Concat(row, " move_form=")',
            "resource_mir.mir_resource_move_form_name(",
            "func mir_resource_mir_to_c_witness(",
        ),
        MIR_TO_C,
    )
    require_tokens(
        worker,
        (
            'const MOVE_STATE_POLICY: &str = "carrier_state_transitions_before_driver_discovery";',
            "fn transition_from_state(",
            "fn storage_state_before(",
            "fn validate_reinitialization(",
            "fn validate_move_state(",
            "validate_move_state(&operations, &carriers_by_id, &values_by_id)?;",
            '"resource_move_diagnostic: resource={} declaration={} move_site={} invalid_use_site={} prior_state={} attempted_operation={}"',
            "fn move_form_name(",
            '"resource_move_join_state_inconsistent"',
            "fn lower_for_cranelift(",
            "move_form_name(source_kind, destination_kind)",
        ),
        WORKER,
    )
    for reason in REASON_CODES:
        if reason not in worker:
            fail(f"Cranelift worker is missing move-state reason: {reason}")


def check_smokes(root: Path) -> None:
    transition = read_text(root, TRANSITION_SMOKE)
    parity = read_text(root, PARITY_SMOKE)
    require_tokens(
        transition,
        (
            'expect_transition("live", "move", 1, "moved"',
            "authority.mir_validate_resource_reinitialization(",
            "resource_reinitialize_requires_fresh_identity",
            "resource_use_after_move",
            "resource_close_after_move",
            "resource_second_move",
            "resource_cleanup_after_move",
            "resource_destructor_after_move",
            "resource_move_from_uninitialized",
            "resource_copy_of_move_only",
            "resource_move_join_state_inconsistent",
            "SUCCESS: Phase 15.3 move-state transitions and diagnostics passed",
        ),
        TRANSITION_SMOKE,
    )
    require_tokens(
        parity,
        (
            "operation:move:a:local",
            "operation:read:a:destination",
            "operation:move:a:field",
            "operation:move:a:field_out",
            "operation:move:a:branch",
            "operation:move:a:loop",
            "operation:initialize:b:fresh",
            '"local:source"',
            "edge:a:then",
            "edge:a:else",
            "edge:a:loop",
            "/tmp/gust-phase15-move-state.request",
            "/tmp/gust-phase15-move-state.mir-to-c.witness",
            "SUCCESS: Phase 15.3 move-state parity smoke passed",
        ),
        PARITY_SMOKE,
    )


def check_parity_evidence(root: Path) -> None:
    source = read_text(root, PARITY)
    require_tokens(
        source,
        (
            "use-after-move",
            "close-after-move",
            "second-move",
            "cleanup-after-move",
            "destructor-after-move",
            "move-from-uninitialized",
            "copy-after-initialize",
            'copy_operation = "operation:move:a:local"',
            'set_field(operation_field(copy_operation, "destination_carrier_id"), "")',
            'set_field(operation_field(copy_operation, "resulting_state"), "live")',
            "inconsistent-join",
            "resource_move_diagnostic:",
            "GUST_NATIVE_BACKEND_DRIVER",
            "poison-driver-invoked",
            "phase15-move-state-output-sentinel",
            "Use of moved variable",
            "protected_output.phase10.bundle",
            "protected_output.phase10.request",
            "guard-cranelift-phase15-move-state-parity: ok (Level 2)",
        ),
        PARITY,
    )


def check_wiring(root: Path) -> None:
    levels = json.loads(read_text(root, LEVELS))
    mapping = levels.get("guards", levels)
    if mapping.get(GUARD_ID) != 1 or mapping.get(PARITY_GUARD_ID) != 2:
        fail("Cranelift test-level registry must classify contract=1 and parity=2")
    justfile = read_text(root, JUSTFILE)
    require_tokens(
        justfile,
        (
            f"{GUARD_ID}:",
            f"{PARITY_GUARD_ID}:",
            "python3 scripts/phase15_move_state.py --check",
            "bash scripts/phase15_move_state_parity.sh",
            f"grep -F $'{GUARD_ID}\\t1\\t'",
            f"grep -F $'{PARITY_GUARD_ID}\\t2\\t'",
        ),
        JUSTFILE,
    )
    workflow = read_text(root, WORKFLOW)
    require_tokens(
        workflow,
        (
            "name: Cranelift Phase 15 Move State",
            "Phase 15.3 move-state contract (Level 1)",
            "Phase 15.3 move-state parity (Level 2)",
            f"run: just {GUARD_ID}",
            f"run: just {PARITY_GUARD_ID}",
        ),
        WORKFLOW,
    )
    guard = read_text(root, GUARD_SCRIPT)
    if "python3 scripts/phase15_move_state.py --check" not in guard:
        fail("guard shell does not invoke the contract checker")


def render_review(rows: list[dict[str, str]]) -> str:
    counts = Counter(row["kind"] for row in rows)
    lines = [
        "Phase 15.3 — Move-State Transitions and Use-After-Move Enforcement",
        f"guard: {GUARD_ID}",
        f"parity_guard: {PARITY_GUARD_ID}",
        f"rows: {len(rows)}",
        "test_levels: contract=Level 1 parity=Level 2",
        "",
        "Inventory",
    ]
    for kind in EXPECTED:
        lines.append(f"- {kind}: {counts[kind]}")
    lines.extend(
        [
            "",
            "Authority",
            "- resource state transitions are compiler-owned",
            "- moves preserve resource identity across selected carriers",
            "- moved storage may be reinitialized only with a fresh resource identity",
            "- source and destination carrier states are explicit and deterministic",
            "",
            "Early rejection",
            "- use after move, close after move, second move, and cleanup/destructor scheduling after move reject",
            "- move from uninitialized storage, copy of move-only values, and inconsistent joins reject",
            "- validation runs before driver discovery, request publication, artifact creation, and output access",
            "",
            "Diagnostics",
            "- resource declaration, move site, invalid use site, prior state, attempted operation, and stable reason code",
            "",
            "Parity",
            "- MIR-to-C and Cranelift consume the same canonical move operations and move-form names",
            "- Level 2 mutations cover every frozen invalid transition",
            "- poisoned-driver and sentinel-output checks prove invalid source use does not reach native execution",
        ]
    )
    return "\n".join(lines) + "\n"


def run(root: Path, write: bool) -> None:
    rows = load_rows(root)
    require_inventory(rows)
    check_authority(root)
    check_resource_mir(root)
    check_request_boundary(root)
    check_consumers(root)
    check_smokes(root)
    check_parity_evidence(root)
    check_wiring(root)
    review = render_review(rows)
    review_path = root / REVIEW
    if write:
        review_path.parent.mkdir(parents=True, exist_ok=True)
        review_path.write_text(review, encoding="utf-8")
    else:
        try:
            actual = review_path.read_text(encoding="utf-8")
        except FileNotFoundError:
            fail(f"missing generated review: {REVIEW}")
        if actual != review:
            fail(f"generated review is stale: run {Path(__file__).as_posix()} --write")
    print(f"{GUARD_ID}: ok ({len(rows)} rows, Level 1)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true")
    group.add_argument("--write", action="store_true")
    args = parser.parse_args()
    run(args.root.resolve(), args.write)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"{GUARD_ID}: {error}", file=sys.stderr)
        raise SystemExit(1)
