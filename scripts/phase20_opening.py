#!/usr/bin/env python3
"""Validate and project the Patch 20.0 opening evidence authority."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase20-opening-contract"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_OPENING.md"
TASK = ROOT / "TASK.md"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"

PROBE_FIELDS = {
    "id", "source_requirement", "fixture", "compile_exit",
    "current_verdict", "diagnostic_substrings", "semantic_owner",
    "next_patch", "fix_enabled",
}
OBSERVABLE_FIELDS = {"id", "comparison", "owner"}
COHORT_FIELDS = {"decision", "owner_policy", "reason_policy", "falsifier"}
REQUIRED_PROBES = {
    "cr11_explicit_graph_annotation": ("CR-11/#158", 0, "20.2"),
    "cr12_wrong_brand_clone_destination": ("CR-12/#159", 1, "20.3"),
    "cr13_freed_receiver_reuse": ("CR-13/#160", 1, "20.5"),
    "issue106_unbound_directory_payload": ("CR-5/#106", 0, "20.9"),
    "issue106_bound_directory_control": ("CR-5/#106", 1, "20.9"),
}
REQUIRED_OBSERVABLES = {
    "compile_result", "process_exit_status", "stdout", "stderr",
    "diagnostic_code_and_span", "resource_terminal_state",
    "sandboxed_filesystem_effects",
}
STATUS_DECISIONS = {
    "migrated": "selected",
    "candidate_deferred": "deferred",
    "deferred": "deferred",
    "replaced": "unsupported_historical_replaced",
}
PROJECTION_FIELDS = {
    "registry_path", "test_levels_path", "historical_workflow_path",
    "entry_status_decisions", "required_entry_owner_fields",
    "source_pair_fields", "composition_field", "deferred_fixture_fields",
    "level3_selection", "projection_policy",
}


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def nested(row: dict, dotted: str, default=None):
    value = row
    for part in dotted.split("."):
        if not isinstance(value, dict) or part not in value:
            return default
        value = value[part]
    return value


def validate() -> tuple[dict, list[dict], list[tuple[str, str]], list[tuple[str, str]], list[str]]:
    registry = load(REGISTRY)
    levels = load(LEVELS)
    snap = registry.get("opening_snapshots", {}).get("phase20")
    require(isinstance(snap, dict), "Phase 20 opening snapshot is missing")
    require(snap.get("opening_version") ==
            "phase20_opening_evidence_and_qualification_authority_v1",
            "Phase 20 opening version drifted")
    require(snap.get("status") == "ready_for_patch20_7",
            "Phase 20 opening status drifted")
    require(snap.get("next_patch") == "20.7", "Phase 20 successor drifted")
    require(snap.get("roadmap_merge_sha") ==
            "1cfab1344b24ffefc72b4d752ead3eb17c6719c6",
            "Phase 20 roadmap merge drifted")
    require(snap.get("review_view") == "compiler/CRANELIFT_PHASE20_OPENING.md",
            "Phase 20 review path drifted")
    require(registry.get("phase19_closure", {}).get("status") ==
            snap.get("predecessor_closure_status"),
            "Phase 20 opening does not trace to the Phase 19 closure")
    require("- [x] Patch 20.0 — Opening Evidence and Qualification Authority — DONE" in
            TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 20.0 DONE")
    pr_fast = PR_FAST.read_text(encoding="utf-8")
    require("Phase 20 opening evidence and qualification authority" in pr_fast and
            "run: just guard-cranelift-phase20-opening-contract" in pr_fast,
            "PR Fast does not own the Phase 20 opening guard")

    probes = snap.get("baseline_probes")
    require(isinstance(probes, list) and len(probes) == 5,
            "Phase 20 must freeze exactly five opening probes")
    seen = set()
    for probe in probes:
        require(set(probe) == PROBE_FIELDS,
                f"probe {probe.get('id')!r} has unexpected fields")
        probe_id = probe["id"]
        require(probe_id not in seen, f"duplicate probe {probe_id!r}")
        seen.add(probe_id)
        require(probe_id in REQUIRED_PROBES, f"unknown probe {probe_id!r}")
        requirement, exit_code, next_patch = REQUIRED_PROBES[probe_id]
        require((probe["source_requirement"], probe["compile_exit"], probe["next_patch"]) ==
                (requirement, exit_code, next_patch),
                f"probe {probe_id!r} verdict or owner patch drifted")
        expected_fix = probe_id in {
            "cr11_explicit_graph_annotation",
            "cr12_wrong_brand_clone_destination",
            "cr13_freed_receiver_reuse",
        }
        require(probe["fix_enabled"] is expected_fix,
                f"probe {probe_id!r} fix state drifted")
        require(probe["current_verdict"], f"probe {probe_id!r} lacks a verdict")
        require(probe["semantic_owner"].startswith("compiler_"),
                f"probe {probe_id!r} is not compiler-owned")
        fixture = ROOT / probe["fixture"]
        require(fixture.is_file(), f"probe {probe_id!r} fixture is missing")
        source = fixture.read_text(encoding="utf-8")
        require(f"current_result: {probe['current_verdict']}" in source,
                f"probe {probe_id!r} fixture verdict marker drifted")
        owner_marker = f"next_patch: {probe['next_patch']}"
        if expected_fix:
            owner_marker = f"fixed_by: {probe['next_patch']}"
        require(owner_marker in source,
                f"probe {probe_id!r} fixture owner marker drifted")
    require(seen == set(REQUIRED_PROBES), "Phase 20 probe population is incomplete")

    projection = snap.get("qualification_projection")
    require(isinstance(projection, dict) and set(projection) == PROJECTION_FIELDS,
            "qualification projection fields drifted")
    require(projection["registry_path"] == "scripts/cranelift_feature_registry.json",
            "qualification projection does not use the canonical registry")
    require(projection["test_levels_path"] == "scripts/cranelift_test_levels.json",
            "qualification projection does not use canonical test levels")
    require(projection["historical_workflow_path"] ==
            ".github/workflows/cranelift-historical-full.yml",
            "qualification projection does not name Historical Full")
    require(projection["entry_status_decisions"] == STATUS_DECISIONS,
            "qualification status decision map drifted")
    for path in (projection["registry_path"], projection["test_levels_path"],
                 projection["historical_workflow_path"]):
        require((ROOT / path).is_file(), f"qualification source {path!r} is missing")

    entries = registry.get("entries")
    require(isinstance(entries, list) and entries,
            "canonical feature registry has no entries")
    entry_ids = set()
    composition_links: list[tuple[str, str]] = []
    deferred_links: list[tuple[str, str]] = []
    owner_fields = projection["required_entry_owner_fields"]
    pair_fields = projection["source_pair_fields"]
    for entry in entries:
        entry_id = entry.get("id")
        require(isinstance(entry_id, str) and entry_id not in entry_ids,
                f"duplicate or invalid registry entry {entry_id!r}")
        entry_ids.add(entry_id)
        require(entry.get("status") in STATUS_DECISIONS,
                f"entry {entry_id!r} has an unnamed qualification status")
        for field in owner_fields + pair_fields:
            require(isinstance(entry.get(field), str) and entry[field],
                    f"entry {entry_id!r} lacks qualification field {field!r}")
        source = entry[pair_fields[0]]
        if source != "none" and source.startswith("compiler/"):
            require((ROOT / source).is_file(),
                    f"entry {entry_id!r} source fixture is missing: {source}")
        for case in nested(entry, projection["composition_field"], []) or []:
            require(isinstance(case, str) and case,
                    f"entry {entry_id!r} has an invalid composition link")
            composition_links.append((entry_id, case))
        deferred = "none"
        for field in projection["deferred_fixture_fields"]:
            candidate = nested(entry, field)
            if isinstance(candidate, str) and candidate != "none":
                deferred = candidate
                break
        if deferred != "none":
            if deferred.startswith("compiler/"):
                require((ROOT / deferred).is_file(),
                        f"entry {entry_id!r} deferred fixture is missing: {deferred}")
            deferred_links.append((entry_id, deferred))

    guards = levels.get("guards")
    require(isinstance(guards, dict), "test-level guard map is missing")
    level3 = sorted(guard for guard, level in guards.items() if level == 3)
    require(level3, "Historical Full owns no Level 3 guards")

    observables = snap.get("observables")
    require(isinstance(observables, list) and len(observables) == 7,
            "Phase 20 must declare seven observables")
    observable_ids = set()
    for observable in observables:
        require(set(observable) == OBSERVABLE_FIELDS,
                f"observable {observable.get('id')!r} has unexpected fields")
        require(observable["id"] not in observable_ids,
                f"duplicate observable {observable['id']!r}")
        observable_ids.add(observable["id"])
        require(observable["comparison"] and observable["owner"],
                f"observable {observable['id']!r} is unowned")
    require(observable_ids == REQUIRED_OBSERVABLES,
            "Phase 20 observable vocabulary is incomplete")

    cohorts = snap.get("cohort_requirements")
    require(isinstance(cohorts, list) and len(cohorts) == 3,
            "Phase 20 cohort requirements are incomplete")
    decisions = set()
    for cohort in cohorts:
        require(set(cohort) == COHORT_FIELDS,
                f"cohort {cohort.get('decision')!r} has unexpected fields")
        decisions.add(cohort["decision"])
        require(all(cohort[field] for field in COHORT_FIELDS - {"decision"}),
                f"cohort {cohort['decision']!r} lacks owner/reason/falsifier")
    require(decisions == set(STATUS_DECISIONS.values()),
            "Phase 20 qualification leaves an unnamed cohort")

    return snap, entries, composition_links, deferred_links, level3


def render(snap: dict, entries: list[dict], composition_links: list[tuple[str, str]],
           deferred_links: list[tuple[str, str]], level3: list[str]) -> str:
    counts = Counter(entry["status"] for entry in entries)
    lines = [
        "# Cranelift Phase 20 Opening Evidence",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` and",
        "`scripts/cranelift_test_levels.json` by `scripts/phase20_opening.py`.",
        "Do not edit by hand.",
        "",
        f"- Opening version: `{snap['opening_version']}`",
        f"- Status: `{snap['status']}`",
        f"- Roadmap merge: `{snap['roadmap_merge_sha']}`",
        f"- Baseline probes: `{len(snap['baseline_probes'])}`",
        f"- Canonical feature entries: `{len(entries)}`",
        f"- Composition links: `{len(composition_links)}`",
        f"- Deferred-source links: `{len(deferred_links)}`",
        f"- Historical Full Level 3 guards: `{len(level3)}`",
        "",
        "## Baseline probes",
        "",
        "| ID | Requirement | Fixture | Current exit | Current verdict | Owner patch |",
        "| --- | --- | --- | ---: | --- | --- |",
    ]
    for probe in snap["baseline_probes"]:
        lines.append(
            f"| `{probe['id']}` | {probe['source_requirement']} | `{probe['fixture']}` "
            f"| {probe['compile_exit']} | {probe['current_verdict']} | {probe['next_patch']} |"
        )

    lines += [
        "",
        "The current verdict is evidence. CR-11 is enabled by Patch 20.2; the",
        "remaining probes stay disabled until their named owner patches.",
        "",
        "## Qualification decisions",
        "",
        "| Registry status | Phase 20 decision | Entries |",
        "| --- | --- | ---: |",
    ]
    mapping = snap["qualification_projection"]["entry_status_decisions"]
    for status, decision in mapping.items():
        lines.append(f"| `{status}` | `{decision}` | {counts[status]} |")

    lines += [
        "",
        "## Canonical source/differential inventory",
        "",
        "| Entry | Status | Decision | Route owner | Worker owner | Diagnostic owner | Source | Differential case |",
        "| --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for entry in entries:
        lines.append(
            f"| `{entry['id']}` | `{entry['status']}` | `{mapping[entry['status']]}` "
            f"| `{entry['route_owner']}` | `{entry['worker_capability_owner']}` "
            f"| `{entry['diagnostic_owner']}` | `{entry['source_fixture']}` "
            f"| `{entry['differential_case_id']}` |"
        )

    lines += [
        "",
        "## Composition links",
        "",
        "| Entry | Composition case |",
        "| --- | --- |",
    ]
    lines.extend(f"| `{entry}` | `{case}` |" for entry, case in composition_links)

    lines += [
        "",
        "## Deferred-source links",
        "",
        "| Entry | Deferred evidence |",
        "| --- | --- |",
    ]
    lines.extend(f"| `{entry}` | `{fixture}` |" for entry, fixture in deferred_links)

    lines += [
        "",
        "## Observable vocabulary",
        "",
        "| Observable | Comparison | Owner |",
        "| --- | --- | --- |",
    ]
    for observable in snap["observables"]:
        lines.append(
            f"| `{observable['id']}` | {observable['comparison']} | `{observable['owner']}` |"
        )

    lines += [
        "",
        "## Historical Full Level 3 inventory",
        "",
    ]
    lines.extend(f"- `{guard}`" for guard in level3)
    lines += [
        "",
        "Registration is not a pass claim. Phase 20 closure requires a successful",
        "authoritative Historical Full run on exact merged main.",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review"))
    args = parser.parse_args()
    try:
        data = validate()
        rendered = render(*data)
        if args.command == "project":
            REVIEW.write_text(rendered, encoding="utf-8")
        elif args.command == "check-review":
            require(REVIEW.is_file(), "generated Phase 20 opening review is missing")
            require(REVIEW.read_text(encoding="utf-8") == rendered,
                    "generated Phase 20 opening review is stale; run project")
    except (Error, json.JSONDecodeError) as error:
        print(f"{GUARD}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
