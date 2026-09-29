#!/usr/bin/env python3
"""Pin the bounded Phase 26.1 take zero-evidence successor."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-take-zero-evidence"
SCRIPT = "scripts/phase26_take_zero_evidence.sh"
POSITIVE = "compiler/phase26_take_zero_test_entry.gst"
NEGATIVES = [
    f"compiler/phase26_take_zero_safe_{name}_source.gst"
    for name in ("call", "readback")
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
    record = activation.get("take_zero_evidence_increment", {})
    take_struct = activation.get("take_struct_alias_evidence_increment")
    expected = {
        "contract_version": "phase26_1e_take_zero_v1",
        "status": "bounded_take_zero_safe_boundary_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_take_zero_subset",
        "operator_ownership_decision": "2026-09-29_bounded_take_zero_transfer",
        "value_states": ["Unknown", "Zero", "Nonzero", "MayZero"],
        "transfer_ops": ["take_operand_zero_evidence_transfer"],
        "positive_fixture": POSITIVE, "negative_fixtures": NEGATIVES,
        "positive_output": "SUCCESS: take preserves known-zero evidence and existing controls\n",
        "safe_boundaries": ["declared_nonextern_raw_pointer_argument"],
        "negative_states": ["Zero", "MayZero"],
        "unknown_and_nonzero": "preserved_without_general_nullability_claim",
        "unsafe_callees": "preserved",
        "diagnostic": "[RawNullSafeBoundary]",
        "failure_stage": "before_driver_discovery",
        "native_fallback": False, "physical_abi_changed": False,
        "mir_changed": False, "runtime_symbol_surface_changed": False,
        "operator_semantics_changed": False,
        "take_move_semantics_changed": False,
        "interprocedural_return_summary": False,
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
    }, "registry acquired unreviewed take zero fields")
    for path in [POSITIVE, *NEGATIVES]:
        require((ROOT / path).is_file(), f"registered fixture missing: {path}")

    from phase22_opening import scan_invocations
    rows = [row for row in scan_invocations() if row["path"] == SCRIPT]
    require(record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_take_zero_phase22_invocation_successor_v1",
        "previous_total": 201, "current_total": 203, "added_rows": rows,
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows) == 2, "native invocation successor drifted")
    require(record["production_audit_successor"] == {
        "contract_version": "phase26_1e_take_zero_production_audit_successor_v1",
        "previous_repository_invocation_count": 201,
        "current_repository_invocation_count": 203,
        "added_invocation_path": SCRIPT, "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "production audit successor drifted")

    from phase24_semantic_spelling_inventory import source_sites, manifest_summary
    require(record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_take_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": activation["match_zero_evidence_increment"][
            "spelling_inventory_successor"]["current_inventory_summary"],
        "current_inventory_summary": (manifest_summary(source_sites()) if
                                      take_struct is None else take_struct[
                                          "spelling_inventory_successor"]["previous_inventory_summary"]),
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
                                        *NEGATIVES]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "spelling inventory successor drifted")

    from phase24_filename_behavior_characterization import source_sites as filename_sites
    previous = activation["match_zero_evidence_increment"][
        "filename_site_successor"]["current_sites"]
    current = (filename_sites() if take_struct is None else take_struct[
        "filename_site_successor"]["previous_sites"])
    require(record["filename_site_successor"] == {
        "contract_version": "phase26_1e_take_zero_filename_site_successor_v1",
        "previous_sites": previous, "current_sites": current,
        "line_deltas": [now["line"] - before["line"] for before, now in zip(previous, current)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(current) == len(previous) == 3,
            "filename site successor drifted")

    surface = record["phase23_text_surface_successor"]
    take_struct_changes = {row["path"]: row for row in take_struct[
        "phase23_text_surface_successor"]["changed_rows"]} if take_struct else {}

    def latest_digest(path: str, starting_digest: str) -> bool:
        from phase26_cast_narrowing_zero_registration import before_cast_digest
        projected_digest = before_cast_digest(activation, path, digest(path))
        later = take_struct_changes.get(path)
        if later is None:
            return starting_digest == projected_digest
        return later["previous_digest"] == starting_digest and \
            later["current_digest"] == projected_digest
    require(surface.get("contract_version") ==
            "phase26_1e_take_zero_phase23_text_surface_successor_v1" and
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
            "python3 scripts/phase26_take_zero_registration.py" in justfile and
            workflow.count(f"just {GUARD}") == 1 and
            "poison-driver.invoked" in guard and
            "GUST_TEST_MIR_TO_C_UNAVAILABLE=1" in guard and
            "[RawNullSafeBoundary]" in guard and
            "call readback" in guard and
            "phase26_match_zero_evidence.sh" in guard,
            "take zero native evidence weakened")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
