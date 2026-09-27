#!/usr/bin/env python3
"""Pin Phase 26.1E2's return-only Reference escape boundary and successors."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-reference-return-escape"
SCRIPT = "scripts/phase26_reference_return_escape.sh"
FIXTURES = [
    "compiler/phase26_reference_return_escape_test_entry.gst",
    "compiler/phase26_reference_return_escape_source.gst",
    "compiler/phase26_reference_return_safe_source.gst",
]
SURFACES = {
    ".github/workflows/pr-fast.yml", "compiler/typechecker.gst", "justfile",
    "scripts/cranelift_test_levels.json", "scripts/phase22_opening.py",
    "scripts/phase26_ffi_raw_return_registration.py",
    "scripts/phase26_ffi_repr_c_registration.py",
    "scripts/phase26_ffi_repr_c_write_registration.py",
    "scripts/phase26_raw_cast_provenance_registration.py",
}


def require(value: bool, message: str) -> None:
    if not value:
        raise SystemExit(f"{GUARD}: {message}")


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def main() -> None:
    registry = json.loads((ROOT / "scripts/cranelift_feature_registry.json")
                          .read_text(encoding="utf-8"))
    activation = registry.get("phase26_activation_audit", {})
    record = activation.get("reference_return_escape_increment", {})
    expected = {
        "contract_version": "phase26_1e2_reference_return_escape_v1",
        "status": "raw_and_isolated_unbranded_reference_returns_rejected",
        "owner": "cranelift", "increment": "26.1E2",
        "boundary": "function_return_only",
        "rejected_origins": ["raw_derived", "sandbox_derived"],
        "safe_origin_return": "preserved",
        "unknown_origin_return": "preserved",
        "unsafe_local_reference_binding": "preserved",
        "safe_branded_target_policy": "unchanged",
        "diagnostic": "[UnsafeReferenceEscape]",
        "positive_fixture": FIXTURES[0],
        "negative_fixture": FIXTURES[1],
        "safe_source_fixture": FIXTURES[2],
        "failure_stage": "before_driver_discovery",
        "native_fallback": False, "physical_abi_changed": False,
        "mir_changed": False, "runtime_symbol_surface_changed": False,
        "owning_level2_guard": GUARD,
        "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"registry field drifted: {key}")
    require(set(record) == set(expected) | {
        "phase22_invocation_successor", "production_audit_successor",
        "phase23_text_surface_successor", "spelling_inventory_successor",
        "filename_site_successor",
    }, "registry acquired unreviewed E2 fields")
    for path in FIXTURES:
        require((ROOT / path).is_file(), f"registered fixture missing: {path}")

    from phase22_opening import scan_invocations
    invocation = record["phase22_invocation_successor"]
    require(invocation.get("contract_version") ==
            "phase26_1e2_phase22_invocation_successor_v1" and
            invocation.get("previous_total") == 171 and
            invocation.get("current_total") == 174 and
            invocation.get("partial_extra_or_substituted_invocation") ==
            "rejected" and
            [row for row in scan_invocations() if row["path"] == SCRIPT] ==
            invocation.get("added_rows"), "native invocation rows drifted")
    require(record["production_audit_successor"] == {
        "contract_version": "phase26_1e2_production_audit_successor_v1",
        "previous_repository_invocation_count": 171,
        "current_repository_invocation_count": 174,
        "added_invocation_path": SCRIPT,
        "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "production audit successor drifted")

    from phase24_filename_behavior_characterization import source_sites
    filename = record["filename_site_successor"]
    previous = activation["ffi_isolated_write_increment"]["filename_site_successor"]["current_sites"]
    current = source_sites()
    deltas = filename.get("line_deltas")
    require(filename.get("contract_version") ==
            "phase26_1e2_filename_site_successor_v1" and
            filename.get("previous_sites") == previous and
            filename.get("current_sites") == current and
            isinstance(deltas, list) and len(deltas) == 3 and
            all(isinstance(delta, int) and delta > 0 for delta in deltas) and
            filename.get("partial_extra_or_substituted_site") == "rejected" and
            len(previous) == len(current) == 3 and
            all(now["line"] == before["line"] + delta and
                {k: v for k, v in now.items() if k != "line"} ==
                {k: v for k, v in before.items() if k != "line"}
                for before, now, delta in zip(previous, current, deltas)),
            "filename-selected sites changed beyond E2 line shift")

    from phase24_semantic_spelling_inventory import source_sites as spelling_sites, manifest_summary
    spelling = record["spelling_inventory_successor"]
    require(spelling.get("contract_version") ==
            "phase26_1e2_spelling_inventory_successor_v1" and
            spelling.get("previous_inventory_summary") == activation[
                "ffi_isolated_write_increment"]["spelling_inventory_successor"][
                    "current_inventory_summary"] and
            spelling.get("current_inventory_summary") ==
            manifest_summary(spelling_sites()) and
            spelling.get("partial_extra_or_substituted_inventory") ==
            "rejected", "spelling inventory successor drifted")

    surface = record["phase23_text_surface_successor"]
    require(surface.get("contract_version") ==
            "phase26_1e2_phase23_text_surface_successor_v1" and
            surface.get("partial_extra_or_substituted_surface") == "rejected" and
            {row["path"] for row in surface.get("changed_rows", [])} ==
            SURFACES and
            len(surface.get("changed_rows", [])) == len(SURFACES) and
            surface.get("added_rows") == [],
            "text surface successor shape drifted")

    justfile = (ROOT / "justfile").read_text()
    workflow = (ROOT / ".github/workflows/pr-fast.yml").read_text()
    guard = (ROOT / SCRIPT).read_text()
    require(justfile.count(f"{GUARD}:") == 1 and
            "python3 scripts/phase26_reference_return_escape_registration.py" in
            justfile and workflow.count(f"just {GUARD}") == 1 and
            "poison-driver.invoked" in guard and
            "[UnsafeReferenceEscape]" in guard and
            "deferred_p13_parameter_argument_target_dependent_abi" in guard and
            "SUCCESS: unbranded Reference return escape boundary verified" in guard,
            "required native return-boundary evidence weakened")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
