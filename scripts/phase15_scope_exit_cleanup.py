#!/usr/bin/env python3
"""Level 1 contract and review for Patch 15.5 normal scope-exit cleanup."""

from __future__ import annotations

import argparse
import csv
from collections import Counter
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
GUARD_ID = "guard-cranelift-phase15-scope-exit-cleanup-contract"
PARITY_GUARD_ID = "guard-cranelift-phase15-scope-exit-cleanup-parity"
CONTRACT = Path("tests/cranelift/phase15_scope_exit_cleanup_contract.tsv")
REVIEW = Path("tests/cranelift/phase15_scope_exit_cleanup_review.txt")
MODEL = Path("compiler/mir_scope_exit_cleanup.gst")
MIR_TO_C = Path("compiler/mir_scope_exit_cleanup_mir_to_c.gst")
FIXTURE = Path("compiler/mir_scope_exit_cleanup_parity_smoke_test_entry.gst")
STATE_SMOKE = Path("compiler/mir_scope_exit_cleanup_state_smoke_test_entry.gst")
AUTHORITY = Path("compiler/mir_resource_authority.gst")
RESOURCE_MIR = Path("compiler/mir_resource_value.gst")
WORKER = Path("compiler/experiments/cranelift/src/scope_exit_cleanup.rs")
MAIN = Path("compiler/experiments/cranelift/src/main.rs")
PARITY = Path("scripts/phase15_scope_exit_cleanup_parity.sh")
WORKFLOW = Path(".github/workflows/phase15-scope-exit-cleanup.yml")
LEVELS = Path("scripts/cranelift_test_levels.json")
JUSTFILE = Path("justfile")

REASONS = (
    "scope_exit_cleanup_duplicate_insertion",
    "scope_exit_cleanup_live_resource_missing",
    "scope_exit_cleanup_moved_resource",
    "scope_exit_cleanup_wrong_scope",
    "scope_exit_cleanup_order_invalid",
    "scope_exit_cleanup_destructor_mismatch",
    "scope_exit_cleanup_operation_missing",
    "scope_exit_cleanup_source_location_mismatch",
    "scope_exit_cleanup_owning_declaration_mismatch",
)


def fail(message: str) -> None:
    raise SystemExit(f"guard-cranelift-phase15-scope-exit-cleanup-contract: {message}")


def read(path: Path) -> str:
    full = ROOT / path
    if not full.is_file() or full.is_symlink():
        fail(f"missing regular file {path}")
    return full.read_text()


def require(text: str, tokens: tuple[str, ...], path: Path) -> None:
    for token in tokens:
        if token not in text:
            fail(f"{path} is missing {token!r}")


def load_contract() -> list[dict[str, str]]:
    with (ROOT / CONTRACT).open(newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    if not rows:
        fail("contract is empty")
    if set(rows[0]) != {"kind", "requirement", "evidence", "level"}:
        fail("contract header must be kind, requirement, evidence, level")
    seen: set[tuple[str, str]] = set()
    for row in rows:
        key = (row["kind"], row["requirement"])
        if key in seen:
            fail(f"duplicate contract row {key}")
        seen.add(key)
        if row["level"] != "1":
            fail(f"contract row {key} is not Level 1")
        if not row["evidence"]:
            fail(f"contract row {key} has no evidence")
    if len(rows) != 45:
        fail(f"expected 45 contract rows, got {len(rows)}")
    return rows


def check_model() -> None:
    model = read(MODEL)
    require(
        model,
        (
            "type MirResourceScope[ctx] struct",
            "type MirResourceScopeBinding[ctx] struct",
            "type MirScopeExitCleanup[ctx] struct",
            "type MirScopeExitCleanupExclusion[ctx] struct",
            "type MirScopeExitCleanupPlan[ctx] struct",
            "func mir_scope_exit_cleanup_plan_build(",
            "func mir_scope_exit_cleanup_validate(",
            "func mir_scope_exit_cleanup_append_to_request(",
            "func mir_scope_exit_cleanup_witness(",
            "selected_scopes_by_exit_sequence_then_reverse_declaration_order",
            '"block_scope"',
            '"function_body"',
            '"selected_nested_scope"',
            '"moved_resource"',
            '"manually_closed_resource"',
            '"already_destroyed_resource"',
        )
        + REASONS,
        MODEL,
    )
    resource = read(RESOURCE_MIR)
    require(
        resource,
        (
            "func mir_resource_value_count(",
            "func mir_resource_value_at(",
            "func mir_resource_operation_count(",
            "func mir_resource_operation_at(",
            "func mir_resource_cleanup_invoke_count(",
            "func mir_resource_mir_apply_scope_exit_cleanup(",
            "operations_scope_cleanup.Push(schedule_operation)",
            "operations_scope_cleanup.Push(cleanup_operation)",
        ),
        RESOURCE_MIR,
    )
    authority = read(AUTHORITY)
    require(
        authority,
        (
            "type MirCleanupObligationQuery[ctx] struct",
            "func mir_cleanup_obligation_for_resource_scope(",
        ),
        AUTHORITY,
    )


def check_backends() -> None:
    mir_to_c = read(MIR_TO_C)
    require(
        mir_to_c,
        (
            "func mir_scope_exit_cleanup_entry_to_c(",
            "func mir_scope_exit_cleanup_to_c_source(",
            "func mir_scope_exit_cleanup_lowering_witness(",
            "cleanup.mir_scope_exit_cleanup_entry_count(plan, ctx)",
            "cleanup.mir_scope_exit_cleanup_entry_at(plan, lowering_cleanup_index, ctx)",
            "action=invoke_destructor",
            "runtime_symbol=",
        ),
        MIR_TO_C,
    )
    if "std.Vector[cleanup.MirScopeExitCleanup" in mir_to_c or "ctx[plan.entries]" in mir_to_c:
        fail("MIR-to-C must access cleanup entries through defining-module helpers")

    worker = read(WORKER)
    require(
        worker,
        (
            "struct ScopeRecord",
            "struct BindingRecord",
            "struct CleanupEntry",
            "struct ExclusionRecord",
            "fn parse_request(",
            "fn validate(",
            "fn canonical_witness(",
            "fn lowering_witness(",
            "pub fn lower_scope_exit_cleanup_witness_path(",
            "scope_exit_cleanup_witness: accepted order_policy=reverse_declaration_order",
            "scope_exit_cleanup_lowering_witness: accepted",
            "action=invoke_destructor",
        )
        + REASONS,
        WORKER,
    )
    main = read(MAIN)
    require(
        main,
        (
            "mod scope_exit_cleanup;",
            '"phase15-scope-exit-cleanup-witness"',
            "scope_exit_cleanup::lower_scope_exit_cleanup_witness_path(",
            "phase15-scope-exit-cleanup-witness <request.native>",
        ),
        MAIN,
    )


def check_fixture_and_parity() -> None:
    fixture = read(FIXTURE)
    require(
        fixture,
        (
            "scope:phase15:scope-exit:block",
            "scope:phase15:scope-exit:nested",
            "scope:phase15:scope-exit:function",
            "decl:block:first",
            "decl:block:second",
            "decl:block:moved",
            "decl:nested:destroyed",
            "decl:function:closed",
            "cleanup.mir_scope_exit_cleanup_plan_build(",
            "resource_mir.mir_resource_mir_apply_scope_exit_cleanup(",
            "cleanup.mir_scope_exit_cleanup_append_to_request(",
            "cleanup.mir_scope_exit_cleanup_witness(",
            "cleanup_mir_to_c.mir_scope_exit_cleanup_lowering_witness(",
            '"/tmp/gust-phase15-scope-exit-cleanup.request"',
            '"/tmp/gust-phase15-scope-exit-cleanup.mir-to-c.witness"',
            "SUCCESS: Phase 15.5 normal scope-exit cleanup parity smoke passed",
        ),
        FIXTURE,
    )
    state = read(STATE_SMOKE)
    require(
        state,
        (
            'expect_reason("moved", "moved_resource")',
            'expect_reason("manually_closed", "manually_closed_resource")',
            'expect_reason("destroyed", "already_destroyed_resource")',
            "SUCCESS: Phase 15.5 scope-exit cleanup state policy passed",
        ),
        STATE_SMOKE,
    )
    parity = read(PARITY)
    require(
        parity,
        (
            "compiler/mir_scope_exit_cleanup_state_smoke_test_entry.gst",
            "compiler/mir_scope_exit_cleanup_parity_smoke_test_entry.gst",
            "phase15-scope-exit-cleanup-witness",
            "grep '^scope_exit_cleanup'",
            "Phase 15.5 MIR-to-C and Cranelift scope-exit cleanup witnesses differ.",
            "duplicate-insertion",
            "missing-cleanup",
            "moved-resource",
            "wrong-scope",
            "bad-order",
            "bad-destructor",
            "missing-operation",
            "guard-cranelift-phase15-scope-exit-cleanup-parity: ok (Level 2)",
        )
        + REASONS[:7],
        PARITY,
    )


def check_wiring() -> None:
    import json

    levels = json.loads(read(LEVELS))
    mapping = levels.get("guards", levels)
    if mapping.get(GUARD_ID) != 1 or mapping.get(PARITY_GUARD_ID) != 2:
        fail("test-level registry must classify contract=1 and parity=2")

    justfile = read(JUSTFILE)
    require(
        justfile,
        (
            f"{GUARD_ID}:",
            f"{PARITY_GUARD_ID}:",
            "python3 scripts/phase15_scope_exit_cleanup.py --check",
            "bash scripts/phase15_scope_exit_cleanup_parity.sh",
            f"grep -F $'{GUARD_ID}\\t1\\t'",
            f"grep -F $'{PARITY_GUARD_ID}\\t2\\t'",
        ),
        JUSTFILE,
    )

    workflow = read(WORKFLOW)
    require(
        workflow,
        (
            "name: Cranelift Phase 15 Scope Exit Cleanup",
            "workflow_dispatch:",
            "compiler/mir_scope_exit_cleanup.gst",
            "compiler/mir_scope_exit_cleanup_mir_to_c.gst",
            "compiler/mir_scope_exit_cleanup_parity_smoke_test_entry.gst",
            "scripts/run-gust-file.sh",
            "Phase 15.5 scope-exit cleanup contract (Level 1)",
            "Phase 15.5 scope-exit cleanup parity (Level 2)",
            f"run: just {GUARD_ID}",
            f"run: just {PARITY_GUARD_ID}",
        ),
        WORKFLOW,
    )


def render(rows: list[dict[str, str]]) -> str:
    counts = Counter(row["kind"] for row in rows)
    lines = [
        "Phase 15.5 — Cleanup Insertion at Normal Scope Exits",
        f"guard: {GUARD_ID}",
        f"parity_guard: {PARITY_GUARD_ID}",
        f"rows: {len(rows)}",
        "test_levels: contract=Level 1 parity=Level 2",
        "order_policy: selected scope exit sequence then reverse declaration order",
        "exit_gate: every selected live resource has exactly one compiler-produced cleanup",
        "",
        "inventory:",
    ]
    lines.extend(f"- {kind}: {counts[kind]}" for kind in sorted(counts))
    return "\n".join(lines) + "\n"


def check() -> list[dict[str, str]]:
    rows = load_contract()
    check_model()
    check_backends()
    check_fixture_and_parity()
    check_wiring()
    expected = render(rows)
    review_path = ROOT / REVIEW
    if not review_path.is_file() or review_path.read_text() != expected:
        fail(f"{REVIEW} is stale; run with --write")
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    if args.write:
        rows = load_contract()
        (ROOT / REVIEW).write_text(render(rows))
    rows = check()
    print(
        "guard-cranelift-phase15-scope-exit-cleanup-contract: "
        f"ok ({len(rows)} rows, Level 1)"
    )


if __name__ == "__main__":
    main()