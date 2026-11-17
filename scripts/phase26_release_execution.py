#!/usr/bin/env python3
"""Run the unchanged protected cold build with bounded environment evidence."""
from __future__ import annotations

import argparse
import ctypes
import datetime
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
import uuid

import phase26_release_paging as environment


def scope_state(unit, output):
    command = ["sudo", "-n", "systemctl", "show", unit,
        "-p", "LoadState", "-p", "ActiveState", "-p", "SubState", "-p", "Result",
        "-p", "ControlGroup", "-p", "MemoryMax", "-p", "MemoryPeak",
        "-p", "MemorySwapMax", "-p", "CPUQuotaPerSecUSec"]
    result = subprocess.run(command, text=True, capture_output=True, timeout=10)
    state = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
    confirmed = (result.returncode == 0 and state.get("LoadState") in ("loaded", "not-found")
        and state.get("ActiveState") in ("active", "activating", "deactivating", "inactive", "failed")
        and "ControlGroup" in state and "Result" in state)
    absent = (result.returncode == 4 and state.get("LoadState") == "not-found" and
        state.get("ActiveState") == "inactive" and state.get("ControlGroup") == "" and
        result.stderr.strip() in ("", "Unit " + unit + " could not be found."))
    with (output/"control-plane.jsonl").open("a") as stream:
        stream.write(json.dumps(dict(utc=environment.utc(), exit=result.returncode,
            stdout=result.stdout, stderr=result.stderr, confirmed=confirmed or absent))+"\n")
    environment.require(confirmed or absent, "scope state is UNCONFIRMED")
    return state


def scope_path(state, unit):
    value = state["ControlGroup"]
    if not value:
        return None
    path = Path("/sys/fs/cgroup")/value.lstrip("/")
    environment.require(path.parent == Path("/sys/fs/cgroup/system.slice") and path.name == unit,
                        "owning scope escapes exact system-unit path")
    return path


def scope_members(path):
    if path is None:
        return []
    members = set()
    for file in [path/"cgroup.procs", *path.rglob("cgroup.procs")]:
        try:
            members.update(map(int, file.read_text().split()))
        except FileNotFoundError:
            pass
    return sorted(members)


def scope_sample(path):
    values = {}
    for name in ("memory.max", "memory.current", "memory.peak", "memory.events",
                 "memory.swap.max", "memory.swap.current", "memory.swap.peak", "cpu.max"):
        try:
            values[name] = (path/name).read_text().strip()
        except FileNotFoundError:
            pass
    if "memory.max" in values:
        environment.require(values["memory.max"].isdecimal() and
            int(values["memory.max"]) <= environment.COMPILER_CAP_BYTES,
            "compiler memory quota is not protected")
    return values


def hosted_command(hosted, unit):
    started = datetime.datetime.fromisoformat(hosted["job"]["started_at"].replace("Z", "+00:00"))
    elapsed = (datetime.datetime.now(datetime.timezone.utc)-started).total_seconds()
    remaining = int(3600-elapsed)
    environment.require(0 <= elapsed and remaining > 30,
                        "insufficient unchanged owning-job deadline")
    names = ("HOME", "PATH", "USER", "LOGNAME", "LANG", "LC_ALL", "CARGO_HOME",
             "RUSTUP_HOME", "RUSTUP_TOOLCHAIN", "CARGO_BUILD_JOBS", "GITHUB_ACTIONS")
    inherited = [name+"="+os.environ[name] for name in names if name in os.environ]
    return ["sudo", "-n", "systemd-run", "--scope", "--quiet", "--expand-environment=no",
        "--unit="+unit, "-p", "MemoryMax="+str(environment.COMPILER_CAP_BYTES),
        "-p", "CPUQuota=200%", "-p", "RuntimeMaxSec="+str(remaining), "--",
        "/usr/bin/setpriv", "--reuid="+str(os.getuid()), "--regid="+str(os.getgid()),
        "--init-groups", "--", "/usr/bin/env", "-i", *inherited,
        sys.executable, str(environment.ROOT/"scripts/phase26_release_execution.py"), "inside-build"]


def enable_subreaper():
    # Only this helper's descendants are adopted; this changes no host setting.
    result = ctypes.CDLL(None, use_errno=True).prctl(36, 1, 0, 0, 0)
    environment.require(result == 0, "cannot establish owned descendant cleanup")


def children():
    path = Path(f"/proc/self/task/{os.getpid()}/children")
    return [int(value) for value in path.read_text().split()]


def drain_local(process, output):
    actions = []
    for signum in (signal.SIGTERM, signal.SIGKILL):
        deadline = time.monotonic()+5
        while True:
            process.poll()  # Reap the primary through Popen, preserving its code.
            for pid in children():
                try:
                    if pid != process.pid:
                        reaped, _status = os.waitpid(pid, os.WNOHANG)
                        if reaped:
                            continue
                    identity = environment.process_identity(pid)
                    environment.require(identity["parent"] == os.getpid(), "cleanup child ownership changed")
                    again = environment.process_identity(pid)
                    environment.require(again == identity, "cleanup child identity changed")
                    os.kill(pid, signum)
                    actions.append(dict(pid=pid, start_ticks=identity["start_ticks"], signal=int(signum)))
                except (ProcessLookupError, FileNotFoundError):
                    pass
            process.poll()
            if not children():
                environment.write(output/"local-payload-terminal.json", dict(empty=True,
                    primary_exit=process.returncode, actions=actions))
                return True
            if time.monotonic() >= deadline:
                break
            time.sleep(0.1)
    environment.write(output/"local-payload-terminal.json", dict(empty=False, actions=actions))
    return False


def run_build(output, start, hosted, payload):
    unit = "run-r"+uuid.uuid4().hex+".scope" if hosted else None
    if unit:
        before = scope_state(unit, output)
        environment.require(before["LoadState"] == "not-found", "new scope is not fresh")
        command = hosted_command(hosted, unit)
    else:
        environment.require(environment.effective_memory_cap() == environment.COMPILER_CAP_BYTES,
                            "local reproduction requires its real protected scope")
        command = [sys.executable, "scripts/phase26_release_execution.py", "inside-build"]
    environment.write(output/"command.json", dict(actual=command,
        protected=environment.COMMAND, unit=unit, quota_bytes=environment.COMPILER_CAP_BYTES))
    process = None
    path = None
    payload["empty"] = False

    enable_subreaper()
    try:
        with (output/"build.log").open("x") as log, (output/"samples.jsonl").open("x") as samples:
            process = subprocess.Popen(command, cwd=environment.ROOT, stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            while True:
                if unit:
                    state = scope_state(unit, output)
                    path = scope_path(state, unit)
                else:
                    state = None
                    path = environment.membership("self")
                record = dict(utc=environment.utc(), state=state, disk=environment.check_disk(start))
                if path and path.exists():
                    record["cgroup"] = scope_sample(path)
                samples.write(json.dumps(record)+"\n")
                samples.flush()
                if process.poll() is not None:
                    break
                time.sleep(1)
        code = process.returncode
    finally:
        if unit:
            state = scope_state(unit, output)
            path = scope_path(state, unit)
            if state["ActiveState"] in ("active", "activating", "deactivating") or scope_members(path):
                with (output/"scope-stop.log").open("x") as stream:
                    environment.checked_run(["sudo", "-n", "systemctl", "stop", unit],
                                            stdout=stream, stderr=subprocess.STDOUT, timeout=100)
                state = scope_state(unit, output)
                path = scope_path(state, unit)
            if process is not None and process.poll() is None:
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    # The scope can materialize after an early cancellation.
                    # Its exact generated identity was absent before our start.
                    with (output/"late-scope-stop.log").open("x") as stream:
                        environment.checked_run(["sudo", "-n", "systemctl", "stop", unit],
                            stdout=stream, stderr=subprocess.STDOUT, timeout=100)
                    process.wait(timeout=15)
            state = scope_state(unit, output)
            path = scope_path(state, unit)
            payload["empty"] = (process is not None and process.poll() is not None and
                not scope_members(path) and state["ActiveState"] in ("inactive", "failed"))
            environment.write(output/"scope-terminal.json", dict(state=state, empty=payload["empty"]))
        elif process is not None:
            payload["empty"] = drain_local(process, output)
        if process is not None and process.poll() is None:
            process.wait(timeout=15)
        environment.require(payload["empty"], "owned build payload termination is UNCONFIRMED")
    environment.write(output/"build-result.json", dict(exit=code, payload_empty=payload["empty"],
        unit=unit, protected_command=environment.COMMAND,
        log_sha256=environment.sha(output/"build.log")))
    return code


def inside_build():
    environment.require(environment.effective_memory_cap() == environment.COMPILER_CAP_BYTES,
                        "inside build lacks its protected memory quota")
    group = environment.membership("self")
    environment.require((group/"cpu.max").read_text().strip() == "200000 100000",
                        "inside build lacks its existing two-CPU bound")
    environment.require(environment.paging_capacity(group) >= environment.MINIMUM_PAGING,
                        "effective ancestor paging capacity is below the chosen precondition")
    output = environment.ROOT/"build/guards/phase26_release_execution"
    environment.require((output/"context.json").is_file(), "inside build is unprepared")
    environment.write(output/"inside-profile.json", dict(utc=environment.utc(),
        cgroup=str(group), profile=scope_sample(group), memory=environment.meminfo(),
        effective_paging_available=environment.paging_capacity(group),
        protected_command=environment.COMMAND))
    os.execvp(environment.COMMAND[0], environment.COMMAND)


def build(output):
    output = (environment.ROOT/output).resolve()
    environment.require(output == environment.ROOT/"build/guards/phase26_release_execution" and
                        not output.exists(), "evidence directory is not fresh and owned")
    environment.require(not (environment.ROOT/"gust").exists(), "cached native build is not qualification")
    output.mkdir(parents=True)
    start = environment.allocated()
    environment.check_disk(start)
    hosted = environment.hosted_runner() if os.environ.get("GITHUB_ACTIONS") == "true" else None
    environment.write(output/"context.json", dict(utc=environment.utc(), hosted=hosted,
        memory=environment.meminfo(), current_cgroup=str(environment.membership("self")),
        quota_bytes=environment.COMPILER_CAP_BYTES, paging_target_bytes=environment.TARGET_PAGING))
    paging = environment.Paging(output, start)
    payload = {"empty": True}
    code = 1
    lifecycle = {"cleanup": False, "canceled": False}

    def cancel(signum, _frame):
        lifecycle["canceled"] = True
        if not lifecycle["cleanup"]:
            # A preparation utility might have been interrupted. Only the
            # build supervisor may subsequently establish positive emptiness.
            payload["empty"] = False
            raise InterruptedError("owning build lifecycle interrupted by signal " + str(signum))

    previous = {sig: signal.signal(sig, cancel) for sig in (signal.SIGTERM, signal.SIGINT)}
    try:
        paging.prepare(hosted)
        code = run_build(output, start, hosted, payload)
        environment.require(code == 0, "actual protected build failed: " + str(code))
        text = (output/"build.log").read_text()
        environment.require("./build/native-build/bin/gust --backend cranelift -o build/.gust.tmp "
            "compiler/test_runner_entry.gst" in text and (environment.ROOT/"gust").is_file(),
            "protected bridge compilation did not actually complete")
    except BaseException as error:
        environment.write(output/"failure.json", dict(utc=environment.utc(),
            error_type=type(error).__name__, message=str(error), payload_empty=payload["empty"]))
        raise
    finally:
        lifecycle["cleanup"] = True
        try:
            paging.cleanup(payload["empty"])
            environment.write(output/"terminal-disk.json", environment.check_disk(start))
        except BaseException as error:
            environment.write(output/"cleanup-failure.json", dict(utc=environment.utc(),
                error_type=type(error).__name__, message=str(error), payload_empty=payload["empty"]))
            raise
        finally:
            for sig, handler in previous.items():
                signal.signal(sig, handler)
    environment.require(not lifecycle["canceled"], "owning build lifecycle was canceled")
    environment.write(output/"result.json", dict(status="PASS actual protected cold build environment",
        exit=code, payload_empty=payload["empty"], paging_released=True,
        limitation="The preceding CI kill cause remains unclassified; this is no quota increase."))


def controls():
    from phase26_release_execution_controls import controls as run_controls
    run_controls()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("build", "inside-build", "controls"))
    parser.add_argument("output", nargs="?", type=Path)
    args = parser.parse_args()
    if args.mode == "controls":
        environment.require(args.output is None, "controls do not accept a build directory")
        controls()
    elif args.mode == "inside-build":
        environment.require(args.output is None, "inside build does not accept substitute arguments")
        inside_build()
    else:
        environment.require(args.output is not None, "missing evidence directory")
        build(args.output)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        raise SystemExit(str(error))
