# Cranelift Phase 21 Native-Feature Seed Convergence

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase21_native_feature_seed_convergence.py project`. Do not edit by hand.

- Contract: `phase21_native_feature_seed_convergence_v1`
- Status: `patch21_13a_complete`
- Next patch: `21.14`
- Accounted authority: `phase21_selected_compiler_module_qualification_v1`
- Previous seed commit: `3c4028e04629a4af1b5010b7b0977b188f0afb6c`
- Fixed-point policy: `make_bootstrap_stage2_stage3_byte_identity`
- Seed-only policy: `generated_seed_and_seed_specific_authority_only`

## Generated seed diff

- Previous lines: 60470
- Current lines: 62917
- Insertions: 2501
- Deletions: 54
- Net line delta: 2447

## Accounted patch range

- Patch 21.7b: `cross_tenant_predicate_validation_reconciliation`
- Patch 21.8: `phase20_residue_migration_authority_and_compiler_graph_fixtures`
- Patch 21.9: `collection_string_native_source_migration_and_transport_corrections`
- Patch 21.10: `filesystem_allocation_native_source_migration_and_arena_access_corrections`
- Patch 21.11: `resource_synchronization_native_source_migration`
- Patch 21.12: `compiler_support_library_native_qualification_fixtures_and_authority`
- Patch 21.13: `selected_compiler_module_native_qualification_and_generic_declaration_admission`

This isolated regeneration serializes the self-hosted compiler and
native-feature source changes after Patch 21.7a through Patch 21.13.
Stage 2 and stage 3 remain byte-identical in the authoritative seed
workflow. The patch adds no Gust semantics, Stdlib or CR-15 change,
MIR/backend behavior, ABI/layout/runtime symbol, default-backend or
fallback change, and does not begin Patch 21.14.
