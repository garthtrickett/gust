# Cranelift Phase 22 Default-Route Seed Convergence

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase22_default_route_seed_convergence.py project`. Do not edit by hand.

- Contract: `phase22_default_route_seed_convergence_v1`
- Status: `patch22_6a_complete`
- Next patch: `22.7`
- Accounted authority: `phase22_default_route_flip_v1`
- Observed main: `e521f4f660acf59aff7e07f79a9567c73ffb0b2b`
- Previous seed commit: `ec60ea2b496681b5c60d702d1f1cb46fdab8982c`
- Previous seed digest: `58006d413edcf55bf0c89e04a2cd7cadb547c1325000cdb07bc117d45822e9e1`
- Converged seed digest: `c2e2cd6d5043af87aacc007d92b105d673bbeea7e8f484a61e18126f39a32383`
- Fixed-point policy: `make_bootstrap_stage2_stage3_byte_identity`
- Bootstrap route: `explicit_mir_to_c`
- Seed-only policy: `generated_seed_and_seed_specific_authority_only`

## Historical validator handoff

- `scripts/phase19_seed_convergence.py`
- `scripts/phase20_seed_convergence.py`
- `scripts/phase20_post_prerequisite_seed_convergence.py`
- `scripts/phase20_protected_access_seed_convergence.py`
- `scripts/phase21_tenant_scope_seed_convergence.py`
- `scripts/phase21_native_feature_seed_convergence.py`

## Generated seed diff

- Previous lines: 62917
- Current lines: 64825
- Insertions: 2094
- Deletions: 186
- Net line delta: 1908

The regenerated seed serializes the final Patch 22.6 compiler sources.
Stage 2 and stage 3 are byte-identical through explicit MIR-to-C. A
compiler rebuilt directly from this seed reports Cranelift as the
default, identifies both explicit C spellings as the retained semantic
oracle, and promises no fallback. This patch adds no Gust semantics,
MIR or native lowering, ABI/layout/runtime symbol, default-route or
bootstrap-route change, Stdlib or CR-15 work, and does not begin 22.7.
