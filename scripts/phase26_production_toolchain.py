#!/usr/bin/env python3
"""Acquire exact public revisions of existing production build dependencies.

Default mode only verifies this host. Download mode writes a private directory.
Installation is confined to the repository's ephemeral GitHub runner job.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

import phase26_toolchain_compatibility

ROOT = Path(__file__).resolve().parents[1]
PIN = ROOT / "compiler/experiments/cranelift/production/build-toolchain.json"


def digest(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def verify(pins):
    for package in pins["packages"]:
        actual = subprocess.check_output(["dpkg-query", "-W", "-f=${Version}", package["package"]], text=True).strip()
        if actual != package["version"]:
            raise SystemExit(f"production toolchain version mismatch: {package['package']} {actual} != {package['version']}")
    version = subprocess.check_output(["rustc", "--version"], text=True)
    if not version.startswith("rustc " + pins["rust_toolchain"] + " ") or pins["rustc_commit"] not in version:
        raise SystemExit("production Rust toolchain mismatch")
    print("PRODUCTION_BUILD_TOOLCHAIN_VERIFIED", flush=True)


def partial_size(path):
    if path.is_symlink() or (path.exists() and not path.is_file()):
        raise SystemExit("production dependency partial is not a regular file")
    return path.stat().st_size if path.exists() else 0


def fetch_package(package, path):
    partial = path.with_suffix(path.suffix + ".partial")
    retryable_http = {"408", "429", "500", "502", "503", "504", "522", "524"}
    for attempt in range(3):
        offset = partial_size(partial)
        command = ["curl", "--proto", "=https", "--tlsv1.2", "--fail", "--location",
                   "--silent", "--show-error", "--max-time", "60",
                   "--write-out", "%{http_code}\\t%header{content-range}\\n",
                   "-o", str(partial)]
        if offset:
            command.extend(("--continue-at", str(offset)))
        completed = subprocess.run([*command, package["url"]], stdout=subprocess.PIPE, text=True)
        response, content_range = completed.stdout.strip("\n").split("\t", 1)
        size = partial_size(partial)
        if offset and (response in ("200", "206") or size != offset or completed.returncode == 0):
            match = re.fullmatch(r"bytes (\d+)-(\d+)/(\d+)", content_range.strip())
            if response != "206" or match is None:
                raise SystemExit("production dependency resume did not return a byte range")
            start, end, total = map(int, match.groups())
            if start != offset or not offset <= size <= total or end != total - 1 or offset > end:
                raise SystemExit("production dependency resume returned an inconsistent byte range")
            if completed.returncode == 0 and size != total:
                raise SystemExit("production dependency resume ended with an incomplete byte range")
        elif not offset and (size or completed.returncode == 0) and response != "200":
            raise SystemExit("production dependency initial response was not a full transfer")

        if completed.returncode == 0:
            if not partial.is_file() or digest(partial) != package["sha256"]:
                raise SystemExit(f"production dependency digest mismatch: {package['package']}")
            partial.rename(path)
            return

        retryable = completed.returncode == 28 or (completed.returncode == 22 and response in retryable_http)
        if not retryable or attempt == 2:
            completed.check_returncode()
        time.sleep(2 ** attempt)


def fetch(pins, directory):
    directory.mkdir(parents=True, exist_ok=False)
    packages = []
    for package in pins["packages"]:
        path = directory / Path(package["filename"]).name
        fetch_package(package, path)
        packages.append(str(path))
    return packages


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["verify", "download", "install-ci"])
    parser.add_argument("directory", nargs="?", type=lambda p: Path(p).resolve())
    args = parser.parse_args()
    pins = json.loads(PIN.read_text())
    if args.mode == "verify": verify(pins)
    else:
        if args.directory is None: parser.error("download/installation requires a new output directory")
        if args.mode == "install-ci":
            if os.environ.get("GITHUB_ACTIONS") != "true" or os.environ.get("GITHUB_REPOSITORY") != "garthtrickett/gust":
                raise SystemExit("production toolchain installation is only for the owning ephemeral CI runner")
            # These are revisions of already-installed build dependencies,
            # not permission to add a package or bypass dependency resolution.
            for package in pins["packages"]:
                state = subprocess.check_output(["dpkg-query", "-W", "-f=${db:Status-Status}", package["package"]], text=True)
                if state != "installed": raise SystemExit("required existing build dependency absent: " + package["package"])
        packages = fetch(pins, args.directory)
        if args.mode == "install-ci":
            phase26_toolchain_compatibility.install(
                pins, packages, args.directory, fetch, digest(PIN))
            subprocess.run(["rustup", "toolchain", "install", pins["rust_toolchain"], "--profile", "minimal"], check=True)
            subprocess.run(["rustup", "default", pins["rust_toolchain"]], check=True)
            verify(pins)
        print("PUBLIC_PINNED_DEPENDENCIES_ACQUIRED", flush=True)
