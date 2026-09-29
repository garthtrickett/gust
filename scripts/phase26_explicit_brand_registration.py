#!/usr/bin/env python3
"""Pin the Phase 26.1 explicit-brand prerequisite and exact historical successors."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-explicit-brand"
SCRIPT = "scripts/phase26_explicit_brand.sh"
POSITIVE = "compiler/phase26_explicit_brand_test_entry.gst"


def require(value: bool, message: str) -> None:
    if not value:
        raise SystemExit(f"{GUARD}: {message}")


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def before_explicit_brand_digest(activation: dict, path: str, live_digest: str) -> str:
    """Reverse only this exact successor for closed text-surface owners."""
    rows = activation.get("explicit_brand_prerequisite", {}).get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])
    selected = [row for row in rows if row.get("path") == path]
    require(len(selected) <= 1, f"duplicate explicit-brand text surface: {path}")
    if not selected:
        return live_digest
    row = selected[0]
    require(row["current_digest"] == live_digest and
            len(row["previous_digest"]) == 64,
            f"explicit-brand text surface drifted: {path}")
    return row["previous_digest"]


def main() -> None:
    registry = json.loads((ROOT / "scripts/cranelift_feature_registry.json")
                          .read_text(encoding="utf-8"))
    activation = registry["phase26_activation_audit"]
    record = activation.get("explicit_brand_prerequisite", {})
    expected = {
        "contract_version": "phase26_1e_explicit_brand_prerequisite_v1",
        "status": "explicit_brand_nil_environment_migration_qualified",
        "owner": "cranelift", "increment": "26.1E_explicit_brand_prerequisite",
        "operator_ownership_decision": "2026-09-29_bounded_explicit_brand_prerequisite",
        "nil_environment_call_sites_before": 8,
        "nil_environment_call_sites_after": 0,
        "environment_aware_helper": "unchanged",
        "real_environment_callers": "unchanged",
        "positive_fixture": POSITIVE,
        "positive_output": "SUCCESS: explicit-only type brands preserve nil-environment matching\n",
        "matching_behavior": "explicit_Index_Struct_Reference_and_nested_traversal_preserved",
        "raw_null_gate": "unchanged_separate_increment",
        "native_fallback": False, "physical_abi_changed": False,
        "mir_changed": False, "runtime_symbol_surface_changed": False,
        "phase26_1_closed": False,
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"registry field drifted: {key}")
    require(set(record) == set(expected) | {
        "phase22_invocation_successor", "production_audit_successor",
        "phase23_text_surface_successor", "spelling_inventory_successor",
        "filename_site_successor",
    }, "registry acquired unreviewed explicit-brand fields")
    require((ROOT / POSITIVE).is_file(), "positive fixture missing")

    from phase22_opening import scan_invocations
    rows = [row for row in scan_invocations() if row["path"] == SCRIPT]
    require(record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_explicit_brand_phase22_invocation_successor_v1",
        "previous_total": 215, "current_total": 216, "added_rows": rows,
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows) == 1, "native invocation successor drifted")
    require(record["production_audit_successor"] == {
        "contract_version": "phase26_1e_explicit_brand_production_audit_successor_v1",
        "previous_repository_invocation_count": 215,
        "current_repository_invocation_count": 216,
        "added_invocation_path": SCRIPT, "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "production audit successor drifted")

    from phase24_semantic_spelling_inventory import source_sites, manifest_summary
    require(record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_explicit_brand_spelling_inventory_successor_v1",
        "previous_inventory_summary": activation["relational_zero_evidence_increment"][
            "spelling_inventory_successor"]["current_inventory_summary"],
        "current_inventory_summary": manifest_summary(source_sites()),
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "spelling inventory successor drifted")

    from phase24_filename_behavior_characterization import source_sites as filename_sites
    previous = activation["relational_zero_evidence_increment"][
        "filename_site_successor"]["current_sites"]
    current = filename_sites()
    require(record["filename_site_successor"] == {
        "contract_version": "phase26_1e_explicit_brand_filename_site_successor_v1",
        "previous_sites": previous, "current_sites": current,
        "line_deltas": [now["line"] - before["line"]
                        for before, now in zip(previous, current)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(current) == len(previous) == 3,
            "filename site successor drifted")

    surface = record["phase23_text_surface_successor"]
    require(surface.get("contract_version") ==
            "phase26_1e_explicit_brand_phase23_text_surface_successor_v1" and
            surface.get("partial_extra_or_substituted_surface") == "rejected" and
            len({row["path"] for row in surface.get("changed_rows", [])}) ==
            len(surface.get("changed_rows", [])) and
            len({row["path"] for row in surface.get("added_rows", [])}) ==
            len(surface.get("added_rows", [])), "text surface successor shape drifted")
    for row in surface["changed_rows"]:
        require(row["current_digest"] == digest(row["path"]) and
                len(row["previous_digest"]) == 64,
                f"changed text surface drifted: {row['path']}")
    for row in surface["added_rows"]:
        require(row["digest"] == digest(row["path"]),
                f"added text surface drifted: {row['path']}")

    justfile = (ROOT / "justfile").read_text(encoding="utf-8")
    workflow = (ROOT / ".github/workflows/pr-fast.yml").read_text(encoding="utf-8")
    guard = (ROOT / SCRIPT).read_text(encoding="utf-8")
    levels = json.loads((ROOT / "scripts/cranelift_test_levels.json")
                        .read_text(encoding="utf-8"))
    require(levels["guards"].get(GUARD) == 2 and
            justfile.count(f"{GUARD}:") == 1 and
            "python3 scripts/phase26_explicit_brand_registration.py" in justfile and
            workflow.count(f"just {GUARD}") == 1 and
            "GUST_TEST_MIR_TO_C_UNAVAILABLE=1" in guard and
            "get_explicit_type_brand(" in guard and
            "phase26_relational_zero_evidence.sh" in guard,
            "explicit-brand native evidence weakened")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
