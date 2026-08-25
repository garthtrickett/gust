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

- Status: `open`
- Question: `native_stage_binary_identity_or_bounded_semantic_reproducibility`
- Decision patch: `21.16`
- Blocks: `21.18`

## Roadmap-patch boundary

- `roadmap_patch_changes_compiler_semantics`: `false`
- `roadmap_patch_changes_mir_or_backends`: `false`
- `roadmap_patch_changes_abi_layout_or_runtime_symbols`: `false`
- `roadmap_patch_changes_bootstrap_seed`: `false`
- `roadmap_patch_edits_stdlib`: `false`
- `phase22_default_backend_flip`: `out_of_scope`
