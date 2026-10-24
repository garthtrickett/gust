#!/usr/bin/env python3
"""Qualify allocator invalidation against existing owned resource obligations."""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
NEGATIVES = (
    "free", "move", "swap_current", "swap_next", "alias_free",
    "transferred_local", "deferred_owner", "conditional_close", "nested_owner",
    "owned_parameter", "aggregate",
)
POSITIVES = (
    "closed_free", "closed_move", "closed_swap", "unrelated_free",
    "automatic_cleanup",
)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def qualify(compiler, output):
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    disk_before = subprocess.check_output(["df", "-B1", str(ROOT)], text=True)
    budget = 128 * 1024 ** 2
    space = os.statvfs(ROOT)
    if space.f_bavail * space.f_frsize < budget + 2 * 1024 ** 3:
        raise SystemExit("allocator matrix disk admission refused")
    output.mkdir(parents=True, exist_ok=False)
    sources = [ROOT / "compiler" / f"phase26_2_allocator_{name}.gst"
               for name in NEGATIVES + POSITIVES]
    inputs = sources + [Path(__file__), ROOT / "compiler/typechecker.gst",
                        ROOT / "compiler/phase20_protected_access_module.gst"]
    before = {str(path.relative_to(ROOT)): digest(path) for path in inputs}
    compiler_hash = digest(compiler)
    records = []
    for name, source in zip(NEGATIVES + POSITIVES, sources):
        reject = name in NEGATIVES
        binary = output / (name + ".bin")
        environment = os.environ.copy()
        if reject:
            # An unexpected acceptance must never link or execute a suspect
            # invalidation. It also cannot masquerade as a frontend refusal.
            environment["GUST_NATIVE_BACKEND_DRIVER"] = "/bin/false"
        result = subprocess.run(
            [str(compiler), "--backend", "cranelift", "-o", str(binary),
             str(source.relative_to(ROOT))], cwd=ROOT, env=environment,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120,
        )
        (output / (name + ".stdout")).write_bytes(result.stdout)
        (output / (name + ".stderr")).write_bytes(result.stderr)
        row = dict(case=name, source_sha256=digest(source),
                   compile_exit=result.returncode, executed=False)
        if reject:
            expected = (result.returncode == 1 and not result.stderr and
                        b"[LinearResourceLeak]" in result.stdout and
                        b"driver_handshake" not in result.stdout and
                        b"gust_native_capability_decision" not in result.stdout and
                        not binary.exists())
            row["verdict"] = (
                "REJECTED (expected assertion)" if expected else
                "ACCEPTED" if result.returncode == 0 else
                "REJECTED (different assertion)"
            )
            row["pass"] = expected
        else:
            row["pass"] = result.returncode == 0 and binary.is_file()
            if row["pass"]:
                execution = subprocess.run(
                    [str(binary)], cwd=ROOT, stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE, timeout=15,
                )
                (output / (name + ".run.stdout")).write_bytes(execution.stdout)
                (output / (name + ".run.stderr")).write_bytes(execution.stderr)
                row.update(executed=True, run_exit=execution.returncode,
                           elf_sha256=digest(binary))
                row["pass"] = (execution.returncode == 0 and
                               execution.stdout == b"41\n" and not execution.stderr)
        records.append(row)
        print(json.dumps(row), flush=True)
    after = {str(path.relative_to(ROOT)): digest(path) for path in inputs}
    passed = before == after and digest(compiler) == compiler_hash and all(
        row["pass"] for row in records)
    allocated = sum(path.stat().st_blocks * 512 for path in output.rglob("*")
                    if path.is_file())
    passed = passed and allocated <= budget
    result = dict(
        started_utc=started, df_B1_start=disk_before,
        df_B1_end=subprocess.check_output(["df", "-B1", str(ROOT)], text=True),
        owned_allocated_start_bytes=0, owned_allocated_end_bytes=allocated,
        owned_output_budget_bytes=budget,
        utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        status="PASS allocator resource liveness" if passed else "FAIL",
        compiler_sha256=compiler_hash, source_before=before, source_after=after,
        cases=records,
        limits="Direct invalidation of existing owned resources; no OD23 slot admission or deferred allocator execution-order claim",
    )
    (output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    if not passed:
        raise SystemExit("allocator resource liveness qualification failed")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path, default=ROOT / "gust")
    parser.add_argument("--output", type=Path,
                        default=ROOT / "build/guards/phase26_2_allocator")
    args = parser.parse_args()
    qualify(args.compiler.resolve(), args.output.resolve())


if __name__ == "__main__":
    main()
