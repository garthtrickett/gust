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
import subprocess
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


QUOTED = re.compile(r"'[^']*'|\"[^\"]*\"")


def strip_quoted(line):
    """Blank out quoted spans so a searched-for name is not read as a call.

    Issue #390: `parse_justfile` matched `just <recipe>` anywhere in a body,
    including inside the *pattern* of an assertion that forbids or requires a
    call -- `rg -n -F 'just guard-x' "$body"` -- and inside bash arrays of
    expected tokens (`justfile:105-111`). Both are text about a call, not a
    call, and reading them as edges makes an orphan look reachable.

    Blanking quoted spans is sound here because no recipe invokes `just` from
    inside a quoted string: there is no `bash -c "just ..."` and no
    `xargs just` in any justfile source. A real call is always unquoted, and
    its quoted *arguments* (`just guard-x "{{shard}}"`) are untouched because
    only the argument span is blanked, not the call.
    """
    return QUOTED.sub(lambda m: " " * len(m.group(0)), line)


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
        for line in body:
            for call in JUST_CALL.finditer(strip_quoted(line)):
                if call.group(1) in edges:
                    edges[recipe].append(call.group(1))
    return edges, parameterised


def _recipe_bodies(text):
    """Recipe name -> body lines. Shared so the dispatch model and the call
    graph cannot drift apart; `parse_justfile`'s two-value signature is public
    (phase24_retirement_consumer_inventory.liveness unpacks it) and must not
    change to expose this."""
    bodies = {}
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
        bodies[current] = []
    return bodies


SINGLE_QUOTED = re.compile(r"'[^']*'")
DISPATCH = re.compile(r'just\s+"\$\{?(\w+)')
ARRAY_OPEN = re.compile(r"^\s*(\w+)=\(\s*$")
PY_SOURCE = re.compile(r"python3\s+(scripts/[A-Za-z0-9_.-]+\.py)\s+([a-z][a-z0-9-]*)")


def _run_name_source(script, subcommand):
    """Ask an authority script for the names it dispatches, or return None."""
    try:
        out = subprocess.run([sys.executable, script, subcommand],
                             capture_output=True, text=True, timeout=120,
                             cwd=str(ROOT))
    except (OSError, subprocess.SubprocessError):
        return None
    if out.returncode != 0:
        return None
    return [line.strip() for line in out.stdout.split("\n") if line.strip()]


def dynamic_edges(text, known):
    """Resolve `just "$var"` dispatch into real edges (issue #393).

    `parse_justfile` only sees literal `just <name>`, so every dynamically
    dispatched guard is invisible to it -- and `registry_named`'s substring
    match has been silently standing in for the missing model.

    Each dispatching body is resolved by unioning every name source it
    contains: literal bash arrays, and the output of any authority script it
    invokes (`cranelift_test_levels.py list-native`,
    `phase15/16/17_*.py individual-guards`). The union **over-approximates**:
    a body that filters its list through `rg` before dispatching gets edges to
    the unfiltered set. That is the safe direction for a reachability claim --
    it can only make a guard look live, never dead -- and it is recorded here
    rather than tuned away, because the filters are themselves computed.

    Raises if a body dispatches but offers no resolvable source. An
    unmodelled dispatch site must fail loudly rather than silently contribute
    nothing, which is exactly how #393 went unnoticed.
    """
    cache = {}
    extra = {}
    for recipe, body in _recipe_bodies(text).items():
        text = "\n".join(body)
        # Only single-quoted spans are blanked here, not all quoted spans:
        # a real dispatch *is* `just "$guard_recipe"` (double-quoted variable),
        # while the assertion that forbids one wraps the whole call in single
        # quotes (`rg -n -F 'just "$guard_recipe"'`, justfile:1834). Reusing
        # strip_quoted would blank the variable itself and resolve nothing --
        # it silently reported 0 dispatch sites when there are 7.
        targets = {m.group(1) for m in DISPATCH.finditer(SINGLE_QUOTED.sub(" ", text))}
        if not targets:
            continue
        names = set()
        in_array = False
        for line in body:
            if ARRAY_OPEN.match(line):
                in_array = True
                continue
            if in_array:
                if line.strip() == ")":
                    in_array = False
                elif NAME.fullmatch(line.strip()):
                    names.add(line.strip())
        for script, sub in PY_SOURCE.findall(text):
            key = (script, sub)
            if key not in cache:
                cache[key] = _run_name_source(script, sub)
            if cache[key]:
                names.update(cache[key])
        resolved = {n for n in names if n in known}
        if not resolved:
            raise SystemExit(
                f"guard_reachability: recipe {recipe!r} dispatches "
                f"`just \"${sorted(targets)[0]}\"` but no name source in its "
                f"body could be resolved. Issue #393: an unmodelled dispatch "
                f"site must fail here, not silently contribute no edges.")
        extra[recipe] = sorted(resolved)
    return extra


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


def selftest_quoted_is_not_a_call():
    """Fail if a searched-for name is read as a call edge again (issue #390).

    This asserts on `parse_justfile` directly rather than through the report,
    because the report cannot see the difference: every recipe this repair
    makes unreachable is currently absorbed by `registry_named`, so the
    aggregate output is byte-identical before and after the fix. Measured on
    `b7a028df`: reachable falls 591 -> 584 and the guard still prints
    "unreachable: 20 (20 known, 0 new)". Asserting here is the only place the
    correction is observable -- the two unsound parts cancel everywhere else,
    which is issue #395's mechanism and why #390 must not be judged by whether
    the summary moved.

    The fixture is synthetic on purpose: a live-justfile assertion would drift
    the moment a recipe is renamed, and start passing for the wrong reason.
    """
    sample = "\n".join([
        "guard-a:",
        "    just guard-real",
        "    rg -n -F 'just guard-forbidden' \"$body\"",
        "    tokens=( 'just guard-token' )",
        "    just guard-with-arg \"{{shard}}\"",
        "guard-real:",
        "guard-forbidden:",
        "guard-token:",
        "guard-with-arg:",
    ])
    edges, _ = parse_justfile(sample)
    reached = edges["guard-a"]
    if "guard-real" not in reached:
        raise SystemExit(
            "guard_reachability selftest: an unquoted `just` call stopped "
            "being an edge; the repair is over-broad")
    if "guard-with-arg" not in reached:
        raise SystemExit(
            "guard_reachability selftest: a call with a quoted argument "
            "stopped being an edge; only the argument may be blanked")
    if "guard-forbidden" in reached:
        raise SystemExit(
            "guard_reachability selftest: a name inside an rg pattern is "
            "being read as a call edge again (issue #390)")
    if "guard-token" in reached:
        raise SystemExit(
            "guard_reachability selftest: a name inside a quoted array token "
            "is being read as a call edge again (issue #390)")


def selftest_dispatch_is_modelled():
    """Fail if dynamic dispatch stops producing edges (issue #393).

    Asserts both directions on a synthetic fixture: a resolvable source must
    yield edges, and an unresolvable dispatch must raise rather than quietly
    contribute nothing -- silence is how #393 survived.
    """
    sample = "\n".join([
        "dispatcher:",
        "    guards=(",
        "      guard-alpha",
        "      guard-beta",
        "    )",
        "    for g in \"${guards[@]}\"; do",
        "      just \"$g\"",
        "    done",
        "guard-alpha:",
        "guard-beta:",
    ])
    edges, _ = parse_justfile(sample)
    resolved = dynamic_edges(sample, set(edges))
    if sorted(resolved.get("dispatcher", [])) != ["guard-alpha", "guard-beta"]:
        raise SystemExit(
            "guard_reachability selftest: dynamic dispatch is no longer "
            "resolved into edges (issue #393); got "
            f"{resolved.get('dispatcher')}")
    blind = "\n".join([
        "blind:",
        "    for g in \"${mystery[@]}\"; do",
        "      just \"$g\"",
        "    done",
        "guard-alpha:",
    ])
    blind_edges, _ = parse_justfile(blind)
    try:
        dynamic_edges(blind, set(blind_edges))
    except SystemExit:
        return
    raise SystemExit(
        "guard_reachability selftest: an unresolvable dispatch site no "
        "longer fails (issue #393); it must not silently contribute nothing")


def main():
    selftest_quoted_is_not_a_call()
    selftest_dispatch_is_modelled()
    parser = argparse.ArgumentParser()
    parser.add_argument("--list", action="store_true",
                        help="print the current orphans and exit 0")
    args = parser.parse_args()

    justfile_text = "\n".join(justfile_sources(JUSTFILE))
    edges, parameterised = parse_justfile(justfile_text)
    # Issue #393: fold dynamically dispatched guards into the graph. Without
    # this the graph is literal-call-only and `registry_named`'s substring
    # match stands in for the missing model -- two unsound parts cancelling.
    for recipe, dispatched in dynamic_edges(justfile_text, set(edges)).items():
        edges[recipe].extend(dispatched)
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
