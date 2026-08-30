#!/usr/bin/env python3
"""Validate and project the Patch 23.2 MIR evidence-owner authority."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE23_MIR_EVIDENCE_OWNER.md"
TASK = ROOT / "TASK.md"
ISSUE_ROADMAP = ROOT / "docs/ISSUE_ROADMAP.md"
ALLOWLIST = ROOT / "scripts/guard_reachability_allowlist.json"
GUARD = "guard-cranelift-phase23-mir-evidence-owner-contract"
LOWER_GUARD = "guard-mir-lower-tiny-function-surface"
TOKEN = re.compile(r"\bmir_lower_[A-Za-z0-9_]+\b")
DEFINITION = re.compile(r"^func (mir_lower_[A-Za-z0-9_]+)\b", re.MULTILINE)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def authority() -> dict:
    data = json.loads(REGISTRY.read_text(encoding="utf-8"))
    value = data.get("phase23_mir_evidence_owner")
    require(isinstance(value, dict), "registry authority is missing")
    return value


def retired_recipe() -> str:
    # Keep the retired name out of executable caller text. The generated
    # authority still renders the historical identity for human readers.
    return "guard-" + "mir-to-c-" + "tiny-surface"


def observed_external_callers() -> list[dict]:
    rows: list[dict] = []
    for path in sorted((ROOT / "compiler").glob("*.gst")):
        relative = path.relative_to(ROOT).as_posix()
        if relative == "compiler/mir.gst":
            continue
        names = TOKEN.findall(path.read_text(encoding="utf-8"))
        if not names:
            continue
        for name in sorted(set(names)):
            rows.append({
                "path": relative,
                "entry": name,
                "occurrences": names.count(name),
            })
    return rows


def observed_definitions() -> list[str]:
    text = (ROOT / "compiler/mir.gst").read_text(encoding="utf-8")
    return sorted(DEFINITION.findall(text))


def validate_surface(value: dict, *, callers: list[dict] | None = None) -> None:
    cohort = value["retained_lowering_surface"]
    actual_definitions = observed_definitions()
    actual_callers = observed_external_callers() if callers is None else callers
    require(actual_definitions == sorted(cohort["definitions"]),
            "fixture lowering definition inventory drifted")
    require(actual_callers == cohort["fixture_callers"],
            "MIR lowering entry point escaped or the exact fixture cohort drifted")

    checked_paths = ["compiler/mir.gst"] + [row["path"] for row in actual_callers]
    forbidden = cohort["forbidden_backend_token"]
    for relative in sorted(set(checked_paths)):
        require(forbidden not in (ROOT / relative).read_text(encoding="utf-8"),
                f"fixture-only lowering source names backend token in {relative}")


def validate_falsifiers(value: dict) -> None:
    validate_surface(value)
    mutation = value["production_use_falsifier"]
    mutated = observed_external_callers() + [{
        "path": mutation["injected_path"],
        "entry": mutation["injected_entry"],
        "occurrences": 1,
    }]
    mutated.sort(key=lambda row: (row["path"], row["entry"]))
    rejected = False
    try:
        validate_surface(value, callers=mutated)
    except SystemExit:
        rejected = True
    require(rejected, "production-use mutation did not falsify the retained invariant")


def non_authority_tracked_paths() -> list[Path]:
    authority_references = {
        "TASK.md",
        "docs/ISSUE_ROADMAP.md",
        "compiler/CRANELIFT_PHASE23_ISSUE_HEALTH_OPENING.md",
        "compiler/CRANELIFT_PHASE23_MIR_EVIDENCE_OWNER.md",
        "scripts/cranelift_feature_registry.json",
    }
    raw = subprocess.check_output(
        ["git", "ls-files", "-z"], cwd=ROOT,
    ).decode("utf-8").split("\0")
    return [
        ROOT / relative
        for relative in raw
        if relative and relative not in authority_references and
        (ROOT / relative).is_file()
    ]


def validate_retirement(value: dict) -> None:
    retirement = value["retired_location_guard"]
    name = retired_recipe()
    require(retirement["recipe"] == name, "retired recipe identity drifted")
    callers = []
    for path in non_authority_tracked_paths():
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        if name in text:
            callers.append(path.relative_to(ROOT).as_posix())
    require(not callers,
            "retired MIR-to-C location guard retains executable callers: " +
            ", ".join(callers))
    allowlist = json.loads(ALLOWLIST.read_text(encoding="utf-8"))
    require(name not in allowlist["known_unreachable"],
            "retired guard still has a reachability exemption")
    require(name not in allowlist["notes"],
            "retired guard still has an ownership note")


def validate() -> dict:
    value = authority()
    require(value.get("contract_version") == "phase23_mir_evidence_owner_v1",
            "contract version drifted")
    require(value.get("status") ==
            "implementation_ready_pending_merged_current_main_closure",
            "implementation/closure state drifted")
    require(value.get("issue") == 110 and value.get("owner") == "cranelift",
            "issue or owner drifted")
    require(value.get("review_view") == REVIEW.relative_to(ROOT).as_posix(),
            "review view drifted")
    require(value.get("implementation_base_sha") ==
            "0c5167443121f3dc2f0a0e143da8638753d96a8d",
            "implementation base drifted")
    require(value.get("retained_guard") == LOWER_GUARD,
            "retained guard identity drifted")

    cohort = value.get("retained_lowering_surface")
    require(isinstance(cohort, dict) and set(cohort) == {
        "invariant", "definitions", "fixture_callers",
        "forbidden_backend_token", "normal_topology_owner",
    }, "retained surface field set drifted")
    require(len(cohort["definitions"]) == 8 and
            len(cohort["fixture_callers"]) == 17,
            "complete fixture cohort cardinality drifted")
    require(all(set(row) == {"path", "entry", "occurrences"} and
                row["path"].startswith("compiler/") and
                row["entry"].startswith("mir_lower_") and
                row["occurrences"] == 1
                for row in cohort["fixture_callers"]),
            "fixture caller row is malformed")
    require(cohort["normal_topology_owner"] ==
            "PR_Fast_Level_1_and_dedicated_Patch_23_2_workflow",
            "normal topology owner drifted")

    mutation = value.get("production_use_falsifier")
    require(mutation == {
        "injected_path": "compiler/typechecker.gst",
        "injected_entry": "mir_lower_tiny_function_fixture",
        "expected": "reject_unregistered_production_caller",
    }, "production-use falsifier drifted")
    retirement = value.get("retired_location_guard")
    require(isinstance(retirement, dict) and retirement == {
        "recipe": retired_recipe(),
        "reason": "production_MIR_to_C_is_legitimate_so_a_fixture_only_location_allowlist_no_longer_states_a_valid_invariant",
        "replacement": "executable_MIR_to_C_behavioral_guards_and_the_retained_fixture_only_lowering_guard",
        "required_live_callers": 0,
        "required_reachability_exemptions": 0,
    }, "retired location-guard authority drifted")
    require(value.get("issue_closure") == {
        "state": "pending_implementation_merge",
        "requirement": "close_only_after_current_main_guard_passes_and_the_issue_and_routing_ledger_cite_exact_PR_and_merge_evidence",
    }, "issue-closure sequencing drifted")
    require(value.get("boundary") == {
        "changes_production_MIR_or_MIR_to_C_capability": False,
        "changes_accepted_Gust_program_meaning": False,
        "adds_or_changes_MIR_operations": False,
        "changes_backend_route_or_fallback": False,
        "changes_ABI_layout_or_runtime_symbols": False,
        "changes_bootstrap_seed": False,
        "edits_stdlib_or_CR15": False,
        "begins_patch23_3": False,
    }, "Patch 23.2 boundary drifted")
    require("- [ ] Patch 23.2 — MIR Evidence-Owner Repair and Retirement (#110)" in
            TASK.read_text(encoding="utf-8"),
            "Patch 23.2 must remain open until merged-main closure evidence")
    require("Implementation authority selected; Cranelift/MIR owner; closure evidence pending." in
            ISSUE_ROADMAP.read_text(encoding="utf-8"),
            "issue routing ledger does not preserve the merged-main closure boundary")
    return value


def render(value: dict) -> str:
    cohort = value["retained_lowering_surface"]
    lines = [
        "# Phase 23 MIR Evidence-Owner Repair",
        "",
        "Generated by `scripts/phase23_mir_evidence_owner.py`; do not edit by hand.",
        "",
        f"- Contract: `{value['contract_version']}`",
        f"- Status: `{value['status']}`",
        f"- Issue: `#{value['issue']}`",
        f"- Retained guard: `{value['retained_guard']}`",
        f"- Invariant: `{cohort['invariant']}`",
        f"- Normal topology: `{cohort['normal_topology_owner']}`",
        "",
        "## Fixture-only lowering cohort",
        "",
        "Definitions: " + ", ".join(f"`{name}`" for name in cohort["definitions"]),
        "",
        "| Caller | Entry | Occurrences |",
        "| --- | --- | ---: |",
    ]
    for row in cohort["fixture_callers"]:
        lines.append(f"| `{row['path']}` | `{row['entry']}` | {row['occurrences']} |")
    retirement = value["retired_location_guard"]
    lines.extend([
        "",
        "## Retired location guard",
        "",
        f"- Recipe: `{retirement['recipe']}`",
        f"- Reason: `{retirement['reason']}`",
        f"- Replacement: `{retirement['replacement']}`",
        "- Live executable callers: `0`",
        "- Reachability exemptions: `0`",
        "",
        "The production-use falsifier injects `mir_lower_tiny_function_fixture` "
        "into `compiler/typechecker.gst`; the retained exact cohort must reject it.",
        "Executable MIR-to-C behavioural guards remain unchanged.",
        "",
        "## Closure sequencing",
        "",
        "Issue #110 remains open in this implementation revision. It may close only "
        "after this guard is merged and passes from exact current main, and after "
        "the issue plus `docs/ISSUE_ROADMAP.md` cite the exact PR and merge commit.",
        "",
        "No production MIR/MIR-to-C capability, accepted Gust meaning, MIR operation, "
        "backend route, ABI/layout/runtime symbol, bootstrap seed, Stdlib, or CR-15 "
        "authority changes here.",
        "",
    ])
    return "\n".join(lines)


def check_review(value: dict) -> None:
    require(REVIEW.read_text(encoding="utf-8") == render(value),
            "generated review is stale; run render")


def evidence() -> None:
    value = validate()
    validate_surface(value)
    validate_falsifiers(value)
    validate_retirement(value)
    check_review(value)
    print("phase23_mir_evidence_owner: evidence ok")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=(
        "validate", "surface", "falsifiers", "retirement", "render",
        "check-review", "evidence",
    ))
    args = parser.parse_args()
    value = validate()
    if args.command == "surface":
        validate_surface(value)
    elif args.command == "falsifiers":
        validate_falsifiers(value)
    elif args.command == "retirement":
        validate_retirement(value)
    elif args.command == "render":
        REVIEW.write_text(render(value), encoding="utf-8")
    elif args.command == "check-review":
        check_review(value)
    elif args.command == "evidence":
        evidence()
    else:
        print("phase23_mir_evidence_owner: ok")


if __name__ == "__main__":
    main()
