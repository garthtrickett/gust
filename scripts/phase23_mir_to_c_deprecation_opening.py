#!/usr/bin/env python3
"""Validate and project Patch 23.7 MIR-to-C consumer inventory evidence."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import re
import subprocess
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE23_MIR_TO_C_DEPRECATION_OPENING.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase23-mir-to-c-deprecation-opening.yml"
GUST = ROOT / "gust"
BASELINE_SOURCE = ROOT / "compiler/phase23_parent_scope_shadow_current.gst"
GUARD_L1 = "guard-cranelift-phase23-mir-to-c-deprecation-opening-contract"
GUARD_L2 = "guard-cranelift-phase23-mir-to-c-deprecation-opening-evidence"

CLASSES = {
    "bootstrap_phase25",
    "focused_live_oracle",
    "archive_candidate",
    "production_or_release_migration",
    "historical_only",
    "unclassified",
}

SELF_EXCLUSIONS = {
    ".github/workflows/phase23-mir-to-c-deprecation-opening.yml",
    "compiler/CRANELIFT_PHASE23_MIR_TO_C_DEPRECATION_OPENING.md",
    "scripts/cranelift_feature_registry.json",
    "scripts/cranelift_feature_registry.schema.json",
    "scripts/phase23_mir_to_c_deprecation_opening.py",
}

SURFACE_PATTERNS = {
    "explicit_backend_spelling": re.compile(
        r"--backend(?:=|\s+)(?:mir-to-c|c)(?:\s|['\"<]|$)|"
        r"(?:backend|backend_name|args\[2\]).{0,80}['\"](?:mir-to-c|c)['\"]"
    ),
    "mir_to_c_name": re.compile(r"MIR-to-C|mir_to_c|mir-to-c"),
    "generated_c_contract": re.compile(
        r"generated[-_ ]C|C_source_on_stdout|Emit C source|"
        r"codegen_generate|gust_(?:stage[0-9]+|compiler)(?:_final)?\.c"
    ),
}

BOOTSTRAP_PATHS = {
    "Makefile",
    "gust_v4.c",
    "compiler/test_runner_bootstrap_bridge_entry.gst",
}

FOCUSED_ORACLE_PATHS = {
    "scripts/phase20_whole_program_corpus.sh",
    "scripts/phase21_cranelift_built_compiler_programs.py",
    "scripts/phase23_resource_acquisition_parity.py",
}

PRODUCTION_PATHS = {
    "README.md",
    "flake.nix",
    "compiler/codegen.gst",
    "compiler/test_runner_entry.gst",
    "compiler/experiments/cranelift/README.md",
    "docs/CRANELIFT_LAUNCH.md",
    "docs/MOBILE_NATIVE_DEPLOYMENT.md",
    "docs/ONE_WAY_LEDGER.md",
    "scripts/run-gust-file.sh",
}

STRUCTURAL_SURFACES = [
    {
        "id": "cli_explicit_c_spellings",
        "path": "compiler/test_runner_entry.gst",
        "surface": "parser_help_and_shared_generated_C_entry",
        "classification": "production_or_release_migration",
        "owner": "cranelift",
        "current_route": "explicit_mir_to_c_and_c_to_codegen_generate_stdout",
        "deprecation_action": "mark_deprecated_in_23_8_preserve_until_24",
        "removal_phase": "24",
        "falsifier": "either_spelling_parser_help_or_shared_codegen_entry_is_missing",
    },
    {
        "id": "bootstrap_bridge",
        "path": "compiler/test_runner_bootstrap_bridge_entry.gst",
        "surface": "bootstrap_only_explicit_C_parser_and_codegen_entry",
        "classification": "bootstrap_phase25",
        "owner": "cranelift",
        "current_route": "explicit_mir_to_c_or_c_to_stage_one_C_stdout",
        "deprecation_action": "preserve_through_phase24",
        "removal_phase": "25",
        "falsifier": "bootstrap_bridge_route_or_phase25_owner_is_missing",
    },
    {
        "id": "generated_c_implementation",
        "path": "compiler/codegen.gst",
        "surface": "self_hosted_AST_and_canonical_MIR_to_C_generation",
        "classification": "production_or_release_migration",
        "owner": "cranelift",
        "current_route": "called_only_by_explicit_C_frontend_and_bootstrap_bridge",
        "deprecation_action": "freeze_in_23_9_remove_active_backend_in_24",
        "removal_phase": "24",
        "falsifier": "generated_C_entry_or_caller_identity_changes_without_successor",
    },
    {
        "id": "accepted_capability_registry",
        "path": "scripts/cranelift_feature_registry.json",
        "surface": "accepted_capabilities_fixtures_routes_and_evidence_authority",
        "classification": "archive_candidate",
        "owner": "cranelift",
        "current_route": "registered_feature_and_differential_population",
        "deprecation_action": "freeze_exact_accepted_C_surface_in_23_9",
        "removal_phase": "24",
        "falsifier": "accepted_capability_is_added_omitted_or_name_substituted",
    },
    {
        "id": "bootstrap_seed",
        "path": "gust_v4.c",
        "surface": "committed_converged_C_seed",
        "classification": "bootstrap_phase25",
        "owner": "cranelift",
        "current_route": "host_C_stage_zero_seed",
        "deprecation_action": "preserve_and_reconverge_only_in_seed_patches",
        "removal_phase": "25",
        "falsifier": "seed_is_removed_or_reclassified_during_phase23_or_24",
    },
    {
        "id": "bootstrap_build_graph",
        "path": "Makefile",
        "surface": "make_gust_and_make_bootstrap_generated_C_chain",
        "classification": "bootstrap_phase25",
        "owner": "cranelift",
        "current_route": "explicit_mir_to_c_stage_generation_plus_host_C",
        "deprecation_action": "preserve_exact_bootstrap_selection",
        "removal_phase": "25",
        "falsifier": "bootstrap_uses_default_or_native_route_before_phase25",
    },
    {
        "id": "retained_c_runtime_aggregate",
        "path": "src/runtime.c",
        "surface": "aggregate_C_runtime_concatenated_into_bootstrap_and_generated_C",
        "classification": "bootstrap_phase25",
        "owner": "cranelift",
        "current_route": "host_C_runtime_aggregate",
        "deprecation_action": "preserve_as_bootstrap_runtime_dependency",
        "removal_phase": "25_or_later_explicit_runtime_policy",
        "falsifier": "backend_retirement_is_misstated_as_repository_wide_C_removal",
    },
    {
        "id": "retained_c_runtime_modules",
        "path": "src/runtime/",
        "surface": "C_runtime_sources_headers_and_symbols",
        "classification": "bootstrap_phase25",
        "owner": "cranelift",
        "current_route": "runtime_archive_and_host_C_link_inputs",
        "deprecation_action": "preserve_and_audit_separately_from_generated_C_backend",
        "removal_phase": "25_or_later_explicit_runtime_policy",
        "falsifier": "runtime_C_is_silently_claimed_removed_by_backend_deprecation",
    },
    {
        "id": "generated_c_stdout",
        "path": "stdout",
        "surface": "explicit_C_user_output_artifact",
        "classification": "production_or_release_migration",
        "owner": "cranelift",
        "current_route": "explicit_mir_to_c_and_c_emit_C_bytes_to_stdout",
        "deprecation_action": "retain_frozen_bytes_through_phase23",
        "removal_phase": "24",
        "falsifier": "explicit_aliases_emit_different_or_empty_bytes",
    },
    {
        "id": "generated_program_c",
        "path": "build/guards/**/oracle.c",
        "surface": "focused_differential_generated_C_artifact",
        "classification": "focused_live_oracle",
        "owner": "cranelift",
        "current_route": "explicit_C_compile_link_execute_oracle",
        "deprecation_action": "consolidate_to_one_live_lane_in_23_10",
        "removal_phase": "24",
        "falsifier": "live_oracle_artifact_is_unowned_empty_or_implicit",
    },
    {
        "id": "generated_compiler_c",
        "path": "build/gust_compiler.c",
        "surface": "make_gust_generated_compiler_C",
        "classification": "bootstrap_phase25",
        "owner": "cranelift",
        "current_route": "explicit_mir_to_c_stage_one_compiler_output",
        "deprecation_action": "preserve_until_native_bootstrap_authority",
        "removal_phase": "25",
        "falsifier": "bootstrap_generated_compiler_artifact_loses_phase25_owner",
    },
    {
        "id": "bootstrap_stage_c",
        "path": "build/gust_stage{1,2,3}*.c",
        "surface": "bootstrap_generated_C_and_runtime_concatenation_artifacts",
        "classification": "bootstrap_phase25",
        "owner": "cranelift",
        "current_route": "explicit_mir_to_c_fixed_point_then_host_C",
        "deprecation_action": "preserve_stage2_stage3_byte_identity",
        "removal_phase": "25",
        "falsifier": "stage_artifacts_are_removed_or_rerouted_before_phase25",
    },
    {
        "id": "temporary_c_outputs",
        "path": "build/guards/**/*.c and /tmp/gust-*.mir-to-c.*",
        "surface": "guard_local_generated_C_and_witness_temporary_files",
        "classification": "archive_candidate",
        "owner": "cranelift",
        "current_route": "explicit_C_guard_evidence",
        "deprecation_action": "archive_or_consolidate_in_23_10_and_23_11",
        "removal_phase": "24",
        "falsifier": "temporary_C_or_witness_producer_is_absent_from_text_or_invocation_inventory",
    },
    {
        "id": "native_runtime_package",
        "path": "build/gust-runtime-package.a",
        "surface": "retained_runtime_archive_for_native_linking",
        "classification": "production_or_release_migration",
        "owner": "cranelift",
        "current_route": "Cranelift_native_link_input_not_generated_C_backend_output",
        "deprecation_action": "preserve_and_distinguish_from_backend_C",
        "removal_phase": "not_scheduled_by_phase23_or_24",
        "falsifier": "native_package_is_incorrectly_classified_as_MIR_to_C_output",
    },
    {
        "id": "installed_native_package",
        "path": "$(PREFIX)/bin/{gust,gust-native-backend,gust-runtime-package.a}",
        "surface": "supported_install_and_relocation_unit",
        "classification": "production_or_release_migration",
        "owner": "cranelift",
        "current_route": "default_and_explicit_CLI_with_native_sibling_driver",
        "deprecation_action": "audit_no_production_C_dependency_in_23_12",
        "removal_phase": "explicit_C_route_24_bootstrap_25",
        "falsifier": "installed_default_or_explicit_native_requires_MIR_to_C",
    },
]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def digest_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def canonical_digest(value: object) -> str:
    encoded = json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=True
    ).encode("utf-8")
    return digest_bytes(encoded)


def opening_module():
    path = ROOT / "scripts/phase22_opening.py"
    spec = importlib.util.spec_from_file_location("phase22_opening", path)
    require(spec is not None and spec.loader is not None,
            "cannot load the Phase 22 invocation scanner")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def tracked_paths() -> list[str]:
    result = subprocess.run(
        ("git", "ls-files", "-z"), cwd=ROOT, check=True,
        stdout=subprocess.PIPE,
    )
    return sorted(item for item in result.stdout.decode().split("\0") if item)


def classify_surface(path: str) -> tuple[str, str, str, str]:
    if path in BOOTSTRAP_PATHS:
        return (
            "bootstrap_phase25", "preserve_exact_C_bootstrap_dependency",
            "25", "bootstrap_surface_is_missing_changed_or_reclassified",
        )
    if path in FOCUSED_ORACLE_PATHS:
        return (
            "focused_live_oracle", "candidate_for_single_live_lane_in_23_10",
            "24", "focused_oracle_candidate_is_missing_or_changes_identity",
        )
    if path in PRODUCTION_PATHS:
        return (
            "production_or_release_migration",
            "deprecate_or_migrate_under_23_8_and_23_12",
            "24_or_25_as_registered",
            "production_or_release_surface_is_missing_or_changes_identity",
        )
    if (path.startswith("docs/PHASE") or
            path.startswith("compiler/CRANELIFT_PHASE") or
            path.startswith("compiler/MIR_FEATURE_MIGRATION") or
            path.startswith("compiler/MIR_AST_TO_C_RETIREMENT")):
        return (
            "historical_only", "preserve_as_historical_evidence",
            "not_removed_by_phase23",
            "historical_record_is_reclassified_as_live_support",
        )
    if path.startswith("docs/") or path in {"TASK.md", "TASK_STDLIB.md", "GEMINI.md", "AGENTS.md"}:
        return (
            "production_or_release_migration",
            "review_claims_in_23_8_and_23_12",
            "24_or_25_as_claim_requires",
            "live_documentation_claim_is_missing_or_changes_identity",
        )
    return (
        "archive_candidate", "map_to_live_lane_or_archive_in_23_10_and_23_11",
        "24", "active_evidence_surface_is_missing_or_changes_identity",
    )


def owner_for_path(path: str) -> str:
    if (path == "TASK_STDLIB.md" or path.startswith("tests/") or
            path.startswith("scripts/stdlib_") or
            path.startswith(".github/workflows/stdlib-")):
        return "stdlib"
    return "cranelift"


def scan_text_surfaces() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for path in tracked_paths():
        if path in SELF_EXCLUSIONS:
            continue
        absolute = ROOT / path
        try:
            raw = absolute.read_bytes()
            text = raw.decode("utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        matches = {
            name: len(pattern.findall(text))
            for name, pattern in SURFACE_PATTERNS.items()
        }
        if not any(matches.values()):
            continue
        classification, action, removal, falsifier = classify_surface(path)
        rows.append({
            "path": path,
            "digest": digest_bytes(raw),
            "match_counts": matches,
            "classification": classification,
            "owner": owner_for_path(path),
            "current_route": "tracked_MIR_to_C_or_generated_C_surface",
            "deprecation_action": action,
            "removal_phase": removal,
            "falsifier": falsifier,
        })
    return rows


def scan_invocations() -> list[dict[str, object]]:
    rows = opening_module().scan_invocations()
    return [
        {
            "path": row["path"],
            "line": row["line"],
            "recipe": row["recipe"],
            "compiler_token": row["compiler_token"],
            "selection": row["selection"],
            "consumer_class": row["consumer_class"],
            "owner": row["owner"],
            "command": row["command"],
        }
        for row in rows
    ]


def inventory_summary() -> dict[str, object]:
    text_rows = scan_text_surfaces()
    invocation_rows = scan_invocations()
    structural_rows = copy.deepcopy(STRUCTURAL_SURFACES)
    classes = Counter(str(row["classification"]) for row in text_rows)
    classes.update(str(row["classification"]) for row in structural_rows)
    selections = Counter(str(row["selection"]) for row in invocation_rows)
    return {
        "text_surface_count": len(text_rows),
        "text_surface_manifest_digest": canonical_digest(text_rows),
        "invocation_count": len(invocation_rows),
        "invocation_manifest_digest": canonical_digest(invocation_rows),
        "structural_surface_count": len(structural_rows),
        "structural_manifest_digest": canonical_digest(structural_rows),
        "classification_counts": dict(sorted(classes.items())),
        "invocation_selection_counts": dict(sorted(selections.items())),
        "unclassified_count": classes.get("unclassified", 0),
    }


def validate_identity_falsifiers(expected: dict[str, object]) -> None:
    text_rows = scan_text_surfaces()
    invocation_rows = scan_invocations()
    require(len(text_rows) > 1 and len(invocation_rows) > 1,
            "inventory is too small for identity falsifiers")
    omitted = text_rows[1:]
    require(canonical_digest(omitted) != expected["text_surface_manifest_digest"],
            "partial text inventory was accepted")
    substituted = copy.deepcopy(text_rows)
    substituted[0]["path"] = str(substituted[0]["path"]) + ".substituted"
    require(canonical_digest(substituted) != expected["text_surface_manifest_digest"],
            "same-count text path substitution was accepted")
    command_substitution = copy.deepcopy(invocation_rows)
    command_substitution[0]["command"] = str(command_substitution[0]["command"]) + " --substituted"
    require(canonical_digest(command_substitution) != expected["invocation_manifest_digest"],
            "same-count invocation command substitution was accepted")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase23_mir_to_c_deprecation_opening")
    require(isinstance(record, dict), "Patch 23.7 authority is missing")
    require(record.get("contract_version") == "phase23_mir_to_c_deprecation_opening_v1",
            "contract version drifted")
    require(record.get("status") == "patch23_7_complete" and
            record.get("next_patch") == "23.8",
            "status or next patch drifted")
    require(record.get("observed_main_sha") ==
            "f328b30d107467811f8eabfd1dc14e17136187f1",
            "opening main identity drifted")
    require(record.get("classifications") == sorted(CLASSES),
            "classification vocabulary drifted")
    require(record.get("inventory") == inventory_summary(),
            "live MIR-to-C consumer inventory drifted")
    require(record["inventory"]["unclassified_count"] == 0,
            "consumer or artifact remains unclassified")
    validate_identity_falsifiers(record["inventory"])

    structural = record.get("structural_surfaces")
    require(structural == STRUCTURAL_SURFACES,
            "structural consumer/artifact inventory drifted")
    for row in scan_text_surfaces() + structural:
        require(row.get("classification") in CLASSES - {"unclassified"} and
                row.get("owner") and row.get("current_route") and
                row.get("deprecation_action") and row.get("removal_phase") and
                row.get("falsifier"),
                f"inventory row is incomplete: {row!r}")

    for key in ("phase23_mir_evidence_owner", "phase23_resource_acquisition_parity",
                "phase23_same_scope_declaration"):
        closure = registry.get(key, {}).get("issue_closure", {})
        require(closure.get("state") == "closed_after_merged_current_main_validation" and
                closure.get("issue_state") == "closed",
                f"mandatory predecessor issue is not closed: {key}")
    task = TASK.read_text(encoding="utf-8")
    for patch in ("23.2", "23.3", "23.4", "23.5", "23.6", "23.6a"):
        require(re.search(rf"^- \[x\] Patch {re.escape(patch)} .* — DONE$", task, re.M) is not None,
                f"mandatory predecessor Patch {patch} is not DONE")
    require("- [x] Patch 23.7 — MIR-to-C Deprecation Opening and Consumer Inventory — DONE" in task,
            "TASK.md does not mark Patch 23.7 DONE")

    baseline = record.get("pre_deprecation_baseline", {})
    require(baseline.get("source") == BASELINE_SOURCE.relative_to(ROOT).as_posix() and
            baseline.get("source_digest") == digest_bytes(BASELINE_SOURCE.read_bytes()) and
            baseline.get("mir_to_c") == baseline.get("c_alias") and
            baseline.get("mir_to_c", {}).get("compile_status") == 0 and
            baseline.get("mir_to_c", {}).get("stdout_size", 0) > 0 and
            baseline.get("mir_to_c", {}).get("stderr_size") == 0,
            "pre-deprecation explicit-C bytes or observables drifted")
    require(record.get("boundary") == {
        "changes_backend_route_or_presentation": False,
        "changes_accepted_Gust_program_meaning": False,
        "adds_or_changes_MIR_operations": False,
        "changes_ABI_layout_runtime_symbols_target_or_linker": False,
        "changes_bootstrap_route_or_seed": False,
        "edits_stdlib_or_CR15": False,
        "begins_patch23_8": False,
    }, "Patch 23.7 boundary drifted")

    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 23.7 guard levels drifted")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in just and f"{GUARD_L2}:" in just,
            "Patch 23.7 just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Patch 23.7 contract")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow,
            "dedicated workflow does not own both guards")
    for path_filter in ("'compiler/**'", "'scripts/**'", "'src/**'", "'gust_v4.c'", "'justfile*'"):
        require(workflow.count(path_filter) == 2,
                f"workflow does not own both path filters for {path_filter}")
    require(REVIEW.is_file() and REVIEW.read_text(encoding="utf-8") == render(record),
            "generated opening review is stale; run project")
    return record


def compile_baseline(backend: str) -> dict[str, object]:
    result = subprocess.run(
        (str(GUST), "--backend", backend, str(BASELINE_SOURCE.relative_to(ROOT))),
        cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        timeout=180, check=False,
    )
    return {
        "compile_status": result.returncode,
        "stdout_size": len(result.stdout),
        "stdout_digest": digest_bytes(result.stdout),
        "stderr_size": len(result.stderr),
        "stderr_digest": digest_bytes(result.stderr),
    }


def evidence(record: dict) -> None:
    require(GUST.is_file(), "gust is missing; run make gust")
    mir_to_c = compile_baseline("mir-to-c")
    c_alias = compile_baseline("c")
    require(mir_to_c == c_alias == record["pre_deprecation_baseline"]["mir_to_c"],
            "pre-deprecation explicit-C aliases or bytes drifted")
    print("phase23_mir_to_c_deprecation_opening: evidence ok")


def render(record: dict) -> str:
    inventory = record["inventory"]
    baseline = record["pre_deprecation_baseline"]
    lines = [
        "# Cranelift Phase 23.7 — MIR-to-C Deprecation Opening",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` and live",
        "repository scans by `scripts/phase23_mir_to_c_deprecation_opening.py`.",
        "Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Observed main: `{record['observed_main_sha']}`",
        f"- Text surfaces: `{inventory['text_surface_count']}`",
        f"- Text manifest: `{inventory['text_surface_manifest_digest']}`",
        f"- Executable compiler invocations: `{inventory['invocation_count']}`",
        f"- Invocation manifest: `{inventory['invocation_manifest_digest']}`",
        f"- Structural surfaces: `{inventory['structural_surface_count']}`",
        f"- Structural manifest: `{inventory['structural_manifest_digest']}`",
        f"- Unclassified: `{inventory['unclassified_count']}`",
        "",
        "## Classification summary",
        "",
    ]
    for name, count in inventory["classification_counts"].items():
        lines.append(f"- `{name}`: `{count}`")
    lines += ["", "## Explicit-C invocation summary", ""]
    for name, count in inventory["invocation_selection_counts"].items():
        lines.append(f"- `{name}`: `{count}`")
    lines += [
        "", "## Pre-deprecation byte baseline", "",
        f"- Source: `{baseline['source']}`",
        f"- Source digest: `{baseline['source_digest']}`",
        f"- Generated C bytes: `{baseline['mir_to_c']['stdout_size']}`",
        f"- Generated C digest: `{baseline['mir_to_c']['stdout_digest']}`",
        f"- Stderr bytes: `{baseline['mir_to_c']['stderr_size']}`",
        "- `mir-to-c` and `c` observables: `byte_identical`",
        "", "## Structural consumer and artifact inventory", "",
        "| ID | Surface | Class | Owner | Current route | Action | Removal | Falsifier |",
        "| --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for row in record["structural_surfaces"]:
        lines.append(
            f"| `{row['id']}` | `{row['path']}` | `{row['classification']}` | "
            f"`{row['owner']}` | `{row['current_route']}` | "
            f"`{row['deprecation_action']}` | `{row['removal_phase']}` | "
            f"`{row['falsifier']}` |"
        )
    lines += [
        "", "## Tracked textual surface inventory", "",
        "| Path | Digest | Matches | Class | Owner | Action | Removal | Falsifier |",
        "| --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for row in scan_text_surfaces():
        matches = ", ".join(
            f"{key}={value}" for key, value in row["match_counts"].items()
        )
        lines.append(
            f"| `{row['path']}` | `{row['digest']}` | `{matches}` | "
            f"`{row['classification']}` | `{row['owner']}` | "
            f"`{row['deprecation_action']}` | `{row['removal_phase']}` | "
            f"`{row['falsifier']}` |"
        )
    lines += [
        "",
        "Patch 23.7 changes no backend route or presentation. Its manifests",
        "freeze the opening population so later Phase 23 patches must record an",
        "explicit successor when they intentionally migrate or archive a surface.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=(
        "scan", "validate", "project", "check-review", "evidence",
    ))
    args = parser.parse_args()
    if args.command == "scan":
        print(json.dumps(inventory_summary(), indent=2, sort_keys=True))
        return
    if args.command == "project":
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
        record = registry.get("phase23_mir_to_c_deprecation_opening")
        require(isinstance(record, dict), "Patch 23.7 authority is missing")
        REVIEW.write_text(render(record), encoding="utf-8")
        validate()
        print(f"{GUARD_L1}: project ok")
        return
    record = validate()
    if args.command == "evidence":
        evidence(record)
    else:
        print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
