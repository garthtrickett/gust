#!/usr/bin/env python3
"""Patch 24.12b: frozen expected-behaviour oracle capture, v2.

The v1 corpus was captured for the *shell* harnesses Patch 24.12 converted.
The Python parity guards Patch 24.12b converts compile different sources, and
none of them has a v1 vector, so the conversion step is not executable without
a capture. `scripts/phase24_frozen_oracle.py` refuses that operation by design
and says so in its own docstring, so this tool exists only because `TASK.md`
Patch 24.12b grants the authority explicitly (#416), and it is bounded by it.

Two things make this the last opportunity rather than merely the next one:

  * capture requires executing the retired backend while the live lane is
    green, and Patch 24.13 removes backend selection, so after 24.13 merges no
    vector can ever be captured again, for any source, by anyone; and
  * the v1 corpus records an empty stderr on all 253 vectors and both blocks
    (#417), so v2 is also the last chance to record that observable in a form
    anything can falsify.

This tool therefore refuses to produce a corpus that repeats either defect: it
records stderr faithfully, it states whether the captured population is
uniformly empty rather than leaving it implicit, and it gives every vector an
authority independent of the vector itself (#399).

It never runs unless asked by name. There is no default source set and no
refresh mode: a captured vector is written once, and a second capture that
disagrees with a committed one fails rather than overwriting it.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "phase24_frozen_oracle_capture"
AUTHORITY = "patch24.12b"
FORMAT = "phase24_frozen_oracle_vectors_v2"

# Held byte-identical with the v1 capture so the two corpora are comparable.
NORMALIZED_ENVIRONMENT = {
    "GUST_RUNNER_SKIP_BUILD": "1",
    "LANG": "C",
    "LC_ALL": "C",
    "SOURCE_DATE_EPOCH": "0",
    "TZ": "UTC",
}
CFLAGS = ["-O0", "-w", "-pthread", "-Isrc"]
RETIRED_ROUTE = ["--backend", "mir-to-c"]

# Only bytes a guard replays carry `hex`; a record without it is provenance.
# The generated C emission is provenance -- it is large, and no guard compares
# it directly -- which is the v1 convention and is kept so a v2 record can be
# read by the v1 reader without a special case.
HEX_LIMIT = 1 << 16


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD}: {message}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def digest_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def stream(value: bytes, *, replayable: bool) -> dict:
    record: dict = {"size": len(value), "sha256": digest_bytes(value)}
    if replayable:
        require(len(value) <= HEX_LIMIT,
                f"a replayable stream is {len(value)} bytes, over the "
                f"{HEX_LIMIT} limit; it would bloat the corpus rather than "
                f"serve it")
        record["hex"] = value.hex()
    return record


def run(command: list[str], *, cwd: Path, timeout: int = 300):
    environment = dict(os.environ)
    environment.update(NORMALIZED_ENVIRONMENT)
    return subprocess.run(command, cwd=cwd, env=environment,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          timeout=timeout, check=False)


def capture_one(compiler: Path, source: Path, kind: str) -> dict:
    """Capture one vector by running the retired route, then the artifact."""
    require(source.is_file(), f"source fixture is not a tracked file: {source}")
    relative = source.relative_to(ROOT).as_posix()

    # The source is passed *relative* to ROOT, not absolutely. A diagnostic
    # quotes the path it was given, so an absolute one would bake the capturing
    # worktree into a committed fixture and never match on replay elsewhere.
    # v1 carries zero absolute paths across its reject vectors; this keeps that
    # property rather than rediscovering it.
    compiled = run([str(compiler), *RETIRED_ROUTE, relative], cwd=ROOT)

    if kind == "reject":
        # A rejection's stdout *is* the diagnostic the guard compares, so it is
        # replayed. There is nothing to execute.
        require(compiled.returncode != 0,
                f"{relative} is registered as a rejection but compiled "
                f"cleanly (exit {compiled.returncode})")
        return {
            "archived_corpus_case": None,
            "compile": {
                "exit": compiled.returncode,
                "stdout": stream(compiled.stdout, replayable=True),
                "stderr": stream(compiled.stderr, replayable=True),
            },
            "kind": "reject",
            "provenance": "captured_live_while_green_patch24_12b",
            "side_effects": [],
            "source_fixture": relative,
            "source_sha256": digest_bytes(source.read_bytes()),
            "workdir_sensitive": False,
        }

    require(compiled.returncode == 0,
            f"{relative} is registered as executable but the retired route "
            f"rejected it (exit {compiled.returncode}): "
            f"{compiled.stdout.decode(errors='replace')[:200]}")

    with tempfile.TemporaryDirectory() as raw:
        work = Path(raw)
        merged = work / "program.c"
        merged.write_bytes((ROOT / "src/runtime.c").read_bytes()
                           + compiled.stdout)
        artifact = work / "program"
        linked = run(["cc", *CFLAGS, str(merged), "-o", str(artifact)],
                     cwd=ROOT)
        require(linked.returncode == 0,
                f"host C compilation failed for {relative}: "
                f"{linked.stderr.decode(errors='replace')[:400]}")
        executed = run([str(artifact)], cwd=ROOT, timeout=60)

    return {
        "archived_corpus_case": None,
        "compile": {
            "exit": compiled.returncode,
            # Provenance: the emitted C, recorded but never served.
            "stdout": stream(compiled.stdout, replayable=False),
            "stderr": stream(compiled.stderr, replayable=True),
        },
        "execution": {
            "exit": executed.returncode,
            "stdout": stream(executed.stdout, replayable=True),
            "stderr": stream(executed.stderr, replayable=True),
        },
        "kind": "exec",
        "provenance": "captured_live_while_green_patch24_12b",
        "side_effects": [],
        "source_fixture": relative,
        "source_sha256": digest_bytes(source.read_bytes()),
        "workdir_sensitive": False,
    }


def vector_authority(vector: dict) -> str:
    """#399: an authority over the observation block, independent of it.

    v1 cross-checked only the 34 vectors carrying an archived-corpus case, so
    for the other 219 a self-consistent edit was indistinguishable from a
    correct capture. Every v2 vector carries this instead, computed at capture
    time over the observation blocks alone.
    """
    observation = {key: vector[key] for key in ("compile", "execution", "kind",
                                                "source_sha256")
                   if key in vector}
    return digest_bytes(json.dumps(observation, sort_keys=True,
                                   separators=(",", ":")).encode())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--authority", required=True,
                        help="must be the roadmap patch granting the capture")
    parser.add_argument("--manifest", required=True,
                        help="JSON list of {source, kind} to capture")
    parser.add_argument("--out", required=True)
    arguments = parser.parse_args()

    require(arguments.authority == AUTHORITY,
            f"capture refused: this tool runs only under {AUTHORITY}, the "
            f"roadmap patch that grants it; got {arguments.authority!r}")

    compiler = ROOT / "gust"
    require(compiler.is_file(),
            "capture needs a built ./gust: the live lane has to be green, and "
            "after Patch 24.13 it cannot be rebuilt")
    require(shutil.which("cc") is not None, "capture needs a host C compiler")

    entries = json.loads(Path(arguments.manifest).read_text(encoding="utf-8"))
    require(entries, "capture manifest is empty")

    vectors: dict[str, dict] = {}
    for entry in entries:
        source = ROOT / entry["source"]
        vector = capture_one(compiler, source, entry["kind"])
        identifier = vector["source_fixture"]
        require(identifier not in vectors,
                f"manifest names {identifier} twice")
        vector["capture_authority_digest"] = vector_authority(vector)
        vectors[identifier] = vector

    # #417: say whether stderr carries anything, rather than leaving a corpus
    # whose every stderr is empty to read as coverage.
    def empty(record: dict) -> bool:
        return int(record["size"]) == 0

    def stderr_population(table: dict) -> tuple[int, int]:
        """Records and non-empty count over WHATEVER vectors are passed.

        Extracted so the header can be derived from the merged table rather
        than from the current run. Computing it once, before the merge, is how
        the committed v2 file came to declare 2 records while holding 29.
        """
        records = [block["stderr"]
                   for vector in table.values()
                   for key in ("compile", "execution")
                   if (block := vector.get(key))]
        return len(records), sum(1 for record in records if not empty(record))

    record_count, non_empty = stderr_population(vectors)

    revision = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT,
                              capture_output=True, text=True, check=False)
    compiler_version = run(["cc", "--version"], cwd=ROOT)

    document = {
        "capture_authority": {
            "authorised_by": "TASK.md Patch 24.12b (#416)",
            "capture_tool_sha256": digest_bytes(Path(__file__).read_bytes()),
            "cc": compiler_version.stdout.decode(errors="replace"
                                                 ).splitlines()[0],
            "cflags": " ".join(CFLAGS),
            "gust_sha256": digest_bytes(compiler.read_bytes()),
            "normalized_environment": dict(NORMALIZED_ENVIRONMENT),
            "oracle_route": "explicit_retired_backend_spelling",
            "sealed_by": "Patch 24.13 removes backend selection; no vector "
                         "can be captured after it merges",
            "source_commit": revision.stdout.strip(),
            "stderr_population": {
                "records": record_count,
                "non_empty": non_empty,
                "note": "v1 recorded 0 non-empty across 421 records (#417); "
                        "this count is stated so a uniformly empty corpus is "
                        "visible rather than implicit",
            },
        },
        "format": FORMAT,
        "supersession_policy": {
            "immutable_version": "v2",
            "live_c": "never_executed_by_replay",
            "mismatch": "fail_never_refresh_silently",
            "refresh": "impossible_after_patch24_13_seals_the_backend",
        },
        "vectors": vectors,
    }

    out = Path(arguments.out)
    if out.exists():
        # A capture that silently overwrites a committed vector is a refresh
        # wearing a capture's name.
        previous = json.loads(out.read_text(encoding="utf-8"))["vectors"]
        for identifier, vector in previous.items():
            if identifier in vectors:
                require(vectors[identifier] == vector,
                        f"recapture disagrees with the committed vector for "
                        f"{identifier}; refusing to overwrite it")
        vectors.update(previous)
        document["vectors"] = dict(sorted(vectors.items()))
        # Recompute the header over the MERGED table. Without this the
        # document describes only the vectors this invocation happened to
        # capture, while carrying every vector captured before it -- which is
        # how the committed file came to say records=2 over 29 vectors.
        record_count, non_empty = stderr_population(document["vectors"])
        document["capture_authority"]["stderr_population"]["records"] = record_count
        document["capture_authority"]["stderr_population"]["non_empty"] = non_empty

    out.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n",
                   encoding="utf-8")
    print(f"{GUARD}: captured {len(document['vectors'])} vectors "
          f"({non_empty}/{record_count} stderr records non-empty)")


if __name__ == "__main__":
    main()
