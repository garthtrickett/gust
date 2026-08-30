#!/usr/bin/env python3
"""Validate and project Patch 22.1 default-route opening evidence."""

from __future__ import annotations

import argparse
import ast
import copy
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
            relative.startswith("tests/") or
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
    elif relative.startswith("tests/"):
        consumer_class = "stdlib_owned_C_or_diagnostic_guard"
        owner = "stdlib"
        expected_artifact = "generated_C_or_diagnostic"
        transition = "checked_cross_lane_relay_after_postmerge_review"
        falsifier = "default_native_route_reaches_a_test_owned_generated_C_consumer"
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
    files.extend(sorted(ROOT.glob("*.sh")))
    files.extend(sorted((ROOT / "scripts").glob("*.sh")))
    files.extend(sorted((ROOT / "tests").glob("*.gst")))
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


def phase22_relay_inventory_rows(
        registry: dict, rows: list[dict[str, object]]) -> list[dict[str, object]]:
    """Keep Phase 22's closed relay identity while validating exact successors."""
    successors = [
        registry.get("phase23_issue_health_opening", {}).get(
            "phase22_closed_inventory_successor", {}),
        registry.get("phase23_structured_guard_defer_native_admission", {}).get(
            "phase22_closed_inventory_extension", {}),
    ]
    expected_authorities = [
        ("23.1", "scripts/phase23_issue_health_opening.py", ["explicit_c"], 2),
        ("23.3a", "scripts/phase23_structured_guard_defer_native_admission.py",
         ["explicit_c", "explicit_cranelift", "explicit_cranelift"], 3),
    ]
    excluded: list[dict[str, object]] = []
    for successor, expected_authority in zip(successors, expected_authorities):
        patch, path, selections, count = expected_authority
        require(successor.get("status") ==
                "exact_phase23_extension_excluded_only_from_phase22_relay_identity" and
                successor.get("owning_patch") == patch and
                successor.get("path") == path and
                successor.get("selection") == (selections[0] if len(selections) == 1 else selections) and
                successor.get("invocation_count") == count,
                "Phase 23 successor invocation authority drifted")
        expected_selections = selections * count if len(selections) == 1 else selections
        expected = [
            (path, command, selection)
            for command, selection in zip(
                successor.get("commands", []), expected_selections
            )
        ]
        live_successors = [row for row in rows if row["path"] == path]
        live = [
            (str(row["path"]), str(row["command"]), str(row["selection"]))
            for row in live_successors
        ]
        require(len(expected) == len(live_successors) == count and live == expected,
                "Phase 23 successor invocation path, command, or selection drifted")
        excluded.extend(live_successors)
    return [row for row in rows if row not in excluded]


def validate_post_flip_relay_transition(
        registry: dict, rows: list[dict[str, object]]) -> tuple[str, dict]:
    """Require the exact landed six-site post-relay state."""
    rows = phase22_relay_inventory_rows(registry, rows)
    migration = registry.get("phase22_explicit_c_migration", {})
    relay = migration.get("cross_lane_relay", {}).get(
        "post_flip_review_relay", {})
    landed_authority = relay.get("landed_authority", {})
    require(landed_authority.get("status") ==
            "exact_post_relay_only" and
            landed_authority.get("owning_pull_request") == 264 and
            landed_authority.get("changed_path_count") == 2 and
            landed_authority.get("route_only_replacement_count") == 6 and
            landed_authority.get("changed_paths") == relay.get("paths"),
            "landed six-site relay authority drifted")
    landed = relay.get("landed_merge_evidence", {})
    require(landed == {
        "status": "merged_on_main",
        "owning_pull_request": 264,
        "base_sha": "5638c3596be450b75f2af905b982875f7863bc37",
        "exact_head_sha": "3ada756e209bfa0556895169870ae00f96d94022",
        "merged_main_sha": "a7adbcd186512a3b4fd99b953bb2bc30f6838c52",
        "pull_request_event": "pull_request",
        "successful_workflows": 6,
        "total_workflows": 6,
        "unfinished_workflows": 0,
        "non_success_workflows": 0,
        "unresolved_review_threads": 0,
        "relayed_review_thread": "PRRT_kwDOS1ExJc6dYPJO",
        "relayed_review_thread_status": "resolved_non_outdated",
    }, "landed relay merge evidence drifted")

    site_fields = ("path", "line", "recipe", "compiler_token", "command")
    expected_sites = {
        tuple(site[field] for field in site_fields)
        for site in relay.get("site_manifest", [])
    }
    live_sites = {
        tuple(row[field] for field in site_fields): row
        for row in rows
        if tuple(row[field] for field in site_fields) in expected_sites
    }
    require(len(expected_sites) == len(live_sites) ==
            relay.get("consumer_count") == 6 and
            sorted({str(site[0]) for site in expected_sites}) ==
            relay.get("paths"),
            "six-site relay path or site manifest drifted")

    summary = scan_summary(rows)
    require({str(row["selection"]) for row in live_sites.values()} ==
            {"explicit_c"} and
            summary == landed_authority.get("exact_invocation_inventory"),
            "live invocation scan is not the exact landed six-site post-relay state")
    return "landed_post_relay", landed_authority


def transition_projection_rows(
        rows: list[dict[str, object]], registry: dict) -> list[dict[str, object]]:
    """Return the landed generated projection for the exact relay."""
    relay = registry["phase22_explicit_c_migration"]["cross_lane_relay"][
        "post_flip_review_relay"
    ]
    site_fields = ("path", "line", "recipe", "compiler_token", "command")
    expected_sites = {
        tuple(site[field] for field in site_fields)
        for site in relay["site_manifest"]
    }
    projected: list[dict[str, object]] = []
    for row in rows:
        copy = dict(row)
        key = tuple(copy[field] for field in site_fields)
        if key in expected_sites:
            copy.update({
                "selection": "explicit_c",
                "consumer_class": "landed_six_site_stdlib_C_or_diagnostic_relay",
                "owner": "stdlib",
                "expected_artifact": "generated_C_or_diagnostic",
                "expected_transition": "exact_six_site_explicit_mir_to_c_relay",
                "falsifier": "partial_extra_path_drift_or_unrelated_inventory_change",
            })
        projected.append(copy)
    return projected


def validate_landed_relay_command_substitution_rejection(
        registry: dict, rows: list[dict[str, object]]) -> None:
    """Prove same-selection changes cannot bypass the landed command manifest."""
    substitutions = (
        ("codegen_helper_pod_move.gst", "codegen_helper_linear_move.gst"),
        ("--backend mir-to-c", "--backend c"),
        ("2>&1", "2>/dev/null"),
    )
    for old, new in substitutions:
        probe = copy.deepcopy(rows)
        target = next(
            row for row in probe
            if row["path"] == "tests/e2e_codegen_assertions.gst" and
            row["line"] == 33
        )
        target["command"] = str(target["command"]).replace(old, new)
        try:
            validate_post_flip_relay_transition(registry, probe)
        except SystemExit:
            continue
        require(False,
                f"landed relay command substitution was accepted: {old}")


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

    postflip = registry.get("phase22_postflip_qualification", {})
    postflip_complete = (
        postflip.get("contract_version") ==
        "phase22_postflip_qualification_v1" and
        postflip.get("status") == "qualification_complete"
    )
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
            marker_present = (path.is_file() and
                              row["marker"] in path.read_text(encoding="utf-8"))
            transitioned_by_postflip = (
                postflip_complete and
                "22.7" in row["expected_transition"]
            )
            require(marker_present or transitioned_by_postflip,
                    f"{surface_name} marker drifted: {row['id']}")

    live_rows = scan_invocations()
    rows = phase22_relay_inventory_rows(registry, live_rows)
    summary = scan_summary(rows)
    migration = registry.get("phase22_explicit_c_migration")
    require(isinstance(migration, dict),
            "explicit-C migration authority is missing")
    validate_post_flip_relay_transition(registry, live_rows)
    validate_landed_relay_command_substitution_rejection(registry, live_rows)
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
    for path_filter in ("'reset-heavy-guards-workflow.sh'", "'tests/*.gst'",
                        "'justfile*'"):
        require(workflow.count(path_filter) == 2,
                f"dedicated workflow does not own both path filters for {path_filter}")
    require(REVIEW.is_file(), "generated opening review is missing")
    review = REVIEW.read_text(encoding="utf-8")
    inventory = scan_summary(rows)
    stable_markers = (
        f"- Contract: `{record['contract_version']}`",
        f"- Observed main: `{record['observed_main_sha']}`",
        f"- Live successor executable compiler invocations: `{inventory['total']}`",
        f"- Unclassified invocations: `{inventory['unclassified_count']}`",
        "- Relay state: `exact_post_relay_only`",
        "## Stability qualification",
        "- Required successful runs: `1`",
        "- Required head: `exact_merged_final_post_flip_implementation_main`",
        "- Maximum unresolved material review findings: `0`",
    )
    require(all(marker in review for marker in stable_markers),
            "frozen generated opening review semantic markers drifted")
    require(review == render(record, live_rows, registry),
            "generated opening review is stale")
    return record


def render(record: dict, rows: list[dict[str, object]], registry: dict) -> str:
    live_rows = rows
    rows = phase22_relay_inventory_rows(registry, live_rows)
    opening_inventory = record["invocation_inventory"]
    _, landed_authority = validate_post_flip_relay_transition(registry, live_rows)
    inventory = landed_authority["exact_invocation_inventory"]
    projected_rows = transition_projection_rows(rows, registry)
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
        f"- Opening-baseline executable compiler invocations: `{opening_inventory['total']}`",
        f"- Live successor executable compiler invocations: `{inventory['total']}`",
        f"- Unclassified invocations: `{inventory['unclassified_count']}`",
        f"- Relay state: `{landed_authority['status']}`",
        f"- Landed owning PR: `#{landed_authority['owning_pull_request']}`",
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
        "## Landed successor invocation summary",
        "",
    ]
    for key, value in inventory["selection_counts"].items():
        lines.append(f"- Landed selection `{key}`: `{value}`")
    for key, value in inventory["consumer_class_counts"].items():
        lines.append(f"- Landed consumer class `{key}`: `{value}`")
    lines += ["", "## Landed exact relay commands", ""]
    relay = registry["phase22_explicit_c_migration"]["cross_lane_relay"][
        "post_flip_review_relay"
    ]
    for site in relay["site_manifest"]:
        lines.append(
            f"- `{site['path']}:{site['line']}` — `{site['command']}`"
        )
    lines += ["", "## Landed successor executable invocation inventory", ""]
    lines.append("| Path | Line | Recipe | Selection | Class | Owner | Expected artifact | Expected transition | Falsifier |")
    lines.append("| --- | ---: | --- | --- | --- | --- | --- | --- | --- |")
    for row in projected_rows:
        lines.append(
            f"| `{row['path']}` | {row['line']} | `{row['recipe']}` | "
            f"`{row['selection']}` | `{row['consumer_class']}` | "
            f"`{row['owner']}` | `{row['expected_artifact']}` | "
            f"`{row['expected_transition']}` | "
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
    if args.command == "project":
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
        record = registry.get("phase22_opening")
        require(isinstance(record, dict), "Patch 22.1 authority is missing")
        REVIEW.write_text(render(record, rows, registry), encoding="utf-8")
        validate()
        print(f"{GUARD_L1}: project ok")
        return
    record = validate()
    if args.command == "check-review":
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
        require(REVIEW.read_text(encoding="utf-8") ==
                render(record, rows, registry),
                "generated opening review is stale; run project")
    else:
        print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
