#!/usr/bin/env python3
"""Validate and project Patch 23.12 production/release route evidence."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE23_PRODUCTION_RELEASE_AUDIT.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase23-production-release-audit.yml"
RUNNER = ROOT / "scripts/run-gust-file.sh"
EVIDENCE = ROOT / "scripts/phase23_production_release_audit.sh"
GUARD_L1 = "guard-cranelift-phase23-production-release-audit-contract"
GUARD_L2 = "guard-cranelift-phase23-production-release-audit-evidence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def digest_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def canonical_digest(value: object) -> str:
    return digest_bytes(json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=True,
    ).encode("utf-8"))


def load_opening():
    path = ROOT / "scripts/phase23_mir_to_c_deprecation_opening.py"
    spec = importlib.util.spec_from_file_location("phase23_opening", path)
    require(spec is not None and spec.loader is not None,
            "cannot load the Phase 23 invocation scanner")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def surface(path: str, role: str, markers: tuple[str, ...]) -> dict[str, object]:
    absolute = ROOT / path
    require(absolute.is_file(), f"supported surface is missing: {path}")
    text = absolute.read_text(encoding="utf-8")
    for marker in markers:
        require(marker in text, f"supported surface marker is missing: {path}: {marker}")
    digest = digest_bytes(absolute.read_bytes())
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    if (path == "justfile" and
            "stdlib_guard_transition" in registry.get("phase24_cr15_opening", {})):
        transition_path = ROOT / "scripts/phase24_cr15_stdlib_guard_transition.py"
        spec = importlib.util.spec_from_file_location(
            "phase24_cr15_guard_transition", transition_path)
        require(spec is not None and spec.loader is not None,
                "cannot load the Patch 24.0c guard transition")
        transition = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(transition)
        digest = transition.normalized_owner_file_digest(registry, path, digest)
    return {
        "path": path,
        "role": role,
        "sha256": digest,
        "markers": markers,
    }


def scan() -> dict[str, object]:
    opening = load_opening()
    invocations = opening.scan_invocations()
    explicit_c = [row for row in invocations if row["selection"] == "explicit_c"]
    bootstrap = [row for row in explicit_c if row["path"] == "Makefile"]
    non_bootstrap = [row for row in explicit_c if row["path"] != "Makefile"]
    supported = (
        surface("Makefile", "default_build_package_and_install", (
            ".DEFAULT_GOAL := phase10-native-package",
            "all: phase10-native-package",
            "install: phase10-native-package",
            "install -m 0755 build/phase10-package/bin/gust",
        )),
        surface("README.md", "user_build_run_install_contract", (
            "build/phase10-package/bin/gust program.gst",
            "make install",
            "backend removal is scheduled for",
            "Phase 24. Bootstrap-C retirement is a separate Phase 25 change",
            "There is no automatic fallback",
        )),
        surface("flake.nix", "developer_single_program_entry", (
            'gt-one-gst() {',
            'GUST_RUNNER_ROUTE=cranelift bash scripts/run-gust-file.sh "$1"',
        )),
        surface("justfile", "developer_single_program_commands", (
            'GUST_RUNNER_ROUTE=cranelift bash scripts/run-gust-file.sh "{{file}}"',
        )),
        surface("scripts/run-gust-file.sh", "shared_explicit_route_runner", (
            'RUNNER_ROUTE="${GUST_RUNNER_ROUTE:-mir-to-c}"',
            "make phase10-native-package",
            "./build/phase10-package/bin/gust",
            "--backend cranelift",
            "./gust --backend mir-to-c",
            'NATIVE_OUTPUT="build/${TEST_STEM}_bin"',
            "COMPILING GUST WITH CRANELIFT",
        )),
        surface("scripts/phase22_default_native_package.sh",
                "clean_install_and_relocation_predecessor", (
            'make install DESTDIR="$install_root" PREFIX=/opt/gust',
            "assert_clean_failure",
            "missing-runtime.diagnostic",
        )),
    )
    runner = RUNNER.read_text(encoding="utf-8")
    require(runner.count("--backend mir-to-c") == 1 and
            runner.count("--backend cranelift") == 1,
            "shared runner does not expose exactly one explicit route per backend")
    require("GUST_RUNNER_ROUTE must be 'mir-to-c' or 'cranelift'" in runner,
            "shared runner does not reject an unknown explicit route")
    require(len(bootstrap) == 5,
            "Phase 25 bootstrap explicit-C invocation count drifted")
    return {
        "supported_surface_count": len(supported),
        "supported_surface_manifest_digest": canonical_digest(supported),
        "repository_invocation_count": len(invocations),
        "repository_explicit_c_count": len(explicit_c),
        "phase25_bootstrap_explicit_c_count": len(bootstrap),
        "non_bootstrap_retained_test_surface_count": len(non_bootstrap),
        "supported_production_or_release_explicit_c_count": 0,
        "active_non_bootstrap_live_c_lane_count": 1,
        "active_non_bootstrap_live_c_owner": "phase23_mir_to_c_focused_live",
        "unknown_downstream_count": 0,
    }


def accepted(record: dict, summary: dict[str, object]) -> bool:
    return record.get("audit") == summary and record.get("route_contract") == {
        "default_and_explicit_native": "cranelift",
        "fallback": "forbidden",
        "supported_production_or_release_requires_mir_to_c": False,
        "remaining_live_c_owners": [
            "phase23_mir_to_c_focused_live", "phase25_bootstrap",
        ],
        "historical_and_archived_call_sites":
            "retained_as_nonproduction_evidence_not_supported_routes",
        "explicit_c_availability": "deprecated_and_retained_through_phase23",
    }


def validate_mutations(record: dict, summary: dict[str, object]) -> None:
    require(accepted(record, summary), "registered production/release audit drifted")
    for label, key, value in (
        ("production C dependency", "supported_production_or_release_explicit_c_count", 1),
        ("second live C lane", "active_non_bootstrap_live_c_lane_count", 2),
        ("unknown downstream", "unknown_downstream_count", 1),
        ("missing bootstrap caller", "phase25_bootstrap_explicit_c_count", 4),
        ("same-count supported surface substitution", "supported_surface_manifest_digest", "0" * 64),
    ):
        mutated = {**summary, key: value}
        require(not accepted(record, mutated), f"accepted {label}")
    fallback = copy.deepcopy(record)
    fallback["route_contract"]["fallback"] = "allowed"
    require(not accepted(fallback, summary), "accepted fallback")


def validate() -> tuple[dict, dict[str, object]]:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase23_production_release_audit")
    require(isinstance(record, dict), "Patch 23.12 authority is missing")
    expected = {
        "contract_version": "phase23_production_release_audit_v1",
        "status": "patch23_12_complete",
        "next_patch": "23.13",
        "owner": "cranelift",
        "review_view": REVIEW.relative_to(ROOT).as_posix(),
        "renderer": Path(__file__).relative_to(ROOT).as_posix(),
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")
    require(registry.get("phase23_mir_to_c_archived_corpus", {}).get("status") ==
            "patch23_11_complete", "Patch 23.11 predecessor is not complete")
    require(registry.get("phase23_mir_to_c_focused_live", {}).get(
            "route_contract", {}).get("non_bootstrap_live_lane_count") == 1,
            "focused live-C predecessor drifted")
    summary = scan()
    closure_transition = registry.get("phase23_closure", {}).get(
        "production_audit_transition")
    derivation_transition = registry.get("phase24_cr15_derivation", {}).get(
        "production_audit_transition")
    if closure_transition is None:
        validate_mutations(record, summary)
    else:
        unchanged = [
            "supported_surface_count", "repository_invocation_count",
            "repository_explicit_c_count", "phase25_bootstrap_explicit_c_count",
            "non_bootstrap_retained_test_surface_count",
            "supported_production_or_release_explicit_c_count",
            "active_non_bootstrap_live_c_lane_count",
            "active_non_bootstrap_live_c_owner", "unknown_downstream_count",
        ]
        require(closure_transition.get("contract_version") ==
                "phase23_closure_production_audit_transition_v1" and
                closure_transition.get("status") == "patch23_15_complete" and
                closure_transition.get("authority_base_main") ==
                "8985a3d09b1f119accd12cd952940ef019d6a698" and
                closure_transition.get("previous_audit") == record.get("audit") and
                closure_transition.get("current_audit") ==
                (summary if derivation_transition is None else
                 derivation_transition.get("previous_audit")) and
                closure_transition.get("unchanged_fields") == unchanged and
                closure_transition.get("change_reason") ==
                "closure_status_and_guard_wiring_changed_supported_surface_file_digests_without_changing_routes_or_counts" and
                closure_transition.get("partial_extra_or_substituted_audit") ==
                "rejected",
                "Patch 23.15 production audit transition drifted")
        for field in unchanged:
            require(closure_transition["current_audit"].get(field) ==
                    closure_transition["previous_audit"].get(field),
                    f"Patch 23.15 changed production audit field: {field}")
        effective = copy.deepcopy(record)
        effective["audit"] = closure_transition["current_audit"]
        if derivation_transition is not None:
            require(
                derivation_transition.get("contract_version") ==
                "phase24_cr15_derivation_production_audit_transition_v1" and
                derivation_transition.get("status") == "patch24_0c_complete" and
                derivation_transition.get("authority_base_main") ==
                "c37024afa580d1e03c5ff70150ed0ae7518a9648" and
                derivation_transition.get("previous_audit") ==
                closure_transition["current_audit"] and
                derivation_transition.get("current_audit") == summary and
                derivation_transition.get("unchanged_fields") == unchanged and
                derivation_transition.get("change_reason") ==
                "CR15_derivation_preserved_the_production_audit_through_exact_relay_projection" and
                derivation_transition.get("partial_extra_or_substituted_audit") ==
                "rejected",
                "Patch 24.0c production audit transition drifted")
            for field in unchanged:
                require(derivation_transition["current_audit"].get(field) ==
                        derivation_transition["previous_audit"].get(field),
                        f"Patch 24.0c changed production audit field: {field}")
            effective["audit"] = derivation_transition["current_audit"]
        validate_mutations(effective, summary)
    require(record.get("timelines") == {
        "phase24": "remove_generated_C_backend_and_explicit_C_publication_routes",
        "phase25": "remove_bootstrap_seed_host_C_chain_and_residual_bootstrap_C",
        "repository_wide_C_absence": "not_claimed_or_scheduled_by_phase23",
    }, "Phase 24/25 timeline boundary drifted")
    require(record.get("package_contract") == {
        "artifacts": ["gust", "gust-native-backend", "gust-runtime-package.a"],
        "repository_install_and_relocated_use": "qualified_native",
        "clean_environment": "temporary_DESTDIR_and_relocated_sibling_directory",
        "cleanup": "owned_temporary_directory_removed",
        "failure_diagnostics": ["missing_worker", "missing_runtime_archive"],
        "no_fallback": "native_succeeds_with_mir_to_c_test_poisoned",
    }, "package qualification contract drifted")
    phase22_migration = record.get("phase22_closed_inventory_migration", {})
    require(phase22_migration.get("status") ==
            "exact_phase23_dual_route_projected_to_phase22_predecessor" and
            phase22_migration.get("owning_patch") == "23.12" and
            phase22_migration.get("path") == "scripts/run-gust-file.sh" and
            phase22_migration.get("previous_row", {}).get("selection") == "explicit_c" and
            phase22_migration.get("current_historical_row", {}).get("selection") ==
            "explicit_c" and
            phase22_migration.get("added_native_row", {}).get("selection") ==
            "explicit_cranelift" and phase22_migration.get("falsifier") ==
            "missing_partial_extra_or_same_count_command_substitution_is_rejected",
            "Phase 22 closed-inventory migration authority drifted")
    require(record.get("budgets") == {
        "workflow_timeout_minutes": 45,
        "evidence_elapsed_ms": 300000,
    }, "audit budgets drifted")
    require(record.get("boundary") == {
        "changes_accepted_Gust_program_meaning": False,
        "adds_or_changes_MIR_operations": False,
        "changes_ABI_layout_runtime_symbols_target_or_linker": False,
        "changes_backend_route_default_or_fallback": False,
        "changes_bootstrap_route_or_seed": False,
        "edits_stdlib_or_CR15": False,
        "begins_patch23_13": False,
    }, "Patch 23.12 boundary widened")
    task = TASK.read_text(encoding="utf-8")
    for patch in ("23.10", "23.11", "23.12"):
        require(re.search(rf"^- \[x\] Patch {re.escape(patch)} .* — DONE$", task, re.M)
                is not None, f"mandatory Patch {patch} status is not DONE")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "guard levels drifted")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in just and f"{GUARD_L2}:" in just,
            "just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the audit contract")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    for token in (f"just {GUARD_L1}", f"just {GUARD_L2}",
                  "make phase10-native-package"):
        require(workflow.count(token) == 1,
                f"dedicated workflow ownership drifted: {token}")
    for marker in ("temporary DESTDIR", "GUST_TEST_MIR_TO_C_UNAVAILABLE=1",
                   "missing-worker", "missing-runtime"):
        require(marker in EVIDENCE.read_text(encoding="utf-8"),
                f"focused evidence marker is missing: {marker}")
    require(REVIEW.is_file() and REVIEW.read_text(encoding="utf-8") ==
            render(record), "generated audit review is stale; run project")
    return record, summary


def render(record: dict) -> str:
    audit = record["audit"]
    lines = [
        "# Cranelift Phase 23.12 — Production, Release, Package, and Downstream Audit",
        "",
        "Generated from the canonical feature registry. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Supported surfaces: `{audit['supported_surface_count']}`",
        f"- Supported surface manifest: `{audit['supported_surface_manifest_digest']}`",
        f"- Repository compiler invocations: `{audit['repository_invocation_count']}`",
        f"- Retained explicit-C call sites: `{audit['repository_explicit_c_count']}`",
        f"- Phase 25 bootstrap explicit-C call sites: `{audit['phase25_bootstrap_explicit_c_count']}`",
        f"- Non-production historical/test call sites: `{audit['non_bootstrap_retained_test_surface_count']}`",
        f"- Supported production/release explicit-C calls: `{audit['supported_production_or_release_explicit_c_count']}`",
        f"- Active non-bootstrap live-C lanes: `{audit['active_non_bootstrap_live_c_lane_count']}`",
        f"- Active live-C owner: `{audit['active_non_bootstrap_live_c_owner']}`",
        f"- Unknown registered downstream consumers: `{audit['unknown_downstream_count']}`",
        "",
        "The remaining historical and archived call sites are retained evidence, not",
        "supported production or release routes. The only live non-bootstrap C owner",
        "is the Patch 23.10 focused oracle lane; bootstrap remains owned by Phase 25.",
        "Explicit C remains deprecated and available through Phase 23. Phase 24 removes",
        "the backend route; Phase 25 separately removes bootstrap C. Repository-wide C",
        "absence is not claimed.",
        "",
    ]
    return "\n".join(lines)


def evidence() -> None:
    result = subprocess.run(
        ["bash", str(EVIDENCE)], cwd=ROOT, check=False,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        timeout=300,
    )
    require(result.returncode == 0,
            f"package/release evidence failed:\n{result.stdout}{result.stderr}")
    require("phase23_production_release_audit: evidence ok" in result.stdout,
            "package/release evidence completion marker is missing")
    print("phase23_production_release_audit: evidence ok")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review", "evidence"))
    args = parser.parse_args()
    if args.command == "evidence":
        validate()
        evidence()
        return
    record, _ = validate() if args.command != "project" else (
        json.loads(REGISTRY.read_text(encoding="utf-8"))["phase23_production_release_audit"], {}
    )
    rendered = render(record)
    if args.command == "project":
        REVIEW.write_text(rendered, encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and REVIEW.read_text(encoding="utf-8") == rendered,
                "generated audit review is stale")
    print(f"{GUARD_L1}: {args.command} ok")


if __name__ == "__main__":
    main()
