#!/usr/bin/env python3
"""Run the first-release compiler/runtime/fixed-point obligations unchanged."""
from __future__ import annotations

import hashlib
import argparse
import json
import os
from pathlib import Path
import subprocess
import time
from phase26_release_bounded import effective_memory_cap

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "build/guards/phase26_release_regression"
COMMANDS = [
    ["cargo", "test", "--locked", "-j2", "--manifest-path",
     "compiler/experiments/cranelift/Cargo.toml", "--", "--nocapture"],
    ["cargo", "test", "--locked", "-j2", "--manifest-path",
     "src/runtime-rs/Cargo.toml", "ffi_call_region", "--", "--nocapture"],
    ["bash", "scripts/phase25_native_fixed_point.sh"],
]


def source_manifest():
    names = subprocess.check_output(["git", "ls-files", "compiler", "src/runtime-rs",
                                     "src/stdlib", "Makefile"], cwd=ROOT, text=True).splitlines()
    return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
            for name in names if (ROOT / name).is_file()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    output = parser.parse_args().output.resolve()
    if ROOT / "build/guards" not in output.parents:
        raise SystemExit("release regression output must be a new owned build/guards directory")
    output.mkdir(parents=True, exist_ok=False)
    memory_cap = effective_memory_cap()
    before = source_manifest()
    rows = []
    environment = dict(os.environ, CARGO_BUILD_JOBS="2")
    for number, command in enumerate(COMMANDS):
        log = output / f"command-{number}.log"
        print("RUN " + " ".join(command), flush=True)
        assert effective_memory_cap() == memory_cap, "release compiler memory cap changed"
        start = time.time()
        # Each log grows while the owning tracked job is live.
        with log.open("wb") as stream:
            result = subprocess.run(command, cwd=ROOT, env=environment,
                                    stdout=stream, stderr=subprocess.STDOUT, timeout=1800)
        rows.append(dict(command=command, exit=result.returncode, seconds=time.time() - start,
                         log=log.relative_to(ROOT).as_posix(),
                         log_sha256=hashlib.sha256(log.read_bytes()).hexdigest()))
        (output / "partial-results.json").write_text(json.dumps(rows, indent=2) + "\n")
        if result.returncode:
            raise SystemExit("release regression failed: " + str(log))
    after = source_manifest()
    if before != after:
        raise SystemExit("release compiler/runtime/stdlib sources changed during regression")
    (output / "result.json").write_text(json.dumps(dict(
        status="PASS compiler runtime and emitted-object fixed point",
        source_before=before, source_after=after, commands=rows,
        memory_cap_bytes=memory_cap, memory_cap_bytes_after=effective_memory_cap()), indent=2) + "\n")
    print("PHASE26_RELEASE_REGRESSION_PASS", flush=True)


if __name__ == "__main__":
    main()
