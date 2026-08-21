#!/usr/bin/env python3
"""Validate and project Patch 19.4 type-derived classification authority."""

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
CODEGEN = ROOT / "compiler/codegen.gst"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE19_CLASSIFICATION.md"
GUARD = "guard-cranelift-phase19-classification-contract"


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
    for pos in range(open_brace, len(source)):
        if source[pos] == "{":
            depth += 1
        elif source[pos] == "}":
            depth -= 1
            if depth == 0:
                return source[open_brace : pos + 1]
    raise SystemExit(f"{GUARD}: unterminated function {name}")


def load_record() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase19_classification")
    require(isinstance(record, dict), "phase19_classification registry record missing")
    return record


def validate() -> dict:
    record = load_record()
    expected = {
        "authority_version": "phase19_type_derived_classification_v1",
        "status": "ready_for_patch19_5",
        "next_patch": "19.5",
        "review_view": "compiler/CRANELIFT_PHASE19_CLASSIFICATION.md",
        "type_authority": "resolved_type_plus_struct_registry_metadata",
        "override_policy": "retained_and_asserted_redundant",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")
    require(record.get("classifications") == [
        "slice", "pointer", "vector", "hashmap", "pool", "arena"
    ], "classification surface drifted")
    require(record.get("fixtures") == [
        "compiler/phase19_classification_test_entry.gst",
        "compiler/phase19_classification_source.gst",
        "compiler/test_runner_entry.gst",
    ], "fixture surface drifted")
    disagreements = record.get("measured_override_disagreements")
    require(isinstance(disagreements, list) and disagreements == [{
        "resolved_shape": "Reference(Arena)",
        "legacy_spelling": "ctx",
        "occurrences": 1597,
        "root_cause": "arena_type_predicate_omitted_reference",
        "resolution": "shared_resolved_type_classifier_includes_reference_arena",
    }], "measured override disagreement record drifted")

    typechecker = TYPECHECKER.read_text(encoding="utf-8")
    for needle in (
        "struct_container_kinds: std.HashMap[str, int, ctx]",
        "func typechecker_classification_slice() int",
        "func typechecker_classification_pointer() int",
        "func typechecker_classification_vector() int",
        "func typechecker_classification_hashmap() int",
        "func typechecker_classification_pool() int",
        "func typechecker_classification_arena() int",
        "func typechecker_classify_resolved_type(",
        "func typechecker_classify_type(",
        "func env_get_struct_container_kind(",
        "mut concrete_container_kind := env_get_struct_template_container_kind(env, template_name);",
        "env_record_struct_container_kind(env, concrete_name, concrete_container_kind, ctx);",
    ):
        require(needle in typechecker, f"classification authority missing {needle!r}")
    classify_body = function_body(typechecker, "typechecker_classify_resolved_type")
    for kind in ("slice", "pointer", "vector", "hashmap", "pool", "arena"):
        require(f"typechecker_classification_{kind}()" in classify_body,
                f"resolved classifier omits {kind}")
    require("env_get_struct_container_kind" in classify_body,
            "container classification does not consult registered metadata")
    require("typechecker_is_arena_value_or_ref" in classify_body,
            "arena classification does not consume the resolved-type predicate")
    require(typechecker.count("env_record_struct_template_container_kind(env,") == 9,
            "Vector/HashMap/Pool template aliases are not completely registered")

    codegen = CODEGEN.read_text(encoding="utf-8")
    for name, kind in (
        ("codegen_is_slice_type", "slice"),
        ("codegen_is_ptr_type", "pointer"),
        ("codegen_is_vector_type", "vector"),
        ("codegen_is_hashmap_type", "hashmap"),
        ("codegen_is_pool_type", "pool"),
    ):
        body = function_body(codegen, name)
        require("typechecker.typechecker_classify_type" in body and
                f"typechecker_classification_{kind}()" in body,
                f"{name} does not consume the shared classifier")
        require("std.str_find" not in body and "std.str_eq" not in body,
                f"{name} still classifies from spelling")
    require("codegen_expression_is_arena_ptr" in codegen,
            "arena pointer classification is not expression-type-derived")
    require("codegen_is_arena_ptr" not in codegen,
            "legacy identifier-based arena pointer classifier remains")
    for forbidden in (
        'std.str_find(clean, "Vector_")',
        'std.str_find(clean, "HashMap_")',
        'std.str_find(clean, "Pool_")',
    ):
        require(forbidden not in typechecker and forbidden not in codegen,
                f"container spelling classifier remains: {forbidden}")

    generate_body = function_body(codegen, "codegen_generate_expression")
    assertion = "Fatal Error: Phase 19 spelling override changed arena classification"
    require("mut resolved_alloc_t := typechecker.env_resolve_type(env, alloc_t, ctx);" in generate_body and
            "typechecker.typechecker_classify_resolved_type(resolved_alloc_t, typechecker.typechecker_classification_arena(), env, ctx)" in generate_body,
            "index arena classification does not consume the resolved allocator type")
    require(assertion in generate_body, "redundancy assertion is missing")
    require("mut is_name_match := 0;" in generate_body,
            "compatibility spelling override was removed before its retirement patch")
    require(generate_body.find(assertion) < generate_body.find("if is_name_match == 1 {", generate_body.find(assertion)),
            "spelling override is applied before its redundancy assertion")

    for fixture in record["fixtures"]:
        require((ROOT / fixture).is_file(), f"classification fixture missing: {fixture}")
    require("- [x] Patch 19.4 — Type-Derived Container and Arena Classification — DONE"
            in TASK.read_text(encoding="utf-8"), "TASK.md does not mark Patch 19.4 DONE")
    return record


def render(record: dict) -> str:
    disagreement = record["measured_override_disagreements"][0]
    return f"""# Cranelift Phase 19 Type-Derived Classification

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase19_classification.py project`. Do not edit by hand.

- Authority: `{record['authority_version']}`
- Status: `{record['status']}`
- Next patch: `{record['next_patch']}`
- Type authority: `{record['type_authority']}`
- Override policy: `{record['override_policy']}`

## Result

`str`/slice, ordinary pointer, Vector, HashMap, Pool, and arena classification
now come from one resolved-type classifier. Concrete container kinds are propagated
from registered templates into a registry keyed beside `struct_registry`; a
Vector-like user spelling without that metadata remains an ordinary struct.

Both typechecking and MIR-to-C consume the same classifier. Arena pointer/value
selection uses the resolved expression type. The remaining Clone brand
representation lookup is explicitly owned by Patch 19.5 and does not decide
whether a value is an arena.

## Measured legacy disagreement

The pre-change self-compilation probe found `{disagreement['occurrences']}`
instances of `{disagreement['resolved_shape']}` named
`{disagreement['legacy_spelling']}`. All had one root cause:
`{disagreement['root_cause']}`. The shared classifier now handles that shape.

The spelling override remains in index lowering, but a fatal assertion runs
before it can change the type-derived answer. Self-compilation and the focused
fixtures therefore prove it is redundant without deleting it prematurely.

No MIR instruction, runtime symbol, ABI, layout, or backend-specific semantic
changed.
"""


def project(check: bool) -> None:
    record = validate()
    expected = render(record)
    if check:
        require(REVIEW.is_file(), "generated review view missing")
        require(REVIEW.read_text(encoding="utf-8") == expected,
                "generated review view is stale; run phase19_classification.py project")
        return
    REVIEW.write_text(expected, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review"))
    args = parser.parse_args()
    if args.command == "validate":
        validate()
    elif args.command == "project":
        project(False)
    else:
        project(True)
    print(f"{GUARD}: ok")


if __name__ == "__main__":
    main()
