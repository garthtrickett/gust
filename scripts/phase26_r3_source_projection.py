#!/usr/bin/env python3
"""Bind an R3 Gust source capture to its checked-in canonical Program."""

from pathlib import Path
import sys

from phase26_r2_source_projection import from_bundle, normalized


ROOT = Path(__file__).resolve().parents[1]
CASES = {
    "compress": "phase26_r3_zlib_compress",
    "decompress": "phase26_r3_zlib_decompress",
    "empty_decompress": "phase26_r3_zlib_empty_decompress",
}


def check(case: str, bundle: Path) -> None:
    stem = CASES[case]
    source = (ROOT / "tests/cranelift" / f"{stem}.gst").resolve()
    fixture = ROOT / "compiler/experiments/cranelift/src/testdata" / f"{stem}.canonical"
    actual = from_bundle(bundle.read_bytes(), source)
    actual_normalized, actual_path = normalized(actual)
    expected_normalized, _ = normalized(fixture.read_bytes())
    if actual_path != str(source).encode() or actual_normalized != expected_normalized:
        raise ValueError(f"R3 source-produced {case} canonical Program drifted")
    print(f"R3_SOURCE_PROJECTION_PASS {case} {len(actual)}")


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in CASES:
        raise SystemExit("usage: phase26_r3_source_projection.py CASE BUNDLE")
    check(sys.argv[1], Path(sys.argv[2]))
