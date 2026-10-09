#!/usr/bin/env python3
"""Acquire the official rust:alpine image for the Phase 25 hosted-runner guards.

This only prepares the ephemeral runner. The guards still run their own
poisoned-PATH musl build/link probes against the unchanged rust:alpine name.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
from urllib.request import Request, urlopen


IMAGE = "rust:alpine"
MIRROR = "https://mirror.gcr.io"
HUB_TAG = "https://hub.docker.com/v2/repositories/library/rust/tags/alpine"
MIRROR_TAG = "https://mirror.gcr.io/v2/library/rust/manifests/alpine"
DAEMON_CONFIG = Path("/etc/docker/daemon.json")
INDEX_ACCEPT = "application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"phase25-ci-musl-image-cache: {message}")


def remote_identity() -> tuple[str, str]:
    with urlopen(HUB_TAG, timeout=20) as response:
        official = json.load(response)
    index_digest = official.get("digest")
    amd64 = [image["digest"] for image in official.get("images", [])
             if image.get("os") == "linux" and image.get("architecture") == "amd64"]
    require(isinstance(index_digest, str) and index_digest.startswith("sha256:")
            and len(amd64) == 1, "Docker Hub did not identify one official linux/amd64 image")

    request = Request(MIRROR_TAG, headers={"Accept": INDEX_ACCEPT})
    with urlopen(request, timeout=20) as response:
        mirrored_index = response.headers.get("Docker-Content-Digest")
        mirror = json.load(response)
    mirrored_amd64 = [image["digest"] for image in mirror.get("manifests", [])
                      if image.get("platform", {}).get("os") == "linux"
                      and image.get("platform", {}).get("architecture") == "amd64"]
    require(mirrored_index == index_digest and mirrored_amd64 == amd64,
            "mirror and official rust:alpine index/linux-amd64 digests differ")
    print(f"official and cached rust:alpine: index={index_digest} linux/amd64={amd64[0]}", flush=True)
    return index_digest, amd64[0]


def configure_daemon() -> None:
    DAEMON_CONFIG.parent.mkdir(parents=True, exist_ok=True)
    existing = json.loads(DAEMON_CONFIG.read_text()) if DAEMON_CONFIG.exists() else {}
    require(isinstance(existing, dict), "Docker daemon configuration is not a JSON object")
    mirrors = existing.get("registry-mirrors", [])
    require(isinstance(mirrors, list) and all(isinstance(m, str) for m in mirrors),
            "Docker registry-mirrors is not a string list")
    if not any(mirror.rstrip("/") == MIRROR for mirror in mirrors):
        existing["registry-mirrors"] = [MIRROR, *mirrors]
        mode = stat.S_IMODE(DAEMON_CONFIG.stat().st_mode) if DAEMON_CONFIG.exists() else 0o644
        with tempfile.NamedTemporaryFile(mode="w", dir=DAEMON_CONFIG.parent,
                                         prefix=".daemon.json.", delete=False) as output:
            json.dump(existing, output, indent=2)
            output.write("\n")
            temporary = Path(output.name)
        os.chmod(temporary, mode)
        os.replace(temporary, DAEMON_CONFIG)
        subprocess.run(["systemctl", "restart", "docker"], check=True)

    info = subprocess.run(["docker", "info", "--format", "{{json .RegistryConfig.Mirrors}}"],
                          check=True, capture_output=True, text=True)
    require(any(mirror.rstrip("/") == MIRROR for mirror in json.loads(info.stdout)),
            "Docker daemon did not enable the public cache")


def acquire(index_digest: str) -> None:
    subprocess.run(["docker", "pull", "--platform", "linux/amd64", IMAGE], check=True)
    result = subprocess.run(["docker", "image", "inspect", IMAGE],
                            check=True, capture_output=True, text=True)
    image = json.loads(result.stdout)[0]
    require(image.get("Os") == "linux" and image.get("Architecture") == "amd64",
            "pulled rust:alpine is not linux/amd64")
    require(any(digest.endswith("@" + index_digest) for digest in image.get("RepoDigests", [])),
            "pulled rust:alpine does not match the official OCI index digest")
    print("official rust:alpine is cached for the unchanged Phase 25 guard", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verify-only", action="store_true",
                        help="compare official/cache identity without changing Docker")
    args = parser.parse_args()
    index_digest, _ = remote_identity()
    if not args.verify_only:
        require(os.geteuid() == 0, "runner setup must run as root")
        configure_daemon()
        acquire(index_digest)


if __name__ == "__main__":
    main()
