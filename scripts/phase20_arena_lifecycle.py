#!/usr/bin/env python3
"""Validate and project Patch 20.4 arena lifecycle observation authority."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_ARENA_LIFECYCLE.md"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
JUSTFILE = ROOT / "justfile"
GUARD = "guard-cranelift-phase20-arena-lifecycle-contract"


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    authority = registry.get("phase20_arena_lifecycle")
    require(isinstance(authority, dict), "Patch 20.4 authority is missing")
    require(authority.get("authority_version") ==
            "phase20_arena_lifecycle_observation_v1",
            "Patch 20.4 authority version drifted")
    require(authority.get("status") == "patch20_4_complete_observation_only",
            "Patch 20.4 status drifted")
    require(authority.get("next_patch") == "20.5",
            "Patch 20.4 successor drifted")
    require(authority.get("issue") == "CR-13/#160",
            "Patch 20.4 issue ownership drifted")
    require(authority.get("lifecycle_states") == ["live", "freed"],
            "arena lifecycle state vocabulary drifted")
    require(authority.get("observed_operations") == [
        "allocation", "clone_destination", "write", "free",
    ], "arena lifecycle operation coverage drifted")
    require(authority.get("identity_flows") == [
        "local", "alias", "field", "parameter", "generic_substitution",
    ], "arena lifecycle identity-flow coverage drifted")
    require(authority.get("opening_probe_fix_enabled") is False,
            "Patch 20.4 must not enable CR-13 enforcement")

    for key in ("semantic_fixture", "issue_fixture"):
        require((ROOT / authority[key]).is_file(),
                f"Patch 20.4 fixture is missing: {authority[key]}")

    source = TYPECHECKER.read_text(encoding="utf-8")
    for evidence in (
        "type ArenaLifecycleState[ctx] struct {",
        "arena_lifecycle_states: std.HashMap[str, ArenaLifecycleState[ctx], ctx]",
        "arena_lifecycle_bindings: std.HashMap[str, str, ctx]",
        "func env_arena_lifecycle_identity_from_type(",
        "func env_arena_lifecycle_resolve_expression_identity(",
        "env_arena_lifecycle_record_binding(env, param.name, param_arena_identity, ctx)",
        "env_arena_lifecycle_record_binding(env, name, declaration_arena_identity, ctx)",
        "env, assignment_lifecycle_binding, assignment_arena_identity, ctx",
        "func env_arena_lifecycle_observe_identity(",
        "func env_arena_lifecycle_observe_expression(",
        "The Patch 20.4 primitive remains an inert observation helper.",
    ):
        require(evidence in source,
                f"arena lifecycle compiler evidence missing: {evidence}")
    inert_observer = source[
        source.index("func env_arena_lifecycle_observe_identity("):
        source.index("func env_arena_lifecycle_observe_expression(")
    ]
    require("state.state = arena_lifecycle_state_freed()" not in inert_observer and
            "report_error" not in inert_observer,
            "Patch 20.4 inert observation primitive changed meaning")

    semantic = (ROOT / authority["semantic_fixture"]).read_text(encoding="utf-8")
    for evidence in (
        '"alias"', '"holder.arena"', '"generic brand substitution"',
        '"allocation"', '"clone_destination"', '"write"', '"free"',
        "same parameter spelling collapsed across function scopes",
        "arena_lifecycle_state_live()",
    ):
        require(evidence in semantic,
                f"arena lifecycle semantic fixture coverage missing: {evidence}")

    issue = (ROOT / authority["issue_fixture"]).read_text(encoding="utf-8")
    require("current_result: rejects_clone_through_freed_arena_receiver" in issue and
            "fixed_by: 20.5" in issue and
            "destination.Free();" in issue and
            'std.Clone(destination, "freed")' in issue,
            "CR-13 successor witness drifted")

    opening = registry.get("opening_snapshots", {}).get("phase20", {})
    require(opening.get("status") == "ready_for_patch20_9" and
            opening.get("next_patch") == "20.9",
            "Phase 20 opening successor did not advance")
    probes = opening.get("baseline_probes", [])
    cr13 = next((probe for probe in probes
                 if probe.get("id") == "cr13_freed_receiver_reuse"), None)
    require(isinstance(cr13, dict) and cr13.get("compile_exit") == 1 and
            cr13.get("fix_enabled") is True and cr13.get("next_patch") == "20.5",
            "CR-13 successor probe does not record Patch 20.5 enforcement")

    require("- [x] Patch 20.4 — Arena Lifecycle State Authority — DONE" in
            TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 20.4 DONE")
    workflow = PR_FAST.read_text(encoding="utf-8")
    require("Phase 20 arena lifecycle observation authority" in workflow and
            "just guard-cranelift-phase20-arena-lifecycle-contract" in workflow,
            "PR Fast does not own Patch 20.4")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require("guard-cranelift-phase20-arena-lifecycle-contract:" in justfile,
            "Patch 20.4 just guard is missing")
    return authority


def render(authority: dict) -> str:
    lines = [
        "# Cranelift Phase 20 Arena Lifecycle Observation Authority",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_arena_lifecycle.py project`. Do not edit by hand.",
        "",
        f"- Authority version: `{authority['authority_version']}`",
        f"- Status: `{authority['status']}`",
        f"- Next patch: `{authority['next_patch']}`",
        f"- Issue: `{authority['issue']}`",
        "",
        "## Identity and lifecycle authority",
        "",
        "Arena lifecycle records are keyed by canonical, function-scoped arena",
        "identity. Locals, aliases, selector fields, parameters, and resolved",
        "generic brand substitutions map back to that record; identical source",
        "spellings in distinct scopes do not collapse.",
        "",
        "The authority represents both `live` and `freed`, and observes:",
        "",
    ]
    for operation in authority["observed_operations"]:
        lines.append(f"- `{operation}`")
    lines += [
        "",
        "## Deliberate non-enforcement",
        "",
        "Patch 20.4 only increments observation counters. In particular, an",
        "observed `Arena.Free` leaves the lifecycle state `live`, the CR-13",
        "opening witness remains accepted, and no new diagnostic is emitted.",
        "Patch 20.5 exclusively owns the transition to `freed` and rejection of",
        "later use through every alias.",
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
                    "generated Patch 20.4 review is stale; run project")
    except (Error, KeyError, StopIteration) as error:
        print(f"{GUARD}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
