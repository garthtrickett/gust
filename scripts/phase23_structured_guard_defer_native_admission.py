#!/usr/bin/env python3
"""Validate and exercise Patch 23.3a's generic guard/defer native handoff."""

from __future__ import annotations

import argparse
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
    require(value == {
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
            "scalar_signature_policy": "a_function_only_typed_program_with_guard_or_defer_may_use_the_existing_full_program_route_when_no_non_scalar_signature_selects_it",
        },
        "fixtures": {
            "positive": "compiler/phase20_resource_acquisition_directory_source.gst",
            "retained_deferred": "compiler/phase13_structured_cfg_short_circuit_deferred_source.gst",
            "retained_declaration": "tests/e2e_formatting_utilities.gst",
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
    require("- [ ] Patch 23.3a — Structured Guard/Defer Native Admission" in
            TASK.read_text(encoding="utf-8"), "TASK 23.3a status is missing")
    return value


def validate_source_handoff(value: dict) -> None:
    deferred = deferred_reason_body()
    require("if statement.tag == 8 {" in deferred,
            "bounded structured-CFG match deferral is missing")
    require("statement.tag == 9" not in deferred and
            "statement.tag == 11" not in deferred,
            "structured-CFG probe still preempts guard/defer")

    full = FULL_PROGRAM.read_text(encoding="utf-8")
    require("func mir_native_full_program_contains_guard_or_defer(" in full,
            "generic typed guard/defer inventory is missing")
    require("statement.tag == 9 || statement.tag == 11" in full,
            "typed guard/defer inventory drifted")
    require("mir_native_full_program_contains_guard_or_defer(programs, ctx)" in full,
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


def run_oracle(source: Path) -> tuple[int, bytes, bytes]:
    generated = run([str(GUST), "--backend", "mir-to-c", str(source)])
    require(generated.returncode == 0, "MIR-to-C oracle did not compile positive")
    require(generated.stderr == b"", "MIR-to-C oracle emitted compiler stderr")
    output_c = BUILD / "positive.c"
    output_c.write_bytes(generated.stdout)
    final_c = BUILD / "positive.final.c"
    final_c.write_bytes((ROOT / "src/runtime.c").read_bytes() + generated.stdout)
    program = BUILD / "positive.c.program"
    linked = run(["cc", "-O0", "-w", "-pthread", "-Isrc", str(final_c),
                  "-o", str(program)])
    require(linked.returncode == 0, "MIR-to-C oracle generated C did not link")
    observed = run([str(program)])
    return observed.returncode, observed.stdout, observed.stderr


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
    source = ROOT / value["fixtures"]["retained_declaration"]
    env = os.environ.copy()
    env["GUST_NATIVE_BACKEND_DRIVER"] = str(DRIVER)
    artifact = BUILD / "retained-declaration.native"
    observed = run([str(GUST), "--backend", "cranelift", "-o", str(artifact),
                    str(source)], env=env)
    require(observed.returncode != 0 and not artifact.exists(),
            "declaration-bearing scalar source reached native publication")
    output = observed.stdout.decode("utf-8", errors="replace")
    require("reason_code=source_feature_not_represented" in output and
            "expected_failure_stage=before_driver_discovery" in output,
            "declaration-bearing scalar source classification changed")


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
        "The generic full-program encoder admits that AST cohort for function-only scalar "
        "program signatures, and the existing worker validates and lowers the same two "
        "canonical operations. No resource, directory, fixture, module, or path exception exists.",
        "",
        "## Evidence contract",
        "",
        f"- Positive source: `{fixtures['positive']}`",
        f"- Retained deferral: `{fixtures['retained_deferred']}`",
        f"- Retained declaration-bearing deferral: `{fixtures['retained_declaration']}`",
        f"- Oracle: `{observables['oracle']}`",
        f"- Expected exit: `{observables['exit_status']}` with empty stdout/stderr",
        f"- Native artifact: `{observables['native_artifact']}`",
        "- Phase 22 relay inventory: the exact "
        f"{value['phase22_closed_inventory_extension']['invocation_count']} evidence invocations are a registered Phase 23 extension and are excluded only while validating the frozen Phase 22 six-site relay identity.",
        "",
        "The evidence guard rejects restoring the preempting guard/defer deferral, "
        "removing the generic function-only scalar-signature handoff, replacing the existing "
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
    oracle = run_oracle(source)
    native = run_native(source)
    require(oracle == native[:3],
            "native guard/defer observables differ from MIR-to-C")
    require(oracle == (value["observables"]["exit_status"], b"", b""),
            "positive observables differ from registered contract")
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
