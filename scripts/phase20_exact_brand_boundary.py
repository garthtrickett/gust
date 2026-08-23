#!/usr/bin/env python3
"""Validate and project the Patch 20.3 exact branded-boundary authority."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_EXACT_BRAND_BOUNDARY.md"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
JUSTFILE = ROOT / "justfile"
GUARD = "guard-cranelift-phase20-exact-brand-boundary-contract"


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    authority = registry.get("phase20_exact_brand_boundary")
    require(isinstance(authority, dict), "Patch 20.3 authority is missing")
    require(authority.get("authority_version") == "phase20_exact_brand_boundary_v1",
            "Patch 20.3 authority version drifted")
    require(authority.get("status") == "patch20_3_complete",
            "Patch 20.3 status drifted")
    require(authority.get("next_patch") == "20.3a",
            "Patch 20.3 successor drifted")
    require(authority.get("issue") == "CR-12/#159",
            "Patch 20.3 issue ownership drifted")
    require(authority.get("opening_probe_fix_enabled") is True,
            "CR-12 opening probe is not enabled")

    expected_coverage = [
        "explicit_annotation", "direct_assignment", "function_argument",
        "function_return", "Index", "field", "import_alias",
        "generic_substitution",
    ]
    require(authority.get("coverage") == expected_coverage,
            "Patch 20.3 coverage drifted")
    for key in (
        "semantic_fixture", "positive_fixture", "positive_import_fixture",
        "issue_fixture", "canonical_mir_fixture",
    ):
        require((ROOT / authority[key]).is_file(),
                f"Patch 20.3 file is missing: {authority[key]}")
    negatives = authority.get("negative_fixtures")
    require(isinstance(negatives, list) and len(negatives) == 5,
            "Patch 20.3 negative fixture matrix drifted")
    for path in negatives:
        require((ROOT / path).is_file(), f"negative fixture is missing: {path}")

    source = TYPECHECKER.read_text(encoding="utf-8")
    for evidence in (
        "func env_types_match_at_brand_boundary(",
        "func typechecker_apply_brand_substitutions(",
        "func typechecker_substitute_call_brand_identity(",
        "mut call_brand_substitutions: std.HashMap[str, str, ctx]",
        "brand_identity_nesting_membership(expected_identity, actual_identity)",
        "env_types_match_at_brand_boundary(env, resolved_explicit, val_type, ctx)",
        "env_types_match_at_brand_boundary(env, left_type, val_type, ctx)",
        "env_types_match_at_brand_boundary(env, expected_type, resolved_arg, ctx)",
        "env_types_match_at_brand_boundary(env, expected_t, actual_return, ctx)",
    ):
        require(evidence in source, f"Patch 20.3 compiler evidence missing: {evidence}")

    semantic = (ROOT / authority["semantic_fixture"]).read_text(encoding="utf-8")
    for evidence in (
        "legacy structural observation", "distinct identities", "same identity",
        "authorized Any wildcard", "existing unbranded compatibility",
        "import alias", "generic substitution", "per-formal call substitution",
    ):
        require(evidence in semantic, f"semantic fixture coverage missing: {evidence}")
    positive = (ROOT / authority["positive_fixture"]).read_text(encoding="utf-8")
    require("std.Clone(ctx, source)" in positive and "return 23" in positive,
            "same-brand positive fixture drifted")
    issue = (ROOT / authority["issue_fixture"]).read_text(encoding="utf-8")
    require("rejects_distinct_destination_brand_at_generic_type_boundary" in issue and
            "fixed_by: 20.3" in issue,
            "CR-12 issue fixture does not record the correction")
    mir = (ROOT / authority["canonical_mir_fixture"]).read_text(encoding="utf-8")
    require("block_0_terminator_kind: ReturnI32" in mir and
            "block_0_terminator_value: 23" in mir and "expected_exit: 23" in mir,
            "Patch 20.3 canonical MIR projection drifted")

    opening = registry.get("opening_snapshots", {}).get("phase20", {})
    probes = opening.get("baseline_probes", [])
    cr12 = next((probe for probe in probes
                 if probe.get("id") == "cr12_wrong_brand_clone_destination"), {})
    require(opening.get("status") == "ready_for_patch20_3a" and
            opening.get("next_patch") == "20.3a",
            "Phase 20 opening successor did not advance")
    require(cr12.get("compile_exit") == 1 and cr12.get("fix_enabled") is True and
            cr12.get("diagnostic_substrings") ==
            ["[TypeMismatch] Explicit Type Annotation Mismatch"],
            "CR-12 opening probe did not record the corrected result")

    require("- [x] Patch 20.3 — Exact Branded Assignment and Annotation (CR-12/#159) — DONE" in
            TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 20.3 DONE")
    workflow = PR_FAST.read_text(encoding="utf-8")
    require("Phase 20 exact branded boundary" in workflow and
            "just guard-cranelift-phase20-exact-brand-boundary-contract" in workflow and
            "just guard-cranelift-phase20-exact-brand-boundary-parity" in workflow,
            "PR Fast does not own both Patch 20.3 levels")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require("guard-cranelift-phase20-exact-brand-boundary-contract:" in justfile and
            "guard-cranelift-phase20-exact-brand-boundary-parity:" in justfile,
            "Patch 20.3 just guards are missing")
    return authority


def render(authority: dict) -> str:
    lines = [
        "# Cranelift Phase 20 Exact Brand Boundary",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_exact_brand_boundary.py project`. Do not edit by hand.",
        "",
        f"- Authority version: `{authority['authority_version']}`",
        f"- Status: `{authority['status']}`",
        f"- Next patch: `{authority['next_patch']}`",
        f"- Issue: `{authority['issue']}`",
        "",
        "## Semantic correction",
        "",
        "After ordinary structural matching and brand substitution, typed value",
        "boundaries compare both resolved arena identities. Two present identities",
        "must be the same, except for the existing `Any` nesting rule. Existing",
        "unbranded compatibility remains unchanged when either identity is absent.",
        "",
        "This rule is generic: Clone, Index, Graph, and library type names are not",
        "special-cased. It applies at annotation, assignment, argument, return,",
        "field, alias, and generic payload boundaries.",
        "",
        "## Evidence",
        "",
    ]
    for item in authority["coverage"]:
        lines.append(f"- `{item}`")
    lines += [
        "",
        "The frontend validates the same-brand program and the rejected matrix.",
        "Its selected `main -> 23` projection is executed through MIR-to-C and",
        "Cranelift from identical canonical MIR. The direct Cranelift source route",
        "remains an explicit pre-driver rejection until Patch 20.12, with no C",
        "fallback.",
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
                    "generated Patch 20.3 review is stale; run project")
    except (Error, KeyError) as error:
        print(f"{GUARD}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
