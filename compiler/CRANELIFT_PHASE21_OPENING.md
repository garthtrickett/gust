# Cranelift Phase 21 Opening Evidence

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase21_opening.py project`. Do not edit by hand.

- Contract: `phase21_opening_evidence_v1`
- Status: `patch21_1_complete`
- Next patch: `21.2`
- Observed main: `736efd9c794352f855e799139f3a9672ee7ea2e0`
- Unclassified failures: `0`

## Track A inventory

- `scoped_entity_declaration` — `absent`
  - Owner: `compiler_typed_query_semantics`
  - Stable reason: `no_compiler_AST_parser_or_type_environment_record_for_a_scoped_entity`
  - Expected transition: `21.2_inert_record_then_21.3_no_op_surface`
  - Falsifier: `a_source_declaration_records_a_compiler_owned_scoped_entity_identity`
- `trusted_scope_provenance` — `absent`
  - Owner: `compiler_typed_query_semantics`
  - Stable reason: `lexical_typechecker_Scope_is_not_a_non_forgeable_tenant_Scope_value`
  - Expected transition: `21.2_inert_record_then_21.4_enforcement`
  - Falsifier: `ordinary_source_cannot_forge_or_substitute_a_trusted_Scope_Workspace_value`
- `typed_query_root_predicate_and_terminal` — `absent`
  - Owner: `compiler_typed_query_semantics`
  - Stable reason: `no_compiler_owned_query_expression_or_root_obligation_exists`
  - Expected transition: `21.2_inert_record_then_21.3_no_op_surface`
  - Falsifier: `a_scoped_root_predicate_and_terminal_query_round_trip_through_the_compiler`
- `predicate_provenance_discharge` — `absent`
  - Owner: `compiler_typed_query_semantics`
  - Stable reason: `ordinary_value_equality_has_no_query_obligation_or_provenance_meaning`
  - Expected transition: `21.4_enforcement`
  - Falsifier: `only_matching_trusted_Scope_provenance_discharges_a_scoped_root`
- `scoped_join_root_obligation` — `absent`
  - Owner: `compiler_typed_query_semantics`
  - Stable reason: `no_query_join_tree_or_per_root_obligation_set_exists`
  - Expected transition: `21.5_enforcement`
  - Falsifier: `each_scoped_join_root_retains_an_independent_obligation`
- `nested_query_obligation` — `absent`
  - Owner: `compiler_typed_query_semantics`
  - Stable reason: `no_nested_query_identity_or_obligation_boundary_exists`
  - Expected transition: `21.5_enforcement`
  - Falsifier: `every_nested_query_retains_its_own_scoped_root_obligations`
- `query_value_obligation_preservation` — `absent`
  - Owner: `compiler_typed_query_semantics`
  - Stable reason: `queries_are_not_values_and_no_obligation_set_can_flow_or_join`
  - Expected transition: `21.5_enforcement_or_conservative_rejection`
  - Falsifier: `query_values_preserve_complete_obligations_or_reject_before_laundering`
- `cross_tenant_capability_marker` — `absent`
  - Owner: `compiler_typed_query_semantics`
  - Stable reason: `no_non_ambient_query_site_cross_tenant_capability_marker_exists`
  - Expected transition: `21.6_enforcement`
  - Falsifier: `cross_tenant_typed_queries_require_an_explicit_non_forgeable_call_site_capability`
- `query_site_rejection_diagnostic` — `absent`
  - Owner: `compiler_typed_query_semantics`
  - Stable reason: `no_query_node_exists_at_which_to_attach_the_OD8_diagnostic`
  - Expected transition: `21.4_through_21.6`
  - Falsifier: `a_missing_wrong_or_laundered_scope_is_rejected_at_the_query`
- `general_uses_clause_and_db_read_effect` — `absent_classified_outside_phase21_OD8_implementation`
  - Owner: `compiler_effect_semantics_future_roadmap`
  - Stable reason: `FunctionSignature_has_inert_internal_requires_fields_but_no_user_uses_clause_or_db_read_effect`
  - Expected transition: `future_explicitly_activated_effect_roadmap_not_phase21`
  - Falsifier: `parser_AST_and_call_graph_check_a_user_uses_db_read_effect_clause`
- `trusted_request_context_establishment` — `excluded_from_typed_query_guarantee`
  - Owner: `trusted_host_boundary`
  - Stable reason: `operator_explicitly_excluded_authentication_and_scope_establishment_from_OD8`
  - Expected transition: `no_phase21_transition`
  - Falsifier: `none_exclusion_is_a_claim_boundary_not_a_compiler_capability`
- `unsafe_or_raw_SQL` — `excluded_from_typed_query_guarantee`
  - Owner: `explicit_privileged_boundary`
  - Stable reason: `operator_explicitly_excluded_raw_SQL_from_compiler_owned_typed_query_analysis`
  - Expected transition: `no_phase21_transition`
  - Falsifier: `none_exclusion_is_a_claim_boundary_not_a_compiler_capability`

## Executable query-shaped baselines

- `trusted_scope_shape` — `accepted_as_ordinary_user_values_not_as_a_typed_query`
  - Fixture: `compiler/phase21_query_shape_trusted_baseline.gst`
  - Current exits: MIR-to-C `21`, Cranelift `21`
  - Intended verdict: `accept_with_matching_trusted_scope_provenance`
  - Expected transition: `21.3_surface_then_21.4_positive_enforcement`
  - Falsifier: `the_equivalent_typed_query_accepts_only_from_matching_trusted_Scope_provenance`
- `untrusted_scope_shape` — `accepted_as_ordinary_user_values_and_returns_the_leak_marker`
  - Fixture: `compiler/phase21_query_shape_untrusted_baseline.gst`
  - Current exits: MIR-to-C `99`, Cranelift `99`
  - Intended verdict: `reject_at_query_despite_matching_predicate_syntax`
  - Expected transition: `21.3_surface_then_21.4_query_site_rejection`
  - Falsifier: `the_equivalent_typed_query_rejects_an_arbitrary_user_controlled_scope_value_at_the_query`

## Inherited Phase 20 residues

- `collections` — `deferred` / `deferred_p13_structured_cfg_non_reducible_shape`
  - Fixture: `compiler/phase20_component_collections_source.gst`
  - Owner: `phase13_generic_source_to_mir`; transition: `21.9`
  - Stable reason: `deferred_p13_structured_cfg_non_reducible_shape` at `before_driver_discovery`
  - Falsifier: `a_real_Vector_or_HashMap_source_program_reaches_the_native_driver_and_its_full_observable_differential_passes`
- `strings` — `deferred` / `deferred_p13_structured_cfg_condition_shape`
  - Fixture: `compiler/phase20_component_strings_source.gst`
  - Owner: `phase13_generic_source_to_mir`; transition: `21.9`
  - Stable reason: `deferred_p13_structured_cfg_condition_shape` at `before_driver_discovery`
  - Falsifier: `a_real_string_utility_source_program_reaches_the_native_driver_and_its_full_observable_differential_passes`
- `filesystem` — `deferred` / `source_feature_not_represented`
  - Fixture: `compiler/phase20_component_filesystem_source.gst`
  - Owner: `phase13_generic_source_to_mir`; transition: `21.10`
  - Stable reason: `source_feature_not_represented` at `before_driver_discovery`
  - Falsifier: `a_sandboxed_file_IO_source_program_reaches_the_native_driver_and_its_exact_filesystem_tree_differential_passes`
- `allocation` — `deferred` / `source_feature_not_represented`
  - Fixture: `compiler/phase20_component_allocation_source.gst`
  - Owner: `phase13_generic_source_to_mir`; transition: `21.10`
  - Stable reason: `source_feature_not_represented` at `before_driver_discovery`
  - Falsifier: `a_real_Arena_allocation_and_write_source_program_reaches_the_native_driver_and_its_full_observable_differential_passes`
- `resources` — `source_or_type_failure` / `source_or_type_failure`
  - Fixture: `compiler/phase20_resource_scope_cleanup_source.gst`
  - Owner: `phase13_generic_source_to_mir`; transition: `21.11`
  - Stable reason: `source_or_type_failure_unsupported_top_level_statement_in_module_import_cohort` at `before_driver_discovery`
  - Falsifier: `a_source_declared_Resource_program_reaches_the_native_driver_and_its_terminal_state_and_cleanup_differential_passes`
- `threading_synchronization` — `deferred` / `deferred_p13_parameter_argument_target_dependent_abi`
  - Fixture: `compiler/phase20_component_threading_source.gst`
  - Owner: `phase13_generic_source_to_mir`; transition: `21.11`
  - Stable reason: `deferred_p13_parameter_argument_target_dependent_abi` at `before_driver_discovery`
  - Falsifier: `a_real_Mutex_or_Channel_source_program_reaches_the_native_driver_and_its_deterministic_invariant_differential_passes`

## Full compiler explicit-Cranelift baseline

- Source: `compiler/test_runner_entry.gst:238:1`
- Exit: `1`; artifact: `absent`
- Decision: `source_or_type_failure` / `source_or_type_failure`
- Diagnostic class: `canonical_mir_verification_error`
- Diagnostic: `Native backend canonical MIR verification failed: unsupported top-level statement in module/import cohort`
- Failure stage: `before_driver_discovery`
- Owner: `compiler_generic_native_capability_planner`
- Expected transition: `21.8_through_21.14_classify_and_migrate_the_complete_compiler_dependency_graph`
- Falsifier: `the_full_compiler_reaches_the_native_driver_and_publishes_a_linked_native_compiler_artifact`

The two query-shaped programs are executable ordinary-language
baselines, not a typed-query syntax decision or an OD-8 pass. Their
purpose is to preserve the currently indistinguishable trusted and
attacker-controlled value flows before Patch 21.3 supplies the no-op
surface and Patch 21.4 enables provenance enforcement.
