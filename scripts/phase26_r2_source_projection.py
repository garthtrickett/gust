#!/usr/bin/env python3
"""Compare a source-produced R2 Program with its reviewed canonical fixture."""

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
CASES = {
    "caller_five_arg": (
        "tests/cranelift/phase26_r2_scoped_caller_five_arg.gst",
        "compiler/experiments/cranelift/src/testdata/"
        "scoped_byte_copy_caller_five_arg_producer.canonical",
    ),
    "zero_length": (
        "tests/cranelift/phase26_r2_scoped_zero_length.gst",
        "compiler/experiments/cranelift/src/testdata/"
        "scoped_byte_copy_zero_length_producer.canonical",
    ),
    "renamed_types": (
        "tests/cranelift/phase26_r2_scoped_renamed_types.gst",
        "compiler/experiments/cranelift/src/testdata/"
        "scoped_byte_copy_renamed_owner_result_producer.canonical",
    ),
}


def normalized(canonical: bytes) -> tuple[bytes, bytes]:
    lines = canonical.splitlines(keepends=True)
    if not lines or lines[0] != b"format: gust.compiler_executable_mir.v1\n" or \
       lines.count(b"module_count: 1\n") != 1:
        raise ValueError("unexpected R2 canonical format or module census")
    indices = [index for index, line in enumerate(lines) if line.startswith(b"module: ")]
    if len(indices) != 1:
        raise ValueError("R2 canonical has no unique module identity")
    index = indices[0]
    fields = lines[index].rstrip(b"\n").split(b"|", 2)
    if len(fields) != 3 or fields[0] != b"module: 0" or not fields[1]:
        raise ValueError("R2 canonical module identity has wrong shape")
    try:
        source_path = bytes.fromhex(fields[1].decode("ascii"))
    except (UnicodeDecodeError, ValueError) as error:
        raise ValueError("R2 canonical module path is not hex") from error
    lines[index] = fields[0] + b"|<source-path>|" + fields[2] + b"\n"
    return b"".join(lines), source_path


def from_bundle(bundle: bytes, source: Path) -> bytes:
    header = b"format: gust.compiler_program_mir_bundle.v1\n"
    begin = b"module_0_canonical_mir_begin\n"
    end = b"module_0_canonical_mir_end\n"
    if not bundle.startswith(header) or bundle.count(begin) != 1 or \
       bundle.count(end) != 1:
        raise ValueError("R2 bundle format or canonical section is not unique")
    prefix, remainder = bundle.split(begin, 1)
    if prefix.count(b"module_count: 1\n") != 1 or \
       prefix.count(b"module_0_path: " + str(source).encode() + b"\n") != 1:
        raise ValueError("R2 bundle did not capture the selected source")
    lengths = [line for line in prefix.splitlines()
               if line.startswith(b"module_0_canonical_mir_length: ")]
    if len(lengths) != 1:
        raise ValueError("R2 bundle has no unique canonical length")
    try:
        length = int(lengths[0].split(b": ", 1)[1])
    except ValueError as error:
        raise ValueError("R2 bundle canonical length is not numeric") from error
    if length <= 0 or length > 32 * 1024 * 1024 or remainder[length:length + len(end)] != end:
        raise ValueError("R2 bundle canonical length or end delimiter disagrees")
    return remainder[:length]


def check(case: str, actual_path: Path) -> None:
    source, fixture = CASES[case]
    source_path = (ROOT / source).resolve()
    actual, actual_source = normalized(from_bundle(actual_path.read_bytes(), source_path))
    expected, _ = normalized((ROOT / fixture).read_bytes())
    if actual_source != str(source_path).encode():
        raise ValueError("captured module path does not identify the selected source")
    if actual != expected:
        raise ValueError("source-produced R2 Program differs from reviewed canonical rows")
    print(f"R2 source producer {case}: exact canonical rows after module-path normalization")


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in CASES:
        raise SystemExit("usage: phase26_r2_source_projection.py CASE ACTUAL_CANONICAL")
    try:
        check(sys.argv[1], Path(sys.argv[2]))
    except (OSError, ValueError) as error:
        raise SystemExit(f"R2 source projection: {error}") from error
