#!/usr/bin/env python3
"""Validate and project Patch 20.6 inert resource declaration metadata."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
AST = ROOT / "compiler/ast.gst"
PARSER = ROOT / "compiler/parser.gst"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_INERT_RESOURCE_SURFACE.md"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
JUSTFILE = ROOT / "justfile"
GUARD = "guard-cranelift-phase20-inert-resource-surface-contract"


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    authority = registry.get("phase20_inert_resource_surface")
    require(isinstance(authority, dict), "Patch 20.6 authority is missing")
    require(authority.get("authority_version") ==
            "phase20_inert_resource_surface_v1",
            "Patch 20.6 authority version drifted")
    require(authority.get("status") == "patch20_6_complete",
            "Patch 20.6 status drifted")
    require(authority.get("next_patch") == "20.7",
            "Patch 20.6 successor drifted")
    require(authority.get("issue") == "CR-5/#106",
            "Patch 20.6 issue ownership drifted")
    require(authority.get("attributes") == [
        "destructor(name)", "opaque", "private",
    ], "Patch 20.6 attribute surface drifted")
    require(authority.get("enforcement_enabled") is False,
            "Patch 20.6 must remain an inert syntax/metadata patch")

    for key in ("parser_fixture", "noop_fixture", "module_fixture"):
        require((ROOT / authority[key]).is_file(),
                f"Patch 20.6 fixture is missing: {authority[key]}")

    ast_source = AST.read_text(encoding="utf-8")
    for evidence in (
        "declared_destructor_name: str", "is_opaque: int",
        "is_private: int", "#[destructor(", "#[opaque]", "#[private]",
    ):
        require(evidence in ast_source,
                f"Patch 20.6 AST evidence missing: {evidence}")

    parser_source = PARSER.read_text(encoding="utf-8")
    for evidence in (
        'std.str_eq(layout_attr_name, "destructor")',
        'std.str_eq(layout_attr_name, "opaque")',
        'std.str_eq(layout_attr_name, "private")',
        "parse_function_decl_with_private(",
        *authority["malformed_diagnostics"],
        *authority["duplicate_diagnostics"], authority["conflict_diagnostic"],
    ):
        require(evidence in parser_source,
                f"Patch 20.6 parser evidence missing: {evidence}")

    typechecker_source = TYPECHECKER.read_text(encoding="utf-8")
    for evidence in (
        "struct_declared_destructor: std.HashMap[str, str, ctx]",
        "struct_declared_opaque: std.HashMap[str, int, ctx]",
        "func env_register_inert_resource_declaration_metadata(",
        "func env_struct_declared_destructor_name(",
        "func env_struct_is_declared_opaque(",
        "sig.is_private = stmt.FunctionDecl.is_private",
    ):
        require(evidence in typechecker_source,
                f"Patch 20.6 inert type metadata missing: {evidence}")
    require("env_register_struct_linear_destructor(\n                env" not in
            typechecker_source,
            "declared destructor metadata leaked into live cleanup authority")

    parser_fixture = (ROOT / authority["parser_fixture"]).read_text(
        encoding="utf-8")
    for diagnostic in (
        *authority["malformed_diagnostics"],
        *authority["duplicate_diagnostics"], authority["conflict_diagnostic"],
    ):
        require(diagnostic in parser_fixture,
                f"Patch 20.6 diagnostic fixture drifted: {diagnostic}")
    for evidence in (
        "env_struct_has_linear_destructor", "ast.serialize_program",
        "private_lookup.Val.is_private",
    ):
        require(evidence in parser_fixture,
                f"Patch 20.6 metadata/no-op witness missing: {evidence}")

    noop_fixture = (ROOT / authority["noop_fixture"]).read_text(
        encoding="utf-8")
    module_fixture = (ROOT / authority["module_fixture"]).read_text(
        encoding="utf-8")
    for evidence in ("handle.token = 42", "resource.close_guard(handle)"):
        require(evidence in noop_fixture,
                f"Patch 20.6 external no-op witness missing: {evidence}")
    for evidence in ("#[destructor(close_guard)]", "#[opaque]", "#[private]"):
        require(evidence in module_fixture,
                f"Patch 20.6 module attribute missing: {evidence}")

    opening = registry.get("opening_snapshots", {}).get("phase20", {})
    require(opening.get("status") == "ready_for_patch20_10" and
            opening.get("next_patch") == "20.10",
            "Phase 20 opening successor did not advance")
    require("- [x] Patch 20.6 — Inert Resource Declaration and Visibility Surface — DONE" in
            TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 20.6 DONE")
    workflow = PR_FAST.read_text(encoding="utf-8")
    require("Phase 20 inert resource declaration surface" in workflow and
            "just guard-cranelift-phase20-inert-resource-surface-contract" in
            workflow,
            "PR Fast does not own the Patch 20.6 Level 1 contract")
    require("guard-cranelift-phase20-inert-resource-surface-contract:" in
            JUSTFILE.read_text(encoding="utf-8"),
            "Patch 20.6 just guard is missing")
    return authority


def render(authority: dict) -> str:
    lines = [
        "# Cranelift Phase 20 Inert Resource Declaration Surface",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_inert_resource_surface.py project`. Do not edit by hand.",
        "",
        f"- Authority version: `{authority['authority_version']}`",
        f"- Status: `{authority['status']}`",
        f"- Next patch: `{authority['next_patch']}`",
        f"- Issue: `{authority['issue']}`",
        "- Enforcement enabled: `false`",
        "",
        "## Additive surface",
        "",
        "The parser and AST preserve `#[destructor(name)]`, `#[opaque]`, and",
        "`#[private]`. Separate type metadata records the declarations without",
        "registering a live linear destructor or applying access restrictions.",
        "Malformed, duplicate, and conflicting spellings have stable parser",
        "diagnostics.",
        "",
        "## No-op boundary and enforcement transition",
        "",
        "At Patch 20.6, a two-module witness directly constructed and accessed",
        "the declared opaque representation and called the declared private",
        "function, returning 42 exactly as the same unannotated program would.",
        "Patch 20.7 completed migration under that no-op. The current Patch 20.8",
        "guard reuses the witness as a transition negative and requires exactly",
        "one OpaqueConstruction, OpaqueRepresentationAccess, and",
        "PrivateDeclarationAccess diagnostic before backend selection.",
        "",
        "The checked-in bootstrap seed compiles the extended self-hosted compiler",
        "and remains unpublished until the isolated Patch 20.11 seed update.",
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
                    "generated Patch 20.6 review is stale; run project")
    except (Error, KeyError) as error:
        print(f"{GUARD}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
