# Cranelift Phase 21 Tenant-Scope Seed Convergence

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase21_tenant_scope_seed_convergence.py project`. Do not edit by hand.

- Contract: `phase21_tenant_scope_seed_convergence_v1`
- Status: `patch21_7a_complete`
- Next patch: `21.8`
- Accounted authority: `phase21_od8_adversarial_verdict_v1`
- Previous seed commit: `02fead71a87f0148d4290ee12e84973931c400e8`
- Fixed-point policy: `make_bootstrap_stage2_stage3_byte_identity`
- Seed-only policy: `generated_seed_and_seed_specific_authority_only`

## Generated seed diff

- Previous lines: 59706
- Current lines: 60470
- Insertions: 841
- Deletions: 77
- Net line delta: 764

## Accounted patch range

- Patch 21.1: `opening_evidence_and_typed_query_baseline_fixtures`
- Patch 21.2: `inert_scoped_query_semantic_records`
- Patch 21.3: `typed_query_noop_surface`
- Patch 21.4: `trusted_scope_provenance_enforcement`
- Patch 21.5: `per_root_join_nested_and_query_value_obligations`
- Patch 21.6: `explicit_cross_tenant_capability_boundary`
- Patch 21.7: `adversarial_verdict_fixtures_and_authority_without_new_semantics`

This isolated regeneration serializes the completed Phase 21 Track A
self-hosted compiler changes through Patch 21.7. Stage 2 and stage 3
must remain byte-identical in the authoritative seed workflow. The
patch adds no Gust semantics, Stdlib API, MIR/backend behavior,
ABI/layout, or runtime symbol.
