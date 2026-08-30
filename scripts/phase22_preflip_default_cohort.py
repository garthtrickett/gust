#!/usr/bin/env python3
"""Validate, project, and replay Patch 22.5 pre-flip qualification."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE22_PREFLIP_DEFAULT_COHORT.md"
FULL_PROGRAM = ROOT / "compiler/experiments/cranelift/src/full_program.rs"
PHASE21_SUITE = ROOT / "scripts/phase21_complete_guard_suite.py"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase22-preflip-default-cohort.yml"
COMPLETE_WORKFLOW = ROOT / ".github/workflows/phase21-complete-guard-suite.yml"
PROGRAM_WORKFLOW = ROOT / ".github/workflows/phase21-cranelift-built-compiler-programs.yml"
PACKAGED_GUST = ROOT / "build/phase10-package/bin/gust"
WORKER = ROOT / "build/gust-native-backend"
RUNTIME_PACKAGE = ROOT / "build/phase10-package/bin/gust-runtime-package.a"
GUARD_L1 = "guard-cranelift-phase22-preflip-default-cohort-contract"
GUARD_L2 = "guard-cranelift-phase22-preflip-default-cohort-evidence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def run(command: list[str], *, env: dict[str, str] | None = None,
        timeout: float = 180.0) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(command, cwd=ROOT, env=env, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, timeout=timeout, check=False)


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase22_preflip_default_cohort")
    require(isinstance(record, dict), "Patch 22.5 authority is missing")
    require(record.get("contract_version") ==
            "phase22_preflip_default_cohort_v1",
            "contract version drifted")
    require(record.get("status") ==
            "qualification_complete_default_flip_prerequisites_satisfied" and
            record.get("next_action") == "patch22_6_default_route_flip",
            "status or next action drifted")
    require(record.get("predecessor_authority") ==
            registry.get("phase22_default_native_package", {}).get(
                "contract_version") == "phase22_default_native_package_v1",
            "predecessor authority drifted")
    require(registry.get("phase22_default_native_package", {}).get("status") ==
            "qualification_complete" and
            registry.get("phase22_explicit_c_migration", {}).get("status") ==
            "complete_post_relay" and
            registry.get("phase22_explicit_c_migration", {}).get(
                "cross_lane_relay", {}).get("status") == "merged_on_main",
            "default-flip prerequisite status drifted")
    require(record.get("compiler_origin") == "Cranelift_built_full_compiler" and
            record.get("candidate_route") ==
            "explicit_cranelift_no_fallback" and
            record.get("semantic_oracle") ==
            "same_Cranelift_built_compiler_explicit_mir_to_c",
            "compiler origin or route contract drifted")
    require(record.get("cohort_authorities") == [
        registry["phase21_cranelift_built_compiler_programs"]["contract_version"],
        registry["phase21_full_compiler_native_qualification"]["contract_version"],
        registry["phase21_complete_guard_suite"]["contract_version"],
    ], "cohort authorities drifted")
    require(record.get("release_representative_cohorts") == [
        "positive", "negative", "resource", "module", "typed_query_positive",
        "typed_query_negative", "full_compiler", "complete_326_case_guard",
    ], "release-representative cohort drifted")

    historical = registry["phase21_complete_guard_suite"]["classification"]
    resolved = record.get("resolved_phase21_runtime_divergences", {})
    historical_fixtures = [
        row["fixture"] for row in historical["runtime_divergences"]
    ]
    require(resolved.get("count") == 3 and
            resolved.get("fixtures") == historical_fixtures and
            resolved.get("root_cause") ==
            "generic_ZeroInitialize_lowering_used_zero_for_empty_Index" and
            resolved.get("oracle_contract") ==
            "empty_Index_is_the_0xFFFFFFFF_absence_sentinel" and
            resolved.get("native_correction") ==
            "Index_typed_ZeroInitialize_emits_i32_minus_one" and
            resolved.get("other_zero_initialization") == "unchanged_zero",
            "runtime-divergence reconciliation drifted")
    correction = record.get("postmerge_default_index_correction", {})
    require(correction == {
        "review_pull_request": 257,
        "review_thread": "PRRT_kwDOS1ExJc6daULJ",
        "source_fixture":
            "compiler/phase22_default_index_initialization_source.gst",
        "helper_fixture":
            "compiler/phase22_default_index_initialization_helper.gst",
        "oracle_exit": 7,
        "pre_correction_native_exit": 41,
        "corrected_native_exit": 7,
        "initialization_contract":
            "Index_defaults_to_i32_minus_one_recursively_through_non_enum_struct_fields",
        "MIR_to_C": "unchanged_semantic_oracle",
        "other_default_initialization": "unchanged_zero",
    }, "post-merge default-Index correction authority drifted")
    overlay = record.get("complete_guard_overlay", {})
    require(overlay == {
        "inventory_total": 326,
        "required_native_case_count":
            historical["required_native_case_count"] + 3,
        "classified_nondefault_native_deferral_count": 121,
        "oracle_precondition_parity_rejection_count": 10,
        "required_native_deferral_count": 0,
        "unclassified_result_count": 0,
        "runtime_divergence_count": 0,
    }, "complete-guard successor accounting drifted")
    require(historical["total_classified_deferral_count"] - 3 ==
            overlay["classified_nondefault_native_deferral_count"] +
            overlay["oracle_precondition_parity_rejection_count"],
            "successor deferral accounting does not reconcile")

    lowering = FULL_PROGRAM.read_text(encoding="utf-8")
    for marker in (
        '"ZeroInitialize" => {',
        "index_element_layout_type(&node.ty).is_ok()",
        "fn initialize_index_sentinels(",
        "self.initialize_index_sentinels(builder, place, ty)?;",
        "-1",
        "scalar_ir_type(&node.ty, self.pointer_type())?",
    ):
        require(marker in lowering, f"generic sentinel lowering marker missing: {marker}")
    require((ROOT / correction["source_fixture"]).is_file() and
            (ROOT / correction["helper_fixture"]).is_file(),
            "default-Index focused source fixture is missing")
    suite = PHASE21_SUITE.read_text(encoding="utf-8")
    for marker in ("resolved_runtime_divergences", "len(resolved_runtime)"):
        require(marker in suite, "complete-suite successor accounting is missing")
    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 22.5 — Pre-flip Default-Cohort Qualification — DONE" in task and
            "- [x] Patch 22.2b — Post-Relay Prerequisite Reconciliation — DONE"
            in task and
            "- [x] Patch 22.6 — Cranelift Default Route Flip — DONE" in task,
            "22.5/22.6 roadmap boundary drifted")
    compiler_entry = (ROOT / "compiler/test_runner_entry.gst").read_text(
        encoding="utf-8")
    require("invocation.backend.tag = 1; // Cranelift" in compiler_entry,
            "Patch 22.6 successor default is absent")
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
            "make gust phase10-native-package" in workflow,
            "focused workflow does not own build and both guards")
    for inherited in (COMPLETE_WORKFLOW, PROGRAM_WORKFLOW):
        text = inherited.read_text(encoding="utf-8")
        require("compiler/experiments/cranelift/**" in text and
                "pull_request:" in text,
                f"inherited workflow dependency drifted: {inherited.name}")
    boundary = record.get("boundary", {})
    require(boundary.get("changes_existing_cranelift_lowering") is True and
            all(value is False for key, value in boundary.items()
                if key != "changes_existing_cranelift_lowering"),
            "Patch 22.5 boundary widened")
    return record


def render(record: dict) -> str:
    overlay = record["complete_guard_overlay"]
    resolved = record["resolved_phase21_runtime_divergences"]
    correction = record["postmerge_default_index_correction"]
    lines = [
        "# Cranelift Phase 22.5 — Pre-flip Default-Cohort Qualification",
        "",
        "Generated from `scripts/cranelift_feature_registry.json`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next action: `{record['next_action']}`",
        f"- Observed main: `{record['observed_main_sha']}`",
        f"- Compiler origin: `{record['compiler_origin']}`",
        f"- Candidate route: `{record['candidate_route']}`",
        f"- Oracle: `{record['semantic_oracle']}`",
        f"- Package origin: `{record['package_origin']}`",
        "",
        "## Cohort",
        "",
        f"- Inventory: `{overlay['inventory_total']}` cases",
        f"- Required native passes: `{overlay['required_native_case_count']}`",
        f"- Classified non-default native deferrals: `{overlay['classified_nondefault_native_deferral_count']}`",
        f"- Oracle-precondition parity rejections: `{overlay['oracle_precondition_parity_rejection_count']}`",
        f"- Required native deferrals: `{overlay['required_native_deferral_count']}`",
        f"- Unclassified results: `{overlay['unclassified_result_count']}`",
        f"- Runtime divergences: `{overlay['runtime_divergence_count']}`",
        "",
        "## Generic reconciliation",
        "",
        f"- Root cause: `{resolved['root_cause']}`",
        f"- Oracle contract: `{resolved['oracle_contract']}`",
        f"- Native correction: `{resolved['native_correction']}`",
        f"- Other zero initialization: `{resolved['other_zero_initialization']}`",
    ]
    lines += [f"- `{fixture}`" for fixture in resolved["fixtures"]]
    lines += [
        "",
        "## Post-merge default-Index correction",
        "",
        f"- Review: `#{correction['review_pull_request']}` / `{correction['review_thread']}`",
        f"- Source fixture: `{correction['source_fixture']}`",
        f"- Helper fixture: `{correction['helper_fixture']}`",
        f"- Pre-correction oracle/native exit: `{correction['oracle_exit']}/{correction['pre_correction_native_exit']}`",
        f"- Corrected oracle/native exit: `{correction['oracle_exit']}/{correction['corrected_native_exit']}`",
        f"- Contract: `{correction['initialization_contract']}`",
        "",
        "The Phase 21 record remains historical. This successor authority resolves",
        "its three runtime-divergence rows without changing the 121 explicitly owned",
        "non-default native capability deferrals or the ten identical oracle/native",
        "precondition rejections. The owning Stdlib explicit-C relay has merged,",
        "all pre-flip prerequisites are complete, and the compiler default remains",
        "MIR-to-C. Patch 22.6 is still unchecked and is not folded into this",
        "reconciliation.",
        "",
    ]
    return "\n".join(lines)


def evidence() -> None:
    record = validate()
    for path in (PACKAGED_GUST, WORKER, RUNTIME_PACKAGE):
        require(path.is_file(), f"missing evidence prerequisite: {path}")
    output = ROOT / "build/guards/phase22_preflip_default_cohort"
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    env = os.environ.copy()
    env["GUST_NATIVE_BACKEND_DRIVER"] = str(WORKER.resolve())
    env["GUST_NATIVE_RUNTIME_PACKAGE"] = str(RUNTIME_PACKAGE.resolve())
    started = time.monotonic()
    native_compiler = output / "native-gust"
    built = run([str(PACKAGED_GUST), "--backend", "cranelift", "-o",
                 str(native_compiler), "compiler/test_runner_entry.gst"],
                env=env, timeout=record["budgets"]["native_compiler_build_ms"] / 1000)
    require(built.returncode == 0 and native_compiler.is_file() and
            not built.stdout and not built.stderr,
            "Cranelift-built compiler prerequisite failed")
    native_env = dict(env)
    native_env["GUST_TEST_MIR_TO_C_UNAVAILABLE"] = "1"
    for index, fixture in enumerate(
            record["resolved_phase21_runtime_divergences"]["fixtures"]):
        case = output / f"case-{index}"
        case.mkdir()
        oracle_c = run([str(native_compiler), "--backend", "mir-to-c", fixture],
                       env=env)
        require(oracle_c.returncode == 0 and oracle_c.stdout and
                not oracle_c.stderr, f"oracle compile failed: {fixture}")
        c_path = case / "oracle.final.c"
        c_path.write_bytes((ROOT / "src/runtime.c").read_bytes() +
                           b"\n" + oracle_c.stdout)
        oracle_program = case / "oracle-program"
        c_build = run([os.environ.get("CC", "cc"), "-O2", "-Wall", "-pthread",
                       "-Isrc", str(c_path), "-o", str(oracle_program)])
        require(c_build.returncode == 0,
                f"oracle host compile failed: {fixture}: {c_build.stderr[-500:]!r}")
        native_program = case / "native-program"
        native_build = run([str(native_compiler), "--backend", "cranelift", "-o",
                            str(native_program), fixture], env=native_env)
        require(native_build.returncode == 0 and native_program.is_file() and
                not native_build.stdout and not native_build.stderr,
                f"native compile or no-fallback contract failed: {fixture}")
        oracle_run = run([str(oracle_program)])
        native_run = run([str(native_program)])
        require(oracle_run.returncode == native_run.returncode == 0 and
                oracle_run.stdout == native_run.stdout and
                oracle_run.stderr == native_run.stderr,
                f"focused observable parity failed: {fixture}")
    correction = record["postmerge_default_index_correction"]
    fixture = correction["source_fixture"]
    case = output / "default-index-initialization"
    case.mkdir()
    oracle_c = run([str(native_compiler), "--backend", "mir-to-c", fixture],
                   env=env)
    require(oracle_c.returncode == 0 and oracle_c.stdout and
            not oracle_c.stderr,
            "default-Index oracle compile failed")
    c_path = case / "oracle.final.c"
    c_path.write_bytes((ROOT / "src/runtime.c").read_bytes() +
                       b"\n" + oracle_c.stdout)
    oracle_program = case / "oracle-program"
    c_build = run([os.environ.get("CC", "cc"), "-O2", "-Wall", "-pthread",
                   "-Isrc", str(c_path), "-o", str(oracle_program)])
    require(c_build.returncode == 0,
            f"default-Index oracle host compile failed: {c_build.stderr[-500:]!r}")
    native_program = case / "native-program"
    native_build = run([str(native_compiler), "--backend", "cranelift", "-o",
                        str(native_program), fixture], env=native_env)
    require(native_build.returncode == 0 and native_program.is_file() and
            not native_build.stdout and not native_build.stderr,
            "default-Index native compile or no-fallback contract failed")
    oracle_run = run([str(oracle_program)])
    native_run = run([str(native_program)])
    require(oracle_run.returncode == native_run.returncode ==
            correction["corrected_native_exit"] and
            oracle_run.stdout == native_run.stdout and
            oracle_run.stderr == native_run.stderr,
            "default-Index scalar/struct observable parity failed")
    elapsed_ms = int((time.monotonic() - started) * 1000)
    require(elapsed_ms <= record["budgets"]["complete_suite_ms"],
            "focused reconciliation exceeded the inherited complete-suite budget")
    case_count = len(record["resolved_phase21_runtime_divergences"]["fixtures"]) + 1
    print(f"{GUARD_L2}: ok cases={case_count} elapsed_ms={elapsed_ms}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=(
        "validate", "project", "check-review", "evidence"))
    args = parser.parse_args()
    record = validate()
    rendered = render(record)
    if args.command == "project":
        REVIEW.write_text(rendered, encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and
                REVIEW.read_text(encoding="utf-8") == rendered,
                "generated review is stale")
    elif args.command == "evidence":
        evidence()
        return
    print(f"{GUARD_L1}: {args.command} ok")


if __name__ == "__main__":
    main()
