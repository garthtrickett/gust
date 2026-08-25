# Cranelift Phase 21 OD-8 Adversarial Soundness Verdict

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase21_od8_adversarial_verdict.py project`. Do not edit by hand.

- Contract: `phase21_od8_adversarial_verdict_v1`
- Status: `patch21_7_complete`
- Next patch: `21.7a`
- Attack authority: `docs/VISION.md_section_56_1`
- Claim scope: `compiler_owned_typed_query_path_only`
- OD-8 status: `resolved_2026_08_25_bounded_positive`
- Verdict: `complete_predefined_in_scope_suite_found_no_compiling_leak_counterexample`
- Evidence date: `2026-08-25`
- In-scope counterexamples: `0`

## In-scope attacks

### `provenance_authenticity`

- Claim boundary: `matching_nonforgeable_typed_Scope_provenance_at_the_compiler_owned_query_predicate`
- Outcome: `no_counterexample`
- `trusted_scope_positive` — `compiler/phase21_trusted_scope_positive.gst` — accepted; MIR-to-C exit `41`, Cranelift exit `41`
- `deserialized_or_attacker_controlled_value` — `compiler/phase21_trusted_scope_arbitrary_invalid.gst` — rejected with `[TenantScopeProvenance]`
- `cast_from_attacker_value` — `compiler/phase21_trusted_scope_cast_invalid.gst` — rejected with `[TenantScopeProvenance]`
- `wrong_scope_identity` — `compiler/phase21_trusted_scope_wrong_identity_invalid.gst` — rejected with `[TenantScopeProvenance]`
- `copied_predicate_spelling` — `compiler/phase21_trusted_scope_syntax_only_invalid.gst` — rejected with `[TenantScopeProvenance]`
- `copy_laundering` — `compiler/phase21_od8_trusted_scope_copy_invalid.gst` — rejected with `[TrustedScopeBoundary]`
- `aggregate_storage_laundering` — `compiler/phase21_od8_trusted_scope_store_invalid.gst` — rejected with `[TrustedScopeBoundary]`
- `return_laundering` — `compiler/phase21_od8_trusted_scope_return_launder_invalid.gst` — rejected with `[TrustedScopeBoundary]`
- `reserved_intrinsic_redefinition` — `compiler/phase21_trusted_scope_reserved_intrinsic_invalid.gst` — rejected with `[ReservedCompilerIntrinsic]`

### `privileged_boundary_transitivity`

- Claim boundary: `implemented_typed_query_host_capability_only_raw_SQL_itself_is_outside_the_claim`
- Outcome: `implemented_privileged_typed_query_capability_is_nontransitive`
- `ordinary_helper` — `compiler/phase21_cross_tenant_helper_invalid.gst` — rejected with `[CrossTenantCapability]`
- `reexport` — `compiler/phase21_cross_tenant_reexport_invalid.gst` — rejected with `[CrossTenantCapabilityBoundary]`
- `outside_marker` — `compiler/phase21_cross_tenant_outside_marker_invalid.gst` — rejected with `[CrossTenantCapabilityBoundary]`

### `joins`

- Claim boundary: `every_scoped_join_root_has_its_own_obligation_while_unscoped_lookup_roots_add_none`
- Outcome: `no_counterexample`
- `missing_scoped_join_scope` — `compiler/phase21_join_obligation_missing_invalid.gst` — rejected with `[TenantScopeProvenance]`
- `sibling_scope_reuse` — `compiler/phase21_join_sibling_isolation_invalid.gst` — rejected with `[TenantScopeProvenance]`
- `unscoped_primary_scoped_join` — `compiler/phase21_od8_unscoped_primary_scoped_join_invalid.gst` — rejected with `[TenantScopeProvenance]`
- `scoped_primary_unscoped_lookup` — `compiler/phase21_unscoped_join_positive.gst` — accepted; MIR-to-C exit `54`

### `nesting`

- Claim boundary: `every_nested_query_is_an_independent_obligation_boundary`
- Outcome: `no_counterexample`
- `outer_scope_does_not_clear_inner` — `compiler/phase21_nested_obligation_missing_invalid.gst` — rejected with `[TenantScopeProvenance]`
- `outer_cross_tenant_marker_does_not_clear_inner` — `compiler/phase21_cross_tenant_nested_nontransitive_invalid.gst` — rejected with `[TenantScopeProvenance]`
- `independently_scoped_nested_aggregate` — `compiler/phase21_nested_aggregate_positive.gst` — accepted; MIR-to-C exit `55`, Cranelift exit `55`

### `queries_as_values`

- Claim boundary: `unresolved_obligations_are_rejected_before_terminal_projection_or_value_flow`
- Outcome: `no_counterexample`
- `unresolved_alias` — `compiler/phase21_query_value_unresolved_invalid.gst` — rejected with `[TenantScopeProvenance]`
- `unresolved_branch_return` — `compiler/phase21_query_value_branch_invalid.gst` — rejected with `[TenantScopeProvenance]`
- `fully_discharged_branch_alias_return` — `compiler/phase21_query_value_flow_positive.gst` — accepted; MIR-to-C exit `52`

### `legitimate_cross_tenant_path`

- Claim boundary: `direct_nonambient_host_capability_visible_at_the_owning_query`
- Outcome: `no_counterexample`
- `direct_capability` — `compiler/phase21_cross_tenant_capability_positive.gst` — accepted; MIR-to-C exit `71`, Cranelift exit `71`
- `forged_capability_value` — `compiler/phase21_cross_tenant_forged_invalid.gst` — rejected with `[CrossTenantCapability]`
- `wrong_arity_host_call` — `compiler/phase21_cross_tenant_wrong_arity_invalid.gst` — rejected with `[CrossTenantCapability]`

### `dynamic_shape`

- Claim boundary: `typed_query_entity_and_field_shape_is_static_syntax_not_runtime_input`
- Outcome: `no_counterexample`
- `computed_root` — `compiler/phase21_od8_dynamic_shape_invalid.gst` — rejected with `Expected scoped entity name after query root`
- `computed_column` — `compiler/phase21_od8_dynamic_column_invalid.gst` — rejected with `Expected expression after query predicate`

## Explicitly out-of-scope probes

- `unsafe_raw_SQL` — `explicit_privileged_boundary_outside_typed_query_analysis_not_counted_as_a_pass`
  - Authority: `docs/VISION.md_sections_56_2_and_57`
- `result_cache` — `outside_query_analysis_not_counted_as_a_pass`
  - Authority: `docs/VISION.md_section_56_1_class_5`
- `multi_step_flows` — `outside_single_query_obligation_analysis_not_counted_as_a_pass`
  - Authority: `docs/VISION.md_section_56_1_class_6`
- `non_query_reads` — `outside_compiler_owned_typed_query_path_not_counted_as_a_pass`
  - Authority: `docs/VISION.md_section_56_1_class_8`
- `trusted_context_establishment` — `host_authentication_and_scope_selection_outside_compiler_claim_not_counted_as_a_pass`
  - Authority: `docs/VISION.md_section_56_1_class_10`

## Bounded verdict

The complete predefined in-scope suite produced no compiler-owned
typed-query program that compiled while lacking its required matching
trusted Scope provenance. OD-8 therefore has a bounded positive verdict
for that path only. This is generated conformance evidence, not formal
proof and not a claim about the explicitly excluded probes above.

Patch 21.7 changes no compiler semantics, MIR, backend behavior, ABI,
layout, runtime symbol, bootstrap seed, database runtime, or Stdlib API.
