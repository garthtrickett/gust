#!/usr/bin/env python3
"""Pin the bounded Phase 26.1 local field zero-evidence successor."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-field-zero-evidence"
SCRIPT = "scripts/phase26_field_zero_evidence.sh"
POSITIVE = "compiler/phase26_field_zero_test_entry.gst"
NEGATIVES = [
    f"compiler/phase26_field_zero_{name}_source.gst"
    for name in ("safe_call", "if_join", "while_join", "whole_reassign", "alias", "safe_return")
]


def require(value: bool, message: str) -> None:
    if not value:
        raise SystemExit(f"{GUARD}: {message}")


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def main() -> None:
    registry = json.loads((ROOT / "scripts/cranelift_feature_registry.json")
                          .read_text(encoding="utf-8"))
    activation = registry["phase26_activation_audit"]
    record = activation.get("field_zero_evidence_increment", {})
    nested_increment = activation.get("nested_field_zero_evidence_increment", {})
    nested_changed = {row["path"]: row for row in activation.get(
        "nested_field_zero_evidence_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])}
    arithmetic_changed = {row["path"]: row for row in activation.get(
        "arithmetic_zero_evidence_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])}
    division_changed = {row["path"]: row for row in activation.get(
        "division_zero_evidence_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])}
    match_changed = {row["path"]: row for row in activation.get(
        "match_zero_evidence_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])}
    take_changed = {row["path"]: row for row in activation.get(
        "take_zero_evidence_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])}

    def latest_digest(path: str, starting_digest: str) -> bool:
        expected_digest = starting_digest
        for successor in (nested_changed, arithmetic_changed, division_changed,
                          match_changed, take_changed):
            later = successor.get(path)
            if later is not None:
                if later["previous_digest"] != expected_digest:
                    return False
                expected_digest = later["current_digest"]
        return expected_digest == digest(path)
    expected = {
        "contract_version": "phase26_1e_local_field_zero_v1",
        "status": "bounded_local_field_zero_safe_boundary_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_local_field_subset",
        "operator_ownership_decision": "2026-09-28_bounded_local_field_zero_evidence",
        "positive_fixture": POSITIVE, "negative_fixtures": NEGATIVES,
        "positive_output": "SUCCESS: direct local field zero readback and nonzero preservation verified\\n",
        "tracked_states": ["Zero", "MayZero"],
        "unproven_and_nonzero": "admitted_without_full_nullability_claim",
        "supported_propagation": ["direct_local_selector_write_read",
                                  "explicit_if_join", "conservative_while_join"],
        "unsupported_alias_policy": "known_zero_path_conservatively_becomes_MayZero",
        "whole_object_reassignment": "known_zero_path_conservatively_becomes_MayZero",
        "diagnostic": "[RawNullSafeBoundary]",
        "failure_stage": "before_driver_discovery",
        "native_fallback": False, "physical_abi_changed": False,
        "mir_changed": False, "runtime_symbol_surface_changed": False,
        "general_nullability": "open_separate_obligation",
        "phase26_1_closed": False,
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"registry field drifted: {key}")
    require(set(record) == set(expected) | {
        "phase22_invocation_successor", "production_audit_successor",
        "phase23_text_surface_successor", "spelling_inventory_successor",
        "filename_site_successor",
    }, "registry acquired unreviewed field-zero fields")
    for path in [POSITIVE, *NEGATIVES]:
        require((ROOT / path).is_file(), f"registered fixture missing: {path}")

    from phase22_opening import scan_invocations
    rows = [row for row in scan_invocations() if row["path"] == SCRIPT]
    require(record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_field_zero_phase22_invocation_successor_v1",
        "previous_total": 190, "current_total": 192, "added_rows": rows,
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows) == 2, "native invocation successor drifted")
    require(record["production_audit_successor"] == {
        "contract_version": "phase26_1e_field_zero_production_audit_successor_v1",
        "previous_repository_invocation_count": 190,
        "current_repository_invocation_count": 192,
        "added_invocation_path": SCRIPT, "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "production audit successor drifted")

    from phase24_semantic_spelling_inventory import source_sites, manifest_summary
    require(record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_field_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": activation["computed_zero_raw_null_increment"][
            "spelling_inventory_successor"]["current_inventory_summary"],
        "current_inventory_summary": (manifest_summary(source_sites()) if
                                      not nested_increment else nested_increment[
                                          "spelling_inventory_successor"]["previous_inventory_summary"]),
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE, *NEGATIVES]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "spelling inventory successor drifted")

    from phase24_filename_behavior_characterization import source_sites as filename_sites
    previous = activation["computed_zero_raw_null_increment"]["filename_site_successor"]["current_sites"]
    current = (filename_sites() if not nested_increment else nested_increment[
        "filename_site_successor"]["previous_sites"])
    require(record["filename_site_successor"] == {
        "contract_version": "phase26_1e_field_zero_filename_site_successor_v1",
        "previous_sites": previous, "current_sites": current,
        "line_deltas": [now["line"] - before["line"] for before, now in zip(previous, current)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(current) == len(previous) == 3,
            "filename site successor drifted")

    surface = record["phase23_text_surface_successor"]
    require(surface.get("contract_version") ==
            "phase26_1e_field_zero_phase23_text_surface_successor_v1" and
            surface.get("partial_extra_or_substituted_surface") == "rejected" and
            len({row["path"] for row in surface.get("changed_rows", [])}) ==
            len(surface.get("changed_rows", [])) and
            len({row["path"] for row in surface.get("added_rows", [])}) ==
            len(surface.get("added_rows", [])), "text surface successor shape drifted")
    for row in surface["changed_rows"]:
        require(latest_digest(row["path"], row["current_digest"]) and
                len(row["previous_digest"]) == 64,
                f"changed text surface drifted: {row['path']}")
    for row in surface["added_rows"]:
        require(latest_digest(row["path"], row["digest"]),
                f"added text surface drifted: {row['path']}")

    justfile = (ROOT / "justfile").read_text(encoding="utf-8")
    workflow = (ROOT / ".github/workflows/pr-fast.yml").read_text(encoding="utf-8")
    guard = (ROOT / SCRIPT).read_text(encoding="utf-8")
    levels = json.loads((ROOT / "scripts/cranelift_test_levels.json")
                        .read_text(encoding="utf-8"))
    require(levels["guards"].get(GUARD) == 2 and
            justfile.count(f"{GUARD}:") == 1 and
            "python3 scripts/phase26_field_zero_registration.py" in justfile and
            workflow.count(f"just {GUARD}") == 1 and
            "poison-driver.invoked" in guard and
            "GUST_TEST_MIR_TO_C_UNAVAILABLE=1" in guard and
            "[RawNullSafeBoundary]" in guard and
            "safe_call if_join while_join whole_reassign alias safe_return" in guard and
            "phase26_computed_zero_raw_null.sh" in guard,
            "field-zero native evidence weakened")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
