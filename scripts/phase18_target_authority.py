#!/usr/bin/env python3
"""Validate and render the Patch 18.1 compiler-owned target authority."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase18-target-authority-contract"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
MODULE = ROOT / "compiler/mir_target_authority.gst"
CONTRACT = ROOT / "tests/cranelift/phase18_target_authority_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase18_target_authority_review.txt"

MODULE_TOKENS = (
    "MirDeclaredTriple", "MirTargetSelection", "MirTargetIdentity", "MirTargetAuthorityTable",
    "mir_target_make_empty_table", "mir_target_triple_is_declared",
    "mir_target_declared_pointer_width", "mir_target_selection_consulted_host",
    "mir_target_identity_agrees_with_layout",
    "compiler_declared_triple_vocabulary_no_host_inference",
    "explicit_requested_target_or_declared_default_never_host_probe",
    "pointer_width_and_endianness_must_agree_with_phase14_target_layout_authority",
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
    triples = authority["declared_triples"]
    header = (
        "Patch 18.1 — Compiler-Owned Target Authority\n\n"
        f"declared_triples\t{len(triples)}\n"
        f"architectures\t{len({t['architecture'] for t in triples})}\n"
        f"operating_systems\t{len({t['operating_system'] for t in triples})}\n"
        f"selection_modes\t{len(authority['selection_modes'])}\n"
        f"rejection_classes\t{len(authority['rejection_classes'])}\n\n"
    )
    return header + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n"
        for row in rows
    )


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    authority = registry.get("phase18_target_authority")
    if not isinstance(authority, dict) or authority.get("version") != "phase18_compiler_owned_target_authority_v1":
        fail("target authority missing")

    if not MODULE.is_file() or MODULE.is_symlink():
        fail("compiler target authority module missing")
    module = MODULE.read_text()
    for token in MODULE_TOKENS:
        if token not in module:
            fail(f"target authority module is missing: {token}")

    triples = authority["declared_triples"]
    if not triples:
        fail("declared triple vocabulary is empty")

    ids = [t["target_id"] for t in triples]
    spellings = [t["target_triple"] for t in triples]
    if len(set(ids)) != len(ids):
        fail("duplicate declared target id")
    if len(set(spellings)) != len(spellings):
        fail("duplicate declared target triple")

    # The vocabulary is registry-derived, not hand-written: every declared
    # triple must be a target the Phase 17 package authority already owns.
    packages = {t["target_id"] for t in registry["phase17_runtime_package_authority"]["target_packages"]}
    unknown = set(ids) - packages
    if unknown:
        fail(f"declared triples not owned by the Phase 17 package authority: {sorted(unknown)}")

    # Layout agreement is computed from the registry-owned target id rather
    # than asserted, so a triple cannot claim a width or endianness that
    # disagrees with the Phase 14 target layout authority.
    for triple in triples:
        fields = dict(part.split("=", 1) for part in triple["target_id"].split(":")[2:] if "=" in part)
        if fields.get("triple") != triple["target_triple"]:
            fail(f"{triple['target_triple']}: target id spelling disagrees with the declared triple")
        expected_width = int(fields["ptr_size"]) * 8
        if triple["pointer_width_bits"] != expected_width:
            fail(f"{triple['target_triple']}: pointer width disagrees with the Phase 14 target layout authority")
        if triple["endianness"] != fields["endian"]:
            fail(f"{triple['target_triple']}: endianness disagrees with the Phase 14 target layout authority")
        parts = triple["target_triple"].split("-")
        if len(parts) < 3:
            fail(f"{triple['target_triple']}: malformed triple")
        if parts[0] != triple["architecture"]:
            fail(f"{triple['target_triple']}: architecture disagrees with the triple spelling")

    if authority["default_target_triple"] not in spellings:
        fail("declared default target is not in the declared triple vocabulary")
    if set(authority["selection_modes"]) != {"explicit_requested_target", "declared_default_target"}:
        fail("selection mode vocabulary drifted")

    for key, expected in (
        ("identity_policy", "compiler_declared_triple_vocabulary_no_host_inference"),
        ("selection_policy", "explicit_requested_target_or_declared_default_never_host_probe"),
        ("layout_agreement_policy",
         "pointer_width_and_endianness_must_agree_with_phase14_target_layout_authority"),
        ("layout_authority_id", "phase14_compiler_owned_layout_authority_v1"),
    ):
        if authority.get(key) != expected:
            fail(f"{key} drifted")

    if authority["layout_authority_id"] != registry["phase14_layout_authority"]["version"]:
        fail("target authority names a layout authority version that does not exist")

    required_rejections = {
        "unknown_target_triple", "malformed_target_triple", "ambiguous_target_triple",
        "duplicate_declared_triple", "target_layout_disagreement",
        "host_inference_under_explicit_target", "missing_target_identity_in_request",
    }
    if not required_rejections.issubset(set(authority["rejection_classes"])):
        fail("rejection class inventory is incomplete")
    required_bans = {
        "no_backend_owned_target_selection", "no_host_probe_under_explicit_target",
        "no_native_isa_builder_as_target_authority",
        "no_target_inferred_from_file_extension_or_output_probe",
    }
    if not required_bans.issubset(set(authority["hard_bans"])):
        fail("hard ban inventory is incomplete")

    # Patch 18.0 recorded a host assumption for the native ISA builder. Patch
    # 18.1 owns the replacement decision, so that assumption must point here.
    hosts = registry["opening_snapshots"]["phase18"]["host_assumption_inventory"]
    owned = {h["id"] for h in hosts if h["owning_phase18_entry_id"] == "p18_target_authority"}
    if "p18_host_cranelift_native_isa" not in owned:
        fail("the native ISA host assumption is not owned by the target authority row")

    rows = contract_rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(rows, authority):
        fail("generated review is stale; run --write")
    print(f"{GUARD}: ok ({len(triples)} declared triples, "
          f"{len(authority['rejection_classes'])} rejection classes, level1)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write:
        registry = json.loads(REGISTRY.read_text())
        REVIEW.write_text(render(contract_rows(), registry["phase18_target_authority"]))
    check()


if __name__ == "__main__":
    main()
