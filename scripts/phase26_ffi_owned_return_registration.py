#!/usr/bin/env python3
"""Pin the 26.1D owned native return and its Level 2 authority."""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-ffi-owned-return"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def main() -> None:
    registry = json.loads((ROOT / "scripts/cranelift_feature_registry.json").read_text())
    record = registry["phase26_activation_audit"]["ffi_owned_return_increment"]
    expected = {
        "contract_version": "phase26_1d_owned_return_v1",
        "status": "owned_native_return_destructor_release_qualified",
        "owner": "cranelift",
        "increment": "26.1D_owned_return",
        "supported_target": "x86_64-unknown-linux-gnu",
        "physical_abi": "one_pointer_repr_c_struct_by_value",
        "result_policy": "owned_return",
        "release_policy": "release_owned",
        "provenance": "raw_derived_unbrandable",
        "exit_routes": ["scope", "early_return", "guard", "defer", "return_transfer"],
        "unsupported_routes": ["retain", "transfer_to_native", "callback", "native_error", "unwind", "process_termination"],
        "positive_fixture": "compiler/phase26_ffi_owned_return_source.gst",
        "minimal_source_fixture": "compiler/phase26_ffi_owned_return_probe_source.gst",
        "canonical_fixture": "compiler/fixtures/native_backend_phase26_owned_return_minimal.mir",
        "host_object_source": "tests/cranelift/phase26_owned_return_hosts.c",
        "owning_level2_guard": GUARD,
        "native_fallback": False,
        "runtime_symbol_surface_changed": False,
    }
    require({key: record.get(key) for key in expected} == expected and
            set(record) == set(expected) | {
                "phase22_invocation_successor", "production_audit_successor",
                "filename_site_successor", "spelling_inventory_successor",
                "phase23_text_surface_successor"},
            "ownership contract drifted")
    from phase22_opening import scan_invocations
    rows = [row for row in scan_invocations()
            if row["path"] == "scripts/phase26_ffi_owned_return.sh"]
    relay = record["phase22_invocation_successor"]
    require(relay["previous_total"] == 240 and relay["current_total"] == 242 and
            relay["added_rows"] == rows and len(rows) == 2,
            "native and poison invocation rows drifted")
    for path in (
        expected["positive_fixture"], expected["minimal_source_fixture"],
        expected["canonical_fixture"],
        expected["host_object_source"],
        "scripts/phase26_ffi_owned_return.sh",
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
