#!/usr/bin/env python3
"""Validate and render the Patch 17.15 runtime residue and coverage audit."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase17-deferred-residue-audit"
CONTRACT = ROOT / "tests/cranelift/phase17_deferred_residue_audit_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase17_deferred_residue_audit_review.txt"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"

# The classification authority records every inventoried helper by design, so it
# is a participation record rather than a termination. Counting it would hide
# every genuine gap.
CLASSIFICATION = ("phase17_runtime_authority", "helper_classifications")

# Only these fields dispose of a helper. Symbol versioning and MIR requirement
# rows are cross-cutting layers a single helper legitimately appears in more
# than once, so treating any repeat appearance as a defect would be wrong.
TERMINAL_FIELDS = {
    "selected_operations",
    "selected_imports",
    "obsolete_families",
    "deferred_rows",
}

ROW_FIELDS = {
    "id",
    "source_phase17_row_ids",
    "source_helper_ids",
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
    "more runtime work",
    "more c helpers",
    "more native libraries",
    "more abi work",
    "more i/o",
    "more threading",
    "wrappers later",
    "platform support later",
}


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD}: {message}")


def helper_terminations(registry: dict) -> dict[str, list[str]]:
    inventory = registry["opening_snapshots"]["phase17"]["helper_inventory"]
    by_symbol = {helper["symbol_identity"]: helper["id"] for helper in inventory}
    terminations: dict[str, list[str]] = {helper["id"]: [] for helper in inventory}
    for authority, body in registry.items():
        if not authority.startswith("phase17") or not isinstance(body, dict):
            continue
        for field, rows in body.items():
            if field not in TERMINAL_FIELDS or (authority, field) == CLASSIFICATION:
                continue
            for row in rows:
                if not isinstance(row, dict):
                    continue
                helper_id = row.get("helper_id")
                if helper_id not in terminations:
                    helper_id = by_symbol.get(row.get("symbol_identity"))
                if helper_id in terminations:
                    terminations[helper_id].append(f"{authority}.{field}")
    return terminations


def contract_rows() -> list[dict[str, str]]:
    with CONTRACT.open(newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    if not rows or set(rows[0]) != {"kind", "requirement", "evidence", "level"}:
        fail("contract schema mismatch")
    if any(row["level"] != "1" or not row["evidence"] for row in rows):
        fail("all rows must be Level 1")
    return rows


def render(rows: list[dict[str, str]], audit: dict) -> str:
    helpers = audit["helper_dispositions"]
    counts = {kind: sum(row["disposition"] == kind for row in helpers)
              for kind in ("migrated", "excluded", "removed", "narrowly_deferred")}
    header = (
        "Patch 17.15 — Deferred Residue and Runtime-Coverage Audit\n\n"
        f"opening_rows\t{len(audit['opening_dispositions'])}\n"
        f"inventoried_helpers\t{len(helpers)}\n"
        f"migrated_helpers\t{counts['migrated']}\n"
        f"excluded_helpers\t{counts['excluded']}\n"
        f"removed_helpers\t{counts['removed']}\n"
        f"narrowly_deferred_helpers\t{counts['narrowly_deferred']}\n"
        f"retained_components\t{len(audit['component_dispositions'])}\n"
        f"narrow_deferred_rows\t{len(audit['narrow_deferred_rows'])}\n\n"
    )
    return header + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n"
        for row in rows
    )


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    audit = registry.get("phase17_deferred_residue_audit")
    if not isinstance(audit, dict) or audit.get("version") != "phase17_deferred_residue_audit_v1":
        fail("audit authority missing")

    snapshot = registry.get("opening_snapshots", {}).get("phase17", {})
    opening_ids = [entry["id"] for entry in snapshot.get("entries", [])]
    dispositions = audit.get("opening_dispositions")
    if [row.get("id") for row in dispositions] != opening_ids:
        fail("opening coverage drifted")
    if any(row["disposition"] != "migrated" or not row["evidence_guard"] for row in dispositions):
        fail("selected Phase 17 opening rows must all be migrated at Patch 17.15")

    # Every inventoried helper terminates exactly once.
    inventory_ids = [helper["id"] for helper in snapshot.get("helper_inventory", [])]
    helper_rows = audit.get("helper_dispositions")
    if [row.get("helper_id") for row in helper_rows] != inventory_ids:
        fail("helper coverage drifted from the opening inventory")

    terminations = helper_terminations(registry)
    deferred_ids = {row["id"] for row in audit["narrow_deferred_rows"]}
    excluded_ids = {row["helper_id"] for row in audit["excluded_items"]}
    for row in helper_rows:
        helper_id = row["helper_id"]
        found = terminations[helper_id]
        if len(found) > 1:
            fail(f"{helper_id}: terminates more than once ({', '.join(found)})")
        if row["disposition"] == "excluded":
            if helper_id not in excluded_ids:
                fail(f"{helper_id}: excluded without a justified exclusion row")
            if found:
                fail(f"{helper_id}: excluded but still terminates in {found[0]}")
        else:
            if not found:
                fail(f"{helper_id}: no termination recorded")
            if row["terminating_authority"] != found[0]:
                fail(f"{helper_id}: terminating authority disagrees with the registry")
        if row["disposition"] == "narrowly_deferred":
            if row["narrow_deferred_row"] not in deferred_ids:
                fail(f"{helper_id}: deferred to an unknown narrow row")
        elif row["narrow_deferred_row"]:
            fail(f"{helper_id}: only narrowly deferred helpers name a narrow row")

    # Every retained C component names a concrete destination.
    components = registry["phase17_retained_c_authority"]["retained_components"]
    component_ids = [component["component_id"] for component in components]
    component_rows = audit["component_dispositions"]
    if [row["component_id"] for row in component_rows] != component_ids:
        fail("retained component coverage drifted")
    for component, row in zip(components, component_rows):
        if component["destination_phase"] != "phase18":
            fail(f"{component['component_id']}: destination phase is not a future phase")
        if row["narrow_deferred_row"] not in deferred_ids:
            fail(f"{component['component_id']}: destination is not a named narrow row")
        if row["narrow_deferred_row"] not in component["removal_criterion"]:
            fail(f"{component['component_id']}: removal criterion does not name its destination row")

    fixtures: set[str] = set()
    codes: set[str] = set()
    for row in audit["narrow_deferred_rows"]:
        if set(row) != ROW_FIELDS:
            fail(f"{row.get('id')}: incomplete actionable deferral")
        scalars = ROW_FIELDS - {"source_phase17_row_ids", "source_helper_ids"}
        if any(not isinstance(row[field], str) or not row[field].strip() for field in scalars):
            fail(f"{row['id']}: blank deferred field")
        source_ids = row["source_phase17_row_ids"]
        if not source_ids or any(source_id not in opening_ids for source_id in source_ids):
            fail(f"{row['id']}: source row traceability is invalid")
        if any(helper_id not in inventory_ids for helper_id in row["source_helper_ids"]):
            fail(f"{row['id']}: unknown source helper")
        if any(term in row["reason"].lower() for term in BROAD_RESIDUE):
            fail(f"{row['id']}: broad residue survived")
        for field in ("positive_future_fixture", "negative_current_fixture"):
            fixture = row[field]
            if fixture in fixtures:
                fail(f"{row['id']}: fixture is not unique")
            fixtures.add(fixture)
            path = ROOT / fixture
            if not path.is_file() or path.is_symlink():
                fail(f"{row['id']}: missing {field}")
        if row["diagnostic_reason_code"] in codes:
            fail(f"{row['id']}: duplicate diagnostic reason code")
        codes.add(row["diagnostic_reason_code"])
        if row["diagnostic_reason_code"] not in (ROOT / row["negative_current_fixture"]).read_text():
            fail(f"{row['id']}: diagnostic fixture drifted")

    # Every narrow row must actually be claimed by a helper or a component.
    claimed = {row["narrow_deferred_row"] for row in helper_rows if row["narrow_deferred_row"]}
    claimed |= {row["narrow_deferred_row"] for row in component_rows}
    unclaimed = deferred_ids - claimed
    if unclaimed:
        fail(f"narrow deferred rows claimed by nothing: {sorted(unclaimed)}")

    for key, expected in (
        ("broad_residue_policy", "reject_broad_or_ambiguous_phase17_runtime_residue"),
        ("coverage_policy", "every_phase17_opening_row_and_inventoried_helper_migrated_excluded_removed_or_replaced_by_narrow_actionable_rows"),
        ("helper_termination_policy", "every_inventoried_helper_terminates_exactly_once_outside_the_classification_authority"),
        ("component_destination_policy", "every_retained_c_component_names_a_narrow_deferred_row_as_its_removal_or_reassessment_destination"),
    ):
        if audit.get(key) != expected:
            fail(f"{key} drifted")

    rows = contract_rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(rows, audit):
        fail("generated review is stale; run --write")

    counts = {kind: sum(r["disposition"] == kind for r in helper_rows)
              for kind in ("migrated", "excluded", "narrowly_deferred")}
    print(
        f"{GUARD}: ok (opening={len(dispositions)} helpers={len(helper_rows)} "
        f"migrated={counts['migrated']} excluded={counts['excluded']} "
        f"deferred={counts['narrowly_deferred']} components={len(component_rows)} "
        f"narrow_rows={len(audit['narrow_deferred_rows'])}, Level 1)"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write:
        registry = json.loads(REGISTRY.read_text())
        REVIEW.write_text(render(contract_rows(), registry["phase17_deferred_residue_audit"]))
    check()


if __name__ == "__main__":
    main()
