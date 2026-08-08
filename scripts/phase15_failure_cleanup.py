#!/usr/bin/env python3
from __future__ import annotations
import argparse, csv, json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase15-failure-cleanup-contract"
CONTRACT = Path("tests/cranelift/phase15_failure_cleanup_contract.tsv")
REVIEW = Path("tests/cranelift/phase15_failure_cleanup_review.txt")
REGISTRY = Path("scripts/cranelift_feature_registry.json")
FILES = [
    Path("compiler/mir_failure_cleanup.gst"),
    Path("compiler/mir_failure_cleanup_mir_to_c.gst"),
    Path("compiler/mir_failure_cleanup_parity_smoke_test_entry.gst"),
    Path("compiler/mir_failure_cleanup_state_smoke_test_entry.gst"),
    Path("compiler/future/p15_selected_failure_cleanup_source.gst"),
    Path("compiler/experiments/cranelift/src/failure_cleanup.rs"),
    Path("compiler/experiments/cranelift/src/main.rs"),
    Path("scripts/phase15_failure_cleanup_parity.sh"),
    Path("scripts/cranelift_feature_registry.schema.json"),
    Path("scripts/cranelift_registry.py"),
    Path(".github/workflows/phase15-failure-cleanup.yml"),
    Path("scripts/cranelift_test_levels.json"),
    Path("justfile"),
]
TOKENS = (
    "compiler_owned_failure_cleanup_policy",
    "trap_before_exec",
    "runtime_failure_return",
    "selected_panic",
    "native_op_failure_edge",
    "async_unwind,foreign_exception,cancellation",
    "before_driver_discovery",
    "cleanup_live_resources_then_terminate",
    "no_cleanup_resource_not_initialized",
    "gust.compiler_panic.v1",
    "gust.compiler_native_failure.v1",
    "reverse_declaration_inner_before_outer",
    "selected_failure_cleanup",
    "shared_canonical_mir_failure_edges_no_backend_cleanup_planner",
    "mir_cleanup_obligation_for_resource_scope",
    "failure_cleanup_obligation_mismatch",
    "exactly_once=1",
    "output_preserved=1",
    "generic_authority=1",
    "backend_cleanup_planner=0",
    "phase15-failure-cleanup-witness",
    "mir_failure_cleanup_mir_to_c_lower",
    "guard-cranelift-phase15-failure-cleanup-contract",
    "guard-cranelift-phase15-failure-cleanup-parity",
)

def fail(message: str) -> None:
    raise SystemExit(f"{GUARD}: {message}")

def read(path: Path) -> str:
    full = ROOT / path
    if not full.is_file() or full.is_symlink():
        fail(f"missing regular file {path}")
    return full.read_text()

def load_contract() -> list[dict[str, str]]:
    with (ROOT / CONTRACT).open(newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    if not rows or set(rows[0]) != {"kind", "requirement", "evidence", "level"}:
        fail("contract schema mismatch")
    if any(row["level"] != "1" or not row["evidence"] for row in rows):
        fail("all contract rows must carry Level 1 evidence")
    if len({(row["kind"], row["requirement"]) for row in rows}) != len(rows):
        fail("duplicate contract row")
    return rows

def check_registry() -> None:
    registry = json.loads(read(REGISTRY))
    authority = registry.get("phase15_failure_cleanup_authority")
    if not isinstance(authority, dict) or authority.get("version") != "phase15_failure_cleanup_authority_v1":
        fail("failure cleanup registry authority missing")
    if authority.get("backend_policy") != "shared_canonical_mir_failure_edges_no_backend_cleanup_planner":
        fail("failure cleanup backend policy drifted")
    selected = authority.get("selected_forms")
    expected = [
        ("trap_before_exec", "before_driver_discovery", "compiler_rejection", "compiler_resource_cleanup_verifier", "no_cleanup_resource_not_initialized", 0, 0, 65),
        ("runtime_failure_return", "runtime_failure_status_edge", "failure_return", "canonical_mir_failure_return.v1", "cleanup_live_resources_then_terminate", 1, 1, 82),
        ("selected_panic", "compiler_selected_panic_edge", "trap_after_cleanup", "gust.compiler_panic.v1", "cleanup_live_resources_then_terminate", 1, 1, 101),
        ("native_op_failure_edge", "canonical_mir_native_failure_edge", "propagate_native_status", "gust.compiler_native_failure.v1", "cleanup_live_resources_then_terminate", 1, 1, 74),
    ]
    if not isinstance(selected, list) or len(selected) != len(expected):
        fail("selected failure cleanup inventory must contain four forms")
    for row, values in zip(selected, expected):
        keys = ("id", "failure_stage", "terminal_kind", "stable_authority", "cleanup_policy", "cleanup_count", "destructor_count", "exit_status")
        if tuple(row.get(key) for key in keys) != values:
            fail(f"failure cleanup form drifted: {values[0]}")
        if row.get("order_policy") != "reverse_declaration_inner_before_outer" or row.get("exactly_once") is not True or row.get("output_preserved") is not True or row.get("status") != "migrated":
            fail(f"failure cleanup guarantees drifted: {values[0]}")
    deferred = authority.get("deferred_forms")
    if [row.get("id") for row in deferred or []] != ["async_unwind", "foreign_exception", "cancellation"]:
        fail("failure cleanup deferred boundary drifted")

def render(rows: list[dict[str, str]]) -> str:
    return "Patch 15.12 — Panic and Failure Cleanup Policy\n\n" + "".join(
        f"{row['kind']}\t{row['requirement']}\t{row['evidence']}\tLevel {row['level']}\n" for row in rows
    )

def check() -> list[dict[str, str]]:
    rows = load_contract()
    combined = "\n".join(read(path) for path in FILES)
    for token in TOKENS:
        if token not in combined:
            fail(f"missing token {token}")
    check_registry()
    expected = render(rows)
    if not (ROOT / REVIEW).is_file() or (ROOT / REVIEW).read_text() != expected:
        fail(f"{REVIEW} is stale; run with --write")
    return rows

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    if args.write:
        rows = load_contract()
        (ROOT / REVIEW).write_text(render(rows))
    rows = check()
    print(f"{GUARD}: ok ({len(rows)} rows, Level 1)")

if __name__ == "__main__":
    main()
