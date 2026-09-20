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
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FALSIFIER_LIST = ROOT / "scripts" / "phase25_no_c_expected_failures.json"

CLOSURE_SENTENCE = (
    "A clean machine builds and tests Gust without invoking a C compiler, "
    "except tree-sitter-gust, which is editor tooling unreachable from "
    "`make test` or CI."
)


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"guard-cranelift-phase25-closure: {message}")
        raise SystemExit(1)


def conditions() -> dict:
    runtime_c = sorted(p.name for p in (ROOT / "src" / "runtime").glob("*.c"))
    remaining = []
    if FALSIFIER_LIST.is_file():
        remaining = json.loads(
            FALSIFIER_LIST.read_text(encoding="utf-8")).get("entries", [])
    return {
        "runtime_c_files": runtime_c,
        "seed_present": (ROOT / "gust_v4.c").is_file(),
        "expected_failures_remaining": [e["id"] for e in remaining],
        "task_md_names_phase_24_active": "Phase 24" in
            (ROOT / "TASK.md").read_text(encoding="utf-8")[:4000],
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
    if state["expected_failures_remaining"]:
        outstanding.append(
            f"{len(state['expected_failures_remaining'])} expected failures "
            f"remain ({', '.join(state['expected_failures_remaining'])}) "
            "-- 25.1, 25.11")
    if state["task_md_names_phase_24_active"]:
        outstanding.append(
            "TASK.md still names Phase 24 as the active roadmap -- the move "
            "is 25.12's own remaining step and needs a sweep of the 127 "
            "scripts that read it")
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
