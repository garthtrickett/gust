#!/usr/bin/env python3
"""Validate, project, and exercise Patch 19.6 spelling-rule convergence."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
AUTHORITY = ROOT / "compiler/phase19_spelling_rule.gst"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
CODEGEN = ROOT / "compiler/codegen.gst"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE19_RULE_CONVERGENCE.md"
GUARD = "guard-cranelift-phase19-rule-convergence"

SPELLINGS = [
    "ctx", "connCtx", "arena", "a", "Any", "ctx1", "ctx2", "innerCtx",
    "outerCtx", "current_ctx", "next_ctx", "main_ctx", "bg_ctx", "file_ctx",
]
REQUIRED_CASES = {
    "suffix_ctx", "substring_ctx", "substring_a", "arrow_ctx", "arrow_a",
    "negative_exact", "negative_suffix", "negative_expression",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def function_body(source: str, name: str) -> str:
    marker = f"func {name}("
    start = source.find(marker)
    require(start >= 0, f"missing function {name}")
    open_brace = source.find("{", start)
    require(open_brace >= 0, f"missing body for {name}")
    depth = 0
    for position in range(open_brace, len(source)):
        if source[position] == "{":
            depth += 1
        elif source[position] == "}":
            depth -= 1
            if depth == 0:
                return source[open_brace : position + 1]
    raise SystemExit(f"{GUARD}: unterminated function {name}")


def expected(case: dict, spellings: list[str]) -> tuple[int, str]:
    value = case["input"]
    form = case["form"]
    if form == "exact":
        return (int(value in spellings), value if value in spellings else "")
    if form == "suffix":
        if value in spellings:
            return (1, value)
        for spelling in spellings:
            if value.endswith("_" + spelling) or value.endswith("__" + spelling):
                return (1, spelling)
        return (0, "")
    if form == "expression":
        match = value in spellings or any(
            "." + spelling in value or "->" + spelling in value
            for spelling in spellings
        )
        return (int(match), "")
    raise AssertionError(form)


def load_record() -> tuple[dict, dict]:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase19_rule_convergence")
    require(isinstance(record, dict), "phase19_rule_convergence registry record missing")
    return registry, record


def validate() -> dict:
    registry, record = load_record()
    expected_fields = {
        "authority_version": "phase19_self_hosted_spelling_rule_v1",
        "status": "ready_for_patch19_7",
        "next_patch": "19.7",
        "review_view": "compiler/CRANELIFT_PHASE19_RULE_CONVERGENCE.md",
        "shared_authority": "compiler/phase19_spelling_rule.gst",
        "consumer_policy": "all_remaining_self_hosted_consumers_delegate_to_one_ordered_case_table",
        "matching_forms": ["exact", "suffix", "expression"],
    }
    for key, value in expected_fields.items():
        require(record.get(key) == value, f"{key} drifted")
    require(record.get("legacy_spellings") == SPELLINGS,
            "ordered legacy spelling table drifted")
    require(registry.get("phase19_representation", {}).get("next_patch") == "19.6",
            "rule convergence does not follow the Patch 19.5 authority")

    cases = record.get("cases")
    require(isinstance(cases, list) and cases, "shared case table is empty")
    case_ids = [case.get("id") for case in cases]
    require(len(case_ids) == len(set(case_ids)), "shared case IDs are not unique")
    require(REQUIRED_CASES <= set(case_ids), "required suffix/substring/arrow cases are missing")
    for case in cases:
        match, brand = expected(case, SPELLINGS)
        require(case.get("expected_match") == match,
                f"case {case.get('id')} expected_match disagrees with the ordered table")
        if case.get("form") in {"exact", "suffix"}:
            require(case.get("expected_brand") == brand,
                    f"case {case.get('id')} expected_brand disagrees with the ordered table")
        else:
            require(case.get("expected_brand") == "",
                    f"expression case {case.get('id')} must not invent a brand identity")

    inventory_ids = {
        site["id"] for site in registry.get("phase19_spelling_inventory", {}).get("sites", [])
    }
    dispositions = record.get("site_dispositions")
    disposition_ids = [row.get("id") for row in dispositions]
    require(len(disposition_ids) == len(set(disposition_ids)), "site disposition IDs repeat")
    require(set(disposition_ids) == inventory_ids,
            "every Patch 19.1 spelling site must terminate exactly once")

    successor = registry.get("phase19_gust_name_list_removed")
    if isinstance(successor, dict):
        require(successor.get("removed_authority") == "compiler/phase19_spelling_rule.gst",
                "Patch 19.8 does not identify the superseded spelling authority")
        require(not AUTHORITY.exists(), "superseded spelling authority returned")
        compiler_sources = TYPECHECKER.read_text(encoding="utf-8") + CODEGEN.read_text(
            encoding="utf-8"
        )
        require('import "phase19_spelling_rule.gst"' not in compiler_sources,
                "superseded spelling authority is still imported")
        require("phase19_legacy_brand_" not in compiler_sources,
                "superseded spelling consumer returned")
        require("- [x] Patch 19.6 — Self-Hosted Rule Convergence — DONE"
                in TASK.read_text(encoding="utf-8"),
                "TASK.md does not mark Patch 19.6 DONE")
        return record

    authority = AUTHORITY.read_text(encoding="utf-8")
    table_body = function_body(authority, "phase19_legacy_brand_spellings")
    pushes = []
    for line in table_body.splitlines():
        line = line.strip()
        if line.startswith('brands.Push("') and line.endswith('");'):
            pushes.append(line[len('brands.Push("') : -len('");')])
    require(pushes == SPELLINGS, "compiler authority does not match the ordered registry table")
    for name in (
        "phase19_legacy_brand_spelling_is_exact",
        "phase19_legacy_brand_from_suffix",
        "phase19_legacy_brand_spelling_in_expression",
    ):
        body = function_body(authority, name)
        require("phase19_legacy_brand_spellings(ctx)" in body,
                f"{name} does not consume the shared table")

    typechecker = TYPECHECKER.read_text(encoding="utf-8")
    codegen = CODEGEN.read_text(encoding="utf-8")
    require('import "phase19_spelling_rule.gst" as spelling_rule;' in typechecker,
            "typechecker does not import the shared spelling authority")
    require('import "phase19_spelling_rule.gst" as spelling_rule;' in codegen,
            "codegen does not import the shared spelling authority")
    extract = function_body(typechecker, "typechecker_extract_brand_from_suffix")
    require("spelling_rule.phase19_legacy_brand_from_suffix(suffix, ctx)" in extract,
            "typechecker suffix extraction does not delegate")
    parser = function_body(typechecker, "parse_one_type_from_parts")
    require("spelling_rule.phase19_legacy_brand_spelling_is_exact(next_part, ctx)" in parser,
            "typechecker brand-member parsing does not delegate")
    require(typechecker.count("spelling_rule.phase19_legacy_brand_spelling_is_exact(") >= 5,
            "self-hosted typechecker consumers did not converge on the exact rule")
    codegen_brand = function_body(codegen, "codegen_is_brand_type")
    require("spelling_rule.phase19_legacy_brand_from_suffix(name, ctx)" in codegen_brand,
            "codegen brand recognition does not delegate")
    generate = function_body(codegen, "codegen_generate_expression")
    require("spelling_rule.phase19_legacy_brand_spelling_in_expression(alloc_str, ctx)" in generate,
            "codegen generated-expression matching does not delegate")
    for legacy_copy in (
        'std.str_eq(next_part, "ctx")',
        'std.str_eq(g_name, "ctx") || std.str_eq(g_name, "connCtx")',
        'std.str_find(alloc_str, "->ctx")',
        'codegen_ends_with(name, "_ctx")',
    ):
        require(legacy_copy not in typechecker + codegen,
                f"divergent legacy consumer remains: {legacy_copy}")

    require("- [x] Patch 19.6 — Self-Hosted Rule Convergence — DONE"
            in TASK.read_text(encoding="utf-8"), "TASK.md does not mark Patch 19.6 DONE")
    return record


def render(record: dict) -> str:
    dispositions = record["site_dispositions"]
    lines = [
        "# Cranelift Phase 19 Self-Hosted Rule Convergence",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase19_rule_convergence.py project`. Do not edit by hand.",
        "",
        f"- Authority: `{record['authority_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Shared compiler authority: `{record['shared_authority']}`",
        f"- Ordered legacy spellings: `{len(record['legacy_spellings'])}`",
        f"- Shared cases: `{len(record['cases'])}`",
        "",
        "## Result",
        "",
        "The legacy brand-spelling rule has one ordered table. Exact brand-member",
        "recognition, type-name suffix extraction, and generated-expression matching",
        "all consume that table. The self-hosted typechecker and codegen no longer",
        "carry independent vocabularies. This patch deliberately retains the rule;",
        "Patch 19.8 removes the centralized compatibility path after Patch 19.7 proves",
        "the retired prototype cannot reintroduce a second implementation.",
        "",
        "The shared case family covers exact names, single- and module-suffix forms,",
        "dot substrings, `->ctx`, `->a`, and negative controls. `Any` compatibility is",
        "recorded separately because wildcard compatibility is an explicit semantic",
        "rule, not evidence that an arbitrary spelling denotes an arena.",
        "",
        "## Patch 19.1 site termination",
        "",
        "| Site | Disposition |",
        "| --- | --- |",
    ]
    for row in dispositions:
        lines.append(f"| `{row['id']}` | `{row['disposition']}` |")
    lines += [
        "",
        "No runtime symbol, MIR instruction, ABI, layout, resource rule, target policy,",
        "or source syntax changed.",
        "",
    ]
    return "\n".join(lines)


def emit_fixture(record: dict) -> str:
    lines = [
        'import "../../../compiler/phase19_spelling_rule.gst" as spelling_rule;',
        "",
        "func main() int {",
        "    mut arena := os.Arena.New();",
        "    defer arena.Free();",
    ]
    for ordinal, case in enumerate(record["cases"], start=1):
        value = case["input"]
        if case["form"] == "exact":
            expression = f'spelling_rule.phase19_legacy_brand_spelling_is_exact("{value}", &arena)'
            lines.append(f"    if {expression} != {case['expected_match']} {{ os.Exit({ordinal}); }}")
        elif case["form"] == "suffix":
            expression = f'spelling_rule.phase19_legacy_brand_from_suffix("{value}", &arena)'
            brand = case["expected_brand"]
            lines.append(
                f'    if std.str_eq({expression}, "{brand}") == 0 {{ os.Exit({ordinal}); }}'
            )
        else:
            expression = f'spelling_rule.phase19_legacy_brand_spelling_in_expression("{value}", &arena)'
            lines.append(f"    if {expression} != {case['expected_match']} {{ os.Exit({ordinal}); }}")
    lines += ["    return 0;", "}", ""]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review", "emit-fixture"))
    args = parser.parse_args()
    record = validate()
    if args.command == "project":
        REVIEW.write_text(render(record), encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file(), "generated review view missing")
        require(REVIEW.read_text(encoding="utf-8") == render(record),
                "generated review view is stale; run phase19_rule_convergence.py project")
    elif args.command == "emit-fixture":
        print(emit_fixture(record), end="")
    stream = sys.stderr if args.command == "emit-fixture" else sys.stdout
    print(f"{GUARD}: ok", file=stream)


if __name__ == "__main__":
    main()
