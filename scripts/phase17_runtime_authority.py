#!/usr/bin/env python3
"""Level 1 contract and reduced review for Phase 17.1 runtime authority."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter
from pathlib import Path

GUARD_ID = "guard-cranelift-phase17-runtime-authority-contract"
TEST_LEVEL = "level1"
CONTRACT = Path("tests/cranelift/phase17_runtime_authority_contract.tsv")
REVIEW = Path("tests/cranelift/phase17_runtime_authority_review.txt")
REGISTRY = Path("scripts/cranelift_feature_registry.json")
AUTHORITY = Path("compiler/mir_runtime_boundary_authority.gst")
REQUEST = Path("compiler/mir_native_backend_runtime_request.gst")
SMOKE = Path("compiler/mir_runtime_boundary_authority_smoke_test_entry.gst")
WORKFLOW = Path(".github/workflows/phase17-runtime-authority.yml")
TASK = Path("TASK.md")

EXPECTED_TYPES = {
    "runtime_abi_identity": "type MirRuntimeAbiIdentity",
    "runtime_helper_identity": "type MirRuntimeHelperIdentity",
    "runtime_helper_classification": "type MirRuntimeHelperClassification",
    "runtime_component_identity": "type MirRuntimeComponentIdentity",
    "runtime_package_identity": "type MirRuntimePackageIdentity",
    "runtime_requirement": "type MirRuntimeRequirement",
    "runtime_compatibility_decision": "type MirRuntimeCompatibilityDecision",
    "runtime_link_plan_handoff": "type MirRuntimeLinkPlanHandoff",
}
EXPECTED_QUERIES = {
    "runtime_helper_of": "func mir_runtime_helper_of(",
    "classify_runtime_helper": "func mir_classify_runtime_helper(",
    "runtime_requirements": "func mir_runtime_requirements(",
    "runtime_component_for": "func mir_runtime_component_for(",
    "select_runtime_package": "func mir_select_runtime_package(",
    "validate_runtime_compatibility": "func mir_validate_runtime_compatibility(",
    "runtime_link_plan": "func mir_runtime_link_plan(",
}
EXPECTED_TRANSPORT = {
    "deterministic_runtime_identity_ids",
    "deterministic_requirement_ids",
    "deterministic_compatibility_ids",
    "canonical_mir_runtime_references",
    "native_request_runtime_table",
    "phase9g_runtime_link_plan_handoff",
}
EXPECTED_REASONS = {
    "unknown_format": "runtime_authority_unknown_format",
    "policy_mismatch": "runtime_authority_policy_mismatch",
    "unknown_helper_id": "runtime_unknown_helper_id",
    "missing_helper_classification": "runtime_missing_helper_classification",
    "conflicting_helper_classification": "runtime_conflicting_helper_classification",
    "invalid_helper_classification": "runtime_invalid_helper_classification",
    "unknown_component_id": "runtime_unknown_component_id",
    "unknown_package_id": "runtime_unknown_package_id",
    "requirement_mismatch": "runtime_requirement_mismatch",
    "compatibility_mismatch": "runtime_compatibility_mismatch",
    "unresolved_link_plan": "runtime_link_plan_unresolved",
    "target_mismatch": "runtime_target_mismatch",
    "canonical_mir_metadata_mismatch": "runtime_metadata_inconsistent_with_canonical_mir",
}
LEGAL_CLASSIFICATIONS = (
    "stable_runtime_library_function",
    "rust_runtime_component",
    "retained_c_runtime_component",
    "pure_gust_runtime_component",
    "obsolete_helper",
)
IDENTITY_FUNCTIONS = (
    "mir_runtime_abi_identity_id",
    "mir_runtime_helper_identity_id",
    "mir_runtime_classification_id",
    "mir_runtime_component_identity_id",
    "mir_runtime_package_identity_id",
    "mir_runtime_requirement_id",
    "mir_runtime_compatibility_decision_id",
    "mir_runtime_link_plan_id",
)
RAW_IDENTITY_BANS = ("sha", "hash", "digest", "fingerprint", "file_bytes")
REQUEST_TOKENS = (
    "type MirNativeBackendRuntimeRequest",
    "runtime_authority_table:",
    "func mir_native_backend_runtime_request_is_valid(",
    "mir_runtime_boundary_authority_table_validate(",
    "func mir_serialize_native_backend_runtime_request(",
    "mir_serialize_runtime_boundary_authority_table_for_request(",
    "abi_request.mir_serialize_native_backend_abi_request(",
    "before worker execution, driver discovery",
)
HARD_BANS = {
    "cranelift_helper_classification_table": (
        (Path("compiler/experiments/cranelift/src/main.rs"),),
        ("WorkerRuntimeHelperClassificationTable", "worker_classify_runtime_helper"),
    ),
    "worker_invented_runtime_requirements": (
        (Path("compiler/experiments/cranelift/src/main.rs"),),
        ("WorkerRuntimeRequirementPlanner", "worker_invent_runtime_requirement"),
    ),
    "driver_package_selection_from_unresolved_symbols": (
        (Path("compiler/driver.gst"), Path("compiler/experiments/cranelift/src/main.rs")),
        ("NativeDriverRuntimePackageSelector", "select_runtime_package_from_unresolved_symbol"),
    ),
    "diagnostic_runtime_compatibility_recomputation": (
        tuple(),
        ("diagnostic_recompute_runtime_compatibility", "diagnostic_infer_runtime_package"),
    ),
}


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD_ID}: {message}")


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        fail(f"missing required file: {path}")


def load_rows(root: Path) -> list[dict[str, str]]:
    path = root / CONTRACT
    try:
        with path.open(encoding="utf-8", newline="") as handle:
            rows = list(csv.DictReader(handle, delimiter="\t"))
    except FileNotFoundError:
        fail(f"missing required file: {CONTRACT}")
    required = {"kind", "id", "owner", "test_level", "disposition"}
    if not rows or set(rows[0]) != required:
        fail(f"{CONTRACT} has an unexpected schema")
    seen: set[tuple[str, str]] = set()
    for row in rows:
        key = (row["kind"], row["id"])
        if key in seen:
            fail(f"duplicate contract row: {key[0]}:{key[1]}")
        seen.add(key)
        if row["test_level"] != TEST_LEVEL:
            fail(f"non-Level-1 row: {row['id']}")
    return rows


def require_contract_inventory(rows: list[dict[str, str]]) -> None:
    by_kind: dict[str, set[str]] = {}
    for row in rows:
        by_kind.setdefault(row["kind"], set()).add(row["id"])
    expected = {
        "semantic_type": set(EXPECTED_TYPES),
        "query": set(EXPECTED_QUERIES),
        "transport": EXPECTED_TRANSPORT,
        "rejection": set(EXPECTED_REASONS),
        "hard_ban": set(HARD_BANS),
        "boundary": {"authority_and_classification_only"},
    }
    for kind, ids in expected.items():
        if by_kind.get(kind) != ids:
            fail(f"{kind} inventory mismatch")


def function_body(source: str, function_name: str) -> str:
    match = re.search(
        rf"func\s+{re.escape(function_name)}\s*\([^{{]+\)\s+[^{{]+\{{",
        source,
    )
    if not match:
        fail(f"missing identity function: {function_name}")
    start = match.end()
    depth = 1
    index = start
    while index < len(source) and depth:
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
        index += 1
    if depth:
        fail(f"unterminated identity function: {function_name}")
    return source[start : index - 1]


def check_registry(root: Path) -> tuple[dict, Counter[str]]:
    registry = json.loads(read_text(root / REGISTRY))
    authority = registry.get("phase17_runtime_authority")
    if not isinstance(authority, dict):
        fail("canonical registry lacks Phase 17 runtime authority")
    if authority.get("version") != "phase17_compiler_owned_runtime_boundary_authority_v1":
        fail("runtime authority version drifted")
    if tuple(authority.get("semantic_types", [])) != tuple(
        token.removeprefix("type ") for token in EXPECTED_TYPES.values()
    ):
        fail("runtime semantic type projection drifted")
    if tuple(authority.get("query_functions", [])) != tuple(
        token.removeprefix("func ").removesuffix("(")
        for token in EXPECTED_QUERIES.values()
    ):
        fail("runtime query projection drifted")
    if tuple(authority.get("legal_helper_classifications", [])) != LEGAL_CLASSIFICATIONS:
        fail("five legal helper classifications drifted")
    inventory = {
        row["id"]: row
        for row in registry["opening_snapshots"]["phase17"]["helper_inventory"]
    }
    classifications = authority.get("helper_classifications", [])
    if len(classifications) != len(inventory):
        fail("not every inventoried helper has exactly one classification")
    seen: set[str] = set()
    counts: Counter[str] = Counter()
    for row in classifications:
        helper_id = row.get("helper_id")
        if helper_id not in inventory or helper_id in seen:
            fail(f"unknown or multiply classified helper: {helper_id}")
        seen.add(helper_id)
        if row.get("symbol_identity") != inventory[helper_id]["symbol_identity"]:
            fail(f"classification symbol differs from inventory: {helper_id}")
        classification = row.get("classification")
        if classification not in LEGAL_CLASSIFICATIONS:
            fail(f"illegal helper classification: {classification}")
        counts[classification] += 1
    if seen != set(inventory):
        fail("helper classification coverage is incomplete")
    return authority, counts


def check_authority(root: Path) -> None:
    source = read_text(root / AUTHORITY)
    for item, token in EXPECTED_TYPES.items():
        if token not in source:
            fail(f"missing semantic type {item}")
    for item, token in EXPECTED_QUERIES.items():
        if token not in source:
            fail(f"missing compiler query {item}")
    for item, token in EXPECTED_REASONS.items():
        if token not in source:
            fail(f"missing rejection reason {item}")
    for classification in LEGAL_CLASSIFICATIONS:
        if f'"{classification}"' not in source:
            fail(f"authority does not freeze classification {classification}")
    for token in (
        "type MirRuntimeMirReference",
        "compiler_owned_native_runtime_boundary_authority",
        "exactly_one_of_five_compiler_owned_helper_classifications",
        "compiler_produced_requirements_only_worker_must_not_invent",
        "phase9g_consumes_validated_runtime_handoff_no_unresolved_symbol_inference",
        "mir_runtime_boundary_authority_table_validate(",
        "mir_serialize_runtime_boundary_authority_table_for_request(",
    ):
        if token not in source:
            fail(f"missing runtime authority marker: {token}")
    for name in IDENTITY_FUNCTIONS:
        body = function_body(source, name).lower()
        for banned in RAW_IDENTITY_BANS:
            if banned in body:
                fail(f"identity function {name} uses banned raw input: {banned}")


def check_request(root: Path) -> None:
    source = read_text(root / REQUEST)
    for token in REQUEST_TOKENS:
        if token not in source:
            fail(f"runtime request transport is missing: {token}")
    validation = source.find("mir_runtime_boundary_authority_table_validate(")
    runtime_serialization = source.find(
        "mir_serialize_runtime_boundary_authority_table_for_request("
    )
    abi_serialization = source.find(
        "abi_request.mir_serialize_native_backend_abi_request("
    )
    if min(validation, runtime_serialization, abi_serialization) < 0:
        fail("runtime request does not validate and serialize both authority layers")
    if runtime_serialization > abi_serialization:
        fail("runtime authority must serialize before the Phase 16 ABI request")


def diagnostic_files(root: Path) -> list[Path]:
    return [
        path for path in (root / "compiler").rglob("*")
        if path.is_file() and "diagnostic" in path.name.lower()
        and path.suffix in {".gst", ".rs"}
    ]


def check_hard_bans(root: Path) -> None:
    for ban_id, (fixed_paths, tokens) in HARD_BANS.items():
        paths = diagnostic_files(root) if not fixed_paths else [
            root / path for path in fixed_paths if (root / path).exists()
        ]
        for path in paths:
            source = path.read_text(encoding="utf-8", errors="replace")
            for token in tokens:
                if token in source:
                    fail(f"hard ban {ban_id} violated by {path.relative_to(root)}")


def check_wiring(root: Path) -> None:
    for path in (SMOKE, WORKFLOW):
        if not (root / path).is_file():
            fail(f"missing required file: {path}")
    workflow = read_text(root / WORKFLOW)
    for token in (
        GUARD_ID,
        "python3 scripts/phase17_runtime_authority.py --check",
        "Phase 17.1 runtime authority contract",
    ):
        if token not in workflow:
            fail(f"workflow is missing Level 1 marker: {token}")
    if "- [x] Patch 17.1 — Compiler-Owned Runtime Boundary and Helper Classification Authority — DONE" not in read_text(root / TASK):
        fail("TASK.md does not mark Patch 17.1 DONE")


def render_review(rows: list[dict[str, str]], counts: Counter[str]) -> str:
    kinds = Counter(row["kind"] for row in rows)
    lines = [
        "Phase 17.1 — Compiler-Owned Runtime Boundary and Helper Classification Authority",
        f"guard: {GUARD_ID}",
        f"test_level: {TEST_LEVEL}",
        "boundary: authority_and_classification_only",
        "identity: compiler_semantic_state_plus_request_ordinal_no_raw_hash",
        "request_order: runtime_authority_before_phase16_abi_resource_and_canonical_request",
        "failure_stage: before_worker_driver_request_object_link_or_output_access",
        "",
        "contract counts:",
    ]
    for kind in sorted(kinds):
        lines.append(f"  {kind}: {kinds[kind]}")
    lines.extend(["", "helper classifications:"])
    for classification in LEGAL_CLASSIFICATIONS:
        lines.append(f"  {classification}: {counts.get(classification, 0)}")
    lines.extend(["", "active contract:"])
    for row in rows:
        lines.append(
            f"  {row['kind']}\t{row['id']}\t{row['owner']}\t{row['disposition']}"
        )
    lines.extend(
        [
            "",
            "consumer rule:",
            "  canonical MIR, MIR-to-C, Cranelift, runtime packaging, diagnostics, and Phase 9G consume the compiler-owned runtime table",
            "  the worker validates transport consistency and does not invent classifications, requirements, components, packages, compatibility, or link plans",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()

    rows = load_rows(root)
    require_contract_inventory(rows)
    _, classification_counts = check_registry(root)
    check_authority(root)
    check_request(root)
    check_hard_bans(root)
    expected = render_review(rows, classification_counts)
    if args.write:
        path = root / REVIEW
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(expected, encoding="utf-8")
    else:
        if read_text(root / REVIEW) != expected:
            fail(
                "generated review is stale; run "
                "python3 scripts/phase17_runtime_authority.py --write"
            )
        check_wiring(root)
    print(
        f"{GUARD_ID}: ok ({len(rows)} rows, "
        f"{sum(classification_counts.values())} helpers, {TEST_LEVEL})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
