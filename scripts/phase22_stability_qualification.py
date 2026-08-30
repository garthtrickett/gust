#!/usr/bin/env python3
"""Validate, project, and replay Patch 22.8 stability authority."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
JUSTFILE = ROOT / "justfile"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE22_STABILITY_QUALIFICATION.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase22-stability-qualification.yml"
HISTORICAL = ROOT / ".github/workflows/cranelift-historical-full.yml"
GUARD_L1 = "guard-cranelift-phase22-stability-qualification-contract"
GUARD_L2 = "guard-cranelift-phase22-stability-qualification-evidence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def event_paths(workflow: str, event: str, next_event: str) -> str:
    start_marker = f"  {event}:"
    end_marker = f"  {next_event}:"
    require(start_marker in workflow and end_marker in workflow,
            f"workflow has no bounded {event} filter")
    return workflow.split(start_marker, 1)[1].split(end_marker, 1)[0]


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    predecessor = registry.get("phase22_historical_route_successor", {})
    require(predecessor.get("contract_version") ==
            "phase22_historical_route_successor_v1" and
            predecessor.get("status") == "corrective_prerequisite_complete",
            "Patch 22.8 Historical successor predecessor drifted")
    opening = registry.get("phase22_opening", {}).get(
        "stability_qualification", {})
    require(opening == {
        "operator_decision": "2026-08-29_one_time_exact_final_main",
        "required_successful_runs": 1,
        "workflow": "Cranelift Historical Full",
        "required_head": "exact_merged_final_post_flip_implementation_main",
        "required_job_population":
            "complete_registry_derived_population_all_success",
        "maximum_unresolved_material_review_findings": 0,
    }, "operator-selected one-time stability policy drifted")

    record = registry.get("phase22_stability_qualification")
    require(isinstance(record, dict), "Patch 22.8 authority is missing")
    require(record.get("contract_version") ==
            "phase22_stability_qualification_v1" and
            record.get("status") ==
            "one_time_exact_main_qualification_complete" and
            record.get("next_patch") == "22.9" and
            record.get("predecessor_authority") ==
            predecessor.get("contract_version") and
            record.get("operator_policy") ==
            "2026-08-29_one_authoritative_exact_final_main_run",
            "Patch 22.8 identity, status, or handoff drifted")

    historical = record.get("authoritative_historical_full", {})
    require(historical == {
        "workflow": "Cranelift Historical Full",
        "run_id": 33298850155,
        "event": "workflow_dispatch",
        "head_branch": "main",
        "head_sha": "a7adbcd186512a3b4fd99b953bb2bc30f6838c52",
        "status": "completed",
        "conclusion": "success",
        "successful_jobs": 18,
        "total_jobs": 18,
        "unfinished_jobs": 0,
        "non_success_jobs": 0,
        "created_at": "2026-08-30T07:17:24Z",
        "completed_at": "2026-08-30T08:34:02Z",
    }, "authoritative Historical Full evidence drifted or is incomplete")

    budgets = record.get("elapsed_budgets", {})
    require(budgets == {
        "workflow_timeout_seconds_per_job": 10800,
        "observed_run_wall_seconds": 4598,
        "observed_max_job_seconds": 3861,
        "observed_aggregate_job_seconds": 24422,
        "all_jobs_within_budget": True,
    }, "Historical elapsed-budget evidence drifted")
    require(budgets["observed_max_job_seconds"] <
            budgets["workflow_timeout_seconds_per_job"],
            "a Historical job exceeded its authoritative budget")

    review = record.get("implementation_review_gate", {})
    require(review == {
        "final_relay_pull_request": 264,
        "final_relay_head_sha": "3ada756e209bfa0556895169870ae00f96d94022",
        "final_relay_review_threads": 0,
        "transition_authority_pull_request": 265,
        "corrected_material_thread": "PRRT_kwDOS1ExJc6dfJGe",
        "correction": "exact_six_command_manifest_with_negative_substitution_guards",
        "unresolved_non_outdated_material_findings": 0,
    }, "implementation review evidence drifted or is not clear")
    require(record.get("retained_gates") == {
        "explicit_c_oracle_and_rollback": "qualified",
        "package_and_install": "qualified",
        "bootstrap_route": "explicit_mir_to_c",
        "pull_request_ci": "exact_full_head_sha_required",
        "fallback": "forbidden",
    }, "retained Phase 22 gates drifted")

    historical_workflow = HISTORICAL.read_text(encoding="utf-8")
    timeouts = [line.strip() for line in historical_workflow.splitlines()
                if "timeout-minutes:" in line]
    require(timeouts and set(timeouts) == {"timeout-minutes: 180"},
            "Historical workflow per-job timeout authority drifted")
    require("scripts/phase14_composition.py target-matrix-json" in
            historical_workflow and
            "matrix:\n        shard:" in historical_workflow and
            all(f"          - {shard}" in historical_workflow for shard in (
                "phase9-core", "phase19", "phase20", "phase18", "phase9g",
                "phase15", "phase16", "phase10", "phase11", "phase17")) and
            "guard-cranelift-historical-full" in historical_workflow,
            "Historical target projection or shard population drifted")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 22.8 — One-Time Default-Native Stability Qualification — DONE" in task and
            "- [ ] Patch 22.9 — Phase 22 Closure" in task,
            "22.8/22.9 roadmap boundary drifted")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "stability guard levels drifted")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in just and f"{GUARD_L2}:" in just,
            "stability guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the stability contract")

    focused = WORKFLOW.read_text(encoding="utf-8")
    require("- run: make phase10-native-package" in focused and
            f"just {GUARD_L1}" in focused and
            f"just {GUARD_L2}" in focused,
            "focused workflow does not own both stability guards")
    required_inputs = [
        "gust_v4.c", "compiler/*.gst", "compiler/experiments/cranelift/**",
        "README.md", "docs/ONE_WAY_LEDGER.md", "tests/*.gst", "justfile*",
        "src/runtime.c", "src/runtime/**",
        "tools/normalize_generated_arena_offsets.py",
    ]
    pull_paths = event_paths(focused, "pull_request", "push")
    push_paths = event_paths(focused, "push", "workflow_dispatch")
    for native_input in required_inputs:
        marker = f"      - '{native_input}'"
        require(marker in pull_paths and marker in push_paths,
                f"stability workflow omits native input {native_input}")

    boundary = record.get("boundary", {})
    require(boundary.get("records_one_time_stability_authority") is True and
            all(value is False for key, value in boundary.items()
                if key != "records_one_time_stability_authority"),
            "Patch 22.8 boundary widened")
    return record


def render(record: dict) -> str:
    historical = record["authoritative_historical_full"]
    budgets = record["elapsed_budgets"]
    review = record["implementation_review_gate"]
    retained = record["retained_gates"]
    lines = [
        "# Cranelift Phase 22.8 — One-Time Stability Qualification",
        "",
        "Generated from `scripts/cranelift_feature_registry.json`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Predecessor: `{record['predecessor_authority']}`",
        f"- Operator policy: `{record['operator_policy']}`",
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
        "## Elapsed budgets",
        "",
        f"- Per-job timeout: `{budgets['workflow_timeout_seconds_per_job']}` seconds",
        f"- Observed run wall time: `{budgets['observed_run_wall_seconds']}` seconds",
        f"- Observed maximum job time: `{budgets['observed_max_job_seconds']}` seconds",
        f"- Observed aggregate job time: `{budgets['observed_aggregate_job_seconds']}` seconds",
        f"- Every job within budget: `{str(budgets['all_jobs_within_budget']).lower()}`",
        "",
        "## Review and retained gates",
        "",
        f"- Final relay PR/head: `#{review['final_relay_pull_request']}` / `{review['final_relay_head_sha']}`",
        f"- Final relay review threads: `{review['final_relay_review_threads']}`",
        f"- Corrected material finding: `#{review['transition_authority_pull_request']}` / `{review['corrected_material_thread']}`",
        f"- Correction: `{review['correction']}`",
        f"- Unresolved material findings: `{review['unresolved_non_outdated_material_findings']}`",
    ]
    lines += [f"- {key}: `{value}`" for key, value in retained.items()]
    lines += [
        "",
        "This is the operator-selected single exact-final-main qualification,",
        "not a repeated daily soak. It records no Gust semantic, MIR/lowering,",
        "ABI/layout/runtime-symbol, target/linker, default-route, fallback,",
        "bootstrap/seed, Stdlib, or CR-15 change and does not begin Patch 22.9.",
        "",
    ]
    return "\n".join(lines)


def evidence() -> None:
    subprocess.run(
        ["just", "guard-cranelift-phase22-postflip-qualification-evidence"],
        cwd=ROOT, check=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command",
                        choices=("validate", "project", "check-review", "evidence"))
    args = parser.parse_args()
    record = validate()
    rendered = render(record)
    if args.command == "project":
        REVIEW.write_text(rendered, encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.exists() and REVIEW.read_text(encoding="utf-8") == rendered,
                "generated review view is stale")
    elif args.command == "evidence":
        evidence()
    print(f"{GUARD_L1}: {args.command} ok")


if __name__ == "__main__":
    main()
