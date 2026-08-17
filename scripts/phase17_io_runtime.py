#!/usr/bin/env python3
"""Level 1 contract and reduced review for Phase 17.11 I/O, filesystem, and resource audit."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import Counter
from pathlib import Path

GUARD = "guard-cranelift-phase17-io-runtime-contract"
PARITY_GUARD = "guard-cranelift-phase17-io-runtime-parity"
LEVEL = "level1"
CONTRACT = Path("tests/cranelift/phase17_io_runtime_contract.tsv")
REVIEW = Path("tests/cranelift/phase17_io_runtime_review.txt")
REGISTRY = Path("scripts/cranelift_feature_registry.json")
SOURCE = Path("compiler/mir_runtime_boundary_authority.gst")
REQUEST_SOURCE = Path("compiler/mir_io_runtime_request.gst")
WORKER = Path("compiler/experiments/cranelift/src/io_runtime.rs")
MAIN = Path("compiler/experiments/cranelift/src/main.rs")
CRATE = Path("compiler/mir_io_runtime_request.gst")
CRATE_SOURCE = Path("compiler/mir_io_runtime_request.gst")
SMOKE = Path("compiler/mir_io_runtime_smoke_test_entry.gst")
PARITY = Path("scripts/phase17_io_runtime_parity.sh")
WORKFLOW = Path(".github/workflows/phase17-io-runtime.yml")
TASK = Path("TASK.md")

IO_KINDS = ("standard_stream", "file_or_stream", "path_or_filesystem",
            "directory_resource", "environment_query", "target_query",
            "c_string_marshalling")
RESOURCE_TRANSITIONS = ("not_a_resource", "acquires", "uses_borrowed", "closes")
FILESYSTEM_EFFECTS = ("none", "reads_filesystem", "writes_filesystem",
                      "removes_path")
EXPECTED = {
    "semantic_type": {"runtime_io_contract"},
    "query": {"runtime_io_contract_for"},
    "io_kind": set(IO_KINDS),
    "resource_transition": set(RESOURCE_TRANSITIONS),
    "filesystem_effect": set(FILESYSTEM_EFFECTS),
    "rejection": {
        "missing_or_incompatible_symbol", "wrong_resource_kind",
        "close_mismatch", "duplicate_close",
        "unsupported_target_or_availability", "hidden_generated_c_wrapper",
    },
    "policy": {
        "close_pairing", "manual_close_and_deferred_cleanup_agree",
        "phase15_resource_identities_mapped",
        "sockets_processes_terminals_deferred", "stable_witness",
    },
    "boundary": {"selected_operations_only"},
}
REASONS = (
    "runtime_io_missing_symbol", "runtime_io_wrong_resource_kind",
    "runtime_io_close_mismatch", "runtime_io_duplicate_close",
    "runtime_io_unsupported_target", "runtime_io_hidden_generated_c_wrapper",
)
SOURCE_TOKENS = (
    "type MirRuntimeIoContract", "io_kind:", "resource_kind:",
    "resource_transition:", "filesystem_effect:", "close_operation_id:",
    "func mir_runtime_io_contract_id(", "func mir_runtime_io_contract_for(",
    "func mir_runtime_io_kind_is_valid(",
    "func mir_runtime_resource_transition_is_valid(",
    "func mir_runtime_filesystem_effect_is_valid(",
    "mir_runtime_table_with_io_contract(",
    "runtime_io_resource_transition", "runtime_io_filesystem_effect",
)
REQUEST_TOKENS = (
    "gust.compiler_io_runtime.v1", "gust.io_runtime_witness.v1",
    "func mir_serialize_io_runtime_request(",
    "func mir_io_runtime_mir_to_c_witness(",
    "io_operations_use_their_classified_explicit_runtime_path",
)
WORKER_TOKENS = (
    "pub fn parse_io_runtime_request(",
    "pub fn render_io_runtime_witness(",
    "pub fn lower_io_runtime_witness_path(", "RESOURCE_TRANSITIONS",
)
MAIN_TOKENS = ("mod io_runtime;", '"phase17-io-runtime-witness"')


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
    authority = registry.get("phase17_io_runtime_authority")
    if not isinstance(authority, dict):
        fail("canonical registry lacks io runtime authority")
    expected = {
        "version": "phase17_io_runtime_authority_v1",
        "status": "ready_for_patch17_12",
        "request_format": "gust.compiler_io_runtime.v1",
        "witness_format": "gust.io_runtime_witness.v1",
        "worker_owner": "compiler/experiments/cranelift/src/io_runtime.rs",
        "next_patch": "17.12",
    }
    for key, value in expected.items():
        if authority.get(key) != value:
            fail(f"io runtime metadata drifted: {key}")
    if tuple(authority.get("io_kinds", ())) != IO_KINDS:
        fail("io kind inventory drifted")
    if tuple(authority.get("rejection_classes", ())) != REASONS:
        fail("io rejection inventory drifted")

    classified = {
        row["symbol_identity"]
        for row in registry["phase17_runtime_authority"]
        ["helper_classifications"]
    }
    acquired, closed, seen = set(), {}, set()
    for row in authority.get("selected_operations", []):
        symbol = row["symbol_identity"]
        if symbol not in classified:
            fail(f"{symbol}: not a helper Patch 17.1 classified")
        if symbol in seen:
            fail(f"{symbol}: selected twice")
        is_resource = row["resource_kind"] != "none"
        if is_resource == (row["resource_transition"] == "not_a_resource"):
            fail(f"{symbol}: resource kind disagrees with its transition")
        if row["resource_transition"] == "acquires":
            acquired.add(row["resource_kind"])
        if row["resource_transition"] == "closes":
            closed[row["resource_kind"]] = closed.get(row["resource_kind"], 0) + 1
        seen.add(symbol)
    for kind in sorted(acquired):
        if closed.get(kind, 0) != 1:
            fail(f"resource kind {kind} acquired but closed {closed.get(kind,0)} times")
    for kind, count in sorted(closed.items()):
        if count != 1:
            fail(f"resource kind {kind} has {count} closers")
    for row in authority.get("deferred_rows", []):
        if row["symbol_identity"] in seen:
            fail(f"{row['symbol_identity']}: both selected and deferred")
        if row["symbol_identity"] not in classified:
            fail(f"{row['symbol_identity']}: defers an unclassified helper")
    return authority


def check_source(root: Path) -> None:
    source = text(root / SOURCE)
    for token in (*SOURCE_TOKENS, *REASONS, *IO_KINDS, *RESOURCE_TRANSITIONS):
        if token not in source:
            fail(f"io runtime source is missing: {token}")
    request = text(root / REQUEST_SOURCE)
    for token in REQUEST_TOKENS:
        if token not in request:
            fail(f"io runtime request module is missing: {token}")
    worker = text(root / WORKER)
    for token in WORKER_TOKENS:
        if token not in worker:
            fail(f"Cranelift io runtime module is missing: {token}")
    main = text(root / MAIN)
    for token in MAIN_TOKENS:
        if token not in main:
            fail(f"Cranelift worker is missing io runtime wiring: {token}")



def check_wiring(root: Path) -> None:
    for path in (SMOKE, PARITY, WORKFLOW, CRATE, CRATE_SOURCE):
        if not (root / path).is_file():
            fail(f"missing required file: {path}")
    workflow = text(root / WORKFLOW)
    for token in (GUARD, PARITY_GUARD,
                  "python3 scripts/phase17_io_runtime.py --check",
                  "Phase 17.11 io runtime contract",
                  "Phase 17.11 io runtime parity"):
        if token not in workflow:
            fail(f"workflow is missing: {token}")
    parity = text(root / PARITY)
    for token in ("phase17-io-runtime-witness", "cmp -s",
                  "exactly one close", "transition="):
        if token not in parity:
            fail(f"parity script is missing: {token}")
    marker = ("- [x] Patch 17.6 — Rust Runtime Components and Native Object "
              "Integration — DONE")
    if marker not in text(root / TASK):
        fail("TASK.md does not mark Patch 17.6 DONE")


def render(contract_rows: list[dict[str, str]], authority: dict) -> str:
    counts = Counter(row["kind"] for row in contract_rows)
    lines = [
        "Phase 17.11 — I/O, Filesystem, and Resource Runtime Audit",
        f"guard: {GUARD}", f"parity_guard: {PARITY_GUARD}",
        f"test_level: {LEVEL}",
        f"close_pairing_policy: {authority['close_pairing_policy']}",
        f"scope_selection_rule: {authority['scope_selection_rule']}",
        f"selected_operations: {len(authority['selected_operations'])}",
        "", "contract counts:",
    ]
    lines += [f"  {kind}: {counts[kind]}" for kind in sorted(counts)]
    lines += ["", "selected operations:"]
    lines += [
        f"  {row['symbol_identity']}\t{row['io_kind']}\t{row['resource_kind']}\t"
        f"{row['resource_transition']}\t{row['failure_form']}\t"
        f"{row['filesystem_effect']}"
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
        "  every selected I/O, filesystem, directory, and resource operation "
        "uses its classified explicit runtime path",
        "  an acquired resource kind has exactly one close",
        "  manual close and deferred cleanup name the same runtime operation",
        "  threading and synchronization audit remains in Patch 17.12",
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
