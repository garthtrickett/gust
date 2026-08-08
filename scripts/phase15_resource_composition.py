#!/usr/bin/env python3
from __future__ import annotations
import argparse, csv, json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase15-resource-composition-contract"
CONTRACT = Path("tests/cranelift/phase15_resource_composition_contract.tsv")
REVIEW = Path("tests/cranelift/phase15_resource_composition_review.txt")
REGISTRY = Path("scripts/cranelift_feature_registry.json")
EXPECTED_IDS = [
    "p15_resource_value_representation", "p15_move_state_transitions",
    "p15_use_after_move_enforcement", "p15_reassignment_cleanup",
    "p15_scope_exit_cleanup", "p15_early_return_cleanup",
    "p15_destructor_scheduling", "p15_manual_close_interaction",
    "p15_conditional_loop_resource_state", "p15_resource_metadata_validation",
    "p15_directory_resources", "p15_selected_failure_cleanup",
]
OPERATIONS = {"init", "move", "reassign", "scope_exit", "early_return", "destructor", "manual_close", "branch_join", "loop_carried", "directory", "failure_return"}
COMPARISONS = {"default_explicit_mir_to_c_byte_identity", "runtime_values", "stdout", "stderr", "exit_status", "resource_witness", "cleanup_witness", "destructor_count", "close_count", "cleanup_order", "filesystem_effects", "output_preservation"}
FILES = [
    Path("compiler/mir_resource_composition.gst"), Path("compiler/mir_resource_composition_mir_to_c.gst"),
    Path("compiler/mir_resource_composition_parity_smoke_test_entry.gst"), Path("compiler/mir_resource_composition_state_smoke_test_entry.gst"),
    Path("compiler/future/p15_complete_resource_differential_source.gst"), Path("compiler/experiments/cranelift/src/resource_composition.rs"),
    Path("compiler/experiments/cranelift/src/main.rs"), Path("scripts/phase15_resource_composition_parity.sh"),
    Path("scripts/cranelift_feature_registry.schema.json"), Path("scripts/cranelift_registry.py"),
    Path("scripts/cranelift_test_levels.json"), Path(".github/workflows/phase15-resource-composition.yml"),
    Path(".github/workflows/cranelift-historical-full.yml"), Path("justfile"),
]
TOKENS = (
    "compiler_owned_generic_resource_composition", "phase15:complete_resource_composition",
    "registry_derived=1", "covered_entries=12", "init,move,reassign,scope_exit,early_return,destructor,manual_close,branch_join,loop_carried,directory,failure_return",
    "default_explicit_mir_to_c_byte_identity", "mir_to_c_cranelift_witness_identity=1",
    "shared_compiler_plan_no_backend_resource_or_cleanup_planner", "backend_resource_planner=0", "backend_cleanup_planner=0",
    "phase15-resource-composition-witness", "guard-cranelift-phase15-resource-composition-contract",
    "guard-cranelift-phase15-resource-composition-differential", "guard-cranelift-phase15-complete-resource-evidence",
)

def fail(message: str) -> None: raise SystemExit(f"{GUARD}: {message}")
def read(path: Path) -> str:
    full = ROOT / path
    if not full.is_file() or full.is_symlink(): fail(f"missing regular file {path}")
    return full.read_text()

def rows() -> list[dict[str, str]]:
    with (ROOT / CONTRACT).open(newline="") as handle: values = list(csv.DictReader(handle, delimiter="\t"))
    if not values or set(values[0]) != {"kind", "requirement", "evidence", "level"}: fail("contract schema mismatch")
    if any(row["level"] != "1" or not row["evidence"] for row in values): fail("contract rows must be Level 1")
    return values

def authority() -> dict:
    registry = json.loads(read(REGISTRY))
    value = registry.get("phase15_resource_composition_authority")
    if not isinstance(value, dict) or value.get("version") != "phase15_resource_composition_authority_v1": fail("composition authority missing")
    opening = registry.get("opening_snapshots", {}).get("phase15", {}).get("entries", [])
    opening_by_id = {entry.get("id"): entry for entry in opening}
    entries = value.get("migrated_entries")
    if not isinstance(entries, list) or [entry.get("id") for entry in entries] != EXPECTED_IDS: fail("migrated composition inventory drifted")
    guards = []
    for entry in entries:
        opening_entry = opening_by_id.get(entry["id"])
        if not opening_entry or entry.get("ci_family") != opening_entry.get("ci_family"): fail(f"{entry['id']}: opening projection mismatch")
        for field in ("positive_future_fixture",):
            fixture = opening_entry.get(field)
            if not isinstance(fixture, str) or not (ROOT / fixture).is_file(): fail(f"{entry['id']}: missing {field}")
        fixture = entry.get("canonical_mir_fixture")
        if not isinstance(fixture, str) or not (ROOT / fixture).is_file(): fail(f"{entry['id']}: canonical MIR evidence missing")
        guard = entry.get("individual_guard")
        if not isinstance(guard, str) or not guard.startswith("guard-cranelift-phase15-"): fail(f"{entry['id']}: individual guard missing")
        if guard not in guards: guards.append(guard)
    case = value.get("composition_case", {})
    if case.get("covered_entry_count") != len(entries) or set(case.get("operations", [])) != OPERATIONS or set(case.get("comparison_contract", [])) != COMPARISONS: fail("composition case contract drifted")
    for field in ("source_fixture", "canonical_mir_fixture"):
        if not (ROOT / case.get(field, "")).is_file(): fail(f"composition case {field} missing")
    if value.get("level3_policy") != "complete_registry_derived_phase15_inventory_owned_only_by_cranelift_historical_full": fail("Level 3 ownership drifted")
    value["_individual_guards"] = guards
    return value

def render(values: list[dict[str, str]]) -> str:
    return "Patch 15.13 — Cross-Feature Resource Composition and Complete Differential\n\n" + "".join(f"{r['kind']}\t{r['requirement']}\t{r['evidence']}\tLevel {r['level']}\n" for r in values)

def check() -> None:
    values = rows(); combined = "\n".join(read(path) for path in FILES)
    for token in TOKENS:
        if token not in combined: fail(f"missing token {token}")
    authority()
    if not (ROOT / REVIEW).is_file() or (ROOT / REVIEW).read_text() != render(values): fail(f"{REVIEW} is stale; run --write")
    print(f"{GUARD}: ok ({len(values)} rows, Level 1)")

def main() -> None:
    parser = argparse.ArgumentParser(); parser.add_argument("command", nargs="?", choices=["individual-guards"]); parser.add_argument("--write", action="store_true"); parser.add_argument("--check", action="store_true"); args = parser.parse_args()
    if args.command == "individual-guards":
        print("\n".join(authority()["_individual_guards"])); return
    if args.write: (ROOT / REVIEW).write_text(render(rows()))
    check()

if __name__ == "__main__": main()
