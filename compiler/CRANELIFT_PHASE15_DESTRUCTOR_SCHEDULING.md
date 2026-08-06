# Cranelift Phase 15 Destructor Scheduling

<!-- Generated contract projection for Patch 15.7. -->

CRANELIFT_PHASE15_DESTRUCTOR_SCHEDULING_VIEW_VERSION: 1
CRANELIFT_PHASE15_DESTRUCTOR_SCHEDULING_VERSION: phase15_destructor_scheduling_and_exactly_once_destruction_v1
CRANELIFT_PHASE15_DESTRUCTOR_SCHEDULING_STATUS: ready_for_patch15_8
CRANELIFT_PHASE15_DESTRUCTOR_SCHEDULING_OWNER: compiler/mir_destructor_scheduling.gst
CRANELIFT_PHASE15_DESTRUCTOR_SCHEDULING_TABLE_FORMAT: gust.compiler_destructor_scheduling_table.v1
CRANELIFT_PHASE15_DESTRUCTOR_SCHEDULING_PRIMARY_TARGET: x86_64-unknown-linux-gnu
CRANELIFT_PHASE15_DESTRUCTOR_SCHEDULING_LEVEL1_GUARD: guard-cranelift-phase15-destructor-scheduling-contract
CRANELIFT_PHASE15_DESTRUCTOR_SCHEDULING_LEVEL2_GUARD: guard-cranelift-phase15-destructor-scheduling-parity
CRANELIFT_PHASE15_DESTRUCTOR_SCHEDULING_NEXT_PATCH: 15.8

## Frozen inventory

- `resource_log_handle` / `destructor_close_log` / `release_os_handle`
- `resource_config_buffer` / `destructor_free_config` / `release_arena_buffer`
- `resource_net_connection` / `destructor_disconnect_net` / `close_network_session`
- `resource_temp_scratch` / `destructor_release_scratch` / `release_stack_buffer`

## Compiler-owned scheduling authority

The compiler owns every destructor identity, every scheduling point, every
cleanup reason, and the destruction order. Each scheduled destructor resolves
to exactly one resource ID, one destructor ID, one cleanup reason, and one
execution point. No backend decides when a destructor is needed.

## Canonical operations

- `schedule_destructor`
- `cancel_schedule` (cancels an obsolete schedule after ownership transfer)
- `execute_destructor`
- `mark_destroyed`

## Exactly-once witness

One compiler-owned schedule and one execution per selected resource. The
witness compares schedule count, execution count, order, and final destroyed
state through both backends.

## Negative classes

- `duplicate_schedule`
- `execute_without_schedule`
- `schedule_after_destruction`
- `destructor_mismatch`
- `skipped_destruction`
- `destruction_after_move`
- `destruction_order_drift`

## Differential evidence

The primary target replays the state machine for every operation, verifies the
exactly-once witness per resource, and compares MIR-to-C and Cranelift output
byte-for-byte. All declared targets produce compiler and worker witnesses;
MIR-to-C executes on the primary target.

## Boundary

Asynchronous destruction, finalizers, garbage collection, and concurrent
cancellation remain deferred. Manual close versus deferred cleanup is Patch
15.8.
