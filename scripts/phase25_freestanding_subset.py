#!/usr/bin/env python3
"""Patch 25.3: the freestanding Gust subset the runtime must be written in.

D2's first obligation, and the one O3 assigned an owner. The runtime IS
`str`, `Vector`, `HashMap` and the arena, so runtime code cannot use them:
no `std.Concat`, no `std.Clone`, no `ctx[...]`. That subset -- raw pointers,
scalars, loops, `extern func` -- plausibly exists and is usable, but nothing
defined or enforced it, so a stray `std.Clone` in a runtime file would
compile and recurse.

ENFORCEMENT IS BY RELOCATION, NOT BY GREP. This matters more than the rule.
A guard that greps runtime `.gst` files for `std.Clone` is a name test
standing in for a behaviour test: it passes for anything aliased, spelled
differently, or reached one call deep. An object carrying a relocation
against a runtime export violated the subset however it was spelled. Same
mechanism D2's third obligation specifies for `os_ArenaAlloc`, so the two
guards are one technique applied twice.

The forbidden set is DERIVED from the runtime's own exports rather than
hardcoded, so a new runtime function is forbidden the moment it exists.
A hardcoded list would go stale silently, which is the defect #436's
`\\.a\\b` diagnosis and #445's rotted harness both were.

A `#[freestanding]` module attribute would be stronger -- it fails at
compile time with a good message instead of at guard time with a symbol
name -- but it is new language surface and therefore an OD-register
question for Phase 26. O3's rule is: derivable constraint is lane work, new
language surface escalates. This is derivable, so it stays here.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Where a Gust-authored runtime object would land once 25.5 starts moving
# files. Empty today; the guard says so rather than passing silently.
FREESTANDING_OBJECTS = ROOT / "build" / "phase25-freestanding"

# The captured name must allow MIXED CASE. A lowercase-only capture
# silently missed os_ArenaAlloc -- the single most important symbol in
# the forbidden set -- and this guard's own assertion caught it.
EXPORT_RE = re.compile(r'^[A-Za-z_][A-Za-z0-9_ *]*?\b([a-z_][A-Za-z0-9_]*)\s*\(', re.M)


def runtime_exports() -> set:
    """Every symbol the C runtime exports -- the set runtime code may not call."""
    found = set()
    for path in sorted((ROOT / "src" / "runtime").glob("*.c")):
        text = path.read_text(encoding="utf-8", errors="replace")
        found.update(EXPORT_RE.findall(text))
    return {s for s in found if s.startswith(("std_", "os_", "gust_"))}


def undefined_symbols(obj: Path) -> set:
    out = subprocess.run(["nm", "-u", str(obj)], capture_output=True, text=True)
    return {line.split()[-1] for line in out.stdout.splitlines() if line.strip()}


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"guard-cranelift-phase25-freestanding-subset: {message}")
        raise SystemExit(1)


def report() -> dict:
    objects = sorted(FREESTANDING_OBJECTS.glob("*.o")) if FREESTANDING_OBJECTS.is_dir() else []
    return {
        "version": "phase25_freestanding_subset_v1",
        "forbidden_symbols": sorted(runtime_exports()),
        "freestanding_objects": [p.name for p in objects],
        "violations": {
            p.name: sorted(undefined_symbols(p) & runtime_exports())
            for p in objects
        },
    }


def validate() -> None:
    record = report()
    forbidden = set(record["forbidden_symbols"])
    # The set must be derived and non-empty, or the guard forbids nothing.
    require(forbidden,
            "no runtime exports found in src/runtime/*.c, so the forbidden "
            "set is empty and this guard would pass anything. The derivation "
            "is broken, not the tree -- the runtime exports symbols today.")
    require("os_ArenaAlloc" in forbidden or "os_Arena_New" in forbidden,
            "the arena allocator is absent from the derived forbidden set; "
            f"got {sorted(forbidden)[:6]}... The derivation is matching the "
            "wrong thing.")
    offenders = {k: v for k, v in record["violations"].items() if v}
    require(not offenders,
            "freestanding runtime objects call the runtime they implement: "
            f"{offenders}. A runtime function that reaches os_ArenaAlloc or "
            "std_* recurses through the thing it is defining.")
    if not record["freestanding_objects"]:
        print("guard-cranelift-phase25-freestanding-subset: ok "
              f"({len(forbidden)} forbidden symbols derived). No freestanding "
              "objects exist yet -- 25.5 produces the first. This guard is "
              "armed and vacuous until then, deliberately and visibly.")
        return
    print("guard-cranelift-phase25-freestanding-subset: ok "
          f"({len(record['freestanding_objects'])} objects, "
          f"{len(forbidden)} forbidden symbols, no violations)")


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
