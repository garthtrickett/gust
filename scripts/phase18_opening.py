#!/usr/bin/env python3
"""Validate and project the Patch 18.0 Phase 18 opening inventory."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase18-opening-contract"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE18_OPENING.md"
REVIEW_PATH = "compiler/CRANELIFT_PHASE18_OPENING.md"

ENTRY_FIELDS = {
    "id", "parent", "feature_family", "ci_family", "capability_owner", "diagnostic_owner",
    "target_applicability", "status", "current_failure_stage",
    "positive_future_fixture", "negative_current_fixture",
}
HOST_FIELDS = {
    "id", "assumption", "source_path", "reachability_area", "inventory_owner",
    "diagnostic_owner", "owning_phase18_entry_id", "initial_classification",
    "target_applicability",
}
CANDIDATE_FIELDS = {
    "target_id", "target_triple", "support_decision", "missing_tuple_elements", "declared_by",
}
REBASE_FIELDS = {
    "source_residual_id", "residual_origin", "phase18_disposition", "selected_phase18_entry_ids",
    "reassigned_destination_phase", "reassigned_capability", "justification",
}
# The six reachability areas the opening inventory must cover. A host assumption
# outside these areas is not a Phase 18 concern; a missing area means the sweep
# was incomplete.
REQUIRED_AREAS = {
    "target_selection", "cranelift_lowering", "object_emission",
    "runtime_package_selection", "link_planning", "publication",
}
TUPLE_ELEMENTS = {"compiler", "runtime_package", "linker", "abi"}


class Error(Exception):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def snapshot(registry: dict) -> dict:
    snapshots = registry.get("opening_snapshots", {})
    require("phase18" in snapshots, "Phase 18 opening snapshot missing")
    return snapshots["phase18"]


def validate(registry: dict) -> dict:
    snap = snapshot(registry)

    require(snap["opening_version"] == "phase18_opening_inventory_rebased_on_phase17_closure",
            "Phase 18 opening version drifted")
    require(snap["inventory_version"] == "phase18_opening_inventory_v1",
            "Phase 18 inventory version drifted")
    require(snap["status"] == "ready_for_patch18_1", "Phase 18 opening status drifted")
    require(snap["next_patch"] == "18.1", "Phase 18 next patch drifted")
    require(snap["review_view"] == REVIEW_PATH, "Phase 18 review view drifted")

    # The opening must rebase on a genuinely closed parent, not merely name one.
    closure = registry.get("phase17_closure", {})
    require(closure.get("status") == "phase17_closed_native_runtime_boundary",
            "Phase 17 is not closed; Phase 18 cannot open against it")
    require(snap["predecessor_closure_version"] == closure.get("status"),
            "Phase 18 predecessor closure version disagrees with the Phase 17 closure")

    entries = snap["entries"]
    ids = [e["id"] for e in entries]
    require(len(ids) == len(set(ids)), "duplicate Phase 18 opening row id")
    for entry in entries:
        eid = entry.get("id", "?")
        require(set(entry) == ENTRY_FIELDS, f"{eid}: opening row field set drifted")
        require(all(str(entry[f]).strip() for f in ENTRY_FIELDS if f != "selected"),
                f"{eid}: blank opening row field")
        require(entry["status"] == "candidate_deferred",
                f"{eid}: Patch 18.0 must not migrate a row")
        require(entry["current_failure_stage"] == "before_driver_discovery",
                f"{eid}: failure stage drifted")
        for field in ("positive_future_fixture", "negative_current_fixture"):
            path = ROOT / entry[field]
            require(path.is_file() and not path.is_symlink(), f"{eid}: missing {field}")

    fixtures = [e[f] for e in entries for f in ("positive_future_fixture", "negative_current_fixture")]
    require(len(fixtures) == len(set(fixtures)), "opening fixture paths are not unique")

    # Host assumptions: real, owned, and covering every reachability area.
    hosts = snap["host_assumption_inventory"]
    host_ids = [h["id"] for h in hosts]
    require(len(host_ids) == len(set(host_ids)), "duplicate host assumption id")
    for host in hosts:
        hid = host.get("id", "?")
        require(set(host) == HOST_FIELDS, f"{hid}: host assumption field set drifted")
        require(host["initial_classification"] == "classification_pending_patch18_1",
                f"{hid}: Patch 18.0 must not classify a host assumption")
        require(host["owning_phase18_entry_id"] in ids, f"{hid}: unknown owning Phase 18 row")
        require(host["reachability_area"] in REQUIRED_AREAS, f"{hid}: unknown reachability area")
        source = ROOT / host["source_path"]
        require(source.is_file() and not source.is_symlink(),
                f"{hid}: host assumption source does not exist: {host['source_path']}")
    covered = {h["reachability_area"] for h in hosts}
    missing = REQUIRED_AREAS - covered
    require(not missing, f"host assumption sweep missed reachability areas: {sorted(missing)}")

    # Candidate targets are unsupported until their tuple is proven.
    candidates = snap["candidate_targets"]
    triples = [c["target_triple"] for c in candidates]
    require(len(triples) == len(set(triples)), "duplicate candidate target triple")
    for candidate in candidates:
        tid = candidate.get("target_id", "?")
        require(set(candidate) == CANDIDATE_FIELDS, f"{tid}: candidate target field set drifted")
        require(candidate["support_decision"] == "unsupported_pending_tuple_evidence",
                f"{tid}: Patch 18.0 must not declare a target supported")
        require(set(candidate["missing_tuple_elements"]) == TUPLE_ELEMENTS,
                f"{tid}: every tuple element must be outstanding at Patch 18.0")
    require(snap["candidate_target_policy"] ==
            "every_candidate_target_is_unsupported_until_its_complete_compiler_runtime_linker_and_abi_tuple_is_proven",
            "candidate target policy drifted")

    # Residual rebase must account for everything Phase 18 inherits, from both parents.
    inherited = {
        row["source_residual_id"]
        for row in registry["opening_snapshots"]["phase17"]["residual_rebase"]
        if row.get("reassigned_destination_phase") == "phase18"
    }
    inherited |= {row["id"] for row in registry["phase17_deferred_residue_audit"]["narrow_deferred_rows"]}
    rebase = snap["residual_rebase"]
    rebase_ids = [row["source_residual_id"] for row in rebase]
    require(len(rebase_ids) == len(set(rebase_ids)), "duplicate residual rebase row")
    unaccounted = inherited - set(rebase_ids)
    require(not unaccounted, f"inherited residuals with no Phase 18 disposition: {sorted(unaccounted)}")
    unknown = set(rebase_ids) - inherited
    require(not unknown, f"residual rebase rows with no inherited source: {sorted(unknown)}")

    for row in rebase:
        rid = row["source_residual_id"]
        require(set(row) == REBASE_FIELDS, f"{rid}: residual rebase field set drifted")
        require(all(str(row[f]).strip() for f in ("residual_origin", "phase18_disposition",
                                                  "reassigned_capability", "justification")),
                f"{rid}: blank residual rebase field")
        selected = row["selected_phase18_entry_ids"]
        require(all(entry_id in ids for entry_id in selected), f"{rid}: unknown selected Phase 18 row")
        disposition = row["phase18_disposition"]
        if disposition == "selected":
            require(selected, f"{rid}: selected residual names no Phase 18 row")
        elif disposition == "reassigned":
            require(not selected, f"{rid}: reassigned residual must not select a Phase 18 row")
            require(row["reassigned_destination_phase"] != "phase18",
                    f"{rid}: reassigned residual cannot point back at Phase 18")
        else:  # split
            require(selected, f"{rid}: split residual names no Phase 18 row")
            require(row["reassigned_destination_phase"] != "phase18",
                    f"{rid}: split residual cannot defer the remainder to Phase 18")

    # CI families are derived, never hand-listed.
    projection = snap["ci_family_projection"]
    expected = list(dict.fromkeys(e["ci_family"] for e in entries))
    require(projection["family_ids"] == expected,
            "Phase 18 CI family projection is not derived from the opening rows in first-occurrence order")

    # Patch 18.0 changes no behavior and adds no Level 2 or Level 3 workflow rows.
    # PR Fast and Heavy Guards keep the absolute ban; the ban is never deleted.
    for workflow in (".github/workflows/pr-fast.yml", ".github/workflows/heavy-guards.yml"):
        text = (ROOT / workflow).read_text()
        for token in ("phase18-family:", "matrix.phase18", "phase18-parity",
                      "phase18-differential", "phase18-complete-target"):
            require(token not in text, f"Phase 18 opening must not add {token} to {workflow}")

    # Cranelift Historical Full is the sole Level 3 owner, so from Patch 18.17 it
    # may carry exactly the complete-target-evidence row and nothing else. This
    # follows the Phase 16 and Phase 17 precedent: the ban is gated on registry
    # evidence rather than removed.
    historical = (ROOT / ".github/workflows/cranelift-historical-full.yml").read_text()
    permitted = "just guard-cranelift-phase18-complete-target-evidence"
    unowned = [
        line.strip() for line in historical.splitlines()
        if any(token in line for token in
               ("phase18-family:", "matrix.phase18", "phase18-parity",
                "phase18-differential", "phase18-complete-target"))
        and permitted not in line
    ]
    require(not unowned,
            f"Cranelift Historical Full carries an unowned Phase 18 row: {unowned}")

    # The permission exists exactly when the composition authority does. Adding
    # the row early and dropping it afterwards are both ownership drift.
    expected_rows = 1 if "phase18_composition" in registry else 0
    actual_rows = historical.count(permitted)
    require(actual_rows == expected_rows,
            "Phase 18 complete target evidence Level 3 ownership drifted: "
            f"expected {expected_rows}, found {actual_rows}")
    return snap


def render(snap: dict) -> str:
    lines = [
        "# Cranelift Phase 18 Opening Inventory",
        "",
        f"- Opening version: `{snap['opening_version']}`",
        f"- Inventory version: `{snap['inventory_version']}`",
        f"- Status: `{snap['status']}`",
        f"- Predecessor closure: `{snap['predecessor_closure_version']}`",
        f"- Opening rows: `{len(snap['entries'])}`",
        f"- Host assumptions: `{len(snap['host_assumption_inventory'])}`",
        f"- Candidate targets: `{len(snap['candidate_targets'])}`",
        f"- Inherited residuals rebased: `{len(snap['residual_rebase'])}`",
        f"- Projected CI families: `{len(snap['ci_family_projection']['family_ids'])}`",
        "",
        "## Opening rows",
        "",
        "| ID | Feature family | CI family | Capability owner | Status |",
        "| --- | --- | --- | --- | --- |",
    ]
    for entry in snap["entries"]:
        lines.append(f"| `{entry['id']}` | {entry['feature_family']} | {entry['ci_family']} "
                     f"| {entry['capability_owner']} | {entry['status']} |")
    lines += ["", "## Host assumptions", "",
              "| ID | Reachability area | Owning row | Source |",
              "| --- | --- | --- | --- |"]
    for host in snap["host_assumption_inventory"]:
        lines.append(f"| `{host['id']}` | {host['reachability_area']} "
                     f"| `{host['owning_phase18_entry_id']}` | `{host['source_path']}` |")
    lines += ["", "## Candidate targets", "",
              "Every candidate is unsupported until its complete compiler, runtime, linker, and ABI tuple is proven.",
              "", "| Target | Support decision | Missing tuple elements |", "| --- | --- | --- |"]
    for candidate in snap["candidate_targets"]:
        lines.append(f"| `{candidate['target_triple']}` | {candidate['support_decision']} "
                     f"| {', '.join(candidate['missing_tuple_elements'])} |")
    lines += ["", "## Inherited residual rebase", "",
              "| Source residual | Origin | Disposition | Selected rows | Destination |",
              "| --- | --- | --- | --- | --- |"]
    for row in snap["residual_rebase"]:
        selected = ", ".join(f"`{x}`" for x in row["selected_phase18_entry_ids"]) or "—"
        lines.append(f"| `{row['source_residual_id']}` | {row['residual_origin']} "
                     f"| {row['phase18_disposition']} | {selected} | {row['reassigned_destination_phase']} |")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review", "families"))
    args = parser.parse_args()
    registry = json.loads(REGISTRY.read_text())
    try:
        snap = validate(registry)
        if args.command == "project":
            REVIEW.parent.mkdir(parents=True, exist_ok=True)
            REVIEW.write_text(render(snap), encoding="utf-8")
        elif args.command == "check-review":
            require(REVIEW.is_file(), f"missing generated review: {REVIEW_PATH}")
            require(REVIEW.read_text(encoding="utf-8") == render(snap),
                    "generated Phase 18 opening review is stale; run `project`")
        elif args.command == "families":
            for family in snap["ci_family_projection"]["family_ids"]:
                print(family)
    except Error as error:
        print(f"{GUARD}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
