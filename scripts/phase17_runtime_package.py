#!/usr/bin/env python3
"""Level 1 contract and reduced reviews for Phase 17.4 runtime packages.

Emits two generated views: a package view over the frozen manifest schema, and a
target view over the per-target package selection.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter
from pathlib import Path

GUARD = "guard-cranelift-phase17-runtime-package-contract"
LEVEL = "level1"
CONTRACT = Path("tests/cranelift/phase17_runtime_package_contract.tsv")
PACKAGE_REVIEW = Path("tests/cranelift/phase17_runtime_package_review.txt")
TARGET_REVIEW = Path("tests/cranelift/phase17_runtime_package_target_review.txt")
REGISTRY = Path("scripts/cranelift_feature_registry.json")
SOURCE = Path("compiler/mir_runtime_boundary_authority.gst")
REQUEST = Path("compiler/mir_native_backend_runtime_request.gst")
SMOKE = Path("compiler/mir_runtime_package_smoke_test_entry.gst")
WORKFLOW = Path(".github/workflows/phase17-runtime-package.yml")
TASK = Path("TASK.md")

PACKAGE_FORMS = (
    "static_archive", "deterministic_object_set", "explicit_native_library",
)
MANIFEST_FIELDS = (
    "components", "provided_symbols", "permitted_system_imports",
    "target_identity", "runtime_abi_identity", "deterministic_link_order",
    "compatibility_constraints",
)
EXPECTED = {
    "semantic_type": {
        "runtime_package_identity", "runtime_package_member",
        "runtime_package_provided_symbol", "runtime_package_system_import",
    },
    "query": {"runtime_package_manifest", "select_runtime_package_for_target"},
    "package_form": set(PACKAGE_FORMS),
    "manifest_field": set(MANIFEST_FIELDS),
    "rejection": {
        "ambiguous_package_selection", "package_for_wrong_target",
        "duplicate_conflicting_component", "missing_mandatory_symbol",
        "incompatible_runtime_abi_version",
        "undeclared_member_or_system_import",
        "nondeterministic_component_order",
    },
    "policy": {
        "declared_build_authority", "compiler_owned_package_selection",
        "phase9g_executes_declared_link_order", "stable_witness",
    },
    "boundary": {"three_approved_scalar_imports"},
}
REASONS = (
    "runtime_package_ambiguous_selection",
    "runtime_package_target_mismatch",
    "runtime_package_duplicate_conflicting_component",
    "runtime_package_missing_mandatory_symbol",
    "runtime_package_abi_version_incompatible",
    "runtime_package_undeclared_member_or_system_import",
    "runtime_package_nondeterministic_component_order",
)
SOURCE_TOKENS = (
    "type MirRuntimePackageIdentity", "type MirRuntimePackageMember",
    "type MirRuntimePackageProvidedSymbol",
    "type MirRuntimePackageSystemImport",
    "manifest_format:", "package_form:", "build_authority_id:",
    "link_order:", "object_identity:", "external_spelling:", "origin:",
    "func mir_runtime_package_form_is_valid(",
    "func mir_runtime_package_member_id(",
    "func mir_runtime_package_provided_symbol_id(",
    "func mir_runtime_package_system_import_id(",
    "func mir_runtime_package_by_id(",
    "func mir_runtime_package_provides_symbol(",
    "func mir_runtime_package_manifest(",
    "func mir_runtime_select_package_for_target(",
    "mir_runtime_table_with_package_member(",
    "mir_runtime_table_with_package_provided_symbol(",
    "mir_runtime_table_with_package_system_import(",
    "runtime_package_manifest_format", "runtime_package_form",
    "runtime_package_build_authority", "runtime_package_member_link_order",
    "runtime_package_provided_spelling", "runtime_package_provided_version",
    "runtime_package_system_import_spelling",
)
REQUEST_TOKENS = (
    "func mir_native_backend_runtime_package_manifest(",
    "func mir_native_backend_select_runtime_package_for_target(",
)
# Package choice and link order are compiler decisions. A backend that can pick
# either one has taken ownership Phase 9G is only supposed to execute.
BAN_TOKENS = (
    "WorkerRuntimePackageDiscovery",
    "worker_select_runtime_package",
    "linker_scan_runtime_directory",
    "infer_link_order_from_archive_members",
)


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD}: {message}")


def text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        fail(f"missing required file: {path}")


def rows(root: Path) -> list[dict[str, str]]:
    try:
        with (root / CONTRACT).open(encoding="utf-8", newline="") as handle:
            result = list(csv.DictReader(handle, delimiter="\t"))
    except FileNotFoundError:
        fail(f"missing required file: {CONTRACT}")
    required = {"kind", "id", "owner", "test_level", "disposition"}
    if not result or set(result[0]) != required:
        fail("contract schema drifted")
    actual: dict[str, set[str]] = {}
    seen: set[tuple[str, str]] = set()
    for row in result:
        key = (row["kind"], row["id"])
        if key in seen or row["test_level"] != LEVEL:
            fail(f"duplicate or non-Level-1 row: {key}")
        seen.add(key)
        actual.setdefault(row["kind"], set()).add(row["id"])
    if actual != EXPECTED:
        fail("contract inventory drifted")
    return result


def check_registry(root: Path) -> tuple[dict, list[str]]:
    registry = json.loads(text(root / REGISTRY))
    authority = registry.get("phase17_runtime_package_authority")
    if not isinstance(authority, dict):
        fail("canonical registry lacks runtime package authority")
    expected_metadata = {
        "version": "phase17_runtime_package_authority_v1",
        "status": "ready_for_patch17_5",
        "authority_owner": "compiler/mir_runtime_boundary_authority.gst",
        "request_owner": "compiler/mir_native_backend_runtime_request.gst",
        "manifest_format": "gust.runtime_package_manifest.v1",
        "build_authority_id": "runtime_build_authority:gust_runtime_package",
        "selection_policy":
            "compiler_owned_compatibility_decision_exactly_one_available_"
            "package_per_target",
        "link_execution_policy":
            "phase9g_executes_declared_link_order_without_choosing_package_"
            "or_order",
        "link_order_policy":
            "dense_ascending_component_order_declared_per_package",
        "system_import_policy":
            "only_enumerated_permitted_system_imports_may_be_referenced",
        "witness_policy":
            "stable_package_manifest_and_target_selection_witnesses",
        "scope_policy":
            "packages_for_three_approved_scalar_imports_cranelift_import_"
            "emission_remains_in_patch17_5",
        "next_patch": "17.5",
    }
    for key, value in expected_metadata.items():
        if authority.get(key) != value:
            fail(f"runtime package metadata drifted: {key}")
    if tuple(authority.get("supported_package_forms", ())) != PACKAGE_FORMS:
        fail("runtime package form inventory drifted")
    if tuple(authority.get("manifest_fields", ())) != MANIFEST_FIELDS:
        fail("runtime package manifest schema drifted")
    if tuple(authority.get("rejection_classes", ())) != REASONS:
        fail("runtime package rejection inventory drifted")

    # One package per Phase 14 declared target, providing exactly the Phase 17.2
    # selected symbols, so packaging cannot widen the migrated runtime surface.
    targets = registry["phase14_primitive_layout"]["declared_targets"]
    spellings = [
        row["external_spelling"]
        for row in registry["phase17_runtime_symbol_authority"]
        ["selected_symbols"]
    ]
    packages = authority.get("target_packages", [])
    if len(packages) != len(targets):
        fail("runtime package target coverage drifted")
    for row, target in zip(packages, targets):
        if (row.get("target_id") != target.get("target_id")
                or row.get("target_triple") != target.get("target_triple")
                or row.get("object_format") != target.get("object_format")):
            fail(f"package does not derive Phase 14 target: "
                 f"{row.get('target_triple')}")
        if (row.get("package_version") != "gust-runtime-package-v1"
                or row.get("package_form") not in PACKAGE_FORMS
                or row.get("compatible_version_min") != 1
                or row.get("compatible_version_max") != 1):
            fail(f"package identity drifted: {row.get('target_triple')}")
        if list(row.get("provided_symbols", [])) != spellings:
            fail(f"package symbols are not the selected inventory: "
                 f"{row.get('target_triple')}")
        components = list(row.get("components", []))
        if not components or len(components) != len(set(components)):
            fail(f"package link order repeats or omits components: "
                 f"{row.get('target_triple')}")
    return authority, spellings


def function_body(source: str, name: str) -> str:
    match = re.search(rf"func\s+{re.escape(name)}\s*\([^{{]+\)\s+[^{{]+\{{", source)
    if not match:
        fail(f"missing identity function: {name}")
    start, depth, index = match.end(), 1, match.end()
    while index < len(source) and depth:
        depth += (source[index] == "{") - (source[index] == "}")
        index += 1
    return source[start:index - 1]


def check_source(root: Path) -> None:
    source = text(root / SOURCE)
    for token in (*SOURCE_TOKENS, *REASONS, *PACKAGE_FORMS):
        if token not in source:
            fail(f"runtime package source is missing: {token}")
    body = function_body(source, "mir_runtime_package_member_id").lower()
    for banned in ("hash", "sha", "digest", "fingerprint", "file_bytes"):
        if banned in body:
            fail(f"runtime package identity uses raw input: {banned}")
    request = text(root / REQUEST)
    for token in REQUEST_TOKENS:
        if token not in request:
            fail(f"runtime request is missing package adapter: {token}")
    for path in (
        root / "compiler/mir_to_c.gst",
        root / "compiler/experiments/cranelift/src/main.rs",
        root / "compiler/driver.gst",
    ):
        if path.is_file():
            content = text(path)
            for token in BAN_TOKENS:
                if token in content:
                    fail(f"backend-local runtime package authority: "
                         f"{path}:{token}")


def check_wiring(root: Path) -> None:
    for path in (SMOKE, WORKFLOW):
        if not (root / path).is_file():
            fail(f"missing required file: {path}")
    workflow = text(root / WORKFLOW)
    for token in (GUARD, "python3 scripts/phase17_runtime_package.py --check",
                  "Phase 17.4 runtime package contract"):
        if token not in workflow:
            fail(f"workflow is missing: {token}")
    marker = ("- [x] Patch 17.4 — Explicit Runtime Packages and "
              "Target-Specific Selection — DONE")
    if marker not in text(root / TASK):
        fail("TASK.md does not mark Patch 17.4 DONE")


def render_package_view(contract_rows: list[dict[str, str]],
                        authority: dict) -> str:
    counts = Counter(row["kind"] for row in contract_rows)
    lines = [
        "Phase 17.4 — Explicit Runtime Packages (package view)",
        f"guard: {GUARD}", f"test_level: {LEVEL}",
        f"manifest_format: {authority['manifest_format']}",
        f"build_authority: {authority['build_authority_id']}",
        f"selection_policy: {authority['selection_policy']}",
        f"link_execution_policy: {authority['link_execution_policy']}",
        "", "contract counts:",
    ]
    lines += [f"  {kind}: {counts[kind]}" for kind in sorted(counts)]
    lines += ["", "supported package forms:"]
    lines += [f"  {value}" for value in authority["supported_package_forms"]]
    lines += ["", "frozen manifest fields:"]
    lines += [f"  {value}" for value in authority["manifest_fields"]]
    lines += ["", "rejection classes:"]
    lines += [f"  {value}" for value in authority["rejection_classes"]]
    lines += [
        "", "exit gate:",
        "  every migrated native target has an explicit deterministic runtime "
        "package selection",
        "  the manifest satisfies the compiler-produced runtime requirements "
        "before the link plan is executed",
        "",
    ]
    return "\n".join(lines)


def render_target_view(authority: dict, spellings: list[str]) -> str:
    lines = [
        "Phase 17.4 — Target-Specific Runtime Package Selection (target view)",
        f"guard: {GUARD}", f"test_level: {LEVEL}",
        f"link_order_policy: {authority['link_order_policy']}",
        f"system_import_policy: {authority['system_import_policy']}",
        f"selected_symbols_per_package: {len(spellings)}",
        "", "target packages:",
    ]
    for row in authority["target_packages"]:
        lines.append(
            f"  {row['target_triple']}\t{row['object_format']}\t"
            f"{row['package_form']}\t{row['package_version']}\t"
            f"{row['compatible_version_min']}-{row['compatible_version_max']}"
        )
        lines.append("    link order:")
        lines += [
            f"      {index}\t{component}"
            for index, component in enumerate(row["components"])
        ]
        lines.append("    provided symbols:")
        lines += [f"      {value}" for value in row["provided_symbols"]]
        lines.append("    permitted system imports:")
        lines += [
            f"      {value}" for value in row["permitted_system_imports"]
        ] or ["      (none)"]
    lines += [
        "", "exit gate:",
        "  package selection is a compiler-owned compatibility decision",
        "  Phase 9G executes the declared link order and does not choose it",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--write", action="store_true")
    modes.add_argument("--check", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    contract_rows = rows(root)
    authority, spellings = check_registry(root)
    check_source(root)
    package_view = render_package_view(contract_rows, authority)
    target_view = render_target_view(authority, spellings)
    if args.write:
        (root / PACKAGE_REVIEW).write_text(package_view, encoding="utf-8")
        (root / TARGET_REVIEW).write_text(target_view, encoding="utf-8")
    else:
        if text(root / PACKAGE_REVIEW) != package_view:
            fail("generated package review is stale; run with --write")
        if text(root / TARGET_REVIEW) != target_view:
            fail("generated target review is stale; run with --write")
        check_wiring(root)
    print(f"{GUARD}: ok ({len(authority['target_packages'])} target packages, "
          f"{len(spellings)} provided symbols, {LEVEL})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
