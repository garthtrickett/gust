#!/usr/bin/env python3
"""Level 1 contract and reduced review for Phase 17.14 composition, compatibility, and diagnostics."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter
from pathlib import Path

GUARD = "guard-cranelift-phase17-composition-contract"
PARITY_GUARD = "guard-cranelift-phase17-composition-differential"
LEVEL = "level1"
CONTRACT = Path("tests/cranelift/phase17_composition_contract.tsv")
REVIEW = Path("tests/cranelift/phase17_composition_review.txt")
REGISTRY = Path("scripts/cranelift_feature_registry.json")
SOURCE = Path("compiler/mir_runtime_boundary_authority.gst")
REQUEST_SOURCE = Path("compiler/mir_composition_request.gst")
WORKER = Path("compiler/experiments/cranelift/src/composition.rs")
MAIN = Path("compiler/experiments/cranelift/src/main.rs")
CRATE = Path("compiler/mir_composition_request.gst")
CRATE_SOURCE = Path("compiler/mir_composition_request.gst")
SMOKE = Path("compiler/mir_composition_smoke_test_entry.gst")
PARITY = Path("scripts/phase17_composition_differential.sh")
WORKFLOW = Path(".github/workflows/phase17-composition.yml")
TASK = Path("TASK.md")

COMPOSITION_KINDS = ("allocation_then_string_formatting_and_output",
                     "resource_bearing_aggregate_across_runtime_call",
                     "directory_acquire_branch_early_return_cleanup",
                     "gust_runtime_helper_calling_stable_import",
                     "rust_and_retained_c_in_one_package",
                     "thread_helper_using_resource_cleanup",
                     "compatible_package_from_target_candidates",
                     "incompatible_version_preserving_sentinel")
SENTINEL_POLICIES = ("sentinel_output_preserved_on_failure",
                     "case_cannot_fail_no_output_to_preserve")
EXPECTED = {
    "semantic_type": {"runtime_composition_case"},
    "query": {"runtime_composition_case_for", "runtime_composition_covers"},
    "composition_kind": set(COMPOSITION_KINDS),
    "sentinel_policy": set(SENTINEL_POLICIES),
    "rejection": {
        "unknown_composition_kind", "not_composed", "no_differential_owner",
        "missing_sentinel_policy", "duplicate_case", "incomplete_inventory",
    },
    "policy": {
        "inventory_derived_from_registry_ownership",
        "every_migrated_authority_participates",
        "no_generated_c_shim_in_link_plan",
        "sentinel_output_preserved_on_failure", "stable_witness",
    },
    "boundary": {"eight_nested_combinations"},
}
REASONS = (
    "runtime_composition_unknown_kind", "runtime_composition_not_composed",
    "runtime_composition_no_differential_owner",
    "runtime_composition_missing_sentinel_policy",
    "runtime_composition_duplicate_case",
    "runtime_composition_incomplete_inventory",
)
SOURCE_TOKENS = (
    "type MirRuntimeCompositionCase", "composition_kind:",
    "participating_authorities:", "differential_owner:", "sentinel_policy:",
    "func mir_runtime_composition_case_id(",
    "func mir_runtime_composition_case_for(",
    "func mir_runtime_composition_covers(",
    "func mir_runtime_composition_kind_is_valid(",
    "func mir_runtime_sentinel_policy_is_valid(",
    "mir_runtime_table_with_composition_case(",
    "runtime_composition_kind", "runtime_composition_sentinel",
)
REQUEST_TOKENS = (
    "gust.compiler_composition.v1", "gust.composition_witness.v1",
    "func mir_serialize_composition_request(",
    "func mir_composition_mir_to_c_witness(",
    "every_migrated_authority_participates_in_at_least_one_composition",
)
WORKER_TOKENS = (
    "pub fn parse_composition_request(",
    "pub fn render_composition_witness(",
    "pub fn lower_composition_witness_path(", "COMPOSITION_KINDS",
)
MAIN_TOKENS = ("mod composition;", '"phase17-composition-witness"')


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
    authority = registry.get("phase17_composition_authority")
    if not isinstance(authority, dict):
        fail("canonical registry lacks composition authority")
    expected = {
        "version": "phase17_composition_authority_v1",
        "status": "ready_for_patch17_15",
        "request_format": "gust.compiler_composition.v1",
        "witness_format": "gust.composition_witness.v1",
        "worker_owner": "compiler/experiments/cranelift/src/composition.rs",
        "next_patch": "17.15",
    }
    for key, value in expected.items():
        if authority.get(key) != value:
            fail(f"composition metadata drifted: {key}")
    if tuple(authority.get("rejection_classes", ())) != REASONS:
        fail("composition rejection inventory drifted")

    cases = authority.get("composition_cases", [])
    if {r["composition_kind"] for r in cases} != set(COMPOSITION_KINDS):
        fail("composition inventory does not cover the eight combinations")

    # Coverage is computed against registry ownership, not a hand-written list.
    participants = set()
    for row in cases:
        if len(row["participating_authorities"]) < 2:
            fail(f"{row['composition_kind']}: composes fewer than two authorities")
        if not row["differential_owner"]:
            fail(f"{row['composition_kind']}: names no differential owner")
        participants.update(row["participating_authorities"])
    authorities = {
        k for k in registry
        if k.startswith("phase17_") and k.endswith("_authority")
        and k != "phase17_composition_authority"
    }
    uncovered = sorted(authorities - participants)
    if uncovered:
        fail(f"authorities with no composition case: {uncovered}")
    unknown = sorted(participants - authorities)
    if unknown:
        fail(f"composition names non-registry authorities: {unknown}")
    return authority


def check_source(root: Path) -> None:
    source = text(root / SOURCE)
    for token in (*SOURCE_TOKENS, *REASONS, *COMPOSITION_KINDS, *SENTINEL_POLICIES):
        if token not in source:
            fail(f"composition source is missing: {token}")
    request = text(root / REQUEST_SOURCE)
    for token in REQUEST_TOKENS:
        if token not in request:
            fail(f"composition request module is missing: {token}")
    worker = text(root / WORKER)
    for token in WORKER_TOKENS:
        if token not in worker:
            fail(f"Cranelift composition module is missing: {token}")
    main = text(root / MAIN)
    for token in MAIN_TOKENS:
        if token not in main:
            fail(f"Cranelift worker is missing composition wiring: {token}")



def check_wiring(root: Path) -> None:
    for path in (SMOKE, PARITY, WORKFLOW, CRATE, CRATE_SOURCE):
        if not (root / path).is_file():
            fail(f"missing required file: {path}")
    workflow = text(root / WORKFLOW)
    for token in (GUARD, PARITY_GUARD,
                  "python3 scripts/phase17_composition.py --check",
                  "Phase 17.14 composition contract",
                  "Phase 17.14 composition differential"):
        if token not in workflow:
            fail(f"workflow is missing: {token}")
    parity = text(root / PARITY)
    for token in ("phase17-composition-witness", "cmp -s",
                  "registry ownership", "participants="):
        if token not in parity:
            fail(f"parity script is missing: {token}")
    marker = ("- [x] Patch 17.6 — Rust Runtime Components and Native Object "
              "Integration — DONE")
    if marker not in text(root / TASK):
        fail("TASK.md does not mark Patch 17.6 DONE")


def render(contract_rows: list[dict[str, str]], authority: dict) -> str:
    counts = Counter(row["kind"] for row in contract_rows)
    participants = set()
    for row in authority["composition_cases"]:
        participants.update(row["participating_authorities"])
    lines = [
        "Phase 17.14 — Cross-Feature Runtime Composition and Complete Differential",
        f"guard: {GUARD}", f"differential_guard: {PARITY_GUARD}",
        f"test_level: {LEVEL}",
        f"inventory_policy: {authority['inventory_policy']}",
        f"coverage_policy: {authority['coverage_policy']}",
        f"authorities_covered: {len(participants)}",
        "", "contract counts:",
    ]
    lines += [f"  {kind}: {counts[kind]}" for kind in sorted(counts)]
    lines += ["", "nested combinations:"]
    for row in authority["composition_cases"]:
        lines.append(f"  {row['composition_kind']}\t{row['sentinel_policy']}")
        lines += [f"    participant\t{a}" for a in row["participating_authorities"]]
        lines.append(f"    owner\t{row['differential_owner']}")
    lines += ["", "rejection classes:"]
    lines += [f"  {value}" for value in authority["rejection_classes"]]
    lines += [
        "", "exit gate:",
        "  migrated Phase 17 capabilities compose rather than being proven only "
        "in isolation",
        "  the differential inventory is derived from canonical registry "
        "ownership",
        "  the explicit Cranelift link plan contains no generated C shim "
        "artifact",
        "  deferred residue and runtime-coverage audit remains in Patch 17.15",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--write", action="store_true")
    modes.add_argument("--check", action="store_true")
    modes.add_argument("individual-guards", nargs="?", const=True, default=None,
                       help="emit the per-authority guards the Level 3 evidence "
                            "run composes, derived from registry ownership")
    args = parser.parse_args()
    root = args.root.resolve()
    if getattr(args, "individual-guards", None) or getattr(args, "individual_guards", None):
        # Derived from registry ownership, then resolved against guards that
        # actually exist. Resolution tries deterministic suffixes rather than
        # substring matching: "runtime" is a substring of almost every guard,
        # and loose matching silently mapped the base classification authority
        # onto the retained-C guard. A registry authority with no Level 1 guard
        # is an error, and the composition guard is excluded so the Level 3 run
        # does not recurse into itself.
        registry = json.loads(text(root / REGISTRY))
        justfile = text(root / Path("justfile"))
        available = set(re.findall(r"^(guard-cranelift-phase17-[\w-]+):", justfile, re.M))
        suffixes = ("-contract", "-authority-contract", "-runtime-contract",
                    "-version-contract")
        emitted, missing = [], []
        for key in sorted(k for k in registry
                          if k.startswith("phase17_") and k.endswith("_authority")):
            if key == "phase17_composition_authority":
                continue
            slug = key.removeprefix("phase17_").removesuffix("_authority").replace("_", "-")
            resolved = next(
                (f"guard-cranelift-phase17-{slug}{suffix}" for suffix in suffixes
                 if f"guard-cranelift-phase17-{slug}{suffix}" in available),
                None,
            )
            if resolved is None:
                missing.append(key)
            else:
                emitted.append(resolved)
        if missing:
            fail(f"registry authorities with no Level 1 guard: {missing}")
        if len(set(emitted)) != len(emitted):
            fail(f"two authorities resolved to the same guard: {sorted(emitted)}")
        for guard in emitted:
            print(guard)
        return 0
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
    participants = set()
    for row in authority["composition_cases"]:
        participants.update(row["participating_authorities"])
    print(f"{GUARD}: ok ({len(authority['composition_cases'])} combinations, "
          f"{len(participants)} authorities covered, {LEVEL})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
