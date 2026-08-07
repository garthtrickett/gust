#!/usr/bin/env python3
from __future__ import annotations
import argparse, csv
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
GUARD="guard-cranelift-phase15-manual-close-contract"
CONTRACT=Path("tests/cranelift/phase15_manual_close_contract.tsv")
REVIEW=Path("tests/cranelift/phase15_manual_close_review.txt")
FILES=[Path("compiler/mir_manual_close.gst"),Path("compiler/mir_manual_close_mir_to_c.gst"),Path("compiler/mir_manual_close_parity_smoke_test_entry.gst"),Path("compiler/mir_manual_close_state_smoke_test_entry.gst"),Path("compiler/experiments/cranelift/src/manual_close.rs"),Path("compiler/experiments/cranelift/src/main.rs"),Path("scripts/phase15_manual_close_parity.sh"),Path(".github/workflows/phase15-manual-close.yml"),Path("scripts/cranelift_test_levels.json"),Path("justfile")]
TOKENS=("compiler_owned_manual_close_and_deferred_cleanup_state_machine","Phase15SelectedResource,os_Dir_ctx","manual_close_succeeds_and_suppresses_deferred_cleanup","close_transitions_to_manually_closed","repeated_close_policy=reject","LinearResourceCloseAfterMove","LinearResourceUseAfterClose","resource_close_of_non_closeable_resource","resource_cleanup_still_scheduled_after_close","cleanup_cancellation_id","scope_exit_does_not_double_close=1","final_destructor_only_if_explicitly_required=1","manual_close_before_scope_exit","manual_close_before_early_return","close_in_one_branch_with_valid_join_handling","close_followed_by_reinitialization_where_selected","LinearResourceDoubleClose","close_count=","destructor_count=suppressed_if_closed","filesystem_effects_compared=1","phase15-manual-close-witness","mir_manual_close_mir_to_c_lower")
def fail(m): raise SystemExit(f"{GUARD}: {m}")
def read(p):
    q=ROOT/p
    if not q.is_file() or q.is_symlink(): fail(f"missing regular file {p}")
    return q.read_text()
def load():
    with (ROOT/CONTRACT).open(newline="") as f: rows=list(csv.DictReader(f,delimiter="\t"))
    if len(rows)!=39: fail(f"expected 39 contract rows, got {len(rows)}")
    if any(r["level"]!="1" for r in rows): fail("all rows must be Level 1")
    return rows
def render(rows):
    return "Patch 15.8 — Manual Close Versus Deferred Cleanup\n\n"+"".join(f"{r['kind']}\t{r['requirement']}\t{r['evidence']}\tLevel {r['level']}\n" for r in rows)
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
