#!/usr/bin/env python3
"""Validate the additive Phase 26 R2 authority before projecting closed rows."""

from __future__ import annotations

import copy
import hashlib
import json
import re
import subprocess
import sys
from functools import lru_cache
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE = "7e52a30352e5632857194062c12e3fa5234d3b4d"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
KEY = "scoped_byte_copy_r2_successor"
VERSION = "phase26_1r2_scoped_byte_copy_successor_v1"
GUARD = "guard-cranelift-phase26-scoped-byte-copy"
INVOCATION_PATH = "scripts/phase26_r2_scoped_copy.sh"
CR15_PATH = "scripts/phase24_cr15_stdlib_guard_transition.py"
UNCHANGED_PRODUCTION_SURFACES = (
    "README.md", "flake.nix", "scripts/run-gust-file.sh",
    "scripts/phase22_default_native_package.sh",
)
SOURCE_PATHS = (
    "compiler/experiments/cranelift/src/approved_package.rs",
    "compiler/experiments/cranelift/src/full_program.rs",
    "compiler/experiments/cranelift/src/main.rs",
    "compiler/experiments/cranelift/src/scoped_byte_copy.rs",
    "compiler/experiments/cranelift/src/collection_provenance.rs",
    "compiler/mir_native_backend_full_program_source.gst",
    "compiler/mir_native_backend_generic_source.gst",
    "compiler/typechecker.gst",
)


def require(ok: bool, reason: str) -> None:
    if not ok:
        raise SystemExit(f"{GUARD}: {reason}")


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def validate_ci_tool_order(workflow: str) -> None:
    """Run R2 against the build artifact before an older guard rebuilds it."""
    marker = "\n  phase26-ffi-position:\n"
    require(workflow.count(marker) == 1, "R2 CI Phase26 job is ambiguous")
    body = workflow.split(marker, 1)[1]
    next_job = re.search(r"(?m)^  [A-Za-z][\w-]*:\s*$", body)
    if next_job:
        body = body[:next_job.start()]
    names = re.findall(r"(?m)^      - name: (.+)$", body)
    required = (
        "Phase 26 approved signed package and linker boundary",
        "Phase 26 scoped signed byte-copy runtime",
        "Phase 26 FFI position policy",
    )
    require(all(names.count(name) == 1 for name in required),
            "R2 CI tool-binding step set drifted")
    start = names.index(required[0])
    require(tuple(names[start:start + 3]) == required,
            "R2 CI tool-binding order drifted")


@lru_cache(maxsize=1)
def ensure_base() -> None:
    spec = BASE + "^{commit}"
    present = subprocess.run(["git", "cat-file", "-e", spec], cwd=ROOT,
                             stderr=subprocess.DEVNULL).returncode == 0
    if not present:
        subprocess.run(["git", "fetch", "--no-tags", "--depth=1", "origin", BASE],
                       cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
        fetched = subprocess.check_output(["git", "rev-parse", "FETCH_HEAD"],
                                          cwd=ROOT, text=True).strip()
        require(fetched == BASE, "pinned merged-main fetch returned another commit")
    committed = subprocess.check_output(["git", "rev-parse", spec],
                                        cwd=ROOT, text=True).strip()
    require(committed == BASE, "pinned merged-main identity drifted")


@lru_cache(maxsize=None)
def base_bytes(path: str) -> bytes:
    ensure_base()
    return subprocess.check_output(["git", "show", f"{BASE}:{path}"], cwd=ROOT)


def prior_source_digest(registry: dict, path: str) -> str:
    """Project only a pinned R2 source back to the tested merged-main bytes."""
    current = digest(path)
    if path not in SOURCE_PATHS:
        return current
    pins = identity(registry)["spelling_inventory_successor"]["changed_source_hashes"]
    require(pins == [{"path": name, "digest": digest(name)} for name in SOURCE_PATHS],
            "R2 source pin drifted before predecessor projection")
    return hashlib.sha256(base_bytes(path)).hexdigest()


def preserved_predecessor_sites(registry: dict, old_sites: list[dict],
                                current_sites: list[dict]) -> list[dict]:
    """Verify old R1 spellings survived at their actual moved source lines."""
    identity(registry)
    ensure_base()
    indexed = {(row["path"], row["line"]): row for row in current_sites}
    for path in sorted({row["path"] for row in old_sites}):
        require(path in SOURCE_PATHS, f"R1 site moved outside R2 source pins: {path}")
        prior_source_digest(registry, path)
        prior_lines = base_bytes(path).decode().splitlines()
        current_lines = (ROOT / path).read_text().splitlines()
        diff = subprocess.check_output(
            ["git", "diff", "--unified=0", BASE, "--", path], cwd=ROOT,
            text=True)
        hunks = []
        for line in diff.splitlines():
            match = re.match(r"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", line)
            if match:
                hunks.append(tuple(int(value) if value is not None else 1
                                   for value in match.groups()))
        for old in (row for row in old_sites if row["path"] == path):
            line = old["line"]
            shift = 0
            for old_start, old_count, new_start, new_count in hunks:
                if old_count == 0 and line <= old_start:
                    break
                if old_count and line < old_start:
                    break
                require(not (old_count and old_start <= line < old_start + old_count),
                        f"R1 source spelling was edited: {path}:{line}")
                shift = (new_start + new_count - old_start - old_count -
                         (old_count == 0) + (new_count == 0))
            moved = line + shift
            require(0 < line <= len(prior_lines) and
                    0 < moved <= len(current_lines) and
                    prior_lines[line - 1] == current_lines[moved - 1],
                    f"R1 source spelling line changed: {path}:{line}")
            site = indexed.get((path, moved))
            require(site is not None and site["classification"] == old["classification"] and
                    site["spellings"] == old["spellings"],
                    f"R1 spelling category changed: {path}:{line}")
    return old_sites


def record(registry: dict) -> dict:
    return registry.get("phase26_activation_audit", {}).get(KEY, {})


def identity(registry: dict) -> dict:
    value = record(registry)
    require(value.get("contract_version") == VERSION and
            value.get("predecessor_main_sha") == BASE and
            value.get("status") == "test_profile_scoped_copy_under_qualification" and
            value.get("owner") == "cranelift" and
            value.get("owning_level2_guard") == GUARD and
            value.get("production_signing_roots") == [] and
            value.get("native_fallback") is False and
            value.get("public_tagged_result_contract") == "open" and
            value.get("generic_vector_safety_floor") == "open_separate_prerequisite",
            "R2 authority or release boundary drifted")
    return value


def normalize_invocations(registry: dict, rows: list[dict]) -> list[dict]:
    value = identity(registry)["phase22_invocation_successor"]
    current = [row for row in rows if row["path"] == INVOCATION_PATH]
    require(value.get("contract_version") == VERSION + "_phase22" and
            value.get("partial_extra_or_substituted_invocation") == "rejected" and
            len(current) == len(value.get("added_rows", [])) == 4 and
            current == value.get("added_rows"),
            "R2 compiler invocation changed, disappeared, or multiplied")
    return [row for row in rows if row["path"] != INVOCATION_PATH]


def normalize_production_audit(registry: dict, live: dict) -> dict:
    """Project only R2's changed Makefile surface off the closed audit."""
    value = identity(registry).get("production_audit_successor")
    require(isinstance(value, dict), "R2 production audit successor is absent")
    predecessor = registry["phase2512b_runtime_c_retirement"][
        "production_audit_transition"]["current_audit"]
    require(value == {
        "contract_version": VERSION + "_production_audit",
        "previous_supported_surface_manifest_digest":
            predecessor["supported_surface_manifest_digest"],
        "current_supported_surface_manifest_digest":
            "13383d08d5a7b0decbc92eaf0d4c8e62cc73555f45d088976932d2dbdfd66ffe",
        "previous_makefile_digest": hashlib.sha256(base_bytes("Makefile")).hexdigest(),
        "current_makefile_digest": digest("Makefile"),
        "previous_justfile_digest": hashlib.sha256(base_bytes("justfile")).hexdigest(),
        "current_justfile_digest": digest("justfile"),
        "current_projection_script_digest": digest(
            "scripts/phase23_production_release_audit.py"),
        "unchanged_supported_paths": list(UNCHANGED_PRODUCTION_SURFACES),
        "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    } and all(digest(path) == hashlib.sha256(base_bytes(path)).hexdigest()
              for path in UNCHANGED_PRODUCTION_SURFACES) and
            live["supported_surface_count"] == 6 and
            live["repository_invocation_count"] == 256 and
            live["supported_surface_manifest_digest"] ==
                value["current_supported_surface_manifest_digest"],
            "R2 production audit supported surface drifted")
    previous = dict(live)
    previous["supported_surface_manifest_digest"] = (
        value["previous_supported_surface_manifest_digest"])
    return previous


def normalize_text(registry: dict, rows: list[dict]) -> list[dict]:
    value = identity(registry)["phase23_text_surface_successor"]
    changed = value.get("changed_rows", [])
    added = value.get("added_rows", [])
    require(value.get("contract_version") == VERSION + "_phase23" and
            value.get("partial_extra_or_substituted_surface") == "rejected" and
            len({row["path"] for row in changed + added}) == len(changed + added),
            "R2 text successor shape drifted")
    live = {row["path"]: row for row in rows}
    for entry in changed:
        row = live.get(entry["path"])
        prior = base_bytes(entry["path"])
        from phase23_mir_to_c_deprecation_opening import SURFACE_PATTERNS
        prior_counts = {name: len(pattern.findall(prior.decode()))
                        for name, pattern in SURFACE_PATTERNS.items()}
        require(row is not None and row["digest"] == entry["current_digest"] and
                row["match_counts"] == entry["match_counts"] and
                entry["previous_digest"] == hashlib.sha256(prior).hexdigest() and
                entry["previous_match_counts"] == prior_counts,
                f"R2 text surface drifted: {entry['path']}")
    for entry in added:
        require(live.get(entry["path"]) == entry["current_row"],
                f"R2 added text surface drifted: {entry['path']}")
    prior = {row["path"]: row["previous_digest"] for row in changed}
    omitted = {row["path"] for row in added}
    return [dict(row, digest=prior[row["path"]]) if row["path"] in prior else row
            for row in rows if row["path"] not in omitted]


def normalize_spelling(registry: dict, summary: dict) -> dict:
    value = identity(registry)["spelling_inventory_successor"]
    previous = registry["phase26_activation_audit"][
        "reference_index_element_r4_spelling_inventory_successor"][
            "current_inventory_summary"]
    require(value.get("contract_version") == VERSION + "_spelling" and
            value.get("partial_extra_or_substituted_inventory") == "rejected" and
            value.get("previous_inventory_summary") == previous and
            value.get("current_inventory_summary") == summary and
            value.get("changed_source_hashes") == [
                {"path": path, "digest": digest(path)} for path in SOURCE_PATHS] and
            summary["source_file_count"] == previous["source_file_count"] + 2 and
            summary["site_count"] == previous["site_count"] + 114 and
            summary["semantic_site_count"] == previous["semantic_site_count"] + 97 and
            summary["classification_counts"]["diagnostic"] ==
                previous["classification_counts"]["diagnostic"] + 17 and
            all(summary["classification_counts"][name] == count
                for name, count in previous["classification_counts"].items()
                if name not in {"semantic_or_intrinsic_recognition", "diagnostic"}) and
            summary["unknown_site_count"] == 0,
            "R2 spelling population or source identity drifted")
    return previous


def normalize_filename(registry: dict, sites: list[dict]) -> list[dict]:
    value = identity(registry)["filename_site_successor"]
    previous = registry["phase26_activation_audit"][
        "reference_index_element_r4_filename_site_successor"]["current_sites"]
    require(value.get("contract_version") == VERSION + "_filename" and
            value.get("partial_extra_or_substituted_site") == "rejected" and
            value.get("previous_sites") == previous and
            value.get("current_sites") == sites and
            value.get("line_deltas") == [253, 253, 275] and
            len(sites) == len(previous) == 3 and
            all({k: v for k, v in now.items() if k != "line"} ==
                {k: v for k, v in before.items() if k != "line"}
                for before, now in zip(previous, sites)),
            "R2 filename selectors changed beyond exact line shifts")
    return previous


def normalize_relay(registry: dict, live_digest: str) -> str:
    value = identity(registry)["cr15_relay_digest_successor"]
    previous = registry["phase26_activation_audit"][
        "reference_index_element_r4_cr15_relay_digest_successor"]["current_digest"]
    require(value == {
        "path": CR15_PATH, "previous_digest": previous,
        "current_digest": live_digest,
        "partial_extra_or_substituted_relay": "rejected",
    }, "R2 relay digest drifted")
    return previous


def validate() -> None:
    registry = json.loads(REGISTRY.read_text())
    value = identity(registry)
    require(set(value) == {
        "contract_version", "predecessor_main_sha", "status", "owner", "owning_level2_guard",
        "production_signing_roots", "native_fallback", "public_tagged_result_contract",
        "generic_vector_safety_floor", "phase22_invocation_successor",
        "production_audit_successor", "phase23_text_surface_successor",
        "spelling_inventory_successor",
        "filename_site_successor", "cr15_relay_digest_successor",
    }, "R2 authority field set drifted")
    from phase24_semantic_spelling_inventory import source_sites, manifest_summary
    from phase24_filename_behavior_characterization import source_sites as filename_sites
    from phase22_opening import classify, logical_commands, COMPILER_TOKEN, selection, is_non_invocation
    normalize_spelling(registry, manifest_summary(source_sites()))
    normalize_filename(registry, filename_sites())
    path = ROOT / INVOCATION_PATH
    found = []
    for line, command, recipe in logical_commands(path):
        for match in COMPILER_TOKEN.finditer(command):
            if not is_non_invocation(command, match.start()):
                found.append(classify(path, line, command, recipe,
                                      match.group("token"), selection(command)))
    normalize_invocations(registry, found)
    from phase23_production_release_audit import scan as production_audit_scan
    normalize_production_audit(registry, production_audit_scan())
    normalize_relay(registry, digest(CR15_PATH))
    validate_ci_tool_order((ROOT / ".github/workflows/pr-fast.yml").read_text())
    require("python3 scripts/phase26_r2_scoped_copy_registration.py" in
            (ROOT / "justfile").read_text() and
            "bash scripts/phase26_r2_scoped_copy.sh" in
            (ROOT / "justfile").read_text() and
            "guard-cranelift-phase26-scoped-byte-copy" in
            (ROOT / ".github/workflows/pr-fast.yml").read_text() and
            "approved_r2_runtime_exports.txt" in
            (ROOT / "compiler/experiments/cranelift/src/approved_package.rs").read_text(),
            "R2 owning gate or signed runtime projection omitted")
    print(f"{GUARD}: exact additive registration ok")


def inversions() -> None:
    """Prove every new projection still refuses its own prior failure class."""
    registry = json.loads(REGISTRY.read_text())
    value = identity(registry)
    activation = registry["phase26_activation_audit"]
    invocation = value["phase22_invocation_successor"]["added_rows"]
    changed = value["phase23_text_surface_successor"]["changed_rows"]
    surfaces = [{"path": row["path"], "digest": row["current_digest"],
                 "match_counts": row["match_counts"]} for row in changed]
    surfaces.extend(copy.deepcopy(row["current_row"])
                    for row in value["phase23_text_surface_successor"]["added_rows"])
    spelling = value["spelling_inventory_successor"]["current_inventory_summary"]
    filename = value["filename_site_successor"]["current_sites"]
    relay = value["cr15_relay_digest_successor"]["current_digest"]
    from phase23_production_release_audit import scan as production_audit_scan
    production = production_audit_scan()
    normalize_invocations(registry, invocation)
    normalize_production_audit(registry, production)
    normalize_text(registry, surfaces)
    normalize_spelling(registry, spelling)
    normalize_filename(registry, filename)
    normalize_relay(registry, relay)

    def rejected(label: str, expected: str, call) -> None:
        try:
            call()
        except SystemExit as error:
            require(expected in str(error),
                    f"{label}: rejected by a different assertion: {error}")
            print(f"{label}: REJECTED (expected assertion)")
        else:
            raise SystemExit(f"{GUARD}: {label}: ACCEPTED")

    rejected("missing R2 compiler invocation", "R2 compiler invocation",
             lambda: normalize_invocations(registry, []))
    for index in range(len(invocation)):
        shortened = invocation[:index] + invocation[index + 1:]
        rejected(f"missing R2 compiler invocation {index}", "R2 compiler invocation",
                 lambda shortened=shortened: normalize_invocations(registry, shortened))
    rejected("extra R2 compiler invocation", "R2 compiler invocation",
             lambda: normalize_invocations(registry, invocation + invocation))
    for index in range(len(invocation)):
        different = copy.deepcopy(invocation)
        different[index]["selection"] = "implicit_default"
        rejected(f"changed backend selection {index}", "R2 compiler invocation",
                 lambda different=different: normalize_invocations(registry, different))
    resource_rows = [index for index, row in enumerate(invocation)
                     if '"$case_dir/program"' in row["command"]]
    require(len(resource_rows) == 1, "R2 resource compiler invocation is ambiguous")
    missing_driver = copy.deepcopy(invocation)
    resource_command = missing_driver[resource_rows[0]]["command"]
    driver_binding = 'GUST_NATIVE_BACKEND_DRIVER="$PWD/build/gust-native-backend" '
    require(resource_command.count(driver_binding) == 1,
            "R2 resource compiler driver binding did not move")
    missing_driver[resource_rows[0]]["command"] = resource_command.replace(driver_binding, "")
    rejected("missing explicit R2 resource driver binding", "R2 compiler invocation",
             lambda: normalize_invocations(registry, missing_driver))
    changed_digest = copy.deepcopy(surfaces)
    changed_digest[0]["digest"] = "0" * 64
    rejected("changed R2 text digest", "R2 text surface",
             lambda: normalize_text(registry, changed_digest))
    changed_added = copy.deepcopy(surfaces)
    changed_added[-1]["digest"] = "0" * 64
    rejected("changed R2 added text digest", "R2 added text surface",
             lambda: normalize_text(registry, changed_added))
    changed_previous = copy.deepcopy(registry)
    changed_previous["phase26_activation_audit"][KEY][
        "phase23_text_surface_successor"]["changed_rows"][0]["previous_digest"] = "0" * 64
    rejected("changed predecessor text projection", "R2 text surface",
             lambda: normalize_text(changed_previous, surfaces))
    for path in ("scripts/phase21_collection_string_native_source.sh",
                 "scripts/phase21_filesystem_allocation_native_source.sh",
                 "scripts/phase26_reference_receiver_registration.py"):
        row_index = next(index for index, row in enumerate(changed)
                         if row["path"] == path)
        changed_live = copy.deepcopy(surfaces)
        changed_live[row_index]["digest"] = "0" * 64
        rejected(f"changed {path} text digest", "R2 text surface",
                 lambda changed_live=changed_live: normalize_text(registry, changed_live))
        changed_prior = copy.deepcopy(registry)
        changed_prior["phase26_activation_audit"][KEY][
            "phase23_text_surface_successor"]["changed_rows"][row_index][
                "previous_digest"] = "0" * 64
        rejected(f"changed {path} predecessor digest", "R2 text surface",
                 lambda changed_prior=changed_prior: normalize_text(changed_prior, surfaces))
    changed_source = copy.deepcopy(registry)
    changed_source["phase26_activation_audit"][KEY][
        "spelling_inventory_successor"]["changed_source_hashes"][0]["digest"] = "0" * 64
    rejected("changed R2 source digest", "R2 spelling population",
             lambda: normalize_spelling(changed_source, spelling))
    changed_summary = copy.deepcopy(spelling)
    changed_summary["source_file_count"] -= 1
    rejected("missing R2 source", "R2 spelling population",
             lambda: normalize_spelling(registry, changed_summary))
    changed_filename = copy.deepcopy(filename)
    changed_filename[0]["line"] -= 1
    rejected("changed filename selector", "R2 filename selectors",
             lambda: normalize_filename(registry, changed_filename))
    rejected("changed relay digest", "R2 relay digest",
             lambda: normalize_relay(registry, "0" * 64))
    changed_production = copy.deepcopy(production)
    changed_production["supported_surface_manifest_digest"] = "0" * 64
    rejected("changed supported production surface", "R2 production audit",
             lambda: normalize_production_audit(registry, changed_production))
    old_digest_production = copy.deepcopy(production)
    old_digest_production["supported_surface_manifest_digest"] = value[
        "production_audit_successor"]["previous_supported_surface_manifest_digest"]
    rejected("old digest over R2 Makefile", "R2 production audit",
             lambda: normalize_production_audit(registry, old_digest_production))
    changed_anchor = copy.deepcopy(registry)
    changed_anchor["phase26_activation_audit"][KEY]["production_audit_successor"][
        "previous_supported_surface_manifest_digest"] = "0" * 64
    rejected("forged historical production anchor", "R2 production audit",
             lambda: normalize_production_audit(changed_anchor, production))
    changed_makefile = copy.deepcopy(registry)
    changed_makefile["phase26_activation_audit"][KEY]["production_audit_successor"][
        "current_makefile_digest"] = "0" * 64
    rejected("changed R2 Makefile pin", "R2 production audit",
             lambda: normalize_production_audit(changed_makefile, production))
    changed_projection = copy.deepcopy(registry)
    changed_projection["phase26_activation_audit"][KEY][
        "production_audit_successor"]["current_projection_script_digest"] = "0" * 64
    rejected("changed production projection script pin", "R2 production audit",
             lambda: normalize_production_audit(changed_projection, production))
    old_digest = digest
    try:
        def altered_digest(path: str) -> str:
            return "0" * 64 if path == "README.md" else old_digest(path)
        globals()["digest"] = altered_digest
        rejected("changed unrelated supported surface", "R2 production audit",
                 lambda: normalize_production_audit(registry, production))
    finally:
        globals()["digest"] = old_digest
    missing_step = (ROOT / "justfile").read_bytes().replace(
        b"guard-cranelift-phase26-scoped-byte-copy:", b"removed-r2-owning-step:")
    require(missing_step != (ROOT / "justfile").read_bytes(),
            "R2 owning-step inversion did not alter justfile bytes")
    try:
        def altered_digest(path: str) -> str:
            return (hashlib.sha256(missing_step).hexdigest() if path == "justfile"
                    else old_digest(path))
        globals()["digest"] = altered_digest
        rejected("missing R2 owning step", "R2 production audit",
                 lambda: normalize_production_audit(registry, production))
    finally:
        globals()["digest"] = old_digest
    missing_record = copy.deepcopy(registry)
    del missing_record["phase26_activation_audit"][KEY]
    rejected("old authority without R2 record", "R2 authority",
             lambda: identity(missing_record))
    workflow = (ROOT / ".github/workflows/pr-fast.yml").read_text()
    before = ("      - name: Phase 26 scoped signed byte-copy runtime\n"
              "        run: just guard-cranelift-phase26-scoped-byte-copy\n\n"
              "      - name: Phase 26 FFI position policy\n"
              "        run: just guard-cranelift-phase26-ffi-position-policy")
    after = ("      - name: Phase 26 FFI position policy\n"
             "        run: just guard-cranelift-phase26-ffi-position-policy\n\n"
             "      - name: Phase 26 scoped signed byte-copy runtime\n"
             "        run: just guard-cranelift-phase26-scoped-byte-copy")
    require(workflow.count(before) == 1, "R2 CI ordering inversion did not move steps")
    rejected("R2 guard after runtime archive rebuild", "R2 CI tool-binding order",
             lambda: validate_ci_tool_order(workflow.replace(before, after)))
    print(f"{GUARD}: thirty-three additive registration inversions ok")


if __name__ == "__main__":
    if len(sys.argv) == 1 or sys.argv[1:] == ["validate"]:
        validate()
    elif sys.argv[1:] == ["inversions"]:
        inversions()
    else:
        raise SystemExit("usage: phase26_r2_scoped_copy_registration.py [validate|inversions]")
