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

# This is the single runner mapping. The stable family set is derived from
# Phase 11 rows; migrated Phase 13 rows join their existing family without
# creating a new workflow matrix.
RUNNERS = (
    (
        "scalars",
        "guard-cranelift-phase13-scalar-expression-parity",
        "PHASE13_SCALAR_EXPRESSION_SKIP_DYNAMIC",
    ),
    (
        "locals",
        "guard-cranelift-phase13-multiple-locals-assignments-parity",
        "PHASE13_MULTIPLE_LOCALS_SKIP_DYNAMIC",
    ),
    (
        "cfg",
        "guard-cranelift-phase13-nested-structured-cfg-parity",
        "PHASE13_NESTED_STRUCTURED_CFG_SKIP_DYNAMIC",
    ),
    (
        "block-params",
        "guard-cranelift-phase13-general-loop-parity",
        "PHASE13_GENERAL_LOOP_SKIP_DYNAMIC",
    ),
    (
        "direct-calls",
        "guard-cranelift-phase13-direct-call-graph-parity",
        "PHASE13_DIRECT_CALL_GRAPH_SKIP_DYNAMIC",
    ),
    (
        "imports",
        "guard-cranelift-phase13-broader-imported-runtime-calls-parity",
        "PHASE13_BROADER_IMPORTED_RUNTIME_CALLS_SKIP_DYNAMIC",
    ),
    (
        "metadata-diagnostics",
        "guard-cranelift-phase13-source-metadata-parity",
        "PHASE13_SOURCE_METADATA_SKIP_DYNAMIC",
    ),
)
RUNNER_BY_FAMILY = {
    family: {
        "static_guard": static_guard,
        "skip_dynamic_env": skip_dynamic_env,
    }
    for family, static_guard, skip_dynamic_env in RUNNERS
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


def differential_registry_rows(registry):
    return phase11_rows(registry) + migrated_phase13_rows(registry)


def active_family_set(registry):
    families = set()
    for entry in phase11_rows(registry):
        family = entry.get("ci_family")
        require(
            isinstance(family, str) and family,
            f"{entry.get('id', '<unknown>')}: Phase 11 ci_family is missing",
        )
        families.add(family)
    return families


def ordered_active_families(registry):
    active = active_family_set(registry)
    mapped = set(RUNNER_BY_FAMILY)
    require(
        active == mapped,
        "Phase 11 CI family projection differs from the runner mapping: "
        f"registry_only={sorted(active - mapped)} mapping_only={sorted(mapped - active)}",
    )
    return [family for family, _, _ in RUNNERS]
    return json.dumps(families, separators=(",", ":"))


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


def validate_registry_projection(registry):
    families = ordered_active_families(registry)
    active = set(families)

    for entry in registry["entries"]:
        family = entry.get("ci_family")
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
            f"Phase 11 CI family {family!r} has no migrated differential rows",
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
            f"unknown or retired Phase 11 CI family {family!r}; "
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


def emit_differential_rows(registry, family):
    rows = selected_rows(registry, family, migrated_only=True)
    for entry in rows:
        evidence = entry.get("evidence")
        require(isinstance(evidence, dict), f"{entry['id']}.evidence must be an object")
        values = (
            tsv(entry["id"], f"{entry['id']}.id"),
            tsv(entry["route_owner"], f"{entry['id']}.route_owner"),
            tsv(entry["ci_family"], f"{entry['id']}.ci_family"),
            tsv(entry["source_fixture"], f"{entry['id']}.source_fixture"),
            tsv(evidence.get("deferred_fixture"), f"{entry['id']}.deferred_fixture"),
            tsv(
                evidence.get("positive_expectation"),
                f"{entry['id']}.positive_expectation",
            ),
        )
        print("\t".join(values))


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
    run_focused(registry, family)
    completed = subprocess.run(
        ["just", "guard-cranelift-phase11-registry-differential", family],
        cwd=ROOT,
        check=False,
    )
    if completed.returncode != 0:
        raise Error(
            f"Phase 11 CI family {family!r} differential cases failed "
            f"with exit code {completed.returncode}"
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
                f"{len(families)} row-derived families and one runner mapping."
            )
        elif args.command == "families":
            print("\n".join(families))
        elif args.command == "matrix-json":
            print(json.dumps(families, separators=(",", ":")))
        elif args.command == "validate-family":
            require(args.value is not None, "validate-family requires a family")
            validate_family(registry, args.value)
            print(f"✅ Active Cranelift CI family: {args.value}")
        elif args.command == "differential-rows":
            require(args.value is not None, "differential-rows requires a family or all")
            if args.value != "all":
                validate_family(registry, args.value)
            emit_differential_rows(registry, args.value)
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
