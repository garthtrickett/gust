#!/usr/bin/env python3
"""Validate and project Patch 21.6 cross-tenant capability authority."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE21_CROSS_TENANT_CAPABILITY.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase21-cross-tenant-capability.yml"
JUSTFILE = ROOT / "justfile"
GUARD_L1 = "guard-cranelift-phase21-cross-tenant-capability-contract"
GUARD_L2 = "guard-cranelift-phase21-cross-tenant-capability-evidence"
POSITIVE_KINDS = ["direct_cross_tenant_capability",
                  "ordinary_scoped_query_unchanged"]
NEGATIVE_KINDS = ["forged_value", "ordinary_helper", "reexport",
                  "nested_nontransitive", "outside_marker",
                  "reserved_redefinition", "wrong_arity"]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    predecessor = registry.get("phase21_per_root_obligations", {})
    require(predecessor.get("status") == "patch21_5_complete" and
            predecessor.get("next_patch") == "21.6",
            "Patch 21.5 predecessor authority drifted")
    record = registry.get("phase21_cross_tenant_capability")
    require(isinstance(record, dict), "Patch 21.6 authority is missing")
    require(record.get("contract_version") ==
            "phase21_cross_tenant_capability_v1", "contract version drifted")
    require(record.get("status") == "patch21_6_complete" and
            record.get("next_patch") == "21.7", "status or successor drifted")
    require(record.get("marker_syntax") ==
            "cross_tenant capability_expression", "marker syntax drifted")
    require(record.get("trusted_host_intrinsic") ==
            "cross_tenant_capability_from_host", "host intrinsic drifted")
    require(record.get("capability_type") == "CrossTenantCapability",
            "capability type drifted")
    require(record.get("capability_policy") ==
            "reserved_compile_time_only_host_capability_recognized_only_as_the_direct_cross_tenant_expression_at_the_owning_query",
            "capability policy drifted")
    require(record.get("local_bypass_policy") ==
            "a_valid_marker_bypasses_only_the_current_query_local_scope_obligations_and_every_nested_query_requires_its_own_marker_or_trusted_scope_provenance",
            "local bypass policy drifted")
    require(record.get("nontransitive_policy") ==
            "ordinary_values_variables_helpers_returns_reexports_and_outer_query_markers_never_carry_cross_tenant_authority",
            "non-transitive policy drifted")
    require(record.get("diagnostic_class") == "CrossTenantCapability" and
            record.get("diagnostic") ==
            "error: cross_tenant requires a direct compiler-owned host capability at this query",
            "query diagnostic drifted")
    require(record.get("boundary_diagnostic_class") ==
            "CrossTenantCapabilityBoundary", "boundary diagnostic drifted")

    positives = record.get("positive_fixtures", [])
    negatives = record.get("negative_fixtures", [])
    require([row.get("kind") for row in positives] == POSITIVE_KINDS,
            "positive fixture population drifted")
    require([row.get("kind") for row in negatives] == NEGATIVE_KINDS,
            "negative fixture population drifted")
    for row in [*positives, *negatives]:
        require((ROOT / row["source_fixture"]).is_file(),
                f"missing Patch 21.6 fixture: {row['source_fixture']}")

    typechecker = read("compiler/typechecker.gst")
    for spelling in (
        "typechecker_make_cross_tenant_capability_type",
        "typechecker_query_cross_tenant_capability_state",
        "cross_tenant_capability_from_host",
        "cross_tenant_state_phase21_6 == 0",
        "CrossTenantCapabilityBoundary",
        "is_compile_time_only = 1",
    ):
        require(spelling in typechecker,
                f"cross-tenant implementation is missing: {spelling}")
    require("raw_sql" not in typechecker.lower(),
            "raw SQL was folded into typed-query enforcement")

    boundary = record.get("boundary", {})
    for field in ("cross_tenant_capability_enforced",
                  "capability_is_nonforgeable", "capability_is_nontransitive",
                  "marker_is_visible_at_query_site"):
        require(boundary.get(field) is True, f"missing authority: {field}")
    for field in ("ordinary_scoped_queries_changed",
                  "raw_SQL_included_in_typed_query_guarantee",
                  "adds_database_runtime", "adds_broader_effect_system",
                  "trusted_host_capability_establishment_claimed",
                  "adds_or_changes_MIR_operations",
                  "changes_ABI_layout_or_runtime_symbols",
                  "changes_bootstrap_seed", "edits_stdlib"):
        require(boundary.get(field) is False,
                f"Patch 21.6 widened boundary: {field}")
    require("- [x] Patch 21.6 — Explicit Cross-Tenant Capability Boundary — DONE"
            in TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 21.6 DONE")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 21.6 guard levels drifted")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in justfile and f"{GUARD_L2}:" in justfile,
            "Patch 21.6 just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own Patch 21.6 Level 1")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow,
            "dedicated Patch 21.6 workflow does not own both guards")
    return record


def render(record: dict) -> str:
    lines = [
        "# Cranelift Phase 21 Cross-Tenant Capability Boundary", "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase21_cross_tenant_capability.py project`. Do not edit by hand.",
        "", f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`", f"- Next patch: `{record['next_patch']}`",
        f"- Marker: `{record['marker_syntax']}`",
        f"- Host boundary: `{record['trusted_host_intrinsic']}`",
        f"- Diagnostic: `{record['diagnostic_class']}` — `{record['diagnostic']}`",
        "", "A deliberate cross-tenant query must spell the marker at that query",
        "and directly invoke the reserved compile-time host capability. The marker",
        "bypasses only that query's local scoped-root obligations. It cannot flow",
        "through values, variables, helpers, returns, re-exports, or an outer query.",
        "", "## Positive evidence", "",
    ]
    for row in record["positive_fixtures"]:
        lines.append(
            f"- `{row['kind']}` — `{row['source_fixture']}` — MIR-to-C exit "
            f"`{row['mir_to_c_exit']}`, Cranelift exit `{row['cranelift_exit']}`"
        )
    lines += ["", "## Rejection evidence", ""]
    for row in record["negative_fixtures"]:
        lines.append(
            f"- `{row['kind']}` — `{row['source_fixture']}` — "
            f"`{row['diagnostic_class']}`"
        )
    lines += ["", "Privileged raw SQL remains a separate explicit unsafe boundary",
              "outside the compiler-owned typed-query guarantee. This patch adds no",
              "database runtime, broader effect system, MIR operation, ABI/layout,",
              "runtime symbol, bootstrap seed, or Stdlib change. Establishment of",
              "the trusted host capability remains outside the compiler claim.", ""]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review",
                                             "positive-cases", "negative-cases"))
    args = parser.parse_args()
    record = validate()
    if args.command == "project":
        REVIEW.write_text(render(record), encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.read_text(encoding="utf-8") == render(record),
                "generated Patch 21.6 review is stale; run project")
    elif args.command == "positive-cases":
        for row in record["positive_fixtures"]:
            print("\t".join((row["kind"], row["source_fixture"],
                              str(row["mir_to_c_exit"]),
                              str(row["cranelift_exit"]))))
        return
    elif args.command == "negative-cases":
        for row in record["negative_fixtures"]:
            print("\t".join((row["kind"], row["source_fixture"],
                              row["diagnostic_class"])))
        return
    print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
