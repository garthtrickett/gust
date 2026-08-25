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
    "21.7a", "21.8", "21.9", "21.10", "21.11", "21.12", "21.13",
    "21.13a", "21.14", "21.15", "21.16", "21.17", "21.18",
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
    lines += [
        "",
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

    task = TASK.read_text(encoding="utf-8")
    require(task.startswith(
        "# Phase 21 — Tenant-Scoped Typed Queries and Cranelift Self-Hosting Qualification"),
        "TASK.md does not open Phase 21")
    status = task.split("## Status", 1)[1].split("## Immutable Contracts", 1)[0]
    rows = re.findall(r"^- \[([ x])\] Patch (21\.\d+[a-z]?) — .+$",
                      status, re.MULTILINE)
    require([patch for _, patch in rows] == EXPECTED_PATCHES,
            "Phase 21 status rows are missing, duplicated, or reordered")
    marks = [mark for mark, _ in rows]
    require(marks[0] == "x", "Patch 21.0 must remain DONE")
    if " " in marks:
        require("x" not in marks[marks.index(" "):],
                "Phase 21 DONE rows must form one contiguous prefix")
    require("On 2026-08-24 the operator conditionally authorized Phase 21" in task and
            "That condition is satisfied" in task,
            "TASK.md does not record operator activation")
    for patch in EXPECTED_PATCHES:
        require(f"## Patch {patch} —" in task,
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
    require("| OD-15 | **Native self-host reproducibility criterion**" in vision and
            "**OPEN** — registered 2026-08-24" in vision,
            "OD-15 is not registered as open")

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
