#!/usr/bin/env python3
"""Validate, project, and run Patch 23.13 cross-feature qualification."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import signal
import subprocess
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
ISSUES = ROOT / "docs/ISSUE_ROADMAP.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE23_CROSS_FEATURE_QUALIFICATION.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase23-cross-feature-qualification.yml"
GUARD_L1 = "guard-cranelift-phase23-cross-feature-qualification-contract"
GUARD_L2 = "guard-cranelift-phase23-cross-feature-qualification-evidence"

PHASE23_L1_GUARDS = [
    "guard-cranelift-phase23-issue-health-opening-contract",
    "guard-cranelift-phase23-mir-evidence-owner-contract",
    "guard-cranelift-phase23-resource-acquisition-parity-contract",
    "guard-cranelift-phase23-structured-guard-defer-native-admission-contract",
    "guard-cranelift-phase23-assurance-phase-a-contract",
    "guard-cranelift-phase23-assurance-phase-b-contract",
    "guard-cranelift-phase23-same-scope-declaration-contract",
    "guard-cranelift-phase23-mir-to-c-deprecation-opening-contract",
    "guard-cranelift-phase23-mir-to-c-frozen-surface-contract",
    "guard-cranelift-phase23-mir-to-c-focused-live-contract",
    "guard-cranelift-phase23-mir-to-c-archived-corpus-contract",
    "guard-cranelift-phase23-production-release-audit-contract",
]

PHASE23_L2_GUARDS = [
    "guard-cranelift-phase23-issue-health-opening-evidence",
    "guard-cranelift-phase23-structured-guard-defer-native-admission-evidence",
    "guard-cranelift-phase23-same-scope-declaration-evidence",
    "guard-cranelift-phase23-mir-to-c-deprecation-opening-evidence",
    "guard-cranelift-phase23-mir-to-c-frozen-surface-evidence",
    "guard-cranelift-phase23-mir-to-c-focused-live-evidence",
    "guard-cranelift-phase23-mir-to-c-archived-corpus-evidence",
    "guard-cranelift-phase23-production-release-audit-evidence",
]

SUPPLEMENTAL_L2_GUARDS = [
    "guard-cranelift-phase18-target-authority-parity",
    "guard-cranelift-phase18-target-support-parity",
    "guard-cranelift-phase18-target-diagnostic-parity",
    "guard-cranelift-phase20-resource-scope-cleanup-parity",
    "guard-cranelift-phase22-postflip-qualification-evidence",
]

STATIC_COMMANDS = [
    ["python3", "scripts/cranelift_registry.py", "validate"],
    ["python3", "scripts/cranelift_registry.py", "check-projection"],
    ["python3", "scripts/cranelift_test_levels.py", "validate"],
    ["python3", "scripts/cranelift_ci_family.py", "validate"],
    ["python3", "scripts/guard_reachability.py"],
    ["python3", "scripts/fixture_reachability.py"],
]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    require(spec is not None and spec.loader is not None,
            f"cannot load {path.relative_to(ROOT)}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def phase23_guard_inventory(levels: dict[str, int], level: int) -> list[str]:
    return [guard for guard, assigned in levels.items()
            if guard.startswith("guard-cranelift-phase23-")
            and guard not in {GUARD_L1, GUARD_L2}
            and assigned == level]


def current_consumer_inventory() -> dict[str, object]:
    module = load_module(
        "phase23_deprecation_opening",
        ROOT / "scripts/phase23_mir_to_c_deprecation_opening.py",
    )
    return module.inventory_summary()


def current_frozen_surface(registry: dict) -> dict[str, object]:
    module = load_module(
        "phase23_frozen_surface",
        ROOT / "scripts/phase23_mir_to_c_frozen_surface.py",
    )
    return module.scan(registry)["live_c_case_surface"]


def validate_transition(record: dict, registry: dict) -> None:
    opening = registry["phase23_mir_to_c_deprecation_opening"][
        "deprecation_contract"]["production_release_inventory_transition"]
    transition = record.get("consumer_inventory_transition", {})
    require(transition.get("contract_version") ==
            "phase23_cross_feature_consumer_inventory_transition_v1" and
            transition.get("status") == "patch23_13_complete" and
            transition.get("authority_base_main") ==
            "9b89296b25d2ab0cf1963ea1d1707139149d0576" and
            transition.get("previous_inventory") == opening["current_inventory"] and
            transition.get("current_inventory") == current_consumer_inventory() and
            transition.get("unchanged_fields") == [
                "invocation_count", "invocation_manifest_digest",
                "structural_surface_count", "structural_manifest_digest",
                "classification_counts", "invocation_selection_counts",
                "unclassified_count",
            ] and transition.get("partial_or_unregistered_inventory") == "rejected",
            "Patch 23.13 consumer inventory transition drifted")
    for field in transition["unchanged_fields"]:
        require(transition["current_inventory"].get(field) ==
                transition["previous_inventory"].get(field),
                f"Patch 23.13 changed consumer inventory field: {field}")

    frozen = registry["phase23_mir_to_c_frozen_surface"][
        "production_release_transition"]
    surface = record.get("frozen_surface_transition", {})
    require(surface.get("contract_version") ==
            "phase23_cross_feature_frozen_surface_transition_v1" and
            surface.get("status") == "patch23_13_complete" and
            surface.get("authority_base_main") ==
            "9b89296b25d2ab0cf1963ea1d1707139149d0576" and
            surface.get("previous_live_c_case_surface") ==
            frozen["current_live_c_case_surface"] and
            surface.get("current_live_c_case_surface") ==
            current_frozen_surface(registry) and
            surface.get("unchanged_fields") == [
                "count", "case_id_manifest_digest", "owner_contract_count",
                "owner_counts", "consumer_class_counts", "selection_counts",
            ] and surface.get("partial_or_unregistered_surface") == "rejected",
            "Patch 23.13 frozen surface transition drifted")
    for field in surface["unchanged_fields"]:
        require(surface["current_live_c_case_surface"].get(field) ==
                surface["previous_live_c_case_surface"].get(field),
                f"Patch 23.13 changed frozen C field: {field}")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase23_cross_feature_qualification")
    require(isinstance(record, dict), "Patch 23.13 authority is missing")
    expected = {
        "contract_version": "phase23_cross_feature_qualification_v1",
        "status": "patch23_13_complete",
        "next_patch": "23.14",
        "owner": "cranelift",
        "review_view": REVIEW.relative_to(ROOT).as_posix(),
        "renderer": Path(__file__).relative_to(ROOT).as_posix(),
        "unexplained_differences": [],
        "module_or_fixture_exceptions": [],
        "unclassified_residues": [],
        "execution_model": {
            "prebuild": "make_phase10_native_package_once",
            "guard_runner_build_policy": "GUST_RUNNER_SKIP_BUILD=1_after_prebuild",
            "guard_semantics": "all_registered_commands_execute_unchanged",
            "bootstrap": "make_bootstrap_after_guards_without_skip_build",
        },
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")
    require(registry["phase23_production_release_audit"].get("status") ==
            "patch23_12_complete", "Patch 23.12 predecessor is not complete")

    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(record.get("phase23_level1_guards") == PHASE23_L1_GUARDS and
            set(PHASE23_L1_GUARDS) == set(phase23_guard_inventory(levels, 1)),
            "complete Phase 23 Level 1 inventory drifted")
    require(record.get("phase23_level2_guards") == PHASE23_L2_GUARDS and
            set(PHASE23_L2_GUARDS) == set(phase23_guard_inventory(levels, 2)),
            "complete Phase 23 Level 2 inventory drifted")
    require(record.get("supplemental_level2_guards") == SUPPLEMENTAL_L2_GUARDS,
            "supplemental qualification inventory drifted")
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 23.13 guard levels drifted")

    issue_records = {
        105: registry["phase23_same_scope_declaration"],
        110: registry["phase23_mir_evidence_owner"],
        240: registry["phase23_resource_acquisition_parity"],
    }
    for issue, authority in issue_records.items():
        closure = authority.get("issue_closure", {})
        require(authority.get("issue") == issue and
                authority.get("status") == "closed_on_merged_current_main" and
                closure.get("state") == "closed_after_merged_current_main_validation" and
                closure.get("issue_state") == "closed" and
                closure.get("current_main_validation", {}).get("result") ==
                "completed_success",
                f"issue #{issue} is not closed on registered current-main evidence")
    issue_roadmap = ISSUES.read_text(encoding="utf-8")
    for issue in (105, 110, 240):
        require(f"[#${issue}" not in issue_roadmap and
                f"[#{issue} —" in issue_roadmap,
                f"issue #{issue} is absent from the closed issue ledger")

    require(registry["phase23_assurance_phase_a"].get("status") ==
            "phase23_4_complete_report_only" and
            registry["phase23_assurance_phase_b"].get("status") ==
            "phase23_5_complete_report_only" and
            registry["phase23_assurance_phase_b"].get("boundary", {}).get(
                "executes_candidate_code") is False,
            "Assurance A/B is not complete and report-only")

    audit = registry["phase23_production_release_audit"]["audit"]
    require(record.get("route_inventory") == audit == {
        "supported_surface_count": 6,
        "supported_surface_manifest_digest": audit["supported_surface_manifest_digest"],
        "repository_invocation_count": 318,
        "repository_explicit_c_count": 178,
        "phase25_bootstrap_explicit_c_count": 5,
        "non_bootstrap_retained_test_surface_count": 173,
        "supported_production_or_release_explicit_c_count": 0,
        "active_non_bootstrap_live_c_lane_count": 1,
        "active_non_bootstrap_live_c_owner": "phase23_mir_to_c_focused_live",
        "unknown_downstream_count": 0,
    }, "production, route, or downstream inventory drifted")
    require(registry["phase23_production_release_audit"]["route_contract"].get(
        "fallback") == "forbidden", "no-fallback authority drifted")

    residues = record.get("residues")
    require(isinstance(residues, list) and residues == [
        {
            "id": "nonbootstrap_explicit_c_evidence",
            "count": 173,
            "owner": "cranelift",
            "destination_phase": "24",
            "reason": "deprecated_generated_C_backend_retained_for_the_single_focused_oracle_and_classified_historical_or_archived_evidence",
            "falsifier": "count_or_complete_identity_changes_or_any_supported_production_or_release_route_requires_C",
        },
        {
            "id": "bootstrap_explicit_c_chain",
            "count": 5,
            "owner": "cranelift",
            "destination_phase": "25",
            "reason": "make_gust_make_bootstrap_and_the_committed_C_seed_remain_owned_by_the_separate_bootstrap_retirement_phase",
            "falsifier": "count_or_identity_changes_or_bootstrap_stops_using_the_registered_explicit_C_chain_before_Phase_25",
        },
    ], "complete residue classification drifted")
    require(sum(row["count"] for row in residues) ==
            record["route_inventory"]["repository_explicit_c_count"],
            "residue counts do not partition the explicit-C inventory")

    coverage = record.get("coverage", {})
    require(set(coverage) == {
        "level1_authority", "level2_behaviour", "issue_health",
        "assurance_report_only", "deprecation_and_frozen_surface",
        "focused_live_and_archive", "package_install_and_release",
        "bootstrap", "default_and_explicit_native", "explicit_c_identity",
        "cleanup_and_resources", "side_effects", "diagnostics", "target",
        "no_fallback", "consumer_scanner", "workflow_reachability",
    } and all(isinstance(owners, list) and owners for owners in coverage.values()),
            "qualification coverage is incomplete")
    validate_transition(record, registry)

    require(record.get("boundary") == {
        "changes_accepted_Gust_program_meaning": False,
        "adds_or_changes_MIR_operations": False,
        "changes_ABI_layout_runtime_symbols_target_or_linker": False,
        "changes_backend_route_default_or_fallback": False,
        "changes_bootstrap_route_or_seed": False,
        "edits_stdlib_or_CR15": False,
        "begins_patch23_14": False,
    }, "Patch 23.13 boundary widened")
    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 23.13 — Cross-Feature Qualification and Residue Audit — DONE"
            in task, "TASK does not mark Patch 23.13 DONE")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in just and f"{GUARD_L2}:" in just,
            "Patch 23.13 just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Patch 23.13 contract")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    for marker in (
        "pull_request:", "push:", "workflow_dispatch:", "gust_v4.c",
        "compiler/**", "src/runtime.c", "src/runtime/**",
        "tools/normalize_generated_arena_offsets.py", GUARD_L1, GUARD_L2,
    ):
        require(marker in workflow, f"Patch 23.13 workflow is missing {marker}")
    return record


def render(record: dict) -> str:
    lines = [
        "# Cranelift Phase 23.13 — Cross-Feature Qualification",
        "",
        "Generated from `scripts/cranelift_feature_registry.json`; do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Phase 23 Level 1 guards: `{len(record['phase23_level1_guards'])}`",
        f"- Phase 23 Level 2 guards: `{len(record['phase23_level2_guards'])}`",
        f"- Supplemental Level 2 owners: `{len(record['supplemental_level2_guards'])}`",
        f"- Unexplained differences: `{len(record['unexplained_differences'])}`",
        f"- Module or fixture exceptions: `{len(record['module_or_fixture_exceptions'])}`",
        f"- Unclassified residues: `{len(record['unclassified_residues'])}`",
        "",
        "## Execution model",
        "",
        "The aggregate builds the native package once, then executes every",
        "registered guard command unchanged with the runner's existing",
        "`GUST_RUNNER_SKIP_BUILD=1` mode. The final `make bootstrap` runs",
        "without that environment override. This removes redundant compiler",
        "rebuilds without changing the guard population or the 85-minute budget.",
        "",
        "## Coverage",
        "",
    ]
    for name, owners in record["coverage"].items():
        lines.append(f"- `{name}`: `{', '.join(owners)}`")
    lines += ["", "## Residues", ""]
    for row in record["residues"]:
        lines += [
            f"- `{row['id']}`: `{row['count']}` calls; owner `{row['owner']}`; "
            f"destination Phase `{row['destination_phase']}`.",
            f"  - Reason: `{row['reason']}`.",
            f"  - Falsifier: `{row['falsifier']}`.",
        ]
    inventory = record["route_inventory"]
    lines += [
        "",
        "## Route inventory",
        "",
        f"- Repository invocations: `{inventory['repository_invocation_count']}`",
        f"- Explicit C: `{inventory['repository_explicit_c_count']}`",
        f"- Phase 25 bootstrap explicit C: `{inventory['phase25_bootstrap_explicit_c_count']}`",
        f"- Non-bootstrap retained C: `{inventory['non_bootstrap_retained_test_surface_count']}`",
        f"- Supported production/release C requirements: `{inventory['supported_production_or_release_explicit_c_count']}`",
        f"- Unknown downstream consumers: `{inventory['unknown_downstream_count']}`",
        "",
        "Issues #105, #110, and #240 are closed on their registered merged",
        "current-main evidence. Assurance A/B remains report-only. The two",
        "residue rows partition every explicit-C invocation and preserve the",
        "separate Phase 24 generated-C and Phase 25 bootstrap-C boundaries.",
        "This qualification introduces no module, fixture, source-spelling, or",
        "stdlib exception and changes no semantics, MIR, ABI, runtime symbol,",
        "route, fallback, target, linker, bootstrap seed, Stdlib, or CR-15 state.",
        "",
    ]
    return "\n".join(lines)


def run_with_deadline(
    command: list[str], deadline: float, *, env: dict[str, str] | None = None
) -> None:
    remaining = deadline - time.monotonic()
    require(remaining > 0, "qualification elapsed budget was exhausted")
    print("+ " + " ".join(command), flush=True)
    process = subprocess.Popen(
        command, cwd=ROOT, env=env, start_new_session=True
    )
    try:
        status = process.wait(timeout=remaining)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()
        raise SystemExit(
            f"{GUARD_L2}: elapsed budget exhausted during {' '.join(command)}"
        )
    require(status == 0, f"command failed ({status}): {' '.join(command)}")


def evidence(record: dict) -> None:
    deadline = time.monotonic() + record["budgets"]["evidence_elapsed_ms"] / 1000
    for command in STATIC_COMMANDS:
        run_with_deadline(command, deadline)
    run_with_deadline(["make", "phase10-native-package"], deadline)
    guard_env = os.environ.copy()
    guard_env["GUST_RUNNER_SKIP_BUILD"] = "1"
    for guard in PHASE23_L1_GUARDS + PHASE23_L2_GUARDS + SUPPLEMENTAL_L2_GUARDS:
        run_with_deadline(["just", guard], deadline, env=guard_env)
    run_with_deadline(["make", "bootstrap"], deadline)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review", "evidence"))
    args = parser.parse_args()
    record = validate()
    rendered = render(record)
    if args.command == "project":
        REVIEW.write_text(rendered, encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and REVIEW.read_text(encoding="utf-8") == rendered,
                "generated review is stale")
    elif args.command == "evidence":
        evidence(record)
    print(f"{GUARD_L1}: {args.command} ok")


if __name__ == "__main__":
    main()
