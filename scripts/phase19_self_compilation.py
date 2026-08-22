#!/usr/bin/env python3
"""Validate and project Patch 19.10 compiler self-compilation evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
TASK = ROOT / "TASK.md"
HISTORICAL = ROOT / ".github/workflows/cranelift-historical-full.yml"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE19_SELF_COMPILATION_DIFFERENTIAL.md"
GUARD = "guard-cranelift-phase19-self-compilation-differential"


EXPECTED_BOUNDARIES = [
    ("19.3", 144, ["phase19: construct canonical branded type names"]),
    ("19.4", 145, [
        "Phase 19.4 derive classification from resolved types",
        "Register synthetic container fixture metadata",
    ]),
    ("19.5", 146, [
        "phase19: add inert call representation fields",
        "phase19: migrate argument representation consumers",
        "phase19: enforce canonical argument representation",
        "fix: preserve reference argument representation",
    ]),
    ("19.6", 147, ["feat: converge self-hosted spelling rules"]),
    ("19.7", 148, []),
    ("19.8", 149, [
        "phase19: remove self-hosted brand name list",
        "fix: resolve ambiguous flattened template brands",
    ]),
]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def load_record() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase19_self_compilation_differential")
    require(isinstance(record, dict), "registry record missing")
    return record


def validate() -> dict:
    record = load_record()
    expected = {
        "contract_version": "phase19_self_compilation_differential_v1",
        "status": "ready_for_patch19_11",
        "next_patch": "19.11",
        "review_view": "compiler/CRANELIFT_PHASE19_SELF_COMPILATION_DIFFERENTIAL.md",
        "baseline_policy": "previous_committed_converged_seed_before_patch19_3",
        "current_policy": "latest_committed_converged_seed_after_patch19_8",
        "level3_owner": "Cranelift Historical Full",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")
    require(record.get("full_diff") == {
        "insertions": 15016,
        "deletions": 14678,
        "unexplained_differences": 0,
    }, "full compiler-C differential accounting drifted")

    boundaries = record.get("patch_boundaries")
    require(isinstance(boundaries, list), "patch boundary inventory missing")
    actual = [
        (row.get("patch"), row.get("pull_request"), row.get("compiler_commit_subjects"))
        for row in boundaries
    ]
    require(actual == EXPECTED_BOUNDARIES, "patch boundary inventory drifted")

    levels = json.loads(LEVELS.read_text(encoding="utf-8")).get("guards", {})
    require(levels.get(GUARD) == 3, "self-compilation differential is not Level 3")
    historical = HISTORICAL.read_text(encoding="utf-8")
    require(historical.count(f"just {GUARD}") == 1,
            "Cranelift Historical Full must invoke the differential exactly once")
    historical_job = historical.split("  historical-full:", 1)[1].split("  phase14-target:", 1)[0]
    require("fetch-depth: 0" in historical_job,
            "Historical Full must fetch the compiler baseline history")
    require("- [x] Patch 19.10 — Generated-C Equivalence Over the Compiler's Own Sources — DONE"
            in TASK.read_text(encoding="utf-8"), "TASK.md does not mark Patch 19.10 DONE")
    return record


def render(record: dict) -> str:
    diff = record["full_diff"]
    lines = [
        "# Cranelift Phase 19 Compiler Self-Compilation Differential",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase19_self_compilation.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Level 3 owner: `{record['level3_owner']}`",
        "",
        "## Complete compiler-source differential",
        "",
        "Historical Full rebuilds the self-hosted compiler at the converged Phase 19.2",
        "baseline and at every Phase 19.3–19.8 merge boundary. Each transition writes",
        "a complete unified C diff named for its owning patch. The guard also rejects",
        "any compiler-source commit whose subject is not assigned to that transition,",
        "requires the baseline build to reproduce its seed, and requires the final",
        "build to reproduce the current converged seed.",
        "",
        f"The complete baseline-to-current C diff contains {diff['insertions']} insertions",
        f"and {diff['deletions']} deletions, with {diff['unexplained_differences']} unexplained differences.",
        "",
        "## Patch attribution",
        "",
    ]
    for row in record["patch_boundaries"]:
        subjects = row["compiler_commit_subjects"]
        detail = "; ".join(f"`{subject}`" for subject in subjects) if subjects else "no compiler-source change"
        lines.append(f"- Patch {row['patch']} / PR #{row['pull_request']} — {detail}")
    lines += [
        "",
        "Patch 19.7 is intentionally the zero-diff transition. Any added, removed, or",
        "reordered compiler-source commit, any missing boundary, any seed mismatch, or",
        "any unlabelled transition makes the Level 3 guard fail.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review"))
    args = parser.parse_args()
    record = validate()
    if args.command == "project":
        REVIEW.write_text(render(record), encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file(), "generated review view missing")
        require(REVIEW.read_text(encoding="utf-8") == render(record),
                "generated review view is stale; run phase19_self_compilation.py project")
    print(f"{GUARD}: ok")


if __name__ == "__main__":
    main()
