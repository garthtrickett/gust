#!/usr/bin/env python3
"""Level 1 contract and reduced review for Patch 16.2 canonical call MIR."""

from __future__ import annotations

import argparse
import csv
from collections import Counter
from pathlib import Path
import sys

GUARD_ID = "guard-cranelift-phase16-call-mir-contract"
PARITY_ID = "guard-cranelift-phase16-call-mir-parity"
CONTRACT = Path("tests/cranelift/phase16_call_mir_contract.tsv")
REVIEW = Path("tests/cranelift/phase16_call_mir_review.txt")

EXPECTED = {
    "operation": {
        "function_abi_declaration", "argument_materialization", "direct_call",
        "result_extraction", "hidden_argument", "hidden_result_storage",
        "post_call_normalization",
    },
    "metadata": {
        "function_abi_id", "call_site_abi_id", "ordered_argument_abi_ids",
        "ordered_result_abi_ids", "target_identity", "calling_convention",
        "source_location",
    },
    "policy": {"evaluation_order", "phase15_resource_transition_preservation"},
    "rejection": {
        "missing_abi_metadata", "argument_count_or_order_mismatch",
        "result_count_mismatch", "unknown_hidden_value",
        "unsupported_calling_convention", "target_mismatch",
        "metadata_signature_disagreement",
    },
    "consumer": {"mir_to_c_canonical_call_operations", "cranelift_canonical_call_operations"},
    "transport": {"native_request_call_mir_table"},
    "hard_ban": {
        "worker_no_source_text_signature_identity",
        "worker_no_symbol_signature_identity",
        "worker_no_c_prototype_signature_identity",
        "worker_no_fixture_name_signature_identity",
    },
    "test": {"level1_call_mir_contract", "level2_call_mir_parity"},
}


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD_ID}: {message}")


def text(root: Path, path: str) -> str:
    try:
        return (root / path).read_text(encoding="utf-8")
    except FileNotFoundError:
        fail(f"missing required file: {path}")


def rows(root: Path) -> list[dict[str, str]]:
    with (root / CONTRACT).open(encoding="utf-8", newline="") as handle:
        result = list(csv.DictReader(handle, delimiter="\t"))
    required = {"kind", "id", "owner", "test_level", "disposition"}
    if not result or set(result[0]) != required:
        fail("contract has an unexpected schema")
    seen: set[tuple[str, str]] = set()
    by_kind: dict[str, set[str]] = {}
    for row in result:
        key = row["kind"], row["id"]
        if key in seen:
            fail(f"duplicate contract row: {key}")
        seen.add(key)
        if row["test_level"] != "level1":
            fail(f"non-Level-1 contract row: {row['id']}")
        by_kind.setdefault(row["kind"], set()).add(row["id"])
    if by_kind != EXPECTED:
        fail(f"contract inventory mismatch: expected {EXPECTED}, got {by_kind}")
    return result


def require(source: str, tokens: tuple[str, ...], owner: str) -> None:
    for token in tokens:
        if token not in source:
            fail(f"{owner} is missing: {token}")


def check_sources(root: Path) -> None:
    call = text(root, "compiler/mir_function_call.gst")
    require(call, (
        "type MirCallOperationKind enum", "FunctionAbiDeclaration", "ArgumentMaterialization",
        "DirectCall", "ResultExtraction", "HiddenArgument", "HiddenResultStorage",
        "PostCallNormalization", "type MirFunctionAbiDeclaration", "type MirCallOperand",
        "type MirCallOperation", "type MirFunctionCallTable",
        "gust.compiler_function_call_mir.v1", "compiler_owned_canonical_call_transport",
        "explicit_function_abi_and_call_plan_ids",
        "source_order_materialization_before_call_then_result_normalization",
        "preserve_compiler_owned_phase15_transition_ids",
        "func mir_function_call_table_validate(", "abi.mir_function_abi_by_id(",
        "abi.mir_abi_call_plan(", "func mir_serialize_function_call_for_request(",
        "func mir_function_call_witness(", "call_mir_missing_abi_metadata",
        "call_mir_argument_count_or_order_mismatch", "call_mir_result_count_mismatch",
        "call_mir_unknown_hidden_value", "call_mir_unsupported_calling_convention",
        "call_mir_target_mismatch", "call_mir_signature_disagreement",
        "resource_transition_id:", "resource_state_before:", "resource_state_after:",
    ), "canonical call MIR")
    for tag in range(7):
        if f"kind.tag == {tag}" not in call:
            fail(f"canonical call operation tag {tag} is not named")

    mir = text(root, "compiler/mir.gst")
    require(mir, (
        'import "mir_function_call.gst" as call_mir;', "CallOperation {",
        "operation: Index[call_mir.MirCallOperation", "AbiCallResult {",
        "func mir_make_stmt_call_operation(", "func mir_make_value_abi_call_result(",
    ), "canonical MIR integration")

    request = text(root, "compiler/mir_native_backend_call_mir_request.gst")
    require(request, (
        "type MirNativeBackendCallMirRequest", "base_request: abi_request.MirNativeBackendAbiRequest",
        "call_mir_table:", "func mir_native_backend_call_mir_request_is_valid(",
        "abi_request.mir_native_backend_abi_request_is_valid(",
        "call_mir.mir_function_call_table_validate(",
        "func mir_serialize_native_backend_call_mir_request(",
        "call_mir.mir_serialize_function_call_for_request(",
        "abi_request.mir_serialize_native_backend_abi_request(",
    ), "native call request")
    if request.find("mir_serialize_function_call_for_request(") > request.find("mir_serialize_native_backend_abi_request("):
        fail("canonical call metadata must serialize before the base ABI request")

    c_consumer = text(root, "compiler/mir_function_call_mir_to_c.gst")
    require(c_consumer, (
        "func mir_function_call_operation_to_c(", "func mir_function_call_to_c_source(",
        "call_mir.mir_function_call_table_validate(", "func mir_function_call_mir_to_c_witness(",
        "call_mir.mir_function_call_witness(",
    ), "MIR-to-C call consumer")
    for tag in range(7):
        if f"operation.operation_kind.tag == {tag}" not in c_consumer:
            fail(f"MIR-to-C does not consume call operation tag {tag}")

    worker = text(root, "compiler/experiments/cranelift/src/function_call_mir.rs")
    main = text(root, "compiler/experiments/cranelift/src/main.rs")
    require(worker, (
        "fn parse_request(", "fn validate(", "fn lower_for_cranelift(",
        "pub fn lower_function_call_mir_witness_path(", "call_mir_missing_abi_metadata",
        "call_mir_argument_count_or_order_mismatch", "call_mir_result_count_mismatch",
        "call_mir_unknown_hidden_value", "call_mir_unsupported_calling_convention",
        "call_mir_target_mismatch", "worker_no_source_text_signature_identity",
        "worker_no_symbol_signature_identity", "worker_no_c_prototype_signature_identity",
        "worker_no_fixture_name_signature_identity",
    ), "Cranelift call consumer")
    require(main, ("mod function_call_mir;", '"phase16-call-mir-witness"'), "Cranelift CLI")
    banned = (
        "signature_from_source_text", "signature_from_symbol", "signature_from_c_prototype",
        "signature_from_fixture_name", "infer_call_signature", "reconstruct_call_signature",
    )
    combined = worker + main
    for token in banned:
        if token in combined:
            fail(f"worker signature hard ban violated: {token}")


def check_wiring(root: Path) -> None:
    fixture = text(root, "compiler/mir_function_call_smoke_test_entry.gst")
    require(fixture, (
        'make_operation("operation:phase16:function-declaration", 0',
        'make_operation("operation:phase16:argument-materialization", 1',
        'make_operation("operation:phase16:direct-call", 2',
        'make_operation("operation:phase16:result-extraction", 3',
        'make_operation("operation:phase16:hidden-argument", 4',
        'make_operation("operation:phase16:hidden-result-storage", 5',
        'make_operation("operation:phase16:post-call-normalization", 6',
        "/tmp/gust-phase16-call-mir.request", "/tmp/gust-phase16-call-mir.mir-to-c.witness",
    ), "call MIR fixture")
    parity = text(root, "scripts/phase16_call_mir_parity.sh")
    require(parity, (
        "phase16-call-mir-witness", "cmp -s", "call_mir_missing_abi_metadata",
        "call_mir_argument_count_or_order_mismatch", "call_mir_result_count_mismatch",
        "call_mir_unknown_hidden_value", "call_mir_unsupported_calling_convention",
        "call_mir_target_mismatch", "sentinel: preserve-existing-output",
    ), "Level 2 parity")
    levels = text(root, "scripts/cranelift_test_levels.json")
    require(levels, (f'"{GUARD_ID}": 1', f'"{PARITY_ID}": 2'), "test-level registry")
    justfile = text(root, "justfile")
    require(justfile, (
        f"{GUARD_ID}:", f"{PARITY_ID}:", "python3 scripts/phase16_call_mir.py --check",
        "bash scripts/phase16_call_mir_parity.sh",
    ), "justfile")
    workflow = text(root, ".github/workflows/phase16-call-mir.yml")
    require(workflow, (
        "Cranelift Phase 16 Call MIR", "Phase 16.2 call MIR contract (Level 1)",
        "Phase 16.2 call MIR parity (Level 2)", f"just {GUARD_ID}", f"just {PARITY_ID}",
    ), "focused workflow")
    pr_fast = text(root, ".github/workflows/pr-fast.yml")
    require(pr_fast, (f"run: just {GUARD_ID}",), "PR Fast Level 1 wiring")
    task = text(root, "TASK.md")
    require(task, ("- [x] Patch 16.2 — Canonical MIR Signature, Call, and Result Transport — DONE",), "roadmap status")
    generic = text(root, "compiler/mir_native_backend_generic_source.gst")
    direct = text(root, "compiler/mir_native_backend_direct_call_source.gst")
    require(generic, ("mir_native_direct_call_source_lower(",), "generic source route")
    require(direct, ("type MirNativeDirectCallFunction", "mir_native_direct_call_emit_bundle("), "real direct-call source producer")


def render(contract_rows: list[dict[str, str]]) -> str:
    counts = Counter(row["kind"] for row in contract_rows)
    lines = [
        "Phase 16.2 — Canonical MIR Signature, Call, and Result Transport",
        f"guard: {GUARD_ID}", f"parity_guard: {PARITY_ID}", "test_level: level1",
        "format: gust.compiler_function_call_mir.v1",
        "inventory: selected direct calls with int, bool, scalar, and already-layout-supported values",
        "authority: explicit compiler ABI and call-plan identities",
        "evaluation: ordered argument materialization before call and result normalization",
        "resource_policy: preserve compiler-owned Phase 15 transition annotations",
        "", "counts:",
    ]
    lines.extend(f"  {kind}: {counts[kind]}" for kind in sorted(counts))
    lines.extend(["", "active contract:"])
    lines.extend(f"  {row['kind']}\t{row['id']}\t{row['owner']}\t{row['disposition']}" for row in contract_rows)
    lines.extend(["", "exit gate:", "  selected calls have one compiler-owned signature and canonical MIR transport", "  MIR-to-C and Cranelift consume identical ordered ABI operation records", ""])
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
    check_sources(root)
    check_wiring(root)
    expected = render(contract_rows)
    if args.write:
        (root / REVIEW).write_text(expected, encoding="utf-8")
    elif text(root, str(REVIEW)) != expected:
        fail("generated review is stale; run python3 scripts/phase16_call_mir.py --write")
    print(f"{GUARD_ID}: ok ({len(contract_rows)} rows, level1)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
