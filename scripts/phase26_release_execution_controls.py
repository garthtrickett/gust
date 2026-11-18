"""Synthetic execution-environment refusals; no host paging activation."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import urllib.error
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


def metadata_api_controls(root):
    """Exercise authorization/transport and early failure without real credentials or network."""
    token = "synthetic-job-credential"
    endpoint = "actions/runs/42"
    url = "https://api.github.com/repos/garthtrickett/gust/" + endpoint
    request_seen = []

    class Response:
        status = 200
        def __init__(self, raw=b'{"id":42}', final=url):
            self.raw, self.final = raw, final
        def __enter__(self):return self
        def __exit__(self, *args):pass
        def geturl(self):return self.final
        def read(self, limit):
            assert limit == 2*1024**2+1
            return self.raw[:limit]

    def opened(request, timeout):
        assert request.full_url in (url, url+"/jobs?per_page=100")
        assert request.get_method() == "GET" and timeout == 30
        assert request.get_header("Authorization") == "Bearer " + token
        request_seen.append(request.full_url)
        return Response(final=request.full_url)

    def opener(handler):
        assert isinstance(handler, paging.NoMetadataRedirect)
        result = __import__("types").SimpleNamespace(open=opened)
        return result

    with patch.object(paging.urllib.request, "build_opener", side_effect=opener):
        for index, path in enumerate((endpoint, endpoint+"/jobs?per_page=100")):
            case = root/("api-accepted-"+str(index));case.mkdir()
            assert paging.public_api(path, token, case) == {"id": 42}
            recorded = json.loads((case/"public-api.jsonl").read_text())
            assert recorded["endpoint"] == path and recorded["status"] == 200 and recorded["authenticated"]
            assert token not in (case/"public-api.jsonl").read_text()
        assert request_seen == [url, url+"/jobs?per_page=100"]
        for value in (None, "", "bad\ncredential"):
            rejected("missing/invalid job credential", lambda v=value: paging.public_api(endpoint, v, root),
                     "missing or invalid automatic metadata credential")
        for value in ("https://other.invalid/", "actions/runs/42/../secrets", "actions/runs/42/jobs?per_page=101"):
            rejected("unqualified metadata path", lambda v=value: paging.public_api(v, token, root),
                     "unqualified public metadata endpoint")
        assert request_seen == [url, url+"/jobs?per_page=100"]
    request = paging.urllib.request.Request(url, headers={"Authorization": "Bearer " + token})
    assert paging.NoMetadataRedirect().redirect_request(request, None, 302, "redirect", {},
        "https://other.invalid/") is None
    for name, response in (("malformed", Response(b"not json")),
                           ("oversized", Response(b" "*(2*1024**2+1))),
                           ("redirected", Response(final="https://other.invalid/"))):
        case = root/("api-"+name);case.mkdir()
        with patch.object(paging.urllib.request, "build_opener") as factory:
            factory.return_value.open.return_value = response
            rejected(name+" metadata", lambda: paging.public_api(endpoint, token, case),
                     "public metadata response unavailable or invalid: "+endpoint)
        assert token not in (case/"public-api.jsonl").read_text()
    case = root/"api-rate-limit";case.mkdir()
    error = urllib.error.HTTPError(url, 403, token, {"X-RateLimit-Remaining": "0",
        "X-RateLimit-Reset": "123", "Authorization": token}, None)
    with patch.object(paging.urllib.request, "build_opener") as factory:
        factory.return_value.open.side_effect = error
        rejected("metadata API rate limit", lambda: paging.public_api(endpoint, token, case),
                 "public metadata request failed: "+endpoint+" HTTP 403")
    raw = (case/"public-api.jsonl").read_text()
    assert token not in raw and json.loads(raw)["rate_limit"] == {
        "X-RateLimit-Remaining": 0, "X-RateLimit-Reset": 123}
    case = root/"early-metadata-failure";case.mkdir()
    def unavailable(credential, output):
        assert credential == token and paging.METADATA_TOKEN not in os.environ
        raise ValueError("release execution environment: controlled metadata refusal")
    with patch.object(paging, "ROOT", case), patch.object(paging, "allocated", return_value=0), \
         patch.object(paging, "check_disk", return_value={}), \
         patch.object(paging, "hosted_runner", side_effect=unavailable), \
         patch.object(paging, "Paging", side_effect=AssertionError("paging must not begin")), \
         patch.object(execution, "run_build", side_effect=AssertionError("build must not begin")), \
         patch.dict(os.environ, {"GITHUB_ACTIONS": "true", paging.METADATA_TOKEN: token}):
        rejected("early metadata refusal retained", lambda: execution.build(Path("build/guards/phase26_release_execution")),
                 "controlled metadata refusal")
        assert paging.METADATA_TOKEN not in os.environ
    evidence = case/"build/guards/phase26_release_execution"
    assert json.loads((evidence/"failure.json").read_text())["payload_empty"]
    assert json.loads((evidence/"paging-cleanup.json").read_text())["status"] == "PASS no job-owned paging created"
    assert (evidence/"terminal-disk.json").is_file()
    assert all(token not in p.read_text() for p in evidence.iterdir())
    # The actual hosted command's allowlist must exclude both credential name and bytes.
    with patch.dict(os.environ, {paging.METADATA_TOKEN: token}):
        command = execution.hosted_command({"job": {"started_at": paging.utc()}}, "run-r"+"0"*32+".scope")
        assert all(token not in value and paging.METADATA_TOKEN not in value for value in command)
    print("RELEASE_METADATA_PUBLIC_AUTH_CONTROLS_PASS; no real credentials, network or provisioning")


def worker_observation_controls(root, env, worker, run, job, checkout):
    """Capture actual-function observations without admitting a synthetic runner."""
    first = dict(pid=10, parent=5, start_ticks="1", executable="/usr/bin/python3")
    final = dict(worker, parent=1)
    with patch.object(paging.os, "getpid", return_value=10), \
         patch.object(paging, "process_identity", side_effect=lambda pid: {10: first, 5: final}[pid]):
        observed, ancestors = paging.hosted_worker_ancestry()
        assert observed == final and ancestors == [first, final]
    with patch.object(paging.os, "getpid", return_value=10):
        with patch.object(paging, "process_identity", return_value=dict(first, parent=1)):
            rejected("no worker basename", paging.hosted_worker_ancestry, "no live Runner.Worker ancestor")
        with patch.object(paging, "process_identity", return_value=dict(first, parent=10)):
            rejected("ancestor cycle", paging.hosted_worker_ancestry, "hosted worker ancestry cycle")
        with patch.object(paging, "process_identity", side_effect=[first, dict(first, start_ticks="2")]):
            rejected("stale process identity", paging.hosted_worker_ancestry,
                     "hosted process identity changed during traversal")
        with patch.object(paging, "process_identity", return_value=dict(first, argv="must not be retained")):
            rejected("unqualified process fields", paging.hosted_worker_ancestry,
                     "unexpected hosted process identity fields")
        with patch.object(paging.time, "monotonic", side_effect=[0, 6]):
            rejected("ancestor duration bound", paging.hosted_worker_ancestry,
                     "hosted worker ancestry bound exhausted")
    with patch.object(paging.os, "getpid", return_value=1000), \
         patch.object(paging, "process_identity", side_effect=lambda pid:
             dict(first, pid=pid, parent=pid-1)):
        rejected("ancestor population bound", paging.hosted_worker_ancestry,
                 "hosted worker ancestry bound exhausted")

    fake_root = Path("/home/runner/work/gust/gust")
    token = "synthetic-observation-credential"
    job = dict(job, id=100)
    def git_value(command, **kwargs):
        assert command[0] == "git" and kwargs == dict(cwd=fake_root, text=True)
        return {("rev-parse", "HEAD"): checkout["head"],
                ("rev-parse", "HEAD^{tree}"): checkout["tree"],
                ("rev-list", "--parents", "-n1", "HEAD"):
                    " ".join([checkout["head"], *checkout["parents"]])}[tuple(command[1:])] + "\n"
    for number, executable in enumerate((final["executable"], "/unqualified-layout/bin/Runner.Worker")):
        case = root/("worker-observation-"+str(number));case.mkdir()
        current = dict(final, executable=executable)
        chain = [first, current]
        def response(path, credential, output):
            assert credential == token and output == case
            assert path in ("actions/runs/42", "actions/runs/42/jobs?per_page=100")
            return run if path == "actions/runs/42" else dict(total_count=1, jobs=[job])
        with patch.object(paging, "ROOT", fake_root), \
             patch.object(paging.os, "getuid", return_value=1000), \
             patch.object(paging.pwd, "getpwuid", return_value=__import__("types").SimpleNamespace(pw_name="runner")), \
             patch.object(paging.Path, "home", return_value=Path("/home/runner")), \
             patch.dict(os.environ, dict(env, GITHUB_WORKSPACE=str(fake_root), GUST_RELEASE_METADATA_TOKEN=token)), \
             patch.object(paging, "hosted_worker_ancestry", return_value=(current, chain)), \
             patch.object(paging, "process_identity", return_value=current), \
             patch.object(paging, "public_api", side_effect=response), \
             patch.object(paging.subprocess, "check_output", side_effect=git_value):
            if number == 0:
                assert paging.hosted_runner(token, case)["worker"] == current
                first_bytes = (case/"hosted-worker-observation-1.json").read_bytes()
                assert paging.hosted_runner(token, case)["worker"] == current
                assert (case/"hosted-worker-observation-1.json").read_bytes() == first_bytes
                assert (case/"hosted-worker-observation-2.json").is_file()
                rejected("third worker observation", lambda: paging.hosted_runner(token, case),
                         "too many hosted worker observations")
            else:
                rejected("observed wrong root still refuses", lambda: paging.hosted_runner(token, case),
                         "no live hosted worker ancestor")
        record = json.loads((case/"hosted-worker-observation-1.json").read_text())
        assert record["status"] == "OBSERVATION ONLY; hosted admission remains required"
        assert record["ancestors"] == chain and record["worker"] == current and record["checkout"] == checkout
        assert record["api_context"] == dict(run_id=42, run_attempt=2, job_id=100, runner_id=123)
        assert all(set(row) == {"pid", "start_ticks", "executable", "parent"} for row in record["ancestors"])
        raw = (case/"hosted-worker-observation-1.json").read_text()
        assert token not in raw and "GITHUB_ACTIONS" not in raw and "argv" not in raw
    case = root/"oversized-worker-observation";case.mkdir()
    rejected("worker observation size bound", lambda: paging.record_worker_observation(case,
        final, [dict(final, executable="x"*(128*1024))], run, job, checkout),
        "hosted worker observation exceeds bound")
    assert not list(case.iterdir())
    # A compact representation can fit while the actual indented bytes exceed
    # the bound. Mutate a real produced record to exercise that distinction.
    boundary = json.loads((root/"worker-observation-0/hosted-worker-observation-1.json").read_text())
    boundary["ancestors"] = [dict(first, executable="") for _ in range(64)]
    padding = 128*1024-len(json.dumps(boundary).encode())-1
    count, remainder = divmod(padding, 64)
    for i, row in enumerate(boundary["ancestors"]):row["executable"] = "x"*(count+(i < remainder))
    assert len(json.dumps(boundary).encode()) < 128*1024
    assert len((json.dumps(boundary, indent=2)+"\n").encode()) > 128*1024
    case = root/"formatted-worker-observation-boundary";case.mkdir()
    with patch.object(paging, "utc", return_value=boundary["utc"]):
        rejected("formatted observation size bound", lambda: paging.record_worker_observation(case,
            boundary["worker"], boundary["ancestors"], run, job, checkout),
            "hosted worker observation exceeds bound")
    assert not list(case.iterdir())
    print("RELEASE_WORKER_OBSERVATION_CONTROLS_PASS; wrong roots still refuse, no provisioning")


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
        metadata_api_controls(root)
        worker_observation_controls(root, env, worker, run, job, checkout)
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
