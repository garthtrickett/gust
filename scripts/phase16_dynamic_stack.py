#!/usr/bin/env python3
from __future__ import annotations
import argparse,csv
from collections import Counter
from pathlib import Path
GUARD="guard-cranelift-phase16-dynamic-stack-contract";PARITY="guard-cranelift-phase16-dynamic-stack-parity";CONTRACT=Path("tests/cranelift/phase16_dynamic_stack_contract.tsv");REVIEW=Path("tests/cranelift/phase16_dynamic_stack_review.txt")
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
    require(source(root,"compiler/mir_dynamic_stack.gst"),("type MirDynamicFramePlan","type MirDynamicFrameTable","gust.compiler_dynamic_stack.v1","bounded_vla_normal_exit","bounded_vla_early_return","bounded_nested_vla","checked_dynamic_size","aligned_stack_allocate","lifetime_start","lifetime_end","restore_stack","resource_cleanup_then_lifetime_end_then_stack_restore","dynamic_stack_non_dominating_size","dynamic_stack_unchecked_overflow","dynamic_stack_size_limit_exceeded","dynamic_stack_unsupported_alignment","dynamic_stack_use_outside_lifetime","dynamic_stack_missing_restoration","dynamic_stack_restore_before_cleanup","dynamic_stack_unsupported_target","dynamic_stack_backend_invented_size","mir_dynamic_stack_table_validate","mir_serialize_dynamic_stack_for_request"),"dynamic stack authority")
    require(source(root,"compiler/mir_native_backend_dynamic_stack_request.gst"),("MirNativeBackendDynamicStackRequest","dynamic_frame_table:","mir_native_backend_dynamic_stack_request_is_valid"),"native request")
    require(source(root,"compiler/mir_dynamic_stack_mir_to_c.gst"),("mir_dynamic_stack_mir_to_c_witness",),"MIR-to-C")
    require(source(root,"compiler/experiments/cranelift/src/dynamic_stack.rs"),("fn validate(","lower_dynamic_stack_witness_path","worker_consumes_compiler_dynamic_size_alignment_lifetime_cleanup_and_restore_plan_no_backend_frame_planner"),"Cranelift")
    require(source(root,"compiler/experiments/cranelift/src/main.rs"),("mod dynamic_stack;",'"phase16-dynamic-stack-witness"'),"CLI")
    require(source(root,"compiler/mir_dynamic_stack_smoke_test_entry.gst"),("frame:normal","frame:early","frame:nested","allow_zero_bytes_preserve_restore_marker","/tmp/gust-phase16-dynamic-stack.request"),"fixture")
    require(source(root,"scripts/phase16_dynamic_stack_parity.sh"),("phase16-dynamic-stack-witness","cmp -s","sentinel: preserve-existing-output","dynamic_stack_non_dominating_size","dynamic_stack_restore_before_cleanup","dynamic_stack_backend_invented_size"),"parity")
    require(source(root,"scripts/cranelift_test_levels.json"),(f'"{GUARD}": 1',f'"{PARITY}": 2'),"levels");require(source(root,"justfile"),(f"{GUARD}:",f"{PARITY}:"),"justfile");require(source(root,".github/workflows/phase16-dynamic-stack.yml"),(f"just {GUARD}",f"just {PARITY}"),"workflow");require(source(root,".github/workflows/pr-fast.yml"),(f"run: just {GUARD}",),"PR Fast");require(source(root,"TASK.md"),("- [x] Patch 16.9 — Bounded Dynamic Stack Frames and Variable-Sized Storage — DONE",),"roadmap");require(source(root,"compiler/future/p16_dynamic_stack_storage_source.gst"),("migrated_by: phase16.9_dynamic_stack",),"future fixture")
def render(data:list[dict[str,str]])->str:
    counts=Counter(row["kind"] for row in data);lines=["Phase 16.9 — Bounded Dynamic Stack Frames and Variable-Sized Storage",f"guard: {GUARD}",f"parity_guard: {PARITY}","test_level: level1","format: gust.compiler_dynamic_stack.v1","inventory: bounded normal-exit, early-return, and nested dynamic i32 stack storage","boundary: unbounded growth, arbitrary probing, coroutine or async frames, and heap fallback remain deferred","","counts:"];lines.extend(f"  {kind}: {counts[kind]}" for kind in sorted(counts));lines.extend(["","active contract:"]);lines.extend(f"  {row['kind']}\t{row['id']}\t{row['owner']}\t{row['disposition']}" for row in data);lines.extend(["","exit gate:","  every selected dynamic stack value has a compiler-owned checked size, alignment, lifetime, and restoration plan","  resource cleanup precedes lifetime end and stack restoration through MIR-to-C and Cranelift",""]);return "\n".join(lines)
def main()->int:
    parser=argparse.ArgumentParser();parser.add_argument("--root",type=Path,default=Path.cwd());mode=parser.add_mutually_exclusive_group(required=True);mode.add_argument("--write",action="store_true");mode.add_argument("--check",action="store_true");args=parser.parse_args();root=args.root.resolve();data=rows(root);check(root);expected=render(data)
    if args.write:(root/REVIEW).write_text(expected,encoding="utf-8")
    elif source(root,str(REVIEW))!=expected:fail("generated review is stale")
    print(f"{GUARD}: ok ({len(data)} rows, level1)");return 0
if __name__=="__main__":raise SystemExit(main())
