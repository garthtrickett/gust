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
    take_record = activation.get("call_take_alias_zero_evidence_increment", {})
    direct_take_record = activation.get("call_direct_take_zero_evidence_increment", {})
    direct_move_record = activation.get("call_direct_move_zero_evidence_increment", {})
    move_call_record = activation.get("call_move_wrapper_zero_evidence_increment", {})
    take_call_record = activation.get("call_take_wrapper_zero_evidence_increment", {})
    two_wrapper_record = activation.get("call_two_wrapper_zero_evidence_increment", {})
    wrapper_chain_record = activation.get("call_wrapper_chain_zero_evidence_increment", {})
    as_cast_record = activation.get("call_as_cast_zero_evidence_increment", {})
    as_cast_chain_record = activation.get("call_as_cast_chain_zero_evidence_increment", {})
    mixed_record = activation.get("call_mixed_cast_zero_evidence_increment", {})
    mixed_chain_record = activation.get("call_mixed_chain_zero_evidence_increment", {})
    local_cast_record = activation.get("call_local_cast_zero_evidence_increment", {})
    local_cast_chain_record = activation.get("call_local_cast_chain_zero_evidence_increment", {})
    local_take_cast_record = activation.get("call_local_take_cast_zero_evidence_increment", {})
    require(record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_call_return_zero_phase22_invocation_successor_v1",
        "previous_total": 218, "current_total": 220, "added_rows": rows[:2],
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows) == 19 and
            local_record.get("phase22_invocation_successor", {}).get("added_rows") == rows[2:3] and
            alias_record.get("phase22_invocation_successor", {}).get("added_rows") == rows[3:4] and
            chain_record.get("phase22_invocation_successor", {}).get("added_rows") == rows[4:5] and
            take_record.get("phase22_invocation_successor", {}).get("added_rows") == rows[5:6] and
            direct_take_record.get("phase22_invocation_successor", {}).get("added_rows") == rows[6:7] and
            direct_move_record.get("phase22_invocation_successor", {}).get("added_rows") == rows[7:8] and
            move_call_record.get("phase22_invocation_successor", {}).get("added_rows") == rows[8:9] and
            take_call_record.get("phase22_invocation_successor", {}).get("added_rows") == rows[9:10] and
            two_wrapper_record.get("phase22_invocation_successor", {}).get("added_rows") == rows[10:11] and
            wrapper_chain_record.get("phase22_invocation_successor", {}).get("added_rows") == rows[11:12] and
            as_cast_record.get("phase22_invocation_successor", {}).get("added_rows") == rows[12:13],
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
    take_changed = {row["path"]: row for row in take_record.get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])}
    direct_take_changed = {row["path"]: row for row in direct_take_record.get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])}
    direct_move_changed = {row["path"]: row for row in direct_move_record.get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])}
    move_call_changed = {row["path"]: row for row in move_call_record.get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])}
    take_call_changed = {row["path"]: row for row in take_call_record.get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])}
    two_wrapper_changed = {row["path"]: row for row in two_wrapper_record.get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])}
    wrapper_chain_changed = {row["path"]: row for row in wrapper_chain_record.get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])}
    as_cast_changed = {row["path"]: row for row in as_cast_record.get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])}
    as_cast_chain_changed = {row["path"]: row for row in as_cast_chain_record.get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])}
    mixed_changed = {row["path"]: row for row in mixed_record.get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])}
    mixed_chain_changed = {row["path"]: row for row in mixed_chain_record.get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])}
    local_cast_changed = {row["path"]: row for row in local_cast_record.get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])}
    local_cast_chain_changed = {row["path"]: row for row in local_cast_chain_record.get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])}
    local_take_cast_changed = {row["path"]: row for row in local_take_cast_record.get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])}
    for row in surface["changed_rows"]:
        text = (ROOT / row["path"]).read_text(encoding="utf-8")
        live_digest = digest(row["path"])
        local_take_cast_successor = local_take_cast_changed.get(row["path"])
        if local_take_cast_successor:
            require(local_take_cast_successor["current_digest"] == live_digest,
                    f"local-Take-cast text surface drifted: {row['path']}")
            live_digest = local_take_cast_successor["previous_digest"]
        local_cast_chain_successor = local_cast_chain_changed.get(row["path"])
        if local_cast_chain_successor:
            require(local_cast_chain_successor["current_digest"] == live_digest,
                    f"local-cast-chain text surface drifted: {row['path']}")
            live_digest = local_cast_chain_successor["previous_digest"]
        local_cast_successor = local_cast_changed.get(row["path"])
        if local_cast_successor:
            require(local_cast_successor["current_digest"] == live_digest,
                    f"local-cast text surface drifted: {row['path']}")
            live_digest = local_cast_successor["previous_digest"]
        chain_successor = mixed_chain_changed.get(row["path"])
        if chain_successor:
            require(chain_successor["current_digest"] == live_digest,
                    f"mixed-chain text surface drifted: {row['path']}")
            live_digest = chain_successor["previous_digest"]
        mixed_successor = mixed_changed.get(row["path"])
        if mixed_successor:
            require(mixed_successor["current_digest"] == live_digest,
                    f"mixed cast text surface drifted: {row['path']}")
            live_digest = mixed_successor["previous_digest"]
        cast_chain_successor = as_cast_chain_changed.get(row["path"])
        if cast_chain_successor:
            require(cast_chain_successor["current_digest"] == live_digest,
                    f"RawPointer AsCast-chain text surface drifted: {row['path']}")
            live_digest = cast_chain_successor["previous_digest"]
        as_cast_successor = as_cast_changed.get(row["path"])
        if as_cast_successor:
            require(as_cast_successor["current_digest"] == live_digest,
                    f"one RawPointer AsCast text surface drifted: {row['path']}")
            live_digest = as_cast_successor["previous_digest"]
        wrapper_chain_successor = wrapper_chain_changed.get(row["path"])
        if wrapper_chain_successor:
            require(wrapper_chain_successor["current_digest"] == live_digest,
                    f"wrapper-chain text surface drifted: {row['path']}")
            live_digest = wrapper_chain_successor["previous_digest"]
        two_wrapper_successor = two_wrapper_changed.get(row["path"])
        if two_wrapper_successor:
            require(two_wrapper_successor["current_digest"] == live_digest,
                    f"depth-two wrapper text surface drifted: {row['path']}")
            live_digest = two_wrapper_successor["previous_digest"]
        take_call_successor = take_call_changed.get(row["path"])
        if take_call_successor:
            require(take_call_successor["current_digest"] == live_digest,
                    f"Take(Call) text surface drifted: {row['path']}")
            live_digest = take_call_successor["previous_digest"]
        move_call_successor = move_call_changed.get(row["path"])
        if move_call_successor:
            require(move_call_successor["current_digest"] == live_digest,
                    f"Move(Call) text surface drifted: {row['path']}")
            live_digest = move_call_successor["previous_digest"]
        direct_move_successor = direct_move_changed.get(row["path"])
        if direct_move_successor:
            require(direct_move_successor["current_digest"] == live_digest,
                    f"direct-Move text surface drifted: {row['path']}")
            live_digest = direct_move_successor["previous_digest"]
        direct_take_successor = direct_take_changed.get(row["path"])
        if direct_take_successor:
            require(direct_take_successor["current_digest"] == live_digest,
                    f"direct-Take text surface drifted: {row['path']}")
            live_digest = direct_take_successor["previous_digest"]
        take_successor = take_changed.get(row["path"])
        if take_successor:
            require(take_successor["current_digest"] == live_digest,
                    f"Take-alias text surface drifted: {row['path']}")
            live_digest = take_successor["previous_digest"]
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
        local_take_cast_successor = local_take_cast_changed.get(row["path"])
        if local_take_cast_successor:
            require(local_take_cast_successor["current_digest"] == live_digest,
                    f"local-Take-cast text surface drifted: {row['path']}")
            live_digest = local_take_cast_successor["previous_digest"]
        local_cast_chain_successor = local_cast_chain_changed.get(row["path"])
        if local_cast_chain_successor:
            require(local_cast_chain_successor["current_digest"] == live_digest,
                    f"local-cast-chain text surface drifted: {row['path']}")
            live_digest = local_cast_chain_successor["previous_digest"]
        local_cast_successor = local_cast_changed.get(row["path"])
        if local_cast_successor:
            require(local_cast_successor["current_digest"] == live_digest,
                    f"local-cast text surface drifted: {row['path']}")
            live_digest = local_cast_successor["previous_digest"]
        chain_successor = mixed_chain_changed.get(row["path"])
        if chain_successor:
            require(chain_successor["current_digest"] == live_digest,
                    f"mixed-chain text surface drifted: {row['path']}")
            live_digest = chain_successor["previous_digest"]
        mixed_successor = mixed_changed.get(row["path"])
        if mixed_successor:
            require(mixed_successor["current_digest"] == live_digest,
                    f"mixed cast text surface drifted: {row['path']}")
            live_digest = mixed_successor["previous_digest"]
        cast_chain_successor = as_cast_chain_changed.get(row["path"])
        if cast_chain_successor:
            require(cast_chain_successor["current_digest"] == live_digest,
                    f"RawPointer AsCast-chain text surface drifted: {row['path']}")
            live_digest = cast_chain_successor["previous_digest"]
        as_cast_successor = as_cast_changed.get(row["path"])
        if as_cast_successor:
            require(as_cast_successor["current_digest"] == live_digest,
                    f"one RawPointer AsCast text surface drifted: {row['path']}")
            live_digest = as_cast_successor["previous_digest"]
        wrapper_chain_successor = wrapper_chain_changed.get(row["path"])
        if wrapper_chain_successor:
            require(wrapper_chain_successor["current_digest"] == live_digest,
                    f"wrapper-chain text surface drifted: {row['path']}")
            live_digest = wrapper_chain_successor["previous_digest"]
        two_wrapper_successor = two_wrapper_changed.get(row["path"])
        if two_wrapper_successor:
            require(two_wrapper_successor["current_digest"] == live_digest,
                    f"depth-two wrapper text surface drifted: {row['path']}")
            live_digest = two_wrapper_successor["previous_digest"]
        take_call_successor = take_call_changed.get(row["path"])
        if take_call_successor:
            require(take_call_successor["current_digest"] == live_digest,
                    f"Take(Call) text surface drifted: {row['path']}")
            live_digest = take_call_successor["previous_digest"]
        move_call_successor = move_call_changed.get(row["path"])
        if move_call_successor:
            require(move_call_successor["current_digest"] == live_digest,
                    f"Move(Call) text surface drifted: {row['path']}")
            live_digest = move_call_successor["previous_digest"]
        direct_move_successor = direct_move_changed.get(row["path"])
        if direct_move_successor:
            require(direct_move_successor["current_digest"] == live_digest,
                    f"direct-Move text surface drifted: {row['path']}")
            live_digest = direct_move_successor["previous_digest"]
        direct_take_successor = direct_take_changed.get(row["path"])
        if direct_take_successor:
            require(direct_take_successor["current_digest"] == live_digest,
                    f"direct-Take text surface drifted: {row['path']}")
            live_digest = direct_take_successor["previous_digest"]
        take_successor = take_changed.get(row["path"])
        if take_successor:
            require(take_successor["current_digest"] == live_digest,
                    f"Take-alias text surface drifted: {row['path']}")
            live_digest = take_successor["previous_digest"]
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
        "added_rows": rows[4:5],
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
        "current_inventory_summary": take_record.get(
            "spelling_inventory_successor", {}).get("previous_inventory_summary"),
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
                                        *chain_fixtures]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "consecutive-alias spelling inventory successor drifted")
    previous_chain_sites = alias_record["filename_site_successor"]["current_sites"]
    current_chain_sites = take_record.get("filename_site_successor", {}).get(
        "previous_sites")
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
        successor = take_changed.get(row["path"])
        require(predecessor is not None and
                row["previous_digest"] == predecessor["current_digest"] and
                row["previous_match_counts"] == predecessor["current_match_counts"] and
                row["current_digest"] ==
                (successor["previous_digest"] if successor else digest(row["path"])) and
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

    take_names = ("caller_first", "callee_first", "mayzero_caller_first",
                  "mayzero_callee_first", "nonzero", "unknown", "unsafe_target",
                  "overwrite", "intervening", "nested", "chained_after_take",
                  "prior_error", "direct_take_argument", "safe_return",
                  "literal_take")
    take_fixtures = [f"compiler/phase26_call_take_alias_zero_{name}_source.gst"
                     for name in take_names]
    take_static = {
        "contract_version": "phase26_1e_call_take_alias_zero_v1",
        "status": "bounded_terminal_take_alias_zero_safe_argument_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_terminal_take_call_alias_subset",
        "operator_ownership_decision": "2026-09-30_bounded_terminal_take_call_alias_zero",
        "value_states": ["Unknown", "Zero", "Nonzero", "MayZero"],
        "candidate_shape": "existing_concrete_direct_nullary_call_local_candidate_one_terminal_immediate_Take_Identifier_alias_then_direct_safe_one_argument_call",
        "take_alias_terminal": True,
        "summary_order": "after_all_function_bodies_before_native_planner",
        "invalidation": "assignment_intervening_statement_nested_scope_second_alias_or_type_error",
        "positive_fixture": POSITIVE,
        "negative_fixtures": [*take_fixtures[:4], take_fixtures[-1]],
        "control_fixtures": take_fixtures[4:-1],
        "safe_boundary": "declared_nonextern_raw_pointer_argument",
        "negative_states": ["Zero", "MayZero"],
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved_without_general_nullability_claim",
        "unsafe_callees": "preserved",
        "direct_Take_argument": "separate_uncovered_shape",
        "safe_return_escape": "preserved",
        "take_move_semantics_changed": False,
        "diagnostic": "[RawNullSafeBoundary]",
        "failure_stage": "before_driver_discovery", "native_fallback": False,
        "physical_abi_changed": False, "mir_changed": False,
        "runtime_symbol_surface_changed": False,
        "operator_semantics_changed": False,
        "general_nullability": "open_separate_obligation", "phase26_1_closed": False,
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in take_static.items():
        require(take_record.get(key) == value,
                f"Take-alias successor field drifted: {key}")
    require(set(take_record) == set(take_static) | {
        "phase22_invocation_successor", "production_audit_successor",
        "spelling_inventory_successor", "filename_site_successor",
        "phase23_text_surface_successor",
    } and all((ROOT / path).is_file() for path in take_fixtures),
            "Take-alias successor fields or fixtures drifted")
    require(take_record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_call_take_alias_zero_phase22_invocation_successor_v1",
        "previous_total": 223, "current_total": 224,
        "added_rows": rows[5:6],
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows[5:6]) == 1, "Take-alias invocation successor drifted")
    require(take_record["production_audit_successor"] == {
        "contract_version": "phase26_1e_call_take_alias_zero_production_audit_successor_v1",
        "previous_repository_invocation_count": 223,
        "current_repository_invocation_count": 224,
        "added_invocation_path": SCRIPT, "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "Take-alias production audit successor drifted")
    require(take_record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_call_take_alias_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": chain_record["spelling_inventory_successor"]["current_inventory_summary"],
        "current_inventory_summary": direct_take_record.get(
            "spelling_inventory_successor", {}).get("previous_inventory_summary"),
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
                                        *take_fixtures]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "Take-alias spelling inventory successor drifted")
    previous_take_sites = chain_record["filename_site_successor"]["current_sites"]
    current_take_sites = direct_take_record.get(
        "filename_site_successor", {}).get("previous_sites")
    require(take_record["filename_site_successor"] == {
        "contract_version": "phase26_1e_call_take_alias_zero_filename_site_successor_v1",
        "previous_sites": previous_take_sites,
        "current_sites": current_take_sites,
        "line_deltas": [now["line"] - before["line"]
                        for before, now in zip(previous_take_sites, current_take_sites)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(previous_take_sites) == len(current_take_sites) == 3 and
            all(now["line"] >= before["line"] and
                {key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now in zip(previous_take_sites, current_take_sites)),
            "Take-alias filename successor drifted")
    take_surface = take_record["phase23_text_surface_successor"]
    require(take_surface.get("contract_version") ==
            "phase26_1e_call_take_alias_zero_phase23_text_surface_successor_v1" and
            take_surface.get("partial_extra_or_substituted_surface") == "rejected" and
            take_surface.get("added_rows") == [] and
            sorted(take_changed) == sorted([
                "compiler/typechecker.gst", "scripts/phase22_opening.py",
                "scripts/phase26_call_return_zero_registration.py",
            ]), "Take-alias text surface set drifted")
    for row in take_surface["changed_rows"]:
        text = (ROOT / row["path"]).read_text(encoding="utf-8")
        predecessor = chain_changed.get(row["path"])
        require(row["previous_digest"] ==
                (predecessor["current_digest"] if predecessor else
                 row["previous_digest"]) and
                len(row["previous_digest"]) == 64 and
                row["current_digest"] ==
                (direct_take_changed[row["path"]]["previous_digest"]
                 if row["path"] in direct_take_changed else digest(row["path"])) and
                row["current_match_counts"] == {
                    name: len(pattern.findall(text))
                    for name, pattern in SURFACE_PATTERNS.items()} and
                row["previous_match_counts"] == row["current_match_counts"],
                f"Take-alias text surface drifted: {row['path']}")
    require("phase26_call_take_alias_zero_${case_name}_source.gst" in guard and
            "chained_after_take" in guard and
            "direct_take_argument" in guard and
            "literal_take" in guard and
            "safe_return" in guard and
            "[RawNullSafeBoundary]" in guard and
            "test ! -e \"$marker\"" in guard,
            "Take-alias native evidence weakened")

    direct_names = ("caller_first", "mayzero_caller_first",
                    "mayzero_callee_first", "plain_chain", "literal_take",
                    "nonzero", "unknown", "unsafe_target", "overwrite",
                    "intervening", "nested", "nested_take", "second_take",
                    "prior_error", "type_mismatch")
    direct_fixtures = [f"compiler/phase26_call_direct_take_zero_{name}_source.gst"
                       for name in direct_names]
    promoted = "compiler/phase26_call_take_alias_zero_direct_take_argument_source.gst"
    direct_static = {
        "contract_version": "phase26_1e_call_direct_take_zero_v1",
        "status": "bounded_direct_terminal_take_argument_zero_safe_boundary_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_direct_terminal_take_argument_subset",
        "operator_ownership_decision": "2026-09-30_bounded_direct_terminal_take_argument_zero",
        "value_states": ["Unknown", "Zero", "Nonzero", "MayZero"],
        "candidate_shape": "existing_concrete_direct_nullary_call_local_candidate_optional_consecutive_plain_alias_then_immediate_direct_Take_Identifier_one_argument_safe_call",
        "summary_order": "after_all_function_bodies_before_native_planner",
        "terminal_take_hops": 1,
        "excluded_shapes": ["prior_terminal_Take_alias", "nested_or_second_Take",
                            "intervening_statement", "indirect_call",
                            "mismatched_argument_type", "nested_scope"],
        "promoted_predecessor_fixture": promoted,
        "predecessor_disposition": "native_explicit_deferral_before_driver",
        "current_disposition": "canonical_RawNullSafeBoundary_before_planner",
        "positive_fixture": POSITIVE,
        "negative_fixtures": [promoted, *direct_fixtures[:5]],
        "control_fixtures": direct_fixtures[5:],
        "safe_boundary": "declared_nonextern_raw_pointer_argument",
        "negative_states": ["Zero", "MayZero"],
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved_without_general_nullability_claim",
        "unsafe_callees": "preserved",
        "take_move_semantics_changed": False,
        "diagnostic": "[RawNullSafeBoundary]",
        "failure_stage": "before_driver_discovery", "native_fallback": False,
        "physical_abi_changed": False, "mir_changed": False,
        "runtime_symbol_surface_changed": False,
        "operator_semantics_changed": False,
        "general_nullability": "open_separate_obligation", "phase26_1_closed": False,
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in direct_static.items():
        require(direct_take_record.get(key) == value,
                f"direct-Take successor field drifted: {key}")
    require(set(direct_take_record) == set(direct_static) | {
        "phase22_invocation_successor", "production_audit_successor",
        "spelling_inventory_successor", "filename_site_successor",
        "phase23_text_surface_successor",
    } and all((ROOT / path).is_file() for path in direct_fixtures),
            "direct-Take successor fields or fixtures drifted")
    require(direct_take_record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_call_direct_take_zero_phase22_invocation_successor_v1",
        "previous_total": 224, "current_total": 225,
        "added_rows": rows[6:7],
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows[6:7]) == 1, "direct-Take invocation successor drifted")
    require(direct_take_record["production_audit_successor"] == {
        "contract_version": "phase26_1e_call_direct_take_zero_production_audit_successor_v1",
        "previous_repository_invocation_count": 224,
        "current_repository_invocation_count": 225,
        "added_invocation_path": SCRIPT, "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "direct-Take production audit successor drifted")
    require(direct_take_record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_call_direct_take_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": take_record["spelling_inventory_successor"][
            "current_inventory_summary"],
        "current_inventory_summary": direct_move_record.get(
            "spelling_inventory_successor", {}).get("previous_inventory_summary"),
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
                                        *direct_fixtures]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "direct-Take spelling inventory successor drifted")
    previous_direct_sites = take_record["filename_site_successor"]["current_sites"]
    current_direct_sites = direct_move_record.get(
        "filename_site_successor", {}).get("previous_sites")
    require(direct_take_record["filename_site_successor"] == {
        "contract_version": "phase26_1e_call_direct_take_zero_filename_site_successor_v1",
        "previous_sites": previous_direct_sites,
        "current_sites": current_direct_sites,
        "line_deltas": [now["line"] - before["line"]
                        for before, now in zip(previous_direct_sites, current_direct_sites)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(previous_direct_sites) == len(current_direct_sites) == 3 and
            all(now["line"] >= before["line"] and
                {key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now in zip(previous_direct_sites, current_direct_sites)),
            "direct-Take filename successor drifted")
    direct_surface = direct_take_record["phase23_text_surface_successor"]
    require(direct_surface.get("contract_version") ==
            "phase26_1e_call_direct_take_zero_phase23_text_surface_successor_v1" and
            direct_surface.get("partial_extra_or_substituted_surface") == "rejected" and
            direct_surface.get("added_rows") == [] and
            sorted(direct_take_changed) == sorted([
                "compiler/typechecker.gst", "scripts/phase22_opening.py",
                "scripts/phase26_call_return_zero_registration.py",
            ]), "direct-Take text surface set drifted")
    for row in direct_surface["changed_rows"]:
        text = (ROOT / row["path"]).read_text(encoding="utf-8")
        predecessor = take_changed.get(row["path"])
        require(row["previous_digest"] ==
                (predecessor["current_digest"] if predecessor else
                 row["previous_digest"]) and
                len(row["previous_digest"]) == 64 and
                row["current_digest"] ==
                (direct_move_changed[row["path"]]["previous_digest"]
                 if row["path"] in direct_move_changed else digest(row["path"])) and
                row["current_match_counts"] == {
                    name: len(pattern.findall(text))
                    for name, pattern in SURFACE_PATTERNS.items()} and
                row["previous_match_counts"] == row["current_match_counts"],
                f"direct-Take text surface drifted: {row['path']}")
    require("phase26_call_direct_take_zero_${case_name}_source.gst" in guard and
            "direct_take_argument" in guard and
            "plain_chain" in guard and
            "nested_take" in guard and
            "second_take" in guard and
            "type_mismatch" in guard and
            "[RawNullSafeBoundary]" in guard and
            "test ! -e \"$marker\"" in guard,
            "direct-Take native evidence weakened")
    move_names = ("caller_first", "mayzero_caller_first", "mayzero_callee_first",
                  "plain_chain", "literal_move", "nonzero", "unknown",
                  "unsafe_target", "overwrite", "intervening", "nested",
                  "nested_move", "second_move", "prior_take_alias",
                  "move_alias", "prior_error", "type_mismatch")
    move_fixtures = [f"compiler/phase26_call_direct_move_zero_{name}_source.gst"
                     for name in move_names]
    move_static = {
        "contract_version": "phase26_1e_call_direct_move_zero_v1",
        "status": "bounded_direct_terminal_move_argument_zero_safe_boundary_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_direct_terminal_move_argument_subset",
        "operator_ownership_decision": "2026-10-01_bounded_direct_terminal_move_argument_zero",
        "value_states": ["Unknown", "Zero", "Nonzero", "MayZero"],
        "candidate_shape": "existing_concrete_direct_nullary_call_local_candidate_optional_consecutive_plain_alias_then_immediate_direct_Move_Identifier_one_argument_safe_call",
        "summary_order": "after_all_function_bodies_before_native_planner",
        "terminal_move_hops": 1,
        "excluded_shapes": ["prior_terminal_Take_alias", "nested_or_second_Move",
                            "Move_alias_declaration", "intervening_statement",
                            "indirect_call", "mismatched_argument_type", "nested_scope"],
        "positive_fixture": POSITIVE,
        "negative_fixtures": move_fixtures[:5],
        "control_fixtures": move_fixtures[5:],
        "safe_boundary": "declared_nonextern_raw_pointer_argument",
        "negative_states": ["Zero", "MayZero"],
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved_without_general_nullability_claim",
        "unsafe_callees": "preserved",
        "take_move_semantics_changed": False,
        "diagnostic": "[RawNullSafeBoundary]",
        "failure_stage": "before_driver_discovery", "native_fallback": False,
        "physical_abi_changed": False, "mir_changed": False,
        "runtime_symbol_surface_changed": False,
        "operator_semantics_changed": False,
        "general_nullability": "open_separate_obligation", "phase26_1_closed": False,
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in move_static.items():
        require(direct_move_record.get(key) == value,
                f"direct-Move successor field drifted: {key}")
    require(set(direct_move_record) == set(move_static) | {
        "phase22_invocation_successor", "production_audit_successor",
        "spelling_inventory_successor", "filename_site_successor",
        "phase23_text_surface_successor",
    } and all((ROOT / path).is_file() for path in move_fixtures),
            "direct-Move successor fields or fixtures drifted")
    require(direct_move_record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_call_direct_move_zero_phase22_invocation_successor_v1",
        "previous_total": 225, "current_total": 226,
        "added_rows": rows[7:8],
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows[7:8]) == 1, "direct-Move invocation successor drifted")
    require(direct_move_record["production_audit_successor"] == {
        "contract_version": "phase26_1e_call_direct_move_zero_production_audit_successor_v1",
        "previous_repository_invocation_count": 225,
        "current_repository_invocation_count": 226,
        "added_invocation_path": SCRIPT, "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "direct-Move production audit successor drifted")
    require(direct_move_record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_call_direct_move_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": direct_take_record["spelling_inventory_successor"][
            "current_inventory_summary"],
        "current_inventory_summary": move_call_record.get(
            "spelling_inventory_successor", {}).get("previous_inventory_summary"),
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
                                        *move_fixtures]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "direct-Move spelling inventory successor drifted")
    previous_move_sites = direct_take_record["filename_site_successor"]["current_sites"]
    current_move_sites = move_call_record.get("filename_site_successor", {}).get(
        "previous_sites")
    require(direct_move_record["filename_site_successor"] == {
        "contract_version": "phase26_1e_call_direct_move_zero_filename_site_successor_v1",
        "previous_sites": previous_move_sites,
        "current_sites": current_move_sites,
        "line_deltas": [now["line"] - before["line"]
                        for before, now in zip(previous_move_sites, current_move_sites)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(previous_move_sites) == len(current_move_sites) == 3 and
            all(now["line"] >= before["line"] and
                {key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now in zip(previous_move_sites, current_move_sites)),
            "direct-Move filename successor drifted")
    move_surface = direct_move_record["phase23_text_surface_successor"]
    require(move_surface.get("contract_version") ==
            "phase26_1e_call_direct_move_zero_phase23_text_surface_successor_v1" and
            move_surface.get("partial_extra_or_substituted_surface") == "rejected" and
            move_surface.get("added_rows") == [] and
            sorted(direct_move_changed) == sorted([
                "compiler/typechecker.gst", "scripts/phase22_opening.py",
                "scripts/phase26_call_return_zero_registration.py",
            ]), "direct-Move text surface set drifted")
    for row in move_surface["changed_rows"]:
        text = (ROOT / row["path"]).read_text(encoding="utf-8")
        predecessor = direct_take_changed.get(row["path"])
        require(row["previous_digest"] == predecessor["current_digest"] and
                len(row["previous_digest"]) == 64 and
                row["current_digest"] ==
                (move_call_changed[row["path"]]["previous_digest"]
                 if row["path"] in move_call_changed else digest(row["path"])) and
                row["current_match_counts"] == {
                    name: len(pattern.findall(text))
                    for name, pattern in SURFACE_PATTERNS.items()} and
                row["previous_match_counts"] == row["current_match_counts"],
                f"direct-Move text surface drifted: {row['path']}")
    require("phase26_call_direct_move_zero_${case_name}_source.gst" in guard and
            "literal_move" in guard and "plain_chain" in guard and
            "nested_move" in guard and "second_move" in guard and
            "move_alias" in guard and "prior_take_alias" in guard and
            "type_mismatch" in guard and "[RawNullSafeBoundary]" in guard and
            "test ! -e \"$marker\"" in guard,
            "direct-Move native evidence weakened")

    move_call_names = ("argument_caller_first", "argument_callee_first",
                       "argument_mayzero_caller_first", "argument_mayzero_callee_first",
                       "return_caller_first", "return_callee_first",
                       "return_mayzero_caller_first", "return_mayzero_callee_first",
                       "nonzero", "unknown", "unsafe_target", "prior_error",
                       "nested_move", "take", "type_mismatch")
    move_call_fixtures = [f"compiler/phase26_call_move_wrapper_zero_{name}_source.gst"
                          for name in move_call_names]
    move_call_static = {
        "contract_version": "phase26_1e_call_move_wrapper_zero_v1",
        "status": "bounded_one_Move_Call_raw_pointer_safe_boundary_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_one_Move_Call_boundary_subset",
        "operator_ownership_decision": "2026-10-01_bounded_one_Move_Call_boundary",
        "value_states": ["Unknown", "Zero", "Nonzero", "MayZero"],
        "candidate_shape": "one_syntactic_Move_around_concrete_direct_nullary_raw_pointer_Call_at_type_matched_safe_argument_or_return_boundary",
        "summary_order": "after_all_function_bodies_before_native_planner",
        "move_wrapper_hops": 1,
        "excluded_shapes": ["nested_Move", "Take", "wrapped_or_indirect_callee",
                            "generic_call", "local_candidate_seeding"],
        "positive_fixture": POSITIVE,
        "negative_fixtures": move_call_fixtures[:8],
        "control_fixtures": move_call_fixtures[8:],
        "safe_boundaries": ["declared_nonextern_raw_pointer_argument",
                            "declared_nonextern_raw_pointer_return"],
        "negative_states": ["Zero", "MayZero"],
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved_without_general_nullability_claim",
        "unsafe_callees": "preserved", "take_move_semantics_changed": False,
        "diagnostic": "[RawNullSafeBoundary]",
        "failure_stage": "before_driver_discovery", "native_fallback": False,
        "physical_abi_changed": False, "mir_changed": False,
        "runtime_symbol_surface_changed": False,
        "operator_semantics_changed": False,
        "general_nullability": "open_separate_obligation", "phase26_1_closed": False,
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in move_call_static.items():
        require(move_call_record.get(key) == value,
                f"Move(Call) successor field drifted: {key}")
    require(set(move_call_record) == set(move_call_static) | {
        "phase22_invocation_successor", "production_audit_successor",
        "spelling_inventory_successor", "filename_site_successor",
        "phase23_text_surface_successor",
    } and all((ROOT / path).is_file() for path in move_call_fixtures),
            "Move(Call) successor fields or fixtures drifted")
    require(move_call_record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_call_move_wrapper_zero_phase22_invocation_successor_v1",
        "previous_total": 226, "current_total": 227,
        "added_rows": rows[8:9],
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows[8:9]) == 1, "Move(Call) invocation successor drifted")
    require(move_call_record["production_audit_successor"] == {
        "contract_version": "phase26_1e_call_move_wrapper_zero_production_audit_successor_v1",
        "previous_repository_invocation_count": 226,
        "current_repository_invocation_count": 227,
        "added_invocation_path": SCRIPT, "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "Move(Call) production audit successor drifted")
    require(move_call_record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_call_move_wrapper_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": direct_move_record[
            "spelling_inventory_successor"]["current_inventory_summary"],
        "current_inventory_summary": take_call_record.get(
            "spelling_inventory_successor", {}).get("previous_inventory_summary"),
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
                                        *move_call_fixtures]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "Move(Call) spelling inventory successor drifted")
    previous_move_call_sites = direct_move_record["filename_site_successor"]["current_sites"]
    current_move_call_sites = take_call_record.get(
        "filename_site_successor", {}).get("previous_sites")
    require(move_call_record["filename_site_successor"] == {
        "contract_version": "phase26_1e_call_move_wrapper_zero_filename_site_successor_v1",
        "previous_sites": previous_move_call_sites,
        "current_sites": current_move_call_sites,
        "line_deltas": [now["line"] - before["line"]
                        for before, now in zip(previous_move_call_sites,
                                               current_move_call_sites)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(previous_move_call_sites) == len(current_move_call_sites) == 3 and
            all(now["line"] >= before["line"] and
                {key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now in zip(previous_move_call_sites, current_move_call_sites)),
            "Move(Call) filename successor drifted")
    move_call_surface = move_call_record["phase23_text_surface_successor"]
    require(move_call_surface.get("contract_version") ==
            "phase26_1e_call_move_wrapper_zero_phase23_text_surface_successor_v1" and
            move_call_surface.get("partial_extra_or_substituted_surface") == "rejected" and
            move_call_surface.get("added_rows") == [] and
            sorted(move_call_changed) == sorted([
                "compiler/typechecker.gst", "scripts/phase22_opening.py",
                "scripts/phase26_call_return_zero_registration.py",
            ]), "Move(Call) text surface set drifted")
    old_move_rows = {row["path"]: row for row in move_surface["changed_rows"]}
    for row in move_call_surface["changed_rows"]:
        text = (ROOT / row["path"]).read_text(encoding="utf-8")
        require(row["previous_digest"] == old_move_rows[row["path"]]["current_digest"] and
                row["current_digest"] ==
                (take_call_changed[row["path"]]["previous_digest"]
                 if row["path"] in take_call_changed else digest(row["path"])) and
                row["current_match_counts"] ==
                (take_call_changed[row["path"]]["previous_match_counts"]
                 if row["path"] in take_call_changed else {
                     name: len(pattern.findall(text))
                     for name, pattern in SURFACE_PATTERNS.items()}) and
                row["previous_match_counts"] == row["current_match_counts"],
                f"Move(Call) text surface drifted: {row['path']}")
    require("phase26_call_move_wrapper_zero_${case_name}_source.gst" in guard and
            "return_mayzero_callee_first" in guard and "nested_move" in guard and
            "type_mismatch" in guard and "check_one_move_call_boundary(ctx);" in
            (ROOT / POSITIVE).read_text(encoding="utf-8") and
            "[RawNullSafeBoundary]" in guard and
            "test ! -e \"$marker\"" in guard,
            "Move(Call) native evidence weakened")

    take_call_names = ("argument_caller_first", "argument_callee_first",
                       "argument_mayzero_caller_first", "argument_mayzero_callee_first",
                       "return_caller_first", "return_callee_first",
                       "return_mayzero_caller_first", "return_mayzero_callee_first",
                       "nonzero", "unknown", "unsafe_target", "prior_error",
                       "nested_take", "move_take", "type_mismatch")
    take_call_fixtures = [f"compiler/phase26_call_take_wrapper_zero_{name}_source.gst"
                          for name in take_call_names]
    take_call_static = {
        "contract_version": "phase26_1e_call_take_wrapper_zero_v1",
        "status": "bounded_one_Take_Call_raw_pointer_safe_boundary_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_one_Take_Call_boundary_subset",
        "operator_ownership_decision": "2026-10-01_bounded_one_Take_Call_boundary",
        "value_states": ["Unknown", "Zero", "Nonzero", "MayZero"],
        "candidate_shape": "one_syntactic_Take_around_concrete_direct_nullary_raw_pointer_Call_at_type_matched_safe_argument_or_return_boundary",
        "summary_order": "after_all_function_bodies_before_native_planner",
        "take_wrapper_hops": 1,
        "excluded_shapes": ["nested_Take", "Move_Take_Call", "wrapped_or_indirect_callee",
                            "generic_call", "local_candidate_seeding"],
        "promoted_predecessor_control":
            "compiler/phase26_call_move_wrapper_zero_take_source.gst",
        "positive_fixture": POSITIVE,
        "negative_fixtures": take_call_fixtures[:8],
        "control_fixtures": take_call_fixtures[8:],
        "safe_boundaries": ["declared_nonextern_raw_pointer_argument",
                            "declared_nonextern_raw_pointer_return"],
        "negative_states": ["Zero", "MayZero"],
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved_without_general_nullability_claim",
        "unsafe_callees": "preserved", "take_move_semantics_changed": False,
        "diagnostic": "[RawNullSafeBoundary]",
        "failure_stage": "before_driver_discovery", "native_fallback": False,
        "physical_abi_changed": False, "mir_changed": False,
        "runtime_symbol_surface_changed": False,
        "operator_semantics_changed": False,
        "general_nullability": "open_separate_obligation", "phase26_1_closed": False,
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in take_call_static.items():
        require(take_call_record.get(key) == value,
                f"Take(Call) successor field drifted: {key}")
    require(set(take_call_record) == set(take_call_static) | {
        "phase22_invocation_successor", "production_audit_successor",
        "spelling_inventory_successor", "filename_site_successor",
        "phase23_text_surface_successor",
    } and all((ROOT / path).is_file() for path in take_call_fixtures),
            "Take(Call) successor fields or fixtures drifted")
    require(take_call_record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_call_take_wrapper_zero_phase22_invocation_successor_v1",
        "previous_total": 227, "current_total": 228,
        "added_rows": rows[9:10],
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows[9:10]) == 1, "Take(Call) invocation successor drifted")
    require(take_call_record["production_audit_successor"] == {
        "contract_version": "phase26_1e_call_take_wrapper_zero_production_audit_successor_v1",
        "previous_repository_invocation_count": 227,
        "current_repository_invocation_count": 228,
        "added_invocation_path": SCRIPT, "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "Take(Call) production audit successor drifted")
    require(take_call_record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_call_take_wrapper_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": move_call_record[
            "spelling_inventory_successor"]["current_inventory_summary"],
        "current_inventory_summary": two_wrapper_record.get(
            "spelling_inventory_successor", {}).get("previous_inventory_summary"),
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
                                        *take_call_fixtures]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "Take(Call) spelling inventory successor drifted")
    previous_take_call_sites = move_call_record["filename_site_successor"]["current_sites"]
    current_take_call_sites = two_wrapper_record.get(
        "filename_site_successor", {}).get("previous_sites")
    require(take_call_record["filename_site_successor"] == {
        "contract_version": "phase26_1e_call_take_wrapper_zero_filename_site_successor_v1",
        "previous_sites": previous_take_call_sites,
        "current_sites": current_take_call_sites,
        "line_deltas": [now["line"] - before["line"]
                        for before, now in zip(previous_take_call_sites,
                                               current_take_call_sites)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(previous_take_call_sites) == len(current_take_call_sites) == 3 and
            all(now["line"] >= before["line"] and
                {key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now in zip(previous_take_call_sites, current_take_call_sites)),
            "Take(Call) filename successor drifted")
    take_call_surface = take_call_record["phase23_text_surface_successor"]
    require(take_call_surface.get("contract_version") ==
            "phase26_1e_call_take_wrapper_zero_phase23_text_surface_successor_v1" and
            take_call_surface.get("partial_extra_or_substituted_surface") == "rejected" and
            take_call_surface.get("added_rows") == [] and
            sorted(take_call_changed) == sorted([
                "compiler/typechecker.gst", "scripts/phase22_opening.py",
                "scripts/phase26_call_return_zero_registration.py",
            ]), "Take(Call) text surface set drifted")
    old_move_call_rows = {row["path"]: row for row in move_call_surface["changed_rows"]}
    for row in take_call_surface["changed_rows"]:
        text = (ROOT / row["path"]).read_text(encoding="utf-8")
        predecessor = old_move_call_rows.get(row["path"])
        require(len(row["previous_digest"]) == 64 and
                (predecessor is None or
                 row["previous_digest"] == predecessor["current_digest"]) and
                row["current_digest"] ==
                (two_wrapper_changed[row["path"]]["previous_digest"]
                 if row["path"] in two_wrapper_changed else digest(row["path"])) and
                row["current_match_counts"] ==
                (two_wrapper_changed[row["path"]]["previous_match_counts"]
                 if row["path"] in two_wrapper_changed else {
                     name: len(pattern.findall(text))
                     for name, pattern in SURFACE_PATTERNS.items()}),
                f"Take(Call) text surface drifted: {row['path']}")
    require("phase26_call_take_wrapper_zero_${case_name}_source.gst" in guard and
            "return_mayzero_callee_first" in guard and
            "nested_take" in guard and "move_take" in guard and
            ("take) line=4; boundary=argument" in guard or
             "take|nested_move) line=4; boundary=argument" in guard) and
            "check_one_take_call_boundary(ctx);" in
            (ROOT / POSITIVE).read_text(encoding="utf-8") and
            "[RawNullSafeBoundary]" in guard and
            "test ! -e \"$marker\"" in guard,
            "Take(Call) native evidence weakened")

    pairs = ("move_take", "take_move", "move_move", "take_take")
    two_wrapper_negatives = [
        f"compiler/phase26_call_two_wrapper_zero_{pair}_{boundary}_{order}_source.gst"
        for pair in pairs for boundary in ("argument", "return")
        for order in ("caller_first", "callee_first")
    ] + ["compiler/phase26_call_two_wrapper_zero_mayzero_source.gst"]
    two_wrapper_controls = [
        f"compiler/phase26_call_two_wrapper_zero_{name}_source.gst"
        for name in ("nonzero", "unsafe_target", "prior_error",
                     "type_mismatch", "depth3")
    ]
    two_wrapper_static = {
        "contract_version": "phase26_1e_call_two_wrapper_zero_v1",
        "status": "bounded_two_Move_Take_wrappers_raw_pointer_safe_boundary_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_two_Move_Take_wrapper_boundary_subset",
        "operator_ownership_decision": "2026-10-01_bounded_two_Move_Take_wrappers_boundary",
        "value_states": ["Unknown", "Zero", "Nonzero", "MayZero"],
        "candidate_shape": "exactly_two_syntactic_Move_Take_wrappers_around_concrete_direct_nullary_raw_pointer_Call_at_type_matched_safe_argument_or_return_boundary",
        "summary_order": "after_all_function_bodies_before_native_planner",
        "wrapper_pairs": ["Move_Take", "Take_Move", "Move_Move", "Take_Take"],
        "wrapper_depth": 2,
        "excluded_shapes": ["depth_three", "wrapped_or_indirect_callee",
                            "generic_call", "local_candidate_seeding"],
        "promoted_predecessor_controls": [
            "compiler/phase26_call_move_wrapper_zero_nested_move_source.gst",
            "compiler/phase26_call_take_wrapper_zero_move_take_source.gst",
            "compiler/phase26_call_take_wrapper_zero_nested_take_source.gst",
        ],
        "positive_fixture": POSITIVE,
        "negative_fixtures": two_wrapper_negatives,
        "control_fixtures": two_wrapper_controls,
        "safe_boundaries": ["declared_nonextern_raw_pointer_argument",
                            "declared_nonextern_raw_pointer_return"],
        "negative_states": ["Zero", "MayZero"],
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved_without_general_nullability_claim",
        "unsafe_callees": "preserved", "take_move_semantics_changed": False,
        "diagnostic": "[RawNullSafeBoundary]",
        "failure_stage": "before_driver_discovery", "native_fallback": False,
        "physical_abi_changed": False, "mir_changed": False,
        "runtime_symbol_surface_changed": False,
        "operator_semantics_changed": False,
        "general_nullability": "open_separate_obligation", "phase26_1_closed": False,
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in two_wrapper_static.items():
        require(two_wrapper_record.get(key) == value,
                f"depth-two wrapper successor field drifted: {key}")
    require(set(two_wrapper_record) == set(two_wrapper_static) | {
        "phase22_invocation_successor", "production_audit_successor",
        "spelling_inventory_successor", "filename_site_successor",
        "phase23_text_surface_successor",
    } and all((ROOT / path).is_file() for path in
              [*two_wrapper_negatives, *two_wrapper_controls]),
            "depth-two wrapper successor fields or fixtures drifted")
    require(two_wrapper_record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_call_two_wrapper_zero_phase22_invocation_successor_v1",
        "previous_total": 228, "current_total": 229,
        "added_rows": rows[10:11],
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows[10:11]) == 1, "depth-two invocation successor drifted")
    require(two_wrapper_record["production_audit_successor"] == {
        "contract_version": "phase26_1e_call_two_wrapper_zero_production_audit_successor_v1",
        "previous_repository_invocation_count": 228,
        "current_repository_invocation_count": 229,
        "added_invocation_path": SCRIPT, "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "depth-two production audit successor drifted")
    require(two_wrapper_record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_call_two_wrapper_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": take_call_record[
            "spelling_inventory_successor"]["current_inventory_summary"],
        "current_inventory_summary": wrapper_chain_record.get(
            "spelling_inventory_successor", {}).get("previous_inventory_summary"),
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
                                        *two_wrapper_negatives,
                                        *two_wrapper_controls]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "depth-two spelling inventory successor drifted")
    prior_sites = take_call_record["filename_site_successor"]["current_sites"]
    live_sites = wrapper_chain_record.get(
        "filename_site_successor", {}).get("previous_sites")
    require(two_wrapper_record["filename_site_successor"] == {
        "contract_version": "phase26_1e_call_two_wrapper_zero_filename_site_successor_v1",
        "previous_sites": prior_sites,
        "current_sites": live_sites,
        "line_deltas": [now["line"] - before["line"]
                        for before, now in zip(prior_sites, live_sites)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(prior_sites) == len(live_sites) == 3 and
            all({key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now in zip(prior_sites, live_sites)),
            "depth-two filename successor drifted")
    surface = two_wrapper_record["phase23_text_surface_successor"]
    require(surface.get("contract_version") ==
            "phase26_1e_call_two_wrapper_zero_phase23_text_surface_successor_v1" and
            surface.get("partial_extra_or_substituted_surface") == "rejected" and
            surface.get("added_rows") == [] and
            sorted(two_wrapper_changed) == sorted([
                "compiler/typechecker.gst", "scripts/phase22_opening.py",
                "scripts/phase26_call_return_zero_registration.py",
            ]), "depth-two text surface set drifted")
    old_rows = {row["path"]: row for row in take_call_surface["changed_rows"]}
    for row in surface["changed_rows"]:
        text = (ROOT / row["path"]).read_text(encoding="utf-8")
        next_row = wrapper_chain_changed.get(row["path"])
        require(row["previous_digest"] == old_rows[row["path"]]["current_digest"] and
                row["current_digest"] ==
                (next_row["previous_digest"] if next_row else digest(row["path"])) and
                row["previous_match_counts"] == old_rows[row["path"]]["current_match_counts"] and
                row["current_match_counts"] ==
                (next_row["previous_match_counts"] if next_row else {
                    name: len(pattern.findall(text))
                    for name, pattern in SURFACE_PATTERNS.items()}),
                f"depth-two text surface drifted: {row['path']}")
    require("phase26_call_two_wrapper_zero_${case_name}_source.gst" in guard and
            "move_take take_move move_move take_take" in guard and
            "mayzero nonzero unsafe_target prior_error type_mismatch depth3" in guard and
            "[RawNullSafeBoundary]" in guard and
            "test ! -e \"$marker\"" in guard,
            "depth-two native evidence weakened")

    triple_negatives = [
        f"compiler/phase26_call_wrapper_chain_zero_{a}_{b}_{c}_{boundary}_{order}_source.gst"
        for a in ("move", "take") for b in ("move", "take")
        for c in ("move", "take") for boundary in ("argument", "return")
        for order in ("caller_first", "callee_first")]
    wrapper_negatives = triple_negatives + [
        f"compiler/phase26_call_wrapper_chain_zero_{name}_source.gst"
        for name in ("depth4_zero", "mayzero_argument", "mayzero_return")]
    wrapper_controls = [f"compiler/phase26_call_wrapper_chain_zero_{name}_source.gst"
                        for name in ("nonzero", "unknown", "unsafe_target",
                                     "prior_error", "type_mismatch")]
    wrapper_static = {
        "contract_version": "phase26_1e_call_wrapper_chain_zero_v1",
        "status": "checked_Move_Take_wrapper_chain_raw_pointer_safe_boundary_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_checked_Move_Take_wrapper_chain_boundary_subset",
        "operator_ownership_decision": "2026-10-01_checked_Move_Take_wrapper_chain_boundary",
        "value_states": ["Unknown", "Zero", "Nonzero", "MayZero"],
        "candidate_shape": "syntactic_Move_Take_chain_around_concrete_direct_nullary_raw_pointer_Call_at_type_matched_safe_argument_or_return_boundary",
        "summary_order": "after_all_function_bodies_before_native_planner",
        "wrapper_chain": "peel_checked_Move_Take_syntax_only_in_safe_boundary_helper",
        "tested_depths": [1, 2, 3, 4],
        "excluded_shapes": ["wrapped_or_indirect_callee", "generic_call",
                            "local_candidate_seeding"],
        "promoted_predecessor_control":
            "compiler/phase26_call_two_wrapper_zero_depth3_source.gst",
        "positive_fixture": POSITIVE,
        "negative_fixtures": wrapper_negatives,
        "control_fixtures": wrapper_controls,
        "safe_boundaries": ["declared_nonextern_raw_pointer_argument",
                            "declared_nonextern_raw_pointer_return"],
        "negative_states": ["Zero", "MayZero"],
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved_without_general_nullability_claim",
        "unsafe_callees": "preserved", "take_move_semantics_changed": False,
        "diagnostic": "[RawNullSafeBoundary]",
        "failure_stage": "before_driver_discovery", "native_fallback": False,
        "physical_abi_changed": False, "mir_changed": False,
        "runtime_symbol_surface_changed": False,
        "operator_semantics_changed": False,
        "general_nullability": "open_separate_obligation", "phase26_1_closed": False,
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in wrapper_static.items():
        require(wrapper_chain_record.get(key) == value,
                f"wrapper-chain successor field drifted: {key}")
    require(set(wrapper_chain_record) == set(wrapper_static) | {
        "phase22_invocation_successor", "production_audit_successor",
        "spelling_inventory_successor", "filename_site_successor",
        "phase23_text_surface_successor",
    } and all((ROOT / path).is_file() for path in
              [*wrapper_negatives, *wrapper_controls]),
            "wrapper-chain successor fields or fixtures drifted")
    require(wrapper_chain_record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_call_wrapper_chain_zero_phase22_invocation_successor_v1",
        "previous_total": 229, "current_total": 230,
        "added_rows": rows[11:12],
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows[11:12]) == 1, "wrapper-chain invocation successor drifted")
    require(wrapper_chain_record["production_audit_successor"] == {
        "contract_version": "phase26_1e_call_wrapper_chain_zero_production_audit_successor_v1",
        "previous_repository_invocation_count": 229,
        "current_repository_invocation_count": 230,
        "added_invocation_path": SCRIPT, "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "wrapper-chain production audit successor drifted")
    require(wrapper_chain_record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_call_wrapper_chain_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": two_wrapper_record[
            "spelling_inventory_successor"]["current_inventory_summary"],
        "current_inventory_summary": as_cast_record.get(
            "spelling_inventory_successor", {}).get(
            "previous_inventory_summary", manifest_summary(source_sites())),
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
                                        *wrapper_negatives, *wrapper_controls]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "wrapper-chain spelling inventory successor drifted")
    prior_sites = two_wrapper_record["filename_site_successor"]["current_sites"]
    live_sites = filename_sites()
    pre_cast_sites = as_cast_record.get("filename_site_successor", {}).get(
        "previous_sites", live_sites)
    require(wrapper_chain_record["filename_site_successor"] == {
        "contract_version": "phase26_1e_call_wrapper_chain_zero_filename_site_successor_v1",
        "previous_sites": prior_sites, "current_sites": pre_cast_sites,
        "line_deltas": [now["line"] - before["line"]
                        for before, now in zip(prior_sites, pre_cast_sites)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(prior_sites) == len(live_sites) == 3 and
            all({key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now in zip(prior_sites, pre_cast_sites)),
            "wrapper-chain filename successor drifted")
    surface = wrapper_chain_record["phase23_text_surface_successor"]
    require(surface.get("contract_version") ==
            "phase26_1e_call_wrapper_chain_zero_phase23_text_surface_successor_v1" and
            surface.get("partial_extra_or_substituted_surface") == "rejected" and
            surface.get("added_rows") == [] and
            sorted(wrapper_chain_changed) == sorted([
                "compiler/typechecker.gst", "scripts/phase22_opening.py",
                "scripts/phase26_call_return_zero_registration.py",
            ]), "wrapper-chain text surface set drifted")
    old_rows = {row["path"]: row for row in two_wrapper_record[
        "phase23_text_surface_successor"]["changed_rows"]}
    for row in surface["changed_rows"]:
        text = (ROOT / row["path"]).read_text(encoding="utf-8")
        next_row = as_cast_changed.get(row["path"])
        require(row["previous_digest"] == old_rows[row["path"]]["current_digest"] and
                row["current_digest"] ==
                (next_row["previous_digest"] if next_row else digest(row["path"])) and
                row["previous_match_counts"] == old_rows[row["path"]]["current_match_counts"] and
                row["current_match_counts"] ==
                (next_row["previous_match_counts"] if next_row else {
                    name: len(pattern.findall(text))
                    for name, pattern in SURFACE_PATTERNS.items()}),
                f"wrapper-chain text surface drifted: {row['path']}")
    require("phase26_call_wrapper_chain_zero_${case_name}_source.gst" in guard and
            "for outer in move take" in guard and
            "for middle in move take" in guard and
            "for inner in move take" in guard and
            "depth4_zero mayzero_argument mayzero_return" in guard and
            "test ! -e \"$marker\"" in guard and
            "check_wrapper_chain_boundary(ctx);" in
            (ROOT / POSITIVE).read_text(encoding="utf-8"),
            "wrapper-chain native evidence weakened")

    cast_negative_names = (
        "argument_caller_first", "argument_callee_first", "other_pointer",
        "return_caller_first", "return_callee_first", "mayzero_argument",
        "mayzero_return",
    )
    cast_control_names = (
        "nonzero", "unknown", "unsafe_target", "type_mismatch", "nested",
        "move_cast", "cast_move", "take_cast", "cast_take",
    )
    cast_negatives = [f"compiler/phase26_call_cast_zero_{name}_source.gst"
                      for name in cast_negative_names]
    cast_controls = [f"compiler/phase26_call_cast_zero_{name}_source.gst"
                     for name in cast_control_names]
    cast_static = {
        "contract_version": "phase26_1e_call_as_cast_zero_v1",
        "status": "one_checked_RawPointer_AsCast_safe_boundary_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_one_RawPointer_AsCast_call_boundary_subset",
        "operator_ownership_decision": "2026-10-01_one_RawPointer_AsCast_call_boundary",
        "value_states": ["Unknown", "Zero", "Nonzero", "MayZero"],
        "candidate_shape": "one_checked_RawPointer_to_RawPointer_AsCast_around_concrete_direct_nullary_Call_at_type_matched_safe_argument_or_return_boundary",
        "summary_order": "after_all_function_bodies_before_native_planner",
        "metadata_proof": "resolved_RawPointer_operand_and_target_or_no_summary",
        "excluded_shapes": ["nested_cast", "Move_or_Take_combined_with_cast",
                            "scalar_to_pointer_cast", "indirect_or_generic_call",
                            "local_alias_or_branch", "local_candidate_seeding"],
        "positive_fixture": POSITIVE,
        "positive_output": "SUCCESS: checked direct-return zero summaries, one RawPointer AsCast, and excluded wrappers verified\n",
        "negative_fixtures": cast_negatives,
        "control_fixtures": cast_controls,
        "safe_boundaries": ["declared_nonextern_raw_pointer_argument",
                            "declared_nonextern_raw_pointer_return"],
        "negative_states": ["Zero", "MayZero"],
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved_without_general_nullability_claim",
        "unsafe_callees": "preserved", "take_move_semantics_changed": False,
        "diagnostic": "[RawNullSafeBoundary]",
        "failure_stage": "before_driver_discovery", "native_fallback": False,
        "physical_abi_changed": False, "mir_changed": False,
        "runtime_symbol_surface_changed": False,
        "operator_semantics_changed": False,
        "general_nullability": "open_separate_obligation", "phase26_1_closed": False,
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in cast_static.items():
        require(as_cast_record.get(key) == value,
                f"one RawPointer AsCast successor field drifted: {key}")
    require(set(as_cast_record) == set(cast_static) | {
        "phase22_invocation_successor", "production_audit_successor",
        "spelling_inventory_successor", "filename_site_successor",
        "phase23_text_surface_successor",
    } and all((ROOT / path).is_file() for path in
              [*cast_negatives, *cast_controls]),
            "one RawPointer AsCast successor fields or fixtures drifted")
    require(as_cast_record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_call_as_cast_zero_phase22_invocation_successor_v1",
        "previous_total": 230, "current_total": 231,
        "added_rows": rows[12:13],
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows) == 19,
            "one RawPointer AsCast invocation successor drifted")
    require(as_cast_record["production_audit_successor"] == {
        "contract_version": "phase26_1e_call_as_cast_zero_production_audit_successor_v1",
        "previous_repository_invocation_count": 230,
        "current_repository_invocation_count": 231,
        "added_invocation_path": SCRIPT, "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "one RawPointer AsCast production audit successor drifted")
    require(as_cast_record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_call_as_cast_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": wrapper_chain_record[
            "spelling_inventory_successor"]["current_inventory_summary"],
        "current_inventory_summary": as_cast_chain_record.get(
            "spelling_inventory_successor", {}).get(
            "previous_inventory_summary", manifest_summary(source_sites())),
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
                                        *cast_negatives, *cast_controls]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "one RawPointer AsCast spelling inventory successor drifted")
    prior_sites = wrapper_chain_record["filename_site_successor"]["current_sites"]
    pre_chain_sites = as_cast_chain_record.get("filename_site_successor", {}).get(
        "previous_sites", live_sites)
    require(as_cast_record["filename_site_successor"] == {
        "contract_version": "phase26_1e_call_as_cast_zero_filename_site_successor_v1",
        "previous_sites": prior_sites, "current_sites": pre_chain_sites,
        "line_deltas": [now["line"] - before["line"]
                        for before, now in zip(prior_sites, pre_chain_sites)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(prior_sites) == len(live_sites) == 3 and
            all({key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now in zip(prior_sites, live_sites)),
            "one RawPointer AsCast filename successor drifted")
    cast_surface = as_cast_record["phase23_text_surface_successor"]
    require(cast_surface.get("contract_version") ==
            "phase26_1e_call_as_cast_zero_phase23_text_surface_successor_v1" and
            cast_surface.get("partial_extra_or_substituted_surface") == "rejected" and
            cast_surface.get("added_rows") == [] and
            sorted(as_cast_changed) == ["compiler/typechecker.gst",
                                        "scripts/phase22_opening.py",
                                        "scripts/phase26_call_return_zero_registration.py"],
            "one RawPointer AsCast text surface set drifted")
    old_rows = {row["path"]: row for row in wrapper_chain_record[
        "phase23_text_surface_successor"]["changed_rows"]}
    for row in cast_surface["changed_rows"]:
        text = (ROOT / row["path"]).read_text(encoding="utf-8")
        require(row["previous_digest"] == old_rows[row["path"]]["current_digest"] and
                row["current_digest"] ==
                (as_cast_chain_changed[row["path"]]["previous_digest"]
                 if row["path"] in as_cast_chain_changed else
                 mixed_changed[row["path"]]["previous_digest"]
                 if row["path"] in mixed_changed else digest(row["path"])) and
                row["previous_match_counts"] == old_rows[row["path"]]["current_match_counts"] and
                row["current_match_counts"] ==
                (as_cast_chain_changed[row["path"]]["previous_match_counts"]
                 if row["path"] in as_cast_chain_changed else
                 mixed_changed[row["path"]]["previous_match_counts"]
                 if row["path"] in mixed_changed else {
                    name: len(pattern.findall(text))
                    for name, pattern in SURFACE_PATTERNS.items()}),
                f"one RawPointer AsCast text surface drifted: {row['path']}")
    positive = (ROOT / POSITIVE).read_text(encoding="utf-8")
    compiler = (ROOT / "compiler/typechecker.gst").read_text(encoding="utf-8")
    require("phase26_call_cast_zero_${case_name}_source.gst" in guard and
            "argument_caller_first argument_callee_first other_pointer" in guard and
            "return_caller_first return_callee_first mayzero_argument mayzero_return" in guard and
            "test ! -e \"$marker\"" in guard and
            "check_pointer_cast_chain_boundary(\"make_zero() as *int\"" in positive and
            "check_pointer_cast_chain_boundary(\"make_zero() as *byte\"" in positive and
            "phase26_zero_resolved_expression_tag(cast_expr.AsCast.left" in compiler and
            "phase26_zero_direct_nullary_callee(env, cast_expr_idx" in compiler,
            "one RawPointer AsCast native evidence weakened")

    cast_chain_negative_names = (
        "argument_caller_first", "argument_callee_first", "return_caller_first",
        "return_callee_first", "mayzero_argument", "depth3_argument",
        "depth3_mayzero_return",
    )
    cast_chain_control_names = (
        "nonzero", "unknown", "unsafe_target", "type_mismatch",
        "scalar_inner", "move_cast", "cast_move", "take_cast", "cast_take",
    )
    cast_chain_negatives = [f"compiler/phase26_call_cast_chain_zero_{name}_source.gst"
                            for name in cast_chain_negative_names]
    cast_chain_controls = [f"compiler/phase26_call_cast_chain_zero_{name}_source.gst"
                           for name in cast_chain_control_names]
    cast_chain_static = {
        "contract_version": "phase26_1e_call_as_cast_chain_zero_v1",
        "status": "checked_RawPointer_AsCast_chain_safe_boundary_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_RawPointer_AsCast_chain_boundary_subset",
        "operator_ownership_decision": "2026-10-01_checked_RawPointer_AsCast_chain_boundary",
        "value_states": ["Unknown", "Zero", "Nonzero", "MayZero"],
        "candidate_shape": "syntactic_AsCast_chain_each_resolved_RawPointer_operand_and_target_around_concrete_direct_nullary_Call_at_type_matched_safe_argument_or_return_boundary",
        "summary_order": "after_all_function_bodies_before_native_planner",
        "metadata_proof": "every_cast_resolved_RawPointer_operand_and_target_or_no_summary",
        "excluded_shapes": ["Move_or_Take_combined_with_cast", "scalar_to_pointer_cast",
                            "indirect_or_generic_call", "local_alias_or_branch",
                            "local_candidate_seeding"],
        "positive_fixture": POSITIVE,
        "positive_output": "SUCCESS: checked direct-return zero summaries, RawPointer AsCast chains, and excluded wrappers verified\n",
        "negative_fixtures": [*cast_chain_negatives, cast_controls[4]],
        "control_fixtures": cast_chain_controls,
        "reclassified_fixture": {
            "path": cast_controls[4],
            "previous": "accepted_then_native_deferral",
            "current": "RawNullSafeBoundary_before_driver",
        },
        "safe_boundaries": ["declared_nonextern_raw_pointer_argument",
                            "declared_nonextern_raw_pointer_return"],
        "negative_states": ["Zero", "MayZero"],
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved_without_general_nullability_claim",
        "unsafe_callees": "preserved", "take_move_semantics_changed": False,
        "diagnostic": "[RawNullSafeBoundary]",
        "failure_stage": "before_driver_discovery", "native_fallback": False,
        "physical_abi_changed": False, "mir_changed": False,
        "runtime_symbol_surface_changed": False,
        "operator_semantics_changed": False,
        "general_nullability": "open_separate_obligation", "phase26_1_closed": False,
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in cast_chain_static.items():
        require(as_cast_chain_record.get(key) == value,
                f"RawPointer AsCast-chain successor field drifted: {key}")
    require(set(as_cast_chain_record) == set(cast_chain_static) | {
        "spelling_inventory_successor", "filename_site_successor",
        "phase23_text_surface_successor",
    } and all((ROOT / path).is_file() for path in
              [*cast_chain_negatives, *cast_chain_controls]) and
            cast_controls[4] in as_cast_record["control_fixtures"],
            "RawPointer AsCast-chain successor fields or fixtures drifted")
    require(as_cast_chain_record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_call_as_cast_chain_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": as_cast_record[
            "spelling_inventory_successor"]["current_inventory_summary"],
        "current_inventory_summary": mixed_record.get(
            "spelling_inventory_successor", {}).get("previous_inventory_summary",
                                                    manifest_summary(source_sites())),
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
                                        *cast_chain_negatives, *cast_chain_controls]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "RawPointer AsCast-chain spelling inventory successor drifted")
    prior_sites = as_cast_record["filename_site_successor"]["current_sites"]
    require(as_cast_chain_record["filename_site_successor"] == {
        "contract_version": "phase26_1e_call_as_cast_chain_zero_filename_site_successor_v1",
        "previous_sites": prior_sites, "current_sites": mixed_record.get(
            "filename_site_successor", {}).get("previous_sites", live_sites),
        "line_deltas": [now["line"] - before["line"]
                        for before, now in zip(prior_sites, as_cast_chain_record[
                            "filename_site_successor"]["current_sites"])],
        "partial_extra_or_substituted_site": "rejected",
    } and len(prior_sites) == len(live_sites) == 3 and
            all({key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now in zip(prior_sites, as_cast_chain_record[
                    "filename_site_successor"]["current_sites"])),
            "RawPointer AsCast-chain filename successor drifted")
    cast_chain_surface = as_cast_chain_record["phase23_text_surface_successor"]
    require(cast_chain_surface.get("contract_version") ==
            "phase26_1e_call_as_cast_chain_zero_phase23_text_surface_successor_v1" and
            cast_chain_surface.get("partial_extra_or_substituted_surface") == "rejected" and
            cast_chain_surface.get("added_rows") == [] and
            sorted(as_cast_chain_changed) == sorted([
                "compiler/typechecker.gst",
                "scripts/phase26_call_return_zero_registration.py",
            ]), "RawPointer AsCast-chain text surface set drifted")
    for row in cast_chain_surface["changed_rows"]:
        path = row["path"]
        text = (ROOT / path).read_text(encoding="utf-8")
        successor = mixed_changed.get(path)
        require(row["current_digest"] ==
                (successor["previous_digest"] if successor else digest(path)) and
                row["current_match_counts"] ==
                (successor["previous_match_counts"] if successor else {
                    name: len(pattern.findall(text))
                    for name, pattern in SURFACE_PATTERNS.items()}) and
                len(row["previous_digest"]) == 64,
                f"RawPointer AsCast-chain text surface drifted: {path}")
    require("phase26_call_cast_chain_zero_${case_name#chain_}_source.gst" in guard and
            "chain_argument_caller_first chain_argument_callee_first" in guard and
            "chain_depth3_argument chain_depth3_mayzero_return" in guard and
            "test ! -e \"$marker\"" in guard and
            "check_pointer_cast_chain_boundary(\"(make_zero() as *int) as *int\"" in positive and
            "check_pointer_cast_chain_boundary(\"((make_zero() as *int) as *byte) as *int\"" in positive and
            "while cast_expr_idx != empty[Index[ast.Expression[ctx], ctx]]" in compiler,
            "RawPointer AsCast-chain native evidence weakened")

    mixed_negatives = [
        f"compiler/phase26_call_mixed_cast_zero_{shape}_{state}_{boundary}_{order}_source.gst"
        for shape in ("move_cast", "cast_move", "take_cast", "cast_take")
        for state in ("zero", "mayzero")
        for boundary in ("argument", "return")
        for order in ("caller_first", "callee_first")
    ]
    mixed_controls = [f"compiler/phase26_call_mixed_cast_zero_{name}_source.gst"
                      for name in ("nonzero", "unknown", "unsafe_target", "type_mismatch",
                                   "two_casts", "two_wrappers", "scalar_cast", "indirect")]
    mixed_static = {
        "contract_version": "phase26_1e_call_mixed_cast_zero_v1",
        "status": "one_checked_RawPointer_AsCast_plus_one_Move_or_Take_safe_boundary_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_mixed_cast_wrapper_boundary_subset",
        "operator_ownership_decision": "2026-10-01_bounded_mixed_cast_Move_Take_boundary",
        "value_states": ["Unknown", "Zero", "Nonzero", "MayZero"],
        "candidate_shape": "exactly_one_checked_RawPointer_AsCast_and_one_syntactic_Move_or_Take_in_either_order_around_concrete_direct_nullary_Call_at_type_matched_safe_argument_or_return",
        "summary_order": "after_all_function_bodies_before_native_planner",
        "metadata_proof": "cast_resolved_RawPointer_operand_and_target_or_no_summary",
        "excluded_shapes": ["two_mixed_casts_or_wrappers", "scalar_to_pointer_cast",
                            "indirect_or_generic_call", "local_alias_or_branch",
                            "local_candidate_seeding"],
        "positive_fixture": POSITIVE,
        "positive_output": "SUCCESS: checked direct-return zero summaries, RawPointer AsCast chains, bounded mixed Move/Take casts, and exclusions verified\n",
        "negative_fixtures": mixed_negatives,
        "control_fixtures": mixed_controls,
        "reclassified_fixtures": [f"compiler/phase26_call_cast_zero_{name}_source.gst"
                                  for name in ("move_cast", "cast_move", "take_cast", "cast_take")],
        "safe_boundaries": ["declared_nonextern_raw_pointer_argument",
                            "declared_nonextern_raw_pointer_return"],
        "negative_states": ["Zero", "MayZero"],
        "prior_error_precedence": "preserved", "unknown_and_nonzero": "preserved",
        "unsafe_callees": "preserved", "take_move_semantics_changed": False,
        "diagnostic": "[RawNullSafeBoundary]", "failure_stage": "before_driver_discovery",
        "native_fallback": False, "physical_abi_changed": False,
        "mir_changed": False, "runtime_symbol_surface_changed": False,
        "operator_semantics_changed": False,
        "general_nullability": "open_separate_obligation", "phase26_1_closed": False,
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in mixed_static.items():
        require(mixed_record.get(key) == value,
                f"mixed cast successor field drifted: {key}")
    require(set(mixed_record) == set(mixed_static) | {
        "phase22_invocation_successor", "production_audit_successor",
        "spelling_inventory_successor", "filename_site_successor",
        "phase23_text_surface_successor",
    } and all((ROOT / path).is_file() for path in
              [*mixed_negatives, *mixed_controls]) and
            all(path in as_cast_record["control_fixtures"]
                for path in mixed_static["reclassified_fixtures"]),
            "mixed cast successor fields or fixtures drifted")
    mixed_invocations = [row for row in scan_invocations() if row["path"] == SCRIPT]
    require(mixed_record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_call_mixed_cast_zero_phase22_invocation_successor_v1",
        "previous_total": 231, "current_total": 233,
        "added_rows": mixed_invocations[13:15],
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(mixed_invocations) == 19,
            "mixed cast invocation successor drifted")
    require(mixed_record["production_audit_successor"] == {
        "contract_version": "phase26_1e_call_mixed_cast_zero_production_audit_successor_v1",
        "previous_repository_invocation_count": 231,
        "current_repository_invocation_count": 233,
        "added_invocation_path": SCRIPT, "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "mixed cast production audit successor drifted")
    require(mixed_record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_call_mixed_cast_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": as_cast_chain_record[
            "spelling_inventory_successor"]["current_inventory_summary"],
        "current_inventory_summary": mixed_chain_record.get(
            "spelling_inventory_successor", {}).get("previous_inventory_summary",
                                                     manifest_summary(source_sites())),
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
                                        *mixed_negatives, *mixed_controls]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "mixed cast spelling inventory successor drifted")
    prior_sites = as_cast_chain_record["filename_site_successor"]["current_sites"]
    require(mixed_record["filename_site_successor"] == {
        "contract_version": "phase26_1e_call_mixed_cast_zero_filename_site_successor_v1",
        "previous_sites": prior_sites, "current_sites": mixed_chain_record.get(
            "filename_site_successor", {}).get("previous_sites", live_sites),
        "line_deltas": [now["line"] - before["line"]
                        for before, now in zip(prior_sites, mixed_record[
                            "filename_site_successor"]["current_sites"])],
        "partial_extra_or_substituted_site": "rejected",
    } and len(prior_sites) == len(live_sites) == 3 and
            all({key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now in zip(prior_sites, mixed_record[
                    "filename_site_successor"]["current_sites"])),
            "mixed cast filename successor drifted")
    mixed_surface = mixed_record["phase23_text_surface_successor"]
    require(mixed_surface.get("contract_version") ==
            "phase26_1e_call_mixed_cast_zero_phase23_text_surface_successor_v1" and
            mixed_surface.get("partial_extra_or_substituted_surface") == "rejected" and
            mixed_surface.get("added_rows") == [] and
            sorted(mixed_changed) == sorted([
                "compiler/typechecker.gst",
                "scripts/phase22_opening.py",
                "scripts/phase26_call_return_zero_registration.py",
            ]), "mixed cast text surface set drifted")
    for row in mixed_surface["changed_rows"]:
        path = row["path"]
        text = (ROOT / path).read_text(encoding="utf-8")
        require((row["previous_digest"] == as_cast_chain_changed[path]["current_digest"]
                 if path in as_cast_chain_changed else len(row["previous_digest"]) == 64) and
                row["current_digest"] ==
                (mixed_chain_changed[path]["previous_digest"]
                 if path in mixed_chain_changed else digest(path)) and
                row["current_match_counts"] ==
                (mixed_chain_changed[path]["previous_match_counts"]
                 if path in mixed_chain_changed else {
                    name: len(pattern.findall(text))
                    for name, pattern in SURFACE_PATTERNS.items()}) and
                len(row["previous_digest"]) == 64,
                f"mixed cast text surface drifted: {path}")
    require("for shape in move_cast cast_move take_cast cast_take; do" in guard and
            "for state in zero mayzero; do" in guard and
            "for boundary_kind in argument return; do" in guard and
            "for order in caller_first callee_first; do" in guard and
            "phase26_call_mixed_cast_zero_${case_name}_source.gst" in guard and
            "test ! -e \"$marker\"" in guard and
            "check_pointer_cast_chain_boundary(\"move (make_zero() as *int)\"" in positive and
            "check_pointer_cast_chain_boundary(\"(take make_zero()) as *int\"" in positive and
            "phase26_zero_resolved_expression_tag(mixed_expr.AsCast.left" in compiler,
            "mixed cast native or poison evidence weakened")

    chain_negatives = [
        f"compiler/phase26_call_mixed_chain_{state}_{boundary}_{order}_source.gst"
        for state in ("zero", "mayzero")
        for boundary in ("argument", "return")
        for order in ("caller_first", "callee_first")
    ]
    chain_controls = [f"compiler/phase26_call_mixed_chain_{name}_source.gst"
                      for name in ("nonzero", "unknown", "unsafe_target",
                                   "type_mismatch", "scalar_cast")]
    chain_static = {
        "contract_version": "phase26_1e_call_mixed_chain_zero_v1",
        "status": "checked_mixed_RawPointer_cast_and_Move_Take_chain_safe_boundary_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_mixed_cast_wrapper_chain_boundary_subset",
        "operator_ownership_decision": "2026-10-01_bounded_mixed_checked_cast_Move_Take_chain",
        "value_states": ["Unknown", "Zero", "Nonzero", "MayZero"],
        "candidate_shape": "finite_post_typecheck_syntactic_chain_with_at_least_one_checked_RawPointer_AsCast_and_one_Move_or_Take_around_concrete_direct_nullary_Call_at_safe_raw_pointer_boundary",
        "metadata_proof": "every_cast_resolved_RawPointer_operand_and_target_or_no_summary",
        "summary_order": "after_all_function_bodies_before_native_planner",
        "excluded_shapes": ["scalar_to_pointer_cast", "missing_resolved_metadata",
                            "indirect_or_generic_call", "local_alias_or_branch"],
        "positive_fixture": POSITIVE,
        "positive_output": "SUCCESS: checked direct-return zero summaries, RawPointer AsCast chains, mixed Move/Take cast chains, and exclusions verified\n",
        "negative_fixtures": chain_negatives,
        "control_fixtures": chain_controls,
        "reclassified_fixtures": mixed_controls[4:6] +
            [f"compiler/phase26_call_cast_chain_zero_{name}_source.gst"
             for name in ("move_cast", "cast_move",
                          "take_cast", "cast_take")],
        "safe_boundaries": ["declared_nonextern_raw_pointer_argument",
                            "declared_nonextern_raw_pointer_return"],
        "negative_states": ["Zero", "MayZero"],
        "prior_error_precedence": "preserved", "unknown_and_nonzero": "preserved",
        "unsafe_callees": "preserved", "take_move_semantics_changed": False,
        "diagnostic": "[RawNullSafeBoundary]", "failure_stage": "before_driver_discovery",
        "native_fallback": False, "physical_abi_changed": False,
        "mir_changed": False, "runtime_symbol_surface_changed": False,
        "operator_semantics_changed": False,
        "general_nullability": "open_separate_obligation", "phase26_1_closed": False,
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in chain_static.items():
        require(mixed_chain_record.get(key) == value,
                f"mixed-chain successor field drifted: {key}")
    require(set(mixed_chain_record) == set(chain_static) | {
        "phase22_invocation_successor", "production_audit_successor",
        "spelling_inventory_successor", "filename_site_successor",
        "phase23_text_surface_successor",
    } and all((ROOT / path).is_file() for path in
              [*chain_negatives, *chain_controls]),
            "mixed-chain successor fields or fixtures drifted")
    require(mixed_chain_record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_call_mixed_chain_zero_phase22_invocation_successor_v1",
        "previous_total": 233, "current_total": 236,
        "added_rows": mixed_invocations[15:18],
        "partial_extra_or_substituted_invocation": "rejected",
    }, "mixed-chain invocation successor drifted")
    require(mixed_chain_record["production_audit_successor"] == {
        "contract_version": "phase26_1e_call_mixed_chain_zero_production_audit_successor_v1",
        "previous_repository_invocation_count": 233,
        "current_repository_invocation_count": 236,
        "added_invocation_path": SCRIPT, "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "mixed-chain production audit successor drifted")
    require(mixed_chain_record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_call_mixed_chain_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": mixed_record[
            "spelling_inventory_successor"]["current_inventory_summary"],
        "current_inventory_summary": local_cast_record[
            "spelling_inventory_successor"]["previous_inventory_summary"],
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
                                        *chain_negatives, *chain_controls]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "mixed-chain spelling inventory successor drifted")
    previous_chain_sites = mixed_record["filename_site_successor"]["current_sites"]
    require(mixed_chain_record["filename_site_successor"] == {
        "contract_version": "phase26_1e_call_mixed_chain_zero_filename_site_successor_v1",
        "previous_sites": previous_chain_sites, "current_sites": local_cast_record[
            "filename_site_successor"]["previous_sites"],
        "line_deltas": [now["line"] - before["line"]
                        for before, now in zip(previous_chain_sites, local_cast_record[
                            "filename_site_successor"]["previous_sites"])],
        "partial_extra_or_substituted_site": "rejected",
    } and len(previous_chain_sites) == len(local_cast_record[
        "filename_site_successor"]["previous_sites"]) == 3 and
            all({key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now in zip(previous_chain_sites, local_cast_record[
                    "filename_site_successor"]["previous_sites"])),
            "mixed-chain filename successor drifted")
    chain_surface = mixed_chain_record["phase23_text_surface_successor"]
    require(chain_surface.get("contract_version") ==
            "phase26_1e_call_mixed_chain_zero_phase23_text_surface_successor_v1" and
            chain_surface.get("partial_extra_or_substituted_surface") == "rejected" and
            chain_surface.get("added_rows") == [] and
            sorted(mixed_chain_changed) == sorted(mixed_changed),
            "mixed-chain text surface set drifted")
    for row in chain_surface["changed_rows"]:
        path = row["path"]
        text = (ROOT / path).read_text(encoding="utf-8")
        local_cast_changed = {entry["path"]: entry for entry in local_cast_record[
            "phase23_text_surface_successor"]["changed_rows"]}
        expected_digest = (local_cast_changed[path]["previous_digest"]
                           if path in local_cast_changed else digest(path))
        expected_counts = (local_cast_changed[path]["previous_match_counts"]
                           if path in local_cast_changed else {
                               name: len(pattern.findall(text))
                               for name, pattern in SURFACE_PATTERNS.items()})
        require(row["previous_digest"] == mixed_changed[path]["current_digest"] and
                row["current_digest"] == expected_digest and
                row["previous_match_counts"] == mixed_changed[path][
                    "current_match_counts"] and
                row["current_match_counts"] == expected_counts,
                f"mixed-chain text surface drifted: {path}")
    require("phase26_call_mixed_chain_${case_name}_source.gst" in guard and
            "for state in zero mayzero; do" in guard and
            "for boundary_kind in argument return; do" in guard and
            "for order in caller_first callee_first; do" in guard and
            "test ! -e \"$marker\"" in guard and
            "while mixed_expr_idx != empty[Index[ast.Expression[ctx], ctx]]" in compiler and
            "phase26_zero_resolved_expression_tag(mixed_expr.AsCast.left" in compiler,
            "mixed-chain native or poison evidence weakened")

    local_cast_negatives = [f"compiler/phase26_call_local_{name}_source.gst"
                            for name in ("cast_zero_caller_first",
                                         "cast_zero_callee_first", "cast_mayzero")]
    local_cast_controls = [f"compiler/phase26_call_local_{name}_source.gst"
                           for name in ("cast_nonzero", "cast_unknown",
                                        "cast_zero_unsafe_target",
                                        "cast_zero_intervening", "cast_zero_alias",
                                        "cast_zero_nested", "cast_zero_move",
                                        "cast_zero_scalar_mismatch")]
    local_cast_static = {
        "contract_version": "phase26_1e_call_local_cast_zero_v1",
        "status": "one_checked_direct_local_RawPointer_cast_safe_argument_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_one_casted_direct_local_argument_subset",
        "operator_ownership_decision": "2026-10-02_bounded_direct_local_cast_argument",
        "value_states": ["Unknown", "Zero", "Nonzero", "MayZero"],
        "candidate_shape": "one_immediate_same_block_direct_local_concrete_nullary_call_result_one_checked_RawPointer_AsCast_argument",
        "summary_order": "after_all_function_bodies_before_native_planner",
        "metadata_proof": "post_typecheck_resolved_RawPointer_operand_and_target_or_no_summary",
        "excluded_shapes": ["alias_hops", "extra_statement", "nested_cast",
                            "Move_or_Take_wrapped_cast", "scalar_cast",
                            "indirect_or_generic_call", "safe_return"],
        "positive_fixture": POSITIVE,
        "positive_output": "SUCCESS: checked direct-return zero summaries, RawPointer AsCast chains, mixed Move/Take cast chains, and exclusions verified\n",
        "negative_fixtures": local_cast_negatives,
        "control_fixtures": local_cast_controls,
        "safe_boundaries": ["declared_nonextern_raw_pointer_argument"],
        "negative_states": ["Zero", "MayZero"],
        "prior_error_precedence": "preserved", "unknown_and_nonzero": "preserved",
        "unsafe_callees": "preserved", "take_move_semantics_changed": False,
        "diagnostic": "[RawNullSafeBoundary]", "failure_stage": "before_driver_discovery",
        "native_fallback": False, "physical_abi_changed": False,
        "mir_changed": False, "runtime_symbol_surface_changed": False,
        "operator_semantics_changed": False,
        "general_nullability": "open_separate_obligation", "phase26_1_closed": False,
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in local_cast_static.items():
        require(local_cast_record.get(key) == value,
                f"local-cast successor field drifted: {key}")
    require(set(local_cast_record) == set(local_cast_static) | {
        "phase22_invocation_successor", "production_audit_successor",
        "spelling_inventory_successor", "filename_site_successor",
        "phase23_text_surface_successor",
    } and all((ROOT / path).is_file() for path in
              [*local_cast_negatives, *local_cast_controls]),
            "local-cast successor fields or fixtures drifted")
    require(local_cast_record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_call_local_cast_zero_phase22_invocation_successor_v1",
        "previous_total": 236, "current_total": 237,
        "added_rows": mixed_invocations[18:19],
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(mixed_invocations[18:19]) == 1,
            "local-cast invocation successor drifted")
    require(local_cast_record["production_audit_successor"] == {
        "contract_version": "phase26_1e_call_local_cast_zero_production_audit_successor_v1",
        "previous_repository_invocation_count": 236,
        "current_repository_invocation_count": 237,
        "added_invocation_path": SCRIPT, "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "local-cast production audit successor drifted")
    require(local_cast_record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_call_local_cast_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": mixed_chain_record[
            "spelling_inventory_successor"]["current_inventory_summary"],
        "current_inventory_summary": local_cast_chain_record[
            "spelling_inventory_successor"]["previous_inventory_summary"],
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
                                        *local_cast_negatives, *local_cast_controls]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "local-cast spelling inventory successor drifted")
    previous_local_cast_sites = mixed_chain_record["filename_site_successor"]["current_sites"]
    require(local_cast_record["filename_site_successor"] == {
        "contract_version": "phase26_1e_call_local_cast_zero_filename_site_successor_v1",
        "previous_sites": previous_local_cast_sites,
        "current_sites": local_cast_chain_record[
            "filename_site_successor"]["previous_sites"],
        "line_deltas": [now["line"] - before["line"]
                        for before, now in zip(previous_local_cast_sites, local_cast_chain_record[
                            "filename_site_successor"]["previous_sites"])],
        "partial_extra_or_substituted_site": "rejected",
    } and len(previous_local_cast_sites) == len(local_cast_chain_record[
        "filename_site_successor"]["previous_sites"]) == 3 and
            all({key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now in zip(previous_local_cast_sites, local_cast_chain_record[
                    "filename_site_successor"]["previous_sites"])),
            "local-cast filename successor drifted")
    local_cast_surface = local_cast_record["phase23_text_surface_successor"]
    require(local_cast_surface.get("contract_version") ==
            "phase26_1e_call_local_cast_zero_phase23_text_surface_successor_v1" and
            local_cast_surface.get("partial_extra_or_substituted_surface") == "rejected" and
            local_cast_surface.get("added_rows") == [] and
            sorted(row["path"] for row in local_cast_surface["changed_rows"]) == sorted([
                "compiler/typechecker.gst", "scripts/phase22_opening.py",
                "scripts/phase26_call_return_zero_registration.py"]),
            "local-cast text surface set drifted")
    predecessor_surfaces = {row["path"]: row for row in chain_surface["changed_rows"]}
    for row in local_cast_surface["changed_rows"]:
        path = row["path"]
        text = (ROOT / path).read_text(encoding="utf-8")
        successor = local_cast_chain_changed.get(path)
        require(row["previous_digest"] == predecessor_surfaces[path]["current_digest"] and
                row["current_digest"] ==
                (successor["previous_digest"] if successor else digest(path)) and
                row["previous_match_counts"] == predecessor_surfaces[path]["current_match_counts"] and
                row["current_match_counts"] ==
                (successor["previous_match_counts"] if successor else {
                    name: len(pattern.findall(text))
                    for name, pattern in SURFACE_PATTERNS.items()}),
                f"local-cast text surface drifted: {path}")
    require("phase26_call_local_${case_name}_source.gst" in guard and
            "cast_zero_caller_first cast_zero_callee_first cast_mayzero" in guard and
            "cast_zero_alias cast_zero_nested cast_zero_move" in guard and
            "test ! -e \"$marker\"" in guard and
            "phase26_zero_local_call_argument_cast_is_raw" in compiler and
            "phase26_zero_resolved_expression_tag(cast_expr.AsCast.left" in compiler and
            "(*env).zero_local_call_alias_hops != 0" in compiler and
            "accept_raw(ptr as *int)" in (ROOT / POSITIVE).read_text(encoding="utf-8"),
            "local-cast native or poison evidence weakened")

    cast_chain_negatives = [f"compiler/phase26_call_local_{name}_source.gst"
                            for name in ("cast_zero_nested", "cast_chain_zero_callee_first",
                                         "cast_chain_mayzero", "cast_chain_zero_depth3")]
    cast_chain_controls = [f"compiler/phase26_call_local_{name}_source.gst"
                           for name in ("cast_chain_nonzero", "cast_chain_unknown",
                                        "cast_chain_zero_unsafe_target", "cast_chain_zero_alias",
                                        "cast_zero_move", "cast_zero_scalar_mismatch")]
    cast_chain_static = {
        "contract_version": "phase26_1e_call_local_cast_chain_zero_v1",
        "status": "checked_direct_local_RawPointer_cast_chain_safe_argument_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_checked_cast_chain_direct_local_argument_subset",
        "operator_ownership_decision": "2026-10-02_bounded_checked_local_cast_chain_argument",
        "value_states": ["Unknown", "Zero", "Nonzero", "MayZero"],
        "candidate_shape": "one_immediate_same_block_direct_local_concrete_nullary_call_result_finite_checked_RawPointer_AsCast_chain_argument",
        "metadata_proof": "post_typecheck_each_cast_resolved_RawPointer_operand_and_target_or_no_summary",
        "summary_order": "after_all_function_bodies_before_native_planner",
        "positive_fixture": POSITIVE,
        "positive_output": "SUCCESS: checked direct-return zero summaries, RawPointer AsCast chains, mixed Move/Take cast chains, and exclusions verified\n",
        "negative_fixtures": cast_chain_negatives,
        "control_fixtures": cast_chain_controls,
        "reclassified_fixtures": ["compiler/phase26_call_local_cast_zero_nested_source.gst"],
        "safe_boundaries": ["declared_nonextern_raw_pointer_argument"],
        "negative_states": ["Zero", "MayZero"],
        "prior_error_precedence": "preserved", "unknown_and_nonzero": "preserved",
        "unsafe_callees": "preserved", "take_move_semantics_changed": False,
        "diagnostic": "[RawNullSafeBoundary]", "failure_stage": "before_driver_discovery",
        "native_fallback": False, "physical_abi_changed": False,
        "mir_changed": False, "runtime_symbol_surface_changed": False,
        "operator_semantics_changed": False,
        "general_nullability": "open_separate_obligation", "phase26_1_closed": False,
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in cast_chain_static.items():
        require(local_cast_chain_record.get(key) == value,
                f"local-cast-chain successor field drifted: {key}")
    require(set(local_cast_chain_record) == set(cast_chain_static) | {
        "spelling_inventory_successor", "filename_site_successor",
        "phase23_text_surface_successor",
    } and all((ROOT / path).is_file() for path in
              [*cast_chain_negatives, *cast_chain_controls]),
            "local-cast-chain successor fields or fixtures drifted")
    require(local_cast_chain_record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_call_local_cast_chain_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": local_cast_record[
            "spelling_inventory_successor"]["current_inventory_summary"],
        "current_inventory_summary": local_take_cast_record[
            "spelling_inventory_successor"]["previous_inventory_summary"],
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
            *[f"compiler/phase26_call_local_cast_chain_{name}_source.gst" for name in (
                "zero_callee_first", "mayzero", "zero_depth3", "nonzero",
                "unknown", "zero_unsafe_target", "zero_alias")]]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "local-cast-chain spelling inventory successor drifted")
    previous_cast_chain_sites = local_cast_record["filename_site_successor"]["current_sites"]
    require(local_cast_chain_record["filename_site_successor"] == {
        "contract_version": "phase26_1e_call_local_cast_chain_zero_filename_site_successor_v1",
        "previous_sites": previous_cast_chain_sites,
        "current_sites": local_take_cast_record[
            "filename_site_successor"]["previous_sites"],
        "line_deltas": [now["line"] - before["line"]
                        for before, now in zip(previous_cast_chain_sites,
                            local_take_cast_record["filename_site_successor"]["previous_sites"])],
        "partial_extra_or_substituted_site": "rejected",
    } and len(previous_cast_chain_sites) == len(local_take_cast_record[
        "filename_site_successor"]["previous_sites"]) == 3 and
        all({key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now in zip(previous_cast_chain_sites,
                    local_take_cast_record["filename_site_successor"]["previous_sites"])),
            "local-cast-chain filename successor drifted")
    cast_chain_surface = local_cast_chain_record["phase23_text_surface_successor"]
    require(cast_chain_surface.get("contract_version") ==
            "phase26_1e_call_local_cast_chain_zero_phase23_text_surface_successor_v1" and
            cast_chain_surface.get("partial_extra_or_substituted_surface") == "rejected" and
            cast_chain_surface.get("added_rows") == [] and
            sorted(row["path"] for row in cast_chain_surface["changed_rows"]) == sorted([
                "compiler/typechecker.gst", "scripts/phase26_call_return_zero_registration.py"]),
            "local-cast-chain text surface set drifted")
    for row in cast_chain_surface["changed_rows"]:
        path = row["path"]
        text = (ROOT / path).read_text(encoding="utf-8")
        predecessor = local_cast_changed.get(path)
        require(predecessor is not None and
                row["previous_digest"] == predecessor["current_digest"] and
                row["previous_match_counts"] == predecessor["current_match_counts"] and
                row["current_digest"] == (local_take_cast_changed.get(path) or {
                    "previous_digest": digest(path)})["previous_digest"] and
                row["current_match_counts"] == (local_take_cast_changed.get(path) or {
                    "previous_match_counts": {
                        name: len(pattern.findall(text))
                        for name, pattern in SURFACE_PATTERNS.items()}})["previous_match_counts"],
                f"local-cast-chain text surface drifted: {path}")
    require("cast_chain_zero_callee_first cast_chain_mayzero cast_chain_zero_depth3" in guard and
            "cast_zero_nested" in guard and
            "test ! -e \"$marker\"" in guard and
            "while source_idx != empty[Index[ast.Expression[ctx], ctx]]" in compiler and
            "while cast_expr.tag == 9" in compiler and
            "phase26_zero_resolved_expression_tag(cast_expr.AsCast.left" in compiler and
            "(*env).zero_local_call_alias_hops != 0" in compiler,
            "local-cast-chain native or poison evidence weakened")

    take_cast_negative_names = (
        "cast_take_zero_caller_first", "cast_take_zero_callee_first",
        "take_cast_zero_caller_first", "take_cast_zero_callee_first",
        "cast_take_mayzero", "take_cast_mayzero")
    take_cast_control_names = (
        "cast_take_nonzero", "take_cast_nonzero", "take_cast_unknown",
        "take_cast_unsafe_target", "take_cast_alias", "take_cast_intervening",
        "take_cast_nested", "cast_take_nested", "take_cast_second_take",
        "take_cast_move", "take_cast_type_mismatch")
    take_cast_fixtures = [f"compiler/phase26_call_local_{name}_source.gst"
                          for name in (*take_cast_negative_names, *take_cast_control_names)]
    take_cast_static = {
        "contract_version": "phase26_1e_call_local_take_cast_zero_v1",
        "status": "checked_one_Take_one_RawPointer_cast_local_safe_argument_rejection_qualified",
        "owner": "cranelift",
        "increment": "26.1E_one_Take_one_checked_cast_direct_local_argument_subset",
        "operator_ownership_decision": "2026-10-02_bounded_one_Take_one_checked_local_cast_argument",
        "value_states": ["Unknown", "Zero", "Nonzero", "MayZero"],
        "candidate_shape": "one_immediate_same_block_concrete_nullary_call_result_one_local_one_Take_one_checked_RawPointer_AsCast_either_order_argument",
        "metadata_proof": "post_typecheck_resolved_RawPointer_operand_and_target_or_no_summary",
        "summary_order": "after_all_function_bodies_before_native_planner",
        "positive_fixture": POSITIVE,
        "positive_output": "SUCCESS: checked direct-return zero summaries, RawPointer AsCast chains, mixed Move/Take cast chains, and exclusions verified\n",
        "negative_fixtures": take_cast_fixtures[:len(take_cast_negative_names)],
        "control_fixtures": take_cast_fixtures[len(take_cast_negative_names):],
        "safe_boundaries": ["declared_nonextern_raw_pointer_argument"],
        "negative_states": ["Zero", "MayZero"],
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved",
        "unsafe_callees": "preserved",
        "take_move_semantics_changed": False,
        "diagnostic": "[RawNullSafeBoundary]",
        "failure_stage": "before_driver_discovery",
        "native_fallback": False,
        "physical_abi_changed": False,
        "mir_changed": False,
        "runtime_symbol_surface_changed": False,
        "operator_semantics_changed": False,
        "general_nullability": "open_separate_obligation",
        "phase26_1_closed": False,
        "owning_level2_guard": GUARD,
        "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in take_cast_static.items():
        require(local_take_cast_record.get(key) == value,
                f"local-Take-cast successor field drifted: {key}")
    require(set(local_take_cast_record) == set(take_cast_static) | {
        "spelling_inventory_successor", "filename_site_successor",
        "phase23_text_surface_successor",
    } and all((ROOT / path).is_file() for path in take_cast_fixtures),
            "local-Take-cast successor fields or fixtures drifted")
    require(local_take_cast_record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_call_local_take_cast_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": local_cast_chain_record[
            "spelling_inventory_successor"]["current_inventory_summary"],
        "current_inventory_summary": manifest_summary(source_sites()),
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
                                        *take_cast_fixtures]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "local-Take-cast spelling inventory successor drifted")
    previous_take_cast_sites = local_cast_chain_record["filename_site_successor"]["current_sites"]
    require(local_take_cast_record["filename_site_successor"] == {
        "contract_version": "phase26_1e_call_local_take_cast_zero_filename_site_successor_v1",
        "previous_sites": previous_take_cast_sites,
        "current_sites": live_sites,
        "line_deltas": [now["line"] - before["line"]
                        for before, now in zip(previous_take_cast_sites, live_sites)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(previous_take_cast_sites) == len(live_sites) == 3 and
            all({key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now in zip(previous_take_cast_sites, live_sites)),
            "local-Take-cast filename successor drifted")
    take_cast_surface = local_take_cast_record["phase23_text_surface_successor"]
    require(take_cast_surface.get("contract_version") ==
            "phase26_1e_call_local_take_cast_zero_phase23_text_surface_successor_v1" and
            take_cast_surface.get("partial_extra_or_substituted_surface") == "rejected" and
            take_cast_surface.get("added_rows") == [] and
            sorted(row["path"] for row in take_cast_surface["changed_rows"]) == sorted([
                "compiler/typechecker.gst", "scripts/phase26_call_return_zero_registration.py"]),
            "local-Take-cast text surface set drifted")
    previous_rows = {row["path"]: row for row in cast_chain_surface["changed_rows"]}
    for row in take_cast_surface["changed_rows"]:
        path = row["path"]
        text = (ROOT / path).read_text(encoding="utf-8")
        predecessor = previous_rows[path]
        require(row["previous_digest"] == predecessor["current_digest"] and
                row["previous_match_counts"] == predecessor["current_match_counts"] and
                row["current_digest"] == digest(path) and
                row["current_match_counts"] == {
                    name: len(pattern.findall(text))
                    for name, pattern in SURFACE_PATTERNS.items()},
                f"local-Take-cast text surface drifted: {path}")
    require("cast_take_zero_caller_first cast_take_zero_callee_first" in guard and
            "take_cast_zero_caller_first take_cast_zero_callee_first" in guard and
            "take_cast_mayzero" in guard and
            "take_cast_type_mismatch" in guard and
            "test ! -e \"$marker\"" in guard and
            "source.tag == 5" in compiler and
            "arg.tag == 5 && inner.tag == 9" in compiler and
            "phase26_zero_local_call_argument_cast_is_raw" in compiler,
            "local-Take-cast native or poison evidence weakened")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
