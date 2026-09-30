#!/usr/bin/env python3
"""Pin the bounded Phase 26.1 direct-call return zero-evidence successor."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-call-return-zero-evidence"
SCRIPT = "scripts/phase26_call_return_zero_evidence.sh"
POSITIVE = "compiler/phase26_call_return_zero_test_entry.gst"
NEGATIVES = [f"compiler/phase26_call_return_zero_{name}_source.gst"
             for name in ("caller_first", "callee_first", "safe_return", "mayzero")]
CONTROLS = [f"compiler/phase26_call_return_zero_{name}_source.gst"
            for name in ("nonzero", "unknown", "unsafe_target", "prior_error")]


def require(value: bool, message: str) -> None:
    if not value:
        raise SystemExit(f"{GUARD}: {message}")


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def main() -> None:
    registry = json.loads((ROOT / "scripts/cranelift_feature_registry.json")
                          .read_text(encoding="utf-8"))
    activation = registry["phase26_activation_audit"]
    record = activation.get("call_return_zero_evidence_increment", {})
    expected = {
        "contract_version": "phase26_1e_call_return_zero_v1",
        "status": "bounded_direct_call_return_zero_safe_boundary_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_direct_call_return_subset",
        "operator_ownership_decision": "2026-09-30_bounded_direct_call_return_zero",
        "value_states": ["Unknown", "Zero", "Nonzero", "MayZero"],
        "summary_shape": "concrete_nongeneric_nullary_raw_pointer_function_one_unconditional_direct_return_identifier_call",
        "summary_order": "after_all_function_bodies_before_native_planner",
        "unsupported_summaries": "Unknown_no_recursion_chains_indirect_calls_or_parameters",
        "positive_fixture": POSITIVE, "negative_fixtures": NEGATIVES,
        "control_fixtures": CONTROLS,
        "positive_output": "SUCCESS: checked direct-return zero summaries and excluded parameters and wrapped callees verified\n",
        "safe_boundaries": ["declared_nonextern_raw_pointer_argument",
                            "declared_nonextern_raw_pointer_return"],
        "negative_states": ["Zero", "MayZero"],
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved_without_general_nullability_claim",
        "unsafe_callees": "preserved",
        "diagnostic": "[RawNullSafeBoundary]",
        "failure_stage": "before_driver_discovery",
        "native_fallback": False, "physical_abi_changed": False,
        "mir_changed": False, "runtime_symbol_surface_changed": False,
        "operator_semantics_changed": False,
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
    }, "registry acquired unreviewed direct-call return fields")
    for path in [POSITIVE, *NEGATIVES, *CONTROLS]:
        require((ROOT / path).is_file(), f"registered fixture missing: {path}")

    from phase22_opening import scan_invocations
    rows = [row for row in scan_invocations() if row["path"] == SCRIPT]
    require(record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_call_return_zero_phase22_invocation_successor_v1",
        "previous_total": 218, "current_total": 220, "added_rows": rows,
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows) == 2, "native invocation successor drifted")
    require(record["production_audit_successor"] == {
        "contract_version": "phase26_1e_call_return_zero_production_audit_successor_v1",
        "previous_repository_invocation_count": 218,
        "current_repository_invocation_count": 220,
        "added_invocation_path": SCRIPT, "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "production audit successor drifted")

    from phase24_semantic_spelling_inventory import source_sites, manifest_summary
    require(record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_call_return_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": activation["empty_raw_zero_evidence_increment"][
            "spelling_inventory_successor"]["current_inventory_summary"],
        "current_inventory_summary": manifest_summary(source_sites()),
        "changed_source_paths": sorted(["compiler/typechecker.gst",
            "compiler/test_runner_entry.gst", POSITIVE, *NEGATIVES, *CONTROLS]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "spelling inventory successor drifted")

    from phase24_filename_behavior_characterization import source_sites as filename_sites
    previous = activation["empty_raw_zero_evidence_increment"][
        "filename_site_successor"]["current_sites"]
    current = filename_sites()
    require(record["filename_site_successor"] == {
        "contract_version": "phase26_1e_call_return_zero_filename_site_successor_v1",
        "previous_sites": previous, "current_sites": current,
        "line_deltas": [now["line"] - before["line"]
                        for before, now in zip(previous, current)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(current) == len(previous) == 3,
            "filename site successor drifted")

    surface = record["phase23_text_surface_successor"]
    require(surface.get("contract_version") ==
            "phase26_1e_call_return_zero_phase23_text_surface_successor_v1" and
            surface.get("partial_extra_or_substituted_surface") == "rejected" and
            len({row["path"] for row in surface.get("changed_rows", [])}) ==
            len(surface.get("changed_rows", [])) and
            len({row["path"] for row in surface.get("added_rows", [])}) ==
            len(surface.get("added_rows", [])), "text surface successor shape drifted")
    from phase23_mir_to_c_deprecation_opening import SURFACE_PATTERNS
    for row in surface["changed_rows"]:
        text = (ROOT / row["path"]).read_text(encoding="utf-8")
        require(row["current_digest"] == digest(row["path"]) and
                row["current_match_counts"] == {
                    name: len(pattern.findall(text))
                    for name, pattern in SURFACE_PATTERNS.items()} and
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
            "python3 scripts/phase26_call_return_zero_registration.py" in justfile and
            workflow.count(f"just {GUARD}") == 1 and
            "poison-driver.invoked" in guard and
            "GUST_TEST_MIR_TO_C_UNAVAILABLE=1" in guard and
            "[RawNullSafeBoundary]" in guard and
            "caller_first callee_first safe_return mayzero nonzero unknown unsafe_target prior_error" in guard and
            "phase26_empty_raw_zero_evidence.sh" in guard,
            "direct-call return native evidence weakened")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
