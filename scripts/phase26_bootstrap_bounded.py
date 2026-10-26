#!/usr/bin/env python3
"""Run only the N-1 compiler bootstrap under its approved execution profile."""
from __future__ import annotations
import os
from pathlib import Path
import re
import sys

BOOTSTRAP_CAP_BYTES = 6 * 1024 ** 3
BUILD_COMMANDS = (("make", "gust"), ("make", "-j2", "gust"))
ENVIRONMENT = ("HOME", "PATH", "USER", "LOGNAME", "LANG", "LC_ALL",
               "CARGO_HOME", "RUSTUP_HOME", "RUSTUP_TOOLCHAIN",
               "GITHUB_ACTIONS", "GUST_BOOTSTRAP_SEED")


def checked_limits(values, required):
    finite = []
    for value in values:
        if value == "max":
            continue
        if not re.fullmatch(r"0|[1-9][0-9]*", value):
            raise ValueError("bootstrap controller limit is invalid")
        finite.append(int(value))
    if not finite or min(finite) != required:
        raise ValueError("bootstrap requires effective 6 GiB RAM and zero swap")
    return required



def checked_cpu_limits(values):
    bounded = False
    for value in values:
        parts = value.split()
        if len(parts) != 2 or not re.fullmatch(r"[1-9][0-9]*", parts[1]):
            raise ValueError("bootstrap CPU limit is invalid")
        quota, period = parts
        if quota == "max":
            continue
        if not re.fullmatch(r"[1-9][0-9]*", quota):
            raise ValueError("bootstrap CPU limit is invalid")
        if int(quota) <= 2 * int(period):
            bounded = True
    if not bounded:
        raise ValueError("bootstrap requires a CPU quota at most two CPUs")


def effective_profile():
    mount = Path("/sys/fs/cgroup").resolve()
    entries = [line.removeprefix("0::") for line in
               Path("/proc/self/cgroup").read_text().splitlines() if line.startswith("0::")]
    if len(entries) != 1 or "memory" not in (mount / "cgroup.controllers").read_text().split():
        raise ValueError("bootstrap requires the unified memory controller")
    membership = Path(entries[0])
    if not membership.is_absolute() or ".." in membership.parts:
        raise ValueError("bootstrap cgroup membership is invalid")
    current = (mount / str(membership).lstrip("/")).resolve()
    if not current.is_relative_to(mount):
        raise ValueError("bootstrap cgroup membership escapes the controller mount")
    limits = {"memory.max": [], "memory.swap.max": [], "cpu.max": []}
    while True:
        for name, values in limits.items():
            path = current / name
            if path.is_file():
                values.append(path.read_text().strip())
            elif current != mount:
                raise ValueError("bootstrap controller limit is missing")
        if current == mount:
            break
        current = current.parent
    checked_cpu_limits(limits["cpu.max"])
    return (checked_limits(limits["memory.max"], BOOTSTRAP_CAP_BYTES),
            checked_limits(limits["memory.swap.max"], 0))


def checked_command(command):
    if tuple(command) not in BUILD_COMMANDS:
        raise ValueError("bootstrap profile accepts only canonical make gust commands")
    return command


def build_environment(source):
    result = {name: source[name] for name in ENVIRONMENT if name in source}
    result["CARGO_BUILD_JOBS"] = "2"
    return result


def inversions():
    assert BOOTSTRAP_CAP_BYTES == 6442450944, 'operator bootstrap execution cap drifted'
    checked_limits(["max", str(BOOTSTRAP_CAP_BYTES), str(BOOTSTRAP_CAP_BYTES * 2)], BOOTSTRAP_CAP_BYTES)
    checked_limits(["max", "0"], 0)
    checked_cpu_limits(["max 100000", "200000 100000"])
    controls = [("unbounded CPU", lambda: checked_cpu_limits(["max 100000"])),
        ("raised CPU", lambda: checked_cpu_limits(["200001 100000"])),
        ("missing CPU", lambda: checked_cpu_limits([])),
        ("invalid CPU", lambda: checked_cpu_limits(["zero 100000"])),
        ("missing memory", lambda: checked_limits([], BOOTSTRAP_CAP_BYTES)),
        ("unbounded memory", lambda: checked_limits(["max"], BOOTSTRAP_CAP_BYTES)),
        ("raised memory", lambda: checked_limits([str(BOOTSTRAP_CAP_BYTES + 1)], BOOTSTRAP_CAP_BYTES)),
        ("tighter ancestor", lambda: checked_limits([str(BOOTSTRAP_CAP_BYTES), str(4 * 1024 ** 3)], BOOTSTRAP_CAP_BYTES)),
        ("invalid memory", lambda: checked_limits(["unknown"], BOOTSTRAP_CAP_BYTES)),
        ("missing swap", lambda: checked_limits([], 0)),
        ("unbounded swap", lambda: checked_limits(["max"], 0)),
        ("nonzero swap", lambda: checked_limits(["1"], 0))]
    for command in (("just", "guard-cranelift-phase26-release-closure"),
                    ("make", "-j3", "gust"), ("make", "gust", "CC=other"),
                    ("make", "-f", "other", "gust"), ("sh", "-c", "make gust")):
        controls.append(("noncanonical command " + " ".join(command),
                         lambda command=command: checked_command(command)))
    for label, callback in controls:
        try:
            callback()
        except ValueError:
            print(label + ": REJECTED (expected assertion)")
        else:
            raise ValueError(label + ": ACCEPTED")
    for command in BUILD_COMMANDS:
        checked_command(command)
    forbidden = ("MAKEFLAGS", "MAKEFILES", "MAKEOVERRIDES", "MFLAGS", "GNUMAKEFLAGS")
    environment = build_environment(dict.fromkeys(forbidden, "override"))
    assert not any(name in environment for name in forbidden)
    assert environment["CARGO_BUILD_JOBS"] == "2"
    import phase26_release_bounded as release
    assert release.COMPILER_CAP_BYTES == 4 * 1024 ** 3
    try:
        release.checked_limit([str(BOOTSTRAP_CAP_BYTES)])
    except ValueError:
        print("six GiB qualification: REJECTED (expected assertion)")
    else:
        raise ValueError("six GiB qualification: ACCEPTED")
    execution_path_controls()
    print("BOOTSTRAP_EXECUTION_PROFILE_INVERSIONS_PASS")



def execution_path_controls():
    from unittest.mock import patch
    import contextlib
    import io
    class Executed(Exception):
        pass
    environment = {"GITHUB_ACTIONS": "true", "PATH": "/usr/bin", "HOME": "/home/builder",
                   "MAKEFLAGS": "override", "MAKEFILES": "foreign", "CARGO_BUILD_JOBS": "99"}
    with patch.dict(os.environ, environment, clear=True), patch.object(os, "getuid", return_value=1000), patch.object(os, "getgid", return_value=1000), contextlib.redirect_stdout(io.StringIO()):
        with patch.object(sys, "argv", ["bootstrap", "make", "gust"]), patch(__name__ + ".effective_profile", return_value=(BOOTSTRAP_CAP_BYTES, 0)), patch.object(os, "execvpe", side_effect=Executed) as execute:
            try:
                main()
            except Executed:
                pass
            else:
                raise ValueError("already-scoped bootstrap did not execute")
            arguments = execute.call_args.args
            assert arguments[:2] == ("make", ["make", "gust"])
            assert arguments[2] == build_environment(environment)
        with patch.object(sys, "argv", ["bootstrap", "make", "-j2", "gust"]), patch(__name__ + ".effective_profile", side_effect=ValueError("unbounded")), patch.object(os, "execvp", side_effect=Executed) as enter:
            try:
                main()
            except Executed:
                pass
            else:
                raise ValueError("CI bootstrap did not enter a bounded scope")
            program, arguments = enter.call_args.args
            assert program == "sudo" and arguments[:3] == ["sudo", "-n", "systemd-run"]
            assert "MemoryMax=" + str(BOOTSTRAP_CAP_BYTES) in arguments
            assert "MemorySwapMax=0" in arguments and "CPUQuota=200%" in arguments
            assert arguments.index("/usr/bin/setpriv") < arguments.index("/usr/bin/env")
            assert "--reuid=1000" in arguments and "--regid=1000" in arguments
            assert arguments[-4:] == ["--inside", "make", "-j2", "gust"]
            assert not any(item.startswith(("MAKEFLAGS=", "MAKEFILES=")) for item in arguments)
            assert "CARGO_BUILD_JOBS=2" in arguments
        with patch.object(sys, "argv", ["bootstrap", "--inside", "make", "gust"]), patch(__name__ + ".effective_profile", side_effect=ValueError("wrong inside limits")), patch.object(os, "execvp") as enter, patch.object(os, "execvpe") as execute:
            try:
                main()
            except ValueError:
                pass
            else:
                raise ValueError("wrong inside limits were accepted")
            assert not enter.called and not execute.called
        with patch.object(sys, "argv", ["bootstrap", "make", "gust"]), patch(__name__ + ".effective_profile", return_value=(BOOTSTRAP_CAP_BYTES, 0)), patch.object(os, "getuid", return_value=0), patch.object(os, "execvpe") as execute:
            try:
                main()
            except ValueError:
                pass
            else:
                raise ValueError("root repository execution was accepted")
            assert not execute.called
    print("BOOTSTRAP_EXECUTION_PATH_CONTROLS_PASS")


def main():
    command = sys.argv[1:]
    if command == ["inversions"]:
        inversions()
        return
    inside = bool(command and command[0] == "--inside")
    if inside:
        command = command[1:]
    checked_command(command)
    environment = build_environment(os.environ)
    try:
        cap, swap = effective_profile()
    except ValueError:
        if inside or os.environ.get("GITHUB_ACTIONS") != "true":
            raise
    else:
        if os.getuid() == 0:
            raise ValueError("bootstrap repository code must run as the original non-root user")
        print("BOOTSTRAP_EFFECTIVE_MEMORY_CAP_BYTES=" + str(cap), flush=True)
        print("BOOTSTRAP_EFFECTIVE_SWAP_CAP_BYTES=" + str(swap), flush=True)
        os.execvpe(command[0], command, environment)
    args = ["sudo", "-n", "systemd-run", "--scope", "--quiet", "--expand-environment=no",
            "-p", "MemoryMax=" + str(BOOTSTRAP_CAP_BYTES), "-p", "MemorySwapMax=0",
            "-p", "CPUQuota=200%", "--", "/usr/bin/setpriv",
            "--reuid=" + str(os.getuid()), "--regid=" + str(os.getgid()),
            "--init-groups", "--", "/usr/bin/env", "-i",
            *(name + "=" + value for name, value in environment.items()),
            sys.executable, str(Path(__file__).resolve()), "--inside", *command]
    os.execvp(args[0], args)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        raise SystemExit("bootstrap bounded execution: " + str(error))
