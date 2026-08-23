#!/usr/bin/env python3
"""Validate and project Patch 20.8 resource declaration enforcement."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_RESOURCE_DECLARATION_ENFORCEMENT.md"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
JUSTFILE = ROOT / "justfile"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
GUARD_L1 = "guard-cranelift-phase20-resource-enforcement-contract"
GUARD_L2 = "guard-cranelift-phase20-resource-enforcement-parity"

NEGATIVES = [
    "compiler/phase20_resource_external_construction_invalid.gst",
    "compiler/phase20_resource_empty_forge_invalid.gst",
    "compiler/phase20_resource_external_field_invalid.gst",
    "compiler/phase20_directory_external_construction_invalid.gst",
    "compiler/phase20_directory_external_field_invalid.gst",
    "compiler/phase20_resource_private_call_invalid.gst",
    "compiler/phase20_resource_private_reference_invalid.gst",
    "compiler/phase20_resource_destructor_missing_invalid.gst",
    "compiler/phase20_resource_destructor_borrowed_invalid.gst",
    "compiler/phase20_resource_destructor_wrong_type_invalid.gst",
    "compiler/phase20_resource_destructor_arity_invalid.gst",
    "compiler/phase20_resource_destructor_result_invalid.gst",
    "compiler/phase20_resource_destructor_unsafe_invalid.gst",
    "compiler/phase20_resource_destructor_extern_invalid.gst",
    "compiler/phase20_resource_destructor_owner_invalid.gst",
]

DIAGNOSTICS = [
    "OpaqueConstruction",
    "OpaqueRepresentationAccess",
    "PrivateDeclarationAccess",
    "ResourceDestructorMissing",
    "ResourceDestructorModuleMismatch",
    "ResourceDestructorSignature",
    "ResourceDestructorStatus",
]


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    authority = registry.get("phase20_resource_declaration_enforcement")
    require(isinstance(authority, dict), "Patch 20.8 authority is missing")
    require(authority.get("authority_version") ==
            "phase20_resource_declaration_enforcement_v1",
            "Patch 20.8 authority version drifted")
    require(authority.get("status") == "patch20_8_complete" and
            authority.get("next_patch") == "20.9",
            "Patch 20.8 status or successor drifted")
    require(authority.get("issue") == "CR-5/#106",
            "Patch 20.8 issue ownership drifted")
    require(authority.get("negative_fixtures") == NEGATIVES,
            "Patch 20.8 negative matrix drifted")
    require(authority.get("diagnostics") == DIAGNOSTICS,
            "Patch 20.8 diagnostic matrix drifted")
    require(authority.get("enforcement_enabled") is True,
            "Patch 20.8 enforcement is not enabled")

    for key in ("positive_fixture", "module_fixture", "transition_fixture"):
        require((ROOT / authority[key]).is_file(),
                f"Patch 20.8 fixture is missing: {authority[key]}")
    for path in NEGATIVES:
        require((ROOT / path).is_file(),
                f"Patch 20.8 negative fixture is missing: {path}")

    source = TYPECHECKER.read_text(encoding="utf-8")
    for evidence in (
        "struct_declaration_module: std.HashMap[str, str, ctx]",
        "function_declaration_module: std.HashMap[str, str, ctx]",
        "struct_validated_destructor: std.HashMap[str, str, ctx]",
        "func env_validate_resource_declaration(",
        "func env_struct_representation_access_allowed(",
        "func env_private_function_access_allowed(",
        "compiler_cleanup_invocation == 1",
        "env_function_is_validated_resource_destructor",
        "env_report_opaque_construction(",
        "env_report_opaque_representation_access(",
        "env_report_private_function_access(",
        *[f"[{diagnostic}]" for diagnostic in DIAGNOSTICS],
    ):
        require(evidence in source,
                f"Patch 20.8 compiler evidence missing: {evidence}")
    require(source.count("env_report_opaque_construction(") == 3,
            "opaque construction must have one helper and two construction sites")
    require(source.count("env_report_opaque_representation_access(") == 2,
            "opaque field access must have one helper and one selector site")
    require(source.count("env_report_private_function_access(") == 5,
            "private visibility must cover helper, identifier, selector, call, and Spawn reference")

    module_source = (ROOT / authority["module_fixture"]).read_text(
        encoding="utf-8")
    for evidence in (
        "#[destructor(destroy_handle)]", "#[opaque]", "#[private]",
        "mut resource: Handle;", "resource.token = 42;",
        "destroy_handle(move resource);", "return resource.token;",
    ):
        require(evidence in module_source,
                f"same-module/resource API evidence missing: {evidence}")

    positive = (ROOT / authority["positive_fixture"]).read_text(
        encoding="utf-8")
    for evidence in (
        "resource.same_module_success()", "resource.acquire()",
        "resource.read(&handle)", "return observed + local_result;",
    ):
        require(evidence in positive,
                f"external safe API evidence missing: {evidence}")

    transition = (ROOT / authority["transition_fixture"]).read_text(
        encoding="utf-8")
    for evidence in (
        "mut handle: resource.Guard;", "handle.token = 42;",
        "resource.close_guard(handle);",
    ):
        require(evidence in transition,
                f"Patch 20.6 transition evidence missing: {evidence}")

    opening = registry.get("opening_snapshots", {}).get("phase20", {})
    require(opening.get("status") == "ready_for_patch20_9" and
            opening.get("next_patch") == "20.9",
            "Phase 20 opening successor did not advance to Patch 20.9")
    require("- [x] Patch 20.8 — Resource Declaration and Construction Enforcement — DONE" in
            TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 20.8 DONE")

    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 20.8 guard levels drifted")
    workflow = PR_FAST.read_text(encoding="utf-8")
    require("Phase 20 resource declaration enforcement" in workflow and
            f"just {GUARD_L1}" in workflow,
            "PR Fast does not own the Patch 20.8 Level 1 guard")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in justfile and f"{GUARD_L2}:" in justfile,
            "Patch 20.8 just guards are missing")
    return authority


def render(authority: dict) -> str:
    lines = [
        "# Cranelift Phase 20 Resource Declaration Enforcement",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_resource_enforcement.py project`. Do not edit by hand.",
        "",
        f"- Authority version: `{authority['authority_version']}`",
        f"- Status: `{authority['status']}`",
        f"- Next patch: `{authority['next_patch']}`",
        f"- Issue: `{authority['issue']}`",
        "- Enforcement enabled: `true`",
        "",
        "## Declaration and module authority",
        "",
        "A declared destructor must exist in the resource type's module, take",
        "exactly one owned value of that resource type, return `Void`, and be a",
        "safe non-extern cleanup function. Only identities passing that validation",
        "enter the compiler-cleanup allowlist; ordinary callers receive no bypass.",
        "",
        "Opaque types can be constructed and their fields accessed only inside",
        "their defining module. Private functions can be called or referenced only",
        "there. A module may therefore expose an acquirer and safe read API without",
        "exposing a forgeable representation or callable cleanup primitive.",
        "",
        "## Backend-neutral evidence",
        "",
        "The positive two-module program returns 47 through default and explicit",
        "MIR-to-C. Every negative produces one identical shared-frontend diagnostic",
        "for default MIR-to-C, explicit MIR-to-C, and explicit Cranelift before",
        "backend selection. The Patch 20.6 no-op witness is reclassified and now",
        "produces exactly the three construction, field, and private-call errors.",
        "",
        "Patch 20.9 still owns acquisition-site obligations; Patch 20.10 still",
        "owns generic scope-exit cleanup and destructor invocation.",
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
                    "generated Patch 20.8 review is stale; run project")
    except (Error, KeyError) as error:
        print(f"{GUARD_L1}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
