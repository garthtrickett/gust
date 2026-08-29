#!/usr/bin/env python3
"""Validate, project, and replay Patch 22.7 post-flip qualification."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
MAKEFILE = ROOT / "Makefile"
README = ROOT / "README.md"
LEDGER = ROOT / "docs/ONE_WAY_LEDGER.md"
CRANELIFT_README = ROOT / "compiler/experiments/cranelift/README.md"
HELP = ROOT / "compiler/phase10_help.txt"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE22_POSTFLIP_QUALIFICATION.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase22-postflip-qualification.yml"
EVIDENCE = ROOT / "scripts/phase22_postflip_qualification.sh"
GUARD_L1 = "guard-cranelift-phase22-postflip-qualification-contract"
GUARD_L2 = "guard-cranelift-phase22-postflip-qualification-evidence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def event_paths(workflow: str, event: str, next_event: str) -> str:
    start_marker = f"  {event}:"
    end_marker = f"  {next_event}:"
    require(start_marker in workflow and end_marker in workflow,
            f"workflow has no bounded {event} filter")
    return workflow.split(start_marker, 1)[1].split(end_marker, 1)[0]


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    predecessor = registry.get("phase22_default_route_seed_convergence", {})
    require(predecessor.get("contract_version") ==
            "phase22_default_route_seed_convergence_v1" and
            predecessor.get("status") == "patch22_6a_complete",
            "Patch 22.6a predecessor authority drifted")
    record = registry.get("phase22_postflip_qualification")
    require(isinstance(record, dict), "Patch 22.7 authority is missing")
    require(record.get("contract_version") ==
            "phase22_postflip_qualification_v1" and
            record.get("status") == "qualification_complete" and
            record.get("next_patch") == "22.8" and
            record.get("predecessor_authority") ==
            predecessor.get("contract_version"),
            "Patch 22.7 identity or status drifted")

    delivery = record.get("delivery_contract", {})
    require(delivery == {
        "make_default_goal": "phase10-native-package",
        "default_backend": "cranelift",
        "package_artifacts": [
            "gust", "gust-native-backend", "gust-runtime-package.a"],
        "install_and_relocation_unit": "three_artifact_sibling_directory",
        "explicit_c_spellings": ["c", "mir-to-c"],
        "explicit_c_role":
            "semantic_oracle_bootstrap_and_operator_selected_rollback",
        "fallback": "forbidden",
        "bootstrap_route": "explicit_mir_to_c",
    }, "delivery contract drifted")

    makefile = MAKEFILE.read_text(encoding="utf-8")
    for marker in (
        ".DEFAULT_GOAL := phase10-native-package",
        "all: phase10-native-package",
        "phase10-native-package: gust build/gust-native-backend $(PHASE21_RUNTIME_PACKAGE)",
        "install: phase10-native-package",
        "./gust --backend mir-to-c compiler/test_runner_entry.gst",
    ):
        require(marker in makefile, f"build/install contract marker missing: {marker}")

    readme = README.read_text(encoding="utf-8")
    for marker in (
        "Gust compiles to native executables through Cranelift by default.",
        "`--backend c` or `--backend mir-to-c`",
        "There is no automatic fallback",
        "`gust-native-backend`",
        "`gust-runtime-package.a`",
    ):
        require(marker in readme, f"README route/package marker missing: {marker}")
    ledger = LEDGER.read_text(encoding="utf-8")
    require("Cranelift is the default; C remains the named oracle" in ledger and
            "rollback is an explicit `--backend c`" in ledger,
            "one-way ledger still describes the pre-flip route")
    cranelift_readme = CRANELIFT_README.read_text(encoding="utf-8")
    require("Current status (Phase 22)" in cranelift_readme and
            "historical record" in cranelift_readme,
            "native backend README does not distinguish current status")
    help_text = HELP.read_text(encoding="utf-8")
    require("Compile to one native executable (default)." in help_text and
            "retained semantic oracle" in help_text and
            "fallback to MIR-to-C" in help_text,
            "checked help does not state the post-flip contract")

    required_inputs = record.get("native_workflow_inputs")
    expected_inputs = [
        "gust_v4.c", "compiler/*.gst",
        "compiler/experiments/cranelift/**", "src/runtime.c",
        "src/runtime/**", "tools/normalize_generated_arena_offsets.py",
    ]
    require(required_inputs == expected_inputs,
            "native workflow input authority drifted")
    for relative in record.get("owning_workflows", []):
        workflow_path = ROOT / relative
        require(workflow_path.is_file(), f"owning workflow is missing: {relative}")
        workflow = workflow_path.read_text(encoding="utf-8")
        pull_paths = event_paths(workflow, "pull_request", "push")
        push_end = "workflow_dispatch" if "  workflow_dispatch:" in workflow else "permissions"
        push_paths = event_paths(workflow, "push", push_end)
        for native_input in required_inputs:
            marker = f"      - '{native_input}'"
            require(marker in pull_paths and marker in push_paths,
                    f"{relative} omits {native_input} from pull_request or push")

    qualification = record.get("qualification", {})
    require(set(qualification.values()) == {
        "qualified", "artifact_and_behavior_identical",
        "byte_identical_and_executable",
        "bare_default_fails_without_fallback_and_explicit_c_succeeds",
        "cranelift_default_explicit_c_oracle_no_fallback",
        "exact_three_artifact_sibling_package",
    }, "qualification result drifted")
    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 22.7 — Post-flip CI, Documentation, and Rollback Qualification — DONE" in task and
            "- [ ] Patch 22.8 — One-Time Default-Native Stability Qualification" in task,
            "22.7/22.8 roadmap boundary drifted")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "guard levels drifted")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in just and f"{GUARD_L2}:" in just,
            "just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the contract")
    focused = WORKFLOW.read_text(encoding="utf-8")
    require("- run: make" in focused and f"just {GUARD_L1}" in focused and
            f"just {GUARD_L2}" in focused,
            "focused workflow does not own default build and both guards")
    boundary = record.get("boundary", {})
    require(boundary.get("changes_build_delivery_default") is True and
            boundary.get("changes_documentation_and_CI") is True and
            all(value is False for key, value in boundary.items()
                if key not in {"changes_build_delivery_default",
                               "changes_documentation_and_CI"}),
            "Patch 22.7 boundary widened")
    return record


def render(record: dict) -> str:
    delivery = record["delivery_contract"]
    qualification = record["qualification"]
    lines = [
        "# Cranelift Phase 22.7 — Post-flip Qualification",
        "",
        "Generated from `scripts/cranelift_feature_registry.json`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Observed main: `{record['observed_main_sha']}`",
        f"- Predecessor: `{record['predecessor_authority']}`",
        "",
        "## Delivery",
        "",
        f"- Make default goal: `{delivery['make_default_goal']}`",
        f"- Compiler default: `{delivery['default_backend']}`",
        f"- Package: `{', '.join(delivery['package_artifacts'])}`",
        f"- Install/relocation unit: `{delivery['install_and_relocation_unit']}`",
        f"- Explicit C spellings: `{', '.join(delivery['explicit_c_spellings'])}`",
        f"- Explicit C role: `{delivery['explicit_c_role']}`",
        f"- Fallback: `{delivery['fallback']}`",
        f"- Bootstrap route: `{delivery['bootstrap_route']}`",
        "",
        "## Qualification",
        "",
    ]
    lines += [f"- {key}: `{value}`" for key, value in qualification.items()]
    lines += [
        "",
        "## Native workflow dependencies",
        "",
    ]
    lines += [f"- `{path}`" for path in record["native_workflow_inputs"]]
    lines += [
        "",
        "Every listed input is present in both pull-request and main-push path",
        "filters of every owning Phase 22 native qualification workflow.",
        "Explicit C is the named oracle and rollback route; native failure never",
        "selects it automatically. This patch adds no Gust semantics, canonical",
        "MIR/lowering, ABI/layout/runtime-symbol, target/linker, seed, or Stdlib",
        "change, and does not begin Patch 22.8.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review", "evidence"))
    args = parser.parse_args()
    record = validate()
    rendered = render(record)
    if args.command == "project":
        REVIEW.write_text(rendered, encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.exists() and REVIEW.read_text(encoding="utf-8") == rendered,
                "generated review view is stale")
    elif args.command == "evidence":
        subprocess.run(["bash", str(EVIDENCE)], cwd=ROOT, check=True)
    print(f"{GUARD_L1}: {args.command} ok")


if __name__ == "__main__":
    main()
