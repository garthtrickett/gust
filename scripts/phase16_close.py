#!/usr/bin/env python3
"""Validate and render the lightweight Patch 16.15 semantic closure."""

from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase16-close"
CONTRACT = ROOT / "tests/cranelift/phase16_close_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase16_close_review.txt"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"

REQUIRED_AUTHORITIES = {
    "phase15_closure",
    "compiler/mir_function_abi_authority.gst",
    "compiler/mir_function_call.gst",
    "phase16_abi_composition_authority",
    "phase16_deferred_residue_audit",
}

REQUIRED_LEVEL1 = {
    "guard-cranelift-registry-schema",
    "guard-cranelift-registry-projection",
    "guard-cranelift-ci-family-projection",
    "guard-cranelift-route-architecture-contract",
    "guard-cranelift-manifest-architecture-contract",
    "guard-cranelift-phase14-layout-authority-contract",
    "guard-cranelift-phase15-resource-authority-contract",
    "guard-cranelift-phase16-opening-contract",
    "guard-cranelift-phase16-abi-authority-contract",
    "guard-cranelift-phase16-call-mir-contract",
    "guard-cranelift-phase16-aggregate-parameter-contract",
    "guard-cranelift-phase16-aggregate-return-contract",
    "guard-cranelift-phase16-direct-call-agreement-contract",
    "guard-cranelift-phase16-typed-indirect-call-contract",
    "guard-cranelift-phase16-fat-pointer-abi-contract",
    "guard-cranelift-phase16-unsized-abi-contract",
    "guard-cranelift-phase16-dynamic-stack-contract",
    "guard-cranelift-phase16-resource-aggregate-abi-contract",
    "guard-cranelift-phase16-cross-module-abi-contract",
    "guard-cranelift-phase16-abi-metadata-contract",
    "guard-cranelift-phase16-composition-contract",
    "guard-cranelift-phase16-deferred-residue-audit",
    "guard-cranelift-phase16-close",
}

REQUIRED_LEVEL2 = {
    "guard-cranelift-phase16-call-mir-parity",
    "guard-cranelift-phase16-aggregate-parameter-parity",
    "guard-cranelift-phase16-aggregate-return-parity",
    "guard-cranelift-phase16-direct-call-agreement-parity",
    "guard-cranelift-phase16-typed-indirect-call-parity",
    "guard-cranelift-phase16-fat-pointer-abi-parity",
    "guard-cranelift-phase16-unsized-abi-parity",
    "guard-cranelift-phase16-dynamic-stack-parity",
    "guard-cranelift-phase16-resource-aggregate-abi-parity",
    "guard-cranelift-phase16-cross-module-abi-parity",
    "guard-cranelift-phase16-composition-differential",
}

REQUIRED_ASSERTIONS = {
    "opening_dispositions_complete",
    "generic_canonical_mir_route",
    "compiler_owned_function_abi_identity",
    "compiler_parameter_result_classification_placement",
    "compiler_explicit_hidden_result",
    "typed_indirect_complete_signature",
    "compiler_dynamic_frame_plan",
    "shared_backend_abi_data",
    "phase15_resource_transfer_decisions",
    "runtime_compiler_identities_descriptors",
    "diagnostics_share_abi_decisions",
    "narrow_owned_target_scoped_deferrals",
    "no_exact_recognizers",
    "no_backend_aggregate_classifier",
    "no_backend_hidden_result_planner",
    "no_backend_resource_transfer_authority",
    "generated_c_not_semantic_authority",
    "cranelift_signature_blocks_not_semantic_authority",
    "explicit_cranelift_no_fallback",
    "early_deferral_before_artifacts",
    "mir_to_c_default_oracle",
    "default_explicit_mir_to_c_equivalent",
    "worker_request_isolation",
    "phase9g_artifact_ownership",
    "registry_derived_totals_classes_targets_families",
    "generated_views_current",
    "registry_derived_ci_families",
    "no_raw_hash_contract",
    "no_exact_matrix_total_correctness",
    "historical_full_sole_complete_evidence_owner",
    "representative_evidence_all_declared_targets",
    "reject_caller_callee_disagreement",
    "hidden_result_exactly_once",
    "resource_transfer_single_live_owner",
    "old_owner_cannot_destroy_moved_resource",
}


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD}: {message}")


def rows() -> list[dict[str, str]]:
    with CONTRACT.open(newline="") as handle:
        values = list(csv.DictReader(handle, delimiter="\t"))
    if not values or set(values[0]) != {"kind", "requirement", "evidence", "level"}:
        fail("contract schema mismatch")
    if any(row["level"] != "1" or not row["evidence"] for row in values):
        fail("closure rows must be Level 1")
    return values


def render(values: list[dict[str, str]]) -> str:
    return "Patch 16.15 — Phase 16 Closure\n\n" + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n"
        for row in values
    )


def require_token(path: Path, token: str) -> None:
    if not path.is_file() or token not in path.read_text():
        fail(f"missing closure evidence token {token} in {path.relative_to(ROOT)}")


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    closure = registry.get("phase16_closure")
    if not isinstance(closure, dict) or closure.get("version") != "phase16_closure_v1":
        fail("semantic closure authority missing")
    if closure.get("status") != "phase16_closed_function_abi_and_aggregate_call_semantics":
        fail("semantic closure status missing")
    if set(closure.get("required_authorities", [])) != REQUIRED_AUTHORITIES:
        fail("required authority coverage drifted")
    expected_counts = {
        "opening_entry_count": 13,
        "migrated_entry_count": 13,
        "excluded_item_count": 0,
        "narrow_deferred_row_count": 19,
    }
    if any(closure.get(key) != value for key, value in expected_counts.items()):
        fail("closure totals drifted")
    if set(closure.get("semantic_assertions", [])) != REQUIRED_ASSERTIONS:
        fail("closure semantic assertion inventory drifted")

    audit = registry.get("phase16_deferred_residue_audit", {})
    opening = registry.get("opening_snapshots", {}).get("phase16", {}).get("entries", [])
    dispositions = audit.get("opening_dispositions", [])
    if [row.get("id") for row in dispositions] != [row.get("id") for row in opening]:
        fail("opening disposition closure incomplete")
    if any(row.get("disposition") != "migrated" for row in dispositions):
        fail("not every selected opening row migrated")
    deferred = audit.get("narrow_deferred_rows", [])
    if len(deferred) != 19 or audit.get("excluded_items") != []:
        fail("residue closure incomplete")
    if any(
        not row.get("capability_owner")
        or not row.get("diagnostic_owner")
        or not row.get("source_phase16_row_ids")
        or row.get("current_failure_stage") != "before_driver_discovery"
        or row.get("target_applicability") != "all_declared_host_targets_from_phase14_target_authority"
        for row in deferred
    ):
        fail("deferred ABI residue is not narrow, owned, target-scoped, and early")

    composition = registry.get("phase16_abi_composition_authority", {})
    migrated_ids = [row.get("id") for row in composition.get("migrated_entries", [])]
    composition_owner = composition.get("composition_case", {}).get("owner_entry_id")
    if migrated_ids + [composition_owner] != [row.get("id") for row in opening]:
        fail("registry differential wiring does not cover every opening row")
    if composition.get("target_applicability") != "all_declared_host_targets_from_phase14_target_authority":
        fail("representative ABI evidence target coverage drifted")

    for authority in REQUIRED_AUTHORITIES:
        if authority.endswith(".gst"):
            path = ROOT / authority
            if not path.is_file() or path.is_symlink():
                fail(f"missing compiler authority {authority}")
        elif authority not in registry:
            fail(f"missing registry authority {authority}")

    evidence_tokens = [
        (ROOT / "compiler/mir_function_abi_authority.gst", "sole semantic owner for function ABI identity"),
        (ROOT / "compiler/mir_function_abi_authority.gst", "parameter/result placement"),
        (ROOT / "compiler/mir_function_abi_authority.gst", "MIR-to-C"),
        (ROOT / "compiler/mir_aggregate_parameter_abi.gst", "aggregate_parameter_caller_callee_disagreement"),
        (ROOT / "compiler/mir_aggregate_result_abi.gst", "aggregate_result_missing_hidden_storage"),
        (ROOT / "compiler/mir_dynamic_stack.gst", "compiler_owned_checked_dynamic_frame_lifetime_and_restore_plan"),
        (ROOT / "compiler/mir_resource_aggregate_abi.gst", "validated_transfer_cancels_source_cleanup_creates_destination_cleanup_one_live_owner"),
        (ROOT / "compiler/mir_resource_aggregate_abi.gst", "resource_aggregate_stale_source_cleanup"),
        (ROOT / "compiler/CRANELIFT_PHASE16_OPENING.md", "MIR-to-C remains the default differential oracle"),
        (ROOT / "compiler/CRANELIFT_EXPERIMENT_MANIFEST.md", "explicit_cranelift_success_deferral_or_failure_terminates_without_MIR-to-C_codegen"),
        (ROOT / "justfile", "guard-cranelift-phase9g-close"),
        (ROOT / "justfile", "guard-cranelift-route-architecture-contract"),
    ]
    for path, token in evidence_tokens:
        require_token(path, token)

    task = (ROOT / "TASK.md").read_text()
    done = {
        int(match.group(1))
        for match in re.finditer(r"^- \[x\] Patch 16\.(\d+).+— DONE$", task, re.MULTILINE)
    }
    if done != set(range(16)):
        fail(f"TASK.md Phase 16 status incomplete: {sorted(done)}")

    levels = json.loads((ROOT / "scripts/cranelift_test_levels.json").read_text())["guards"]
    if any(levels.get(guard) != 1 for guard in REQUIRED_LEVEL1):
        fail("Level 1 closure mapping incomplete")
    if any(levels.get(guard) != 2 for guard in REQUIRED_LEVEL2):
        fail("Level 2 focused ABI mapping incomplete")
    if levels.get("guard-cranelift-phase16-complete-abi-evidence") != 3:
        fail("complete ABI evidence is not Level 3")

    historical = (ROOT / ".github/workflows/cranelift-historical-full.yml").read_text()
    if historical.count("just guard-cranelift-phase16-complete-abi-evidence") != 1:
        fail("Historical Full does not solely own complete ABI evidence")
    if "workflow_dispatch:" not in historical:
        fail("Historical Full is not separately runnable")

    pr_fast = (ROOT / ".github/workflows/pr-fast.yml").read_text()
    if pr_fast.count("run: just guard-cranelift-phase16-close") != 1:
        fail("PR Fast must invoke the Phase 16 closure guard exactly once")
    if "run: just guard-cranelift-phase16-deferred-residue-audit" in pr_fast:
        fail("PR Fast still directly invokes the superseded Phase 16.14 owner")
    if re.search(r"(?m)^\s+- phase16-close\s*$", pr_fast) or "matrix.phase16" in pr_fast:
        fail("Phase 16 closure must not create a matrix family")

    justfile = (ROOT / "justfile").read_text()
    start = justfile.find("guard-cranelift-phase16-close:")
    end = justfile.find("\nguard-cranelift-", start + 1)
    if start < 0:
        fail("closure recipe missing")
    body = justfile[start:end if end >= 0 else None]
    forbidden_replay = (
        "phase16-composition-differential",
        "phase16-complete-abi-evidence",
        "guard-cranelift-historical-full",
        "guard-cranelift-differential-family",
        "phase16_abi_composition_parity.sh",
        "cargo ",
        "make ",
        "./gust",
    )
    if any(token in body for token in forbidden_replay):
        fail("closure guard replays forbidden Level 2, Level 3, native, or build evidence")

    policies = {
        "oracle_policy": "mir_to_c_remains_default_differential_oracle",
        "fallback_policy": "explicit_cranelift_no_fallback",
        "artifact_policy": "phase9g_retains_object_link_cleanup_and_atomic_publication_ownership",
        "worker_policy": "isolated_worker_consumes_only_validated_request_canonical_mir_layout_resource_and_abi_metadata",
        "failure_policy": "invalid_or_deferred_stops_before_driver_and_artifact_access_with_output_preserved",
        "test_level_policy": "level1_contracts_level2_registry_families_level3_historical_full_only",
        "scope_policy": "declared_phase16_inventory_only_no_complete_platform_ffi_dispatch_unsized_runtime_or_production_claim",
    }
    if any(closure.get(key) != value for key, value in policies.items()):
        fail("closure policy drifted")

    values = rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(values):
        fail("generated closure review is stale; run --write")
    print(f"{GUARD}: ok (opening=13 migrated=13 deferred=19 excluded=0, Level 1)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write:
        REVIEW.write_text(render(rows()))
    check()


if __name__ == "__main__":
    main()
