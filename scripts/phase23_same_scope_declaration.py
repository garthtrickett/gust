#!/usr/bin/env python3
"""Validate the bounded #105 current-lexical-scope diagnostic."""

from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
GUST = ROOT / "gust"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE23_SAME_SCOPE_DECLARATION.md"
ASSURANCE = ROOT / "scripts/phase23_same_scope_declaration_assurance.json"
TASK = ROOT / "TASK.md"
GEMINI = ROOT / "GEMINI.md"
ISSUE_ROADMAP = ROOT / "docs/ISSUE_ROADMAP.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
GUARD = "guard-cranelift-phase23-same-scope-declaration-contract"
DIAGNOSTIC = "Semantic Error: Duplicate declaration 'value' in the same lexical scope"
NEGATIVE = ROOT / "compiler/phase23_same_scope_duplicate_current.gst"
POSITIVES = [
    ROOT / "compiler/phase23_parent_scope_shadow_current.gst",
    ROOT / "compiler/phase23_disjoint_block_reuse_current.gst",
    ROOT / "compiler/phase23_assignment_reuse_current.gst",
    ROOT / "compiler/phase23_different_function_reuse_current.gst",
]
NEGATIVE_C_COMMAND = "[str(GUST), '--backend', 'mir-to-c', str(NEGATIVE)]"
NEGATIVE_DEFAULT_COMMAND = "[str(GUST), str(NEGATIVE)]"
POSITIVE_C_COMMAND = "[str(GUST), '--backend', 'mir-to-c', str(source)]"
POSITIVE_DEFAULT_COMMAND = "[str(GUST), str(source)]"

EXPECTED_AUTHORITY = {
    "contract_version": "phase23_same_scope_declaration_v1",
    "status": "closed_on_merged_current_main",
    "issue": 105,
    "owner": "cranelift",
    "review_view": "compiler/CRANELIFT_PHASE23_SAME_SCOPE_DECLARATION.md",
    "diagnostic": "Semantic Error: Duplicate declaration '<name>' in the same lexical scope",
    "negative": "compiler/phase23_same_scope_duplicate_current.gst",
    "positives": [path.relative_to(ROOT).as_posix() for path in POSITIVES],
    "oracle": "explicit_mir_to_c",
    "default_native": "same_duplicate_diagnostic_before_native_capability_selection; valid_cases_retain_explicit_native_capability_deferral_without_fallback",
    "assurance": "scripts/phase23_same_scope_declaration_assurance.json",
    "phase22_closed_inventory_extension": {
        "status": "exact_phase23_extension_excluded_only_from_phase22_relay_identity",
        "owning_patch": "23.6",
        "path": "scripts/phase23_same_scope_declaration.py",
        "selection": ["explicit_c", "implicit_default", "explicit_c", "implicit_default"],
        "invocation_count": 4,
        "commands": [
            NEGATIVE_C_COMMAND,
            NEGATIVE_DEFAULT_COMMAND,
            POSITIVE_C_COMMAND,
            POSITIVE_DEFAULT_COMMAND,
        ],
        "phase22_relay_contract": "the_exact_six_site_Stdlib_relay_and_306_invocation_inventory_remain_unchanged",
        "phase23_contract": "all_four_same_scope_evidence_calls_remain_visible_in_the_live_scan_and_are_owned_by_the_Patch_23_6_evidence_guard",
        "falsifier": "missing_partial_extra_path_command_or_selection_drift_is_rejected",
    },
    "issue_closure": {
        "state": "closed_after_merged_current_main_validation",
        "implementation_pull_request": 278,
        "implementation_exact_head_sha": "74b259d2c7573b4929f2ffa331a261085a16e894",
        "implementation_merged_main_sha": "f6814323588eeb5321a7c0e20210aec802be568f",
        "pull_request_event": "pull_request",
        "successful_workflows": 120,
        "total_workflows": 120,
        "unfinished_workflows": 0,
        "non_success_workflows": 0,
        "unresolved_review_threads": 0,
        "current_main_validation": {
            "sha": "f6814323588eeb5321a7c0e20210aec802be568f",
            "commands": [
                "make gust",
                "make phase10-native-package",
                "just guard-cranelift-phase23-same-scope-declaration-evidence",
            ],
            "result": "completed_success",
        },
        "issue_state": "closed",
        "bootstrap_seed_status": "unchanged_deferred_to_patch23_6a",
    },
    "boundary": {
        "rejects_only_current_lexical_scope_duplicate_declarations": True,
        "preserves_parent_scope_shadowing_disjoint_block_reuse_assignment_and_different_function_reuse": True,
        "adds_or_changes_MIR_operations": False,
        "changes_backend_route_or_fallback": False,
        "changes_ABI_layout_or_runtime_symbols": False,
        "changes_bootstrap_seed": False,
        "edits_stdlib_or_CR15": False,
        "begins_patch23_6a": False,
    },
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def run(command: list[str]) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          check=False)


def authority() -> dict:
    value = json.loads(REGISTRY.read_text(encoding="utf-8")).get("phase23_same_scope_declaration")
    require(value == EXPECTED_AUTHORITY, "registry same-scope authority drifted")
    return value


def assurance() -> dict:
    value = json.loads(ASSURANCE.read_text(encoding="utf-8"))
    require(value == {
        "contract_version": "phase23_same_scope_declaration_assurance_v1",
        "mode": "report_only",
        "issue": 105,
        "base_main_sha": "b6264ccef8f35e8fe9b055b685648efec8ac6858",
        "result": "unqualified_candidate_evidence",
        "inventory": {
            "same_scope_duplicate": "Gust_rejects_before_backend",
            "parent_scope_shadow": "explicit_mir_to_c_accepts",
            "disjoint_block_reuse": "explicit_mir_to_c_accepts",
            "assignment": "explicit_mir_to_c_accepts",
            "different_function_reuse": "explicit_mir_to_c_accepts",
            "default_native": "duplicate_diagnostic_or_explicit_capability_deferral_without_fallback",
        },
        "closure_evidence": "pending_merged_current_main_validation_and_patch23_6a_seed",
    }, "report-only #105 assurance result drifted")
    return value


def validate() -> None:
    authority()
    assurance()
    require(NEGATIVE.is_file() and all(path.is_file() for path in POSITIVES),
            "fixture inventory is incomplete")
    require("- [x] Patch 23.6 — Same-Scope Declaration Diagnostic (#105) — DONE" in
            TASK.read_text(encoding="utf-8"),
            "Patch 23.6 roadmap status is not closed")
    gemini = GEMINI.read_text(encoding="utf-8")
    require("### C. Lexical Declaration Scope" in gemini and
            "whole-function naming rule" in gemini,
            "GEMINI lexical-scope correction drifted")
    issue_roadmap = ISSUE_ROADMAP.read_text(encoding="utf-8")
    require("PR #278 exact head `74b259d2c7573b4929f2ffa331a261085a16e894` passed 120/120" in
            issue_roadmap,
            "#105 routing ledger does not cite exact implementation evidence")
    levels = json.loads(LEVELS.read_text(encoding="utf-8")).get("guards", {})
    require(levels.get(GUARD) == 1, "Level 1 guard registration drifted")
    require(f"{GUARD}:" in JUSTFILE.read_text(encoding="utf-8"), "Just guard is missing")
    require("Phase 23 same-scope declaration diagnostic" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast reachability is missing")


def host_c_compiles(source: Path, generated: bytes) -> None:
    with tempfile.TemporaryDirectory(prefix="gust-phase23-scope-") as raw:
        output = Path(raw) / "program.c"
        output.write_bytes((ROOT / "src/runtime.c").read_bytes() + generated)
        result = run(["cc", "-O0", "-w", "-pthread", "-Isrc", str(output),
                      "-o", str(Path(raw) / "program")])
        require(result.returncode == 0,
                f"{source.relative_to(ROOT)} no longer compiles through the explicit-C oracle")


def evidence() -> None:
    require(GUST.is_file(), "make gust must produce ./gust before evidence")
    negative_c = run([str(GUST), "--backend", "mir-to-c", str(NEGATIVE)])
    negative_default = run([str(GUST), str(NEGATIVE)])
    require(negative_c.returncode == 1 and negative_default.returncode == 1,
            "same-scope duplicate must reject before either backend")
    require(negative_c.stderr == b"" and negative_default.stderr == b"",
            "same-scope diagnostic must not leak backend stderr")
    require(negative_c.stdout == negative_default.stdout and DIAGNOSTIC.encode() in negative_c.stdout,
            "explicit-C and default-native duplicate diagnostics diverged")
    require(b"source_feature_not_represented" not in negative_c.stdout,
            "same-scope duplicate reached native capability selection")

    for source in POSITIVES:
        explicit_c = run([str(GUST), "--backend", "mir-to-c", str(source)])
        require(explicit_c.returncode == 0 and explicit_c.stderr == b"" and explicit_c.stdout,
                f"{source.relative_to(ROOT)} no longer passes explicit MIR-to-C")
        require(DIAGNOSTIC.encode() not in explicit_c.stdout,
                f"{source.relative_to(ROOT)} was mistaken for a current-scope duplicate")
        host_c_compiles(source, explicit_c.stdout)

        default_native = run([str(GUST), str(source)])
        require(default_native.returncode == 1 and default_native.stderr == b"",
                f"{source.relative_to(ROOT)} default-native status drifted")
        require(b"gust_native_capability_decision:" in default_native.stdout and
                b"unsupported_native_capability" in default_native.stdout and
                DIAGNOSTIC.encode() not in default_native.stdout,
                f"{source.relative_to(ROOT)} changed native deferral or acquired a fallback")
    print("phase23_same_scope_declaration: evidence ok")


def render() -> str:
    value = authority()
    lines = [
        "# Cranelift Phase 23 Same-Scope Declaration Diagnostic",
        "",
        "Generated by `scripts/phase23_same_scope_declaration.py`; do not edit by hand.",
        "",
        f"- Contract: `{value['contract_version']}`",
        f"- Status: `{value['status']}`",
        f"- Issue: `#{value['issue']}`",
        f"- Diagnostic: `{value['diagnostic']}`",
        f"- Negative: `{value['negative']}`",
        f"- Positives: `{', '.join(value['positives'])}`",
        f"- Assurance: `{value['assurance']}` (`unqualified_candidate_evidence`; not merge authority).",
        "- Current-scope-only: parent shadowing, disjoint block reuse, assignment, and different-function reuse remain valid.",
        "- Explicit MIR-to-C remains the oracle. Default-native valid fixtures retain their explicit native-capability deferral; no fallback is added.",
        "- Seed reconvergence is deliberately deferred to Patch 23.6a.",
        "",
        "## Closure evidence",
        "",
        f"PR `#{value['issue_closure']['implementation_pull_request']}` exact head "
        f"`{value['issue_closure']['implementation_exact_head_sha']}` passed "
        f"`{value['issue_closure']['successful_workflows']}/"
        f"{value['issue_closure']['total_workflows']}` pull-request workflows with "
        f"`{value['issue_closure']['unresolved_review_threads']}` unresolved review threads "
        f"and merged as `{value['issue_closure']['implementation_merged_main_sha']}`.",
        "The focused diagnostic evidence and bootstrap-sensitive `make gust` passed "
        "on that exact merged current main. Issue #105 is closed; `gust_v4.c` is "
        "unchanged and remains isolated to Patch 23.6a.",
        "",
    ]
    return "\n".join(lines)


def check_review() -> None:
    require(REVIEW.read_text(encoding="utf-8") == render(), "generated review is stale")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "evidence", "render", "check-review"))
    args = parser.parse_args()
    if args.command == "validate":
        validate()
    elif args.command == "evidence":
        evidence()
    elif args.command == "render":
        print(render(), end="")
    else:
        check_review()


if __name__ == "__main__":
    main()
