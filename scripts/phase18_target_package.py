#!/usr/bin/env python3
"""Validate and render the Patch 18.6 target runtime package selection."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase18-target-package-contract"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
CONTRACT = ROOT / "tests/cranelift/phase18_target_package_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase18_target_package_review.txt"


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
    selections = authority["package_selections"]
    forms = sorted({s["package_form"] for s in selections})
    header = (
        "Patch 18.6 — Target-Specific Runtime Package Selection\n\n"
        f"package_selections\t{len(selections)}\n"
        f"package_forms\t{len(forms)}\n"
        f"enforcement_evidence\t{len(authority['enforcement_evidence'])}\n"
        f"rejection_classes\t{len(authority['rejection_classes'])}\n\n"
    )
    return header + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n"
        for row in rows
    )


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    authority = registry.get("phase18_target_package_selection")
    if not isinstance(authority, dict) or authority.get("version") != "phase18_target_package_selection_v1":
        fail("target package selection authority missing")

    # The consumed authority must be able to refuse, not merely record.
    consumed = registry.get(authority["consumed_authority"])
    if not isinstance(consumed, dict):
        fail(f"consumed authority {authority['consumed_authority']} is not in the registry")
    declared = set(consumed.get("rejection_classes", []))
    for evidence in authority["enforcement_evidence"]:
        if evidence not in declared:
            fail(f"{evidence} is not a rejection class the Phase 17 package authority declares")

    packages = {p["target_id"]: p for p in consumed["target_packages"]}
    formats = {d["target_id"]: d["object_format"]
               for d in registry["phase18_object_format"]["format_descriptors"]}
    triples = {t["target_id"]: t for t in registry["phase18_target_authority"]["declared_triples"]}
    selections = authority["package_selections"]

    covered = [s["target_id"] for s in selections]
    if sorted(covered) != sorted(triples):
        fail("package selection coverage disagrees with the declared triple vocabulary")
    if len(set(covered)) != len(covered):
        fail("duplicate package selection for a target")

    for selection in selections:
        tid = selection["target_id"]
        triple = triples[tid]
        package = packages.get(tid)
        if package is None:
            fail(f"{triple['target_triple']}: no Phase 17 package for this target")
        if selection["selected_package_version"] != package["package_version"]:
            fail(f"{triple['target_triple']}: selected package version disagrees with Phase 17")
        if selection["package_form"] != package["package_form"]:
            fail(f"{triple['target_triple']}: selected package form disagrees with Phase 17")
        # Phase 17 spells the format with different casing, so normalise
        # explicitly rather than relying on an accident of comparison.
        if package["object_format"].lower() != formats[tid]:
            fail(f"{triple['target_triple']}: package object format {package['object_format']} "
                 f"disagrees with the Patch 18.3 descriptor {formats[tid]}")
        if selection["owning_authority"] != authority["consumed_authority"]:
            fail(f"{triple['target_triple']}: selection does not name the consumed authority as owner")
        if selection["compatibility_decision"] not in {"compatible", "incompatible"}:
            fail(f"{triple['target_triple']}: package compatibility decision is not a decision")

    if authority["validation_stage"] != "before_linker_invocation_and_before_output_replacement":
        fail("package selection validation stage drifted")
    if authority["selection_policy"] != (
        "phase18_selects_an_existing_phase17_package_and_never_defines_runtime_symbol_identity_or_version"
    ):
        fail("selection policy drifted")

    required = {"target_package_missing", "target_package_wrong_target",
                "target_package_object_format_mismatch", "target_package_incompatible",
                "target_package_defined_by_phase18", "target_package_selected_after_linker_invocation"}
    if not required.issubset(set(authority["rejection_classes"])):
        fail("rejection class inventory is incomplete")

    rows = contract_rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(rows, authority):
        fail("generated review is stale; run --write")
    forms = sorted({s["package_form"] for s in selections})
    print(f"{GUARD}: ok ({len(selections)} selections, forms={','.join(forms)}, level1)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write:
        registry = json.loads(REGISTRY.read_text())
        REVIEW.write_text(render(contract_rows(), registry["phase18_target_package_selection"]))
    check()


if __name__ == "__main__":
    main()
