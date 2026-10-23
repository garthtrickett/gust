#!/usr/bin/env python3
"""Qualify native bytes through the imported, safe public interface."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import shutil
import subprocess

from phase26_production_guard import offline_command
from phase26_ticket_publication_guard import checked_package

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "src/stdlib/native_bytes.gst"
CONSUMER = ROOT / "tests/stdlib_s26_1_native_bytes.gst"
SCRATCH = ROOT / "build/guards/stdlib_s26_1_public_qualification"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def native_cases():
    template = CONSUMER.read_text()
    compressed = [120, 156, 99, 102, 1, 0, 0, 12, 0, 8]
    empty = [120, 156, 3, 0, 0, 0, 0, 1]
    # Check every encoded byte; equal length/checksum alone is insufficient.
    exact = " && ".join(["len(bytes) == 10"] +
        [f"bytes[{i}] == ({value} as byte)" for i, value in enumerate(compressed)])
    for name, operation, values, capacity, level, result, expected in (
        ("compressed_bytes", "compress", [3, 4], 64, 6, f"100 + (({exact}) as int)", 101),
        ("decoded_bytes", "decompress", compressed, 2, None,
         "100 + (((len(bytes) == 2) && (bytes[0] == (3 as byte)) && (bytes[1] == (4 as byte))) as int)", 101),
        ("empty_compression", "compress", [], 64, 6, "100 + len(bytes)", 108),
        ("empty_zero_destination", "decompress", empty, 0, None, "100 + len(bytes)", 100),
        ("nonempty_zero_destination", "decompress", compressed, 0, None, "100 + len(bytes)", 253),
        ("corrupt", "decompress", [3, 4], 64, None, "100 + len(bytes)", 252),
        ("truncated", "decompress", compressed[:4], 64, None, "100 + len(bytes)", 252),
        ("short_compression", "compress", [3, 4], 1, 6, "100 + len(bytes)", 253),
        ("short_decompression", "decompress", compressed, 1, None, "100 + len(bytes)", 253),
        ("invalid_level", "compress", [3, 4], 64, 10, "100 + len(bytes)", 255),
        ("negative_capacity", "compress", [3, 4], -1, 6, "100 + len(bytes)", 255),
        ("oversized_capacity", "decompress", compressed, 1073741825, None, "100 + len(bytes)", 254),
        ("incompressible", "compress", list(random.Random(2601).randbytes(256)), 512, 6,
         "100 + (len(bytes) == 267)", 101),
    ):
        text = template.replace("    input.Push(3 as byte);\n    input.Push(4 as byte);",
            "\n".join(f"    input.Push({value} as byte);" for value in values))
        cap = str(capacity) if capacity >= 0 else f"0 - {abs(capacity)}"
        args = f"&destination, &input, {cap}" + (f", {level}" if level is not None else "")
        text = text.replace("native.compress(&destination, &input, 64, 6)", f"native.{operation}({args})")
        text = text.replace("100 + len(bytes)", result)
        yield name, text, expected
    yield "roundtrip", (ROOT / "tests/stdlib_s26_1_roundtrip.gst").read_text(), 101
    # A caller-owned input alias may remain usable while output is independent.
    yield "copied_input", template.replace("    mut result :=", "    mut alias := input;\n    mut result :=").replace(
        "&destination, &input, 64, 6", "&destination, &alias, 64, 6"), 110
    yield "distinct_output_arena", template.replace("    mut input:",
        "    mut input_arena := os.Arena.New();\n    defer input_arena.Free();\n    mut input:").replace(
        "std.Vector[byte, destination] := std.VectorNew(&destination)",
        "std.Vector[byte, input_arena] := std.VectorNew(&input_arena)"), 110


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--source-negatives", action="store_true")
    args = parser.parse_args()
    checked_package(args.package)
    if SCRATCH.exists():
        shutil.rmtree(SCRATCH)
    SCRATCH.mkdir(parents=True)
    tools = SCRATCH / "tools"
    tools.mkdir()
    for source, name in ((ROOT / "gust", "gust"),
                         (ROOT / "build/gust-native-backend", "gust-native-backend"),
                         (args.package / "gust-runtime-package.a", "gust-runtime-package.a")):
        shutil.copy2(source, tools / name)
    shutil.copytree(args.package, tools / "approved-packages/gust_zlib_1_3_2_production")
    launcher = {"PATH": "/usr/bin:/bin", "LC_ALL": "C"}
    namespace = subprocess.check_output(offline_command(
        ["/usr/bin/readlink", "/proc/self/ns/net"], launcher), env=launcher, text=True).strip()
    if namespace == os.readlink("/proc/self/ns/net"):
        raise ValueError("public interface qualification lacks physical network isolation")
    before = sha(MODULE)
    results = []

    def compile_source(name, text):
        directory = SCRATCH / name
        directory.mkdir()
        source = directory / "case.gst"
        source.write_text(text.replace('"../src/stdlib/native_bytes.gst"',
            json.dumps(os.path.relpath(MODULE, directory))))
        output = directory / "program"
        env = dict(launcher, HOME=str(directory), GUST_TEST_MIR_TO_C_UNAVAILABLE="1",
                   GUST_NATIVE_BACKEND_DRIVER=str(tools / "gust-native-backend"),
                   GUST_NATIVE_KEEP_OBJECTS=str(directory / "keep"))
        process = subprocess.run(offline_command(
            [tools / "gust", "--backend", "cranelift", "-o", output, source], env),
            env=launcher, cwd=ROOT, capture_output=True, text=True, timeout=120)
        (directory / "stdout").write_text(process.stdout)
        (directory / "stderr").write_text(process.stderr)
        return source, output, process

    for case, diagnostic in (
        ("wrong_arena", "[BrandMismatch] Arena.get_ref index brand"),
        ("error_ticket_rejected", "Field 'ticket' not found in enum variant Error"),
        ("output_escape_rejected", "[TypeMismatch] Return type mismatch"),
    ):
        text = (ROOT / f"tests/stdlib_s26_1_{case}.gst").read_text()
        source, output, process = compile_source(case, text)
        rejected = 0 < process.returncode < 128 and not output.exists() and not output.is_symlink()
        verdict = ("REJECTED (expected assertion)" if diagnostic in process.stdout + process.stderr
                   else "REJECTED (different assertion)") if rejected else "ACCEPTED or invalid rejection"
        results.append(dict(case=case, source_sha256=sha(source), verdict=verdict, exit=process.returncode))
        if verdict != "REJECTED (expected assertion)":
            raise ValueError(f"{case}: {verdict}")
        print("PUBLIC_SOURCE_REJECTION_PASS", case, flush=True)
    if not args.source_negatives:
        for name, text, expected in native_cases():
            source, output, process = compile_source(name, text)
            if process.returncode != 0 or not output.is_file():
                raise ValueError(f"{name}: compilation failed ({process.returncode}): {process.stdout}{process.stderr}")
            status = subprocess.run(offline_command([output], launcher), env=launcher, timeout=10)
            if status.returncode != expected:
                raise ValueError(f"{name}: observed {status.returncode}, expected {expected}")
            headers = subprocess.check_output(["readelf", "-l", output], text=True)
            if "INTERP" in headers or "DYNAMIC" in headers:
                raise ValueError(f"{name}: unqualified dynamic dependency")
            results.append(dict(case=name, source_sha256=sha(source), elf_sha256=sha(output), exit=status.returncode))
            print("PUBLIC_NATIVE_CASE_PASS", name, flush=True)
            (SCRATCH / "partial-results.json").write_text(json.dumps(results, indent=2) + "\n")
    if sha(MODULE) != before:
        raise ValueError("library changed during qualification")
    (SCRATCH / "result.json").write_text(json.dumps(dict(
        status="PASS source negatives only" if args.source_negatives else "PASS public native interface",
        module_sha256=before, offline_network_namespace_verified=True, cases=results), indent=2) + "\n")


if __name__ == "__main__":
    main()
