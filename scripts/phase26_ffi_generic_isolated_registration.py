#!/usr/bin/env python3
"""Pin the additive generic isolated FFI Call and its native proof."""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-ffi-generic-isolated"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def before_generic_isolated_digest(activation: dict, path: str,
                                   live_digest: str) -> str:
    """Reverse this exact successor for earlier frozen guard identities."""
    native_error_rows = activation.get("ffi_native_error_status_increment", {}).get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])
    native_error = [row for row in native_error_rows if row.get("path") == path]
    require(len(native_error) <= 1, f"duplicate native-error surface: {path}")
    if native_error:
        row = native_error[0]
        require(row["current_digest"] == live_digest and
                len(row["previous_digest"]) == 64,
                f"native-error text surface drifted: {path}")
        live_digest = row["previous_digest"]
    callback_rows = activation.get("ffi_callback_sync_increment", {}).get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])
    callback = [row for row in callback_rows if row.get("path") == path]
    require(len(callback) <= 1, f"duplicate callback surface: {path}")
    if callback:
        row = callback[0]
        require(row["current_digest"] == live_digest and
                len(row["previous_digest"]) == 64,
                f"callback text surface drifted: {path}")
        live_digest = row["previous_digest"]
    retained_rows = activation.get("ffi_retained_lease_increment", {}).get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])
    retained = [row for row in retained_rows if row.get("path") == path]
    require(len(retained) <= 1, f"duplicate retained-lease surface: {path}")
    if retained:
        row = retained[0]
        require(row["current_digest"] == live_digest and
                len(row["previous_digest"]) == 64,
                f"retained-lease text surface drifted: {path}")
        live_digest = row["previous_digest"]
    direct_rows = activation.get("ffi_generic_direct_call_increment", {}).get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])
    direct = [row for row in direct_rows if row.get("path") == path]
    require(len(direct) <= 1, f"duplicate direct-borrow surface: {path}")
    if direct:
        row = direct[0]
        require(row["current_digest"] == live_digest and
                len(row["previous_digest"]) == 64,
                f"direct-borrow text surface drifted: {path}")
        live_digest = row["previous_digest"]
    rows = activation.get("ffi_generic_isolated_call_increment", {}).get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])
    selected = [row for row in rows if row.get("path") == path]
    require(len(selected) <= 1, f"duplicate generic isolation surface: {path}")
    if selected:
        row = selected[0]
        require(row["current_digest"] == live_digest and
                len(row["previous_digest"]) == 64,
                f"generic isolation text surface drifted: {path}")
        return row["previous_digest"]
    return live_digest


def main() -> None:
    registry = json.loads((ROOT / "scripts/cranelift_feature_registry.json").read_text())
    record = registry["phase26_activation_audit"]["ffi_generic_isolated_call_increment"]
    expected = {
        "contract_version": "phase26_1d_generic_isolated_call_v1",
        "status": "versioned_generic_multi_position_isolated_c_call_qualified",
        "owner": "cranelift",
        "increment": "26.1D_generic_isolated_call",
        "supported_target": "x86_64-unknown-linux-gnu",
        "canonical_call_variant": "3_isolated_call_v1",
        "legacy_call_variants": [0, 1, 2],
        "selected_policies": ["borrow_read_isolated_call", "borrow_write_isolated_call"],
        "selected_shapes": ["flat_repr_c", "flat_packed_repr_c"],
        "provenance": ["direct_local_address", "untrusted_raw_copyback"],
        "cleanup": "single_call_arena_before_continuation",
        "supported_exit_routes": ["normal", "early_return", "guard", "defer"],
        "unsupported_routes": ["retain", "transfer", "callback", "native_error",
                               "unwind", "longjmp", "process_termination"],
        "positive_fixture": "compiler/phase26_ffi_generic_isolated_source.gst",
        "canonical_fixture": "compiler/fixtures/native_backend_phase26_generic_isolated_minimal.mir",
        "host_object_source": "tests/cranelift/phase26_generic_isolated_hosts.c",
        "owning_level2_guard": GUARD,
        "native_fallback": False,
        "runtime_symbol_surface_changed": False,
    }
    require({key: record.get(key) for key in expected} == expected,
            "generic isolated-call contract drifted")
    require(set(record) == set(expected) | {
        "phase22_invocation_successor", "production_audit_successor",
        "spelling_inventory_successor", "phase23_text_surface_successor",
        "legacy_unknown_host_successor",
    }, "generic isolated-call acquired unreviewed fields")
    require(record["legacy_unknown_host_successor"] == {
        "contract_version": "phase26_1d_generic_isolated_legacy_host_successor_v1",
        "previous_read_and_write": "unknown_host_deferred_before_driver_discovery",
        "current_read_and_write": "flat_c_layout_supported_independent_of_host_name",
        "proof": "existing_D5_D6_poison_driver_guards_require_supported_then_driver_handshake",
        "other_negative_cases": "preserved",
        "phase22_shifted_rows": [
            {"path": "scripts/phase26_ffi_isolated_read.sh",
             "previous_line": 98, "current_line": 107},
            {"path": "scripts/phase26_ffi_isolated_write.sh",
             "previous_line": 103, "current_line": 112},
        ],
    }, "D5/D6 unknown-host historical successor drifted")
    from phase22_opening import scan_invocations
    rows = [row for row in scan_invocations()
            if row["path"] == "scripts/phase26_ffi_generic_isolated.sh"]
    relay = record["phase22_invocation_successor"]
    require(relay["previous_total"] == 244 and relay["current_total"] == 246 and
            relay["added_rows"] == rows and len(rows) == 2,
            "exact native and poison invocation rows drifted")
    require(record["production_audit_successor"]["added_invocation_path"] ==
            "scripts/phase26_ffi_generic_isolated.sh" and
            record["spelling_inventory_successor"]["changed_source_paths"] == [
                "compiler/experiments/cranelift/src/full_program.rs",
                "compiler/mir_native_backend_full_program_source.gst",
                "compiler/phase26_ffi_generic_isolated_source.gst"],
            "historical projection successor drifted")
    for path in (expected["positive_fixture"], expected["canonical_fixture"],
                 expected["host_object_source"],
                 "scripts/phase26_ffi_generic_isolated.sh",
                 "compiler/fixtures/native_backend_phase26_generic_isolated_unknown_read.mir",
                 "compiler/fixtures/native_backend_phase26_generic_isolated_unknown_write.mir"):
        require((ROOT / path).is_file(), f"fixture or guard missing: {path}")
    levels = json.loads((ROOT / "scripts/cranelift_test_levels.json").read_text())
    require(levels["guards"].get(GUARD) == 2, "Level 2 owner drifted")
    require(f"{GUARD}:" in (ROOT / "justfile").read_text(),
            "justfile recipe missing")
    require(f"just {GUARD}" in (ROOT / ".github/workflows/pr-fast.yml").read_text(),
            "PR Fast owner missing")
    guard = (ROOT / "scripts/phase26_ffi_generic_isolated.sh").read_text()
    for token in ("canonical-positive.o", "forged_read_origin", "wrong_cleanup",
                  "legacy_read_unknown_host", "legacy_write_unknown_host",
                  "os_Arena_Free", "phase21-full-program-object", "poison-driver"):
        require(token in guard, f"native or fail-closed assertion missing: {token}")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
