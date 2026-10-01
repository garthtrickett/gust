#!/usr/bin/env python3
"""Validate and project the report-only Patch 24.2 spelling inventory.

The inventory is deliberately re-derived from tracked compiler-owned source.
It records each source-line/category site that contains a concrete stdlib/runtime
spelling and distinguishes semantic recognition from spellings used only for
diagnostics, serialization, mangling, comments, fixtures, or comparisons over
already-constructed evidence.  Patch 24.2 changes no compiler behaviour.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE24_SEMANTIC_SPELLING_INVENTORY.md"
REVIEW_PATH = REVIEW.relative_to(ROOT).as_posix()
GUARD = "guard-cranelift-phase24-semantic-spelling-inventory-contract"

CONCRETE = re.compile(
    r"(?<![A-Za-z0-9])(?:"
    r"std[._][A-Za-z][A-Za-z0-9_.]*|"
    r"os[._][A-Za-z][A-Za-z0-9_.]*|"
    r"(?:Arena|Vector|HashMap|Pool|Graph|Mutex|Channel|Resource|Rc|Option|"
    r"DirEntry|Dir|ThreadLocalContext|GenerationalArena|Spawn|FormatInt|"
    r"Format|Concat|Clone|ArenaAlloc|ScratchAlloc|VectorNew|HashMapNew|"
    r"PoolNew|GraphNew|MutexNew|ChannelNew|RcNew|CloseDir|OpenDir|LogInt|"
    r"LogStr|Args|Exit)(?:_[A-Za-z0-9_]+)?"
    r")(?![A-Za-z0-9])"
)
QUOTED = re.compile(r'"(?:[^"\\]|\\.)*"')
FUNCTION_GST = re.compile(r"^\s*func\s+([A-Za-z_][A-Za-z0-9_]*)")
FUNCTION_RS = re.compile(
    r"^\s*(?:pub(?:\([^)]*\))?\s+)?(?:async\s+)?fn\s+"
    r"([A-Za-z_][A-Za-z0-9_]*)"
)

SEMANTIC = "semantic_or_intrinsic_recognition"
PARTITIONS = (
    "diagnostic",
    "serialization",
    "mangling_or_generated_name",
    "comment",
    "fixture_or_evidence",
    "non_decision_comparison",
)
ALL_CLASSIFICATIONS = (SEMANTIC, *PARTITIONS)


class InventoryError(Exception):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise InventoryError(message)


def digest(value: object) -> str:
    if not isinstance(value, (bytes, bytearray)):
        value = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(value).hexdigest()


def tracked_sources() -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", "compiler/**/*.gst", "compiler/**/*.rs", "compiler/*.gst"],
        cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE,
    )
    paths = []
    for raw in result.stdout.splitlines():
        path = ROOT / raw
        if not path.is_file() or "/target/" in raw:
            continue
        paths.append(path)
    return sorted(set(paths))


def layer_for(path: str) -> str:
    name = Path(path).name
    if name in {"lexer.gst", "parser.gst"}:
        return "source_admission"
    if name in {"resolver.gst", "typechecker.gst"}:
        return "resolution_and_type_construction"
    if name == "codegen.gst":
        return "retained_C_codegen"
    if "mir_native_backend" in name:
        return "canonical_MIR_selection"
    if "/experiments/cranelift/src/" in f"/{path}":
        return "cranelift_translation"
    if name.startswith("mir_"):
        return "canonical_MIR_authority"
    return "compiler_support"


def is_fixture_path(path: str) -> bool:
    name = Path(path).name
    return (
        "/future/" in f"/{path}"
        or "_test_" in name
        or "_smoke_" in name
        or "_parity_" in name
        or name.endswith("_tests.rs")
    )


def classify(path: str, function: str, line: str, literal: str) -> str:
    stripped = line.lstrip()
    lower_function = function.lower()
    if stripped.startswith("//") or stripped.startswith("///"):
        return "comment"
    if is_fixture_path(path) or "#[cfg(test)]" in line:
        return "fixture_or_evidence"
    if any(word in lower_function for word in (
        "mangle", "erase", "canonical_type_ident", "get_c_type",
        "runtime_symbol", "debug_", "display_", "stringify",
    )):
        return "mangling_or_generated_name"
    if any(marker in line for marker in (
        "add_error", "Error::", "error(", "fail(", "panic!(", "unreachable!(",
        "invalid(", "expect(\"", "ok_or_else", "map_err",
    )) and (" " in literal or "requires" in literal or "missing" in literal):
        return "diagnostic"
    if any(word in lower_function for word in (
        "append_to_request", "append_field", "serialize", "emit_metadata",
        "write_manifest", "render_", "request_text",
    )):
        return "serialization"
    if ("validate" in lower_function or "validation" in lower_function) and (
        Path(path).name.startswith("mir_") or path.endswith("specialized_resource.rs")
    ):
        return "non_decision_comparison"
    return SEMANTIC


def source_sites() -> list[dict]:
    grouped: dict[tuple[str, int, str], dict] = {}
    for source in tracked_sources():
        path = source.relative_to(ROOT).as_posix()
        function = "module_scope"
        matcher = FUNCTION_RS if source.suffix == ".rs" else FUNCTION_GST
        for line_number, line in enumerate(source.read_text(encoding="utf-8").splitlines(), 1):
            match = matcher.match(line)
            if match:
                function = match.group(1)
            for quoted in QUOTED.finditer(line):
                literal = quoted.group(0)[1:-1]
                spellings = sorted(set(CONCRETE.findall(literal)))
                if not spellings:
                    continue
                classification = classify(path, function, line, literal)
                key = (path, line_number, classification)
                row = grouped.setdefault(key, {
                    "id": "",
                    "path": path,
                    "line": line_number,
                    "function": function,
                    "layer": layer_for(path),
                    "classification": classification,
                    "spellings": [],
                    "source_lines": [],
                    "decision": "",
                    "semantic_role": "",
                    "current_authority": "live_compiler_source_at_inventory_base",
                    "present_owner": "cranelift_lane",
                    "eventual_intrinsic_owner": "",
                    "intended_later_phase": "",
                    "reason_retained": "",
                    "falsifier": "",
                })
                row["line"] = min(row["line"], line_number)
                row["spellings"].extend(spellings)
                row["source_lines"].append(line_number)

    rows = []
    for (path, line_number, classification), row in sorted(grouped.items()):
        row["spellings"] = sorted(set(row["spellings"]))
        row["source_lines"] = sorted(set(row["source_lines"]))
        stable = re.sub(
            r"[^a-z0-9]+", "_",
            f"{path}_{line_number}_{classification}".lower()).strip("_")
        row["id"] = stable
        if classification == SEMANTIC:
            row["decision"] = f"recognizes concrete spellings while executing {function}"
            row["semantic_role"] = row["layer"]
            row["eventual_intrinsic_owner"] = "compiler_owned_resolved_semantic_or_intrinsic_id"
            row["intended_later_phase"] = "24.5.1"
            row["reason_retained"] = "Patch_24_2_is_report_only_and_preserves_current_dispatch"
        else:
            row["decision"] = f"does not select program meaning; classified as {classification}"
            row["semantic_role"] = "non_semantic_partition"
            row["eventual_intrinsic_owner"] = "not_applicable"
            row["intended_later_phase"] = "none"
            row["reason_retained"] = "explicitly_partitioned_to_prevent_false_semantic_inventory"
        row["falsifier"] = (
            f"{row['id']}_omitted_substituted_duplicated_unclassified_or_line_drifted"
        )
        lines = (ROOT / path).read_text(encoding="utf-8").splitlines()
        row["source_digest"] = digest(
            "\n".join(lines[n - 1] for n in row["source_lines"]).encode()
        )
        rows.append(row)
    return rows


def manifest_summary(rows: list[dict]) -> dict:
    classified = Counter(row["classification"] for row in rows)
    semantic = [row for row in rows if row["classification"] == SEMANTIC]
    partitions = {name: [row for row in rows if row["classification"] == name]
                  for name in PARTITIONS}
    return {
        "source_file_count": len(tracked_sources()),
        "site_count": len(rows),
        "semantic_site_count": len(semantic),
        "semantic_manifest_digest": digest(semantic),
        "classification_counts": {name: classified.get(name, 0)
                                  for name in ALL_CLASSIFICATIONS},
        "partition_manifest_digests": {name: digest(partitions[name]) for name in PARTITIONS},
        "complete_manifest_digest": digest(rows),
        "unknown_site_count": 0,
    }


def validate_row_shape(rows: list[dict]) -> None:
    ids = [row["id"] for row in rows]
    require(len(ids) == len(set(ids)), "duplicate site identity")
    require(rows, "inventory is empty")
    for row in rows:
        require(row["classification"] in ALL_CLASSIFICATIONS,
                f"unclassified site {row['id']}")
        source = ROOT / row["path"]
        require(source.is_file(), f"stale path for {row['id']}")
        lines = source.read_text(encoding="utf-8").splitlines()
        require(row["source_lines"] and row["line"] == min(row["source_lines"]),
                f"stale anchor line for {row['id']}")
        require(all(0 < n <= len(lines) for n in row["source_lines"]),
                f"stale source line for {row['id']}")
        require(row["source_digest"] == digest(
            "\n".join(lines[n - 1] for n in row["source_lines"]).encode()),
            f"stale-line digest for {row['id']}")
        require(row["spellings"], f"site {row['id']} has no spelling")


def load_authority() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    value = registry.get("phase24_semantic_spelling_inventory")
    require(isinstance(value, dict), "registry authority is missing")
    return value


def validate() -> tuple[dict, list[dict], dict]:
    value = load_authority()
    rows = source_sites()
    validate_row_shape(rows)
    summary = manifest_summary(rows)
    require(value.get("contract_version") == "phase24_semantic_spelling_inventory_v1",
            "contract version drifted")
    require(value.get("status") == "patch24_2_complete_report_only",
            "status drifted")
    require(value.get("authority_base_main") ==
            "f36d43e33cb2c0f5b66c801b82d5e27ebcfc0ddc",
            "authority base main drifted")
    require(value.get("review_view") == REVIEW_PATH, "review view drifted")
    # Patch 25.12b adds the FIRST successor this record has needed. Its site
    # identity is path + LINE + classification, so any patch that edits an
    # inventoried file moves the digests even when it adds and removes
    # nothing -- which is exactly what deleting src/runtime.c did: eleven
    # required-file lists lost a line, two cc lines lost an argument, three
    # replay guards gained the two #includes it used to supply. The counts
    # are unchanged and both digests moved.
    #
    # Patch 24.2's record is LANDED, so it is not re-pinned. The successor
    # carries the move and asserts its own arithmetic: same population,
    # different identity. Re-pinning 24.2 would go green while overwriting a
    # closed report.
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    spelling_successor = registry.get(
        "phase2512b_runtime_c_retirement", {}).get(
            "spelling_inventory_transition")
    reference_successor = registry.get("phase26_activation_audit", {}).get(
        "reference_receiver_prerequisite", {}).get(
            "spelling_inventory_successor")
    runtime_successor = registry.get("phase26_activation_audit", {}).get(
        "runtime_formal_signature_prerequisite", {}).get(
            "spelling_inventory_successor")
    str_successor = registry.get("phase26_activation_audit", {}).get(
        "str_direct_call_prerequisite", {}).get(
            "spelling_inventory_successor")
    ffi_successor = registry.get("phase26_activation_audit", {}).get(
        "ffi_position_policy_increment", {}).get(
            "spelling_inventory_successor")
    d2_successor = registry.get("phase26_activation_audit", {}).get(
        "ffi_repr_c_layout_increment", {}).get(
            "spelling_inventory_successor")
    d3_successor = registry.get("phase26_activation_audit", {}).get(
        "ffi_repr_c_write_increment", {}).get(
            "spelling_inventory_successor")
    d4_successor = registry.get("phase26_activation_audit", {}).get(
        "ffi_raw_return_increment", {}).get(
            "spelling_inventory_successor")
    e1_successor = registry.get("phase26_activation_audit", {}).get(
        "raw_cast_provenance_increment", {}).get(
            "spelling_inventory_successor")
    d5_successor = registry.get("phase26_activation_audit", {}).get(
        "ffi_isolated_read_increment", {}).get(
            "spelling_inventory_successor")
    d6_successor = registry.get("phase26_activation_audit", {}).get(
        "ffi_isolated_write_increment", {}).get(
            "spelling_inventory_successor")
    e2_successor = registry.get("phase26_activation_audit", {}).get(
        "reference_return_escape_increment", {}).get(
            "spelling_inventory_successor")
    e3_successor = registry.get("phase26_activation_audit", {}).get(
        "safe_reference_call_increment", {}).get(
            "spelling_inventory_successor")
    e4_successor = registry.get("phase26_activation_audit", {}).get(
        "raw_null_safe_boundary_increment", {}).get(
            "spelling_inventory_successor")
    packed_successor = registry.get("phase26_activation_audit", {}).get(
        "ffi_packed_layout_increment", {}).get(
            "spelling_inventory_successor")
    packed_write_successor = registry.get("phase26_activation_audit", {}).get(
        "ffi_packed_write_increment", {}).get(
            "spelling_inventory_successor")
    packed_isolated_successor = registry.get("phase26_activation_audit", {}).get(
        "ffi_packed_isolated_read_increment", {}).get(
            "spelling_inventory_successor")
    packed_isolated_write_successor = registry.get("phase26_activation_audit", {}).get(
        "ffi_packed_isolated_write_increment", {}).get(
            "spelling_inventory_successor")
    computed_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "computed_zero_raw_null_increment", {}).get(
            "spelling_inventory_successor")
    field_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "field_zero_evidence_increment", {}).get(
            "spelling_inventory_successor")
    nested_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "nested_field_zero_evidence_increment", {}).get(
            "spelling_inventory_successor")
    arithmetic_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "arithmetic_zero_evidence_increment", {}).get(
            "spelling_inventory_successor")
    division_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "division_zero_evidence_increment", {}).get(
            "spelling_inventory_successor")
    match_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "match_zero_evidence_increment", {}).get(
            "spelling_inventory_successor")
    take_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "take_zero_evidence_increment", {}).get(
            "spelling_inventory_successor")
    take_struct_successor = registry.get("phase26_activation_audit", {}).get(
        "take_struct_alias_evidence_increment", {}).get(
            "spelling_inventory_successor")
    cast_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "cast_narrowing_zero_evidence_increment", {}).get(
            "spelling_inventory_successor")
    bool_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "bool_literal_zero_evidence_increment", {}).get(
            "spelling_inventory_successor")
    logical_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "logical_zero_evidence_increment", {}).get(
            "spelling_inventory_successor")
    equality_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "equality_zero_evidence_increment", {}).get(
            "spelling_inventory_successor")
    relational_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "relational_zero_evidence_increment", {}).get(
            "spelling_inventory_successor")
    explicit_brand_successor = registry.get("phase26_activation_audit", {}).get(
        "explicit_brand_prerequisite", {}).get(
            "spelling_inventory_successor")
    empty_raw_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "empty_raw_zero_evidence_increment", {}).get(
            "spelling_inventory_successor")
    call_return_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "call_return_zero_evidence_increment", {}).get(
        "spelling_inventory_successor")
    call_local_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "call_local_zero_evidence_increment", {}).get(
        "spelling_inventory_successor")
    call_alias_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "call_alias_zero_evidence_increment", {}).get(
        "spelling_inventory_successor")
    call_chain_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "call_chain_zero_evidence_increment", {}).get(
        "spelling_inventory_successor")
    call_take_alias_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "call_take_alias_zero_evidence_increment", {}).get(
        "spelling_inventory_successor")
    call_direct_take_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "call_direct_take_zero_evidence_increment", {}).get(
        "spelling_inventory_successor")
    call_direct_move_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "call_direct_move_zero_evidence_increment", {}).get(
        "spelling_inventory_successor")
    call_move_wrapper_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "call_move_wrapper_zero_evidence_increment", {}).get(
        "spelling_inventory_successor")
    call_take_wrapper_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "call_take_wrapper_zero_evidence_increment", {}).get(
        "spelling_inventory_successor")
    call_two_wrapper_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "call_two_wrapper_zero_evidence_increment", {}).get(
        "spelling_inventory_successor")
    call_wrapper_chain_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "call_wrapper_chain_zero_evidence_increment", {}).get(
        "spelling_inventory_successor")
    call_as_cast_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "call_as_cast_zero_evidence_increment", {}).get(
        "spelling_inventory_successor")
    call_as_cast_chain_zero_successor = registry.get("phase26_activation_audit", {}).get(
        "call_as_cast_chain_zero_evidence_increment", {}).get(
        "spelling_inventory_successor")
    expected_summary = (summary if spelling_successor is None
                        else spelling_successor["previous_inventory_summary"])
    require(value.get("inventory_summary") == expected_summary,
            "live concrete-spelling inventory is not the exact registered manifest")
    if spelling_successor is not None:
        require(spelling_successor.get("contract_version") ==
                "phase2512b_spelling_inventory_transition_v1" and
                spelling_successor.get("current_inventory_summary") ==
                (summary if reference_successor is None else
                 reference_successor.get("predecessor_inventory_summary")),
                "Patch 25.12b spelling-inventory successor does not end at "
                "the live manifest")
        was = spelling_successor["previous_inventory_summary"]
        now = spelling_successor["current_inventory_summary"]
        require(was.get("site_count") == now.get("site_count") and
                was.get("complete_manifest_digest") !=
                now.get("complete_manifest_digest"),
                "Patch 25.12b must move spelling-inventory IDENTITY without "
                "moving the population: it edits inventoried lines, it does "
                "not add or remove spelling sites")
    if reference_successor is not None:
        require(spelling_successor is not None and
                reference_successor.get("contract_version") ==
                "phase26_reference_receiver_spelling_inventory_successor_v1" and
                reference_successor.get("predecessor_complete_manifest_digest") ==
                spelling_successor["current_inventory_summary"][
                    "complete_manifest_digest"] and
                reference_successor.get("changed_source_paths") == [
                    "compiler/experiments/cranelift/src/full_program.rs",
                    "compiler/mir_native_backend_full_program_source.gst",
                    "compiler/phase16_reference_receiver_source.gst",
                    "compiler/phase16_reference_return_deferred_source.gst",
                    "compiler/phase16_string_clone_source.gst",
                    "compiler/phase16_non_string_clone_deferred_source.gst",
                ] and
                reference_successor.get(
                    "partial_extra_or_substituted_inventory") == "rejected" and
                reference_successor.get("current_inventory_summary") ==
                (summary if runtime_successor is None else
                 runtime_successor.get("previous_inventory_summary")),
                "Phase 26 reference receiver spelling inventory successor "
                "does not end at the live manifest")
        was = spelling_successor["current_inventory_summary"]
        now = reference_successor["current_inventory_summary"]
        require(now["site_count"] == was["site_count"] + 3 and
                now["semantic_site_count"] == was["semantic_site_count"] + 3 and
                now["classification_counts"][SEMANTIC] ==
                was["classification_counts"][SEMANTIC] + 3 and
                all(now["classification_counts"][kind] ==
                    was["classification_counts"][kind]
                    for kind in PARTITIONS) and
                now["unknown_site_count"] == was["unknown_site_count"] == 0 and
                now["source_file_count"] == was["source_file_count"] + 4 and
                {key for key in was["partition_manifest_digests"]
                 if was["partition_manifest_digests"][key] !=
                 now["partition_manifest_digests"][key]} == {"diagnostic"},
                "Phase 26 reference receiver spelling inventory changed "
                "unregistered site populations or partitions")
    if runtime_successor is not None:
        require(reference_successor is not None and
                runtime_successor.get("contract_version") ==
                "phase26_runtime_formal_signature_spelling_successor_v1" and
                runtime_successor.get("changed_source_paths") == [
                    "compiler/experiments/cranelift/src/full_program.rs",
                    "compiler/mir_native_backend_full_program_source.gst",
                    "compiler/phase26_runtime_formal_signature_source.gst",
                    "compiler/phase26_runtime_formal_signature_wrong_type_source.gst",
                ] and
                runtime_successor.get("previous_inventory_summary") ==
                reference_successor["current_inventory_summary"] and
                runtime_successor.get("current_inventory_summary") ==
                (summary if str_successor is None else
                 str_successor.get("previous_inventory_summary")) and
                runtime_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected",
                "runtime formal signature spelling successor drifted")
        was = runtime_successor["previous_inventory_summary"]
        now = runtime_successor["current_inventory_summary"]
        require(now["site_count"] == was["site_count"] and
                now["semantic_site_count"] == was["semantic_site_count"] and
                now["source_file_count"] == was["source_file_count"] + 2 and
                now["unknown_site_count"] == 0 and
                now["classification_counts"] == was["classification_counts"],
                "runtime formal signature changed the spelling population")
    if str_successor is not None:
        require(runtime_successor is not None and
                str_successor.get("contract_version") ==
                "phase26_str_direct_call_spelling_successor_v1" and
                str_successor.get("changed_source_paths") == [
                    "compiler/mir_native_backend_full_program_source.gst",
                    "compiler/mir_native_backend_parameter_argument_source.gst",
                    "compiler/phase26_runtime_slice_return_deferred_source.gst",
                    "compiler/phase26_str_direct_call_source.gst",
                    "compiler/phase26_str_extern_deferred_source.gst",
                ] and
                str_successor.get("previous_inventory_summary") ==
                runtime_successor["current_inventory_summary"] and
                str_successor.get("current_inventory_summary") ==
                (summary if ffi_successor is None else
                 ffi_successor.get("previous_inventory_summary")) and
                str_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected",
                "Str direct-call spelling successor drifted")
        was = str_successor["previous_inventory_summary"]
        now = str_successor["current_inventory_summary"]
        require(now["site_count"] == was["site_count"] and
                now["semantic_site_count"] == was["semantic_site_count"] and
                now["source_file_count"] == was["source_file_count"] + 3 and
                now["unknown_site_count"] == 0 and
                now["classification_counts"] == was["classification_counts"] and
                now["complete_manifest_digest"] ==
                was["complete_manifest_digest"],
                "Str direct calls changed an unregistered spelling site")
    if ffi_successor is not None:
        previous = str_successor["current_inventory_summary"]
        ffi_now = ffi_successor["current_inventory_summary"]
        require(ffi_successor.get("contract_version") ==
                "phase26_1d1_spelling_inventory_successor_v1" and
                ffi_successor.get("previous_inventory_summary") == previous and
                ffi_successor.get("current_inventory_summary") ==
                (summary if d2_successor is None else
                 d2_successor.get("previous_inventory_summary")) and
                ffi_successor.get("changed_source_paths") == sorted([
                    "compiler/ast.gst", "compiler/parser.gst",
                    "compiler/typechecker.gst",
                    "compiler/phase26_ffi_aggregate_invalid.gst",
                    "compiler/phase26_ffi_borrow_read_source.gst",
                    "compiler/phase26_ffi_callback_invalid.gst",
                    "compiler/phase26_ffi_native_error_invalid.gst",
                    "compiler/phase26_ffi_nonextern_attribute_invalid.gst",
                    "compiler/phase26_ffi_position_policy_test_entry.gst",
                    "compiler/phase26_ffi_retain_invalid.gst",
                    "compiler/phase26_ffi_returned_pointer_invalid.gst",
                    "compiler/phase26_ffi_transfer_invalid.gst",
                    "compiler/phase26_ffi_unannotated_pointer_invalid.gst",
                    "compiler/phase26_ffi_unsafe_call_invalid.gst",
                    "compiler/phase26_ffi_write_nonraw_invalid.gst",
                ]) and
                ffi_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                ffi_now["source_file_count"] ==
                previous["source_file_count"] + 12 and
                ffi_now["site_count"] == previous["site_count"] and
                ffi_now["semantic_site_count"] ==
                previous["semantic_site_count"] and
                ffi_now["classification_counts"] ==
                previous["classification_counts"] and
                ffi_now["unknown_site_count"] == 0,
                "Phase 26.1D1 spelling inventory changed beyond its "
                "registered source and identity successor")
    if d2_successor is not None:
        previous = ffi_successor["current_inventory_summary"]
        d2_now = d2_successor["current_inventory_summary"]
        require(d2_successor.get("contract_version") ==
                "phase26_1d2_spelling_inventory_successor_v1" and
                d2_successor.get("previous_inventory_summary") == previous and
                d2_successor.get("current_inventory_summary") ==
                (summary if d3_successor is None else
                 d3_successor.get("previous_inventory_summary")) and
                d2_successor.get("changed_source_paths") == sorted([
                    "compiler/mir_native_backend_full_program_source.gst",
                    "compiler/mir_native_backend_generic_source.gst",
                    "compiler/mir_native_backend_module_import_source.gst",
                    "compiler/phase26_ffi_repr_c_probe_source.gst",
                    "compiler/phase26_ffi_repr_c_missing_source.gst",
                    "compiler/phase26_ffi_repr_c_order_source.gst",
                    "compiler/phase26_ffi_repr_c_packed_source.gst",
                    "compiler/phase26_ffi_repr_c_nested_source.gst",
                    "compiler/phase26_ffi_repr_c_unknown_host_source.gst",
                    "compiler/phase26_ffi_repr_c_enum_source.gst",
                ]) and
                d2_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                d2_now["source_file_count"] == previous["source_file_count"] + 7 and
                d2_now["site_count"] == previous["site_count"] and
                d2_now["semantic_site_count"] == previous["semantic_site_count"] and
                d2_now["classification_counts"] == previous["classification_counts"] and
                d2_now["unknown_site_count"] == 0 and
                {key for key in previous["partition_manifest_digests"]
                 if previous["partition_manifest_digests"][key] !=
                 d2_now["partition_manifest_digests"][key]} ==
                {"mangling_or_generated_name"},
                "Phase 26.1D2 spelling inventory changed beyond its "
                "registered source and identity successor")
    if d3_successor is not None:
        previous = d2_successor["current_inventory_summary"]
        require(d3_successor.get("contract_version") ==
                "phase26_1d3_spelling_inventory_successor_v1" and
                d3_successor.get("previous_inventory_summary") == previous and
                d3_successor.get("current_inventory_summary") ==
                (summary if d4_successor is None else
                 d4_successor.get("previous_inventory_summary")) and
                d3_successor.get("changed_source_paths") == sorted([
                    "compiler/mir_native_backend_full_program_source.gst",
                    "compiler/mir_native_backend_module_import_source.gst",
                    "compiler/mir_native_backend_parameter_argument_source.gst",
                    *[f"compiler/phase26_ffi_repr_c_write_{name}_source.gst"
                      for name in ("missing", "order", "packed", "nested",
                                   "unknown_host", "enum")],
                    "compiler/phase26_ffi_repr_c_write_source.gst",
                ]) and
                d3_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                d3_successor["current_inventory_summary"]["source_file_count"] ==
                previous["source_file_count"] + 7 and
                d3_successor["current_inventory_summary"]["site_count"] == previous["site_count"] and
                d3_successor["current_inventory_summary"]["semantic_site_count"] ==
                previous["semantic_site_count"] and
                d3_successor["current_inventory_summary"]["classification_counts"] ==
                previous["classification_counts"] and
                d3_successor["current_inventory_summary"]["unknown_site_count"] == 0 and
                {key for key in previous["partition_manifest_digests"]
                 if previous["partition_manifest_digests"][key] !=
                 d3_successor["current_inventory_summary"]["partition_manifest_digests"][key]} ==
                {"mangling_or_generated_name"},
                "Phase 26.1D3 spelling inventory changed beyond its "
                "registered source and identity successor")
    if d4_successor is not None:
        previous = d3_successor["current_inventory_summary"]
        d4_now = d4_successor["current_inventory_summary"]
        changed_source_paths = sorted([
            "compiler/ast.gst",
            "compiler/experiments/cranelift/src/full_program.rs",
            "compiler/experiments/cranelift/src/main.rs",
            "compiler/mir_native_backend_full_program_source.gst",
            "compiler/mir_native_backend_module_import_source.gst",
            "compiler/mir_native_backend_parameter_argument_source.gst",
            "compiler/parser.gst",
            "compiler/phase26_ffi_position_policy_test_entry.gst",
            "compiler/typechecker.gst",
            "compiler/phase26_ffi_raw_return_source.gst",
            "compiler/phase26_ffi_raw_return_policy_test_entry.gst",
            *[f"compiler/phase26_ffi_raw_return_{name}_source.gst"
              for name in ("missing", "unknown_host", "wrong_inner",
                           "reference", "str", "slice", "transfer",
                           "scalar_policy", "nonextern", "unsafe_call",
                           "unsafe_deref")],
        ])
        require(d4_successor.get("contract_version") ==
                "phase26_1d4_spelling_inventory_successor_v1" and
                d4_successor.get("previous_inventory_summary") == previous and
                d4_successor.get("current_inventory_summary") ==
                (summary if e1_successor is None else
                 e1_successor.get("previous_inventory_summary")) and
                d4_successor.get("changed_source_paths") == changed_source_paths and
                d4_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                d4_now["source_file_count"] == previous["source_file_count"] + 13 and
                d4_now["site_count"] == previous["site_count"] and
                d4_now["semantic_site_count"] == previous["semantic_site_count"] and
                d4_now["classification_counts"] == previous["classification_counts"] and
                d4_now["unknown_site_count"] == 0 and
                {key for key in previous["partition_manifest_digests"]
                 if previous["partition_manifest_digests"][key] !=
                 d4_now["partition_manifest_digests"][key]} ==
                {"diagnostic", "mangling_or_generated_name", "serialization"},
                "Phase 26.1D4 spelling inventory changed beyond its "
                "registered source and identity successor")
    if e1_successor is not None:
        previous = d4_successor["current_inventory_summary"]
        e1_now = e1_successor["current_inventory_summary"]
        require(e1_successor.get("contract_version") ==
                "phase26_1e1_spelling_inventory_successor_v1" and
                e1_successor.get("previous_inventory_summary") == previous and
                e1_successor.get("current_inventory_summary") ==
                (summary if d5_successor is None else
                 d5_successor.get("previous_inventory_summary")) and
                e1_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/mir_native_backend_full_program_source.gst",
                    "compiler/phase26_raw_cast_provenance_test_entry.gst",
                    "compiler/phase26_raw_cast_safe_brand_rejected_source.gst",
                    "compiler/phase26_raw_cast_unsafe_source.gst",
                ]) and
                e1_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                e1_now["source_file_count"] == previous["source_file_count"] + 3 and
                e1_now["site_count"] == previous["site_count"] and
                e1_now["semantic_site_count"] == previous["semantic_site_count"] and
                e1_now["classification_counts"] == previous["classification_counts"] and
                e1_now["unknown_site_count"] == 0 and
                {key for key in previous["partition_manifest_digests"]
                 if previous["partition_manifest_digests"][key] !=
                 e1_now["partition_manifest_digests"][key]} ==
                {"mangling_or_generated_name"},
                "Phase 26.1E1 spelling inventory changed beyond registered sources")
    if d5_successor is not None:
        previous = e1_successor["current_inventory_summary"]
        require(d5_successor.get("contract_version") ==
                "phase26_1d5_spelling_inventory_successor_v1" and
                d5_successor.get("previous_inventory_summary") == previous and
                d5_successor.get("current_inventory_summary") ==
                (summary if d6_successor is None else
                 d6_successor.get("previous_inventory_summary")) and
                d5_successor.get("changed_source_paths") == sorted([
                    "compiler/parser.gst", "compiler/typechecker.gst",
                    "compiler/mir_native_backend_module_import_source.gst",
                    "compiler/mir_native_backend_full_program_source.gst",
                    "compiler/experiments/cranelift/src/full_program.rs",
                    *[f"compiler/phase26_ffi_isolated_{name}_source.gst"
                      for name in ("read", "missing_repr", "order", "packed",
                                   "nested", "enum", "unknown_host", "write_host",
                                   "nonreference", "nonaggregate")],
                ]) and
                d5_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and summary["unknown_site_count"] == 0,
                "Phase 26.1D5 spelling inventory drifted")
    if d6_successor is not None:
        require(d5_successor is not None and
                d6_successor.get("contract_version") ==
                "phase26_1d6_spelling_inventory_successor_v1" and
                d6_successor.get("previous_inventory_summary") ==
                d5_successor["current_inventory_summary"] and
                d6_successor.get("current_inventory_summary") ==
                (summary if e2_successor is None else
                 e2_successor.get("previous_inventory_summary")) and
                d6_successor.get("changed_source_paths") == sorted([
                    "compiler/parser.gst", "compiler/typechecker.gst",
                    "compiler/mir_native_backend_parameter_argument_source.gst",
                    "compiler/mir_native_backend_module_import_source.gst",
                    "compiler/mir_native_backend_full_program_source.gst",
                    "compiler/experiments/cranelift/src/full_program.rs",
                    *[f"compiler/phase26_ffi_isolated_write_{name}_source.gst"
                      for name in ("missing", "order", "packed", "nested",
                                   "enum", "unknown_host", "nonraw",
                                   "nonaggregate")],
                    "compiler/phase26_ffi_isolated_write_source.gst",
                ]) and
                d6_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and summary["unknown_site_count"] == 0,
                "Phase 26.1D6 spelling inventory drifted")
    if e2_successor is not None:
        previous_e2 = d6_successor["current_inventory_summary"]
        now_e2 = e2_successor.get("current_inventory_summary", {})
        require(d6_successor is not None and
                e2_successor.get("contract_version") ==
                "phase26_1e2_spelling_inventory_successor_v1" and
                e2_successor.get("previous_inventory_summary") ==
                d6_successor["current_inventory_summary"] and
                e2_successor.get("current_inventory_summary") ==
                (summary if e3_successor is None else
                 e3_successor.get("previous_inventory_summary")) and
                e2_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_reference_return_escape_test_entry.gst",
                    "compiler/phase26_reference_return_escape_source.gst",
                    "compiler/phase26_reference_return_safe_source.gst",
                ]) and
                e2_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_e2["source_file_count"] == previous_e2["source_file_count"] + 3 and
                now_e2["site_count"] == previous_e2["site_count"] and
                now_e2["semantic_site_count"] == previous_e2["semantic_site_count"] and
                now_e2["classification_counts"] == previous_e2["classification_counts"] and
                {key for key in previous_e2["partition_manifest_digests"]
                 if previous_e2["partition_manifest_digests"][key] !=
                 now_e2["partition_manifest_digests"][key]} ==
                {"diagnostic", "mangling_or_generated_name"} and
                now_e2["unknown_site_count"] == 0,
                "Phase 26.1E2 spelling inventory drifted")
    if e3_successor is not None:
        previous_e3 = e2_successor["current_inventory_summary"]
        now_e3 = e3_successor.get("current_inventory_summary", {})
        require(e2_successor is not None and
                e3_successor.get("contract_version") ==
                "phase26_1e3_spelling_inventory_successor_v1" and
                e3_successor.get("previous_inventory_summary") == previous_e3 and
                now_e3 == (summary if e4_successor is None else
                           e4_successor.get("previous_inventory_summary")) and
                e3_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_safe_reference_call_source.gst",
                    "compiler/phase26_safe_reference_call_escape_source.gst",
                    "compiler/phase26_safe_reference_call_mismatch_source.gst",
                    "compiler/phase26_safe_reference_call_test_entry.gst",
                ]) and
                e3_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_e3["source_file_count"] == previous_e3["source_file_count"] + 4 and
                now_e3["site_count"] == previous_e3["site_count"] and
                now_e3["semantic_site_count"] == previous_e3["semantic_site_count"] and
                now_e3["classification_counts"] == previous_e3["classification_counts"] and
                now_e3["unknown_site_count"] == 0,
                "Phase 26.1E3 spelling inventory drifted")
    if e4_successor is not None:
        previous_e4 = e3_successor["current_inventory_summary"]
        now_e4 = e4_successor.get("current_inventory_summary", {})
        require(e3_successor is not None and
                e4_successor.get("contract_version") ==
                "phase26_1e4_spelling_inventory_successor_v1" and
                e4_successor.get("previous_inventory_summary") == previous_e4 and
                now_e4 == (summary if packed_successor is None else
                           packed_successor.get("previous_inventory_summary")) and
                e4_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_raw_null_safe_boundary_test_entry.gst",
                    "compiler/phase26_raw_null_safe_return_source.gst",
                    "compiler/phase26_raw_null_safe_call_source.gst",
                ]) and
                e4_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_e4["source_file_count"] == previous_e4["source_file_count"] + 3 and
                now_e4["site_count"] == previous_e4["site_count"] and
                now_e4["semantic_site_count"] == previous_e4["semantic_site_count"] and
                now_e4["classification_counts"] == previous_e4["classification_counts"] and
                now_e4["unknown_site_count"] == 0,
                "Phase 26.1E4 spelling inventory drifted")
    if packed_successor is not None:
        previous_packed = e4_successor["current_inventory_summary"]
        now_packed = packed_successor.get("current_inventory_summary", {})
        require(e4_successor is not None and
                packed_successor.get("contract_version") ==
                "phase26_1d_packed_spelling_inventory_successor_v1" and
                packed_successor.get("previous_inventory_summary") == previous_packed and
                now_packed == (summary if packed_write_successor is None else
                               packed_write_successor.get("previous_inventory_summary")) and
                packed_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    *[f"compiler/phase26_ffi_packed_{name}_source.gst" for name in (
                        "probe", "missing", "order", "nested", "enum",
                        "unknown_host", "by_value", "safe_field", "field_reference")],
                ]) and
                packed_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_packed["source_file_count"] ==
                previous_packed["source_file_count"] + 9 and
                now_packed["unknown_site_count"] == 0,
                "Phase 26 packed spelling inventory drifted")
    if packed_write_successor is not None:
        previous_write = packed_successor["current_inventory_summary"]
        now_write = packed_write_successor.get("current_inventory_summary", {})
        require(packed_successor is not None and
                packed_write_successor.get("contract_version") ==
                "phase26_1d_packed_write_spelling_inventory_successor_v1" and
                packed_write_successor.get("previous_inventory_summary") == previous_write and
                now_write == (summary if packed_isolated_successor is None else
                              packed_isolated_successor.get("previous_inventory_summary")) and
                packed_write_successor.get("changed_source_paths") == sorted([
                    "compiler/phase26_ffi_packed_write_source.gst",
                    "compiler/phase26_ffi_packed_write_unknown_host_source.gst",
                    "compiler/phase26_ffi_packed_write_wrong_policy_source.gst",
                ]) and
                packed_write_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_write["source_file_count"] ==
                previous_write["source_file_count"] + 3 and
                now_write["unknown_site_count"] == 0,
                "Phase 26 packed write spelling inventory drifted")
    if packed_isolated_successor is not None:
        previous_isolated = packed_write_successor["current_inventory_summary"]
        now_isolated = packed_isolated_successor.get("current_inventory_summary", {})
        fixture_paths = sorted([
            "compiler/phase26_ffi_packed_isolated_read_source.gst",
            *[f"compiler/phase26_ffi_packed_isolated_{name}_source.gst" for name in
              ("wrong_host", "wrong_policy", "missing_repr", "nested")],
        ])
        require(packed_write_successor is not None and
                packed_isolated_successor.get("contract_version") ==
                "phase26_1d_packed_isolated_read_spelling_inventory_successor_v1" and
                packed_isolated_successor.get("previous_inventory_summary") ==
                previous_isolated and
                now_isolated == (summary if packed_isolated_write_successor is None else
                                 packed_isolated_write_successor.get("previous_inventory_summary")) and
                packed_isolated_successor.get("changed_source_paths") == fixture_paths and
                packed_isolated_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_isolated["source_file_count"] ==
                previous_isolated["source_file_count"] + len(fixture_paths) and
                now_isolated["unknown_site_count"] == 0,
                "Phase 26 packed isolated read spelling inventory drifted")
    if packed_isolated_write_successor is not None:
        previous_write_isolated = packed_isolated_successor["current_inventory_summary"]
        now_write_isolated = packed_isolated_write_successor.get("current_inventory_summary", {})
        fixture_paths = sorted([
            "compiler/phase26_ffi_packed_isolated_wrong_policy_source.gst",
            "compiler/phase26_ffi_packed_write_wrong_policy_source.gst",
            "compiler/phase26_ffi_packed_isolated_write_source.gst",
            *[f"compiler/phase26_ffi_packed_isolated_write_{name}_source.gst" for name in
              ("wrong_host", "wrong_policy", "missing_repr", "nested")],
        ])
        require(packed_isolated_successor is not None and
                packed_isolated_write_successor.get("contract_version") ==
                "phase26_1d_packed_isolated_write_spelling_inventory_successor_v1" and
                packed_isolated_write_successor.get("previous_inventory_summary") ==
                previous_write_isolated and
                now_write_isolated == (summary if computed_zero_successor is None else
                                       computed_zero_successor.get("previous_inventory_summary")) and
                packed_isolated_write_successor.get("changed_source_paths") == fixture_paths and
                packed_isolated_write_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_write_isolated["source_file_count"] ==
                previous_write_isolated["source_file_count"] + 5 and
                now_write_isolated["unknown_site_count"] == 0,
                "Phase 26 packed isolated write spelling inventory drifted")
    if computed_zero_successor is not None:
        previous_computed = packed_isolated_write_successor["current_inventory_summary"]
        now_computed = computed_zero_successor.get("current_inventory_summary", {})
        fixture_paths = sorted([
            "compiler/typechecker.gst",
            "compiler/phase26_computed_zero_test_entry.gst",
            *[f"compiler/phase26_computed_zero_safe_{name}_source.gst" for name in
              ("sum_return", "sum_call", "local_call", "branch_call")],
        ])
        require(packed_isolated_write_successor is not None and
                computed_zero_successor.get("contract_version") ==
                "phase26_1e_computed_zero_spelling_inventory_successor_v1" and
                computed_zero_successor.get("previous_inventory_summary") ==
                previous_computed and
                now_computed == (summary if field_zero_successor is None else
                                 field_zero_successor.get("previous_inventory_summary")) and
                computed_zero_successor.get("changed_source_paths") == fixture_paths and
                computed_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_computed["source_file_count"] ==
                previous_computed["source_file_count"] + 5 and
                now_computed["site_count"] == previous_computed["site_count"] and
                now_computed["unknown_site_count"] == 0,
                "Phase 26 computed-zero spelling inventory drifted")
    if field_zero_successor is not None:
        previous_field_zero = computed_zero_successor["current_inventory_summary"]
        now_field_zero = field_zero_successor.get("current_inventory_summary", {})
        fixture_paths = sorted([
            "compiler/typechecker.gst",
            "compiler/phase26_field_zero_test_entry.gst",
            *[f"compiler/phase26_field_zero_{name}_source.gst" for name in
              ("safe_call", "if_join", "while_join", "whole_reassign", "alias", "safe_return")],
        ])
        require(computed_zero_successor is not None and
                field_zero_successor.get("contract_version") ==
                "phase26_1e_field_zero_spelling_inventory_successor_v1" and
                field_zero_successor.get("previous_inventory_summary") ==
                previous_field_zero and
                now_field_zero == (summary if nested_zero_successor is None else
                                   nested_zero_successor.get("previous_inventory_summary")) and
                field_zero_successor.get("changed_source_paths") == fixture_paths and
                field_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_field_zero["source_file_count"] ==
                previous_field_zero["source_file_count"] + 7 and
                now_field_zero["site_count"] == previous_field_zero["site_count"] and
                now_field_zero["unknown_site_count"] == 0,
                "Phase 26 field-zero spelling inventory drifted")
    if nested_zero_successor is not None:
        previous_nested = field_zero_successor["current_inventory_summary"]
        now_nested = nested_zero_successor.get("current_inventory_summary", {})
        fixture_paths = sorted([
            "compiler/typechecker.gst",
            "compiler/phase26_nested_field_zero_test_entry.gst",
            *[f"compiler/phase26_nested_field_zero_{name}_source.gst" for name in
              ("safe_call", "if_join", "while_join", "subobject", "safe_return", "nonzero")],
        ])
        require(field_zero_successor is not None and
                nested_zero_successor.get("contract_version") ==
                "phase26_1e_nested_field_zero_spelling_inventory_successor_v1" and
                nested_zero_successor.get("previous_inventory_summary") ==
                previous_nested and
                now_nested == (summary if arithmetic_zero_successor is None else
                               arithmetic_zero_successor.get("previous_inventory_summary")) and
                nested_zero_successor.get("changed_source_paths") == fixture_paths and
                nested_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_nested["source_file_count"] ==
                previous_nested["source_file_count"] + 7 and
                now_nested["site_count"] == previous_nested["site_count"] and
                now_nested["unknown_site_count"] == 0,
                "Phase 26 nested field-zero spelling inventory drifted")
    if arithmetic_zero_successor is not None:
        previous_arithmetic = nested_zero_successor["current_inventory_summary"]
        now_arithmetic = arithmetic_zero_successor.get("current_inventory_summary", {})
        fixture_paths = sorted([
            "compiler/typechecker.gst",
            "compiler/phase26_arithmetic_zero_test_entry.gst",
            *[f"compiler/phase26_arithmetic_zero_safe_{name}_source.gst" for name in
              ("sub_call", "mul_call", "sub_return", "mul_return")],
        ])
        require(nested_zero_successor is not None and
                arithmetic_zero_successor.get("contract_version") ==
                "phase26_1e_arithmetic_zero_spelling_inventory_successor_v1" and
                arithmetic_zero_successor.get("previous_inventory_summary") ==
                previous_arithmetic and
                now_arithmetic == (summary if division_zero_successor is None else
                                   division_zero_successor.get("previous_inventory_summary")) and
                arithmetic_zero_successor.get("changed_source_paths") == fixture_paths and
                arithmetic_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_arithmetic["source_file_count"] ==
                previous_arithmetic["source_file_count"] + 5 and
                now_arithmetic["site_count"] == previous_arithmetic["site_count"] and
                now_arithmetic["unknown_site_count"] == 0,
                "Phase 26 arithmetic zero spelling inventory drifted")
    if division_zero_successor is not None:
        previous_division = arithmetic_zero_successor["current_inventory_summary"]
        now_division = division_zero_successor.get("current_inventory_summary", {})
        fixture_paths = sorted([
            "compiler/typechecker.gst",
            "compiler/phase26_division_zero_test_entry.gst",
            "compiler/phase26_division_zero_safe_call_source.gst",
            "compiler/phase26_division_zero_safe_return_source.gst",
        ])
        require(arithmetic_zero_successor is not None and
                division_zero_successor.get("contract_version") ==
                "phase26_1e_division_zero_spelling_inventory_successor_v1" and
                division_zero_successor.get("previous_inventory_summary") ==
                previous_division and
                now_division == (summary if match_zero_successor is None else
                                 match_zero_successor.get("previous_inventory_summary")) and
                division_zero_successor.get("changed_source_paths") == fixture_paths and
                division_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_division["source_file_count"] ==
                previous_division["source_file_count"] + 3 and
                now_division["site_count"] == previous_division["site_count"] and
                now_division["unknown_site_count"] == 0,
                "Phase 26 division zero spelling inventory drifted")
    if match_zero_successor is not None:
        previous_match = division_zero_successor["current_inventory_summary"]
        now_match = match_zero_successor.get("current_inventory_summary", {})
        fixture_paths = sorted([
            "compiler/typechecker.gst",
            "compiler/phase26_match_zero_test_entry.gst",
            "compiler/phase26_match_zero_safe_call_source.gst",
            "compiler/phase26_match_zero_safe_return_source.gst",
        ])
        require(division_zero_successor is not None and
                match_zero_successor.get("contract_version") ==
                "phase26_1e_match_zero_spelling_inventory_successor_v1" and
                match_zero_successor.get("previous_inventory_summary") ==
                previous_match and
                now_match == (summary if take_zero_successor is None else
                              take_zero_successor.get("previous_inventory_summary")) and
                match_zero_successor.get("changed_source_paths") == fixture_paths and
                match_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_match["source_file_count"] ==
                previous_match["source_file_count"] + 3 and
                now_match["site_count"] == previous_match["site_count"] and
                now_match["unknown_site_count"] == 0,
                "Phase 26 match zero spelling inventory drifted")
    if take_zero_successor is not None:
        previous_take = match_zero_successor["current_inventory_summary"]
        now_take = take_zero_successor.get("current_inventory_summary", {})
        fixture_paths = sorted([
            "compiler/typechecker.gst",
            "compiler/phase26_take_zero_test_entry.gst",
            "compiler/phase26_take_zero_safe_call_source.gst",
            "compiler/phase26_take_zero_safe_readback_source.gst",
        ])
        require(match_zero_successor is not None and
                take_zero_successor.get("contract_version") ==
                "phase26_1e_take_zero_spelling_inventory_successor_v1" and
                take_zero_successor.get("previous_inventory_summary") ==
                previous_take and
                now_take == (summary if take_struct_successor is None else
                             take_struct_successor.get("previous_inventory_summary")) and
                take_zero_successor.get("changed_source_paths") == fixture_paths and
                take_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_take["source_file_count"] ==
                previous_take["source_file_count"] + 3 and
                now_take["site_count"] == previous_take["site_count"] and
                now_take["unknown_site_count"] == 0,
                "Phase 26 take zero spelling inventory drifted")
    if take_struct_successor is not None:
        previous_struct = take_zero_successor["current_inventory_summary"]
        now_struct = take_struct_successor.get("current_inventory_summary", {})
        fixture_paths = sorted([
            "compiler/typechecker.gst",
            "compiler/phase26_take_struct_alias_test_entry.gst",
            "compiler/phase26_take_struct_alias_decl_source.gst",
            "compiler/phase26_take_struct_alias_assign_source.gst",
            "compiler/phase26_take_struct_alias_nonzero_source.gst",
        ])
        require(take_zero_successor is not None and
                take_struct_successor.get("contract_version") ==
                "phase26_1e_take_struct_alias_spelling_inventory_successor_v1" and
                take_struct_successor.get("previous_inventory_summary") ==
                previous_struct and
                now_struct == (summary if cast_zero_successor is None else
                               cast_zero_successor.get("previous_inventory_summary")) and
                take_struct_successor.get("changed_source_paths") == fixture_paths and
                take_struct_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_struct["source_file_count"] ==
                previous_struct["source_file_count"] + 4 and
                now_struct["site_count"] == previous_struct["site_count"] and
                now_struct["unknown_site_count"] == 0,
                "Phase 26 local Struct Take-alias spelling inventory drifted")
    if cast_zero_successor is not None:
        previous_cast = take_struct_successor["current_inventory_summary"]
        now_cast = cast_zero_successor.get("current_inventory_summary", {})
        require(take_struct_successor is not None and
                cast_zero_successor.get("contract_version") ==
                "phase26_1e_cast_narrowing_zero_spelling_inventory_successor_v1" and
                cast_zero_successor.get("previous_inventory_summary") ==
                previous_cast and now_cast ==
                (summary if bool_zero_successor is None else
                 bool_zero_successor.get("previous_inventory_summary")) and
                cast_zero_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_cast_narrowing_zero_test_entry.gst",
                    *[f"compiler/phase26_cast_narrowing_{name}_source.gst"
                      for name in ("safe_call", "safe_return", "nonzero",
                                   "unknown", "unsafe")],
                ]) and
                cast_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_cast["source_file_count"] ==
                previous_cast["source_file_count"] + 6 and
                now_cast["site_count"] == previous_cast["site_count"] and
                now_cast["unknown_site_count"] == 0,
                "Phase 26 cast narrowing spelling inventory drifted")
    if bool_zero_successor is not None:
        previous_bool = cast_zero_successor["current_inventory_summary"]
        now_bool = bool_zero_successor.get("current_inventory_summary", {})
        require(cast_zero_successor is not None and
                bool_zero_successor.get("contract_version") ==
                "phase26_1e_bool_literal_zero_spelling_inventory_successor_v1" and
                bool_zero_successor.get("previous_inventory_summary") ==
                previous_bool and now_bool == (summary if logical_zero_successor is None
                                             else logical_zero_successor.get("previous_inventory_summary")) and
                bool_zero_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_bool_literal_zero_test_entry.gst",
                    *[f"compiler/phase26_bool_literal_{name}_source.gst"
                      for name in ("safe_call", "safe_return", "nonzero",
                                   "unknown", "unsafe")],
                ]) and
                bool_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_bool["source_file_count"] ==
                previous_bool["source_file_count"] + 6 and
                now_bool["site_count"] == previous_bool["site_count"] and
                now_bool["unknown_site_count"] == 0,
                "Phase 26 Bool literal spelling inventory drifted")
    if logical_zero_successor is not None:
        previous_logical = bool_zero_successor["current_inventory_summary"]
        now_logical = logical_zero_successor.get("current_inventory_summary", {})
        require(bool_zero_successor is not None and
                logical_zero_successor.get("contract_version") ==
                "phase26_1e_logical_zero_spelling_inventory_successor_v1" and
                logical_zero_successor.get("previous_inventory_summary") ==
                previous_logical and now_logical == (summary if equality_zero_successor is None
                                                   else equality_zero_successor.get("previous_inventory_summary")) and
                logical_zero_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_logical_zero_test_entry.gst",
                    *[f"compiler/phase26_logical_zero_{name}_source.gst"
                      for name in ("safe_call", "safe_return", "nonzero",
                                   "unknown", "unsafe")],
                ]) and
                logical_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_logical["source_file_count"] ==
                previous_logical["source_file_count"] + 6 and
                now_logical["site_count"] == previous_logical["site_count"] and
                now_logical["unknown_site_count"] == 0,
                "Phase 26 logical spelling inventory drifted")
    if equality_zero_successor is not None:
        previous_equality = logical_zero_successor["current_inventory_summary"]
        now_equality = equality_zero_successor.get("current_inventory_summary", {})
        require(logical_zero_successor is not None and
                equality_zero_successor.get("contract_version") ==
                "phase26_1e_equality_zero_spelling_inventory_successor_v1" and
                equality_zero_successor.get("previous_inventory_summary") ==
                previous_equality and now_equality == (summary if relational_zero_successor is None
                                else relational_zero_successor.get("previous_inventory_summary")) and
                equality_zero_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_equality_zero_test_entry.gst",
                    *[f"compiler/phase26_equality_zero_{name}_source.gst"
                      for name in ("safe_call", "safe_return", "nonzero",
                                   "unknown", "unsafe")],
                ]) and
                equality_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_equality["source_file_count"] ==
                previous_equality["source_file_count"] + 6 and
                now_equality["site_count"] == previous_equality["site_count"] and
                now_equality["unknown_site_count"] == 0,
                "Phase 26 equality spelling inventory drifted")
    if relational_zero_successor is not None:
        previous_relational = equality_zero_successor["current_inventory_summary"]
        now_relational = relational_zero_successor.get("current_inventory_summary", {})
        require(equality_zero_successor is not None and
                relational_zero_successor.get("contract_version") ==
                "phase26_1e_relational_zero_spelling_inventory_successor_v1" and
                relational_zero_successor.get("previous_inventory_summary") ==
                previous_relational and now_relational == (summary if explicit_brand_successor is None
                                else explicit_brand_successor.get("previous_inventory_summary")) and
                relational_zero_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_relational_zero_test_entry.gst",
                    *[f"compiler/phase26_relational_zero_{name}_source.gst"
                      for name in ("safe_call", "safe_return", "nonzero",
                                   "unknown", "unsafe")],
                ]) and
                relational_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_relational["source_file_count"] ==
                previous_relational["source_file_count"] + 6 and
                now_relational["site_count"] == previous_relational["site_count"] and
                now_relational["unknown_site_count"] == 0,
                "Phase 26 relational spelling inventory drifted")
    if explicit_brand_successor is not None:
        previous_explicit = relational_zero_successor["current_inventory_summary"]
        now_explicit = explicit_brand_successor.get("current_inventory_summary", {})
        require(relational_zero_successor is not None and
                explicit_brand_successor.get("contract_version") ==
                "phase26_1e_explicit_brand_spelling_inventory_successor_v1" and
                explicit_brand_successor.get("previous_inventory_summary") ==
                previous_explicit and now_explicit ==
                (summary if empty_raw_zero_successor is None else
                 empty_raw_zero_successor.get("previous_inventory_summary")) and
                explicit_brand_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_explicit_brand_test_entry.gst",
                ]) and
                explicit_brand_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_explicit["source_file_count"] ==
                previous_explicit["source_file_count"] + 1 and
                now_explicit["unknown_site_count"] == 0,
                "Phase 26 explicit-brand spelling inventory drifted")
    if empty_raw_zero_successor is not None:
        previous_empty = explicit_brand_successor["current_inventory_summary"]
        now_empty = empty_raw_zero_successor.get("current_inventory_summary", {})
        require(explicit_brand_successor is not None and
                empty_raw_zero_successor.get("contract_version") ==
                "phase26_1e_empty_raw_zero_spelling_inventory_successor_v1" and
                empty_raw_zero_successor.get("previous_inventory_summary") ==
                previous_empty and now_empty ==
                (summary if call_return_zero_successor is None else
                 call_return_zero_successor.get("previous_inventory_summary")) and
                empty_raw_zero_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_empty_raw_zero_test_entry.gst",
                    *[f"compiler/phase26_empty_raw_zero_{name}_source.gst"
                      for name in ("safe_call", "safe_return", "nonzero",
                                   "unknown", "unsafe")],
                ]) and
                empty_raw_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and
                now_empty["source_file_count"] ==
                previous_empty["source_file_count"] + 6 and
                now_empty["unknown_site_count"] == 0,
                "Phase 26 Empty raw-pointer spelling inventory drifted")
    if call_return_zero_successor is not None:
        require(empty_raw_zero_successor is not None and
                call_return_zero_successor.get("contract_version") ==
                "phase26_1e_call_return_zero_spelling_inventory_successor_v1" and
                call_return_zero_successor.get("previous_inventory_summary") ==
                empty_raw_zero_successor["current_inventory_summary"] and
                call_return_zero_successor.get("current_inventory_summary") ==
                (summary if call_local_zero_successor is None else
                 call_local_zero_successor.get("previous_inventory_summary")) and
                call_return_zero_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/test_runner_entry.gst",
                    "compiler/phase26_call_return_zero_test_entry.gst",
                    *[f"compiler/phase26_call_return_zero_{name}_source.gst"
                      for name in ("caller_first", "callee_first", "safe_return", "mayzero",
                                   "nonzero", "unknown", "unsafe_target",
                                   "prior_error")],
                ]) and
                call_return_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and summary["unknown_site_count"] == 0,
                "Phase 26 direct-call return spelling inventory drifted")
    if call_local_zero_successor is not None:
        require(call_return_zero_successor is not None and
                call_local_zero_successor.get("contract_version") ==
                "phase26_1e_call_local_zero_spelling_inventory_successor_v1" and
                call_local_zero_successor.get("previous_inventory_summary") ==
                call_return_zero_successor["current_inventory_summary"] and
                call_local_zero_successor.get("current_inventory_summary") ==
                (summary if call_alias_zero_successor is None else
                 call_alias_zero_successor.get("previous_inventory_summary")) and
                call_local_zero_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_call_return_zero_test_entry.gst",
                    *[f"compiler/phase26_call_local_zero_{name}_source.gst"
                      for name in ("caller_first", "callee_first", "mayzero",
                                   "overwrite", "nonzero", "unknown",
                                   "unsafe_target", "alias", "branch", "loop",
                                   "prior_error")],
                ]) and
                call_local_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and summary["unknown_site_count"] == 0,
                "Phase 26 local-call spelling inventory drifted")
    if call_alias_zero_successor is not None:
        require(call_local_zero_successor is not None and
                call_alias_zero_successor.get("contract_version") ==
                "phase26_1e_call_alias_zero_spelling_inventory_successor_v1" and
                call_alias_zero_successor.get("previous_inventory_summary") ==
                call_local_zero_successor["current_inventory_summary"] and
                call_alias_zero_successor.get("current_inventory_summary") ==
                (summary if call_chain_zero_successor is None else
                 call_chain_zero_successor.get("previous_inventory_summary")) and
                call_alias_zero_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_call_return_zero_test_entry.gst",
                    *[f"compiler/phase26_call_alias_zero_{name}_source.gst"
                      for name in ("caller_first", "mayzero", "nonzero",
                                   "unknown", "unsafe_target", "overwrite",
                                   "intervening", "chain", "nested",
                                   "prior_error")],
                ]) and
                call_alias_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and summary["unknown_site_count"] == 0,
                "Phase 26 one-hop alias spelling inventory drifted")
    if call_chain_zero_successor is not None:
        chain_paths = [f"compiler/phase26_call_chain_zero_{name}_source.gst"
                       for name in ("caller_first", "callee_first",
                                    "mayzero_caller_first", "mayzero_callee_first",
                                    "nonzero", "unknown", "unsafe_target",
                                    "overwrite", "intervening", "nested",
                                    "prior_error")]
        require(call_alias_zero_successor is not None and
                call_chain_zero_successor.get("contract_version") ==
                "phase26_1e_call_chain_zero_spelling_inventory_successor_v1" and
                call_chain_zero_successor.get("previous_inventory_summary") ==
                call_alias_zero_successor["current_inventory_summary"] and
                call_chain_zero_successor.get("current_inventory_summary") ==
                (summary if call_take_alias_zero_successor is None else
                 call_take_alias_zero_successor.get("previous_inventory_summary")) and
                call_chain_zero_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_call_return_zero_test_entry.gst",
                    *chain_paths,
                ]) and
                call_chain_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and summary["unknown_site_count"] == 0,
                "Phase 26 consecutive-alias spelling inventory drifted")
    if call_take_alias_zero_successor is not None:
        take_names = ("caller_first", "callee_first", "mayzero_caller_first",
                      "mayzero_callee_first", "nonzero", "unknown", "unsafe_target",
                      "overwrite", "intervening", "nested", "chained_after_take",
                      "prior_error", "direct_take_argument", "safe_return",
                      "literal_take")
        require(call_chain_zero_successor is not None and
                call_take_alias_zero_successor.get("contract_version") ==
                "phase26_1e_call_take_alias_zero_spelling_inventory_successor_v1" and
                call_take_alias_zero_successor.get("previous_inventory_summary") ==
                call_chain_zero_successor["current_inventory_summary"] and
                call_take_alias_zero_successor.get("current_inventory_summary") ==
                (summary if call_direct_take_zero_successor is None else
                 call_direct_take_zero_successor.get("previous_inventory_summary")) and
                call_take_alias_zero_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_call_return_zero_test_entry.gst",
                    *[f"compiler/phase26_call_take_alias_zero_{name}_source.gst"
                      for name in take_names],
                ]) and
                call_take_alias_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and summary["unknown_site_count"] == 0,
                "Phase 26 Take-alias spelling inventory drifted")
    if call_direct_take_zero_successor is not None:
        direct_take_names = ("caller_first", "mayzero_caller_first",
                             "mayzero_callee_first", "plain_chain", "literal_take",
                             "nonzero", "unknown", "unsafe_target", "overwrite",
                             "intervening", "nested", "nested_take", "second_take",
                             "prior_error", "type_mismatch")
        require(call_take_alias_zero_successor is not None and
                call_direct_take_zero_successor.get("contract_version") ==
                "phase26_1e_call_direct_take_zero_spelling_inventory_successor_v1" and
                call_direct_take_zero_successor.get("previous_inventory_summary") ==
                call_take_alias_zero_successor["current_inventory_summary"] and
                call_direct_take_zero_successor.get("current_inventory_summary") ==
                (summary if call_direct_move_zero_successor is None else
                 call_direct_move_zero_successor.get("previous_inventory_summary")) and
                call_direct_take_zero_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_call_return_zero_test_entry.gst",
                    *[f"compiler/phase26_call_direct_take_zero_{name}_source.gst"
                      for name in direct_take_names],
                ]) and
                call_direct_take_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and summary["unknown_site_count"] == 0,
                "Phase 26 direct-Take spelling inventory drifted")
    if call_direct_move_zero_successor is not None:
        direct_move_names = ("caller_first", "mayzero_caller_first",
                             "mayzero_callee_first", "plain_chain", "literal_move",
                             "nonzero", "unknown", "unsafe_target", "overwrite",
                             "intervening", "nested", "nested_move", "second_move",
                             "prior_take_alias", "move_alias", "prior_error",
                             "type_mismatch")
        require(call_direct_take_zero_successor is not None and
                call_direct_move_zero_successor.get("contract_version") ==
                "phase26_1e_call_direct_move_zero_spelling_inventory_successor_v1" and
                call_direct_move_zero_successor.get("previous_inventory_summary") ==
                call_direct_take_zero_successor["current_inventory_summary"] and
                call_direct_move_zero_successor.get("current_inventory_summary") ==
                (summary if call_move_wrapper_zero_successor is None else
                 call_move_wrapper_zero_successor.get("previous_inventory_summary")) and
                call_direct_move_zero_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_call_return_zero_test_entry.gst",
                    *[f"compiler/phase26_call_direct_move_zero_{name}_source.gst"
                      for name in direct_move_names],
                ]) and
                call_direct_move_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and summary["unknown_site_count"] == 0,
                "Phase 26 direct-Move spelling inventory drifted")
    if call_move_wrapper_zero_successor is not None:
        move_call_names = ("argument_caller_first", "argument_callee_first",
                           "argument_mayzero_caller_first", "argument_mayzero_callee_first",
                           "return_caller_first", "return_callee_first",
                           "return_mayzero_caller_first", "return_mayzero_callee_first",
                           "nonzero", "unknown", "unsafe_target", "prior_error",
                           "nested_move", "take", "type_mismatch")
        require(call_direct_move_zero_successor is not None and
                call_move_wrapper_zero_successor.get("contract_version") ==
                "phase26_1e_call_move_wrapper_zero_spelling_inventory_successor_v1" and
                call_move_wrapper_zero_successor.get("previous_inventory_summary") ==
                call_direct_move_zero_successor["current_inventory_summary"] and
                call_move_wrapper_zero_successor.get("current_inventory_summary") ==
                (summary if call_take_wrapper_zero_successor is None else
                 call_take_wrapper_zero_successor.get("previous_inventory_summary")) and
                call_move_wrapper_zero_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_call_return_zero_test_entry.gst",
                    *[f"compiler/phase26_call_move_wrapper_zero_{name}_source.gst"
                      for name in move_call_names],
                ]) and
                call_move_wrapper_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and summary["unknown_site_count"] == 0,
                "Phase 26 Move(Call) spelling inventory drifted")
    if call_take_wrapper_zero_successor is not None:
        take_call_names = ("argument_caller_first", "argument_callee_first",
                           "argument_mayzero_caller_first", "argument_mayzero_callee_first",
                           "return_caller_first", "return_callee_first",
                           "return_mayzero_caller_first", "return_mayzero_callee_first",
                           "nonzero", "unknown", "unsafe_target", "prior_error",
                           "nested_take", "move_take", "type_mismatch")
        require(call_move_wrapper_zero_successor is not None and
                call_take_wrapper_zero_successor.get("contract_version") ==
                "phase26_1e_call_take_wrapper_zero_spelling_inventory_successor_v1" and
                call_take_wrapper_zero_successor.get("previous_inventory_summary") ==
                call_move_wrapper_zero_successor["current_inventory_summary"] and
                call_take_wrapper_zero_successor.get("current_inventory_summary") ==
                (summary if call_two_wrapper_zero_successor is None else
                 call_two_wrapper_zero_successor.get("previous_inventory_summary")) and
                call_take_wrapper_zero_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_call_return_zero_test_entry.gst",
                    *[f"compiler/phase26_call_take_wrapper_zero_{name}_source.gst"
                      for name in take_call_names],
                ]) and
                call_take_wrapper_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and summary["unknown_site_count"] == 0,
                "Phase 26 Take(Call) spelling inventory drifted")
    if call_two_wrapper_zero_successor is not None:
        pair_names = ("move_take", "take_move", "move_move", "take_take")
        matrix_paths = [f"compiler/phase26_call_two_wrapper_zero_{pair}_{boundary}_{order}_source.gst"
                        for pair in pair_names for boundary in ("argument", "return")
                        for order in ("caller_first", "callee_first")]
        control_paths = [f"compiler/phase26_call_two_wrapper_zero_{name}_source.gst"
                         for name in ("mayzero", "nonzero", "unsafe_target", "prior_error",
                                      "type_mismatch", "depth3")]
        previous = call_take_wrapper_zero_successor["current_inventory_summary"]
        require(call_take_wrapper_zero_successor is not None and
                call_two_wrapper_zero_successor.get("contract_version") ==
                "phase26_1e_call_two_wrapper_zero_spelling_inventory_successor_v1" and
                call_two_wrapper_zero_successor.get("previous_inventory_summary") == previous and
                call_two_wrapper_zero_successor.get("current_inventory_summary") ==
                (summary if call_wrapper_chain_zero_successor is None else
                 call_wrapper_chain_zero_successor.get("previous_inventory_summary")) and
                call_two_wrapper_zero_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_call_return_zero_test_entry.gst",
                    *matrix_paths, *control_paths,
                ]) and
                call_two_wrapper_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and call_two_wrapper_zero_successor[
                    "current_inventory_summary"]["source_file_count"] ==
                previous["source_file_count"] + 22 and
                call_two_wrapper_zero_successor[
                    "current_inventory_summary"]["site_count"] == previous["site_count"] and
                call_two_wrapper_zero_successor[
                    "current_inventory_summary"]["semantic_site_count"] == previous["semantic_site_count"] and
                summary["unknown_site_count"] == 0,
                "Phase 26 depth-two wrapper spelling inventory drifted")
    if call_wrapper_chain_zero_successor is not None:
        triple_paths = [
            f"compiler/phase26_call_wrapper_chain_zero_{a}_{b}_{c}_{boundary}_{order}_source.gst"
            for a in ("move", "take") for b in ("move", "take")
            for c in ("move", "take") for boundary in ("argument", "return")
            for order in ("caller_first", "callee_first")]
        control_paths = [f"compiler/phase26_call_wrapper_chain_zero_{name}_source.gst"
                         for name in ("depth4_zero", "mayzero_argument", "mayzero_return",
                                      "nonzero", "unknown", "unsafe_target",
                                      "prior_error", "type_mismatch")]
        previous = call_two_wrapper_zero_successor["current_inventory_summary"]
        require(call_two_wrapper_zero_successor is not None and
                call_wrapper_chain_zero_successor.get("contract_version") ==
                "phase26_1e_call_wrapper_chain_zero_spelling_inventory_successor_v1" and
                call_wrapper_chain_zero_successor.get("previous_inventory_summary") == previous and
                call_wrapper_chain_zero_successor.get("current_inventory_summary") ==
                (summary if call_as_cast_zero_successor is None else
                 call_as_cast_zero_successor.get("previous_inventory_summary")) and
                call_wrapper_chain_zero_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_call_return_zero_test_entry.gst",
                    *triple_paths, *control_paths,
                ]) and
                call_wrapper_chain_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and call_wrapper_chain_zero_successor[
                    "current_inventory_summary"]["source_file_count"] ==
                previous["source_file_count"] + 40 and
                call_wrapper_chain_zero_successor[
                    "current_inventory_summary"]["site_count"] == previous["site_count"] and
                call_wrapper_chain_zero_successor[
                    "current_inventory_summary"]["semantic_site_count"] == previous["semantic_site_count"] and
                call_wrapper_chain_zero_successor[
                    "current_inventory_summary"]["unknown_site_count"] == 0,
                "Phase 26 wrapper-chain spelling inventory drifted")
    if call_as_cast_zero_successor is not None:
        paths = [f"compiler/phase26_call_cast_zero_{name}_source.gst"
                 for name in ("argument_caller_first", "argument_callee_first",
                              "other_pointer", "return_caller_first",
                              "return_callee_first", "mayzero_argument",
                              "mayzero_return", "nonzero", "unknown",
                              "unsafe_target", "type_mismatch", "nested",
                              "move_cast", "cast_move", "take_cast", "cast_take")]
        previous = call_wrapper_chain_zero_successor["current_inventory_summary"]
        require(call_as_cast_zero_successor.get("contract_version") ==
                "phase26_1e_call_as_cast_zero_spelling_inventory_successor_v1" and
                call_as_cast_zero_successor.get("previous_inventory_summary") == previous and
                call_as_cast_zero_successor.get("current_inventory_summary") ==
                (summary if call_as_cast_chain_zero_successor is None else
                 call_as_cast_chain_zero_successor.get("previous_inventory_summary")) and
                call_as_cast_zero_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_call_return_zero_test_entry.gst", *paths,
                ]) and
                call_as_cast_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and call_as_cast_zero_successor[
                    "current_inventory_summary"]["source_file_count"] ==
                previous["source_file_count"] + len(paths) and
                call_as_cast_zero_successor["current_inventory_summary"]["site_count"] ==
                previous["site_count"] and
                call_as_cast_zero_successor[
                    "current_inventory_summary"]["semantic_site_count"] ==
                previous["semantic_site_count"] and
                call_as_cast_zero_successor[
                    "current_inventory_summary"]["unknown_site_count"] == 0,
                "Phase 26 one RawPointer AsCast spelling inventory drifted")
    if call_as_cast_chain_zero_successor is not None:
        paths = [f"compiler/phase26_call_cast_chain_zero_{name}_source.gst"
                 for name in ("argument_caller_first", "argument_callee_first",
                              "return_caller_first", "return_callee_first",
                              "mayzero_argument", "depth3_argument",
                              "depth3_mayzero_return", "nonzero", "unknown",
                              "unsafe_target", "type_mismatch", "scalar_inner",
                              "move_cast", "cast_move", "take_cast", "cast_take")]
        previous = call_as_cast_zero_successor["current_inventory_summary"]
        require(call_as_cast_chain_zero_successor.get("contract_version") ==
                "phase26_1e_call_as_cast_chain_zero_spelling_inventory_successor_v1" and
                call_as_cast_chain_zero_successor.get("previous_inventory_summary") == previous and
                call_as_cast_chain_zero_successor.get("current_inventory_summary") == summary and
                call_as_cast_chain_zero_successor.get("changed_source_paths") == sorted([
                    "compiler/typechecker.gst",
                    "compiler/phase26_call_return_zero_test_entry.gst", *paths,
                ]) and
                call_as_cast_chain_zero_successor.get("partial_extra_or_substituted_inventory") ==
                "rejected" and summary["source_file_count"] ==
                previous["source_file_count"] + len(paths) and
                summary["site_count"] == previous["site_count"] and
                summary["semantic_site_count"] == previous["semantic_site_count"] and
                summary["unknown_site_count"] == 0,
                "Phase 26 RawPointer AsCast-chain spelling inventory drifted")
    require(value.get("classification_policy") == {
        "semantic": SEMANTIC,
        "non_semantic_partitions": list(PARTITIONS),
        "site_identity": "tracked_source_path_plus_source_line_plus_classification",
        "spelling_scope": "quoted_concrete_stdlib_runtime_names_prefixes_and_generated_forms",
        "unknown_policy": "reject",
    }, "classification policy drifted")
    require(value.get("falsifiers") == [
        "omitted_site", "substituted_spelling", "duplicate_site",
        "unclassified_site", "stale_line",
    ], "falsifier authority drifted")
    require(value.get("boundary") == {
        "changes_compiler_or_runtime_source": False,
        "changes_accepted_Gust_program_meaning": False,
        "adds_intrinsic_ids_or_dispatch": False,
        "changes_MIR_ABI_layout_runtime_symbols_or_backend_route": False,
        "changes_bootstrap_route_or_seed": False,
        "edits_stdlib": False,
        "begins_patch24_3": False,
    }, "report-only boundary drifted")
    return value, rows, summary


def run_falsifiers(rows: list[dict], summary: dict) -> None:
    require(len(rows) > 1, "falsifiers require multiple rows")
    omitted = rows[:-1]
    require(manifest_summary(omitted)["complete_manifest_digest"] !=
            summary["complete_manifest_digest"], "omission falsifier did not fire")
    substituted = json.loads(json.dumps(rows))
    substituted[0]["spellings"][0] += "_substituted"
    require(digest(substituted) != summary["complete_manifest_digest"],
            "substitution falsifier did not fire")
    duplicated = [*rows, rows[0]]
    try:
        validate_row_shape(duplicated)
    except InventoryError as error:
        require("duplicate" in str(error), "duplicate falsifier returned wrong failure")
    else:
        raise InventoryError("duplicate falsifier did not fire")
    synthetic = json.loads(json.dumps(rows[0]))
    synthetic["classification"] = "unknown"
    try:
        validate_row_shape([synthetic])
    except InventoryError as error:
        require("unclassified" in str(error), "unclassified falsifier returned wrong failure")
    else:
        raise InventoryError("unclassified falsifier did not fire")
    stale = json.loads(json.dumps(rows[0]))
    stale["source_digest"] = "0" * 64
    try:
        validate_row_shape([stale])
    except InventoryError as error:
        require("stale-line" in str(error), "stale-line falsifier returned wrong failure")
    else:
        raise InventoryError("stale-line falsifier did not fire")


def render(value: dict, rows: list[dict], summary: dict) -> str:
    lines = [
        "# Cranelift Phase 24 Semantic Spelling Inventory",
        "",
        "Generated by `scripts/phase24_semantic_spelling_inventory.py`; do not edit by hand.",
        "",
        "Patch 24.2 is report-only. Every row below preserves the current spelling-based",
        "decision or explicitly places a non-decision spelling in one of six partitions.",
        "No intrinsic ID, dispatch, compiler structure, or accepted meaning changes here.",
        "",
        f"- Contract: `{value['contract_version']}`",
        f"- Authority base: `{value['authority_base_main']}`",
        f"- Tracked compiler source files: `{summary['source_file_count']}`",
        f"- Classified sites: `{summary['site_count']}`",
        f"- Semantic/intrinsic recognition sites: `{summary['semantic_site_count']}`",
        f"- Unknown sites: `{summary['unknown_site_count']}`",
        "",
        "## Partition summary",
        "",
        "| Classification | Sites | Manifest digest |",
        "| --- | ---: | --- |",
        f"| `{SEMANTIC}` | {summary['classification_counts'][SEMANTIC]} | `{summary['semantic_manifest_digest']}` |",
    ]
    for name in PARTITIONS:
        lines.append(
            f"| `{name}` | {summary['classification_counts'][name]} | "
            f"`{summary['partition_manifest_digests'][name]}` |"
        )
    lines += [
        "",
        "## Site inventory",
        "",
        "Each row carries the complete required authority fields. Repeated aliases in one",
        "source line are one stable decision site. Every line is pinned by the registry",
        "digest and re-read by the guard.",
        "",
        "| ID | Spelling(s) | Source | Layer | Classification | Decision / semantic role | Current authority | Present owner | Eventual intrinsic owner | Later phase | Reason retained | Falsifier |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for row in rows:
        spellings = ", ".join(f"`{value}`" for value in row["spellings"])
        lines.append(
            f"| `{row['id']}` | {spellings} | `{row['path']}:{row['line']}` "
            f"(`{row['function']}`) | `{row['layer']}` | `{row['classification']}` | "
            f"{row['decision']}; `{row['semantic_role']}` | `{row['current_authority']}` | "
            f"`{row['present_owner']}` | `{row['eventual_intrinsic_owner']}` | "
            f"`{row['intended_later_phase']}` | `{row['reason_retained']}` | "
            f"`{row['falsifier']}` |"
        )
    lines += [
        "",
        "## Falsification boundary",
        "",
        "The evidence command mutates the derived manifest in memory and proves rejection",
        "of omission, spelling substitution, duplicate identity, an unknown classification,",
        "and a stale source-line digest. Source files are never modified by that replay.",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=(
        "scan-json", "validate", "project", "check-review", "evidence", "full",
    ))
    args = parser.parse_args()
    try:
        if args.command == "scan-json":
            rows = source_sites()
            validate_row_shape(rows)
            summary = manifest_summary(rows)
            print(json.dumps(summary, indent=2, sort_keys=True))
            return 0
        value, rows, summary = validate()
        projected = render(value, rows, summary)
        if args.command == "project":
            REVIEW.write_text(projected, encoding="utf-8")
        elif args.command in {"check-review", "full"}:
            require(REVIEW.is_file(), f"missing generated review {REVIEW_PATH}")
            require(REVIEW.read_text(encoding="utf-8") == projected,
                    "generated spelling inventory is stale; run project")
        if args.command in {"evidence", "full"}:
            run_falsifiers(rows, summary)
            print("guard-cranelift-phase24-semantic-spelling-inventory-contract: evidence ok")
    except (InventoryError, subprocess.CalledProcessError) as error:
        print(f"{GUARD}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
