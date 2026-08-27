#!/usr/bin/env python3
"""Validate, project, and execute Patch 21.16 native rebuild evidence."""

from __future__ import annotations

import argparse
import hashlib
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
VISION = ROOT / "docs/VISION.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE21_NATIVE_REBUILD_REPRODUCIBILITY.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase21-native-rebuild-reproducibility.yml"
WORKER = ROOT / "build/gust-native-backend"
PACKAGED_GUST = ROOT / "build/phase10-package/bin/gust"
RUNTIME_PACKAGE = ROOT / "build/phase10-package/bin/gust-runtime-package.a"
MANIFEST = ROOT / "compiler/experiments/cranelift/Cargo.toml"
LOCKFILE = ROOT / "compiler/experiments/cranelift/Cargo.lock"
GUARD_L1 = "guard-cranelift-phase21-native-rebuild-reproducibility-contract"
GUARD_L2 = "guard-cranelift-phase21-native-rebuild-reproducibility-evidence"


class SuiteDeadlineExceeded(RuntimeError):
    """A child process exhausted the registered Patch 21.16 deadline."""


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
            f"subprocess exceeded its registered deadline: {' '.join(command)}"
        ) from error
    return subprocess.CompletedProcess(command, process.returncode, stdout, stderr)


def remaining_timeout(deadline: float) -> float:
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise SuiteDeadlineExceeded("registered suite deadline was exhausted")
    return remaining


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    predecessor = registry.get("phase21_cranelift_built_compiler_programs", {})
    require(
        predecessor.get("status") == "patch21_15_complete"
        and predecessor.get("next_patch") == "21.16",
        "Patch 21.15 predecessor authority drifted",
    )
    roadmap = registry.get("phase21_roadmap", {})
    od15 = roadmap.get("od15", {})
    require(
        od15.get("status") == "resolved_2026_08_27_strict_binary_identity"
        and od15.get("criterion")
        == "independently_produced_native_stages_are_byte_identical_under_the_pinned_authoritative_environment"
        and od15.get("blocks") == "none",
        "OD-15 strict binary-identity resolution drifted",
    )

    record = registry.get("phase21_native_rebuild_reproducibility", {})
    expected = {
        "contract_version": "phase21_native_rebuild_reproducibility_v1",
        "status": "patch21_16_complete",
        "next_patch": "21.17",
        "review_view": "compiler/CRANELIFT_PHASE21_NATIVE_REBUILD_REPRODUCIBILITY.md",
        "observed_main_sha": "378c7067eb87a55874cdad80ed71159ccd211146",
        "predecessor_authority": "phase21_cranelift_built_compiler_programs_v1",
        "od15_resolution": "resolved_2026_08_27_strict_binary_identity",
        "compiler_source": "compiler/test_runner_entry.gst",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")

    require(record.get("stage_graph") == [
        "N1a=packaged_MIR_to_C_built_compiler_to_Cranelift_native_compiler",
        "N1b=independent_packaged_MIR_to_C_built_compiler_to_Cranelift_native_compiler",
        "N2=N1a_to_Cranelift_native_compiler",
        "N3=N2_to_Cranelift_native_compiler",
    ], "native rebuild stage graph drifted")

    environment = record.get("authoritative_environment", {})
    require(environment.get("source_commit_policy")
            == "exact_clean_checked_out_workflow_head_for_every_stage",
            "authoritative source-commit policy drifted")
    require(environment.get("runner_image") == "ubuntu-24.04"
            and environment.get("rustc_version")
            == "rustc 1.97.1 (8bab26f4f 2026-07-14)"
            and environment.get("cargo_version")
            == "cargo 1.97.1 (c980f4866 2026-06-30)"
            and environment.get("cranelift_version") == "0.131.0"
            and environment.get("target") == "x86_64-unknown-linux-gnu"
            and environment.get("backend_flags") == ["--backend", "cranelift"],
            "pinned compiler, Cranelift, target, or flag authority drifted")
    require(environment.get("cranelift_manifest")
            == "compiler/experiments/cranelift/Cargo.toml"
            and environment.get("cranelift_lockfile")
            == "compiler/experiments/cranelift/Cargo.lock"
            and environment.get("dependency_resolution")
            == "cargo_locked_exact_versions_and_checksums",
            "pinned Cranelift manifest, lockfile, or resolution policy drifted")
    manifest = MANIFEST.read_text(encoding="utf-8")
    lockfile = LOCKFILE.read_text(encoding="utf-8")
    for package in (
        "cranelift-codegen",
        "cranelift-frontend",
        "cranelift-module",
        "cranelift-native",
        "cranelift-object",
    ):
        require(f'{package} = "=0.131.0"' in manifest,
                f"pinned {package} manifest version drifted")
        require(f'name = "{package}"\nversion = "0.131.0"' in lockfile,
                f"locked {package} version drifted")
    makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
    require("$(CARGO) build \\\n\t\t--locked \\" in makefile,
            "native worker build no longer uses the locked dependency graph")
    require(environment.get("cc") == "cc"
            and environment.get("cc_version") == "13.3.0"
            and environment.get("cflags") == "-O2 -Wall -pthread"
            and environment.get("linker") == "GNU ld"
            and environment.get("linker_version") == "2.42"
            and environment.get("runtime_package")
            == "build/phase10-package/bin/gust-runtime-package.a",
            "pinned C toolchain, linker, flags, or runtime authority drifted")
    require(environment.get("normalized_environment") == {
        "LANG": "C.UTF-8",
        "LC_ALL": "C.UTF-8",
        "TZ": "UTC",
        "SOURCE_DATE_EPOCH": "0",
        "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
        "CC": "cc",
        "CFLAGS": "-O2 -Wall -pthread",
        "RUSTUP_TOOLCHAIN": "1.97.1",
    }, "normalized environment drifted")

    require(record.get("identity_contract") == {
        "criterion": "N1a_N1b_N2_and_N3_artifacts_are_byte_identical",
        "help_behavior": "exit_stdout_and_stderr_are_byte_identical_across_all_stages",
        "linker_side_effects": "every_stage_has_byte_identical_empty_phase9g_stdout_and_stderr_logs",
        "fallback_policy": "explicit_cranelift_no_fallback",
        "failure_cleanup": "no_generated_C_request_bundle_or_intermediate_object",
        "cross_environment_policy": "separately_bounded_semantic_reproducibility_cannot_substitute_for_this_phase21_gate",
    }, "native stage identity contract drifted")
    require(record.get("decision_evidence") == {
        "operator_date": "2026-08-27",
        "observed_artifact_bytes": 5696280,
        "all_artifact_bytes_equal": True,
        "all_help_behavior_equal": True,
        "all_build_diagnostics_empty": True,
        "all_linker_logs_empty": True,
    }, "OD-15 decision evidence drifted")
    require(record.get("boundary") == {
        "changes_accepted_Gust_program_meaning": False,
        "adds_or_changes_MIR_operations": False,
        "changes_ABI_layout_or_runtime_symbols": False,
        "changes_bootstrap_seed": False,
        "changes_default_backend_or_fallback": False,
        "edits_stdlib_or_CR15": False,
        "begins_patch21_17": False,
    }, "Patch 21.16 boundary widened")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 21.16 — Native Rebuild Reproducibility Authority — DONE"
            in task, "TASK.md does not mark Patch 21.16 DONE")
    vision = VISION.read_text(encoding="utf-8")
    vision_flat = " ".join(vision.split())
    require("**RESOLVED 2026-08-27 — STRICT BINARY IDENTITY**" in vision
            and "### 111.1 Native self-host reproducibility (OD-15)" in vision
            and "does not weaken or substitute for Phase 21" in vision_flat,
            "VISION OD-15 resolution drifted")

    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 21.16 guard levels drifted")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in justfile and f"{GUARD_L2}:" in justfile,
            "Patch 21.16 just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Patch 21.16 contract guard")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    for token in (
        f"just {GUARD_L1}",
        f"just {GUARD_L2}",
        "make gust phase10-native-package",
        "runs-on: ubuntu-24.04",
        "RUSTUP_TOOLCHAIN: \"1.97.1\"",
        "rustup toolchain install 1.97.1 --profile minimal --no-self-update",
        "ref: ${{ github.event.pull_request.head.sha || github.sha }}",
        "GUST_AUTHORITATIVE_SOURCE_COMMIT: ${{ github.event.pull_request.head.sha || github.sha }}",
    ):
        require(token in workflow, f"dedicated Patch 21.16 workflow lacks {token}")
    for path in (
        "- 'TASK.md'",
        "- 'docs/VISION.md'",
        "- 'gust_v4.c'",
        "- 'compiler/*.gst'",
        "- 'compiler/experiments/cranelift/**'",
        "- 'src/runtime.c'",
        "- 'src/runtime/**'",
    ):
        require(workflow.count(path) == 2,
                f"dedicated workflow does not cover {path} twice")
    return record


def render(record: dict) -> str:
    environment = record["authoritative_environment"]
    evidence = record["decision_evidence"]
    measurements = record["measurements"]
    lines = [
        "# Cranelift Phase 21 Native Rebuild Reproducibility Authority",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase21_native_rebuild_reproducibility.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- OD-15: `{record['od15_resolution']}`",
        f"- Compiler source: `{record['compiler_source']}`",
        "",
        "## Selected authoritative criterion",
        "",
        "Independent native compiler stages must be byte-identical when every",
        "authoritative environment input is identical. A separately bounded",
        "cross-machine or cross-toolchain semantic contract cannot substitute",
        "for or weaken this Phase 21 closure gate.",
        "",
        "## Native stage graph",
        "",
    ]
    lines += [f"- `{stage}`" for stage in record["stage_graph"]]
    lines += [
        "",
        "## Pinned authoritative environment",
        "",
        f"- Source: `{environment['source_commit_policy']}`",
        f"- Runner: `{environment['runner_image']}`",
        f"- Rust: `{environment['rustc_version']}`",
        f"- Cargo: `{environment['cargo_version']}`",
        f"- Cranelift: `{environment['cranelift_version']}` from "
        f"`{environment['cranelift_manifest']}` and the exact locked dependency graph "
        f"in `{environment['cranelift_lockfile']}`",
        f"- Target and flags: `{environment['target']}` / "
        f"`{' '.join(environment['backend_flags'])}`",
        f"- C toolchain: `{environment['cc']} {environment['cc_version']}` / "
        f"`{environment['cflags']}`",
        f"- Linker: `{environment['linker']} {environment['linker_version']}`",
        f"- Runtime: `{environment['runtime_package']}`",
        "- Normalized stage environment:",
    ]
    lines += [f"  - `{key}={value}`"
              for key, value in environment["normalized_environment"].items()]
    lines += [
        "",
        "## Measured decision evidence",
        "",
        f"- Artifact: `{evidence['observed_artifact_bytes']}` bytes and byte-identical "
        "across N1a/N1b/N2/N3.",
        "- Help stdout is byte-identical and help stderr is empty across every stage.",
        f"- Observed elapsed ms: N1a `{measurements['observed_n1a_elapsed_ms']}`, "
        f"N1b `{measurements['observed_n1b_elapsed_ms']}`, "
        f"N2 `{measurements['observed_n2_elapsed_ms']}`, "
        f"N3 `{measurements['observed_n3_elapsed_ms']}`.",
        f"- Observed peak child RSS: `{measurements['observed_peak_rss_kib']}` KiB.",
        "- Build diagnostics and Phase 9G linker logs are empty for every stage.",
        "- The guard compares the live exact workflow-head artifacts without pinning",
        "  legitimate later source commits to one historical artifact digest.",
        "",
        "## Boundary",
        "",
        "Patch 21.16 changes no accepted Gust meaning, MIR operation, ABI/layout/runtime",
        "symbol, bootstrap seed, default backend, fallback policy, Stdlib, or CR-15",
        "authority, and it does not begin Patch 21.17.",
        "",
    ]
    return "\n".join(lines)


def tool_output(command: list[str]) -> str:
    result = run(command, env=os.environ.copy(), timeout=30)
    require(result.returncode == 0 and result.stderr == b"",
            f"tool version probe failed: {' '.join(command)}")
    return result.stdout.decode().strip()


def source_paths() -> list[str]:
    paths = [str(path.relative_to(ROOT)) for path in sorted((ROOT / "compiler").glob("*.gst"))]
    paths += [
        "compiler/experiments/cranelift/Cargo.toml",
        "compiler/experiments/cranelift/Cargo.lock",
        "compiler/experiments/cranelift/src",
        "src/runtime.c",
        "src/runtime",
        "gust_v4.c",
        "Makefile",
    ]
    return paths


def assert_clean_authoritative_sources() -> str:
    head = tool_output(["git", "rev-parse", "HEAD"])
    expected = os.environ.get("GUST_AUTHORITATIVE_SOURCE_COMMIT", head)
    require(head == expected, "checkout is not the exact authoritative workflow head")
    clean = run(["git", "diff", "--quiet", "HEAD", "--", *source_paths()],
                env=os.environ.copy(), timeout=30)
    require(clean.returncode == 0, "authoritative compiler/runtime/toolchain sources are dirty")
    return head


def verify_toolchain(record: dict) -> None:
    environment = record["authoritative_environment"]
    require(tool_output(["rustc", "--version"]) == environment["rustc_version"],
            "rustc version differs from the pinned authority")
    require(tool_output(["cargo", "--version"]) == environment["cargo_version"],
            "cargo version differs from the pinned authority")
    require(tool_output([environment["cc"], "-dumpfullversion"])
            == environment["cc_version"],
            "C compiler version differs from the pinned authority")
    linker = tool_output(["ld", "-v"])
    require(environment["linker"] in linker
            and linker.endswith(environment["linker_version"]),
            "linker version differs from the pinned authority")


def stage_environment(record: dict) -> dict[str, str]:
    environment = dict(record["authoritative_environment"]["normalized_environment"])
    environment["GUST_NATIVE_BACKEND_DRIVER"] = str(WORKER.resolve())
    return environment


def evidence(record: dict) -> None:
    for path in (ROOT / "gust", WORKER, PACKAGED_GUST, RUNTIME_PACKAGE):
        require(path.is_file(), f"evidence prerequisite is missing: {path.relative_to(ROOT)}")
    source_commit = assert_clean_authoritative_sources()
    verify_toolchain(record)
    runtime_hash = sha256(RUNTIME_PACKAGE)
    environment = stage_environment(record)
    measurements = record["measurements"]
    started = time.monotonic()
    deadline = started + measurements["max_suite_elapsed_ms"] / 1000

    with tempfile.TemporaryDirectory(prefix="phase21-16-", dir=ROOT / "build") as raw_tmp:
        tmp = Path(raw_tmp)
        stages: list[tuple[str, Path, int]] = []
        origins: list[tuple[str, Path]] = [
            ("N1a", PACKAGED_GUST),
            ("N1b", PACKAGED_GUST),
        ]
        for stage, origin in origins:
            artifact = tmp / f"gust-{stage.lower()}"
            stage_started = time.monotonic()
            built = run([
                str(origin),
                *record["authoritative_environment"]["backend_flags"],
                "-o", str(artifact),
                record["compiler_source"],
            ], env=environment, timeout=min(
                remaining_timeout(deadline),
                measurements["max_stage_elapsed_ms"] / 1000,
            ))
            elapsed_ms = int((time.monotonic() - stage_started) * 1000)
            require(built.returncode == 0 and built.stdout == built.stderr == b""
                    and artifact.is_file(), f"{stage} publication failed")
            stages.append((stage, artifact, elapsed_ms))

        for stage, origin_stage in (("N2", "N1a"), ("N3", "N2")):
            origin = next(path for name, path, _ in stages if name == origin_stage)
            artifact = tmp / f"gust-{stage.lower()}"
            stage_started = time.monotonic()
            built = run([
                str(origin),
                *record["authoritative_environment"]["backend_flags"],
                "-o", str(artifact),
                record["compiler_source"],
            ], env=environment, timeout=min(
                remaining_timeout(deadline),
                measurements["max_stage_elapsed_ms"] / 1000,
            ))
            elapsed_ms = int((time.monotonic() - stage_started) * 1000)
            require(built.returncode == 0 and built.stdout == built.stderr == b""
                    and artifact.is_file(), f"{stage} publication failed")
            stages.append((stage, artifact, elapsed_ms))

        artifact_bytes = [path.read_bytes() for _, path, _ in stages]
        require(all(data == artifact_bytes[0] for data in artifact_bytes[1:]),
                "N1a/N1b/N2/N3 are not byte-identical")
        artifact_size = len(artifact_bytes[0])
        require(measurements["minimum_artifact_bytes"] <= artifact_size
                <= measurements["maximum_artifact_bytes"],
                "native compiler artifact left its registered size bounds")

        helps = [run([str(path), "--help"], env=environment,
                     timeout=remaining_timeout(deadline))
                 for _, path, _ in stages]
        require(all(result.returncode == 0 for result in helps)
                and all(result.stdout == helps[0].stdout
                        and result.stderr == helps[0].stderr for result in helps[1:])
                and helps[0].stderr == b"",
                "native stage help behavior diverged")

        linker_logs: list[bytes] = []
        for stage, artifact, _ in stages:
            stdout_log = tmp / f".{artifact.name}.phase9g-link.stdout.log"
            stderr_log = tmp / f".{artifact.name}.phase9g-link.stderr.log"
            require(stdout_log.is_file() and stderr_log.is_file(),
                    f"{stage} Phase 9G linker logs are missing")
            linker_logs += [stdout_log.read_bytes(), stderr_log.read_bytes()]
            require(not Path(str(artifact) + ".phase10.bundle").exists()
                    and not Path(str(artifact) + ".phase10.request").exists(),
                    f"{stage} left a request or bundle")
        require(all(log == b"" for log in linker_logs),
                "native stage Phase 9G linker diagnostics are not empty")
        require(not list(tmp.glob("*.c")) and not list(tmp.glob("*.o")),
                "native rebuild route left generated C or intermediate objects")

        suite_elapsed_ms = int((time.monotonic() - started) * 1000)
        peak_rss_kib = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
        require(suite_elapsed_ms <= measurements["max_suite_elapsed_ms"]
                and peak_rss_kib <= measurements["max_peak_rss_kib"],
                "Patch 21.16 evidence exceeded its resource budget")
        require(runtime_hash == sha256(RUNTIME_PACKAGE),
                "runtime package changed during native rebuild evidence")
        require(source_commit == assert_clean_authoritative_sources(),
                "authoritative source commit changed during native rebuild evidence")
        stage_times = " ".join(f"{name.lower()}_elapsed_ms={elapsed}"
                               for name, _, elapsed in stages)
        print(
            f"{GUARD_L2}: ok source_commit={source_commit} {stage_times} "
            f"suite_elapsed_ms={suite_elapsed_ms} peak_rss_kib={peak_rss_kib} "
            f"artifact_bytes={artifact_size} artifact_sha256="
            f"{hashlib.sha256(artifact_bytes[0]).hexdigest()} help_stdout_sha256="
            f"{hashlib.sha256(helps[0].stdout).hexdigest()} runtime_sha256={runtime_hash}"
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
