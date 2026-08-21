#!/usr/bin/env python3
"""Validate and project Patch 19.3 canonical branded type naming."""

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
CODEGEN = ROOT / "compiler/codegen.gst"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE19_TYPE_NAMING.md"
GUARD = "guard-cranelift-phase19-type-naming-contract"


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
    record = registry.get("phase19_type_naming")
    require(isinstance(record, dict), "phase19_type_naming registry record missing")
    return record


def validate() -> dict:
    record = load_record()
    require(record.get("authority_version") == "phase19_canonical_type_naming_v1",
            "authority version drifted")
    require(record.get("status") == "ready_for_patch19_4", "status drifted")
    require(record.get("next_patch") == "19.4", "next patch drifted")
    require(record.get("review_view") == "compiler/CRANELIFT_PHASE19_TYPE_NAMING.md",
            "review view drifted")
    require(record.get("identity_authority") == "phase19_brand_identity_authority_v1",
            "Patch 19.2 identity authority linkage drifted")
    require(record.get("construction_policy") == "template_plus_non_brand_resolved_type_arguments",
            "construction policy drifted")
    require(record.get("codegen_consumer") == "canonical_type_name_lookup_only",
            "codegen consumer policy drifted")
    require(record.get("legacy_suffix_surgery") == "removed_from_codegen_struct_name_erasure",
            "legacy suffix-surgery retirement drifted")

    typechecker = TYPECHECKER.read_text(encoding="utf-8")
    for needle in (
        "canonical_type_names: std.HashMap[str, str, ctx]",
        "func typechecker_construct_canonical_monomorphized_name(",
        "func typechecker_construct_brand_argument_elided_name(",
        "func typechecker_type_matches_brand_identity_argument(",
        "func env_record_canonical_type_name(",
        "func env_get_canonical_type_name(",
        "mut val_type_ident := typechecker_canonical_type_ident(env, v_type, ctx);",
    ):
        require(needle in typechecker, f"canonical naming authority missing {needle!r}")
    require(typechecker.count("env_ref_new.canonical_type_names = std.HashMapNew(ctx);") == 1,
            "canonical naming map initialization drifted")
    require(typechecker.count("typechecker_construct_canonical_monomorphized_name(") == 3,
            "canonical construction must cover the helper plus enum and struct monomorphization")
    require(typechecker.count("typechecker_construct_brand_argument_elided_name(") == 3,
            "construction-state alias coverage drifted")

    codegen = CODEGEN.read_text(encoding="utf-8")
    erase_body = function_body(codegen, "codegen_erase_struct_name")
    require("typechecker.env_get_canonical_branded_type_name" in erase_body,
            "codegen erasure does not consume canonical naming metadata")
    for forbidden in ("brand_bases", "codegen_ends_with", "std.str_slice", "codegen_strip_brand_prefix"):
        require(forbidden not in erase_body,
                f"codegen struct-name erasure still performs string surgery via {forbidden}")

    paired_sources = record.get("paired_sources")
    require(paired_sources == [
        "compiler/phase19_type_naming_explicit_source.gst",
        "compiler/phase19_type_naming_inferred_source.gst",
    ], "paired source list drifted")
    for source_path in paired_sources:
        require((ROOT / source_path).is_file(), f"paired source missing: {source_path}")

    aliases = record.get("native_abi_aliases")
    require(isinstance(aliases, list) and len(aliases) == 4,
            "native ABI alias enumeration drifted")
    for alias in aliases:
        needle = (
            f'env_record_canonical_type_name(env, "{alias["branded_name"]}", '
            f'"{alias["canonical_name"]}", ctx);'
        )
        require(needle in typechecker, f"native ABI alias missing: {alias['branded_name']}")

    changes = record.get("enumerated_generated_c_changes")
    require(isinstance(changes, list) and len(changes) == 2,
            "generated-C change enumeration drifted")
    require("- [x] Patch 19.3 — Canonical Branded Type Naming Without a Brand Vocabulary — DONE"
            in TASK.read_text(encoding="utf-8"), "TASK.md does not mark Patch 19.3 DONE")
    return record


def render(record: dict) -> str:
    aliases = "\n".join(
        f'| `{item["branded_name"]}` | `{item["canonical_name"]}` |'
        for item in record["native_abi_aliases"]
    )
    changes = "\n".join(
        f'| `{item["old_name"]}` | `{item["canonical_name"]}` | {item["reason"]} |'
        for item in record["enumerated_generated_c_changes"]
    )
    return f"""# Cranelift Phase 19 Canonical Branded Type Naming

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase19_type_naming.py project`. Do not edit by hand.

- Authority: `{record['authority_version']}`
- Status: `{record['status']}`
- Next patch: `{record['next_patch']}`
- Identity authority: `{record['identity_authority']}`
- Construction: `{record['construction_policy']}`
- Codegen consumer: `{record['codegen_consumer']}`

## Result

Monomorphization now constructs a canonical name from the template and its
non-brand resolved type arguments. The exact arena identity comes from the
Patch 19.2 `BrandIdentity` record. `codegen_erase_struct_name` performs a
metadata lookup only; it no longer deletes suffixes or consults a brand-word
vocabulary.

Both the full monomorphized name and the construction state with the outer
brand argument elided map to the same canonical name. This keeps arena-index
metadata, struct declarations, and synthetic wrapper names aligned without
reverse-parsing a flattened string.

## Native ABI aliases

The following types enter through manually registered runtime signatures, not
Gust template monomorphization. Their existing C ABI spellings are recorded at
that boundary.

| Branded signature name | Canonical C name |
| --- | --- |
{aliases}

## Enumerated generated-C naming changes

The paired inferred/explicit fixture uses the namespaced arena identity
`lib_module__ctx`. The old surgery removed only `module__ctx`, leaving a false
`_lib` type argument. Construction removes the complete brand argument.

| Before | After | Reason |
| --- | --- | --- |
{changes}

The inferred and explicit sources emit byte-identical C after this correction,
and the resulting translation unit compiles and runs. No MIR instruction,
layout, ABI, runtime symbol, or backend-specific semantic changed.
"""


def project(check: bool) -> None:
    record = validate()
    expected = render(record)
    if check:
        require(REVIEW.is_file(), "generated review view missing")
        require(REVIEW.read_text(encoding="utf-8") == expected,
                "generated review view is stale; run phase19_type_naming.py project")
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
