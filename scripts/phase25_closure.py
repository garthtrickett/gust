#!/usr/bin/env python3
"""Patch 25.12: Phase 25's closure contract, written before it can be met.

The exit gate is that a clean machine builds and tests Gust without
invoking a C compiler. This encodes what that does and does not claim, and
refuses to let the phase close on a sentence wider than the evidence.

Phase 24 closed on "28 registered live-C cases" -- accurate about the
registers and incomplete about the tree -- and #398, #422, #424 and #451
each found something it missed. The remedy is not a better register; it is
a closure sentence whose every clause has a falsifier that runs.

WHAT THE SENTENCE MAY CLAIM

  A clean machine builds and tests Gust without invoking a C compiler,
  EXCEPT tree-sitter-gust, which is editor tooling unreachable from
  `make test` or CI (Patch 25.0).

Not "the repository contains no C". That would be false while
`tree-sitter-gust/src/parser.c` exists, and stating the exception is the
difference between a closure and an oversight.

WHAT MUST HOLD FIRST, each with a guard rather than a claim:

  * src/runtime/ has no .c files          (25.5, 25.6)
  * gust_v4.c is absent                   (25.9)
  * the emitter and its entry are gone    (25.10)
  * the no-C falsifier list is empty      (25.1, 25.11)

THE TASK.md MOVE IS A SEPARATE STEP AND IS NOT DONE HERE. 127 scripts read
TASK.md and several assert an immutable Phase N record; moving the
active-roadmap pointer needs its own patch and a full sweep. This guard
records the obligation and fails closure while it is outstanding, so the
phase cannot close by forgetting it.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FALSIFIER_LIST = ROOT / "scripts" / "phase25_no_c_expected_failures.json"

# 25.10 deletes the emitter. Closure asserted its absence nowhere, so the
# guard could have printed "all conditions met" with the C emitter still
# reachable. These are the two spellings that make it reachable; both are
# live in the tree today (27 and 13 tracked files).
EMITTER_MARKERS = ("bootstrap-emitter", "GUST_BOOTSTRAP_EMITTER")

# Patch 25.12b names the SECOND exception, on this file's own principle:
# stating the exception is the difference between a closure and an oversight.
#
# The C-free route is the MUSL one, and that was never a late discovery --
# Patch 25.11 measured it and the docs say "everything else is proved on
# musl only". On gnu there is no C-free link at all: gnu + rust-lld fails
# with -lc -lm -ldl -lpthread -lrt -lutil -lgcc_s unfound, and cargo links
# build scripts for the HOST regardless of --target, so a gnu host reaches
# for cc before anything of Gust's is linked. O6 keeps the user default on
# the host target and P10 makes a no-C gnu host ERROR naming musl rather
# than silently hand back a static binary with a broken dlopen.
#
# An unqualified sentence would be the oversight this file exists to avoid:
# it would read as "Gust needs no C compiler anywhere", which is false on
# the platform most users are on.
CLOSURE_SENTENCE = (
    "On the musl route, a clean machine builds and tests Gust without "
    "invoking a C compiler, except tree-sitter-gust, which is editor "
    "tooling unreachable from `make test` or CI. On a gnu host the link "
    "still goes through a C driver: no C-free link exists there, and the "
    "user default stays the host target by design (O6/P10)."
)


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"guard-cranelift-phase25-closure: {message}")
        raise SystemExit(1)


def _emitter_deletion_report() -> dict:
    """The owning guard's own answer, rather than a second opinion.

    scripts/phase25_emitter_deletion.py is the instrument for this question.
    It already separates a CALLER from a file that merely names the spelling,
    via comment_occurrences(), refusal_probes() and registered_non_callers(),
    and it enumerates the whole tree as a CLOSED set so a file naming the
    spelling that nobody registered fails there rather than passing silently.
    Two instruments answering one question is how they drift into two
    answers; this asks the one that owns it.
    """
    spec = importlib.util.spec_from_file_location(
        "phase25_emitter_deletion", ROOT / "scripts" / "phase25_emitter_deletion.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.report()


def emitter_residue() -> list:
    """Tracked files still making the bootstrap emitter REACHABLE.

    Patch 25.12b: this was a substring match over every tracked file, and it
    counted PROSE. On main@27d0aa00 it reported 28 files, among them:

      * scripts/phase25_emitter_deletion.py -- the guard whose entire job is
        to assert the emitter is ABSENT;
      * scripts/phase22_explicit_c_migration.sh -- the refusal probe, which
        asks for the emitter in order to require the refusal;
      * scripts/cranelift_feature_registry.json -- the records of the
        DEPARTURE, including the departed invocations' own text;
      * six docs recording that the retirement happened.

    None of those makes the emitter reachable. The emitter is gone, and
    compiler/codegen.gst no longer defines its entry function at all --
    4,833 lines down to 207.

    That sentence deliberately does NOT spell the emitter's entry symbol.
    Doing so matched the `generated_c_contract` surface pattern and enrolled
    THIS FILE as a tracked text surface, which would have made a comment
    explaining a removal cost a registered successor block. Describe it;
    do not name it. The same trap, in its sixth form this phase.

    The old function already knew about this failure mode and fixed it for
    exactly one file -- itself, with the comment "the guard was detecting its
    own source". The defect was never specific to this file; it is what a
    content match does to any codebase that documents its own removals, and
    this phase has hit it five separate times. A closure condition that can
    only be satisfied by deleting the record of the change is the wrong
    condition.
    """
    report = _emitter_deletion_report()
    return sorted(path for path, count
                  in report["entry_spelling_sites"].items() if count)


def active_roadmap_phase() -> int:
    """The phase TASK.md declares active: the highest `# Phase N` heading.

    A substring test for "Phase 24" in the first 4,000 characters cannot
    distinguish the active declaration from the immutable Phase 24 record
    that must SURVIVE the move -- and the Phase 25 document being moved in
    mentions Phase 24 near its own beginning. That test would keep reporting
    Phase 24 active forever, blocking closure on prose placement.
    """
    text = (ROOT / "TASK.md").read_text(encoding="utf-8")
    phases = [int(m) for m in re.findall(r"^# Phase (\d+)", text, re.M)]
    return max(phases) if phases else 0


def conditions() -> dict:
    # rglob, not glob: a .c rehomed under src/runtime/rust/ is still runtime C,
    # and a top-level-only scan would report the condition satisfied.
    runtime_c = sorted(
        str(p.relative_to(ROOT / "src" / "runtime"))
        for p in (ROOT / "src" / "runtime").rglob("*.c"))
    # An ABSENT list is not an exhausted list, and the difference decides
    # closure: without this, deleting 25.1's falsifier would read exactly
    # like clearing it. Reported as an outstanding CONDITION rather than
    # raised, because this guard measures distance to closure and is
    # expected to run before 25.1 has landed the file.
    list_present = FALSIFIER_LIST.is_file()
    record = {}
    if list_present:
        record = json.loads(FALSIFIER_LIST.read_text(encoding="utf-8"))
        list_present = isinstance(record.get("entries"), list)
    return {
        "runtime_c_files": runtime_c,
        "seed_present": (ROOT / "gust_v4.c").is_file(),
        "falsifier_list_present": list_present,
        "expected_failures_remaining":
            [e["id"] for e in record.get("entries", [])],
        "emitter_residue": emitter_residue(),
        "active_roadmap_phase": active_roadmap_phase(),
    }


def validate() -> None:
    """Report distance to closure. Not an assertion that closure has happened."""
    state = conditions()
    outstanding = []
    if state["runtime_c_files"]:
        outstanding.append(
            f"{len(state['runtime_c_files'])} runtime .c files remain "
            f"({', '.join(state['runtime_c_files'])}) -- 25.5, 25.6")
    if state["seed_present"]:
        outstanding.append("gust_v4.c is present -- 25.9")
    if not state["falsifier_list_present"]:
        outstanding.append(
            f"{FALSIFIER_LIST.relative_to(ROOT)} is absent or has no "
            "`entries` list -- Patch 25.1's tracked falsifier is the "
            "evidence closure is measured against, and an absent list is "
            "not an exhausted one")
    if state["expected_failures_remaining"]:
        outstanding.append(
            f"{len(state['expected_failures_remaining'])} expected failures "
            f"remain ({', '.join(state['expected_failures_remaining'])}) "
            "-- 25.1, 25.11")
    if state["emitter_residue"]:
        outstanding.append(
            f"{len(state['emitter_residue'])} tracked files still reach the "
            f"bootstrap emitter ({', '.join(state['emitter_residue'][:3])}"
            f"{', ...' if len(state['emitter_residue']) > 3 else ''}) -- 25.10")
    if state["active_roadmap_phase"] < 25:
        outstanding.append(
            f"TASK.md declares Phase {state['active_roadmap_phase']} active, "
            "not Phase 25 -- the move is 25.12's own step and needs a sweep "
            "of the 127 scripts that read it")
    if outstanding:
        print("guard-cranelift-phase25-closure: NOT CLOSED. "
              f"{len(outstanding)} conditions outstanding:")
        for item in outstanding:
            print(f"  - {item}")
        print("  The closure sentence stays unwritten until each has a "
              "guard that passes, not an argument that it should.")
        return
    print("guard-cranelift-phase25-closure: all conditions met. The closure "
          f"sentence may now read:\n  {CLOSURE_SENTENCE}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["validate", "report"])
    args = parser.parse_args()
    if args.command == "report":
        print(json.dumps({"sentence": CLOSURE_SENTENCE, **conditions()},
                         indent=2, sort_keys=True))
    else:
        validate()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
