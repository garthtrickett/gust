#!/usr/bin/env python3
from __future__ import annotations
import argparse, csv
from collections import Counter
from pathlib import Path

GUARD="guard-cranelift-phase16-fat-pointer-abi-contract"
PARITY="guard-cranelift-phase16-fat-pointer-abi-parity"
CONTRACT=Path("tests/cranelift/phase16_fat_pointer_abi_contract.tsv")
REVIEW=Path("tests/cranelift/phase16_fat_pointer_abi_review.txt")

def fail(message:str)->None: raise SystemExit(f"{GUARD}: {message}")
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
    authority=source(root,"compiler/mir_fat_pointer_abi.gst")
    require(authority,("type MirFatPointerTraitCall","type MirFatPointerAbiTable","gust.compiler_fat_pointer_abi.v1","borrowed_trait_object_method_call","two_word_data_and_vtable","compiler_owned_fat_pointer_components_vtable_slot_and_call_abi","construct_fat_pointer","extract_vtable_method","typed_indirect_call","mir_layout_table_is_valid","mir_function_abi_by_id","mir_validate_abi_compatibility","fat_pointer_missing_metadata","fat_pointer_component_mismatch","fat_pointer_unknown_method_signature","fat_pointer_invalid_slot_identity","fat_pointer_untyped_dispatch","fat_pointer_unsupported_target_representation","fat_pointer_insufficient_alignment","fat_pointer_resource_disposition_mismatch","mir_fat_pointer_abi_table_validate","mir_serialize_fat_pointer_abi_for_request"),"fat pointer authority")
    require(source(root,"compiler/mir_native_backend_fat_pointer_abi_request.gst"),("MirNativeBackendFatPointerAbiRequest","fat_pointer_table:","mir_native_backend_fat_pointer_abi_request_is_valid"),"native request")
    require(source(root,"compiler/mir_fat_pointer_abi_mir_to_c.gst"),("mir_fat_pointer_abi_mir_to_c_witness",),"MIR-to-C")
    require(source(root,"compiler/experiments/cranelift/src/fat_pointer_abi.rs"),("fn validate(","lower_fat_pointer_abi_witness_path","worker_consumes_compiler_fat_pointer_components_layouts_vtable_slot_and_typed_call_abi_no_backend_vtable_interpretation"),"Cranelift")
    require(source(root,"compiler/experiments/cranelift/src/main.rs"),("mod fat_pointer_abi;",'"phase16-fat-pointer-abi-witness"'),"CLI")
    require(source(root,"compiler/mir_fat_pointer_abi_smoke_test_entry.gst"),("fat_pointer:borrowed_display_object","vtable_slot:DisplayLike:value:0","borrowed_no_transfer_state_live","/tmp/gust-phase16-fat-pointer-abi.request"),"fixture")
    require(source(root,"scripts/phase16_fat_pointer_abi_parity.sh"),("phase16-fat-pointer-abi-witness","cmp -s","sentinel: preserve-existing-output","fat_pointer_missing_metadata","fat_pointer_untyped_dispatch"),"parity")
    require(source(root,"scripts/cranelift_test_levels.json"),(f'"{GUARD}": 1',f'"{PARITY}": 2'),"levels")
    require(source(root,"justfile"),(f"{GUARD}:",f"{PARITY}:"),"justfile")
    require(source(root,".github/workflows/phase16-fat-pointer-abi.yml"),(f"just {GUARD}",f"just {PARITY}"),"workflow")
    require(source(root,".github/workflows/pr-fast.yml"),(f"run: just {GUARD}",),"PR Fast")
    require(source(root,"TASK.md"),("- [x] Patch 16.7 — Fat-Pointer and Selected Trait-Object Call ABI — DONE",),"roadmap")
    require(source(root,"compiler/future/p16_fat_pointer_trait_object_call_abi_source.gst"),("migrated_by: phase16.7_fat_pointer_abi",),"future fixture")
def render(data:list[dict[str,str]])->str:
    counts=Counter(row["kind"] for row in data)
    lines=["Phase 16.7 — Fat-Pointer and Selected Trait-Object Call ABI",f"guard: {GUARD}",f"parity_guard: {PARITY}","test_level: level1","format: gust.compiler_fat_pointer_abi.v1","inventory: borrowed two-word data/vtable trait object and one typed method slot","boundary: general trait resolution, object safety, downcasting, complete vtables, closure objects, and foreign object models remain deferred","","counts:"]
    lines.extend(f"  {kind}: {counts[kind]}" for kind in sorted(counts))
    lines.extend(["","active contract:"])
    lines.extend(f"  {row['kind']}\t{row['id']}\t{row['owner']}\t{row['disposition']}" for row in data)
    lines.extend(["","exit gate:","  every selected fat-pointer call carries compiler-owned component layouts, pairing, slot, and typed ABI","  MIR-to-C and Cranelift consume the same compiler-produced trait-object call plan",""])
    return "\n".join(lines)
def main()->int:
    parser=argparse.ArgumentParser();parser.add_argument("--root",type=Path,default=Path.cwd());mode=parser.add_mutually_exclusive_group(required=True);mode.add_argument("--write",action="store_true");mode.add_argument("--check",action="store_true");args=parser.parse_args();root=args.root.resolve();data=rows(root);check(root);expected=render(data)
    if args.write:(root/REVIEW).write_text(expected,encoding="utf-8")
    elif source(root,str(REVIEW))!=expected:fail("generated review is stale")
    print(f"{GUARD}: ok ({len(data)} rows, level1)");return 0
if __name__=="__main__":raise SystemExit(main())
