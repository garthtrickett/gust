#!/usr/bin/env python3
"""Keep the release compiler and owning recipe within a real 4 GiB cgroup."""
from __future__ import annotations
import os
from pathlib import Path
import re
import sys

COMPILER_CAP_BYTES = 4 * 1024 ** 3


def checked_limit(values):
    finite = []
    for value in values:
        if value == "max":
            continue
        if not re.fullmatch(r"[1-9][0-9]*", value):
            raise ValueError("release memory limit cannot be established")
        finite.append(int(value))
    result = min(finite) if finite else None
    if result is None or result > COMPILER_CAP_BYTES:
        raise ValueError("release execution requires an effective memory cap at most 4 GiB")
    return result


def effective_memory_cap():
    mount = Path("/sys/fs/cgroup").resolve()
    entries = [line.removeprefix("0::") for line in
               Path("/proc/self/cgroup").read_text().splitlines() if line.startswith("0::")]
    if len(entries) != 1 or "memory" not in (mount / "cgroup.controllers").read_text().split():
        raise ValueError("release execution requires the unified memory controller")
    membership = entries[0]
    if not membership.startswith("/") or ".." in Path(membership).parts:
        raise ValueError("release cgroup membership is not an absolute controller path")
    current = (mount / membership.lstrip("/")).resolve()
    if not current.is_relative_to(mount):
        raise ValueError("release cgroup membership escapes its controller mount")
    values = []
    while True:
        limit = current / "memory.max"
        if limit.is_file():
            values.append(limit.read_text().strip())
        elif current != mount:
            raise ValueError("release cgroup memory limit is absent")
        if current == mount:
            break
        current = current.parent
    return checked_limit(values)


def inversions():
    assert checked_limit(["max", str(COMPILER_CAP_BYTES), str(COMPILER_CAP_BYTES * 2)]) == COMPILER_CAP_BYTES
    assert checked_limit([str(COMPILER_CAP_BYTES), str(COMPILER_CAP_BYTES // 2)]) == COMPILER_CAP_BYTES // 2
    for label, values in (("unbounded", ["max"]), ("missing", []),
                          ("raised", [str(COMPILER_CAP_BYTES + 1)]),
                          ("zero", ["0"]), ("invalid", ["unknown"])):
        try:
            checked_limit(values)
        except ValueError:
            print(label + ": REJECTED (expected assertion)")
        else:
            raise ValueError(label + ": ACCEPTED")
    print("RELEASE_MEMORY_LIMIT_INVERSIONS_PASS")


def main():
    command = sys.argv[1:]
    if command == ["inversions"]:
        inversions()
        return
    inside = bool(command and command[0] == "--inside")
    if inside:
        command = command[1:]
    if not command:
        raise ValueError("release bounded launcher needs a command")
    os.environ.setdefault("CARGO_BUILD_JOBS", "2")
    try:
        cap = effective_memory_cap()
    except ValueError:
        if inside or os.environ.get("GITHUB_ACTIONS") != "true":
            raise
    else:
        print("RELEASE_EFFECTIVE_MEMORY_CAP_BYTES=" + str(cap), flush=True)
        os.execvp(command[0], command)
    # The hosted runner already supplies passwordless sudo. Use it only for a
    # transient scope, then restore the original uid/gid before repository code.
    # Keep existing sudo-unshare available to the owning offline guard; compiled
    # programs still receive that guard's separate no-new-privileges boundary.
    environment = {name: os.environ[name] for name in
        ("HOME", "PATH", "USER", "LOGNAME", "LANG", "LC_ALL", "CARGO_HOME",
         "RUSTUP_HOME", "RUSTUP_TOOLCHAIN", "CARGO_BUILD_JOBS", "GITHUB_ACTIONS")
        if name in os.environ}
    args = ["sudo", "-n", "systemd-run", "--scope", "--quiet", "--expand-environment=no",
            "-p", "MemoryMax=" + str(COMPILER_CAP_BYTES), "-p", "CPUQuota=200%", "--",
            "/usr/bin/setpriv", "--reuid=" + str(os.getuid()),
            "--regid=" + str(os.getgid()), "--init-groups", "--",
            "/usr/bin/env", "-i", *(name + "=" + value for name, value in environment.items()),
            sys.executable, str(Path(__file__).resolve()), "--inside", *command]
    os.execvp(args[0], args)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        raise SystemExit("release bounded execution: " + str(error))
