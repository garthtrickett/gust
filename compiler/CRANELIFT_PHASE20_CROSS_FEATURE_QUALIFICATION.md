# Cranelift Phase 20 Cross-Feature Qualification

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_cross_feature_qualification.py project`. Do not edit by hand.

- Contract: `phase20_cross_feature_qualification_v1`
- Status: `phase20_ready_for_authoritative_historical_full`
- Next patch: `20.17`
- Normalization: `none`
- Unexplained divergences: `0`

## Mixed selected cohort

- Features: `brand_identity,arena_liveness,user_resources,modules,approved_runtime_import,bounded_scale,long_lived_concurrency`
- Source oracle: `compiler/phase20_cross_feature_qualification_source.gst`
- Canonical MIR: `compiler/fixtures/native_backend_phase20_cross_feature_qualification.mir`
- Expected exit: `47`
- Resource events: `57,2,1`
- Backend policy: MIR_to_C_executes_the_mixed_source_oracle_and_direct_canonical_MIR_Cranelift_executes_the_same_observable_plan_against_the_same_runtime_and_test_probes
- Fallback policy: direct_mixed_source_Cranelift_is_poisoned_and_must_reject_before_driver_discovery_without_an_artifact

## Canonical registry audit

- Entries: `95`
- Migrated: `34`
- Candidate deferred: `43`
- Replaced: `11`
- Deferred: `7`
- Duplicate IDs: `0`
- Unowned rows: `0`

## Final deduplicated residues

- `collections` — `deferred` / `deferred_p13_structured_cfg_non_reducible_shape`
  - Fixture: `compiler/phase20_component_collections_source.gst`
  - Diagnostic: `stdout:reason_code=deferred_p13_structured_cfg_non_reducible_shape` at `before_driver_discovery`
  - Owner: `phase13_generic_source_to_mir`; destination: `phase21_opening`
  - Falsifier: a real Vector or HashMap source program reaches the native driver and its full observable differential passes
- `strings` — `deferred` / `deferred_p13_structured_cfg_condition_shape`
  - Fixture: `compiler/phase20_component_strings_source.gst`
  - Diagnostic: `stdout:reason_code=deferred_p13_structured_cfg_condition_shape` at `before_driver_discovery`
  - Owner: `phase13_generic_source_to_mir`; destination: `phase21_opening`
  - Falsifier: a real string utility source program reaches the native driver and its full observable differential passes
- `filesystem` — `deferred` / `source_feature_not_represented`
  - Fixture: `compiler/phase20_component_filesystem_source.gst`
  - Diagnostic: `stdout:reason_code=source_feature_not_represented` at `before_driver_discovery`
  - Owner: `phase13_generic_source_to_mir`; destination: `phase21_opening`
  - Falsifier: a sandboxed file I/O source program reaches the native driver and its exact filesystem-tree differential passes
- `allocation` — `deferred` / `source_feature_not_represented`
  - Fixture: `compiler/phase20_component_allocation_source.gst`
  - Diagnostic: `stdout:reason_code=source_feature_not_represented` at `before_driver_discovery`
  - Owner: `phase13_generic_source_to_mir`; destination: `phase21_opening`
  - Falsifier: a real Arena allocation and write source program reaches the native driver and its full observable differential passes
- `resources` — `source_or_type_failure` / `source_or_type_failure`
  - Fixture: `compiler/phase20_resource_scope_cleanup_source.gst`
  - Diagnostic: `stderr:Native backend canonical MIR verification failed: unsupported top-level statement in module/import cohort` at `before_driver_discovery`
  - Owner: `phase13_generic_source_to_mir`; destination: `phase21_opening`
  - Falsifier: a source-declared Resource program reaches the native driver and its terminal-state and cleanup differential passes
- `threading_synchronization` — `deferred` / `deferred_p13_parameter_argument_target_dependent_abi`
  - Fixture: `compiler/phase20_component_threading_source.gst`
  - Diagnostic: `stdout:reason_code=deferred_p13_parameter_argument_target_dependent_abi` at `before_driver_discovery`
  - Owner: `phase13_generic_source_to_mir`; destination: `phase21_opening`
  - Falsifier: a real Mutex or Channel source program reaches the native driver and its deterministic-invariant differential passes

The resource and threading rows subsume Patch 20.15's narrower direct
source exclusions; they are not additional residue categories. The
authoritative Historical Full result remains a Patch 20.17 closure gate.
