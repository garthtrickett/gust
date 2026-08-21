#!/usr/bin/env python3
"""Validate and project Patch 19.8 self-hosted name-list removal."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE19_GUST_NAME_LIST_REMOVED.md"
AUTHORITY = ROOT / "compiler/phase19_spelling_rule.gst"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
CODEGEN = ROOT / "compiler/codegen.gst"
GENERATED_COMPILER_C = ROOT / "build/gust_compiler.c"
GUARD = "guard-cranelift-phase19-gust-name-list-removed"

LEGACY_IDENTIFIERS = (
    "phase19_legacy_brand_spellings",
    "phase19_legacy_brand_spelling_is_exact",
    "phase19_legacy_brand_from_suffix",
    "phase19_legacy_brand_spelling_in_expression",
    "typechecker_extract_brand_from_suffix",
    "typechecker_clean_monomorphized_name",
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def load_record() -> tuple[dict, dict]:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase19_gust_name_list_removed")
    require(isinstance(record, dict), "registry record missing")
    return registry, record


def validate() -> dict:
    registry, record = load_record()
    expected = {
        "contract_version": "phase19_gust_name_list_removed_v1",
        "status": "ready_for_patch19_9",
        "next_patch": "19.9",
        "review_view": "compiler/CRANELIFT_PHASE19_GUST_NAME_LIST_REMOVED.md",
        "removed_authority": "compiler/phase19_spelling_rule.gst",
        "decision_policy": "template_role_and_resolved_type_metadata_only",
        "generated_c_baseline_sha256": "3d5a969d8228486f242bd30efd2f41886eb3b18a9cea7d8119ce02eda181c0b1",
        "generated_c_current_sha256": "0c950d953ee6ed7f3fcf77dae301cfed64d2704d0f620fb1a0e4a441ab187f07",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")
    if GENERATED_COMPILER_C.is_file():
        generated_digest = hashlib.sha256(GENERATED_COMPILER_C.read_bytes()).hexdigest()
        require(generated_digest == record["generated_c_current_sha256"],
                "built compiler C does not match the enumerated Patch 19.8 output")
    require(
        registry.get("phase19_retired_prototype_absence", {}).get("next_patch") == "19.8",
        "name-list removal does not follow Patch 19.7",
    )
    require(not AUTHORITY.exists(), "retired spelling authority still exists")

    compiler_sources = "\n".join(
        path.read_text(encoding="utf-8") for path in sorted((ROOT / "compiler").glob("*.gst"))
    )
    for identifier in LEGACY_IDENTIFIERS:
        require(identifier not in compiler_sources, f"legacy consumer remains: {identifier}")
    require('import "phase19_spelling_rule.gst"' not in compiler_sources,
            "retired spelling authority is still imported")

    typechecker = TYPECHECKER.read_text(encoding="utf-8")
    codegen = CODEGEN.read_text(encoding="utf-8")
    semantic_sources = typechecker + codegen
    legacy_spelling_pattern = re.compile(
        r'std\.str_(?:eq|find)\([^\n]*"(?:ctx|connCtx|arena|a|ctx1|ctx2|innerCtx|'
        r'outerCtx|current_ctx|next_ctx|main_ctx|bg_ctx|file_ctx)"'
    )
    require(legacy_spelling_pattern.search(semantic_sources) is None,
            "spelling-derived semantic comparison remains in typechecker/codegen")
    for needle in (
        "brand_parameter_index: int",
        "func typechecker_type_is_brand_marker(",
        "func typechecker_infer_struct_template_brand_parameter(",
        "func typechecker_infer_enum_template_brand_parameter(",
        "func env_get_template_brand_parameter_index(",
        "func env_get_canonical_branded_type_name(",
        "func typechecker_canonicalize_concrete_name(",
    ):
        require(needle in typechecker, f"structural type authority missing {needle!r}")
    require(
        "typechecker.typechecker_type_is_brand_marker(t, ctx)" in codegen,
        "codegen does not consume the structural brand marker",
    )
    require(
        "typechecker.env_get_template_brand_parameter_index(env, name)" in codegen,
        "codegen does not consume template role metadata",
    )
    require(
        "typechecker.env_get_canonical_branded_type_name(env, name, brand, ctx)" in codegen,
        "codegen does not delegate canonical branded-name lookup",
    )

    diff = record.get("generated_c_diff")
    require(isinstance(diff, dict), "generated-C difference enumeration missing")
    require(diff.get("insertions") == 532 and diff.get("deletions") == 435,
            "generated-C line counts drifted")
    categories = diff.get("categories")
    require(isinstance(categories, list) and len(categories) == 6,
            "generated-C categories must enumerate six bounded changes")
    require(all(set(row) == {"id", "scope"} for row in categories),
            "generated-C category shape drifted")

    fixtures = record.get("parity_fixtures")
    require(fixtures == [
        "compiler/phase19_name_list_removed_ctx_source.gst",
        "compiler/phase19_name_list_removed_region_source.gst",
    ], "parity fixture family drifted")
    require(all((ROOT / path).is_file() for path in fixtures), "parity fixture missing")
    require("- [x] Patch 19.8 — Name-List Removal From the Self-Hosted Compiler — DONE"
            in TASK.read_text(encoding="utf-8"), "TASK.md does not mark Patch 19.8 DONE")
    return record


def render(record: dict) -> str:
    lines = [
        "# Cranelift Phase 19 Gust Name-List Removal",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase19_gust_name_list_removed.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Decision policy: `{record['decision_policy']}`",
        f"- Removed authority: `{record['removed_authority']}`",
        f"- Baseline generated C SHA-256: `{record['generated_c_baseline_sha256']}`",
        f"- Current generated C SHA-256: `{record['generated_c_current_sha256']}`",
        "",
        "## Result",
        "",
        "The ordered brand-name vocabulary and every exact, suffix, substring, and",
        "generated-expression consumer are absent from `compiler/*.gst`. Generic",
        "templates record one brand-argument position, resolution represents that",
        "argument with existing AST brand metadata, and codegen consumes those records.",
        "The committed seed compiles the resulting compiler with `make gust`.",
        "",
        "## Generated-C difference enumeration",
        "",
        f"The compiler C changed by {record['generated_c_diff']['insertions']} insertions and",
        f"{record['generated_c_diff']['deletions']} deletions. Every hunk belongs to one of:",
        "",
    ]
    lines += [f"- `{row['id']}` — {row['scope']}" for row in record["generated_c_diff"]["categories"]]
    lines += [
        "",
        "The differences are compiler-internal authority and generated helper changes;",
        "there is no new syntax, MIR operation, ABI/layout change, runtime symbol, target",
        "policy, linker policy, or backend-specific meaning.",
        "",
        "## Level 2 parity",
        "",
        "The paired sources differ only by renaming the template/allocator brand from",
        "`ctx` to `region`. Both compile without diagnostics and return 19, proving an",
        "arbitrary spelling follows the same structural role.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review"))
    args = parser.parse_args()
    record = validate()
    if args.command == "project":
        REVIEW.write_text(render(record), encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file(), "generated review view missing")
        require(REVIEW.read_text(encoding="utf-8") == render(record),
                "generated review view is stale; run phase19_gust_name_list_removed.py project")
    print(f"{GUARD}: ok")


if __name__ == "__main__":
    main()
