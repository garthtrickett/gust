#!/usr/bin/env python3
"""No tracked file may require a retired `--backend` spelling to stay present.

Patch 24.13 removes the explicit C backend selection. The retirement inventory
enumerates *where* the retired spelling appears; nothing enumerated *what
asserts it must keep appearing*, and those are different populations. This is
the second one, and it is derived rather than listed on purpose: two
independent enumerations of it disagreed, so any list would bake in whichever
one is wrong. A derived check fails on a pinning site nobody has seen yet.

Polarity is read off the comparison node, not guessed from nearby words. An
assertion that the spelling is *absent* is made more true by 24.13 and is not
a finding; an assertion that it is *present* is an obligation 24.13 must
invert.

Two states, selected by one registered fact rather than by a site list:

  before 24.13 lands  the pin set must be NON-EMPTY. An instrument that
                      reports zero because it stopped working looks exactly
                      like success, so the pre-landing state is what makes
                      the post-landing zero worth believing.
  after 24.13 lands   the pin set must be EMPTY.

Usage:
    python3 scripts/phase24_13_presence_pin_falsifier.py check
    python3 scripts/phase24_13_presence_pin_falsifier.py inventory
"""
from __future__ import annotations

import argparse
import ast
import importlib.util
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts" / "cranelift_feature_registry.json"

def _surviving_backends() -> set[str]:
    """The backend names that outlive Patch 24.13.

    Deliberately the *survivor* list, not the retired list. Three reasons:

      - it is the over-approximation the brief asks for. Anything else spelled
        after `--backend` counts as retired, so a pinning site using a spelling
        nobody has written yet is caught without being named;
      - the registered retired-spelling authority
        (`phase24_retirement_consumer_inventory.BACKEND_SPELLING`) matches
        `--backend c` only before whitespace or end-of-line. It misses the two
        sites that write it before a backtick -- `phase22_postflip_
        qualification.py:95` and `phase24_retirement_consumer_inventory.py:486`
        -- so deferring to it here would inherit that undercount;
      - naming only survivors keeps the retired spelling out of this file, so
        it does not enrol itself in the Phase 23 text-surface manifest, whose
        predicate is content-based.

    `bootstrap-emitter` is the internal bootstrap-only entry Patch 24.11
    decided and Patch 24.13 lands; it is not reachable by ordinary `gust`.
    """
    return {"cranelift", "bootstrap-emitter"}


# `--backend <name>`, capturing the name up to the first shell/markup
# delimiter, so `--backend c` before a backtick or quote is still a hit.
_SELECTOR = re.compile(r"--backend[= ]+(?P<name>[^\s'\"`)\];,]+)")

# A value that is not a literal backend name -- a shell variable, or a flag.
# `./gust --backend "$route"` is an explicit selection whose value is chosen at
# run time; it is registered as such and is not a retired spelling.
_NOT_A_LITERAL = re.compile(r"[$({]|^-")


def retired_search(text: str):
    """The first match in `text` naming a backend Patch 24.13 retires."""
    surviving = _surviving_backends()
    for match in _SELECTOR.finditer(text):
        name = match.group("name")
        if _NOT_A_LITERAL.search(name):
            continue
        # A help-text enumeration such as `--backend <a|b|cranelift>` names
        # several backends at once; it is retired if any alternative in it is.
        parts = [part for part in re.split(r"[<>|/]", name) if part]
        if any(part not in surviving and
               re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]*", part)
               for part in parts):
            return match
    return None


# This repository's assertion helpers. `assert` statements are covered too.
ASSERT_NAMES = {"require", "require_token", "assert_true", "expect", "ensure"}

# `<assert> <pattern> ... || fail` in shell: the pattern must BE there.
SH_PRESENCE_FAIL = re.compile(r"\|\|\s*fail\b")
SH_NEGATED = re.compile(r"^\s*(?:if\s+)?!\s*(?:grep|rg)\b")
SH_MATCHER = re.compile(r"\b(?:grep|rg)\b")

# The landing signal. When 24.13 registers this node, the expected pin set
# flips from non-empty to empty. One registered fact, not a list of sites.
LANDED_KEY = "phase24_13_backend_selection_removal"


class Finding(Exception):
    pass


def fail(message: str) -> None:
    print(f"guard-cranelift-phase24-13-presence-pin-falsifier: {message}",
          file=sys.stderr)
    raise SystemExit(1)


def tracked_files() -> list[str]:
    out = subprocess.run(["git", "-C", str(ROOT), "ls-files", "-z"],
                         capture_output=True, check=True).stdout
    return [p for p in out.decode().split("\0")
            if p and "__pycache__" not in p]


def _retired_lines(node: ast.AST) -> list[int]:
    return sorted({
        n.lineno for n in ast.walk(node)
        if isinstance(n, ast.Constant) and isinstance(n.value, str)
        and retired_search(n.value)
    })


def _has_retired(node: ast.AST) -> bool:
    return bool(_retired_lines(node))


def _counts(node: ast.AST, carrier: str | None) -> bool:
    if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
            and node.func.attr == "count"):
        return False
    if carrier is None:
        return _has_retired(node)
    return any(isinstance(a, ast.Name) and a.id == carrier
               for a in node.args)


def polarity(cond: ast.AST, carrier: str | None = None) -> str:
    """presence | absence | unknown | none, read off the comparison shape.

    `carrier` names a variable standing in for the literal, so
    `for m in (<literals>,): require(m in text)` scores the same as an inline
    `require("<literal>" in text)`.
    """
    def mentions(node: ast.AST) -> bool:
        if carrier is None:
            return _has_retired(node)
        return any(isinstance(n, ast.Name) and n.id == carrier
                   for n in ast.walk(node))

    def walk(node: ast.AST, negated: bool) -> list[str]:
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.Not):
            return walk(node.operand, not negated)
        if isinstance(node, ast.BoolOp):
            out: list[str] = []
            for value in node.values:
                out += walk(value, negated)
            return out
        if isinstance(node, ast.Compare):
            out = []
            for op, comp in zip(node.ops, node.comparators):
                if not (mentions(node.left) or mentions(comp)):
                    continue
                if isinstance(op, ast.In):
                    out.append("absence" if negated else "presence")
                elif isinstance(op, ast.NotIn):
                    out.append("presence" if negated else "absence")
                elif _counts(node.left, carrier):
                    zero = isinstance(comp, ast.Constant) and comp.value == 0
                    if isinstance(op, (ast.Eq, ast.GtE, ast.Gt)):
                        verdict = "absence" if zero else "presence"
                    elif isinstance(op, (ast.Lt, ast.LtE)):
                        verdict = "absence" if zero else "unknown"
                    else:
                        verdict = "unknown"
                    out.append(("absence" if verdict == "presence" else
                                "presence" if verdict == "absence" else
                                verdict) if negated else verdict)
                elif isinstance(op, ast.Eq):
                    # `x == {<literal-carrying dict>}` -- an equality pin.
                    out.append("absence" if negated else "presence")
                else:
                    out.append("unknown")
            return out
        if carrier is None and _has_retired(node):
            return ["absence" if negated else "presence"]
        return []

    verdicts = set(walk(cond, False))
    if verdicts == {"presence"}:
        return "presence"
    if verdicts == {"absence"}:
        return "absence"
    if not verdicts:
        return "none"
    return "mixed"


def scan_python(rel: str, text: str) -> list[dict]:
    try:
        tree = ast.parse(text)
    except SyntaxError as exc:
        # A file that cannot be parsed is a file this check cannot clear. It
        # must not be skipped: a silent skip shrinks the pin set, which is
        # indistinguishable from the patch having done its job.
        raise Finding(f"{rel}: cannot be parsed, so its pins cannot be "
                      f"ruled out: {exc}") from exc

    tables: dict[str, ast.AST] = {}
    for stmt in tree.body:
        if isinstance(stmt, ast.Assign) and len(stmt.targets) == 1 \
                and isinstance(stmt.targets[0], ast.Name) \
                and isinstance(stmt.value, (ast.List, ast.Tuple, ast.Dict)):
            tables[stmt.targets[0].id] = stmt.value

    parents: dict[int, ast.AST] = {}
    for node in ast.walk(tree):
        for child in ast.iter_child_nodes(node):
            parents[id(child)] = node

    def loop_carried(node: ast.AST, cond: ast.AST):
        """Literals reaching `cond` through an enclosing `for`."""
        names = {n.id for n in ast.walk(cond) if isinstance(n, ast.Name)}
        out = []
        cur = node
        while id(cur) in parents:
            cur = parents[id(cur)]
            if not isinstance(cur, ast.For):
                continue
            iterable = cur.iter
            if isinstance(iterable, ast.Name) and iterable.id in tables:
                iterable = tables[iterable.id]
            bound = {n.id for n in ast.walk(cur.target)
                     if isinstance(n, ast.Name)}
            carriers = sorted(bound & names)
            if not carriers:
                continue
            for line in _retired_lines(iterable):
                out.append((carriers[0], line))
        return out

    found: dict[tuple[str, int], dict] = {}

    def record(line: int, pol: str, assert_line: int, how: str) -> None:
        key = (rel, line)
        rank = {"presence": 3, "absence": 2}
        prev = found.get(key)
        if prev is None or rank.get(pol, 1) > rank.get(prev["polarity"], 1):
            found[key] = dict(file=rel, line=line, polarity=pol,
                              assert_line=assert_line, how=how)

    # Carry the assertion node itself, not its line number. Re-finding the
    # node by `lineno` costs a full tree walk per assertion, which is
    # quadratic: `scripts/cranelift_registry.py` alone has 1181 `require`
    # calls over 55632 nodes, and that one file accounted for 65.7M of the
    # 77.2M node visits a whole run used to make.
    conditions: list[tuple[ast.AST, ast.AST, str]] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Assert):
            conditions.append((node, node.test, "assert"))
            continue
        if not isinstance(node, ast.Call) or not node.args:
            continue
        name = (node.func.id if isinstance(node.func, ast.Name)
                else node.func.attr if isinstance(node.func, ast.Attribute)
                else None)
        if name in ASSERT_NAMES:
            conditions.append((node, node.args[0], name))

    for node, cond, how in conditions:
        lineno = node.lineno
        for line in _retired_lines(cond):
            record(line, polarity(cond), lineno, how)
        for carrier, line in loop_carried(node, cond):
            record(line, polarity(cond, carrier), lineno, f"{how}/loop")

    return list(found.values())


def scan_shell(rel: str, text: str) -> list[dict]:
    out = []
    for i, line in enumerate(text.splitlines(), 1):
        if not retired_search(line) or not SH_MATCHER.search(line):
            continue
        if SH_NEGATED.search(line):
            pol = "absence"
        elif SH_PRESENCE_FAIL.search(line):
            pol = "presence"
        else:
            pol = "unknown"
        out.append(dict(file=rel, line=i, polarity=pol, assert_line=i,
                        how="sh"))
    return out


def presence_pins() -> tuple[list[dict], list[dict]]:
    """(presence pins, everything else that mentions a retired spelling)."""
    pins, others = [], []
    for rel in tracked_files():
        path = ROOT / rel
        if not path.is_file():
            continue
        if rel.endswith(".py"):
            scan = scan_python
        elif rel.endswith(".sh"):
            scan = scan_shell
        else:
            continue
        for site in scan(rel, path.read_text(encoding="utf-8",
                                             errors="replace")):
            (pins if site["polarity"] == "presence" else others).append(site)
    pins.sort(key=lambda s: (s["file"], s["line"]))
    others.sort(key=lambda s: (s["file"], s["line"]))
    return pins, others


def landed() -> bool:
    try:
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read the registry, so the 24.13 state is unknown: {exc}")
    return isinstance(registry.get(LANDED_KEY), dict)


def render(sites: list[dict]) -> str:
    by_file: dict[str, list[int]] = {}
    for site in sites:
        by_file.setdefault(site["file"], []).append(site["line"])
    return "\n".join(f"  {f}:{','.join(str(n) for n in sorted(set(v)))}"
                     for f, v in sorted(by_file.items()))


def check() -> int:
    try:
        pins, others = presence_pins()
    except Finding as exc:
        fail(str(exc))
    if landed():
        if pins:
            print(f"{len(pins)} site(s) still require a retired --backend "
                  f"spelling to be present after Patch 24.13:\n"
                  f"{render(pins)}\n\n"
                  f"Invert each one rather than deleting it: after 24.13 the "
                  f"surviving claim is that the explicit C selection is "
                  f"absent, and a deleted clause asserts nothing.",
                  file=sys.stderr)
            fail(f"{len(pins)} presence pin(s) survive Patch 24.13")
        print("ok: no tracked file requires a retired --backend spelling")
        return 0
    # Pre-landing. The instrument must be able to see something before a later
    # zero from it means anything.
    if not pins:
        fail("Patch 24.13 has not landed, yet this check finds zero presence "
             "pins. Before the removal the repository is full of them, so a "
             "zero here means the check stopped working, not that the work "
             "is done.")
    print(f"ok (pre-24.13): {len(pins)} presence pin(s) across "
          f"{len({s['file'] for s in pins})} file(s) await inversion; "
          f"{len(others)} non-presence mention(s) correctly excluded")
    return 0


def inventory() -> int:
    try:
        pins, others = presence_pins()
    except Finding as exc:
        fail(str(exc))
    print(json.dumps(dict(landed=landed(), presence=pins, other=others),
                     indent=2, sort_keys=True))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("check", "inventory"),
                        nargs="?", default="check")
    args = parser.parse_args()
    return check() if args.mode == "check" else inventory()


if __name__ == "__main__":
    raise SystemExit(main())
