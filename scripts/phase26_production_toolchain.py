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
import subprocess

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


def fetch(pins, directory):
    directory.mkdir(parents=True, exist_ok=False)
    packages = []
    for package in pins["packages"]:
        path = directory / Path(package["filename"]).name
        subprocess.run(["curl", "--proto", "=https", "--tlsv1.2", "--fail", "--location",
                        "--silent", "--show-error", "--retry", "2", "--max-time", "60",
                        package["url"], "-o", str(path)], check=True)
        if digest(path) != package["sha256"]:
            raise SystemExit(f"production dependency digest mismatch: {package['package']}")
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
            subprocess.run(["sudo", "apt-get", "install", "-y", "--allow-downgrades",
                            "--no-install-recommends", "--no-remove", *packages], check=True)
            subprocess.run(["rustup", "toolchain", "install", pins["rust_toolchain"], "--profile", "minimal"], check=True)
            subprocess.run(["rustup", "default", pins["rust_toolchain"]], check=True)
            verify(pins)
        print("PUBLIC_PINNED_DEPENDENCIES_ACQUIRED", flush=True)
