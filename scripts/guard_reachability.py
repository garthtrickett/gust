#!/usr/bin/env python3
"""Find guard recipes that nothing in CI can reach.

A `guard-*` recipe that no workflow runs looks like coverage and provides none.
This repository has hit that shape repeatedly, so the check is mechanical here
rather than a thing anyone has to remember.

The justfile is not one file: it `import`s several fragments, and recipes and
`just` calls in those fragments count exactly the same as ones in the root.

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

IMPORT = re.compile(r"^\s*import\s+\??\s*['\"]([^'\"]+)['\"]", re.M)
RECIPE_HEAD = re.compile(r"^([a-zA-Z0-9_-]+)([^:]*):(.*)$")
JUST_CALL = re.compile(r"just\s+(?:--\S+\s+)*([a-zA-Z0-9_-]+)")
NAME = re.compile(r"[a-zA-Z0-9_-]+")


def justfile_sources(path, seen=None):
    """The root justfile plus every fragment it imports, transitively.

    `just` merges imports into one namespace, so a recipe defined in a fragment
    and a `just other-recipe` call written inside one are indistinguishable from
    the same thing in the root file. Reading only the root invents orphans.
    """
    seen = seen if seen is not None else []
    path = path.resolve()
    if path in [p.resolve() for p in seen] or not path.exists():
        return []
    seen.append(path)
    text = path.read_text()
    out = [text]
    for match in IMPORT.finditer(text):
        out.extend(justfile_sources(path.parent / match.group(1), seen))
    return out


def parse_justfile(text):
    """Return ({recipe: [recipes it reaches]}, {recipes that take parameters})."""
    edges = {}
    bodies = {}
    parameterised = set()
    current = None
    for line in text.split("\n"):
        if line[:1] in (" ", "\t"):
            if current:
                bodies[current].append(line)
            continue
        if line.startswith("#") or not line.strip() or ":=" in line:
            continue
        match = RECIPE_HEAD.match(line)
        if not match:
            continue
        current = match.group(1)
        # `name args:` declares parameters; `name: dep dep` declares dependencies.
        if match.group(2).strip():
            parameterised.add(current)
        edges[current] = [d for d in match.group(3).split() if NAME.fullmatch(d)]
        bodies[current] = []
    # A recipe may also shell out to `just other-recipe`, which is an edge too.
    for recipe, body in bodies.items():
        for call in JUST_CALL.finditer("\n".join(body)):
            if call.group(1) in edges:
                edges[recipe].append(call.group(1))
    return edges, parameterised


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

    edges, parameterised = parse_justfile("\n".join(justfile_sources(JUSTFILE)))
    # A recipe that takes arguments cannot be a gate on its own -- something has
    # to supply the arguments -- so only argument-free recipes are checked.
    guards = {r for r in edges if r.startswith("guard-") and r not in parameterised}
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
