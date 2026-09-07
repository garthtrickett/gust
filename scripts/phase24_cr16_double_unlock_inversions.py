#!/usr/bin/env python3
"""Gated inversion suite for the CR-16 raw double-unlock call-site successor.

The successor admits one new raw call site, so the thing worth proving is that
it admits *only* that one: every neighbouring shape - a different path, a
different count, a lock that came along for the ride, a call outside explicit
unsafe - must still be rejected.

The first case is the control. Without the registry row, the fixture is
rejected; with it, accepted. A registration that changes nothing would pass
every other case here while doing no work, so that case runs first and the
suite refuses to continue if it does not move.

    python3 scripts/phase24_cr16_double_unlock_inversions.py
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
GUARD = ROOT / "scripts/phase20_unsafe_mutex_migration.py"
FIXTURE = ROOT / "tests/stdlib_s1_mutex_guard_scope_raw_double_unlock.gst"
SUBSTITUTE = ROOT / "tests/stdlib_s1_mutex_guard_scope_substituted.gst"

TRANSITION = ("phase24_cr15_opening", "stdlib_guard_transition",
              "s1_9_raw_double_unlock_successor")

# Held here rather than in the repository: the contract counts untracked *.gst
# files on disk, so a committed copy would enrol the site permanently and the
# two-state design - row landed, fixture not yet shipped - could not be tested.
FIXTURE_SOURCE = '''import "stdlib_s1_mutex_guard_generic_derivation_module.gst" as sync;

type Counter struct {
    value: int
}

func main() int {
    mut arena := os.Arena.New();
    defer arena.Free();
    mut mutex: std.Mutex[Counter, arena] := std.MutexNew(&arena);
    mut owner := sync.lock(&mutex);
    unsafe {
        mutex.Unlock();
    }
    return 0;
}
'''

DRIFTED = "S1.9 raw double-unlock successor drifted"
SHAPE = "S1.9 added call site shape drifted"
NOT_REGISTERED_SHAPE = ("S1.9 double-unlock site is not the registered "
                        "zero-lock one-unlock shape")
PARTIAL = "S1.9 raw double-unlock fixture is partial or substituted"
CLASSIFICATION = "raw Mutex call-site classification drifted"
ENFORCEMENT = "differs from the exact Patch 20.16d enforcement-negative"
ALREADY_PINNED = "S1.9 double-unlock call site is already pinned"


def run_guard() -> tuple[int, str]:
    done = subprocess.run([sys.executable, str(GUARD), "validate"],
                          cwd=ROOT, capture_output=True, text=True)
    return done.returncode, (done.stdout + done.stderr).strip()


def successor_of(registry: dict) -> dict:
    node = registry
    for key in TRANSITION:
        node = node[key]
    return node


def write_fixture(source: str = FIXTURE_SOURCE,
                  target: Path = FIXTURE) -> None:
    target.write_text(source, encoding="utf-8")


def clear_fixtures() -> None:
    for path in (FIXTURE, SUBSTITUTE):
        if path.exists():
            path.unlink()


# --- registry mutations -----------------------------------------------------

def m_contract_version(registry: dict) -> None:
    successor_of(registry)["contract_version"] = "phase24_bogus_v9"


def m_partial_accepted(registry: dict) -> None:
    successor_of(registry)["partial_extra_or_substituted_call_site"] = \
        "accepted"


def m_safe_raw_calls(registry: dict) -> None:
    successor_of(registry)["safe_raw_calls_added"] = 1


def m_shape_key_dropped(registry: dict) -> None:
    del successor_of(registry)["added_call_site"]["role"]


def m_lock_calls_nonzero(registry: dict) -> None:
    successor_of(registry)["added_call_site"]["lock_calls"] = 1


def m_unlock_calls_two(registry: dict) -> None:
    successor_of(registry)["added_call_site"]["unlock_calls"] = 2


def m_path_substituted(registry: dict) -> None:
    successor_of(registry)["added_call_site"]["path"] = str(
        SUBSTITUTE.relative_to(ROOT))


def m_double_registration(registry: dict) -> None:
    """Re-registering a site an earlier successor already pins."""
    successor_of(registry)["added_call_site"].update({
        "path": "tests/stdlib_s1_mutex_guard_generic_derivation_module.gst",
        "lock_calls": 0,
        "unlock_calls": 1,
    })


REGISTRY_CASES = [
    ("R01 contract_version drift", m_contract_version, False, DRIFTED),
    ("R02 partial/substituted newly accepted", m_partial_accepted, False,
     DRIFTED),
    ("R03 safe raw call silently admitted", m_safe_raw_calls, False, DRIFTED),
    ("R04 added call-site shape key dropped", m_shape_key_dropped, False,
     SHAPE),
    ("R05 registered site given a lock", m_lock_calls_nonzero, False,
     NOT_REGISTERED_SHAPE),
    ("R06 registered site given a second unlock", m_unlock_calls_two, False,
     NOT_REGISTERED_SHAPE),
    ("R07 registered path substituted, fixture present", m_path_substituted,
     True, CLASSIFICATION),
    ("R08 re-registers an already-pinned site", m_double_registration, False,
     ALREADY_PINNED),
]


# --- live-tree mutations ----------------------------------------------------

WITH_EXTRA_LOCK = FIXTURE_SOURCE.replace(
    "    unsafe {\n        mutex.Unlock();\n    }\n",
    "    unsafe {\n        mutex.Lock();\n        mutex.Unlock();\n    }\n")
WITH_SECOND_UNLOCK = FIXTURE_SOURCE.replace(
    "        mutex.Unlock();\n",
    "        mutex.Unlock();\n        mutex.Unlock();\n")
WITHOUT_UNSAFE = FIXTURE_SOURCE.replace(
    "    unsafe {\n        mutex.Unlock();\n    }\n",
    "    mutex.Unlock();\n")

TREE_CASES = [
    ("L01 fixture gains a lock", WITH_EXTRA_LOCK, FIXTURE, PARTIAL),
    ("L02 fixture gains a second unlock", WITH_SECOND_UNLOCK, FIXTURE,
     PARTIAL),
    ("L03 fixture unlock leaves explicit unsafe", WITHOUT_UNSAFE, FIXTURE,
     ENFORCEMENT),
    ("L04 fixture shipped at an unregistered path", FIXTURE_SOURCE, SUBSTITUTE,
     CLASSIFICATION),
]


def main() -> int:
    clear_fixtures()
    original = REGISTRY.read_bytes()
    failures = 0

    code, message = run_guard()
    if code != 0:
        print(f"CONTROL FAILED: guard not green before any mutation\n  {message}")
        return 1
    print("control: guard green, fixture absent (the registered pre-state)")

    write_fixture()
    code, message = run_guard()
    clear_fixtures()
    if code != 0:
        print("CONTROL FAILED: guard rejects the fixture it registers\n"
              f"  {message}")
        return 1
    print("control: guard green, fixture present (the registered post-state)")

    # The load-bearing control. If the row is not what admits the fixture, the
    # registration is a no-op and every case below would pass while proving
    # nothing.
    registry = json.loads(original.decode("utf-8"))
    disabled = json.dumps(registry).replace(
        '"s1_9_raw_double_unlock_successor"',
        '"s1_9_raw_double_unlock_successor_disabled"', 1)
    REGISTRY.write_text(disabled, encoding="utf-8")
    write_fixture()
    code, message = run_guard()
    clear_fixtures()
    REGISTRY.write_bytes(original)
    if code == 0:
        print("CONTROL FAILED: the fixture is accepted without the registry "
              "row, so the row does no work")
        return 1
    print("control: without the row, the fixture is rejected - the row is "
          "load-bearing\n")

    for name, mutate, with_fixture, expected in REGISTRY_CASES:
        registry = json.loads(original.decode("utf-8"))
        mutate(registry)
        REGISTRY.write_text(json.dumps(registry, indent=2), encoding="utf-8")
        if with_fixture:
            write_fixture()
        code, message = run_guard()
        clear_fixtures()
        REGISTRY.write_bytes(original)
        ok = code != 0 and expected in message
        failures += 0 if ok else 1
        print(f"[{'PASS' if ok else 'FAIL'}] {name}", flush=True)
        if not ok:
            print(f"         expected: {expected}\n         got:      {message[:200]}")

    if REGISTRY.read_bytes() != original:
        print("CONTROL FAILED: the registry was not restored byte-exactly")
        return 1

    for name, source, target, expected in TREE_CASES:
        write_fixture(source, target)
        code, message = run_guard()
        clear_fixtures()
        ok = code != 0 and expected in message
        failures += 0 if ok else 1
        print(f"[{'PASS' if ok else 'FAIL'}] {name}", flush=True)
        if not ok:
            print(f"         expected: {expected}\n         got:      {message[:200]}")

    code, message = run_guard()
    if code != 0:
        print(f"\nCONTROL FAILED: tree not restored\n  {message}")
        return 1

    total = len(REGISTRY_CASES) + len(TREE_CASES)
    print(f"\n{total - failures}/{total} inversions rejected as required")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
