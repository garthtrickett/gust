#!/usr/bin/env python3
"""Validate, project, and reproduce the Patch 23.1 checkpoint opening."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE23_ISSUE_HEALTH_OPENING.md"
TASK = ROOT / "TASK.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase23-issue-health-opening.yml"
SAME_SCOPE = ROOT / "compiler/phase23_same_scope_duplicate_current.gst"
PARENT_SHADOW = ROOT / "compiler/phase23_parent_scope_shadow_current.gst"
GUARD_L1 = "guard-cranelift-phase23-issue-health-opening-contract"
GUARD_L2 = "guard-cranelift-phase23-issue-health-opening-evidence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def authority() -> dict:
    data = json.loads(REGISTRY.read_text(encoding="utf-8"))
    value = data.get("phase23_issue_health_opening")
    require(isinstance(value, dict), "registry authority is missing")
    return value


def run(command: list[str], *, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        command,
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def validate() -> dict:
    value = authority()
    require(value.get("contract_version") == "phase23_issue_health_opening_v1",
            "contract version drifted")
    require(value.get("status") == "patch23_1_complete",
            "opening must be complete")
    require(value.get("next_patch") == "23.2", "next patch drifted")
    require(value.get("review_view") == REVIEW.relative_to(ROOT).as_posix(),
            "review view drifted")
    require(value.get("observed_main_sha") ==
            "aa21bef767eddf1622d6648f8547726575a6ffb5",
            "current-main reproduction base drifted")
    require(value.get("open_issue_numbers") ==
            [91, 101, 102, 103, 105, 108, 110, 133, 240],
            "complete open-issue snapshot drifted")

    issues = value.get("checkpoint_issues")
    require(isinstance(issues, list) and len(issues) == 3,
            "expected exactly three checkpoint issues")
    require([row.get("issue") for row in issues] == [110, 240, 105],
            "checkpoint issue order or identity drifted")
    required_fields = {
        "issue", "state", "owner", "invariant", "entry_points",
        "expected", "actual", "reachability", "superseding_authority",
        "semantic_effect", "bootstrap_effect", "closure_falsifier",
        "successor_patch",
    }
    for row in issues:
        require(set(row) == required_fields,
                f"issue #{row.get('issue')} field set drifted")
        require(row["state"] == "open" and row["owner"] == "cranelift",
                f"issue #{row['issue']} owner/state drifted")
        require(row["successor_patch"] in ("23.2", "23.3", "23.6"),
                f"issue #{row['issue']} successor is outside checkpoint")

    historical = value.get("latest_successful_historical_full")
    require(historical == {
        "workflow": "Cranelift Historical Full",
        "run_id": 33303824486,
        "event": "schedule",
        "head_sha": "a7adbcd186512a3b4fd99b953bb2bc30f6838c52",
        "status": "completed",
        "conclusion": "success",
        "successful_jobs": 18,
        "total_jobs": 18,
        "relationship": "latest_successful_predecessor_baseline_not_phase23_closure_evidence",
    }, "Historical Full baseline drifted")

    repository = value.get("repository_health")
    require(repository == {
        "observed_at_utc": "2026-08-30T14:18:00Z",
        "workflow_file_count": 121,
        "pull_request_trigger_count": 118,
        "push_trigger_count": 119,
        "workflow_dispatch_trigger_count": 103,
        "ruleset_id": 20214069,
        "ruleset_name": "Protect main",
        "ruleset_enforcement": "active",
        "required_status_checks": ["Codex / Trusted actor"],
        "required_approving_review_count": 0,
        "required_review_thread_resolution": True,
    }, "repository-health snapshot drifted")

    assurance = value.get("assurance_boundary")
    require(assurance == {
        "authorization": "phase_A_and_phase_B_report_only",
        "historical_inputs": [110, 240],
        "selected_current_pilot": 105,
        "allowed_patches": ["23.4", "23.5"],
        "forbidden": [
            "assurance_phases_C_D_or_E",
            "independent_model_review",
            "protected_publication",
            "repository_rule_changes",
            "new_required_status_check",
        ],
    }, "assurance authorization boundary drifted")

    require(value.get("deprecation_predecessor_gate") ==
            ["23.2", "23.3", "23.4", "23.5", "23.6", "23.6a"],
            "deprecation predecessor gate drifted")
    successor = value.get("phase22_closed_inventory_successor", {})
    successor_commands = successor.get("commands", [])
    successor_metadata = dict(successor)
    successor_metadata.pop("commands", None)
    require(successor_metadata == {
        "status": "exact_phase23_extension_excluded_only_from_phase22_relay_identity",
        "owning_patch": "23.1",
        "path": "scripts/phase23_issue_health_opening.py",
        "selection": "explicit_c",
        "invocation_count": 2,
        "phase22_relay_contract": "the_exact_six_site_Stdlib_relay_and_306_invocation_inventory_remain_unchanged",
        "phase23_contract": "both_new_calls_remain_visible_in_the_live_scan_and_are_owned_by_the_Patch_23_1_evidence_guard",
        "falsifier": "missing_partial_extra_path_command_or_selection_drift_is_rejected",
    }, "Phase 22 closed-inventory successor authority drifted")
    require(len(successor_commands) == 2 and
            successor_commands[0].endswith("str(SAME_SCOPE)]") and
            successor_commands[1].endswith("str(PARENT_SHADOW)]") and
            all(command.startswith("['." + "/gust', '--backend', 'mir-to-c', ")
                for command in successor_commands),
            "Phase 22 successor command manifest drifted")
    require(value.get("boundary") == {
        "changes_guard_behavior": False,
        "changes_compiler_behavior": False,
        "changes_backend_route_or_fallback": False,
        "changes_issue_state": False,
        "changes_accepted_Gust_program_meaning": False,
        "adds_or_changes_MIR_operations": False,
        "changes_ABI_layout_or_runtime_symbols": False,
        "changes_bootstrap_seed": False,
        "edits_stdlib_or_CR15": False,
        "begins_deprecation_patch": False,
    }, "Patch 23.1 boundary drifted")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 23.1 — Post-Phase-22 Assurance and Issue-Health Opening — DONE" in task,
            "TASK status does not mark Patch 23.1 DONE")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "test-level assignments drifted")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in just and f"{GUARD_L2}:" in just,
            "just guard reachability drifted")
    require(GUARD_L1 in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast contract reachability drifted")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    for required in (
        "pull_request:", "push:", "workflow_dispatch:", "gust_v4.c",
        "compiler/*.gst", "src/runtime.c", "src/runtime/**",
        "tools/normalize_generated_arena_offsets.py", GUARD_L1, GUARD_L2,
    ):
        require(required in workflow, f"workflow is missing {required}")
    for fixture in (SAME_SCOPE, PARENT_SHADOW):
        require(fixture.is_file(), f"missing witness {fixture.relative_to(ROOT)}")
    return value


def render(value: dict) -> str:
    lines = [
        "# Cranelift Phase 23 Issue-Health Opening",
        "",
        "Generated by `scripts/phase23_issue_health_opening.py`; do not edit by hand.",
        "",
        f"- Contract: `{value['contract_version']}`",
        f"- Status: `{value['status']}`",
        f"- Reproduction main: `{value['observed_main_sha']}`",
        f"- Next patch: `{value['next_patch']}`",
        "- Open issues: `" + ", ".join(f"#{number}" for number in value["open_issue_numbers"]) + "`",
        "",
        "## Checkpoint issues",
        "",
        "| Issue | Entry points | Actual current-main result | Reachability | Successor | Closure falsifier |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for row in value["checkpoint_issues"]:
        rendered_entry_points = [
            "just guard-" + entry.removeprefix("just_recipe:")
            if entry.startswith("just_recipe:") else entry
            for entry in row["entry_points"]
        ]
        lines.append(
            f"| #{row['issue']} | `{'; '.join(rendered_entry_points)}` | "
            f"{row['actual']} | {row['reachability']} | Patch {row['successor_patch']} | "
            f"{row['closure_falsifier']} |"
        )
    lines.extend(["", "## Ownership and effects", ""])
    for row in value["checkpoint_issues"]:
        lines.extend([
            f"### Issue #{row['issue']}", "",
            f"- Owner: `{row['owner']}`",
            f"- Invariant: {row['invariant']}",
            f"- Expected: {row['expected']}",
            f"- Superseding authority: {row['superseding_authority']}",
            f"- Semantic effect in Patch 23.1: `{row['semantic_effect']}`",
            f"- Bootstrap effect in Patch 23.1: `{row['bootstrap_effect']}`",
            "",
        ])
    historical = value["latest_successful_historical_full"]
    lines.extend([
        "## Evidence health", "",
        f"- Latest successful Historical Full: run `{historical['run_id']}`, event "
        f"`{historical['event']}`, exact SHA `{historical['head_sha']}`, "
        f"`{historical['successful_jobs']}/{historical['total_jobs']}` jobs successful.",
        f"- Relationship: `{historical['relationship']}`.",
        f"- Workflow files at the reproduction base: `{value['repository_health']['workflow_file_count']}`; "
        f"pull-request triggers: `{value['repository_health']['pull_request_trigger_count']}`.",
        f"- Main ruleset: `{value['repository_health']['ruleset_name']}` requires "
        f"`Codex / Trusted actor` and resolved review threads; approving reviews required: `0`.",
        "", "## Assurance boundary", "",
        "- Authorized: Phase A authority/trigger inventory and Phase B deterministic evaluator in report-only mode.",
        "- Historical stale-evidence inputs: `#110`, `#240`; selected current pilot: `#105`.",
        "- Not authorized: Phases C-E, independent model review, protected publication, repository-rule changes, or a new required check.",
        "- MIR-to-C deprecation remains blocked until Patches `23.2` through `23.6a` are DONE.",
        "- The two Patch 23.1 explicit-C calls stay visible in the live invocation scan; only Phase 22's closed 306-call relay identity excludes their exact registered path and commands.",
        "", "Patch 23.1 records evidence only. It changes no guard, compiler behaviour, "
        "backend route, issue state, accepted Gust meaning, MIR, ABI/layout, runtime "
        "symbol, bootstrap seed, Stdlib source, or CR-15 authority.", "",
    ])
    return "\n".join(lines)


def check_review(value: dict) -> None:
    expected = render(value)
    require(REVIEW.read_text(encoding="utf-8") == expected,
            "generated review is stale; run render")


def evidence() -> None:
    value = validate()
    require((ROOT / "gust").is_file(), "make gust prerequisite is missing")
    driver = ROOT / "build/phase10-package/bin/gust-native-backend"
    require(driver.is_file() and os.access(driver, os.X_OK),
            "make phase10-native-package prerequisite is missing")

    lower = run(["just", "guard-mir-lower-tiny-function-surface"])
    require(lower.returncode == 0,
            "#110 retained lowering guard does not pass current main")
    successor = run(["python3", "scripts/phase23_mir_evidence_owner.py", "evidence"])
    require(successor.returncode == 0,
            "#110 Patch 23.2 successor authority does not pass current main")

    resource_env = os.environ.copy()
    resource_env["GUST_NATIVE_BACKEND_DRIVER"] = str(driver)
    resource = run(
        ["just", "guard-cranelift-phase20-resource-acquisition-parity"],
        env=resource_env,
    )
    native = ROOT / "build/guards/phase20_resource_acquisition/phase20_resource_acquisition_source.native"
    require(resource.returncode != 0 and native.is_file(),
            "#240 stale guard did not fail after producing the supported native artifact")
    native_run = run([str(native)])
    require(native_run.returncode == 168 and not native_run.stdout and not native_run.stderr,
            "#240 positive native observable drifted")

    with tempfile.TemporaryDirectory(prefix="gust-phase23-issue-health-") as raw:
        temp = Path(raw)
        same_c = run(["./gust", "--backend", "mir-to-c", str(SAME_SCOPE)])
        shadow_c = run(["./gust", "--backend", "mir-to-c", str(PARENT_SHADOW)])
        require(same_c.returncode == 0 and not same_c.stderr,
                "#105 same-scope duplicate is no longer accepted by current main")
        require(shadow_c.returncode == 0 and not shadow_c.stderr,
                "#105 parent-scope shadow is no longer accepted by current main")
        combined = temp / "same_scope.c"
        combined.write_bytes((ROOT / "src/runtime.c").read_bytes() + same_c.stdout)
        cc = run([os.environ.get("CC", "cc"), "-O0", "-w", "-pthread", "-Isrc",
                  str(combined), "-o", str(temp / "same_scope")])
        cc_log = (cc.stdout + cc.stderr).decode("utf-8", "replace")
        require(cc.returncode != 0 and "redefinition of" in cc_log and "value" in cc_log,
                "#105 host-C same-scope redeclaration failure drifted")

    check_review(value)
    print("phase23_issue_health_opening: evidence ok")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "render", "check-review", "evidence"))
    args = parser.parse_args()
    value = validate()
    if args.command == "render":
        REVIEW.write_text(render(value), encoding="utf-8")
    elif args.command == "check-review":
        check_review(value)
        print("phase23_issue_health_opening: review current")
    elif args.command == "evidence":
        evidence()
    else:
        print("phase23_issue_health_opening: ok")


if __name__ == "__main__":
    main()
