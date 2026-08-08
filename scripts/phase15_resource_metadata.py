#!/usr/bin/env python3
from __future__ import annotations
import argparse, csv
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
GUARD="guard-cranelift-phase15-resource-metadata-contract"
CONTRACT=Path("tests/cranelift/phase15_resource_metadata_contract.tsv")
REVIEW=Path("tests/cranelift/phase15_resource_metadata_review.txt")
FILES=[Path("compiler/mir_resource_authority.gst"),Path("compiler/mir_native_backend_resource_request.gst"),Path("compiler/mir_native_backend_resource_mir_request.gst"),Path("compiler/experiments/cranelift/src/main.rs"),Path("scripts/phase15_resource_metadata.py"),Path(".github/workflows/phase15-resource-metadata.yml"),Path("scripts/cranelift_test_levels.json"),Path("justfile")]
TOKENS=("freeze_resource_metadata_schema","MirResourceIdentity","resource_id:","value_id:","resource_type_id:","source_declaration_id:","source_location:","owning_function:","owning_scope:","resource_kind:","destructor_id:","close_capability_id:","layout_id:","MirResourceState","program_point:","state:","MirDestructorIdentity","runtime_symbol:","MirCloseCapability","MirCleanupObligation","cleanup_id:","scope_exit_id:","insertion_scope:","execution_order:","exactly_once:","MirResourceStateJoin","join_id:","incoming_resource_ids:","incoming_states:","resulting_state:","MirResourceMirReference","mir_value_id:","mir_operation_id:","deterministic_ordering","deterministic_resource_ordering","deterministic_cleanup_ordering","deterministic_join_ordering","before_driver_discovery","malformed_requests_rejected_before_worker","worker_receives_validated_contract","resource_authority_table_validate","mir_native_backend_resource_request_is_valid","mir_serialize_resource_authority_table_for_request","resource_table_deterministic_ordering_valid","resource_metadata_contract_frozen","resource_metadata_deterministic_ordering_guaranteed","phase15-resource-metadata-witness")

def fail(m): raise SystemExit(f"{GUARD}: {m}")
def read(p):
    q=ROOT/p
    if not q.is_file() or q.is_symlink(): fail(f"missing regular file {p}")
    return q.read_text()
def load():
    with (ROOT/CONTRACT).open(newline="") as f: rows=list(csv.DictReader(f,delimiter="\t"))
    if len(rows)!=38: fail(f"expected 38 contract rows, got {len(rows)}")
    if any(r["level"]!="1" for r in rows): fail("all rows must be Level 1")
    return rows
def render(rows):
    return "Patch 15.10 — Resource Metadata and Request Validation\n\n"+"".join(f"{r['kind']}\t{r['requirement']}\t{r['evidence']}\tLevel {r['level']}\n" for r in rows)
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
