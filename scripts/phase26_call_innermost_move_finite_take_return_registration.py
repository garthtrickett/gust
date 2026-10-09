#!/usr/bin/env python3
"""Pin the exact innermost-Move/finite-Take successor before frozen predecessors."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KEY = "call_innermost_move_finite_take_return_zero_increment"
OLD = "call_innermost_move_three_take_return_zero_increment"
GUARD = "guard-cranelift-phase26-call-return-zero-evidence"
GUARD_PATH = "scripts/phase26_call_return_zero_evidence.sh"
POSITIVE = "compiler/phase26_call_return_zero_test_entry.gst"
RECLASSIFIED = "compiler/phase26_call_local_return_innermost_move_three_take_fourth_take_source.gst"
NAMES = (
    "zero", "fifth_take", "outer_cast_mayzero", "between_outer_middle_cast_mayzero",
    "between_middle_inner_cast_mayzero", "before_move_cast_mayzero",
    "inside_move_cast_mayzero", "interleaved_cast_mayzero", "nonzero",
    "unknown", "unsafe", "gap", "overwrite", "wrong_type",
    "callee_first", "later_take", "move_between", "outer_and_inner_move",
    "double_inner_move", "scalar_cast", "cast_without_alias", "prior_move",
)
NEW_FIXTURES = [
    f"compiler/phase26_call_local_return_innermost_move_finite_take_{name}_source.gst"
    for name in NAMES
]
TEXT_PATHS = [
    "compiler/typechecker.gst",
    "scripts/phase26_call_return_zero_registration.py",
    "scripts/phase26_call_innermost_move_three_take_return_registration.py",
    "scripts/phase26_call_outer_move_finite_take_return_registration.py",
    "scripts/phase26_call_innermost_move_two_take_return_registration.py",
    "scripts/phase26_call_finite_take_return_registration.py",
    "scripts/phase26_call_outer_move_two_take_return_registration.py",
    "scripts/phase26_call_inner_move_two_take_return_registration.py",
]
CR15_PATH = "scripts/phase24_cr15_stdlib_guard_transition.py"


def require(ok: bool, message: str) -> None:
    if not ok:
        raise SystemExit(f"{GUARD}: innermost-Move finite-Take successor {message}")


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def record(activation: dict) -> dict:
    return activation.get(KEY, {})


def old_text(activation: dict, path: str) -> tuple[str | None, dict | None]:
    old_surface = activation[OLD]["phase23_text_surface_successor"]
    old_rows = {row["path"]: row for row in old_surface["changed_rows"]}
    old_added = old_surface["added_rows"][0]
    if path in old_rows:
        return old_rows[path]["current_digest"], old_rows[path]["current_match_counts"]
    if path == old_added["path"]:
        return old_added["digest"], old_added["match_counts"]
    return None, None


def before_new_digest(activation: dict, path: str, live_digest: str) -> str:
    rows = record(activation).get("phase23_text_surface_successor", {}).get("changed_rows", [])
    matches = [row for row in rows if row.get("path") == path]
    require(len(matches) <= 1, f"duplicate text path: {path}")
    if not matches:
        return live_digest
    row = matches[0]
    previous, _ = old_text(activation, path)
    require(previous is not None and row.get("previous_digest") == previous and
            row.get("current_digest") == live_digest, f"text digest drifted: {path}")
    return previous


def before_new_counts(activation: dict, path: str, live_counts: dict[str, int]) -> dict[str, int]:
    rows = record(activation).get("phase23_text_surface_successor", {}).get("changed_rows", [])
    matches = [row for row in rows if row.get("path") == path]
    require(len(matches) <= 1, f"duplicate text path: {path}")
    if not matches:
        return live_counts
    row = matches[0]
    _, previous = old_text(activation, path)
    require(previous is not None and row.get("previous_match_counts") == previous and
            row.get("current_match_counts") == live_counts, f"text count drifted: {path}")
    return previous


def before_new_spelling(activation: dict, live: dict) -> dict:
    successor = record(activation).get("spelling_inventory_successor", {})
    previous = activation[OLD]["spelling_inventory_successor"]["current_inventory_summary"]
    require(successor == {
        "contract_version": "phase26_1e_innermost_move_finite_take_spelling_successor_v1",
        "previous_inventory_summary": previous,
        "current_inventory_summary": live,
        "changed_source_paths": ["compiler/typechecker.gst", POSITIVE, *NEW_FIXTURES],
        "partial_extra_or_substituted_inventory": "rejected",
    } and live["source_file_count"] == previous["source_file_count"] + len(NEW_FIXTURES) and
            live["site_count"] == previous["site_count"] and
            live["semantic_site_count"] == previous["semantic_site_count"] and
            live["classification_counts"] == previous["classification_counts"] and
            live["unknown_site_count"] == 0, "spelling inventory drifted")
    return previous


def before_new_filename(activation: dict, live: list[dict]) -> list[dict]:
    successor = record(activation).get("filename_site_successor", {})
    previous = activation[OLD]["filename_site_successor"]["current_sites"]
    require(successor == {
        "contract_version": "phase26_1e_innermost_move_finite_take_filename_successor_v1",
        "previous_sites": previous,
        "current_sites": live,
        "line_deltas": [now["line"] - before["line"] for before, now in zip(previous, live)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(previous) == len(live) == 3 and
            all({k: v for k, v in now.items() if k != "line"} ==
                {k: v for k, v in before.items() if k != "line"}
                for before, now in zip(previous, live)), "filename sites drifted")
    return previous


def before_new_invocations(activation: dict, live: list[dict], *,
                           projected: bool = False) -> list[dict]:
    successor = record(activation).get("phase22_invocation_successor", {})
    previous = activation[OLD]["phase22_invocation_successor"]["added_row"]
    frozen = activation["call_outer_move_take_return_zero_increment"][
        "phase22_invocation_successor"]["previous_row"]
    added = successor.get("added_row", {})
    selected = [row for row in live if row.get("path") == GUARD_PATH]
    require(successor == {
        "contract_version": "phase26_1e_innermost_move_finite_take_phase22_line_successor_v1",
        "previous_row": previous, "unchanged_total": 23,
        "added_row": added, "current_total": 24,
        "partial_extra_or_substituted_invocation": "rejected",
    } and
            ((len(selected) in (20, 21, 22, 23) and selected[-1] in
              (previous, activation[OLD]["phase22_invocation_successor"]["previous_row"], frozen))
             if projected else
             (len(selected) == 24 and selected[-2] == previous and selected[-1] == added)) and
            added.get("line", 0) > previous.get("line", 0) and
            {k: v for k, v in added.items() if k != "line"} ==
            {k: v for k, v in previous.items() if k != "line"},
            "invocation line successor drifted")
    return [row for row in live if row != added]


def main() -> None:
    activation = json.loads((ROOT / "scripts/cranelift_feature_registry.json")
                            .read_text())["phase26_activation_audit"]
    row = record(activation)
    expected = {
        "contract_version": "phase26_1e_innermost_move_finite_take_return_zero_v1",
        "status": "bounded_innermost_move_finite_take_safe_return_rejection_qualified",
        "owner": "cranelift",
        "increment": "26.1E_innermost_Move_finite_Take_safe_return",
        "operator_ownership_decision": "2026-10-09_coordinator_assigned_under_activated_phase26",
        "candidate_shape": "immediate_same_block_concrete_nullary_raw_pointer_call_current_local_or_validated_alias_four_or_more_Takes_then_one_innermost_Move_optional_checked_raw_casts",
        "safe_boundary": "declared_nonextern_raw_pointer_return",
        "negative_states": ["Zero", "MayZero"],
        "negative_fixtures": [RECLASSIFIED, *NEW_FIXTURES[:8]],
        "control_fixtures": NEW_FIXTURES[8:],
        "reclassified_fixture": {"path": RECLASSIFIED,
                                 "previous": "accepted_then_native_deferral",
                                 "current": "RawNullSafeBoundary_before_driver"},
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved",
        "unsafe_functions": "preserved",
        "later_Take_or_misplaced_or_second_Move": "excluded_from_new_form",
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
    successors = {"guard_digest_successor", "positive_fixture_successor",
                  "cr15_relay_digest_successor", "spelling_inventory_successor",
                  "filename_site_successor", "phase22_invocation_successor",
                  "phase23_text_surface_successor"}
    require({k: row.get(k) for k in expected} == expected and
            set(row) == set(expected) | successors, "contract or field set drifted")
    require(all((ROOT / p).is_file() for p in [RECLASSIFIED, *NEW_FIXTURES]),
            "source fixture missing")
    for field, path, previous in (
        ("guard_digest_successor", GUARD_PATH, activation[OLD]["guard_digest_successor"]["current_digest"]),
        ("positive_fixture_successor", POSITIVE, activation[OLD]["positive_fixture_successor"]["current_digest"]),
        ("cr15_relay_digest_successor", CR15_PATH, activation[OLD]["cr15_relay_digest_successor"]["current_digest"]),
    ):
        require(row[field] == {
            "path": path, "previous_digest": previous,
            "current_digest": digest(path),
            "partial_extra_or_substituted_" +
            ("guard" if field.startswith("guard") else
             "fixture" if field.startswith("positive") else "relay"): "rejected",
        }, f"{field} drifted")
    guard = (ROOT / GUARD_PATH).read_text()
    compiler = (ROOT / "compiler/typechecker.gst").read_text()
    require(all(marker in guard for marker in (
        "fourth_take move_between outer_and_inner_move",
        "for case_name in " + " ".join(NAMES) + "; do",
        "phase26_call_local_return_innermost_move_finite_take_${case_name}_source.gst",
        "GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER", 'test ! -e "$marker"')) and
        compiler.count("take_count > 2 && inner_move == 1") == 2 and
        compiler.count("if outer_move == 1 || inner_move == 1 || take_count == 0") == 2 and
        "inner_move == 1 && take_count < 2" in compiler and
        "inner_move == 0 || take_count >= 2" in compiler,
        "native or fail-closed evidence weakened")
    from phase24_semantic_spelling_inventory import source_sites, manifest_summary
    before_new_spelling(activation, manifest_summary(source_sites()))
    from phase24_filename_behavior_characterization import source_sites as filename_sites
    before_new_filename(activation, filename_sites())
    from phase22_opening import (scan_invocations, logical_commands, COMPILER_TOKEN,
                                 is_non_invocation, classify, selection)
    raw = []
    path = ROOT / GUARD_PATH
    for line, command, recipe in logical_commands(path):
        for match in COMPILER_TOKEN.finditer(command):
            if not is_non_invocation(command, match.start()):
                raw.append(classify(path, line, command, recipe,
                                    match.group("token"), selection(command)))
    require(len(raw) == 24 and len(before_new_invocations(activation, raw)) == 23,
            "raw Phase22 invocation identity drifted")
    normalized = [e for e in scan_invocations() if e["path"] == GUARD_PATH]
    require(len(normalized) == 20 and normalized[-1] == activation[
        "call_outer_move_take_return_zero_increment"][
            "phase22_invocation_successor"]["previous_row"],
        "Phase22 projected invocation identity drifted")
    from phase23_mir_to_c_deprecation_opening import SURFACE_PATTERNS, SELF_EXCLUSIONS, tracked_paths
    surface = row["phase23_text_surface_successor"]
    changed, added = surface.get("changed_rows", []), surface.get("added_rows", [])
    require(surface.get("contract_version") ==
            "phase26_1e_innermost_move_finite_take_phase23_text_successor_v1" and
            surface.get("partial_extra_or_substituted_surface") == "rejected" and
            [entry.get("path") for entry in changed] == TEXT_PATHS and
            len(added) == 1 and added[0].get("path") ==
            "scripts/phase26_call_innermost_move_finite_take_return_registration.py" and
            all(path in tracked_paths() and path not in SELF_EXCLUSIONS
                for path in TEXT_PATHS), "text surface shape drifted")
    for entry in changed:
        path = entry["path"]
        previous_digest, previous_counts = old_text(activation, path)
        counts = {name: len(pattern.findall((ROOT / path).read_text()))
                  for name, pattern in SURFACE_PATTERNS.items()}
        require(previous_digest is not None and previous_counts is not None and
                entry == {"path": path, "previous_digest": previous_digest,
                          "current_digest": digest(path),
                          "previous_match_counts": previous_counts,
                          "current_match_counts": counts},
                f"text surface drifted: {path}")
    path = added[0]["path"]
    counts = {name: len(pattern.findall((ROOT / path).read_text()))
              for name, pattern in SURFACE_PATTERNS.items()}
    require(added[0] == {
        "path": path, "digest": digest(path), "match_counts": counts,
        "classification": "archive_candidate", "owner": "cranelift",
        "current_route": "tracked_MIR_to_C_or_generated_C_surface",
        "deprecation_action": "map_to_live_lane_or_archive_in_23_10_and_23_11",
        "removal_phase": "24",
        "falsifier": "active_evidence_surface_is_missing_or_changes_identity",
    } and any(counts.values()), "added text surface drifted")
    print(f"{GUARD}: innermost-Move finite-Take successor registration ok")


if __name__ == "__main__":
    main()
