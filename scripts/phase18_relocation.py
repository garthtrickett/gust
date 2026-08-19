#!/usr/bin/env python3
"""Validate and render the Patch 18.4 relocation model."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase18-relocation-contract"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
MODULE = ROOT / "compiler/mir_target_authority.gst"
CONTRACT = ROOT / "tests/cranelift/phase18_relocation_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase18_relocation_review.txt"

# Relocation kind prefixes are format-specific. A kind spelled for one format
# cannot appear in a model for another.
KIND_PREFIX = {"elf": ("R_",), "macho": ("X86_64_RELOC_", "ARM64_RELOC_")}

MODULE_TOKENS = (
    "MirRelocation", "MirRelocationModel", "mir_relocation_kind_declared",
    "mir_relocation_section_permitted", "mir_relocation_kind_is_absolute",
    "mir_relocation_validate", "relocation_in_disallowed_section",
    "relocation_validated_too_late",
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
    models = authority["relocation_models"]
    header = (
        "Patch 18.4 — Relocation Model and Validation\n\n"
        f"relocation_models\t{len(models)}\n"
        f"relocation_kinds\t{sum(len(m['relocation_kinds']) for m in models)}\n"
        f"permitted_section_kinds\t{len(authority['permitted_section_kinds'])}\n"
        f"excluded_section_kinds\t{len(authority['excluded_section_kinds'])}\n"
        f"rejection_classes\t{len(authority['rejection_classes'])}\n\n"
    )
    return header + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n"
        for row in rows
    )


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    authority = registry.get("phase18_relocation_model")
    if not isinstance(authority, dict) or authority.get("version") != "phase18_relocation_model_v1":
        fail("relocation authority missing")

    module = MODULE.read_text() if MODULE.is_file() else ""
    for token in MODULE_TOKENS:
        if token not in module:
            fail(f"target authority module is missing: {token}")

    triples = {t["target_id"]: t for t in registry["phase18_target_authority"]["declared_triples"]}
    formats = {d["target_id"]: d["object_format"]
               for d in registry["phase18_object_format"]["format_descriptors"]}
    models = authority["relocation_models"]

    covered = [m["target_id"] for m in models]
    if sorted(covered) != sorted(triples):
        fail("relocation model coverage disagrees with the declared triple vocabulary")
    if len(set(covered)) != len(covered):
        fail("duplicate relocation model for a target")

    permitted = authority["permitted_section_kinds"]
    excluded = authority["excluded_section_kinds"]
    declared_sections = registry["phase18_object_format"]["section_kinds"]

    # Permitted and excluded must partition the declared section kinds exactly.
    if sorted(permitted + excluded) != sorted(declared_sections):
        fail("permitted and excluded section kinds do not partition the declared section kinds")
    if set(permitted) & set(excluded):
        fail("a section kind is both permitted and excluded")
    if "zero_initialised_data" not in excluded:
        fail("zero initialised data holds no bytes and must be excluded from relocations")

    for model in models:
        tid = model["target_id"]
        triple = triples[tid]

        # The model must agree with the object format and architecture the
        # earlier authorities already decided.
        if model["object_format"] != formats[tid]:
            fail(f"{triple['target_triple']}: relocation model object format disagrees with Patch 18.3")
        if model["architecture"] != triple["architecture"]:
            fail(f"{triple['target_triple']}: relocation model architecture disagrees with the target identity")

        kinds = model["relocation_kinds"]
        if not kinds:
            fail(f"{triple['target_triple']}: relocation model declares no kinds")
        if len(set(kinds)) != len(kinds):
            fail(f"{triple['target_triple']}: duplicate relocation kind")

        prefixes = KIND_PREFIX[model["object_format"]]
        for kind in kinds:
            if not kind.startswith(prefixes):
                fail(f"{triple['target_triple']}: relocation kind {kind} is not a "
                     f"{model['object_format']} kind")

        if model["permitted_section_kinds"] != permitted:
            fail(f"{triple['target_triple']}: permitted section kinds disagree with the authority")
        if model["validation_stage"] != authority["validation_stage"]:
            fail(f"{triple['target_triple']}: validation stage disagrees with the authority")

    if authority["validation_stage"] != "before_object_publication_and_before_linker_invocation":
        fail("relocation validation stage drifted")
    if authority["output_preservation_policy"] != "existing_output_survives_relocation_validation_failure":
        fail("output preservation policy drifted")
    if authority["exclusion_reason"] != "zero_initialised_data_holds_no_bytes_so_it_can_hold_no_relocation":
        fail("section exclusion reason drifted")

    required = {"relocation_kind_unknown", "relocation_in_disallowed_section",
                "relocation_offset_malformed", "relocation_addend_malformed",
                "relocation_symbol_missing", "relocation_validated_too_late"}
    if not required.issubset(set(authority["rejection_classes"])):
        fail("rejection class inventory is incomplete")

    hosts = registry["opening_snapshots"]["phase18"]["host_assumption_inventory"]
    owned = {h["id"] for h in hosts if h["owning_phase18_entry_id"] == "p18_relocation_model"}
    if "p18_host_relocation_defaults" not in owned:
        fail("the relocation defaults host assumption is not owned by the relocation row")

    rows = contract_rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(rows, authority):
        fail("generated review is stale; run --write")
    print(f"{GUARD}: ok ({len(models)} models, "
          f"{sum(len(m['relocation_kinds']) for m in models)} kinds, level1)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write:
        registry = json.loads(REGISTRY.read_text())
        REVIEW.write_text(render(contract_rows(), registry["phase18_relocation_model"]))
    check()


if __name__ == "__main__":
    main()
