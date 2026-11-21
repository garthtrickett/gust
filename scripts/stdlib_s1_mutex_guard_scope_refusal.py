"""Strict frontend-only refusal predicate for the original CR-16 source.

This checks captured compiler output; it never compiles or runs a fixture.
"""
from pathlib import Path
import sys

EXPECTED = (
    b"[LinearResourceLeak] Deferred allocator Free executes before dependent "
    b"cleanup or invalidates a returned owner"
)
WORKER_MARKERS = (
    b"driver_handshake", b"handshake process failed",
    b"gust_native_capability_decision",
)


def validate(status, stdout, stderr, output_exists, output_is_symlink):
    if status != 1:
        raise ValueError("expected exact frontend exit 1")
    if any(marker in (stdout + stderr).lower() for marker in WORKER_MARKERS):
        raise ValueError("worker/capability marker in purported frontend refusal")
    if stderr:
        raise ValueError("frontend refusal stderr must be empty")
    if EXPECTED not in stdout:
        raise ValueError("expected exact bracketed cleanup diagnostic in stdout")
    if output_exists or output_is_symlink:
        raise ValueError("frontend refusal produced an output or symlink")


if __name__ == "__main__":
    if len(sys.argv) != 5:
        sys.exit("usage: refusal.py STATUS STDOUT STDERR OUTPUT")
    try:
        output = Path(sys.argv[4])
        validate(int(sys.argv[1]), Path(sys.argv[2]).read_bytes(),
                 Path(sys.argv[3]).read_bytes(), output.exists(), output.is_symlink())
    except (ValueError, OSError) as error:
        sys.exit(f"CR-16 strict frontend refusal: {error}")
    print("CR-16 original: strict frontend cleanup refusal; no native output")
