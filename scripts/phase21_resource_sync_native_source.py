#!/usr/bin/env python3
"""Validate and project Patch 21.11 resource/synchronization authority."""

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE21_RESOURCE_SYNC_NATIVE_SOURCE.md"
GUARD_L1 = "guard-cranelift-phase21-resource-sync-native-source-contract"
GUARD_L2 = "guard-cranelift-phase21-resource-sync-native-source-parity"


def require(ok: bool, message: str) -> None:
    if not ok:
        raise SystemExit(f"{GUARD_L1}: {message}")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text())
    record = registry.get("phase21_resource_sync_native_source", {})
    require(record.get("contract_version") ==
            "phase21_resource_sync_native_source_v1", "contract drifted")
    require(record.get("status") == "patch21_11_complete" and
            record.get("next_patch") == "21.12", "status drifted")
    require(record.get("predecessor_authority") ==
            registry["phase21_filesystem_allocation_native_source"]
            ["contract_version"], "predecessor drifted")
    cases = record.get("source_cases", [])
    rejected = record.get("rejected_source_cases", [])
    linear_modules = record.get("linear_module_fixtures", [])
    require([case["id"] for case in cases] ==
            ["resource_primary", "resource_renamed", "threading_primary"],
            "source case population drifted")
    require([case["id"] for case in rejected] ==
            ["resource_computed_token"], "rejection population drifted")
    require(linear_modules ==
            ["compiler/phase21_resource_sync_renamed_module.gst"],
            "linear module fixture population drifted")
    require(all((ROOT / case["source_fixture"]).is_file()
                for case in cases + rejected), "source fixture is missing")
    require(all((ROOT / path).is_file() for path in linear_modules),
            "linear module fixture is missing")
    imported_modules = {
        f"compiler/{line.split(chr(34))[1]}"
        for case in cases
        for line in (ROOT / case["source_fixture"]).read_text().splitlines()
        if line.startswith("import \"")
    }
    require(set(linear_modules).issubset(imported_modules),
            "linear module fixture is not imported by a qualified source case")
    canonical = record.get("canonical_contract", {})
    for operation in ("LocalRawPointerSetParam", "LocalRawPointerSetCall",
                      "LocalI32SetRawPointerLoad", "RawPointerStoreLocalI32",
                      "LocalRawPointerOffset", "ArenaStoreLocalI32",
                      "FunctionAddress", "ArenaAllocationAddress"):
        require(operation in canonical.get("operations", []),
                f"canonical operation lacks {operation}")
    require(canonical.get("fallback") == "forbidden", "fallback drifted")
    require(record.get("runtime_package", {}).get("new_or_changed_runtime_symbols")
            == [], "runtime symbol boundary drifted")
    fixture = ROOT / record["worker_contract"]["canonical_fixtures"][0]
    require(fixture.is_file(), "canonical threading fixture is missing")
    worker = (ROOT / "compiler/experiments/cranelift/src/main.rs").read_text()
    lowerer = (ROOT / "compiler/mir_native_backend_resource_sync_source.gst").read_text()
    route = (ROOT / "compiler/mir_native_backend_source_route.gst").read_text()
    for marker in canonical["operations"] + canonical["runtime_imports"]:
        require(marker in worker or marker in lowerer or marker in route,
                f"implementation lacks {marker}")
    for case in cases + rejected:
        name = Path(case["source_fixture"]).name
        require(name not in worker and name not in lowerer,
                f"implementation recognizes fixture name {name}")
    levels = json.loads((ROOT / "scripts/cranelift_test_levels.json").read_text())["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "guard levels drifted")
    require(f"{GUARD_L1}:" in (ROOT / "justfile").read_text() and
            f"{GUARD_L2}:" in (ROOT / "justfile").read_text(),
            "just guards are missing")
    require(f"just {GUARD_L1}" in
            (ROOT / ".github/workflows/pr-fast.yml").read_text(),
            "PR Fast guard is missing")
    return record


def render(record: dict) -> str:
    lines = [
        "# Cranelift Phase 21 Resource and Synchronization Native Source Migration",
        "", "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase21_resource_sync_native_source.py project`. Do not edit by hand.",
        "", f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`", f"- Next patch: `{record['next_patch']}`",
        "", "## Qualified source cases", "",
    ]
    for case in record["source_cases"]:
        lines.append(f"- `{case['id']}` — `{case['source_fixture']}` — stdout hex `{case['expected_stdout'].encode().hex()}`")
    lines += ["", "## Linear module inventory", ""]
    for path in record["linear_module_fixtures"]:
        lines.append(f"- `{path}`")
    lines += ["", "## Canonical boundary", "",
              f"- Operations: `{', '.join(record['canonical_contract']['operations'])}`",
              f"- Runtime imports: `{', '.join(record['canonical_contract']['runtime_imports'])}`",
              "- Generated C and fallback: forbidden",
              "- New or changed runtime symbols: none", ""]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review",
                                            "case-lines", "rejection-lines"))
    args = parser.parse_args()
    record = validate()
    if args.command == "project":
        REVIEW.write_text(render(record))
    elif args.command == "check-review":
        require(REVIEW.is_file() and REVIEW.read_text() == render(record),
                "generated review is stale")
    elif args.command == "case-lines":
        for case in record["source_cases"]:
            print("\t".join((case["id"], case["source_fixture"],
                              case["expected_stdout"].encode().hex(),
                              str(case["expected_exit"]))))
    elif args.command == "rejection-lines":
        for case in record["rejected_source_cases"]:
            print("\t".join((case["id"], case["source_fixture"],
                              case["expected_failure_stage"],
                              case["oracle_stdout"].encode().hex(),
                              str(case["oracle_exit"]))))


if __name__ == "__main__":
    main()
