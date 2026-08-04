#!/usr/bin/env python3
"""Validate and render Patch 14.13 deferred residue and target coverage."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
SCHEMA = ROOT / "scripts/cranelift_feature_registry.schema.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE14_FINAL_REVIEW.md"

VERSION = "phase14_deferred_residue_v1"
STATUS = "frozen_for_future_phases"
OPENING_VERSION = "phase14_opening_inventory_v1"
REVIEW_PATH = "compiler/CRANELIFT_PHASE14_FINAL_REVIEW.md"

SNAPSHOT_FIELDS = {
    "version",
    "status",
    "source_opening_version",
    "final_review_view",
    "immutable_fields",
    "broad_description_bans",
    "resolution_policy",
    "freeze_policy",
    "opening_dispositions",
    "inherited_residual_dispositions",
    "target_dispositions",
    "rows",
}
ROW_FIELDS = (
    "id",
    "feature_family",
    "capability_owner",
    "diagnostic_owner",
    "capability",
    "concrete_reason",
    "destination_phase",
    "prerequisite_capability",
    "current_failure_stage",
    "target_applicability",
    "positive_future_fixture",
    "negative_current_fixture",
    "diagnostic_reason_code",
    "source_phase14_row_ids",
    "source_phase13_residual_ids",
)
OPENING_DISPOSITION_FIELDS = {
    "source_phase14_row_id",
    "final_disposition",
    "replacement_residual_ids",
    "justification",
}
INHERITED_DISPOSITION_FIELDS = {
    "source_phase13_residual_id",
    "final_disposition",
    "selected_phase14_row_ids",
    "replacement_residual_ids",
    "destination_phase",
    "justification",
}
TARGET_DISPOSITION_FIELDS = {
    "target_id",
    "target_triple",
    "final_disposition",
    "replacement_residual_ids",
    "justification",
}
BROAD_DESCRIPTION_BANS = (
    "more_types",
    "more_pointers",
    "more_aggregates",
    "more_memory_operations",
    "unsupported_layout",
    "unsupported_target",
    "broader_ABI",
    "runtime_work_later",
)
FAILURE_STAGES = {
    "before_driver_discovery",
    "canonical_mir_validation_before_driver_discovery",
    "source_or_type_failure_before_driver_discovery",
}
OPENING_FINAL_DISPOSITIONS = {"migrated", "excluded", "replaced"}
TARGET_FINAL_DISPOSITIONS = {"supported", "excluded", "replaced"}


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def read_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise Error(f"missing required file: {path.relative_to(ROOT)}") from exc
    except json.JSONDecodeError as exc:
        raise Error(
            f"invalid JSON in {path.relative_to(ROOT)}:"
            f"{exc.lineno}:{exc.colno}: {exc.msg}"
        ) from exc
    require(isinstance(value, dict), f"{path.relative_to(ROOT)} must contain an object")
    return value


def text(value: object, context: str) -> str:
    require(isinstance(value, str) and value.strip(), f"{context} must be non-empty text")
    return value


def unique_strings(value: object, context: str, *, allow_empty: bool = False) -> list[str]:
    require(isinstance(value, list), f"{context} must be an array")
    if not allow_empty:
        require(value, f"{context} must not be empty")
    require(
        all(isinstance(item, str) and item for item in value),
        f"{context} must contain non-empty strings",
    )
    require(len(value) == len(set(value)), f"{context} contains duplicates")
    return value


def normalized_searchable(*parts: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", "_".join(parts).lower()).strip("_")


def fixture(path_text: object, residual_id: str, marker: str) -> str:
    relative = text(path_text, f"{residual_id}.{marker}_fixture")
    path = ROOT / relative
    require(path.is_file() and not path.is_symlink(), f"{residual_id}: missing regular fixture {relative}")
    source = path.read_text(encoding="utf-8")
    require(f"residual_id: {residual_id}" in source, f"{residual_id}: fixture {relative} lacks residual ID marker")
    if marker == "negative":
        require(
            f"expected_reason_code: deferred_{residual_id}" in source,
            f"{residual_id}: negative fixture lacks stable reason-code marker",
        )
    else:
        require(
            f"destination_phase:" in source,
            f"{residual_id}: future fixture lacks destination-phase marker",
        )
    return relative


def validate_schema(schema: dict) -> None:
    residual = schema.get("properties", {}).get("residual_snapshots", {})
    require(
        set(residual.get("required", [])) == {"phase13", "phase14"},
        "schema residual snapshot keys must be phase13 and phase14",
    )
    require(
        residual.get("properties", {}).get("phase14", {}).get("$ref")
        == "#/$defs/phase14_residual_snapshot",
        "schema does not route residual_snapshots.phase14 to its canonical definition",
    )

    definitions = schema.get("$defs", {})
    checks = {
        "phase14_residual_snapshot": SNAPSHOT_FIELDS,
        "phase14_opening_disposition": OPENING_DISPOSITION_FIELDS,
        "phase14_inherited_residual_disposition": INHERITED_DISPOSITION_FIELDS,
        "phase14_target_disposition": TARGET_DISPOSITION_FIELDS,
        "phase14_residual_row": set(ROW_FIELDS),
    }
    for name, expected in checks.items():
        definition = definitions.get(name, {})
        require(
            set(definition.get("required", [])) == set(expected),
            f"schema {name} required fields drifted",
        )
        require(
            definition.get("additionalProperties") is False,
            f"schema {name} must reject unknown fields",
        )


def validate() -> dict:
    registry = read_json(REGISTRY)
    schema = read_json(SCHEMA)
    validate_schema(schema)

    snapshots = registry.get("residual_snapshots")
    require(
        isinstance(snapshots, dict) and set(snapshots) == {"phase13", "phase14"},
        "residual_snapshots must contain exactly phase13 and phase14",
    )
    snapshot = snapshots["phase14"]
    require(
        isinstance(snapshot, dict) and set(snapshot) == SNAPSHOT_FIELDS,
        "Phase 14 residual snapshot fields drifted",
    )
    require(snapshot["version"] == VERSION, "Phase 14 residual version drifted")
    require(snapshot["status"] == STATUS, "Phase 14 residual snapshot is not frozen")
    require(
        snapshot["source_opening_version"] == OPENING_VERSION,
        "Phase 14 residual snapshot opening version drifted",
    )
    require(
        snapshot["final_review_view"] == REVIEW_PATH,
        "Phase 14 final review path drifted",
    )
    require(
        snapshot["immutable_fields"] == list(ROW_FIELDS),
        "Phase 14 residual immutable fields drifted",
    )
    require(
        snapshot["broad_description_bans"] == list(BROAD_DESCRIPTION_BANS),
        "Phase 14 broad-description bans drifted",
    )
    text(snapshot["resolution_policy"], "phase14.resolution_policy")
    text(snapshot["freeze_policy"], "phase14.freeze_policy")

    opening = registry.get("opening_snapshots", {}).get("phase14", {})
    require(
        opening.get("inventory_version") == OPENING_VERSION,
        "Phase 14 opening inventory version drifted",
    )
    opening_rows = opening.get("entries")
    require(isinstance(opening_rows, list) and opening_rows, "Phase 14 opening rows are missing")
    opening_ids = [text(row.get("id"), "Phase 14 opening row ID") for row in opening_rows]
    require(len(opening_ids) == len(set(opening_ids)), "Phase 14 opening row IDs are duplicated")

    current_rows = {
        entry["id"]: entry
        for entry in registry.get("entries", [])
        if entry.get("origin_phase") == "phase14"
    }
    require(
        set(current_rows) == set(opening_ids),
        "current Phase 14 rows differ from the opening inventory",
    )

    residual_rows = snapshot["rows"]
    require(isinstance(residual_rows, list) and residual_rows, "Phase 14 residual rows are missing")
    residual_by_id: dict[str, dict] = {}
    reason_codes: set[str] = set()
    future_fixtures: set[str] = set()
    negative_fixtures: set[str] = set()
    inherited_phase13_ids = {
        row["id"]
        for row in snapshots["phase13"]["rows"]
        if row.get("destination_phase") == "phase14"
    }
    for index, row in enumerate(residual_rows):
        context = f"residual_snapshots.phase14.rows[{index}]"
        require(
            isinstance(row, dict) and set(row) == set(ROW_FIELDS),
            f"{context} fields or field order drifted",
        )
        residual_id = text(row["id"], f"{context}.id")
        require(
            re.fullmatch(r"p[0-9]+_[A-Za-z0-9_]+", residual_id) is not None,
            f"{residual_id}: residual ID is not stable",
        )
        require(residual_id not in residual_by_id, f"duplicate Phase 14 residual ID: {residual_id}")
        residual_by_id[residual_id] = row

        for field in (
            "feature_family",
            "capability_owner",
            "diagnostic_owner",
            "capability",
            "concrete_reason",
            "destination_phase",
            "prerequisite_capability",
            "target_applicability",
        ):
            text(row[field], f"{residual_id}.{field}")
        require(
            re.fullmatch(r"phase[0-9]+", row["destination_phase"]) is not None,
            f"{residual_id}: destination phase is not concrete",
        )
        require(
            residual_id.startswith(row["destination_phase"].replace("phase", "p") + "_"),
            f"{residual_id}: stable ID and destination phase disagree",
        )
        require(
            row["current_failure_stage"] in FAILURE_STAGES,
            f"{residual_id}: current failure stage is not stable",
        )
        expected_reason = f"deferred_{residual_id}"
        require(
            row["diagnostic_reason_code"] == expected_reason,
            f"{residual_id}: diagnostic reason code must be {expected_reason}",
        )
        require(expected_reason not in reason_codes, f"duplicate diagnostic reason code: {expected_reason}")
        reason_codes.add(expected_reason)

        sources14 = unique_strings(
            row["source_phase14_row_ids"],
            f"{residual_id}.source_phase14_row_ids",
        )
        require(
            set(sources14) <= set(opening_ids),
            f"{residual_id}: unknown Phase 14 source rows",
        )
        sources13 = unique_strings(
            row["source_phase13_residual_ids"],
            f"{residual_id}.source_phase13_residual_ids",
            allow_empty=True,
        )
        require(
            set(sources13) <= inherited_phase13_ids,
            f"{residual_id}: unknown inherited Phase 13 residual rows",
        )

        searchable = normalized_searchable(
            row["capability"],
            row["concrete_reason"],
            row["prerequisite_capability"],
            row["target_applicability"],
        )
        for banned in BROAD_DESCRIPTION_BANS:
            require(
                normalized_searchable(banned) not in searchable,
                f"{residual_id}: broad residual description remains: {banned}",
            )

        future_path = fixture(row["positive_future_fixture"], residual_id, "future")
        negative_path = fixture(row["negative_current_fixture"], residual_id, "negative")
        require(future_path != negative_path, f"{residual_id}: future and negative fixtures must differ")
        require(future_path not in future_fixtures, f"future fixture is shared: {future_path}")
        require(negative_path not in negative_fixtures, f"negative fixture is shared: {negative_path}")
        future_fixtures.add(future_path)
        negative_fixtures.add(negative_path)

    dispositions = snapshot["opening_dispositions"]
    require(isinstance(dispositions, list) and dispositions, "opening dispositions are missing")
    disposition_by_id: dict[str, dict] = {}
    for index, disposition in enumerate(dispositions):
        context = f"opening_dispositions[{index}]"
        require(
            isinstance(disposition, dict) and set(disposition) == OPENING_DISPOSITION_FIELDS,
            f"{context} fields drifted",
        )
        row_id = text(disposition["source_phase14_row_id"], f"{context}.source_phase14_row_id")
        require(row_id not in disposition_by_id, f"duplicate opening disposition: {row_id}")
        disposition_by_id[row_id] = disposition
        final = disposition["final_disposition"]
        require(final in OPENING_FINAL_DISPOSITIONS, f"{row_id}: invalid final disposition")
        require(
            final == current_rows[row_id]["status"],
            f"{row_id}: final disposition differs from the canonical registry row",
        )
        replacements = unique_strings(
            disposition["replacement_residual_ids"],
            f"{row_id}.replacement_residual_ids",
            allow_empty=True,
        )
        require(
            set(replacements) <= set(residual_by_id),
            f"{row_id}: unknown replacement residual IDs",
        )
        if final == "replaced":
            require(replacements, f"{row_id}: replaced row has no narrower residual")
        else:
            require(not replacements, f"{row_id}: non-replaced row has replacement residuals")
        text(disposition["justification"], f"{row_id}.justification")
    require(
        set(disposition_by_id) == set(opening_ids),
        "not every Phase 14 opening row has a final disposition",
    )

    inherited = snapshot["inherited_residual_dispositions"]
    require(isinstance(inherited, list) and inherited, "inherited residual dispositions are missing")
    inherited_by_id: dict[str, dict] = {}
    for index, disposition in enumerate(inherited):
        context = f"inherited_residual_dispositions[{index}]"
        require(
            isinstance(disposition, dict) and set(disposition) == INHERITED_DISPOSITION_FIELDS,
            f"{context} fields drifted",
        )
        source_id = text(
            disposition["source_phase13_residual_id"],
            f"{context}.source_phase13_residual_id",
        )
        require(source_id not in inherited_by_id, f"duplicate inherited disposition: {source_id}")
        inherited_by_id[source_id] = disposition
        final = disposition["final_disposition"]
        require(final in OPENING_FINAL_DISPOSITIONS, f"{source_id}: invalid inherited disposition")
        selected = unique_strings(
            disposition["selected_phase14_row_ids"],
            f"{source_id}.selected_phase14_row_ids",
            allow_empty=True,
        )
        replacements = unique_strings(
            disposition["replacement_residual_ids"],
            f"{source_id}.replacement_residual_ids",
            allow_empty=True,
        )
        require(set(selected) <= set(opening_ids), f"{source_id}: unknown selected Phase 14 rows")
        require(set(replacements) <= set(residual_by_id), f"{source_id}: unknown narrower residual rows")
        require(
            re.fullmatch(r"phase[0-9]+", disposition["destination_phase"]) is not None,
            f"{source_id}: inherited destination phase is not concrete",
        )
        if final == "migrated":
            require(selected and not replacements, f"{source_id}: migrated inherited row needs selected rows only")
            require(disposition["destination_phase"] == "phase14", f"{source_id}: migrated row must finish in phase14")
        elif final == "excluded":
            require(not selected and not replacements, f"{source_id}: excluded row must not select or replace")
            require(disposition["destination_phase"] != "phase14", f"{source_id}: excluded row needs a later destination")
        else:
            require(replacements, f"{source_id}: replaced row has no narrower residual")
            require(disposition["destination_phase"] != "phase14", f"{source_id}: replaced row needs a later destination")
        text(disposition["justification"], f"{source_id}.justification")
    require(
        set(inherited_by_id) == inherited_phase13_ids,
        "Phase 13 residual rows assigned to Phase 14 are not fully resolved",
    )

    declared_targets = registry.get("phase14_primitive_layout", {}).get("declared_targets")
    require(isinstance(declared_targets, list) and declared_targets, "declared Phase 14 targets are missing")
    declared_by_id = {target["target_id"]: target for target in declared_targets}
    require(len(declared_by_id) == len(declared_targets), "declared target IDs are duplicated")

    target_dispositions = snapshot["target_dispositions"]
    require(isinstance(target_dispositions, list) and target_dispositions, "target dispositions are missing")
    target_by_id: dict[str, dict] = {}
    for index, disposition in enumerate(target_dispositions):
        context = f"target_dispositions[{index}]"
        require(
            isinstance(disposition, dict) and set(disposition) == TARGET_DISPOSITION_FIELDS,
            f"{context} fields drifted",
        )
        target_id = text(disposition["target_id"], f"{context}.target_id")
        require(target_id not in target_by_id, f"duplicate target disposition: {target_id}")
        target_by_id[target_id] = disposition
        require(target_id in declared_by_id, f"unknown declared target: {target_id}")
        require(
            disposition["target_triple"] == declared_by_id[target_id]["target_triple"],
            f"{target_id}: target triple differs from declared target authority",
        )
        final = disposition["final_disposition"]
        require(final in TARGET_FINAL_DISPOSITIONS, f"{target_id}: invalid target disposition")
        replacements = unique_strings(
            disposition["replacement_residual_ids"],
            f"{target_id}.replacement_residual_ids",
            allow_empty=True,
        )
        require(set(replacements) <= set(residual_by_id), f"{target_id}: unknown target residual IDs")
        if final == "replaced":
            require(replacements, f"{target_id}: replaced target has no target-specific residual")
        else:
            require(not replacements, f"{target_id}: non-replaced target has replacement residuals")
        text(disposition["justification"], f"{target_id}.justification")
    require(
        set(target_by_id) == set(declared_by_id),
        "not every declared host target has an explicit disposition",
    )

    return {
        "opening_count": len(opening_ids),
        "opening_disposition_counts": Counter(
            disposition["final_disposition"] for disposition in dispositions
        ),
        "inherited_count": len(inherited_phase13_ids),
        "inherited_disposition_counts": Counter(
            disposition["final_disposition"] for disposition in inherited
        ),
        "residual_count": len(residual_rows),
        "residual_destination_counts": Counter(row["destination_phase"] for row in residual_rows),
        "residual_family_counts": Counter(row["feature_family"] for row in residual_rows),
        "target_count": len(declared_targets),
        "target_disposition_counts": Counter(
            disposition["final_disposition"] for disposition in target_dispositions
        ),
        "snapshot": snapshot,
    }


def counter_lines(counter: Counter[str]) -> list[str]:
    return [f"- `{name}`: `{counter[name]}`" for name in sorted(counter)]


def render_review() -> str:
    summary = validate()
    snapshot = summary["snapshot"]
    lines = [
        "# Cranelift Phase 14 Final Review",
        "",
        "<!-- Generated by scripts/phase14_deferred_residue.py; do not edit by hand. -->",
        "",
        "CRANELIFT_PHASE14_FINAL_REVIEW_VERSION: 1",
        f"CRANELIFT_PHASE14_DEFERRED_RESIDUE_VERSION: {snapshot['version']}",
        f"CRANELIFT_PHASE14_DEFERRED_RESIDUE_STATUS: {snapshot['status']}",
        "CRANELIFT_PHASE14_DEFERRED_RESIDUE_AUTHORITY: scripts/cranelift_feature_registry.json",
        "CRANELIFT_PHASE14_DEFERRED_RESIDUE_GUARD: guard-cranelift-phase14-deferred-residue-audit",
        "CRANELIFT_PHASE14_FINAL_CLOSURE_GUARD: guard-cranelift-phase14-close",
        "",
        "## Derived final totals",
        "",
        f"- Phase 14 opening rows: `{summary['opening_count']}`",
        f"- Inherited Phase 13 rows assigned to Phase 14: `{summary['inherited_count']}`",
        f"- Narrow future residual rows: `{summary['residual_count']}`",
        f"- Declared host targets: `{summary['target_count']}`",
        "",
        "### Opening dispositions",
        "",
        *counter_lines(summary["opening_disposition_counts"]),
        "",
        "### Inherited residual dispositions",
        "",
        *counter_lines(summary["inherited_disposition_counts"]),
        "",
        "### Future residual destinations",
        "",
        *counter_lines(summary["residual_destination_counts"]),
        "",
        "### Future residual feature families",
        "",
        *counter_lines(summary["residual_family_counts"]),
        "",
        "### Target dispositions",
        "",
        *counter_lines(summary["target_disposition_counts"]),
        "",
        "## Opening-row audit",
        "",
        "| Phase 14 row | Final disposition | Narrow replacements | Justification |",
        "|---|---|---|---|",
    ]
    for item in snapshot["opening_dispositions"]:
        replacements = ", ".join(item["replacement_residual_ids"]) or "none"
        lines.append(
            f"| `{item['source_phase14_row_id']}` | `{item['final_disposition']}` | "
            f"`{replacements}` | `{item['justification']}` |"
        )

    lines.extend([
        "",
        "## Inherited Phase 13 residue assigned to Phase 14",
        "",
        "| Inherited row | Final disposition | Selected Phase 14 rows | Narrow replacements | Destination | Justification |",
        "|---|---|---|---|---|---|",
    ])
    for item in snapshot["inherited_residual_dispositions"]:
        selected = ", ".join(item["selected_phase14_row_ids"]) or "none"
        replacements = ", ".join(item["replacement_residual_ids"]) or "none"
        lines.append(
            f"| `{item['source_phase13_residual_id']}` | `{item['final_disposition']}` | "
            f"`{selected}` | `{replacements}` | `{item['destination_phase']}` | "
            f"`{item['justification']}` |"
        )

    lines.extend([
        "",
        "## Frozen actionable future residue",
        "",
        "| Stable ID | Capability | Owner | Diagnostic owner | Destination | Failure stage | Target applicability | Phase 14 sources |",
        "|---|---|---|---|---|---|---|---|",
    ])
    for row in snapshot["rows"]:
        sources = ", ".join(row["source_phase14_row_ids"])
        lines.append(
            f"| `{row['id']}` | `{row['capability']}` | `{row['capability_owner']}` | "
            f"`{row['diagnostic_owner']}` | `{row['destination_phase']}` | "
            f"`{row['current_failure_stage']}` | `{row['target_applicability']}` | `{sources}` |"
        )

    lines.extend([
        "",
        "## Declared-target coverage",
        "",
        "| Target triple | Final disposition | Narrow target residue | Justification |",
        "|---|---|---|---|",
    ])
    for item in snapshot["target_dispositions"]:
        replacements = ", ".join(item["replacement_residual_ids"]) or "none"
        lines.append(
            f"| `{item['target_triple']}` | `{item['final_disposition']}` | "
            f"`{replacements}` | `{item['justification']}` |"
        )

    lines.extend([
        "",
        "## Semantic freeze",
        "",
        "The registry is the sole authority for final totals, row disposition, target coverage, and future residue.",
        "Future phases may change a deferred row only by versioning the Phase 14 residual snapshot and regenerating this view.",
        "",
        "The positive-future and negative-current files are stable inventory anchors for each row.",
        "They are not a substitute for the focused executable evidence that the destination phase must add before migration.",
        "",
        "The audit is static and Level 1. It does not compile Gust, run native programs, replay differential families, or execute the declared-target matrix.",
        "",
    ])
    return "\n".join(lines)


def check_review() -> None:
    expected = render_review()
    try:
        actual = REVIEW.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise Error(f"missing generated review: {REVIEW.relative_to(ROOT)}") from exc
    require(actual == expected, "generated Phase 14 final review is stale")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command",
        choices=("validate", "render", "check-review", "summary-json"),
    )
    args = parser.parse_args()
    try:
        if args.command == "validate":
            summary = validate()
            print(
                "✅ Phase 14 deferred residue audit passed: "
                f"opening={summary['opening_count']} "
                f"inherited={summary['inherited_count']} "
                f"residual={summary['residual_count']} "
                f"targets={summary['target_count']}."
            )
        elif args.command == "render":
            print(render_review(), end="")
        elif args.command == "check-review":
            check_review()
            print("✅ Phase 14 final review matches the canonical residual snapshot.")
        else:
            summary = validate()
            print(json.dumps({
                "opening": summary["opening_count"],
                "inherited": summary["inherited_count"],
                "residual": summary["residual_count"],
                "targets": summary["target_count"],
            }, sort_keys=True))
    except Error as exc:
        print(f"Phase 14 deferred residue audit error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())