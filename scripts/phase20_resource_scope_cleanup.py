#!/usr/bin/env python3
"""Validate and project Patch 20.10 generic resource scope cleanup authority."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
CODEGEN = ROOT / "compiler/codegen.gst"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_RESOURCE_SCOPE_CLEANUP.md"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
JUSTFILE = ROOT / "justfile"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
GUARD_L1 = "guard-cranelift-phase20-resource-scope-cleanup-contract"
GUARD_L2 = "guard-cranelift-phase20-resource-scope-cleanup-parity"


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    authority = registry.get("phase20_resource_scope_cleanup")
    require(isinstance(authority, dict), "Patch 20.10 authority is missing")
    require(authority.get("authority_version") ==
            "phase20_resource_scope_cleanup_v1",
            "Patch 20.10 authority version drifted")
    require(authority.get("status") == "patch20_10_complete" and
            authority.get("next_patch") == "20.11",
            "Patch 20.10 status or successor drifted")
    require(authority.get("issue") == "CR-5/#106",
            "Patch 20.10 issue ownership drifted")
    require(authority.get("enforcement_enabled") is True,
            "Patch 20.10 enforcement is not enabled")
    for key in ("module_fixture", "source_fixture"):
        require((ROOT / authority[key]).is_file(),
                f"Patch 20.10 fixture is missing: {authority[key]}")

    typechecker = TYPECHECKER.read_text(encoding="utf-8")
    for evidence in (
        "type ResourceCleanupAction[ctx] struct",
        "resource_cleanup_plans: std.HashMap",
        "func resource_cleanup_plan_key(",
        "func env_record_resource_cleanup_plan(",
        "func typechecker_check_resource_scoped_block(",
        "path-dependent live and terminal ownership at scope exit",
        "acquisition did not occur on this path",
        "obligation.cleanup_condition",
        "(*env).struct_validated_destructor.Get",
    ):
        require(evidence in typechecker,
                f"Patch 20.10 typechecker evidence missing: {evidence}")
    require("(*env).open_directories.Get" not in typechecker,
            "open_directories still has an enforcement read")

    codegen = CODEGEN.read_text(encoding="utf-8")
    for evidence in (
        "func codegen_generate_resource_cleanup_plan(",
        "func codegen_generate_active_defers(",
        '"return", ctx[stmt_idx].Return.span',
        "action.cleanup_condition",
        "codegen_resource_cleanup_c_function_name(",
    ):
        require(evidence in codegen,
                f"Patch 20.10 codegen evidence missing: {evidence}")

    source = (ROOT / authority["source_fixture"]).read_text(encoding="utf-8")
    for evidence in (
        "func nested_cleanup()", "func aggregate_cleanup()",
        "func early_return_cleanup() int", "func scheduled_cleanup()",
        "func loop_cleanup()", "func match_cleanup()",
        "func manual_cleanup()", "box.second = resource.acquire(4);",
        "defer resource.consume(scheduled);",
    ):
        require(evidence in source,
                f"Patch 20.10 source witness missing: {evidence}")

    require("- [x] Patch 20.10 — Generic Scope and Destructor Enforcement (CR-5) — DONE"
            in TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 20.10 DONE")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 20.10 guard levels drifted")
    workflow = PR_FAST.read_text(encoding="utf-8")
    require("Phase 20 generic resource scope cleanup" in workflow and
            f"just {GUARD_L1}" in workflow,
            "PR Fast does not own the Patch 20.10 Level 1 guard")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in justfile and f"{GUARD_L2}:" in justfile,
            "Patch 20.10 just guards are missing")

    successor = registry.get("phase21_resource_sync_native_source", {})
    successor_case = None
    if successor.get("status") == "patch21_11_complete":
        require(successor.get("predecessor_authority") ==
                registry["phase21_filesystem_allocation_native_source"]
                ["contract_version"],
                "Patch 21.11 successor authority is not linked")
        successor_case = next((case for case in successor.get("source_cases", [])
                               if case.get("source_fixture") ==
                               authority["source_fixture"]), None)
        require(successor_case is not None and
                successor_case.get("expected_exit") == 0 and
                successor_case.get("expected_stderr") == "",
                "Patch 21.11 lacks native success authority for the cleanup source")
    projected = dict(authority)
    projected["completed_successor_native_case"] = successor_case
    return projected


def render(authority: dict) -> str:
    lines = [
        "# Cranelift Phase 20 Generic Resource Scope Cleanup",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_resource_scope_cleanup.py project`. Do not edit by hand.",
        "",
        f"- Authority version: `{authority['authority_version']}`",
        f"- Status: `{authority['status']}`",
        f"- Next patch: `{authority['next_patch']}`",
        f"- Issue: `{authority['issue']}`",
        "- Enforcement enabled: `true`",
        "",
        "## Compiler-owned cleanup plan",
        "",
        "The typechecker transports each acquisition identity to its final owned",
        "storage and records structured cleanup actions at lexical blocks and",
        "returns. Code generation consumes those actions mechanically. Inner",
        "scopes run first; declarations and resource fields run in reverse order.",
        "",
        "Return expressions are evaluated before cleanup. Manual destruction,",
        "moves, owned-argument transfer, returned ownership, and explicit defer",
        "are terminal states and therefore cannot also receive automatic cleanup.",
        "Mixed live/terminal joins reject rather than risk a double destruction.",
        "Stored fallible acquisitions clean their payload only when `.Ok`.",
        "",
        "Directory resources use the same plan. `open_directories` remains only",
        "write-only compatibility storage and has no semantic enforcement read.",
        "Phase 15 canonical cleanup parity remains the MIR-to-C/Cranelift consumer",
        "agreement authority.",
        "",
    ]
    successor_case = authority["completed_successor_native_case"]
    if successor_case is not None:
        lines += [
            "## Successor transition",
            "",
            "Patch 21.11 now owns native source admission for this exact resource",
            "cleanup fixture. This historical guard therefore verifies its native",
            "observable result instead of retaining the superseded pre-driver",
            "rejection expectation.",
            f"- Source: `{successor_case['source_fixture']}`",
            f"- Expected stdout hex: `{successor_case['expected_stdout'].encode().hex()}`",
            "",
        ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=(
        "validate", "project", "check-review", "successor-native-case",
    ))
    args = parser.parse_args()
    try:
        authority = validate()
        if args.command == "project":
            REVIEW.write_text(render(authority), encoding="utf-8")
        elif args.command == "check-review":
            require(REVIEW.read_text(encoding="utf-8") == render(authority),
                    "generated Patch 20.10 review is stale; run project")
        elif args.command == "successor-native-case":
            case = authority["completed_successor_native_case"]
            if case is not None:
                print(case["source_fixture"])
    except (Error, KeyError) as error:
        print(f"{GUARD_L1}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
