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

## Phase 23 successor transition

- Contract: `phase23_diagnostic_seed_reconvergence_transition_v1`
- Status: `landed_post_publication`
- Authority base main: `d49cf1835972951b806621b798e7f905aa95df1a`
- Accounted compiler authorities: `phase23_structured_guard_defer_native_admission_v1, phase23_same_scope_declaration_v1`
- Seed PR policy: `gust_v4_c_only`
- Partial or unregistered identity: `rejected`
- Accepted `post_publication` identity: 64929 lines, `33b23ff4e8dab6c84365920bf3a2a674d7e3f5248646f6ffd69c8f7cc014083a`

## Phase 23 landed seed evidence

- Pull request: `#281`
- Exact head: `b3ce3637017e29074f34b8657e7e75d9e0a39ef9`
- Merge main: `5f0130fa24430e96da2425d05f24a8223e914f1d`
- Merged at: `2026-09-01T00:43:42Z`
- Event: `pull_request`
- Exact-head workflows: 21/21 successful, 0 unfinished, 0 non-success
- Unresolved non-outdated review threads: 0
- Changed paths: `gust_v4.c`

## Phase 23 deprecation seed transition

- Contract: `phase23_deprecation_seed_reconvergence_transition_v1`
- Status: `landed_post_publication`
- Authority base main: `e39ddaf86fe689a9817fb4ee50e6eab0c506139c`
- Accounted compiler authority: `phase23_mir_to_c_user_deprecation_v1`
- Seed PR policy: `gust_v4_c_only`
- Partial or unregistered identity: `rejected`
- Generated diff: 2 insertions, 2 deletions, 0 net lines
- Accepted `post_publication` identity: 64929 lines, `af8a283c9ef4dbe621f78729e89a4c7270c0b740aeb7164af57fa953e5f29924`

## Phase 23 deprecation landed seed evidence

- Pull request: `#289`
- Exact head: `ba040834dadef99982892016a2163d0296270a0a`
- Merge main: `3d9ed5df9188cf38275885a665316e58cfb9dd21`
- Merged at: `2026-09-01T08:53:43Z`
- Event: `pull_request`
- Exact-head workflows: 22/22 successful, 0 unfinished, 0 non-success
- Unresolved non-outdated review threads: 0
- Changed paths: `gust_v4.c`

## Phase 24 CR-15 seed transition

- Contract: `phase24_cr15_seed_reconvergence_transition_v1`
- Status: `ready_for_seed_publication`
- Authority base main: `10076805b56697304e7b236fff09cdf3689fcc05`
- Accounted compiler authorities: `phase24_cr15_derivation_v1, phase24_cr15_qualification_v1`
- Seed PR policy: `gust_v4_c_only`
- Partial or unregistered identity: `rejected`
- Generated diff: 1332 insertions, 472 deletions, 860 net lines
- Accepted `pre_publication` identity: 64929 lines, `af8a283c9ef4dbe621f78729e89a4c7270c0b740aeb7164af57fa953e5f29924`
- Accepted `post_publication` identity: 65789 lines, `706430d05010521657d44e0ee2afa2580afb71f1f5e8ca54a88f6e34f1a2e8d9`

The regenerated seed preserves the final Patch 22.6 default-route compiler
sources and serializes the registered Patch 23.3a guard/defer admission and
Patch 23.6 same-scope diagnostic authorities. Stage 2 and stage 3 are
byte-identical through explicit MIR-to-C. A
compiler rebuilt directly from this seed reports Cranelift as the
default, identifies both explicit C spellings as the retained semantic
oracle, and promises no fallback. This patch adds no Gust semantics,
MIR or native lowering, ABI/layout/runtime symbol, default-route or
bootstrap-route change, Stdlib or CR-15 work, and does not begin 22.7.
