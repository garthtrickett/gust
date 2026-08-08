#!/usr/bin/env python3
from __future__ import annotations
import argparse, csv, json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase15-deferred-residue-audit"
CONTRACT = ROOT / "tests/cranelift/phase15_deferred_residue_audit_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase15_deferred_residue_audit_review.txt"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
REQUIRED_DEFERRED = ["p17_async_unwind_resource_cleanup", "p17_foreign_exception_resource_cleanup", "p19_cancellation_resource_cleanup"]

def fail(message: str) -> None: raise SystemExit(f"{GUARD}: {message}")
def contract_rows() -> list[dict[str, str]]:
    with CONTRACT.open(newline="") as handle: rows = list(csv.DictReader(handle, delimiter="\t"))
    if not rows or set(rows[0]) != {"kind", "requirement", "evidence", "level"}: fail("contract schema mismatch")
    if any(row["level"] != "1" or not row["evidence"] for row in rows): fail("all rows must be Level 1")
    return rows
def render(rows: list[dict[str, str]]) -> str:
    return "Patch 15.14 — Deferred Residue and Resource-Coverage Audit\n\n" + "".join(f"{r['kind']}\t{r['requirement']}\t{r['evidence']}\tLevel {r['level']}\n" for r in rows)

def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    audit = registry.get("phase15_deferred_residue_audit")
    if not isinstance(audit, dict) or audit.get("version") != "phase15_deferred_residue_audit_v1": fail("audit authority missing")
    opening = registry.get("opening_snapshots", {}).get("phase15", {}).get("entries", [])
    opening_ids = [entry.get("id") for entry in opening]
    dispositions = audit.get("opening_dispositions")
    if not isinstance(dispositions, list) or [row.get("id") for row in dispositions] != opening_ids: fail("opening coverage drifted")
    if any(row.get("disposition") not in {"migrated", "excluded", "replaced"} or not row.get("evidence_guard") for row in dispositions): fail("opening row has ambiguous disposition")
    if any(row.get("disposition") != "migrated" for row in dispositions): fail("selected Phase 15 opening rows must all be migrated at Patch 15.14")
    deferred = audit.get("narrow_deferred_rows")
    if not isinstance(deferred, list) or [row.get("id") for row in deferred] != REQUIRED_DEFERRED: fail("narrow deferred inventory drifted")
    required = {"id", "parent", "owner", "reason", "destination_phase", "prerequisite", "failure_stage", "target_applicability", "positive_future_fixture", "negative_current_fixture", "diagnostic_code"}
    for row in deferred:
        if set(row) != required or any(not str(row[field]).strip() for field in required): fail(f"{row.get('id')}: incomplete actionable deferral")
        if row["id"].startswith("p15_"): fail(f"{row['id']}: broad Phase 15 residue survived")
        if row["parent"] != "p15_selected_failure_cleanup" or row["failure_stage"] != "before_driver_discovery": fail(f"{row['id']}: traceability/failure stage drifted")
        for field in ("positive_future_fixture", "negative_current_fixture"):
            path = ROOT / row[field]
            if not path.is_file() or path.is_symlink(): fail(f"{row['id']}: missing {field}")
        if row["diagnostic_code"] not in (ROOT / row["negative_current_fixture"]).read_text(): fail(f"{row['id']}: diagnostic fixture drifted")
    excluded = audit.get("excluded_items")
    if not isinstance(excluded, list) or [row.get("id") for row in excluded] != ["os_DirEntry_ctx"]: fail("explicit exclusion drifted")
    if audit.get("broad_residue_policy") != "reject_broad_or_ambiguous_phase15_residue": fail("broad residue policy drifted")
    rows = contract_rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(rows): fail("generated review is stale; run --write")
    print(f"{GUARD}: ok (opening={len(dispositions)} migrated={len(dispositions)} deferred={len(deferred)} excluded={len(excluded)}, Level 1)")

def main() -> None:
    parser = argparse.ArgumentParser(); parser.add_argument("--write", action="store_true"); parser.add_argument("--check", action="store_true"); args = parser.parse_args()
    if args.write: REVIEW.write_text(render(contract_rows()))
    check()
if __name__ == "__main__": main()
