#!/usr/bin/env python3
"""Observe the signed R2 caller fixture's copied bytes and owner cleanup."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def debugger_identity(gdb_path: Path) -> dict:
    version = subprocess.run([str(gdb_path), "--version"], capture_output=True,
                             text=True, timeout=15, check=True)
    capability = subprocess.run(
        [str(gdb_path), "-nx", "-nh", "-batch",
         "-ex", "set auto-load python-scripts off",
         "-ex", 'python import gdb, sys; print("R2_GDB_CAPABILITY", '
                'int(hasattr(gdb, "FinishBreakpoint")), '
                '".".join(map(str, sys.version_info[:3])))'],
        capture_output=True, text=True, timeout=15, check=True)
    capability_lines = [line for line in capability.stdout.splitlines()
                        if line.startswith("R2_GDB_CAPABILITY ")]
    if (len(capability_lines) != 1 or
            not capability_lines[0].startswith("R2_GDB_CAPABILITY 1 ")):
        raise AssertionError("GDB lacks the Python FinishBreakpoint capability")
    return {"path": str(gdb_path), "sha256": sha256(gdb_path),
            "version": version.stdout.strip(),
            "python_capability": capability_lines[0]}


def observe(label: str, expected: list[int], wanted_exit: int,
            wanted_verdict: str, executable: Path, directory: Path,
            gdb_path: str, script: Path) -> None:
    result = directory / f"{label}.json"
    stdout = directory / f"{label}.stdout"
    stderr = directory / f"{label}.stderr"
    environment = dict(os.environ)
    environment["R2_EXPECTED_BYTES"] = json.dumps(expected)
    environment["R2_OBSERVER_RESULT"] = str(result)
    command = [gdb_path, "-nx", "-nh", "-batch",
               "-ex", "set auto-load python-scripts off",
               "-ex", "set auto-load local-gdbinit off",
               "-x", str(script), "--args", str(executable)]
    with stdout.open("x") as output, stderr.open("x") as errors:
        process = subprocess.Popen(command, env=environment, stdout=output,
                                   stderr=errors, start_new_session=True)
        try:
            exit_code = process.wait(timeout=45)
        except BaseException:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            raise
    if not result.is_file():
        raise AssertionError(f"{label}: GDB produced no observer result")
    evidence = json.loads(result.read_text())
    if (exit_code != wanted_exit or evidence.get("verdict") != wanted_verdict
            or evidence.get("expected") != expected):
        raise AssertionError(f"{label}: unexpected observer result: "
                             f"exit={exit_code}, evidence={evidence}")
    if wanted_verdict == "REJECTED (expected assertion)":
        if evidence.get("reason") != "actual output backing bytes differ from expected oracle":
            raise AssertionError(f"{label}: wrong rejection owner: {evidence}")
    print(f"{label}: {wanted_verdict}", flush=True)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: phase26_r2_byte_observer.py SIGNED_ELF OUTPUT_DIR")
    executable = Path(sys.argv[1]).resolve(strict=True)
    directory = Path(sys.argv[2]).resolve()
    script = Path(__file__).with_suffix(".gdb.py").resolve(strict=True)
    selected_gdb = shutil.which("gdb")
    if not selected_gdb or not os.access(executable, os.X_OK):
        raise AssertionError("GDB or executable signed caller fixture unavailable")
    gdb_path = Path(selected_gdb).resolve(strict=True)
    directory.mkdir(parents=True, exist_ok=False)
    original_elf = sha256(executable)
    original_script = sha256(script)
    original_gdb = debugger_identity(gdb_path)
    with (directory / "debugger-identity.json").open("x") as receipt:
        json.dump(original_gdb, receipt, indent=2, sort_keys=True)
        receipt.write("\n")
    observe("actual_bytes", [3, 4], 0, "ACCEPTED", executable,
            directory, str(gdb_path), script)
    if debugger_identity(gdb_path) != original_gdb:
        raise AssertionError("debugger identity changed after actual byte observation")
    observe("wrong_byte_oracle", [3, 5], 1,
            "REJECTED (expected assertion)", executable, directory,
            str(gdb_path), script)
    if (sha256(executable) != original_elf or sha256(script) != original_script or
            debugger_identity(gdb_path) != original_gdb):
        raise AssertionError("observer inputs changed while running")


if __name__ == "__main__":
    main()
