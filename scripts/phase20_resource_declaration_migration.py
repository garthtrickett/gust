#!/usr/bin/env python3
"""Validate and project Patch 20.7 resource declaration migration."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
METADATA_ROUTE = ROOT / "compiler/mir_native_backend_metadata_source.gst"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_RESOURCE_DECLARATION_MIGRATION.md"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
JUSTFILE = ROOT / "justfile"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
GUARD = "guard-cranelift-phase20-resource-declaration-migration-contract"

SOURCE_DECLARATIONS = [
    "compiler/phase13_composition_resource_metadata_source.gst",
    "compiler/phase13_source_resource_metadata_source.gst",
    "compiler/phase13_resource_cleanup_deferred_source.gst",
    "compiler/future/phase14_resource_cleanup_source.gst",
]

ENFORCEMENT_LINEAR_FIXTURES = [
    "compiler/phase20_resource_enforcement_module.gst",
    "compiler/phase20_resource_scope_cleanup_module.gst",
    "compiler/phase20_resource_destructor_missing_invalid.gst",
    "compiler/phase20_resource_destructor_borrowed_invalid.gst",
    "compiler/phase20_resource_destructor_wrong_type_invalid.gst",
    "compiler/phase20_resource_destructor_arity_invalid.gst",
    "compiler/phase20_resource_destructor_result_invalid.gst",
    "compiler/phase20_resource_destructor_unsafe_invalid.gst",
    "compiler/phase20_resource_destructor_extern_invalid.gst",
    "compiler/phase20_resource_destructor_owner_invalid.gst",
]

GENERIC_GUARD_LINEAR_FIXTURES = [
    "compiler/phase20_generic_guard_prerequisites_source.gst",
    "compiler/phase20_generic_resource_destructor_wrong_type_invalid.gst",
    "compiler/phase20_generic_resource_destructor_wrong_brand_invalid.gst",
]

CROSS_FEATURE_LINEAR_FIXTURES = [
    "compiler/phase20_cross_feature_resource_module.gst",
]

SOURCE_DESTRUCTORS = {
    SOURCE_DECLARATIONS[0]: (
        "Phase13CompositionResourceMetadata",
        "phase13_destroy_composition_resource",
    ),
    SOURCE_DECLARATIONS[1]: (
        "Phase13SourceResourceMetadata",
        "phase13_destroy_source_resource",
    ),
    SOURCE_DECLARATIONS[2]: (
        "Phase13DeferredResource",
        "phase13_destroy_deferred_resource",
    ),
    SOURCE_DECLARATIONS[3]: (
        "Phase14Resource",
        "destroy_phase14_resource",
    ),
}

DIRECTORY_VOCABULARY_FILES = [
    "compiler/codegen.gst",
    "compiler/e2e_complex_bootstrap_target.gst",
    "compiler/future/p15_complete_resource_differential_source.gst",
    "compiler/future/p15_directory_resources_source.gst",
    "compiler/future/p15_selected_failure_cleanup_source.gst",
    "compiler/future/p20_issue106_bound_directory_current.gst",
    "compiler/future/p20_issue106_unbound_directory_current.gst",
    "compiler/mir_specialized_resource.gst",
    "compiler/mir_specialized_resource_parity_smoke_test_entry.gst",
    "compiler/phase19_cross_feature_composition_source.gst",
    "compiler/phase20_directory_external_construction_invalid.gst",
    "compiler/phase20_directory_external_field_invalid.gst",
    "compiler/phase20_resource_acquisition_directory_discarded_invalid.gst",
    "compiler/phase20_resource_acquisition_directory_source.gst",
    "compiler/resolver.gst",
    "compiler/test_directory_leak_violation.gst",
    "compiler/typechecker.gst",
    "compiler/typechecker_directory_resource_cleanup_boundary_routing_test_entry.gst",
    "compiler/typechecker_directory_resource_parity_metadata_test_entry.gst",
    "compiler/typechecker_directory_resource_shadow_tracking_test_entry.gst",
    "compiler/typechecker_directory_resource_source_of_truth_flip_test_entry.gst",
    "compiler/typechecker_open_directories_legacy_freeze_test_entry.gst",
]


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def compiler_gst_files() -> list[Path]:
    return sorted((ROOT / "compiler").rglob("*.gst"))


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def gust_code_without_comments_or_literals(source: str) -> str:
    """Preserve Gust tokens while masking comments and quoted literals."""
    result = list(source)
    index = 0
    while index < len(source):
        if source.startswith("//", index):
            result[index] = " "
            result[index + 1] = " "
            index += 2
            while index < len(source) and source[index] != "\n":
                result[index] = " "
                index += 1
            continue
        if source.startswith("/*", index):
            result[index] = " "
            result[index + 1] = " "
            index += 2
            while index < len(source) and not source.startswith("*/", index):
                if source[index] != "\n":
                    result[index] = " "
                index += 1
            if index < len(source):
                result[index] = " "
                result[index + 1] = " "
                index += 2
            continue
        if source[index] in ('"', "'"):
            quote = source[index]
            result[index] = " "
            index += 1
            while index < len(source):
                if source[index] == "\\" and index + 1 < len(source):
                    result[index] = " "
                    result[index + 1] = " "
                    index += 2
                    continue
                if source[index] == quote:
                    result[index] = " "
                    index += 1
                    break
                if source[index] != "\n":
                    result[index] = " "
                index += 1
            continue
        index += 1
    return "".join(result)


def has_linear_attribute(source: str) -> bool:
    code = gust_code_without_comments_or_literals(source)
    return re.search(r"#\s*\[\s*linear\s*\]", code) is not None


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    authority = registry.get("phase20_resource_declaration_migration")
    require(isinstance(authority, dict), "Patch 20.7 authority is missing")
    require(authority.get("authority_version") ==
            "phase20_resource_declaration_migration_v1",
            "Patch 20.7 authority version drifted")
    require(authority.get("status") == "patch20_7_complete",
            "Patch 20.7 status drifted")
    require(authority.get("next_patch") == "20.8",
            "Patch 20.7 successor drifted")
    require(authority.get("issue") == "CR-5/#106",
            "Patch 20.7 issue ownership drifted")
    require(authority.get("source_declarations") == SOURCE_DECLARATIONS,
            "Patch 20.7 source declaration cohort drifted")
    require(authority.get("directory_vocabulary_files") ==
            DIRECTORY_VOCABULARY_FILES,
            "Patch 20.7 directory vocabulary cohort drifted")
    require(authority.get("directory_bridge_owner") ==
            "compiler/typechecker.gst",
            "Patch 20.7 directory bridge owner drifted")
    require(authority.get("directory_resource_type") == "os_Dir_ctx" and
            authority.get("directory_destructor") == "os.CloseDir",
            "Patch 20.7 directory authority drifted")
    require(authority.get("enforcement_enabled") is False,
            "Patch 20.7 must leave enforcement disabled")

    parser_valid_linear_spellings = (
        "#[linear] #[destructor(close)] type Guard struct { token: int }",
        "    #[linear]\ntype Guard struct { token: int }",
        "#[opaque] #[linear] type Guard struct { token: int }",
    )
    require(all(has_linear_attribute(source)
                for source in parser_valid_linear_spellings),
            "linear inventory does not cover parser-valid attribute placement")
    require(not has_linear_attribute(
                '// #[linear]\nmut text := "#[linear]";'),
            "linear inventory counts comments or string literals")

    actual_linear = []
    for path in compiler_gst_files():
        source = path.read_text(encoding="utf-8")
        if has_linear_attribute(source):
            actual_linear.append(relative(path))
    expected_linear = sorted(SOURCE_DECLARATIONS + ENFORCEMENT_LINEAR_FIXTURES +
                             GENERIC_GUARD_LINEAR_FIXTURES +
                             CROSS_FEATURE_LINEAR_FIXTURES)
    require(actual_linear == expected_linear,
            "compiler-owned #[linear] declaration inventory drifted: " +
            repr(actual_linear))

    enforcement = registry.get("phase20_resource_declaration_enforcement", {})
    enforcement_files = [enforcement.get("module_fixture", "")]
    enforcement_files += enforcement.get("negative_fixtures", [])
    cleanup = registry.get("phase20_resource_scope_cleanup", {})
    enforcement_files.append(cleanup.get("module_fixture", ""))
    require(all(path in enforcement_files
                for path in ENFORCEMENT_LINEAR_FIXTURES),
            "Phase 20 linear fixtures are not classified by their authority")

    generic_guard = registry.get("phase20_generic_guard_prerequisites", {})
    generic_guard_files = [generic_guard.get("positive_fixture", "")]
    generic_guard_files += generic_guard.get("negative_fixtures", [])
    require(all(path in generic_guard_files
                for path in GENERIC_GUARD_LINEAR_FIXTURES),
            "Patch 20.14a linear fixtures are not classified by their authority")

    cross_feature = registry.get("phase20_cross_feature_qualification", {})
    require(cross_feature.get("resource_module_fixture") in
            CROSS_FEATURE_LINEAR_FIXTURES,
            "Patch 20.16 linear fixture is not classified by its authority")

    for source_path, (type_name, destructor_name) in SOURCE_DESTRUCTORS.items():
        source = (ROOT / source_path).read_text(encoding="utf-8")
        for evidence in (
            "#[linear]",
            f"#[destructor({destructor_name})]",
            "#[opaque]",
            "#[private]",
            f"func {destructor_name}(resource: {type_name})",
        ):
            require(evidence in source,
                    f"{source_path} lacks migrated evidence: {evidence}")
        require(source.index("#[linear]") < source.index("#[destructor(") <
                source.index("#[opaque]") < source.index(f"type {type_name}"),
                f"{source_path} declaration attributes are not stacked")
        require(source.index("#[private]") <
                source.index(f"func {destructor_name}"),
                f"{source_path} cleanup is not declared private")

    directory_tokens = ("os.OpenDir", "os.ReadDir", "os.CloseDir")
    actual_directory_files = []
    for path in compiler_gst_files():
        source = path.read_text(encoding="utf-8")
        if any(token in source for token in directory_tokens):
            actual_directory_files.append(relative(path))
    require(actual_directory_files == DIRECTORY_VOCABULARY_FILES,
            "compiler-owned directory vocabulary inventory drifted: " +
            repr(actual_directory_files))

    typechecker = TYPECHECKER.read_text(encoding="utf-8")
    inert_call = ('env_register_inert_resource_declaration_metadata(env, '
                  '"os_Dir_ctx", "os.CloseDir", 1, ctx);')
    generic_inert_call = ('env_register_inert_resource_declaration_metadata(env, '
                          'type_name, "os.CloseDir", 1, ctx);')
    require(inert_call in typechecker and generic_inert_call in typechecker,
            "directory bridge lacks inert destructor/opacity metadata")
    require(typechecker.count(
        'env_register_struct_linear_destructor(env, "os_Dir_ctx", '
        '"os.CloseDir", ctx);') == 1,
        "directory bridge live Phase 15 destructor authority drifted")
    require(typechecker.count(
        'env_register_struct_linear_destructor(env, type_name, '
        '"os.CloseDir", ctx);') == 1,
        "directory parity live Phase 15 destructor authority drifted")

    metadata_route = METADATA_ROUTE.read_text(encoding="utf-8")
    for evidence in (
        "linear_struct_destructor_name",
        "inert_cleanup_declaration_count",
        "statement.FunctionDecl.is_private == 1",
        "statement.StructDecl.declared_destructor_name",
        "len(statements) != 2 + inert_cleanup_declaration_count",
    ):
        require(evidence in metadata_route,
                f"Phase 13 declaration-only route evidence missing: {evidence}")

    opening = registry.get("opening_snapshots", {}).get("phase20", {})
    require(opening.get("status") == "ready_for_patch20_11" and
            opening.get("next_patch") == "20.11",
            "Phase 20 opening successor did not advance")
    require("- [x] Patch 20.7 — Resource Declaration Migration Under the No-op — DONE" in
            TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 20.7 DONE")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))
    require(levels.get("guards", {}).get(GUARD) == 1,
            "Patch 20.7 guard is not classified Level 1")
    workflow = PR_FAST.read_text(encoding="utf-8")
    require("Phase 20 resource declaration migration" in workflow and
            f"just {GUARD}" in workflow,
            "PR Fast does not own the Patch 20.7 Level 1 contract")
    require(f"{GUARD}:" in JUSTFILE.read_text(encoding="utf-8"),
            "Patch 20.7 just guard is missing")
    return authority


def render(authority: dict) -> str:
    lines = [
        "# Cranelift Phase 20 Resource Declaration Migration",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_resource_declaration_migration.py project`. Do not edit by hand.",
        "",
        f"- Authority version: `{authority['authority_version']}`",
        f"- Status: `{authority['status']}`",
        f"- Next patch: `{authority['next_patch']}`",
        f"- Issue: `{authority['issue']}`",
        "- Enforcement enabled: `false`",
        "",
        "## Migrated source declarations",
        "",
    ]
    lines.extend(f"- `{path}`" for path in authority["source_declarations"])
    lines += [
        "",
        "Every compiler-owned `#[linear]` structure now declares an opaque",
        "representation, a destructor name, and a same-module private cleanup",
        "function with an owned resource parameter. The attributes remain inert",
        "under Patch 20.6, so the existing programs retain their behavior.",
        "The Phase 13 metadata route counts that matching private cleanup as a",
        "declaration-only companion, preserving its established native parity.",
        "",
        "## Directory metadata bridge",
        "",
        "The synthesized `os_Dir_ctx` resource records inert destructor",
        "`os.CloseDir` and opacity metadata alongside the existing live Phase 15",
        "linear/destructor metadata. Its source compatibility, explicit close",
        "behavior, cleanup scheduling, and diagnostics are unchanged.",
        "",
        f"The exact directory vocabulary cohort contains "
        f"{len(authority['directory_vocabulary_files'])} compiler files. The",
        "inventory guard derives both cohorts from live compiler sources and",
        "rejects any unclassified declaration or directory use site.",
        "",
        "Patch 20.8 alone owns enforcement of declaration, construction,",
        "representation-access, and private-call rules.",
        "Its positive module and intentional invalid declaration fixtures are",
        "classified separately by the Patch 20.8 authority while remaining in",
        "this exact compiler-owned `#[linear]` inventory.",
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
                    "generated Patch 20.7 review is stale; run project")
    except (Error, KeyError) as error:
        print(f"{GUARD}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
