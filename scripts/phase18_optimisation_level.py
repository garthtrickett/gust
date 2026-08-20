#!/usr/bin/env python3
"""Validate and render the Patch 18.14 optimisation-level policy."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase18-optimisation-level-contract"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
CONTRACT = ROOT / "tests/cranelift/phase18_optimisation_level_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase18_optimisation_level_review.txt"


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
    header = (
        "Patch 18.14 — Optimisation-Level Policy\n\n"
        f"declared_levels\t{len(authority['declared_levels'])}\n"
        f"observable_behaviour\t{len(authority['observable_behaviour'])}\n"
        f"permitted_to_vary\t{len(authority['permitted_to_vary'])}\n"
        f"rejection_classes\t{len(authority['rejection_classes'])}\n\n"
    )
    return header + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n"
        for row in rows
    )


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    authority = registry.get("phase18_optimisation_level")
    if not isinstance(authority, dict) or authority.get("version") != "phase18_optimisation_level_v1":
        fail("optimisation level authority missing")

    levels = authority["declared_levels"]
    transformations = authority["level_transformations"]
    if sorted(transformations) != sorted(levels):
        fail("the transformation map does not cover exactly the declared levels")
    # The unoptimised level must actually be unoptimised, or the comparison it
    # anchors is between two optimised builds.
    if transformations.get("none"):
        fail("the none level declares transformations")
    for level, items in transformations.items():
        if len(set(items)) != len(items):
            fail(f"{level}: duplicate transformation")

    observable = set(authority["observable_behaviour"])
    varying = set(authority["permitted_to_vary"])
    if not observable:
        fail("no observable behaviour is declared, so equivalence claims nothing")
    # A field both fixed and free makes the equivalence claim untestable.
    overlap = observable & varying
    if overlap:
        fail(f"these are both required to stay fixed and permitted to vary: {sorted(overlap)}")

    # A level incompatible with the selected debug plan is rejected, so the two
    # authorities must at least agree the debug levels exist.
    debug_levels = set(registry["phase18_debug_information"]["debug_levels"])
    if not debug_levels:
        fail("no debug levels declared for the compatibility policy to reference")

    for key, expected in (
        ("selection_policy", "the_compiler_selects_the_level_and_carries_it_in_the_native_request"),
        ("equivalence_policy", "observable_program_behaviour_is_identical_across_declared_levels"),
        ("debug_compatibility_policy",
         "a_level_incompatible_with_the_selected_debug_plan_is_rejected"),
    ):
        if authority.get(key) != expected:
            fail(f"{key} drifted")

    required = {"optimisation_level_unknown", "optimisation_level_transformation_undeclared",
                "optimisation_level_changed_observable_behaviour",
                "optimisation_level_incompatible_with_debug_plan",
                "optimisation_level_selected_by_backend"}
    if not required.issubset(set(authority["rejection_classes"])):
        fail("rejection class inventory is incomplete")

    rows = contract_rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(rows, authority):
        fail("generated review is stale; run --write")
    print(f"{GUARD}: ok ({len(levels)} levels, {len(observable)} observable, "
          f"{len(varying)} permitted to vary, level1)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write:
        registry = json.loads(REGISTRY.read_text())
        REVIEW.write_text(render(contract_rows(), registry["phase18_optimisation_level"]))
    check()


if __name__ == "__main__":
    main()
