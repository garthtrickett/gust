# Cranelift Phase 23.10 — Focused Live MIR-to-C Compatibility Lane

Generated from the canonical feature registry. Do not edit by hand.

- Contract: `phase23_mir_to_c_focused_live_v1`
- Status: `patch23_10_complete`
- Registry-derived families: `14`
- Family manifest: `1fffc956d284c857b85be3860487c395f656b2a3b809c26d701914114fdbea89`
- Whole-program cases: `6`
- Program manifest: `6ae773959d60b59ecaaf1f039f9fc33188d040e0d4558dcc24d10dc1ecef43ad`
- Coverage: `module, output_artifact, rejection, resource, side_effects, success, typed_query`
- Oracle: explicit `mir-to-c`; subject: explicit `cranelift`; fallback: forbidden.
- This is the sole registered non-bootstrap live-C compatibility lane.

## Families

- `scalars`
- `locals`
- `cfg`
- `block-params`
- `direct-calls`
- `imports`
- `metadata-diagnostics`
- `primitive-layout`
- `conversions`
- `pointer-memory`
- `strings-views`
- `arrays-slices`
- `structs-enums`
- `aggregate-flow`

## Whole-program cohort

- `imported_module`
- `resource_cleanup`
- `scalar_positive`
- `scalar_type_error`
- `trusted_typed_query`
- `typed_query_provenance_error`

## Removed default-CI coverage

- `pr_fast_static_matrix` / `mir-to-c-return-int` → `family_and_whole_program_focused_lane`
- `pr_fast_phase11_family_matrix` / `14_registry_families` → `focused_family_matrix`
- `heavy_guards_matrix` / `mir-to-c-boring-surface` → `focused_family_and_archived_23_11`
- `phase21_compiler_programs_workflow` / `evidence` → `focused_whole_program`

Patch 23.10 changes no accepted Gust meaning, MIR operation, ABI/layout/runtime
contract, backend route/default/fallback, bootstrap route, or seed.
