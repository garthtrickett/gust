#!/usr/bin/env python3
"""Exact additive registration for OD20 checked collection operations."""
from __future__ import annotations
import copy
import hashlib
import json
import subprocess
import sys
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = "6bca6cdde2a3966758fc3fb40e04fc3115e270ad"
KEY = "collection_validity_r4_successor"
VERSION = "phase26_1r4_collection_validity_v1"
GUARD = "guard-cranelift-phase26-collection-validity"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
CI_STEP = ("      - name: Phase 26 checked collection validity and copy preservation\n"
           "        run: just guard-cranelift-phase26-collection-validity\n\n")
CHANGED = (
    "GUST_LANE_STATE.md", ".github/workflows/pr-fast.yml", "justfile",
    "scripts/cranelift_test_levels.json",
    "compiler/typechecker.gst", "compiler/mir_native_backend_full_program_source.gst",
    "compiler/experiments/cranelift/src/full_program.rs",
    "scripts/phase26_r2_scoped_copy_registration.py",
    "scripts/phase26_r3_zlib_adapter_registration.py",
    "scripts/phase24_semantic_spelling_inventory.py",
)
ADDED = (
    "compiler/experiments/cranelift/src/checked_collection.rs",
    "compiler/experiments/cranelift/src/checked_collection_tests.rs",
    "compiler/typechecker_phase26_collection_authority_test_entry.gst",
    "compiler/CRANELIFT_PHASE26_COLLECTION_SPELLING_INVENTORY.md",
    "compiler/CRANELIFT_PHASE26_COLLECTION_VALIDITY.md",
    "scripts/phase26_r4_collection_registration.py",
    "scripts/phase26_r4_collection_guard.py",
    "tests/cranelift/phase26_r4_default_collection_rejected.gst",
    "tests/cranelift/phase26_r4_metadata_reference_rejected.gst",
    "tests/cranelift/phase26_r4_metadata_write_rejected.gst",
)
ARTIFACT_MAXIMUM = 10616832

def require(ok: bool, message: str) -> None:
    if not ok: raise SystemExit(f"{GUARD}: {message}")

@lru_cache(maxsize=1)
def ensure_base() -> None:
    if subprocess.run(["git", "cat-file", "-e", BASE + "^{commit}"], cwd=ROOT,
                      stderr=subprocess.DEVNULL).returncode != 0:
        subprocess.run(["git", "fetch", "--no-tags", "--depth=1", "origin", BASE],
                       cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
        actual = subprocess.check_output(["git", "rev-parse", "FETCH_HEAD"], cwd=ROOT, text=True).strip()
        require(actual == BASE, "R4 predecessor fetch changed identity")
    actual = subprocess.check_output(["git", "rev-parse", BASE + "^{commit}"], cwd=ROOT, text=True).strip()
    require(actual == BASE, "R4 predecessor identity changed")

@lru_cache(maxsize=None)
def base_bytes(path: str) -> bytes:
    ensure_base()
    return subprocess.check_output(["git", "show", f"{BASE}:{path}"], cwd=ROOT)

def sha(raw: bytes) -> str: return hashlib.sha256(raw).hexdigest()
def digest(path: str) -> str: return sha((ROOT / path).read_bytes())
def base_registry() -> dict: return json.loads(base_bytes("scripts/cranelift_feature_registry.json"))
def record(registry: dict) -> dict: return registry.get("phase26_activation_audit", {}).get(KEY, {})

def identity(registry: dict) -> dict:
    value = record(registry)
    require(value.get("contract_version") == VERSION and value.get("predecessor_main_sha") == BASE and
            value.get("owner") == "cranelift" and value.get("owning_guard") == GUARD and
            value.get("release_status") == "capability_only_wrapper_and_release_open" and
            value.get("failure_scope") == "deterministic_process_native_trap_no_unwind" and
            value.get("allocator_abi") == "u32_offset_encoded_in_i32_exhaustion_aborts" and
            value.get("new_i32_allocation_byte_ceiling") is False and
            value.get("compiler_artifact_maximum_unchanged") == ARTIFACT_MAXIMUM,
            "R4 identity or selected semantic boundary drifted")
    require([row["path"] for row in value.get("changed_files", [])] == list(CHANGED) and
            [row["path"] for row in value.get("added_files", [])] == list(ADDED),
            "R4 pinned file population drifted")
    return value

def prior_digest(registry: dict, path: str, live: str) -> str:
    if not record(registry): return live
    rows = [row for row in identity(registry)["changed_files"] if row["path"] == path]
    if not rows: return live
    row = rows[0]
    require(row["current_digest"] == live and row["previous_digest"] == sha(base_bytes(path)),
            f"R4 changed file drifted: {path}")
    return row["previous_digest"]

def projection_digest(value) -> str:
    return sha(json.dumps(value, sort_keys=True, separators=(",", ":")).encode())

def project(registry: dict, kind: str, current):
    if not record(registry): return current
    value = identity(registry)["projections"][kind]
    require(projection_digest(current) == value["current_digest"], f"R4 {kind} live projection drifted")
    baseline = base_registry()["phase26_activation_audit"]
    if kind == "spelling": expected = baseline["zlib_adapter_r3_successor"]["spelling_inventory_successor"]["current_inventory_summary"]
    elif kind == "filename": expected = baseline["scoped_byte_copy_r2_successor"]["filename_site_successor"]["current_sites"]
    elif kind == "r3_record": expected = baseline["zlib_adapter_r3_successor"]
    elif kind == "workflow": expected = base_bytes(".github/workflows/pr-fast.yml").decode()
    elif kind == "production": expected = baseline["zlib_adapter_r3_successor"]["production_audit_successor"]["current_audit"]
    elif kind == "text":
        expected = []
        from phase23_mir_to_c_deprecation_opening import SURFACE_PATTERNS
        for row in current:
            path = row["path"]
            if path in ADDED: continue
            raw = base_bytes(path) if path in CHANGED else (ROOT / path).read_bytes()
            counts = {name: len(pattern.findall(raw.decode())) for name, pattern in SURFACE_PATTERNS.items()}
            if any(counts.values()): expected.append(dict(row, digest=sha(raw), match_counts=counts))
    else: raise SystemExit(f"unknown R4 projection: {kind}")
    require(value["previous_digest"] == projection_digest(expected), f"R4 {kind} predecessor drifted")
    before = expected
    if kind == "filename":
        without_line = lambda row: {key: value for key, value in row.items() if key != "line"}
        require(len(current) == len(before) == 3 and
                all(without_line(now) == without_line(old) for now, old in zip(current, before)),
                "R4 filename selectors changed beyond line shifts")
    return copy.deepcopy(before)

def project_registry(registry: dict) -> dict:
    historical = copy.deepcopy(registry)
    historical.get("phase26_activation_audit", {}).pop(KEY, None)
    return historical

def spelling_review_path(registry: dict, predecessor: Path) -> Path:
    if not record(registry): return predecessor
    identity(registry)
    relative = predecessor.relative_to(ROOT).as_posix()
    require(predecessor.read_bytes() == base_bytes(relative),
            "R4 rewrote the frozen predecessor spelling review")
    return ROOT / "compiler/CRANELIFT_PHASE26_COLLECTION_SPELLING_INVENTORY.md"

def spelling_review_text(registry: dict, full_review: str) -> str:
    if not record(registry): return full_review
    return ("# Phase 26 collection spelling inventory successor\n\n"
            "Generated from the complete live source scan; no historical review is rewritten.\n\n"
            f"- Predecessor main: `{BASE}`\n"
            f"- Complete current rendered inventory SHA-256: `{sha(full_review.encode())}`\n"
            f"- Frozen predecessor review SHA-256: `{sha(base_bytes('compiler/CRANELIFT_PHASE24_SEMANTIC_SPELLING_INVENTORY.md'))}`\n\n"
            "The owning registration separately binds the complete source-site manifest, classification\n"
            "counts, exact source changes and source-file population. The full current scan and its\n"
            "stale-line, omission, duplication and classification falsifiers remain enforced.\n"
            "Reproduce the full current report with `python3 scripts/phase26_r4_collection_registration.py spelling-full`.\n")

def check_spelling_review(registry: dict, full_review: str) -> None:
    path = spelling_review_path(registry, ROOT / "compiler/CRANELIFT_PHASE24_SEMANTIC_SPELLING_INVENTORY.md")
    require(path.is_file() and path.read_text() == spelling_review_text(registry, full_review),
            "R4 current spelling review is stale or missing")

def live_projections() -> dict:
    import phase26_r3_zlib_adapter_registration as r3
    from phase24_semantic_spelling_inventory import source_sites, manifest_summary
    from phase24_filename_behavior_characterization import source_sites as filename_sites
    from phase23_production_release_audit import scan as production_scan
    old = base_registry()["phase26_activation_audit"]
    current_text = r3.raw_text_surfaces()
    previous_text = []
    from phase23_mir_to_c_deprecation_opening import SURFACE_PATTERNS
    for row in current_text:
        path = row["path"]
        if path in ADDED: continue
        raw = base_bytes(path) if path in CHANGED else (ROOT / path).read_bytes()
        counts = {name: len(pattern.findall(raw.decode())) for name, pattern in SURFACE_PATTERNS.items()}
        if any(counts.values()): previous_text.append(dict(row, digest=sha(raw), match_counts=counts))
    production = production_scan()
    return {
            "text": {"previous": previous_text, "current": current_text},
            "spelling": {"previous": old["zlib_adapter_r3_successor"]["spelling_inventory_successor"]["current_inventory_summary"], "current": manifest_summary(source_sites())},
            "filename": {"previous": old["scoped_byte_copy_r2_successor"]["filename_site_successor"]["current_sites"], "current": filename_sites()},
            "r3_record": {"previous": old["zlib_adapter_r3_successor"], "current": r3.build_record()},
            "production": {"previous": old["zlib_adapter_r3_successor"]["production_audit_successor"]["current_audit"], "current": production},
            "workflow": {"previous": base_bytes(".github/workflows/pr-fast.yml").decode(), "current": (ROOT / ".github/workflows/pr-fast.yml").read_text()},
        }

def build_record() -> dict:
    return {"contract_version": VERSION, "predecessor_main_sha": BASE, "owner": "cranelift", "owning_guard": GUARD,
        "release_status": "capability_only_wrapper_and_release_open",
        "failure_scope": "deterministic_process_native_trap_no_unwind",
        "allocator_abi": "u32_offset_encoded_in_i32_exhaustion_aborts", "new_i32_allocation_byte_ceiling": False,
        "compiler_artifact_maximum_unchanged": ARTIFACT_MAXIMUM,
        "changed_files": [{"path": path, "previous_digest": sha(base_bytes(path)), "current_digest": digest(path)} for path in CHANGED],
        "added_files": [{"path": path, "digest": digest(path)} for path in ADDED],
        "projections": {kind: {"previous_digest": projection_digest(edge["previous"]),
            "current_digest": projection_digest(edge["current"])}
            for kind, edge in live_projections().items()}}

def write_record(value: dict) -> None:
    # Insert only the successor. Preserve historical registry bytes, including
    # deliberately retained formatting, instead of reserializing the ledger.
    marker = '  "phase26_activation_audit": {\n'
    baseline = base_bytes("scripts/cranelift_feature_registry.json").decode()
    require(baseline.count(marker) == 1, "R4 registry insertion anchor drifted")
    field = "\n".join("  " + line for line in json.dumps({KEY: value}, indent=2).splitlines()[1:-1])
    REGISTRY.write_text(baseline.replace(marker, marker + field + ",\n", 1))

def validate() -> None:
    registry = json.loads(REGISTRY.read_text()); value = identity(registry)
    require(value == build_record(), "R4 registration or live census drifted")
    require(project_registry(registry) == base_registry(), "R4 changed a frozen registry field")
    workflow = (ROOT / ".github/workflows/pr-fast.yml").read_text()
    require(workflow.count(CI_STEP) == 1 and workflow.replace(CI_STEP, "", 1) == base_bytes(".github/workflows/pr-fast.yml").decode(),
            "R4 owning CI step missing, duplicated or changed predecessor")
    just = (ROOT / "justfile").read_text()
    suffix = "\n# OD20 registered collection validity, process traps, and copy preservation.\n" + GUARD + ":\n    python3 scripts/phase26_r4_collection_registration.py validate\n    python3 scripts/phase26_r4_collection_registration.py inversions\n    python3 scripts/phase26_r4_collection_guard.py\n"
    require(just == base_bytes("justfile").decode() + suffix, "R4 owning recipe or predecessor recipes drifted")
    levels = json.loads((ROOT / "scripts/cranelift_test_levels.json").read_text())
    require(levels["guards"].get(GUARD) == 2, "R4 owning test level drifted")
    del levels["guards"][GUARD]
    require(levels == json.loads(base_bytes("scripts/cranelift_test_levels.json")), "R4 changed predecessor test levels")
    for kind, edge in live_projections().items(): project(registry, kind, edge["current"])
    import phase24_semantic_spelling_inventory as spelling
    rows = spelling.source_sites()
    check_spelling_review(registry, spelling.render(spelling.load_authority(), rows, spelling.manifest_summary(rows)))
    print(f"{GUARD}: exact additive registration ok")

def inversions() -> None:
    registry = json.loads(REGISTRY.read_text()); validate()
    def rejected(label, callback, expected):
        try: callback()
        except SystemExit as error:
            require(expected in str(error), f"{label}: REJECTED (different assertion): {error}")
            print(f"{label}: REJECTED (expected assertion)")
        else: raise SystemExit(f"{GUARD}: {label}: ACCEPTED")
    for path in CHANGED:
        rejected(f"substituted {path}", lambda path=path: prior_digest(registry, path, "0" * 64), f"R4 changed file drifted: {path}")
        rejected(f"old state {path}", lambda path=path: prior_digest(registry, path, sha(base_bytes(path))), f"R4 changed file drifted: {path}")
    for kind in identity(registry)["projections"]:
        rejected(f"missing {kind}", lambda kind=kind: project(registry, kind, None), f"R4 {kind} live projection drifted")
    changed_sites = copy.deepcopy(live_projections()["filename"]["current"])
    changed_sites[0]["line"] += 1
    rejected("unregistered filename coordinate", lambda: project(registry, "filename", changed_sites), "R4 filename live projection drifted")
    rejected("stale current spelling view", lambda: check_spelling_review(registry, "substituted rendered report"), "R4 current spelling review is stale or missing")
    altered = copy.deepcopy(registry); altered["phase26_activation_audit"][KEY]["compiler_artifact_maximum_unchanged"] += 1
    rejected("changed live artifact budget", lambda: identity(altered), "R4 identity or selected semantic boundary drifted")
    from phase21_cranelift_built_compiler_programs import compiler_artifact_within_live_budget
    predecessor = registry["phase21_cranelift_built_compiler_programs"]
    require(compiler_artifact_within_live_budget(registry, predecessor, ARTIFACT_MAXIMUM) and
            not compiler_artifact_within_live_budget(registry, predecessor, ARTIFACT_MAXIMUM + 1) and
            compiler_artifact_within_live_budget(project_registry(registry), predecessor, ARTIFACT_MAXIMUM),
            "R4 live artifact boundary is absent")
    print(f"{GUARD}: additive inversions ok")

if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) == 2 else "validate"
    if command == "generate":
        write_record(build_record())
    elif command == "spelling-full":
        import phase24_semantic_spelling_inventory as spelling
        rows = spelling.source_sites()
        print(spelling.render(spelling.load_authority(), rows, spelling.manifest_summary(rows)))
    elif command == "validate": validate()
    elif command == "inversions": inversions()
    else: raise SystemExit("expected generate|validate|inversions")
