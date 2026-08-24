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
            "phase20_generic_guard_prerequisites_v1",
            "Patch 20.14a authority version drifted")
    require(authority.get("status") == "patch20_14a_complete",
            "Patch 20.14a status drifted")
    require(authority.get("next_patch") == "20.14b",
            "Patch 20.14a successor drifted")

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
    require("| OD-13 | **Mutex protected-access contract**" in vision and
            "Mutex.Lock()` currently returns `RawPointer(T)`" in vision,
            "OD-13 or the unchanged Mutex contract is missing")
    require("- [x] Patch 20.14a — Generic Guard Prerequisite Corrections — DONE"
            in TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 20.14a DONE")

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
        "## Backend and open-decision boundary",
        "",
        "The accepted source returns 37 through MIR-to-C; the same selected",
        "observable returns 37 through supported canonical MIR and Cranelift.",
        "`Mutex.Lock()` still returns `RawPointer(T)` with explicit `Unlock()`.",
        "OD-13 remains open and Patch 20.14a makes no Stdlib API, MIR, ABI, layout,",
        "or runtime-symbol decision. The compiler-source change is followed by",
        "the isolated Patch 20.14b seed reconvergence before Patch 20.15.",
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
