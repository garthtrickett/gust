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
import platform
import re
import subprocess
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs" / "RELEASE_MANIFEST.json"
SEED_ENV = "GUST_BOOTSTRAP_SEED"

# A digest is 64 LOWERCASE HEX characters. The previous length-only check
# accepted 64 'z' characters as a sha256.
SHA256_RE = re.compile(r"[0-9a-f]{64}")

# Every artifact declares what it is. Without this, the seed lookup treated
# the fixed-point proof log as a bootstrap compiler.
BRIDGE_ROLE = "bridge_compiler"
ARTIFACT_ROLES = frozenset({BRIDGE_ROLE, "fixed_point_proof", "source_seed"})


def host_target() -> str:
    machine = platform.machine()
    system = platform.system().lower()
    return f"{machine}-{system}"


def annotated_tag(tag: str) -> bool:
    """True only for an annotated tag object, not a lightweight ref."""
    out = subprocess.run(["git", "cat-file", "-t", tag], cwd=ROOT,
                         capture_output=True, text=True)
    return out.returncode == 0 and out.stdout.strip() == "tag"


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
    # Only a bridge compiler for THIS target is a seed. Keying on every
    # artifact digest meant the fixed-point proof log, or a binary for
    # another platform, verified successfully and was then handed to the
    # build as a compiler.
    host = host_target()
    known = {}
    for release in record["releases"]:
        for entry in release["artifacts"]:
            if entry.get("role") != BRIDGE_ROLE:
                continue
            known[entry["digest"]] = (release["tag"], entry["name"],
                                      entry.get("target"))
    got = digest(artifact)
    require(got in known,
            f"{path} has digest {got}, which no tracked release lists as a "
            f"{BRIDGE_ROLE!r}. An unverified seed is exactly what option B "
            "exists to avoid -- publish it and commit the digest, or do not "
            "use it. A proof log or another platform's binary is not a seed.")
    tag, name, target = known[got]
    require(target == host,
            f"{name} from {tag} targets {target!r} but this host is "
            f"{host!r}; a bridge binary for another platform cannot bootstrap "
            "here, and silently accepting it would fail later and elsewhere.")
    print(f"guard-cranelift-phase25-release-manifest: {path} verified as "
          f"{name} from {tag} for {target}")


def validate() -> None:
    record = load()
    require(record.get("version") == "phase25_release_manifest_v1",
            "release manifest version drifted")
    releases = record["releases"]
    if not releases:
        # NOT "ok". An empty manifest is the absence of the thing this patch
        # exists to produce, and printing success for it is how a release
        # guard goes green with no release. P13 puts the tag on merged main,
        # so 25.8a lands the mechanics and 25.8 cuts release 0 -- this is
        # that outstanding step, named, not a silent pass.
        print("guard-cranelift-phase25-release-manifest: MECHANICS ONLY. "
              "No release is minted yet.\n"
              "  - Patch 25.8 mints release 0 from the current gust_v4.c, "
              "before 25.10 deletes the emitter that can regenerate it.\n"
              "  - P13 requires the tag on merged `main`, so it cannot be "
              "cut from this branch; 25.8a lands the mechanics it needs.\n"
              "  The offline seed path is wired and exercisable "
              f"({SEED_ENV}), and every check below arms the moment a "
              "release appears.")
        return
    seen = set()
    for release in releases:
        tag = release.get("tag", "?")
        for field in ("tag", "artifacts", "fixed_point_proof", "signature"):
            require(release.get(field),
                    f"release {tag} is missing {field}; the fixed-point "
                    "proof is the attestation that matters and a release "
                    "without one is trusted, not verified")
        require(tag not in seen, f"duplicate tag {tag}")
        seen.add(tag)
        require(annotated_tag(tag),
                f"{tag} is not an annotated tag in this repository. O8 says "
                "a release IS an annotated tag; a manifest naming a tag that "
                "does not exist is a claim about nothing.")
        names, roles = set(), []
        for entry in release["artifacts"]:
            name = entry.get("name")
            require(name and name not in names,
                    f"{tag} has a missing or duplicated artifact name "
                    f"{name!r}")
            names.add(name)
            require(SHA256_RE.fullmatch(entry.get("digest", "")),
                    f"{tag}/{name} has no sha256: a digest must be 64 "
                    "lowercase hex characters, and 64 of anything else "
                    "passed the previous check.")
            require(entry.get("role") in ARTIFACT_ROLES,
                    f"{tag}/{name} has role {entry.get('role')!r}, not one "
                    f"of {sorted(ARTIFACT_ROLES)}; without a role every "
                    "artifact reads as a usable bootstrap seed.")
            if entry["role"] == BRIDGE_ROLE:
                require(entry.get("target"),
                        f"{tag}/{name} is a {BRIDGE_ROLE} with no target; a "
                        "bridge binary is only a seed on its own platform.")
            roles.append(entry["role"])
        require(BRIDGE_ROLE in roles,
                f"{tag} publishes no {BRIDGE_ROLE}, so nothing in it can "
                "seed a bootstrap -- which is what O9's escape requires.")
        require(release["fixed_point_proof"] in names,
                f"{tag}'s fixed_point_proof "
                f"{release['fixed_point_proof']!r} is not one of its "
                f"artifacts {sorted(names)}; an attestation that is not "
                "published cannot be regenerated by anyone.")
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
