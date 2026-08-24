# Cranelift Phase 20 Protected-Access Liveness

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_protected_access_liveness.py project`. Do not edit by hand.

- Contract: `phase20_protected_access_liveness_v1`
- Status: `patch20_16d_complete`
- Next patch: `20.16e`
- Implementation authority landed: `true`

## Safe authority

A reference-returning call with exactly one live move-only Resource
guard receiver or argument inherits that guard's canonical acquisition
identity. Moving the guard preserves the identity and transfers the
obligation. Scalar copies cease to alias protected storage; references,
pointers, strings, slices, and aggregates retain the root.

Rooted access is rejected after terminal guard state. It cannot be
returned, stored in fields or containers, or passed through an unchecked
callee boundary. Multiple candidate guard roots are rejected as
ambiguous. This is generic Resource authority, not a Mutex special case
and not a separate access token.

## Mutex and cleanup boundary

Raw `Mutex.Lock()` and `Mutex.Unlock()` now require explicit `unsafe`.
Their lowering, runtime symbols, ABI, layout, and MIR remain unchanged.
The source oracle proves compiler-inserted destructor unlock exactly once
on normal, early-return, conditional, and selected failure exits. The
supported canonical-MIR/Cranelift probe exercises the same four unlocked
lifecycle cycles and shares exit observable `72`, without fallback.

## Handoff

After this patch is merged, the registrar may resume Stdlib S1.8 and
re-derive its work from checked compiler authority. This record does not
select Stdlib names, representation, re-entrancy, or accessor ergonomics.
Bootstrap seed reconvergence remains isolated in Patch 20.16e.
