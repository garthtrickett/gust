#!/usr/bin/env python3
"""Patch 25.9: removing gust_v4.c -- 66,002 lines, 81% of the tree's C.

D1: bootstrap from the previous release, with a published bridge binary
whose digest is committed as the fallback. The seed is DELETED, not
translated -- that is what makes A the ranked choice and why this is the
largest single reduction in the phase.

INVERT, DO NOT DELETE. Every assertion that referenced the seed must
assert its ABSENCE and, in the same breath, the presence of what replaced
it. An assertion that simply disappears says nothing, and four instances
of exactly that were found in one Phase 24 patch. So this guard checks
both halves: the seed is gone AND a release-based route exists that can
produce a compiler without it.

ORDERING THIS ENFORCES. Release 0 must be minted from the current
gust_v4.c BEFORE 25.10 deletes the emitter that can regenerate it. Get
that backwards and the chain has no entry point: no seed, no release, and
no way to build the compiler that would have produced either. The guard
refuses a tree where the seed is gone and no release exists.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEED = ROOT / "gust_v4.c"
MANIFEST = ROOT / "docs" / "RELEASE_MANIFEST.json"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"guard-cranelift-phase25-seed-cutover: {message}")
        raise SystemExit(1)


def releases() -> list:
    if not MANIFEST.is_file():
        return []
    return json.loads(MANIFEST.read_text(encoding="utf-8")).get("releases", [])


def report() -> dict:
    return {
        "version": "phase25_seed_cutover_v1",
        "seed_present": SEED.is_file(),
        "seed_lines": sum(1 for _ in SEED.open(encoding="utf-8",
                                               errors="replace"))
                      if SEED.is_file() else 0,
        "release_count": len(releases()),
        "replacement_route": "release artifact via GUST_BOOTSTRAP_SEED, "
                             "verified against the committed manifest",
    }


def validate() -> None:
    record = report()
    if record["seed_present"]:
        # Pre-cut-over. The only thing to enforce here is the ordering that
        # makes the cut-over survivable.
        print("guard-cranelift-phase25-seed-cutover: seed present "
              f"({record['seed_lines']} lines); cut-over not yet performed. "
              f"{record['release_count']} releases exist -- release 0 must "
              "be minted from this seed BEFORE 25.10 deletes the emitter "
              "that can regenerate it.")
        return
    # Post cut-over: the inverted assertion. Absence is only half of it.
    require(record["release_count"] > 0,
            "gust_v4.c is gone and NO release exists. The chain has no "
            "entry point: no seed, no release, and no way to build the "
            "compiler that would have produced either. Release 0 is minted "
            "before the seed is removed, not after.")
    print("guard-cranelift-phase25-seed-cutover: ok (seed absent, "
          f"{record['release_count']} releases provide the replacement "
          "route)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["report", "validate"])
    args = parser.parse_args()
    if args.command == "report":
        print(json.dumps(report(), indent=2, sort_keys=True))
    else:
        validate()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
