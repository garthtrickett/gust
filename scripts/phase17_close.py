#!/usr/bin/env python3
"""Validate and render the Patch 17.16 Phase 17 semantic closure."""

from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase17-close"
CONTRACT = ROOT / "tests/cranelift/phase17_close_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase17_close_review.txt"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
SCHEMA = ROOT / "scripts/cranelift_feature_registry.schema.json"

REQUIRED_LEVEL1 = {
    "guard-cranelift-registry-schema",
    "guard-cranelift-registry-projection",
    "guard-cranelift-ci-family-projection",
    "guard-cranelift-route-architecture-contract",
    "guard-cranelift-manifest-architecture-contract",
    "guard-cranelift-phase14-layout-authority-contract",
    "guard-cranelift-phase15-resource-authority-contract",
    "guard-cranelift-phase16-abi-authority-contract",
    "guard-cranelift-phase17-opening-contract",
    "guard-cranelift-phase17-runtime-authority-contract",
    "guard-cranelift-phase17-runtime-symbol-version-contract",
    "guard-cranelift-phase17-runtime-requirement-contract",
    "guard-cranelift-phase17-runtime-package-contract",
    "guard-cranelift-phase17-runtime-import-contract",
    "guard-cranelift-phase17-rust-runtime-contract",
    "guard-cranelift-phase17-retained-c-runtime-contract",
    "guard-cranelift-phase17-gust-runtime-contract",
    "guard-cranelift-phase17-shim-elimination-contract",
    "guard-cranelift-phase17-memory-runtime-contract",
    "guard-cranelift-phase17-io-runtime-contract",
    "guard-cranelift-phase17-thread-runtime-contract",
    "guard-cranelift-phase17-availability-contract",
    "guard-cranelift-phase17-composition-contract",
    "guard-cranelift-phase17-deferred-residue-audit",
    "guard-cranelift-phase17-close",
}

REQUIRED_LEVEL2 = {
    "guard-cranelift-phase17-runtime-import-parity",
    "guard-cranelift-phase17-rust-runtime-parity",
    "guard-cranelift-phase17-retained-c-runtime-parity",
    "guard-cranelift-phase17-gust-runtime-parity",
    "guard-cranelift-phase17-shim-elimination-parity",
    "guard-cranelift-phase17-memory-runtime-parity",
    "guard-cranelift-phase17-io-runtime-parity",
    "guard-cranelift-phase17-thread-runtime-parity",
    "guard-cranelift-phase17-availability-parity",
    "guard-cranelift-phase17-composition-differential",
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
    return "Patch 17.16 — Phase 17 Closure\n\n" + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n"
        for row in values
    )


def require_token(path: Path, token: str) -> None:
    if not path.is_file() or token not in path.read_text():
        fail(f"missing closure evidence token {token} in {path.relative_to(ROOT)}")


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    closure = registry.get("phase17_closure")
    if not isinstance(closure, dict) or closure.get("version") != "phase17_closure_v1":
        fail("semantic closure authority missing")
    if closure.get("status") != "phase17_closed_native_runtime_boundary":
        fail("semantic closure status missing")

    # The schema declares the frozen closure claim and the minimum policy
    # inventories, but the registry is not machine-validated against it, so the
    # declaration is enforced here. Otherwise the const would be documentation.
    schema = json.loads(SCHEMA.read_text())
    declared = schema.get("$defs", {}).get("phase17_closure", {})
    declared_properties = declared.get("properties", {})
    if not declared_properties:
        fail("schema does not declare the Phase 17 closure")
    if set(declared.get("required", [])) - set(closure):
        fail("closure is missing schema-required fields")
    pinned = declared_properties.get("closure_wording", {}).get("const")
    if not pinned:
        fail("schema does not pin the closure wording")
    if closure.get("closure_wording") != pinned:
        fail("closure wording drifted from the pinned schema claim")
    for field in ("non_claims", "forbidden_replays"):
        minimum = declared_properties.get(field, {}).get("minItems")
        if not minimum:
            fail(f"schema does not declare a floor for {field}")
        if len(closure.get(field, [])) < minimum:
            fail(f"{field} fell below its declared floor of {minimum}")

    audit = registry.get("phase17_deferred_residue_audit", {})
    snapshot = registry.get("opening_snapshots", {}).get("phase17", {})
    helpers = audit.get("helper_dispositions", [])

    # Every total is derived from the registry. An exact count is never a
    # correctness claim on its own; it must agree with what the registry says.
    derived = {
        "opening_entry_count": len(snapshot.get("entries", [])),
        "migrated_entry_count": sum(
            row.get("disposition") == "migrated" for row in audit.get("opening_dispositions", [])
        ),
        "inventoried_helper_count": len(snapshot.get("helper_inventory", [])),
        "migrated_helper_count": sum(r.get("disposition") == "migrated" for r in helpers),
        "excluded_helper_count": sum(r.get("disposition") == "excluded" for r in helpers),
        "narrowly_deferred_helper_count": sum(
            r.get("disposition") == "narrowly_deferred" for r in helpers
        ),
        "retained_component_count": len(audit.get("component_dispositions", [])),
        "narrow_deferred_row_count": len(audit.get("narrow_deferred_rows", [])),
    }
    for key, value in derived.items():
        if closure.get(key) != value:
            fail(f"closure total {key} is not registry-derived")
    if derived["opening_entry_count"] != derived["migrated_entry_count"]:
        fail("not every Phase 17 opening row reached a migrated disposition")
    if len(helpers) != derived["inventoried_helper_count"]:
        fail("helper disposition coverage is incomplete")
    if sum(
        derived[key]
        for key in ("migrated_helper_count", "excluded_helper_count", "narrowly_deferred_helper_count")
    ) != derived["inventoried_helper_count"]:
        fail("helper dispositions do not account for every inventoried helper")

    for authority in closure.get("required_authorities", []):
        if authority.endswith(".gst"):
            path = ROOT / authority
            if not path.is_file() or path.is_symlink():
                fail(f"missing compiler authority {authority}")
        elif authority not in registry:
            fail(f"missing registry authority {authority}")

    # The closure wording is pinned by the schema, so it cannot drift. What can
    # drift is the prose projected into the generated view, which is what a
    # reader actually sees, so the registry-owned non-claims are enforced there.
    wording = closure.get("closure_wording", "").lower()
    for required in ("declared phase 17", "without generated c shims", "future-phase deferrals"):
        if required not in wording:
            fail(f"closure wording is missing its scope limit: {required}")
    non_claims = closure.get("non_claims", [])
    if not non_claims:
        fail("closure non-claims inventory is empty")
    projected = (ROOT / "docs/CRANELIFT_FEATURE_REGISTRY.md").read_text().lower()
    section = projected[projected.index("## phase 17 closure"):] if "## phase 17 closure" in projected else ""
    if not section:
        fail("generated view is missing the Phase 17 closure section")
    # The view renders the non-claims from the registry, so the check is exact
    # presence rather than prose analysis. Scanning prose for claim-like wording
    # cannot separate a claim from its own disclaimer.
    for claim in non_claims:
        if claim not in section:
            fail(f"generated Phase 17 closure view omits non-claim: {claim}")

    evidence_tokens = [
        (ROOT / "compiler/mir_runtime_boundary_authority.gst", "MirRuntimeCompositionCase"),
        (ROOT / "compiler/mir_runtime_boundary_authority.gst", "MirRuntimeAvailabilityDecision"),
        (ROOT / "compiler/mir_runtime_boundary_authority.gst", "MirRuntimeShimBan"),
        (ROOT / "justfile", "guard-cranelift-phase9g-close"),
        (ROOT / "justfile", "guard-cranelift-route-architecture-contract"),
        (ROOT / "scripts/install-native-deps-ci.sh", "NATIVE_DEPS_CI_MAX_ATTEMPTS"),
    ]
    for path, token in evidence_tokens:
        require_token(path, token)

    task = (ROOT / "TASK.md").read_text()
    done = {
        int(match.group(1))
        for match in re.finditer(r"^- \[x\] Patch 17\.(\d+).+— DONE$", task, re.MULTILINE)
    }
    if done != set(range(17)):
        fail(f"TASK.md Phase 17 status incomplete: {sorted(done)}")

    levels = json.loads((ROOT / "scripts/cranelift_test_levels.json").read_text())["guards"]
    if any(levels.get(guard) != 1 for guard in REQUIRED_LEVEL1):
        fail("Level 1 closure mapping incomplete")
    if any(levels.get(guard) != 2 for guard in REQUIRED_LEVEL2):
        fail("Level 2 focused runtime mapping incomplete")
    if levels.get("guard-cranelift-phase17-complete-runtime-evidence") != 3:
        fail("complete runtime evidence is not Level 3")

    historical = (ROOT / ".github/workflows/cranelift-historical-full.yml").read_text()
    if historical.count("just guard-cranelift-phase17-complete-runtime-evidence") != 1:
        fail("Historical Full does not solely own complete runtime evidence")
    if "workflow_dispatch:" not in historical:
        fail("Historical Full is not separately runnable")

    pr_fast = (ROOT / ".github/workflows/pr-fast.yml").read_text()
    if pr_fast.count("run: just guard-cranelift-phase17-close") != 1:
        fail("PR Fast must invoke the Phase 17 closure guard exactly once")
    if "run: just guard-cranelift-phase17-deferred-residue-audit" in pr_fast:
        fail("PR Fast still directly invokes the superseded Phase 17.15 owner")
    if re.search(r"(?m)^\s+- phase17-close\s*$", pr_fast) or "matrix.phase17" in pr_fast:
        fail("Phase 17 closure must not create a matrix family")

    justfile = (ROOT / "justfile").read_text()
    start = justfile.find("guard-cranelift-phase17-close:")
    if start < 0:
        fail("closure recipe missing")
    end = justfile.find("\nguard-cranelift-", start + 1)
    body = justfile[start:end if end >= 0 else None]
    forbidden_replay = closure.get("forbidden_replays", [])
    if not forbidden_replay:
        fail("closure forbidden-replay inventory is empty")
    if any(token in body for token in forbidden_replay):
        fail("closure guard replays forbidden Level 2, Level 3, native, or build evidence")

    policies = {
        "oracle_policy": "mir_to_c_remains_default_differential_oracle",
        "fallback_policy": "explicit_cranelift_no_fallback",
        "artifact_policy": "phase9g_retains_object_link_cleanup_and_atomic_publication_ownership",
        "worker_policy": "isolated_worker_consumes_only_validated_request_canonical_mir_layout_resource_abi_and_runtime_metadata",
        "failure_policy": "invalid_or_deferred_stops_before_driver_and_artifact_access_with_output_preserved",
        "availability_policy": "missing_or_incompatible_runtime_package_stops_before_linker_invocation_and_output_replacement",
        "test_level_policy": "level1_contracts_level2_registry_families_level3_historical_full_only",
        "scope_policy": "declared_phase17_inventory_only_no_complete_runtime_rewrite_c_removal_ffi_allocation_concurrency_platform_or_production_claim",
    }
    if any(closure.get(key) != value for key, value in policies.items()):
        fail("closure policy drifted")

    values = rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(values):
        fail("generated closure review is stale; run --write")
    print(
        f"{GUARD}: ok (opening={derived['opening_entry_count']} "
        f"helpers={derived['inventoried_helper_count']} "
        f"migrated={derived['migrated_helper_count']} "
        f"excluded={derived['excluded_helper_count']} "
        f"deferred={derived['narrowly_deferred_helper_count']} "
        f"components={derived['retained_component_count']}, Level 1)"
    )


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
