#!/usr/bin/env python3
"""Source-backed, signed-production qualification of generic ticket publication."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import re
import shutil
import subprocess

from phase26_production_guard import offline_command
from phase26_r2_source_projection import from_bundle, normalized

ROOT = Path(__file__).resolve().parents[1]
PROFILE = ROOT / "compiler/experiments/cranelift/production"
SOURCE = ROOT / "tests/cranelift/phase26_ticket_publication.gst"
FIXTURE = ROOT / "compiler/experiments/cranelift/src/testdata/scoped_ticket_publication_producer.canonical"
SCRATCH = ROOT / "build/guards/phase26_ticket_publication"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def checked_package(package):
    for name in ("manifest.txt", "manifest.sig"):
        if (package / name).read_bytes() != (PROFILE / name).read_bytes():
            raise ValueError("ticket guard package differs from enrolled signed production profile")
    rows = [line.removeprefix("artifact: ").split("|")
            for line in (PROFILE / "manifest.txt").read_text().splitlines()
            if line.startswith("artifact: ")]
    if len(rows) != 12 or any(digest(package / name) != expected for _, name, expected in rows):
        raise ValueError("ticket guard signed production artifact bytes disagree")


def cases(template):
    yield "source", template, 10
    names = {"CopyOutcome": "ByteChoice", "Completed": "Ready", "Rejected": "Fault",
             "complete_copy": "make_ready", "reject_copy": "make_fault", "copy_bytes": "marshal",
             "pool": "owner_pool", "destination": "caller_pool", "collected": "complete_bytes",
             "handle": "slot", "number": "error_value"}
    renamed = re.sub(r"\b(" + "|".join(names) + r")\b", lambda match: names[match[0]], template)
    yield "renamed", renamed, 10
    good = [120, 156, 99, 102, 1, 0, 0, 12, 0, 8]
    empty = [120, 156, 3, 0, 0, 0, 0, 1]
    random_input = list(random.Random(2601).randbytes(256))
    for name, decompress, inputs, cap, level, result, expected in (
        ("decompress_content", True, good, 2, 6,
         "100 + len(bytes) * 10 + (bytes[0] as int) * 10 + (bytes[1] as int)", 154),
        ("empty", True, empty, 0, 6, "100 + len(bytes)", 100),
        ("empty_input", False, [], 64, 6, "100 + len(bytes)", 108),
        ("incompressible", False, random_input, 512, 6, "100 + (len(bytes) == 267)", 101),
        ("corrupt", True, [3, 4], 64, 6, "100 + len(bytes)", 252),
        ("short", False, [3, 4], 1, 6, "100 + len(bytes)", 253),
        ("invalid_level", False, [3, 4], 64, 10, "100 + len(bytes)", 255),
        ("negative_capacity", False, [3, 4], -1, 6, "100 + len(bytes)", 255),
        ("oversized_capacity", False, [3, 4], 1073741825, 6, "100 + len(bytes)", 255),
    ):
        source = template.replace("    input.Push(3 as byte);\n    input.Push(4 as byte);",
            "\n".join(f"    input.Push({value} as byte);" for value in inputs))
        source = source.replace("&input, 64, 6)", f"&input, {cap if cap >= 0 else '0 - 1'}, {level})")
        source = source.replace("return len(bytes);", f"return {result};")
        if decompress:
            source = source.replace("gust_zlib_compress", "gust_zlib_decompress")
            source = source.replace(", level: int #[ffi(value)]", "")
            source = source.replace("output_cap, level\n", "output_cap\n")
        yield name, source, expected


def rejections(template):
    yield "wrong_arena", template.replace("    defer destination.Free();",
        "    defer destination.Free();\n    mut other := os.Arena.New();\n    defer other.Free();").replace(
            "destination.get_ref(copied)", "other.get_ref(copied)"), "[BrandMismatch] Arena.get_ref index brand"
    yield "effectful_constructor", template.replace("        result.tag = 1;",
        "        os.LogInt(number);\n        result.tag = 1;"), "ticket constructor has extra effects"
    yield "wrong_error_tag", template.replace("result.tag = 1;", "result.tag = 0;"), \
        "ticket constructor tag disagrees with payload"
    yield "direct_large_payload", template.replace("handle: Index[std.Vector[byte, pool], pool]",
        "handle: std.Vector[byte, pool]"), "large enum variant payload"
    allocation = "    mut handle: Index[std.Vector[byte, pool], pool] := os.ArenaAlloc(pool);\n"
    store = "    pool.Set(handle, collected);\n"
    early = template.replace(allocation, "").replace(store, "")
    early = early.replace("    unsafe {\n        mut acquired", allocation + "    unsafe {\n        mut acquired")
    early = early.replace("    }\n    // The native owner is gone", "        pool.Set(handle, collected);\n    }\n    // The native owner is gone")
    yield "publication_before_cleanup", early, "scoped byte-copy stages are out of order"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", type=Path,
        default=ROOT / "build/guards/phase26_production_trust/candidate/package")
    args = parser.parse_args()
    checked_package(args.package)
    if SCRATCH.exists():
        shutil.rmtree(SCRATCH)
    SCRATCH.mkdir(parents=True)
    tools = SCRATCH / "clean-tools"
    tools.mkdir()
    for source, name in ((ROOT / "gust", "gust"),
                         (ROOT / "build/gust-native-backend", "gust-native-backend"),
                         (args.package / "gust-runtime-package.a", "gust-runtime-package.a")):
        shutil.copyfile(source, tools / name)
        if name != "gust-runtime-package.a":
            (tools / name).chmod(0o755)
    shutil.copytree(args.package, tools / "approved-packages/gust_zlib_1_3_2_production")
    environment = {"PATH": "/usr/bin:/bin", "LC_ALL": "C"}
    namespace = subprocess.check_output(offline_command(
        ["/usr/bin/readlink", "/proc/self/ns/net"], environment), env=environment, text=True).strip()
    if namespace == os.readlink("/proc/self/ns/net"):
        raise ValueError("ticket execution did not enter an offline network namespace")
    results = []
    for name, text, expected in cases(SOURCE.read_text()):
        directory = SCRATCH / name
        directory.mkdir()
        source = SOURCE if name == "source" else directory / "case.gst"
        if name != "source":
            source.write_text(text)
        clean = dict(environment, HOME=str(directory), GUST_TEST_MIR_TO_C_UNAVAILABLE="1",
                     GUST_NATIVE_BACKEND_DRIVER=str(tools / "gust-native-backend"),
                     GUST_NATIVE_KEEP_OBJECTS=str(directory / "keep"))
        output = directory / "program"
        with (directory / "stdout").open("w") as stdout, (directory / "stderr").open("w") as stderr:
            subprocess.run(offline_command([tools / "gust", "--backend", "cranelift", "-o", output, source], clean),
                           env=environment, cwd=ROOT, stdout=stdout, stderr=stderr, check=True, timeout=120)
        if name == "source":
            actual = from_bundle((directory / "keep/program.mir.bundle").read_bytes(), SOURCE.resolve())
            if normalized(actual)[0] != normalized(FIXTURE.read_bytes())[0]:
                raise ValueError("ticket source-produced canonical fixture drifted")
            first = digest(output)
            with (directory / "repeat.stdout").open("w") as stdout, (directory / "repeat.stderr").open("w") as stderr:
                subprocess.run(offline_command([tools / "gust", "--backend", "cranelift", "-o", output, source], clean),
                               env=environment, cwd=ROOT, stdout=stdout, stderr=stderr, check=True, timeout=120)
            if digest(output) != first:
                raise ValueError("ticket production linking is not deterministic")
        if name == "decompress_content":
            actual = from_bundle((directory / "keep/program.mir.bundle").read_bytes(), source.resolve())
            fixture = FIXTURE.with_name("scoped_ticket_content_producer.canonical")
            if normalized(actual)[0] != normalized(fixture.read_bytes())[0]:
                raise ValueError("ticket content source-produced canonical fixture drifted")
        status = subprocess.run(offline_command([output], environment), env=environment, timeout=10)
        if status.returncode != expected:
            raise ValueError(f"ticket {name}: {status.returncode} != {expected}")
        headers = subprocess.check_output(["readelf", "-l", output], text=True)
        if "INTERP" in headers or "DYNAMIC" in headers:
            raise ValueError("ticket executable acquired a dynamic dependency")
        results.append(dict(case=name, source_sha256=digest(source), exit=status.returncode,
                            elf_sha256=digest(output)))
        (SCRATCH / "partial-results.json").write_text(json.dumps(results, indent=2) + "\n")
        print("TICKET_PRODUCTION_CASE_PASS", name, flush=True)
    negatives = []
    for name, text, expected in rejections(SOURCE.read_text()):
        directory = SCRATCH / name
        directory.mkdir()
        source = directory / "never-execute.gst"
        source.write_text(text)
        output = directory / "never-execute"
        clean = dict(environment, HOME=str(directory), GUST_TEST_MIR_TO_C_UNAVAILABLE="1",
                     GUST_NATIVE_BACKEND_DRIVER=str(tools / "gust-native-backend"))
        process = subprocess.run(offline_command([tools / "gust", "--backend", "cranelift", "-o", output, source], clean),
                                 env=environment, cwd=ROOT, capture_output=True, text=True, timeout=120)
        (directory / "stdout").write_text(process.stdout)
        (directory / "stderr").write_text(process.stderr)
        rejected = 0 < process.returncode < 128 and not output.exists() and not output.is_symlink()
        verdict = ("REJECTED (expected assertion)" if expected in process.stdout + process.stderr else
                   "REJECTED (different assertion)") if rejected else "ACCEPTED or invalid rejection"
        negatives.append(dict(case=name, source_sha256=digest(source), exit=process.returncode, verdict=verdict))
        (SCRATCH / "rejections.json").write_text(json.dumps(negatives, indent=2) + "\n")
        if verdict != "REJECTED (expected assertion)":
            raise ValueError(f"ticket {name}: {verdict}: {process.stdout}{process.stderr}")
        print("TICKET_SOURCE_REJECTION_PASS", name, flush=True)
    (SCRATCH / "result.json").write_text(json.dumps(dict(
        status="PASS generic ticket production profile only; Phase26.1 OPEN",
        offline_network_namespace_verified=True, snapshot=json.loads((PROFILE / "snapshot.json").read_text()),
        frontend_sha256=digest(tools / "gust"), worker_sha256=digest(tools / "gust-native-backend"),
        cases=results, rejections=negatives), indent=2) + "\n")
    print("TICKET_PRODUCTION_QUALIFICATION_PASS", flush=True)


if __name__ == "__main__":
    main()
