#!/usr/bin/env python3
"""Validate and project Patch 20.16c explicit-unsafe Mutex migration."""

from __future__ import annotations

import argparse
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
    expected = {
        row["path"]: {"Lock": row["lock_calls"],
                      "Unlock": row["unlock_calls"]}
        for row in authority.get("call_sites", [])
    }
    require(actual == expected,
            f"raw Mutex call-site classification drifted: actual={actual!r}")
    lock_calls = sum(call.method == "Lock" for call in calls)
    unlock_calls = sum(call.method == "Unlock" for call in calls)
    require(authority.get("baseline_lock_calls") == 12 and
            authority.get("baseline_unlock_calls") == 12 and
            authority.get("baseline_calls") == 24,
            "Patch 20.16c frozen 24-call baseline drifted")
    require(lock_calls == authority.get("total_lock_calls") == 14,
            "raw Mutex Lock inventory drifted")
    require(unlock_calls == authority.get("total_unlock_calls") == 14,
            "raw Mutex Unlock inventory drifted")
    require(len(calls) == authority.get("total_calls") == 28,
            "raw Mutex total call inventory drifted")
    require(authority.get("transitional_test_coverage") == [
        "tests/e2e_mutex_concurrency.gst",
        "tests/e2e_sync_primitives.gst",
    ], "transitional raw Mutex test classification drifted")

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
