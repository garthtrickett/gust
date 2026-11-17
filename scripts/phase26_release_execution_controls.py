"""Synthetic execution-environment refusals; no host paging activation."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from unittest.mock import patch

import phase26_release_execution as execution
import phase26_release_paging as paging


def rejected(label, function, diagnostic, expected=ValueError):
    try:
        function()
    except expected as error:
        message = "release execution environment: " + diagnostic if expected is ValueError else diagnostic
        if str(error) != message:
            raise ValueError(label + ": REJECTED (different assertion): " + str(error)) from error
        print(label + ": REJECTED (expected assertion)")
    else:
        raise ValueError(label + ": ACCEPTED")


def controls():
    assert paging.COMPILER_CAP_BYTES == 4294967296
    assert (paging.MINIMUM_PAGING, paging.TARGET_PAGING, paging.MAX_NEW_PAGING) == (
        1152*1024**2, 1200*1024**2, 1280*1024**2)
    assert paging.GROWTH_BUDGET == paging.DISK_RESERVE == 2147483648
    assert paging.COMMAND == ["python3", "scripts/phase26_release_bounded.py", "make", "gust"]
    try:
        rejected("harness-different", lambda: paging.require(False, "other boundary"), "intended boundary")
    except ValueError as error:
        assert str(error) == ("harness-different: REJECTED (different assertion): "
                              "release execution environment: other boundary")
    else:
        raise ValueError("rejection harness folded a different assertion into PASS")
    try:
        rejected("harness-accepted", lambda: None, "intended boundary")
    except ValueError as error:
        assert str(error) == "harness-accepted: ACCEPTED"
    else:
        raise ValueError("rejection harness folded acceptance into rejection")
    rejected("harness-expected", lambda: paging.require(False, "intended boundary"), "intended boundary")
    print("REJECTION_HARNESS_THREE_OUTCOMES_PASS")
    head, base, merge, tree = (character*40 for character in "abct")
    env = dict(GITHUB_ACTIONS="true", RUNNER_ENVIRONMENT="github-hosted", RUNNER_OS="Linux",
        GITHUB_REPOSITORY="garthtrickett/gust", GITHUB_REPOSITORY_ID="1263612197",
        GITHUB_JOB="qualification", GITHUB_RUN_ID="42", GITHUB_RUN_ATTEMPT="2",
        GITHUB_SHA=head, RUNNER_NAME="GitHub Actions 123")
    worker = dict(executable="/home/runner/runners/version/bin/Runner.Worker", pid=5, start_ticks="7")
    run = dict(id=42, run_attempt=2, repository=dict(id=1263612197), actor=dict(id=3760677),
        path=paging.WORKFLOW, status="in_progress", event="pull_request", head_sha=head,
        head_branch="codex/phase26-production-trust-renewal",
        head_commit=dict(tree_id=tree), pull_requests=[dict(head=dict(sha=head,
        repo=dict(id=1263612197)), base=dict(sha=base, ref="main", repo=dict(id=1263612197)))])
    job = dict(name="qualification", run_attempt=2, status="in_progress", run_id=42,
        head_sha=head, runner_id=123, runner_name=env["RUNNER_NAME"],
        runner_group_name="GitHub Actions", labels=["ubuntu-24.04"])
    checkout = dict(head=head, tree=tree, parents=[base])

    def validate(e=env, w=worker, r=run, j=job, c=checkout):
        return paging.validate_runner_evidence(e, w, r, [j], c)

    assert validate() == job
    merged_env, merged_checkout = dict(env, GITHUB_SHA=merge), dict(checkout, head=merge, parents=[base, head])
    assert validate(e=merged_env, c=merged_checkout) == job
    for name, value in (("GITHUB_ACTIONS", "false"), ("RUNNER_ENVIRONMENT", "self-hosted"),
        ("GITHUB_REPOSITORY_ID", "1"), ("GITHUB_JOB", "other"), ("GITHUB_RUN_ID", "43"),
        ("GITHUB_RUN_ATTEMPT", "1"), ("RUNNER_NAME", "other")):
        diagnostic = ("owning runner/job provenance mismatch" if name == "RUNNER_NAME" else
            "owning public run provenance mismatch" if name in ("GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT") else
            "not the owning hosted runner")
        rejected("hosted identity " + name, lambda n=name, v=value: validate(e=dict(env, **{n: v})), diagnostic)
    rejected("environment flags without worker ancestry", lambda: validate(w=dict(worker, executable="/usr/bin/python3")),
             "no live hosted worker ancestor")
    rejected("foreign checkout tree", lambda: validate(c=dict(checkout, tree="f"*40)),
             "checkout differs from the exact owning source tree")
    rejected("unauthenticated merge parents", lambda: validate(e=merged_env,
        c=dict(merged_checkout, parents=["f"*40, head])), "checkout is not the authenticated owning merge tree")
    rejected("historical job attempt", lambda: validate(j=dict(job, run_attempt=1)),
             "ambiguous or absent current owning job")
    rejected("foreign runner", lambda: validate(j=dict(job, runner_id=0)), "owning runner/job provenance mismatch")
    rejected("substituted owning workflow", lambda: validate(r=dict(run, path="other.yml")),
             "owning public run provenance mismatch")
    rejected("ambiguous current jobs", lambda: paging.validate_runner_evidence(env, worker, run, [job, job], checkout),
             "ambiguous or absent current owning job")
    old = {"/existing": dict(kind="file", size_bytes=1024, used_bytes=0, priority=-2)}
    assert paging.preserved_swaps(old, {"/existing": dict(old["/existing"], used_bytes=512)})
    assert not paging.preserved_swaps(old, {})
    assert not paging.preserved_swaps(old, {"/existing": dict(old["/existing"], size_bytes=2048)})
    assert not paging.preserved_swaps(old, {"/existing": dict(old["/existing"], priority=1)})
    parent = paging.ROOT/"build/guards/phase26_release_execution_controls"
    parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="controls-", dir=parent) as temporary:
        root = Path(temporary)
        output = root/"evidence"
        output.mkdir()
        (root/"build/guards").mkdir(parents=True)
        unit = "run-r"+"0"*32+".scope"
        absent = "LoadState=not-found\nActiveState=inactive\nControlGroup=\nResult=success\n"
        for number, (code, stdout, stderr, accept) in enumerate((
            (0, absent, "", True), (4, absent, "", True),
            (1, "", "Access denied", False), (0, "", "", False),
            (4, absent, "Access denied", False), (4, "", "Unrelated error", False),
            (0, absent.replace("ActiveState=inactive\n", ""), "", False))):
            case = output/str(number)
            case.mkdir()
            result = subprocess.CompletedProcess([], code, stdout, stderr)
            with patch.object(subprocess, "run", return_value=result):
                if accept:
                    assert execution.scope_state(unit, case)["LoadState"] == "not-found"
                else:
                    rejected("unconfirmed scope query " + str(number), lambda: execution.scope_state(unit, case),
                             "scope state is UNCONFIRMED")
            raw = json.loads((case/"control-plane.jsonl").read_text())
            assert raw["confirmed"] == accept and raw["stderr"] == stderr
        with patch.object(paging, "ROOT", root), patch.object(paging, "swap_rows", return_value={}), \
             patch.object(paging, "paging_capacity", return_value=0), \
             patch.object(paging, "paging_limit_remaining", return_value=None), \
             patch.object(paging, "meminfo", return_value=dict(MemAvailable=8*1024**3, SwapFree=0, SwapTotal=0)), \
             patch.object(paging, "check_disk", return_value={}), \
             patch.object(paging, "allocated", return_value=0), \
             patch.object(paging, "checked_run", side_effect=AssertionError("unexpected privileged command")):
            case = output/"outside-ci"
            case.mkdir()
            owned = paging.Paging(case, 0)
            rejected("no shared-host provisioning", lambda: owned.prepare(None),
                     "insufficient existing paging outside ephemeral owning CI")
            assert not owned.file.exists()
            case = output/"partial-allocation"
            case.mkdir()
            owned = paging.Paging(case, 0)
            context = dict(environment=env, worker=worker, checkout=checkout,
                           job=dict(job, id=100), run=run)
            with patch.object(paging, "hosted_runner", return_value=context), \
                 patch.object(os, "posix_fallocate", side_effect=OSError("controlled allocation failure")):
                rejected("partial allocation fails closed", lambda: owned.prepare(context),
                         "controlled allocation failure", OSError)
            assert owned.file.is_file() and owned.identity is not None
            rejected("unconfirmed payload retains owned file", lambda: owned.cleanup(False),
                     "payload emptiness is unconfirmed; paging retained")
            assert owned.file.is_file()
            owned.cleanup(True)
            assert not owned.file.exists()
            case = output/"substituted-inode"
            case.mkdir()
            owned = paging.Paging(case, 0)
            owned.file.parent.mkdir(mode=0o700)
            owned.file.write_bytes(b"owned control")
            owned.file.chmod(0o600)
            state = owned.file.stat()
            owned.identity = dict(device=state.st_dev, inode=state.st_ino,
                                 uid=state.st_uid, bytes=state.st_size)
            kept = owned.file.with_name("kept-control")
            owned.file.rename(kept)
            owned.file.write_bytes(b"substitute")
            owned.file.chmod(0o600)
            rejected("substituted paging inode retained", lambda: owned.cleanup(True), "owned paging identity changed")
            assert kept.read_bytes() == b"owned control" and owned.file.read_bytes() == b"substitute"
            owned.file.unlink()
            kept.rename(owned.file)
            with patch.object(paging, "swap_rows", return_value={str(owned.file): dict(used_bytes=0)}), \
                 patch.object(paging, "checked_run", side_effect=subprocess.CalledProcessError(1, ["CONTROLLED_SWAPOFF"])):
                rejected("swapoff failure retains file", lambda: owned.cleanup(True),
                         str(subprocess.CalledProcessError(1, ["CONTROLLED_SWAPOFF"])), subprocess.CalledProcessError)
            assert owned.file.read_bytes() == b"owned control"
        case = output/"actual-owned-orphan"
        case.mkdir()
        execution.enable_subreaper()
        process = subprocess.Popen([sys.executable, "-c", "import subprocess,sys;"
            "subprocess.Popen([sys.executable,'-c','import time;time.sleep(30)'])"],
            start_new_session=True)
        process.wait(timeout=10)
        assert process.returncode == 0 and execution.children()
        assert execution.drain_local(process, case) and not execution.children()
    print("RELEASE_EXECUTION_ENVIRONMENT_CONTROLS_PASS; synthetic only, no paging activation")
