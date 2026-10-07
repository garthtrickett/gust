#!/usr/bin/env python3
"""Pin the bounded signed Int native-error status and historical successors."""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-ffi-native-error-status"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def main() -> None:
    registry = json.loads((ROOT / "scripts/cranelift_feature_registry.json").read_text())
    activation = registry["phase26_activation_audit"]
    record = activation["ffi_native_error_status_increment"]
    expected = {
        "contract_version": "phase26_1d_native_error_status_v1",
        "status": "bounded_explicit_signed_int_native_error_status_qualified",
        "owner": "cranelift",
        "increment": "26.1D_native_error_status",
        "supported_target": "x86_64-unknown-linux-gnu",
        "canonical_call_variant": "7_native_error_status_v1",
        "legacy_call_variants": list(range(7)),
        "selected_policy": "native_error_return",
        "result_type": "Int",
        "status_convention": "zero_success_nonzero_failure_preserve_signed_status",
        "unsupported_routes": ["implicit_result", "throw", "errno", "pointer_result",
                               "callback_mixed", "ownership_mixed", "unwind"],
        "positive_fixture": "compiler/phase26_ffi_native_error_status_source.gst",
        "host_object_source": "tests/cranelift/phase26_native_error_status_hosts.c",
        "owning_level2_guard": GUARD,
        "native_fallback": False,
        "runtime_symbol_surface_changed": False,
    }
    require({key: record.get(key) for key in expected} == expected and
            set(record) == set(expected) | {
                "phase22_invocation_successor", "production_audit_successor",
                "phase23_text_surface_successor", "spelling_inventory_successor",
                "filename_site_successor",
            }, "native-error contract or field set drifted")
    from phase22_opening import scan_invocations
    selected = "scripts/phase26_ffi_native_error_status.sh"
    rows = [row for row in scan_invocations() if row["path"] == selected]
    require(record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1d_native_error_status_phase22_invocation_successor_v1",
        "previous_total": 252,
        "current_total": 254,
        "added_rows": rows,
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows) == 2 and
            all(row["selection"] == "explicit_cranelift" for row in rows),
            "native-error invocation successor drifted")
    require(record["production_audit_successor"] == {
        "contract_version": "phase26_1d_native_error_status_production_audit_successor_v1",
        "previous_repository_invocation_count": 252,
        "current_repository_invocation_count": 254,
        "added_invocation_path": selected,
        "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "native-error production audit successor drifted")
    surface = record["phase23_text_surface_successor"]
    expected_paths = [
        ".github/workflows/pr-fast.yml",
        "compiler/experiments/cranelift/src/full_program.rs",
        "compiler/mir_native_backend_full_program_source.gst",
        "compiler/typechecker.gst", "justfile", "scripts/cranelift_test_levels.json",
        "scripts/phase22_opening.py", "scripts/phase26_call_return_zero_registration.py",
    ]
    require(surface["contract_version"] ==
            "phase26_1d_native_error_status_phase23_text_surface_successor_v1" and
            surface["added_rows"] == [] and
            surface["partial_extra_or_substituted_surface"] == "rejected" and
            [row["path"] for row in surface["changed_rows"]] == expected_paths,
            "native-error text surface shape drifted")
    callback_rows = {row["path"]: row for row in activation[
        "ffi_callback_sync_increment"]["phase23_text_surface_successor"]["changed_rows"]}
    for row in surface["changed_rows"]:
        current = hashlib.sha256((ROOT / row["path"]).read_bytes()).hexdigest()
        require(row["current_digest"] == current and
                len(row["previous_digest"]) == 64 and
                row["previous_match_counts"] == row["current_match_counts"] and
                (row["path"] not in callback_rows or
                 row["previous_digest"] == callback_rows[row["path"]]["current_digest"]),
                f"native-error text surface drifted: {row['path']}")
    from phase24_semantic_spelling_inventory import source_sites, manifest_summary
    spelling = record["spelling_inventory_successor"]
    previous_summary = activation["ffi_callback_sync_increment"][
        "spelling_inventory_successor"]["current_inventory_summary"]
    current_summary = manifest_summary(source_sites())
    require(spelling == {
        "contract_version": "phase26_1d_native_error_status_spelling_inventory_successor_v1",
        "previous_inventory_summary": previous_summary,
        "current_inventory_summary": current_summary,
        "changed_source_paths": sorted([
            "compiler/experiments/cranelift/src/full_program.rs",
            "compiler/mir_native_backend_full_program_source.gst",
            "compiler/phase26_ffi_native_error_status_source.gst",
            "compiler/typechecker.gst",
        ]),
        "partial_extra_or_substituted_inventory": "rejected",
    } and current_summary["source_file_count"] ==
            previous_summary["source_file_count"] + 1 and
            all(current_summary[key] == previous_summary[key] for key in (
                "site_count", "semantic_site_count", "unknown_site_count")),
            "native-error spelling inventory drifted")
    from phase24_filename_behavior_characterization import source_sites as filename_sites
    filename = record["filename_site_successor"]
    previous_sites = activation["ffi_callback_sync_increment"][
        "filename_site_successor"]["current_sites"]
    current_sites = filename_sites()
    require(filename == {
        "contract_version": "phase26_1d_native_error_status_filename_site_successor_v1",
        "previous_sites": previous_sites,
        "current_sites": current_sites,
        "line_deltas": [22, 22, 22],
        "partial_extra_or_substituted_site": "rejected",
    } and len(previous_sites) == len(current_sites) == 3 and
            all(now["line"] == before["line"] + 22 and
                {key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now in zip(previous_sites, current_sites)),
            "native-error filename site successor drifted")
    for p in (expected["positive_fixture"], expected["host_object_source"], selected):
        require((ROOT / p).is_file(), f"fixture or guard missing: {p}")
    levels = json.loads((ROOT / "scripts/cranelift_test_levels.json").read_text())
    require(levels["guards"].get(GUARD) == 2 and
            f"{GUARD}:" in (ROOT / "justfile").read_text() and
            f"just {GUARD}" in (ROOT / ".github/workflows/pr-fast.yml").read_text(),
            "Level 2 owner wiring drifted")
    guard = (ROOT / selected).read_text()
    for token in ("host_status_alpha", "zero_arg", "wrong_result_policy",
                  "wrong_target", "wrong_zero_arg_position",
                  "phase21-full-program-object", "poison-driver"):
        require(token in guard, f"native or fail-closed assertion missing: {token}")
    source = (ROOT / expected["positive_fixture"]).read_text()
    host = (ROOT / expected["host_object_source"]).read_text()
    require(all(name in source and name in host for name in
                ("host_status_alpha", "host_status_beta")),
            "independent C hosts drifted")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
