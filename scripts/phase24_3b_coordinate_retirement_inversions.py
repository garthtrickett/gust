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
ROUTE_ARCHITECTURE = ROOT / "scripts/phase12_5_route_architecture.sh"

# Tracked paths this suite perturbs, saved and restored as bytes.
PERTURBED = (JUSTFILE, REGISTRY, OPENING_REVIEW, DRIVER_HOST,
             ROUTE_ARCHITECTURE)

SHIFT_PROBE_LINE = "# 24.3b inversion probe: simulated above-boundary insertion\n"
# Patch 24.13 retired both of the coordinates R01 and R02 used to perturb.
#
# R01 substituted a justfile token inside a command that emitted C. 24.13
# turned that case into an -o *refusal*, so it emits no C at all and its
# label left the live-C surface. Renaming the token to follow the label --
# the first reading of this breakage -- kept the "appears exactly once"
# assertion satisfied while the inversion silently stopped biting: the
# relaxation was ACCEPTED, which is the failure mode this suite exists to
# catch. R02's anchor did not move at all; the `>"$case_dir/default.c"`
# redirection is gone from the tree, because that is what retiring the
# generated-C backend means.
#
# Both are retired by absence rather than deleted: R01 and R02 assert the
# old coordinates are gone, then re-point at a live-C coordinate that is
# Cranelift-owned. The 26 live-C cases that survive 24.13 are otherwise
# Stdlib-lane recipes scheduled for removal by the #398 rewiring, so
# anchoring a Cranelift inversion to them would only break again.
RETIRED_SUBSTITUTE_TOKEN = "mir-to-c-output"
RETIRED_DISABLED_COMMAND_ANCHOR = '$positive_source" >"$case_dir/default.c'
LIVE_C_INVOCATION_ANCHOR = "./gust --backend mir-to-c"
SUBSTITUTE_TOKEN = '"$novel_source"'
DELETED_TABLE_ROW_PREFIX = "| `Makefile` | `none` |"

FROZEN_TRANSITION = "Patch 24.13 frozen live-C transition drifted"
# Terminal link of the frozen-surface chain, and the live-C count it
# carries. Both move with every patch that adds a link; pinning them is
# what makes such a patch announce itself here instead of silently
# comparing an interior link against live.
TERMINAL_FROZEN_LINK = "phase24_13_backend_removal"
TERMINAL_LIVE_C_COUNT = 26
EFFECTIVE_AGGREGATE = "effective Phase 22 aggregate drifted"
LANDED_SITE = "a landed Stdlib invocation site drifted"
RETIREMENT_CONTRACT = "24.3b invocation digest fields drifted"
APPENDED_NOT_EXPLICIT = ("an appended Stdlib invocation does not select a "
                         "backend explicitly")
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

def live_c_invocation_line(text: str) -> int:
    """Index of the one live-C invocation R01 and R02 perturb."""
    lines = text.splitlines(keepends=True)
    hits = [index for index, line in enumerate(lines)
            if LIVE_C_INVOCATION_ANCHOR in line]
    assert len(hits) == 1, (
        "live-C invocation anchor is missing or duplicated in "
        f"{ROUTE_ARCHITECTURE.name}")
    return hits[0]


def r01_command_substitution() -> bool:
    assert RETIRED_SUBSTITUTE_TOKEN not in JUSTFILE.read_text(
        encoding="utf-8"), (
        "the coordinate Patch 24.13 retired is back in the justfile")
    text = ROUTE_ARCHITECTURE.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)
    index = live_c_invocation_line(text)
    assert lines[index].count(SUBSTITUTE_TOKEN) == 1
    lines[index] = lines[index].replace(
        SUBSTITUTE_TOKEN, SUBSTITUTE_TOKEN[:-1] + '_substituted"')
    ROUTE_ARCHITECTURE.write_text("".join(lines), encoding="utf-8")
    return check_rejected(
        "R01 command substitution",
        "scripts/phase23_mir_to_c_frozen_surface.py", "validate",
        FROZEN_TRANSITION)


def r02_invocation_deletion() -> bool:
    assert RETIRED_DISABLED_COMMAND_ANCHOR not in JUSTFILE.read_text(
        encoding="utf-8"), (
        "the generated-C redirection Patch 24.13 retired is back")
    text = ROUTE_ARCHITECTURE.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)
    lines[live_c_invocation_line(text)] = (
        "# 24.3b inversion probe: disabled invocation\n")
    ROUTE_ARCHITECTURE.write_text("".join(lines), encoding="utf-8")
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


def stdlib_site_selections() -> dict:
    """Selections actually scanned at each landed Stdlib invocation site."""
    dep = load("r03b_dep", "scripts/phase23_mir_to_c_deprecation_opening.py")
    seen: dict = {}
    for row in dep.scan_invocations():
        if str(row.get("owner")) != "stdlib":
            continue
        key = (str(row["path"]), str(row["recipe"]))
        seen.setdefault(key, set()).add(str(row.get("selection")))
    return seen


def split_landed_sites(registry: dict) -> tuple:
    """Landed sites partitioned by whether an append of them stays admissible.

    Patch 24.13 moved `tests/test_runner.gst` onto the bootstrap-only
    `--backend bootstrap-emitter` spelling, which is deliberately absent from
    `appended_stdlib_invocation_selections`: that entry point hard-fails
    without GUST_BOOTSTRAP_EMITTER=1, so a *newly appended* Stdlib invocation
    choosing it could not run. The site is grandfathered as landed, not as
    appendable.

    R03b used `sites[-1]`, which is that site. Un-registering it therefore
    tripped the explicitness check before the aggregate comparison it exists
    to exercise -- the inversion still "rejected", so it read as green in a
    one-line summary while testing a different tooth.
    """
    selections = stdlib_site_selections()
    allowed = set(contract(registry)["appended_stdlib_invocation_selections"])
    fall_through, trips = [], []
    for index, site in enumerate(
            contract(registry)["landed_stdlib_invocation_sites"]):
        seen = selections.get((str(site["path"]), str(site["recipe"])), set())
        (fall_through if seen and seen <= allowed else trips).append(index)
    return fall_through, trips


def r03b_landed_site_removal() -> bool:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    fall_through, _ = split_landed_sites(registry)
    assert len(fall_through) > 1, (
        "no landed Stdlib site still reaches the aggregate comparison")
    target = fall_through[-1]

    def mutate(reg: dict) -> None:
        sites = contract(reg)["landed_stdlib_invocation_sites"]
        assert len(sites) > 1
        del sites[target]
    mutate_registry(mutate)
    return check_rejected(
        "R03b landed site removal",
        "scripts/phase24_cr15_stdlib_guard_transition.py", "validate",
        EFFECTIVE_AGGREGATE)


def r03c_bootstrap_only_site_is_not_appendable() -> bool:
    """Companion to R03b: the exclusion above is asserted, not assumed."""
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    _, trips = split_landed_sites(registry)
    assert len(trips) == 1, (
        "expected exactly one bootstrap-only landed Stdlib site, "
        f"found {len(trips)}")
    target = trips[0]

    def mutate(reg: dict) -> None:
        del contract(reg)["landed_stdlib_invocation_sites"][target]
    mutate_registry(mutate)
    return check_rejected(
        "R03c bootstrap-only site is not appendable",
        "scripts/phase24_cr15_stdlib_guard_transition.py", "validate",
        APPENDED_NOT_EXPLICIT)


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
    # The terminal link is the newest one in the chain, not a fixed patch
    # name. Patch 24.13 added `phase24_13_backend_removal` ahead of
    # `phase24_cr15_derivation`, whose 178-case surface stays true of 24.0c
    # and is now an interior link -- comparing it to live raised a bare
    # AssertionError rather than naming what moved.
    terminal = registry[TERMINAL_FROZEN_LINK]["frozen_surface_transition"][
        "current_live_c_case_surface"]
    assert terminal["case_id_manifest_digest"] == current, (
        f"{TERMINAL_FROZEN_LINK} is not the terminal frozen-surface link")
    assert terminal["count"] == live["count"] == TERMINAL_LIVE_C_COUNT, (
        f"terminal live-C count moved: registered {terminal['count']}, "
        f"live {live['count']}, pinned {TERMINAL_LIVE_C_COUNT}")
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
                     r03c_bootstrap_only_site_is_not_appendable,
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
