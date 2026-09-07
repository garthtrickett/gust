#!/usr/bin/env python3
"""Gated inversion suite for the Phase 26/27 docs consumer successor retirement.

Two of that successor's assertions were retired because each compares the live
tree against an inventory frozen at the PR #318 docs migration and never bumped
afterwards.  Every other assertion it backs is retained, and this suite exists
to prove that each retained one can still fail: it constructs a violation per
case and requires the guard to reject it.

A relaxation that cannot fail is a deleted test.  Run:

    python3 scripts/phase24_docs_successor_retirement_inversions.py
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
GUARD = ROOT / "scripts/phase23_mir_to_c_deprecation_opening.py"
SUCCESSOR = ("phase24_s1_8_authority_successor",
             "phase26_27_docs_consumer_successor")

# An enrolled text surface that no projection rewrites, so a change to it
# reaches the manifest digests rather than being replaced by a frozen row.
OTHER_ENROLLED = "compiler/mir_layout.gst"
NEW_SURFACE = "compiler/phase24_inversion_probe_surface.md"
SUBSTITUTE_SURFACE = "compiler/mir_layout_substituted.gst"

DRIFTED = "Phase 26/27 docs consumer successor drifted"
FROZEN_ROW = "Phase 26/27 docs changed a frozen row beyond file identity"
LIVE_STATE = "Phase 26/27 docs live state is partial, extra, or substituted"
RETAINED_FIELD = "Phase 26/27 docs changed retained inventory field"
UNREGISTERED = "changed an unregistered text surface"


def git(*args: str) -> None:
    subprocess.run(["git", *args], cwd=ROOT, capture_output=True)


def run_guard() -> tuple[int, str]:
    done = subprocess.run(
        [sys.executable, str(GUARD), "validate"],
        cwd=ROOT, capture_output=True, text=True)
    return done.returncode, (done.stdout + done.stderr).strip()


def successor_of(registry: dict) -> dict:
    return registry[SUCCESSOR[0]][SUCCESSOR[1]]


def registered_docs_paths() -> list[str]:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    return successor_of(registry)["registered_changed_text_surfaces"]


# --- registry mutations -----------------------------------------------------

def m_contract_version(registry: dict) -> None:
    successor_of(registry)["contract_version"] = "phase24_bogus_v2"


def m_status(registry: dict) -> None:
    successor_of(registry)["status"] = "ready_for_something_else"


def m_authority_base(registry: dict) -> None:
    successor_of(registry)["authority_base_main"] = "0" * 40


def m_owning_pull_request(registry: dict) -> None:
    successor_of(registry)["owning_docs_pull_request"] = 319


def m_owning_head_sha(registry: dict) -> None:
    successor_of(registry)["owning_docs_exact_head_sha"] = "0" * 40


def m_chain_link(registry: dict) -> None:
    """Break previous_inventory == the coordination successor's current one."""
    successor_of(registry)["previous_inventory"]["invocation_count"] += 1


def m_accepted_state_names(registry: dict) -> None:
    successor_of(registry)["accepted_live_states"] = [
        "post_phase26_27_docs", "pre_phase26_27_docs"]


def m_registered_paths_reordered(registry: dict) -> None:
    paths = successor_of(registry)["registered_changed_text_surfaces"]
    paths[0], paths[1] = paths[1], paths[0]


def m_registered_paths_substituted(registry: dict) -> None:
    successor_of(registry)["registered_changed_text_surfaces"][0] = "GEMINI2.md"


def m_unchanged_fields(registry: dict) -> None:
    successor_of(registry)["unchanged_fields"].remove("invocation_count")


def m_partial_accepted(registry: dict) -> None:
    successor_of(registry)["partial_extra_or_substituted_surface"] = "accepted"


def m_boundary_flag(registry: dict) -> None:
    successor_of(registry)["boundary"]["begins_patch24_3"] = True


def m_frozen_row_digest_equal(registry: dict) -> None:
    """A registered doc that did not change is not a migration row."""
    successor = successor_of(registry)
    successor["previous_changed_text_surfaces"][0]["digest"] = \
        successor["current_changed_text_surfaces"][0]["digest"]


def m_frozen_row_identity(registry: dict) -> None:
    """A row may differ only in digest; class drift is a substitution."""
    successor_of(registry)["current_changed_text_surfaces"][0][
        "classification"] = "bootstrap_phase25"


def m_retained_inventory_field(registry: dict) -> None:
    successor_of(registry)["current_inventory"]["invocation_count"] += 1


REGISTRY_CASES = [
    ("R01 contract_version drift", m_contract_version, DRIFTED),
    ("R02 status drift", m_status, DRIFTED),
    ("R03 authority_base_main drift", m_authority_base, DRIFTED),
    ("R04 owning PR renumbered", m_owning_pull_request, DRIFTED),
    ("R05 owning head sha drift", m_owning_head_sha, DRIFTED),
    ("R06 predecessor chain link broken", m_chain_link, DRIFTED),
    ("R07 accepted state order swapped", m_accepted_state_names, DRIFTED),
    ("R08 registered paths reordered", m_registered_paths_reordered, DRIFTED),
    ("R09 registered path substituted", m_registered_paths_substituted, DRIFTED),
    ("R10 unchanged_fields narrowed", m_unchanged_fields, DRIFTED),
    ("R11 partial/substituted newly accepted", m_partial_accepted, DRIFTED),
    ("R12 boundary flag flipped", m_boundary_flag, DRIFTED),
    ("R13 frozen row digest made equal", m_frozen_row_digest_equal, FROZEN_ROW),
    ("R14 frozen row class substituted", m_frozen_row_identity, FROZEN_ROW),
    ("R15 retained inventory field moved", m_retained_inventory_field,
     RETAINED_FIELD),
]


# --- live-tree mutations ----------------------------------------------------
#
# L01 is the case that isolates what the retained half of the live-state check
# still buys.  Changing a registered PR #318 document *and* registering that
# change at the maintained Patch 24.2f digest satisfies every whole-tree
# obligation; only the retained per-row half rejects it.  Without the 24.2f
# bump the run would stop earlier and prove nothing about this check, which is
# why the bump is part of the case rather than a convenience.
#
# L02-L05 are the replacement coverage for the two retired whole-tree pins: an
# unregistered change to any other enrolled surface is still rejected, now by
# the maintained Patch 24.2f digest instead of the frozen PR #318 one.

TREE_CASES = [
    ("L01 registered doc moved, tree change registered",
     "registered-doc-with-bump", LIVE_STATE),
    ("L02 non-projected enrolled file edited", "other-enrolled-edit",
     UNREGISTERED),
    ("L03 new enrolling file added", "new-enrolled-file", UNREGISTERED),
    ("L04 enrolled file removed", "remove-enrolled", UNREGISTERED),
    ("L05 enrolled path substituted", "substitute-enrolled", UNREGISTERED),
]


def bump_24_2f() -> bool:
    """Register the live tree at the maintained Patch 24.2f digest."""
    _, message = run_guard()
    marker = "unregistered text surface: "
    if marker not in message:
        return False
    fresh = message.split(marker, 1)[1].split()[0]
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    stale = registry["phase22_default_route_seed_convergence"][
        "phase24_2g_auth_seed_identity_successor"][
            "unchanged_other_text_surface_manifest_digest"]
    raw = REGISTRY.read_text(encoding="utf-8")
    if raw.count(stale) != 1:
        return False
    REGISTRY.write_text(raw.replace(stale, fresh), encoding="utf-8")
    return True


def apply_tree_case(kind: str) -> None:
    if kind == "registered-doc-with-bump":
        # The three registered PR #318 documents that are not also Patch 24.2r
        # living surfaces are the ones this check can speak about; the other
        # six are projected to frozen rows by that earlier, deliberate design.
        target = ROOT / "docs/RUST_PROTOTYPE_REMOVAL.md"
        target.write_bytes(target.read_bytes() + b"\n<!-- inv -->\n")
        bump_24_2f()
    elif kind == "other-enrolled-edit":
        target = ROOT / OTHER_ENROLLED
        target.write_bytes(target.read_bytes() + b"\n// inv\n")
    elif kind == "new-enrolled-file":
        (ROOT / NEW_SURFACE).write_text(
            "Names the mir_to_c route so that it enrols.\n", encoding="utf-8")
        git("add", "-N", NEW_SURFACE)
    elif kind == "remove-enrolled":
        git("rm", "-q", "--force", OTHER_ENROLLED)
    elif kind == "substitute-enrolled":
        git("mv", OTHER_ENROLLED, SUBSTITUTE_SURFACE)
    else:
        raise AssertionError(f"unknown tree case: {kind}")


def restore() -> None:
    """Return the worktree to HEAD, including index-only and created paths."""
    for created in (NEW_SURFACE, SUBSTITUTE_SURFACE):
        git("rm", "-q", "--force", "--ignore-unmatch", created)
        path = ROOT / created
        if path.exists():
            path.unlink()
    git("reset", "-q", "HEAD", "--", ".")
    git("checkout", "--", ".")


def main() -> int:
    code, message = run_guard()
    if code != 0:
        print("CONTROL FAILED: the guard is not green before any mutation.\n"
              f"  {message}")
        return 1
    print("control: guard green on the unmutated tree\n")

    failures = 0
    original = REGISTRY.read_bytes()
    for name, mutate, expected in REGISTRY_CASES:
        registry = json.loads(original.decode("utf-8"))
        mutate(registry)
        REGISTRY.write_text(json.dumps(registry, indent=2), encoding="utf-8")
        code, message = run_guard()
        REGISTRY.write_bytes(original)
        ok = code != 0 and expected in message
        failures += 0 if ok else 1
        print(f"[{'PASS' if ok else 'FAIL'}] {name}", flush=True)
        if not ok:
            print(f"         expected: {expected}\n         got:      {message}")

    if REGISTRY.read_bytes() != original:
        print("CONTROL FAILED: the registry was not restored byte-exactly")
        return 1

    for name, kind, expected in TREE_CASES:
        apply_tree_case(kind)
        code, message = run_guard()
        REGISTRY.write_bytes(original)
        restore()
        ok = code != 0 and expected in message
        failures += 0 if ok else 1
        print(f"[{'PASS' if ok else 'FAIL'}] {name}", flush=True)
        if not ok:
            print(f"         expected: {expected}\n         got:      {message}")

    code, message = run_guard()
    if code != 0:
        print(f"\nCONTROL FAILED: the tree was not restored\n  {message}")
        return 1

    total = len(REGISTRY_CASES) + len(TREE_CASES)
    print(f"\n{total - failures}/{total} inversions rejected as required")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
