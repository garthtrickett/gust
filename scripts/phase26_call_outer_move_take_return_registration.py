#!/usr/bin/env python3
"""Pin the one-outer-Move, one-Take safe-return successor."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-call-return-zero-evidence"
KEY = "call_outer_move_take_return_zero_increment"
GUARD_PATH = "scripts/phase26_call_return_zero_evidence.sh"
PREVIOUS_GUARD_DIGEST = "4e6210934b6e58984ccb441b369c000173d1e78911df821649c0946e23076b9c"
EXISTING_RECLASSIFIED = (
    "compiler/phase26_call_local_return_take_wrapper_move_take_source.gst"
)
NEW_FIXTURES = [
    f"compiler/phase26_call_local_return_outer_move_take_{name}_source.gst"
    for name in (
        "alias_cast_mayzero", "cast_outside_take_mayzero", "zero", "nonzero",
        "unknown", "unsafe", "double_move", "wrong_type",
    )
]


def require(value: bool, message: str) -> None:
    if not value:
        raise SystemExit(f"{GUARD}: outer-Move successor {message}")


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def record(activation: dict) -> dict:
    return activation.get(KEY, {})


def before_outer_move_digest(activation: dict, path: str, live_digest: str, *,
                             new_projected: bool = False) -> str:
    if activation.get("call_two_take_return_zero_increment"):
        from phase26_call_two_take_return_registration import before_two_take_digest
        live_digest = before_two_take_digest(
            activation, path, live_digest, new_projected=new_projected)
    rows = record(activation).get("phase23_text_surface_successor", {}).get(
        "changed_rows", []
    )
    matches = [row for row in rows if row.get("path") == path]
    require(len(matches) <= 1, f"duplicate text path: {path}")
    if not matches:
        return live_digest
    row = matches[0]
    require(row.get("current_digest") == live_digest and
            len(row.get("previous_digest", "")) == 64,
            f"text digest drifted: {path}")
    return row["previous_digest"]


def before_outer_move_spelling(activation: dict, live: dict) -> dict:
    if activation.get("call_two_take_return_zero_increment"):
        from phase26_call_two_take_return_registration import before_two_take_spelling
        live = before_two_take_spelling(activation, live)
    successor = record(activation).get("spelling_inventory_successor", {})
    previous = activation["ffi_policy_vector_status_increment"][
        "spelling_inventory_successor"]["current_inventory_summary"]
    require(successor == {
        "contract_version": "phase26_1e_outer_move_take_spelling_successor_v1",
        "previous_inventory_summary": previous,
        "current_inventory_summary": live,
        "changed_source_paths": ["compiler/typechecker.gst", *NEW_FIXTURES],
        "partial_extra_or_substituted_inventory": "rejected",
    } and live["source_file_count"] ==
            previous["source_file_count"] + len(NEW_FIXTURES) and
            live["site_count"] == previous["site_count"] and
            live["semantic_site_count"] == previous["semantic_site_count"] and
            live["classification_counts"] == previous["classification_counts"] and
            live["unknown_site_count"] == 0,
            "spelling inventory drifted")
    return previous


def before_outer_move_filename(activation: dict, live: list[dict]) -> list[dict]:
    if activation.get("call_two_take_return_zero_increment"):
        from phase26_call_two_take_return_registration import before_two_take_filename
        live = before_two_take_filename(activation, live)
    successor = record(activation).get("filename_site_successor", {})
    previous = activation["ffi_policy_vector_status_increment"][
        "filename_site_successor"]["current_sites"]
    require(successor == {
        "contract_version": "phase26_1e_outer_move_take_filename_successor_v1",
        "previous_sites": previous,
        "current_sites": live,
        "line_deltas": [12, 12, 12],
        "partial_extra_or_substituted_site": "rejected",
    } and len(previous) == len(live) == 3 and
            all(now["line"] == before["line"] + 12 and
                {key: value for key, value in now.items() if key != "line"} ==
                {key: value for key, value in before.items() if key != "line"}
                for before, now in zip(previous, live)),
            "filename sites drifted")
    return previous


def before_outer_move_invocations(
        activation: dict, live: list[dict], *, projected: bool = False) -> list[dict]:
    if activation.get("call_two_take_return_zero_increment"):
        from phase26_call_two_take_return_registration import before_two_take_invocations
        live = before_two_take_invocations(activation, live, projected=projected)
    successor = record(activation).get("phase22_invocation_successor", {})
    previous = activation["call_take_alias_return_zero_evidence_increment"][
        "phase22_invocation_successor"]["added_rows"][0]
    current = successor.get("current_row", {})
    selected = [entry for entry in live if entry.get("path") == GUARD_PATH]
    require(successor == {
        "contract_version": "phase26_1e_outer_move_take_phase22_line_successor_v1",
        "previous_row": previous,
        "current_row": current,
        "unchanged_total": 20,
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(selected) == 20 and selected[-1] in (current, previous) and
            current.get("line") == previous["line"] + 1 and
            {key: value for key, value in current.items() if key != "line"} ==
            {key: value for key, value in previous.items() if key != "line"},
            "invocation line successor drifted")
    return [previous if entry == current else entry for entry in live]


def main() -> None:
    activation = json.loads((ROOT / "scripts/cranelift_feature_registry.json")
                            .read_text())["phase26_activation_audit"]
    if activation.get("call_two_take_return_zero_increment"):
        from phase26_call_two_take_return_registration import (
            before_two_take_digest, main as two_take_registration_main,
        )
        two_take_registration_main()
    row = record(activation)
    expected = {
        "contract_version": "phase26_1e_outer_move_take_return_zero_v1",
        "status": "bounded_outer_move_one_take_safe_return_rejection_qualified",
        "owner": "cranelift",
        "increment": "26.1E_outer_Move_one_Take_safe_return",
        "operator_ownership_decision": "2026-10-08_bounded_outer_Move_one_Take_safe_return",
        "candidate_shape": "immediate_same_block_concrete_nullary_raw_pointer_call_current_local_or_validated_alias_one_outer_Move_one_Take_optional_checked_raw_casts",
        "safe_boundary": "declared_nonextern_raw_pointer_return",
        "negative_states": ["Zero", "MayZero"],
        "negative_fixtures": [EXISTING_RECLASSIFIED, *NEW_FIXTURES[:3]],
        "control_fixtures": NEW_FIXTURES[3:],
        "reclassified_fixture": {
            "path": EXISTING_RECLASSIFIED,
            "previous": "accepted_then_native_deferral",
            "current": "RawNullSafeBoundary_before_driver",
        },
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved",
        "unsafe_functions": "preserved",
        "additional_Move_or_Take": "excluded",
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
        "phase22_invocation_successor",
    }
    require({key: row.get(key) for key in expected} == expected and
            set(row) == set(expected) | successors,
            "contract or field set drifted")
    require(all((ROOT / path).is_file() for path in
                [EXISTING_RECLASSIFIED, *NEW_FIXTURES]),
            "source fixture missing")
    guard_successor = row["guard_digest_successor"]
    current_guard_digest = digest(GUARD_PATH)
    if activation.get("call_outer_move_two_take_return_zero_increment"):
        current_guard_digest = activation[
            "call_outer_move_two_take_return_zero_increment"][
                "guard_digest_successor"]["previous_digest"]
    if activation.get("call_two_take_return_zero_increment"):
        successor = activation["call_two_take_return_zero_increment"][
            "guard_digest_successor"]
        require(successor.get("current_digest") == current_guard_digest,
                "two-Take guard successor drifted")
        current_guard_digest = successor["previous_digest"]
    require(guard_successor == {
        "path": GUARD_PATH,
        "previous_digest": PREVIOUS_GUARD_DIGEST,
        "current_digest": current_guard_digest,
        "partial_extra_or_substituted_guard": "rejected",
    },
            "focused guard digest drifted")
    guard = (ROOT / GUARD_PATH).read_text()
    compiler = (ROOT / "compiler/typechecker.gst").read_text()
    require(all(marker in guard for marker in (
                "wrapper_move_take|outer_move_alias_cast_mayzero",
                "outer_move_cast_outside_take_mayzero", "outer_move_zero",
                "outer_move_nonzero", "outer_move_unknown", "outer_move_unsafe",
                "outer_move_double_move", "outer_move_wrong_type",
                "GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER",
                "test ! -e \"$marker\"")) and
            ("outer_move == 1 && take_count != 1" in compiler or
             activation.get("call_outer_move_two_take_return_zero_increment") and
             "outer_move == 1 && take_count == 0" in compiler) and
            ("Matcher already proved one outer Move and one Take" in compiler or
             activation.get("call_outer_move_two_take_return_zero_increment") and
             "Matcher proved one outer Move and one or two Takes" in compiler or
             activation.get("call_outer_move_finite_take_return_zero_increment") and
             "Matcher proved one outer Move and a finite Take chain" in compiler or
             activation.get("call_outer_move_cast_prefix_return_zero_increment") and
             "preceded by checked raw-pointer casts, may enclose a finite Take chain" in compiler),
            "native or fail-closed evidence weakened")

    from phase24_semantic_spelling_inventory import source_sites, manifest_summary
    before_outer_move_spelling(activation, manifest_summary(source_sites()))
    from phase24_filename_behavior_characterization import source_sites as filename_sites
    before_outer_move_filename(activation, filename_sites())
    from phase22_opening import scan_invocations
    before_outer_move_invocations(activation, [entry for entry in
        scan_invocations() if entry["path"] == GUARD_PATH], projected=True)

    from phase23_mir_to_c_deprecation_opening import (
        SURFACE_PATTERNS, SELF_EXCLUSIONS, tracked_paths,
    )
    surface = row["phase23_text_surface_successor"]
    changed = surface.get("changed_rows", [])
    paths = [entry.get("path") for entry in changed]
    prior_surface = {
        entry["path"]: entry for entry in activation[
            "ffi_policy_vector_status_increment"][
                "phase23_text_surface_successor"]["changed_rows"]
    }
    added = surface.get("added_rows", [])
    added_path = "scripts/phase26_call_outer_move_take_return_registration.py"
    require(surface.get("contract_version") ==
            "phase26_1e_outer_move_take_phase23_text_successor_v1" and
            isinstance(added, list) and len(added) == 1 and
            added[0].get("path") == added_path and
            surface.get("partial_extra_or_substituted_surface") == "rejected" and
            paths == ["compiler/typechecker.gst",
                      "scripts/phase26_call_return_zero_registration.py"] and
            all(path in tracked_paths() and path not in SELF_EXCLUSIONS
                for path in paths),
            "text surface shape drifted")
    added_text = (ROOT / added_path).read_text()
    added_counts = {name: len(pattern.findall(added_text))
                    for name, pattern in SURFACE_PATTERNS.items()}
    two_take_rows = {entry["path"]: entry for entry in activation.get(
        "call_two_take_return_zero_increment", {}).get(
            "phase23_text_surface_successor", {}).get("changed_rows", [])}
    if added_path in two_take_rows:
        added_counts = two_take_rows[added_path]["previous_match_counts"]
    require(added[0] == {
        "path": added_path,
        "digest": before_two_take_digest(activation, added_path,
                                         digest(added_path)) if two_take_rows else digest(added_path),
        "match_counts": added_counts,
        "classification": "archive_candidate",
        "owner": "cranelift",
        "current_route": "tracked_MIR_to_C_or_generated_C_surface",
        "deprecation_action": "map_to_live_lane_or_archive_in_23_10_and_23_11",
        "removal_phase": "24",
        "falsifier": "active_evidence_surface_is_missing_or_changes_identity",
    } and any(added_counts.values()),
            "added text surface drifted")
    for entry in changed:
        path = entry["path"]
        text = (ROOT / path).read_text()
        counts = {name: len(pattern.findall(text))
                  for name, pattern in SURFACE_PATTERNS.items()}
        if path in two_take_rows:
            counts = two_take_rows[path]["previous_match_counts"]
        current_digest = digest(path)
        if two_take_rows:
            current_digest = before_two_take_digest(activation, path, current_digest)
        require(entry["current_digest"] == current_digest and
                entry["current_match_counts"] == counts and
                entry["previous_digest"] ==
                    prior_surface[path]["current_digest"] and
                entry["previous_match_counts"] ==
                    prior_surface[path]["current_match_counts"] and
                entry["current_match_counts"] == counts,
                f"text surface drifted: {path}")
    print(f"{GUARD}: outer-Move successor registration ok")


if __name__ == "__main__":
    main()
