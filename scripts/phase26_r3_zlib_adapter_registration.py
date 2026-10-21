#!/usr/bin/env python3
"""Exact additive R3 projection over the merged Phase 26 R2 authority."""

from __future__ import annotations

import copy
import hashlib
import json
import subprocess
import sys
from functools import lru_cache
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE = "c0aaf4f94e5f33daf8b65fa9235226b3bd685bb3"
KEY = "zlib_adapter_r3_successor"
VERSION = "phase26_1r3_zlib_adapter_successor_v1"
GUARD = "guard-cranelift-phase26-zlib-adapter"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
ARCHIVE_SHA256 = "bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16"
INVOCATION_PATH = "scripts/phase26_r3_zlib_adapter_guard.sh"
RELAY_PATH = "scripts/phase24_cr15_stdlib_guard_transition.py"
NEW_PATHS = (
    "compiler/experiments/cranelift/ffi-zlib/README.md",
    "compiler/experiments/cranelift/ffi-zlib/gust_zlib_adapter.c",
    "compiler/experiments/cranelift/ffi-zlib/gust_zlib_adapter.h",
    "compiler/experiments/cranelift/src/approved_zlib_tests.rs",
    "compiler/experiments/cranelift/src/testdata/phase26_r3_zlib_compress.canonical",
    "compiler/experiments/cranelift/src/testdata/phase26_r3_zlib_decompress.canonical",
    "compiler/experiments/cranelift/src/testdata/phase26_r3_zlib_empty_decompress.canonical",
    "scripts/phase26_r3_source_projection.py",
    "scripts/phase26_r3_zlib_adapter.sh",
    "scripts/phase26_r3_zlib_adapter_guard.sh",
    "scripts/phase26_r3_zlib_adapter_registration.py",
    "tests/cranelift/phase26_r3_zlib_compress.gst",
    "tests/cranelift/phase26_r3_zlib_decompress.gst",
    "tests/cranelift/phase26_r3_zlib_empty_decompress.gst",
    "tests/phase26_r3_zlib_adapter.c",
)
CHANGED_PATHS = (
    ".github/workflows/pr-fast.yml",
    "compiler/experiments/cranelift/src/approved_package.rs",
    "justfile",
    "scripts/cranelift_test_levels.json",
    "scripts/phase23_production_release_audit.py",
    "scripts/phase24_cr15_stdlib_guard_transition.py",
    "scripts/phase26_call_cast_alias_finite_cast_plain_terminal_cast_chain_return_registration.py",
    "scripts/phase26_r2_scoped_copy_registration.py",
)
CI_STEP = ("      - name: Phase 26 pinned zlib adapter and signed test-profile link\n"
           "        run: just guard-cranelift-phase26-zlib-adapter\n\n")


def require(ok: bool, reason: str) -> None:
    if not ok:
        raise SystemExit(f"{GUARD}: {reason}")


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


@lru_cache(maxsize=1)
def ensure_base() -> None:
    if subprocess.run(["git", "cat-file", "-e", BASE + "^{commit}"], cwd=ROOT,
                      stderr=subprocess.DEVNULL).returncode != 0:
        subprocess.run(["git", "fetch", "--no-tags", "--depth=1", "origin", BASE],
                       cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
        actual = subprocess.check_output(["git", "rev-parse", "FETCH_HEAD"],
                                         cwd=ROOT, text=True).strip()
        require(actual == BASE, "pinned merged-main fetch changed identity")
    actual = subprocess.check_output(["git", "rev-parse", BASE + "^{commit}"],
                                     cwd=ROOT, text=True).strip()
    require(actual == BASE, "pinned merged-main identity changed")


@lru_cache(maxsize=None)
def base_bytes(path: str) -> bytes:
    ensure_base()
    return subprocess.check_output(["git", "show", f"{BASE}:{path}"], cwd=ROOT)


def record(registry: dict) -> dict:
    return registry.get("phase26_activation_audit", {}).get(KEY, {})


def identity(registry: dict) -> dict:
    value = record(registry)
    require(value.get("contract_version") == VERSION and
            value.get("predecessor_main_sha") == BASE and
            value.get("owner") == "cranelift" and
            value.get("status") == "test_profile_real_zlib_under_qualification" and
            value.get("owning_level2_guard") == GUARD and
            value.get("target") == "x86_64-unknown-linux-gnu" and
            value.get("zlib_version") == "1.3.2" and
            value.get("zlib_source_archive_digest") == ARCHIVE_SHA256 and
            value.get("production_signing_roots") == [] and
            value.get("public_safe_wrapper_status") == "open" and
            value.get("partial_extra_or_substituted_authority") == "rejected",
            "R3 release boundary or identity drifted")
    return value


def prior_digest(registry: dict, path: str, live_digest: str) -> str:
    if not record(registry):
        return live_digest
    pins = identity(registry)["changed_file_hashes"]
    matches = [row for row in pins if row["path"] == path]
    require(len(matches) <= 1, f"R3 duplicate changed path: {path}")
    if not matches:
        return live_digest
    row = matches[0]
    require(row["current_digest"] == live_digest and
            row["previous_digest"] == hashlib.sha256(base_bytes(path)).hexdigest(),
            f"R3 changed file digest drifted: {path}")
    return row["previous_digest"]


def prior_source_digest(registry: dict, path: str) -> str:
    return prior_digest(registry, path, digest(path))


def project_ci_workflow(registry: dict, workflow: str) -> str:
    if not record(registry):
        return workflow
    require(workflow.count(CI_STEP) == 1 and
            digest(".github/workflows/pr-fast.yml") ==
                hashlib.sha256(workflow.encode()).hexdigest(),
            "R3 CI owning step absent, duplicated, or substituted")
    projected = workflow.replace(CI_STEP, "", 1)
    require(projected.encode() == base_bytes(".github/workflows/pr-fast.yml"),
            "R3 CI edit changed predecessor workflow")
    return projected


def raw_text_surfaces() -> list[dict]:
    import phase23_mir_to_c_deprecation_opening as phase23
    rows = []
    for path in phase23.tracked_paths():
        if path in phase23.SELF_EXCLUSIONS:
            continue
        try:
            raw = (ROOT / path).read_bytes()
            text = raw.decode("utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        matches = {name: len(pattern.findall(text))
                   for name, pattern in phase23.SURFACE_PATTERNS.items()}
        if not any(matches.values()):
            continue
        classification, action, removal, falsifier = phase23.classify_surface(path)
        rows.append({
            "path": path, "digest": hashlib.sha256(raw).hexdigest(),
            "match_counts": matches, "classification": classification,
            "owner": phase23.owner_for_path(path),
            "current_route": "tracked_MIR_to_C_or_generated_C_surface",
            "deprecation_action": action, "removal_phase": removal,
            "falsifier": falsifier,
        })
    return rows


def old_text_row(path: str, current: dict) -> dict:
    from phase23_mir_to_c_deprecation_opening import SURFACE_PATTERNS
    old = base_bytes(path).decode("utf-8")
    counts = {name: len(pattern.findall(old))
              for name, pattern in SURFACE_PATTERNS.items()}
    require(any(counts.values()), f"R3 changed text path had no old row: {path}")
    return dict(current, digest=hashlib.sha256(old.encode()).hexdigest(),
                match_counts=counts)


def normalize_text(registry: dict, rows: list[dict]) -> list[dict]:
    if not record(registry):
        return rows
    value = identity(registry)["phase23_text_surface_successor"]
    by_path = {row["path"]: row for row in rows}
    require(len(by_path) == len(rows), "R3 text surface has duplicate paths")
    changed = value["changed_rows"]
    added = value["added_rows"]
    for entry in changed:
        path = entry["path"]
        require(by_path.get(path) == entry["current_row"] and
                entry["previous_row"] == old_text_row(path, entry["current_row"]),
                f"R3 text surface drifted: {path}")
    for entry in added:
        require(by_path.get(entry["path"]) == entry["current_row"] and
                entry["path"] in NEW_PATHS,
                f"R3 added text surface drifted: {entry['path']}")
    previous = {entry["path"]: entry["previous_row"] for entry in changed}
    omitted = {entry["path"] for entry in added}
    return [previous.get(row["path"], row) for row in rows
            if row["path"] not in omitted]


def invocation_rows() -> list[dict]:
    from phase22_opening import (COMPILER_TOKEN, classify, is_non_invocation,
                                 logical_commands, selection)
    path = ROOT / INVOCATION_PATH
    rows = []
    for line, command, recipe in logical_commands(path):
        for match in COMPILER_TOKEN.finditer(command):
            if not is_non_invocation(command, match.start()):
                rows.append(classify(path, line, command, recipe,
                                     match.group("token"), selection(command)))
    return rows


def normalize_invocations(registry: dict, rows: list[dict]) -> list[dict]:
    if not record(registry):
        return rows
    expected = identity(registry)["phase22_invocation_successor"]["added_rows"]
    current = [row for row in rows if row["path"] == INVOCATION_PATH]
    without_line = lambda row: {key: value for key, value in row.items() if key != "line"}
    require(len(expected) == len(current) == 1 and
            without_line(current[0]) == without_line(expected[0]) and
            current[0]["selection"] == "explicit_cranelift" and
            current[0]["command"].count("GUST_NATIVE_BACKEND_DRIVER=") == 1,
            "R3 explicit compiler invocation drifted")
    return [row for row in rows if row["path"] != INVOCATION_PATH]


def normalize_production_audit(registry: dict, live: dict) -> dict:
    if not record(registry):
        return live
    value = identity(registry)["production_audit_successor"]
    require(live == value["current_audit"] and
            value["current_audit"]["repository_invocation_count"] ==
                value["previous_audit"]["repository_invocation_count"] + 1 and
            {key: item for key, item in value["current_audit"].items()
             if key != "repository_invocation_count"} ==
                {key: item for key, item in value["previous_audit"].items()
                 if key != "repository_invocation_count"},
            "R3 production audit changed beyond exact compiler invocation")
    return value["previous_audit"]


def normalize_spelling(registry: dict, live: dict) -> dict:
    if not record(registry):
        return live
    value = identity(registry)["spelling_inventory_successor"]
    previous = registry["phase26_activation_audit"]["scoped_byte_copy_r2_successor"][
        "spelling_inventory_successor"]["current_inventory_summary"]
    require(value["previous_inventory_summary"] == previous and
            value["current_inventory_summary"] == live and
            live["source_file_count"] == previous["source_file_count"] + 1 and
            live["site_count"] == previous["site_count"] and
            live["semantic_site_count"] == previous["semantic_site_count"] and
            live["classification_counts"] == previous["classification_counts"] and
            live["unknown_site_count"] == 0,
            "R3 spelling population or source identity drifted")
    return previous


def build_record() -> dict:
    from phase24_semantic_spelling_inventory import manifest_summary, source_sites
    from phase23_production_release_audit import scan as production_scan
    base_registry = json.loads(base_bytes("scripts/cranelift_feature_registry.json"))
    old_summary = base_registry["phase26_activation_audit"][
        "scoped_byte_copy_r2_successor"]["spelling_inventory_successor"][
            "current_inventory_summary"]
    current_text = raw_text_surfaces()
    by_path = {row["path"]: row for row in current_text}
    changed_text = []
    added_text = []
    for path, row in by_path.items():
        if path in NEW_PATHS:
            added_text.append({"path": path, "current_row": row})
        elif path in CHANGED_PATHS and row["digest"] != hashlib.sha256(base_bytes(path)).hexdigest():
            changed_text.append({"path": path, "previous_row": old_text_row(path, row),
                                 "current_row": row})
    require(len(invocation_rows()) == 1, "R3 new compiler invocation census")
    production = production_scan()
    require(production["repository_invocation_count"] == 257,
            "R3 production invocation count changed")
    previous_production = dict(production, repository_invocation_count=256)
    return {
        "contract_version": VERSION,
        "predecessor_main_sha": BASE,
        "owner": "cranelift",
        "status": "test_profile_real_zlib_under_qualification",
        "owning_level2_guard": GUARD,
        "target": "x86_64-unknown-linux-gnu",
        "zlib_version": "1.3.2",
        "zlib_source_archive_digest": ARCHIVE_SHA256,
        "production_signing_roots": [],
        "public_safe_wrapper_status": "open",
        "partial_extra_or_substituted_authority": "rejected",
        "new_file_hashes": [{"path": path, "digest": digest(path)} for path in NEW_PATHS],
        "changed_file_hashes": [
            {"path": path, "previous_digest": hashlib.sha256(base_bytes(path)).hexdigest(),
             "current_digest": digest(path)} for path in CHANGED_PATHS],
        "phase22_invocation_successor": {"added_rows": invocation_rows(),
                                         "partial_extra_or_substituted_invocation": "rejected"},
        "phase23_text_surface_successor": {
            "changed_rows": changed_text, "added_rows": added_text,
            "partial_extra_or_substituted_surface": "rejected"},
        "production_audit_successor": {
            "previous_audit": previous_production, "current_audit": production,
            "partial_extra_or_substituted_audit": "rejected"},
        "spelling_inventory_successor": {
            "previous_inventory_summary": old_summary,
            "current_inventory_summary": manifest_summary(source_sites()),
            "partial_extra_or_substituted_inventory": "rejected"},
    }


def validate() -> None:
    registry = json.loads(REGISTRY.read_text())
    value = identity(registry)
    require(value == build_record(), "R3 additive registration or source census drifted")
    historical = copy.deepcopy(registry)
    del historical["phase26_activation_audit"][KEY]
    require(historical == json.loads(base_bytes("scripts/cranelift_feature_registry.json")),
            "R3 changed a predecessor registry field")
    from phase24_semantic_spelling_inventory import manifest_summary, source_sites
    from phase23_production_release_audit import scan as production_scan
    normalize_spelling(registry, manifest_summary(source_sites()))
    normalize_production_audit(registry, production_scan())
    normalize_invocations(registry, invocation_rows())
    normalize_text(registry, raw_text_surfaces())
    project_ci_workflow(registry, (ROOT / ".github/workflows/pr-fast.yml").read_text())
    require("python3 scripts/phase26_r3_zlib_adapter_registration.py" in
            (ROOT / "justfile").read_text() and
            "bash scripts/phase26_r3_zlib_adapter_guard.sh" in
            (ROOT / "justfile").read_text() and
            "guard-cranelift-phase26-zlib-adapter" in
            (ROOT / ".github/workflows/pr-fast.yml").read_text() and
            "PRODUCTION_REGISTRY: &[RegisteredPackage] = &[]" in
            (ROOT / "compiler/experiments/cranelift/src/approved_package.rs").read_text(),
            "R3 owning gate or production default-deny omitted")
    print(f"{GUARD}: exact additive registration ok")


def inversions() -> None:
    registry = json.loads(REGISTRY.read_text())
    value = identity(registry)
    baseline = build_record()
    require(value == baseline, "R3 inversion baseline is not current")
    text_rows = raw_text_surfaces()
    invocation = invocation_rows()
    from phase23_production_release_audit import scan as production_scan
    from phase24_semantic_spelling_inventory import manifest_summary, source_sites
    production = production_scan()
    spelling = manifest_summary(source_sites())
    normalize_text(registry, text_rows)
    normalize_invocations(registry, invocation)
    normalize_production_audit(registry, production)
    normalize_spelling(registry, spelling)

    def rejected(label: str, owning: str, callback) -> None:
        try:
            callback()
        except SystemExit as error:
            require(owning in str(error), f"{label}: REJECTED (different assertion): {error}")
            print(f"{label}: REJECTED (expected assertion)")
        else:
            raise SystemExit(f"{GUARD}: {label}: ACCEPTED")

    missing = copy.deepcopy(registry)
    del missing["phase26_activation_audit"][KEY]
    rejected("missing R3 record", "R3 release boundary", lambda: identity(missing))
    for path in NEW_PATHS:
        altered = copy.deepcopy(registry)
        row = next(row for row in altered["phase26_activation_audit"][KEY]["new_file_hashes"]
                   if row["path"] == path)
        row["digest"] = "0" * 64
        rejected(f"changed added file {path}", "R3 additive registration",
                 lambda altered=altered: require(record(altered) == baseline,
                                                  "R3 additive registration changed"))
    extra = invocation + invocation
    rejected("duplicate R3 compiler call", "R3 explicit compiler invocation",
             lambda: normalize_invocations(registry, extra))
    wrong_selection = copy.deepcopy(invocation)
    wrong_selection[0]["selection"] = "implicit_default"
    rejected("changed R3 backend", "R3 explicit compiler invocation",
             lambda: normalize_invocations(registry, wrong_selection))
    changed_text = copy.deepcopy(text_rows)
    target = value["phase23_text_surface_successor"]["changed_rows"][0]["path"]
    next(row for row in changed_text if row["path"] == target)["digest"] = "0" * 64
    rejected("changed R3 text digest", "R3 text surface",
             lambda: normalize_text(registry, changed_text))
    changed_production = dict(production, repository_invocation_count=256)
    rejected("missing R3 production invocation", "R3 production audit",
             lambda: normalize_production_audit(registry, changed_production))
    changed_spelling = dict(spelling, source_file_count=spelling["source_file_count"] - 1)
    rejected("missing R3 source", "R3 spelling population",
             lambda: normalize_spelling(registry, changed_spelling))
    workflow = (ROOT / ".github/workflows/pr-fast.yml").read_text()
    rejected("missing R3 CI step", "R3 CI owning step",
             lambda: project_ci_workflow(registry, workflow.replace(CI_STEP, "")))
    print(f"{GUARD}: additive inversion set ok")


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) == 2 else "validate"
    if command == "generate":
        print(json.dumps(build_record(), indent=2, sort_keys=True))
    elif command == "validate":
        validate()
    elif command == "inversions":
        inversions()
    else:
        raise SystemExit("usage: phase26_r3_zlib_adapter_registration.py [generate|validate|inversions]")
