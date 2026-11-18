#!/usr/bin/env python3
"""Measured cold-build environment; the enrolled launcher still enforces 4 GiB.

Job-owned paging is permitted only on the authenticated ephemeral owning runner.
It is counted as disk growth, never RAM, and released before the R5 recipe.
"""
from __future__ import annotations

import datetime
import hashlib
import json
import os
from pathlib import Path
import pwd
import re
import stat
import subprocess
import time
import urllib.error
import urllib.request

from phase26_release_bounded import COMPILER_CAP_BYTES, effective_memory_cap

ROOT = Path(__file__).resolve().parents[1]
MINIMUM_PAGING = 1152 * 1024 ** 2
TARGET_PAGING = 1200 * 1024 ** 2
MAX_NEW_PAGING = 1280 * 1024 ** 2
GROWTH_BUDGET = 2 * 1024 ** 3
DISK_RESERVE = 2 * 1024 ** 3
HOST_RESERVE = 1536 * 1024 ** 2
COMMAND = ["python3", "scripts/phase26_release_bounded.py", "make", "gust"]
WORKFLOW = ".github/workflows/phase26-release-closure.yml"
METADATA_TOKEN = "GUST_RELEASE_METADATA_TOKEN"


def require(condition, message):
    if not condition:
        raise ValueError("release execution environment: " + message)


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def write(path, value):
    with path.open("x") as stream:
        json.dump(value, stream, indent=2)
        stream.write("\n")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def checked_run(command, **kwargs):
    return subprocess.run(list(map(str, command)), check=True, **kwargs)


def meminfo():
    values = {}
    for line in Path("/proc/meminfo").read_text().splitlines():
        name, value = line.split(":", 1)
        if name in ("MemAvailable", "SwapTotal", "SwapFree"):
            fields = value.split()
            require(len(fields) == 2 and fields[1] == "kB", "unknown memory units")
            values[name] = int(fields[0]) * 1024
    require(len(values) == 3, "incomplete memory observation")
    return values


def membership(pid):
    lines = Path(f"/proc/{pid}/cgroup").read_text().splitlines()
    groups = [line[3:] for line in lines if line.startswith("0::")]
    require(len(groups) == 1 and groups[0].startswith("/") and
            ".." not in Path(groups[0]).parts, "invalid cgroup membership")
    return Path("/sys/fs/cgroup") / groups[0].lstrip("/")


def paging_limit_remaining(group):
    available = None
    while True:
        maximum = group / "memory.swap.max"
        current = group / "memory.swap.current"
        if maximum.is_file():
            limit = maximum.read_text().strip()
            if limit != "max":
                require(limit.isdecimal() and current.is_file(), "unknown paging limit")
                remaining = max(int(limit) - int(current.read_text()), 0)
                available = remaining if available is None else min(available, remaining)
        if group == Path("/sys/fs/cgroup"):
            return available
        group = group.parent


def paging_capacity(group):
    limit = paging_limit_remaining(group)
    available = meminfo()["SwapFree"]
    return available if limit is None else min(available, limit)


def process_identity(pid):
    directory = Path("/proc") / str(pid)
    before = (directory / "stat").read_text().split()[21]
    executable = (directory / "exe").resolve(strict=True)
    fields = dict(line.split(":", 1) for line in
                  (directory / "status").read_text().splitlines() if ":" in line)
    require((directory / "stat").read_text().split()[21] == before,
            "process identity changed during inspection")
    return dict(pid=pid, start_ticks=before, executable=str(executable),
                parent=int(fields["PPid"].strip()))


class NoMetadataRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, url):
        # Authorization must never leave this fixed API origin, even by redirect.
        return None


def public_api(path, token, output):
    require(re.fullmatch(r"actions/runs/[0-9]+(?:/jobs\?per_page=100)?", path) is not None,
            "unqualified public metadata endpoint")
    require(isinstance(token, str) and 0 < len(token) <= 4096 and token.isascii() and
            not re.search(r"\s", token), "missing or invalid automatic metadata credential")
    url = "https://api.github.com/repos/garthtrickett/gust/" + path
    request = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json",
        "User-Agent": "gust-release-execution", "Authorization": "Bearer " + token})
    record = dict(utc=utc(), endpoint=path, authenticated=True)
    try:
        with urllib.request.build_opener(NoMetadataRedirect()).open(request, timeout=30) as response:
            record["status"] = response.status
            require(response.status == 200, "unexpected public metadata response status")
            require(response.geturl() == url, "public metadata response changed origin or endpoint")
            raw = response.read(2 * 1024 ** 2 + 1)
        require(len(raw) <= 2 * 1024 ** 2, "public provenance response exceeds bound")
        return json.loads(raw)
    except urllib.error.HTTPError as error:
        record["status"] = error.code
        record["rate_limit"] = {name: (int(error.headers[name]) if error.headers[name].isdecimal()
            else "unparsed") for name in (
            "X-RateLimit-Limit", "X-RateLimit-Remaining", "X-RateLimit-Reset", "Retry-After")
            if error.headers and name in error.headers}
        raise ValueError("release execution environment: public metadata request failed: " +
                         path + " HTTP " + str(error.code)) from None
    except (OSError, ValueError) as error:
        record["error_type"] = type(error).__name__
        raise ValueError("release execution environment: public metadata response unavailable or invalid: " +
                         path) from None
    finally:
        # Never persist a request, authorization header, credential or error body.
        with (output/"public-api.jsonl").open("a") as stream:
            stream.write(json.dumps(record)+"\n")


def validate_runner_evidence(environment, worker, run, jobs, checkout):
    require(environment.get("GITHUB_ACTIONS") == "true" and
            environment.get("RUNNER_ENVIRONMENT") == "github-hosted" and
            environment.get("RUNNER_OS") == "Linux" and
            environment.get("GITHUB_REPOSITORY") == "garthtrickett/gust" and
            environment.get("GITHUB_REPOSITORY_ID") == "1263612197" and
            environment.get("GITHUB_JOB") == "qualification", "not the owning hosted runner")
    executable = Path(worker["executable"])
    require(executable.name == "Runner.Worker" and
            executable.is_relative_to("/home/runner/runners"), "no live hosted worker ancestor")
    require(run["id"] == int(environment["GITHUB_RUN_ID"]) and
            run["run_attempt"] == int(environment["GITHUB_RUN_ATTEMPT"]) and
            run["repository"]["id"] == 1263612197 and
            run["actor"]["id"] == 3760677 and run["path"] == WORKFLOW and
            run["event"] in ("pull_request", "push", "workflow_dispatch") and
            (run["head_branch"] == "main" or run["head_branch"].startswith("codex/")) and
            run["status"] == "in_progress", "owning public run provenance mismatch")
    # This owning gate qualifies the PR HEAD tree. Authenticated merge parents
    # do not authorize extra main-tree bytes; those need rebase/requalification.
    require(checkout["head"] == environment["GITHUB_SHA"] and
            checkout["tree"] == run["head_commit"]["tree_id"],
            "checkout differs from the exact owning source tree")
    if checkout["head"] != run["head_sha"]:
        requests = run["pull_requests"]
        require(run["event"] == "pull_request" and len(requests) == 1 and
                requests[0]["head"]["sha"] == run["head_sha"] and
                requests[0]["head"]["repo"]["id"] == 1263612197 and
                requests[0]["base"]["repo"]["id"] == 1263612197 and
                requests[0]["base"]["ref"] == "main" and
                len(checkout["parents"]) == 2 and set(checkout["parents"]) ==
                {run["head_sha"], requests[0]["base"]["sha"]},
                "checkout is not the authenticated owning merge tree")
    current = [job for job in jobs if job["name"] == "qualification" and
               job["run_attempt"] == run["run_attempt"] and job["status"] == "in_progress"]
    require(len(current) == 1, "ambiguous or absent current owning job")
    job = current[0]
    require(job["run_id"] == run["id"] and job["head_sha"] == run["head_sha"] and
            job["runner_id"] > 0 and job["runner_name"] == environment.get("RUNNER_NAME") and
            job["runner_group_name"] == "GitHub Actions" and
            job["labels"] == ["ubuntu-24.04"], "owning runner/job provenance mismatch")
    return job


def hosted_runner(token, output):
    require(os.getuid() != 0 and pwd.getpwuid(os.getuid()).pw_name == "runner" and
            Path.home() == Path("/home/runner") and
            ROOT == Path(os.environ.get("GITHUB_WORKSPACE", "")).resolve() and
            ROOT.is_relative_to("/home/runner/work"), "shared-host provisioning is forbidden")
    pid = os.getpid()
    worker = None
    while pid > 1:
        identity = process_identity(pid)
        if Path(identity["executable"]).name == "Runner.Worker":
            worker = identity
            break
        pid = identity["parent"]
    require(worker is not None, "no live Runner.Worker ancestor")
    names = ("GITHUB_ACTIONS", "RUNNER_ENVIRONMENT", "RUNNER_OS", "GITHUB_REPOSITORY",
             "GITHUB_REPOSITORY_ID", "GITHUB_JOB", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT",
             "GITHUB_SHA", "RUNNER_NAME")
    environment = {name: os.environ.get(name, "") for name in names}
    require(environment["GITHUB_RUN_ID"].isdecimal() and
            environment["GITHUB_RUN_ATTEMPT"].isdecimal(), "invalid owning run identifiers")
    run = public_api("actions/runs/" + environment["GITHUB_RUN_ID"], token, output)
    jobs = public_api("actions/runs/" + environment["GITHUB_RUN_ID"] + "/jobs?per_page=100", token, output)
    require(jobs["total_count"] == len(jobs["jobs"]) == 1, "unexpected owning job population")
    def git(*arguments):
        return subprocess.check_output(["git", *arguments], cwd=ROOT, text=True).strip()
    checkout = dict(head=git("rev-parse", "HEAD"), tree=git("rev-parse", "HEAD^{tree}"),
                    parents=git("rev-list", "--parents", "-n1", "HEAD").split()[1:])
    job = validate_runner_evidence(environment, worker, run, jobs["jobs"], checkout)
    require(process_identity(worker["pid"]) == worker, "hosted worker identity changed")
    return dict(environment=environment, worker=worker, run=run, job=job, checkout=checkout)


def allocated():
    paths = [ROOT / name for name in ("build", "src/runtime-rs/target",
             "compiler/experiments/cranelift/target", "gust", "gust_bootstrap",
             "gust-native-backend", "gust-runtime-package.a", "to.log") if (ROOT/name).exists()]
    require(all(not path.is_symlink() and path.resolve().is_relative_to(ROOT) for path in paths),
            "owned output root escapes worktree")
    if not paths:
        return 0
    result = subprocess.check_output(["du", "-s", "-B1", "--", *map(str, paths)], text=True)
    return sum(int(line.split()[0]) for line in result.splitlines())


def check_disk(start):
    growth = max(allocated() - start, 0)
    filesystem = os.statvfs(ROOT)
    free = filesystem.f_bavail * filesystem.f_frsize
    require(growth <= GROWTH_BUDGET and free >= GROWTH_BUDGET - growth + DISK_RESERVE,
            "owned disk growth or reserve exhausted")
    return dict(growth_bytes=growth, growth_budget_bytes=GROWTH_BUDGET,
                available_bytes=free, reserve_bytes=DISK_RESERVE)


def swap_rows():
    lines = Path("/proc/swaps").read_text().splitlines()
    require(lines and lines[0].split() == ["Filename", "Type", "Size", "Used", "Priority"],
            "unknown paging table")
    result = {}
    for line in lines[1:]:
        fields = line.split()
        require(len(fields) == 5 and "\\" not in fields[0], "unrecognized paging path")
        result[fields[0]] = dict(kind=fields[1], size_bytes=int(fields[2])*1024,
                               used_bytes=int(fields[3])*1024, priority=int(fields[4]))
    return result


def preserved_swaps(before, after):
    stable = ("kind", "size_bytes", "priority")
    return all(name in after and all(after[name][key] == value[key] for key in stable)
               for name, value in before.items())


class Paging:
    def __init__(self, output, start):
        self.output, self.start = output, start
        self.file = ROOT/"build/guards/phase26_release_execution_paging/swapfile"
        self.identity = None
        self.before = swap_rows()

    def prepare(self, hosted, token=None):
        require(not self.file.parent.exists() and not self.file.parent.is_symlink(),
                "unowned prior paging directory must remain untouched")
        available = paging_capacity(membership("self"))
        write(self.output/"paging-before.json", dict(utc=utc(), memory=meminfo(),
              effective_available_bytes=available, target_bytes=TARGET_PAGING,
              existing=self.before, disk=check_disk(self.start)))
        if available >= TARGET_PAGING:
            return
        require(hosted is not None, "insufficient existing paging outside ephemeral owning CI")
        verified = hosted_runner(token, self.output)
        require(isinstance(hosted, dict) and all(name in hosted for name in
                ("environment", "worker", "checkout", "job", "run")) and
                all(hosted[name] == verified[name] for name in ("environment", "worker", "checkout")) and
                hosted["job"]["id"] == verified["job"]["id"] and
                hosted["run"]["run_attempt"] == verified["run"]["run_attempt"],
                "paging provisioning lacks current verified owning context")
        limit = paging_limit_remaining(membership("self"))
        require(limit is None or limit >= TARGET_PAGING,
                "ancestor paging limit cannot establish the chosen precondition")
        required = TARGET_PAGING - available + os.sysconf("SC_PAGE_SIZE")
        amount = ((required+1024**2-1)//1024**2)*1024**2
        require(0 < amount <= MAX_NEW_PAGING and
                max(allocated()-self.start, 0)+amount <= GROWTH_BUDGET,
                "paging allocation exceeds chosen disk bound")
        require(not self.file.parent.exists(), "paging directory is not fresh")
        self.file.parent.mkdir(mode=0o700)
        descriptor = os.open(self.file, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        try:
            os.posix_fallocate(descriptor, 0, amount)
            os.fsync(descriptor)
        finally:
            state = os.fstat(descriptor)
            self.identity = dict(device=state.st_dev, inode=state.st_ino, uid=state.st_uid,
                                 bytes=state.st_size)
            os.close(descriptor)
            write(self.output/"owned-paging.json", dict(path=str(self.file), **self.identity))
        state = self.file.lstat()
        self.check_identity()
        require(state.st_blocks*512 >= amount, "paging file is sparse")
        check_disk(self.start)
        with (self.output/"paging-activation.log").open("x") as log:
            checked_run(["sudo", "-n", "chown", "--no-dereference", "0:0", self.file],
                        stdout=log, stderr=subprocess.STDOUT)
            promoted = self.file.lstat()
            require(promoted.st_dev == self.identity["device"] and
                    promoted.st_ino == self.identity["inode"] and
                    promoted.st_size == self.identity["bytes"] and promoted.st_uid == 0,
                    "paging ownership transition changed its exact inode")
            self.identity["uid"] = 0
            self.check_identity()
            write(self.output/"active-paging-identity.json", dict(path=str(self.file), **self.identity))
            checked_run(["sudo", "-n", "mkswap", self.file], stdout=log, stderr=subprocess.STDOUT)
            checked_run(["sudo", "-n", "swapon", self.file], stdout=log, stderr=subprocess.STDOUT)
        rows = swap_rows()
        require(preserved_swaps(self.before, rows),
                "existing paging changed during provisioning")
        require(str(self.file) in rows and paging_capacity(membership("self")) >= TARGET_PAGING,
                "bounded paging activation did not establish the chosen precondition")

    def check_identity(self):
        state = self.file.lstat()
        require(stat.S_ISREG(state.st_mode) and stat.S_IMODE(state.st_mode) == 0o600 and
                self.file.resolve() == self.file and state.st_uid in (os.getuid(), 0) and
                dict(device=state.st_dev, inode=state.st_ino, uid=state.st_uid,
                     bytes=state.st_size) == self.identity, "owned paging identity changed")

    def cleanup(self, payload_empty):
        require(payload_empty, "payload emptiness is unconfirmed; paging retained")
        if self.identity is None:
            require(not self.file.exists() and not self.file.is_symlink(),
                    "unconfirmed partial paging allocation retained")
            write(self.output/"paging-cleanup.json", dict(status="PASS no job-owned paging created"))
            return
        self.check_identity()
        rows = swap_rows()
        if str(self.file) in rows:
            require(meminfo()["MemAvailable"] >= rows[str(self.file)]["used_bytes"]+HOST_RESERVE,
                    "paging release cannot preserve host RAM reserve; file retained")
            with (self.output/"paging-release.log").open("x") as log:
                checked_run(["sudo", "-n", "swapoff", self.file], stdout=log,
                            stderr=subprocess.STDOUT, timeout=120)
        require(str(self.file) not in swap_rows(), "owned paging still active; file retained")
        self.check_identity()
        self.file.unlink()
        self.file.parent.rmdir()
        write(self.output/"paging-cleanup.json", dict(status="PASS exact owned paging released",
              original_identity=self.identity, path=str(self.file)))
