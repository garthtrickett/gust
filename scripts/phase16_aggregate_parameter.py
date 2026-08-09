#!/usr/bin/env python3
"""Level 1 contract and reduced review for Patch 16.3."""

from __future__ import annotations

import argparse
import csv
from collections import Counter
from pathlib import Path
import sys

GUARD = "guard-cranelift-phase16-aggregate-parameter-contract"
PARITY = "guard-cranelift-phase16-aggregate-parameter-parity"
CONTRACT = Path("tests/cranelift/phase16_aggregate_parameter_contract.tsv")
REVIEW = Path("tests/cranelift/phase16_aggregate_parameter_review.txt")

EXPECTED = {
    "classification": {"direct", "split", "indirect_by_value"},
    "metadata": {"canonical_type_id", "layout_id", "abi_value_id", "logical_locations", "caller_materialization", "callee_materialization", "padding_policy", "copy_move_disposition"},
    "policy": {"initialized_fields_only", "padding_not_semantic", "non_resource_copy_only", "resource_bearing_deferred_to_16_10"},
    "rejection": {"unsupported_shape", "invalid_layout_identity", "illegal_split_boundary", "insufficient_alignment", "overlapping_placements", "caller_callee_disagreement", "move_only_copy", "argument_order_mismatch"},
    "consumer": {"mir_to_c_compiler_plan", "cranelift_compiler_plan"},
    "transport": {"native_request_aggregate_parameter_table"},
    "hard_ban": {"no_backend_local_classifier", "no_source_or_generated_c_inference"},
    "test": {"level1_aggregate_parameter_contract", "level2_aggregate_parameter_parity"},
}


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


def contract_rows(root: Path) -> list[dict[str, str]]:
    with (root / CONTRACT).open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    if not rows or set(rows[0]) != {"kind", "id", "owner", "test_level", "disposition"}:
        fail("contract schema drifted")
    actual: dict[str, set[str]] = {}
    seen: set[tuple[str, str]] = set()
    for row in rows:
        key = row["kind"], row["id"]
        if key in seen:
            fail(f"duplicate row: {key}")
        seen.add(key)
        if row["test_level"] != "level1":
            fail(f"non-Level-1 contract row: {row['id']}")
        actual.setdefault(row["kind"], set()).add(row["id"])
    if actual != EXPECTED:
        fail(f"contract inventory mismatch: {actual}")
    return rows


def check_sources(root: Path) -> None:
    authority = source(root, "compiler/mir_aggregate_parameter_abi.gst")
    require(authority, (
        "type MirAggregateParameterLocation", "type MirAggregateParameterPlan", "type MirAggregateParameterTable",
        "gust.compiler_aggregate_parameter_abi.v1", "compiler_owned_aggregate_parameter_classifier",
        "struct_single_i32", "struct_pair_i32", "struct_triple_i64", '"direct"', '"split"', '"indirect_by_value"',
        "canonical_type_id", "layout_id", "abi_value_id", "caller_materialization", "callee_materialization",
        "initialized_fields_only_padding_not_semantic", "non_resource_copy_only_resource_bearing_aggregate_calls_deferred_to_phase16_10",
        "mir_layout_table_is_valid", "mir_abi_classification_by_id", "mir_aggregate_parameter_placement_by_id",
        "func mir_aggregate_parameter_table_validate", "func mir_serialize_aggregate_parameter_for_request",
        "aggregate_parameter_unsupported_shape", "aggregate_parameter_invalid_layout_identity",
        "aggregate_parameter_illegal_split_boundary", "aggregate_parameter_insufficient_alignment",
        "aggregate_parameter_overlapping_placements", "aggregate_parameter_caller_callee_disagreement",
        "aggregate_parameter_move_only_copy_rejected", "aggregate_parameter_argument_order_mismatch",
    ), "aggregate parameter authority")
    request = source(root, "compiler/mir_native_backend_aggregate_parameter_request.gst")
    require(request, ("MirNativeBackendAggregateParameterRequest", "layout_table:", "abi_authority:", "aggregate_parameter_table:", "mir_native_backend_aggregate_parameter_request_is_valid", "mir_serialize_native_backend_aggregate_parameter_request"), "native request")
    c_consumer = source(root, "compiler/mir_aggregate_parameter_abi_mir_to_c.gst")
    require(c_consumer, ("mir_aggregate_parameter_to_c_source", "mir_aggregate_parameter_table_validate", "mir_aggregate_parameter_mir_to_c_witness"), "MIR-to-C consumer")
    worker = source(root, "compiler/experiments/cranelift/src/aggregate_parameter_abi.rs")
    main = source(root, "compiler/experiments/cranelift/src/main.rs")
    require(worker, ("fn parse(", "fn validate(", "lower_aggregate_parameter_witness_path", "worker_no_backend_local_aggregate_parameter_classifier_no_source_text_no_generated_c_no_host_abi_guess"), "Cranelift consumer")
    require(main, ("mod aggregate_parameter_abi;", '"phase16-aggregate-parameter-witness"'), "Cranelift CLI")
    for banned in ("classify_with_host_abi", "infer_aggregate_parameter", "layout_from_generated_c", "aggregate_signature_from_source"):
        if banned in worker + main:
            fail(f"backend-local aggregate classifier hard ban violated: {banned}")


def check_wiring(root: Path) -> None:
    fixture = source(root, "compiler/mir_aggregate_parameter_abi_smoke_test_entry.gst")
    require(fixture, ("struct_single_i32", "struct_pair_i32", "struct_triple_i64", "canonical_value", "split_initialized_fields", "caller_owned_readonly_slot", "/tmp/gust-phase16-aggregate-parameter.request", "/tmp/gust-phase16-aggregate-parameter.mir-to-c.witness"), "compiler fixture")
    parity = source(root, "scripts/phase16_aggregate_parameter_parity.sh")
    require(parity, ("phase16-aggregate-parameter-witness", "cmp -s", "sentinel: preserve-existing-output", "aggregate_parameter_move_only_copy_rejected", "aggregate_parameter_overlapping_placements"), "Level 2 parity")
    levels = source(root, "scripts/cranelift_test_levels.json")
    require(levels, (f'"{GUARD}": 1', f'"{PARITY}": 2'), "test levels")
    justfile = source(root, "justfile")
    require(justfile, (f"{GUARD}:", f"{PARITY}:", "python3 scripts/phase16_aggregate_parameter.py --check", "bash scripts/phase16_aggregate_parameter_parity.sh"), "justfile")
    workflow = source(root, ".github/workflows/phase16-aggregate-parameters.yml")
    require(workflow, ("Cranelift Phase 16 Aggregate Parameters", f"just {GUARD}", f"just {PARITY}"), "focused workflow")
    require(source(root, ".github/workflows/pr-fast.yml"), (f"run: just {GUARD}",), "PR Fast")
    require(source(root, "TASK.md"), ("- [x] Patch 16.3 — Aggregate Parameter Classification and Passing — DONE",), "roadmap")


def render(rows: list[dict[str, str]]) -> str:
    counts = Counter(row["kind"] for row in rows)
    lines = [
        "Phase 16.3 — Aggregate Parameter Classification and Passing",
        f"guard: {GUARD}", f"parity_guard: {PARITY}", "test_level: level1",
        "format: gust.compiler_aggregate_parameter_abi.v1",
        "inventory: non-resource single-i32, pair-i32, and triple-i64 structs",
        "classification: direct, split, and indirect-by-value compiler plans",
        "padding: initialized fields only; padding bytes are not semantic values",
        "resource_boundary: resource-bearing aggregate calls remain deferred to Phase 16.10",
        "", "counts:",
    ]
    lines.extend(f"  {kind}: {counts[kind]}" for kind in sorted(counts))
    lines.extend(["", "active contract:"])
    lines.extend(f"  {row['kind']}\t{row['id']}\t{row['owner']}\t{row['disposition']}" for row in rows)
    lines.extend(["", "exit gate:", "  every selected aggregate parameter has one compiler-owned classification and placement", "  MIR-to-C and Cranelift consume identical logical locations and initialized-field witnesses", ""])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    rows = contract_rows(root)
    check_sources(root)
    check_wiring(root)
    expected = render(rows)
    if args.write:
        (root / REVIEW).write_text(expected, encoding="utf-8")
    elif source(root, str(REVIEW)) != expected:
        fail("generated review is stale; run python3 scripts/phase16_aggregate_parameter.py --write")
    print(f"{GUARD}: ok ({len(rows)} rows, level1)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
