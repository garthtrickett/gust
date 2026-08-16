#!/usr/bin/env python3
"""Level 1 contract and reduced review for Phase 17.2 runtime symbols."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter
from pathlib import Path

GUARD = "guard-cranelift-phase17-runtime-symbol-version-contract"
LEVEL = "level1"
CONTRACT = Path("tests/cranelift/phase17_runtime_symbol_version_contract.tsv")
REVIEW = Path("tests/cranelift/phase17_runtime_symbol_version_review.txt")
REGISTRY = Path("scripts/cranelift_feature_registry.json")
SOURCE = Path("compiler/mir_runtime_boundary_authority.gst")
REQUEST = Path("compiler/mir_native_backend_runtime_request.gst")
SMOKE = Path("compiler/mir_runtime_symbol_version_smoke_test_entry.gst")
WORKFLOW = Path(".github/workflows/phase17-runtime-symbol-version.yml")
TASK = Path("TASK.md")

EXPECTED = {
    "semantic_type": {"runtime_abi_identity", "runtime_symbol_identity"},
    "query": {"runtime_abi_for", "runtime_symbol_for"},
    "linkage": {
        "phase14_target_layout", "phase15_resource_operation",
        "phase16_function_abi", "required_optional_policy",
        "visibility_and_linkage_policy",
    },
    "rejection": {
        "unknown_runtime_abi", "unversioned_selected_symbol",
        "duplicate_conflicting_symbol", "symbol_spelling_abi_conflict",
        "calling_convention_mismatch", "target_or_layout_mismatch",
        "backend_raw_symbol_substitution",
    },
    "policy": {
        "runtime_abi_version", "symbol_version", "compatibility_range",
        "stable_witness",
    },
    "boundary": {"three_approved_scalar_imports"},
}
SYMBOLS = {
    "p17_helper_tiny_host_add_one_i32": (
        "tiny_host_add_one_i32", "signature:i32_to_i32"
    ),
    "p17_helper_tiny_host_add_i32": (
        "tiny_host_add_i32", "signature:i32_i32_to_i32"
    ),
    "p17_helper_tiny_host_is_positive_i32": (
        "tiny_host_is_positive_i32", "signature:i32_to_i32"
    ),
}
REASONS = (
    "runtime_symbol_unknown_abi", "runtime_symbol_unversioned",
    "runtime_symbol_duplicate_conflict",
    "runtime_symbol_calling_convention_mismatch",
    "runtime_symbol_target_or_layout_mismatch",
    "runtime_symbol_spelling_abi_conflict",
    "runtime_symbol_backend_substitution",
)
SOURCE_TOKENS = (
    "type MirRuntimeSymbolIdentity",
    "compatible_version_min:", "compatible_version_max:",
    "external_spelling:", "symbol_version:", "function_abi_id:",
    "calling_convention_id:", "layout_id:", "resource_operation_id:",
    "required:", "visibility:", "linkage:", "compatibility_policy:",
    "func mir_runtime_symbol_identity_id(",
    "func mir_runtime_abi_for(", "func mir_runtime_symbol_for(",
    "func mir_runtime_validate_symbol_spelling(",
    "mir_runtime_table_with_symbol(",
    "runtime_symbol_id", "runtime_symbol_external_spelling",
    "runtime_symbol_version",
)
REQUEST_TOKENS = (
    "func mir_native_backend_runtime_abi_for(",
    "func mir_native_backend_runtime_symbol_for(",
)
BAN_TOKENS = (
    "WorkerRuntimeSymbolSubstitutionTable",
    "worker_substitute_runtime_symbol",
    "mir_to_c_infer_runtime_symbol_version",
    "select_runtime_symbol_from_unresolved_linker_name",
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
    authority = registry.get("phase17_runtime_symbol_authority")
    if not isinstance(authority, dict):
        fail("canonical registry lacks runtime symbol authority")
    expected_metadata = {
        "version": "phase17_runtime_symbol_version_authority_v1",
        "status": "ready_for_patch17_3",
        "authority_owner": "compiler/mir_runtime_boundary_authority.gst",
        "runtime_abi_version": "gust-runtime-abi-v1",
        "symbol_version": "gust-runtime-symbol-v1",
        "symbol_naming_policy": "preserve_real_external_spelling_version_in_compiler_symbol_identity",
        "compatibility_policy": "exact_major_compatible_minor_range_1_1",
        "visibility_policy": "default_hidden_selected_runtime_imports_public",
        "linkage_policy": "external_static_runtime_package_no_dynamic_loading",
        "backend_policy": "backends_consume_compiler_symbol_records_no_raw_symbol_substitution",
        "witness_policy": "stable_runtime_abi_and_versioned_symbol_witnesses",
        "scope_policy": "three_approved_scalar_imports_only_other_helper_symbols_extend_in_later_phase17_patches",
        "next_patch": "17.3",
    }
    for key, value in expected_metadata.items():
        if authority.get(key) != value:
            fail(f"runtime symbol metadata drifted: {key}")
    targets = registry["phase14_primitive_layout"]["declared_targets"]
    abis = authority.get("supported_abis", [])
    if len(abis) != len(targets):
        fail("runtime ABI target coverage drifted")
    for abi, target in zip(abis, targets):
        for key in ("target_id", "target_triple", "object_format"):
            if abi.get(key) != target.get(key):
                fail(f"runtime ABI does not derive Phase 14 {key}")
        if (abi.get("calling_convention_id") != "gust_canonical_v1"
                or abi.get("layout_authority_id")
                != "phase14_compiler_owned_type_and_target_layout"
                or abi.get("function_abi_authority_id")
                != "phase16_compiler_owned_function_abi"
                or abi.get("resource_authority_id")
                != "phase15_compiler_owned_resource_operations"
                or (abi.get("compatible_version_min"),
                    abi.get("compatible_version_max")) != (1, 1)):
            fail(f"runtime ABI linkage drifted: {abi.get('target_triple')}")
    classifications = {
        row["helper_id"]: row
        for row in registry["phase17_runtime_authority"]["helper_classifications"]
    }
    selected = authority.get("selected_symbols", [])
    if {row.get("helper_id") for row in selected} != set(SYMBOLS):
        fail("selected symbol coverage drifted")
    for row in selected:
        helper = row["helper_id"]
        spelling, signature = SYMBOLS[helper]
        if (row.get("external_spelling") != spelling
                or row.get("signature_id") != signature
                or classifications[helper]["classification"]
                != "stable_runtime_library_function"
                or row.get("component_id")
                != classifications[helper]["component_id"]
                or row.get("layout_id") != "layout:type:gust:i32"
                or row.get("resource_operation_id")
                != "none_scalar_runtime_operation"
                or row.get("required") is not True):
            fail(f"selected symbol record drifted: {helper}")
    return authority, targets


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
    for token in (*SOURCE_TOKENS, *REASONS):
        if token not in source:
            fail(f"runtime symbol source is missing: {token}")
    body = function_body(source, "mir_runtime_symbol_identity_id").lower()
    for banned in ("hash", "sha", "digest", "fingerprint", "file_bytes"):
        if banned in body:
            fail(f"runtime symbol identity uses raw input: {banned}")
    request = text(root / REQUEST)
    for token in REQUEST_TOKENS:
        if token not in request:
            fail(f"runtime request is missing symbol adapter: {token}")
    for path in (
        root / "compiler/mir_to_c.gst",
        root / "compiler/experiments/cranelift/src/main.rs",
        root / "compiler/driver.gst",
    ):
        if path.is_file():
            content = text(path)
            for token in BAN_TOKENS:
                if token in content:
                    fail(f"backend-local runtime symbol authority: {path}:{token}")


def check_wiring(root: Path) -> None:
    for path in (SMOKE, WORKFLOW):
        if not (root / path).is_file():
            fail(f"missing required file: {path}")
    workflow = text(root / WORKFLOW)
    for token in (GUARD, "python3 scripts/phase17_runtime_symbol_version.py --check",
                  "Phase 17.2 runtime symbol version contract"):
        if token not in workflow:
            fail(f"workflow is missing: {token}")
    marker = "- [x] Patch 17.2 — Supported Runtime ABI, Symbol Identity, and Versioning — DONE"
    if marker not in text(root / TASK):
        fail("TASK.md does not mark Patch 17.2 DONE")


def render(contract_rows: list[dict[str, str]], authority: dict,
           targets: list[dict]) -> str:
    counts = Counter(row["kind"] for row in contract_rows)
    lines = [
        "Phase 17.2 — Supported Runtime ABI, Symbol Identity, and Versioning",
        f"guard: {GUARD}", f"test_level: {LEVEL}",
        f"runtime_abi_version: {authority['runtime_abi_version']}",
        f"symbol_version: {authority['symbol_version']}",
        "scope: three_approved_scalar_imports",
        "", "contract counts:",
    ]
    lines += [f"  {kind}: {counts[kind]}" for kind in sorted(counts)]
    lines += ["", "declared target ABIs:"]
    lines += [f"  {row['target_triple']}\t{row['object_format']}\tgust_canonical_v1"
              for row in targets]
    lines += ["", "selected versioned symbols:"]
    lines += [
        f"  {row['helper_id']}\t{row['external_spelling']}\t"
        f"{row['signature_id']}\t{authority['symbol_version']}"
        for row in authority["selected_symbols"]
    ]
    lines += [
        "", "exit gate:",
        "  every selected runtime call resolves to one compiler-owned versioned symbol",
        "  target layout function ABI resource linkage visibility and compatibility are explicit",
        "  later Phase 17 patches extend this authority for the remaining helper inventory",
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
    authority, targets = check_registry(root)
    check_source(root)
    expected = render(contract_rows, authority, targets)
    if args.write:
        (root / REVIEW).write_text(expected, encoding="utf-8")
    else:
        if text(root / REVIEW) != expected:
            fail("generated review is stale; run this script with --write")
        check_wiring(root)
    print(f"{GUARD}: ok ({len(targets)} targets, {len(SYMBOLS)} symbols, {LEVEL})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
