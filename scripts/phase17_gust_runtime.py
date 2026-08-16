#!/usr/bin/env python3
"""Level 1 contract and reduced review for Phase 17.8 pure Gust runtime modules."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import Counter
from pathlib import Path

GUARD = "guard-cranelift-phase17-gust-runtime-contract"
PARITY_GUARD = "guard-cranelift-phase17-gust-runtime-parity"
LEVEL = "level1"
CONTRACT = Path("tests/cranelift/phase17_gust_runtime_contract.tsv")
REVIEW = Path("tests/cranelift/phase17_gust_runtime_review.txt")
REGISTRY = Path("scripts/cranelift_feature_registry.json")
SOURCE = Path("compiler/mir_runtime_boundary_authority.gst")
REQUEST_SOURCE = Path("compiler/mir_gust_runtime_request.gst")
WORKER = Path("compiler/experiments/cranelift/src/gust_runtime.rs")
MAIN = Path("compiler/experiments/cranelift/src/main.rs")
CRATE = Path("src/runtime/gust/char_predicates.gst")
CRATE_SOURCE = Path("src/runtime/gust/char_predicates.gst")
SMOKE = Path("compiler/mir_gust_runtime_smoke_test_entry.gst")
PARITY = Path("scripts/phase17_gust_runtime_parity.sh")
WORKFLOW = Path(".github/workflows/phase17-gust-runtime.yml")
TASK = Path("TASK.md")

INITIALIZATION_POLICIES = ("none_required_pure_functions",
                           "explicit_caller_invoked_initializer")
EXPECTED = {
    "semantic_type": {"runtime_gust_module"},
    "query": {"runtime_gust_module_for"},
    "field": {
        "component_id", "exported_symbol_ids", "imported_symbol_ids",
        "allowed_dependency_ids", "runtime_abi_version", "target_applicability",
        "initialization_policy", "failure_policy",
    },
    "initialization_policy": set(INITIALIZATION_POLICIES),
    "rejection": {
        "non_generic_lowering", "missing_runtime_requirement",
        "circular_component_dependency", "abi_or_target_mismatch",
        "hidden_generated_c_compilation",
    },
    "policy": {
        "generic_canonical_mir_route", "no_source_or_module_name_recognition",
        "packaged_as_explicit_component", "stable_witness",
    },
    "boundary": {"reference_module_only"},
}
REASONS = (
    "runtime_gust_non_generic_lowering", "runtime_gust_missing_requirement",
    "runtime_gust_circular_dependency", "runtime_gust_abi_or_target_mismatch",
    "runtime_gust_hidden_generated_c",
)
SOURCE_TOKENS = (
    "type MirRuntimeGustModule", "gust_module_id:", "module_source_path:",
    "allowed_dependency_ids:", "lowering_route:", "initialization_policy:",
    "func mir_runtime_gust_module_id(", "func mir_runtime_gust_module_for(",
    "func mir_runtime_lowering_route_is_valid(",
    "func mir_runtime_initialization_policy_is_valid(",
    "mir_runtime_table_with_gust_module(",
    "runtime_gust_lowering_route", "runtime_gust_source_path",
)
REQUEST_TOKENS = (
    "gust.compiler_gust_runtime.v1", "gust.gust_runtime_witness.v1",
    "func mir_serialize_gust_runtime_request(",
    "func mir_gust_runtime_mir_to_c_witness(",
    "generic_canonical_mir_route_no_bespoke_recognition",
)
WORKER_TOKENS = (
    "pub fn parse_gust_runtime_request(",
    "pub fn render_gust_runtime_witness(",
    "pub fn lower_gust_runtime_witness_path(", "GENERIC_ROUTE",
)
MAIN_TOKENS = ("mod gust_runtime;", '"phase17-gust-runtime-witness"')
CRATE_TOKENS = ("func gust_rt_is_alpha(",)
CRATE_SOURCE_TOKENS = ("func gust_rt_is_digit(", "func gust_rt_is_whitespace(")


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
    authority = registry.get("phase17_gust_runtime_authority")
    if not isinstance(authority, dict):
        fail("canonical registry lacks gust runtime authority")
    expected = {
        "version": "phase17_gust_runtime_authority_v1",
        "status": "ready_for_patch17_9",
        "request_format": "gust.compiler_gust_runtime.v1",
        "witness_format": "gust.gust_runtime_witness.v1",
        "worker_owner": "compiler/experiments/cranelift/src/gust_runtime.rs",
        "module_source_prefix": "src/runtime/gust/",
        "lowering_route": "generic_parse_typecheck_canonical_mir_abi_cranelift",
        "next_patch": "17.9",
    }
    for key, value in expected.items():
        if authority.get(key) != value:
            fail(f"gust runtime metadata drifted: {key}")
    if tuple(authority.get("rejection_classes", ())) != REASONS:
        fail("gust runtime rejection inventory drifted")

    classified = [
        row for row in registry["phase17_runtime_authority"]
        ["helper_classifications"]
        if row["classification"] == "pure_gust_runtime_component"
    ]
    if authority.get("migrated_helper_count") != len(classified):
        fail("migrated helper count disagrees with Patch 17.1 classifications")
    modules = authority.get("selected_modules", [])
    if not modules:
        fail("gust runtime must declare at least one reference module")
    spellings: set[str] = set()
    for row in modules:
        src = row.get("module_source_path", "")
        if not src.startswith("src/runtime/gust/") or not src.endswith(".gst"):
            fail(f"{row.get('component_id')}: source is not a Gust runtime module")
        if not (root / src).is_file():
            fail(f"{row.get('component_id')}: module source does not exist: {src}")
        if row.get("initialization_policy") not in INITIALIZATION_POLICIES:
            fail(f"{row.get('component_id')}: initialization policy undeclared")
        if row.get("component_id") in row.get("allowed_dependencies", []):
            fail(f"{row.get('component_id')}: depends on its own component")
        for spelling in row.get("exported_spellings", []):
            if spelling in spellings:
                fail(f"duplicate exported spelling: {spelling}")
            spellings.add(spelling)
    return authority


def check_source(root: Path) -> None:
    source = text(root / SOURCE)
    for token in (*SOURCE_TOKENS, *REASONS, *INITIALIZATION_POLICIES):
        if token not in source:
            fail(f"gust runtime source is missing: {token}")
    request = text(root / REQUEST_SOURCE)
    for token in REQUEST_TOKENS:
        if token not in request:
            fail(f"gust runtime request module is missing: {token}")
    worker = text(root / WORKER)
    for token in WORKER_TOKENS:
        if token not in worker:
            fail(f"Cranelift gust runtime module is missing: {token}")
    main = text(root / MAIN)
    for token in MAIN_TOKENS:
        if token not in main:
            fail(f"Cranelift worker is missing gust runtime wiring: {token}")
    module = text(root / CRATE)
    for token in CRATE_TOKENS:
        if token not in module:
            fail(f"gust runtime module is missing: {token}")
    crate_source = text(root / CRATE_SOURCE)
    for token in CRATE_SOURCE_TOKENS:
        if token not in crate_source:
            fail(f"gust runtime crate source is missing: {token}")


def check_wiring(root: Path) -> None:
    for path in (SMOKE, PARITY, WORKFLOW, CRATE, CRATE_SOURCE):
        if not (root / path).is_file():
            fail(f"missing required file: {path}")
    workflow = text(root / WORKFLOW)
    for token in (GUARD, PARITY_GUARD,
                  "python3 scripts/phase17_gust_runtime.py --check",
                  "Phase 17.8 gust runtime contract",
                  "Phase 17.8 gust runtime parity"):
        if token not in workflow:
            fail(f"workflow is missing: {token}")
    parity = text(root / PARITY)
    for token in ("phase17-gust-runtime-witness", "cmp -s",
                  "char_predicates", "bespoke recognition"):
        if token not in parity:
            fail(f"parity script is missing: {token}")
    marker = ("- [x] Patch 17.6 — Rust Runtime Components and Native Object "
              "Integration — DONE")
    if marker not in text(root / TASK):
        fail("TASK.md does not mark Patch 17.6 DONE")


def render(contract_rows: list[dict[str, str]], authority: dict) -> str:
    counts = Counter(row["kind"] for row in contract_rows)
    lines = [
        "Phase 17.8 — Pure Gust Runtime Modules Compiled Through MIR",
        f"guard: {GUARD}", f"parity_guard: {PARITY_GUARD}",
        f"test_level: {LEVEL}",
        f"module_source_prefix: {authority['module_source_prefix']}",
        f"lowering_route: {authority['lowering_route']}",
        f"recognition_policy: {authority['recognition_policy']}",
        f"helpers_migrated_from_patch17_1_inventory: {authority['migrated_helper_count']}",
        "", "contract counts:",
    ]
    lines += [f"  {kind}: {counts[kind]}" for kind in sorted(counts)]
    lines += ["", "declared pure Gust runtime modules:"]
    for row in authority["selected_modules"]:
        lines.append(
            f"  {row['component_id']}\t{row['module_source_path']}\t"
            f"{row['initialization_policy']}\t{row['failure_policy']}"
        )
        lines += [f"    export\t{s}" for s in row["exported_spellings"]]
    lines += ["", "rejection classes:"]
    lines += [f"  {value}" for value in authority["rejection_classes"]]
    lines += [
        "", "exit gate:",
        "  every selected pure Gust runtime helper compiles through generic "
        "canonical MIR",
        "  the module is supplied as an explicit native runtime package component",
        "  no bespoke compiler recognition and no generated C glue",
        "  generated C shim elimination remains in Patch 17.9",
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
    print(f"{GUARD}: ok ({len(authority['selected_modules'])} modules, "
          f"{authority['migrated_helper_count']} migrated helpers, {LEVEL})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
