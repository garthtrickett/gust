#!/usr/bin/env python3
"""Validate the CR-a MIR identity format ledger.

There is one definition of the `<kind>:v1(:<field>=<value>)*` identity
serialization - `mir_identity_begin` / `mir_identity_field` in
compiler/mir_layout.gst - and this guard forbids hand-rolling it anywhere else.

WHY THIS LEDGER IS NOT A CARVE-OUT, despite resembling one. A carve-out
relabels a failure for a named site, can be added to, records no target, and
states its exit criterion nowhere; that shape let one in
phase21_complete_guard_suite.py conceal that its population was exactly two.
This ledger has the three properties that one lacked:

  1. it can only SHRINK - current_sites must be a subset of previous_sites, so
     a new site can never be admitted to it;
  2. its contents are pinned EXACTLY against a live scan, so silent growth and
     unrecorded shrink both fail;
  3. zero is the recorded target, in this code rather than in a roadmap row.

Together those make it self-sealing: once the set reaches zero, the subset
assertion means it can never grow again. A migration ledger and a carve-out
have the same shape and opposite properties, and the difference is mechanical
rather than a matter of intent.

COUNT AGREEMENT IS NOT ENFORCEMENT. An earlier version of this detector matched
only a literal beginning with ":", which catches a continuation field but not
the opening form "<kind>:v1:<field>=". Every one of the 59 existing sites
carries a continuation literal, so that detector scanned clean, reported
exactly the expected 59, and enforced nothing against new code. A detector
validated against the corpus it was derived from will always match that corpus;
matching is evidence about the present and none at all about the future. Only
an inversion that constructs a site which does not yet exist can distinguish
the two, which is why one is in the suite for this guard.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
COMPILER = ROOT / "compiler"
GUARD = "guard-cranelift-phase24-identity-format-ledger"
# Fixtures, not builders. See scan_sites().
EXEMPT_SUFFIX = "_smoke_test_entry.gst"

# The hand-rolled form this patch retires. Two shapes, and BOTH are needed:
#
#   ":target="                 a continuation literal, colon-first
#   "aggregate_value:v1:id="   an OPENING literal, where the colon is mid-string
#
# An earlier version of this guard matched only the first and accepted a new
# single-field builder whose only literal is the opening form - the exact case
# the guard exists to reject. Every one of the 59 existing sites happens to
# carry a continuation literal, so the hole was invisible against the live
# corpus and only an inversion that added a new site exposed it.
STRING_LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')
FIELD_IN_LITERAL = re.compile(r":[A-Za-z_]+=")
VERSION_IN_LITERAL = re.compile(r":v[0-9]+")


def hand_rolls_identity(line: str) -> bool:
    for literal in STRING_LITERAL.findall(line):
        if FIELD_IN_LITERAL.search(literal) or VERSION_IN_LITERAL.search(literal):
            return True
    return False
FUNC = re.compile(r"^func\s+(\w+)\s*\(")


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def scan_sites() -> list[str]:
    """Every function in compiler/*.gst that hand-rolls a field literal.

    Keyed on file and function rather than on a name pattern. The population
    was originally scoped as "93 functions named *_identity*"; measured by
    format instead, it is 59, of which 25 are named *_id and would never have
    matched the name. The risk attaches to the format, so the scan does too.
    """
    sites: list[str] = []
    for path in sorted(COMPILER.glob("*.gst")):
        # Smoke-test entries are FIXTURES, and a fixture must state its
        # expectation literally rather than derive it from the code under test.
        # Several also hold deliberately malformed identities the builder could
        # not produce, e.g. "target:v1:triple=weird". Exempting them is a
        # property of what they are, not a concession to make the guard pass.
        if path.name.endswith(EXEMPT_SUFFIX):
            continue
        lines = path.read_text(encoding="utf-8").split("\n")
        owner: list[str | None] = [None] * len(lines)
        for index, line in enumerate(lines):
            match = FUNC.match(line)
            if not match:
                continue
            start = index
            while start < len(lines) and "{" not in lines[start]:
                start += 1
            depth = 0
            for cursor in range(start, len(lines)):
                depth += lines[cursor].count("{") - lines[cursor].count("}")
                owner[cursor] = match.group(1)
                if depth <= 0:
                    break
        for index, line in enumerate(lines):
            if not hand_rolls_identity(line):
                continue
            require(owner[index] is not None,
                    f"field literal outside any function: "
                    f"compiler/{path.name}:{index + 1}")
            site = f"compiler/{path.name}::{owner[index]}"
            if site not in sites:
                sites.append(site)
    return sorted(sites)


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    ledger = registry.get("phase24_identity_format_ledger")
    require(isinstance(ledger, dict), "identity format ledger is missing")
    require(ledger.get("contract_version") ==
            "phase24_identity_format_ledger_v1" and
            ledger.get("growth") == "rejected" and
            ledger.get("target_size") == 0 and
            bool(ledger.get("stage2_entry_obligation")),
            "identity format ledger contract drifted")

    definition = ledger["definition"]
    source = (ROOT / definition["path"]).read_text(encoding="utf-8")
    for name in (definition["begin"], definition["field"]):
        require(f"func {name}(" in source,
                f"the identity definition is missing: {name}")
    # The definition must not itself hand-roll the literal, or it would need an
    # exemption from the rule it exists to make enforceable.
    start = source.index(f"func {definition['begin']}(")
    end = source.index(f"func {definition['field']}(")
    end = source.index("\n}", end)
    require(not any(hand_rolls_identity(line)
                    for line in source[start:end].split("\n")),
            "the identity definition hand-rolls the literal it forbids")

    previous = ledger["previous_sites"]
    current = ledger["current_sites"]
    require(len(set(current)) == len(current) and
            len(set(previous)) == len(previous),
            "identity format ledger lists a site twice")
    # SHRINK-ONLY. This is the seal: a new site can never be admitted, and once
    # current is empty no site can ever be re-admitted.
    extra = sorted(set(current) - set(previous))
    require(not extra,
            "identity format ledger grew, which is never permitted: " +
            ", ".join(extra))
    require(len(current) <= len(previous),
            "identity format ledger size grew")

    live = scan_sites()
    unregistered = sorted(set(live) - set(current))
    require(not unregistered,
            "a hand-rolled MIR identity site is not in the ledger; use "
            f"{definition['begin']}/{definition['field']} instead: " +
            ", ".join(unregistered))
    stale = sorted(set(current) - set(live))
    require(not stale,
            "the ledger lists a site that no longer hand-rolls an identity; "
            "remove it in the patch that migrated it: " + ", ".join(stale))
    return {"remaining": len(live), "target": ledger["target_size"]}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate",))
    parser.parse_args()
    try:
        state = validate()
        print(f"identity format ledger: {state['remaining']} hand-rolled "
              f"sites remaining, target {state['target']}")
    except (Error, KeyError, ValueError) as error:
        print(f"{GUARD}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
