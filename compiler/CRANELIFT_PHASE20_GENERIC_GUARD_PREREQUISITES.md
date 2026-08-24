# Cranelift Phase 20 Generic Guard Prerequisites

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_generic_guard_prerequisites.py project`. Do not edit by hand.

- Authority version: `phase20_generic_guard_prerequisites_v1`
- Status: `patch20_14a_complete`
- Next patch: `20.14b`

## Corrections

A generic Resource destructor parameter is checked against the canonical
declared template after its brand parameter is substituted. A safe
reference parameter whose pointee carries the same resolved brand keeps
safe-parameter provenance through aggregate field assignment and return.

The change does not weaken non-laundering: raw-derived and sandbox-derived
references remain rejected. Wrong owned types and wrong brands remain
`ResourceDestructorSignature` failures. There is no Mutex-specific path.

## Backend and open-decision boundary

The accepted source returns 37 through MIR-to-C; the same selected
observable returns 37 through supported canonical MIR and Cranelift.
`Mutex.Lock()` still returns `RawPointer(T)` with explicit `Unlock()`.
OD-13 remains open and Patch 20.14a makes no Stdlib API, MIR, ABI, layout,
or runtime-symbol decision. The compiler-source change is followed by
the isolated Patch 20.14b seed reconvergence before Patch 20.15.
