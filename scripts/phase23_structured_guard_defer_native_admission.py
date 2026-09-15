#!/usr/bin/env python3
"""Validate and exercise Patch 23.3a's generic guard/defer native handoff."""

from __future__ import annotations

import argparse
import copy
import json
import os
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE23_STRUCTURED_GUARD_DEFER_NATIVE_ADMISSION.md"
TASK = ROOT / "TASK.md"
STRUCTURED = ROOT / "compiler/mir_native_backend_structured_cfg_source.gst"
FULL_PROGRAM = ROOT / "compiler/mir_native_backend_full_program_source.gst"
WORKER = ROOT / "compiler/experiments/cranelift/src/full_program.rs"
GUST = ROOT / "gust"
DRIVER = ROOT / "build/phase10-package/bin/gust-native-backend"
BUILD = ROOT / "build/guards/phase23_structured_guard_defer_native_admission"
GUARD = "guard-cranelift-phase23-structured-guard-defer-native-admission-contract"
MIR_TO_C_COMMAND = "[str(" + "GUST), '--backend', 'mir-to-c', str(source)]"
NATIVE_COMMAND = "[str(" + "GUST), '--backend', 'cranelift', '-o', str(artifact), str(source)]"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def authority() -> dict:
    value = json.loads(REGISTRY.read_text(encoding="utf-8")).get(
        "phase23_structured_guard_defer_native_admission"
    )
    require(isinstance(value, dict), "registry authority is missing")
    return value


def deferred_reason_body() -> str:
    text = STRUCTURED.read_text(encoding="utf-8")
    start = text.index("func mir_native_structured_cfg_deferred_reason(")
    end = text.index("func mir_native_structured_cfg_contains_branch(", start)
    return text[start:end]


def validate(value: dict | None = None) -> dict:
    value = authority() if value is None else value
    # Patch 24.13 nests a per-row disposition record under the Phase 22
    # closed-inventory extension. Patch 23.3a's authority is unchanged and is
    # still compared exactly below, so the record is lifted out first and
    # checked on its own terms rather than widening that comparison.
    comparable = copy.deepcopy(value) if isinstance(value, dict) else value
    retirement = None
    if isinstance(comparable, dict):
        extension = comparable.get("phase22_closed_inventory_extension")
        if isinstance(extension, dict):
            retirement = extension.pop("phase24_13_retirement", None)
    require(retirement is None or
            (retirement.get("contract_version") ==
             "phase24_13_phase23_executor_retirement_v1" and
             len(retirement.get("dispositions", [])) ==
             value["phase22_closed_inventory_extension"].get(
                 "invocation_count")),
            "the Patch 24.13 retirement record nested in Patch 23.3a's "
            "closed-inventory extension drifted")
    require(comparable == {
        "contract_version": "phase23_structured_guard_defer_native_admission_v1",
        "status": "patch23_3a_complete",
        "next_patch": "23.3",
        "owner": "cranelift",
        "review_view": REVIEW.relative_to(ROOT).as_posix(),
        "source_admission": {
            "narrow_probe": "mir_native_structured_cfg_deferred_reason",
            "full_program_route": "mir_native_full_program_source_lower",
            "typed_ast_tags": [9, 11],
            "canonical_operations": ["GuardUnwrap", "ScheduleDefer"],
            "scalar_signature_policy": "a_function_only_typed_program_with_both_guard_and_defer_may_use_the_existing_full_program_route_when_no_non_scalar_signature_selects_it",
        },
        "fixtures": {
            "positive": "compiler/phase20_resource_acquisition_directory_source.gst",
            "retained_deferred": "compiler/phase13_structured_cfg_short_circuit_deferred_source.gst",
            "retained_declarations": ["tests/e2e_formatting_utilities.gst", "tests/e2e_native_collections_evaluation.gst"],
        },
        "phase22_closed_inventory_extension": {
            "status": "exact_phase23_extension_excluded_only_from_phase22_relay_identity",
            "owning_patch": "23.3a",
            "path": "scripts/phase23_structured_guard_defer_native_admission.py",
            "selection": ["explicit_c", "explicit_cranelift", "explicit_cranelift", "explicit_cranelift"],
            "invocation_count": 4,
            "commands": [
                MIR_TO_C_COMMAND,
                NATIVE_COMMAND,
                NATIVE_COMMAND,
                NATIVE_COMMAND,
            ],
        },
        "phase21_complete_suite_transition": {
            "status": "exact_phase23_guard_defer_admission_overlay",
            "admitted_runner_fixtures": [
                "tests/e2e_guard_hashmap_lookup.gst",
                "tests/e2e_guard_mutability.gst",
            ],
            "required_native_case_delta": 2,
            "classified_deferral_delta": -2,
            "reason_count_deltas": {
                "deferred_p13_structured_cfg_non_reducible_shape": -2,
            },
        },
        "observables": {
            "exit_status": 0,
            "stdout": "",
            "stderr": "",
            "native_artifact": "nonempty_linked_executable",
            "oracle": "mir_to_c",
        },
        "boundary": {
            "changes_accepted_Gust_program_meaning": False,
            "adds_or_changes_MIR_operations": False,
            "changes_existing_MIR_operation_meaning": False,
            "changes_resource_move_or_cleanup_semantics": False,
            "changes_ABI_layout_or_runtime_symbols": False,
            "changes_backend_route_or_fallback": False,
            "changes_bootstrap_seed": False,
            "edits_stdlib_or_CR15": False,
            "begins_patch23_3": False,
        },
    }, "registry authority drifted")
    require("- [x] Patch 23.3a — Structured Guard/Defer Native Admission — DONE" in
            TASK.read_text(encoding="utf-8"), "TASK 23.3a completion is missing")
    return value


def validate_source_handoff(value: dict) -> None:
    deferred = deferred_reason_body()
    require("if statement.tag == 8 {" in deferred,
            "bounded structured-CFG match deferral is missing")
    require("statement.tag == 9" not in deferred and
            "statement.tag == 11" not in deferred,
            "structured-CFG probe still preempts guard/defer")

    full = FULL_PROGRAM.read_text(encoding="utf-8")
    require("func mir_native_full_program_contains_guard_and_defer(" in full and
            "func mir_native_full_program_block_guard_defer_mask(" in full,
            "generic typed guard/defer inventory is missing")
    require("if statement.tag == 9 {" in full and
            "if statement.tag == 11 {" in full,
            "typed guard/defer inventory drifted")
    require("mir_native_full_program_contains_guard_and_defer(programs, ctx)" in full,
            "scalar-signature handoff is missing")
    require("if statement.tag != 3 {" in full,
            "function-only scalar guard/defer admission boundary is missing")
    for forbidden in ("phase20_resource_acquisition", "OpenDir", "Directory"):
        require(forbidden not in deferred and forbidden not in full,
                "source admission contains a fixture or resource-specific exception")

    worker = WORKER.read_text(encoding="utf-8")
    for operation in value["source_admission"]["canonical_operations"]:
        require(f'"{operation}"' in worker,
                f"worker no longer validates existing {operation} operation")
    require('"GuardUnwrap" => self.lower_guard(builder, &node)' in worker,
            "worker guard lowering drifted")
    require('"ScheduleDefer" => {' in worker and
            "self.defers.last_mut().unwrap().push" in worker,
            "worker defer lowering drifted")


def run(command: list[str], *, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(command, cwd=ROOT, env=env, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, check=False)


# Patch 24.13: run_oracle is retired, not merely unused.
#
# It compiled the positive fixture through the MIR-to-C backend, host-compiled
# the result and ran it, to serve as the differential oracle for run_native.
# The conversion below dropped the differential -- the native arm is held to
# the registered observables directly -- which left this function with no
# callers while it still executed the spelling this patch removes. Dead code
# that invokes a removed backend is exactly what #424 was filed about: it does
# not run, so nothing fails, and it survives review as "unused".
#
# What it asserted is not lost. MIR_TO_C_COMMAND above still records the argv
# it built, and the Phase 22 successor manifest still pins that row as this
# guard's history; the frozen oracle's discharged register asserts that the
# argv is no longer CONSTRUCTED anywhere in this file. So the record of what
# the oracle was survives, and the claim that it no longer runs is checked.


def run_native(source: Path) -> tuple[int, bytes, bytes, Path]:
    env = os.environ.copy()
    env["GUST_NATIVE_BACKEND_DRIVER"] = str(DRIVER)
    artifact = BUILD / "positive.native"
    compiled = run([str(GUST), "--backend", "cranelift", "-o", str(artifact),
                   str(source)], env=env)
    require(compiled.returncode == 0, "native guard/defer source did not reach driver")
    require(compiled.stdout == b"" and compiled.stderr == b"",
            "native compiler emitted an unexpected diagnostic")
    require(artifact.is_file() and artifact.stat().st_size > 0,
            "native driver did not publish a nonempty executable")
    observed = run([str(artifact)])
    return observed.returncode, observed.stdout, observed.stderr, artifact


def validate_retained_deferral(value: dict) -> None:
    source = ROOT / value["fixtures"]["retained_deferred"]
    env = os.environ.copy()
    env["GUST_NATIVE_BACKEND_DRIVER"] = str(DRIVER)
    artifact = BUILD / "retained-deferred.native"
    observed = run([str(GUST), "--backend", "cranelift", "-o", str(artifact),
                    str(source)], env=env)
    require(observed.returncode != 0 and not artifact.exists(),
            "retained structured-CFG deferral reached native publication")
    output = observed.stdout.decode("utf-8", errors="replace")
    require("deferred_p13_structured_cfg_short_circuit" in output and
            "expected_failure_stage=before_driver_discovery" in output,
            "retained short-circuit deferral changed")


def validate_retained_declaration_deferral(value: dict) -> None:
    env = os.environ.copy()
    env["GUST_NATIVE_BACKEND_DRIVER"] = str(DRIVER)
    for index, fixture in enumerate(value["fixtures"]["retained_declarations"]):
        source = ROOT / fixture
        artifact = BUILD / f"retained-declaration-{index}.native"
        observed = run([str(GUST), "--backend", "cranelift", "-o", str(artifact),
                        str(source)], env=env)
        require(observed.returncode != 0 and not artifact.exists(),
                "retained scalar source reached native publication")
        output = observed.stdout.decode("utf-8", errors="replace")
        require("reason_code=source_feature_not_represented" in output and
                "expected_failure_stage=before_driver_discovery" in output,
                "retained scalar source classification changed")


def render(value: dict) -> str:
    source = value["source_admission"]
    fixtures = value["fixtures"]
    observables = value["observables"]
    return "\n".join([
        "# Phase 23 Structured Guard/Defer Native Admission",
        "",
        "Generated by `scripts/phase23_structured_guard_defer_native_admission.py`; do not edit by hand.",
        "",
        f"- Contract: `{value['contract_version']}`",
        f"- Status: `{value['status']}`",
        f"- Owner: `{value['owner']}`",
        f"- Narrow probe: `{source['narrow_probe']}`",
        f"- Full-program route: `{source['full_program_route']}`",
        f"- Typed AST tags: `{source['typed_ast_tags']}`",
        f"- Existing canonical operations: `{', '.join(source['canonical_operations'])}`",
        "",
        "The narrower structured-CFG recognizer does not claim typed `guard` or `defer`. "
        "The generic full-program encoder admits only function-only scalar programs that contain both "
        "operations, and the existing worker validates and lowers the same two "
        "canonical operations. No resource, directory, fixture, module, or path exception exists.",
        "",
        "## Evidence contract",
        "",
        f"- Positive source: `{fixtures['positive']}`",
        f"- Retained deferral: `{fixtures['retained_deferred']}`",
        f"- Retained declaration/defer-only deferrals: `{', '.join(fixtures['retained_declarations'])}`",
        f"- Oracle: `{observables['oracle']}`",
        f"- Expected exit: `{observables['exit_status']}` with empty stdout/stderr",
        f"- Native artifact: `{observables['native_artifact']}`",
        "- Phase 22 relay inventory: the exact "
        f"{value['phase22_closed_inventory_extension']['invocation_count']} evidence invocations are a registered Phase 23 extension and are excluded only while validating the frozen Phase 22 six-site relay identity.",
        "- Complete-suite overlay: two exact guard/defer runner fixtures move from the "
        "historical non-reducible deferral cohort to required native qualification.",
        "",
        "The evidence guard rejects restoring the preempting guard/defer deferral, "
        "removing the generic function-only both-operations scalar-signature handoff, replacing the existing "
        "worker operations, admitting declaration-bearing scalar source, or admitting the "
        "retained short-circuit structured-CFG deferral.",
        "",
        "No accepted Gust meaning, canonical MIR operation or operation meaning, resource/move/cleanup "
        "semantics, ABI/layout/runtime symbol, backend fallback, bootstrap seed, Stdlib, or CR-15 authority changes.",
        "",
    ])


def check_review(value: dict) -> None:
    require(REVIEW.read_text(encoding="utf-8") == render(value),
            "generated review is stale; run render")


def evidence() -> None:
    value = validate()
    validate_source_handoff(value)
    require(GUST.is_file() and DRIVER.is_file(),
            "build gust and phase10-native-package before evidence")
    if BUILD.exists():
        shutil.rmtree(BUILD)
    BUILD.mkdir(parents=True)
    source = ROOT / value["fixtures"]["positive"]
    # Patch 24.13: the oracle arm is retired and the native arm is checked
    # against the REGISTERED CONTRACT instead of against it.
    #
    # The two assertions were doing different work. The first compared native
    # to MIR-to-C -- a second opinion, which the retirement removes. The second
    # compared the oracle to value["observables"]["exit_status"], a registered
    # expectation that was never derived from either backend. Pointing the
    # native arm at that expectation keeps the assertion that has independent
    # authority and drops only the differential.
    #
    # This is why the guard converts rather than retires: what it ultimately
    # proves is that the positive fixture produces the registered observables,
    # and the native route can be held to that directly.
    native = run_native(source)
    require(native[:3] == (value["observables"]["exit_status"], b"", b""),
            "positive native observables differ from registered contract")
    validate_retained_deferral(value)
    validate_retained_declaration_deferral(value)
    check_review(value)
    print(f"phase23_structured_guard_defer_native_admission: evidence ok artifact_bytes={native[3].stat().st_size}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "render", "check-review", "evidence"))
    args = parser.parse_args()
    value = validate()
    if args.command == "render":
        REVIEW.write_text(render(value), encoding="utf-8")
    elif args.command == "check-review":
        check_review(value)
    elif args.command == "evidence":
        evidence()
    else:
        validate_source_handoff(value)
        print("phase23_structured_guard_defer_native_admission: ok")


if __name__ == "__main__":
    main()
