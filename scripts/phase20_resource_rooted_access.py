#!/usr/bin/env python3
"""Validate and project Patch 20.16b inert resource-rooted access authority."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
CODEGEN = ROOT / "compiler/codegen.gst"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_RESOURCE_ROOTED_ACCESS.md"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
JUSTFILE = ROOT / "justfile"
GUARD = "guard-cranelift-phase20-resource-rooted-access-contract"


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    authority = registry.get("phase20_resource_rooted_access")
    require(isinstance(authority, dict), "Patch 20.16b authority is missing")
    require(authority.get("contract_version") ==
            "phase20_resource_rooted_access_v1",
            "Patch 20.16b contract version drifted")
    require(authority.get("status") == "patch20_16b_complete",
            "Patch 20.16b status drifted")
    require(authority.get("next_patch") == "20.16c",
            "Patch 20.16b successor drifted")
    require((ROOT / authority["semantic_fixture"]).is_file(),
            "Patch 20.16b semantic fixture is missing")

    typechecker = TYPECHECKER.read_text(encoding="utf-8")
    for evidence in (
        "resource_root_identity: str",
        "func expression_provenance_with_resource_root(",
        "func expression_provenance_has_resource_root(",
        "func expression_provenance_resource_root_identity(",
        "func env_expression_provenance_rooted_in_resource_storage(",
        "func env_expression_provenance_resource_root_is_live(",
        "env_type_is_safe_branded_return_target(prov.resolved_type, ctx) == 0",
        "expression_provenance_allows_safe_branding(prov) == 0",
        "std.str_eq(left.resource_root_identity, right.resource_root_identity)",
        "safe_readback_prov.resource_root_identity = std.Clone(",
    ):
        require(evidence in typechecker,
                f"resource-rooted access carrier evidence is missing: {evidence}")
    require(typechecker.count(
        "env_expression_provenance_rooted_in_resource_storage("
    ) == 1, "resource-root constructor was enabled on a live typechecking path")

    fixture = (ROOT / authority["semantic_fixture"]).read_text(encoding="utf-8")
    for evidence in (
        "env_register_resource_parameter_obligation(",
        "env_expression_provenance_rooted_in_resource_storage(",
        "expression_provenance_inherit_readback(",
        "expression_provenance_join(",
        "env_bind_resource_identity(",
        "env_resource_obligation_set_state(",
        "raw-derived provenance received safe guard authority",
        "inert resource-root metadata changed current acceptance",
    ):
        require(evidence in fixture,
                f"Patch 20.16b witness coverage is missing: {evidence}")

    codegen = CODEGEN.read_text(encoding="utf-8")
    require("return make_type_pointer(val_t_lookup.Val, ctx);" in typechecker,
            "transitional Mutex.Lock return type changed during inert patch")
    require("std_Mutex_Lock_impl(" in codegen and
            "std_Mutex_Unlock_impl(" in codegen,
            "transitional Mutex raw primitive lowering changed during inert patch")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 20.16b — Inert Resource-Rooted Access Authority — DONE"
            in task, "TASK.md does not mark Patch 20.16b DONE")
    require("- [ ] Patch 20.16c — Explicit-Unsafe Mutex Primitive Migration"
            in task, "TASK.md does not preserve Patch 20.16c as the next boundary")

    workflow = PR_FAST.read_text(encoding="utf-8")
    require("Phase 20 inert resource-rooted access authority" in workflow and
            "just guard-cranelift-phase20-resource-rooted-access-contract"
            in workflow and
            "just guard-cranelift-phase20-resource-rooted-access-parity"
            in workflow,
            "PR Fast does not own both Patch 20.16b levels")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require("guard-cranelift-phase20-resource-rooted-access-contract:"
            in justfile and
            "guard-cranelift-phase20-resource-rooted-access-parity:"
            in justfile,
            "Patch 20.16b just guards are missing")
    return authority


def render(authority: dict) -> str:
    return "\n".join([
        "# Cranelift Phase 20 Inert Resource-Rooted Access Authority",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_resource_rooted_access.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{authority['contract_version']}`",
        f"- Status: `{authority['status']}`",
        f"- Next patch: `{authority['next_patch']}`",
        f"- Carrier: `{authority['carrier']}`",
        f"- Root authority: `{authority['root_authority']}`",
        "",
        "## Inert semantic carrier",
        "",
        "`ExpressionProvenance` may carry the canonical acquisition identity of",
        "the linear Resource guard that authorizes protected access. Safe readback",
        "preserves that identity. A control-flow join preserves it only when both",
        "paths carry the same non-empty identity, so a conditional path cannot",
        "invent universal authority. Guard rebinding continues to name the same",
        "acquisition obligation; terminal obligation state is observable as not live.",
        "",
        "No live typechecking path constructs this metadata in Patch 20.16b. The",
        "new helpers emit no diagnostic and enable no rejection. `Mutex.Lock()`",
        "still returns `RawPointer(T)`, raw Lock/Unlock lowering and every call site",
        "remain unchanged, and no separate access token or Mutex-specific Resource",
        "path exists.",
        "",
        "## Backend and bootstrap boundary",
        "",
        "The existing generic-guard source observable remains identical through",
        "MIR-to-C and supported Cranelift without fallback. The checked-in seed",
        "builds the additive carrier; generated reconvergence remains isolated in",
        "Patch 20.16e after migration and enforcement. Patch 20.16c is the next",
        "authorized boundary and owns only whole-tree explicit-unsafe migration.",
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
                    "generated Patch 20.16b review is stale; run project")
    except (Error, KeyError) as error:
        print(f"{GUARD}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
