#!/usr/bin/env python3
"""Validate and project Patch 21.9 collection/string native-source authority."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE21_COLLECTION_STRING_NATIVE_SOURCE.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase21-collection-string-native-source.yml"
JUSTFILE = ROOT / "justfile"
LOWERER = ROOT / "compiler/mir_native_backend_collection_string_source.gst"
GENERIC = ROOT / "compiler/mir_native_backend_generic_source.gst"
REQUEST = ROOT / "compiler/mir_native_backend_request.gst"
ROUTE = ROOT / "compiler/mir_native_backend_source_route.gst"
WORKER = ROOT / "compiler/experiments/cranelift/src/main.rs"
MAKEFILE = ROOT / "Makefile"
GUARD_L1 = "guard-cranelift-phase21-collection-string-native-source-contract"
GUARD_L2 = "guard-cranelift-phase21-collection-string-native-source-parity"

CAPABILITIES = [
    "scheduled_defer_call_edges",
    "call_result_condition_cfg",
    "generic_receiver_and_aggregate_result_calls",
    "enum_match_payload_cfg",
    "string_view_byte_and_cast_operations",
]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    predecessor = registry.get("phase21_residue_migration_authority", {})
    record = registry.get("phase21_collection_string_native_source")
    require(isinstance(record, dict), "Patch 21.9 authority is missing")
    require(record.get("contract_version") ==
            "phase21_collection_string_native_source_v2",
            "contract version drifted")
    require(record.get("status") == "patch21_9_complete" and
            record.get("next_patch") == "21.10",
            "status or successor drifted")
    require(record.get("predecessor_authority") ==
            predecessor.get("contract_version") and
            predecessor.get("status") == "patch21_8_complete",
            "Patch 21.8 predecessor link drifted")
    require(record.get("source_route_policy") ==
            "typed_AST_operations_lower_to_canonical_MIR_without_source_path_fixture_name_or_generated_C_recognition",
            "source route policy drifted")
    require(record.get("scope", "").startswith(
            "bounded_compiler_owned_collection_and_string_source_cohort"),
            "bounded cohort is not explicit")

    capabilities = record.get("capabilities", [])
    require([item.get("id") for item in capabilities] == CAPABILITIES,
            "Patch 21.9 capability population drifted")
    require(all(item.get("state") and item.get("canonical_evidence")
                for item in capabilities),
            "a capability lacks state or canonical evidence")

    cases = record.get("source_cases", [])
    require([case.get("id") for case in cases] == [
        "collections_primary", "collections_renamed_variant",
        "strings_primary", "strings_renamed_variant",
        "strings_embedded_newline",
    ], "source differential population drifted")
    require(all((ROOT / case["source_fixture"]).is_file() and
                case.get("expected_exit") == 0 and
                case.get("expected_stderr") == "" and
                case.get("expected_stdout")
                for case in cases),
            "a source differential case is incomplete")
    rejected_cases = record.get("rejected_source_cases", [])
    require([case.get("id") for case in rejected_cases] == [
        "collections_extra_effect", "strings_extra_effect",
        "collections_unrepresented_log_expression",
        "strings_unrepresented_log_expression",
    ], "conservative rejection population drifted")
    require(all((ROOT / case["source_fixture"]).is_file() and
                case.get("expected_failure_stage") == "before_driver_discovery" and
                case.get("oracle_exit") == 0 and
                case.get("oracle_stderr") == "" and
                case.get("oracle_stdout")
                for case in rejected_cases),
            "a conservative rejection case is incomplete")

    canonical = record.get("canonical_contract", {})
    require(canonical.get("format") == "gust.compiler_mir_ingestion.v2" and
            canonical.get("operations") == [
                "LocalI32Set", "BranchLocalI32Positive", "CallVoid",
                "Jump", "ReturnI32",
            ] and canonical.get("types") == ["int", "str", "void"] and
            canonical.get("runtime_imports") == ["os_LogInt", "os_LogStr"] and
            canonical.get("fallback") == "forbidden",
            "canonical MIR contract drifted")
    runtime = record.get("runtime_package", {})
    require(runtime.get("retained_components") ==
            ["src/runtime/arena.c", "src/runtime/host_io.c"] and
            runtime.get("provided_symbols") == [
                "os_ArenaAlloc", "os_Arena_Free", "os_Arena_New",
                "os_Arena_Validate", "os_Args", "os_LogError", "os_LogInt",
                "os_LogStr", "os_MockPayload", "os_argc", "os_argv",
                "std_GenerationalSwap",
            ] and runtime.get("selected_imports") ==
            ["os_LogInt", "os_LogStr"] and
            runtime.get("new_or_changed_runtime_symbols") == [],
            "retained runtime package authority drifted")
    worker_contract = record.get("worker_contract", {})
    require(worker_contract.get("source_recognition") is False and
            worker_contract.get("string_literal_transport") ==
            "compiler_hex_encoded_bytes_to_declared_data_symbol_pointer_and_length" and
            worker_contract.get("generated_C") is False,
            "worker source-recognition or generated-C boundary drifted")

    require(record.get("remaining_residues") == [
        {"category": "filesystem", "destination_patch": "21.10", "decision": "deferred"},
        {"category": "allocation", "destination_patch": "21.10", "decision": "deferred"},
        {"category": "resources", "destination_patch": "21.11", "decision": "source_or_type_failure"},
        {"category": "threading_synchronization", "destination_patch": "21.11", "decision": "deferred"},
    ], "later residue ownership changed")
    boundary = record.get("boundary", {})
    require(boundary.get("changes_Gust_program_meaning") is False and
            boundary.get("changes_explicit_Cranelift_capability") is True and
            boundary.get("changes_canonical_MIR_transport") is True and
            boundary.get("changes_ABI_or_layout_authority") is False and
            boundary.get("adds_or_changes_runtime_symbols") is False and
            boundary.get("changes_bootstrap_seed") is False and
            boundary.get("edits_stdlib") is False,
            "Patch 21.9 boundary drifted")

    lowerer = LOWERER.read_text(encoding="utf-8")
    require("mir_native_collection_string_source_lower" in lowerer and
            "CallVoid" in lowerer and "StringLiteralUtf8Hex" in lowerer and
            "MirNativeCollectionStringIntValue" in lowerer and
            "MirNativeCollectionStringStringValue" in lowerer and
            "BranchLocalI32Positive" in lowerer,
            "compiler canonical lowering surface is incomplete")
    for fixture_name in (
        "phase20_component_collections_source.gst",
        "phase20_component_strings_source.gst",
        "phase21_collection_native_source_variant.gst",
        "phase21_string_native_source_variant.gst",
        "phase21_collection_native_unrepresented_log_expression.gst",
        "phase21_string_native_unrepresented_log_expression.gst",
        "phase21_string_native_embedded_newline.gst",
    ):
        require(fixture_name not in lowerer and fixture_name not in
                WORKER.read_text(encoding="utf-8"),
                f"source or worker recognizes fixture name {fixture_name}")
    require("collection_string.mir_native_collection_string_source_lower" in
            GENERIC.read_text(encoding="utf-8"),
            "generic source route does not invoke Patch 21.9 lowering")
    require("runtime_package_path" in REQUEST.read_text(encoding="utf-8") and
            "gust-runtime-package.a" in ROUTE.read_text(encoding="utf-8"),
            "compiler request does not carry the retained runtime package")
    worker = WORKER.read_text(encoding="utf-8")
    for marker in ("StringLiteralUtf8Hex", "compiler_mir_string_literal_bytes",
                   "CallVoid", "StringSlice", "runtime_package"):
        require(marker in worker, f"worker lacks {marker} transport")
    makefile = MAKEFILE.read_text(encoding="utf-8")
    for marker in ("build/gust-runtime-package.a", "src/runtime/arena.c",
                   "src/runtime/host_io.c", "ar rcs"):
        require(marker in makefile, f"runtime archive build lacks {marker}")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 21.9 — Collections and Strings Native Source Migration — DONE"
            in task and "**Exit Gate:** all five registered source cases" in task and
            "Post-merge correction (2026-08-25)" in task,
            "TASK.md does not close Patch 21.9")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 21.9 guard levels drifted")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in justfile and f"{GUARD_L2}:" in justfile,
            "Patch 21.9 just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own Patch 21.9 Level 1")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow,
            "dedicated Patch 21.9 workflow does not own both guards")
    return record


def render(record: dict) -> str:
    lines = [
        "# Cranelift Phase 21 Collection and String Native Source Migration", "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase21_collection_string_native_source.py project`. Do not edit by hand.",
        "", f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Scope: `{record['scope']}`",
        f"- Source route: `{record['source_route_policy']}`",
        "", "## Generic capability transition", "",
    ]
    for capability in record["capabilities"]:
        lines += [
            f"- `{capability['id']}`: `{capability['state']}`",
            f"  - Canonical evidence: `{capability['canonical_evidence']}`",
        ]
    lines += ["", "## Source differential cases", ""]
    for case in record["source_cases"]:
        lines += [
            f"- `{case['id']}` — `{case['source_fixture']}`",
            f"  - Exit: `{case['expected_exit']}`",
            f"  - Stdout: `{case['expected_stdout'].encode().hex()}` (hex)",
            "  - Stderr: empty",
        ]
    lines += ["", "## Conservative rejection cases", ""]
    for case in record["rejected_source_cases"]:
        lines += [
            f"- `{case['id']}` — `{case['source_fixture']}`",
            f"  - Expected failure stage: `{case['expected_failure_stage']}`",
            f"  - MIR-to-C stdout: `{case['oracle_stdout'].encode().hex()}` (hex)",
        ]
    canonical = record["canonical_contract"]
    runtime = record["runtime_package"]
    lines += [
        "", "## Canonical and runtime boundary", "",
        f"- Format: `{canonical['format']}`",
        f"- Operations: `{', '.join(canonical['operations'])}`",
        f"- Types: `{', '.join(canonical['types'])}`",
        f"- Runtime imports: `{', '.join(canonical['runtime_imports'])}`",
        f"- Runtime archive: `{runtime['path']}` from `{', '.join(runtime['retained_components'])}`",
        f"- Archive-provided symbols: `{', '.join(runtime['provided_symbols'])}`",
        "- New or changed runtime symbols: none",
        "- Generated C or fallback in the qualified route: none",
        "", "## Remaining boundary", "",
        "Patch 21.9 is deliberately bounded to the represented compiler-owned",
        "collection/string source cohort. Unrepresented shapes still reject",
        "before driver discovery. Filesystem and allocation remain Patch 21.10;",
        "resources and synchronization remain Patch 21.11.", "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=(
        "validate", "project", "check-review", "case-lines",
        "rejection-lines"))
    args = parser.parse_args()
    record = validate()
    if args.command == "project":
        REVIEW.write_text(render(record), encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and
                REVIEW.read_text(encoding="utf-8") == render(record),
                "generated Patch 21.9 review is stale; run project")
    elif args.command == "case-lines":
        for case in record["source_cases"]:
            print("\t".join((case["id"], case["source_fixture"],
                             case["expected_stdout"].encode().hex(),
                             str(case["expected_exit"]))))
        return
    elif args.command == "rejection-lines":
        for case in record["rejected_source_cases"]:
            print("\t".join((case["id"], case["source_fixture"],
                             case["expected_failure_stage"],
                             case["oracle_stdout"].encode().hex(),
                             str(case["oracle_exit"]))))
        return
    print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
