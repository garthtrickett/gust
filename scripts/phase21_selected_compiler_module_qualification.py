#!/usr/bin/env python3
"""Validate, project, and execute Patch 21.13 selected-module evidence."""

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
REVIEW = ROOT / "compiler/CRANELIFT_PHASE21_SELECTED_COMPILER_MODULE_QUALIFICATION.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase21-selected-compiler-module-qualification.yml"
LOWERER = ROOT / "compiler/mir_native_backend_module_import_source.gst"
GUARD_L1 = "guard-cranelift-phase21-selected-compiler-module-qualification-contract"
GUARD_L2 = "guard-cranelift-phase21-selected-compiler-module-qualification-evidence"


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
            r'^import "([^"]+)" as ', source.read_text(encoding="utf-8"),
            re.MULTILINE,
        )
        for dependency in imports:
            edges.append((name, dependency))
            visit(dependency)

    visit(root_name)
    return seen, edges


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    predecessor = registry.get(
        "phase21_compiler_support_native_qualification", {}
    )
    require(
        predecessor.get("status") == "patch21_12_complete"
        and predecessor.get("next_patch") == "21.13",
        "Patch 21.12 predecessor authority drifted",
    )
    record = registry.get(
        "phase21_selected_compiler_module_qualification", {}
    )
    require(
        record.get("contract_version")
        == "phase21_selected_compiler_module_qualification_v1",
        "contract version drifted",
    )
    require(
        record.get("status") == "patch21_13_complete"
        and record.get("next_patch") == "21.13a",
        "status or successor drifted",
    )
    require(
        record.get("observed_main_sha")
        == "45a635c1acbf294997d952701d8ad12c934686c9",
        "qualification base drifted",
    )
    require(
        record.get("predecessor_authority")
        == predecessor.get("contract_version"),
        "predecessor link drifted",
    )

    expected_order = [
        "lexer.gst",
        "parser.gst",
        "resolver.gst",
        "typechecker.gst",
        "mir.gst",
        "codegen.gst",
    ]
    require(
        record.get("selected_module_order") == expected_order,
        "selected compiler-module order drifted",
    )
    slices = record.get("slices", [])
    require(
        [row.get("order") for row in slices] == list(range(1, 7))
        and [row.get("selected_module") for row in slices] == expected_order,
        "selected slices are missing, duplicated, or reordered",
    )
    for row in slices:
        reachable, edges = import_graph(row["selected_module"])
        require(
            row.get("reachable_module_count") == len(reachable)
            and row.get("reachable_import_edge_count") == len(edges),
            f"{row['id']} reachable graph counts drifted",
        )
        fixture = ROOT / row.get("source_fixture", "")
        require(fixture.is_file(), f"{row['id']} fixture is missing")
        fixture_text = fixture.read_text(encoding="utf-8")
        fixture_imports = re.findall(
            r'^import "([^"]+)" as ', fixture_text, re.MULTILINE
        )
        require(
            fixture_imports == [row["selected_module"]],
            f"{row['id']} fixture no longer selects exactly its owning module",
        )
        main_line = next(
            (
                index
                for index, line in enumerate(fixture_text.splitlines(), start=1)
                if line == "func main() int {"
            ),
            0,
        )
        require(
            row.get("cranelift", {}).get("line") == main_line,
            f"{row['id']} diagnostic location drifted",
        )
        oracle = row.get("oracle", {})
        require(
            oracle.get("compile_exit") == 0
            and oracle.get("run_exit") == 0
            and oracle.get("stdout") == ""
            and oracle.get("stderr") == ""
            and oracle.get("generated_c_bytes", 0) > 0
            and oracle.get("artifact")
            == "nonempty_generated_C_and_linked_executable",
            f"{row['id']} MIR-to-C oracle contract drifted",
        )
        native = row.get("cranelift", {})
        require(
            native.get("compile_exit") == 1
            and native.get("decision") == "source_or_type_failure"
            and native.get("reason_code") == "source_or_type_failure"
            and native.get("diagnostic_class")
            == "canonical_mir_verification_error"
            and native.get("diagnostic")
            == "Native backend canonical MIR verification failed: module function uses an unsupported scalar signature"
            and native.get("failure_stage") == "before_driver_discovery"
            and native.get("canonical_mir")
            == "absent_before_driver_discovery"
            and native.get("artifact") == "absent",
            f"{row['id']} explicit-Cranelift classification drifted",
        )
        for backend in ("mir_to_c", "cranelift"):
            budget = row.get("measurement", {}).get(backend, {})
            require(
                0 <= budget.get("baseline_elapsed_ms", -1)
                <= budget.get("max_elapsed_ms", -1)
                and 0 < budget.get("baseline_peak_rss_kib", 0)
                <= budget.get("max_peak_rss_kib", 0),
                f"{row['id']} {backend} measurement budget drifted",
            )

    declaration = record.get("declaration_admission", {})
    require(
        declaration.get("id")
        == "generic_compiler_module_top_level_declaration_lowering"
        and declaration.get("status") == "implemented"
        and declaration.get("source_fixture")
        == "compiler/phase21_selected_declaration_source.gst"
        and declaration.get("dependency_fixture")
        == "compiler/phase21_selected_declaration_module.gst"
        and declaration.get("oracle", {}).get("run_exit") == 42
        and declaration.get("cranelift", {}).get("run_exit") == 42,
        "generic declaration-admission witness drifted",
    )
    dependency = ROOT / declaration["dependency_fixture"]
    source = ROOT / declaration["source_fixture"]
    require(
        dependency.is_file()
        and source.is_file()
        and "type DeclarationPair struct {" in dependency.read_text(encoding="utf-8")
        and "type DeclarationState enum {" in dependency.read_text(encoding="utf-8")
        and 'import "phase21_selected_declaration_module.gst" as declaration;'
        in source.read_text(encoding="utf-8"),
        "generic declaration-admission source shapes drifted",
    )
    lowerer = LOWERER.read_text(encoding="utf-8")
    require(
        "if len(programs) > 1 {" in lowerer
        and "else if statement.tag != 1 && statement.tag != 2 {" in lowerer,
        "generic declaration admission is missing from the module lowerer",
    )
    require(
        record.get("generic_capability_rows") == [
            {
                "id": "generic_compiler_module_top_level_declaration_lowering",
                "status": "implemented",
                "destination_patch": "21.13",
                "policy": "no_module_specific_exception",
            },
            {
                "id": "compiler_module_non_scalar_signature_lowering",
                "status": "required",
                "current_decision": "source_or_type_failure",
                "failure_stage": "before_driver_discovery",
                "destination_patch": "21.14",
                "policy": "one_generic_capability_for_all_selected_modules_no_module_specific_exception",
            },
        ],
        "generic capability rows drifted",
    )
    require(
        record.get("large_function_registry_observation")
        == "not_observable_until_generic_non_scalar_signature_lowering_advances_the_selected_modules",
        "large-function/registry evidence boundary drifted",
    )
    progression = record.get("full_compiler_progression", {})
    require(
        progression
        == {
            "historical_authority": "phase21_opening_evidence_v1",
            "historical_record_preserved": True,
            "support_authority": "phase21_compiler_support_native_qualification_v1",
            "support_record_preserved": True,
            "cross_feature_authority": "phase20_cross_feature_qualification_v1",
            "cross_feature_record_preserved": True,
            "current_diagnostic": "Native backend canonical MIR verification failed: module function uses an unsupported scalar signature",
            "current_failure_stage": "before_driver_discovery",
            "current_artifact": "absent",
            "driver_invoked": False,
        }
        and all(
            row["cranelift"]["diagnostic"]
            == progression["current_diagnostic"]
            for row in slices
        ),
        "full-compiler progression authority drifted",
    )
    boundary = record.get("boundary", {})
    require(
        boundary and all(value is False for value in boundary.values()),
        "Patch 21.13 widened beyond its qualification boundary",
    )

    task = TASK.read_text(encoding="utf-8")
    require(
        "- [x] Patch 21.13 — Selected Compiler-Module Native Qualification — DONE"
        in task
        and "**Exit Gate:** all six selected modules" in task,
        "TASK.md does not close the Patch 21.13 boundary",
    )
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(
        levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
        "Patch 21.13 guard levels drifted",
    )
    require(
        f"{GUARD_L1}:" in JUSTFILE.read_text(encoding="utf-8")
        and f"{GUARD_L2}:" in JUSTFILE.read_text(encoding="utf-8"),
        "Patch 21.13 just guards are missing",
    )
    require(
        f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
        "PR Fast does not own the Patch 21.13 contract guard",
    )
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(
        f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow,
        "dedicated Patch 21.13 workflow does not own both guards",
    )
    for runtime_path in ("'src/runtime.c'", "'src/runtime/**'"):
        require(
            workflow.count(f"- {runtime_path}") == 2,
            f"dedicated Patch 21.13 workflow does not cover {runtime_path} twice",
        )
    return record


def render(record: dict) -> str:
    lines = [
        "# Cranelift Phase 21 Selected Compiler-Module Native Qualification",
        "",
        "Generated from scripts/cranelift_feature_registry.json by",
        "scripts/phase21_selected_compiler_module_qualification.py project.",
        "Do not edit by hand.",
        "",
        f"- Contract: {record['contract_version']}",
        f"- Status: {record['status']}",
        f"- Next patch: {record['next_patch']}",
        f"- Observed main: {record['observed_main_sha']}",
        f"- Selected order: {', '.join(record['selected_module_order'])}",
        "",
        "## Generic declaration admission",
        "",
        "- Ordinary struct/enum declarations own no executable MIR.",
        "- Every function use still passes the generic signature and body lowerers.",
        "- The declaration witness exits 42 with empty output through both backends.",
        "",
        "## Selected module slices",
        "",
    ]
    for row in record["slices"]:
        lines.extend(
            [
                f"{row['order']}. {row['id']} — {row['selected_module']}",
                f"   - Reachable graph: {row['reachable_module_count']} modules / {row['reachable_import_edge_count']} import edges",
                f"   - MIR-to-C: {row['oracle']['generated_c_bytes']} generated-C bytes; linked executable exits 0 with empty output",
                f"   - Explicit Cranelift: {row['cranelift']['decision']} at {row['cranelift']['failure_stage']}; canonical MIR {row['cranelift']['canonical_mir']}; artifact {row['cranelift']['artifact']}",
                f"   - Diagnostic: {row['cranelift']['diagnostic']}",
                f"   - Local baselines: MIR-to-C {row['measurement']['mir_to_c']['baseline_elapsed_ms']}ms / {row['measurement']['mir_to_c']['baseline_peak_rss_kib']}KiB; Cranelift {row['measurement']['cranelift']['baseline_elapsed_ms']}ms / {row['measurement']['cranelift']['baseline_peak_rss_kib']}KiB",
            ]
        )
    lines.extend(
        [
            "",
            "## Generic capability disposition",
            "",
            "- Top-level struct/enum declaration admission: implemented in Patch 21.13.",
            "- Non-scalar compiler-module signatures: one generic required capability assigned to Patch 21.14.",
            "- Large-function/registry behavior is not yet observable because signature admission rejects first.",
            "- The historical Phase 20 cross-feature, Phase 21 opening, and Patch 21.12 support records remain recorded; their live guards now follow this successor diagnostic.",
            "",
            "Patch 21.13 changes no Gust source meaning, canonical MIR operation,",
            "ABI/layout/runtime symbol, bootstrap seed, default backend, fallback,",
            "Stdlib, CR-15, or Patch 21.13a work.",
            "",
        ]
    )
    return "\n".join(lines)


def run_process(
    command: list[str], stdout: Path, stderr: Path,
    env: dict[str, str] | None = None,
) -> int:
    with stdout.open("wb") as out, stderr.open("wb") as err:
        return subprocess.run(
            command, cwd=ROOT, stdout=out, stderr=err, env=env, check=False
        ).returncode


def measure_one(
    result_path: Path, stdout: Path, stderr: Path, command: list[str]
) -> None:
    started = time.monotonic_ns()
    status = run_process(command, stdout, stderr)
    elapsed_ms = (time.monotonic_ns() - started) / 1_000_000
    usage = resource.getrusage(resource.RUSAGE_CHILDREN)
    result_path.write_text(
        json.dumps(
            {
                "status": status,
                "elapsed_ms": int(round(elapsed_ms)),
                "peak_rss_kib": int(usage.ru_maxrss),
            }
        )
        + "\n",
        encoding="utf-8",
    )


def measure(
    command: list[str], prefix: Path, env: dict[str, str] | None = None
) -> dict:
    result = prefix.with_suffix(".json")
    invocation = [
        sys.executable,
        str(Path(__file__).resolve()),
        "measure-one",
        "--result",
        str(result),
        "--stdout",
        str(prefix.with_suffix(".stdout")),
        "--stderr",
        str(prefix.with_suffix(".stderr")),
        "--",
        *command,
    ]
    completed = subprocess.run(invocation, cwd=ROOT, env=env, check=False)
    require(
        completed.returncode == 0 and result.is_file(),
        f"measurement wrapper failed: {' '.join(command)}",
    )
    return json.loads(result.read_text(encoding="utf-8"))


def check_budget(row: dict, backend: str, observed: dict) -> None:
    budget = row["measurement"][backend]
    require(
        observed["elapsed_ms"] <= budget["max_elapsed_ms"],
        f"{row['id']} {backend} exceeded elapsed budget",
    )
    require(
        observed["peak_rss_kib"] <= budget["max_peak_rss_kib"],
        f"{row['id']} {backend} exceeded RSS budget",
    )


def run_evidence(output: Path) -> None:
    record = validate()
    require(
        (ROOT / "gust").is_file() and os.access(ROOT / "gust", os.X_OK),
        "Patch 21.13 evidence requires rebuilt ./gust",
    )
    worker = ROOT / "build/gust-native-backend"
    require(
        worker.is_file() and os.access(worker, os.X_OK),
        "Patch 21.13 evidence requires build/gust-native-backend",
    )
    output.mkdir(parents=True, exist_ok=True)
    driver_marker = output / "driver-invoked"
    capture_driver = output / "capture-driver"
    capture_driver.write_text(
        "#!/usr/bin/env bash\nset -euo pipefail\ntouch \"$DRIVER_MARKER\"\nexit 99\n",
        encoding="utf-8",
    )
    capture_driver.chmod(0o755)
    observations = []
    cc = os.environ.get("CC", "cc")
    for row in record["slices"]:
        case_root = output / row["id"]
        case_root.mkdir(parents=True, exist_ok=True)
        driver_marker.unlink(missing_ok=True)
        source = row["source_fixture"]
        oracle = measure(
            ["./gust", "--backend", "mir-to-c", source],
            case_root / "mir-to-c",
        )
        require(
            oracle["status"] == 0,
            f"{row['id']}: MIR-to-C compile status drifted",
        )
        oracle_c = case_root / "oracle.c"
        oracle_c.write_bytes(
            (case_root / "mir-to-c.stdout").read_bytes()
        )
        require(
            oracle_c.stat().st_size == row["oracle"]["generated_c_bytes"]
            and not (case_root / "mir-to-c.stderr").read_bytes(),
            f"{row['id']}: MIR-to-C output bytes or diagnostics drifted",
        )
        executable = case_root / "oracle"
        status = run_process(
            [
                cc, "-O0", "-w", "-pthread", "-Isrc", "-include",
                "src/runtime.c", str(oracle_c), "-o", str(executable),
            ],
            case_root / "oracle-link.stdout",
            case_root / "oracle-link.stderr",
        )
        require(
            status == 0 and executable.is_file(),
            f"{row['id']}: MIR-to-C output did not link",
        )
        status = run_process(
            [str(executable)],
            case_root / "oracle-run.stdout",
            case_root / "oracle-run.stderr",
        )
        require(
            status == 0
            and not (case_root / "oracle-run.stdout").read_bytes()
            and not (case_root / "oracle-run.stderr").read_bytes(),
            f"{row['id']}: MIR-to-C runtime oracle drifted",
        )
        env = os.environ.copy()
        env["GUST_NATIVE_BACKEND_DRIVER"] = str(capture_driver.resolve())
        env["DRIVER_MARKER"] = str(driver_marker.resolve())
        native = measure(
            ["./gust", "--backend", "cranelift", "-o",
             str(case_root / "native"), source],
            case_root / "cranelift",
            env,
        )
        diagnostic = row["cranelift"]
        native_stdout = (case_root / "cranelift.stdout").read_text(
            encoding="utf-8"
        )
        native_stderr = (case_root / "cranelift.stderr").read_text(
            encoding="utf-8"
        )
        for marker in (
            f"decision={diagnostic['decision']}",
            f"reason_code={diagnostic['reason_code']}",
            f"expected_failure_stage={diagnostic['failure_stage']}",
            f"class={diagnostic['diagnostic_class']}",
            f"source={source}",
            f"line={diagnostic['line']}",
        ):
            require(
                marker in native_stdout,
                f"{row['id']}: missing diagnostic marker {marker}",
            )
        require(
            native["status"] == diagnostic["compile_exit"]
            and native_stderr == diagnostic["diagnostic"] + "\n"
            and not (case_root / "native").exists()
            and not driver_marker.exists(),
            f"{row['id']}: native classification or resource state drifted",
        )
        check_budget(row, "mir_to_c", oracle)
        check_budget(row, "cranelift", native)
        observations.append(
            {"id": row["id"], "mir_to_c": oracle, "cranelift": native}
        )

    declaration = record["declaration_admission"]
    positive_root = output / "declaration-admission"
    positive_root.mkdir(parents=True, exist_ok=True)
    source = declaration["source_fixture"]
    oracle_c = positive_root / "oracle.c"
    status = run_process(
        ["./gust", "--backend", "mir-to-c", source],
        oracle_c,
        positive_root / "oracle.compiler.stderr",
    )
    require(
        status == declaration["oracle"]["compile_exit"]
        and oracle_c.stat().st_size > 0
        and not (positive_root / "oracle.compiler.stderr").read_bytes(),
        "declaration witness MIR-to-C compilation failed",
    )
    oracle = positive_root / "oracle"
    status = run_process(
        [
            cc, "-O0", "-w", "-pthread", "-Isrc", "-include",
            "src/runtime.c", str(oracle_c), "-o", str(oracle),
        ],
        positive_root / "oracle-link.stdout",
        positive_root / "oracle-link.stderr",
    )
    require(status == 0, "declaration witness MIR-to-C link failed")
    oracle_status = run_process(
        [str(oracle)],
        positive_root / "oracle.stdout",
        positive_root / "oracle.stderr",
    )
    native = positive_root / "native"
    env = os.environ.copy()
    env["GUST_NATIVE_BACKEND_DRIVER"] = str(worker.resolve())
    status = run_process(
        ["./gust", "--backend", "cranelift", "-o", str(native), source],
        positive_root / "native.compiler.stdout",
        positive_root / "native.compiler.stderr",
        env,
    )
    require(
        status == 0 and native.is_file(),
        "declaration witness native compilation failed",
    )
    native_status = run_process(
        [str(native)],
        positive_root / "native.stdout",
        positive_root / "native.stderr",
    )
    require(
        oracle_status == declaration["oracle"]["run_exit"]
        and native_status == declaration["cranelift"]["run_exit"]
        and (positive_root / "oracle.stdout").read_text(encoding="utf-8")
        == declaration["oracle"]["stdout"]
        and (positive_root / "native.stdout").read_text(encoding="utf-8")
        == declaration["cranelift"]["stdout"]
        and (positive_root / "oracle.stderr").read_text(encoding="utf-8")
        == declaration["oracle"]["stderr"]
        and (positive_root / "native.stderr").read_text(encoding="utf-8")
        == declaration["cranelift"]["stderr"]
        and not (positive_root / "native.compiler.stdout").read_bytes()
        and not (positive_root / "native.compiler.stderr").read_bytes()
        and not Path(str(native) + ".phase10.bundle").exists()
        and not Path(str(native) + ".phase10.request").exists(),
        "declaration witness backend parity or cleanup drifted",
    )
    (output / "observations.json").write_text(
        json.dumps(
            {
                "contract_version": record["contract_version"],
                "slices": observations,
                "declaration_admission": {
                    "mir_to_c_run_exit": oracle_status,
                    "cranelift_run_exit": native_status,
                },
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("validate")
    subparsers.add_parser("project")
    subparsers.add_parser("check-review")
    evidence = subparsers.add_parser("run-evidence")
    evidence.add_argument("--output", type=Path, required=True)
    measure_parser = subparsers.add_parser("measure-one")
    measure_parser.add_argument("--result", type=Path, required=True)
    measure_parser.add_argument("--stdout", type=Path, required=True)
    measure_parser.add_argument("--stderr", type=Path, required=True)
    measure_parser.add_argument("rest", nargs=argparse.REMAINDER)
    args = parser.parse_args()

    if args.command == "validate":
        validate()
        print(f"{GUARD_L1}: ok")
    elif args.command == "project":
        REVIEW.write_text(render(validate()), encoding="utf-8")
    elif args.command == "check-review":
        require(
            REVIEW.is_file()
            and REVIEW.read_text(encoding="utf-8") == render(validate()),
            "generated review is stale; run the projector",
        )
        print(f"{GUARD_L1}: review ok")
    elif args.command == "run-evidence":
        run_evidence(args.output)
        print(f"{GUARD_L2}: ok")
    else:
        command = args.rest
        if command and command[0] == "--":
            command = command[1:]
        require(bool(command), "measure-one requires a command")
        measure_one(args.result, args.stdout, args.stderr, command)


if __name__ == "__main__":
    main()
