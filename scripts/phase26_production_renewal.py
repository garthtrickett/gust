#!/usr/bin/env python3
"""Prepare the selected worker renewal; only a real public signature admits it.

This is source-publication tooling, not a package-supplied trust update. It has
no signing operation and never accepts a replacement key or freshness override.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
PROFILE = ROOT / "compiler/experiments/cranelift/production"
HISTORY = PROFILE / "epoch1"
KEY = "edb0cc88828921e2c3cc7cc6633f646a7b72537331b3ea578e365c8a5fd94dae"
SIGNER = "gust-github-release-1"
HISTORICAL_KEY = "6778b05d2ef8f7af4f553918b2b5658eba1d7919536ab3b64c69e63fd5e0b550"
DOMAIN = b"gust-approved-native-package-v2\0"
EPOCHS = ("release_epoch", "minimum_package_epoch", "key_first_epoch", "key_last_epoch")
HISTORY_PINS = {
    "predecessor-baseline-v4.json.gz": "5da70567528d2e2f3b70ca7bd3028816819d2ecdca0ae250ef8e4e61d82b6bc5",
    "predecessor-baseline-v3.json.gz": "86f54ea30392f3cab6ffd05eabac6c109190814eda50b64dbb62cacf9939e03c",
    "public-identity.json": "5116cf043f6aa8b42a8018f14aa195722d738a1ab0ddc8d04db62c472aac8529",
    "predecessor-baseline-v2.json.gz": "30e78dbe50b8b0b0fb2daa6614f8cbab5eb8844f8f666a041408d3aae7acfb03",
    "manifest.txt": "eba10d837fcaaaca525359dbaed8f953493ce3407b8149ebea8e526d524e3ab1",
    "manifest.sig": "ca663c4013fa5e793652e0759ea7b9f79cd204c01a00c830cc6d168e42ab7d39",
    "snapshot.json": "810b6ca7660b7c3ad36ebf1c1bae4c03fea247e1f3a5e0dd867a079ebdca6c79",
    "production_trust.rs": "9de4a2ed0db9b585ca181c3d13b7aacd3898f7152af92a7db9483a94d2265434",
    "predecessor-baseline.json.gz": "73089a2c9dbadb629efc24d28f9d42aacfe73e6ea9374a74513935ebb524e54d",
}


def require(ok, message):
    if not ok:
        raise SystemExit("production renewal: " + message)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def load(path):
    return json.loads(path.read_text())


def key_array(key):
    value = bytes.fromhex(key)
    return "\n            ".join(",".join(f"0x{x:02x}" for x in value[i:i+8]) +
        ("," if i < 24 else "") for i in range(0, 32, 8))


def historical_key_array():
    return key_array(HISTORICAL_KEY)


def selected_key_array():
    return key_array(KEY)


def checked_profile():
    for name, expected in HISTORY_PINS.items():
        require(digest((HISTORY / name).read_bytes()) == expected,
                "immutable epoch1 history changed: " + name)
    old = load(HISTORY / "snapshot.json")
    snapshot = load(PROFILE / "snapshot.json")
    require(tuple(snapshot.get(name) for name in EPOCHS) == (2, 2, 2, 2),
            "selected epoch2 range changed")
    require(snapshot.get("signer") == SIGNER and snapshot.get("public_key_hex") == KEY and
            old["signer"] == "gust-native-release-1" and old["public_key_hex"] == HISTORICAL_KEY,
            "selected public identity changed")
    issued, expires = snapshot.get("issued_unix_seconds"), snapshot.get("expires_unix_seconds")
    require(type(issued) is int and type(expires) is int and issued > old["expires_unix_seconds"] and
            snapshot.get("maximum_validity_seconds") == 604800 and expires - issued == 604800,
            "selected assembly interval changed")
    require(snapshot.get("revoked_keys") == [] and snapshot.get("withdrawn_digests") == [],
            "enrolled revocation/withdrawal state changed; honor applicable contrary authority")
    worker = (HISTORY / "production_trust.rs").read_text()
    for before, after in [
        ("id: \"gust-native-release-1\",", f"id: \"{SIGNER}\","),
        (historical_key_array(), selected_key_array()),
        ("release_epoch: 1,", "release_epoch: 2,"),
        ("minimum_package_epoch: 1,", "minimum_package_epoch: 2,"),
        ("first_epoch: 1, last_epoch: 1,", "first_epoch: 2, last_epoch: 2,"),
        (f"issued_unix_seconds: {old['issued_unix_seconds']},", f"issued_unix_seconds: {issued},"),
        (f"expires_unix_seconds: {old['expires_unix_seconds']},", f"expires_unix_seconds: {expires},"),
    ]:
        require(worker.count(before) == 1, "historical worker anchor changed")
        worker = worker.replace(before, after, 1)
    require((ROOT / "compiler/experiments/cranelift/src/production_trust.rs").read_text() == worker,
            "worker differs from selected epoch/time/public-identity renewal")
    manifest = (PROFILE / "manifest.txt").read_bytes()
    assembly = load(PROFILE / "renewal-assembly.json")
    require(digest(manifest) == snapshot["manifest_sha256"] == assembly["manifest_sha256"] and
            digest(DOMAIN + manifest) == assembly["canonical_message_sha256"] and
            issued == assembly["issued_unix_seconds"] and expires == assembly["expires_unix_seconds"],
            "actual assembly message/time binding changed")
    lines = manifest.decode().splitlines()
    require(lines.count("epoch: 2") == 1 and lines.count("artifact_count: 12") == 1 and
            lines.count("signer: " + SIGNER) == 1,
            "actual manifest epoch or population changed")
    artifacts = [dict(zip(("kind", "name", "sha256"), line.removeprefix("artifact: ").split("|")))
                 for line in lines if line.startswith("artifact: ")]
    require(artifacts == assembly["artifacts"] and len(artifacts) == 12 and
            len({row["name"] for row in artifacts}) == 12,
            "actual artifact manifest changed")
    require(assembly["assembly_script_sha256"] ==
            digest((ROOT / "scripts/phase26_production_package.py").read_bytes()),
            "assembler changed since actual assembly; reassemble before signing")
    return snapshot, DOMAIN + manifest


def check_signature(signature, message, *, public_key=KEY):
    require(len(signature) == 64, "real Ed25519 public signature must be exactly64 bytes")
    parent = ROOT / "build/guards"
    parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="renewal-public-verification-", dir=parent) as temporary:
        directory = Path(temporary)
        (directory / "public.der").write_bytes(bytes.fromhex("302a300506032b6570032100" + public_key))
        (directory / "message.bin").write_bytes(message)
        (directory / "signature.bin").write_bytes(signature)
        result = subprocess.run(["openssl", "pkeyutl", "-verify", "-pubin", "-keyform", "DER",
            "-inkey", str(directory / "public.der"), "-rawin", "-in", str(directory / "message.bin"),
            "-sigfile", str(directory / "signature.bin")], capture_output=True)
        require(result.returncode == 0, "public signature does not verify for exact enrolled message/key")


def validate():
    snapshot, message = checked_profile()
    now = int(time.time())
    require(snapshot["issued_unix_seconds"] <= now < snapshot["expires_unix_seconds"],
            "actual worker snapshot is not currently valid")
    path = PROFILE / "manifest.sig"
    require(path.is_file(), "real epoch2 public signature missing; unsigned preparation cannot qualify")
    check_signature(path.read_bytes(), message)
    print("SELECTED_EPOCH2_SIGNATURE_AND_PROFILE_PASS; full qualification remains separate")


def handoff(output):
    snapshot, message = checked_profile()
    output.mkdir(mode=0o700, parents=False, exist_ok=False)
    (output / "canonical-message.bin").write_bytes(message)
    (output / "public-key.der").write_bytes(bytes.fromhex("302a300506032b6570032100" + KEY))
    request = dict(status="UNSIGNED; actual signature required, no production qualification",
        key_id=SIGNER, public_key_hex=KEY,
        canonical_message_sha256=digest(message), canonical_message_bytes=len(message),
        snapshot=snapshot, required_signature_format="raw64-byte Ed25519 public signature",
        signature_destination=str(output / "manifest.sig"),
        no_private_material_accessed=True)
    (output / "handoff.json").write_text(json.dumps(request, indent=2) + "\n")
    print(json.dumps(request))


def accept_public_signature(path):
    snapshot, message = checked_profile()
    require(snapshot["issued_unix_seconds"] <= int(time.time()) < snapshot["expires_unix_seconds"],
            "actual worker snapshot is not currently valid")
    signature = path.read_bytes()
    check_signature(signature, message)
    destination = PROFILE / "manifest.sig"
    # Never overwrite an enrolled/frozen public signature during a handoff.
    with destination.open("xb") as stream:
        stream.write(signature)
    print("PUBLIC_SIGNATURE_INGESTED; re-enumeration, reviews and all actual qualification still required")


def inversions():
    """Actual public crypto and fail-closed controls; never full production qualification."""
    import copy
    from unittest.mock import patch
    checked_profile()  # Positive exact current-source preparation baseline.
    count = 0
    def rejected(label, callback, expected):
        nonlocal count
        try:
            callback()
        except SystemExit as error:
            require(expected in str(error), label + ": REJECTED (different assertion): " + str(error))
            print(label + ": REJECTED (expected assertion): " + str(error), flush=True)
            count += 1
        else:
            raise SystemExit(label + ": ACCEPTED")
    original_load = load
    for field, value, expected in (
        *((field, value, "epoch2 range") for field in EPOCHS for value in (1, 3)),
        ("signer", "other", "public identity"),
        ("public_key_hex", "0" * 64, "public identity"),
        ("maximum_validity_seconds", 604801, "assembly interval"),
        ("expires_unix_seconds", 0, "assembly interval"),
        ("issued_unix_seconds", "not a timestamp", "assembly interval"),
        ("revoked_keys", [SIGNER], "revocation/withdrawal state"),
        ("withdrawn_digests", ["0" * 64], "revocation/withdrawal state"),
    ):
        changed = copy.deepcopy(original_load(PROFILE / "snapshot.json"))
        changed[field] = value
        with patch.dict(globals(), load=lambda p: changed if p == PROFILE / "snapshot.json" else original_load(p)):
            rejected("snapshot-" + field + "=" + str(value), checked_profile, expected)
    original_read = Path.read_bytes
    for name in HISTORY_PINS:
        with patch.object(Path, "read_bytes", lambda p, name=name:
                original_read(p) + b"\n" if p == HISTORY / name else original_read(p)):
            rejected("historical-" + name, checked_profile, "immutable epoch1 history")
    snapshot, message = checked_profile()
    old_message = DOMAIN + (HISTORY / "manifest.txt").read_bytes()
    old_signature = (HISTORY / "manifest.sig").read_bytes()
    check_signature(old_signature, old_message, public_key=HISTORICAL_KEY)  # Actual original crypto.
    check_signature((PROFILE / "manifest.sig").read_bytes(), message)  # Actual current crypto.
    rejected("new-signature-old-key", lambda: check_signature((PROFILE / "manifest.sig").read_bytes(), message, public_key=HISTORICAL_KEY), "does not verify")
    rejected("new-signature-wrong-message", lambda: check_signature((PROFILE / "manifest.sig").read_bytes(), message + b"\n"), "does not verify")
    altered = bytearray((PROFILE / "manifest.sig").read_bytes()); altered[0] ^= 1
    rejected("tampered-current-signature", lambda: check_signature(bytes(altered), message), "does not verify")
    for width in (0, 1, 63, 65):
        rejected("signature-width-" + str(width),
                 lambda width=width: check_signature(bytes(width), message), "exactly64")
    rejected("old-signature-new-message", lambda: check_signature(old_signature, message), "does not verify")
    rejected("unsigned64", lambda: check_signature(bytes(64), message), "does not verify")
    original_is_file = Path.is_file
    with patch.object(Path, "is_file", lambda p: False if p == PROFILE / "manifest.sig" else original_is_file(p)):
        rejected("missing-current-signature", validate, "real epoch2 public signature missing")
    print("RENEWAL_PUBLIC_CRYPTO_AND_REFUSAL_CONTROLS_PASS", count,
          "expected refusals; full production qualification remains separate")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("prepare-check")
    commands.add_parser("validate")
    commands.add_parser("inversions")
    for name, argument in (("handoff", "output"), ("accept-public-signature", "signature")):
        commands.add_parser(name).add_argument(argument, type=Path)
    args = parser.parse_args()
    if args.command == "prepare-check":
        checked_profile()
        print("UNSIGNED_PROFILE_PREPARATION_PASS; no signature or production qualification")
    elif args.command == "validate":
        validate()
    elif args.command == "inversions":
        inversions()
    elif args.command == "handoff":
        handoff(args.output)
    else:
        accept_public_signature(args.signature)
