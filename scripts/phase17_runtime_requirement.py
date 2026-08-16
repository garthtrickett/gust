#!/usr/bin/env python3
"""Level 1 contract and reduced review for Phase 17.3 runtime requirements."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter
from pathlib import Path

GUARD = "guard-cranelift-phase17-runtime-requirement-contract"
LEVEL = "level1"
CONTRACT = Path("tests/cranelift/phase17_runtime_requirement_contract.tsv")
REVIEW = Path("tests/cranelift/phase17_runtime_requirement_review.txt")
REGISTRY = Path("scripts/cranelift_feature_registry.json")
SOURCE = Path("compiler/mir_runtime_boundary_authority.gst")
REQUEST = Path("compiler/mir_native_backend_runtime_request.gst")
SMOKE = Path("compiler/mir_runtime_requirement_smoke_test_entry.gst")
WORKFLOW = Path(".github/workflows/phase17-runtime-requirement.yml")
TASK = Path("TASK.md")

CALL_KINDS = (
    "direct_call", "selected_indirect_call", "cleanup_or_destructor",
    "cross_module_composition", "runtime_module_call",
)
EXPECTED = {
    "semantic_type": {"runtime_requirement", "runtime_mir_reference"},
    "query": {
        "runtime_requirement_for", "runtime_requirement_table",
        "runtime_mir_reference_for",
    },
    "linkage": {
        "helper_and_symbol_identity", "runtime_abi_version_range",
        "phase14_target_layout", "phase15_resource_operation",
        "phase16_function_abi", "target_applicability",
    },
    "call_kind": set(CALL_KINDS),
    "rejection": {
        "unknown_helper_or_symbol", "duplicate_conflicting_requirement",
        "mir_operation_missing_requirement",
        "unused_requirement_without_package_mandate",
        "incompatible_symbol_version",
        "target_layout_resource_or_abi_mismatch",
        "classification_inconsistent_with_symbol",
    },
    "policy": {
        "deterministic_requirement_identity", "request_table_deduplication",
        "worker_validates_but_cannot_invent", "stable_witness",
    },
    "boundary": {"three_approved_scalar_imports"},
}
REASONS = (
    "runtime_requirement_unknown_helper_or_symbol",
    "runtime_requirement_duplicate_conflict",
    "runtime_requirement_missing_for_mir_operation",
    "runtime_requirement_unused_without_package_mandate",
    "runtime_requirement_symbol_version_incompatible",
    "runtime_requirement_target_or_layout_mismatch",
    "runtime_requirement_classification_conflict",
)
SOURCE_TOKENS = (
    "type MirRuntimeRequirement", "type MirRuntimeMirReference",
    "symbol_id:", "required_version_min:", "required_version_max:",
    "call_kind:", "package_mandatory:", "target_applicability:",
    "layout_id:", "resource_operation_id:", "function_abi_id:",
    "func mir_runtime_mir_reference_id(",
    "func mir_runtime_call_kind_is_valid(",
    "func mir_runtime_requirement_by_id(",
    "func mir_runtime_requirement_for(",
    "func mir_runtime_requirement_table(",
    "func mir_runtime_mir_reference_for(",
    "func mir_runtime_symbol_by_id(", "func mir_runtime_abi_by_id(",
    "mir_runtime_table_with_requirement(",
    "mir_runtime_table_with_mir_reference(",
    "runtime_requirement_symbol_id", "runtime_requirement_version_min",
    "runtime_requirement_version_max", "runtime_requirement_call_kind",
    "runtime_requirement_package_mandatory",
    "runtime_mir_reference_requirement_id", "runtime_mir_reference_call_kind",
)
REQUEST_TOKENS = (
    "func mir_native_backend_runtime_requirement_table(",
    "func mir_native_backend_runtime_requirement_for(",
    "func mir_native_backend_runtime_mir_reference_for(",
)
# A backend that can synthesize ownership defeats the whole patch: the worker
# must validate compiler-produced requirements, never manufacture them.
BAN_TOKENS = (
    "WorkerRuntimeRequirementSynthesisTable",
    "worker_infer_runtime_requirement",
    "mir_to_c_synthesize_runtime_requirement",
    "derive_runtime_requirement_from_unresolved_symbol",
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


def check_registry(root: Path) -> tuple[dict, list[dict]]:
    registry = json.loads(text(root / REGISTRY))
    authority = registry.get("phase17_runtime_requirement_authority")
    if not isinstance(authority, dict):
        fail("canonical registry lacks runtime requirement authority")
    expected_metadata = {
        "version": "phase17_runtime_requirement_authority_v1",
        "status": "ready_for_patch17_4",
        "authority_owner": "compiler/mir_runtime_boundary_authority.gst",
        "request_owner": "compiler/mir_native_backend_runtime_request.gst",
        "requirement_policy":
            "compiler_produced_requirements_only_worker_must_not_invent",
        "deduplication_policy":
            "one_requirement_per_program_and_symbol_first_appearance_order",
        "version_range_policy":
            "required_range_must_lie_inside_frozen_runtime_abi_range",
        "unused_requirement_policy":
            "requirement_without_canonical_mir_reference_must_be_package_mandatory",
        "witness_policy":
            "stable_requirement_and_canonical_mir_reference_witnesses",
        "scope_policy":
            "requirements_for_three_approved_scalar_imports_packages_and_"
            "selection_remain_in_patch17_4",
        "next_patch": "17.4",
    }
    for key, value in expected_metadata.items():
        if authority.get(key) != value:
            fail(f"runtime requirement metadata drifted: {key}")
    if tuple(authority.get("preserved_call_kinds", ())) != CALL_KINDS:
        fail("runtime requirement call-kind coverage drifted")
    if tuple(authority.get("rejection_classes", ())) != REASONS:
        fail("runtime requirement rejection inventory drifted")

    # Coverage is derived from the Phase 17.2 selected symbols, so this patch
    # cannot widen the migrated runtime surface behind a requirement table.
    symbols = registry["phase17_runtime_symbol_authority"]
    selected = {row["helper_id"] for row in symbols["selected_symbols"]}
    abis = symbols["supported_abis"]
    requirements = authority.get("selected_requirements", [])
    if {row.get("helper_id") for row in requirements} != selected:
        fail("selected requirement coverage drifted")
    for row in requirements:
        helper = row["helper_id"]
        minimum, maximum = row["required_version_min"], row["required_version_max"]
        if (row.get("symbol_helper_id") != helper
                or row.get("call_kind") not in CALL_KINDS
                or row.get("package_mandatory") is not False
                or not isinstance(minimum, int) or isinstance(minimum, bool)
                or not isinstance(maximum, int) or isinstance(maximum, bool)
                or not 1 <= minimum <= maximum):
            fail(f"selected requirement record drifted: {helper}")
        for abi in abis:
            if (minimum < abi["compatible_version_min"]
                    or maximum > abi["compatible_version_max"]):
                fail(f"requirement version range escapes ABI range: {helper}")
    return authority, abis


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
    for token in (*SOURCE_TOKENS, *REASONS, *CALL_KINDS):
        if token not in source:
            fail(f"runtime requirement source is missing: {token}")
    body = function_body(source, "mir_runtime_mir_reference_id").lower()
    for banned in ("hash", "sha", "digest", "fingerprint", "file_bytes"):
        if banned in body:
            fail(f"runtime reference identity uses raw input: {banned}")
    request = text(root / REQUEST)
    for token in REQUEST_TOKENS:
        if token not in request:
            fail(f"runtime request is missing requirement adapter: {token}")
    for path in (
        root / "compiler/mir_to_c.gst",
        root / "compiler/experiments/cranelift/src/main.rs",
        root / "compiler/driver.gst",
    ):
        if path.is_file():
            content = text(path)
            for token in BAN_TOKENS:
                if token in content:
                    fail(f"backend-local runtime requirement authority: "
                         f"{path}:{token}")


def check_wiring(root: Path) -> None:
    for path in (SMOKE, WORKFLOW):
        if not (root / path).is_file():
            fail(f"missing required file: {path}")
    workflow = text(root / WORKFLOW)
    for token in (GUARD, "python3 scripts/phase17_runtime_requirement.py --check",
                  "Phase 17.3 runtime requirement contract"):
        if token not in workflow:
            fail(f"workflow is missing: {token}")
    marker = ("- [x] Patch 17.3 — Runtime Requirements in Canonical MIR and "
              "Native Requests — DONE")
    if marker not in text(root / TASK):
        fail("TASK.md does not mark Patch 17.3 DONE")


def render(contract_rows: list[dict[str, str]], authority: dict,
           abis: list[dict]) -> str:
    counts = Counter(row["kind"] for row in contract_rows)
    lines = [
        "Phase 17.3 — Runtime Requirements in Canonical MIR and Native Requests",
        f"guard: {GUARD}", f"test_level: {LEVEL}",
        f"requirement_policy: {authority['requirement_policy']}",
        f"deduplication_policy: {authority['deduplication_policy']}",
        "scope: three_approved_scalar_imports",
        "", "contract counts:",
    ]
    lines += [f"  {kind}: {counts[kind]}" for kind in sorted(counts)]
    lines += ["", "carried requirement identities:"]
    lines += [f"  {value}" for value in authority["carried_identities"]]
    lines += ["", "preserved runtime call shapes:"]
    lines += [f"  {value}" for value in authority["preserved_call_kinds"]]
    lines += ["", "declared target ABI version ranges:"]
    lines += [
        f"  {row['target_triple']}\t{row['compatible_version_min']}"
        f"\t{row['compatible_version_max']}"
        for row in abis
    ]
    lines += ["", "selected requirements:"]
    lines += [
        f"  {row['helper_id']}\t{row['call_kind']}\t"
        f"{row['required_version_min']}\t{row['required_version_max']}\t"
        f"package_mandatory={str(row['package_mandatory']).lower()}"
        for row in authority["selected_requirements"]
    ]
    lines += [
        "", "exit gate:",
        "  every selected runtime-facing MIR operation carries one validated "
        "compiler-produced requirement",
        "  malformed runtime metadata is rejected without backend or linker "
        "inference",
        "  runtime packages and target-specific selection remain in Patch 17.4",
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
    authority, abis = check_registry(root)
    check_source(root)
    expected = render(contract_rows, authority, abis)
    if args.write:
        (root / REVIEW).write_text(expected, encoding="utf-8")
    else:
        if text(root / REVIEW) != expected:
            fail("generated review is stale; run this script with --write")
        check_wiring(root)
    print(f"{GUARD}: ok ({len(abis)} targets, "
          f"{len(authority['selected_requirements'])} requirements, {LEVEL})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
