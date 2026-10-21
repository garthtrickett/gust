#!/usr/bin/env python3
"""Bind the R2 owning guard to the exact build job's source and tools."""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RECORD = ROOT / "build/phase26-r2-tool-binding.json"
VERSION = "gust.phase26.r2.build_artifact_binding.v1"
TOOLS = ("gust", "build/gust-native-backend", "build/gust-runtime-package.a")
EXTRA = ("Makefile", "src/runtime/core_headers.h")


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def tracked_sources() -> list[str]:
    raw = subprocess.check_output(
        ["git", "ls-files", "-z", "--", "compiler", "src/runtime-rs"], cwd=ROOT)
    paths = []
    for path in raw.decode().split("\0"):
        if not path or "/target/" in path:
            continue
        if Path(path).suffix in {".gst", ".rs", ".canonical", ".toml", ".lock"}:
            paths.append(path)
    return sorted(set(paths + list(EXTRA)))


def current() -> dict:
    paths = tracked_sources()
    combined = hashlib.sha256()
    for path in paths:
        source = ROOT / path
        if not source.is_file():
            raise SystemExit("R2 build source vanished: " + path)
        combined.update(path.encode() + b"\0" + bytes.fromhex(digest(source.read_bytes())))
    tools = {}
    for path in TOOLS:
        artifact = ROOT / path
        if not artifact.is_file() or not artifact.stat().st_size:
            raise SystemExit("R2 build artifact absent: " + path)
        tools[path] = digest(artifact.read_bytes())
    return {
        "contract_version": VERSION,
        "commit": subprocess.check_output(["git", "rev-parse", "HEAD"],
                                          cwd=ROOT, text=True).strip(),
        "source_file_count": len(paths),
        "source_manifest_digest": combined.hexdigest(),
        "tool_sha256": tools,
    }


def main() -> None:
    if sys.argv[1:] == ["record"]:
        RECORD.parent.mkdir(parents=True, exist_ok=True)
        RECORD.write_text(json.dumps(current(), indent=2, sort_keys=True) + "\n")
        print("R2 exact build source and tools recorded")
    elif sys.argv[1:] == ["check"]:
        if not RECORD.is_file() or json.loads(RECORD.read_text()) != current():
            raise SystemExit("R2 owning guard source/tool artifact binding drifted")
        print("R2 exact build source and tools match")
    else:
        raise SystemExit("usage: phase26_r2_tool_binding.py record|check")


if __name__ == "__main__":
    main()
