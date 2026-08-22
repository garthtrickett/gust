# Cranelift Phase 19 Compiler Self-Compilation Differential

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase19_self_compilation.py project`. Do not edit by hand.

- Contract: `phase19_self_compilation_differential_v1`
- Status: `ready_for_patch19_11`
- Next patch: `19.11`
- Level 3 owner: `Cranelift Historical Full`

## Complete compiler-source differential

Historical Full rebuilds the self-hosted compiler at the converged Phase 19.2
baseline and at every Phase 19.3–19.8 merge boundary. Each transition writes
a complete unified C diff named for its owning patch. The guard also rejects
any compiler-source commit whose subject is not assigned to that transition,
requires the baseline build to reproduce its seed, and requires the final
build to reproduce the current converged seed.

The complete baseline-to-current C diff contains 15016 insertions
and 14678 deletions, with 0 unexplained differences.

## Patch attribution

- Patch 19.3 / PR #144 — `phase19: construct canonical branded type names`
- Patch 19.4 / PR #145 — `Phase 19.4 derive classification from resolved types`; `Register synthetic container fixture metadata`
- Patch 19.5 / PR #146 — `phase19: add inert call representation fields`; `phase19: migrate argument representation consumers`; `phase19: enforce canonical argument representation`; `fix: preserve reference argument representation`
- Patch 19.6 / PR #147 — `feat: converge self-hosted spelling rules`
- Patch 19.7 / PR #148 — no compiler-source change
- Patch 19.8 / PR #149 — `phase19: remove self-hosted brand name list`; `fix: resolve ambiguous flattened template brands`

Patch 19.7 is intentionally the zero-diff transition. Any added, removed, or
reordered compiler-source commit, any missing boundary, any seed mismatch, or
any unlabelled transition makes the Level 3 guard fail.
