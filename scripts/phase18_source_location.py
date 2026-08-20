#!/usr/bin/env python3
"""Validate and render the Patch 18.13 source-location preservation."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase18-source-location-contract"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
CONTRACT = ROOT / "tests/cranelift/phase18_source_location_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase18_source_location_review.txt"


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
        "Patch 18.13 — Source-Location Preservation\n\n"
        f"record_fields\t{len(authority['record_fields'])}\n"
        f"declared_gaps\t{len(authority['declared_gaps'])}\n"
        f"required_when\t{authority['required_when']}\n"
        f"rejection_classes\t{len(authority['rejection_classes'])}\n\n"
    )
    return header + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n"
        for row in rows
    )


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    authority = registry.get("phase18_source_location")
    if not isinstance(authority, dict) or authority.get("version") != "phase18_source_location_v1":
        fail("source location authority missing")

    debug = registry["phase18_debug_information"]
    levels = set(debug["debug_levels"])

    # Locations are required at a declared debug level, not at a phrase. A
    # requirement naming a level that does not exist can never be satisfied.
    required_when = authority["required_when"]
    if required_when not in levels:
        fail(f"source locations are required at {required_when}, which is not a declared debug level")

    # And only where the plan actually emits a line table, or the requirement
    # would demand records the plan never produces.
    for plan in debug["debug_plans"]:
        if plan["debug_level"] != required_when:
            continue
        if "line_table" not in plan["included_record_kinds"]:
            fail(f"{plan['target_id']}: source locations are required at a level "
                 f"whose plan emits no line table")

    if not authority["record_fields"]:
        fail("the source location record declares no fields")
    for field_name in authority["record_fields"]:
        if not field_name.strip():
            fail("a source location record field is unnamed")

    # A gap is a place a location deliberately does not survive. Each must say
    # why, or it is an undocumented hole rather than a decision.
    gaps = authority["declared_gaps"]
    if not gaps:
        fail("no declared gaps; a phase preserving everything must say so explicitly")
    for gap in gaps:
        if not gap.get("gap") or not gap.get("reason"):
            fail("a declared gap is missing its name or its reason")

    for key, expected in (
        ("preservation_policy",
         "a_source_location_produced_by_the_compiler_survives_lowering_wherever_the_"
         "debug_plan_requires_it"),
        ("production_policy",
         "canonical_mir_carries_compiler_produced_source_locations_and_never_backend_"
         "reconstructed_ones"),
    ):
        if authority.get(key) != expected:
            fail(f"{key} drifted")

    required = {"source_location_lost_in_lowering",
                "source_location_duplicated_for_one_instruction",
                "source_location_fabricated_without_a_source_span",
                "source_location_reconstructed_by_backend",
                "source_location_missing_where_the_debug_plan_requires_it"}
    if not required.issubset(set(authority["rejection_classes"])):
        fail("rejection class inventory is incomplete")

    rows = contract_rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(rows, authority):
        fail("generated review is stale; run --write")
    print(f"{GUARD}: ok ({len(authority['record_fields'])} record fields, "
          f"{len(gaps)} declared gaps, required at {required_when}, level1)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write:
        registry = json.loads(REGISTRY.read_text())
        REVIEW.write_text(render(contract_rows(), registry["phase18_source_location"]))
    check()


if __name__ == "__main__":
    main()
