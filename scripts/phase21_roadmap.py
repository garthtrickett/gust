#!/usr/bin/env python3
"""Validate and project Phase 21 roadmap and OD-8 design authority."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
VISION = ROOT / "docs/VISION.md"
SHARED = ROOT / "docs/SHARED_SEMANTIC_ZONE.md"
DEMO = ROOT / "docs/DEMO_TARGET_PROGRAM.md"
TAIL = ROOT / "docs/ROADMAP_TAIL.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE21_ROADMAP.md"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase21-roadmap.yml"
JUSTFILE = ROOT / "justfile"
GUARD = "guard-cranelift-phase21-roadmap"

EXPECTED_PATCHES = [
    "21.0", "21.1", "21.2", "21.3", "21.4", "21.5", "21.6", "21.7",
    "21.7a", "21.7b", "21.8", "21.9", "21.10", "21.11", "21.12",
    "21.13", "21.13a", "21.14", "21.15", "21.16", "21.16a", "21.16b",
    "21.17a", "21.17", "21.17b", "21.17c", "21.17d", "21.17e", "21.17f", "21.18",
]

EXPECTED_AMENDMENTS = [
    {
        "patch": "21.16a",
        "status": "complete",
        "capability": "native_rebuild_workflow_dependency_correction",
        "reason": "post_merge_review_proved_the_generated_arena_offset_normalizer_was_a_compiler_input_missing_from_native_rebuild_workflow_paths",
        "merge_sha": "df8a7861b3f78e604e4f64519e785245ea801125",
        "exact_head_pull_request_successes": 5,
        "changes_compiler_semantics": False,
    },
    {
        "patch": "21.16b",
        "status": "complete",
        "capability": "generic_native_compiler_large_function_allocation_scaling",
        "trigger": "patch21_17_inherited_phase20_generated_large_function_replay",
        "passing_operation_counts": [64, 128, 256],
        "aborting_operation_counts": [512, 768, 1024],
        "abort_signal": 6,
        "abort_peak_rss_kib": 4198784,
        "required_operation_count": 1024,
        "passing_case_count": 34,
        "observed_large_function_peak_rss_kib": 95488,
        "post_merge_correction": "compiler_origin_selection_and_local_state_linear_canonical_transport",
        "compiler_origin_policy": "GUST_COMPILER_is_consumed_by_the_inherited_scale_harness_and_names_the_Cranelift_built_compiler_under_test",
        "corrected_emitter": "compiler/mir_native_backend_local_state_source.gst",
        "byte_identity_operation_count": 256,
        "byte_identity_policy": "pre_correction_and_corrected_Cranelift_built_compilers_emit_cmp_identical_canonical_bundles_and_native_artifacts",
        "changes_compiler_semantics": False,
        "falsifier": "the_Cranelift_built_compiler_completes_the_unchanged_1024_operation_cohort_with_MIR_to_C_parity_inside_registered_budgets",
        "boundary": "existing_Gust_MIR_ABI_layout_and_runtime_symbol_authority_only_no_cohort_reduction_budget_weakening_arena_capacity_bypass_module_exception_or_fallback",
    },
    {
        "patch": "21.17a",
        "status": "complete",
        "capability": "generic_scheduler_main_result_completion",
        "trigger": "patch21_17_inherited_phase20_long_lived_concurrent_replay",
        "operator_date": "2026-08-28",
        "expected_exit_status": 47,
        "observed_mir_to_c_statuses_before": [0, 47],
        "observed_native_status_before": 47,
        "focused_replays_per_backend": 32,
        "synchronization_authority": "scheduler_owned_pending_fiber_count_with_full_barrier_result_publication",
        "runtime_implementation": "src/runtime/fiber.c",
        "changes_runtime_symbols": False,
        "changes_abi_or_layout": False,
        "changes_accepted_gust_meaning": False,
        "falsifier": "every_focused_MIR_to_C_and_Cranelift_replay_returns_47_with_identical_empty_streams_and_the_patch21_17_full_inherited_replay_passes",
        "boundary": "generic_scheduler_completion_only_no_gate_weakening_fixture_exception_other_runtime_semantics_stdlib_CR15_or_patch21_18",
    },
    {
        "patch": "21.17b",
        "status": "complete",
        "capability": "historical_dependency_beachhead_prose_scope_correction",
        "trigger_run_id": 33171071194,
        "failed_guard": "guard-cranelift-dependency-beachhead",
        "failure_class": "generated_compiler_review_prose_false_positive",
        "correction": "compiler_CRANELIFT_review_markdown_is_excluded_from_the_production_reference_scan",
        "production_scan_scope": "compiler_src_tests_root_manifests_and_Makefile_unchanged",
        "changes_compiler_semantics": False,
        "falsifier": "the_focused_beachhead_guard_and_replacement_phase9_core_Historical_Full_shard_pass_while_production_source_remains_scanned",
        "boundary": "guard_population_classification_only_no_gate_weakening_compiler_MIR_backend_ABI_layout_runtime_symbol_seed_default_backend_Stdlib_CR15_or_phase22_change",
    },
    {
        "patch": "21.17c",
        "status": "complete",
        "capability": "historical_driver_handshake_fixture_reconciliation",
        "trigger_run_id": 33177003376,
        "failed_guard": "guard-cranelift-phase10-driver-handshake-contract",
        "failure_class": "positive_fixture_omitted_existing_full_program_canonical_format",
        "existing_authority": "patch21_14_exact_three_format_driver_handshake_contract",
        "correction": "positive_and_protocol_mismatch_fixture_handshakes_advertise_v1_v2_and_gust_compiler_executable_mir_v1",
        "changes_compiler_semantics": False,
        "falsifier": "the_focused_phase10_handshake_guard_and_replacement_phase10_Historical_Full_shard_pass_without_validator_or_worker_change",
        "boundary": "fixture_reconciliation_only_no_validator_worker_compiler_MIR_backend_ABI_layout_runtime_symbol_seed_default_backend_Stdlib_CR15_or_phase22_change",
    },
    {
        "patch": "21.17d",
        "status": "complete",
        "capability": "historical_phase9f_import_ABI_fixture_reconciliation",
        "trigger_run_id": 33177003376,
        "failed_guard": "guard-cranelift-phase9f-call-import-schema-validator",
        "failure_class": "negative_fixture_used_admitted_void_return_ABI_and_reached_call_result_validation",
        "existing_authority": "phase9f_import_scalar_ABI_allowlist_and_patch21_9_call_result_type_validation",
        "correction": "replace_obsolete_void_import_witness_with_unsupported_usize_return_import_witness",
        "changes_compiler_semantics": False,
        "falsifier": "the_focused_phase9f_schema_guard_and_replacement_phase9_core_Historical_Full_shard_pass_without_validator_or_compiler_change",
        "boundary": "negative_fixture_and_guard_expectation_only_no_validator_compiler_MIR_backend_ABI_layout_runtime_symbol_seed_default_backend_Stdlib_CR15_or_phase22_change",
    },
    {
        "patch": "21.17e",
        "status": "complete",
        "capability": "historical_driver_handshake_inventory_reconciliation",
        "trigger_run_id": 33194593462,
        "failed_guard": "guard-cranelift-phase10-driver-handshake-contract",
        "failure_class": "guard_froze_pre_patch21_14_worker_capability_inventory",
        "existing_authority": "patch21_14_full_program_canonical_MIR_worker_inventory",
        "correction": "require_gust_compiler_executable_mir_v1_and_exact_3_28_16_19_3_worker_inventory",
        "changes_compiler_semantics": False,
        "falsifier": "the_focused_phase10_handshake_guard_and_replacement_phase10_Historical_Full_shard_pass_without_worker_validator_or_compiler_change",
        "boundary": "guard_inventory_expectation_only_no_worker_validator_compiler_MIR_backend_ABI_layout_runtime_symbol_seed_default_backend_Stdlib_CR15_or_phase22_change",
    },
    {
        "patch": "21.17f",
        "status": "complete",
        "capability": "historical_driver_handshake_manifest_freeze",
        "trigger_run_id": 33205727452,
        "failed_guard": "guard-cranelift-phase10-driver-handshake-contract",
        "failure_class": "guard_compared_only_inventory_counts_and_missed_same_count_substitutions",
        "existing_authority": "patch21_14_exact_ordered_worker_capability_manifest",
        "correction": "compare_complete_ordered_handshake_manifest_and_reject_same_count_substitutions_in_every_category",
        "changes_compiler_semantics": False,
        "falsifier": "the_focused_phase10_guard_rejects_same_count_substitutions_for_canonical_format_operation_type_ABI_runtime_import_and_target_requirement",
        "boundary": "guard_manifest_expectation_and_negative_falsifiers_only_no_worker_validator_compiler_MIR_backend_ABI_layout_runtime_symbol_seed_default_backend_Stdlib_CR15_or_phase22_change",
    },
]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def render(authority: dict) -> str:
    predecessor = authority["predecessor"]
    activation = authority["activation"]
    od8 = authority["od8"]
    od15 = authority["od15"]
    boundary = authority["phase_boundary"]
    lines = [
        "# Cranelift Phase 21 Roadmap and OD-8 Design Authority",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase21_roadmap.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{authority['contract_version']}`",
        f"- Status: `{authority['status']}`",
        f"- Next patch: `{authority['next_patch']}`",
        f"- Operator date: `{activation['operator_date']}`",
        f"- Completion loop through: `{activation['completion_loop_through']}`",
        "",
        "## Exact predecessor closure",
        "",
        f"- Status: `{predecessor['closure_status']}`",
        f"- Merge: `{predecessor['closure_merge_sha']}`",
        f"- Historical Full run: `{predecessor['historical_run_id']}`",
        f"- Historical head: `{predecessor['historical_head_sha']}`",
        f"- Successful jobs: `{predecessor['historical_jobs']}`",
        "",
        "## Serial tracks",
        "",
    ]
    lines += [f"- `{track}`" for track in authority["serial_tracks"]]
    lines += ["", "## Roadmap amendments", ""]
    for amendment in authority["amendments"]:
        lines += [
            f"### Patch {amendment['patch']}",
            "",
            f"- Status: `{amendment['status']}`",
            f"- Capability: `{amendment['capability']}`",
        ]
        for key, value in amendment.items():
            if key in {"patch", "status", "capability"}:
                continue
            if isinstance(value, list):
                rendered = ",".join(str(item) for item in value)
            elif isinstance(value, bool):
                rendered = str(value).lower()
            else:
                rendered = str(value)
            lines.append(f"- {key.replace('_', ' ').title()}: `{rendered}`")
        lines.append("")
    lines += [
        "## OD-8",
        "",
        f"- Status: `{od8['status']}`",
        f"- Design authority: `{od8['design_authority']}`",
        f"- Obligation: `{od8['obligation']}`",
        f"- Discharge: `{od8['discharge']}`",
        f"- Syntax policy: `{od8['syntax_policy']}`",
        f"- Join policy: `{od8['join_policy']}`",
        f"- Nesting policy: `{od8['nesting_policy']}`",
        f"- Cross-tenant policy: `{od8['cross_tenant_policy']}`",
        f"- Rejection policy: `{od8['rejection_policy']}`",
        f"- Claim scope: `{od8['claim_scope']}`",
        f"- Demo target contract: `{od8['demo_target_contract']}`",
        "- Excluded claims:",
    ]
    lines += [f"  - `{claim}`" for claim in od8["excluded_claims"]]
    lines += [
        f"- Positive verdict gate: `{od8['positive_resolution_gate']}`",
        f"- Negative verdict gate: `{od8['negative_resolution_gate']}`",
    ]
    if authority.get("_od8_successor_verdict"):
        lines.append(
            f"- Successor evidence verdict: `{authority['_od8_successor_verdict']}`"
        )
    lines += [
        "", "## OD-15", "",
        f"- Status: `{od15['status']}`",
        f"- Question: `{od15['question']}`",
        f"- Criterion: `{od15['criterion']}`",
        "- Pinned authoritative environment:",
    ]
    lines += [f"  - `{field}`" for field in od15["authoritative_environment"]]
    lines += [
        f"- Cross-environment policy: `{od15['cross_environment_policy']}`",
        f"- Decision patch: `{od15['decision_patch']}`",
        f"- Blocks: `{od15['blocks']}`",
        "",
        "## Roadmap-patch boundary",
        "",
    ]
    lines += [f"- `{key}`: `{str(value).lower()}`"
              for key, value in boundary.items()]
    lines.append("")
    return "\n".join(lines)


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    authority = registry.get("phase21_roadmap")
    require(isinstance(authority, dict), "Phase 21 roadmap authority is missing")
    require(authority.get("contract_version") ==
            "phase21_roadmap_and_od8_design_authority_v1",
            "contract version drifted")
    require(authority.get("status") == "patch21_0_complete" and
            authority.get("next_patch") == "21.1",
            "roadmap status or successor drifted")

    closure = registry.get("phase20_closure", {})
    predecessor = authority.get("predecessor", {})
    require(closure.get("status") == predecessor.get("closure_status"),
            "Phase 20 closure status does not match the predecessor")
    historical = closure.get("authoritative_historical_full", {})
    require(historical.get("run_id") == predecessor.get("historical_run_id") and
            historical.get("head_sha") == predecessor.get("historical_head_sha") and
            historical.get("successful_jobs") ==
            predecessor.get("historical_jobs") == historical.get("total_jobs") and
            historical.get("conclusion") == "success",
            "exact predecessor Historical Full evidence drifted")
    require(predecessor.get("closure_merge_sha") ==
            "da18ab2ba3307c24ffabdc510fd0583f9a75e22b",
            "Phase 20 closure merge drifted")
    activation = authority.get("activation", {})
    require(activation == {
        "operator_date": "2026-08-24",
        "condition": "formal_phase20_closure",
        "condition_satisfied": True,
        "completion_loop_through": "21.18",
    }, "operator activation drifted")
    require(authority.get("amendments") == EXPECTED_AMENDMENTS,
            "Phase 21 roadmap amendments drifted")

    task = TASK.read_text(encoding="utf-8")
    require(task.startswith("# Phase 23 — MIR-to-C Deprecation"),
            "TASK.md does not open the active Phase 23 roadmap")
    require(
        "# Immutable Phase 22 Completion Record — Cranelift Default Backend "
        "Transition" in task,
        "TASK.md does not preserve the immutable Phase 22 record",
    )
    immutable_marker = (
        "# Immutable Phase 21 Completion Record — Tenant-Scoped Typed Queries "
        "and Cranelift Self-Hosting Qualification"
    )
    require(immutable_marker in task,
            "TASK.md does not preserve the immutable Phase 21 record")
    phase21 = task.split(immutable_marker, 1)[1].split(
        "# Immutable Phase 20 Completion Record", 1)[0]
    status = phase21.split("## Status", 1)[1].split(
        "## Immutable Contracts", 1)[0]
    rows = re.findall(r"^- \[([ x])\] Patch (21\.\d+[a-z]?) — .+$",
                      status, re.MULTILINE)
    require([patch for _, patch in rows] == EXPECTED_PATCHES,
            "Phase 21 status rows are missing, duplicated, or reordered")
    marks = [mark for mark, _ in rows]
    require(marks[0] == "x", "Patch 21.0 must remain DONE")
    if " " in marks:
        require("x" not in marks[marks.index(" "):],
                "Phase 21 DONE rows must form one contiguous prefix")
    require("On 2026-08-24 the operator conditionally authorized Phase 21" in phase21 and
            "That condition is satisfied" in phase21,
            "TASK.md does not record operator activation")
    for patch in EXPECTED_PATCHES:
        require(f"## Patch {patch} —" in phase21,
                f"TASK.md lacks Patch {patch} boundary")
    require("# Immutable Phase 20 Completion Record" in task and
            "## Phase 20 Closure Record" in task,
            "TASK.md does not preserve the Phase 20 completion record")

    od8 = authority.get("od8", {})
    require(od8.get("status") == "design_set_evidence_open",
            "OD-8 was incorrectly resolved or reopened")
    require(od8.get("excluded_claims") == [
        "caches", "non_query_reads", "multi_step_flows", "unsafe_or_raw_SQL",
        "trusted_request_context_establishment",
    ], "OD-8 excluded claim boundary drifted")
    require(od8.get("demo_target_contract") ==
            "typed_query_negative_not_raw_sql_and_exact_surface_deferred_to_21_3",
            "OD-8 demo target contract drifted")
    verdict_record = registry.get("phase21_od8_adversarial_verdict")
    if verdict_record is None:
        verdict_evidence = (
            "**DESIGN SET 2026-08-24 / EVIDENCE OPEN**",
            "### 56.2 What the analysis must check — design set, evidence open",
            "the evidence verdict is not",
        )
    else:
        require(verdict_record.get("status") == "patch21_7_complete" and
                verdict_record.get("verdict", {}).get("od8_status") ==
                "resolved_2026_08_25_bounded_positive",
                "OD-8 successor verdict authority drifted")
        verdict_evidence = (
            "**RESOLVED 2026-08-25 — BOUNDED POSITIVE**",
            "### 56.2 What the analysis checks — design set, bounded verdict recorded",
            "complete predefined §56.1",
        )
    vision = VISION.read_text(encoding="utf-8")
    for evidence in (*verdict_evidence,
        "non-forgeable typed Scope provenance",
        "compiler-owned typed-query path",
        "unsafe/raw SQL",
        "trusted request context",
    ):
        require(evidence in vision, f"VISION OD-8 authority is missing: {evidence}")
    require(authority.get("od15") == {
        "status": "resolved_2026_08_27_strict_binary_identity",
        "question": "native_stage_binary_identity_or_bounded_semantic_reproducibility",
        "criterion": "independently_produced_native_stages_are_byte_identical_under_the_pinned_authoritative_environment",
        "authoritative_environment": [
            "exact_source_commit",
            "cranelift_and_toolchain_versions",
            "target",
            "flags",
            "runtime_package",
            "linker",
            "normalized_environment",
        ],
        "cross_environment_policy": "a_separately_bounded_semantic_reproducibility_contract_may_cover_cross_machine_or_cross_toolchain_builds_but_cannot_weaken_phase21_closure",
        "decision_patch": "21.16",
        "blocks": "none",
    }, "OD-15 resolution authority drifted")
    require("| OD-15 | ~~**Native self-host reproducibility criterion**" in vision and
            "**RESOLVED 2026-08-27 — STRICT BINARY IDENTITY**" in vision and
            "### 111.1 Native self-host reproducibility (OD-15)" in vision,
            "VISION does not record the resolved OD-15 authority")

    shared = SHARED.read_text(encoding="utf-8")
    shared_flat = " ".join(shared.split())
    shared_verdict = ("OD-8 is `DESIGN SET / EVIDENCE OPEN`"
                      if verdict_record is None else
                      "OD-8 is `RESOLVED 2026-08-25 / BOUNDED POSITIVE`")
    for evidence in (
        "Tenant-scoped typed-query obligations and trusted `Scope` provenance",
        shared_verdict,
        "Every scoped join root and nested query owns its own obligation",
        "compiler-owned typed-query path",
    ):
        require(evidence in shared_flat,
                f"shared-zone authority is missing: {evidence}")
    demo = DEMO.read_text(encoding="utf-8")
    demo_flat = " ".join(demo.split())
    for evidence in (
        "error: query lacks trusted tenant-scope provenance",
        "matching predicate syntax does not prove trusted Scope provenance",
        "Privileged raw SQL is an explicit boundary outside this guarantee",
        "Patch 21.3 owns the final typed-query spelling",
    ):
        require(evidence in demo_flat,
                f"demo target OD-8 boundary is missing: {evidence}")
    tail = TAIL.read_text(encoding="utf-8")
    require("## Phase 21 — Cranelift self-hosting qualification" in tail and
            "Cranelift-built Gust compiler rebuilds itself" in tail,
            "Phase 21 roadmap-tail critical path drifted")

    boundary = authority.get("phase_boundary", {})
    require(all(boundary.get(key) is False for key in (
        "roadmap_patch_changes_compiler_semantics",
        "roadmap_patch_changes_mir_or_backends",
        "roadmap_patch_changes_abi_layout_or_runtime_symbols",
        "roadmap_patch_changes_bootstrap_seed",
        "roadmap_patch_edits_stdlib",
    )), "roadmap-only boundary drifted")
    require(boundary.get("phase22_default_backend_flip") == "out_of_scope",
            "Phase 22 boundary drifted")
    require(f"{GUARD}:" in JUSTFILE.read_text(encoding="utf-8"),
            "just guard is missing")
    require(f"just {GUARD}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the roadmap guard")
    require(f"just {GUARD}" in WORKFLOW.read_text(encoding="utf-8"),
            "dedicated workflow does not own the roadmap guard")
    projected = dict(authority)
    if verdict_record is not None:
        projected["_od8_successor_verdict"] = verdict_record["verdict"]["od8_status"]
    return projected


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review"))
    args = parser.parse_args()
    authority = validate()
    if args.command == "project":
        REVIEW.write_text(render(authority), encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and
                REVIEW.read_text(encoding="utf-8") == render(authority),
                "generated review is stale; run project")
    print(f"{GUARD}: ok")


if __name__ == "__main__":
    main()
