#!/usr/bin/env python3
"""Validate, project, and execute Patch 21.12 qualification evidence."""

from __future__ import annotations

import argparse
import json
import os
import re
import resource
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE21_COMPILER_SUPPORT_NATIVE_QUALIFICATION.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase21-compiler-support-native-qualification.yml"
GUARD_L1 = "guard-cranelift-phase21-compiler-support-native-qualification-contract"
GUARD_L2 = "guard-cranelift-phase21-compiler-support-native-qualification-evidence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def import_graph(root_name: str) -> tuple[set[str], list[tuple[str, str]]]:
    seen: set[str] = set()
    edges: list[tuple[str, str]] = []

    def visit(name: str) -> None:
        if name in seen:
            return
        seen.add(name)
        source = ROOT / "compiler" / name
        require(source.is_file(), f"compiler graph module is missing: {name}")
        imports = re.findall(
            r'^import "([^"]+)" as ', source.read_text(encoding="utf-8"), re.MULTILINE
        )
        for dependency in imports:
            edges.append((name, dependency))
            visit(dependency)

    visit(root_name)
    return seen, edges


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    predecessor = registry.get("phase21_resource_sync_native_source", {})
    require(predecessor.get("status") == "patch21_11_complete" and
            predecessor.get("next_patch") == "21.12",
            "Patch 21.11 predecessor authority drifted")
    graph_authority = registry.get("phase21_residue_migration_authority", {})
    graph = graph_authority.get("compiler_graph", {})
    record = registry.get("phase21_compiler_support_native_qualification", {})
    require(record.get("contract_version") ==
            "phase21_compiler_support_native_qualification_v1",
            "contract version drifted")
    require(record.get("status") == "patch21_12_complete" and
            record.get("next_patch") == "21.13", "status or successor drifted")
    require(record.get("predecessor_authority") ==
            predecessor.get("contract_version"), "predecessor link drifted")
    require(record.get("compiler_graph_authority") ==
            graph_authority.get("contract_version"), "compiler graph link drifted")
    require(record.get("observed_main_sha") ==
            "302c902e69112a510543ff6c5d720d39872f02ea",
            "qualification base drifted")

    current_reachable, current_edges = import_graph(graph.get("root", ""))
    authority_reachable = {module for row in graph.get("slices", [])
                           for module in row.get("modules", [])}
    authority_edges = [(source, dependency) for source, dependency in current_edges
                       if source in authority_reachable and
                       dependency in authority_reachable]
    successors = record.get("successor_migration_modules", [])
    selected = set(record.get("selected_modules_deferred_to_patch21_13", []))
    entry = record.get("entry_module_deferred_to_patch21_14")
    support = current_reachable - selected - {entry}
    require(authority_reachable.issubset(current_reachable) and
            len(authority_reachable) == graph.get("module_count") == 38 and
            len(authority_edges) == graph.get("import_edge_count") == 116,
            "compiler graph drifted from Patch 21.8 authority")
    require(successors == [
        "mir_native_backend_collection_string_source.gst",
        "mir_native_backend_filesystem_allocation_source.gst",
        "mir_native_backend_resource_sync_source.gst",
    ] and set(successors) == current_reachable - authority_reachable and
            record.get("current_compiler_graph_module_count") ==
            len(current_reachable) == 41 and
            record.get("current_compiler_graph_import_edge_count") ==
            len(current_edges) == 125,
            "post-authority successor graph reconciliation drifted")
    require(selected == {"lexer.gst", "parser.gst", "resolver.gst",
                         "typechecker.gst", "mir.gst", "codegen.gst"},
            "Patch 21.13 selected-module boundary drifted")
    require(entry == "test_runner_entry.gst", "full compiler entry boundary drifted")
    require(record.get("support_module_count") == len(support) == 34,
            "support module population drifted")
    require(record.get("support_dependency_edge_count") ==
            sum(source in support and dependency in current_reachable
                for source, dependency in current_edges) == 87,
            "support dependency-edge population drifted")
    require(record.get("support_induced_edge_count") ==
            sum(source in support and dependency in support
                for source, dependency in current_edges) == 72,
            "support induced-edge population drifted")

    expected_slices = []
    for graph_slice in graph["slices"]:
        modules = [module for module in graph_slice["modules"] if module in support]
        if graph_slice["id"] == "native_source_lowering":
            modules = modules[:-1] + successors + modules[-1:]
        if modules:
            expected_slices.append((graph_slice["id"], modules))
    slices = record.get("slices", [])
    require([row.get("order") for row in slices] == list(range(1, 5)) and
            [row.get("id") for row in slices] ==
            [item[0] for item in expected_slices],
            "support slices are missing, duplicated, or reordered")
    for row, (_, modules) in zip(slices, expected_slices):
        require(row.get("modules") == modules and
                row.get("module_count") == len(modules),
                f"{row['id']} module population drifted")
        require(row.get("dependency_edge_count") ==
                sum(source in modules and dependency in current_reachable
                    for source, dependency in current_edges),
                f"{row['id']} dependency-edge count drifted")
        fixture = ROOT / row.get("source_fixture", "")
        require(fixture.is_file(), f"{row['id']} fixture is missing")
        fixture_imports = re.findall(
            r'^import "([^"]+)" as ', fixture.read_text(encoding="utf-8"), re.MULTILINE
        )
        require(fixture_imports == modules,
                f"{row['id']} fixture imports drifted from the registry slice")
        main_line = next(
            (index for index, line in enumerate(
                fixture.read_text(encoding="utf-8").splitlines(), start=1)
             if line == "func main() int {"), 0
        )
        require(row.get("cranelift", {}).get("line") == main_line,
                f"{row['id']} diagnostic location drifted")
        require(row.get("oracle") == {
            "compile_exit": 0,
            "run_exit": 0,
            "stdout": "",
            "stderr": "",
            "artifact": "nonempty_generated_C_and_linked_executable",
        }, f"{row['id']} MIR-to-C oracle contract drifted")
        require(row.get("cranelift", {}).get("compile_exit") == 1 and
                row["cranelift"].get("decision") == "source_or_type_failure" and
                row["cranelift"].get("reason_code") == "source_or_type_failure" and
                row["cranelift"].get("diagnostic_class") ==
                "canonical_mir_verification_error" and
                row["cranelift"].get("failure_stage") ==
                "before_driver_discovery" and
                row["cranelift"].get("canonical_mir") ==
                "absent_before_driver_discovery" and
                row["cranelift"].get("artifact") == "absent",
                f"{row['id']} explicit-Cranelift classification drifted")
        require(row["cranelift"].get("diagnostic") ==
                "Native backend canonical MIR verification failed: unsupported top-level statement in module/import cohort",
                f"{row['id']} diagnostic text drifted")
        measurement = row.get("measurement", {})
        for backend in ("mir_to_c", "cranelift"):
            budget = measurement.get(backend, {})
            require(0 <= budget.get("baseline_elapsed_ms", -1) <=
                    budget.get("max_elapsed_ms", -1) and
                    0 < budget.get("baseline_peak_rss_kib", 0) <=
                    budget.get("max_peak_rss_kib", 0),
                    f"{row['id']} {backend} measurement budget drifted")
    require(record.get("measurement_policy") == {
        "protocol": "fresh_child_process_monotonic_elapsed_and_wait4_maxrss",
        "sample_count": 1,
        "elapsed_statistic": "single_focused_qualification_observation",
        "memory_statistic": "maximum_resident_set_size",
        "threshold_policy": "fixed_registry_values_reviewed_with_the_patch_no_runtime_rebasing",
    }, "measurement policy drifted")
    require(record.get("resource_state") ==
            "compiler_process_only_no_native_program_or_runtime_resource_acquisition",
            "resource-state boundary drifted")
    require(record.get("capability_disposition") == {
        "id": "generic_compiler_module_top_level_declaration_lowering",
        "decision": "source_or_type_failure",
        "destination_patch": "21.13",
        "policy": "generic_capability_row_required_no_module_specific_exception",
    }, "Patch 21.13 capability handoff drifted")
    boundary = record.get("boundary", {})
    require(boundary and all(value is False for value in boundary.values()),
            "Patch 21.12 widened beyond qualification evidence")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 21.12 — Compiler Support-Library Native Qualification — DONE"
            in task and "**Exit Gate:** all 34 support modules" in task,
            "TASK.md does not close the Patch 21.12 qualification boundary")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 21.12 guard levels drifted")
    require(f"{GUARD_L1}:" in JUSTFILE.read_text(encoding="utf-8") and
            f"{GUARD_L2}:" in JUSTFILE.read_text(encoding="utf-8"),
            "Patch 21.12 just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Patch 21.12 contract guard")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow,
            "dedicated Patch 21.12 workflow does not own both guards")
    return record


def render(record: dict) -> str:
    lines = [
        "# Cranelift Phase 21 Compiler Support-Library Native Qualification", "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase21_compiler_support_native_qualification.py project`. Do not edit by hand.",
        "", f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`", f"- Next patch: `{record['next_patch']}`",
        f"- Observed main: `{record['observed_main_sha']}`",
        f"- Patch 21.8 graph authority: `{record['compiler_graph_module_count']}` modules / `{record['compiler_graph_import_edge_count']}` import edges",
        f"- Current graph after Patches 21.9–21.11: `{record['current_compiler_graph_module_count']}` modules / `{record['current_compiler_graph_import_edge_count']}` import edges",
        f"- Successor migration modules: `{', '.join(record['successor_migration_modules'])}`",
        f"- Qualified support population: `{record['support_module_count']}` modules / `{record['support_dependency_edge_count']}` dependency edges (`{record['support_induced_edge_count']}` support-to-support)",
        "", "## Topological support slices", "",
    ]
    for row in record["slices"]:
        lines += [
            f"{row['order']}. `{row['id']}` — `{row['module_count']}` modules / `{row['dependency_edge_count']}` dependency edges",
            f"   - Root: `{row['source_fixture']}`",
            f"   - Modules: `{', '.join(row['modules'])}`",
            "   - MIR-to-C: accepted; linked executable exits 0 with empty stdout/stderr",
            f"   - Explicit Cranelift: `{row['cranelift']['decision']}` at `{row['cranelift']['failure_stage']}`; canonical MIR `{row['cranelift']['canonical_mir']}`; artifact `{row['cranelift']['artifact']}`",
            f"   - Diagnostic: `{row['cranelift']['diagnostic']}`",
            f"   - Local baselines: MIR-to-C `{row['measurement']['mir_to_c']['baseline_elapsed_ms']}ms` / `{row['measurement']['mir_to_c']['baseline_peak_rss_kib']}KiB`; Cranelift `{row['measurement']['cranelift']['baseline_elapsed_ms']}ms` / `{row['measurement']['cranelift']['baseline_peak_rss_kib']}KiB`",
        ]
    lines += [
        "", "## Classification", "",
        f"- Resource state: `{record['resource_state']}`",
        f"- Remaining generic capability: `{record['capability_disposition']['id']}`",
        f"- Destination: Patch `{record['capability_disposition']['destination_patch']}`",
        f"- Policy: `{record['capability_disposition']['policy']}`",
        f"- Selected modules reserved for Patch 21.13: `{', '.join(record['selected_modules_deferred_to_patch21_13'])}`",
        f"- Full compiler entry reserved for Patch 21.14: `{record['entry_module_deferred_to_patch21_14']}`",
        "", "Patch 21.12 is qualification evidence only. It adds no accepted source",
        "meaning, canonical MIR operation, backend capability, ABI/layout or runtime",
        "symbol, bootstrap seed, fallback, default-backend change, or Stdlib work.", "",
    ]
    return "\n".join(lines)


def run_process(command: list[str], stdout: Path, stderr: Path,
                env: dict[str, str] | None = None) -> int:
    with stdout.open("wb") as out, stderr.open("wb") as err:
        return subprocess.run(command, cwd=ROOT, stdout=out, stderr=err,
                              env=env, check=False).returncode


def measure_one(result_path: Path, stdout: Path, stderr: Path,
                command: list[str]) -> None:
    started = time.monotonic_ns()
    status = run_process(command, stdout, stderr)
    elapsed_ms = (time.monotonic_ns() - started) / 1_000_000
    usage = resource.getrusage(resource.RUSAGE_CHILDREN)
    result_path.write_text(json.dumps({
        "status": status,
        "elapsed_ms": int(round(elapsed_ms)),
        "peak_rss_kib": int(usage.ru_maxrss),
    }) + "\n", encoding="utf-8")


def measure(command: list[str], prefix: Path,
            env: dict[str, str] | None = None) -> dict:
    result = prefix.with_suffix(".json")
    invocation = [
        sys.executable, str(Path(__file__).resolve()), "measure-one",
        "--result", str(result), "--stdout", str(prefix.with_suffix(".stdout")),
        "--stderr", str(prefix.with_suffix(".stderr")), "--", *command,
    ]
    completed = subprocess.run(invocation, cwd=ROOT, env=env, check=False)
    require(completed.returncode == 0 and result.is_file(),
            f"measurement wrapper failed: {' '.join(command)}")
    return json.loads(result.read_text(encoding="utf-8"))


def run_evidence(output: Path) -> None:
    record = validate()
    require((ROOT / "gust").is_file() and os.access(ROOT / "gust", os.X_OK),
            "Patch 21.12 evidence requires rebuilt ./gust")
    output.mkdir(parents=True, exist_ok=True)
    driver_marker = output / "driver-invoked"
    capture_driver = output / "capture-driver"
    capture_driver.write_text(
        "#!/usr/bin/env bash\nset -euo pipefail\ntouch \"$DRIVER_MARKER\"\nexit 99\n",
        encoding="utf-8",
    )
    capture_driver.chmod(0o755)
    observations = []
    for row in record["slices"]:
        case_root = output / row["id"]
        case_root.mkdir(parents=True, exist_ok=True)
        source = row["source_fixture"]
        oracle_c = case_root / "oracle.c"
        oracle = measure(
            ["./gust", "--backend", "mir-to-c", source],
            case_root / "mir-to-c",
        )
        require(oracle["status"] == row["oracle"]["compile_exit"],
                f"{row['id']}: MIR-to-C compile status drifted")
        oracle_c.write_bytes((case_root / "mir-to-c.stdout").read_bytes())
        require(oracle_c.stat().st_size > 0 and
                not (case_root / "mir-to-c.stderr").read_bytes(),
                f"{row['id']}: MIR-to-C did not emit clean nonempty C")
        executable = case_root / "oracle"
        cc = os.environ.get("CC", "cc")
        status = run_process(
            [cc, "-O0", "-w", "-pthread", "-Isrc", "-include", "src/runtime.c",
             str(oracle_c), "-o", str(executable)],
            case_root / "oracle-link.stdout", case_root / "oracle-link.stderr",
        )
        require(status == 0 and executable.is_file(),
                f"{row['id']}: MIR-to-C output did not link")
        status = run_process([str(executable)], case_root / "oracle-run.stdout",
                             case_root / "oracle-run.stderr")
        require(status == row["oracle"]["run_exit"] and
                (case_root / "oracle-run.stdout").read_text(encoding="utf-8") ==
                row["oracle"]["stdout"] and
                (case_root / "oracle-run.stderr").read_text(encoding="utf-8") ==
                row["oracle"]["stderr"],
                f"{row['id']}: MIR-to-C runtime oracle drifted")

        native = case_root / "native"
        env = os.environ.copy()
        env["GUST_NATIVE_BACKEND_DRIVER"] = str(capture_driver.resolve())
        env["DRIVER_MARKER"] = str(driver_marker.resolve())
        observed_native = measure(
            ["./gust", "--backend", "cranelift", "-o", str(native), source],
            case_root / "cranelift", env,
        )
        require(observed_native["status"] == row["cranelift"]["compile_exit"],
                f"{row['id']}: explicit-Cranelift status drifted")
        native_stdout = (case_root / "cranelift.stdout").read_text(encoding="utf-8")
        native_stderr = (case_root / "cranelift.stderr").read_text(encoding="utf-8")
        diagnostic = row["cranelift"]
        for marker in (
            f"decision={diagnostic['decision']}",
            f"reason_code={diagnostic['reason_code']}",
            f"expected_failure_stage={diagnostic['failure_stage']}",
            f"class={diagnostic['diagnostic_class']}",
            f"source={source}", f"line={diagnostic['line']}",
        ):
            require(marker in native_stdout,
                    f"{row['id']}: missing diagnostic marker {marker}")
        require(native_stderr == diagnostic["diagnostic"] + "\n" and
                not native.exists() and
                not driver_marker.exists(),
                f"{row['id']}: rejection reached the driver or produced an artifact")
        for backend, observed in (("mir_to_c", oracle),
                                  ("cranelift", observed_native)):
            budget = row["measurement"][backend]
            require(observed["elapsed_ms"] <= budget["max_elapsed_ms"],
                    f"{row['id']} {backend} elapsed {observed['elapsed_ms']}ms exceeds {budget['max_elapsed_ms']}ms")
            require(observed["peak_rss_kib"] <= budget["max_peak_rss_kib"],
                    f"{row['id']} {backend} peak {observed['peak_rss_kib']}KiB exceeds {budget['max_peak_rss_kib']}KiB")
        observations.append({
            "id": row["id"], "mir_to_c": oracle,
            "cranelift": observed_native,
            "canonical_mir": diagnostic["canonical_mir"],
            "native_artifact": diagnostic["artifact"],
            "resource_state": record["resource_state"],
        })
    (output / "measurements.json").write_text(
        json.dumps(observations, indent=2) + "\n", encoding="utf-8")
    print(f"{GUARD_L2}: ok")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=(
        "validate", "project", "check-review", "run-evidence", "measure-one",
    ))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--result", type=Path)
    parser.add_argument("--stdout", type=Path)
    parser.add_argument("--stderr", type=Path)
    args, remainder = parser.parse_known_args()
    if args.command == "measure-one":
        require(args.result and args.stdout and args.stderr and
                remainder[:1] == ["--"] and len(remainder) > 1,
                "measure-one arguments are incomplete")
        measure_one(args.result, args.stdout, args.stderr, remainder[1:])
        return
    require(not remainder, f"unexpected arguments: {' '.join(remainder)}")
    record = validate()
    if args.command == "project":
        REVIEW.write_text(render(record), encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and
                REVIEW.read_text(encoding="utf-8") == render(record),
                "generated Patch 21.12 review is stale; run project")
    elif args.command == "run-evidence":
        require(args.output is not None, "run-evidence requires --output")
        run_evidence(args.output)
    print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
