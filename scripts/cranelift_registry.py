#!/usr/bin/env python3
"""Validate and project the canonical Cranelift feature registry."""

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
SCHEMA = ROOT / "scripts/cranelift_feature_registry.schema.json"
DEFERRED = {"deferred", "inherited_deferred", "candidate_deferred"}
AMBIGUOUS = {"", "unknown", "tbd", "ownerless", "ambiguous"}

TOP_FIELDS = {
    "schema", "schema_version", "registry_version", "registry_status",
    "current_phase", "closed_phase_versions", "closure_snapshots",
    "planning_categories", "supported_values", "legacy_views", "entries",
}
ENTRY_FIELDS = {
    "id", "origin_phase", "parent", "feature_family", "ci_family", "status",
    "route_owner", "worker_capability_owner", "diagnostic_owner",
    "source_fixture", "canonical_mir_fixture", "differential_case_id",
    "deferral_reason", "future_destination_phase", "closure_version", "evidence",
}
SUPPORTED_FIELDS = {
    "statuses", "origin_phases", "feature_families", "ci_families",
    "route_owners", "worker_capability_owners", "diagnostic_owners",
}
PHASE11_SNAPSHOT_FIELDS = {
    "closure_version", "immutable_fields", "entry_count",
    "classification_counts", "deferred_entry_ids", "entries",
    "byte_provenance", "comparison_policy",
}
PHASE11_SNAPSHOT_ENTRY_FIELDS = {
    "id", "classification", "feature_family", "route_owner",
    "source_fixture", "canonical_mir_fixture", "ci_family",
}
PHASE11_IMMUTABLE_FIELDS = (
    "id", "classification", "feature_family", "route_owner",
    "source_fixture", "canonical_mir_fixture", "ci_family",
)
PHASE11_CLASSIFICATION_COUNTS = {
    "migrated": 12,
    "deferred": 7,
    "excluded": 0,
}
PHASE11_DEFERRED_IDS = (
    "resource_metadata",
    "native_boundary_metadata",
    "block_param_merge_imported_call_return",
    "block_param_merge_arm_update_imported_call_return",
    "block_param_merge_arm_update_imported_call_branch",
    "block_param_merge_imported_branch_joined_return",
    "block_param_merge_dual_imported_joined_return",
)


class Error(RuntimeError):
    pass


def require(condition, message):
    if not condition:
        raise Error(message)


def read_json(path):
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise Error(f"missing file: {path.relative_to(ROOT)}") from exc
    except json.JSONDecodeError as exc:
        raise Error(
            f"invalid JSON in {path.relative_to(ROOT)}:"
            f"{exc.lineno}:{exc.colno}: {exc.msg}"
        ) from exc
    require(isinstance(value, dict), f"{path.relative_to(ROOT)} must be an object")
    return value


def text(value, context):
    require(isinstance(value, str), f"{context} must be a string")
    require(value.strip().lower() not in AMBIGUOUS, f"{context} is blank or ambiguous")
    return value


def unique_strings(value, context):
    require(isinstance(value, list), f"{context} must be an array")
    result = [text(item, f"{context}[{index}]") for index, item in enumerate(value)]
    require(len(result) == len(set(result)), f"{context} contains duplicates")
    return result


def fixture(value, context):
    value = text(value, context)
    if value == "none" or value.startswith("none_"):
        return
    require((ROOT / value).is_file(), f"{context} points to missing file: {value}")


def parse_record(line, prefix):
    fields = {}
    for segment in line[len(prefix):].split("|"):
        if not segment:
            continue
        require("=" in segment, f"invalid legacy segment: {segment}")
        key, value = segment.split("=", 1)
        require(key not in fields, f"legacy record repeats {key}")
        fields[key] = value
    return fields


def legacy_records(path, prefix):
    require(path.is_file(), f"missing legacy view: {path.relative_to(ROOT)}")
    return [
        parse_record(line, prefix)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.startswith(prefix)
    ]


def validate_phase11_snapshot_structure(registry):
    snapshots = registry["closure_snapshots"]
    require(
        isinstance(snapshots, dict) and set(snapshots) == {"phase11"},
        "closure_snapshots must contain exactly phase11",
    )
    snapshot = snapshots["phase11"]
    require(
        isinstance(snapshot, dict) and set(snapshot) == PHASE11_SNAPSHOT_FIELDS,
        "Phase 11 closure snapshot fields drifted",
    )
    require(
        snapshot["closure_version"] == registry["closed_phase_versions"]["phase11"],
        "Phase 11 closure snapshot version differs from closed_phase_versions",
    )
    require(
        snapshot["immutable_fields"] == list(PHASE11_IMMUTABLE_FIELDS),
        "Phase 11 immutable-field set drifted",
    )
    require(snapshot["entry_count"] == 19,
            "Phase 11 closure snapshot entry_count must be 19")
    require(
        snapshot["classification_counts"] == PHASE11_CLASSIFICATION_COUNTS,
        "Phase 11 closure snapshot classification totals drifted",
    )
    require(
        unique_strings(
            snapshot["deferred_entry_ids"],
            "closure_snapshots.phase11.deferred_entry_ids",
        ) == list(PHASE11_DEFERRED_IDS),
        "Phase 11 deferred entry IDs drifted",
    )
    require(snapshot["byte_provenance"] == "git_history",
            "Phase 11 byte provenance must be Git history")
    require(
        snapshot["comparison_policy"]
        == "semantic_fields_only_whitespace_prose_field_order_and_generated_layout_are_ignored",
        "Phase 11 semantic comparison policy drifted",
    )

    rows = snapshot["entries"]
    require(isinstance(rows, list) and len(rows) == 19,
            "Phase 11 closure snapshot must contain 19 rows")
    ids = set()
    for index, row in enumerate(rows):
        context = f"closure_snapshots.phase11.entries[{index}]"
        require(
            isinstance(row, dict) and set(row) == PHASE11_SNAPSHOT_ENTRY_FIELDS,
            f"{context} fields drifted",
        )
        entry_id = text(row["id"], f"{context}.id")
        require(entry_id not in ids, f"duplicate Phase 11 snapshot ID: {entry_id}")
        ids.add(entry_id)
        require(
            row["classification"] in PHASE11_CLASSIFICATION_COUNTS,
            f"{entry_id}: unknown snapshot classification {row['classification']}",
        )
        for field in (
            "feature_family", "route_owner", "source_fixture",
            "canonical_mir_fixture", "ci_family",
        ):
            text(row[field], f"{context}.{field}")
        fixture(row["source_fixture"], f"{context}.source_fixture")
        fixture(row["canonical_mir_fixture"],
                f"{context}.canonical_mir_fixture")

    return snapshot

def validate():
    registry = read_json(REGISTRY)
    schema = read_json(SCHEMA)

    require(set(registry) == TOP_FIELDS, "registry top-level fields drifted")
    require(
        schema.get("$schema") == "https://json-schema.org/draft/2020-12/schema",
        "schema must use JSON Schema draft 2020-12",
    )
    require(schema.get("$id") == registry["schema"], "schema path and $id differ")
    require(set(schema.get("required", [])) == TOP_FIELDS,
            "schema top-level required fields drifted")
    entry_schema = schema.get("$defs", {}).get("entry", {})
    require(set(entry_schema.get("required", [])) == ENTRY_FIELDS,
            "schema entry required fields drifted")
    require(entry_schema.get("additionalProperties") is False,
            "schema entries must reject unknown fields")

    require(registry["schema"] == "scripts/cranelift_feature_registry.schema.json",
            "registry schema path is not canonical")
    require(registry["schema_version"] == 1, "schema_version must be 1")
    require(registry["registry_version"] == 1, "registry_version must be 1")
    require(
        registry["registry_status"] == "phase12_5_canonical_machine_readable_registry",
        "registry status is missing or stale",
    )
    require(registry["current_phase"] == "phase12.5", "current_phase must be phase12.5")
    require(
        registry["closed_phase_versions"] == {
            "phase11": "phase11_closed_registry_backed_feature_parity_migration",
            "phase12_5_opening": "phase12_5_opened_verification_framework_consolidation",
        },
        "closed phase versions drifted",
    )
    validate_phase11_snapshot_structure(registry)

    categories = set(unique_strings(registry["planning_categories"], "planning_categories"))
    supported = registry["supported_values"]
    require(isinstance(supported, dict) and set(supported) == SUPPORTED_FIELDS,
            "supported_values fields drifted")
    allowed = {
        key: set(unique_strings(value, f"supported_values.{key}"))
        for key, value in supported.items()
    }
    require(
        set(registry["legacy_views"]) == {"phase11", "phase13", "generated_summary"},
        "legacy_views fields drifted",
    )
    for key, value in registry["legacy_views"].items():
        text(value, f"legacy_views.{key}")

    entries = registry["entries"]
    require(isinstance(entries, list) and len(entries) == 35,
            f"registry must contain 35 entries, found {len(entries) if isinstance(entries, list) else 'non-array'}")

    ids = set()
    phase11 = []
    phase13 = []
    for index, entry in enumerate(entries):
        context = f"entries[{index}]"
        require(isinstance(entry, dict) and set(entry) == ENTRY_FIELDS,
                f"{context} fields drifted")
        entry_id = text(entry["id"], f"{context}.id")
        require(all(ch.isalnum() or ch == "_" for ch in entry_id),
                f"{entry_id}: unsupported ID characters")
        require(entry_id not in ids, f"duplicate ID: {entry_id}")
        ids.add(entry_id)

        checks = (
            ("origin_phase", "origin_phases"),
            ("feature_family", "feature_families"),
            ("ci_family", "ci_families"),
            ("status", "statuses"),
            ("route_owner", "route_owners"),
            ("worker_capability_owner", "worker_capability_owners"),
            ("diagnostic_owner", "diagnostic_owners"),
        )
        for field, allowed_field in checks:
            value = text(entry[field], f"{entry_id}.{field}")
            require(value in allowed[allowed_field],
                    f"{entry_id}: unknown {field} {value}")

        parent = text(entry["parent"], f"{entry_id}.parent")
        fixture(entry["source_fixture"], f"{entry_id}.source_fixture")
        fixture(entry["canonical_mir_fixture"], f"{entry_id}.canonical_mir_fixture")
        require(text(entry["differential_case_id"], f"{entry_id}.differential_case_id").count(":") == 1,
                f"{entry_id}: differential_case_id must be namespace:id")
        reason = text(entry["deferral_reason"], f"{entry_id}.deferral_reason")
        destination = text(entry["future_destination_phase"],
                           f"{entry_id}.future_destination_phase")
        closure = text(entry["closure_version"], f"{entry_id}.closure_version")
        require(isinstance(entry["evidence"], dict), f"{entry_id}.evidence must be an object")

        status = entry["status"]
        if status in DEFERRED:
            require(entry["route_owner"] == "deferred",
                    f"{entry_id}: deferred status requires route_owner=deferred")
            require(not reason.startswith("none_"),
                    f"{entry_id}: deferred status requires a reason")
            require(not destination.startswith("none_"),
                    f"{entry_id}: deferred status requires a future phase")
        elif status == "migrated":
            require(entry["route_owner"] == "generic_canonical_mir",
                    f"{entry_id}: migrated status requires generic canonical MIR")
            require(reason == destination == "none_migrated",
                    f"{entry_id}: migrated entry has stale deferral fields")
        elif status == "excluded":
            require(entry["route_owner"] == "excluded",
                    f"{entry_id}: excluded status requires route_owner=excluded")

        if entry["origin_phase"] == "phase11":
            require(parent == "phase11_root:feature_inventory",
                    f"{entry_id}: invalid Phase 11 parent")
            require(closure == "phase11_closed_registry_backed_feature_parity_migration",
                    f"{entry_id}: Phase 11 closure version drifted")
            phase11.append(entry)
        else:
            require(closure == "phase13_opening_inventory_v1",
                    f"{entry_id}: Phase 13 closure version drifted")
            phase13.append(entry)

    phase11_by_id = {entry["id"]: entry for entry in phase11}
    for entry in phase13:
        parent = entry["parent"]
        if parent.startswith("phase11_entry:"):
            parent_id = parent.split(":", 1)[1]
            require(parent_id in phase11_by_id, f"{entry['id']}: missing parent {parent_id}")
            require(phase11_by_id[parent_id]["status"] == "deferred",
                    f"{entry['id']}: inherited parent is not deferred")
            require(entry["status"] == "inherited_deferred",
                    f"{entry['id']}: entry parent requires inherited_deferred")
        elif parent.startswith("phase11_category:"):
            category = parent.split(":", 1)[1]
            require(category in categories, f"{entry['id']}: unknown category {category}")
            require(entry["status"] == "candidate_deferred",
                    f"{entry['id']}: category parent requires candidate_deferred")
        else:
            raise Error(f"{entry['id']}: invalid parent {parent}")

    require(Counter(entry["origin_phase"] for entry in entries)
            == Counter({"phase11": 19, "phase13": 16}),
            "origin phase totals drifted")
    require(Counter(entry["status"] for entry in phase11)
            == Counter({"migrated": 12, "deferred": 7}),
            "Phase 11 status totals drifted")
    require(Counter(entry["status"] for entry in phase13)
            == Counter({"inherited_deferred": 7, "candidate_deferred": 9}),
            "Phase 13 status totals drifted")
    return registry


def verify_legacy_import(registry):
    views = registry["legacy_views"]
    p11 = legacy_records(ROOT / views["phase11"], "parity_entry: ")
    p13 = legacy_records(ROOT / views["phase13"], "phase13_entry: ")
    require(len(p11) == 19 and len(p13) == 16,
            f"legacy row totals drifted: phase11={len(p11)} phase13={len(p13)}")
    entries = {entry["id"]: entry for entry in registry["entries"]}

    json_p11 = {entry["id"] for entry in registry["entries"]
                if entry["origin_phase"] == "phase11"}
    require({row["id"] for row in p11} == json_p11,
            "Phase 11 stable IDs differ from the historical view")
    for row in p11:
        entry = entries[row["id"]]
        expected = {
            "feature_family": row["family"],
            "source_fixture": row["source_fixture"],
            "canonical_mir_fixture": row["mir_fixture"],
            "route_owner": row["route_owner"],
            "ci_family": row["ci_family"],
            "status": "deferred" if row["migration_status"] == "deferred" else "migrated",
        }
        for field, value in expected.items():
            require(entry[field] == value,
                    f"Phase 11 {row['id']} {field} differs from historical view")

    json_p13 = {entry["id"] for entry in registry["entries"]
                if entry["origin_phase"] == "phase13"}
    require({row["id"] for row in p13} == json_p13,
            "Phase 13 stable IDs differ from the historical view")
    fields = (
        "parent", "feature_family", "source_fixture", "canonical_mir_fixture",
        "route_owner", "worker_capability_owner", "diagnostic_owner",
        "ci_family", "status", "deferral_reason",
    )
    for row in p13:
        entry = entries[row["id"]]
        for field in fields:
            require(entry[field] == row[field],
                    f"Phase 13 {row['id']} {field} differs from historical view")


def verify_phase11_closure(registry):
    snapshot = validate_phase11_snapshot_structure(registry)
    current = [
        entry for entry in registry["entries"]
        if entry["origin_phase"] == "phase11"
    ]
    current_by_id = {entry["id"]: entry for entry in current}
    snapshot_by_id = {entry["id"]: entry for entry in snapshot["entries"]}

    require(len(current) == snapshot["entry_count"] == 19,
            "Phase 11 semantic closure must contain 19 current and frozen rows")
    require(set(current_by_id) == set(snapshot_by_id),
            "Phase 11 stable ID inventory differs from the semantic snapshot")

    field_map = {
        "id": "id",
        "classification": "status",
        "feature_family": "feature_family",
        "route_owner": "route_owner",
        "source_fixture": "source_fixture",
        "canonical_mir_fixture": "canonical_mir_fixture",
        "ci_family": "ci_family",
    }
    for entry_id, frozen in snapshot_by_id.items():
        live = current_by_id[entry_id]
        for frozen_field, live_field in field_map.items():
            require(
                frozen[frozen_field] == live[live_field],
                f"Phase 11 {entry_id} changed immutable field "
                f"{frozen_field}: frozen={frozen[frozen_field]!r} "
                f"current={live[live_field]!r}",
            )
        require(
            live["closure_version"] == snapshot["closure_version"],
            f"Phase 11 {entry_id} closure version drifted",
        )

    counts = Counter(entry["status"] for entry in current)
    actual_counts = {
        "migrated": counts["migrated"],
        "deferred": counts["deferred"],
        "excluded": counts["excluded"],
    }
    require(
        actual_counts == snapshot["classification_counts"]
        == PHASE11_CLASSIFICATION_COUNTS,
        "Phase 11 12/7/0 classification inventory drifted",
    )
    actual_deferred = [
        entry["id"] for entry in current if entry["status"] == "deferred"
    ]
    require(
        actual_deferred == snapshot["deferred_entry_ids"]
        == list(PHASE11_DEFERRED_IDS),
        "Phase 11 deferred parent ID inventory drifted",
    )


def cell(value):
    return str(value).replace("|", r"\|").replace("\n", " ")


def render(registry):
    entries = registry["entries"]
    phase = Counter(entry["origin_phase"] for entry in entries)
    status = Counter(entry["status"] for entry in entries)
    feature = Counter(entry["feature_family"] for entry in entries)
    ci = Counter(entry["ci_family"] for entry in entries)
    lines = [
        "# Canonical Cranelift Feature Registry", "",
        "<!-- Generated by scripts/cranelift_registry.py; do not edit by hand. -->", "",
        f"- Schema version: `{registry['schema_version']}`",
        f"- Registry version: `{registry['registry_version']}`",
        f"- Registry status: `{registry['registry_status']}`",
        f"- Entries: `{len(entries)}`",
        f"- Phase 11 entries: `{phase['phase11']}`",
        f"- Phase 13 entries: `{phase['phase13']}`", "",
        "## Derived status totals", "",
    ]
    lines += [f"- `{key}`: `{status[key]}`" for key in sorted(status)]
    lines += ["", "## Derived feature-family totals", ""]
    lines += [f"- `{key}`: `{feature[key]}`" for key in sorted(feature)]
    lines += ["", "## Derived CI-family totals", ""]
    lines += [f"- `{key}`: `{ci[key]}`" for key in sorted(ci)]
    lines += [
        "", "## Registry entries", "",
        "| ID | Origin | Parent | Feature family | CI family | Status | Route owner | Worker owner | Diagnostic owner | Source fixture | Canonical MIR fixture | Differential case | Future phase | Deferral reason | Closure version |",
        "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    fields = (
        "id", "origin_phase", "parent", "feature_family", "ci_family", "status",
        "route_owner", "worker_capability_owner", "diagnostic_owner",
        "source_fixture", "canonical_mir_fixture", "differential_case_id",
        "future_destination_phase", "deferral_reason", "closure_version",
    )
    for entry in entries:
        lines.append("| " + " | ".join(cell(entry[field]) for field in fields) + " |")
    lines += [
        "", "## Legacy views", "",
        f"- Phase 11 historical view: `{registry['legacy_views']['phase11']}`",
        f"- Phase 13 historical view: `{registry['legacy_views']['phase13']}`", "",
        "The JSON registry is authoritative. These Markdown documents remain review and historical views only.", "",
    ]
    return "\n".join(lines)


def summary_path(registry):
    return ROOT / registry["legacy_views"]["generated_summary"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command",
        choices=(
            "validate",
            "verify-legacy-import",
            "verify-phase11-closure",
            "project",
            "check-projection",
        ),
    )
    command = parser.parse_args().command
    try:
        registry = validate()
        if command == "verify-legacy-import":
            verify_legacy_import(registry)
        elif command == "verify-phase11-closure":
            verify_phase11_closure(registry)
        elif command == "project":
            path = summary_path(registry)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(render(registry), encoding="utf-8")
        elif command == "check-projection":
            path = summary_path(registry)
            require(path.is_file(), f"missing generated summary: {path.relative_to(ROOT)}")
            require(path.read_text(encoding="utf-8") == render(registry),
                    "generated summary is stale; run `python3 scripts/cranelift_registry.py project`")
    except Error as exc:
        print(f"cranelift registry error: {exc}", file=sys.stderr)
        return 1

    messages = {
        "validate": "✅ Canonical Cranelift registry schema passed: 35 unique entries.",
        "verify-legacy-import": "✅ Canonical registry preserves all 19 Phase 11 and 16 Phase 13 legacy rows.",
        "verify-phase11-closure": "✅ Phase 11 semantic closure snapshot passed: 19 rows, 12 migrated, seven deferred, zero excluded.",
        "project": "✅ Canonical Cranelift registry Markdown summary generated.",
        "check-projection": "✅ Canonical Cranelift registry Markdown summary is current.",
    }
    print(messages[command])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
