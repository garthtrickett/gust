#!/usr/bin/env python3
"""Validate and render the Patch 18.16 atomic executable publication."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase18-publication-contract"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
CONTRACT = ROOT / "tests/cranelift/phase18_publication_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase18_publication_review.txt"

# Publication is the last step that can destroy a valid artifact, so its
# position in the order is the whole contract.
PRECONDITIONS = ["object_emission", "relocation_validation", "availability_validation",
                 "link_success"]


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
    header = (
        "Patch 18.16 — Atomic Executable Publication\n\n"
        f"required_preconditions\t{len(authority['required_preconditions'])}\n"
        f"temporary_artifacts\t{len(authority['temporary_artifacts'])}\n"
        f"rejection_classes\t{len(authority['rejection_classes'])}\n\n"
    )
    return header + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n"
        for row in rows
    )


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    authority = registry.get("phase18_publication")
    if not isinstance(authority, dict) or authority.get("version") != "phase18_publication_v1":
        fail("publication authority missing")

    # Phase 9G executes publication; Phase 18 only supplies the plan.
    if authority["publication_owner"] != "phase9g_artifact_planner":
        fail("publication owner drifted from Phase 9G")
    if "guard-cranelift-phase9g-close" not in (ROOT / "justfile").read_text():
        fail("the Phase 9G artifact ownership guard is absent")

    # Every validation must precede publication, in order.
    if authority["required_preconditions"] != PRECONDITIONS:
        fail("the publication precondition order drifted")

    # The preconditions must name stages the earlier authorities actually own,
    # or publication is ordered after checks that do not exist.
    if "phase18_relocation_model" not in registry:
        fail("relocation validation is a precondition but the authority is absent")
    reloc_stage = registry["phase18_relocation_model"]["validation_stage"]
    if "before_object_publication" not in reloc_stage:
        fail("the relocation model does not validate before object publication")

    artifacts = authority["temporary_artifacts"]
    if not artifacts:
        fail("no temporary artifacts declared; publication creates at least one")
    for artifact in artifacts:
        if not artifact.get("artifact") or not artifact.get("owner"):
            fail("a temporary artifact is missing its name or owner")
        if not artifact.get("cleanup_rule"):
            fail(f"{artifact.get('artifact')}: temporary artifact has no cleanup rule")
        if artifact["owner"] != "phase9g_artifact_planner":
            fail(f"{artifact['artifact']}: temporary artifact is not owned by Phase 9G")

    for key, expected in (
        ("ownership_policy", "phase18_supplies_the_publication_plan_and_phase9g_executes_it"),
        ("atomicity_method", "write_to_a_temporary_path_then_rename_over_the_output_in_one_step"),
        ("atomicity_reason", "a_partially_written_executable_must_never_replace_a_valid_one"),
        ("preservation_guarantee",
         "existing_output_survives_failure_deferral_and_unsupported_target_rejection"),
        ("sentinel_policy",
         "a_sentinel_output_proves_no_replacement_occurred_before_a_rejection"),
    ):
        if authority.get(key) != expected:
            fail(f"{key} drifted")

    required = {"publication_before_object_emission", "publication_before_relocation_validation",
                "publication_before_availability_validation", "publication_before_link_success",
                "publication_not_atomic", "publication_executed_by_phase18",
                "temporary_artifact_without_owner_or_cleanup_rule"}
    if not required.issubset(set(authority["rejection_classes"])):
        fail("rejection class inventory is incomplete")

    # Patch 18.0 recorded the host publication rename assumption; this row owns it.
    hosts = registry["opening_snapshots"]["phase18"]["host_assumption_inventory"]
    owned = {h["id"] for h in hosts if h["owning_phase18_entry_id"] == "p18_atomic_publication"}
    if "p18_host_publication_rename" not in owned:
        fail("the host publication rename assumption is not owned by this row")

    rows = contract_rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(rows, authority):
        fail("generated review is stale; run --write")
    print(f"{GUARD}: ok ({len(PRECONDITIONS)} ordered preconditions, "
          f"{len(artifacts)} temporary artifacts, level1)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write:
        registry = json.loads(REGISTRY.read_text())
        REVIEW.write_text(render(contract_rows(), registry["phase18_publication"]))
    check()


if __name__ == "__main__":
    main()
