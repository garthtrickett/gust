# Cranelift Phase 20 Stdlib and Runtime Component Differential

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_stdlib_runtime_differential.py project`. Do not edit by hand.

- Contract: `phase20_stdlib_runtime_differential_v1`
- Status: `patch20_13_complete`
- Next patch: `20.14`
- Selection policy: `select_only_components_with_a_real_whole_program_cranelift_source_route`
- Marker policy: `source_markers_and_request_witnesses_do_not_establish_component_execution`
- Normalization policy: `none`

## Selected component

- Component: `runtime_component:approved_scalar_imports`
- Whole-program case: `p20_multi_module_runtime_scalar`
- Source: `compiler/phase20_whole_program_scalar_source.gst`
- Helpers: `tiny_host_add_i32`

This is the only current component with a real, no-fallback
whole-program source route. Patch 20.12 owns its exact compile/runtime
status, stdout, stderr, canonical request/bundle, and filesystem evidence.

## Explicit exclusions

- `collections` — `deferred` / `deferred_p13_structured_cfg_non_reducible_shape`
  - Fixture: `compiler/phase20_component_collections_source.gst`
  - Owner: `phase13_generic_source_to_mir`; destination: `20.16`
  - Falsifier: a real Vector or HashMap source program reaches the native driver and its full Patch 20 observable differential passes
- `strings` — `deferred` / `deferred_p13_structured_cfg_condition_shape`
  - Fixture: `compiler/phase20_component_strings_source.gst`
  - Owner: `phase13_generic_source_to_mir`; destination: `20.16`
  - Falsifier: a real string utility source program reaches the native driver and its full Patch 20 observable differential passes
- `filesystem` — `deferred` / `source_feature_not_represented`
  - Fixture: `compiler/phase20_component_filesystem_source.gst`
  - Owner: `phase13_generic_source_to_mir`; destination: `20.16`
  - Falsifier: a sandboxed file I/O source program reaches the native driver and its exact filesystem-tree differential passes
- `allocation` — `deferred` / `source_feature_not_represented`
  - Fixture: `compiler/phase20_component_allocation_source.gst`
  - Owner: `phase13_generic_source_to_mir`; destination: `20.16`
  - Falsifier: a real Arena allocation and write source program reaches the native driver and its full observable differential passes
- `resources` — `source_or_type_failure` / `source_or_type_failure`
  - Fixture: `compiler/phase20_resource_scope_cleanup_source.gst`
  - Owner: `phase13_generic_source_to_mir`; destination: `20.16`
  - Falsifier: a successful source-declared Resource program reaches the native driver and its terminal-state and cleanup differential passes
- `threading_synchronization` — `deferred` / `deferred_p13_parameter_argument_target_dependent_abi`
  - Fixture: `compiler/phase20_component_threading_source.gst`
  - Owner: `phase13_generic_source_to_mir`; destination: `20.16`
  - Falsifier: a real Mutex or Channel source program reaches the native driver and its deterministic-invariant differential passes

## Successor transitions

The six exclusions above remain the frozen Patch 20.13 snapshot.
Completed successor migrations are no longer re-probed as exclusions
by this historical guard.
Completed successor-owned categories: `collections,strings`.

Phase 17 request witnesses continue to prove runtime-operation contract
agreement, but a scalar marker plus a request witness is not counted as
execution of a collection, string, filesystem, allocation, Resource, or
synchronization program. Every still-active exclusion is re-probed before
driver discovery with MIR-to-C fallback poisoned.
