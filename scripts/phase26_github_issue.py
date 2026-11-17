#!/usr/bin/env python3
"""Issue an untrusted public candidate with a one-shot GitHub-held Ed25519 key.

Only the reviewed GitHub job may execute this command. Private bytes remain on
that ephemeral runner. An output key is not enrolled until separately reviewed
and pinned in a worker release; this command never updates a worker or snapshot.
"""
from __future__ import annotations

import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
KEY_ID = "gust-github-release-1"
BRANCH = "refs/heads/codex/phase26-github-release-signing"
SPKI_PREFIX = bytes.fromhex("302a300506032b6570032100")


def require(ok, label):
    if not ok:
        raise RuntimeError(label)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def openssl(arguments, label):
    result = subprocess.run(["/usr/bin/openssl", *map(str, arguments)],
        env={"PATH": "/usr/bin:/bin", "LC_ALL": "C"},
        capture_output=True, timeout=30)
    # Never expose private diagnostics, stdout, key bytes or command arguments.
    require(result.returncode == 0, label)
    return result.stdout


def main():
    require(os.environ.get("GITHUB_ACTIONS") == "true" and os.getuid() != 0,
            "requires actual unprivileged GitHub runner")
    for name, value in {
        "GITHUB_REPOSITORY": "garthtrickett/gust", "GITHUB_REPOSITORY_ID": "1263612197",
        "GITHUB_ACTOR_ID": "3760677", "GITHUB_EVENT_NAME": "push",
        "GITHUB_REF": BRANCH, "GITHUB_RUN_ATTEMPT": "1",
    }.items():
        require(os.environ.get(name) == value, "GitHub identity or trigger mismatch: " + name)
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    require(head == os.environ["GITHUB_SHA"], "checkout differs from triggering commit")
    candidate_script = ROOT / "scripts/phase26_github_package_candidate.py"
    require(sha(candidate_script) == os.environ["REVIEWED_CANDIDATE_SHA256"] and
            sha(Path(__file__)) == os.environ["REVIEWED_ISSUER_SHA256"],
            "reviewed candidate/issuer bytes differ")
    subprocess.run(["python3", "scripts/phase26_production_toolchain.py", "verify"],
                   cwd=ROOT, check=True)
    require(sha(ROOT / "compiler/experiments/cranelift/src/production_trust.rs") ==
            "9de4a2ed0db9b585ca181c3d13b7aacd3898f7152af92a7db9483a94d2265434",
            "authenticated predecessor trust state changed; reassess revocations")
    history = ROOT / "compiler/experiments/cranelift/production/manifest.txt"
    require(sha(history) == "eba10d837fcaaaca525359dbaed8f953493ce3407b8149ebea8e526d524e3ab1",
            "original artifact manifest changed")
    expected = {line.split("|")[1]: line.split("|")[2]
                for line in history.read_text().splitlines() if line.startswith("artifact: ")}
    require(len(expected) == 12, "original artifact population changed")
    package = ROOT / "build/github-r3/build/package"
    names = ("zlib-1.3.2.tar.gz", "gust_zlib_adapter.c", "gust_zlib_adapter.h", "zlib.h",
             "zconf.h", "zlib-LICENSE", "build-options.txt", "gust_zlib_adapter.o", "libz.a")
    for name in names:
        require(sha(package / name) == expected[name], "actual public component differs: " + name)
    runtime = ROOT / "build/gust-runtime-package.a"
    require(sha(runtime) == expected["gust-runtime-package.a"], "actual runtime bytes differ")
    print("PUBLIC_INPUTS_VERIFIED; private generation has not started", flush=True)

    output = ROOT / "build/guards/phase26_github_signed_candidate"
    output.parent.mkdir(parents=True, exist_ok=True)
    require(not output.exists(), "candidate output already exists")
    spec = importlib.util.spec_from_file_location("public_candidate", candidate_script)
    assembler = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(assembler)
    os.umask(0o077)
    # No existing local or GitHub secret is read. This key exists for this job only.
    with tempfile.TemporaryDirectory(prefix="gust-epoch2-private-", dir=os.environ["RUNNER_TEMP"]) as temporary:
        private = Path(temporary) / "key.pem"
        openssl(["genpkey", "-algorithm", "ED25519", "-out", private], "key generation failed")
        require(stat.S_IMODE(private.stat().st_mode) == 0o600, "private key mode differs")
        der = openssl(["pkey", "-in", private, "-pubout", "-outform", "DER"], "public derivation failed")
        require(len(der) == 44 and der[:12] == SPKI_PREFIX, "generated public algorithm differs")
        identity = dict(provisioned_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
            key_id=KEY_ID, algorithm="Ed25519", public_key_hex=der[12:].hex(), public_key_bytes=32,
            public_spki_sha256=hashlib.sha256(der).hexdigest(),
            release_signing_custody_withdrawal_owner="garthtrickett",
            private_material_policy="One-shot ephemeral GitHub runner only; no private bytes in output/source/agent state",
            worker_enrollment="PENDING explicit reviewed source-pinned worker publication")
        public_input = Path(temporary) / "public-identity.json"
        write(public_input, identity)
        assembler.assemble(package, runtime, public_input, output)
        request = json.loads((output / "signing-request.json").read_text())
        require(request["signer"] == KEY_ID and request["public_key_hex"] == der[12:].hex() and
                all(request[name] == 2 for name in ("release_epoch", "minimum_package_epoch", "key_first_epoch", "key_last_epoch")),
                "candidate identity/epoch differs")
        now = int(datetime.datetime.now(datetime.timezone.utc).timestamp())
        require(request["issued_unix_seconds"] <= now < request["expires_unix_seconds"] and
                request["expires_unix_seconds"] - request["issued_unix_seconds"] == 604800,
                "actual assembly freshness differs")
        message = output / "canonical-message.bin"
        require(message.read_bytes() == b"gust-approved-native-package-v2\0" +
                (output / "package/manifest.txt").read_bytes(), "canonical message differs")
        signature = output / "package/manifest.sig"
        openssl(["pkeyutl", "-sign", "-rawin", "-inkey", private, "-in", message, "-out", signature],
                "candidate signing failed")
        require(signature.stat().st_size == 64, "signature width differs")
        public = Path(temporary) / "public.der"
        public.write_bytes(der)
        openssl(["pkeyutl", "-verify", "-pubin", "-keyform", "DER", "-inkey", public,
                 "-rawin", "-in", message, "-sigfile", signature], "public signature verification failed")
        shutil.copyfile(public_input, output / "public-identity.json")
        (output / "public-key.der").write_bytes(der)
    # Private temporary material is unlinked; hosted storage secure erasure is not asserted.
    snapshot = {name: request[name] for name in ("signer", "public_key_hex", "manifest_sha256",
        "release_epoch", "minimum_package_epoch", "key_first_epoch", "key_last_epoch",
        "issued_unix_seconds", "expires_unix_seconds", "maximum_validity_seconds")}
    snapshot.update(revoked_keys=[], withdrawn_digests=[])
    write(output / "snapshot.json", snapshot)
    write(output / "github-provenance.json", dict(
        status="ACTUAL signed public candidate ONLY; no worker enrollment or qualification",
        repository_id=os.environ["GITHUB_REPOSITORY_ID"], actor_id=os.environ["GITHUB_ACTOR_ID"],
        head_sha=head, ref=os.environ["GITHUB_REF"], event=os.environ["GITHUB_EVENT_NAME"],
        run_id=os.environ["GITHUB_RUN_ID"], run_attempt=os.environ["GITHUB_RUN_ATTEMPT"],
        key_id=KEY_ID, public_key_hex=der[12:].hex(), public_der_sha256=hashlib.sha256(der).hexdigest(),
        canonical_message_sha256=sha(message), signature_sha256=sha(signature),
        candidate_script_sha256=sha(candidate_script), issuer_sha256=sha(Path(__file__)),
        artifact_inputs={name: sha(package / name) for name in names}, runtime_sha256=sha(runtime),
        private_output=False, worker_enrolled=False))
    print("PUBLIC_CANDIDATE_SIGNED_AND_VERIFIED; worker enrollment remains pending", flush=True)


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as error:
        raise SystemExit("GitHub candidate issuance refused: " + str(error))
    except Exception:
        # Normal toolchain/build failures are diagnosed before the private step.
        # A private operation emits only a stage label, never private diagnostics.
        raise SystemExit("GitHub candidate issuance refused; no private diagnostics emitted")
