#!/usr/bin/env python3
"""Validate and project Patch 21.4 trusted Scope provenance authority."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE21_TRUSTED_SCOPE_PROVENANCE.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase21-trusted-scope-provenance.yml"
JUSTFILE = ROOT / "justfile"
GUARD_L1 = "guard-cranelift-phase21-trusted-scope-provenance-contract"
GUARD_L2 = "guard-cranelift-phase21-trusted-scope-provenance-evidence"
NEGATIVE_KINDS = ["absent", "forged_function", "wrong_scope",
                  "arbitrary_value", "cast", "copied_predicate_spelling"]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase21_trusted_scope_provenance")
    require(isinstance(record, dict), "Patch 21.4 authority is missing")
    require(record.get("contract_version") ==
            "phase21_trusted_scope_provenance_v1", "contract version drifted")
    require(record.get("status") == "patch21_4_complete" and
            record.get("next_patch") == "21.5", "status or successor drifted")
    require(record.get("trusted_origin_intrinsic") ==
            "trusted_scope_from_context", "trusted origin intrinsic drifted")
    require(record.get("trusted_origin_policy") ==
            "reserved_compiler_owned_compile_time_intrinsic_usable_only_inside_typed_query_predicates_with_one_literal_scope_identity_and_never_emitted_to_either_backend",
            "trusted origin boundary drifted")
    require(record.get("trusted_scope_type_policy") ==
            "the_intrinsic_result_is_the_compiler_only_nominal_type_Scope_of_the_literal_scope_identity_and_discharge_requires_that_exact_type",
            "trusted Scope nominal type policy drifted")
    require(record.get("provenance_carrier") == [
        "ExpressionProvenance.trusted_scope_identity",
        "ExpressionProvenance.trusted_scope_origin_kind",
    ], "trusted provenance carrier drifted")
    require(record.get("diagnostic_class") == "TenantScopeProvenance" and
            record.get("diagnostic") ==
            "error: query lacks trusted tenant-scope provenance",
            "query-site diagnostic drifted")

    positive = record.get("positive_fixture", {})
    require(positive == {
        "source_fixture": "compiler/phase21_trusted_scope_positive.gst",
        "mir_to_c_exit": 41, "cranelift_exit": 41,
    }, "positive observation drifted")
    negatives = record.get("negative_fixtures")
    require([row.get("kind") for row in negatives] == NEGATIVE_KINDS,
            "negative provenance population drifted")
    nonforgeability = record.get("nonforgeability_fixtures")
    require([row.get("diagnostic_class") for row in nonforgeability] ==
            ["TrustedScopeBoundary", "ReservedCompilerIntrinsic"],
            "trusted boundary non-forgeability population drifted")
    for row in [positive, *negatives, *nonforgeability]:
        require((ROOT / row["source_fixture"]).is_file(),
                f"missing Patch 21.4 fixture: {row['source_fixture']}")

    typechecker = read("compiler/typechecker.gst")
    generic = read("compiler/mir_native_backend_generic_source.gst")
    for spelling in (
        "struct_scoped_entity", "struct_scope_field",
        "trusted_scope_identity", "trusted_scope_origin_kind",
        "trusted_request_context_scope",
        "typechecker_make_trusted_scope_type",
        "typechecker_type_is_matching_trusted_scope",
        "typechecker_check_query_scope_obligations",
        "typechecker_query_predicate_discharges_root",
        "[TenantScopeProvenance] error: query lacks trusted tenant-scope provenance",
        "[TrustedScopeBoundary]", "[ReservedCompilerIntrinsic]",
    ):
        require(spelling in typechecker,
                f"trusted Scope implementation is missing: {spelling}")
    require("source_statement_phase21_4.StructDecl.is_scoped_entity == 0" in
            generic, "native metadata-only declaration filter is missing")
    require("trusted_scope_from_context" not in read("compiler/codegen.gst"),
            "trusted compile-time intrinsic leaked into codegen")
    require("trusted_scope_from_context(\"workspace_id\")" in
            read(positive["source_fixture"]), "positive lacks trusted origin")
    for row in negatives:
        source = read(row["source_fixture"])
        require("return query {" in source and "#[scoped(workspace_id)]" in source,
                f"negative is not a scoped query: {row['kind']}")

    boundary = record.get("boundary", {})
    require(boundary.get("primary_scoped_roots_enforced") is True,
            "primary scoped-root enforcement is not active")
    for field in (
        "join_roots_enforced", "nested_queries_enforced",
        "cross_tenant_capability_enforced",
        "trusted_request_context_establishment_claimed",
        "adds_or_changes_MIR_operations",
        "changes_ABI_layout_or_runtime_symbols", "changes_bootstrap_seed",
        "edits_stdlib",
    ):
        require(boundary.get(field) is False,
                f"Patch 21.4 widened boundary: {field}")
    require("- [x] Patch 21.4 — Trusted Scope Provenance Enforcement — DONE" in
            TASK.read_text(encoding="utf-8"), "TASK.md does not mark 21.4 DONE")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 21.4 guard levels drifted")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in justfile and f"{GUARD_L2}:" in justfile,
            "Patch 21.4 just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own Patch 21.4 Level 1")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow,
            "dedicated Patch 21.4 workflow does not own both guards")
    return record


def render(record: dict) -> str:
    lines = [
        "# Cranelift Phase 21 Trusted Scope Provenance", "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase21_trusted_scope_provenance.py project`. Do not edit by hand.",
        "", f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`", f"- Next patch: `{record['next_patch']}`",
        f"- Diagnostic: `{record['diagnostic_class']}` — `{record['diagnostic']}`",
        "", "A scoped entity records its declared scope field. A primary query root",
        "creates an obligation for that exact identity. Only provenance emitted",
        "by the reserved compile-time `trusted_scope_from_context` boundary, with",
        "the exact compiler-only nominal type `Scope[scope-identity]`, can discharge",
        "it; arbitrary values, function names, casts, and copied",
        "predicate spelling do not carry the provenance category.", "",
        "## Evidence", "",
        f"- Positive: `{record['positive_fixture']['source_fixture']}` — MIR-to-C and Cranelift exit `41`",
    ]
    for row in record["negative_fixtures"]:
        lines.append(f"- `{row['kind']}` — `{row['source_fixture']}` — rejected at query")
    for row in record["nonforgeability_fixtures"]:
        lines.append(f"- `{row['kind']}` — `{row['source_fixture']}` — `{row['diagnostic_class']}`")
    lines += ["", "The intrinsic is compile-time-only and is never emitted to either backend.",
              "Trusted request-context establishment is outside this guarantee. Join",
              "roots, nested queries, and cross-tenant capabilities remain explicitly",
              "unenforced for Patches 21.5 and 21.6.", ""]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review",
                                             "negative-cases", "nonforgeability-cases"))
    args = parser.parse_args()
    record = validate()
    if args.command == "project":
        REVIEW.write_text(render(record), encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.read_text(encoding="utf-8") == render(record),
                "generated Patch 21.4 review is stale; run project")
    elif args.command == "negative-cases":
        for row in record["negative_fixtures"]:
            print("\t".join((row["kind"], row["source_fixture"])))
        return
    elif args.command == "nonforgeability-cases":
        for row in record["nonforgeability_fixtures"]:
            print("\t".join((row["kind"], row["source_fixture"], row["diagnostic_class"])))
        return
    print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
