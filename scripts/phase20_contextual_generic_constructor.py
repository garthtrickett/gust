#!/usr/bin/env python3
"""Validate and project Patch 20.3a contextual constructor authority."""

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
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_CONTEXTUAL_GENERIC_CONSTRUCTOR.md"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
JUSTFILE = ROOT / "justfile"
GUARD = "guard-cranelift-phase20-contextual-generic-constructor-contract"


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    authority = registry.get("phase20_contextual_generic_constructor")
    require(isinstance(authority, dict), "Patch 20.3a authority is missing")
    require(authority.get("authority_version") ==
            "phase20_contextual_generic_constructor_result_v1",
            "Patch 20.3a authority version drifted")
    require(authority.get("status") == "patch20_3a_complete",
            "Patch 20.3a status drifted")
    require(authority.get("next_patch") == "20.4",
            "Patch 20.3a successor drifted")
    require(authority.get("context_boundaries") == [
        "explicit_annotation", "direct_assignment", "function_argument",
        "function_return",
    ], "contextual boundary coverage drifted")
    require(authority.get("constructor_families") == [
        "Vector", "HashMap", "Pool", "Mutex", "Channel", "Graph",
    ], "generic constructor-family coverage drifted")

    for key in ("inferred_fixture", "explicit_fixture", "canonical_mir_fixture"):
        require((ROOT / authority[key]).is_file(),
                f"Patch 20.3a file is missing: {authority[key]}")
    negatives = authority.get("negative_fixtures")
    require(isinstance(negatives, list) and len(negatives) == 2,
            "Patch 20.3a negative fixture matrix drifted")
    for path in negatives:
        require((ROOT / path).is_file(), f"negative fixture is missing: {path}")

    typechecker = TYPECHECKER.read_text(encoding="utf-8")
    for evidence in (
        "func typechecker_is_contextual_generic_constructor_name(",
        "func typechecker_record_contextual_expression_type(",
        "func typechecker_contextualize_generic_constructor_result(",
        "env_types_match_at_brand_boundary(env, resolved_expected, resolved_actual, ctx)",
        "typechecker_record_contextual_expression_type(expr_idx, resolved_expected, env, ctx)",
        "val_idx, resolved_explicit, val_type, env, ctx",
        "val_idx, left_type, val_type, env, ctx",
        "arg_idx_check_call_nlaunder, expected_type, resolved_arg, env, ctx",
        "expr_idx, ctx[(*env).expected_return_type], actual_return, env, ctx",
    ):
        require(evidence in typechecker,
                f"contextual typechecker evidence missing: {evidence}")

    codegen = CODEGEN.read_text(encoding="utf-8")
    require("func codegen_contextual_constructor_struct_name(" in codegen,
            "contextual MIR-to-C type consumer is missing")
    require(codegen.count("codegen_contextual_constructor_struct_name(") == 7,
            "all six constructor families must share one contextual codegen helper")
    require("if codegen_ends_with(recorded, \"_Any\") == 0" in codegen,
            "MIR-to-C does not distinguish a resolved result from the placeholder")

    inferred = (ROOT / authority["inferred_fixture"]).read_text(encoding="utf-8")
    explicit = (ROOT / authority["explicit_fixture"]).read_text(encoding="utf-8")
    for evidence in (
        "return std.ChannelNew(ctx);",
        "return std.VectorNew(ctx);",
        "consume_contextual_vector(std.VectorNew(ctx))",
        "assigned = std.VectorNew(&application_arena);",
        "return 31;",
    ):
        require(evidence in inferred and evidence in explicit,
                f"paired contextual fixture coverage missing: {evidence}")
    require("mut inferred_channel :=" in inferred and
            "mut inferred_channel: std.Channel[int, application_arena]" in explicit,
            "inferred/explicit Channel pair drifted")
    require("mut inferred_vector :=" in inferred and
            "mut inferred_vector: std.Vector[int, application_arena]" in explicit,
            "non-Channel inferred/explicit control drifted")

    cross_template = (ROOT / negatives[0]).read_text(encoding="utf-8")
    wrong_brand = (ROOT / negatives[1]).read_text(encoding="utf-8")
    require("std.Vector[int, ctx] := std.ChannelNew" in cross_template,
            "cross-template negative drifted")
    require("std.Channel[int, origin]" in wrong_brand and
            "std.ChannelNew(destination)" in wrong_brand,
            "wrong-brand negative drifted")

    mir = (ROOT / authority["canonical_mir_fixture"]).read_text(encoding="utf-8")
    require("block_0_terminator_value: 31" in mir and "expected_exit: 31" in mir,
            "Patch 20.3a canonical MIR projection drifted")
    opening = registry.get("opening_snapshots", {}).get("phase20", {})
    require(opening.get("status") == "ready_for_patch20_11" and
            opening.get("next_patch") == "20.11",
            "Phase 20 opening successor did not advance")
    require("- [x] Patch 20.3a — Contextual Generic Constructor Result Authority — DONE" in
            TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 20.3a DONE")

    workflow = PR_FAST.read_text(encoding="utf-8")
    require("Phase 20 contextual generic constructor" in workflow and
            "just guard-cranelift-phase20-contextual-generic-constructor-contract" in workflow and
            "just guard-cranelift-phase20-contextual-generic-constructor-parity" in workflow,
            "PR Fast does not own both Patch 20.3a levels")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require("guard-cranelift-phase20-contextual-generic-constructor-contract:" in justfile and
            "guard-cranelift-phase20-contextual-generic-constructor-parity:" in justfile,
            "Patch 20.3a just guards are missing")
    return authority


def render(authority: dict) -> str:
    lines = [
        "# Cranelift Phase 20 Contextual Generic Constructor Result",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_contextual_generic_constructor.py project`. Do not edit by hand.",
        "",
        f"- Authority version: `{authority['authority_version']}`",
        f"- Status: `{authority['status']}`",
        f"- Next patch: `{authority['next_patch']}`",
        "",
        "## Semantic correction",
        "",
        "An already-resolved compatible annotation, assignment, argument, or",
        "return type is the result authority for a generic constructor expression.",
        "Normal template, payload, and exact-brand matching must succeed first;",
        "context does not authorize a conversion or cast.",
        "",
        "MIR-to-C consumes that recorded semantic result. It does not reconstruct",
        "an `_Any` specialization from a constructor spelling. The rule is shared",
        "by every registered constructor family and contains no Channel-only path.",
        "",
        "## Evidence",
        "",
    ]
    for boundary in authority["context_boundaries"]:
        lines.append(f"- Context boundary: `{boundary}`")
    for family in authority["constructor_families"]:
        lines.append(f"- Constructor family: `{family}`")
    lines += [
        "",
        "The inferred/explicit pair emits byte-identical, host-compilable C and",
        "returns 31. Cross-template and wrong-brand contexts remain rejected.",
        "Selected canonical MIR returns 31 through MIR-to-C and Cranelift. The",
        "direct Cranelift source route remains an explicit pre-driver deferral",
        "with no C fallback. Seed publication remains isolated to Patch 20.11.",
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
                    "generated Patch 20.3a review is stale; run project")
    except (Error, KeyError) as error:
        print(f"{GUARD}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
