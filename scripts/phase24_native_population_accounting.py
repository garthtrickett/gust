"""Patch 24.15: account every retired `list-native` member against the #405 baseline.

Static and report-only.

Patch 24.17 qualifies one authoritative `Cranelift Historical Full` run, and
part of the population that run exercises is computed at run time: `just`
dispatches `python3 scripts/cranelift_test_levels.py list-native` at
justfile:276-280, and the historical workflow reaches it through the
phase9-core shard. Nothing in the level script or the workflow pins the
result -- the literal `88` occurs zero times in either.

That makes the population a moving target measured by the thing it gates.
Patches 24.15, 24.15a and 24.16 all retire level entries, and each retirement
shrinks the population 24.17's gate is measured over, so an unaccounted
removal makes that gate EASIER rather than failing it (#405).

This instrument pins the pre-retirement baseline as data and requires an
accounting for every departure from it:

  * a member that disappears without an entry here FAILS;
  * an entry naming a member that is still present FAILS, so the accounting
    cannot run ahead of the work or outlive it;
  * a member that appears from nowhere FAILS, because a population that can
    grow silently is not a baseline.

The direction matters. The failure mode #405 describes is a gate passing on a
smaller population than it was written for, which no amount of "did the run
succeed" checking detects.
"""

import argparse
import json
import hashlib
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TASK = ROOT / "TASK.md"
LEVELS = ROOT / "scripts" / "cranelift_test_levels.py"

GUARD = "guard-cranelift-phase24-native-population-accounting-contract"
VERSION = "phase24_native_population_accounting_v1"

# The commit the baseline was measured at: the Patch 24.12a merge, before any
# patch that retires a level entry had run.
BASELINE_COMMIT = "87231e50"
BASELINE_COUNT = 88
# Raised in review on #426: pinning only the COUNT lets a patch rename or
# replace a retired native guard in TASK.md, the justfile and the level policy
# while keeping 88 names. `expected` would then equal the rewritten live
# population and this guard would pass against a baseline that had silently
# moved -- the accounting would be true of a baseline nobody measured.
#
# The membership is pinned by digest over the sorted names, so a rename fails
# here and has to be accounted for rather than absorbed. Verified before
# pinning that the block is byte-identical to the one 24.15 introduced, so
# this locks the measured baseline and not a drifted one.
BASELINE_DIGEST = "231e5dace4c8b12003eba39a7494f0ce7d79aeff9167e73ae51ddaea918ace48"

# Every member this phase retires, with the patch that did it and why. Empty
# until a retirement lands; an entry here that is still in the population is
# itself a failure, so this cannot be filled in speculatively.
RETIRED_MEMBERS: dict[str, str] = {}


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD}: {message}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def baseline() -> set:
    """The 88 members, read from the roadmap block that records them.

    Read rather than duplicated: a copy in this file could drift from the
    roadmap's list, and then two documents would disagree about what the
    baseline was with no way to tell which is right.
    """
    text = TASK.read_text(encoding="utf-8")
    start = text.find("The 88 members, which 24.15, 24.15a and 24.16 may reduce")
    require(start != -1, "the #405 baseline block is missing from TASK.md")
    block = text[start:]
    fence = block.find("```text")
    require(fence != -1, "the #405 baseline block has no fenced member list")
    end = block.find("```", fence + len("```text"))
    require(end != -1, "the #405 baseline member list is unterminated")
    members = set(re.findall(r"guard-[a-z0-9-]+", block[fence:end]))
    require(
        len(members) == BASELINE_COUNT,
        f"the #405 baseline block lists {len(members)} members, not "
        f"{BASELINE_COUNT}. The baseline is measured at {BASELINE_COMMIT} and "
        "is not something a later patch may edit: reduce the live population "
        "and account for it here instead.",
    )
    digest = hashlib.sha256("\n".join(sorted(members)).encode("utf-8")).hexdigest()
    require(
        digest == BASELINE_DIGEST,
        "the #405 baseline members changed while the count held: a renamed or "
        "substituted member is still a moved baseline, and this accounting "
        f"would otherwise be true of a baseline nobody measured. Got {digest}, "
        f"pinned {BASELINE_DIGEST} at {BASELINE_COMMIT}.",
    )
    return members


def population() -> set:
    result = subprocess.run(
        ["python3", str(LEVELS), "list-native"],
        cwd=ROOT, capture_output=True, text=True, check=False,
    )
    require(result.returncode == 0,
            f"list-native failed: {result.stderr.strip()[:200]}")
    return {line.strip() for line in result.stdout.splitlines() if line.strip()}


def validate() -> dict:
    expected = baseline()
    live = population()

    appeared = sorted(live - expected)
    require(
        not appeared,
        f"members appeared that the #405 baseline does not contain: {appeared}. "
        "A population that grows silently is not a baseline, and Patch 24.17 "
        "qualifies its run against this one.",
    )

    gone = sorted(expected - live)
    unaccounted = [member for member in gone if member not in RETIRED_MEMBERS]
    require(
        not unaccounted,
        f"members left the native population with no accounting: {unaccounted}. "
        "Each retirement shrinks the population Patch 24.17's gate is measured "
        "over, so an unaccounted removal makes that gate easier rather than "
        "failing it (#405). Record it in RETIRED_MEMBERS with the patch and "
        "the reason.",
    )

    premature = sorted(member for member in RETIRED_MEMBERS if member in live)
    require(
        not premature,
        f"accounted as retired but still in the population: {premature}. The "
        "accounting may not run ahead of the work, or outlive it.",
    )

    stray = sorted(member for member in RETIRED_MEMBERS if member not in expected)
    require(
        not stray,
        f"accounted as retired but never in the baseline: {stray}.",
    )

    return {
        "version": VERSION,
        "baseline_commit": BASELINE_COMMIT,
        "baseline": len(expected),
        "live": len(live),
        "retired": len(gone),
        "accounted": {member: RETIRED_MEMBERS[member] for member in gone},
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["report", "validate"],
                        nargs="?", default="validate")
    arguments = parser.parse_args()
    if arguments.command == "report":
        print(json.dumps({"baseline": sorted(baseline()),
                          "live": sorted(population())}, indent=2))
        return
    print(json.dumps(validate(), indent=2, sort_keys=True))
    print(f"{GUARD}: ok")


if __name__ == "__main__":
    main()
