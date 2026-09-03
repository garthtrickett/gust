#!/usr/bin/env python3
"""Validate, project, and replay Patch 24.1 filename-selected behaviour."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
TASK = ROOT / "TASK.md"
VISION = ROOT / "docs/VISION.md"
ARCHITECTURE = ROOT / "docs/COMPILER_ARCHITECTURE_CONSOLIDATION.md"
SHARED_ZONE = ROOT / "docs/SHARED_SEMANTIC_ZONE.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE24_FILENAME_BEHAVIOR_CHARACTERIZATION.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase24-filename-behavior-characterization.yml"
BUILD = ROOT / "build/phase24-filename-behavior-characterization"
GUARD_L1 = "guard-cranelift-phase24-filename-behavior-characterization-contract"
GUARD_L2 = "guard-cranelift-phase24-filename-behavior-characterization-evidence"
EMPTY_SHA256 = hashlib.sha256(b"").hexdigest()

FIXTURES = {
    "tcs_declaration": ROOT / "tests/phase24_filename_tcs_declaration_characterization.gst",
    "tcs_guard": ROOT / "tests/phase24_filename_tcs_guard_characterization.gst",
    "index_assignment": ROOT / "tests/phase24_filename_index_assignment_characterization.gst",
    "index_pointer_write": ROOT / "tests/phase24_filename_index_pointer_write_characterization.gst",
}

PAIR_NAMES = {
    "tcs_declaration": (
        "test_tcs_declaration_selected.gst", "declaration_neutral.gst"),
    "tcs_guard": ("test_tcs_guard_selected.gst", "guard_neutral.gst"),
    "index_assignment": (
        "test_index_assignment_selected.gst", "index_assignment_neutral.gst"),
    "index_pointer_write": (
        "test_index_pointer_write_selected.gst", "index_pointer_write_neutral.gst"),
}

ROUTES = {
    "retained_explicit_compatibility": ("--backend", "mir-to-c"),
    "explicit_cranelift": ("--backend", "cranelift"),
    "default_cranelift": (),
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    value = registry.get("phase24_filename_behavior_characterization")
    require(isinstance(value, dict), "registry authority is missing")
    return value


def source_sites() -> list[dict]:
    lines = TYPECHECKER.read_text(encoding="utf-8").splitlines()
    selection = re.compile(
        r'^\s*if std\.str_find\(\(\*env\)\.current_file, '
        r'"(test_(?:tcs|index)_)"\) != 0 - 1 \{$')
    sites: list[dict] = []
    occurrence = {"test_tcs_": 0, "test_index_": 0}
    ids = {
        ("test_tcs_", 1): "var_declaration_stack_classification",
        ("test_index_", 1): "assignment_hazard_and_view_invalidation",
        ("test_tcs_", 2): "guard_payload_stack_classification",
    }
    contexts = {
        "var_declaration_stack_classification": "statement_var_declaration",
        "assignment_hazard_and_view_invalidation": "statement_assignment",
        "guard_payload_stack_classification": "statement_guard_payload_binding",
    }
    for line_number, line in enumerate(lines, 1):
        match = selection.match(line)
        if not match:
            continue
        selector = match.group(1)
        occurrence[selector] += 1
        key = (selector, occurrence[selector])
        require(key in ids, f"unclassified filename selector occurrence {key}")
        site_id = ids[key]
        window = "\n".join(lines[line_number - 2:line_number + 7]) + "\n"
        sites.append({
            "id": site_id,
            "path": TYPECHECKER.relative_to(ROOT).as_posix(),
            "line": line_number,
            "selector": selector,
            "selector_occurrence": occurrence[selector],
            "statement_context": contexts[site_id],
            "window_digest": digest(window.encode()),
        })
    return sites


def tracked_selected_filenames() -> dict[str, list[str]]:
    result = subprocess.run(
        ["git", "ls-files"], cwd=ROOT, check=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    paths = result.stdout.splitlines()
    return {
        selector: sorted(path for path in paths if selector in Path(path).name)
        for selector in ("test_tcs_", "test_index_")
    }


def validate_static(value: dict) -> None:
    require(value.get("contract_version") ==
            "phase24_filename_behavior_characterization_v1",
            "contract version drifted")
    require(value.get("status") ==
            "patch24_1_complete_observational_decision_open",
            "status drifted")
    require(value.get("authority_base_main") ==
            "3abae7a96111b15e27e295a81f15b7f97a2e372c",
            "authority base main drifted")
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    coordination = registry.get("phase24_s1_8_authority_successor", {})
    require(
        coordination.get("contract_version") ==
        "phase24_s1_8_authority_successor_v1" and
        coordination.get("owning_stdlib_pull_request") == 314 and
        coordination.get("owning_stdlib_exact_head_sha") ==
        "96a51a20dd4071ad63ead144cdb11ce4da3834a6",
        "S1.8 coordination successor identity drifted")
    accepted_justfile_digests = [
        value.get("live_justfile_successor_digest"),
        *coordination.get("justfile_state_digests", {}).values(),
    ]
    require(digest(JUSTFILE.read_bytes()) in accepted_justfile_digests,
            "live justfile successor digest drifted")
    require(value.get("review_view") == REVIEW.relative_to(ROOT).as_posix(),
            "review view drifted")
    require(value.get("site_manifest") == source_sites(),
            "filename-selected site manifest drifted")
    require([row["selector"] for row in value["site_manifest"]] ==
            ["test_tcs_", "test_index_", "test_tcs_"],
            "selector order or completeness drifted")

    callers = value.get("preexisting_selected_filenames")
    require(callers == {
        "test_tcs_": ["tests/test_tcs_non_pod_on_stack_rejected.gst"],
        "test_index_": [],
    }, "pre-change selected filename manifest drifted")
    require(tracked_selected_filenames() == callers,
            "live selected filename manifest is not exact")
    require(value.get("preexisting_caller_manifest") == [{
        "fixture": "tests/test_tcs_non_pod_on_stack_rejected.gst",
        "caller": "tests/test_runner.gst",
        "caller_line": 1566,
        "expected_diagnostic_fragment": "StackAllocationViolation",
    }], "pre-change caller manifest drifted")

    entrypoints = value.get("current_file_input_manifest")
    require(entrypoints == [
        {"path": "compiler/test_runner_entry.gst", "lines": [342, 356, 376]},
        {"path": "compiler/test_runner_bootstrap_bridge_entry.gst",
         "lines": [199, 213, 233]},
        {"path": "compiler/type_dump_entry.gst", "lines": [38]},
    ], "current_file input manifest drifted")
    for row in entrypoints:
        lines = (ROOT / row["path"]).read_text(encoding="utf-8").splitlines()
        for line_number in row["lines"]:
            require("current_file =" in lines[line_number - 1],
                    f"current_file input drifted at {row['path']}:{line_number}")

    witnesses = value.get("witnesses")
    require(isinstance(witnesses, list) and len(witnesses) == 4,
            "witness manifest must contain exactly four rows")
    expected_ids = list(FIXTURES)
    require([row.get("id") for row in witnesses] == expected_ids,
            "witness order or identity drifted")
    expected_site_ids = {
        "tcs_declaration": "var_declaration_stack_classification",
        "tcs_guard": "guard_payload_stack_classification",
        "index_assignment": "assignment_hazard_and_view_invalidation",
        "index_pointer_write": "assignment_hazard_and_view_invalidation",
    }
    for row in witnesses:
        witness_id = row["id"]
        source = FIXTURES[witness_id]
        require(source.is_file(), f"missing witness {source.relative_to(ROOT)}")
        source_bytes = source.read_bytes()
        selected_name, neutral_name = PAIR_NAMES[witness_id]
        require(row == {
            "id": witness_id,
            "site_id": expected_site_ids[witness_id],
            "fixture": source.relative_to(ROOT).as_posix(),
            "fixture_digest": digest(source_bytes),
            "selected_filename": selected_name,
            "neutral_filename": neutral_name,
            "pair_bytes_identical": True,
        }, f"witness authority drifted for {witness_id}")
        selector = ("test_index_" if witness_id.startswith("index_")
                    else "test_tcs_")
        require(selector in selected_name and selector not in neutral_name,
                f"filename selection pair drifted for {witness_id}")
        require(digest(source_bytes + b"\nmutation") != row["fixture_digest"],
                f"fixture digest is not mutation-sensitive for {witness_id}")

    authority = value.get("authority_classification")
    require(authority == {
        "var_declaration_stack_classification": {
            "classification": "genuine_decision_open",
            "existing_authority": [
                "TASK.md Patch 24.1",
                "docs/COMPILER_ARCHITECTURE_CONSOLIDATION.md Phase 24 opening preflight",
            ],
            "finding": "no_VISION_or_shared_zone_rule_selects_universal_non_POD_stack_rejection_or_an_internal_profile",
            "replacement_not_selected": [
                "universal_non_POD_stack_rejection",
                "non_user_selectable_internal_compilation_profile",
            ],
        },
        "guard_payload_stack_classification": {
            "classification": "genuine_decision_open",
            "existing_authority": [
                "TASK.md Patch 24.1",
                "docs/COMPILER_ARCHITECTURE_CONSOLIDATION.md Phase 24 opening preflight",
            ],
            "finding": "no_VISION_or_shared_zone_rule_selects_universal_non_POD_guard_payload_rejection_or_an_internal_profile",
            "replacement_not_selected": [
                "universal_non_POD_guard_payload_rejection",
                "non_user_selectable_internal_compilation_profile",
            ],
        },
        "assignment_hazard_and_view_invalidation": {
            "classification": "universal_rule_required_by_existing_authority",
            "existing_authority": ["docs/VISION.md section 26 Borrows"],
            "finding": "current_language_has_one_mutable_reference_form_and_no_aliasing_analysis",
            "selected_branch_conflict": "filename_selected_ReadWriteHazard_enforces_the_deferred_aliasing_rule",
            "replacement_constraint": "filename_cannot_enable_deferred_aliasing_restriction",
        },
    }, "authority classification drifted")
    vision = VISION.read_text(encoding="utf-8")
    for marker in (
        "Two `&T[ctx]` arguments may alias the same value and both write through it.",
        "There is no `inout`, no `&mut T[ctx]`, and no aliasing analysis.",
        "Restricting mutation through references",
        "OD-16 resolved 2026-09-03",
        "There is no internal compilation profile for these",
    ):
        require(marker in vision, f"VISION authority marker is missing: {marker}")
    architecture = ARCHITECTURE.read_text(encoding="utf-8")
    require("operator selected universal rejection of non-POD local" in architecture and
            "without an internal compilation profile" in architecture,
            "architecture decision successor drifted")
    require(SHARED_ZONE.is_file(), "shared semantic zone is missing")

    decision = value.get("decision_boundary")
    require(decision == {
        "status": "genuine_semantic_decision_open",
        "blocking_sites": [
            "var_declaration_stack_classification",
            "guard_payload_stack_classification",
        ],
        "question": "are_non_POD_local_and_guard_payload_stack_rejections_universal_Gust_semantics_or_an_internal_compilation_profile",
        "next_action": "stop_after_patch24_1_merge_for_operator_authority",
        "patch24_2_started": False,
        "patch24_3_rule_selected": False,
    }, "decision boundary drifted")
    successor = value.get("decision_authority_successor")
    require(isinstance(successor, dict) and
            successor.get("contract_version") ==
            "phase24_universal_tcs_decision_v1" and
            successor.get("status") ==
            "patch24_1a_operator_decision_recorded" and
            successor.get("operator_decision_date") == "2026-09-03" and
            successor.get("authority_base_main") ==
            "b32f9ab3716fb5562095bb1453ef9304c8574f04" and
            successor.get("selected_rule") ==
            "universal_rejection_of_non_POD_local_declarations_and_guard_payload_bindings" and
            successor.get("applies_to_sites") == decision["blocking_sites"] and
            successor.get("source_filenames_semantically_inert") is True and
            successor.get("internal_compilation_profile_for_these_checks") is False and
            successor.get("patch_order") == ["24.1a", "24.2", "24.3"] and
            successor.get("changed_paths") == [
                "TASK.md",
                "compiler/CRANELIFT_PHASE23_MIR_TO_C_DEPRECATION_OPENING.md",
                "compiler/CRANELIFT_PHASE24_FILENAME_BEHAVIOR_CHARACTERIZATION.md",
                "docs/COMPILER_ARCHITECTURE_CONSOLIDATION.md",
                "docs/VISION.md",
                "scripts/cranelift_feature_registry.json",
                "scripts/cranelift_feature_registry.schema.json",
                "scripts/phase23_mir_to_c_deprecation_opening.py",
                "scripts/phase24_cr15_stdlib_guard_transition.py",
                "scripts/phase24_filename_behavior_characterization.py",
            ] and
            successor.get("boundary") == {
                "changes_compiler_accepted_programs": False,
                "implements_patch24_3_rule": False,
                "adds_internal_compilation_profile": False,
                "changes_MIR_ABI_runtime_backend_or_bootstrap": False,
                "edits_stdlib": False,
                "begins_patch24_2_inventory": False,
            }, "Patch 24.1a decision successor drifted")
    consumer = successor.get("consumer_inventory_transition", {})
    require(consumer.get("contract_version") ==
            "phase24_universal_tcs_decision_consumer_transition_v1" and
            consumer.get("previous_inventory") ==
            value["consumer_inventory_transition"]["current_inventory"] and
            consumer.get("registered_changed_text_surfaces") ==
            ["TASK.md", "docs/VISION.md"] and
            [row.get("path") for row in consumer.get(
                "previous_changed_text_surfaces", [])] ==
            consumer.get("registered_changed_text_surfaces") and
            [row.get("path") for row in consumer.get(
                "current_changed_text_surfaces", [])] ==
            consumer.get("registered_changed_text_surfaces") and
            consumer.get("unchanged_fields") == [
                "text_surface_count", "invocation_count",
                "invocation_manifest_digest", "structural_surface_count",
                "structural_manifest_digest", "classification_counts",
                "invocation_selection_counts", "unclassified_count",
            ] and consumer.get("partial_extra_or_substituted_surface") ==
            "rejected", "Patch 24.1a consumer successor drifted")
    require(value.get("boundary") == {
        "changes_accepted_Gust_meaning": False,
        "changes_typechecker_or_compiler_source": False,
        "adds_or_changes_MIR_operations": False,
        "changes_ABI_layout_runtime_symbols_target_or_linker": False,
        "changes_backend_route_default_or_fallback": False,
        "changes_bootstrap_route_or_seed": False,
        "edits_stdlib": False,
        "begins_patch24_2_or_24_3": False,
    }, "Patch 24.1 boundary drifted")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 24.1 — Filename-Selected Behaviour Characterization — DONE" in task,
            "TASK status does not mark Patch 24.1 DONE")
    require("- [x] Patch 24.1a — Universal TCS Semantic Decision Authority — DONE" in task and
            ("- [ ] Patch 24.2 — Compiler-Recognized Semantic Spelling Inventory" in task or
             "- [x] Patch 24.2 — Compiler-Recognized Semantic Spelling Inventory — DONE" in task),
            "TASK status does not record the Patch 24.1a decision boundary")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "test-level assignments drifted")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in just and f"{GUARD_L2}:" in just,
            "just guard reachability drifted")
    require(GUARD_L1 in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast guard reachability drifted")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    for marker in (
        "pull_request:", "push:", "workflow_dispatch:", "gust_v4.c",
        "compiler/*.gst", "src/runtime.c", "src/runtime/**",
        "tools/normalize_generated_arena_offsets.py", GUARD_L1, GUARD_L2,
    ):
        require(marker in workflow, f"workflow is missing {marker}")


def render(value: dict) -> str:
    lines = [
        "# Phase 24.1 Filename-Selected Behaviour Characterization",
        "",
        "Generated by `scripts/phase24_filename_behavior_characterization.py`; do not edit by hand.",
        "",
        f"- Contract: `{value['contract_version']}`",
        f"- Status: `{value['status']}`",
        f"- Pre-change main: `{value['authority_base_main']}`",
        "- Boundary: observation only; no compiler behaviour changed.",
        "",
        "## Complete live site manifest",
        "",
        "| Site | Selector | Source | Context | Window digest |",
        "| --- | --- | --- | --- | --- |",
    ]
    for site in value["site_manifest"]:
        lines.append(
            f"| `{site['id']}` | `{site['selector']}` | `{site['path']}:{site['line']}` | "
            f"`{site['statement_context']}` | `{site['window_digest']}` |")
    lines += [
        "",
        "Pre-existing selected filenames: `test_tcs_` has "
        "`tests/test_tcs_non_pod_on_stack_rejected.gst`; `test_index_` has none. "
        "The former is reached from `tests/test_runner.gst:1566`.",
        "",
        "## Byte-identical rename observations",
        "",
        "| Witness | Route | Selected | Neutral | Selected stdout | Neutral stdout |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for witness in value["witnesses"]:
        observations = value["observations"][witness["id"]]
        for route in ROUTES:
            selected = observations[route]["selected"]
            neutral = observations[route]["neutral"]
            lines.append(
                f"| `{witness['id']}` | `{route}` | exit `{selected['exit_status']}` | "
                f"exit `{neutral['exit_status']}` | `{selected['stdout_bytes']}` bytes / "
                f"`{selected['stdout_digest']}` | `{neutral['stdout_bytes']}` bytes / "
                f"`{neutral['stdout_digest']}` |")
    lines += [
        "",
        "All stderr streams are empty. No invocation leaves `user.native`; accepted compatibility-path output is the complete compatibility artifact on stdout. Default and explicit Cranelift observations are byte-identical for each side.",
        "",
        "Selected TCS declaration and guard filenames reject with the complete `StackAllocationViolation` diagnostic while their neutral names are accepted by the compatibility path and reach the unchanged source-admission boundary under Cranelift. The selected index-assignment filename rejects with the complete `ReadWriteHazard` diagnostic. The selected pointer-write filename records both `WriteWriteHazard` conflicts and the subsequent invalidated-view `Use of moved variable` diagnostic; both neutral names follow the same accepted/deferred split.",
        "",
        "## Authority classification and decision boundary",
        "",
        "At Patch 24.1, VISION §26 already required that a filename could not enable the deferred aliasing restriction, so the `test_index_` hazard outcome had a universal replacement constraint. No VISION or shared-zone rule then decided whether the non-POD local and guard-payload stack rejection was universal Gust semantics or a non-user-selectable internal compilation profile.",
        "",
        "Therefore Patch 24.1 closes as observational evidence with a genuine semantic decision open for the two TCS sites. It selects neither alternative and starts neither Patch 24.2 nor Patch 24.3. Per the live Exit Gate, the lane stops after this patch merges for operator authority.",
        "",
        "## Patch 24.1a operator decision successor",
        "",
        "On 2026-09-03 the operator selected universal rejection of non-POD local declarations and guard-payload bindings in every Gust program. Source filenames are semantically inert, and these checks do not use an internal compilation profile.",
        "",
        "This successor records authority only. It preserves every Patch 24.1 observation, changes no compiler-accepted program, and begins neither the report-only Patch 24.2 inventory nor the Patch 24.3 correction.",
        "",
    ]
    return "\n".join(lines)


def check_review(value: dict) -> None:
    require(REVIEW.read_text(encoding="utf-8") == render(value),
            "generated review is stale; run render")


def run_observation(witness_id: str, route: str, side: str) -> dict:
    selected_name, neutral_name = PAIR_NAMES[witness_id]
    filename = selected_name if side == "selected" else neutral_name
    source = FIXTURES[witness_id].read_bytes()
    target = BUILD / filename
    target.write_bytes(source)
    relative_target = target.relative_to(ROOT).as_posix()
    command = [str(ROOT / "gust"), *ROUTES[route], relative_target]
    result = subprocess.run(
        command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        check=False)
    return {
        "exit_status": result.returncode,
        "stdout_bytes": len(result.stdout),
        "stdout_digest": digest(result.stdout),
        "stderr_bytes": len(result.stderr),
        "stderr_digest": digest(result.stderr),
        "native_artifact_present": (ROOT / "user.native").exists(),
    }


def validate_transitions(value: dict) -> None:
    invocation = value.get("phase22_invocation_transition", {})
    require(invocation.get("contract_version") ==
            "phase24_filename_behavior_phase22_invocation_transition_v1" and
            invocation.get("status") == "exact_observational_invocation" and
            invocation.get("closed_phase_projection") ==
            "remove_exact_patch24_1_observation_driver_only" and
            invocation.get("partial_extra_or_substituted_invocation") ==
            "rejected", "Phase 22 invocation transition drifted")
    require(invocation.get("added_invocation") == {
        "path": "scripts/phase24_filename_behavior_characterization.py",
        "line": 361,
        "recipe": "none",
        "compiler_token": "python_argv",
        "selection": "implicit_default",
        "consumer_class": "cranelift_C_or_diagnostic_guard",
        "owner": "cranelift",
        "expected_artifact": "generated_C_or_diagnostic",
        "expected_transition": "22.2_explicit_C_selection",
        "falsifier": "default_flip_changes_the_guard_artifact_before_explicit_C_migration",
        "command": "[str(ROOT / 'gust'), *ROUTES[route], relative_target]",
    }, "Phase 22 observation invocation identity drifted")
    decision = value.get("decision_authority_successor", {})
    decision_invocation = decision.get("phase22_invocation_transition", {})
    require(decision_invocation.get("contract_version") ==
            "phase24_universal_tcs_decision_phase22_invocation_transition_v1" and
            decision_invocation.get("previous_invocation") ==
            invocation.get("added_invocation") and
            decision_invocation.get("current_invocation") == {
                **invocation["added_invocation"], "line": 428,
            } and
            decision_invocation.get("summary_unchanged") is True and
            decision_invocation.get("partial_extra_or_substituted_invocation") ==
            "rejected", "Patch 24.1a Phase 22 invocation successor drifted")
    consumer = value.get("consumer_inventory_transition", {})
    require(consumer.get("contract_version") ==
            "phase24_filename_behavior_consumer_transition_v1" and
            consumer.get("status") == "patch24_1_complete_observational" and
            consumer.get("authority_base_main") == value.get("authority_base_main") and
            consumer.get("registered_changed_paths") == [
                ".github/workflows/pr-fast.yml", "TASK.md",
                "scripts/cranelift_registry.py",
                "scripts/cranelift_test_levels.json", "scripts/phase23_closure.py",
                "scripts/phase24_cr15_closure.py",
            ] and
            consumer.get("unchanged_fields") == [
                "text_surface_count", "invocation_count",
                "invocation_manifest_digest", "structural_surface_count",
                "structural_manifest_digest", "classification_counts",
                "invocation_selection_counts", "unclassified_count",
            ] and
            consumer.get("partial_extra_or_substituted_surface") == "rejected",
            "Phase 23 consumer transition drifted")
    require(consumer.get("previous_inventory", {}).get(
                "text_surface_manifest_digest") ==
            "750a79c58822a4fb410b5fe906cb9c10f694f9f613e305cc05a820f42b24aac8" and
            consumer.get("current_inventory", {}).get(
                "text_surface_manifest_digest") ==
            "62554b494475af54f9dc4fc8bb5973fe6631657b5ef424cf32b0d686c2037970",
            "Phase 23 consumer inventory identities drifted")


def evidence(value: dict) -> None:
    require((ROOT / "gust").is_file(), "make gust prerequisite is missing")
    BUILD.mkdir(parents=True, exist_ok=True)
    native_artifact = ROOT / "user.native"
    require(not native_artifact.exists(),
            "stale user.native obscures filename characterization")
    expected = value.get("observations")
    require(set(expected) == set(FIXTURES), "observation witness set drifted")
    for witness_id in FIXTURES:
        selected_name, neutral_name = PAIR_NAMES[witness_id]
        selected_target = BUILD / selected_name
        neutral_target = BUILD / neutral_name
        selected_target.write_bytes(FIXTURES[witness_id].read_bytes())
        neutral_target.write_bytes(FIXTURES[witness_id].read_bytes())
        require(selected_target.read_bytes() == neutral_target.read_bytes(),
                f"rename pair bytes differ for {witness_id}")
        for route in ROUTES:
            for side in ("selected", "neutral"):
                actual = run_observation(witness_id, route, side)
                require(actual == expected[witness_id][route][side],
                        f"{witness_id} {route} {side} observation drifted: {actual}")
                require(actual["stderr_bytes"] == 0 and
                        actual["stderr_digest"] == EMPTY_SHA256,
                        f"{witness_id} {route} {side} stderr is not empty")
                require(not actual["native_artifact_present"],
                        f"{witness_id} {route} {side} left a native artifact")
        require(expected[witness_id]["explicit_cranelift"] ==
                expected[witness_id]["default_cranelift"],
                f"default and explicit Cranelift observations differ for {witness_id}")
        require(expected[witness_id]["retained_explicit_compatibility"]["selected"] ==
                expected[witness_id]["explicit_cranelift"]["selected"],
                f"selected pre-backend diagnostic differs for {witness_id}")
    check_review(value)
    print("phase24_filename_behavior_characterization: evidence ok")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "render", "check-review", "evidence"))
    args = parser.parse_args()
    value = load()
    validate_static(value)
    validate_transitions(value)
    if args.command == "render":
        REVIEW.write_text(render(value), encoding="utf-8")
    elif args.command == "check-review":
        check_review(value)
        print("phase24_filename_behavior_characterization: review current")
    elif args.command == "evidence":
        evidence(value)
    else:
        print("phase24_filename_behavior_characterization: ok")


if __name__ == "__main__":
    main()
