#!/usr/bin/env python3
"""Validate and project Patch 21.2 inert scoped-query semantic records."""

from __future__ import annotations

import argparse
import json
import tempfile
import sys
import subprocess
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

    # Patch 24.12a retired the Level 2 evidence recipe. The rationale
    # recorded here described that harness as two arms, both on the retired
    # route. It had FIVE, and three of them were backend-neutral (#413): a
    # positive round trip and two compile-fail cases whose OpaqueConstruction
    # and PrivateDeclarationAccess rejections are raised in the typechecker
    # before any backend emits. The retirement was right about the emitter
    # arms and wrong about those three, and nothing on the tree compiled the
    # three fixtures afterwards -- the surviving Level 1 validator checked
    # that witness strings were still present in source, which is not a
    # behaviour test.
    #
    # Patch 24.12b restores the behavioural half in replay_front_end below,
    # from the frozen vectors that already recorded it. The Level 1 contract
    # otherwise still carries this patch's live invariant: it validates the
    # registry authority and its generated review.
    #
    # Asserted in the inverse rather than dropped. A clause that simply
    # stopped mentioning the evidence guard would say nothing about it, and
    # an assertion that says nothing is the inert-field failure this phase
    # keeps finding. These fail if the retired guard comes back.
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1,
            "Patch 21.2 Level 1 contract level drifted")
    require(GUARD_L2 not in levels,
            f"Patch 24.12a retired the Level 2 evidence guard, but it has a "
            f"test level again: {GUARD_L2}")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in justfile,
            "Patch 21.2 Level 1 contract recipe is missing")
    require(f"\n{GUARD_L2}:" not in justfile,
            f"Patch 24.12a retired the Level 2 evidence recipe, but it is "
            f"back in the justfile: {GUARD_L2}")
    require(not (ROOT / "scripts/phase21_inert_scoped_query_records.sh")
            .exists(),
            "Patch 24.12a retired the inert-record harness, but it is back")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Level 1 Patch 21.2 contract")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow,
            "dedicated Patch 21.2 workflow does not own the Level 1 contract")
    require(f"just {GUARD_L2}" not in workflow,
            f"Patch 24.12a retired the Level 2 evidence guard, but the "
            f"dedicated workflow still runs it: {GUARD_L2}")
    # The dedicated workflow is not left half-emptied: removing the evidence
    # job leaves one real job that runs the Level 1 contract, which is where
    # this patch's live invariant is. Asserted so it cannot decay into a
    # workflow that dispatches nothing.
    require(workflow.count("runs-on:") == 1,
            "the dedicated Patch 21.2 workflow no longer has exactly one "
            "job after the Level 2 evidence job was retired")
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


# Patch 24.12b (#413): the behavioural half Patch 24.12a retired with the
# emitter arms. These three fixtures are typechecker cases -- two rejections
# raised before any backend emits, and one positive round trip -- so they were
# never emitter-coupled and should not have gone with the golden loop.
#
# Replayed from the frozen vectors rather than recompiled: the expected
# observation was already captured, so this needs a runner, not new goldens,
# and it executes no C. That is what lets it sit in the Level 1 contract
# instead of reviving a Level 2 evidence recipe.
FRONT_END_REPLAY = (
    ("compiler/typed_query_semantic_records_forge_invalid.gst", "reject",
     b"[OpaqueConstruction]"),
    ("compiler/typed_query_semantic_records_private_constructor_invalid.gst",
     "reject", b"[PrivateDeclarationAccess]"),
    ("compiler/typed_query_semantic_records_test_entry.gst", "exec",
     b"SUCCESS: Phase 21 inert scoped-query semantic records round-tripped"),
)


def replay_front_end() -> int:
    """Assert the two rejections and the positive round trip still hold."""
    replayed = 0
    for vector_id, kind, needle in FRONT_END_REPLAY:
        require((ROOT / vector_id).is_file(),
                f"Patch 21.2 front-end fixture is missing: {vector_id}")
        with tempfile.TemporaryDirectory(prefix="gust-p21-inert-") as raw:
            prefix = Path(raw) / "frozen"
            served = subprocess.run(
                [sys.executable, "scripts/phase24_frozen_oracle.py",
                 "materialize", vector_id, str(prefix), "--kind", kind],
                cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                check=False)
            require(served.returncode == 0,
                    f"the frozen oracle refused {vector_id}: "
                    f"{served.stderr.decode(errors='replace')[:200]}")
            if kind == "reject":
                status = int(Path(f"{prefix}.compile.status")
                             .read_text().strip())
                stdout = Path(f"{prefix}.compile.stdout").read_bytes()
                stderr = Path(f"{prefix}.compile.stderr").read_bytes()
                require(status == 1 and not stderr and needle in stdout,
                        f"Patch 21.2 front-end rejection drifted for "
                        f"{vector_id}")
            else:
                status = int(Path(f"{prefix}.status").read_text().strip())
                stdout = Path(f"{prefix}.stdout").read_bytes()
                require(status == 0 and needle in stdout,
                        f"Patch 21.2 positive round trip drifted for "
                        f"{vector_id}")
        replayed += 1
    require(replayed == len(FRONT_END_REPLAY),
            "Patch 21.2 front-end replay skipped a case; absence is not "
            "success")
    return replayed


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
    # #413: the behavioural half runs inside the Level 1 contract, which PR
    # Fast already owns, so the coverage returns without reviving a Level 2
    # recipe. The count is printed rather than implied -- a replay that
    # silently covered fewer cases would otherwise read as "ok".
    replayed = replay_front_end()
    print(f"{GUARD_L1}: ok ({replayed} front-end cases replayed)")


if __name__ == "__main__":
    main()
