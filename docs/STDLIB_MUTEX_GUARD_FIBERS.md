# MutexGuard Fiber Contention Evidence

Patch S1.10 validates the safe `sync.lock` / `sync.get` surface under real
fibers. It adds no synchronization, resource, move, MIR, ABI, or backend
semantics, and it introduces no raw `Mutex.Lock` or `Mutex.Unlock` call.

## Contention, suspension and wakeup

`tests/stdlib_s1_mutex_guard_fibers.gst` spawns a holder fiber that acquires the
guard and yields **twice while still holding it**, and a contender fiber that
attempts acquisition and must suspend. The contender can only proceed once the
holder's call returns and scope exit releases the guard. Both increments land,
so the settled count is exactly `2`.

A guard that failed to release at scope exit would not print a wrong number — it
would hang the settle loop, because the contender would never wake.

## Exact shared counter

Three further fibers each perform one hundred guarded increments. Every mutation
in the program goes through `increment_once`, which takes one acquisition and
releases it by scope exit. On top of the two increments above the total is
exactly `302`. A lost update from a dropped acquisition would hang rather than
misreport.

## Identical behaviour with and without the guard

The without-guard arm is `tests/e2e_mutex_concurrency.gst`, the pre-existing raw
`Mutex.Lock`/`Unlock` fiber test, which performs the same shared-counter workload
and must still produce its exact total of `300`.

**It is reused rather than duplicated, deliberately.** A new raw fixture would
add an unregistered raw `Mutex` call site to the inventory pinned by the
Cranelift-owned `guard-cranelift-phase20-unsafe-mutex-migration-contract`, which
is the same coordination boundary that defers S1.9's raw double-unlock fixture
under CR-16. Reusing the registered baseline gives the identical with/without
comparison and adds no call site.

The guard asserts positively that the S1.10 fixture contains no `.Lock()` or
`.Unlock()` call, so the safe surface is the only path to the protected value.

The `unsafe` blocks in the fixture's task functions scope the **spawn argument
dereference**, which is the pre-existing raw-pointer fiber ABI shared by every
spawn test in the repository. They are not mutex operations.

## Future coverage — recorded, not skipped

The roadmap directs that coverage CI cannot run be recorded here rather than
silently dropped.

**The Cranelift route cannot run fiber programs.** Measured through
`scripts/run-gust-file.sh` with `GUST_RUNNER_ROUTE=cranelift`:
`tests/e2e_spawn_yield.gst`, `tests/e2e_sync_primitives.gst` and
`tests/e2e_mutex_concurrency.gst` are each deferred with
`class=unsupported_native_capability` and
`reason_code=deferred_p13_parameter_argument_target_dependent_abi` — *"Cranelift
backend selection is valid, but the source-level route is not connected yet."*

S1.10 therefore qualifies on MIR-to-C only. Unlike S1.8 and S1.9, its exit gate
does not require both-route parity; it requires with/without-guard equivalence
and an exact counter, both of which are met.

Two items are recorded as future coverage:

- **Cranelift fiber contention**, once the source-level route is connected.
  Tracked separately as **CR-19**, because this fixture is currently classified
  `supported` and then fails canonical MIR verification, where its three
  siblings defer gracefully. That classification asymmetry is compiler-owned and
  is not a request for fiber lowering.
- **Multi-shard scheduler and real parallel contention.** The suite runs fibers
  on the default scheduler configuration; genuine parallel contention across
  shards is not exercised here.
