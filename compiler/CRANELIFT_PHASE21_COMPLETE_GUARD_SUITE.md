# Cranelift Phase 21 Complete Guard Suite and Budgets

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase21_complete_guard_suite.py project`. Do not edit by hand.

- Contract: `phase21_complete_guard_suite_v1`
- Status: `patch21_17_complete`
- Next patch: `21.18`
- Compiler origin: `Cranelift_built_full_compiler`
- Target route: `explicit_cranelift_no_fallback`
- Oracle: `same_Cranelift_built_compiler_explicit_mir_to_c`

## Complete inventory

- Total: `326`
- Positive: `216`
- Compile-fail: `104`
- Runtime-failure: `6`
- Required native cases: `192`
- Classified deferrals: `134`
- Isolated serial shards: `2`

## Compile deferrals

| Reason | Cases |
| --- | ---: |
| `source_feature_not_represented` | 74 |
| `deferred_p13_parameter_argument_target_dependent_abi` | 25 |
| `deferred_p13_structured_cfg_condition_shape` | 7 |
| `deferred_p13_structured_cfg_loop_or_backedge` | 5 |
| `deferred_p13_parameter_argument_aggregate_parameter` | 3 |
| `deferred_p13_structured_cfg_condition_operator` | 3 |
| `deferred_p13_structured_cfg_non_reducible_shape` | 2 |
| `source_or_type_failure` | 1 |
| `inconsistent_abi_equivalent_import_signature` | 1 |

## Explicit oracle preconditions

- `compiler/codegen_initializer_test_entry.gst` — `oracle_positive_fixture_rejects_current_signature`; owner `self_hosted_test_runner_fixture`; destination `phase22_pre_default_guard_cleanup`
- `tests/e2e_generational_arena_wrapper_migration.gst` — `oracle_positive_fixture_rejects_current_arena_identity`; owner `self_hosted_test_runner_fixture`; destination `phase22_pre_default_guard_cleanup`
- `tests/e2e_parallel_zero_copy_parsing.gst` — `oracle_positive_fixture_rejects_current_spawn_argument`; owner `self_hosted_test_runner_fixture`; destination `phase22_pre_default_guard_cleanup`
- `tests/e2e_fiber_channel_pipeline.gst` — `oracle_positive_fixture_rejects_current_spawn_argument`; owner `self_hosted_test_runner_fixture`; destination `phase22_pre_default_guard_cleanup`
- `tests/e2e_unsafe_nested_selector_subscript_field_write.gst` — `oracle_positive_fixture_rejects_current_arena_identity`; owner `self_hosted_test_runner_fixture`; destination `phase22_pre_default_guard_cleanup`
- `compiler/test_directory_leak_violation.gst` — `oracle_negative_expectation_preempted_by_opaque_construction`; owner `self_hosted_test_runner_fixture`; destination `phase22_pre_default_guard_cleanup`
- `tests/test_brand_nesting_violation_rejected.gst` — `oracle_negative_expectation_uses_retired_diagnostic`; owner `self_hosted_test_runner_fixture`; destination `phase22_pre_default_guard_cleanup`
- `tests/test_branded_struct_mismatch_rejected.gst` — `oracle_negative_expectation_uses_retired_diagnostic`; owner `self_hosted_test_runner_fixture`; destination `phase22_pre_default_guard_cleanup`
- `tests/test_nested_different_brands_rejected.gst` — `oracle_negative_expectation_uses_retired_diagnostic`; owner `self_hosted_test_runner_fixture`; destination `phase22_pre_default_guard_cleanup`
- `tests/test_ctx_reassignment_rejected.gst` — `oracle_negative_expectation_uses_retired_diagnostic`; owner `self_hosted_test_runner_fixture`; destination `phase22_pre_default_guard_cleanup`

## Explicit runtime divergences

- `compiler/typechecker_scope_test_entry.gst` — `native_observable_divergence`; owner `phase14_generic_full_program_lowering`; destination `phase22_pre_default_native_parity`
- `compiler/parser_reference_access_test_entry.gst` — `native_observable_divergence`; owner `phase14_generic_full_program_lowering`; destination `phase22_pre_default_native_parity`
- `compiler/typechecker_expression_provenance_test_entry.gst` — `native_observable_divergence`; owner `phase14_generic_full_program_lowering`; destination `phase22_pre_default_native_parity`

## Resource budgets

- Protocol: `two_isolated_serial_shards_monotonic_elapsed_and_aggregate_proc_tree_peak_rss`
- Native compiler build maximum: `180000` ms
- Corpus suite maximum: `3600000` ms
- Complete suite maximum: `4200000` ms
- Peak RSS maximum: `6291456` KiB

## Full inherited budget replay

- `phase20_generated_mir_scale_full`
- `phase20_long_lived_concurrent_full`
- `phase20_cross_feature_qualification_full`

## Resolved scaling predecessor

- Authority: `phase21_roadmap_patch21_16b`
- Status: `complete`
- Required operation count: `1024`
- Passing cases: `34`
- Observed large-function peak RSS: `83456` KiB
- Falsifier: `the_Cranelift_built_compiler_completes_the_unchanged_1024_operation_cohort_with_MIR_to_C_parity_inside_registered_budgets`

Every case in the self-hosted runner inventory is either a
required native pass or an owned, reason-coded deferral with a
falsifier. The target leg is explicit Cranelift with no fallback;
MIR-to-C is invoked only as the semantic oracle. No unexplained
failure or unclassified inventory row is permitted.
