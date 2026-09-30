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
    local_record = activation.get("call_local_zero_evidence_increment", {})
    alias_record = activation.get("call_alias_zero_evidence_increment", {})
    chain_record = activation.get("call_chain_zero_evidence_increment", {})
    require(record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_call_return_zero_phase22_invocation_successor_v1",
        "previous_total": 218, "current_total": 220, "added_rows": rows[:2],
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows) == 5 and
            local_record.get("phase22_invocation_successor", {}).get("added_rows") == rows[2:3] and
            alias_record.get("phase22_invocation_successor", {}).get("added_rows") == rows[3:4] and
            chain_record.get("phase22_invocation_successor", {}).get("added_rows") == rows[4:],
            "native invocation successor drifted")
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
        "current_inventory_summary": local_record.get(
            "spelling_inventory_successor", {}).get("previous_inventory_summary"),
        "changed_source_paths": sorted(["compiler/typechecker.gst",
            "compiler/test_runner_entry.gst", POSITIVE, *NEGATIVES, *CONTROLS]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "spelling inventory successor drifted")

    from phase24_filename_behavior_characterization import source_sites as filename_sites
    previous = activation["empty_raw_zero_evidence_increment"][
        "filename_site_successor"]["current_sites"]
    current = local_record.get("filename_site_successor", {}).get("previous_sites")
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
    local_changed = {row["path"]: row for row in local_record.get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])}
    alias_changed = {row["path"]: row for row in alias_record.get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])}
    chain_changed = {row["path"]: row for row in chain_record.get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])}
    for row in surface["changed_rows"]:
        text = (ROOT / row["path"]).read_text(encoding="utf-8")
        live_digest = digest(row["path"])
        chain_successor = chain_changed.get(row["path"])
        if chain_successor:
            require(chain_successor["current_digest"] == live_digest,
                    f"consecutive-alias text surface drifted: {row['path']}")
            live_digest = chain_successor["previous_digest"]
        alias_successor = alias_changed.get(row["path"])
        if alias_successor:
            require(alias_successor["current_digest"] == live_digest,
                    f"one-hop alias text surface drifted: {row['path']}")
            live_digest = alias_successor["previous_digest"]
        live_counts = {name: len(pattern.findall(text))
                       for name, pattern in SURFACE_PATTERNS.items()}
        successor = local_changed.get(row["path"])
        require(row["current_digest"] ==
                (successor["previous_digest"] if successor else live_digest) and
                row["current_match_counts"] ==
                (successor["previous_match_counts"] if successor else live_counts) and
                (successor is None or
                 (successor["current_digest"] == live_digest and
                  successor["current_match_counts"] == live_counts)) and
                len(row["previous_digest"]) == 64,
                f"changed text surface drifted: {row['path']}")
    for row in surface["added_rows"]:
        successor = local_changed.get(row["path"])
        alias_successor = alias_changed.get(row["path"])
        live_digest = digest(row["path"])
        chain_successor = chain_changed.get(row["path"])
        if chain_successor:
            require(chain_successor["current_digest"] == live_digest,
                    f"consecutive-alias text surface drifted: {row['path']}")
            live_digest = chain_successor["previous_digest"]
        if alias_successor:
            require(alias_successor["current_digest"] == live_digest,
                    f"one-hop alias text surface drifted: {row['path']}")
            live_digest = alias_successor["previous_digest"]
        require(row["digest"] ==
                (successor["previous_digest"] if successor else live_digest),
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

    local_names = ("caller_first", "callee_first", "mayzero", "overwrite",
                   "nonzero", "unknown", "unsafe_target", "alias", "branch",
                   "loop", "prior_error")
    local_fixtures = [f"compiler/phase26_call_local_zero_{name}_source.gst"
                      for name in local_names]
    local_static = {
        "contract_version": "phase26_1e_call_local_zero_v1",
        "status": "bounded_one_local_direct_call_zero_safe_argument_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_one_local_direct_call_return_subset",
        "operator_ownership_decision": "2026-09-30_bounded_one_local_call_result_zero",
        "value_states": ["Unknown", "Zero", "Nonzero", "MayZero"],
        "candidate_shape": "concrete_nongeneric_nullary_raw_pointer_direct_call_one_local_next_direct_one_argument_expression_statement",
        "summary_order": "after_all_function_bodies_before_native_planner",
        "invalidation": "any_intervening_statement_or_nested_control_flow_or_alias_or_overwrite",
        "positive_fixture": POSITIVE,
        "negative_fixtures": local_fixtures[:3],
        "control_fixtures": local_fixtures[3:],
        "safe_boundary": "declared_nonextern_raw_pointer_argument",
        "negative_states": ["Zero", "MayZero"],
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved_without_general_nullability_claim",
        "unsafe_callees": "preserved", "diagnostic": "[RawNullSafeBoundary]",
        "failure_stage": "before_driver_discovery", "native_fallback": False,
        "physical_abi_changed": False, "mir_changed": False,
        "runtime_symbol_surface_changed": False,
        "operator_semantics_changed": False,
        "general_nullability": "open_separate_obligation", "phase26_1_closed": False,
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in local_static.items():
        require(local_record.get(key) == value,
                f"one-local successor field drifted: {key}")
    require(set(local_record) == set(local_static) | {
        "phase22_invocation_successor", "production_audit_successor",
        "spelling_inventory_successor", "filename_site_successor",
        "phase23_text_surface_successor",
    } and all((ROOT / path).is_file() for path in local_fixtures),
            "one-local successor acquired fields or lost a fixture")
    require(local_record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_call_local_zero_phase22_invocation_successor_v1",
        "previous_total": 220, "current_total": 221,
        "added_rows": rows[2:3],
        "partial_extra_or_substituted_invocation": "rejected",
    }, "one-local invocation successor drifted")
    require(local_record["production_audit_successor"] == {
        "contract_version": "phase26_1e_call_local_zero_production_audit_successor_v1",
        "previous_repository_invocation_count": 220,
        "current_repository_invocation_count": 221,
        "added_invocation_path": SCRIPT, "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "one-local production audit successor drifted")
    require(local_record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_call_local_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": record["spelling_inventory_successor"]["current_inventory_summary"],
        "current_inventory_summary": alias_record.get(
            "spelling_inventory_successor", {}).get("previous_inventory_summary"),
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
                                        *local_fixtures]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "one-local spelling inventory successor drifted")
    local_sites = alias_record.get("filename_site_successor", {}).get("previous_sites")
    require(local_record["filename_site_successor"] == {
        "contract_version": "phase26_1e_call_local_zero_filename_site_successor_v1",
        "previous_sites": record["filename_site_successor"]["current_sites"],
        "current_sites": local_sites,
        "line_deltas": [now["line"] - before["line"]
                        for before, now in zip(
                            record["filename_site_successor"]["current_sites"], local_sites)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(local_sites) == 3, "one-local filename successor drifted")
    local_surface = local_record["phase23_text_surface_successor"]
    alias_surface = alias_record.get("phase23_text_surface_successor", {})
    old_surface_rows = {
        row["path"]: (row["current_digest"], row["current_match_counts"])
        for row in surface["changed_rows"]
    }
    old_surface_rows.update({row["path"]: (row["digest"], row["match_counts"])
                             for row in surface["added_rows"]})
    require(local_surface.get("contract_version") ==
            "phase26_1e_call_local_zero_phase23_text_surface_successor_v1" and
            local_surface.get("partial_extra_or_substituted_surface") == "rejected" and
            local_surface.get("added_rows") == [] and
            sorted(row["path"] for row in local_surface.get("changed_rows", [])) ==
            sorted(["compiler/typechecker.gst", "scripts/phase22_opening.py",
                    "scripts/phase26_call_return_zero_registration.py"]),
            "one-local text surface set drifted")
    for row in local_surface["changed_rows"]:
        text = (ROOT / row["path"]).read_text(encoding="utf-8")
        successor = alias_changed.get(row["path"])
        require((row["previous_digest"], row["previous_match_counts"]) ==
                old_surface_rows[row["path"]] and
                row["current_digest"] ==
                (successor["previous_digest"] if successor else digest(row["path"])) and
                row["current_match_counts"] == {
                    name: len(pattern.findall(text))
                    for name, pattern in SURFACE_PATTERNS.items()},
                f"one-local text surface drifted: {row['path']}")
    require("for case_name in caller_first callee_first mayzero overwrite nonzero unknown unsafe_target alias branch loop prior_error" in guard and
            "phase26_call_local_zero_${case_name}_source.gst" in guard and
            "check_one_local_direct_call_shape(ctx);" in (ROOT / POSITIVE).read_text(encoding="utf-8") and
            "[RawNullSafeBoundary]" in guard and
            "reason_code=deferred_p13_parameter_argument_target_dependent_abi" in guard and
            "test ! -e \"$marker\"" in guard,
            "one-local native evidence weakened")

    alias_names = ("caller_first", "mayzero", "nonzero", "unknown",
                   "unsafe_target", "overwrite", "intervening", "chain",
                   "nested", "prior_error")
    alias_fixtures = [f"compiler/phase26_call_alias_zero_{name}_source.gst"
                      for name in alias_names]
    alias_static = {
        "contract_version": "phase26_1e_call_alias_zero_v1",
        "status": "bounded_one_hop_direct_call_zero_safe_argument_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_one_hop_call_alias_subset",
        "operator_ownership_decision": "2026-09-30_bounded_one_hop_call_alias_zero",
        "value_states": ["Unknown", "Zero", "Nonzero", "MayZero"],
        "candidate_shape": "concrete_nongeneric_nullary_raw_pointer_direct_call_local_immediate_one_by_value_raw_pointer_alias_immediate_direct_one_argument_expression_statement",
        "summary_order": "after_all_function_bodies_before_native_planner",
        "invalidation": "assignment_intervening_statement_nested_scope_second_alias_or_type_error",
        "positive_fixture": POSITIVE,
        "negative_fixtures": [local_fixtures[7], *alias_fixtures[:2]],
        "control_fixtures": alias_fixtures[2:],
        "reclassified_fixture": {
            "path": local_fixtures[7],
            "previous": "accepted_then_native_deferral",
            "current": "RawNullSafeBoundary_before_driver",
        },
        "safe_boundary": "declared_nonextern_raw_pointer_argument",
        "negative_states": ["Zero", "MayZero"],
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved_without_general_nullability_claim",
        "unsafe_callees": "preserved", "diagnostic": "[RawNullSafeBoundary]",
        "failure_stage": "before_driver_discovery", "native_fallback": False,
        "physical_abi_changed": False, "mir_changed": False,
        "runtime_symbol_surface_changed": False,
        "operator_semantics_changed": False,
        "general_nullability": "open_separate_obligation", "phase26_1_closed": False,
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in alias_static.items():
        require(alias_record.get(key) == value,
                f"one-hop alias successor field drifted: {key}")
    require(set(alias_record) == set(alias_static) | {
        "phase22_invocation_successor", "production_audit_successor",
        "spelling_inventory_successor", "filename_site_successor",
        "phase23_text_surface_successor",
    } and all((ROOT / path).is_file() for path in alias_fixtures) and
            local_fixtures[7] in local_record["control_fixtures"],
            "one-hop alias successor changed predecessor or lost a fixture")
    require(alias_record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_call_alias_zero_phase22_invocation_successor_v1",
        "previous_total": 221, "current_total": 222,
        "added_rows": rows[3:4],
        "partial_extra_or_substituted_invocation": "rejected",
    }, "one-hop alias invocation successor drifted")
    require(alias_record["production_audit_successor"] == {
        "contract_version": "phase26_1e_call_alias_zero_production_audit_successor_v1",
        "previous_repository_invocation_count": 221,
        "current_repository_invocation_count": 222,
        "added_invocation_path": SCRIPT, "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "one-hop alias production audit successor drifted")
    require(alias_record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_call_alias_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": local_record["spelling_inventory_successor"][
            "current_inventory_summary"],
        "current_inventory_summary": chain_record.get(
            "spelling_inventory_successor", {}).get("previous_inventory_summary"),
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
                                        *alias_fixtures]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "one-hop alias spelling inventory successor drifted")
    live_sites = chain_record.get("filename_site_successor", {}).get("previous_sites")
    previous_sites = local_record["filename_site_successor"]["current_sites"]
    require(alias_record["filename_site_successor"] == {
        "contract_version": "phase26_1e_call_alias_zero_filename_site_successor_v1",
        "previous_sites": previous_sites, "current_sites": live_sites,
        "line_deltas": [now["line"] - before["line"]
                        for before, now in zip(previous_sites, live_sites)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(previous_sites) == len(live_sites) == 3 and
            all(now["line"] >= before["line"] and
                {key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now in zip(previous_sites, live_sites)),
            "one-hop alias filename successor drifted")
    require(alias_surface.get("contract_version") ==
            "phase26_1e_call_alias_zero_phase23_text_surface_successor_v1" and
            alias_surface.get("partial_extra_or_substituted_surface") == "rejected" and
            alias_surface.get("added_rows") == [] and
            sorted(alias_changed) == sorted([
                "compiler/typechecker.gst", "scripts/phase22_opening.py",
                "scripts/phase26_call_return_zero_registration.py",
            ]), "one-hop alias text surface set drifted")
    predecessor_digests = {
        row["path"]: row["current_digest"]
        for row in local_surface["changed_rows"]
    }
    for row in alias_surface["changed_rows"]:
        text = (ROOT / row["path"]).read_text(encoding="utf-8")
        next_row = chain_changed.get(row["path"])
        require(row["previous_digest"] == predecessor_digests[row["path"]] and
                row["current_digest"] ==
                (next_row["previous_digest"] if next_row else digest(row["path"])) and
                row["current_match_counts"] == {
                    name: len(pattern.findall(text))
                    for name, pattern in SURFACE_PATTERNS.items()} and
                row["previous_match_counts"] == row["current_match_counts"],
                f"one-hop alias text surface drifted: {row['path']}")
    require("for case_name in caller_first mayzero nonzero unknown unsafe_target overwrite intervening chain nested prior_error" in guard and
            "phase26_call_alias_zero_${case_name}_source.gst" in guard and
            "caller_first|callee_first|mayzero|alias" in guard and
            "phase26_zero_local_call_alias_name" in (ROOT / POSITIVE).read_text(encoding="utf-8") and
            "[RawNullSafeBoundary]" in guard and
            "reason_code=deferred_p13_parameter_argument_target_dependent_abi" in guard and
            "test ! -e \"$marker\"" in guard,
            "one-hop alias native evidence weakened")

    chain_names = ("caller_first", "callee_first", "mayzero_caller_first",
                   "mayzero_callee_first", "nonzero", "unknown",
                   "unsafe_target", "overwrite", "intervening", "nested",
                   "prior_error")
    chain_fixtures = [f"compiler/phase26_call_chain_zero_{name}_source.gst"
                      for name in chain_names]
    chain_static = {
        "contract_version": "phase26_1e_call_chain_zero_v1",
        "status": "bounded_consecutive_local_call_alias_zero_safe_argument_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_consecutive_local_call_alias_subset",
        "operator_ownership_decision": "2026-09-30_bounded_consecutive_call_alias_zero",
        "value_states": ["Unknown", "Zero", "Nonzero", "MayZero"],
        "candidate_shape": "concrete_nongeneric_nullary_raw_pointer_direct_call_local_consecutive_same_block_type_matched_by_value_aliases_immediate_direct_one_argument_expression_statement",
        "summary_order": "after_all_function_bodies_before_native_planner",
        "invalidation": "assignment_intervening_statement_nested_scope_indirect_call_or_type_error",
        "positive_fixture": POSITIVE,
        "negative_fixtures": [alias_fixtures[7], *chain_fixtures[:4]],
        "control_fixtures": chain_fixtures[4:],
        "reclassified_fixture": {
            "path": alias_fixtures[7],
            "previous": "accepted_then_native_deferral",
            "current": "RawNullSafeBoundary_before_driver",
        },
        "safe_boundary": "declared_nonextern_raw_pointer_argument",
        "negative_states": ["Zero", "MayZero"],
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved_without_general_nullability_claim",
        "unsafe_callees": "preserved", "diagnostic": "[RawNullSafeBoundary]",
        "failure_stage": "before_driver_discovery", "native_fallback": False,
        "physical_abi_changed": False, "mir_changed": False,
        "runtime_symbol_surface_changed": False,
        "operator_semantics_changed": False,
        "general_nullability": "open_separate_obligation", "phase26_1_closed": False,
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in chain_static.items():
        require(chain_record.get(key) == value,
                f"consecutive-alias successor field drifted: {key}")
    require(set(chain_record) == set(chain_static) | {
        "phase22_invocation_successor", "production_audit_successor",
        "spelling_inventory_successor", "filename_site_successor",
        "phase23_text_surface_successor",
    } and all((ROOT / path).is_file() for path in chain_fixtures) and
            alias_fixtures[7] in alias_record["control_fixtures"],
            "consecutive-alias successor changed predecessor or lost a fixture")
    require(chain_record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_call_chain_zero_phase22_invocation_successor_v1",
        "previous_total": 222, "current_total": 223,
        "added_rows": rows[4:],
        "partial_extra_or_substituted_invocation": "rejected",
    }, "consecutive-alias invocation successor drifted")
    require(chain_record["production_audit_successor"] == {
        "contract_version": "phase26_1e_call_chain_zero_production_audit_successor_v1",
        "previous_repository_invocation_count": 222,
        "current_repository_invocation_count": 223,
        "added_invocation_path": SCRIPT, "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "consecutive-alias production audit successor drifted")
    require(chain_record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_call_chain_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": alias_record["spelling_inventory_successor"][
            "current_inventory_summary"],
        "current_inventory_summary": manifest_summary(source_sites()),
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
                                        *chain_fixtures]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "consecutive-alias spelling inventory successor drifted")
    previous_chain_sites = alias_record["filename_site_successor"]["current_sites"]
    current_chain_sites = filename_sites()
    require(chain_record["filename_site_successor"] == {
        "contract_version": "phase26_1e_call_chain_zero_filename_site_successor_v1",
        "previous_sites": previous_chain_sites,
        "current_sites": current_chain_sites,
        "line_deltas": [now["line"] - before["line"]
                        for before, now in zip(previous_chain_sites, current_chain_sites)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(previous_chain_sites) == len(current_chain_sites) == 3 and
            all(now["line"] >= before["line"] and
                {key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now in zip(previous_chain_sites, current_chain_sites)),
            "consecutive-alias filename successor drifted")
    chain_surface = chain_record["phase23_text_surface_successor"]
    require(chain_surface.get("contract_version") ==
            "phase26_1e_call_chain_zero_phase23_text_surface_successor_v1" and
            chain_surface.get("partial_extra_or_substituted_surface") == "rejected" and
            chain_surface.get("added_rows") == [] and
            sorted(chain_changed) == sorted([
                "compiler/typechecker.gst", "scripts/phase22_opening.py",
                "scripts/phase26_call_return_zero_registration.py",
            ]), "consecutive-alias text surface set drifted")
    for row in chain_surface["changed_rows"]:
        text = (ROOT / row["path"]).read_text(encoding="utf-8")
        predecessor = alias_changed.get(row["path"])
        require(predecessor is not None and
                row["previous_digest"] == predecessor["current_digest"] and
                row["previous_match_counts"] == predecessor["current_match_counts"] and
                row["current_digest"] == digest(row["path"]) and
                row["current_match_counts"] == {
                    name: len(pattern.findall(text))
                    for name, pattern in SURFACE_PATTERNS.items()} and
                row["previous_match_counts"] == row["current_match_counts"] and
                len(row["previous_digest"]) == 64,
                f"consecutive-alias text surface drifted: {row['path']}")
    require("for case_name in caller_first callee_first mayzero_caller_first mayzero_callee_first nonzero unknown unsafe_target overwrite intervening nested prior_error" in guard and
            "phase26_call_chain_zero_${case_name}_source.gst" in guard and
            "caller_first|callee_first|mayzero_caller_first|mayzero_callee_first" in guard and
            "chain)" in guard and
            "[RawNullSafeBoundary]" in guard and
            "reason_code=deferred_p13_parameter_argument_target_dependent_abi" in guard and
            "test ! -e \"$marker\"" in guard,
            "consecutive-alias native evidence weakened")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
