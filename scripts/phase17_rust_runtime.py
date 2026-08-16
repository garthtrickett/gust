#!/usr/bin/env python3
"""Level 1 contract and reduced review for Phase 17.6 Rust runtime components."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import Counter
from pathlib import Path

GUARD = "guard-cranelift-phase17-rust-runtime-contract"
PARITY_GUARD = "guard-cranelift-phase17-rust-runtime-parity"
LEVEL = "level1"
CONTRACT = Path("tests/cranelift/phase17_rust_runtime_contract.tsv")
REVIEW = Path("tests/cranelift/phase17_rust_runtime_review.txt")
REGISTRY = Path("scripts/cranelift_feature_registry.json")
SOURCE = Path("compiler/mir_runtime_boundary_authority.gst")
REQUEST_SOURCE = Path("compiler/mir_rust_runtime_request.gst")
WORKER = Path("compiler/experiments/cranelift/src/rust_runtime.rs")
MAIN = Path("compiler/experiments/cranelift/src/main.rs")
CRATE = Path("src/runtime/rust/Cargo.toml")
CRATE_SOURCE = Path("src/runtime/rust/src/lib.rs")
SMOKE = Path("compiler/mir_rust_runtime_component_smoke_test_entry.gst")
PARITY = Path("scripts/phase17_rust_runtime_parity.sh")
WORKFLOW = Path(".github/workflows/phase17-rust-runtime.yml")
TASK = Path("TASK.md")

PANIC_BOUNDARIES = ("abort_no_unwind_across_ffi",
                    "catch_unwind_converted_to_explicit_error")
ALLOCATION_BOUNDARIES = ("no_allocation_caller_owns_all_memory",
                         "allocates_in_caller_supplied_arena")
OBJECT_FORMS = ("static_library", "deterministic_object_set")
EXPECTED = {
    "semantic_type": {"runtime_rust_component"},
    "query": {"runtime_rust_component_for"},
    "field": {
        "component_id", "source_ownership", "exported_symbol_ids",
        "imported_symbol_ids", "runtime_abi_version", "target_applicability",
        "object_form", "panic_boundary", "allocation_boundary",
    },
    "panic_boundary": set(PANIC_BOUNDARIES),
    "allocation_boundary": set(ALLOCATION_BOUNDARIES),
    "object_form": set(OBJECT_FORMS),
    "rejection": {
        "undeclared_rust_export", "unwind_across_unsupported_boundary",
        "abi_or_target_mismatch", "duplicate_symbol_provider",
        "generated_c_glue_dependency",
    },
    "policy": {
        "independent_compilation", "stable_unmangled_abi_exports",
        "packaged_through_phase17_manifest", "stable_witness",
    },
    "boundary": {"reference_component_only"},
}
REASONS = (
    "runtime_rust_undeclared_export",
    "runtime_rust_unwind_boundary_violation",
    "runtime_rust_abi_or_target_mismatch",
    "runtime_rust_duplicate_symbol_provider",
    "runtime_rust_generated_c_glue_dependency",
)
SOURCE_TOKENS = (
    "type MirRuntimeRustComponent", "rust_component_id:", "source_ownership:",
    "exported_symbol_ids:", "imported_symbol_ids:", "object_form:",
    "panic_boundary:", "allocation_boundary:",
    "func mir_runtime_rust_component_id(",
    "func mir_runtime_rust_component_for(",
    "func mir_runtime_panic_boundary_is_valid(",
    "func mir_runtime_allocation_boundary_is_valid(",
    "func mir_runtime_rust_object_form_is_valid(",
    "mir_runtime_table_with_rust_component(",
    "runtime_rust_panic_boundary", "runtime_rust_object_form",
)
REQUEST_TOKENS = (
    "gust.compiler_rust_runtime.v1", "gust.rust_runtime_witness.v1",
    "func mir_serialize_rust_runtime_request(",
    "func mir_rust_runtime_mir_to_c_witness(",
    "independently_compiled_component_no_source_specific_c_generation",
)
WORKER_TOKENS = (
    "pub fn parse_rust_runtime_request(",
    "pub fn render_rust_runtime_witness(",
    "pub fn lower_rust_runtime_witness_path(",
)
MAIN_TOKENS = ("mod rust_runtime;", '"phase17-rust-runtime-witness"')
# The crate is the runtime contract: unmangled extern "C" exports and a panic
# boundary that cannot unwind back into compiled Gust.
CRATE_TOKENS = ('crate-type = ["staticlib"]', 'panic = "abort"')
CRATE_SOURCE_TOKENS = ("#[no_mangle]", 'extern "C"', "#[panic_handler]")


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD}: {message}")


def text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        fail(f"missing required file: {path}")


def rows(root: Path) -> list[dict[str, str]]:
    try:
        with (root / CONTRACT).open(encoding="utf-8", newline="") as handle:
            result = list(csv.DictReader(handle, delimiter="\t"))
    except FileNotFoundError:
        fail(f"missing required file: {CONTRACT}")
    required = {"kind", "id", "owner", "test_level", "disposition"}
    if not result or set(result[0]) != required:
        fail("contract schema drifted")
    actual: dict[str, set[str]] = {}
    seen: set[tuple[str, str]] = set()
    for row in result:
        key = (row["kind"], row["id"])
        if key in seen or row["test_level"] != LEVEL:
            fail(f"duplicate or non-Level-1 row: {key}")
        seen.add(key)
        actual.setdefault(row["kind"], set()).add(row["id"])
    if actual != EXPECTED:
        fail("contract inventory drifted")
    return result


def check_registry(root: Path) -> dict:
    registry = json.loads(text(root / REGISTRY))
    authority = registry.get("phase17_rust_runtime_authority")
    if not isinstance(authority, dict):
        fail("canonical registry lacks rust runtime authority")
    expected = {
        "version": "phase17_rust_runtime_authority_v1",
        "status": "ready_for_patch17_7",
        "request_format": "gust.compiler_rust_runtime.v1",
        "witness_format": "gust.rust_runtime_witness.v1",
        "crate_owner": "src/runtime/rust/Cargo.toml",
        "worker_owner": "compiler/experiments/cranelift/src/rust_runtime.rs",
        "next_patch": "17.7",
    }
    for key, value in expected.items():
        if authority.get(key) != value:
            fail(f"rust runtime metadata drifted: {key}")
    if tuple(authority.get("rejection_classes", ())) != REASONS:
        fail("rust runtime rejection inventory drifted")
    if tuple(authority.get("panic_boundaries", ())) != PANIC_BOUNDARIES:
        fail("rust runtime panic boundary inventory drifted")

    # The empty migration inventory must stay visible, not silently pass.
    classified = [
        row for row in registry["phase17_runtime_authority"]
        ["helper_classifications"]
        if row["classification"] == "rust_runtime_component"
    ]
    if authority.get("migrated_helper_count") != len(classified):
        fail("migrated helper count disagrees with Patch 17.1 classifications")
    components = authority.get("selected_components", [])
    if not components:
        fail("rust runtime must declare at least one reference component")
    spellings: set[str] = set()
    for row in components:
        if row.get("object_form") not in OBJECT_FORMS:
            fail(f"unsupported object form: {row.get('component_id')}")
        if row.get("panic_boundary") not in PANIC_BOUNDARIES:
            fail(f"unsupported panic boundary: {row.get('component_id')}")
        if row.get("allocation_boundary") not in ALLOCATION_BOUNDARIES:
            fail(f"unsupported allocation boundary: {row.get('component_id')}")
        for spelling in row.get("exported_spellings", []):
            if spelling in spellings:
                fail(f"duplicate exported spelling: {spelling}")
            spellings.add(spelling)
    return authority


def check_source(root: Path) -> None:
    source = text(root / SOURCE)
    for token in (*SOURCE_TOKENS, *REASONS, *PANIC_BOUNDARIES,
                  *ALLOCATION_BOUNDARIES, *OBJECT_FORMS):
        if token not in source:
            fail(f"rust runtime source is missing: {token}")
    request = text(root / REQUEST_SOURCE)
    for token in REQUEST_TOKENS:
        if token not in request:
            fail(f"rust runtime request module is missing: {token}")
    worker = text(root / WORKER)
    for token in WORKER_TOKENS:
        if token not in worker:
            fail(f"Cranelift rust runtime module is missing: {token}")
    main = text(root / MAIN)
    for token in MAIN_TOKENS:
        if token not in main:
            fail(f"Cranelift worker is missing rust runtime wiring: {token}")
    crate = text(root / CRATE)
    for token in CRATE_TOKENS:
        if token not in crate:
            fail(f"rust runtime crate is missing: {token}")
    if crate.count('panic = "abort"') < 2:
        fail("rust runtime crate must abort in both dev and release profiles")
    crate_source = text(root / CRATE_SOURCE)
    for token in CRATE_SOURCE_TOKENS:
        if token not in crate_source:
            fail(f"rust runtime crate source is missing: {token}")


def check_wiring(root: Path) -> None:
    for path in (SMOKE, PARITY, WORKFLOW, CRATE, CRATE_SOURCE):
        if not (root / path).is_file():
            fail(f"missing required file: {path}")
    workflow = text(root / WORKFLOW)
    for token in (GUARD, PARITY_GUARD,
                  "python3 scripts/phase17_rust_runtime.py --check",
                  "Phase 17.6 rust runtime contract",
                  "Phase 17.6 rust runtime parity"):
        if token not in workflow:
            fail(f"workflow is missing: {token}")
    parity = text(root / PARITY)
    for token in ("phase17-rust-runtime-witness", "cmp -s", "nm -g",
                  "--release", "cc -O2"):
        if token not in parity:
            fail(f"parity script is missing: {token}")
    marker = ("- [x] Patch 17.6 — Rust Runtime Components and Native Object "
              "Integration — DONE")
    if marker not in text(root / TASK):
        fail("TASK.md does not mark Patch 17.6 DONE")


def render(contract_rows: list[dict[str, str]], authority: dict) -> str:
    counts = Counter(row["kind"] for row in contract_rows)
    lines = [
        "Phase 17.6 — Rust Runtime Components and Native Object Integration",
        f"guard: {GUARD}", f"parity_guard: {PARITY_GUARD}",
        f"test_level: {LEVEL}",
        f"crate: {authority['crate_owner']}",
        f"request_format: {authority['request_format']}",
        f"witness_format: {authority['witness_format']}",
        f"linkage_policy: {authority['linkage_policy']}",
        f"mangling_policy: {authority['mangling_policy']}",
        f"helpers_migrated_from_patch17_1_inventory: {authority['migrated_helper_count']}",
        "", "contract counts:",
    ]
    lines += [f"  {kind}: {counts[kind]}" for kind in sorted(counts)]
    lines += ["", "declared Rust runtime components:"]
    for row in authority["selected_components"]:
        lines.append(
            f"  {row['component_id']}\t{row['object_form']}\t"
            f"{row['panic_boundary']}\t{row['allocation_boundary']}"
        )
        lines += [f"    export\t{s}" for s in row["exported_spellings"]]
    lines += ["", "rejection classes:"]
    lines += [f"  {value}" for value in authority["rejection_classes"]]
    lines += [
        "", "exit gate:",
        "  every selected Rust runtime helper is supplied by an explicit "
        "compatible runtime component",
        "  components compile independently and export stable unmangled ABI "
        "symbols",
        "  no source-specific C generation stands between program and component",
        "  retained C runtime objects remain in Patch 17.7",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--write", action="store_true")
    modes.add_argument("--check", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    contract_rows = rows(root)
    authority = check_registry(root)
    check_source(root)
    expected = render(contract_rows, authority)
    if args.write:
        (root / REVIEW).write_text(expected, encoding="utf-8")
    else:
        if text(root / REVIEW) != expected:
            fail("generated review is stale; run this script with --write")
        check_wiring(root)
    print(f"{GUARD}: ok ({len(authority['selected_components'])} components, "
          f"{authority['migrated_helper_count']} migrated helpers, {LEVEL})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
