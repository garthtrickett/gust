#!/usr/bin/env python3
"""Pin finite checked terminal raw casts after a finite cast and plain alias chain."""
from __future__ import annotations
import hashlib
import json
import subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
BASE = "34f00cd5d180d0d3b3790ff5471762e9599bb040"
KEY = "call_cast_alias_finite_cast_plain_terminal_cast_chain_return_zero_increment"
OLD = "call_cast_alias_finite_cast_plain_terminal_cast_return_zero_increment"
GUARD = "guard-cranelift-phase26-call-return-zero-evidence"
GUARD_PATH = "scripts/phase26_call_return_zero_evidence.sh"
POSITIVE = "compiler/phase26_call_return_zero_test_entry.gst"
CR15_PATH = "scripts/phase24_cr15_stdlib_guard_transition.py"
HELPER = "scripts/phase26_call_cast_alias_finite_cast_plain_terminal_cast_return_registration.py"
NEW_HELPER = "scripts/phase26_call_cast_alias_finite_cast_plain_terminal_cast_chain_return_registration.py"
APPROVED_TEXT_KEY = "approved_package_r1_phase23_text_surface_successor"
APPROVED_SPELLING_KEY = "approved_package_r1_spelling_inventory_successor"
APPROVED_RELAY_KEY = "approved_package_r1_cr15_relay_digest_successor"
TEXT_PATHS = ["compiler/typechecker.gst",
              "scripts/phase26_call_cast_alias_return_cast_registration.py",
              "scripts/phase26_call_cast_initialized_alias_return_registration.py",
              HELPER]
RECLASSIFIED = "compiler/phase26_call_local_return_cast_alias_finite_cast_plain_terminal_cast_stacked_source.gst"
NAMES = ('fifth_cast_third_plain_mayzero', 'one_plain_suffix', 'quadruple_mayzero', 'three_cast_prefix', 'triple_gap', 'triple_later_alias', 'triple_mayzero', 'triple_move_operand', 'triple_nonzero', 'triple_outer_move', 'triple_outer_take', 'triple_overwrite', 'triple_prior_move', 'triple_prior_escape', 'triple_scalar_operand', 'triple_scalar_target', 'triple_take_operand', 'triple_unknown', 'triple_unsafe', 'triple_wrong_brand', 'triple_wrong_brand_target', 'triple_wrong_type', 'triple_zero')

NEW_FIXTURES = [f"compiler/phase26_call_local_return_cast_alias_finite_cast_plain_terminal_chain_{name}_source.gst" for name in NAMES]
NEGATIVE_NAMES = ("fifth_cast_third_plain_mayzero", "quadruple_mayzero", "triple_mayzero", "triple_zero")
NEGATIVE = [RECLASSIFIED, *[f"compiler/phase26_call_local_return_cast_alias_finite_cast_plain_terminal_chain_{name}_source.gst" for name in NEGATIVE_NAMES]]

def require(ok: bool, reason: str) -> None:
    if not ok:
        raise SystemExit(f"{GUARD}: finite checked-cast plain terminal cast chain {reason}")


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def record(activation: dict) -> dict:
    return activation.get(KEY, {})


def before_approved_digest(activation: dict, path: str, live_digest: str) -> str:
    if activation.get("zlib_adapter_r3_successor"):
        from phase26_r3_zlib_adapter_registration import prior_digest
        live_digest = prior_digest({"phase26_activation_audit": activation}, path, live_digest)
    if activation.get("scoped_byte_copy_r2_successor"):
        from phase26_r2_scoped_copy_registration import normalize_relay, normalize_text
        if path == CR15_PATH:
            live_digest = normalize_relay({"phase26_activation_audit": activation}, live_digest)
        successor = activation["scoped_byte_copy_r2_successor"]["phase23_text_surface_successor"]
        matches = [entry for entry in successor["changed_rows"] if entry["path"] == path]
        require(len(matches) <= 1, f"duplicate R2 text path: {path}")
        if matches:
            require(matches[0]["current_digest"] == live_digest,
                    f"R2 text digest drifted: {path}")
            live_digest = matches[0]["previous_digest"]
    reference_relay = activation.get(
        "reference_index_element_r4_cr15_relay_digest_successor")
    if reference_relay is not None and path == CR15_PATH:
        require(reference_relay == {
            "path": CR15_PATH,
            "previous_digest": activation[APPROVED_RELAY_KEY]["current_digest"],
            "current_digest": live_digest,
            "partial_extra_or_substituted_relay": "rejected",
        }, "Reference index relay digest drifted")
        live_digest = reference_relay["previous_digest"]
    reference_index = activation.get(
        "reference_index_element_r4_phase23_text_surface_successor", {})
    matches = [entry for entry in reference_index.get("changed_rows", [])
               if entry.get("path") == path]
    require(len(matches) <= 1, f"duplicate Reference index text path: {path}")
    if matches:
        require(matches[0].get("current_digest") == live_digest,
                f"Reference index text digest drifted: {path}")
        live_digest = matches[0]["previous_digest"]
    relay = activation.get(APPROVED_RELAY_KEY)
    if relay is not None and path == CR15_PATH:
        require(relay == {
            "path": CR15_PATH,
            "previous_digest": activation[KEY]["cr15_relay_digest_successor"]["current_digest"],
            "current_digest": live_digest,
            "partial_extra_or_substituted_relay": "rejected",
        }, "approved-package relay digest drifted")
        return relay["previous_digest"]
    rows = activation.get(APPROVED_TEXT_KEY, {}).get("changed_rows", [])
    hits = [entry for entry in rows if entry.get("path") == path]
    require(len(hits) <= 1, f"duplicate approved-package text path: {path}")
    if not hits:
        return live_digest
    require(hits[0].get("current_digest") == live_digest,
            f"approved-package text digest drifted: {path}")
    return hits[0]["previous_digest"]


def prior_text(activation: dict, path: str) -> tuple[str, dict[str, int]]:
    from phase23_mir_to_c_deprecation_opening import SURFACE_PATTERNS
    spec = f"{BASE}:{path}"
    if subprocess.run(["git", "cat-file", "-e", spec], cwd=ROOT,
                      stderr=subprocess.DEVNULL).returncode != 0:
        subprocess.run(["git", "fetch", "--no-tags", "--depth=1", "origin", BASE],
                       cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
        fetched = subprocess.check_output(["git", "rev-parse", "FETCH_HEAD"],
                                          cwd=ROOT, text=True).strip()
        require(fetched == BASE, "pinned prior commit fetch drifted")
    committed = subprocess.check_output(
        ["git", "show", spec], cwd=ROOT)
    source = committed.decode()
    digest = hashlib.sha256(committed).hexdigest()
    counts = {name: len(pattern.findall(source))
              for name, pattern in SURFACE_PATTERNS.items()}
    old_surface = activation[OLD]["phase23_text_surface_successor"]
    rows = [*old_surface["changed_rows"], *old_surface["added_rows"]]
    hits = [row for row in rows if row["path"] == path]
    if hits:
        require(len(hits) == 1 and
                hits[0].get("current_digest", hits[0].get("digest")) == digest and
                hits[0].get("current_match_counts", hits[0].get("match_counts")) == counts,
                f"committed prior text identity drifted: {path}")
    return digest, counts


def before_new_digest(activation: dict, path: str, live_digest: str) -> str:
    live_digest = before_approved_digest(activation, path, live_digest)
    row = record(activation)
    for field in ("guard_digest_successor", "positive_fixture_successor",
                  "cr15_relay_digest_successor"):
        direct = row.get(field, {})
        if direct.get("path") == path:
            previous = activation[OLD][field]["current_digest"]
            require(direct.get("previous_digest") == previous and
                    direct.get("current_digest") == live_digest,
                    f"{field} exact digest drifted")
            return previous
    matches = [entry for entry in row.get("phase23_text_surface_successor", {})
               .get("changed_rows", []) if entry.get("path") == path]
    require(len(matches) <= 1, f"duplicate text path: {path}")
    if not matches:
        return live_digest
    previous, _ = prior_text(activation, path)
    require(matches[0].get("previous_digest") == previous and
            matches[0].get("current_digest") == live_digest,
            f"text digest drifted: {path}")
    return previous


def before_new_counts(activation: dict, path: str,
                      live_counts: dict[str, int]) -> dict[str, int]:
    matches = [entry for entry in record(activation)
               .get("phase23_text_surface_successor", {}).get("changed_rows", [])
               if entry.get("path") == path]
    require(len(matches) <= 1, f"duplicate text path: {path}")
    if not matches:
        return live_counts
    _, previous = prior_text(activation, path)
    require(matches[0].get("previous_match_counts") == previous and
            matches[0].get("current_match_counts") == live_counts,
            f"text counts drifted: {path}")
    return previous


def before_new_spelling(activation: dict, live: dict) -> dict:
    actual_live = live
    if activation.get("zlib_adapter_r3_successor"):
        from phase26_r3_zlib_adapter_registration import normalize_spelling
        live = normalize_spelling({"phase26_activation_audit": activation}, live)
    if activation.get("scoped_byte_copy_r2_successor"):
        from phase26_r2_scoped_copy_registration import normalize_spelling
        live = normalize_spelling({"phase26_activation_audit": activation}, live)
    reference_index = activation.get(
        "reference_index_element_r4_spelling_inventory_successor")
    if reference_index is not None:
        from phase24_semantic_spelling_inventory import source_sites
        from phase24_semantic_spelling_inventory import manifest_summary
        previous = activation[APPROVED_SPELLING_KEY]["current_inventory_summary"]
        source_paths = [
            "compiler/phase26_reference_index_element_mismatch.gst",
            "compiler/phase26_reference_index_element_source.gst",
            "compiler/typechecker.gst",
        ]
        from phase26_r2_scoped_copy_registration import prior_source_digest
        require(reference_index == {
            "contract_version":
                "phase26_1r4_reference_index_element_spelling_inventory_successor_v1",
            "previous_inventory_summary": previous,
            "current_inventory_summary": live,
            "changed_source_hashes": [
                {"path": path, "digest": prior_source_digest(
                    {"phase26_activation_audit": activation}, path)}
                for path in source_paths],
            "partial_extra_or_substituted_inventory": "rejected",
        } and actual_live == manifest_summary(source_sites()) and
                live["source_file_count"] == previous["source_file_count"] + 2 and
                live["site_count"] == previous["site_count"] and
                live["semantic_site_count"] == previous["semantic_site_count"] and
                live["classification_counts"] == previous["classification_counts"] and
                live["unknown_site_count"] == 0,
                "Reference index spelling inventory drifted")
        live = previous
    approved = activation.get(APPROVED_SPELLING_KEY)
    if approved is not None:
        from phase24_semantic_spelling_inventory import source_sites
        previous = record(activation)["spelling_inventory_successor"]["current_inventory_summary"]
        paths = ["compiler/experiments/cranelift/src/approved_package.rs",
                 "compiler/experiments/cranelift/src/full_program.rs",
                 "compiler/experiments/cranelift/src/main.rs"]
        from phase26_r2_scoped_copy_registration import prior_source_digest
        source_hashes = [{"path": path, "digest": prior_source_digest(
            {"phase26_activation_audit": activation}, path)} for path in paths]
        sites = [{"path": site["path"], "line": site["line"],
                  "classification": site["classification"],
                  "spellings": site["spellings"]}
                 for site in source_sites()
                 if site["path"] == paths[0] or
                 (site["path"] == paths[1] and site["line"] == 2339)]
        if activation.get("scoped_byte_copy_r2_successor"):
            from phase26_r2_scoped_copy_registration import preserved_predecessor_sites
            sites = preserved_predecessor_sites(
                {"phase26_activation_audit": activation}, approved["added_sites"],
                source_sites())
        require(approved == {
            "contract_version": "phase26_1r1_approved_package_spelling_successor_v1",
            "previous_inventory_summary": previous,
            "current_inventory_summary": live,
            "changed_source_hashes": source_hashes,
            "added_sites": sites,
            "partial_extra_or_substituted_inventory": "rejected",
        } and live["source_file_count"] == previous["source_file_count"] + 1 and
                live["site_count"] == previous["site_count"] + 11 and
                live["semantic_site_count"] == previous["semantic_site_count"] + 11 and
                len(sites) == 11 and all(site["classification"] ==
                    "semantic_or_intrinsic_recognition" for site in sites) and
                live["unknown_site_count"] == 0,
                "approved-package spelling inventory drifted")
        live = previous
    previous = activation[OLD]["spelling_inventory_successor"]["current_inventory_summary"]
    require(record(activation).get("spelling_inventory_successor") == {
        "contract_version": "phase26_1e_cast_alias_finite_cast_plain_terminal_cast_chain_return_spelling_successor_v1",
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
    actual_live = live
    if activation.get("scoped_byte_copy_r2_successor"):
        from phase26_r2_scoped_copy_registration import normalize_filename
        live = normalize_filename({"phase26_activation_audit": activation}, live)
    reference_index = activation.get(
        "reference_index_element_r4_filename_site_successor")
    if reference_index is not None:
        from phase24_filename_behavior_characterization import source_sites
        prior = activation[KEY]["filename_site_successor"]["current_sites"]
        require(reference_index == {
            "contract_version":
                "phase26_1r4_reference_index_element_filename_site_successor_v1",
            "previous_sites": prior,
            "current_sites": live,
            "line_deltas": [now["line"] - before["line"]
                            for before, now in zip(prior, live)],
            "partial_extra_or_substituted_site": "rejected",
        } and actual_live == source_sites() and len(prior) == len(live) == 3 and
                all({key: value for key, value in now.items() if key != "line"} ==
                    {key: value for key, value in before.items() if key != "line"}
                    for before, now in zip(prior, live)),
                "Reference index filename sites drifted")
        live = prior
    previous = activation[OLD]["filename_site_successor"]["current_sites"]
    require(record(activation).get("filename_site_successor") == {
        "contract_version": "phase26_1e_cast_alias_finite_cast_plain_terminal_cast_chain_return_filename_successor_v1",
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


def main() -> None:
    activation = json.loads((ROOT / 'scripts/cranelift_feature_registry.json').read_text())['phase26_activation_audit']
    row = record(activation)
    expected = {
        'contract_version': 'phase26_1e_cast_alias_finite_cast_plain_terminal_cast_chain_return_zero_v1',
        'status': 'bounded_finite_checked_terminal_raw_cast_chain_after_finite_cast_plain_aliases_qualified',
        'owner': 'cranelift',
        'increment': '26.1E_finite_checked_cast_finite_plain_aliases_finite_terminal_checked_raw_cast_chain',
        'operator_ownership_decision': '2026-10-12_coordinator_assigned_under_activated_phase26',
        'candidate_shape': 'immediate_same_block_concrete_nullary_raw_pointer_call_then_four_or_more_checked_raw_cast_initialized_aliases_then_two_or_more_adjacent_plain_by_value_raw_aliases_then_finite_two_or_more_individually_checked_raw_to_raw_AsCast_chain_of_terminal_Identifier_return',
        'safe_boundary': 'declared_nonextern_raw_pointer_return',
        'negative_states': ['Zero', 'MayZero'],
        'negative_fixtures': NEGATIVE,
        'control_fixtures': [path for path in NEW_FIXTURES if path not in NEGATIVE],
        'prior_error_precedence': 'preserved',
        'unknown_and_nonzero': 'preserved',
        'unsafe_functions': 'preserved',
        'one_plain_or_short_cast_prefix_take_move_operand_or_wrapper_later_alias_scalar_unproved_wrong_brand_cast_gap_overwrite_wider_flow': 'excluded_from_new_form',
        'take_move_resource_semantics_changed': False,
        'diagnostic': '[RawNullSafeBoundary]',
        'failure_stage': 'before_driver_discovery',
        'native_fallback': False,
        'mir_changed': False,
        'physical_abi_changed': False,
        'runtime_symbol_surface_changed': False,
        'general_nullability': 'open_separate_obligation',
        'phase26_1_closed': False,
        'owning_level2_guard': GUARD,
    }
    successors = {'guard_digest_successor', 'positive_fixture_successor',
                  'cr15_relay_digest_successor', 'reclassified_fixture_digests',
                  'spelling_inventory_successor', 'filename_site_successor',
                  'phase22_invocation_identity', 'phase23_text_surface_successor'}
    require({key: row.get(key) for key in expected} == expected and
            set(row) == set(expected) | successors,
            'contract or field set drifted')
    require(all((ROOT / path).is_file() for path in [RECLASSIFIED, *NEW_FIXTURES]),
            'closed fixture missing')
    require(row['reclassified_fixture_digests'] == [{
        'path': RECLASSIFIED, 'digest': digest(RECLASSIFIED),
        'previous_guard_classification': 'phase13_deferral_before_driver',
        'current_guard_classification': 'RawNullSafeBoundary_before_driver',
    }], 'genuine MayZero witness drifted')
    for field, path in (('guard_digest_successor', GUARD_PATH),
                        ('positive_fixture_successor', POSITIVE),
                        ('cr15_relay_digest_successor', CR15_PATH)):
        previous = activation[OLD][field]['current_digest']
        require(row[field] == {
            'path': path, 'previous_digest': previous,
            'current_digest': before_approved_digest(activation, path, digest(path)),
            'partial_extra_or_substituted_' +
            ('guard' if field.startswith('guard') else
             'fixture' if field.startswith('positive') else 'relay'): 'rejected',
        }, f'{field} drifted')
    guard = (ROOT / GUARD_PATH).read_text()
    compiler = (ROOT / 'compiler/typechecker.gst').read_text()
    require(' '.join('finite_cast_plain_terminal_chain_' + name for name in NAMES) in guard and
            'finite_cast_plain_terminal_chain_triple_mayzero' in guard and
            'finite_cast_plain_terminal_cast_stacked|finite_cast_plain_terminal_chain_triple_zero' in guard and
            'finite_cast_plain_terminal_chain_triple_wrong_type)' in guard and
            'finite_cast_plain_terminal_chain_triple_prior_move|finite_cast_plain_terminal_chain_triple_move_operand)' in guard and
            'finite_cast_plain_terminal_chain_triple_prior_escape)' in guard and
            'finite_cast_plain_terminal_chain_triple_wrong_brand_target)' in guard and
            'expected_failure_stage=before_driver_discovery' in guard and
            'GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER' in guard and
            'test ! -e "$marker"' in guard and
            'zero_local_call_finite_cast_plain_count: int' in compiler and
            '(*env).zero_local_call_finite_cast_plain_count >= 2 && expr.tag == 9' in compiler and
            'while cast_source.tag == 9 {' in compiler and
            'phase26_zero_resolved_expression_tag(cast_source.AsCast.left, env, ctx) != 9' in compiler and
            'if cast_source.tag != 0 { return 0; }' in compiler and
            'env_types_match_at_brand_boundary(env, source_type.Val, alias_type.Val, ctx) == 1' in compiler and
            'phase26_zero_local_call_alias_cast_is_raw(statements[i], env, ctx) == 1' in compiler and
            'if expr.tag == 4 { // One direct terminal Move' in compiler and
            'if moved_alias.tag != 0 { return 0; }' in compiler,
            'native or fail-closed evidence weakened')
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
                                    match.group('token'), selection(command)))
    selected = [entry for entry in raw if entry['path'] == GUARD_PATH]
    normalized = [entry for entry in scan_invocations() if entry['path'] == GUARD_PATH]
    prior = activation[OLD]['phase22_invocation_identity']
    require(row['phase22_invocation_identity'] == {
        'raw_total': len(selected), 'raw_last_row': selected[-1],
        'projected_total': len(normalized), 'projected_last_row': normalized[-1],
        'partial_extra_or_substituted_invocation': 'rejected',
    } and len(selected) == prior['raw_total'] and
            len(normalized) == prior['projected_total'] and
            selected[-1]['path'] == prior['raw_last_row']['path'] and
            normalized[-1]['path'] == prior['projected_last_row']['path'],
            'raw or projected invocation identity drifted')
    from phase23_mir_to_c_deprecation_opening import SURFACE_PATTERNS, SELF_EXCLUSIONS, tracked_paths
    surface = row['phase23_text_surface_successor']
    changed, added = surface.get('changed_rows', []), surface.get('added_rows', [])
    require(surface.get('contract_version') ==
            'phase26_1e_cast_alias_finite_cast_plain_terminal_cast_chain_return_phase23_text_successor_v1' and
            surface.get('partial_extra_or_substituted_surface') == 'rejected' and
            [entry.get('path') for entry in changed] == TEXT_PATHS and
            len(added) == 1 and added[0].get('path') == NEW_HELPER and
            all(path in tracked_paths() and path not in SELF_EXCLUSIONS
                for path in TEXT_PATHS), 'text surface shape drifted')
    for entry in changed:
        path = entry['path']
        counts = {name: len(pattern.findall((ROOT / path).read_text()))
                  for name, pattern in SURFACE_PATTERNS.items()}
        previous_digest, previous_counts = prior_text(activation, path)
        require(entry == {
            'path': path, 'previous_digest': previous_digest,
            'current_digest': before_approved_digest(activation, path, digest(path)),
            'previous_match_counts': previous_counts,
            'current_match_counts': counts,
        }, f'text surface drifted: {path}')
    counts = {name: len(pattern.findall((ROOT / NEW_HELPER).read_text()))
              for name, pattern in SURFACE_PATTERNS.items()}
    require(added[0] == {
        'path': NEW_HELPER, 'digest': before_approved_digest(activation, NEW_HELPER,
                                                          digest(NEW_HELPER)),
        'match_counts': counts, 'classification': 'archive_candidate',
        'owner': 'cranelift',
        'current_route': 'tracked_MIR_to_C_or_generated_C_surface',
        'deprecation_action': 'map_to_live_lane_or_archive_in_23_10_and_23_11',
        'removal_phase': '24',
        'falsifier': 'active_evidence_surface_is_missing_or_changes_identity',
    } and any(counts.values()), 'added text surface drifted')
    print(f'{GUARD}: finite checked-cast plain terminal cast chain registration ok')

if __name__ == '__main__':
    main()
