#!/usr/bin/env python3
"""Validate and project Patch 21.5 per-root query obligations."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE21_PER_ROOT_OBLIGATIONS.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase21-per-root-obligations.yml"
JUSTFILE = ROOT / "justfile"
GUARD_L1 = "guard-cranelift-phase21-per-root-obligations-contract"
GUARD_L2 = "guard-cranelift-phase21-per-root-obligations-evidence"
POSITIVE_KINDS = ["scoped_joins_and_nested", "unscoped_join",
                  "nested_aggregate_shape", "branch_return_alias_flow"]
NEGATIVE_KINDS = ["join_missing", "sibling_discharge", "nested_missing",
                  "query_value_unresolved", "branch_unresolved"]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    predecessor = registry.get("phase21_trusted_scope_provenance", {})
    require(predecessor.get("status") == "patch21_4_complete" and
            predecessor.get("next_patch") == "21.5",
            "Patch 21.4 predecessor authority drifted")
    record = registry.get("phase21_per_root_obligations")
    require(isinstance(record, dict), "Patch 21.5 authority is missing")
    require(record.get("contract_version") ==
            "phase21_per_root_obligations_v1", "contract version drifted")
    require(record.get("status") == "patch21_5_complete" and
            record.get("next_patch") == "21.6", "status or successor drifted")
    require(record.get("obligation_carrier") == [
        "QueryScopeObligation.entity_identity",
        "QueryScopeObligation.binding_identity",
        "QueryScopeObligation.scope_identity",
        "QueryScopeObligation.root_kind",
        "QueryScopeObligation.source_order",
        "QueryScopeObligation.discharged",
    ], "obligation carrier drifted")
    require(record.get("deterministic_order") ==
            "primary_roots_in_source_order_then_join_roots_in_source_order_with_nested_queries_checked_recursively_in_source_order",
            "obligation ordering drifted")
    require(record.get("join_policy") ==
            "each_scoped_join_root_owns_an_independent_obligation_discharged_only_by_its_own_join_predicate_unscoped_joins_create_none",
            "join-root policy drifted")
    require(record.get("nested_policy") ==
            "every_nested_query_is_a_fresh_obligation_boundary_outer_sibling_and_earlier_discharge_never_clear_it",
            "nested-query policy drifted")
    require(record.get("query_value_policy") ==
            "every_query_must_discharge_its_complete_local_obligation_set_before_terminal_value_projection_so_unresolved_sets_cannot_flow_through_aliases_returns_branches_or_aggregate_shaped_nested_queries",
            "query-value policy drifted")
    require(record.get("diagnostic_class") == "TenantScopeProvenance" and
            record.get("diagnostic") ==
            "error: query lacks trusted tenant-scope provenance",
            "query-site diagnostic drifted")

    positives = record.get("positive_fixtures", [])
    negatives = record.get("negative_fixtures", [])
    require([row.get("kind") for row in positives] == POSITIVE_KINDS,
            "positive fixture population drifted")
    require([row.get("kind") for row in negatives] == NEGATIVE_KINDS,
            "negative fixture population drifted")
    for row in [*positives, *negatives]:
        require((ROOT / row["source_fixture"]).is_file(),
                f"missing Patch 21.5 fixture: {row['source_fixture']}")

    typechecker = read("compiler/typechecker.gst")
    for spelling in (
        "type QueryScopeObligation", "typechecker_build_query_scope_obligations",
        "root_kind", "source_order", "ctx[expr.Query.joins]",
        "join_phase21_5.predicate", "ctx[expr.Query.nested_queries]",
        "check_expression(nested_expr_idx_phase21_5",
        "query lacks trusted tenant-scope provenance for scoped root",
    ):
        require(spelling in typechecker,
                f"per-root implementation is missing: {spelling}")
    require("cross_tenant_capability" not in
            typechecker[typechecker.index("typechecker_build_query_scope_obligations"):
                        typechecker.index("func check_expression_internal")],
            "Patch 21.5 widened into cross-tenant capability enforcement")

    boundary = record.get("boundary", {})
    for field in ("primary_scoped_roots_enforced", "join_roots_enforced",
                  "nested_queries_enforced"):
        require(boundary.get(field) is True, f"missing enforcement: {field}")
    for field in ("unscoped_joins_create_obligations",
                  "partial_query_obligation_sets_flow_as_values",
                  "cross_tenant_capability_enforced",
                  "trusted_request_context_establishment_claimed",
                  "adds_or_changes_MIR_operations",
                  "changes_ABI_layout_or_runtime_symbols",
                  "changes_bootstrap_seed", "edits_stdlib"):
        require(boundary.get(field) is False,
                f"Patch 21.5 widened boundary: {field}")
    require("- [x] Patch 21.5 — Per-Root Join and Nested-Query Obligations — DONE"
            in TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 21.5 DONE")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 21.5 guard levels drifted")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in justfile and f"{GUARD_L2}:" in justfile,
            "Patch 21.5 just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own Patch 21.5 Level 1")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow,
            "dedicated Patch 21.5 workflow does not own both guards")
    return record


def render(record: dict) -> str:
    lines = [
        "# Cranelift Phase 21 Per-Root Query Obligations", "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase21_per_root_obligations.py project`. Do not edit by hand.",
        "", f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`", f"- Next patch: `{record['next_patch']}`",
        f"- Diagnostic: `{record['diagnostic_class']}` — `{record['diagnostic']}`",
        "", "Every scoped primary or joined root owns a distinct obligation in",
        "deterministic source order. A join can be discharged only by its own",
        "predicate. Every nested query is checked as a fresh boundary, so outer,",
        "sibling, or earlier evidence cannot clear it.", "",
        "Query values use conservative projection: the complete local obligation",
        "set must be discharged before the terminal becomes an ordinary value.",
        "Therefore unresolved sets cannot be laundered through aliases, returns,",
        "branches, or aggregate-shaped nested queries.", "", "## Positive evidence", "",
    ]
    for row in record["positive_fixtures"]:
        backends = f"MIR-to-C exit `{row['mir_to_c_exit']}`"
        if "cranelift_exit" in row:
            backends += f", Cranelift exit `{row['cranelift_exit']}`"
        lines.append(f"- `{row['kind']}` — `{row['source_fixture']}` — {backends}")
    lines += ["", "## Rejection evidence", ""]
    for row in record["negative_fixtures"]:
        lines.append(
            f"- `{row['kind']}` — `{row['source_fixture']}` — "
            f"`{row['root_kind']}` binding `{row['binding']}` rejected at its query"
        )
    lines += ["", "Unscoped joins create no obligation. Cross-tenant capability",
              "enforcement remains Patch 21.6. Trusted-context establishment, raw",
              "SQL, MIR operations, ABI/layout, runtime symbols, and Stdlib remain",
              "outside this patch.", ""]
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
                "generated Patch 21.5 review is stale; run project")
    elif args.command == "positive-cases":
        for row in record["positive_fixtures"]:
            print("\t".join((row["kind"], row["source_fixture"],
                              str(row["mir_to_c_exit"]),
                              str(row.get("cranelift_exit", "-")))))
        return
    elif args.command == "negative-cases":
        for row in record["negative_fixtures"]:
            print("\t".join((row["kind"], row["source_fixture"],
                              row["root_kind"], row["binding"])))
        return
    print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
