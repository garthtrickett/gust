# Cranelift Phase 20 Arena Lifecycle Observation Authority

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_arena_lifecycle.py project`. Do not edit by hand.

- Authority version: `phase20_arena_lifecycle_observation_v1`
- Status: `patch20_4_complete_observation_only`
- Next patch: `20.5`
- Issue: `CR-13/#160`

## Identity and lifecycle authority

Arena lifecycle records are keyed by canonical, function-scoped arena
identity. Locals, aliases, selector fields, parameters, and resolved
generic brand substitutions map back to that record; identical source
spellings in distinct scopes do not collapse.

The authority represents both `live` and `freed`, and observes:

- `allocation`
- `clone_destination`
- `write`
- `free`

## Deliberate non-enforcement

Patch 20.4 only increments observation counters. In particular, an
observed `Arena.Free` leaves the lifecycle state `live`, the CR-13
opening witness remains accepted, and no new diagnostic is emitted.
Patch 20.5 exclusively owns the transition to `freed` and rejection of
later use through every alias.
