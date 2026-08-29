#!/usr/bin/env python3
"""Validate and project Patch 22.2's explicit-C migration authority."""

from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE22_EXPLICIT_C_MIGRATION.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase22-explicit-c-migration.yml"
ENTRY = ROOT / "compiler/test_runner_entry.gst"
BRIDGE = ROOT / "compiler/test_runner_bootstrap_bridge_entry.gst"
GUARD_L1 = "guard-cranelift-phase22-explicit-c-migration-contract"
GUARD_L2 = "guard-cranelift-phase22-explicit-c-migration-evidence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def opening_module():
    path = ROOT / "scripts/phase22_opening.py"
    spec = importlib.util.spec_from_file_location("phase22_opening", path)
    require(spec is not None and spec.loader is not None,
            "cannot load the Patch 22.1 scanner")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def validate() -> tuple[dict, list[dict[str, object]]]:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    opening = registry.get("phase22_opening", {})
    require(opening.get("contract_version") == "phase22_opening_v2",
            "opening authority drifted")
    record = registry.get("phase22_explicit_c_migration")
    require(isinstance(record, dict), "Patch 22.2 authority is missing")
    require(record.get("contract_version") == "phase22_explicit_c_migration_v1",
            "contract version drifted")
    require(record.get("status") ==
            "cranelift_owned_migration_complete_cross_lane_pending" and
            record.get("next_action") == "stdlib_owned_consumer_relay",
            "status or next action drifted")
    require(record.get("observed_main_sha") ==
            "831a125263961943e81dc4888c3f83458325af4f",
            "observed main drifted")
    require(record.get("opening_authority") == opening.get("contract_version"),
            "opening authority link drifted")
    require(record.get("route_contract") == {
        "default_backend": "mir_to_c_unchanged",
        "explicit_mir_to_c": "mir_to_c",
        "explicit_c": "exact_alias_of_mir_to_c",
        "explicit_cranelift": "unchanged",
        "backend_selection_stage": "after_shared_resolver_parser_and_typechecker",
        "fallback_policy": "forbidden",
    }, "route contract drifted")

    scanner = opening_module()
    rows = scanner.scan_invocations()
    summary = scanner.scan_summary(rows)
    require(summary == record.get("current_invocation_inventory"),
            f"current invocation inventory drifted: {summary!r}")
    migration = record.get("migration", {})
    has_implicit_output_successor = "phase22_native_implicit_output" in registry
    expected_patch22_invocations = 17 if has_implicit_output_successor else 7
    expected_patch22_implicit = 3 if has_implicit_output_successor else 2
    require(migration.get("opening_implicit_count") ==
            opening.get("invocation_inventory", {}).get("selection_counts", {}).get(
                "implicit_default") and
            migration.get("current_implicit_count") ==
            summary["selection_counts"]["implicit_default"] and
            migration.get("cranelift_owned_migrated_count") == 60 and
            migration.get("patch22_evidence_invocation_count") ==
            expected_patch22_invocations and
            migration.get("patch22_evidence_implicit_count") ==
            expected_patch22_implicit and
            migration.get("opening_implicit_count") +
            migration.get("patch22_evidence_implicit_count") -
            migration.get("current_implicit_count") == 60,
            "migration accounting drifted")
    require(sum(migration.get(key, 0) for key in (
        "bootstrap_migrated_count", "repository_guard_migrated_count",
        "script_guard_migrated_count", "developer_pipeline_migrated_count",
    )) == 60, "migration-class accounting drifted")

    implicit = [row for row in rows if row["selection"] == "implicit_default"]
    allowed_cranelift = {
        "help_surface_probe", "intentional_default_selection_probe",
        "invocation_parser_probe",
    }
    require(all(row["consumer_class"] in allowed_cranelift
                for row in implicit if row["owner"] == "cranelift"),
            "a Cranelift-owned C dependency still omits backend selection")
    relay_rows = [row for row in implicit if row["owner"] == "stdlib"]
    relay = record.get("cross_lane_relay", {})
    require(len(relay_rows) == relay.get("consumer_count") == 15,
            "cross-lane relay count drifted")
    require(sorted({str(row["path"]) for row in relay_rows}) ==
            sorted(relay.get("paths", [])),
            "cross-lane relay path set drifted")
    require(relay.get("status") == "pending_owning_lane_correction" and
            relay.get("owner") == "stdlib",
            "cross-lane relay status drifted")

    entry = ENTRY.read_text(encoding="utf-8")
    for marker in (
        'os.LogStr("  gust --backend c <source.gst>");',
        'std.str_eq(backend_name, "c") == 1',
        'os.LogStr("  --backend <mir-to-c|c|cranelift>  Select the backend explicitly.");',
    ):
        require(marker in entry, f"explicit-C source marker is missing: {marker}")
    require(entry.count("codegen.codegen_generate(programs, module_prefixes, &env, ctx)") == 1,
            "explicit C spellings no longer share one MIR-to-C codegen call")
    bridge = BRIDGE.read_text(encoding="utf-8")
    require('std.str_eq(args[2], "mir-to-c") == 1' in bridge and
            'std.str_eq(args[2], "c") == 1' in bridge,
            "bootstrap bridge does not admit both explicit C spellings")

    task = TASK.read_text(encoding="utf-8")
    require("- [ ] Patch 22.2 — Explicit C Route and No-op Consumer Migration" in task,
            "Patch 22.2 must remain open while the owning Stdlib relay is pending")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "guard levels drifted")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in just and f"{GUARD_L2}:" in just,
            "just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the migration contract")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow,
            "dedicated workflow does not own both guards")
    boundary = record.get("boundary", {})
    require(boundary and all(value is False for value in boundary.values()),
            "Patch 22.2 widened beyond the recorded boundary")
    return record, relay_rows


def render(record: dict, relay_rows: list[dict[str, object]]) -> str:
    migration = record["migration"]
    inventory = record["current_invocation_inventory"]
    lines = [
        "# Cranelift Phase 22.2 — Explicit C Route and No-op Consumer Migration",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` and the live",
        "repository invocation scan. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next action: `{record['next_action']}`",
        f"- Observed main: `{record['observed_main_sha']}`",
        f"- Default backend: `{record['route_contract']['default_backend']}`",
        f"- Explicit `c`: `{record['route_contract']['explicit_c']}`",
        f"- Cranelift-owned migrations: `{migration['cranelift_owned_migrated_count']}`",
        f"- Remaining implicit consumers: `{inventory['selection_counts']['implicit_default']}`",
        f"- Pending Stdlib-owned consumers: `{len(relay_rows)}`",
        "",
        "## Migration classes",
        "",
        f"- Bootstrap/final compiler C generation: `{migration['bootstrap_migrated_count']}`",
        f"- Repository guards: `{migration['repository_guard_migrated_count']}`",
        f"- Script guards: `{migration['script_guard_migrated_count']}`",
        f"- Developer C pipeline: `{migration['developer_pipeline_migrated_count']}`",
        "",
        "## Preserved implicit consumers",
        "",
    ]
    for key, value in record["preserved_implicit_classes"].items():
        lines.append(f"- `{key}`: `{value}`")
    lines += [
        "", "## Cross-lane relay", "",
        "| Path | Line | Expected artifact | Falsifier |",
        "| --- | ---: | --- | --- |",
    ]
    for row in relay_rows:
        lines.append(
            f"| `{row['path']}` | {row['line']} | `{row['expected_artifact']}` | "
            f"`{row['falsifier']}` |"
        )
    lines += [
        "",
        "Patch 22.2 remains open: the Cranelift-owned no-op migration is",
        "complete, but the roadmap exit gate forbids DONE status or a later",
        "default flip until these owning Stdlib corrections merge. This patch",
        "does not edit Stdlib or change the MIR-to-C default.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review"))
    args = parser.parse_args()
    record, relay_rows = validate()
    expected = render(record, relay_rows)
    if args.command == "project":
        REVIEW.write_text(expected, encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and REVIEW.read_text(encoding="utf-8") == expected,
                "generated migration review is stale; run project")
    else:
        print(f"{GUARD_L1}: ok (60 migrated, 15 Stdlib relay rows pending)")


if __name__ == "__main__":
    main()
