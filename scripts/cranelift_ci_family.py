#!/usr/bin/env python3
"""Project and run registry-derived Cranelift CI families."""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"

# This is the single active runner mapping. The stable family set is derived
# from Phase 11 rows plus newly migrated Phase 14 families. Migrated Phase 13
# rows continue to join their inherited families without creating workflow rows.
#
# The optional post-focused guard belongs to the evidence route for that family.
# Phase 11/13 families use the generic Phase 13 source differential after their
# focused guard. Phase 14 families own dedicated request/witness differentials
# for individual positive and negative semantic evidence and must not be
# rerouted through the Phase 13 generic source-to-MIR registry harness. Patch
# 14.12 adds a composition-only route-sentinel differential after each focused
# Phase 14 family while preserving the focused semantic witness as the layout
# and behavior authority.
RUNNERS = (
    (
        "scalars",
        "guard-cranelift-phase13-scalar-expression-parity",
        "PHASE13_SCALAR_EXPRESSION_SKIP_DYNAMIC",
        "guard-cranelift-phase13-composition-differential",
    ),
    (
        "locals",
        "guard-cranelift-phase13-multiple-locals-assignments-parity",
        "PHASE13_MULTIPLE_LOCALS_SKIP_DYNAMIC",
        "guard-cranelift-phase13-composition-differential",
    ),
    (
        "cfg",
        "guard-cranelift-phase13-nested-structured-cfg-parity",
        "PHASE13_NESTED_STRUCTURED_CFG_SKIP_DYNAMIC",
        "guard-cranelift-phase13-composition-differential",
    ),
    (
        "block-params",
        "guard-cranelift-phase13-general-loop-parity",
        "PHASE13_GENERAL_LOOP_SKIP_DYNAMIC",
        "guard-cranelift-phase13-composition-differential",
    ),
    (
        "direct-calls",
        "guard-cranelift-phase13-direct-call-graph-parity",
        "PHASE13_DIRECT_CALL_GRAPH_SKIP_DYNAMIC",
        "guard-cranelift-phase13-composition-differential",
    ),
    (
        "imports",
        "guard-cranelift-phase13-broader-imported-runtime-calls-parity",
        "PHASE13_BROADER_IMPORTED_RUNTIME_CALLS_SKIP_DYNAMIC",
        "guard-cranelift-phase13-composition-differential",
    ),
    (
        "metadata-diagnostics",
        "guard-cranelift-phase13-source-metadata-parity",
        "PHASE13_SOURCE_METADATA_SKIP_DYNAMIC",
        "guard-cranelift-phase13-composition-differential",
    ),
    (
        "primitive-layout",
        "guard-cranelift-phase14-primitive-layout-parity",
        "PHASE14_PRIMITIVE_LAYOUT_SKIP_DYNAMIC",
        "guard-cranelift-phase14-composition-differential",
    ),
    (
        "conversions",
        "guard-cranelift-phase14-integer-conversion-parity",
        "PHASE14_INTEGER_CONVERSION_SKIP_DYNAMIC",
        "guard-cranelift-phase14-composition-differential",
    ),
    (
        "pointer-memory",
        "guard-cranelift-phase14-pointer-memory-parity",
        "PHASE14_POINTER_MEMORY_SKIP_DYNAMIC",
        "guard-cranelift-phase14-composition-differential",
    ),
    (
        "strings-views",
        "guard-cranelift-phase14-string-view-parity",
        "PHASE14_STRING_VIEW_SKIP_DYNAMIC",
        "guard-cranelift-phase14-composition-differential",
    ),
    (
        "arrays-slices",
        "guard-cranelift-phase14-array-slice-parity",
        "PHASE14_ARRAY_SLICE_SKIP_DYNAMIC",
        "guard-cranelift-phase14-composition-differential",
    ),
    (
        "structs-enums",
        "guard-cranelift-phase14-structs-enums-parity",
        "PHASE14_STRUCTS_ENUMS_SKIP_DYNAMIC",
        "guard-cranelift-phase14-composition-differential",
    ),
    (
        "aggregate-flow",
        "guard-cranelift-phase14-aggregate-parity",
        "PHASE14_AGGREGATE_SKIP_DYNAMIC",
        "guard-cranelift-phase14-composition-differential",
    ),
)
RUNNER_BY_FAMILY = {
    family: {
        "static_guard": static_guard,
        "skip_dynamic_env": skip_dynamic_env,
        "post_focused_guard": post_focused_guard,
    }
    for family, static_guard, skip_dynamic_env, post_focused_guard in RUNNERS
}


class Error(RuntimeError):
    pass


def require(condition, message):
    if not condition:
        raise Error(message)


def read_registry():
    try:
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise Error(f"missing canonical registry: {REGISTRY.relative_to(ROOT)}") from exc
    except json.JSONDecodeError as exc:
        raise Error(
            f"invalid canonical registry JSON: {exc.lineno}:{exc.colno}: {exc.msg}"
        ) from exc
    require(isinstance(registry, dict), "canonical registry must be a JSON object")
    entries = registry.get("entries")
    require(isinstance(entries, list) and entries, "canonical registry entries are missing")
    return registry


def phase11_rows(registry):
    rows = [
        entry
        for entry in registry["entries"]
        if entry.get("origin_phase") == "phase11"
    ]
    require(rows, "canonical registry contains no Phase 11 rows")
    return rows


def migrated_phase13_rows(registry):
    return [
        entry
        for entry in registry["entries"]
        if entry.get("origin_phase") == "phase13"
        and entry.get("status") == "migrated"
        and entry.get("route_owner") == "generic_canonical_mir"
        and entry.get("capability_decision") == "supported"
    ]


def migrated_phase14_rows(registry):
    return [
        entry
        for entry in registry["entries"]
        if entry.get("origin_phase") == "phase14"
        and entry.get("status") == "migrated"
        and entry.get("route_owner") == "generic_canonical_mir"
    ]


def differential_registry_rows(registry):
    return (
        phase11_rows(registry)
        + migrated_phase13_rows(registry)
        + migrated_phase14_rows(registry)
    )


def active_family_set(registry):
    families = set()
    for entry in phase11_rows(registry) + migrated_phase14_rows(registry):
        family = entry.get("ci_family")
        require(
            isinstance(family, str) and family,
            f"{entry.get('id', '<unknown>')}: active ci_family is missing",
        )
        families.add(family)
    return families


def ordered_active_families(registry):
    active = active_family_set(registry)
    mapped = set(RUNNER_BY_FAMILY)
    require(
        active == mapped,
        "Registry-derived CI family projection differs from the runner mapping: "
        f"registry_only={sorted(active - mapped)} mapping_only={sorted(mapped - active)}",
    )
    return [family for family, _, _, _ in RUNNERS]


def selected_rows(registry, family, migrated_only=False):
    rows = differential_registry_rows(registry)
    if family != "all":
        validate_family(registry, family)
        rows = [entry for entry in rows if entry["ci_family"] == family]
    if migrated_only:
        rows = [
            entry
            for entry in rows
            if entry.get("status") == "migrated"
            and entry.get("route_owner") == "generic_canonical_mir"
        ]
    require(rows, f"Cranelift CI family {family!r} selects no registry rows")
    return rows


def migrated_differential_rows(registry):
    return [
        entry
        for entry in differential_registry_rows(registry)
        if entry.get("status") == "migrated"
        and entry.get("route_owner") == "generic_canonical_mir"
    ]


def composition_case_records(registry):
    migrated = migrated_differential_rows(registry)
    migrated_ids = {entry["id"] for entry in migrated}
    cases = []
    case_by_id = {}
    references = {}

    for entry in migrated:
        evidence = entry.get("evidence")
        require(isinstance(evidence, dict), f"{entry['id']}.evidence must be an object")
        case_ids = evidence.get("composition_case_ids")
        require(
            isinstance(case_ids, list) and case_ids,
            f"{entry['id']}: migrated row has no composition relationship",
        )
        require(
            len(case_ids) == len(set(case_ids))
            and all(isinstance(case_id, str) and case_id for case_id in case_ids),
            f"{entry['id']}: invalid composition case references",
        )
        references[entry["id"]] = set(case_ids)

        owned = evidence.get("composition_cases", [])
        require(
            isinstance(owned, list),
            f"{entry['id']}.evidence.composition_cases must be an array",
        )
        for case in owned:
            require(isinstance(case, dict), f"{entry['id']}: invalid composition case")
            case_id = case.get("id")
            require(
                isinstance(case_id, str) and case_id and case_id not in case_by_id,
                f"{entry['id']}: duplicate or missing composition case ID",
            )
            require(
                case.get("owner_entry_id") == entry["id"],
                f"{case_id}: composition owner mismatch",
            )
            covers = case.get("covers_entry_ids")
            require(
                isinstance(covers, list)
                and len(covers) >= 2
                and len(covers) == len(set(covers)),
                f"{case_id}: composition coverage must contain unique migrated rows",
            )
            require(
                entry["id"] in covers and all(item in migrated_ids for item in covers),
                f"{case_id}: composition coverage contains an unknown row",
            )
            for fixture_field in ("source_fixture", "failure_fixture"):
                fixture_path = case.get(fixture_field)
                require(
                    isinstance(fixture_path, str)
                    and fixture_path
                    and (ROOT / fixture_path).is_file(),
                    f"{case_id}: missing {fixture_field}",
                )
            require(
                isinstance(case.get("positive_expectation"), str)
                and case["positive_expectation"].startswith("exit_"),
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
            case_by_id[case_id] = case
            cases.append(case)

    for entry_id, case_ids in references.items():
        for case_id in case_ids:
            require(case_id in case_by_id, f"{entry_id}: unknown composition case {case_id}")
            require(
                entry_id in case_by_id[case_id]["covers_entry_ids"],
                f"{entry_id}: composition case {case_id} does not cover the row",
            )

    for case_id, case in case_by_id.items():
        referrers = {
            entry_id
            for entry_id, case_ids in references.items()
            if case_id in case_ids
        }
        require(
            referrers == set(case["covers_entry_ids"]),
            f"{case_id}: composition references differ from covers_entry_ids",
        )

    phase14_ids = {entry["id"] for entry in migrated_phase14_rows(registry)}
    for entry in migrated_phase14_rows(registry):
        evidence = entry.get("evidence")
        require(isinstance(evidence, dict), f"{entry['id']}.evidence must be an object")
        cross_cases = evidence.get("phase14_12_composition_cases", [])
        require(
            isinstance(cross_cases, list),
            f"{entry['id']}.evidence.phase14_12_composition_cases must be an array",
        )
        for case in cross_cases:
            require(isinstance(case, dict), f"{entry['id']}: invalid Patch 14.12 case")
            case_id = case.get("id")
            require(
                isinstance(case_id, str) and case_id and case_id not in case_by_id,
                f"{entry['id']}: duplicate or missing Patch 14.12 case ID",
            )
            require(
                case.get("owner_entry_id") == entry["id"],
                f"{case_id}: Patch 14.12 composition owner mismatch",
            )
            covers = case.get("covers_entry_ids")
            require(
                isinstance(covers, list)
                and len(covers) == len(set(covers))
                and set(covers) == phase14_ids,
                f"{case_id}: Patch 14.12 coverage must equal migrated Phase 14 rows",
            )
            for fixture_field in ("source_fixture", "failure_fixture"):
                fixture_path = case.get(fixture_field)
                require(
                    isinstance(fixture_path, str)
                    and fixture_path
                    and (ROOT / fixture_path).is_file(),
                    f"{case_id}: missing {fixture_field}",
                )
            require(
                isinstance(case.get("positive_expectation"), str)
                and case["positive_expectation"].startswith("exit_"),
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
            case_by_id[case_id] = case
            cases.append(case)
    return cases


def validate_registry_projection(registry):
    families = ordered_active_families(registry)
    active = set(families)

    for entry in registry["entries"]:
        family = entry.get("ci_family")
        if entry.get("origin_phase") == "phase14":
            if entry.get("status") == "migrated":
                require(
                    entry.get("route_owner") == "generic_canonical_mir"
                    and family in active,
                    f"{entry.get('id', '<unknown>')}: migrated Phase 14 family is not active",
                )
            else:
                require(
                    entry.get("status") == "candidate_deferred"
                    and entry.get("route_owner") == "deferred",
                    f"{entry.get('id', '<unknown>')}: deferred Phase 14 row ownership drifted",
                )
            continue
        if entry.get("origin_phase") in {"phase15", "phase16"}:
            require(
                entry.get("status") == "candidate_deferred"
                and entry.get("route_owner") == "deferred",
                f"{entry.get('id', '<unknown>')}: later-phase opening row must remain planning-only",
            )
            continue
        require(
            family in active,
            f"{entry.get('id', '<unknown>')}: CI family {family!r} is not active in the stable family set",
        )

    for entry in migrated_phase13_rows(registry):
        require(
            entry.get("capability_decision") == "supported",
            f"{entry['id']}: migrated Phase 13 row must have a supported capability decision",
        )

    for family in families:
        migrated = selected_rows(registry, family, migrated_only=True)
        require(
            migrated,
            f"Registry CI family {family!r} has no migrated differential rows",
        )

    composition_cases = composition_case_records(registry)
    composition_families = {case.get("ci_family") for case in composition_cases}
    require(
        composition_families == set(families),
        "Registry-derived composition cases do not cover the active CI families: "
        f"missing={sorted(set(families) - composition_families)} "
        f"extra={sorted(composition_families - set(families))}",
    )

    individual_ids = set()
    for entry in migrated_differential_rows(registry):
        evidence = entry["evidence"]
        case_id = entry.get("differential_case_id")
        require(
            isinstance(case_id, str) and case_id and case_id not in individual_ids,
            f"{entry['id']}: missing or duplicate individual differential case ID",
        )
        individual_ids.add(case_id)
        require(
            isinstance(evidence.get("individual_evidence_guard"), str)
            and evidence["individual_evidence_guard"],
            f"{entry['id']}: individual focused evidence guard is missing",
        )
        require(
            evidence.get("differential_stderr_policy") in {"stable_bytes", "ignored"},
            f"{entry['id']}: invalid differential stderr policy",
        )
        require(
            evidence.get("differential_side_effect_policy")
            in {"none", "compare_tree"},
            f"{entry['id']}: invalid differential side-effect policy",
        )
        failure_fixture = evidence.get("differential_failure_fixture")
        require(
            isinstance(failure_fixture, str)
            and failure_fixture
            and (ROOT / failure_fixture).is_file(),
            f"{entry['id']}: differential failure fixture is missing",
        )

    supported = registry.get("supported_values")
    require(isinstance(supported, dict), "supported_values must be an object")
    require(
        "ci_families" not in supported,
        "supported_values.ci_families must not duplicate the row-derived active set",
    )
    return families


def validate_family(registry, family):
    families = ordered_active_families(registry)
    if family not in RUNNER_BY_FAMILY:
        raise Error(
            f"unknown or retired Cranelift CI family {family!r}; "
            f"active families: {', '.join(families)}"
        )
    return RUNNER_BY_FAMILY[family]


def require_token(text, token, context):
    require(token in text, f"{context} is missing required token: {token}")


def check_pr_workflow(path):
    registry = read_registry()
    families = validate_registry_projection(registry)
    text = path.read_text(encoding="utf-8")

    required = (
        "phase11_families:",
        'matrix=$(python3 scripts/cranelift_ci_family.py matrix-json)',
        "family: ${{ fromJSON(needs.build.outputs.phase11_families) }}",
        'just guard-cranelift-differential-family "${{ matrix.family }}"',
        "needs: [guard, phase11-family]",
    )
    for token in required:
        require_token(text, token, path.relative_to(ROOT))

    require(
        "historical-closure:" not in text
        and "just guard-cranelift-phase11-close" not in text,
        f"{path.relative_to(ROOT)} must not own Level 3 historical replay",
    )

    for family in families:
        literal = f"- cranelift-phase11-{family}"
        require(
            literal not in text,
            f"{path.relative_to(ROOT)} manually inventories registry family {family}",
        )
    return families


def check_heavy_workflow(path):
    registry = read_registry()
    families = validate_registry_projection(registry)
    text = path.read_text(encoding="utf-8")

    for family in families:
        literal = f"- cranelift-phase11-{family}"
        require(
            literal not in text,
            f"{path.relative_to(ROOT)} duplicates PR family {family}",
        )
    require(
        "historical-closure:" not in text
        and "just guard-cranelift-phase11-close" not in text,
        f"{path.relative_to(ROOT)} must leave Level 3 history to its dedicated workflow",
    )
    require_token(
        text,
        "needs: [guard, phase9g-link-driver]",
        path.relative_to(ROOT),
    )
    return families

def tsv(value, context):
    require(isinstance(value, str) and value, f"{context} must be a non-empty string")
    require("\t" not in value and "\n" not in value, f"{context} is not TSV-safe")
    return value


def differential_case_values(
    *,
    case_id,
    case_kind,
    owner_entry_id,
    ci_family,
    source_fixture,
    failure_fixture,
    positive_expectation,
    stderr_policy,
    side_effect_policy,
    related_entry_ids,
):
    return (
        tsv(case_id, f"{case_id}.case_id"),
        tsv(case_kind, f"{case_id}.case_kind"),
        tsv(owner_entry_id, f"{case_id}.owner_entry_id"),
        tsv(ci_family, f"{case_id}.ci_family"),
        tsv(source_fixture, f"{case_id}.source_fixture"),
        tsv(failure_fixture, f"{case_id}.failure_fixture"),
        tsv(positive_expectation, f"{case_id}.positive_expectation"),
        tsv(stderr_policy, f"{case_id}.stderr_policy"),
        tsv(side_effect_policy, f"{case_id}.side_effect_policy"),
        tsv(",".join(related_entry_ids), f"{case_id}.related_entry_ids"),
    )


def emit_differential_cases(registry, family):
    rows = selected_rows(registry, family, migrated_only=True)
    for entry in rows:
        evidence = entry.get("evidence")
        require(isinstance(evidence, dict), f"{entry['id']}.evidence must be an object")
        values = differential_case_values(
            case_id=entry["differential_case_id"],
            case_kind="individual",
            owner_entry_id=entry["id"],
            ci_family=entry["ci_family"],
            source_fixture=entry["source_fixture"],
            failure_fixture=evidence.get("differential_failure_fixture"),
            positive_expectation=evidence.get("positive_expectation"),
            stderr_policy=evidence.get("differential_stderr_policy"),
            side_effect_policy=evidence.get("differential_side_effect_policy"),
            related_entry_ids=[entry["id"]],
        )
        print("\t".join(values))

    for case in composition_case_records(registry):
        if family != "all" and case["ci_family"] != family:
            continue
        values = differential_case_values(
            case_id=case["id"],
            case_kind="composition",
            owner_entry_id=case["owner_entry_id"],
            ci_family=case["ci_family"],
            source_fixture=case["source_fixture"],
            failure_fixture=case["failure_fixture"],
            positive_expectation=case["positive_expectation"],
            stderr_policy=case["stderr_policy"],
            side_effect_policy=case["side_effect_policy"],
            related_entry_ids=case["covers_entry_ids"],
        )
        print("\t".join(values))


def emit_differential_rows(registry, family):
    emit_differential_cases(registry, family)


def run_static(registry, family):
    runner = validate_family(registry, family)
    rows = selected_rows(registry, family)
    print(
        "▶ Cranelift CI family static contract: "
        f"family={family} rows={','.join(entry['id'] for entry in rows)}"
    )
    environment = os.environ.copy()
    environment[runner["skip_dynamic_env"]] = "1"
    completed = subprocess.run(
        ["just", runner["static_guard"]],
        cwd=ROOT,
        env=environment,
        check=False,
    )
    if completed.returncode != 0:
        raise Error(
            f"Cranelift CI family {family!r} static guard "
            f"{runner['static_guard']} failed with exit code {completed.returncode}"
        )


def run_focused(registry, family):
    runner = validate_family(registry, family)
    rows = selected_rows(registry, family)
    print(
        "▶ Cranelift CI family focused contract: "
        f"family={family} rows={','.join(entry['id'] for entry in rows)}"
    )
    completed = subprocess.run(
        ["just", runner["static_guard"]],
        cwd=ROOT,
        check=False,
    )
    if completed.returncode != 0:
        raise Error(
            f"Cranelift CI family {family!r} focused guard "
            f"{runner['static_guard']} failed with exit code {completed.returncode}"
        )


def run_family(registry, family):
    runner = validate_family(registry, family)
    run_focused(registry, family)
    post_focused_guard = runner["post_focused_guard"]
    if post_focused_guard is not None:
        completed = subprocess.run(
            ["just", post_focused_guard, family],
            cwd=ROOT,
            check=False,
        )
        if completed.returncode != 0:
            raise Error(
                f"Registry-derived CI family {family!r} post-focused evidence "
                f"failed with exit code {completed.returncode}"
            )
    print(f"✅ Cranelift CI family runner passed: {family}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command",
        choices=(
            "validate",
            "families",
            "matrix-json",
            "validate-family",
            "differential-rows",
            "differential-cases",
            "run-static",
            "run",
            "check-pr-workflow",
            "check-heavy-workflow",
        ),
    )
    parser.add_argument("value", nargs="?")
    args = parser.parse_args()

    try:
        registry = read_registry()
        families = validate_registry_projection(registry)

        if args.command == "validate":
            print(
                "✅ Cranelift CI family projection passed: "
                f"{len(families)} row-derived families, one runner mapping, "
                f"and {len(composition_case_records(registry))} composition cases."
            )
        elif args.command == "families":
            print("\n".join(families))
        elif args.command == "matrix-json":
            print(json.dumps(families, separators=(",", ":")))
        elif args.command == "validate-family":
            require(args.value is not None, "validate-family requires a family")
            validate_family(registry, args.value)
            print(f"✅ Active Cranelift CI family: {args.value}")
        elif args.command in {"differential-rows", "differential-cases"}:
            require(
                args.value is not None,
                f"{args.command} requires a family or all",
            )
            if args.value != "all":
                validate_family(registry, args.value)
            emit_differential_cases(registry, args.value)
        elif args.command == "run-static":
            require(args.value is not None, "run-static requires a family")
            run_static(registry, args.value)
        elif args.command == "run":
            require(args.value is not None, "run requires a family")
            run_family(registry, args.value)
        elif args.command == "check-pr-workflow":
            require(args.value is not None, "check-pr-workflow requires a path")
            check_pr_workflow(ROOT / args.value)
            print("✅ PR Fast family matrix is registry-derived.")
        elif args.command == "check-heavy-workflow":
            require(args.value is not None, "check-heavy-workflow requires a path")
            check_heavy_workflow(ROOT / args.value)
            print("✅ Heavy Guards contains no duplicated registry family matrix.")
    except (Error, OSError) as exc:
        print(f"cranelift CI family error: {exc}", file=sys.stderr)
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
