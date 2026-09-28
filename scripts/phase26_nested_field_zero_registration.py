#!/usr/bin/env python3
"""Pin the bounded Phase 26.1 nested local field zero-evidence successor."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-nested-field-zero-evidence"
SCRIPT = "scripts/phase26_nested_field_zero_evidence.sh"
POSITIVE = "compiler/phase26_nested_field_zero_test_entry.gst"
NEGATIVES = [
    f"compiler/phase26_nested_field_zero_{name}_source.gst"
    for name in ("safe_call", "if_join", "while_join", "subobject", "safe_return")
]
DEFERRED = "compiler/phase26_nested_field_zero_nonzero_source.gst"


def require(value: bool, message: str) -> None:
    if not value:
        raise SystemExit(f"{GUARD}: {message}")


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def main() -> None:
    registry = json.loads((ROOT / "scripts/cranelift_feature_registry.json")
                          .read_text(encoding="utf-8"))
    activation = registry["phase26_activation_audit"]
    record = activation.get("nested_field_zero_evidence_increment", {})
    expected = {
        "contract_version": "phase26_1e_nested_local_field_zero_v1",
        "status": "bounded_nested_local_field_zero_safe_boundary_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_nested_local_field_subset",
        "operator_ownership_decision": "2026-09-28_bounded_nested_local_field_zero_evidence",
        "positive_fixture": POSITIVE, "negative_fixtures": NEGATIVES,
        "unchanged_native_deferral_fixture": DEFERRED,
        "positive_output": "SUCCESS: nested local by-value field zero evidence and exclusions verified\\n",
        "tracked_states": ["Zero", "MayZero"],
        "supported_selector_chain": "scoped_by_value_Struct_intermediates_to_RawPointer_field",
        "excluded_bases": ["RawPointer", "Reference", "index", "call"],
        "supported_propagation": ["nested_selector_write_read", "explicit_if_join",
                                  "conservative_while_join", "subobject_invalidation"],
        "unproven_and_nonzero": "admitted_without_full_nullability_claim",
        "native_nested_source_route": "deferred_source_feature_not_represented",
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
    }, "registry acquired unreviewed nested field-zero fields")
    for path in [POSITIVE, *NEGATIVES, DEFERRED]:
        require((ROOT / path).is_file(), f"registered fixture missing: {path}")

    from phase22_opening import scan_invocations
    rows = [row for row in scan_invocations() if row["path"] == SCRIPT]
    require(record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_nested_field_zero_phase22_invocation_successor_v1",
        "previous_total": 192, "current_total": 195, "added_rows": rows,
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows) == 3, "native invocation successor drifted")
    require(record["production_audit_successor"] == {
        "contract_version": "phase26_1e_nested_field_zero_production_audit_successor_v1",
        "previous_repository_invocation_count": 192,
        "current_repository_invocation_count": 195,
        "added_invocation_path": SCRIPT, "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "production audit successor drifted")

    from phase24_semantic_spelling_inventory import source_sites, manifest_summary
    arithmetic = activation.get("arithmetic_zero_evidence_increment")
    expected_spelling = (arithmetic["spelling_inventory_successor"]["previous_inventory_summary"]
                         if arithmetic else manifest_summary(source_sites()))
    require(record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_nested_field_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": activation["field_zero_evidence_increment"][
            "spelling_inventory_successor"]["current_inventory_summary"],
        "current_inventory_summary": expected_spelling,
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
                                        *NEGATIVES, DEFERRED]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "spelling inventory successor drifted")

    from phase24_filename_behavior_characterization import source_sites as filename_sites
    previous = activation["field_zero_evidence_increment"]["filename_site_successor"]["current_sites"]
    current = (arithmetic["filename_site_successor"]["previous_sites"]
               if arithmetic else filename_sites())
    require(record["filename_site_successor"] == {
        "contract_version": "phase26_1e_nested_field_zero_filename_site_successor_v1",
        "previous_sites": previous, "current_sites": current,
        "line_deltas": [now["line"] - before["line"] for before, now in zip(previous, current)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(current) == len(previous) == 3,
            "filename site successor drifted")

    surface = record["phase23_text_surface_successor"]
    successor_changes = {row["path"]: row for row in arithmetic[
        "phase23_text_surface_successor"]["changed_rows"]} if arithmetic else {}
    require(surface.get("contract_version") ==
            "phase26_1e_nested_field_zero_phase23_text_surface_successor_v1" and
            surface.get("partial_extra_or_substituted_surface") == "rejected" and
            len({row["path"] for row in surface.get("changed_rows", [])}) ==
            len(surface.get("changed_rows", [])) and
            len({row["path"] for row in surface.get("added_rows", [])}) ==
            len(surface.get("added_rows", [])), "text surface successor shape drifted")
    for row in surface["changed_rows"]:
        require(row["current_digest"] == successor_changes.get(
                    row["path"], {}).get("previous_digest", digest(row["path"])) and
                len(row["previous_digest"]) == 64,
                f"changed text surface drifted: {row['path']}")
    for row in surface["added_rows"]:
        require(row["digest"] == successor_changes.get(
                    row["path"], {}).get("previous_digest", digest(row["path"])),
                f"added text surface drifted: {row['path']}")

    justfile = (ROOT / "justfile").read_text(encoding="utf-8")
    workflow = (ROOT / ".github/workflows/pr-fast.yml").read_text(encoding="utf-8")
    guard = (ROOT / SCRIPT).read_text(encoding="utf-8")
    levels = json.loads((ROOT / "scripts/cranelift_test_levels.json")
                        .read_text(encoding="utf-8"))
    require(levels["guards"].get(GUARD) == 2 and
            justfile.count(f"{GUARD}:") == 1 and
            "python3 scripts/phase26_nested_field_zero_registration.py" in justfile and
            workflow.count(f"just {GUARD}") == 1 and
            "poison-driver.invoked" in guard and
            "GUST_TEST_MIR_TO_C_UNAVAILABLE=1" in guard and
            "[RawNullSafeBoundary]" in guard and
            "safe_call if_join while_join subobject safe_return" in guard and
            "reason_code=source_feature_not_represented" in guard and
            "phase26_field_zero_evidence.sh" in guard,
            "nested field-zero native evidence weakened")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
