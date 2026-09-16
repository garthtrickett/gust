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
import importlib.util
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
# Patch 24.12b (#416): the additive v2 capture, served alongside v1.
VECTORS_V2 = ROOT / "compiler/fixtures/phase24_frozen_oracle_vectors_v2.json"
VECTORS_V3 = ROOT / "compiler/fixtures/phase24_frozen_oracle_vectors_v3.json"
VECTORS_V4 = ROOT / "compiler/fixtures/phase24_frozen_oracle_vectors_v4.json"
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
# with it, not carried" describes. Patch 24.12a retires them.
#
# It is not where the unqualified "zero parity guards execute live C" gate
# closes, and this comment used to say it was. That closure moved to Patch
# 24.12b by coordinator ruling: the population both this patch and the 24.11
# inventory measure is the shell one, and 8 parity guards written in Python
# run both backends in one function and compare them. Retiring these seven
# leaves those eight, so 24.12a cannot close a gate stated over every parity
# guard. 24.12b converts them and widens the population to see them.
#
# The criterion is checked, not asserted: `check_native_arm_split` below
# measures each harness and fails if any row is on the wrong side.
# ---------------------------------------------------------------------------

# Patch 24.12a retired all seven. The register is empty and stays empty.
EXCLUDED_EMITTER_ONLY_LOCI: tuple[str, ...] = ()

# What an empty register must not become is a vacuous one. The loop below
# used to iterate this tuple, so emptying it would turn the criterion into a
# test that passes because there is nothing to test -- the exact shape of
# defect this phase keeps finding. So 24.12a replaces it with a discovery
# sweep over the same population 24.11 inventories (`scripts/*.sh`), and
# measuring it turned up one harness that is emitter-only and is not 24.12's
# to have excluded: the explicit-C migration evidence, which the inventory
# already defers to 24.13. Registered here with its owner rather than
# rounded down to zero.
EMITTER_ONLY_RESIDUE = {
    "scripts/phase22_explicit_c_migration.sh": "24.13",
}
EXCLUDED_OWNER = "24.12a"
# Where the unqualified gate closes. Not 24.12a: see the note above.
UNQUALIFIED_GATE_OWNER = "24.12b"

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

# Patch 24.13 briefly added a second way to be a route-unavailability probe,
# for a world where the spelling was rejected by construction. That removal is
# deferred until the live-C surface drains (issue #398), so the C route still
# EXISTS and the poison env var is once again the only thing that can make it
# unavailable at run time.
#
# The alternative form is retired rather than left dormant: as a disjunct it
# could never fire, but it would still let any harness qualify as a probe by
# containing three strings, which is weaker than what this check is for.

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
# Patch 24.13 (#411): the residue is discharged, not excused.
#
# These two harnesses called the shared runner with no route pinned, so they
# reached the retired backend through its default. Patch 24.13 flips that
# default to cranelift, which is why this register is now empty and why the
# unqualified live-C gate belongs to this patch rather than to 24.12b.
#
# Kept as an empty register rather than deleted: check_no_live_c below asserts
# it is empty, so a harness that reacquires a default-route call fails instead
# of quietly rejoining a set nobody reads.
# Patch 24.13: emptied, and the flip alone did NOT empty it. Both rows --
# phase15_resource_composition_parity.sh and phase16_abi_composition_parity.sh
# -- reached live C through the runner's default, and flipping that default
# left them with no working route at all rather than with a native one: their
# `compiler/future/p1{5,6}_complete_*_differential_source.gst` sources have a
# deferred native capability, and the mir-to-c route this patch removed was the
# only other one. CI named it as an unconnected source-level route.
#
# What discharged the rows was converting that one call in each harness to the
# frozen oracle, which both were already materializing two lines later. Their
# remaining runner calls are smoke entries that compile natively today --
# measured, not assumed, against a built native package.
#
# Recorded because "the register is empty" and "the work is done" are different
# claims, and this patch briefly had the first without the second.
RUNNER_MEDIATED_RESIDUE: dict[str, int] = {}
RUNNER_RESIDUE_OWNER = "24.13"

# ---------------------------------------------------------------------------
# The shared runner's own default, which no Phase 24 patch owned.
#
# RUNNER_MEDIATED_RESIDUE above records converted harnesses that still reach
# live C through the runner. This records the runner itself: before Patch
# 24.13, scripts/run-gust-file.sh WAS
# RUNNER_ROUTE="${GUST_RUNNER_ROUTE:-mir-to-c}", so a caller that set
# nothing reached the retired backend *by default rather than by selection*
# -- the "no fallback, retry-through-C, or environment-selected route"
# invariant read forwards. It is cranelift now; the paragraph is kept in the
# past tense because the register exists to witness that change.
#
# Four justfile recipes call the runner. Two pin GUST_RUNNER_ROUTE=cranelift
# on the invoking line and the inventory re-verifies that pin. The two below
# do not, and both are live: they are Stdlib-owned guards, so no Phase 24
# patch was given them, and deleting the spelling in 24.13 breaks both.
#
# Registered, not fixed: 24.12a retires emitter-only guards, and a default
# pointing at a spelling is a selection-removal concern. 24.13 flips the
# default. If Stdlib pins these explicitly first, 24.13's change becomes a
# no-op -- the check below then fails and the register has to say so, rather
# than the row being quietly dropped.
# ---------------------------------------------------------------------------

# Patch 24.13 (#411): the flip this register exists to witness. It was
# ${GUST_RUNNER_ROUTE:-mir-to-c}; a caller that pinned nothing reached the
# retired backend by default rather than by selection, which is what kept
# Patch 24.12b's live-C gate qualified.
RUNNER_DEFAULT_ROUTE = 'RUNNER_ROUTE="${GUST_RUNNER_ROUTE:-cranelift}"'
RUNNER_DEFAULT_UNPINNED_CALLERS = (
    "guard-stdlib-s1-collection-receivers",
    "guard-stdlib-s1-str-surface",
)
RUNNER_CALL = re.compile(r"bash scripts/run-gust-file\.sh")

BACKEND_SPELLING = re.compile(r"--backend (?:mir-to-c|c(?=[\s\"']|$))")
RECIPE_HEAD = re.compile(r"^([A-Za-z0-9_-]+)([^:]*):")


# ---------------------------------------------------------------------------
# Patch 24.12b: the Python population, computed rather than enumerated (#415).
#
# FROZEN_LOCI above is a registered tuple, so check_no_live_c can only catch a
# *registered* harness reacquiring live C. A guard written in Python that
# builds its own argv is invisible to it, and to check_sweep, whose loci are
# scripts/*.sh plus the Makefile and the justfile fragments.
#
# The criterion below is derived from the tree, not listed here. Every
# scripts/*.py that builds an argv selecting the retired backend must be
# either converted or carry a registered exclusion with a reason. A file that
# acquires such an argv later fails this check rather than being silently out
# of scope -- the inverse form, so it fails on a new site instead of on a list
# that inherits whichever enumeration was wrong.
#
# It over-approximates deliberately: it finds argv *construction*, not proven
# execution. The narrower form -- requiring the list be passed directly to a
# subprocess.* call -- was measured and returns 0, because every site on this
# tree hands its argv to a local helper (`run`, `run_process`, `run_before`).
# That is #396's indirection defect one language over, and it is why the
# narrow form is recorded here as rejected rather than used.
# ---------------------------------------------------------------------------

# Named PENDING, not CONVERTED, because that is the true state. A file in this
# tuple still builds a retired-backend argv today -- that is exactly why the
# derivation still finds it. Conversion *removes* the argv, which drops the
# file out of the derived population, and the staleness check below then
# requires its row be retired. So the tuple empties itself as the work lands,
# and "Patch 24.12b is done" is the statement that it is empty. Calling these
# "converted" while they still execute the retired backend would be the
# green-but-wrong shape this phase keeps finding.
PYTHON_RETIRED_ARGV_PENDING_CONVERSION: tuple[str, ...] = (
)

# Patch 24.13: rows retired out of the register above, with the check that
# retires them.
#
# The staleness check below requires that a registered locus still builds a
# retired-backend argv, so a converted file's row must come out. Deleting the
# row would leave no trace that the file was ever in the population -- the
# exclusion's reason, and the fact that it was discharged rather than never
# applying, would both be gone. So the row moves here instead, and the claim
# inverts: each entry asserts the argv is ABSENT, and fails if the file starts
# building one again.
PYTHON_RETIRED_ARGV_DISCHARGED: dict[str, str] = {
    "scripts/phase23_issue_health_opening.py":
        "converted by Patch 24.13. Both retired-backend calls asserted issue "
        "#105's diagnostic against literals, and front-end rejection was "
        "measured to be backend-independent, so both were re-pointed at the "
        "native backend with an explicit -o. The assertions are unchanged; "
        "only the route they travel is.",
    "scripts/phase23_same_scope_declaration.py":
        "converted by Patch 24.13. Its exclusion said conversion needed a "
        "frozen-vector capture and roadmap authority Patch 24.12b did not "
        "hold. 24.13 did not capture vectors: it retired the two explicit-C "
        "arms and asserts the same claims where they are actually decided -- "
        "the duplicate is rejected in the front end, before native capability "
        "selection is consulted, which is what the two-backend differential "
        "was proving indirectly. host_c_compiles and its explicit-C oracle "
        "were retired with it.",
    "scripts/phase21_cranelift_built_compiler_programs.py":
        "discharged by Patch 24.13. Its exclusion covered compile_oracle, the "
        "MIR-to-C third arm of a three-way comparison. All three arms were "
        "checked against the REGISTERED accepted_cases rather than against "
        "each other, so the oracle was a third witness and not the reference; "
        "24.13 replaces it with the frozen vector asserted against those same "
        "values, and retires the now-callerless function.",
    "scripts/phase23_structured_guard_defer_native_admission.py":
        "discharged by Patch 24.13. Its exclusion covered run_oracle, the "
        "MIR-to-C differential arm. The guard was converted to hold the "
        "native arm to the registered observables directly, which left "
        "run_oracle dead while it still constructed a retired-backend argv; "
        "24.13 retires the function. MIR_TO_C_COMMAND still records the argv "
        "it built, so the history survives as data.",
}

# Each exclusion carries the reason it is out, and every reason is a property
# something else on the tree can contradict -- not an opinion recorded once.
PYTHON_RETIRED_ARGV_EXCLUSIONS: dict[str, str] = {
    # The three the literals-only scan could not see. Registered rather than
    # converted, each for a reason measured on this tree, and all three are
    # workflow-reachable -- they were executing live C while this guard
    # reported zero pending conversions.
    "scripts/phase21_complete_guard_suite.py":
        "a two-arm parity suite whose oracle arm IS the retired route: "
        "compile_case builds the argv from a parameter and qualify_case "
        "passes 'mir-to-c'. Conversion needs a frozen vector per case, and "
        "only 4 of its 326 runner cases have one -- 322 captures, which is "
        "not a budget Patch 24.12b holds. Routing it natively instead would "
        "leave a parity suite comparing the native arm against itself. Owned "
        "by 24.13, which cannot merge while this suite still executes a "
        "spelling it removes (#424).",
    "scripts/phase23_mir_to_c_deprecation_opening.py":
        "opening record for a closed phase: compile_baseline('mir-to-c') and "
        "('c') establish the Phase 23 deprecation baseline itself, so the "
        "retired-route call produces the reference rather than being judged "
        "against one. Its source has no vector. Same disposition as "
        "phase23_structured_guard_defer_native_admission.",
    "scripts/phase24_cr15_opening.py":
        "opening record for CR-15: its routes list is "
        "[explicit_c_spellings[0], explicit_native_backend], and the explicit-C "
        "route is the thing the opening measures. Its witness has no vector.",
    "scripts/phase24_frozen_oracle_capture.py":
        "the capture tool itself. It builds the retired argv because running "
        "the retired route while the live lane is green is precisely what a "
        "capture is, under the authority TASK.md Patch 24.12b grants (#416). "
        "It is not a parity guard, runs only when named with --authority, and "
        "becomes inert at Patch 24.13, which seals the corpus. Caught by this "
        "very check when it was added, which is the inverse assertion working: "
        "a new site fails rather than being silently out of scope.",
    "scripts/phase24_filename_behavior_characterization.py":
        "the retired spelling is data in a ROUTES table whose subject *is* "
        "route-dependent behaviour (Patch 24.1). Removing the row would "
        "delete the phenomenon under characterization; Patch 24.3 carries the "
        "correction as future work by operator decision.",
}


# Patch 24.12b (#416): fixtures that are modules, not programs.
#
# A module has no `main`, so it cannot be captured as an exec vector -- the
# capture tool's link step fails, correctly, and writes nothing. It does not
# need one: a module's behaviour is exercised through the source that imports
# it, and that source carries the vector.
#
# Registered as a claim the validator checks rather than a note: each entry
# must actually be imported by a fixture that has a vector. A module whose
# importer loses its vector stops being covered, and this fails rather than
# leaving the module silently uncaptured.
PYTHON_MODULE_FIXTURES: dict[str, str] = {
    "compiler/phase21_selected_declaration_module.gst":
        "compiler/phase21_selected_declaration_source.gst",
    "compiler/phase22_default_index_initialization_helper.gst":
        "compiler/phase22_default_index_initialization_source.gst",
    "compiler/phase24_resource_implicit_transfer_module.gst":
        "compiler/phase24_resource_implicit_transfer_positive.gst",
}


def check_module_fixture_cover() -> int:
    """Every registered module is imported by a fixture that has a vector."""
    servable = load_servable_vectors()["vectors"]
    for module, importer in PYTHON_MODULE_FIXTURES.items():
        require((ROOT / module).is_file(),
                f"a registered module fixture is missing: {module}")
        require(importer in servable,
                f"module {module} is registered as covered by {importer}, "
                f"but that fixture has no frozen vector")
        body = (ROOT / importer).read_text(encoding="utf-8", errors="replace")
        require(Path(module).name in body,
                f"{importer} no longer imports {module}, so the module is "
                f"not covered by it")
    return len(PYTHON_MODULE_FIXTURES)


def python_retired_argv_sites() -> dict[str, list[int]]:
    """Every scripts/*.py that builds an argv selecting the retired backend.

    Derived by walking each module's AST for a list or tuple literal whose
    elements include the ``--backend`` flag followed by a retired spelling,
    or a single fused ``--backend=<spelling>`` element.
    """
    import ast

    retired = {"mir-to-c", "c"}
    found: dict[str, list[int]] = {}
    for path in sorted((ROOT / "scripts").glob("*.py")):
        try:
            tree = ast.parse(path.read_text(encoding="utf-8", errors="replace"))
        except SyntaxError:
            continue
        lines: list[int] = []
        for node in ast.walk(tree):
            if not isinstance(node, (ast.List, ast.Tuple)):
                continue
            elements = [
                element.value
                if isinstance(element, ast.Constant)
                and isinstance(element.value, str) else None
                for element in node.elts
            ]
            for index, value in enumerate(elements):
                if (value == "--backend" and index + 1 < len(elements)
                        and elements[index + 1] in retired):
                    lines.append(node.lineno)
                elif (isinstance(value, str) and value.startswith("--backend=")
                      and value.split("=", 1)[1] in retired):
                    lines.append(node.lineno)
                elif value == "--backend" and index + 1 < len(elements):
                    # The backend is chosen by a VARIABLE, so its value is not
                    # visible here. Recognising only adjacent literals made this
                    # scan report a file as clean while it executed live C:
                    # phase21_complete_guard_suite.compile_case builds
                    # [compiler, "--backend", backend] and qualify_case passes
                    # "mir-to-c" into it, from three workflows.
                    #
                    # Resolving that needs interprocedural dataflow. This check
                    # does the thing it can defend instead: an argv whose
                    # backend value cannot be resolved to a literal is
                    # UNRESOLVED, and unresolved fails -- same direction as the
                    # rest of this instrument, where a site that cannot be
                    # classified is a failure rather than a pass. A file that
                    # genuinely only ever passes a live spelling says so with a
                    # registered exclusion.
                    if node.elts[index + 1].__class__ is not ast.Constant:
                        lines.append(node.lineno)
        if lines:
            found[path.relative_to(ROOT).as_posix()] = sorted(set(lines))
    return found


# Patch 24.12b (#416): a vector is keyed by source path and pins
# source_sha256, so the oracle's identity model assumes the source is a
# tracked file. A guard that *writes* its own .gst sources has nothing to key
# on, and no budget discharges the conversion step for it. That is a different
# disposition from "needs a capture", and the roadmap's list of eight does not
# distinguish them -- so it is measured here rather than inherited.
#
# Over-approximating on purpose: any locus that synthesizes a .gst at all is
# flagged, and the flag is cleared only by a registered disposition. A guard
# that starts synthesizing sources later fails this rather than silently
# becoming unconvertible.
# Patch 24.12b: conversion is per call site, not per guard. A guard can hold
# both a convertible parity arm and an arm asserting a property of the EMITTED
# C with no native counterpart; the second kind is Patch 24.12a's class and
# cannot be converted. Empty because every such arm in this patch's population
# has been retired and inverted -- the register stays, with its falsifier, so
# a future arm has somewhere to be declared rather than being invented ad hoc.
PYTHON_EMITTER_ONLY_ARMS: dict[str, str] = {}


PYTHON_SOURCE_SYNTHESIS_DISPOSITION: dict[str, str] = {
}


def python_source_synthesis() -> dict[str, list[int]]:
    """Loci that write their own .gst sources at run time.

    Detected by walking for a write to a path whose literal or f-string
    spelling ends in ``.gst``. It over-approximates: a locus that writes any
    such path is reported, whether or not that source reaches the retired arm.
    """
    import ast

    def names_gst(node: ast.AST) -> bool:
        for child in ast.walk(node):
            if isinstance(child, ast.Constant) and isinstance(child.value, str):
                if child.value.endswith(".gst"):
                    return True
        return False

    found: dict[str, list[int]] = {}
    for path in sorted((ROOT / "scripts").glob("*.py")):
        try:
            tree = ast.parse(path.read_text(encoding="utf-8", errors="replace"))
        except SyntaxError:
            continue
        lines: list[int] = []
        for node in ast.walk(tree):
            if (isinstance(node, ast.Call)
                    and isinstance(node.func, ast.Attribute)
                    and node.func.attr in ("write_text", "write_bytes")):
                target = node.func.value
                # `<expr>.write_text(...)` where <expr> mentions a .gst name,
                # or a variable assigned from one -- the assignment form is
                # caught by scanning the enclosing module for the same name.
                if names_gst(target):
                    lines.append(node.lineno)
        # Catch the two-step form: `p = dir / "x.gst"` then `p.write_text(...)`.
        gst_vars: set[str] = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Assign) and names_gst(node.value):
                for target in node.targets:
                    if isinstance(target, ast.Name):
                        gst_vars.add(target.id)
        for node in ast.walk(tree):
            if (isinstance(node, ast.Call)
                    and isinstance(node.func, ast.Attribute)
                    and node.func.attr in ("write_text", "write_bytes")
                    and isinstance(node.func.value, ast.Name)
                    and node.func.value.id in gst_vars):
                lines.append(node.lineno)
        if lines:
            found[path.relative_to(ROOT).as_posix()] = sorted(set(lines))
    return found


def check_python_population() -> dict[str, object]:
    """Patch 24.12b: the criterion, measured over the live tree."""
    sites = python_retired_argv_sites()
    pending = set(PYTHON_RETIRED_ARGV_PENDING_CONVERSION)
    excluded = set(PYTHON_RETIRED_ARGV_EXCLUSIONS)

    overlap = pending & excluded
    require(not overlap,
            "a Python locus is both pending conversion and excluded: "
            f"{sorted(overlap)}")

    discharged = set(PYTHON_RETIRED_ARGV_DISCHARGED)
    reentered = sorted(discharged & set(sites))
    require(not reentered,
            "a Python locus registered as discharged builds a retired-backend "
            f"argv again: {reentered}")
    for locus in discharged:
        require((ROOT / locus).is_file(),
                "a discharged Python locus was deleted rather than converted: "
                f"{locus}")
    collision = sorted(discharged & (pending | excluded))
    require(not collision,
            "a Python locus is both discharged and still registered as "
            f"pending or excluded: {collision}")

    accounted = pending | excluded
    unaccounted = sorted(set(sites) - accounted)
    require(not unaccounted,
            "a scripts/*.py builds a retired-backend argv and is neither "
            "owned for conversion nor registered as excluded: "
            f"{unaccounted}")

    # An account that no longer describes the tree is worse than none: it
    # reads as coverage. Both directions fail.
    stale = sorted(accounted - set(sites))
    require(not stale,
            "a registered Python locus no longer builds a retired-backend "
            f"argv; retire its row instead of leaving it: {stale}")

    for locus, reason in PYTHON_RETIRED_ARGV_EXCLUSIONS.items():
        require(len(reason.split()) >= 12,
                f"a Python exclusion is registered without a reason: {locus}")

    # #416: a locus pending conversion that synthesizes its own .gst sources
    # cannot be discharged by capturing a vector, because there is no tracked
    # path to key one on. It needs a registered disposition saying which of
    # its sources are capturable and where the rest go.
    for locus, description in PYTHON_EMITTER_ONLY_ARMS.items():
        require(locus in pending,
                f"an emitter-only arm is registered against a locus that is "
                f"not pending conversion; retire the row: {locus}")
        require(len(description.split()) >= 12,
                f"an emitter-only arm is registered without a description: "
                f"{locus}")

    synthesis = python_source_synthesis()
    needs_disposition = sorted(pending & set(synthesis))
    missing = [locus for locus in needs_disposition
               if locus not in PYTHON_SOURCE_SYNTHESIS_DISPOSITION]
    require(not missing,
            "a locus pending conversion writes its own .gst sources and has "
            f"no registered disposition: {missing}")
    for locus, disposition in PYTHON_SOURCE_SYNTHESIS_DISPOSITION.items():
        require(locus in synthesis,
                f"a source-synthesis disposition names a locus that no longer "
                f"synthesizes sources; retire its row instead: {locus}")
        require(len(disposition.split()) >= 12,
                f"a source-synthesis disposition has no reason: {locus}")

    return {
        "population": len(sites),
        "pending": len(pending),
        "excluded": len(excluded),
        "synthesizes_sources": sorted(pending & set(python_source_synthesis())),
        "sites": {locus: list(lines) for locus, lines in sites.items()},
    }


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


def load_servable_vectors() -> dict:
    """v1 plus the Patch 24.12b v2 capture, for serving only.

    The two corpora are kept as separate files on purpose. v1 is immutable and
    its supersession policy forbids refreshing it, so v2 is an *addition*
    rather than an edit: a source captured for the Python guards cannot
    silently redefine a v1 observable. Serving unions them; `validate` still
    measures v1 alone, so the v1 counts this guard reports keep meaning what
    they meant.

    A v2 vector that collides with a v1 id fails rather than shadowing it --
    the one direction that would let a new capture overwrite a frozen
    expectation without anything noticing.
    """
    vectors = load_vectors()
    # During a mutation replay `_materialize_from` repoints _VECTORS_PATH at a
    # scratch file holding exactly the table under test. That table is already
    # the complete set to serve, so merging v2 on top of it would re-add the
    # very vectors being mutated and trip the collision check below. Serving
    # the scratch verbatim is what makes the v2 arm testable at all.
    if _VECTORS_PATH != VECTORS:
        return vectors
    if not VECTORS_V2.is_file():
        return vectors
    second = json.loads(VECTORS_V2.read_text(encoding="utf-8"))
    require(second.get("format") == "phase24_frozen_oracle_vectors_v2",
            "the v2 capture file is not a v2 corpus")
    collisions = sorted(set(second["vectors"]) & set(vectors["vectors"]))
    require(not collisions,
            f"a v2 vector would shadow a v1 vector; v1 is immutable and a "
            f"capture may not redefine it: {collisions}")
    merged = dict(vectors)
    merged["vectors"] = dict(vectors["vectors"])
    merged["vectors"].update(second["vectors"])
    # Patch 24.12c adds a third capture, on the same terms as the second: an
    # addition, never an edit. Its collision check spans v1 AND v2, because by
    # this point both are already merged and a v3 vector may shadow neither.
    for path, expected_format, label in (
            (VECTORS_V3, "phase24_frozen_oracle_vectors_v3", "v3"),
            (VECTORS_V4, "phase24_frozen_oracle_vectors_v4", "v4")):
        if not path.is_file():
            continue
        block = json.loads(path.read_text(encoding="utf-8"))
        require(block.get("format") == expected_format,
                f"the {label} capture file is not a {label} corpus")
        collisions = sorted(set(block["vectors"]) & set(merged["vectors"]))
        require(not collisions,
                f"a {label} vector would shadow an earlier one; the previous "
                "corpora are immutable and a capture may not redefine them: "
                f"{collisions}")
        merged["vectors"].update(block["vectors"])
    return merged


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
    require(vector["kind"] in ("exec", "reject", "compile_only"),
            f"frozen vector has an unknown kind: {vector_id}")
    if vector["kind"] == "compile_only":
        # Patch 24.12c. A fixture that must be compiled but never run -- the
        # CR-16 raw-double-unlock witness, whose two unlock paths make its
        # runtime behaviour undefined and whose guard stops at
        # `cc -fsyntax-only`. The absence of an execution record is the
        # POINT, so it is asserted rather than tolerated, and the reason is
        # carried in the vector so a consumer cannot read it as an omission.
        require("execution" not in vector,
                f"a compile-only vector carries an execution record, which "
                f"is the one thing its kind exists to forbid: {vector_id}")
        require(vector.get("never_executed_reason"),
                f"a compile-only vector does not say why it is never "
                f"executed: {vector_id}")
    source = ROOT / str(vector["source_fixture"])
    require(source.is_file(),
            f"frozen vector source is missing: {vector_id}")
    require(digest_bytes(source.read_bytes()) == vector["source_sha256"],
            f"frozen vector source moved without a re-freeze: {vector_id}")
    if vector["kind"] == "exec":
        require("execution" in vector,
                f"exec vector has no frozen execution: {vector_id}")
    # Provenance is an allowlist, not a free field: an unrecognised value
    # fails closed. The v2 spelling is listed explicitly rather than relaxed
    # to a prefix match, so a third capture has to declare itself too.
    require(vector["provenance"] in (
        "derived_from_archived_corpus_v1", "captured_live_while_green",
        "captured_live_while_green_patch24_12b",
        "captured_live_while_green_patch24_12c",
        "captured_live_while_green_patch24_12d"),
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
    # Serving resolves v1 and the v2 capture; validate below still measures
    # v1 alone, so its counts keep meaning what they meant.
    vectors = load_servable_vectors()
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
    if vector["kind"] == "compile_only":
        # Serve the compile side and stop. There is deliberately no runtime
        # observable to write.
        Path(f"{prefix}.compile.stdout").write_bytes(
            record_bytes(compile_record["stdout"]))
        Path(f"{prefix}.never-executed").write_text(
            str(vector["never_executed_reason"]) + "\n", encoding="utf-8")
        return
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
    # Measured, not registered: every shell harness that still spells a live
    # C backend and cannot compare it against a native arm. Patch 24.12a
    # emptied the exclusion register, so this population must be exactly the
    # residue another patch owns -- a new emitter-only harness, or a
    # converted one that loses its native arm, fails here rather than being
    # absorbed by an empty tuple.
    measured = sorted(
        path.relative_to(ROOT).as_posix()
        for path in (ROOT / "scripts").glob("*.sh")
        if BACKEND_SPELLING.search(
            path.read_text(encoding="utf-8", errors="replace"))
        and not has_native_arm(path.relative_to(ROOT).as_posix()))
    require(measured == sorted(EMITTER_ONLY_RESIDUE),
            f"the emitter-only shell population moved: measured {measured}, "
            f"registered {sorted(EMITTER_ONLY_RESIDUE)}")
    require(not EXCLUDED_EMITTER_ONLY_LOCI,
            f"Patch {EXCLUDED_OWNER} retired the exclusion register; a locus "
            f"is back in it: {list(EXCLUDED_EMITTER_ONLY_LOCI)}")
    for locus, owner in sorted(EMITTER_ONLY_RESIDUE.items()):
        require((ROOT / locus).is_file(),
                f"registered emitter-only residue is missing: {locus}")
        require(owner != EXCLUDED_OWNER,
                f"residue owned by {EXCLUDED_OWNER} should have been retired "
                f"by it: {locus}")
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
            poisoned = any(POISON_GUARD in line
                           for line in lines[max(0, index - 3):index])
            require(poisoned,
                    f"a live-C spelling in {locus} is not a registered "
                    f"route-unavailability probe (line {index + 1}): it does "
                    "not carry the poison guard")
        if allowed:
            require("unexpectedly emitted generated C" in text,
                    f"a route-unavailability probe in {locus} no longer "
                    f"asserts that nothing was emitted")
    # The runner-mediated residue is bounded and owned by 24.13; it must not
    # grow, and a harness must not quietly acquire a new default-route call.
    require(not RUNNER_MEDIATED_RESIDUE,
            "Patch 24.13 discharged the runner-mediated residue by flipping "
            "the runner default; a locus is back in the register: "
            f"{sorted(RUNNER_MEDIATED_RESIDUE)}")
    for locus, expected in RUNNER_MEDIATED_RESIDUE.items():
        text = (ROOT / locus).read_text(encoding="utf-8")
        found = sum(1 for line in text.split("\n")
                    if RUNNER_CALL.search(line)
                    and "GUST_RUNNER_ROUTE=cranelift" not in line)
        require(found == expected,
                f"runner-mediated C residue moved without updating the "
                f"{RUNNER_RESIDUE_OWNER} hand-off: {locus} "
                f"({found} default-route calls, registered {expected})")
    # Patch 24.13 (#411): the polarity of this check is inverted with the
    # runner's default.
    #
    # It used to forbid an UNPINNED runner call, because unpinned meant the
    # retired backend. After the default flip, unpinned means cranelift, so an
    # unpinned call is now the correct thing and forbidding it would be
    # asserting the opposite of what the phase wants. What must be forbidden
    # instead is an EXPLICIT pin to the retired route, which is the only way a
    # converted harness can still reach it.
    for locus in FROZEN_LOCI:
        text = (ROOT / locus).read_text(encoding="utf-8")
        require(not any(RUNNER_CALL.search(line) and
                        "GUST_RUNNER_ROUTE=mir-to-c" in line
                        for line in text.split("\n")),
                f"a converted parity harness pins the retired route "
                f"explicitly: {locus}")

    # The runner's default route, and every recipe that takes it by omission.
    runner = (ROOT / "scripts/run-gust-file.sh").read_text(encoding="utf-8")
    require(RUNNER_DEFAULT_ROUTE in runner,
            f"the shared runner's default route changed; "
            f"{RUNNER_RESIDUE_OWNER} owns that flip and this register has "
            f"to record it rather than silently agree")
    unpinned = sorted(
        recipe for recipe, body in recipe_bodies().items()
        for line in body.split("\n")
        if "run-gust-file.sh" in line
        and "GUST_RUNNER_ROUTE=cranelift" not in line)
    require(unpinned == sorted(RUNNER_DEFAULT_UNPINNED_CALLERS),
            f"the set of recipes reaching live C through the runner's "
            f"default moved: measured {unpinned}, registered "
            f"{sorted(RUNNER_DEFAULT_UNPINNED_CALLERS)}")

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
    # `compile_only` serves its compile block, like `reject` does. It has no
    # execution record at all -- that absence is the point of the kind, for a
    # witness whose runtime behaviour is undefined and must never be replayed
    # as an expectation. Reading slot["execution"] here raised KeyError:
    # 'execution' the moment such a vector entered the servable set, which is
    # a crash where a clear refusal belongs.
    if kind in ("reject", "compile_only"):
        return slot["compile"]
    return slot["execution"]


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

            # Patch 24.12b (#412): stderr on the same footing as exit and
            # stdout. materialize freezes it on every vector, and the docstring
            # above has always claimed the live lane caught a wrong stderr --
            # but nothing here demonstrated it, so the claim rested on the
            # arm that did not exist. For an exec vector the observable is
            # {prefix}.stderr; for a reject it is folded into {prefix}.log.
            good_err = Path(
                f"{prefix}.log" if kind == "reject" else f"{prefix}.stderr"
            ).read_bytes()
            mutated = copy.deepcopy(table)
            stream = _served_block(mutated[vector_id], kind, env_key)["stderr"]
            tampered = bytes.fromhex(str(stream["hex"])) + b"tampered"
            stream["hex"] = tampered.hex()
            stream["size"] = len(tampered)
            stream["sha256"] = digest_bytes(tampered)
            _materialize_from(vector_id, mutated, root / "err",
                              env_key=env_key)
            require(Path(
                f"{root / 'err'}.log" if kind == "reject"
                else f"{root / 'err'}.stderr").read_bytes() != good_err,
                f"stderr mutation is invisible: {vector_id}")

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


# ---------------------------------------------------------------------------
# End-to-end mutation evidence: the arrow `validate_mutations` cannot reach.
#
# `validate_mutations` above tampers with a vector, materializes it, and
# asserts the bytes moved. That proves `materialize` transcribes its input
# faithfully — the first arrow of
#
#     vector -> materialize -> guard reads artifacts -> guard asserts
#
# and it stops there. Nothing in that function invokes a guard, so on its own
# it cannot tell a guard that compares what it materializes from one that
# materializes a record and reads none of it.
#
# Two of the ways that could go wrong are caught before this file's mutations
# ever run, because the evidence guard runs the contract first:
# `check_presence_rewrites` fails if a converted harness loses the comparison
# it was re-pointed to, and `check_native_arm_split` fails if it stops
# executing its native side. Both were confirmed by mutation, each failing on
# its own assertion rather than on some other one.
#
# What neither of those covers is an assertion that is present and does not
# fire. Only running a guard against a wrong vector answers that, so
# scripts/phase24_frozen_oracle_e2e_mutation.py does exactly that, and the
# measured result is recorded below rather than described. The rows are
# checked against the probe and against the harnesses they name, so a sample
# entry cannot quietly stop meaning what it says.
# ---------------------------------------------------------------------------

E2E_PROBE = ROOT / "scripts/phase24_frozen_oracle_e2e_mutation.py"
E2E_PASSING_VERDICT = "FAILS THEN PASSES"

E2E_MUTATION_EVIDENCE = (
    {
        "guard": "guard-cranelift-phase11-generic-canonical-mir-route",
        "harness": "scripts/phase13_registry_differential.sh",
        "vector": "compiler/phase14_struct_composition_source.gst",
        "mutate": "stdout",
        "mutation": "execution.stdout 0B -> 8B",
        "expect": "runtime stdout bytes differ",
        "comparison":
            'cmp -s "$case_dir/mir-to-c.stdout" "$case_dir/native.stdout"',
        "verdict": E2E_PASSING_VERDICT,
        "mutate_leg_rc": 1,
        "pass_leg_rc": 0,
        "measured": "2026-09-14T05:21:01Z",
        "why": "the guard runs `bash \"$differential_harness\" all`, so it "
               "executes the harness this patch rewrote, and the mutation "
               "targets the comparison the rewrite re-pointed rather than "
               "the status comparison beside it that the rewrite never "
               "touched",
    },
)

# Consumers the probe ran and found blind. Kept because a probe whose findings
# are dropped is a probe nobody can audit, and because this one was the first
# candidate tested — the class it was built to detect was not empty.
E2E_BLIND_CONSUMERS = (
    {
        "guard": "guard-cranelift-phase13-capability-deferral-contract",
        "harness": "scripts/phase13_capability_deferral.sh",
        "vector": "compiler/phase12_5_route_novel_source.gst",
        "mutation": "execution.exit 49 -> 50",
        "verdict": "DOES NOT FAIL",
        "control": "build/guards/cranelift_phase13_capability_deferral/"
                   "frozen.status read back as 50 after the leg, so the "
                   "tampered expectation did reach the guard",
        "cause": "it requests a full execution record with --kind exec and "
                 "the only later use of that prefix is a test that compile "
                 "stderr is empty; frozen.status, frozen.stdout and "
                 "frozen.stderr are never read",
        "residual": "not inert — materialize still fails it closed on a "
                    "moved source fixture — but blind to every frozen "
                    "execution expectation",
        "tracked_by": "#407",
    },
)

# What vector mutation cannot reach at all, stated so the sample is not read
# as covering it.
E2E_UNCOVERED = (
    "None of the four closure guards rewritten in this patch "
    "(phase11-close, phase12-5-close, phase13-close, phase14-close) consumes "
    "a vector: two assert the text of the materialize call and two never "
    "mention it. Whether a re-pointed closure assertion still fires therefore "
    "cannot be tested by mutating a vector. check_presence_rewrites covers "
    "their presence-and-absence obligation; a weakened one needs separate "
    "evidence and does not have it here."
)


def load_e2e_probe_sample() -> tuple[dict, ...]:
    """The probe's own sample, read from the probe rather than restated.

    Importing it is the point: a row here that has drifted from the entry the
    probe actually ran is a record of a measurement nobody made.
    """
    require(E2E_PROBE.is_file(),
            f"the end-to-end mutation probe is missing: "
            f"{E2E_PROBE.relative_to(ROOT)}; the evidence rows below record "
            f"runs of a file that is no longer here")
    spec = importlib.util.spec_from_file_location(
        "phase24_frozen_oracle_e2e_mutation", E2E_PROBE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return tuple(module.SAMPLE)


def check_e2e_mutation_evidence(vectors: dict) -> None:
    just = JUSTFILE.read_text(encoding="utf-8")
    sample = load_e2e_probe_sample()
    keyed = {(str(entry["guard"]), str(entry["vector"])): entry
             for entry in sample}

    for row in E2E_MUTATION_EVIDENCE:
        key = (row["guard"], row["vector"])
        require(key in keyed,
                f"an end-to-end evidence row records a run the probe no "
                f"longer performs: {row['guard']} on {row['vector']}")
        entry = keyed[key]
        for field in ("mutate", "expect"):
            require(entry[field] == row[field],
                    f"the probe and the recorded result disagree about "
                    f"{field} for {row['guard']}: {entry[field]!r} vs "
                    f"{row[field]!r}")
        require(row["verdict"] == E2E_PASSING_VERDICT,
                f"an end-to-end evidence row records a verdict that is not a "
                f"pass: {row['guard']} -> {row['verdict']}")
        require(row["mutate_leg_rc"] != 0 and row["pass_leg_rc"] == 0,
                f"an end-to-end evidence row is not a fails-then-passes "
                f"pair: {row['guard']} "
                f"(mutate={row['mutate_leg_rc']}, pass={row['pass_leg_rc']})")
        require(f"{row['guard']}:" in just,
                f"an end-to-end evidence row names a guard the justfile does "
                f"not define: {row['guard']}")
        harness = ROOT / str(row["harness"])
        require(harness.is_file(),
                f"an end-to-end evidence row names a missing harness: "
                f"{row['harness']}")
        body = harness.read_text(encoding="utf-8")
        # The two halves of the assertion the probe required to fire. Losing
        # either turns the recorded pass into a statement about code that is
        # no longer there.
        require(row["comparison"] in body,
                f"the comparison {row['guard']} was measured to fail on is "
                f"gone from {row['harness']}: {row['comparison']}")
        require(row["expect"] in body,
                f"{row['harness']} no longer emits the failure the probe "
                f"matched on, so the recorded verdict cannot be reproduced: "
                f"{row['expect']}")
        vector = vectors["vectors"].get(str(row["vector"]))
        require(vector is not None,
                f"an end-to-end evidence row mutates a vector that is no "
                f"longer frozen: {row['vector']}")
        require(vector.get("archived_corpus_case") is None,
                f"{row['vector']} is now archived-corpus linked, so "
                f"check_corpus_identity would reject the probe's mutation "
                f"before the guard ever saw it and the recorded pass would "
                f"be about the oracle rather than about the guard")

    for row in E2E_BLIND_CONSUMERS:
        require(f"{row['guard']}:" in just,
                f"a recorded blind consumer names a guard the justfile does "
                f"not define: {row['guard']}")
        require((ROOT / str(row["harness"])).is_file(),
                f"a recorded blind consumer names a missing harness: "
                f"{row['harness']}")
        require(str(row["vector"]) in vectors["vectors"],
                f"a recorded blind consumer names a vector that is no longer "
                f"frozen: {row['vector']}")
        require(row.get("tracked_by"),
                f"a blind consumer is recorded with no issue tracking it: "
                f"{row['guard']}")


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

    # v2 is pinned the same way v1 is. It was not, and the asymmetry was
    # load-bearing: capture_authority_digest is WRITTEN into each v2 vector and
    # read by nothing, so a v2 observation could be edited -- keeping its own
    # size and sha256 fields self-consistent -- and the loader would accept it,
    # because it checked only the format and collisions against v1. The frozen
    # corpus is the only oracle the retired backend leaves behind; an
    # unpinned half of it is a corpus that can be quietly rewritten.
    if VECTORS_V2.exists():
        v2_table = json.loads(VECTORS_V2.read_text(encoding="utf-8"))["vectors"]
        require(node.get("v2_vector_count") == len(v2_table),
                "registered v2 vector count drifted: registry says "
                f"{node.get('v2_vector_count')}, the manifest holds "
                f"{len(v2_table)}")
        require(node.get("v2_vectors_digest") == canonical_digest(v2_table),
                "registered v2 vectors digest drifted; a v2 observation was "
                "edited after capture")

    check_no_live_c()
    check_native_arm_split()
    # Patch 24.12b (#415): the Python half of the population, derived from the
    # tree rather than read off FROZEN_LOCI. check_no_live_c above iterates a
    # registered tuple and so cannot see a guard that was never registered.
    python_population = check_python_population()
    check_module_fixture_cover()
    require(node.get("frozen_loci") == list(FROZEN_LOCI) and
            node.get("frozen_recipes") == list(FROZEN_RECIPES),
            "registered frozen locus set drifted")
    require(node.get("excluded_emitter_only_loci") ==
            list(EXCLUDED_EMITTER_ONLY_LOCI) and
            node.get("excluded_emitter_only_owner") == EXCLUDED_OWNER,
            "the registered emitter-only exclusion set drifted")
    require(node.get("emitter_only_residue") == dict(EMITTER_ONLY_RESIDUE),
            "the registered emitter-only residue drifted")
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

    require(node.get("runner_default_route") == RUNNER_DEFAULT_ROUTE and
            node.get("runner_default_unpinned_callers") ==
            list(RUNNER_DEFAULT_UNPINNED_CALLERS),
            "the registered runner-default residue drifted")
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
            "the guard recipes are no longer defined in the justfile")
    check_contract_runs_unconditionally()
    check_workflow_triggers_on_fixtures(vectors)
    check_e2e_mutation_evidence(vectors)
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
        f"`{EXCLUDED_OWNER}` retires them. The unqualified \"zero parity",
        "guards execute live C\" gate does **not** close there: the Python",
        f"guards named above outlive it. Patch `{UNQUALIFIED_GATE_OWNER}`",
        "converts those eight and widens the measured population to include",
        "`scripts/*.py`, and that is where the unqualified gate closes.",
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
        "## End-to-end mutation evidence",
        "",
        "`validate_mutations` tampers with every vector and asserts the",
        "materialized bytes move with it. That proves `materialize`",
        "transcribes its input faithfully, which is the first arrow of",
        "`vector -> materialize -> guard reads artifacts -> guard asserts`,",
        "and it is not the same claim as \"a converted guard would fail if",
        "the vector were wrong\".",
        "",
        "Two ways that could go wrong are rejected before those mutations",
        "run, because the evidence guard runs the contract first. Both were",
        "confirmed by mutating the harness rather than by reading it:",
        "",
        "- dropping the re-pointed comparison from",
        "  `scripts/phase13_registry_differential.sh` fails",
        "  `check_presence_rewrites`;",
        "- removing that harness's native arm fails",
        "  `check_native_arm_split`.",
        "",
        "Neither covers an assertion that is present and does not fire. That",
        "needs a guard run against a wrong vector, which is what",
        f"`{E2E_PROBE.relative_to(ROOT)}`",
        "does: it shadows the frozen manifest with a bind mount inside a",
        "mount namespace, runs the guard on the tampered copy and then on the",
        "pristine one, and requires it to fail and then pass. Fail alone is",
        "not enough — a guard that is red for an unrelated reason also fails",
        "on a mutated vector, which would let a dead guard certify the loop",
        "closed. A failure that does not name the assertion under test is",
        "reported as its own verdict rather than counted as evidence.",
        "",
    ]
    for row in E2E_MUTATION_EVIDENCE:
        lines += [
            f"### `{row['guard']}` — {row['verdict']}",
            "",
            f"- Consumer: `{row['harness']}`",
            f"- Vector: `{row['vector']}`",
            f"- Mutation: `{row['mutation']}`",
            f"- Assertion required to fire: `{row['expect']}`"
            f" (`{row['comparison']}`)",
            f"- Legs: mutate `rc={row['mutate_leg_rc']}`, "
            f"pass `rc={row['pass_leg_rc']}`",
            f"- Measured: `{row['measured']}`",
            f"- Why this pairing: {row['why']}",
            "",
        ]
    lines += [
        "### Consumers found blind",
        "",
        "The probe is not free of findings, and the first candidate it ran",
        "was one. These are recorded rather than dropped:",
        "",
    ]
    for row in E2E_BLIND_CONSUMERS:
        lines += [
            f"- `{row['guard']}` — {row['verdict']}. "
            f"Mutation `{row['mutation']}` on `{row['vector']}`; "
            f"{row['control']}. Cause: {row['cause']}. "
            f"Scope: {row['residual']}. Tracked by {row['tracked_by']}.",
        ]
    lines += [
        "",
        "### What this does not claim",
        "",
        f"{len(E2E_MUTATION_EVIDENCE)} of the `{node['vector_count']}`",
        "vectors was driven end-to-end through a real guard. That proves the",
        "sampled guards compare what they materialize and says nothing about",
        "the rest. The sample was chosen by risk — a guard that executes the",
        "harness rewritten in this patch, mutating the comparison the rewrite",
        "re-pointed — not by convenience.",
        "",
        E2E_UNCOVERED,
        "",
        "The probe is committed and runnable but is wired into no workflow.",
        "It depends on unprivileged user namespaces, for which this",
        "repository has no precedent, and `require_namespace_support` fails",
        "loudly rather than skipping, so placing it in CI is a decision that",
        "waits on measuring namespace availability on a runner. Until then",
        "the rows above attest to a measured past state; what keeps them",
        "honest is that `validate` checks each one against the probe and",
        "against the harness it names, so a row cannot outlive the assertion",
        "it describes.",
        "",
    ]
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



# ---------------------------------------------------------------------------
# The digest check has to be reachable without a paths filter.
#
# `check_vector` compares each of the 253 frozen vectors against the digest of
# the source it was captured from, and a vector is only sound if that source
# has not moved. But the contract guard that runs it was invoked from exactly
# one workflow, `phase24-frozen-oracle.yml`, and that workflow's paths filter
# lists the vector manifest and the tooling — not one of the 253 fixtures. So
# editing a fixture triggered nothing that checked its digest, and the fixture
# drifted from its frozen expectation with CI green.
#
# The fix is not to enumerate 253 paths into the filter: that is a second
# instance of the same defect, an enumeration claiming coverage over a
# population it does not contain, needing hand-maintenance forever. It is to
# run the contract from a workflow that has no filter to forget. This assertion
# is what keeps it there — without it the fix is a state, not an invariant, and
# the next person to add a paths filter recreates the hole silently.
#
# Parsed by indentation rather than with PyYAML deliberately: no script in
# scripts/ imports yaml and PR Fast does not install it, so a yaml dependency
# here would make the oracle's own contract unrunnable in the workflow this
# check exists to put it in.
# ---------------------------------------------------------------------------

WORKFLOW_DIR = ROOT / ".github/workflows"


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def unconditional_pr_workflows() -> list[Path]:
    """Workflows that run on every pull request, with no paths filter.

    `pull_request:` with no sub-keys is the trap here: it parses as `None` and
    means "every pull request", which is indistinguishable from an absent key
    if you test for a mapping and skip falsey values. That mistake produced two
    different wrong answers during this patch — one derivation said there were
    no unconditional workflows, another said five. Treating `None` as "no paths
    filter", which is what it means, gives two.
    """
    found: list[Path] = []
    for path in sorted(WORKFLOW_DIR.glob("*.y*ml")):
        lines = path.read_text(encoding="utf-8").split("\n")
        trigger: list[str] = []
        depth = None
        for line in lines:
            if depth is None:
                if re.match(r"^(on|\"on\"|'on'):", line):
                    depth = 0
                continue
            if line.strip() == "" or line.lstrip().startswith("#"):
                continue
            if _indent(line) <= depth:
                break
            trigger.append(line)
        if depth is None:
            continue
        pr_indent = None
        filtered = False
        for line in trigger:
            if pr_indent is None:
                if re.match(r"^\s*pull_request:", line):
                    pr_indent = _indent(line)
                continue
            if _indent(line) <= pr_indent:
                break                      # the pull_request block ended
            if re.match(r"^\s*paths(-ignore)?:", line):
                filtered = True
                break
        if pr_indent is not None and not filtered:
            found.append(path)
    return found


def check_contract_runs_unconditionally() -> None:
    unconditional = unconditional_pr_workflows()
    require(unconditional,
            "no workflow triggers on pull_request without a paths filter, so "
            "nothing can validate the frozen digests unconditionally")
    runners = [path.name for path in unconditional
               if f"just {GUARD_L1}" in path.read_text(encoding="utf-8")]
    require(runners,
            f"{GUARD_L1} is not invoked by any workflow that runs on every "
            f"pull request (unfiltered workflows: "
            f"{', '.join(p.name for p in unconditional)}). Every frozen "
            f"vector's source_sha256 is then checked only when a paths filter "
            f"happens to match, and a fixture can drift from the digest it was "
            f"frozen against with CI green.")


# ---------------------------------------------------------------------------
# The dedicated workflow has to fire for the files the digest check reads.
#
# `check_contract_runs_unconditionally` above puts the digest check on every
# pull request through PR Fast, which is the guarantee that does not depend on
# a list. This check covers the dedicated workflow, whose Level 2 evidence job
# PR Fast does not run: a fixture-only pull request should trigger it and did
# not, because the paths filter named the vector manifest and the tooling and
# not one of the 253 sources those vectors are digests of.
#
# What matters is that the patterns are checked against the population rather
# than asserted over it. An enumeration claiming coverage it does not have is
# the defect this patch keeps finding, so the filter is compared against every
# `source_fixture` in the manifest, and a fixture in a directory no pattern
# reaches fails here — when it is added, not the first time it silently drifts.
# ---------------------------------------------------------------------------

def workflow_pull_request_paths(path: Path) -> list[str]:
    """The `paths:` entries under this workflow's `pull_request:` trigger."""
    depth = None
    trigger: list[str] = []
    for line in path.read_text(encoding="utf-8").split("\n"):
        if depth is None:
            if re.match(r"^(on|\"on\"|'on'):", line):
                depth = 0
            continue
        if line.strip() == "" or line.lstrip().startswith("#"):
            continue
        if _indent(line) <= depth:
            break
        trigger.append(line)
    pr_indent = None
    paths_indent = None
    found: list[str] = []
    for line in trigger:
        if pr_indent is None:
            if re.match(r"^\s*pull_request:", line):
                pr_indent = _indent(line)
            continue
        if _indent(line) <= pr_indent:
            break                          # the pull_request block ended
        if paths_indent is None:
            if re.match(r"^\s*paths:", line):
                paths_indent = _indent(line)
            continue
        if _indent(line) <= paths_indent:
            break                          # the paths list ended
        entry = line.strip()
        if entry.startswith("- "):
            found.append(entry[2:].strip().strip("'\""))
    return found


def filter_pattern_matches(pattern: str, candidate: str) -> bool:
    """GitHub's filter-pattern semantics for the subset this filter uses.

    `*` stops at a path separator and `**` does not, which is the whole
    difference that decides whether `compiler/future/` is covered. `**` may
    also match zero segments, so `a/**/b.gst` matches `a/b.gst`; the filter
    lists the bare `a/*.gst` form alongside it anyway, so coverage does not
    rest on that reading of the pattern.
    """
    parts: list[str] = []
    segments = pattern.split("/")
    for index, segment in enumerate(segments):
        last = index == len(segments) - 1
        if segment == "**":
            # Whole segments, including none, and it carries its own trailing
            # separator so `a/**/b` still matches `a/b`.
            parts.append(".*" if last else "(?:[^/]+/)*")
            continue
        parts.append("".join("[^/]*" if char == "*" else re.escape(char)
                             for char in segment))
        if not last:
            parts.append("/")
    return re.fullmatch("".join(parts), candidate) is not None


def check_workflow_triggers_on_fixtures(vectors: dict) -> None:
    patterns = workflow_pull_request_paths(WORKFLOW)
    require(patterns,
            f"{WORKFLOW.name} has no pull_request paths filter to read. If it "
            f"was removed the workflow now runs on every pull request, which "
            f"is safe, but this check no longer measures anything and should "
            f"be retired rather than left passing vacuously.")
    sources = {str(vector["source_fixture"])
               for vector in vectors["vectors"].values()}
    uncovered = sorted(source for source in sources
                       if not any(filter_pattern_matches(pattern, source)
                                  for pattern in patterns))
    require(not uncovered,
            f"{len(uncovered)} of {len(sources)} frozen source fixtures are "
            f"outside {WORKFLOW.name}'s pull_request paths filter, so editing "
            f"one triggers nothing that checks its digest: "
            f"{', '.join(uncovered[:5])}"
            f"{f' (+{len(uncovered) - 5} more)' if len(uncovered) > 5 else ''}")


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
        # v1 and the v2 capture are both proven falsifiable, and the two
        # counts are reported separately. A capture that is servable but never
        # mutated is the #399 shape again -- an observable nothing can
        # contradict -- so v2 does not get to inherit v1's evidence.
        checked = validate_mutations(load_vectors())
        servable = load_servable_vectors()
        second = {"vectors": {k: v for k, v in servable["vectors"].items()
                              if k not in load_vectors()["vectors"]}}
        captured = validate_mutations(second) if second["vectors"] else 0
        # Patch 24.12b (#412): stderr joins the named arms. It is named here
        # because this line is the only place the covered set is stated, and
        # an arm that runs but is not named reads as absent.
        print(f"{GUARD_L2}: {checked} v1 + {captured} v2 frozen vectors are "
              f"falsifiable (exit, stdout, stderr, moved source, changed "
              f"kind, unknown id)")
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
        # State the covered counts rather than leaving them implicit: an
        # unstated split reads as full coverage to anyone who sees "ok"
        # (#399, the 34-of-253 lesson). The Python population is derived,
        # so its size is a measurement and belongs in the summary.
        population = check_python_population()
        print(f"{GUARD_L1}: ok "
              f"({node['vector_count']} vectors, "
              f"{node['archived_corpus_linked_vectors']} archived-corpus "
              f"linked, {len(FROZEN_LOCI)} harnesses and "
              f"{len(FROZEN_RECIPES)} recipes free of live C; "
              f"{population['population']} Python loci build a retired-backend "
              f"argv = {population['pending']} pending conversion + "
              f"{population['excluded']} registered exclusions)")


if __name__ == "__main__":
    main()
