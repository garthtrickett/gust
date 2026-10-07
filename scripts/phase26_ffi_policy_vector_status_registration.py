#!/usr/bin/env python3
"""Pin the bounded Call8 policy vector and its exact historical successors."""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-ffi-policy-vector-status"
SELECTED = "scripts/phase26_ffi_policy_vector_status.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def main() -> None:
    registry = json.loads((ROOT / "scripts/cranelift_feature_registry.json").read_text())
    activation = registry["phase26_activation_audit"]
    record = activation["ffi_policy_vector_status_increment"]
    expected = {
        "contract_version": "phase26_1d_policy_vector_status_v1",
        "status": "bounded_direct_isolated_borrow_and_signed_status_qualified",
        "owner": "cranelift",
        "increment": "26.1D_policy_vector_status",
        "supported_target": "x86_64-unknown-linux-gnu",
        "canonical_call_variant": "8_policy_vector_status_v1",
        "legacy_call_variants": list(range(8)),
        "parameter_policies": ["value", "borrow_read_call", "borrow_write_call",
                               "borrow_read_isolated", "borrow_write_isolated"],
        "result_policy": "native_error_return",
        "result_type": "Int",
        "status_convention": "zero_success_nonzero_failure_preserve_signed_status",
        "cleanup": "ordered_write_copyback_then_one_arena_free_before_continuation_on_every_status",
        "provenance": "canonical_local_address_or_call_bounded_isolated_copy",
        "unsupported_routes": ["aliased_direct_isolated_origins", "callback_mixed",
                               "ownership_mixed", "retained", "unwind",
                               "status_dependent_cleanup"],
        "positive_fixture": "compiler/phase26_ffi_policy_vector_status_source.gst",
        "host_object_source": "tests/cranelift/phase26_policy_vector_status_hosts.c",
        "owning_level2_guard": GUARD,
        "native_fallback": False,
        "runtime_symbol_surface_changed": False,
    }
    successor_keys = {
        "phase22_invocation_successor", "production_audit_successor",
        "phase23_text_surface_successor", "spelling_inventory_successor",
        "filename_site_successor", "legacy_native_error_mixed_borrow_successor",
    }
    require({key: record.get(key) for key in expected} == expected and
            set(record) == set(expected) | successor_keys,
            "Call8 contract or field set drifted")

    from phase22_opening import scan_invocations
    rows = [row for row in scan_invocations() if row["path"] == SELECTED]
    require(record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1d_policy_vector_status_phase22_invocation_successor_v1",
        "previous_total": 254, "current_total": 256,
        "added_rows": rows,
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows) == 2 and
            all(row["selection"] == "explicit_cranelift" for row in rows),
            "Call8 invocation successor drifted")
    require(record["production_audit_successor"] == {
        "contract_version": "phase26_1d_policy_vector_status_production_audit_successor_v1",
        "previous_repository_invocation_count": 254,
        "current_repository_invocation_count": 256,
        "added_invocation_path": SELECTED,
        "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "Call8 production audit successor drifted")

    surface = record["phase23_text_surface_successor"]
    paths = [
        ".github/workflows/pr-fast.yml",
        "compiler/experiments/cranelift/src/full_program.rs",
        "compiler/mir_native_backend_full_program_source.gst",
        "compiler/typechecker.gst", "justfile", "scripts/cranelift_test_levels.json",
        "scripts/phase22_opening.py", "scripts/phase26_call_return_zero_registration.py",
    ]
    require(surface["contract_version"] ==
            "phase26_1d_policy_vector_status_phase23_text_surface_successor_v1" and
            surface["added_rows"] == [] and
            surface["partial_extra_or_substituted_surface"] == "rejected" and
            [row["path"] for row in surface["changed_rows"]] == paths,
            "Call8 text surface successor shape drifted")
    for row in surface["changed_rows"]:
        require(row["current_digest"] == hashlib.sha256(
                    (ROOT / row["path"]).read_bytes()).hexdigest() and
                len(row["previous_digest"]) == 64 and
                row["previous_match_counts"] == row["current_match_counts"],
                f"Call8 text surface drifted: {row['path']}")

    from phase24_semantic_spelling_inventory import source_sites, manifest_summary
    spelling = record["spelling_inventory_successor"]
    previous_summary = activation["prefix_resolution_memory_prerequisite"][
        "spelling_inventory_successor"]["current_inventory_summary"]
    current_summary = manifest_summary(source_sites())
    require(spelling == {
        "contract_version": "phase26_1d_policy_vector_status_spelling_inventory_successor_v1",
        "previous_inventory_summary": previous_summary,
        "current_inventory_summary": current_summary,
        "changed_source_paths": [
            "compiler/experiments/cranelift/src/full_program.rs",
            "compiler/mir_native_backend_full_program_source.gst",
            "compiler/mir_native_backend_parameter_argument_source.gst",
            "compiler/phase26_ffi_policy_vector_status_source.gst",
            "compiler/typechecker.gst"],
        "partial_extra_or_substituted_inventory": "rejected",
    } and current_summary["source_file_count"] ==
            previous_summary["source_file_count"] + 1 and
            current_summary["site_count"] == previous_summary["site_count"] + 3 and
            current_summary["semantic_site_count"] ==
            previous_summary["semantic_site_count"] + 3 and
            current_summary["unknown_site_count"] == 0,
            "Call8 spelling inventory drifted")

    from phase24_filename_behavior_characterization import source_sites as filename_sites
    filename = record["filename_site_successor"]
    previous_sites = activation["prefix_resolution_memory_prerequisite"][
        "filename_site_successor"]["current_sites"]
    current_sites = filename_sites()
    require(filename == {
        "contract_version": "phase26_1d_policy_vector_status_filename_site_successor_v1",
        "previous_sites": previous_sites,
        "current_sites": current_sites,
        "line_deltas": [7, 7, 7],
        "partial_extra_or_substituted_site": "rejected",
    } and len(previous_sites) == len(current_sites) == 3 and
            all(now["line"] == before["line"] + 7 and
                {key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now in zip(previous_sites, current_sites)),
            "Call8 filename sites drifted")
    legacy = record["legacy_native_error_mixed_borrow_successor"]
    require(legacy["contract_version"] ==
            "phase26_1d_policy_vector_status_legacy_call7_mixed_borrow_v1" and
            legacy["path"] == "scripts/phase26_ffi_native_error_status.sh" and
            legacy["current_digest"] == hashlib.sha256(
                (ROOT / legacy["path"]).read_bytes()).hexdigest() and
            len(legacy["previous_digest"]) == 64 and
            legacy["previous_disposition"] == "mixed_borrow_rejected" and
            legacy["current_disposition"] ==
            "bounded_borrow_admitted_only_by_Call8_unsupported_Str_remains_rejected" and
            legacy["legacy_call7_scalar_only"] == "preserved",
            "Call7 source exclusion successor drifted")

    for path in (expected["positive_fixture"], expected["host_object_source"], SELECTED):
        require((ROOT / path).is_file(), f"Call8 fixture or guard missing: {path}")
    levels = json.loads((ROOT / "scripts/cranelift_test_levels.json").read_text())
    require(levels["guards"].get(GUARD) == 2 and
            f"{GUARD}:" in (ROOT / "justfile").read_text() and
            f"just {GUARD}" in (ROOT / ".github/workflows/pr-fast.yml").read_text(),
            "Call8 Level 2 wiring drifted")
    guard = (ROOT / SELECTED).read_text()
    for marker in ("host_vector_alpha", "host_vector_beta", "scalar_mix",
                   "duplicate", "wrong_target", "poison-driver", "legacy_call7"):
        require(marker in guard, f"Call8 assertion missing: {marker}")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
