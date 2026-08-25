#!/usr/bin/env python3
"""Validate and project Patch 21.7's bounded OD-8 attack verdict."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
VISION = ROOT / "docs/VISION.md"
SHARED = ROOT / "docs/SHARED_SEMANTIC_ZONE.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE21_OD8_ADVERSARIAL_VERDICT.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase21-od8-adversarial-verdict.yml"
JUSTFILE = ROOT / "justfile"
GUARD_L1 = "guard-cranelift-phase21-od8-adversarial-verdict-contract"
GUARD_L2 = "guard-cranelift-phase21-od8-adversarial-verdict-evidence"
ATTACK_IDS = [
    "provenance_authenticity",
    "privileged_boundary_transitivity",
    "joins",
    "nesting",
    "queries_as_values",
    "legitimate_cross_tenant_path",
    "dynamic_shape",
]
OUT_OF_SCOPE_IDS = [
    "unsafe_raw_SQL",
    "result_cache",
    "multi_step_flows",
    "non_query_reads",
    "trusted_context_establishment",
]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    predecessor = registry.get("phase21_cross_tenant_capability", {})
    require(predecessor.get("status") == "patch21_6_complete" and
            predecessor.get("next_patch") == "21.7",
            "Patch 21.6 predecessor authority drifted")
    record = registry.get("phase21_od8_adversarial_verdict")
    require(isinstance(record, dict), "Patch 21.7 authority is missing")
    require(record.get("contract_version") ==
            "phase21_od8_adversarial_verdict_v1",
            "contract version drifted")
    require(record.get("status") == "patch21_7_complete" and
            record.get("next_patch") == "21.7a",
            "status or successor drifted")
    require(record.get("attack_authority") ==
            "docs/VISION.md_section_56_1" and
            record.get("claim_scope") ==
            "compiler_owned_typed_query_path_only",
            "attack authority or claim scope drifted")

    verdict = record.get("verdict", {})
    require(verdict.get("od8_status") ==
            "resolved_2026_08_25_bounded_positive",
            "OD-8 bounded status drifted")
    require(verdict.get("decision") ==
            "complete_predefined_in_scope_suite_found_no_compiling_leak_counterexample",
            "OD-8 evidence decision drifted")
    require(verdict.get("operator_design_date") == "2026-08-24" and
            verdict.get("evidence_date") == "2026-08-25",
            "OD-8 decision or evidence date drifted")
    require(verdict.get("post_merge_reconciliation") ==
            "patch21_7b_added_the_omitted_marked_predicate_boundary_attempt_and_reexecuted_the_complete_suite",
            "OD-8 post-merge reconciliation is missing")
    require(verdict.get("in_scope_counterexamples") == [],
            "positive verdict records an in-scope counterexample")

    attacks = record.get("in_scope_attacks", [])
    require([row.get("id") for row in attacks] == ATTACK_IDS,
            "in-scope attack classes are missing, duplicated, or reordered")
    attempts = []
    for attack in attacks:
        require(attack.get("claim_boundary") and attack.get("outcome"),
                f"attack class is unbounded: {attack.get('id')}")
        rows = attack.get("attempts", [])
        require(rows, f"attack class has no witness: {attack.get('id')}")
        for row in rows:
            require(row.get("kind") and row.get("source_fixture"),
                    f"attack witness is unclassified: {attack.get('id')}")
            require((ROOT / row["source_fixture"]).is_file(),
                    f"missing attack witness: {row['source_fixture']}")
            require(row.get("expected") in {"accept", "reject"},
                    f"unknown expected outcome: {row.get('kind')}")
            if row["expected"] == "accept":
                require(isinstance(row.get("mir_to_c_exit"), int),
                        f"accepted witness lacks MIR-to-C exit: {row['kind']}")
                if "cranelift_exit" in row:
                    require(row["mir_to_c_exit"] == row["cranelift_exit"],
                            f"selected native witness lacks parity: {row['kind']}")
            else:
                require(row.get("diagnostic"),
                        f"rejection witness lacks diagnostic: {row['kind']}")
            attempts.append(row)
    require(len(attempts) == 28,
            "predefined in-scope witness population drifted")
    require(sum(row["expected"] == "accept" for row in attempts) == 5 and
            sum(row["expected"] == "reject" for row in attempts) == 23,
            "accepted/rejected witness split drifted")

    excluded = record.get("out_of_scope_probes", [])
    require([row.get("id") for row in excluded] == OUT_OF_SCOPE_IDS,
            "out-of-scope probe boundary is missing, duplicated, or reordered")
    for row in excluded:
        require(row.get("authority") and
                row.get("outcome", "").endswith("not_counted_as_a_pass"),
                f"out-of-scope probe became a false pass: {row.get('id')}")

    boundary = record.get("boundary", {})
    require(boundary and all(value is False for value in boundary.values()),
            "Patch 21.7 widened beyond an evidence verdict")
    require("- [x] Patch 21.7 — OD-8 Adversarial Soundness Verdict — DONE"
            in TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 21.7 DONE")

    vision = VISION.read_text(encoding="utf-8")
    for evidence in (
        "**RESOLVED 2026-08-25 — BOUNDED POSITIVE**",
        "### 56.2 What the analysis checks — design set, bounded verdict recorded",
        "compiler/CRANELIFT_PHASE21_OD8_ADVERSARIAL_VERDICT.md",
        "does not cover caches, non-query reads, multi-step flows, unsafe/raw SQL",
    ):
        require(evidence in vision,
                f"VISION bounded verdict is missing: {evidence}")
    shared = SHARED.read_text(encoding="utf-8")
    require("OD-8 is `RESOLVED 2026-08-25 / BOUNDED POSITIVE`" in shared and
            "compiler/CRANELIFT_PHASE21_OD8_ADVERSARIAL_VERDICT.md" in shared,
            "shared-zone bounded verdict authority drifted")

    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 21.7 guard levels drifted")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in justfile and f"{GUARD_L2}:" in justfile,
            "Patch 21.7 just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own Patch 21.7 Level 1")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow,
            "dedicated Patch 21.7 workflow does not own both guards")
    return record


def render(record: dict) -> str:
    verdict = record["verdict"]
    lines = [
        "# Cranelift Phase 21 OD-8 Adversarial Soundness Verdict",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase21_od8_adversarial_verdict.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Attack authority: `{record['attack_authority']}`",
        f"- Claim scope: `{record['claim_scope']}`",
        f"- OD-8 status: `{verdict['od8_status']}`",
        f"- Verdict: `{verdict['decision']}`",
        f"- Evidence date: `{verdict['evidence_date']}`",
        f"- Post-merge reconciliation: `{verdict['post_merge_reconciliation']}`",
        f"- In-scope counterexamples: `{len(verdict['in_scope_counterexamples'])}`",
        "",
        "## In-scope attacks",
        "",
    ]
    for attack in record["in_scope_attacks"]:
        lines += [
            f"### `{attack['id']}`",
            "",
            f"- Claim boundary: `{attack['claim_boundary']}`",
            f"- Outcome: `{attack['outcome']}`",
        ]
        for attempt in attack["attempts"]:
            if attempt["expected"] == "accept":
                outcome = f"accepted; MIR-to-C exit `{attempt['mir_to_c_exit']}`"
                if "cranelift_exit" in attempt:
                    outcome += f", Cranelift exit `{attempt['cranelift_exit']}`"
            else:
                outcome = f"rejected with `{attempt['diagnostic']}`"
            lines.append(
                f"- `{attempt['kind']}` — `{attempt['source_fixture']}` — {outcome}"
            )
        lines.append("")

    lines += ["## Explicitly out-of-scope probes", ""]
    for probe in record["out_of_scope_probes"]:
        lines += [
            f"- `{probe['id']}` — `{probe['outcome']}`",
            f"  - Authority: `{probe['authority']}`",
        ]
    lines += [
        "",
        "## Bounded verdict",
        "",
        "The complete predefined in-scope suite produced no compiler-owned",
        "typed-query program that compiled while lacking its required matching",
        "trusted Scope provenance. OD-8 therefore has a bounded positive verdict",
        "for that path only. This is generated conformance evidence, not formal",
        "proof and not a claim about the explicitly excluded probes above.",
        "",
        "Patch 21.7 changes no compiler semantics, MIR, backend behavior, ABI,",
        "layout, runtime symbol, bootstrap seed, database runtime, or Stdlib API.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=(
        "validate", "project", "check-review", "positive-cases",
        "negative-cases",
    ))
    args = parser.parse_args()
    record = validate()
    if args.command == "project":
        REVIEW.write_text(render(record), encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and
                REVIEW.read_text(encoding="utf-8") == render(record),
                "generated Patch 21.7 review is stale; run project")
    elif args.command in {"positive-cases", "negative-cases"}:
        expected = "accept" if args.command == "positive-cases" else "reject"
        for attack in record["in_scope_attacks"]:
            for row in attack["attempts"]:
                if row["expected"] != expected:
                    continue
                values = [attack["id"], row["kind"], row["source_fixture"]]
                if expected == "accept":
                    values += [str(row["mir_to_c_exit"]),
                               str(row.get("cranelift_exit", "-"))]
                else:
                    values.append(row["diagnostic"])
                print("\t".join(values))
        return
    print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
