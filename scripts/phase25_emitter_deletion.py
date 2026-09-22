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
# The sites that INVOKE the emitter: a command line that actually runs it.
#
# This was ("Makefile", "justfile", "compiler/test_runner_entry.gst") and that
# undercounted by four. The comment justifying the narrow scope was about
# ASSERTION sites -- guards naming the authority to check its presence -- and
# that justification is right, but it was applied to four files that genuinely
# invoke:
#
#   tests/test_runner.gst:125,163              ./gust --backend bootstrap-emitter
#   scripts/phase22_explicit_c_migration.sh    three invocations
#   scripts/phase25_runtime_strings_generated.sh:61
#   scripts/phase25_strings_gust_parity.sh:38
#
# The consequence was specific and bad: the symmetry assertion below says
# "the emitter is gone but N sites remain, so every caller is broken", and
# with a three-file scope it could not see four of the seven invoking files.
# Deleting the emitter would have reported zero remaining sites while four
# callers broke.
INVOKERS = (
    "Makefile",
    "justfile",
    "compiler/test_runner_entry.gst",
    "tests/test_runner.gst",
    "scripts/phase22_explicit_c_migration.sh",
    "scripts/phase25_runtime_strings_generated.sh",
    "scripts/phase25_strings_gust_parity.sh",
    # The #446 bridge entry: it ACCEPTS the spelling
    # (`std.str_eq(args[2], "bootstrap-emitter")`) and advertises it in its
    # usage string. An entry surface, not a subprocess caller, but it dies
    # with the emitter for the same reason test_runner_entry.gst does.
    "compiler/test_runner_bootstrap_bridge_entry.gst",
)
# Files that NAME the spelling without invoking it: guards asserting its
# presence or absence, docs, the seed, the registry, and this script. Listed
# rather than ignored so that the union below is a closed set -- a hardcoded
# invoker list drifts silently, and the whole defect above was a list that
# had drifted.
MENTIONS = (
    "GUST_LANE_STATE.md",
    "TASK.md",
    "docs/ONE_WAY_LEDGER.md",
    "docs/PHASE24_RETIREMENT_CONSUMER_INVENTORY.md",
    "docs/PHASE25_BOOTSTRAP_SEED_POLICY.md",
    "docs/PHASE25_ROADMAP.md",
    "gust_v4.c",
    "scripts/cranelift_feature_registry.json",
    "scripts/phase22_default_route_flip.py",
    "scripts/phase22_default_route_seed_convergence.py",
    "scripts/phase22_opening.py",
    "scripts/phase22_postflip_qualification.py",
    "scripts/phase23_production_release_audit.py",
    "scripts/phase24_3b_coordinate_retirement_inversions.py",
    "scripts/phase24_c_toolchain_provenance.py",
    "scripts/phase24_closure.py",
    "scripts/phase24_cr15_stdlib_guard_transition.py",
    "scripts/phase24_retirement_consumer_inventory.py",
    "scripts/phase25_emitter_deletion.py",
    # Found by the closed-set assertion below on its first run, which is the
    # point of it: my own enumeration had scoped `git grep` to Makefile,
    # justfile, scripts/*.sh, tests/*.gst and compiler/*.gst, so every one of
    # these was outside the search that produced the "23 sites in 10 files"
    # figure. All assert or describe the spelling; none invoke it.
    "docs/ISSUE_ROADMAP.md",
    "scripts/phase22_native_implicit_output.py",
    "scripts/phase24_filename_behavior_characterization.py",
    "scripts/phase24_historical_full_qualification.py",
    "scripts/phase25_closure.py",
)
CALLERS = INVOKERS
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
    # The set of files naming the spelling must be CLOSED. A hardcoded
    # invoker list is exactly what drifted before, and a drifted list fails
    # by undercounting -- silently, and in the direction that lets the
    # emitter be deleted with live callers still reaching for it. So any
    # tracked file that names the spelling and is in neither list fails
    # here, and has to be classified as invoking or merely naming it.
    tracked = subprocess.run(
        ["git", "grep", "-lE",
         "(GUST_BOOTSTRAP_EMITTER|--backend[= ]bootstrap-emitter|bootstrap-emitter)"],
        cwd=ROOT, capture_output=True, text=True, check=False).stdout.split()
    known = set(INVOKERS) | set(MENTIONS)
    unclassified = sorted(set(tracked) - known)
    require(not unclassified,
            "files name the bootstrap-emitter spelling but are classified "
            f"neither as invokers nor as mentions: {unclassified}. Decide "
            "which it is -- an unclassified invoker is a caller this guard "
            "cannot see, which is how the census undercounted by four.")
    departed = sorted(f for f in known
                      if f not in tracked and (ROOT / f).is_file())
    require(not departed,
            f"registered emitter sites no longer name the spelling: {departed}. "
            "Remove them from INVOKERS/MENTIONS in the same patch, so the "
            "lists cannot keep asserting a population that has moved.")
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
