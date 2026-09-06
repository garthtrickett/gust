#!/usr/bin/env python3
"""Validate and project Patch 20.16c explicit-unsafe Mutex migration."""

from __future__ import annotations

import argparse
import importlib.util
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
CODEGEN = ROOT / "compiler/codegen.gst"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_UNSAFE_MUTEX_MIGRATION.md"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
JUSTFILE = ROOT / "justfile"
GUARD = "guard-cranelift-phase20-unsafe-mutex-migration-contract"
TOKEN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*|[{}().;]")


class Error(RuntimeError):
    pass


@dataclass(frozen=True)
class MethodCall:
    path: str
    line: int
    method: str
    explicit_unsafe: bool


@dataclass(frozen=True)
class Token:
    text: str
    line: int


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def mask_comments_and_literals(source: str) -> str:
    """Mask comments and literals while preserving newlines and token offsets."""
    result = list(source)
    index = 0
    while index < len(source):
        if source.startswith("//", index):
            end = source.find("\n", index)
            if end < 0:
                end = len(source)
            for pos in range(index, end):
                result[pos] = " "
            index = end
            continue
        if source.startswith("/*", index):
            end = source.find("*/", index + 2)
            require(end >= 0, "unterminated block comment in scanner input")
            end += 2
            for pos in range(index, end):
                if result[pos] != "\n":
                    result[pos] = " "
            index = end
            continue
        if source[index] in ('"', "'"):
            quote = source[index]
            pos = index
            escaped = False
            while pos < len(source):
                char = source[pos]
                if char != "\n":
                    result[pos] = " "
                if pos > index and char == quote and not escaped:
                    pos += 1
                    break
                if char == "\\" and not escaped:
                    escaped = True
                else:
                    escaped = False
                pos += 1
            require(pos <= len(source) and source[pos - 1] == quote,
                    "unterminated literal in scanner input")
            index = pos
            continue
        index += 1
    return "".join(result)


def tokens(source: str) -> list[Token]:
    masked = mask_comments_and_literals(source)
    result: list[Token] = []
    line = 1
    previous_end = 0
    for match in TOKEN.finditer(masked):
        line += masked.count("\n", previous_end, match.start())
        result.append(Token(match.group(0), line))
        previous_end = match.end()
    return result


def scan_source(path: str, source: str) -> list[MethodCall]:
    stream = tokens(source)
    unsafe_blocks: list[bool] = []
    pending_unsafe = False
    calls: list[MethodCall] = []
    for index, token in enumerate(stream):
        if (token.text == "." and index + 2 < len(stream) and
                stream[index + 1].text in ("Lock", "Unlock") and
                stream[index + 2].text == "("):
            calls.append(MethodCall(
                path=path,
                line=stream[index + 1].line,
                method=stream[index + 1].text,
                explicit_unsafe=unsafe_blocks[-1] if unsafe_blocks else False,
            ))
        if token.text == "unsafe":
            pending_unsafe = True
        elif token.text == "{":
            inherited = unsafe_blocks[-1] if unsafe_blocks else False
            unsafe_blocks.append(inherited or pending_unsafe)
            pending_unsafe = False
        elif token.text == "}":
            require(bool(unsafe_blocks),
                    f"unbalanced closing brace while scanning {path}:{token.line}")
            unsafe_blocks.pop()
            pending_unsafe = False
        elif token.text == ";":
            pending_unsafe = False
    require(not unsafe_blocks, f"unbalanced opening brace while scanning {path}")
    return calls


def scanner_self_test() -> None:
    witness = """
func safe_call() { mutex.Lock(); }
unsafe { mutex.Unlock(); }
  unsafe
  { mutex.Lock(); }
// unsafe { ignored.Lock(); }
mut text := "unsafe { ignored.Unlock(); }";
unsafe func internal_call() { mutex.Unlock(); }
"""
    calls = scan_source("<scanner-self-test>", witness)
    require([(call.method, call.explicit_unsafe) for call in calls] == [
        ("Lock", False),
        ("Unlock", True),
        ("Lock", True),
        ("Unlock", True),
    ], "lexical unsafe scanner self-test failed")


def tracked_gust_paths() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "-z", "--cached", "--others",
         "--exclude-standard", "--", "*.gst"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    )
    return sorted(
        item.decode("utf-8")
        for item in result.stdout.split(b"\0")
        if item
    )


def complete_inventory() -> list[MethodCall]:
    calls: list[MethodCall] = []
    for path in tracked_gust_paths():
        source = (ROOT / path).read_text(encoding="utf-8")
        calls.extend(scan_source(path, source))
    return calls


def s1_8_transition(registry: dict) -> tuple[dict, str] | None:
    opening = registry.get("phase24_cr15_opening", {})
    value = opening.get("stdlib_guard_transition")
    if not isinstance(value, dict) or not isinstance(
            value.get("s1_8_inventory_successor"), dict):
        return None
    path = ROOT / "scripts/phase24_cr15_stdlib_guard_transition.py"
    spec = importlib.util.spec_from_file_location(
        "phase24_s1_8_mutex_inventory_transition", path)
    require(spec is not None and spec.loader is not None,
            "cannot load the S1.8 inventory transition")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    successor = module.s1_8_successor(value)
    return successor, module.s1_8_state(value)


def s1_11_removal_successor(registry: dict) -> dict | None:
    """CR-21: the only successor in this chain that REMOVES call sites.

    Every predecessor adds one and computes current = previous + [added], so a
    migration that retires a transitional test had no mechanism at all. This is
    that mechanism, kept to the same shape: previous_* retains the pinned state
    so nothing is forgotten, and anything partial, extra or substituted rejects.
    """
    successor = registry.get("phase24_cr15_opening", {}).get(
        "stdlib_guard_transition", {}).get("s1_11_raw_mutex_removal_successor")
    if not isinstance(successor, dict):
        return None
    require(successor.get("contract_version") ==
            "phase24_s1_11_raw_mutex_removal_v1" and
            successor.get("partial_extra_or_substituted_call_site") ==
            "rejected" and
            successor.get("safe_raw_calls_added") == 0 and
            isinstance(successor.get("removed_call_site"), dict),
            "S1.11 raw Mutex removal successor drifted")
    removed = successor["removed_call_site"]
    require(sorted(removed) == ["lock_calls", "path", "role", "unlock_calls"],
            "S1.11 removed call site shape drifted")
    previous = successor["previous_totals"]
    current = successor["current_totals"]
    # The removal must account for exactly the removed site and nothing else,
    # so a hand-edited total cannot quietly retire a second file.
    require(current == {
        "lock_calls": previous["lock_calls"] - removed["lock_calls"],
        "unlock_calls": previous["unlock_calls"] - removed["unlock_calls"],
        "calls": previous["calls"] - removed["lock_calls"] -
        removed["unlock_calls"],
    }, "S1.11 removal totals do not account for exactly the removed site")
    require(removed["path"] in successor["previous_transitional_test_coverage"],
            "S1.11 removed a call site that was never transitional")
    require(successor["current_transitional_test_coverage"] ==
            [path for path in successor["previous_transitional_test_coverage"]
             if path != removed["path"]],
            "S1.11 transitional coverage does not drop exactly the migrated "
            "test")
    # Patch S1.10's without-guard baseline asserts 300 and must survive. An
    # empty transitional set would mean the baseline was migrated too.
    require(successor["current_transitional_test_coverage"],
            "S1.11 emptied the transitional raw Mutex set; the S1.10 baseline "
            "must remain")
    return successor


def validate() -> tuple[dict, list[MethodCall]]:
    scanner_self_test()
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    authority = registry.get("phase20_unsafe_mutex_migration")
    require(isinstance(authority, dict), "Patch 20.16c authority is missing")
    require(authority.get("contract_version") ==
            "phase20_unsafe_mutex_migration_v1",
            "Patch 20.16c contract version drifted")
    require(authority.get("status") == "patch20_16c_complete",
            "Patch 20.16c status drifted")
    require(authority.get("next_patch") == "20.16d",
            "Patch 20.16c successor drifted")
    require(authority.get("source_scope") ==
            "every_git_tracked_gust_source_file",
            "Patch 20.16c source scope drifted")
    require(authority.get("enforcement_enabled") is True,
            "Patch 20.16d successor enforcement state drifted")

    calls = complete_inventory()
    unsafe_failures = [call for call in calls if not call.explicit_unsafe]
    enforcement_negatives = set(authority.get(
        "enforcement_negative_fixtures", []))
    require({call.path for call in unsafe_failures} == enforcement_negatives and
            len(unsafe_failures) == 2,
            "raw Mutex-style method call outside explicit unsafe differs from "
            "the exact Patch 20.16d enforcement-negative fixtures: " +
            ", ".join(f"{call.path}:{call.line}:{call.method}"
                      for call in unsafe_failures))

    actual: dict[str, dict[str, int]] = {}
    for call in calls:
        counts = actual.setdefault(call.path, {"Lock": 0, "Unlock": 0})
        counts[call.method] += 1
    expected_call_sites = authority.get("call_sites", [])
    expected_total_lock_calls = authority.get("total_lock_calls")
    expected_total_unlock_calls = authority.get("total_unlock_calls")
    expected_total_calls = authority.get("total_calls")
    successor = registry.get("phase24_cr15_qualification", {}).get(
        "raw_mutex_call_site_transition")
    if successor is not None:
        require(
            successor.get("contract_version") ==
            "phase24_cr15_qualification_raw_mutex_transition_v1" and
            successor.get("status") == "patch24_0d_complete" and
            successor.get("authority_base_main") ==
            "2383096a741c62e8de103a5b79281b9f616eb805" and
            successor.get("previous_call_sites") == authority.get("call_sites") and
            successor.get("previous_totals") == {
                "lock_calls": authority.get("total_lock_calls"),
                "unlock_calls": authority.get("total_unlock_calls"),
                "calls": authority.get("total_calls"),
            } and
            successor.get("added_call_site") == {
                "path": "tests/phase24_cr15_qualification_module.gst",
                "role": "patch24_0d_spelling_substituted_metadata_fixture",
                "lock_calls": 1,
                "unlock_calls": 1,
            } and
            successor.get("current_call_sites") ==
            authority.get("call_sites") + [successor["added_call_site"]] and
            successor.get("current_totals") == {
                "lock_calls": 16, "unlock_calls": 16, "calls": 32,
            } and
            successor.get("baseline_calls_unchanged") == 24 and
            successor.get("partial_extra_or_substituted_call_site") == "rejected",
            "Patch 24.0d raw Mutex call-site successor drifted")
        expected_call_sites = successor["current_call_sites"]
        expected_total_lock_calls = successor["current_totals"]["lock_calls"]
        expected_total_unlock_calls = successor["current_totals"]["unlock_calls"]
        expected_total_calls = successor["current_totals"]["calls"]
    s1_8 = s1_8_transition(registry)
    if s1_8 is not None:
        s1_8_successor, s1_8_state = s1_8
        raw = s1_8_successor["raw_mutex_call_site_transition"]
        require(raw["previous_totals"] == {
            "lock_calls": expected_total_lock_calls,
            "unlock_calls": expected_total_unlock_calls,
            "calls": expected_total_calls,
        }, "S1.8 raw Mutex predecessor totals drifted")
        if s1_8_state == "post_s1_8":
            expected_call_sites = expected_call_sites + [raw["added_call_site"]]
            expected_total_lock_calls = raw["current_totals"]["lock_calls"]
            expected_total_unlock_calls = raw["current_totals"]["unlock_calls"]
            expected_total_calls = raw["current_totals"]["calls"]
    frozen_coverage = [
        "tests/e2e_mutex_concurrency.gst",
        "tests/e2e_sync_primitives.gst",
    ]
    expected_coverage = frozen_coverage
    s1_11 = s1_11_removal_successor(registry)
    if s1_11 is not None:
        removed = s1_11["removed_call_site"]
        require(s1_11["previous_totals"] == {
            "lock_calls": expected_total_lock_calls,
            "unlock_calls": expected_total_unlock_calls,
            "calls": expected_total_calls,
        }, "S1.11 raw Mutex predecessor totals drifted")
        require(s1_11["previous_transitional_test_coverage"] ==
                frozen_coverage,
                "S1.11 transitional predecessor coverage drifted")
        require(any(row["path"] == removed["path"] and
                    row["lock_calls"] == removed["lock_calls"] and
                    row["unlock_calls"] == removed["unlock_calls"]
                    for row in expected_call_sites),
                "S1.11 removed a call site the contract does not pin")
        # Two registered states, because the registry row lands in the
        # Cranelift patch and the source edit lands in the Stdlib patch. Main
        # is valid holding either; anything between them is drift.
        live_row = actual.get(removed["path"])
        pinned_row = {"Lock": removed["lock_calls"],
                      "Unlock": removed["unlock_calls"]}
        require(live_row == pinned_row or live_row is None,
                "S1.11 migrated raw Mutex site is partial or substituted: "
                f"{removed['path']}={live_row!r}")
        if live_row is None:
            expected_call_sites = [row for row in expected_call_sites
                                   if row["path"] != removed["path"]]
            expected_total_lock_calls = s1_11["current_totals"]["lock_calls"]
            expected_total_unlock_calls = \
                s1_11["current_totals"]["unlock_calls"]
            expected_total_calls = s1_11["current_totals"]["calls"]
            expected_coverage = s1_11["current_transitional_test_coverage"]
    expected = {
        row["path"]: {"Lock": row["lock_calls"],
                      "Unlock": row["unlock_calls"]}
        for row in expected_call_sites
    }
    require(actual == expected,
            f"raw Mutex call-site classification drifted: actual={actual!r}")
    lock_calls = sum(call.method == "Lock" for call in calls)
    unlock_calls = sum(call.method == "Unlock" for call in calls)
    require(authority.get("baseline_lock_calls") == 12 and
            authority.get("baseline_unlock_calls") == 12 and
            authority.get("baseline_calls") == 24,
            "Patch 20.16c frozen 24-call baseline drifted")
    require(lock_calls == expected_total_lock_calls,
            "raw Mutex Lock inventory drifted")
    require(unlock_calls == expected_total_unlock_calls,
            "raw Mutex Unlock inventory drifted")
    require(len(calls) == expected_total_calls,
            "raw Mutex total call inventory drifted")
    # The frozen authority record never changes; what a migration moves is the
    # EFFECTIVE set. Comparing the effective set against the live inventory is
    # what makes the removal mechanism non-optional: migrating a transitional
    # test without registering the removal leaves the effective set naming a
    # file that carries no raw calls, and that fails here.
    require(authority.get("transitional_test_coverage") == frozen_coverage,
            "transitional raw Mutex test classification drifted")
    require(expected_coverage ==
            [path for path in frozen_coverage if path in actual],
            "the effective transitional raw Mutex set does not match the live "
            "inventory; a transitional test was migrated without a registered "
            "removal, or a registered removal did not happen")

    typechecker = TYPECHECKER.read_text(encoding="utf-8")
    codegen = CODEGEN.read_text(encoding="utf-8")
    require("return make_type_pointer(val_t_lookup.Val, ctx);" in typechecker,
            "transitional Mutex.Lock return type changed during migration")
    require("[UnsafeMutexPrimitive]" in typechecker,
            "Patch 20.16d raw primitive enforcement is missing")
    require("std_Mutex_Lock_impl(" in codegen and
            "std_Mutex_Unlock_impl(" in codegen,
            "transitional Mutex primitive lowering changed during migration")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 20.16c — Explicit-Unsafe Mutex Primitive Migration — DONE"
            in task, "TASK.md does not mark Patch 20.16c DONE")
    require("- [x] Patch 20.16d — Protected-Access Liveness Enforcement — DONE"
            in task, "TASK.md does not mark the Patch 20.16d successor DONE")
    workflow = PR_FAST.read_text(encoding="utf-8")
    require("Phase 20 explicit-unsafe Mutex primitive migration" in workflow and
            "just guard-cranelift-phase20-unsafe-mutex-migration-contract"
            in workflow and
            "just guard-cranelift-phase20-unsafe-mutex-migration-parity"
            in workflow,
            "PR Fast does not own both Patch 20.16c levels")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require("guard-cranelift-phase20-unsafe-mutex-migration-contract:"
            in justfile and
            "guard-cranelift-phase20-unsafe-mutex-migration-parity:"
            in justfile,
            "Patch 20.16c just guards are missing")
    return authority, calls


def render(authority: dict) -> str:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    s1_8 = s1_8_transition(registry)
    lines = [
        "# Cranelift Phase 20 Explicit-Unsafe Mutex Primitive Migration",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_unsafe_mutex_migration.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{authority['contract_version']}`",
        f"- Status: `{authority['status']}`",
        f"- Next patch: `{authority['next_patch']}`",
        f"- Scope: `{authority['source_scope']}`",
        f"- Current classified calls: `{authority['total_calls']}` "
        f"(`{authority['total_lock_calls']}` Lock, "
        f"`{authority['total_unlock_calls']}` Unlock)",
        f"- Patch 20.16c frozen baseline: `{authority['baseline_calls']}`",
        "",
        "## Complete classified inventory",
        "",
    ]
    for row in authority["call_sites"]:
        lines.append(
            f"- `{row['path']}` — `{row['role']}`; "
            f"Lock `{row['lock_calls']}`, Unlock `{row['unlock_calls']}`"
        )
    lines += [
        "",
        "Every tracked Gust call spelled `.Lock(` or `.Unlock(` is classified.",
        "All operational calls are lexically inside an explicit `unsafe` block",
        "or unsafe function body; the only safe calls are the two exact Patch",
        "20.16d enforcement-negative fixtures. The scanner",
        "masks comments and literals, handles inline and whitespace-separated",
        "unsafe blocks, and rejects both unclassified calls and classified calls",
        "that escape the unsafe context.",
        "",
        "The 24-call Patch 20.16c baseline was already explicit unsafe because earlier raw-pointer",
        "migration wrapped the dereference performed between Lock and Unlock.",
        "Patch 20.16c therefore freezes the complete migration as a semantic no-op",
        "without rewriting source. Patch 20.16d adds two explicit-unsafe",
        "lifecycle calls and the two classified safe rejection witnesses. The",
        "two `tests/` fixtures remain transitional",
        "raw/manual coverage, not the future safe API contract.",
        "",
        "## Enforcement and backend boundary",
        "",
        "Safe-call enforcement is enabled by Patch 20.16d. `Mutex.Lock()` still",
        "returns a raw pointer internally; Lock/Unlock lowering, runtime symbols,",
        "ABI/layout, and MIR remain unchanged. Generic protected-access liveness",
        "is owned by the successor authority. Seed reconvergence remains isolated in",
        "Patch 20.16e.",
        "",
    ]
    if s1_8 is not None:
        successor, _ = s1_8
        raw = successor["raw_mutex_call_site_transition"]
        lines += [
            "## Registered Stdlib S1.8 successor",
            "",
            f"- Contract: `{successor['contract_version']}`",
            f"- Accepted complete successor: `{raw['current_totals']['calls']}` calls "
            f"(`{raw['current_totals']['lock_calls']}` Lock, "
            f"`{raw['current_totals']['unlock_calls']}` Unlock)",
            "- Added site: `tests/stdlib_s1_mutex_guard_generic_derivation_module.gst`",
            "",
            "The added one Lock/one Unlock pair is internal to the selected S1.8 module",
            "and remains explicitly unsafe. No safe raw call, backend-specific rule,",
            "partial lifecycle pair, path substitution, or unrelated call site is admitted.",
            "",
        ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=(
        "validate", "project", "check-review", "inventory"))
    args = parser.parse_args()
    try:
        authority, calls = validate()
        if args.command == "project":
            REVIEW.write_text(render(authority), encoding="utf-8")
        elif args.command == "check-review":
            require(REVIEW.read_text(encoding="utf-8") == render(authority),
                    "generated Patch 20.16c review is stale; run project")
        elif args.command == "inventory":
            for call in calls:
                print(f"{call.path}:{call.line}\t{call.method}\t"
                      f"explicit_unsafe={str(call.explicit_unsafe).lower()}")
    except (Error, KeyError, subprocess.CalledProcessError) as error:
        print(f"{GUARD}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
