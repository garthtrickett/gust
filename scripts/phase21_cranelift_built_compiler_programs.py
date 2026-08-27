#!/usr/bin/env python3
"""Validate, project, and execute Patch 21.15 compiler-origin parity evidence."""

from __future__ import annotations

import argparse
import json
import os
import resource
import signal
import subprocess
import tempfile
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE21_CRANELIFT_BUILT_COMPILER_PROGRAMS.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase21-cranelift-built-compiler-programs.yml"
WORKER = ROOT / "build/gust-native-backend"
PACKAGED_GUST = ROOT / "build/phase10-package/bin/gust"
RUNTIME_PACKAGE = ROOT / "build/phase10-package/bin/gust-runtime-package.a"
GUARD_L1 = "guard-cranelift-phase21-cranelift-built-compiler-programs-contract"
GUARD_L2 = "guard-cranelift-phase21-cranelift-built-compiler-programs-evidence"


class SuiteDeadlineExceeded(RuntimeError):
    """A child process exhausted the registered Patch 21.15 suite deadline."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def run(
    command: list[str],
    *,
    env: dict[str, str] | None = None,
    timeout: float | None = None,
) -> subprocess.CompletedProcess[bytes]:
    process = subprocess.Popen(
        command,
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        start_new_session=True,
    )
    try:
        stdout, stderr = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired as error:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.communicate()
        raise SuiteDeadlineExceeded(
            f"subprocess exceeded remaining suite deadline: {' '.join(command)}"
        ) from error
    return subprocess.CompletedProcess(command, process.returncode, stdout, stderr)


def remaining_timeout(deadline: float) -> float:
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise SuiteDeadlineExceeded("registered suite deadline was exhausted")
    return remaining


def run_before(
    deadline: float,
    command: list[str],
    *,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[bytes]:
    return run(command, env=env, timeout=remaining_timeout(deadline))


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    predecessor = registry.get("phase21_full_compiler_native_qualification", {})
    require(
        predecessor.get("status") == "patch21_14_complete"
        and predecessor.get("next_patch") == "21.15",
        "Patch 21.14 predecessor authority drifted",
    )
    record = registry.get("phase21_cranelift_built_compiler_programs", {})
    expected = {
        "contract_version": "phase21_cranelift_built_compiler_programs_v1",
        "status": "patch21_15_complete",
        "next_patch": "21.16",
        "review_view": "compiler/CRANELIFT_PHASE21_CRANELIFT_BUILT_COMPILER_PROGRAMS.md",
        "observed_main_sha": "4c62f7482c972f5019d112b48589fd4529edb692",
        "predecessor_authority": "phase21_full_compiler_native_qualification_v1",
        "compiler_source": "compiler/test_runner_entry.gst",
        "compiler_build_backend": "cranelift",
        "target_backend": "cranelift",
        "semantic_oracle": "mir_to_c_compiled_program_execution",
        "fallback_policy": "explicit_cranelift_no_fallback",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")

    require(
        record.get("compiler_artifact") == {
            "kind": "linked_native_executable",
            "elf_class": "ELF64",
            "machine": "Advanced Micro Devices X86-64",
            "minimum_bytes": 4194304,
            "maximum_bytes": 10485760,
            "generated_C": False,
        },
        "compiler artifact authority drifted",
    )
    require(
        record.get("accepted_cases") == [
            {
                "id": "scalar_positive",
                "cohort": "positive",
                "source_fixture": "compiler/phase11_scalar_unsupported_multiply_source.gst",
                "run_exit": 12,
                "stdout": "",
                "stderr": "",
            },
            {
                "id": "resource_cleanup",
                "cohort": "resource",
                "source_fixture": "compiler/phase20_resource_scope_cleanup_source.gst",
                "run_exit": 0,
                "stdout": "2\n1\n4\n3\n5\n9\n6\n7\n8\n10\n",
                "stderr": "",
            },
            {
                "id": "imported_module",
                "cohort": "module",
                "source_fixture": "compiler/phase21_selected_declaration_source.gst",
                "run_exit": 42,
                "stdout": "",
                "stderr": "",
            },
            {
                "id": "trusted_typed_query",
                "cohort": "typed_query",
                "source_fixture": "compiler/phase21_trusted_scope_positive.gst",
                "run_exit": 41,
                "stdout": "",
                "stderr": "",
            },
        ],
        "accepted program cohort drifted",
    )
    require(
        record.get("rejected_cases") == [
            {
                "id": "scalar_type_error",
                "cohort": "negative",
                "source_fixture": "compiler/phase13_scalar_invalid_operand_source.gst",
                "compile_exit": 1,
                "diagnostic_class": "TypeMismatch",
            },
            {
                "id": "typed_query_provenance_error",
                "cohort": "typed_query_negative",
                "source_fixture": "compiler/phase21_trusted_scope_absent_invalid.gst",
                "compile_exit": 1,
                "diagnostic_class": "TenantScopeProvenance",
            },
        ],
        "rejected program cohort drifted",
    )
    require(
        record.get("comparison_contract") == {
            "accepted_compile_diagnostics": "empty_for_both_compiler_origins",
            "accepted_execution": "exit_stdout_and_stderr_byte_identical_to_MIR_to_C_oracle",
            "accepted_native_artifacts": "C_built_and_Cranelift_built_compilers_emit_byte_identical_ELF_executables",
            "rejected_diagnostics": "stdout_and_stderr_byte_identical_between_compiler_origins",
            "rejected_driver_policy": "rejection_precedes_native_driver_discovery",
            "side_effect_policy": "program_output_and_phase9g_link_logs_byte_identical_between_compiler_origins",
            "failure_cleanup": "no_output_request_bundle_object_or_generated_C",
        },
        "comparison contract drifted",
    )
    measurements = record.get("measurements", {})
    require(
        measurements.get("observed_compiler_build_elapsed_ms") == 39658
        and measurements.get("observed_suite_elapsed_ms") == 41556
        and measurements.get("observed_peak_rss_kib") == 4041984
        and measurements.get("observed_compiler_bytes") == 5696280
        and measurements.get("max_compiler_build_elapsed_ms") == 600000
        and measurements.get("max_suite_elapsed_ms") == 180000
        and measurements.get("max_peak_rss_kib") == 6291456,
        "Patch 21.15 resource budgets drifted",
    )
    require(
        record.get("boundary") == {
            "changes_accepted_Gust_program_meaning": False,
            "adds_or_changes_MIR_operations": False,
            "changes_ABI_layout_or_runtime_symbols": False,
            "changes_bootstrap_seed": False,
            "changes_default_backend_or_fallback": False,
            "edits_stdlib_or_CR15": False,
            "begins_patch21_16_or_OD15": False,
        },
        "Patch 21.15 boundary widened",
    )

    for case in record["accepted_cases"] + record["rejected_cases"]:
        require((ROOT / case["source_fixture"]).is_file(),
                f"source fixture is missing: {case['source_fixture']}")
    resource_source = (ROOT / "compiler/phase20_resource_scope_cleanup_source.gst").read_text()
    require('import "phase20_resource_scope_cleanup_module.gst" as resource;' in resource_source,
            "resource case lost its owning module")
    module_source = (ROOT / "compiler/phase21_selected_declaration_source.gst").read_text()
    require('import "phase21_selected_declaration_module.gst" as declaration;' in module_source,
            "module case lost its import")
    typed_query = (ROOT / "compiler/phase21_trusted_scope_positive.gst").read_text()
    require("trusted_scope_from_context" in typed_query and "query {" in typed_query,
            "typed-query case lost trusted scope provenance")

    require(
        "- [x] Patch 21.15 — Cranelift-Built Compiler Program Compilation — DONE"
        in TASK.read_text(encoding="utf-8"),
        "TASK.md does not mark Patch 21.15 DONE",
    )
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 21.15 guard levels drifted")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in justfile and f"{GUARD_L2}:" in justfile,
            "Patch 21.15 just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Patch 21.15 contract guard")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    for token in (f"just {GUARD_L1}", f"just {GUARD_L2}",
                  "make gust phase10-native-package"):
        require(token in workflow, f"dedicated Patch 21.15 workflow lacks {token}")
    for runtime_path in ("- 'src/runtime.c'", "- 'src/runtime/**'"):
        require(workflow.count(runtime_path) == 2,
                f"dedicated workflow does not cover {runtime_path} twice")
    require(workflow.count("- 'gust_v4.c'") == 2,
            "dedicated workflow does not cover gust_v4.c twice")
    require("python3 scripts/phase21_cranelift_built_compiler_programs.py deadline-regression"
            in justfile, "Patch 21.15 deadline regression is not guarded")
    return record


def render(record: dict) -> str:
    lines = [
        "# Cranelift Phase 21 Cranelift-Built Compiler Program Compilation",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase21_cranelift_built_compiler_programs.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Compiler source: `{record['compiler_source']}`",
        f"- Compiler build backend: `{record['compiler_build_backend']}`",
        f"- Program backend: `{record['target_backend']}`",
        f"- Semantic oracle: `{record['semantic_oracle']}`",
        f"- Fallback: `{record['fallback_policy']}`",
        "",
        "## Selected accepted programs",
        "",
    ]
    for case in record["accepted_cases"]:
        lines.append(
            f"- `{case['cohort']}`: `{case['source_fixture']}` — exit {case['run_exit']}, "
            f"stdout hex `{case['stdout'].encode().hex()}`, stderr hex `{case['stderr'].encode().hex()}`."
        )
    lines.extend(["", "## Selected rejections", ""])
    for case in record["rejected_cases"]:
        lines.append(
            f"- `{case['cohort']}`: `{case['source_fixture']}` — exit {case['compile_exit']}, "
            f"diagnostic class `{case['diagnostic_class']}`."
        )
    lines.extend([
        "",
        "## Comparison and boundary",
        "",
        "- Every accepted program has byte-identical exit/stdout/stderr against the MIR-to-C oracle.",
        "- The C-built and Cranelift-built compilers emit byte-identical native ELF program artifacts.",
        "- Their Phase 9G linker stdout/stderr logs are present and byte-identical.",
        "- Rejections have byte-identical stdout/stderr and happen before native-driver discovery.",
        "- Successful subject routes leave no request, bundle, object, or generated-C residue.",
        "- Patch 21.15 changes no Gust meaning, MIR operation, ABI/layout/runtime symbol, seed, default backend, fallback policy, Stdlib, or CR-15 authority, and does not begin Patch 21.16 or OD-15.",
        "",
    ])
    return "\n".join(lines)


def compile_oracle(
    source: str,
    root: Path,
    deadline: float,
) -> tuple[Path, subprocess.CompletedProcess[bytes]]:
    generated_c = root / "oracle.c"
    compiled = run_before(deadline, [str(ROOT / "gust"), "--backend", "mir-to-c", source])
    generated_c.write_bytes(compiled.stdout)
    require(compiled.returncode == 0 and compiled.stderr == b"" and generated_c.stat().st_size > 0,
            f"{source}: MIR-to-C oracle compilation failed")
    artifact = root / "oracle"
    linked = run_before(deadline, [
        os.environ.get("CC", "cc"), "-O0", "-w", "-pthread", "-Isrc",
        "-include", "src/runtime.c", str(generated_c), "-o", str(artifact),
    ])
    require(linked.returncode == 0 and linked.stdout == linked.stderr == b"" and artifact.is_file(),
            f"{source}: MIR-to-C oracle link failed")
    return artifact, compiled


def assert_elf(path: Path, deadline: float) -> None:
    header = run_before(deadline, ["readelf", "-h", str(path)])
    require(
        header.returncode == 0
        and b"ELF64" in header.stdout
        and b"Advanced Micro Devices X86-64" in header.stdout,
        f"native artifact properties drifted: {path.name}",
    )


def evidence(record: dict) -> None:
    for path in (ROOT / "gust", WORKER, PACKAGED_GUST, RUNTIME_PACKAGE):
        require(path.is_file(), f"evidence prerequisite is missing: {path.relative_to(ROOT)}")
    started = time.monotonic()
    deadline = started + record["measurements"]["max_suite_elapsed_ms"] / 1000
    with tempfile.TemporaryDirectory(prefix="phase21-15-", dir=ROOT / "build") as raw_tmp:
        tmp = Path(raw_tmp)
        native_compiler = tmp / "gust-native"
        build_started = time.monotonic()
        built = run([
            str(PACKAGED_GUST), "--backend", "cranelift", "-o", str(native_compiler),
            record["compiler_source"],
        ], timeout=min(
            remaining_timeout(deadline),
            record["measurements"]["max_compiler_build_elapsed_ms"] / 1000,
        ))
        build_elapsed_ms = int((time.monotonic() - build_started) * 1000)
        artifact = record["compiler_artifact"]
        require(
            built.returncode == 0 and built.stdout == built.stderr == b""
            and native_compiler.is_file()
            and artifact["minimum_bytes"] <= native_compiler.stat().st_size <= artifact["maximum_bytes"],
            "Cranelift-built compiler publication failed or left its artifact budget",
        )
        assert_elf(native_compiler, deadline)

        real_env = os.environ.copy()
        real_env["GUST_NATIVE_BACKEND_DRIVER"] = str(WORKER.resolve())
        for case in record["accepted_cases"]:
            case_root = tmp / case["id"]
            case_root.mkdir()
            source = case["source_fixture"]
            oracle_artifact, _ = compile_oracle(source, case_root, deadline)
            reference_artifact = case_root / "reference-native"
            reference = run_before(deadline, [
                str(ROOT / "gust"), "--backend", "cranelift", "-o",
                str(reference_artifact), source,
            ], env=real_env)
            subject_artifact = case_root / "subject-native"
            subject = run_before(deadline, [
                str(native_compiler), "--backend", "cranelift", "-o",
                str(subject_artifact), source,
            ], env=real_env)
            require(
                reference.returncode == subject.returncode == 0
                and reference.stdout == reference.stderr == subject.stdout == subject.stderr == b""
                and reference_artifact.read_bytes() == subject_artifact.read_bytes(),
                f"{case['id']}: compiler-origin diagnostics or native artifact diverged",
            )
            reference_logs = [
                case_root / f".{reference_artifact.name}.phase9g-link.stdout.log",
                case_root / f".{reference_artifact.name}.phase9g-link.stderr.log",
            ]
            subject_logs = [
                case_root / f".{subject_artifact.name}.phase9g-link.stdout.log",
                case_root / f".{subject_artifact.name}.phase9g-link.stderr.log",
            ]
            require(
                all(path.is_file() for path in reference_logs + subject_logs)
                and [path.read_bytes() for path in reference_logs]
                == [path.read_bytes() for path in subject_logs],
                f"{case['id']}: Phase 9G linker side effects diverged",
            )
            assert_elf(reference_artifact, deadline)
            assert_elf(subject_artifact, deadline)
            executions = [run_before(deadline, [str(path)]) for path in
                          (oracle_artifact, reference_artifact, subject_artifact)]
            expected_stdout = case["stdout"].encode()
            expected_stderr = case["stderr"].encode()
            require(
                all(result.returncode == case["run_exit"]
                    and result.stdout == expected_stdout
                    and result.stderr == expected_stderr for result in executions),
                f"{case['id']}: accepted behavior or side effects diverged",
            )
            for path in (reference_artifact, subject_artifact):
                require(
                    not Path(str(path) + ".phase10.bundle").exists()
                    and not Path(str(path) + ".phase10.request").exists(),
                    f"{case['id']}: native route left request or bundle residue",
                )
            require(
                list(case_root.glob("*.c")) == [case_root / "oracle.c"]
                and not list(case_root.glob("*.o")),
                f"{case['id']}: native route left generated C or object residue",
            )

        missing_driver = tmp / "deliberately-missing-native-driver"
        reject_env = os.environ.copy()
        reject_env["GUST_NATIVE_BACKEND_DRIVER"] = str(missing_driver)
        for case in record["rejected_cases"]:
            source = case["source_fixture"]
            reference_artifact = tmp / f"{case['id']}-reference"
            subject_artifact = tmp / f"{case['id']}-subject"
            reference = run_before(deadline, [
                str(ROOT / "gust"), "--backend", "cranelift", "-o",
                str(reference_artifact), source,
            ], env=reject_env)
            subject = run_before(deadline, [
                str(native_compiler), "--backend", "cranelift", "-o",
                str(subject_artifact), source,
            ], env=reject_env)
            diagnostic = f"[{case['diagnostic_class']}]".encode()
            require(
                reference.returncode == subject.returncode == case["compile_exit"]
                and reference.stdout == subject.stdout
                and reference.stderr == subject.stderr
                and diagnostic in subject.stdout
                and not reference_artifact.exists()
                and not subject_artifact.exists()
                and not list(tmp.glob(f".{reference_artifact.name}.phase9g-link.*.log"))
                and not list(tmp.glob(f".{subject_artifact.name}.phase9g-link.*.log")),
                f"{case['id']}: rejection diagnostics, driver boundary, or cleanup diverged",
            )

        suite_elapsed_ms = int((time.monotonic() - started) * 1000)
        peak_rss_kib = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
        require(
            suite_elapsed_ms <= record["measurements"]["max_suite_elapsed_ms"]
            and peak_rss_kib <= record["measurements"]["max_peak_rss_kib"],
            "Patch 21.15 evidence exceeded its resource budget",
        )
        require(not list(tmp.rglob("*.phase10.bundle"))
                and not list(tmp.rglob("*.phase10.request")),
                "Patch 21.15 evidence left native transient residue")
        print(
            f"{GUARD_L2}: ok build_elapsed_ms={build_elapsed_ms} "
            f"suite_elapsed_ms={suite_elapsed_ms} peak_rss_kib={peak_rss_kib} "
            f"compiler_bytes={native_compiler.stat().st_size}"
        )


def deadline_regression() -> None:
    try:
        remaining_timeout(time.monotonic() - 1)
    except SuiteDeadlineExceeded:
        pass
    else:
        require(False, "expired suite deadline was accepted")

    started = time.monotonic()
    try:
        run(["sh", "-c", "sleep 5"], timeout=0.02)
    except SuiteDeadlineExceeded:
        pass
    else:
        require(False, "hung subprocess did not trip the suite deadline")
    require(time.monotonic() - started < 1,
            "deadline regression did not terminate the child process group promptly")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command",
        choices=("validate", "project", "check-review", "deadline-regression", "evidence"),
    )
    args = parser.parse_args()
    record = validate()
    if args.command == "project":
        REVIEW.write_text(render(record), encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and REVIEW.read_text(encoding="utf-8") == render(record),
                "generated review is stale; run project")
    elif args.command == "deadline-regression":
        deadline_regression()
    elif args.command == "evidence":
        try:
            evidence(record)
        except SuiteDeadlineExceeded as error:
            raise SystemExit(f"{GUARD_L2}: {error}") from None
    print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
