# Cranelift Phase 20 Generic Guard Prerequisites

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_generic_guard_prerequisites.py project`. Do not edit by hand.

- Authority version: `phase20_generic_guard_prerequisites_v2`
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

## Backend and historical decision boundary

The accepted source returns 37 through MIR-to-C; the same selected
observable returns 37 through supported canonical MIR and Cranelift.
During Patch 20.14a, `Mutex.Lock()` still returned `RawPointer(T)` with
explicit `Unlock()` and OD-13 remained open. That phase-frozen fact is
retained by `decision_at_patch`; it is not current decision authority.

## Resolved successor and implementation boundary

The operator resolved OD-13 on 2026-08-24. Safe acquisition returns one
move-only linear guard carrying context-branded protected access and
owning automatic exactly-once unlock on every scope exit. The guard is
the authority; no separate compiler access token is introduced. Raw
pointer/manual unlock may remain only explicit unsafe or internal machinery.

Patch 20.16a records that decision without changing behaviour. Patches
20.16b–20.16e stage inert generic resource-rooted authority, whole-tree
raw-primitive migration, protected-access liveness enforcement, and
isolated seed convergence. The registrar handoff occurs only after checked
Patch 20.16d implementation authority lands. Stdlib API ergonomics remain
outside this record.
