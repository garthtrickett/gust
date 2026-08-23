# Cranelift Phase 20 Resource Acquisition Obligations

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_resource_acquisition.py project`. Do not edit by hand.

- Authority version: `phase20_resource_acquisition_obligations_v3`
- Status: `patch20_10_complete`
- Next patch: `20.11`
- Issue: `CR-5/#106`
- Enforcement enabled: `true`

## Acquisition identity

A tracking-eligible call expression creates one stable obligation
identity from its source location. Binding, assignment, aliases,
aggregate storage, payload extraction, guards, owned arguments, and
returns transport that identity instead of creating binding-local
copies. A fallible guard or direct success-flag failure path carries
no successful acquisition; its success payload inherits the pending
identity.
Ordinary branch and loop exits conservatively join pending and
terminal states, so consumption on one reachable path cannot
discharge another path.

An owned resource argument transfers the caller identity and creates
a pending obligation for the callee parameter. The validated
destructor is the terminal operation and does not recursively acquire
another obligation.

Patch 20.10 consumes stored obligations with automatic cleanup.
Both #106 directory shapes, a user-declared bound owner, and an
otherwise empty by-value callee now compile with exactly-once cleanup.
Ignored directory and user-resource
calls reject at full-expression end with
`ResourceAcquisitionDiscarded`. A non-resource call remains accepted.

## Scope cleanup successor

Patch 20.10 uses these identities as the inputs to compiler-owned
structured cleanup plans. Mixed live/terminal joins still reject,
while stored fallible acquisitions clean `.Val` only when `.Ok`.
