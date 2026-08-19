#!/usr/bin/env python3
"""Validate and render the Patch 18.7 linker discovery and invocation policy."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase18-linker-policy-contract"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
CONTRACT = ROOT / "tests/cranelift/phase18_linker_policy_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase18_linker_policy_review.txt"

# Discovery is ordered and deterministic. CC remains available but is a
# validated step in that order rather than an unvalidated escape hatch.
DISCOVERY_ORDER = ["declared_target_linker", "validated_cc_environment_override",
                   "declared_default_driver"]
FORMAT_BY_OS = {"linux": "elf", "darwin": "macho"}


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
    descriptors = authority["linker_descriptors"]
    discovered = sum(d["discovery_result"] == "discovered" for d in descriptors)
    header = (
        "Patch 18.7 — Linker Discovery, Selection, and Invocation Policy\n\n"
        f"linker_descriptors\t{len(descriptors)}\n"
        f"discovered_linkers\t{discovered}\n"
        f"discovery_steps\t{len(authority['discovery_order'])}\n"
        f"permitted_arguments\t{len(authority['permitted_arguments'])}\n"
        f"rejection_classes\t{len(authority['rejection_classes'])}\n\n"
    )
    return header + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n"
        for row in rows
    )


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    authority = registry.get("phase18_linker_policy")
    if not isinstance(authority, dict) or authority.get("version") != "phase18_linker_policy_v1":
        fail("linker policy authority missing")

    if authority["discovery_order"] != DISCOVERY_ORDER:
        fail("linker discovery order drifted")
    if authority["invocation_owner"] != "phase9g_artifact_planner":
        fail("linker invocation owner drifted from Phase 9G")

    # Phase 9G must still own execution. Phase 18 plans the invocation only.
    justfile = (ROOT / "justfile").read_text()
    if "guard-cranelift-phase9g-close" not in justfile:
        fail("the Phase 9G artifact ownership guard is absent")

    triples = {t["target_id"]: t for t in registry["phase18_target_authority"]["declared_triples"]}
    formats = {d["target_id"]: d["object_format"]
               for d in registry["phase18_object_format"]["format_descriptors"]}
    descriptors = authority["linker_descriptors"]

    covered = [d["target_id"] for d in descriptors]
    if sorted(covered) != sorted(triples):
        fail("linker descriptor coverage disagrees with the declared triple vocabulary")
    if len(set(covered)) != len(covered):
        fail("duplicate linker descriptor for a target")

    permitted = set(authority["permitted_arguments"])
    for descriptor in descriptors:
        tid = descriptor["target_id"]
        triple = triples[tid]

        if descriptor["discovery_order"] != DISCOVERY_ORDER:
            fail(f"{triple['target_triple']}: descriptor discovery order disagrees with the authority")
        if descriptor["discovery_result"] not in {"discovered", "undiscovered_no_cross_linker_declared"}:
            fail(f"{triple['target_triple']}: discovery result is not a declared outcome")

        # The linker must support the object format this target actually uses.
        expected = FORMAT_BY_OS[triple["operating_system"]]
        if expected != formats[tid]:
            fail(f"{triple['target_triple']}: object format derivation disagrees with Patch 18.3")
        if expected not in descriptor["supported_object_formats"]:
            fail(f"{triple['target_triple']}: linker does not support the target's object format")

        if not set(descriptor["permitted_arguments"]).issubset(permitted):
            fail(f"{triple['target_triple']}: invocation argument outside the declared vocabulary")
        if descriptor["invocation_owner"] != "phase9g_artifact_planner":
            fail(f"{triple['target_triple']}: invocation owner is not Phase 9G")

    if authority["discovery_policy"] != (
        "deterministic_ordered_discovery_never_an_unvalidated_environment_variable_alone"
    ):
        fail("discovery policy drifted")
    if authority["invocation_ownership_policy"] != (
        "phase18_plans_the_invocation_and_phase9g_executes_it"
    ):
        fail("invocation ownership policy drifted")
    if authority["validation_stage"] != "before_linker_invocation_and_before_output_replacement":
        fail("linker validation stage drifted")

    required = {"linker_undiscovered", "linker_unsupported_object_format",
                "linker_argument_outside_vocabulary", "linker_selected_from_unvalidated_environment",
                "linker_invoked_by_phase18", "linker_target_mismatch"}
    if not required.issubset(set(authority["rejection_classes"])):
        fail("rejection class inventory is incomplete")

    # Patch 18.0 recorded both linker host assumptions; this row owns them.
    hosts = registry["opening_snapshots"]["phase18"]["host_assumption_inventory"]
    owned = {h["id"] for h in hosts if h["owning_phase18_entry_id"] == "p18_linker_policy"}
    for assumption in ("p18_host_linker_driver_env", "p18_host_linker_invocation"):
        if assumption not in owned:
            fail(f"{assumption} is not owned by the linker policy row")

    rows = contract_rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(rows, authority):
        fail("generated review is stale; run --write")
    discovered = sum(d["discovery_result"] == "discovered" for d in descriptors)
    print(f"{GUARD}: ok ({len(descriptors)} descriptors, {discovered} discovered, level1)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write:
        registry = json.loads(REGISTRY.read_text())
        REVIEW.write_text(render(contract_rows(), registry["phase18_linker_policy"]))
    check()


if __name__ == "__main__":
    main()
