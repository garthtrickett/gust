#!/usr/bin/env python3
"""Validate the exact pre/post Stdlib CR-15 prerequisite-guard transition."""

from __future__ import annotations

import argparse
import collections
import copy
import re
import hashlib
import importlib.util
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE24_CR15_STDLIB_GUARD_TRANSITION.md"
JUSTFILE = ROOT / "justfile"
TASK = ROOT / "TASK.md"
LAUNCH_GATE = ROOT / "docs/CRANELIFT_LAUNCH.md"
GUARD = "guard-cranelift-phase24-cr15-stdlib-guard-transition"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def digest_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def authority(registry: dict | None = None) -> dict:
    if registry is None:
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    opening = registry.get("phase24_cr15_opening", {})
    value = opening.get("stdlib_guard_transition")
    require(isinstance(value, dict), "transition authority is missing")
    return value


def s1_8_successor(value: dict) -> dict:
    successor = value.get("s1_8_inventory_successor")
    require(isinstance(successor, dict), "S1.8 inventory successor is missing")
    require(
        successor.get("contract_version") ==
        "phase24_stdlib_s1_8_inventory_successor_v1" and
        successor.get("status") ==
        "ready_for_exact_stdlib_s1_8_publication" and
        successor.get("authority_base_main") ==
        "9d065b4b395b604b6c285a32f0ef23b71528e159" and
        successor.get("candidate_base_main") ==
        "3abae7a96111b15e27e295a81f15b7f97a2e372c" and
        successor.get("changed_paths") == sorted(successor.get("changed_paths", [])) and
        len(successor.get("changed_paths", [])) == 9 and
        len(set(successor.get("changed_paths", []))) == 9 and
        successor.get("boundary") == {
            "changes_accepted_Gust_program_meaning": False,
            "adds_or_changes_MIR_operations": False,
            "changes_ABI_layout_runtime_symbols": False,
            "changes_backend_route_default_or_fallback": False,
            "changes_bootstrap_route_or_seed": False,
            "edits_stdlib_candidate": False,
            "begins_patch24_2_or_24_3": False,
        },
        "S1.8 inventory successor identity or boundary drifted")
    states = successor.get("accepted_states", [])
    require([row.get("state") for row in states] ==
            ["pre_s1_8", "post_s1_8"],
            "S1.8 accepted state order drifted")
    for state in states:
        files = state.get("files", [])
        require([row.get("path") for row in files] == successor["changed_paths"],
                f"S1.8 {state.get('state')} path manifest drifted")
        require(all(("digest" in row) != ("absent" in row) for row in files),
                f"S1.8 {state.get('state')} file identity is ambiguous")
    require(all(row.get("absent") is True for row in states[0]["files"]
                if "absent" in row) and
            all(len(row.get("digest", "")) == 64 for state in states
                for row in state["files"] if "digest" in row),
            "S1.8 accepted file identity drifted")
    raw = successor.get("raw_mutex_call_site_transition", {})
    require(raw == {
        "previous_totals": {"lock_calls": 16, "unlock_calls": 16, "calls": 32},
        "added_call_site": {
            "path": "tests/stdlib_s1_mutex_guard_generic_derivation_module.gst",
            "role": "stdlib_s1_8_selected_module_internal_lifecycle",
            "lock_calls": 1,
            "unlock_calls": 1,
        },
        "current_totals": {"lock_calls": 17, "unlock_calls": 17, "calls": 34},
        "safe_raw_calls_added": 0,
        "partial_extra_or_substituted_call_site": "rejected",
    }, "S1.8 raw Mutex transition drifted")
    invocation = successor.get("phase22_invocation_transition", {})
    require(invocation == {
        "path": "justfile",
        "recipe": "guard-stdlib-s1-resource-prerequisites",
        "compiler_token": "./gust",
        "selection": "explicit_c",
        "command": 'if ./gust --backend mir-to-c "$witness" >"$output" 2>&1; then',
        "pre_line": 23270,
        "post_line": 23285,
        "summary_unchanged": True,
        "partial_extra_or_substituted_invocation": "rejected",
    }, "S1.8 Phase 22 invocation transition drifted")
    text = successor.get("phase23_text_surface_transition", {})
    paths = text.get("changed_paths", [])
    require(paths == [
        "TASK_STDLIB.md", "docs/STDLIB_FOUNDATIONS.md",
        "docs/STDLIB_SURFACE_FINDINGS.md", "justfile",
    ] and
            [row.get("path") for row in text.get("previous_rows", [])] == paths and
            [row.get("path") for row in text.get("current_rows", [])] == paths and
            text.get("closed_phase_projection") ==
            "canonical_pre_s1_8_identity" and
            text.get("partial_extra_or_substituted_surface") == "rejected",
            "S1.8 Phase 23 text-surface transition drifted")
    return successor


def s1_8_coordination_successor(registry: dict, successor: dict) -> dict:
    coordination = registry.get("phase24_s1_8_authority_successor")
    require(isinstance(coordination, dict),
            "S1.8 coordination successor is missing")
    require(
        coordination.get("contract_version") ==
        "phase24_s1_8_authority_successor_v1" and
        coordination.get("status") == "ready_for_exact_stdlib_s1_8_rebase" and
        coordination.get("authority_base_main") ==
        "148a7715e7a3f22e30e361750d2e49a443ce5c42" and
        coordination.get("owning_stdlib_pull_request") == 314 and
        coordination.get("owning_stdlib_exact_head_sha") ==
        "96a51a20dd4071ad63ead144cdb11ce4da3834a6" and
        coordination.get("changed_paths") == successor["changed_paths"] and
        coordination.get("inherited_inventory_contract") ==
        successor["contract_version"] and
        coordination.get("justfile_state_digests") == {
            "pre_s1_8":
            "74bea653752ec6b7432c0df3613a2e3b243e59bc36789c4b98b0baecf3951e08",
            "post_s1_8":
            "8cd6f74b95c4e576168ea861288fa40ed918328d4e43428975466f902c0f843f",
        } and
        coordination.get("unchanged_non_justfile_identity") ==
        "byte_identical_to_inherited_pre_and_post_states" and
        coordination.get("added_phase23_text_surface") == {
            "path": "scripts/stdlib_s1_mutex_guard_parity.sh",
            "digest":
            "f03f7b26d667150fcc2019a5aea8f99f12ac165e4da28eac18d1c878fc7eb9fe",
            "match_counts": {
                "explicit_backend_spelling": 0,
                "mir_to_c_name": 7,
                "generated_c_contract": 0,
            },
            "classification": "archive_candidate",
            "owner": "stdlib",
            "current_route": "tracked_MIR_to_C_or_generated_C_surface",
            "deprecation_action": "map_to_live_lane_or_archive_in_23_10_and_23_11",
            "removal_phase": "24",
            "falsifier": "active_evidence_surface_is_missing_or_changes_identity",
        } and
        coordination.get("rejected_states") == [
            "partial", "extra", "substituted", "safe_raw",
            "backend_specific", "path_drifted", "unrelated",
        ] and
        coordination.get("phase22_invocation_transition") == {
            "contract_version":
            "phase24_s1_8_authority_phase22_invocation_transition_v1",
            "previous_invocation": {
                "path": "scripts/phase24_filename_behavior_characterization.py",
                "line": 428,
                "recipe": "none",
                "compiler_token": "python_argv",
                "selection": "implicit_default",
                "consumer_class": "cranelift_C_or_diagnostic_guard",
                "owner": "cranelift",
                "expected_artifact": "generated_C_or_diagnostic",
                "expected_transition": "22.2_explicit_C_selection",
                "falsifier":
                "default_flip_changes_the_guard_artifact_before_explicit_C_migration",
                "command":
                "[str(ROOT / 'gust'), *ROUTES[route], relative_target]",
            },
            "current_invocation": {
                "path": "scripts/phase24_filename_behavior_characterization.py",
                "line": 441,
                "recipe": "none",
                "compiler_token": "python_argv",
                "selection": "implicit_default",
                "consumer_class": "cranelift_C_or_diagnostic_guard",
                "owner": "cranelift",
                "expected_artifact": "generated_C_or_diagnostic",
                "expected_transition": "22.2_explicit_C_selection",
                "falsifier":
                "default_flip_changes_the_guard_artifact_before_explicit_C_migration",
                "command":
                "[str(ROOT / 'gust'), *ROUTES[route], relative_target]",
            },
            "summary_unchanged": True,
            "partial_extra_or_substituted_invocation": "rejected",
        } and
        coordination.get("boundary") == {
            "changes_compiler_runtime_or_stdlib_source": False,
            "changes_accepted_Gust_program_meaning": False,
            "adds_or_changes_MIR_ABI_layout_or_runtime_symbols": False,
            "changes_backend_route_default_or_fallback": False,
            "changes_bootstrap_route_or_seed": False,
            "begins_patch24_3": False,
        }, "S1.8 coordination successor identity or boundary drifted")
    return coordination


def s1_8_workflow_prerequisite_successor(
        coordination: dict, successor: dict) -> dict:
    workflow = coordination.get("workflow_prerequisite_successor")
    require(isinstance(workflow, dict),
            "S1.8 workflow prerequisite successor is missing")
    original_post = next(
        row for row in successor["accepted_states"][1]["files"]
        if row["path"] == ".github/workflows/stdlib-s1-mutex-guard.yml")
    require(
        workflow == {
            "contract_version":
            "phase24_s1_8_workflow_prerequisite_successor_v1",
            "status": "ready_for_exact_corrected_stdlib_s1_8_publication",
            "authority_base_main":
            "49e28774b5514960264ca68d291c8cecc3d476b5",
            "owning_stdlib_pull_request": 314,
            "candidate_rebased_head_sha":
            "63d8af1e7310fcbafa8c0dfbe074b04c04d5deb8",
            "changed_paths": [
                ".github/workflows/stdlib-s1-mutex-guard.yml"],
            "pre_workflow_digest":
            "eac232f77b80bd8980396738dc4f1708882402bcc4a0db3411b0a40bfdc7acdd",
            "post_workflow_digest":
            "a5afeb46e55c23465fab8539e1c8e9ad7b8ed200522affa0edd835674d384424",
            "required_step": "make gust",
            "unchanged_other_eight_paths":
            "byte_identical_to_phase24_s1_8_authority_successor_v1",
            "rejected_states": [
                "broken_workflow_post_s1_8", "partial", "extra",
                "substituted", "safe_raw", "backend_specific",
                "path_drifted", "unrelated",
            ],
            "boundary": {
                "changes_compiler_runtime_or_stdlib_source": False,
                "changes_accepted_Gust_program_meaning": False,
                "adds_or_changes_MIR_ABI_layout_or_runtime_symbols": False,
                "changes_backend_route_default_or_fallback": False,
                "changes_bootstrap_route_or_seed": False,
                "begins_patch24_3": False,
            },
        } and
        original_post.get("digest") == workflow["pre_workflow_digest"],
        "S1.8 workflow prerequisite successor identity or boundary drifted")
    return workflow


def provider_docs_successor(coordination: dict) -> dict:
    successor = coordination.get("provider_docs_consumer_successor")
    require(isinstance(successor, dict),
            "provider docs consumer successor is missing")
    paths = [
        "docs/CRYPTO_PROVIDER_ARCHITECTURE.md",
        "docs/DEMO_TARGET_PROGRAM.md",
        "docs/DEPLOYMENT_ARCHITECTURE.md",
        "docs/FULL_STACK_REFERENCE_MAP.md",
        "docs/HTTP_RPC_ARCHITECTURE.md",
        "docs/POSTGRES_DRIVER_ARCHITECTURE.md",
        "docs/STDLIB_FOUNDATIONS.md",
        "docs/STRATEGY_REVIEW.md",
        "docs/SUPPLIER_ADAPTER_STRATEGY.md",
        "docs/VISION.md",
        "docs/WASM_DOM_ARCHITECTURE.md",
        "docs/WEB_SLICE_0.md",
    ]
    boundary = {
        "changes_compiler_runtime_or_stdlib_source": False,
        "changes_accepted_Gust_program_meaning": False,
        "adds_or_changes_MIR_ABI_layout_or_runtime_symbols": False,
        "changes_backend_route_default_or_fallback": False,
        "changes_bootstrap_route_or_seed": False,
        "edits_provider_docs_candidate": False,
        "begins_patch24_3": False,
    }
    require(
        successor.get("contract_version") ==
        "phase24_provider_docs_consumer_successor_v1" and
        successor.get("status") ==
        "ready_for_exact_provider_docs_rebase" and
        successor.get("authority_base_main") ==
        "a6e99e14a1a90da29c26ef5f40f119c7feee8fa3" and
        successor.get("owning_docs_pull_request") == 320 and
        successor.get("owning_docs_exact_head_sha") ==
        "51c6365aea49d52931e98fbffd8d912734d53d6a" and
        successor.get("changed_paths") == paths and
        successor.get("accepted_live_states") == [
            "pre_provider_docs", "post_provider_docs"] and
        successor.get("rejected_states") == [
            "partial", "extra", "substituted", "path_drifted",
            "near_miss", "unrelated"] and
        successor.get("boundary") == boundary,
        "provider docs successor identity or boundary drifted")
    states = successor.get("accepted_states", [])
    require([row.get("state") for row in states] ==
            successor["accepted_live_states"],
            "provider docs accepted state order drifted")
    for state in states:
        files = state.get("files", [])
        require([row.get("path") for row in files] == paths,
                f"provider docs {state.get('state')} path manifest drifted")
        require(all(("digest" in row) != ("absent" in row) for row in files),
                f"provider docs {state.get('state')} file identity is ambiguous")
    require(all(row.get("absent") is True for row in states[0]["files"]
                if "absent" in row) and
            all(len(row.get("digest", "")) == 64 for state in states
                for row in state["files"] if "digest" in row) and
            all("digest" in row for row in states[1]["files"]),
            "provider docs accepted file identity drifted")
    require(successor.get("stdlib_surface_transition") == {
        "path": "docs/STDLIB_FOUNDATIONS.md",
        "pre_digest":
        "d1b41c13376d718749e2b67e9bb32136dfd1cd05f0e2cacbf4d56e00f87695dd",
        "post_digest":
        "33b8eedb1fbf96a14507c7a4fb706c5e9587ccaebdddb7112fba7859234ee843",
        "normalized_state": "post_s1_8",
        "partial_extra_or_substituted_surface": "rejected",
    }, "provider docs Stdlib surface transition drifted")
    phase23 = successor.get("phase23_text_surface_transition", {})
    previous_rows = phase23.get("previous_rows", [])
    current_rows = phase23.get("current_rows", [])
    require(
        phase23.get("changed_paths") == [
            "docs/HTTP_RPC_ARCHITECTURE.md",
            "docs/STDLIB_FOUNDATIONS.md",
            "docs/VISION.md",
        ] and
        phase23.get("added_paths") == [
            "docs/HTTP_RPC_ARCHITECTURE.md"] and
        [row.get("path") for row in previous_rows] == [
            "docs/STDLIB_FOUNDATIONS.md", "docs/VISION.md"] and
        [row.get("path") for row in current_rows] ==
        phase23.get("changed_paths") and
        phase23.get("closed_phase_projection") ==
        "canonical_pre_provider_docs_identity" and
        phase23.get("partial_extra_or_substituted_surface") == "rejected",
        "provider docs Phase 23 text-surface transition drifted")
    return successor


def classify_exact_file_manifest(
        successor: dict, live: list[dict[str, object]]) -> str | None:
    matches = [row["state"] for row in successor["accepted_states"]
               if row["files"] == live]
    require(len(matches) <= 1, "accepted provider docs identities overlap")
    return str(matches[0]) if matches else None


def provider_docs_falsifier_self_test(successor: dict) -> None:
    pre = copy.deepcopy(successor["accepted_states"][0]["files"])
    post = copy.deepcopy(successor["accepted_states"][1]["files"])
    require(classify_exact_file_manifest(successor, pre) ==
            "pre_provider_docs" and
            classify_exact_file_manifest(successor, post) ==
            "post_provider_docs",
            "provider docs classifier rejected an exact registered state")
    partial = copy.deepcopy(post)
    partial[0] = copy.deepcopy(pre[0])
    substituted = copy.deepcopy(post)
    substituted[0]["digest"] = "0" * 64
    path_drifted = copy.deepcopy(post)
    path_drifted[0]["path"] = "docs/SUBSTITUTED_PROVIDER_ARCHITECTURE.md"
    near_miss = copy.deepcopy(post)
    near_miss[-1]["digest"] = "f" * 64
    extra = copy.deepcopy(post)
    extra.append({"path": "docs/UNRELATED.md", "digest": "1" * 64})
    require(all(classify_exact_file_manifest(successor, candidate) is None
                for candidate in (
                    partial, substituted, path_drifted, near_miss, extra)),
            "provider docs partial, substituted, path-drifted, near-miss, "
            "or extra state was admitted")


LIVING_SURFACE_COLLAPSE: dict = {}


def provider_docs_state(coordination: dict) -> str:
    successor = provider_docs_successor(coordination)
    provider_docs_falsifier_self_test(successor)
    live: list[dict[str, object]] = []
    for path in successor["changed_paths"]:
        absolute = ROOT / path
        if absolute.is_file():
            live.append({
                "path": path,
                "digest": digest_bytes(absolute.read_bytes()),
            })
        else:
            live.append({"path": path, "absent": True})
    # A path Patch 24.2i registered as a landed living surface is admitted at
    # any bytes and projected onto the state this closed transition was
    # registered against; its landed content is asserted separately. Every
    # other provider doc still has to match a registered state exactly.
    state = classify_exact_file_manifest(successor, live)
    if state is None:
        collapse = LIVING_SURFACE_COLLAPSE.get("living_surfaces", [])
        living_paths = {row["path"] for row in collapse}
        if living_paths:
            for candidate in successor["accepted_states"]:
                projected = [
                    dict(candidate_row) if row["path"] in living_paths else row
                    for row, candidate_row in zip(live, candidate["files"])
                ]
                if classify_exact_file_manifest(successor, projected) is not None:
                    state = str(candidate["state"])
                    break
    require(state is not None,
            "live provider docs surface is neither exact pre- nor post-state")
    return state


def s1_9_resource_assignment_roadmap_successor(registry: dict) -> dict:
    coordination = registry.get("phase24_s1_8_authority_successor", {})
    successor = coordination.get("s1_9_resource_assignment_roadmap_successor")
    require(isinstance(successor, dict),
            "S1.9 Resource-assignment roadmap successor is missing")
    boundary = {
        "changes_compiler_runtime_or_stdlib_source": False,
        "changes_accepted_Gust_program_meaning": False,
        "adds_or_changes_MIR_ABI_layout_or_runtime_symbols": False,
        "changes_backend_route_default_or_fallback": False,
        "changes_bootstrap_route_or_seed": False,
        "edits_stdlib": False,
        "begins_patch24_3": False,
    }
    require(
        successor.get("contract_version") ==
        "phase24_s1_9_resource_assignment_roadmap_v1" and
        successor.get("status") == "patch24_2e_complete" and
        successor.get("authority_base_main") ==
        "db13122a9235c4ecc865bff6c275c7bf3946769b" and
        successor.get("changed_paths") == ["TASK.md"] and
        successor.get("accepted_live_states") == [
            "pre_roadmap_amendment", "post_roadmap_amendment"] and
        successor.get("implementation_sequence") == [
            "24.2f", "24.2g", "24.2h"] and
        successor.get("resume_patch24_3_after") == "stdlib_s1_12" and
        successor.get("rejected_states") == [
            "partial", "extra", "substituted", "path_drifted",
            "near_miss", "unrelated"] and
        successor.get("boundary") == boundary,
        "S1.9 Resource-assignment roadmap successor drifted")
    states = successor.get("accepted_states", [])
    require([row.get("state") for row in states] ==
            successor["accepted_live_states"] and
            all(row.get("files", []) and
                [item.get("path") for item in row["files"]] == ["TASK.md"]
                for row in states),
            "S1.9 Resource-assignment roadmap state identity drifted")
    return successor


def s1_9_resource_assignment_implementation_successor(
        registry: dict) -> dict:
    roadmap = s1_9_resource_assignment_roadmap_successor(registry)
    successor = roadmap.get("implementation_successor")
    require(isinstance(successor, dict),
            "S1.9 Resource-assignment implementation successor is missing")
    expected = {
        "contract_version":
        "phase24_s1_9_resource_assignment_implementation_v1",
        "status": "patch24_2f_implementation",
        "authority_base_main":
        "6e5aaa671b705c71866cc30d719c70d5cd316b59",
        "predecessor_justfile_digest":
        "8cd6f74b95c4e576168ea861288fa40ed918328d4e43428975466f902c0f843f",
        "live_justfile_successor_digest":
        "bd05a2b8a5f79ac4a82b7edd0d63d845c7693d196038974ebce0f108e7db9732",
        "added_recipes": [
            "guard-cranelift-phase24-resource-implicit-transfer-contract",
            "guard-cranelift-phase24-resource-implicit-transfer-evidence",
        ],
        "boundary": {
            "changes_compiler_source": True,
            "changes_accepted_Gust_program_meaning": True,
            "adds_or_changes_MIR_ABI_layout_or_runtime_symbols": False,
            "changes_backend_route_default_or_fallback": False,
            "changes_bootstrap_route_or_seed": False,
            "edits_stdlib": False,
            "begins_patch24_3": False,
        },
    }
    require({key: successor.get(key) for key in expected} == expected,
            "S1.9 Resource-assignment implementation successor drifted")
    transition = successor.get("consumer_inventory_transition")
    require(isinstance(transition, dict) and
            transition.get("contract_version") ==
            "phase24_s1_9_resource_assignment_implementation_consumer_transition_v1" and
            transition.get("status") == "patch24_2f_implementation" and
            transition.get("authority_base_main") ==
            "6e5aaa671b705c71866cc30d719c70d5cd316b59" and
            transition.get("registered_changed_paths") == [
                ".github/workflows/pr-fast.yml",
                "compiler/CRANELIFT_PHASE24_SEMANTIC_SPELLING_INVENTORY.md",
                "compiler/typechecker.gst",
                "scripts/cranelift_test_levels.json",
                "scripts/phase24_cr15_closure.py",
                "scripts/phase24_resource_implicit_transfer.py",
            ] and
            transition.get("added_text_surfaces") == [
                "scripts/phase24_resource_implicit_transfer.py"] and
            transition.get("unchanged_fields") == [
                "invocation_count", "invocation_manifest_digest",
                "structural_surface_count", "structural_manifest_digest",
                "invocation_selection_counts", "unclassified_count",
            ] and
            transition.get("partial_extra_or_substituted_surface") ==
            "rejected",
            "Patch 24.2f consumer inventory transition drifted")
    return successor


def classify_s1_9_resource_assignment_roadmap(
        successor: dict, live: list[dict[str, object]]) -> str | None:
    matches = [row["state"] for row in successor["accepted_states"]
               if row["files"] == live]
    require(len(matches) <= 1,
            "S1.9 Resource-assignment roadmap identities overlap")
    return str(matches[0]) if matches else None


def cranelift_roadmap_living_surface(successor: dict) -> dict:
    """Patch 24.2n: TASK.md is a living roadmap, not a frozen artefact.

    Every patch ticks a status row in TASK.md, so byte-pinning it forbids this
    lane from recording its own merged work - Patches 24.2f-24.2h merged while
    the roadmap still reported them unstarted, which is worse than a freeze
    because the document actively misreported state. Hold it to the landed
    records it must not lose instead, so gutting a merged patch's section still
    fails while ordinary roadmap evolution passes.
    """
    living = successor.get("roadmap_living_surface")
    require(isinstance(living, dict), "Cranelift roadmap living surface is missing")
    require(living.get("contract_version") ==
            "phase24_2n_cranelift_roadmap_living_surface_v1" and
            living.get("status") == "patch24_2n_roadmap_evolution" and
            living.get("path") == "TASK.md" and
            living.get("unregistered_living_surface") == "rejected",
            "Cranelift roadmap living surface drifted")
    markers = living.get("required_markers", [])
    require(bool(markers) and all(isinstance(m, str) and m for m in markers),
            "Cranelift roadmap living surface declares no landed marker")
    return living


def assert_landed_roadmap_records(living: dict) -> None:
    """Every landed roadmap record the live TASK.md must still carry."""
    text = TASK.read_text(encoding="utf-8")
    for marker in living["required_markers"]:
        require(marker in text,
                f"landed roadmap record was removed from TASK.md: {marker!r}")


def s1_9_resource_assignment_roadmap_state(registry: dict) -> str:
    successor = s1_9_resource_assignment_roadmap_successor(registry)
    pre = copy.deepcopy(successor["accepted_states"][0]["files"])
    post = copy.deepcopy(successor["accepted_states"][1]["files"])
    require(classify_s1_9_resource_assignment_roadmap(successor, pre) ==
            "pre_roadmap_amendment" and
            classify_s1_9_resource_assignment_roadmap(successor, post) ==
            "post_roadmap_amendment",
            "S1.9 Resource-assignment roadmap exact states were rejected")
    substituted = copy.deepcopy(post)
    substituted[0]["digest"] = "0" * 64
    path_drifted = copy.deepcopy(post)
    path_drifted[0]["path"] = "TASK_SUBSTITUTED.md"
    extra = copy.deepcopy(post)
    extra.append({"path": "UNRELATED.md", "digest": "1" * 64})
    require(all(classify_s1_9_resource_assignment_roadmap(
        successor, candidate) is None
        for candidate in (substituted, path_drifted, extra)),
        "S1.9 Resource-assignment roadmap falsifier was admitted")
    living = cranelift_roadmap_living_surface(successor)
    assert_landed_roadmap_records(living)
    live = [{"path": "TASK.md", "digest": digest_bytes(TASK.read_bytes())}]
    state = classify_s1_9_resource_assignment_roadmap(successor, live)
    if state is None:
        # TASK.md is a registered living surface: its landed records are
        # asserted above, so it is admitted at any bytes and reported as the
        # post-amendment state the closed projections expect.
        state = str(successor["accepted_states"][1]["state"])
    require(state is not None,
            "live TASK is neither exact pre- nor post-S1.9 roadmap state")
    return state


def coordinated_s1_8_states(
        successor: dict, coordination: dict,
        workflow: dict) -> list[dict[str, object]]:
    states = copy.deepcopy(successor["accepted_states"])
    digests = coordination["justfile_state_digests"]
    for state in states:
        for row in state["files"]:
            if row["path"] == "justfile":
                row.pop("absent", None)
                row["digest"] = digests[state["state"]]
            if (state["state"] == "post_s1_8" and
                    row["path"] == workflow["changed_paths"][0]):
                require(row.get("digest") == workflow["pre_workflow_digest"],
                        "S1.8 predecessor workflow identity drifted")
                row["digest"] = workflow["post_workflow_digest"]
    return states


def classify_s1_8_manifest(
        successor: dict, live: list[dict[str, object]]) -> str | None:
    matches = [row["state"] for row in successor["accepted_states"]
               if row["files"] == live]
    require(len(matches) <= 1, "S1.8 accepted state identities overlap")
    return str(matches[0]) if matches else None


def s1_8_falsifier_self_test(successor: dict) -> None:
    pre = copy.deepcopy(successor["accepted_states"][0]["files"])
    post = copy.deepcopy(successor["accepted_states"][1]["files"])
    require(classify_s1_8_manifest(successor, pre) == "pre_s1_8" and
            classify_s1_8_manifest(successor, post) == "post_s1_8",
            "S1.8 exact-state classifier rejected a registered state")

    partial = copy.deepcopy(post)
    partial[0] = copy.deepcopy(pre[0])
    substituted = copy.deepcopy(post)
    substituted[0]["digest"] = "0" * 64
    path_drifted = copy.deepcopy(post)
    path_drifted[0]["path"] = ".github/workflows/substituted.yml"
    extra = copy.deepcopy(post)
    extra.append({"path": "tests/unrelated.gst", "digest": "1" * 64})
    require(all(classify_s1_8_manifest(successor, candidate) is None
                for candidate in (partial, substituted, path_drifted, extra)),
            "S1.8 partial, substituted, path-drifted, or extra state was admitted")


def landed_living_surface_collapse(successor: dict) -> dict:
    """Patch 24.2i: Stdlib S1.8 has landed, so its living documents unfreeze.

    Byte-pinning TASK_STDLIB.md and the justfile stopped proving anything about
    S1.8 the moment S1.8 merged; all it did was forbid the Stdlib lane from
    ticking its own next checkbox or adding its next guard recipe. S1.8's own
    deliverables stay exactly pinned. Each living document is instead held to
    the landed content it must not lose, so removing an S1.8 recipe, fixture or
    DONE row still fails while ordinary roadmap evolution passes.
    """
    collapse = successor.get("landed_living_surface_collapse")
    require(isinstance(collapse, dict), "S1.8 landed living-surface collapse is missing")
    require(collapse.get("contract_version") ==
            "phase24_2i_stdlib_landed_living_surface_v1" and
            collapse.get("status") == "patch24_2i_stdlib_roadmap_evolution" and
            collapse.get("landed_publication") == "stdlib_s1_8" and
            collapse.get("unregistered_living_surface") == "rejected",
            "S1.8 landed living-surface collapse drifted")
    living = collapse.get("living_surfaces", [])
    pinned = collapse.get("pinned_deliverable_paths", [])
    require(sorted(pinned + [row["path"] for row in living]) ==
            successor["changed_paths"],
            "landed living-surface collapse does not partition the S1.8 manifest")
    require(len({row["path"] for row in living}) == len(living) and living,
            "landed living-surface paths are duplicated or empty")
    for row in living:
        markers = row.get("required_markers", [])
        require(bool(markers) and all(isinstance(m, str) and m for m in markers),
                f"living surface {row['path']} declares no landed marker")
    return collapse


def assert_landed_living_content(collapse: dict) -> None:
    """Every registered living surface must still carry its landed markers."""
    for row in collapse["living_surfaces"]:
        absolute = ROOT / row["path"]
        require(absolute.is_file(), f"living surface {row['path']} is missing")
        text = absolute.read_text(encoding="utf-8")
        for marker in row["required_markers"]:
            require(marker in text,
                    f"Stdlib S1.8 landed content was removed from {row['path']}: "
                    f"{marker!r}")


def s1_8_state(value: dict, registry: dict | None = None) -> str:
    if registry is None:
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    successor = s1_8_successor(value)
    s1_8_falsifier_self_test(successor)
    # Populated before provider_docs_state runs, since that check consults the
    # registered living surfaces and only receives the coordination record.
    _collapse = landed_living_surface_collapse(successor)
    assert_landed_living_content(_collapse)
    LIVING_SURFACE_COLLAPSE.clear()
    LIVING_SURFACE_COLLAPSE.update(_collapse)
    coordination = s1_8_coordination_successor(registry, successor)
    workflow = s1_8_workflow_prerequisite_successor(
        coordination, successor)
    provider = provider_docs_successor(coordination)
    provider_state = provider_docs_state(coordination)
    collapse = landed_living_surface_collapse(successor)
    living_paths = {row["path"] for row in collapse["living_surfaces"]}
    live: list[dict[str, object]] = []
    for path in successor["changed_paths"]:
        absolute = ROOT / path
        if absolute.is_file():
            live.append({"path": path, "digest": digest_bytes(absolute.read_bytes())})
        else:
            live.append({"path": path, "absent": True})

    coordinated = copy.deepcopy(successor)
    coordinated["accepted_states"] = coordinated_s1_8_states(
        successor, coordination, workflow)
    s1_8_falsifier_self_test(coordinated)
    broken = copy.deepcopy(successor)
    broken["accepted_states"] = copy.deepcopy(successor["accepted_states"])
    for state in broken["accepted_states"]:
        for row in state["files"]:
            if row["path"] == "justfile":
                row.pop("absent", None)
                row["digest"] = coordination[
                    "justfile_state_digests"][state["state"]]
    require(classify_s1_8_manifest(
        coordinated, broken["accepted_states"][1]["files"]) is None,
        "S1.8 broken-workflow post-state was admitted")
    if provider_state == "post_provider_docs":
        stdlib_transition = provider["stdlib_surface_transition"]
        stdlib_row = next(
            row for row in live
            if row["path"] == stdlib_transition["path"])
        # A registered living surface has already been checked for its landed
        # content, so it is admitted at any bytes and projected onto the closed
        # pre-state the provider-docs transition was registered against. An
        # unregistered path still has to match exactly.
        require(stdlib_transition["path"] in living_paths or
                stdlib_row.get("digest") == stdlib_transition["post_digest"],
                "provider docs Stdlib post-state identity drifted")
        stdlib_row["digest"] = stdlib_transition["pre_digest"]
    # A living surface has already been checked for its landed content, so its
    # exact bytes are projected onto the registered post-S1.8 identity. S1.8's
    # own deliverables are untouched here and still compare byte-for-byte.
    post_files = {row["path"]: row
                  for row in coordinated["accepted_states"][1]["files"]}
    for row in live:
        if (row["path"] in living_paths and "digest" in row and
                row["path"] != provider["stdlib_surface_transition"]["path"]):
            registered = post_files.get(row["path"], {})
            if "digest" in registered:
                row["digest"] = registered["digest"]
    state = classify_s1_8_manifest(coordinated, live)
    if state is None:
        implementation = s1_9_resource_assignment_implementation_successor(
            registry)
        implementation_coordinated = copy.deepcopy(coordinated)
        for row in implementation_coordinated["accepted_states"][1]["files"]:
            if row["path"] == "justfile":
                require(row.get("digest") ==
                        implementation["predecessor_justfile_digest"],
                        "Patch 24.2f justfile predecessor identity drifted")
                row["digest"] = implementation[
                    "live_justfile_successor_digest"]
        s1_8_falsifier_self_test(implementation_coordinated)
        state = classify_s1_8_manifest(implementation_coordinated, live)
    require(state is not None,
            "live Stdlib surface is neither exact pre-S1.8 nor exact post-S1.8 state")
    return state


def derivation_successor_digest(registry: dict) -> str | None:
    """Return the exact Patch 24.0c justfile successor when it is registered."""
    derivation = registry.get("phase24_cr15_derivation")
    if not isinstance(derivation, dict):
        return None
    transition = derivation.get("consumer_inventory_transition")
    if not isinstance(transition, dict):
        return None
    digest = transition.get("live_justfile_successor_digest")
    require(isinstance(digest, str) and len(digest) == 64,
            "Patch 24.0c justfile successor digest drifted")
    return digest


def qualification_successor_digest(registry: dict) -> str | None:
    """Return the exact Patch 24.0d justfile successor when it is registered."""
    qualification = registry.get("phase24_cr15_qualification")
    if not isinstance(qualification, dict):
        return None
    digest = qualification.get("live_justfile_successor_digest")
    require(isinstance(digest, str) and len(digest) == 64,
            "Patch 24.0d justfile successor digest drifted")
    return digest


def closure_successor_digest(registry: dict) -> str | None:
    """Return the exact Patch 24.0f justfile successor when it is registered."""
    closure = registry.get("phase24_cr15_closure")
    if not isinstance(closure, dict):
        return None
    digest = closure.get("live_justfile_successor_digest")
    require(isinstance(digest, str) and len(digest) == 64,
            "Patch 24.0f justfile successor digest drifted")
    return digest


def filename_characterization_successor_digest(registry: dict) -> str | None:
    """Return the exact Patch 24.1 justfile successor when it is registered."""
    characterization = registry.get("phase24_filename_behavior_characterization")
    if not isinstance(characterization, dict):
        return None
    digest = characterization.get("live_justfile_successor_digest")
    require(isinstance(digest, str) and len(digest) == 64,
            "Patch 24.1 justfile successor digest drifted")
    return digest


def validate_static(value: dict) -> None:
    require(value.get("contract_version") ==
            "phase24_cr15_stdlib_guard_transition_v1",
            "contract version drifted")
    require(value.get("status") == "landed_exact_relay" and
            value.get("owner") == "cranelift" and
            value.get("owning_stdlib_pull_request") == 304 and
            value.get("owning_stdlib_exact_head_sha") ==
            "f1267700e29784a1e59ff97e327f93a91da89585" and
            value.get("owning_stdlib_base_sha") ==
            "57fb7c5d531b752ebc34e20be170ec653f0f62b9",
            "owning relay identity drifted")
    require(value.get("landed_merge_evidence") == {
        "merge_main_sha": "c37024afa580d1e03c5ff70150ed0ae7518a9648",
        "pull_request_workflow_count": 93,
        "pull_request_workflow_success_count": 93,
        "unfinished_or_non_success_count": 0,
        "review_count": 0,
        "unresolved_thread_count": 0,
        "changed_paths": ["justfile"],
    }, "landed relay evidence drifted")
    require(value.get("changed_paths") == ["justfile"] and
            value.get("changed_path_count") == 1 and
            value.get("changed_site_count") == 1,
            "relay path or site count drifted")
    require(value.get("pre_relay_justfile_digest") ==
            "47b2886ff09862a09bac75419c4dd8714e184333e79e7415af6ac73f4064ff2c" and
            value.get("post_relay_justfile_digest") ==
            "97ebdee95b04c0f036b1f84a7d6a9d7ad1bb6adacc9c3ee2c5e2f8ea4bf43467",
            "relay file identity drifted")
    site = value.get("changed_site", {})
    require(site == {
        "path": "justfile",
        "recipe": "guard-stdlib-s1-resource-prerequisites",
        "compiler_token": "./gust",
        "selection": "explicit_c",
        "command": 'if ./gust --backend mir-to-c "$witness" >"$output" 2>&1; then',
        "pre_relay_line": 23258,
        "post_relay_line": 23270,
    }, "relay site identity drifted")
    require(value.get("phase22_invocation_summary") == {
        "total": 318,
        "selection_counts": {
            "explicit_c": 178,
            "explicit_cranelift": 119,
            "explicit_invalid_or_parser_probe": 3,
            "implicit_default": 18,
        },
        "consumer_class_counts": {
            "already_explicit_or_parser_probe": 300,
            "cranelift_C_or_diagnostic_guard": 5,
            "help_surface_probe": 3,
            "intentional_default_selection_probe": 8,
            "invocation_parser_probe": 2,
        },
        "owner_counts": {"cranelift": 289, "stdlib": 29},
        "unclassified_count": 0,
    }, "Phase 22 aggregate identity drifted")
    require(value.get("projection_policy") == {
        "pre_relay": "accepted_as_live_predecessor",
        "post_relay": "accepted_only_at_exact_registered_file_and_site_identity",
        "patch24_0c_successor": "accepted_only_at_exact_registered_derivation_digest",
        "patch24_0d_successor": "accepted_only_at_exact_registered_qualification_digest",
        "closed_phase_projection": "canonical_pre_relay_identity",
        "partial_extra_substituted_or_unrelated": "rejected",
        "landed_merge_evidence_is_recorded": True,
    }, "projection policy drifted")
    s1_8_successor(value)


def live_state(registry: dict | None = None) -> str:
    if registry is None:
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    value = authority(registry)
    validate_static(value)
    if s1_8_state(value, registry) == "post_s1_8":
        return "s1_8_successor"
    digest = digest_bytes(JUSTFILE.read_bytes())
    if digest == value["pre_relay_justfile_digest"]:
        return "pre_relay"
    if digest == value["post_relay_justfile_digest"]:
        return "post_relay"
    successor = derivation_successor_digest(registry)
    if successor is not None and digest == successor:
        return "derivation_successor"
    successor = qualification_successor_digest(registry)
    if successor is not None and digest == successor:
        return "qualification_successor"
    successor = closure_successor_digest(registry)
    if successor is not None and digest == successor:
        return "closure_successor"
    successor = filename_characterization_successor_digest(registry)
    if successor is not None and digest == successor:
        return "filename_characterization_successor"
    require(False,
            "justfile is not an exact registered relay or derivation state")
    raise AssertionError("unreachable")


def _class_contract_for_review() -> dict:
    return pinned_manifest_class_contract(
        json.loads(REGISTRY.read_text(encoding="utf-8")))


def pinned_manifest_class_contract(registry: dict) -> dict:
    """Patch 24.2p: the pinned-manifest class contract.

    Phases 22 and 23 pin two repository-wide manifests: an invocation inventory
    and a text-surface manifest whose membership is decided by *content match*,
    not by path - 578 of 2377 tracked files on the authority base. Every
    artefact a Stdlib or docs patch is made of lands in one or both, and a
    parity script cannot exercise both backend routes without naming them and
    thereby enrolling itself in the manifest that forbids new files. Patches
    24.2i and 24.2n lifted one instance each. This holds the class: living
    surfaces are held by the content they must not lose, lane-owned appends are
    admitted, and every closed-phase artefact stays exactly pinned.
    """
    successor = registry.get("phase24_s1_8_authority_successor", {}).get(
        "s1_9_resource_assignment_roadmap_successor", {})
    contract = successor.get("pinned_manifest_class_contract")
    require(isinstance(contract, dict),
            "pinned-manifest class contract is missing")
    require(contract.get("contract_version") ==
            "phase24_2p_pinned_manifest_class_v1" and
            contract.get("status") == "patch24_2p_pinned_manifest_class" and
            contract.get("unregistered_living_surface") == "rejected" and
            contract.get("unclassified_surface") == "rejected" and
            contract.get("unclassified_invocation") == "rejected" and
            contract.get("implicit_default_stdlib_invocation") == "rejected" and
            contract.get("cranelift_owned_append") == "rejected" and
            contract.get("landed_surface_removal") == "rejected",
            "pinned-manifest class contract drifted")
    living = contract.get("living_surfaces", [])
    require(bool(living) and
            len({row["path"] for row in living}) == len(living),
            "class living surfaces are empty or duplicated")
    for row in living:
        markers = row.get("required_markers", [])
        require(bool(markers) and all(isinstance(m, str) and m for m in markers),
                f"class living surface {row['path']} declares no landed marker")
    require(bool(contract.get("landed_stdlib_text_surfaces")) and
            bool(contract.get("landed_stdlib_invocation_sites")),
            "class contract registers no landed surface inventory")
    require(contract.get("appended_document_marker_removal") == "rejected",
            "appended-document marker contract drifted")
    for doc in contract.get("appended_document_markers", []):
        markers = doc.get("required_markers", [])
        require(bool(markers) and all(isinstance(m, str) and m for m in markers),
                f"appended document {doc.get('path')!r} declares no marker")
    living_rows = contract.get("living_projected_rows", [])
    require(bool(living_rows) and
            len({str(r["path"]) for r in living_rows}) == len(living_rows) and
            contract.get("unprojected_living_row") == "rejected" and
            contract.get("structural_rule_violation") == "rejected",
            "class living projected rows are missing, duplicated, or drifted")
    for row in living_rows:
        markers = row.get("required_markers", [])
        require(bool(markers) and all(isinstance(m, str) and m for m in markers) and
                isinstance(row.get("digest"), str) and
                isinstance(row.get("match_counts"), dict),
                f"living projected row {row.get('path')!r} is incomplete")
    for rule in contract.get("structural_rules", []):
        require(rule.get("unit") in ("line", "section") and
                bool(rule.get("unit_pattern")) and
                bool(rule.get("must_contain_any")) and
                int(rule.get("minimum_units", 0)) > 0,
                f"structural rule {rule.get('id')!r} is incomplete")
    require(contract.get("launch_gate_obligation_removal") == "rejected" and
            contract.get("unadjudicated_phase27_row") == "rejected" and
            isinstance(contract.get("retired_census_spelling"), str) and
            bool(contract.get("retired_census_spelling")),
            "launch-gate obligation contract drifted")
    obligations = contract.get("launch_gate_obligations", [])
    require(len(obligations) >= 3 and
            len({str(row["id"]) for row in obligations}) == len(obligations),
            "launch-gate obligations are missing or duplicated")
    for obligation in obligations:
        require(bool(obligation.get("markers")) and
                bool(obligation.get("bullet_prefix")) and
                bool(obligation.get("reason")) and
                obligation.get("disposition") in (
                    "launch_obligation", "launch_obligation_widened"),
                f"launch obligation {obligation.get('id')!r} is incomplete")
    dispositions = contract.get("phase27_row_dispositions", [])
    require([str(row["row"]) for row in dispositions] ==
            ["27.3", "27.4", "27.5", "27.6"],
            "the four Phase 27 rows are not each adjudicated")
    stated = {str(row["id"]) for row in obligations}
    for row in dispositions:
        require(row.get("disposition") in (
                    "launch_obligation", "opportunistic_cleanup", "split") and
                bool(row.get("reason")) and bool(row.get("destination")),
                f"Phase 27 row {row.get('row')!r} is not adjudicated")
        require(row["disposition"] == "opportunistic_cleanup" or
                str(row.get("obligation_id")) in stated,
                f"Phase 27 row {row.get('row')!r} claims an obligation "
                "the launch gate does not state")
    scope = contract.get("appended_text_surface_scope", {})
    require(isinstance(scope, dict) and
            bool(scope.get("path_prefixes")) and
            scope.get("outside_scope") == "rejected",
            "class appended text-surface scope is missing or drifted")
    return contract


def assert_class_living_content(contract: dict) -> None:
    """Every registered living surface must still carry its landed markers.

    This is what replaces the byte pin. A marker is a section identifier or a
    landed record, so it cannot survive gutting the content it names - the
    failure mode a bare substring marker has.
    """
    for row in contract["living_surfaces"]:
        absolute = ROOT / row["path"]
        require(absolute.is_file(),
                f"registered living surface is missing: {row['path']}")
        text = absolute.read_text(encoding="utf-8")
        for marker in row["required_markers"]:
            require(marker in text,
                    "landed content was removed from "
                    f"{row['path']}: {marker!r}")


def class_living_markers_hold(registry: dict, path: str) -> bool:
    """True when a registered living surface still carries every landed marker.

    Used where a guard reads a file's bytes directly rather than through the
    manifest rows, so the digest allowlist can be replaced by the content
    assertion without the guard losing its falsifier.
    """
    contract = pinned_manifest_class_contract(registry)
    rows = [row for row in contract["living_surfaces"]
            if str(row["path"]) == path]
    if not rows:
        return False
    absolute = ROOT / path
    if not absolute.is_file():
        return False
    text = absolute.read_text(encoding="utf-8")
    return all(marker in text for marker in rows[0]["required_markers"])


def class_living_paths(contract: dict) -> set[str]:
    return {str(row["path"]) for row in contract["living_surfaces"]}


def project_class_living_rows(
        rows: list[dict[str, object]],
        expected_rows: list[object],
        living_paths: set[str]) -> list[dict[str, object]]:
    """Admit any bytes for a registered living surface.

    The live row is projected onto the exact closed row the manifest was
    registered against, so no pinned digest has to move. Falsifiability comes
    from the markers asserted in assert_class_living_content, not from the
    bytes.
    """
    expected = {str(row["path"]): row for row in expected_rows
                if isinstance(row, dict)}
    projected = []
    for row in rows:
        path = str(row["path"])
        if path in living_paths and path in expected:
            projected.append(copy.deepcopy(expected[path]))
        else:
            projected.append(row)
    return projected


def gut_launch_gate_bullet(text: str, prefix: str) -> str:
    """Delete one launch-gate item the way a reader deleting it would.

    A bullet is its own line plus every following two-space continuation line,
    so this removes the obligation as written rather than removing the marker
    strings. That distinction is the whole value of the check below.
    """
    lines = text.splitlines(keepends=True)
    starts = [index for index, line in enumerate(lines)
              if line.startswith(prefix)]
    require(len(starts) == 1,
            f"launch-gate item is missing or duplicated: {prefix!r}")
    start = starts[0]
    end = start + 1
    while end < len(lines) and lines[end].startswith("  "):
        end += 1
    return "".join(lines[:start] + lines[end:])


def assert_launch_gate_obligations(contract: dict) -> None:
    """Patch 24.2t: a stated obligation nothing can falsify is a comment.

    `docs/CRANELIFT_LAUNCH.md` demanded "every Phase 20-27 status row ... is
    closed". That is a phase-number census - the same shape as "there are
    exactly 319 invocations", and as a whole-file digest standing in for tamper
    detection. It inherited Phase 27's four-clause exit gate by counting rather
    than by naming any part of it, so re-keying the count to 20-26 would have
    dropped four obligations without anyone deciding to. Two were promoted to
    stated obligations, one exit clause was restated at wider scope, and the
    rest were adjudicated into `docs/OPPORTUNISTIC_CLEANUP.md`.

    Each surviving obligation is asserted here, and each assertion is proved to
    fail when the obligation is removed. The removal deletes the whole bullet
    rather than the marker strings, which is what keeps the check from being
    circular: if a marker were registered against a neighbouring line, gutting
    the obligation would leave it standing and the last assertion fires.
    """
    rows = [row for row in contract["living_projected_rows"]
            if str(row["path"]) == "docs/CRANELIFT_LAUNCH.md"]
    require(len(rows) == 1,
            "the launch gate is not a registered living surface")
    registered = [str(marker) for marker in rows[0]["required_markers"]]
    text = LAUNCH_GATE.read_text(encoding="utf-8")
    census = str(contract["retired_census_spelling"])
    require(census not in text,
            f"the retired phase-number census was reintroduced: {census!r}")
    for obligation in contract["launch_gate_obligations"]:
        name = obligation["id"]
        markers = [str(marker) for marker in obligation["markers"]]
        require(all(marker in registered for marker in markers),
                f"launch obligation {name!r} is stated but not held by a "
                "registered marker")
        for marker in markers:
            require(text.count(marker) == 1,
                    f"launch obligation {name!r} marker is missing or "
                    f"duplicated: {marker!r}")
        gutted = gut_launch_gate_bullet(text, str(obligation["bullet_prefix"]))
        require(any(marker not in gutted for marker in registered),
                f"deleting launch obligation {name!r} left every marker "
                "standing, so the gate would still pass without it")
        require(not any(marker in gutted for marker in markers),
                f"launch obligation {name!r} is markered outside the bullet it "
                "names, so a gutting would survive it")


def assert_class_structural_rules(contract: dict) -> None:
    """Patch 24.2r: invariants a substring marker cannot express.

    "Every rule row carries a status" and "every phase section carries an exit
    gate" are properties of a document's shape, not of any one line. They catch
    a status softened into prose and a vanished row while staying indifferent to
    a status honestly changing - which is the progress these documents exist to
    record. The minimum_units floor is load-bearing rather than decorative: a
    rule of the form "every unit satisfies P" is vacuously true of zero units,
    so without a floor, deleting every unit would pass the rule written to catch
    exactly that.
    """
    for rule in contract.get("structural_rules", []):
        absolute = ROOT / str(rule["path"])
        require(absolute.is_file(),
                f"structural-rule surface is missing: {rule['path']}")
        text = absolute.read_text(encoding="utf-8")
        pattern = str(rule["unit_pattern"])
        if rule["unit"] == "line":
            units = [line for line in text.splitlines()
                     if re.search(pattern, line)]
        else:
            units = [part for part in re.split(r"(?m)^## ", text)
                     if re.match(pattern, part)]
        wanted = list(rule["must_contain_any"])
        offenders = [u.splitlines()[0][:60] for u in units
                     if not any(token in u for token in wanted)]
        require(not offenders,
                f"{rule['path']} violates {rule['id']}: {offenders[:3]}")
        require(len(units) >= int(rule["minimum_units"]),
                f"{rule['path']} fell below the {rule['id']} floor: "
                f"{len(units)} < {rule['minimum_units']}")


def assert_class_document_content(contract: dict) -> None:
    """Every content assertion this contract makes about a living document.

    Extracted from project_class_living_documents so the module that owns the
    contract can assert it directly. Before Patch 24.2t these checks ran only
    when a *consumer* scanned text surfaces, so `Cranelift Phase 24 CR-15
    Stdlib Guard Transition` could pass while asserting nothing about the six
    documents it registers - coverage survived incidentally, through the Phase
    23 opening guard's `docs/**` filter, rather than by design. An assertion
    reachable only through another guard's import is one refactor away from
    being reachable through nothing.
    """
    for path, row in sorted(
            {str(row["path"]): row for row in contract["living_projected_rows"]}.items()):
        absolute = ROOT / path
        require(absolute.is_file(), f"living document is missing: {path}")
        text = absolute.read_text(encoding="utf-8")
        for marker in row["required_markers"]:
            require(marker in text,
                    f"landed content was removed from {path}: {marker!r}")
    # Patch 24.2s: an appended document is projected out of the closed manifest
    # rather than onto a closed row - it has none, being new - so it is held to
    # its markers alone. The retirement contract names the manifest's own scan
    # patterns, so it enrols itself and is unaddable until admitted here.
    for doc in contract.get("appended_document_markers", []):
        absolute = ROOT / str(doc["path"])
        require(absolute.is_file(),
                f"appended document is missing: {doc['path']}")
        text = absolute.read_text(encoding="utf-8")
        for marker in doc["required_markers"]:
            require(marker in text,
                    f"recorded decision was removed from {doc['path']}: "
                    f"{marker!r}")
    assert_class_structural_rules(contract)
    assert_launch_gate_obligations(contract)


def project_class_living_documents(
        contract: dict,
        rows: list[dict[str, object]]) -> list[dict[str, object]]:
    """Hold the docs lane's living documents by content, not by bytes.

    Each registered document is admitted at any bytes that still carry its
    landed markers and satisfy its structural rules, then projected onto the
    exact closed manifest row it was registered against - so no pinned digest
    moves and the closed-phase evidence is unchanged.
    """
    assert_class_document_content(contract)
    registered = {str(row["path"]): row for row in contract["living_projected_rows"]}
    projected: list[dict[str, object]] = []
    for row in rows:
        path = str(row["path"])
        if path in registered:
            replacement = copy.deepcopy(row)
            replacement["digest"] = str(registered[path]["digest"])
            replacement["match_counts"] = copy.deepcopy(
                registered[path]["match_counts"])
            projected.append(replacement)
        else:
            projected.append(row)
    return projected


def drop_class_appended_text_surfaces(
        registry: dict,
        rows: list[dict[str, object]]) -> list[dict[str, object]]:
    """Admit Stdlib-owned growth in the Phase 23 content-pattern manifest.

    A closed phase's text-surface manifest asserts that every MIR-to-C surface
    is classified and that no registered surface changes identity. It does not
    - and cannot usefully - assert that no lane ever adds a file, since the
    manifest enrols files by content match. Stdlib-owned additions are
    therefore required to be classified and then projected out; every landed
    surface, and every Cranelift-owned row, is judged exactly as before.
    """
    contract = pinned_manifest_class_contract(registry)
    assert_class_living_content(contract)
    rows = project_class_living_documents(contract, rows)
    living = class_living_paths(contract)
    landed = set(contract["landed_stdlib_text_surfaces"])
    scope = contract["appended_text_surface_scope"]
    prefixes = tuple(scope["path_prefixes"])
    exact = set(scope.get("exact_paths", []))

    def in_scope(path: str) -> bool:
        return path.startswith(prefixes) or path in exact

    live_paths = {str(row["path"]) for row in rows}
    missing = sorted(landed - live_paths)
    require(not missing,
            f"a landed Stdlib text surface was removed: {missing[:3]}")
    kept: list[dict[str, object]] = []
    for row in rows:
        path = str(row["path"])
        if path in living or path in landed:
            kept.append(row)
            continue
        if not in_scope(path):
            # Outside the registered lane scope, so judged exactly as before:
            # a new Cranelift-owned MIR-to-C surface is still drift.
            kept.append(row)
            continue
        require(str(row.get("classification")) != "unclassified",
                f"appended Stdlib text surface is unclassified: {path}")
    return kept


def drop_class_appended_invocations(
        registry: dict,
        rows: list[dict[str, object]]) -> list[dict[str, object]]:
    """Admit Stdlib-owned growth in the Phase 22 invocation inventory.

    The closed six-site post-flip relay identity is untouched: those six sites
    keep their exact path, line, recipe, token, command and explicit_c
    selection. What is relaxed is the whole-repository census that rode along
    with it, whose load-bearing content is that no invocation escapes
    classification. That is kept and widened to every row, and an appended
    Stdlib invocation must additionally select a backend *explicitly* - so a
    patch cannot add a route-ambiguous invocation, which the census never
    actually prevented.
    """
    contract = pinned_manifest_class_contract(registry)
    sites = {(str(site["path"]), str(site["recipe"])): int(site["invocation_count"])
             for site in contract["landed_stdlib_invocation_sites"]}
    allowed = set(contract["appended_stdlib_invocation_selections"])
    rejected = str(contract["appended_stdlib_invocation_rejected_selection"])
    require(rejected not in allowed and
            contract.get("appended_stdlib_invocation_unregistered_selection") ==
            "rejected",
            "class contract admits the rejected invocation selection")
    live_counts = collections.Counter(
        (str(row["path"]), str(row["recipe"])) for row in rows
        if str(row.get("owner")) == "stdlib")
    for key, count in sorted(sites.items()):
        require(live_counts.get(key, 0) == count,
                "a landed Stdlib invocation site drifted: "
                f"{key[0]} {key[1]} {live_counts.get(key, 0)} != {count}")
    kept: list[dict[str, object]] = []
    for row in rows:
        require(str(row.get("consumer_class")) != "unclassified",
                "an unclassified invocation exists: "
                f"{row['path']}:{row['line']}")
        if str(row.get("owner")) != "stdlib":
            kept.append(row)
            continue
        if (str(row["path"]), str(row["recipe"])) in sites:
            kept.append(row)
            continue
        require(str(row["selection"]) != rejected and
                str(row["selection"]) in allowed,
                "an appended Stdlib invocation does not select a backend "
                f"explicitly: {row['path']}:{row['line']} "
                f"selection={row['selection']}")
    return kept


def normalize_phase22_invocations(
        registry: dict, rows: list[dict[str, object]]) -> list[dict[str, object]]:
    """Project the exact post relay onto the closed Phase 22 site identity."""
    rows = drop_class_appended_invocations(registry, rows)
    value = authority(registry)
    state = live_state(registry)
    site = value["changed_site"]
    line_key = ("pre_relay_line" if state == "pre_relay"
                else "post_relay_line")
    expected_line = site[line_key]
    if state == "s1_8_successor":
        expected_line = s1_8_successor(value)[
            "phase22_invocation_transition"]["post_line"]
    matches = [
        row for row in rows
        if row.get("path") == site["path"] and
        row.get("recipe") == site["recipe"] and
        row.get("compiler_token") == site["compiler_token"]
    ]
    require(len(matches) == 1, "relay site is missing, duplicated, or substituted")
    match = matches[0]
    require(match.get("line") == expected_line and
            match.get("selection") == site["selection"] and
            match.get("command") == site["command"],
            "relay site command, route, or location drifted")
    normalized = copy.deepcopy(rows)
    target = next(
        row for row in normalized
        if row.get("path") == site["path"] and
        row.get("recipe") == site["recipe"] and
        row.get("compiler_token") == site["compiler_token"]
    )
    target["line"] = site["pre_relay_line"]
    characterization = registry.get(
        "phase24_filename_behavior_characterization", {})
    transition = characterization.get("phase22_invocation_transition")
    if isinstance(transition, dict):
        require(transition.get("contract_version") ==
                "phase24_filename_behavior_phase22_invocation_transition_v1" and
                transition.get("status") == "exact_observational_invocation" and
                transition.get("closed_phase_projection") ==
                "remove_exact_patch24_1_observation_driver_only" and
                transition.get("partial_extra_or_substituted_invocation") ==
                "rejected",
                "Patch 24.1 invocation transition drifted")
        added = transition.get("added_invocation")
        decision = characterization.get("decision_authority_successor")
        if isinstance(decision, dict):
            decision_transition = decision.get("phase22_invocation_transition", {})
            require(decision_transition.get("contract_version") ==
                    "phase24_universal_tcs_decision_phase22_invocation_transition_v1" and
                    decision_transition.get("previous_invocation") == added and
                    decision_transition.get("summary_unchanged") is True and
                    decision_transition.get("partial_extra_or_substituted_invocation") ==
                    "rejected",
                    "Patch 24.1a invocation successor drifted")
            added = decision_transition.get("current_invocation")
        coordination = registry.get("phase24_s1_8_authority_successor", {})
        coordination_transition = coordination.get(
            "phase22_invocation_transition", {})
        require(
            coordination_transition.get("contract_version") ==
            "phase24_s1_8_authority_phase22_invocation_transition_v1" and
            coordination_transition.get("previous_invocation") == added and
            coordination_transition.get("summary_unchanged") is True and
            coordination_transition.get(
                "partial_extra_or_substituted_invocation") == "rejected",
            "S1.8 coordination invocation successor drifted")
        added = coordination_transition.get("current_invocation")
        # Patch 24.2f registers its own successor link: admitting the exact
        # Patch 24.2f justfile digest in the characterization guard moved this
        # observation driver five lines down. The projection below still
        # removes the row, so the closed Phase 22 summary is unchanged.
        implementation_transition = (
            s1_9_resource_assignment_implementation_successor(registry)
            .get("phase22_invocation_transition", {}))
        require(
            implementation_transition.get("contract_version") ==
            "phase24_s1_9_resource_assignment_implementation_phase22_invocation_transition_v1" and
            implementation_transition.get("previous_invocation") == added and
            implementation_transition.get("summary_unchanged") is True and
            implementation_transition.get(
                "partial_extra_or_substituted_invocation") == "rejected",
            "Patch 24.2f invocation successor drifted")
        added = implementation_transition.get("current_invocation")
        matches = [row for row in normalized if all(
            row.get(field) == added.get(field) for field in (
                "path", "line", "recipe", "compiler_token", "selection",
                "consumer_class", "owner", "expected_artifact",
                "expected_transition", "falsifier", "command"))]
        require(len(matches) == 1,
                "Patch 24.1 observation invocation is missing, duplicated, or substituted")
        require(transition.get("live_summary") == {
            "total": 319,
            "selection_counts": {
                "explicit_c": 178, "explicit_cranelift": 119,
                "explicit_invalid_or_parser_probe": 3, "implicit_default": 19,
            },
            "consumer_class_counts": {
                "already_explicit_or_parser_probe": 300,
                "cranelift_C_or_diagnostic_guard": 6,
                "help_surface_probe": 3,
                "intentional_default_selection_probe": 8,
                "invocation_parser_probe": 2,
            },
            "owner_counts": {"cranelift": 290, "stdlib": 29},
            "unclassified_count": 0,
        }, "Patch 24.1 live invocation summary drifted")
        normalized.remove(matches[0])
    normalized.sort(key=lambda row: (
        str(row["path"]), int(row["line"]), str(row["command"])
    ))
    return normalized


def normalize_phase23_text_surfaces(
        registry: dict, rows: list[dict[str, object]]) -> list[dict[str, object]]:
    """Keep closed Phase 23 projection identity across this exact control-plane relay."""
    rows = drop_class_appended_text_surfaces(registry, rows)
    living_paths = class_living_paths(
        pinned_manifest_class_contract(registry))
    value = authority(registry)
    state = live_state(registry)
    s1_successor = s1_8_successor(value)
    coordination = s1_8_coordination_successor(registry, s1_successor)
    provider = provider_docs_successor(coordination)
    provider_state = provider_docs_state(coordination)
    provider_text = provider["phase23_text_surface_transition"]
    provider_paths = provider_text["changed_paths"]
    by_live_path = {str(row["path"]): row for row in rows}
    if provider_state == "pre_provider_docs":
        require([by_live_path.get(path) for path in (
            "docs/STDLIB_FOUNDATIONS.md", "docs/VISION.md",
        )] == provider_text["previous_rows"] and
                all(path not in by_live_path
                    for path in provider_text["added_paths"]),
                "provider docs pre-state Phase 23 surface drifted")
    else:
        rows = project_class_living_rows(
            rows, provider_text["current_rows"], living_paths)
        by_live_path = {str(row["path"]): row for row in rows}
        require([by_live_path.get(path) for path in provider_paths] ==
                provider_text["current_rows"],
                "provider docs post-state Phase 23 surface is partial or substituted")
        replacements = {
            str(row["path"]): copy.deepcopy(row)
            for row in provider_text["previous_rows"]
        }
        rows = [
            replacements.get(str(row["path"]), row)
            for row in rows
            if str(row["path"]) not in provider_text["added_paths"]
        ]
    if state == "s1_8_successor":
        transition = s1_successor["phase23_text_surface_transition"]
        expected_current = copy.deepcopy(transition["current_rows"])
        # The justfile has two registered identities in this state: the exact
        # post-S1.8 digest, and the exact Patch 24.2f successor that adds the
        # two implicit-transfer recipes. Pin to whichever is live and reject
        # everything else, rather than re-reading the file as its own expected
        # value, which would make the comparison below unfalsifiable.
        # Patch 24.2p: the justfile, TASK_STDLIB.md and the two Stdlib documents
        # are registered living surfaces. Their landed markers are asserted in
        # drop_class_appended_text_surfaces above, so here each is admitted at
        # any bytes and projected onto the exact closed row this manifest was
        # registered against. Appending a guard recipe is not changing one.
        rows = project_class_living_rows(rows, expected_current, living_paths)
        by_live_path = {str(row["path"]): row for row in rows}
        require([by_live_path.get(path) for path in transition["changed_paths"]] ==
                expected_current,
                "live S1.8 text surfaces are partial, substituted, or drifted")
        replacements = {
            str(row["path"]): copy.deepcopy(row)
            for row in transition["previous_rows"]
        }
        replacements["justfile"]["digest"] = coordination[
            "justfile_state_digests"]["pre_s1_8"]
        rows = [replacements.get(str(row["path"]), row) for row in rows]
        added = coordination["added_phase23_text_surface"]
        matches = [row for row in rows if row["path"] == added["path"]]
        require(matches == [added],
                "S1.8 added text surface is missing, substituted, or duplicated")
        rows.remove(matches[0])
    roadmap = s1_9_resource_assignment_roadmap_successor(registry)
    roadmap_state = s1_9_resource_assignment_roadmap_state(registry)
    roadmap_states = {
        row["state"]: row["files"][0]
        for row in roadmap["accepted_states"]
    }
    by_path = {str(row["path"]): row for row in rows}
    require("TASK.md" in by_path,
            "S1.9 Resource-assignment roadmap TASK surface is missing")
    # TASK.md is a registered living surface (Patch 24.2n). Its landed records
    # are asserted in s1_9_resource_assignment_roadmap_state, so here it is
    # admitted at any bytes and projected onto the closed pre-amendment state
    # this projection was registered against.
    require(by_path["TASK.md"].get("digest") ==
            roadmap_states[roadmap_state]["digest"] or
            isinstance(roadmap.get("roadmap_living_surface"), dict),
            "S1.9 Resource-assignment roadmap TASK surface drifted")
    by_path["TASK.md"]["digest"] = roadmap_states[
        "pre_roadmap_amendment"]["digest"]
    # Patch 24.2q: Patch 24.2n projected the digest but left match_counts live,
    # so TASK.md was editable only while its MIR-to-C mention count never moved -
    # a trap that fires on the first ordinary row about backend parity. Project
    # the whole content-derived row, as every other living surface already gets.
    projected = pinned_manifest_class_contract(registry)["roadmap_projected_row"]
    require(str(projected["path"]) == "TASK.md" and
            projected.get("unprojected_match_counts") == "rejected",
            "roadmap projected-row contract drifted")
    by_path["TASK.md"]["match_counts"] = copy.deepcopy(
        projected["match_counts"])
    implementation = s1_9_resource_assignment_implementation_successor(
        registry)
    transition = implementation["consumer_inventory_transition"]
    changed_paths = transition["registered_changed_paths"]
    # Patch 24.2g-auth registers one further changed surface on top of the merged
    # Patch 24.2f state. Both are exact registered states; anything else rejects.
    auth = registry.get("phase22_default_route_seed_convergence", {}).get(
        "phase24_2g_auth_seed_identity_successor")
    auth_paths: list[str] = []
    if isinstance(auth, dict):
        require(auth.get("contract_version") ==
                "phase24_2g_auth_seed_identity_successor_v1" and
                auth.get("status") == "patch24_2g_closure_landed" and
                auth.get("registered_changed_paths") == [
                    "gust_v4.c",
                    "scripts/phase22_default_route_seed_convergence.py",
                    "scripts/phase24_cr15_closure.py"] and
                auth.get("added_text_surfaces") == [] and
                auth.get("partial_extra_or_substituted_surface") == "rejected",
                "Patch 24.2g-auth seed identity successor drifted")
        auth_paths = auth["registered_changed_paths"]
    union_paths = changed_paths + [
        path for path in auth_paths if path not in changed_paths]
    # A path registered by Patch 24.2g-auth is judged by that successor instead,
    # since this patch moves it beyond the identity Patch 24.2f pinned.
    solely_24_2f = [path for path in changed_paths if path not in auth_paths]
    changed_rows = [row for row in rows if row["path"] in solely_24_2f]
    require(changed_rows == [row for row in transition["current_changed_text_surfaces"]
                             if row["path"] in solely_24_2f],
            "Patch 24.2f changed text surfaces are partial or substituted")
    auth_pre_rows: dict[str, dict] = {}
    if auth_paths:
        # Each registered path is judged independently: the guard script lands in
        # Patch 24.2g-auth and gust_v4.c lands in Patch 24.2g, so a tree can hold
        # one at its post identity while the other is still at its pre identity.
        # Every combination is an exact registered state; anything else rejects.
        pre_by_path = {row["path"]: row
                       for row in auth["previous_changed_text_surfaces"]}
        post_by_path = {row["path"]: row
                        for row in auth["current_changed_text_surfaces"]}
        require(sorted(pre_by_path) == sorted(auth_paths) and
                sorted(post_by_path) == sorted(auth_paths),
                "Patch 24.2g-auth registered paths and rows disagree")
        live_by_path = {row["path"]: row for row in rows
                        if row["path"] in auth_paths}
        require(sorted(live_by_path) == sorted(auth_paths),
                "Patch 24.2g-auth registered text surface is missing")
        for path in auth_paths:
            live_row = live_by_path[path]
            require(live_row in (pre_by_path[path], post_by_path[path]),
                    "Patch 24.2g-auth changed text surfaces are partial or "
                    f"substituted: {path}")
            auth_pre_rows[path] = pre_by_path[path]
    # The auth paths are excluded from the unchanged-other digest in every state,
    # so that digest does not depend on which of them has landed yet.
    scope = union_paths
    other_digest = digest_bytes(json.dumps(
        [row for row in rows if row["path"] not in scope],
        sort_keys=True, separators=(",", ":")).encode())
    expected_other = (auth["unchanged_other_text_surface_manifest_digest"]
                      if auth_paths
                      else transition["unchanged_other_text_surface_manifest_digest"])
    require(other_digest == expected_other,
            f"Patch 24.2f changed an unregistered text surface: {other_digest}")
    replacements = {
        row["path"]: copy.deepcopy(row)
        for row in transition["previous_changed_text_surfaces"]
    }
    # Project each auth path back so the closed Phase 23 and Phase 26/27
    # projections keep seeing the state they were registered against, whichever
    # of these patches has landed. A path Patch 24.2f already tracks keeps that
    # patch's own previous identity - those projections predate 24.2f and expect
    # the pre-24.2f row, not this successor's.
    for path, row in auth_pre_rows.items():
        if path not in replacements:
            replacements[path] = copy.deepcopy(row)
    added = set(transition["added_text_surfaces"])
    if auth_paths:
        added |= set(auth["added_text_surfaces"])
    rows = [replacements.get(row["path"], row) for row in rows
            if row["path"] not in added]
    canonical = value.get("canonical_phase23_text_surfaces", [])
    require([row.get("path") for row in canonical] == [
        "justfile", "scripts/phase22_opening.py",
    ], "canonical text-surface path manifest drifted")
    by_path = {str(row["path"]): row for row in rows}
    for expected in canonical:
        path = str(expected["path"])
        require(path in by_path, f"canonical text surface is missing: {path}")
        live = by_path[path]
        accepted = list(expected.get("accepted_live_digests", []))
        if path == "justfile":
            successor = derivation_successor_digest(registry)
            if successor is not None:
                accepted.append(successor)
            successor = qualification_successor_digest(registry)
            if successor is not None:
                accepted.append(successor)
            successor = closure_successor_digest(registry)
            if successor is not None:
                accepted.append(successor)
            successor = filename_characterization_successor_digest(registry)
            if successor is not None:
                accepted.append(successor)
        require(live.get("digest") in accepted,
                f"unregistered text-surface identity: {path}")
        for field in (
            "match_counts", "classification", "owner", "current_route",
            "deprecation_action", "removal_phase", "falsifier",
        ):
            require(live.get(field) == expected.get(field),
                    f"text-surface classification drifted: {path}: {field}")
        by_path[path] = {
            key: copy.deepcopy(expected[key])
            for key in (
                "path", "digest", "match_counts", "classification", "owner",
                "current_route", "deprecation_action", "removal_phase", "falsifier",
            )
        }
    return [by_path[str(row["path"])] for row in rows]


def normalized_owner_file_digest(
        registry: dict, path: str, digest: str) -> str:
    """Normalize only the exact registered justfile owner identity."""
    if path != "justfile":
        return digest
    value = authority(registry)
    state = live_state(registry)
    expected = (value["pre_relay_justfile_digest"]
                if state == "pre_relay"
                else value["post_relay_justfile_digest"])
    if state == "derivation_successor":
        expected = derivation_successor_digest(registry)
    elif state == "qualification_successor":
        expected = qualification_successor_digest(registry)
    elif state == "closure_successor":
        expected = closure_successor_digest(registry)
    elif state == "filename_characterization_successor":
        expected = filename_characterization_successor_digest(registry)
    elif state == "s1_8_successor":
        successor = s1_8_successor(value)
        coordination = s1_8_coordination_successor(registry, successor)
        implementation_digest = s1_9_resource_assignment_implementation_successor(
            registry)["live_justfile_successor_digest"]
        expected = (implementation_digest
                    if digest == implementation_digest
                    else coordination["justfile_state_digests"]["post_s1_8"])
    # Patch 24.2p: the justfile is a registered living surface. It is admitted
    # at any bytes that still carry its landed guard recipes; gutting one of
    # them still rejects here.
    require(digest == expected or class_living_markers_hold(registry, "justfile"),
            "live-C justfile owner identity drifted")
    return value["pre_relay_justfile_digest"]


def validate() -> tuple[dict, str]:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    assert_class_living_content(pinned_manifest_class_contract(registry))
    assert_class_document_content(pinned_manifest_class_contract(registry))
    value = authority(registry)
    state = live_state(registry)
    s1_9_resource_assignment_roadmap_state(registry)

    opening_path = ROOT / "scripts/phase22_opening.py"
    spec = importlib.util.spec_from_file_location("phase22_transition_opening", opening_path)
    require(spec is not None and spec.loader is not None,
            "cannot load the Phase 22 invocation scanner")
    opening = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(opening)
    rows = opening.scan_invocations()
    require(opening.scan_summary(rows) == value["phase22_invocation_summary"],
            "effective Phase 22 aggregate drifted")
    return value, state


def render(value: dict) -> str:
    site = value["changed_site"]
    summary = value["phase22_invocation_summary"]
    successor = s1_8_successor(value)
    raw = successor["raw_mutex_call_site_transition"]
    return "\n".join([
        "# Cranelift Phase 24 CR-15 Stdlib Guard Transition",
        "",
        "Generated by `scripts/phase24_cr15_stdlib_guard_transition.py`; do not edit by hand.",
        "",
        f"- Contract: `{value['contract_version']}`",
        f"- Status: `{value['status']}`",
        f"- Owning Stdlib PR: `#{value['owning_stdlib_pull_request']}`",
        f"- Exact owning head: `{value['owning_stdlib_exact_head_sha']}`",
        "- Changed paths: `justfile` (exactly one)",
        f"- Changed site: `{site['recipe']}` / `{site['compiler_token']}`",
        f"- Pre-relay line: `{site['pre_relay_line']}`",
        f"- Post-relay line: `{site['post_relay_line']}`",
        f"- Preserved invocation total: `{summary['total']}`",
        f"- Preserved explicit-C count: `{summary['selection_counts']['explicit_c']}`",
        f"- Preserved unclassified count: `{summary['unclassified_count']}`",
        "",
        "The exact relay is merged and recorded. Only the exact pre-relay, landed one-site",
        "relay, or exact registry-owned Patch 24.0c/24.0d successor is accepted.",
        "Closed Phase 22/23 projections use the canonical predecessor identity because",
        "the compiler command and route are unchanged. Partial, extra-site, substituted,",
        "path-drifted, or unrelated `justfile` changes are rejected.",
        "",
        "The landed evidence records 93/93 successful exact-head pull-request workflows,",
        "zero reviews, zero unresolved threads, and the sole changed path `justfile`.",
        "It changes no language, MIR, backend, route/default/fallback, runtime, bootstrap,",
        "or Stdlib semantics.",
        "",
        "## Exact S1.8 successor",
        "",
        f"- Contract: `{successor['contract_version']}`",
        f"- Status: `{successor['status']}`",
        f"- Candidate paths: `{len(successor['changed_paths'])}`",
        f"- Raw lifecycle successor: `{raw['current_totals']['lock_calls']}` Lock / "
        f"`{raw['current_totals']['unlock_calls']}` Unlock",
        "",
        "Only the exact pre-S1.8 state or the complete registered nine-path S1.8",
        "state is accepted. The successor adds one internal explicit-unsafe Lock/Unlock",
        "pair and preserves the closed Phase 22 invocation and Phase 23 text-surface",
        "identities through exact normalization. Partial, extra, substituted, safe-raw,",
        "backend-specific, path-drifted, and unrelated inventory states remain rejected.",
        "",
        "## Pinned-manifest class contract (Patch 24.2p)",
        "",
        f"- Contract: `{_class_contract_for_review()['contract_version']}`",
        f"- Living surfaces: `{len(_class_contract_for_review()['living_surfaces'])}`",
        f"- Landed Stdlib text surfaces: "
        f"`{len(_class_contract_for_review()['landed_stdlib_text_surfaces'])}`",
        f"- Landed Stdlib invocation sites: "
        f"`{len(_class_contract_for_review()['landed_stdlib_invocation_sites'])}` "
        f"covering `{_class_contract_for_review()['landed_stdlib_invocation_count']}` "
        "invocations",
        "",
        "Phases 22 and 23 pin two repository-wide manifests whose membership is",
        "decided by content match rather than by path, so the pinned set is not",
        "enumerable from a path list. Each registered living surface is admitted at",
        "any bytes that still carry its landed markers and is projected onto the exact",
        "closed row the manifest was registered against, so no pinned digest moves.",
        "Additions inside the registered lane scope must be classified, and an added",
        "invocation must select a backend explicitly. The closed six-site post-flip",
        "relay identity, every landed surface, and every Cranelift-owned row are",
        "judged exactly as before; removing a landed surface, gutting a registered",
        "marker, adding a Cranelift-owned surface or invocation, and any unclassified",
        "surface or invocation all remain rejected.",
        "",
    ])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review"))
    args = parser.parse_args()
    value, state = validate()
    expected = render(value)
    if args.command == "project":
        REVIEW.write_text(expected, encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and REVIEW.read_text(encoding="utf-8") == expected,
                "generated review is stale")
    print(f"{GUARD}: {args.command} ok ({state})")


if __name__ == "__main__":
    main()
