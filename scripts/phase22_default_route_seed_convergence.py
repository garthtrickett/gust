#!/usr/bin/env python3
"""Validate and project Patch 22.6a default-route seed convergence."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
SEED = ROOT / "gust_v4.c"
MAKEFILE = ROOT / "Makefile"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE22_DEFAULT_ROUTE_SEED_CONVERGENCE.md"
WORKFLOW = ROOT / ".github/workflows/phase19-seed-convergence.yml"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
JUSTFILE = ROOT / "justfile"
GUARD = "guard-cranelift-phase22-default-route-seed-convergence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def accepted_live_seed_identities(record: dict) -> list[dict]:
    transition = record.get("phase23_successor_transition")
    require(transition == {
        "contract_version": "phase23_diagnostic_seed_reconvergence_transition_v1",
        "status": "ready_for_seed_publication",
        "predecessor_seed_authority": "phase22_default_route_seed_convergence_v1",
        "authority_base_main": "d49cf1835972951b806621b798e7f905aa95df1a",
        "accounted_compiler_authorities": [
            "phase23_structured_guard_defer_native_admission_v1",
            "phase23_same_scope_declaration_v1",
        ],
        "accepted_live_seed_identities": [
            {
                "state": "pre_publication",
                "line_count": 64825,
                "seed_digest": "c2e2cd6d5043af87aacc007d92b105d673bbeea7e8f484a61e18126f39a32383",
            },
            {
                "state": "post_publication",
                "line_count": 64929,
                "seed_digest": "33b23ff4e8dab6c84365920bf3a2a674d7e3f5248646f6ffd69c8f7cc014083a",
            },
        ],
        "generated_seed_diff": {
            "previous_lines": 64825,
            "current_lines": 64929,
            "insertions": 154,
            "deletions": 50,
            "line_delta": 104,
        },
        "seed_pr_policy": "gust_v4_c_only",
        "partial_or_unregistered_identity": "rejected",
        "closure_transition": "collapse_to_post_publication_after_seed_merge",
    }, "Phase 23 seed successor transition drifted")
    identities = transition["accepted_live_seed_identities"]
    require(len({(row["line_count"], row["seed_digest"]) for row in identities}) == 2,
            "Phase 23 seed transition identities are not distinct")
    successor_diff = transition["generated_seed_diff"]
    require(successor_diff["current_lines"] - successor_diff["previous_lines"] ==
            successor_diff["line_delta"] and
            successor_diff["insertions"] - successor_diff["deletions"] ==
            successor_diff["line_delta"],
            "Phase 23 generated seed line delta is inconsistent")
    return identities


def accepted_live_seed_line_counts(record: dict) -> set[int]:
    return {row["line_count"] for row in accepted_live_seed_identities(record)}


def accepted_live_seed_line_count(record: dict, actual_line_count: int) -> int:
    require(actual_line_count in accepted_live_seed_line_counts(record),
            "committed seed line count is outside the exact Phase 23 transition")
    return actual_line_count


def live_seed_identity_is_accepted(record: dict, line_count: int, seed_digest: str) -> bool:
    return any({"line_count": line_count, "seed_digest": seed_digest} == {
        "line_count": row["line_count"], "seed_digest": row["seed_digest"],
    } for row in accepted_live_seed_identities(record))


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    prior_seed = registry.get("phase21_native_feature_seed_convergence", {})
    require(prior_seed.get("contract_version") ==
            "phase21_native_feature_seed_convergence_v1",
            "predecessor seed authority drifted")
    flip = registry.get("phase22_default_route_flip", {})
    require(flip.get("contract_version") == "phase22_default_route_flip_v1" and
            flip.get("status") == "implementation_complete",
            "accounted Patch 22.6 authority drifted")

    record = registry.get("phase22_default_route_seed_convergence")
    require(isinstance(record, dict), "Patch 22.6a authority is missing")
    expected = {
        "contract_version": "phase22_default_route_seed_convergence_v1",
        "status": "patch22_6a_complete",
        "next_patch": "22.7",
        "review_view": "compiler/CRANELIFT_PHASE22_DEFAULT_ROUTE_SEED_CONVERGENCE.md",
        "observed_main_sha": "e521f4f660acf59aff7e07f79a9567c73ffb0b2b",
        "seed_path": "gust_v4.c",
        "predecessor_seed_authority": "phase21_native_feature_seed_convergence_v1",
        "accounted_authority": "phase22_default_route_flip_v1",
        "previous_seed_commit": "ec60ea2b496681b5c60d702d1f1cb46fdab8982c",
        "previous_seed_digest": "58006d413edcf55bf0c89e04a2cd7cadb547c1325000cdb07bc117d45822e9e1",
        "converged_seed_digest": "c2e2cd6d5043af87aacc007d92b105d673bbeea7e8f484a61e18126f39a32383",
        "fixed_point_policy": "make_bootstrap_stage2_stage3_byte_identity",
        "seed_only_policy": "generated_seed_and_seed_specific_authority_only",
        "bootstrap_route": "explicit_mir_to_c",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")

    require(record.get("seed_help_contract") == {
        "default_backend": "cranelift",
        "explicit_c_role": "retained_semantic_oracle",
        "fallback": "forbidden",
    }, "seed help contract drifted")
    handoff_validators = [
        "scripts/phase19_seed_convergence.py",
        "scripts/phase20_seed_convergence.py",
        "scripts/phase20_post_prerequisite_seed_convergence.py",
        "scripts/phase20_protected_access_seed_convergence.py",
        "scripts/phase21_tenant_scope_seed_convergence.py",
        "scripts/phase21_native_feature_seed_convergence.py",
    ]
    require(record.get("successor_handoff_validators") == handoff_validators,
            "historical seed successor-handoff inventory drifted")
    for relative in handoff_validators:
        require("phase22_default_route_seed_convergence" in
                (ROOT / relative).read_text(encoding="utf-8"),
                f"historical seed validator lacks Patch 22.6a handoff: {relative}")
    diff = record.get("generated_seed_diff")
    require(diff == {
        "previous_lines": 62917,
        "current_lines": 64825,
        "insertions": 2094,
        "deletions": 186,
        "line_delta": 1908,
    }, "generated seed diff accounting drifted")
    require(diff["current_lines"] - diff["previous_lines"] == diff["line_delta"] and
            diff["insertions"] - diff["deletions"] == diff["line_delta"],
            "generated seed line delta is inconsistent")
    require(record.get("boundary") == {
        "adds_or_changes_Gust_semantics": False,
        "adds_or_changes_MIR_or_native_lowering": False,
        "changes_ABI_layout_runtime_symbols_target_or_linker": False,
        "changes_default_backend_or_bootstrap_route": False,
        "changes_bootstrap_seed": True,
        "edits_stdlib_or_CR15": False,
        "begins_patch22_7": False,
    }, "Patch 22.6a widened beyond seed reconvergence")

    seed_bytes = SEED.read_bytes()
    seed_text = seed_bytes.decode("utf-8")
    live_seed_identity = {
        "line_count": len(seed_text.splitlines()),
        "seed_digest": hashlib.sha256(seed_bytes).hexdigest(),
    }
    require(live_seed_identity_is_accepted(
        record, live_seed_identity["line_count"], live_seed_identity["seed_digest"]),
            "committed seed is neither exact pre-publication nor post-publication identity")
    for help_fragment in (
        "cranelift  Compile to one native executable (default).",
        "mir-to-c, c  Emit C source to stdout (retained semantic oracle).",
        "fallback to MIR-to-C.",
    ):
        require(help_fragment in seed_text,
                f"regenerated seed lacks help contract fragment: {help_fragment}")
    require("- [x] Patch 22.6a — Default-Route Bootstrap Seed Reconvergence — DONE"
            in TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 22.6a DONE")

    makefile = MAKEFILE.read_text(encoding="utf-8")
    for explicit_seed_command in (
        "./gust_bootstrap --backend mir-to-c compiler/test_runner_bootstrap_bridge_entry.gst",
        "./build/gust_stage1_bin --backend mir-to-c compiler/test_runner_entry.gst",
        "./gust --backend mir-to-c compiler/test_runner_entry.gst",
        "./build/gust_stage2_bin --backend mir-to-c compiler/test_runner_entry.gst",
    ):
        require(explicit_seed_command in makefile,
                f"bootstrap route is not explicit C: {explicit_seed_command}")

    workflow = WORKFLOW.read_text(encoding="utf-8")
    for evidence in (
        "compiler/CRANELIFT_PHASE22_DEFAULT_ROUTE_SEED_CONVERGENCE.md",
        "scripts/phase22_default_route_seed_convergence.py",
        f"just {GUARD}",
    ):
        require(evidence in workflow,
                f"authoritative seed workflow lacks {evidence}")
    for command in (
        "make bootstrap",
        "cmp build/gust_stage2.c build/gust_stage3.c",
        "git diff --exit-code -- gust_v4.c",
    ):
        require(command in workflow,
                f"authoritative fixed-point workflow lacks {command}")
    require(f"just {GUARD}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Patch 22.6a Level 1 guard")
    require(f"{GUARD}:" in JUSTFILE.read_text(encoding="utf-8"),
            "Patch 22.6a just guard is missing")
    return record


def render(record: dict) -> str:
    diff = record["generated_seed_diff"]
    transition = record["phase23_successor_transition"]
    return "\n".join([
        "# Cranelift Phase 22 Default-Route Seed Convergence",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase22_default_route_seed_convergence.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Accounted authority: `{record['accounted_authority']}`",
        f"- Observed main: `{record['observed_main_sha']}`",
        f"- Previous seed commit: `{record['previous_seed_commit']}`",
        f"- Previous seed digest: `{record['previous_seed_digest']}`",
        f"- Converged seed digest: `{record['converged_seed_digest']}`",
        f"- Fixed-point policy: `{record['fixed_point_policy']}`",
        f"- Bootstrap route: `{record['bootstrap_route']}`",
        f"- Seed-only policy: `{record['seed_only_policy']}`",
        "",
        "## Historical validator handoff",
        "",
    ] + [
        f"- `{path}`" for path in record["successor_handoff_validators"]
    ] + [
        "",
        "## Generated seed diff",
        "",
        f"- Previous lines: {diff['previous_lines']}",
        f"- Current lines: {diff['current_lines']}",
        f"- Insertions: {diff['insertions']}",
        f"- Deletions: {diff['deletions']}",
        f"- Net line delta: {diff['line_delta']}",
        "",
        "## Phase 23 successor transition",
        "",
        f"- Contract: `{transition['contract_version']}`",
        f"- Status: `{transition['status']}`",
        f"- Authority base main: `{transition['authority_base_main']}`",
        f"- Accounted compiler authorities: `{', '.join(transition['accounted_compiler_authorities'])}`",
        f"- Seed PR policy: `{transition['seed_pr_policy']}`",
        f"- Partial or unregistered identity: `{transition['partial_or_unregistered_identity']}`",
    ] + [
        f"- Accepted `{row['state']}` identity: {row['line_count']} lines, `{row['seed_digest']}`"
        for row in transition["accepted_live_seed_identities"]
    ] + [
        "",
        "The regenerated seed serializes the final Patch 22.6 compiler sources.",
        "Stage 2 and stage 3 are byte-identical through explicit MIR-to-C. A",
        "compiler rebuilt directly from this seed reports Cranelift as the",
        "default, identifies both explicit C spellings as the retained semantic",
        "oracle, and promises no fallback. This patch adds no Gust semantics,",
        "MIR or native lowering, ABI/layout/runtime symbol, default-route or",
        "bootstrap-route change, Stdlib or CR-15 work, and does not begin 22.7.",
        "",
    ])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review"))
    args = parser.parse_args()
    record = validate()
    if args.command == "project":
        REVIEW.write_text(render(record), encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and REVIEW.read_text(encoding="utf-8") == render(record),
                "generated review is stale; run project")
    print(f"{GUARD}: ok")


if __name__ == "__main__":
    main()
