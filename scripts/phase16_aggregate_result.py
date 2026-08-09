#!/usr/bin/env python3
"""Level 1 contract and generated review for Patch 16.4."""

from __future__ import annotations

import argparse
import csv
from collections import Counter
from pathlib import Path

GUARD = "guard-cranelift-phase16-aggregate-return-contract"
PARITY = "guard-cranelift-phase16-aggregate-return-parity"
CONTRACT = Path("tests/cranelift/phase16_aggregate_result_contract.tsv")
REVIEW = Path("tests/cranelift/phase16_aggregate_result_review.txt")


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD}: {message}")


def source(root: Path, path: str) -> str:
    try:
        return (root / path).read_text(encoding="utf-8")
    except FileNotFoundError:
        fail(f"missing required file: {path}")


def require(text: str, tokens: tuple[str, ...], owner: str) -> None:
    for token in tokens:
        if token not in text:
            fail(f"{owner} is missing: {token}")


def rows(root: Path) -> list[dict[str, str]]:
    with (root / CONTRACT).open(encoding="utf-8", newline="") as handle:
        result = list(csv.DictReader(handle, delimiter="\t"))
    schema = {"kind", "id", "owner", "test_level", "disposition"}
    if not result or set(result[0]) != schema:
        fail("contract schema drifted")
    keys: set[tuple[str, str]] = set()
    for row in result:
        key = row["kind"], row["id"]
        if key in keys or row["test_level"] != "level1":
            fail(f"invalid or duplicate contract row: {key}")
        keys.add(key)
    required = {
        ("classification", "direct"), ("classification", "split"),
        ("classification", "hidden_pointer"),
        ("rejection", "missing_hidden_storage"),
        ("rejection", "uninitialized_publication"),
        ("hard_ban", "no_backend_invented_hidden_storage"),
    }
    if not required.issubset(keys):
        fail("required aggregate-result inventory is incomplete")
    return result


def check(root: Path) -> None:
    authority = source(root, "compiler/mir_aggregate_result_abi.gst")
    require(authority, (
        "type MirAggregateResultPlan", "type MirAggregateResultTable",
        "gust.compiler_aggregate_result_abi.v1", "struct_single_i32",
        "struct_pair_i32", "struct_triple_i64", '"direct"', '"split"',
        '"hidden_pointer"', "caller_compiler_plan",
        "return_evaluation_then_phase15_cleanup_then_result_transfer",
        "aggregate_result_missing_hidden_storage",
        "aggregate_result_duplicate_hidden_identity",
        "aggregate_result_wrong_layout_or_alignment",
        "aggregate_result_written_after_terminal",
        "aggregate_result_caller_callee_disagreement",
        "aggregate_result_uninitialized_publication",
        "aggregate_result_backend_invented_storage",
        "mir_aggregate_result_table_validate",
        "mir_serialize_aggregate_result_for_request",
    ), "aggregate result authority")
    require(source(root, "compiler/mir_native_backend_aggregate_result_request.gst"), (
        "MirNativeBackendAggregateResultRequest", "layout_table:",
        "abi_authority:", "aggregate_result_table:",
        "mir_native_backend_aggregate_result_request_is_valid",
    ), "native request")
    require(source(root, "compiler/mir_aggregate_result_abi_mir_to_c.gst"), (
        "mir_aggregate_result_to_c_source", "mir_aggregate_result_table_validate",
        "mir_aggregate_result_mir_to_c_witness",
    ), "MIR-to-C consumer")
    worker = source(root, "compiler/experiments/cranelift/src/aggregate_result_abi.rs")
    require(worker, ("fn parse(", "fn validate(",
        "lower_aggregate_result_witness_path",
        "worker_no_backend_local_aggregate_result_classifier_no_backend_invented_hidden_storage"),
        "Cranelift consumer")
    require(source(root, "compiler/experiments/cranelift/src/main.rs"), (
        "mod aggregate_result_abi;", '"phase16-aggregate-result-witness"'), "Cranelift CLI")
    fixture = source(root, "compiler/mir_aggregate_result_abi_smoke_test_entry.gst")
    require(fixture, ("ResultDirectI32", "ResultPairI32", "ResultTripleI64",
        "aggregate_result_storage:caller:triple",
        "/tmp/gust-phase16-aggregate-result.request",
        "/tmp/gust-phase16-aggregate-result.mir-to-c.witness"), "compiler fixture")
    require(source(root, "scripts/phase16_aggregate_result_parity.sh"), (
        "phase16-aggregate-result-witness", "cmp -s",
        "sentinel: preserve-existing-output", "aggregate_result_missing_hidden_storage",
        "aggregate_result_uninitialized_publication"), "Level 2 parity")
    require(source(root, "scripts/cranelift_test_levels.json"),
        (f'"{GUARD}": 1', f'"{PARITY}": 2'), "test levels")
    require(source(root, "justfile"), (f"{GUARD}:", f"{PARITY}:"), "justfile")
    require(source(root, ".github/workflows/phase16-aggregate-returns.yml"),
        (f"just {GUARD}", f"just {PARITY}"), "focused workflow")
    require(source(root, ".github/workflows/pr-fast.yml"), (f"run: just {GUARD}",), "PR Fast")
    require(source(root, "TASK.md"),
        ("- [x] Patch 16.4 — Aggregate Return Classification and Hidden Result Transport — DONE",),
        "roadmap")


def render(contract_rows: list[dict[str, str]]) -> str:
    counts = Counter(row["kind"] for row in contract_rows)
    lines = [
        "Phase 16.4 — Aggregate Return Classification and Hidden Result Transport",
        f"guard: {GUARD}", f"parity_guard: {PARITY}", "test_level: level1",
        "format: gust.compiler_aggregate_result_abi.v1",
        "inventory: non-resource single-i32, pair-i32, and triple-i64 struct results",
        "classification: direct, split, and explicit hidden-pointer result transport",
        "ordering: evaluate return value, run Phase 15 cleanup, then publish and extract result",
        "boundary: complete platform aggregate-return classification remains deferred",
        "", "counts:",
    ]
    lines.extend(f"  {kind}: {counts[kind]}" for kind in sorted(counts))
    lines.extend(["", "active contract:"])
    lines.extend(f"  {row['kind']}\t{row['id']}\t{row['owner']}\t{row['disposition']}" for row in contract_rows)
    lines.extend(["", "exit gate:",
        "  every selected aggregate result has one compiler-owned placement",
        "  hidden result storage is explicit and equivalent through MIR-to-C and Cranelift", ""])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    contract_rows = rows(root)
    check(root)
    expected = render(contract_rows)
    if args.write:
        (root / REVIEW).write_text(expected, encoding="utf-8")
    elif source(root, str(REVIEW)) != expected:
        fail("generated review is stale; run python3 scripts/phase16_aggregate_result.py --write")
    print(f"{GUARD}: ok ({len(contract_rows)} rows, level1)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
