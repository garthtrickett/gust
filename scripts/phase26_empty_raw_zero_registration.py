#!/usr/bin/env python3
"""Pin the bounded Phase 26.1 canonical Empty raw-pointer zero-evidence successor."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-empty-raw-zero-evidence"
SCRIPT = "scripts/phase26_empty_raw_zero_evidence.sh"
POSITIVE = "compiler/phase26_empty_raw_zero_test_entry.gst"
NEGATIVES = [
    f"compiler/phase26_empty_raw_zero_{name}_source.gst"
    for name in ("safe_call", "safe_return")
]
CONTROLS = [
    f"compiler/phase26_empty_raw_zero_{name}_source.gst"
    for name in ("nonzero", "unknown", "unsafe")
]


def require(value: bool, message: str) -> None:
    if not value:
        raise SystemExit(f"{GUARD}: {message}")


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def before_call_return_zero_digest(activation: dict, path: str,
                                   live_digest: str) -> str:
    """Project the later exact text-surface successor to this closed patch."""
    two_wrapper_rows = activation.get("call_two_wrapper_zero_evidence_increment", {}).get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])
    two_wrapper_selected = [row for row in two_wrapper_rows if row.get("path") == path]
    require(len(two_wrapper_selected) <= 1,
            f"duplicate depth-two wrapper text surface: {path}")
    if two_wrapper_selected:
        two_wrapper_row = two_wrapper_selected[0]
        require(two_wrapper_row["current_digest"] == live_digest and
                len(two_wrapper_row["previous_digest"]) == 64,
                f"depth-two wrapper text surface drifted: {path}")
        live_digest = two_wrapper_row["previous_digest"]
    take_call_rows = activation.get("call_take_wrapper_zero_evidence_increment", {}).get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])
    take_call_selected = [row for row in take_call_rows if row.get("path") == path]
    require(len(take_call_selected) <= 1,
            f"duplicate Take(Call) text surface: {path}")
    if take_call_selected:
        take_call_row = take_call_selected[0]
        require(take_call_row["current_digest"] == live_digest and
                len(take_call_row["previous_digest"]) == 64,
                f"Take(Call) text surface drifted: {path}")
        live_digest = take_call_row["previous_digest"]
    move_call_rows = activation.get("call_move_wrapper_zero_evidence_increment", {}).get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])
    move_call_selected = [row for row in move_call_rows if row.get("path") == path]
    require(len(move_call_selected) <= 1,
            f"duplicate Move(Call) text surface: {path}")
    if move_call_selected:
        move_call_row = move_call_selected[0]
        require(move_call_row["current_digest"] == live_digest and
                len(move_call_row["previous_digest"]) == 64,
                f"Move(Call) text surface drifted: {path}")
        live_digest = move_call_row["previous_digest"]
    direct_move_rows = activation.get("call_direct_move_zero_evidence_increment", {}).get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])
    direct_move_selected = [row for row in direct_move_rows if row.get("path") == path]
    require(len(direct_move_selected) <= 1,
            f"duplicate direct-Move text surface: {path}")
    if direct_move_selected:
        direct_move_row = direct_move_selected[0]
        require(direct_move_row["current_digest"] == live_digest and
                len(direct_move_row["previous_digest"]) == 64,
                f"direct-Move text surface drifted: {path}")
        live_digest = direct_move_row["previous_digest"]
    direct_take_rows = activation.get("call_direct_take_zero_evidence_increment", {}).get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])
    direct_take_selected = [row for row in direct_take_rows if row.get("path") == path]
    require(len(direct_take_selected) <= 1,
            f"duplicate direct-Take text surface: {path}")
    if direct_take_selected:
        direct_take_row = direct_take_selected[0]
        require(direct_take_row["current_digest"] == live_digest and
                len(direct_take_row["previous_digest"]) == 64,
                f"direct-Take text surface drifted: {path}")
        live_digest = direct_take_row["previous_digest"]
    take_rows = activation.get("call_take_alias_zero_evidence_increment", {}).get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])
    take_selected = [row for row in take_rows if row.get("path") == path]
    require(len(take_selected) <= 1,
            f"duplicate Take-alias text surface: {path}")
    if take_selected:
        take_row = take_selected[0]
        require(take_row["current_digest"] == live_digest and
                len(take_row["previous_digest"]) == 64,
                f"Take-alias text surface drifted: {path}")
        live_digest = take_row["previous_digest"]
    chain_rows = activation.get("call_chain_zero_evidence_increment", {}).get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])
    chain_selected = [row for row in chain_rows if row.get("path") == path]
    require(len(chain_selected) <= 1,
            f"duplicate consecutive-alias text surface: {path}")
    if chain_selected:
        chain_row = chain_selected[0]
        require(chain_row["current_digest"] == live_digest and
                len(chain_row["previous_digest"]) == 64,
                f"consecutive-alias text surface drifted: {path}")
        live_digest = chain_row["previous_digest"]
    alias_rows = activation.get("call_alias_zero_evidence_increment", {}).get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])
    alias_selected = [row for row in alias_rows if row.get("path") == path]
    require(len(alias_selected) <= 1, f"duplicate one-hop alias text surface: {path}")
    if alias_selected:
        alias_row = alias_selected[0]
        require(alias_row["current_digest"] == live_digest and
                len(alias_row["previous_digest"]) == 64,
                f"one-hop alias text surface drifted: {path}")
        live_digest = alias_row["previous_digest"]
    local_rows = activation.get("call_local_zero_evidence_increment", {}).get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])
    local_selected = [row for row in local_rows if row.get("path") == path]
    require(len(local_selected) <= 1, f"duplicate one-local text surface: {path}")
    if local_selected:
        local_row = local_selected[0]
        require(local_row["current_digest"] == live_digest and
                len(local_row["previous_digest"]) == 64,
                f"one-local text surface drifted: {path}")
        live_digest = local_row["previous_digest"]
    rows = activation.get("call_return_zero_evidence_increment", {}).get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])
    selected = [row for row in rows if row.get("path") == path]
    require(len(selected) <= 1, f"duplicate direct-call return text surface: {path}")
    if not selected:
        return live_digest
    row = selected[0]
    require(row["current_digest"] == live_digest and
            len(row["previous_digest"]) == 64,
            f"direct-call return text surface drifted: {path}")
    return row["previous_digest"]


def before_empty_raw_zero_digest(activation: dict, path: str, live_digest: str) -> str:
    """Reverse only this registered successor for older exact-surface owners."""
    live_digest = before_call_return_zero_digest(activation, path, live_digest)
    rows = activation.get("empty_raw_zero_evidence_increment", {}).get(
        "phase23_text_surface_successor", {}).get("changed_rows", [])
    selected = [row for row in rows if row.get("path") == path]
    require(len(selected) <= 1, f"duplicate Empty raw-pointer text surface: {path}")
    if not selected:
        return live_digest
    row = selected[0]
    require(row["current_digest"] == live_digest and
            len(row["previous_digest"]) == 64,
            f"Empty raw-pointer text surface drifted: {path}")
    return row["previous_digest"]


def main() -> None:
    registry = json.loads((ROOT / "scripts/cranelift_feature_registry.json")
                          .read_text(encoding="utf-8"))
    activation = registry["phase26_activation_audit"]
    record = activation.get("empty_raw_zero_evidence_increment", {})
    expected = {
        "contract_version": "phase26_1e_empty_raw_zero_v1",
        "status": "bounded_empty_raw_zero_safe_boundary_rejection_qualified",
        "owner": "cranelift", "increment": "26.1E_empty_raw_pointer_subset",
        "operator_ownership_decision": "2026-09-29_bounded_empty_raw_zero",
        "value_states": ["Unknown", "Zero", "Nonzero", "MayZero"],
        "transfer_ops": ["typechecked_empty_raw_pointer_zero_initialize"],
        "other_empty_types": "Unknown_including_Index_sentinel",
        "preserved_transfers": ["cast", "local_binding", "literal", "unsafe_callee"],
        "positive_fixture": POSITIVE, "negative_fixtures": NEGATIVES,
        "control_fixtures": CONTROLS,
        "positive_output": "SUCCESS: canonical Empty raw-pointer zero evidence and safe-boundary controls verified\n",
        "safe_boundaries": ["declared_nonextern_raw_pointer_argument",
                            "declared_nonextern_raw_pointer_return"],
        "negative_states": ["Zero"],
        "unknown_and_nonzero": "preserved_without_general_nullability_claim",
        "unsafe_callees": "preserved",
        "diagnostic": "[RawNullSafeBoundary]",
        "failure_stage": "before_driver_discovery",
        "native_fallback": False, "physical_abi_changed": False,
        "mir_changed": False, "runtime_symbol_surface_changed": False,
        "operator_semantics_changed": False,
        "general_nullability": "open_separate_obligation",
        "phase26_1_closed": False,
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"registry field drifted: {key}")
    require(set(record) == set(expected) | {
        "phase22_invocation_successor", "production_audit_successor",
        "phase23_text_surface_successor", "spelling_inventory_successor",
        "filename_site_successor",
    }, "registry acquired unreviewed Empty raw-pointer fields")
    for path in [POSITIVE, *NEGATIVES, *CONTROLS]:
        require((ROOT / path).is_file(), f"registered fixture missing: {path}")

    from phase22_opening import scan_invocations
    rows = [row for row in scan_invocations() if row["path"] == SCRIPT]
    require(record["phase22_invocation_successor"] == {
        "contract_version": "phase26_1e_empty_raw_zero_phase22_invocation_successor_v1",
        "previous_total": 216, "current_total": 218, "added_rows": rows,
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows) == 2, "native invocation successor drifted")
    require(record["production_audit_successor"] == {
        "contract_version": "phase26_1e_empty_raw_zero_production_audit_successor_v1",
        "previous_repository_invocation_count": 216,
        "current_repository_invocation_count": 218,
        "added_invocation_path": SCRIPT, "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "production audit successor drifted")

    from phase24_semantic_spelling_inventory import source_sites, manifest_summary
    call_return_zero = activation.get("call_return_zero_evidence_increment", {})
    require(record["spelling_inventory_successor"] == {
        "contract_version": "phase26_1e_empty_raw_zero_spelling_inventory_successor_v1",
        "previous_inventory_summary": activation["explicit_brand_prerequisite"][
            "spelling_inventory_successor"]["current_inventory_summary"],
        "current_inventory_summary": (manifest_summary(source_sites())
            if not call_return_zero else call_return_zero[
                "spelling_inventory_successor"]["previous_inventory_summary"]),
        "changed_source_paths": sorted(["compiler/typechecker.gst", POSITIVE,
                                        *NEGATIVES, *CONTROLS]),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "spelling inventory successor drifted")

    from phase24_filename_behavior_characterization import source_sites as filename_sites
    previous = activation["explicit_brand_prerequisite"][
        "filename_site_successor"]["current_sites"]
    current = (filename_sites() if not call_return_zero else
               call_return_zero["filename_site_successor"]["previous_sites"])
    require(record["filename_site_successor"] == {
        "contract_version": "phase26_1e_empty_raw_zero_filename_site_successor_v1",
        "previous_sites": previous, "current_sites": current,
        "line_deltas": [current_row["line"] - previous_row["line"]
                        for previous_row, current_row in zip(previous, current)],
        "partial_extra_or_substituted_site": "rejected",
    } and len(current) == len(previous) == 3,
            "filename site successor drifted")

    surface = record["phase23_text_surface_successor"]
    require(surface.get("contract_version") ==
            "phase26_1e_empty_raw_zero_phase23_text_surface_successor_v1" and
            surface.get("partial_extra_or_substituted_surface") == "rejected" and
            len({row["path"] for row in surface.get("changed_rows", [])}) ==
            len(surface.get("changed_rows", [])) and
            len({row["path"] for row in surface.get("added_rows", [])}) ==
            len(surface.get("added_rows", [])), "text surface successor shape drifted")
    for row in surface["changed_rows"]:
        require(row["current_digest"] == before_call_return_zero_digest(
                    activation, row["path"], digest(row["path"])) and
                len(row["previous_digest"]) == 64,
                f"changed text surface drifted: {row['path']}")
    for row in surface["added_rows"]:
        require(row["digest"] == digest(row["path"]),
                f"added text surface drifted: {row['path']}")

    justfile = (ROOT / "justfile").read_text(encoding="utf-8")
    workflow = (ROOT / ".github/workflows/pr-fast.yml").read_text(encoding="utf-8")
    guard = (ROOT / SCRIPT).read_text(encoding="utf-8")
    levels = json.loads((ROOT / "scripts/cranelift_test_levels.json")
                        .read_text(encoding="utf-8"))
    require(levels["guards"].get(GUARD) == 2 and
            justfile.count(f"{GUARD}:") == 1 and
            "python3 scripts/phase26_empty_raw_zero_registration.py" in justfile and
            workflow.count(f"just {GUARD}") == 1 and
            "poison-driver.invoked" in guard and
            "GUST_TEST_MIR_TO_C_UNAVAILABLE=1" in guard and
            "[RawNullSafeBoundary]" in guard and
            "safe_call safe_return nonzero unknown unsafe" in guard and
            "phase26_relational_zero_evidence.sh" in guard,
            "Empty raw-pointer native evidence weakened")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
