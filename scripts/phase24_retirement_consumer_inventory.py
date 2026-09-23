"""Patch 24.11: generated-C consumer and route inventory.

Report-only and static: no compiler build, no test execution. Enumerates
every remaining live generated-C route, caller, guard, registry row,
workflow, command, package/release reference, fixture, and artifact on
current main, with the owning removal patch and a live falsifier per row.

A row is live evidence, not a census of history: closed-phase records,
frozen authorities, and the generated seed keep their MIR-to-C mentions and
are out of scope here. What is inventoried is anything a removal patch
(24.12-24.18) or Phase 25 must touch, convert, or delete.

Falsifiability: every row carries a check against the live tree. Deleting,
converting, or adding a live C route without updating the registered rows
fails `validate`. The removal patches register their moves here as they
land; an unregistered move is the failure this inventory exists to catch.

Line numbers are display only, never digest inputs (Patch 24.3b): rows are
keyed by file, recipe/command identity, and meaning.
"""

import argparse
import copy
import hashlib
import importlib.util
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts" / "cranelift_feature_registry.json"
LEVELS = ROOT / "scripts" / "cranelift_test_levels.json"
TASK = ROOT / "TASK.md"
VIEW = ROOT / "docs" / "PHASE24_RETIREMENT_CONSUMER_INVENTORY.md"

GUARD = "guard-cranelift-phase24-retirement-consumer-inventory-contract"
VERSION = "phase24_retirement_consumer_inventory_v1"
STATUS = "patch24_11_complete"
BASE_MAIN = "b7b1713cd65630b14ae92e46afd393990928a2e2"

JUSTFILE_FRAGMENTS = [
    "justfile",
    "justfile-reports",
    "justfile-step44",
    "justfile-step45",
    "justfile-step51",
    "justfile-step52",
]

# User-facing C selection spellings. The sweep counts these in execution
# loci only (Makefile, justfile set, scripts/*.sh, tests/*.gst,
# compiler/*.gst). Historical mentions in docs, closed validators, generated
# views, and the seed are frozen records, not routes, and are out of scope.
BACKEND_SPELLING = re.compile(r"--backend (?:mir-to-c|c(?=[\s]|$))")

RECIPE_HEAD = re.compile(r"^([A-Za-z0-9_-]+)([^:]*):")


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD}: {message}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def digest(value: object) -> str:
    return hashlib.sha256(
        json.dumps(value, sort_keys=True).encode("utf-8")).hexdigest()


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def recipe_bodies() -> dict[str, str]:
    """Every just recipe body across the merged justfile namespace."""
    bodies: dict[str, str] = {}
    for fragment in JUSTFILE_FRAGMENTS:
        current: str | None = None
        for line in read(fragment).split("\n"):
            if line[:1] in (" ", "\t"):
                if current is not None:
                    bodies[current] += line + "\n"
                continue
            match = RECIPE_HEAD.match(line)
            if match:
                current = match.group(1)
                bodies.setdefault(current, "")
    return bodies


# ---------------------------------------------------------------------------
# Bootstrap-entry decision (Patch 24.11 decides, Patch 24.13 lands).
#
# Measured on the authority base: no distinct internal entry exists. All five
# Makefile bootstrap callers reach the emitter through the user-facing
# `--backend mir-to-c` selection (compiler/test_runner_entry.gst:99-113,
# emitting at :456). The stage-one bridge entry parses the same spellings
# but emits C unconditionally through its direct call (:269); it is
# bootstrap-scoped already and stays as is under Phase 25.
# ---------------------------------------------------------------------------

BOOTSTRAP_ENTRY_DECISION = {
    "status": "patch24_11_decided_patch24_13_lands",
    "current_state": "no_distinct_internal_entry",
    "current_callers": {
        "makefile_cli_spelling_callers": [
            "Makefile:55",
            "Makefile:112",
            "Makefile:143",
            "Makefile:241",
            "Makefile:245",
        ],
        "selection": "user-facing --backend mir-to-c",
        "dispatch": "compiler/test_runner_entry.gst:99-113",
        "emitter": "compiler/test_runner_entry.gst:456",
    },
    "selected_entry": "--backend bootstrap-emitter",
    "selected_dispatch": "existing MirToC tag, new spelling branch only",
    "rejected": {
        "environment_variable":
            "invisible to review and spoofable; Phase 10 precedent keeps "
            "explicit selection explicit",
        "entry_file_gating":
            "filename-selected meaning, rejected by the preflight invariant",
        "keeping_mir_to_c_for_bootstrap":
            "leaves a user-facing spelling reaching the emitter after "
            "removal; the 24.13 falsifier could not distinguish bootstrap "
            "from ordinary use",
    },
    "advertised_in_help": False,
    "falsifiers": [
        "--backend mir-to-c and --backend c reject with unknown backend",
        "help output names no C backend",
        "exactly the five Makefile caller lines use the internal spelling "
        "and no other tracked file does",
        "bootstrap still converges stage2==stage3 through the entry",
    ],
}

# ---------------------------------------------------------------------------
# Registered rows. Fields: id, path(s), kind, owner_patch, action, detail,
# check, falsifier. `owner_patch` is the patch that takes the row out of
# live state: 24.12 converts/retires live differentials, 24.13 removes
# selection and migrates test routes to native, 24.14 removes C toolchain
# plumbing, 24.15 retires packages/docs/registry, 24.16 audits residue,
# 25 removes the bootstrap chain and the emitter, stdlib-coordination rows
# are migrated by the Stdlib lane with the 23.11 corpus provided by 24.12.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Rows a later patch has already taken out of live state.
#
# Every row's falsifier is "this row is still live". That is the right check
# while the row is live and exactly the wrong one afterwards: the moment a
# removal or conversion patch lands, an unrevised inventory asserts the work
# never happened, and the guard that was meant to prove progress blocks it
# instead. So a taken-out row records the patch that took it and what must be
# true now, and its falsifier inverts — putting the C route back fails just as
# loudly as never removing it did.
#
# Residual counts are explicit rather than assumed zero: the phase12.5 route
# harness keeps one `--backend mir-to-c` spelling, a probe asserting the route
# is *refused*, which compiles and runs nothing and so has no observable to
# freeze.
# ---------------------------------------------------------------------------

TAKEN_OUT_BY = "24.12"
FROZEN_ORACLE_CALL = "phase24_frozen_oracle.py materialize"

# recipe id -> why Patch 24.13 routed it to the SURVIVING backend rather than
# to the frozen oracle.
#
# A third disposition was needed. TAKEN_OUT_RECIPES asserts a recipe's C route
# is gone AND that it now reaches the frozen oracle; these three reach the
# native route instead, because what they assert is still directly observable
# there -- acceptance, rejection, and compile-and-run. Checking them against
# the frozen-oracle branch would demand an oracle call they should not make,
# and the "else" branch demands the C route still be present, so without this
# the conversion fails whichever way it is scored.
#
# guard-compile-pass and guard-compile-fail were scored 24.16/retire. That
# ownership was assigned before it was known that 24.13's removal BREAKS them:
# they drive the spelling this patch turns into a rejection, so leaving them to
# 24.16 ships ~82 guard invocations that cannot run. Re-scored to 24.13 with
# the reason recorded, not moved silently.
# Patch 24.13 routed these to the bootstrap-only entry. Patch 24.14 renamed
# the set it inherited to NATIVE_ROUTED_RECIPES and repopulated it with the
# recipes IT routes natively, which silently dropped 24.13's population --
# make-test-suite then fell through to the branch demanding a retired C
# route it no longer has. Both routings are real and both stay asserted.
# Patch 25.10c emptied this set. All three rows moved: one to
# NATIVE_ROUTED_RECIPES and two to DELEGATED_ROUTE_RECIPES below.
#
# The rows said these recipes compiled tests/test_runner.gst, "which the
# native route defers on (phase13_generic_source_to_mir)". That is still
# true of the RUNNER and is not why they were stuck. Measured over all 324
# corpus cases: 117 of 120 tests/ positives have no native route, but 92 of
# 94 compiler/*_test_entry.gst positives compile natively, and the
# aggregate-parameter capability everyone was waiting on is 3 of 216. The
# recipes did not need that capability; two of them did not need the runner.
#
# Kept as an empty register rather than deleted, with its needle, because the
# assertion below is what stops a C route coming BACK, and a set that no
# longer exists cannot refuse a new member.
BOOTSTRAP_ROUTED_RECIPES: dict[str, str] = {}
BOOTSTRAP_ROUTE_NEEDLE = "--backend bootstrap-emitter"


# Patch 25.10c: recipes that select NO backend, because they delegate to one.
#
# make-test-suite and its parallel form used to emit the runner's C and host
# compile it. They now call phase21_complete_guard_suite.py's evidence arm,
# which compiles the SAME case list -- parsed out of the same file by
# runner_cases() -- on the native route, and which three CI workflows already
# run. make-test-suite was the local-only duplicate of that coverage.
#
# So they hold neither needle: not the retired spelling, and not
# --backend cranelift either, because the backend is chosen one level down.
# This is a separate register rather than two more rows in
# NATIVE_ROUTED_RECIPES because that set asserts a recipe SELECTS the native
# route BY NAME. A delegating recipe would have to spell a backend it does
# not invoke to satisfy it, and a guard satisfied by a fake spelling is worse
# than one that admits the third case exists.
DELEGATED_ROUTE_RECIPES = {
    "make-test-suite":
        "delegates the corpus to the phase21 evidence arm, which classifies "
        "all 324 cases on the native route; the 117 tests/ positives with no "
        "native route lose EXECUTION and are checked against frozen reason "
        "codes instead, which is the recorded loss",
    "make-test-suite-parallel":
        "the parallel form, delegating identically; the two differ only in "
        "which guard pass runs first, so they must not differ in backend",
}
DELEGATED_ROUTE_NEEDLE = "guard-cranelift-phase21-complete-guard-suite-evidence"


NATIVE_ROUTED_RECIPES = {
    "run-step52-positive-batch":
        "Patch 25.10c: becomes the native build its own 24.13 comment "
        "predicted, though not by the predicted mechanism. It waited on "
        "phase13_generic_source_to_mir; what actually freed it is that the "
        "eight compiler test entries it pins never needed the runner, and "
        "all eight compile AND run natively today, verified individually",
    "guard-positive":
        "compile-and-run, measured: 101 of 105 sources compile and run with "
        "exit 0 on the native route; the four that do not are named in the "
        "recipe with the reason code the compiler reports",
    "guard-compile-pass":
        "acceptance: 17 of 25 sources stop at decision=deferred with no "
        "front-end error, so the recipe asserts acceptance directly rather "
        "than inferring it from a successful C emission",
    "guard-compile-fail":
        "rejection is backend-independent; all 49 sources still reject with "
        "their registered diagnostic",
}
NATIVE_ROUTE_NEEDLE = "--backend cranelift"

# recipe id -> why Issue #398 served it from the frozen oracle.
#
# A fourth disposition, and a separate register rather than three more rows
# in TAKEN_OUT_RECIPES, because that set records what Patch 24.12 did and
# these three are not 24.12's. They are the Stdlib-owned recipes the deferral
# left behind: Patch 24.13 could not convert them (AGENTS.md line 98 puts
# them in the other lane's ownership) and its removal broke them where they
# stood, which is why it was withdrawn.
#
# The assertions are the same as TAKEN_OUT_RECIPES': the C route must be gone
# AND the recipe must reach the frozen oracle. Both halves, so a recipe that
# simply stopped compiling anything cannot pass as a converted one.
ISSUE398_CONVERTED_RECIPES = {
    "guard-stdlib-s1-str-equality-diagnostic":
        "asserts the text of a diagnostic and of the emitted C, both of "
        "which the frozen record carries",
    "guard-stdlib-s1-collection-receivers":
        "compares emitted C across receiver forms; the comparison is between "
        "two recordings rather than two compilations",
    "guard-stdlib-s1-resource-prerequisites":
        "Patch 24.0c's relay site, whose one invocation is registered as "
        "retired in phase398_retained_spelling_removal.relay_site_retirement",
}
ISSUE398_CONVERTED_BY = "#398"

# recipe id -> what Patch 24.12 did to it
TAKEN_OUT_RECIPES = {
    "guard-cranelift-phase11-scalar-expression-parity": "convert",
    "guard-cranelift-phase11-local-state-parity": "convert",
    "guard-cranelift-phase11-structured-cfg-parity": "convert",
    "guard-cranelift-phase11-block-parameter-loop-parity": "convert",
    "guard-cranelift-phase11-direct-call-abi-parity": "convert",
    "guard-cranelift-phase11-module-import-runtime-parity": "convert",
    "guard-cranelift-phase11-metadata-diagnostic-parity": "convert",
    "guard-mir-feature-return-int-preservation": "convert",
    "guard-mir-feature-local-binding-read-preservation": "convert",
    "guard-mir-feature-if-else-return-int-preservation": "convert",
    "guard-mir-feature-local-binding-read-provenance-metadata-preservation": "convert",
    # These two are closure guards that `rg -F` for the exact
    # live-C spellings inside the Phase 13 differential harness,
    # so converting that harness made them red. 24.16 was to
    # retire them; 24.12 had to rewrite them to the spelling that
    # now carries the same obligation, so it owns them.
    "guard-cranelift-phase12-5-close": "rewrite",
    "guard-cranelift-phase13-close": "rewrite",
}

# harness path -> live `--backend` spellings it may still carry
TAKEN_OUT_HARNESSES = {
    "scripts/phase12_5_route_architecture.sh": 1,
    "scripts/phase13_broader_imported_runtime_calls.sh": 0,
    "scripts/phase13_capability_deferral.sh": 0,
    "scripts/phase13_direct_call_graph.sh": 0,
    "scripts/phase13_general_loop.sh": 0,
    "scripts/phase13_multiple_locals_assignments.sh": 0,
    "scripts/phase13_nested_structured_cfg.sh": 0,
    "scripts/phase13_parameter_argument.sh": 0,
    "scripts/phase13_registry_differential.sh": 0,
    "scripts/phase13_scalar_expression.sh": 0,
    "scripts/phase13_source_metadata.sh": 0,
    "scripts/phase14_composition_differential.sh": 0,
    "scripts/phase15_resource_composition_parity.sh": 0,
    "scripts/phase16_abi_composition_parity.sh": 0,
    "scripts/phase19_composition_parity.sh": 0,
    "scripts/phase19_representation_parity.sh": 0,
    "scripts/phase20_arena_free.sh": 0,
    "scripts/phase20_contextual_generic_constructor.sh": 0,
    "scripts/phase20_cross_feature_qualification.sh": 0,
    "scripts/phase20_exact_brand_boundary.sh": 0,
    "scripts/phase20_generic_guard_prerequisites.sh": 0,
    "scripts/phase20_inert_resource_surface.sh": 0,
    "scripts/phase20_long_lived_concurrent.sh": 0,
    "scripts/phase20_nested_brand_annotation.sh": 0,
    "scripts/phase20_protected_access_liveness.sh": 0,
    "scripts/phase20_resource_acquisition.sh": 0,
    "scripts/phase20_resource_enforcement.sh": 0,
    "scripts/phase20_resource_scope_cleanup.sh": 0,
    "scripts/phase20_stdlib_runtime_differential.sh": 0,
    "scripts/phase20_whole_program_corpus.sh": 0,
    "scripts/phase21_collection_string_native_source.sh": 0,
    "scripts/phase21_cross_tenant_capability.sh": 0,
    "scripts/phase21_filesystem_allocation_native_source.sh": 0,
    "scripts/phase21_od8_adversarial_verdict.sh": 0,
    "scripts/phase21_opening.sh": 0,
    "scripts/phase21_per_root_obligations.sh": 0,
    "scripts/phase21_resource_sync_native_source.sh": 0,
    "scripts/phase21_trusted_scope_provenance.sh": 0,
    "scripts/phase21_typed_query_noop_surface.sh": 0,
}

# harness path -> (patch that owns it instead, why 24.12 did not)
#
# Patch 24.13: empty, and that is the statement. Every row here named 24.13 as
# the patch that would handle it, so the register discharges when 24.13 lands
# rather than being carried forward. The rows move to DISCHARGED_HARNESSES,
# which asserts the opposite of what the deferral did: the deferral required
# the harness still have a C route, and the discharge requires it either have
# none or say in the file why the survivors are not live-C arms.
DEFERRED_HARNESSES: dict[str, tuple[str, str]] = {
}

# harness path -> (patch that discharged it, what survives and why)
#
# Each reason is a property the tree can contradict, checked below: a harness
# at zero must be at zero, and a harness with survivors must carry the Phase 24
# removal marker -- the string its own inverted assertions grep for. A harness
# that simply dropped its C route without inverting anything has neither, and
# fails.
# Compared case-insensitively: the harnesses spell it both "REMOVED in
# Phase 24" (help text) and "removed in Phase 24" (rejection text).
#
# Lost in the 24.13/24.14 merge: the definition sat in a hunk resolved to
# 24.14's side while its consumer below came from main's. `validate` never
# reaches that branch, so it read clean -- the undefined-name sweep is what
# caught it, which is exactly the runtime-in-evidence-paths case it exists
# for.
REMOVAL_MARKER = "removed in phase 24"

# Harnesses Issue #398 converted onto frozen replay, and the spellings each
# has left. Kept apart from TAKEN_OUT_HARNESSES because that register records
# what Patch 24.12 did; these three are the Stdlib-owned harnesses the
# deferral left behind. Same both-halves rule: the registered count AND a
# frozen-oracle call, so a harness that simply stopped comparing anything
# fails rather than reading as converted.
ISSUE398_CONVERTED_HARNESSES = {
    "scripts/stdlib_s1_branded_collections_parity.sh": 0,
    "scripts/stdlib_s1_clone_destination_parity.sh": 0,
    "scripts/stdlib_s1_composition_parity.sh": 0,
    # Found by the C-toolchain provenance guard rather than by any invocation
    # census: this harness made four live-C calls that every census projected
    # away as appended Stdlib rows, so "28 registered live-C cases" never
    # counted them. The removal would have broken it in CI. Converted here
    # with the rest -- all seven of its fixtures already had v3 vectors of
    # exactly the right kinds, so it needed no new capture.
    "scripts/stdlib_s1_mutex_guard_scope_parity.sh": 0,
}

# Harnesses that KEEP a spelling because they invert it: the invocation is
# still made, in order to assert that it is refused. The count alone cannot
# tell that from a live consumer, so the removal marker is required too --
# a probe that drifted back to expecting success loses it.
ISSUE398_INVERTED_HARNESSES = {
    "scripts/phase22_opening.sh": 1,
}

# Harnesses that reached the retired backend through the shared runner rather
# than by spelling `--backend`, so no invocation census ever saw them and the
# "28 registered live-C cases" figure never counted them. The C-toolchain
# provenance guard found the first; the rest came from the runner-pinned
# family this inventory already tracked.
#
# Their family counts occurrences of the string "mir-to-c", which after the
# conversion is mostly file names -- a number that would go up and down
# without meaning anything. So these three are measured on what actually
# matters instead: exactly ONE place still asks the runner for the retired
# route, that place asserts the request is refused, and the evidence the
# route used to produce is replayed from the frozen oracle. A harness that
# went back to asking for the route twice, or stopped asserting the refusal,
# or dropped the replay, each fails a different one of the three.
ISSUE398_RUNNER_CONVERTED = {
    "scripts/stdlib_s1_migration_parity.sh": 1,
    "scripts/stdlib_s1_mutex_guard_fibers_parity.sh": 1,
    "scripts/stdlib_s1_mutex_guard_parity.sh": 1,
}
RETIRED_ROUTE_REQUEST = "GUST_RUNNER_ROUTE=mir-to-c"
RETIRED_ROUTE_REFUSAL = "which was removed in Phase 24"


DISCHARGED_HARNESSES: dict[str, tuple[str, str]] = {
    "scripts/phase22_default_native_package.sh":
        ("24.13", "every live-C arm retired; nothing survives"),
    # phase22_explicit_c_migration.sh and phase22_opening.sh were listed here
    # on the premise that their surviving live-C arms had been INVERTED into
    # assertions that the spelling is rejected, and withdrawn when that
    # removal was deferred. Issue #398 performs it and the arms are inverted
    # for real -- but the rows stay out of this register, because neither
    # harness is DISCHARGED. phase22_opening.sh still makes one invocation,
    # registered in ISSUE398_INVERTED_HARNESSES with its removal marker.
    # "Discharged" means nothing survives; "inverted" means something
    # survives and asserts the opposite. Collapsing the two is what this
    # register exists to prevent.
    "scripts/phase22_native_implicit_output.sh":
        ("24.13", "every live-C arm retired; nothing survives"),
    "scripts/phase22_postflip_qualification.sh":
        ("24.13", "every live-C arm retired; nothing survives"),
}

# Patch 24.13 removed compiler/test_runner_entry.gst from this set: it no
# longer carries a live C route, and RETIRED_FILE_SURFACES asserts the
# surfaces it lost stay gone.
# Patch 24.13 dropped justfile-step51: its three generic recipes were routed
# to the surviving backend, so the file carries no live C route at all --
# dropped rather than pinned at zero, because a zero pin keeps asserting a
# sweep over a file with nothing to sweep.
#
# compiler/test_runner_entry.gst stays in the LOCUS list under Issue #398
# even though its count left SWEEP_COUNTS. The two are different statements:
# the locus list is where the sweep looks, and the count list is what it
# expects to find. The entry now carries no backend spelling, so check_sweep
# emits no row for it and a count would expect a key that never appears --
# but it is exactly the file where one coming back matters most, so it stays
# in the population that gets looked at.
SWEEP_LOCI = ["Makefile", "justfile", "compiler/test_runner_entry.gst"]

# Exact per-file spelling counts for sweep loci with more than one shape.
# Single-shape loci are pinned by their row checks; the sweep asserts the
# total per file so a new C route in a known file still fails.
SWEEP_COUNTS = {
    # Issue #398 removed both spellings from the compiler entry and the
    # runner's C arm with them, so neither file carries a backend spelling
    # any more and check_sweep -- which reports only loci WITH hits -- stops
    # producing a row for either. Dropped rather than pinned at zero, for the
    # reason spelled out for the Makefile below: a zero pin expects a key the
    # sweep can never emit.
    #
    # The claim is not lost. The compiler entry's spellings are asserted
    # absent in RETIRED_FILE_SURFACES and its rejection block is pinned by
    # phase22_explicit_c_migration.py; the runner is required to carry no
    # mir-to-c invocation and exactly one refusal by
    # phase23_production_release_audit.py.
    # Patch 24.13: 5 -> 3. Two Makefile bootstrap callers moved to the
    # bootstrap-only entry; the remaining three are driven by the seed and the
    # bridge parser, which this patch does not touch and Phase 25 owns.
    # Patch 24.13 moved all five Makefile bootstrap callers to the
    # bootstrap-only entry, so the Makefile carries no retired spelling at
    # all and check_sweep -- which reports only loci WITH hits -- stops
    # producing a row for it. Expecting a count here would expect a key the
    # sweep can never emit.
    #
    # The claim is not lost, it moved to checks that assert it directly:
    # phase22_postflip_qualification requires all five callers on the entry
    # and no seed driver spelling the retired backend,
    # phase23_production_release_audit records phase25_bootstrap_explicit_c
    # _count at zero, and phase22_default_route_seed_convergence inverts
    # each of the four rows -- retired absent AND replacement present.
    # Patch 24.13 removed this locus entirely -- the help line went and the
    # selection branch became a rejection, so the file no longer carries a
    # live C route. It is dropped from SWEEP_LOCI rather than pinned at zero,
    # because a zero pin would keep asserting a sweep over a file with nothing
    # to sweep.
    # 38 before Patch 24.12; the conversion took 22 out (7 phase11 and 4
    # mir-feature parity recipes, and the live-C literals three closure
    # guards required the Phase 13 differential harness to still contain).
    # Issue #398: 9 -> 1. Eight Stdlib-owned invocations across three guard
    # recipes now replay a frozen record. The one that remains is
    # Cranelift-owned.
    "justfile": 1,
    # Issue #398 converted all four cases onto frozen replay, so this locus
    # leaves the sweep too. An earlier draft pinned it at zero on the grounds
    # that it is still a live harness worth a falsifier -- true, but a zero
    # pin is not that falsifier, because the sweep never emits a key for a
    # file with no hits. The falsifier it actually needs is the
    # MIGRATED_FILE_SURFACES row, which requires the retired command absent
    # AND the frozen replay present.
    # Patch 24.13 migrated both invocations to the bootstrap-only entry;
    # both halves of the move are asserted in MIGRATED_FILE_SURFACES.
    # Patch 24.13 retired the runner's mir-to-c route; the surface is
    # asserted absent in RETIRED_FILE_SURFACES instead of counted here.
}

# Differential .sh harness families: exact file set with per-file hit
# counts. Phase suffix selects the owner: live differentials convert under
# 24.12, closed-phase evidence retires under 24.12 as superseded live-C
# execution, Stdlib-owned harnesses migrate under stdlib-coordination.
SH_FAMILIES = {
    "early-differential": {
        "owner_patch": "24.12",
        "action": "convert",
        "files": {
            "scripts/phase12_5_route_architecture.sh": 2,
            "scripts/phase13_broader_imported_runtime_calls.sh": 2,
            "scripts/phase13_capability_deferral.sh": 2,
            "scripts/phase13_direct_call_graph.sh": 2,
            "scripts/phase13_general_loop.sh": 2,
            "scripts/phase13_multiple_locals_assignments.sh": 2,
            "scripts/phase13_nested_structured_cfg.sh": 2,
            "scripts/phase13_parameter_argument.sh": 2,
            "scripts/phase13_registry_differential.sh": 2,
            "scripts/phase13_scalar_expression.sh": 2,
            "scripts/phase13_source_metadata.sh": 2,
            "scripts/phase14_composition_differential.sh": 2,
        },
    },
    "phase15-16-composition": {
        "owner_patch": "24.12",
        "action": "convert",
        "files": {
            "scripts/phase15_resource_composition_parity.sh": 2,
            "scripts/phase16_abi_composition_parity.sh": 2,
        },
    },
    "phase19-parity": {
        "owner_patch": "24.12",
        "action": "convert",
        "files": {
            "scripts/phase19_composition_parity.sh": 2,
            "scripts/phase19_representation_parity.sh": 1,
        },
    },
    "phase20-evidence": {
        "owner_patch": "24.12",
        "action": "convert",
        "files": {
            "scripts/phase20_arena_free.sh": 4,
            "scripts/phase20_contextual_generic_constructor.sh": 3,
            "scripts/phase20_cross_feature_qualification.sh": 2,
            "scripts/phase20_exact_brand_boundary.sh": 3,
            "scripts/phase20_generic_guard_prerequisites.sh": 2,
            "scripts/phase20_inert_resource_surface.sh": 2,
            "scripts/phase20_long_lived_concurrent.sh": 2,
            "scripts/phase20_nested_brand_annotation.sh": 4,
            "scripts/phase20_protected_access_liveness.sh": 3,
            "scripts/phase20_resource_acquisition.sh": 4,
            "scripts/phase20_resource_enforcement.sh": 4,
            "scripts/phase20_resource_scope_cleanup.sh": 5,
            "scripts/phase20_stdlib_runtime_differential.sh": 1,
            "scripts/phase20_whole_program_corpus.sh": 2,
        },
    },
    "phase21-native-qualification": {
        "owner_patch": "24.12",
        "action": "convert",
        "files": {
            "scripts/phase21_collection_string_native_source.sh": 4,
            "scripts/phase21_cross_tenant_capability.sh": 2,
            "scripts/phase21_filesystem_allocation_native_source.sh": 3,
            "scripts/phase21_od8_adversarial_verdict.sh": 2,
            "scripts/phase21_opening.sh": 2,
            "scripts/phase21_per_root_obligations.sh": 2,
            "scripts/phase21_resource_sync_native_source.sh": 2,
            "scripts/phase21_trusted_scope_provenance.sh": 3,
            "scripts/phase21_typed_query_noop_surface.sh": 2,
        },
    },
    "phase22-flip-evidence": {
        "owner_patch": "24.13",
        "action": "retire",
        "files": {
            # Patch 24.13 discharged this family's deferral -- it IS 24.13.
            # Counts re-measured, not adjusted to fit: the three that reach 0
            # had every live-C arm retired; the two that do not are the mixed
            # dispositions, and their survivors are accounted for in
            # DISCHARGED_HARNESSES below rather than left as bare residue.
            "scripts/phase22_default_native_package.sh": 0,
            "scripts/phase22_explicit_c_migration.sh": 2,
            "scripts/phase22_native_implicit_output.sh": 0,
            # 1 -> 2: restoring the explicit.c emission the c-alias
            # comparison needs as its reference (issue #398) brings back the
            # spelling that produced it.
            "scripts/phase22_opening.sh": 2,
            "scripts/phase22_postflip_qualification.sh": 0,
        },
    },
    "stdlib-parity": {
        "owner_patch": "stdlib-coordination",
        "action": "migrate",
        "files": {
            "scripts/stdlib_s1_branded_collections_parity.sh": 5,
            "scripts/stdlib_s1_clone_destination_parity.sh": 5,
            "scripts/stdlib_s1_composition_parity.sh": 2,
            "scripts/stdlib_s1_mutex_guard_scope_parity.sh": 1,
        },
    },
    "stdlib-runner-pinned": {
        "owner_patch": "stdlib-coordination",
        "action": "migrate",
        "match": "route",
        "files": {
            "scripts/stdlib_s1_migration_parity.sh": 1,
            "scripts/stdlib_s1_mutex_guard_fibers_parity.sh": 4,
            "scripts/stdlib_s1_mutex_guard_parity.sh": 6,
        },
    },
}

# Just recipes executing or pinning live C. `live` is cross-checked against
# the mechanical liveness closure (workflow-reachable, CI-family
# registry-named, or make-test closure); a mismatch fails validate.
RECIPE_ROWS = [
    # (recipe, needle, owner_patch, action, live)
    ("guard-cranelift-phase11-scalar-expression-parity",
     './gust --backend mir-to-c "$source_path"', "24.12", "convert", True),
    ("guard-cranelift-phase11-local-state-parity",
     './gust --backend mir-to-c "$source_path"', "24.12", "convert", True),
    ("guard-cranelift-phase11-structured-cfg-parity",
     './gust --backend mir-to-c "$source_path"', "24.12", "convert", True),
    ("guard-cranelift-phase11-block-parameter-loop-parity",
     './gust --backend mir-to-c "$source_path"', "24.12", "convert", True),
    ("guard-cranelift-phase11-direct-call-abi-parity",
     './gust --backend mir-to-c "$positive_source"', "24.12", "convert", True),
    ("guard-cranelift-phase11-module-import-runtime-parity",
     './gust --backend mir-to-c "$source_path"', "24.12", "convert", True),
    ("guard-cranelift-phase11-metadata-diagnostic-parity",
     './gust --backend mir-to-c "$type_error_source"', "24.12", "convert", True),
    ("guard-mir-feature-return-int-preservation",
     './gust --backend mir-to-c "$feature_fixture"', "24.12", "convert", True),
    ("guard-mir-feature-local-binding-read-preservation",
     './gust --backend mir-to-c "$feature_fixture"', "24.12", "convert", True),
    ("guard-mir-feature-if-else-return-int-preservation",
     './gust --backend mir-to-c "$feature_fixture"', "24.12", "convert", True),
    ("guard-mir-feature-local-binding-read-provenance-metadata-preservation",
     './gust --backend mir-to-c "$feature_fixture"', "24.12", "convert", True),
    ("guard-cranelift-differential-family",
     "cranelift_ci_family.py run", "24.12", "convert", True),
    ("guard-cranelift-phase23-mir-to-c-focused-live-contract",
     "scripts/phase23_mir_to_c_focused_live.py validate", "24.12", "retire", True),
    ("guard-cranelift-phase23-mir-to-c-focused-live-evidence",
     "scripts/phase23_mir_to_c_focused_live.py evidence", "24.12", "retire", True),
    ("guard-cranelift-phase21-cranelift-built-compiler-programs-evidence",
     "cranelift-built-compiler-programs", "24.12", "retire", True),
    ("make-test-suite",
     "./gust --backend mir-to-c tests/test_runner.gst", "24.13", "migrate", True),
    ("make-test-suite-parallel",
     "./gust --backend mir-to-c tests/test_runner.gst", "24.13", "migrate", True),
    # Re-scored from 24.16/retire by Patch 24.13, for the same reason
    # guard-compile-pass and guard-compile-fail were: the ownership was
    # assigned before it was known that 24.13's removal BREAKS it. This recipe
    # drives the spelling this patch turns into a rejection, so leaving it to
    # 24.16 ships a recipe that cannot run. Recorded, not moved silently.
    ("run-step52-positive-batch",
     "./gust --backend mir-to-c tests/test_runner.gst", "24.13", "migrate", False),
    ("guard-positive",
     './gust --backend mir-to-c "$test_path"', "24.13", "migrate", True),
    # Re-scored live by Patch 24.12a. Both are reached from a workflow --
    # guard-cranelift-phase20-arena-free-contract calls them -- and were
    # scored dead only because liveness() parsed the justfile fragments
    # separately and lost every cross-file call edge (issue #395). They stay
    # 24.16/retire: being executed does not make a C consumer permanent, it
    # means the retirement has to migrate the callers rather than delete a
    # recipe nothing runs.
    ("guard-compile-pass",
     './gust --backend mir-to-c "$test_path"', "24.16", "retire", True),
    ("guard-compile-fail",
     './gust --backend mir-to-c "$test_path"', "24.16", "retire", True),
    ("guard-stdlib-s1-str-equality-diagnostic",
     './gust --backend mir-to-c "$mismatch"', "stdlib-coordination", "migrate", True),
    ("guard-stdlib-s1-collection-receivers",
     './gust --backend mir-to-c "$negative"', "stdlib-coordination", "migrate", True),
    ("guard-stdlib-s1-resource-prerequisites",
     './gust --backend mir-to-c "$witness"', "stdlib-coordination", "migrate", True),
    ("guard-stdlib-s1-migration",
     "bash scripts/stdlib_s1_migration_parity.sh", "stdlib-coordination", "migrate", True),
    ("guard-cranelift-phase10-backend-selection-contract",
     "codegen.codegen_generate(programs, module_prefixes, &env, ctx)",
     "24.13", "retire", True),
    ("guard-cranelift-phase10-opening-contract",
     "gust --backend mir-to-c program.gst", "24.15", "retire", True),
    ("guard-cranelift-phase12-5-close",
     '\'./gust --backend c "$source_fixture"\'', "24.16", "retire", True),
    ("guard-cranelift-phase13-close",
     '\'./gust --backend c "$source_fixture"\'', "24.16", "retire", True),
    # Direct C-harness callers: these recipes invoke a harness that executes
    # live C, so the harness retirement/conversion rewrites them too. Pure
    # dispatchers to registered rows (e.g. phase13 family parity calling
    # phase11 parity) carry no C of their own and need no row.
    ("guard-cranelift-phase11-close",
     "scripts/phase13_registry_differential.sh", "24.12", "retire", True),
    ("guard-cranelift-phase13-composition-differential",
     "scripts/phase13_registry_differential.sh", "24.12", "retire", True),
    ("guard-cranelift-phase13-source-metadata-parity",
     "scripts/phase13_source_metadata.sh", "24.12", "retire", True),
    ("guard-cranelift-phase14-composition-differential",
     "scripts/phase14_composition_differential.sh", "24.12", "retire", True),
    ("guard-cranelift-phase15-resource-composition-differential",
     "scripts/phase15_resource_composition_parity.sh", "24.12", "retire", True),
    ("guard-cranelift-phase16-composition-differential",
     "scripts/phase16_abi_composition_parity.sh", "24.12", "retire", True),
    ("guard-cranelift-phase19-composition-parity",
     "scripts/phase19_composition_parity.sh", "24.12", "retire", True),
    # Corrected in Patch 24.12: it sits in a `retire` family but keeps real
    # native evidence — it delegates to phase16_call_mir_parity.sh, which
    # compares the MIR-to-C witness against the explicit Cranelift consumer —
    # so it converts rather than being retired.
    ("guard-cranelift-phase19-representation-parity",
     "scripts/phase19_representation_parity.sh", "24.12", "convert", True),
    ("guard-cranelift-phase21-collection-string-native-source-parity",
     "scripts/phase21_collection_string_native_source.sh", "24.12", "convert", True),
    ("guard-cranelift-phase21-cross-tenant-capability-evidence",
     "scripts/phase21_cross_tenant_capability.sh", "24.12", "convert", True),
    ("guard-cranelift-phase21-filesystem-allocation-native-source-parity",
     "scripts/phase21_filesystem_allocation_native_source.sh", "24.12", "convert", True),
    ("guard-cranelift-phase21-od8-adversarial-verdict-evidence",
     "scripts/phase21_od8_adversarial_verdict.sh", "24.12", "convert", True),
    ("guard-cranelift-phase21-opening-evidence",
     "scripts/phase21_opening.sh", "24.12", "convert", True),
    ("guard-cranelift-phase21-per-root-obligations-evidence",
     "scripts/phase21_per_root_obligations.sh", "24.12", "convert", True),
    ("guard-cranelift-phase21-residue-migration-authority-evidence",
     "scripts/phase21_opening.sh", "24.12", "convert", True),
    ("guard-cranelift-phase21-resource-sync-native-source-parity",
     "scripts/phase21_resource_sync_native_source.sh", "24.12", "convert", True),
    ("guard-cranelift-phase21-trusted-scope-provenance-evidence",
     "scripts/phase21_trusted_scope_provenance.sh", "24.12", "convert", True),
    ("guard-cranelift-phase21-typed-query-noop-surface-evidence",
     "scripts/phase21_typed_query_noop_surface.sh", "24.12", "convert", True),
    ("guard-cranelift-phase22-default-native-package-evidence",
     "scripts/phase22_default_native_package.sh", "24.12", "retire", True),
    ("guard-cranelift-phase22-explicit-c-migration-evidence",
     "scripts/phase22_explicit_c_migration.sh", "24.12", "retire", True),
    ("guard-cranelift-phase22-native-implicit-output-evidence",
     "scripts/phase22_native_implicit_output.sh", "24.12", "retire", True),
    ("guard-cranelift-phase22-opening-evidence",
     "scripts/phase22_opening.sh", "24.12", "retire", True),
    ("guard-stdlib-s1-branded-collections",
     "scripts/stdlib_s1_branded_collections_parity.sh", "stdlib-coordination", "migrate", True),
    ("guard-stdlib-s1-clone-destination",
     "scripts/stdlib_s1_clone_destination_parity.sh", "stdlib-coordination", "migrate", True),
    ("guard-stdlib-s1-composition",
     "scripts/stdlib_s1_composition_parity.sh", "stdlib-coordination", "migrate", True),
    ("guard-stdlib-s1-mutex-guard-scope",
     "scripts/stdlib_s1_mutex_guard_scope_parity.sh", "stdlib-coordination", "migrate", True),
    ("guard-stdlib-s1-str-surface",
     'bash scripts/run-gust-file.sh "$fixture"', "stdlib-coordination", "migrate", True),
]

WORKFLOW_ROWS = [
    # (workflow, needle, owner_patch, action)
    ("phase23-mir-to-c-focused-live.yml",
     "guard-cranelift-phase23-mir-to-c-focused-live-evidence", "24.12", "retire"),
    ("phase23-mir-to-c-frozen-surface.yml",
     "guard-cranelift-phase23-mir-to-c-frozen-surface-contract", "24.15", "update"),
    ("phase23-mir-to-c-archived-corpus.yml",
     "guard-cranelift-phase23-mir-to-c-archived-corpus-contract", "24.15", "update"),
    ("phase23-mir-to-c-deprecation-opening.yml",
     "guard-cranelift-phase23-mir-to-c-deprecation-opening-evidence", "24.16", "retire"),
    ("phase23-mir-evidence-owner.yml",
     "compiler/mir_to_c_*_smoke_test_entry.gst", "24.16", "retire"),
    ("phase21-cranelift-built-compiler-programs.yml",
     "scripts/phase23_mir_to_c_focused_live.py", "24.12", "retire"),
    ("phase24-cr15-stdlib-guard-transition.yml",
     "scripts/phase23_mir_to_c_deprecation_opening.py", "24.16", "retire"),
    ("pr-fast.yml",
     "guard-cranelift-phase23-mir-to-c-focused-live-contract", "24.16", "retire"),
]

# ---------------------------------------------------------------------------
# Patch 24.15's four registry rows, and the disposition they actually get.
#
# The roadmap says "retire the generated-C registry rows". Read as deletion
# that is not implementable and not right:
#
#   * phase23_closure indexes all four by contract_version and status
#     (patch23_7 through patch23_11). Deleting any is a KeyError in frozen
#     closed-phase evidence, not a retirement.
#   * They are Phase 23 RECORDS. "As of Patch 23.10 there was one live lane"
#     stays true no matter what Phase 24 does; a record of a closed phase is
#     not made wrong by later work.
#
# What IS wrong is a closed record asserting a currently-false LIVE state.
# phase23_mir_to_c_focused_live.route_contract says
# non_bootstrap_live_lane_count: 1, and Patch 24.14 retired that lane.
#
# So the live CLAIMS are retired and the records survive -- the same polarity
# pair as RETIRED_FILE_SURFACES/REBASED_FILE_SURFACES, one level up. The
# falsifier is not a list: each retired claim must DISAGREE with what the tree
# now measures, and the measurement is 24.14's derived lane count rather than
# a second declaration. A claim that still matches the tree was not retired,
# and fails here.
RETIRED_REGISTRY_CLAIMS = {
    "phase23_mir_to_c_focused_live": (
        ("route_contract", "non_bootstrap_live_lane_count"),
        "Patch 24.14 retired the focused live oracle, the single non-bootstrap "
        "live-C lane Patch 23.10 deliberately retained. The Phase 23 record "
        "keeps saying one lane existed then; what is retired is the claim that "
        "one exists now.",
    ),
}


def check_retired_registry_claims(registry: dict) -> None:
    """A retired live claim must disagree with what the tree measures."""
    spec = importlib.util.spec_from_file_location(
        "_audit", ROOT / "scripts" / "phase23_production_release_audit.py")
    module = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(module)
    except SystemExit:
        pass
    measured = module.scan()["active_non_bootstrap_live_c_lane_count"]

    for node_key, (path, reason) in RETIRED_REGISTRY_CLAIMS.items():
        node = registry.get(node_key)
        require(isinstance(node, dict),
                f"a retired-claim node must still exist as a closed-phase "
                f"record: {node_key}")
        claimed = node
        for step in path:
            require(isinstance(claimed, dict) and step in claimed,
                    f"the retired claim is gone from {node_key}: {path}. The "
                    "record survives; only the claim is retired, so deleting "
                    "it asserts nothing.")
            claimed = claimed[step]
        require(claimed != measured,
                f"{node_key}.{'.'.join(path)} still agrees with the tree "
                f"({claimed} == {measured}), so nothing was retired. {reason}")


REGISTRY_ROWS = [
    # Live generated-C registry nodes retired or updated under 24.15. The
    # archived corpus node survives as the parity authority with its live-C
    # references updated, per the oracle-replacement contract.
    ("phase23_mir_to_c_deprecation_opening", "24.15", "retire"),
    ("phase23_mir_to_c_frozen_surface", "24.15", "retire"),
    ("phase23_mir_to_c_focused_live", "24.15", "retire"),
    ("phase23_mir_to_c_archived_corpus", "24.15", "update"),
]

# Patch 24.13 (#398, #402): surfaces this patch actually removed, asserted in
# the INVERSE. A FILE_ROWS entry requires its needle to be PRESENT, which is
# right while a surface is still awaiting retirement and wrong the moment it is
# retired -- the row would break on a patch that never edits the file, and
# dropping it would say nothing about whether the surface came back.
#
# Only the help line went. The MirToC enum variant survives because the
# bootstrap-only entry reuses that tag, and the str_eq on the retired spelling
# survives because it is now the branch that REJECTS it. Both are still
# FILE_ROWS entries, still owned for later retirement, and still required to be
# present -- which is why this register names one surface rather than three.
RETIRED_FILE_SURFACES = [
    # Flipping the runner default was independent of the spelling removal, so
    # this row survived 24.13's withdrawal on its own.
    ("scripts/run-gust-file.sh",
     'RUNNER_ROUTE="${GUST_RUNNER_ROUTE:-mir-to-c}"', "24.13"),
    # The compiler help lines 24.13 wrote out and had to put back. Issue #398
    # removes them for real. Retirement is the right claim for these three:
    # nothing replaces a usage line for a route that no longer exists, and
    # what the compiler says INSTEAD is asserted by the rebased rows below
    # and by the rejection block phase22_explicit_c_migration.py pins.
    ("compiler/test_runner_entry.gst",
     "gust --backend mir-to-c <source.gst>", "#398"),
    ("compiler/test_runner_entry.gst",
     "gust --backend c <source.gst>", "#398"),
    ("compiler/test_runner_entry.gst",
     "--backend <mir-to-c|c|cranelift>", "#398"),
]

# (path, the spelling that was there, the spelling that replaced it, owner)
#
# RETIRED_FILE_SURFACES asserts only that a surface is GONE, which is the right
# claim when a patch takes something out. A migration is a different claim and
# a stronger one: the old spelling is gone AND a named replacement is there in
# its place. Scoring a migration as a retirement would let the file lose the
# invocation entirely and still pass, which is the "vanished passing as moved"
# failure this phase keeps having to rule out -- so it gets its own register
# rather than being folded into the retirement one.
# Surfaces a retirement patch REPLACED rather than removed: both halves
# have to be asserted, or the check could be deleted outright.
#
# Patch 24.14 rebased the -o refusal's wording from "the MIR-to-C
# backend" to "the bootstrap emitter entry", on the premise that only the
# bootstrap entry could still reach it. The removal is deferred until the
# live-C surface drains (issue #398), so --backend mir-to-c reaches that
# refusal too and the original wording names the spelling the caller
# actually used. Empty rather than deleted: this register is what 24.14
# needs again the moment the removal lands.
REBASED_FILE_SURFACES: list = []

MIGRATED_FILE_SURFACES = [
    ("tests/test_runner.gst",
     'std.Concat("./gust --backend mir-to-c ", path)',
     'std.Concat("./gust --backend bootstrap-emitter ", path)',
     "24.13"),
    # Issue #398. A migration rather than a retirement, and scored that way
    # deliberately: these four cases still run, they just read a recording
    # instead of making a compilation. Scoring them as retirements would let
    # the assertions disappear along with the invocation and still pass.
    ("tests/e2e_codegen_assertions.gst",
     '"./gust --backend mir-to-c tests/codegen_helper_pod_move.gst',
     "materialize tests/codegen_helper_pod_move.gst "
     "build/codegen_helper_pod_move --kind compile_only",
     "#398"),
]

FILE_ROWS = [
    # Issue #451: three cc sites in the justfile, one row each. They are
    # `cat src/runtime.c build/test_runner.c`, i.e. the hand-written
    # runtime concatenated with emitter output, so they retire when the
    # emitter retires at Patch 25.10 rather than being un-retired Phase 24
    # routes.
    #
    # Keyed on `(file, recipe, product)`. The MARKER cell must be literal
    # text present in the file -- the guard checks the surface still
    # exists -- so it carries the recipe header, and the action cell
    # carries the product. `inventory_owner` matches across all cells,
    # so a row authorizes exactly one site. Three earlier shapes were all too
    # coarse and each was caught in review: RECIPE_ROWS by recipe name
    # duplicated IDs that already exist under 24.13/migrate; FILE_ROWS by
    # file exempted a 22,605-line file; FILE_ROWS by product let any NEW
    # recipe compiling that product inherit the owner. A row authorizes
    # one site.
    ('justfile', 'make-test-suite:',
     'phase25', 'retire-with-emitter test_runner_final.c'),
    ('justfile', 'make-test-suite-parallel:',
     'phase25', 'retire-with-emitter test_runner_final.c'),
    ('justfile', 'run-step52-positive-batch:',
     'phase25', 'retire-with-emitter test_runner_step52_positive_final.c'),

    # (path, needle, owner_patch, action)
    ("compiler/test_runner_entry.gst",
     "    MirToC,", "24.13", "retire"),
    ("compiler/test_runner_entry.gst",
     'std.str_eq(backend_name, "mir-to-c")', "24.13", "retire"),
    ("compiler/test_runner_entry.gst",
     "the MIR-to-C backend does not accept -o", "24.14", "retire"),
    # Patch 25.10 retires these five. The emitter call in the entry, the
    # emitter itself, the bridge entry's two rows (the file is deleted with
    # the stage chain), and the Makefile's build/gust_final.c, which was the
    # product of the emission step that is gone.
    ("compiler/test_runner_entry.gst",
     "mut c_code := codegen.codegen_generate(programs, module_prefixes, &env, ctx);",
     "25", "retired-by-25.10"),
    ("compiler/codegen.gst",
     "func codegen_generate(programs: std.Vector[ast.Program[ctx], ctx]",
     "25", "retired-by-25.10"),
    ("compiler/test_runner_bootstrap_bridge_entry.gst",
     "mut c_code := codegen.codegen_generate(programs, module_prefixes, &env, ctx);",
     "25", "retired-by-25.10"),
    ("compiler/test_runner_bootstrap_bridge_entry.gst",
     # Patch 24.13 WIDENED this usage line rather than retiring it: the bridge
     # now also accepts the bootstrap-only entry, because Makefile:143 and the
     # sanitized stage-one diagnostic drive stage1_bin through it once the seed
     # reconverges. The retired spellings are still listed and still accepted
     # here -- the bridge is Phase-25-owned machinery and this patch does not
     # retire it, it only adds the entry the migrated callers need.
     "Usage: gust-bootstrap-bridge [--backend <mir-to-c|c|bootstrap-emitter>] <file.gst>",
     "25", "retired-by-25.10"),
    ("Makefile",
     "build/gust_final.c", "24.14", "retired-by-25.10"),
    ("Makefile",
     'CC="${CC}" CFLAGS="${CFLAGS}" INCLUDES="${INCLUDES}" just make-test-suite',
     "24.14", "migrate"),
    # Patch 24.13 migrated this default to cranelift (#411); inverted below.
    ("scripts/cranelift_ci_family.py",
     '["just", runner["static_guard"]]', "24.12", "convert"),
]

SMOKE_FIXTURES = sorted([
    "compiler/mir_to_c_block_jump_smoke_test_entry.gst",
    "compiler/mir_to_c_conditional_branch_smoke_test_entry.gst",
    "compiler/mir_to_c_entry_smoke_test_entry.gst",
    "compiler/mir_to_c_function_shell_smoke_test_entry.gst",
    "compiler/mir_to_c_local_binding_read_smoke_test_entry.gst",
    "compiler/mir_to_c_native_boundary_metadata_smoke_test_entry.gst",
    "compiler/mir_to_c_provenance_metadata_smoke_test_entry.gst",
    "compiler/mir_to_c_resource_metadata_smoke_test_entry.gst",
    "compiler/mir_to_c_return_int_literal_smoke_test_entry.gst",
])

SCRIPT_ROWS = [
    # Guard-implementation scripts with live-C evidence modes.
    ("scripts/phase23_mir_to_c_focused_live.py", "24.12", "retire"),
    ("scripts/phase23_mir_to_c_archived_corpus.py", "24.15", "update"),
    ("scripts/phase23_mir_to_c_frozen_surface.py", "24.15", "retire"),
    ("scripts/phase23_mir_to_c_deprecation_opening.py", "24.16", "retire"),
    ("scripts/phase23_production_release_audit.py", "24.16", "retire"),
    # Patch 24.12b: the thirteen Python loci. None had a row before this
    # patch, which is what its own step text said and #415 measured -- the
    # population was a hand-list with no authority behind it.
    #
    # Converted by 24.12b: their retired arms are served from the frozen
    # oracle and their native arms still run live.
    ("scripts/phase24_cr15_derivation.py", "24.12b", "convert"),
    ("scripts/phase24_cr15_qualification.py", "24.12b", "convert"),
    ("scripts/phase21_compiler_support_native_qualification.py",
     "24.12b", "convert"),
    ("scripts/phase22_preflip_default_cohort.py", "24.12b", "convert"),
    ("scripts/phase21_selected_compiler_module_qualification.py",
     "24.12b", "convert"),
    ("scripts/phase22_default_route_flip.py", "24.12b", "convert"),
    # Structural: cannot be discharged by conversion alone.
    ("scripts/phase20_generated_mir_scale.py", "24.16", "materialize"),
    ("scripts/phase24_resource_implicit_transfer.py", "24.16", "materialize"),
    # Registered exclusions, each with its reason in the frozen oracle's
    # PYTHON_RETIRED_ARGV_EXCLUSIONS.
    ("scripts/phase21_cranelift_built_compiler_programs.py", "24.14", "retire"),
    ("scripts/phase23_same_scope_declaration.py", "24.16", "convert"),
    ("scripts/phase23_issue_health_opening.py", "24.16", "retire"),
    ("scripts/phase23_structured_guard_defer_native_admission.py",
     "24.16", "retire"),
    ("scripts/phase24_filename_behavior_characterization.py", "24.3", "carry"),
    ("scripts/phase24_frozen_oracle_capture.py", "24.13", "retire"),
]


def liveness() -> tuple[set[str], set[str], set[str]]:
    """Workflow-reachable, CI-family registry-named, and make-test closure.

    The annotation said two while the docstring said three and the body
    returned three (#404). That mismatch is what produced two plausible wrong
    intermediates, 90 and then 371: a caller reading the signature unpacks two
    names and silently folds the third set into whichever it happens to bind.

    Recipes the just-graph cannot see through make/python indirection are
    covered by the registry-named set and the make-test roots. Anything
    outside all three is staged, not live.
    """
    spec = importlib.util.spec_from_file_location(
        "guard_reachability", ROOT / "scripts" / "guard_reachability.py")
    require(spec is not None and spec.loader is not None,
            "cannot load the guard reachability module")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    # Parse the concatenation, the way guard_reachability.main() does.
    # Parsing each fragment separately drops every cross-file call edge:
    # parse_justfile only records `just <recipe>` as an edge when the callee
    # is a key in that same parse, and the justfile imports five fragments.
    # The per-file graph found 517 live recipes against the concatenated
    # graph's 591 -- 74 short, 65 of them with truncated edge sets, and the
    # per-file parse contributed no edge the concatenated one lacked. It
    # validated green only because the registry-named set covered the
    # difference, which is the mechanism issue #393 says is unsound: two
    # unsound parts cancelling. Issue #395.
    justfile_text = "\n".join(module.justfile_sources(ROOT / "justfile"))
    edges, _ = module.parse_justfile(justfile_text)
    # Patch 24.15a (#404): fold dynamically dispatched guards into the graph,
    # exactly as guard_reachability.main does before computing reachability.
    # liveness() did not, which is the whole reason it needed the substring
    # blob match below: a guard reached only through `just "$var"` dispatch was
    # invisible to the static edges, so `named` had to cover for it. That made
    # mention load-bearing here while #393's repair was busy removing it from
    # guard_reachability -- the two instruments disagreeing about what counts
    # as an execution route.
    dispatched = module.dynamic_edges(justfile_text, set(edges))
    for recipe, names in dispatched.items():
        edges[recipe].extend(names)
    roots = set(module.workflow_roots(edges))
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    # The inventory node itself names every row by construction, so it must
    # not feed the liveness signal: only pre-existing CI-family authority
    # counts as registry-named.
    prior = {key: value for key, value in registry.items()
             if key != "phase24_retirement_consumer_inventory"}
    blobs = [json.dumps(prior)]
    try:
        blobs.append(read("scripts/cranelift_test_levels.json"))
    except OSError:
        pass
    named = {name for name in edges
             if any(name in blob for blob in blobs)}
    make_roots = {"make-test-suite", "make-test-suite-parallel",
                  "make-test-guards", "make-test-guards-policy"}
    # Three signals, kept apart. They used to be returned as two, with
    # registry-named folded into make-reachable, and a row scored live by a
    # bare mention was then indistinguishable from one something executes.
    # check_stale_row_scoring below needs to tell them apart.
    return (set(module.reachable(edges, roots)), named,
            set(module.reachable(edges, make_roots)))



# ---------------------------------------------------------------------------
# Rows this inventory knows are wrong, with an owner, because a known-wrong
# row nobody owns is how this file acquired 53 failing assertions at 24.11.
#
# Two different defects, so two registers and two falsifiers. A patch that
# fixes one must not be able to believe it has fixed the other.
#
#   action_disagrees_with_outcome
#       The row's `action`/`owner_patch` say something other than what
#       happened to the harness it calls -- mostly rows still saying
#       `24.12 retire` about harnesses 24.12 converted.
#
#   is_live_with_no_execution_route
#       Scored `live=True` while reachable by **neither** static `just` edges
#       **nor** any level-driven dynamic dispatcher. No execution route
#       exists for them at all, and `require((recipe in live) == is_live)`
#       pins that as registry authority.
#
#       These were first registered as "live by mention", on the argument
#       that a name appearing in scripts/cranelift_test_levels.json is a
#       classification rather than a caller. **That argument is retracted.**
#       `guard-cranelift-experimental-backend-suite` (justfile:21892-21911)
#       runs every recipe `cranelift_test_levels.py list-native` returns, and
#       of seven `just "$var"` dispatch sites at least four are driven by
#       that file. For 37 of 53 guards a level entry is precisely what causes
#       execution, so the level file is the repository's primary dynamic
#       execution authority and `registry_named` including it is defensible.
#
#       Re-derived against the corrected model -- static closure over
#       workflow roots, unioned with `cranelift_test_levels.py list-native`
#       and `level <guard>` for the phase15/16/17 complete-evidence guards.
#       All 7 hold, 0 drop: none is dispatched by the level file.
#
#       **Upper bound, not settled.** Three dispatch sites -- justfile:306,
#       :21967, :22621 -- have sources not yet enumerated. If any dispatches
#       one of these seven, that row drops. Re-run the model above rather
#       than inheriting this number.
#
# Patch 24.12a registers, it does not re-score: flipping `is_live` moves
# pinned authority that Patch 24.12's conversion evidence rests on.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# What Patch 24.12a took out. The 24.11 per-row falsifier is "this row is
# still live", which inverts the moment a patch removes the row -- so a
# removal is recorded and asserted in the inverse rather than deleted
# quietly. Each of these must now be absent from the justfile and the tree.
# ---------------------------------------------------------------------------

RETIRED_BY = "24.12a"

RETIRED_RECIPES = (
    "guard-cranelift-phase19-classification-parity",
    "guard-cranelift-phase19-gust-name-list-removed-parity",
    "guard-cranelift-phase19-rename-invariance",
    "guard-cranelift-phase19-rule-convergence-parity",
    "guard-cranelift-phase19-type-naming-parity",
    "guard-cranelift-phase21-inert-scoped-query-records-evidence",
)

RETIRED_HARNESSES = (
    "scripts/phase19_classification_parity.sh",
    "scripts/phase19_gust_name_list_removed_parity.sh",
    "scripts/phase19_rename_invariance.sh",
    "scripts/phase19_rule_convergence_parity.sh",
    "scripts/phase19_type_naming_parity.sh",
    "scripts/phase20_resource_declaration_migration.sh",
    "scripts/phase21_inert_scoped_query_records.sh",
)

# ---------------------------------------------------------------------------
# Surfaces no row owns, and the instrument blind spot that hid them (#396).
#
# check_harness_callers() says it closes the gap where "a recipe that calls a
# C-executing harness without naming a backend still runs live C". It does
# not: HARNESS_CALL needs the literal path straight after `bash`, and the
# prevailing justfile idiom assigns it to a variable first
# (`evidence_script="scripts/x.sh"` then `bash "$evidence_script"`), so those
# recipes are never required to have a row.
#
# Measured on this tree by this lane: 113 recipes call a harness directly and
# 10 name one only through a variable, all 10 unrowed. The coordinator
# measured 25 and 24 on the same tree; the two differ because the count
# depends on which indirection forms are matched, and pinning that down is
# part of what Patch 24.15a has to do rather than something to settle by
# picking a number here.
#
# Patch 24.12a registers, it does not repair: the HARNESS_CALL fix rides with
# #390/#393/#395 in Patch 24.15a, and adjudicating the rows it then demands
# is Patch 24.16's.
# ---------------------------------------------------------------------------

HARNESS_CALL_BLIND_SPOT_OWNER = "24.15a"

UNOWNED_SURFACES = (
    {
        "surface": "scripts/phase12_5_route_architecture.sh",
        "owner": "24.16",
        "why": "still runs ./gust --backend mir-to-c as its registered "
               "route-unavailability probe, and the recipe that calls it "
               "names it through a variable, so #396 kept it off the rows "
               "this inventory requires. Adjudicating the row the repaired "
               "instrument demands is the residue audit's.",
    },
    {
        "surface": "scripts/phase24_3b_coordinate_retirement_inversions.py",
        "owner": "24.16",
        "why": "a chain consumer nothing executes. It reads the "
               "frozen-surface chain five times (:71, :120, :158, :185, "
               ":265, each loading phase23_mir_to_c_frozen_surface.py, with "
               ":120 and :185 invoking its validate), but every reference to "
               "it in the tree is non-executing: TASK.md prose and a path "
               "list in phase23_mir_to_c_deprecation_opening.py:79. No "
               "justfile recipe, workflow or Makefile target names it. It is "
               "kept off the orphan report by 4 mentions in the feature "
               "registry -- issue #393's defect in a population one ring "
               "out, since it is not a guard recipe so guard_reachability "
               "never considered it and it appears in neither the orphan "
               "list nor the allowlist. A script that reads a chain and is "
               "executed by nothing protects nothing today; whether to wire "
               "it to a caller or retire it is a residue judgement, not "
               "Patch 24.12a's to make mid-patch.",
    },
    {
        "surface": "compiler/phase10_help.txt",
        "owner": "24.13",
        "why": "the pinned expected output of the `gust --help` contract "
               "(.github/workflows/heavy-guards.yml:45-46, justfile:10126, "
               "grepped again at justfile:21674-21675). It advertises "
               "--backend <mir-to-c|c|cranelift>. Patch 24.13 removes the "
               "selection, which changes --help, which breaks this fixture -- "
               "so it is a consequence of selection removal and 24.13's to "
               "update, not 24.15's package-and-documentation retirement. "
               "Unowned, it falls between them.",
    },
)

STALE_SCORING_OWNER = "24.16"

ACTION_DISAGREES_WITH_OUTCOME = (
    "guard-cranelift-phase11-close",
    "guard-cranelift-phase12-5-close",
    "guard-cranelift-phase13-close",
    "guard-cranelift-phase13-composition-differential",
    "guard-cranelift-phase13-source-metadata-parity",
    "guard-cranelift-phase14-composition-differential",
    "guard-cranelift-phase15-resource-composition-differential",
    "guard-cranelift-phase16-composition-differential",
    "guard-cranelift-phase19-composition-parity",
)

# Issues #390 and #393, Patch 24.15a: seven entries join this register as a
# consequence of repairing the reachability instrument, not of any change in
# the guards themselves. Before the repair each looked reachable, because
# `liveness()` read a recipe name it was merely searching for as a call edge
# (#390) and could not model dynamic guard dispatch (#393). Every `just
# <name>` occurrence of the four `guard-mir-feature-*-preservation` recipes
# sits inside an `rg -n -F` assertion pattern -- justfile:1355-1370 and
# :1507-1522 -- and is a search for the name, not a call of it.
#
# Measured on this tree after the repair, all seven are absent from both the
# workflow and the `make` populations and present only in registry naming,
# which is exactly this register's predicate.
#
# They are registered here rather than re-scored to `is_live=False`. On main
# the same repair does move four of them to False, because main has no
# CI-family registry naming for them; this tree is Patch 24.12a's, where that
# naming exists, so `recipe in live` stays True and re-scoring the rows would
# make them contradict what `liveness()` measures here. That is the coupling
# the 24.15a split could not satisfy: the repair and this register have to
# land in one tree.
IS_LIVE_WITH_NO_EXECUTION_ROUTE = (
    # Issue #437 wired 27 of the 28 parity recipes and left this one here
    # deliberately: it is adjudicated repair_required, not wired, because it
    # fails when executed. It keeps its level and its place in the justfile,
    # so it is still live-by-mention with no execution route -- which is
    # exactly what this register is for. The finding is in
    # issue437_parity_residue_adjudication.repair_required_finding.
    "guard-cranelift-phase11-metadata-diagnostic-parity",
    "guard-cranelift-phase13-composition-differential",
    "guard-cranelift-phase14-composition-differential",
    "guard-mir-feature-if-else-return-int-preservation",
    "guard-mir-feature-local-binding-read-preservation",
    "guard-mir-feature-local-binding-read-provenance-metadata-preservation",
    "guard-mir-feature-return-int-preservation",
)

# Issue #396, Patch 24.15a. `HARNESS_CALL` needs the literal path straight
# after `bash`, so a recipe naming its harness any other way is never required
# to have a row. The fix is NOT to enumerate the known indirection forms:
# measured on this tree, a repair that "resolves single-assignment variables"
# would recover 27 double-quoted and 2 single-quoted assignments and still
# miss 14 harnesses invoked as bare executables -- while reporting itself
# complete. Distinct harnesses by form:
#
#     bash <literal path>      105   matched by HARNESS_CALL
#     var="scripts/x.sh"        27   missed (the form #396 names)
#     var='scripts/x.sh'         2   missed (single quotes)
#     scripts/x.sh (no bash)    14   missed -- not indirection at all; the
#                                    path is literal, there is simply no
#                                    `bash` in front of it
#
# So assert the inverse instead: every `scripts/*.sh` reference in a recipe
# body must be matched by one of the registered forms below. A new form fails
# here rather than silently contributing no row, which is exactly how this
# blind spot survived. This pins the *forms*, not the rows -- adjudicating the
# rows the repaired sweep then demands is Patch 24.16's.
#
# Every form must match at the reference, not merely somewhere on its line.
# An earlier version of this check skipped any reference sitting inside quotes
# before testing the forms at all, on the argument that a quoted path is text
# about a call. The prevailing idiom in this justfile is
# `evidence_script="scripts/x.sh"` -- quoted -- so the skip took out the very
# form #396 is about: the "assignment to a variable" pattern was exercised by
# 0 of 169 references and could have been deleted without failing anything,
# and a genuinely novel quoted form such as `echo "scripts/new.sh"` was
# accepted in silence. Tested instead of skipped, the same 169 references are
# all accounted for and the assignment form carries 37 of them.
HARNESS_REFERENCE = re.compile(r"scripts/[A-Za-z0-9_.-]+\.sh")
HARNESS_REFERENCE_FORMS = (
    ("bash <literal path>",
     re.compile(r"\bbash\s+scripts/[A-Za-z0-9_.-]+\.sh")),
    ("assignment to a variable",
     re.compile(r"""=\s*['"]?scripts/[A-Za-z0-9_.-]+\.sh""")),
    # `./` is optional. Patch 25.5 wrote three recipes as
    # `./scripts/x.sh`, which is the same call and was not an accounted
    # form, so the sweep failed rather than demanding rows for them --
    # which is the check working, and the fix is to account for the form
    # rather than to respell the callers into the one form it knew.
    ("invoked as a bare executable",
     re.compile(r"^\s*(?:\S+=\S+\s+)*\./?scripts/[A-Za-z0-9_.-]+\.sh(?:\s|$)"
                .replace("\\./?", "(?:\\./)?"))),
    # Spans the whole line deliberately: "the line is a comment" is a property
    # of the line, and the span has to reach the reference for the overlap
    # test below to see it.
    ("named in a comment (text about a call, not a call)",
     re.compile(r"^\s*#.*")),
    ("continuation argument to a command on an earlier line",
     re.compile(r"^\s*(?:\"\$[A-Za-z_]\w*\"\s+)+scripts/[A-Za-z0-9_.-]+\.sh")),
)


def _accounting_form(line: str, offset: int) -> str | None:
    """The registered form whose own match covers this reference, or None.

    Overlap, not a bare line-level `search`. A line can hold a registered form
    and a novel one at once -- `bash scripts/a.sh && cp scripts/b.sh /tmp` --
    and under a line-level test the first launders the second. Requiring the
    form's match to span the reference is what makes each reference answer for
    itself, and it is also what lets a quoted reference be *tested* rather
    than skipped: `evidence_script="scripts/x.sh"` is covered because the
    assignment pattern reaches through the quote to the path, while
    `echo "scripts/new.sh"` is covered by nothing and fails.
    """
    for name, pattern in HARNESS_REFERENCE_FORMS:
        for match in pattern.finditer(line):
            if match.start() <= offset < match.end():
                return name
    return None


def check_harness_reference_forms(bodies: dict[str, str]) -> int:
    """Fail if a harness is named in a form the sweep does not account for."""
    unaccounted = []
    for recipe, body in sorted(bodies.items()):
        for line in body.split("\n"):
            for hit in HARNESS_REFERENCE.finditer(line):
                if _accounting_form(line, hit.start()) is None:
                    unaccounted.append(f"{recipe}: {line.strip()[:88]}")
                    break
    require(not unaccounted,
            "a harness is referenced in a form the sweep does not account "
            "for (issue #396); register the form in "
            "HARNESS_REFERENCE_FORMS or the reference will never demand a "
            "row:\n  " + "\n  ".join(unaccounted[:8]))
    return len(HARNESS_REFERENCE_FORMS)


HARNESS_CALL = re.compile(r"bash (scripts/[A-Za-z0-9_.-]+\.sh)")

# Recipes invoking the shared runner with an explicit non-C route. Verified
# clean by inspection (both pin GUST_RUNNER_ROUTE=cranelift on the invoking
# line); the check below re-verifies that pin rather than trusting this list.
CLEAN_RUNNER_CALLERS = {"gt-one-gst", "guard"}


def check_harness_callers(bodies: dict[str, str],
                          registered: set[str]) -> None:
    """Every direct C-harness invocation belongs to a registered row.

    The spelling sweep cannot see transitive execution: a recipe that calls
    a C-executing harness without naming a backend still runs live C. This
    closes that gap. The two developer entries invoking the shared runner
    with an explicit cranelift route are admitted by their verified pin,
    not by name.
    """
    sh_with_c = set()
    for path in (ROOT / "scripts").glob("*.sh"):
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        if BACKEND_SPELLING.search(text):
            sh_with_c.add(path.name)
    for recipe, body in bodies.items():
        for match in HARNESS_CALL.finditer(body):
            harness = match.group(1)
            if harness == "scripts/run-gust-file.sh":
                if recipe in CLEAN_RUNNER_CALLERS:
                    line = next(line for line in body.split("\n")
                                if "run-gust-file.sh" in line)
                    require("GUST_RUNNER_ROUTE=cranelift" in line,
                            f"runner caller lost its explicit route: {recipe}")
                    continue
            if harness.split("/")[-1] not in sh_with_c:
                continue
            require(recipe in registered,
                    f"unregistered C-harness caller: {recipe} -> {harness}")


# Patch 24.14 (#401): the native route's linker driver, excepted BY NAME.
#
# 24.14 removes C compiler discovery that exists to emit and build C as a
# backend product. The supported native route discovers its linker driver on a
# normal compilation path and must survive: deleting it removes the ability to
# LINK, not the ability to emit C, and the two share only the CC variable and
# the cc binary.
#
# The falsifier over-approximates within the right scope rather than
# enumerating call sites. It asserts the discovery is still there and still
# reached from the link request -- so a patch that deletes it fails here rather
# than at whatever downstream guard happens to notice a missing binary.
#
# It deliberately does NOT assert that this is the only cc consumer anywhere:
# 46 cc call sites across 44 scripts/*.sh link native objects, and that form
# was measured and rejected as unsatisfiable without deleting valid evidence.
NATIVE_LINKER_DRIVER = {
    "path": "compiler/experiments/cranelift/src/main.rs",
    "discovery": 'env::var_os("CC").unwrap_or_else(|| OsString::from("cc"))',
    "request_field": "linker_driver,",
    "invocation": "Command::new(&request.linker_driver)",
    "policy": "compiler/mir_target_authority.gst",
    "policy_marker": "Patch 18.7: linker discovery and invocation policy",
}


def check_native_linker_driver() -> None:
    """Patch 24.14: the supported route can still find and run its linker."""
    driver = read(NATIVE_LINKER_DRIVER["path"])
    for key in ("discovery", "request_field", "invocation"):
        require(NATIVE_LINKER_DRIVER[key] in driver,
                f"Patch 24.14 removed the native route's linker driver, which "
                f"#401 excepts by name: {NATIVE_LINKER_DRIVER[key]}")
    policy = read(NATIVE_LINKER_DRIVER["policy"])
    require(NATIVE_LINKER_DRIVER["policy_marker"] in policy,
            "the Patch 18.7 linker discovery policy this exception rests on "
            "is gone")


def check_sweep() -> dict[str, int]:
    """Every backend-spelling hit in execution loci belongs to a row."""
    loci = (["Makefile"] + JUSTFILE_FRAGMENTS
            + ["compiler/test_runner_entry.gst",
               "compiler/test_runner_bootstrap_bridge_entry.gst",
               "scripts/run-gust-file.sh",
               "tests/e2e_codegen_assertions.gst",
               "tests/test_runner.gst"]
            + sorted(str(path.relative_to(ROOT)) for path in
                     (ROOT / "scripts").glob("*.sh")))
    counts: dict[str, int] = {}
    for locus in loci:
        try:
            text = read(locus)
        except OSError:
            continue
        hits = len(BACKEND_SPELLING.findall(text))
        if hits:
            counts[locus] = hits
    return counts


def family_rows() -> list[dict[str, str]]:
    """One row per family, split where a family's files went different ways.

    A family-level verdict is too coarse the moment one of its files is
    handled by a different patch — which is exactly what Patch 24.12 found in
    `phase21-native-qualification`, marked `convert` while containing a
    harness with no native arm. So a family whose files split emits one row
    per destination, and the row set says what actually happened rather than
    what the family average was.
    """
    rows: list[dict[str, str]] = []
    for name, family in SH_FAMILIES.items():
        files = list(family["files"])
        taken = [path for path in files if path in TAKEN_OUT_HARNESSES]
        deferred: dict[str, list[str]] = {}
        for path in files:
            if path in TAKEN_OUT_HARNESSES:
                continue
            if path in DEFERRED_HARNESSES:
                deferred.setdefault(DEFERRED_HARNESSES[path][0],
                                    []).append(path)
        if not taken and not deferred:
            rows.append({"id": f"sh-family:{name}",
                         "owner_patch": family["owner_patch"],
                         "action": family["action"]})
            continue
        if taken:
            rows.append({"id": f"sh-family:{name}",
                         "owner_patch": TAKEN_OUT_BY,
                         "action": "convert"})
        for owner in sorted(deferred):
            rows.append({"id": f"sh-family:{name}:deferred-to-{owner}",
                         "owner_patch": owner,
                         "action": "retire"})
    return rows


def row_outcome(recipe: str, bodies: dict[str, str]) -> tuple[str, str] | None:
    """What actually happened to the harness a row's recipe calls."""
    body = bodies.get(recipe)
    if body is None:
        return None
    called = set(HARNESS_CALL.findall(body)) | set(
        re.findall(r"(?:^|\s)(scripts/[A-Za-z0-9_.-]+\.sh)", body))
    owners = {DEFERRED_HARNESSES[path][0]
              for path in called if path in DEFERRED_HARNESSES}
    if owners:
        return (sorted(owners)[0], "retire")
    if recipe in TAKEN_OUT_RECIPES or called & set(TAKEN_OUT_HARNESSES):
        return (TAKEN_OUT_BY, "convert")
    return None


def check_family_actions() -> None:
    """A family must declare the disposition its files actually took.

    Scope: `SH_FAMILIES` only. The recipe rows have their own defect and
    their own register; one obligation per assertion.

    `family_rows()` computes the emitted row and never reads this field, so
    it is inert for every split family -- which is how four families came to
    declare `retire` about files Patch 24.12 converted, and passed. An
    unchecked field standing in for a measured one is issue #393's shape one
    layer up, so Patch 24.12a measures it instead of correcting it once.
    """
    for name, family in SH_FAMILIES.items():
        files = list(family["files"])
        taken = [path for path in files if path in TAKEN_OUT_HARNESSES]
        owners = {DEFERRED_HARNESSES[path][0]
                  for path in files if path in DEFERRED_HARNESSES}
        if taken:
            expected = (TAKEN_OUT_BY, "convert")
        elif owners:
            require(len(owners) == 1,
                    f"family {name} defers to more than one owner: "
                    f"{sorted(owners)}")
            expected = (sorted(owners)[0], "retire")
        else:
            # Nothing in this family moved, so there is no outcome to agree
            # with and its declared disposition stands on its own authority.
            continue
        actual = (family["owner_patch"], family["action"])
        require(actual == expected,
                f"family {name} declares {actual[0]}/{actual[1]} but its "
                f"files went {expected[0]}/{expected[1]}")



# ---------------------------------------------------------------------------
# Patch 24.15a (#404): the inverse, over EVERY recipe rather than over the
# inventory's own rows.
#
# IS_LIVE_WITH_NO_EXECUTION_ROUTE above is an enumeration scoped to
# RECIPE_ROWS, so it can only catch a recipe the inventory already lists. Of
# the 55 recipes whose ONLY liveness signal is a registry mention,
# 14 are inventoried and
# 41 are not -- invisible to that check
# entirely. That is the shape #404 names: an enumeration reporting
# completeness over a population that excludes the real case.
#
# This is a SHRINK-ONLY ledger, not an allowlist. A recipe joining it fails,
# because self-enrolment becoming load-bearing is exactly what Patch 24.15's
# registry retirements make possible. A recipe leaving it also fails, so the
# register cannot quietly drift out of step with the tree.
#
# Adjudicating these rows is NOT this patch's job -- TASK.md scopes 24.15a to
# instrument repair and gives the re-scored rows to 24.16, with a different
# falsifier. What lands here is the measurement, taken with an instrument that
# folds dynamic dispatch into the graph, so 24.16 starts from a number that
# means what it says.
MENTION_ONLY_LIVENESS = (
    # Patch 25.10 deletes the C stage chain, and the Makefile target this
    # named went with it: diagnose-phase10-stage1 was a sanitizer build of the
    # stage-one C, and there is no stage one. So it stops being reached by
    # make and becomes live only by the registry naming it, which is what this
    # ledger is for.
    #
    # It is NOT adjudicated as fine. justfile:22 still carries a recipe that
    # runs `make diagnose-phase10-stage1`, so `just diagnose-phase10-stage1`
    # now fails with "No rule to make target" -- a real dangling caller, not
    # bookkeeping. It is left here rather than fixed in this patch because the
    # justfile is append-only (the Patch 24.0c manifest is keyed on line
    # numbers) and Issue #451 freezes its digest in both halves of a pair, so
    # removing two lines from the middle of it is its own patch with its own
    # re-registration. Recorded rather than silently absorbed.
    "diagnose-phase10-stage1",
    # Issue #437 left this one here: it is adjudicated repair_required
    # rather than wired, because it fails when executed, so it still has no
    # execution route and is still live only by mention. Removing it would
    # claim a wiring that did not happen.
    "guard-cranelift-phase11-metadata-diagnostic-parity",
    # Issue #437 removed the other 27 parity recipes from this ledger. That is what the
    # "every removal is an adjudication" clause below asks for: they were not
    # dropped, they were WIRED. Each now has an execution route in
    # .github/workflows/phase24-parity-residue.yml, so it is no longer live
    # by mention alone and no longer belongs here.
    "bootstrap",
    "check",
    "default",
    "gt-one",
    "gt-one-gst",
    "guard-cranelift-branch-native-smoke",
    "guard-cranelift-compiler-mir-ingestion-corpus-surface",
    "guard-cranelift-contract-fast",
    "guard-cranelift-differential-native-smoke",
    "guard-cranelift-experimental-backend-suite-parallel",
    "guard-cranelift-local-binding-read-native-smoke",
    "guard-cranelift-phase10-packaging-help-ci",
    "guard-cranelift-phase11-ci-family",
    "guard-cranelift-phase11-registry-differential",
    "guard-cranelift-phase12-5-opening-contract",
    "guard-cranelift-phase13-composition-differential",
    "guard-cranelift-phase14-composition-differential",
    "guard-cranelift-phase9b-close",
    "guard-cranelift-phase9c-close",
    "guard-cranelift-phase9f-opening-contract",
    "guard-mir-feature-if-else-return-int-preservation",
    "guard-mir-feature-local-binding-read-preservation",
    "guard-mir-feature-local-binding-read-provenance-metadata-preservation",
    "guard-mir-feature-return-int-preservation",
    "phase10-native-package",
    "test",
)

def check_stale_row_scoring(bodies: dict[str, str], workflow_seen: set[str],
                            named_seen: set[str],
                            make_seen: set[str]) -> None:
    """The two registers of known-wrong rows must match what is measured.

    Each is an equality, not a floor: a row that stops being wrong has to
    leave its register, and a newly wrong row fails rather than joining
    silently.
    """
    measured_action = sorted(
        recipe for recipe, needle, owner, action, is_live in RECIPE_ROWS
        if (outcome := row_outcome(recipe, bodies)) is not None
        and (owner, action) != outcome)
    require(measured_action == sorted(ACTION_DISAGREES_WITH_OUTCOME),
            f"the action-disagreement residue moved: measured "
            f"{measured_action}, registered "
            f"{sorted(ACTION_DISAGREES_WITH_OUTCOME)}")

    measured_mention = sorted(
        recipe for recipe, needle, owner, action, is_live in RECIPE_ROWS
        if is_live and recipe in named_seen
        and recipe not in workflow_seen and recipe not in make_seen)
    require(measured_mention == sorted(IS_LIVE_WITH_NO_EXECUTION_ROUTE),
            f"the no-execution-route liveness residue moved: measured "
            f"{measured_mention}, registered "
            f"{sorted(IS_LIVE_WITH_NO_EXECUTION_ROUTE)}")

    # Patch 24.16's adjudication of the PARITY residue, which is what the
    # repaired instrument shows the mention-only population actually is.
    #
    # 28 of the 54 are parity guards -- 12 phase14, 8 phase13, 7 phase11, 1
    # phase20 -- and all 28 share one basis, so they are one class and not 28
    # decisions:
    #
    #   * they exist as justfile recipes (0 of 28 are absent);
    #   * they are UNASSIGNED in cranelift_test_levels.json -- all 28;
    #   * nothing executes them: not a workflow, not the make closure;
    #   * they are "live" only because the feature registry mentions the name.
    #
    # That is a weaker basis than the roadmap's sharpest case. TASK.md says of
    # guard-cranelift-phase20-resource-enforcement-parity that "a bare level
    # assignment is the only thing keeping a known-red, never-executed guard
    # off the orphan list". These have no level assignment AT ALL, and a guard
    # with no level cannot be dispatched by the level-driven runners, so there
    # is no path by which CI reaches them.
    #
    # Pinned rather than retired in this commit. Retiring 28 recipes at once is
    # the same shape as the bulk accept TASK.md warns against for the
    # allowlist: it would discharge the gate by volume rather than by
    # adjudication. What is asserted here is the BASIS -- if any of them gains
    # a level assignment or an executor, this fails and the class has to be
    # re-adjudicated rather than silently shrinking.
    # Issue #437 adjudicates the 28. The verdict is WIRE, so every check
    # here inverts: where Patch 24.16 required these recipes to be
    # unreachable, unlevelled and pending, this requires each to be executed,
    # levelled, and disposed of by a registered verdict.
    #
    # That inversion is the point. 24.16's version made continued
    # unreachability the passing state, which is why #427 flagged it: all 28
    # evidence owners could test nothing and the audit stayed green. Now the
    # audit goes red if any of them stops running.
    parity_residue = sorted(
        recipe for recipe in MENTION_ONLY_LIVENESS if "parity" in recipe)
    levels = json.loads(
        (ROOT / "scripts" / "cranelift_test_levels.json").read_text(
            encoding="utf-8"))["guards"]
    registry_doc = json.loads(REGISTRY.read_text(encoding="utf-8"))
    pending = registry_doc.get("phase24_16_residue_audit", {}).get(
        "parity_residue_adjudication")
    # 24.16's record stays exactly as 24.16 wrote it. It is still true of
    # 24.16 -- these recipes WERE pending then -- and the adjudication links
    # to it rather than editing it.
    require(isinstance(pending, dict) and
            pending.get("contract_version") ==
            "phase24_16_parity_residue_pending_v1" and
            pending.get("status") == "pending_adjudication" and
            pending.get("owner_issue") == 437,
            "Patch 24.16's pending-adjudication record is missing or "
            "reworded; the Issue #437 adjudication is a successor to it, not "
            "a replacement for it")
    adjudication = registry_doc.get("issue437_parity_residue_adjudication")
    require(isinstance(adjudication, dict) and
            adjudication.get("contract_version") ==
            "issue437_parity_residue_adjudication_v1" and
            adjudication.get("predecessor_contract_version") ==
            pending["contract_version"] and
            adjudication.get("partial_or_unregistered_adjudication") ==
            "rejected" and
            adjudication.get("unreachability_is_not_the_end_state") ==
            "discharged",
            "the parity residue has no registered adjudication, so this "
            "audit would pass on the bare fact that 28 guards are "
            "unreachable -- the defect #427 raised")

    wired = sorted(adjudication.get("wired", []))
    retired = sorted(adjudication.get("retired", []))
    # A third verdict, because two were not enough. One of the 28 fails when
    # executed, and neither existing verdict is honest about it: "wired"
    # would turn main red, and dropping it from the disposal to keep CI
    # green is adjudicating by convenience -- the failure this whole check
    # exists to correct.
    #
    # repair_required says what is true: it is still here, still
    # dispatchable, deliberately not yet executed, and owned. It is a far
    # smaller claim than 24.16's blanket pending -- one recipe, reproduced
    # and diagnosed to a named field -- and it carries the finding so the
    # next reader does not start from scratch.
    repair = sorted(adjudication.get("repair_required", []))
    # Every pending recipe must get exactly one verdict. A recipe in neither
    # list has been dropped from the adjudication silently; one in both is
    # incoherent. Either way the disposal is partial, which the contract
    # rejects by name.
    require(sorted(set(wired) | set(retired) | set(repair)) ==
            sorted(pending.get("recipes", [])),
            "the adjudication does not dispose of exactly the pending set: "
            f"{sorted((set(wired) | set(retired) | set(repair)) ^ set(pending.get('recipes', [])))[:6]}")
    require(len(wired) + len(retired) + len(repair) ==
            len(set(wired) | set(retired) | set(repair)),
            "a recipe carries more than one verdict: "
            f"{sorted((set(wired) & set(retired)) | (set(wired) & set(repair)) | (set(retired) & set(repair)))}")

    adjudicated_bodies = recipe_bodies()
    for recipe in wired:
        # The inversion, stated three ways, because "wired" is a claim about
        # three different things and a recipe can lose any one of them
        # independently: it must still exist, still be dispatchable, and
        # still be reached by something that runs.
        require(recipe in adjudicated_bodies,
                f"a recipe adjudicated WIRE is gone from the justfile: "
                f"{recipe}. Retiring it is a different verdict and needs "
                "re-adjudication, not a deletion.")
        require(recipe in levels,
                f"a recipe adjudicated WIRE has no level assignment: "
                f"{recipe}, so the level-driven runners cannot dispatch it")
        require(recipe in workflow_seen or recipe in make_seen,
                f"a recipe adjudicated WIRE is not executed by anything: "
                f"{recipe}. The verdict was to give it an execution route; "
                "without one the adjudication is a word in the registry.")
    for recipe in repair:
        # Deliberately NOT executed, and that has to be checked in both
        # directions. It must still be here and still dispatchable, so the
        # verdict cannot be used to quietly park a recipe; and it must not
        # be in the executor, so a red guard cannot reach main by being
        # added to a shard without re-adjudication.
        require(recipe in adjudicated_bodies and recipe in levels,
                "a recipe adjudicated repair_required is gone or unlevelled: "
                f"{recipe}. That is a retirement, and it needs that verdict.")
        require(recipe not in workflow_seen and recipe not in make_seen,
                "a recipe adjudicated repair_required is executed: "
                f"{recipe}. It is known red; wiring it needs the repair "
                "first and a new verdict after it.")
    require(bool(adjudication.get("repair_required_finding")) == bool(repair),
            "a repair_required verdict carries no finding, so the next "
            "reader has to rediscover why it is red")

    for recipe in retired:
        require(recipe not in adjudicated_bodies,
                f"a recipe adjudicated RETIRE is still in the justfile: "
                f"{recipe}")
        require(recipe not in workflow_seen and recipe not in make_seen,
                f"a recipe adjudicated RETIRE is still executed: {recipe}")

    # The residue is exactly the repair_required set -- not empty, and not
    # whatever happens to be left. A wired recipe falling back into it has
    # lost the execution route the adjudication gave it; a repair_required
    # one leaving it has been wired without the repair.
    require(parity_residue == repair,
            "the mention-only parity residue is not the repair_required "
            f"set: {parity_residue} against {repair}. A wired recipe here "
            "has lost its execution route; a repair_required recipe missing "
            "from here has been wired while still red.")

    # The execution route is checked against the file that provides it, not
    # taken on the registry's word. A workflow that stopped naming a wired
    # recipe would otherwise leave the liveness signal to whatever else
    # happened to reach it.
    executor = ROOT / str(adjudication.get("executor_workflow", ""))
    require(executor.is_file(),
            "the registered executor workflow is missing: "
            f"{adjudication.get('executor_workflow')}")
    executor_text = executor.read_text(encoding="utf-8")
    unnamed = [recipe for recipe in wired
               if f"just {recipe}" not in executor_text]
    require(not unnamed,
            f"the executor workflow does not run every wired recipe: "
            f"{unnamed[:6]}")

    # Patch 24.16's adjudication of the native-smoke population.
    #
    # TASK.md expected this to be the phase's weak point: "Most of the 43 are
    # *-native-smoke recipes ... so they bear on the phase's premise: Phase 24
    # removes the C backend on the grounds that the native route is qualified,
    # and part of that evidence is guards nothing runs."
    #
    # Measured on the REPAIRED instrument, that is substantially not the case.
    # The 43 was counted before 24.15a folded dynamic dispatch into the graph;
    # doing so recovered the native smokes as genuinely reached. The residue is
    # concentrated in parity guards instead, and the premise is in better shape
    # than the roadmap feared -- which is exactly the kind of thing a repaired
    # instrument is supposed to be able to say.
    #
    #   native-smoke recipes known : 96
    #   workflow-reachable         : 93
    #   mention-only               :  3
    #
    # guard-cranelift-mir-to-c-differential-native-smoke, named in the roadmap
    # as bearing on the premise, is workflow-reachable.
    #
    # Pinned as a floor rather than an equality: new smokes may be added, but
    # the reached population may not silently shrink back.
    smokes = {recipe for recipe in (workflow_seen | named_seen | make_seen)
              if recipe.endswith("-native-smoke")}
    reached = smokes & (workflow_seen | make_seen)
    require(
        len(reached) >= 93,
        f"the native-smoke population that something executes shrank to "
        f"{len(reached)} of {len(smokes)}. Phase 24 removes the C backend on "
        "the grounds that the native route is qualified; that evidence cannot "
        "be guards nothing runs.",
    )
    require(
        "guard-cranelift-mir-to-c-differential-native-smoke" in reached,
        "the MIR-to-C differential native smoke is no longer executed by "
        "anything, and TASK.md names it as bearing on the phase's premise",
    )

    # #404's inverse: no recipe may be live SOLELY because a registry names it.
    # Asserted over every recipe, not over the inventory's own rows, because an
    # enumeration scoped to RECIPE_ROWS cannot see the 41 that are not in it.
    mention_only = sorted(named_seen - workflow_seen - make_seen)
    joined = sorted(set(mention_only) - set(MENTION_ONLY_LIVENESS))
    left = sorted(set(MENTION_ONLY_LIVENESS) - set(mention_only))
    require(not joined,
            "a recipe became live solely because a registry names it: "
            f"{joined}. Self-enrolment is not an execution route; register it "
            "with a reason or give it a caller.")
    require(not left,
            "a recipe left the mention-only ledger without the register "
            f"being updated: {left}. This ledger is shrink-only and every "
            "removal is an adjudication, which is Patch 24.16's job.")

    require(STALE_SCORING_OWNER not in ("24.12", "24.12a"),
            "the stale-row residue must be owned by a patch that can still "
            "fix it")

    # Each unowned surface must still exist, still lack a row, and still
    # name an owner that can act. A surface that acquires a row has to leave
    # this register rather than sit in it as a stale claim.
    rowed = ({recipe for recipe, _, _, _, _ in RECIPE_ROWS}
             | {workflow for workflow, _, _, _ in WORKFLOW_ROWS}
             | {key for key, _, _ in REGISTRY_ROWS}
             | {path for path, _, _, _ in FILE_ROWS}
             | {path for path, _, _ in SCRIPT_ROWS})
    for row in UNOWNED_SURFACES:
        surface = row["surface"]
        require((ROOT / surface).exists(),
                f"a registered unowned surface is missing: {surface}")
        require(surface not in rowed,
                f"{surface} now has an inventory row and must leave the "
                f"unowned register")
        require(row["owner"] not in ("24.12", "24.12a") and row["why"],
                f"{surface} is registered without an owner that can act, or "
                f"without a reason")
    require(HARNESS_CALL_BLIND_SPOT_OWNER not in ("24.12", "24.12a"),
            "the harness-caller blind spot must be owned by a patch that can "
            "still repair it")


def build_rows() -> list[dict[str, str]]:
    """The inventory's rows, derived. Extracted so the projector and the
    validator cannot drift apart by building them two different ways."""
    return ([{"id": recipe,
              "owner_patch": TAKEN_OUT_BY if recipe in TAKEN_OUT_RECIPES
                             else owner,
              "action": TAKEN_OUT_RECIPES.get(recipe, action)}
             for recipe, _, owner, action, _ in RECIPE_ROWS]
            + [{"id": workflow, "owner_patch": owner, "action": action}
               for workflow, _, owner, action in WORKFLOW_ROWS]
            + [{"id": key, "owner_patch": owner, "action": action}
               for key, owner, action in REGISTRY_ROWS]
            + [{"id": f"{path} :: {needle[:40]}", "owner_patch": owner,
                 "action": action}
               for path, needle, owner, action in FILE_ROWS]
            + family_rows()
            + [{"id": "smoke-fixtures", "owner_patch": "24.16",
                "action": "retire"}]
            + [{"id": path, "owner_patch": owner, "action": action}
               for path, owner, action in SCRIPT_ROWS])


def tracked_text_paths() -> list[str]:
    """Every tracked file, so a reference sweep cannot be scoped by suffix."""
    result = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT,
                            check=True, stdout=subprocess.PIPE)
    return [p for p in result.stdout.decode().split("\0") if p]


def expected_sweep() -> dict[str, int]:
    expected = dict(SWEEP_COUNTS)
    for family in SH_FAMILIES.values():
        if family.get("match") == "route":
            continue
        for path, count in family["files"].items():
            # Same rule as the converted harnesses below, and for the same
            # reason: check_sweep only reports loci with at least one hit, so
            # a family file whose live-C arms are all gone has to leave the
            # expectation rather than sit at zero, which would expect a key
            # the sweep will never produce.
            if count:
                expected[path] = count
            else:
                expected.pop(path, None)
    # check_sweep only reports loci with at least one hit, so a converted
    # harness must leave the expectation entirely rather than sit at zero.
    for path, residual in TAKEN_OUT_HARNESSES.items():
        if residual:
            expected[path] = residual
        else:
            expected.pop(path, None)
    # Issue #398's two registers, by the same rule. The converted harnesses
    # all land at zero and leave the expectation; the inverted one keeps its
    # spelling and stays in it, which is what makes the sweep still able to
    # notice if that probe ever grows a second invocation.
    for path, residual in ISSUE398_CONVERTED_HARNESSES.items():
        if residual:
            expected[path] = residual
        else:
            expected.pop(path, None)
    for path, residual in ISSUE398_INVERTED_HARNESSES.items():
        if residual:
            expected[path] = residual
        else:
            expected.pop(path, None)
    return expected


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    node = registry.get("phase24_retirement_consumer_inventory")
    require(isinstance(node, dict), "retirement inventory node is missing")
    require(node.get("version") == VERSION and
            node.get("status") == STATUS and
            node.get("authority_base_main") == BASE_MAIN and
            node.get("authority_owner") ==
            "scripts/cranelift_feature_registry.json",
            "retirement inventory identity drifted")
    require(node.get("bootstrap_entry_decision") ==
            BOOTSTRAP_ENTRY_DECISION,
            "bootstrap-entry decision drifted")

    bodies = recipe_bodies()
    workflow_seen, named_seen, make_seen = liveness()
    live = workflow_seen | named_seen | make_seen
    check_family_actions()
    check_stale_row_scoring(bodies, workflow_seen, named_seen, make_seen)
    for recipe in RETIRED_RECIPES:
        require(recipe not in bodies,
                f"a recipe Patch {RETIRED_BY} retired is back: {recipe}")
    for harness in RETIRED_HARNESSES:
        require(not (ROOT / harness).exists(),
                f"a harness Patch {RETIRED_BY} retired is back: {harness}")
        require(harness not in DEFERRED_HARNESSES,
                f"a retired harness is still registered as deferred: "
                f"{harness}")
    # Nothing may still call a retired harness, over every tracked file
    # rather than one population.
    #
    # This exists because deleting the seven left
    # scripts/phase19_brand_authority_parity.sh -- a *surviving* harness --
    # calling two of them, and the guard died at exit 127, command not found.
    # It was missed because one sweep covered scripts/*.py and another
    # covered justfile recipe bodies, and a shell harness calling another
    # shell harness is in neither. That is the same defect as #390, #393,
    # #395 and #396: an enumeration reporting completeness over a population
    # that excludes the real case. Here it bit the patch rather than the
    # repo, so the fix is to stop scoping the sweep by file type.
    #
    # A guard that dies at 127 proves nothing about the invariant it names,
    # which is this phase's own "absence never counts as success" rule
    # arriving as a missing file rather than a skipped test.
    # Files that record the retirement rather than depend on it. Named
    # individually, because excluding by suffix is the mistake this sweep
    # exists to correct.
    recorders = {
        "scripts/phase24_retirement_consumer_inventory.py",
        "docs/PHASE24_RETIREMENT_CONSUMER_INVENTORY.md",
        "scripts/cranelift_feature_registry.json",
        # The projected text-surface census. Patch 24.12a's projection puts
        # removed surfaces back before the pinned unchanged-other digest is
        # computed over them, so this document lists the retired harnesses by
        # construction. A mention here is the projection working, not a
        # dangling reference -- and the census would be seven rows short
        # without it.
        "compiler/CRANELIFT_PHASE23_MIR_TO_C_DEPRECATION_OPENING.md",
        # Inverse-assertion sites: these name a retired harness precisely in
        # order to require that it is gone. Excluding them is not a hole --
        # a reference that asserts absence is the opposite of a dangling
        # call, and their own guards fail if the harness returns.
        "scripts/phase21_inert_scoped_query_records.py",
        "scripts/phase19_closure.py",
    }
    for path in tracked_text_paths():
        if path in recorders:
            continue
        try:
            body = read(path)
        except (OSError, UnicodeDecodeError):
            # A tracked binary cannot call anything. Skipping it is not a
            # scoped-by-suffix exclusion: it is the only file class that
            # cannot hold a reference at all.
            continue
        for harness in RETIRED_HARNESSES:
            require(harness not in body,
                    f"{path} still references a harness Patch {RETIRED_BY} "
                    f"retired: {harness}")

    for recipe, needle, owner, action, is_live in RECIPE_ROWS:
        require(recipe in bodies, f"inventoried recipe is missing: {recipe}")
        if recipe in BOOTSTRAP_ROUTED_RECIPES:
            require(needle not in bodies[recipe],
                    f"a recipe Patch 24.13 routed to the bootstrap entry has "
                    f"its C route back: {recipe}")
            require(BOOTSTRAP_ROUTE_NEEDLE in bodies[recipe],
                    f"a recipe Patch 24.13 routed to the bootstrap entry does "
                    f"not select it: {recipe}")
            require(NATIVE_ROUTE_NEEDLE not in bodies[recipe],
                    f"a recipe registered as bootstrap-routed also takes the "
                    f"native route, so it belongs in NATIVE_ROUTED_RECIPES: "
                    f"{recipe}")
        elif recipe in DELEGATED_ROUTE_RECIPES:
            require(needle not in bodies[recipe],
                    f"a recipe Patch 25.10c routed to the evidence arm has "
                    f"its C route back: {recipe}")
            require(BOOTSTRAP_ROUTE_NEEDLE not in bodies[recipe],
                    f"a delegating recipe reaches the retired emitter "
                    f"spelling again: {recipe}")
            require(DELEGATED_ROUTE_NEEDLE in bodies[recipe],
                    f"a recipe registered as delegating does not call the "
                    f"evidence arm, so it delegates to nothing: {recipe}")
        elif recipe in NATIVE_ROUTED_RECIPES:
            require(needle not in bodies[recipe],
                    f"a recipe Patch 24.13 routed natively has its C route "
                    f"back: {recipe}")
            require(NATIVE_ROUTE_NEEDLE in bodies[recipe],
                    f"a recipe Patch 24.13 routed natively does not select "
                    f"the surviving backend: {recipe}")
        elif recipe in TAKEN_OUT_RECIPES:
            require(needle not in bodies[recipe],
                    f"a recipe Patch {TAKEN_OUT_BY} took out has its C route "
                    f"back: {recipe}")
            require(FROZEN_ORACLE_CALL in bodies[recipe],
                    f"a recipe Patch {TAKEN_OUT_BY} took out does not reach "
                    f"the frozen oracle: {recipe}")
        elif recipe in ISSUE398_CONVERTED_RECIPES:
            require(needle not in bodies[recipe],
                    f"a recipe Issue {ISSUE398_CONVERTED_BY} converted has "
                    f"its C route back: {recipe}")
            require(FROZEN_ORACLE_CALL in bodies[recipe],
                    f"a recipe Issue {ISSUE398_CONVERTED_BY} converted does "
                    f"not reach the frozen oracle: {recipe}")
        else:
            require(needle in bodies[recipe],
                    f"inventoried recipe lost its C route: {recipe}")
        require((recipe in live) == is_live,
                f"recipe liveness changed without inventory update: {recipe}")
    for workflow, needle, owner, action in WORKFLOW_ROWS:
        text = read(f".github/workflows/{workflow}")
        require(needle in text,
                f"inventoried workflow lost its C reference: {workflow}")
    for key, owner, action in REGISTRY_ROWS:
        require(isinstance(registry.get(key), dict),
                f"inventoried registry node is missing: {key}")
    check_retired_registry_claims(registry)
    # Patch 25.10 is the owner these rows were waiting for. Five of them --
    # four marked owner "25" and one Makefile row 24.14 marked "migrate" --
    # name surfaces this patch removes, so requiring them PRESENT would ask
    # the tree to keep the thing the inventory exists to retire.
    #
    # The rows are kept and their ACTION is what changes, following the
    # retired-claim rule above: "the record survives; only the claim is
    # retired, so deleting it asserts nothing". A retired row now requires
    # ABSENCE -- and where the whole file went, that the file went. So a
    # surface coming back fails, and so does a row that claims a retirement
    # that did not happen.
    for path, needle, owner, action in FILE_ROWS:
        if action.startswith("retired-by-25.10"):
            if not (ROOT / path).is_file():
                continue
            require(needle not in read(path),
                    f"a surface Patch 25.10 retires is back: {path}: "
                    f"{needle[:48]}")
            continue
        require(needle in read(path),
                f"inventoried file lost its C surface: {path}: {needle[:48]}")
    for path, needle, owner in RETIRED_FILE_SURFACES:
        require(needle not in read(path),
                f"Patch {owner} retired this surface, but it is back: "
                f"{path}: {needle[:48]}")
    for path, needle, owner in REBASED_FILE_SURFACES:
        require(needle in read(path),
                f"Patch {owner} rebased this surface onto a surviving reason, "
                f"but that is gone too: {path}: {needle[:48]}")
    for family_name, family in SH_FAMILIES.items():
        for path, count in family["files"].items():
            text = read(path)
            if family.get("match") == "route":
                hits = text.count("mir-to-c")
            else:
                hits = len(BACKEND_SPELLING.findall(text))
            if path in ISSUE398_RUNNER_CONVERTED:
                expected = ISSUE398_RUNNER_CONVERTED[path]
                asks = text.count(RETIRED_ROUTE_REQUEST)
                require(asks == expected,
                        f"a runner-pinned harness Issue #398 converted asks "
                        f"for the retired route {asks} times, {expected} "
                        f"registered: {path}")
                require(RETIRED_ROUTE_REFUSAL in text,
                        f"a runner-pinned harness Issue #398 converted asks "
                        "for the retired route without asserting that the "
                        f"request is refused: {path}")
                require(FROZEN_ORACLE_CALL in text,
                        f"a runner-pinned harness Issue #398 converted does "
                        f"not replay the evidence it stopped producing: "
                        f"{path}")
            elif path in ISSUE398_CONVERTED_HARNESSES:
                expected = ISSUE398_CONVERTED_HARNESSES[path]
                require(hits == expected,
                        f"a harness Issue #398 converted carries {hits} live "
                        f"C spellings, {expected} registered: {path}")
                require(FROZEN_ORACLE_CALL in text,
                        "a harness Issue #398 converted does not reach the "
                        f"frozen oracle: {path}")
            elif path in ISSUE398_INVERTED_HARNESSES:
                expected = ISSUE398_INVERTED_HARNESSES[path]
                require(hits == expected,
                        f"a harness Issue #398 inverted carries {hits} live "
                        f"C spellings, {expected} registered: {path}")
                require(REMOVAL_MARKER in text.lower(),
                        f"the spelling Issue #398 left in {path} does not "
                        "assert the Phase 24 removal, so it reads as a live "
                        "consumer rather than an inverted probe")
            elif path in TAKEN_OUT_HARNESSES:
                require(hits == TAKEN_OUT_HARNESSES[path],
                        f"a harness Patch {TAKEN_OUT_BY} converted carries "
                        f"{hits} live C spellings, "
                        f"{TAKEN_OUT_HARNESSES[path]} registered: {path}")
                require(FROZEN_ORACLE_CALL in text,
                        f"a harness Patch {TAKEN_OUT_BY} converted does not "
                        f"reach the frozen oracle: {path}")
            else:
                require(hits == count,
                        f"harness family drifted: {path}")
                if path in DISCHARGED_HARNESSES:
                    patch, _reason = DISCHARGED_HARNESSES[path]
                    require(hits == 0 or
                            REMOVAL_MARKER in text.lower(),
                            f"Patch {patch} discharged this harness, but it "
                            f"still carries {hits} live-C spellings without "
                            "asserting the Phase 24 removal anywhere -- the "
                            f"route was dropped, not inverted: {path}")
                require(path not in DEFERRED_HARNESSES or hits > 0,
                        f"a harness deferred to "
                        f"{DEFERRED_HARNESSES.get(path, ('', ''))[0]} lost "
                        f"its C route outside that patch: {path}")
    for path in SMOKE_FIXTURES:
        require((ROOT / path).is_file(),
                f"inventoried smoke fixture is missing: {path}")
    for path, owner, action in SCRIPT_ROWS:
        require((ROOT / path).is_file(),
                f"inventoried guard script is missing: {path}")

    check_native_linker_driver()
    counts = check_sweep()
    require(counts == expected_sweep(),
            f"live C sweep moved without inventory update: "
            f"{sorted(set(counts) ^ set(expected_sweep()))}")
    # Issue #396: pin the reference forms before trusting the sweep that
    # reads them. An unaccounted form fails here rather than silently
    # exempting its recipe from ever needing a row.
    check_harness_reference_forms(bodies)
    check_harness_callers(
        bodies, {recipe for recipe, _, _, _, _ in RECIPE_ROWS})

    rows = build_rows()
    owners = sorted({row["owner_patch"] for row in rows})
    # Patch 24.12a discharged every row it owned, so it leaves this set. A
    # patch that finishes its rows should stop appearing here; one that
    # acquires rows must be added deliberately.
    # Patch 24.12b acquires rows -- the thirteen Python loci, which had none
    # -- so it is added deliberately, which is what this pin is for. "24.3"
    # joins for one row: the filename-behaviour characterization carries the
    # retired spelling as data in a route table whose subject is
    # route-dependence, and Patch 24.3 is the carried future work that owns
    # correcting it. Naming 24.16 there instead would have been tidier and
    # false.
    # Issue #451 adds "phase25" for the two justfile products that compile
    # emitter output and retire with the emitter at Patch 25.10. "25"
    # already appears, but `inventory_owner` only accepts `24.N`,
    # `stdlib-coordination` or `phase25`, so a row owned "25" is invisible
    # to the provenance guard asking who owns a site. Both spellings are
    # kept rather than unified: renaming existing rows is a separate change
    # with its own evidence.
    require(owners == ["24.12", "24.12b", "24.13", "24.14", "24.15", "24.16",
                       "24.3", "25", "phase25", "stdlib-coordination"],
            f"inventory owner set drifted: {owners}")
    require(RETIRED_BY not in owners,
            f"Patch {RETIRED_BY} still owns inventory rows after retiring "
            f"everything it was given: {RETIRED_BY}")
    require(node.get("rows") == rows, "registered inventory rows drifted")
    require(node.get("row_count") == len(rows) and
            node.get("inventory_digest") == digest(rows),
            "registered inventory counts drifted")
    require(node.get("stale_row_scoring") == {
        "owner": STALE_SCORING_OWNER,
        "action_disagrees_with_outcome":
            list(ACTION_DISAGREES_WITH_OUTCOME),
        "is_live_with_no_execution_route": list(IS_LIVE_WITH_NO_EXECUTION_ROUTE),
    }, "the registered stale-row residue drifted")
    require(node.get("unowned_surfaces") == {
        "harness_call_blind_spot_owner": HARNESS_CALL_BLIND_SPOT_OWNER,
        "surfaces": [dict(row) for row in UNOWNED_SURFACES],
    }, "the registered unowned-surface residue drifted")
    require(node.get("retired") == {
        "by": RETIRED_BY,
        "recipes": list(RETIRED_RECIPES),
        "harnesses": list(RETIRED_HARNESSES),
    }, "the registered retirement record drifted")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 24.11 — Generated-C Consumer and Route Inventory — DONE"
            in task, "TASK status does not mark Patch 24.11 DONE")

    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD) == 1, "test-level assignment drifted")
    just = read("justfile")
    require(f"{GUARD}:" in just, "just guard reachability drifted")
    return node


def render(node: dict) -> str:
    decision = node["bootstrap_entry_decision"]
    lines = [
        "# Phase 24.11 — Generated-C Consumer and Route Inventory",
        "",
        "<!-- Generated by scripts/phase24_retirement_consumer_inventory.py",
        "     from the live tree. Do not edit by hand; update the script",
        "     rows and regenerate. -->",
        "",
        f"Status: `{node['status']}`",
        f"Authority base: `{node['authority_base_main']}`",
        f"Rows: `{node['row_count']}`",
        f"Digest: `{node['inventory_digest']}`",
        "",
        "## Bootstrap-entry decision",
        "",
        f"- State: `{decision['current_state']}`",
        f"- Selected entry: `{decision['selected_entry']}`",
        f"- Dispatch: `{decision['selected_dispatch']}`",
        f"- Advertised in help: `{decision['advertised_in_help']}`",
        "",
        "### Current callers (all user-facing selection today)",
        "",
    ]
    for caller in decision["current_callers"]["makefile_cli_spelling_callers"]:
        lines.append(f"- `{caller}`")
    lines += [
        f"- selection `{decision['current_callers']['selection']}` at "
        f"`{decision['current_callers']['dispatch']}`, emitting at "
        f"`{decision['current_callers']['emitter']}`",
        "",
        "### Rejected",
        "",
    ]
    for name, reason in decision["rejected"].items():
        lines.append(f"- `{name}`: {reason}")
    lines += [
        "",
        "### Falsifiers",
        "",
    ]
    for falsifier in decision["falsifiers"]:
        lines.append(f"- {falsifier}")
    lines += [
        "",
        "## Rows by owning patch",
        "",
    ]
    by_owner: dict[str, list[str]] = {}
    for row in node["rows"]:
        by_owner.setdefault(row["owner_patch"], []).append(
            f"{row['id']} ({row['action']})")
    for owner in sorted(by_owner):
        lines.append(f"### {owner}")
        lines.append("")
        for item in sorted(by_owner[owner]):
            lines.append(f"- {item}")
        lines.append("")
    return "\n".join(lines)


def check_review(node: dict) -> None:
    require(VIEW.read_text(encoding="utf-8") == render(node),
            "generated inventory review is stale; run render")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "render", "check-review"))
    args = parser.parse_args()
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    node = validate()
    if args.command == "render":
        VIEW.write_text(render(node), encoding="utf-8")
        validate()
        print(f"{GUARD}: render ok")
    elif args.command == "check-review":
        check_review(node)
        print(f"{GUARD}: review current")
    else:
        print(f"{GUARD}: ok")


if __name__ == "__main__":
    main()
