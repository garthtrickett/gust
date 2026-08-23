#!/usr/bin/env python3
"""Validate and project Patch 20.12 whole-program corpus authority."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_WHOLE_PROGRAM_CORPUS.md"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
JUSTFILE = ROOT / "justfile"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
GUARD_L1 = "guard-cranelift-phase20-whole-program-corpus-contract"
GUARD_L2 = "guard-cranelift-phase20-whole-program-corpus-parity"


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    authority = registry.get("phase20_whole_program_corpus")
    require(isinstance(authority, dict), "Patch 20.12 authority is missing")
    require(authority.get("contract_version") ==
            "phase20_whole_program_corpus_v1",
            "Patch 20.12 contract version drifted")
    require(authority.get("status") == "patch20_12_complete" and
            authority.get("next_patch") == "20.13",
            "Patch 20.12 status or successor drifted")
    require(authority.get("harness") ==
            "scripts/phase20_whole_program_corpus.sh",
            "Patch 20.12 harness drifted")
    require(authority.get("normalization_policy") ==
            "none_in_the_initial_cohort",
            "Patch 20.12 silently permits normalization")
    require(authority.get("no_fallback_policy") ==
            "explicit_cranelift_runs_with_mir_to_c_poisoned_and_must_not_fall_back",
            "Patch 20.12 no-fallback policy drifted")

    observable_ids = [row.get("id") for row in authority.get("observables", [])]
    require(observable_ids == [
        "compile_result", "process_exit_status", "stdout", "stderr_diagnostics",
        "resource_terminal_state", "sandboxed_filesystem_effects",
    ], "Patch 20.12 observable inventory drifted")

    cases = authority.get("selected_cases")
    require(isinstance(cases, list) and len(cases) == 5,
            "Patch 20.12 must select exactly five initial cases")
    require(len({case.get("id") for case in cases}) == len(cases),
            "Patch 20.12 selected case IDs are not unique")
    require({case.get("kind") for case in cases} ==
            {"runtime_success", "compile_failure"},
            "Patch 20.12 selected case kinds drifted")
    for case in cases:
        require((ROOT / case["source_fixture"]).is_file(),
                f"selected fixture is missing: {case['source_fixture']}")
        for companion in case.get("companion_fixtures", []):
            require((ROOT / companion).is_file(),
                    f"selected companion fixture is missing: {companion}")
        require(case.get("normalization") == "none",
                f"selected case {case['id']} normalizes an observable")
        require(case.get("side_effect_policy") == "none",
                f"selected case {case['id']} has undeclared filesystem effects")
        require(case.get("level") == 2,
                f"selected case {case['id']} is not registered Level 2")

    runtime_cases = [case for case in cases
                     if case["kind"] == "runtime_success"]
    failure_cases = [case for case in cases
                     if case["kind"] == "compile_failure"]
    require(len(runtime_cases) == 3 and len(failure_cases) == 2,
            "Patch 20.12 runtime/failure cohort shape drifted")
    require(any(case.get("companion_fixtures") for case in runtime_cases),
            "Patch 20.12 has no multi-file selected program")
    selected_features = {
        feature for case in cases for feature in case.get("feature_claims", [])
    }
    require({"modules", "control_flow", "generics", "brands", "resources",
             "aggregates", "failure_diagnostics"}.issubset(selected_features),
            "Patch 20.12 selected feature coverage drifted")

    exclusions = authority.get("explicit_exclusions")
    require(isinstance(exclusions, list) and len(exclusions) == 3,
            "Patch 20.12 explicit exclusion inventory drifted")
    require(all(row.get("owner") and row.get("reason") and row.get("falsifier")
                for row in exclusions),
            "Patch 20.12 exclusion lacks owner, reason, or falsifier")
    require({row.get("id") for row in exclusions} == {
        "successful_generic_brand_resource_source_route",
        "observable_runtime_io_and_filesystem",
        "costly_whole_program_cases",
    }, "Patch 20.12 exclusion IDs drifted")

    require("- [x] Patch 20.12 — Whole-Program Corpus and Observable Contract — DONE"
            in TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 20.12 DONE")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 20.12 guard levels drifted")
    workflow = PR_FAST.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow,
            "PR Fast does not own both Patch 20.12 guards")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in justfile and f"{GUARD_L2}:" in justfile,
            "Patch 20.12 just guards are missing")
    return authority


def case_rows(authority: dict, kind: str) -> str:
    rows = []
    for case in authority["selected_cases"]:
        if case["kind"] != kind:
            continue
        rows.append("\t".join([
            case["id"], case["source_fixture"],
            str(case["expected_compile_status"]),
            str(case.get("expected_exit_status", "none")),
            case.get("diagnostic_substring", "none"),
            case["resource_terminal_state"], case["side_effect_policy"],
            case["normalization"],
        ]))
    return "\n".join(rows)


def render(authority: dict) -> str:
    lines = [
        "# Cranelift Phase 20 Whole-Program Corpus",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_whole_program_corpus.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{authority['contract_version']}`",
        f"- Status: `{authority['status']}`",
        f"- Next patch: `{authority['next_patch']}`",
        f"- Harness: `{authority['harness']}`",
        f"- Canonical MIR policy: `{authority['canonical_mir_policy']}`",
        f"- No-fallback policy: `{authority['no_fallback_policy']}`",
        f"- Normalization policy: `{authority['normalization_policy']}`",
        "",
        "## Observables",
        "",
    ]
    lines += [f"- `{row['id']}` — `{row['comparison']}`"
              for row in authority["observables"]]
    lines += ["", "## Selected initial cohort", ""]
    for case in authority["selected_cases"]:
        expectation = (f"exit {case['expected_exit_status']}"
                       if case["kind"] == "runtime_success"
                       else f"compile {case['expected_compile_status']} / "
                            f"`{case['diagnostic_substring']}`")
        lines.append(
            f"- `{case['id']}` — `{case['kind']}`, {expectation}; "
            f"features `{','.join(case['feature_claims'])}`"
        )
    lines += ["", "## Explicit exclusions", ""]
    for row in authority["explicit_exclusions"]:
        lines += [
            f"- `{row['id']}` — owner `{row['owner']}`; next `{row['next_patch']}`",
            f"  - Reason: {row['reason']}",
            f"  - Falsifier: {row['falsifier']}",
        ]
    lines += [
        "",
        "The initial cohort claims only connected runtime programs and exact",
        "shared-front-end failures. Successful generic, branded, Resource, and",
        "observable I/O/filesystem programs are not silently counted as native",
        "parity; their exclusions remain registered until their stated falsifiers",
        "are met. No selected case permits environmental normalization.",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=(
        "validate", "project", "check-review", "runtime-cases", "failure-cases",
    ))
    args = parser.parse_args()
    try:
        authority = validate()
        if args.command == "project":
            REVIEW.write_text(render(authority), encoding="utf-8")
        elif args.command == "check-review":
            require(REVIEW.read_text(encoding="utf-8") == render(authority),
                    "generated Patch 20.12 review is stale; run project")
        elif args.command == "runtime-cases":
            print(case_rows(authority, "runtime_success"))
        elif args.command == "failure-cases":
            print(case_rows(authority, "compile_failure"))
    except (Error, KeyError) as error:
        print(f"{GUARD_L1}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
