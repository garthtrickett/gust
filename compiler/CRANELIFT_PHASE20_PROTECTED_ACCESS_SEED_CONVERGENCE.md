# Cranelift Phase 20 Protected-Access Seed Convergence

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_protected_access_seed_convergence.py project`. Do not edit by hand.

- Contract: `phase20_protected_access_seed_convergence_v1`
- Status: `patch20_16e_complete`
- Next patch: `20.17`
- Accounted authority: `phase20_protected_access_liveness_v1`
- Previous seed commit: `1588c07944468d7ef68e21b945540203a4d87595`
- Fixed-point policy: `make_bootstrap_stage2_stage3_byte_identity`
- Seed-only policy: `generated_seed_and_seed_specific_authority_only`

## Generated seed diff

- Previous lines: 59520
- Current lines: 59706
- Insertions: 234
- Deletions: 48
- Net line delta: 186

## Accounted patch range

- Patch 20.15: `long_lived_and_concurrent_resource_qualification_fixtures_and_authority`
- Patch 20.16: `cross_feature_resource_qualification_fixtures_and_authority`
- Patch 20.16a: `OD_13_decision_projection_without_compiler_semantic_change`
- Patch 20.16b: `inert_resource_root_carrier_in_the_self_hosted_typechecker`
- Patch 20.16c: `unsafe_Mutex_inventory_authority_without_compiler_semantic_change`
- Patch 20.16d: `protected_access_liveness_enforcement_and_fixtures`

This isolated regeneration accounts for every compiler-tree patch
since the Patch 20.14b seed through Patch 20.16d. It changes no new
Gust semantics, Stdlib API, MIR, ABI/layout, runtime symbol, backend,
target, or linker policy.
