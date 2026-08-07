#!/usr/bin/env python3
from __future__ import annotations
import argparse, csv
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
GUARD="guard-cranelift-phase15-destructor-scheduling-contract"
CONTRACT=Path("tests/cranelift/phase15_destructor_scheduling_contract.tsv")
REVIEW=Path("tests/cranelift/phase15_destructor_scheduling_review.txt")
FILES=[Path("compiler/mir_destructor_scheduling.gst"),Path("compiler/mir_destructor_scheduling_parity_smoke_test_entry.gst"),Path("compiler/mir_destructor_scheduling_state_smoke_test_entry.gst"),Path("compiler/experiments/cranelift/src/destructor_scheduling.rs"),Path("compiler/experiments/cranelift/src/main.rs"),Path("scripts/phase15_destructor_scheduling_parity.sh"),Path(".github/workflows/phase15-destructor-scheduling.yml"),Path("scripts/cranelift_test_levels.json"),Path("justfile")]
TOKENS=("compiler_owned_destructor_identity_and_schedule","schedule_destructor,cancel_obsolete_schedule,execute_destructor,mark_resource_destroyed","one_live_schedule_one_execution_deterministic_order","destructor_duplicate_live_schedule","destructor_execution_without_schedule","destructor_schedule_after_destroy","destructor_identity_mismatch","destructor_live_resource_skipped","destructor_moved_ownership_destroyed","destructor_order_drift","destructor_transfer_schedule_not_canceled","destructor_scheduling_exactly_once_witness","observable_effects_preserved=1","async_destruction,finalizers,gc,concurrent_cancellation")
def fail(m): raise SystemExit(f"{GUARD}: {m}")
def read(p):
    q=ROOT/p
    if not q.is_file() or q.is_symlink(): fail(f"missing regular file {p}")
    return q.read_text()
def load():
    with (ROOT/CONTRACT).open(newline="") as f: rows=list(csv.DictReader(f,delimiter="\t"))
    if len(rows)!=42: fail(f"expected 42 contract rows, got {len(rows)}")
    if any(r["level"]!="1" for r in rows): fail("all rows must be Level 1")
    return rows
def render(rows):
    return "Patch 15.7 — Destructor Scheduling and Exactly-Once Destruction\n\n"+"".join(f"{r['kind']}\t{r['requirement']}\t{r['evidence']}\tLevel {r['level']}\n" for r in rows)
def check():
    rows=load(); combined="\n".join(read(p) for p in FILES)
    for t in TOKENS:
        if t not in combined: fail(f"missing token {t}")
    expected=render(rows)
    if not (ROOT/REVIEW).is_file() or (ROOT/REVIEW).read_text()!=expected: fail(f"{REVIEW} is stale; run with --write")
    return rows
def main():
    p=argparse.ArgumentParser(); p.add_argument("--check",action="store_true"); p.add_argument("--write",action="store_true"); a=p.parse_args()
    if a.write:
        rows=load(); (ROOT/REVIEW).write_text(render(rows))
    rows=check(); print(f"{GUARD}: ok ({len(rows)} rows, Level 1)")
if __name__=="__main__": main()