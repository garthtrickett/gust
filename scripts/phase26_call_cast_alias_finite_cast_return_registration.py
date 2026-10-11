#!/usr/bin/env python3
"""Pin finite consecutive checked cast aliases before frozen Phase 26 owners."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KEY = "call_cast_alias_finite_cast_return_zero_increment"
OLD = "call_cast_alias_third_cast_return_zero_increment"
GUARD = "guard-cranelift-phase26-call-return-zero-evidence"
GUARD_PATH = "scripts/phase26_call_return_zero_evidence.sh"
POSITIVE = "compiler/phase26_call_return_zero_test_entry.gst"
CR15_PATH = "scripts/phase24_cr15_stdlib_guard_transition.py"
RECLASSIFIED = (
    "compiler/phase26_call_local_return_cast_alias_third_cast_fourth_cast_source.gst",
)
NAMES = (
    'fifth_interleaved_mayzero',
    'fifth_mayzero',
    'fifth_mayzero_move',
    'fifth_nonzero',
    'fifth_unknown',
    'fifth_zero',
    'fourth_double_move',
    'fourth_fifth_plain',
    'fourth_gap',
    'fourth_interleaved_mayzero',
    'fourth_interleaved_mayzero_move',
    'fourth_mayzero',
    'fourth_mayzero_move',
    'fourth_move_initializer',
    'fourth_move_take',
    'fourth_no_alias_cast',
    'fourth_nonzero',
    'fourth_overwrite',
    'fourth_plain_interleave',
    'fourth_plain_prefix',
    'fourth_prior_escape',
    'fourth_prior_move',
    'fourth_prior_move_return_move',
    'fourth_return_cast',
    'fourth_return_move_cast',
    'fourth_return_take',
    'fourth_scalar_cast',
    'fourth_take_initializer',
    'fourth_unknown',
    'fourth_unsafe',
    'fourth_wrong_type',
    'fourth_zero',
    'fourth_zero_move',
    'sixth_interleaved_mayzero',
    'sixth_mayzero',
    'sixth_mayzero_move',
    'sixth_nonzero',
    'sixth_unknown',
    'sixth_zero',
)
NEGATIVE_NAMES = (
    'fifth_interleaved_mayzero', 'fifth_mayzero_move', 'fifth_mayzero',
    'fifth_zero', 'fourth_interleaved_mayzero_move', 'fourth_interleaved_mayzero',
    'fourth_mayzero_move', 'fourth_mayzero', 'fourth_zero_move', 'fourth_zero',
    'sixth_interleaved_mayzero', 'sixth_mayzero_move', 'sixth_mayzero', 'sixth_zero',
)
NEW_FIXTURES = [f"compiler/phase26_call_local_return_cast_alias_finite_cast_{name}_source.gst"
                for name in NAMES]
TEXT_PATHS = ["compiler/typechecker.gst",
              "scripts/phase26_call_cast_alias_third_cast_return_registration.py",
              "scripts/phase26_call_cast_alias_second_cast_return_registration.py",
              "scripts/phase26_call_cast_alias_second_plain_return_registration.py",
              "scripts/phase26_call_cast_alias_take_return_registration.py",
              "scripts/phase26_call_cast_alias_return_cast_registration.py",
              "scripts/phase26_call_cast_initialized_alias_return_registration.py"]
FROZEN_TEXT = {
    "compiler/typechecker.gst": {
        "digest": "96c7bbf342d8ab73528984d14e6fc96e9940089db7b4cd63f37ef71b8510a695",
        "match_counts": {"explicit_backend_spelling": 0, "mir_to_c_name": 0,
                         "generated_c_contract": 1},
    },
    "scripts/phase26_call_cast_alias_third_cast_return_registration.py": {
        "digest": "f138c7f43635326b9e32e36da023c802d61f05d34b0cb960e432b8f6d950729d",
        "match_counts": {"explicit_backend_spelling": 0, "mir_to_c_name": 8,
                         "generated_c_contract": 1},
    },
    "scripts/phase26_call_cast_alias_second_cast_return_registration.py": {
        "digest": "c6c165c7eee5c0e545bcb1ae32ef1b57bb78e4cc9ea3027673ea8ae5925216e2",
        "match_counts": {"explicit_backend_spelling": 0, "mir_to_c_name": 7,
                         "generated_c_contract": 1},
    },
    "scripts/phase26_call_cast_alias_second_plain_return_registration.py": {
        "digest": "f78ac476632a3823acfcc966c8b4a75e9842c95cda14e5b33fdd0b6293a5ed71",
        "match_counts": {"explicit_backend_spelling": 0, "mir_to_c_name": 7,
                         "generated_c_contract": 1},
    },
    "scripts/phase26_call_cast_alias_take_return_registration.py": {
        "digest": "2abef1e872fe017900041820ca794226b2c0dda76e950a08d15228ae00e5d970",
        "match_counts": {"explicit_backend_spelling": 0, "mir_to_c_name": 5,
                         "generated_c_contract": 1},
    },
    "scripts/phase26_call_cast_alias_return_cast_registration.py": {
        "digest": "443adea6476f6990d9440ed47ca0f72a75ca5483a0a5cdadae3d874051e2922c",
        "match_counts": {"explicit_backend_spelling": 0, "mir_to_c_name": 4,
                         "generated_c_contract": 1},
    },
    "scripts/phase26_call_cast_initialized_alias_return_registration.py": {
        "digest": "89939071f1d345d5f34d70c3535bc9121ed6eeb50a77b25557d5efa4ddab67b2",
        "match_counts": {"explicit_backend_spelling": 0, "mir_to_c_name": 11,
                         "generated_c_contract": 1},
    },
}


def require(ok: bool, message: str) -> None:
    if not ok:
        raise SystemExit(f"{GUARD}: cast-alias finite-cast successor {message}")


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def record(activation: dict) -> dict:
    return activation.get(KEY, {})


def before_new_digest(activation: dict, path: str, live_digest: str) -> str:
    if activation.get("call_cast_alias_finite_cast_plain_return_zero_increment"):
        from phase26_call_cast_alias_finite_cast_plain_return_registration import before_new_digest as before_finite_cast_plain_digest
        live_digest = before_finite_cast_plain_digest(activation, path, live_digest)
    row = record(activation)
    for field in ("guard_digest_successor", "positive_fixture_successor",
                  "cr15_relay_digest_successor"):
        direct = row.get(field, {})
        if direct.get("path") == path:
            previous = activation[OLD][field]["current_digest"]
            require(direct.get("previous_digest") == previous and
                    direct.get("current_digest") == live_digest,
                    f"{field} digest drifted")
            return previous
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
    if activation.get("call_cast_alias_finite_cast_plain_return_zero_increment"):
        from phase26_call_cast_alias_finite_cast_plain_return_registration import before_new_counts as before_finite_cast_plain_counts
        live_counts = before_finite_cast_plain_counts(activation, path, live_counts)
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
    if activation.get("call_cast_alias_finite_cast_plain_return_zero_increment"):
        from phase26_call_cast_alias_finite_cast_plain_return_registration import before_new_spelling as before_finite_cast_plain_spelling
        live = before_finite_cast_plain_spelling(activation, live)
    successor = record(activation).get("spelling_inventory_successor", {})
    previous = activation[OLD]["spelling_inventory_successor"]["current_inventory_summary"]
    require(successor == {
        "contract_version": "phase26_1e_cast_alias_finite_cast_return_spelling_successor_v1",
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
    if activation.get("call_cast_alias_finite_cast_plain_return_zero_increment"):
        from phase26_call_cast_alias_finite_cast_plain_return_registration import before_new_filename as before_finite_cast_plain_filename
        live = before_finite_cast_plain_filename(activation, live)
    successor = record(activation).get("filename_site_successor", {})
    previous = activation[OLD]["filename_site_successor"]["current_sites"]
    require(successor == {
        "contract_version": "phase26_1e_cast_alias_finite_cast_return_filename_successor_v1",
        "previous_sites": previous,
        "current_sites": live,
        "line_deltas": [now["line"] - before["line"] for before, now in zip(previous, live)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(previous) == len(live) == 3 and
            all({k: v for k, v in now.items() if k != "line"} ==
                {k: v for k, v in before.items() if k != "line"}
                for before, now in zip(previous, live)), "filename sites drifted")
    return previous


def main() -> None:
    activation = json.loads((ROOT / "scripts/cranelift_feature_registry.json")
                            .read_text())["phase26_activation_audit"]
    if activation.get("call_cast_alias_finite_cast_plain_return_zero_increment"):
        from phase26_call_cast_alias_finite_cast_plain_return_registration import before_new_digest as project_new_digest, before_new_counts as project_new_counts
    else:
        project_new_digest = lambda _activation, _path, value: value
        project_new_counts = lambda _activation, _path, value: value
    row = record(activation)
    expected = {
        "contract_version": "phase26_1e_cast_alias_finite_cast_return_zero_v1",
        "status": "bounded_finite_checked_cast_alias_safe_return_rejection_qualified",
        "owner": "cranelift",
        "increment": "26.1E_finite_consecutive_checked_cast_aliases",
        "operator_ownership_decision": "2026-10-10_coordinator_assigned_under_activated_phase26",
        "candidate_shape": "immediate_same_block_concrete_nullary_raw_pointer_call_then_finite_four_or_more_consecutive_checked_raw_cast_initialized_aliases_then_direct_Identifier_or_one_direct_Move_return",
        "safe_boundary": "declared_nonextern_raw_pointer_return",
        "negative_states": ["Zero", "MayZero"],
        "negative_fixtures": [*RECLASSIFIED, *[f"compiler/phase26_call_local_return_cast_alias_finite_cast_{name}_source.gst" for name in NEGATIVE_NAMES]],
        "control_fixtures": [path for path in NEW_FIXTURES if path not in [f"compiler/phase26_call_local_return_cast_alias_finite_cast_{name}_source.gst" for name in NEGATIVE_NAMES]],
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved",
        "unsafe_functions": "preserved",
        "plain_prefix_or_interleave_take_move_initializer_return_wrapper_or_unproved_cast": "excluded_from_new_form",
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
                  "cr15_relay_digest_successor", "reclassified_fixture_digests",
                  "spelling_inventory_successor", "filename_site_successor",
                  "phase22_invocation_identity", "phase23_text_surface_successor"}
    require({key: row.get(key) for key in expected} == expected and
            set(row) == set(expected) | successors, "contract or field set drifted")
    require(all((ROOT / path).is_file() for path in [*RECLASSIFIED, *NEW_FIXTURES]),
            "source fixture missing")
    require(row["reclassified_fixture_digests"] == [
        {"path": path, "digest": digest(path),
         "previous_guard_classification": "phase13_deferral_before_driver",
         "current_guard_classification": "RawNullSafeBoundary_before_driver"}
        for path in RECLASSIFIED
    ], "frozen MayZero witness drifted")
    for field, path in (("guard_digest_successor", GUARD_PATH),
                        ("positive_fixture_successor", POSITIVE),
                        ("cr15_relay_digest_successor", CR15_PATH)):
        previous = activation[OLD][field]["current_digest"]
        require(row[field] == {
            "path": path, "previous_digest": previous,
            "current_digest": project_new_digest(activation, path, digest(path)),
            "partial_extra_or_substituted_" +
            ("guard" if field.startswith("guard") else
             "fixture" if field.startswith("positive") else "relay"): "rejected",
        }, f"{field} drifted")
    guard = (ROOT / GUARD_PATH).read_text()
    compiler = (ROOT / "compiler/typechecker.gst").read_text()
    finite_cast_plain = activation.get("call_cast_alias_finite_cast_plain_return_zero_increment")
    wrong_marker = ("finite_cast_fourth_wrong_type|finite_cast_plain_fourth_wrong_type|finite_plain_third_wrong_type)"
                    if finite_cast_plain else "finite_cast_fourth_wrong_type|finite_plain_third_wrong_type)")
    escape_marker = ("finite_cast_fourth_prior_escape|finite_cast_plain_fourth_prior_escape|finite_plain_third_prior_escape)"
                     if finite_cast_plain else "finite_cast_fourth_prior_escape|finite_plain_third_prior_escape)")
    move_marker = "finite_cast_fourth_prior_move|finite_cast_fourth_prior_move_return_move|finite_cast_fourth_return_move_cast)"
    if finite_cast_plain:
        from phase26_call_cast_alias_finite_cast_plain_return_registration import NAMES as FINITE_CAST_PLAIN_NAMES
        guard_cases = " ".join("finite_cast_" + name for name in NAMES) + " " + " ".join("finite_cast_plain_" + name for name in FINITE_CAST_PLAIN_NAMES) + " second_cast_zero"
    else:
        guard_cases = " ".join("finite_cast_" + name for name in NAMES) + " second_cast_zero"
    require(guard_cases in guard and
            "third_cast_interleaved_mayzero_move|third_cast_fourth_cast|finite_cast_" in guard and
            wrong_marker in guard and
            escape_marker in guard and
            move_marker in guard and
            'test ! -e "$marker"' in guard and
            "GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER" in guard and
            "zero_local_call_third_cast_terminal: int" in compiler and
            "if (*env).zero_local_call_third_cast_terminal == 1 {" in compiler and
            'if value.tag != 9 || (*env).zero_local_call_alias_hops < 3 { return ""; }' in compiler and
            "(*env).zero_local_call_alias_hops < 3) { return \"\"; }" in compiler and
            "(*env).zero_local_call_third_cast_terminal = 1;" in compiler and
            "phase26_zero_local_call_alias_cast_is_raw(statements[i], env, ctx) == 1" in compiler and
            "env_types_match_at_brand_boundary(env, source_type.Val, alias_type.Val, ctx) == 1" in compiler and
            "if (*env).zero_local_call_alias_hops >= 2 { return expr.tag == 0; }" in compiler and
            "if expr.tag == 4 { // One direct terminal Move" in compiler and
            "if moved_alias.tag != 0 { return 0; }" in compiler,
            "native or fail-closed evidence weakened")
    from phase24_semantic_spelling_inventory import source_sites, manifest_summary
    before_new_spelling(activation, manifest_summary(source_sites()))
    from phase24_filename_behavior_characterization import source_sites as filename_sites
    before_new_filename(activation, filename_sites())
    from phase22_opening import scan_invocations, logical_commands, COMPILER_TOKEN, is_non_invocation, classify, selection
    raw = []
    path = ROOT / GUARD_PATH
    for line, command, recipe in logical_commands(path):
        for match in COMPILER_TOKEN.finditer(command):
            if not is_non_invocation(command, match.start()):
                raw.append(classify(path, line, command, recipe,
                                    match.group("token"), selection(command)))
    selected = [entry for entry in raw if entry["path"] == GUARD_PATH]
    normalized = [entry for entry in scan_invocations() if entry["path"] == GUARD_PATH]
    prior = activation[OLD]["phase22_invocation_identity"]
    require(row["phase22_invocation_identity"] == {
        "raw_total": len(selected), "raw_last_row": selected[-1],
        "projected_total": len(normalized), "projected_last_row": normalized[-1],
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(selected) == prior["raw_total"] and
            len(normalized) == prior["projected_total"] and
            selected[-1]["path"] == prior["raw_last_row"]["path"] and
            normalized[-1]["path"] == prior["projected_last_row"]["path"],
            "raw or projected invocation identity drifted")
    from phase23_mir_to_c_deprecation_opening import SURFACE_PATTERNS, SELF_EXCLUSIONS, tracked_paths
    surface = row["phase23_text_surface_successor"]
    changed, added = surface.get("changed_rows", []), surface.get("added_rows", [])
    require(surface.get("contract_version") ==
            "phase26_1e_cast_alias_finite_cast_return_phase23_text_successor_v1" and
            surface.get("partial_extra_or_substituted_surface") == "rejected" and
            [entry.get("path") for entry in changed] == TEXT_PATHS and
            len(added) == 1 and added[0].get("path") ==
            "scripts/phase26_call_cast_alias_finite_cast_return_registration.py" and
            all(path in tracked_paths() and path not in SELF_EXCLUSIONS
                for path in TEXT_PATHS), "text surface shape drifted")
    for entry in changed:
        path = entry["path"]
        counts = {name: len(pattern.findall((ROOT / path).read_text()))
                  for name, pattern in SURFACE_PATTERNS.items()}
        current_digest = project_new_digest(activation, path, digest(path))
        counts = project_new_counts(activation, path, counts)
        require(entry == {"path": path,
                          "previous_digest": FROZEN_TEXT[path]["digest"],
                          "current_digest": current_digest,
                          "previous_match_counts": FROZEN_TEXT[path]["match_counts"],
                          "current_match_counts": counts},
                f"text surface drifted: {path}")
    path = added[0]["path"]
    counts = {name: len(pattern.findall((ROOT / path).read_text()))
              for name, pattern in SURFACE_PATTERNS.items()}
    current_digest = project_new_digest(activation, path, digest(path))
    counts = project_new_counts(activation, path, counts)
    require(added[0] == {
        "path": path, "digest": current_digest, "match_counts": counts,
        "classification": "archive_candidate", "owner": "cranelift",
        "current_route": "tracked_MIR_to_C_or_generated_C_surface",
        "deprecation_action": "map_to_live_lane_or_archive_in_23_10_and_23_11",
        "removal_phase": "24",
        "falsifier": "active_evidence_surface_is_missing_or_changes_identity",
    } and any(counts.values()), "added text surface drifted")
    print(f"{GUARD}: finite checked-cast alias successor registration ok")


if __name__ == "__main__":
    main()
