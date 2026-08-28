# Cranelift Phase 21 Roadmap and OD-8 Design Authority

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase21_roadmap.py project`. Do not edit by hand.

- Contract: `phase21_roadmap_and_od8_design_authority_v1`
- Status: `patch21_0_complete`
- Next patch: `21.1`
- Operator date: `2026-08-24`
- Completion loop through: `21.18`

## Exact predecessor closure

- Status: `phase20_closed_semantic_foundations_and_qualification`
- Merge: `da18ab2ba3307c24ffabdc510fd0583f9a75e22b`
- Historical Full run: `32772996884`
- Historical head: `6e54e3cc6fa8fc44e5df7a67624bb183b01b2258`
- Successful jobs: `18`

## Serial tracks

- `typed_query_scope_analysis_and_adversarial_verdict`
- `cranelift_self_hosting_qualification`

## Roadmap amendments

### Patch 21.16a

- Status: `complete`
- Capability: `native_rebuild_workflow_dependency_correction`
- Reason: `post_merge_review_proved_the_generated_arena_offset_normalizer_was_a_compiler_input_missing_from_native_rebuild_workflow_paths`
- Merge Sha: `df8a7861b3f78e604e4f64519e785245ea801125`
- Exact Head Pull Request Successes: `5`
- Changes Compiler Semantics: `false`

### Patch 21.16b

- Status: `complete`
- Capability: `generic_native_compiler_large_function_allocation_scaling`
- Trigger: `patch21_17_inherited_phase20_generated_large_function_replay`
- Passing Operation Counts: `64,128,256`
- Aborting Operation Counts: `512,768,1024`
- Abort Signal: `6`
- Abort Peak Rss Kib: `4198784`
- Required Operation Count: `1024`
- Passing Case Count: `34`
- Observed Large Function Peak Rss Kib: `95488`
- Post Merge Correction: `compiler_origin_selection_and_local_state_linear_canonical_transport`
- Compiler Origin Policy: `GUST_COMPILER_is_consumed_by_the_inherited_scale_harness_and_names_the_Cranelift_built_compiler_under_test`
- Corrected Emitter: `compiler/mir_native_backend_local_state_source.gst`
- Byte Identity Operation Count: `256`
- Byte Identity Policy: `pre_correction_and_corrected_Cranelift_built_compilers_emit_cmp_identical_canonical_bundles_and_native_artifacts`
- Changes Compiler Semantics: `false`
- Falsifier: `the_Cranelift_built_compiler_completes_the_unchanged_1024_operation_cohort_with_MIR_to_C_parity_inside_registered_budgets`
- Boundary: `existing_Gust_MIR_ABI_layout_and_runtime_symbol_authority_only_no_cohort_reduction_budget_weakening_arena_capacity_bypass_module_exception_or_fallback`

### Patch 21.17a

- Status: `complete`
- Capability: `generic_scheduler_main_result_completion`
- Trigger: `patch21_17_inherited_phase20_long_lived_concurrent_replay`
- Operator Date: `2026-08-28`
- Expected Exit Status: `47`
- Observed Mir To C Statuses Before: `0,47`
- Observed Native Status Before: `47`
- Focused Replays Per Backend: `32`
- Synchronization Authority: `scheduler_owned_pending_fiber_count_with_full_barrier_result_publication`
- Runtime Implementation: `src/runtime/fiber.c`
- Changes Runtime Symbols: `false`
- Changes Abi Or Layout: `false`
- Changes Accepted Gust Meaning: `false`
- Falsifier: `every_focused_MIR_to_C_and_Cranelift_replay_returns_47_with_identical_empty_streams_and_the_patch21_17_full_inherited_replay_passes`
- Boundary: `generic_scheduler_completion_only_no_gate_weakening_fixture_exception_other_runtime_semantics_stdlib_CR15_or_patch21_18`

### Patch 21.17b

- Status: `complete`
- Capability: `historical_dependency_beachhead_prose_scope_correction`
- Trigger Run Id: `33171071194`
- Failed Guard: `guard-cranelift-dependency-beachhead`
- Failure Class: `generated_compiler_review_prose_false_positive`
- Correction: `compiler_CRANELIFT_review_markdown_is_excluded_from_the_production_reference_scan`
- Production Scan Scope: `compiler_src_tests_root_manifests_and_Makefile_unchanged`
- Changes Compiler Semantics: `false`
- Falsifier: `the_focused_beachhead_guard_and_replacement_phase9_core_Historical_Full_shard_pass_while_production_source_remains_scanned`
- Boundary: `guard_population_classification_only_no_gate_weakening_compiler_MIR_backend_ABI_layout_runtime_symbol_seed_default_backend_Stdlib_CR15_or_phase22_change`

### Patch 21.17c

- Status: `complete`
- Capability: `historical_driver_handshake_fixture_reconciliation`
- Trigger Run Id: `33177003376`
- Failed Guard: `guard-cranelift-phase10-driver-handshake-contract`
- Failure Class: `positive_fixture_omitted_existing_full_program_canonical_format`
- Existing Authority: `patch21_14_exact_three_format_driver_handshake_contract`
- Correction: `positive_and_protocol_mismatch_fixture_handshakes_advertise_v1_v2_and_gust_compiler_executable_mir_v1`
- Changes Compiler Semantics: `false`
- Falsifier: `the_focused_phase10_handshake_guard_and_replacement_phase10_Historical_Full_shard_pass_without_validator_or_worker_change`
- Boundary: `fixture_reconciliation_only_no_validator_worker_compiler_MIR_backend_ABI_layout_runtime_symbol_seed_default_backend_Stdlib_CR15_or_phase22_change`

### Patch 21.17d

- Status: `complete`
- Capability: `historical_phase9f_import_ABI_fixture_reconciliation`
- Trigger Run Id: `33177003376`
- Failed Guard: `guard-cranelift-phase9f-call-import-schema-validator`
- Failure Class: `negative_fixture_used_admitted_void_return_ABI_and_reached_call_result_validation`
- Existing Authority: `phase9f_import_scalar_ABI_allowlist_and_patch21_9_call_result_type_validation`
- Correction: `replace_obsolete_void_import_witness_with_unsupported_usize_return_import_witness`
- Changes Compiler Semantics: `false`
- Falsifier: `the_focused_phase9f_schema_guard_and_replacement_phase9_core_Historical_Full_shard_pass_without_validator_or_compiler_change`
- Boundary: `negative_fixture_and_guard_expectation_only_no_validator_compiler_MIR_backend_ABI_layout_runtime_symbol_seed_default_backend_Stdlib_CR15_or_phase22_change`

### Patch 21.17e

- Status: `complete`
- Capability: `historical_driver_handshake_inventory_reconciliation`
- Trigger Run Id: `33194593462`
- Failed Guard: `guard-cranelift-phase10-driver-handshake-contract`
- Failure Class: `guard_froze_pre_patch21_14_worker_capability_inventory`
- Existing Authority: `patch21_14_full_program_canonical_MIR_worker_inventory`
- Correction: `require_gust_compiler_executable_mir_v1_and_exact_3_28_16_19_3_worker_inventory`
- Changes Compiler Semantics: `false`
- Falsifier: `the_focused_phase10_handshake_guard_and_replacement_phase10_Historical_Full_shard_pass_without_worker_validator_or_compiler_change`
- Boundary: `guard_inventory_expectation_only_no_worker_validator_compiler_MIR_backend_ABI_layout_runtime_symbol_seed_default_backend_Stdlib_CR15_or_phase22_change`

## OD-8

- Status: `design_set_evidence_open`
- Design authority: `docs/VISION.md_section_56_2`
- Obligation: `every_query_rooted_at_a_scoped_entity_carries_an_independent_compile_time_scope_obligation`
- Discharge: `matching_non_forgeable_typed_Scope_provenance_derived_from_the_trusted_request_context_only`
- Syntax policy: `a_tenant_predicate_or_arbitrary_user_controlled_value_never_discharges_an_obligation`
- Join policy: `every_scoped_join_root_carries_its_own_obligation`
- Nesting policy: `every_nested_query_carries_its_own_obligation`
- Cross-tenant policy: `explicit_capability_gated_non_ambient_and_visible_at_the_call_site`
- Rejection policy: `compiler_error_at_the_query`
- Claim scope: `compiler_owned_typed_query_path_only`
- Demo target contract: `typed_query_negative_not_raw_sql_and_exact_surface_deferred_to_21_3`
- Excluded claims:
  - `caches`
  - `non_query_reads`
  - `multi_step_flows`
  - `unsafe_or_raw_SQL`
  - `trusted_request_context_establishment`
- Positive verdict gate: `implemented_analysis_survives_the_complete_predefined_section_56_1_adversarial_suite`
- Negative verdict gate: `one_in_scope_compiling_leak_counterexample`
- Successor evidence verdict: `resolved_2026_08_25_bounded_positive`

## OD-15

- Status: `resolved_2026_08_27_strict_binary_identity`
- Question: `native_stage_binary_identity_or_bounded_semantic_reproducibility`
- Criterion: `independently_produced_native_stages_are_byte_identical_under_the_pinned_authoritative_environment`
- Pinned authoritative environment:
  - `exact_source_commit`
  - `cranelift_and_toolchain_versions`
  - `target`
  - `flags`
  - `runtime_package`
  - `linker`
  - `normalized_environment`
- Cross-environment policy: `a_separately_bounded_semantic_reproducibility_contract_may_cover_cross_machine_or_cross_toolchain_builds_but_cannot_weaken_phase21_closure`
- Decision patch: `21.16`
- Blocks: `none`

## Roadmap-patch boundary

- `roadmap_patch_changes_compiler_semantics`: `false`
- `roadmap_patch_changes_mir_or_backends`: `false`
- `roadmap_patch_changes_abi_layout_or_runtime_symbols`: `false`
- `roadmap_patch_changes_bootstrap_seed`: `false`
- `roadmap_patch_edits_stdlib`: `false`
- `phase22_default_backend_flip`: `out_of_scope`
