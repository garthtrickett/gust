#!/usr/bin/env python3
"""Validate and project Patch 22.3 native implicit-output authority."""

from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE22_NATIVE_IMPLICIT_OUTPUT.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
ENTRY = ROOT / "compiler/test_runner_entry.gst"
HELP = ROOT / "compiler/phase10_help.txt"
SOURCE_ROUTE = ROOT / "compiler/mir_native_backend_source_route.gst"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase22-native-implicit-output.yml"
GUARD_L1 = "guard-cranelift-phase22-native-implicit-output-contract"
GUARD_L2 = "guard-cranelift-phase22-native-implicit-output-evidence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def opening_module():
    path = ROOT / "scripts/phase22_opening.py"
    spec = importlib.util.spec_from_file_location("phase22_opening", path)
    require(spec is not None and spec.loader is not None,
            "cannot load the Phase 22 invocation scanner")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    predecessor = registry.get("phase22_explicit_c_migration", {})
    record = registry.get("phase22_native_implicit_output")
    require(isinstance(record, dict), "Patch 22.3 authority is missing")
    require(record.get("contract_version") == "phase22_native_implicit_output_v1",
            "contract version drifted")
    require(record.get("status") == "implementation_complete" and
            record.get("next_action") == "patch22_6_default_route_flip",
            "status or next action drifted")
    require(record.get("observed_main_sha") ==
            "f648de3fb200f83735b0a86ca1d843500c6401aa",
            "observed main drifted")
    require(record.get("predecessor_authority") ==
            predecessor.get("contract_version") ==
            "phase22_explicit_c_migration_v2",
            "predecessor authority drifted")
    require(record.get("route_contract") == {
        "default_backend": "mir_to_c_unchanged",
        "selection": "explicit_cranelift_without_explicit_output_only",
        "source_suffix": "exact_lowercase_dot_gst",
        "source_stem": "remove_exactly_one_terminal_dot_gst",
        "output_directory": "normalized_lexical_source_directory",
        "target_executable_suffix":
            "empty_for_all_declared_phase14_elf_and_macho_targets",
        "invalid_source_names": [
            "missing_dot_gst_suffix", "empty_stem", "dot_stem", "dotdot_stem",
        ],
        "collision_rule": "reject_when_the_derived_output_still_ends_in_dot_gst",
        "explicit_output": "opaque_and_authoritative",
        "existing_output_success": "phase9g_atomic_replacement",
        "existing_output_failure": "preserved_byte_for_byte",
        "directory_creation": "forbidden",
        "native_source_route": "same_route_as_equivalent_explicit_output",
        "fallback_policy": "forbidden",
    }, "route contract drifted")

    scanner = opening_module()
    scanner.validate_post_flip_relay_transition(
        registry, scanner.scan_invocations()
    )
    migration = predecessor.get("migration", {})
    require(migration.get("opening_implicit_count") +
            migration.get("patch22_evidence_implicit_count") -
            migration.get("current_implicit_count") ==
            migration.get("cranelift_owned_migrated_count") == 60,
            "predecessor migration accounting drifted")
    require(predecessor.get("status") == "complete_post_relay" and
            predecessor.get("cross_lane_relay", {}).get("status") ==
            "merged_on_main" and
            predecessor.get("cross_lane_relay", {}).get(
                "authorized_post_relay_consumer_count") == 0,
            "the merged Stdlib-owned relay drifted")

    entry = ENTRY.read_text(encoding="utf-8")
    for marker in (
        'os.LogStr("  gust --backend cranelift [-o <output>] <source.gst>");',
        'invocation.output_path = compiler_native_implicit_output_path(invocation.source_path, ctx);',
        'func compiler_native_implicit_output_path(source_path: str, ctx: &Arena) str {',
        'return os.path_join(os.PathDir(ctx, source_path), stem, ctx);',
        'compiler_invocation_fail("implicit Cranelift output would collide with a Gust source path");',
    ):
        require(marker in entry, f"compiler marker is missing: {marker}")
    require(entry.splitlines()[240] == "func main() {",
            "Patch 22.3 moved the registered compiler entry source line")
    require(entry.count("native_source_route.mir_native_scalar_source_compile(") == 1,
            "implicit and explicit forms no longer share one native source route")
    require("the experimental backend requires exactly one -o <output> value" not in entry,
            "superseded mandatory-output rejection remains live")
    help_text = HELP.read_text(encoding="utf-8")
    require("gust --backend cranelift [-o <output>] <source.gst>" in help_text and
            "Optional Cranelift output; defaults to the source stem." in help_text,
            "help projection drifted")

    source_route = SOURCE_ROUTE.read_text(encoding="utf-8")
    for marker in (".phase10.bundle", ".phase10.request",
                   "mir_native_scalar_source_compile("):
        require(marker in source_route, f"inherited native source-route marker is missing: {marker}")
    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 22.2 — Explicit C Route and No-op Consumer Migration — DONE"
            in task and
            "- [x] Patch 22.2b — Post-Relay Prerequisite Reconciliation — DONE"
            in task and
            "- [x] Patch 22.3 — Native Implicit-Output Contract — DONE" in task and
            "- [x] Patch 22.6 — Cranelift Default Route Flip — DONE" in task,
            "22.2/22.3 completion or the 22.6 boundary drifted")

    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "guard levels drifted")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in just and f"{GUARD_L2}:" in just,
            "just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the contract")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow,
            "dedicated workflow does not own both guards")
    require(record.get("boundary") == {
        "changes_explicit_cranelift_output_inference": True,
        "changes_default_backend": False,
        "changes_accepted_Gust_program_meaning": False,
        "adds_or_changes_MIR_operations": False,
        "changes_target_linker_or_phase9g_publication": False,
        "changes_ABI_layout_or_runtime_symbols": False,
        "changes_bootstrap_seed": False,
        "edits_stdlib_or_CR15": False,
        "begins_patch22_4": False,
    }, "Patch 22.3 widened beyond its recorded boundary")
    return record


def render(record: dict) -> str:
    route = record["route_contract"]
    evidence = record["evidence"]
    lines = [
        "# Cranelift Phase 22.3 — Native Implicit-Output Contract",
        "",
        "Generated from `scripts/cranelift_feature_registry.json`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next action: `{record['next_action']}`",
        f"- Observed main: `{record['observed_main_sha']}`",
        f"- Predecessor: `{record['predecessor_authority']}`",
        "",
        "## Inferred output",
        "",
        f"- Selection: `{route['selection']}`",
        f"- Source suffix: `{route['source_suffix']}`",
        f"- Stem derivation: `{route['source_stem']}`",
        f"- Directory: `{route['output_directory']}`",
        f"- Target executable suffix: `{route['target_executable_suffix']}`",
        f"- Invalid names: `{', '.join(route['invalid_source_names'])}`",
        f"- Collision rule: `{route['collision_rule']}`",
        f"- Explicit `-o`: `{route['explicit_output']}`",
        "",
        "## Publication and evidence",
        "",
        f"- Existing output on success: `{route['existing_output_success']}`",
        f"- Existing output on failure: `{route['existing_output_failure']}`",
        f"- Directory creation: `{route['directory_creation']}`",
        f"- Source route: `{route['native_source_route']}`",
        f"- Fallback: `{route['fallback_policy']}`",
        f"- Inferred/explicit bytes: `{evidence['inferred_explicit_executable_bytes']}`",
        f"- Observable semantics: `{evidence['observable_semantics']}`",
        f"- Malformed intent cases: `{evidence['malformed_intent_cases']}`",
        "",
        "Patch 22.3 changes only explicit Cranelift output inference. Bare Gust",
        "remains MIR-to-C, the explicit output path remains opaque, and the existing",
        "native source route and Phase 9G transaction retain artifact ownership.",
        "The owning Stdlib relay has merged and Patch 22.3 is complete. The",
        "compiler default remains MIR-to-C; Patch 22.6 is still unchecked and",
        "this reconciliation does not itself authorize a partial route flip.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review"))
    args = parser.parse_args()
    record = validate()
    rendered = render(record)
    if args.command == "project":
        REVIEW.write_text(rendered, encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.exists(), "generated review view is missing")
        require(REVIEW.read_text(encoding="utf-8") == rendered,
                "generated review view is stale")
    print(f"{GUARD_L1}: {args.command} ok")


if __name__ == "__main__":
    main()
