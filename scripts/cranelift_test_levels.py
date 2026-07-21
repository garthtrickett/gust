#!/usr/bin/env python3
"""Validate the three-level Cranelift guard cost and CI ownership policy."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
POLICY_PATH = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_WORKFLOW = ROOT / ".github/workflows/pr-fast.yml"
HEAVY_WORKFLOW = ROOT / ".github/workflows/heavy-guards.yml"
HISTORICAL_WORKFLOW = ROOT / ".github/workflows/cranelift-historical-full.yml"

GUARD_RECIPE_PATTERN = re.compile(
    r"^(guard-cranelift-[A-Za-z0-9_-]+)(?: [^:\n]*)?:$",
    re.MULTILINE,
)
GUARD_NAME_PATTERN = re.compile(r"^guard-cranelift-[A-Za-z0-9_-]+$")
TOKEN_PATTERN = re.compile(r"guard-cranelift-[A-Za-z0-9_-]+")
DIRECT_CALL_PATTERN = re.compile(
    r"^[ \t]+just[ \t]+(guard-cranelift-[A-Za-z0-9_-]+)",
    re.MULTILINE,
)

NATIVE_SUITE_EXCLUSIONS = {
    "guard-cranelift-branch-native-smoke",
    "guard-cranelift-differential-native-smoke",
    "guard-cranelift-local-binding-read-native-smoke",
}
NATIVE_SUITE_AGGREGATES = {
    "guard-cranelift-mir-to-cranelift-translator-seed-suite",
    "guard-cranelift-phase9c-differential-ladder-native-smoke",
}


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise Error(f"missing required file: {path.relative_to(ROOT)}") from exc


def read_policy() -> dict:
    try:
        policy = json.loads(read_text(POLICY_PATH))
    except json.JSONDecodeError as exc:
        raise Error(
            f"invalid test-level JSON: {exc.lineno}:{exc.colno}: {exc.msg}"
        ) from exc

    require(isinstance(policy, dict), "test-level policy must be a JSON object")
    require(policy.get("version") == 1, "test-level policy version must be 1")

    levels = policy.get("levels")
    require(isinstance(levels, dict), "test-level policy levels must be an object")
    require(set(levels) == {"1", "2", "3"}, "test-level policy must define levels 1, 2, and 3")

    guards = policy.get("guards")
    require(isinstance(guards, dict), "test-level policy guards must be an object")
    for guard, level in guards.items():
        require(
            isinstance(guard, str) and GUARD_NAME_PATTERN.fullmatch(guard),
            f"invalid Cranelift guard name in test-level policy: {guard!r}",
        )
        require(level in (1, 2, 3), f"{guard}: invalid test level {level!r}")
    return policy


def defined_guards() -> set[str]:
    return set(GUARD_RECIPE_PATTERN.findall(read_text(JUSTFILE)))


def recipe_bodies() -> dict[str, str]:
    text = read_text(JUSTFILE)
    matches = list(GUARD_RECIPE_PATTERN.finditer(text))
    bodies = {}
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        bodies[match.group(1)] = text[match.end():end]
    return bodies


def validate_inventory(policy: dict) -> None:
    defined = defined_guards()
    assigned = set(policy["guards"])
    require(
        defined == assigned,
        "Cranelift test-level inventory differs from justfile: "
        f"unassigned={sorted(defined - assigned)} "
        f"undefined={sorted(assigned - defined)}",
    )

    for caller, body in recipe_bodies().items():
        caller_level = int(policy["guards"][caller])
        for callee in DIRECT_CALL_PATTERN.findall(body):
            callee_level = int(policy["guards"][callee])
            require(
                callee_level <= caller_level,
                f"{caller}: Level {caller_level} directly calls "
                f"{callee}: Level {callee_level}",
            )


def level_of(policy: dict, guard: str) -> int:
    try:
        return int(policy["guards"][guard])
    except KeyError as exc:
        raise Error(f"unassigned Cranelift guard: {guard}") from exc


def direct_guard_tokens(text: str) -> set[str]:
    return set(TOKEN_PATTERN.findall(text))


def require_direct_levels(
    policy: dict,
    text: str,
    allowed_levels: set[int],
    context: str,
) -> None:
    invalid = sorted(
        guard
        for guard in direct_guard_tokens(text)
        if level_of(policy, guard) not in allowed_levels
    )
    require(
        not invalid,
        f"{context} directly invokes guards outside levels "
        f"{sorted(allowed_levels)}: {invalid}",
    )


def check_pr_workflow(policy: dict) -> None:
    text = read_text(PR_WORKFLOW)
    require("pull_request:" in text, "PR Fast must remain a pull-request workflow")
    require(
        text.count("just guard-cranelift-phase12-5-close") == 1,
        "PR Fast must invoke guard-cranelift-phase12-5-close exactly once",
    )
    require(
        text.count(
            "just guard-cranelift-phase13-capability-deferral-contract"
        )
        == 1,
        "PR Fast must invoke the Phase 13 capability/deferral contract "
        "exactly once",
    )
    require(
        text.count(
            'just guard-cranelift-differential-family "${{ matrix.family }}"'
        )
        == 1,
        "PR Fast must invoke the registry-derived differential-family guard exactly once",
    )
    require(
        "historical-closure:" not in text,
        "PR Fast must not contain a Level 3 historical-closure job",
    )
    require(
        "guard-cranelift-historical-full" not in text
        and "guard-cranelift-phase11-close" not in text,
        "PR Fast must not run Level 3 full-history entry points",
    )
    require(
        "needs: [guard, phase11-family]" in text,
        "PR Fast final job must depend only on Level 1 and Level 2 jobs",
    )
    require_direct_levels(policy, text, {1, 2}, "PR Fast")


def check_heavy_workflow(policy: dict) -> None:
    text = read_text(HEAVY_WORKFLOW)
    require(
        "historical-closure:" not in text,
        "Heavy Guards must not contain the full historical replay job",
    )
    require(
        "guard-cranelift-historical-full" not in text
        and "guard-cranelift-phase11-close" not in text,
        "Heavy Guards must leave full history to its scheduled/manual owner",
    )
    require(
        "needs: [guard, phase9g-link-driver]" in text,
        "Heavy final job must depend on focused native and link evidence only",
    )
    require(
        'just guard-cranelift-differential-family "${{ matrix.family }}"' not in text,
        "Heavy Guards must not duplicate the PR Fast family matrix",
    )


def check_historical_workflow(policy: dict) -> None:
    text = read_text(HISTORICAL_WORKFLOW)
    require("schedule:" in text, "historical workflow must have a schedule")
    require("workflow_dispatch:" in text, "historical workflow must support manual runs")
    require("pull_request:" not in text, "historical workflow must not run on pull requests")
    require(
        text.count("just guard-cranelift-historical-full") == 1,
        "historical workflow must invoke guard-cranelift-historical-full exactly once",
    )
    require_direct_levels(policy, text, {3}, "Cranelift Historical Full")


def print_level(policy: dict, level: int) -> None:
    for guard, assigned in sorted(policy["guards"].items()):
        if assigned == level:
            print(guard)


def native_suite_guards(policy: dict) -> list[str]:
    guards = []
    for guard, level in sorted(policy["guards"].items()):
        if level != 3 or guard in NATIVE_SUITE_EXCLUSIONS:
            continue
        if (
            guard.endswith("-native-smoke")
            or guard.endswith("-native-rejection")
            or guard in NATIVE_SUITE_AGGREGATES
        ):
            guards.append(guard)
    require(guards, "structured test-level authority contains no native suite guards")
    return guards


def print_native(policy: dict) -> None:
    for guard in native_suite_guards(policy):
        print(guard)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command",
        choices=(
            "validate",
            "level",
            "list-level",
            "list-native",
            "check-pr-workflow",
            "check-heavy-workflow",
            "check-historical-workflow",
        ),
    )
    parser.add_argument("value", nargs="?")
    args = parser.parse_args()

    try:
        policy = read_policy()
        validate_inventory(policy)

        if args.command == "validate":
            counts = {
                level: sum(1 for value in policy["guards"].values() if value == level)
                for level in (1, 2, 3)
            }
            print(
                "✅ Cranelift test levels passed: "
                f"Level 1={counts[1]}, Level 2={counts[2]}, Level 3={counts[3]}."
            )
        elif args.command == "level":
            require(args.value is not None, "level requires a guard name")
            level = level_of(policy, args.value)
            owner = policy["levels"][str(level)]["ci_owner"]
            print(f"{args.value}\t{level}\t{owner}")
        elif args.command == "list-level":
            require(args.value in {"1", "2", "3"}, "list-level requires 1, 2, or 3")
            print_level(policy, int(args.value))
        elif args.command == "list-native":
            require(args.value is None, "list-native does not accept a value")
            print_native(policy)
        elif args.command == "check-pr-workflow":
            check_pr_workflow(policy)
            print("✅ PR Fast owns only Level 1 contracts and Level 2 families.")
        elif args.command == "check-heavy-workflow":
            check_heavy_workflow(policy)
            print("✅ Heavy Guards contains focused native evidence and no full-history replay.")
        elif args.command == "check-historical-workflow":
            check_historical_workflow(policy)
            print("✅ Cranelift Historical Full is the sole Level 3 CI owner.")
    except (Error, OSError) as exc:
        print(f"cranelift test-level error: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
