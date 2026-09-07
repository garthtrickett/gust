# Realistic Example Migration — Patch S1.11

S1.11 converts one existing realistic test from manual `Lock()` / `Unlock()` to
the scoped guard delivered by S1.8 and qualified by S1.9 and S1.10. It adds no
synchronization, resource, move, MIR, ABI, or backend semantics.

## What was migrated, and why this file

`tests/e2e_sync_primitives.gst` — a producer/consumer fiber pipeline over a
channel and a mutex-protected counter.

It was chosen from an enumeration performed **before** any code was written.
Exactly nine files in the repository contain a raw `.Lock()` or `.Unlock()`, and
**all nine were already registered raw-Mutex call sites**; there is no
`examples/` directory. There was therefore no unpinned candidate, and any
migration necessarily changed the inventory pinned by
`guard-cranelift-phase20-unsafe-mutex-migration-contract`. That was filed as
CR-21 and registered by Patch 24.3e before this patch was published.

Of the two files the contract labels **transitional**, the other —
`tests/e2e_mutex_concurrency.gst` — was rejected deliberately: it is S1.10's
without-guard baseline asserting `300`, so migrating it would have broken
`guard-stdlib-s1-mutex-guard-fibers`.

## The delta

| property | before | after |
| --- | --- | --- |
| raw `Lock()` calls | 4 | **0** |
| raw `Unlock()` calls | 4 | **0** |
| manual cleanup paths | 4 | **0** |
| `unsafe` blocks | 5 | **2** |
| observable | `10` | `10` |

Every acquisition is now a helper — `set_count`, `add_to_count`, `read_count` —
that takes one acquisition and releases it by scope exit. There is no unlock to
forget and no path out of those functions that skips it.

## The `unsafe` accounting

Stated explicitly so the delta can be confirmed as a pure mutex migration rather
than an incidental `unsafe` reduction riding along.

| block | before | after |
| --- | --- | --- |
| 1 | `chan.Send(i)` | unchanged |
| 2 | `chan.Recv()` + `mutex.Lock`/mutate/`Unlock` | `chan.Recv()` + spawn-arg deref |
| 3 | `mutex.Lock` / set / `Unlock` | **removed** |
| 4 | `mutex.Lock` / read / `Unlock` | **removed** |
| 5 | `mutex.Lock` / log / `Unlock` | **removed** |

**All three removed blocks contained nothing but mutex operations.** The two
survivors are the channel operations and the `(*p)` spawn-argument dereference
required by the fiber ABI — neither is a mutex operation, and neither is a
raw-pointer workaround introduced in place of a removed unlock.

## Identical observable behaviour and synchronization guarantees

Measured on both forms, same compiler, same route:

| program | exit | observable |
| --- | --- | --- |
| pre-migration (raw `Lock`/`Unlock`) | 0 | `10` |
| migrated (scoped guard) | 0 | `10` |

The producer sends `0..4`; the consumer accumulates them under the guard; the
program settles at exactly `10`. The synchronization guarantee is unchanged
because the guard acquires and releases the same mutex — a lost or doubled
release would hang the settle loop rather than print a wrong number, so the
observable is a live check on the guarantee and not merely on the arithmetic.

## Coverage this patch does not claim

The Cranelift route is not exercised. Fiber programs do not lower there:
`e2e_spawn_yield`, `e2e_sync_primitives` and `e2e_mutex_concurrency` are each
deferred with `unsupported_native_capability`, recorded for S1.10 in
`docs/STDLIB_MUTEX_GUARD_FIBERS.md` and tracked as CR-19. This patch does not
change that and does not claim otherwise.
