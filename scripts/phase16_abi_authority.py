#!/usr/bin/env python3
"""Level 1 contract and reduced review projection for Phase 16.1."""

from __future__ import annotations

import argparse
import csv
from collections import Counter
from pathlib import Path
import re
import sys

GUARD_ID = "guard-cranelift-phase16-abi-authority-contract"
TEST_LEVEL = "level1"
CONTRACT = Path("tests/cranelift/phase16_abi_authority_contract.tsv")
REVIEW = Path("tests/cranelift/phase16_abi_authority_review.txt")
AUTHORITY = Path("compiler/mir_function_abi_authority.gst")
REQUEST = Path("compiler/mir_native_backend_abi_request.gst")
SMOKE = Path("compiler/mir_function_abi_authority_smoke_test_entry.gst")
WORKFLOW = Path(".github/workflows/phase16-abi-authority.yml")
TASK = Path("TASK.md")

EXPECTED_TYPES = {
    "function_abi_identity": "type MirFunctionAbiIdentity",
    "abi_value_classification": "type MirAbiValueClassification",
    "parameter_placement": "type MirAbiParameterPlacement",
    "result_placement": "type MirAbiResultPlacement",
    "call_site_plan": "type MirAbiCallSitePlan",
    "dynamic_frame_plan": "type MirDynamicFramePlan",
    "abi_compatibility_decision": "type MirAbiCompatibilityDecision",
}
EXPECTED_QUERIES = {
    "function_abi": "func mir_function_abi(",
    "classify_abi_value": "func mir_classify_abi_value(",
    "parameter_placements": "func mir_parameter_placements(",
    "result_placements": "func mir_result_placements(",
    "call_plan": "func mir_abi_call_plan(",
    "frame_plan": "func mir_abi_frame_plan(",
    "validate_abi_compatibility": "func mir_validate_abi_compatibility(",
}
EXPECTED_REASONS = {
    "unknown_abi_ids": "abi_unknown_id",
    "duplicate_conflicting_records": "abi_duplicate_conflicting_record",
    "unknown_layout_or_resource_ids": "abi_unknown_layout_or_resource_id",
    "impossible_placements": "abi_impossible_placement",
    "invalid_hidden_results": "abi_invalid_hidden_result",
    "signature_mismatches": "abi_signature_mismatch",
    "target_mismatches": "abi_target_mismatch",
    "metadata_inconsistent_with_canonical_mir": "abi_metadata_inconsistent_with_canonical_mir",
}
EXPECTED_TRANSPORT = {
    "deterministic_abi_value_ids",
    "deterministic_placement_ids",
    "deterministic_call_site_ids",
    "deterministic_frame_plan_ids",
    "canonical_mir_abi_references",
    "native_request_abi_table",
}
REQUEST_TOKENS = (
    "type MirNativeBackendAbiRequest",
    "abi_authority_table:",
    "func mir_native_backend_abi_request_is_valid(",
    "mir_function_abi_authority_table_validate(",
    "func mir_serialize_native_backend_abi_request(",
    "mir_serialize_function_abi_authority_table_for_request(",
    "resource_request.mir_serialize_native_backend_resource_request(",
    "before worker execution, driver",
)
IDENTITY_FUNCTIONS = (
    "mir_function_abi_identity_id",
    "mir_abi_value_classification_id",
    "mir_abi_placement_id",
    "mir_abi_call_site_plan_id",
    "mir_dynamic_frame_plan_id",
)
RAW_IDENTITY_BANS = ("sha", "hash", "digest", "fingerprint", "file_bytes")

HARD_BANS = {
    "mir_to_c_separate_aggregate_classifier": (
        (Path("compiler/mir_to_c.gst"),),
        ("MirToCAggregateAbiClassifier", "mir_to_c_classify_aggregate_abi", "mir_to_c_plan_hidden_result"),
    ),
    "worker_separate_call_planner": (
        (Path("compiler/experiments/cranelift/src/main.rs"),),
        ("WorkerAbiTable", "struct WorkerCallPlanner", "worker_plan_abi_call"),
    ),
    "cranelift_signatures_as_semantic_authority": (
        (Path("compiler/experiments/cranelift/src/main.rs"),),
        ("CraneliftSignatureAuthority", "cranelift_signature_is_semantic_authority", "infer_abi_from_cranelift_signature"),
    ),
    "diagnostics_independent_abi_decisions": (
        tuple(),
        ("diagnostic_recompute_function_abi", "diagnostic_infer_abi_placement"),
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
        "boundary": {"authority_and_transport_only"},
    }
    for kind, ids in expected.items():
        if by_kind.get(kind) != ids:
            fail(f"{kind} inventory mismatch: expected {sorted(ids)}, got {sorted(by_kind.get(kind, set()))}")


def function_body(source: str, function_name: str) -> str:
    match = re.search(rf"func\s+{re.escape(function_name)}\s*\([^{{]+\)\s+[^{{]+\{{", source)
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
            fail(f"missing request rejection {item}")
    for token in (
        "type MirAbiMirReference",
        "mir_function_id:",
        "mir_call_id:",
        "mir_result_id:",
        "abi_id:",
        "call_plan_id:",
        "frame_plan_id:",
        "compiler_semantic_state_plus_request_ordinal_no_raw_hash",
        "mir_function_abi_authority_table_validate(",
        "mir_serialize_function_abi_authority_table_for_request(",
    ):
        if token not in source:
            fail(f"missing canonical ABI authority marker: {token}")
    for name in IDENTITY_FUNCTIONS:
        body = function_body(source, name).lower()
        for banned in RAW_IDENTITY_BANS:
            if banned in body:
                fail(f"semantic identity function {name} uses banned raw identity input: {banned}")


def check_request(root: Path) -> None:
    source = read_text(root / REQUEST)
    for token in REQUEST_TOKENS:
        if token not in source:
            fail(f"native request ABI transport is missing: {token}")
    validation_call = source.find("mir_function_abi_authority_table_validate(")
    abi_serialization = source.find("mir_serialize_function_abi_authority_table_for_request(")
    base_serialization = source.find("resource_request.mir_serialize_native_backend_resource_request(")
    if min(validation_call, abi_serialization, base_serialization) < 0:
        fail("native ABI request does not validate and serialize both ABI and resource requests")
    if abi_serialization > base_serialization:
        fail("ABI authority must serialize before the base request reaches the worker")


def candidate_diagnostic_files(root: Path) -> list[Path]:
    compiler = root / "compiler"
    if not compiler.exists():
        return []
    return [
        path
        for path in compiler.rglob("*")
        if path.is_file() and "diagnostic" in path.name.lower() and path.suffix in {".gst", ".rs"}
    ]


def check_hard_bans(root: Path) -> None:
    for ban_id, (fixed_paths, tokens) in HARD_BANS.items():
        paths = candidate_diagnostic_files(root) if ban_id == "diagnostics_independent_abi_decisions" else [
            root / path for path in fixed_paths if (root / path).exists()
        ]
        for path in paths:
            source = path.read_text(encoding="utf-8", errors="replace")
            for token in tokens:
                if token in source:
                    fail(f"hard ban {ban_id} violated by {path.relative_to(root)}: {token}")


def check_wiring(root: Path) -> None:
    if not (root / SMOKE).is_file():
        fail(f"missing authority smoke entry: {SMOKE}")
    workflow = read_text(root / WORKFLOW)
    for token in (GUARD_ID, "python3 scripts/phase16_abi_authority.py --check", "Phase 16.1 ABI authority contract"):
        if token not in workflow:
            fail(f"workflow is missing Level 1 ownership marker: {token}")
    task = read_text(root / TASK)
    if "- [x] Patch 16.1 — Compiler-Owned Function ABI Authority — DONE" not in task:
        fail("TASK.md does not mark Patch 16.1 DONE")


def render_review(rows: list[dict[str, str]]) -> str:
    counts = Counter(row["kind"] for row in rows)
    lines = [
        "Phase 16.1 — Compiler-Owned Function ABI Authority",
        f"guard: {GUARD_ID}",
        f"test_level: {TEST_LEVEL}",
        "boundary: authority_and_transport_only",
        "identity: compiler_semantic_state_plus_request_ordinal_no_raw_hash",
        "request_order: abi_authority_before_resource_and_canonical_request",
        "failure_stage: before_worker_driver_request_object_link_or_output_access",
        "",
        "counts:",
    ]
    for kind in sorted(counts):
        lines.append(f"  {kind}: {counts[kind]}")
    lines.extend(["", "active contract:"])
    for row in rows:
        lines.append(f"  {row['kind']}\t{row['id']}\t{row['owner']}\t{row['disposition']}")
    lines.extend(
        [
            "",
            "consumer rule:",
            "  canonical MIR metadata, MIR-to-C, Cranelift, runtime-facing calls, and diagnostics consume the compiler-owned ABI table",
            "  the worker validates transport consistency and does not invent classification, placement, call, hidden-result, or frame semantics",
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
    check_authority(root)
    check_request(root)
    check_hard_bans(root)
    expected = render_review(rows)

    if args.write:
        path = root / REVIEW
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(expected, encoding="utf-8")
    else:
        actual = read_text(root / REVIEW)
        if actual != expected:
            fail(f"generated review is stale; run python3 scripts/phase16_abi_authority.py --write")
        check_wiring(root)

    print(f"{GUARD_ID}: ok ({len(rows)} rows, {TEST_LEVEL})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
