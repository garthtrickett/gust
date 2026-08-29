#!/usr/bin/env python3
"""Validate, project, and run Patch 21.17 complete native guard evidence."""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import re
import shutil
import signal
import subprocess
import threading
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
RUNNER = ROOT / "tests/test_runner.gst"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE21_COMPLETE_GUARD_SUITE.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase21-complete-guard-suite.yml"
WORKER = ROOT / "build/gust-native-backend"
PACKAGED_GUST = ROOT / "build/phase10-package/bin/gust"
RUNTIME_PACKAGE = ROOT / "build/phase10-package/bin/gust-runtime-package.a"
GUARD_L1 = "guard-cranelift-phase21-complete-guard-suite-contract"
GUARD_L2 = "guard-cranelift-phase21-complete-guard-suite-evidence"
ASAN_FIBER_EXIT_WARNING = re.compile(
    rb"==\d+==WARNING: ASan is ignoring requested "
    rb"__asan_handle_no_return: stack type: default top: 0x[0-9a-fA-F]+; "
    rb"bottom 0x[0-9a-fA-F]+; size: 0x[0-9a-fA-F]+ \(\d+\)\n"
    rb"False positive error reports may follow\n"
    rb"For details see https://github\.com/google/sanitizers/issues/189\n?"
)


class DeadlineExceeded(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def run(command: list[str], *, env: dict[str, str] | None = None,
        timeout: float | None = None,
        cwd: Path = ROOT) -> subprocess.CompletedProcess[bytes]:
    process = subprocess.Popen(
        command, cwd=cwd, env=env, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, start_new_session=True,
    )
    try:
        stdout, stderr = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired as error:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.communicate()
        raise DeadlineExceeded(
            f"subprocess exceeded remaining suite deadline: {' '.join(command)}"
        ) from error
    return subprocess.CompletedProcess(command, process.returncode,
                                       stdout, stderr)


def remaining(deadline: float) -> float:
    value = deadline - time.monotonic()
    if value <= 0:
        raise DeadlineExceeded("registered suite deadline was exhausted")
    return value


def run_before(deadline: float, command: list[str], *,
               env: dict[str, str] | None = None,
               cwd: Path = ROOT) -> subprocess.CompletedProcess[bytes]:
    return run(command, env=env, timeout=remaining(deadline), cwd=cwd)


def decode_gust_string(value: str) -> str:
    result = ""
    index = 0
    escapes = {"n": "\n", "r": "\r", "t": "\t", '"': '"', "\\": "\\"}
    while index < len(value):
        if value[index] == "\\" and index + 1 < len(value) \
                and value[index + 1] in escapes:
            result += escapes[value[index + 1]]
            index += 2
        else:
            result += value[index]
            index += 1
    return result


def runner_cases() -> list[dict]:
    source = RUNNER.read_text(encoding="utf-8")
    name = r"(t[A-Za-z0-9_]+)"
    paths = dict(re.findall(
        rf'(?m)^\s*{name}\.path = "([^"]+)";', source))
    modes = {key: int(value) for key, value in re.findall(
        rf'(?m)^\s*{name}\.is_negative = ([012]);', source)}
    substrings = {key: int(value) for key, value in re.findall(
        rf'(?m)^\s*{name}\.is_substring = ([01]);', source)}
    expected = dict(re.findall(
        rf'(?m)^\s*{name}\.expected = "((?:[^"\\]|\\.)*)";', source))
    order = re.findall(rf'(?m)^\s*tests\.Push\({name}\);', source)
    require(len(order) == len(set(order)), "test-runner case names are duplicated")
    require(all(key in paths and key in modes and key in expected for key in order),
            "test-runner case metadata is incomplete")
    return [{
        "name": key,
        "path": paths[key],
        "mode": modes[key],
        "substring": substrings.get(key, 0),
        "expected": decode_gust_string(expected[key]),
    } for key in order]


def authority() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase21_complete_guard_suite")
    require(isinstance(record, dict), "Patch 21.17 authority is missing")
    return record


def resolved_runtime_divergences(registry: dict, record: dict) -> set[str]:
    """Return exact successor-owned resolutions without rewriting Phase 21 history."""
    successor = registry.get("phase22_preflip_default_cohort", {})
    require(successor.get("contract_version") ==
            "phase22_preflip_default_cohort_v1",
            "Patch 22.5 successor authority is missing")
    resolution = successor.get("resolved_phase21_runtime_divergences", {})
    historical = {
        row["fixture"] for row in record["classification"]["runtime_divergences"]
    }
    resolved = set(resolution.get("fixtures", []))
    require(resolution.get("count") == len(resolved) == 3 and
            resolved == historical,
            "Patch 22.5 runtime-divergence resolution drifted")
    require(resolution.get("root_cause") ==
            "generic_ZeroInitialize_lowering_used_zero_for_empty_Index" and
            resolution.get("oracle_contract") ==
            "empty_Index_is_the_0xFFFFFFFF_absence_sentinel" and
            resolution.get("native_correction") ==
            "Index_typed_ZeroInitialize_emits_i32_minus_one" and
            resolution.get("other_zero_initialization") == "unchanged_zero",
            "Patch 22.5 generic sentinel correction drifted")
    return resolved


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    predecessor = registry.get("phase21_native_rebuild_reproducibility", {})
    require(predecessor.get("status") == "patch21_16_complete" and
            predecessor.get("next_patch") == "21.17",
            "Patch 21.16 predecessor authority drifted")
    record = authority()
    expected = {
        "contract_version": "phase21_complete_guard_suite_v1",
        "status": "patch21_17_complete",
        "next_patch": "21.18",
        "review_view": "compiler/CRANELIFT_PHASE21_COMPLETE_GUARD_SUITE.md",
        "predecessor_authority": "phase21_native_rebuild_reproducibility_v1",
        "compiler_origin": "Cranelift_built_full_compiler",
        "target_backend": "explicit_cranelift_no_fallback",
        "semantic_oracle": "same_Cranelift_built_compiler_explicit_mir_to_c",
        "inventory_source": "tests/test_runner.gst",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")
    resolved_runtime_divergences(registry, record)

    cases = runner_cases()
    inventory = record.get("inventory", {})
    observed = {
        "total": len(cases),
        "positive": sum(case["mode"] == 0 for case in cases),
        "compile_fail": sum(case["mode"] == 1 for case in cases),
        "runtime_failure": sum(case["mode"] == 2 for case in cases),
    }
    require(inventory == observed == {
        "total": 326, "positive": 216, "compile_fail": 104,
        "runtime_failure": 6,
    }, "complete test-runner inventory drifted")
    require(record.get("execution_shards") == {
        "count": 2,
        "isolation": "detached_git_worktree_per_serial_shard",
        "assignment": "runner_index_modulo_shard_count",
        "memory_measurement": "aggregate_live_proc_tree_rss",
    }, "complete-suite shard authority drifted")
    scaling = record.get("resolved_scaling_predecessor")
    require(scaling == {
        "authority": "phase21_roadmap_patch21_16b",
        "status": "complete",
        "required_operation_count": 1024,
        "passing_case_count": 34,
        "observed_large_function_peak_rss_kib": 95488,
        "post_merge_correction": "compiler_origin_selection_and_local_state_linear_canonical_transport",
        "compiler_origin_policy": "GUST_COMPILER_is_consumed_by_the_inherited_scale_harness_and_names_the_Cranelift_built_compiler_under_test",
        "corrected_emitter": "compiler/mir_native_backend_local_state_source.gst",
        "byte_identity_operation_count": 256,
        "changes_compiler_semantics": False,
        "falsifier": "the_Cranelift_built_compiler_completes_the_unchanged_1024_operation_cohort_with_MIR_to_C_parity_inside_registered_budgets",
    }, "native-compiler allocation-scaling predecessor drifted")
    roadmap = registry.get("phase21_roadmap", {})
    require(scaling in [{
        "authority": "phase21_roadmap_patch21_16b",
        "status": row.get("status"),
        "required_operation_count": row.get("required_operation_count"),
        "passing_case_count": row.get("passing_case_count"),
        "observed_large_function_peak_rss_kib": row.get(
            "observed_large_function_peak_rss_kib"),
        "post_merge_correction": row.get("post_merge_correction"),
        "compiler_origin_policy": row.get("compiler_origin_policy"),
        "corrected_emitter": row.get("corrected_emitter"),
        "byte_identity_operation_count": row.get(
            "byte_identity_operation_count"),
        "changes_compiler_semantics": row.get(
            "changes_compiler_semantics"),
        "falsifier": row.get("falsifier"),
    } for row in roadmap.get("amendments", []) if row.get("patch") == "21.16b"],
            "Patch 21.16b registry authority does not support completion")

    classification = record.get("classification", {})
    reason_counts = classification.get("compile_deferral_reason_counts", {})
    require(sum(reason_counts.values()) == 121 and
            classification.get("oracle_precondition_failure_count") == 10 and
            classification.get("runtime_divergence_count") == 3 and
            classification.get("required_native_case_count") == 192 and
            classification.get("total_classified_deferral_count") == 134 and
            192 + 134 == inventory["total"],
            "Patch 21.17 classification is incomplete")
    oracle_cases = classification.get("oracle_precondition_failures", [])
    runtime_cases = classification.get("runtime_divergences", [])
    require(len(oracle_cases) == 10 and len(runtime_cases) == 3,
            "explicit exceptional classification rows drifted")
    all_paths = {case["path"] for case in cases}
    exceptional = {row["fixture"] for row in oracle_cases + runtime_cases}
    require(len(exceptional) == 13 and exceptional <= all_paths,
            "exceptional classification fixtures drifted")
    for row in oracle_cases + runtime_cases:
        require(row.get("owner") and row.get("destination") and
                row.get("reason_code") and row.get("falsifier"),
                f"classification row lacks ownership: {row}")

    budgets = record.get("budgets", {})
    require(budgets.get("measurement_protocol") ==
            "two_isolated_serial_shards_monotonic_elapsed_and_aggregate_proc_tree_peak_rss" and
            all(isinstance(budgets.get(key), int) and budgets[key] > 0 for key in (
                "max_native_compiler_build_ms", "max_corpus_suite_ms",
                "max_complete_suite_ms", "max_peak_rss_kib",
            )), "Patch 21.17 resource budgets drifted")
    require(record.get("budget_replays") == [
        "phase20_generated_mir_scale_full",
        "phase20_long_lived_concurrent_full",
        "phase20_cross_feature_qualification_full",
    ], "Patch 21.17 full budget replay set drifted")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 21.17 — Complete Guard Suite and Resource Budgets — DONE"
            in task, "TASK.md does not mark Patch 21.17 complete")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 21.17 guard levels drifted")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in justfile and f"{GUARD_L2}:" in justfile,
            "Patch 21.17 just guards are missing")
    pr_fast = PR_FAST.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in pr_fast,
            "PR Fast does not own the Patch 21.17 contract")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    for needle in ("pull_request:", "gust_v4.c", "src/runtime.c",
                   "src/runtime/**", "tools/normalize_generated_arena_offsets.py",
                   f"just {GUARD_L2}"):
        require(needle in workflow, f"Patch 21.17 workflow lacks {needle}")
    for path in (
        ROOT / "scripts/phase20_generated_mir_scale.py",
        ROOT / "scripts/phase20_long_lived_concurrent.sh",
        ROOT / "scripts/phase20_cross_feature_qualification.sh",
    ):
        require("GUST_COMPILER" in path.read_text(encoding="utf-8"),
                f"native compiler-origin override missing from {path}")
    return record


def render(record: dict) -> str:
    inventory = record["inventory"]
    classification = record["classification"]
    budgets = record["budgets"]
    lines = [
        "# Cranelift Phase 21 Complete Guard Suite and Budgets", "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase21_complete_guard_suite.py project`. Do not edit by hand.",
        "", f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`", f"- Next patch: `{record['next_patch']}`",
        f"- Compiler origin: `{record['compiler_origin']}`",
        f"- Target route: `{record['target_backend']}`",
        f"- Oracle: `{record['semantic_oracle']}`", "", "## Complete inventory", "",
        f"- Total: `{inventory['total']}`",
        f"- Positive: `{inventory['positive']}`",
        f"- Compile-fail: `{inventory['compile_fail']}`",
        f"- Runtime-failure: `{inventory['runtime_failure']}`",
        f"- Required native cases: `{classification['required_native_case_count']}`",
        f"- Classified deferrals: `{classification['total_classified_deferral_count']}`",
        f"- Isolated serial shards: `{record['execution_shards']['count']}`",
        "", "## Compile deferrals", "",
        "| Reason | Cases |", "| --- | ---: |",
    ]
    for reason, count in classification["compile_deferral_reason_counts"].items():
        lines.append(f"| `{reason}` | {count} |")
    lines += ["", "## Explicit oracle preconditions", ""]
    for row in classification["oracle_precondition_failures"]:
        lines.append(f"- `{row['fixture']}` — `{row['reason_code']}`; owner "
                     f"`{row['owner']}`; destination `{row['destination']}`")
    lines += ["", "## Explicit runtime divergences", ""]
    for row in classification["runtime_divergences"]:
        lines.append(f"- `{row['fixture']}` — `{row['reason_code']}`; owner "
                     f"`{row['owner']}`; destination `{row['destination']}`")
    lines += ["", "## Resource budgets", "",
              f"- Protocol: `{budgets['measurement_protocol']}`",
              f"- Native compiler build maximum: `{budgets['max_native_compiler_build_ms']}` ms",
              f"- Corpus suite maximum: `{budgets['max_corpus_suite_ms']}` ms",
              f"- Complete suite maximum: `{budgets['max_complete_suite_ms']}` ms",
              f"- Peak RSS maximum: `{budgets['max_peak_rss_kib']}` KiB",
              "", "## Full inherited budget replay", ""]
    lines += [f"- `{name}`" for name in record["budget_replays"]]
    scaling = record["resolved_scaling_predecessor"]
    lines += ["", "## Resolved scaling predecessor", "",
              f"- Authority: `{scaling['authority']}`",
              f"- Status: `{scaling['status']}`",
              f"- Required operation count: `{scaling['required_operation_count']}`",
              f"- Passing cases: `{scaling['passing_case_count']}`",
              f"- Observed large-function peak RSS: "
              f"`{scaling['observed_large_function_peak_rss_kib']}` KiB",
              f"- Compiler origin policy: `{scaling['compiler_origin_policy']}`",
              f"- Corrected emitter: `{scaling['corrected_emitter']}`",
              f"- Byte-identity operation count: "
              f"`{scaling['byte_identity_operation_count']}`",
              f"- Falsifier: `{scaling['falsifier']}`"]
    lines += ["", "Every case in the self-hosted runner inventory is either a",
              "required native pass or an owned, reason-coded deferral with a",
              "falsifier. The target leg is explicit Cranelift with no fallback;",
              "MIR-to-C is invoked only as the semantic oracle. No unexplained",
              "failure or unclassified inventory row is permitted.", ""]
    return "\n".join(lines)


def clean_sanitizer_fiber_exit_warning(value: bytes) -> bytes:
    return ASAN_FIBER_EXIT_WARNING.sub(b"", value)


def clean_output(value: bytes) -> bytes:
    value = clean_sanitizer_fiber_exit_warning(value)
    lines = value.split(b"\n")
    return b"\n".join(line for line in lines
                       if not line.startswith((bytes([226]), bytes([240]),
                                               bytes([243])))).strip()


def write_logs(case_dir: Path, prefix: str,
               completed: subprocess.CompletedProcess[bytes]) -> None:
    (case_dir / f"{prefix}.stdout").write_bytes(completed.stdout)
    (case_dir / f"{prefix}.stderr").write_bytes(completed.stderr)
    (case_dir / f"{prefix}.status").write_text(
        f"{completed.returncode}\n", encoding="utf-8")


def observable_mismatch_detail(
        oracle: subprocess.CompletedProcess[bytes],
        native: subprocess.CompletedProcess[bytes]) -> str:
    def detail(label: str,
               completed: subprocess.CompletedProcess[bytes]) -> str:
        stdout_tail = completed.stdout[-256:]
        stderr_tail = completed.stderr[-256:]
        return (
            f"{label}(status={completed.returncode}, "
            f"stdout_len={len(completed.stdout)}, "
            f"stdout_tail={stdout_tail!r}, "
            f"stderr_len={len(completed.stderr)}, "
            f"stderr_tail={stderr_tail!r})"
        )

    return f"{detail('oracle', oracle)}; {detail('native', native)}"


def compile_case(deadline: float, compiler: Path, case: dict, backend: str,
                 output: Path, env: dict[str, str],
                 cwd: Path) -> subprocess.CompletedProcess[bytes]:
    command = [str(compiler), "--backend", backend]
    if backend == "cranelift":
        command += ["-o", str(output)]
    command.append(case["path"])
    return run_before(deadline, command, env=env, cwd=cwd)


def compile_c(deadline: float, source: bytes, output: Path, mode: int,
              cwd: Path) -> None:
    c_path = output.with_suffix(".final.c")
    c_path.write_bytes((cwd / "src/runtime.c").read_bytes() + b"\n" + source)
    command = [os.environ.get("CC", "cc"), "-O2", "-Wall", "-pthread", "-Isrc"]
    if mode == 2:
        command += ["-fsanitize=address", "-DGUST_DEBUG"]
    command += [str(c_path), "-o", str(output)]
    completed = run_before(deadline, command, cwd=cwd)
    require(completed.returncode == 0,
            f"oracle host compilation failed for {output.name}: "
            f"{completed.stderr.decode(errors='replace')[-500:]}")


def expected_execution(case: dict, completed: subprocess.CompletedProcess[bytes]) -> bool:
    actual = clean_output(completed.stdout + completed.stderr)
    expected = case["expected"].strip().encode()
    if case["mode"] == 2:
        return completed.returncode != 0 and expected in actual
    if case["substring"] == 1:
        return completed.returncode == 0 and expected in actual
    return completed.returncode == 0 and actual == expected


def prepare_execution(case: dict, cwd: Path) -> None:
    if "e2e_fallible_guard_bootstrap" in case["path"]:
        nested = cwd / "temp_e2e_guard_test_dir/nested"
        nested.mkdir(parents=True, exist_ok=True)
        (nested / "file1.gst").write_text("func main() {}\n", encoding="utf-8")
    if "e2e_filesystem_ops" in case["path"]:
        directory = cwd / "temp_e2e_filesystem_dir"
        directory.mkdir(parents=True, exist_ok=True)
        (directory / "file1.gst").write_text("func main() {}\n", encoding="utf-8")
        (directory / "file2.txt").write_text("plain text\n", encoding="utf-8")


def cleanup_execution(case: dict, cwd: Path) -> None:
    if "e2e_fallible_guard_bootstrap" in case["path"]:
        shutil.rmtree(cwd / "temp_e2e_guard_test_dir", ignore_errors=True)
    if "e2e_filesystem_ops" in case["path"]:
        shutil.rmtree(cwd / "temp_e2e_filesystem_dir", ignore_errors=True)
        try:
            (cwd / "temp_e2e_filesystem_test.txt").unlink()
        except FileNotFoundError:
            pass


def no_failed_artifacts(case_dir: Path, native_output: Path) -> bool:
    forbidden = [native_output, native_output.with_suffix(".o"),
                 native_output.with_suffix(".c"),
                 native_output.with_suffix(".request"),
                 native_output.with_suffix(".bundle")]
    return not any(path.exists() for path in forbidden)


def process_tree_rss_kib(root_pid: int) -> int:
    processes: dict[int, tuple[int, int]] = {}
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            fields = {}
            for line in (entry / "status").read_text(encoding="utf-8").splitlines():
                if ":" in line:
                    key, value = line.split(":", 1)
                    fields[key] = value.strip()
            pid = int(entry.name)
            ppid = int(fields.get("PPid", "-1"))
            rss = int(fields.get("VmRSS", "0 kB").split()[0])
            processes[pid] = (ppid, rss)
        except (FileNotFoundError, PermissionError, ProcessLookupError, ValueError):
            continue
    descendants = {root_pid}
    changed = True
    while changed:
        changed = False
        for pid, (ppid, _) in processes.items():
            if ppid in descendants and pid not in descendants:
                descendants.add(pid)
                changed = True
    return sum(processes.get(pid, (-1, 0))[1] for pid in descendants)


def sample_peak_rss(stop: threading.Event, result: list[int]) -> None:
    root_pid = os.getpid()
    while not stop.wait(0.05):
        result[0] = max(result[0], process_tree_rss_kib(root_pid))
    result[0] = max(result[0], process_tree_rss_kib(root_pid))


def create_shards(deadline: float, count: int) -> tuple[Path, list[Path]]:
    base = ROOT.parent / f".gust-phase21-17-shards-{os.getpid()}"
    require(not base.exists(), f"stale shard root exists: {base}")
    roots = []
    for index in range(count):
        path = base / f"shard-{index}"
        completed = run_before(deadline, [
            "git", "worktree", "add", "--detach", str(path), "HEAD",
        ])
        require(completed.returncode == 0,
                f"could not create isolated corpus shard {index}: "
                f"{completed.stderr.decode(errors='replace')[-500:]}")
        roots.append(path)
    return base, roots


def remove_shards(base: Path, roots: list[Path]) -> None:
    for path in roots:
        completed = run(["git", "worktree", "remove", "--force", str(path)],
                        timeout=60)
        require(completed.returncode == 0,
                f"could not remove isolated corpus shard: {path}")
    shutil.rmtree(base, ignore_errors=True)


def qualify_case(deadline: float, native_compiler: Path, env: dict[str, str],
                 output: Path, case: dict, index: int, cwd: Path,
                 oracle_rows: dict[str, dict],
                 runtime_rows: dict[str, dict],
                 compile_reasons: dict[str, int]) -> tuple[str, str]:
    case_dir = output / f"case-{index:03d}"
    case_dir.mkdir()
    native_output = case_dir / "native-program"
    oracle_output = case_dir / "oracle-program"
    oracle = compile_case(deadline, native_compiler, case, "mir-to-c",
                          oracle_output, env, cwd)
    write_logs(case_dir, "oracle-compile", oracle)
    native_env = dict(env)
    native_env["GUST_TEST_MIR_TO_C_UNAVAILABLE"] = "1"

    if case["path"] in oracle_rows:
        native = compile_case(deadline, native_compiler, case, "cranelift",
                              native_output, native_env, cwd)
        write_logs(case_dir, "native-compile", native)
        require(oracle.returncode != 0 and native.returncode != 0 and
                oracle.stdout == native.stdout and
                oracle.stderr == native.stderr and
                no_failed_artifacts(case_dir, native_output),
                f"oracle precondition classification drifted: {case['path']}")
        return "deferral", ""

    if case["mode"] == 1:
        native = compile_case(deadline, native_compiler, case, "cranelift",
                              native_output, native_env, cwd)
        write_logs(case_dir, "native-compile", native)
        require(oracle.returncode != 0 and native.returncode != 0 and
                oracle.stdout == native.stdout and
                oracle.stderr == native.stderr and
                case["expected"].encode() in oracle.stdout + oracle.stderr and
                no_failed_artifacts(case_dir, native_output),
                f"compile-fail parity or cleanup drifted: {case['path']}")
        return "required", ""

    require(oracle.returncode == 0 and not oracle.stderr,
            f"MIR-to-C oracle failed unexpectedly: {case['path']}")
    native = compile_case(deadline, native_compiler, case, "cranelift",
                          native_output, native_env, cwd)
    write_logs(case_dir, "native-compile", native)
    if native.returncode != 0:
        combined = (native.stdout + native.stderr).decode(errors="replace")
        matches = re.findall(r"reason_code=([^ ]+)", combined)
        reason = matches[-1] if matches else ""
        if reason == "supported" and case["path"] == \
                "compiler/typechecker_origins_test_entry.gst":
            reason = "inconsistent_abi_equivalent_import_signature"
            require("inconsistent signatures" in combined,
                    "ABI-equivalent import-signature deferral drifted")
        else:
            require("expected_failure_stage=before_driver_discovery" in combined,
                    f"deferral failure stage drifted: {case['path']}")
        require(reason in compile_reasons and
                no_failed_artifacts(case_dir, native_output),
                f"unclassified native compile deferral: {case['path']}")
        return "deferral", reason

    compile_c(deadline, oracle.stdout, oracle_output, case["mode"], cwd)
    prepare_execution(case, cwd)
    try:
        oracle_run = run_before(deadline, [str(oracle_output)], cwd=cwd)
    finally:
        cleanup_execution(case, cwd)
    write_logs(case_dir, "oracle-run", oracle_run)
    require(expected_execution(case, oracle_run),
            f"MIR-to-C oracle observable drifted: {case['path']}")

    prepare_execution(case, cwd)
    try:
        native_run = run_before(deadline, [str(native_output)], cwd=cwd)
    finally:
        cleanup_execution(case, cwd)
    write_logs(case_dir, "native-run", native_run)
    if case["path"] in runtime_rows:
        require(not expected_execution(case, native_run),
                f"runtime deferral was fixed; reclassify {case['path']}")
        return "deferral", ""
    require(expected_execution(case, native_run) and
            native_run.returncode == oracle_run.returncode and
            native_run.stdout == oracle_run.stdout and
            clean_sanitizer_fiber_exit_warning(native_run.stderr) ==
            clean_sanitizer_fiber_exit_warning(oracle_run.stderr),
            f"unexplained native observable divergence: {case['path']}; "
            f"{observable_mismatch_detail(oracle_run, native_run)}")
    return "required", ""


def evidence() -> None:
    record = validate()
    budgets = record["budgets"]
    suite_started = time.monotonic()
    deadline = suite_started + budgets["max_complete_suite_ms"] / 1000
    output = ROOT / "build/guards/phase21_complete_guard_suite"
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    for path in (WORKER, PACKAGED_GUST, RUNTIME_PACKAGE):
        require(path.is_file(), f"missing prerequisite: {path}")
    peak_rss = [process_tree_rss_kib(os.getpid())]
    peak_stop = threading.Event()
    peak_thread = threading.Thread(
        target=sample_peak_rss, args=(peak_stop, peak_rss), daemon=True)
    peak_thread.start()

    native_compiler = output / "native-gust"
    env = os.environ.copy()
    env["GUST_NATIVE_BACKEND_DRIVER"] = str(WORKER.resolve())
    env["GUST_NATIVE_RUNTIME_PACKAGE"] = str(RUNTIME_PACKAGE.resolve())
    build_started = time.monotonic()
    built = run_before(deadline, [str(PACKAGED_GUST), "--backend", "cranelift",
                                  "-o", str(native_compiler),
                                  "compiler/test_runner_entry.gst"], env=env)
    write_logs(output, "native-compiler-build", built)
    build_ms = int((time.monotonic() - build_started) * 1000)
    require(built.returncode == 0 and native_compiler.is_file() and
            not built.stdout and not built.stderr and
            build_ms <= budgets["max_native_compiler_build_ms"],
            "native compiler build failed or exceeded its budget")

    classification = record["classification"]
    oracle_rows = {row["fixture"]: row for row in
                   classification["oracle_precondition_failures"]}
    resolved_runtime = resolved_runtime_divergences(
        json.loads(REGISTRY.read_text(encoding="utf-8")), record)
    runtime_rows = {row["fixture"]: row for row in
                    classification["runtime_divergences"]
                    if row["fixture"] not in resolved_runtime}
    reason_counts: dict[str, int] = {}
    required_count = 0
    deferral_count = 0
    corpus_started = time.monotonic()
    cases = runner_cases()
    shard_base, shard_roots = create_shards(
        deadline, record["execution_shards"]["count"])
    executors = [concurrent.futures.ThreadPoolExecutor(max_workers=1)
                 for _ in shard_roots]
    futures = []
    try:
        for index, case in enumerate(cases):
            shard_index = index % len(shard_roots)
            futures.append(executors[shard_index].submit(
                qualify_case, deadline, native_compiler, env, output, case,
                index, shard_roots[shard_index], oracle_rows, runtime_rows,
                classification["compile_deferral_reason_counts"],
            ))
        for future in futures:
            disposition, reason = future.result()
            if disposition == "required":
                required_count += 1
            else:
                deferral_count += 1
            if reason:
                reason_counts[reason] = reason_counts.get(reason, 0) + 1
    finally:
        for future in futures:
            if not future.done():
                future.cancel()
        for executor in executors:
            executor.shutdown(wait=True, cancel_futures=True)
        remove_shards(shard_base, shard_roots)

    require(reason_counts == classification["compile_deferral_reason_counts"],
            f"compile deferral population drifted: {reason_counts}")
    require(required_count ==
            classification["required_native_case_count"] + len(resolved_runtime) and
            deferral_count ==
            classification["total_classified_deferral_count"] - len(resolved_runtime),
            "complete classified population count drifted")
    corpus_ms = int((time.monotonic() - corpus_started) * 1000)
    require(corpus_ms <= budgets["max_corpus_suite_ms"],
            "complete corpus exceeded its elapsed budget")

    replay_env = dict(env)
    replay_env["GUST_COMPILER"] = str(native_compiler.resolve())
    commands = [
        ["python3", "scripts/phase20_generated_mir_scale.py", "run",
         "--profile", "full", "--output",
         "build/guards/phase21_complete_guard_generated_scale"],
        ["bash", "scripts/phase20_long_lived_concurrent.sh", "full"],
        ["bash", "scripts/phase20_cross_feature_qualification.sh", "full"],
    ]
    for index, command in enumerate(commands):
        completed = run_before(deadline, command, env=replay_env)
        write_logs(output, f"budget-replay-{index}", completed)
        require(completed.returncode == 0,
                f"inherited full budget replay failed: {' '.join(command)}\n"
                f"{completed.stderr.decode(errors='replace')[-1000:]}")

    suite_ms = int((time.monotonic() - suite_started) * 1000)
    peak_stop.set()
    peak_thread.join(timeout=1)
    require(suite_ms <= budgets["max_complete_suite_ms"] and
            peak_rss[0] <= budgets["max_peak_rss_kib"],
            "Patch 21.17 complete evidence exceeded its resource budget")
    (output / "measurements.json").write_text(json.dumps({
        "native_compiler_build_ms": build_ms,
        "corpus_suite_ms": corpus_ms,
        "complete_suite_ms": suite_ms,
        "peak_rss_kib": peak_rss[0],
        "required_native_cases": required_count,
        "classified_deferrals": deferral_count,
    }, indent=2) + "\n", encoding="utf-8")
    print(f"{GUARD_L2}: ok required={required_count} deferrals={deferral_count} "
          f"build_ms={build_ms} corpus_ms={corpus_ms} suite_ms={suite_ms} "
          f"peak_rss_kib={peak_rss[0]}")


def deadline_regression() -> None:
    try:
        run(["bash", "-c", "while :; do :; done"], timeout=0.05)
    except DeadlineExceeded:
        print(f"{GUARD_L1}: deadline regression ok")
        return
    require(False, "deadline regression did not stop the child process group")


def observable_diagnostic_regression() -> None:
    oracle = subprocess.CompletedProcess(
        ["oracle"], 1, b"expected\n", b"")
    native = subprocess.CompletedProcess(
        ["native"], 0, b"unexpected\n", b"native diagnostic\n")
    observed = observable_mismatch_detail(oracle, native)
    expected = (
        "oracle(status=1, stdout_len=9, stdout_tail=b'expected\\n', "
        "stderr_len=0, stderr_tail=b''); "
        "native(status=0, stdout_len=11, stdout_tail=b'unexpected\\n', "
        "stderr_len=18, stderr_tail=b'native diagnostic\\n')"
    )
    require(observed == expected,
            "observable mismatch diagnostic regression drifted")
    scheduler_warning = (
        b"==123==WARNING: ASan is ignoring requested "
        b"__asan_handle_no_return: stack type: default top: 0x7fff0000; "
        b"bottom 0x7f000000; size: 0x00ff0000 (16711680)\n"
        b"False positive error reports may follow\n"
        b"For details see https://github.com/google/sanitizers/issues/189\n"
    )
    actual_report = b"ERROR: AddressSanitizer: heap-use-after-free\n"
    require(clean_sanitizer_fiber_exit_warning(
                scheduler_warning + actual_report) == actual_report,
            "ASan scheduler warning normalization drifted")
    require(clean_sanitizer_fiber_exit_warning(scheduler_warning[:-10]) != b"",
            "partial ASan scheduler warning was hidden")
    print(f"{GUARD_L1}: observable diagnostic regression ok")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=(
        "validate", "project", "check-review", "evidence",
        "deadline-regression", "observable-diagnostic-regression",
    ))
    args = parser.parse_args()
    record = validate()
    if args.command == "project":
        REVIEW.write_text(render(record), encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and
                REVIEW.read_text(encoding="utf-8") == render(record),
                "generated review is stale; run project")
    elif args.command == "evidence":
        evidence()
        return
    elif args.command == "deadline-regression":
        deadline_regression()
        return
    elif args.command == "observable-diagnostic-regression":
        observable_diagnostic_regression()
        return
    print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
