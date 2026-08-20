#!/usr/bin/env python3
"""Validate and render the Patch 18.15 reproducible object and artifact output."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase18-reproducibility-contract"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
CONTRACT = ROOT / "tests/cranelift/phase18_reproducibility_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase18_reproducibility_review.txt"


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
        "Patch 18.15 — Reproducible Object and Artifact Output\n\n"
        f"reproducible_inputs\t{len(authority['reproducible_inputs'])}\n"
        f"reproducible_fields\t{len(authority['reproducible_fields'])}\n"
        f"excluded_fields\t{len(authority['excluded_fields'])}\n"
        f"normalisation_rules\t{len(authority['normalisation_rules'])}\n"
        f"rejection_classes\t{len(authority['rejection_classes'])}\n\n"
    )
    return header + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n"
        for row in rows
    )


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    authority = registry.get("phase18_reproducibility")
    if not isinstance(authority, dict) or authority.get("version") != "phase18_reproducibility_v1":
        fail("reproducibility authority missing")

    inputs = set(authority["reproducible_inputs"])
    # Both of these change emitted bytes. A byte guarantee that ignores them is
    # not a guarantee; it is a comparison of two builds that happened to agree.
    for required_input in ("optimisation_level", "debug_plan"):
        if required_input not in inputs:
            fail(f"{required_input} is not a reproducibility input, yet it changes emitted bytes")
    if "target_id" not in inputs:
        fail("the target is not a reproducibility input")

    reproducible = authority["reproducible_fields"]
    excluded = authority["excluded_fields"]
    if not reproducible:
        fail("no reproducible fields; the guarantee covers nothing")
    if not excluded:
        fail("no excluded fields; a byte guarantee that excludes nothing must say so")

    # Every exclusion states why, or it is a silently narrowed guarantee.
    for row in excluded:
        if not row.get("field") or not row.get("reason"):
            fail("an excluded field is missing its name or its reason")

    overlap = set(reproducible) & {row["field"] for row in excluded}
    if overlap:
        fail(f"these fields are both guaranteed and disclaimed: {sorted(overlap)}")

    if not authority["normalisation_rules"]:
        fail("no normalisation rules; embedded paths and ordering would vary freely")

    if authority["comparison_method"] != (
        "two_builds_of_the_same_input_target_and_level_are_compared_byte_for_byte_over_"
        "the_reproducible_fields"
    ):
        fail("comparison method drifted")

    required = {"reproducible_field_varied_between_builds", "excluded_field_not_declared",
                "normalisation_rule_not_applied",
                "reproducibility_claimed_without_a_repeated_build",
                "nondeterministic_order_in_a_reproducible_field",
                "reproducibility_input_undeclared"}
    if not required.issubset(set(authority["rejection_classes"])):
        fail("rejection class inventory is incomplete")

    rows = contract_rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(rows, authority):
        fail("generated review is stale; run --write")
    print(f"{GUARD}: ok ({len(inputs)} inputs, {len(reproducible)} reproducible fields, "
          f"{len(excluded)} declared exclusions, level1)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write:
        registry = json.loads(REGISTRY.read_text())
        REVIEW.write_text(render(contract_rows(), registry["phase18_reproducibility"]))
    check()


if __name__ == "__main__":
    main()
