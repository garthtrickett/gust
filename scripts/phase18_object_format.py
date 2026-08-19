#!/usr/bin/env python3
"""Validate and render the Patch 18.3 object format authority."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase18-object-format-contract"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
MODULE = ROOT / "compiler/mir_target_authority.gst"
CONTRACT = ROOT / "tests/cranelift/phase18_object_format_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase18_object_format_review.txt"

# The format follows from the operating system in the declared target identity.
# This map is the derivation, so a descriptor is checked against it rather than
# trusted.
FORMAT_BY_OS = {"linux": "elf", "darwin": "macho"}

MODULE_TOKENS = (
    "MirObjectSection", "MirObjectFormatDescriptor",
    "mir_object_format_for_operating_system", "mir_object_section_declared",
    "mir_object_binding_declared", "mir_object_format_validate",
    "object_format_disagrees_with_target_identity",
    "object_format_not_derived_from_target_identity",
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


def render(rows: list[dict[str, str]], authority: dict) -> str:
    descriptors = authority["format_descriptors"]
    header = (
        "Patch 18.3 — Object Format, Section, and Symbol Binding Authority\n\n"
        f"format_descriptors\t{len(descriptors)}\n"
        f"object_formats\t{len(authority['object_formats'])}\n"
        f"section_kinds\t{len(authority['section_kinds'])}\n"
        f"symbol_bindings\t{len(authority['symbol_bindings'])}\n"
        f"rejection_classes\t{len(authority['rejection_classes'])}\n\n"
    )
    return header + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n"
        for row in rows
    )


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    authority = registry.get("phase18_object_format")
    if not isinstance(authority, dict) or authority.get("version") != "phase18_object_format_authority_v1":
        fail("object format authority missing")

    module = MODULE.read_text() if MODULE.is_file() else ""
    for token in MODULE_TOKENS:
        if token not in module:
            fail(f"target authority module is missing: {token}")

    triples = {t["target_id"]: t for t in registry["phase18_target_authority"]["declared_triples"]}
    descriptors = authority["format_descriptors"]

    # Exactly one descriptor per declared target, no more and no fewer.
    covered = [d["target_id"] for d in descriptors]
    if sorted(covered) != sorted(triples):
        fail("object format descriptor coverage disagrees with the declared triple vocabulary")
    if len(set(covered)) != len(covered):
        fail("duplicate object format descriptor for a target")

    declared_kinds = authority["section_kinds"]
    for descriptor in descriptors:
        tid = descriptor["target_id"]
        triple = triples[tid]

        # The format is recomputed from the operating system, never trusted.
        expected = FORMAT_BY_OS.get(triple["operating_system"])
        if expected is None:
            fail(f"{triple['target_triple']}: no object format derivation for {triple['operating_system']}")
        if descriptor["object_format"] != expected:
            fail(f"{triple['target_triple']}: object format {descriptor['object_format']} "
                 f"disagrees with the target identity, which implies {expected}")
        if descriptor["derived_from"] != "operating_system_in_declared_target_identity":
            fail(f"{triple['target_triple']}: object format is not derived from the target identity")

        if descriptor["section_kinds"] != declared_kinds:
            fail(f"{triple['target_triple']}: section kinds disagree with the declared vocabulary")
        if len(descriptor["section_names"]) != len(descriptor["section_kinds"]):
            fail(f"{triple['target_triple']}: every section kind needs exactly one name")
        if len(set(descriptor["section_names"])) != len(descriptor["section_names"]):
            fail(f"{triple['target_triple']}: duplicate section name")
        if descriptor["max_section_alignment"] < 1:
            fail(f"{triple['target_triple']}: max section alignment must be positive")

        # ELF and Mach-O spell sections differently; the spelling must match the
        # format, or the descriptor is describing a different object file.
        if descriptor["object_format"] == "elf":
            if not all(name.startswith(".") for name in descriptor["section_names"]):
                fail(f"{triple['target_triple']}: ELF section names must be dot-prefixed")
        else:
            if not all("," in name and name.startswith("__") for name in descriptor["section_names"]):
                fail(f"{triple['target_triple']}: Mach-O section names must be segment,section pairs")

        if not set(descriptor["symbol_bindings"]).issubset(set(authority["symbol_bindings"])):
            fail(f"{triple['target_triple']}: symbol binding outside the declared vocabulary")
        if not set(descriptor["symbol_visibilities"]).issubset(set(authority["symbol_visibilities"])):
            fail(f"{triple['target_triple']}: symbol visibility outside the declared vocabulary")

    if sorted(authority["object_formats"]) != sorted({d["object_format"] for d in descriptors}):
        fail("declared object formats are not derived from the descriptors")

    for key, expected in (
        ("format_derivation", "operating_system_in_declared_target_identity"),
        ("selection_policy",
         "object_format_is_derived_from_target_identity_never_from_a_file_extension_probe_or_host_default"),
        ("emission_policy",
         "emitted_objects_use_only_declared_section_kinds_bindings_and_visibilities"),
    ):
        if authority.get(key) != expected:
            fail(f"{key} drifted")

    required_bans = {"no_object_format_from_host_isa", "no_object_format_from_file_extension",
                     "no_object_format_from_output_probe", "no_backend_owned_section_naming"}
    if not required_bans.issubset(set(authority["hard_bans"])):
        fail("hard ban inventory is incomplete")

    # Patch 18.0 recorded the host ISA object builder assumption; this row owns it.
    hosts = registry["opening_snapshots"]["phase18"]["host_assumption_inventory"]
    owned = {h["id"] for h in hosts if h["owning_phase18_entry_id"] == "p18_object_format"}
    if "p18_host_object_builder_isa" not in owned:
        fail("the host ISA object builder assumption is not owned by the object format row")

    rows = contract_rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(rows, authority):
        fail("generated review is stale; run --write")
    print(f"{GUARD}: ok ({len(descriptors)} descriptors, "
          f"{len(authority['object_formats'])} formats, level1)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write:
        registry = json.loads(REGISTRY.read_text())
        REVIEW.write_text(render(contract_rows(), registry["phase18_object_format"]))
    check()


if __name__ == "__main__":
    main()
