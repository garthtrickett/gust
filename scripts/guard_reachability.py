#!/usr/bin/env python3
"""Find guard recipes that nothing in CI can reach.

A `guard-*` recipe that no workflow runs looks like coverage and provides none.
This repository has hit that shape repeatedly, so the check is mechanical here
rather than a thing anyone has to remember.

Reachability has three sources and all three matter. Counting only the first
reports far too many orphans:

  1. `just <recipe>` written literally in a workflow, plus everything that
     recipe pulls in -- its dependency list and any `just <other>` in its body.
  2. The same, transitively.
  3. Names carried in the registries that generate CI families, which dispatch
     guards without ever naming them in YAML.
"""

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
JUSTFILE = ROOT / "justfile"
WORKFLOWS = ROOT / ".github" / "workflows"
REGISTRIES = (
    ROOT / "scripts" / "cranelift_feature_registry.json",
    ROOT / "scripts" / "cranelift_test_levels.json",
)
ALLOWLIST = ROOT / "scripts" / "guard_reachability_allowlist.json"

RECIPE_HEAD = re.compile(r"^([a-zA-Z0-9_-]+)\s*(?:\+?[a-zA-Z0-9_=\"'\s]*)?:(.*)$")
JUST_CALL = re.compile(r"just\s+(?:--\S+\s+)*([a-zA-Z0-9_-]+)")
NAME = re.compile(r"[a-zA-Z0-9_-]+")


def parse_justfile(text):
    """Return {recipe: [recipes it can reach directly]}."""
    edges = {}
    bodies = {}
    current = None
    for line in text.split("\n"):
        if line[:1] in (" ", "\t"):
            if current:
                bodies[current].append(line)
            continue
        if line.startswith("#") or not line.strip():
            continue
        match = RECIPE_HEAD.match(line)
        if not match:
            continue
        current = match.group(1)
        edges[current] = [d for d in match.group(2).split() if NAME.fullmatch(d)]
        bodies[current] = []
    # A recipe may also shell out to `just other-recipe`, which is an edge too.
    for recipe, body in bodies.items():
        for call in JUST_CALL.finditer("\n".join(body)):
            if call.group(1) in edges:
                edges[recipe].append(call.group(1))
    return edges


def workflow_roots(edges):
    roots = set()
    for path in sorted(WORKFLOWS.glob("*.y*ml")):
        for call in JUST_CALL.finditer(path.read_text()):
            if call.group(1) in edges:
                roots.add(call.group(1))
    return roots


def reachable(edges, roots):
    seen = set()
    stack = list(roots)
    while stack:
        recipe = stack.pop()
        if recipe in seen:
            continue
        seen.add(recipe)
        stack.extend(edges.get(recipe, []))
    return seen


def registry_named(names):
    """Names a registry mentions. Substring matching is deliberate: the
    registries embed guard names inside larger command strings."""
    blobs = [p.read_text() for p in REGISTRIES if p.exists()]
    return {n for n in names if any(n in blob for blob in blobs)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--list", action="store_true",
                        help="print the current orphans and exit 0")
    args = parser.parse_args()

    edges = parse_justfile(JUSTFILE.read_text())
    guards = {r for r in edges if r.startswith("guard-")}
    seen = reachable(edges, workflow_roots(edges))
    unreached = guards - seen
    orphans = sorted(unreached - registry_named(unreached))

    if args.list:
        for name in orphans:
            print(name)
        return 0

    allowed = json.loads(ALLOWLIST.read_text())["known_unreachable"] if ALLOWLIST.exists() else {}
    new = [o for o in orphans if o not in allowed]
    fixed = sorted(set(allowed) - set(orphans))

    print(f"guard recipes: {len(guards)}")
    print(f"reachable from a workflow: {len(guards & seen)}")
    print(f"named in a CI-family registry: {len(unreached) - len(orphans)}")
    print(f"unreachable: {len(orphans)} ({len(allowed)} known, {len(new)} new)")

    if new:
        print("\nThese guard recipes are reachable from nothing:")
        for name in new:
            print(f"  {name}")
        print("\nWire each into a workflow or a CI-family registry, or delete it.")
        print("A guard nothing runs is not coverage.")
        return 1

    if fixed:
        print("\nThese are no longer unreachable. Remove them from")
        print(f"{ALLOWLIST.relative_to(ROOT)} so the ratchet keeps tightening:")
        for name in fixed:
            print(f"  {name}")
        return 1

    print("\nNo new unreachable guard recipes.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
