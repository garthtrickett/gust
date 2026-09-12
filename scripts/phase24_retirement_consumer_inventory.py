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

SWEEP_LOCI = ["Makefile", "justfile", "justfile-step51",
              "compiler/test_runner_entry.gst"]

# Exact per-file spelling counts for sweep loci with more than one shape.
# Single-shape loci are pinned by their row checks; the sweep asserts the
# total per file so a new C route in a known file still fails.
SWEEP_COUNTS = {
    "Makefile": 5,
    "compiler/test_runner_entry.gst": 2,
    "justfile": 38,
    "justfile-step51": 3,
    "tests/e2e_codegen_assertions.gst": 4,
    "tests/test_runner.gst": 2,
    "scripts/run-gust-file.sh": 1,
}

# Differential .sh harness families: exact file set with per-file hit
# counts. Phase suffix selects the owner: live differentials convert under
# 24.12, closed-phase evidence retires under 24.12 as superseded live-C
# execution, Stdlib-owned harnesses migrate under stdlib-coordination.
SH_FAMILIES = {
    "early-differential": {
        "owner_patch": "24.12",
        "action": "retire",
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
        "action": "retire",
        "files": {
            "scripts/phase15_resource_composition_parity.sh": 2,
            "scripts/phase16_abi_composition_parity.sh": 2,
        },
    },
    "phase19-parity": {
        "owner_patch": "24.12",
        "action": "retire",
        "files": {
            "scripts/phase19_classification_parity.sh": 1,
            "scripts/phase19_composition_parity.sh": 2,
            "scripts/phase19_gust_name_list_removed_parity.sh": 1,
            "scripts/phase19_rename_invariance.sh": 1,
            "scripts/phase19_representation_parity.sh": 1,
            "scripts/phase19_rule_convergence_parity.sh": 1,
            "scripts/phase19_type_naming_parity.sh": 1,
        },
    },
    "phase20-evidence": {
        "owner_patch": "24.12",
        "action": "retire",
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
            "scripts/phase20_resource_declaration_migration.sh": 2,
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
            "scripts/phase21_inert_scoped_query_records.sh": 1,
            "scripts/phase21_od8_adversarial_verdict.sh": 2,
            "scripts/phase21_opening.sh": 2,
            "scripts/phase21_per_root_obligations.sh": 2,
            "scripts/phase21_resource_sync_native_source.sh": 2,
            "scripts/phase21_trusted_scope_provenance.sh": 3,
            "scripts/phase21_typed_query_noop_surface.sh": 2,
        },
    },
    "phase22-flip-evidence": {
        "owner_patch": "24.12",
        "action": "retire",
        "files": {
            "scripts/phase22_default_native_package.sh": 2,
            "scripts/phase22_explicit_c_migration.sh": 6,
            "scripts/phase22_native_implicit_output.sh": 2,
            "scripts/phase22_opening.sh": 2,
            "scripts/phase22_postflip_qualification.sh": 3,
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
    ("run-step52-positive-batch",
     "./gust --backend mir-to-c tests/test_runner.gst", "24.16", "retire", False),
    ("guard-positive",
     './gust --backend mir-to-c "$test_path"', "24.13", "migrate", True),
    ("guard-compile-pass",
     './gust --backend mir-to-c "$test_path"', "24.16", "retire", False),
    ("guard-compile-fail",
     './gust --backend mir-to-c "$test_path"', "24.16", "retire", False),
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

REGISTRY_ROWS = [
    # Live generated-C registry nodes retired or updated under 24.15. The
    # archived corpus node survives as the parity authority with its live-C
    # references updated, per the oracle-replacement contract.
    ("phase23_mir_to_c_deprecation_opening", "24.15", "retire"),
    ("phase23_mir_to_c_frozen_surface", "24.15", "retire"),
    ("phase23_mir_to_c_focused_live", "24.15", "retire"),
    ("phase23_mir_to_c_archived_corpus", "24.15", "update"),
]

FILE_ROWS = [
    # (path, needle, owner_patch, action)
    ("compiler/test_runner_entry.gst",
     "    MirToC,", "24.13", "retire"),
    ("compiler/test_runner_entry.gst",
     'std.str_eq(backend_name, "mir-to-c")', "24.13", "retire"),
    ("compiler/test_runner_entry.gst",
     "gust --backend mir-to-c <source.gst>", "24.13", "retire"),
    ("compiler/test_runner_entry.gst",
     "the MIR-to-C backend does not accept -o", "24.14", "retire"),
    ("compiler/test_runner_entry.gst",
     "mut c_code := codegen.codegen_generate(programs, module_prefixes, &env, ctx);",
     "25", "survive"),
    ("compiler/codegen.gst",
     "func codegen_generate(programs: std.Vector[ast.Program[ctx], ctx]",
     "25", "survive"),
    ("compiler/test_runner_bootstrap_bridge_entry.gst",
     "mut c_code := codegen.codegen_generate(programs, module_prefixes, &env, ctx);",
     "25", "survive"),
    ("compiler/test_runner_bootstrap_bridge_entry.gst",
     "Usage: gust-bootstrap-bridge [--backend <mir-to-c|c>] <file.gst>",
     "25", "survive"),
    ("Makefile",
     "build/gust_final.c", "24.14", "migrate"),
    ("Makefile",
     'CC="${CC}" CFLAGS="${CFLAGS}" INCLUDES="${INCLUDES}" just make-test-suite',
     "24.14", "migrate"),
    ("scripts/run-gust-file.sh",
     'RUNNER_ROUTE="${GUST_RUNNER_ROUTE:-mir-to-c}"', "24.13", "migrate"),
    ("tests/test_runner.gst",
     'std.Concat("./gust --backend mir-to-c ", path)', "24.13", "migrate"),
    ("tests/e2e_codegen_assertions.gst",
     '"./gust --backend mir-to-c tests/codegen_helper_pod_move.gst', "24.12", "convert"),
    ("README.md",
     "selected explicitly with `--backend c`", "24.15", "retire"),
    ("compiler/experiments/cranelift/README.md",
     "Explicit `--backend c` / `--backend mir-to-c`", "24.15", "retire"),
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
]


def liveness() -> tuple[set[str], set[str]]:
    """Workflow-reachable, CI-family registry-named, and make-test closure.

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
    edges: dict[str, list[str]] = {}
    for text in module.justfile_sources(ROOT / "justfile"):
        update, _ = module.parse_justfile(text)
        edges.update(update)
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
    return set(module.reachable(edges, roots)), named | set(
        module.reachable(edges, make_roots))


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


def expected_sweep() -> dict[str, int]:
    expected = dict(SWEEP_COUNTS)
    for family in SH_FAMILIES.values():
        if family.get("match") == "route":
            continue
        expected.update(family["files"])
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
    workflow_seen, named_seen = liveness()
    live = workflow_seen | named_seen

    for recipe, needle, owner, action, is_live in RECIPE_ROWS:
        require(recipe in bodies, f"inventoried recipe is missing: {recipe}")
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
    for path, needle, owner, action in FILE_ROWS:
        require(needle in read(path),
                f"inventoried file lost its C surface: {path}: {needle[:48]}")
    for family_name, family in SH_FAMILIES.items():
        for path, count in family["files"].items():
            text = read(path)
            if family.get("match") == "route":
                hits = text.count("mir-to-c")
            else:
                hits = len(BACKEND_SPELLING.findall(text))
            require(hits == count,
                    f"harness family drifted: {path}")
    for path in SMOKE_FIXTURES:
        require((ROOT / path).is_file(),
                f"inventoried smoke fixture is missing: {path}")
    for path, owner, action in SCRIPT_ROWS:
        require((ROOT / path).is_file(),
                f"inventoried guard script is missing: {path}")

    counts = check_sweep()
    require(counts == expected_sweep(),
            f"live C sweep moved without inventory update: "
            f"{sorted(set(counts) ^ set(expected_sweep()))}")

    rows = ([{"id": recipe, "owner_patch": owner, "action": action}
             for recipe, _, owner, action, _ in RECIPE_ROWS]
            + [{"id": workflow, "owner_patch": owner, "action": action}
               for workflow, _, owner, action in WORKFLOW_ROWS]
            + [{"id": key, "owner_patch": owner, "action": action}
               for key, owner, action in REGISTRY_ROWS]
            + [{"id": f"{path} :: {needle[:40]}", "owner_patch": owner,
                 "action": action}
               for path, needle, owner, action in FILE_ROWS]
            + [{"id": f"sh-family:{name}", "owner_patch": family["owner_patch"],
                "action": family["action"]} for name, family in
               SH_FAMILIES.items()]
            + [{"id": "smoke-fixtures", "owner_patch": "24.16",
                "action": "retire"}]
            + [{"id": path, "owner_patch": owner, "action": action}
               for path, owner, action in SCRIPT_ROWS])
    owners = sorted({row["owner_patch"] for row in rows})
    require(owners == ["24.12", "24.13", "24.14", "24.15", "24.16", "25",
                       "stdlib-coordination"],
            f"inventory owner set drifted: {owners}")
    require(node.get("rows") == rows, "registered inventory rows drifted")
    require(node.get("row_count") == len(rows) and
            node.get("inventory_digest") == digest(rows),
            "registered inventory counts drifted")

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
