#!/usr/bin/env python3
"""Patch 25.10: the emitter and its bootstrap entry go TOGETHER.

D5. `compiler/codegen.gst` carries the emitter; `--backend
bootstrap-emitter` and the `GUST_BOOTSTRAP_EMITTER` authority are how
anything reaches it. They exist only for each other:

  * an entry with no emitter is dead machinery;
  * an emitter no entry can reach is the dead code #424 was filed about.

So this guard's assertion is SYMMETRY, not absence. Removing one without
the other is the failure mode, and it is the plausible one -- deleting the
user-facing spelling feels like progress while leaving 4,765 lines of
unreachable emitter behind.

It also enforces the ordering 25.9 depends on from the other side: the
emitter may not go while gust_v4.c is still the bootstrap entry point,
because the emitter is what regenerates it. Release 0 first, then the
seed, then this.
"""
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENTRY_SPELLING = "bootstrap-emitter"
AUTHORITY = "GUST_BOOTSTRAP_EMITTER"
CALLERS = ("Makefile", "justfile", "compiler/test_runner_entry.gst")
# Scoped to CALLERS on purpose: these are the sites that INVOKE the emitter.
# The authority is named in other files too -- guards that assert its
# presence or absence, and this script -- and counting those would make the
# number move whenever a guard is edited.
MANIFEST = ROOT / "docs/RELEASE_MANIFEST.json"


def releases() -> list:
    if not MANIFEST.is_file():
        return []
    return json.loads(MANIFEST.read_text(encoding="utf-8")).get("releases", [])


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"guard-cranelift-phase25-emitter-deletion: {message}")
        raise SystemExit(1)


def count(needle: str, path: str) -> int:
    target = ROOT / path
    if not target.is_file():
        return 0
    return target.read_text(encoding="utf-8", errors="replace").count(needle)


def emitter_present() -> bool:
    """The emitter itself, not the spelling that reaches it."""
    out = subprocess.run(
        ["grep", "-c", "codegen_generate", str(ROOT / "compiler" / "codegen.gst")],
        capture_output=True, text=True)
    return out.returncode == 0 and int(out.stdout.strip() or 0) > 0


def report() -> dict:
    entry = {p: count(ENTRY_SPELLING, p) for p in CALLERS}
    return {
        "version": "phase25_emitter_deletion_v1",
        "emitter_present": emitter_present(),
        "entry_spelling_sites": entry,
        "entry_total": sum(entry.values()),
        "authority_sites": sum(count(AUTHORITY, p) for p in CALLERS),
        "seed_present": (ROOT / "gust_v4.c").is_file(),
        "release_count": len(releases()),
    }


def validate() -> None:
    r = report()
    # The symmetry assertion. Either both are here or both are gone.
    require(not (r["emitter_present"] and r["entry_total"] == 0),
            "the emitter is still in compiler/codegen.gst but nothing "
            "reaches it: no bootstrap-emitter spelling remains. That is "
            "the dead code #424 was filed about -- delete the emitter in "
            "the same patch that removed its entry.")
    require(not (not r["emitter_present"] and r["entry_total"] > 0),
            f"{r['entry_total']} bootstrap-emitter sites remain but the "
            "emitter is gone. An entry with no emitter is dead machinery "
            "and every caller is now broken.")
    # The AUTHORITY is the other half of the entry and was counted but
    # never asserted. `--backend bootstrap-emitter` is the spelling; the
    # GUST_BOOTSTRAP_EMITTER environment variable is what the callers set
    # to reach the same code. Deleting one and leaving the other passed
    # this guard, which made "both or neither" true of only one of them.
    require(not (r["emitter_present"] and r["authority_sites"] == 0),
            "the emitter is still in compiler/codegen.gst but no caller "
            "sets GUST_BOOTSTRAP_EMITTER. The authority is half the entry "
            "and it went without the emitter.")
    require(not (not r["emitter_present"] and r["authority_sites"] > 0),
            f"{r['authority_sites']} GUST_BOOTSTRAP_EMITTER references "
            "remain but the emitter is gone. Every one of them now names "
            "an authority over code that does not exist.")
    if not r["emitter_present"]:
        # 25.9's ordering, enforced from this side. The emitter is what
        # regenerates gust_v4.c, so deleting it without a release having
        # been minted leaves no way to produce a seed ever again.
        #
        # This replaces `require(r["seed_present"] or True, "")`, which was
        # a tautology with an empty message: it could not fail, and it
        # occupied the place where the ordering check was supposed to be.
        require(r["release_count"] > 0,
                "the emitter is gone and NO release exists. The emitter is "
                "what regenerates gust_v4.c, so this order leaves no route "
                "to a seed at all. Patch 25.9 mints release 0 first; that "
                "is not a convention, it is the only entry point left.")
        print("guard-cranelift-phase25-emitter-deletion: ok (emitter, entry "
              f"and authority all removed; {r['release_count']} releases "
              "provide the bootstrap route)")
        return
    print("guard-cranelift-phase25-emitter-deletion: emitter present with "
          f"{r['entry_total']} entry sites across "
          f"{len([p for p,c in r['entry_spelling_sites'].items() if c])} "
          f"files, {r['authority_sites']} authority references. Deletion "
          "waits on 25.9: the emitter is what regenerates gust_v4.c, so "
          "release 0 and the seed cut-over come first.")


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
