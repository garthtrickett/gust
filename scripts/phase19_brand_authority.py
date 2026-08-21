#!/usr/bin/env python3
"""Validate and project the Patch 19.2 brand-identity authority contract."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE19_BRAND_AUTHORITY.md"
REVIEW_PATH = "compiler/CRANELIFT_PHASE19_BRAND_AUTHORITY.md"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
FIXTURE = ROOT / "compiler/typechecker_brand_identity_test_entry.gst"
GUARD = "guard-cranelift-phase19-brand-authority-contract"

LEGACY_ARENA_NAMES = {"ctx", "arena", "connCtx", "a"}
DECLARATION = re.compile(
    r"\b(?:mut\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([^,;)=\{]+)"
)
INFERRED_ARENA = re.compile(
    r"\bmut\s+([A-Za-z_][A-Za-z0-9_]*)\s*:=\s*(?:os[._])?Arena\.New\s*\("
)
ARENA_TYPE = re.compile(r"[&*]?\s*(?:os[._])?Arena")


class Error(Exception):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def scan_disagreements() -> list[dict]:
    """Compare the old identifier rule with declared/inferred arena types."""
    rows: list[dict] = []
    seen: set[tuple[str, int, str, str]] = set()
    for path in sorted(ROOT.joinpath("compiler").glob("*.gst")):
        relative = path.relative_to(ROOT).as_posix()
        for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            line = raw_line.split("//", 1)[0]
            for match in DECLARATION.finditer(line):
                binding, declared_type = match.group(1), match.group(2).strip()
                spelling_is_arena = binding in LEGACY_ARENA_NAMES
                semantic_is_arena = ARENA_TYPE.fullmatch(declared_type) is not None
                if spelling_is_arena == semantic_is_arena:
                    continue
                reason = (
                    "legacy_name_on_non_arena_type"
                    if spelling_is_arena
                    else "arena_type_with_non_legacy_name"
                )
                key = (relative, line_number, binding, declared_type)
                if key not in seen:
                    seen.add(key)
                    rows.append({
                        "source_path": relative,
                        "line": line_number,
                        "binding": binding,
                        "declared_type": declared_type,
                        "spelling_is_arena": spelling_is_arena,
                        "record_is_arena": semantic_is_arena,
                        "reason": reason,
                    })
            for match in INFERRED_ARENA.finditer(line):
                binding = match.group(1)
                spelling_is_arena = binding in LEGACY_ARENA_NAMES
                if spelling_is_arena:
                    continue
                declared_type = "inferred Arena.New()"
                key = (relative, line_number, binding, declared_type)
                if key not in seen:
                    seen.add(key)
                    rows.append({
                        "source_path": relative,
                        "line": line_number,
                        "binding": binding,
                        "declared_type": declared_type,
                        "spelling_is_arena": False,
                        "record_is_arena": True,
                        "reason": "arena_type_with_non_legacy_name",
                    })
    return rows


def validate(registry: dict) -> dict:
    authority = registry.get("phase19_brand_authority")
    require(isinstance(authority, dict), "Phase 19 brand authority record missing")
    require(authority.get("authority_version") == "phase19_brand_identity_authority_v1",
            "Phase 19 brand authority version drifted")
    require(authority.get("status") == "ready_for_patch19_3",
            "Phase 19 brand authority status drifted")
    require(authority.get("next_patch") == "19.3", "Phase 19 brand authority next patch drifted")
    require(authority.get("review_view") == REVIEW_PATH, "Phase 19 brand authority review view drifted")
    require(authority.get("codegen_policy") == "unchanged_legacy_consumers_remain",
            "Patch 19.2 must not switch codegen consumers")
    require(authority.get("identity_fields") == ["brand_origin", "arena_identity", "is_arena"],
            "brand identity schema drifted")
    require(authority.get("public_boundary_policy") == "explicit_brand_required",
            "public API explicit-brand policy drifted")

    source = TYPECHECKER.read_text(encoding="utf-8")
    for needle in (
        "type BrandIdentity[ctx] struct {",
        "brand_identities: std.HashMap[str, BrandIdentity[ctx], ctx]",
        "func typechecker_brand_identity_from_resolved_type(",
        "func env_record_brand_identity(",
        "func env_get_brand_identity(",
        "func env_require_explicit_public_brand(",
        "[ImplicitPublicBrand]",
    ):
        require(needle in source, f"compiler-owned brand authority surface missing {needle!r}")
    require(source.count("env_require_explicit_public_brand(") == 3,
            "public brand enforcement must cover the helper, parameters, and returns")
    require(FIXTURE.is_file(), "brand identity semantic fixture missing")

    expected = authority.get("disagreements")
    if isinstance(registry.get("phase19_gust_name_list_removed"), dict):
        require(isinstance(expected, list) and expected,
                "historical brand/spelling disagreement inventory is empty")
        require({row["reason"] for row in expected} == {
            "legacy_name_on_non_arena_type", "arena_type_with_non_legacy_name"
        }, "historical brand/spelling comparison lost one disagreement direction")
        return authority
    actual = scan_disagreements()
    require(expected == actual,
            "brand/spelling disagreement inventory drifted; run phase19_brand_authority.py scan")
    require(actual, "brand/spelling comparison unexpectedly has no disagreements")
    require({row["reason"] for row in actual} == {
        "legacy_name_on_non_arena_type", "arena_type_with_non_legacy_name"
    }, "brand/spelling comparison must retain both disagreement directions")
    return authority


def render(authority: dict) -> str:
    rows = authority["disagreements"]
    spelling_only = sum(row["spelling_is_arena"] and not row["record_is_arena"] for row in rows)
    record_only = sum(row["record_is_arena"] and not row["spelling_is_arena"] for row in rows)
    lines = [
        "# Cranelift Phase 19 Brand Identity Authority",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase19_brand_authority.py project`. Do not edit by hand.",
        "",
        "Patch 19.2 adds a compiler-owned record during type resolution and",
        "leaves every legacy codegen consumer unchanged. The comparison below",
        "is therefore evidence for the later migration, not a codegen switch.",
        "",
        f"- Authority version: `{authority['authority_version']}`",
        f"- Status: `{authority['status']}`",
        f"- Identity fields: `{', '.join(authority['identity_fields'])}`",
        f"- Public boundary policy: `{authority['public_boundary_policy']}`",
        f"- Whole-source disagreements: `{len(rows)}`",
        f"- Legacy spelling only: `{spelling_only}`",
        f"- Resolved arena type only: `{record_only}`",
        "",
        "## Authority contract",
        "",
        "`TypeEnvironment.brand_identities` is populated by `env_resolve_type`.",
        "Its key is the canonical serialized resolved type; its value records",
        "where the brand came from, the arena identity, and whether the resolved",
        "value itself denotes an arena. Suffix spelling is deliberately excluded",
        "from the record and remains available only through the legacy helper.",
        "",
        "Public function parameters and returns that resolve to a branded type",
        "must name that brand explicitly. Missing brands produce",
        "`[ImplicitPublicBrand]`; ordinary unbranded values and `&Arena` remain valid.",
        "",
        "## Whole-compiler comparison",
        "",
        "The projector scans every `compiler/*.gst` declaration with an explicit",
        "type, plus local `Arena.New()` inference. These are every disagreement",
        "between the four-name arena rule and the resolved-type rule in that",
        "declarative surface.",
        "",
        "| Source | Binding | Declared/resolved type | Spelling says arena | Record says arena | Reason |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for row in rows:
        lines.append(
            f"| `{row['source_path']}:{row['line']}` | `{row['binding']}` "
            f"| `{row['declared_type']}` | `{str(row['spelling_is_arena']).lower()}` "
            f"| `{str(row['record_is_arena']).lower()}` | `{row['reason']}` |"
        )
    lines += [
        "",
        "The `legacy_name_on_non_arena_type` rows are false positives caused by",
        "ordinary scalar or view parameters named `a`. The",
        "`arena_type_with_non_legacy_name` rows are false negatives: their types",
        "are `Arena`/`&Arena` (or inferred from `Arena.New()`), regardless of name.",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review", "scan"))
    args = parser.parse_args()
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    try:
        if args.command == "scan":
            print(json.dumps(scan_disagreements(), indent=2))
            return 0
        authority = validate(registry)
        if args.command == "project":
            REVIEW.write_text(render(authority), encoding="utf-8")
        elif args.command == "check-review":
            require(REVIEW.is_file(), f"missing generated review: {REVIEW_PATH}")
            require(REVIEW.read_text(encoding="utf-8") == render(authority),
                    "generated Phase 19 brand authority review is stale; run project")
    except Error as error:
        print(f"{GUARD}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
