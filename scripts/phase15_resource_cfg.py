#!/usr/bin/env python3
from __future__ import annotations
import argparse, csv
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
GUARD="guard-cranelift-phase15-resource-cfg-contract"
CONTRACT=Path("tests/cranelift/phase15_resource_cfg_contract.tsv")
REVIEW=Path("tests/cranelift/phase15_resource_cfg_review.txt")
FILES=[Path("compiler/mir_resource_cfg.gst"),Path("compiler/mir_resource_cfg_mir_to_c.gst"),Path("compiler/mir_resource_cfg_parity_smoke_test_entry.gst"),Path("compiler/mir_resource_cfg_state_smoke_test_entry.gst"),Path("compiler/experiments/cranelift/src/resource_cfg.rs"),Path("compiler/experiments/cranelift/src/main.rs"),Path("scripts/phase15_resource_cfg_parity.sh"),Path(".github/workflows/phase15-resource-cfg.yml"),Path("scripts/cranelift_test_levels.json"),Path("justfile")]
TOKENS=("compiler_owned_join_policy","freeze_supported_resource_state_joins","live/live","moved/moved","closed/closed","reinitialized/reinitialized","live/moved","live/closed","destroyed/live","incompatible_resource_identities","compiler_produced_join_records_with_block_parameters","resource_state_block_parameters","resource_remains_live_across_iterations","resource_moves_exactly_once_before_loop_exit","resource_is_replaced_each_iteration_with_prior_cleanup","resource_is_closed_on_all_exiting_paths","path_dependent_liveness_without_selected_policy","cleanup_obligation_mismatch_at_join","loop_backedge_state_mismatch","use_after_conditionally_moved_state","destructor_schedule_disagreement","nested_branches","selected_loops","resource_state_witness_after_join","resource_state_witness_after_loop_exit","cleanup_behavior_equivalent","irreducible_cfg_deferred","arbitrary_exception_edges_deferred","unrestricted_ownership_merging_deferred","resource_cfg_witness","block_params_used=1","compiler_owned_join_policy_with_equivalent_cleanup_behavior_through_mir_to_c_and_cranelift","mir_resource_cfg_mir_to_c_lower","phase15-resource-cfg-witness","resource_cfg_join_valid","resource_cfg_loop_valid")

def fail(m): raise SystemExit(f"{GUARD}: {m}")
def read(p):
    q=ROOT/p
    if not q.is_file() or q.is_symlink(): fail(f"missing regular file {p}")
    return q.read_text()
def load():
    with (ROOT/CONTRACT).open(newline="") as f: rows=list(csv.DictReader(f,delimiter="\t"))
    if len(rows)!=43: fail(f"expected 43 contract rows, got {len(rows)}")
    if any(r["level"]!="1" for r in rows): fail("all rows must be Level 1")
    return rows
def render(rows):
    return "Patch 15.9 — Conditional and Loop-Carried Resource States\n\n"+"".join(f"{r['kind']}\t{r['requirement']}\t{r['evidence']}\tLevel {r['level']}\n" for r in rows)
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
