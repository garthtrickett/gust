# Cranelift Phase 20 Post-Prerequisite Seed Convergence

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_post_prerequisite_seed_convergence.py project`. Do not edit by hand.

- Contract: `phase20_post_prerequisite_seed_convergence_v1`
- Status: `patch20_14b_complete`
- Next patch: `20.15`
- Accounted patch: `20.14a`
- Previous seed commit: `958262bc42e33f83a79d828a629e582528e334e7`
- Fixed-point policy: `make_bootstrap_stage2_stage3_byte_identity`
- Seed-only policy: `generated_seed_and_seed_specific_authority_only`

## Generated seed diff

- Previous lines: 59502
- Current lines: 59520
- Insertions: 63
- Deletions: 45
- Net line delta: 18

This isolated regeneration accounts only for the self-hosted compiler
correction in Patch 20.14a. It changes no Gust semantics, Stdlib API,
MIR, ABI/layout, runtime symbol, backend, target, or linker policy.
