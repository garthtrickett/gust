#!/usr/bin/env python3
from __future__ import annotations
import argparse, csv
from collections import Counter
from pathlib import Path

GUARD="guard-cranelift-phase16-abi-metadata-contract"
CONTRACT=Path("tests/cranelift/phase16_abi_metadata_contract.tsv")
MALFORMED=Path("tests/cranelift/phase16_abi_metadata_malformed.tsv")
REVIEW=Path("tests/cranelift/phase16_abi_metadata_review.txt")
REASONS={
"unknown_abi":"abi_metadata_unknown_abi_id","duplicate_record":"abi_metadata_duplicate_conflicting_record",
"unknown_layout":"abi_metadata_unknown_layout_or_resource_id","missing_call_metadata":"abi_metadata_mir_call_missing_metadata",
"missing_mir_owner":"abi_metadata_without_mir_owner","impossible_placement":"abi_metadata_impossible_placement",
"overlapping_stack":"abi_metadata_overlapping_stack_areas","invalid_hidden_result":"abi_metadata_invalid_hidden_result",
"signature_mismatch":"abi_metadata_signature_mismatch","target_mismatch":"abi_metadata_target_mismatch",
"invalid_frame_restoration":"abi_metadata_invalid_frame_restoration","resource_transfer":"abi_metadata_resource_transfer_inconsistent",
"nondeterministic_ordering":"abi_metadata_nondeterministic_ordering"}

def fail(message:str)->None: raise SystemExit(f"{GUARD}: {message}")
def read(root:Path,path:str)->str:
    candidate=root/path
    if not candidate.is_file() or candidate.is_symlink(): fail(f"missing regular file: {path}")
    return candidate.read_text(encoding="utf-8")
def load(root:Path,path:Path,columns:set[str])->list[dict[str,str]]:
    with (root/path).open(encoding="utf-8",newline="") as handle: rows=list(csv.DictReader(handle,delimiter="\t"))
    if not rows or set(rows[0])!=columns: fail(f"schema drifted: {path}")
    return rows
def check(root:Path)->list[dict[str,str]]:
    rows=load(root,CONTRACT,{"kind","id","owner","test_level","disposition"})
    if any(row["test_level"]!="level1" for row in rows): fail("all contract rows must be Level 1")
    keys=[(row["kind"],row["id"]) for row in rows]
    if len(keys)!=len(set(keys)): fail("duplicate contract row")
    malformed=load(root,MALFORMED,{"fixture","reason_code","old","new"})
    if {row["fixture"]:row["reason_code"] for row in malformed}!=REASONS: fail("malformed request inventory drifted")
    request=read(root,"compiler/mir_native_backend_abi_metadata_request.gst")
    worker=read(root,"compiler/experiments/cranelift/src/abi_metadata.rs")
    fixture=read(root,"compiler/fixtures/native_backend_abi_metadata_valid.request")
    harness=read(root,"scripts/phase16_abi_metadata_validation.sh")
    for token in ("abi_metadata_schema_frozen","abi_metadata_deterministic_ordering_and_deduplication","abi_metadata_validation_before_worker_driver_and_artifact_access","mir_native_backend_abi_metadata_request_is_valid","worker_validates_but_does_not_invent_abi_classifications_placements_signatures_or_ownership_transfers"):
        if token not in request: fail(f"request contract missing: {token}")
    for token in ("function_abi","classification","parameter_placement","result_placement","hidden_value","call_plan","compatibility","dynamic_frame","layout_reference","resource_transfer","mir_owner"):
        if f"kind={token}" not in fixture: fail(f"valid fixture missing record kind: {token}")
    for reason in REASONS.values():
        if reason not in worker or reason not in request: fail(f"missing stable reason: {reason}")
    for token in ("worker_validates_compiler_produced_abi_metadata_but_never_invents_classification_placement_signature_hidden_result_frame_or_resource_transfer","phase16-abi-metadata-witness"):
        combined=worker+read(root,"compiler/experiments/cranelift/src/main.rs")
        if token not in combined: fail(f"worker boundary missing: {token}")
    for token in ("sentinel: preserve-existing-output","poisoned-driver-was-invoked","GUST_NATIVE_DRIVER","reason=","cmp -s"):
        if token not in harness: fail(f"validation harness missing: {token}")
    for path,token in (("scripts/cranelift_test_levels.json",f'"{GUARD}": 1'),("justfile",f"{GUARD}:"),(".github/workflows/phase16-abi-metadata.yml",f"just {GUARD}"),(".github/workflows/pr-fast.yml",f"run: just {GUARD}"),("TASK.md","- [x] Patch 16.12 — ABI Metadata and Native Request Validation — DONE"),("compiler/future/p16_abi_metadata_validation_source.gst","migrated_by: phase16.12_abi_metadata_request_validation")):
        if token not in read(root,path): fail(f"{path} missing: {token}")
    return rows
def render(rows:list[dict[str,str]])->str:
    counts=Counter(row["kind"] for row in rows)
    lines=["Patch 16.12 — ABI Metadata and Native Request Validation",f"guard: {GUARD}","test_level: level1","format: gust.compiler_abi_metadata_request.v1","authority: compiler-owned ABI, Phase 14 layout, and Phase 15 resource records","boundary: validation precedes worker, driver, object, linker, and output replacement","","counts:"]
    lines.extend(f"  {kind}: {counts[kind]}" for kind in sorted(counts));lines.extend(["","active contract:"])
    lines.extend(f"  {row['kind']}\t{row['id']}\t{row['owner']}\t{row['disposition']}" for row in rows)
    lines.extend(["","malformed request reasons:"]);lines.extend(f"  {fixture}\t{reason}" for fixture,reason in sorted(REASONS.items()))
    lines.extend(["","exit gate:","  one deterministic compiler-produced ABI metadata contract reaches the worker","  malformed ABI metadata preserves existing output and cannot reach driver or artifact access",""])
    return "\n".join(lines)
def main()->int:
    parser=argparse.ArgumentParser();parser.add_argument("--root",type=Path,default=Path.cwd());mode=parser.add_mutually_exclusive_group(required=True);mode.add_argument("--write",action="store_true");mode.add_argument("--check",action="store_true");args=parser.parse_args();root=args.root.resolve();rows=check(root);expected=render(rows)
    if args.write:(root/REVIEW).write_text(expected,encoding="utf-8")
    elif read(root,str(REVIEW))!=expected:fail("generated review is stale")
    print(f"{GUARD}: ok ({len(rows)} rows, level1)");return 0
if __name__=="__main__": raise SystemExit(main())
