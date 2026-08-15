#!/usr/bin/env python3
"""Validate and render the Patch 16.14 ABI residue audit."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase16-deferred-residue-audit"
CONTRACT = ROOT / "tests/cranelift/phase16_deferred_residue_audit_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase16_deferred_residue_audit_review.txt"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"

REQUIRED_DEFERRED = [
    "p17_variadic_gust_calls",
    "p17_c_variadic_calls",
    "p17_target_homogeneous_aggregate_abi",
    "p17_vector_simd_calling_convention",
    "p17_complete_windows_aggregate_abi",
    "p17_complete_sysv_aggregate_abi",
    "p17_complete_aarch64_pcs",
    "p18_closure_environment_abi",
    "p17_signature_erased_function_pointers",
    "p18_trait_object_vtable_generation",
    "p17_arbitrary_unsized_aggregate_fields",
    "p18_coroutine_async_frame_abi",
    "p17_unbounded_dynamic_stack_and_probing",
    "p17_foreign_aggregate_parameters_returns",
    "p17_foreign_resource_ownership_transfer",
    "p17_cross_version_module_abi",
    "p17_dynamic_library_symbol_version_abi",
    "p17_tail_call_abi",
    "p17_unwind_exception_personality_abi",
]

ROW_FIELDS = {
    "id",
    "source_phase16_row_ids",
    "capability_owner",
    "diagnostic_owner",
    "reason",
    "destination_phase",
    "prerequisite_capability",
    "current_failure_stage",
    "target_applicability",
    "positive_future_fixture",
    "negative_current_fixture",
    "diagnostic_reason_code",
}

BROAD_RESIDUE = {
    "more abi",
    "more calling conventions",
    "more aggregates",
    "more indirect calls",
    "more unsized types",
    "more stack allocation",
    "ffi later",
    "runtime work later",
}


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


def render(rows: list[dict[str, str]], audit: dict[str, object]) -> str:
    dispositions = audit["opening_dispositions"]
    deferred = audit["narrow_deferred_rows"]
    header = (
        "Patch 16.14 — Deferred Residue and ABI-Coverage Audit\n\n"
        f"opening_rows\t{len(dispositions)}\n"
        f"migrated_rows\t{sum(row['disposition'] == 'migrated' for row in dispositions)}\n"
        f"narrow_deferred_rows\t{len(deferred)}\n"
        "excluded_rows\t0\n\n"
    )
    return header + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n"
        for row in rows
    )


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    audit = registry.get("phase16_deferred_residue_audit")
    if not isinstance(audit, dict) or audit.get("version") != "phase16_deferred_residue_audit_v1":
        fail("audit authority missing")

    opening_snapshot = registry.get("opening_snapshots", {}).get("phase16", {})
    opening = opening_snapshot.get("entries", [])
    opening_ids = [entry.get("id") for entry in opening]
    dispositions = audit.get("opening_dispositions")
    if not isinstance(dispositions, list) or [row.get("id") for row in dispositions] != opening_ids:
        fail("opening coverage drifted")
    if any(
        row.get("disposition") not in {"migrated", "excluded", "replaced"}
        or not row.get("evidence_guard")
        for row in dispositions
    ):
        fail("opening row has ambiguous disposition")
    if any(row.get("disposition") != "migrated" for row in dispositions):
        fail("selected Phase 16 opening rows must all be migrated at Patch 16.14")

    composition = registry.get("phase16_abi_composition_authority", {})
    migrated = [row.get("id") for row in composition.get("migrated_entries", [])]
    owner = composition.get("composition_case", {}).get("owner_entry_id")
    if migrated + [owner] != opening_ids:
        fail("composition authority does not account for every migrated opening row")

    residual_rebase = opening_snapshot.get("residual_rebase", [])
    selected = {
        entry_id
        for row in residual_rebase
        if row.get("phase16_disposition") == "selected"
        for entry_id in row.get("selected_phase16_entry_ids", [])
    }
    if not selected or not selected.issubset(set(opening_ids)):
        fail("Phase 15 residual rebase traceability drifted")

    deferred = audit.get("narrow_deferred_rows")
    if not isinstance(deferred, list) or [row.get("id") for row in deferred] != REQUIRED_DEFERRED:
        fail("narrow deferred inventory drifted")
    fixture_paths: set[str] = set()
    diagnostic_codes: set[str] = set()
    for row in deferred:
        if set(row) != ROW_FIELDS:
            fail(f"{row.get('id')}: incomplete actionable deferral")
        scalar_fields = ROW_FIELDS - {"source_phase16_row_ids"}
        if any(not isinstance(row[field], str) or not row[field].strip() for field in scalar_fields):
            fail(f"{row['id']}: blank deferred field")
        source_ids = row["source_phase16_row_ids"]
        if not isinstance(source_ids, list) or not source_ids or len(source_ids) != len(set(source_ids)):
            fail(f"{row['id']}: source row traceability is invalid")
        if any(source_id not in opening_ids for source_id in source_ids):
            fail(f"{row['id']}: unknown source Phase 16 row")
        if row["destination_phase"] not in {"phase17", "phase18"}:
            fail(f"{row['id']}: destination phase drifted")
        if row["current_failure_stage"] != "before_driver_discovery":
            fail(f"{row['id']}: failure stage drifted")
        if row["target_applicability"] != "all_declared_host_targets_from_phase14_target_authority":
            fail(f"{row['id']}: target applicability is not authority-derived")
        if any(term in row["reason"].lower() for term in BROAD_RESIDUE):
            fail(f"{row['id']}: broad residue survived")
        for field in ("positive_future_fixture", "negative_current_fixture"):
            fixture = row[field]
            if fixture in fixture_paths:
                fail(f"{row['id']}: fixture is not unique")
            fixture_paths.add(fixture)
            path = ROOT / fixture
            if not path.is_file() or path.is_symlink():
                fail(f"{row['id']}: missing {field}")
        diagnostic_code = row["diagnostic_reason_code"]
        if diagnostic_code in diagnostic_codes:
            fail(f"{row['id']}: duplicate diagnostic reason code")
        diagnostic_codes.add(diagnostic_code)
        if diagnostic_code not in (ROOT / row["negative_current_fixture"]).read_text():
            fail(f"{row['id']}: diagnostic fixture drifted")

    if audit.get("excluded_items") != []:
        fail("Phase 16 has no selected-inventory exclusions")
    if audit.get("broad_residue_policy") != "reject_broad_or_ambiguous_phase16_residue":
        fail("broad residue policy drifted")
    if audit.get("coverage_policy") != "every_phase16_opening_row_migrated_excluded_or_replaced_by_narrow_actionable_rows":
        fail("coverage policy drifted")
    if audit.get("abi_class_target_policy") != "selected_classes_supported_all_other_declared_classes_and_targets_narrowly_deferred":
        fail("ABI class and target coverage policy drifted")
    if audit.get("phase15_rebase_policy") != "all_selected_phase15_residuals_consumed_without_ambiguous_carryover":
        fail("Phase 15 rebase policy drifted")

    rows = contract_rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(rows, audit):
        fail("generated review is stale; run --write")
    print(
        f"{GUARD}: ok (opening={len(dispositions)} migrated={len(dispositions)} "
        f"deferred={len(deferred)} excluded=0, Level 1)"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write:
        registry = json.loads(REGISTRY.read_text())
        REVIEW.write_text(render(contract_rows(), registry["phase16_deferred_residue_audit"]))
    check()


if __name__ == "__main__":
    main()
