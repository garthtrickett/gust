#!/usr/bin/env python3
"""Pin the bounded synchronous C callback and its canonical authority."""

import json
import hashlib
from pathlib import Path

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
        "filename_site_successor",
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
    expected_paths = [
        ".github/workflows/pr-fast.yml",
        "compiler/experiments/cranelift/src/full_program.rs",
        "compiler/mir_native_backend_full_program_source.gst",
        "compiler/typechecker.gst", "justfile",
        "scripts/cranelift_test_levels.json", "scripts/phase22_opening.py",
    ]
    require(surface["contract_version"] ==
            "phase26_1d_callback_sync_phase23_text_surface_successor_v1" and
            surface["added_rows"] == [] and
            surface["partial_extra_or_substituted_surface"] == "rejected" and
            [row["path"] for row in surface["changed_rows"]] == expected_paths,
            "callback text surface successor shape drifted")
    for row in surface["changed_rows"]:
        current = hashlib.sha256((ROOT / row["path"]).read_bytes()).hexdigest()
        require(current == row["current_digest"] and
                len(row["previous_digest"]) == 64 and
                row["previous_match_counts"] == row["current_match_counts"],
                f"callback text surface drifted: {row['path']}")
    from phase24_semantic_spelling_inventory import source_sites, manifest_summary
    spelling = record["spelling_inventory_successor"]
    previous = registry["phase26_activation_audit"]["ffi_retained_lease_increment"][
        "spelling_inventory_successor"]["current_inventory_summary"]
    require(spelling["contract_version"] ==
            "phase26_1d_callback_sync_spelling_inventory_successor_v1" and
            spelling["previous_inventory_summary"] == previous and
            spelling["current_inventory_summary"] == manifest_summary(source_sites()) and
            spelling["partial_extra_or_substituted_inventory"] == "rejected",
            "callback spelling inventory successor drifted")
    from phase24_filename_behavior_characterization import source_sites as filename_source_sites
    filename = record["filename_site_successor"]
    previous_sites = registry["phase26_activation_audit"]["ffi_retained_lease_increment"][
        "filename_site_successor"]["current_sites"]
    current_sites = filename_source_sites()
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
