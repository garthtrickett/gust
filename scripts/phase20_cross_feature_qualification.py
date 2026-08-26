#!/usr/bin/env python3
"""Validate and project Patch 20.16 cross-feature qualification."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_CROSS_FEATURE_QUALIFICATION.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
HISTORICAL = ROOT / ".github/workflows/cranelift-historical-full.yml"
JUSTFILE = ROOT / "justfile"
GUARD_L1 = "guard-cranelift-phase20-cross-feature-qualification-contract"
GUARD_L2 = "guard-cranelift-phase20-cross-feature-qualification-parity"
GUARD_L3 = "guard-cranelift-phase20-cross-feature-qualification-full"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase20_cross_feature_qualification")
    require(isinstance(record, dict), "Patch 20.16 authority is missing")
    expected = {
        "contract_version": "phase20_cross_feature_qualification_v1",
        "status": "phase20_ready_for_authoritative_historical_full",
        "next_patch": "20.17",
        "review_view": "compiler/CRANELIFT_PHASE20_CROSS_FEATURE_QUALIFICATION.md",
        "harness": "scripts/phase20_cross_feature_qualification.sh",
        "source_fixture": "compiler/phase20_cross_feature_qualification_source.gst",
        "resource_module_fixture": "compiler/phase20_cross_feature_resource_module.gst",
        "runtime_probe_fixture": "compiler/fixtures/phase20_cross_feature_probe.c",
        "canonical_mir_fixture": "compiler/fixtures/native_backend_phase20_cross_feature_qualification.mir",
        "selected_features": [
            "brand_identity", "arena_liveness", "user_resources", "modules",
            "approved_runtime_import", "bounded_scale",
            "long_lived_concurrency",
        ],
        "expected_exit": 47,
        "expected_events": [57, 2, 1],
        "normalization_policy": "none",
        "backend_policy": "MIR_to_C_executes_the_mixed_source_oracle_and_direct_canonical_MIR_Cranelift_executes_the_same_observable_plan_against_the_same_runtime_and_test_probes",
        "fallback_policy": "direct_mixed_source_Cranelift_is_poisoned_and_must_reject_before_driver_discovery_without_an_artifact",
        "unexplained_divergences": [],
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")
    require(record.get("profiles") == [
        {"id": "small", "level": 2, "concurrent_cycles": 8},
        {"id": "full", "level": 3, "concurrent_cycles": 128},
    ], "Patch 20.16 profiles drifted")

    entries = registry.get("entries")
    require(isinstance(entries, list), "canonical registry entries are missing")
    ids = [row.get("id") for row in entries]
    status_counts = Counter(row.get("status") for row in entries)
    audit = {
        "entry_count": len(entries),
        "migrated": status_counts["migrated"],
        "candidate_deferred": status_counts["candidate_deferred"],
        "replaced": status_counts["replaced"],
        "deferred": status_counts["deferred"],
        "duplicate_ids": len(ids) - len(set(ids)),
        "unowned_rows": sum(
            not row.get("route_owner") or
            not row.get("worker_capability_owner") or
            not row.get("diagnostic_owner")
            for row in entries
        ),
    }
    require(record.get("registry_audit") == audit,
            f"canonical registry audit drifted: {audit}")

    residues = record.get("final_residues")
    require(isinstance(residues, list) and len(residues) == 6,
            "Patch 20.16 must retain exactly six deduplicated residues")
    require(len({row.get("category") for row in residues}) == 6,
            "Patch 20.16 residue categories are duplicated")
    inherited = registry["phase20_stdlib_runtime_differential"][
        "explicit_exclusions"]
    inherited_by_category = {row["category"]: row for row in inherited}
    require(set(inherited_by_category) == {
        "collections", "strings", "filesystem", "allocation", "resources",
        "threading_synchronization",
    }, "Patch 20.13 residue categories drifted")
    for row in residues:
        prior = inherited_by_category.get(row.get("category"))
        require(prior is not None, f"unknown residue: {row.get('category')}")
        for key in ("source_fixture", "decision", "reason_code", "owner"):
            require(row.get(key) == prior.get(key),
                    f"{row['category']} changed inherited {key}")
        require(row.get("failure_stage") == "before_driver_discovery" and
                row.get("diagnostic") and
                row.get("destination") == "phase21_opening" and
                row.get("falsifier"),
                f"{row['category']} lacks bounded residue authority")
        require((ROOT / row["source_fixture"]).is_file(),
                f"missing residue fixture: {row['source_fixture']}")

    migrated_categories = []
    for successor_id, completed_status, predecessor_id in (
        ("phase21_collection_string_native_source", "patch21_9_complete",
         "phase21_residue_migration_authority"),
        ("phase21_filesystem_allocation_native_source", "patch21_10_complete",
         "phase21_collection_string_native_source"),
    ):
        successor = registry.get(successor_id, {})
        if successor.get("status") == completed_status:
            require(successor.get("predecessor_authority") ==
                    registry[predecessor_id]["contract_version"],
                    f"{completed_status} successor authority is not linked to "
                    f"{predecessor_id}")
            migrated_categories.extend(
                case["id"].split("_", 1)[0]
                for case in successor.get("source_cases", [])
                if case["id"].endswith("_primary")
            )

    refinements = registry["phase20_long_lived_concurrent"][
        "explicit_exclusions"]
    require({row["reason_code"] for row in refinements} == {
        inherited_by_category["resources"]["reason_code"],
        inherited_by_category["threading_synchronization"]["reason_code"],
    }, "Patch 20.15 resource/threading refinements do not deduplicate")

    for key in ("source_fixture", "resource_module_fixture",
                "runtime_probe_fixture", "canonical_mir_fixture"):
        require((ROOT / record[key]).is_file(), f"missing {key}")
    require("- [x] Patch 20.16 — Cross-Feature Qualification and Residue "
            "Audit — DONE" in TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 20.16 DONE")

    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2 and
            levels.get(GUARD_L3) == 3,
            "Patch 20.16 guard levels drifted")
    pr_fast = PR_FAST.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in pr_fast and f"just {GUARD_L2}" in pr_fast and
            f"just {GUARD_L3}" not in pr_fast,
            "PR Fast Patch 20.16 ownership drifted")
    historical = HISTORICAL.read_text(encoding="utf-8")
    require(f"phase20) just {GUARD_L3} ;;" in historical,
            "Historical Full does not own the Patch 20.16 composition guard")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(all(f"{guard}:" in justfile for guard in
                (GUARD_L1, GUARD_L2, GUARD_L3)),
            "Patch 20.16 just guards are missing")
    full_recipe = justfile.split(f"{GUARD_L3}:", 1)[1].split("\n\n", 1)[0]
    require("guard-cranelift-phase20-generated-mir-scale-full" in full_recipe and
            "guard-cranelift-phase20-long-lived-concurrent-full" in full_recipe,
            "Patch 20.16 Level 3 does not compose both existing full owners")
    projected = dict(record)
    projected["active_final_residues"] = [
        row for row in residues
        if row["category"] not in migrated_categories
    ]
    projected["completed_successor_migrations"] = migrated_categories
    return projected


def render(record: dict) -> str:
    audit = record["registry_audit"]
    lines = [
        "# Cranelift Phase 20 Cross-Feature Qualification",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_cross_feature_qualification.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Normalization: `{record['normalization_policy']}`",
        f"- Unexplained divergences: `{len(record['unexplained_divergences'])}`",
        "",
        "## Mixed selected cohort",
        "",
        f"- Features: `{','.join(record['selected_features'])}`",
        f"- Source oracle: `{record['source_fixture']}`",
        f"- Canonical MIR: `{record['canonical_mir_fixture']}`",
        f"- Expected exit: `{record['expected_exit']}`",
        f"- Resource events: `{','.join(map(str, record['expected_events']))}`",
        f"- Backend policy: {record['backend_policy']}",
        f"- Fallback policy: {record['fallback_policy']}",
        "",
        "## Canonical registry audit",
        "",
        f"- Entries: `{audit['entry_count']}`",
        f"- Migrated: `{audit['migrated']}`",
        f"- Candidate deferred: `{audit['candidate_deferred']}`",
        f"- Replaced: `{audit['replaced']}`",
        f"- Deferred: `{audit['deferred']}`",
        f"- Duplicate IDs: `{audit['duplicate_ids']}`",
        f"- Unowned rows: `{audit['unowned_rows']}`",
        "",
        "## Final deduplicated residues",
        "",
    ]
    for row in record["final_residues"]:
        lines += [
            f"- `{row['category']}` — `{row['decision']}` / `{row['reason_code']}`",
            f"  - Fixture: `{row['source_fixture']}`",
            f"  - Diagnostic: `{row['diagnostic']}` at `{row['failure_stage']}`",
            f"  - Owner: `{row['owner']}`; destination: `{row['destination']}`",
            f"  - Falsifier: {row['falsifier']}",
        ]
    lines += [
        "",
        "## Successor transitions",
        "",
        "The six residues above remain the frozen Patch 20.16 snapshot.",
        "Completed successor migrations are no longer re-probed as residues",
        "by this historical guard.",
        "Completed successor-owned categories: `" +
        ",".join(record["completed_successor_migrations"]) + "`.",
        "",
        "The resource and threading rows subsume Patch 20.15's narrower direct",
        "source exclusions; they are not additional residue categories. The",
        "authoritative Historical Full result remains a Patch 20.17 closure gate.",
        "",
    ]
    return "\n".join(lines)


def residue_cases(record: dict) -> str:
    return "\n".join("\t".join([
        row["category"], row["source_fixture"], row["decision"],
        row["reason_code"], row["diagnostic"], row["failure_stage"],
        row["owner"], row["destination"],
    ]) for row in record["active_final_residues"])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=(
        "validate", "project", "check-review", "residue-cases",
    ))
    args = parser.parse_args()
    record = validate()
    if args.command == "project":
        REVIEW.write_text(render(record), encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and
                REVIEW.read_text(encoding="utf-8") == render(record),
                "generated review is stale; run project")
    elif args.command == "residue-cases":
        print(residue_cases(record))
        return
    print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
