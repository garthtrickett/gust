#!/usr/bin/env python3
"""Validate and project Patch 21.10 filesystem/allocation native authority."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE21_FILESYSTEM_ALLOCATION_NATIVE_SOURCE.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase21-filesystem-allocation-native-source.yml"
LOWERER = ROOT / "compiler/mir_native_backend_filesystem_allocation_source.gst"
GENERIC = ROOT / "compiler/mir_native_backend_generic_source.gst"
ROUTE = ROOT / "compiler/mir_native_backend_source_route.gst"
WORKER = ROOT / "compiler/experiments/cranelift/src/main.rs"
PARITY_SCRIPT = ROOT / "scripts/phase21_filesystem_allocation_native_source.sh"
MAKEFILE = ROOT / "Makefile"
GUARD_L1 = "guard-cranelift-phase21-filesystem-allocation-native-source-contract"
GUARD_L2 = "guard-cranelift-phase21-filesystem-allocation-native-source-parity"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    predecessor = registry.get("phase21_collection_string_native_source", {})
    record = registry.get("phase21_filesystem_allocation_native_source")
    require(isinstance(record, dict), "Patch 21.10 authority is missing")
    require(record.get("contract_version") ==
            "phase21_filesystem_allocation_native_source_v1",
            "contract version drifted")
    require(record.get("status") == "patch21_10_complete" and
            record.get("next_patch") == "21.11",
            "status or successor drifted")
    require(record.get("predecessor_authority") ==
            predecessor.get("contract_version") and
            predecessor.get("status") == "patch21_9_complete",
            "Patch 21.9 predecessor link drifted")
    require(record.get("source_route_policy") ==
            "typed_AST_operations_lower_to_canonical_MIR_without_source_path_fixture_name_type_name_or_generated_C_recognition",
            "source route policy drifted")
    require(record.get("scope", "").startswith(
            "bounded_compiler_owned_filesystem_and_branded_arena_allocation"),
            "bounded cohort is not explicit")

    require([item.get("id") for item in record.get("capabilities", [])] == [
        "scheduled_defer_call_edges",
        "approved_filesystem_runtime_calls",
        "branded_arena_allocation_write_and_index",
    ], "capability population drifted")
    require(all(item.get("state") and item.get("canonical_evidence")
                for item in record["capabilities"]),
            "a capability lacks state or canonical evidence")

    cases = record.get("source_cases", [])
    require([case.get("id") for case in cases] == [
        "filesystem_primary", "filesystem_renamed_variant",
        "allocation_primary", "allocation_renamed_variant",
    ], "source differential population drifted")
    require(all((ROOT / case["source_fixture"]).is_file() and
                case.get("expected_exit") == 0 and
                case.get("expected_stderr") == "" and
                case.get("expected_stdout")
                for case in cases), "a source case is incomplete")
    require(all(bool(case.get("expected_file")) ==
                case["id"].startswith("filesystem")
                for case in cases), "filesystem effect evidence drifted")

    rejected = record.get("rejected_source_cases", [])
    require([case.get("id") for case in rejected] == [
        "filesystem_computed_write_contents",
        "allocation_computed_field_value",
    ], "rejection population drifted")
    require(all((ROOT / case["source_fixture"]).is_file() and
                case.get("expected_failure_stage") ==
                "before_driver_discovery" and
                case.get("oracle_exit") == 0 and
                case.get("oracle_stderr") == "" and
                case.get("oracle_stdout")
                for case in rejected), "a rejection case is incomplete")

    canonical = record.get("canonical_contract", {})
    require(canonical.get("format") == "gust.compiler_mir_ingestion.v2" and
            canonical.get("operations") == [
                "ArenaInit", "LocalI32SetCall", "LocalStringSetCall",
                "ArenaStoreI32", "LocalI32SetArenaLoad", "CallVoid",
                "ReturnI32",
            ] and canonical.get("types") ==
            ["arena", "usize", "int", "str", "void"] and
            canonical.get("runtime_imports") == [
                "os_Arena_New", "os_Arena_Free", "os_ArenaAlloc",
                "os_WriteFile", "os_ReadFile", "os_LogInt", "os_LogStr",
            ] and canonical.get("fallback") == "forbidden",
            "canonical MIR contract drifted")
    require(canonical.get("arena_access_validation") == {
        "allocation_provenance":
        "earlier_same_block_import_whose_link_symbol_is_os_ArenaAlloc_with_same_arena_and_literal_size",
        "access_range":
        "non_negative_byte_offset_plus_four_byte_i32_width_within_allocation_size",
        "index_reassignment": "clears_allocation_provenance",
    }, "canonical arena-access validation contract drifted")
    runtime = record.get("runtime_package", {})
    require(runtime.get("retained_components") == [
        "src/runtime/arena.c", "src/runtime/host_io.c",
        "src/runtime/file_io.c",
    ] and runtime.get("new_or_changed_runtime_symbols") == [],
            "retained runtime package boundary drifted")
    worker_contract = record.get("worker_contract", {})
    require(worker_contract.get("source_recognition") is False and
            worker_contract.get("string_literal_transport") ==
            "phase21_9_StringLiteralUtf8Hex_preserved" and
            worker_contract.get("canonical_fixtures") == [
                "compiler/fixtures/native_backend_phase21_filesystem_source.mir",
                "compiler/fixtures/native_backend_phase21_allocation_source.mir",
            ] and all((ROOT / fixture).is_file() for fixture in
                      worker_contract.get("canonical_fixtures", [])) and
            worker_contract.get("generated_C") is False,
            "worker transport boundary drifted")
    require(record.get("remaining_residues") == [
        {"category": "resources", "destination_patch": "21.11",
         "decision": "source_or_type_failure"},
        {"category": "threading_synchronization", "destination_patch":
         "21.11", "decision": "deferred"},
    ], "Patch 21.11 residue ownership changed")
    boundary = record.get("boundary", {})
    require(boundary == {
        "changes_Gust_program_meaning": False,
        "changes_explicit_Cranelift_capability": True,
        "changes_canonical_MIR_transport": True,
        "changes_ABI_or_layout_authority": False,
        "adds_or_changes_runtime_symbols": False,
        "changes_bootstrap_seed": False,
        "edits_stdlib": False,
    }, "Patch 21.10 boundary drifted")

    lowerer = LOWERER.read_text(encoding="utf-8")
    for marker in (
        "mir_native_filesystem_allocation_source_lower", "ArenaInit",
        "LocalStringSetCall", "ArenaStoreI32", "LocalI32SetArenaLoad",
        "StringLiteralUtf8Hex", "phase21_10",
    ):
        require(marker in lowerer, f"lowerer lacks {marker}")
    worker = WORKER.read_text(encoding="utf-8")
    for fixture in [case["source_fixture"] for case in cases + rejected]:
        fixture_name = Path(fixture).name
        require(fixture_name not in lowerer and fixture_name not in worker,
                f"source or worker recognizes fixture name {fixture_name}")
    require("filesystem_allocation.mir_native_filesystem_allocation_source_lower"
            in GENERIC.read_text(encoding="utf-8"),
            "generic source route does not invoke Patch 21.10 lowerer")
    route = ROUTE.read_text(encoding="utf-8")
    for marker in ("ArenaInit", "arena", "usize", "os_WriteFile",
                   "os_ReadFile", "os_ArenaAlloc"):
        require(marker in route, f"static capability set lacks {marker}")
    for marker in ("ArenaPointer", "USizeLiteral", "LocalStringSetCall",
                   "ArenaStoreI32", "LocalI32SetArenaLoad",
                   "StringLiteralUtf8Hex"):
        require(marker in worker, f"worker lacks {marker}")
    parity_script = PARITY_SCRIPT.read_text(encoding="utf-8")
    for marker in (
        "arena-negative-offset", "arena-out-of-range",
        "arena-missing-provenance", "arena-index-reassigned",
        "arena access byte offset must be non-negative",
        "arena access range 4..8 exceeds allocation size 4",
        "arena access requires same-block os_ArenaAlloc provenance",
    ):
        require(marker in parity_script,
                f"malformed arena-MIR evidence lacks {marker}")
    makefile = MAKEFILE.read_text(encoding="utf-8")
    for marker in ("src/runtime/arena.c", "src/runtime/host_io.c",
                   "src/runtime/file_io.c", "build/gust-runtime-package.a"):
        require(marker in makefile, f"runtime archive build lacks {marker}")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 21.10 — Filesystem and Allocation Native Source Migration — DONE"
            in task and "**Exit Gate:** all four registered source cases" in task,
            "TASK.md does not close Patch 21.10")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 21.10 guard levels drifted")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in justfile and f"{GUARD_L2}:" in justfile,
            "Patch 21.10 just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own Patch 21.10 Level 1")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow and
            f"just {GUARD_L2}" in workflow,
            "dedicated Patch 21.10 workflow does not own both guards")
    return record


def render(record: dict) -> str:
    lines = [
        "# Cranelift Phase 21 Filesystem and Allocation Native Source Migration",
        "", "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase21_filesystem_allocation_native_source.py project`. Do not edit by hand.",
        "", f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`", f"- Next patch: `{record['next_patch']}`",
        f"- Scope: `{record['scope']}`", f"- Source route: `{record['source_route_policy']}`",
        "", "## Generic capability transition", "",
    ]
    for capability in record["capabilities"]:
        lines += [f"- `{capability['id']}`: `{capability['state']}`",
                  f"  - Canonical evidence: `{capability['canonical_evidence']}`"]
    lines += ["", "## Source differential cases", ""]
    for case in record["source_cases"]:
        lines += [f"- `{case['id']}` — `{case['source_fixture']}`",
                  f"  - Exit: `{case['expected_exit']}`",
                  f"  - Stdout: `{case['expected_stdout'].encode().hex()}` (hex)",
                  "  - Stderr: empty"]
        if case.get("expected_file"):
            lines += [f"  - File: `{case['expected_file']}` = "
                      f"`{case['expected_file_contents'].encode().hex()}` (hex)"]
    lines += ["", "## Conservative rejection cases", ""]
    for case in record["rejected_source_cases"]:
        lines += [f"- `{case['id']}` — `{case['source_fixture']}`",
                  f"  - Expected failure stage: `{case['expected_failure_stage']}`",
                  f"  - MIR-to-C stdout: `{case['oracle_stdout'].encode().hex()}` (hex)"]
    canonical = record["canonical_contract"]
    runtime = record["runtime_package"]
    lines += ["", "## Canonical and runtime boundary", "",
              f"- Format: `{canonical['format']}`",
              f"- Operations: `{', '.join(canonical['operations'])}`",
              f"- Types: `{', '.join(canonical['types'])}`",
              f"- Runtime imports: `{', '.join(canonical['runtime_imports'])}`",
              "- Arena allocation provenance: earlier same-block imported "
              "`os_ArenaAlloc` link symbol, same arena, literal size",
              "- Arena access range: non-negative byte offset plus the four-byte "
              "`i32` width must fit the recorded allocation",
              "- Arena index reassignment clears allocation provenance",
              f"- Runtime archive: `{runtime['path']}` from "
              f"`{', '.join(runtime['retained_components'])}`",
              "- New or changed runtime symbols: none",
              "- Generated C or fallback in the qualified route: none",
              "", "## Remaining boundary", "",
              "Patch 21.10 is bounded to the represented filesystem and one-int-field",
              "branded arena allocation cohorts. Computed write contents and computed",
              "stored values still reject before driver discovery. Resources and",
              "synchronization remain Patch 21.11.", ""]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review",
                                            "case-lines", "rejection-lines"))
    args = parser.parse_args()
    record = validate()
    if args.command == "project":
        REVIEW.write_text(render(record), encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and REVIEW.read_text(encoding="utf-8") ==
                render(record), "generated review is stale; run project")
    elif args.command == "case-lines":
        for case in record["source_cases"]:
            print("\t".join((case["id"], case["source_fixture"],
                              case["expected_stdout"].encode().hex(),
                              str(case["expected_exit"]),
                              case.get("expected_file", ""),
                              case.get("expected_file_contents", "").encode().hex())))
    elif args.command == "rejection-lines":
        for case in record["rejected_source_cases"]:
            print("\t".join((case["id"], case["source_fixture"],
                              case["expected_failure_stage"],
                              case["oracle_stdout"].encode().hex(),
                              str(case["oracle_exit"]),
                              case.get("oracle_file", ""),
                              case.get("oracle_file_contents", "").encode().hex())))
    else:
        print(f"✅ {GUARD_L1} authority passed")


if __name__ == "__main__":
    main()
