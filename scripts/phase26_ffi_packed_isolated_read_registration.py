#!/usr/bin/env python3
"""Pin the bounded Phase 26.1 packed isolated read successor."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase26-ffi-packed-isolated-read"
SCRIPT = "scripts/phase26_ffi_packed_isolated_read.sh"
FIXTURES = [
    "compiler/phase26_ffi_packed_isolated_read_source.gst",
    "compiler/phase26_ffi_packed_isolated_wrong_host_source.gst",
    "compiler/phase26_ffi_packed_isolated_wrong_policy_source.gst",
    "compiler/phase26_ffi_packed_isolated_missing_repr_source.gst",
    "compiler/phase26_ffi_packed_isolated_nested_source.gst",
]


def require(value: bool, message: str) -> None:
    if not value:
        raise SystemExit(f"{GUARD}: {message}")


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def main() -> None:
    registry = json.loads((ROOT / "scripts/cranelift_feature_registry.json")
                          .read_text(encoding="utf-8"))
    activation = registry["phase26_activation_audit"]
    record = activation.get("ffi_packed_isolated_read_increment", {})
    expected = {
        "contract_version": "phase26_1d_packed_isolated_read_ffi_layout_v1",
        "status": "selected_flat_packed_repr_c_isolated_read_qualified",
        "owner": "cranelift", "increment": "26.1D_packed_isolated_read_subset",
        "operator_ownership_decision": "2026-09-28_bounded_packed_isolated_read",
        "supported_position": "unsafe_borrow_read_isolated_call_reference_to_flat_packed_repr_c_struct",
        "selected_host_import": "tiny_host_read_packed_probe",
        "selected_host_object": "generated_test_only_existing_host_object_slot",
        "physical_abi_changed": False,
        "target_layout": "x86_64_linux_elf_byte_int_byte_offsets_0_1_5_size_6_align_1",
        "unaligned_int_access": "bytewise_native_host_read_after_six_byte_isolated_copy",
        "arena_lifetime": "copy_in_host_call_free_on_normal_return",
        "positive_fixture": FIXTURES[0],
        "negative_fixtures": FIXTURES[1:],
        "positive_output": "24\\n20\\n",
        "failure_stage": "before_driver_discovery",
        "deferral_reason": "deferred_p26_ffi_borrowed_c_layout",
        "native_fallback": False,
        "runtime_symbol_surface_changed": False,
        "remaining_layout_obligations": ["general_packed_layout", "enum_representation",
                                         "by_value_aggregate", "nested_aggregate",
                                         "packed_isolated_write"],
        "owning_level2_guard": GUARD, "pr_fast_job": "phase26-ffi-position",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"registry field drifted: {key}")
    require(set(record) == set(expected) | {
        "phase22_invocation_successor", "production_audit_successor",
        "phase23_text_surface_successor", "spelling_inventory_successor",
    }, "registry acquired unreviewed packed isolated read fields")
    for path in FIXTURES:
        require((ROOT / path).is_file(), f"registered fixture missing: {path}")

    from phase22_opening import scan_invocations
    invocation = record["phase22_invocation_successor"]
    rows = [row for row in scan_invocations() if row["path"] == SCRIPT]
    require(invocation == {
        "contract_version": "phase26_1d_packed_isolated_read_phase22_invocation_successor_v1",
        "previous_total": 184, "current_total": 184 + len(rows),
        "added_rows": rows,
        "partial_extra_or_substituted_invocation": "rejected",
    } and len(rows) == 2, "native invocation successor drifted")
    require(record["production_audit_successor"] == {
        "contract_version": "phase26_1d_packed_isolated_read_production_audit_successor_v1",
        "previous_repository_invocation_count": 184,
        "current_repository_invocation_count": 184 + len(rows),
        "added_invocation_path": SCRIPT,
        "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    }, "production audit successor drifted")

    from phase24_semantic_spelling_inventory import source_sites, manifest_summary
    spelling = record["spelling_inventory_successor"]
    require(spelling == {
        "contract_version": "phase26_1d_packed_isolated_read_spelling_inventory_successor_v1",
        "previous_inventory_summary": activation["ffi_packed_write_increment"][
            "spelling_inventory_successor"]["current_inventory_summary"],
        "current_inventory_summary": activation.get(
            "ffi_packed_isolated_write_increment", {}).get(
                "spelling_inventory_successor", {}).get(
                    "previous_inventory_summary", manifest_summary(source_sites())),
        "changed_source_paths": sorted(FIXTURES),
        "partial_extra_or_substituted_inventory": "rejected",
    }, "spelling inventory successor drifted")

    surface = record["phase23_text_surface_successor"]
    require(surface.get("contract_version") ==
            "phase26_1d_packed_isolated_read_phase23_text_surface_successor_v1" and
            surface.get("partial_extra_or_substituted_surface") == "rejected" and
            len({row["path"] for row in surface.get("changed_rows", [])}) ==
            len(surface.get("changed_rows", [])) and
            len({row["path"] for row in surface.get("added_rows", [])}) ==
            len(surface.get("added_rows", [])),
            "text surface successor shape drifted")
    for row in surface["changed_rows"]:
        later = {entry["path"]: entry for entry in activation.get(
            "ffi_packed_isolated_write_increment", {}).get(
                "phase23_text_surface_successor", {}).get("changed_rows", [])}.get(row["path"])
        computed = {entry["path"]: entry for entry in activation.get(
            "computed_zero_raw_null_increment", {}).get(
                "phase23_text_surface_successor", {}).get("changed_rows", [])}.get(row["path"])
        field_zero = {entry["path"]: entry for entry in activation.get(
            "field_zero_evidence_increment", {}).get(
                "phase23_text_surface_successor", {}).get("changed_rows", [])}.get(row["path"])
        predecessor_digest = (computed["current_digest"] if computed else
                              later["current_digest"] if later else row["current_digest"])
        require((later is None or later["previous_digest"] == row["current_digest"]) and
                (computed is None or computed["previous_digest"] ==
                 (later["current_digest"] if later else row["current_digest"])) and
                (field_zero is None or field_zero["previous_digest"] ==
                 predecessor_digest) and
                (field_zero["current_digest"] if field_zero else
                 predecessor_digest) == digest(row["path"]) and
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
            "python3 scripts/phase26_ffi_packed_isolated_read_registration.py" in justfile and
            workflow.count(f"just {GUARD}") == 1 and
            "poison-driver.invoked" in guard and
            "deferred_p26_ffi_borrowed_c_layout" in guard and
            "printf '24\\n20\\n'" in guard and
            "tiny_host_read_packed_probe" in guard and "os_Arena_Free" in guard,
            "packed isolated read native evidence weakened")
    print(f"{GUARD}: registration ok")


if __name__ == "__main__":
    main()
