#!/usr/bin/env python3
"""Validate and render the Patch 18.11 symbol and relocation inspection."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase18-object-inspection-contract"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
CONTRACT = ROOT / "tests/cranelift/phase18_object_inspection_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase18_object_inspection_review.txt"


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
        "Patch 18.11 — Symbol and Relocation Inspection Evidence\n\n"
        f"symbol_fields\t{len(authority['symbol_fields'])}\n"
        f"relocation_fields\t{len(authority['relocation_fields'])}\n"
        f"comparison_sources\t3\n"
        f"rejection_classes\t{len(authority['rejection_classes'])}\n\n"
    )
    return header + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n"
        for row in rows
    )


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    authority = registry.get("phase18_object_inspection")
    if not isinstance(authority, dict) or authority.get("version") != "phase18_object_inspection_v1":
        fail("object inspection authority missing")

    # Inspection observes and compares; it never decides.
    if authority["inspection_role"] != "observe_and_compare_never_decide":
        fail("inspection role drifted")
    if authority["authority_ban"] != (
        "inspection_never_supplies_a_symbol_binding_relocation_kind_or_section_that_the_"
        "compiler_did_not_produce"
    ):
        fail("the inspection authority ban drifted")

    # A comparison source that does not exist means inspection compares against
    # nothing, which would make it decorative exactly where it must be load-bearing.
    for key in ("symbol_comparison_source", "relocation_comparison_source",
                "binding_comparison_source"):
        source = authority[key]
        if source not in registry:
            fail(f"{key} names {source}, which is not in the registry")

    if not authority["symbol_fields"] or not authority["relocation_fields"]:
        fail("inspection declares no fields to observe")
    for field_name in authority["symbol_fields"] + authority["relocation_fields"]:
        if not field_name.strip():
            fail("an inspected field is unnamed")

    # There must be something real to compare against, or every comparison
    # trivially succeeds.
    object_format = registry["phase18_object_format"]
    bindings = object_format["symbol_bindings"]
    sections = object_format["section_kinds"]
    kinds = {k for m in registry["phase18_relocation_model"]["relocation_models"]
             for k in m["relocation_kinds"]}
    if not bindings:
        fail("no symbol bindings are declared for inspection to compare against")
    if not sections:
        fail("no section kinds are declared for inspection to compare against")
    if not kinds:
        fail("no relocation kinds are declared for inspection to compare against")

    if authority["disagreement_policy"] != (
        "an_object_whose_inspected_contents_disagree_with_the_compiler_produced_plan_is_rejected"
    ):
        fail("disagreement policy drifted")
    if authority["validation_stage"] != "after_object_emission_and_before_linker_invocation":
        fail("inspection validation stage drifted")

    required = {"inspected_symbol_not_in_compiler_plan",
                "inspected_binding_outside_declared_vocabulary",
                "inspected_section_outside_declared_vocabulary",
                "inspected_relocation_kind_not_in_model",
                "inspected_relocation_in_disallowed_section",
                "inspection_used_as_semantic_authority",
                "inspected_object_missing_expected_symbol"}
    if not required.issubset(set(authority["rejection_classes"])):
        fail("rejection class inventory is incomplete")

    rows = contract_rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(rows, authority):
        fail("generated review is stale; run --write")
    print(f"{GUARD}: ok ({len(bindings)} bindings, {len(sections)} sections, "
          f"{len(kinds)} relocation kinds to compare against, level1)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write:
        registry = json.loads(REGISTRY.read_text())
        REVIEW.write_text(render(contract_rows(), registry["phase18_object_inspection"]))
    check()


if __name__ == "__main__":
    main()
