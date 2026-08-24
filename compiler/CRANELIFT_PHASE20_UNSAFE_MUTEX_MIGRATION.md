# Cranelift Phase 20 Explicit-Unsafe Mutex Primitive Migration

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_unsafe_mutex_migration.py project`. Do not edit by hand.

- Contract: `phase20_unsafe_mutex_migration_v1`
- Status: `patch20_16c_complete`
- Next patch: `20.16d`
- Scope: `every_git_tracked_gust_source_file`
- Calls: `24` (`12` Lock, `12` Unlock)

## Complete classified inventory

- `compiler/e2e_complex_bootstrap_target.gst` — `bootstrap_target`; Lock `4`, Unlock `4`
- `compiler/phase20_component_threading_source.gst` — `compiler_threading_compile_only_fixture`; Lock `1`, Unlock `1`
- `tests/e2e_mutex_concurrency.gst` — `transitional_mutex_test`; Lock `3`, Unlock `3`
- `tests/e2e_sync_primitives.gst` — `transitional_sync_test`; Lock `4`, Unlock `4`

Every tracked Gust call spelled `.Lock(` or `.Unlock(` is lexically
inside an explicit `unsafe` block or unsafe function body. The scanner
masks comments and literals, handles inline and whitespace-separated
unsafe blocks, and rejects both unclassified calls and classified calls
that escape the unsafe context.

All 24 sites were already explicit unsafe because earlier raw-pointer
migration wrapped the dereference performed between Lock and Unlock.
Patch 20.16c therefore freezes the complete migration as a semantic no-op
without rewriting source. The two `tests/` fixtures remain transitional
raw/manual coverage, not the future safe API contract.

## Enforcement and backend boundary

Safe-call enforcement remains disabled. `Mutex.Lock()` still returns a
raw pointer; Lock/Unlock lowering, runtime symbols, ABI/layout, MIR, and
all existing observables remain unchanged. Patch 20.16d is the only next
boundary authorized to enable generic protected-access liveness and raw
primitive unsafe-call enforcement. Seed reconvergence remains isolated in
Patch 20.16e.
