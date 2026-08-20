#!/usr/bin/env python3
"""Validate and render the Patch 18.12 debug information strategy."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase18-debug-info-contract"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
CONTRACT = ROOT / "tests/cranelift/phase18_debug_info_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase18_debug_info_review.txt"


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
    plans = authority["debug_plans"]
    header = (
        "Patch 18.12 — Debug Information Strategy\n\n"
        f"debug_plans\t{len(plans)}\n"
        f"debug_levels\t{len(authority['debug_levels'])}\n"
        f"included_record_kinds\t{len(plans[0]['included_record_kinds'])}\n"
        f"excluded_record_kinds\t{len(plans[0]['excluded_record_kinds'])}\n"
        f"fidelity_non_claims\t{len(authority['fidelity_non_claims'])}\n\n"
    )
    return header + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n"
        for row in rows
    )


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    authority = registry.get("phase18_debug_information")
    if not isinstance(authority, dict) or authority.get("version") != "phase18_debug_information_v1":
        fail("debug information authority missing")

    triples = {t["target_id"]: t for t in registry["phase18_target_authority"]["declared_triples"]}
    formats = {d["target_id"]: d["object_format"]
               for d in registry["phase18_object_format"]["format_descriptors"]}
    plans = authority["debug_plans"]

    covered = [p["target_id"] for p in plans]
    if sorted(covered) != sorted(triples):
        fail("debug plan coverage disagrees with the declared triple vocabulary")
    if len(set(covered)) != len(covered):
        fail("duplicate debug plan for a target")

    levels = set(authority["debug_levels"])
    for plan in plans:
        triple = triples[plan["target_id"]]
        if plan["target_id"] not in formats:
            fail(f"{triple['target_triple']}: no object format descriptor for this target")
        if plan["derived_from"] != "object_format_in_the_phase18_object_format_authority":
            fail(f"{triple['target_triple']}: debug format is not derived from the object format")
        if plan["debug_level"] not in levels:
            fail(f"{triple['target_triple']}: debug level is outside the declared vocabulary")

        included = set(plan["included_record_kinds"])
        excluded = set(plan["excluded_record_kinds"])
        if not included:
            fail(f"{triple['target_triple']}: debug plan includes no record kinds")
        # Included and excluded must be disjoint, or a record kind is both
        # promised and disclaimed.
        if included & excluded:
            fail(f"{triple['target_triple']}: a record kind is both included and excluded")
        if not excluded:
            fail(f"{triple['target_triple']}: a debug plan must say what it does not emit")

    # The fidelity limits are stated where the capability is defined rather than
    # deferred to the closure.
    non_claims = authority["fidelity_non_claims"]
    if len(non_claims) < 5:
        fail("the fidelity non-claim inventory is incomplete")
    for claim in non_claims:
        if not claim.strip():
            fail("a fidelity non-claim is unnamed")

    for key, expected in (
        ("selection_policy", "the_compiler_selects_the_debug_plan_and_the_backend_never_infers_one"),
        ("emission_policy",
         "only_declared_record_kinds_are_emitted_and_an_undeclared_kind_is_rejected"),
    ):
        if authority.get(key) != expected:
            fail(f"{key} drifted")

    required = {"debug_level_unknown", "debug_record_kind_undeclared",
                "debug_format_disagrees_with_object_format", "debug_plan_inferred_by_backend",
                "debug_plan_missing_for_declared_target"}
    if not required.issubset(set(authority["rejection_classes"])):
        fail("rejection class inventory is incomplete")

    rows = contract_rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(rows, authority):
        fail("generated review is stale; run --write")
    print(f"{GUARD}: ok ({len(plans)} plans, levels={','.join(authority['debug_levels'])}, "
          f"{len(non_claims)} non-claims, level1)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write:
        registry = json.loads(REGISTRY.read_text())
        REVIEW.write_text(render(contract_rows(), registry["phase18_debug_information"]))
    check()


if __name__ == "__main__":
    main()
