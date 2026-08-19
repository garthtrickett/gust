#!/usr/bin/env python3
"""Validate and render the Patch 18.8 static and dynamic link modes."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase18-link-mode-contract"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
CONTRACT = ROOT / "tests/cranelift/phase18_link_mode_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase18_link_mode_review.txt"

# A mode is available only when a runtime package form provides it. This map is
# the derivation, so availability is recomputed rather than trusted.
FORM_TO_MODE = {"static_archive": "static", "shared_library": "dynamic"}


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
    decisions = authority["link_mode_decisions"]
    modes = sorted({m for d in decisions for m in d["available_modes"]})
    header = (
        "Patch 18.8 — Static and Dynamic Runtime Linking Modes\n\n"
        f"link_mode_decisions\t{len(decisions)}\n"
        f"declared_modes\t{len(authority['link_modes'])}\n"
        f"available_modes\t{len(modes)}\n"
        f"rejection_classes\t{len(authority['rejection_classes'])}\n\n"
    )
    return header + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n"
        for row in rows
    )


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    authority = registry.get("phase18_link_mode")
    if not isinstance(authority, dict) or authority.get("version") != "phase18_link_mode_v1":
        fail("link mode authority missing")

    if authority["form_to_mode"] != FORM_TO_MODE:
        fail("the package form to link mode derivation drifted")

    packages = {p["target_id"]: p
                for p in registry["phase17_runtime_package_authority"]["target_packages"]}
    triples = {t["target_id"]: t for t in registry["phase18_target_authority"]["declared_triples"]}
    decisions = authority["link_mode_decisions"]

    covered = [d["target_id"] for d in decisions]
    if sorted(covered) != sorted(triples):
        fail("link mode coverage disagrees with the declared triple vocabulary")
    if len(set(covered)) != len(covered):
        fail("duplicate link mode decision for a target")

    for decision in decisions:
        tid = decision["target_id"]
        triple = triples[tid]
        package = packages[tid]

        # Availability is recomputed from the package form, so a target cannot
        # advertise a mode no package backs.
        expected = sorted({FORM_TO_MODE[package["package_form"]]})
        if sorted(decision["available_modes"]) != expected:
            fail(f"{triple['target_triple']}: available modes {decision['available_modes']} "
                 f"are not derived from the package form {package['package_form']}")
        if decision["required_package_form"] != package["package_form"]:
            fail(f"{triple['target_triple']}: required package form disagrees with Phase 17")
        if decision["selected_mode"] not in decision["available_modes"]:
            fail(f"{triple['target_triple']}: selected mode is not available for this target")
        if decision["selected_mode"] not in authority["link_modes"]:
            fail(f"{triple['target_triple']}: selected mode is outside the declared vocabulary")
        if not decision["unavailable_mode_reason"]:
            fail(f"{triple['target_triple']}: an unavailable mode must state why")

    if authority["availability_derivation"] != (
        "a_mode_is_available_only_when_a_phase17_runtime_package_form_provides_it"
    ):
        fail("availability derivation drifted")
    if authority["substitution_policy"] != (
        "an_unavailable_mode_is_refused_and_never_silently_substituted"
    ):
        fail("substitution policy drifted")
    if authority["validation_stage"] != "before_linker_invocation_and_before_output_replacement":
        fail("link mode validation stage drifted")

    required = {"link_mode_unavailable_for_target", "link_mode_silently_substituted",
                "link_mode_unknown", "link_mode_package_form_mismatch",
                "link_mode_selected_without_package_evidence"}
    if not required.issubset(set(authority["rejection_classes"])):
        fail("rejection class inventory is incomplete")

    rows = contract_rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(rows, authority):
        fail("generated review is stale; run --write")
    modes = sorted({m for d in decisions for m in d["available_modes"]})
    print(f"{GUARD}: ok ({len(decisions)} decisions, available={','.join(modes)}, level1)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write:
        registry = json.loads(REGISTRY.read_text())
        REVIEW.write_text(render(contract_rows(), registry["phase18_link_mode"]))
    check()


if __name__ == "__main__":
    main()
