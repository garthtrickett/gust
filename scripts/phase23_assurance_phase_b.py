#!/usr/bin/env python3
"""Evaluate captured Phase 23 assurance manifests without executing candidates."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from phase23_assurance_phase_a import LOSS_TAXONOMY, validate as validate_phase_a


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
MANIFESTS = ROOT / "scripts/phase23_assurance_manifests.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE23_ASSURANCE_PHASE_B.md"
TASK = ROOT / "TASK.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
GUARD = "guard-cranelift-phase23-assurance-phase-b-contract"
POLICY = "exact_full_candidate_head_sha_and_event_pull_request_with_all_review_threads_resolved"
IDENTITY_KEYS = {"repository", "head_sha", "base_sha", "event"}
MANIFEST_KEYS = {
    "id", "subject", "expected_result", "expected_candidate", "candidate", "expected_inventory",
    "observed_inventory", "expected_runs", "observed_runs", "expected_artifacts",
    "observed_artifacts", "candidate_policy", "declared_loss_state", "reason",
}
EXPECTED_AUTHORITY = {
    "contract_version": "phase23_assurance_phase_b_v1",
    "status": "phase23_5_complete_report_only",
    "owner": "cranelift",
    "phase_a_envelopes": "scripts/phase23_assurance_envelopes.json",
    "manifests": "scripts/phase23_assurance_manifests.json",
    "review_view": "compiler/CRANELIFT_PHASE23_ASSURANCE_PHASE_B.md",
    "renderer": "scripts/phase23_assurance_phase_b.py",
    "guard": GUARD,
    "authorization": "phase_A_and_phase_B_report_only",
    "forbidden": [
        "assurance_phases_C_D_or_E", "independent_model_review",
        "protected_publication", "repository_rule_changes",
        "new_required_status_check", "new_workflow", "candidate_code_execution",
    ],
    "boundary": {
        "changes_compiler_behavior": False,
        "changes_accepted_Gust_program_meaning": False,
        "changes_MIR_or_native_lowering": False,
        "changes_ABI_layout_or_runtime_symbols": False,
        "changes_backend_route_or_fallback": False,
        "changes_bootstrap_seed": False,
        "edits_stdlib_or_CR15": False,
        "adds_workflow_or_required_status": False,
        "executes_candidate_code": False,
        "begins_patch23_6": False,
    },
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def read_json(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{GUARD}: invalid JSON in {path.relative_to(ROOT)}: {exc}") from exc
    require(isinstance(data, dict), f"{path.relative_to(ROOT)} must contain an object")
    return data


def full_sha(value: object) -> bool:
    return isinstance(value, str) and len(value) == 40 and all(c in "0123456789abcdef" for c in value)


def digest(value: object) -> bool:
    return isinstance(value, str) and len(value) == 64 and all(c in "0123456789abcdef" for c in value)


def validate_identity(value: object, label: str) -> dict:
    require(isinstance(value, dict) and set(value) == IDENTITY_KEYS, f"{label} identity field set drifted")
    require(value["repository"] == "garthtrickett/gust", f"{label} repository drifted")
    require(full_sha(value["head_sha"]) and full_sha(value["base_sha"]), f"{label} requires full SHAs")
    require(value["event"] == "pull_request", f"{label} event is not pull_request")
    return value


def ids(values: object, label: str) -> list[str]:
    require(isinstance(values, list) and values, f"{label} is empty")
    require(all(isinstance(v, str) and v for v in values), f"{label} is malformed")
    require(len(values) == len(set(values)), f"{label} contains a duplicate")
    return values


def artifact_map(values: object, label: str) -> dict[str, str]:
    require(isinstance(values, list) and values, f"{label} is empty")
    result: dict[str, str] = {}
    for value in values:
        require(isinstance(value, dict) and set(value) == {"id", "sha256"}, f"{label} is malformed")
        item, sha = value["id"], value["sha256"]
        require(isinstance(item, str) and item and digest(sha), f"{label} digest is malformed")
        require(item not in result, f"{label} duplicate artifact {item}")
        result[item] = sha
    return result


def run_map(values: object, candidate: dict, label: str) -> dict[str, dict]:
    require(isinstance(values, list), f"{label} must be a list")
    result: dict[str, dict] = {}
    for value in values:
        require(isinstance(value, dict) and set(value) == {"name", "head_sha", "event", "status", "conclusion"},
                f"{label} run is malformed")
        name = value["name"]
        require(isinstance(name, str) and name and name not in result, f"{label} run name drifted")
        require(value["head_sha"] == candidate["head_sha"], f"{label} run uses wrong SHA")
        require(value["event"] == candidate["event"], f"{label} run uses wrong event")
        result[name] = value
    return result


def classify(manifest: dict) -> str:
    try:
        expected_candidate = validate_identity(manifest["expected_candidate"], manifest["id"])
        candidate = validate_identity(manifest["candidate"], manifest["id"])
    except SystemExit as exc:
        return "stale_evidence" if "event" in str(exc) else "malformed_evidence"
    if candidate != expected_candidate:
        return "stale_evidence"
    if manifest["candidate_policy"] != POLICY:
        return "stale_evidence"
    declared = manifest["declared_loss_state"]
    if declared != "passed":
        return declared
    try:
        expected_inventory = ids(manifest["expected_inventory"], f"{manifest['id']} expected inventory")
        observed_inventory = ids(manifest["observed_inventory"], f"{manifest['id']} observed inventory")
        expected_runs = run_map(manifest["expected_runs"], candidate, f"{manifest['id']} expected runs")
        observed_runs = run_map(manifest["observed_runs"], candidate, f"{manifest['id']} observed runs")
        expected_artifacts = artifact_map(manifest["expected_artifacts"], f"{manifest['id']} expected artifacts")
        observed_artifacts = artifact_map(manifest["observed_artifacts"], f"{manifest['id']} observed artifacts")
    except (KeyError, SystemExit):
        return "malformed_evidence"
    if expected_inventory != observed_inventory:
        return "unresolved"
    if not observed_runs:
        return "empty_selection"
    if set(expected_runs) != set(observed_runs):
        return "unresolved"
    for run in observed_runs.values():
        if run["status"] != "completed":
            return "unresolved"
        if run["conclusion"] == "cancelled":
            return "skipped_with_reason"
        if run["conclusion"] != "success":
            return "failed"
    if expected_artifacts != observed_artifacts:
        return "malformed_evidence"
    return "passed"


def authority() -> None:
    value = read_json(REGISTRY).get("phase23_assurance_phase_b")
    require(value == EXPECTED_AUTHORITY, "registry Phase B authority drifted")


def validate_manifest_source() -> list[dict]:
    data = read_json(MANIFESTS)
    require(set(data) == {"schema_version", "phase", "loss_taxonomy", "fixtures"}, "manifest source field set drifted")
    require(data["schema_version"] == "phase23_assurance_phase_b_manifest_v1" and data["phase"] == "23",
            "manifest source version or phase drifted")
    require(data["loss_taxonomy"] == LOSS_TAXONOMY, "manifest loss taxonomy drifted")
    fixtures = data["fixtures"]
    require(isinstance(fixtures, list) and len(fixtures) == 17, "fixture inventory drifted")
    expected = {
        "issue110_qualified", "issue240_qualified", "phase22_closed_historical_qualified",
        "issue105_preimplementation", "wrong_sha", "wrong_event", "cancelled", "red",
        "missing", "empty", "malformed", "forged_digest", "candidate_policy_change",
        "unsupported", "not_applicable", "fallback", "stale_unresolved",
    }
    actual = {item.get("id") for item in fixtures if isinstance(item, dict)}
    require(actual == expected, "fixture identities drifted")
    for fixture in fixtures:
        require(isinstance(fixture, dict) and set(fixture) == MANIFEST_KEYS, "fixture field set drifted")
        require(isinstance(fixture["id"], str) and fixture["id"], "fixture id is malformed")
        require(isinstance(fixture["expected_result"], str), f"{fixture['id']} expected result is malformed")
        require(fixture["expected_result"] in LOSS_TAXONOMY, f"{fixture['id']} expected result is unknown")
        require(fixture["declared_loss_state"] in LOSS_TAXONOMY, f"{fixture['id']} declared loss is unknown")
        require(isinstance(fixture["reason"], str) and fixture["reason"], f"{fixture['id']} reason is empty")
        result = classify(fixture)
        require(result == fixture["expected_result"],
                f"{fixture['id']} expected {fixture['expected_result']}, got {result}")
    return fixtures


def validate() -> list[dict]:
    validate_phase_a()
    authority()
    fixtures = validate_manifest_source()
    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 23.4 — Assurance Phase A Authority and Trigger Inventory — DONE" in task,
            "Phase A is not DONE")
    require("- [x] Patch 23.5 — Assurance Phase B Deterministic Report-Only Evaluator — DONE" in task,
            "TASK does not mark Phase B done")
    levels = read_json(LEVELS).get("guards", {})
    require(levels.get(GUARD) == 1, "Phase B guard must remain Level 1")
    require(f"{GUARD}:" in JUSTFILE.read_text(encoding="utf-8"), "Phase B guard is not reachable through just")
    require(GUARD in PR_FAST.read_text(encoding="utf-8"), "Phase B guard is not reachable from PR Fast")
    require(not [path.name for path in (ROOT / ".github/workflows").glob("*assurance*")],
            "Phase B must not add an assurance workflow")
    return fixtures


def render(fixtures: list[dict]) -> str:
    rows = [
        "# Phase 23 Semantic Change Assurance — Phase B",
        "",
        "Generated by `scripts/phase23_assurance_phase_b.py`; do not edit by hand.",
        "",
        "- Mode: `report_only`; captured manifests only; no candidate code is executed.",
        "- Qualification rule: exact full candidate SHA, `pull_request` event, complete expected population, matching inventories and artifact digests.",
        "- Any non-`passed` result is not merge or closure authority.",
        "",
        "| Fixture | Subject | Expected classification | Result |",
        "| --- | --- | --- | --- |",
    ]
    for fixture in fixtures:
        rows.append(f"| `{fixture['id']}` | `{fixture['subject']}` | `{fixture['expected_result']}` | `{classify(fixture)}` |")
    rows.extend([
        "", "## Boundary", "",
        "Phase B is a deterministic report over base-controlled, captured manifests. It adds no workflow, required status, repository-rule, publisher, review, or protected-publication authority; it changes no compiler behavior, Gust meaning, MIR/native lowering, ABI/layout/runtime symbols, backend route/fallback, bootstrap seed, Stdlib, or CR-15 authority. Assurance Phases C-E remain inactive.",
        "",
    ])
    return "\n".join(rows)


def check_review(fixtures: list[dict]) -> None:
    require(REVIEW.read_text(encoding="utf-8") == render(fixtures), "generated Phase B review is stale; run render")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "render", "check-review"))
    args = parser.parse_args()
    fixtures = validate()
    if args.command == "render":
        REVIEW.write_text(render(fixtures), encoding="utf-8")
    elif args.command == "check-review":
        check_review(fixtures)
        print("phase23_assurance_phase_b: review current")
    else:
        print("phase23_assurance_phase_b: ok")


if __name__ == "__main__":
    main()
