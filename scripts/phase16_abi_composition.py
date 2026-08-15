#!/usr/bin/env python3
from __future__ import annotations
import argparse,csv,json
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent;GUARD="guard-cranelift-phase16-composition-contract";CONTRACT=Path("tests/cranelift/phase16_abi_composition_contract.tsv");REVIEW=Path("tests/cranelift/phase16_abi_composition_review.txt");REGISTRY=Path("scripts/cranelift_feature_registry.json")
EXPECTED_IDS=["p16_function_abi_authority","p16_canonical_call_result_mir","p16_aggregate_parameter_abi","p16_aggregate_return_hidden_result_abi","p16_direct_call_agreement","p16_typed_indirect_calls","p16_fat_pointer_trait_object_call_abi","p16_unsized_value_abi","p16_dynamic_stack_storage","p16_resource_aggregate_call_abi","p16_cross_module_aggregate_resource_abi","p16_abi_metadata_validation"]
OPERATIONS={"aggregate_parameter","aggregate_result","hidden_result","direct_call","typed_indirect_call","fat_pointer_call","unsized_metadata","dynamic_stack","resource_transfer","cross_module_call","failure_before_transfer","failure_after_transfer"}
COMPARISONS={"default_explicit_mir_to_c_byte_identity","runtime_values","stdout","stderr","exit_status","parameter_result_witnesses","hidden_value_witnesses","layouts","resource_transitions","cleanup_destructor_order","filesystem_effects","initialized_data","output_preservation","mir_to_c_cranelift_witness_identity"}
FILES=[Path("compiler/mir_abi_composition.gst"),Path("compiler/mir_abi_composition_mir_to_c.gst"),Path("compiler/mir_abi_composition_parity_smoke_test_entry.gst"),Path("compiler/future/p16_complete_abi_differential_source.gst"),Path("compiler/experiments/cranelift/src/abi_composition.rs"),Path("compiler/experiments/cranelift/src/main.rs"),Path("scripts/phase16_abi_composition_parity.sh"),Path("scripts/cranelift_feature_registry.schema.json"),Path("scripts/cranelift_test_levels.json"),Path(".github/workflows/phase16-abi-composition.yml"),Path(".github/workflows/cranelift-historical-full.yml"),Path("justfile"),Path("TASK.md")]
TOKENS=("compiler_owned_generic_abi_composition","phase16:complete_abi_composition","registry_derived=1","covered_entries=12","shared_compiler_abi_layout_frame_and_phase15_resource_plan_no_backend_classifier","backend_abi_classifier=0","backend_hidden_result_planner=0","backend_resource_transfer_planner=0","phase16-abi-composition-witness","guard-cranelift-phase16-composition-contract","guard-cranelift-phase16-composition-differential","guard-cranelift-phase16-complete-abi-evidence")
def fail(m:str)->None:raise SystemExit(f"{GUARD}: {m}")
def read(path:Path)->str:
    full=ROOT/path
    if not full.is_file() or full.is_symlink():fail(f"missing regular file {path}")
    return full.read_text(encoding="utf-8")
def rows()->list[dict[str,str]]:
    with (ROOT/CONTRACT).open(encoding="utf-8",newline="") as handle:values=list(csv.DictReader(handle,delimiter="\t"))
    if not values or set(values[0])!={"kind","requirement","evidence","level"} or any(row["level"]!="1" for row in values):fail("contract schema or level mismatch")
    return values
def authority()->dict:
    registry=json.loads(read(REGISTRY));value=registry.get("phase16_abi_composition_authority")
    if not isinstance(value,dict) or value.get("version")!="phase16_abi_composition_authority_v1":fail("composition authority missing")
    opening=registry.get("opening_snapshots",{}).get("phase16",{}).get("entries",[]);opening_by_id={entry.get("id"):entry for entry in opening};entries=value.get("migrated_entries")
    if not isinstance(entries,list) or [entry.get("id") for entry in entries]!=EXPECTED_IDS:fail("migrated composition inventory drifted")
    guards=[]
    for entry in entries:
        source=opening_by_id.get(entry["id"])
        if not source or source.get("ci_family")!=entry.get("ci_family"):fail(f"{entry['id']}: opening projection mismatch")
        for field in ("positive_future_fixture","negative_current_fixture"):
            if not (ROOT/source.get(field,"")).is_file():fail(f"{entry['id']}: missing {field}")
        if not (ROOT/entry.get("canonical_mir_fixture","")).is_file():fail(f"{entry['id']}: canonical MIR evidence missing")
        guard=entry.get("individual_guard","")
        if not guard.startswith("guard-cranelift-phase16-"):fail(f"{entry['id']}: individual guard missing")
        if guard not in guards:guards.append(guard)
    case=value.get("composition_case",{})
    if case.get("covered_entry_count")!=len(entries) or set(case.get("operations",[]))!=OPERATIONS or set(case.get("comparison_contract",[]))!=COMPARISONS:fail("composition case drifted")
    for field in ("source_fixture","canonical_mir_fixture"):
        if not (ROOT/case.get(field,"")).is_file():fail(f"composition {field} missing")
    if value.get("level3_policy")!="complete_registry_derived_phase16_inventory_owned_only_by_cranelift_historical_full":fail("Level 3 policy drifted")
    value["_individual_guards"]=guards;return value
def render(values:list[dict[str,str]])->str:return "Patch 16.13 — Cross-Feature ABI Composition and Complete Differential\n\n"+"".join(f"{r['kind']}\t{r['requirement']}\t{r['evidence']}\tLevel {r['level']}\n" for r in values)
def check()->None:
    values=rows();combined="\n".join(read(path) for path in FILES)
    for token in TOKENS:
        if token not in combined:fail(f"missing token {token}")
    authority();expected=render(values)
    if not (ROOT/REVIEW).is_file() or read(REVIEW)!=expected:fail(f"{REVIEW} is stale; run --write")
    print(f"{GUARD}: ok ({len(values)} rows, Level 1)")
def main()->None:
    parser=argparse.ArgumentParser();parser.add_argument("command",nargs="?",choices=["individual-guards"]);parser.add_argument("--write",action="store_true");parser.add_argument("--check",action="store_true");args=parser.parse_args()
    if args.command=="individual-guards":print("\n".join(authority()["_individual_guards"]));return
    if args.write:(ROOT/REVIEW).write_text(render(rows()),encoding="utf-8")
    check()
if __name__=="__main__":main()
