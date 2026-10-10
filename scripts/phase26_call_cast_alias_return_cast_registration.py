#!/usr/bin/env python3
"""Pin checked return casts after one cast-initialized alias before frozen owners."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KEY = "call_cast_alias_return_cast_zero_increment"
OLD = "call_cast_initialized_alias_return_zero_increment"
GUARD = "guard-cranelift-phase26-call-return-zero-evidence"
GUARD_PATH = "scripts/phase26_call_return_zero_evidence.sh"
POSITIVE = "compiler/phase26_call_return_zero_test_entry.gst"
CR15_PATH = "scripts/phase24_cr15_stdlib_guard_transition.py"
RECLASSIFIED = "compiler/phase26_call_local_return_cast_alias_return_cast_source.gst"
NAMES = ("return_zero", "return_depth3", "return_nonzero", "return_unknown",
         "return_unsafe", "return_scalar", "return_take_cast", "return_move_cast",
         "return_wrong_type", "return_prior_escape", "return_prior_move",
         "return_second_alias", "return_gap", "return_overwrite")
NEW_FIXTURES = [f"compiler/phase26_call_local_return_cast_alias_{name}_source.gst"
                for name in NAMES]
TEXT_PATHS = ["compiler/typechecker.gst",
              "scripts/phase26_call_cast_initialized_alias_return_registration.py",
              "scripts/phase26_call_return_zero_registration.py"]
FROZEN_TEXT = {
    "compiler/typechecker.gst": {
        "digest": "fb15cb8cd737da36a87d18f59b3af59e2e90f02e573a28a51cc74ac0f4d8ccac",
        "match_counts": {"explicit_backend_spelling": 0, "mir_to_c_name": 0,
                         "generated_c_contract": 1}},
    "scripts/phase26_call_cast_initialized_alias_return_registration.py": {
        "digest": "b2ea5ec1c8b301e4a70810c80282826f8de6d2fcbfef55672b15c897ba0d0149",
        "match_counts": {"explicit_backend_spelling": 0, "mir_to_c_name": 11,
                         "generated_c_contract": 1}},
    "scripts/phase26_call_return_zero_registration.py": {
        "digest": "fdc39038b1fa41cbb1101de74ce2bb9648514e06f5f89425da774cb8abb143e5",
        "match_counts": {"explicit_backend_spelling": 0, "mir_to_c_name": 1,
                         "generated_c_contract": 0}},
}


def require(ok: bool, message: str) -> None:
    if not ok:
        raise SystemExit(f"{GUARD}: checked return-cast successor {message}")


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def record(activation: dict) -> dict:
    return activation.get(KEY, {})


def before_new_digest(activation: dict, path: str, live_digest: str) -> str:
    if activation.get("call_cast_alias_take_return_zero_increment"):
        from phase26_call_cast_alias_take_return_registration import before_new_digest as before_take_return
        live_digest = before_take_return(activation, path, live_digest)
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
    if activation.get("call_cast_alias_take_return_zero_increment"):
        from phase26_call_cast_alias_take_return_registration import before_new_counts as before_take_return
        live_counts = before_take_return(activation, path, live_counts)
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
    if activation.get("call_cast_alias_take_return_zero_increment"):
        from phase26_call_cast_alias_take_return_registration import before_new_spelling as before_take_return
        live = before_take_return(activation, live)
    successor = record(activation).get("spelling_inventory_successor", {})
    previous = activation[OLD]["spelling_inventory_successor"]["current_inventory_summary"]
    require(successor == {
        "contract_version": "phase26_1e_cast_alias_return_cast_spelling_successor_v1",
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
    if activation.get("call_cast_alias_take_return_zero_increment"):
        from phase26_call_cast_alias_take_return_registration import before_new_filename as before_take_return
        live = before_take_return(activation, live)
    successor = record(activation).get("filename_site_successor", {})
    previous = activation[OLD]["filename_site_successor"]["current_sites"]
    require(successor == {
        "contract_version": "phase26_1e_cast_alias_return_cast_filename_successor_v1",
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
    if activation.get("call_cast_alias_take_return_zero_increment"):
        from phase26_call_cast_alias_take_return_registration import main as take_return_main
        take_return_main()
    row = record(activation)
    expected = {
        "contract_version": "phase26_1e_cast_alias_return_cast_zero_v1",
        "status": "bounded_checked_raw_return_cast_after_cast_alias_safe_return_rejection_qualified",
        "owner": "cranelift",
        "increment": "26.1E_finite_checked_raw_return_casts_after_one_cast_initialized_alias",
        "operator_ownership_decision": "2026-10-09_coordinator_assigned_under_activated_phase26",
        "candidate_shape": "immediate_same_block_concrete_nullary_raw_pointer_call_then_one_checked_cast_initialized_alias_then_immediate_finite_checked_raw_casts_around_Identifier_return",
        "safe_boundary": "declared_nonextern_raw_pointer_return",
        "negative_states": ["Zero", "MayZero"],
        "negative_fixtures": [RECLASSIFIED, NEW_FIXTURES[0], NEW_FIXTURES[1]],
        "control_fixtures": NEW_FIXTURES[2:],
        "prior_error_precedence": "preserved",
        "unknown_and_nonzero": "preserved",
        "unsafe_functions": "preserved",
        "second_alias_take_move_or_unproved_cast": "excluded_from_new_form",
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
                  "cr15_relay_digest_successor", "reclassified_fixture_digest",
                  "spelling_inventory_successor", "filename_site_successor",
                  "phase22_invocation_identity", "phase23_text_surface_successor"}
    require({key: row.get(key) for key in expected} == expected and
            set(row) == set(expected) | successors, "contract or field set drifted")
    require(all((ROOT / path).is_file() for path in [RECLASSIFIED, *NEW_FIXTURES]),
            "source fixture missing")
    require(row["reclassified_fixture_digest"] == {
        "path": RECLASSIFIED,
        "digest": "dac8c95ef340305b270e60d9f1ec36aa39df83679f3828ef19e4f6941886f9b4",
        "previous_guard_classification": "phase13_deferral_before_driver",
        "current_guard_classification": "RawNullSafeBoundary_before_driver",
    } and digest(RECLASSIFIED) == row["reclassified_fixture_digest"]["digest"],
            "frozen MayZero witness drifted")
    for field, path in (("guard_digest_successor", GUARD_PATH),
                        ("positive_fixture_successor", POSITIVE),
                        ("cr15_relay_digest_successor", CR15_PATH)):
        previous = activation[OLD][field]["current_digest"]
        current_digest = digest(path)
        if activation.get("call_cast_alias_take_return_zero_increment"):
            from phase26_call_cast_alias_take_return_registration import before_new_digest as before_take_return
            current_digest = before_take_return(activation, path, current_digest)
        require(row[field] == {
            "path": path, "previous_digest": previous,
            "current_digest": current_digest,
            "partial_extra_or_substituted_" +
            ("guard" if field.startswith("guard") else
             "fixture" if field.startswith("positive") else "relay"): "rejected",
        }, f"{field} drifted")
    guard = (ROOT / GUARD_PATH).read_text()
    compiler = (ROOT / "compiler/typechecker.gst").read_text()
    old_names = activation[OLD]["control_fixtures"]
    take_names = ""
    if activation.get("call_cast_alias_take_return_zero_increment"):
        from phase26_call_cast_alias_take_return_registration import NAMES as TAKE_NAMES
        take_names = " " + " ".join("take_" + name for name in TAKE_NAMES)
    direct_move_names = ""
    if activation.get("call_cast_alias_direct_move_return_zero_increment"):
        from phase26_call_cast_alias_direct_move_return_registration import NAMES as DIRECT_MOVE_NAMES
        direct_move_names = " " + " ".join("direct_move_" + name for name in DIRECT_MOVE_NAMES)
    second_plain_names = ""
    if activation.get("call_cast_alias_second_plain_return_zero_increment"):
        from phase26_call_cast_alias_second_plain_return_registration import NAMES as SECOND_PLAIN_NAMES
        second_plain_names = " " + " ".join("second_plain_" + name for name in SECOND_PLAIN_NAMES)
    finite_plain_names = ""
    if activation.get("call_cast_alias_finite_plain_return_zero_increment"):
        from phase26_call_cast_alias_finite_plain_return_registration import NAMES as FINITE_PLAIN_NAMES
        finite_plain_names = " " + " ".join("finite_plain_" + name for name in FINITE_PLAIN_NAMES)
    third_cast_names = ""
    if activation.get("call_cast_alias_third_cast_return_zero_increment"):
        from phase26_call_cast_alias_third_cast_return_registration import NAMES as THIRD_CAST_NAMES
        third_cast_names = " " + " ".join("third_cast_" + name for name in THIRD_CAST_NAMES)
    second_cast_names = ""
    if activation.get("call_cast_alias_second_cast_return_zero_increment"):
        from phase26_call_cast_alias_second_cast_return_registration import NAMES as SECOND_CAST_NAMES
        second_cast_names = " " + " ".join("second_cast_" + name for name in SECOND_CAST_NAMES)
    require("for case_name in " + " ".join(
        Path(path).stem.removeprefix("phase26_call_local_return_cast_alias_").removesuffix("_source")
        for path in activation[OLD]["negative_fixtures"] + old_names) +
        " " + " ".join(NAMES) + take_names + second_plain_names + finite_plain_names + third_cast_names + second_cast_names + direct_move_names + "; do" in guard and
        ("zero|mayzero|depth3|second_alias|plain_suffix|direct_move_second_alias|return_cast|return_zero|return_depth3|return_take|return_take_cast|take_zero|take_mayzero" if activation.get(
            "call_cast_alias_second_plain_return_zero_increment") else
         "zero|mayzero|depth3|return_cast|return_zero|return_depth3|return_take|return_take_cast|take_zero|take_mayzero" if activation.get(
            "call_cast_alias_take_return_zero_increment") else
         "zero|mayzero|depth3|return_cast|return_zero|return_depth3)") in guard and
        ("return_wrong_type|take_wrong_type|direct_move_wrong_type)" if activation.get(
            "call_cast_alias_direct_move_return_zero_increment") else
         "return_wrong_type)") in guard and
        ("return_prior_escape|take_prior_escape|direct_move_prior_escape)" if activation.get(
            "call_cast_alias_direct_move_return_zero_increment") else
         "return_prior_escape|take_prior_escape)" if activation.get(
            "call_cast_alias_take_return_zero_increment") else
         "return_prior_escape)") in guard and
        ("return_prior_move|take_prior_move)" if activation.get(
            "call_cast_alias_take_return_zero_increment") else
         "return_prior_move)") in guard and
        'test ! -e "$marker"' in guard and
        "GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER" in guard and
        ("while alias_return.tag == 5 || alias_return.tag == 9" if activation.get(
            "call_cast_alias_take_return_zero_increment") else
         "while alias_return.tag == 9") in compiler and
        ("phase26_zero_resolved_expression_tag(next_idx, env, ctx) != 9" if activation.get(
            "call_cast_alias_take_return_zero_increment") else
         "phase26_zero_resolved_expression_tag(alias_return.AsCast.left, env, ctx) != 9") in compiler and
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
    frozen = activation[OLD]["phase22_invocation_successor"]["added_row"]
    normalized = [entry for entry in scan_invocations() if entry["path"] == GUARD_PATH]
    require(row["phase22_invocation_identity"] == {
        "raw_total": 29, "raw_last_row": frozen,
        "projected_total": 20,
        "projected_last_row": activation["call_outer_move_take_return_zero_increment"][
            "phase22_invocation_successor"]["previous_row"],
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(selected) == 29 and selected[-1] == frozen and
            len(normalized) == 20 and normalized[-1] == row[
                "phase22_invocation_identity"]["projected_last_row"],
            "raw or projected invocation identity drifted")
    from phase23_mir_to_c_deprecation_opening import SURFACE_PATTERNS, SELF_EXCLUSIONS, tracked_paths
    surface = row["phase23_text_surface_successor"]
    changed, added = surface.get("changed_rows", []), surface.get("added_rows", [])
    require(surface.get("contract_version") ==
            "phase26_1e_cast_alias_return_cast_phase23_text_successor_v1" and
            surface.get("partial_extra_or_substituted_surface") == "rejected" and
            [entry.get("path") for entry in changed] == TEXT_PATHS and
            len(added) == 1 and added[0].get("path") ==
            "scripts/phase26_call_cast_alias_return_cast_registration.py" and
            all(path in tracked_paths() and path not in SELF_EXCLUSIONS
                for path in TEXT_PATHS), "text surface shape drifted")
    for entry in changed:
        path = entry["path"]
        counts = {name: len(pattern.findall((ROOT / path).read_text()))
                  for name, pattern in SURFACE_PATTERNS.items()}
        current_digest = digest(path)
        if activation.get("call_cast_alias_take_return_zero_increment"):
            from phase26_call_cast_alias_take_return_registration import before_new_digest as before_take_return_digest, before_new_counts as before_take_return_counts
            current_digest = before_take_return_digest(activation, path, current_digest)
            counts = before_take_return_counts(activation, path, counts)
        require(entry == {"path": path,
                          "previous_digest": FROZEN_TEXT[path]["digest"],
                          "current_digest": current_digest,
                          "previous_match_counts": FROZEN_TEXT[path]["match_counts"],
                          "current_match_counts": counts},
                f"text surface drifted: {path}")
    path = added[0]["path"]
    counts = {name: len(pattern.findall((ROOT / path).read_text()))
              for name, pattern in SURFACE_PATTERNS.items()}
    added_digest = digest(path)
    if activation.get("call_cast_alias_take_return_zero_increment"):
        from phase26_call_cast_alias_take_return_registration import before_new_digest as before_take_return_digest, before_new_counts as before_take_return_counts
        added_digest = before_take_return_digest(activation, path, added_digest)
        counts = before_take_return_counts(activation, path, counts)
    require(added[0] == {
        "path": path, "digest": added_digest, "match_counts": counts,
        "classification": "archive_candidate", "owner": "cranelift",
        "current_route": "tracked_MIR_to_C_or_generated_C_surface",
        "deprecation_action": "map_to_live_lane_or_archive_in_23_10_and_23_11",
        "removal_phase": "24",
        "falsifier": "active_evidence_surface_is_missing_or_changes_identity",
    } and any(counts.values()), "added text surface drifted")
    print(f"{GUARD}: checked return-cast successor registration ok")


if __name__ == "__main__":
    main()
