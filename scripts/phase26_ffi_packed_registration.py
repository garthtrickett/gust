#!/usr/bin/env python3
"""Pin the bounded Phase 26.1 packed FFI layout and unaligned access path."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-ffi-packed-layout"
SCRIPT = "scripts/phase26_ffi_packed_layout.sh"
FIXTURES = [
    "compiler/phase26_ffi_packed_probe_source.gst",
    *[f"compiler/phase26_ffi_packed_{name}_source.gst" for name in (
        "missing", "order", "nested", "enum", "unknown_host", "by_value",
        "safe_field", "field_reference")],
]


def require(value: bool, message: str) -> None:
    if not value:
        raise SystemExit(f"{GUARD}: {message}")


def project_live_digest_to_pre_packed(registry: dict, path: str,
                                      live_digest: str) -> str:
    from phase26_cast_narrowing_zero_registration import before_cast_digest
    live_digest = before_cast_digest(registry.get("phase26_activation_audit", {}),
                                     path, live_digest)
    take_struct_rows = registry.get("phase26_activation_audit", {}).get(
        "take_struct_alias_evidence_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])
    take_struct_selected = [row for row in take_struct_rows if row.get("path") == path]
    require(len(take_struct_selected) <= 1,
            f"duplicate local Struct Take-alias text surface: {path}")
    if take_struct_selected:
        row = take_struct_selected[0]
        require(row["current_digest"] == live_digest and
                len(row["previous_digest"]) == 64,
                f"local Struct Take-alias text surface drifted: {path}")
        live_digest = row["previous_digest"]
    take_rows = registry.get("phase26_activation_audit", {}).get(
        "take_zero_evidence_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])
    take_selected = [row for row in take_rows if row.get("path") == path]
    require(len(take_selected) <= 1,
            f"duplicate take zero text surface: {path}")
    if take_selected:
        row = take_selected[0]
        require(row["current_digest"] == live_digest and
                len(row["previous_digest"]) == 64,
                f"take zero text surface drifted: {path}")
        live_digest = row["previous_digest"]
    match_rows = registry.get("phase26_activation_audit", {}).get(
        "match_zero_evidence_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])
    match_selected = [row for row in match_rows if row.get("path") == path]
    require(len(match_selected) <= 1,
            f"duplicate match zero text surface: {path}")
    if match_selected:
        row = match_selected[0]
        require(row["current_digest"] == live_digest and
                len(row["previous_digest"]) == 64,
                f"match zero text surface drifted: {path}")
        live_digest = row["previous_digest"]
    division_rows = registry.get("phase26_activation_audit", {}).get(
        "division_zero_evidence_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])
    division_selected = [row for row in division_rows if row.get("path") == path]
    require(len(division_selected) <= 1,
            f"duplicate division zero text surface: {path}")
    if division_selected:
        row = division_selected[0]
        require(row["current_digest"] == live_digest and
                len(row["previous_digest"]) == 64,
                f"division zero text surface drifted: {path}")
        live_digest = row["previous_digest"]
    arithmetic_rows = registry.get("phase26_activation_audit", {}).get(
        "arithmetic_zero_evidence_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])
    arithmetic_selected = [row for row in arithmetic_rows if row.get("path") == path]
    require(len(arithmetic_selected) <= 1,
            f"duplicate arithmetic zero text surface: {path}")
    if arithmetic_selected:
        row = arithmetic_selected[0]
        require(row["current_digest"] == live_digest and
                len(row["previous_digest"]) == 64,
                f"arithmetic zero text surface drifted: {path}")
        live_digest = row["previous_digest"]
    nested_rows = registry.get("phase26_activation_audit", {}).get(
        "nested_field_zero_evidence_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])
    nested_selected = [row for row in nested_rows if row.get("path") == path]
    require(len(nested_selected) <= 1,
            f"duplicate nested field-zero text surface: {path}")
    if nested_selected:
        row = nested_selected[0]
        require(row["current_digest"] == live_digest and
                len(row["previous_digest"]) == 64,
                f"nested field-zero text surface drifted: {path}")
        live_digest = row["previous_digest"]
    field_rows = registry.get("phase26_activation_audit", {}).get(
        "field_zero_evidence_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])
    field_selected = [row for row in field_rows if row.get("path") == path]
    require(len(field_selected) <= 1,
            f"duplicate field-zero text surface: {path}")
    if field_selected:
        row = field_selected[0]
        require(row["current_digest"] == live_digest and
                len(row["previous_digest"]) == 64,
                f"field-zero text surface drifted: {path}")
        live_digest = row["previous_digest"]
    computed_rows = registry.get("phase26_activation_audit", {}).get(
        "computed_zero_raw_null_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])
    computed_selected = [row for row in computed_rows if row.get("path") == path]
    require(len(computed_selected) <= 1,
            f"duplicate computed-zero text surface: {path}")
    if computed_selected:
        row = computed_selected[0]
        require(row["current_digest"] == live_digest and
                len(row["previous_digest"]) == 64,
                f"computed-zero text surface drifted: {path}")
        live_digest = row["previous_digest"]
    isolated_write_rows = registry.get("phase26_activation_audit", {}).get(
        "ffi_packed_isolated_write_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])
    isolated_write_selected = [row for row in isolated_write_rows if row.get("path") == path]
    require(len(isolated_write_selected) <= 1,
            f"duplicate packed isolated write text surface: {path}")
    if isolated_write_selected:
        row = isolated_write_selected[0]
        require(row["current_digest"] == live_digest and
                len(row["previous_digest"]) == 64,
                f"packed isolated write text surface drifted: {path}")
        live_digest = row["previous_digest"]
    isolated_rows = registry.get("phase26_activation_audit", {}).get(
        "ffi_packed_isolated_read_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])
    isolated_selected = [row for row in isolated_rows if row.get("path") == path]
    require(len(isolated_selected) <= 1,
            f"duplicate packed isolated read text surface: {path}")
    if isolated_selected:
        row = isolated_selected[0]
        require(row["current_digest"] == live_digest and
                len(row["previous_digest"]) == 64,
                f"packed isolated read text surface drifted: {path}")
        live_digest = row["previous_digest"]
    write_rows = registry.get("phase26_activation_audit", {}).get(
        "ffi_packed_write_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])
    write_selected = [row for row in write_rows if row.get("path") == path]
    require(len(write_selected) <= 1, f"duplicate packed write text surface: {path}")
    if write_selected:
        row = write_selected[0]
        require(row["current_digest"] == live_digest and
                len(row["previous_digest"]) == 64,
                f"packed write text surface drifted: {path}")
        live_digest = row["previous_digest"]
    rows = registry.get("phase26_activation_audit", {}).get(
        "ffi_packed_layout_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])
    selected = [row for row in rows if row.get("path") == path]
    require(len(selected) <= 1, f"duplicate packed text surface: {path}")
    if not selected:
        return live_digest
    row = selected[0]
    require(row["current_digest"] == live_digest and
            len(row["previous_digest"]) == 64,
            f"packed text surface drifted: {path}")
    return str(row["previous_digest"])


def main() -> None:
    registry = json.loads((ROOT / "scripts/cranelift_feature_registry.json")
                          .read_text(encoding="utf-8"))
    activation = registry.get("phase26_activation_audit", {})
    record = activation.get("ffi_packed_layout_increment", {})
    expected = {
        "contract_version": "phase26_1d_packed_flat_ffi_layout_v1",
        "status": "selected_flat_packed_repr_c_borrow_qualified",
        "owner": "cranelift", "increment": "26.1D_packed_layout_subset",
        "operator_ownership_decision": "2026-09-27_bounded_physical_layout",
        "supported_position": "unsafe_borrow_read_call_reference_to_flat_packed_repr_c_struct",
        "selected_host_import": "tiny_host_read_packed_probe",
        "selected_host_object": "generated_test_only_existing_host_object_slot",
        "physical_abi_changed": False,
        "target_layout": "x86_64_linux_elf_byte_int_byte_offsets_0_1_5_size_6_align_1",
        "unaligned_int_access": "unsafe_source_and_bytewise_native_load_store",
        "field_reference": "rejected",
        "positive_fixture": FIXTURES[0],
        "negative_fixtures": FIXTURES[1:],
        "failure_stage": "before_driver_discovery",
        "deferral_reason": "deferred_p26_ffi_borrowed_c_layout",
        "native_fallback": False,
        "runtime_symbol_surface_changed": False,
        "remaining_layout_obligations": ["general_packed_layout", "enum_representation",
                                         "by_value_aggregate", "nested_aggregate"],
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"registry field drifted: {key}")
    require(set(record) == set(expected) | {
        "phase22_invocation_successor", "production_audit_successor",
        "phase23_text_surface_successor", "spelling_inventory_successor",
        "filename_site_successor",
    }, "registry acquired unreviewed packed fields")
    for path in FIXTURES:
        require((ROOT / path).is_file(), f"registered fixture missing: {path}")

    from phase22_opening import scan_invocations
    invocation = record["phase22_invocation_successor"]
    added = invocation.get("added_rows")
    require(invocation.get("contract_version") ==
            "phase26_1d_packed_phase22_invocation_successor_v1" and
            invocation.get("previous_total") == 179 and
            invocation.get("current_total") == 179 + len(added) and
            invocation.get("partial_extra_or_substituted_invocation") ==
            "rejected" and
            [row for row in scan_invocations() if row["path"] == SCRIPT] == added,
            "native invocation successor drifted")
    require(record["production_audit_successor"] == {
        "contract_version": "phase26_1d_packed_production_audit_successor_v1",
        "previous_repository_invocation_count": 179,
        "current_repository_invocation_count": 179 + len(added),
        "added_invocation_path": SCRIPT,
        "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "production audit successor drifted")

    from phase24_semantic_spelling_inventory import source_sites, manifest_summary
    spelling = record["spelling_inventory_successor"]
    write_spelling = activation.get("ffi_packed_write_increment", {}).get(
        "spelling_inventory_successor")
    require(spelling.get("contract_version") ==
            "phase26_1d_packed_spelling_inventory_successor_v1" and
            spelling.get("previous_inventory_summary") ==
            activation["raw_null_safe_boundary_increment"][
                "spelling_inventory_successor"]["current_inventory_summary"] and
            spelling.get("current_inventory_summary") ==
            (manifest_summary(source_sites()) if write_spelling is None else
             write_spelling.get("previous_inventory_summary")) and
            spelling.get("changed_source_paths") == sorted([
                "compiler/typechecker.gst", *FIXTURES]) and
            spelling.get("partial_extra_or_substituted_inventory") == "rejected",
            "spelling inventory successor drifted")

    from phase24_filename_behavior_characterization import source_sites as filename_sites
    filename = record["filename_site_successor"]
    previous = activation["raw_null_safe_boundary_increment"][
        "filename_site_successor"]["current_sites"]
    current = filename_sites()
    computed_filename = activation.get("computed_zero_raw_null_increment", {}).get(
        "filename_site_successor")
    packed_current = (current if computed_filename is None else
                      computed_filename.get("previous_sites"))
    deltas = filename.get("line_deltas")
    require(filename.get("contract_version") ==
            "phase26_1d_packed_filename_site_successor_v1" and
            filename.get("previous_sites") == previous and
            filename.get("current_sites") == packed_current and
            isinstance(deltas, list) and len(deltas) == len(packed_current) and
            all(now["line"] == before["line"] + delta and
                {key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now, delta in zip(previous, packed_current, deltas)) and
            filename.get("partial_extra_or_substituted_site") == "rejected",
            "filename site successor drifted")

    surface = record["phase23_text_surface_successor"]
    require(surface.get("contract_version") ==
            "phase26_1d_packed_phase23_text_surface_successor_v1" and
            surface.get("partial_extra_or_substituted_surface") == "rejected" and
            len({row["path"] for row in surface.get("changed_rows", [])}) ==
            len(surface.get("changed_rows", [])) and
            len({row["path"] for row in surface.get("added_rows", [])}) ==
            len(surface.get("added_rows", [])),
            "text surface successor shape drifted")

    justfile = (ROOT / "justfile").read_text(encoding="utf-8")
    workflow = (ROOT / ".github/workflows/pr-fast.yml").read_text(encoding="utf-8")
    guard = (ROOT / SCRIPT).read_text(encoding="utf-8")
    require(justfile.count(f"{GUARD}:") == 1 and
            "python3 scripts/phase26_ffi_packed_registration.py" in justfile and
            workflow.count(f"just {GUARD}") == 1 and
            "poison-driver.invoked" in guard and
            "[PackedFieldUnsafe]" in guard and
            "[PackedFieldReference]" in guard and
            "deferred_p26_ffi_borrowed_c_layout" in guard,
            "packed native evidence weakened")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
