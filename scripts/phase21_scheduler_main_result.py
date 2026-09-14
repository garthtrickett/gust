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
HARNESS = ROOT / "scripts/phase20_long_lived_concurrent.sh"
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

    # Patch 24.12 converted the harness this guard replays, so replay() reads
    # a frozen MIR-to-C observation instead of executing one. That contract
    # is between two files, and nothing else checks the seam: this guard
    # names no backend spelling, so the 24.12 inventory (which scans
    # scripts/*.sh) and its no-live-C check both look straight past it. It
    # broke exactly that way once -- the harness stopped building
    # `mir-to-c-program`, this file went on requiring it, and the guard still
    # passed on any tree with a stale build/ directory. Assert the seam from
    # this side, in both directions.
    harness = HARNESS.read_text(encoding="utf-8")
    require("phase24_frozen_oracle.py materialize" in harness and
            '"$build_root/mir-to-c" --kind exec' in harness,
            "the long-lived harness no longer materializes the frozen "
            "MIR-to-C observation that replay() reads")
    require("mir-to-c-program" not in harness,
            "the long-lived harness builds a live-C program again; replay() "
            "would compare the frozen arm against a tree that has both")


def replay() -> None:
    validate()
    subprocess.run(
        ["bash", "scripts/phase20_long_lived_concurrent.sh", "full"],
        cwd=ROOT,
        check=True,
    )

    build = ROOT / "build/guards/phase20_long_lived_concurrent_full"
    expected_status = EXPECTED["expected_exit_status"]
    replays = EXPECTED["focused_replays_per_backend"]

    # Patch 24.12 froze this harness's MIR-to-C arm, so there is no
    # `mir-to-c-program` to replay: phase20_long_lived_concurrent.sh now
    # materializes the frozen vector's observation instead, under the same
    # GUST_PHASE20_LONG_LIVED_CYCLES the native replays below run with. The
    # recording is read once. Serving it 32 times would compare a file to
    # itself, which is why the harness stopped doing that for its own
    # resource arm; the determinism evidence Patch 21.17a rests on is the
    # native replay loop, and that is still live.
    frozen = {
        "status": build / "mir-to-c.status",
        "stdout": build / "mir-to-c.stdout",
        "stderr": build / "mir-to-c.stderr",
    }
    for name, path in frozen.items():
        require(path.is_file(),
                f"frozen MIR-to-C {name} observable is missing")
    mir_to_c = (
        int(frozen["status"].read_text(encoding="utf-8").strip()),
        frozen["stdout"].read_bytes(),
        frozen["stderr"].read_bytes(),
    )
    require(mir_to_c[0] == expected_status,
            f"frozen MIR-to-C observation returned {mir_to_c[0]}, "
            f"expected {expected_status}")
    require(not mir_to_c[1] and not mir_to_c[2],
            "frozen MIR-to-C observation carries an observable stream")

    program = build / "native-program"
    require(program.is_file(), "focused cranelift executable is missing")
    env = os.environ.copy()
    env["GUST_PHASE20_LONG_LIVED_CYCLES"] = "128"
    first: tuple[int, bytes, bytes] | None = None
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
                f"cranelift replay {run} returned {result.returncode}, "
                f"expected {expected_status}")
        require(not result.stdout and not result.stderr,
                f"cranelift replay {run} produced an observable stream")
        if first is None:
            first = observation
        else:
            require(observation == first,
                    f"cranelift replay {run} was nondeterministic")
        require(observation == mir_to_c,
                f"cranelift replay {run} diverged from the frozen MIR-to-C "
                f"observation")


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
