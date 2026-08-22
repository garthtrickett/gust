#!/usr/bin/env python3
"""Validate and project Patch 19.11 cross-feature composition."""

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TYPECHECKER = ROOT / "compiler/typechecker.gst"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE19_COMPOSITION.md"
GUARD = "guard-cranelift-phase19-composition-contract"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def load() -> tuple[dict, dict]:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase19_composition")
    require(isinstance(record, dict), "phase19_composition registry record missing")
    return registry, record


def validate() -> dict:
    registry, record = load()
    expected = {
        "contract_version": "phase19_cross_feature_composition_v1",
        "status": "ready_for_patch19_12",
        "next_patch": "19.12",
        "review_view": "compiler/CRANELIFT_PHASE19_COMPOSITION.md",
        "source_fixture": "compiler/phase19_cross_feature_composition_source.gst",
        "expected_exit_status": 91,
        "mir_to_c_policy": "default_and_explicit_byte_identical_then_execute",
        "cranelift_disposition": "explicitly_deferred_without_c_fallback",
        "cranelift_capability": "phase13_generic_source_to_mir",
        "cranelift_reason_code": "deferred_p13_parameter_argument_target_dependent_abi",
        "cranelift_failure_stage": "before_driver_discovery",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")

    require(record.get("composed_features") == [
        "branded_collection",
        "cross_arena_clone",
        "branded_reference",
        "linear_directory_resource",
        "direct_function_call",
    ], "composed feature inventory drifted")
    require(record.get("canonical_native_abi_types") == [
        "os_Dir", "os_DirEntry", "LookupResult_os_Dir",
        "LookupResult_os_DirEntry",
    ], "canonical native ABI type inventory drifted")

    authority_versions = {
        "phase14_layout_authority": (
            "phase14_compiler_owned_layout_authority_v1", "consumed_by_patch14_7"),
        "phase15_resource_composition_authority": (
            "phase15_resource_composition_authority_v1",
            "patch15_13_complete_composition_migrated"),
        "phase16_abi_composition_authority": (
            "phase16_abi_composition_authority_v1",
            "patch16_13_complete_composition_migrated"),
        "phase17_composition_authority": (
            "phase17_composition_authority_v1", "ready_for_patch17_15"),
        "phase18_composition": (
            "phase18_composition_v1", "ready_for_patch18_18"),
    }
    require(record.get("unaffected_authorities") == list(authority_versions),
            "unaffected authority inventory drifted")
    for key, (version, status) in authority_versions.items():
        authority = registry.get(key)
        require(isinstance(authority, dict), f"predecessor authority missing: {key}")
        require(authority.get("version") == version, f"{key} version drifted")
        require(authority.get("status") == status, f"{key} status drifted")

    fixture_path = ROOT / record["source_fixture"]
    require(fixture_path.is_file(), "composition fixture missing")
    fixture = fixture_path.read_text(encoding="utf-8")
    for token in (
        "type Phase19CompositionNode[ctx] struct",
        "std.Vector[Index[Phase19CompositionNode, origin], origin]",
        "std.Clone(destination, nodes[0])",
        "origin.get_ref(source)",
        "destination.get_ref(cloned)",
        'os.OpenDir(origin, ".")',
        "os.CloseDir(directory)",
        "phase19_composed_call(&origin, &destination)",
        "return 91;",
    ):
        require(token in fixture, f"composition fixture is missing {token!r}")

    typechecker = TYPECHECKER.read_text(encoding="utf-8")
    for native_type in record["canonical_native_abi_types"]:
        alias = f'env_record_canonical_type_name(env, "{native_type}", "{native_type}", ctx);'
        require(alias in typechecker, f"canonical native ABI alias missing: {native_type}")
    for token in (
        "layout.brand = t.Struct.brand;",
        "typechecker_canonicalize_concrete_name(resolved_name, brand_name, ctx)",
        "env_get_canonical_type_name(env, elided_name, ctx)",
    ):
        require(token in typechecker, f"structural canonicalization fix missing: {token}")

    require(
        "- [x] Patch 19.11 — Cross-Feature Composition and Complete Differential — DONE"
        in TASK.read_text(encoding="utf-8"),
        "TASK.md does not mark Patch 19.11 DONE",
    )
    return record


def render(record: dict) -> str:
    features = "\n".join(f"- `{feature}`" for feature in record["composed_features"])
    authorities = "\n".join(
        f"- `{authority}`" for authority in record["unaffected_authorities"])
    return f"""# Cranelift Phase 19 Cross-Feature Composition

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase19_composition.py project`. Do not edit by hand.

- Authority: `{record['contract_version']}`
- Status: `{record['status']}`
- Next patch: `{record['next_patch']}`
- Fixture: `{record['source_fixture']}`
- Expected exit status: `{record['expected_exit_status']}`

## Composed features

{features}

## Backend result

Default and explicit MIR-to-C must emit byte-identical C. That C must compile
with the unchanged runtime surface and return status 91. The composition also
guards the spelling-independent canonical native ABI names discovered here:
synthetic `LookupResult` layouts retain their resolved brand, and canonical
lookup elides that known identity before resolving the existing runtime type.

Explicit Cranelift is deferred by the compiler-owned
`{record['cranelift_capability']}` decision with reason
`{record['cranelift_reason_code']}` at `{record['cranelift_failure_stage']}`.
The Level 2 guard requires that refusal and proves no C fallback or native
artifact is published.

## Unaffected predecessor authorities

{authorities}

No MIR instruction, runtime symbol, ABI, layout, target policy, linker policy,
resource rule, or source syntax changes in this patch.
"""


def project(check: bool) -> None:
    record = validate()
    expected = render(record)
    if check:
        require(REVIEW.is_file(), "generated review view missing")
        require(REVIEW.read_text(encoding="utf-8") == expected,
                "generated review view is stale; run phase19_composition.py project")
    else:
        REVIEW.write_text(expected, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review"))
    args = parser.parse_args()
    if args.command == "validate":
        validate()
    elif args.command == "project":
        project(False)
    else:
        project(True)
    print(f"{GUARD}: ok")


if __name__ == "__main__":
    main()
