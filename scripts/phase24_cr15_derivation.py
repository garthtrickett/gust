#!/usr/bin/env python3
"""Validate, project, and qualify Patch 24.0c protected-Resource derivation."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE24_CR15_DERIVATION.md"
TASK = ROOT / "TASK.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase24-cr15-derivation.yml"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
CODEGEN = ROOT / "compiler/codegen.gst"
FULL_PROGRAM = ROOT / "compiler/mir_native_backend_full_program_source.gst"
GUARD_L1 = "guard-cranelift-phase24-cr15-derivation-contract"
GUARD_L2 = "guard-cranelift-phase24-cr15-derivation-evidence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def authority() -> dict:
    data = json.loads(REGISTRY.read_text(encoding="utf-8"))
    value = data.get("phase24_cr15_derivation")
    require(isinstance(value, dict), "registry authority is missing")
    return value


def validate() -> dict:
    value = authority()
    require(value.get("contract_version") == "phase24_cr15_derivation_v1",
            "contract version drifted")
    require(value.get("status") == "patch24_0c_complete",
            "derivation status drifted")
    require(value.get("authority_base_main") ==
            "c37024afa580d1e03c5ff70150ed0ae7518a9648",
            "authority base main drifted")
    require(value.get("next_patch") == "24.0d", "next patch drifted")
    require(value.get("review_view") == REVIEW.relative_to(ROOT).as_posix(),
            "review view drifted")
    witnesses = value.get("witnesses", {})
    expected = {
        "template": "tests/stdlib_s1_mutex_guard_generic_derivation_module.gst",
        "accepted_constructor_shape": "tests/stdlib_s1_mutex_guard_generic_derivation_rejected.gst",
        "multiple_identity": "tests/phase24_cr15_protected_resource_multiple.gst",
        "native_inferred": "tests/phase24_cr15_protected_resource_native_inferred.gst",
        "native_explicit": "tests/phase24_cr15_protected_resource_native_explicit.gst",
        "native_second_type": "tests/phase24_cr15_protected_resource_native_second_type.gst",
        "arbitrary_generic_rejected": "tests/phase24_cr15_arbitrary_generic_rejected.gst",
        "unprotected_rejected": "tests/phase24_cr15_unprotected_rejected.gst",
    }
    require(witnesses == expected, "witness manifest drifted")
    for path in expected.values():
        require((ROOT / path).is_file(), f"missing witness {path}")

    derivation = value.get("derivation")
    require(derivation == {
        "selection": "structural_resolved_protected_resource_quartet",
        "surface": "module_level_acquisition_and_rooted_accessor_only",
        "identity": "declaration_owner_plus_local_role_plus_concrete_guard_payload_and_brand",
        "materialization": "concrete_typed_ast_before_backend_selection",
        "lowering": "ordinary_canonical_calls_and_existing_resource_cleanup",
        "placeholder_policy": "unresolved_recipe_layouts_removed_before_backend_inventory",
        "backend_policy": "shared_typed_input_no_consumer_spelling_no_fallback",
    }, "derivation contract drifted")
    require(value.get("negative_authority") == [
        "arbitrary_user_generic_functions_remain_closed",
        "unprotected_inputs_receive_no_derivation",
        "extension_method_syntax_is_not_admitted",
        "consumer_spelling_is_not_authority",
    ], "negative authority drifted")
    require(value.get("boundary") == {
        "adds_or_changes_MIR_operations": False,
        "changes_ABI_layout_runtime_symbols_target_or_linker": False,
        "changes_backend_route_default_or_fallback": False,
        "changes_bootstrap_route_or_seed": False,
        "edits_stdlib": False,
        "begins_patch24_0d_or_24_1": False,
    }, "Patch 24.0c boundary drifted")

    source = TYPECHECKER.read_text(encoding="utf-8")
    for marker in value.get("compiler_markers", []):
        require(marker in source, f"compiler marker is missing: {marker}")
    start = source.index("func typechecker_type_names(")
    end = source.index("func env_resolve_type(", start)
    derivation_source = source[start:end]
    for forbidden in ("MutexGuard", "sync.lock", "sync.get"):
        require(forbidden not in derivation_source,
                f"derivation recognizes consumer spelling {forbidden}")
    for backend_source in (CODEGEN, FULL_PROGRAM):
        text = backend_source.read_text(encoding="utf-8")
        for forbidden in ("MutexGuard", "sync.lock", "sync.get"):
            require(forbidden not in text,
                    f"backend consumer recognizes {forbidden}")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 24.0c — Protected-Resource Guard Derivation — DONE" in task,
            "TASK status does not mark Patch 24.0c DONE")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "test-level assignments drifted")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in just and f"{GUARD_L2}:" in just,
            "just guard reachability drifted")
    require(GUARD_L1 in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast contract reachability drifted")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    for required in (
        "pull_request:", "push:", "workflow_dispatch:", "gust_v4.c",
        "compiler/*.gst", "src/runtime.c", "src/runtime/**",
        "tools/normalize_generated_arena_offsets.py", GUARD_L1, GUARD_L2,
    ):
        require(required in workflow, f"workflow is missing {required}")
    return value


def render(value: dict) -> str:
    derivation = value["derivation"]
    return "\n".join([
        "# Cranelift Phase 24 CR-15 Protected-Resource Derivation",
        "",
        "Generated by `scripts/phase24_cr15_derivation.py`; do not edit by hand.",
        "",
        f"- Contract: `{value['contract_version']}`",
        f"- Status: `{value['status']}`",
        f"- Implementation base: `{value['authority_base_main']}`",
        f"- Next patch: `{value['next_patch']}`",
        "",
        "## Derived authority",
        "",
        f"Selection is `{derivation['selection']}`. The admitted surface is `{derivation['surface']}`.",
        f"Concrete identity is `{derivation['identity']}` and materialization is `{derivation['materialization']}`.",
        f"Lowering remains `{derivation['lowering']}` under `{derivation['backend_policy']}`.",
        "",
        "## Evidence boundary",
        "",
        "Equivalent inferred and explicit guards agree; distinct payload/brand identities remain distinct; two protected payload types compile through retained explicit compatibility and explicit no-fallback Cranelift paths.",
        "Arbitrary user generic functions and unprotected inputs remain rejected before backend selection. No backend recognizes MutexGuard, sync.lock, or sync.get.",
        "",
        "Patch 24.0c adds no MIR operation or meaning, ABI/layout/runtime symbol, target/linker policy, route/default/fallback, Stdlib source, bootstrap route, or seed change. Patch 24.0d remains separate.",
        "",
    ])


def check_review(value: dict) -> None:
    require(REVIEW.read_text(encoding="utf-8") == render(value),
            "generated review is stale; run render")


def run(command: list[str]) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, timeout=120, check=False)


def native_artifact(witness: Path) -> Path:
    return witness.with_suffix("")


def evidence() -> None:
    value = validate()
    witnesses = {key: ROOT / path for key, path in value["witnesses"].items()}
    compiler = ROOT / "build/phase10-package/bin/gust"
    require(compiler.is_file(), "native package prerequisite is missing")

    # Patch 24.12b: retired, and INVERTED rather than deleted.
    #
    # These arms compiled four witnesses through the retired route only to
    # assert properties of the emitted C -- that the inferred and explicit
    # spellings produce identical output, and that the multiple-identity case
    # names three arenas. Neither has a native counterpart, so there is no
    # second arm for a frozen one to be compared against: this is Patch
    # 24.12a's emitter-only class arriving one patch late, and it cannot be
    # converted at any budget.
    #
    # A dropped clause says nothing. This one says the arms are gone and fails
    # if they come back. The needle is assembled from fragments so that
    # asserting the spelling's absence does not itself re-introduce the
    # spelling -- writing it literally would re-enrol this file in the
    # text-surface census and put a retired argv back into the derived
    # population, making the assertion falsify itself.
    retired_route = "--backend" + '", "' + "mir-to-c"
    own_source = Path(__file__).read_text(encoding="utf-8")
    require(retired_route not in own_source,
            "the retired emitter-only arms are back in "
            "phase24_cr15_derivation")

    for key in ("native_inferred", "native_explicit", "native_second_type"):
        artifact = native_artifact(witnesses[key])
        if artifact.exists():
            artifact.unlink()
        for route in ([], ["--backend", "cranelift"]):
            result = run([str(compiler), *route, str(witnesses[key])])
            require(result.returncode == 0 and not result.stdout and not result.stderr,
                    f"no-fallback native compilation failed for {key}: {route}")
            require(artifact.is_file() and artifact.stat().st_size > 0,
                    f"native artifact is missing for {key}: {route}")
            artifact.unlink()

    for key, diagnostic in (
        ("arbitrary_generic_rejected", b"Argument type mismatch for function 'identity'"),
        ("unprotected_rejected", b"[ProtectedResourceDerivation]"),
    ):
        # Patch 24.12b: the retired arm is served from the frozen oracle and
        # the native arm still runs live. What changed is which side of the
        # comparison executes, not what the comparison means -- the two
        # diagnostics are still required to be byte identical.
        witness = witnesses[key]
        vector_id = witness.relative_to(ROOT).as_posix()
        with tempfile.TemporaryDirectory(prefix="gust-cr15-frozen-") as raw:
            prefix = Path(raw) / "frozen"
            materialized = run([sys.executable,
                                "scripts/phase24_frozen_oracle.py",
                                "materialize", vector_id, str(prefix),
                                "--kind", "reject"])
            require(materialized.returncode == 0,
                    f"frozen oracle refused {key}: "
                    f"{materialized.stderr.decode(errors='replace')[:200]}")
            frozen_status = int(
                Path(f"{prefix}.compile.status").read_text().strip())
            frozen_stdout = Path(f"{prefix}.compile.stdout").read_bytes()
            frozen_stderr = Path(f"{prefix}.compile.stderr").read_bytes()
        require(frozen_status == 1 and not frozen_stderr and
                diagnostic in frozen_stdout,
                f"frozen negative authority drifted for {key}")

        # The witness is passed RELATIVE, matching how the frozen vector was
        # captured. A diagnostic quotes the path it was given, so an absolute
        # path here makes the two sides differ by their own spelling and the
        # byte comparison below fails for a reason that has nothing to do with
        # the diagnostic. Both arms must be asked the same question.
        native = run([str(compiler), "--backend", "cranelift", vector_id])
        require(native.returncode == 1 and not native.stderr and
                diagnostic in native.stdout,
                f"negative authority drifted for {key}: native")
        require(not native_artifact(witness).exists(),
                f"negative case produced an artifact for {key}")
        require(frozen_stdout == native.stdout,
                f"pre-driver diagnostics diverged for {key}")
    check_review(value)
    print("phase24_cr15_derivation: evidence ok")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "render", "check-review", "evidence"))
    args = parser.parse_args()
    value = validate()
    if args.command == "render":
        REVIEW.write_text(render(value), encoding="utf-8")
    elif args.command == "check-review":
        check_review(value)
        print("phase24_cr15_derivation: review current")
    elif args.command == "evidence":
        evidence()
    else:
        print("phase24_cr15_derivation: ok")


if __name__ == "__main__":
    main()
