#!/usr/bin/env python3
"""Pin the single checked cast-initialized alias successor before frozen owners."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KEY = "call_cast_initialized_alias_return_zero_increment"
OLD = "call_outer_move_cast_prefix_return_zero_increment"
GUARD = "guard-cranelift-phase26-call-return-zero-evidence"
GUARD_PATH = "scripts/phase26_call_return_zero_evidence.sh"
POSITIVE = "compiler/phase26_call_return_zero_test_entry.gst"
CR15_PATH = "scripts/phase24_cr15_stdlib_guard_transition.py"
NAMES = ('zero', 'mayzero', 'depth3', 'nonzero', 'unknown', 'unsafe',
         'second_alias', 'plain_prefix', 'plain_suffix', 'take_inner',
         'move_inner', 'return_cast', 'return_take', 'return_move',
         'gap', 'overwrite', 'wrong_type',
         'prior_escape', 'scalar_cast', 'no_alias_cast', 'prior_move')
NEW_FIXTURES = [
    f"compiler/phase26_call_local_return_cast_alias_{name}_source.gst"
    for name in NAMES
]
TEXT_PATHS = ['compiler/typechecker.gst',
 'scripts/phase26_call_return_zero_registration.py',
 'scripts/phase26_call_outer_move_cast_prefix_return_registration.py',
 'scripts/phase26_call_finite_outer_move_finite_inner_take_return_registration.py',
 'scripts/phase26_call_two_outer_move_finite_inner_take_return_registration.py',
 'scripts/phase26_call_between_move_finite_inner_take_return_registration.py',
 'scripts/phase26_call_innermost_move_three_take_return_registration.py',
 'scripts/phase26_call_innermost_move_finite_take_return_registration.py',
 'scripts/phase26_call_outer_move_finite_take_return_registration.py',
 'scripts/phase26_call_finite_take_return_registration.py']
FROZEN_TEXT = {'compiler/typechecker.gst': {'digest': 'd7277863be6caa393b5fdd73d399ccd2b857eea01b272e090a6e53c76c00f579',
                              'match_counts': {'explicit_backend_spelling': 0,
                                               'mir_to_c_name': 0,
                                               'generated_c_contract': 1}},
 'scripts/phase26_call_return_zero_registration.py': {'digest': '779d5e5a25a45d101033e4f250a8d8d3993e4d4ba00437d08bccd415b19975b7',
                                                       'match_counts': {'explicit_backend_spelling': 0,
                                                                        'mir_to_c_name': 1,
                                                                        'generated_c_contract': 0}},
 'scripts/phase26_call_outer_move_cast_prefix_return_registration.py': {'digest': 'c4cee44cb52246822894aa98d696fcf2f12532bb66631f4c2ee66d935872d821',
                                                                        'match_counts': {'explicit_backend_spelling': 0,
                                                                                         'mir_to_c_name': 15,
                                                                                         'generated_c_contract': 1}},
 'scripts/phase26_call_finite_outer_move_finite_inner_take_return_registration.py': {'digest': '4cb798f2f865f2dadf3fa5f7e4e441d96fdc363c0d5840a70ee8972e934be1e1',
                                                                                     'match_counts': {'explicit_backend_spelling': 0,
                                                                                                      'mir_to_c_name': 1,
                                                                                                      'generated_c_contract': 1}},
 'scripts/phase26_call_two_outer_move_finite_inner_take_return_registration.py': {'digest': '0dd50b3d7f54e83dab41ab0adf313a6dadcca84736532b583b73995b6efbb806',
                                                                                  'match_counts': {'explicit_backend_spelling': 0,
                                                                                                   'mir_to_c_name': 1,
                                                                                                   'generated_c_contract': 1}},
 'scripts/phase26_call_between_move_finite_inner_take_return_registration.py': {'digest': '9236917355b8bc9ae495251b61dcaf788e70b3b6a5bb7245a63c8f0710063f27',
                                                                                'match_counts': {'explicit_backend_spelling': 0,
                                                                                                 'mir_to_c_name': 1,
                                                                                                 'generated_c_contract': 1}},
 'scripts/phase26_call_innermost_move_three_take_return_registration.py': {'digest': 'f271d279a0f6989833adeabcd5bd8c57e13c560bda221c222011d3ac93b4dcb6',
                                                                           'match_counts': {'explicit_backend_spelling': 0,
                                                                                            'mir_to_c_name': 1,
                                                                                            'generated_c_contract': 1}},
 'scripts/phase26_call_innermost_move_finite_take_return_registration.py': {'digest': '6eb0784cccc72f824d041b3f9633fbc0acc9a6c99a415394a3a2382ad150b4df',
                                                                            'match_counts': {'explicit_backend_spelling': 0,
                                                                                             'mir_to_c_name': 1,
                                                                                             'generated_c_contract': 1}},
 'scripts/phase26_call_outer_move_finite_take_return_registration.py': {'digest': 'f30d268ea55d4e7b27172dd1580e27d277849727880a9ddfb1e19d7c943b76e3',
                                                                        'match_counts': {'explicit_backend_spelling': 0,
                                                                                         'mir_to_c_name': 4,
                                                                                         'generated_c_contract': 1}},
 'scripts/phase26_call_finite_take_return_registration.py': {'digest': 'c1bfdcbbc897f6dae34fe523bedf0cf2b0015ecdcdc6dd1a79d20a4d89a3c2b9',
                                                             'match_counts': {'explicit_backend_spelling': 0,
                                                                              'mir_to_c_name': 3,
                                                                              'generated_c_contract': 1}}}


def require(ok: bool, message: str) -> None:
    if not ok:
        raise SystemExit(f"{GUARD}: cast-initialized alias successor {message}")


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def record(activation: dict) -> dict:
    return activation.get(KEY, {})


def before_new_digest(activation: dict, path: str, live_digest: str) -> str:
    row = record(activation)
    for field in ("guard_digest_successor", "positive_fixture_successor",
                  "cr15_relay_digest_successor"):
        direct = row.get(field, {})
        if direct.get("path") == path:
            require(direct.get("current_digest") == live_digest and
                    isinstance(direct.get("previous_digest"), str),
                    f"{field} digest drifted")
            return direct["previous_digest"]
    rows = row.get("phase23_text_surface_successor", {}).get("changed_rows", [])
    matches = [entry for entry in rows if entry.get("path") == path]
    require(len(matches) <= 1, f"duplicate text path: {path}")
    if not matches:
        return live_digest
    entry = matches[0]
    previous = FROZEN_TEXT.get(path, {}).get("digest")
    require(previous is not None and entry.get("previous_digest") == previous and
            entry.get("current_digest") == live_digest,
            f"text digest drifted: {path}")
    return previous


def before_new_counts(activation: dict, path: str,
                      live_counts: dict[str, int]) -> dict[str, int]:
    rows = record(activation).get("phase23_text_surface_successor", {}).get("changed_rows", [])
    matches = [entry for entry in rows if entry.get("path") == path]
    require(len(matches) <= 1, f"duplicate text path: {path}")
    if not matches:
        return live_counts
    entry = matches[0]
    previous = FROZEN_TEXT.get(path, {}).get("match_counts")
    require(previous is not None and entry.get("previous_match_counts") == previous and
            entry.get("current_match_counts") == live_counts,
            f"text count drifted: {path}")
    return previous


def before_new_spelling(activation: dict, live: dict) -> dict:
    successor = record(activation).get("spelling_inventory_successor", {})
    previous = activation[OLD]["spelling_inventory_successor"]["current_inventory_summary"]
    require(successor == {
        "contract_version": "phase26_1e_cast_initialized_alias_spelling_successor_v1",
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
        "contract_version": "phase26_1e_cast_initialized_alias_filename_successor_v1",
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
    selected = [entry for entry in live if entry.get("path") == GUARD_PATH]
    require(successor == {
        "contract_version": "phase26_1e_cast_initialized_alias_phase22_line_successor_v1",
        "previous_row": previous, "unchanged_total": 28,
        "added_row": added, "current_total": 29,
        "partial_extra_or_substituted_invocation": "rejected",
    } and
            ((len(selected) in range(20, 29) and selected[-1] in
              (previous, activation[OLD]["phase22_invocation_successor"]["previous_row"], frozen))
             if projected else
             (len(selected) == 29 and selected[-2] == previous and selected[-1] == added)) and
            added.get("line", 0) > previous.get("line", 0) and
            {k: v for k, v in added.items() if k != "line"} ==
            {k: v for k, v in previous.items() if k != "line"},
            "invocation line successor drifted")
    return [entry for entry in live if entry != added]


def main() -> None:
    activation = json.loads((ROOT / "scripts/cranelift_feature_registry.json")
                            .read_text())["phase26_activation_audit"]
    row = record(activation)
    expected = {
        "contract_version": "phase26_1e_cast_initialized_alias_return_zero_v1",
        "status": "bounded_checked_raw_cast_initialized_alias_safe_return_rejection_qualified",
        "owner": "cranelift",
        "increment": "26.1E_one_immediate_checked_raw_cast_initialized_alias_safe_return",
        "operator_ownership_decision": "2026-10-09_coordinator_assigned_under_activated_phase26",
        "candidate_shape": "immediate_same_block_concrete_nullary_raw_pointer_call_then_one_by_value_alias_initialized_by_finite_checked_raw_pointer_casts_around_Identifier_then_immediate_Identifier_return",
        "safe_boundary": "declared_nonextern_raw_pointer_return",
        "negative_states": ["Zero", "MayZero"],
        "negative_fixtures": NEW_FIXTURES[:3],
        "control_fixtures": NEW_FIXTURES[3:],
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved",
        "unsafe_functions": "preserved",
        "second_alias_or_return_wrapper": "excluded_from_new_form",
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
    require({key: row.get(key) for key in expected} == expected and
            set(row) == set(expected) | successors, "contract or field set drifted")
    require(all((ROOT / path).is_file() for path in NEW_FIXTURES),
            "source fixture missing")
    for field, path, previous in (
        ("guard_digest_successor", GUARD_PATH,
         activation[OLD]["guard_digest_successor"]["current_digest"]),
        ("positive_fixture_successor", POSITIVE,
         activation[OLD]["positive_fixture_successor"]["current_digest"]),
        ("cr15_relay_digest_successor", CR15_PATH,
         activation[OLD]["cr15_relay_digest_successor"]["current_digest"]),
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
        "for case_name in " + " ".join(NAMES) + "; do",
        "phase26_call_local_return_cast_alias_${case_name}_source.gst",
        "GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER", 'test ! -e "$marker"')) and
        "zero_local_call_cast_alias_terminal" in compiler and
        "phase26_zero_local_call_alias_cast_is_raw" in compiler and
        "phase26_zero_resolved_expression_tag(value.AsCast.left, env, ctx) != 9" in compiler and
        "if (*env).zero_local_call_cast_alias_terminal == 1 { return 0; }" in compiler and
        "if expr.tag != 0 { return 0; }" in compiler,
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
    require(len(raw) == 29 and len(before_new_invocations(activation, raw)) == 28,
            "raw Phase22 invocation identity drifted")
    normalized = [entry for entry in scan_invocations() if entry["path"] == GUARD_PATH]
    require(len(normalized) == 20 and normalized[-1] == activation[
        "call_outer_move_take_return_zero_increment"][
            "phase22_invocation_successor"]["previous_row"],
        "Phase22 projected invocation identity drifted")
    from phase23_mir_to_c_deprecation_opening import SURFACE_PATTERNS, SELF_EXCLUSIONS, tracked_paths
    surface = row["phase23_text_surface_successor"]
    changed, added = surface.get("changed_rows", []), surface.get("added_rows", [])
    require(surface.get("contract_version") ==
            "phase26_1e_cast_initialized_alias_phase23_text_successor_v1" and
            surface.get("partial_extra_or_substituted_surface") == "rejected" and
            [entry.get("path") for entry in changed] == TEXT_PATHS and
            len(added) == 1 and added[0].get("path") ==
            "scripts/phase26_call_cast_initialized_alias_return_registration.py" and
            all(path in tracked_paths() and path not in SELF_EXCLUSIONS
                for path in TEXT_PATHS), "text surface shape drifted")
    for entry in changed:
        path = entry["path"]
        frozen = FROZEN_TEXT[path]
        counts = {name: len(pattern.findall((ROOT / path).read_text()))
                  for name, pattern in SURFACE_PATTERNS.items()}
        require(entry == {"path": path, "previous_digest": frozen["digest"],
                          "current_digest": digest(path),
                          "previous_match_counts": frozen["match_counts"],
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
    print(f"{GUARD}: cast-initialized alias successor registration ok")


if __name__ == "__main__":
    main()
