#!/usr/bin/env python3
"""Validate and project Patch 20.14a generic guard prerequisites."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
TASK = ROOT / "TASK.md"
VISION = ROOT / "docs/VISION.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_GENERIC_GUARD_PREREQUISITES.md"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
JUSTFILE = ROOT / "justfile"
GUARD = "guard-cranelift-phase20-generic-guard-prerequisites-contract"


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    authority = registry.get("phase20_generic_guard_prerequisites")
    require(isinstance(authority, dict), "Patch 20.14a authority is missing")
    require(authority.get("authority_version") ==
            "phase20_generic_guard_prerequisites_v2",
            "Patch 20.14a authority version drifted")
    require(authority.get("status") == "patch20_14a_complete",
            "Patch 20.14a status drifted")
    require(authority.get("next_patch") == "20.14b",
            "Patch 20.14a successor drifted")
    require(authority.get("decision_at_patch") ==
            "OD_13_open_during_patch20_14a",
            "Patch 20.14a historical OD-13 state drifted")
    require(authority.get("decision_successor_status") ==
            "OD_13_resolved_2026_08_24",
            "OD-13 successor decision drifted")
    require(authority.get("decision_authority_patch") == "20.16a" and
            authority.get("implementation_transition") ==
            ["20.16b", "20.16c", "20.16d", "20.16e"],
            "OD-13 implementation sequencing drifted")

    for key in ("semantic_fixture", "positive_fixture", "canonical_mir_fixture"):
        require((ROOT / authority[key]).is_file(),
                f"Patch 20.14a file is missing: {authority[key]}")
    negatives = authority.get("negative_fixtures")
    require(negatives == [
        "compiler/phase20_generic_resource_destructor_wrong_type_invalid.gst",
        "compiler/phase20_generic_resource_destructor_wrong_brand_invalid.gst",
    ], "generic Resource negative fixture matrix drifted")
    require(authority.get("provenance_negative_cases") ==
            ["raw_derived", "sandbox_derived"],
            "non-laundering negative provenance matrix drifted")
    for path in negatives:
        require((ROOT / path).is_file(), f"negative fixture is missing: {path}")

    typechecker = TYPECHECKER.read_text(encoding="utf-8")
    for evidence in (
        "mut reference_inner_param_origin := ctx[t.Reference.inner];",
        "if reference_inner_param_origin.Struct.brand != empty[Index[str, ctx]]",
        "mut expected_parameter_type := make_type_struct(type_name, \"\", ctx);",
        "mut brand_parameter_index := env_get_template_brand_parameter_index(",
        "env_types_match_at_brand_boundary(",
        "env, expected_parameter_type, parameter_type, ctx",
    ):
        require(evidence in typechecker,
                f"generic frontend evidence is missing: {evidence}")

    positive = (ROOT / authority["positive_fixture"]).read_text(encoding="utf-8")
    for evidence in (
        "Phase20GenericGuardResource[ctx]",
        "destroy_phase20_generic_guard_resource(resource: Phase20GenericGuardResource[ctx])",
        "value: &Phase20GuardValue[ctx]",
        "func capture_phase20_reference(value: &Phase20GuardValue[ctx])",
        "result.value = value;",
        "return 37;",
    ):
        require(evidence in positive, f"positive fixture coverage missing: {evidence}")

    semantic = (ROOT / authority["semantic_fixture"]).read_text(encoding="utf-8")
    for evidence in (
        "expression_provenance_raw_derived(reference_type, ctx)",
        "expression_provenance_sandbox_derived(reference_type, ctx)",
        "env_record_safe_parameter_provenance(&env, \"source\", reference_type, ctx)",
        "unsafe-derived branded reference capture was accepted",
    ):
        require(evidence in semantic,
                f"provenance witness coverage missing: {evidence}")

    mir = (ROOT / authority["canonical_mir_fixture"]).read_text(encoding="utf-8")
    require("block_0_terminator_value: 37" in mir and "expected_exit: 37" in mir,
            "Patch 20.14a canonical MIR projection drifted")

    vision = VISION.read_text(encoding="utf-8")
    for evidence in (
        "| OD-13 | ~~**Mutex protected-access contract**",
        "**RESOLVED 2026-08-24**",
        "non-forgeable, move-only linear guard",
        "separate access token",
    ):
        require(evidence in vision, f"resolved OD-13 evidence is missing: {evidence}")
    task = TASK.read_text(encoding="utf-8")
    for evidence in (
        "- [x] Patch 20.14a — Generic Guard Prerequisite Corrections — DONE",
        "- [x] Patch 20.16a — Mutex Guard Decision and Implementation Authority — DONE",
        "- [x] Patch 20.16b — Inert Resource-Rooted Access Authority — DONE",
        "- [x] Patch 20.16c — Explicit-Unsafe Mutex Primitive Migration — DONE",
        "- [x] Patch 20.16d — Protected-Access Liveness Enforcement — DONE",
        "- [ ] Patch 20.16e — Protected-Access Bootstrap Seed Reconvergence",
    ):
        require(evidence in task, f"TASK.md OD-13 sequencing is missing: {evidence}")

    workflow = PR_FAST.read_text(encoding="utf-8")
    require("Phase 20 generic guard prerequisites" in workflow and
            "just guard-cranelift-phase20-generic-guard-prerequisites-contract" in workflow and
            "just guard-cranelift-phase20-generic-guard-prerequisites-parity" in workflow,
            "PR Fast does not own both Patch 20.14a levels")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require("guard-cranelift-phase20-generic-guard-prerequisites-contract:" in justfile and
            "guard-cranelift-phase20-generic-guard-prerequisites-parity:" in justfile,
            "Patch 20.14a just guards are missing")
    return authority


def render(authority: dict) -> str:
    return "\n".join([
        "# Cranelift Phase 20 Generic Guard Prerequisites",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_generic_guard_prerequisites.py project`. Do not edit by hand.",
        "",
        f"- Authority version: `{authority['authority_version']}`",
        f"- Status: `{authority['status']}`",
        f"- Next patch: `{authority['next_patch']}`",
        "",
        "## Corrections",
        "",
        "A generic Resource destructor parameter is checked against the canonical",
        "declared template after its brand parameter is substituted. A safe",
        "reference parameter whose pointee carries the same resolved brand keeps",
        "safe-parameter provenance through aggregate field assignment and return.",
        "",
        "The change does not weaken non-laundering: raw-derived and sandbox-derived",
        "references remain rejected. Wrong owned types and wrong brands remain",
        "`ResourceDestructorSignature` failures. There is no Mutex-specific path.",
        "",
        "## Backend and historical decision boundary",
        "",
        "The accepted source returns 37 through MIR-to-C; the same selected",
        "observable returns 37 through supported canonical MIR and Cranelift.",
        "During Patch 20.14a, `Mutex.Lock()` still returned `RawPointer(T)` with",
        "explicit `Unlock()` and OD-13 remained open. That phase-frozen fact is",
        "retained by `decision_at_patch`; it is not current decision authority.",
        "",
        "## Resolved successor and implementation boundary",
        "",
        "The operator resolved OD-13 on 2026-08-24. Safe acquisition returns one",
        "move-only linear guard carrying context-branded protected access and",
        "owning automatic exactly-once unlock on every scope exit. The guard is",
        "the authority; no separate compiler access token is introduced. Raw",
        "pointer/manual unlock may remain only explicit unsafe or internal machinery.",
        "",
        "Patch 20.16a records that decision without changing behaviour. Patches",
        "20.16b–20.16e stage inert generic resource-rooted authority, whole-tree",
        "raw-primitive migration, protected-access liveness enforcement, and",
        "isolated seed convergence. The registrar handoff occurs only after checked",
        "Patch 20.16d implementation authority lands. Stdlib API ergonomics remain",
        "outside this record.",
        "",
    ])


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
                    "generated Patch 20.14a review is stale; run project")
    except (Error, KeyError) as error:
        print(f"{GUARD}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
