#!/usr/bin/env python3
"""Validate, project, and reproduce the inert Patch 24.0b CR-15 opening."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE24_CR15_OPENING.md"
TASK = ROOT / "TASK.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase24-cr15-opening.yml"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
MODULE = ROOT / "tests/stdlib_s1_mutex_guard_generic_derivation_module.gst"
WITNESS = ROOT / "tests/stdlib_s1_mutex_guard_generic_derivation_rejected.gst"
EXPECTED_STDOUT = ROOT / "compiler/fixtures/phase24_cr15_rejected_stdout.txt"
GUARD_L1 = "guard-cranelift-phase24-cr15-opening-contract"
GUARD_L2 = "guard-cranelift-phase24-cr15-opening-evidence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def canonical_diagnostic(data: bytes) -> bytes:
    """Keep complete diagnostics while ignoring source-display trailing blanks."""
    rendered = b"\n".join(line.rstrip(b" \t") for line in data.splitlines())
    return rendered.rstrip(b"\n") + b"\n"


def authority() -> dict:
    data = json.loads(REGISTRY.read_text(encoding="utf-8"))
    value = data.get("phase24_cr15_opening")
    require(isinstance(value, dict), "registry authority is missing")
    return value


def derivation_successor_active() -> bool:
    data = json.loads(REGISTRY.read_text(encoding="utf-8"))
    successor = data.get("phase24_cr15_derivation")
    return (isinstance(successor, dict) and
            successor.get("contract_version") == "phase24_cr15_derivation_v1" and
            successor.get("status") == "patch24_0c_complete")


def validate() -> dict:
    value = authority()
    require(value.get("contract_version") == "phase24_cr15_opening_v1",
            "contract version drifted")
    require(value.get("status") == "patch24_0b_complete_inert",
            "opening status drifted")
    require(value.get("authority_base_main") ==
            "8b84622ddffb88a97bd06d6b87e948d1e7e88545",
            "opening base main drifted")
    require(value.get("next_patch") == "24.0c", "next patch drifted")
    require(value.get("review_view") == REVIEW.relative_to(ROOT).as_posix(),
            "review view drifted")
    require(value.get("witnesses") == [
        MODULE.relative_to(ROOT).as_posix(),
        WITNESS.relative_to(ROOT).as_posix(),
    ], "witness manifest drifted")

    baseline = value.get("rejected_baseline")
    require(baseline == {
        "routes": ["retained_explicit_compatibility", "explicit_cranelift"],
        "exit_status": 1,
        "stdout_bytes": 5679,
        "stdout_fixture": EXPECTED_STDOUT.relative_to(ROOT).as_posix(),
        "fixture_normalization": "rstrip_horizontal_whitespace_per_line_and_trailing_blank_lines_single_final_newline",
        "stderr_bytes": 0,
        "route_outputs_byte_identical": True,
        "backend_selection_reached": False,
        "failure_families": [
            "Brand Nesting Restriction",
            "ResourceDestructorSignature",
            "Argument type mismatch",
            "FieldNotFound",
        ],
    }, "rejected baseline drifted")

    descriptor = value.get("inert_derivation_descriptor")
    require(descriptor == {
        "selection": "resolved_compiler_metadata_only",
        "activation": "inert_until_patch24_0c",
        "inputs": [
            "struct_templates.generics_and_fields",
            "canonical_type_names",
            "brand_identities",
            "struct_linear_resource",
            "struct_declared_destructor_and_opaque",
            "struct_and_function_declaration_module",
            "struct_validated_destructor",
            "function_registry_signature",
            "function_return_provenance.resource_root_identity",
            "resource_acquisition_obligations",
        ],
        "derived_identities": [
            "concrete_acquisition_call",
            "concrete_guard_type",
            "concrete_destructor",
            "concrete_rooted_accessor",
        ],
        "identity_rule": "canonical_resolved_template_arguments_plus_brand_identity_and_declaration_owner",
        "lowering": "ordinary_canonical_calls_resource_obligation_and_protected_root_machinery",
        "backend_policy": "backend_neutral_no_recognition_no_fallback",
    }, "inert derivation descriptor drifted")
    require(value.get("forbidden_recognizers") == [
        "consumer_type_spelling", "consumer_guard_spelling",
        "consumer_lock_spelling", "consumer_get_spelling",
        "arbitrary_user_generic_function", "backend_selected_rule",
    ], "forbidden recognizer set drifted")
    require(value.get("boundary") == {
        "changes_accepted_Gust_program_meaning": False,
        "adds_or_changes_MIR_operations": False,
        "changes_ABI_layout_runtime_symbols_target_or_linker": False,
        "changes_backend_route_default_or_fallback": False,
        "changes_bootstrap_route_or_seed": False,
        "edits_stdlib": False,
        "implements_CR15": False,
        "begins_patch24_0c_or_24_1": False,
    }, "Patch 24.0b boundary drifted")

    source = TYPECHECKER.read_text(encoding="utf-8")
    for marker in value.get("compiler_fact_markers", []):
        require(marker in source, f"compiler fact marker is missing: {marker}")
    if not derivation_successor_active():
        for forbidden in value.get("implementation_markers_absent", []):
            require(forbidden not in source,
                    f"opening is no longer inert; implementation marker exists: {forbidden}")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 24.0b — CR-15 Opening Evidence and Inert Derivation Contract — DONE" in task,
            "TASK status does not mark Patch 24.0b DONE")
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
    for witness in (MODULE, WITNESS, EXPECTED_STDOUT):
        require(witness.is_file(), f"missing witness {witness.relative_to(ROOT)}")
    return value


def render(value: dict) -> str:
    baseline = value["rejected_baseline"]
    descriptor = value["inert_derivation_descriptor"]
    lines = [
        "# Cranelift Phase 24 CR-15 Opening",
        "",
        "Generated by `scripts/phase24_cr15_opening.py`; do not edit by hand.",
        "",
        f"- Contract: `{value['contract_version']}`",
        f"- Status: `{value['status']}`",
        f"- Reproduction main: `{value['authority_base_main']}`",
        f"- Next patch: `{value['next_patch']}`",
        "",
        "## Rejected baseline",
        "",
        f"Both retained compiler paths reject with status `{baseline['exit_status']}` before backend selection.",
        f"Their stdout is byte-identical to `{baseline['stdout_fixture']}` (`{baseline['stdout_bytes']}` bytes); stderr is empty.",
        "Failure families: " + ", ".join(f"`{item}`" for item in baseline["failure_families"]) + ".",
        "",
        "## Inert derivation descriptor",
        "",
        f"Selection: `{descriptor['selection']}`; activation: `{descriptor['activation']}`.",
        f"Stable identity: `{descriptor['identity_rule']}`.",
        "Inputs: " + ", ".join(f"`{item}`" for item in descriptor["inputs"]) + ".",
        "Derived identities: " + ", ".join(f"`{item}`" for item in descriptor["derived_identities"]) + ".",
        f"Lowering contract: `{descriptor['lowering']}`; backend policy: `{descriptor['backend_policy']}`.",
        "",
        "## Falsifiers",
        "",
        "No authority may be selected by consumer type, guard, acquisition, or accessor spelling; arbitrary user generic functions remain closed; backend selection cannot affect derivation.",
        "",
        "Patch 24.0b records an inert compiler-owned contract only. It changes no accepted Gust meaning, MIR, ABI/layout/runtime symbol, route/fallback, Stdlib source, bootstrap seed, or Phase 24.1 state.",
        "",
    ]
    return "\n".join(lines)


def check_review(value: dict) -> None:
    require(REVIEW.read_text(encoding="utf-8") == render(value),
            "generated review is stale; run render")


def evidence() -> None:
    value = validate()
    if derivation_successor_active():
        check_review(value)
        print("phase24_cr15_opening: historical rejected baseline preserved; Patch 24.0c successor active")
        return
    require((ROOT / "gust").is_file(), "make gust prerequisite is missing")
    baseline = value["rejected_baseline"]
    expected_stdout = EXPECTED_STDOUT.read_bytes()
    require(expected_stdout == canonical_diagnostic(expected_stdout),
            "expected diagnostic fixture is not canonical")
    route_names = json.loads(REGISTRY.read_text(encoding="utf-8"))["phase23_closure"]["route_authority"]
    routes = [route_names["explicit_c_spellings"][0], route_names["explicit_native_backend"]]
    outputs: list[bytes] = []
    sentinel = ROOT / "user.native"
    require(not sentinel.exists(), "stale native artifact obscures opening evidence")
    for route in routes:
        command = (str(ROOT / "gust"), "--backend", route,
                   WITNESS.relative_to(ROOT).as_posix())
        result = subprocess.run(
            command,
            cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            check=False,
        )
        require(result.returncode == baseline["exit_status"],
                f"{route} rejection status drifted")
        require(len(result.stdout) == baseline["stdout_bytes"] and
                canonical_diagnostic(result.stdout) == expected_stdout,
                f"{route} diagnostic identity drifted")
        require(len(result.stderr) == baseline["stderr_bytes"],
                f"{route} stderr identity drifted")
        for family in baseline["failure_families"]:
            require(family.encode() in result.stdout,
                    f"{route} is missing failure family {family}")
        require(not sentinel.exists(),
                f"{route} produced an artifact before backend selection")
        outputs.append(result.stdout)
    require(outputs[0] == outputs[1], "retained path diagnostics diverged")
    check_review(value)
    print("phase24_cr15_opening: evidence ok")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "render", "check-review", "evidence"))
    args = parser.parse_args()
    value = validate()
    if args.command == "render":
        REVIEW.write_text(render(value), encoding="utf-8")
    elif args.command == "check-review":
        check_review(value)
        print("phase24_cr15_opening: review current")
    elif args.command == "evidence":
        evidence()
    else:
        print("phase24_cr15_opening: ok")


if __name__ == "__main__":
    main()
