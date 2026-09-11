#!/usr/bin/env python3
"""Gated inversion suite for the Patch 24.3b coordinate retirement.

Patch 24.3b retired the remaining `line` coordinates that Patch 24.3c left
behind: the invocation-manifest digest input, the live-C case digests, the
observation-driver match, the opening-review inventory table, and the relay
probe lookup. A coordinate is a fact with a shelf life; every retired site
now anchors on what the row means instead.

A relaxation that cannot fail is a deleted test. This suite proves both
directions: acceptance cases show a whole-tree line shift still validates,
and rejection cases show a meaning change still fails. Three outcomes per
case, never two: ACCEPTED, REJECTED at the pinned message, and REJECTED
elsewhere (reported as a failure with the actual message, since a substring
miss must not turn a rejection into a reported hole).

    python3 scripts/phase24_3b_coordinate_retirement_inversions.py
"""

from __future__ import annotations

import copy
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
JUSTFILE = ROOT / "justfile"
OPENING_REVIEW = ROOT / "compiler/CRANELIFT_PHASE22_OPENING.md"
DRIVER_HOST = ROOT / "scripts/phase24_filename_behavior_characterization.py"

# Tracked paths this suite perturbs, saved and restored as bytes.
PERTURBED = (JUSTFILE, REGISTRY, OPENING_REVIEW, DRIVER_HOST)

SHIFT_PROBE_LINE = "# 24.3b inversion probe: simulated above-boundary insertion\n"
SUBSTITUTE_TOKEN = "mir-to-c-output"
DISABLED_COMMAND_ANCHOR = '$positive_source" >"$case_dir/default.c'
DELETED_TABLE_ROW_PREFIX = "| `Makefile` | `none` |"

FROZEN_TRANSITION = "Patch 24.0c frozen live-C transition drifted"
EFFECTIVE_AGGREGATE = "effective Phase 22 aggregate drifted"
LANDED_SITE = "a landed Stdlib invocation site drifted"
RETIREMENT_CONTRACT = "24.3b invocation digest fields drifted"
STALE_REVIEW = "generated opening review is stale"


def load(name: str, relative: str):
    spec = importlib.util.spec_from_file_location(name, str(ROOT / relative))
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def patch_in_effect() -> bool:
    """Abort unless the tree under test carries the retirement."""
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    contract = registry.get(
        "phase24_s1_8_authority_successor", {}).get(
            "s1_9_resource_assignment_roadmap_successor", {}).get(
                "pinned_manifest_class_contract", {})
    node = contract.get("phase24_3b_coordinate_retirement")
    if not isinstance(node, dict):
        return False
    if node.get("readmission") != "rejected":
        return False
    dep = load("inv_dep", "scripts/phase23_mir_to_c_deprecation_opening.py")
    fro = load("inv_fro", "scripts/phase23_mir_to_c_frozen_surface.py")
    return ("line" not in dep.INVOCATION_DIGEST_FIELDS and
            "line" not in fro.LIVE_C_DIGEST_FIELDS and
            "case_id" not in fro.LIVE_C_DIGEST_FIELDS)


def run_guard(relative: str, command: str) -> tuple[int, str]:
    done = subprocess.run(
        [sys.executable, str(ROOT / relative), command],
        cwd=ROOT, capture_output=True, text=True, timeout=600)
    return done.returncode, (done.stdout + done.stderr).strip()


def check_rejected(label: str, relative: str, command: str,
                   pinned: str) -> bool:
    code, output = run_guard(relative, command)
    if code == 0:
        print(f"{label}: ACCEPTED (guard passed; relaxation cannot fail)")
        return False
    if pinned in output:
        print(f"{label}: REJECTED as required ({pinned})")
        return True
    print(f"{label}: REJECTED ELSEWHERE (expected {pinned!r}):")
    print("   actual: " + output[-300:])
    return False


def check_accepted(label: str, relative: str, command: str) -> bool:
    code, output = run_guard(relative, command)
    if code == 0:
        print(f"{label}: ACCEPTED as required")
        return True
    print(f"{label}: REJECTED (retirement incomplete):")
    print("   actual: " + output[-300:])
    return False


# --- acceptance: a line shift validates -------------------------------------

def a01_justfile_insertion() -> bool:
    JUSTFILE.write_text(
        SHIFT_PROBE_LINE + JUSTFILE.read_text(encoding="utf-8"),
        encoding="utf-8")
    ok = True
    ok &= check_accepted(
        "A01 opening review under shift",
        "scripts/phase22_opening.py", "check-review")
    ok &= check_accepted(
        "A01 frozen surface under shift",
        "scripts/phase23_mir_to_c_frozen_surface.py", "validate")
    ok &= check_accepted(
        "A01 guard transition under shift",
        "scripts/phase24_cr15_stdlib_guard_transition.py", "validate")
    ok &= check_accepted(
        "A01 deprecation opening under shift",
        "scripts/phase23_mir_to_c_deprecation_opening.py", "validate")
    return ok


def a02_driver_match_without_coordinate() -> bool:
    # The observation driver lives in an excluded guard script, so moving it
    # trips no text pin; pre-patch, the meaning-identical row at its new line
    # failed the ten-field match and every guard with it. Post-patch the
    # match ignores the coordinate and the shift validates.
    text = DRIVER_HOST.read_text(encoding="utf-8")
    DRIVER_HOST.write_text(SHIFT_PROBE_LINE + text, encoding="utf-8")
    return check_accepted(
        "A02 driver match under shift",
        "scripts/phase24_cr15_stdlib_guard_transition.py", "validate")


def a03_invocation_digest_without_coordinate() -> bool:
    dep = load("a03_dep", "scripts/phase23_mir_to_c_deprecation_opening.py")
    rows = dep.scan_invocations()
    before = dep.canonical_digest(dep.invocation_digest_rows(rows))
    shifted = copy.deepcopy(rows)
    for row in shifted:
        row["line"] = int(row["line"]) + 1
    after = dep.canonical_digest(dep.invocation_digest_rows(shifted))
    if after == before:
        print("A03 invocation digest under shift: ACCEPTED as required")
        return True
    print("A03 invocation digest under shift: REJECTED (digest moved)")
    return False


def a04_live_c_digest_without_coordinate() -> bool:
    fro = load("a04_fro", "scripts/phase23_mir_to_c_frozen_surface.py")
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    cases = fro.live_c_case_rows()
    before = fro.live_c_summary(cases)
    shifted = copy.deepcopy(cases)
    for row in shifted:
        row["line"] = int(row["line"]) + 1
        row["case_id"] = (
            f"{row['path']}:{row['line']}:{row['recipe'] or 'direct'}")
    after = fro.live_c_summary(shifted)
    if after == before:
        print("A04 live-C digest under shift: ACCEPTED as required")
        return True
    print("A04 live-C digest under shift: REJECTED (surface moved)")
    return False


# --- rejection: a meaning change fails --------------------------------------

def r01_command_substitution() -> bool:
    text = JUSTFILE.read_text(encoding="utf-8")
    assert text.count(SUBSTITUTE_TOKEN) == 1
    JUSTFILE.write_text(
        text.replace(SUBSTITUTE_TOKEN, SUBSTITUTE_TOKEN + "-substituted"),
        encoding="utf-8")
    return check_rejected(
        "R01 command substitution",
        "scripts/phase23_mir_to_c_frozen_surface.py", "validate",
        FROZEN_TRANSITION)


def r02_invocation_deletion() -> bool:
    lines = JUSTFILE.read_text(encoding="utf-8").splitlines(keepends=True)
    hits = [index for index, line in enumerate(lines)
            if DISABLED_COMMAND_ANCHOR in line and
            line.lstrip().startswith("./gust")]
    assert len(hits) == 1, "deletion anchor is missing or duplicated"
    lines[hits[0]] = "# 24.3b inversion probe: disabled invocation\n"
    JUSTFILE.write_text("".join(lines), encoding="utf-8")
    return check_rejected(
        "R02 invocation deletion",
        "scripts/phase24_cr15_stdlib_guard_transition.py", "validate",
        EFFECTIVE_AGGREGATE)


def mutate_registry(mutate) -> bool:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    mutate(registry)
    REGISTRY.write_text(json.dumps(registry, indent=2) + "\n",
                        encoding="utf-8")
    return True


def contract(registry: dict) -> dict:
    return registry["phase24_s1_8_authority_successor"][
        "s1_9_resource_assignment_roadmap_successor"][
            "pinned_manifest_class_contract"]


def r03_landed_count_mutation() -> bool:
    # Mutating the registered count (rather than removing the site) reaches
    # the site check inside the projection, ahead of the aggregate: it pins
    # the site tooth precisely. Removing the site instead trips the
    # aggregate first (see R03b); both teeth are real and each case names
    # the one it exercises.
    def mutate(registry: dict) -> None:
        sites = contract(registry)["landed_stdlib_invocation_sites"]
        assert len(sites) > 1
        key = sorted(sites, key=lambda s: str(s["path"]))[0]
        key["invocation_count"] = int(key["invocation_count"]) + 1
    mutate_registry(mutate)
    return check_rejected(
        "R03 landed count mutation",
        "scripts/phase24_cr15_stdlib_guard_transition.py", "validate",
        LANDED_SITE)


def r03b_landed_site_removal() -> bool:
    def mutate(registry: dict) -> None:
        sites = contract(registry)["landed_stdlib_invocation_sites"]
        assert len(sites) > 1
        del sites[-1]
    mutate_registry(mutate)
    return check_rejected(
        "R03b landed site removal",
        "scripts/phase24_cr15_stdlib_guard_transition.py", "validate",
        EFFECTIVE_AGGREGATE)


def r04_coordinate_readmission() -> bool:
    def mutate(registry: dict) -> None:
        fields = contract(registry)[
            "phase24_3b_coordinate_retirement"]["invocation_digest_fields"]
        fields.append("line")
    mutate_registry(mutate)
    return check_rejected(
        "R04 coordinate readmission",
        "scripts/phase24_cr15_stdlib_guard_transition.py", "validate",
        RETIREMENT_CONTRACT)


def r05_stored_digest_rollback() -> bool:
    # Roll back ONLY the terminal stored digest via its registry path, so
    # every chain link still holds and the terminal live comparison is the
    # tooth that must fire. A first-occurrence text rollback instead breaks
    # an older stored==stored link first (observed: Patch 23.13 fires),
    # which proves chain integrity but not the terminal.
    fro = load("r05_fro", "scripts/phase23_mir_to_c_frozen_surface.py")
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    live = fro.scan(registry)["live_c_case_surface"]
    current = live["case_id_manifest_digest"]
    terminal = registry["phase24_cr15_derivation"]["frozen_surface_transition"][
        "current_live_c_case_surface"]
    assert terminal["case_id_manifest_digest"] == current
    assert terminal["count"] == live["count"] == 178
    terminal["case_id_manifest_digest"] = "0" * 64
    REGISTRY.write_text(json.dumps(registry, indent=2) + "\n",
                        encoding="utf-8")
    return check_rejected(
        "R05 stored digest rollback",
        "scripts/phase23_mir_to_c_frozen_surface.py", "validate",
        FROZEN_TRANSITION)


def r06_review_tamper() -> bool:
    lines = OPENING_REVIEW.read_text(encoding="utf-8").splitlines(keepends=True)
    hit = next(index for index, line in enumerate(lines)
               if line.startswith(DELETED_TABLE_ROW_PREFIX))
    del lines[hit]
    OPENING_REVIEW.write_text("".join(lines), encoding="utf-8")
    return check_rejected(
        "R06 review tamper",
        "scripts/phase22_opening.py", "check-review",
        STALE_REVIEW)


def main() -> int:
    if not patch_in_effect():
        print("24.3b retirement is not in effect; aborting "
              "(harness must test the patched code).")
        return 2
    saved = {path: path.read_bytes() for path in PERTURBED}
    failures = 0
    total = 0
    try:
        for case in (a01_justfile_insertion,
                     a02_driver_match_without_coordinate,
                     a03_invocation_digest_without_coordinate,
                     a04_live_c_digest_without_coordinate,
                     r01_command_substitution,
                     r02_invocation_deletion,
                     r03_landed_count_mutation,
                     r03b_landed_site_removal,
                     r04_coordinate_readmission,
                     r05_stored_digest_rollback,
                     r06_review_tamper):
            for path in PERTURBED:
                path.write_bytes(saved[path])
            total += 1
            try:
                if not case():
                    failures += 1
            except SystemExit as exc:
                print(f"{case.__name__}: harness error SystemExit({exc})")
                failures += 1
    finally:
        for path in PERTURBED:
            path.write_bytes(saved[path])
    restored = all(path.read_bytes() == saved[path] for path in PERTURBED)
    print(f"\n{total - failures}/{total} inversions held; "
          f"tree restored: {restored}")
    if not restored:
        return 1
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
