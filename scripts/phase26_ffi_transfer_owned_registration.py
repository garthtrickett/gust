#!/usr/bin/env python3
"""Pin the Phase 26.1D by-value native owner transfer authority."""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-ffi-transfer-owned"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def main() -> None:
    registry = json.loads((ROOT / "scripts/cranelift_feature_registry.json").read_text())
    record = registry["phase26_activation_audit"]["ffi_transfer_owned_increment"]
    expected = {
        "contract_version": "phase26_1d_transfer_owned_v1",
        "status": "native_by_value_linear_owner_transfer_qualified",
        "owner": "cranelift",
        "increment": "26.1D_transfer_owned",
        "supported_target": "x86_64-unknown-linux-gnu",
        "physical_abi": "one_pointer_repr_c_struct_by_value",
        "parameter_policy": "transfer_owned",
        "producer_policy": "owned_return",
        "release_policy": "release_owned",
        "provenance": "raw_derived_unbrandable",
        "exit_routes": ["scope", "early_return", "conditional", "defer"],
        "unsupported_routes": ["retain", "callback", "native_error", "unwind", "process_termination"],
        "positive_fixture": "compiler/phase26_ffi_transfer_owned_source.gst",
        "canonical_fixture": "compiler/fixtures/native_backend_phase26_transfer_owned_minimal.mir",
        "host_object_source": "tests/cranelift/phase26_transfer_owned_hosts.c",
        "owning_level2_guard": GUARD,
        "native_fallback": False,
        "runtime_symbol_surface_changed": False,
    }
    successors = {
        "phase22_invocation_successor", "production_audit_successor",
        "filename_site_successor", "spelling_inventory_successor",
        "phase23_text_surface_successor",
    }
    require({key: record.get(key) for key in expected} == expected and
            set(record) == set(expected) | successors,
            "ownership contract drifted")
    from phase22_opening import scan_invocations
    rows = [row for row in scan_invocations()
            if row["path"] == "scripts/phase26_ffi_transfer_owned.sh"]
    relay = record["phase22_invocation_successor"]
    require(relay["previous_total"] == 242 and relay["current_total"] == 244 and
            relay["added_rows"] == rows and len(rows) == 2,
            "native and poison invocation rows drifted")
    for path in (
        expected["positive_fixture"], expected["canonical_fixture"],
        expected["host_object_source"], "scripts/phase26_ffi_transfer_owned.sh",
    ):
        require((ROOT / path).is_file(), f"fixture or guard missing: {path}")
    levels = json.loads((ROOT / "scripts/cranelift_test_levels.json").read_text())
    require(levels["guards"].get(GUARD) == 2, "Level 2 owner drifted")
    require(f"{GUARD}:" in (ROOT / "justfile").read_text(), "justfile recipe missing")
    require(f"just {GUARD}" in (ROOT / ".github/workflows/pr-fast.yml").read_text(),
            "PR Fast owner missing")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
