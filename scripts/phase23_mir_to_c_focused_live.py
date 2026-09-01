#!/usr/bin/env python3
"""Validate and project the Patch 23.10 focused live MIR-to-C lane."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE23_MIR_TO_C_FOCUSED_LIVE.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
HEAVY = ROOT / ".github/workflows/heavy-guards.yml"
LEGACY = ROOT / ".github/workflows/phase21-cranelift-built-compiler-programs.yml"
WORKFLOW = ROOT / ".github/workflows/phase23-mir-to-c-focused-live.yml"
GUARD_L1 = "guard-cranelift-phase23-mir-to-c-focused-live-contract"
GUARD_L2 = "guard-cranelift-phase23-mir-to-c-focused-live-evidence"

REQUIRED_COVERAGE = {
    "success", "rejection", "resource", "module", "typed_query",
    "output_artifact", "side_effects",
}
PATH_FILTERS = (
    "'TASK.md'", "'README.md'", "'GEMINI.md'", "'gust_v4.c'",
    "'Makefile'", "'*.sh'", "'compiler/**'", "'docs/**'",
    "'scripts/**'", "'src/**'", "'tests/**'", "'justfile*'",
    "'.github/workflows/**'",
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def digest_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def canonical_digest(value: object) -> str:
    return digest_bytes(json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=True,
    ).encode("utf-8"))


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    require(spec is not None and spec.loader is not None,
            f"cannot load {path.relative_to(ROOT)}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def family_rows(registry: dict) -> list[dict[str, object]]:
    module = load_module("cranelift_ci_family", ROOT / "scripts/cranelift_ci_family.py")
    rows = []
    for family in module.ordered_active_families(registry):
        selected = module.selected_rows(registry, family, migrated_only=True)
        require(selected, f"focused family is empty: {family}")
        rows.append({
            "family": family,
            "entry_ids": sorted(str(row["id"]) for row in selected),
            "complete_entry_manifest_digest": canonical_digest(sorted(
                selected, key=lambda row: str(row["id"])
            )),
            "runner": copy.deepcopy(module.RUNNER_BY_FAMILY[family]),
        })
    require(rows and len({row["family"] for row in rows}) == len(rows),
            "focused family identity is empty or duplicated")
    return rows


def program_rows(registry: dict) -> list[dict[str, object]]:
    predecessor = registry["phase21_cranelift_built_compiler_programs"]
    roles = {
        "scalar_positive": ["success", "output_artifact"],
        "resource_cleanup": ["success", "resource", "output_artifact", "side_effects"],
        "imported_module": ["success", "module", "output_artifact"],
        "trusted_typed_query": ["success", "typed_query", "output_artifact"],
        "scalar_type_error": ["rejection"],
        "typed_query_provenance_error": ["rejection", "typed_query"],
    }
    rows = []
    for kind, cases in (("accepted", predecessor["accepted_cases"]),
                        ("rejected", predecessor["rejected_cases"])):
        for case in cases:
            case_id = str(case["id"])
            require(case_id in roles, f"unregistered focused program: {case_id}")
            source = ROOT / str(case["source_fixture"])
            require(source.is_file(), f"focused source is missing: {source.relative_to(ROOT)}")
            rows.append({
                "id": case_id,
                "kind": kind,
                "coverage": roles[case_id],
                "source_fixture": str(case["source_fixture"]),
                "source_digest": digest_bytes(source.read_bytes()),
                "observable_contract_digest": canonical_digest(case),
            })
    rows.sort(key=lambda row: str(row["id"]))
    require(set(roles) == {str(row["id"]) for row in rows},
            "focused program cohort is partial or substituted")
    coverage = {role for row in rows for role in row["coverage"]}
    require(coverage == REQUIRED_COVERAGE,
            f"focused coverage drifted: {sorted(coverage)}")
    return rows


def scan(registry: dict) -> dict[str, object]:
    families = family_rows(registry)
    programs = program_rows(registry)
    return {
        "family_count": len(families),
        "family_ids": [row["family"] for row in families],
        "family_manifest_digest": canonical_digest(families),
        "program_count": len(programs),
        "program_ids": [row["id"] for row in programs],
        "program_manifest_digest": canonical_digest(programs),
        "coverage": sorted(REQUIRED_COVERAGE),
    }


def accepts(record: dict, summary: dict[str, object]) -> bool:
    return record.get("cohort") == summary and record.get("route_contract") == {
        "owner": "phase23_mir_to_c_focused_live",
        "non_bootstrap_live_lane_count": 1,
        "oracle_backend": "explicit_mir_to_c",
        "subject_backend": "explicit_cranelift",
        "fallback": "forbidden",
        "default_production_native_matrices_contain_mir_to_c": False,
        "bootstrap_C_owner": "phase25",
        "archive_successor": "23.11",
    }


def validate_mutations(record: dict, summary: dict[str, object]) -> None:
    require(accepts(record, summary), "registered focused cohort drifted")
    for label, mutated in (
        ("empty family cohort", {**summary, "family_count": 0, "family_ids": [],
                                 "family_manifest_digest": canonical_digest([])}),
        ("family omission", {**summary, "family_count": summary["family_count"] - 1,
                             "family_ids": summary["family_ids"][1:]}),
        ("same-count family substitution", {**summary,
            "family_ids": [str(summary["family_ids"][0]) + "-substituted"]
            + list(summary["family_ids"])[1:]}),
        ("program omission", {**summary, "program_count": summary["program_count"] - 1,
                              "program_ids": summary["program_ids"][1:]}),
        ("same-count program substitution", {**summary,
            "program_ids": [str(summary["program_ids"][0]) + "-substituted"]
            + list(summary["program_ids"])[1:]}),
        ("missing coverage", {**summary, "coverage": summary["coverage"][1:]}),
    ):
        require(not accepts(record, mutated), f"accepted {label}")
    fallback = copy.deepcopy(record)
    fallback["route_contract"]["fallback"] = "allowed"
    require(not accepts(fallback, summary), "accepted fallback")


def validate() -> tuple[dict, dict[str, object]]:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase23_mir_to_c_focused_live")
    require(isinstance(record, dict), "Patch 23.10 authority is missing")
    expected_header = {
        "contract_version": "phase23_mir_to_c_focused_live_v1",
        "status": "patch23_10_complete",
        "next_patch": "23.11",
        "owner": "cranelift",
        "review_view": REVIEW.relative_to(ROOT).as_posix(),
        "renderer": Path(__file__).relative_to(ROOT).as_posix(),
    }
    for key, value in expected_header.items():
        require(record.get(key) == value, f"{key} drifted")
    summary = scan(registry)
    validate_mutations(record, summary)
    require(record.get("budgets") == {
        "workflow_timeout_minutes": 75,
        "family_job_timeout_minutes": 60,
        "whole_program_suite_elapsed_ms": 180000,
        "whole_program_peak_rss_kib": 6291456,
    }, "focused lane budgets drifted")
    require(record.get("removed_default_coverage") == [
        {"source": "pr_fast_static_matrix", "cell": "mir-to-c-return-int",
         "successor": "family_and_whole_program_focused_lane"},
        {"source": "pr_fast_phase11_family_matrix", "cell": "14_registry_families",
         "successor": "focused_family_matrix"},
        {"source": "heavy_guards_matrix", "cell": "mir-to-c-boring-surface",
         "guard": "guard-mir-to-c-boring-surface",
         "successor": "focused_family_and_archived_23_11"},
        {"source": "phase21_compiler_programs_workflow", "cell": "evidence",
         "successor": "focused_whole_program"},
    ], "removed coverage map drifted")
    require(record.get("boundary") == {
        "changes_accepted_Gust_program_meaning": False,
        "adds_or_changes_MIR_operations": False,
        "changes_ABI_layout_runtime_symbols_target_or_linker": False,
        "changes_backend_route_default_or_fallback": False,
        "changes_bootstrap_route_or_seed": False,
        "edits_stdlib_or_CR15": False,
        "begins_patch23_11": False,
    }, "Patch 23.10 boundary widened")

    task = TASK.read_text(encoding="utf-8")
    for patch in ("23.7", "23.8", "23.8a", "23.9", "23.10"):
        require(re.search(rf"^- \[x\] Patch {re.escape(patch)} .* — DONE$", task, re.M)
                is not None, f"mandatory Patch {patch} status is not DONE")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 23.10 guard levels drifted")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in just and f"{GUARD_L2}:" in just,
            "Patch 23.10 just guards are missing")

    pr_fast = PR_FAST.read_text(encoding="utf-8")
    for retired in ("mir-to-c-return-int", "phase11-family:", "phase11_families:",
                    'just guard-cranelift-differential-family "${{ matrix.family }}"'):
        require(retired not in pr_fast, f"PR Fast retains MIR-to-C matrix token: {retired}")
    require("routed-return-int" in pr_fast and f"just {GUARD_L1}" in pr_fast,
            "PR Fast lost native coverage or focused contract")
    heavy = HEAVY.read_text(encoding="utf-8")
    require("mir-to-c-boring-surface" not in heavy,
            "Heavy Guards retains a MIR-to-C matrix cell")
    legacy = LEGACY.read_text(encoding="utf-8")
    require(f"just guard-cranelift-phase21-cranelift-built-compiler-programs-contract" in legacy
            and "guard-cranelift-phase21-cranelift-built-compiler-programs-evidence" not in legacy,
            "Phase 21 workflow did not delegate only its live evidence")

    workflow = WORKFLOW.read_text(encoding="utf-8")
    for token in (
        f"just {GUARD_L1}", f"just {GUARD_L2}",
        "python3 scripts/cranelift_ci_family.py matrix-json",
        'just guard-cranelift-differential-family "${{ matrix.family }}"',
        "just guard-cranelift-phase21-cranelift-built-compiler-programs-evidence",
        "make gust phase10-native-package",
    ):
        require(workflow.count(token) == 1, f"focused workflow ownership drifted: {token}")
    for path_filter in PATH_FILTERS:
        require(workflow.count(path_filter) == 2,
                f"focused workflow does not own both path filters for {path_filter}")
    require(REVIEW.is_file() and REVIEW.read_text(encoding="utf-8") == render(record),
            "generated focused-live review is stale; run project")
    return record, summary


def render(record: dict) -> str:
    cohort = record["cohort"]
    lines = [
        "# Cranelift Phase 23.10 — Focused Live MIR-to-C Compatibility Lane",
        "",
        "Generated from the canonical feature registry. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Registry-derived families: `{cohort['family_count']}`",
        f"- Family manifest: `{cohort['family_manifest_digest']}`",
        f"- Whole-program cases: `{cohort['program_count']}`",
        f"- Program manifest: `{cohort['program_manifest_digest']}`",
        f"- Coverage: `{', '.join(cohort['coverage'])}`",
        "- Oracle: explicit `mir-to-c`; subject: explicit `cranelift`; fallback: forbidden.",
        "- This is the sole registered non-bootstrap live-C compatibility lane.",
        "",
        "## Families",
        "",
    ]
    lines += [f"- `{family}`" for family in cohort["family_ids"]]
    lines += ["", "## Whole-program cohort", ""]
    lines += [f"- `{case_id}`" for case_id in cohort["program_ids"]]
    lines += ["", "## Removed default-CI coverage", ""]
    for row in record["removed_default_coverage"]:
        lines.append(f"- `{row['source']}` / `{row['cell']}` → `{row['successor']}`")
    lines += [
        "",
        "Patch 23.10 changes no accepted Gust meaning, MIR operation, ABI/layout/runtime",
        "contract, backend route/default/fallback, bootstrap route, or seed.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=(
        "scan", "validate", "project", "check-review", "evidence",
    ))
    args = parser.parse_args()
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    if args.command == "scan":
        print(json.dumps(scan(registry), indent=2, sort_keys=True))
        return
    if args.command == "project":
        record = registry.get("phase23_mir_to_c_focused_live")
        require(isinstance(record, dict), "Patch 23.10 authority is missing")
        REVIEW.write_text(render(record), encoding="utf-8")
        validate()
        print(f"{GUARD_L1}: project ok")
        return
    record, _ = validate()
    if args.command == "evidence":
        print("phase23_mir_to_c_focused_live: evidence ok")
    else:
        print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
