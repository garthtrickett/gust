#!/usr/bin/env python3
from __future__ import annotations
import argparse,csv
from collections import Counter
from pathlib import Path
G="guard-cranelift-phase16-cross-module-abi-contract";P="guard-cranelift-phase16-cross-module-abi-parity";C=Path("tests/cranelift/phase16_cross_module_abi_contract.tsv");R=Path("tests/cranelift/phase16_cross_module_abi_review.txt")
def fail(m):raise SystemExit(f"{G}: {m}")
def src(root,p):
 try:return(root/p).read_text()
 except FileNotFoundError:fail(f"missing required file: {p}")
def req(t,tokens,o):
 for x in tokens:
  if x not in t:fail(f"{o} is missing: {x}")
def rows(root):
 with(root/C).open(newline="")as h:d=list(csv.DictReader(h,delimiter="\t"))
 if not d or set(d[0])!={"kind","id","owner","test_level","disposition"}:fail("schema")
 return d
def check(root):
 req(src(root,"compiler/mir_cross_module_abi.gst"),("MirCrossModuleAbiPlan","gust.compiler_cross_module_abi.v1","aggregate_parameter","aggregate_result","resource_aggregate_transfer","multiple_selected_modules","cross_module_missing_abi_descriptor","cross_module_stale_import","cross_module_layout_mismatch","cross_module_target_mismatch","cross_module_calling_convention_mismatch","cross_module_hidden_result_mismatch","cross_module_resource_policy_mismatch","cross_module_unsupported_foreign_symbol","phase9g_owns_object_link_temporary_and_atomic_publication"),"authority");req(src(root,"compiler/experiments/cranelift/src/cross_module_abi.rs"),("lower_cross_module_abi_witness_path","worker_consumes_compiler_cross_module"),"worker");req(src(root,"compiler/mir_cross_module_abi_smoke_test_entry.gst"),("cross:param","cross:result","cross:resource","cross:multiple"),"fixture");req(src(root,"scripts/phase16_cross_module_abi_parity.sh"),("cmp -s","sentinel: preserve-existing-output","cross_module_stale_import"),"parity");req(src(root,"justfile"),(G+":",P+":"),"justfile");req(src(root,"scripts/cranelift_test_levels.json"),(f'"{G}": 1',f'"{P}": 2'),"levels");req(src(root,"TASK.md"),("- [x] Patch 16.11 — Selected Cross-Module Aggregate and Resource ABI — DONE",),"roadmap");req(src(root,"compiler/future/p16_cross_module_aggregate_resource_abi_source.gst"),("migrated_by: phase16.11_cross_module_abi",),"fixture marker")
def render(d):
 c=Counter(x["kind"]for x in d);lines=["Phase 16.11 — Selected Cross-Module Aggregate and Resource ABI",f"guard: {G}",f"parity_guard: {P}","format: gust.compiler_cross_module_abi.v1","boundary: foreign ABI, dynamic libraries, symbol negotiation, variadics, and cross-language exceptions remain deferred","","counts:"];lines += [f"  {k}: {c[k]}"for k in sorted(c)];lines += ["","active contract:"]+[f"  {x['kind']}\t{x['id']}\t{x['owner']}\t{x['disposition']}"for x in d]+["","exit gate:","  selected same-version Gust modules agree on compiler-produced ABI, layout, placement, hidden results, and resource policy","  Phase 9G retains object, link, temporary, and publication ownership",""];return"\n".join(lines)
def main():
 p=argparse.ArgumentParser();p.add_argument("--root",type=Path,default=Path.cwd());m=p.add_mutually_exclusive_group(required=True);m.add_argument("--write",action="store_true");m.add_argument("--check",action="store_true");a=p.parse_args();root=a.root.resolve();d=rows(root);check(root);e=render(d)
 if a.write:(root/R).write_text(e)
 elif src(root,str(R))!=e:fail("generated review is stale")
 print(f"{G}: ok ({len(d)} rows, level1)")
if __name__=="__main__":main()
