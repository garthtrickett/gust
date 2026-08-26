#!/usr/bin/env python3
"""Validate and project Patch 19.9 bootstrap seed convergence evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
SEED = ROOT / "gust_v4.c"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE19_SEED_CONVERGENCE.md"
WORKFLOW = ROOT / ".github/workflows/phase19-seed-convergence.yml"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
GUARD = "guard-cranelift-phase19-seed-convergence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def load_record() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase19_seed_convergence")
    require(isinstance(record, dict), "registry record missing")
    return record


def validate() -> dict:
    record = load_record()
    expected = {
        "contract_version": "phase19_seed_convergence_v3",
        "status": "ready_for_patch19_12",
        "next_patch": "19.12",
        "review_view": "compiler/CRANELIFT_PHASE19_SEED_CONVERGENCE.md",
        "seed_path": "gust_v4.c",
        "seed_pull_request": 157,
        "fixed_point_policy": "make_bootstrap_stage2_stage3_byte_identity",
        "pull_request_scope_policy": "seed_owned_changes_only_capability_pr_seed_deferred",
        "main_push_scope_policy": "all_compiler_changes_require_fixed_point",
        "active_deferred_seed_patch": "20.11",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")

    diff = record.get("generated_seed_diff")
    require(isinstance(diff, dict), "generated seed diff is missing")
    expected_diff = {
        "previous_lines": 57351,
        "current_lines": 57360,
        "insertions": 18,
        "deletions": 9,
        "line_delta": 9,
    }
    require(diff == expected_diff, "generated seed diff accounting drifted")
    require(diff["current_lines"] - diff["previous_lines"] == diff["line_delta"],
            "recorded seed line delta is inconsistent")
    require(diff["insertions"] - diff["deletions"] == diff["line_delta"],
            "recorded insertion/deletion delta is inconsistent")

    accounted = record.get("accounted_patches")
    require(isinstance(accounted, list), "accounted patch list is missing")
    require([row.get("patch") for row in accounted] == ["19.11"],
            "seed changes are not accounted to Patch 19.11")
    require(all(set(row) == {"patch", "scope"} and row["scope"] for row in accounted),
            "seed accounting row shape drifted")

    seed = SEED.read_text(encoding="utf-8")
    live_seed_lines = diff["current_lines"]
    successor = json.loads(REGISTRY.read_text(encoding="utf-8")).get(
        "phase20_seed_convergence"
    )
    if successor is not None:
        require(successor.get("predecessor_authority") == record["contract_version"],
                "Phase 20 seed authority does not name this predecessor")
        successor_diff = successor.get("generated_seed_diff")
        require(isinstance(successor_diff, dict),
                "Phase 20 seed authority omits generated diff accounting")
        live_seed_lines = successor_diff.get("current_lines")
        post_prerequisite = json.loads(REGISTRY.read_text(encoding="utf-8")).get(
            "phase20_post_prerequisite_seed_convergence"
        )
        if post_prerequisite is not None:
            require(post_prerequisite.get("predecessor_authority") ==
                    successor.get("contract_version"),
                    "Patch 20.14b seed authority does not name Phase 20 predecessor")
            post_diff = post_prerequisite.get("generated_seed_diff")
            require(isinstance(post_diff, dict),
                    "Patch 20.14b seed authority omits generated diff accounting")
            live_seed_lines = post_diff.get("current_lines")
            protected_access = json.loads(REGISTRY.read_text(encoding="utf-8")).get(
                "phase20_protected_access_seed_convergence"
            )
            if protected_access is not None:
                require(protected_access.get("predecessor_seed_authority") ==
                        post_prerequisite.get("contract_version"),
                        "Patch 20.16e seed authority does not name Patch 20.14b predecessor")
                protected_diff = protected_access.get("generated_seed_diff")
                require(isinstance(protected_diff, dict),
                        "Patch 20.16e seed authority omits generated diff accounting")
                live_seed_lines = protected_diff.get("current_lines")
                phase21_seed = json.loads(REGISTRY.read_text(encoding="utf-8")).get(
                    "phase21_tenant_scope_seed_convergence"
                )
                if phase21_seed is not None:
                    require(phase21_seed.get("predecessor_seed_authority") ==
                            protected_access.get("contract_version"),
                            "Patch 21.7a seed authority does not name Patch 20.16e")
                    phase21_diff = phase21_seed.get("generated_seed_diff")
                    require(isinstance(phase21_diff, dict),
                            "Patch 21.7a seed authority omits generated diff accounting")
                    live_seed_lines = phase21_diff.get("current_lines")
                    native_feature_seed = json.loads(
                        REGISTRY.read_text(encoding="utf-8")
                    ).get("phase21_native_feature_seed_convergence")
                    if native_feature_seed is not None:
                        require(native_feature_seed.get("predecessor_seed_authority") ==
                                phase21_seed.get("contract_version"),
                                "Patch 21.13a seed authority does not name Patch 21.7a")
                        native_feature_diff = native_feature_seed.get("generated_seed_diff")
                        require(isinstance(native_feature_diff, dict),
                                "Patch 21.13a seed authority omits generated diff accounting")
                        live_seed_lines = native_feature_diff.get("current_lines")
    require(len(seed.splitlines()) == live_seed_lines, "committed seed line count drifted")
    for symbol in (
        "typechecker__env_get_canonical_branded_type_name",
        "typechecker__typechecker_is_arena_value_or_ref",
        "struct mir_function_call__MirCallOperand",
        "typechecker__env_pre_register_template_statement",
        "typechecker__typechecker_complete_flattened_template_arguments",
    ):
        require(symbol in seed, f"regenerated seed is missing {symbol}")
    for retired in ("phase19_legacy_brand_spellings", "phase19_spelling_rule"):
        require(retired not in seed, f"regenerated seed retains {retired}")

    workflow = WORKFLOW.read_text(encoding="utf-8")
    pull_request_section, push_section = workflow.split("  push:", 1)
    require("'compiler/*.gst'" not in pull_request_section,
            "compiler source changes must not force seed regeneration into capability PRs")
    require("'compiler/*.gst'" in push_section,
            "main compiler changes do not schedule the seed-drift detector")
    for command in (
        "make bootstrap",
        "cmp build/gust_stage2.c build/gust_stage3.c",
        "git diff --exit-code -- gust_v4.c",
    ):
        require(command in workflow, f"fixed-point workflow is missing {command!r}")
    for token in (
        "fetch-depth: 0",
        "Select authoritative seed-convergence scope",
        'if [ "$EVENT_NAME" != "pull_request" ]',
        'git diff --quiet "$BASE_SHA" "$HEAD_SHA" --',
        "steps.seed_scope.outputs.required == 'true'",
        "Capability PR defers generated seed to its roadmap seed patch",
    ):
        require(token in workflow, f"fixed-point scope selector is missing {token!r}")
    selector = workflow.split("Select authoritative seed-convergence scope", 1)[1]
    selector = selector.split("Capability PR defers generated seed", 1)[0]
    for seed_owned_path in (
        "gust_v4.c",
        "compiler/CRANELIFT_PHASE19_SEED_CONVERGENCE.md",
        "scripts/phase19_seed_convergence.py",
    ):
        require(seed_owned_path in selector,
                f"fixed-point scope selector omits {seed_owned_path}")
    require("compiler/*.gst" not in selector,
            "capability compiler sources must remain deferred on pull requests")
    require("just guard-cranelift-phase19-seed-convergence"
            in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Level 1 seed convergence contract")

    require("- [x] Patch 19.9 — Seed Regeneration and Fixed-Point Convergence — DONE"
            in TASK.read_text(encoding="utf-8"), "TASK.md does not mark Patch 19.9 DONE")
    return record


def render(record: dict) -> str:
    diff = record["generated_seed_diff"]
    lines = [
        "# Cranelift Phase 19 Seed Convergence",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase19_seed_convergence.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Seed: `{record['seed_path']}`",
        f"- Seed-only pull request: `#{record['seed_pull_request']}`",
        f"- Fixed-point policy: `{record['fixed_point_policy']}`",
        f"- Pull-request scope: `{record['pull_request_scope_policy']}`",
        f"- Main-push scope: `{record['main_push_scope_policy']}`",
        f"- Active deferred seed patch: `{record['active_deferred_seed_patch']}`",
        "",
        "## Fixed point",
        "",
        "`make bootstrap` generated byte-identical stage 2 and stage 3 compiler C,",
        "then published stage 3 as the committed seed in the isolated seed-only PR.",
        "The dedicated CI workflow repeats that fixed-point check for seed-owned",
        "pull-request changes and for every compiler change after it reaches main.",
        "Capability PRs leave the generated seed to their roadmap's isolated seed",
        "patch; metadata files cannot accidentally force it into a capability PR.",
        "",
        "## Generated seed diff",
        "",
        f"- Previous lines: {diff['previous_lines']}",
        f"- Current lines: {diff['current_lines']}",
        f"- Insertions: {diff['insertions']}",
        f"- Deletions: {diff['deletions']}",
        f"- Net line delta: {diff['line_delta']}",
        "",
        "Every compiler-source change since the preceding seed belongs to:",
        "",
    ]
    lines += [f"- Patch {row['patch']} — {row['scope']}" for row in record["accounted_patches"]]
    lines += [
        "",
        "No unrelated compiler-source commit is included in this regeneration.",
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
                "generated review view is stale; run phase19_seed_convergence.py project")
    print(f"{GUARD}: ok")


if __name__ == "__main__":
    main()
