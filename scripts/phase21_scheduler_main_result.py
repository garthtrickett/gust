#!/usr/bin/env python3
"""Validate and replay Patch 21.17a scheduler result publication authority."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
RUNTIME = ROOT / "src/runtime/fiber.c"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase21-scheduler-main-result.yml"
JUSTFILE = ROOT / "justfile"
GUARD_L1 = "guard-cranelift-phase21-scheduler-main-result-contract"
GUARD_L2 = "guard-cranelift-phase21-scheduler-main-result-evidence"

EXPECTED = {
    "patch": "21.17a",
    "status": "complete",
    "capability": "generic_scheduler_main_result_completion",
    "trigger": "patch21_17_inherited_phase20_long_lived_concurrent_replay",
    "operator_date": "2026-08-28",
    "expected_exit_status": 47,
    "observed_mir_to_c_statuses_before": [0, 47],
    "observed_native_status_before": 47,
    "focused_replays_per_backend": 32,
    "synchronization_authority": (
        "scheduler_owned_pending_fiber_count_with_full_barrier_result_publication"
    ),
    "runtime_implementation": "src/runtime/fiber.c",
    "changes_runtime_symbols": False,
    "changes_abi_or_layout": False,
    "changes_accepted_gust_meaning": False,
    "falsifier": (
        "every_focused_MIR_to_C_and_Cranelift_replay_returns_47_with_identical_"
        "empty_streams_and_the_patch21_17_full_inherited_replay_passes"
    ),
    "boundary": (
        "generic_scheduler_completion_only_no_gate_weakening_fixture_exception_"
        "other_runtime_semantics_stdlib_CR15_or_patch21_18"
    ),
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def validate() -> None:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    amendments = registry.get("phase21_roadmap", {}).get("amendments", [])
    rows = [row for row in amendments if row.get("patch") == "21.17a"]
    require(rows == [EXPECTED], "Patch 21.17a registry authority drifted")

    task = TASK.read_text(encoding="utf-8")
    require(
        "- [x] Patch 21.17a — Scheduler Main-Result Completion — DONE" in task,
        "TASK.md does not mark Patch 21.17a DONE",
    )

    runtime = RUNTIME.read_text(encoding="utf-8")
    for fragment in (
        "static int gust_pending_fibers = 0;",
        "__sync_add_and_fetch(&gust_pending_fibers, 1);",
        "__sync_sub_and_fetch(&gust_pending_fibers, 1);",
        "__sync_fetch_and_add(&gust_pending_fibers, 0) > 0",
    ):
        require(fragment in runtime, f"runtime completion primitive missing: {fragment}")
    require(
        runtime.index("__sync_add_and_fetch(&gust_pending_fibers, 1);")
        < runtime.index("target->run_queue_tail->next = fiber;"),
        "pending ownership must be established before publishing the queued fiber",
    )
    require(
        runtime.index("__sync_sub_and_fetch(&gust_pending_fibers, 1);")
        < runtime.index("gust_fiber_free(next);"),
        "terminal completion must be published before freeing the fiber",
    )

    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1, "Patch 21.17a contract is not Level 1")
    require(levels.get(GUARD_L2) == 2, "Patch 21.17a evidence is not Level 2")

    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in justfile, "Patch 21.17a contract recipe is missing")
    require(f"{GUARD_L2}:" in justfile, "Patch 21.17a evidence recipe is missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Patch 21.17a contract")

    require(WORKFLOW.is_file(), "Patch 21.17a workflow is missing")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(workflow.count("- 'src/runtime.c'") == 2,
            "workflow must watch runtime aggregation on PR and main")
    require(workflow.count("- 'src/runtime/**'") == 2,
            "workflow must watch runtime sources on PR and main")
    require(workflow.count("- 'tools/normalize_generated_arena_offsets.py'") == 2,
            "workflow must watch the compiler's generated-offset normalizer")
    require(f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow,
            "workflow does not execute both Patch 21.17a owners")


def replay() -> None:
    validate()
    subprocess.run(
        ["bash", "scripts/phase20_long_lived_concurrent.sh", "full"],
        cwd=ROOT,
        check=True,
    )

    build = ROOT / "build/guards/phase20_long_lived_concurrent_full"
    programs = {
        "mir-to-c": build / "mir-to-c-program",
        "cranelift": build / "native-program",
    }
    expected_status = EXPECTED["expected_exit_status"]
    replays = EXPECTED["focused_replays_per_backend"]
    env = os.environ.copy()
    env["GUST_PHASE20_LONG_LIVED_CYCLES"] = "128"
    observations: dict[str, tuple[int, bytes, bytes]] = {}
    for backend, program in programs.items():
        require(program.is_file(), f"focused {backend} executable is missing")
        for run in range(1, replays + 1):
            result = subprocess.run(
                [str(program)],
                cwd=ROOT,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=30,
                check=False,
            )
            observation = (result.returncode, result.stdout, result.stderr)
            require(result.returncode == expected_status,
                    f"{backend} replay {run} returned {result.returncode}, "
                    f"expected {expected_status}")
            require(not result.stdout and not result.stderr,
                    f"{backend} replay {run} produced an observable stream")
            if backend in observations:
                require(observation == observations[backend],
                        f"{backend} replay {run} was nondeterministic")
            else:
                observations[backend] = observation
    require(observations["mir-to-c"] == observations["cranelift"],
            "MIR-to-C and Cranelift focused observations diverged")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "replay"))
    args = parser.parse_args()
    if args.command == "replay":
        replay()
    else:
        validate()
    print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
