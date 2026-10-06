#!/usr/bin/env python3
"""Pin the bounded Phase 26.1D6 isolated borrowed write and its successors."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-ffi-isolated-write"
SCRIPT = "scripts/phase26_ffi_isolated_write.sh"
FIXTURES = [
    "compiler/phase26_ffi_isolated_write_source.gst",
    *[f"compiler/phase26_ffi_isolated_write_{name}_source.gst" for name in
      ("missing", "order", "packed", "nested", "enum",
       "unknown_host", "nonraw", "nonaggregate")],
]


def require(value: bool, message: str) -> None:
    if not value:
        raise SystemExit(f"{GUARD}: {message}")


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def main() -> None:
    registry = json.loads((ROOT / "scripts/cranelift_feature_registry.json")
                          .read_text(encoding="utf-8"))
    activation = registry.get("phase26_activation_audit", {})
    record = activation.get("ffi_isolated_write_increment", {})
    expected = {
        "contract_version": "phase26_1d6_ffi_isolated_write_v1",
        "status": "selected_flat_repr_c_raw_write_isolated_copyback_per_call",
        "owner": "cranelift", "increment": "26.1D6",
        "declared_parameter_policy": "borrow_write_isolated_call",
        "canonical_call_policy": "explicit_optional_call_marker_2",
        "ordinary_call_policy": "unchanged_marker_0",
        "storage": "temporary_arena_copy_in_host_write_copyback_then_free",
        "physical_pointer_abi": "unchanged",
        "selected_host_import": "tiny_host_write_repr_c_probe",
        "selected_host_object": "generated_test_only_existing_host_object_slot",
        "positive_fixture": FIXTURES[0],
        "negative_fixtures": FIXTURES[1:],
        "failure_stage": "before_driver_discovery",
        "deferral_reason": "deferred_p26_ffi_borrowed_c_layout",
        "native_fallback": False, "physical_abi_changed": False,
        "runtime_symbol_surface_changed": False,
        "unsupported_shapes": [
            "reference_writes", "transfer", "retain", "returned_pointer",
            "callback", "native_error", "by_value_aggregate", "nested",
            "packed", "enum", "unapproved_host", "nonlocal_exit_cleanup",
        ],
        "owning_level2_guard": GUARD,
        "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"registry field drifted: {key}")
    require(set(record) == set(expected) | {
        "phase22_invocation_successor", "production_audit_successor",
        "phase23_text_surface_successor", "spelling_inventory_successor",
        "filename_site_successor",
    }, "registry acquired unreviewed D6 fields")
    for path in FIXTURES:
        require((ROOT / path).is_file(), f"registered fixture missing: {path}")

    from phase22_opening import scan_invocations
    invocation = record["phase22_invocation_successor"]
    live_rows = [row for row in scan_invocations() if row["path"] == SCRIPT]
    shift = activation["ffi_generic_isolated_call_increment"][
        "legacy_unknown_host_successor"]["phase22_shifted_rows"][1]
    require(shift == {"path": SCRIPT, "previous_line": 103,
                      "current_line": 112} and len(live_rows) == 3,
            "generic isolated write invocation successor drifted")
    projected_rows = [dict(row, line=shift["previous_line"])
                      if row["line"] == shift["current_line"] else row
                      for row in live_rows]
    require(invocation.get("contract_version") ==
            "phase26_1d6_phase22_invocation_successor_v1" and
            invocation.get("previous_total") == 168 and
            invocation.get("current_total") == 171 and
            invocation.get("partial_extra_or_substituted_invocation") ==
            "rejected" and
            projected_rows ==
            invocation.get("added_rows"), "native invocation rows drifted")
    require(record["production_audit_successor"] == {
        "contract_version": "phase26_1d6_production_audit_successor_v1",
        "previous_repository_invocation_count": 168,
        "current_repository_invocation_count": 171,
        "added_invocation_path": SCRIPT,
        "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "production audit successor drifted")

    from phase24_filename_behavior_characterization import source_sites
    filename = record["filename_site_successor"]
    previous = activation["ffi_isolated_read_increment"][
        "filename_site_successor"]["current_sites"]
    e2 = activation.get("reference_return_escape_increment", {})
    current = (e2.get("filename_site_successor", {}).get("previous_sites")
               if e2 else source_sites())
    delta = filename.get("line_delta")
    require(filename.get("contract_version") ==
            "phase26_1d6_filename_site_successor_v1" and
            filename.get("previous_sites") == previous and
            filename.get("current_sites") == current and
            isinstance(delta, int) and delta > 0 and
            len(previous) == len(current) == 3 and
            all(now["line"] == before["line"] + delta and
                {k: v for k, v in now.items() if k != "line"} ==
                {k: v for k, v in before.items() if k != "line"}
                for before, now in zip(previous, current)) and
            filename.get("partial_extra_or_substituted_site") == "rejected",
            "filename-selected sites changed beyond the exact D6 line shift")

    from phase24_semantic_spelling_inventory import source_sites as spelling_sites, manifest_summary
    spelling = record["spelling_inventory_successor"]
    require(spelling.get("contract_version") ==
            "phase26_1d6_spelling_inventory_successor_v1" and
            spelling.get("previous_inventory_summary") == activation[
                "ffi_isolated_read_increment"]["spelling_inventory_successor"][
                    "current_inventory_summary"] and
            spelling.get("current_inventory_summary") ==
            (e2.get("spelling_inventory_successor", {}).get(
                "previous_inventory_summary") if e2 else
             manifest_summary(spelling_sites())) and
            spelling.get("partial_extra_or_substituted_inventory") ==
            "rejected", "spelling inventory successor drifted")

    surface = record["phase23_text_surface_successor"]
    require(surface.get("contract_version") ==
            "phase26_1d6_phase23_text_surface_successor_v1" and
            surface.get("partial_extra_or_substituted_surface") == "rejected" and
            len({row["path"] for row in surface.get("changed_rows", [])}) ==
            len(surface.get("changed_rows", [])) and
            surface.get("added_rows") == [],
            "text surface successor shape drifted")
    # The separately required Phase23 projection validates every live row.

    justfile = (ROOT / "justfile").read_text()
    workflow = (ROOT / ".github/workflows/pr-fast.yml").read_text()
    guard = (ROOT / SCRIPT).read_text()
    require(justfile.count(f"{GUARD}:") == 1 and
            "python3 scripts/phase26_ffi_isolated_write_registration.py" in
            justfile and workflow.count(f"just {GUARD}") == 1 and
            "poison-driver.invoked" in guard and
            "printf '20\\n30\\n4\\n'" in guard and
            "--disassemble=gust_phase21_program_main" in guard and
            "memcpy" in guard and
            "os_Arena_Free" in guard and
            "missing order packed nested unknown_host enum" in guard and
            "decision=supported capability=phase13_generic_source_to_mir" in guard and
            "if test \"$case_name\" = unknown_host" in guard and
            "nonraw nonaggregate" in guard,
            "required native behavior or no-fallback guard weakened")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
