#!/usr/bin/env python3
"""Pin Phase26.1D3's selected native raw-pointer write contract."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-ffi-repr-c-write"
SCRIPT = "scripts/phase26_ffi_repr_c_write.sh"
FIXTURES = ["compiler/phase26_ffi_repr_c_write_source.gst", *[
    f"compiler/phase26_ffi_repr_c_write_{name}_source.gst"
    for name in ("missing", "order", "packed", "nested", "unknown_host",
                 "enum")
]]
SURFACES = {
    ".github/workflows/pr-fast.yml",
    "compiler/experiments/cranelift/src/full_program.rs",
    "compiler/experiments/cranelift/src/main.rs",
    "compiler/mir_native_backend_full_program_source.gst",
    "justfile", "scripts/cranelift_test_levels.json",
    "scripts/phase22_opening.py",
    "scripts/phase26_ffi_repr_c_registration.py",
    "scripts/phase26_reference_receiver_registration.py",
}


def require(value: bool, message: str) -> None:
    if not value:
        raise SystemExit(f"{GUARD}: {message}")


def main() -> None:
    registry = json.loads((ROOT / "scripts/cranelift_feature_registry.json")
                          .read_text(encoding="utf-8"))
    record = registry.get("phase26_activation_audit", {}).get(
        "ffi_repr_c_write_increment", {})
    expected = {
        "contract_version": "phase26_1d3_ffi_repr_c_write_v1",
        "status": "selected_flat_borrowed_repr_c_raw_write_qualified",
        "owner": "cranelift", "increment": "26.1D3",
        "canonical_layout_metadata": "existing_full_program_layout_rows",
        "target_layout_authority":
            "phase14_declared_x86_64_linux_pointer_and_i32_alignment",
        "supported_position":
            "borrow_write_call_raw_pointer_to_flat_repr_c_struct",
        "selected_host_import": "tiny_host_write_repr_c_probe",
        "selected_host_object": "generated_test_only_existing_host_object_slot",
        "positive_fixture": FIXTURES[0],
        "negative_fixtures": FIXTURES[1:],
        "failure_stage": "before_driver_discovery",
        "deferral_reason": "deferred_p26_ffi_borrowed_c_layout",
        "native_fallback": False, "physical_abi_changed": False,
        "runtime_symbol_surface_changed": False,
        "unsupported_shapes": [
            "packed", "enum", "by_value_aggregate", "nested_aggregate",
            "unapproved_host", "transfer", "retain", "returned_pointer",
            "callback", "native_error", "isolated_arena",
        ],
        "owning_level2_guard": GUARD,
        "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"registry field drifted: {key}")
    require(set(record) == set(expected) | {
        "phase22_invocation_successor", "production_audit_successor",
        "phase23_text_surface_successor", "spelling_inventory_successor",
    }, "registry acquired unreviewed D3 fields")
    for path in FIXTURES:
        require((ROOT / path).is_file(), f"registered fixture missing: {path}")

    from phase22_opening import scan_invocations
    invocation = record["phase22_invocation_successor"]
    require(invocation.get("contract_version") ==
            "phase26_1d3_phase22_invocation_successor_v1" and
            invocation.get("previous_total") == 158 and
            invocation.get("current_total") == 160 and
            invocation.get("partial_extra_or_substituted_invocation") ==
            "rejected" and
            [row for row in scan_invocations() if row["path"] == SCRIPT] ==
            invocation.get("added_rows"), "native invocation rows drifted")

    surfaces = record["phase23_text_surface_successor"]
    changed = surfaces.get("changed_rows", [])
    added = surfaces.get("added_rows", [])
    require(surfaces.get("contract_version") ==
            "phase26_1d3_phase23_text_surface_successor_v1" and
            surfaces.get("partial_extra_or_substituted_surface") ==
            "rejected" and len(changed) == len(SURFACES) and
            {row.get("path") for row in changed} == SURFACES and
            len(added) == 1 and added[0].get("path") ==
            "scripts/phase26_ffi_repr_c_write_registration.py",
            "Phase23 text surface successor drifted")
    d2_rows = {row["path"]: row for row in registry[
        "phase26_activation_audit"]["ffi_repr_c_layout_increment"][
        "phase23_text_surface_successor"]["changed_rows"]}
    d4_rows = {row["path"]: row for row in registry[
        "phase26_activation_audit"].get("ffi_raw_return_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])}
    for row in surfaces["changed_rows"]:
        predecessor = d2_rows.get(row["path"])
        successor = d4_rows.get(row["path"])
        require(len(row["previous_digest"]) == 64 and
                (predecessor is None or
                 row["previous_digest"] == predecessor["current_digest"]),
                f"text surface predecessor drifted: {row['path']}")
        require(hashlib.sha256((ROOT / row["path"]).read_bytes()).hexdigest()
                == (successor["current_digest"] if successor else
                    row["current_digest"]) and
                (successor is None or
                 successor["previous_digest"] == row["current_digest"]),
                f"text surface digest drifted: {row['path']}")
    for row in surfaces["added_rows"]:
        successor = d4_rows.get(row["path"])
        require(hashlib.sha256((ROOT / row["path"]).read_bytes()).hexdigest()
                == (successor["current_digest"] if successor else
                    row["digest"]) and
                (successor is None or
                 successor["previous_digest"] == row["digest"]),
                f"added text surface digest drifted: {row['path']}")

    workflow = (ROOT / ".github/workflows/pr-fast.yml").read_text()
    justfile = (ROOT / "justfile").read_text()
    guard = (ROOT / SCRIPT).read_text()
    require(workflow.count(f"just {GUARD}") == 1 and
            justfile.count(f"{GUARD}:") == 1 and
            "python3 scripts/phase26_ffi_repr_c_write_registration.py" in
            justfile, "required Level2 registration path drifted")
    require("GUST_TEST_MIR_TO_C_UNAVAILABLE=1" in guard and
            "deferred_p26_ffi_borrowed_c_layout" in guard and
            "poison-driver.invoked" in guard and
            "printf '20\\n30\\n4\\n'" in guard and
            "missing order packed nested unknown_host enum" in guard and
            "--backend mir-to-c" not in guard,
            "native write or pre-driver evidence weakened")
    require("tiny_host_write_repr_c_probe" not in
            (ROOT / "src/runtime-rs/src/lib.rs").read_text() and
            "tiny_host_write_repr_c_probe" not in
            (ROOT / "Makefile").read_text(),
            "selected test host leaked into packaged runtime")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
