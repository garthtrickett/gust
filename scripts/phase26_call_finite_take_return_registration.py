#!/usr/bin/env python3
"""Pin the finite Take-only successor before older MIR-to-C evidence."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KEY = "call_finite_take_return_zero_increment"
OLD = "call_innermost_move_two_take_return_zero_increment"
GUARD = "guard-cranelift-phase26-call-return-zero-evidence"
GUARD_PATH = "scripts/phase26_call_return_zero_evidence.sh"
POSITIVE = "compiler/phase26_call_return_zero_test_entry.gst"
RECLASSIFIED = "compiler/phase26_call_local_return_two_take_third_take_source.gst"
NEW_FIXTURES = [
    f"compiler/phase26_call_local_return_finite_take_{name}_source.gst"
    for name in (
        "zero", "mayzero_three", "mayzero_four", "outer_cast_mayzero",
        "inner_cast_mayzero", "interleaved_cast_mayzero", "nonzero",
        "unknown", "unsafe", "gap", "overwrite", "wrong_type",
        "callee_first", "scalar_cast",
    )
]
TEXT_PATHS = [
    "compiler/typechecker.gst",
    "scripts/phase26_call_return_zero_registration.py",
    "scripts/phase26_call_inner_move_two_take_return_registration.py",
    "scripts/phase26_call_outer_move_two_take_return_registration.py",
    "scripts/phase26_call_innermost_move_two_take_return_registration.py",
]
CR15_PATH = "scripts/phase24_cr15_stdlib_guard_transition.py"
FROZEN_CR15 = {
    "digest": "a57cba7a8c14b382979e8117340a211d4cc6c708c4cd4d07a038148a047bd891",
    "match_counts": {"explicit_backend_spelling": 2, "mir_to_c_name": 15,
                     "generated_c_contract": 6},
}


def require(ok: bool, message: str) -> None:
    if not ok:
        raise SystemExit(f"{GUARD}: finite Take-only successor {message}")


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def record(activation: dict) -> dict:
    return activation.get(KEY, {})


def before_new_digest(activation: dict, path: str, live_digest: str) -> str:
    if activation.get("call_outer_move_finite_take_return_zero_increment"):
        from phase26_call_outer_move_finite_take_return_registration import before_new_digest as before_outer_finite_digest
        live_digest = before_outer_finite_digest(activation, path, live_digest)
    rows = record(activation).get("phase23_text_surface_successor", {}).get("changed_rows", [])
    matches = [row for row in rows if row.get("path") == path]
    require(len(matches) <= 1, f"duplicate text path: {path}")
    if not matches:
        return live_digest
    row = matches[0]
    require(row.get("current_digest") == live_digest and
            len(row.get("previous_digest", "")) == 64,
            f"text digest drifted: {path}")
    return row["previous_digest"]


def before_new_spelling(activation: dict, live: dict) -> dict:
    if activation.get("call_outer_move_finite_take_return_zero_increment"):
        from phase26_call_outer_move_finite_take_return_registration import before_new_spelling as before_outer_finite_spelling
        live = before_outer_finite_spelling(activation, live)
    successor = record(activation).get("spelling_inventory_successor", {})
    previous = activation[OLD]["spelling_inventory_successor"]["current_inventory_summary"]
    require(successor == {
        "contract_version": "phase26_1e_finite_take_spelling_successor_v1",
        "previous_inventory_summary": previous,
        "current_inventory_summary": live,
        "changed_source_paths": ["compiler/typechecker.gst", POSITIVE, *NEW_FIXTURES],
        "partial_extra_or_substituted_inventory": "rejected",
    } and live["source_file_count"] == previous["source_file_count"] + len(NEW_FIXTURES) and
            live["site_count"] == previous["site_count"] and
            live["semantic_site_count"] == previous["semantic_site_count"] and
            live["classification_counts"] == previous["classification_counts"] and
            live["unknown_site_count"] == 0,
            "spelling inventory drifted")
    return previous


def before_new_filename(activation: dict, live: list[dict]) -> list[dict]:
    if activation.get("call_outer_move_finite_take_return_zero_increment"):
        from phase26_call_outer_move_finite_take_return_registration import before_new_filename as before_outer_finite_filename
        live = before_outer_finite_filename(activation, live)
    successor = record(activation).get("filename_site_successor", {})
    previous = activation[OLD]["filename_site_successor"]["current_sites"]
    require(successor == {
        "contract_version": "phase26_1e_finite_take_filename_successor_v1",
        "previous_sites": previous,
        "current_sites": live,
        "line_deltas": [now["line"] - before["line"]
                        for before, now in zip(previous, live)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(previous) == len(live) == 3 and
            all({k: v for k, v in now.items() if k != "line"} ==
                {k: v for k, v in before.items() if k != "line"}
                for before, now in zip(previous, live)),
            "filename sites drifted")
    return previous


def before_new_invocations(activation: dict, live: list[dict], *,
                           projected: bool = False) -> list[dict]:
    if activation.get("call_outer_move_finite_take_return_zero_increment"):
        from phase26_call_outer_move_finite_take_return_registration import before_new_invocations as before_outer_finite_invocations
        live = before_outer_finite_invocations(activation, live, projected=projected)
    successor = record(activation).get("phase22_invocation_successor", {})
    previous = activation[OLD]["phase22_invocation_successor"]["current_row"]
    frozen = activation["call_outer_move_take_return_zero_increment"][
        "phase22_invocation_successor"]["previous_row"]
    current = successor.get("current_row", {})
    added = successor.get("added_row", {})
    selected = [row for row in live if row.get("path") == GUARD_PATH]
    require(successor == {
        "contract_version": "phase26_1e_finite_take_phase22_line_successor_v1",
        "previous_row": previous,
        "current_row": current,
        "unchanged_total": 20,
        "added_row": added,
        "current_total": 21,
        "partial_extra_or_substituted_invocation": "rejected",
    } and
            ((len(selected) == 20 and selected[-1] in (current, previous, frozen))
             if projected else
             (len(selected) == 21 and selected[-2] == current and selected[-1] == added)) and
            added.get("line") > current.get("line", 0) and
            {k: v for k, v in added.items() if k != "line"} ==
            {k: v for k, v in current.items() if k != "line"} and
            {k: v for k, v in current.items() if k != "line"} ==
            {k: v for k, v in previous.items() if k != "line"},
            "invocation line successor drifted")
    return [previous if row == current else row for row in live if row != added]


def main() -> None:
    activation = json.loads((ROOT / "scripts/cranelift_feature_registry.json")
                            .read_text())["phase26_activation_audit"]
    if activation.get("call_outer_move_finite_take_return_zero_increment"):
        from phase26_call_outer_move_finite_take_return_registration import main as outer_finite_main
        outer_finite_main()
    row = record(activation)
    expected = {
        "contract_version": "phase26_1e_finite_take_return_zero_v1",
        "status": "bounded_finite_take_safe_return_rejection_qualified",
        "owner": "cranelift",
        "increment": "26.1E_finite_Take_only_safe_return",
        "operator_ownership_decision": "2026-10-08_coordinator_assigned_under_activated_phase26",
        "candidate_shape": "immediate_same_block_concrete_nullary_raw_pointer_call_current_local_or_validated_alias_finite_Take_only_chain_optional_checked_raw_casts",
        "safe_boundary": "declared_nonextern_raw_pointer_return",
        "negative_states": ["Zero", "MayZero"],
        "negative_fixtures": [RECLASSIFIED, *NEW_FIXTURES[:6]],
        "control_fixtures": NEW_FIXTURES[6:],
        "reclassified_fixture": {"path": RECLASSIFIED,
                                 "previous": "accepted_then_native_deferral",
                                 "current": "RawNullSafeBoundary_before_driver"},
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved",
        "unsafe_functions": "preserved",
        "Move_bearing_third_Take_or_second_Move": "excluded_from_new_form",
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
    successors = {"guard_digest_successor", "phase23_text_surface_successor",
                  "spelling_inventory_successor", "filename_site_successor",
                  "phase22_invocation_successor", "positive_fixture_successor",
                  "cr15_relay_digest_successor"}
    require({k: row.get(k) for k in expected} == expected and
            set(row) == set(expected) | successors, "contract or field set drifted")
    require(all((ROOT / p).is_file() for p in [RECLASSIFIED, *NEW_FIXTURES]),
            "source fixture missing")
    live_guard_digest = digest(GUARD_PATH)
    live_positive_digest = digest(POSITIVE)
    if activation.get("call_innermost_move_three_take_return_zero_increment"):
        three = activation["call_innermost_move_three_take_return_zero_increment"]
        require(three["guard_digest_successor"]["current_digest"] == live_guard_digest and
                three["positive_fixture_successor"]["current_digest"] == live_positive_digest,
                "innermost-Move three-Take live evidence drifted")
        live_guard_digest = three["guard_digest_successor"]["previous_digest"]
        live_positive_digest = three["positive_fixture_successor"]["previous_digest"]
    if activation.get("call_outer_move_finite_take_return_zero_increment"):
        outer_finite = activation["call_outer_move_finite_take_return_zero_increment"]
        require(outer_finite["guard_digest_successor"]["current_digest"] == live_guard_digest and
                outer_finite["positive_fixture_successor"]["current_digest"] == live_positive_digest,
                "outer-Move finite-Take live evidence drifted")
        live_guard_digest = outer_finite["guard_digest_successor"]["previous_digest"]
        live_positive_digest = outer_finite["positive_fixture_successor"]["previous_digest"]
    require(row["guard_digest_successor"] == {
        "path": GUARD_PATH,
        "previous_digest": activation[OLD]["guard_digest_successor"]["current_digest"],
        "current_digest": live_guard_digest,
        "partial_extra_or_substituted_guard": "rejected",
    }, "guard digest drifted")
    require(row["positive_fixture_successor"] == {
        "path": POSITIVE,
        "previous_digest": activation[OLD]["positive_fixture_successor"]["current_digest"],
        "current_digest": live_positive_digest,
        "partial_extra_or_substituted_fixture": "rejected",
    }, "positive matcher evidence drifted")
    live_cr15_digest = digest(CR15_PATH)
    if activation.get("call_innermost_move_three_take_return_zero_increment"):
        three = activation["call_innermost_move_three_take_return_zero_increment"]
        require(three["cr15_relay_digest_successor"]["current_digest"] == live_cr15_digest,
                "innermost-Move three-Take CR15 relay drifted")
        live_cr15_digest = three["cr15_relay_digest_successor"]["previous_digest"]
    if activation.get("call_outer_move_finite_take_return_zero_increment"):
        outer_finite = activation["call_outer_move_finite_take_return_zero_increment"]
        require(outer_finite["cr15_relay_digest_successor"]["current_digest"] == live_cr15_digest and
                outer_finite["cr15_relay_digest_successor"]["previous_digest"] ==
                row["cr15_relay_digest_successor"]["current_digest"],
                "outer-Move finite-Take CR15 relay drifted")
        live_cr15_digest = outer_finite["cr15_relay_digest_successor"]["previous_digest"]
    require(row["cr15_relay_digest_successor"] == {
        "path": CR15_PATH,
        "previous_digest": FROZEN_CR15["digest"],
        "current_digest": live_cr15_digest,
        "partial_extra_or_substituted_relay": "rejected",
    }, "CR15 historical relay drifted")
    guard = (ROOT / GUARD_PATH).read_text()
    compiler = (ROOT / "compiler/typechecker.gst").read_text()
    case_names = [Path(path).stem.removeprefix("phase26_call_local_return_finite_take_").removesuffix("_source")
                  for path in NEW_FIXTURES]
    require(all(marker in guard for marker in (
        "two_take_third_take",
        "for case_name in " + " ".join(case_names) + "; do",
        "phase26_call_local_return_finite_take_${case_name}_source.gst",
        "zero|mayzero_three|mayzero_four|outer_cast_mayzero|inner_cast_mayzero|interleaved_cast_mayzero)",
        "GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER", "test ! -e \"$marker\"")) and
        (("take_count > 2 && (outer_move == 1 || inner_move == 1)" in compiler)
         if not activation.get("call_outer_move_finite_take_return_zero_increment") else
         (compiler.count("take_count > 2 && inner_move == 1") == 2 and
          activation["call_outer_move_finite_take_return_zero_increment"][
              "phase23_text_surface_successor"]["changed_rows"][0]["previous_digest"] ==
          row["phase23_text_surface_successor"]["changed_rows"][0]["current_digest"])) and
        (("(take_count != 1 && take_count != 2)" in compiler)
         if not activation.get("call_innermost_move_three_take_return_zero_increment") else
         (compiler.count("(take_count != 1 && take_count != 2 && take_count != 3)") == 2 and
          activation["call_innermost_move_three_take_return_zero_increment"][
              "phase23_text_surface_successor"]["changed_rows"][0]["previous_digest"] ==
          activation["call_outer_move_finite_take_return_zero_increment"][
              "phase23_text_surface_successor"]["changed_rows"][0]["current_digest"])) and
        "inner_move == 1 && take_count != 2" in compiler,
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
    expected_raw = (23 if activation.get("call_innermost_move_three_take_return_zero_increment") else
                    22 if activation.get("call_outer_move_finite_take_return_zero_increment") else 21)
    require(len(raw) == expected_raw and len(before_new_invocations(activation, raw)) == 20,
            "raw Phase22 invocation identity drifted")
    normalized = [e for e in scan_invocations() if e["path"] == GUARD_PATH]
    require(len(normalized) == 20 and normalized[-1] == activation[
        "call_outer_move_take_return_zero_increment"][
            "phase22_invocation_successor"]["previous_row"],
        "Phase22 projected invocation identity drifted")
    from phase23_mir_to_c_deprecation_opening import SURFACE_PATTERNS, SELF_EXCLUSIONS, tracked_paths
    cr15_text = (ROOT / CR15_PATH).read_text()
    require({name: len(pattern.findall(cr15_text))
             for name, pattern in SURFACE_PATTERNS.items()} ==
            FROZEN_CR15["match_counts"],
            "CR15 excluded historical surface counts drifted")
    surface = row["phase23_text_surface_successor"]
    changed = surface.get("changed_rows", [])
    added = surface.get("added_rows", [])
    prior_rows = {e["path"]: e for e in activation[OLD][
        "phase23_text_surface_successor"]["changed_rows"]}
    prior_added = activation[OLD]["phase23_text_surface_successor"]["added_rows"][0]
    require(prior_added["path"] ==
            "scripts/phase26_call_innermost_move_two_take_return_registration.py",
            "frozen text predecessor drifted")
    require(surface.get("contract_version") ==
            "phase26_1e_finite_take_phase23_text_successor_v1" and
            surface.get("partial_extra_or_substituted_surface") == "rejected" and
            [e.get("path") for e in changed] == TEXT_PATHS and
            len(added) == 1 and added[0].get("path") ==
            "scripts/phase26_call_finite_take_return_registration.py" and
            prior_added["path"] ==
            "scripts/phase26_call_innermost_move_two_take_return_registration.py" and
            all(p in tracked_paths() and p not in SELF_EXCLUSIONS for p in TEXT_PATHS),
            "text surface shape drifted")
    for e in changed:
        path = e["path"]
        counts = {name: len(pattern.findall((ROOT / path).read_text()))
                  for name, pattern in SURFACE_PATTERNS.items()}
        current_digest = digest(path)
        if activation.get("call_outer_move_finite_take_return_zero_increment"):
            from phase26_call_outer_move_finite_take_return_registration import before_new_digest as before_outer_finite_digest, before_new_counts as before_outer_finite_counts
            current_digest = before_outer_finite_digest(activation, path, current_digest)
            counts = before_outer_finite_counts(activation, path, counts)
        prior = prior_rows.get(path)
        require(prior is not None or path == prior_added["path"],
                f"unproven predecessor: {path}")
        previous_digest = prior["current_digest"] if prior else prior_added["digest"]
        previous_counts = (prior["current_match_counts"] if prior else
                           prior_added["match_counts"])
        require(e == {"path": path,
                      "previous_digest": previous_digest,
                      "current_digest": current_digest,
                      "previous_match_counts": previous_counts,
                      "current_match_counts": counts},
                f"text surface drifted: {path}")
    path = added[0]["path"]
    counts = {name: len(pattern.findall((ROOT / path).read_text()))
              for name, pattern in SURFACE_PATTERNS.items()}
    current_digest = digest(path)
    if activation.get("call_outer_move_finite_take_return_zero_increment"):
        from phase26_call_outer_move_finite_take_return_registration import before_new_digest as before_outer_finite_digest, before_new_counts as before_outer_finite_counts
        current_digest = before_outer_finite_digest(activation, path, current_digest)
        counts = before_outer_finite_counts(activation, path, counts)
    require(added[0] == {
        "path": path, "digest": current_digest, "match_counts": counts,
        "classification": "archive_candidate", "owner": "cranelift",
        "current_route": "tracked_MIR_to_C_or_generated_C_surface",
        "deprecation_action": "map_to_live_lane_or_archive_in_23_10_and_23_11",
        "removal_phase": "24",
        "falsifier": "active_evidence_surface_is_missing_or_changes_identity",
    } and any(counts.values()), "added text surface drifted")
    print(f"{GUARD}: finite Take-only successor registration ok")


if __name__ == "__main__":
    main()
