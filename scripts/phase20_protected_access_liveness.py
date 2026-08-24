#!/usr/bin/env python3
"""Validate and project Patch 20.16d protected-access liveness authority."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_PROTECTED_ACCESS_LIVENESS.md"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
HISTORICAL = ROOT / ".github/workflows/cranelift-historical-full.yml"
JUSTFILE = ROOT / "justfile"
GUARD = "guard-cranelift-phase20-protected-access-liveness-contract"


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    authority = registry.get("phase20_protected_access_liveness")
    require(isinstance(authority, dict), "Patch 20.16d authority is missing")
    require(authority.get("contract_version") ==
            "phase20_protected_access_liveness_v1",
            "Patch 20.16d contract version drifted")
    require(authority.get("status") == "patch20_16d_complete",
            "Patch 20.16d status drifted")
    require(authority.get("next_patch") == "20.16e",
            "Patch 20.16d successor drifted")
    require(authority.get("handoff") == {
        "implementation_authority_landed": True,
        "registrar_action": "stdlib_s1_8_may_rederive_from_merged_patch20_16d",
        "stdlib_policy": "not_selected_by_compiler_authority",
    }, "Patch 20.16d registrar handoff drifted")

    for key in ("module_fixture", "positive_fixture", "canonical_mir_fixture",
                "native_probe"):
        require((ROOT / authority[key]).is_file(),
                f"Patch 20.16d file is missing: {authority[key]}")
    negatives = authority.get("negative_fixtures")
    require(isinstance(negatives, list) and len(negatives) == 7,
            "Patch 20.16d negative matrix drifted")
    for row in negatives:
        require((ROOT / row["path"]).is_file(),
                f"Patch 20.16d negative fixture is missing: {row['path']}")
        require(row["diagnostic"] in (
            "ProtectedAccessNotLive", "ProtectedAccessEscape",
            "ProtectedAccessAmbiguousRoot",
            "UnsafeMutexPrimitive"),
            f"unexpected Patch 20.16d diagnostic: {row['diagnostic']}")

    typechecker = TYPECHECKER.read_text(encoding="utf-8")
    for evidence in (
        "func env_resource_root_identity_for_call(",
        "func env_report_resource_root_liveness(",
        "func env_report_resource_root_escape(",
        "[ProtectedAccessNotLive]",
        "[ProtectedAccessEscape]",
        "[ProtectedAccessAmbiguousRoot]",
        "[UnsafeMutexPrimitive]",
        "if (*env).in_unsafe_block == 0",
        "storing protected access in a field",
        "storing protected access in a container",
        "passing protected access to a callee",
        "returning protected access",
    ):
        require(evidence in typechecker,
                f"protected-access compiler evidence is missing: {evidence}")

    module = (ROOT / authority["module_fixture"]).read_text(encoding="utf-8")
    for evidence in (
        "#[linear]", "#[destructor(destroy_guard)]", "#[opaque]",
        "func access(owner: &Guard[ctx]) &ProtectedValue[ctx]",
        "#[destructor(destroy_mutex_owner)]",
        "(*owner.mutex).Unlock();",
        "mut raw_value := (*mutex).Lock();",
        "func mutex_access(owner: &MutexOwner[ctx]) &ProtectedValue[ctx]",
        "return &(*owner.protected);",
    ):
        require(evidence in module,
                f"protected-access module coverage is missing: {evidence}")

    positive = (ROOT / authority["positive_fixture"]).read_text(encoding="utf-8")
    for evidence in (
        "live_access()", "moved_guard_access()", "normal_scope_cleanup()",
        "early_return_cleanup()", "conditional_cleanup()",
        "failure_cleanup(ctx)", "mutex_normal_cleanup(&mutex)",
        "mutex_early_cleanup(&mutex)", "mutex_conditional_cleanup(&mutex)",
        "mutex_failure_cleanup(&mutex, ctx)", "return observed;",
    ):
        require(evidence in positive,
                f"protected-access positive coverage is missing: {evidence}")

    mir = (ROOT / authority["canonical_mir_fixture"]).read_text(encoding="utf-8")
    require("phase20_protected_access_lifecycle_probe" in mir and
            "function_0_expected_exit: 72" in mir,
            "Patch 20.16d canonical MIR projection drifted")
    probe = (ROOT / authority["native_probe"]).read_text(encoding="utf-8")
    for evidence in ("pthread_mutex_lock", "pthread_mutex_unlock",
                     "pthread_mutex_trylock", "return 72;"):
        require(evidence in probe,
                f"Patch 20.16d native lifecycle probe is missing: {evidence}")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 20.16d — Protected-Access Liveness Enforcement — DONE"
            in task, "TASK.md does not mark Patch 20.16d DONE")
    require("- [ ] Patch 20.16e — Protected-Access Bootstrap Seed Reconvergence"
            in task, "TASK.md does not preserve Patch 20.16e as the next boundary")

    workflow = PR_FAST.read_text(encoding="utf-8")
    require("Phase 20 protected-access liveness enforcement" in workflow and
            "just guard-cranelift-phase20-protected-access-liveness-contract"
            in workflow and
            "just guard-cranelift-phase20-protected-access-liveness-parity"
            in workflow,
            "PR Fast does not own both Patch 20.16d focused levels")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    for guard in (
        "guard-cranelift-phase20-protected-access-liveness-contract:",
        "guard-cranelift-phase20-protected-access-liveness-parity:",
        "guard-cranelift-phase20-protected-access-liveness-full:",
    ):
        require(guard in justfile, f"Patch 20.16d guard is missing: {guard}")
    historical = HISTORICAL.read_text(encoding="utf-8")
    require("guard-cranelift-phase20-cross-feature-qualification-full" in historical,
            "Phase 20 historical owner drifted")
    require("just guard-cranelift-phase20-protected-access-liveness-full" in
            justfile.split(
                "guard-cranelift-phase20-cross-feature-qualification-full:", 1
            )[1],
            "Phase 20 Level 3 composition does not include Patch 20.16d")
    return authority


def render(authority: dict) -> str:
    return "\n".join([
        "# Cranelift Phase 20 Protected-Access Liveness",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_protected_access_liveness.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{authority['contract_version']}`",
        f"- Status: `{authority['status']}`",
        f"- Next patch: `{authority['next_patch']}`",
        "- Implementation authority landed: `true`",
        "",
        "## Safe authority",
        "",
        "A reference-returning call with exactly one live move-only Resource",
        "guard receiver or argument inherits that guard's canonical acquisition",
        "identity. Moving the guard preserves the identity and transfers the",
        "obligation. Scalar copies cease to alias protected storage; references,",
        "pointers, strings, slices, and aggregates retain the root.",
        "",
        "Rooted access is rejected after terminal guard state. It cannot be",
        "returned, stored in fields or containers, or passed through an unchecked",
        "callee boundary. Multiple candidate guard roots are rejected as",
        "ambiguous. This is generic Resource authority, not a Mutex special case",
        "and not a separate access token.",
        "",
        "## Mutex and cleanup boundary",
        "",
        "Raw `Mutex.Lock()` and `Mutex.Unlock()` now require explicit `unsafe`.",
        "Their lowering, runtime symbols, ABI, layout, and MIR remain unchanged.",
        "The source oracle proves compiler-inserted destructor unlock exactly once",
        "on normal, early-return, conditional, and selected failure exits. The",
        "supported canonical-MIR/Cranelift probe exercises the same four unlocked",
        "lifecycle cycles and shares exit observable `72`, without fallback.",
        "",
        "## Handoff",
        "",
        "After this patch is merged, the registrar may resume Stdlib S1.8 and",
        "re-derive its work from checked compiler authority. This record does not",
        "select Stdlib names, representation, re-entrancy, or accessor ergonomics.",
        "Bootstrap seed reconvergence remains isolated in Patch 20.16e.",
        "",
    ])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review"))
    args = parser.parse_args()
    try:
        authority = validate()
        if args.command == "project":
            REVIEW.write_text(render(authority), encoding="utf-8")
        elif args.command == "check-review":
            require(REVIEW.read_text(encoding="utf-8") == render(authority),
                    "generated Patch 20.16d review is stale; run project")
    except (Error, KeyError, json.JSONDecodeError) as error:
        print(f"{GUARD}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
