#!/usr/bin/env python3
"""Validate and project Patch 23.14 exact-main Historical authority."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE23_HISTORICAL_FULL_QUALIFICATION.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
FOCUSED_WORKFLOW = ROOT / ".github/workflows/phase23-historical-full-qualification.yml"
HISTORICAL_WORKFLOW = ROOT / ".github/workflows/cranelift-historical-full.yml"
GUARD = "guard-cranelift-phase23-historical-full-qualification-contract"

HISTORICAL_SHARDS = [
    "phase9-core", "phase19", "phase20", "phase18", "phase9g",
    "phase15", "phase16", "phase10", "phase11", "phase17",
]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def event_paths(workflow: str, event: str, next_event: str) -> str:
    start_marker = f"  {event}:"
    end_marker = f"  {next_event}:"
    require(start_marker in workflow and end_marker in workflow,
            f"workflow has no bounded {event} filter")
    return workflow.split(start_marker, 1)[1].split(end_marker, 1)[0]


def declared_targets() -> list[str]:
    output = subprocess.check_output(
        ["python3", "scripts/phase14_composition.py", "target-matrix-json"],
        cwd=ROOT,
        text=True,
    )
    targets = json.loads(output)
    require(isinstance(targets, list) and targets and
            all(isinstance(target, str) and target for target in targets) and
            len(targets) == len(set(targets)),
            "declared target projection is empty, malformed, or duplicated")
    return targets


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    predecessor = registry.get("phase23_cross_feature_qualification", {})
    require(predecessor.get("contract_version") ==
            "phase23_cross_feature_qualification_v1" and
            predecessor.get("status") == "patch23_13_complete",
            "Patch 23.13 predecessor is not complete")

    record = registry.get("phase23_historical_full_qualification")
    require(isinstance(record, dict), "Patch 23.14 authority is missing")
    require(record.get("contract_version") ==
            "phase23_historical_full_qualification_v1" and
            record.get("status") == "patch23_14_complete" and
            record.get("next_patch") == "23.15" and
            record.get("owner") == "cranelift" and
            record.get("review_view") == REVIEW.relative_to(ROOT).as_posix() and
            record.get("renderer") == Path(__file__).relative_to(ROOT).as_posix() and
            record.get("predecessor_authority") ==
            predecessor.get("contract_version"),
            "Patch 23.14 identity, status, or predecessor drifted")

    implementation = record.get("final_implementation_review_gate", {})
    require(implementation == {
        "pull_request": 296,
        "head_sha": "321ddd2e0cb093298db800a7ea966d5ae92e5418",
        "merged_main_sha": "fee6600d86f85f8a0a0da94211ae89895869187e",
        "event": "pull_request",
        "successful_workflows": 123,
        "total_workflows": 123,
        "unfinished_workflows": 0,
        "non_success_workflows": 0,
        "unresolved_non_outdated_review_threads": 0,
        "unresolved_material_findings": 0,
    }, "final implementation PR or review evidence drifted")

    historical = record.get("authoritative_historical_full", {})
    require(historical == {
        "workflow": "Cranelift Historical Full",
        "run_id": 33584176425,
        "event": "workflow_dispatch",
        "head_branch": "main",
        "head_sha": "fee6600d86f85f8a0a0da94211ae89895869187e",
        "status": "completed",
        "conclusion": "success",
        "successful_jobs": 18,
        "total_jobs": 18,
        "unfinished_jobs": 0,
        "non_success_jobs": 0,
        "created_at": "2026-09-02T02:41:49Z",
        "completed_at": "2026-09-02T04:12:03Z",
    }, "authoritative Historical evidence drifted or is incomplete")
    require(historical["head_sha"] == implementation["merged_main_sha"],
            "Historical run is not on the exact final implementation main")

    targets = declared_targets()
    population = record.get("expected_job_population", {})
    require(population == {
        "inventory_job": "Project declared Phase 14 targets",
        "build_job": "Build shared Gust artifact",
        "historical_shards": HISTORICAL_SHARDS,
        "declared_targets": targets,
        "completion_job": "Level 3 declared-target completion",
        "expected_unique_jobs": 3 + len(HISTORICAL_SHARDS) + len(targets),
        "observed_unique_jobs": 18,
        "every_expected_job_present_exactly_once": True,
    }, "complete Historical job population drifted")
    require(population["expected_unique_jobs"] == historical["total_jobs"] == 18,
            "expected and observed Historical job totals differ")

    budgets = record.get("elapsed_budgets", {})
    require(budgets == {
        "workflow_timeout_seconds_per_job": 10800,
        "observed_run_wall_seconds": 5414,
        "observed_max_job_seconds": 4286,
        "observed_aggregate_job_seconds": 22697,
        "all_jobs_within_budget": True,
    }, "Historical elapsed-budget evidence drifted")
    require(budgets["observed_max_job_seconds"] <
            budgets["workflow_timeout_seconds_per_job"],
            "a Historical job exceeded its declared budget")

    coverage = record.get("qualified_phase23_coverage", {})
    require(coverage == {
        "final_implementation": "phase23_cross_feature_qualification_v1",
        "issue_health": [
            "phase23_mir_evidence_owner_v1",
            "phase23_resource_acquisition_parity_v1",
            "phase23_same_scope_declaration_v1",
        ],
        "assurance_report_only": [
            "phase23_assurance_phase_a_v1",
            "phase23_assurance_phase_b_v1",
        ],
        "focused_compatibility_successor": "phase23_mir_to_c_focused_live_v1",
        "native_default_package_no_fallback": "phase23_production_release_audit_v1",
        "bootstrap_fixed_point": "phase23_cross_feature_qualification_v1",
        "historical_population": ".github/workflows/cranelift-historical-full.yml",
    }, "Phase 23 coverage projection drifted")
    for key in (
        "phase23_mir_evidence_owner",
        "phase23_resource_acquisition_parity",
        "phase23_same_scope_declaration",
    ):
        require(registry[key].get("status") == "closed_on_merged_current_main",
                f"{key} issue-health authority is not closed")
    require(registry["phase23_assurance_phase_a"].get("status") ==
            "phase23_4_complete_report_only" and
            registry["phase23_assurance_phase_b"].get("status") ==
            "phase23_5_complete_report_only",
            "Assurance A/B is not complete and report-only")
    require(registry["phase23_mir_to_c_focused_live"].get("contract_version") ==
            coverage["focused_compatibility_successor"] and
            registry["phase23_production_release_audit"].get("contract_version") ==
            coverage["native_default_package_no_fallback"],
            "focused compatibility or production/package authority drifted")

    historical_workflow = HISTORICAL_WORKFLOW.read_text(encoding="utf-8")
    require("name: Cranelift Historical Full" in historical_workflow and
            "scripts/phase14_composition.py target-matrix-json" in historical_workflow and
            "matrix:\n        target: ${{ fromJSON(needs.inventory.outputs.phase14_targets) }}" in historical_workflow and
            "Level 3 declared-target completion" in historical_workflow,
            "Historical workflow identity or target projection drifted")
    for shard in HISTORICAL_SHARDS:
        require(historical_workflow.count(f"          - {shard}\n") == 1,
                f"Historical shard is missing or duplicated: {shard}")
    timeouts = [line.strip() for line in historical_workflow.splitlines()
                if "timeout-minutes:" in line]
    require(len(timeouts) == 5 and set(timeouts) == {"timeout-minutes: 180"},
            "Historical per-job timeout authority drifted")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 23.14 — Exact-Main Historical Full Qualification — DONE" in task and
            "- [ ] Patch 23.15 — Phase 23 Closure" in task,
            "23.14/23.15 roadmap boundary drifted")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD) == 1, "Patch 23.14 guard level drifted")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD}:" in just, "Patch 23.14 just guard is missing")
    require(f"just {GUARD}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Patch 23.14 contract")

    focused = FOCUSED_WORKFLOW.read_text(encoding="utf-8")
    require(f"just {GUARD}" in focused,
            "focused workflow does not own the Patch 23.14 contract")
    required_inputs = [
        "TASK.md", "gust_v4.c", "compiler/**", "scripts/**", "src/runtime.c",
        "src/runtime/**", "tools/normalize_generated_arena_offsets.py",
        ".github/workflows/**", "justfile*",
    ]
    pull_paths = event_paths(focused, "pull_request", "push")
    push_paths = event_paths(focused, "push", "workflow_dispatch")
    for native_input in required_inputs:
        marker = f"      - '{native_input}'"
        require(marker in pull_paths and marker in push_paths,
                f"Patch 23.14 workflow omits applicable input {native_input}")

    require(record.get("staleness_policy") == {
        "rule": "replace_if_applicable_phase23_input_lands_before_closure_publication",
        "applicable_input":
            "change_that_alters_the_Historical_workload_or_final_implementation_artifact",
        "authority_only_projection":
            "does_not_stale_the_recorded_final_implementation_run",
    },
            "Historical staleness policy drifted")
    require(record.get("boundary") == {
        "records_exact_main_historical_authority": True,
        "changes_accepted_Gust_program_meaning": False,
        "adds_or_changes_MIR_operations": False,
        "changes_ABI_layout_runtime_symbols_target_or_linker": False,
        "changes_backend_route_default_or_fallback": False,
        "changes_bootstrap_route_or_seed": False,
        "edits_stdlib_or_CR15": False,
        "begins_patch23_15": False,
    }, "Patch 23.14 boundary widened")
    return record


def render(record: dict) -> str:
    implementation = record["final_implementation_review_gate"]
    historical = record["authoritative_historical_full"]
    population = record["expected_job_population"]
    budgets = record["elapsed_budgets"]
    coverage = record["qualified_phase23_coverage"]
    lines = [
        "# Cranelift Phase 23.14 — Exact-Main Historical Full Qualification",
        "",
        "Generated from `scripts/cranelift_feature_registry.json`; do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Predecessor: `{record['predecessor_authority']}`",
        "",
        "## Final implementation and review gate",
        "",
        f"- PR/head: `#{implementation['pull_request']}` / `{implementation['head_sha']}`",
        f"- Exact merged main: `{implementation['merged_main_sha']}`",
        f"- Exact-head workflows: `{implementation['successful_workflows']}/{implementation['total_workflows']}` successful",
        f"- Unfinished/non-success: `{implementation['unfinished_workflows']}/{implementation['non_success_workflows']}`",
        f"- Unresolved review threads/material findings: `{implementation['unresolved_non_outdated_review_threads']}/{implementation['unresolved_material_findings']}`",
        "",
        "## Authoritative Historical Full",
        "",
        f"- Workflow/run: `{historical['workflow']}` / `{historical['run_id']}`",
        f"- Event/branch: `{historical['event']}` / `{historical['head_branch']}`",
        f"- Exact head: `{historical['head_sha']}`",
        f"- Status/conclusion: `{historical['status']}` / `{historical['conclusion']}`",
        f"- Complete jobs: `{historical['successful_jobs']}/{historical['total_jobs']}` successful",
        f"- Unfinished/non-success: `{historical['unfinished_jobs']}/{historical['non_success_jobs']}`",
        f"- Created/completed: `{historical['created_at']}` / `{historical['completed_at']}`",
        "",
        "## Population and budgets",
        "",
        f"- Historical shards: `{len(population['historical_shards'])}`",
        f"- Registry-derived declared targets: `{len(population['declared_targets'])}`",
        f"- Expected/observed unique jobs: `{population['expected_unique_jobs']}/{population['observed_unique_jobs']}`",
        f"- Every expected job exactly once: `{str(population['every_expected_job_present_exactly_once']).lower()}`",
        f"- Per-job timeout: `{budgets['workflow_timeout_seconds_per_job']}` seconds",
        f"- Observed run/max/aggregate seconds: `{budgets['observed_run_wall_seconds']}/{budgets['observed_max_job_seconds']}/{budgets['observed_aggregate_job_seconds']}`",
        f"- Every job within budget: `{str(budgets['all_jobs_within_budget']).lower()}`",
        "",
        "## Registered coverage",
        "",
    ]
    for key, value in coverage.items():
        rendered_value = ", ".join(value) if isinstance(value, list) else value
        lines.append(f"- {key}: `{rendered_value}`")
    lines += [
        "",
        "Only a change that alters the Historical workload or final",
        "implementation artifact invalidates this run. This generated",
        "authority projection does not stale its recorded implementation main.",
        "",
        "This authority records the exact final implementation main and its",
        "complete Historical population. It changes no program meaning, MIR",
        "operation, ABI, runtime symbol, backend route, fallback, bootstrap",
        "seed, Stdlib surface, or CR-15 state, and it does not begin Patch 23.15.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review"))
    args = parser.parse_args()
    record = validate()
    rendered = render(record)
    if args.command == "project":
        REVIEW.write_text(rendered, encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.exists() and REVIEW.read_text(encoding="utf-8") == rendered,
                "generated review view is stale")
    print(f"{GUARD}: {args.command} ok")


if __name__ == "__main__":
    main()
