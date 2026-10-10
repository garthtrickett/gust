#!/usr/bin/env python3
"""Pin one additional plain alias after one checked cast-initialized alias before frozen owners."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KEY = "call_cast_alias_second_plain_return_zero_increment"
OLD = "call_cast_alias_direct_move_return_zero_increment"
GUARD = "guard-cranelift-phase26-call-return-zero-evidence"
GUARD_PATH = "scripts/phase26_call_return_zero_evidence.sh"
POSITIVE = "compiler/phase26_call_return_zero_test_entry.gst"
CR15_PATH = "scripts/phase24_cr15_stdlib_guard_transition.py"
RECLASSIFIED = (
    "compiler/phase26_call_local_return_cast_alias_second_alias_source.gst",
    "compiler/phase26_call_local_return_cast_alias_plain_suffix_source.gst",
    "compiler/phase26_call_local_return_cast_alias_direct_move_second_alias_source.gst",
)
NAMES = ("zero", "zero_move", "depth3", "depth3_move", "nonzero", "unknown", "unsafe",
         "third_alias", "second_cast", "second_take", "second_move", "return_cast",
         "return_take", "return_move_cast", "return_take_move", "return_move_take",
         "double_move", "gap", "overwrite", "scalar_cast", "prior_move",
         "prior_move_return_move", "wrong_type", "prior_escape", "plain_prefix")
NEW_FIXTURES = [f"compiler/phase26_call_local_return_cast_alias_second_plain_{name}_source.gst"
                for name in NAMES]
TEXT_PATHS = ["compiler/typechecker.gst",
              "scripts/phase26_call_cast_alias_direct_move_return_registration.py",
              "scripts/phase26_call_cast_alias_take_return_registration.py",
              "scripts/phase26_call_cast_alias_return_cast_registration.py",
              "scripts/phase26_call_cast_initialized_alias_return_registration.py",
              "scripts/phase26_call_return_zero_registration.py"]
FROZEN_TEXT = {
    'compiler/typechecker.gst': {
        "digest": "4332d9f2d5f9d001a71ada91a333ed2edcf22eff428daaab1f9cd3384f03f548",
        "match_counts": {'explicit_backend_spelling': 0, 'mir_to_c_name': 0, 'generated_c_contract': 1},
    },
    'scripts/phase26_call_cast_alias_direct_move_return_registration.py': {
        "digest": "cfcedfc8150d8605c590f34208337b4ae36a27f12165a861a800bbe57d8aa0b2",
        "match_counts": {'explicit_backend_spelling': 0, 'mir_to_c_name': 6, 'generated_c_contract': 1},
    },
    'scripts/phase26_call_cast_alias_take_return_registration.py': {
        "digest": "c71c07bf2f437245813d77726f33d471d260b7684110059719e2ab90d7a8c7c5",
        "match_counts": {'explicit_backend_spelling': 0, 'mir_to_c_name': 5, 'generated_c_contract': 1},
    },
    'scripts/phase26_call_cast_alias_return_cast_registration.py': {
        "digest": "fdd390fda8a27b06b38b60ca3028fabc21441927ff3c9e70d3350e4a59a11bf7",
        "match_counts": {'explicit_backend_spelling': 0, 'mir_to_c_name': 4, 'generated_c_contract': 1},
    },
    'scripts/phase26_call_cast_initialized_alias_return_registration.py': {
        "digest": "187c7999a2a90b8582fb0de92f615853053ac61b968d2f7782a63c02b9c1b8f7",
        "match_counts": {'explicit_backend_spelling': 0, 'mir_to_c_name': 11, 'generated_c_contract': 1},
    },
    'scripts/phase26_call_return_zero_registration.py': {
        "digest": "733ea9e366794ac261b858e5be102b201698d7305c7f964effb8b2d463cc8295",
        "match_counts": {'explicit_backend_spelling': 0, 'mir_to_c_name': 1, 'generated_c_contract': 0},
    },
}


def require(ok: bool, message: str) -> None:
    if not ok:
        raise SystemExit(f"{GUARD}: cast-alias second-plain successor {message}")


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
        "contract_version": "phase26_1e_cast_alias_second_plain_return_spelling_successor_v1",
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
        "contract_version": "phase26_1e_cast_alias_second_plain_return_filename_successor_v1",
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
    row = record(activation)
    expected = {
        "contract_version": "phase26_1e_cast_alias_second_plain_return_zero_v1",
        "status": "bounded_second_plain_after_checked_cast_alias_safe_return_rejection_qualified",
        "owner": "cranelift",
        "increment": "26.1E_one_plain_alias_after_one_cast_initialized_alias",
        "operator_ownership_decision": "2026-10-10_coordinator_assigned_under_activated_phase26",
        "candidate_shape": "immediate_same_block_concrete_nullary_raw_pointer_call_then_one_checked_cast_initialized_alias_then_one_plain_by_value_raw_alias_then_direct_Identifier_or_one_direct_Move_return",
        "safe_boundary": "declared_nonextern_raw_pointer_return",
        "negative_states": ["Zero", "MayZero"],
        "negative_fixtures": [*RECLASSIFIED, *NEW_FIXTURES[:4]],
        "control_fixtures": NEW_FIXTURES[4:],
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved",
        "unsafe_functions": "preserved",
        "third_alias_wrapped_return_or_unproved_cast": "excluded_from_new_form",
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
    ],
            "frozen MayZero witnesses drifted")
    for field, path in (("guard_digest_successor", GUARD_PATH),
                        ("positive_fixture_successor", POSITIVE),
                        ("cr15_relay_digest_successor", CR15_PATH)):
        previous = activation[OLD][field]["current_digest"]
        require(row[field] == {
            "path": path, "previous_digest": previous,
            "current_digest": digest(path),
            "partial_extra_or_substituted_" +
            ("guard" if field.startswith("guard") else
             "fixture" if field.startswith("positive") else "relay"): "rejected",
        }, f"{field} drifted")
    guard = (ROOT / GUARD_PATH).read_text()
    compiler = (ROOT / "compiler/typechecker.gst").read_text()
    require(" ".join("second_plain_" + name for name in NAMES) + " direct_move_zero" in guard and
            "phase26_call_local_return_cast_alias_${case_name}_source.gst" in guard and
            "second_plain_wrong_type)" in guard and
            "second_plain_prior_escape)" in guard and
            "take_prior_move)" in guard and
            "second_plain_prior_move|second_plain_prior_move_return_move|second_plain_return_move_cast)" in guard and
            "take_move_mixed" in guard and
            "return_move_cast|direct_move_cast_wrapped)" in guard and
            "zero|mayzero|depth3|second_alias|plain_suffix|direct_move_second_alias|return_cast" in guard and
            "second_plain_zero|second_plain_zero_move|second_plain_depth3|second_plain_depth3_move)" in guard and
            'test ! -e "$marker"' in guard and
            "GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER" in guard and
            "if expr.tag == 4 { // One direct terminal Move" in compiler and
            "if moved_alias.tag != 0 { return 0; }" in compiler and
            "return ctx[expr.Move.expr].tag == 0;" in compiler and
            "if (*env).zero_local_call_alias_hops == 2 { return expr.tag == 0; }" in compiler and
            "if (*env).zero_local_call_cast_alias_terminal == 1 && value.tag != 0 { return \"\"; }" in compiler and
            "while alias_return.tag == 5 || alias_return.tag == 9" in compiler and
            "phase26_zero_resolved_expression_tag(next_idx, env, ctx) != 9" in compiler and
            "if alias_return.tag != 0 { return 0; }" in compiler,
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
        "raw_total": 29, "raw_last_row": prior["raw_last_row"],
        "projected_total": 20, "projected_last_row": prior["projected_last_row"],
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(selected) == 29 and selected[-1] == prior["raw_last_row"] and
            len(normalized) == 20 and normalized[-1] == prior["projected_last_row"],
            "raw or projected invocation identity drifted")
    from phase23_mir_to_c_deprecation_opening import SURFACE_PATTERNS, SELF_EXCLUSIONS, tracked_paths
    surface = row["phase23_text_surface_successor"]
    changed, added = surface.get("changed_rows", []), surface.get("added_rows", [])
    require(surface.get("contract_version") ==
            "phase26_1e_cast_alias_second_plain_return_phase23_text_successor_v1" and
            surface.get("partial_extra_or_substituted_surface") == "rejected" and
            [entry.get("path") for entry in changed] == TEXT_PATHS and
            len(added) == 1 and added[0].get("path") ==
            "scripts/phase26_call_cast_alias_second_plain_return_registration.py" and
            all(path in tracked_paths() and path not in SELF_EXCLUSIONS
                for path in TEXT_PATHS), "text surface shape drifted")
    for entry in changed:
        path = entry["path"]
        counts = {name: len(pattern.findall((ROOT / path).read_text()))
                  for name, pattern in SURFACE_PATTERNS.items()}
        require(entry == {"path": path,
                          "previous_digest": FROZEN_TEXT[path]["digest"],
                          "current_digest": digest(path),
                          "previous_match_counts": FROZEN_TEXT[path]["match_counts"],
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
    print(f"{GUARD}: cast-alias second-plain successor registration ok")


if __name__ == "__main__":
    main()
