#!/usr/bin/env python3
"""Level 1 contract and generated review for Patch 16.5."""
from __future__ import annotations
import argparse, csv
from collections import Counter
from pathlib import Path

GUARD = "guard-cranelift-phase16-direct-call-agreement-contract"
PARITY = "guard-cranelift-phase16-direct-call-agreement-parity"
CONTRACT = Path("tests/cranelift/phase16_direct_call_agreement_contract.tsv")
REVIEW = Path("tests/cranelift/phase16_direct_call_agreement_review.txt")
def fail(message: str) -> None: raise SystemExit(f"{GUARD}: {message}")
def source(root: Path, path: str) -> str:
    try: return (root / path).read_text(encoding="utf-8")
    except FileNotFoundError: fail(f"missing required file: {path}")
def require(text: str, tokens: tuple[str, ...], owner: str) -> None:
    for token in tokens:
        if token not in text: fail(f"{owner} is missing: {token}")
def load_rows(root: Path) -> list[dict[str, str]]:
    with (root / CONTRACT).open(encoding="utf-8", newline="") as handle: rows = list(csv.DictReader(handle, delimiter="\t"))
    if not rows or set(rows[0]) != {"kind", "id", "owner", "test_level", "disposition"}: fail("contract schema drifted")
    seen = set()
    for row in rows:
        key = row["kind"], row["id"]
        if key in seen or row["test_level"] != "level1": fail(f"invalid contract row: {key}")
        seen.add(key)
    return rows
def check(root: Path) -> None:
    authority = source(root, "compiler/mir_direct_call_agreement.gst")
    require(authority, ("type MirDirectCallAgreement", "type MirDirectCallAgreementTable", "gust.compiler_direct_call_agreement.v1", "nested_direct", "direct_recursion", "mixed_scalar_aggregate", "aggregate_result_chain", "mir_function_abi_by_id", "mir_abi_call_plan", "mir_function_call_declaration_by_abi", "direct_call_signature_drift", "direct_call_stale_plan", "direct_call_parameter_permutation", "direct_call_result_permutation", "direct_call_layout_mismatch", "direct_call_calling_convention_mismatch", "direct_call_target_mismatch", "direct_call_hidden_result_mismatch", "direct_call_resource_transfer_mismatch", "mir_direct_call_agreement_table_validate", "mir_serialize_direct_call_agreement_for_request"), "direct-call authority")
    require(source(root, "compiler/mir_native_backend_direct_call_agreement_request.gst"), ("MirNativeBackendDirectCallAgreementRequest", "base_request:", "direct_call_table:", "mir_native_backend_direct_call_agreement_request_is_valid"), "native request")
    require(source(root, "compiler/mir_direct_call_agreement_mir_to_c.gst"), ("mir_direct_call_mir_to_c_witness",), "MIR-to-C consumer")
    require(source(root, "compiler/experiments/cranelift/src/direct_call_agreement.rs"), ("fn validate(", "lower_direct_call_agreement_witness_path", "worker_consumes_compiler_direct_call_agreement_no_backend_signature_or_placement_reconstruction"), "Cranelift consumer")
    require(source(root, "compiler/experiments/cranelift/src/main.rs"), ("mod direct_call_agreement;", '"phase16-direct-call-agreement-witness"'), "Cranelift CLI")
    require(source(root, "compiler/mir_direct_call_agreement_smoke_test_entry.gst"), ("agreement:nested", "agreement:recursive", "agreement:mixed", "agreement:chain", "producer_result_to_consumer_argument", "/tmp/gust-phase16-direct-call-agreement.request"), "compiler fixture")
    require(source(root, "scripts/phase16_direct_call_agreement_parity.sh"), ("phase16-direct-call-agreement-witness", "cmp -s", "sentinel: preserve-existing-output", "direct_call_signature_drift", "direct_call_resource_transfer_mismatch"), "Level 2 parity")
    require(source(root, "scripts/cranelift_test_levels.json"), (f'"{GUARD}": 1', f'"{PARITY}": 2'), "test levels")
    require(source(root, "justfile"), (f"{GUARD}:", f"{PARITY}:"), "justfile")
    require(source(root, ".github/workflows/phase16-direct-call-agreement.yml"), (f"just {GUARD}", f"just {PARITY}"), "workflow")
    require(source(root, ".github/workflows/pr-fast.yml"), (f"run: just {GUARD}",), "PR Fast")
    require(source(root, "TASK.md"), ("- [x] Patch 16.5 — Caller/Callee Placement and Direct-Call Agreement — DONE",), "roadmap")
def render(rows: list[dict[str, str]]) -> str:
    counts = Counter(row["kind"] for row in rows)
    lines = ["Phase 16.5 — Caller/Callee Placement and Direct-Call Agreement", f"guard: {GUARD}", f"parity_guard: {PARITY}", "test_level: level1", "format: gust.compiler_direct_call_agreement.v1", "inventory: same-module nested, recursive, mixed scalar/aggregate, and aggregate-result-chain direct calls", "authority: compiler compares declaration, definition, call plan, placements, layouts, hidden values, and resource disposition", "", "counts:"]
    lines.extend(f"  {kind}: {counts[kind]}" for kind in sorted(counts)); lines.extend(["", "active contract:"])
    lines.extend(f"  {row['kind']}\t{row['id']}\t{row['owner']}\t{row['disposition']}" for row in rows)
    lines.extend(["", "exit gate:", "  every selected direct call has one compiler-owned compatibility decision", "  caller/callee ABI drift is rejected before worker or artifact access", ""]); return "\n".join(lines)
def main() -> int:
    parser = argparse.ArgumentParser(); parser.add_argument("--root", type=Path, default=Path.cwd()); mode = parser.add_mutually_exclusive_group(required=True); mode.add_argument("--write", action="store_true"); mode.add_argument("--check", action="store_true")
    args = parser.parse_args(); root = args.root.resolve(); rows = load_rows(root); check(root); expected = render(rows)
    if args.write: (root / REVIEW).write_text(expected, encoding="utf-8")
    elif source(root, str(REVIEW)) != expected: fail("generated review is stale; run python3 scripts/phase16_direct_call_agreement.py --write")
    print(f"{GUARD}: ok ({len(rows)} rows, level1)"); return 0
if __name__ == "__main__": raise SystemExit(main())
