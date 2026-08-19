#!/usr/bin/env python3
"""Validate and render the Patch 18.2 complete target support tuple."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase18-target-support-contract"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
MODULE = ROOT / "compiler/mir_target_authority.gst"
CONTRACT = ROOT / "tests/cranelift/phase18_target_support_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase18_target_support_review.txt"

ELEMENTS = ["compiler", "runtime_package", "linker", "abi"]
MODULE_TOKENS = (
    "MirTargetSupportElement", "MirTargetSupportTuple",
    "mir_target_make_element", "mir_target_tuple_element_order",
    "mir_target_element_supported", "mir_target_tuple_is_complete",
    "mir_target_tuple_validate",
    "target_supported_without_complete_tuple",
    "target_unsupported_without_named_missing_elements",
)


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


def render(rows: list[dict[str, str]], support: dict) -> str:
    tuples = support["support_tuples"]
    complete = sum(t["support_decision"] == "supported" for t in tuples)
    header = (
        "Patch 18.2 — Complete Target Support Tuple\n\n"
        f"support_tuples\t{len(tuples)}\n"
        f"tuple_elements\t{len(support['tuple_elements'])}\n"
        f"declared_supported_targets\t{len(support['declared_supported_targets'])}\n"
        f"complete_tuples\t{complete}\n"
        f"rejection_classes\t{len(support['rejection_classes'])}\n\n"
    )
    return header + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n"
        for row in rows
    )


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    support = registry.get("phase18_target_support")
    if not isinstance(support, dict) or support.get("version") != "phase18_target_support_tuple_v1":
        fail("target support authority missing")

    module = MODULE.read_text() if MODULE.is_file() else ""
    for token in MODULE_TOKENS:
        if token not in module:
            fail(f"target authority module is missing: {token}")

    if support["tuple_elements"] != ELEMENTS or support["validation_order"] != ELEMENTS:
        fail("tuple element or validation order drifted")

    # Every tuple covers exactly the declared targets, once each.
    declared = [t["target_id"] for t in registry["phase18_target_authority"]["declared_triples"]]
    covered = [t["target_id"] for t in support["support_tuples"]]
    if sorted(covered) != sorted(declared):
        fail("support tuple coverage disagrees with the declared triple vocabulary")
    if len(set(covered)) != len(covered):
        fail("duplicate support tuple for a target")

    owners = support["element_owning_authorities"]
    if sorted(owners) != sorted(ELEMENTS):
        fail("element owning authority map drifted")
    # An element may name a registry authority that exists, or be explicitly
    # pending a later patch. It may not name an owner that was never built.
    for element, owner in owners.items():
        if owner.startswith("pending_patch18_"):
            continue
        if owner not in registry:
            fail(f"{element}: owning authority {owner} does not exist in the registry")

    for tuple_row in support["support_tuples"]:
        tid = tuple_row["tuple_id"]
        kinds = [e["element_kind"] for e in tuple_row["elements"]]
        if kinds != ELEMENTS:
            fail(f"{tid}: element order is not the frozen validation order")
        if not tuple_row["validation_order_frozen"]:
            fail(f"{tid}: validation order is not frozen")

        for element in tuple_row["elements"]:
            if element["owning_authority"] != owners[element["element_kind"]]:
                fail(f"{tid}: {element['element_kind']} names a different owner than the authority map")
            # Present and compatible without evidence is a claim, not support.
            if element["present"] and element["compatible"] and not element["evidence_id"]:
                fail(f"{tid}: {element['element_kind']} claims support with no evidence id")

        supported_elements = [
            e["element_kind"] for e in tuple_row["elements"]
            if e["present"] and e["compatible"] and e["evidence_id"] and e["owning_authority"]
        ]
        complete = len(supported_elements) == len(ELEMENTS)
        missing = tuple_row["missing_elements"]
        decision = tuple_row["support_decision"]

        if decision == "supported":
            if not complete:
                fail(f"{tid}: declared supported without a complete tuple")
            if missing:
                fail(f"{tid}: declared supported while naming missing elements")
        else:
            if complete:
                fail(f"{tid}: complete tuple recorded as unsupported")
            # A refusal that does not say what is absent is not a decision.
            if not missing:
                fail(f"{tid}: unsupported without naming its missing elements")
            expected = [e for e in ELEMENTS if e not in supported_elements]
            if sorted(missing) != sorted(expected):
                fail(f"{tid}: missing element list disagrees with the tuple contents")

    # The declared supported set is derived from the tuples, never asserted.
    derived = [t["target_id"] for t in support["support_tuples"] if t["support_decision"] == "supported"]
    if sorted(support["declared_supported_targets"]) != sorted(derived):
        fail("declared supported target set is not derived from complete tuples")

    for key, expected in (
        ("completeness_policy", "supported_requires_all_four_elements_present_compatible_and_evidenced"),
        ("capability_policy",
         "backend_architecture_capability_is_one_input_to_the_compiler_element_and_never_sufficient_alone"),
        ("partial_tuple_policy",
         "a_partial_tuple_must_not_reach_lowering_object_emission_or_link_planning"),
        ("narrowness_policy",
         "declared_supported_target_set_is_registry_derived_and_may_be_empty_until_later_patches_supply_elements"),
    ):
        if support.get(key) != expected:
            fail(f"{key} drifted")

    required = {
        "target_supported_without_complete_tuple", "target_unsupported_without_named_missing_elements",
        "target_support_order_not_frozen", "target_support_order_drift",
        "target_support_decision_drift", "target_support_missing_elements_drift",
        "target_support_element_without_owner_or_evidence",
    }
    if not required.issubset(set(support["rejection_classes"])):
        fail("rejection class inventory is incomplete")

    rows = contract_rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(rows, support):
        fail("generated review is stale; run --write")
    print(f"{GUARD}: ok ({len(support['support_tuples'])} tuples, "
          f"{len(support['declared_supported_targets'])} supported targets, level1)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write:
        registry = json.loads(REGISTRY.read_text())
        REVIEW.write_text(render(contract_rows(), registry["phase18_target_support"]))
    check()


if __name__ == "__main__":
    main()
