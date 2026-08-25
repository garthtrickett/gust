#!/usr/bin/env python3
"""Validate and project Patch 21.2 inert scoped-query semantic records."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE21_INERT_SCOPED_QUERY_RECORDS.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase21-inert-scoped-query-records.yml"
JUSTFILE = ROOT / "justfile"
GUARD_L1 = "guard-cranelift-phase21-inert-scoped-query-records-contract"
GUARD_L2 = "guard-cranelift-phase21-inert-scoped-query-records-evidence"

RECORD_FAMILIES = [
    "ScopedEntityDeclaration",
    "CanonicalQueryRoot",
    "PerRootScopeObligation",
    "PredicateProvenance",
    "NestedQueryIdentity",
    "CrossTenantMarker",
    "TrustedScopeOrigin",
]

PRIVATE_CONSTRUCTORS = [
    "make_scoped_entity_declaration",
    "make_canonical_query_root",
    "make_per_root_scope_obligation",
    "make_predicate_provenance",
    "make_nested_query_identity",
    "make_cross_tenant_marker",
    "make_trusted_scope_origin",
    "make_empty_inert_scoped_query_semantic_records",
]

NORMAL_COMPILER_SURFACES = [
    "compiler/lexer.gst",
    "compiler/parser.gst",
    "compiler/ast.gst",
    "compiler/typechecker.gst",
    "compiler/mir.gst",
    "compiler/codegen.gst",
    "compiler/test_runner_entry.gst",
    "compiler/test_runner_bootstrap_bridge_entry.gst",
]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase21_inert_scoped_query_records")
    require(isinstance(record, dict), "Patch 21.2 authority is missing")
    require(record.get("contract_version") ==
            "phase21_inert_scoped_query_semantic_records_v1",
            "contract version drifted")
    require(record.get("status") == "patch21_2_complete" and
            record.get("next_patch") == "21.3",
            "status or successor drifted")
    require(record.get("record_families") == RECORD_FAMILIES,
            "semantic record family population drifted")
    require(record.get("construction_policy") ==
            "all_records_opaque_all_constructors_private_no_record_value_leaves_the_module",
            "record construction policy drifted")
    require(record.get("reachability_policy") ==
            "module_absent_from_parser_typechecker_codegen_MIR_and_normal_compiler_entrypoints",
            "normal-path reachability policy drifted")
    require(record.get("trusted_scope_origin_policy") ==
            "identity_only_inert_record_no_public_constructor_no_source_value_provenance",
            "trusted Scope origin policy drifted")
    require(record.get("per_root_policy") ==
            "each_canonical_root_has_a_distinct_recorded_obligation_identity_without_enforcement",
            "per-root inert obligation policy drifted")

    for field in (
        "module", "self_hosted_round_trip_fixture",
        "ordinary_construction_forge_fixture",
        "private_constructor_forge_fixture",
    ):
        require((ROOT / record[field]).is_file(),
                f"missing Patch 21.2 file: {record[field]}")
    require(record.get("review_view") ==
            "compiler/CRANELIFT_PHASE21_INERT_SCOPED_QUERY_RECORDS.md",
            "generated review path drifted")

    module = (ROOT / record["module"]).read_text(encoding="utf-8")
    for family in RECORD_FAMILIES:
        require(f"#[opaque]\ntype {family}[ctx] struct" in module,
                f"record is not opaque and branded: {family}")
    require("#[opaque]\ntype InertScopedQuerySemanticRecords[ctx] struct" in module,
            "inert semantic record table is not opaque")
    for constructor in PRIVATE_CONSTRUCTORS:
        require(f"#[private]\nfunc {constructor}(" in module,
                f"constructor is not private: {constructor}")
    require("func phase21_inert_scoped_query_records_round_trip(" in module,
            "self-hosted round-trip hook is missing")
    require("recorded_not_enforced" in module,
            "inert obligation state is missing")

    module_name = Path(record["module"]).name
    for surface in NORMAL_COMPILER_SURFACES:
        source = (ROOT / surface).read_text(encoding="utf-8")
        require(module_name not in source,
                f"inert records became reachable from {surface}")

    round_trip = (ROOT / record["self_hosted_round_trip_fixture"]).read_text(
        encoding="utf-8")
    require("phase21_inert_scoped_query_records_round_trip" in round_trip and
            "SUCCESS: Phase 21 inert scoped-query semantic records round-tripped" in round_trip,
            "self-hosted round-trip fixture drifted")
    ordinary_forge = (ROOT / record[
        "ordinary_construction_forge_fixture"]).read_text(encoding="utf-8")
    require("empty[query_records.TrustedScopeOrigin[ctx]]" in ordinary_forge,
            "ordinary-construction forge witness drifted")
    private_forge = (ROOT / record[
        "private_constructor_forge_fixture"]).read_text(encoding="utf-8")
    require("query_records.make_trusted_scope_origin(" in private_forge and
            "user-controlled" in private_forge,
            "private-constructor forge witness drifted")

    deltas = record.get("semantic_delta_witnesses")
    require(isinstance(deltas, list) and len(deltas) == 3,
            "semantic-delta baseline population drifted")
    require([row.get("kind") for row in deltas] == [
        "generated_c_golden_and_runtime_observation",
        "generated_c_golden_and_runtime_observation",
        "unchanged_source_and_exact_diagnostic",
    ], "semantic-delta baseline kinds drifted")
    for row in deltas:
        require((ROOT / row["source_fixture"]).is_file(),
                f"semantic-delta fixture is missing: {row['source_fixture']}")
        require(row.get("compile_exit") in {0, 1},
                f"semantic-delta row is incomplete: {row['source_fixture']}")
    require([row.get("runtime_exit") for row in deltas[:2]] == [21, 99],
            "query-shaped runtime observations drifted")
    for row in deltas[:2]:
        require((ROOT / row["generated_c_golden"]).is_file(),
                f"generated-C golden is missing: {row['generated_c_golden']}")
    require(deltas[2].get("diagnostic_class") == "OpaqueConstruction" and
            deltas[2].get("diagnostic") ==
            "Opaque type 'phase20_resource_enforcement_module__Handle' can be constructed only inside its defining module",
            "existing diagnostic observation drifted")

    boundary = record.get("boundary", {})
    require(boundary and all(value is False for value in boundary.values()),
            "Patch 21.2 widened beyond inert records")
    require("- [x] Patch 21.2 — Inert Scoped-Query Semantic Records — DONE" in
            TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 21.2 DONE")

    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 21.2 guard levels drifted")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in justfile and f"{GUARD_L2}:" in justfile,
            "Patch 21.2 just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Level 1 Patch 21.2 contract")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow,
            "dedicated Patch 21.2 workflow does not own both guards")
    return record


def render(record: dict) -> str:
    lines = [
        "# Cranelift Phase 21 Inert Scoped-Query Semantic Records",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase21_inert_scoped_query_records.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Module: `{record['module']}`",
        "- Enforcement enabled: `false`",
        "- Reachable from normal source typechecking/lowering: `false`",
        "",
        "## Opaque record families",
        "",
    ]
    for family in record["record_families"]:
        lines.append(f"- `{family}`")
    lines += [
        "",
        "Every family is branded and opaque. Every constructor is private, and",
        "the focused self-hosted hook returns only pass/fail, so no ordinary",
        "source program can construct or obtain a trusted Scope-origin record.",
        "The module is absent from parser, typechecker, MIR, codegen, and normal",
        "compiler entrypoints.",
        "",
        "## Preserved semantic baseline",
        "",
    ]
    for row in record["semantic_delta_witnesses"]:
        lines += [
            f"- `{row['source_fixture']}` — `{row['kind']}`",
        ]
        if row["kind"] == "generated_c_golden_and_runtime_observation":
            lines += [
                f"  - Generated-C golden: `{row['generated_c_golden']}`",
                f"  - Compile exit: `{row['compile_exit']}`",
                f"  - Runtime exit: `{row['runtime_exit']}`",
            ]
        else:
            lines += [
                f"  - Compile exit: `{row['compile_exit']}`",
                f"  - Diagnostic class: `{row['diagnostic_class']}`",
                f"  - Diagnostic: `{row['diagnostic']}`",
            ]
    lines += [
        "",
        "The evidence guard compares both generated-C outputs byte-for-byte with",
        "their exact-main goldens, replays both programs, and checks the exact",
        "existing diagnostic. Patch 21.2 adds",
        "no source syntax, rejection, MIR operation,",
        "backend behavior, ABI/layout rule, runtime symbol, or seed update.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=(
        "validate", "project", "check-review", "semantic-delta-cases",
    ))
    args = parser.parse_args()
    record = validate()
    if args.command == "project":
        REVIEW.write_text(render(record), encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.read_text(encoding="utf-8") == render(record),
                "generated Patch 21.2 review is stale; run project")
    elif args.command == "semantic-delta-cases":
        for row in record["semantic_delta_witnesses"]:
            print("\t".join((
                row["kind"], row["source_fixture"],
                str(row["compile_exit"]),
                str(row.get("runtime_exit", "-")),
                row.get("diagnostic", "-"),
                row.get("generated_c_golden", "-"),
            )))
        return
    print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
