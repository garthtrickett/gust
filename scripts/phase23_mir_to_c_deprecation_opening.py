#!/usr/bin/env python3
"""Validate and project Patch 23.7 MIR-to-C consumer inventory evidence."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import os
import re
import subprocess
import tempfile
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
NATIVE_IDENTITY_SOURCE = ROOT / "compiler/phase10_scalar_return_source.gst"
ENTRY = ROOT / "compiler/test_runner_entry.gst"
HELP = ROOT / "compiler/phase10_help.txt"
README = ROOT / "README.md"
SEED = ROOT / "gust_v4.c"
PACKAGED_GUST = ROOT / "build/phase10-package/bin/gust"
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
    ".github/workflows/phase23-mir-to-c-frozen-surface.yml",
    ".github/workflows/phase23-mir-to-c-focused-live.yml",
    ".github/workflows/phase23-mir-to-c-archived-corpus.yml",
    ".github/workflows/phase23-production-release-audit.yml",
    ".github/workflows/phase23-cross-feature-qualification.yml",
    "compiler/CRANELIFT_PHASE23_MIR_TO_C_DEPRECATION_OPENING.md",
    "compiler/CRANELIFT_PHASE23_MIR_TO_C_FROZEN_SURFACE.md",
    "compiler/CRANELIFT_PHASE23_MIR_TO_C_FOCUSED_LIVE.md",
    "compiler/CRANELIFT_PHASE23_MIR_TO_C_ARCHIVED_CORPUS.md",
    "compiler/CRANELIFT_PHASE23_PRODUCTION_RELEASE_AUDIT.md",
    "compiler/CRANELIFT_PHASE23_CROSS_FEATURE_QUALIFICATION.md",
    "compiler/fixtures/phase23_mir_to_c_reference_corpus_v1.json",
    "scripts/cranelift_feature_registry.json",
    "scripts/cranelift_feature_registry.schema.json",
    "scripts/phase23_mir_to_c_deprecation_opening.py",
    "scripts/phase23_mir_to_c_frozen_surface.py",
    "scripts/phase23_mir_to_c_focused_live.py",
    "scripts/phase23_mir_to_c_archived_corpus.py",
    "scripts/phase23_production_release_audit.py",
    "scripts/phase23_production_release_audit.sh",
    "scripts/phase23_cross_feature_qualification.py",
    ".github/workflows/phase24-cr15-stdlib-guard-transition.yml",
    "compiler/CRANELIFT_PHASE24_CR15_STDLIB_GUARD_TRANSITION.md",
    "scripts/phase24_cr15_stdlib_guard_transition.py",
    ".github/workflows/phase24-cr15-qualification.yml",
    "compiler/CRANELIFT_PHASE24_CR15_QUALIFICATION.md",
    "scripts/phase24_cr15_qualification.py",
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
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    if "stdlib_guard_transition" not in registry.get("phase24_cr15_opening", {}):
        return rows
    path = ROOT / "scripts/phase24_cr15_stdlib_guard_transition.py"
    spec = importlib.util.spec_from_file_location("phase24_cr15_guard_transition", path)
    require(spec is not None and spec.loader is not None,
            "cannot load the Patch 24.0c guard transition")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.normalize_phase23_text_surfaces(registry, rows)


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


def validate_phase24_cr15_seed_publication_transition(
        registry: dict, live_inventory: dict, live_rows: list[dict]) -> dict:
    authority = registry.get("phase24_cr15_seed_authority_consumer_transition", {})
    transition = authority.get("seed_publication_transition", {})
    authority_paths = ["scripts/phase23_closure.py"]
    seed_path = "gust_v4.c"
    unchanged_fields = [
        "text_surface_count", "invocation_count", "invocation_manifest_digest",
        "structural_surface_count", "structural_manifest_digest",
        "classification_counts", "invocation_selection_counts",
        "unclassified_count",
    ]
    states = transition.get("accepted_live_states", [])
    require(
        transition.get("contract_version") ==
        "phase24_cr15_seed_publication_consumer_transition_v1" and
        transition.get("status") == "ready_for_seed_publication" and
        transition.get("authority_base_main") ==
        "f1da52fdd0211414017d160d5bd55a2f12748530" and
        transition.get("previous_inventory") == authority.get("current_inventory") and
        transition.get("registered_authority_changed_paths") == authority_paths and
        transition.get("seed_path") == seed_path and
        transition.get("unchanged_fields") == unchanged_fields and
        transition.get("partial_extra_or_substituted_surface") == "rejected" and
        [row.get("state") for row in states] ==
        ["pre_publication", "post_publication"],
        "Patch 24.0e CR-15 seed publication transition drifted")
    previous_authority_rows = transition.get(
        "previous_authority_text_surfaces", [])
    current_authority_rows = transition.get(
        "current_authority_text_surfaces", [])
    live_authority_rows = [row for row in live_rows
                           if row["path"] in authority_paths]
    parent_authority_rows = [
        row for row in authority.get("current_changed_text_surfaces", [])
        if row["path"] in authority_paths
    ]
    require(
        previous_authority_rows == parent_authority_rows and
        [row.get("path") for row in previous_authority_rows] == authority_paths and
        current_authority_rows == live_authority_rows and
        previous_authority_rows != current_authority_rows,
        "Patch 24.0e seed publication authority-surface identity drifted")
    matching_states = [row for row in states
                       if row.get("inventory") == live_inventory]
    require(len(matching_states) == 1,
            "live inventory is neither exact pre-publication nor post-publication state")
    live_seed_rows = [row for row in live_rows if row["path"] == seed_path]
    require(live_seed_rows == [matching_states[0].get("seed_surface")],
            "live seed surface does not match its registered publication state")
    require(states[0].get("seed_surface") != states[1].get("seed_surface") and
            states[0].get("inventory") != states[1].get("inventory"),
            "seed publication states are not distinct")
    for state in states:
        for field in unchanged_fields:
            require(state["inventory"].get(field) ==
                    transition["previous_inventory"].get(field),
                    f"seed publication changed retained inventory field: {field}")
    require(canonical_digest([
        row for row in live_rows
        if row["path"] not in authority_paths + [seed_path]
    ]) == transition.get("unchanged_other_text_surface_manifest_digest"),
            "seed publication changed an unregistered text surface")
    return matching_states[0]["inventory"]


def validate_phase24_cr15_closure_transition(
        registry: dict, live_inventory: dict, live_rows: list[dict]) -> dict:
    """Accept only the exact Patch 24.0f closure evidence successor."""
    closure = registry.get("phase24_cr15_closure", {})
    transition = closure.get("consumer_inventory_transition", {})
    seed_transition = registry.get(
        "phase24_cr15_seed_authority_consumer_transition", {}).get(
            "seed_publication_transition", {})
    seed_states = seed_transition.get("accepted_live_states", [])
    paths = transition.get("registered_changed_paths", [])
    unchanged = [
        "invocation_count", "invocation_manifest_digest",
        "structural_surface_count", "structural_manifest_digest",
        "invocation_selection_counts", "unclassified_count",
    ]
    require(
        transition.get("contract_version") ==
        "phase24_cr15_closure_consumer_transition_v1" and
        transition.get("status") == "patch24_0f_ready_for_merge" and
        transition.get("authority_base_main") ==
        "aea95476d455c292f8b790a810b23bb98badcdd8" and
        len(seed_states) == 2 and
        seed_states[1].get("state") == "post_publication" and
        transition.get("previous_inventory") == seed_states[1].get("inventory") and
        transition.get("current_inventory") == live_inventory and
        transition.get("unchanged_fields") == unchanged and
        transition.get("partial_extra_or_substituted_surface") == "rejected" and
        paths == sorted(paths) and len(paths) == len(set(paths)),
        "Patch 24.0f closure consumer transition drifted")
    previous_rows = transition.get("previous_changed_text_surfaces", [])
    current_rows = transition.get("current_changed_text_surfaces", [])
    require([row.get("path") for row in previous_rows] == [
                path for path in paths
                if any(base.get("path") == path for base in previous_rows)] and
            [row.get("path") for row in current_rows] == [
                path for path in paths
                if any(live.get("path") == path for live in current_rows)],
            "Patch 24.0f changed text-surface manifests drifted")
    require(current_rows == [row for row in live_rows if row["path"] in paths],
            "Patch 24.0f live changed text surfaces drifted")
    require(canonical_digest([
        row for row in live_rows if row["path"] not in paths
    ]) == transition.get("unchanged_other_text_surface_manifest_digest"),
            "Patch 24.0f changed an unregistered text surface")
    for field in unchanged:
        require(live_inventory.get(field) ==
                transition["previous_inventory"].get(field),
                f"Patch 24.0f changed retained inventory field: {field}")
    require(transition.get("current_inventory", {}).get("text_surface_count") ==
            transition["previous_inventory"].get("text_surface_count") +
            transition.get("added_text_surface_count", -1),
            "Patch 24.0f text-surface delta drifted")
    return live_inventory


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


def projected_text_surfaces(
        registry: dict, record: dict) -> list[dict[str, object]]:
    """Keep the generated review stable across the registered seed-only PR."""
    rows = scan_text_surfaces()
    transition = record["deprecation_contract"][
        "seed_reconvergence_inventory_transition"]
    states = transition["accepted_live_states"]
    require([row["state"] for row in states] ==
            ["post_publication"],
            "seed inventory projection state order drifted")
    live_seed_digest = digest_bytes(SEED.read_bytes())
    cr15_publication = registry.get(
        "phase24_cr15_seed_authority_consumer_transition", {}).get(
            "seed_publication_transition")
    if live_seed_digest not in {row["seed_digest"] for row in states}:
        if isinstance(registry.get("phase24_cr15_closure"), dict):
            validate_phase24_cr15_closure_transition(
                registry, inventory_summary(), rows)
        else:
            validate_phase24_cr15_seed_publication_transition(
                registry, inventory_summary(), rows)
    seed_rows = [row for row in rows if row["path"] == transition["seed_path"]]
    require(len(seed_rows) == 1,
            "seed inventory projection did not find exactly one seed row")
    if isinstance(cr15_publication, dict):
        publication_states = cr15_publication.get("accepted_live_states", [])
        require([row.get("state") for row in publication_states] ==
                ["pre_publication", "post_publication"],
                "seed publication projection state order drifted")
        seed_rows[0].clear()
        seed_rows[0].update(
            copy.deepcopy(publication_states[0]["seed_surface"]))
    else:
        seed_rows[0]["digest"] = states[0]["seed_digest"]
    return rows


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
    successor = record.get("deprecation_contract")
    require(isinstance(successor, dict) and
            successor.get("contract_version") ==
            "phase23_mir_to_c_user_deprecation_v1" and
            successor.get("status") == "patch23_8_complete" and
            successor.get("next_patch") == "23.8a",
            "Patch 23.8 deprecation successor is missing or incomplete")
    seed_transition = successor.get("seed_reconvergence_inventory_transition")
    require(seed_transition == {
        "contract_version": "phase23_deprecation_seed_inventory_transition_v1",
        "status": "landed_post_publication",
        "authority_base_main": "2204239042b3e19283dc400d212445a72aff1f50",
        "seed_path": "gust_v4.c",
        "accepted_live_states": [
            {
                "state": "post_publication",
                "seed_digest":
                    "af8a283c9ef4dbe621f78729e89a4c7270c0b740aeb7164af57fa953e5f29924",
                "text_surface_count": 566,
                "text_surface_manifest_digest":
                    "6ee29149e1afba58a8407416effa561714ccb774ccaa074496ba1a9714683fec",
            },
        ],
        "unchanged_inventory_fields": [
            "invocation_count",
            "invocation_manifest_digest",
            "structural_surface_count",
            "structural_manifest_digest",
            "classification_counts",
            "invocation_selection_counts",
            "unclassified_count",
        ],
        "partial_or_mismatched_seed_inventory_state": "rejected",
        "closure_transition": "collapsed_to_post_publication",
        "landed_seed_evidence": {
            "pull_request": 289,
            "head_sha": "ba040834dadef99982892016a2163d0296270a0a",
            "merge_main_sha": "3d9ed5df9188cf38275885a665316e58cfb9dd21",
            "merged_at": "2026-09-01T08:53:43Z",
            "event": "pull_request",
            "workflow_population": 22,
            "successful_workflows": 22,
            "unfinished_workflows": 0,
            "non_success_workflows": 0,
            "unresolved_non_outdated_review_threads": 0,
            "changed_paths": ["gust_v4.c"],
        },
    }, "Patch 23.8a seed inventory transition drifted")
    frozen_transition = successor.get("frozen_surface_inventory_transition")
    require(isinstance(frozen_transition, dict) and
            frozen_transition.get("contract_version") ==
            "phase23_frozen_surface_inventory_transition_v1" and
            frozen_transition.get("status") == "patch23_9_complete" and
            frozen_transition.get("authority_base_main") ==
            "05b2545ce21688577834d5914137c81be7c99de5" and
            frozen_transition.get("previous_inventory") == {
                "seed_digest":
                    "af8a283c9ef4dbe621f78729e89a4c7270c0b740aeb7164af57fa953e5f29924",
                "text_surface_count": 566,
                "text_surface_manifest_digest":
                    "6ee29149e1afba58a8407416effa561714ccb774ccaa074496ba1a9714683fec",
            } and
            frozen_transition.get("unchanged_live_route_fields") == [
                "invocation_count",
                "invocation_manifest_digest",
                "structural_surface_count",
                "structural_manifest_digest",
                "classification_counts",
                "invocation_selection_counts",
                "unclassified_count",
            ] and
            frozen_transition.get("partial_or_unregistered_inventory") ==
            "rejected",
            "Patch 23.9 frozen-surface inventory transition drifted")
    require(frozen_transition.get("authority_only_paths") == [
        ".github/workflows/phase23-mir-to-c-frozen-surface.yml",
        "TASK.md",
        "compiler/CRANELIFT_PHASE23_MIR_TO_C_FROZEN_SURFACE.md",
        "justfile",
        "scripts/cranelift_feature_registry.json",
        "scripts/cranelift_feature_registry.schema.json",
        "scripts/cranelift_registry.py",
        "scripts/cranelift_test_levels.json",
        "scripts/phase23_mir_to_c_deprecation_opening.py",
        "scripts/phase23_mir_to_c_frozen_surface.py",
        ".github/workflows/pr-fast.yml",
    ], "Patch 23.9 authority-only path manifest drifted")
    focused_transition = successor.get("focused_live_inventory_transition")
    require(isinstance(focused_transition, dict) and
            focused_transition.get("contract_version") ==
            "phase23_focused_live_inventory_transition_v1" and
            focused_transition.get("status") == "patch23_10_complete" and
            focused_transition.get("authority_base_main") ==
            "7178ee245d6d340329f6b5614dbf8be12fe8d273" and
            focused_transition.get("previous_inventory") ==
            frozen_transition.get("current_inventory") and
            focused_transition.get("unchanged_fields") == [
                "invocation_count",
                "structural_surface_count",
                "structural_manifest_digest",
                "invocation_selection_counts",
                "unclassified_count",
            ] and
            focused_transition.get("partial_or_unregistered_inventory") ==
            "rejected",
            "Patch 23.10 focused-live inventory transition drifted")
    require(focused_transition.get("authority_only_paths") == [
        ".github/workflows/heavy-guards.yml",
        ".github/workflows/phase21-cranelift-built-compiler-programs.yml",
        ".github/workflows/phase23-mir-to-c-focused-live.yml",
        ".github/workflows/pr-fast.yml",
        "TASK.md",
        "compiler/CRANELIFT_PHASE22_OPENING.md",
        "compiler/CRANELIFT_PHASE23_MIR_TO_C_DEPRECATION_OPENING.md",
        "compiler/CRANELIFT_PHASE23_MIR_TO_C_FOCUSED_LIVE.md",
        "compiler/CRANELIFT_PHASE23_MIR_TO_C_FROZEN_SURFACE.md",
        "justfile",
        "scripts/cranelift_ci_family.py",
        "scripts/cranelift_feature_registry.json",
        "scripts/cranelift_feature_registry.schema.json",
        "scripts/cranelift_registry.py",
        "scripts/cranelift_test_levels.json",
        "scripts/cranelift_test_levels.py",
        "scripts/phase21_cranelift_built_compiler_programs.py",
        "scripts/phase23_mir_to_c_deprecation_opening.py",
        "scripts/phase23_mir_to_c_focused_live.py",
        "scripts/phase23_mir_to_c_frozen_surface.py",
    ], "Patch 23.10 authority-only path manifest drifted")
    archive_transition = successor.get("archived_corpus_inventory_transition")
    require(isinstance(archive_transition, dict) and
            archive_transition.get("contract_version") ==
            "phase23_archived_corpus_inventory_transition_v1" and
            archive_transition.get("status") == "patch23_11_complete" and
            archive_transition.get("authority_base_main") ==
            "7941bceb2ed62bca97917ad241290caf5fd97bf6" and
            archive_transition.get("previous_inventory") ==
            focused_transition.get("current_inventory") and
            archive_transition.get("unchanged_inventory_fields") == [
                "text_surface_count", "structural_surface_count",
                "structural_manifest_digest", "classification_counts",
                "unclassified_count",
            ] and
            archive_transition.get("unchanged_invocation_selection_fields") == [
                "explicit_c", "explicit_cranelift",
                "explicit_invalid_or_parser_probe",
            ] and
            archive_transition.get("implicit_default_replay_delta") == 1 and
            archive_transition.get("live_explicit_c_population") == 178 and
            archive_transition.get("partial_or_unregistered_inventory") ==
            "rejected", "Patch 23.11 archived-corpus inventory transition drifted")
    require(archive_transition.get("authority_only_paths") == [
        ".github/workflows/phase23-mir-to-c-archived-corpus.yml",
        ".github/workflows/pr-fast.yml",
        "TASK.md",
        "compiler/CRANELIFT_PHASE23_MIR_TO_C_ARCHIVED_CORPUS.md",
        "compiler/CRANELIFT_PHASE22_OPENING.md",
        "compiler/CRANELIFT_PHASE23_MIR_TO_C_DEPRECATION_OPENING.md",
        "compiler/CRANELIFT_PHASE23_MIR_TO_C_FROZEN_SURFACE.md",
        "compiler/fixtures/phase23_mir_to_c_reference_corpus_v1.json",
        "justfile",
        "scripts/cranelift_feature_registry.json",
        "scripts/cranelift_feature_registry.schema.json",
        "scripts/cranelift_registry.py",
        "scripts/cranelift_test_levels.json",
        "scripts/phase23_mir_to_c_archived_corpus.py",
        "scripts/phase23_mir_to_c_deprecation_opening.py",
        "scripts/phase23_mir_to_c_frozen_surface.py",
        "scripts/phase22_opening.py",
    ], "Patch 23.11 authority-only path manifest drifted")
    production_transition = successor.get("production_release_inventory_transition")
    require(isinstance(production_transition, dict) and
            production_transition.get("contract_version") ==
            "phase23_production_release_inventory_transition_v1" and
            production_transition.get("status") == "patch23_12_complete" and
            production_transition.get("authority_base_main") ==
            "c2b6ec8c4a3650e704541ebd00b57020783f1def" and
            production_transition.get("previous_inventory") ==
            archive_transition.get("current_inventory") and
            production_transition.get("migration") == {
                "path": "scripts/run-gust-file.sh",
                "historical_route":
                    "explicit_mir_to_c_plus_host_C_compile_link_preserved",
                "supported_route":
                    "explicit_cranelift_native_artifact_selected_by_GUST_RUNNER_ROUTE",
                "supported_callers": [
                    "flake.nix:gt-one-gst", "justfile:gt-one-gst",
                    "justfile:guard",
                    "scripts/phase23_production_release_audit.sh",
                ],
                "invocation_delta": 1,
                "explicit_c_delta": 0,
                "explicit_cranelift_delta": 1,
                "production_surface_delta": 0,
            } and production_transition.get("unchanged_fields") == [
                "text_surface_count", "structural_surface_count",
                "structural_manifest_digest", "classification_counts",
                "unclassified_count",
            ] and production_transition.get("partial_or_unregistered_inventory") ==
            "rejected", "Patch 23.12 production/release inventory transition drifted")
    qualification_transition = registry.get(
        "phase23_cross_feature_qualification", {}).get(
            "consumer_inventory_transition", {})
    require(isinstance(qualification_transition, dict) and
            qualification_transition.get("contract_version") ==
            "phase23_cross_feature_consumer_inventory_transition_v1" and
            qualification_transition.get("status") == "patch23_13_complete" and
            qualification_transition.get("authority_base_main") ==
            "9b89296b25d2ab0cf1963ea1d1707139149d0576" and
            qualification_transition.get("previous_inventory") ==
            production_transition.get("current_inventory") and
            qualification_transition.get("unchanged_fields") == [
                "invocation_count", "invocation_manifest_digest",
                "structural_surface_count", "structural_manifest_digest",
                "classification_counts", "invocation_selection_counts",
                "unclassified_count",
            ] and qualification_transition.get(
                "partial_or_unregistered_inventory") == "rejected",
            "Patch 23.13 qualification inventory transition drifted")
    live_inventory = inventory_summary()
    live_seed_digest = digest_bytes(SEED.read_bytes())
    accepted_by_seed = {
        row["seed_digest"]: row
        for row in seed_transition["accepted_live_states"]
    }
    accepted_state = accepted_by_seed.get(live_seed_digest)
    cr15_closure_inventory = None
    if accepted_state is None:
        if isinstance(registry.get("phase24_cr15_closure"), dict):
            cr15_inventory = validate_phase24_cr15_closure_transition(
                registry, live_inventory, scan_text_surfaces())
            cr15_closure_inventory = cr15_inventory
            seed_publication = registry[
                "phase24_cr15_seed_authority_consumer_transition"][
                    "seed_publication_transition"]
            accepted_inventory = seed_publication[
                "accepted_live_states"][1]["inventory"]
        else:
            cr15_inventory = validate_phase24_cr15_seed_publication_transition(
                registry, live_inventory, scan_text_surfaces())
            accepted_inventory = cr15_inventory
        accepted_state = {
            "text_surface_count": accepted_inventory["text_surface_count"],
            "text_surface_manifest_digest":
                accepted_inventory["text_surface_manifest_digest"],
        }
    require(accepted_state is not None,
            "live seed is outside the registered seed inventory transitions")
    previous_inventory = copy.deepcopy(successor["post_deprecation_inventory"])
    previous_inventory["text_surface_count"] = accepted_state["text_surface_count"]
    previous_inventory["text_surface_manifest_digest"] = \
        accepted_state["text_surface_manifest_digest"]
    for field in frozen_transition["unchanged_live_route_fields"]:
        require(frozen_transition["current_inventory"].get(field) ==
                previous_inventory.get(field),
                f"Patch 23.9 changed frozen route field: {field}")
    for field in focused_transition["unchanged_fields"]:
        require(focused_transition["current_inventory"].get(field) ==
                focused_transition["previous_inventory"].get(field),
                f"Patch 23.10 changed retained inventory field: {field}")
    for field in archive_transition["unchanged_inventory_fields"]:
        require(archive_transition["current_inventory"].get(field) ==
                archive_transition["previous_inventory"].get(field),
                f"Patch 23.11 changed retained inventory field: {field}")
    previous_selections = archive_transition["previous_inventory"][
        "invocation_selection_counts"]
    current_selections = archive_transition["current_inventory"][
        "invocation_selection_counts"]
    for field in archive_transition["unchanged_invocation_selection_fields"]:
        require(current_selections.get(field) == previous_selections.get(field),
                f"Patch 23.11 changed retained invocation selection: {field}")
    require(current_selections.get("implicit_default", 0) ==
            previous_selections.get("implicit_default", 0) +
            archive_transition["implicit_default_replay_delta"] and
            archive_transition["current_inventory"]["invocation_count"] ==
            archive_transition["previous_inventory"]["invocation_count"] + 1,
            "Patch 23.11 native archive replay invocation delta drifted")
    for field in production_transition["unchanged_fields"]:
        require(production_transition["current_inventory"].get(field) ==
                production_transition["previous_inventory"].get(field),
                f"Patch 23.12 changed retained inventory field: {field}")
    previous_production_selections = production_transition["previous_inventory"][
        "invocation_selection_counts"]
    current_production_selections = production_transition["current_inventory"][
        "invocation_selection_counts"]
    require(current_production_selections.get("explicit_c") ==
            previous_production_selections.get("explicit_c") and
            current_production_selections.get("explicit_cranelift") ==
            previous_production_selections.get("explicit_cranelift") + 1 and
            production_transition["current_inventory"]["invocation_count"] ==
            production_transition["previous_inventory"]["invocation_count"] + 1 and
            production_transition["current_inventory"]["classification_counts"]
            ["production_or_release_migration"] ==
            production_transition["previous_inventory"]["classification_counts"]
            ["production_or_release_migration"],
            "Patch 23.12 supported-runner migration delta drifted")
    for field in qualification_transition["unchanged_fields"]:
        require(qualification_transition["current_inventory"].get(field) ==
                qualification_transition["previous_inventory"].get(field),
                f"Patch 23.13 changed retained inventory field: {field}")
    historical_transition = registry.get(
        "phase23_historical_full_qualification", {}).get(
            "consumer_inventory_transition")
    if historical_transition is None:
        expected_inventory = qualification_transition["current_inventory"]
    else:
        historical_unchanged = [
            "invocation_count", "invocation_manifest_digest",
            "structural_surface_count", "structural_manifest_digest",
            "invocation_selection_counts", "unclassified_count",
        ]
        historical_paths = [
            "compiler/CRANELIFT_PHASE23_HISTORICAL_FULL_QUALIFICATION.md",
            "scripts/phase23_historical_full_qualification.py",
        ]
        require(historical_transition.get("contract_version") ==
                "phase23_historical_consumer_inventory_transition_v1" and
                historical_transition.get("status") == "patch23_14_complete" and
                historical_transition.get("authority_base_main") ==
                "fee6600d86f85f8a0a0da94211ae89895869187e" and
                historical_transition.get("previous_inventory") ==
                qualification_transition["current_inventory"] and
                historical_transition.get("registered_added_paths") ==
                historical_paths and
                historical_transition.get("unchanged_fields") ==
                historical_unchanged and
                historical_transition.get("partial_extra_or_substituted_surface") ==
                "rejected",
                "Patch 23.14 Historical inventory transition drifted")
        historical_previous = historical_transition["previous_inventory"]
        historical_current = historical_transition["current_inventory"]
        for field in historical_unchanged:
            require(historical_current.get(field) ==
                    historical_previous.get(field),
                    f"Patch 23.14 changed retained inventory field: {field}")
        previous_classes = historical_previous["classification_counts"]
        current_classes = historical_current["classification_counts"]
        require(historical_current["text_surface_count"] ==
                historical_previous["text_surface_count"] + 2 and
                current_classes.get("archive_candidate") ==
                previous_classes.get("archive_candidate") + 1 and
                current_classes.get("historical_only") ==
                previous_classes.get("historical_only") + 1 and
                all(current_classes.get(key) == previous_classes.get(key)
                    for key in (
                        "bootstrap_phase25", "focused_live_oracle",
                        "production_or_release_migration",
                    )),
                "Patch 23.14 classified text-surface delta drifted")
        closure_transition = registry.get("phase23_closure", {}).get(
            "consumer_inventory_transition")
        if closure_transition is None:
            historical_rows = [row for row in scan_text_surfaces()
                               if row["path"] in historical_paths]
            require([row["path"] for row in historical_rows] == historical_paths and
                    historical_transition.get("registered_added_text_surfaces") ==
                    historical_rows,
                    "Patch 23.14 added text-surface identity drifted")
            expected_inventory = historical_current
        else:
            require([row.get("path") for row in historical_transition.get(
                "registered_added_text_surfaces", [])] == historical_paths,
                    "Patch 23.14 recorded added text-surface paths drifted")
            closure_paths = [
                "docs/PHASE23_CLOSURE.md",
                "scripts/phase23_closure.py",
            ]
            require(closure_transition.get("contract_version") ==
                    "phase23_closure_consumer_inventory_transition_v1" and
                    closure_transition.get("status") == "patch23_15_complete" and
                    closure_transition.get("authority_base_main") ==
                    "8985a3d09b1f119accd12cd952940ef019d6a698" and
                    closure_transition.get("previous_inventory") ==
                    historical_current and
                    closure_transition.get("registered_added_paths") ==
                    closure_paths and
                    closure_transition.get("unchanged_fields") ==
                    historical_unchanged and
                    closure_transition.get("partial_extra_or_substituted_surface") ==
                    "rejected",
                    "Patch 23.15 closure inventory transition drifted")
            closure_current = closure_transition["current_inventory"]
            for field in historical_unchanged:
                require(closure_current.get(field) ==
                        historical_current.get(field),
                        f"Patch 23.15 changed retained inventory field: {field}")
            historical_classes = historical_current["classification_counts"]
            closure_classes = closure_current["classification_counts"]
            require(closure_current["text_surface_count"] ==
                    historical_current["text_surface_count"] + 2 and
                    closure_classes.get("archive_candidate") ==
                    historical_classes.get("archive_candidate") + 1 and
                    closure_classes.get("historical_only") ==
                    historical_classes.get("historical_only") + 1 and
                    all(closure_classes.get(key) == historical_classes.get(key)
                        for key in (
                            "bootstrap_phase25", "focused_live_oracle",
                            "production_or_release_migration",
                        )),
                    "Patch 23.15 classified text-surface delta drifted")
            roadmap_transition = registry.get("phase23_closure", {}).get(
                "phase24_opening_preflight_roadmap_transition")
            cr15_roadmap_transition = registry.get("phase23_closure", {}).get(
                "phase24_cr15_roadmap_amendment_transition")
            cr15_opening_transition = registry.get("phase23_closure", {}).get(
                "phase24_cr15_opening_transition")
            cr15_derivation_transition = registry.get(
                "phase24_cr15_derivation", {}).get(
                    "consumer_inventory_transition")
            cr15_qualification_transition = registry.get(
                "phase24_cr15_qualification", {}).get(
                    "consumer_inventory_transition")
            cr15_seed_transition = registry.get(
                "phase24_cr15_seed_authority_consumer_transition")
            cr15_seed_publication = (
                cr15_seed_transition.get("seed_publication_transition")
                if isinstance(cr15_seed_transition, dict) else None
            )
            closure_rows = [row for row in scan_text_surfaces()
                            if row["path"] in closure_paths]
            require([row.get("path") for row in closure_transition.get(
                        "registered_added_text_surfaces", [])] == closure_paths,
                    "Patch 23.15 recorded added text-surface paths drifted")
            if roadmap_transition is None:
                require(closure_transition.get(
                            "registered_added_text_surfaces") == closure_rows,
                        "Patch 23.15 added text-surface identity drifted")
            expected_inventory = closure_current
            if roadmap_transition is not None:
                changed_paths = ["TASK.md", "scripts/phase23_closure.py"]
                previous_changed_surfaces = [
                    {
                        "path": "TASK.md",
                        "digest": "83173140afd89df31664c9a3fe4a03fedb9f662c1167fccdd7f649b761b4581e",
                        "match_counts": {
                            "explicit_backend_spelling": 0,
                            "mir_to_c_name": 115,
                            "generated_c_contract": 25,
                        },
                        "classification": "production_or_release_migration",
                        "owner": "cranelift",
                        "current_route": "tracked_MIR_to_C_or_generated_C_surface",
                        "deprecation_action": "review_claims_in_23_8_and_23_12",
                        "removal_phase": "24_or_25_as_claim_requires",
                        "falsifier":
                        "live_documentation_claim_is_missing_or_changes_identity",
                    },
                    closure_transition["registered_added_text_surfaces"][1],
                ]
                roadmap_unchanged = [
                    "text_surface_count", "invocation_count",
                    "invocation_manifest_digest", "structural_surface_count",
                    "structural_manifest_digest", "classification_counts",
                    "invocation_selection_counts", "unclassified_count",
                ]
                require(
                    roadmap_transition.get("contract_version") ==
                    "phase24_opening_preflight_roadmap_transition_v1" and
                    roadmap_transition.get("status") == "patch24_0_complete" and
                    roadmap_transition.get("authority_base_main") ==
                    "1c5e7fe5dee11aa00019bffafe14778a449b96d4" and
                    roadmap_transition.get("previous_inventory") ==
                    closure_current and
                    roadmap_transition.get("previous_changed_text_surfaces") ==
                    previous_changed_surfaces and
                    roadmap_transition.get("registered_changed_paths") ==
                    changed_paths and
                    roadmap_transition.get("unchanged_fields") ==
                    roadmap_unchanged and
                    roadmap_transition.get(
                        "partial_extra_or_substituted_surface") == "rejected",
                    "Patch 24.0 roadmap inventory transition drifted")
                roadmap_current = roadmap_transition["current_inventory"]
                for field in roadmap_unchanged:
                    require(roadmap_current.get(field) ==
                            closure_current.get(field),
                            f"Patch 24.0 changed retained inventory field: {field}")
                live_text_rows = scan_text_surfaces()
                expected_inventory = roadmap_current
                if cr15_roadmap_transition is None:
                    changed_rows = [row for row in live_text_rows
                                    if row["path"] in changed_paths]
                    require([row["path"] for row in changed_rows] == changed_paths and
                            roadmap_transition.get(
                                "current_changed_text_surfaces") == changed_rows,
                            "Patch 24.0 changed text-surface identity drifted")
                    require(
                        canonical_digest([row for row in live_text_rows
                                          if row["path"] not in changed_paths]) ==
                        roadmap_transition.get(
                            "unchanged_other_text_surface_manifest_digest"),
                        "Patch 24.0 changed an unregistered text surface")
                else:
                    require(
                        cr15_roadmap_transition.get("contract_version") ==
                        "phase24_cr15_roadmap_amendment_transition_v1" and
                        cr15_roadmap_transition.get("status") ==
                        "patch24_0a_complete" and
                        cr15_roadmap_transition.get("authority_base_main") ==
                        "86d13496fa83c6d3688402f09b77a8dfbb8168fc" and
                        cr15_roadmap_transition.get("previous_inventory") ==
                        roadmap_current and
                        cr15_roadmap_transition.get(
                            "previous_changed_text_surfaces") ==
                        roadmap_transition["current_changed_text_surfaces"] and
                        cr15_roadmap_transition.get("registered_changed_paths") ==
                        changed_paths and
                        cr15_roadmap_transition.get("unchanged_fields") ==
                        roadmap_unchanged and
                        cr15_roadmap_transition.get(
                            "partial_extra_or_substituted_surface") == "rejected",
                        "Patch 24.0a CR-15 roadmap transition drifted")
                    cr15_current = cr15_roadmap_transition["current_inventory"]
                    for field in roadmap_unchanged:
                        require(cr15_current.get(field) ==
                                roadmap_current.get(field),
                                f"Patch 24.0a changed retained inventory field: {field}")
                    if cr15_opening_transition is None:
                        changed_rows = [row for row in live_text_rows
                                        if row["path"] in changed_paths]
                        require([row["path"] for row in changed_rows] == changed_paths and
                                cr15_roadmap_transition.get(
                                    "current_changed_text_surfaces") == changed_rows,
                                "Patch 24.0a changed text-surface identity drifted")
                        require(
                            canonical_digest([row for row in live_text_rows
                                              if row["path"] not in changed_paths]) ==
                            cr15_roadmap_transition.get(
                                "unchanged_other_text_surface_manifest_digest"),
                            "Patch 24.0a changed an unregistered text surface")
                        expected_inventory = cr15_current
                    else:
                        require(
                            cr15_opening_transition.get("contract_version") ==
                            "phase24_cr15_opening_transition_v1" and
                            cr15_opening_transition.get("status") ==
                            "patch24_0b_complete_inert" and
                            cr15_opening_transition.get("authority_base_main") ==
                            "8b84622ddffb88a97bd06d6b87e948d1e7e88545" and
                            cr15_opening_transition.get("previous_inventory") ==
                            cr15_current and
                            cr15_opening_transition.get("current_inventory") ==
                            (live_inventory if cr15_derivation_transition is None
                             else cr15_derivation_transition.get(
                                 "previous_inventory")) and
                            cr15_opening_transition.get("registered_changed_paths") ==
                            changed_paths and
                            cr15_opening_transition.get("previous_changed_text_surfaces") ==
                            cr15_roadmap_transition["current_changed_text_surfaces"] and
                            cr15_opening_transition.get("unchanged_fields") ==
                            roadmap_unchanged and
                            cr15_opening_transition.get(
                                "partial_extra_or_substituted_surface") == "rejected",
                            "Patch 24.0b CR-15 opening transition drifted")
                        if cr15_derivation_transition is None:
                            changed_rows = [row for row in live_text_rows
                                            if row["path"] in changed_paths]
                            require([row["path"] for row in changed_rows] == changed_paths and
                                    cr15_opening_transition.get(
                                        "current_changed_text_surfaces") == changed_rows,
                                    "Patch 24.0b changed text-surface identity drifted")
                            require(
                                canonical_digest([row for row in live_text_rows
                                                  if row["path"] not in changed_paths]) ==
                                cr15_opening_transition.get(
                                    "unchanged_other_text_surface_manifest_digest"),
                                "Patch 24.0b changed an unregistered text surface")
                            expected_inventory = cr15_opening_transition["current_inventory"]
                        else:
                            successor_unchanged = [
                                "invocation_count", "invocation_manifest_digest",
                                "structural_surface_count", "structural_manifest_digest",
                                "invocation_selection_counts", "unclassified_count",
                            ]
                            successor_paths = cr15_derivation_transition.get(
                                "registered_changed_paths", [])
                            successor_rows = (
                                [row for row in live_text_rows
                                 if row["path"] in successor_paths]
                                if cr15_qualification_transition is None else
                                cr15_derivation_transition.get(
                                    "current_changed_text_surfaces", [])
                            )
                            successor_other_digest = (
                                canonical_digest([
                                    row for row in live_text_rows
                                    if row["path"] not in successor_paths
                                ])
                                if cr15_qualification_transition is None else
                                cr15_derivation_transition.get(
                                    "unchanged_other_text_surface_manifest_digest")
                            )
                            derivation_live_inventory = (
                                live_inventory if cr15_qualification_transition is None
                                else cr15_derivation_transition["current_inventory"]
                            )
                            require(
                                cr15_derivation_transition.get("contract_version") ==
                                "phase24_cr15_derivation_consumer_transition_v1" and
                                cr15_derivation_transition.get("status") ==
                                "patch24_0c_complete" and
                                cr15_derivation_transition.get("authority_base_main") ==
                                "c37024afa580d1e03c5ff70150ed0ae7518a9648" and
                                cr15_derivation_transition.get("previous_inventory") ==
                                cr15_opening_transition["current_inventory"] and
                                cr15_derivation_transition.get("current_inventory") ==
                                (live_inventory
                                 if cr15_qualification_transition is None else
                                 cr15_qualification_transition.get(
                                     "previous_inventory")) and
                                cr15_derivation_transition.get("unchanged_fields") ==
                                successor_unchanged and
                                derivation_live_inventory.get("text_surface_count") ==
                                cr15_derivation_transition["previous_inventory"].get(
                                    "text_surface_count") + 1 and
                                derivation_live_inventory.get(
                                    "classification_counts", {}).get(
                                    "archive_candidate") ==
                                cr15_derivation_transition["previous_inventory"].get(
                                    "classification_counts", {}).get(
                                        "archive_candidate") + 1 and
                                all(derivation_live_inventory.get(
                                        "classification_counts", {}).get(key) ==
                                    cr15_derivation_transition["previous_inventory"].get(
                                        "classification_counts", {}).get(key)
                                    for key in (
                                        "bootstrap_phase25", "focused_live_oracle",
                                        "historical_only", "production_or_release_migration",
                                    )) and
                                cr15_derivation_transition.get(
                                    "partial_extra_or_substituted_surface") == "rejected" and
                                [row["path"] for row in successor_rows] == successor_paths and
                                cr15_derivation_transition.get(
                                    "current_changed_text_surfaces") == successor_rows and
                                successor_other_digest == cr15_derivation_transition.get(
                                    "unchanged_other_text_surface_manifest_digest"),
                                "Patch 24.0c CR-15 derivation transition drifted")
                            for field in successor_unchanged:
                                require(derivation_live_inventory.get(field) ==
                                        cr15_derivation_transition[
                                            "previous_inventory"].get(field),
                                        f"Patch 24.0c changed retained inventory field: {field}")
                            expected_inventory = cr15_derivation_transition[
                                "current_inventory"]
                            if cr15_qualification_transition is not None:
                                qualification_unchanged = [
                                    "text_surface_count", "invocation_count",
                                    "invocation_manifest_digest",
                                    "structural_surface_count",
                                    "structural_manifest_digest",
                                    "classification_counts",
                                    "invocation_selection_counts",
                                    "unclassified_count",
                                ]
                                qualification_paths = cr15_qualification_transition.get(
                                    "registered_changed_paths", [])
                                qualification_rows = (
                                    [row for row in live_text_rows
                                     if row["path"] in qualification_paths]
                                    if cr15_seed_transition is None else
                                    cr15_qualification_transition.get(
                                        "current_changed_text_surfaces", [])
                                )
                                previous_by_path = {
                                    row["path"]: row for row in
                                    cr15_qualification_transition.get(
                                        "previous_changed_text_surfaces", [])
                                }
                                qualification_live_inventory = (
                                    live_inventory if cr15_seed_transition is None
                                    else cr15_qualification_transition[
                                        "current_inventory"]
                                )
                                require(
                                    cr15_qualification_transition.get(
                                        "contract_version") ==
                                    "phase24_cr15_qualification_consumer_transition_v1" and
                                    cr15_qualification_transition.get("status") ==
                                    "patch24_0d_complete" and
                                    cr15_qualification_transition.get(
                                        "authority_base_main") ==
                                    "2383096a741c62e8de103a5b79281b9f616eb805" and
                                    cr15_qualification_transition.get(
                                        "previous_inventory") ==
                                    cr15_derivation_transition["current_inventory"] and
                                    cr15_qualification_transition.get(
                                        "current_inventory") ==
                                    (live_inventory if cr15_seed_transition is None else
                                     cr15_seed_transition.get("previous_inventory")) and
                                    cr15_qualification_transition.get(
                                        "unchanged_fields") ==
                                    qualification_unchanged and
                                    cr15_qualification_transition.get(
                                        "partial_extra_or_substituted_surface") ==
                                    "rejected" and
                                    [row["path"] for row in qualification_rows] ==
                                    qualification_paths and
                                    cr15_qualification_transition.get(
                                        "current_changed_text_surfaces") ==
                                    qualification_rows and
                                    [row.get("path") for row in
                                     cr15_qualification_transition.get(
                                         "previous_changed_text_surfaces", [])] ==
                                    qualification_paths and
                                    all(previous_by_path[path] != row
                                        for path, row in zip(
                                            qualification_paths,
                                            qualification_rows)) and
                                    (canonical_digest([
                                        row for row in live_text_rows
                                        if row["path"] not in qualification_paths
                                    ]) if cr15_seed_transition is None else
                                     cr15_qualification_transition.get(
                                         "unchanged_other_text_surface_manifest_digest")) ==
                                    cr15_qualification_transition.get(
                                        "unchanged_other_text_surface_manifest_digest"),
                                    "Patch 24.0d CR-15 qualification transition drifted")
                                for field in qualification_unchanged:
                                    require(
                                        qualification_live_inventory.get(field) ==
                                        cr15_qualification_transition[
                                            "previous_inventory"].get(field),
                                        f"Patch 24.0d changed retained inventory field: {field}")
                                expected_inventory = cr15_qualification_transition[
                                    "current_inventory"]
                                if cr15_seed_transition is not None:
                                    seed_paths = [
                                        "compiler/CRANELIFT_PHASE22_DEFAULT_ROUTE_SEED_CONVERGENCE.md",
                                        "scripts/cranelift_registry.py",
                                        "scripts/phase22_default_route_seed_convergence.py",
                                        "scripts/phase23_closure.py",
                                    ]
                                    seed_unchanged = [
                                        "text_surface_count", "invocation_count",
                                        "invocation_manifest_digest",
                                        "structural_surface_count",
                                        "structural_manifest_digest",
                                        "classification_counts",
                                        "invocation_selection_counts",
                                        "unclassified_count",
                                    ]
                                    seed_rows = (
                                        [row for row in live_text_rows
                                         if row["path"] in seed_paths]
                                        if cr15_seed_publication is None else
                                        cr15_seed_transition.get(
                                            "current_changed_text_surfaces", [])
                                    )
                                    previous_seed_rows = cr15_seed_transition.get(
                                        "previous_changed_text_surfaces", [])
                                    seed_live_inventory = (
                                        live_inventory if cr15_seed_publication is None
                                        else cr15_seed_transition["current_inventory"]
                                    )
                                    require(
                                        cr15_seed_transition.get("contract_version") ==
                                        "phase24_cr15_seed_authority_consumer_transition_v1" and
                                        cr15_seed_transition.get("status") ==
                                        "ready_for_seed_publication" and
                                        cr15_seed_transition.get("authority_base_main") ==
                                        "10076805b56697304e7b236fff09cdf3689fcc05" and
                                        cr15_seed_transition.get("previous_inventory") ==
                                        cr15_qualification_transition["current_inventory"] and
                                        cr15_seed_transition.get("current_inventory") ==
                                        (live_inventory
                                         if cr15_seed_publication is None else
                                         cr15_seed_publication.get(
                                             "previous_inventory")) and
                                        cr15_seed_transition.get("registered_changed_paths") ==
                                        seed_paths and
                                        cr15_seed_transition.get("unchanged_fields") ==
                                        seed_unchanged and
                                        cr15_seed_transition.get(
                                            "partial_extra_or_substituted_surface") ==
                                        "rejected" and
                                        [row["path"] for row in seed_rows] == seed_paths and
                                        cr15_seed_transition.get(
                                            "current_changed_text_surfaces") == seed_rows and
                                        [row.get("path") for row in previous_seed_rows] ==
                                        seed_paths and
                                        all(previous != current for previous, current in
                                            zip(previous_seed_rows, seed_rows)) and
                                        (canonical_digest([
                                            row for row in live_text_rows
                                            if row["path"] not in seed_paths
                                        ]) if cr15_seed_publication is None else
                                         cr15_seed_transition.get(
                                             "unchanged_other_text_surface_manifest_digest")) ==
                                        cr15_seed_transition.get(
                                            "unchanged_other_text_surface_manifest_digest"),
                                        "Patch 24.0e CR-15 seed authority transition drifted")
                                    for field in seed_unchanged:
                                        require(
                                            seed_live_inventory.get(field) ==
                                            cr15_seed_transition[
                                                "previous_inventory"].get(field),
                                            f"Patch 24.0e changed retained inventory field: {field}")
                                    expected_inventory = cr15_seed_transition[
                                        "current_inventory"]
                                    if cr15_seed_publication is not None:
                                        if cr15_closure_inventory is not None:
                                            expected_inventory = cr15_closure_inventory
                                        else:
                                            expected_inventory = (
                                                validate_phase24_cr15_seed_publication_transition(
                                                    registry, live_inventory, live_text_rows)
                                            )
    require(expected_inventory == live_inventory,
            "live Phase 23 MIR-to-C inventory is not the exact registered successor")
    require(live_inventory["unclassified_count"] == 0,
            "consumer or artifact remains unclassified")
    validate_identity_falsifiers(live_inventory)

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
    require("- [x] Patch 23.8 — User-Facing MIR-to-C Deprecation Contract — DONE" in task,
            "TASK.md does not mark Patch 23.8 DONE")
    require("- [x] Patch 23.8a — Deprecation Bootstrap Seed Reconvergence — DONE" in task,
            "TASK.md does not mark Patch 23.8a DONE")

    presentation = successor.get("presentation", {})
    expected_presentation = {
        "compiler_help":
            "mir-to-c, c  DEPRECATED: Emit C source to stdout (retained semantic oracle); backend removal is Phase 24.",
        "bootstrap_help":
            "Bootstrap C retirement is separate and deferred to Phase 25.",
        "root_documentation":
            "deprecated_explicit_C_spellings_remain_accepted_through_phase23_backend_removal_phase24_bootstrap_C_retirement_phase25",
        "ordinary_compilation_notice": "none_help_and_documentation_only",
    }
    require(presentation == expected_presentation,
            "Patch 23.8 presentation authority drifted")
    entry = ENTRY.read_text(encoding="utf-8")
    help_text = HELP.read_text(encoding="utf-8")
    readme = README.read_text(encoding="utf-8")
    for marker in (presentation["compiler_help"], presentation["bootstrap_help"]):
        require(marker in entry and marker in help_text,
                f"compiler help deprecation marker is missing: {marker}")
    require(entry.count('std.str_eq(backend_name, "mir-to-c")') == 1 and
            entry.count('std.str_eq(backend_name, "c")') == 1,
            "an explicit C spelling is no longer accepted by the shared parser")
    for marker in (
        "C99 backend is deprecated",
        "backend removal scheduled for Phase 24",
        "retirement is deferred to Phase 25",
        "deprecated C compatibility choices",
    ):
        require(marker in readme,
                f"root user deprecation timeline is missing: {marker}")
    require(record["pre_deprecation_baseline"] ==
            successor.get("explicit_c_byte_authority"),
            "Patch 23.8 did not preserve the Patch 23.7 byte authority")
    require(successor.get("route_contract") == {
        "default_backend": "cranelift",
        "explicit_native_backend": "cranelift",
        "default_and_explicit_native": "byte_and_observable_identical",
        "explicit_c_spellings": ["mir-to-c", "c"],
        "explicit_c_acceptance": "retained_byte_identical_through_phase23",
        "fallback": "forbidden",
        "backend_removal_phase": "24",
        "bootstrap_C_retirement_phase": "25",
    }, "Patch 23.8 route contract drifted")
    require(successor.get("boundary") == {
        "changes_help_and_root_documentation": True,
        "changes_backend_route_or_acceptance": False,
        "changes_ordinary_compilation_stdout_or_stderr": False,
        "changes_accepted_Gust_program_meaning": False,
        "adds_or_changes_MIR_operations": False,
        "changes_ABI_layout_runtime_symbols_target_or_linker": False,
        "changes_bootstrap_route_or_seed": False,
        "edits_stdlib_or_CR15": False,
        "begins_patch23_8a": False,
    }, "Patch 23.8 boundary drifted")

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
    require(REVIEW.is_file() and
            REVIEW.read_text(encoding="utf-8") == render(registry, record),
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
    help_result = subprocess.run(
        (str(GUST), "--help"), cwd=ROOT, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, timeout=180, check=False,
    )
    require(help_result.returncode == 0 and help_result.stderr == b"" and
            help_result.stdout == HELP.read_bytes(),
            "live compiler help does not match the checked deprecation projection")

    require(PACKAGED_GUST.is_file(),
            "packaged compiler is missing; run make phase10-native-package")
    guard_root = ROOT / "build/guards"
    guard_root.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.pop("GUST_NATIVE_BACKEND_DRIVER", None)
    with tempfile.TemporaryDirectory(prefix="phase23-8-", dir=guard_root) as tmp:
        output = Path(tmp)
        bare = output / "bare"
        explicit = output / "explicit"
        bare_build = subprocess.run(
            (str(PACKAGED_GUST), "-o", str(bare),
             str(NATIVE_IDENTITY_SOURCE.relative_to(ROOT))),
            cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            timeout=180, check=False,
        )
        explicit_build = subprocess.run(
            (str(PACKAGED_GUST), "--backend", "cranelift", "-o", str(explicit),
             str(NATIVE_IDENTITY_SOURCE.relative_to(ROOT))),
            cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            timeout=180, check=False,
        )
        require(bare_build.returncode == explicit_build.returncode == 0 and
                bare_build.stdout == explicit_build.stdout == b"" and
                bare_build.stderr == explicit_build.stderr == b"" and
                bare.is_file() and explicit.is_file() and
                bare.read_bytes() == explicit.read_bytes(),
                "default and explicit Cranelift artifacts or diagnostics differ")
        bare_run = subprocess.run(
            (str(bare),), cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            timeout=180, check=False,
        )
        explicit_run = subprocess.run(
            (str(explicit),), cwd=ROOT, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, timeout=180, check=False,
        )
        require((bare_run.returncode, bare_run.stdout, bare_run.stderr) ==
                (explicit_run.returncode, explicit_run.stdout,
                 explicit_run.stderr),
                "default and explicit Cranelift execution differs")
    print("phase23_mir_to_c_deprecation_opening: evidence ok")


def render(registry: dict, record: dict) -> str:
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
    for row in projected_text_surfaces(registry, record):
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
    successor = record["deprecation_contract"]
    post = successor["post_deprecation_inventory"]
    seed_transition = successor["seed_reconvergence_inventory_transition"]
    seed_landed = seed_transition["landed_seed_evidence"]
    lines += [
        "## Patch 23.8 user-facing deprecation successor",
        "",
        f"- Contract: `{successor['contract_version']}`",
        f"- Status: `{successor['status']}`",
        f"- Next patch: `{successor['next_patch']}`",
        f"- Compiler help: `{successor['presentation']['compiler_help']}`",
        f"- Bootstrap help: `{successor['presentation']['bootstrap_help']}`",
        "- Both explicit C spellings remain accepted and byte-identical.",
        "- Generated-C backend removal is Phase 24; bootstrap-C retirement is Phase 25.",
        "- Ordinary compilation emits no deprecation notice.",
        f"- Post-deprecation text surfaces: `{post['text_surface_count']}`",
        f"- Post-deprecation text manifest: `{post['text_surface_manifest_digest']}`",
        f"- Post-deprecation invocations: `{post['invocation_count']}`",
        f"- Post-deprecation invocation manifest: `{post['invocation_manifest_digest']}`",
        f"- Unclassified: `{post['unclassified_count']}`",
        "",
        "### Patch 23.8a seed inventory transition",
        "",
        f"- Contract: `{seed_transition['contract_version']}`",
        f"- Status: `{seed_transition['status']}`",
        f"- Authority base main: `{seed_transition['authority_base_main']}`",
        f"- Partial or mismatched state: `{seed_transition['partial_or_mismatched_seed_inventory_state']}`",
    ] + [
        f"- Accepted `{row['state']}` pair: seed `{row['seed_digest']}`, text manifest `{row['text_surface_manifest_digest']}`"
        for row in seed_transition["accepted_live_states"]
    ] + [
        "",
        "### Patch 23.8a landed seed evidence",
        "",
        f"- Pull request: `#{seed_landed['pull_request']}`",
        f"- Exact head: `{seed_landed['head_sha']}`",
        f"- Merge main: `{seed_landed['merge_main_sha']}`",
        f"- Merged at: `{seed_landed['merged_at']}`",
        f"- Exact-head workflows: {seed_landed['successful_workflows']}/{seed_landed['workflow_population']} successful, {seed_landed['unfinished_workflows']} unfinished, {seed_landed['non_success_workflows']} non-success",
        f"- Unresolved non-outdated review threads: {seed_landed['unresolved_non_outdated_review_threads']}",
        f"- Changed paths: `{', '.join(seed_landed['changed_paths'])}`",
        "",
    ]
    frozen_transition = successor["frozen_surface_inventory_transition"]
    frozen_inventory = frozen_transition["current_inventory"]
    lines += [
        "## Patch 23.9 frozen-surface inventory successor",
        "",
        f"- Contract: `{frozen_transition['contract_version']}`",
        f"- Status: `{frozen_transition['status']}`",
        f"- Authority base main: `{frozen_transition['authority_base_main']}`",
        f"- Current text surfaces: `{frozen_inventory['text_surface_count']}`",
        f"- Current text manifest: `{frozen_inventory['text_surface_manifest_digest']}`",
        f"- Current invocations: `{frozen_inventory['invocation_count']}`",
        f"- Current invocation manifest: `{frozen_inventory['invocation_manifest_digest']}`",
        "- Invocation identities, structural surfaces, classifications, and route selections are unchanged.",
        "- The transition contains authority and generated-review changes only.",
        "- Partial or unregistered inventory: `rejected`",
        "",
    ]
    focused_transition = successor["focused_live_inventory_transition"]
    focused_inventory = focused_transition["current_inventory"]
    lines += [
        "## Patch 23.10 focused-live inventory successor",
        "",
        f"- Contract: `{focused_transition['contract_version']}`",
        f"- Status: `{focused_transition['status']}`",
        f"- Authority base main: `{focused_transition['authority_base_main']}`",
        f"- Current text surfaces: `{focused_inventory['text_surface_count']}`",
        f"- Current text manifest: `{focused_inventory['text_surface_manifest_digest']}`",
        f"- Current invocations: `{focused_inventory['invocation_count']}`",
        f"- Current invocation manifest: `{focused_inventory['invocation_manifest_digest']}`",
        "- Invocation count, structural surfaces, route selections, and zero-unclassified status are unchanged.",
        "- One registered authority reference joins the archive-candidate text inventory; other identity changes are workflow routing files and shifted command locations.",
        "- Partial or unregistered inventory: `rejected`",
        "",
    ]
    archive_transition = successor["archived_corpus_inventory_transition"]
    archive_inventory = archive_transition["current_inventory"]
    lines += [
        "## Patch 23.11 archived-corpus inventory successor",
        "",
        f"- Contract: `{archive_transition['contract_version']}`",
        f"- Status: `{archive_transition['status']}`",
        f"- Authority base main: `{archive_transition['authority_base_main']}`",
        f"- Current text surfaces: `{archive_inventory['text_surface_count']}`",
        f"- Current text manifest: `{archive_inventory['text_surface_manifest_digest']}`",
        f"- Current invocations: `{archive_inventory['invocation_count']}`",
        f"- Current invocation manifest: `{archive_inventory['invocation_manifest_digest']}`",
        f"- Live explicit-C invocations: `{archive_transition['live_explicit_c_population']}` (unchanged)",
        "- The sole added invocation is default-native archived-corpus replay; no live-C caller was added.",
        "- Partial or unregistered inventory: `rejected`",
        "",
    ]
    production_transition = successor["production_release_inventory_transition"]
    production_inventory = production_transition["current_inventory"]
    lines += [
        "## Patch 23.12 production/release inventory successor",
        "",
        f"- Contract: `{production_transition['contract_version']}`",
        f"- Status: `{production_transition['status']}`",
        f"- Authority base main: `{production_transition['authority_base_main']}`",
        f"- Current text surfaces: `{production_inventory['text_surface_count']}`",
        f"- Current text manifest: `{production_inventory['text_surface_manifest_digest']}`",
        f"- Current invocations: `{production_inventory['invocation_count']}`",
        f"- Current invocation manifest: `{production_inventory['invocation_manifest_digest']}`",
        f"- Explicit-C invocations: `{production_inventory['invocation_selection_counts']['explicit_c']}`",
        f"- Explicit-Cranelift invocations: `{production_inventory['invocation_selection_counts']['explicit_cranelift']}`",
        "- The supported single-program runner moved from generated C plus host-C linking to an explicit Cranelift artifact.",
        "- Partial or unregistered inventory: `rejected`",
        "",
    ]
    qualification_transition = json.loads(REGISTRY.read_text(encoding="utf-8"))[
        "phase23_cross_feature_qualification"]["consumer_inventory_transition"]
    qualification_inventory = qualification_transition["current_inventory"]
    lines += [
        "## Patch 23.13 cross-feature inventory successor",
        "",
        f"- Contract: `{qualification_transition['contract_version']}`",
        f"- Status: `{qualification_transition['status']}`",
        f"- Authority base main: `{qualification_transition['authority_base_main']}`",
        f"- Current text surfaces: `{qualification_inventory['text_surface_count']}`",
        f"- Current text manifest: `{qualification_inventory['text_surface_manifest_digest']}`",
        f"- Current invocations: `{qualification_inventory['invocation_count']}`",
        f"- Current invocation manifest: `{qualification_inventory['invocation_manifest_digest']}`",
        f"- Explicit-C invocations: `{qualification_inventory['invocation_selection_counts']['explicit_c']}`",
        f"- Explicit-Cranelift invocations: `{qualification_inventory['invocation_selection_counts']['explicit_cranelift']}`",
        "- Qualification authority changes no compiler invocation or classification.",
        "- Partial or unregistered inventory: `rejected`",
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
        REVIEW.write_text(render(registry, record), encoding="utf-8")
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
