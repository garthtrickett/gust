#!/usr/bin/env python3
"""Validate and project Patch 19.7's retired-prototype absence contract."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE19_RETIRED_PROTOTYPE_ABSENCE.md"
TASK = ROOT / "TASK.md"
GUARD = "guard-cranelift-phase19-retired-prototype-absent"

RETIRED_ROOT_PACKAGE = (
    "Cargo.toml",
    "Cargo.lock",
    "src/ast.rs",
    "src/codegen.rs",
    "src/codegen_runtime.rs",
    "src/lexer.rs",
    "src/lib.rs",
    "src/main.rs",
    "src/parser.rs",
    "src/resolver.rs",
    "src/token.rs",
    "src/typechecker.rs",
    "src/typechecker/monomorphize.rs",
    "src/typechecker/types.rs",
    "src/typechecker/visitor.rs",
)
PRESERVED_BOUNDARIES = (
    "src/runtime.c",
    "src/runtime/*.c",
    "src/runtime/rust/",
    "compiler/experiments/cranelift/",
)
CURRENT_SEMANTICS_DOCUMENTS = (
    "TASK.md",
    "docs/SHARED_SEMANTIC_ZONE.md",
    "docs/VISION.md",
    "compiler/CRANELIFT_PHASE19_OPENING.md",
    "compiler/CRANELIFT_PHASE19_SPELLING_INVENTORY.md",
    "compiler/CRANELIFT_PHASE19_BRAND_AUTHORITY.md",
    "compiler/CRANELIFT_PHASE19_TYPE_NAMING.md",
    "compiler/CRANELIFT_PHASE19_CLASSIFICATION.md",
    "compiler/CRANELIFT_PHASE19_REPRESENTATION.md",
    "compiler/CRANELIFT_PHASE19_RULE_CONVERGENCE.md",
    "compiler/CRANELIFT_PHASE19_GUST_NAME_LIST_REMOVED.md",
)
HISTORICAL_EXCEPTION = "docs/RUST_PROTOTYPE_REMOVAL.md"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def read(path: str) -> str:
    source = ROOT / path
    require(source.is_file(), f"required file is missing: {path}")
    return source.read_text(encoding="utf-8")


def retired_references(text: str) -> list[str]:
    """Find repository-root path references, not live paths ending the same way."""
    found = []
    for path in RETIRED_ROOT_PACKAGE:
        pattern = rf"(?<![A-Za-z0-9_./-]){re.escape(path)}(?=$|[^A-Za-z0-9_./-])"
        if re.search(pattern, text):
            found.append(path)
    return found


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase19_retired_prototype_absence")
    require(isinstance(record, dict), "absence contract registry record missing")
    expected = {
        "contract_version": "phase19_retired_prototype_absence_v1",
        "status": "ready_for_patch19_8",
        "next_patch": "19.8",
        "review_view": "compiler/CRANELIFT_PHASE19_RETIRED_PROTOTYPE_ABSENCE.md",
        "live_compiler_scope": "self_hosted_compiler_only",
        "retired_root_package": list(RETIRED_ROOT_PACKAGE),
        "preserved_boundaries": list(PRESERVED_BOUNDARIES),
        "current_semantics_documents": list(CURRENT_SEMANTICS_DOCUMENTS),
        "historical_citation_exception": HISTORICAL_EXCEPTION,
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")

    require(
        registry.get("phase19_rule_convergence", {}).get("next_patch") == "19.7",
        "absence contract does not follow Patch 19.6",
    )

    returned = [path for path in RETIRED_ROOT_PACKAGE if (ROOT / path).exists()]
    require(not returned, f"retired root Rust package returned: {returned}")

    require((ROOT / "src/runtime.c").is_file(), "load-bearing src/runtime.c is missing")
    runtime_modules = sorted((ROOT / "src/runtime").glob("*.c"))
    require(runtime_modules, "src/runtime/*.c contains no live runtime modules")
    for crate, required_files in (
        ("src/runtime/rust", ("Cargo.toml", "Cargo.lock", "src/lib.rs")),
        ("compiler/experiments/cranelift", ("Cargo.toml", "Cargo.lock", "src/main.rs")),
    ):
        require((ROOT / crate).is_dir(), f"preserved Rust crate is missing: {crate}/")
        for required_file in required_files:
            path = f"{crate}/{required_file}"
            require((ROOT / path).is_file(), f"preserved Rust crate input is missing: {path}")

    for document in CURRENT_SEMANTICS_DOCUMENTS:
        text = read(document)
        stale = retired_references(text)
        require(not stale, f"{document} cites retired compiler input(s): {stale}")

    phase19_projection = {
        key: value
        for key, value in registry.items()
        if key.startswith("phase19_") and key != "phase19_retired_prototype_absence"
    }
    phase19_projection["opening_snapshot"] = registry.get("opening_snapshots", {}).get(
        "phase19", {}
    )
    projection_text = json.dumps(phase19_projection, sort_keys=True)
    stale_projection = retired_references(projection_text)
    require(
        not stale_projection,
        f"Phase 19 registry projection cites retired compiler input(s): {stale_projection}",
    )
    require(
        {row.get("compiler") for row in phase19_projection["phase19_spelling_inventory"]["sites"]}
        == {"self_hosted"},
        "Phase 19 spelling projection does not name exactly the live compiler",
    )

    require((ROOT / HISTORICAL_EXCEPTION).is_file(), "historical removal plan is missing")
    historical_text = read(HISTORICAL_EXCEPTION)
    require(
        "Status: completed 2026-08-21." in historical_text
        and "not evidence for current compiler semantics" in historical_text,
        "removal plan is not explicitly classified as historical evidence",
    )
    require(
        bool(retired_references(historical_text)),
        "historical removal plan no longer records the retired boundary",
    )
    require(
        "- [x] Patch 19.7 — Retired Prototype Absence Contract — DONE"
        in TASK.read_text(encoding="utf-8"),
        "TASK.md does not mark Patch 19.7 DONE",
    )
    return record


def render(record: dict) -> str:
    lines = [
        "# Cranelift Phase 19 Retired-Prototype Absence Contract",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase19_retired_prototype_absence.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Live compiler scope: `{record['live_compiler_scope']}`",
        "",
        "## Retired root package",
        "",
        "These paths must remain absent:",
        "",
    ]
    lines += [f"- `{path}`" for path in record["retired_root_package"]]
    lines += [
        "",
        "## Preserved boundaries",
        "",
        "These live runtime and backend paths are outside the removal boundary:",
        "",
    ]
    lines += [f"- `{path}`" for path in record["preserved_boundaries"]]
    lines += [
        "",
        "## Current semantic evidence",
        "",
        "Phase 19 registry projections and current-semantic documents are checked",
        "against the retired path list. The sole exception is",
        f"`{record['historical_citation_exception']}`, which records the completed",
        "removal rather than describing a live compiler implementation.",
        "",
        "No Gust syntax, type rule, MIR instruction, ABI, layout, runtime symbol,",
        "target policy, linker policy, compiler source, or bootstrap seed changed.",
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
        require(
            REVIEW.read_text(encoding="utf-8") == render(record),
            "generated review view is stale; run phase19_retired_prototype_absence.py project",
        )
    print(f"{GUARD}: ok")


if __name__ == "__main__":
    main()
