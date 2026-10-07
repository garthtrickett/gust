#!/usr/bin/env python3
"""Pin the bounded synchronous C callback and its canonical authority."""

import json
import hashlib
from pathlib import Path
from phase26_ffi_native_error_status_registration import (
    before_prefix_memory_digest, before_prefix_memory_spelling,
    before_prefix_memory_filename,
)

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-ffi-callback-sync"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def main() -> None:
    registry = json.loads((ROOT / "scripts/cranelift_feature_registry.json").read_text())
    record = registry["phase26_activation_audit"]["ffi_callback_sync_increment"]
    expected = {
        "contract_version": "phase26_1d_callback_sync_v1",
        "status": "bounded_noncapturing_synchronous_c_callback_qualified",
        "owner": "cranelift",
        "increment": "26.1D_callback_sync",
        "supported_target": "x86_64-unknown-linux-gnu",
        "canonical_call_variant": "6_callback_call_v1",
        "legacy_call_variants": [0, 1, 2, 3, 4, 5],
        "selected_policy": "callback",
        "signature": "compiler_owned_Callback_int_int",
        "function_address_provenance": "named_noncapturing_Gust_int_to_int_function",
        "scope": "single_synchronous_unsafe_C_call",
        "unsupported_routes": ["retain", "capture", "general_function_pointer", "native_error", "unwind"],
        "positive_fixture": "compiler/phase26_ffi_callback_sync_source.gst",
        "host_object_source": "tests/cranelift/phase26_callback_sync_hosts.c",
        "owning_level2_guard": GUARD,
        "native_fallback": False,
        "runtime_symbol_surface_changed": False,
    }
    require({key: record.get(key) for key in expected} == expected,
            "callback contract drifted")
    require(set(record) == set(expected) | {
        "phase22_invocation_successor", "production_audit_successor",
        "phase23_text_surface_successor", "spelling_inventory_successor",
        "filename_site_successor", "legacy_position_callback_diagnostic_successor",
    }, "callback acquired unreviewed fields")
    from phase22_opening import scan_invocations
    rows = [row for row in scan_invocations()
            if row["path"] == "scripts/phase26_ffi_callback_sync.sh"]
    require(record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1d_callback_sync_phase22_invocation_successor_v1",
        "previous_total": 250,
        "current_total": 252,
        "added_rows": rows,
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows) == 2 and all(row["selection"] == "explicit_cranelift"
                                 for row in rows),
            "callback invocation successor drifted")
    require(record["production_audit_successor"] == {
        "contract_version": "phase26_1d_callback_sync_production_audit_successor_v1",
        "previous_repository_invocation_count": 250,
        "current_repository_invocation_count": 252,
        "added_invocation_path": "scripts/phase26_ffi_callback_sync.sh",
        "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "callback production audit successor drifted")
    surface = record["phase23_text_surface_successor"]
    native_error = registry["phase26_activation_audit"].get(
        "ffi_native_error_status_increment", {})
    native_rows = native_error.get("phase23_text_surface_successor", {}).get(
        "changed_rows", [])
    native_by_path = {row["path"]: row for row in native_rows}
    vector = registry["phase26_activation_audit"].get(
        "ffi_policy_vector_status_increment", {})
    vector_rows = vector.get("phase23_text_surface_successor", {}).get(
        "changed_rows", [])
    vector_by_path = {row["path"]: row for row in vector_rows}
    require(len(vector_by_path) == len(vector_rows),
            "duplicate policy-vector text surface")
    require(len(native_by_path) == len(native_rows),
            "duplicate native-error text surface")
    expected_paths = [
        ".github/workflows/pr-fast.yml",
        "compiler/experiments/cranelift/src/full_program.rs",
        "compiler/mir_native_backend_full_program_source.gst",
        "compiler/typechecker.gst", "justfile",
        "scripts/cranelift_test_levels.json", "scripts/phase22_opening.py",
        "scripts/phase26_call_return_zero_registration.py",
    ]
    require(surface["contract_version"] ==
            "phase26_1d_callback_sync_phase23_text_surface_successor_v1" and
            surface["added_rows"] == [] and
            surface["partial_extra_or_substituted_surface"] == "rejected" and
            [row["path"] for row in surface["changed_rows"]] == expected_paths,
            "callback text surface successor shape drifted")
    for row in surface["changed_rows"]:
        current = hashlib.sha256((ROOT / row["path"]).read_bytes()).hexdigest()
        vector_row = vector_by_path.get(row["path"])
        if vector_row is not None:
            require(vector_row["current_digest"] == current and
                    vector_row["previous_match_counts"] ==
                    vector_row["current_match_counts"],
                    f"policy-vector text successor drifted: {row['path']}")
            current = vector_row["previous_digest"]
        current = before_prefix_memory_digest(
            registry["phase26_activation_audit"], row["path"], current)
        successor = native_by_path.get(row["path"])
        if successor is not None:
            require(successor["current_digest"] == current and
                    successor["previous_digest"] == row["current_digest"],
                    f"native-error text successor drifted: {row['path']}")
            current = successor["previous_digest"]
        require(current == row["current_digest"] and
                len(row["previous_digest"]) == 64 and
                row["previous_match_counts"] == row["current_match_counts"],
                f"callback text surface drifted: {row['path']}")
    from phase24_semantic_spelling_inventory import source_sites, manifest_summary
    spelling = record["spelling_inventory_successor"]
    previous = registry["phase26_activation_audit"]["ffi_retained_lease_increment"][
        "spelling_inventory_successor"]["current_inventory_summary"]
    live_inventory = manifest_summary(source_sites())
    vector_spelling = vector.get("spelling_inventory_successor")
    if vector_spelling is not None:
        require(vector_spelling["current_inventory_summary"] == live_inventory and
                vector_spelling["previous_inventory_summary"] ==
                registry["phase26_activation_audit"]["prefix_resolution_memory_prerequisite"]["spelling_inventory_successor"]["current_inventory_summary"],
                "policy-vector spelling inventory successor drifted")
        live_inventory = vector_spelling["previous_inventory_summary"]
    live_inventory = before_prefix_memory_spelling(
        registry["phase26_activation_audit"], live_inventory)
    native_spelling = native_error.get("spelling_inventory_successor")
    if native_spelling is not None:
        require(native_spelling["current_inventory_summary"] == live_inventory and
                native_spelling["previous_inventory_summary"] ==
                spelling["current_inventory_summary"],
                "native-error spelling inventory successor drifted")
        live_inventory = native_spelling["previous_inventory_summary"]
    require(spelling["contract_version"] ==
            "phase26_1d_callback_sync_spelling_inventory_successor_v1" and
            spelling["previous_inventory_summary"] == previous and
            spelling["current_inventory_summary"] == live_inventory and
            spelling["partial_extra_or_substituted_inventory"] == "rejected",
            "callback spelling inventory successor drifted")
    from phase24_filename_behavior_characterization import source_sites as filename_source_sites
    filename = record["filename_site_successor"]
    previous_sites = registry["phase26_activation_audit"]["ffi_retained_lease_increment"][
        "filename_site_successor"]["current_sites"]
    current_sites = filename_source_sites()
    vector_sites = vector.get("filename_site_successor")
    if vector_sites is not None:
        require(vector_sites["current_sites"] == current_sites and
                vector_sites["previous_sites"] ==
                registry["phase26_activation_audit"]["prefix_resolution_memory_prerequisite"]["filename_site_successor"]["current_sites"],
                "policy-vector filename successor drifted")
        current_sites = vector_sites["previous_sites"]
    current_sites = before_prefix_memory_filename(
        registry["phase26_activation_audit"], current_sites)
    native_sites = native_error.get("filename_site_successor")
    if native_sites is not None:
        require(native_sites["current_sites"] == current_sites and
                native_sites["previous_sites"] == filename["current_sites"],
                "native-error filename successor drifted")
        current_sites = native_sites["previous_sites"]
    require(filename == {
        "contract_version": "phase26_1d_callback_sync_filename_site_successor_v1",
        "previous_sites": previous_sites,
        "current_sites": current_sites,
        "line_deltas": [95, 95, 95],
        "partial_extra_or_substituted_site": "rejected",
    } and len(previous_sites) == len(current_sites) == 3 and
            all(now["line"] == before["line"] + 95 and
                {key: val for key, val in now.items() if key != "line"} ==
                {key: val for key, val in before.items() if key != "line"}
                for before, now in zip(previous_sites, current_sites)),
            "callback filename site successor drifted")
    diagnostic = record["legacy_position_callback_diagnostic_successor"]
    position_guard = (ROOT / "scripts/phase26_ffi_position_policy.sh").read_text()
    transfer_guard = (ROOT / "scripts/phase26_ffi_transfer_owned.sh").read_text()
    require(diagnostic == {
        "contract_version": "phase26_1d_callback_sync_legacy_position_diagnostic_successor_v1",
        "source_fixture": "compiler/phase26_ffi_callback_invalid.gst",
        "transfer_fixture": "scripts/phase26_ffi_transfer_owned.sh:callback_policy",
        "previous_diagnostic": "FFICallbackNativeErrorUnsupported",
        "current_diagnostic": "FFICallbackSignature",
        "native_error_diagnostic": "FFICallbackNativeErrorUnsupported",
        "failure_stage": "source_typechecking_before_driver",
        "other_position_cases_preserved": True,
        "poison_driver_invoked": False,
        "native_artifact_emitted": False,
    } and "'callback|FFICallbackSignature'" in position_guard and
            "'native_error|FFICallbackNativeErrorUnsupported'" in position_guard and
            "callback_policy) expected='[FFICallbackSignature]'" in transfer_guard and
            "native_error_policy) expected='[FFICallbackNativeErrorUnsupported]'" in transfer_guard and
            "test ! -e \"$poison_marker\"" in position_guard and
            "test ! -e \"$build_root/$name-native\"" in position_guard and
            "test ! -e \"$marker\"" in transfer_guard and
            "test ! -e \"$build_root/$case_name\"" in transfer_guard,
            "legacy callback position diagnostic successor drifted")
    for path in (expected["positive_fixture"], expected["host_object_source"],
                 "scripts/phase26_ffi_callback_sync.sh"):
        require((ROOT / path).is_file(), f"fixture or guard missing: {path}")
    levels = json.loads((ROOT / "scripts/cranelift_test_levels.json").read_text())
    require(levels["guards"].get(GUARD) == 2, "Level 2 owner drifted")
    require(f"{GUARD}:" in (ROOT / "justfile").read_text(),
            "justfile recipe missing")
    require(f"just {GUARD}" in (ROOT / ".github/workflows/pr-fast.yml").read_text(),
            "PR Fast owner missing")
    guard = (ROOT / "scripts/phase26_ffi_callback_sync.sh").read_text()
    for token in ("callback_alpha_host", "callback_beta_host", "outside_unsafe",
                  "imported_type_collision", "local_declaration", "alias_address",
                  "forged_policy", "legacy_without_plan",
                  "phase21-full-program-object", "poison-driver"):
        require(token in guard, f"native or fail-closed assertion missing: {token}")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
