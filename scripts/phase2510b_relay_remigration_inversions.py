#!/usr/bin/env python3
"""Gated inversion suite for the Patch 25.10b relay re-migration successor.

Patch 24.13 recorded where each retired `--backend mir-to-c` relay site was
migrated TO. A migration record pins a DESTINATION rather than a state, so it
is tripped by re-migrating a site, not by editing one. Patch 25.10b re-migrates
one of those destinations: the runner's negative path leaves the bootstrap
emitter for the native route. 24.13's record stays exactly as written -- it is
a true statement about what 24.13 did -- and this patch registers the newer
link, which the opening contract consults before looking for 24.13's
destination in the tree.

The same patch retires the `line` coordinate from both destination lookups,
on Patch 24.3b's reasoning: a coordinate is a fact with a shelf life, and any
insertion above a row moves it, so a destination matched WITH its line turns
an unrelated edit elsewhere in the file into migration drift. Dropping it is
also strictly stronger on the absence half -- the retired command must be gone
from the whole file, not merely off the line it used to sit on.

A relaxation that cannot fail is a deleted test, so this suite proves both
directions. Three outcomes per case, never two: ACCEPTED, REJECTED at the
pinned message, and REJECTED elsewhere -- reported as a failure with the
actual message, because a rejection by some other clause does not show the
clause under test is reachable. Two cases here were written wrong the first
time and only that third outcome revealed it: with the successor's clauses
ordered "arrived, then departed", putting 24.13's destination back reported
the successor's destination as missing instead, and orphaning the successor's
only entry fell through to 24.13's own check. The clauses are ordered
"departed, then arrived" because of the first, and the accounting clause is
exercised with an EXTRA entry because of the second.

    python3 scripts/phase2510b_relay_remigration_inversions.py
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
RUNNER = ROOT / "tests/test_runner.gst"
GUARD = ROOT / "scripts/phase22_opening.py"

# Tracked paths this suite perturbs, saved and restored as bytes.
PERTURBED = (REGISTRY, RUNNER)
NODE = "phase2510b_runner_negative_path"

NATIVE = 'mut cmd := std.Concat("./gust --backend cranelift -o /dev/null ", path);'
EMITTER = 'mut cmd := std.Concat("./gust --backend bootstrap-emitter ", path);'
COMPILE = 'mut cmd_comp := std.Concat("./gust --backend bootstrap-emitter ", path);'


def run_guard() -> tuple[int, str]:
    result = subprocess.run(
        [sys.executable, str(GUARD), "validate"],
        capture_output=True, text=True, cwd=ROOT)
    blob = (result.stderr + result.stdout).strip()
    return result.returncode, blob.splitlines()[-1] if blob else ""


def registry_entry(registry: dict) -> dict:
    return registry[NODE]["relay_remigration"]["migrations"][0]


def write_registry(mutate) -> None:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    mutate(registry)
    REGISTRY.write_text(
        json.dumps(registry, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def substitute(old: str, new: str) -> None:
    text = RUNNER.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"inversion probe anchor is absent: {old}")
    RUNNER.write_text(text.replace(old, new), encoding="utf-8")


# (name, expected message or None for "must still be accepted", mutation)
CASES = (
    ("successor destination is absent from the tree",
     "Patch 25.10b records a replacement",
     lambda: write_registry(lambda r: registry_entry(r)["migrated_site"].update(
         command='mut cmd := std.Concat("./gust --backend nope ", path);'))),
    ("successor node deleted entirely",
     "Patch 24.13 records a replacement",
     lambda: write_registry(lambda r: r.pop(NODE))),
    ("24.13's destination is put back in the tree",
     "24.13's destination is still in the tree",
     lambda: substitute(NATIVE, EMITTER)),
    ("successor claims an extra site 24.13 never migrated to",
     "never migrated to",
     lambda: write_registry(lambda r: r[NODE]["relay_remigration"]["migrations"]
                            .append(orphan(r)))),
    ("successor destination still spells the retired backend",
     "still spells bootstrap-emitter",
     lambda: remigrate_to_emitter()),
    ("unremigrated 24.13 destination changes command",
     "Patch 24.13 records a replacement",
     lambda: substitute(
         COMPILE, 'mut cmd_comp := std.Concat("./gust --backend nope ", path);')),
    # Acceptance: the coordinate is retired in BOTH lookups, so a destination
    # that only moved down the file still validates. Without these two, every
    # rejection above would also be satisfied by pinning `line` again.
    ("successor destination line is wrong", None,
     lambda: write_registry(lambda r: registry_entry(r)["migrated_site"].update(
         line=999))),
    ("unremigrated 24.13 destination is pushed down a line", None,
     lambda: substitute(COMPILE, "\n        " + COMPILE)),
)


def orphan(registry: dict) -> dict:
    entry = json.loads(json.dumps(registry_entry(registry)))
    entry["pinned_site"]["command"] = (
        'mut x := std.Concat("./gust --backend unrelated ", path);')
    return entry


def remigrate_to_emitter() -> None:
    moved = 'mut cmd := std.Concat("./gust --backend bootstrap-emitter -o /dev/null ", path);'
    write_registry(lambda r: registry_entry(r)["migrated_site"].update(command=moved))
    substitute(NATIVE, moved)


def main() -> int:
    saved = {path: path.read_bytes() for path in PERTURBED}

    def restore() -> None:
        for path, blob in saved.items():
            path.write_bytes(blob)

    code, message = run_guard()
    if code != 0:
        print(f"control: the tree does not validate before any mutation: {message}")
        return 1
    print(f"control: accepted ({message})")

    failures = 0
    try:
        for name, expected, mutate in CASES:
            restore()
            mutate()
            code, message = run_guard()
            if expected is None:
                verdict = "ACCEPTED" if code == 0 else "REJECTED elsewhere"
                good = code == 0
            elif code == 0:
                verdict, good = "ACCEPTED", False
            elif expected in message:
                verdict, good = "REJECTED at the pinned message", True
            else:
                verdict, good = "REJECTED elsewhere", False
            failures += not good
            print(f"{'ok  ' if good else 'FAIL'} {name}\n       {verdict}: {message}")
    finally:
        restore()

    code, message = run_guard()
    if code != 0:
        print(f"the tree did not restore cleanly: {message}")
        return 1
    print(f"{len(CASES) - failures} of {len(CASES)} inversion cases behaved as pinned")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
