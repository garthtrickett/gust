# Cranelift Phase 21 Resource and Synchronization Native Source Migration

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase21_resource_sync_native_source.py project`. Do not edit by hand.

- Contract: `phase21_resource_sync_native_source_v1`
- Status: `patch21_11_complete`
- Next patch: `21.12`

## Qualified source cases

- `resource_primary` — `compiler/phase20_resource_scope_cleanup_source.gst` — stdout hex `320a310a340a330a350a390a360a370a380a31300a`
- `resource_renamed` — `compiler/phase21_resource_sync_renamed_source.gst` — stdout hex `31320a31310a31340a31330a31350a31390a31360a31370a31390a32300a`
- `threading_primary` — `compiler/phase20_component_threading_source.gst` — stdout hex `310a`

## Canonical boundary

- Operations: `LocalRawPointerSetParam, LocalRawPointerSetCall, LocalI32SetRawPointerLoad, RawPointerStoreLocalI32, LocalRawPointerOffset, ArenaStoreLocalI32, FunctionAddress, ArenaAllocationAddress`
- Runtime imports: `os_Arena_New, os_Arena_Free, os_ArenaAlloc, os_LogInt, std_Mutex_Alloc, std_Mutex_Lock_impl, std_Mutex_Unlock_impl, gust_scheduler_init, gust_scheduler_spawn, gust_yield, gust_scheduler_destroy`
- Generated C and fallback: forbidden
- New or changed runtime symbols: none
