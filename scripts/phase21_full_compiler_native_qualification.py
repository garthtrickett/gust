#!/usr/bin/env python3
"""Validate, project, and execute Patch 21.14 qualification evidence."""

from __future__ import annotations

import argparse
import json
import os
import resource
import subprocess
import tempfile
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE21_FULL_COMPILER_NATIVE_QUALIFICATION.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase21-full-compiler-native-qualification.yml"
FIXTURE = ROOT / "compiler/fixtures/native_backend_phase21_full_program_minimal.mir"
WORKER = ROOT / "build/gust-native-backend"
PACKAGED_GUST = ROOT / "build/phase10-package/bin/gust"
RUNTIME_PACKAGE = ROOT / "build/phase10-package/bin/gust-runtime-package.a"
GUARD_L1 = "guard-cranelift-phase21-full-compiler-native-qualification-contract"
GUARD_L2 = "guard-cranelift-phase21-full-compiler-native-qualification-evidence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def run(command: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
        **kwargs,
    )


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    predecessor = registry.get("phase21_native_feature_seed_convergence", {})
    require(
        predecessor.get("status") == "patch21_13a_complete"
        and predecessor.get("next_patch") == "21.14",
        "Patch 21.13a predecessor authority drifted",
    )
    record = registry.get("phase21_full_compiler_native_qualification", {})
    expected = {
        "contract_version": "phase21_full_compiler_native_qualification_v1",
        "status": "patch21_14_complete",
        "next_patch": "21.15",
        "review_view": "compiler/CRANELIFT_PHASE21_FULL_COMPILER_NATIVE_QUALIFICATION.md",
        "observed_main_sha": "649236a673888d4b1da1f1d33c3ffe376fa1cf8a",
        "predecessor_authority": "phase21_native_feature_seed_convergence_v1",
        "source_entry": "compiler/test_runner_entry.gst",
        "canonical_format": "gust.compiler_executable_mir.v1",
        "program_bundle_format": "gust.compiler_program_mir_bundle.v1",
        "target_triple": "x86_64-unknown-linux-gnu",
        "object_format": "Elf",
        "semantic_oracle": "mir_to_c",
        "fallback_policy": "explicit_cranelift_no_fallback",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")

    require(
        record.get("canonical_inventory") == {
            "module_count": 42,
            "minimum_layout_count": 788,
            "minimum_enum_count": 40,
            "minimum_function_count": 1803,
            "minimum_node_count": 247483,
            "entry_function": "main",
            "symbol_authority": "strict_payload_worker_rederived_outer_bundle_exports_main_only",
        },
        "canonical inventory authority drifted",
    )
    require(
        record.get("runtime_package") == {
            "format": "static_archive",
            "members": [
                "arena.o", "host_io.o", "file_io.o", "scratch.o", "fiber.o",
                "collections.o", "strings.o", "approved_scalar_imports.o",
            ],
            "symbol_policy": "existing_registered_runtime_symbols_only",
        },
        "runtime package authority drifted",
    )
    require(
        record.get("resource_cleanup_transport") == {
            "source_authority": "typechecker_resource_cleanup_plans",
            "operations": [
                "ResourceStorage", "ConditionalCleanup", "ScopeCleanup",
            ],
            "normal_exit_order": "source_defers_then_scope_cleanup_plan",
            "return_order": "all_active_source_defers_then_return_cleanup_plan",
            "backend_inference": False,
        },
        "resource cleanup transport authority drifted",
    )
    require(
        record.get("artifact") == {
            "kind": "linked_native_executable",
            "elf_class": "ELF64",
            "elf_type": "DYN",
            "machine": "Advanced Micro Devices X86-64",
            "minimum_bytes": 1048576,
            "maximum_bytes": 20971520,
            "exports_main": True,
            "generated_C_in_qualified_route": False,
        },
        "artifact authority drifted",
    )
    require(
        record.get("failure_contract") == {
            "fixture": "compiler/fixtures/native_backend_phase21_full_program_minimal.mir",
            "malformation": "unknown_full_program_operation",
            "exit_status": 2,
            "diagnostic": "gust Cranelift experiment failed: unknown full-program operation BogusOperation\n",
            "diagnostic_runs_byte_identical": True,
            "failed_object_absent": True,
            "transient_request_bundle_and_object_absent_after_success": True,
        },
        "failure cleanup or diagnostic authority drifted",
    )
    require(
        record.get("predecessor_replay") == {
            "authorities": [
                "phase21_opening_evidence_v1",
                "phase21_residue_migration_authority_v1",
                "phase21_collection_string_native_source_v1",
                "phase21_filesystem_allocation_native_source_v1",
                "phase21_resource_sync_native_source_v1",
                "phase21_compiler_support_native_qualification_v1",
                "phase21_selected_compiler_module_qualification_v1",
            ],
            "historical_records_preserved": True,
            "live_decision": "supported",
            "canonical_format": "gust.compiler_executable_mir.v1",
            "artifact": "linked_native_executable",
            "execution_policy": "exit_stdout_and_stderr_match_each_slice_MIR_to_C_oracle",
        },
        "predecessor live-replay authority drifted",
    )
    measurements = record.get("measurements", {})
    require(
        measurements.get("max_compile_elapsed_ms") == 600000
        and measurements.get("max_peak_rss_kib") == 6291456,
        "qualification budgets drifted",
    )
    require(
        record.get("boundary") == {
            "changes_accepted_Gust_program_meaning": False,
            "adds_module_specific_exceptions": False,
            "changes_ABI_layout_or_runtime_symbols": False,
            "changes_bootstrap_seed": False,
            "changes_default_backend_or_fallback": False,
            "edits_stdlib_or_CR15": False,
            "begins_patch21_15": False,
        },
        "Patch 21.14 boundary widened",
    )

    require(FIXTURE.is_file(), "minimal full-program fixture is missing")
    fixture = FIXTURE.read_text(encoding="utf-8")
    require(
        fixture.startswith("format: gust.compiler_executable_mir.v1\n")
        and "entry_function_index: 0\n" in fixture,
        "minimal full-program fixture shape drifted",
    )
    rust = (ROOT / "compiler/experiments/cranelift/src/main.rs").read_text(encoding="utf-8")
    full_rust = (ROOT / "compiler/experiments/cranelift/src/full_program.rs").read_text(encoding="utf-8")
    source = (ROOT / "compiler/mir_native_backend_full_program_source.gst").read_text(encoding="utf-8")
    driver = (ROOT / "compiler/mir_native_backend_driver.gst").read_text(encoding="utf-8")
    for token in (
        "mod full_program;",
        "full_program::validate_contents(canonical_mir)",
        "full_program::lower_contents(",
        '"phase21-full-program-object"',
    ):
        require(token in rust, f"worker integration lacks {token}")
    for token in (
        'pub const FORMAT: &str = "gust.compiler_executable_mir.v1";',
        "pub fn validate_contents",
        "pub fn lower_contents",
        "target_object_builder",
    ):
        require(token in full_rust, f"strict full-program worker lacks {token}")
    require(
        "mir_native_full_program_analyze_signatures" in source
        and "mir_native_full_program_emit_bundle" in source
        and "for function_index in 0..len(functions)" not in source.split(
            "func mir_native_full_program_emit_bundle", 1
        )[1],
        "generic source lowering or compact outer symbol authority drifted",
    )
    require(
        "len(canonical_formats) != 3" in driver
        and '"gust.compiler_executable_mir.v1"' in driver,
        "driver handshake does not own the full-program format",
    )
    makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
    require(
        "PHASE10_NATIVE_BACKEND_SOURCES = $(wildcard compiler/experiments/cranelift/src/*.rs)"
        in makefile
        and "$(PHASE10_NATIVE_BACKEND_SOURCES)" in makefile,
        "native worker build does not track every Rust source module",
    )
    for member in record["runtime_package"]["members"]:
        require(member in makefile, f"runtime package build lacks {member}")

    require(
        "- [x] Patch 21.14 — Full Compiler Canonical-MIR and Native Object Qualification — DONE"
        in TASK.read_text(encoding="utf-8"),
        "TASK.md does not mark Patch 21.14 DONE",
    )
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(
        levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
        "Patch 21.14 guard levels drifted",
    )
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in justfile and f"{GUARD_L2}:" in justfile,
            "Patch 21.14 just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Patch 21.14 contract guard")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    for token in (f"just {GUARD_L1}", f"just {GUARD_L2}", "make gust phase10-native-package"):
        require(token in workflow, f"dedicated Patch 21.14 workflow lacks {token}")
    for runtime_path in ("- 'src/runtime.c'", "- 'src/runtime/**'"):
        require(workflow.count(runtime_path) == 2,
                f"dedicated Patch 21.14 workflow does not cover {runtime_path} twice")
    return record


def render(record: dict) -> str:
    inventory = record["canonical_inventory"]
    artifact = record["artifact"]
    cleanup = record["resource_cleanup_transport"]
    return "\n".join([
        "# Cranelift Phase 21 Full Compiler Native Qualification",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase21_full_compiler_native_qualification.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Canonical format: `{record['canonical_format']}`",
        f"- Target/object: `{record['target_triple']}` / `{record['object_format']}`",
        f"- Oracle: `{record['semantic_oracle']}`",
        f"- Fallback: `{record['fallback_policy']}`",
        "",
        "## Qualified full-compiler projection",
        "",
        f"- Modules: {inventory['module_count']}",
        f"- Layouts: at least {inventory['minimum_layout_count']}",
        f"- Enums: at least {inventory['minimum_enum_count']}",
        f"- Functions: at least {inventory['minimum_function_count']}",
        f"- Executable nodes: at least {inventory['minimum_node_count']}",
        f"- Entry: `{inventory['entry_function']}`",
        f"- Symbol authority: `{inventory['symbol_authority']}`",
        "",
        "## Artifact and failure evidence",
        "",
        f"- Artifact: `{artifact['elf_class']}` `{artifact['elf_type']}` `{artifact['machine']}` executable exporting `main`.",
        "- The qualified route emits no generated C and leaves no transient request, bundle, or object.",
        "- The existing runtime archive supplies all eight registered object members; no runtime symbol is added.",
        f"- Malformed MIR exits {record['failure_contract']['exit_status']} with byte-identical diagnostics and no object.",
        "- The native artifact's help output is byte-identical to the MIR-to-C-built compiler.",
        "- Frozen predecessor records remain historical; their live replay now requires supported native parity.",
        f"- Resource cleanup is transported from `{cleanup['source_authority']}` with no backend inference.",
        f"- Normal exit ordering: `{cleanup['normal_exit_order']}`; return ordering: `{cleanup['return_order']}`.",
        "",
        "Patch 21.14 adds generic executable canonical-MIR production and native",
        "lowering for the full compiler under existing Phase 14–16 authorities.",
        "It changes no accepted Gust meaning, ABI/layout/runtime symbol, bootstrap",
        "seed, default backend, fallback policy, Stdlib or CR-15 contract, and it",
        "does not begin Patch 21.15.",
        "",
    ])


def evidence(record: dict) -> None:
    for path in (ROOT / "gust", WORKER, PACKAGED_GUST, RUNTIME_PACKAGE):
        require(path.is_file(), f"evidence prerequisite is missing: {path.relative_to(ROOT)}")
    expected_members = record["runtime_package"]["members"]
    archive = run(["ar", "t", str(RUNTIME_PACKAGE)])
    require(archive.returncode == 0 and archive.stdout.splitlines() == expected_members,
            "runtime archive members drifted")

    valid = run([str(WORKER), "phase21-full-program-validate", str(FIXTURE)])
    require(valid.returncode == 0 and "entry=main" in valid.stdout and valid.stderr == "",
            "minimal full-program validation failed")
    with tempfile.TemporaryDirectory(prefix="phase21-14-", dir=ROOT / "build") as raw_tmp:
        tmp = Path(raw_tmp)
        object_path = tmp / "minimal.o"
        lowered = run([str(WORKER), "phase21-full-program-object", str(FIXTURE), str(object_path)])
        require(lowered.returncode == 0 and object_path.stat().st_size > 0,
                "minimal full-program object lowering failed")
        header = run(["readelf", "-h", str(object_path)])
        require(
            header.returncode == 0
            and "ELF64" in header.stdout
            and "REL (Relocatable file)" in header.stdout
            and record["artifact"]["machine"] in header.stdout,
            "minimal object target properties drifted",
        )

        malformed = tmp / "malformed.mir"
        malformed.write_text(
            FIXTURE.read_text(encoding="utf-8").replace(
                "496e74656765724c69746572616c",
                "426f6775734f7065726174696f6e",
                1,
            ),
            encoding="utf-8",
        )
        failed_object = tmp / "failed.o"
        attempts = [
            run([str(WORKER), "phase21-full-program-object", str(malformed), str(failed_object)])
            for _ in range(2)
        ]
        failure = record["failure_contract"]
        require(
            all(attempt.returncode == failure["exit_status"] for attempt in attempts)
            and attempts[0].stdout == attempts[1].stdout == ""
            and attempts[0].stderr == attempts[1].stderr == failure["diagnostic"]
            and not failed_object.exists(),
            "malformed full-program diagnostics or failure cleanup drifted",
        )

        compiler = tmp / "gust-native"
        started = time.monotonic()
        built = run([
            str(PACKAGED_GUST), "--backend", "cranelift", "-o", str(compiler),
            "compiler/test_runner_entry.gst",
        ], timeout=record["measurements"]["max_compile_elapsed_ms"] / 1000)
        elapsed_ms = int((time.monotonic() - started) * 1000)
        peak_rss_kib = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
        require(built.returncode == 0 and built.stdout == "" and built.stderr == "",
                "full compiler native publication failed")
        require(
            record["artifact"]["minimum_bytes"] <= compiler.stat().st_size
            <= record["artifact"]["maximum_bytes"],
            "full compiler native artifact size left its budget",
        )
        require(elapsed_ms <= record["measurements"]["max_compile_elapsed_ms"]
                and peak_rss_kib <= record["measurements"]["max_peak_rss_kib"],
                "full compiler compile resource budget exceeded")
        header = run(["readelf", "-h", str(compiler)])
        symbols = run(["nm", "-g", str(compiler)])
        require(
            header.returncode == 0
            and artifact_header(record, header.stdout)
            and symbols.returncode == 0
            and any(line.rstrip().endswith(" T main") for line in symbols.stdout.splitlines()),
            "linked compiler artifact properties drifted",
        )
        oracle_help = run([str(ROOT / "gust"), "--help"])
        native_help = run([str(compiler), "--help"])
        require(
            oracle_help.returncode == native_help.returncode == 0
            and oracle_help.stdout == native_help.stdout
            and oracle_help.stderr == native_help.stderr == "",
            "native compiler help behavior diverged from the oracle",
        )
        residue = [
            path.name for path in tmp.iterdir()
            if path.name != compiler.name
            and not path.name.startswith(".gust-native.phase9g-link.")
            and path.name not in {"minimal.o", "malformed.mir"}
        ]
        require(not residue and not list(tmp.glob("*.c")),
                f"qualified route left transient or generated-C residue: {residue}")
    print(
        f"{GUARD_L2}: ok elapsed_ms={elapsed_ms} peak_rss_kib={peak_rss_kib} "
        f"artifact_bytes={compiler.stat().st_size if compiler.exists() else 'cleaned'}"
    )


def artifact_header(record: dict, output: str) -> bool:
    artifact = record["artifact"]
    return (
        artifact["elf_class"] in output
        and f"Type:                              {artifact['elf_type']}" in output
        and artifact["machine"] in output
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review", "evidence"))
    args = parser.parse_args()
    record = validate()
    if args.command == "project":
        REVIEW.write_text(render(record), encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and REVIEW.read_text(encoding="utf-8") == render(record),
                "generated review is stale; run project")
    elif args.command == "evidence":
        evidence(record)
    print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
