# Cranelift Phase 19 Type-Derived Argument Representation

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase19_representation.py project`. Do not edit by hand.

- Authority: `phase19_type_derived_argument_representation_v1`
- Status: `ready_for_patch19_6`
- Next patch: `19.6`
- Source authority: `phase16_parameter_and_result_placement_passing_mode`
- Canonical MIR record: `MirCallOperand.passing_mode_plus_materialization`
- Backend policy: `mir_to_c_and_cranelift_consume_the_record`

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
