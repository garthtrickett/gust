#!/usr/bin/env python3
from __future__ import annotations
import argparse, csv
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
GUARD="guard-cranelift-phase15-early-return-cleanup-contract"
CONTRACT=Path("tests/cranelift/phase15_early_return_cleanup_contract.tsv")
REVIEW=Path("tests/cranelift/phase15_early_return_cleanup_review.txt")

FILES={
"model":Path("compiler/mir_early_exit_cleanup.gst"),
"fixture":Path("compiler/mir_early_exit_cleanup_parity_smoke_test_entry.gst"),
"state":Path("compiler/mir_early_exit_cleanup_state_smoke_test_entry.gst"),
"worker":Path("compiler/experiments/cranelift/src/early_return_cleanup.rs"),
"main":Path("compiler/experiments/cranelift/src/main.rs"),
"parity":Path("scripts/phase15_early_return_cleanup_parity.sh"),
"workflow":Path(".github/workflows/phase15-early-return-cleanup.yml"),
"levels":Path("scripts/cranelift_test_levels.json"),
"justfile":Path("justfile"),
}

TOKENS=(
"direct_return","nested_conditional_return","selected_loop_return","selected_break","selected_continue",
"inner_scope_before_outer_scope_then_reverse_declaration_order",
"early_return_cleanup_missing","early_return_cleanup_after_terminator",
"early_return_cleanup_duplicate_shared_edge","early_return_cleanup_resource_not_in_exited_scope",
"early_return_cleanup_non_live_resource","early_return_cleanup_return_order_invalid",
"early_return_cleanup_inner_outer_order_invalid","early_return_cleanup_aggregate_return_deferred",
"deferred_to_phase16","return_value_evaluated_before_cleanup=1","output_preserved=1",
)

def fail(msg): raise SystemExit(f"{GUARD}: {msg}")
def read(path):
    full=ROOT/path
    if not full.is_file() or full.is_symlink(): fail(f"missing regular file {path}")
    return full.read_text()
def load():
    with (ROOT/CONTRACT).open(newline="") as f: rows=list(csv.DictReader(f,delimiter="\t"))
    if len(rows)!=40: fail(f"expected 40 contract rows, got {len(rows)}")
    if set(rows[0])!={"kind","requirement","evidence","level"}: fail("bad header")
    if any(row["level"]!="1" for row in rows): fail("all rows must be Level 1")
    return rows
def render(rows):
    lines=["Patch 15.6 — Cleanup at Early Returns and Structured Exits",""]
    for row in rows: lines.append(f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}")
    return "\n".join(lines)+"\n"
def check():
    rows=load()
    combined="\n".join(read(path) for path in FILES.values())
    for token in TOKENS:
        if token not in combined: fail(f"missing token {token}")
    for token in (
        "guard-cranelift-phase15-early-return-cleanup-contract:",
        "guard-cranelift-phase15-early-return-cleanup-parity:",
        "python3 scripts/phase15_early_return_cleanup.py --check",
        "bash scripts/phase15_early_return_cleanup_parity.sh",
    ):
        if token not in read(FILES["justfile"]): fail(f"justfile missing {token}")
    review=ROOT/REVIEW
    expected=render(rows)
    if not review.is_file() or review.read_text()!=expected: fail(f"{REVIEW} is stale; run with --write")
    return rows
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--check",action="store_true")
    parser.add_argument("--write",action="store_true")
    args=parser.parse_args()
    if args.write:
        rows=load(); (ROOT/REVIEW).write_text(render(rows))
    rows=check()
    print(f"{GUARD}: ok ({len(rows)} rows, Level 1)")
if __name__=="__main__": main()