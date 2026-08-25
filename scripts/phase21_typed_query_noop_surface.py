#!/usr/bin/env python3
"""Validate and project Patch 21.3 typed-query no-op surface authority."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE21_TYPED_QUERY_NOOP_SURFACE.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase21-typed-query-noop-surface.yml"
JUSTFILE = ROOT / "justfile"
GUARD_L1 = "guard-cranelift-phase21-typed-query-noop-surface-contract"
GUARD_L2 = "guard-cranelift-phase21-typed-query-noop-surface-evidence"

QUERY_CLAUSES = [
    "root Entity as binding",
    "predicate expression",
    "join Entity as binding predicate expression",
    "nested query expression",
    "cross_tenant capability_expression",
    "terminal expression",
]
AST_CARRIERS = [
    "StructDecl.is_scoped_entity",
    "StructDecl.scope_field",
    "Expression.Query",
    "QueryRoot",
    "QueryJoin",
]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase21_typed_query_noop_surface")
    require(isinstance(record, dict), "Patch 21.3 authority is missing")
    require(record.get("contract_version") ==
            "phase21_typed_query_noop_surface_v1", "contract version drifted")
    require(record.get("status") == "patch21_3_complete" and
            record.get("next_patch") == "21.4", "status or successor drifted")
    require(record.get("declaration_syntax") ==
            "#[scoped(field)] type Entity struct", "declaration syntax drifted")
    require(record.get("query_clauses") == QUERY_CLAUSES,
            "complete query-clause population drifted")
    require(record.get("contextual_keyword_policy") ==
            "query_is_an_ordinary_identifier_unless_immediately_followed_by_a_left_brace",
            "contextual identifier policy drifted")
    require(record.get("ast_carriers") == AST_CARRIERS,
            "AST carrier population drifted")
    require(record.get("evaluation_policy") ==
            "query_clauses_are_inert_and_the_query_value_type_codegen_and_constant_evaluation_delegate_only_to_the_terminal_expression",
            "no-op evaluation policy drifted")
    require(record.get("enforcement_policy") ==
            "no_scope_obligation_is_created_or_discharged_and_no_query_rejection_is_enabled_until_patch21_4",
            "enforcement boundary drifted")

    for field in ("parser_fixture", "complete_surface_fixture", "review_view"):
        require((ROOT / record[field]).is_file() or field == "review_view",
                f"missing Patch 21.3 file: {record[field]}")
    require(record.get("complete_surface_exit") == 37,
            "complete surface runtime observation drifted")

    ast = read("compiler/ast.gst")
    parser = read("compiler/parser.gst")
    typechecker = read("compiler/typechecker.gst")
    codegen = read("compiler/codegen.gst")
    generic = read("compiler/mir_native_backend_generic_source.gst")
    require("is_scoped_entity: int" in ast and "scope_field: str" in ast and
            "Query {" in ast and "type QueryRoot[ctx] struct" in ast and
            "type QueryJoin[ctx] struct" in ast,
            "typed-query AST carriers are incomplete")
    require("func parse_query_expression(" in parser and
            "peek_token_is(p, 13) { // contextual query only before '{'" in parser,
            "query parser is missing or no longer contextual")
    for clause in ("root", "predicate", "join", "nested", "cross_tenant", "terminal"):
        require(f'parser_cur_ident_is(p, "{clause}")' in parser,
                f"query parser is missing clause: {clause}")
    require("stmt_struct_parse.StructDecl.is_scoped_entity = is_scoped_entity_decl" in parser and
            "stmt_struct_parse.StructDecl.scope_field = scoped_entity_field_decl" in parser,
            "scoped declaration metadata is not populated")
    require("return check_expression(expr.Query.terminal" in typechecker and
            "ctx[expr_idx].Query.terminal, env, ctx" in codegen and
            "ctx[expression.Query.terminal], env, ctx" in generic,
            "terminal delegation is incomplete")
    for source in (ast, parser, typechecker, codegen, generic):
        require("query lacks trusted tenant-scope provenance" not in source,
                "Patch 21.4 query rejection was enabled early")

    parser_fixture = read(record["parser_fixture"])
    complete = read(record["complete_surface_fixture"])
    require("mut query := 3; return query;" in parser_fixture and
            "query_expression_phase21_3.tag != 14" in parser_fixture,
            "ordinary query identifier compatibility witness drifted")
    for spelling in ("#[scoped(workspace_id)]", "root ", "predicate ",
                     "join ", "nested query {", "cross_tenant ", "terminal "):
        require(spelling in complete and spelling in parser_fixture,
                f"complete surface fixture is missing: {spelling}")

    witnesses = record.get("migrated_witnesses")
    require(isinstance(witnesses, list) and len(witnesses) == 2,
            "migrated witness population drifted")
    require([row.get("mir_to_c_exit") for row in witnesses] == [21, 99] and
            [row.get("cranelift_exit") for row in witnesses] == [21, 99],
            "migrated witness observations drifted")
    for row in witnesses:
        source = read(row["source_fixture"])
        require("current_surface: compiler_owned_typed_query_syntax_without_scope_enforcement" in source and
                "syntax_authority: patch21_3_contextual_query_and_scoped_entity_surface" in source and
                "return query {" in source,
                f"witness was not migrated under the no-op: {row['source_fixture']}")

    for consumer in record.get("compiler_owned_consumers", []):
        require((ROOT / consumer).is_file(), f"missing compiler consumer: {consumer}")
    require(len(record.get("compiler_owned_consumers", [])) == 5,
            "compiler consumer inventory drifted")
    boundary = record.get("boundary", {})
    require(boundary.get("adds_source_syntax") is True and
            all(value is False for key, value in boundary.items()
                if key != "adds_source_syntax"),
            "Patch 21.3 widened beyond additive no-op syntax")
    require("- [x] Patch 21.3 — Typed-Query Surface Under the No-op — DONE" in
            TASK.read_text(encoding="utf-8"), "TASK.md does not mark Patch 21.3 DONE")

    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 21.3 guard levels drifted")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in justfile and f"{GUARD_L2}:" in justfile,
            "Patch 21.3 just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Level 1 Patch 21.3 contract")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow,
            "dedicated Patch 21.3 workflow does not own both guards")
    return record


def render(record: dict) -> str:
    lines = [
        "# Cranelift Phase 21 Typed-Query No-op Surface",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase21_typed_query_noop_surface.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Scoped declaration: `{record['declaration_syntax']}`",
        f"- Complete surface exit: `{record['complete_surface_exit']}`",
        "- Scope enforcement: `false`",
        "",
        "## Query clauses",
        "",
    ]
    lines += [f"- `{clause}`" for clause in record["query_clauses"]]
    lines += [
        "",
        "`query` remains an ordinary identifier unless immediately followed by",
        "`{`. The AST records every clause, but typechecking, C generation, and",
        "the supported native constant route obtain the query value only from",
        "the terminal expression. No obligation or rejection is active.",
        "",
        "## Migrated executable witnesses",
        "",
    ]
    for row in record["migrated_witnesses"]:
        lines += [
            f"- `{row['source_fixture']}` — MIR-to-C `{row['mir_to_c_exit']}`, Cranelift `{row['cranelift_exit']}`",
        ]
    lines += [
        "",
        "The checked-in bootstrap seed builds the complete parser and compiler",
        "surface. This patch adds syntax only: it adds no MIR operation, backend",
        "observable, ABI/layout rule, runtime symbol, seed update, or Stdlib edit.",
        "Patch 21.4 owns trusted Scope provenance and query-site enforcement.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=(
        "validate", "project", "check-review", "witness-cases",
    ))
    args = parser.parse_args()
    record = validate()
    if args.command == "project":
        REVIEW.write_text(render(record), encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.read_text(encoding="utf-8") == render(record),
                "generated Patch 21.3 review is stale; run project")
    elif args.command == "witness-cases":
        for row in record["migrated_witnesses"]:
            print("\t".join((row["source_fixture"],
                              str(row["mir_to_c_exit"]))))
        return
    print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
