#!/usr/bin/env python3
"""Validate and project Patch 22.1 default-route opening evidence."""

from __future__ import annotations

import argparse
import ast
import json
import re
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE22_OPENING.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase22-opening.yml"
GUARD_L1 = "guard-cranelift-phase22-opening-contract"
GUARD_L2 = "guard-cranelift-phase22-opening-evidence"

COMPILER_TOKEN = re.compile(
    r"(?P<token>\./gust(?:_bootstrap)?|"
    r"\./build/phase10-package/bin/gust|"
    r"\./build/(?:diagnostics/phase10-stage1/)?"
    r"gust_stage[0-9]+(?:_bin|_sanitized))(?=\s)"
)
RECIPE = re.compile(r"^([A-Za-z0-9_.-]+)(?:\s+[^:]*)?:\s*$")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def logical_commands(path: Path) -> list[tuple[int, str, str]]:
    """Return shell-like logical lines with their enclosing just recipe."""
    commands: list[tuple[int, str, str]] = []
    pending = ""
    pending_line = 0
    recipe = ""
    for line_no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if path.name.startswith("justfile") and raw and not raw[0].isspace():
            match = RECIPE.match(raw)
            if match:
                recipe = match.group(1)
        stripped = raw.strip()
        if pending:
            pending += " " + stripped
        else:
            pending = stripped
            pending_line = line_no
        if pending.endswith("\\"):
            pending = pending[:-1].rstrip()
            continue
        commands.append((pending_line, pending, recipe))
        pending = ""
    if pending:
        commands.append((pending_line, pending, recipe))
    return commands


def is_non_invocation(command: str, token_start: int) -> bool:
    prefix = command[:token_start]
    if command.startswith("#"):
        return True
    ignored_prefixes = (
        "echo ", "printf ", "rg ", "grep ", "chmod ", "touch ",
        "test -", "[ ", "if [ ", "elif [ ", "case ", "for required in ",
    )
    if command.startswith(ignored_prefixes):
        return True
    if any(marker in prefix for marker in ("echo ", "printf ", "rg ", "grep ")):
        return True
    return False


def selection(command: str) -> str:
    if (re.search(r"--backend(?:=|\s+)cranelift(?:\s|$)", command) or
            re.search(r"['\"]--backend['\"]\s*,\s*['\"]cranelift['\"]", command)):
        return "explicit_cranelift"
    if (re.search(r"--backend(?:=|\s+)(?:mir-to-c|c)(?:\s|$)", command) or
            re.search(r"['\"]--backend['\"]\s*,\s*['\"](?:mir-to-c|c)['\"]", command)):
        return "explicit_c"
    if "--backend" in command:
        return "explicit_invalid_or_parser_probe"
    return "implicit_default"


def classify(path: Path, line_no: int, command: str, recipe: str,
             token: str, selected: str) -> dict[str, object]:
    relative = path.relative_to(ROOT).as_posix()
    if selected != "implicit_default":
        consumer_class = "already_explicit_or_parser_probe"
        owner = (
            "stdlib" if relative.startswith("scripts/stdlib_") or
            recipe.startswith("guard-stdlib-") else "cranelift"
        )
        expected_artifact = "selected_backend_contract"
        transition = "preserve_explicit_selection"
        falsifier = "explicit_selection_is_removed_or_routes_to_a_different_backend"
    elif relative == "Makefile":
        consumer_class = "bootstrap_and_final_compiler_C_generation"
        owner = "cranelift"
        expected_artifact = "generated_C_or_bootstrap_diagnostic"
        transition = "22.2_explicit_mir_to_c_before_default_flip"
        falsifier = "default_flip_reaches_a_bootstrap_stage_before_explicit_C_migration"
    elif relative == "scripts/run-gust-file.sh":
        consumer_class = "developer_generated_C_pipeline"
        owner = "cranelift"
        expected_artifact = "generated_C"
        transition = "22.2_explicit_C_selection"
        falsifier = "default_flip_sends_generated_C_pipeline_to_native_output"
    elif relative in (
            "scripts/phase13_registry_differential.sh",
            "scripts/phase22_opening.sh",
            "scripts/phase22_native_implicit_output.sh",
    ):
        consumer_class = "intentional_default_selection_probe"
        owner = "cranelift"
        expected_artifact = "current_default_route_observation"
        transition = "22.6_flip_expectation_only"
        falsifier = "probe_is_migrated_before_the_default_route_changes"
    elif relative == "scripts/phase22_explicit_c_migration.sh":
        consumer_class = "intentional_default_selection_probe"
        owner = "cranelift"
        expected_artifact = "current_default_route_observation"
        transition = "22.6_flip_expectation_only"
        falsifier = "probe_is_migrated_before_the_default_route_changes"
    elif "--help" in command or re.search(r"(?:^|\s)-h(?:\s|$)", command):
        consumer_class = "help_surface_probe"
        owner = "cranelift"
        expected_artifact = "help_text"
        transition = "22.6_flip_help_expectation"
        falsifier = "help_expectation_changes_before_the_default_route"
    elif relative.startswith("scripts/stdlib_") or recipe.startswith("guard-stdlib-"):
        consumer_class = "stdlib_owned_C_or_diagnostic_guard"
        owner = "stdlib"
        expected_artifact = "generated_C_or_diagnostic"
        transition = "checked_cross_lane_relay_before_22.6"
        falsifier = "default_flip_lands_before_the_owning_lane_classifies_the_consumer"
    elif relative.startswith("justfile") and "expect_invocation_failure" in command:
        consumer_class = "invocation_parser_probe"
        owner = "cranelift"
        expected_artifact = "pre_backend_invocation_diagnostic"
        transition = "preserve_shared_parser_diagnostic"
        falsifier = "backend_migration_changes_a_pre_backend_parser_diagnostic"
    elif relative.startswith("justfile") and recipe.startswith(
            "guard-cranelift-phase10-backend-selection"):
        consumer_class = "intentional_default_selection_probe"
        owner = "cranelift"
        expected_artifact = "current_default_route_observation"
        transition = "22.6_flip_expectation_only"
        falsifier = "probe_is_migrated_before_the_default_route_changes"
    elif relative.startswith("justfile"):
        consumer_class = "repository_C_or_diagnostic_guard"
        owner = "cranelift"
        expected_artifact = "generated_C_or_diagnostic"
        transition = "22.2_explicit_C_selection"
        falsifier = "default_flip_changes_the_guard_artifact_before_explicit_C_migration"
    elif relative.startswith("scripts/"):
        consumer_class = "cranelift_C_or_diagnostic_guard"
        owner = "cranelift"
        expected_artifact = "generated_C_or_diagnostic"
        transition = "22.2_explicit_C_selection"
        falsifier = "default_flip_changes_the_guard_artifact_before_explicit_C_migration"
    else:
        consumer_class = "unclassified"
        owner = ""
        expected_artifact = ""
        transition = ""
        falsifier = "unclassified_invocation_exists"
    return {
        "path": relative,
        "line": line_no,
        "recipe": recipe or "none",
        "compiler_token": token,
        "selection": selected,
        "consumer_class": consumer_class,
        "owner": owner,
        "expected_artifact": expected_artifact,
        "expected_transition": transition,
        "falsifier": falsifier,
        "command": command,
    }


def python_compiler_lists(path: Path) -> list[tuple[int, str, str]]:
    """Return directly represented Python argv lists that select a Gust compiler."""
    source = path.read_text(encoding="utf-8")
    tree = ast.parse(source, filename=str(path))
    rows: list[tuple[int, str, str]] = []
    compiler_expr = re.compile(
        r"(?:['\"]\./gust['\"]|ROOT\s*/\s*['\"]gust['\"]|"
        r"\bPACKAGED_GUST\b|\bGUST\b)"
    )
    for node in ast.walk(tree):
        if not isinstance(node, ast.List):
            continue
        command = ast.unparse(node)
        top_level_compiler = any(
            isinstance(element, (ast.Name, ast.Constant, ast.Call, ast.BinOp))
            and compiler_expr.search(ast.unparse(element))
            for element in node.elts
        )
        if not top_level_compiler:
            continue
        rows.append((node.lineno, command, "python_argv"))
    return rows


def scan_invocations() -> list[dict[str, object]]:
    files = [ROOT / "Makefile"]
    files.extend(sorted(ROOT.glob("justfile*")))
    files.extend(sorted((ROOT / "scripts").glob("*.sh")))
    rows: list[dict[str, object]] = []
    for path in files:
        for line_no, command, recipe in logical_commands(path):
            for match in COMPILER_TOKEN.finditer(command):
                if is_non_invocation(command, match.start()):
                    continue
                selected = selection(command)
                rows.append(classify(
                    path, line_no, command, recipe, match.group("token"), selected
                ))
    for path in sorted((ROOT / "scripts").glob("*.py")):
        for line_no, command, token in python_compiler_lists(path):
            rows.append(classify(
                path, line_no, command, "", token, selection(command)
            ))
    rows.sort(key=lambda row: (str(row["path"]), int(row["line"]), str(row["command"])))
    return rows


def scan_summary(rows: list[dict[str, object]]) -> dict[str, object]:
    selections = Counter(str(row["selection"]) for row in rows)
    classes = Counter(str(row["consumer_class"]) for row in rows)
    owners = Counter(str(row["owner"]) for row in rows)
    return {
        "total": len(rows),
        "selection_counts": dict(sorted(selections.items())),
        "consumer_class_counts": dict(sorted(classes.items())),
        "owner_counts": dict(sorted(owners.items())),
        "unclassified_count": classes.get("unclassified", 0),
    }


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase22_opening")
    require(isinstance(record, dict), "Patch 22.1 authority is missing")
    require(record.get("contract_version") == "phase22_opening_v2",
            "contract version drifted")
    require(record.get("status") == "patch22_1_complete" and
            record.get("next_patch") == "22.2",
            "status or successor drifted")
    require(record.get("observed_main_sha") ==
            "c157c86674624fd298c2f65e98ed8f4df85cb175",
            "opening evidence base drifted")
    require(record.get("phase21_closure_authority") ==
            registry.get("phase21_closure", {}).get("version"),
            "Phase 21 closure link drifted")

    cli = record.get("current_cli")
    require(cli == {
        "bare_route": "mir_to_c",
        "bare_artifact": "C_source_on_stdout",
        "explicit_mir_to_c_route": "mir_to_c",
        "explicit_c_alias": "rejected_unknown_backend",
        "explicit_cranelift_requires_output": True,
        "backend_selection_stage": "after_shared_resolver_parser_and_typechecker",
        "fallback_policy": "forbidden",
    }, "current CLI baseline drifted")

    package = record.get("current_package")
    require(package == {
        "make_target": "phase10-native-package",
        "install_target": "install",
        "artifacts": ["gust", "gust-native-backend", "gust-runtime-package.a"],
        "driver_discovery": "absolute_GUST_NATIVE_BACKEND_DRIVER_then_executable_sibling",
        "path_search": False,
        "auto_build_or_download": False,
    }, "package baseline drifted")

    for surface_name in ("documentation_surfaces", "workflow_surfaces"):
        surfaces = record.get(surface_name)
        require(isinstance(surfaces, list) and surfaces,
                f"{surface_name} is missing")
        for row in surfaces:
            require(all(row.get(field) for field in (
                "id", "path", "current_state", "marker", "owner",
                "expected_transition",
            )), f"{surface_name} row is unclassified: {row!r}")
            path = ROOT / row["path"]
            require(path.is_file() and
                    row["marker"] in path.read_text(encoding="utf-8"),
                    f"{surface_name} marker drifted: {row['id']}")

    rows = scan_invocations()
    summary = scan_summary(rows)
    migration = registry.get("phase22_explicit_c_migration")
    expected_inventories = (
        (
            migration.get("current_invocation_inventory"),
            migration.get("authorized_post_relay_invocation_inventory"),
            registry.get("phase22_default_route_flip", {}).get(
                "post_flip_invocation_inventory"),
        )
        if isinstance(migration, dict)
        else (record.get("invocation_inventory"),)
    )
    require(summary in expected_inventories,
            f"executable compiler invocation inventory drifted: {summary!r}")
    require(summary["unclassified_count"] == 0,
            "an executable compiler invocation is unclassified")
    require(all(row["owner"] and row["expected_artifact"] and
                row["expected_transition"] and row["falsifier"] for row in rows),
            "an executable compiler invocation lacks owner, artifact, transition, or falsifier")

    suite = registry.get("phase21_complete_guard_suite", {})
    classification = suite.get("classification", {})
    handoff = record.get("native_capability_handoff")
    require(handoff == {
        "authority": suite.get("contract_version"),
        "inventory_total": suite.get("inventory", {}).get("total"),
        "required_native_case_count": classification.get("required_native_case_count"),
        "compile_deferral_count": sum(
            classification.get("compile_deferral_reason_counts", {}).values()),
        "oracle_precondition_failure_count":
            classification.get("oracle_precondition_failure_count"),
        "runtime_divergence_count": classification.get("runtime_divergence_count"),
        "default_policy": "unsupported_native_features_fail_clearly_without_C_fallback",
        "cleanup_destination": "22.5_pre_flip_default_cohort_qualification",
    }, "Phase 21 native-capability handoff drifted")

    stability = record.get("stability_qualification")
    require(stability == {
        "operator_decision": "2026-08-29_one_time_exact_final_main",
        "required_successful_runs": 1,
        "workflow": "Cranelift Historical Full",
        "required_head": "exact_merged_final_post_flip_implementation_main",
        "required_job_population": "complete_registry_derived_population_all_success",
        "maximum_unresolved_material_review_findings": 0,
    }, "stability-qualification authority drifted")

    require(record.get("unclassified_failures") == [],
            "Patch 22.1 leaves an unclassified failure")
    boundary = record.get("boundary", {})
    require(boundary and all(value is False for value in boundary.values()),
            "opening evidence widened into implementation")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 22.1 — Opening Default-Route and Consumer Inventory — DONE" in task,
            "TASK.md does not mark Patch 22.1 DONE")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 22.1 guard levels drifted")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in just and f"{GUARD_L2}:" in just,
            "Patch 22.1 just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Level 1 opening guard")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow,
            "dedicated workflow does not own both opening guards")
    require(REVIEW.is_file(), "generated opening review is missing")
    review = REVIEW.read_text(encoding="utf-8")
    inventory = record["invocation_inventory"]
    stable_markers = (
        f"- Contract: `{record['contract_version']}`",
        f"- Observed main: `{record['observed_main_sha']}`",
        f"- Executable compiler invocations: `{inventory['total']}`",
        f"- Unclassified invocations: `{inventory['unclassified_count']}`",
        "## Stability qualification",
        "- Required successful runs: `1`",
        "- Required head: `exact_merged_final_post_flip_implementation_main`",
        "- Maximum unresolved material review findings: `0`",
    )
    require(all(marker in review for marker in stable_markers),
            "frozen generated opening review semantic markers drifted")
    return record


def render(record: dict, rows: list[dict[str, object]]) -> str:
    inventory = record["invocation_inventory"]
    handoff = record["native_capability_handoff"]
    stability = record["stability_qualification"]
    lines = [
        "# Cranelift Phase 22 Opening — Default Route and Consumer Inventory",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` and the live",
        "repository invocation scan by `scripts/phase22_opening.py project`.",
        "Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Observed main: `{record['observed_main_sha']}`",
        f"- Executable compiler invocations: `{inventory['total']}`",
        f"- Unclassified invocations: `{inventory['unclassified_count']}`",
        "",
        "## Current CLI and package",
        "",
        f"- Bare route: `{record['current_cli']['bare_route']}`",
        f"- Bare artifact: `{record['current_cli']['bare_artifact']}`",
        f"- Explicit `mir-to-c`: `{record['current_cli']['explicit_mir_to_c_route']}`",
        f"- Explicit `c`: `{record['current_cli']['explicit_c_alias']}`",
        f"- Cranelift requires `-o`: `{str(record['current_cli']['explicit_cranelift_requires_output']).lower()}`",
        f"- Package artifacts: `{', '.join(record['current_package']['artifacts'])}`",
        "",
        "## Documentation and workflow surfaces",
        "",
    ]
    for row in record["documentation_surfaces"]:
        lines.append(
            f"- `{row['id']}` — `{row['current_state']}`; transition "
            f"`{row['expected_transition']}`"
        )
    for row in record["workflow_surfaces"]:
        lines.append(
            f"- `{row['id']}` — `{row['current_state']}`; transition "
            f"`{row['expected_transition']}`"
        )
    lines += [
        "",
        "## Invocation summary",
        "",
    ]
    for key, value in inventory["selection_counts"].items():
        lines.append(f"- Selection `{key}`: `{value}`")
    for key, value in inventory["consumer_class_counts"].items():
        lines.append(f"- Consumer class `{key}`: `{value}`")
    lines += ["", "## Executable invocation inventory", ""]
    lines.append("| Path | Line | Recipe | Selection | Class | Owner | Expected transition | Falsifier |")
    lines.append("| --- | ---: | --- | --- | --- | --- | --- | --- |")
    for row in rows:
        lines.append(
            f"| `{row['path']}` | {row['line']} | `{row['recipe']}` | "
            f"`{row['selection']}` | `{row['consumer_class']}` | "
            f"`{row['owner']}` | `{row['expected_transition']}` | "
            f"`{row['falsifier']}` |"
        )
    lines += [
        "", "## Phase 21 native-capability handoff", "",
        f"- Complete inventory: `{handoff['inventory_total']}`",
        f"- Required native cases: `{handoff['required_native_case_count']}`",
        f"- Compile deferrals: `{handoff['compile_deferral_count']}`",
        f"- Oracle precondition failures: `{handoff['oracle_precondition_failure_count']}`",
        f"- Runtime divergences: `{handoff['runtime_divergence_count']}`",
        f"- Default policy: `{handoff['default_policy']}`",
        f"- Cleanup destination: `{handoff['cleanup_destination']}`",
        "", "## Stability qualification", "",
        f"- Operator decision: `{stability['operator_decision']}`",
        f"- Required successful runs: `{stability['required_successful_runs']}`",
        f"- Workflow: `{stability['workflow']}`",
        f"- Required head: `{stability['required_head']}`",
        f"- Required job population: `{stability['required_job_population']}`",
        "- Maximum unresolved material review findings: "
        f"`{stability['maximum_unresolved_material_review_findings']}`",
        "",
        "Patch 22.1 changes no route. The invocation inventory is a transition",
        "checklist: Patch 22.2 makes C-dependent consumers explicit while bare",
        "Gust still emits C; later patches own omitted native output, packaging,",
        "the default flip, seed reconvergence, and stability evidence.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=(
        "scan", "validate", "project", "check-review",
    ))
    args = parser.parse_args()
    rows = scan_invocations()
    if args.command == "scan":
        print(json.dumps(scan_summary(rows), indent=2, sort_keys=True))
        return
    record = validate()
    if args.command == "project":
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
        require("phase22_explicit_c_migration" not in registry,
                "opening review is frozen after Patch 22.2 begins")
        REVIEW.write_text(render(record, rows), encoding="utf-8")
    elif args.command == "check-review":
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
        if "phase22_explicit_c_migration" not in registry:
            require(REVIEW.read_text(encoding="utf-8") == render(record, rows),
                    "generated opening review is stale; run project")
    else:
        print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
