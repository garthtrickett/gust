#!/usr/bin/env python3
"""Pin the bounded native-owned retained lease and its historical relays."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-ffi-retained-lease"

def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")

def main() -> None:
    registry = json.loads((ROOT / "scripts/cranelift_feature_registry.json").read_text())
    record = registry["phase26_activation_audit"]["ffi_retained_lease_increment"]
    expected = {
        "contract_version": "phase26_1d_retained_lease_v1",
        "status": "native_owned_retained_pointer_lease_qualified",
        "owner": "cranelift",
        "increment": "26.1D_retained_lease",
        "supported_target": "x86_64-unknown-linux-gnu",
        "canonical_call_variant": "5_retained_lease_v1",
        "legacy_call_variants": [0, 1, 2, 3, 4],
        "selected_policy": "retain",
        "selected_shape": "one_raw_field_linear_repr_c_owner",
        "provenance": "native_owned_raw_field",
        "scope": "adjacent_acquisition_registration_to_terminal_release",
        "supported_exit_routes": ["normal", "early_return", "guard", "defer"],
        "unsupported_origins": ["stack", "arena", "unbound_raw"],
        "unsupported_routes": ["transfer", "callback", "native_error", "unwind",
                               "longjmp", "process_termination"],
        "positive_fixture": "compiler/phase26_ffi_retained_lease_source.gst",
        "canonical_fixture": "compiler/fixtures/native_backend_phase26_retained_lease_minimal.mir",
        "host_object_source": "tests/cranelift/phase26_retained_lease_hosts.c",
        "owning_level2_guard": GUARD,
        "native_fallback": False,
        "runtime_symbol_surface_changed": False,
    }
    require({key: record.get(key) for key in expected} == expected,
            "native-owned retained lease contract drifted")
    require(set(record) == set(expected) | {
        "phase22_invocation_successor", "production_audit_successor",
        "phase23_text_surface_successor", "spelling_inventory_successor",
        "legacy_transfer_retained_policy_successor",
    }, "retained lease acquired unreviewed fields")
    require(record["legacy_transfer_retained_policy_successor"] == {
        "fixture": "scripts/phase26_ffi_transfer_owned.sh:retained_policy",
        "previous_diagnostic": "FFITransferRetainUnsupported",
        "current_diagnostic": "FFIByValueAggregateUnsupported",
        "rejected_before_driver_discovery": True,
        "other_transfer_cases_preserved": True,
    } and "retained_policy) expected='[FFIByValueAggregateUnsupported]'" in
            (ROOT / "scripts/phase26_ffi_transfer_owned.sh").read_text(),
            "legacy transfer retain rejection successor drifted")
    from phase22_opening import scan_invocations
    rows = [row for row in scan_invocations()
            if row["path"] == "scripts/phase26_ffi_retained_lease.sh"]
    require(record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1d_retained_lease_phase22_invocation_successor_v1",
        "previous_total": 248,
        "current_total": 250,
        "added_rows": rows,
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows) == 2 and all(row["selection"] == "explicit_cranelift"
                                 for row in rows), "exact native/poison invocation rows drifted")
    require(record["production_audit_successor"] == {
        "contract_version": "phase26_1d_retained_lease_production_audit_successor_v1",
        "previous_repository_invocation_count": 248,
        "current_repository_invocation_count": 250,
        "added_invocation_path": "scripts/phase26_ffi_retained_lease.sh",
        "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "production audit successor drifted")
    for path in (expected["positive_fixture"], expected["canonical_fixture"],
                 expected["host_object_source"],
                 "scripts/phase26_ffi_retained_lease.sh"):
        require((ROOT / path).is_file(), f"fixture or guard missing: {path}")
    levels = json.loads((ROOT / "scripts/cranelift_test_levels.json").read_text())
    require(levels["guards"].get(GUARD) == 2, "Level 2 owner drifted")
    require(f"{GUARD}:" in (ROOT / "justfile").read_text(),
            "justfile recipe missing")
    require(f"just {GUARD}" in (ROOT / ".github/workflows/pr-fast.yml").read_text(),
            "PR Fast owner missing")
    guard = (ROOT / "scripts/phase26_ffi_retained_lease.sh").read_text()
    for token in ("canonical-positive.o", "stack_origin", "arena_origin",
                  "post_registration_take", "post_registration_transfer",
                  "early_then_terminal_cleanup", "release_then_owner_use",
                  "registration_before_acquisition", "suffix_free_call0",
                  "phase21-full-program-object", "poison-driver"):
        require(token in guard, f"native or fail-closed assertion missing: {token}")
    print(f"{GUARD}: registration ok")

if __name__ == "__main__":
    main()
