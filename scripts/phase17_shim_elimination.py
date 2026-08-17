#!/usr/bin/env python3
"""Level 1 contract and reduced review for Phase 17.9 generated C shim elimination."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import Counter
from pathlib import Path

GUARD = "guard-cranelift-phase17-shim-elimination-contract"
PARITY_GUARD = "guard-cranelift-phase17-shim-elimination-parity"
LEVEL = "level1"
CONTRACT = Path("tests/cranelift/phase17_shim_elimination_contract.tsv")
REVIEW = Path("tests/cranelift/phase17_shim_elimination_review.txt")
REGISTRY = Path("scripts/cranelift_feature_registry.json")
SOURCE = Path("compiler/mir_runtime_boundary_authority.gst")
REQUEST_SOURCE = Path("compiler/mir_shim_elimination_request.gst")
WORKER = Path("compiler/experiments/cranelift/src/shim_elimination.rs")
MAIN = Path("compiler/experiments/cranelift/src/main.rs")
CRATE = Path("compiler/mir_shim_elimination_request.gst")
CRATE_SOURCE = Path("compiler/mir_shim_elimination_request.gst")
SMOKE = Path("compiler/mir_shim_elimination_smoke_test_entry.gst")
PARITY = Path("scripts/phase17_shim_elimination_parity.sh")
WORKFLOW = Path(".github/workflows/phase17-shim-elimination.yml")
TASK = Path("TASK.md")

BANNED_CLASSES = ("runtime_call_wrapper", "abi_adaptation_wrapper",
                  "resource_or_cleanup_wrapper",
                  "allocation_or_string_helper_wrapper",
                  "io_filesystem_or_threading_wrapper",
                  "target_selection_wrapper_fragment")
REPLACEMENT_KINDS = ("compiler_owned_direct_import", "explicit_runtime_component",
                     "narrower_explicit_deferral")
EXPECTED = {
    "semantic_type": {"runtime_shim_ban"},
    "query": {"runtime_shim_ban_for"},
    "banned_class": set(BANNED_CLASSES),
    "replacement_kind": set(REPLACEMENT_KINDS),
    "obsolete_family": {
        "generated_is_valid_family", "generated_generational_clone_family",
        "generated_pthread_wrapper_family", "generated_entry_wrapper_family",
    },
    "rejection": {
        "unclassified_ban", "ban_without_replacement", "missing_evidence",
        "duplicate_ban",
    },
    "policy": {
        "no_program_specific_c_generation", "no_c_wrapper_source_transport",
        "cranelift_succeeds_without_c_compiler", "stable_witness",
    },
    "boundary": {"native_path_only"},
}
REASONS = (
    "runtime_shim_unclassified_ban", "runtime_shim_ban_without_replacement",
    "runtime_shim_missing_evidence", "runtime_shim_duplicate_ban",
)
SOURCE_TOKENS = (
    "type MirRuntimeShimBan", "banned_class:", "obsolete_family:",
    "replacement_kind:", "evidence_policy:",
    "func mir_runtime_shim_ban_id(", "func mir_runtime_shim_ban_for(",
    "func mir_runtime_banned_class_is_valid(",
    "func mir_runtime_replacement_kind_is_valid(",
    "mir_runtime_table_with_shim_ban(",
    "runtime_shim_banned_class", "runtime_shim_evidence_policy",
)
REQUEST_TOKENS = (
    "gust.compiler_shim_elimination.v1", "gust.shim_elimination_witness.v1",
    "func mir_serialize_shim_elimination_request(",
    "func mir_shim_elimination_mir_to_c_witness(",
    "native_path_emits_no_program_specific_c",
)
WORKER_TOKENS = (
    "pub fn parse_shim_elimination_request(",
    "pub fn render_shim_elimination_witness(",
    "pub fn lower_shim_elimination_witness_path(", "EVIDENCE_POLICY",
)
MAIN_TOKENS = ("mod shim_elimination;", '"phase17-shim-elimination-witness"',
               '"phase17-shim-elimination-object"',
               "fn emit_phase17_shim_elimination_object(")
CRATE_TOKENS = ("gust.compiler_shim_elimination.v1",)
CRATE_SOURCE_TOKENS = ("native_path_emits_no_program_specific_c",)


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
    authority = registry.get("phase17_shim_elimination_authority")
    if not isinstance(authority, dict):
        fail("canonical registry lacks shim elimination authority")
    expected = {
        "version": "phase17_shim_elimination_authority_v1",
        "status": "ready_for_patch17_10",
        "request_format": "gust.compiler_shim_elimination.v1",
        "witness_format": "gust.shim_elimination_witness.v1",
        "worker_owner": "compiler/experiments/cranelift/src/shim_elimination.rs",
        "linkage_policy": "native_path_emits_no_program_specific_c",
        "evidence_policy":
            "explicit_cranelift_succeeds_with_c_compiler_unavailable",
        "next_patch": "17.10",
    }
    for key, value in expected.items():
        if authority.get(key) != value:
            fail(f"shim elimination metadata drifted: {key}")
    if tuple(authority.get("banned_classes", ())) != BANNED_CLASSES:
        fail("shim banned class inventory drifted")
    if tuple(authority.get("replacement_kinds", ())) != REPLACEMENT_KINDS:
        fail("shim replacement kind inventory drifted")
    if tuple(authority.get("rejection_classes", ())) != REASONS:
        fail("shim rejection inventory drifted")

    # Every obsolete family must be one Patch 17.1 actually classified obsolete.
    obsolete = {
        row["helper_id"]: row
        for row in registry["phase17_runtime_authority"]
        ["helper_classifications"]
        if row["classification"] == "obsolete_helper"
    }
    families = authority.get("obsolete_families", [])
    if {r.get("helper_id") for r in families} != set(obsolete):
        fail("obsolete family coverage disagrees with Patch 17.1")
    for row in families:
        if row["family"] != obsolete[row["helper_id"]]["symbol_identity"]:
            fail(f"{row['helper_id']}: family disagrees with classified symbol")
        if row["replacement_kind"] not in REPLACEMENT_KINDS:
            fail(f"{row['helper_id']}: replacement kind not supported")
    return authority


def check_source(root: Path) -> None:
    source = text(root / SOURCE)
    for token in (*SOURCE_TOKENS, *REASONS, *BANNED_CLASSES, *REPLACEMENT_KINDS):
        if token not in source:
            fail(f"shim elimination source is missing: {token}")
    request = text(root / REQUEST_SOURCE)
    for token in REQUEST_TOKENS:
        if token not in request:
            fail(f"shim elimination request module is missing: {token}")
    worker = text(root / WORKER)
    for token in WORKER_TOKENS:
        if token not in worker:
            fail(f"Cranelift shim elimination module is missing: {token}")
    main = text(root / MAIN)
    for token in MAIN_TOKENS:
        if token not in main:
            fail(f"Cranelift worker is missing shim elimination wiring: {token}")

    crate_source = text(root / CRATE_SOURCE)
    for token in CRATE_SOURCE_TOKENS:
        if token not in crate_source:
            fail(f"shim elimination crate source is missing: {token}")


def check_wiring(root: Path) -> None:
    for path in (SMOKE, PARITY, WORKFLOW, CRATE, CRATE_SOURCE):
        if not (root / path).is_file():
            fail(f"missing required file: {path}")
    workflow = text(root / WORKFLOW)
    for token in (GUARD, PARITY_GUARD,
                  "python3 scripts/phase17_shim_elimination.py --check",
                  "Phase 17.9 shim elimination contract",
                  "Phase 17.9 shim elimination parity"):
        if token not in workflow:
            fail(f"workflow is missing: {token}")
    parity = text(root / PARITY)
    for token in ("phase17-shim-elimination-witness",
                  "phase17-shim-elimination-object", "cmp -s",
                  'env -i PATH="/nonexistent"'):
        if token not in parity:
            fail(f"parity script is missing: {token}")
    marker = ("- [x] Patch 17.6 — Rust Runtime Components and Native Object "
              "Integration — DONE")
    if marker not in text(root / TASK):
        fail("TASK.md does not mark Patch 17.6 DONE")


def render(contract_rows: list[dict[str, str]], authority: dict) -> str:
    counts = Counter(row["kind"] for row in contract_rows)
    lines = [
        "Phase 17.9 — Generated C Shim Elimination and Obsolete Helper Removal",
        f"guard: {GUARD}", f"parity_guard: {PARITY_GUARD}",
        f"test_level: {LEVEL}",
        f"linkage_policy: {authority['linkage_policy']}",
        f"evidence_policy: {authority['evidence_policy']}",
        f"transport_ban_policy: {authority['transport_ban_policy']}",
        "", "contract counts:",
    ]
    lines += [f"  {kind}: {counts[kind]}" for kind in sorted(counts)]
    lines += ["", "banned wrapper classes:"]
    lines += [f"  {value}" for value in authority["banned_classes"]]
    lines += ["", "obsolete generated-C families removed:"]
    lines += [
        f"  {row['family']}\t{row['helper_id']}\t{row['replacement_kind']}"
        for row in authority["obsolete_families"]
    ]
    lines += ["", "rejection classes:"]
    lines += [f"  {value}" for value in authority["rejection_classes"]]
    lines += [
        "", "exit gate:",
        "  every selected retained C implementation reaches programs through "
        "the package manifest",
        "  no retained C source is generated from the compiled program",
        "  no retained C is used as an implicit Cranelift shim",
        "  explicit Cranelift succeeds with the C compiler unavailable",
        "  allocation, string, and core memory audit remains in Patch 17.10",
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
    print(f"{GUARD}: ok ({len(authority['banned_classes'])} banned classes, "
          f"{len(authority['obsolete_families'])} obsolete families, {LEVEL})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
