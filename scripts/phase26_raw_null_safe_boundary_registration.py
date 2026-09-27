#!/usr/bin/env python3
"""Pin the bounded Phase 26.1E4 raw-null safe-boundary increment."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-raw-null-safe-boundary"
SCRIPT = "scripts/phase26_raw_null_safe_boundary.sh"
FIXTURES = [
    "compiler/phase26_raw_null_safe_boundary_test_entry.gst",
    "compiler/phase26_raw_null_safe_return_source.gst",
    "compiler/phase26_raw_null_safe_call_source.gst",
]


def require(value: bool, message: str) -> None:
    if not value:
        raise SystemExit(f"{GUARD}: {message}")


def project_live_digest_to_pre_e4(registry: dict, path: str,
                                  live_digest: str) -> str:
    """Validate this increment's exact successor for a closed predecessor."""
    rows = registry.get("phase26_activation_audit", {}).get(
        "raw_null_safe_boundary_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])
    selected = [row for row in rows if row.get("path") == path]
    require(len(selected) <= 1, f"duplicate E4 text surface: {path}")
    if not selected:
        return live_digest
    row = selected[0]
    require(row["current_digest"] == live_digest and
            len(row["previous_digest"]) == 64,
            f"E4 text surface drifted: {path}")
    return str(row["previous_digest"])


def main() -> None:
    registry = json.loads((ROOT / "scripts/cranelift_feature_registry.json")
                          .read_text(encoding="utf-8"))
    activation = registry.get("phase26_activation_audit", {})
    record = activation.get("raw_null_safe_boundary_increment", {})
    expected = {
        "contract_version": "phase26_1e4_raw_null_safe_boundary_v1",
        "status": "known_zero_raw_pointer_declared_safe_boundaries_rejected",
        "owner": "cranelift", "increment": "26.1E4",
        "boundary": ["declared_safe_nonextern_raw_pointer_return",
                     "declared_safe_nonextern_raw_pointer_argument"],
        "origin_marker": "phase26.raw_null_zero_cast",
        "full_raw_nullability": "open_separate_obligation",
        "nonzero_raw_pointer": "preserved", "unknown_raw_pointer": "preserved",
        "unsafe_callee_and_return": "preserved",
        "bare_null_index_sentinel": "preserved",
        "type_mismatch_diagnostic": "preserved",
        "diagnostic": "[RawNullSafeBoundary]",
        "positive_fixture": FIXTURES[0],
        "negative_fixtures": FIXTURES[1:],
        "failure_stage": "before_driver_discovery", "native_fallback": False,
        "physical_abi_changed": False, "mir_changed": False,
        "runtime_symbol_surface_changed": False,
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"registry field drifted: {key}")
    require(set(record) == set(expected) | {
        "phase22_invocation_successor", "production_audit_successor",
        "phase23_text_surface_successor", "spelling_inventory_successor",
        "filename_site_successor",
    }, "registry acquired unreviewed E4 fields")
    for path in FIXTURES:
        require((ROOT / path).is_file(), f"registered fixture missing: {path}")

    from phase22_opening import scan_invocations
    invocation = record["phase22_invocation_successor"]
    require(invocation.get("contract_version") ==
            "phase26_1e4_phase22_invocation_successor_v1" and
            invocation.get("previous_total") == 177 and
            invocation.get("current_total") == 179 and
            invocation.get("partial_extra_or_substituted_invocation") ==
            "rejected" and
            [row for row in scan_invocations() if row["path"] == SCRIPT] ==
            invocation.get("added_rows"), "native invocation rows drifted")
    require(record["production_audit_successor"] == {
        "contract_version": "phase26_1e4_production_audit_successor_v1",
        "previous_repository_invocation_count": 177,
        "current_repository_invocation_count": 179,
        "added_invocation_path": SCRIPT,
        "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "production audit successor drifted")

    from phase24_filename_behavior_characterization import source_sites
    filename = record["filename_site_successor"]
    previous = activation["safe_reference_call_increment"]["filename_site_successor"]["current_sites"]
    current = source_sites()
    deltas = filename.get("line_deltas")
    require(filename.get("contract_version") ==
            "phase26_1e4_filename_site_successor_v1" and
            filename.get("previous_sites") == previous and
            filename.get("current_sites") == current and
            isinstance(deltas, list) and len(deltas) == 3 and
            all(delta > 0 for delta in deltas) and
            filename.get("partial_extra_or_substituted_site") == "rejected" and
            all(now["line"] == before["line"] + delta and
                {key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now, delta in zip(previous, current, deltas)),
            "filename-selected sites changed beyond E4 line shift")

    from phase24_semantic_spelling_inventory import source_sites as spelling_sites, manifest_summary
    spelling = record["spelling_inventory_successor"]
    require(spelling.get("contract_version") ==
            "phase26_1e4_spelling_inventory_successor_v1" and
            spelling.get("previous_inventory_summary") == activation[
                "safe_reference_call_increment"]["spelling_inventory_successor"][
                    "current_inventory_summary"] and
            spelling.get("current_inventory_summary") ==
            manifest_summary(spelling_sites()) and
            spelling.get("changed_source_paths") == sorted(
                ["compiler/typechecker.gst", *FIXTURES]) and
            spelling.get("partial_extra_or_substituted_inventory") ==
            "rejected", "spelling inventory successor drifted")

    surface = record["phase23_text_surface_successor"]
    require(surface.get("contract_version") ==
            "phase26_1e4_phase23_text_surface_successor_v1" and
            surface.get("partial_extra_or_substituted_surface") ==
            "rejected" and
            len({row["path"] for row in surface.get("changed_rows", [])}) ==
            len(surface.get("changed_rows", [])) and
            len({row["path"] for row in surface.get("added_rows", [])}) ==
            len(surface.get("added_rows", [])),
            "text surface successor shape drifted")

    justfile = (ROOT / "justfile").read_text(encoding="utf-8")
    workflow = (ROOT / ".github/workflows/pr-fast.yml").read_text(encoding="utf-8")
    guard = (ROOT / SCRIPT).read_text(encoding="utf-8")
    require(justfile.count(f"{GUARD}:") == 1 and
            "python3 scripts/phase26_raw_null_safe_boundary_registration.py" in justfile and
            workflow.count(f"just {GUARD}") == 1 and
            "poison-driver.invoked" in guard and
            "[RawNullSafeBoundary]" in guard and
            "typechecker.expected" in guard and
            "return call" in guard,
            "required raw-null evidence weakened")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
