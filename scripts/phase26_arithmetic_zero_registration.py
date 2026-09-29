#!/usr/bin/env python3
"""Pin the bounded Phase 26.1 subtraction/multiplication zero-evidence successor."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-arithmetic-zero-evidence"
SCRIPT = "scripts/phase26_arithmetic_zero_evidence.sh"
POSITIVE = "compiler/phase26_arithmetic_zero_test_entry.gst"
NEGATIVES = [
    f"compiler/phase26_arithmetic_zero_safe_{name}_source.gst"
    for name in ("sub_call", "mul_call", "sub_return", "mul_return")
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
    record = activation.get("arithmetic_zero_evidence_increment", {})
    division = activation.get("division_zero_evidence_increment")
    match = activation.get("match_zero_evidence_increment")
    expected = {
        "contract_version": "phase26_1e_arithmetic_zero_v1",
        "status": "bounded_arithmetic_zero_safe_boundary_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_arithmetic_zero_subset",
        "operator_ownership_decision": "2026-09-28_bounded_arithmetic_zero_evidence",
        "value_states": ["Unknown", "Zero", "Nonzero", "MayZero"],
        "transfer_ops": ["typechecked_integer_byte_subtraction",
                         "typechecked_integer_byte_multiplication"],
        "positive_fixture": POSITIVE, "negative_fixtures": NEGATIVES,
        "positive_output": "SUCCESS: arithmetic zero evidence tables, safe boundaries, and controls verified\n",
        "safe_boundaries": ["declared_nonextern_raw_pointer_return",
                            "declared_nonextern_raw_pointer_argument"],
        "negative_states": ["Zero", "MayZero"],
        "unknown_and_nonzero": "preserved_without_general_nullability_claim",
        "unsafe_callees": "preserved",
        "diagnostic": "[RawNullSafeBoundary]",
        "failure_stage": "before_driver_discovery",
        "native_fallback": False, "physical_abi_changed": False,
        "mir_changed": False, "runtime_symbol_surface_changed": False,
        "operator_semantics_changed": False,
        "general_constant_propagation": False,
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
    }, "registry acquired unreviewed arithmetic zero fields")
    for path in [POSITIVE, *NEGATIVES]:
        require((ROOT / path).is_file(), f"registered fixture missing: {path}")

    from phase22_opening import scan_invocations
    rows = [row for row in scan_invocations() if row["path"] == SCRIPT]
    require(record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_arithmetic_zero_phase22_invocation_successor_v1",
        "previous_total": 195, "current_total": 197, "added_rows": rows,
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows) == 2, "native invocation successor drifted")
    require(record["production_audit_successor"] == {
        "contract_version": "phase26_1e_arithmetic_zero_production_audit_successor_v1",
        "previous_repository_invocation_count": 195,
        "current_repository_invocation_count": 197,
        "added_invocation_path": SCRIPT, "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "production audit successor drifted")

    from phase24_semantic_spelling_inventory import source_sites, manifest_summary
    require(record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_arithmetic_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": activation["nested_field_zero_evidence_increment"][
            "spelling_inventory_successor"]["current_inventory_summary"],
        "current_inventory_summary": (manifest_summary(source_sites()) if
                                      division is None else division[
                                          "spelling_inventory_successor"]["previous_inventory_summary"]),
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
                                        *NEGATIVES]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "spelling inventory successor drifted")

    from phase24_filename_behavior_characterization import source_sites as filename_sites
    previous = activation["nested_field_zero_evidence_increment"][
        "filename_site_successor"]["current_sites"]
    current = (filename_sites() if division is None else division[
        "filename_site_successor"]["previous_sites"])
    require(record["filename_site_successor"] == {
        "contract_version": "phase26_1e_arithmetic_zero_filename_site_successor_v1",
        "previous_sites": previous, "current_sites": current,
        "line_deltas": [now["line"] - before["line"] for before, now in zip(previous, current)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(current) == len(previous) == 3,
            "filename site successor drifted")

    surface = record["phase23_text_surface_successor"]
    division_changes = {row["path"]: row for row in division[
        "phase23_text_surface_successor"]["changed_rows"]} if division else {}
    match_changes = {row["path"]: row for row in match[
        "phase23_text_surface_successor"]["changed_rows"]} if match else {}

    def latest_digest(path: str, starting_digest: str) -> bool:
        current = starting_digest
        for changes in (division_changes, match_changes):
            later = changes.get(path)
            if later is not None:
                if later["previous_digest"] != current:
                    return False
                current = later["current_digest"]
        return current == digest(path)
    require(surface.get("contract_version") ==
            "phase26_1e_arithmetic_zero_phase23_text_surface_successor_v1" and
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
            "python3 scripts/phase26_arithmetic_zero_registration.py" in justfile and
            workflow.count(f"just {GUARD}") == 1 and
            "poison-driver.invoked" in guard and
            "GUST_TEST_MIR_TO_C_UNAVAILABLE=1" in guard and
            "[RawNullSafeBoundary]" in guard and
            "sub_call mul_call sub_return mul_return" in guard and
            "phase26_computed_zero_raw_null.sh" in guard,
            "arithmetic zero native evidence weakened")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
