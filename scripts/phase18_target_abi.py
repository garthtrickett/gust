#!/usr/bin/env python3
"""Validate and render the Patch 18.5 target ABI selection."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase18-target-abi-contract"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
CONTRACT = ROOT / "tests/cranelift/phase18_target_abi_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase18_target_abi_review.txt"


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
    selections = authority["abi_selections"]
    header = (
        "Patch 18.5 — Target-Specific ABI Selection\n\n"
        f"abi_selections\t{len(selections)}\n"
        f"available_abi_ids\t{len(authority['available_abi_ids'])}\n"
        f"rejection_classes\t{len(authority['rejection_classes'])}\n\n"
    )
    return header + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n"
        for row in rows
    )


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    authority = registry.get("phase18_target_abi_selection")
    if not isinstance(authority, dict) or authority.get("version") != "phase18_target_abi_selection_v1":
        fail("target ABI selection authority missing")

    # The consumed authority must be a module that can actually refuse a wrong
    # convention. An owner that only stores a field owns nothing.
    consumed = ROOT / authority["consumed_authority"]
    if not consumed.is_file() or consumed.is_symlink():
        fail(f"consumed authority {authority['consumed_authority']} does not exist")
    consumed_text = consumed.read_text()
    if authority["enforcement_evidence"] not in consumed_text:
        fail(f"{authority['consumed_authority']} does not contain its declared "
             f"enforcement evidence {authority['enforcement_evidence']}")

    # Phase 18 may select only what Phase 16 accepts. Anything else would be
    # Phase 18 defining ABI semantics.
    available = authority["available_abi_ids"]
    if not available:
        fail("no ABI is available to select")
    for abi_id in available:
        if f'"{abi_id}"' not in consumed_text:
            fail(f"{abi_id} is not accepted by {authority['consumed_authority']}")

    triples = {t["target_id"]: t for t in registry["phase18_target_authority"]["declared_triples"]}
    selections = authority["abi_selections"]
    covered = [s["target_id"] for s in selections]
    if sorted(covered) != sorted(triples):
        fail("ABI selection coverage disagrees with the declared triple vocabulary")
    if len(set(covered)) != len(covered):
        fail("duplicate ABI selection for a target")

    for selection in selections:
        triple = triples[selection["target_id"]]
        if selection["selected_abi_id"] not in available:
            fail(f"{triple['target_triple']}: selected ABI is not one Phase 16 accepts")
        if selection["owning_authority"] != authority["consumed_authority"]:
            fail(f"{triple['target_triple']}: selection does not name the consumed authority as owner")
        if selection["compatibility_decision"] not in {"compatible", "incompatible"}:
            fail(f"{triple['target_triple']}: ABI compatibility decision is not a decision")
        # Claiming a platform convention would be selecting something Phase 16
        # does not offer, which is Phase 18 defining ABI semantics.
        if selection["platform_convention_status"] != "deferred_to_a_later_abi_phase":
            fail(f"{triple['target_triple']}: platform calling conventions are not Phase 16's to offer yet")

    if authority["selection_policy"] != (
        "phase18_selects_an_existing_phase16_abi_and_never_defines_abi_placement_"
        "classification_or_transport"
    ):
        fail("selection policy drifted")
    if authority["platform_convention_policy"] != (
        "platform_specific_calling_conventions_are_not_declared_by_phase16_so_they_"
        "remain_deferred_and_no_target_may_select_one"
    ):
        fail("platform convention policy drifted")

    required = {"target_abi_undeclared_by_phase16", "target_abi_incompatible",
                "target_abi_selection_missing", "target_abi_defined_by_phase18",
                "target_abi_platform_convention_selected_without_phase16_support"}
    if not required.issubset(set(authority["rejection_classes"])):
        fail("rejection class inventory is incomplete")

    rows = contract_rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(rows, authority):
        fail("generated review is stale; run --write")
    print(f"{GUARD}: ok ({len(selections)} selections, "
          f"{len(available)} available ABI, level1)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write:
        registry = json.loads(REGISTRY.read_text())
        REVIEW.write_text(render(contract_rows(), registry["phase18_target_abi_selection"]))
    check()


if __name__ == "__main__":
    main()
