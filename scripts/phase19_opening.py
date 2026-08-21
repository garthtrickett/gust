#!/usr/bin/env python3
"""Validate and project the Patch 19.0 Phase 19 opening inventory.

Phase 19 owns brand identity and value representation. Its opening inventory
records where the active self-hosted compiler decides those things from an
identifier's spelling, so that later patches remove those decisions against a
written list rather than against memory.

The inventory is registry-derived: the review view under compiler/ is generated
from the snapshot, never hand-edited, and `check-review` fails if the two drift.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase19-opening-contract"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE19_OPENING.md"
REVIEW_PATH = "compiler/CRANELIFT_PHASE19_OPENING.md"

ENTRY_FIELDS = {
    "id", "parent", "feature_family", "ci_family", "capability_owner",
    "diagnostic_owner", "target_applicability", "status",
    "current_failure_stage", "source_requirement",
    "positive_future_fixture", "negative_current_fixture",
}
HOST_FIELDS = {
    "id", "assumption", "source_path", "reachability_area", "inventory_owner",
    "diagnostic_owner", "owning_phase19_entry_id", "initial_classification",
    "target_applicability",
}
VOCABULARY_FIELDS = {"id", "source_path", "line", "compiler", "names"}
REBASE_FIELDS = {
    "source_residual_id", "residual_origin", "phase19_disposition",
    "selected_phase19_entry_ids", "justification",
}

# The four areas a spelling-derived decision can reach. An assumption outside
# these is not a Phase 19 concern; a missing area means the sweep was partial.
REQUIRED_AREAS = {
    "brand_resolution", "type_naming",
    "container_classification", "argument_representation",
}
# The deprecated Rust prototype is removed. Phase 19 follows the
# self-hosted compiler that participates in the bootstrap chain.
REQUIRED_COMPILERS = {"self_hosted"}

# CR-2's own text is the source requirement for the phase; these are the rows
# that must exist for it and for the two shared-zone decisions.
REQUIRED_REQUIREMENTS = {
    "TASK_STDLIB.md CR-2",
    "docs/SHARED_SEMANTIC_ZONE.md D-1",
    "docs/SHARED_SEMANTIC_ZONE.md D-1",
}


class Error(Exception):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def snapshot(registry: dict) -> dict:
    snapshots = registry.get("opening_snapshots", {})
    require("phase19" in snapshots, "Phase 19 opening snapshot missing")
    return snapshots["phase19"]


def validate(registry: dict) -> dict:
    snap = snapshot(registry)

    require(snap["opening_version"] == "phase19_opening_inventory_rebased_on_phase18_closure",
            "Phase 19 opening version drifted")
    require(snap["inventory_version"] == "phase19_opening_inventory_self_hosted_v2",
            "Phase 19 inventory version drifted")
    require(snap["status"] == "ready_for_patch19_1", "Phase 19 opening status drifted")
    require(snap["next_patch"] == "19.1", "Phase 19 next patch drifted")
    require(snap["review_view"] == REVIEW_PATH, "Phase 19 review view drifted")

    # The opening must rebase on a genuinely closed parent, not merely name one.
    closure = registry.get("phase18_closure", {})
    require(closure.get("status") == snap["predecessor_closure_version"],
            "Phase 19 opening does not trace to the recorded Phase 18 closure")

    entries = snap["entries"]
    require(entries, "Phase 19 opening has no rows")
    seen_ids = set()
    for entry in entries:
        require(set(entry) == ENTRY_FIELDS,
                f"Phase 19 row {entry.get('id')!r} has unexpected fields")
        require(entry["id"] not in seen_ids, f"duplicate Phase 19 row {entry['id']!r}")
        seen_ids.add(entry["id"])
        require(entry["status"] == "candidate_deferred",
                f"Phase 19 row {entry['id']!r} must open deferred")
        require(entry["current_failure_stage"] == "before_driver_discovery",
                f"Phase 19 row {entry['id']!r} must fail before driver discovery")

    requirements = {entry["source_requirement"] for entry in entries}
    missing = REQUIRED_REQUIREMENTS - requirements
    require(not missing, f"Phase 19 opening does not own: {sorted(missing)}")

    # Parent traceability: the first row rebases on Phase 18's closure, the rest
    # on Phase 19 planning. A row parented on nothing is not traceable.
    for entry in entries:
        parent = entry["parent"]
        require(parent.startswith("phase18_closure:") or parent.startswith("phase19_planning:"),
                f"Phase 19 row {entry['id']!r} has an untraceable parent {parent!r}")
        if parent.startswith("phase18_closure:"):
            require(parent.split(":", 1)[1] == snap["predecessor_closure_version"],
                    f"Phase 19 row {entry['id']!r} names a different Phase 18 closure")

    hosts = snap["host_assumptions"]
    require(hosts, "Phase 19 opening inventoried no host assumptions")
    host_ids = set()
    for host in hosts:
        require(set(host) == HOST_FIELDS,
                f"host assumption {host.get('id')!r} has unexpected fields")
        require(host["id"] not in host_ids, f"duplicate host assumption {host['id']!r}")
        host_ids.add(host["id"])
        require(host["reachability_area"] in REQUIRED_AREAS,
                f"host assumption {host['id']!r} names an out-of-boundary area")
        require(host["owning_phase19_entry_id"] in seen_ids,
                f"host assumption {host['id']!r} is owned by no Phase 19 row")
        require((ROOT / host["source_path"]).is_file(),
                f"host assumption {host['id']!r} cites a missing file {host['source_path']}")

    areas = {host["reachability_area"] for host in hosts}
    require(areas == REQUIRED_AREAS,
            f"host assumption sweep is incomplete: missing {sorted(REQUIRED_AREAS - areas)}")

    vocabularies = snap["brand_vocabularies"]
    require(vocabularies, "Phase 19 opening recorded no brand vocabulary")
    vocab_ids = set()
    for vocab in vocabularies:
        require(set(vocab) == VOCABULARY_FIELDS,
                f"brand vocabulary {vocab.get('id')!r} has unexpected fields")
        require(vocab["id"] not in vocab_ids, f"duplicate brand vocabulary {vocab['id']!r}")
        vocab_ids.add(vocab["id"])
        require(vocab["compiler"] in REQUIRED_COMPILERS,
                f"brand vocabulary {vocab['id']!r} names an unknown compiler")
        require(vocab["names"], f"brand vocabulary {vocab['id']!r} is empty")
        require((ROOT / vocab["source_path"]).is_file(),
                f"brand vocabulary {vocab['id']!r} cites a missing file {vocab['source_path']}")

    compilers = {vocab["compiler"] for vocab in vocabularies}
    require(compilers == REQUIRED_COMPILERS,
            f"brand vocabulary sweep covers only {sorted(compilers)}")

    for row in snap["phase18_rebase"]:
        require(set(row) == REBASE_FIELDS,
                f"rebase row {row.get('source_residual_id')!r} has unexpected fields")
        for selected in row["selected_phase19_entry_ids"]:
            require(selected in seen_ids,
                    f"rebase row {row['source_residual_id']!r} selects unknown row {selected!r}")

    return snap


def render(snap: dict) -> str:
    lines = [
        "# Cranelift Phase 19 Opening Inventory",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase19_opening.py project`. Do not edit by hand.",
        "",
        f"- Opening version: `{snap['opening_version']}`",
        f"- Inventory version: `{snap['inventory_version']}`",
        f"- Status: `{snap['status']}`",
        f"- Predecessor closure: `{snap['predecessor_closure_version']}`",
        f"- Opening rows: `{len(snap['entries'])}`",
        f"- Host assumptions: `{len(snap['host_assumptions'])}`",
        f"- Brand vocabularies: `{len(snap['brand_vocabularies'])}`",
        f"- Inherited residuals rebased: `{len(snap['phase18_rebase'])}`",
        "- Compiler scope: `self_hosted` (the deprecated root Rust prototype is removed)",
        "",
        "## Opening rows",
        "",
        "| ID | Feature family | CI family | Source requirement | Status |",
        "| --- | --- | --- | --- | --- |",
    ]
    for entry in snap["entries"]:
        lines.append(f"| `{entry['id']}` | {entry['feature_family']} | {entry['ci_family']} "
                     f"| {entry['source_requirement']} | {entry['status']} |")

    lines += ["", "## Brand vocabularies", "",
              "Every list the self-hosted compiler consults to decide brand identity",
              "from a spelling. The compiler scans first-match-wins and restarts until",
              "stable, so the order of a list is part of its behaviour, not presentation.",
              "", "| ID | Compiler | Source | Names |", "| --- | --- | --- | --- |"]
    for vocab in snap["brand_vocabularies"]:
        names = ", ".join(f"`{n}`" for n in vocab["names"])
        lines.append(f"| `{vocab['id']}` | {vocab['compiler']} "
                     f"| `{vocab['source_path']}:{vocab['line']}` | {names} |")

    lines += ["", "## Host assumptions", "",
              "| ID | Reachability area | Owning row | Source | Classification |",
              "| --- | --- | --- | --- | --- |"]
    for host in snap["host_assumptions"]:
        lines.append(f"| `{host['id']}` | {host['reachability_area']} "
                     f"| `{host['owning_phase19_entry_id']}` | `{host['source_path']}` "
                     f"| {host['initial_classification']} |")

    lines += ["", "## Inherited residual rebase", "",
              "| Source residual | Origin | Disposition | Selected rows |",
              "| --- | --- | --- | --- |"]
    for row in snap["phase18_rebase"]:
        selected = ", ".join(f"`{x}`" for x in row["selected_phase19_entry_ids"]) or "—"
        lines.append(f"| `{row['source_residual_id']}` | {row['residual_origin']} "
                     f"| {row['phase19_disposition']} | {selected} |")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review"))
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
                    "generated Phase 19 opening review is stale; run `project`")
    except Error as error:
        print(f"{GUARD}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
