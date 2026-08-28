#!/usr/bin/env python3
"""Patch 20.14 deterministic canonical-MIR generation and scale harness."""

from __future__ import annotations

import argparse
import json
import os
import resource
import shutil
import statistics
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
GUST = os.environ.get("GUST_COMPILER", "./gust")
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_GENERATED_MIR_SCALE.md"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
HISTORICAL = ROOT / ".github/workflows/cranelift-historical-full.yml"
JUSTFILE = ROOT / "justfile"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
GUARD_L1 = "guard-cranelift-phase20-generated-mir-scale-contract"
GUARD_L2 = "guard-cranelift-phase20-generated-mir-sample-parity"
GUARD_L3 = "guard-cranelift-phase20-generated-mir-scale-full"
COMPOSITION_L3 = "guard-cranelift-phase20-cross-feature-qualification-full"


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def authority() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    value = registry.get("phase20_generated_mir_scale")
    require(isinstance(value, dict), "Patch 20.14 authority is missing")
    return value


def validate() -> dict:
    value = authority()
    require(value.get("contract_version") == "phase20_generated_mir_scale_v1",
            "Patch 20.14 contract version drifted")
    require(value.get("status") == "patch20_14_complete" and
            value.get("next_patch") == "20.14h",
            "Patch 20.14 status or successor drifted")
    require(value.get("generator") ==
            "scripts/phase20_generated_mir_scale.py",
            "Patch 20.14 generator drifted")
    require(value.get("harness") ==
            "scripts/phase20_generated_mir_scale.py run",
            "Patch 20.14 harness drifted")
    require(value.get("algorithm") ==
            "lcg32_seeded_abstract_scalar_plan_v1",
            "Patch 20.14 deterministic algorithm drifted")
    require(value.get("canonical_mir_constraint") ==
            "validated_i32_scalar_local_operations_and_acyclic_local_calls_only",
            "Patch 20.14 canonical MIR constraint drifted")
    require(value.get("route_policy") ==
            "generated_scalars_and_large_function_use_three_way_source_and_direct_mir_agreement_while_large_module_uses_mir_to_c_source_oracle_against_direct_canonical_mir_because_the_source_native_planner_intentionally_rejects_unregistered_call_graph_shapes",
            "Patch 20.14 route policy drifted")
    require(value.get("normalization_policy") == "none",
            "Patch 20.14 silently permits normalization")

    seed_sets = value.get("recorded_seed_sets")
    require(isinstance(seed_sets, dict) and
            seed_sets.get("level2") == [1, 7, 19, 42] and
            seed_sets.get("level3") == list(range(1, 33)),
            "Patch 20.14 recorded seeds drifted")
    require(len(set(seed_sets["level3"])) == len(seed_sets["level3"]),
            "Patch 20.14 Level 3 seeds are not unique")

    cohorts = value.get("cohorts")
    require(isinstance(cohorts, list) and len(cohorts) == 4,
            "Patch 20.14 cohort inventory drifted")
    by_id = {row.get("id"): row for row in cohorts}
    require(set(by_id) == {
        "small_generated_scalar", "full_generated_scalar",
        "large_function", "large_module",
    }, "Patch 20.14 cohort identities drifted")
    require(by_id["small_generated_scalar"] == {
        "id": "small_generated_scalar", "level": 2,
        "seed_set": "level2", "operation_count": 8,
    }, "Patch 20.14 Level 2 cohort drifted")
    require(by_id["full_generated_scalar"] == {
        "id": "full_generated_scalar", "level": 3,
        "seed_set": "level3", "operation_count": 24,
    }, "Patch 20.14 full generated cohort drifted")
    require(by_id["large_function"] == {
        "id": "large_function", "level": 3,
        "operation_count": 1024,
    }, "Patch 20.14 large-function cohort drifted")
    require(by_id["large_module"] == {
        "id": "large_module", "level": 3,
        "function_count": 64,
    }, "Patch 20.14 large-module cohort drifted")

    measurement = value.get("measurement")
    require(isinstance(measurement, dict),
            "Patch 20.14 measurement authority is missing")
    require(measurement.get("protocol") ==
            "fresh_child_process_monotonic_elapsed_and_wait4_maxrss",
            "Patch 20.14 measurement protocol drifted")
    require(measurement.get("warmup_runs") == 1 and
            measurement.get("sample_count") == 3 and
            measurement.get("elapsed_statistic") == "median" and
            measurement.get("memory_statistic") == "maximum",
            "Patch 20.14 sample policy drifted")
    require(measurement.get("threshold_policy") ==
            "fixed_registry_values_reviewed_with_the_patch_no_runtime_rebasing",
            "Patch 20.14 threshold policy drifted")
    budgets = measurement.get("budgets")
    require(isinstance(budgets, list) and len(budgets) == 4,
            "Patch 20.14 budget inventory drifted")
    budget_keys = {(row.get("cohort"), row.get("backend")) for row in budgets}
    require(budget_keys == {
        ("large_function", "mir-to-c"),
        ("large_function", "cranelift"),
        ("large_module", "mir-to-c"),
        ("large_module", "cranelift"),
    }, "Patch 20.14 budget coverage drifted")
    for row in budgets:
        require(all(isinstance(row.get(key), int) and row[key] > 0 for key in (
            "baseline_elapsed_ms", "baseline_peak_rss_kib",
            "max_elapsed_ms", "max_peak_rss_kib",
        )), f"Patch 20.14 invalid budget: {row}")
        require(row["baseline_elapsed_ms"] <= row["max_elapsed_ms"] and
                row["baseline_peak_rss_kib"] <= row["max_peak_rss_kib"],
                f"Patch 20.14 baseline exceeds threshold: {row}")

    failures = value.get("minimized_failures")
    require(isinstance(failures, list),
            "Patch 20.14 minimized-failure inventory is missing")
    for row in failures:
        fixture = ROOT / row["fixture"]
        require(fixture.is_file(),
                f"Patch 20.14 minimized failure is missing: {fixture}")
        require(row.get("seed") in seed_sets["level3"] and row.get("reason"),
                "Patch 20.14 minimized failure lacks seed or reason")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 20.14 — Generated-MIR, Scale, and Resource-Use "
            "Qualification — DONE" in task,
            "TASK.md does not mark Patch 20.14 DONE")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2 and
            levels.get(GUARD_L3) == 3,
            "Patch 20.14 guard levels drifted")
    pr_fast = PR_FAST.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in pr_fast and f"just {GUARD_L2}" in pr_fast,
            "PR Fast does not own both Patch 20.14 Level 1/2 guards")
    require(f"just {GUARD_L3}" not in pr_fast,
            "PR Fast must not run Patch 20.14 Level 3")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(all(f"{guard}:" in justfile
                for guard in (GUARD_L1, GUARD_L2, GUARD_L3)),
            "Patch 20.14 just guards are missing")
    historical = HISTORICAL.read_text(encoding="utf-8")
    composition_recipe = justfile.split(f"{COMPOSITION_L3}:", 1)[1].split(
        "\n\n", 1)[0] if f"{COMPOSITION_L3}:" in justfile else ""
    require("          - phase20" in historical and
            f"phase20) just {COMPOSITION_L3} ;;" in historical and
            f"just {GUARD_L3}" in composition_recipe,
            "Historical Full does not transitively own Patch 20.14 Level 3")
    return value


def render(value: dict) -> str:
    lines = [
        "# Cranelift Phase 20 Generated MIR and Scale Qualification",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_generated_mir_scale.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{value['contract_version']}`",
        f"- Status: `{value['status']}`",
        f"- Next patch: `{value['next_patch']}`",
        f"- Generator: `{value['generator']}`",
        f"- Algorithm: `{value['algorithm']}`",
        f"- Canonical MIR constraint: `{value['canonical_mir_constraint']}`",
        f"- Route policy: `{value['route_policy']}`",
        f"- Normalization: `{value['normalization_policy']}`",
        "",
        "## Recorded cohorts",
        "",
    ]
    for row in value["cohorts"]:
        size = (f"operations `{row['operation_count']}`"
                if "operation_count" in row
                else f"functions `{row['function_count']}`")
        seed = (f"; seeds `{row['seed_set']}`"
                if "seed_set" in row else "")
        lines.append(f"- `{row['id']}` — Level {row['level']}; {size}{seed}")
    measurement = value["measurement"]
    lines += [
        "",
        "## Reproducible resource protocol",
        "",
        f"- Protocol: `{measurement['protocol']}`",
        f"- Warmups: `{measurement['warmup_runs']}`",
        f"- Samples: `{measurement['sample_count']}`",
        f"- Elapsed statistic: `{measurement['elapsed_statistic']}`",
        f"- Memory statistic: `{measurement['memory_statistic']}`",
        f"- Threshold policy: `{measurement['threshold_policy']}`",
        "",
        "| Cohort | Backend | Baseline ms | Baseline KiB | Maximum ms | Maximum KiB |",
        "| --- | --- | ---: | ---: | ---: | ---: |",
    ]
    for row in measurement["budgets"]:
        lines.append(
            f"| `{row['cohort']}` | `{row['backend']}` | "
            f"{row['baseline_elapsed_ms']} | {row['baseline_peak_rss_kib']} | "
            f"{row['max_elapsed_ms']} | {row['max_peak_rss_kib']} |"
        )
    lines += [
        "",
        "## Failure preservation",
        "",
        f"- Policy: {value['failure_preservation_policy']}",
        f"- Committed minimized failures: `{len(value['minimized_failures'])}`",
        "",
        "Every generated scalar plan emits both Gust source and canonical MIR.",
        "The source executes through MIR-to-C and explicit no-fallback Cranelift;",
        "the canonical MIR executes through the generic ingestion worker. Exact",
        "exit status, stdout, and stderr must agree across all three executions.",
        "Level 3 alone owns exhaustive seeds, scale cohorts, and resource budgets.",
        "",
    ]
    return "\n".join(lines)


class Lcg:
    def __init__(self, seed: int):
        self.state = seed & 0xFFFFFFFF

    def next(self) -> int:
        self.state = (1664525 * self.state + 1013904223) & 0xFFFFFFFF
        return self.state


def scalar_plan(seed: int, count: int) -> tuple[int, list[tuple[str, int]], int]:
    rng = Lcg(seed)
    initial = 1 + rng.next() % 19
    value = initial
    operations: list[tuple[str, int]] = []
    for _ in range(count):
        choice = rng.next() % 3
        operand = 1 + rng.next() % 5
        if choice == 0 and value + operand <= 120:
            operation = "add"
            value += operand
        elif choice == 1 and value >= operand:
            operation = "sub"
            value -= operand
        else:
            operation = "mul"
            operand = 1 if value > 40 else 2
            value *= operand
        operations.append((operation, operand))
    require(0 <= value <= 255, f"seed {seed} escaped bounded i32 result")
    return initial, operations, value


def scalar_source(initial: int, operations: list[tuple[str, int]]) -> str:
    symbol = {"add": "+", "sub": "-", "mul": "*"}
    lines = ["func main() int {", f"    mut generated_value := {initial};"]
    lines += [f"    generated_value = generated_value {symbol[op]} {operand};"
              for op, operand in operations]
    lines += ["    return generated_value;", "}", ""]
    return "\n".join(lines)


def scalar_mir(initial: int, operations: list[tuple[str, int]], expected: int) -> str:
    kinds = {
        "add": "LocalI32AddI32Literal",
        "sub": "LocalI32SubI32Literal",
        "mul": "LocalI32MulI32Literal",
    }
    lines = [
        "format: gust.compiler_mir_ingestion.v1",
        "function: main",
        "backend_symbol: main",
        "parameter_count: 0",
        "return_type: int",
        "local_count: 1",
        "local_0_name: generated_value",
        "local_0_type: int",
        "entry_block: entry",
        "block_count: 1",
        "block_0_label: entry",
        "block_0_parameter_count: 0",
        f"block_0_statement_count: {len(operations) + 1}",
        "block_0_statement_0_kind: LocalI32Set",
        "block_0_statement_0_local: generated_value",
        f"block_0_statement_0_value: {initial}",
    ]
    for index, (operation, operand) in enumerate(operations, 1):
        lines += [
            f"block_0_statement_{index}_kind: {kinds[operation]}",
            f"block_0_statement_{index}_local: generated_value",
            f"block_0_statement_{index}_value: {operand}",
        ]
    lines += [
        "block_0_terminator_kind: ReturnLocalI32",
        "block_0_terminator_local: generated_value",
        "metadata_count: 0",
        f"expected_exit: {expected}",
        "",
    ]
    return "\n".join(lines)


def module_source(function_count: int) -> str:
    lines = ["func main() int {",
             "    mut generated_value := generated_helper_0(0);"]
    for index in range(1, function_count):
        lines.append(
            f"    generated_value = generated_helper_{index}(generated_value);"
        )
    lines += ["    return generated_value;", "}", ""]
    for index in range(function_count):
        lines += [
            f"func generated_helper_{index}(value: int) int {{",
            "    return value + 1;",
            "}",
            "",
        ]
    return "\n".join(lines)


def module_mir(function_count: int) -> str:
    module = "phase20_generated_large_module"
    lines = [
        "format: gust.compiler_mir_ingestion.v2",
        f"module: {module}",
        "import_count: 0",
        f"function_count: {function_count + 1}",
        "function_0_linkage: exported_entry",
        "function_0_function: main",
        "function_0_backend_symbol: main",
        "function_0_parameter_count: 0",
        "function_0_return_type: int",
        "function_0_local_count: 1",
        "function_0_local_0_name: generated_value",
        "function_0_local_0_type: int",
        "function_0_entry_block: entry",
        "function_0_block_count: 1",
        "function_0_block_0_label: entry",
        "function_0_block_0_parameter_count: 0",
        f"function_0_block_0_statement_count: {function_count}",
    ]
    for index in range(function_count):
        prefix = f"function_0_block_0_statement_{index}"
        lines += [
            f"{prefix}_kind: LocalI32SetCall",
            f"{prefix}_local: generated_value",
            f"{prefix}_callee_kind: LocalFunction",
            f"{prefix}_callee: generated_helper_{index}",
            f"{prefix}_argument_count: 1",
        ]
        if index == 0:
            lines += [f"{prefix}_argument_0_kind: I32Literal",
                      f"{prefix}_argument_0_value: 0"]
        else:
            lines += [f"{prefix}_argument_0_kind: LocalI32",
                      f"{prefix}_argument_0_local: generated_value"]
    lines += [
        "function_0_block_0_terminator_kind: ReturnLocalI32",
        "function_0_block_0_terminator_local: generated_value",
        "function_0_metadata_count: 0",
        f"function_0_expected_exit: {function_count}",
    ]
    for index in range(function_count):
        function = index + 1
        prefix = f"function_{function}"
        lines += [
            f"{prefix}_linkage: module_local",
            f"{prefix}_function: generated_helper_{index}",
            f"{prefix}_backend_symbol: {module}__generated_helper_{index}",
            f"{prefix}_parameter_count: 1",
            f"{prefix}_parameter_0_type: int",
            f"{prefix}_return_type: int",
            f"{prefix}_local_count: 1",
            f"{prefix}_local_0_name: return_value",
            f"{prefix}_local_0_type: int",
            f"{prefix}_entry_block: entry",
            f"{prefix}_block_count: 1",
            f"{prefix}_block_0_label: entry",
            f"{prefix}_block_0_parameter_count: 0",
            f"{prefix}_block_0_statement_count: 2",
            f"{prefix}_block_0_statement_0_kind: LocalI32SetParam",
            f"{prefix}_block_0_statement_0_local: return_value",
            f"{prefix}_block_0_statement_0_param: 0",
            f"{prefix}_block_0_statement_1_kind: LocalI32AddI32Literal",
            f"{prefix}_block_0_statement_1_local: return_value",
            f"{prefix}_block_0_statement_1_value: 1",
            f"{prefix}_block_0_terminator_kind: ReturnLocalI32",
            f"{prefix}_block_0_terminator_local: return_value",
            f"{prefix}_metadata_count: 0",
            f"{prefix}_expected_exit: 0",
        ]
    lines.append("")
    return "\n".join(lines)


def write_case(output: Path, name: str, source: str, mir: str,
               expected: int, kind: str) -> dict:
    case_dir = output / name
    case_dir.mkdir(parents=True, exist_ok=True)
    source_path = case_dir / f"{name}.gst"
    mir_path = case_dir / f"{name}.mir"
    source_path.write_text(source, encoding="utf-8")
    mir_path.write_text(mir, encoding="utf-8")
    return {
        "id": name,
        "kind": kind,
        "source": str(source_path),
        "mir": str(mir_path),
        "expected_exit": expected,
    }


def generate(profile: str, output: Path) -> list[dict]:
    value = authority()
    by_id = {row["id"]: row for row in value["cohorts"]}
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    cases = []
    scalar_id = ("small_generated_scalar" if profile == "small"
                 else "full_generated_scalar")
    scalar = by_id[scalar_id]
    for seed in value["recorded_seed_sets"][scalar["seed_set"]]:
        initial, operations, expected = scalar_plan(seed,
                                                     scalar["operation_count"])
        name = f"seed_{seed:08d}"
        cases.append(write_case(
            output, name, scalar_source(initial, operations),
            scalar_mir(initial, operations, expected), expected,
            "generated_scalar",
        ))
    if profile == "full":
        large_function = by_id["large_function"]
        operation_count = large_function["operation_count"]
        operations = [("add", 1) if index % 2 == 0 else ("sub", 1)
                      for index in range(operation_count)]
        cases.append(write_case(
            output, "large_function", scalar_source(17, operations),
            scalar_mir(17, operations, 17), 17, "large_function",
        ))
        large_module = by_id["large_module"]
        function_count = large_module["function_count"]
        cases.append(write_case(
            output, "phase20_generated_large_module",
            module_source(function_count), module_mir(function_count),
            function_count, "large_module",
        ))
    manifest_rows = []
    for case in cases:
        row = dict(case)
        row["source"] = str(Path(case["source"]).relative_to(output))
        row["mir"] = str(Path(case["mir"]).relative_to(output))
        manifest_rows.append(row)
    manifest = output / "manifest.json"
    manifest.write_text(json.dumps(manifest_rows, indent=2) + "\n",
                        encoding="utf-8")
    return cases


def run_process(command: list[str], stdout: Path, stderr: Path,
                env: dict[str, str] | None = None) -> int:
    stdout.parent.mkdir(parents=True, exist_ok=True)
    with stdout.open("wb") as out_handle, stderr.open("wb") as err_handle:
        completed = subprocess.run(command, cwd=ROOT, env=env,
                                   stdout=out_handle, stderr=err_handle,
                                   check=False)
    return completed.returncode


def execute(binary: Path, prefix: Path) -> tuple[int, bytes, bytes]:
    completed = subprocess.run([str(binary.resolve())], cwd=ROOT,
                               stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, check=False)
    prefix.with_suffix(".status").write_text(
        f"{completed.returncode}\n", encoding="utf-8")
    prefix.with_suffix(".stdout").write_bytes(completed.stdout)
    prefix.with_suffix(".stderr").write_bytes(completed.stderr)
    return completed.returncode, completed.stdout, completed.stderr


def compile_and_compare(case: dict, worker: Path, output: Path) -> None:
    case_dir = output / case["id"]
    case_dir.mkdir(parents=True, exist_ok=True)
    source = Path(case["source"])
    mir = Path(case["mir"])
    c_path = case_dir / "program.c"
    c_stderr = case_dir / "mir-to-c.compiler.stderr"
    status = run_process([GUST, "--backend", "mir-to-c", str(source)],
                         c_path, c_stderr)
    require(status == 0 and not c_stderr.read_bytes(),
            f"{case['id']}: MIR-to-C compilation failed")
    final_c = case_dir / "program.final.c"
    final_c.write_bytes((ROOT / "src/runtime.c").read_bytes() + c_path.read_bytes())
    mir_binary = case_dir / "mir-to-c-program"
    status = run_process([
        os.environ.get("CC", "cc"), "-O0", "-w", "-pthread", "-Isrc",
        str(final_c), "-o", str(mir_binary),
    ], case_dir / "cc.stdout", case_dir / "cc.stderr")
    require(status == 0, f"{case['id']}: host C compilation failed")

    native_binary = case_dir / "native-program"
    if case["kind"] != "large_module":
        env = os.environ.copy()
        env["GUST_TEST_MIR_TO_C_UNAVAILABLE"] = "1"
        env["GUST_NATIVE_BACKEND_DRIVER"] = str(worker.resolve())
        status = run_process([
            GUST, "--backend", "cranelift", "-o", str(native_binary),
            str(source),
        ], case_dir / "native.compiler.stdout",
           case_dir / "native.compiler.stderr", env)
        require(status == 0 and
                not (case_dir / "native.compiler.stdout").read_bytes() and
                not (case_dir / "native.compiler.stderr").read_bytes(),
                f"{case['id']}: no-fallback Cranelift source compilation failed")

    direct_object = case_dir / "direct.o"
    status = run_process([
        str(worker.resolve()), "compiler-mir-ingestion-object", str(mir),
        str(direct_object),
    ], case_dir / "direct.compiler.stdout",
       case_dir / "direct.compiler.stderr")
    require(status == 0, f"{case['id']}: generated canonical MIR was rejected")
    direct_binary = case_dir / "direct-program"
    status = run_process([
        os.environ.get("CC", "cc"), str(direct_object), "-o", str(direct_binary),
    ], case_dir / "direct.cc.stdout", case_dir / "direct.cc.stderr")
    require(status == 0, f"{case['id']}: generated canonical MIR did not link")

    results = {
        "mir-to-c": execute(mir_binary, case_dir / "mir-to-c"),
        "cranelift-direct-mir": execute(direct_binary,
                                         case_dir / "cranelift-direct-mir"),
    }
    if case["kind"] != "large_module":
        results["cranelift-source"] = execute(
            native_binary, case_dir / "cranelift-source")
    expected = case["expected_exit"]
    require(all(result[0] == expected for result in results.values()),
            f"{case['id']}: exit divergence: " +
            ", ".join(f"{name}={result[0]}" for name, result in results.items()))
    observables = {(result[1], result[2]) for result in results.values()}
    require(len(observables) == 1,
            f"{case['id']}: stdout/stderr divergence")


def measure_one(result_path: Path, stdout: Path, stderr: Path,
                command: list[str]) -> None:
    started = time.monotonic_ns()
    status = run_process(command, stdout, stderr)
    elapsed_ms = (time.monotonic_ns() - started) / 1_000_000
    usage = resource.getrusage(resource.RUSAGE_CHILDREN)
    result_path.write_text(json.dumps({
        "status": status,
        "elapsed_ms": elapsed_ms,
        "peak_rss_kib": int(usage.ru_maxrss),
    }) + "\n", encoding="utf-8")


def measure_command(command: list[str], prefix: Path, warmups: int,
                    samples: int) -> tuple[int, int]:
    records = []
    for index in range(warmups + samples):
        result = prefix.parent / f"{prefix.name}.{index}.json"
        stdout = prefix.parent / f"{prefix.name}.{index}.stdout"
        stderr = prefix.parent / f"{prefix.name}.{index}.stderr"
        invocation = [
            sys.executable, str(Path(__file__).resolve()), "measure-one",
            "--result", str(result), "--stdout", str(stdout),
            "--stderr", str(stderr), "--", *command,
        ]
        completed = subprocess.run(invocation, cwd=ROOT, check=False)
        require(completed.returncode == 0 and result.is_file(),
                f"measurement wrapper failed: {' '.join(command)}")
        record = json.loads(result.read_text(encoding="utf-8"))
        require(record["status"] == 0,
                f"measured command failed: {' '.join(command)}")
        if index >= warmups:
            records.append(record)
    elapsed = int(round(statistics.median(row["elapsed_ms"] for row in records)))
    peak_rss = max(row["peak_rss_kib"] for row in records)
    return elapsed, peak_rss


def measure_scale(cases: list[dict], worker: Path, output: Path, value: dict) -> None:
    measurement = value["measurement"]
    warmups = measurement["warmup_runs"]
    samples = measurement["sample_count"]
    budget_by_key = {(row["cohort"], row["backend"]): row
                     for row in measurement["budgets"]}
    observed = []
    env_prefix = ["env", "GUST_TEST_MIR_TO_C_UNAVAILABLE=1",
                  f"GUST_NATIVE_BACKEND_DRIVER={worker.resolve()}"]
    for case in cases:
        if case["kind"] not in {"large_function", "large_module"}:
            continue
        source = case["source"]
        cranelift_command = [
            *env_prefix, GUST, "--backend", "cranelift", "-o",
            str((output / case["id"] / "measured-native").resolve()), source,
        ]
        if case["kind"] == "large_module":
            cranelift_command = [
                str(worker.resolve()), "compiler-mir-ingestion-object",
                case["mir"],
                str((output / case["id"] / "measured-native.o").resolve()),
            ]
        commands = {
            "mir-to-c": [GUST, "--backend", "mir-to-c", source],
            "cranelift": cranelift_command,
        }
        for backend, command in commands.items():
            prefix = output / case["id"] / f"measure-{backend}"
            elapsed, peak_rss = measure_command(command, prefix, warmups, samples)
            budget = budget_by_key[(case["kind"], backend)]
            require(elapsed <= budget["max_elapsed_ms"],
                    f"{case['kind']} {backend} median {elapsed}ms exceeds "
                    f"{budget['max_elapsed_ms']}ms")
            require(peak_rss <= budget["max_peak_rss_kib"],
                    f"{case['kind']} {backend} peak {peak_rss}KiB exceeds "
                    f"{budget['max_peak_rss_kib']}KiB")
            observed.append({"cohort": case["kind"], "backend": backend,
                             "median_elapsed_ms": elapsed,
                             "max_peak_rss_kib": peak_rss})
    (output / "measurements.json").write_text(
        json.dumps(observed, indent=2) + "\n", encoding="utf-8")


def run(profile: str, output: Path) -> None:
    value = validate()
    gust_path = Path(GUST)
    if not gust_path.is_absolute():
        gust_path = ROOT / gust_path
    require(gust_path.is_file() and os.access(gust_path, os.X_OK),
            f"Patch 20.14 requires executable compiler {GUST}")
    worker = ROOT / "build/gust-native-backend"
    if not worker.is_file():
        subprocess.run(["make", "build/gust-native-backend"], cwd=ROOT,
                       check=True)
    first = output / "generated"
    second = output / "determinism-check"
    cases = generate(profile, first)
    generate(profile, second)
    first_files = sorted(path.relative_to(first) for path in first.rglob("*")
                         if path.is_file())
    second_files = sorted(path.relative_to(second) for path in second.rglob("*")
                          if path.is_file())
    require(first_files == second_files, "generated file inventory is unstable")
    for relative in first_files:
        require((first / relative).read_bytes() == (second / relative).read_bytes(),
                f"generated bytes are unstable: {relative}")
    shutil.rmtree(second)
    evidence = output / "evidence"
    for case in cases:
        try:
            compile_and_compare(case, worker, evidence)
        except Error:
            candidate = output / "minimized-failure-candidate" / case["id"]
            candidate.mkdir(parents=True, exist_ok=True)
            shutil.copy2(case["source"], candidate)
            shutil.copy2(case["mir"], candidate)
            raise
        print(f"PASS {case['id']}")
    if profile == "full":
        measure_scale(cases, worker, evidence, value)
    print(f"PASS phase20 generated MIR profile={profile} cases={len(cases)}")


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    for command in ("validate", "project", "check-review"):
        subparsers.add_parser(command)
    generate_parser = subparsers.add_parser("generate")
    generate_parser.add_argument("--profile", choices=("small", "full"),
                                 required=True)
    generate_parser.add_argument("--output", type=Path, required=True)
    run_parser = subparsers.add_parser("run")
    run_parser.add_argument("--profile", choices=("small", "full"),
                            required=True)
    run_parser.add_argument("--output", type=Path, required=True)
    measure_parser = subparsers.add_parser("measure-one")
    measure_parser.add_argument("--result", type=Path, required=True)
    measure_parser.add_argument("--stdout", type=Path, required=True)
    measure_parser.add_argument("--stderr", type=Path, required=True)
    measure_parser.add_argument("remainder", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    try:
        if args.command == "validate":
            validate()
        elif args.command == "project":
            REVIEW.write_text(render(validate()), encoding="utf-8")
        elif args.command == "check-review":
            require(REVIEW.read_text(encoding="utf-8") == render(validate()),
                    "generated Patch 20.14 review is stale; run project")
        elif args.command == "generate":
            generate(args.profile, args.output)
        elif args.command == "run":
            run(args.profile, args.output)
        elif args.command == "measure-one":
            command = args.remainder
            if command and command[0] == "--":
                command = command[1:]
            require(bool(command), "measure-one requires a command")
            measure_one(args.result, args.stdout, args.stderr, command)
    except (Error, KeyError, OSError, subprocess.CalledProcessError) as error:
        print(f"{GUARD_L1}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
