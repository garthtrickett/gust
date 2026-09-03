# Stdlib foundations — the plan, its status, and three unconnected blockers

A "stdlib foundations" plan covering string ergonomics, HashMap through
references, branded collection consistency, `Clone` normalization, a scoped mutex
guard, and then a roadmap out to `std.net`. Reviewed again 2026-09-03 after the
Phase 24.0f CR-15 closure and S1.8 implementation.

**Most of the first half is already the Phase S1 roadmap in `TASK_STDLIB.md`, and
every pre-guard item is done.** The valuable content is therefore the status
mapping, the roadmap tail that is *not* captured anywhere, and three blockers the
plan does not know it has.

---

## 1. The first half is Phase S1, and here is where it stands

| Plan item | S1 patch | State |
| --- | --- | --- |
| 1.1 `str` equality | **S1.1** | **DONE (#74)** — but see below, it is not what the plan asks for |
| 1.1 `str` length, byte access, slicing | **S1.2** | **DONE** |
| 1.2 HashMap methods through references | **S1.3** | **DONE** |
| 1.3 Branded collection type consistency | **S1.4** | **DONE** |
| 1.4 `Clone` with arena references | **S1.5** | **DONE** |
| Tests proving all five compose | **S1.6** | **DONE** |
| 2.x scoped mutex guard | **S1.7 / S1.8** | **audit and safe prototype DONE** |

Phase 19 delivered CR-2, and the narrower S1.4/S1.5 defects subsequently landed
through Cranelift coordination. Phase 20 delivered CR-5 and generic
protected-access liveness. Phase 24.0f then closed CR-15 with bounded
compiler-owned derivation that preserves OD-2. S1.8 consumes that authority in
the selected `sync.lock` / `sync.get` prototype.

### 1.1 is done, and it did not do what this plan wants

S1.1 made `a == b` on `str` a **rejection** with a diagnostic naming
`std.str_eq`. This plan asks for the opposite: that `if name == "PING"` simply
work, lowering to semantic comparison. Its argument is the sharpest statement of
why that matters anywhere in the repository:

> **"Users should not have to remember `std.str_eq(name, "PING")`. That is
> implementation leakage."**

`docs/SHARED_SEMANTIC_ZONE.md` D-3 already says the miscompile is closed while the
semantics are not — *"rejecting an operator is not deciding what it means"* — and
tracks the remainder as **CR-1**. **This plan is a request for CR-1**, and the
leakage framing belongs in that CR: the current state is not neutral, it forces
every user to know a compiler-internal spelling.

**The byte-length decision is also worth recording as decided rather than
assumed:** `Len` is **byte length, not codepoint length**, because sockets,
protocols and files need bytes; Unicode helpers arrive later under *different
names*. And explicitly: **do not let basic `Len()` secretly walk UTF-8.** This
agrees with §33 and with `docs/UNBLOCKED_CONTAINMENT_WORK.md`'s JSON writer, which
already assumes a byte-based `str`.

---

## 2. Three blockers the plan did not know it had — current disposition

**A. The guard's compile-fail list requires visibility levels, which do not
exist.** The plan wants to reject *"construct fake guard"* and *"manually unlock
then let the guard unlock again"*, and correctly notes those *"may dictate how
much of the constructor/release API needs to remain internal."* There is no
internal. `docs/ONE_WAY_LEDGER.md` row 35 records that `pub`, `private`,
`public`, `internal` and `export` are **all absent from both lexers**, so every
field of every struct is reachable everywhere. **A guard whose constructor anyone
can call is not a guard**, and this is a hard prerequisite rather than a polish
item.

**Resolved by Phase 20.** `#[opaque]` construction control and `#[private]`
cleanup authority now exist as generic source metadata. S1.9 must consume them;
it must not recreate visibility for MutexGuard.

**B. `MutexGuard` is blocked on destructor declaration, not on design.** The plan
states the ideal exactly right:

> **"`MutexGuard` is not compiler magic. It is merely a well-designed Gust
> resource."**

That is the test of whether §28's machinery is strong enough, and the answer
today is no — `TASK_STDLIB.md` CR-5 and `STEP52_RESOURCE_SEMANTICS.md` item 4
record **one built-in destructor and no source syntax to declare another**. So the
guard is blocked on exactly the same thing as the Postgres capability
(`docs/VISION.md` §54.0). **This plan is the clearest statement of why CR-5 is
worth scheduling**, because it shows what CR-5 buys: not one type, but the
principle that resources are library code.

**Superseded by CR-15.** Source-declared destructors, acquisition obligations,
automatic scope cleanup, transfer joins, and protected-access liveness have now
landed. The design is still selected, but an ordinary reusable Gust module would
require user-written generic `lock` and `get` functions, which resolved OD-2
forbids. The operator chose bounded compiler-owned derivation over reopening
generic functions. That derivation must be generic over Resource and protected
access metadata and backend-neutral; it is not permission for a Mutex-named
backend rule.

**Resolved by Phase 24.0f and consumed by S1.8.** The merged derivation produces
the selected concrete guard/acquisition/accessor identities before backend
selection. The safe module now supplies the ordinary lock, guarded access, and
registered cleanup bodies without changing the runtime symbol surface.

**C. `Mutex[T]` grants mutable access through a guard, which is interior
mutability.** The plan wisely defers it — *"I would not start there"* — but the
tension should be recorded: §27 says safe application code does not receive
unrestricted interior mutability, and `guard.value.counter += 1` is mutation
through a shared handle. It may well be *restricted* enough to qualify, since
access is gated on holding the guard. **That is an OD-3 question, not a stdlib
one**, and it should be routed there rather than decided inside a mutex patch.

**Resolved by OD-13.** One move-only guard is both the acquisition obligation
and the authority for context-branded protected access while live. Patch 20.16d
enforces that generic liveness rule. CR-15 supplies the missing reusable
derivation; it does not reopen the access decision.

---

## 3. The governing rule has inverted, and the plan predates the inversion

> *"No new lifetime machinery. No backend-only semantics. **MIR-to-C establishes
> behavior; Cranelift must eventually agree.**"*

The first two clauses hold and are good rules. **The third is now backwards.**
`docs/VISION_RECONCILIATION.md` §7 makes C retirement the declared current
priority, and `docs/ROADMAP_TAIL.md` Phases 22–24 flip the default to Cranelift
and then delete the C backend. Under `AGENTS.md`, MIR-to-C is the **differential
oracle** — it establishes behaviour *today* and is scheduled to stop existing.

**Restated for the current roadmap:** behaviour is established by the canonical
semantics, both backends must agree, and where they disagree today MIR-to-C is
the oracle — **but no new stdlib design may depend on a C-backend behaviour that
Cranelift cannot reproduce**, because the oracle is being retired rather than
promoted. The plan's own instinct is right; only its direction of authority is
dated.

**The other rule needs no revision and should be kept verbatim:**

> *"No new language feature unless the abstraction genuinely cannot be expressed
> safely."*

That is `docs/ROADMAP_TAIL.md`'s organising principle — make the safe path
convenient rather than the type system more expressive — stated as an acceptance
test rather than as a philosophy.

---

## 4. The roadmap tail — not captured anywhere

`TASK_STDLIB.md` runs to S1.12. Everything below is beyond it and is in no file.

1. **Standardize linear OS resources** — `File`, `Socket`, explicit `Close`,
   move-only ownership. *Consumes the landed CR-5 resource floor; any new
   runtime symbols still follow CR-4's cross-lane protocol.*
2. **Basic `std.net`** — `Listen`, `Accept`, `Connect`, `Read`, `Write`, `Close`,
   **initially blocking if necessary.**
3. **Buffered I/O** — `BufferedReader`, `BufferedWriter`, `ReadLine`, with
   caller-supplied or request arenas.
4. **Fiber-aware networking** — nonblocking sockets, scheduler parking and
   wakeup, and **poll/ppoll hidden completely from user code.**
5. **Time** — monotonic clock, sleep, deadlines, socket read/write timeouts.
6. **Concurrency abstractions** — bounded queue, worker pool, connection pool,
   **built from `Mutex`, `Channel`, and spawn rather than from new primitives.**
7. **Three canonical examples** — HTTP server, concurrent KV server,
   file-processing daemon.

**Two observations on the tail.**

Step 4 is where `docs/VISION.md` §21's transparent-suspension direction gets
tested for real. *"Hide poll/ppoll completely from user code"* **is** transparent
suspension, stated as a stdlib requirement rather than as a language property —
and §21.1's first fatal blocker is precisely a capability call that cannot suspend
without unwinding a native frame. **`std.net` is the experiment that answers
whether that blocker is real.**

Step 6's constraint — build the pool from `Mutex`, `Channel` and spawn rather
than new primitives — collides with **OD-11**, which deletes the bare
`std.Spawn`. The constraint survives and the spelling does not: a worker pool
built on scoped spawn holds linear task handles, which is *better* for a pool
than detached workers, since a pool that cannot join its workers cannot shut down
cleanly. **Worth noting rather than treating as a conflict.**
