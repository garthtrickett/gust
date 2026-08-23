#!/usr/bin/env python3
"""Validate and project Patch 20.5 Arena.Free receiver invalidation."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_ARENA_FREE_INVALIDATION.md"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
JUSTFILE = ROOT / "justfile"
GUARD = "guard-cranelift-phase20-arena-free-contract"


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    authority = registry.get("phase20_arena_free_invalidation")
    require(isinstance(authority, dict), "Patch 20.5 authority is missing")
    require(authority.get("authority_version") ==
            "phase20_arena_free_invalidation_v1",
            "Patch 20.5 authority version drifted")
    require(authority.get("status") == "patch20_5_complete",
            "Patch 20.5 status drifted")
    require(authority.get("next_patch") == "20.6",
            "Patch 20.5 successor drifted")
    require(authority.get("issue") == "CR-13/#160",
            "Patch 20.5 issue ownership drifted")
    require(authority.get("diagnostic_code") == "ArenaUseAfterFree",
            "Patch 20.5 diagnostic code drifted")
    require(authority.get("rejected_operations") == [
        "allocation", "clone_destination", "write", "repeated_free",
    ], "Patch 20.5 rejected operation matrix drifted")
    require(authority.get("alias_coverage") == [
        "local_alias", "selector_field", "function_parameter",
    ], "Patch 20.5 alias coverage drifted")
    require(authority.get("opening_probe_fix_enabled") is True,
            "CR-13 opening fix is not enabled")

    for key in ("positive_fixture", "issue_fixture", "canonical_mir_fixture"):
        require((ROOT / authority[key]).is_file(),
                f"Patch 20.5 file is missing: {authority[key]}")
    negatives = authority.get("negative_fixtures")
    require(isinstance(negatives, list) and len(negatives) == 7,
            "Patch 20.5 negative fixture matrix drifted")
    for path in negatives:
        require((ROOT / path).is_file(),
                f"Patch 20.5 negative fixture is missing: {path}")

    source = TYPECHECKER.read_text(encoding="utf-8")
    for evidence in (
        "in_defer_expression: int",
        "arena_lifecycle_deferred_frees: std.HashMap[str, int, ctx]",
        "func env_arena_lifecycle_apply_expression(",
        "if state.state == arena_lifecycle_state_freed()",
        '"Semantic Error: [ArenaUseAfterFree] Arena identity \'"',
        "state.state = arena_lifecycle_state_freed()",
        "if (*env).in_defer_expression == 0",
        'env, arg0_idx, "allocation", expr.Call.span, ctx',
        'env, dest_expr_idx, "clone_destination", expr.Call.span, ctx',
        'env, left_expr_idx, "write", expr.Call.span, ctx',
        'env, left_expr_idx, "free", expr.Call.span, ctx',
        "(*env).in_defer_expression = 1",
        "(*env).in_defer_expression = old_in_defer_expression",
        "already has a deferred Free; rejected repeated Free",
    ):
        require(evidence in source,
                f"Arena.Free compiler evidence missing: {evidence}")
    require(source.count("env_arena_lifecycle_apply_expression(") == 5,
            "exactly four CR-13 operation sites must share one lifecycle helper")

    positive = (ROOT / authority["positive_fixture"]).read_text(encoding="utf-8")
    for evidence in (
        "defer primary.Free();", "defer secondary.Free();",
        "os.ArenaAlloc(primary)", "primary.Set(primary_index, 37)",
        'std.Clone(primary, "live")', "os.ArenaAlloc(secondary)",
        "return 37;",
    ):
        require(evidence in positive,
                f"live-arena positive coverage missing: {evidence}")

    issue = (ROOT / authority["issue_fixture"]).read_text(encoding="utf-8")
    require("current_result: rejects_clone_through_freed_arena_receiver" in issue and
            "fixed_by: 20.5" in issue and
            "destination.Free();" in issue and
            'std.Clone(destination, "freed")' in issue,
            "CR-13 issue fixture does not record the correction")

    fixture_evidence = {
        negatives[0]: "os.ArenaAlloc(destination)",
        negatives[1]: "destination.Set(value, 9)",
        negatives[2]: "destination.Free();",
        negatives[3]: "defer destination.Free();",
        negatives[4]: "mut alias := destination;",
        negatives[5]: "holder.arena.Free();",
        negatives[6]: "func consume_then_reuse(ctx: Arena)",
    }
    for path, evidence in fixture_evidence.items():
        require(evidence in (ROOT / path).read_text(encoding="utf-8"),
                f"negative fixture coverage drifted: {path}")

    mir = (ROOT / authority["canonical_mir_fixture"]).read_text(encoding="utf-8")
    require("block_0_terminator_value: 37" in mir and "expected_exit: 37" in mir,
            "Patch 20.5 canonical MIR projection drifted")

    opening = registry.get("opening_snapshots", {}).get("phase20", {})
    probes = opening.get("baseline_probes", [])
    cr13 = next((probe for probe in probes
                 if probe.get("id") == "cr13_freed_receiver_reuse"), {})
    require(opening.get("status") == "ready_for_patch20_8" and
            opening.get("next_patch") == "20.8",
            "Phase 20 opening successor did not advance")
    require(cr13.get("compile_exit") == 1 and cr13.get("fix_enabled") is True and
            cr13.get("diagnostic_substrings") == ["[ArenaUseAfterFree]"] and
            cr13.get("current_verdict") ==
            "rejects_clone_through_freed_arena_receiver",
            "CR-13 opening probe did not record the corrected result")

    require("- [x] Patch 20.5 — Arena.Free Receiver Invalidation (CR-13/#160) — DONE" in
            TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 20.5 DONE")
    workflow = PR_FAST.read_text(encoding="utf-8")
    require("Phase 20 Arena.Free receiver invalidation" in workflow and
            "just guard-cranelift-phase20-arena-free-contract" in workflow and
            "just guard-cranelift-phase20-arena-free-parity" in workflow,
            "PR Fast does not own both Patch 20.5 levels")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require("guard-cranelift-phase20-arena-free-contract:" in justfile and
            "guard-cranelift-phase20-arena-free-parity:" in justfile,
            "Patch 20.5 just guards are missing")
    return authority


def render(authority: dict) -> str:
    lines = [
        "# Cranelift Phase 20 Arena.Free Receiver Invalidation",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_arena_free.py project`. Do not edit by hand.",
        "",
        f"- Authority version: `{authority['authority_version']}`",
        f"- Status: `{authority['status']}`",
        f"- Next patch: `{authority['next_patch']}`",
        f"- Issue: `{authority['issue']}`",
        f"- Diagnostic: `[{authority['diagnostic_code']}]`",
        "",
        "## Semantic correction",
        "",
        "The first immediate `Arena.Free` transitions its canonical receiver",
        "identity from live to freed. Allocation, Clone destination use, write,",
        "and repeated Free consult the same record and are rejected after that",
        "transition. Local aliases, selector fields, and function parameters",
        "cannot create a fresh identity, while a distinct arena remains live.",
        "",
        "A deferred Free is checked and observed at its source position but does",
        "not transition early; existing `defer ctx.Free()` programs retain their",
        "scope-exit meaning.",
        "",
        "## Evidence",
        "",
        "Every rejected fixture produces exactly one identical frontend",
        "`ArenaUseAfterFree` diagnostic for default MIR-to-C, explicit MIR-to-C,",
        "and direct Cranelift requests before backend selection. The accepted",
        "two-arena program returns 37 through MIR-to-C; its selected canonical",
        "MIR returns 37 through Cranelift. The direct accepted generic-source",
        "Cranelift route remains explicitly deferred with no C fallback.",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review"))
    args = parser.parse_args()
    try:
        authority = validate()
        if args.command == "project":
            REVIEW.write_text(render(authority), encoding="utf-8")
        elif args.command == "check-review":
            require(REVIEW.read_text(encoding="utf-8") == render(authority),
                    "generated Patch 20.5 review is stale; run project")
    except (Error, KeyError) as error:
        print(f"{GUARD}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
