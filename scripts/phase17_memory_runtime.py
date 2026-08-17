#!/usr/bin/env python3
"""Level 1 contract and reduced review for Phase 17.10 allocation, core-memory, and string audit."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import Counter
from pathlib import Path

GUARD = "guard-cranelift-phase17-memory-runtime-contract"
PARITY_GUARD = "guard-cranelift-phase17-memory-runtime-parity"
LEVEL = "level1"
CONTRACT = Path("tests/cranelift/phase17_memory_runtime_contract.tsv")
REVIEW = Path("tests/cranelift/phase17_memory_runtime_review.txt")
REGISTRY = Path("scripts/cranelift_feature_registry.json")
SOURCE = Path("compiler/mir_runtime_boundary_authority.gst")
REQUEST_SOURCE = Path("compiler/mir_memory_runtime_request.gst")
WORKER = Path("compiler/experiments/cranelift/src/memory_runtime.rs")
MAIN = Path("compiler/experiments/cranelift/src/main.rs")
CRATE = Path("compiler/mir_memory_runtime_request.gst")
CRATE_SOURCE = Path("compiler/mir_memory_runtime_request.gst")
SMOKE = Path("compiler/mir_memory_runtime_smoke_test_entry.gst")
PARITY = Path("scripts/phase17_memory_runtime_parity.sh")
WORKFLOW = Path(".github/workflows/phase17-memory-runtime.yml")
TASK = Path("TASK.md")

OPERATION_KINDS = ("allocate", "deallocate", "reallocate", "memory_copy",
                   "memory_move", "memory_set", "memory_compare",
                   "bounds_or_failure_report", "string_create", "string_length",
                   "string_compare", "string_convert", "string_destroy")
ALLOCATION_DOMAINS = ("host_process_allocator", "caller_owned_arena",
                      "thread_local_scratch", "no_allocation")
OWNERSHIP_TRANSFERS = ("caller_retains_ownership",
                       "ownership_transfers_to_caller",
                       "borrowed_for_call_duration")
EXPECTED = {
    "semantic_type": {"runtime_memory_contract"},
    "query": {"runtime_memory_contract_for"},
    "operation_kind": set(OPERATION_KINDS),
    "allocation_domain": set(ALLOCATION_DOMAINS),
    "ownership_transfer": set(OWNERSHIP_TRANSFERS),
    "rejection": {
        "missing_allocation_helper", "incompatible_allocator_domain",
        "invalid_string_layout", "wrong_symbol_version",
        "unsupported_target_operation", "hidden_generated_c_wrapper",
    },
    "policy": {
        "domain_pairing", "phase14_layout_preserved",
        "phase15_resource_preserved", "intrinsics_are_not_runtime_calls",
        "stable_witness",
    },
    "boundary": {"selected_operations_only"},
}
REASONS = (
    "runtime_memory_missing_allocation_helper",
    "runtime_memory_incompatible_allocator_domain",
    "runtime_memory_invalid_string_layout",
    "runtime_memory_wrong_symbol_version",
    "runtime_memory_unsupported_target_operation",
    "runtime_memory_hidden_generated_c_wrapper",
)
SOURCE_TOKENS = (
    "type MirRuntimeMemoryContract", "operation_kind:", "allocation_domain:",
    "ownership_transfer:", "failure_reporting:",
    "func mir_runtime_memory_contract_id(",
    "func mir_runtime_memory_contract_for(",
    "func mir_runtime_memory_operation_is_valid(",
    "func mir_runtime_allocation_domain_is_valid(",
    "func mir_runtime_ownership_transfer_is_valid(",
    "mir_runtime_table_with_memory_contract(",
    "runtime_memory_allocation_domain", "runtime_memory_ownership_transfer",
)
REQUEST_TOKENS = (
    "gust.compiler_memory_runtime.v1", "gust.memory_runtime_witness.v1",
    "func mir_serialize_memory_runtime_request(",
    "func mir_memory_runtime_mir_to_c_witness(",
    "memory_operations_use_their_classified_explicit_runtime_path",
)
WORKER_TOKENS = (
    "pub fn parse_memory_runtime_request(",
    "pub fn render_memory_runtime_witness(",
    "pub fn lower_memory_runtime_witness_path(", "ALLOCATION_DOMAINS",
)
MAIN_TOKENS = ("mod memory_runtime;", '"phase17-memory-runtime-witness"')


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
    authority = registry.get("phase17_memory_runtime_authority")
    if not isinstance(authority, dict):
        fail("canonical registry lacks memory runtime authority")
    expected = {
        "version": "phase17_memory_runtime_authority_v1",
        "status": "ready_for_patch17_11",
        "request_format": "gust.compiler_memory_runtime.v1",
        "witness_format": "gust.memory_runtime_witness.v1",
        "worker_owner": "compiler/experiments/cranelift/src/memory_runtime.rs",
        "next_patch": "17.11",
    }
    for key, value in expected.items():
        if authority.get(key) != value:
            fail(f"memory runtime metadata drifted: {key}")
    if tuple(authority.get("operation_kinds", ())) != OPERATION_KINDS:
        fail("memory operation inventory drifted")
    if tuple(authority.get("allocation_domains", ())) != ALLOCATION_DOMAINS:
        fail("memory allocation domain inventory drifted")
    if tuple(authority.get("rejection_classes", ())) != REASONS:
        fail("memory rejection inventory drifted")

    classified = {
        row["symbol_identity"]
        for row in registry["phase17_runtime_authority"]
        ["helper_classifications"]
    }
    acquiring, releasing, seen = set(), set(), set()
    for row in authority.get("selected_operations", []):
        symbol = row["symbol_identity"]
        if symbol not in classified:
            fail(f"{symbol}: not a helper Patch 17.1 classified")
        if symbol in seen:
            fail(f"{symbol}: selected twice")
        if row["operation_kind"] in ("allocate", "string_create"):
            acquiring.add(row["allocation_domain"])
        if row["operation_kind"] in ("deallocate", "string_destroy"):
            releasing.add(row["allocation_domain"])
        seen.add(symbol)
    orphaned = releasing - acquiring
    if orphaned:
        fail(f"domains release without acquiring: {sorted(orphaned)}")

    for row in authority.get("deferred_rows", []):
        if row["symbol_identity"] in seen:
            fail(f"{row['symbol_identity']}: both selected and deferred")
        if row["symbol_identity"] not in classified:
            fail(f"{row['symbol_identity']}: defers an unclassified helper")
    return authority


def check_source(root: Path) -> None:
    source = text(root / SOURCE)
    for token in (*SOURCE_TOKENS, *REASONS, *OPERATION_KINDS, *ALLOCATION_DOMAINS):
        if token not in source:
            fail(f"memory runtime source is missing: {token}")
    request = text(root / REQUEST_SOURCE)
    for token in REQUEST_TOKENS:
        if token not in request:
            fail(f"memory runtime request module is missing: {token}")
    worker = text(root / WORKER)
    for token in WORKER_TOKENS:
        if token not in worker:
            fail(f"Cranelift memory runtime module is missing: {token}")
    main = text(root / MAIN)
    for token in MAIN_TOKENS:
        if token not in main:
            fail(f"Cranelift worker is missing memory runtime wiring: {token}")



def check_wiring(root: Path) -> None:
    for path in (SMOKE, PARITY, WORKFLOW, CRATE, CRATE_SOURCE):
        if not (root / path).is_file():
            fail(f"missing required file: {path}")
    workflow = text(root / WORKFLOW)
    for token in (GUARD, PARITY_GUARD,
                  "python3 scripts/phase17_memory_runtime.py --check",
                  "Phase 17.10 memory runtime contract",
                  "Phase 17.10 memory runtime parity"):
        if token not in workflow:
            fail(f"workflow is missing: {token}")
    parity = text(root / PARITY)
    for token in ("phase17-memory-runtime-witness", "cmp -s",
                  "matching release", "domain="):
        if token not in parity:
            fail(f"parity script is missing: {token}")
    marker = ("- [x] Patch 17.6 — Rust Runtime Components and Native Object "
              "Integration — DONE")
    if marker not in text(root / TASK):
        fail("TASK.md does not mark Patch 17.6 DONE")


def render(contract_rows: list[dict[str, str]], authority: dict) -> str:
    counts = Counter(row["kind"] for row in contract_rows)
    lines = [
        "Phase 17.10 — Allocation, String, and Core Memory Runtime Audit",
        f"guard: {GUARD}", f"parity_guard: {PARITY_GUARD}",
        f"test_level: {LEVEL}",
        f"domain_pairing_policy: {authority['domain_pairing_policy']}",
        f"intrinsic_boundary_policy: {authority['intrinsic_boundary_policy']}",
        f"selected_operations: {len(authority['selected_operations'])}",
        "", "contract counts:",
    ]
    lines += [f"  {kind}: {counts[kind]}" for kind in sorted(counts)]
    lines += ["", "selected operations:"]
    lines += [
        f"  {row['symbol_identity']}\t{row['operation_kind']}\t"
        f"{row['allocation_domain']}\t{row['ownership_transfer']}\t"
        f"{row['failure_reporting']}"
        for row in authority["selected_operations"]
    ]
    lines += ["", "concrete deferred rows:"]
    lines += [
        f"  {row['symbol_identity']}\t{row['reason']}\t-> {row['destination_phase']}"
        for row in authority["deferred_rows"]
    ]
    lines += ["", "rejection classes:"]
    lines += [f"  {value}" for value in authority["rejection_classes"]]
    lines += [
        "", "exit gate:",
        "  every selected allocation, core-memory, and string operation uses "
        "its classified explicit runtime path",
        "  memory obtained from one allocation domain is released only through "
        "that domain",
        "  Phase 14 layout and Phase 15 resource obligations are preserved",
        "  I/O, filesystem, and resource audit remains in Patch 17.11",
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
    print(f"{GUARD}: ok ({len(authority['selected_operations'])} operations, "
          f"{len(authority['deferred_rows'])} deferred, {LEVEL})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
