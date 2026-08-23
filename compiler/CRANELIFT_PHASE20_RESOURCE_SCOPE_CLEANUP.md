# Cranelift Phase 20 Generic Resource Scope Cleanup

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_resource_scope_cleanup.py project`. Do not edit by hand.

- Authority version: `phase20_resource_scope_cleanup_v1`
- Status: `patch20_10_complete`
- Next patch: `20.11`
- Issue: `CR-5/#106`
- Enforcement enabled: `true`

## Compiler-owned cleanup plan

The typechecker transports each acquisition identity to its final owned
storage and records structured cleanup actions at lexical blocks and
returns. Code generation consumes those actions mechanically. Inner
scopes run first; declarations and resource fields run in reverse order.

Return expressions are evaluated before cleanup. Manual destruction,
moves, owned-argument transfer, returned ownership, and explicit defer
are terminal states and therefore cannot also receive automatic cleanup.
Mixed live/terminal joins reject rather than risk a double destruction.
Stored fallible acquisitions clean their payload only when `.Ok`.

Directory resources use the same plan. `open_directories` remains only
write-only compatibility storage and has no semantic enforcement read.
Phase 15 canonical cleanup parity remains the MIR-to-C/Cranelift consumer
agreement authority; generic source cohorts still preserve explicit
Cranelift no-fallback deferrals where their unrelated source lowering is
not yet selected.
