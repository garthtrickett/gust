#!/usr/bin/env python3
"""Level 1 contract and reduced review for Phase 17.12 threading and synchronization audit."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import Counter
from pathlib import Path

GUARD = "guard-cranelift-phase17-thread-runtime-contract"
PARITY_GUARD = "guard-cranelift-phase17-thread-runtime-parity"
LEVEL = "level1"
CONTRACT = Path("tests/cranelift/phase17_thread_runtime_contract.tsv")
REVIEW = Path("tests/cranelift/phase17_thread_runtime_review.txt")
REGISTRY = Path("scripts/cranelift_feature_registry.json")
SOURCE = Path("compiler/mir_runtime_boundary_authority.gst")
REQUEST_SOURCE = Path("compiler/mir_thread_runtime_request.gst")
WORKER = Path("compiler/experiments/cranelift/src/thread_runtime.rs")
MAIN = Path("compiler/experiments/cranelift/src/main.rs")
CRATE = Path("compiler/mir_thread_runtime_request.gst")
CRATE_SOURCE = Path("compiler/mir_thread_runtime_request.gst")
SMOKE = Path("compiler/mir_thread_runtime_smoke_test_entry.gst")
PARITY = Path("scripts/phase17_thread_runtime_parity.sh")
WORKFLOW = Path(".github/workflows/phase17-thread-runtime.yml")
TASK = Path("TASK.md")

THREAD_OPERATIONS = ("mutex_create", "mutex_lock", "mutex_unlock",
                     "channel_create", "channel_send", "channel_receive",
                     "fiber_create", "fiber_destroy", "scheduler_init",
                     "scheduler_destroy", "thread_count_query")
LIFETIME_CONSTRAINTS = ("caller_scoped", "scheduler_owned", "process_lifetime")
CANCELLATION_POLICIES = ("no_cancellation_supported", "cooperative_yield_point")
EXPECTED = {
    "semantic_type": {"runtime_thread_contract"},
    "query": {"runtime_thread_contract_for"},
    "thread_operation": set(THREAD_OPERATIONS),
    "lifetime_constraint": set(LIFETIME_CONSTRAINTS),
    "cancellation_policy": set(CANCELLATION_POLICIES),
    "rejection": {
        "unsupported_target", "missing_thread_runtime_component",
        "abi_or_symbol_version_mismatch", "undeclared_system_library",
        "unsupported_cancellation_or_unwind", "hidden_generated_c_wrapper",
    },
    "policy": {
        "explicit_thread_library_dependency",
        "phase15_ownership_and_cleanup_preserved",
        "scheduler_ordering_is_not_a_stable_oracle",
        "atomics_and_broader_concurrency_deferred", "stable_witness",
    },
    "boundary": {"bounded_inventory_only"},
}
REASONS = (
    "runtime_thread_unsupported_target", "runtime_thread_missing_component",
    "runtime_thread_abi_or_version_mismatch",
    "runtime_thread_undeclared_system_library",
    "runtime_thread_unsupported_cancellation",
    "runtime_thread_hidden_generated_c_wrapper",
)
SOURCE_TOKENS = (
    "type MirRuntimeThreadContract", "thread_operation:",
    "system_library_dependency:", "lifetime_constraint:",
    "cancellation_policy:",
    "func mir_runtime_thread_contract_id(",
    "func mir_runtime_thread_contract_for(",
    "func mir_runtime_thread_operation_is_valid(",
    "func mir_runtime_lifetime_constraint_is_valid(",
    "func mir_runtime_cancellation_policy_is_valid(",
    "mir_runtime_table_with_thread_contract(",
    "runtime_thread_system_library", "runtime_thread_cancellation",
)
REQUEST_TOKENS = (
    "gust.compiler_thread_runtime.v1", "gust.thread_runtime_witness.v1",
    "func mir_serialize_thread_runtime_request(",
    "func mir_thread_runtime_mir_to_c_witness(",
    "thread_operations_use_their_classified_explicit_runtime_path",
)
WORKER_TOKENS = (
    "pub fn parse_thread_runtime_request(",
    "pub fn render_thread_runtime_witness(",
    "pub fn lower_thread_runtime_witness_path(",
    "PERMITTED_SYSTEM_LIBRARIES",
)
MAIN_TOKENS = ("mod thread_runtime;", '"phase17-thread-runtime-witness"')


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
    authority = registry.get("phase17_thread_runtime_authority")
    if not isinstance(authority, dict):
        fail("canonical registry lacks thread runtime authority")
    expected = {
        "version": "phase17_thread_runtime_authority_v1",
        "status": "ready_for_patch17_13",
        "request_format": "gust.compiler_thread_runtime.v1",
        "witness_format": "gust.thread_runtime_witness.v1",
        "worker_owner": "compiler/experiments/cranelift/src/thread_runtime.rs",
        "oracle_policy":
            "scheduler_ordering_is_not_a_stable_oracle_and_is_not_compared",
        "next_patch": "17.13",
    }
    for key, value in expected.items():
        if authority.get(key) != value:
            fail(f"thread runtime metadata drifted: {key}")
    if tuple(authority.get("thread_operations", ())) != THREAD_OPERATIONS:
        fail("thread operation inventory drifted")
    if tuple(authority.get("rejection_classes", ())) != REASONS:
        fail("thread rejection inventory drifted")

    classified = {
        row["symbol_identity"]
        for row in registry["phase17_runtime_authority"]
        ["helper_classifications"]
    }
    permitted = set(authority.get("permitted_system_libraries", []))
    seen = set()
    for row in authority.get("selected_operations", []):
        symbol = row["symbol_identity"]
        if symbol not in classified:
            fail(f"{symbol}: not a helper Patch 17.1 classified")
        if symbol in seen:
            fail(f"{symbol}: selected twice")
        if row["thread_operation"] not in THREAD_OPERATIONS:
            fail(f"{symbol}: operation outside the bounded inventory")
        if row["system_library_dependency"] not in permitted:
            fail(f"{symbol}: {row['system_library_dependency']} is not permitted")
        if row["cancellation_policy"] not in CANCELLATION_POLICIES:
            fail(f"{symbol}: cancellation policy is not claimed by this patch")
        seen.add(symbol)
    for row in authority.get("deferred_rows", []):
        if row["symbol_identity"] in seen:
            fail(f"{row['symbol_identity']}: both selected and deferred")
        if row["symbol_identity"] not in classified:
            fail(f"{row['symbol_identity']}: defers an unclassified helper")
    return authority


def check_source(root: Path) -> None:
    source = text(root / SOURCE)
    for token in (*SOURCE_TOKENS, *REASONS, *THREAD_OPERATIONS, *CANCELLATION_POLICIES):
        if token not in source:
            fail(f"thread runtime source is missing: {token}")
    request = text(root / REQUEST_SOURCE)
    for token in REQUEST_TOKENS:
        if token not in request:
            fail(f"thread runtime request module is missing: {token}")
    worker = text(root / WORKER)
    for token in WORKER_TOKENS:
        if token not in worker:
            fail(f"Cranelift thread runtime module is missing: {token}")
    main = text(root / MAIN)
    for token in MAIN_TOKENS:
        if token not in main:
            fail(f"Cranelift worker is missing thread runtime wiring: {token}")



def check_wiring(root: Path) -> None:
    for path in (SMOKE, PARITY, WORKFLOW, CRATE, CRATE_SOURCE):
        if not (root / path).is_file():
            fail(f"missing required file: {path}")
    workflow = text(root / WORKFLOW)
    for token in (GUARD, PARITY_GUARD,
                  "python3 scripts/phase17_thread_runtime.py --check",
                  "Phase 17.12 thread runtime contract",
                  "Phase 17.12 thread runtime parity"):
        if token not in workflow:
            fail(f"workflow is missing: {token}")
    parity = text(root / PARITY)
    for token in ("phase17-thread-runtime-witness", "cmp -s",
                  "stable oracle", "system_library="):
        if token not in parity:
            fail(f"parity script is missing: {token}")
    marker = ("- [x] Patch 17.6 — Rust Runtime Components and Native Object "
              "Integration — DONE")
    if marker not in text(root / TASK):
        fail("TASK.md does not mark Patch 17.6 DONE")


def render(contract_rows: list[dict[str, str]], authority: dict) -> str:
    counts = Counter(row["kind"] for row in contract_rows)
    lines = [
        "Phase 17.12 — Threading and Synchronization Runtime Audit",
        f"guard: {GUARD}", f"parity_guard: {PARITY_GUARD}",
        f"test_level: {LEVEL}",
        f"system_library_policy: {authority['system_library_policy']}",
        f"oracle_policy: {authority['oracle_policy']}",
        f"selected_operations: {len(authority['selected_operations'])}",
        "", "contract counts:",
    ]
    lines += [f"  {kind}: {counts[kind]}" for kind in sorted(counts)]
    lines += ["", "selected operations:"]
    lines += [
        f"  {row['symbol_identity']}\t{row['thread_operation']}\t"
        f"{row['system_library_dependency']}\t{row['lifetime_constraint']}\t"
        f"{row['cancellation_policy']}\t{row['failure_form']}"
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
        "  every selected threading and synchronization operation uses its "
        "classified explicit runtime path",
        "  a platform thread library is a permitted system import of a "
        "declared package",
        "  scheduler ordering is not a stable oracle and is not compared",
        "  availability, compatibility, and diagnostics remain in Patch 17.13",
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
