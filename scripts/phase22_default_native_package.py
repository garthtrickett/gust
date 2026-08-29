#!/usr/bin/env python3
"""Validate and project Patch 22.4 default-native package qualification."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE22_DEFAULT_NATIVE_PACKAGE.md"
MAKEFILE = ROOT / "Makefile"
SOURCE_ROUTE = ROOT / "compiler/mir_native_backend_source_route.gst"
EVIDENCE = ROOT / "scripts/phase22_default_native_package.sh"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase22-default-native-package.yml"
GUARD_L1 = "guard-cranelift-phase22-default-native-package-contract"
GUARD_L2 = "guard-cranelift-phase22-default-native-package-evidence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase22_default_native_package")
    require(isinstance(record, dict), "Patch 22.4 authority is missing")
    require(record.get("contract_version") == "phase22_default_native_package_v1",
            "contract version drifted")
    require(record.get("status") == "qualification_complete" and
            record.get("next_action") == "patch22_6_default_route_flip",
            "status or next action drifted")
    require(record.get("observed_main_sha") ==
            "db4b58bdd78dde41226f9a1e110d555a3c7f5d5d",
            "observed main drifted")
    require(record.get("predecessor_authority") ==
            registry.get("phase22_native_implicit_output", {}).get("contract_version") ==
            "phase22_native_implicit_output_v1",
            "predecessor authority drifted")
    require(registry.get("phase22_native_implicit_output", {}).get("status") ==
            "implementation_complete" and
            registry.get("phase22_explicit_c_migration", {}).get("status") ==
            "complete_post_relay",
            "post-relay predecessor status drifted")
    require(registry.get("phase17_runtime_package_authority", {}).get("version") ==
            "phase17_runtime_package_authority_v1",
            "Phase 17 runtime-package authority drifted")
    require(registry.get("phase18_target_package_selection", {}).get("version") ==
            "phase18_target_package_selection_v1",
            "Phase 18 target-package authority drifted")

    package = record.get("package_contract", {})
    require(package == {
        "build_target": "make_phase10_native_package",
        "install_target": "make_install_DESTDIR_PREFIX",
        "artifacts": [
            {"name": "gust", "mode": "0755", "role": "self_hosted_compiler"},
            {"name": "gust-native-backend", "mode": "0755",
             "role": "executable_relative_native_worker"},
            {"name": "gust-runtime-package.a", "mode": "0644",
             "role": "worker_relative_retained_runtime_archive"},
        ],
        "worker_discovery":
            "absolute_environment_override_or_executable_relative_sibling_only",
        "runtime_discovery": "worker_relative_sibling_only",
        "path_search": "forbidden",
        "auto_build_download_or_fallback": "forbidden",
        "relocation_unit": "three_artifact_sibling_directory",
        "directory_creation": "install_target_creates_only_requested_prefix_parent",
    }, "package contract drifted")
    qualification = record.get("qualification", {})
    require(qualification.get("compiler_default") == "mir_to_c_unchanged" and
            qualification.get("default_candidate_route") ==
            "explicit_cranelift_with_implicit_output" and
            qualification.get("ambient_worker_override") == "unset" and
            qualification.get("repository_package") == "qualified" and
            qualification.get("clean_temporary_prefix_install") == "qualified" and
            qualification.get("relocated_install") == "qualified" and
            qualification.get("explicit_c_without_native_components") ==
            "byte_identical_and_usable" and
            qualification.get("failure_cases") == [
                "missing_sibling_worker", "missing_runtime_archive",
                "incompatible_sibling_worker",
            ] and
            qualification.get("failure_output_policy") ==
            "existing_output_preserved_and_owned_intermediates_removed" and
            qualification.get("oracle") == "explicit_mir_to_c",
            "qualification contract drifted")
    require(qualification.get("selected_native_cohort") == [
        {"source": "compiler/phase10_scalar_return_source.gst",
         "expected_exit": 7, "requires_runtime_archive": False},
        {"source": "compiler/phase20_component_allocation_source.gst",
         "expected_exit": 0, "requires_runtime_archive": True},
    ], "selected native cohort drifted")

    makefile = MAKEFILE.read_text(encoding="utf-8")
    for marker in (
        "phase10-native-package: gust build/gust-native-backend $(PHASE21_RUNTIME_PACKAGE)",
        'install -m 0755 gust build/phase10-package/.bin.tmp/gust',
        'install -m 0755 build/gust-native-backend build/phase10-package/.bin.tmp/gust-native-backend',
        'install -m 0644 $(PHASE21_RUNTIME_PACKAGE) build/phase10-package/.bin.tmp/gust-runtime-package.a',
        "install: phase10-native-package",
        'install -d "$(DESTDIR)$(PREFIX)/bin"',
    ):
        require(marker in makefile, f"package/install marker is missing: {marker}")
    source_route = SOURCE_ROUTE.read_text(encoding="utf-8")
    for marker in (
        'os.GetEnv(\n        ctx,\n        "GUST_NATIVE_BACKEND_DRIVER"',
        "os.ExecutablePath(ctx)",
        '"gust-native-backend"',
        "os.PathDir(ctx, discovery.path)",
        '"gust-runtime-package.a"',
    ):
        require(marker in source_route, f"executable-relative discovery marker is missing: {marker}")
    require("PATH" not in source_route and "download" not in source_route.lower() and
            "cargo build" not in source_route,
            "source route gained PATH search, download, or auto-build behavior")

    evidence = EVIDENCE.read_text(encoding="utf-8")
    for marker in (
        'env -u GUST_NATIVE_BACKEND_DRIVER',
        'make install DESTDIR="$install_root" PREFIX=/opt/gust',
        'PATH="$installed_bin:$PATH"',
        "missing-runtime.diagnostic",
        "incompatible-worker.diagnostic",
        "assert_clean_failure",
        '"$missing_bin/gust" --backend c',
    ):
        require(marker in evidence, f"focused evidence marker is missing: {marker}")

    task = TASK.read_text(encoding="utf-8")
    for row in (
        "- [x] Patch 22.2 — Explicit C Route and No-op Consumer Migration — DONE",
        "- [x] Patch 22.2b — Post-Relay Prerequisite Reconciliation — DONE",
        "- [x] Patch 22.3 — Native Implicit-Output Contract — DONE",
        "- [x] Patch 22.4 — Default-Native Package and Install Qualification — DONE",
        "- [ ] Patch 22.6 — Cranelift Default Route Flip",
    ):
        require(row in task, "post-relay roadmap boundary drifted")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "guard levels drifted")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in just and f"{GUARD_L2}:" in just,
            "just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the contract")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow and
            "make phase10-native-package" in workflow,
            "dedicated workflow does not own package build and both guards")
    require(record.get("boundary") and
            all(value is False for value in record["boundary"].values()),
            "Patch 22.4 widened beyond its no-change qualification boundary")
    return record


def render(record: dict) -> str:
    package = record["package_contract"]
    qualification = record["qualification"]
    lines = [
        "# Cranelift Phase 22.4 — Default-Native Package and Install Qualification",
        "",
        "Generated from `scripts/cranelift_feature_registry.json`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next action: `{record['next_action']}`",
        f"- Observed main: `{record['observed_main_sha']}`",
        f"- Predecessor: `{record['predecessor_authority']}`",
        "",
        "## Package",
        "",
    ]
    lines += [
        f"- `{row['name']}` — mode `{row['mode']}` — `{row['role']}`"
        for row in package["artifacts"]
    ]
    lines += [
        f"- Worker discovery: `{package['worker_discovery']}`",
        f"- Runtime discovery: `{package['runtime_discovery']}`",
        f"- PATH search: `{package['path_search']}`",
        f"- Auto-build/download/fallback: `{package['auto_build_download_or_fallback']}`",
        f"- Relocation unit: `{package['relocation_unit']}`",
        "",
        "## Qualification",
        "",
        f"- Compiler default: `{qualification['compiler_default']}`",
        f"- Default candidate: `{qualification['default_candidate_route']}`",
        f"- Repository package: `{qualification['repository_package']}`",
        f"- Clean temporary-prefix install: `{qualification['clean_temporary_prefix_install']}`",
        f"- Relocated install: `{qualification['relocated_install']}`",
        "- Selected native cohort:",
    ]
    lines += [
        f"  - `{row['source']}` — exit `{row['expected_exit']}` — "
        f"retained runtime `{str(row['requires_runtime_archive']).lower()}`"
        for row in qualification["selected_native_cohort"]
    ]
    lines += [
        f"- Explicit C without native components: `{qualification['explicit_c_without_native_components']}`",
        f"- Failure cases: `{', '.join(qualification['failure_cases'])}`",
        f"- Failure output policy: `{qualification['failure_output_policy']}`",
        f"- Oracle: `{qualification['oracle']}`",
        "",
        "This is a qualification of the existing three-artifact package, not a",
        "package-layout or default-route change. The owning Stdlib explicit-C",
        "relay has merged and Patches 22.2–22.4 are complete. Patch 22.6 remains",
        "unchecked; this reconciliation does not change the default route.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review"))
    args = parser.parse_args()
    record = validate()
    rendered = render(record)
    if args.command == "project":
        REVIEW.write_text(rendered, encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.exists(), "generated review is missing")
        require(REVIEW.read_text(encoding="utf-8") == rendered,
                "generated review is stale")
    print(f"{GUARD_L1}: {args.command} ok")


if __name__ == "__main__":
    main()
