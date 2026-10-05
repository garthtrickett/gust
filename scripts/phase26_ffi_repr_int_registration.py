#!/usr/bin/env python3
"""Pin the opt-in fieldless enum ABI and its Level 2 evidence."""

import json
from pathlib import Path

from phase22_opening import scan_invocations


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
GUARD = "guard-cranelift-phase26-ffi-repr-int"
SCRIPT = "scripts/phase26_ffi_repr_int.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def main() -> None:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry["phase26_activation_audit"]["ffi_repr_int_increment"]
    expected = {
        "contract_version": "phase26_1d_repr_int_v1",
        "status": "opt_in_fieldless_enum_integer_abi_qualified",
        "owner": "cranelift",
        "increment": "26.1D_enum_representation",
        "plain_enum_layout": "unchanged_8_byte_aggregate",
        "repr_int_layout": "four_byte_i32_scalar",
        "selected_ffi_host": "tiny_host_echo_repr_int",
        "native_fallback": False,
        "runtime_symbol_surface_changed": False,
        "positive_fixture": "compiler/phase26_ffi_repr_int_source.gst",
        "owning_level2_guard": GUARD,
    }
    require({key: record.get(key) for key in expected} == expected,
            "ABI ownership record drifted")
    require(set(record) == set(expected) | {
        "phase22_invocation_successor", "production_audit_successor",
        "filename_site_successor", "spelling_inventory_successor",
        "phase23_text_surface_successor"},
        "ABI ownership record gained unreviewed fields")
    rows = [row for row in scan_invocations() if row["path"] == SCRIPT]
    require(rows == record["phase22_invocation_successor"]["added_rows"] and
            len(rows) == 2, "native and poison invocation rows drifted")
    require((ROOT / expected["positive_fixture"]).is_file() and
            (ROOT / SCRIPT).is_file(), "owned fixture or guard is missing")
    justfile = (ROOT / "justfile").read_text(encoding="utf-8")
    workflow = (ROOT / ".github/workflows/pr-fast.yml").read_text(encoding="utf-8")
    levels = json.loads((ROOT / "scripts/cranelift_test_levels.json").read_text())
    require(f"{GUARD}:" in justfile and
            f"just {GUARD}" in workflow and
            levels["guards"].get(GUARD) == 2,
            "Level 2 CI ownership drifted")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
