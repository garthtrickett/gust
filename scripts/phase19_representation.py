#!/usr/bin/env python3
"""Validate and project Patch 19.5 canonical argument representation."""

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
ABI = ROOT / "compiler/mir_function_abi_authority.gst"
CALL_MIR = ROOT / "compiler/mir_function_call.gst"
MIR_TO_C = ROOT / "compiler/mir_function_call_mir_to_c.gst"
CODEGEN = ROOT / "compiler/codegen.gst"
CRANELIFT = ROOT / "compiler/experiments/cranelift/src/function_call_mir.rs"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE19_REPRESENTATION.md"
GUARD = "guard-cranelift-phase19-representation-contract"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def function_body(source: str, name: str) -> str:
    marker = f"func {name}("
    start = source.find(marker)
    require(start >= 0, f"missing function {name}")
    open_brace = source.find("{", start)
    require(open_brace >= 0, f"missing body for {name}")
    depth = 0
    for pos in range(open_brace, len(source)):
        if source[pos] == "{":
            depth += 1
        elif source[pos] == "}":
            depth -= 1
            if depth == 0:
                return source[open_brace : pos + 1]
    raise SystemExit(f"{GUARD}: unterminated function {name}")


def load_record() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase19_representation")
    require(isinstance(record, dict), "phase19_representation registry record missing")
    return record


def validate() -> dict:
    record = load_record()
    expected = {
        "authority_version": "phase19_type_derived_argument_representation_v1",
        "status": "ready_for_patch19_6",
        "next_patch": "19.6",
        "review_view": "compiler/CRANELIFT_PHASE19_REPRESENTATION.md",
        "source_authority": "phase16_parameter_and_result_placement_passing_mode",
        "mir_record": "MirCallOperand.passing_mode_plus_materialization",
        "backend_policy": "mir_to_c_and_cranelift_consume_the_record",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")
    require(record.get("materializations") == ["by_value", "by_address"],
            "materialization vocabulary drifted")
    fixtures = record.get("rename_invariance_fixtures")
    require(fixtures == [
        "compiler/phase19_argument_representation_a_source.gst",
        "compiler/phase19_argument_representation_b_source.gst",
    ], "representation fixture family drifted")
    for fixture in fixtures:
        require((ROOT / fixture).is_file(), f"representation fixture missing: {fixture}")

    abi = ABI.read_text(encoding="utf-8")
    for needle in (
        "func mir_abi_argument_materialization(",
        "func mir_abi_parameter_passing_mode_for_value_class(",
        "func mir_abi_parameter_placement_by_id(",
        "func mir_abi_result_placement_by_id(",
    ):
        require(needle in abi, f"Phase 16 representation projection missing {needle!r}")
    projection = function_body(abi, "mir_abi_argument_materialization")
    for mode in ("direct", "split", "indirect_by_value", "indirect_by_reference", "hidden_pointer"):
        require(f'"{mode}"' in projection, f"passing mode {mode} is not projected")
    require('return "by_value";' in projection and 'return "by_address";' in projection,
            "Phase 16 modes do not project to the bounded representation vocabulary")

    call_mir = CALL_MIR.read_text(encoding="utf-8")
    for needle in (
        "type MirArgumentRepresentation[ctx] struct",
        "passing_mode: str,",
        "materialization: str,",
        'mir_abi_parameter_placement_by_id(authority, value.abi_value_id, ctx)',
        'mir_abi_result_placement_by_id(authority, value.abi_value_id, ctx)',
        '"call_mir_representation_missing"',
        '"call_mir_representation_mismatch"',
        'row = mir_call_append_field(row, "passing_mode", value.passing_mode, ctx);',
        'row = mir_call_append_field(row, "materialization", value.materialization, ctx);',
        'mut row := "argument_representation: id=";',
    ):
        require(needle in call_mir, f"canonical call MIR representation missing {needle!r}")

    mir_to_c = MIR_TO_C.read_text(encoding="utf-8")
    require("func mir_function_call_operand_to_c(" in mir_to_c and
            "mir_function_call_operand_to_c(operands[index], ctx)" in mir_to_c,
            "MIR-to-C does not consume canonical operand representation")

    cranelift = CRANELIFT.read_text(encoding="utf-8")
    for needle in (
        "passing_mode: String",
        "materialization: String",
        '"call_mir_representation_missing"',
        '"call_mir_representation_mismatch"',
        '"argument_representation: id={}',
    ):
        require(needle in cranelift, f"Cranelift representation consumer missing {needle!r}")

    codegen = CODEGEN.read_text(encoding="utf-8")
    for needle in (
        "func codegen_plan_argument_representation_for_value_class(",
        "func codegen_plan_argument_representation_for_type(",
        "func codegen_plan_argument_representation(",
        "func codegen_emit_argument_representation(",
        "mir_abi_parameter_passing_mode_for_value_class",
        "mir_call_argument_representation",
    ):
        require(needle in codegen, f"self-hosted representation consumer missing {needle!r}")
    generate = function_body(codegen, "codegen_generate_expression")
    for forbidden in (
        'std.Concat("&",',
        'arg_str = std.Concat("&", arg_str)',
        'mut ref_prefix := "&"',
        "codegen_brand_representation_is_pointer",
    ):
        require(forbidden not in generate, f"codegen still prepends address-of from source text: {forbidden}")
    require(generate.count("codegen_emit_argument_representation(") >= 20,
            "argument and index lowering did not migrate completely")
    require("phase19_argument_length(a);" not in codegen,
            "fixture-specific source recognizer entered codegen")

    require("- [x] Patch 19.5 — Argument and Index Representation From the Type System — DONE"
            in TASK.read_text(encoding="utf-8"), "TASK.md does not mark Patch 19.5 DONE")
    return record


def render(record: dict) -> str:
    return f"""# Cranelift Phase 19 Type-Derived Argument Representation

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase19_representation.py project`. Do not edit by hand.

- Authority: `{record['authority_version']}`
- Status: `{record['status']}`
- Next patch: `{record['next_patch']}`
- Source authority: `{record['source_authority']}`
- Canonical MIR record: `{record['mir_record']}`
- Backend policy: `{record['backend_policy']}`

## Result

Phase 16 parameter and result placements now project each passing mode to one
of two backend-neutral materializations: `by_value` or `by_address`. Canonical
call MIR records both the authoritative passing mode and its projection on each
operand. Missing records and disagreements are rejected before either backend
emits output.

The self-hosted compiler plans argument and index receiver representation from
resolved type classification, creates the same canonical representation record,
and gives that record to MIR-to-C. Address materialization is emitted only by
that consumer; call lowering no longer prepends `&` while inspecting a source
expression or its identifier.

The direct regression pair passes a local `str` named `a` and then `b` to the
same by-value parameter. Both programs return 7, their normalized generated C
is byte-identical, and neither call contains an address-of. The canonical call
fixture additionally carries direct/by-value, indirect-reference/by-address,
and hidden-pointer/by-address operands; MIR-to-C and explicit Cranelift produce
the same normalized witness.

No runtime symbol, target policy, layout, resource rule, or source syntax changed.
"""


def project(check: bool) -> None:
    record = validate()
    expected = render(record)
    if check:
        require(REVIEW.is_file(), "generated review view missing")
        require(REVIEW.read_text(encoding="utf-8") == expected,
                "generated review view is stale; run phase19_representation.py project")
        return
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
