# Cranelift Phase 19 Cross-Feature Composition

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase19_composition.py project`. Do not edit by hand.

- Authority: `phase19_cross_feature_composition_v1`
- Status: `ready_for_patch19_12`
- Next patch: `19.12`
- Fixture: `compiler/phase19_cross_feature_composition_source.gst`
- Expected exit status: `91`

## Composed features

- `branded_collection`
- `cross_arena_clone`
- `branded_reference`
- `linear_directory_resource`
- `direct_function_call`

## Backend result

Default and explicit MIR-to-C must emit byte-identical C. That C must compile
with the unchanged runtime surface and return status 91. The composition also
guards the spelling-independent canonical native ABI names discovered here:
synthetic `LookupResult` layouts retain their resolved brand, and canonical
lookup elides that known identity before resolving the existing runtime type.

Explicit Cranelift is deferred by the compiler-owned
`phase13_generic_source_to_mir` decision with reason
`deferred_p13_parameter_argument_target_dependent_abi` at `before_driver_discovery`.
That is the preserved Phase 19 classification. After Phase 26 admitted direct
call Reference parameters, the same composition reaches a typed `std.Clone`
of an `Index` and now defers with `deferred_p14_full_program_non_string_clone` at
`before_driver_discovery`. The Level 2 guard checks that refusal and an
independent `Index` Clone fixture, with no C fallback or native artifact.
String Clone remains natively supported. The frozen exit status 91 is unchanged.

## Unaffected predecessor authorities

- `phase14_layout_authority`
- `phase15_resource_composition_authority`
- `phase16_abi_composition_authority`
- `phase17_composition_authority`
- `phase18_composition`

No MIR instruction, runtime symbol, ABI, layout, target policy, linker policy,
resource rule, or source syntax changes in this patch.
