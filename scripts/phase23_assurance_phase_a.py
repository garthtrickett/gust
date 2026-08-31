#!/usr/bin/env python3
"""Validate and render the report-only Phase 23 assurance authority."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
SCHEMA = ROOT / "scripts/phase23_assurance_envelope.schema.json"
ENVELOPES = ROOT / "scripts/phase23_assurance_envelopes.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE23_ASSURANCE_PHASE_A.md"
TASK = ROOT / "TASK.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
GUARD = "guard-cranelift-phase23-assurance-phase-a-contract"
LOSS_TAXONOMY = [
    "passed", "failed", "unsupported", "skipped_with_reason", "not_applicable",
    "not_executed", "empty_selection", "fallback_used", "malformed_evidence",
    "stale_evidence", "unresolved",
]
IDENTITY_FIELDS = {"repository", "observed_main_sha", "base_sha", "observed_at_utc"}
REFERENCE_KINDS = {
    "operator_authority", "inherited_contract", "assumption", "parked_scope",
    "candidate_evidence", "closure_evidence",
}
EXPECTED_AUTHORITY = {
    "contract_version": "phase23_assurance_phase_a_v1",
    "status": "phase23_4_complete_report_only",
    "owner": "cranelift",
    "schema": "scripts/phase23_assurance_envelope.schema.json",
    "envelopes": "scripts/phase23_assurance_envelopes.json",
    "review_view": "compiler/CRANELIFT_PHASE23_ASSURANCE_PHASE_A.md",
    "renderer": "scripts/phase23_assurance_phase_a.py",
    "guard": GUARD,
    "historical_inputs": [110, 240],
    "selected_current_pilot": 105,
    "authorization": "phase_A_and_phase_B_report_only",
    "forbidden": [
        "assurance_phases_C_D_or_E", "independent_model_review",
        "protected_publication", "repository_rule_changes",
        "new_required_status_check", "new_workflow",
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
        "begins_patch23_5": False,
    },
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def read_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{GUARD}: invalid JSON in {path.relative_to(ROOT)}: {exc}") from exc
    require(isinstance(value, dict), f"{path.relative_to(ROOT)} must contain an object")
    return value


def repository_is_shallow() -> bool:
    result = subprocess.run(
        ["git", "rev-parse", "--is-shallow-repository"], cwd=ROOT,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=False,
    )
    require(result.returncode == 0, "cannot determine repository shallow state")
    state = result.stdout.strip()
    require(state in {"true", "false"}, "repository shallow state is malformed")
    return state == "true"


def require_identity(value: object, label: str) -> None:
    require(isinstance(value, dict) and set(value) == IDENTITY_FIELDS,
            f"{label} identity field set drifted")
    require(value["repository"] == "garthtrickett/gust", f"{label} repository drifted")
    shallow = repository_is_shallow()
    for key in ("observed_main_sha", "base_sha"):
        sha = value[key]
        require(isinstance(sha, str) and len(sha) == 40 and
                all(char in "0123456789abcdef" for char in sha),
                f"{label} {key} must be a full lowercase SHA")
        if not shallow:
            exists = subprocess.run(
                ["git", "cat-file", "-e", f"{sha}^{{commit}}"], cwd=ROOT,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
            )
            require(exists.returncode == 0, f"{label} {key} is not a known commit")
    observed_at = value["observed_at_utc"]
    require(isinstance(observed_at, str) and observed_at.endswith("Z") and len(observed_at) == 20,
            f"{label} observation timestamp drifted")


def authority() -> dict:
    value = read_json(REGISTRY).get("phase23_assurance_phase_a")
    require(isinstance(value, dict), "registry Phase A authority is missing")
    require(value == EXPECTED_AUTHORITY, "registry Phase A authority drifted")
    return value


def validate_schema() -> None:
    schema = read_json(SCHEMA)
    require(schema.get("$schema") == "https://json-schema.org/draft/2020-12/schema",
            "envelope schema draft drifted")
    require(schema.get("$id") == "scripts/phase23_assurance_envelope.schema.json",
            "envelope schema identity drifted")
    require(schema.get("additionalProperties") is False,
            "envelope schema must reject unknown top-level fields")
    require(set(schema.get("required", [])) == {
        "schema_version", "phase", "source_identity", "loss_taxonomy",
        "repository_facts", "envelopes",
    }, "envelope schema top-level contract drifted")
    envelope = schema.get("$defs", {}).get("envelope", {})
    require(envelope.get("additionalProperties") is False,
            "per-issue envelopes must reject unknown fields")


def validate_envelope_row(row: object, expected_issue: int, expected_state: str,
                          expected_risk: str) -> None:
    required = {
        "id", "issue", "state", "risk_class", "source_identity",
        "authority_references", "expected_inventory", "observed_loss_states",
        "candidate_evidence", "closure_evidence", "assumptions", "non_goals",
        "parked_scope",
    }
    require(isinstance(row, dict) and set(row) == required,
            f"issue #{expected_issue} envelope field set drifted")
    require(row["issue"] == expected_issue and row["state"] == expected_state and
            row["risk_class"] == expected_risk,
            f"issue #{expected_issue} state or risk classification drifted")
    require_identity(row["source_identity"], f"issue #{expected_issue}")
    references = row["authority_references"]
    require(isinstance(references, list) and len(references) >= 6,
            f"issue #{expected_issue} authority reference inventory is incomplete")
    kinds = set()
    for reference in references:
        require(isinstance(reference, dict) and set(reference) == {"kind", "path", "role"},
                f"issue #{expected_issue} authority reference is malformed")
        require(reference["kind"] in REFERENCE_KINDS,
                f"issue #{expected_issue} authority classification is unknown")
        require(reference["path"] and reference["role"],
                f"issue #{expected_issue} authority reference is empty")
        kinds.add(reference["kind"])
    require({"operator_authority", "inherited_contract", "candidate_evidence", "closure_evidence"} <= kinds,
            f"issue #{expected_issue} does not distinguish authority from evidence")
    inventory = row["expected_inventory"]
    require(isinstance(inventory, list) and inventory,
            f"issue #{expected_issue} expected inventory is empty")
    for item in inventory:
        require(isinstance(item, dict) and set(item) == {"id", "required_state", "authority"} and
                all(isinstance(item[key], str) and item[key] for key in item),
                f"issue #{expected_issue} expected inventory item is malformed")
    losses = row["observed_loss_states"]
    require(isinstance(losses, list) and losses and set(losses) <= set(LOSS_TAXONOMY),
            f"issue #{expected_issue} loss state drifted")
    for key in ("candidate_evidence", "closure_evidence", "assumptions", "non_goals", "parked_scope"):
        require(isinstance(row[key], list) and all(isinstance(value, str) and value for value in row[key]),
                f"issue #{expected_issue} {key} must be a string list")


def validate() -> dict:
    value = authority()
    validate_schema()
    data = read_json(ENVELOPES)
    require(set(data) == {"schema_version", "phase", "source_identity", "loss_taxonomy", "repository_facts", "envelopes"},
            "envelope source field set drifted")
    require(data["schema_version"] == "phase23_assurance_envelope_v1" and data["phase"] == "23",
            "envelope version or phase drifted")
    require_identity(data["source_identity"], "Phase A source")
    require(data["loss_taxonomy"] == LOSS_TAXONOMY, "common loss taxonomy drifted")
    facts = data["repository_facts"]
    require(isinstance(facts, dict) and set(facts) == {
        "ruleset", "workflow_file_count", "pull_request_trigger_count",
        "push_trigger_count", "workflow_dispatch_trigger_count", "qualification_rule",
    }, "repository facts field set drifted")
    require(facts["ruleset"] == {
        "id": 20214069, "name": "Protect main", "enforcement": "active",
        "required_status_checks": ["Codex / Trusted actor"],
        "required_approving_review_count": 0,
        "required_review_thread_resolution": True,
    }, "captured main ruleset facts drifted")
    require((facts["workflow_file_count"], facts["pull_request_trigger_count"],
             facts["push_trigger_count"], facts["workflow_dispatch_trigger_count"]) == (124, 121, 122, 106),
            "captured workflow facts drifted")
    require(facts["qualification_rule"] ==
            "exact_full_candidate_head_sha_and_event_pull_request_with_all_review_threads_resolved",
            "exact-SHA qualification rule drifted")
    rows = data["envelopes"]
    require(isinstance(rows, list) and len(rows) == 3,
            "Phase A must contain exactly the two historical inputs and one pilot")
    expected = [(110, "historical_closed_input", "R2"),
                (240, "historical_closed_input", "R2"),
                (105, "planned_R1_pilot", "R1")]
    for row, (issue, state, risk) in zip(rows, expected):
        validate_envelope_row(row, issue, state, risk)
    require(rows[0]["observed_loss_states"] == ["stale_evidence"],
            "#110 stale-evidence classification drifted")
    require(rows[1]["observed_loss_states"] == ["stale_evidence"],
            "#240 stale-evidence classification drifted")
    require(rows[2]["observed_loss_states"] == ["not_executed", "unresolved"],
            "#105 planned-pilot classification drifted")
    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 23.2 — MIR Evidence-Owner Repair and Retirement (#110) — DONE" in task,
            "#110 closure status is absent from TASK")
    require("- [x] Patch 23.3 — Resource-Acquisition Parity Evidence Repair (#240) — DONE" in task,
            "#240 closure status is absent from TASK")
    require("- [x] Patch 23.4 — Assurance Phase A Authority and Trigger Inventory — DONE" in task,
            "TASK does not mark Phase A done")
    levels = read_json(LEVELS).get("guards", {})
    require(levels.get(GUARD) == 1, "Phase A guard must remain Level 1")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD}:" in just, "Phase A guard is not reachable through just")
    require(GUARD in PR_FAST.read_text(encoding="utf-8"), "Phase A guard is not reachable from PR Fast")
    workflow_names = [path.name for path in (ROOT / ".github/workflows").glob("*assurance*")]
    require(not workflow_names, "Phase A must not add an assurance workflow")
    return data


def render(data: dict) -> str:
    facts = data["repository_facts"]
    lines = [
        "# Phase 23 Semantic Change Assurance — Phase A",
        "",
        "Generated by `scripts/phase23_assurance_phase_a.py`; do not edit by hand.",
        "",
        "- Envelope schema: `phase23_assurance_envelope_v1`",
        f"- Source main/base: `{data['source_identity']['observed_main_sha']}`",
        f"- Observed: `{data['source_identity']['observed_at_utc']}`",
        "- Mode: `report_only`; this document is not merge or closure authority.",
        "",
        "## Qualification facts",
        "",
        f"- Main ruleset: `{facts['ruleset']['name']}` (`{facts['ruleset']['enforcement']}`), required status `{facts['ruleset']['required_status_checks'][0]}`, resolved review threads, and `{facts['ruleset']['required_approving_review_count']}` approving reviews.",
        f"- Captured workflows: `{facts['workflow_file_count']}` files; `pull_request` `{facts['pull_request_trigger_count']}`, `push` `{facts['push_trigger_count']}`, and `workflow_dispatch` `{facts['workflow_dispatch_trigger_count']}` triggers.",
        "- Candidate qualification: exact full candidate SHA, `pull_request` event, complete expected population, and resolved review threads.",
        "- Common loss taxonomy: " + ", ".join(f"`{item}`" for item in data["loss_taxonomy"]) + ".",
        "",
        "## Envelope inventory",
        "",
        "| Issue | State / risk | Current loss states | Candidate evidence | Closure evidence |",
        "| --- | --- | --- | --- | --- |",
    ]
    for row in data["envelopes"]:
        lines.append(
            f"| #{row['issue']} | `{row['state']}` / `{row['risk_class']}` | "
            f"`{', '.join(row['observed_loss_states'])}` | {row['candidate_evidence'][0]} | {row['closure_evidence'][0]} |"
        )
    for row in data["envelopes"]:
        lines.extend(["", f"## Issue #{row['issue']} — `{row['id']}`", "",
                      f"- Source/base: `{row['source_identity']['observed_main_sha']}` / `{row['source_identity']['base_sha']}`.",
                      "- Expected inventory:"])
        for item in row["expected_inventory"]:
            lines.append(f"  - `{item['id']}` → `{item['required_state']}` ({item['authority']}).")
        lines.append("- Authority classification:")
        for reference in row["authority_references"]:
            lines.append(f"  - `{reference['kind']}`: `{reference['path']}` — {reference['role']}.")
        lines.append("- Assumptions: " + ("none" if not row["assumptions"] else "; ".join(row["assumptions"])) + ".")
        lines.append("- Non-goals: " + "; ".join(row["non_goals"]) + ".")
        lines.append("- Parked scope: " + "; ".join(row["parked_scope"]) + ".")
    lines.extend([
        "", "## Phase A boundary", "",
        "Phase A records provenance and expected evidence only. It adds no workflow, required status, reviewer role, publisher, or repository-rule change; it changes no compiler behavior, Gust meaning, MIR, native lowering, ABI/layout/runtime symbol, backend route/fallback, bootstrap seed, Stdlib, or CR-15 authority.",
        "", "Phase B alone may evaluate captured deterministic manifests. Assurance Phases C-E, independent model review, and protected publication remain inactive.",
        "",
    ])
    return "\n".join(lines)


def check_review(data: dict) -> None:
    require(REVIEW.read_text(encoding="utf-8") == render(data),
            "generated Phase A review is stale; run render")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "render", "check-review"))
    args = parser.parse_args()
    data = validate()
    if args.command == "render":
        REVIEW.write_text(render(data), encoding="utf-8")
    elif args.command == "check-review":
        check_review(data)
        print("phase23_assurance_phase_a: review current")
    else:
        print("phase23_assurance_phase_a: ok")


if __name__ == "__main__":
    main()
