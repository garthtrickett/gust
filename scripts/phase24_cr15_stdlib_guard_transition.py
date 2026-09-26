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


def provider_docs_state(coordination: dict, registry: dict) -> str:
    successor = provider_docs_successor(coordination)
    provider_docs_falsifier_self_test(successor)
    # The later class contract registers additional living documents beyond
    # S1.8's original set. Check their landed markers before projecting their
    # live bytes onto this closed provider-docs manifest.
    class_contract = pinned_manifest_class_contract(registry)
    assert_class_living_content(class_contract)
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
        living_paths = {row["path"] for row in collapse} | \
            class_living_paths(class_contract)
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
    provider_state = provider_docs_state(coordination, registry)
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
        if state is None:
            # Issue #398 converts scripts/stdlib_s1_mutex_guard_parity.sh
            # onto frozen replay, which moves bytes S1.8 pinned exactly. The
            # pin stays as the record of what S1.8 delivered; the successor
            # rebases the one path it moved, the same way Patch 24.2f's
            # successor rebases the justfile just above.
            #
            # It rebases exactly one path, and only from the digest it names
            # as the predecessor. A successor that pointed at some other
            # registered file, or at a post-state this manifest never held,
            # fails rather than re-pinning the manifest to whatever is on
            # disk. The falsifier self-test runs again on the rebased
            # manifest, so the classifier is proved to still reject partial,
            # substituted, path-drifted and extra states after the rebase --
            # a rebase that made the manifest permissive would fail there.
            spelling = registry.get(
                "phase398_retained_spelling_removal", {}).get(
                    "s1_8_surface_successor")
            if spelling is not None:
                require(spelling.get("contract_version") ==
                        "phase398_s1_8_surface_successor_v1" and
                        spelling.get("partial_or_substituted_surface") ==
                        "rejected",
                        "Issue #398 S1.8 surface successor drifted")
                # Rebased onto `coordinated`, not onto the justfile
                # successor above it. The justfile is a registered living
                # surface, so its live bytes are already projected onto the
                # registered post identity before any of this runs; layering
                # this on top of the justfile rebase would put that one path
                # back to a digest the projection had just resolved, and the
                # manifest would fail on the justfile instead.
                spelling_coordinated = copy.deepcopy(coordinated)
                rebased = 0
                for row in spelling_coordinated["accepted_states"][1]["files"]:
                    if row["path"] != spelling["path"]:
                        continue
                    require(row.get("digest") ==
                            spelling["predecessor_digest"],
                            "Issue #398 S1.8 surface predecessor identity "
                            f"drifted: {spelling['path']}")
                    row["digest"] = spelling["successor_digest"]
                    rebased += 1
                require(rebased == 1,
                        "Issue #398 rebases a path the S1.8 manifest does not "
                        f"pin exactly once: {spelling['path']}")
                s1_8_falsifier_self_test(spelling_coordinated)
                state = classify_s1_8_manifest(spelling_coordinated, live)
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


def effective_phase22_summary(registry: dict, value: dict) -> dict:
    """The pinned Phase 22 census, advanced by each registered successor.

    Patch 24.12 is the first patch to reduce this census: converting a parity
    guard removes the invocation it used to make, so 107 explicit-C rows leave
    it. Pinning the closed total and editing it in place would rewrite what
    the closed record claims; the successor states the reduction instead, and
    the arithmetic has to close.
    """
    summary = value["phase22_invocation_summary"]
    successor = registry.get("phase24_frozen_oracle_replacement", {}).get(
        "phase22_invocation_successor")
    if successor is None:
        return summary
    previous = successor.get("previous_summary")
    current = successor.get("current_summary")
    require(successor.get("contract_version") ==
            "phase24_12_frozen_oracle_phase22_invocation_successor_v1" and
            successor.get("status") == "patch24_12_complete" and
            successor.get("authority_base_main") ==
            "8aa9922eb40ad404647a86f865f0790ab37a3589" and
            previous == summary and
            isinstance(current, dict) and
            successor.get("partial_or_unregistered_reduction") == "rejected",
            "Patch 24.12 Phase 22 invocation successor drifted")
    require(current["total"] < previous["total"] and
            current["unclassified_count"] == previous["unclassified_count"] ==
            0,
            "Patch 24.12 did not reduce a fully classified Phase 22 census")
    require(successor.get("removed_invocation_count") ==
            previous["total"] - current["total"] and
            successor["removed_invocation_count"] ==
            previous["selection_counts"]["explicit_c"] -
            current["selection_counts"]["explicit_c"],
            "the Patch 24.12 census reduction is not entirely explicit-C")
    oracle = registry.get("phase24_frozen_oracle_replacement", {})
    surface = oracle.get("frozen_surface_transition", {})
    require(successor["removed_invocation_count"] ==
            surface.get("removed_case_count"),
            "the Phase 22 census and the frozen-surface transition disagree "
            "about how many live-C cases Patch 24.12 removed")
    # Patch 24.12a advances the same census, and its reduction must agree
    # with its own frozen-surface transition the same way 24.12's did. Two
    # authorities measuring one removal: if they disagree, one is measuring
    # something else.
    emitter = registry.get("phase24_12a_emitter_only_retirement", {}).get(
        "phase22_invocation_successor")
    if emitter is None:
        return current
    previous, current = current, emitter.get("current_summary")
    require(emitter.get("contract_version") ==
            "phase24_12a_invocation_successor_v1" and
            emitter.get("status") == "patch24_12a_complete" and
            emitter.get("previous_summary") == previous and
            isinstance(current, dict) and
            emitter.get("partial_or_unregistered_reduction") == "rejected",
            "Patch 24.12a Phase 22 invocation successor drifted")
    require(current["total"] < previous["total"] and
            current["unclassified_count"] == previous["unclassified_count"]
            == 0,
            "Patch 24.12a did not reduce a fully classified Phase 22 census")
    require(emitter.get("removed_invocation_count") ==
            previous["total"] - current["total"] and
            emitter["removed_invocation_count"] ==
            previous["selection_counts"]["explicit_c"] -
            current["selection_counts"]["explicit_c"],
            "the Patch 24.12a census reduction is not entirely explicit-C")
    emitter_surface = registry.get(
        "phase24_12a_emitter_only_retirement", {}).get(
            "frozen_surface_transition", {})
    require(emitter["removed_invocation_count"] ==
            emitter_surface.get("removed_case_count"),
            "the Phase 22 census and the frozen-surface transition disagree "
            "about how many live-C cases Patch 24.12a removed")
    # Patch 24.12b advances the same census once more, under the same
    # two-authority rule: its reduction must agree with its own
    # frozen-surface transition or one of them is measuring something else.
    conversion = registry.get(
        "phase24_12b_python_parity_conversion", {}).get(
            "phase22_invocation_successor")
    if conversion is None:
        return current
    previous, current = current, conversion.get("current_summary")
    require(conversion.get("contract_version") ==
            "phase24_12b_invocation_successor_v1" and
            conversion.get("previous_summary") == previous and
            isinstance(current, dict) and
            conversion.get("partial_or_unregistered_reduction") == "rejected",
            "Patch 24.12b Phase 22 invocation successor drifted")
    require(current["total"] < previous["total"] and
            current["unclassified_count"] == previous["unclassified_count"]
            == 0,
            "Patch 24.12b did not reduce a fully classified Phase 22 census")
    require(conversion.get("removed_invocation_count") ==
            previous["total"] - current["total"] and
            conversion["removed_invocation_count"] ==
            previous["selection_counts"]["explicit_c"] -
            current["selection_counts"]["explicit_c"],
            "the Patch 24.12b census reduction is not entirely explicit-C")
    conversion_surface = registry.get(
        "phase24_12b_python_parity_conversion", {}).get(
            "frozen_surface_transition", {})
    require(conversion["removed_invocation_count"] ==
            conversion_surface.get("removed_case_count"),
            "the Phase 22 census and the frozen-surface transition disagree "
            "about how many live-C cases Patch 24.12b removed")

    # Patch 24.13 continues the chain, and is the first link that both
    # RECLASSIFIES and reduces. Every successor above only removes
    # invocations, so each asserts `current["total"] < previous["total"]`.
    # 24.13 removes backend SELECTION at some sites -- the caller survives and
    # chooses a different backend -- and removes the site outright at others,
    # taking with it the bare `./gust` arm that existed only to compare against
    # the explicit-C one. So the total neither holds nor simply falls by the
    # explicit-C drop, and the contract has to split that drop into its fates.
    #
    # Without this link the chain simply stopped at 24.12b and returned a
    # census that predates the removal, so the aggregate compared a live tree
    # against a state two patches old and reported "drifted" without saying
    # which patch was missing.
    #
    # This census is the UNFILTERED scan; the Phase 22 relay census drops the
    # relay-inventory and Phase 23 successor rows before counting. They are
    # therefore different populations and their counts differ -- measured,
    # unfiltered: explicit_c 56 -> 31, explicit_bootstrap_emitter 0 -> 9,
    # explicit_cranelift 119 -> 126, implicit_default 18 -> 14,
    # explicit_invalid_or_parser_probe 3 -> 3, total 196 -> 183, so 16 moved,
    # 9 retired, 4 companion arms; relay: 14 moved, 5 retired, 4 companion
    # arms. Measured on the branch, the relay census is this one minus the
    # Phase 23 successor rows and the runner's live row, plus one substituted
    # Phase 22 projection row.
    #
    # This contract used to share the relay census's
    # `reclassified_invocation_count`, which held only while 24.13 was small
    # enough for both populations to see the same two moves. It cannot be
    # shared now, and the excess cannot be DERIVED either: the registered
    # predecessor censuses are aggregates, so the rows the relay census
    # excluded *then* are not recoverable from them. So the excess is
    # registered as a measured constant rather than computed, and pinned --
    # a later patch that changes which rows the relay census drops moves these
    # two numbers and has to re-measure and say so, which is the property that
    # matters. The companion-arm count is the one quantity the two censuses
    # must still agree on outright, because no retired bare arm sits in the
    # excluded set -- if one ever does, the equality below fails rather than
    # quietly absorbing it.
    removal = registry.get("phase24_13_backend_removal", {}).get(
        "phase22_invocation_successor")
    if removal is None:
        return current
    previous, current = current, removal.get("current_summary")
    require(isinstance(current, dict) and
            removal.get("previous_summary") == previous and
            removal.get("partial_or_unregistered_reclassification") ==
            "rejected",
            "Patch 24.13 Phase 22 invocation successor drifted")
    require(current["unclassified_count"] == previous["unclassified_count"]
            == 0,
            "Patch 24.13 must leave the Phase 22 census fully classified")
    moved = removal.get("unfiltered_reclassified_invocation_count")
    retired_c = removal.get("unfiltered_retired_explicit_c_count")
    retired_companion = removal.get(
        "unfiltered_retired_companion_default_count")
    require(all(isinstance(value, int) for value in
                (moved, retired_c, retired_companion)) and
            moved > 0 and retired_c > 0,
            "Patch 24.13 registered a Phase 22 transition that neither moves "
            "nor retires an explicit-C invocation")
    destinations = ("explicit_bootstrap_emitter", "explicit_cranelift")
    drop = (previous["selection_counts"].get("explicit_c", 0) -
            current["selection_counts"].get("explicit_c", 0))
    rise = sum(current["selection_counts"].get(name, 0) -
               previous["selection_counts"].get(name, 0)
               for name in destinations)
    default_drop = (previous["selection_counts"].get("implicit_default", 0) -
                    current["selection_counts"].get("implicit_default", 0))
    require(moved == rise and drop == moved + retired_c and
            default_drop == retired_companion and
            previous["total"] - current["total"] ==
            retired_c + retired_companion,
            "the Patch 24.13 Phase 22 transition does not balance: registered "
            f"{moved} moved and {retired_c} retired against an explicit-C "
            f"drop of {drop} and a destination rise of {rise}, with "
            f"{default_drop} companion arms against {retired_companion} "
            f"registered and a total drop of "
            f"{previous['total'] - current['total']}. An invocation that "
            "disappeared must not pass as one that moved.")
    for name in set(previous["selection_counts"]) | set(
            current["selection_counts"]):
        if name in {"explicit_c", "implicit_default", *destinations}:
            continue
        require(previous["selection_counts"].get(name, 0) ==
                current["selection_counts"].get(name, 0),
                f"Patch 24.13 moved a selection it does not claim: {name}")
    # The two filterings, reconciled rather than assumed equal.
    relay_moved = removal.get("reclassified_invocation_count")
    relay_retired = removal.get("retired_explicit_c_count")
    require(moved - relay_moved ==
            removal.get("relay_excluded_moved_count") >= 0 and
            retired_c - relay_retired ==
            removal.get("relay_excluded_retired_count") >= 0,
            "the unfiltered and relay censuses disagree by an unregistered "
            f"amount: {moved} vs {relay_moved} moved, {retired_c} vs "
            f"{relay_retired} retired")
    require(retired_companion ==
            removal.get("retired_companion_default_count"),
            "a companion default arm was retired inside a relay-excluded row, "
            "which the two censuses cannot both be measuring")
    return _phase26_ffi_repr_c_invocation_successor(registry,
        _phase26_ffi_position_invocation_successor(registry,
            _phase26_reference_receiver_invocation_successor(
                registry, _issue398_summary_successor(registry, current))))


def _phase26_ffi_repr_c_invocation_successor(registry: dict,
        previous: dict) -> dict:
    successor = registry.get("phase26_activation_audit", {}).get(
        "ffi_repr_c_layout_increment", {}).get("phase22_invocation_successor")
    if successor is None:
        return previous
    rows = successor.get("added_rows")
    require(successor.get("contract_version") ==
            "phase26_1d2_phase22_invocation_successor_v1" and
            successor.get("previous_total") == previous["total"] == 155 and
            successor.get("current_total") == 158 and
            successor.get("partial_extra_or_substituted_invocation") ==
            "rejected" and isinstance(rows, list) and len(rows) == 3 and
            all(row.get("path") == "scripts/phase26_ffi_repr_c_layout.sh" and
                row.get("selection") == "explicit_cranelift" and
                row.get("consumer_class") ==
                "already_explicit_or_parser_probe" and
                row.get("owner") == "cranelift" for row in rows),
            "Phase 26.1D2 invocation successor drifted")
    current = copy.deepcopy(previous)
    current["total"] += len(rows)
    for row in rows:
        for key, label in (("selection_counts", "selection"),
                           ("consumer_class_counts", "consumer_class"),
                           ("owner_counts", "owner")):
            group = str(row[label])
            current[key][group] = current[key].get(group, 0) + 1
    require(current["total"] == successor["current_total"] and
            current["unclassified_count"] == 0,
            "Phase 26.1D2 invocation census did not balance")
    return current


def _phase26_ffi_position_invocation_successor(
        registry: dict, previous: dict) -> dict:
    """Advance the unfiltered census by the four exact D1 native probes."""
    successor = registry.get("phase26_activation_audit", {}).get(
        "ffi_position_policy_increment", {}).get("phase22_invocation_successor")
    if successor is None:
        return previous
    rows = successor.get("added_rows")
    require(successor.get("contract_version") ==
            "phase26_1d1_phase22_invocation_successor_v1" and
            successor.get("previous_total") == previous["total"] == 151 and
            successor.get("current_total") == 155 and
            successor.get("partial_extra_or_substituted_invocation") ==
            "rejected" and isinstance(rows, list) and len(rows) == 4 and
            all(row.get("path") ==
                "scripts/phase26_ffi_position_policy.sh" and
                row.get("selection") == "explicit_cranelift" and
                row.get("consumer_class") ==
                "already_explicit_or_parser_probe" and
                row.get("owner") == "cranelift" for row in rows),
            "Phase 26.1D1 invocation successor drifted")
    current = copy.deepcopy(previous)
    current["total"] += len(rows)
    for row in rows:
        for key, label in (("selection_counts", "selection"),
                           ("consumer_class_counts", "consumer_class"),
                           ("owner_counts", "owner")):
            group = str(row[label])
            current[key][group] = current[key].get(group, 0) + 1
    require(current["total"] == successor["current_total"] and
            current["unclassified_count"] == 0,
            "Phase 26.1D1 invocation census did not balance")
    return current


def _phase26_reference_receiver_invocation_successor(
        registry: dict, previous: dict) -> dict:
    """Admit one native-only prerequisite invocation without rewriting Phase 22."""
    successor = registry.get("phase26_activation_audit", {}).get(
        "reference_receiver_prerequisite", {}).get(
            "phase22_invocation_successor")
    if successor is None:
        return previous
    row = successor.get("added_row")
    require(successor.get("contract_version") ==
            "phase26_reference_receiver_phase22_invocation_successor_v1" and
            successor.get("previous_total") == previous["total"] == 150 and
            successor.get("current_total") == 151 and
            successor.get("partial_extra_or_substituted_invocation") ==
            "rejected" and
            isinstance(row, dict) and
            row.get("path") == "scripts/phase16_reference_receiver_parity.sh" and
            row.get("selection") == "explicit_cranelift" and
            row.get("consumer_class") == "already_explicit_or_parser_probe" and
            row.get("owner") == "cranelift",
            "Phase 26 reference receiver invocation successor drifted")
    current = copy.deepcopy(previous)
    current["total"] += 1
    for key, label in (("selection_counts", "selection"),
                       ("consumer_class_counts", "consumer_class"),
                       ("owner_counts", "owner")):
        group = str(row[label])
        current[key][group] = current[key].get(group, 0) + 1
    require(current["total"] == successor["current_total"] and
            current["unclassified_count"] == 0,
            "Phase 26 reference receiver invocation census did not balance")
    return current


def _issue398_summary_successor(registry: dict, previous: dict) -> dict:
    """Issue #398 on the unfiltered census: a retirement with two survivors.

    The relay-filtered half of this same successor lives in
    scripts/phase22_opening.py and carries the file-level checks, because that
    module can join line continuations the way the scan does. This half owns
    the arithmetic on the unfiltered census and the one number the two must
    agree on: the size of the removal, differing only by the retired rows the
    relay census excludes.

    Nothing is reclassified. Every converted consumer stops invoking a
    compiler rather than invoking a different one, so the explicit-C drop and
    the total drop are the same number. The two invocations left are inverted
    probes asserting the spelling is refused; each is checked here against the
    rejection it claims to assert, so a probe that went back to expecting
    success cannot sit in this census looking like a retired one that got
    missed.
    """
    successor = registry.get("phase398_retained_spelling_removal", {}).get(
        "phase22_invocation_successor")
    if successor is None:
        return previous
    current = successor.get("current_summary")
    require(successor.get("contract_version") ==
            "phase398_invocation_retirement_successor_v1" and
            successor.get("previous_summary") == previous and
            isinstance(current, dict) and
            successor.get("partial_or_unregistered_retirement") == "rejected",
            "Issue #398 Phase 22 invocation successor drifted")
    require(current["unclassified_count"] == previous["unclassified_count"]
            == 0,
            "Issue #398 must leave the Phase 22 census fully classified")

    retired = successor.get("unfiltered_retired_explicit_c_count")
    relay_retired = successor.get("relay_retired_explicit_c_count")
    excluded = successor.get("relay_excluded_retired_count")
    reclassified = successor.get("reclassified_invocation_count")
    require(all(isinstance(value, int) for value in
                (retired, relay_retired, excluded, reclassified)) and
            retired > 0,
            "Issue #398 registered a Phase 22 transition that retires no "
            "explicit-C invocation")
    require(retired - relay_retired == excluded >= 0,
            "the unfiltered and relay censuses disagree by an unregistered "
            f"amount: {retired} vs {relay_retired} retired against "
            f"{excluded} relay-excluded")

    destinations = ("explicit_bootstrap_emitter", "explicit_cranelift")
    drop = (previous["selection_counts"].get("explicit_c", 0) -
            current["selection_counts"].get("explicit_c", 0))
    rise = sum(current["selection_counts"].get(name, 0) -
               previous["selection_counts"].get(name, 0)
               for name in destinations)
    require(rise == reclassified == 0,
            "Issue #398 retires the spelling rather than re-pointing it, but "
            f"{rise} invocations arrive at {destinations}")
    require(drop == retired and previous["total"] - current["total"] == retired,
            f"the Issue #398 Phase 22 transition does not balance: an "
            f"explicit-C drop of {drop} and a total drop of "
            f"{previous['total'] - current['total']} against {retired} "
            "registered as retired")
    for name in set(previous["selection_counts"]) | set(
            current["selection_counts"]):
        if name == "explicit_c":
            continue
        require(previous["selection_counts"].get(name, 0) ==
                current["selection_counts"].get(name, 0),
                f"Issue #398 moved a selection it does not claim: {name}")

    inversions = successor.get("retained_inversions", [])
    require(current["selection_counts"].get("explicit_c", 0) ==
            len(inversions),
            "the explicit-C invocations Issue #398 leaves in the Phase 22 "
            f"census are not the registered inverted probes: "
            f"{current['selection_counts'].get('explicit_c', 0)} against "
            f"{len(inversions)}")
    for row in inversions:
        require(str(row["rejection_marker"]) in
                (ROOT / str(row["path"])).read_text(encoding="utf-8"),
                f"the retained explicit-C invocation in {row['path']} no "
                "longer asserts that the spelling is refused")

    # Patch 25.5 is the first link that ADDS to the census rather than
    # reducing it. Every link above asserts `current["total"] <
    # previous["total"]`, because every one of them was retiring something.
    # Porting the runtime goes the other way: the strings differential has
    # to emit the Gust side to compare it, and that is a real backend
    # invocation the census is entitled to know about.
    #
    # The scan covers Makefile, justfile*, root and scripts/*.sh,
    # tests/*.gst and scripts/*.py. tools/ is NOT scanned, so moving the
    # invocation one directory over would have made this green for free.
    # That is evading an enumeration whose entire purpose is to know where
    # the backend is invoked, so the registered node names the temptation
    # and rejects it rather than leaving it to be rediscovered.
    previous = current
    added = registry.get("phase25_runtime_port_invocations")
    if added is None:
        return previous
    current = added.get("current_summary")
    require(added.get("contract_version") ==
            "phase25_runtime_port_invocation_successor_v1" and
            added.get("owner") == "cranelift" and
            added.get("previous_summary") == previous and
            isinstance(current, dict) and
            added.get("escaping_the_census_by_relocation") == "rejected",
            "Patch 25.5 Phase 22 invocation successor drifted")
    rows = added.get("added_invocation_rows", [])
    count = added.get("added_invocation_count")
    require(isinstance(count, int) and count == len(rows) > 0,
            "Patch 25.5 registered an invocation addition with no rows")
    require(current["total"] - previous["total"] == count and
            current["unclassified_count"] == previous["unclassified_count"]
            == 0,
            "the Patch 25.5 invocation addition does not balance against a "
            "fully classified census")
    # Only the selections the rows claim may move, and only by as many rows
    # as claim them. An addition that quietly re-points an existing
    # invocation would otherwise balance on the total alone.
    claimed: dict[str, int] = {}
    for row in rows:
        claimed[str(row["selection"])] = claimed.get(str(row["selection"]), 0) + 1
    for name in set(previous["selection_counts"]) | set(
            current["selection_counts"]):
        require(current["selection_counts"].get(name, 0) -
                previous["selection_counts"].get(name, 0) ==
                claimed.get(name, 0),
                f"Patch 25.5 moved a selection it does not claim: {name}")
    # A DEPARTURE IS NOT A CHANGE. Patch 25.10a deletes both files Patch
    # 25.5 added an invocation to, and a deleted path does not produce a
    # census row to re-read -- this loop raised FileNotFoundError rather
    # than failing with a diagnosis. Rows the newer link registers as
    # departed are checked for ABSENCE instead, which is the same
    # assertion inverted rather than a hole: a file that came back with
    # its invocation intact still fails here.
    departed = {
        str(row["path"]) for row in
        registry.get("phase2510a_strings_retirement", {})
                .get("invocation_departure", {})
                .get("departed_invocation_rows", [])
    }
    for row in rows:
        path = str(row["path"])
        if path in departed:
            require(not (ROOT / path).exists(),
                    f"{path} is registered as departed by Patch 25.10a but "
                    "is present; the invocation it carries is back in the "
                    "census without a row for it")
            continue
        require(str(row["invocation_marker"]) in
                (ROOT / path).read_text(encoding="utf-8"),
                f"the registered Patch 25.5 invocation in {row['path']} is "
                "no longer there")

    # Patch 25.10a reverses exactly what Patch 25.5 added. Both of 25.5's
    # added rows are in scripts it deletes, so its census returns to the
    # summary 25.5 recorded as its predecessor -- which is asserted here
    # rather than described, because "the counts went back" is the kind of
    # claim that is easy to state and easy to have wrong by one.
    previous = current
    departure = registry.get("phase2510a_strings_retirement", {}).get(
        "invocation_departure")
    if departure is None:
        return previous
    current = departure.get("current_summary")
    require(departure.get("contract_version") ==
            "phase2510a_strings_invocation_departure_v1" and
            departure.get("owner") == "cranelift" and
            departure.get("previous_summary") == previous and
            isinstance(current, dict) and
            departure.get("escaping_the_census_by_relocation") == "rejected",
            "Patch 25.10a Phase 22 invocation departure drifted")
    gone = departure.get("departed_invocation_rows", [])
    count = departure.get("departed_invocation_count")
    require(isinstance(count, int) and count == len(gone) > 0,
            "Patch 25.10a registered an invocation departure with no rows")
    require(previous["total"] - current["total"] == count and
            current["unclassified_count"] == 0,
            "the Patch 25.10a invocation departure does not balance against "
            "a fully classified census")
    claimed = {}
    for row in gone:
        claimed[str(row["selection"])] = claimed.get(str(row["selection"]), 0) + 1
    for name in set(previous["selection_counts"]) | set(
            current["selection_counts"]):
        require(previous["selection_counts"].get(name, 0) -
                current["selection_counts"].get(name, 0) ==
                claimed.get(name, 0),
                f"Patch 25.10a moved a selection it does not claim: {name}")
    # Patch 25.10 goes LAST here, and that is not the same discipline as
    # the text-surface chain in this same file. That chain projects the
    # tree BACKWARDS and runs newest-first. This one walks summaries
    # FORWARDS in time -- `previous = current` then read the next link --
    # so the newest patch is appended, not prepended. Putting 25.10
    # ahead of 25.10a here handed it 25.10a's predecessor and failed as
    # "invocation departure drifted", which names the symptom and not
    # the ordering.
    #
    # It removes the five Makefile invocations of the C stage chain;
    # both censuses read the same registry node, as 25.10a's pair does.
    previous = current
    emitter_departure = registry.get("phase2510_emitter_deletion", {}).get(
        "invocation_departure")
    if emitter_departure is None:
        return previous
    current = emitter_departure.get("current_summary")
    require(emitter_departure.get("contract_version") ==
            "phase2510_emitter_deletion_invocation_departure_v1" and
            emitter_departure.get("owner") == "cranelift" and
            emitter_departure.get("previous_summary") == previous and
            isinstance(current, dict) and
            emitter_departure.get(
                "escaping_the_census_by_relocation") == "rejected",
            "Patch 25.10 Phase 22 invocation departure drifted")
    emitter_gone = emitter_departure.get("departed_invocation_rows", [])
    emitter_count = emitter_departure.get("departed_invocation_count")
    require(isinstance(emitter_count, int)
            and emitter_count == len(emitter_gone) > 0,
            "Patch 25.10 registered an invocation departure with no rows")
    require(current["unclassified_count"] == 0,
            "the Patch 25.10 invocation departure does not balance against "
            "a fully classified census")
    emitter_claimed = {}
    for row in emitter_gone:
        emitter_claimed[str(row["selection"])] = emitter_claimed.get(
            str(row["selection"]), 0) + 1
    # Patch 25.10 both DEPARTS and RECLASSIFIES, and the two are counted
    # separately. Seven invocations leave; one does not leave at all, it
    # CHANGES SPELLING -- the runner's negative path flips from
    # explicit_bootstrap_emitter to explicit_cranelift, so
    # explicit_cranelift goes UP by one while the departures go down.
    #
    # The guard caught this and its own comment says why it exists: "an
    # addition that quietly re-points an existing invocation would
    # otherwise balance on the total alone". A departure-only claim would
    # have made a reclassification look like a disappearance.
    reclassified = emitter_departure.get("reclassified_invocation_rows", [])
    gained = {}
    for row in reclassified:
        gained[str(row["to_selection"])] = gained.get(
            str(row["to_selection"]), 0) + 1
        emitter_claimed[str(row["from_selection"])] = emitter_claimed.get(
            str(row["from_selection"]), 0) + 1
    require(previous["total"] - current["total"] == emitter_count,
            "the Patch 25.10 census total must fall by exactly the "
            "departures; a reclassification does not change the total")
    for name in set(previous["selection_counts"]) | set(
            current["selection_counts"]):
        require(previous["selection_counts"].get(name, 0) -
                current["selection_counts"].get(name, 0) ==
                emitter_claimed.get(name, 0) - gained.get(name, 0),
                f"Patch 25.10 moved a selection it does not claim: {name}")

    return current


def frozen_oracle_successor_digest(registry: dict) -> str | None:
    """Return the exact Patch 24.12 justfile successor when it is registered."""
    oracle = registry.get("phase24_frozen_oracle_replacement")
    if not isinstance(oracle, dict):
        return None
    successor = oracle.get("text_surface_successor")
    if not isinstance(successor, dict):
        return None
    digest = successor.get("live_justfile_successor_digest")
    require(isinstance(digest, str) and len(digest) == 64,
            "Patch 24.12 justfile successor digest drifted")
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
    retirement = contract.get("phase24_3b_coordinate_retirement")
    require(isinstance(retirement, dict),
            "24.3b coordinate retirement contract is missing")
    require(retirement.get("contract_version") ==
            "phase24_3b_coordinate_retirement_v1" and
            retirement.get("status") == "patch24_3b_complete" and
            retirement.get("discharges") ==
            "relay_site_anchor.unretired_coordinates_owner" and
            retirement.get("retired_coordinate") == "line" and
            retirement.get("readmission") == "rejected" and
            retirement.get("census_verdict") ==
            "retained_tripwire_with_registration_drill",
            "24.3b coordinate retirement contract drifted")
    require(retirement.get("invocation_digest_fields") == [
                "path", "recipe", "compiler_token", "selection",
                "consumer_class", "owner", "command",
            ] and
            "line" not in retirement["invocation_digest_fields"],
            "24.3b invocation digest fields drifted")
    require(sorted(retirement.get("live_c_digest_fields", [])) == sorted([
                "case_key", "path", "recipe", "owner", "selection",
                "consumer_class", "compiler_token", "command_digest",
                "owner_file_digest", "complete_case_digest",
            ]) and
            "line" not in retirement["live_c_digest_fields"] and
            "case_id" not in retirement["live_c_digest_fields"],
            "24.3b live-C digest fields drifted")
    require(retirement.get("observation_match_fields") == [
                "path", "recipe", "compiler_token", "selection",
                "consumer_class", "owner", "expected_artifact",
                "expected_transition", "falsifier", "command",
            ] and
            "line" not in retirement["observation_match_fields"],
            "24.3b observation match fields drifted")
    require(retirement.get("opening_review_inventory_columns") == [
                "Path", "Recipe", "Selection", "Class", "Owner",
                "Expected artifact", "Expected transition", "Falsifier",
            ],
            "24.3b opening review columns drifted")
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
    # Patch 24.13: this manifest enrols files by CONTENT, so a file that stops
    # spelling the retired backend stops producing a row and reads here as a
    # removal. That is the phase succeeding, not a regression -- but "the file
    # is gone" and "the file no longer names MIR-to-C" are the same observation
    # from this vantage point, and only one of them is allowed.
    #
    # The successor separates them at the source: each departed path must still
    # be a file on disk, and must match NO surface pattern. Deleting the file
    # fails the first check; leaving any retired spelling behind fails the
    # second; and a path that departed without being registered still fails
    # below, because only registered departures are discharged here.
    departures = registry.get("phase24_13_backend_removal", {}).get(
        "text_surface_departures")
    # Issue #398 retires a landed Stdlib surface of its own, so the registered
    # set is the union of the two. Union rather than replacement: 24.13's two
    # departures are still departed, and a patch that dropped them from the
    # register would stop proving they left by retirement rather than by
    # deletion. Each patch's own paths are still proved below, one at a time.
    spelling_departures = registry.get(
        "phase398_retained_spelling_removal", {}).get(
            "text_surface_departures")
    if spelling_departures is not None:
        require(spelling_departures.get("contract_version") ==
                "phase398_text_surface_departure_v1" and
                spelling_departures.get("deleted_rather_than_retired") ==
                "rejected",
                "Issue #398 text surface departure successor drifted")
    if departures is not None and missing:
        require(departures.get("contract_version") ==
                "phase24_13_text_surface_departure_v1",
                "Patch 24.13 text surface departure successor drifted")
        registered = list(departures.get("paths", []))
        registered += [path for path in
                       (spelling_departures or {}).get("paths", [])
                       if path not in registered]
        # Containment, not equality: this node records every surface that left
        # the content enrolment, and the landed-Stdlib set is a subset of that.
        # Both directions still hold -- an unregistered departure fails here,
        # and every registered departure is proved below to have actually
        # departed rather than merely being listed.
        unregistered = [path for path in missing if path not in registered]
        require(not unregistered,
                "Patch 24.13 Stdlib text surfaces departed without being "
                f"registered: {unregistered}")
        patterns_path = ROOT / "scripts/phase23_mir_to_c_deprecation_opening.py"
        spec = importlib.util.spec_from_file_location(
            "phase23_surface_patterns", patterns_path)
        require(spec is not None and spec.loader is not None,
                "cannot load the Phase 23 surface patterns")
        patterns_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(patterns_module)
        for path in registered:
            surface = ROOT / path
            require(surface.is_file(),
                    "Patch 24.13 registers a Stdlib surface as departed, but "
                    f"the file was deleted rather than retired: {path}")
            text = surface.read_text(encoding="utf-8")
            still = sorted(name for name, pattern
                           in patterns_module.SURFACE_PATTERNS.items()
                           if pattern.search(text))
            require(not still,
                    f"Patch 24.13 records {path} as having left the MIR-to-C "
                    f"text surface, but it still matches {still}")
        missing = []
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
    # Issue #398 converts these consumers onto frozen replay, so the closed
    # Patch 24.2p counts stop describing the tree. The reduction is read from
    # the successor rather than edited into that record, and BOTH counts are
    # checked: a site that vanished fails the same as one that kept an
    # invocation it was supposed to retire.
    retirement = registry.get("phase398_retained_spelling_removal", {})
    retired = {}
    if retirement:
        require(retirement.get("contract_version") ==
                "phase398_landed_site_retirement_v1" and
                retirement.get("partial_or_unregistered_retirement") ==
                "rejected",
                "Issue #398 landed-site retirement successor drifted")
        for row in retirement.get("retired_sites", []):
            retired[(str(row["path"]), str(row["recipe"]))] = row
    for key, count in sorted(sites.items()):
        row = retired.get(key)
        if row is None:
            require(live_counts.get(key, 0) == count,
                    "a landed Stdlib invocation site drifted: "
                    f"{key[0]} {key[1]} {live_counts.get(key, 0)} != {count}")
            continue
        require(int(row["previous_invocation_count"]) == count,
                "Issue #398 records a previous count this manifest never "
                f"pinned: {key[0]} {key[1]} {row['previous_invocation_count']}"
                f" != {count}")
        require(live_counts.get(key, 0) == int(row["current_invocation_count"]),
                "a site Issue #398 retired does not match its registered "
                f"result: {key[0]} {key[1]} {live_counts.get(key, 0)} != "
                f"{row['current_invocation_count']}")
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


def relay_site_anchor(registry: dict) -> dict:
    """Patch 24.3c: the contract for anchoring the relay site without a coordinate.

    Carries the reachability boundary as a tripwire. Layer 1 - this re-anchor -
    is sufficient ONLY for an edit below `highest_ordinary_invocation_row_line`,
    which is where every Stdlib guard recipe and every end-of-file append lives.
    An edit ABOVE it moves other invocation rows and reaches a further five
    comparison sites and two generated reviews, none of which this patch touches.

    Patch 24.3d: scope against `highest_ordinary_invocation_row_line` (23176),
    NOT `highest_invocation_row_line` (23258). The latter names the relay row -
    the one row this contract immunizes by projecting its line away before the
    invocation manifest is hashed - so it over-restricts by 82 lines. Both
    over-restrict and neither under-protects, so nothing was ever wrongly
    admitted; the 24.3c value carried the wrong label, not a wrong number.

    The ordering below is the inversion: a tree that swaps the two values, or
    drops the ordinary boundary, is rejected rather than silently scoped against
    the relay coordinate again.
    """
    contract = pinned_manifest_class_contract(registry)
    anchor = contract.get("relay_site_anchor")
    require(isinstance(anchor, dict), "relay site anchor contract is missing")
    require(anchor.get("contract_version") == "phase24_3c_relay_site_anchor_v1" and
            anchor.get("retired_anchor_field") == "line" and
            anchor.get("rejected_selection") == "implicit_default" and
            anchor.get("drifted_site") == "rejected" and
            isinstance(anchor.get("highest_invocation_row_line"), int) and
            isinstance(anchor.get("highest_ordinary_invocation_row_line"), int) and
            bool(anchor.get("unretired_coordinates_owner")),
            "relay site anchor contract drifted")
    # Patch 24.3d. The ordinary boundary is the live constraint and the relay
    # coordinate is the immunized row above it, so ordinary < relay is what
    # makes the pair mean anything. Swapping them would scope every future edit
    # against the relay row again - the exact conflation this patch corrects -
    # and would do it silently, because both values would still be ints.
    require(anchor["highest_ordinary_invocation_row_line"] <
            anchor["highest_invocation_row_line"],
            "relay site anchor boundary pair is inverted: the ordinary "
            "invocation row must sit above the immunized relay row")
    require(anchor.get("anchor_fields") ==
            ["path", "recipe", "compiler_token", "command", "selection"],
            "relay site anchor fields drifted")
    require("line" not in anchor["anchor_fields"],
            "the retired coordinate was re-admitted as an anchor field")
    return anchor


def normalize_phase22_invocations(
        registry: dict, rows: list[dict[str, object]]) -> list[dict[str, object]]:
    """Project the exact post relay onto the closed Phase 22 site identity."""
    rows = drop_class_appended_invocations(registry, rows)
    value = authority(registry)
    state = live_state(registry)
    site = value["changed_site"]
    anchor = relay_site_anchor(registry)
    matches = [
        row for row in rows
        if row.get("path") == site["path"] and
        row.get("recipe") == site["recipe"] and
        row.get("compiler_token") == site["compiler_token"]
    ]
    # Issue #398 converts this invocation onto frozen replay, so the relay
    # identity it anchored is retired. Both halves are required, because a
    # site that simply vanished would otherwise read as converted.
    relay_retired = registry.get("phase398_retained_spelling_removal", {}).get(
        "relay_site_retirement")
    if relay_retired is not None:
        require(relay_retired.get("contract_version") ==
                "phase398_relay_site_retirement_v1" and
                relay_retired.get("retired_site") == site and
                relay_retired.get("partial_or_unregistered_retirement") ==
                "rejected",
                "Issue #398 relay site retirement successor drifted")
        justfile_text = (ROOT / "justfile").read_text(encoding="utf-8")
        require(str(site["command"]) not in justfile_text,
                "Issue #398 retired the relay site, but its command is back: "
                f"{site['command'][:60]}")
        require(str(relay_retired["replacement_marker"]) in justfile_text,
                "Issue #398 retired the relay site without its replay "
                "replacement, so the site vanished rather than converted")
        require(not matches,
                "the retired relay site still produces an invocation row")
    # Only the relay site's own assertions are skipped once it is retired: the
    # command and route checks, the no-fallback check and the line projection
    # all speak about a row that no longer exists. Everything AFTER them still
    # applies -- in particular Patch 24.1's observation driver, which this
    # function also removes from the projection. An earlier draft returned here
    # instead and left that driver in, which showed up as an implicit_default
    # invocation appearing from nowhere in the census.
    if relay_retired is None:
        require(len(matches) == 1,
                "relay site is missing, duplicated, or substituted")
        match = matches[0]
        # Patch 24.3c: anchor on what the pin MEANS - the recipe that owns the site
        # and the exact command it runs - rather than on where it happens to sit.
        # `line` was an absolute coordinate used as a proxy for a location, so it
        # broke on any insertion above it, including one in an unrelated recipe:
        # Stdlib S1.10 could not edit its own guard recipe without failing seven
        # guards, all reporting this one assertion. recipe + command + selection is
        # what the check was always trying to say, and the evidence is that it is
        # stable across exactly the edit that moved the coordinate.
        require(match.get("command") == site["command"] and
                match.get("selection") == site["selection"],
                "relay site command or route drifted")
        # The no-fallback guarantee, asserted rather than left implied. Relaxing this
        # manifest is lane work ONLY while it never admits an implicit_default
        # invocation, so that condition is a check rather than a promise in prose.
        require(site["selection"] != anchor["rejected_selection"] and
                match.get("selection") != anchor["rejected_selection"],
                "relay site would admit an implicit_default invocation")
        normalized = copy.deepcopy(rows)
        target = next(
            row for row in normalized
            if row.get("path") == site["path"] and
            row.get("recipe") == site["recipe"] and
            row.get("compiler_token") == site["compiler_token"]
        )
        # KEEP THIS. It projects this row's live line onto the frozen coordinate
        # before the invocation manifest is hashed, which is why re-anchoring above
        # does not move invocation_manifest_digest for this row.
        #
        # It immunizes EXACTLY ONE ROW. Measured, because an earlier reading of this
        # line claimed the digest was immunized in general and that is false: a
        # justfile edit above other invocations still moves the digest
        # (f27c56c4... -> aaaf12d4...). Retiring the remaining coordinates is
        # Patch 24.3b's; see relay_site_anchor.unretired_coordinates_owner.
        target["line"] = site["pre_relay_line"]
    else:
        normalized = copy.deepcopy(rows)
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
        # Patch 24.3b: match on what the observation driver IS, not where it
        # sits. `line` was the last coordinate in this match: any edit above
        # the driver in its host file failed every guard with the message
        # below, and the repair was a new successor link recording the same
        # row at a new line. The chain above stays as the history of those
        # moves; the match itself no longer needs one. Duplicates still fail:
        # two rows with the same meaning match twice.
        matches = [row for row in normalized if all(
            row.get(field) == added.get(field) for field in (
                "path", "recipe", "compiler_token", "selection",
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


def rebase_s1_8_surface(registry: dict, rows: list) -> list:
    """Apply Issue #398's one-path S1.8 rebase to a list of expected rows.

    The same successor the S1.8 inventory manifest uses, applied here because
    this projection runs BEFORE the newest-first successor chain further down
    and therefore sees the file at its converted bytes, not at the identity
    S1.8 registered.

    It rewrites exactly one digest, and only from the predecessor it names.
    A row at any other digest is left alone and fails the comparison it was
    going to fail anyway -- the rebase cannot be used to make an unexpected
    identity acceptable.
    """
    successor = registry.get("phase398_retained_spelling_removal", {}).get(
        "s1_8_surface_successor")
    if successor is None:
        return rows
    require(successor.get("contract_version") ==
            "phase398_s1_8_surface_successor_v1" and
            successor.get("partial_or_substituted_surface") == "rejected",
            "Issue #398 S1.8 surface successor drifted")
    # Two shapes reach this. The S1.8 inventory manifest carries bare
    # `{path, digest}` rows, so only the digest moves there. The Phase 23
    # text-surface manifest carries the full classified row, whose match
    # counts the conversion also moved -- a digest-only swap would leave that
    # row claiming seven MIR-to-C mentions in a file that now has twelve. So
    # the full row is registered as a pair and swapped whole.
    rebased = []
    for row in rows:
        if row is not None and str(row.get("path")) == successor["path"]:
            if row == successor.get("previous_row"):
                row = copy.deepcopy(successor["current_row"])
            elif (set(row) == {"path", "digest"} and
                    row.get("digest") == successor["predecessor_digest"]):
                row = copy.deepcopy(row)
                row["digest"] = successor["successor_digest"]
        rebased.append(row)
    return rebased


def phase2510_disenrolled_paths(registry: dict, rows: list) -> set:
    """Surfaces Patch 25.10 takes OUT of the enrolled set without deleting.

    compiler/CRANELIFT_PHASE24_SEMANTIC_SPELLING_INVENTORY.md is generated
    from the live scan. With the emitter deleted the semantic spellings it
    inventoried are gone, so the regenerated document names no retired
    spelling and stops matching -- while remaining a tracked file.

    That is NOT a departure and is deliberately not folded into
    departed_paths. A deleted file cannot quietly come back; a generated
    document can, the moment something re-adds a spelling to it. So the record
    is separate and the assertion is the OPPOSITE PAIR: the file must still
    EXIST, and it must produce NO manifest row. Folding the two together would
    let a deletion pass as a disenrolment and vice versa.

    FIVE links registered this surface -- 25.5, 25.6, 25.7, 24.12b and the
    S1.8 implementation successor -- so the subtraction lives here rather than
    being copied into each of them. An earlier attempt drove it into the links
    by regex and touched 23, which is fitting rather than measuring.
    """
    disenrolment = registry.get("phase2510_emitter_deletion", {}).get(
        "text_surface_disenrolment")
    if disenrolment is None:
        return set()
    require(disenrolment.get("contract_version") ==
            "phase2510_emitter_deletion_text_surface_disenrolment_v1" and
            disenrolment.get("partial_or_substituted_disenrolment") ==
            "rejected",
            "Patch 25.10 text surface disenrolment record drifted")
    live_scan = {row["path"] for row in rows}
    out = set()
    for path in disenrolment["disenrolled_paths"]:
        require((ROOT / path).is_file(),
                f"Patch 25.10 records {path} as disenrolled, but the file is "
                "gone -- that is a departure, and departures restore a "
                "previous row where disenrolments do not")
        require(path not in live_scan,
                f"Patch 25.10 records {path} as disenrolled, but it still "
                "produces a manifest row")
        out.add(path)
    return out


def normalize_phase23_text_surfaces(
        registry: dict, rows: list[dict[str, object]]) -> list[dict[str, object]]:
    """Keep closed Phase 23 projection identity across this exact control-plane relay."""
    d2 = registry.get("phase26_activation_audit", {}).get(
        "ffi_repr_c_layout_increment", {}).get("phase23_text_surface_successor")
    if d2 is not None:
        changed = d2.get("changed_rows")
        added = d2.get("added_row")
        expected_paths = {
            ".github/workflows/pr-fast.yml",
            "compiler/experiments/cranelift/src/full_program.rs",
            "compiler/experiments/cranelift/src/main.rs",
            "compiler/mir_native_backend_full_program_source.gst",
            "justfile", "scripts/cranelift_test_levels.json",
            "scripts/phase21_compiler_support_native_qualification.py",
            "scripts/phase22_opening.py",
            "scripts/phase26_reference_receiver_registration.py",
        }
        require(d2.get("contract_version") ==
                "phase26_1d2_phase23_text_surface_successor_v1" and
                d2.get("partial_extra_or_substituted_surface") ==
                "rejected" and isinstance(changed, list) and
                {entry.get("path") for entry in changed} == expected_paths and
                len(changed) == len(expected_paths) and
                isinstance(added, dict) and
                added.get("path") ==
                "scripts/phase26_ffi_repr_c_registration.py",
                "Phase 26.1D2 text surface successor shape drifted")
        live = {row["path"]: row for row in rows}
        require(live.get(added["path"]) == added,
                "Phase 26.1D2 added text surface drifted")
        for entry in changed:
            row = live.get(entry["path"])
            require(row is not None and
                    row["digest"] == entry["current_digest"] and
                    row["match_counts"] == entry["current_match_counts"] and
                    len(entry["previous_digest"]) == 64,
                    f"Phase 26.1D2 text surface drifted: {entry['path']}")
        rows = [dict(row,
                     digest=next((entry["previous_digest"] for entry in changed
                                  if entry["path"] == row["path"]), row["digest"]),
                     match_counts=next((entry["previous_match_counts"] for entry in changed
                                        if entry["path"] == row["path"]), row["match_counts"]))
                for row in rows if row["path"] != added["path"]]
    ffi = registry.get("phase26_activation_audit", {}).get(
        "ffi_position_policy_increment", {}).get("phase23_text_surface_successor")
    if ffi is not None:
        changed = ffi.get("changed_rows")
        added = ffi.get("added_rows")
        changed_paths = {
            ".github/workflows/pr-fast.yml",
            "compiler/typechecker.gst",
            "justfile",
            "scripts/cranelift_ci_family.py",
            "scripts/cranelift_test_levels.json",
            "scripts/cranelift_test_levels.py",
            "scripts/phase22_opening.py",
            "scripts/phase13_parameter_argument.sh",
            "scripts/phase26_reference_receiver_registration.py",
        }
        require(ffi.get("contract_version") ==
                "phase26_1d1_phase23_text_surface_successor_v1" and
                ffi.get("partial_extra_or_substituted_surface") ==
                "rejected" and isinstance(changed, list) and
                isinstance(added, list) and len(changed) ==
                len(changed_paths) and
                {entry.get("path") for entry in changed} == changed_paths and
                [entry.get("path") for entry in added] == [
                    "scripts/phase26_ffi_position_registration.py"],
                "Phase 26.1D1 text surface successor drifted")
        live = {row["path"]: row for row in rows}
        require(all(live.get(entry["path"]) == entry["current_row"]
                    for entry in changed) and
                all(live.get(entry["path"]) == entry for entry in added),
                "Phase 26.1D1 text surfaces are missing, extra, or "
                "substituted")
        previous = {entry["path"]: entry["previous_row"]
                    for entry in changed}
        added_paths = {entry["path"] for entry in added}
        rows = [previous.get(row["path"], row) for row in rows
                if row["path"] not in added_paths]

    str_direct = registry.get("phase26_activation_audit", {}).get(
        "str_direct_call_prerequisite", {}).get("text_surface_successor", {})
    str_rows = str_direct.get("changed_rows", [])
    str_paths = {
        "compiler/mir_native_backend_full_program_source.gst",
        "scripts/phase13_parameter_argument.sh",
        "scripts/phase21_complete_guard_suite.py",
        "scripts/phase26_reference_receiver_registration.py",
    }
    require(str_direct.get("contract_version") ==
            "phase26_str_direct_call_text_surface_successor_v1" and
            str_direct.get("partial_extra_or_substituted_surface") ==
            "rejected" and
            {row.get("path") for row in str_rows} == str_paths and
            len(str_rows) == len(str_paths),
            "Str direct-call text surface successor drifted")
    str_by_path = {row["path"]: row for row in str_rows}
    live_str_rows = {row["path"]: row for row in rows
                     if row["path"] in str_paths}
    for path, changed in str_by_path.items():
        live = live_str_rows.get(path)
        require(live is not None and
                live["digest"] == changed.get("current_digest") and
                live["match_counts"] == changed.get("current_match_counts") and
                len(changed.get("previous_digest", "")) == 64,
                f"Str direct-call text surface drifted: {path}")
    rows = [dict(row,
                 digest=str_by_path[row["path"]]["previous_digest"],
                 match_counts=str_by_path[row["path"]][
                     "previous_match_counts"])
            if row["path"] in str_by_path else row for row in rows]
    runtime = registry.get("phase26_activation_audit", {}).get(
        "runtime_formal_signature_prerequisite", {}).get(
            "text_surface_successor", {})
    runtime_rows = runtime.get("changed_rows", [])
    runtime_paths = {
        "compiler/experiments/cranelift/src/full_program.rs",
        "compiler/mir_native_backend_full_program_source.gst",
        "scripts/phase13_parameter_argument.sh",
        "scripts/phase21_complete_guard_suite.py",
        "scripts/phase26_reference_receiver_registration.py",
    }
    require(runtime.get("contract_version") ==
            "phase26_runtime_formal_signature_text_surface_successor_v1" and
            runtime.get("partial_extra_or_substituted_surface") ==
            "rejected" and
            {row.get("path") for row in runtime_rows} == runtime_paths and
            len(runtime_rows) == len(runtime_paths),
            "runtime formal signature text surface successor drifted")
    runtime_by_path = {row["path"]: row for row in runtime_rows}
    live_by_path = {row["path"]: row for row in rows}
    for path, changed in runtime_by_path.items():
        live = live_by_path.get(path)
        require(live is not None and
                live["digest"] == changed.get("current_digest") and
                live["match_counts"] == changed.get("current_match_counts") and
                len(changed.get("previous_digest", "")) == 64,
                f"runtime formal signature text surface drifted: {path}")
    rows = [dict(row,
                 digest=runtime_by_path[row["path"]]["previous_digest"],
                 match_counts=runtime_by_path[row["path"]][
                     "previous_match_counts"])
            if row["path"] in runtime_by_path else row for row in rows]
    # The Stdlib S2 opening updates the S1 branded-collections guard's exact
    # native deferral reason after the Phase 26 reference-parameter repair.
    # Accept either the merged guard or that one measured successor, then
    # project it to the merged identity before closed Phase 25/23 links run.
    branded = registry.get("phase26_activation_audit", {}).get(
        "stdlib_s1_branded_collections_guard_successor")
    require(branded == {
        "contract_version": "phase26_s2_branded_collections_guard_successor_v1",
        "path": "scripts/stdlib_s1_branded_collections_parity.sh",
        "previous_digest":
            "94175540c66343b20bd16a98af324684376d9fc717382ba895c0473cb122f94f",
        "current_digest":
            "2ab852165d09d4d4f4a4aa37446d68ddd212a5e578c6ce90cb202ad3ab8e6af9",
        "match_counts": {
            "explicit_backend_spelling": 0,
            "generated_c_contract": 1,
            "mir_to_c_name": 2,
        },
        "owner": "cranelift",
        "stdlib_pull_request": 477,
        "partial_extra_or_substituted_surface": "rejected",
    }, "Phase 26 Stdlib S1 branded-collections guard successor drifted")
    branded_rows = [row for row in rows if row["path"] == branded["path"]]
    require(len(branded_rows) == 1 and
            branded_rows[0]["digest"] in (
                branded["previous_digest"], branded["current_digest"]) and
            branded_rows[0]["match_counts"] == branded["match_counts"],
            "Phase 26 Stdlib S1 branded-collections guard is missing, "
            "extra, or substituted")
    rows = [dict(row, digest=branded["previous_digest"])
            if row["path"] == branded["path"] else row for row in rows]
    # The S1 Clone destination guard changes its measured pre-driver reason
    # after native Str direct calls are qualified. Keep the closed Phase 25
    # identity while accepting exactly the Stdlib-owned guard correction.
    clone = registry.get("phase26_activation_audit", {}).get(
        "stdlib_s1_clone_destination_guard_successor")
    require(clone == {
        "contract_version": "phase26_s1_clone_destination_guard_successor_v1",
        "path": "scripts/stdlib_s1_clone_destination_parity.sh",
        "previous_digest":
            "4292d7b3dc06b4b976925ed8c1e32529f895f8c9061a09938f8fa636d177fbc5",
        "current_digest":
            "57ab9e004b976b41d626e0279e39b73e6e3e17693108a3a8ae1ac8b71fa2c548",
        "match_counts": {
            "explicit_backend_spelling": 0,
            "generated_c_contract": 0,
            "mir_to_c_name": 2,
        },
        "owner": "cranelift",
        "stdlib_branch": "codex/stdlib-clone-destination-deferral",
        "partial_extra_or_substituted_surface": "rejected",
    }, "Phase 26 Stdlib S1 Clone destination guard successor drifted")
    clone_rows = [row for row in rows if row["path"] == clone["path"]]
    require(len(clone_rows) == 1 and
            clone_rows[0]["digest"] in (
                clone["previous_digest"], clone["current_digest"]) and
            clone_rows[0]["match_counts"] == clone["match_counts"],
            "Phase 26 Stdlib S1 Clone destination guard is missing, "
            "extra, or substituted")
    rows = [dict(row, digest=clone["previous_digest"])
            if row["path"] == clone["path"] else row for row in rows]

    # The S1 Composition guard keeps its frozen C runtime result while its
    # native pre-driver reason tracks the qualified reference/Str route.
    # Accept only the measured Stdlib-owned correction before projecting to
    # the closed Phase 25 text-surface identity.
    composition = registry.get("phase26_activation_audit", {}).get(
        "stdlib_s1_composition_guard_successor")
    require(composition == {
        "contract_version": "phase26_s1_composition_guard_successor_v1",
        "path": "scripts/stdlib_s1_composition_parity.sh",
        "previous_digest":
            "ee7e47345762aee97da1bf0f6953543f4366c0f7e75e46022e0099a9cf425911",
        "current_digest":
            "2c8cf28422bd906135b007511823a8269302947d33f4c2914c09694851086c61",
        "match_counts": {
            "explicit_backend_spelling": 0,
            "generated_c_contract": 0,
            "mir_to_c_name": 4,
        },
        "owner": "cranelift",
        "stdlib_branch": "codex/stdlib-composition-deferral",
        "partial_extra_or_substituted_surface": "rejected",
    }, "Phase 26 Stdlib S1 Composition guard successor drifted")
    composition_rows = [row for row in rows
                        if row["path"] == composition["path"]]
    require(len(composition_rows) == 1 and
            composition_rows[0]["digest"] in (
                composition["previous_digest"],
                composition["current_digest"]) and
            composition_rows[0]["match_counts"] ==
                composition["match_counts"],
            "Phase 26 Stdlib S1 Composition guard is missing, extra, "
            "or substituted")
    rows = [dict(row, digest=composition["previous_digest"])
            if row["path"] == composition["path"] else row for row in rows]

    prerequisite = registry.get("phase26_activation_audit", {}).get(
        "reference_receiver_prerequisite", {})
    successor = prerequisite.get("phase23_text_surface_successor")
    if successor is not None:
        phase23_closure_path = successor.get("phase23_closure_path")
        full_program_path = successor.get("full_program_path")
        phase22_path = successor.get("phase22_path")
        phase13_path = successor.get("phase13_path")
        added = successor.get("added_row")
        corrective_rows = successor.get("corrective_changed_rows", [])
        corrective_paths = {
            "compiler/CRANELIFT_PHASE19_COMPOSITION.md",
            "compiler/mir_native_backend_full_program_source.gst",
            "scripts/phase19_composition.py",
            "scripts/phase19_composition_parity.sh",
            "scripts/phase20_exact_brand_boundary.sh",
            "scripts/phase21_complete_guard_suite.py",
        }
        require(successor.get("contract_version") ==
                "phase26_reference_receiver_phase23_text_surface_successor_v1" and
                phase23_closure_path == "scripts/phase23_closure.py" and
                full_program_path ==
                "compiler/experiments/cranelift/src/full_program.rs" and
                phase22_path == "scripts/phase22_opening.py" and
                phase13_path == "scripts/phase13_parameter_argument.sh" and
                isinstance(added, dict) and
                added.get("path") ==
                "scripts/phase26_reference_receiver_registration.py" and
                isinstance(corrective_rows, list) and
                {row.get("path") for row in corrective_rows} ==
                corrective_paths and len(corrective_rows) ==
                len(corrective_paths) and
                successor.get("partial_extra_or_substituted_surface") ==
                "rejected",
                "Phase 26 reference receiver text surface successor drifted")
        phase23_closure_rows = [row for row in rows
                                if row["path"] == phase23_closure_path]
        full_program_rows = [row for row in rows
                             if row["path"] == full_program_path]
        phase22_rows = [row for row in rows if row["path"] == phase22_path]
        phase13_rows = [row for row in rows if row["path"] == phase13_path]
        added_rows = [row for row in rows if row["path"] == added["path"]]
        require(len(phase23_closure_rows) == 1 and
                phase23_closure_rows[0]["digest"] ==
                successor["current_phase23_closure_digest"] and
                len(full_program_rows) == 1 and
                full_program_rows[0]["digest"] ==
                successor["current_full_program_digest"] and
                len(phase22_rows) == 1 and
                phase22_rows[0]["digest"] ==
                successor["current_phase22_digest"] and
                len(phase13_rows) == 1 and
                phase13_rows[0]["digest"] ==
                successor["current_phase13_digest"] and
                added_rows == [added],
                "Phase 26 reference receiver text surfaces are missing, "
                "extra, or substituted")
        corrective_previous = {}
        for changed in corrective_rows:
            path = changed["path"]
            live = [row for row in rows if row["path"] == path]
            require(len(live) == 1 and
                    live[0]["digest"] == changed.get("current_digest") and
                    live[0]["match_counts"] ==
                    changed.get("current_match_counts") and
                    set(changed) == {"path", "previous_digest",
                                     "current_digest", "previous_match_counts",
                                     "current_match_counts"},
                    f"Phase 26 corrective text surface drifted: {path}")
            previous = dict(live[0])
            previous["digest"] = changed["previous_digest"]
            previous["match_counts"] = changed["previous_match_counts"]
            corrective_previous[path] = previous
        previous_phase23_closure = dict(phase23_closure_rows[0])
        previous_phase23_closure["digest"] = successor[
            "previous_phase23_closure_digest"]
        previous_full_program = dict(full_program_rows[0])
        previous_full_program["digest"] = successor[
            "previous_full_program_digest"]
        previous_phase22 = dict(phase22_rows[0])
        previous_phase22["digest"] = successor["previous_phase22_digest"]
        previous_phase13 = dict(phase13_rows[0])
        previous_phase13["digest"] = successor["previous_phase13_digest"]
        rows = [previous_phase23_closure if row["path"] ==
                phase23_closure_path else
                previous_full_program if row["path"] == full_program_path else
                previous_phase22 if row["path"] == phase22_path else
                previous_phase13 if row["path"] == phase13_path else row
                for row in rows if row["path"] != added["path"]]
        rows = [corrective_previous.get(row["path"], row) for row in rows]

    # Phase 26 activation moves the active pointer in TASK.md. The older
    # Patch 25.12b successor enrolled that file and must keep its exact
    # historical post-state. Register the complete new control-plane change
    # and project it back before any of the closed links below run.
    activation = registry.get("phase26_activation_audit", {}).get(
        "text_surface_successor")
    require(isinstance(activation, dict) and
            activation.get("contract_version") ==
            "phase26_activation_audit_text_surface_successor_v1" and
            activation.get("partial_extra_or_substituted_surface") ==
            "rejected",
            "Phase 26 activation text surface successor is missing or drifted")
    activation_paths = list(activation["registered_changed_paths"])
    activation_pre = {r["path"]: r for r in
                      activation["previous_changed_text_surfaces"]}
    activation_post = {r["path"]: r for r in
                       activation["current_changed_text_surfaces"]}
    require(sorted(activation_pre) == sorted(activation_paths) ==
            sorted(activation_post),
            "Phase 26 activation registered paths and rows disagree")
    activation_live = {r["path"]: r for r in rows
                       if r["path"] in activation_paths}
    require(sorted(activation_live) == sorted(activation_paths),
            "Phase 26 activation registered surface is missing from the scan")
    require(activation_live == activation_post,
            "Phase 26 activation text surfaces drifted from their registered "
            "successor state")
    rows = [dict(activation_pre.get(r["path"], r)) for r in rows]

    # Computed once for every link below. Five of them registered the
    # surface Patch 25.10 disenrols, so each subtracts the SAME set rather
    # than carrying its own idea of what left.
    disenrolled = phase2510_disenrolled_paths(registry, rows)
    # ORDER CORRECTED ON THE MERGE. Patch 25.9's comment below still says
    # it runs FIRST "because it is the newest link", and that was true on
    # its own branch. On this tree 25.10a and then 25.10 landed after it,
    # so they lead and 25.9 follows -- newest-first, as every link here
    # does. Left 25.9's wording alone rather than rewriting a record of
    # what was true when it was written; the ordering is what has to be
    # right, and it is stated here.
    # MERGE ORDER, and it is not arbitrary: Patch 25.10 is newer than
    # 25.10a, which is newer than 25.7, so they run in that order and
    # each hands the next the tree it was registered against. 25.10a
    # is 25.10's prerequisite -- it takes two explicit_bootstrap_emitter
    # sites out of the census before 25.10 counts them -- so putting
    # 25.10a first here would hand 25.10 a tree one patch behind.
    # A DEPARTURE FIRST, for the reason 25.9's block gives about the seed:
    # compiler/test_runner_bootstrap_bridge_entry.gst is deleted, so it
    # stops producing a manifest row, and Patch 24.13 registered it as a
    # surface that exists. It did exist when 24.13 was written. Restoring
    # the row here lets 24.13 go on comparing what it froze, instead of
    # its evidence being edited for a file that was genuinely present.
    #
    # The tidier-looking move -- deleting the bridge entry's row from
    # 24.13's block -- destroys the record.
    emitter_departure_surface = registry.get(
        "phase2510_emitter_deletion", {}).get("text_surface_departure")
    if emitter_departure_surface is not None:
        require(emitter_departure_surface.get("contract_version") ==
                "phase2510_emitter_deletion_text_surface_departure_v1" and
                emitter_departure_surface.get(
                    "partial_or_substituted_departure") == "rejected",
                "Patch 25.10 emitter departure record drifted")
        departed = list(emitter_departure_surface["departed_paths"])
        live = {row["path"] for row in rows}
        present = [path for path in departed if path in live]
        require(not present,
                f"Patch 25.10 records {present} as departed, but they still "
                "produce a manifest row. A departure that did not happen is "
                "a row restored on top of a live one, counted twice.")
        restored = emitter_departure_surface["departed_previous_rows"]
        require(sorted(row["path"] for row in restored) == sorted(departed),
                "Patch 25.10 does not carry exactly one previous row per "
                "departed surface")
        rows = sorted(list(rows) + [dict(row) for row in restored],
                      key=lambda row: str(row["path"]))
    # The Phase 9G historical guard repair follows 25.12c. Project its
    # registered text surfaces back before checking the older links: the
    # justfile assertion changed with 25.12b's linker call, and adding this
    # registry key also changes the registry loader's enrolled text.
    history_guard_surface = registry.get(
        "phase25_historical9g_guard_repair", {}).get("text_surface_successor")
    if history_guard_surface is not None:
        require(history_guard_surface.get("contract_version") ==
                "phase25_historical9g_guard_repair_text_surface_successor_v1" and
                history_guard_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Phase 9G historical guard repair text surface successor drifted")
        hg_paths = list(history_guard_surface["registered_changed_paths"])
        hg_pre = {r["path"]: r for r
                  in history_guard_surface["previous_changed_text_surfaces"]}
        hg_post = {r["path"]: r for r
                   in history_guard_surface["current_changed_text_surfaces"]}
        require(sorted(hg_pre) == sorted(hg_paths) == sorted(hg_post),
                "Phase 9G historical guard repair paths and rows disagree")
        hg_live = {r["path"]: r for r in rows if r["path"] in hg_paths}
        require(sorted(hg_live) == sorted(hg_paths),
                "Phase 9G historical guard repair text surface is missing "
                f"from the scan: {sorted(set(hg_paths) - set(hg_live))}")
        require(hg_live in (hg_pre, hg_post),
                "Phase 9G historical guard repair text surfaces are partial "
                "or substituted")
        rows = [dict(hg_pre.get(r["path"], r)) for r in rows]
    # Patch 25.12c is newer than 25.12b, so it runs first. It is record
    # keeping, not a route change: the Phase 25 Status section had 25.10a
    # and 25.10 unticked though both merged, had no row for 25.12b, and still
    # headed Patch 25.0 IN PROGRESS. docs/PHASE25_ROADMAP.md is pinned by
    # three landed patches, so correcting it needs this link -- and the
    # failure without it names Patch 25.10, the OLDER link that notices,
    # because 25.12b's block does not carry the roadmap and passes it through.
    status_surface = registry.get(
        "phase2512c_status_record", {}).get("text_surface_successor")
    if status_surface is not None:
        require(status_surface.get("contract_version") ==
                "phase2512c_status_record_text_surface_successor_v1" and
                status_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Patch 25.12c status record text surface successor drifted")
        sr_paths = list(status_surface["registered_changed_paths"])
        sr_pre = {r["path"]: r for r
                  in status_surface["previous_changed_text_surfaces"]}
        sr_post = {r["path"]: r for r
                   in status_surface["current_changed_text_surfaces"]}
        require(sorted(sr_pre) == sorted(sr_paths) == sorted(sr_post),
                "Patch 25.12c registered paths and rows disagree")
        sr_live = {r["path"]: r for r in rows if r["path"] in sr_paths}
        require(sorted(sr_live) == sorted(sr_paths),
                "Patch 25.12c registered text surface is missing from the "
                f"scan: {sorted(set(sr_paths) - set(sr_live))}")
        require(sr_live in (sr_pre, sr_post),
                "Patch 25.12c changed text surfaces are partial or "
                "substituted: the live rows match neither the complete "
                "predecessor state nor the complete successor state "
                f"({sorted(p for p in sr_paths if sr_live[p] != sr_post[p])} "
                "differ from post)")
        rows = [dict(sr_pre.get(r["path"], r)) for r in rows]
    # Patch 25.12b is newer than 25.10, so IT runs first and projects the
    # tree back to the state 25.10's successor was registered against. Same
    # newest-first discipline as every link below: this chain walks
    # BACKWARDS, so a new link PREPENDS. (The invocation-summary chains in
    # phase22_opening.py and this file walk the other way and append; getting
    # it wrong fails as "drifted" rather than as an ordering complaint.)
    #
    # It retires src/runtime.c, the last runtime C source. The file itself
    # carries no departed half: it never matched a surface pattern -- its
    # prose says "the emitted-C route" while the pattern is generated[-_ ]C
    # -- so, exactly as with fiber.c in 25.6 and strings.c in 25.10a, there
    # is no manifest row to depart and the scan's row count is unchanged.
    # What moves is the seventeen surfaces that STOPPED naming it.
    runtime_c_surface = registry.get(
        "phase2512b_runtime_c_retirement", {}).get("text_surface_successor")
    if runtime_c_surface is not None:
        require(runtime_c_surface.get("contract_version") ==
                "phase2512b_runtime_c_retirement_text_surface_successor_v1" and
                runtime_c_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Patch 25.12b runtime-C retirement text surface successor "
                "drifted")
        rc_paths = list(runtime_c_surface["registered_changed_paths"])
        rc_pre = {r["path"]: r for r
                  in runtime_c_surface["previous_changed_text_surfaces"]}
        rc_post = {r["path"]: r for r
                   in runtime_c_surface["current_changed_text_surfaces"]}
        require(sorted(rc_pre) == sorted(rc_paths) == sorted(rc_post),
                "Patch 25.12b registered paths and rows disagree")
        rc_live = {r["path"]: r for r in rows if r["path"] in rc_paths}
        require(sorted(rc_live) == sorted(rc_paths),
                "Patch 25.12b registered text surface is missing from the "
                f"scan: {sorted(set(rc_paths) - set(rc_live))}")
        require(rc_live in (rc_pre, rc_post),
                "Patch 25.12b changed text surfaces are partial or "
                "substituted: the live rows match neither the complete "
                "predecessor state nor the complete successor state "
                f"({sorted(p for p in rc_paths if rc_live[p] != rc_post[p])} "
                "differ from post)")
        rows = [dict(rc_pre.get(r["path"], r)) for r in rows]
    # Patch 25.10 merges after 25.7, so it is the newest link and runs
    # FIRST. It records a finding and changes no route, so what moves is
    # the roadmap and the registry key above.
    emitter_del_surface = registry.get(
        "phase2510_emitter_deletion", {}).get("text_surface_successor")
    if emitter_del_surface is not None:
        require(emitter_del_surface.get("contract_version") ==
                "phase2510_emitter_deletion_text_surface_successor_v1" and
                emitter_del_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Patch 25.10 emitter deletion text surface successor drifted")
        ed_paths = list(emitter_del_surface["registered_changed_paths"])
        ed_pre = {r["path"]: r for r
                  in emitter_del_surface["previous_changed_text_surfaces"]}
        ed_post = {r["path"]: r for r
                   in emitter_del_surface["current_changed_text_surfaces"]}
        require(sorted(ed_pre) == sorted(ed_paths) == sorted(ed_post),
                "Patch 25.10 registered paths and rows disagree")
        ed_live = {r["path"]: r for r in rows if r["path"] in ed_paths}
        require(sorted(ed_live) == sorted(ed_paths),
                "Patch 25.10 registered text surface is missing from the scan")
        require(ed_live in (ed_pre, ed_post),
                "Patch 25.10 changed text surfaces are partial or "
                "substituted: the live rows match neither the complete "
                "predecessor state nor the complete successor state "
                f"({sorted(p for p in ed_paths if ed_live[p] != ed_post[p])} differ from post)")
        rows = [dict(ed_pre.get(r["path"], r)) for r in rows]
        # The guard this patch adds is itself an enrolled surface: the scan
        # matches on CONTENT, and a script about `--backend bootstrap-emitter`
        # necessarily contains the spelling. Added surfaces carry one
        # registered row rather than a pre/post pair, and are dropped from
        # the rows the older links see -- those links were registered
        # against a tree where this file did not exist.
        ed_added = set(emitter_del_surface["added_text_surfaces"])
        ed_rows = {r["path"]: r for r
                   in emitter_del_surface["added_text_surface_rows"]}
        require(sorted(ed_rows) == sorted(ed_added),
                "Patch 25.10 added paths and rows disagree")
        ed_live_added = {r["path"]: r for r in rows if r["path"] in ed_added}
        require(sorted(ed_live_added) == sorted(ed_added),
                "Patch 25.10 added text surface is missing from the scan: "
                f"{sorted(ed_added - set(ed_live_added))}")
        for path in sorted(ed_added):
            require(ed_live_added[path] == ed_rows[path],
                    "Patch 25.10 added text surface does not match its "
                    f"registered row: {path}")
        rows = [r for r in rows if r["path"] not in ed_added]
    # Patch 25.10a is newer than 25.7, so it runs FIRST and projects the
    # tree back to the state 25.7's successor was registered against. Same
    # newest-first discipline as every link below it.
    #
    # It retires src/runtime/strings.c into the Rust crate. That file is
    # DELETED, but it never matched a surface pattern -- generated C with
    # no mention of generated C in it -- so, exactly as with fiber.c in
    # 25.6, there is no departed half for this block to carry and the
    # scan's row count is unchanged.
    #
    # Seven surfaces move, and two of them are this registration itself:
    # cranelift_registry.py and the schema both list the top-level key
    # this patch adds, so registering the change changes them. That is the
    # toll having a toll, not a mistake -- they are carried here rather
    # than left to fail the older links they are pinned in.
    strings_surface = registry.get(
        "phase2510a_strings_retirement", {}).get("text_surface_successor")
    if strings_surface is not None:
        require(strings_surface.get("contract_version") ==
                "phase2510a_strings_retirement_text_surface_successor_v1" and
                strings_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Patch 25.10a strings retirement text surface successor drifted")
        st_paths = list(strings_surface["registered_changed_paths"])
        st_pre = {r["path"]: r for r
                  in strings_surface["previous_changed_text_surfaces"]}
        st_post = {r["path"]: r for r
                   in strings_surface["current_changed_text_surfaces"]}
        require(sorted(st_pre) == sorted(st_paths) == sorted(st_post),
                "Patch 25.10a registered paths and rows disagree")
        st_live = {r["path"]: r for r in rows if r["path"] in st_paths}
        require(sorted(st_live) == sorted(st_paths),
                "Patch 25.10a registered text surface is missing from the scan")
        require(st_live in (st_pre, st_post),
                "Patch 25.10a changed text surfaces are partial or "
                "substituted: the live rows match neither the complete "
                "predecessor state nor the complete successor state "
                f"({sorted(p for p in st_paths if st_live[p] != st_post[p])} differ from post)")
        rows = [dict(st_pre.get(r["path"], r)) for r in rows]
    # Patch 25.9 runs FIRST because it is the newest link, and because it is
    # a DEPARTURE rather than a change: gust_v4.c is deleted, so it stops
    # producing a manifest row at all. Every block below this one registered
    # the seed as a surface that exists, and they are right -- it did, when
    # they were written. Restoring the row here lets them go on comparing
    # what they froze, instead of rewriting their evidence for a file that
    # was genuinely present at the time.
    #
    # The alternative, deleting the seed's row from each older block, is the
    # move that looks tidier and quietly destroys the record.
    departure = (registry.get("phase259_seed_cutover", {})
                 .get("text_surface_departure"))
    if departure is not None:
        require(departure.get("contract_version") ==
                "phase259_seed_cutover_text_surface_departure_v1" and
                departure.get("partial_or_substituted_departure") ==
                "rejected",
                "Patch 25.9 seed departure record drifted")
        departed = list(departure["departed_paths"])
        live = {row["path"] for row in rows}
        present = [path for path in departed if path in live]
        require(not present,
                f"Patch 25.9 records {present} as departed, but they still "
                "produce a manifest row. A departure that did not happen is "
                "a row restored on top of a live one, counted twice.")
        restored = departure["departed_previous_rows"]
        require(sorted(row["path"] for row in restored) == sorted(departed),
                "Patch 25.9 does not carry exactly one previous row per "
                "departed surface")
        rows = sorted(list(rows) + [dict(row) for row in restored],
                      key=lambda row: str(row["path"]))
    # ...and then 25.9's ordinary changed surfaces, projected back the same
    # way every other link does it. The departure above and this are two
    # different things and both are needed: one row LEFT the scan, two
    # others CHANGED, and a block that handled only the departure would
    # leave the changed pair looking like drift to 25.5.
    cutover = (registry.get("phase259_seed_cutover", {})
               .get("text_surface_successor"))
    if cutover is not None:
        require(cutover.get("contract_version") ==
                "phase259_seed_cutover_text_surface_successor_v1" and
                cutover.get("partial_extra_or_substituted_surface") ==
                "rejected",
                "Patch 25.9 seed cut-over text surface successor drifted")
        sc_paths = list(cutover["registered_changed_paths"])
        sc_pre = {r["path"]: r for r in cutover["previous_changed_text_surfaces"]}
        sc_post = {r["path"]: r for r in cutover["current_changed_text_surfaces"]}
        require(sorted(sc_pre) == sorted(sc_paths) == sorted(sc_post),
                "Patch 25.9 registered paths and rows disagree")
        sc_live = {r["path"]: r for r in rows if r["path"] in sc_paths}
        require(sorted(sc_live) == sorted(sc_paths),
                "Patch 25.9 registered text surface is missing from the scan")
        require(sc_live in (sc_pre, sc_post),
                "Patch 25.9 changed text surfaces are partial or substituted: "
                "the live rows match neither the complete predecessor state "
                "nor the complete successor state "
                f"({sorted(p for p in sc_paths if sc_live[p] != sc_post[p])} differ from post)")
        rows = [dict(sc_pre.get(r["path"], r)) for r in rows]
    rows = drop_class_appended_text_surfaces(registry, rows)
    living_paths = class_living_paths(
        pinned_manifest_class_contract(registry))
    value = authority(registry)
    state = live_state(registry)
    s1_successor = s1_8_successor(value)
    coordination = s1_8_coordination_successor(registry, s1_successor)
    provider = provider_docs_successor(coordination)
    provider_state = provider_docs_state(coordination, registry)
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
        expected_current = rebase_s1_8_surface(registry, expected_current)
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
        added = rebase_s1_8_surface(
            registry, [coordination["added_phase23_text_surface"]])[0]
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
    # Patch 24.3b: this successor carries the one stored aggregate manifest
    # digest that is compared against a value derived from the live tree, so it
    # is the one the retirement kept. The guard used to fall back to the S1.9
    # implementation successor's copy when this one was absent; that copy was
    # retired with the other fifty-nine, so the successor is now required to be
    # present. The requirement is asserted here, where the successor is read,
    # not where the digest is used: everything below is derived from
    # auth_paths, so a check placed further down could never be the one that
    # fires - the inversion for a missing successor proved exactly that.
    require(isinstance(auth, dict),
            "Patch 24.2g-auth seed identity successor is missing")
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
    auth_paths: list[str] = auth["registered_changed_paths"]
    union_paths = changed_paths + [
        path for path in auth_paths if path not in changed_paths]
    # A path registered by Patch 24.2g-auth is judged by that successor instead,
    # since this patch moves it beyond the identity Patch 24.2f pinned.
    # Patch 24.12 adds a fourth source, for the same reason Patch 24.3b added a
    # third: this patch moves scripts/cranelift_test_levels.json by registering
    # its own two guards, and widening the closed Patch 24.2f registration
    # instead would rewrite what that record claims 24.2f registered.
    oracle_surface = registry.get("phase24_frozen_oracle_replacement", {}).get(
        "text_surface_successor")
    oracle_paths: list[str] = []
    if oracle_surface is not None:
        require(oracle_surface.get("contract_version") ==
                "phase24_12_frozen_oracle_text_surface_successor_v1" and
                oracle_surface.get("status") == "patch24_12_complete" and
                oracle_surface.get("authority_base_main") ==
                "8aa9922eb40ad404647a86f865f0790ab37a3589" and
                isinstance(oracle_surface.get("added_text_surfaces"),
                           list) and
                isinstance(oracle_surface.get("removed_text_surfaces"),
                           list) and
                oracle_surface.get("partial_extra_or_substituted_surface") ==
                "rejected",
                "Patch 24.12 text surface successor drifted")
        oracle_paths = list(oracle_surface["registered_changed_paths"])
    # Patch 25.7 merges after 25.5, so it is the newest link and runs
    # FIRST. It adds a guard and a workflow step and changes no route, so
    # what moves here is the roadmap, the justfile and the surfaces its
    # own findings edited.
    chain_surface = registry.get(
        "phase257_native_stage_chain", {}).get("text_surface_successor")
    if chain_surface is not None:
        require(chain_surface.get("contract_version") ==
                "phase257_native_stage_chain_text_surface_successor_v1" and
                chain_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Patch 25.7 native stage chain text surface successor drifted")
        ch_paths = list(chain_surface["registered_changed_paths"])
        ch_pre = {r["path"]: r for r
                  in chain_surface["previous_changed_text_surfaces"]}
        ch_post = {r["path"]: r for r
                   in chain_surface["current_changed_text_surfaces"]}
        require(sorted(ch_pre) == sorted(ch_paths) == sorted(ch_post),
                "Patch 25.7 registered paths and rows disagree")
        ch_expected = [p for p in ch_paths if p not in disenrolled]
        ch_pre = {k: r for k, r in ch_pre.items() if k in ch_expected}
        ch_post = {k: r for k, r in ch_post.items() if k in ch_expected}
        ch_live = {r["path"]: r for r in rows if r["path"] in ch_expected}
        require(sorted(ch_live) == sorted(ch_expected),
                "Patch 25.7 registered text surface is missing from the scan")
        require(ch_live in (ch_pre, ch_post),
                "Patch 25.7 changed text surfaces are partial or "
                "substituted: the live rows match neither the complete "
                "predecessor state nor the complete successor state "
                f"({sorted(p for p in ch_expected if ch_live[p] != ch_post[p])} differ from post)")
        rows = [dict(ch_pre.get(r["path"], r)) for r in rows]
    # Patch 25.5 merges after 25.6, so it is the newest link and runs
    # FIRST. Twelve enrolled surfaces changed; none were added or removed.
    # Deleting five C files removed no row, because none of the five was
    # enrolled -- the scan matches on CONTENT, and a runtime .c mentioning
    # no backend spelling was never in it. The count stays at 581.
    #
    # docs/PHASE25_BOOTSTRAP_SEED_POLICY.md changed here too and is
    # deliberately absent, for the reason given in the 25.6 block below:
    # it is an ADDED surface with a single registered row, so there is no
    # predecessor state to project it back to.
    port_surface = registry.get(
        "phase255_runtime_to_gust", {}).get("text_surface_successor")
    if port_surface is not None:
        require(port_surface.get("contract_version") ==
                "phase255_runtime_to_gust_text_surface_successor_v1" and
                port_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Patch 25.5 runtime-to-Gust text surface successor drifted")
        pt_paths = list(port_surface["registered_changed_paths"])
        pt_pre = {r["path"]: r for r
                  in port_surface["previous_changed_text_surfaces"]}
        pt_post = {r["path"]: r for r
                   in port_surface["current_changed_text_surfaces"]}
        require(sorted(pt_pre) == sorted(pt_paths) == sorted(pt_post),
                "Patch 25.5 registered paths and rows disagree")
        pt_expected = [p for p in pt_paths if p not in disenrolled]
        pt_pre = {k: r for k, r in pt_pre.items() if k in pt_expected}
        pt_post = {k: r for k, r in pt_post.items() if k in pt_expected}
        pt_live = {r["path"]: r for r in rows if r["path"] in pt_expected}
        require(sorted(pt_live) == sorted(pt_expected),
                "Patch 25.5 registered text surface is missing from the scan")
        require(pt_live in (pt_pre, pt_post),
                "Patch 25.5 changed text surfaces are partial or "
                "substituted: the live rows match neither the complete "
                "predecessor state nor the complete successor state "
                f"({sorted(p for p in pt_expected if pt_live[p] != pt_post[p])} differ from post)")
        rows = [dict(pt_pre.get(r["path"], r)) for r in rows]
    # Patch 24.13 runs before 24.12b for the same reason 24.12b runs before
    # 24.12a: the newest link projects the tree back to the state the older
    # successors were registered against, so each hands the next the tree it
    # expects.
    # Patch 24.14 is newer than 24.13, so it runs FIRST and projects the tree
    # back to the state 24.13's successor was registered against. Same
    # newest-first discipline as every link below; inserting it after 24.13
    # would hand 24.13 a tree two patches ahead of what it recorded.
    # Patch 24.15a is newer than 24.14, so it runs first, same newest-first
    # discipline as every link below it.
    # Patch 24.15 is newest, so it runs first.
    # Patch 24.18 is newest, so it runs first. It registers the closure's own
    # surfaces: cranelift_registry.py, which it edits to register the
    # phase24_closure top-level key, and the closure contract it adds.
    # Issue #398 is newest, so it runs FIRST and projects the tree back to
    # the state every successor below it was registered against. It moves the
    # most surfaces of any link here -- the compiler entry and its help, the
    # guards that pinned the old wording, the consumers converted onto frozen
    # replay, the seed, and the user documentation -- and it is the only one
    # that REMOVES a surface: tests/e2e_codegen_assertions.gst stops matching
    # the content patterns once its invocations become replays.
    # Issue #437 is newest, so it runs FIRST and projects the tree back to
    # the state Issue #398's successor was registered against. Same
    # newest-first discipline as every link below it.
    # Phase 25's seed-policy record is newest, so it runs FIRST. It adds one
    # document and moves docs/ROADMAP_TAIL.md; no code or route changes.
    # Patch 25.6 merges AFTER 25.4, so it is the newest link here and runs
    # FIRST. It changes twelve enrolled surfaces and adds none: fiber.c is
    # deleted, but fiber.c was never enrolled -- it matched no surface
    # pattern -- so the scan's row count is unchanged at 590 and this block
    # is a pure projection, with no added or removed half to carry.
    #
    # A thirteenth surface moved and is deliberately NOT here. Patch 25.6
    # also edits docs/PHASE25_BOOTSTRAP_SEED_POLICY.md, which the seed
    # policy block below carries as an ADDED surface -- and an added
    # surface has one registered row, not a predecessor/successor pair, so
    # there is nothing for this block to project it back to. Its row is
    # updated in place there instead. Projecting it here would hand that
    # block the pre-25.6 digest and fail it.
    fiber_surface = registry.get(
        "patch256_fiber_global_asm", {}).get("text_surface_successor")
    if fiber_surface is not None:
        require(fiber_surface.get("contract_version") ==
                "patch256_fiber_global_asm_text_surface_successor_v1" and
                fiber_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Patch 25.6 fiber global_asm text surface successor drifted")
        fb_paths = list(fiber_surface["registered_changed_paths"])
        fb_pre = {r["path"]: r for r
                  in fiber_surface["previous_changed_text_surfaces"]}
        fb_post = {r["path"]: r for r
                   in fiber_surface["current_changed_text_surfaces"]}
        require(sorted(fb_pre) == sorted(fb_paths) == sorted(fb_post),
                "Patch 25.6 registered paths and rows disagree")
        fb_expected = [p for p in fb_paths if p not in disenrolled]
        fb_pre = {k: r for k, r in fb_pre.items() if k in fb_expected}
        fb_post = {k: r for k, r in fb_post.items() if k in fb_expected}
        fb_live = {r["path"]: r for r in rows if r["path"] in fb_expected}
        require(sorted(fb_live) == sorted(fb_expected),
                "Patch 25.6 registered text surface is missing from the scan")
        require(fb_live in (fb_pre, fb_post),
                "Patch 25.6 changed text surfaces are partial or "
                "substituted: the live rows match neither the complete "
                "predecessor state nor the complete successor state "
                f"({sorted(p for p in fb_expected if fb_live[p] != fb_post[p])} differ from post)")
        rows = [dict(fb_pre.get(r["path"], r)) for r in rows]
    # Patch 25.4 merges AFTER 25.8a and 25.1, so it runs before both of
    # them, and after 25.6, which is newer still. The union resolution
    # that brought it here appended it at the END, which is file order,
    # not merge order -- and
    # the chain is defined by merge order. Moved, because leaving it last
    # made 25.8a compare live rows against a state 25.4 had not yet
    # projected back.
    # It carries the Makefile (the C fixture's object left the runtime
    # object list) and the phase21 qualification guard (its
    # runtime_package members moved).
    crate_surface = registry.get(
        "patch254_runtime_crate", {}).get("text_surface_successor")
    if crate_surface is not None:
        require(crate_surface.get("contract_version") ==
                "patch254_runtime_crate_text_surface_successor_v1" and
                crate_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Patch 25.4 runtime crate text surface successor drifted")
        cr_paths = list(crate_surface["registered_changed_paths"])
        cr_pre = {r["path"]: r for r
                  in crate_surface["previous_changed_text_surfaces"]}
        cr_post = {r["path"]: r for r
                   in crate_surface["current_changed_text_surfaces"]}
        require(sorted(cr_pre) == sorted(cr_paths) == sorted(cr_post),
                "Patch 25.4 registered paths and rows disagree")
        cr_live = {r["path"]: r for r in rows if r["path"] in cr_paths}
        require(sorted(cr_live) == sorted(cr_paths),
                "Patch 25.4 registered text surface is missing from the scan")
        require(cr_live in (cr_pre, cr_post),
                "Patch 25.4 changed text surfaces are partial or "
                "substituted: the live rows match neither the complete "
                "predecessor state nor the complete successor state "
                f"({sorted(p for p in cr_paths if cr_live[p] != cr_post[p])} differ from post)")
        rows = [dict(cr_pre.get(r["path"], r)) for r in rows]
    # Patch 25.1 is the newest successor, so it runs FIRST. It only ADDS a
    # surface -- the expected-failure list -- so the added-row requirement
    # from PR #444's review carries the whole contract.
    # Patch 25.8a merged AFTER 25.1, so it is newer and runs FIRST. The
    # two blocks were written on parallel branches and each inserted
    # itself where it landed, which left file order disagreeing with
    # merge order -- and the chain is defined by merge order.
    seedwire_surface = registry.get(
        "phase258_release_mechanics", {}).get("text_surface_successor")
    if seedwire_surface is not None:
        require(seedwire_surface.get("contract_version") ==
                "phase258_release_mechanics_text_surface_successor_v1" and
                seedwire_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Patch 25.8a release mechanics text surface successor drifted")
        sw_paths = list(seedwire_surface["registered_changed_paths"])
        sw_pre = {r["path"]: r for r
                  in seedwire_surface["previous_changed_text_surfaces"]}
        sw_post = {r["path"]: r for r
                   in seedwire_surface["current_changed_text_surfaces"]}
        require(sorted(sw_pre) == sorted(sw_paths) == sorted(sw_post),
                "Patch 25.8a registered paths and rows disagree")
        sw_live = {r["path"]: r for r in rows if r["path"] in sw_paths}
        require(sorted(sw_live) == sorted(sw_paths),
                "Patch 25.8a registered text surface is missing from the scan")
        require(sw_live in (sw_pre, sw_post),
                "Patch 25.8a changed text surfaces are partial or "
                "substituted: the live rows match neither the complete "
                "predecessor state nor the complete successor state "
                f"({sorted(p for p in sw_paths if sw_live[p] != sw_post[p])} differ from post)")
        rows = [dict(sw_pre.get(r["path"], r)) for r in rows]
        rows.sort(key=lambda r: str(r["path"]))
        by_path = {r["path"]: r for r in rows}

    falsifier_surface = registry.get(
        "patch251_no_c_falsifier", {}).get("text_surface_successor")
    if falsifier_surface is not None:
        require(falsifier_surface.get("contract_version") ==
                "patch251_no_c_falsifier_text_surface_successor_v1" and
                falsifier_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Patch 25.1 falsifier text surface successor drifted")
        fs_paths = list(falsifier_surface["registered_changed_paths"])
        fs_pre = {r["path"]: r for r
                  in falsifier_surface["previous_changed_text_surfaces"]}
        fs_post = {r["path"]: r for r
                   in falsifier_surface["current_changed_text_surfaces"]}
        require(sorted(fs_pre) == sorted(fs_paths) == sorted(fs_post),
                "Patch 25.1 registered paths and rows disagree")
        fs_chg = {r["path"]: r for r in rows if r["path"] in fs_paths}
        require(sorted(fs_chg) == sorted(fs_paths),
                "Patch 25.1 registered text surface is missing from scan")
        require(fs_chg in (fs_pre, fs_post),
                "Patch 25.1 changed text surfaces are partial or "
                f"substituted ({sorted(p for p in fs_paths if fs_chg[p] != fs_post[p])} differ from post)")
        rows = [dict(fs_pre.get(r["path"], r)) for r in rows]
        fs_added = set(falsifier_surface["added_text_surfaces"])
        fs_rows = {r["path"]: r for r
                   in falsifier_surface["added_text_surface_rows"]}
        require(sorted(fs_rows) == sorted(fs_added),
                "Patch 25.1 added paths and rows disagree")
        # Patch 25.10 clears the bootstrap-chain-compiles-c entry from this
        # file, as that entry's own cleared_by scheduled. Its prose carried
        # the file's only surface-pattern match, so removing it takes the
        # whole file out of the enrolled set -- still tracked, no longer a
        # surface. Same disenrolment record as the generated inventory review,
        # and the same reason it is not a departure: the file is right there,
        # and one more sentence about generated C would put it back.
        fs_expected = {p for p in fs_added if p not in disenrolled}
        fs_live = {r["path"]: r for r in rows if r["path"] in fs_expected}
        require(sorted(fs_live) == sorted(fs_expected),
                "Patch 25.1 added text surface is missing from the scan: "
                f"{sorted(fs_added - set(fs_live))}")
        for path in sorted(fs_expected):
            require(fs_live[path] == fs_rows[path],
                    "Patch 25.1 added text surface does not match its "
                    f"registered row: {path}")
        rows = [r for r in rows if r["path"] not in fs_added]
        rows.sort(key=lambda r: str(r["path"]))
        by_path = {r["path"]: r for r in rows}

    # Issue #451 is the newest successor, so it runs FIRST. Three files:
    # the provenance guard (justfile enabled), the retirement inventory
    # (three recipes owned by phase25) and cranelift_registry.py, which
    # moves because adding a top-level key edits TOP_FIELDS.
    # Patch 25.8a is the newest successor, so it runs FIRST. One path: the
    # Makefile, because wiring GUST_BOOTSTRAP_SEED into gust_bootstrap is
    # what turns the offline path from a documented claim into a route the
    # build actually takes.
    ownership_surface = registry.get(
        "issue451_inventory_ownership", {}).get("text_surface_successor")
    if ownership_surface is not None:
        require(ownership_surface.get("contract_version") ==
                "issue451_inventory_ownership_text_surface_successor_v1" and
                ownership_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Issue #451 ownership text surface successor drifted")
        ow_paths = list(ownership_surface["registered_changed_paths"])
        ow_pre = {r["path"]: r for r
                  in ownership_surface["previous_changed_text_surfaces"]}
        ow_post = {r["path"]: r for r
                   in ownership_surface["current_changed_text_surfaces"]}
        require(sorted(ow_pre) == sorted(ow_paths) == sorted(ow_post),
                "Issue #451 registered paths and rows disagree")
        ow_live = {r["path"]: r for r in rows if r["path"] in ow_paths}
        require(sorted(ow_live) == sorted(ow_paths),
                "Issue #451 registered text surface is missing from the scan")
        require(ow_live in (ow_pre, ow_post),
                "Issue #451 changed text surfaces are partial or "
                "substituted: the live rows match neither the complete "
                "predecessor state nor the complete successor state "
                f"({sorted(p for p in ow_paths if ow_live[p] != ow_post[p])} differ from post)")
        rows = [dict(ow_pre.get(r["path"], r)) for r in rows]
        rows.sort(key=lambda r: str(r["path"]))
        by_path = {r["path"]: r for r in rows}

    # Issue #431 is the newest successor, so it runs FIRST. It carries the
    # two repaired guards plus scripts/cranelift_registry.py, because
    # adding a top-level key edits TOP_FIELDS and that file is itself an
    # enrolled surface. Whole-map comparison per the PR #447 review.
    baseline_surface = registry.get(
        "issue431_full_compiler_baseline", {}).get("text_surface_successor")
    if baseline_surface is not None:
        require(baseline_surface.get("contract_version") ==
                "issue431_full_compiler_baseline_text_surface_successor_v1"
                and baseline_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Issue #431 baseline text surface successor drifted")
        bl_paths = list(baseline_surface["registered_changed_paths"])
        bl_pre = {r["path"]: r for r
                  in baseline_surface["previous_changed_text_surfaces"]}
        bl_post = {r["path"]: r for r
                   in baseline_surface["current_changed_text_surfaces"]}
        require(sorted(bl_pre) == sorted(bl_paths) == sorted(bl_post),
                "Issue #431 registered paths and rows disagree")
        bl_live = {r["path"]: r for r in rows if r["path"] in bl_paths}
        require(sorted(bl_live) == sorted(bl_paths),
                "Issue #431 registered text surface is missing from the scan")
        require(bl_live in (bl_pre, bl_post),
                "Issue #431 changed text surfaces are partial or "
                "substituted: the live rows match neither the complete "
                "predecessor state nor the complete successor state "
                f"({sorted(p for p in bl_paths if bl_live[p] != bl_post[p])} differ from post)")
        rows = [dict(bl_pre.get(r["path"], r)) for r in rows]
        rows.sort(key=lambda r: str(r["path"]))
        by_path = {r["path"]: r for r in rows}

    # Issue #436's justfile population is the newest successor here, so it
    # runs FIRST. Whole-map comparison per the PR #447 review.
    population_surface = registry.get(
        "issue436_justfile_population", {}).get("text_surface_successor")
    if population_surface is not None:
        require(population_surface.get("contract_version") ==
                "issue436_justfile_population_text_surface_successor_v1" and
                population_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Issue #436 justfile population successor drifted")
        pop_paths = list(population_surface["registered_changed_paths"])
        pop_pre = {row["path"]: row for row
                   in population_surface["previous_changed_text_surfaces"]}
        pop_post = {row["path"]: row for row
                    in population_surface["current_changed_text_surfaces"]}
        require(sorted(pop_pre) == sorted(pop_paths) == sorted(pop_post),
                "Issue #436 justfile population paths and rows disagree")
        pop_live = {row["path"]: row for row in rows
                    if row["path"] in pop_paths}
        require(sorted(pop_live) == sorted(pop_paths),
                "Issue #436 justfile population surface missing from scan")
        require(pop_live in (pop_pre, pop_post),
                "Issue #436 justfile population changed text surfaces are "
                "partial or substituted: the live rows match neither the "
                "complete predecessor state nor the complete successor "
                f"state ({sorted(p for p in pop_paths if pop_live[p] != pop_post[p])} differ from post)")
        rows = [dict(pop_pre.get(row["path"], row)) for row in rows]
        rows.sort(key=lambda row: str(row["path"]))
        by_path = {row["path"]: row for row in rows}

    # PR #447 is newer than Issue #436's own successor, so it runs FIRST and
    # projects the tree back to the state #436 was registered against. It
    # carries scripts/cranelift_registry.py as well as the resolver, because
    # adding a top-level key edits TOP_FIELDS, and that file is itself an
    # enrolled surface and not in SELF_EXCLUSIONS.
    scoping_surface = registry.get(
        "issue447_resolver_scoping", {}).get("text_surface_successor")
    if scoping_surface is not None:
        require(scoping_surface.get("contract_version") ==
                "issue447_resolver_scoping_text_surface_successor_v1" and
                scoping_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Issue #447 resolver scoping text surface successor drifted")
        scoping_paths = list(scoping_surface["registered_changed_paths"])
        scoping_pre = {row["path"]: row for row
                       in scoping_surface["previous_changed_text_surfaces"]}
        scoping_post = {row["path"]: row for row
                        in scoping_surface["current_changed_text_surfaces"]}
        require(sorted(scoping_pre) == sorted(scoping_paths) ==
                sorted(scoping_post),
                "Issue #447 registered paths and rows disagree")
        scoping_live = {row["path"]: row for row in rows
                        if row["path"] in scoping_paths}
        require(sorted(scoping_live) == sorted(scoping_paths),
                "Issue #447 registered text surface is missing from the scan")
        # PR #447 review (P2): comparing each path independently against
        # pre-or-post accepts a MIX -- one path at its predecessor row while
        # another is at its successor row -- which is exactly the partially
        # applied or partially reverted state
        # `partial_extra_or_substituted_surface: rejected` exists to refuse.
        # Compare the complete map against one complete state or the other.
        require(scoping_live in (scoping_pre, scoping_post),
                "Issue #447 changed text surfaces are partial or "
                "substituted: the live rows match neither the complete "
                "predecessor state nor the complete successor state "
                f"({sorted(path for path in scoping_paths if scoping_live[path] != scoping_post[path])} differ from post)")
        rows = [dict(scoping_pre.get(row["path"], row)) for row in rows]
    # The Phase 25 roadmap draft is newer than the seed policy, so it runs
    # FIRST and projects the tree back to the state the seed-policy successor
    # was registered against. It only adds a surface; it changes none, so the
    # added-row requirement carries the whole contract -- and per the PR #444
    # review, that requirement is what makes the enrolment real rather than
    # decorative.
    roadmap_surface = registry.get(
        "phase25_roadmap_draft", {}).get("text_surface_successor")
    if roadmap_surface is not None:
        require(roadmap_surface.get("contract_version") ==
                "phase25_roadmap_draft_text_surface_successor_v1" and
                roadmap_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Phase 25 roadmap text surface successor drifted")
        roadmap_paths = list(roadmap_surface["registered_changed_paths"])
        roadmap_pre = {row["path"]: row for row
                       in roadmap_surface["previous_changed_text_surfaces"]}
        roadmap_post = {row["path"]: row for row
                        in roadmap_surface["current_changed_text_surfaces"]}
        require(sorted(roadmap_pre) == sorted(roadmap_paths) ==
                sorted(roadmap_post),
                "Phase 25 roadmap registered paths and rows disagree")
        roadmap_chg = {row["path"]: row for row in rows
                       if row["path"] in roadmap_paths}
        require(sorted(roadmap_chg) == sorted(roadmap_paths),
                "Phase 25 roadmap registered text surface is missing from "
                "the scan")
        for path in roadmap_paths:
            require(roadmap_chg[path] in (roadmap_pre[path],
                                          roadmap_post[path]),
                    "Phase 25 roadmap changed text surfaces are partial or "
                    f"substituted: {path}")
        rows = [dict(roadmap_pre.get(row["path"], row)) for row in rows]
        roadmap_added = set(roadmap_surface["added_text_surfaces"])
        roadmap_rows = {row["path"]: row for row
                        in roadmap_surface["added_text_surface_rows"]}
        require(sorted(roadmap_rows) == sorted(roadmap_added),
                "Phase 25 roadmap added paths and rows disagree")
        roadmap_live = {row["path"]: row for row in rows
                        if row["path"] in roadmap_added}
        require(sorted(roadmap_live) == sorted(roadmap_added),
                "Phase 25 roadmap added text surface is missing from the "
                f"scan: {sorted(roadmap_added - set(roadmap_live))}")
        for path in sorted(roadmap_added):
            require(roadmap_live[path] == roadmap_rows[path],
                    "Phase 25 roadmap added text surface does not match its "
                    f"registered row: {path}")
        rows = [row for row in rows if row["path"] not in roadmap_added]
        rows.sort(key=lambda row: str(row["path"]))
        by_path = {row["path"]: row for row in rows}

    seed_policy_surface = registry.get(
        "phase25_bootstrap_seed_policy", {}).get("text_surface_successor")
    if seed_policy_surface is not None:
        require(seed_policy_surface.get("contract_version") ==
                "phase25_bootstrap_seed_policy_text_surface_successor_v1" and
                seed_policy_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Phase 25 seed-policy text surface successor drifted")
        seed_paths = list(seed_policy_surface["registered_changed_paths"])
        seed_pre = {row["path"]: row for row
                    in seed_policy_surface["previous_changed_text_surfaces"]}
        seed_post = {row["path"]: row for row
                     in seed_policy_surface["current_changed_text_surfaces"]}
        require(sorted(seed_pre) == sorted(seed_paths) == sorted(seed_post),
                "Phase 25 seed-policy registered paths and rows disagree")
        seed_live = {row["path"]: row for row in rows
                     if row["path"] in seed_paths}
        require(sorted(seed_live) == sorted(seed_paths),
                "Phase 25 seed-policy text surface is missing from the scan")
        for path in seed_paths:
            require(seed_live[path] in (seed_pre[path], seed_post[path]),
                    "Phase 25 seed-policy changed text surfaces are partial "
                    f"or substituted: {path}")
        seed_added = set(seed_policy_surface["added_text_surfaces"])
        # PR #444 review (P2): the block below filters every added path out of
        # the scan, and nothing first required the path to BE in the scan. So
        # deleting docs/PHASE25_BOOTSTRAP_SEED_POLICY.md left both this guard
        # and phase23_mir_to_c_deprecation_opening green -- verified by
        # deleting it -- and the registered enrolment protected nothing. A
        # projection that cannot fail on the surface it projects is a record,
        # not a guard. Require the expected row first, then project it away.
        seed_added_rows = {row["path"]: row for row
                           in seed_policy_surface["added_text_surface_rows"]}
        require(sorted(seed_added_rows) == sorted(seed_added),
                "Phase 25 seed-policy added paths and rows disagree")
        seed_added_live = {row["path"]: row for row in rows
                           if row["path"] in seed_added}
        require(sorted(seed_added_live) == sorted(seed_added),
                "Phase 25 seed-policy added text surface is missing from the "
                f"scan: {sorted(set(seed_added) - set(seed_added_live))}")
        for path in sorted(seed_added):
            require(seed_added_live[path] == seed_added_rows[path],
                    "Phase 25 seed-policy added text surface does not match "
                    f"its registered row: {path}")
        rows = [dict(seed_pre.get(row["path"], row)) for row in rows
                if row["path"] not in seed_added]
        rows = sorted(rows + [copy.deepcopy(r) for r
                              in seed_policy_surface["removed_text_surfaces"]],
                      key=lambda row: str(row["path"]))
        by_path = {row["path"]: row for row in rows}

    parity_surface = registry.get(
        "issue437_parity_residue_adjudication", {}).get(
            "text_surface_successor")
    if parity_surface is not None:
        require(parity_surface.get("contract_version") ==
                "issue437_text_surface_successor_v1" and
                parity_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Issue #437 text surface successor drifted")
        parity_paths = list(parity_surface["registered_changed_paths"])
        parity_pre = {row["path"]: row for row
                      in parity_surface["previous_changed_text_surfaces"]}
        parity_post = {row["path"]: row for row
                       in parity_surface["current_changed_text_surfaces"]}
        require(sorted(parity_pre) == sorted(parity_paths) ==
                sorted(parity_post),
                "Issue #437 registered paths and rows disagree")
        parity_live = {row["path"]: row for row in rows
                       if row["path"] in parity_paths}
        require(sorted(parity_live) == sorted(parity_paths),
                "Issue #437 registered text surface is missing from the scan")
        for path in parity_paths:
            require(parity_live[path] in (parity_pre[path],
                                          parity_post[path]),
                    "Issue #437 changed text surfaces are partial or "
                    f"substituted: {path}")
        parity_added = set(parity_surface["added_text_surfaces"])
        rows = [dict(parity_pre.get(row["path"], row)) for row in rows
                if row["path"] not in parity_added]
        rows = sorted(rows + [copy.deepcopy(r) for r
                              in parity_surface["removed_text_surfaces"]],
                      key=lambda row: str(row["path"]))
    # Issue #436 is newest, so it runs FIRST and projects the tree back to
    # the state Issue #398's successor was registered against.
    resolver_surface = registry.get(
        "issue436_provenance_resolver", {}).get("text_surface_successor")
    if resolver_surface is not None:
        require(resolver_surface.get("contract_version") ==
                "issue436_text_surface_successor_v1" and
                resolver_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Issue #436 text surface successor drifted")
        resolver_paths = list(resolver_surface["registered_changed_paths"])
        resolver_pre = {row["path"]: row for row
                        in resolver_surface["previous_changed_text_surfaces"]}
        resolver_post = {row["path"]: row for row
                         in resolver_surface["current_changed_text_surfaces"]}
        require(sorted(resolver_pre) == sorted(resolver_paths) ==
                sorted(resolver_post),
                "Issue #436 registered paths and rows disagree")
        resolver_live = {row["path"]: row for row in rows
                         if row["path"] in resolver_paths}
        require(sorted(resolver_live) == sorted(resolver_paths),
                "Issue #436 registered text surface is missing from the scan")
        for path in resolver_paths:
            require(resolver_live[path] in (resolver_pre[path],
                                            resolver_post[path]),
                    "Issue #436 changed text surfaces are partial or "
                    f"substituted: {path}")
        rows = [dict(resolver_pre.get(row["path"], row)) for row in rows]
        rows.sort(key=lambda row: str(row["path"]))
        by_path = {row["path"]: row for row in rows}

    spelling_surface = registry.get(
        "phase398_retained_spelling_removal", {}).get("text_surface_successor")
    if spelling_surface is not None:
        require(spelling_surface.get("contract_version") ==
                "phase398_text_surface_successor_v1" and
                spelling_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Issue #398 text surface successor drifted")
        spelling_paths = list(spelling_surface["registered_changed_paths"])
        spelling_pre = {row["path"]: row for row
                        in spelling_surface["previous_changed_text_surfaces"]}
        spelling_post = {row["path"]: row for row
                         in spelling_surface["current_changed_text_surfaces"]}
        require(sorted(spelling_pre) == sorted(spelling_paths) ==
                sorted(spelling_post),
                "Issue #398 registered paths and rows disagree")
        spelling_live = {row["path"]: row for row in rows
                         if row["path"] in spelling_paths}
        require(sorted(spelling_live) == sorted(spelling_paths),
                "Issue #398 registered text surface is missing from the "
                f"scan: {sorted(set(spelling_paths) - set(spelling_live))}")
        for path in spelling_paths:
            require(spelling_live[path] in (spelling_pre[path],
                                            spelling_post[path]),
                    "Issue #398 changed text surfaces are partial or "
                    f"substituted: {path}")
        spelling_added = set(spelling_surface["added_text_surfaces"])
        rows = [dict(spelling_pre.get(row["path"], row)) for row in rows
                if row["path"] not in spelling_added]
        rows = sorted(rows + [copy.deepcopy(r) for r
                              in spelling_surface["removed_text_surfaces"]],
                      key=lambda row: str(row["path"]))
        by_path = {row["path"]: row for row in rows}

    closure_surface = registry.get(
        "phase24_closure", {}).get("text_surface_successor")
    if closure_surface is not None:
        require(closure_surface.get("contract_version") ==
                "phase24_18_text_surface_successor_v1" and
                closure_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Patch 24.18 text surface successor drifted")
        closure_paths = list(closure_surface["registered_changed_paths"])
        closure_pre = {row["path"]: row for row
                       in closure_surface["previous_changed_text_surfaces"]}
        closure_post = {row["path"]: row for row
                        in closure_surface["current_changed_text_surfaces"]}
        require(sorted(closure_pre) == sorted(closure_paths) ==
                sorted(closure_post),
                "Patch 24.18 registered text surface is missing")
        closure_live = {row["path"]: row for row in rows
                        if row["path"] in closure_paths}
        require(sorted(closure_live) == sorted(closure_paths),
                "Patch 24.18 registered text surface is missing from the scan")
        for path in closure_paths:
            require(closure_live[path] in (closure_pre[path],
                                           closure_post[path]),
                    "Patch 24.18 changed text surfaces are partial or "
                    f"substituted: {path}")
        closure_added = set(closure_surface["added_text_surfaces"])
        rows = [dict(closure_pre.get(row["path"], row)) for row in rows
                if row["path"] not in closure_added]
        rows = sorted(rows + [copy.deepcopy(r) for r
                              in closure_surface["removed_text_surfaces"]],
                      key=lambda row: str(row["path"]))
        by_path = {row["path"]: row for row in rows}

    # Patch 24.16 runs next.
    audit_surface = registry.get(
        "phase24_16_residue_audit", {}).get("text_surface_successor")
    if audit_surface is not None:
        require(audit_surface.get("contract_version") ==
                "phase24_16_text_surface_successor_v1" and
                audit_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Patch 24.16 text surface successor drifted")
        audit_paths = list(audit_surface["registered_changed_paths"])
        audit_pre = {row["path"]: row for row
                     in audit_surface["previous_changed_text_surfaces"]}
        audit_post = {row["path"]: row for row
                      in audit_surface["current_changed_text_surfaces"]}
        require(sorted(audit_pre) == sorted(audit_paths) == sorted(audit_post),
                "Patch 24.16 registered text surface is missing")
        audit_live = {row["path"]: row for row in rows
                      if row["path"] in audit_paths}
        require(sorted(audit_live) == sorted(audit_paths),
                "Patch 24.16 registered text surface is missing from the scan")
        for path in audit_paths:
            require(audit_live[path] in (audit_pre[path], audit_post[path]),
                    "Patch 24.16 changed text surfaces are partial or "
                    f"substituted: {path}")
        audit_added = set(audit_surface["added_text_surfaces"])
        rows = [dict(audit_pre.get(row["path"], row)) for row in rows
                if row["path"] not in audit_added]
        rows = sorted(rows + [copy.deepcopy(r) for r
                              in audit_surface["removed_text_surfaces"]],
                      key=lambda row: str(row["path"]))
        by_path = {row["path"]: row for row in rows}

    docs_surface = registry.get(
        "phase24_15_package_docs_registry", {}).get("text_surface_successor")
    if docs_surface is not None:
        require(docs_surface.get("contract_version") ==
                "phase24_15_text_surface_successor_v1" and
                docs_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Patch 24.15 text surface successor drifted")
        docs_paths = list(docs_surface["registered_changed_paths"])
        docs_pre = {row["path"]: row for row
                    in docs_surface["previous_changed_text_surfaces"]}
        docs_post = {row["path"]: row for row
                     in docs_surface["current_changed_text_surfaces"]}
        require(sorted(docs_pre) == sorted(docs_paths) == sorted(docs_post),
                "Patch 24.15 registered text surface is missing")
        docs_live = {row["path"]: row for row in rows
                     if row["path"] in docs_paths}
        require(sorted(docs_live) == sorted(docs_paths),
                "Patch 24.15 registered text surface is missing from the scan")
        for path in docs_paths:
            require(docs_live[path] in (docs_pre[path], docs_post[path]),
                    "Patch 24.15 changed text surfaces are partial or "
                    f"substituted: {path}")
        docs_added = set(docs_surface["added_text_surfaces"])
        rows = [dict(docs_pre.get(row["path"], row)) for row in rows
                if row["path"] not in docs_added]
        rows = sorted(rows + [copy.deepcopy(r) for r
                              in docs_surface["removed_text_surfaces"]],
                      key=lambda row: str(row["path"]))
        by_path = {row["path"]: row for row in rows}

    reachability_surface = registry.get(
        "phase24_15a_reachability_repair", {}).get("text_surface_successor")
    if reachability_surface is not None:
        require(reachability_surface.get("contract_version") ==
                "phase24_15a_text_surface_successor_v1" and
                reachability_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Patch 24.15a text surface successor drifted")
        reach_paths = list(
            reachability_surface["registered_changed_paths"])
        reach_pre = {row["path"]: row for row in
                     reachability_surface["previous_changed_text_surfaces"]}
        reach_post = {row["path"]: row for row in
                      reachability_surface["current_changed_text_surfaces"]}
        require(sorted(reach_pre) == sorted(reach_paths) == sorted(reach_post),
                "Patch 24.15a registered text surface is missing")
        reach_live = {row["path"]: row for row in rows
                      if row["path"] in reach_paths}
        require(sorted(reach_live) == sorted(reach_paths),
                "Patch 24.15a registered text surface is missing from the scan")
        for path in reach_paths:
            require(reach_live[path] in (reach_pre[path], reach_post[path]),
                    "Patch 24.15a changed text surfaces are partial or "
                    f"substituted: {path}")
        reach_added = set(reachability_surface["added_text_surfaces"])
        rows = [dict(reach_pre.get(row["path"], row)) for row in rows
                if row["path"] not in reach_added]
        rows = sorted(rows + [copy.deepcopy(r) for r
                              in reachability_surface["removed_text_surfaces"]],
                      key=lambda row: str(row["path"]))
        by_path = {row["path"]: row for row in rows}

    toolchain_surface = registry.get(
        "phase24_14_toolchain_removal", {}).get("text_surface_successor")
    if toolchain_surface is not None:
        require(toolchain_surface.get("contract_version") ==
                "phase24_14_text_surface_successor_v1" and
                toolchain_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Patch 24.14 text surface successor drifted")
        toolchain_paths = list(toolchain_surface["registered_changed_paths"])
        toolchain_pre = {row["path"]: row for row
                         in toolchain_surface["previous_changed_text_surfaces"]}
        toolchain_post = {row["path"]: row for row
                          in toolchain_surface["current_changed_text_surfaces"]}
        require(sorted(toolchain_pre) == sorted(toolchain_paths) ==
                sorted(toolchain_post),
                "Patch 24.14 registered text surface is missing")
        toolchain_live = {row["path"]: row for row in rows
                          if row["path"] in toolchain_paths}
        require(sorted(toolchain_live) == sorted(toolchain_paths),
                "Patch 24.14 registered text surface is missing from the scan")
        for path in toolchain_paths:
            require(toolchain_live[path] in (toolchain_pre[path],
                                             toolchain_post[path]),
                    "Patch 24.14 changed text surfaces are partial or "
                    f"substituted: {path}")
        toolchain_added = set(toolchain_surface["added_text_surfaces"])
        rows = [dict(toolchain_pre.get(row["path"], row)) for row in rows
                if row["path"] not in toolchain_added]
        rows = sorted(rows + [copy.deepcopy(r) for r
                              in toolchain_surface["removed_text_surfaces"]],
                      key=lambda row: str(row["path"]))
        by_path = {row["path"]: row for row in rows}

    removal_surface = registry.get(
        "phase24_13_backend_removal", {}).get("text_surface_successor")
    if removal_surface is not None:
        require(removal_surface.get("contract_version") ==
                "phase24_13_text_surface_successor_v1" and
                removal_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Patch 24.13 text surface successor drifted")
        removal_paths = list(removal_surface["registered_changed_paths"])
        removal_pre = {row["path"]: row for row
                       in removal_surface["previous_changed_text_surfaces"]}
        removal_post = {row["path"]: row for row
                        in removal_surface["current_changed_text_surfaces"]}
        require(sorted(removal_pre) == sorted(removal_paths) and
                sorted(removal_post) == sorted(removal_paths),
                "Patch 24.13 registered paths and rows disagree")
        removal_live = {row["path"]: row for row in rows
                        if row["path"] in removal_paths}
        require(sorted(removal_live) == sorted(removal_paths),
                "Patch 24.13 registered text surface is missing")
        for path in removal_paths:
            require(removal_live[path] in (removal_pre[path],
                                           removal_post[path]),
                    "Patch 24.13 changed text surfaces are partial or "
                    f"substituted: {path}")
        removal_added = set(removal_surface["added_text_surfaces"])
        rows = [dict(removal_pre.get(row["path"], row)) for row in rows
                if row["path"] not in removal_added]
        rows = sorted(rows + [copy.deepcopy(r) for r
                              in removal_surface["removed_text_surfaces"]],
                      key=lambda row: str(row["path"]))
        by_path = {row["path"]: row for row in rows}

    # Patch 24.12b runs next: it projects the tree back to its pre-24.12b
    # state, which is what every older successor below was registered against. Same three directions as 24.12a -- every
    # registered path goes back to its pre-patch row, every added surface is
    # dropped, every removed surface is put back.
    conversion_surface = registry.get(
        "phase24_12b_python_parity_conversion", {}).get(
            "text_surface_successor")
    if conversion_surface is not None:
        require(conversion_surface.get("contract_version") ==
                "phase24_12b_text_surface_successor_v1" and
                isinstance(conversion_surface.get("added_text_surfaces"),
                           list) and
                isinstance(conversion_surface.get("removed_text_surfaces"),
                           list) and
                conversion_surface.get(
                    "partial_extra_or_substituted_surface") == "rejected",
                "Patch 24.12b text surface successor drifted")
        conversion_paths = list(
            conversion_surface["registered_changed_paths"])
        conversion_pre = {row["path"]: row for row
                          in conversion_surface[
                              "previous_changed_text_surfaces"]}
        conversion_post = {row["path"]: row for row
                           in conversion_surface[
                               "current_changed_text_surfaces"]}
        require(sorted(conversion_pre) == sorted(conversion_paths) and
                sorted(conversion_post) == sorted(conversion_paths),
                "Patch 24.12b registered paths and rows disagree")
        # 24.12b uses a per-path loop rather than a whole-dict comparison,
        # so the subtraction applies to the iteration as well as the set.
        conversion_expected = [path for path in conversion_paths
                               if path not in disenrolled]
        conversion_live = {row["path"]: row for row in rows
                           if row["path"] in conversion_expected}
        require(sorted(conversion_live) == sorted(conversion_expected),
                "Patch 24.12b registered text surface is missing")
        for path in conversion_expected:
            require(conversion_live[path] in (conversion_pre[path],
                                              conversion_post[path]),
                    "Patch 24.12b changed text surfaces are partial or "
                    f"substituted: {path}")
        conversion_added = set(conversion_surface["added_text_surfaces"])
        for path in conversion_added:
            require(any(row["path"] == path for row in rows),
                    "a text surface Patch 24.12b registered as added is not "
                    f"there: {path}")
        conversion_removed = [copy.deepcopy(row) for row
                              in conversion_surface["removed_text_surfaces"]]
        rows = [dict(conversion_pre.get(row["path"], row)) for row in rows
                if row["path"] not in conversion_added]
        rows = sorted(rows + conversion_removed,
                      key=lambda row: str(row["path"]))
        by_path = {row["path"]: row for row in rows}

    emitter_surface = registry.get(
        "phase24_12a_emitter_only_retirement", {}).get("text_surface_successor")
    emitter_paths: list[str] = []
    if emitter_surface is not None:
        require(emitter_surface.get("contract_version") ==
                "phase24_12a_text_surface_successor_v1" and
                emitter_surface.get("status") == "patch24_12a_complete" and
                isinstance(emitter_surface.get("added_text_surfaces"), list) and
                isinstance(emitter_surface.get("removed_text_surfaces"),
                           list) and
                emitter_surface.get("partial_extra_or_substituted_surface") ==
                "rejected",
                "Patch 24.12a text surface successor drifted")
        emitter_paths = list(emitter_surface["registered_changed_paths"])
    solely_24_2f = [path for path in changed_paths
                    if path not in auth_paths and path not in oracle_paths
                    and path not in disenrolled]
    changed_rows = [row for row in rows if row["path"] in solely_24_2f]
    require(changed_rows == [row for row in transition["current_changed_text_surfaces"]
                             if row["path"] in solely_24_2f],
            "Patch 24.2f changed text surfaces are partial or substituted")
    if emitter_paths:
        emitter_pre = {row["path"]: row for row
                       in emitter_surface["previous_changed_text_surfaces"]}
        emitter_post = {row["path"]: row for row
                        in emitter_surface["current_changed_text_surfaces"]}
        require(sorted(emitter_pre) == sorted(emitter_paths) and
                sorted(emitter_post) == sorted(emitter_paths),
                "Patch 24.12a registered paths and rows disagree")
        emitter_live = {row["path"]: row for row in rows
                        if row["path"] in emitter_paths}
        require(sorted(emitter_live) == sorted(emitter_paths),
                "Patch 24.12a registered text surface is missing")
        for path in emitter_paths:
            require(emitter_live[path] in (emitter_pre[path],
                                           emitter_post[path]),
                    "Patch 24.12a changed text surfaces are partial or "
                    f"substituted: {path}")
        # Same three directions Patch 24.12 had to handle: every registered
        # path goes back to its pre-patch row, every added surface is
        # dropped, and every removed surface is put back -- otherwise the
        # pinned unchanged-other digest, which is computed over these rows,
        # sees a tree seven surfaces short.
        added = set(emitter_surface["added_text_surfaces"])
        removed = [copy.deepcopy(row)
                   for row in emitter_surface["removed_text_surfaces"]]
        rows = [dict(emitter_pre.get(row["path"], row)) for row in rows
                if row["path"] not in added]
        rows = sorted(rows + removed, key=lambda row: str(row["path"]))
        by_path = {row["path"]: row for row in rows}

    oracle_pre_rows: dict[str, dict] = {}
    if oracle_paths:
        oracle_pre = {row["path"]: row for row
                      in oracle_surface["previous_changed_text_surfaces"]}
        oracle_post = {row["path"]: row for row
                       in oracle_surface["current_changed_text_surfaces"]}
        require(sorted(oracle_pre) == sorted(oracle_paths) and
                sorted(oracle_post) == sorted(oracle_paths),
                "Patch 24.12 registered paths and rows disagree")
        oracle_live = {row["path"]: row for row in rows
                       if row["path"] in oracle_paths}
        require(sorted(oracle_live) == sorted(oracle_paths),
                "Patch 24.12 registered text surface is missing")
        for path in oracle_paths:
            require(oracle_live[path] in (oracle_pre[path], oracle_post[path]),
                    "Patch 24.12 changed text surfaces are partial or "
                    f"substituted: {path}")
            oracle_pre_rows[path] = oracle_pre[path]
        # Patch 24.12 is the first patch to move the census in all three
        # directions at once: it edits 41 tracked surfaces, adds 5, and takes
        # 4 out entirely — a converted parity harness stops matching any
        # tracked MIR-to-C token, so it stops enrolling. The pinned
        # unchanged-other digest is computed further down over exactly these
        # rows, so the projection has to happen here, before it: every
        # registered path goes back to its pre-patch row, every added path is
        # dropped, and every removed path is put back. What is checked is that
        # the registered state is the live one; what is projected is the
        # closed state the downstream digests were registered against.
        oracle_added = set(oracle_surface["added_text_surfaces"])
        live_paths = {row["path"] for row in rows}
        require(oracle_added <= live_paths,
                "a text surface Patch 24.12 registered as added is not there")
        removed = oracle_surface["removed_text_surfaces"]
        removed_paths = {row["path"] for row in removed}
        require(not (removed_paths & live_paths),
                "a text surface Patch 24.12 registered as removed still "
                "enrols")
        rows = [oracle_pre_rows.get(row["path"], row) for row in rows
                if row["path"] not in oracle_added]
        rows = sorted(rows + [copy.deepcopy(row) for row in removed],
                      key=lambda row: str(row["path"]))
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
    # Patch 24.3b: this patch's own moved surfaces are judged by its own
    # successor, the way Patch 24.2g-auth judges its own. Extending the Patch
    # 24.2f registration instead would rewrite what that closed record claims
    # 24.2f registered, so the scope gains a third source rather than a wider
    # 24.2f. Every combination of pre/post identity across the three sources
    # is an exact registered state; anything else rejects.
    retirement = registry.get(
        "phase24_s1_8_authority_successor", {}).get(
            "s1_9_resource_assignment_roadmap_successor", {}).get(
                "coordinate_retirement_successor", {})
    require(isinstance(retirement, dict) and
            retirement.get("contract_version") ==
            "phase24_3b_coordinate_retirement_text_surface_successor_v1" and
            retirement.get("status") == "patch24_3b_complete" and
            retirement.get("authority_base_main") ==
            "f2fd96adad7ca0a08dcc7ae78a5a52aeba74904b" and
            retirement.get("registered_changed_paths") == [
                "scripts/phase22_opening.py",
                "compiler/CRANELIFT_PHASE22_OPENING.md",
            ] and
            retirement.get("added_text_surfaces") == [] and
            retirement.get("partial_extra_or_substituted_surface") ==
            "rejected",
            "Patch 24.3b coordinate retirement successor drifted")
    # A path this patch also moved is judged by this patch's successor, which
    # already projected it back above; leaving it here would compare the
    # projected row against Patch 24.3b's pair and pass for the wrong reason.
    retire_paths: list[str] = [
        path for path in retirement["registered_changed_paths"]
        if path not in oracle_paths]
    retire_pre_rows: dict[str, dict] = {}
    retire_pre_by_path = {
        row["path"]: row
        for row in retirement["previous_changed_text_surfaces"]
        if row["path"] in retire_paths}
    retire_post_by_path = {
        row["path"]: row
        for row in retirement["current_changed_text_surfaces"]
        if row["path"] in retire_paths}
    require(sorted(retire_pre_by_path) == sorted(retire_paths) and
            sorted(retire_post_by_path) == sorted(retire_paths),
            "Patch 24.3b registered paths and rows disagree")
    retire_live_by_path = {row["path"]: row for row in rows
                           if row["path"] in retire_paths}
    require(sorted(retire_live_by_path) == sorted(retire_paths),
            "Patch 24.3b registered text surface is missing")
    for path in retire_paths:
        live_row = retire_live_by_path[path]
        require(live_row in (retire_pre_by_path[path],
                             retire_post_by_path[path]),
                "Patch 24.3b changed text surfaces are partial or "
                f"substituted: {path}")
        retire_pre_rows[path] = retire_pre_by_path[path]
    # The auth paths are excluded from the unchanged-other digest in every state,
    # so that digest does not depend on which of them has landed yet.
    # Scope uses Patch 24.3b's full registered set, not the subset it still
    # judges: a path handed to the Patch 24.12 successor is still one the
    # pinned unchanged-other digest was computed without.
    scope = union_paths + [
        path for path in retirement["registered_changed_paths"]
        if path not in union_paths]
    other_digest = digest_bytes(json.dumps(
        [row for row in rows if row["path"] not in scope],
        sort_keys=True, separators=(",", ":")).encode())
    pinned_other = auth["unchanged_other_text_surface_manifest_digest"]
    # Patch 24.13: this pin cannot be met by any live computation any more, and
    # not because an unregistered surface changed.
    #
    # The manifest enrols by CONTENT. Three files stopped matching the patterns
    # when their retired spellings went, so they produce no row at all -- they
    # are not "changed others", they are absent from the population the pinned
    # digest was computed over. Adding them to `scope` does nothing, because a
    # path with no row is already excluded; the digest moves regardless.
    #
    # The successor does not simply re-pin. It reconstructs the ORIGINAL
    # population by re-inserting each departure's registered previous row and
    # requires that to reproduce the pinned digest exactly. That uses 24.2f's
    # own pin as the control: it passes only if the departures are the whole
    # difference, so any other surface that moved still fails here. The live
    # remainder is then pinned separately, so the new state is registered too.
    departures = registry.get("phase24_13_backend_removal", {}).get(
        "text_surface_departures")
    successor = (departures or {}).get("unchanged_other_successor")
    if successor is None:
        require(other_digest == pinned_other,
                f"Patch 24.2f changed an unregistered text surface: "
                f"{other_digest}")
    else:
        require(successor.get("contract_version") ==
                "phase24_13_unchanged_other_successor_v1" and
                successor.get("previous_unchanged_other_digest") ==
                pinned_other and
                successor.get("partial_or_substituted_departure") ==
                "rejected",
                "Patch 24.13 unchanged-other successor drifted")
        departed_paths = list(departures.get("paths", []))
        live_paths = {row["path"] for row in rows}
        still_present = [path for path in departed_paths if path in live_paths]
        require(not still_present,
                "Patch 24.13 records these surfaces as departed, but they "
                f"still produce a manifest row: {still_present}")
        previous_rows = successor.get("departed_previous_rows", [])
        require(sorted(row["path"] for row in previous_rows) ==
                sorted(departed_paths),
                "Patch 24.13 unchanged-other successor does not carry one "
                "previous row per departed surface")
        reconstructed = sorted(
            [row for row in rows if row["path"] not in scope] + previous_rows,
            key=lambda row: str(row["path"]))
        require(digest_bytes(json.dumps(
            reconstructed, sort_keys=True, separators=(",", ":")
        ).encode()) == pinned_other,
                "Patch 24.13 restored the departed surfaces but the manifest "
                "still does not reproduce Patch 24.2f's pinned digest, so "
                "something other than the departures changed")
        require(other_digest ==
                successor.get("current_unchanged_other_digest"),
                "Patch 24.13 unchanged-other remainder is not the registered "
                f"one: {other_digest}")
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
    # Project each retired path back onto its pre-patch row for the same
    # reason: downstream projections predate this patch and expect the
    # pre-patch row, not this successor's. No retired path overlaps the
    # earlier sources, so the guard is structural rather than load-bearing.
    for path, row in retire_pre_rows.items():
        if path not in replacements:
            replacements[path] = copy.deepcopy(row)
    for path, row in oracle_pre_rows.items():
        if path not in replacements:
            replacements[path] = copy.deepcopy(row)
    added = set(transition["added_text_surfaces"])
    if auth_paths:
        added |= set(auth["added_text_surfaces"])
    added |= set(retirement["added_text_surfaces"])

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
            successor = frozen_oracle_successor_digest(registry)
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
    prerequisite = registry.get("phase26_activation_audit", {}).get(
        "reference_receiver_prerequisite", {})
    invocation_successor = prerequisite.get("phase22_invocation_successor")
    if invocation_successor is not None:
        added = invocation_successor["added_row"]
        require([row for row in rows if row.get("path") == added["path"]] ==
                [added],
                "Phase 26 reference receiver native invocation is missing, "
                "extra, or substituted")
    ffi = registry.get("phase26_activation_audit", {}).get(
        "ffi_position_policy_increment", {}).get("phase22_invocation_successor")
    if ffi is not None:
        added_rows = ffi["added_rows"]
        require([row for row in rows if row.get("path") ==
                 "scripts/phase26_ffi_position_policy.sh"] == added_rows,
                "Phase 26.1D1 native invocations are missing, extra, or "
                "substituted")
    require(opening.scan_summary(rows) ==
            effective_phase22_summary(registry, value),
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
