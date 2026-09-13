#!/usr/bin/env python3
"""Patch 24.12: frozen expected-behaviour oracle replacement.

The retired backend was the semantic oracle for every parity guard. This
module is what replaces that role, so that the oracle can go without taking
live parity evidence with it.

A vector records what the MIR-to-C route observably did for one source
fixture, captured while the live lane was green and reproducing the
immutable Patch 23.11 archived reference corpus byte for byte. `materialize`
serves those observables to a converted parity guard; the guard's native arm
still runs live and is still compared byte for byte. What changed is which
side of the comparison is executed, not what the comparison means.

Nothing here executes C. There is no capture command, no live fallback, and
no environment-selected route back to the emitter: an unknown vector, a
moved source fixture, or a vector that disagrees with the archived corpus
fails closed. Refreshing the frozen set needs a new version and explicit
roadmap authority, exactly as the 23.11 corpus does.

Vectors: compiler/fixtures/phase24_frozen_oracle_vectors_v1.json
Archived corpus: compiler/fixtures/phase23_mir_to_c_reference_corpus_v1.json
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
TASK = ROOT / "TASK.md"
VECTORS = ROOT / "compiler/fixtures/phase24_frozen_oracle_vectors_v1.json"
CORPUS = ROOT / "compiler/fixtures/phase23_mir_to_c_reference_corpus_v1.json"
VIEW = ROOT / "docs/PHASE24_FROZEN_ORACLE_REPLACEMENT.md"
JUSTFILE = ROOT / "justfile"
WORKFLOW = ROOT / ".github/workflows/phase24-frozen-oracle.yml"

GUARD_L1 = "guard-cranelift-phase24-frozen-oracle-contract"
GUARD_L2 = "guard-cranelift-phase24-frozen-oracle-evidence"
VERSION = "phase24_frozen_oracle_replacement_v1"
STATUS = "patch24_12_complete"
VECTOR_FORMAT = "gust.phase24.frozen_oracle_vectors.v1"

# Execution loci that carried a parity guard's live-C arm before this patch
# and must carry none after it. This is the Patch 24.12 exit gate expressed
# as a check: "zero parity guards execute live C". The list is the 24.11
# inventory's 24.12-owned harness set; a converted guard that grows a C arm
# back, and a new parity guard that reaches for one, both fail here.
FROZEN_LOCI = (
    "scripts/phase12_5_route_architecture.sh",
    "scripts/phase13_broader_imported_runtime_calls.sh",
    "scripts/phase13_capability_deferral.sh",
    "scripts/phase13_direct_call_graph.sh",
    "scripts/phase13_general_loop.sh",
    "scripts/phase13_multiple_locals_assignments.sh",
    "scripts/phase13_nested_structured_cfg.sh",
    "scripts/phase13_parameter_argument.sh",
    "scripts/phase13_registry_differential.sh",
    "scripts/phase13_scalar_expression.sh",
    "scripts/phase13_source_metadata.sh",
    "scripts/phase14_composition_differential.sh",
    "scripts/phase15_resource_composition_parity.sh",
    "scripts/phase16_abi_composition_parity.sh",
    "scripts/phase19_classification_parity.sh",
    "scripts/phase19_composition_parity.sh",
    "scripts/phase19_gust_name_list_removed_parity.sh",
    "scripts/phase19_rename_invariance.sh",
    "scripts/phase19_representation_parity.sh",
    "scripts/phase19_rule_convergence_parity.sh",
    "scripts/phase19_type_naming_parity.sh",
    "scripts/phase20_arena_free.sh",
    "scripts/phase20_contextual_generic_constructor.sh",
    "scripts/phase20_cross_feature_qualification.sh",
    "scripts/phase20_exact_brand_boundary.sh",
    "scripts/phase20_generic_guard_prerequisites.sh",
    "scripts/phase20_inert_resource_surface.sh",
    "scripts/phase20_long_lived_concurrent.sh",
    "scripts/phase20_nested_brand_annotation.sh",
    "scripts/phase20_protected_access_liveness.sh",
    "scripts/phase20_resource_acquisition.sh",
    "scripts/phase20_resource_declaration_migration.sh",
    "scripts/phase20_resource_enforcement.sh",
    "scripts/phase20_resource_scope_cleanup.sh",
    "scripts/phase20_stdlib_runtime_differential.sh",
    "scripts/phase20_whole_program_corpus.sh",
    "scripts/phase21_collection_string_native_source.sh",
    "scripts/phase21_cross_tenant_capability.sh",
    "scripts/phase21_filesystem_allocation_native_source.sh",
    "scripts/phase21_inert_scoped_query_records.sh",
    "scripts/phase21_od8_adversarial_verdict.sh",
    "scripts/phase21_opening.sh",
    "scripts/phase21_per_root_obligations.sh",
    "scripts/phase21_resource_sync_native_source.sh",
    "scripts/phase21_trusted_scope_provenance.sh",
    "scripts/phase21_typed_query_noop_surface.sh",
)

# Parity recipes whose bodies must likewise carry no C arm after conversion.
FROZEN_RECIPES = (
    "guard-cranelift-phase11-scalar-expression-parity",
    "guard-cranelift-phase11-local-state-parity",
    "guard-cranelift-phase11-structured-cfg-parity",
    "guard-cranelift-phase11-block-parameter-loop-parity",
    "guard-cranelift-phase11-direct-call-abi-parity",
    "guard-cranelift-phase11-module-import-runtime-parity",
    "guard-cranelift-phase11-metadata-diagnostic-parity",
    "guard-mir-feature-return-int-preservation",
    "guard-mir-feature-local-binding-read-preservation",
    "guard-mir-feature-if-else-return-int-preservation",
    "guard-mir-feature-local-binding-read-provenance-metadata-preservation",
)

# ---------------------------------------------------------------------------
# Pre-existing reds this patch deliberately does NOT repair.
#
# Both fail on their native/static side before any C comparison, so neither
# is a live-lane disagreement and neither is frozen from a failing run. They
# are recorded here, rather than left in a chat log, so the Phase 24.16
# residue audit cannot miss them: an orphaned guard reported as live is
# exactly what that audit exists to catch.
# ---------------------------------------------------------------------------

NOT_REPAIRED = (
    {
        "guard": "guard-cranelift-phase11-structured-cfg-parity",
        "state": "red_on_its_dynamic_path",
        "cause": "reads registry[\"phase13\"][\"entries\"]; no top-level "
                 "phase13 key exists at HEAD, HEAD~50 or HEAD~200",
        "why_ci_is_green": "its sole caller "
                           "guard-cranelift-phase13-nested-structured-cfg-parity "
                           "sets PHASE11_STRUCTURED_CFG_SKIP_DYNAMIC=1, so the "
                           "branch is never reached; PR Fast on main "
                           "8aa9922e is success (push run 34695365766)",
        "reproduce": "just guard-cranelift-phase11-structured-cfg-parity",
        "frozen_from_a_red_run": False,
        "frozen_how": "its four positive cases run before the break and were "
                      "observed green; the fifth case fixture "
                      "compiler/phase11_structured_cfg_deferred_loop_source.gst "
                      "is derived from the immutable 23.11 corpus case "
                      "p13_general_loop_backedge_source_route",
        "scope": "not_repaired_out_of_retirement_scope",
        "owner": "24.16",
    },
    {
        "guard": "guard-cranelift-phase11-metadata-diagnostic-parity",
        "state": "red_and_orphaned",
        "cause": "dies at the bare rg -F 'metadata_0_policy: "
                 "recognized_preserved' capture.bundle under set -e in the "
                 "native_boundary case; nothing in the justfile invokes the "
                 "guard (justfile:12780 is its recipe head, justfile:18608 is "
                 "an rg -e pattern forbidding the call)",
        "why_ci_is_green": "no recipe, workflow or make target executes it; "
                           "PR Fast on main 8aa9922e is success (push run "
                           "34695365766) and never reaches it",
        "reproduce": "just guard-cranelift-phase11-metadata-diagnostic-parity",
        "frozen_from_a_red_run": False,
        "frozen_how": "only its C arm converts (a rejection of the "
                      "type-error fixture, captured from the compiler); the "
                      "native red stays visible exactly as today",
        "scope": "not_repaired_out_of_retirement_scope",
        "owner": "24.16",
        "tracked_by": "https://github.com/garthtrickett/gust/issues/390",
    },
    {
        "guard": "guard-cranelift-phase20-resource-enforcement-parity",
        "state": "red_and_orphaned",
        "cause": "asserts exactly one 'Semantic Error:' line in the compiler "
                 "diagnostics for phase20_resource_destructor_arity_invalid, "
                 "and the compiler emits three (test 3 = 1)",
        "why_ci_is_green": "not workflow-reachable and no recipe calls it; "
                           "PR Fast on main 8aa9922e is success (push run "
                           "34695365766) and never reaches it",
        "reproduce": "bash scripts/phase20_resource_enforcement.sh",
        "frozen_from_a_red_run": False,
        "frozen_how": "the frozen reject log matches the live compiler byte "
                      "for byte; the guard fails at a later count assertion "
                      "that failed identically before conversion, verified by "
                      "running the pre-conversion script from bf3875bc",
        "scope": "not_repaired_out_of_retirement_scope",
        "owner": "24.16",
    },
)

# Parity harnesses that no longer select the C backend themselves but still
# reach it through the shared runner's DEFAULT route
# (`scripts/run-gust-file.sh`, `GUST_RUNNER_ROUTE="${GUST_RUNNER_ROUTE:-mir-to-c}"`).
# That row is Patch 24.13's to migrate, so this patch names the residue
# exactly rather than claiming more than it delivers: after 24.12 no parity
# guard *selects* live C, and these two still *reach* it until 24.13 flips
# the runner default. Registered so the count cannot grow unnoticed.
RUNNER_MEDIATED_RESIDUE = {
    "scripts/phase15_resource_composition_parity.sh": 3,
    "scripts/phase16_abi_composition_parity.sh": 2,
}
RUNNER_RESIDUE_OWNER = "24.13"
RUNNER_CALL = re.compile(r"bash scripts/run-gust-file\.sh")

BACKEND_SPELLING = re.compile(r"--backend (?:mir-to-c|c(?=[\s\"']|$))")
RECIPE_HEAD = re.compile(r"^([A-Za-z0-9_-]+)([^:]*):")


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD_L1}: {message}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def digest_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def canonical_digest(value: object) -> str:
    return digest_bytes(json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=True,
    ).encode("utf-8"))


def load_vectors() -> dict:
    require(VECTORS.is_file(), "frozen vector file is missing")
    return json.loads(VECTORS.read_text(encoding="utf-8"))


def load_corpus() -> dict:
    require(CORPUS.is_file(), "archived 23.11 reference corpus is missing")
    return json.loads(CORPUS.read_text(encoding="utf-8"))


def record_bytes(record: dict) -> bytes:
    """Recover the frozen bytes of a record, verifying its own digest.

    Records carry `hex` only where the bytes are replayed. A record without
    `hex` is provenance (the generated C emission), never served.
    """
    require("hex" in record, "frozen record holds no replayable bytes")
    value = bytes.fromhex(str(record["hex"]))
    require(len(value) == record["size"] and
            digest_bytes(value) == record["sha256"],
            "frozen record is internally inconsistent")
    return value


def check_vector(vector_id: str, vectors: dict) -> dict:
    """Resolve one vector, failing closed rather than falling back."""
    table = vectors.get("vectors", {})
    require(vector_id in table,
            f"no frozen vector for '{vector_id}' — failing closed, "
            f"there is no live-C fallback")
    vector = table[vector_id]
    for field in ("source_fixture", "source_sha256", "kind", "provenance",
                  "compile", "side_effects", "workdir_sensitive"):
        require(field in vector, f"frozen vector is malformed: {vector_id}")
    require(vector["kind"] in ("exec", "reject"),
            f"frozen vector has an unknown kind: {vector_id}")
    source = ROOT / str(vector["source_fixture"])
    require(source.is_file(),
            f"frozen vector source is missing: {vector_id}")
    require(digest_bytes(source.read_bytes()) == vector["source_sha256"],
            f"frozen vector source moved without a re-freeze: {vector_id}")
    if vector["kind"] == "exec":
        require("execution" in vector,
                f"exec vector has no frozen execution: {vector_id}")
    require(vector["provenance"] in (
        "derived_from_archived_corpus_v1", "captured_live_while_green"),
        f"frozen vector has an unknown provenance: {vector_id}")
    require(not (vector["provenance"] == "derived_from_archived_corpus_v1"
                 and vector.get("archived_corpus_case") is None),
            f"a corpus-derived vector names no archived case: {vector_id}")
    return vector


def materialize(vector_id: str, prefix: Path, expect_kind: str | None,
                workdir: Path | None = None) -> None:
    """Write one frozen vector's observables where a guard expects them.

    `workdir` reconstructs the frozen side-effect tree for the harnesses
    that compare what each arm left on disk (`diff -ru mir-workdir
    native-workdir`). Effects are part of the frozen behaviour, not a
    by-product of it: a case that used to write a file must still be
    recorded as writing it.
    """
    vectors = load_vectors()
    vector = check_vector(vector_id, vectors)
    if expect_kind is not None:
        require(vector["kind"] == expect_kind,
                f"frozen vector kind changed for {vector_id}: "
                f"frozen={vector['kind']} expected={expect_kind}")
    prefix.parent.mkdir(parents=True, exist_ok=True)
    if workdir is not None:
        workdir.mkdir(parents=True, exist_ok=True)
        for effect in vector.get("side_effects", []):
            target = workdir / str(effect["path"])
            require(".." not in Path(str(effect["path"])).parts,
                    f"frozen side effect escapes its workdir: {vector_id}")
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(record_bytes(effect))
    compile_record = vector["compile"]
    Path(f"{prefix}.compile.status").write_text(
        f"{compile_record['exit']}\n", encoding="utf-8")
    Path(f"{prefix}.compile.stderr").write_bytes(
        record_bytes(compile_record["stderr"]))
    if vector["kind"] == "reject":
        stdout = record_bytes(compile_record["stdout"])
        stderr = record_bytes(compile_record["stderr"])
        Path(f"{prefix}.compile.stdout").write_bytes(stdout)
        # The rejecting guards capture the compiler with `>log 2>&1`.
        Path(f"{prefix}.log").write_bytes(stdout + stderr)
        Path(f"{prefix}.status").write_text(
            f"{compile_record['exit']}\n", encoding="utf-8")
        return
    # A working-directory sensitive fixture was frozen under both
    # conventions; serve the one this call site actually uses. Asking for a
    # workdir is the call site saying "I run the arm from a sandbox".
    if workdir is not None and vector.get("workdir_sensitive"):
        require("execution_workdir" in vector,
                f"workdir-sensitive vector has no frozen sandbox run: "
                f"{vector_id}")
        execution = vector["execution_workdir"]
    else:
        execution = vector["execution"]
    Path(f"{prefix}.status").write_text(
        f"{execution['exit']}\n", encoding="utf-8")
    Path(f"{prefix}.stdout").write_bytes(record_bytes(execution["stdout"]))
    Path(f"{prefix}.stderr").write_bytes(record_bytes(execution["stderr"]))


# ---------------------------------------------------------------------------
# Archived-corpus identity.
#
# A vector whose fixture is one of the 34 immutable Patch 23.11 corpus cases
# is not an independent capture: it must agree with the corpus byte for byte.
# That is what ties the replacement to the roadmap's named parity authority
# rather than to a fresh recording nobody can check.
# ---------------------------------------------------------------------------

def corpus_index(corpus: dict) -> dict[str, dict]:
    index: dict[str, dict] = {}
    for case in corpus["cases"]:
        index[str(case["source_fixture"])] = case
    require(len(index) == len(corpus["cases"]),
            "archived corpus has duplicate source fixtures")
    return index


def check_corpus_identity(vectors: dict, corpus: dict) -> int:
    index = corpus_index(corpus)
    linked = 0
    for vector_id, vector in sorted(vectors["vectors"].items()):
        case_id = vector.get("archived_corpus_case")
        source = str(vector["source_fixture"])
        if case_id is None:
            require(source not in index,
                    f"vector covers an archived corpus fixture without "
                    f"claiming its case: {vector_id}")
            continue
        require(source in index,
                f"vector claims an archived case for an unarchived "
                f"fixture: {vector_id}")
        case = index[source]
        require(str(case["id"]) == case_id,
                f"vector names the wrong archived case: {vector_id}")
        require(vector["source_sha256"] == case["source_sha256"],
                f"vector source disagrees with the archived corpus: "
                f"{vector_id}")
        require(vector["compile"]["exit"] == case["compile"]["exit"],
                f"vector compile exit disagrees with the archived corpus: "
                f"{vector_id}")
        require(vector["compile"]["stdout"]["sha256"] ==
                case["compile"]["generated_c"]["sha256"],
                f"vector emission disagrees with the archived corpus: "
                f"{vector_id}")
        require(vector["kind"] == "exec",
                f"archived corpus case is not frozen as exec: {vector_id}")
        for stream in ("stdout", "stderr"):
            require(vector["execution"][stream]["sha256"] ==
                    case["execution"][stream]["sha256"],
                    f"vector {stream} disagrees with the archived corpus: "
                    f"{vector_id}")
        require(vector["execution"]["exit"] == case["execution"]["exit"],
                f"vector exit disagrees with the archived corpus: "
                f"{vector_id}")
        require([{"path": e["path"], "size": e["size"],
                  "sha256": e["sha256"]}
                 for e in vector["side_effects"]] == case["side_effects"],
                f"vector side effects disagree with the archived corpus: "
                f"{vector_id}")
        linked += 1
    return linked


# ---------------------------------------------------------------------------
# Exit gate: zero parity guards execute live C.
# ---------------------------------------------------------------------------

def recipe_bodies() -> dict[str, str]:
    bodies: dict[str, str] = {}
    current: str | None = None
    for line in JUSTFILE.read_text(encoding="utf-8").split("\n"):
        if line[:1] in (" ", "\t"):
            if current is not None:
                bodies[current] += line + "\n"
            continue
        match = RECIPE_HEAD.match(line)
        if match:
            current = match.group(1)
            bodies.setdefault(current, "")
    return bodies


def check_no_live_c() -> None:
    for locus in FROZEN_LOCI:
        path = ROOT / locus
        require(path.is_file(), f"frozen parity harness is missing: {locus}")
        hits = BACKEND_SPELLING.findall(path.read_text(encoding="utf-8"))
        require(not hits,
                f"a converted parity harness executes live C again: "
                f"{locus} ({len(hits)} spellings)")
    # The runner-mediated residue is bounded and owned by 24.13; it must not
    # grow, and a harness must not quietly acquire a new default-route call.
    for locus, expected in RUNNER_MEDIATED_RESIDUE.items():
        text = (ROOT / locus).read_text(encoding="utf-8")
        found = sum(1 for line in text.split("\n")
                    if RUNNER_CALL.search(line)
                    and "GUST_RUNNER_ROUTE=cranelift" not in line)
        require(found == expected,
                f"runner-mediated C residue moved without updating the "
                f"{RUNNER_RESIDUE_OWNER} hand-off: {locus} "
                f"({found} default-route calls, registered {expected})")
    for locus in FROZEN_LOCI:
        if locus in RUNNER_MEDIATED_RESIDUE:
            continue
        text = (ROOT / locus).read_text(encoding="utf-8")
        require(not any(RUNNER_CALL.search(line)
                        and "GUST_RUNNER_ROUTE=cranelift" not in line
                        for line in text.split("\n")),
                f"a converted parity harness acquired an unregistered "
                f"default-route runner call: {locus}")

    bodies = recipe_bodies()
    for recipe in FROZEN_RECIPES:
        require(recipe in bodies,
                f"frozen parity recipe is missing: {recipe}")
        hits = BACKEND_SPELLING.findall(bodies[recipe])
        require(not hits,
                f"a converted parity recipe executes live C again: "
                f"{recipe} ({len(hits)} spellings)")


# ---------------------------------------------------------------------------
# Mutation evidence. A frozen test that cannot fail is a deleted test, so
# every vector is required to drive the artifacts a guard compares: tamper
# with the vector and the materialized bytes must move with it.
# ---------------------------------------------------------------------------

def _materialize_from(vector_id: str, table: dict, prefix: Path,
                      kind: str | None = None) -> None:
    saved = VECTORS.read_text(encoding="utf-8")
    payload = json.loads(saved)
    payload["vectors"] = table
    VECTORS.write_text(json.dumps(payload), encoding="utf-8")
    try:
        materialize(vector_id, prefix, kind)
    finally:
        VECTORS.write_text(saved, encoding="utf-8")


def validate_mutations(vectors: dict) -> int:
    """Prove every frozen vector still drives what the guards compare.

    The live lane caught a wrong exit status, wrong stdout, and wrong
    stderr. Each mutation below is one of those, applied to a throwaway
    copy of the vector table; the committed file is restored either way.
    """
    table = vectors["vectors"]
    checked = 0
    with tempfile.TemporaryDirectory() as raw:
        root = Path(raw)
        for vector_id, vector in sorted(table.items()):
            prefix = root / "good"
            _materialize_from(vector_id, table, prefix)
            kind = vector["kind"]
            observed = "status" if kind == "reject" else "status"
            good_status = Path(f"{prefix}.{observed}").read_bytes()
            good_out = Path(
                f"{prefix}.log" if kind == "reject" else f"{prefix}.stdout"
            ).read_bytes()

            mutated = copy.deepcopy(table)
            slot = mutated[vector_id]
            block = slot["compile"] if kind == "reject" else slot["execution"]
            block["exit"] = int(block["exit"]) + 1
            _materialize_from(vector_id, mutated, root / "exit")
            require(Path(f"{root / 'exit'}.status").read_bytes() != good_status,
                    f"exit-status mutation is invisible: {vector_id}")

            mutated = copy.deepcopy(table)
            slot = mutated[vector_id]
            stream = slot["compile"]["stdout"] if kind == "reject" \
                else slot["execution"]["stdout"]
            tampered = bytes.fromhex(str(stream["hex"])) + b"tampered"
            stream["hex"] = tampered.hex()
            stream["size"] = len(tampered)
            stream["sha256"] = digest_bytes(tampered)
            _materialize_from(vector_id, mutated, root / "out")
            require(Path(
                f"{root / 'out'}.log" if kind == "reject"
                else f"{root / 'out'}.stdout").read_bytes() != good_out,
                f"stdout mutation is invisible: {vector_id}")

            mutated = copy.deepcopy(table)
            mutated[vector_id]["source_sha256"] = "0" * 64
            try:
                _materialize_from(vector_id, mutated, root / "moved")
                fail(f"a moved source fixture was replayed anyway: {vector_id}")
            except SystemExit as error:
                require("moved without a re-freeze" in str(error),
                        f"a moved source failed for the wrong reason: "
                        f"{vector_id}")

            mutated = copy.deepcopy(table)
            mutated[vector_id]["kind"] = (
                "reject" if kind == "exec" else "exec")
            try:
                _materialize_from(vector_id, mutated, root / "kind", kind)
                fail(f"a changed vector kind was replayed anyway: {vector_id}")
            except SystemExit as error:
                # Either check may catch it first and both are correct
                # rejections: flipping exec->reject trips the kind the call
                # site asserted, while reject->exec trips the missing frozen
                # execution. What matters is that neither replays.
                require(vector_id in str(error),
                        f"a changed kind failed without naming the vector: "
                        f"{vector_id}")
            checked += 1

        try:
            materialize("no-such-frozen-vector", root / "unknown", None)
            fail("an unknown vector id was replayed anyway")
        except SystemExit as error:
            require("failing closed" in str(error),
                    "an unknown vector failed for the wrong reason")
    return checked


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    node = registry.get("phase24_frozen_oracle_replacement")
    require(isinstance(node, dict), "frozen oracle registry node is missing")
    require(node.get("version") == VERSION and
            node.get("status") == STATUS and
            node.get("authority_owner") ==
            "scripts/cranelift_feature_registry.json",
            "frozen oracle identity drifted")

    vectors = load_vectors()
    require(vectors.get("format") == VECTOR_FORMAT,
            "frozen vector format drifted")
    policy = vectors.get("supersession_policy", {})
    require(policy.get("refresh") ==
            "new_version_and_explicit_roadmap_authority_only" and
            policy.get("mismatch") == "fail_never_refresh_silently" and
            policy.get("live_c") == "never_executed_by_replay",
            "frozen vector supersession policy drifted")

    table = vectors.get("vectors", {})
    require(table, "frozen vector manifest is empty")
    ids = sorted(table)
    for vector_id in ids:
        check_vector(vector_id, vectors)

    corpus = load_corpus()
    require(digest_bytes(CORPUS.read_bytes()) ==
            vectors["capture_authority"]["archived_corpus_sha256"],
            "the archived corpus moved under the frozen vectors")
    linked = check_corpus_identity(vectors, corpus)
    require(linked == node.get("archived_corpus_linked_vectors"),
            "registered archived-corpus linkage drifted")

    require(node.get("vector_ids") == ids,
            "registered frozen manifest drifted from the vector file")
    require(node.get("vector_count") == len(ids) and
            node.get("vectors_digest") == canonical_digest(table),
            "registered frozen counts drifted")

    check_no_live_c()
    require(node.get("frozen_loci") == list(FROZEN_LOCI) and
            node.get("frozen_recipes") == list(FROZEN_RECIPES),
            "registered frozen locus set drifted")
    require(node.get("runner_mediated_residue") ==
            dict(RUNNER_MEDIATED_RESIDUE) and
            node.get("runner_residue_owner") == RUNNER_RESIDUE_OWNER,
            "the registered runner-mediated residue drifted")
    require(node.get("not_repaired") == [dict(row) for row in NOT_REPAIRED],
            "the not-repaired pre-existing reds drifted")
    for row in NOT_REPAIRED:
        require(row["frozen_from_a_red_run"] is False,
                f"a guard's expectation was frozen from a red run: "
                f"{row['guard']}")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 24.12 — Frozen Expected-Behaviour Oracle "
            "Replacement — DONE" in task,
            "TASK status does not mark Patch 24.12 DONE")

    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1, "L1 test-level assignment drifted")
    require(levels.get(GUARD_L2) == 2, "L2 test-level assignment drifted")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in just and f"{GUARD_L2}:" in just,
            "just guard reachability drifted")
    return node


def render(node: dict) -> str:
    lines = [
        "# Phase 24.12 — Frozen Expected-Behaviour Oracle Replacement",
        "",
        "<!-- Generated by scripts/phase24_frozen_oracle.py from registry",
        "     authority and the frozen vector file. Do not edit by hand;",
        "     update the script and regenerate. -->",
        "",
        f"Status: `{node['status']}`",
        f"Vectors: `{node['vector_count']}`",
        f"Archived-corpus linked vectors: "
        f"`{node['archived_corpus_linked_vectors']}`",
        f"Digest: `{node['vectors_digest']}`",
        "",
        "The retired backend was the semantic oracle for the parity guards.",
        "It is no longer executed by any of them. Parity is carried by the",
        "immutable Patch 23.11 archived reference corpus plus the frozen",
        "vectors below; each converted guard still runs its native arm live",
        "and still compares it byte for byte, against frozen observables",
        "rather than against a freshly generated C program.",
        "",
        "Unknown vectors, moved source fixtures, changed vector kinds, and",
        "vectors that disagree with the archived corpus fail closed. There",
        "is no live-C fallback and no environment-selected route back to the",
        "emitter. Refreshing the set needs a new version and explicit",
        "roadmap authority.",
        "",
        "## Parity harnesses with no live-C arm",
        "",
    ]
    for locus in node["frozen_loci"]:
        lines.append(f"- `{locus}`")
    lines += [
        "",
        "## What this patch does and does not claim",
        "",
        "After this patch **no parity guard selects the C backend**: the",
        f"spelling is gone from all {len(FROZEN_LOCI)} harnesses and",
        f"{len(FROZEN_RECIPES)} recipes above.",
        "",
        "Two of them still *reach* live C through the shared runner's default",
        "route (`scripts/run-gust-file.sh`), which is Patch",
        f"`{RUNNER_RESIDUE_OWNER}`'s row to migrate, not this one's:",
        "",
    ]
    for locus, count in sorted(node["runner_mediated_residue"].items()):
        lines.append(f"- `{locus}` — {count} default-route call(s)")
    lines += [
        "",
        "That count is registered and checked, so the residue cannot grow",
        "unnoticed and cannot be mistaken for a completed migration.",
        "",
        "## Parity recipes with no live-C arm",
        "",
    ]
    for recipe in node["frozen_recipes"]:
        lines.append(f"- `{recipe}`")
    lines += [
        "",
        "## Pre-existing reds this patch does not repair",
        "",
        "Both fail on their native or static side before any C comparison, so",
        "neither is a live-lane disagreement, and nothing below is frozen from",
        "a failing run. They are listed here so the Phase 24.16 residue audit",
        "cannot miss them.",
        "",
    ]
    for row in NOT_REPAIRED:
        lines += [
            f"### `{row['guard']}`",
            "",
            f"- State: `{row['state']}`",
            f"- Cause: {row['cause']}",
            f"- Why main is green: {row['why_ci_is_green']}",
            f"- Reproduce: `{row['reproduce']}`",
            f"- Frozen from a red run: `{row['frozen_from_a_red_run']}`",
            f"- What is frozen: {row['frozen_how']}",
            f"- Scope: `{row['scope']}` (owner `{row['owner']}`)",
        ]
        if "tracked_by" in row:
            lines.append(f"- Tracked by: {row['tracked_by']}")
        lines.append("")
    lines += ["## Frozen vectors", ""]
    for vector_id in node["vector_ids"]:
        lines.append(f"- `{vector_id}`")
    lines.append("")
    return "\n".join(lines)


def check_review(node: dict) -> None:
    require(VIEW.read_text(encoding="utf-8") == render(node),
            "generated frozen oracle review is stale; run render")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=(
        "validate", "render", "check-review", "materialize",
        "mutation-evidence"))
    parser.add_argument("vector_id", nargs="?")
    parser.add_argument("prefix", nargs="?")
    parser.add_argument("--kind", choices=("exec", "reject"), default=None)
    parser.add_argument("--workdir", default=None)
    args = parser.parse_args()

    if args.command == "materialize":
        require(bool(args.vector_id) and bool(args.prefix),
                "materialize needs a vector id and an output prefix")
        materialize(args.vector_id, Path(args.prefix), args.kind,
                    Path(args.workdir) if args.workdir else None)
        return
    if args.command == "mutation-evidence":
        checked = validate_mutations(load_vectors())
        print(f"{GUARD_L2}: {checked} frozen vectors are falsifiable "
              f"(exit, stdout, moved source, changed kind, unknown id)")
        return

    node = validate()
    if args.command == "render":
        VIEW.write_text(render(node), encoding="utf-8")
        validate()
        print(f"{GUARD_L1}: render ok")
    elif args.command == "check-review":
        check_review(node)
        print(f"{GUARD_L1}: review current")
    else:
        print(f"{GUARD_L1}: ok "
              f"({node['vector_count']} vectors, "
              f"{node['archived_corpus_linked_vectors']} archived-corpus "
              f"linked, {len(FROZEN_LOCI)} harnesses and "
              f"{len(FROZEN_RECIPES)} recipes free of live C)")


if __name__ == "__main__":
    main()
