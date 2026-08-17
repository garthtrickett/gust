#!/usr/bin/env python3
"""Level 1 contract and reduced review for Phase 17.13 availability, compatibility, and diagnostics."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import Counter
from pathlib import Path

GUARD = "guard-cranelift-phase17-availability-contract"
PARITY_GUARD = "guard-cranelift-phase17-availability-parity"
LEVEL = "level1"
CONTRACT = Path("tests/cranelift/phase17_availability_contract.tsv")
REVIEW = Path("tests/cranelift/phase17_availability_review.txt")
REGISTRY = Path("scripts/cranelift_feature_registry.json")
SOURCE = Path("compiler/mir_runtime_boundary_authority.gst")
REQUEST_SOURCE = Path("compiler/mir_availability_request.gst")
WORKER = Path("compiler/experiments/cranelift/src/availability.rs")
MAIN = Path("compiler/experiments/cranelift/src/main.rs")
CRATE = Path("compiler/mir_availability_request.gst")
CRATE_SOURCE = Path("compiler/mir_availability_request.gst")
SMOKE = Path("compiler/mir_availability_smoke_test_entry.gst")
PARITY = Path("scripts/phase17_availability_parity.sh")
WORKFLOW = Path(".github/workflows/phase17-availability.yml")
TASK = Path("TASK.md")

VALIDATION_STEPS = ("package_manifest_format",
                    "runtime_abi_identity_and_version", "target_identity",
                    "required_component_presence",
                    "required_symbol_presence_and_version",
                    "function_abi_layout_and_resource_compatibility",
                    "declared_system_library_requirements",
                    "deterministic_component_and_link_ordering")
STAGE_BOUNDARIES = ("before_worker_execution",
                    "after_target_selection_before_linker_invocation")
EXPECTED = {
    "semantic_type": {"runtime_availability_decision"},
    "query": {"runtime_availability_decision_for"},
    "validation_step": set(VALIDATION_STEPS),
    "stage_boundary": set(STAGE_BOUNDARIES),
    "rejection": {
        "runtime_package_missing", "runtime_manifest_malformed",
        "runtime_wrong_target", "runtime_abi_incompatible",
        "runtime_component_missing", "runtime_symbol_missing",
        "runtime_symbol_version_incompatible",
        "runtime_classification_inconsistent",
        "runtime_link_plan_dependency_undeclared",
    },
    "policy": {
        "frozen_dense_decision_order", "decisions_complete_before_any_output",
        "no_replacement_package_or_fallback_helper", "stable_witness",
    },
    "boundary": {"frozen_decision_order"},
}
REASONS = (
    "runtime_availability_malformed_decision",
    "runtime_availability_unclassified_rejection",
    "runtime_availability_late_decision",
    "runtime_availability_decision_order_drift",
    "runtime_availability_duplicate_decision",
    "runtime_availability_incomplete_order",
)
SOURCE_TOKENS = (
    "type MirRuntimeAvailabilityDecision", "decision_order:",
    "validation_step:", "rejection_class:", "stage_boundary:",
    "func mir_runtime_availability_decision_id(",
    "func mir_runtime_availability_decision_for(",
    "func mir_runtime_validation_step_is_valid(",
    "func mir_runtime_stage_boundary_is_valid(",
    "func mir_runtime_availability_rejection_is_valid(",
    "mir_runtime_table_with_availability_decision(",
    "runtime_availability_step", "runtime_availability_stage",
)
REQUEST_TOKENS = (
    "gust.compiler_availability.v1", "gust.availability_witness.v1",
    "func mir_serialize_availability_request(",
    "func mir_availability_mir_to_c_witness(",
    "all_compatibility_decisions_complete_before_any_output_could_exist",
)
WORKER_TOKENS = (
    "pub fn parse_availability_request(",
    "pub fn render_availability_witness(",
    "pub fn lower_availability_witness_path(", "VALIDATION_STEPS",
)
MAIN_TOKENS = ("mod availability;", '"phase17-availability-witness"')


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD}: {message}")


def text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        fail(f"missing required file: {path}")


def rows(root: Path) -> list[dict[str, str]]:
    try:
        with (root / CONTRACT).open(encoding="utf-8", newline="") as handle:
            result = list(csv.DictReader(handle, delimiter="\t"))
    except FileNotFoundError:
        fail(f"missing required file: {CONTRACT}")
    required = {"kind", "id", "owner", "test_level", "disposition"}
    if not result or set(result[0]) != required:
        fail("contract schema drifted")
    actual: dict[str, set[str]] = {}
    seen: set[tuple[str, str]] = set()
    for row in result:
        key = (row["kind"], row["id"])
        if key in seen or row["test_level"] != LEVEL:
            fail(f"duplicate or non-Level-1 row: {key}")
        seen.add(key)
        actual.setdefault(row["kind"], set()).add(row["id"])
    if actual != EXPECTED:
        fail("contract inventory drifted")
    return result


def check_registry(root: Path) -> dict:
    registry = json.loads(text(root / REGISTRY))
    authority = registry.get("phase17_availability_authority")
    if not isinstance(authority, dict):
        fail("canonical registry lacks availability authority")
    expected = {
        "version": "phase17_availability_authority_v1",
        "status": "ready_for_patch17_14",
        "request_format": "gust.compiler_availability.v1",
        "witness_format": "gust.availability_witness.v1",
        "worker_owner": "compiler/experiments/cranelift/src/availability.rs",
        "next_patch": "17.14",
    }
    for key, value in expected.items():
        if authority.get(key) != value:
            fail(f"availability metadata drifted: {key}")

    # The frozen order must be dense, ascending, and complete.
    decisions = authority.get("decision_order", [])
    if len(decisions) != len(VALIDATION_STEPS):
        fail(f"decision order has {len(decisions)} of {len(VALIDATION_STEPS)} steps")
    for index, row in enumerate(decisions):
        if row["decision_order"] != index:
            fail(f"decision {index} claims order {row['decision_order']}")
        if row["validation_step"] != VALIDATION_STEPS[index]:
            fail(f"decision {index} is not the frozen step for its position")
        if row["stage_boundary"] not in STAGE_BOUNDARIES:
            fail(f"decision {index} is deferred past an output-producing stage")
    return authority


def check_source(root: Path) -> None:
    source = text(root / SOURCE)
    for token in (*SOURCE_TOKENS, *REASONS, *VALIDATION_STEPS, *STAGE_BOUNDARIES):
        if token not in source:
            fail(f"availability source is missing: {token}")
    request = text(root / REQUEST_SOURCE)
    for token in REQUEST_TOKENS:
        if token not in request:
            fail(f"availability request module is missing: {token}")
    worker = text(root / WORKER)
    for token in WORKER_TOKENS:
        if token not in worker:
            fail(f"Cranelift availability module is missing: {token}")
    main = text(root / MAIN)
    for token in MAIN_TOKENS:
        if token not in main:
            fail(f"Cranelift worker is missing availability wiring: {token}")



def check_wiring(root: Path) -> None:
    for path in (SMOKE, PARITY, WORKFLOW, CRATE, CRATE_SOURCE):
        if not (root / path).is_file():
            fail(f"missing required file: {path}")
    workflow = text(root / WORKFLOW)
    for token in (GUARD, PARITY_GUARD,
                  "python3 scripts/phase17_availability.py --check",
                  "Phase 17.13 availability contract",
                  "Phase 17.13 availability parity"):
        if token not in workflow:
            fail(f"workflow is missing: {token}")
    parity = text(root / PARITY)
    for token in ("phase17-availability-witness", "cmp -s",
                  "output-producing stage", "order="):
        if token not in parity:
            fail(f"parity script is missing: {token}")
    marker = ("- [x] Patch 17.6 — Rust Runtime Components and Native Object "
              "Integration — DONE")
    if marker not in text(root / TASK):
        fail("TASK.md does not mark Patch 17.6 DONE")


def render(contract_rows: list[dict[str, str]], authority: dict) -> str:
    counts = Counter(row["kind"] for row in contract_rows)
    lines = [
        "Phase 17.13 — Runtime Availability, Compatibility, and Diagnostic Enforcement",
        f"guard: {GUARD}", f"parity_guard: {PARITY_GUARD}",
        f"test_level: {LEVEL}",
        f"ordering_policy: {authority['ordering_policy']}",
        f"stage_policy: {authority['stage_policy']}",
        f"no_fallback_policy: {authority['no_fallback_policy']}",
        "", "contract counts:",
    ]
    lines += [f"  {kind}: {counts[kind]}" for kind in sorted(counts)]
    lines += ["", "frozen decision order:"]
    lines += [
        f"  {row['decision_order']}\t{row['validation_step']}\t"
        f"{row['rejection_class']}\t{row['stage_boundary']}"
        for row in authority["decision_order"]
    ]
    lines += ["", "stable rejection classes:"]
    lines += [f"  {value}" for value in authority["rejection_classes"]]
    lines += [
        "", "exit gate:",
        "  runtime package availability and compatibility are validated before "
        "linking",
        "  every decision completes before linker invocation, temporary link "
        "output creation, or output replacement",
        "  the worker invents no replacement package and no fallback helper",
        "  cross-feature composition and the complete differential remain in "
        "Patch 17.14",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--write", action="store_true")
    modes.add_argument("--check", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    contract_rows = rows(root)
    authority = check_registry(root)
    check_source(root)
    expected = render(contract_rows, authority)
    if args.write:
        (root / REVIEW).write_text(expected, encoding="utf-8")
    else:
        if text(root / REVIEW) != expected:
            fail("generated review is stale; run this script with --write")
        check_wiring(root)
    print(f"{GUARD}: ok ({len(authority['decision_order'])} frozen decisions, "
          f"{len(authority['rejection_classes'])} rejection classes, {LEVEL})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
