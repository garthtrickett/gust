#!/usr/bin/env python3
"""Validate and project Patch 20.15 long-lived/concurrent qualification."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_LONG_LIVED_CONCURRENT.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
HISTORICAL = ROOT / ".github/workflows/cranelift-historical-full.yml"
JUSTFILE = ROOT / "justfile"
GUARD_L1 = "guard-cranelift-phase20-long-lived-concurrent-contract"
GUARD_L2 = "guard-cranelift-phase20-long-lived-concurrent-smoke"
GUARD_L3 = "guard-cranelift-phase20-long-lived-concurrent-full"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase20_long_lived_concurrent")
    require(isinstance(record, dict), "Patch 20.15 authority is missing")
    expected = {
        "contract_version": "phase20_long_lived_concurrent_v1",
        "status": "patch20_15_complete",
        "next_patch": "20.16",
        "review_view": "compiler/CRANELIFT_PHASE20_LONG_LIVED_CONCURRENT.md",
        "harness": "scripts/phase20_long_lived_concurrent.sh",
        "runtime_source_fixture": "compiler/phase20_long_lived_concurrent_source.gst",
        "runtime_probe_fixture": "compiler/fixtures/phase20_long_lived_concurrent_probe.c",
        "canonical_mir_fixture": "compiler/fixtures/native_backend_phase20_long_lived_concurrent.mir",
        "resource_source_fixture": "compiler/phase20_long_lived_resource_source.gst",
        "resource_module_fixture": "compiler/phase20_resource_scope_cleanup_module.gst",
        "resource_policy": "sixteen_in_process_cycles_each_destroy_nested_fields_in_reverse_order_transfer_one_manual_terminal_owner_and_destroy_the_outer_owner_exactly_once",
        "concurrency_policy": "two_pthreads_share_one_runtime_mutex_and_one_bounded_channel_producer_is_joined_after_deterministic_receive_count_and_sum_invariants",
        "allocation_policy": "one_mutex_and_one_channel_are_reused_for_the_bounded_process_lifetime_and_reclaimed_with_the_test_process",
        "backend_policy": "MIR_to_C_source_and_direct_canonical_MIR_Cranelift_call_the_same_test_only_probe_and_link_the_same_production_runtime_without_fallback",
        "normalization_policy": "none",
        "od13_policy": "open_and_unchanged_not_part_of_patch20_15",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")
    require(record.get("profiles") == [
        {"id": "small", "level": 2, "concurrent_cycles": 8,
         "resource_process_runs": 1},
        {"id": "full", "level": 3, "concurrent_cycles": 128,
         "resource_process_runs": 4},
    ], "Patch 20.15 profiles drifted")
    exclusions = record.get("explicit_exclusions")
    require(isinstance(exclusions, list) and len(exclusions) == 2,
            "Patch 20.15 must retain two direct-source exclusions")
    require({row.get("id") for row in exclusions} == {
        "direct_resource_source_to_cranelift",
        "direct_threading_source_to_cranelift",
    }, "Patch 20.15 exclusion identities drifted")
    for row in exclusions:
        require(row.get("owner") == "phase13_generic_source_to_mir" and
                row.get("destination") == "20.16" and
                row.get("reason_code") in {
                    "source_or_type_failure",
                    "deferred_p13_parameter_argument_target_dependent_abi",
                } and row.get("falsifier"),
                f"invalid Patch 20.15 exclusion: {row}")

    for key in ("runtime_source_fixture", "runtime_probe_fixture",
                "canonical_mir_fixture", "resource_source_fixture",
                "resource_module_fixture"):
        require((ROOT / record[key]).is_file(), f"missing {key}")
    require("- [x] Patch 20.15 — Long-Lived and Concurrent Resource "
            "Differential — DONE" in TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 20.15 DONE")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2 and
            levels.get(GUARD_L3) == 3, "Patch 20.15 guard levels drifted")
    require(levels.get("guard-cranelift-phase20-resource-scope-cleanup-parity")
            == 2, "shared cleanup-plan parity is not a registered Level 2 owner")
    pr_fast = PR_FAST.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in pr_fast and f"just {GUARD_L2}" in pr_fast and
            f"just {GUARD_L3}" not in pr_fast,
            "PR Fast Patch 20.15 ownership drifted")
    historical = HISTORICAL.read_text(encoding="utf-8")
    require(f"just {GUARD_L3}" in historical,
            "Historical Full does not own Patch 20.15 Level 3")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(all(f"{guard}:" in justfile for guard in
                (GUARD_L1, GUARD_L2, GUARD_L3)),
            "Patch 20.15 just guards are missing")
    return record


def render(record: dict) -> str:
    lines = [
        "# Cranelift Phase 20 Long-Lived and Concurrent Resources",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_long_lived_concurrent.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Normalization: `{record['normalization_policy']}`",
        f"- OD-13: `{record['od13_policy']}`",
        "",
        "## Selected profiles",
        "",
        "| Profile | Level | Concurrent cycles | Resource process runs |",
        "| --- | ---: | ---: | ---: |",
    ]
    for row in record["profiles"]:
        lines.append(f"| `{row['id']}` | {row['level']} | "
                     f"{row['concurrent_cycles']} | "
                     f"{row['resource_process_runs']} |")
    lines += [
        "",
        "## Observable contract",
        "",
        f"- Resource lifecycle: {record['resource_policy']}",
        f"- Concurrency: {record['concurrency_policy']}",
        f"- Allocation: {record['allocation_policy']}",
        f"- Backend route: {record['backend_policy']}",
        "",
        "The production runtime is unchanged. A test-only imported probe runs",
        "real Mutex lock/unlock and bounded Channel send/receive operations.",
        "MIR-to-C source and direct canonical-MIR Cranelift executions must have",
        "the same exit status and exact stdout/stderr. The resource oracle runs",
        "real source-declared cleanup and composes the existing shared compiler",
        "cleanup-plan parity through its separately registered Level 2 owner;",
        "direct source routes remain explicit exclusions.",
        "",
        "## Explicit exclusions",
        "",
    ]
    for row in record["explicit_exclusions"]:
        lines.append(f"- `{row['id']}` — `{row['reason_code']}`; owner "
                     f"`{row['owner']}`; destination `{row['destination']}`; "
                     f"falsifier: {row['falsifier']}")
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review"))
    args = parser.parse_args()
    record = validate()
    if args.command == "project":
        REVIEW.write_text(render(record), encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and
                REVIEW.read_text(encoding="utf-8") == render(record),
                "generated review is stale; run project")
    print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
