#!/usr/bin/env python3
"""Validate and project the canonical brand-matching authority through Patch 20.2."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
FIXTURE = ROOT / "compiler/typechecker_phase20_brand_matching_test_entry.gst"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_BRAND_MATCHING.md"
TASK = ROOT / "TASK.md"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
GUARD = "guard-cranelift-phase20-brand-matching-contract"

OPERATIONS = [
    "brand_identity_exact_match",
    "brand_identity_nesting_membership",
    "brand_identity_mismatch_description",
]
SHADOW_FIELDS = [
    "brand_match_shadow_checks",
    "brand_match_shadow_agreements",
    "brand_match_shadow_disagreements",
]


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def load_registry() -> dict:
    return json.loads(REGISTRY.read_text(encoding="utf-8"))


def validate() -> dict:
    registry = load_registry()
    authority = registry.get("phase20_brand_matching")
    require(isinstance(authority, dict), "Phase 20 brand-matching authority is missing")
    require(authority.get("authority_version") == "phase20_canonical_brand_matching_v3",
            "Phase 20 brand-matching authority version drifted")
    require(authority.get("status") == "patch20_3_exact_boundaries_enabled",
            "Phase 20 brand-matching status drifted")
    require(authority.get("next_patch") == "20.4",
            "Phase 20 brand-matching successor drifted")
    require(authority.get("identity_authority") == "phase19_brand_identity_authority_v1",
            "Phase 20 brand matching lost its Phase 19 identity authority")
    require(authority.get("operations") == OPERATIONS,
            "canonical brand-matching operation set drifted")
    require(authority.get("shadow_fields") == SHADOW_FIELDS,
            "brand-matching shadow observation fields drifted")
    require(authority.get("legacy_acceptance_function") ==
            "env_is_element_allowed_in_brand",
            "legacy nesting acceptance owner drifted")
    require(authority.get("legacy_string_cleaner") == "strip_brand_prefix",
            "legacy brand string cleaner drifted")
    require(authority.get("semantic_fixture") ==
            "compiler/typechecker_phase20_brand_matching_test_entry.gst",
            "Phase 20 brand-matching fixture drifted")
    require(authority.get("behavior_policy") ==
            "resolved_identity_authoritative_for_brand_nesting_and_typed_value_boundaries_with_legacy_shadow_observation_only",
            "Patch 20.3 canonical boundary policy drifted")
    require(authority.get("opening_probe_fixes_enabled") is True,
            "Patch 20.2 must enable the CR-11 opening defect fix")

    opening = registry.get("opening_snapshots", {}).get("phase20", {})
    probes = opening.get("baseline_probes", [])
    require(len(probes) == 5 and probes[0].get("id") == "cr11_explicit_graph_annotation" and
            probes[0].get("fix_enabled") is True and
            probes[1].get("id") == "cr12_wrong_brand_clone_destination" and
            probes[1].get("fix_enabled") is True and
            all(probe.get("fix_enabled") is False for probe in probes[2:]),
            "Patch 20.3 must enable exactly the CR-11 and CR-12 opening fixes")

    source = TYPECHECKER.read_text(encoding="utf-8")
    for operation in OPERATIONS:
        require(f"func {operation}(" in source,
                f"canonical brand operation missing: {operation}")
    for field in SHADOW_FIELDS:
        require(f"{field}: int" in source,
                f"brand shadow field missing: {field}")
        require(f"env_ref_new.{field} = 0;" in source,
                f"brand shadow field is not initialized: {field}")
    require("func env_record_brand_match_shadow(" in source,
            "brand shadow recorder is missing")
    require("brand_identity_nesting_membership(parent_identity, element_identity)" in source,
            "legacy nesting path does not observe the canonical decision")
    require("if resolved_match == 1" in source,
            "resolved nesting result is not authoritative")

    cleaner_files = []
    occurrence_count = 0
    for path in sorted(ROOT.joinpath("compiler").glob("*.gst")):
        count = path.read_text(encoding="utf-8").count("strip_brand_prefix(")
        if count:
            cleaner_files.append(path.relative_to(ROOT).as_posix())
            occurrence_count += count
    require(occurrence_count == authority.get("frozen_string_cleaner_occurrences"),
            "legacy string-cleaner inventory drifted; Patch 20.2 freezes 48 occurrences")
    require(occurrence_count - 1 == authority.get("frozen_string_cleaner_callers"),
            "legacy string-cleaner caller count drifted")
    require(cleaner_files == authority.get("frozen_string_cleaner_owner_files"),
            "legacy brand string cleaner owner-file inventory drifted")

    require(FIXTURE.is_file(), "Phase 20 brand-matching semantic fixture is missing")
    fixture = FIXTURE.read_text(encoding="utf-8")
    for evidence in (
        "distinct same-shaped arena values matched",
        "nested pointer/reference",
        "resolved field",
        "resolved import alias",
        "generic substitution",
        "brand_match_shadow_disagreements != 1",
    ):
        require(evidence in fixture, f"brand identity fixture evidence missing: {evidence}")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 20.1 — Canonical Brand-Matching Primitives — DONE" in task,
            "TASK.md does not mark Patch 20.1 DONE")
    workflow = PR_FAST.read_text(encoding="utf-8")
    require("Phase 20 canonical brand matching" in workflow and
            "run: just guard-cranelift-phase20-brand-matching-contract" in workflow,
            "PR Fast does not own the Patch 20.1 guard")
    return authority


def render(authority: dict) -> str:
    lines = [
        "# Cranelift Phase 20 Canonical Brand Matching",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_brand_matching.py project`. Do not edit by hand.",
        "",
        f"- Authority version: `{authority['authority_version']}`",
        f"- Status: `{authority['status']}`",
        f"- Next patch: `{authority['next_patch']}`",
        f"- Identity authority: `{authority['identity_authority']}`",
        f"- Behaviour policy: `{authority['behavior_policy']}`",
        "",
        "## Canonical operations",
        "",
    ]
    for operation in authority["operations"]:
        lines.append(f"- `{operation}`")
    lines += [
        "",
        "Exact matching compares non-empty resolved arena identities and ignores",
        "their provenance labels. Nesting membership adds the existing `Any`",
        "wildcard policy. Mismatch text is produced from the same identities.",
        "",
        "## Behaviour-neutral shadow",
        "",
        "`env_is_element_allowed_in_brand` owns nesting acceptance and now returns",
        "the resolved-identity answer. The previous `strip_brand_prefix` result is",
        "retained only as a disagreement counter and cannot accept or reject source.",
        "",
        f"The frozen source contains `{authority['frozen_string_cleaner_callers']}`",
        "legacy cleaner calls (plus the function definition). Later patches must",
        "remove those callers from this baseline rather than adding parallel rules.",
        "",
        "The semantic fixture covers nested wrappers, distinct same-shaped arena",
        "identities, registered fields, import aliases, generic substitution, exact",
        "and wildcard comparison, mismatch text, and both shadow agreement states.",
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
            require(REVIEW.is_file(), "generated Phase 20 brand-matching review is missing")
            require(REVIEW.read_text(encoding="utf-8") == render(authority),
                    "generated Phase 20 brand-matching review is stale; run project")
    except Error as error:
        print(f"{GUARD}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
