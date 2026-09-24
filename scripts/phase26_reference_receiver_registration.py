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
    ],
    "exact_native_output_guard": "scripts/phase16_reference_receiver_parity.sh",
    "owning_level2_guard": "guard-cranelift-phase13-parameter-argument-parity",
    "preserved_deferred_fixture":
        "compiler/phase13_parameter_argument_target_abi_source.gst",
    "preserved_reference_return_fixture":
        "compiler/phase16_reference_return_deferred_source.gst",
    "preserved_deferred_reason":
        "deferred_p13_parameter_argument_target_dependent_abi",
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
            "compiler/phase16_reference_receiver_source.gst",
            "compiler/phase16_reference_return_deferred_source.gst",
        ],
        "current_inventory_summary": {
            "classification_counts": {
                "comment": 2,
                "diagnostic": 10,
                "fixture_or_evidence": 679,
                "mangling_or_generated_name": 9,
                "non_decision_comparison": 8,
                "semantic_or_intrinsic_recognition": 680,
                "serialization": 1,
            },
            "complete_manifest_digest":
                "6877d13f26af53ba1c73f860b8ce3a41ad875b8e617d1cccd50b5e9e6362150c",
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
                "04c1076acb211d9d31f7c50c55ed880848e94ad4406b27f43c1fabcdc919b582",
            "semantic_site_count": 680,
            "site_count": 1389,
            "source_file_count": 1081,
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
            digest("compiler/experiments/cranelift/src/full_program.rs"),
        "phase22_path": "scripts/phase22_opening.py",
        "previous_phase22_digest":
            "0d3a7f856253c711be186d2fc0aad9a49983ef64c194ee3b2da88233d39e160e",
        "current_phase22_digest": digest("scripts/phase22_opening.py"),
        "phase13_path": "scripts/phase13_parameter_argument.sh",
        "previous_phase13_digest":
            "e14cbe70afac5d4691c9af5eba1b2a61fc48de8d2162fe8f3df60a8810692cd0",
        "current_phase13_digest": digest("scripts/phase13_parameter_argument.sh"),
        "added_row": {
            "path": "scripts/phase26_reference_receiver_registration.py",
            "digest": digest("scripts/phase26_reference_receiver_registration.py"),
            "match_counts": {
                "explicit_backend_spelling": 1,
                "mir_to_c_name": 2,
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
    require(activation.get("reference_receiver_prerequisite") == expected_record,
            "selected reference receiver prerequisite record drifted")
    for path in (*EXPECTED["positive_fixtures"],
                 EXPECTED["preserved_deferred_fixture"],
                 EXPECTED["preserved_reference_return_fixture"],
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
    native_guard = (ROOT / EXPECTED["exact_native_output_guard"]).read_text(
        encoding="utf-8")
    require("python3 scripts/phase26_reference_receiver_registration.py"
            in native_guard, "Level 2 evidence does not validate its registration")
    require("--backend cranelift" in native_guard and
            "GUST_TEST_MIR_TO_C_UNAVAILABLE=1" in native_guard,
            "reference receiver evidence lacks native-only selection")
    require("--backend mir-to-c" not in native_guard,
            "reference receiver evidence revived C execution")
    print("✅ Selected native reference receiver prerequisite registration passed.")


if __name__ == "__main__":
    main()
