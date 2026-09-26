#!/usr/bin/env python3
"""Validate the selected native reference-argument prerequisite registration."""

import json
import hashlib
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
EXPECTED = {
    "contract_version": "phase26_reference_receiver_prerequisite_v1",
    "status": "selected_native_reference_argument_receiver_qualified",
    "owner": "cranelift",
    "separate_from_phase26_1d1": True,
    "capability_id": "phase13_generic_source_to_mir",
    "abi_authority": "phase16_direct_pointer_parameter_abi",
    "canonical_route": "full_program_source_to_mir_no_c_fallback",
    "supported_shape": "direct_call_reference_parameter_to_aggregate_or_collection",
    "positive_fixtures": [
        "tests/test_hashmap_reference_receiver.gst",
        "compiler/phase16_reference_receiver_source.gst",
        "compiler/phase16_string_clone_source.gst",
    ],
    "exact_native_output_guard": "scripts/phase16_reference_receiver_parity.sh",
    "owning_level2_guard": "guard-cranelift-phase13-parameter-argument-parity",
    "preserved_deferred_fixture":
        "compiler/phase13_parameter_argument_target_abi_source.gst",
    "preserved_reference_return_fixture":
        "compiler/phase16_reference_return_deferred_source.gst",
    "preserved_deferred_reason":
        "deferred_p13_parameter_argument_target_dependent_abi",
    "non_string_clone_negative_fixture":
        "compiler/phase16_non_string_clone_deferred_source.gst",
    "physical_abi_changed": False,
}
EXPECTED_INVOCATION = {
    "path": "scripts/phase16_reference_receiver_parity.sh",
    "line": 23,
    "recipe": "none",
    "compiler_token": "./gust",
    "selection": "explicit_cranelift",
    "consumer_class": "already_explicit_or_parser_probe",
    "owner": "cranelift",
    "expected_artifact": "selected_backend_contract",
    "expected_transition": "preserve_explicit_selection",
    "falsifier": "explicit_selection_is_removed_or_routes_to_a_different_backend",
    "command": (
        'GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" '
        './gust --backend cranelift -o "$case_dir/program" "$source" '
        '>"$case_dir/compile.stdout" 2>"$case_dir/compile.stderr"'
    ),
}


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"reference receiver registration: {message}")


def main() -> None:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    activation = registry.get("phase26_activation_audit", {})
    require(activation.get("status") == "phase26_activation_audit_registered",
            "Phase 26 activation is not registered")
    expected_record = dict(EXPECTED)
    expected_record["phase22_invocation_successor"] = {
        "contract_version":
            "phase26_reference_receiver_phase22_invocation_successor_v1",
        "previous_total": 150,
        "current_total": 151,
        "added_row": EXPECTED_INVOCATION,
        "partial_extra_or_substituted_invocation": "rejected",
    }
    expected_record["production_audit_successor"] = {
        "contract_version":
            "phase26_reference_receiver_production_audit_successor_v1",
        "previous_repository_invocation_count": 150,
        "current_repository_invocation_count": 151,
        "added_invocation_path": "scripts/phase16_reference_receiver_parity.sh",
        "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }
    expected_record["phase21_complete_suite_successor"] = {
        "contract_version": "phase26_reference_receiver_phase21_successor_v1",
        "status": "exact_reference_parameter_admission_overlay",
        "admitted_runner_fixtures": [
            "tests/test_safe_references_comprehensive_accepted.gst",
        ],
        "newly_deferred_runner_fixture": "tests/e2e_adt_pressure_test.gst",
        "unresolved_member_runner_fixture":
            "tests/test_reference_access_parsing_accepted.gst",
        "previous_reason": EXPECTED["preserved_deferred_reason"],
        "current_reason": "deferred_p13_parameter_argument_aggregate_return",
        "unresolved_member_reason":
            "deferred_p14_full_program_unresolved_member_call",
        "required_native_case_delta": 1,
        "classified_deferral_delta": -1,
        "reason_count_deltas": {
            "deferred_p13_parameter_argument_target_dependent_abi": -3,
            "deferred_p13_parameter_argument_aggregate_return": 1,
            "deferred_p14_full_program_unresolved_member_call": 1,
        },
        "frozen_phase21_record": "unchanged",
        "partial_extra_or_substituted_transition": "rejected",
    }
    expected_record["phase19_non_string_clone_successor"] = {
        "contract_version":
            "phase26_reference_receiver_phase19_non_string_clone_successor_v1",
        "source_fixture": "compiler/phase19_cross_feature_composition_source.gst",
        "independent_negative_fixture":
            EXPECTED["non_string_clone_negative_fixture"],
        "supported_string_fixture": "compiler/phase16_string_clone_source.gst",
        "previous_reason": EXPECTED["preserved_deferred_reason"],
        "current_reason": "deferred_p14_full_program_non_string_clone",
        "failure_stage": "before_driver_discovery",
        "frozen_exit_status": 91,
        "no_c_fallback_or_native_artifact": True,
        "partial_extra_or_substituted_transition": "rejected",
    }
    expected_record["phase20_non_string_clone_successor"] = {
        "contract_version":
            "phase26_reference_receiver_phase20_non_string_clone_successor_v1",
        "source_fixture": "compiler/phase20_exact_brand_boundary_source.gst",
        "owning_level2_guard":
            "guard-cranelift-phase20-exact-brand-boundary-parity",
        "frozen_mir_to_c_exit_status": 23,
        "canonical_mir_native_exit_status": 23,
        "previous_direct_route": "native_full_program_success",
        "current_direct_reason": "deferred_p14_full_program_non_string_clone",
        "failure_stage": "before_driver_discovery",
        "no_c_fallback_or_native_artifact": True,
        "frozen_phase20_record": "unchanged",
        "partial_extra_or_substituted_transition": "rejected",
    }
    filename_record = registry["phase24_filename_behavior_characterization"]
    expected_record["phase24_filename_successor"] = {
        "contract_version":
            "phase26_reference_receiver_phase24_filename_successor_v1",
        "witness_id": "tcs_guard",
        "side": "neutral",
        "previous_reason": EXPECTED["preserved_deferred_reason"],
        "current_reason": "deferred_p13_parameter_argument_aggregate_parameter",
        "previous_observation": filename_record["observations"]["tcs_guard"][
            "explicit_cranelift"]["neutral"],
        "current_observation": {
            "exit_status": 1,
            "stdout_bytes": 673,
            "stdout_digest":
                "f8db6e11f2c96b59735293f34b844cd27c1425c9e55db3ccd7b6fb8cbcdfbd0d",
            "stderr_bytes": 0,
            "stderr_digest": hashlib.sha256(b"").hexdigest(),
            "native_artifact_present": False,
        },
        "selected_observation_unchanged": True,
        "explicit_default_equal": True,
        "partial_extra_or_substituted_observation": "rejected",
    }
    prior_spelling = registry["phase2512b_runtime_c_retirement"][
        "spelling_inventory_transition"]["current_inventory_summary"]
    expected_record["spelling_inventory_successor"] = {
        "contract_version":
            "phase26_reference_receiver_spelling_inventory_successor_v1",
        "predecessor_complete_manifest_digest":
            "00639edc0517ccfc685b57ce856dd1531de69ea85faccf0cc9d91984f02c8a61",
        "predecessor_inventory_summary": prior_spelling,
        "changed_source_paths": [
            "compiler/experiments/cranelift/src/full_program.rs",
            "compiler/mir_native_backend_full_program_source.gst",
            "compiler/phase16_reference_receiver_source.gst",
            "compiler/phase16_reference_return_deferred_source.gst",
            "compiler/phase16_string_clone_source.gst",
            "compiler/phase16_non_string_clone_deferred_source.gst",
        ],
        "current_inventory_summary": {
            "classification_counts": {
                "comment": 2,
                "diagnostic": 10,
                "fixture_or_evidence": 679,
                "mangling_or_generated_name": 9,
                "non_decision_comparison": 8,
                "semantic_or_intrinsic_recognition": 683,
                "serialization": 1,
            },
            "complete_manifest_digest":
                "bd95861f3a2cd704f21ba7a3e187dcd118496020ce3038ca106487ebd3c4d63c",
            "partition_manifest_digests": {
                "comment":
                    "6c84ac779c82fc6ae5bfb653f34848965cd2d8445e827340d845cfe95208f1db",
                "diagnostic":
                    "6e82e2d2913cca3a5f24a7afa698738a3e8d23445820c6565a167ede70e2600a",
                "fixture_or_evidence":
                    "3395286d25f0394871f098da9a3d260cb4745ab3c4fa9da7aa6cc68b1b72dbe5",
                "mangling_or_generated_name":
                    "f2c6d856ed3923254cbc9e167320d3409a49579ff300db521a0b7516c7d7f4b2",
                "non_decision_comparison":
                    "87541c86aeaad80e96afc79c7c74d7dad8aa745acfdeb6a78f0bc2c16b65a0b7",
                "serialization":
                    "cd26d44606f736374209054c0fc91d72f950946ad84fad1a5e6efb6c7fc4f5b9",
            },
            "semantic_manifest_digest":
                "15a481959ef250b65239a316386832af8269e19efefb54ad3d3132b42495d1b7",
            "semantic_site_count": 683,
            "site_count": 1392,
            "source_file_count": 1083,
            "unknown_site_count": 0,
        },
        "partial_extra_or_substituted_inventory": "rejected",
    }
    expected_record["phase23_text_surface_successor"] = {
        "contract_version":
            "phase26_reference_receiver_phase23_text_surface_successor_v1",
        "phase23_closure_path": "scripts/phase23_closure.py",
        "previous_phase23_closure_digest":
            "34cbe395e69c7453b837feb9d674fcbed701ba8be21230fea0782a7cb3cb3cb0",
        "current_phase23_closure_digest": digest("scripts/phase23_closure.py"),
        "full_program_path":
            "compiler/experiments/cranelift/src/full_program.rs",
        "previous_full_program_digest":
            "8ac856fe6b96297898870e9339e9c9855368333a7d9825156d13e77a7c0d6417",
        "current_full_program_digest":
            "76d799b16eecac358c5539de53b97548e5a45eb6d7e4cb49bd1ca188d9ae37c6",
        "phase22_path": "scripts/phase22_opening.py",
        "previous_phase22_digest":
            "0d3a7f856253c711be186d2fc0aad9a49983ef64c194ee3b2da88233d39e160e",
        "current_phase22_digest": digest("scripts/phase22_opening.py"),
        "phase13_path": "scripts/phase13_parameter_argument.sh",
        "previous_phase13_digest":
            "e14cbe70afac5d4691c9af5eba1b2a61fc48de8d2162fe8f3df60a8810692cd0",
        "current_phase13_digest":
            "9991aa3731782994a9384f951b741419256bb6827d2f201bec1587ac6dd29048",
        "added_row": {
            "path": "scripts/phase26_reference_receiver_registration.py",
            "digest":
                "b7fe3829188e9b9db736aeaee22d88649ebab1ba958fbc3ddfbaa434fec0f0c2",
            "match_counts": {
                "explicit_backend_spelling": 1,
                "mir_to_c_name": 4,
                "generated_c_contract": 1,
            },
            "classification": "archive_candidate",
            "owner": "cranelift",
            "current_route": "tracked_MIR_to_C_or_generated_C_surface",
            "deprecation_action": "map_to_live_lane_or_archive_in_23_10_and_23_11",
            "removal_phase": "24",
            "falsifier": "active_evidence_surface_is_missing_or_changes_identity",
        },
        "partial_extra_or_substituted_surface": "rejected",
    }
    corrective_surfaces = [
        ("compiler/CRANELIFT_PHASE19_COMPOSITION.md",
         "9ca17624f319898c5b6240906d43ef4d0b34f829987b150a0b332e097b28cb5f",
         (0, 1, 0), (0, 1, 0)),
        ("compiler/mir_native_backend_full_program_source.gst",
         "ad4b9607f51592b7f0e82217ab3999ef83cb953355bf510d597fba8f2d529f8a",
         (0, 0, 1), (0, 0, 1)),
        ("scripts/phase19_composition.py",
         "a8b456eadbed5438ca792650540a9658530f4b041dac398d0385a9c5fdc4e14a",
         (0, 2, 0), (0, 2, 0)),
        ("scripts/phase19_composition_parity.sh",
         "0e4384ff31a6352bf93bcb463fed0904d8c93d63ee559cd88e446b5b58cbdc1c",
         (0, 8, 1), (0, 6, 1)),
        ("scripts/phase20_exact_brand_boundary.sh",
         "44c60de9d556605a47ac2283decd593833454ff5643cf9fa41795057e52a0ba9",
         (0, 7, 0), (0, 5, 0)),
        ("scripts/phase21_complete_guard_suite.py",
         "ac65da6e651480e044e24f008644e7c5f993a71c523ab6356d1f7107be36ea8b",
         (0, 2, 0), (0, 2, 0)),
    ]
    count_names = ("explicit_backend_spelling", "mir_to_c_name",
                   "generated_c_contract")
    expected_record["phase23_text_surface_successor"][
        "corrective_changed_rows"] = [{
            "path": path,
            "previous_digest": previous_digest,
            "current_digest": (
                "540c07e65ab191288e78f4bf7354f7fbd2ffb8fcf0e036ced81a96e927d80c5d"
                if path == "compiler/mir_native_backend_full_program_source.gst"
                else "576aff2b010f713b76bd098443047365cc897066a9ca96f45a19c5e42b421d8b"
                if path == "scripts/phase21_complete_guard_suite.py"
                else digest(path)
            ),
            "previous_match_counts": dict(zip(count_names, previous_counts)),
            "current_match_counts": dict(zip(count_names, current_counts)),
        } for path, previous_digest, previous_counts, current_counts
        in corrective_surfaces]
    require(activation.get("reference_receiver_prerequisite") == expected_record,
            "selected reference receiver prerequisite record drifted")
    runtime = activation.get("runtime_formal_signature_prerequisite", {})
    runtime_base = {
        "contract_version": "phase26_runtime_formal_signature_prerequisite_v1",
        "status": "canonical_runtime_formal_scalar_calls_qualified",
        "owner": "cranelift",
        "separate_from_phase26_1d1_and_str_abi": True,
        "canonical_signature_source": "typechecker_function_registry",
        "physical_abi_changed": False,
        "positive_fixture": "compiler/phase26_runtime_formal_signature_source.gst",
        "wrong_type_fixture":
            "compiler/phase26_runtime_formal_signature_wrong_type_source.gst",
        "exact_native_output": "1\n65\n1\n",
        "owning_level2_guard": "guard-cranelift-phase13-parameter-argument-parity",
        "new_compiler_invocation_sites": 0,
    }
    require({key: runtime.get(key) for key in runtime_base} == runtime_base and
            set(runtime) == set(runtime_base) | {
                "phase21_complete_suite_successor", "text_surface_successor",
                "spelling_inventory_successor"},
            "runtime formal signature prerequisite base drifted")
    require(runtime["phase21_complete_suite_successor"] == {
        "contract_version": "phase26_runtime_formal_phase21_successor_v1",
        "status": "exact_runtime_formal_scalar_admission_overlay",
        "admitted_runner_fixture":
            "compiler/typechecker_origins_test_entry.gst",
        "required_output_substring":
            "get_type_brand nested pointer lookup OK",
        "previous_reason":
            "deferred_p14_full_program_inconsistent_runtime_signature",
        "required_native_case_delta": 1,
        "classified_deferral_delta": -1,
        "reason_count_deltas": {
            "deferred_p14_full_program_inconsistent_runtime_signature": -1,
        },
        "frozen_phase21_record": "unchanged",
        "partial_extra_or_substituted_transition": "rejected",
    }, "runtime formal Phase 21 exact successor drifted")
    runtime_surfaces = runtime["text_surface_successor"]
    required_runtime_paths = {
        "compiler/experiments/cranelift/src/full_program.rs",
        "compiler/mir_native_backend_full_program_source.gst",
        "scripts/phase13_parameter_argument.sh",
        "scripts/phase21_complete_guard_suite.py",
        "scripts/phase26_reference_receiver_registration.py",
    }
    runtime_rows = runtime_surfaces.get("changed_rows", [])
    require(runtime_surfaces.get("contract_version") ==
            "phase26_runtime_formal_signature_text_surface_successor_v1" and
            runtime_surfaces.get("partial_extra_or_substituted_surface") ==
            "rejected" and
            {row.get("path") for row in runtime_rows} ==
            required_runtime_paths and
            len(runtime_rows) == len(required_runtime_paths),
            "runtime formal signature text surface paths drifted")
    str_direct = activation.get("str_direct_call_prerequisite", {})
    str_base = {
        "contract_version": "phase26_str_direct_call_prerequisite_v1",
        "status": "canonical_local_str_parameter_and_return_qualified",
        "owner": "cranelift",
        "separate_from_phase26_1d1": True,
        "physical_abi_changed": False,
        "canonical_layout": "existing_str_view",
        "qualified_positions": ["direct_parameter", "direct_return"],
        "positive_fixture": "compiler/phase26_str_direct_call_source.gst",
        "extern_deferred_fixture":
            "compiler/phase26_str_extern_deferred_source.gst",
        "extern_deferred_reason":
            "deferred_p13_parameter_argument_target_dependent_abi",
        "exact_native_output": "11\ndirect return\ncloned return\n",
        "unchanged_stdlib_guard": "guard-stdlib-s1-str-surface",
        "owning_level2_guard": "guard-cranelift-phase13-parameter-argument-parity",
        "new_compiler_invocation_sites": 0,
    }
    require({key: str_direct.get(key) for key in str_base} == str_base and
            set(str_direct) == set(str_base) | {
                "phase21_complete_suite_successor",
                "spelling_inventory_successor", "text_surface_successor"},
            "Str direct-call prerequisite base drifted")
    require(str_direct["phase21_complete_suite_successor"] == {
        "contract_version": "phase26_str_direct_phase21_successor_v1",
        "status": "exact_runtime_slice_return_deferral_overlay",
        "admitted_runner_fixtures": [
            "tests/test_return_parameter_view_accepted.gst",
            "tests/test_return_static_literal_view_accepted.gst",
            "tests/test_brand_erasure_utility_functions.gst",
            "tests/e2e_codegen_assertions.gst",
        ],
        "runner_fixture": "tests/e2e_fallible_guard_bootstrap.gst",
        "previous_reason":
            "deferred_p13_parameter_argument_target_dependent_abi",
        "current_reason": "deferred_p14_full_program_runtime_slice_return",
        "required_native_case_delta": 4,
        "classified_deferral_delta": -4,
        "reason_count_deltas": {
            "deferred_p13_parameter_argument_target_dependent_abi": -5,
            "deferred_p14_full_program_runtime_slice_return": 1,
        },
        "frozen_phase21_record": "unchanged",
        "partial_extra_or_substituted_transition": "rejected",
    }, "Str direct-call Phase21 successor drifted")
    str_surfaces = str_direct["text_surface_successor"]
    str_rows = str_surfaces.get("changed_rows", [])
    required_str_paths = {
        "compiler/mir_native_backend_full_program_source.gst",
        "scripts/phase13_parameter_argument.sh",
        "scripts/phase21_complete_guard_suite.py",
        "scripts/phase26_reference_receiver_registration.py",
    }
    require(str_surfaces.get("contract_version") ==
            "phase26_str_direct_call_text_surface_successor_v1" and
            str_surfaces.get("partial_extra_or_substituted_surface") ==
            "rejected" and
            {row.get("path") for row in str_rows} == required_str_paths and
            len(str_rows) == len(required_str_paths),
            "Str direct-call text surface paths drifted")
    str_by_path = {row["path"]: row for row in str_rows}
    runtime_by_path = {row["path"]: row for row in runtime_rows}
    for row in runtime_rows:
        require(set(row) == {"path", "previous_digest", "current_digest",
                             "previous_match_counts", "current_match_counts"} and
                row["current_digest"] == (
                    str_by_path[row["path"]]["previous_digest"]
                    if row["path"] in str_by_path else digest(row["path"])) and
                len(row["previous_digest"]) == 64 and
                set(row["previous_match_counts"]) ==
                {"explicit_backend_spelling", "mir_to_c_name", "generated_c_contract"} and
                set(row["current_match_counts"]) ==
                set(row["previous_match_counts"]),
                f"runtime formal signature text surface drifted: {row['path']}")
    for row in str_rows:
        predecessor = runtime_by_path[row["path"]]
        require(set(row) == {"path", "previous_digest", "current_digest",
                             "previous_match_counts", "current_match_counts"} and
                row["previous_digest"] == predecessor["current_digest"] and
                row["previous_match_counts"] ==
                predecessor["current_match_counts"] and
                row["current_digest"] == digest(row["path"]) and
                row["current_match_counts"] ==
                row["previous_match_counts"],
                f"Str direct-call text surface drifted: {row['path']}")
    for path in (str_base["positive_fixture"],
                 str_base["extern_deferred_fixture"],
                 "compiler/phase26_runtime_slice_return_deferred_source.gst"):
        require((ROOT / path).is_file(), f"missing Str direct-call fixture: {path}")
    phase16_guard = (ROOT / "scripts/phase16_reference_receiver_parity.sh").read_text(
        encoding="utf-8")
    phase13_guard = (ROOT / "scripts/phase13_parameter_argument.sh").read_text(
        encoding="utf-8")
    require("compiler/phase26_str_direct_call_source.gst str-direct-call" in
            phase16_guard and
            "compiler/phase26_str_extern_deferred_source.gst str-extern-abi" in
            phase13_guard and
            "compiler/phase26_runtime_slice_return_deferred_source.gst" in
            phase13_guard and
            "deferred_p14_full_program_runtime_slice_return deferred" in
            phase13_guard and
            "just guard-stdlib-s1-str-surface" in phase13_guard,
            "Str direct-call native or no-fallback guard is not executed")
    for path in (*EXPECTED["positive_fixtures"],
                 EXPECTED["preserved_deferred_fixture"],
                 EXPECTED["preserved_reference_return_fixture"],
                 EXPECTED["non_string_clone_negative_fixture"],
                 expected_record["phase21_complete_suite_successor"][
                     "unresolved_member_runner_fixture"],
                 EXPECTED["exact_native_output_guard"]):
        require((ROOT / path).is_file(), f"missing registered input {path}")

    phase13_guard = (ROOT / "scripts/phase13_parameter_argument.sh").read_text(
        encoding="utf-8")
    require('bash "$reference_receiver_guard" "$build_root/reference-receiver"'
            in phase13_guard, "Level 2 owner does not execute native evidence")
    require("assert_preserved_pre_driver_failure" in phase13_guard and
            '"$target_abi_source" target-dependent-abi' in phase13_guard,
            "target-dependent ABI negative is no longer executed")
    require('"$reference_return_source" reference-return-abi' in phase13_guard,
            "Reference return ABI negative is no longer executed")
    require(EXPECTED["preserved_deferred_reason"] in phase13_guard,
            "registered negative reason is no longer asserted")
    require('"$unresolved_member_source" unresolved-member-call' in
            phase13_guard and
            expected_record["phase21_complete_suite_successor"][
                "unresolved_member_reason"] in phase13_guard,
            "unresolved member call negative is no longer executed")
    native_guard = (ROOT / EXPECTED["exact_native_output_guard"]).read_text(
        encoding="utf-8")
    require("python3 scripts/phase26_reference_receiver_registration.py"
            in native_guard, "Level 2 evidence does not validate its registration")
    require("--backend cranelift" in native_guard and
            "GUST_TEST_MIR_TO_C_UNAVAILABLE=1" in native_guard,
            "reference receiver evidence lacks native-only selection")
    require("--backend mir-to-c" not in native_guard,
            "reference receiver evidence revived C execution")
    require(EXPECTED["positive_fixtures"][-1] in native_guard,
            "native Str Clone positive is not executed")
    require(runtime["positive_fixture"] in native_guard and
            "runtime-formal-signature" in native_guard and
            "1\\n65\\n1\\n" in native_guard and
            runtime["wrong_type_fixture"] in phase13_guard and
            "runtime-formal-wrong-type" in phase13_guard and
            "source_or_type_failure" in phase13_guard,
            "native runtime formal positive or fail-closed negative is not executed")
    phase19_guard = (ROOT / "scripts/phase19_composition_parity.sh").read_text(
        encoding="utf-8")
    require(EXPECTED["non_string_clone_negative_fixture"] in phase19_guard and
            expected_record["phase19_non_string_clone_successor"][
                "current_reason"] in phase19_guard and
            "GUST_TEST_MIR_TO_C_UNAVAILABLE=1" in phase19_guard,
            "Phase 19 no-fallback non-string Clone negative is not executed")
    phase20_guard = (ROOT / "scripts/phase20_exact_brand_boundary.sh").read_text(
        encoding="utf-8")
    require(expected_record["phase20_non_string_clone_successor"][
                "current_direct_reason"] in phase20_guard and
            "GUST_TEST_MIR_TO_C_UNAVAILABLE=1" in phase20_guard and
            'test ! -e "$poison_marker"' in phase20_guard and
            'test ! -e "$build_root/direct-native"' in phase20_guard,
            "Phase 20 branded Index Clone deferral is not pinned")
    print("✅ Selected native reference receiver prerequisite registration passed.")


if __name__ == "__main__":
    main()
