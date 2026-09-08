#!/usr/bin/env python3
"""Gated inversion suite for the Patch 24.3b dead-chain retirement.

Patch 24.3b retired sixty of the sixty-one stored aggregate manifest digests.
Line coverage over the thirteen registry-consumer guard invocations showed that
none of the sixty was ever compared against a value derived from the live tree:
they were dead by four independent mechanisms - chain-only object equality,
`if <successor> is None:` branches that no tree reaches, literal `X == X`
self-comparisons that do execute, and source literals that pin one stored
digest to another.  One row was retained, the only one a live comparison reads:

    phase22_default_route_seed_convergence
      / phase24_2g_auth_seed_identity_successor
      / unchanged_other_text_surface_manifest_digest

A relaxation of a check that already cannot fail is a deleted test.  This suite
exists so that the retained one is demonstrably not in that category: it drives
the same check from both sides - move the registered value against a fixed tree,
and move the tree against a fixed registered value - and requires a rejection
each time.  It also covers the branch the retirement removed: the guard used to
fall back to a now-retired digest when the successor was absent, and now
requires the successor to be present.

    python3 scripts/phase24_3b_dead_chain_inversions.py
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
# This file is registered in the guard's SELF_EXCLUSIONS, alongside the Phase
# 26/27 inversion suite it is modelled on: enrolment is by content, and a suite
# that names the manifest machinery would otherwise enrol in the manifest it
# exercises and move the very count it is asserting about.
GUARD = ROOT / "scripts/phase23_mir_to_c_deprecation_opening.py"
ANCHOR = ("phase22_default_route_seed_convergence",
          "phase24_2g_auth_seed_identity_successor",
          "unchanged_other_text_surface_manifest_digest")

# An enrolled text surface that no projection rewrites and that the registry
# never names, so a change to it reaches the aggregate rather than being
# replaced by a frozen row.  Deliberately not compiler source.
PROBE = ROOT / ".github/workflows/phase15-move-state.yml"

UNREGISTERED = "changed an unregistered text surface"
MISSING_AUTH = "Patch 24.2g-auth seed identity successor is missing"


def run_guard() -> tuple[int, str]:
    done = subprocess.run(
        [sys.executable, str(GUARD), "validate"],
        cwd=ROOT, capture_output=True, text=True)
    return done.returncode, (done.stdout + done.stderr).strip()


# --- registry inversions ----------------------------------------------------

def m_anchor_value(registry: dict) -> None:
    """The registered value moves; the tree does not."""
    successor = registry[ANCHOR[0]][ANCHOR[1]]
    digest = successor[ANCHOR[2]]
    successor[ANCHOR[2]] = ("0" * 8) + digest[8:]


def m_anchor_absent(registry: dict) -> None:
    """The successor that carries the retained digest goes missing."""
    del registry[ANCHOR[0]][ANCHOR[1]]


REGISTRY_CASES = [
    ("registered anchor value moved", m_anchor_value, UNREGISTERED),
    ("anchor successor removed", m_anchor_absent, MISSING_AUTH),
]


# --- tree inversions --------------------------------------------------------

def t_enrolled_surface_moved() -> None:
    """The tree moves; the registered value does not."""
    PROBE.write_bytes(PROBE.read_bytes() +
                      b"\n# phase24.3b inversion probe\n")


TREE_CASES = [
    ("enrolled unprojected surface moved", t_enrolled_surface_moved,
     UNREGISTERED),
]


def main() -> int:
    original = REGISTRY.read_bytes()
    probe_original = PROBE.read_bytes()
    failures = 0

    code, message = run_guard()
    if code != 0:
        print(f"CONTROL FAILED: the tree is not green before the suite\n  {message}")
        return 1

    for name, mutate, expected in REGISTRY_CASES:
        registry = json.loads(original.decode("utf-8"))
        mutate(registry)
        REGISTRY.write_text(json.dumps(registry, indent=2) + "\n",
                            encoding="utf-8")
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

    for name, mutate, expected in TREE_CASES:
        mutate()
        code, message = run_guard()
        PROBE.write_bytes(probe_original)
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
