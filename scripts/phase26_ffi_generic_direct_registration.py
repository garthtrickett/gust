#!/usr/bin/env python3
"""Pin the additive, tagged synchronous direct C borrow contract."""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-ffi-generic-direct"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def main() -> None:
    registry = json.loads((ROOT / "scripts/cranelift_feature_registry.json").read_text())
    record = registry["phase26_activation_audit"]["ffi_generic_direct_call_increment"]
    expected = {
        "contract_version": "phase26_1d_generic_direct_call_v1",
        "status": "versioned_generic_multi_position_direct_c_call_qualified",
        "owner": "cranelift",
        "increment": "26.1D_generic_direct_call",
        "supported_target": "x86_64-unknown-linux-gnu",
        "canonical_call_variant": "4_direct_call_v1",
        "legacy_call_variants": [0, 1, 2, 3],
        "selected_policies": ["borrow_read_call", "borrow_write_call"],
        "selected_shapes": ["flat_repr_c", "flat_packed_repr_c"],
        "provenance": "direct_local_address",
        "scope": "synchronous_call",
        "supported_exit_routes": ["normal", "early_return", "guard", "defer"],
        "unsupported_routes": ["retain", "transfer", "callback", "native_error",
                               "unwind", "longjmp", "process_termination"],
        "positive_fixture": "compiler/phase26_ffi_generic_direct_source.gst",
        "canonical_fixture": "compiler/fixtures/native_backend_phase26_generic_direct_minimal.mir",
        "host_object_source": "tests/cranelift/phase26_generic_direct_hosts.c",
        "owning_level2_guard": GUARD,
        "native_fallback": False,
        "runtime_symbol_surface_changed": False,
    }
    require({key: record.get(key) for key in expected} == expected,
            "generic direct-call contract drifted")
    require(set(record) == set(expected) | {
        "phase22_invocation_successor", "production_audit_successor",
        "phase23_text_surface_successor", "spelling_inventory_successor",
        "legacy_unknown_host_successor", "legacy_write_alias_successor",
    }, "generic direct-call acquired unreviewed fields")
    require(record["legacy_unknown_host_successor"] == {
        "contract_version": "phase26_1d_generic_direct_legacy_host_successor_v1",
        "previous_d2": "unknown_host_deferred_before_driver_discovery",
        "current_d2": "generic_direct_call4_supported_then_poison_driver_handshake",
        "legacy_call0_without_suffix": "rejected_before_object_emission",
        "other_d2_negative_cases": "preserved",
        "phase22_shifted_rows": [{
            "path": "scripts/phase26_ffi_repr_c_layout.sh",
            "previous_line": 59,
            "current_line": 70,
        }],
    }, "generic direct legacy-host successor drifted")
    require(record["legacy_write_alias_successor"] == {
        "contract_version": "phase26_1d_generic_direct_legacy_write_alias_successor_v1",
        "fixture": "compiler/phase26_ffi_repr_c_write_unknown_host_source.gst",
        "previous_d3": "unknown_host_deferred_before_driver_discovery",
        "current_d3": "local_raw_alias_rejected_by_canonical_mir_before_driver",
        "other_d3_negative_cases": "preserved",
    }, "generic direct legacy write-alias successor drifted")
    from phase22_opening import scan_invocations
    rows = [row for row in scan_invocations()
            if row["path"] == "scripts/phase26_ffi_generic_direct.sh"]
    relay = record["phase22_invocation_successor"]
    require(relay == {
        "contract_version": "phase26_1d_generic_direct_phase22_invocation_successor_v1",
        "previous_total": 246,
        "current_total": 248,
        "added_rows": rows,
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows) == 2, "exact native and poison invocation rows drifted")
    require(record["production_audit_successor"] == {
        "contract_version": "phase26_1d_generic_direct_production_audit_successor_v1",
        "previous_repository_invocation_count": 246,
        "current_repository_invocation_count": 248,
        "added_invocation_path": "scripts/phase26_ffi_generic_direct.sh",
        "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "production audit successor drifted")
    for path in (expected["positive_fixture"], expected["canonical_fixture"],
                 expected["host_object_source"],
                 "scripts/phase26_ffi_generic_direct.sh"):
        require((ROOT / path).is_file(), f"fixture or guard missing: {path}")
    levels = json.loads((ROOT / "scripts/cranelift_test_levels.json").read_text())
    require(levels["guards"].get(GUARD) == 2, "Level 2 owner drifted")
    require(f"{GUARD}:" in (ROOT / "justfile").read_text(),
            "justfile recipe missing")
    require(f"just {GUARD}" in (ROOT / ".github/workflows/pr-fast.yml").read_text(),
            "PR Fast owner missing")
    guard = (ROOT / "scripts/phase26_ffi_generic_direct.sh").read_text()
    for token in ("canonical-positive.o", "aliased_positions", "wrong_scope",
                  "legacy_3_forgery", "legacy_unknown_host_call0",
                  "phase21-full-program-object", "poison-driver"):
        require(token in guard, f"native or fail-closed assertion missing: {token}")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
