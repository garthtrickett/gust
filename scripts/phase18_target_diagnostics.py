#!/usr/bin/env python3
"""Validate and render the Patch 18.10 unsupported-target diagnostics."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase18-target-diagnostic-contract"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
CONTRACT = ROOT / "tests/cranelift/phase18_target_diagnostic_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase18_target_diagnostic_review.txt"


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
    diagnostics = authority["target_diagnostics"]
    supported = sum(d["support_decision"] == "supported" for d in diagnostics)
    header = (
        "Patch 18.10 — Unsupported-Target Detection and Diagnostics\n\n"
        f"target_diagnostics\t{len(diagnostics)}\n"
        f"supported_targets\t{supported}\n"
        f"unsupported_targets\t{len(diagnostics) - supported}\n"
        f"rejection_classes\t{len(authority['rejection_classes'])}\n\n"
    )
    return header + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n"
        for row in rows
    )


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    authority = registry.get("phase18_target_diagnostics")
    if not isinstance(authority, dict) or authority.get("version") != "phase18_target_diagnostics_v1":
        fail("target diagnostics authority missing")

    triples = {t["target_id"]: t for t in registry["phase18_target_authority"]["declared_triples"]}
    linkers = {d["target_id"]: d for d in registry["phase18_linker_policy"]["linker_descriptors"]}
    packages = {p["target_id"] for p in registry["phase17_runtime_package_authority"]["target_packages"]}
    abis = {s["target_id"] for s in registry["phase18_target_abi_selection"]["abi_selections"]}
    diagnostics = authority["target_diagnostics"]

    covered = [d["target_id"] for d in diagnostics]
    if sorted(covered) != sorted(triples):
        fail("diagnostic coverage disagrees with the declared triple vocabulary")
    if len(set(covered)) != len(covered):
        fail("duplicate diagnostic for a target")

    for diagnostic in diagnostics:
        tid = diagnostic["target_id"]
        triple = triples[tid]

        # The missing element set is recomputed from the owning authorities, so
        # a diagnostic can neither invent a gap nor omit a real one.
        missing = []
        if tid not in packages:
            missing.append("runtime_package")
        if linkers[tid]["discovery_result"] != "discovered":
            missing.append("linker")
        if tid not in abis:
            missing.append("abi")

        if sorted(diagnostic["missing_tuple_elements"]) != sorted(missing):
            fail(f"{triple['target_triple']}: missing elements "
                 f"{diagnostic['missing_tuple_elements']} disagree with the authorities, "
                 f"which report {missing}")

        supported = not missing
        expected = "supported" if supported else "unsupported_missing_elements"
        if diagnostic["support_decision"] != expected:
            fail(f"{triple['target_triple']}: support decision is not derived from the tuple")

        if supported:
            if diagnostic["rejection_class"]:
                fail(f"{triple['target_triple']}: a supported target carries a rejection class")
        else:
            # An unsupported target names a specific class, never a generic refusal.
            if not diagnostic["rejection_class"]:
                fail(f"{triple['target_triple']}: unsupported without a rejection class")
            if diagnostic["rejection_class"] not in authority["rejection_classes"]:
                fail(f"{triple['target_triple']}: rejection class outside the declared inventory")
        if diagnostic["failure_stage"] != authority["failure_stage"]:
            fail(f"{triple['target_triple']}: failure stage disagrees with the authority")

    if authority["failure_stage"] != "before_driver_discovery":
        fail("diagnostic failure stage drifted")
    for key, expected in (
        ("stage_policy",
         "an_unsupported_target_is_refused_before_native_driver_access_object_creation_"
         "linker_invocation_and_output_replacement"),
        ("derivation_policy",
         "each_diagnostic_names_the_tuple_elements_the_target_actually_lacks_rather_than_"
         "a_generic_refusal"),
        ("attempt_policy", "an_unsupported_target_is_never_attempted_and_then_failed_later"),
        ("output_preservation_policy", "existing_output_survives_every_rejection_class"),
    ):
        if authority.get(key) != expected:
            fail(f"{key} drifted")

    required = {"unknown_triple", "unsupported_architecture", "missing_runtime_package",
                "missing_linker", "incompatible_abi", "unavailable_link_mode", "incomplete_tuple"}
    if not required.issubset(set(authority["rejection_classes"])):
        fail("rejection class inventory is incomplete")

    rows = contract_rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(rows, authority):
        fail("generated review is stale; run --write")
    supported = sum(d["support_decision"] == "supported" for d in diagnostics)
    print(f"{GUARD}: ok ({len(diagnostics)} diagnostics, {supported} supported, "
          f"{len(diagnostics) - supported} unsupported, level1)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write:
        registry = json.loads(REGISTRY.read_text())
        REVIEW.write_text(render(contract_rows(), registry["phase18_target_diagnostics"]))
    check()


if __name__ == "__main__":
    main()
