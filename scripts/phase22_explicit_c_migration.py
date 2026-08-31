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


def validate() -> tuple[dict, str]:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    opening = registry.get("phase22_opening", {})
    require(opening.get("contract_version") == "phase22_opening_v2",
            "opening authority drifted")
    record = registry.get("phase22_explicit_c_migration")
    require(isinstance(record, dict), "Patch 22.2 authority is missing")
    require(record.get("contract_version") == "phase22_explicit_c_migration_v2",
            "contract version drifted")
    require(record.get("status") == "complete_post_relay" and
            record.get("next_action") == "patch22_6_default_route_flip",
            "status or next action drifted")
    require(record.get("observed_main_sha") ==
            "d7c0a733c211a202bda417fb7d5b8ceb12ced415",
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
    pre_relay_inventory = record.get("current_invocation_inventory")
    post_relay_inventory = record.get(
        "authorized_post_relay_invocation_inventory"
    )
    relay_transition_state, transition = (
        scanner.validate_post_flip_relay_transition(registry, rows)
    )
    migration = record.get("migration", {})
    has_implicit_output_successor = "phase22_native_implicit_output" in registry
    has_preflip_successor = "phase22_preflip_default_cohort" in registry
    expected_patch22_invocations = (
        18 if has_preflip_successor else
        17 if has_implicit_output_successor else 7
    )
    expected_patch22_implicit = 3 if has_implicit_output_successor else 2
    require(migration.get("opening_implicit_count") ==
            opening.get("invocation_inventory", {}).get("selection_counts", {}).get(
                "implicit_default") and
            migration.get("current_implicit_count") ==
            pre_relay_inventory["selection_counts"]["implicit_default"] and
            migration.get("authorized_post_relay_implicit_count") ==
            post_relay_inventory["selection_counts"]["implicit_default"] and
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
    if "phase22_default_route_flip" in registry:
        allowed_cranelift.add("cranelift_C_or_diagnostic_guard")
    require(all(row["consumer_class"] in allowed_cranelift
                for row in implicit if row["owner"] == "cranelift"),
            "a Cranelift-owned C dependency still omits backend selection")
    relay_rows = [row for row in implicit if row["owner"] == "stdlib"]
    stdlib_rows = [row for row in rows if row["owner"] == "stdlib"]
    relay = record.get("cross_lane_relay", {})
    post_flip_relay = relay.get("post_flip_review_relay", {})
    require(post_flip_relay.get("status") ==
            "landed_exact_post_relay_only" and
            post_flip_relay.get("review_pull_request") == 251 and
            post_flip_relay.get("review_thread") ==
            "PRRT_kwDOS1ExJc6dYPJO" and
            post_flip_relay.get("consumer_count") == 6 and
            post_flip_relay.get("expected_selection") ==
            "explicit_mir_to_c" and
            post_flip_relay.get("required_before") ==
            "patch22_8_stability_authority_publication",
            "post-flip review relay authority drifted")
    require(len(relay_rows) == 0 and
            relay.get("consumer_count") == 15 and
            relay.get("authorized_post_relay_consumer_count") == 0,
            "cross-lane relay transition count drifted")
    require(sorted({str(row["path"]) for row in stdlib_rows
                    if not str(row["path"]).startswith("tests/")}) ==
            sorted(relay.get("paths", [])),
            "cross-lane relay path set drifted")
    # Physical line numbers move whenever an unrelated guard recipe is added.
    # The frozen manifest records the stable source, owning recipe, and compiler
    # token; the selection assertion below retains its exact C-route invariant.
    site_fields = ("path", "recipe", "compiler_token")
    site_manifest = relay.get("authorized_site_manifest", [])
    live_site_rows: dict[tuple[object, ...], list[dict[str, object]]] = {}
    for row in stdlib_rows:
        key = tuple(row[field] for field in site_fields)
        live_site_rows.setdefault(key, []).append(row)
    expected_sites = {
        tuple(row[field] for field in site_fields)
        for row in site_manifest
    }
    require(len(site_manifest) == 15 and expected_sites.issubset(live_site_rows),
            "cross-lane relay site manifest drifted")
    require(all(any(row["selection"] == "explicit_c"
                    for row in live_site_rows[site])
                for site in expected_sites),
            "an authorized relay site did not make the exact route transition")
    pending_site_fields = site_fields + ("command",)
    pending_sites = {
        tuple(row[field] for field in pending_site_fields)
        for row in post_flip_relay.get("site_manifest", [])
    }
    live_pending_sites = {
        tuple(row[field] for field in pending_site_fields): row
        for row in stdlib_rows
        if tuple(row[field] for field in pending_site_fields) in pending_sites
    }
    require(len(pending_sites) == 6 and
            pending_sites == set(live_pending_sites) and
            sorted({str(row["path"]) for row in live_pending_sites.values()}) ==
            post_flip_relay.get("paths") and
            all(row["selection"] == "explicit_c"
                for row in live_pending_sites.values()),
            "post-flip review relay site manifest drifted")
    require(relay_transition_state == "landed_post_relay" and
            transition == post_flip_relay.get("landed_authority") and
            post_flip_relay.get("landed_merge_evidence") == {
                "status": "merged_on_main",
                "owning_pull_request": 264,
                "base_sha": "5638c3596be450b75f2af905b982875f7863bc37",
                "exact_head_sha": "3ada756e209bfa0556895169870ae00f96d94022",
                "merged_main_sha": "a7adbcd186512a3b4fd99b953bb2bc30f6838c52",
                "pull_request_event": "pull_request",
                "successful_workflows": 6,
                "total_workflows": 6,
                "unfinished_workflows": 0,
                "non_success_workflows": 0,
                "unresolved_review_threads": 0,
                "relayed_review_thread": "PRRT_kwDOS1ExJc6dYPJO",
                "relayed_review_thread_status": "resolved_non_outdated",
            },
            "six-site landed authority or merge-evidence state drifted")
    require(relay.get("status") == "merged_on_main" and
            relay.get("owner") == "stdlib" and
            relay.get("pull_request") == 256 and
            relay.get("exact_head_sha") ==
            "884cb57aee466da24410ade1a9bc7ddc9e592dd7" and
            relay.get("merged_main_sha") ==
            "8045704ca5632e3ad096d1cd25eac12c57a4b28b" and
            relay.get("pull_request_success_count") == 73 and
            relay.get("unresolved_review_thread_count") == 0 and
            relay.get("expected_selection") == "explicit_mir_to_c" and
            relay.get("evidence") ==
            "owning_pr_exact_head_complete_pull_request_population",
            "cross-lane relay status drifted")
    pre_selections = pre_relay_inventory["selection_counts"]
    post_selections = post_relay_inventory["selection_counts"]
    pre_classes = pre_relay_inventory["consumer_class_counts"]
    post_classes = post_relay_inventory["consumer_class_counts"]
    require(post_relay_inventory["total"] == pre_relay_inventory["total"] and
            post_relay_inventory["owner_counts"] ==
            pre_relay_inventory["owner_counts"] and
            post_relay_inventory["unclassified_count"] ==
            pre_relay_inventory["unclassified_count"] == 0 and
            post_selections["explicit_c"] - pre_selections["explicit_c"] ==
            relay["consumer_count"] and
            pre_selections["implicit_default"] -
            post_selections["implicit_default"] == relay["consumer_count"] and
            post_selections["explicit_cranelift"] ==
            pre_selections["explicit_cranelift"] and
            post_selections["explicit_invalid_or_parser_probe"] ==
            pre_selections["explicit_invalid_or_parser_probe"] and
            post_classes["already_explicit_or_parser_probe"] -
            pre_classes["already_explicit_or_parser_probe"] ==
            relay["consumer_count"] and
            "stdlib_owned_C_or_diagnostic_guard" not in post_classes,
            "authorized post-relay inventory is not the exact 15-site delta")
    owner_selections = relay.get("authorized_post_relay_owner_selections", {})
    initial_stdlib_rows = [
        row for row in stdlib_rows
        if tuple(row[field] for field in pending_site_fields) not in pending_sites
    ]
    require(len(initial_stdlib_rows) == 23 and
            sum(row["selection"] == "explicit_c" for row in initial_stdlib_rows) ==
            owner_selections.get("explicit_c") == 20 and
            sum(row["selection"] == "explicit_cranelift"
                for row in initial_stdlib_rows) ==
            owner_selections.get("explicit_cranelift") == 3,
            "merged post-relay Stdlib selection set drifted")

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
    require("- [x] Patch 22.2 — Explicit C Route and No-op Consumer Migration — DONE"
            in task,
            "TASK.md does not record Patch 22.2 completion")
    require("- [x] Patch 22.2a — Cross-Lane Explicit-C Relay Publication Authority — DONE"
            in task,
            "TASK.md does not record the relay-publication authority correction")
    require("- [x] Patch 22.2b — Post-Relay Prerequisite Reconciliation — DONE"
            in task and
            "- [x] Patch 22.6 — Cranelift Default Route Flip — DONE" in task,
            "TASK.md does not preserve the post-relay/default-flip boundary")
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
    for path_filter in ("'reset-heavy-guards-workflow.sh'", "'tests/*.gst'",
                        "'justfile*'"):
        require(workflow.count(path_filter) == 2,
                f"dedicated workflow does not own both path filters for {path_filter}")
    boundary = record.get("boundary", {})
    require(boundary and all(value is False for value in boundary.values()),
            "Patch 22.2 widened beyond the recorded boundary")
    return record, relay_transition_state


def render(record: dict) -> str:
    migration = record["migration"]
    pre_inventory = record["current_invocation_inventory"]
    post_inventory = record["authorized_post_relay_invocation_inventory"]
    relay = record["cross_lane_relay"]
    post_flip_relay = relay["post_flip_review_relay"]
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
        f"- Pre-relay implicit consumers: `{pre_inventory['selection_counts']['implicit_default']}`",
        f"- Merged post-relay implicit consumers: `{migration['authorized_post_relay_implicit_count']}`",
        f"- Pre-relay explicit C consumers: `{pre_inventory['selection_counts']['explicit_c']}`",
        f"- Merged post-relay explicit C consumers: `{post_inventory['selection_counts']['explicit_c']}`",
        f"- Pre-relay implicit Stdlib-owned consumers: `{relay['consumer_count']}`",
        f"- Merged post-relay implicit Stdlib-owned consumers: `{relay['authorized_post_relay_consumer_count']}`",
        f"- Relay status: `{relay['status']}`",
        f"- Relay PR: `#{relay['pull_request']}` at `{relay['exact_head_sha']}`",
        f"- Relay merged main: `{relay['merged_main_sha']}`",
        f"- Relay PR workflows: `{relay['pull_request_success_count']}` successful",
        f"- Relay unresolved review threads: `{relay['unresolved_review_thread_count']}`",
        "",
        "## Migration classes",
        "",
        f"- Bootstrap/final compiler C generation: `{migration['bootstrap_migrated_count']}`",
        f"- Repository guards: `{migration['repository_guard_migrated_count']}`",
        f"- Script guards: `{migration['script_guard_migrated_count']}`",
        f"- Developer C pipeline: `{migration['developer_pipeline_migrated_count']}`",
        "",
        "## Pre-relay preserved implicit consumers",
        "",
    ]
    for key, value in record["pre_relay_preserved_implicit_classes"].items():
        lines.append(f"- `{key}`: `{value}`")
    lines += [
        "", "## Merged post-relay preserved implicit consumers", "",
    ]
    for key, value in record[
            "authorized_post_relay_preserved_implicit_classes"].items():
        lines.append(f"- `{key}`: `{value}`")
    lines += [
        "", "## Cross-lane relay", "",
        "| Path | Line | Recipe | Compiler |",
        "| --- | ---: | --- | --- |",
    ]
    for row in relay["authorized_site_manifest"]:
        lines.append(
            f"| `{row['path']}` | {row['line']} | `{row['recipe']}` | "
            f"`{row['compiler_token']}` |"
        )
    lines += [
        "",
        "## Post-flip review relay",
        "",
        f"- Status: `{post_flip_relay['status']}`",
        f"- Review: `#{post_flip_relay['review_pull_request']}` / `{post_flip_relay['review_thread']}`",
        f"- Landed owning PR: `#{post_flip_relay['landed_authority']['owning_pull_request']}`",
        f"- Landed exact head: `{post_flip_relay['landed_merge_evidence']['exact_head_sha']}`",
        f"- Landed merge main: `{post_flip_relay['landed_merge_evidence']['merged_main_sha']}`",
        f"- Landed PR workflows: `{post_flip_relay['landed_merge_evidence']['successful_workflows']}/{post_flip_relay['landed_merge_evidence']['total_workflows']}` successful",
        f"- Relayed review thread: `{post_flip_relay['landed_merge_evidence']['relayed_review_thread_status']}`",
        f"- Required owning transitions: `{post_flip_relay['consumer_count']}`",
        f"- Expected selection: `{post_flip_relay['expected_selection']}`",
    ]
    for row in post_flip_relay["site_manifest"]:
        lines.append(
            f"- `{row['path']}:{row['line']}` — `{row['command']}`"
        )
    lines += [
        "",
        "Patch 22.2's original relay is complete. The owning Stdlib relay merged with its complete",
        "exact-head pull-request population successful and zero review threads.",
        "This authority now accepts only the exact merged 15-site post-relay",
        "inventory plus the six test-owned consumers discovered by post-merge",
        "review. The completed transition now admits only the exact landed",
        "two-path/six-site post-relay manifest; the former pre-relay state,",
        "partial, extra-site, path-drift, same-count substitution, and unrelated",
        "inventory states reject. Exact PR evidence is recorded separately from",
        "the semantic inventory contract. This correction does not edit Stdlib.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review"))
    args = parser.parse_args()
    record, relay_transition_state = validate()
    expected = render(record)
    if args.command == "project":
        REVIEW.write_text(expected, encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and REVIEW.read_text(encoding="utf-8") == expected,
                "generated migration review is stale; run project")
    else:
        print(
            f"{GUARD_L1}: ok (60 migrated, relay state={relay_transition_state})"
        )


if __name__ == "__main__":
    main()
