#!/usr/bin/env python3
"""Validate and render the Patch 18.17 cross-target composition and per-target evidence."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase18-composition-contract"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
CONTRACT = ROOT / "tests/cranelift/phase18_composition_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase18_composition_review.txt"

# The six evidence kinds the phase exit gate requires of every declared
# supported target.
EVIDENCE_KINDS = ["native_compile", "object_inspection", "link", "execution",
                  "diagnostic", "reproducibility"]


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD}: {message}")


def contract_rows() -> list[dict[str, str]]:
    with CONTRACT.open(newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    if not rows or set(rows[0]) != {"kind", "requirement", "evidence", "level"}:
        fail("contract schema mismatch")
    if any(row["level"] != "1" or not row["evidence"] for row in rows):
        fail("all rows must be Level 1")
    return rows


def render(rows: list[dict[str, str]], authority: dict) -> str:
    cases = authority["composition_cases"]
    matrix = authority["per_target_evidence"]
    header = (
        "Patch 18.17 — Cross-Target Composition and Complete Per-Target Evidence\n\n"
        f"composition_cases\t{len(cases)}\n"
        f"participating_authorities\t{len({a for c in cases for a in c['participating_authorities']})}\n"
        f"evidence_kinds\t{len(EVIDENCE_KINDS)}\n"
        f"declared_supported_targets\t{len(matrix)}\n\n"
    )
    return header + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n"
        for row in rows
    )


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    authority = registry.get("phase18_composition")
    if not isinstance(authority, dict) or authority.get("version") != "phase18_composition_v1":
        fail("composition authority missing")

    # The composition inventory is derived from registry ownership, not
    # hand-written, so a new authority cannot be added and left uncomposed.
    owned = {k for k in registry if k.startswith("phase18_") and k != "phase18_composition"}
    cases = authority["composition_cases"]
    participating = {a for case in cases for a in case["participating_authorities"]}
    unknown = participating - owned
    if unknown:
        fail("composition_names_absent_authority: "
             f"composition names authorities that do not exist: {sorted(unknown)}")
    uncomposed = owned - participating
    if uncomposed:
        fail("composition_authority_uncomposed: these Phase 18 authorities "
             f"take part in no composition case: {sorted(uncomposed)}")

    # Every declared supported target carries all six evidence kinds, and the
    # supported set itself is derived from the diagnostics rather than asserted.
    diagnostics = registry["phase18_target_diagnostics"]["target_diagnostics"]
    supported = sorted(d["target_id"] for d in diagnostics
                       if d["support_decision"] == "supported")
    matrix = authority["per_target_evidence"]
    if sorted(row["target_id"] for row in matrix) != supported:
        fail("per_target_evidence_incomplete: the per-target evidence matrix is "
             "not derived from the declared supported set")

    for row in matrix:
        present = sorted(row["evidence_kinds"])
        if present != sorted(EVIDENCE_KINDS):
            missing = sorted(set(EVIDENCE_KINDS) - set(present))
            fail(f"per_target_evidence_incomplete: {row['target_id']} is missing "
                 f"evidence kinds {missing}")
        # Execution evidence must come from the target's own runner. A target
        # with no runner cannot be declared supported at all.
        if row["execution_runner"] != row["target_id"]:
            fail(f"execution_evidence_from_another_runner: {row['target_id']} takes its "
                 "execution evidence from another target's runner")

    # A target with no runner stays undeclared, named as a narrow deferred row.
    for entry in authority["targets_without_runner"]:
        if not entry.get("target_id") or not entry.get("deferred_row"):
            fail("a runnerless target is missing its id or its deferred row")
        if entry["target_id"] in supported:
            fail(f"runnerless_target_declared_supported: {entry['target_id']} is declared "
                 "supported despite having no runner")

    if authority["inventory_derivation"] != (
        "composition_inventory_is_derived_from_canonical_registry_ownership_not_a_hand_"
        "written_list"
    ):
        fail("inventory derivation drifted")
    if authority["runner_policy"] != (
        "a_target_with_no_available_runner_remains_undeclared_because_execution_evidence_"
        "is_part_of_the_phase_exit_gate"
    ):
        fail("runner policy drifted")

    rows = contract_rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(rows, authority):
        fail("generated review is stale; run --write")
    print(f"{GUARD}: ok ({len(cases)} cases, {len(participating)} authorities covered, "
          f"{len(matrix)} supported targets with all {len(EVIDENCE_KINDS)} evidence kinds, level1)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write:
        registry = json.loads(REGISTRY.read_text())
        REVIEW.write_text(render(contract_rows(), registry["phase18_composition"]))
    check()


if __name__ == "__main__":
    main()
