"""Patch 24.17: qualify ONE Historical Full run on the exact merged main.

The run is dispatched, not waited for opportunistically: `gh workflow run` on
`.github/workflows/cranelift-historical-full.yml`, which declares
`workflow_dispatch:`.

Two things this exists to prevent, both of which pass silently otherwise.

INHERITING THE POPULATION (#405). Part of the population the run exercises is
computed at RUN TIME -- `just` dispatches
`cranelift_test_levels.py list-native` and the historical workflow reaches it
through the phase9-core shard -- and nothing in either pins the result. So a
run can be green over a SMALLER population than the one the gate was written
for, and every patch from 24.15 onward shrinks that population. The run is
therefore qualified against the pre-retirement baseline member by member, not
against whatever population it happened to have.

QUALIFYING THE WRONG MAIN. "The run was green" is an adjective. The closure
rests on a run identity -- run id, FULL sha, event, conclusion, unique job
population, budgets -- recorded before closure publication, so a later reader
can check the claim instead of believing it. An abbreviated sha is rejected:
abbreviations can become ambiguous as the repository grows.
"""

# REGISTRATION NOTE (24.17): no recipe, level or workflow yet, for the
# same reason as phase24_closure.py -- this refuses until main contains
# the retirement, which cannot be true until the stack merges. It is
# registered alongside the closure, and dispatched by hand once between
# the merge and the closure PR.

import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = "cranelift-historical-full.yml"
GUARD = "guard-cranelift-phase24-historical-full-qualification"


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD}: {message}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def gh(*args: str) -> str:
    result = subprocess.run(["gh", *args], cwd=ROOT, capture_output=True,
                            text=True, check=False)
    require(result.returncode == 0,
            f"gh {' '.join(args)} failed: {result.stderr.strip()[:200]}")
    return result.stdout


def merged_main_sha() -> str:
    sha = gh("api", "repos/{owner}/{repo}/commits/main", "--jq", ".sha").strip()
    require(len(sha) == 40, f"expected a full main sha, got {sha!r}")
    return sha


def dispatch(sha: str) -> None:
    """Dispatch on main, then confirm the run's head is the sha we meant."""
    gh("workflow", "run", WORKFLOW, "--ref", "main")
    print(f"{GUARD}: dispatched {WORKFLOW} on main @ {sha}")


def latest_run() -> dict:
    payload = json.loads(gh(
        "run", "list", "--workflow", WORKFLOW, "--limit", "1",
        "--json", "databaseId,headSha,event,status,conclusion,createdAt"))
    require(payload, "no Historical Full run found")
    return payload[0]


def retirement_is_on_main() -> None:
    """The main being qualified must CONTAIN the retirement.

    Without this the guard passes on any green Historical run against whatever
    main happens to exist -- including the pre-retirement main, which is green
    precisely because nothing was removed yet. "The exact merged retirement
    main" is a claim about content, and a sha alone cannot carry it.

    Checked by content, not by a status row: a row saying DONE is what the
    closure generator enforces, and two instruments asserting the same row
    is one instrument.
    """
    entry = gh("api",
               "repos/{owner}/{repo}/contents/compiler/test_runner_entry.gst",
               "--jq", ".content")
    import base64
    source = base64.b64decode(entry).decode("utf-8", "replace")
    require(
        "the generated-C backend was removed in Phase 24" in source,
        "main does not contain the retirement: the compiler entry still "
        "accepts the generated-C backend. A Historical run on a "
        "pre-retirement main is green because nothing was removed yet, so "
        "qualifying it proves the opposite of what this patch claims.",
    )
    require(
        '"--backend <mir-to-c|c|cranelift>"' not in source,
        "main still advertises the removed C backend in its help surface",
    )


def qualify(run: dict, expected_sha: str) -> dict:
    retirement_is_on_main()
    require(
        run["headSha"] == expected_sha,
        f"the run qualified is not on the exact merged main: run head "
        f"{run['headSha']} != main {expected_sha}. Patch 24.17 qualifies ONE "
        "run on the exact merged retirement main; a run on any other commit "
        "qualifies a tree nobody is shipping.",
    )
    require(run["status"] == "completed",
            f"the run has not completed: {run['status']}")
    require(run["conclusion"] == "success",
            f"the authoritative run did not succeed: {run['conclusion']}")

    jobs = json.loads(gh("run", "view", str(run["databaseId"]),
                         "--json", "jobs"))["jobs"]
    names = [job["name"] for job in jobs]
    duplicated = sorted({n for n in names if names.count(n) > 1})
    require(not duplicated,
            f"the job population is not unique: {duplicated}. A repeated job "
            "makes the population count larger than the work it covers.")
    incomplete = [job["name"] for job in jobs
                  if job["conclusion"] not in ("success", "skipped")]
    require(not incomplete,
            f"jobs did not succeed: {incomplete[:6]}")

    accounting = subprocess.run(
        ["python3", str(ROOT / "scripts" / "phase24_native_population_accounting.py"),
         "validate"], cwd=ROOT, capture_output=True, text=True, check=False)
    require(accounting.returncode == 0,
            "the #405 population accounting does not hold, so this run's "
            "population cannot be qualified against the baseline: "
            f"{accounting.stdout.strip()[-200:]}")

    return {
        "run_id": run["databaseId"],
        "head_sha": run["headSha"],
        "event": run["event"],
        "conclusion": run["conclusion"],
        "unique_job_population": len(set(names)),
        "budgets": {"jobs": len(jobs), "skipped": sum(
            1 for job in jobs if job["conclusion"] == "skipped")},
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["dispatch", "qualify"])
    arguments = parser.parse_args()
    sha = merged_main_sha()
    if arguments.command == "dispatch":
        dispatch(sha)
        return
    authority = qualify(latest_run(), sha)
    print(json.dumps(authority, indent=2, sort_keys=True))
    print(f"{GUARD}: ok")


if __name__ == "__main__":
    main()
