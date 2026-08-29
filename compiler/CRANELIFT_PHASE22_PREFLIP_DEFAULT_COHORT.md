# Cranelift Phase 22.5 — Pre-flip Default-Cohort Qualification

Generated from `scripts/cranelift_feature_registry.json`. Do not edit by hand.

- Contract: `phase22_preflip_default_cohort_v1`
- Status: `qualification_complete_default_flip_prerequisites_satisfied`
- Next action: `patch22_6_default_route_flip`
- Observed main: `76192f27c73b9caf7ec5a610624996a9337d09f2`
- Compiler origin: `Cranelift_built_full_compiler`
- Candidate route: `explicit_cranelift_no_fallback`
- Oracle: `same_Cranelift_built_compiler_explicit_mir_to_c`
- Package origin: `build_phase10_package_three_artifact_sibling_directory`

## Cohort

- Inventory: `326` cases
- Required native passes: `195`
- Classified non-default native deferrals: `121`
- Oracle-precondition parity rejections: `10`
- Required native deferrals: `0`
- Unclassified results: `0`
- Runtime divergences: `0`

## Generic reconciliation

- Root cause: `generic_ZeroInitialize_lowering_used_zero_for_empty_Index`
- Oracle contract: `empty_Index_is_the_0xFFFFFFFF_absence_sentinel`
- Native correction: `Index_typed_ZeroInitialize_emits_i32_minus_one`
- Other zero initialization: `unchanged_zero`
- `compiler/typechecker_scope_test_entry.gst`
- `compiler/parser_reference_access_test_entry.gst`
- `compiler/typechecker_expression_provenance_test_entry.gst`

The Phase 21 record remains historical. This successor authority resolves
its three runtime-divergence rows without changing the 121 explicitly owned
non-default native capability deferrals or the ten identical oracle/native
precondition rejections. The owning Stdlib explicit-C relay has merged,
all pre-flip prerequisites are complete, and the compiler default remains
MIR-to-C. Patch 22.6 is still unchecked and is not folded into this
reconciliation.
