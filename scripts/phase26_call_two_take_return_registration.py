#!/usr/bin/env python3
"""Pin the bounded two-Take safe-return successor and reverse only its evidence."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-call-return-zero-evidence"
GUARD_PATH = "scripts/phase26_call_return_zero_evidence.sh"
KEY = "call_two_take_return_zero_increment"
EXISTING_RECLASSIFIED = "compiler/phase26_call_local_return_take_wrapper_nested_take_source.gst"
NEW_FIXTURES = [
    f"compiler/phase26_call_local_return_two_take_{name}_source.gst"
    for name in (
        "zero", "outer_cast_mayzero", "inner_cast_mayzero",
        "interleaved_cast_mayzero", "nonzero", "unknown", "unsafe",
        "gap", "overwrite", "wrong_type", "callee_first",
        "third_take", "move",
    )
]


def require(value: bool, message: str) -> None:
    if not value:
        raise SystemExit(f"{GUARD}: two-Take successor {message}")


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def record(activation: dict) -> dict:
    return activation.get(KEY, {})


def before_two_take_digest(activation: dict, path: str, live_digest: str, *,
                           new_projected: bool = False) -> str:
    if activation.get("call_outer_move_two_take_return_zero_increment"):
        if new_projected:
            rows = activation["call_outer_move_two_take_return_zero_increment"][
                "phase23_text_surface_successor"]["changed_rows"]
            selected = [row for row in rows if row["path"] == path]
            require(len(selected) <= 1 and
                    (not selected or live_digest == selected[0]["previous_digest"]),
                    f"projected text digest drifted: {path}")
        else:
            from phase26_call_outer_move_two_take_return_registration import before_new_digest
            live_digest = before_new_digest(activation, path, live_digest)
    rows = record(activation).get("phase23_text_surface_successor", {}).get(
        "changed_rows", [])
    matches = [row for row in rows if row.get("path") == path]
    require(len(matches) <= 1, f"duplicate text path: {path}")
    if not matches:
        return live_digest
    row = matches[0]
    require(row.get("current_digest") == live_digest and
            len(row.get("previous_digest", "")) == 64,
            f"text digest drifted: {path}")
    return row["previous_digest"]


def before_two_take_spelling(activation: dict, live: dict) -> dict:
    if activation.get("call_outer_move_two_take_return_zero_increment"):
        from phase26_call_outer_move_two_take_return_registration import before_new_spelling
        live = before_new_spelling(activation, live)
    successor = record(activation).get("spelling_inventory_successor", {})
    previous = activation["call_outer_move_take_return_zero_increment"][
        "spelling_inventory_successor"]["current_inventory_summary"]
    require(successor == {
        "contract_version": "phase26_1e_two_take_spelling_successor_v1",
        "previous_inventory_summary": previous,
        "current_inventory_summary": live,
        "changed_source_paths": ["compiler/typechecker.gst",
                                 "compiler/phase26_call_return_zero_test_entry.gst",
                                 *NEW_FIXTURES],
        "partial_extra_or_substituted_inventory": "rejected",
    } and live["source_file_count"] == previous["source_file_count"] + len(NEW_FIXTURES) and
            live["site_count"] == previous["site_count"] and
            live["semantic_site_count"] == previous["semantic_site_count"] and
            live["classification_counts"] == previous["classification_counts"] and
            live["unknown_site_count"] == 0,
            "spelling inventory drifted")
    return previous


def before_two_take_filename(activation: dict, live: list[dict]) -> list[dict]:
    if activation.get("call_outer_move_two_take_return_zero_increment"):
        from phase26_call_outer_move_two_take_return_registration import before_new_filename
        live = before_new_filename(activation, live)
    successor = record(activation).get("filename_site_successor", {})
    previous = activation["call_outer_move_take_return_zero_increment"][
        "filename_site_successor"]["current_sites"]
    require(successor == {
        "contract_version": "phase26_1e_two_take_filename_successor_v1",
        "previous_sites": previous,
        "current_sites": live,
        "line_deltas": [now["line"] - before["line"]
                        for before, now in zip(previous, live)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(previous) == len(live) == 3 and
            all({key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now in zip(previous, live)),
            "filename sites drifted")
    return previous


def before_two_take_invocations(
        activation: dict, live: list[dict], *, projected: bool = False) -> list[dict]:
    if activation.get("call_outer_move_two_take_return_zero_increment"):
        from phase26_call_outer_move_two_take_return_registration import before_new_invocations
        live = before_new_invocations(activation, live, projected=projected)
    successor = record(activation).get("phase22_invocation_successor", {})
    outer_successor = activation["call_outer_move_take_return_zero_increment"][
        "phase22_invocation_successor"]
    previous = outer_successor["current_row"]
    frozen = outer_successor["previous_row"]
    current = successor.get("current_row", {})
    selected = [row for row in live if row.get("path") == GUARD_PATH]
    require(successor == {
        "contract_version": "phase26_1e_two_take_phase22_line_successor_v1",
        "previous_row": previous,
        "current_row": current,
        "unchanged_total": 20,
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(selected) == 20 and
            (selected[-1] in (current, previous, frozen) if projected else
             selected[-1] == current) and
            {key: value for key, value in current.items() if key != "line"} ==
            {key: value for key, value in previous.items() if key != "line"},
            "invocation line successor drifted")
    return [previous if row == current else row for row in live]


def main() -> None:
    activation = json.loads((ROOT / "scripts/cranelift_feature_registry.json")
                            .read_text())["phase26_activation_audit"]
    if activation.get("call_outer_move_two_take_return_zero_increment"):
        from phase26_call_outer_move_two_take_return_registration import main as new_main
        new_main()
    row = record(activation)
    expected = {
        "contract_version": "phase26_1e_two_take_return_zero_v1",
        "status": "bounded_two_take_safe_return_rejection_qualified",
        "owner": "cranelift",
        "increment": "26.1E_two_Take_safe_return",
        "operator_ownership_decision": "2026-10-08_coordinator_assigned_under_activated_phase26",
        "candidate_shape": "immediate_same_block_concrete_nullary_raw_pointer_call_current_local_or_validated_alias_exactly_two_Takes_optional_checked_raw_casts_no_Move",
        "safe_boundary": "declared_nonextern_raw_pointer_return",
        "negative_states": ["Zero", "MayZero"],
        "negative_fixtures": [EXISTING_RECLASSIFIED, *NEW_FIXTURES[:4]],
        "control_fixtures": NEW_FIXTURES[4:],
        "reclassified_fixture": {
            "path": EXISTING_RECLASSIFIED,
            "previous": "accepted_then_native_deferral",
            "current": "RawNullSafeBoundary_before_driver",
        },
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved",
        "unsafe_functions": "preserved",
        "third_Take_or_any_Move": "excluded_from_new_form",
        "take_move_resource_semantics_changed": False,
        "diagnostic": "[RawNullSafeBoundary]",
        "failure_stage": "before_driver_discovery",
        "native_fallback": False,
        "mir_changed": False,
        "physical_abi_changed": False,
        "runtime_symbol_surface_changed": False,
        "general_nullability": "open_separate_obligation",
        "phase26_1_closed": False,
        "owning_level2_guard": GUARD,
    }
    successors = {
        "guard_digest_successor", "phase23_text_surface_successor",
        "spelling_inventory_successor", "filename_site_successor",
        "phase22_invocation_successor", "positive_fixture_successor",
    }
    require({key: row.get(key) for key in expected} == expected and
            set(row) == set(expected) | successors,
            "contract or field set drifted")
    require(all((ROOT / path).is_file() for path in
                [EXISTING_RECLASSIFIED, *NEW_FIXTURES]),
            "source fixture missing")
    previous_guard = activation["call_outer_move_take_return_zero_increment"][
        "guard_digest_successor"]["current_digest"]
    current_guard = digest(GUARD_PATH)
    new_successor = activation.get("call_outer_move_two_take_return_zero_increment")
    if new_successor:
        current_guard = new_successor["guard_digest_successor"]["previous_digest"]
    require(row["guard_digest_successor"] == {
        "path": GUARD_PATH,
        "previous_digest": previous_guard,
        "current_digest": current_guard,
        "partial_extra_or_substituted_guard": "rejected",
    }, "focused guard digest drifted")
    current_positive = digest("compiler/phase26_call_return_zero_test_entry.gst")
    if new_successor:
        current_positive = new_successor["positive_fixture_successor"]["previous_digest"]
    require(row["positive_fixture_successor"] == {
        "path": "compiler/phase26_call_return_zero_test_entry.gst",
        "previous_digest": "6b92d337f7017c9afec72819a77e3ba8e5e8381e38d8ad1379e6fff6e2a3194a",
        "current_digest": current_positive,
        "partial_extra_or_substituted_fixture": "rejected",
    }, "positive matcher evidence drifted")
    guard = (ROOT / GUARD_PATH).read_text()
    compiler = (ROOT / "compiler/typechecker.gst").read_text()
    require(all(marker in guard for marker in (
                "wrapper_nested_take|two_take_zero", "two_take_outer_cast_mayzero",
                "two_take_inner_cast_mayzero", "two_take_interleaved_cast_mayzero",
                "two_take_third_take", "two_take_move",
                "GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER",
                "test ! -e \"$marker\"")) and
            ((((compiler.count("if outer_move == 1 || inner_move == 1 { return 0; }") == 2 and compiler.count("if take_count == 0 { outer_move = 1; }") == 2) if activation.get("call_outer_move_cast_prefix_return_zero_increment") else "if outer_move == 1 || inner_move == 1 || take_count == 0" in compiler))
             if activation.get("call_finite_outer_move_finite_inner_take_return_zero_increment") else
             ("take_count > 2 || (outer_move == 1 && take_count > 1)" in compiler or
              activation.get("call_outer_move_two_take_return_zero_increment") and
              "take_count > 2" in compiler)),
            "native or fail-closed evidence weakened")
    from phase24_semantic_spelling_inventory import source_sites, manifest_summary
    before_two_take_spelling(activation, manifest_summary(source_sites()))
    from phase24_filename_behavior_characterization import source_sites as filename_sites
    before_two_take_filename(activation, filename_sites())
    from phase22_opening import scan_invocations
    normalized = [entry for entry in scan_invocations()
                  if entry["path"] == GUARD_PATH]
    require(len(normalized) == 20 and normalized[-1] == activation[
        "call_outer_move_take_return_zero_increment"][
            "phase22_invocation_successor"]["previous_row"],
            "Phase 22 projected invocation identity drifted")
    from phase23_mir_to_c_deprecation_opening import (
        SURFACE_PATTERNS, SELF_EXCLUSIONS, tracked_paths,
    )
    surface = row["phase23_text_surface_successor"]
    changed = surface.get("changed_rows", [])
    added = surface.get("added_rows", [])
    require(surface.get("contract_version") ==
            "phase26_1e_two_take_phase23_text_successor_v1" and
            surface.get("partial_extra_or_substituted_surface") == "rejected" and
            isinstance(changed, list) and isinstance(added, list) and
            len({entry.get("path") for entry in changed}) == len(changed) and
            [entry.get("path") for entry in changed] == [
                "compiler/typechecker.gst",
                "scripts/phase26_call_return_zero_registration.py",
                "scripts/phase26_call_outer_move_take_return_registration.py",
            ] and
            len(added) == 1 and
            added[0].get("path") ==
            "scripts/phase26_call_two_take_return_registration.py" and
            all(entry.get("path") in tracked_paths() and
                entry.get("path") not in SELF_EXCLUSIONS for entry in changed),
            "text surface shape drifted")
    prior_rows = {entry["path"]: entry for entry in activation[
        "call_outer_move_take_return_zero_increment"][
            "phase23_text_surface_successor"]["changed_rows"]}
    prior_added = activation["call_outer_move_take_return_zero_increment"][
        "phase23_text_surface_successor"]["added_rows"][0]
    require(prior_added["path"] ==
            "scripts/phase26_call_outer_move_take_return_registration.py",
            "frozen added-text predecessor drifted")
    for entry in changed:
        path = entry["path"]
        text = (ROOT / path).read_text()
        counts = {name: len(pattern.findall(text))
                  for name, pattern in SURFACE_PATTERNS.items()}
        current_digest = digest(path)
        if new_successor:
            successor_rows = {e["path"]: e for e in new_successor[
                "phase23_text_surface_successor"]["changed_rows"]}
            successor = successor_rows[path]
            current_digest = successor["previous_digest"]
            counts = successor["previous_match_counts"]
        prior = prior_rows.get(path)
        require(prior is not None or path == prior_added["path"],
                f"unproven text predecessor: {path}")
        require(entry == {
            "path": path,
            "previous_digest": (prior["current_digest"] if prior else
                                prior_added["digest"]),
            "current_digest": current_digest,
            "previous_match_counts": (prior["current_match_counts"] if prior else
                                      prior_added["match_counts"]),
            "current_match_counts": counts,
        }, f"text surface drifted: {path}")
    added_path = added[0]["path"]
    text = (ROOT / added_path).read_text()
    counts = {name: len(pattern.findall(text))
              for name, pattern in SURFACE_PATTERNS.items()}
    added_digest = digest(added_path)
    if new_successor:
        successor_rows = {e["path"]: e for e in new_successor[
            "phase23_text_surface_successor"]["changed_rows"]}
        successor = successor_rows[added_path]
        added_digest = successor["previous_digest"]
        counts = successor["previous_match_counts"]
    require(added[0] == {
        "path": added_path, "digest": added_digest,
        "match_counts": counts, "classification": "archive_candidate",
        "owner": "cranelift",
        "current_route": "tracked_MIR_to_C_or_generated_C_surface",
        "deprecation_action": "map_to_live_lane_or_archive_in_23_10_and_23_11",
        "removal_phase": "24",
        "falsifier": "active_evidence_surface_is_missing_or_changes_identity",
    } and any(counts.values()), "added text surface drifted")
    print(f"{GUARD}: two-Take successor registration ok")


if __name__ == "__main__":
    main()
