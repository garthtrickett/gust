#!/usr/bin/env python3
"""Validate, project, and qualify Patch 24.0d CR-15 parity authority."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import stat
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE24_CR15_QUALIFICATION.md"
TASK = ROOT / "TASK.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase24-cr15-qualification.yml"
FULL_PROGRAM_SOURCE = ROOT / "compiler/mir_native_backend_full_program_source.gst"
FULL_PROGRAM_WORKER = ROOT / "compiler/experiments/cranelift/src/full_program.rs"
GUARD_L1 = "guard-cranelift-phase24-cr15-qualification-contract"
GUARD_L2 = "guard-cranelift-phase24-cr15-qualification-evidence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def authority() -> dict:
    data = json.loads(REGISTRY.read_text(encoding="utf-8"))
    value = data.get("phase24_cr15_qualification")
    require(isinstance(value, dict), "registry authority is missing")
    return value


def validate() -> dict:
    value = authority()
    require(value.get("contract_version") == "phase24_cr15_qualification_v1",
            "contract version drifted")
    require(value.get("status") == "patch24_0d_complete",
            "qualification status drifted")
    require(value.get("authority_base_main") ==
            "2383096a741c62e8de103a5b79281b9f616eb805",
            "authority base main drifted")
    require(value.get("next_patch") == "24.0e", "next patch drifted")
    require(value.get("review_view") == REVIEW.relative_to(ROOT).as_posix(),
            "review view drifted")

    expected_witnesses = {
        "inferred": "tests/phase24_cr15_qualification_positive.gst",
        "explicit": "tests/phase24_cr15_qualification_explicit.gst",
        "spelling_substituted_module": "tests/phase24_cr15_qualification_module.gst",
        "same_spelling_without_metadata_module": "tests/phase24_cr15_qualification_no_metadata_module.gst",
        "same_spelling_without_metadata_rejected": "tests/phase24_cr15_qualification_no_metadata_rejected.gst",
        "use_after_move_rejected": "tests/phase24_cr15_qualification_use_after_move_rejected.gst",
        "escape_rejected": "tests/phase24_cr15_qualification_escape_rejected.gst",
        "forgery_rejected": "tests/phase24_cr15_qualification_forgery_rejected.gst",
        "unresolved_rejected": "tests/phase24_cr15_qualification_unresolved_rejected.gst",
        "wrong_brand_rejected": "tests/phase24_cr15_qualification_wrong_brand_rejected.gst",
        "post_cleanup_rejected": "compiler/phase20_protected_access_after_close_invalid.gst",
    }
    require(value.get("witnesses") == expected_witnesses,
            "witness manifest drifted")
    for path in expected_witnesses.values():
        require((ROOT / path).is_file(), f"missing witness {path}")

    require(value.get("positive_authority") == {
        "protected_resource_families": [
            "selected_MutexGuard_metadata_family",
            "spelling_substituted_Lease_metadata_family",
        ],
        "protected_payloads": ["Counter", "Flag"],
        "context_brands": ["first_arena", "third_arena"],
        "scope_exits": ["normal", "return", "break", "continue"],
        "resource_events": [
            "nested_scope", "move_transfer", "repeated_acquisition",
            "exactly_once_cleanup", "guard_rooted_mutation",
        ],
        "expected_stdout": "100\n1\n7\n100\n1\n9\n100\n1\n10\n100\n1\n100\n7\n1\n100\n8\n1\n",
    }, "positive authority drifted")
    require(value.get("canonical_lowering") == {
        "constructor": "typed_MutexNew_to_concrete_helper_using_existing_zero_initialize_assign_call_return",
        "lock_unlock": "typed_intrinsics_to_existing_runtime_calls_and_field_addressing",
        "scope_exit": "existing_ScopeCleanup_on_fallthrough_return_break_and_continue",
        "worker_policy": "generic_canonical_operations_only_no_Mutex_or_guard_consumer_recognizer",
        "mir_operation_change": False,
    }, "canonical lowering contract drifted")
    require(value.get("negative_authority") == {
        "use_after_move": "Use of moved variable source",
        "escape": "Escape analysis violation",
        "forgery": "[OpaqueConstruction]",
        "unresolved": "Brand Nesting Restriction",
        "wrong_brand": "[TypeMismatch]",
        "without_metadata": "Brand Nesting Restriction",
        "post_cleanup": "[ProtectedAccessNotLive]",
    }, "negative authority drifted")
    require(value.get("boundary") == {
        "changes_accepted_Gust_meaning_beyond_CR15": False,
        "adds_or_changes_MIR_operations": False,
        "changes_ABI_layout_runtime_symbols_target_or_linker": False,
        "changes_backend_route_default_or_fallback": False,
        "changes_bootstrap_route_or_seed": False,
        "edits_stdlib": False,
        "begins_patch24_0e_or_24_1": False,
    }, "Patch 24.0d boundary drifted")

    source = FULL_PROGRAM_SOURCE.read_text(encoding="utf-8")
    for marker in (
        "mir_native_full_program_append_mutex_constructor_helpers",
        '"__gust_mutex_new_"',
        '"std_Mutex_Lock_impl"',
        '"std_Mutex_Unlock_impl"',
    ):
        require(marker in source, f"canonical source marker is missing: {marker}")
    worker = FULL_PROGRAM_WORKER.read_text(encoding="utf-8")
    require("scope_cleanups: Vec<Option<usize>>" in worker and
            "self.emit_scope_exit(builder, scope)?" in worker,
            "generic scope-exit lowering markers are missing")
    for forbidden in ("MutexGuard", "sync.lock", "sync.get", "std_Mutex"):
        require(forbidden not in worker,
                f"native worker contains a bespoke consumer recognizer: {forbidden}")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 24.0d — CR-15 Cross-Path and Adversarial Qualification — DONE" in task,
            "TASK status does not mark Patch 24.0d DONE")
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
        "compiler/*.gst", "compiler/experiments/cranelift/**",
        "src/runtime.c", "src/runtime/**",
        "tools/normalize_generated_arena_offsets.py", GUARD_L1, GUARD_L2,
    ):
        require(required in workflow, f"workflow is missing {required}")
    return value


def render(value: dict) -> str:
    return "\n".join([
        "# Cranelift Phase 24 CR-15 Cross-Path Qualification",
        "",
        "Generated by `scripts/phase24_cr15_qualification.py`; do not edit by hand.",
        "",
        f"- Contract: `{value['contract_version']}`",
        f"- Status: `{value['status']}`",
        f"- Implementation base: `{value['authority_base_main']}`",
        f"- Next patch: `{value['next_patch']}`",
        "",
        "## Qualified capability",
        "",
        "The selected MutexGuard family and a spelling-substituted Lease family derive only from resolved protected-Resource metadata. Counter and Flag payloads across first_arena and third_arena brands preserve inferred/explicit identity.",
        "Normal, return, break, and continue exits execute existing canonical ScopeCleanup exactly once. Nested scopes, explicit move transfer, repeated acquisition, and guard-rooted mutation agree through MIR-to-C and explicit no-fallback Cranelift.",
        "",
        "## Adversarial boundary",
        "",
        "Use after move or cleanup, protected-reference escape, opaque construction forgery, unresolved placeholders, wrong brands, and an equivalent consumer spelling without Resource metadata reject before backend divergence.",
        "The native worker lowers generic canonical operations only; it contains no Mutex, MutexGuard, sync.lock, sync.get, or protected-family recognizer.",
        "",
        "Patch 24.0d adds no MIR operation or meaning, ABI/layout/runtime symbol, target/linker policy, route/default/fallback, Stdlib source, bootstrap route, or seed change. Patch 24.0e remains separate.",
        "",
    ])


def check_review(value: dict) -> None:
    require(REVIEW.read_text(encoding="utf-8") == render(value),
            "generated review is stale; run render")


def run(command: list[str], *, env: dict[str, str] | None = None,
        timeout: int = 120) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, env=env,
                          timeout=timeout, check=False)


def evidence() -> None:
    value = validate()
    witnesses = {key: ROOT / path for key, path in value["witnesses"].items()}
    compiler = ROOT / "build/phase10-package/bin/gust"
    driver = ROOT / "build/phase10-package/bin/gust-native-backend"
    runtime_package = ROOT / "build/phase10-package/bin/gust-runtime-package.a"
    runtime = ROOT / "src/runtime.c"
    for prerequisite in (compiler, driver, runtime_package, runtime):
        require(prerequisite.is_file(), f"missing prerequisite {prerequisite}")

    expected_stdout = value["positive_authority"]["expected_stdout"].encode()
    c_outputs: dict[str, bytes] = {}
    for key in ("inferred", "explicit"):
        result = run([str(compiler), "--backend", "mir-to-c",
                      str(witnesses[key])])
        require(result.returncode == 0 and not result.stderr and
                result.stdout.startswith(b"// Transpiled C Code\n#include"),
                f"retained compatibility failed for {key}")
        c_outputs[key] = result.stdout
    require(c_outputs["inferred"] == c_outputs["explicit"],
            "inferred and explicit generated C differ")

    with tempfile.TemporaryDirectory(prefix="gust-phase24-cr15-") as temporary:
        temp = Path(temporary)
        equivalent = temp / "equivalent.gst"
        shutil.copy2(witnesses["spelling_substituted_module"],
                     temp / witnesses["spelling_substituted_module"].name)
        wrapper = temp / "capture-driver"
        wrapper.write_text(
            "#!/usr/bin/env bash\nset -euo pipefail\n"
            "if test \"${1:-}\" = phase10-backend-request-compile; then\n"
            "  bundle=$(sed -n 's/^program_mir_bundle_path: //p' \"$2\")\n"
            "  cp \"$bundle\" \"$CAPTURE_BUNDLE\"\n"
            "fi\nexec \"$REAL_DRIVER\" \"$@\"\n",
            encoding="utf-8",
        )
        wrapper.chmod(wrapper.stat().st_mode | stat.S_IXUSR)
        shutil.copy2(runtime_package, temp / runtime_package.name)
        bundles: dict[str, bytes] = {}
        artifacts: dict[str, bytes] = {}
        outputs: dict[str, bytes] = {}
        for key in ("inferred", "explicit"):
            shutil.copy2(witnesses[key], equivalent)
            artifact = temp / "program"
            bundle = temp / f"{key}.bundle"
            environment = os.environ.copy()
            environment.update({
                "GUST_NATIVE_BACKEND_DRIVER": str(wrapper),
                "REAL_DRIVER": str(driver),
                "CAPTURE_BUNDLE": str(bundle),
            })
            result = run([str(compiler), "--backend", "cranelift", "-o",
                          str(artifact), str(equivalent)], env=environment)
            require(result.returncode == 0 and not result.stdout and
                    not result.stderr and artifact.is_file(),
                    f"explicit no-fallback Cranelift compilation failed for {key}: "
                    f"stdout={result.stdout.decode(errors='replace')!r} "
                    f"stderr={result.stderr.decode(errors='replace')!r}")
            executed = run([str(artifact)], timeout=20)
            require(executed.returncode == 0 and
                    executed.stdout == expected_stdout and not executed.stderr,
                    f"native execution drifted for {key}")
            bundles[key] = bundle.read_bytes()
            artifacts[key] = artifact.read_bytes()
            outputs[key] = executed.stdout

            default_artifact = temp / "default-program"
            environment["CAPTURE_BUNDLE"] = str(temp / f"{key}-default.bundle")
            default = run([str(compiler), "-o", str(default_artifact),
                           str(equivalent)], env=environment)
            require(default.returncode == 0 and not default.stdout and
                    not default.stderr and
                    default_artifact.read_bytes() == artifacts[key],
                    f"default and explicit Cranelift artifacts differ for {key}")

        require(bundles["inferred"] == bundles["explicit"],
                "inferred and explicit canonical MIR differ")
        require(artifacts["inferred"] == artifacts["explicit"],
                "inferred and explicit native artifacts differ")
        require(outputs["inferred"] == outputs["explicit"],
                "inferred and explicit native output differs")

        for key in ("inferred", "explicit"):
            c_source = temp / f"{key}.c"
            c_source.write_bytes(runtime.read_bytes() + c_outputs[key])
            c_artifact = temp / f"{key}-c"
            compiled = run(["cc", "-O2", "-Wall", "-pthread", "-Isrc",
                            str(c_source), "-o", str(c_artifact)])
            require(compiled.returncode == 0,
                    f"retained compatibility host compile failed for {key}")
            executed = run([str(c_artifact)], timeout=20)
            require(executed.returncode == 0 and
                    executed.stdout == expected_stdout and not executed.stderr,
                    f"retained compatibility execution drifted for {key}")

        failed_artifact = temp / "must-not-fallback"
        failed_env = os.environ.copy()
        failed_env["GUST_NATIVE_BACKEND_DRIVER"] = "/bin/false"
        failed = run([str(compiler), "--backend", "cranelift", "-o",
                      str(failed_artifact), str(witnesses["inferred"])],
                     env=failed_env)
        require(failed.returncode == 1 and not failed_artifact.exists() and
                b"driver_handshake_error" in failed.stdout and
                b"Transpiled C Code" not in failed.stdout,
                "supported CR-15 program fell back after driver failure")

    for key, diagnostic in value["negative_authority"].items():
        witness_key = {
            "use_after_move": "use_after_move_rejected",
            "escape": "escape_rejected",
            "forgery": "forgery_rejected",
            "unresolved": "unresolved_rejected",
            "wrong_brand": "wrong_brand_rejected",
            "without_metadata": "same_spelling_without_metadata_rejected",
            "post_cleanup": "post_cleanup_rejected",
        }[key]
        outputs = []
        for route in (("--backend", "mir-to-c"),
                      ("--backend", "cranelift")):
            result = run([str(compiler), *route, str(witnesses[witness_key])])
            require(result.returncode == 1 and not result.stderr and
                    diagnostic.encode() in result.stdout,
                    f"negative authority drifted for {key}: {route}")
            outputs.append(result.stdout)
        require(outputs[0] == outputs[1],
                f"pre-driver diagnostics diverged for {key}")

    check_review(value)
    print("phase24_cr15_qualification: evidence ok")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command",
                        choices=("validate", "render", "check-review", "evidence"))
    args = parser.parse_args()
    value = validate()
    if args.command == "render":
        REVIEW.write_text(render(value), encoding="utf-8")
    elif args.command == "check-review":
        check_review(value)
        print("phase24_cr15_qualification: review current")
    elif args.command == "evidence":
        evidence()
    else:
        print("phase24_cr15_qualification: ok")


if __name__ == "__main__":
    main()
