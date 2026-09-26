#!/usr/bin/env python3
"""Pin the selected Phase26.1D2 C-layout gate and its exact successors."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-ffi-repr-c-layout"
SCRIPT = "scripts/phase26_ffi_repr_c_layout.sh"
FIXTURES = [
    "compiler/phase26_ffi_repr_c_probe_source.gst",
    *[f"compiler/phase26_ffi_repr_c_{name}_source.gst"
      for name in ("missing", "order", "packed", "nested", "unknown_host", "enum")],
    "compiler/phase26_ffi_aggregate_invalid.gst",
]
SURFACES = {
    ".github/workflows/pr-fast.yml",
    "compiler/experiments/cranelift/src/full_program.rs",
    "compiler/experiments/cranelift/src/main.rs",
    "compiler/mir_native_backend_full_program_source.gst",
    "justfile",
    "scripts/cranelift_test_levels.json",
    "scripts/phase21_compiler_support_native_qualification.py",
    "scripts/phase22_opening.py",
}


def require(value: bool, message: str) -> None:
    if not value:
        raise SystemExit(f"{GUARD}: {message}")


def main() -> None:
    registry = json.loads((ROOT / "scripts/cranelift_feature_registry.json")
                          .read_text(encoding="utf-8"))
    record = registry.get("phase26_activation_audit", {}).get(
        "ffi_repr_c_layout_increment", {})
    expected = {
        "contract_version": "phase26_1d2_ffi_repr_c_layout_v1",
        "status": "selected_flat_borrowed_repr_c_layout_qualified",
        "owner": "cranelift",
        "increment": "26.1D2",
        "canonical_layout_metadata": "existing_full_program_layout_rows",
        "target_layout_authority": "phase14_declared_x86_64_linux_pointer_and_i32_alignment",
        "supported_position": "borrow_read_call_reference_to_flat_repr_c_struct",
        "selected_host_import": "tiny_host_read_repr_c_probe",
        "selected_host_object": "generated_test_only_not_runtime_package",
        "positive_fixture": FIXTURES[0],
        "negative_fixtures": FIXTURES[1:],
        "failure_stage": "before_driver_discovery",
        "deferral_reason": "deferred_p26_ffi_borrowed_c_layout",
        "native_fallback": False,
        "physical_abi_changed": False,
        "runtime_symbol_surface_changed": False,
        "unsupported_shapes": ["packed", "enum", "by_value_aggregate",
                               "nested_aggregate", "unapproved_host"],
        "owning_level2_guard": GUARD,
        "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"registry field drifted: {key}")
    require(set(record) == set(expected) | {
        "phase21_import_edge_successor",
        "phase22_invocation_successor", "phase23_text_surface_successor",
        "production_audit_successor", "spelling_inventory_successor"},
        "registry acquired unreviewed D2 fields")
    require(record["phase21_import_edge_successor"] == {
        "contract_version": "phase26_1d2_phase21_import_edge_successor_v1",
        "added_edge": [
            "mir_native_backend_module_import_source.gst", "typechecker.gst"],
        "frozen_import_edge_count": 116,
    }, "Phase21 import-edge successor drifted")
    for path in FIXTURES:
        require((ROOT / path).is_file(), f"registered fixture missing: {path}")

    invocation = record["phase22_invocation_successor"]
    require(invocation.get("contract_version") ==
            "phase26_1d2_phase22_invocation_successor_v1" and
            invocation.get("previous_total") == 155 and
            invocation.get("current_total") == 158 and
            invocation.get("partial_extra_or_substituted_invocation") == "rejected" and
            len(invocation.get("added_rows", [])) == 3,
            "Phase22 invocation successor drifted")
    from phase22_opening import scan_invocations
    live = [row for row in scan_invocations() if row["path"] == SCRIPT]
    require(live == invocation["added_rows"],
            "selected native invocation rows differ from scanner")

    surfaces = record["phase23_text_surface_successor"]
    changed = surfaces.get("changed_rows", [])
    added = surfaces.get("added_row")
    require(surfaces.get("contract_version") ==
            "phase26_1d2_phase23_text_surface_successor_v1" and
            surfaces.get("partial_extra_or_substituted_surface") == "rejected" and
            len(changed) == len(SURFACES) and
            {row.get("path") for row in changed} == SURFACES and
            isinstance(added, dict) and
            added.get("path") ==
            "scripts/phase26_ffi_repr_c_registration.py",
            "Phase23 text surface successor drifted")
    for row in changed:
        live_digest = hashlib.sha256((ROOT / row["path"]).read_bytes()).hexdigest()
        require(live_digest == row["current_digest"] and
                len(row["previous_digest"]) == 64,
                f"text surface digest drifted: {row['path']}")
    require(hashlib.sha256(
                (ROOT / added["path"]).read_bytes()).hexdigest() ==
            added["digest"], "added registration text surface drifted")

    workflow = (ROOT / ".github/workflows/pr-fast.yml").read_text()
    justfile = (ROOT / "justfile").read_text()
    guard = (ROOT / SCRIPT).read_text()
    require(workflow.count(f"just {GUARD}") == 1 and
            workflow.count("phase26-ffi-position:") == 1 and
            justfile.count(f"{GUARD}:") == 1 and
            "python3 scripts/phase26_ffi_repr_c_registration.py" in justfile,
            "required PR Fast Level2 registration path drifted")
    require("GUST_TEST_MIR_TO_C_UNAVAILABLE=1" in guard and
            "deferred_p26_ffi_borrowed_c_layout" in guard and
            "poison-driver.invoked" in guard and
            "printf '24\\n'" in guard and
            "--backend mir-to-c" not in guard,
            "native positive or pre-driver negative evidence weakened")
    require("tiny_host_read_repr_c_probe" not in
            (ROOT / "src/runtime-rs/src/lib.rs").read_text() and
            "tiny_host_read_repr_c_probe" not in
            (ROOT / "Makefile").read_text(),
            "selected test host leaked into packaged runtime")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
