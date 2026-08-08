#!/usr/bin/env python3
from __future__ import annotations
import argparse, csv, json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase15-specialized-resource-contract"
CONTRACT = Path("tests/cranelift/phase15_specialized_resource_contract.tsv")
REVIEW = Path("tests/cranelift/phase15_specialized_resource_review.txt")
REGISTRY = Path("scripts/cranelift_feature_registry.json")
FILES = [
    Path("compiler/mir_specialized_resource.gst"),
    Path("compiler/mir_specialized_resource_mir_to_c.gst"),
    Path("compiler/mir_specialized_resource_parity_smoke_test_entry.gst"),
    Path("compiler/mir_specialized_resource_state_smoke_test_entry.gst"),
    Path("compiler/future/p15_directory_resources_source.gst"),
    Path("compiler/experiments/cranelift/src/specialized_resource.rs"),
    Path("compiler/experiments/cranelift/src/main.rs"),
    Path("scripts/phase15_specialized_resource_parity.sh"),
    Path("scripts/cranelift_feature_registry.schema.json"),
    Path("scripts/cranelift_registry.py"),
    Path(".github/workflows/phase15-specialized-resource.yml"),
    Path("scripts/cranelift_test_levels.json"),
    Path("justfile"),
]
TOKENS = (
    "compiler_owned_generic_resource_and_lifetime_authority",
    "no_specialized_backend_state_machine",
    "os_Dir_ctx",
    "os_DirEntry_ctx",
    "os.OpenDir",
    "os.CloseDir",
    "destructor:os.CloseDir",
    "close:os.CloseDir",
    "copy_policy",
    "prohibited",
    "move_policy",
    "immovable_while_open",
    "manual_or_scope_exit_exactly_once",
    "close_directory_handle",
    "os_OpenDir",
    "os_CloseDir",
    "all_declared_host_targets_from_phase14_target_authority",
    "layout:os_dir",
    "mir_resource_by_id",
    "mir_resource_latest_state",
    "mir_destructor_for",
    "mir_close_capability_for",
    "generic_authority=1",
    "backend_local_state_machine=0",
    "directory_entry_observed",
    "close_count=1",
    "destructor_count=0",
    "filesystem_effects_compared=1",
    "phase15-specialized-resource-witness",
    "mir_specialized_resource_mir_to_c_lower",
    "guard-cranelift-phase15-specialized-resource-contract",
    "guard-cranelift-phase15-specialized-resource-parity",
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
    authority = registry.get("phase15_specialized_resource_authority")
    if not isinstance(authority, dict) or authority.get("version") != "phase15_specialized_resource_authority_v1":
        fail("specialized resource registry authority missing")
    selected = authority.get("selected_kinds")
    if not isinstance(selected, list) or len(selected) != 1:
        fail("selected specialized resource inventory must contain exactly one kind")
    expected = {
        "id": "directory",
        "opening_entry_id": "p15_directory_resources",
        "resource_type_id": "os_Dir_ctx",
        "constructor_id": "os.OpenDir",
        "destructor_id": "destructor:os.CloseDir",
        "close_capability_id": "close:os.CloseDir",
        "copy_policy": "prohibited",
        "move_policy": "immovable_while_open",
        "close_policy": "manual_or_scope_exit_exactly_once",
        "cleanup_effect": "close_directory_handle",
        "constructor_runtime_symbol": "os_OpenDir",
        "close_runtime_symbol": "os_CloseDir",
        "target_applicability": "all_declared_host_targets_from_phase14_target_authority",
        "layout_id": "layout:os_dir",
        "source_fixture": "compiler/future/p15_directory_resources_source.gst",
        "canonical_mir_fixture": "compiler/mir_specialized_resource_parity_smoke_test_entry.gst",
        "status": "migrated",
    }
    if selected[0] != expected:
        fail("directory specialized resource registry row drifted")
    if authority.get("backend_policy") != "no_specialized_backend_state_machine":
        fail("specialized resource backend policy drifted")

def render(rows: list[dict[str, str]]) -> str:
    return "Patch 15.11 — Directory and Selected Specialized Resource Kinds\n\n" + "".join(
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
