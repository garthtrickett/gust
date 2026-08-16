#!/usr/bin/env python3
"""Level 1 contract and reduced review for Phase 17.5 runtime imports."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter
from pathlib import Path

GUARD = "guard-cranelift-phase17-runtime-import-contract"
PARITY_GUARD = "guard-cranelift-phase17-runtime-import-parity"
LEVEL = "level1"
CONTRACT = Path("tests/cranelift/phase17_runtime_import_contract.tsv")
REVIEW = Path("tests/cranelift/phase17_runtime_import_review.txt")
REGISTRY = Path("scripts/cranelift_feature_registry.json")
SOURCE = Path("compiler/mir_runtime_boundary_authority.gst")
REQUEST_SOURCE = Path("compiler/mir_runtime_import_request.gst")
WORKER = Path("compiler/experiments/cranelift/src/runtime_import.rs")
MAIN = Path("compiler/experiments/cranelift/src/main.rs")
SMOKE = Path("compiler/mir_runtime_import_smoke_test_entry.gst")
PARITY = Path("scripts/phase17_runtime_import_parity.sh")
WORKFLOW = Path(".github/workflows/phase17-runtime-import.yml")
TASK = Path("TASK.md")

SIDE_EFFECTS = (
    "pure_scalar_no_side_effects", "observable_side_effects",
    "allocates_in_caller_arena",
)
FAILURES = (
    "total_cannot_fail", "returns_explicit_error", "aborts_process_on_failure",
)
EXPECTED = {
    "semantic_type": {"runtime_import_declaration"},
    "query": {"runtime_import_for"},
    "linkage": {
        "helper_and_symbol_identity", "symbol_version",
        "phase16_function_abi", "defining_runtime_component",
        "target_applicability",
    },
    "side_effect_policy": set(SIDE_EFFECTS),
    "failure_policy": set(FAILURES),
    "rejection": {
        "missing_symbol", "incompatible_version", "abi_mismatch",
        "wrong_target_component", "undeclared_import",
    },
    "policy": {
        "no_backend_symbol_or_signature_table",
        "direct_external_call_no_generated_c_glue",
        "package_exports_required_symbol", "stable_witness",
    },
    "boundary": {"three_approved_scalar_imports"},
}
REASONS = (
    "runtime_import_missing_symbol", "runtime_import_incompatible_version",
    "runtime_import_abi_mismatch", "runtime_import_wrong_target_component",
    "runtime_import_undeclared",
)
SOURCE_TOKENS = (
    "type MirRuntimeImportDeclaration", "side_effect_policy:", "failure_policy:",
    "func mir_runtime_import_declaration_id(",
    "func mir_runtime_import_for(", "func mir_runtime_import_by_id(",
    "func mir_runtime_side_effect_policy_is_valid(",
    "func mir_runtime_failure_policy_is_valid(",
    "mir_runtime_table_with_import_declaration(",
    "runtime_import_spelling", "runtime_import_version",
    "runtime_import_function_abi", "runtime_import_side_effects",
)
REQUEST_TOKENS = (
    "gust.compiler_runtime_import.v1", "gust.runtime_import_witness.v1",
    "func mir_serialize_runtime_import_request(",
    "func mir_runtime_import_mir_to_c_witness(",
    "direct_external_call_no_generated_c_glue",
)
WORKER_TOKENS = (
    "pub fn parse_runtime_import_request(",
    "pub fn render_runtime_import_witness(",
    "pub fn lower_runtime_import_witness_path(",
    "fn parameter_count(",
)
MAIN_TOKENS = (
    "mod runtime_import;",
    '"phase17-runtime-import-witness"',
    '"phase17-runtime-import-object"',
    "fn emit_phase17_runtime_import_object(",
    "Linkage::Import",
)
# The whole point of the patch: the worker derives the signature from the
# compiler's function ABI identity and keeps no spelling table of its own.
WORKER_BAN_TOKENS = (
    "tiny_host_add_one_i32",
    "tiny_host_add_i32",
    "tiny_host_is_positive_i32",
    "HOST_ADD_ONE_I32_SYMBOL",
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


def check_registry(root: Path) -> dict:
    registry = json.loads(text(root / REGISTRY))
    authority = registry.get("phase17_runtime_import_authority")
    if not isinstance(authority, dict):
        fail("canonical registry lacks runtime import authority")
    expected_metadata = {
        "version": "phase17_runtime_import_authority_v1",
        "status": "ready_for_patch17_6",
        "authority_owner": "compiler/mir_runtime_boundary_authority.gst",
        "request_owner": "compiler/mir_runtime_import_request.gst",
        "worker_owner": "compiler/experiments/cranelift/src/runtime_import.rs",
        "request_format": "gust.compiler_runtime_import.v1",
        "witness_format": "gust.runtime_import_witness.v1",
        "linkage_policy": "direct_external_call_no_generated_c_glue",
        "backend_table_policy":
            "backend_holds_no_symbol_spelling_or_signature_table_signature_"
            "derived_from_compiler_function_abi",
        "package_export_policy":
            "selected_package_must_export_required_symbol_and_version",
        "witness_policy":
            "cranelift_and_mir_to_c_runtime_import_witnesses_must_match_"
            "byte_for_byte",
        "scope_policy":
            "stable_runtime_library_imports_only_legacy_fixture_symbol_"
            "constants_removed_in_patch17_9",
        "next_patch": "17.6",
    }
    for key, value in expected_metadata.items():
        if authority.get(key) != value:
            fail(f"runtime import metadata drifted: {key}")
    if tuple(authority.get("side_effect_policies", ())) != SIDE_EFFECTS:
        fail("runtime import side-effect inventory drifted")
    if tuple(authority.get("failure_policies", ())) != FAILURES:
        fail("runtime import failure inventory drifted")
    if tuple(authority.get("rejection_classes", ())) != REASONS:
        fail("runtime import rejection inventory drifted")

    symbols = {
        row["helper_id"]: row
        for row in registry["phase17_runtime_symbol_authority"]
        ["selected_symbols"]
    }
    imports = authority.get("selected_imports", [])
    if {row.get("helper_id") for row in imports} != set(symbols):
        fail("selected import coverage drifted")
    for row in imports:
        symbol = symbols[row["helper_id"]]
        if (row.get("external_spelling") != symbol["external_spelling"]
                or row.get("function_abi_identity")
                != symbol["function_abi_identity"]
                or row.get("component_id") != symbol["component_id"]
                or row.get("symbol_version") != "gust-runtime-symbol-v1"
                or row.get("side_effect_policy") not in SIDE_EFFECTS
                or row.get("failure_policy") not in FAILURES):
            fail(f"selected import drifted: {row.get('helper_id')}")
    return authority


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
    for token in (*SOURCE_TOKENS, *REASONS, *SIDE_EFFECTS, *FAILURES):
        if token not in source:
            fail(f"runtime import source is missing: {token}")
    body = function_body(source, "mir_runtime_import_declaration_id").lower()
    for banned in ("hash", "sha", "digest", "fingerprint", "file_bytes"):
        if banned in body:
            fail(f"runtime import identity uses raw input: {banned}")
    request = text(root / REQUEST_SOURCE)
    for token in REQUEST_TOKENS:
        if token not in request:
            fail(f"runtime import request module is missing: {token}")
    worker = text(root / WORKER)
    for token in WORKER_TOKENS:
        if token not in worker:
            fail(f"Cranelift runtime import module is missing: {token}")
    for token in WORKER_BAN_TOKENS:
        if token in worker:
            fail(f"backend-maintained runtime symbol table: {WORKER}:{token}")
    main = text(root / MAIN)
    for token in MAIN_TOKENS:
        if token not in main:
            fail(f"Cranelift worker is missing runtime import wiring: {token}")


def check_wiring(root: Path) -> None:
    for path in (SMOKE, PARITY, WORKFLOW):
        if not (root / path).is_file():
            fail(f"missing required file: {path}")
    workflow = text(root / WORKFLOW)
    for token in (GUARD, PARITY_GUARD,
                  "python3 scripts/phase17_runtime_import.py --check",
                  "Phase 17.5 runtime import contract",
                  "Phase 17.5 runtime import parity"):
        if token not in workflow:
            fail(f"workflow is missing: {token}")
    parity = text(root / PARITY)
    for token in ("phase17-runtime-import-witness",
                  "phase17-runtime-import-object", "cmp -s", "nm -u"):
        if token not in parity:
            fail(f"parity script is missing: {token}")
    marker = ("- [x] Patch 17.5 — Stable Runtime-Library Imports for "
              "Cranelift — DONE")
    if marker not in text(root / TASK):
        fail("TASK.md does not mark Patch 17.5 DONE")


def render(contract_rows: list[dict[str, str]], authority: dict) -> str:
    counts = Counter(row["kind"] for row in contract_rows)
    lines = [
        "Phase 17.5 — Stable Runtime-Library Imports for Cranelift",
        f"guard: {GUARD}", f"parity_guard: {PARITY_GUARD}",
        f"test_level: {LEVEL}",
        f"request_format: {authority['request_format']}",
        f"witness_format: {authority['witness_format']}",
        f"linkage_policy: {authority['linkage_policy']}",
        "scope: three_approved_scalar_imports",
        "", "contract counts:",
    ]
    lines += [f"  {kind}: {counts[kind]}" for kind in sorted(counts)]
    lines += ["", "migrated stable runtime-library imports:"]
    lines += [
        f"  {row['helper_id']}\t{row['external_spelling']}\t"
        f"{row['symbol_version']}\t{row['side_effect_policy']}\t"
        f"{row['failure_policy']}"
        for row in authority["selected_imports"]
    ]
    lines += ["", "rejection classes:"]
    lines += [f"  {value}" for value in authority["rejection_classes"]]
    lines += [
        "", "exit gate:",
        "  every selected stable runtime-library helper is called by Cranelift "
        "through its compiler-owned versioned symbol",
        "  the explicit runtime package exports that symbol and version",
        "  no generated C glue stands between the caller and the runtime",
        "  legacy per-phase fixture symbol constants are removed in Patch 17.9",
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
    authority = check_registry(root)
    check_source(root)
    expected = render(contract_rows, authority)
    if args.write:
        (root / REVIEW).write_text(expected, encoding="utf-8")
    else:
        if text(root / REVIEW) != expected:
            fail("generated review is stale; run this script with --write")
        check_wiring(root)
    print(f"{GUARD}: ok ({len(authority['selected_imports'])} migrated "
          f"imports, {LEVEL})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
