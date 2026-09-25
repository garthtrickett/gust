#!/usr/bin/env python3
"""Validate Phase 26.1D1's selected canonical external-call policy gate."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
GUARD = "guard-cranelift-phase26-ffi-position-policy"
FIXTURES = [
    "compiler/phase26_ffi_position_policy_test_entry.gst",
    "compiler/phase26_ffi_borrow_read_source.gst",
    "compiler/phase26_ffi_unannotated_pointer_invalid.gst",
    "compiler/phase26_ffi_transfer_invalid.gst",
    "compiler/phase26_ffi_retain_invalid.gst",
    "compiler/phase26_ffi_callback_invalid.gst",
    "compiler/phase26_ffi_native_error_invalid.gst",
    "compiler/phase26_ffi_returned_pointer_invalid.gst",
    "compiler/phase26_ffi_aggregate_invalid.gst",
    "compiler/phase26_ffi_write_nonraw_invalid.gst",
    "compiler/phase26_ffi_nonextern_attribute_invalid.gst",
    "compiler/phase26_ffi_unsafe_call_invalid.gst",
]
EXPECTED = {
    "contract_version": "phase26_1d1_ffi_position_policy_v1",
    "status": "selected_canonical_ffi_ownership_positions_qualified",
    "owner": "cranelift",
    "increment": "26.1D1",
    "canonical_parameter_policies": [
        "value", "borrow_read_call", "borrow_write_call",
    ],
    "scalar_value_policy": "synthesized_on_extern_declaration",
    "void_or_scalar_return_policy": "synthesized_value",
    "borrow_write_formal": "explicit_raw_pointer_only",
    "borrow_write_meaning": "native_mutation_permission_under_explicit_unsafe",
    "borrow_write_aliasing": "aliases_may_exist_no_exclusivity_claim",
    "native_contract_enforcement": "declaration_and_call_validation_only",
    "unsupported_contracts": [
        "transfer", "retain", "callback", "native_error",
        "returned_pointer", "by_value_aggregate",
    ],
    "failure_stage": "canonical_typechecking_before_driver",
    "existing_unsafe_call_gate": "preserved",
    "physical_abi_changed": False,
    "runtime_symbol_surface_changed": False,
    "native_fallback": False,
    "owning_level2_guard": GUARD,
    "pr_fast_job": "phase26-ffi-position",
    "positive_metadata_fixture": FIXTURES[0],
    "positive_borrow_fixture": FIXTURES[1],
    "negative_fixtures": FIXTURES[2:],
    "current_borrow_native_disposition":
        "deferred_p13_parameter_argument_target_dependent_abi",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def main() -> None:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    activation = registry.get("phase26_activation_audit", {})
    require(activation.get("status") == "phase26_activation_audit_registered",
            "Phase 26 activation is not registered")
    record = activation.get("ffi_position_policy_increment", {})
    for key, expected in EXPECTED.items():
        require(record.get(key) == expected,
                f"FFI position registration drifted: {key}")
    require(set(record) == set(EXPECTED) | {
        "phase22_invocation_successor", "phase23_text_surface_successor",
        "production_audit_successor", "filename_site_successor",
        "spelling_inventory_successor",
    }, "FFI position registration fields drifted")
    for path in FIXTURES:
        require((ROOT / path).is_file(), f"registered fixture is missing: {path}")

    justfile = (ROOT / "justfile").read_text(encoding="utf-8")
    workflow = (ROOT / ".github/workflows/pr-fast.yml").read_text(
        encoding="utf-8")
    guard = (ROOT / "scripts/phase26_ffi_position_policy.sh").read_text(
        encoding="utf-8")
    require(justfile.count(f"{GUARD}:") == 1 and
            "python3 scripts/phase26_ffi_position_registration.py" in justfile and
            "bash scripts/phase26_ffi_position_policy.sh" in justfile,
            "Level 2 recipe does not own registration and execution")
    require(workflow.count("phase26-ffi-position:") == 1 and
            workflow.count(f"just {GUARD}") == 1 and
            "needs: [guard, level1, phase20-nested-brand-annotation, "
            "phase26-ffi-position]" in workflow,
            "PR Fast does not own the selected Level 2 gate")
    require("GUST_TEST_MIR_TO_C_UNAVAILABLE=1" in guard and
            "--backend cranelift" in guard and
            "poison-driver.invoked" in guard and
            "deferred_p13_parameter_argument_target_dependent_abi" in guard,
            "guard lost its native-only, pre-driver boundary")
    require("--backend mir-to-c" not in guard,
            "guard revived a retired backend route")
    for path in FIXTURES[:2]:
        require(path in guard,
                f"guard does not execute positive fixture: {path}")
    require('source="compiler/phase26_ffi_${name}_invalid.gst"' in guard,
            "guard no longer executes the negative fixture table")
    for path in FIXTURES[2:]:
        name = path.removeprefix("compiler/phase26_ffi_").removesuffix(
            "_invalid.gst")
        require(f"'{name}|" in guard,
                f"guard does not execute negative fixture: {path}")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
