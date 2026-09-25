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
        require(ffi_successor.get("contract_version") ==
                "phase26_1d1_spelling_inventory_successor_v1" and
                ffi_successor.get("previous_inventory_summary") == previous and
                ffi_successor.get("current_inventory_summary") == summary and
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
                summary["source_file_count"] ==
                previous["source_file_count"] + 12 and
                summary["site_count"] == previous["site_count"] and
                summary["semantic_site_count"] ==
                previous["semantic_site_count"] and
                summary["classification_counts"] ==
                previous["classification_counts"] and
                summary["unknown_site_count"] == 0,
                "Phase 26.1D1 spelling inventory changed beyond its "
                "registered source and identity successor")
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
