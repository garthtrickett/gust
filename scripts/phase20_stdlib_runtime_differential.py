#!/usr/bin/env python3
"""Validate and project Patch 20.13 stdlib/runtime differential authority."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_STDLIB_RUNTIME_DIFFERENTIAL.md"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
JUSTFILE = ROOT / "justfile"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
GUARD_L1 = "guard-cranelift-phase20-stdlib-runtime-contract"
GUARD_L2 = "guard-cranelift-phase20-stdlib-runtime-parity"


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    authority = registry.get("phase20_stdlib_runtime_differential")
    require(isinstance(authority, dict), "Patch 20.13 authority is missing")
    require(authority.get("contract_version") ==
            "phase20_stdlib_runtime_differential_v1",
            "Patch 20.13 contract version drifted")
    require(authority.get("status") == "patch20_13_complete" and
            authority.get("next_patch") == "20.14",
            "Patch 20.13 status or successor drifted")
    require(authority.get("selection_policy") ==
            "select_only_components_with_a_real_whole_program_cranelift_source_route",
            "Patch 20.13 selection policy drifted")
    require(authority.get("marker_policy") ==
            "source_markers_and_request_witnesses_do_not_establish_component_execution",
            "Patch 20.13 permits marker-only qualification")
    require(authority.get("normalization_policy") == "none",
            "Patch 20.13 permits observable normalization")

    selected = authority.get("selected_components")
    require(isinstance(selected, list) and len(selected) == 1,
            "Patch 20.13 selected component count drifted")
    component = selected[0]
    require(component.get("component_id") ==
            "runtime_component:approved_scalar_imports",
            "Patch 20.13 selected an unconnected component")
    require(component.get("whole_program_case") ==
            "p20_multi_module_runtime_scalar",
            "Patch 20.13 selected case ownership drifted")
    require((ROOT / component["source_fixture"]).is_file(),
            "Patch 20.13 selected source fixture is missing")
    imports = registry["phase17_runtime_import_authority"]["selected_imports"]
    expected_helpers = [row["external_spelling"] for row in imports]
    require(component.get("selected_helpers") == expected_helpers,
            "Patch 20.13 selected helper projection drifted")
    corpus_cases = registry["phase20_whole_program_corpus"]["selected_cases"]
    require(any(case["id"] == component["whole_program_case"] and
                case["kind"] == "runtime_success" for case in corpus_cases),
            "Patch 20.13 selected component lacks Patch 20.12 runtime evidence")

    exclusions = authority.get("explicit_exclusions")
    require(isinstance(exclusions, list) and len(exclusions) == 6,
            "Patch 20.13 exclusion inventory drifted")
    require({row.get("category") for row in exclusions} == {
        "collections", "strings", "filesystem", "allocation", "resources",
        "threading_synchronization",
    }, "Patch 20.13 category coverage drifted")
    for row in exclusions:
        require((ROOT / row["source_fixture"]).is_file(),
                f"Patch 20.13 exclusion fixture missing: {row['source_fixture']}")
        require(row.get("owner") and row.get("reason_code") and
                row.get("falsifier") and row.get("destination") == "20.16",
                f"Patch 20.13 exclusion is unowned: {row.get('category')}")
        require(row.get("decision") in {"deferred", "source_or_type_failure"},
                f"Patch 20.13 exclusion decision drifted: {row.get('category')}")

    require("- [x] Patch 20.13 — Stdlib and Runtime Component Differential — DONE"
            in TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 20.13 DONE")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 20.13 guard levels drifted")
    workflow = PR_FAST.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow,
            "PR Fast does not own both Patch 20.13 guards")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in justfile and f"{GUARD_L2}:" in justfile,
            "Patch 20.13 just guards are missing")
    return authority


def exclusion_rows(authority: dict) -> str:
    return "\n".join("\t".join([
        row["category"], row["source_fixture"], row["decision"],
        row["reason_code"], row["owner"], row["destination"],
    ]) for row in authority["explicit_exclusions"])


def render(authority: dict) -> str:
    selected = authority["selected_components"][0]
    lines = [
        "# Cranelift Phase 20 Stdlib and Runtime Component Differential",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_stdlib_runtime_differential.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{authority['contract_version']}`",
        f"- Status: `{authority['status']}`",
        f"- Next patch: `{authority['next_patch']}`",
        f"- Selection policy: `{authority['selection_policy']}`",
        f"- Marker policy: `{authority['marker_policy']}`",
        f"- Normalization policy: `{authority['normalization_policy']}`",
        "",
        "## Selected component",
        "",
        f"- Component: `{selected['component_id']}`",
        f"- Whole-program case: `{selected['whole_program_case']}`",
        f"- Source: `{selected['source_fixture']}`",
        f"- Helpers: `{','.join(selected['selected_helpers'])}`",
        "",
        "This is the only current component with a real, no-fallback",
        "whole-program source route. Patch 20.12 owns its exact compile/runtime",
        "status, stdout, stderr, canonical request/bundle, and filesystem evidence.",
        "",
        "## Explicit exclusions",
        "",
    ]
    for row in authority["explicit_exclusions"]:
        lines += [
            f"- `{row['category']}` — `{row['decision']}` / `{row['reason_code']}`",
            f"  - Fixture: `{row['source_fixture']}`",
            f"  - Owner: `{row['owner']}`; destination: `{row['destination']}`",
            f"  - Falsifier: {row['falsifier']}",
        ]
    lines += [
        "",
        "Phase 17 request witnesses continue to prove runtime-operation contract",
        "agreement, but a scalar marker plus a request witness is not counted as",
        "execution of a collection, string, filesystem, allocation, Resource, or",
        "synchronization program. Every exclusion is re-probed before driver",
        "discovery with MIR-to-C fallback poisoned.",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=(
        "validate", "project", "check-review", "exclusion-cases",
    ))
    args = parser.parse_args()
    try:
        authority = validate()
        if args.command == "project":
            REVIEW.write_text(render(authority), encoding="utf-8")
        elif args.command == "check-review":
            require(REVIEW.read_text(encoding="utf-8") == render(authority),
                    "generated Patch 20.13 review is stale; run project")
        elif args.command == "exclusion-cases":
            print(exclusion_rows(authority))
    except (Error, KeyError) as error:
        print(f"{GUARD_L1}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
