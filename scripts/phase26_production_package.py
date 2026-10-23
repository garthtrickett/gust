#!/usr/bin/env python3
"""Assemble public, unsigned production inputs; never access signing keys.

The worker enrollment and qualification are separate from this preparation.
The output must be a new directory, so a reviewed signing request is immutable
by construction across subsequent assembly attempts.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
KEY = "6778b05d2ef8f7af4f553918b2b5658eba1d7919536ab3b64c69e63fd5e0b550"
SOURCE = "bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16"
MEMBERS = ("crt1.o", "crti.o", "crtbeginT.o", "libc.a", "libm-2.39.a",
           "libmvec.a", "libgcc.a", "libgcc_eh.a", "crtend.o", "crtn.o")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def assemble(package: Path, runtime: Path, receipt: Path, output: Path) -> None:
    identity = json.loads(receipt.read_text())
    assert identity["key_id"] == "gust-native-release-1"
    assert identity["public_key_hex"] == KEY
    der = bytes.fromhex("302a300506032b6570032100" + identity["public_key_hex"])
    assert der == bytes.fromhex("302a300506032b6570032100" + KEY)
    assert hashlib.sha256(der).hexdigest() == identity["public_spki_sha256"]
    assert sha(package / "zlib-1.3.2.tar.gz") == SOURCE
    for name in ("gust_zlib_adapter.c", "gust_zlib_adapter.h"):
        assert (package / name).read_bytes() == (
            ROOT / "compiler/experiments/cranelift/ffi-zlib" / name).read_bytes()
    output.mkdir(mode=0o700, parents=False, exist_ok=False)
    destination = output / "package"
    destination.mkdir(mode=0o700)
    artifacts = [
        ("source", "zlib-1.3.2.tar.gz"), ("source", "gust_zlib_adapter.c"),
        ("header", "gust_zlib_adapter.h"), ("header", "zlib.h"),
        ("header", "zconf.h"), ("source", "zlib-LICENSE"),
        ("build_options", "build-options.txt"), ("object", "gust_zlib_adapter.o"),
        ("archive", "libz.a"),
    ]
    for _, name in artifacts:
        shutil.copyfile(package / name, destination / name)
    shutil.copyfile(runtime, destination / "gust-runtime-package.a")
    artifacts.append(("build_options", "gust-runtime-package.a"))
    closure = output / "link-closure"
    closure.mkdir(mode=0o700)
    pins = []
    for name in MEMBERS:
        path = Path(subprocess.check_output(
            ["/usr/bin/cc", "-print-file-name=" + name], text=True).strip()).resolve(strict=True)
        shutil.copyfile(path, closure / name)
        pins.append({"name": name, "source_path": str(path), "sha256": sha(closure / name)})
    subprocess.run(["/usr/bin/ar", "qcD", str(destination / "link-closure.a"),
                    *(str(closure / name) for name in MEMBERS)], check=True)
    artifacts.append(("build_options", "link-closure.a"))
    tools = []
    for name in ("cc", "ld", "as"):
        path = Path("/usr/bin") / name
        tools.append({"path": str(path), "resolved_path": str(path.resolve()), "sha256": sha(path)})
    provenance = {"format": "gust.production_link_closure.v1", "members": pins,
                  "tools": tools, "flags": "/usr/bin/ld -static --build-id=none -m elf_x86_64",
                  "link_order": ["crt1.o", "crti.o", "crtbeginT.o", "<generated-object>",
                                 "gust_zlib_adapter.o", "libz.a", "gust-runtime-package.a",
                                 "--start-group", "libc.a", "libm-2.39.a", "libmvec.a",
                                 "libgcc.a", "libgcc_eh.a", "--end-group", "crtend.o", "crtn.o"],
                  "artifact_source_commit": "c6916d3ede29d407f35e63fe222fcc8e01a80150",
                  "assembly_script_sha256": sha(Path(__file__)),
                  "release_owner": "garthtrickett"}
    (destination / "link-provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
    artifacts.append(("build_options", "link-provenance.json"))
    manifest = ["format: gust.approved_native_package.v2", "repository: garthtrickett/gust",
                "release: phase26-native-release-1", "package_id: gust_zlib_1_3_2_production",
                "epoch: 1", "signer: gust-native-release-1", "target: x86_64-unknown-linux-gnu",
                "object_format: Elf", "license: Zlib", f"artifact_count: {len(artifacts)}"]
    manifest += [f"artifact: {kind}|{name}|{sha(destination / name)}" for kind, name in artifacts]
    ptr = b"RawPointer(Byte)".hex()
    manifest += ["symbol_count: 3", "symbol: gust_zlib_bound|496e74|value|1|496e74@value|-",
                 f"symbol: gust_zlib_compress|496e74|value|5|{ptr}@borrow_read_call,496e74@value,{ptr}@borrow_write_call,496e74@value,496e74@value|0@1@read,2@3@write",
                 f"symbol: gust_zlib_decompress|496e74|value|4|{ptr}@borrow_read_call,496e74@value,{ptr}@borrow_write_call,496e74@value|0@1@read,2@3@write"]
    manifest_path = destination / "manifest.txt"
    manifest_path.write_bytes(("\n".join(manifest) + "\n").encode())
    message = output / "canonical-message.bin"
    message.write_bytes(b"gust-approved-native-package-v2\0" + manifest_path.read_bytes())
    issued = int(time.time())
    request = {"status": "UNSIGNED; preparation only, no production qualification",
               "signer": identity["key_id"], "public_key_hex": KEY,
               "canonical_message_path": str(message), "canonical_message_sha256": sha(message),
               "manifest_path": str(manifest_path), "manifest_sha256": sha(manifest_path),
               "artifact_manifest": provenance, "release_epoch": 1, "minimum_package_epoch": 1,
               "key_first_epoch": 1, "key_last_epoch": 1, "issued_unix_seconds": issued,
               "expires_unix_seconds": issued + 604800, "maximum_validity_seconds": 604800,
               "signature_destination": str(destination / "manifest.sig"),
               "authority_receipt_sha256": sha(receipt),
               "artifacts": [{"kind": k, "name": n, "sha256": sha(destination / n)} for k, n in artifacts]}
    path = output / "signing-request.json"
    path.write_text(json.dumps(request, indent=2) + "\n")
    print(str(path), sha(path))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("package", "runtime", "receipt", "output"):
        parser.add_argument(name, type=lambda value: Path(value).resolve())
    args = parser.parse_args()
    assemble(args.package, args.runtime, args.receipt, args.output)
