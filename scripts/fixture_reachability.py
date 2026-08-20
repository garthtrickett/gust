#!/usr/bin/env python3
"""Find test fixtures that nothing in CI compiles or runs.

Companion to guard_reachability.py. A guard recipe nothing reaches is one
problem; a fixture whose only referencing recipe is itself unreachable is the
same problem one level down, and it is easier to miss -- the fixture looks
covered because a recipe names it.

The trap this avoids: "referenced only from justfile" is NOT the same as "not
exercised". Most such fixtures are named by recipes that CI does reach. The
reference has to be resolved to its recipe, and that recipe's reachability
checked. Applying the loose test reports 51 fixtures here; the correct test
reports 7.
"""

import argparse
import json
import pathlib
import re
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from guard_reachability import (  # noqa: E402
    JUSTFILE,
    justfile_sources,
    parse_justfile,
    reachable,
    registry_named,
    workflow_roots,
)

ROOT = pathlib.Path(__file__).resolve().parent.parent
FIXTURES = "compiler/*_test_entry.gst"
ALLOWLIST = ROOT / "scripts" / "fixture_reachability_allowlist.json"
RECIPE_HEAD = re.compile(r"^([a-zA-Z0-9_-]+)([^:]*):(.*)$")


def recipes_mentioning(stem, sources):
    """Every recipe whose body names this fixture."""
    found = set()
    for text in sources:
        current = None
        for line in text.split("\n"):
            if line[:1] in (" ", "\t"):
                if current and stem in line:
                    found.add(current)
                continue
            if line.startswith("#") or not line.strip() or ":=" in line:
                continue
            match = RECIPE_HEAD.match(line)
            if match:
                current = match.group(1)
    return found


def unexercised():
    sources = justfile_sources(JUSTFILE)
    edges, _ = parse_justfile("\n".join(sources))
    live = reachable(edges, workflow_roots(edges)) | registry_named(set(edges))
    out = []
    for path in sorted(ROOT.glob(FIXTURES)):
        stem = path.stem
        # Anything outside the justfiles -- a test runner, a workflow, a script --
        # counts as exercising it, so only justfile-only fixtures are candidates.
        elsewhere = subprocess.run(
            ["git", "grep", "-l", "-F", stem], cwd=ROOT,
            capture_output=True, text=True).stdout.split()
        # This tool's own files must not count as evidence. The allowlist names
        # every fixture it records, so once it is committed -- and `git grep`
        # only sees tracked files -- each allowlisted fixture would look
        # exercised by the very file recording that it is not.
        elsewhere = [f for f in elsewhere
                     if not f.startswith("justfile")
                     and not pathlib.Path(f).name.startswith("fixture_reachability")]
        if elsewhere:
            continue
        owners = recipes_mentioning(stem, sources)
        if owners and not (owners & live):
            out.append((stem, sorted(owners)))
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()

    found = unexercised()
    if args.list:
        for stem, _ in found:
            print(stem)
        return 0

    allowed = json.loads(ALLOWLIST.read_text())["known_unexercised"] if ALLOWLIST.exists() else {}
    names = [s for s, _ in found]
    new = [s for s in names if s not in allowed]
    fixed = sorted(set(allowed) - set(names))

    print(f"fixtures compiled by nothing in CI: {len(names)} "
          f"({len(allowed)} known, {len(new)} new)")

    if new:
        print("\nNothing in CI compiles or runs these fixtures:")
        for stem, _ in found:
            if stem in new:
                print(f"  {stem}")
        return 1
    if fixed:
        print(f"\nNo longer unexercised. Remove from {ALLOWLIST.name}:")
        for stem in fixed:
            print(f"  {stem}")
        return 1
    print("\nNo newly unexercised fixtures.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
