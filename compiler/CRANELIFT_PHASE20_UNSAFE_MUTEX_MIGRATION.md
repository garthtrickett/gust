# Cranelift Phase 20 Explicit-Unsafe Mutex Primitive Migration

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_unsafe_mutex_migration.py project`. Do not edit by hand.

- Contract: `phase20_unsafe_mutex_migration_v1`
- Status: `patch20_16c_complete`
- Next patch: `20.16d`
- Scope: `every_git_tracked_gust_source_file`
- Current classified calls: `30` (`15` Lock, `15` Unlock)
- Patch 20.16c frozen baseline: `24`

## Complete classified inventory

- `compiler/e2e_complex_bootstrap_target.gst` — `bootstrap_target`; Lock `4`, Unlock `4`
- `compiler/phase20_component_threading_source.gst` — `compiler_threading_runtime_fixture`; Lock `2`, Unlock `2`
- `compiler/phase20_mutex_lock_safe_invalid.gst` — `patch20_16d_enforcement_negative`; Lock `1`, Unlock `0`
- `compiler/phase20_mutex_unlock_safe_invalid.gst` — `patch20_16d_enforcement_negative`; Lock `0`, Unlock `1`
- `compiler/phase20_protected_access_module.gst` — `patch20_16d_explicit_unsafe_lifecycle_fixture`; Lock `1`, Unlock `1`
- `tests/e2e_mutex_concurrency.gst` — `transitional_mutex_test`; Lock `3`, Unlock `3`
- `tests/e2e_sync_primitives.gst` — `transitional_sync_test`; Lock `4`, Unlock `4`

Every tracked Gust call spelled `.Lock(` or `.Unlock(` is classified.
All operational calls are lexically inside an explicit `unsafe` block
or unsafe function body; the only safe calls are the two exact Patch
20.16d enforcement-negative fixtures. The scanner
masks comments and literals, handles inline and whitespace-separated
unsafe blocks, and rejects both unclassified calls and classified calls
that escape the unsafe context.

The 24-call Patch 20.16c baseline was already explicit unsafe because earlier raw-pointer
migration wrapped the dereference performed between Lock and Unlock.
Patch 20.16c therefore freezes the complete migration as a semantic no-op
without rewriting source. Patch 20.16d adds two explicit-unsafe
lifecycle calls and the two classified safe rejection witnesses. The
two `tests/` fixtures remain transitional
raw/manual coverage, not the future safe API contract.

## Enforcement and backend boundary

Safe-call enforcement is enabled by Patch 20.16d. `Mutex.Lock()` still
returns a raw pointer internally; Lock/Unlock lowering, runtime symbols,
ABI/layout, and MIR remain unchanged. Generic protected-access liveness
is owned by the successor authority. Seed reconvergence remains isolated in
Patch 20.16e.
