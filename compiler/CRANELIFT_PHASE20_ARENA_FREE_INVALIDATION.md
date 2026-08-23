# Cranelift Phase 20 Arena.Free Receiver Invalidation

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_arena_free.py project`. Do not edit by hand.

- Authority version: `phase20_arena_free_invalidation_v1`
- Status: `patch20_5_complete`
- Next patch: `20.6`
- Issue: `CR-13/#160`
- Diagnostic: `[ArenaUseAfterFree]`

## Semantic correction

The first immediate `Arena.Free` transitions its canonical receiver
identity from live to freed. Allocation, Clone destination use, write,
and repeated Free consult the same record and are rejected after that
transition. Local aliases, selector fields, and function parameters
cannot create a fresh identity, while a distinct arena remains live.

A deferred Free is checked and observed at its source position but does
not transition early; existing `defer ctx.Free()` programs retain their
scope-exit meaning.

## Evidence

Every rejected fixture produces exactly one identical frontend
`ArenaUseAfterFree` diagnostic for default MIR-to-C, explicit MIR-to-C,
and direct Cranelift requests before backend selection. The accepted
two-arena program returns 37 through MIR-to-C; its selected canonical
MIR returns 37 through Cranelift. The direct accepted generic-source
Cranelift route remains explicitly deferred with no C fallback.
