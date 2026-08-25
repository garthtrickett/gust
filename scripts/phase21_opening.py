#!/usr/bin/env python3
"""Validate and project Patch 21.1 opening evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE21_OPENING.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase21-opening.yml"
JUSTFILE = ROOT / "justfile"
GUARD_L1 = "guard-cranelift-phase21-opening-contract"
GUARD_L2 = "guard-cranelift-phase21-opening-evidence"

TRACK_A_IDS = [
    "scoped_entity_declaration",
    "trusted_scope_provenance",
    "typed_query_root_predicate_and_terminal",
    "predicate_provenance_discharge",
    "scoped_join_root_obligation",
    "nested_query_obligation",
    "query_value_obligation_preservation",
    "cross_tenant_capability_marker",
    "query_site_rejection_diagnostic",
    "general_uses_clause_and_db_read_effect",
    "trusted_request_context_establishment",
    "unsafe_or_raw_SQL",
]

RESIDUE_DESTINATIONS = {
    "collections": "21.9",
    "strings": "21.9",
    "filesystem": "21.10",
    "allocation": "21.10",
    "resources": "21.11",
    "threading_synchronization": "21.11",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase21_opening")
    require(isinstance(record, dict), "Patch 21.1 authority is missing")
    require(record.get("contract_version") == "phase21_opening_evidence_v1",
            "contract version drifted")
    require(record.get("status") == "patch21_1_complete" and
            record.get("next_patch") == "21.2",
            "status or successor drifted")
    require(record.get("observed_main_sha") ==
            "736efd9c794352f855e799139f3a9672ee7ea2e0",
            "opening evidence base drifted")
    require(record.get("roadmap_authority") ==
            registry.get("phase21_roadmap", {}).get("contract_version"),
            "roadmap authority link drifted")

    inventory = record.get("track_a_inventory")
    require(isinstance(inventory, list) and
            [row.get("id") for row in inventory] == TRACK_A_IDS,
            "Track A inventory is missing, duplicated, or reordered")
    for row in inventory:
        require(all(row.get(field) for field in (
            "current_state", "owner", "stable_reason",
            "expected_transition", "falsifier",
        )), f"Track A row is unclassified: {row.get('id')}")
    require(inventory[-2]["current_state"] ==
            inventory[-1]["current_state"] ==
            "excluded_from_typed_query_guarantee",
            "operator-excluded boundaries drifted")
    require(inventory[-3]["expected_transition"] ==
            "future_explicitly_activated_effect_roadmap_not_phase21",
            "general effect syntax was silently folded into Phase 21")

    witnesses = record.get("query_shape_witnesses")
    require(isinstance(witnesses, list) and
            [row.get("id") for row in witnesses] == [
                "trusted_scope_shape", "untrusted_scope_shape"],
            "query-shaped witness population drifted")
    for row in witnesses:
        path = ROOT / row["source_fixture"]
        require(path.is_file(), f"missing witness: {row['source_fixture']}")
        text = path.read_text(encoding="utf-8")
        require(f"witness_kind: {'intended_trusted_scope_positive' if row['id'] == 'trusted_scope_shape' else 'intended_untrusted_scope_negative'}" in text,
                f"witness kind drifted: {row['id']}")
        require("current_surface: compiler_owned_typed_query_syntax_without_scope_enforcement" in text and
                "syntax_authority: patch21_3_contextual_query_and_scoped_entity_surface" in text,
                f"witness was not migrated under Patch 21.3: {row['id']}")
        require(row.get("mir_to_c_exit") == row.get("cranelift_exit") and
                row.get("mir_to_c_exit") in {21, 99},
                f"witness backend baseline drifted: {row['id']}")
        require(all(row.get(field) for field in (
            "intended_future_verdict", "current_semantic_status", "owner",
            "expected_transition", "falsifier",
        )), f"witness is unclassified: {row['id']}")

    residues = record.get("inherited_residues")
    require(isinstance(residues, list) and
            [row.get("category") for row in residues] ==
            list(RESIDUE_DESTINATIONS),
            "six inherited residue categories drifted")
    phase20 = {
        row["category"]: row for row in
        registry["phase20_cross_feature_qualification"]["final_residues"]
    }
    for row in residues:
        prior = phase20.get(row["category"])
        require(prior is not None, f"unknown residue: {row['category']}")
        for current, inherited in (
            ("source_fixture", "source_fixture"),
            ("current_decision", "decision"),
            ("reason_code", "reason_code"),
            ("failure_stage", "failure_stage"),
            ("owner", "owner"),
        ):
            require(row.get(current) == prior.get(inherited),
                    f"{row['category']} changed inherited {current}")
        require(row.get("expected_transition") ==
                RESIDUE_DESTINATIONS[row["category"]] and
                row.get("stable_reason") and row.get("falsifier"),
                f"residue is unclassified: {row['category']}")
        require((ROOT / row["source_fixture"]).is_file(),
                f"residue fixture is missing: {row['source_fixture']}")

    baseline = record.get("full_compiler_baseline")
    require(baseline == {
        "source_fixture": "compiler/test_runner_entry.gst",
        "backend": "explicit_cranelift",
        "compile_exit": 1,
        "decision": "source_or_type_failure",
        "capability": "phase13_generic_source_to_mir",
        "reason_code": "source_or_type_failure",
        "diagnostic_class": "canonical_mir_verification_error",
        "diagnostic": "Native backend canonical MIR verification failed: unsupported top-level statement in module/import cohort",
        "source_line": 238,
        "source_column": 1,
        "failure_stage": "before_driver_discovery",
        "artifact": "absent",
        "owner": "compiler_generic_native_capability_planner",
        "expected_transition": "21.8_through_21.14_classify_and_migrate_the_complete_compiler_dependency_graph",
        "falsifier": "the_full_compiler_reaches_the_native_driver_and_publishes_a_linked_native_compiler_artifact",
    }, "full-compiler baseline drifted")
    source_lines = (ROOT / baseline["source_fixture"]).read_text(
        encoding="utf-8").splitlines()
    require(source_lines[baseline["source_line"] - 1] == "func main() {",
            "full-compiler baseline source location drifted")
    require(record.get("unclassified_failures") == [],
            "Patch 21.1 leaves an unclassified failure")
    boundary = record.get("boundary", {})
    require(boundary and all(value is False for value in boundary.values()),
            "opening evidence widened into implementation")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 21.1 — Opening Evidence and Dual-Track Baseline — DONE" in task,
            "TASK.md does not mark Patch 21.1 DONE")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 21.1 guard levels drifted")
    require(f"{GUARD_L1}:" in JUSTFILE.read_text(encoding="utf-8") and
            f"{GUARD_L2}:" in JUSTFILE.read_text(encoding="utf-8"),
            "Patch 21.1 just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Level 1 opening guard")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow,
            "dedicated workflow does not own both opening guards")
    return record


def render(record: dict) -> str:
    lines = [
        "# Cranelift Phase 21 Opening Evidence",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase21_opening.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Observed main: `{record['observed_main_sha']}`",
        f"- Unclassified failures: `{len(record['unclassified_failures'])}`",
        "",
        "## Track A inventory",
        "",
    ]
    for row in record["track_a_inventory"]:
        lines += [
            f"- `{row['id']}` — `{row['current_state']}`",
            f"  - Owner: `{row['owner']}`",
            f"  - Stable reason: `{row['stable_reason']}`",
            f"  - Expected transition: `{row['expected_transition']}`",
            f"  - Falsifier: `{row['falsifier']}`",
        ]
    lines += ["", "## Executable query-shaped baselines", ""]
    for row in record["query_shape_witnesses"]:
        lines += [
            f"- `{row['id']}` — `{row['current_semantic_status']}`",
            f"  - Fixture: `{row['source_fixture']}`",
            f"  - Current exits: MIR-to-C `{row['mir_to_c_exit']}`, Cranelift `{row['cranelift_exit']}`",
            f"  - Intended verdict: `{row['intended_future_verdict']}`",
            f"  - Expected transition: `{row['expected_transition']}`",
            f"  - Falsifier: `{row['falsifier']}`",
        ]
    lines += ["", "## Inherited Phase 20 residues", ""]
    for row in record["inherited_residues"]:
        lines += [
            f"- `{row['category']}` — `{row['current_decision']}` / `{row['reason_code']}`",
            f"  - Fixture: `{row['source_fixture']}`",
            f"  - Owner: `{row['owner']}`; transition: `{row['expected_transition']}`",
            f"  - Stable reason: `{row['stable_reason']}` at `{row['failure_stage']}`",
            f"  - Falsifier: `{row['falsifier']}`",
        ]
    baseline = record["full_compiler_baseline"]
    lines += [
        "", "## Full compiler explicit-Cranelift baseline", "",
        f"- Source: `{baseline['source_fixture']}:{baseline['source_line']}:{baseline['source_column']}`",
        f"- Exit: `{baseline['compile_exit']}`; artifact: `{baseline['artifact']}`",
        f"- Decision: `{baseline['decision']}` / `{baseline['reason_code']}`",
        f"- Diagnostic class: `{baseline['diagnostic_class']}`",
        f"- Diagnostic: `{baseline['diagnostic']}`",
        f"- Failure stage: `{baseline['failure_stage']}`",
        f"- Owner: `{baseline['owner']}`",
        f"- Expected transition: `{baseline['expected_transition']}`",
        f"- Falsifier: `{baseline['falsifier']}`",
        "",
        "The two query-shaped programs are executable ordinary-language",
        "baselines, not a typed-query syntax decision or an OD-8 pass. Their",
        "purpose is to preserve the currently indistinguishable trusted and",
        "attacker-controlled value flows before Patch 21.3 supplies the no-op",
        "surface and Patch 21.4 enables provenance enforcement.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=(
        "validate", "project", "check-review", "witness-cases",
        "residue-cases", "active-residue-cases",
    ))
    args = parser.parse_args()
    record = validate()
    if args.command == "project":
        REVIEW.write_text(render(record), encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and
                REVIEW.read_text(encoding="utf-8") == render(record),
                "generated opening review is stale; run project")
    elif args.command == "witness-cases":
        for row in record["query_shape_witnesses"]:
            print("\t".join((row["id"], row["source_fixture"],
                              str(row["mir_to_c_exit"]))))
        return
    elif args.command in ("residue-cases", "active-residue-cases"):
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
        phase20 = json.loads(REGISTRY.read_text(encoding="utf-8"))[
            "phase20_cross_feature_qualification"]["final_residues"]
        diagnostics = {row["category"]: row["diagnostic"] for row in phase20}
        migrated: set[str] = set()
        if args.command == "active-residue-cases":
            transition = registry.get(
                "phase21_collection_string_native_source", {})
            if transition.get("status") == "patch21_9_complete":
                migrated = {
                    case["id"].split("_", 1)[0]
                    for case in transition.get("source_cases", [])
                    if case["id"].endswith("_primary")
                }
        for row in record["inherited_residues"]:
            if row["category"] in migrated:
                continue
            print("\t".join((
                row["category"], row["source_fixture"],
                row["current_decision"], row["reason_code"],
                diagnostics[row["category"]], row["failure_stage"],
            )))
        return
    print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
