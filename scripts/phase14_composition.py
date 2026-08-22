#!/usr/bin/env python3
"""Validate and project Patch 14.12 cross-feature composition ownership."""

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
HISTORICAL_WORKFLOW = ROOT / ".github/workflows/cranelift-historical-full.yml"

TARGET_POLICY = "all_declared_host_targets_from_phase14_target_authority"
CROSS_CASE_FIELD = "phase14_12_composition_cases"
CLOSURE_VERSION = "phase14_cross_feature_all_target_layout_differential_v1"

REQUIRED_COMPOSITION_TAGS = {
    "primitive_and_pointer_sized_integers",
    "signed_and_unsigned_conversions",
    "bounded_pointers",
    "deterministic_stack_slots",
    "typed_loads_and_stores",
    "strings_and_views",
    "arrays_and_slices",
    "declaration_order_structs",
    "enums_and_tagged_unions",
    "aggregate_joins_and_loop_carried_values",
    "struct_with_array_and_slice_fields",
    "enum_with_struct_or_string_view_payload",
    "array_of_structs",
    "slice_of_structs",
    "nullable_pointer_in_tagged_union",
    "aggregate_values_updated_through_branches",
}

REQUIRED_COMPARISONS = {
    "default_explicit_mir_to_c_byte_identity",
    "runtime_values",
    "stdout_stderr_when_stable",
    "exit_status",
    "semantic_layout_witnesses",
    "type_size_alignment",
    "field_offsets",
    "array_stride",
    "slice_view_field_layout",
    "enum_tag_payload_layout",
    "initialized_memory_bytes",
    "ignore_uninitialized_padding",
}


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def read_registry() -> dict:
    try:
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise Error(f"missing canonical registry: {REGISTRY.relative_to(ROOT)}") from exc
    except json.JSONDecodeError as exc:
        raise Error(
            f"invalid canonical registry JSON: {exc.lineno}:{exc.colno}: {exc.msg}"
        ) from exc
    require(isinstance(registry, dict), "canonical registry must be an object")
    return registry


def migrated_phase14_rows(registry: dict) -> list[dict]:
    rows = [
        entry
        for entry in registry.get("entries", [])
        if entry.get("origin_phase") == "phase14"
        and entry.get("status") == "migrated"
        and entry.get("route_owner") == "generic_canonical_mir"
    ]
    require(rows, "canonical registry contains no migrated Phase 14 rows")
    return rows


def phase14_families(registry: dict) -> list[str]:
    families: list[str] = []
    for entry in migrated_phase14_rows(registry):
        family = entry.get("ci_family")
        require(
            isinstance(family, str) and family,
            f"{entry.get('id', '<unknown>')}: missing Phase 14 CI family",
        )
        if family not in families:
            families.append(family)
    return families


def declared_targets(registry: dict) -> list[str]:
    authority = registry.get("phase14_primitive_layout")
    require(isinstance(authority, dict), "Phase 14 target authority is missing")
    records = authority.get("declared_targets")
    require(isinstance(records, list) and records, "declared target authority is empty")
    targets = []
    for index, record in enumerate(records):
        require(isinstance(record, dict), f"declared target {index} is not an object")
        target = record.get("target_triple")
        require(
            isinstance(target, str) and target and target not in targets,
            f"declared target {index} is missing or duplicated",
        )
        targets.append(target)
    primary = authority.get("primary_level2_target")
    require(primary in targets, "primary Level 2 target is not declared")
    return targets


def primary_target(registry: dict) -> str:
    declared_targets(registry)
    return registry["phase14_primitive_layout"]["primary_level2_target"]


def require_fixture(case_id: str, case: dict, field: str) -> None:
    value = case.get(field)
    require(isinstance(value, str) and value, f"{case_id}: missing {field}")
    path = ROOT / value
    require(
        path.is_file() and not path.is_symlink(),
        f"{case_id}: {field} is not a regular repository file: {value}",
    )


def validate_case(
    case: dict,
    *,
    migrated_ids: set[str],
    known_case_ids: set[str],
    cross_feature: bool,
) -> None:
    require(isinstance(case, dict), "composition case must be an object")
    case_id = case.get("id")
    require(
        isinstance(case_id, str) and case_id and case_id not in known_case_ids,
        f"missing or duplicate composition case ID: {case_id!r}",
    )
    known_case_ids.add(case_id)
    owner = case.get("owner_entry_id")
    require(owner in migrated_ids, f"{case_id}: unknown owner entry {owner!r}")
    family = case.get("ci_family")
    require(isinstance(family, str) and family, f"{case_id}: missing CI family")
    covers = case.get("covers_entry_ids")
    require(
        isinstance(covers, list)
        and len(covers) >= 2
        and len(covers) == len(set(covers))
        and owner in covers
        and all(entry_id in migrated_ids for entry_id in covers),
        f"{case_id}: invalid migrated-row coverage",
    )
    require_fixture(case_id, case, "source_fixture")
    require_fixture(case_id, case, "failure_fixture")
    expectation = case.get("positive_expectation")
    require(
        isinstance(expectation, str) and expectation.startswith("exit_"),
        f"{case_id}: positive expectation must declare an exit status",
    )
    require(
        case.get("stderr_policy") in {"stable_bytes", "ignored"},
        f"{case_id}: invalid stderr policy",
    )
    require(
        case.get("side_effect_policy") in {"none", "compare_tree"},
        f"{case_id}: invalid side-effect policy",
    )
    if cross_feature:
        require(
            set(covers) == migrated_ids,
            f"{case_id}: the Patch 14.12 case must cover every migrated Phase 14 row",
        )
        require(
            case.get("target_applicability") == TARGET_POLICY,
            f"{case_id}: target applicability is not registry-authority derived",
        )
        tags = case.get("composition_tags")
        require(
            isinstance(tags, list)
            and len(tags) == len(set(tags))
            and REQUIRED_COMPOSITION_TAGS.issubset(set(tags)),
            f"{case_id}: required nested composition tags are incomplete",
        )
        comparisons = case.get("comparison_contract")
        require(
            isinstance(comparisons, list)
            and len(comparisons) == len(set(comparisons))
            and REQUIRED_COMPARISONS.issubset(set(comparisons)),
            f"{case_id}: comparison contract is incomplete",
        )


def validate_registry(registry: dict) -> dict:
    rows = migrated_phase14_rows(registry)
    migrated_ids = {entry["id"] for entry in rows}
    families = phase14_families(registry)
    targets = declared_targets(registry)

    individual_ids: set[str] = set()
    row_case_ids: set[str] = set()
    row_cases: list[dict] = []
    references: dict[str, set[str]] = {}

    for entry in rows:
        entry_id = entry["id"]
        require(
            entry.get("target_applicability") == TARGET_POLICY,
            f"{entry_id}: target applicability drifted",
        )
        require_fixture(entry_id, entry, "source_fixture")
        canonical_fixture = entry.get("canonical_mir_fixture")
        require(
            isinstance(canonical_fixture, str)
            and canonical_fixture.startswith("compiler/fixtures/")
            and canonical_fixture.endswith(".mir"),
            f"{entry_id}: canonical MIR fixture ownership is missing",
        )
        differential_case_id = entry.get("differential_case_id")
        require(
            isinstance(differential_case_id, str)
            and differential_case_id
            and differential_case_id not in individual_ids,
            f"{entry_id}: missing or duplicate differential case owner",
        )
        individual_ids.add(differential_case_id)

        evidence = entry.get("evidence")
        require(isinstance(evidence, dict), f"{entry_id}: evidence must be an object")
        guard = evidence.get("individual_evidence_guard")
        require(
            isinstance(guard, str) and guard,
            f"{entry_id}: individual focused evidence guard is missing",
        )
        case_ids = evidence.get("composition_case_ids")
        require(
            isinstance(case_ids, list)
            and case_ids
            and len(case_ids) == len(set(case_ids))
            and all(isinstance(case_id, str) and case_id for case_id in case_ids),
            f"{entry_id}: composition relationship is missing or invalid",
        )
        references[entry_id] = set(case_ids)
        owned_cases = evidence.get("composition_cases", [])
        require(isinstance(owned_cases, list), f"{entry_id}: composition cases must be an array")
        for case in owned_cases:
            validate_case(
                case,
                migrated_ids=migrated_ids,
                known_case_ids=row_case_ids,
                cross_feature=False,
            )
            require(
                case.get("owner_entry_id") == entry_id,
                f"{case.get('id', '<unknown>')}: owner entry mismatch",
            )
            row_cases.append(case)

    row_case_by_id = {case["id"]: case for case in row_cases}
    for entry_id, case_ids in references.items():
        for case_id in case_ids:
            require(case_id in row_case_by_id, f"{entry_id}: unknown composition case {case_id}")
            require(
                entry_id in row_case_by_id[case_id]["covers_entry_ids"],
                f"{entry_id}: composition case {case_id} does not cover the row",
            )

    for case_id, case in row_case_by_id.items():
        referrers = {
            entry_id
            for entry_id, case_ids in references.items()
            if case_id in case_ids
        }
        require(
            referrers == set(case["covers_entry_ids"]),
            f"{case_id}: row references differ from declared coverage",
        )

    row_case_families = {case["ci_family"] for case in row_cases}
    require(
        row_case_families == set(families),
        "active Phase 14 families lack registry-owned composition cases: "
        f"missing={sorted(set(families) - row_case_families)} "
        f"extra={sorted(row_case_families - set(families))}",
    )

    cross_cases: list[dict] = []
    all_case_ids = set(row_case_ids)
    for entry in rows:
        evidence = entry["evidence"]
        cases = evidence.get(CROSS_CASE_FIELD, [])
        require(
            isinstance(cases, list),
            f"{entry['id']}.{CROSS_CASE_FIELD} must be an array",
        )
        for case in cases:
            validate_case(
                case,
                migrated_ids=migrated_ids,
                known_case_ids=all_case_ids,
                cross_feature=True,
            )
            require(
                case.get("owner_entry_id") == entry["id"],
                f"{case.get('id', '<unknown>')}: Patch 14.12 owner mismatch",
            )
            cross_cases.append(case)

    require(cross_cases, "registry contains no Patch 14.12 cross-feature case")
    require(
        any(case.get("closure_version") == CLOSURE_VERSION for case in cross_cases),
        "Patch 14.12 closure version is missing",
    )

    return {
        "row_count": len(rows),
        "family_count": len(families),
        "case_count": len(row_cases),
        "cross_case_count": len(cross_cases),
        "target_count": len(targets),
        "families": families,
        "targets": targets,
    }


def check_historical_workflow(registry: dict, path: Path) -> None:
    validate_registry(registry)
    text = path.read_text(encoding="utf-8")
    required_tokens = (
        "phase14_targets:",
        'matrix=$(python3 scripts/phase14_composition.py target-matrix-json)',
        "target: ${{ fromJSON(needs.inventory.outputs.phase14_targets) }}",
        'PHASE14_TARGET="${{ matrix.target }}"',
        "just guard-cranelift-phase14-all-target-composition",
        "needs: [historical-shard, phase14-target]",
    )
    for token in required_tokens:
        require(token in text, f"{path.relative_to(ROOT)} is missing {token!r}")
    for target in declared_targets(registry):
        require(
            target not in text,
            f"{path.relative_to(ROOT)} manually lists declared target {target}",
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command",
        choices=(
            "validate",
            "families",
            "targets",
            "primary-target",
            "target-matrix-json",
            "validate-family",
            "validate-target",
            "check-historical-workflow",
        ),
    )
    parser.add_argument("value", nargs="?")
    args = parser.parse_args()

    try:
        registry = read_registry()
        summary = validate_registry(registry)

        if args.command == "validate":
            print(
                "✅ Phase 14.12 composition inventory passed: "
                f"rows={summary['row_count']} families={summary['family_count']} "
                f"composition_cases={summary['case_count']} "
                f"cross_feature_cases={summary['cross_case_count']} "
                f"targets={summary['target_count']}."
            )
        elif args.command == "families":
            print("\n".join(summary["families"]))
        elif args.command == "targets":
            print("\n".join(summary["targets"]))
        elif args.command == "primary-target":
            print(primary_target(registry))
        elif args.command == "target-matrix-json":
            print(json.dumps(summary["targets"], separators=(",", ":")))
        elif args.command == "validate-family":
            require(args.value is not None, "validate-family requires a family")
            require(
                args.value in summary["families"],
                f"not a migrated Phase 14 family: {args.value}",
            )
            print(f"✅ Migrated Phase 14 family: {args.value}")
        elif args.command == "validate-target":
            require(args.value is not None, "validate-target requires a target")
            require(
                args.value in summary["targets"],
                f"not a declared Phase 14 target: {args.value}",
            )
            print(f"✅ Declared Phase 14 target: {args.value}")
        elif args.command == "check-historical-workflow":
            workflow = ROOT / args.value if args.value else HISTORICAL_WORKFLOW
            check_historical_workflow(registry, workflow)
            print("✅ Cranelift Historical Full target matrix is registry-derived.")
    except (Error, OSError) as exc:
        print(f"phase14 composition error: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
