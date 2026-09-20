#!/usr/bin/env python3
"""Patch 25.2: what the native fixed point compares, and under what conditions.

D4 replaces `stage2.c == stage3.c` with a comparison of Cranelift-emitted
objects, because linking introduces ordering and layout the compiler does
not own -- comparing binaries would prove the linker deterministic rather
than the compiler self-reproducing. D4 named the idea and left three things
unstated, which O7 supplies and this patch fixes in code.

  1. THE ARTIFACT SET. The objects the compiler emits for compiler/*.gst --
     the compiler compiling itself. Not the runtime objects, whose
     reproducibility belongs to whatever toolchain builds them under D2 and
     D3, and not linked executables.

  2. PATHS ARE REMAPPED AT BUILD TIME, not stripped afterwards. Absolute
     paths enter objects through debug info and embedded source locations,
     and a fixed point that holds only inside one checkout directory is not
     the property D7 promises a third party. The prefix is a pinned
     constant, never derived from cwd: a remap computed from the working
     directory reproduces the nondeterminism it exists to remove while
     looking like it fixed it.

  3. EVERY EMITTED SECTION IS IN SCOPE, debug info included. Stripping
     would make the comparison pass more easily and hide exactly the class
     of nondeterminism most likely to be present. Cranelift emits no debug
     info today -- measured, see VACUOUS_TODAY -- so that clause is
     currently vacuous, and saying so here stops a passing comparison being
     read as evidence about debug determinism.

Patch 25.0 measured determinism itself: byte-identical across three runs and
from a different input path, for one fixture on one architecture. This patch
does not re-measure that; it fixes what the fixed point will compare.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Pinned. A build constant, never derived from cwd -- see (2) above.
REMAP_PREFIX = "/gust"

# Recorded so a green comparison is not misread. Patch 25.0 measured this:
# no debug_info, DWARF or debuginfo handling exists in the Cranelift driver.
VACUOUS_TODAY = ("debug_info_sections",)

ARTIFACT_SET = {
    "description": "objects the compiler emits for its own sources",
    "sources": "compiler/*.gst",
    "excludes": [
        "runtime objects -- built by the D2/D3 toolchain, not this compiler",
        "linked executables -- would prove the linker deterministic (D4)",
    ],
}


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"guard-cranelift-phase25-fixed-point-artifact-set: {message}")
        raise SystemExit(1)


def driver_emits_debug_info() -> bool:
    """The falsifier for VACUOUS_TODAY: the day debug info starts appearing."""
    driver = ROOT / "compiler" / "experiments" / "cranelift" / "src" / "main.rs"
    if not driver.is_file():
        return False
    text = driver.read_text(encoding="utf-8", errors="replace")
    return bool(re.search(r'debug_info|DWARF|debuginfo|emit_debug', text))


def driver_applies_remap() -> bool:
    """Whether a build-time path remap exists in the driver at all.

    Measured 2026-09-20: it does not. REMAP_PREFIX is a pinned constant that
    nothing applies, so validating its SHAPE says nothing about its effect --
    a well-formed constant is well-formed whether or not it is used.

    That is tolerable only because the remap is not needed yet. An object
    emitted through the native route was checked for the checkout path and
    contained none: the paths the remap exists to erase do not reach the
    artifact today, for the same reason VACUOUS_TODAY holds -- no debug info.

    So this is the remap clause's falsifier, and it is the mirror of the
    debug-info one. It fires when a remap APPEARS, because at that moment the
    prefix stops being inert: it must then be shown to be applied and the
    comparison must be exercised, not merely declared.
    """
    driver = ROOT / "compiler" / "experiments" / "cranelift" / "src" / "main.rs"
    if not driver.is_file():
        return False
    text = driver.read_text(encoding="utf-8", errors="replace")
    return bool(re.search(r'remap|prefix_map|path_prefix', text))


def compiler_sources() -> list:
    return sorted(p.name for p in (ROOT / "compiler").glob("*.gst"))


def report() -> dict:
    return {
        "version": "phase25_fixed_point_artifact_set_v1",
        "artifact_set": ARTIFACT_SET,
        "compiler_source_count": len(compiler_sources()),
        "remap_prefix": REMAP_PREFIX,
        "sections_in_scope": "all emitted sections, debug info included",
        "vacuous_today": list(VACUOUS_TODAY),
        "driver_emits_debug_info": driver_emits_debug_info(),
        "driver_applies_remap": driver_applies_remap(),
    }


def validate() -> None:
    record = report()
    require(record["compiler_source_count"] > 0,
            "no compiler/*.gst sources found; the artifact set is empty and "
            "the fixed point would compare nothing")
    require(REMAP_PREFIX.startswith("/") and "$" not in REMAP_PREFIX,
            f"remap prefix {REMAP_PREFIX!r} is not a pinned absolute "
            "constant; a prefix derived from the environment reproduces the "
            "nondeterminism it exists to remove")
    # Inverts: the day the driver emits debug info, the vacuity claim dies.
    require(not record["driver_emits_debug_info"],
            "the Cranelift driver now emits debug info, so "
            f"{list(VACUOUS_TODAY)} is no longer vacuous. The comparison "
            "already covers every emitted section, but this record said the "
            "clause was inert -- re-measure determinism WITH debug info "
            "before relying on the fixed point.")
    # Inverts: the day a remap exists, a pinned-but-unapplied prefix stops
    # being inert and starts being a claim this guard has not checked.
    require(not record["driver_applies_remap"],
            "the Cranelift driver now has a path remap, so REMAP_PREFIX is no "
            "longer an inert constant. Prove it is actually applied and "
            "exercise the two-build comparison -- validating the constant's "
            "shape was only defensible while nothing applied it.")
    print("guard-cranelift-phase25-fixed-point-artifact-set: ok "
          f"({record['compiler_source_count']} compiler sources, remap "
          f"{REMAP_PREFIX} declared but not yet applied, debug-info and remap clauses both vacuous today)")


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
