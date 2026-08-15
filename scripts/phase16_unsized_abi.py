#!/usr/bin/env python3
from __future__ import annotations
import argparse,csv
from collections import Counter
from pathlib import Path
GUARD="guard-cranelift-phase16-unsized-abi-contract";PARITY="guard-cranelift-phase16-unsized-abi-parity";CONTRACT=Path("tests/cranelift/phase16_unsized_abi_contract.tsv");REVIEW=Path("tests/cranelift/phase16_unsized_abi_review.txt")
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
    require(source(root,"compiler/mir_unsized_abi.gst"),("type MirUnsizedAbiPlan","type MirUnsizedAbiTable","gust.compiler_unsized_abi.v1","borrowed_slice_parameter","borrowed_slice_result","fixed_backing_local_slice_view","fat_pointer_data_and_length","compiler_checked_length_times_element_size_no_backend_calculation","bind_unsized_data","bind_length_metadata","checked_size_multiply","transport_unsized_view","unsized_by_value_without_storage_plan","unsized_missing_metadata","unsized_inconsistent_length_or_layout","unsized_size_overflow","unsized_insufficient_alignment","unsized_bounds_violation","unsized_invalid_result_ownership","unsized_backend_invented_size","mir_unsized_abi_table_validate","mir_serialize_unsized_abi_for_request"),"unsized authority")
    require(source(root,"compiler/mir_native_backend_unsized_abi_request.gst"),("MirNativeBackendUnsizedAbiRequest","unsized_table:","mir_native_backend_unsized_abi_request_is_valid"),"native request")
    require(source(root,"compiler/mir_unsized_abi_mir_to_c.gst"),("mir_unsized_abi_mir_to_c_witness",),"MIR-to-C")
    require(source(root,"compiler/experiments/cranelift/src/unsized_abi.rs"),("fn validate(","lower_unsized_abi_witness_path","worker_consumes_compiler_unsized_data_metadata_element_layout_storage_lifetime_bounds_and_transport_no_backend_size_calculation"),"Cranelift")
    require(source(root,"compiler/experiments/cranelift/src/main.rs"),("mod unsized_abi;",'"phase16-unsized-abi-witness"'),"CLI")
    require(source(root,"compiler/mir_unsized_abi_smoke_test_entry.gst"),("slice:param","slice:result","slice:local","caller_backing_borrowed_result","/tmp/gust-phase16-unsized-abi.request"),"fixture")
    require(source(root,"scripts/phase16_unsized_abi_parity.sh"),("phase16-unsized-abi-witness","cmp -s","sentinel: preserve-existing-output","unsized_missing_metadata","unsized_backend_invented_size"),"parity")
    require(source(root,"scripts/cranelift_test_levels.json"),(f'"{GUARD}": 1',f'"{PARITY}": 2'),"levels");require(source(root,"justfile"),(f"{GUARD}:",f"{PARITY}:"),"justfile");require(source(root,".github/workflows/phase16-unsized-abi.yml"),(f"just {GUARD}",f"just {PARITY}"),"workflow");require(source(root,".github/workflows/pr-fast.yml"),(f"run: just {GUARD}",),"PR Fast");require(source(root,"TASK.md"),("- [x] Patch 16.8 — Unsized Value Parameter, Return, and Storage Contract — DONE",),"roadmap");require(source(root,"compiler/future/p16_unsized_value_abi_source.gst"),("migrated_by: phase16.8_unsized_abi",),"future fixture")
def render(data:list[dict[str,str]])->str:
    counts=Counter(row["kind"] for row in data);lines=["Phase 16.8 — Unsized Value Parameter, Return, and Storage Contract",f"guard: {GUARD}",f"parity_guard: {PARITY}","test_level: level1","format: gust.compiler_unsized_abi.v1","inventory: borrowed slice parameter, caller-backed borrowed slice result, and fixed-backing local slice view","boundary: arbitrary DSTs, unsized aggregate tails, dynamic allocation, heap allocation, and complete trait objects remain deferred","","counts:"];lines.extend(f"  {kind}: {counts[kind]}" for kind in sorted(counts));lines.extend(["","active contract:"]);lines.extend(f"  {row['kind']}\t{row['id']}\t{row['owner']}\t{row['disposition']}" for row in data);lines.extend(["","exit gate:","  every selected unsized value carries compiler-owned data, length, layout, storage, lifetime, bounds, and transport","  MIR-to-C and Cranelift consume the same compiler-produced checked size and metadata flow",""]);return "\n".join(lines)
def main()->int:
    parser=argparse.ArgumentParser();parser.add_argument("--root",type=Path,default=Path.cwd());mode=parser.add_mutually_exclusive_group(required=True);mode.add_argument("--write",action="store_true");mode.add_argument("--check",action="store_true");args=parser.parse_args();root=args.root.resolve();data=rows(root);check(root);expected=render(data)
    if args.write:(root/REVIEW).write_text(expected,encoding="utf-8")
    elif source(root,str(REVIEW))!=expected:fail("generated review is stale")
    print(f"{GUARD}: ok ({len(data)} rows, level1)");return 0
if __name__=="__main__":raise SystemExit(main())
