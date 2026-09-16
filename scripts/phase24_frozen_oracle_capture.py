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
# Patch 24.12c: the authority is now a set, and each member is checked against
# the roadmap rather than taken on trust.
#
# This was a single constant compared to a passed string, which made the bound
# real but shallow: anyone editing the constant could grant themselves the
# authority the docstring says is granted by TASK.md. Each entry now names the
# roadmap row that grants it, and `require_roadmap_authority` refuses unless
# that row actually exists in TASK.md -- so the grant and the claim cannot
# drift apart.
AUTHORITIES = {
    "patch24.12b": ("- [x] Patch 24.12b — Python Parity Guard Conversion",
                    "phase24_frozen_oracle_vectors_v2"),
    "patch24.12c": ("- [ ] Patch 24.12c — Frozen Oracle Capture for the "
                    "Uncovered Population",
                    "phase24_frozen_oracle_vectors_v3"),
    "patch24.12d": ("- [ ] Patch 24.12d — Frozen Oracle Capture for the "
                    "Default-Route Flip",
                    "phase24_frozen_oracle_vectors_v4"),
}

# Patch 24.12d's population: the sources that lose their C route to the
# runner's DEFAULT flip rather than to a consumer naming them.
#
# 24.12c derived its population from consumers that name their fixtures. These
# three are named by nobody -- they are handed to scripts/run-gust-file.sh with
# no explicit route, so they went through C by default and take the native
# route once Patch 24.13 flips that default. Measured across all 61 sources
# those 55 scripts pass to the runner: 58 compile natively and 3 appeared to
# defer, of which one was an artifact of matching a usage message rather than
# an invocation. Two are real.
POPULATION_24_12D: dict[str, tuple[str, str]] = {
    "compiler/future/p15_directory_resources_source.gst":
        ("scripts/phase15_specialized_resource_parity.sh", "exec"),
    "compiler/future/p15_selected_failure_cleanup_source.gst":
        ("scripts/phase15_failure_cleanup_parity.sh", "exec"),
}
# tests/e2e_collections_methods.gst is deliberately NOT here. It appeared in
# the first derivation because the sweep matched `run-gust-file.sh <path>.gst`
# textually, and the runner's own usage message contains
# "e.g., scripts/run-gust-file.sh tests/e2e_collections_methods.gst". No script
# passes it to the runner; it is an example in an error string. The consumer
# check below is what caught it -- the named consumer does not mention it.
AUTHORITY = "patch24.12b"
FORMAT = "phase24_frozen_oracle_vectors_v2"

# Patch 24.12c: the population this authority may capture, and nothing else.
#
# Raised in review: selecting an authority chose only the OUTPUT FORMAT. The
# manifest loop still accepted any tracked source, never checked overlap with
# v1/v2, and never checked membership in the two consumer populations the
# roadmap row promises it is derived from. A malformed manifest could mint an
# apparently authoritative vector for an unrelated or already-covered fixture,
# and because 24.13 makes recapture impossible that mistake would be permanent.
#
# So the population is declared here with the consumer that reads each entry,
# the manifest must match it exactly, and every entry is checked to be
# referenced by its named consumer. `kind` is declared too, because it is a
# property of how the consumer treats the fixture and not of the source.
# The guard-positive recipe list, which is where these four are driven on the
# branch this patch captures from. The justfile-step51 allowlist that names
# them is added BY Patch 24.13 and does not exist here yet -- a first version
# pointed at it and the consumer check caught that the file does not mention
# them. Naming the file 24.13 will later use would have been tidier and false.
STEP51 = "justfile"
POPULATION: dict[str, tuple[str, str]] = {
    "compiler/e2e_complex_bootstrap_target.gst": (STEP51, "exec"),
    "compiler/typechecker_phase20_generic_guard_prerequisites_test_entry.gst":
        (STEP51, "exec"),
    "tests/e2e_mutex_concurrency.gst": (STEP51, "exec"),
    "tests/e2e_sync_primitives.gst": (STEP51, "exec"),
}
for _fixture, _kind in (
    ("tests/stdlib_s1_branded_collections_explicit.gst", "exec"),
    ("tests/stdlib_s1_branded_collections_inferred.gst", "exec"),
    ("tests/stdlib_s1_branded_collections_incompatible_value_rejected.gst",
     "reject"),
    ("tests/stdlib_s1_branded_collections_wrong_arena_rejected.gst", "reject"),
    ("tests/test_hashmap_reference_use_after_move_rejected.gst", "reject"),
):
    POPULATION[_fixture] = ("scripts/stdlib_s1_branded_collections_parity.sh",
                            _kind)
for _fixture, _kind in (
    ("tests/stdlib_s1_clone_destination_explicit.gst", "exec"),
    ("tests/stdlib_s1_clone_destination_inferred.gst", "exec"),
    ("tests/stdlib_s1_clone_freed_destination_rejected.gst", "reject"),
    ("tests/stdlib_s1_clone_moved_destination_rejected.gst", "reject"),
    ("tests/stdlib_s1_clone_wrong_brand_rejected.gst", "reject"),
):
    POPULATION[_fixture] = ("scripts/stdlib_s1_clone_destination_parity.sh",
                            _kind)
POPULATION["tests/stdlib_s1_composition.gst"] = (
    "scripts/stdlib_s1_composition_parity.sh", "exec")
POPULATION["tests/stdlib_s1_mutex_guard.gst"] = (
    "scripts/stdlib_s1_mutex_guard_parity.sh", "exec")
POPULATION["tests/stdlib_s1_mutex_guard_fibers.gst"] = (
    "scripts/stdlib_s1_mutex_guard_fibers_parity.sh", "exec")
for _fixture, _kind in (
    ("tests/stdlib_s1_mutex_guard_scope.gst", "exec"),
    ("tests/stdlib_s1_mutex_guard_scope_copy_rejected.gst", "reject"),
    ("tests/stdlib_s1_mutex_guard_scope_double_release_rejected.gst", "reject"),
    ("tests/stdlib_s1_mutex_guard_scope_fabricated_rejected.gst", "reject"),
    ("tests/stdlib_s1_mutex_guard_scope_two_owners_rejected.gst", "reject"),
    ("tests/stdlib_s1_mutex_guard_scope_use_after_move_rejected.gst", "reject"),
    # compile_only, not exec: see NEVER_EXECUTE.
    ("tests/stdlib_s1_mutex_guard_scope_raw_double_unlock.gst",
     "compile_only"),
):
    POPULATION[_fixture] = (
        "scripts/stdlib_s1_mutex_guard_scope_parity.sh", _kind)

# Fixtures that must be compiled but never run, with the reason recorded in
# the vector itself so a consumer cannot mistake a missing `execution` block
# for an omission.
NEVER_EXECUTE = {
    "tests/stdlib_s1_mutex_guard_scope_raw_double_unlock.gst":
        "CR-16 explicit-unsafe witness: a manual unlock followed by guard "
        "cleanup gives two unlock paths, so the program's runtime behaviour "
        "is undefined. Its guard stops at `cc -fsyntax-only` and states that "
        "the runner must not execute it; a recorded exit would be a reading "
        "of undefined behaviour replayable as an expectation.",
}

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
            "provenance": "captured_live_while_green_patch24_12c",
            "side_effects": [],
            "source_fixture": relative,
            "source_sha256": digest_bytes(source.read_bytes()),
            "workdir_sensitive": False,
        }

    require(compiled.returncode == 0,
            f"{relative} is registered as executable but the retired route "
            f"rejected it (exit {compiled.returncode}): "
            f"{compiled.stdout.decode(errors='replace')[:200]}")

    if kind == "compile_only":
        # A fixture that must be compiled but must NOT be run.
        #
        # This kind was added for a module with no `main`, then removed when
        # that module turned out not to belong in the population at all --
        # and removing it was the mistake. Raised in review: the CR-16
        # raw-double-unlock witness has a `main`, so a kind derived from
        # "does the source define main" classified it `exec`, and the capture
        # duly linked it, ran it, and recorded the exit as a legitimate oracle
        # observation.
        #
        # That program performs a manual unlock followed by guard cleanup --
        # two unlock paths, undefined behaviour. Its own guard stops at
        # `cc -fsyntax-only` and says so: "run-gust-file.sh executes positive
        # fixtures and must not run this one." A recorded exit from undefined
        # behaviour, replayable as a runtime expectation, is exactly the
        # green-but-wrong artifact this corpus exists to prevent.
        #
        # So the kind is a property of how the CONSUMER treats the fixture,
        # never of the source's shape, and it is declared per fixture in
        # POPULATION below rather than inferred.
        return {
            "archived_corpus_case": None,
            "compile": {
                "exit": compiled.returncode,
                "stdout": stream(compiled.stdout,
                                 replayable=len(compiled.stdout) <= HEX_LIMIT),
                "c_served": len(compiled.stdout) <= HEX_LIMIT,
                "stderr": stream(compiled.stderr, replayable=True),
            },
            "kind": "compile_only",
            "never_executed_reason": NEVER_EXECUTE[relative],
            "provenance": "captured_live_while_green_patch24_12c",
            "side_effects": [],
            "source_fixture": relative,
            "source_sha256": digest_bytes(source.read_bytes()),
            "workdir_sensitive": False,
        }

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
            # Patch 24.12c serves the emitted C where it fits, instead of
            # recording it as provenance unconditionally. v1's convention
            # rested on "it is large, and no guard compares it directly", and
            # both halves are false for most of this population: three Stdlib
            # parity guards `cmp` the generated C byte-for-byte and a fourth
            # greps it for symbols.
            #
            # "Most", not "all", and the difference was measured rather than
            # assumed. 24 of these 25 fixtures emit 1-13 KB; one --
            # typechecker_phase20_generic_guard_prerequisites_test_entry.gst --
            # emits 1.6 MB, over the replay limit. A first version served
            # unconditionally and the capture died on it.
            #
            # So the decision is per vector and is RECORDED per vector: a
            # consumer that needs the C text can see `c_served: false` and the
            # size, rather than replaying a record that silently has no `hex`
            # and concluding the streams differ.
            "stdout": stream(compiled.stdout,
                             replayable=len(compiled.stdout) <= HEX_LIMIT),
            "c_served": len(compiled.stdout) <= HEX_LIMIT,
            "stderr": stream(compiled.stderr, replayable=True),
        },
        "execution": {
            "exit": executed.returncode,
            "stdout": stream(executed.stdout, replayable=True),
            "stderr": stream(executed.stderr, replayable=True),
        },
        "kind": "exec",
        "provenance": "captured_live_while_green_patch24_12c",
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

    require(arguments.authority in AUTHORITIES,
            "capture refused: this tool runs only under a roadmap patch that "
            f"grants it ({sorted(AUTHORITIES)}); got {arguments.authority!r}")
    roadmap_row, output_format = AUTHORITIES[arguments.authority]
    roadmap = (ROOT / "TASK.md").read_text(encoding="utf-8")
    require(roadmap_row in roadmap,
            "capture refused: TASK.md does not carry the row that grants "
            f"{arguments.authority}. The grant has to be in the roadmap, not "
            f"in this tool: {roadmap_row!r}")

    compiler = ROOT / "gust"
    require(compiler.is_file(),
            "capture needs a built ./gust: the live lane has to be green, and "
            "after Patch 24.13 it cannot be rebuilt")
    require(shutil.which("cc") is not None, "capture needs a host C compiler")

    entries = json.loads(Path(arguments.manifest).read_text(encoding="utf-8"))
    require(entries, "capture manifest is empty")

    # The roadmap row promises the manifest is derived from the two consumer
    # populations, that an already-covered source cannot be recaptured, and
    # that a source neither consumer names cannot be added. Enforced here:
    # before 24.12c those were three sentences in TASK.md and nothing checked
    # them, so a malformed manifest could mint a permanent vector for the
    # wrong fixture.
    if arguments.authority in ("patch24.12c", "patch24.12d"):
        population = (POPULATION if arguments.authority == "patch24.12c"
                      else POPULATION_24_12D)
        supplied = {entry["source"]: entry.get("kind") for entry in entries}
        declared = {source: kind for source, (_, kind) in population.items()}
        extra = sorted(set(supplied) - set(declared))
        require(not extra,
                "capture refused: the manifest names sources outside the "
                f"population this authority covers: {extra}")
        absent = sorted(set(declared) - set(supplied))
        require(not absent,
                "capture refused: the manifest is missing sources the "
                f"population declares: {absent}")
        wrong = sorted(source for source, kind in supplied.items()
                       if kind != declared[source])
        require(not wrong,
                "capture refused: a manifest kind disagrees with the "
                "population, and kind is a property of how the consumer "
                f"treats the fixture: {[(s, supplied[s], declared[s]) for s in wrong]}")

        # Every entry is read by the consumer that claims it.
        unreferenced = []
        for source, (consumer, _kind) in population.items():
            text = (ROOT / consumer).read_text(encoding="utf-8")
            if source not in text:
                unreferenced.append(f"{source} not named in {consumer}")
        require(not unreferenced,
                "capture refused: a declared fixture is not referenced by its "
                f"consumer: {unreferenced}")

        # Nothing already covered. Recapture is the one thing this corpus can
        # never take back, because 24.13 removes the route that produced it.
        covered = set()
        for existing in ("compiler/fixtures/phase24_frozen_oracle_vectors_v1.json",
                         "compiler/fixtures/phase24_frozen_oracle_vectors_v2.json",
                         "compiler/fixtures/phase24_frozen_oracle_vectors_v3.json"):
            path = ROOT / existing
            if path.is_file():
                covered |= set(json.loads(
                    path.read_text(encoding="utf-8"))["vectors"])
        overlap = sorted(set(supplied) & covered)
        require(not overlap,
                "capture refused: these sources already have a vector in v1 "
                f"or v2, and neither may be superseded: {overlap}")

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
            "authorised_by": f"TASK.md {arguments.authority}",
            "authorising_roadmap_row": roadmap_row,
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
        "format": output_format,
        "supersession_policy": {
            "immutable_version": output_format.rsplit("_", 1)[-1],
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
