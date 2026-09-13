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
EMITTER_ONLY_ASSERTIONS_REMOVED = (
    ROOT / "compiler/fixtures/phase24_emitter_only_assertions_removed_v1.json")
JUSTFILE = ROOT / "justfile"
WORKFLOW = ROOT / ".github/workflows/phase24-frozen-oracle.yml"

GUARD_L1 = "guard-cranelift-phase24-frozen-oracle-contract"
GUARD_L2 = "guard-cranelift-phase24-frozen-oracle-evidence"
VERSION = "phase24_frozen_oracle_replacement_v1"
STATUS = "patch24_12_complete"
VECTOR_FORMAT = "gust.phase24.frozen_oracle_vectors.v1"

# Execution loci that carried a parity guard's live-C arm before this patch
# and must carry none after it. This is the Patch 24.12 exit gate expressed
# as a check: "zero parity guards WITH A NATIVE ARM execute live C". The list
# is the 24.11 inventory's 24.12-owned harness set minus the seven harnesses
# below that have no native arm; a converted guard that grows a C arm back,
# and a new parity guard that reaches for one, both fail here.
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
    "scripts/phase19_composition_parity.sh",
    "scripts/phase19_representation_parity.sh",
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
    "scripts/phase20_resource_enforcement.sh",
    "scripts/phase20_resource_scope_cleanup.sh",
    "scripts/phase20_stdlib_runtime_differential.sh",
    "scripts/phase20_whole_program_corpus.sh",
    "scripts/phase21_collection_string_native_source.sh",
    "scripts/phase21_cross_tenant_capability.sh",
    "scripts/phase21_filesystem_allocation_native_source.sh",
    "scripts/phase21_od8_adversarial_verdict.sh",
    "scripts/phase21_opening.sh",
    "scripts/phase21_per_root_obligations.sh",
    "scripts/phase21_resource_sync_native_source.sh",
    "scripts/phase21_trusted_scope_provenance.sh",
    "scripts/phase21_typed_query_noop_surface.sh",
)

# ---------------------------------------------------------------------------
# The seven harnesses this patch deliberately does NOT convert, and the
# measurable criterion that selects them.
#
# Ask: does the harness have a native arm? If it does, conversion preserves a
# real comparison — one side becomes frozen, the other still runs live. If it
# does not, the harness compiles two *source* arms through C and compares the
# generated C text, or the C program's exit, to each other. Freezing both
# sides of that leaves a frozen-vs-frozen tautology that can never fail: a
# deleted test wearing a conversion's clothes, and worse than a deletion
# because it still looks like coverage.
#
# Their invariants ("renaming a type does not change the generated C", "a
# local's spelling does not change the generated C") are invariants *about the
# emitter being retired*. They die with it, which is what the Immutable
# Contract's "a guard that exists only to serve the retired backend is removed
# with it, not carried" describes. Patch 24.12a retires them, and that is
# where the original "zero parity guards execute live C" gate closes.
#
# The criterion is checked, not asserted: `check_native_arm_split` below
# measures each harness and fails if any row is on the wrong side.
# ---------------------------------------------------------------------------

EXCLUDED_EMITTER_ONLY_LOCI = (
    "scripts/phase19_classification_parity.sh",
    "scripts/phase19_gust_name_list_removed_parity.sh",
    "scripts/phase19_rename_invariance.sh",
    "scripts/phase19_rule_convergence_parity.sh",
    "scripts/phase19_type_naming_parity.sh",
    "scripts/phase20_resource_declaration_migration.sh",
    "scripts/phase21_inert_scoped_query_records.sh",
)
EXCLUDED_OWNER = "24.12a"

# A harness has a native arm when it runs one of these live, directly or
# through a harness it delegates to.
NATIVE_EXECUTOR = re.compile(
    r"--backend cranelift"
    r"|build/gust-native-backend"
    r"|GUST_NATIVE_BACKEND_DRIVER"
    r"|gust-cranelift-experiment")
DELEGATION = re.compile(r"bash (scripts/[A-Za-z0-9_./-]+\.sh)")

# ---------------------------------------------------------------------------
# The one live `--backend mir-to-c` spelling that is not a C arm.
#
# phase12_5 asserts that poisoning the route makes it *unavailable*: the
# invocation must fail, must emit no C, and must report the test-only
# diagnostic. Nothing is compiled or executed from it, so there is no
# observable to freeze — freezing it would replace a live refusal with a
# recording of one. It is registered here, with its exact count, so the
# exemption is visible and cannot quietly grow.
# ---------------------------------------------------------------------------

POISONED_ROUTE_PROBES = {
    "scripts/phase12_5_route_architecture.sh": 1,
}
POISON_GUARD = "GUST_TEST_MIR_TO_C_UNAVAILABLE=1"

# ---------------------------------------------------------------------------
# Closure guards that required a converted harness to still contain live C.
#
# Three closed-phase closure guards `rg -F` for the exact live-C spellings
# inside scripts/phase13_registry_differential.sh. Converting that harness
# made all three red, and none of them was in the 43-guard trace, so nothing
# else would have caught it before CI. The obligation they encode is
# unchanged — every differential case still drives a MIR-to-C observation and
# a live native one and compares them byte for byte — so each assertion is
# rewritten to the spelling that now carries it, per the standing ruling on
# predecessor guards with live-C expectations. Registered as old -> new so the
# rewrite is reviewable rather than buried in a justfile diff.
# ---------------------------------------------------------------------------

LIVE_C_PRESENCE_ASSERTIONS_REWRITTEN = (
    {
        "guard": "guard-cranelift-phase13-close",
        "target": "scripts/phase13_registry_differential.sh",
        "was": "./gust --backend c \"$source_fixture\"",
        "now": "python3 scripts/phase24_frozen_oracle.py materialize",
    },
    {
        "guard": "guard-cranelift-phase13-close",
        "target": "scripts/phase13_registry_differential.sh",
        "was": "./gust --backend mir-to-c \"$source_fixture\"",
        "now": "\"$source_fixture\" \"$case_dir/mir-to-c\" --kind exec",
    },
    {
        "guard": "guard-cranelift-phase13-close",
        "target": "scripts/phase13_registry_differential.sh",
        "was": "cmp -s \"$case_dir/default.c\" \"$case_dir/explicit.c\"",
        "now": "cmp -s \"$case_dir/mir-to-c.stdout\" \"$case_dir/native.stdout\"",
    },
    {
        "guard": "guard-cranelift-phase11-close",
        "target": "scripts/phase13_registry_differential.sh",
        "was": "default.c",
        "now": "phase24_frozen_oracle.py materialize",
    },
    {
        "guard": "guard-cranelift-phase11-close",
        "target": "scripts/phase13_registry_differential.sh",
        "was": "explicit.c",
        "now": "workdir \"$case_dir/mir-workdir\"",
    },
    {
        "guard": "guard-cranelift-phase11-close",
        "target": "scripts/phase13_registry_differential.sh",
        "was": "cmp -s \"$case_dir/default.c\" \"$case_dir/explicit.c\"",
        "now": "cmp -s \"$case_dir/mir-to-c.stdout\" \"$case_dir/native.stdout\"",
    },
    {
        "guard": "guard-cranelift-phase11-close",
        "target": "scripts/phase13_registry_differential.sh",
        "was": "mir-to-c-program",
        "now": "mir-to-c.status",
    },
    {
        "guard": "guard-cranelift-phase12-5-close",
        "target": "scripts/phase13_registry_differential.sh",
        "was": "./gust --backend c \"$source_fixture\"",
        "now": "python3 scripts/phase24_frozen_oracle.py materialize",
    },
    {
        "guard": "guard-cranelift-phase14-close",
        "host": "scripts/phase14_closure.py",
        "target": "scripts/phase13_registry_differential.sh",
        "was": "./gust --backend c \"$source_fixture\"",
        "now": "python3 scripts/phase24_frozen_oracle.py materialize",
    },
    {
        "guard": "guard-cranelift-phase14-close",
        "host": "scripts/phase14_closure.py",
        "target": "scripts/phase13_registry_differential.sh",
        "was": "./gust --backend mir-to-c \"$source_fixture\"",
        "now": "\"$source_fixture\" \"$case_dir/mir-to-c\" --kind exec",
    },
    {
        "guard": "guard-cranelift-phase14-close",
        "host": "scripts/phase14_closure.py",
        "target": "scripts/phase13_registry_differential.sh",
        "was": "cmp -s \"$case_dir/default.c\" \"$case_dir/explicit.c\"",
        "now": "cmp -s \"$case_dir/mir-to-c.stdout\" \"$case_dir/native.stdout\"",
    },
    {
        "guard": "guard-cranelift-phase12-5-close",
        "target": "scripts/phase13_registry_differential.sh",
        "was": "./gust --backend mir-to-c \"$source_fixture\"",
        "now": "\"$source_fixture\" \"$case_dir/mir-to-c\" --kind exec",
    },
    {
        "guard": "guard-cranelift-phase12-5-close",
        "target": "scripts/phase13_registry_differential.sh",
        "was": "cmp -s \"$case_dir/default.c\" \"$case_dir/explicit.c\"",
        "now": "cmp -s \"$case_dir/mir-to-c.stdout\" \"$case_dir/native.stdout\"",
    },
)

# ---------------------------------------------------------------------------
# Cases inside a converted harness that have no native counterpart.
#
# The exit gate is stated at harness granularity, and these rows are the
# residue inside it: the harness has a native arm, but these particular cases
# never had one, so after conversion their only observation is the frozen
# record. They are not tautologies — a moved source fixture or a changed
# registered exit still fails them closed — but they carry no live
# comparison, and saying so is cheaper than letting a reader assume otherwise.
# ---------------------------------------------------------------------------

FROZEN_ONLY_CASES = (
    {
        "locus": "scripts/phase21_per_root_obligations.sh",
        "case": "unscoped_join",
        "source_fixture": "compiler/phase21_unscoped_join_positive.gst",
        "why": "its positive-cases row registers native_exit '-'",
        "reproduce": "python3 scripts/phase21_per_root_obligations.py "
                     "positive-cases",
    },
    {
        "locus": "scripts/phase21_per_root_obligations.sh",
        "case": "branch_return_alias_flow",
        "source_fixture": "compiler/phase21_query_value_flow_positive.gst",
        "why": "its positive-cases row registers native_exit '-'",
        "reproduce": "python3 scripts/phase21_per_root_obligations.py "
                     "positive-cases",
    },
    {
        "locus": "scripts/phase21_od8_adversarial_verdict.sh",
        "case": "joins/scoped_primary_unscoped_lookup",
        "source_fixture": "compiler/phase21_unscoped_join_positive.gst",
        "why": "its positive-cases row registers native_exit '-'",
        "reproduce": "python3 scripts/phase21_od8_adversarial_verdict.py "
                     "positive-cases",
    },
    {
        "locus": "scripts/phase21_od8_adversarial_verdict.sh",
        "case": "queries_as_values/fully_discharged_branch_alias_return",
        "source_fixture": "compiler/phase21_query_value_flow_positive.gst",
        "why": "its positive-cases row registers native_exit '-'",
        "reproduce": "python3 scripts/phase21_od8_adversarial_verdict.py "
                     "positive-cases",
    },
    {
        "locus": "scripts/phase21_trusted_scope_provenance.sh",
        "case": "outside_query_use",
        "source_fixture":
            "compiler/phase21_trusted_scope_outside_query_invalid.gst",
        "why": "the nonforgeability-cases loop has no Cranelift arm at all",
        "reproduce": "python3 scripts/phase21_trusted_scope_provenance.py "
                     "nonforgeability-cases",
    },
    {
        "locus": "scripts/phase21_trusted_scope_provenance.sh",
        "case": "reserved_intrinsic_redefinition",
        "source_fixture":
            "compiler/phase21_trusted_scope_reserved_intrinsic_invalid.gst",
        "why": "the nonforgeability-cases loop has no Cranelift arm at all",
        "reproduce": "python3 scripts/phase21_trusted_scope_provenance.py "
                     "nonforgeability-cases",
    },
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
                 "native_boundary case; nothing in the justfile invokes "
                 "the guard \u2014 it appears twice, as its own recipe head "
                 "and inside an `rg -e` pattern in "
                 "guard-cranelift-phase11-close that forbids the call, and "
                 "guard_reachability scores the second as a caller "
                 "(issue #390)",
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


# Mutation evidence reads a tampered copy of the manifest through this, so
# nothing ever rewrites the committed authority file. An earlier shape wrote
# the mutation into `VECTORS` and restored it in a `finally`, which is one
# SIGTERM away from leaving the repository's frozen manifest holding a
# deliberately corrupted vector, and made a concurrent `git add` on that file
# fail with SIGBUS.
_VECTORS_PATH = VECTORS


def load_vectors() -> dict:
    require(_VECTORS_PATH.is_file(), "frozen vector file is missing")
    return json.loads(_VECTORS_PATH.read_text(encoding="utf-8"))


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
                workdir: Path | None = None,
                env_key: str | None = None) -> None:
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
    # A fixture whose C arm is parameterised by the environment (the
    # long-lived concurrency guard runs it under a cycle count) is frozen
    # once per environment the harness actually uses. The call site passes
    # the same assignment it sets, so the frozen side and the live native
    # side are compared under identical conditions.
    require(env_key is not None or not vector.get("env_parameterised"),
            f"env-parameterised vector served without an environment: "
            f"{vector_id} — failing closed rather than replaying the run "
            f"captured with the variable unset")
    if env_key is not None:
        variants = vector.get("env_variants") or {}
        require(vector.get("env_parameterised") is True,
                f"an environment was requested for a vector frozen without "
                f"one: {vector_id}")
        require(env_key in variants,
                f"no frozen vector for {vector_id} under environment "
                f"'{env_key}' — failing closed, there is no live-C fallback")
        execution = variants[env_key]
        Path(f"{prefix}.status").write_text(
            f"{execution['exit']}\n", encoding="utf-8")
        Path(f"{prefix}.stdout").write_bytes(record_bytes(execution["stdout"]))
        Path(f"{prefix}.stderr").write_bytes(record_bytes(execution["stderr"]))
        return
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


def has_native_arm(locus: str, seen: set[str] | None = None) -> bool:
    """Does this harness run the native backend, directly or by delegation?

    This is the convert-vs-retire criterion, measured rather than judged. The
    delegation step is load-bearing: phase15 and phase16 reach Cranelift
    through the experiment worker they build, and phase19_representation
    reaches it through phase16_call_mir_parity.sh, so a direct-spelling test
    would call three converted harnesses emitter-only.
    """
    seen = set() if seen is None else seen
    if locus in seen:
        return False
    seen.add(locus)
    path = ROOT / locus
    if not path.is_file():
        return False
    text = path.read_text(encoding="utf-8")
    if NATIVE_EXECUTOR.search(text):
        return True
    return any(has_native_arm(target, seen)
               for target in DELEGATION.findall(text))


def check_native_arm_split() -> None:
    """Every converted harness has a native arm; every excluded one does not.

    A harness put on the wrong side of this split fails here rather than
    becoming a frozen-vs-frozen tautology nobody notices.
    """
    for locus in FROZEN_LOCI:
        require(has_native_arm(locus),
                f"a converted parity harness has no native arm, so freezing "
                f"its C side leaves nothing live to compare against: {locus}")
    for locus in EXCLUDED_EMITTER_ONLY_LOCI:
        path = ROOT / locus
        require(path.is_file(),
                f"an excluded emitter-only harness is missing: {locus}")
        require(not has_native_arm(locus),
                f"an excluded harness grew a native arm and is now "
                f"convertible rather than {EXCLUDED_OWNER}'s to retire: "
                f"{locus}")
        require(BACKEND_SPELLING.search(path.read_text(encoding="utf-8")),
                f"an excluded emitter-only harness no longer executes C, so "
                f"it was converted or changed outside this patch: {locus}")
    overlap = set(FROZEN_LOCI) & set(EXCLUDED_EMITTER_ONLY_LOCI)
    require(not overlap, f"a harness is both converted and excluded: "
                         f"{sorted(overlap)}")


def check_emitter_only_removals() -> dict:
    """Every recorded removal really happened."""
    require(EMITTER_ONLY_ASSERTIONS_REMOVED.is_file(),
            "the emitter-only assertion removal record is missing")
    record = json.loads(
        EMITTER_ONLY_ASSERTIONS_REMOVED.read_text(encoding="utf-8"))
    require(record.get("format") ==
            "gust.phase24.emitter_only_assertions_removed.v1",
            "emitter-only removal record format drifted")
    for row in record["removals"]:
        for field in ("locus", "kind", "assertion", "probe"):
            require(field in row, f"malformed removal row: {row}")
        require(row["kind"] in ("generated_c_determinism",
                               "generated_c_text"),
                f"unknown removal kind: {row['kind']}")
        path = ROOT / str(row["locus"])
        require(path.is_file(),
                f"removal record names a missing file: {row['locus']}")
        require(row["probe"] not in path.read_text(encoding="utf-8"),
                f"a removal this patch claims to have made is still there: "
                f"{row['locus']}: {row['probe']}")
    return record


def check_presence_rewrites() -> None:
    """Each closure guard now asserts the spelling that carries the obligation.

    Both directions matter: the new spelling must be in the harness (or the
    guard asserts something that is not there), and the old one must be gone
    (or the rewrite was cosmetic and the guard would still pass on an
    unconverted harness).
    """
    for row in LIVE_C_PRESENCE_ASSERTIONS_REWRITTEN:
        # A presence assertion lives in the justfile unless it says otherwise;
        # the Phase 14 closure keeps its copy in Python.
        host_path = ROOT / str(row.get("host", "justfile"))
        require(host_path.is_file(),
                f"a rewritten presence assertion names a missing host: "
                f"{row.get('host', 'justfile')}")
        host = host_path.read_text(encoding="utf-8")
        target = ROOT / str(row["target"])
        require(target.is_file(),
                f"a rewritten presence assertion names a missing harness: "
                f"{row['target']}")
        body = target.read_text(encoding="utf-8")
        require(row["now"] in body,
                f"{row['guard']} asserts a spelling {row['target']} does not "
                f"have: {row['now']}")
        require(row["was"] not in body,
                f"{row['guard']}'s old live-C spelling is back in "
                f"{row['target']}: {row['was']}")
        require(row["now"] in host,
                f"{row['guard']} was not rewritten to the new spelling: "
                f"{row['now']}")
        require(f"'{row['was']}'" not in host,
                f"a live-C presence assertion survives in "
                f"{row.get('host', 'justfile')}: {row['was']}")


def check_frozen_only_cases(vectors: dict) -> None:
    """The cases inside a converted harness that carry no live comparison."""
    for row in FROZEN_ONLY_CASES:
        require(row["locus"] in FROZEN_LOCI,
                f"a frozen-only case names a harness this patch did not "
                f"convert: {row['locus']}")
        require(str(row["source_fixture"]) in vectors["vectors"],
                f"a frozen-only case has no frozen vector: "
                f"{row['source_fixture']}")


def check_no_live_c() -> None:
    for locus in FROZEN_LOCI:
        path = ROOT / locus
        require(path.is_file(), f"frozen parity harness is missing: {locus}")
        text = path.read_text(encoding="utf-8")
        lines = text.split("\n")
        hits = [index for index, line in enumerate(lines)
                if BACKEND_SPELLING.search(line)]
        allowed = POISONED_ROUTE_PROBES.get(locus, 0)
        require(len(hits) == allowed,
                f"a converted parity harness executes live C again: "
                f"{locus} ({len(hits)} spellings, {allowed} registered as "
                f"route-unavailability probes)")
        for index in hits:
            # A registered probe asserts the route is *refused*. It compiles
            # nothing and runs nothing, so there is no observable to freeze;
            # freezing it would replace a live refusal with a recording of
            # one. Anything else on this line is a C arm wearing a probe's
            # name.
            require(any(POISON_GUARD in line
                        for line in lines[max(0, index - 3):index]),
                    f"a live-C spelling in {locus} is not a registered "
                    f"route-unavailability probe (line {index + 1})")
        if allowed:
            require("unexpectedly emitted generated C" in text,
                    f"a route-unavailability probe in {locus} no longer "
                    f"asserts that nothing was emitted")
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
                      kind: str | None = None,
                      env_key: str | None = None) -> None:
    global _VECTORS_PATH
    payload = json.loads(VECTORS.read_text(encoding="utf-8"))
    payload["vectors"] = table
    with tempfile.TemporaryDirectory() as raw:
        scratch = Path(raw) / VECTORS.name
        scratch.write_text(json.dumps(payload), encoding="utf-8")
        _VECTORS_PATH = scratch
        try:
            materialize(vector_id, prefix, kind, None, env_key)
        finally:
            _VECTORS_PATH = VECTORS


def _served_block(slot: dict, kind: str, env_key: str | None) -> dict:
    """The record `materialize` will actually replay for this call shape."""
    if env_key is not None:
        return slot["env_variants"][env_key]
    return slot["compile"] if kind == "reject" else slot["execution"]


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
            # An environment-parameterised vector is never served without an
            # environment, so its falsifiability has to be demonstrated the
            # way the guard actually asks for it.
            env_key = (sorted(vector["env_variants"])[0]
                       if vector.get("env_parameterised") else None)
            _materialize_from(vector_id, table, prefix, env_key=env_key)
            kind = vector["kind"]
            observed = "status" if kind == "reject" else "status"
            good_status = Path(f"{prefix}.{observed}").read_bytes()
            good_out = Path(
                f"{prefix}.log" if kind == "reject" else f"{prefix}.stdout"
            ).read_bytes()

            mutated = copy.deepcopy(table)
            block = _served_block(mutated[vector_id], kind, env_key)
            block["exit"] = int(block["exit"]) + 1
            _materialize_from(vector_id, mutated, root / "exit",
                              env_key=env_key)
            require(Path(f"{root / 'exit'}.status").read_bytes() != good_status,
                    f"exit-status mutation is invisible: {vector_id}")

            mutated = copy.deepcopy(table)
            stream = _served_block(mutated[vector_id], kind, env_key)["stdout"]
            tampered = bytes.fromhex(str(stream["hex"])) + b"tampered"
            stream["hex"] = tampered.hex()
            stream["size"] = len(tampered)
            stream["sha256"] = digest_bytes(tampered)
            _materialize_from(vector_id, mutated, root / "out",
                              env_key=env_key)
            require(Path(
                f"{root / 'out'}.log" if kind == "reject"
                else f"{root / 'out'}.stdout").read_bytes() != good_out,
                f"stdout mutation is invisible: {vector_id}")

            if env_key is not None:
                # Two more ways an environment-parameterised vector could be
                # served wrongly and look fine: dropping the environment (and
                # silently replaying the unset run), or asking for one that
                # was never frozen.
                try:
                    _materialize_from(vector_id, table, root / "noenv")
                    fail(f"an env-parameterised vector was replayed without "
                         f"an environment: {vector_id}")
                except SystemExit as error:
                    require("served without an environment" in str(error),
                            f"a missing environment failed for the wrong "
                            f"reason: {vector_id}")
                try:
                    _materialize_from(vector_id, table, root / "badenv",
                                      env_key="NO_SUCH_VARIABLE=1")
                    fail(f"an unfrozen environment was replayed anyway: "
                         f"{vector_id}")
                except SystemExit as error:
                    require("failing closed" in str(error),
                            f"an unfrozen environment failed for the wrong "
                            f"reason: {vector_id}")

            mutated = copy.deepcopy(table)
            mutated[vector_id]["source_sha256"] = "0" * 64
            try:
                _materialize_from(vector_id, mutated, root / "moved",
                                  env_key=env_key)
                fail(f"a moved source fixture was replayed anyway: {vector_id}")
            except SystemExit as error:
                require("moved without a re-freeze" in str(error),
                        f"a moved source failed for the wrong reason: "
                        f"{vector_id}")

            mutated = copy.deepcopy(table)
            mutated[vector_id]["kind"] = (
                "reject" if kind == "exec" else "exec")
            try:
                _materialize_from(vector_id, mutated, root / "kind", kind,
                                  env_key)
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

    # The manifest is pinned by content, not by an id list. Listing the ids
    # in the registry would put every frozen fixture path into
    # scripts/cranelift_feature_registry.json, and the Phase 12.5 route
    # architecture guard requires its two probe fixtures to stay out of that
    # file precisely so a probe cannot be mistaken for a registered historical
    # case. The digest pins strictly more than the ids would.
    require(node.get("vector_count") == len(ids) and
            node.get("vectors_digest") == canonical_digest(table),
            "registered frozen counts drifted")
    require("vector_ids" not in node,
            "the registry must not enumerate frozen fixture paths; the "
            "Phase 12.5 route probes have to stay out of it")

    check_no_live_c()
    check_native_arm_split()
    require(node.get("frozen_loci") == list(FROZEN_LOCI) and
            node.get("frozen_recipes") == list(FROZEN_RECIPES),
            "registered frozen locus set drifted")
    require(node.get("excluded_emitter_only_loci") ==
            list(EXCLUDED_EMITTER_ONLY_LOCI) and
            node.get("excluded_emitter_only_owner") == EXCLUDED_OWNER,
            "the registered emitter-only exclusion set drifted")
    require(node.get("poisoned_route_probes") == dict(POISONED_ROUTE_PROBES),
            "the registered route-unavailability probe set drifted")
    removals = check_emitter_only_removals()
    require(node.get("emitter_only_assertions_removed") ==
            len(removals["removals"]) and
            node.get("emitter_only_assertions_removed_digest") ==
            canonical_digest(removals["removals"]),
            "the registered emitter-only removal record drifted")
    check_presence_rewrites()
    require(node.get("live_c_presence_assertions_rewritten") ==
            [dict(row) for row in LIVE_C_PRESENCE_ASSERTIONS_REWRITTEN],
            "the registered live-C presence rewrites drifted")
    check_frozen_only_cases(vectors)
    require(node.get("frozen_only_cases") ==
            [dict(row) for row in FROZEN_ONLY_CASES],
            "the registered frozen-only case set drifted")
    # Environment-parameterised vectors must declare every environment a
    # call site may ask for, and must not silently fall back to the unset
    # capture: the long-lived concurrency fixture exits 90 with its cycle
    # count unset and 47 with it set, so serving the wrong one would freeze
    # an expectation the guard never produced.
    parameterised = []
    for vector_id, vector in sorted(table.items()):
        variants = vector.get("env_variants")
        flagged = bool(vector.get("env_parameterised"))
        require(flagged == (variants is not None),
                f"env_parameterised and env_variants disagree: {vector_id}")
        if variants is None:
            continue
        parameterised.append(str(vector["source_fixture"]))
        require(isinstance(variants, dict) and variants,
                f"env-parameterised vector has no variants: {vector_id}")
        require(vector["kind"] == "exec",
                f"only an executing vector can be environment "
                f"parameterised: {vector_id}")
        for key, variant in sorted(variants.items()):
            require("=" in key,
                    f"env variant key is not KEY=VALUE: {vector_id} {key}")
            for field in ("exit", "stdout", "stderr"):
                require(field in variant,
                        f"env variant is malformed: {vector_id} {key}")
            record_bytes(variant["stdout"])
            record_bytes(variant["stderr"])
    authority = vectors["capture_authority"]
    require(authority.get("env_parameterised_fixtures") == parameterised,
            "the registered environment-parameterised fixture set drifted")
    require(bool(authority.get("env_capture_tool_sha256")) ==
            bool(parameterised),
            "environment variants exist without naming the tool that "
            "captured them")
    require(node.get("env_parameterised_fixtures") == parameterised,
            "registered environment-parameterised fixtures drifted")

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
        "After this patch **no parity harness or recipe with a native arm",
        "selects the C backend**: the spelling is gone from all "
        f"{len(FROZEN_LOCI)}",
        f"harnesses and {len(FROZEN_RECIPES)} recipes above.",
        "",
        "Read that as the population it was measured over, not as a",
        "repository-wide statement. The Patch 24.11 consumer inventory",
        "discovers execution loci by globbing `scripts/*.sh` together with",
        "the Makefile, the justfile fragments and a named set of entry",
        "fixtures. A parity guard implemented in Python runs both backends",
        "through `subprocess` and is invisible to that census, so this patch",
        "neither converted nor counted one. Those guards are outside this",
        "patch and still need an owner before the unqualified gate can",
        "close.",
        "",
        f"Within that population {len(EXCLUDED_EMITTER_ONLY_LOCI)} further",
        "parity harnesses still execute live C and are listed below: they",
        "have no native arm, so freezing both of their source arms would",
        "leave a comparison that can never fail. Patch",
        f"`{EXCLUDED_OWNER}` retires them, and that is where the original",
        "\"zero parity guards execute live C\" gate closes **for the",
        "measured population**. It does not close outright until the Python",
        "guards named above have an owner too.",
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
        "## Parity harnesses deliberately excluded (owner "
        f"`{EXCLUDED_OWNER}`)",
        "",
        "The criterion is measured, not asserted: a harness has a native arm",
        "if it runs `--backend cranelift`, `build/gust-native-backend`,",
        "`GUST_NATIVE_BACKEND_DRIVER` or `gust-cranelift-experiment`, directly",
        "or through a harness it delegates to. `validate` fails if any row",
        "below acquires one, or if any converted harness turns out to lack",
        "one.",
        "",
    ]
    for locus in node["excluded_emitter_only_loci"]:
        lines.append(f"- `{locus}`")
    lines += [
        "",
        "## The one live-C spelling that is not a C arm",
        "",
        "A route-unavailability probe asserts the C route is *refused*: the",
        "invocation must fail and must emit no C. Nothing is compiled or run",
        "from it, so there is no observable to freeze — freezing it would",
        "replace a live refusal with a recording of one. The count is",
        "registered and each occurrence must sit under",
        f"`{POISON_GUARD}`.",
        "",
    ]
    for locus, count in sorted(node["poisoned_route_probes"].items()):
        lines.append(f"- `{locus}` — {count} probe(s)")
    lines += [
        "",
        "## Emitter-only assertions removed",
        "",
        "Determinism comparisons between two identical MIR-to-C invocations",
        "of the same source, and assertions about the text of the generated",
        "C. Each inspected the emitter and had no native counterpart, so each",
        "goes with it rather than being frozen on both sides. `validate`",
        "asserts every recorded removal really happened.",
        "",
        f"- {node['emitter_only_assertions_removed']} assertions removed",
        f"- Record: `{EMITTER_ONLY_ASSERTIONS_REMOVED.relative_to(ROOT)}`",
        f"- Digest: `{node['emitter_only_assertions_removed_digest']}`",
        "",
        "## Closure guards that required live C to still be there",
        "",
        "Three closed-phase closure guards asserted the exact live-C",
        "spellings inside the Phase 13 differential harness, so converting it",
        "made them red. The obligation is unchanged — every differential case",
        "still drives a MIR-to-C observation and a live native one and",
        "compares them byte for byte — so each assertion is rewritten to the",
        "spelling that now carries it.",
        "",
    ]
    for row in node["live_c_presence_assertions_rewritten"]:
        lines.append(f"- `{row['guard']}` on `{row['target']}`: "
                     f"`{row['was']}` -> `{row['now']}`")
    lines += [
        "",
        "## Cases with no live comparison left",
        "",
        "The gate is stated per harness; these are the cases inside a",
        "converted harness that never had a native counterpart, so after",
        "conversion their only observation is the frozen record. A moved",
        "source fixture or a changed registered exit still fails them closed,",
        "but no live comparison remains.",
        "",
    ]
    for row in node["frozen_only_cases"]:
        lines.append(f"- `{row['locus']}` case `{row['case']}` "
                     f"({row['source_fixture']}) — {row['why']}")
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
    lines += [
        "## Frozen vectors",
        "",
        f"`{node['vector_count']}` vectors, pinned by content as",
        f"`{node['vectors_digest']}`. The manifest itself is",
        f"`{VECTORS.relative_to(ROOT)}`; it is not enumerated in the registry,",
        "because that would put every frozen fixture path into a file the",
        "Phase 12.5 route architecture guard requires its probe fixtures to",
        "stay out of.",
        "",
    ]
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
    parser.add_argument("--env", default=None,
                        help="KEY=VALUE the call site sets when running the "
                             "arm; selects the frozen variant for it")
    args = parser.parse_args()

    if args.command == "materialize":
        require(bool(args.vector_id) and bool(args.prefix),
                "materialize needs a vector id and an output prefix")
        materialize(args.vector_id, Path(args.prefix), args.kind,
                    Path(args.workdir) if args.workdir else None,
                    args.env)
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
