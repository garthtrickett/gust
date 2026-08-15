#!/usr/bin/env python3
from __future__ import annotations
import argparse,csv
from collections import Counter
from pathlib import Path
GUARD="guard-cranelift-phase16-resource-aggregate-abi-contract";PARITY="guard-cranelift-phase16-resource-aggregate-abi-parity";CONTRACT=Path("tests/cranelift/phase16_resource_aggregate_abi_contract.tsv");REVIEW=Path("tests/cranelift/phase16_resource_aggregate_abi_review.txt")
def fail(message:str)->None:raise SystemExit(f"{GUARD}: {message}")
def source(root:Path,path:str)->str:
    try:return (root/path).read_text(encoding="utf-8")
    except FileNotFoundError:fail(f"missing required file: {path}")
def require(text:str,tokens:tuple[str,...],owner:str)->None:
    for token in tokens:
        if token not in text:fail(f"{owner} is missing: {token}")
def rows(root:Path)->list[dict[str,str]]:
    with (root/CONTRACT).open(encoding="utf-8",newline="") as handle:data=list(csv.DictReader(handle,delimiter="\t"))
    if not data or set(data[0])!={"kind","id","owner","test_level","disposition"}:fail("contract schema drifted")
    seen=set()
    for row in data:
        key=row["kind"],row["id"]
        if key in seen or row["test_level"]!="level1":fail(f"invalid row: {key}")
        seen.add(key)
    return data
def check(root:Path)->None:
    require(source(root,"compiler/mir_resource_aggregate_abi.gst"),("type MirResourceAggregateAbiPlan","gust.compiler_resource_aggregate_abi.v1","move_into_call","aggregate_return_new_owner","nested_resource_aggregate","early_return_after_receipt","reassign_returned_aggregate","validated_transfer_cancels_source_cleanup_creates_destination_cleanup_one_live_owner","resource_aggregate_silent_copy","resource_aggregate_two_live_owners","resource_aggregate_missing_destination_identity","resource_aggregate_stale_source_cleanup","resource_aggregate_uninitialized_publication","resource_aggregate_destructor_mismatch","resource_aggregate_caller_callee_disagreement","mir_resource_aggregate_abi_table_validate","mir_serialize_resource_aggregate_abi_for_request"),"resource aggregate authority")
    require(source(root,"compiler/mir_native_backend_aggregate_resource_abi_request.gst"),("MirNativeBackendResourceAggregateAbiRequest","resource_aggregate_table:","mir_native_backend_resource_aggregate_abi_request_is_valid"),"native request");require(source(root,"compiler/mir_resource_aggregate_abi_mir_to_c.gst"),("mir_resource_aggregate_abi_mir_to_c_witness",),"MIR-to-C");require(source(root,"compiler/experiments/cranelift/src/resource_aggregate_abi.rs"),("fn validate(","lower_resource_aggregate_abi_witness_path","worker_consumes_compiler_aggregate_abi_phase15_resource_transition_cleanup_and_destructor_plan_no_backend_ownership_transfer"),"Cranelift");require(source(root,"compiler/experiments/cranelift/src/main.rs"),("mod resource_aggregate_abi;",'"phase16-resource-aggregate-abi-witness"'),"CLI");require(source(root,"compiler/mir_resource_aggregate_abi_smoke_test_entry.gst"),("resource_aggregate:param","resource_aggregate:return","resource_aggregate:nested","resource_aggregate:early","resource_aggregate:reassign","/tmp/gust-phase16-resource-aggregate-abi.request"),"fixture");require(source(root,"scripts/phase16_resource_aggregate_abi_parity.sh"),("phase16-resource-aggregate-abi-witness","cmp -s","sentinel: preserve-existing-output","resource_aggregate_silent_copy","resource_aggregate_two_live_owners","resource_aggregate_stale_source_cleanup"),"parity");require(source(root,"scripts/cranelift_test_levels.json"),(f'"{GUARD}": 1',f'"{PARITY}": 2'),"levels");require(source(root,"justfile"),(f"{GUARD}:",f"{PARITY}:"),"justfile");require(source(root,".github/workflows/phase16-resource-aggregate-abi.yml"),(f"just {GUARD}",f"just {PARITY}"),"workflow");require(source(root,".github/workflows/pr-fast.yml"),(f"run: just {GUARD}",),"PR Fast");require(source(root,"TASK.md"),("- [x] Patch 16.10 — Resource-Bearing Aggregate Call ABI — DONE",),"roadmap");require(source(root,"compiler/future/p16_resource_aggregate_call_abi_source.gst"),("migrated_by: phase16.10_resource_aggregate_abi",),"future fixture")
def render(data:list[dict[str,str]])->str:
    counts=Counter(row["kind"] for row in data);lines=["Phase 16.10 — Resource-Bearing Aggregate Call ABI",f"guard: {GUARD}",f"parity_guard: {PARITY}","test_level: level1","format: gust.compiler_resource_aggregate_abi.v1","inventory: selected move-only aggregate parameters, direct and hidden results, nested receipt, early return, and reassignment","boundary: general borrowing, shared ownership, foreign ABI, and unrestricted resource aggregates remain deferred","","counts:"];lines.extend(f"  {kind}: {counts[kind]}" for kind in sorted(counts));lines.extend(["","active contract:"]);lines.extend(f"  {row['kind']}\t{row['id']}\t{row['owner']}\t{row['disposition']}" for row in data);lines.extend(["","exit gate:","  each selected aggregate transfer has one validated Phase 15 transition, one live owner, and one destination cleanup","  MIR-to-C and Cranelift consume the same layout, ABI, ownership, failure, and destructor plan",""]);return "\n".join(lines)
def main()->int:
    parser=argparse.ArgumentParser();parser.add_argument("--root",type=Path,default=Path.cwd());mode=parser.add_mutually_exclusive_group(required=True);mode.add_argument("--write",action="store_true");mode.add_argument("--check",action="store_true");args=parser.parse_args();root=args.root.resolve();data=rows(root);check(root);expected=render(data)
    if args.write:(root/REVIEW).write_text(expected,encoding="utf-8")
    elif source(root,str(REVIEW))!=expected:fail("generated review is stale")
    print(f"{GUARD}: ok ({len(data)} rows, level1)");return 0
if __name__=="__main__":raise SystemExit(main())
