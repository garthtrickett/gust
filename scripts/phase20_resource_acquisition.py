#!/usr/bin/env python3
"""Validate and project Patch 20.9 acquisition-site resource authority."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE20_RESOURCE_ACQUISITION_OBLIGATIONS.md"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
JUSTFILE = ROOT / "justfile"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
GUARD_L1 = "guard-cranelift-phase20-resource-acquisition-contract"
GUARD_L2 = "guard-cranelift-phase20-resource-acquisition-parity"

NEGATIVES = [
    "compiler/future/p20_issue106_bound_directory_current.gst",
    "compiler/future/p20_issue106_unbound_directory_current.gst",
    "compiler/phase20_resource_acquisition_user_bound_invalid.gst",
    "compiler/phase20_resource_acquisition_user_discarded_invalid.gst",
    "compiler/phase20_resource_acquisition_directory_discarded_invalid.gst",
]
DIAGNOSTICS = ["ResourceAcquisitionLeak", "ResourceAcquisitionDiscarded"]


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    authority = registry.get("phase20_resource_acquisition_obligations")
    require(isinstance(authority, dict), "Patch 20.9 authority is missing")
    require(authority.get("authority_version") ==
            "phase20_resource_acquisition_obligations_v1",
            "Patch 20.9 authority version drifted")
    require(authority.get("status") == "patch20_9_complete" and
            authority.get("next_patch") == "20.10",
            "Patch 20.9 status or successor drifted")
    require(authority.get("issue") == "CR-5/#106",
            "Patch 20.9 issue ownership drifted")
    require(authority.get("negative_fixtures") == NEGATIVES,
            "Patch 20.9 negative matrix drifted")
    require(authority.get("diagnostics") == DIAGNOSTICS,
            "Patch 20.9 diagnostic matrix drifted")
    require(authority.get("enforcement_enabled") is True,
            "Patch 20.9 enforcement is not enabled")

    for key in ("user_positive_fixture", "directory_positive_fixture",
                "module_fixture"):
        require((ROOT / authority[key]).is_file(),
                f"Patch 20.9 fixture is missing: {authority[key]}")
    for path in NEGATIVES:
        require((ROOT / path).is_file(),
                f"Patch 20.9 negative fixture is missing: {path}")

    source = TYPECHECKER.read_text(encoding="utf-8")
    for evidence in (
        "type ResourceAcquisitionObligation[ctx] struct",
        "resource_acquisition_obligations: std.HashMap",
        "resource_value_identities: std.HashMap",
        "func env_register_resource_acquisition(",
        "func env_resource_identity_for_expression(",
        "func env_bind_resource_expression(",
        "func env_transfer_resource_return_expression(",
        "func env_transfer_owned_resource_argument(",
        "func env_consume_resource_destructor_call(",
        "func env_report_discarded_resource_acquisition(",
        "func env_report_pending_resource_acquisitions(",
        "fallible guard's else branch is the acquisition-failure path",
        "[ResourceAcquisitionLeak]",
        "[ResourceAcquisitionDiscarded]",
    ):
        require(evidence in source,
                f"Patch 20.9 compiler evidence missing: {evidence}")

    module = (ROOT / authority["module_fixture"]).read_text(encoding="utf-8")
    for evidence in (
        "func assignment_success() int", "func alias_success() int",
        "func aggregate_success() int", "func return_acquired() Handle",
        "func returned_success() int", "func transfer_success() int",
        "destroy_handle(box.handle);", "return acquire();",
    ):
        require(evidence in module,
                f"Patch 20.9 transfer evidence missing: {evidence}")

    user_positive = (ROOT / authority["user_positive_fixture"]).read_text(
        encoding="utf-8")
    require("std.FormatInt(7);" in user_positive and
            "resource.transfer_success()" in user_positive,
            "non-resource control or user transfer positive drifted")
    directory_positive = (ROOT / authority["directory_positive_fixture"]).read_text(
        encoding="utf-8")
    require("guard directory := os.OpenDir" in directory_positive and
            "os.CloseDir(directory);" in directory_positive,
            "conditional directory transfer positive drifted")

    opening = registry.get("opening_snapshots", {}).get("phase20", {})
    require(opening.get("status") == "ready_for_patch20_10" and
            opening.get("next_patch") == "20.10",
            "Phase 20 opening successor did not advance to Patch 20.10")
    probes = {probe["id"]: probe for probe in opening.get("baseline_probes", [])}
    for probe_id in ("issue106_bound_directory_control",
                     "issue106_unbound_directory_payload"):
        probe = probes.get(probe_id, {})
        require(probe.get("compile_exit") == 1 and
                probe.get("fix_enabled") is True and
                "[ResourceAcquisitionLeak]" in probe.get("diagnostic_substrings", []),
                f"Patch 20.9 opening probe did not flip: {probe_id}")

    require("- [x] Patch 20.9 — Acquisition-Site Resource Obligations (#106) — DONE" in
            TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 20.9 DONE")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 20.9 guard levels drifted")
    workflow = PR_FAST.read_text(encoding="utf-8")
    require("Phase 20 resource acquisition obligations" in workflow and
            f"just {GUARD_L1}" in workflow,
            "PR Fast does not own the Patch 20.9 Level 1 guard")
    justfile = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in justfile and f"{GUARD_L2}:" in justfile,
            "Patch 20.9 just guards are missing")
    return authority


def render(authority: dict) -> str:
    return "\n".join([
        "# Cranelift Phase 20 Resource Acquisition Obligations",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase20_resource_acquisition.py project`. Do not edit by hand.",
        "",
        f"- Authority version: `{authority['authority_version']}`",
        f"- Status: `{authority['status']}`",
        f"- Next patch: `{authority['next_patch']}`",
        f"- Issue: `{authority['issue']}`",
        "- Enforcement enabled: `true`",
        "",
        "## Acquisition identity",
        "",
        "A tracking-eligible call expression creates one stable obligation",
        "identity from its source location. Binding, assignment, aliases,",
        "aggregate storage, payload extraction, guards, owned arguments, and",
        "returns transport that identity instead of creating binding-local",
        "copies. A fallible guard's else branch carries no successful",
        "acquisition; its success payload inherits the pending identity.",
        "",
        "Both #106 directory shapes and a user-declared bound leak now reject",
        "with `ResourceAcquisitionLeak`. Ignored directory and user-resource",
        "calls reject at full-expression end with",
        "`ResourceAcquisitionDiscarded`. A non-resource call remains accepted.",
        "",
        "## Patch boundary",
        "",
        "Patch 20.9 establishes ownership and transfer only. Patch 20.10 still",
        "owns automatic destructor invocation, reverse lexical/field order, and",
        "nested resource-field cleanup. No MIR, ABI, runtime-symbol, or backend",
        "meaning changes here.",
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
                    "generated Patch 20.9 review is stale; run project")
    except (Error, KeyError) as error:
        print(f"{GUARD_L1}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
