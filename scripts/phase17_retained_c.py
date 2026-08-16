#!/usr/bin/env python3
"""Level 1 contract and reduced review for Phase 17.7 retained C runtime objects."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import Counter
from pathlib import Path

GUARD = "guard-cranelift-phase17-retained-c-runtime-contract"
PARITY_GUARD = "guard-cranelift-phase17-retained-c-runtime-parity"
LEVEL = "level1"
CONTRACT = Path("tests/cranelift/phase17_retained_c_contract.tsv")
REVIEW = Path("tests/cranelift/phase17_retained_c_review.txt")
REGISTRY = Path("scripts/cranelift_feature_registry.json")
SOURCE = Path("compiler/mir_runtime_boundary_authority.gst")
REQUEST_SOURCE = Path("compiler/mir_retained_c_runtime_request.gst")
WORKER = Path("compiler/experiments/cranelift/src/retained_c_runtime.rs")
MAIN = Path("compiler/experiments/cranelift/src/main.rs")
SMOKE = Path("compiler/mir_retained_c_runtime_smoke_test_entry.gst")
PARITY = Path("scripts/phase17_retained_c_runtime_parity.sh")
WORKFLOW = Path(".github/workflows/phase17-retained-c-runtime.yml")
TASK = Path("TASK.md")

RETENTION_REASONS = ("awaiting_pure_gust_migration",
                     "awaiting_rust_component_migration",
                     "host_platform_primitive_no_gust_equivalent")
EXPECTED = {
    "semantic_type": {"runtime_retained_c_component"},
    "query": {"runtime_retained_c_for"},
    "field": {
        "component_id", "owned_source_paths", "exported_symbol_ids",
        "imported_symbol_ids", "runtime_abi_identity", "target_applicability",
        "build_inputs", "retention_reason", "removal_criterion",
    },
    "retention_reason": set(RETENTION_REASONS),
    "rejection": {
        "anonymous_or_unclassified_object", "program_specific_c_generation",
        "unversioned_export", "hidden_target_assumption", "duplicate_provider",
        "direct_linker_inclusion",
    },
    "policy": {
        "independent_compilation", "no_program_derived_c_source",
        "shared_manifest_path", "stable_witness",
    },
    "boundary": {"frozen_retained_inventory"},
}
REASONS = (
    "runtime_retained_c_anonymous_object",
    "runtime_retained_c_program_specific_generation",
    "runtime_retained_c_unversioned_export",
    "runtime_retained_c_hidden_target_assumption",
    "runtime_retained_c_duplicate_provider",
    "runtime_retained_c_direct_linker_inclusion",
)
SOURCE_TOKENS = (
    "type MirRuntimeRetainedCComponent", "retained_component_id:",
    "owned_source_paths:", "build_inputs:", "retention_reason:",
    "removal_criterion:", "destination_phase:",
    "func mir_runtime_retained_c_component_id(",
    "func mir_runtime_retained_c_for(",
    "func mir_runtime_retention_reason_is_valid(",
    "mir_runtime_table_with_retained_c_component(",
    "runtime_retained_c_retention_reason", "runtime_retained_c_destination_phase",
)
REQUEST_TOKENS = (
    "gust.compiler_retained_c_runtime.v1", "gust.retained_c_runtime_witness.v1",
    "func mir_serialize_retained_c_request(",
    "func mir_retained_c_mir_to_c_witness(",
    "separately_compiled_component_no_program_derived_c_source",
)
WORKER_TOKENS = (
    "pub fn parse_retained_c_request(", "pub fn render_retained_c_witness(",
    "pub fn lower_retained_c_witness_path(", "OWNED_SOURCE_PREFIX",
)
MAIN_TOKENS = ("mod retained_c_runtime;", '"phase17-retained-c-witness"')


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
    authority = registry.get("phase17_retained_c_authority")
    if not isinstance(authority, dict):
        fail("canonical registry lacks retained C authority")
    expected = {
        "version": "phase17_retained_c_authority_v1",
        "status": "ready_for_patch17_8",
        "request_format": "gust.compiler_retained_c_runtime.v1",
        "witness_format": "gust.retained_c_runtime_witness.v1",
        "worker_owner": "compiler/experiments/cranelift/src/retained_c_runtime.rs",
        "owned_source_prefix": "src/runtime/",
        "next_patch": "17.8",
    }
    for key, value in expected.items():
        if authority.get(key) != value:
            fail(f"retained C metadata drifted: {key}")
    if tuple(authority.get("rejection_classes", ())) != REASONS:
        fail("retained C rejection inventory drifted")
    if tuple(authority.get("retention_reasons", ())) != RETENTION_REASONS:
        fail("retained C retention reason inventory drifted")

    # The frozen inventory must equal the Patch 17.1 classifications exactly,
    # so retained C can shrink over later patches but never quietly grow.
    classified: dict[str, int] = {}
    for row in registry["phase17_runtime_authority"]["helper_classifications"]:
        if row["classification"] == "retained_c_runtime_component":
            classified[row["component_id"]] = classified.get(row["component_id"], 0) + 1
    components = authority.get("retained_components", [])
    if {r.get("component_id") for r in components} != set(classified):
        fail("retained C component coverage drifted")
    if authority.get("retained_helper_count") != sum(classified.values()):
        fail("retained C helper count disagrees with Patch 17.1")
    for row in components:
        cid = row["component_id"]
        if row.get("helper_count") != classified[cid]:
            fail(f"{cid}: helper count disagrees with Patch 17.1")
        if row.get("retention_reason") not in RETENTION_REASONS:
            fail(f"{cid}: retention reason is not justified")
        source = row.get("owned_source_path", "")
        if (not source.startswith("src/runtime/") or "generated" in source
                or "build/" in source):
            fail(f"{cid}: owned source is not a repository runtime file")
        if not (root / source).is_file():
            fail(f"{cid}: owned source does not exist: {source}")
        if not str(row.get("destination_phase", "")).startswith("17."):
            fail(f"{cid}: destination phase is not a Phase 17 patch")
    return authority


def check_source(root: Path) -> None:
    source = text(root / SOURCE)
    for token in (*SOURCE_TOKENS, *REASONS, *RETENTION_REASONS):
        if token not in source:
            fail(f"retained C runtime source is missing: {token}")
    request = text(root / REQUEST_SOURCE)
    for token in REQUEST_TOKENS:
        if token not in request:
            fail(f"retained C runtime request module is missing: {token}")
    worker = text(root / WORKER)
    for token in WORKER_TOKENS:
        if token not in worker:
            fail(f"Cranelift retained C runtime module is missing: {token}")
    main = text(root / MAIN)
    for token in MAIN_TOKENS:
        if token not in main:
            fail(f"Cranelift worker is missing retained C runtime wiring: {token}")


def check_wiring(root: Path) -> None:
    for path in (SMOKE, PARITY, WORKFLOW):
        if not (root / path).is_file():
            fail(f"missing required file: {path}")
    workflow = text(root / WORKFLOW)
    for token in (GUARD, PARITY_GUARD,
                  "python3 scripts/phase17_retained_c.py --check",
                  "Phase 17.7 retained C runtime contract",
                  "Phase 17.7 retained C runtime parity"):
        if token not in workflow:
            fail(f"workflow is missing: {token}")
    parity = text(root / PARITY)
    for token in ("phase17-retained-c-witness", "cmp -s", "cc -O2",
                  "core_headers.h"):
        if token not in parity:
            fail(f"parity script is missing: {token}")
    marker = ("- [x] Patch 17.6 — Rust Runtime Components and Native Object "
              "Integration — DONE")
    if marker not in text(root / TASK):
        fail("TASK.md does not mark Patch 17.6 DONE")


def render(contract_rows: list[dict[str, str]], authority: dict) -> str:
    counts = Counter(row["kind"] for row in contract_rows)
    lines = [
        "Phase 17.7 — Explicit Retained C Runtime Objects",
        f"guard: {GUARD}", f"parity_guard: {PARITY_GUARD}",
        f"test_level: {LEVEL}",
        f"request_format: {authority['request_format']}",
        f"witness_format: {authority['witness_format']}",
        f"linkage_policy: {authority['linkage_policy']}",
        f"generation_policy: {authority['generation_policy']}",
        f"retained_helper_count: {authority['retained_helper_count']}",
        "", "contract counts:",
    ]
    lines += [f"  {kind}: {counts[kind]}" for kind in sorted(counts)]
    lines += ["", "frozen retained C inventory:"]
    for row in sorted(authority["retained_components"], key=lambda r: r["component_id"]):
        lines.append(
            f"  {row['component_id']}\t{row['helper_count']}\t"
            f"{row['owned_source_path']}\t{row['retention_reason']}\t"
            f"-> {row['destination_phase']}"
        )
    lines += ["", "rejection classes:"]
    lines += [f"  {value}" for value in authority["rejection_classes"]]
    lines += [
        "", "exit gate:",
        "  every retained C implementation is a separately compiled, versioned, "
        "target-scoped component",
        "  no retained C source is generated from the compiled program",
        "  no retained C is used as an implicit Cranelift shim",
        "  pure Gust runtime modules remain in Patch 17.8",
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
    print(f"{GUARD}: ok ({len(authority['retained_components'])} components, "
          f"{authority['retained_helper_count']} retained helpers, {LEVEL})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
