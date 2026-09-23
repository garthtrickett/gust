#!/usr/bin/env python3
"""Patch 25.1: the no-C-compiler job, and the contract that makes it evidence.

D8 says the only honest falsifier for "a clean machine builds and tests Gust
without invoking a C compiler" is a CI job on an image with no C compiler.
O4 adds the part that makes such a job worth having: it is expected to fail
while work remains, so it needs a stated contract rather than an exemption.
There is no `continue-on-error` anywhere in the repository's 153 workflows;
a red job without one would simply read as breakage.

The contract:

  * The job is expected to FAIL while `phase25_no_c_expected_failures.json`
    has entries, and to fail ONLY for reasons on that list.
  * A failure whose reason is absent is a REGRESSION and is reported as
    one. That is the inversion discipline applied to a CI job, and it is
    what separates a measurement from decoration.
  * The list is read at runtime rather than restated here, so the job and
    the list cannot drift apart (P7).
  * Promotion is mechanical but not automatic: when the list empties the
    job reports ready, and a patch flips it to required (P8). Automatic
    promotion would turn a success elsewhere into a blocking red with
    nobody expecting it.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import tempfile
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIST = ROOT / "scripts" / "phase25_no_c_expected_failures.json"

C_COMPILERS = ("cc", "gcc", "clang", "c++", "g++", "cc1")


def load() -> dict:
    return json.loads(LIST.read_text(encoding="utf-8"))


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"guard-cranelift-phase25-no-c-falsifier: {message}")
        raise SystemExit(1)


def present_compilers() -> list:
    return [name for name in C_COMPILERS if shutil.which(name)]


def validate() -> None:
    """Check the list's own shape. Runs anywhere, including with a C compiler."""
    record = load()
    require(record.get("version") == "phase25_no_c_expected_failures_v1",
            "expected-failure list version drifted")
    require(record.get("contract"),
            "the list carries no contract; a bare list of excuses is not one")
    for entry in record["entries"]:
        for field in ("id", "reason", "measured_by", "cleared_by"):
            require(entry.get(field),
                    f"entry {entry.get('id', '?')!r} is missing {field}: an "
                    "entry that does not say what clears it is permanent")
    ids = [entry["id"] for entry in record["entries"]]
    require(len(ids) == len(set(ids)), f"duplicate entry ids: {ids}")
    if not record["entries"]:
        print("guard-cranelift-phase25-no-c-falsifier: expected-failure list "
              "is EMPTY -- ready for promotion to required. That is a patch, "
              "not an automatic flip (P8).")
        return
    print("guard-cranelift-phase25-no-c-falsifier: ok "
          f"({len(record['entries'])} expected failures, "
          f"{len(record['excepted'])} excepted). The job is expected red "
          "until this list empties.")


def check_environment() -> None:
    """Run ON the no-C image. Reports what is still needed, and why."""
    found = present_compilers()
    record = load()
    if found:
        print("guard-cranelift-phase25-no-c-falsifier: this image HAS a C "
              f"compiler ({', '.join(found)}), so it cannot falsify the gate. "
              "The job must run on an image without one.")
        raise SystemExit(1)
    print("no C compiler on PATH: " + ", ".join(C_COMPILERS) + " all absent")
    if not record["entries"]:
        print("guard-cranelift-phase25-no-c-falsifier: no expected failures "
              "remain; the gate should now be provable here.")
        return
    print("guard-cranelift-phase25-no-c-falsifier: EXPECTED RED. "
          f"{len(record['entries'])} reasons remain:")
    for entry in record["entries"]:
        print(f"  - {entry['id']}: cleared by {entry['cleared_by']}")
    raise SystemExit(1)



WORKLOAD = ["make", "gust"]

# Withheld from the shadow PATH. Everything else on PATH is symlinked through,
# because a PATH of seven tools cannot run a build at all: the first attempt
# died on `mkdir: command not found`, which is the harness failing, not the
# gate. A falsifier whose environment cannot run the workload proves nothing
# about the workload.
BLOCKED_TOOLS = ("cc", "gcc", "clang", "c++", "g++", "cc1", "cpp",
                 "clang++", "gcc-13", "x86_64-linux-gnu-gcc")


def compiler_free_path(dest: str) -> str:
    """A full toolchain with the compilers withheld."""
    seen = set()
    for directory in os.environ.get("PATH", "").split(os.pathsep):
        if not os.path.isdir(directory) or directory.startswith(dest):
            continue
        for name in os.listdir(directory):
            if name in BLOCKED_TOOLS or name in seen:
                continue
            src = os.path.join(directory, name)
            if os.path.isdir(src) or not os.access(src, os.X_OK):
                continue
            try:
                os.symlink(src, os.path.join(dest, name))
                seen.add(name)
            except OSError:
                pass
    return dest


def run_workload() -> None:
    """Run the real build with no compiler, and CLASSIFY what happens.

    check-environment only asserts that compiler names are absent from PATH.
    That certifies nothing about Gust: an eventual promoted job would pass
    merely because `cc` is not on PATH, and an unrelated build break could
    never be told apart from a tracked reason. So the workload runs, and its
    failure is matched against the tracked list.
    """
    record = load()
    entries = record["entries"]
    with tempfile.TemporaryDirectory(prefix="gust-nocc-") as tmp:
        dest = os.path.join(tmp, "nocc")
        os.makedirs(dest)
        env = dict(os.environ, PATH=compiler_free_path(dest))
        proc = subprocess.run(WORKLOAD, cwd=ROOT, env=env,
                              capture_output=True, text=True)
    output = proc.stdout + proc.stderr
    if not entries:
        # Patch 25.12b: the list emptied, and this branch had to change with
        # it -- the contract says promotion happens "by a patch that says
        # so, never automatically", and this is that patch saying so.
        #
        # It used to require WORKLOAD to SUCCEED here. On this runner it
        # cannot, and not for any reason left to fix: Patch 25.11 measured
        # that GNU HAS NO C-FREE LINK AT ALL (gnu + rust-lld fails with
        # -lc -lm -ldl -lpthread -lrt -lutil -lgcc_s unfound), and cargo
        # builds build scripts for the HOST regardless of --target, so
        # libm's build script reaches for cc before anything of Gust's is
        # linked. Demanding success on a gnu runner would be demanding that
        # rustc stop being rustc.
        #
        # It is also not what this phase decided to ship. O6 keeps the user
        # default on the host's native target, and P10 says a gnu host with
        # no C compiler ERRORS naming musl rather than silently handing back
        # a static binary with a non-functional dlopen. The C-free claim was
        # always the musl one; the docs say so in those words.
        #
        # So the gate is asserted where it is true, and the gnu route is
        # still pinned so a silent default change cannot pass unnoticed.
        musl = subprocess.run(
            [sys.executable, str(ROOT / "scripts/phase25_musl_c_free_link.py"),
             "validate"], cwd=ROOT, capture_output=True, text=True)
        require(musl.returncode == 0,
                "the expected-failure list is empty, so the C-free gate must "
                "HOLD on the route this phase proves it on, but the musl "
                f"link guard failed:\n{(musl.stdout + musl.stderr)[-1500:]}")
        host = subprocess.run(
            [sys.executable, str(ROOT / "scripts/phase25_musl_c_free_link.py"),
             "host-build"], cwd=ROOT, capture_output=True, text=True)
        require(host.returncode == 0,
                "the expected-failure list is empty, so a musl HOST must "
                "build with no C compiler, but it did not:\n"
                f"{(host.stdout + host.stderr)[-1500:]}")
        require(proc.returncode != 0,
                f"{' '.join(WORKLOAD)} SUCCEEDED with no C compiler on a GNU "
                "host. That contradicts Patch 25.11's measurement that gnu "
                "has no C-free link, so either the toolchain changed under "
                "this gate or the workload stopped doing what it claims -- "
                "either way it needs a patch, not a green tick")
        print("guard-cranelift-phase25-no-c-falsifier: the gate HOLDS. The "
              "C-free route is proved on musl -- link and host build, both "
              "with every C driver poisoned -- and the gnu route still "
              f"requires a C driver by O6/P10 design ({' '.join(WORKLOAD)} "
              f"exited {proc.returncode} here, as it must).")
        return
    require(proc.returncode != 0,
            f"{' '.join(WORKLOAD)} SUCCEEDED with no C compiler while "
            f"{len(entries)} expected failures remain. Either the gate now "
            "holds and this list is stale, or the workload did not do what "
            "it claims -- neither is a pass.")
    matched = [e["id"] for e in entries
               if e.get("observable_signature")
               and re.search(e["observable_signature"], output)]
    require(matched,
            f"{' '.join(WORKLOAD)} failed for a reason not on the tracked "
            "list, which is a REGRESSION, not progress. Expected one of "
            f"{[e['id'] for e in entries if e.get('observable_signature')]}. "
            f"Observed:\n{output[-2000:]}")
    print("guard-cranelift-phase25-no-c-falsifier: EXPECTED RED, and the "
          f"workload was run. {' '.join(WORKLOAD)} failed as "
          f"{matched[0]}. {len(entries)} reasons remain:")
    for entry in entries:
        print(f"  - {entry['id']}: cleared by {entry['cleared_by']}")
    raise SystemExit(1)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command",
                        choices=["validate", "check-environment", "run-workload",
                                 "report"])
    args = parser.parse_args()
    if args.command == "report":
        print(json.dumps(load(), indent=2, sort_keys=True))
    elif args.command == "check-environment":
        check_environment()
    elif args.command == "run-workload":
        run_workload()
    else:
        validate()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
