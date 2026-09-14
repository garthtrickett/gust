#!/usr/bin/env python3
"""End-to-end mutation evidence: prove a converted guard fails on a wrong vector.

`phase24_frozen_oracle.py::validate_mutations` proves that `materialize`
transcribes its input faithfully — tamper with a vector, materialize it, assert
the bytes moved. That is the first arrow of

    vector -> materialize -> guard reads artifacts -> guard asserts

and it stops there. It does not prove that a converted guard would *fail* if the
vector were wrong. All of these pass it today: a guard that materializes a
vector and never compares the artifacts; one that compares exit status but
quietly stopped comparing stdout; one whose assertion was weakened during
conversion. #392's own exit gate asks for the rest — "a replacement that cannot
fail is a deleted test" — so this is the patch's stated step, not an extra.

This probe runs a real guard twice and requires it to FAIL and then PASS.

**Fails-then-passes, not just fails.** A guard broken for an unrelated reason
also fails when you mutate its vector. Asserting only "mutation -> guard fails"
lets a genuinely dead guard certify the loop closed — the defect being fixed,
reproduced inside its own fix. The passing leg is the same recipe, the same
environment and the same command, with vector content the sole variable: both
legs run inside the namespace against a bind-mounted manifest, and the only
difference between them is the bytes of that file.

**Why a mount namespace rather than a temporary rewrite of the tracked file.**
The guard under test is a subprocess tree (`just` -> bash -> `python3`), so the
in-process `_VECTORS_PATH` swap `validate_mutations` uses cannot reach it; the
scratch path has to travel out of band. A bind mount shadows the tracked path
for that process tree alone. The tracked manifest is never written, so there is
no restore path that can fail — which matters, because a `finally:` does not run
when a process is killed, and that is exactly how a mutated expectation
(`execution.exit: 8` on `compiler/phase11_scalar_literal_source.gst`) came to be
left in this manifest once. A wrong frozen expectation is invisible: it is not
malformed, every guard reading it compares against a plausible wrong number, and
the oracle certifies it. So the tree is checked before and after every leg too —
belt and braces, because the mechanism is what is being trusted.

**The namespace maps the caller to uid 0**, which is what permits the mount. A
guard that behaved differently under that mapping would be a confound — but the
passing leg is exactly the control for it: if the guard passes inside the
namespace against the pristine manifest, the mapping is benign for that guard.
The mechanism validates itself on every entry.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VECTORS = ROOT / "compiler/fixtures/phase24_frozen_oracle_vectors_v1.json"
GUARD = "Patch 24.12 end-to-end mutation evidence"


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD}: {message}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


# ---------------------------------------------------------------------------
# The sample, and the criterion that chose it.
#
# Sampling is by RISK, not by convenience. Three easy exec vectors would pass
# and tell you nothing.
#
# `ci` marks the one entry that runs as a guard in CI. The others are captured
# locally and frozen as evidence: they attest to a past state and are NOT
# protected against a future weakening of the harnesses they exercise. Six more
# patches (24.12b, 24.13, 24.14, 24.15, 24.15a, 24.16) will edit these
# harnesses. Saying which entries keep running and which do not is the honest
# scope statement.
# ---------------------------------------------------------------------------

SAMPLE = (
    {
        "guard": "guard-cranelift-phase11-generic-canonical-mir-route",
        "vector": "compiler/phase14_struct_composition_source.gst",
        "mutate": "stdout",
        "expect": "runtime stdout bytes differ",
        "ci": True,
        "why": (
            "Executes scripts/phase13_registry_differential.sh -- the harness "
            "rewritten in-patch. `cmp -s mir-to-c.stdout native.stdout` "
            "(:173) IS the re-pointed assertion: it replaced "
            "`cmp -s default.c explicit.c`. So the mutation is to stdout, not "
            "to exit. Mutating exit would trip the separate status comparison "
            "at :162, which the conversion did not touch -- a green probe "
            "against a different assertion. The vector is deliberately NOT "
            "archived-corpus linked, so check_corpus_identity cannot catch the "
            "mutation first and let this pass for the wrong reason."
        ),
    },
)

def tree_clean(label: str) -> None:
    dirty = subprocess.run(
        ["git", "status", "--porcelain", "--", "compiler/fixtures/"],
        cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()
    require(not dirty,
            f"compiler/fixtures/ is dirty {label}; refusing to continue "
            f"rather than freeze or compare against a tampered manifest:\n"
            f"{dirty}")


def require_namespace_support() -> None:
    """Fail loudly if the mechanism is unavailable. Never skip.

    A probe that skips when it cannot run is a dead guard certifying the loop
    closed, which is the shape this whole file exists to rule out.
    """
    require(shutil.which("unshare") is not None,
            "unshare(1) is not installed; the probe cannot shadow the frozen "
            "manifest without writing it, and will not fall back to writing it")
    probe = subprocess.run(
        ["unshare", "--map-root-user", "--mount", "--", "true"],
        capture_output=True, text=True)
    require(probe.returncode == 0,
            f"unprivileged user namespaces are unavailable here "
            f"(rc={probe.returncode}): {probe.stderr.strip()}")


def run_leg(guard: str, manifest: Path) -> subprocess.CompletedProcess:
    """Run `just <guard>` with `manifest` shadowing the tracked vector file."""
    inner = (f"mount --bind {shlex.quote(str(manifest))} "
             f"{shlex.quote(str(VECTORS))} && "
             f"exec just {shlex.quote(guard)}")
    return subprocess.run(
        ["unshare", "--map-root-user", "--mount", "--", "bash", "-c", inner],
        cwd=ROOT, capture_output=True, text=True)


def mutated_manifest(entry: dict, scratch: Path) -> tuple[Path, Path, str]:
    """Write a pristine copy and a copy with one expectation moved.

    Both files are written here, so the two legs differ in content and in
    nothing else -- not in path shape, not in serialisation.

    Which field to move is the entry's choice, and it matters: a harness
    typically compares several things, and only some of them were re-pointed
    during conversion. Moving a field the conversion did not touch produces a
    guard that fails for a reason the probe was not testing.
    """
    vector_id = entry["vector"]
    payload = json.loads(VECTORS.read_text(encoding="utf-8"))
    require(vector_id in payload["vectors"],
            f"no frozen vector to mutate: {vector_id}")
    pristine = scratch / "pristine.json"
    pristine.write_text(json.dumps(payload), encoding="utf-8")

    tampered = copy.deepcopy(payload)
    vector = tampered["vectors"][vector_id]
    block = (vector["compile"] if vector["kind"] == "reject"
             else vector.get("execution") or vector["compile"])
    if entry["mutate"] == "exit":
        was = int(block["exit"])
        block["exit"] = was + 1
        mutation = f"{vector_id}: execution.exit {was} -> {was + 1}"
    elif entry["mutate"] == "stdout":
        stream = block["stdout"]
        raw = bytes.fromhex(str(stream["hex"])) + b"tampered"
        stream["hex"] = raw.hex()
        stream["size"] = len(raw)
        stream["sha256"] = hashlib.sha256(raw).hexdigest()
        mutation = (f"{vector_id}: execution.stdout "
                    f"{len(raw) - len(b'tampered')}B -> {len(raw)}B")
    else:
        fail(f"unknown mutation kind: {entry['mutate']}")
    path = scratch / "mutated.json"
    path.write_text(json.dumps(tampered), encoding="utf-8")
    return pristine, path, mutation


def probe(entry: dict) -> dict:
    guard = entry["guard"]
    with tempfile.TemporaryDirectory() as raw:
        scratch = Path(raw)
        pristine, tampered, mutation = mutated_manifest(entry, scratch)

        # Mutate leg FIRST. A candidate that does not fail is the finding, and
        # is reported as one -- never swapped for a candidate that behaves.
        tree_clean(f"before the mutate leg of {guard}")
        bad = run_leg(guard, tampered)
        tree_clean(f"after the mutate leg of {guard}")

        tree_clean(f"before the pass leg of {guard}")
        good = run_leg(guard, pristine)
        tree_clean(f"after the pass leg of {guard}")

    output = bad.stdout + bad.stderr
    result = {"guard": guard, "vector": entry["vector"], "mutation": mutation,
              "expect": entry["expect"],
              "mutate_leg_rc": bad.returncode, "pass_leg_rc": good.returncode}
    if bad.returncode == 0:
        result["verdict"] = "DOES NOT FAIL"
        result["detail"] = (
            "the guard passed against a manifest carrying a wrong frozen "
            "expectation, so it does not compare what it materializes")
    elif entry["expect"] not in output:
        # It failed -- but not at the assertion under test. A guard that dies
        # for an unrelated reason would otherwise be scored as evidence that
        # the re-pointed comparison still fires.
        result["verdict"] = "FAILED FOR THE WRONG REASON"
        result["detail"] = (
            f"expected the failure to name {entry['expect']!r}, which is the "
            f"assertion the conversion re-pointed. It did not:\n"
            + output[-2000:])
    elif good.returncode != 0:
        result["verdict"] = "CONTROL FAILED"
        result["detail"] = (
            "the guard also failed against the pristine manifest, so its "
            "failure on the mutation proves nothing -- it is red for an "
            "unrelated reason:\n" + (good.stdout + good.stderr)[-2000:])
    else:
        result["verdict"] = "FAILS THEN PASSES"
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--entry", default=None,
                        help="run one guard from the sample by name")
    args = parser.parse_args()

    require_namespace_support()
    entries = [e for e in SAMPLE
               if args.entry in (None, e["guard"])]
    require(bool(entries), f"no sample entry named {args.entry}")

    results = [probe(e) for e in entries]
    ok = all(r["verdict"] == "FAILS THEN PASSES" for r in results)
    for r in results:
        print(f"{r['verdict']:<20} {r['guard']}")
        print(f"  mutation:  {r['mutation']}")
        print(f"  mutate leg rc={r['mutate_leg_rc']} (must be non-zero)  "
              f"pass leg rc={r['pass_leg_rc']} (must be zero)")
        if "detail" in r:
            print(f"  {r['detail']}")

    # Constraint 6: state what the sample claims, so "mutation evidence: PASS"
    # cannot be read as a claim over all 253 vectors.
    total = len(json.loads(VECTORS.read_text(encoding="utf-8"))["vectors"])
    print(f"\n{GUARD}: {len(results)} of {total} frozen vectors were driven "
          f"end-to-end through a real guard. This proves the SAMPLED guards "
          f"compare what they materialize. It says nothing about the other "
          f"{total - len(results)}.")
    if not ok:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
