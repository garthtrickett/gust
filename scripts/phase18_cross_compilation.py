#!/usr/bin/env python3
"""Validate and render the Patch 18.9 cross-compilation policy."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase18-cross-compilation-contract"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
CONTRACT = ROOT / "tests/cranelift/phase18_cross_compilation_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase18_cross_compilation_review.txt"


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
    pairs = authority["host_target_pairs"]
    cross = sum(p["classification"] == "cross" for p in pairs)
    header = (
        "Patch 18.9 — Cross-Compilation Policy and Host/Target Separation\n\n"
        f"host_target_pairs\t{len(pairs)}\n"
        f"cross_candidates\t{cross}\n"
        f"declared_cross_pairs\t{len(authority['declared_cross_pairs'])}\n"
        f"host_leakage_bans\t{len(authority['host_leakage_bans'])}\n"
        f"rejection_classes\t{len(authority['rejection_classes'])}\n\n"
    )
    return header + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n"
        for row in rows
    )


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    authority = registry.get("phase18_cross_compilation")
    if not isinstance(authority, dict) or authority.get("version") != "phase18_cross_compilation_v1":
        fail("cross compilation authority missing")

    triples = {t["target_id"]: t for t in registry["phase18_target_authority"]["declared_triples"]}
    linkers = {d["target_id"]: d for d in registry["phase18_linker_policy"]["linker_descriptors"]}
    host = authority["host_triple"]
    pairs = authority["host_target_pairs"]

    declared_triples = sorted(t["target_triple"] for t in triples.values())
    if sorted(p["target_triple"] for p in pairs) != declared_triples:
        fail("host target pair coverage disagrees with the declared triple vocabulary")
    if host not in declared_triples:
        fail("the host triple is not one of the declared targets")

    by_triple = {t["target_triple"]: tid for tid, t in triples.items()}
    for pair in pairs:
        triple = pair["target_triple"]
        # Classification is derived: a pair is cross exactly when the target
        # triple differs from the host triple.
        expected = "cross" if triple != host else "native"
        if pair["classification"] != expected:
            fail(f"{triple}: classification is not derived from the host and target triples")

        discovered = linkers[by_triple[triple]]["discovery_result"] == "discovered"
        # A cross pair may be declared only when its linker was discovered.
        # Declaring a pair that cannot link would be a claim without evidence.
        if pair["declared"]:
            if expected != "cross":
                fail(f"{triple}: a native pair cannot be declared as a cross pair")
            if not discovered:
                fail(f"{triple}: declared as a cross pair without a discovered linker")
            if pair["blocking_reason"]:
                fail(f"{triple}: a declared pair cannot also carry a blocking reason")
        elif expected == "cross" and not pair["blocking_reason"]:
            fail(f"{triple}: an undeclared cross pair must state what blocks it")

    derived = [p for p in pairs if p["declared"]]
    if authority["declared_cross_pairs"] != derived:
        fail("declared cross pairs are not derived from the pair list")

    if authority["classification_derivation"] != (
        "a_pair_is_cross_when_the_target_triple_differs_from_the_host_triple"
    ):
        fail("classification derivation drifted")
    if authority["declaration_policy"] != (
        "a_cross_pair_is_declared_only_when_its_complete_target_support_tuple_holds"
    ):
        fail("declaration policy drifted")

    required_bans = {"no_host_paths_in_a_cross_artifact", "no_host_libraries_in_a_cross_artifact",
                     "no_host_headers_in_a_cross_artifact",
                     "no_host_runtime_package_in_a_cross_artifact"}
    if not required_bans.issubset(set(authority["host_leakage_bans"])):
        fail("host leakage ban inventory is incomplete")

    required = {"cross_pair_undeclared", "cross_pair_incomplete_tuple",
                "cross_artifact_host_leakage", "cross_pair_host_runtime_package_selected",
                "cross_pair_host_linker_selected"}
    if not required.issubset(set(authority["rejection_classes"])):
        fail("rejection class inventory is incomplete")

    rows = contract_rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(rows, authority):
        fail("generated review is stale; run --write")
    cross = sum(p["classification"] == "cross" for p in pairs)
    print(f"{GUARD}: ok ({len(pairs)} pairs, {cross} cross candidates, "
          f"{len(authority['declared_cross_pairs'])} declared, level1)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write:
        registry = json.loads(REGISTRY.read_text())
        REVIEW.write_text(render(contract_rows(), registry["phase18_cross_compilation"]))
    check()


if __name__ == "__main__":
    main()
