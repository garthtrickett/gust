#!/usr/bin/env python3
"""Validate and project the Patch 20.2 nested-brand annotation authority."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_NESTED_BRAND_ANNOTATION.md"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
JUSTFILE = ROOT / "justfile"
GUARD = "guard-cranelift-phase20-nested-brand-annotation-contract"


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    authority = registry.get("phase20_nested_brand_annotation")
    require(isinstance(authority, dict), "Patch 20.2 authority is missing")
    require(authority.get("authority_version") ==
            "phase20_nested_brand_annotation_correction_v1",
            "Patch 20.2 authority version drifted")
    require(authority.get("status") == "patch20_2_complete",
            "Patch 20.2 status drifted")
    require(authority.get("next_patch") == "20.3",
            "Patch 20.2 successor drifted")
    require(authority.get("issue") == "CR-11/#158",
            "Patch 20.2 issue ownership drifted")
    require(authority.get("opening_probe_fix_enabled") is True,
            "CR-11 opening probe is not enabled")

    expected_coverage = [
        "two_nested_brands",
        "three_nested_brands",
        "explicit_declaration",
        "inferred_declaration",
        "import_alias",
        "field_brand",
        "illegal_escape",
    ]
    require(authority.get("coverage") == expected_coverage,
            "Patch 20.2 coverage drifted")

    for key in (
        "positive_fixture", "positive_import_fixture", "issue_fixture",
        "negative_fixture", "canonical_mir_fixture", "review_view",
    ):
        path = ROOT / authority[key]
        require(path.is_file(), f"Patch 20.2 file is missing: {authority[key]}")

    source = TYPECHECKER.read_text(encoding="utf-8")
    for evidence in (
        "mut resolved_nested_template := 0;",
        "mut substituted_args: std.Vector[ast.Type[ctx], ctx]",
        "if resolved_match == 1",
        "brand_identity_mismatch_description(parent_identity, element_identity, ctx)",
        "mut preserved_nesting_error_count := 0;",
        "start_err_len + preserved_nesting_error_count",
    ):
        require(evidence in source, f"Patch 20.2 compiler evidence missing: {evidence}")
    require("mut clean_name := strip_brand_prefix(name, ctx);" not in source,
            "brand nesting still shortcuts through stripped struct spelling")

    positive = (ROOT / authority["positive_fixture"]).read_text(encoding="utf-8")
    for evidence in (
        "std.Graph[Phase20GraphNode, application_arena]",
        "mut inferred := move explicit",
        "model.ImportedGraphNode",
        "holder.arena",
        "std.Pool[std.GraphNode[Phase20GraphNode, application_arena], application_arena]",
        "return 20",
    ):
        require(evidence in positive, f"positive coverage missing: {evidence}")

    issue = (ROOT / authority["issue_fixture"]).read_text(encoding="utf-8")
    require("accepts_explicit_graph_annotation_with_resolved_nested_brand_identity" in issue,
            "CR-11 fixture does not record the corrected result")
    negative = (ROOT / authority["negative_fixture"]).read_text(encoding="utf-8")
    require("inner_arena" in negative and "outer_arena" in negative,
            "illegal nested-brand fixture drifted")
    mir = (ROOT / authority["canonical_mir_fixture"]).read_text(encoding="utf-8")
    require("block_0_terminator_kind: ReturnI32" in mir and
            "block_0_terminator_value: 20" in mir and
            "expected_exit: 20" in mir,
            "Patch 20.2 canonical MIR projection drifted")

    opening = registry.get("opening_snapshots", {}).get("phase20", {})
    probes = opening.get("baseline_probes", [])
    require(opening.get("status") == "ready_for_patch20_7" and
            opening.get("next_patch") == "20.7",
            "Phase 20 opening successor did not advance")
    require(probes and probes[0].get("compile_exit") == 0 and
            probes[0].get("fix_enabled") is True and
            probes[0].get("diagnostic_substrings") == [],
            "CR-11 opening probe did not record the corrected result")

    require("- [x] Patch 20.2 — Nested Brand Annotation Correction (CR-11/#158) — DONE" in
            TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 20.2 DONE")
    workflow = PR_FAST.read_text(encoding="utf-8")
    require("Phase 20 nested brand annotation" in workflow and
            "just guard-cranelift-phase20-nested-brand-annotation-contract" in workflow and
            "just guard-cranelift-phase20-nested-brand-annotation-parity" in workflow,
            "PR Fast does not own both Patch 20.2 levels")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require("guard-cranelift-phase20-nested-brand-annotation-contract:" in justfile and
            "guard-cranelift-phase20-nested-brand-annotation-parity:" in justfile,
            "Patch 20.2 just guards are missing")
    return authority


def render(authority: dict) -> str:
    lines = [
        "# Cranelift Phase 20 Nested Brand Annotation",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_nested_brand_annotation.py project`. Do not edit by hand.",
        "",
        f"- Authority version: `{authority['authority_version']}`",
        f"- Status: `{authority['status']}`",
        f"- Next patch: `{authority['next_patch']}`",
        f"- Issue: `{authority['issue']}`",
        "",
        "## Semantic correction",
        "",
        "Nested generic placeholders are instantiated while their substitution",
        "arguments are still typed. Brand nesting then compares resolved arena",
        "identities; flattened type-name spelling is not an acceptance input.",
        "",
        "A primary nesting diagnostic remains in the environment while the",
        "successfully constructed generic type is preserved. This prevents a",
        "secondary declaration mismatch against synthetic `Void`.",
        "",
        "## Evidence",
        "",
    ]
    for item in authority["coverage"]:
        lines.append(f"- `{item}`")
    lines += [
        "",
        "The frontend validates the full accepted program. Its unreachable type",
        "annotation probes project to the selected `main -> 20` canonical MIR,",
        "which MIR-to-C and Cranelift execute with the same observable result.",
        "The direct whole-program Cranelift source route remains an explicit",
        "pre-driver source/type rejection until Patch 20.12; no C fallback is",
        "permitted.",
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
                    "generated Patch 20.2 review is stale; run project")
    except (Error, KeyError) as error:
        print(f"{GUARD}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
