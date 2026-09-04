#!/usr/bin/env python3
"""Validate and exercise Patch 24.2f implicit Resource transfer."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True

from phase24_cr15_stdlib_guard_transition import (
    s1_9_resource_assignment_roadmap_state,
    s1_9_resource_assignment_roadmap_successor,
)


ROOT = Path(__file__).resolve().parent.parent
TYPECHECKER = ROOT / "compiler/typechecker.gst"
MODULE = ROOT / "compiler/phase24_resource_implicit_transfer_module.gst"
POSITIVE = ROOT / "compiler/phase24_resource_implicit_transfer_positive.gst"
REJECTED = ROOT / "compiler/phase24_resource_implicit_transfer_source_rejected.gst"
NON_RESOURCE = ROOT / "compiler/phase24_resource_implicit_transfer_non_resource.gst"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase24-resource-implicit-transfer.yml"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
GUARD_L1 = "guard-cranelift-phase24-resource-implicit-transfer-contract"
GUARD_L2 = "guard-cranelift-phase24-resource-implicit-transfer-evidence"
DIAGNOSTIC = b"LinearResourceUseAfterMove"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def implementation_slices(source: str) -> tuple[str, str]:
    diagnostic_start = source.index("func env_report_linear_resource_use_after_move(")
    diagnostic_end = source.index("func typechecker_query_side_is_scoped_field(", diagnostic_start)
    binding_marker = "mut resource_bound := env_bind_resource_expression(env, name, val_idx, ctx);"
    binding_start = source.index(binding_marker)
    binding_end = source.index("if (*env).current_function_local_vars", binding_start)
    return source[diagnostic_start:diagnostic_end], source[binding_start:binding_end]


def validate_implementation(source: str) -> None:
    diagnostic, binding = implementation_slices(source)
    require("resource_value_identities.Get(name).Ok" in diagnostic,
            "moved diagnostic is not gated by compiler-tracked Resource identity")
    require("moved_vars.Get(name).Ok" in diagnostic and
            "LinearResourceUseAfterMove" in diagnostic,
            "generic moved Resource diagnostic is missing")
    require("resource_bound == 1 && ctx[val_idx].tag == 0" in binding,
            "implicit transfer is not limited to a successful direct identifier binding")
    require("moved_vars.Insert(ctx[val_idx].Identifier.name, 1);" in binding,
            "implicit transfer does not invalidate its source in general moved state")

    report_call = (
        "env_report_linear_resource_use_after_move(env, resolved_name, "
        "expr.Identifier.span, ctx);"
    )
    general_move = "if (*env).moved_vars.Get(resolved_name).Ok {"
    require(source.index(report_call) < source.index(general_move, source.index(report_call)),
            "Resource diagnostic no longer precedes the general moved diagnostic")

    selected = diagnostic + binding
    forbidden = (
        "Mutex", "MutexGuard", "sync.lock", "sync.get", "current_file",
        "phase24_resource_implicit_transfer", "--backend", "cranelift",
        "mir-to-c", "fixture",
    )
    for spelling in forbidden:
        require(spelling not in selected,
                f"implementation recognizes forbidden spelling {spelling!r}")


def validate() -> None:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    s1_9_resource_assignment_roadmap_successor(registry)
    require(s1_9_resource_assignment_roadmap_state(registry) ==
            "post_roadmap_amendment",
            "Patch 24.2e predecessor is not the exact amended roadmap state")

    source = TYPECHECKER.read_text(encoding="utf-8")
    validate_implementation(source)

    # These mutations prove that the structural checks fail for each semantic
    # dependency instead of merely checking that the files exist.
    mutations = (
        source.replace("resource_bound == 1 &&", "resource_bound == 0 &&", 1),
        source.replace("(*env).moved_vars.Insert(ctx[val_idx].Identifier.name, 1);", "", 1),
        source.replace("mut resource_bound := env_bind_resource_expression", "mut MutexGuard := env_bind_resource_expression", 1),
    )
    for mutation in mutations:
        try:
            validate_implementation(mutation)
        except (SystemExit, ValueError):
            continue
        raise SystemExit(f"{GUARD_L1}: a structural falsifier was not detected")

    module = MODULE.read_text(encoding="utf-8")
    for marker in (
        "#[linear]", "#[destructor(retire_ticket)]", "#[opaque]",
        "type Ticket struct", "func acquire_ticket", "func read_ticket",
    ):
        require(marker in module, f"generic Resource witness is missing {marker}")
    positive = POSITIVE.read_text(encoding="utf-8")
    rejected = REJECTED.read_text(encoding="utf-8")
    non_resource = NON_RESOURCE.read_text(encoding="utf-8")
    require("mut destination := source;" in positive and
            "read_ticket(&destination)" in positive and
            "read_ticket(&source)" not in positive,
            "positive destination-only witness drifted")
    require("mut destination := source;" in rejected and
            "read_ticket(&source)" in rejected and
            "read_ticket(&destination)" in rejected,
            "source-reuse witness drifted")
    require("mut destination := source;" in non_resource and
            "source + destination" in non_resource,
            "unrelated non-Resource copy control drifted")

    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "test-level assignments drifted")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in just and f"{GUARD_L2}:" in just,
            "just guard reachability drifted")
    require(GUARD_L1 in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast contract reachability drifted")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    for marker in (
        "pull_request:", "push:", "workflow_dispatch:", "compiler/*.gst",
        "scripts/phase24_resource_implicit_transfer.py",
        GUARD_L1, GUARD_L2,
    ):
        require(marker in workflow, f"workflow is missing {marker}")


def run(command: list[str], *, env: dict[str, str] | None = None,
        timeout: int = 180) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, env=env, timeout=timeout,
                          check=False)


def compile_c(compiler: Path, source: Path) -> bytes:
    result = run([str(compiler), "--backend", "mir-to-c", str(source)])
    require(result.returncode == 0 and not result.stderr and
            result.stdout.startswith(b"// Transpiled C Code\n#include"),
            f"explicit MIR-to-C compilation failed for {source.name}: "
            f"stdout={result.stdout.decode(errors='replace')!r} "
            f"stderr={result.stderr.decode(errors='replace')!r}")
    return result.stdout


def execute_c(c_output: bytes, runtime: Path, temporary: Path,
              stem: str) -> subprocess.CompletedProcess[bytes]:
    c_source = temporary / f"{stem}.c"
    c_source.write_bytes(runtime.read_bytes() + c_output)
    artifact = temporary / f"{stem}-c"
    compiled = run(["cc", "-O2", "-Wall", "-pthread", "-Isrc",
                    str(c_source), "-o", str(artifact)])
    require(compiled.returncode == 0,
            f"host C compilation failed for {stem}: "
            f"{compiled.stderr.decode(errors='replace')}")
    return run([str(artifact)], timeout=20)


def compile_and_execute_native(compiler: Path, source: Path, artifact: Path,
                               route: list[str]) -> tuple[bytes, subprocess.CompletedProcess[bytes]]:
    compiled = run([str(compiler), *route, "-o", str(artifact), str(source)])
    require(compiled.returncode == 0 and not compiled.stdout and
            not compiled.stderr and artifact.is_file() and artifact.stat().st_size > 0,
            f"native compilation failed for {source.name} via {route}: "
            f"stdout={compiled.stdout.decode(errors='replace')!r} "
            f"stderr={compiled.stderr.decode(errors='replace')!r}")
    contents = artifact.read_bytes()
    executed = run([str(artifact)], timeout=20)
    return contents, executed


def assert_pre_backend_rejection(compiler: Path, source: Path,
                                 temporary: Path) -> None:
    outputs: list[bytes] = []
    for label, route, accepts_output in (
        ("c", ["--backend", "mir-to-c"], False),
        ("native", ["--backend", "cranelift"], True),
    ):
        artifact = temporary / f"must-not-exist-{source.stem}-{label}"
        output_args = ["-o", str(artifact)] if accepts_output else []
        result = run([str(compiler), *route, *output_args, str(source)])
        require(result.returncode == 1 and not result.stderr and
                DIAGNOSTIC in result.stdout and not artifact.exists(),
                f"source reuse in {source.name} was not rejected before {label} "
                "backend selection: "
                f"stdout={result.stdout.decode(errors='replace')!r} "
                f"stderr={result.stderr.decode(errors='replace')!r}")
        require(b"driver_handshake" not in result.stdout and
                b"Native backend driver" not in result.stdout and
                b"Transpiled C Code" not in result.stdout,
                f"source reuse reached a backend through {label}")
        outputs.append(result.stdout)
    require(outputs[0] == outputs[1],
            f"pre-backend diagnostic differs between retained paths for {source.name}")


def evidence() -> None:
    validate()
    compiler = ROOT / "build/phase10-package/bin/gust"
    driver = ROOT / "build/phase10-package/bin/gust-native-backend"
    runtime_package = ROOT / "build/phase10-package/bin/gust-runtime-package.a"
    runtime = ROOT / "src/runtime.c"
    for prerequisite in (compiler, driver, runtime_package, runtime):
        require(prerequisite.is_file(), f"missing prerequisite {prerequisite}")

    with tempfile.TemporaryDirectory(prefix="gust-phase24-resource-transfer-") as name:
        temporary = Path(name)

        c_output = compile_c(compiler, POSITIVE)
        main_start = c_output.index(b"int gust_user_main_impl(")
        main_end = c_output.index(b"\n}\n\nvoid gust_user_main(", main_start)
        main_body = c_output[main_start:main_end]
        cleanup = b"phase24_resource_implicit_transfer_module__retire_ticket(destination);"
        require(main_body.count(cleanup) == 1 and
                b"retire_ticket(source);" not in main_body and
                b"read_ticket(&(destination))" in main_body,
                "retained C path does not contain exactly one destination cleanup")
        c_run = execute_c(c_output, runtime, temporary, "positive")
        require(c_run.returncode == 0 and c_run.stdout == b"71\n" and
                not c_run.stderr,
                "retained C path did not execute one destination cleanup")

        native_results: list[tuple[bytes, subprocess.CompletedProcess[bytes]]] = []
        for label, route in (
            ("default", []),
            ("explicit", ["--backend", "cranelift"]),
        ):
            native_results.append(compile_and_execute_native(
                compiler, POSITIVE, temporary / f"positive-{label}", route
            ))
        for _, executed in native_results:
            require(executed.returncode == 0 and executed.stdout == b"71\n" and
                    not executed.stderr,
                    "native path did not execute one destination cleanup")
        require(native_results[0][0] == native_results[1][0],
                "default and explicit Cranelift artifacts differ")

        assert_pre_backend_rejection(compiler, REJECTED, temporary)

        extra_owner = temporary / "extra_owner_rejected.gst"
        extra_owner.write_text(
            'import "phase24_resource_implicit_transfer_module.gst" as resource;\n\n'
            'func main() int {\n'
            '    mut source := resource.acquire_ticket(72);\n'
            '    mut destination := source;\n'
            '    mut extra := destination;\n'
            '    return resource.read_ticket(&destination) - '
            'resource.read_ticket(&extra);\n'
            '}\n', encoding="utf-8"
        )
        (temporary / MODULE.name).write_bytes(MODULE.read_bytes())
        assert_pre_backend_rejection(compiler, extra_owner, temporary)

        renamed_module = temporary / "backend_fixture_alias.gst"
        renamed_module.write_text(
            MODULE.read_text(encoding="utf-8")
            .replace("Ticket", "Permit")
            .replace("retire_ticket", "release_permit")
            .replace("acquire_ticket", "make_permit")
            .replace("read_ticket", "inspect_permit"),
            encoding="utf-8",
        )
        renamed = temporary / "mutex_guard_cranelift_fixture.gst"
        renamed.write_text(
            'import "backend_fixture_alias.gst" as unrelated;\n\n'
            'func main() int {\n'
            '    mut owner := unrelated.make_permit(73);\n'
            '    mut copy := owner;\n'
            '    mut forbidden := unrelated.inspect_permit(&owner);\n'
            '    return forbidden - unrelated.inspect_permit(&copy);\n'
            '}\n', encoding="utf-8"
        )
        assert_pre_backend_rejection(compiler, renamed, temporary)

        non_resource_c = execute_c(
            compile_c(compiler, NON_RESOURCE), runtime, temporary, "non-resource"
        )
        require(non_resource_c.returncode == 0 and not non_resource_c.stdout and
                not non_resource_c.stderr,
                "unrelated non-Resource copy semantics changed on retained C path")
        _, non_resource_native = compile_and_execute_native(
            compiler, NON_RESOURCE, temporary / "non-resource-native",
            ["--backend", "cranelift"],
        )
        require(non_resource_native.returncode == 0 and
                not non_resource_native.stdout and not non_resource_native.stderr,
                "unrelated non-Resource copy semantics changed on native path")

        failed_artifact = temporary / "must-not-fallback"
        environment = os.environ.copy()
        environment["GUST_NATIVE_BACKEND_DRIVER"] = "/bin/false"
        failed = run([str(compiler), "--backend", "cranelift", "-o",
                      str(failed_artifact), str(POSITIVE)], env=environment)
        require(failed.returncode == 1 and not failed_artifact.exists() and
                b"driver_handshake_error" in failed.stdout and
                b"Transpiled C Code" not in failed.stdout,
                "supported transfer silently fell back after driver failure")

    print("phase24_resource_implicit_transfer: evidence ok")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "evidence"))
    args = parser.parse_args()
    if args.command == "evidence":
        evidence()
    else:
        validate()
        print("phase24_resource_implicit_transfer: ok")


if __name__ == "__main__":
    main()
