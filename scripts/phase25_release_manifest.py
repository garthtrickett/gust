#!/usr/bin/env python3
"""Patch 25.8: what a Gust release is, and what makes one verifiable.

D1 bootstraps from the previous release and D7 requires an independently
auditable chain, but neither said what a release IS. O8, O9 and O10 settle
it and this implements them.

A release is:

  1. an annotated git tag;
  2. an artifact set attached to it -- the per-platform bridge binaries of
     D1 option B, and the fixed-point proof log;
  3. a MANIFEST listing every artifact with its digest.

The manifest, and ONLY the manifest, is committed. Binaries live as release
assets. P15 corrected D1 here: its option B originally said the binary
itself was committed, which contradicted O8 and would write blobs into git
history permanently -- the opacity D1's own ranking held against option C.
Publishing the binary and committing its digest keeps the property option B
buys, which is a bridge that needs no previous release.

THE NETWORK IS NEVER ON THE CRITICAL PATH. `GUST_BOOTSTRAP_SEED=/path`
takes a local artifact and verifies it against the tracked manifest.
Fetching is a convenience. An auditable chain that cannot be built offline
is not auditable by anyone who does not already trust the host, which is
most of the people the property is for.

N-1 FLOOR (O9). Release N builds from N-1 and nothing older is promised.
Tags and assets are kept forever -- they cost nothing -- but the supported,
tested path is one step. Promising more means testing more, and a chain
nobody exercises is already broken. The escape is D1's published bridge:
if the chain breaks, it re-enters in one step. That is what B is FOR.

TWO ATTESTATION LAYERS, and the reproducible one wins (O10). The
fixed-point proof says what the artifact IS and anyone can regenerate it. A
signed manifest says who published it. If they ever disagree the fixed
point wins and the release is withdrawn: a signature on a blob nobody can
reproduce is trust, not verification.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs" / "RELEASE_MANIFEST.json"
SEED_ENV = "GUST_BOOTSTRAP_SEED"


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"guard-cranelift-phase25-release-manifest: {message}")
        raise SystemExit(1)


def load() -> dict:
    if not MANIFEST.is_file():
        return {"version": "phase25_release_manifest_v1", "releases": []}
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def verify_seed() -> None:
    """Verify a locally-supplied seed against the tracked manifest."""
    path = os.environ.get(SEED_ENV)
    require(path, f"{SEED_ENV} is unset. The offline path is the point: a "
                  "chain that can only be fetched is not auditable by "
                  "anyone who does not trust the host.")
    artifact = Path(path)
    require(artifact.is_file(), f"{SEED_ENV}={path} is not a file")
    record = load()
    known = {
        entry["digest"]: (release["tag"], entry["name"])
        for release in record["releases"] for entry in release["artifacts"]
    }
    got = digest(artifact)
    require(got in known,
            f"{path} has digest {got}, which no tracked release manifest "
            "lists. An unverified seed is exactly what option B exists to "
            "avoid -- publish it and commit the digest, or do not use it.")
    tag, name = known[got]
    print(f"guard-cranelift-phase25-release-manifest: {path} verified as "
          f"{name} from {tag}")


def validate() -> None:
    record = load()
    require(record.get("version") == "phase25_release_manifest_v1",
            "release manifest version drifted")
    releases = record["releases"]
    if not releases:
        print("guard-cranelift-phase25-release-manifest: ok (no releases "
              "yet; Patch 25.9 mints release 0 from the current gust_v4.c, "
              "before 25.10 deletes the emitter that can regenerate it)")
        return
    seen = set()
    for release in releases:
        for field in ("tag", "artifacts", "fixed_point_proof"):
            require(release.get(field),
                    f"release {release.get('tag', '?')} is missing {field}; "
                    "the fixed-point proof is the attestation that matters "
                    "and a release without one is trusted, not verified")
        require(release["tag"] not in seen, f"duplicate tag {release['tag']}")
        seen.add(release["tag"])
        for entry in release["artifacts"]:
            require(len(entry.get("digest", "")) == 64,
                    f"{release['tag']}/{entry.get('name')} has no sha256")
    print(f"guard-cranelift-phase25-release-manifest: ok "
          f"({len(releases)} releases, N-1 floor, offline seed path via "
          f"{SEED_ENV})")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command",
                        choices=["validate", "verify-seed", "report"])
    args = parser.parse_args()
    if args.command == "report":
        print(json.dumps(load(), indent=2, sort_keys=True))
    elif args.command == "verify-seed":
        verify_seed()
    else:
        validate()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
