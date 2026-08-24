# Cranelift Phase 20 Inert Resource-Rooted Access Authority

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_resource_rooted_access.py project`. Do not edit by hand.

- Contract: `phase20_resource_rooted_access_v1`
- Status: `patch20_16b_complete`
- Next patch: `20.16c`
- Carrier: `ExpressionProvenance.resource_root_identity`
- Root authority: `ResourceAcquisitionObligation.identity`

## Inert semantic carrier

`ExpressionProvenance` may carry the canonical acquisition identity of
the linear Resource guard that authorizes protected access. Safe readback
preserves that identity. A control-flow join preserves it only when both
paths carry the same non-empty identity, so a conditional path cannot
invent universal authority. Guard rebinding continues to name the same
acquisition obligation; terminal obligation state is observable as not live.

No live typechecking path constructs this metadata in Patch 20.16b. The
new helpers emit no diagnostic and enable no rejection. `Mutex.Lock()`
still returns `RawPointer(T)`, raw Lock/Unlock lowering and every call site
remain unchanged, and no separate access token or Mutex-specific Resource
path exists.

## Backend and bootstrap boundary

The existing generic-guard source observable remains identical through
MIR-to-C and supported Cranelift without fallback. The checked-in seed
builds the additive carrier; generated reconvergence remains isolated in
Patch 20.16e after migration and enforcement. Patch 20.16c is the next
authorized boundary and owns only whole-tree explicit-unsafe migration.
