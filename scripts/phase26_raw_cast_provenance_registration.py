#!/usr/bin/env python3
"""Pin Phase26.1E1 raw-cast provenance and its exact registry successors."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-raw-cast-provenance"
SCRIPT = "scripts/phase26_raw_cast_provenance.sh"
FIXTURES = [
    "compiler/phase26_raw_cast_provenance_test_entry.gst",
    "compiler/phase26_raw_cast_safe_brand_rejected_source.gst",
    "compiler/phase26_raw_cast_unsafe_source.gst",
]
SURFACES = {
    ".github/workflows/pr-fast.yml",
    "compiler/mir_native_backend_full_program_source.gst",
    "compiler/typechecker.gst",
    "justfile",
    "scripts/cranelift_test_levels.json",
    "scripts/phase22_opening.py",
    "scripts/phase26_ffi_repr_c_registration.py",
    "scripts/phase26_ffi_repr_c_write_registration.py",
    "scripts/phase26_ffi_raw_return_registration.py",
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
    record = activation.get("raw_cast_provenance_increment", {})
    d5 = activation.get("ffi_isolated_read_increment", {})
    d5_rows = {row["path"]: row for row in d5.get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])}
    d6_rows = {row["path"]: row for row in activation.get(
        "ffi_isolated_write_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])}
    e2_rows = {row["path"]: row for row in activation.get(
        "reference_return_escape_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])}
    e3_rows = {row["path"]: row for row in activation.get(
        "safe_reference_call_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])}
    expected = {
        "contract_version": "phase26_1e1_raw_cast_provenance_v1",
        "status": "raw_pointer_cast_safe_brand_laundering_rejected",
        "owner": "cranelift", "increment": "26.1E1",
        "raw_target_provenance": "raw_derived_unbrandable",
        "existing_raw_and_sandbox_taint": "preserved",
        "bare_null_index_sentinel": "preserved",
        "unsafe_cast_gate": "preserved",
        "scratch_string_return_copy": "arena_owned_before_return",
        "positive_fixture": FIXTURES[0],
        "negative_fixtures": FIXTURES[1:],
        "failure_stage": "before_driver_discovery",
        "native_fallback": False, "physical_abi_changed": False,
        "mir_changed": False, "runtime_symbol_surface_changed": False,
        "owning_level2_guard": GUARD,
        "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"registry field drifted: {key}")
    require(set(record) == set(expected) | {
        "phase22_invocation_successor", "production_audit_successor",
        "phase23_text_surface_successor", "spelling_inventory_successor",
        "filename_site_successor",
    }, "registry acquired unreviewed E1 fields")
    for path in FIXTURES:
        require((ROOT / path).is_file(), f"registered fixture missing: {path}")

    from phase22_opening import scan_invocations
    invocation = record["phase22_invocation_successor"]
    require(invocation.get("contract_version") ==
            "phase26_1e1_phase22_invocation_successor_v1" and
            invocation.get("previous_total") == 163 and
            invocation.get("current_total") == 165 and
            invocation.get("partial_extra_or_substituted_invocation") ==
            "rejected" and
            [row for row in scan_invocations() if row["path"] == SCRIPT] ==
            invocation.get("added_rows"), "native invocation rows drifted")
    require(record["production_audit_successor"] == {
        "contract_version": "phase26_1e1_production_audit_successor_v1",
        "previous_repository_invocation_count": 163,
        "current_repository_invocation_count": 165,
        "added_invocation_path": SCRIPT,
        "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "production audit successor drifted")

    from phase24_filename_behavior_characterization import source_sites
    previous = activation["ffi_raw_return_increment"]["filename_site_successor"]["current_sites"]
    filename = record["filename_site_successor"]
    current = (d5.get("filename_site_successor", {}).get("previous_sites")
               if d5 else source_sites())
    require(filename.get("contract_version") ==
            "phase26_1e1_filename_site_successor_v1" and
            filename.get("previous_sites") == previous and
            filename.get("current_sites") == current and
            filename.get("line_delta") == 11 and
            filename.get("partial_extra_or_substituted_site") == "rejected" and
            len(previous) == len(current) == 3 and
            all(now["line"] == before["line"] + 11 and
                {key: val for key, val in now.items() if key != "line"} ==
                {key: val for key, val in before.items() if key != "line"}
                for before, now in zip(previous, current)),
            "filename sites changed beyond E1 line shift")

    surfaces = record["phase23_text_surface_successor"]
    changed = surfaces.get("changed_rows", [])
    added = surfaces.get("added_rows", [])
    require(surfaces.get("contract_version") ==
            "phase26_1e1_phase23_text_surface_successor_v1" and
            surfaces.get("partial_extra_or_substituted_surface") ==
            "rejected" and len(changed) == len(SURFACES) and
            {row.get("path") for row in changed} == SURFACES and
            len(added) == 1 and added[0].get("path") ==
            "scripts/phase26_raw_cast_provenance_registration.py",
            "Phase23 text surface successor drifted")
    d4 = {row["path"]: row for row in activation[
        "ffi_raw_return_increment"]["phase23_text_surface_successor"][
            "changed_rows"]}
    d4_added = {row["path"]: row for row in activation[
        "ffi_raw_return_increment"]["phase23_text_surface_successor"][
            "added_rows"]}
    for row in changed:
        predecessor = d4.get(row["path"])
        added_predecessor = d4_added.get(row["path"])
        next_row = d5_rows.get(row["path"])
        d6_row = d6_rows.get(row["path"])
        e2_row = e2_rows.get(row["path"])
        e3_row = e3_rows.get(row["path"])
        latest_before_e2 = (d6_row["current_digest"] if d6_row else
                            next_row["current_digest"] if next_row else
                            row["current_digest"])
        require(len(row["previous_digest"]) == 64 and
                (predecessor is None or
                 row["previous_digest"] == predecessor["current_digest"]) and
                (added_predecessor is None or
                 row["previous_digest"] == added_predecessor["digest"]) and
                (next_row is None or
                 next_row["previous_digest"] == row["current_digest"]) and
                (d6_row is None or d6_row["previous_digest"] ==
                 (next_row["current_digest"] if next_row else row["current_digest"])) and
                (e2_row is None or e2_row["previous_digest"] == latest_before_e2) and
                (e3_row is None or e3_row["previous_digest"] ==
                 (e2_row["current_digest"] if e2_row else latest_before_e2)) and
                digest(row["path"]) ==
                (e3_row["current_digest"] if e3_row else
                 e2_row["current_digest"] if e2_row else latest_before_e2),
                f"text surface predecessor/current digest drifted: {row['path']}")
    added_next = d5_rows.get(added[0]["path"])
    added_d6 = d6_rows.get(added[0]["path"])
    added_e2 = e2_rows.get(added[0]["path"])
    added_e3 = e3_rows.get(added[0]["path"])
    added_before_e2 = (added_d6["current_digest"] if added_d6 else
                       added_next["current_digest"] if added_next else
                       added[0]["digest"])
    require((added_next is None or
             added_next["previous_digest"] == added[0]["digest"]) and
            (added_d6 is None or added_d6["previous_digest"] ==
             (added_next["current_digest"] if added_next else added[0]["digest"])) and
            (added_e2 is None or
             added_e2["previous_digest"] == added_before_e2) and
            (added_e3 is None or added_e3["previous_digest"] ==
             (added_e2["current_digest"] if added_e2 else added_before_e2)) and
            digest(added[0]["path"]) ==
            (added_e3["current_digest"] if added_e3 else
             added_e2["current_digest"] if added_e2 else added_before_e2),
            "added registration text surface drifted")

    spelling = record["spelling_inventory_successor"]
    from phase24_semantic_spelling_inventory import source_sites as spelling_sites, manifest_summary
    current_summary = (d5.get("spelling_inventory_successor", {}).get(
        "previous_inventory_summary") if d5 else
        manifest_summary(spelling_sites()))
    require(spelling.get("contract_version") ==
            "phase26_1e1_spelling_inventory_successor_v1" and
            spelling.get("previous_inventory_summary") == activation[
                "ffi_raw_return_increment"]["spelling_inventory_successor"][
                    "current_inventory_summary"] and
            spelling.get("current_inventory_summary") == current_summary and
            spelling.get("changed_source_paths") == sorted([
                "compiler/typechecker.gst",
                "compiler/mir_native_backend_full_program_source.gst",
                *FIXTURES]) and
            spelling.get("partial_extra_or_substituted_inventory") ==
            "rejected", "spelling inventory successor drifted")

    justfile = (ROOT / "justfile").read_text()
    workflow = (ROOT / ".github/workflows/pr-fast.yml").read_text()
    guard = (ROOT / SCRIPT).read_text()
    require(justfile.count(f"{GUARD}:") == 1 and
            "python3 scripts/phase26_raw_cast_provenance_registration.py" in
            justfile and workflow.count(f"just {GUARD}") == 1,
            "required Level2 registration path drifted")
    require("GUST_TEST_MIR_TO_C_UNAVAILABLE=1" in guard and
            "source_feature_not_represented" in guard and
            "Non-laundering violation" in guard and
            "poison-driver.invoked" in guard and
            "SUCCESS: raw-pointer cast provenance" in guard and
            "--backend mir-to-c" not in guard,
            "native provenance or no-fallback evidence weakened")
    require((ROOT / "compiler/mir_native_backend_full_program_source.gst")
            .read_text().count(
                "return std.Clone(ctx, *(((header_ptr as *str) + 0) as *str));")
            == 2, "self-hosting scratch strings are not copied before return")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
