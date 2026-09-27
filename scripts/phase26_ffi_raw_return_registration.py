#!/usr/bin/env python3
"""Pin Phase26.1D4's unowned raw-pointer return and exact successors."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-ffi-raw-return"
SCRIPT = "scripts/phase26_ffi_raw_return.sh"
FIXTURES = [
    "compiler/phase26_ffi_raw_return_source.gst",
    "compiler/phase26_ffi_raw_return_policy_test_entry.gst",
    *[f"compiler/phase26_ffi_raw_return_{name}_source.gst"
      for name in ("missing", "unknown_host", "wrong_inner", "reference",
                   "str", "slice", "transfer", "scalar_policy", "nonextern",
                   "unsafe_call", "unsafe_deref")],
]
SURFACES = {
    ".github/workflows/pr-fast.yml",
    "compiler/experiments/cranelift/src/full_program.rs",
    "compiler/experiments/cranelift/src/main.rs",
    "compiler/mir_native_backend_full_program_source.gst",
    "compiler/typechecker.gst",
    "justfile", "scripts/cranelift_test_levels.json",
    "scripts/phase22_opening.py",
    "scripts/phase26_ffi_repr_c_registration.py",
    "scripts/phase26_ffi_repr_c_write_registration.py",
    "scripts/phase26_reference_receiver_registration.py",
}


def require(value: bool, message: str) -> None:
    if not value:
        raise SystemExit(f"{GUARD}: {message}")


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def main() -> None:
    registry = json.loads((ROOT / "scripts/cranelift_feature_registry.json")
                          .read_text(encoding="utf-8"))
    activation = registry.get("phase26_activation_audit", {})
    record = activation.get("ffi_raw_return_increment", {})
    expected = {
        "contract_version": "phase26_1d4_ffi_raw_return_v1",
        "status": "selected_unowned_raw_pointer_return_qualified",
        "owner": "cranelift", "increment": "26.1D4",
        "declared_return_policy": "raw_untrusted",
        "canonical_return_provenance": "raw_derived_unbrandable",
        "unsafe_call_and_dereference": "explicit_unsafe_required",
        "supported_position": "extern_raw_pointer_return_only",
        "selected_host_import": "tiny_host_raw_untrusted_int",
        "selected_host_object": "generated_test_only_existing_host_object_slot",
        "positive_fixture": FIXTURES[0],
        "provenance_fixture": FIXTURES[1],
        "negative_fixtures": FIXTURES[2:],
        "failure_stage": "before_driver_discovery",
        "deferral_reason": "deferred_p26_ffi_raw_return_host_contract",
        "native_fallback": False, "physical_abi_changed": False,
        "runtime_symbol_surface_changed": False,
        "unsupported_shapes": [
            "reference_return", "str_return", "slice_return", "transfer",
            "retain", "callback", "native_error", "packed", "enum",
            "by_value_aggregate", "isolated_arena", "general_lifetime_algebra",
        ],
        "owning_level2_guard": GUARD,
        "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"registry field drifted: {key}")
    require(set(record) == set(expected) | {
        "phase22_invocation_successor", "production_audit_successor",
        "phase23_text_surface_successor", "spelling_inventory_successor",
        "filename_site_successor",
    }, "registry acquired unreviewed D4 fields")
    for path in FIXTURES:
        require((ROOT / path).is_file(), f"registered fixture missing: {path}")

    from phase24_filename_behavior_characterization import source_sites
    d1_sites = activation["ffi_position_policy_increment"]["filename_site_successor"]["current_sites"]
    filename = record["filename_site_successor"]
    live_sites = source_sites()
    e1_filename = activation.get("raw_cast_provenance_increment", {}).get(
        "filename_site_successor")
    d4_current = (e1_filename["previous_sites"] if e1_filename else live_sites)
    require(filename.get("contract_version") ==
            "phase26_1d4_filename_site_successor_v1" and
            filename.get("previous_sites") == d1_sites and
            filename.get("current_sites") == d4_current and
            filename.get("line_delta") == 24 and
            filename.get("partial_extra_or_substituted_site") == "rejected" and
            len(d1_sites) == len(d4_current) == 3 and
            all(now["line"] == before["line"] + 24 and
                {key: val for key, val in now.items() if key != "line"} ==
                {key: val for key, val in before.items() if key != "line"}
                for before, now in zip(d1_sites, d4_current)),
            "D4 filename-selected sites changed beyond the exact line shift")

    from phase22_opening import scan_invocations
    invocation = record["phase22_invocation_successor"]
    require(invocation.get("contract_version") ==
            "phase26_1d4_phase22_invocation_successor_v1" and
            invocation.get("previous_total") == 160 and
            invocation.get("current_total") == 163 and
            invocation.get("partial_extra_or_substituted_invocation") ==
            "rejected" and
            [row for row in scan_invocations() if row["path"] == SCRIPT] ==
            invocation.get("added_rows"), "native invocation rows drifted")

    production = record["production_audit_successor"]
    require(production == {
        "contract_version": "phase26_1d4_production_audit_successor_v1",
        "previous_repository_invocation_count": 160,
        "current_repository_invocation_count": 163,
        "added_invocation_path": SCRIPT,
        "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "production audit successor drifted")

    surfaces = record["phase23_text_surface_successor"]
    changed = surfaces.get("changed_rows", [])
    added = surfaces.get("added_rows", [])
    require(surfaces.get("contract_version") ==
            "phase26_1d4_phase23_text_surface_successor_v1" and
            surfaces.get("partial_extra_or_substituted_surface") ==
            "rejected" and len(changed) == len(SURFACES) and
            {row.get("path") for row in changed} == SURFACES and
            len(added) == 1 and added[0].get("path") ==
            "scripts/phase26_ffi_raw_return_registration.py",
            "Phase23 text surface successor drifted")
    d3 = {row["path"]: row for row in activation[
        "ffi_repr_c_write_increment"]["phase23_text_surface_successor"][
            "changed_rows"]}
    d3_added = {row["path"]: row for row in activation[
        "ffi_repr_c_write_increment"]["phase23_text_surface_successor"][
            "added_rows"]}
    for row in changed:
        predecessor = d3.get(row["path"])
        added_predecessor = d3_added.get(row["path"])
        e1_successor = {entry["path"]: entry for entry in activation.get(
            "raw_cast_provenance_increment", {}).get(
                "phase23_text_surface_successor", {}).get("changed_rows", [])}.get(row["path"])
        require(len(row["previous_digest"]) == 64 and
                (predecessor is None or
                 row["previous_digest"] == predecessor["current_digest"]) and
                (added_predecessor is None or
                 row["previous_digest"] == added_predecessor["digest"]) and
                digest(row["path"]) == (e1_successor["current_digest"] if
                                        e1_successor else row["current_digest"]) and
                (e1_successor is None or
                 e1_successor["previous_digest"] == row["current_digest"]),
                f"text surface predecessor/current digest drifted: {row['path']}")
    added_successor = {entry["path"]: entry for entry in activation.get(
        "raw_cast_provenance_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])}.get(
                added[0]["path"])
    require(digest(added[0]["path"]) ==
            (added_successor["current_digest"] if added_successor else
             added[0]["digest"]) and
            (added_successor is None or
             added_successor["previous_digest"] == added[0]["digest"]),
            "added registration text surface drifted")

    justfile = (ROOT / "justfile").read_text()
    workflow = (ROOT / ".github/workflows/pr-fast.yml").read_text()
    guard = (ROOT / SCRIPT).read_text()
    require(justfile.count(f"{GUARD}:") == 1 and
            "python3 scripts/phase26_ffi_raw_return_registration.py" in
            justfile and workflow.count(f"just {GUARD}") == 1,
            "required Level2 registration path drifted")
    require("GUST_TEST_MIR_TO_C_UNAVAILABLE=1" in guard and
            "deferred_p26_ffi_raw_return_host_contract" in guard and
            "poison-driver.invoked" in guard and
            "printf '37\\n'" in guard and
            "raw-derived and unbrandable" in guard and
            "--backend mir-to-c" not in guard and
            all(name in guard for name in (
                "missing unknown_host wrong_inner reference str slice transfer",
                "scalar_policy nonextern unsafe_call unsafe_deref")),
            "native positive or pre-driver negative evidence weakened")
    require("tiny_host_raw_untrusted_int" not in
            (ROOT / "src/runtime-rs/src/lib.rs").read_text() and
            "tiny_host_raw_untrusted_int" not in
            (ROOT / "Makefile").read_text(),
            "selected test host leaked into packaged runtime")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
