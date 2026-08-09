#!/usr/bin/env python3
from __future__ import annotations
import argparse, csv
from collections import Counter
from pathlib import Path
GUARD="guard-cranelift-phase16-typed-indirect-call-contract"; PARITY="guard-cranelift-phase16-typed-indirect-call-parity"; CONTRACT=Path("tests/cranelift/phase16_typed_indirect_call_contract.tsv"); REVIEW=Path("tests/cranelift/phase16_typed_indirect_call_review.txt")
def fail(message:str)->None: raise SystemExit(f"{GUARD}: {message}")
def source(root:Path,path:str)->str:
    try:return (root/path).read_text(encoding="utf-8")
    except FileNotFoundError:fail(f"missing required file: {path}")
def require(text:str,tokens:tuple[str,...],owner:str)->None:
    for token in tokens:
        if token not in text:fail(f"{owner} is missing: {token}")
def rows(root:Path)->list[dict[str,str]]:
    with (root/CONTRACT).open(encoding="utf-8",newline="") as handle: result=list(csv.DictReader(handle,delimiter="\t"))
    if not result or set(result[0])!={"kind","id","owner","test_level","disposition"}:fail("contract schema drifted")
    seen=set()
    for row in result:
        key=row["kind"],row["id"]
        if key in seen or row["test_level"]!="level1":fail(f"invalid row: {key}")
        seen.add(key)
    return result
def check(root:Path)->None:
    authority=source(root,"compiler/mir_typed_indirect_call.gst")
    require(authority,("type MirTypedIndirectCall","type MirTypedIndirectCallTable","gust.compiler_typed_indirect_call.v1","compatible_function_selection","typed_function_value_parameter","complete_canonical_signature_and_function_abi_identity_no_erasure","mir_validate_abi_compatibility","create_typed_function_value","typed_indirect_call","typed_indirect_unknown_signature","typed_indirect_signature_erasure","typed_indirect_incompatible_function_value","typed_indirect_null_call","typed_indirect_unsupported_calling_convention","typed_indirect_variadic_not_selected","typed_indirect_unvalidated_pointer_cast","mir_typed_indirect_call_table_validate","mir_serialize_typed_indirect_call_for_request"),"typed indirect authority")
    require(source(root,"compiler/mir_native_backend_typed_indirect_call_request.gst"),("MirNativeBackendTypedIndirectCallRequest","typed_indirect_table:","mir_native_backend_typed_indirect_call_request_is_valid"),"native request")
    require(source(root,"compiler/mir_typed_indirect_call_mir_to_c.gst"),("mir_typed_indirect_call_mir_to_c_witness",),"MIR-to-C")
    require(source(root,"compiler/experiments/cranelift/src/typed_indirect_call.rs"),("fn validate(","lower_typed_indirect_call_witness_path","worker_consumes_complete_compiler_typed_function_abi_no_signature_erasure"),"Cranelift")
    require(source(root,"compiler/experiments/cranelift/src/main.rs"),("mod typed_indirect_call;",'"phase16-typed-indirect-call-witness"'),"CLI")
    require(source(root,"compiler/mir_typed_indirect_call_smoke_test_entry.gst"),("function_value:selection","function_value:parameter","select_compatible_function","pass_typed_function_value","/tmp/gust-phase16-typed-indirect-call.request"),"fixture")
    require(source(root,"scripts/phase16_typed_indirect_call_parity.sh"),("phase16-typed-indirect-call-witness","cmp -s","sentinel: preserve-existing-output","typed_indirect_unknown_signature","typed_indirect_unvalidated_pointer_cast"),"parity")
    require(source(root,"scripts/cranelift_test_levels.json"),(f'"{GUARD}": 1',f'"{PARITY}": 2'),"levels"); require(source(root,"justfile"),(f"{GUARD}:",f"{PARITY}:"),"justfile"); require(source(root,".github/workflows/phase16-typed-indirect-calls.yml"),(f"just {GUARD}",f"just {PARITY}"),"workflow"); require(source(root,".github/workflows/pr-fast.yml"),(f"run: just {GUARD}",),"PR Fast"); require(source(root,"TASK.md"),("- [x] Patch 16.6 — Typed Indirect Calls and Function-Value ABI — DONE",),"roadmap")
def render(data:list[dict[str,str]])->str:
    counts=Counter(row["kind"] for row in data); lines=["Phase 16.6 — Typed Indirect Calls and Function-Value ABI",f"guard: {GUARD}",f"parity_guard: {PARITY}","test_level: level1","format: gust.compiler_typed_indirect_call.v1","inventory: compatible function selection and typed function-value parameters","boundary: closures, erased signatures, arbitrary code pointers, dynamic symbols, and unrestricted virtual calls remain deferred","","counts:"]; lines.extend(f"  {kind}: {counts[kind]}" for kind in sorted(counts)); lines.extend(["","active contract:"]); lines.extend(f"  {row['kind']}\t{row['id']}\t{row['owner']}\t{row['disposition']}" for row in data); lines.extend(["","exit gate:","  every selected indirect call carries a complete compiler-owned ABI identity","  MIR-to-C and Cranelift consume the same typed call decision",""]); return "\n".join(lines)
def main()->int:
    parser=argparse.ArgumentParser();parser.add_argument("--root",type=Path,default=Path.cwd());mode=parser.add_mutually_exclusive_group(required=True);mode.add_argument("--write",action="store_true");mode.add_argument("--check",action="store_true");args=parser.parse_args();root=args.root.resolve();data=rows(root);check(root);expected=render(data)
    if args.write:(root/REVIEW).write_text(expected,encoding="utf-8")
    elif source(root,str(REVIEW))!=expected:fail("generated review is stale")
    print(f"{GUARD}: ok ({len(data)} rows, level1)");return 0
if __name__=="__main__":raise SystemExit(main())
