#!/usr/bin/env python3
"""Level 1 contract and reduced review projection for Phase 15.1."""

from __future__ import annotations

import argparse
import csv
from collections import Counter
from pathlib import Path
import re
import sys

GUARD_ID = "guard-cranelift-phase15-resource-authority-contract"
TEST_LEVEL = "level1"
CONTRACT = Path("tests/cranelift/phase15_resource_authority_contract.tsv")
REVIEW = Path("tests/cranelift/phase15_resource_authority_review.txt")
AUTHORITY = Path("compiler/mir_resource_authority.gst")
REQUEST = Path("compiler/mir_native_backend_resource_request.gst")
WORKFLOW = Path(".github/workflows/phase15-resource-authority.yml")

EXPECTED_TYPES = {
    "resource_identity": "type MirResourceIdentity",
    "resource_state": "type MirResourceState",
    "resource_transition": "type MirResourceTransition",
    "cleanup_obligation": "type MirCleanupObligation",
    "destructor_identity": "type MirDestructorIdentity",
    "close_capability": "type MirCloseCapability",
    "resource_state_join": "type MirResourceStateJoin",
}
EXPECTED_QUERIES = {
    "resource_of": "func mir_resource_of(",
    "resource_state_at": "func mir_resource_state_at(",
    "validate_resource_transition": "func mir_validate_resource_transition(",
    "cleanup_obligations": "func mir_cleanup_obligations(",
    "destructor_for": "func mir_destructor_for(",
    "join_resource_states": "func mir_join_resource_states(",
}
EXPECTED_REASONS = {
    "unknown_resource_ids": "resource_unknown_id",
    "duplicate_conflicting_resource_records": "resource_duplicate_conflicting_record",
    "unknown_destructor_ids": "resource_unknown_destructor_id",
    "impossible_state_transitions": "resource_impossible_state_transition",
    "cleanup_for_moved_or_destroyed_values": "resource_cleanup_for_moved_or_destroyed_value",
    "duplicate_cleanup_ids": "resource_duplicate_cleanup_id",
    "target_or_layout_mismatches": "resource_target_or_layout_mismatch",
    "metadata_inconsistent_with_canonical_mir": "resource_metadata_inconsistent_with_canonical_mir",
}
REQUEST_TOKENS = (
    "type MirNativeBackendResourceRequest",
    "resource_authority_table:",
    "func mir_native_backend_resource_request_is_valid(",
    "mir_resource_authority_table_validate(",
    "func mir_serialize_native_backend_resource_request(",
    "mir_serialize_resource_authority_table_for_request(",
    "native_request.mir_serialize_native_backend_request(",
)
IDENTITY_FUNCTIONS = (
    "mir_resource_identity_id",
    "mir_cleanup_obligation_id",
)
RAW_IDENTITY_BANS = ("sha", "hash", "digest", "fingerprint", "file_bytes")

HARD_BANS = {
    "mir_to_c_separate_resource_state_table": (
        (Path("compiler/mir_to_c.gst"),),
        ("MirToCResourceStateTable", "mir_to_c_resource_state_table", "mir_to_c_plan_cleanup"),
    ),
    "worker_separate_cleanup_planner": (
        (Path("compiler/experiments/cranelift/src/main.rs"),),
        ("WorkerResourceStateTable", "struct CleanupPlanner", "plan_cleanup_obligation"),
    ),
    "runtime_duplicate_resource_transitions": (
        tuple(),
        ("RUNTIME_RESOURCE_TRANSITION_TABLE", "runtime_resource_transition_table", "runtime_apply_resource_transition"),
    ),
    "diagnostics_independent_resource_state": (
        tuple(),
        ("diagnostic_recompute_resource_state", "diagnostic_infer_resource_state"),
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
    with path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
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
        "rejection": set(EXPECTED_REASONS),
        "hard_ban": set(HARD_BANS),
        "transport": {
            "deterministic_resource_id",
            "deterministic_cleanup_id",
            "canonical_mir_resource_cleanup_references",
            "native_request_resource_table",
        },
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
        "type MirResourceMirReference",
        "mir_value_id:",
        "mir_operation_id:",
        "resource_id:",
        "cleanup_id:",
        "compiler_semantic_state_plus_request_ordinal_no_raw_hash",
    ):
        if token not in source:
            fail(f"missing canonical authority marker: {token}")
    for name in IDENTITY_FUNCTIONS:
        body = function_body(source, name).lower()
        for banned in RAW_IDENTITY_BANS:
            if banned in body:
                fail(f"semantic identity function {name} uses banned raw identity input: {banned}")


def check_request(root: Path) -> None:
    source = read_text(root / REQUEST)
    for token in REQUEST_TOKENS:
        if token not in source:
            fail(f"native request resource transport is missing: {token}")
    validation_call = source.find("mir_resource_authority_table_validate(")
    base_serialization = source.find("native_request.mir_serialize_native_backend_request(")
    resource_serialization = source.find("mir_serialize_resource_authority_table_for_request(")
    if validation_call < 0 or resource_serialization < 0 or base_serialization < 0:
        fail("native resource request does not validate and serialize both authority and base request")
    if resource_serialization > base_serialization:
        fail("resource authority must serialize before the base request reaches the worker")


def candidate_runtime_files(root: Path) -> list[Path]:
    result: list[Path] = []
    for folder in (root / "runtime", root / "compiler" / "runtime"):
        if folder.exists():
            result.extend(path for path in folder.rglob("*") if path.suffix in {".gst", ".rs", ".c", ".h"})
    return result


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
        if ban_id == "runtime_duplicate_resource_transitions":
            paths = candidate_runtime_files(root)
        elif ban_id == "diagnostics_independent_resource_state":
            paths = candidate_diagnostic_files(root)
        else:
            paths = [root / path for path in fixed_paths if (root / path).exists()]
        for path in paths:
            source = path.read_text(encoding="utf-8", errors="replace")
            for token in tokens:
                if token in source:
                    fail(f"hard ban {ban_id} violated by {path.relative_to(root)}: {token}")


def render_review(rows: list[dict[str, str]]) -> str:
    counts = Counter(row["kind"] for row in rows)
    lines = [
        "Phase 15.1 — Compiler-Owned Resource and Lifetime Authority",
        f"guard: {GUARD_ID}",
        f"test_level: {TEST_LEVEL}",
        "boundary: authority_and_transport_only",
        "identity: compiler_semantic_state_plus_request_ordinal_no_raw_hash",
        "",
        "counts:",
    ]
    for kind in sorted(counts):
        lines.append(f"  {kind}: {counts[kind]}")
    lines.extend(["", "active contract:"])
    for row in rows:
        lines.append(
            f"  {row['kind']}\t{row['id']}\t{row['owner']}\t{row['disposition']}"
        )
    lines.extend(
        [
            "",
            "consumer rule:",
            "  canonical MIR metadata, MIR-to-C, Cranelift, runtime-facing operations, and diagnostics consume the compiler-owned table",
            "  the worker validates transport consistency and does not invent ownership semantics",
            "",
        ]
    )
    return "\n".join(lines)


def check_workflow(root: Path) -> None:
    workflow = read_text(root / WORKFLOW)
    for token in (GUARD_ID, "python3 scripts/phase15_resource_authority.py --check", "Phase 15.1 resource authority contract"):
        if token not in workflow:
            fail(f"workflow is missing Level 1 ownership marker: {token}")


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
            fail(f"generated review is stale; run python3 scripts/phase15_resource_authority.py --write")
        check_workflow(root)

    print(f"{GUARD_ID}: ok ({len(rows)} rows, {TEST_LEVEL})")
    return 0


if __name__ == "__main__":
    sys.exit(main())