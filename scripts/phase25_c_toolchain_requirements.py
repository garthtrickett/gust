#!/usr/bin/env python3
"""Patch 25.0: what actually requires a C toolchain, measured from the tree.

Phase 24 closed on "28 registered live-C cases". The number was accurate
about the registers and incomplete about the tree -- #398 found four Stdlib
guards reaching the backend through `GUST_RUNNER_ROUTE`, #422 sixteen
emitters and ten `cc` consumers absent from the census, #451 three justfile
sites invisible because a line that both bound and invoked `CC_BIN` counted
only as a binding. So this enumeration derives from the tree and uses the
registers only as a cross-check.

It is deliberately category-by-category rather than one pattern. A single
regex over tracked files matches `as` and `cc` as substrings inside `.gst`
sources; refining it until the count looks plausible is how a tuned
heuristic gets mistaken for a measurement.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# `tree-sitter-gust` is excepted by name, not by silence. Measured in Patch
# 25.0: the Makefile's `test:` target is `test: gust require_just` and never
# names `test_tree_sitter`. Cited by content, not by line: Patch 25.4 inserted
# the runtime-rs rules above it and moved it from :262 to :272, which a line
# citation would have recorded as a silent falsehood.
# No workflow mentions tree-sitter; the only routes are
# `make test_tree_sitter` and a justfile recipe that passes `CC=cc` itself.
# Against D10's operational test it is optional, so the phase's closure
# sentence claims a C-free build and test of Gust, not a C-free repository.
EXCEPTED = {
    "tree-sitter-gust": "editor tooling; unreachable from `make test` or CI",
}


def make_cc_recipes() -> list:
    """Makefile lines that compile C with $(CC)."""
    text = (ROOT / "Makefile").read_text(encoding="utf-8")
    return [
        n for n, line in enumerate(text.splitlines(), 1)
        # Make command prefixes -- `@` silent, `-` ignore-errors, `+`
        # always-execute -- sit before the compiler reference. Requiring
        # $(CC) at the start missed Makefile:252's `@${CC} ...`, so this
        # reported 11 lines where the tree has 12. A miscount in the patch
        # whose whole purpose is measurement.
        if re.match(r'^\s*[-@+]*\s*\$[({]CC[)}]', line)
    ]


def tree_sitter_sites() -> list:
    """Every invocation of the tree-sitter CLI, which compiles parser.c."""
    out = []
    for name in ("Makefile", "justfile"):
        text = (ROOT / name).read_text(encoding="utf-8")
        for n, line in enumerate(text.splitlines(), 1):
            if re.search(r'tree-sitter\s+(test|parse|generate|build)', line):
                out.append(f"{name}:{n}")
    return out


def make_test_reaches_tree_sitter() -> bool:
    """The falsifier for the exception: if `make test` ever depends on it."""
    text = (ROOT / "Makefile").read_text(encoding="utf-8")
    # Prerequisites can be wrapped with a trailing backslash. Reading only
    # the first physical line would let `test: gust require_just \` followed
    # by `test_tree_sitter` run the grammar compiler while this reported the
    # exception intact.
    match = re.search(r'^test:((?:[^\n\\]|\\\n?)*)', text, re.MULTILINE)
    return bool(match) and "test_tree_sitter" in match.group(1)


def workflows_reach_tree_sitter() -> list:
    found = subprocess.run(
        # `make test_tree_sitter` contains no "tree-sitter" substring, so
        # searching only the hyphenated CLI name would miss a CI route to
        # the grammar compiler entirely.
        ["grep", "-rlE", "tree-sitter|test_tree_sitter",
         str(ROOT / ".github" / "workflows")],
        capture_output=True, text=True,
    ).stdout.split()
    return [Path(p).name for p in found]


def report() -> dict:
    return {
        "version": "phase25_c_toolchain_requirements_v1",
        "makefile_cc_recipe_lines": make_cc_recipes(),
        "tree_sitter_sites": tree_sitter_sites(),
        "excepted": EXCEPTED,
        "exception_falsifiers": {
            "make_test_depends_on_tree_sitter": make_test_reaches_tree_sitter(),
            "workflows_naming_tree_sitter": workflows_reach_tree_sitter(),
        },
    }


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"guard-cranelift-phase25-c-toolchain-requirements: {message}")
        raise SystemExit(1)


def validate() -> None:
    record = report()
    require(record["makefile_cc_recipe_lines"],
            "no $(CC) recipe lines found in the Makefile; the scan is broken, "
            "not the tree -- the bootstrap chain compiles C today")
    require(record["tree_sitter_sites"],
            "no tree-sitter sites found; the exception below describes "
            "something that is no longer there")
    # The exception inverts: it holds only while both falsifiers stay false.
    require(not record["exception_falsifiers"]["make_test_depends_on_tree_sitter"],
            "`make test` now depends on test_tree_sitter, so tree-sitter is "
            "no longer optional and Patch 25.0's exception is void")
    require(not record["exception_falsifiers"]["workflows_naming_tree_sitter"],
            "a workflow now names tree-sitter: "
            f"{record['exception_falsifiers']['workflows_naming_tree_sitter']}. "
            "The exception assumed no CI route; re-adjudicate before closure")
    print("guard-cranelift-phase25-c-toolchain-requirements: ok "
          f"({len(record['makefile_cc_recipe_lines'])} Makefile $(CC) lines, "
          f"{len(record['tree_sitter_sites'])} tree-sitter sites excepted)")


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
