# The One-Way Ledger

Gust's central design rule is that there is one way to do each thing. That rule
is currently spread across `docs/VISION.md` Part IV, Part XXII, `README.md`, and
five documents outside the repository. Spread out, it cannot be checked, and a
proposal that violates it is only caught if the reviewer happens to remember the
rule.

This file collates it. Every row names the one sanctioned way, what is rejected,
and **whether the compiler actually does it today**.

## How to use it

- A proposal must fit an existing row, or add one with justification.
- A row's `Status` is a claim about the compiler and must have a reproduction.
- `docs/VISION.md` remains authoritative for *what the rule is*. This file is
  authoritative for *whether it holds*.

## Status vocabulary

| Status | Meaning |
| --- | --- |
| **HOLDS** | Implemented and enforced. |
| **PARTIAL** | Enforced in one direction only, or enforced without the sanctioned replacement existing. |
| **VIOLATED** | The compiler or runtime does the rejected thing. |
| **ABSENT** | Not implemented either way; the rule is a design intention with nothing enforcing it. |
| **DEFERRED** | The rule was withdrawn from `docs/VISION.md` to match the implementation. The property it protected is still wanted and is unscheduled. |

`ABSENT` is not a defect. Most of these are unbuilt platform surface and are
correctly deferred per `docs/VISION.md` Part status markers. `VIOLATED` is a
defect, and every `VIOLATED` row names its owner.

**Verified 2026-08-20 against `b47d0049` (`main`).** Reproductions in the
Evidence section below; row-level citations are `path:line` pinned to that commit.

---

## The ledger

| # | Concern | The one way | Rejected | Status |
| --- | --- | --- | --- | --- |
| 1 | Memory | Branded contexts and arenas | GC; malloc/free; refcount by default | **HOLDS** |
| 2 | Brand identity | Type-carried context brand | brand by naming convention | **VIOLATED** — D-1 |
| 3 | Absence | `Option[T]` | null in safe code | **PARTIAL** — E1 |
| 4 | Failure | `Result[T, E]` with `?` propagation | exceptions; error codes | **ABSENT** — E2 |
| 5 | Fallible binding | `guard x := … else { … }` | unchecked unwrap | **HOLDS** |
| 6 | Panic scope | Terminates request, task, or job | terminating the process | **VIOLATED** — E3 |
| 7 | Abstraction | Concrete structs, functions, explicit function tables | inheritance; broad traits; interface hierarchies | **HOLDS** |
| 8 | Dynamic dispatch | Data-oriented registry indexed by handle | per-object vtable pointers | **ABSENT** — design in `VISION_RECONCILIATION.md` App. B |
| 9 | Generics | Generic structs and enums; compiler-owned containers | user generic *functions*; HKT; specialization; trait bounds | **HOLDS** |
| 10 | Derivation | Bounded compiler-owned derivation | user macros; arbitrary compile-time execution; build scripts | **HOLDS** — E4 |
| 11 | Operators | Compiler-owned operator set | user overloading | **HOLDS** — E4 |
| 12 | Conversions | Explicit; only lossless widening implicit | implicit narrowing or lossy conversion | **ABSENT** |
| 13 | String equality | `std.str_eq` | `==` over `str` | **HOLDS** — E5 |
| 14 | Mutation | One reference form, `&T[ctx]`, which carries no mutability | *(restricting mutation through references: withdrawn, unscheduled)* | **DEFERRED** — E6 |
| 15 | Cleanup | `defer`, LIFO, plus registered destructors | manual close; finalizers; fallible destructors | **PARTIAL** — E7 |
| 16 | Resources | Linear, propagating transitively | ad-hoc handle discipline | **PARTIAL** — E7 |
| 17 | Shared ownership | Decided case-by-case; open as OD-3 | unrestricted interior mutability | **VIOLATED** — E8 |
| 18 | Suspension | Transparent; no function colouring | coloured `async`; Promises; raw futures | **ABSENT** — OD-1, E9 |
| 19 | Concurrency | Structured scopes, owned tasks, linear handles | detached spawn; actors as universal model | **VIOLATED** — E9 |
| 20 | Background work | Supervisor (long-lived) / job (durable) | fire-and-forget in request code | **ABSENT** |
| 21 | Authority | Declared effects on every function | ambient authority | **ABSENT** — E10 |
| 22 | Dependencies | Platform / certified provider / vendored source / escape hatch | resolver; transitive graph; registry by default | **ABSENT** |
| 23 | External services | Gust-owned capability interface | supplier SDK imports; in-process C libraries | **ABSENT** |
| 24 | Client↔server | Typed gustrpc calls | hand-written clients; duplicated schemas | **ABSENT** |
| 25 | Rendering and state | Lit-style compiled templates; SAM action→model→state→effect | VirtualDOM; ad-hoc stores; two-way binding | **ABSENT** |
| 26 | Schema | Postgres is source of truth; Gust derives types | ORM-first | **ABSENT** |
| 27 | Backend | Cranelift native | — (C retained as bootstrap seed and differential oracle) | **PARTIAL** — Phase 18 open |
| 28 | Integer types | Fixed-width `i32`, `u32`, `i64`, `u64`, `isize`, `usize` | a single unsized integer | **ABSENT** — E11 |
| 29 | Overflow | Traps by default in all builds; wrapping/saturating/checked are named operations | silent wraparound | **VIOLATED** — E11 |

Counts: 7 `HOLDS`, 4 `PARTIAL`, 5 `VIOLATED`, 1 `DEFERRED`, 12 `ABSENT`.

| Row | Rule | Status | Owner |
| --- | --- | --- | --- |
| 2 | Brand identity | VIOLATED | Phase 19 (`TASK_PHASE19.md`), staged |
| 6 | Panic scope | VIOLATED | `TASK_STDLIB.md` CR-3, issue #91 — unscheduled |
| 17 | Shared ownership | VIOLATED | `TASK_STDLIB.md` CR-9 — new |
| 19 | Concurrency | VIOLATED | `TASK_STDLIB.md` CR-8, issue #101 — new |
| 29 | Overflow | VIOLATED | issue #103 — new |
| 14 | Mutation | DEFERRED | `TASK_STDLIB.md` CR-6 — rule withdrawn, unscheduled |

Every one has a written owner and none is currently scheduled. That is the
honest summary: five rules are known to be broken and one was withdrawn, and no
lane is working on any of them.

---

## Evidence

### D-1 — brand identity is inferred from identifier spelling (row 2)

Owned by **Phase 19** (`TASK_PHASE19.md`), staged and not yet active. Recorded in
`docs/SHARED_SEMANTIC_ZONE.md` as D-1/D-2 and in `TASK_STDLIB.md` as CR-2.

```
$ grep -n 'brand_bases' src/codegen.rs src/typechecker/types.rs
src/codegen.rs:71:    let brand_bases = ["connCtx", "arena", "ctx", "Any", "a", "main_ctx", "bg_ctx", "file_ctx"];
src/typechecker/types.rs:61:    let brand_bases = ["connCtx", "arena", "ctx", "Any", "a", "main_ctx", "bg_ctx", "file_ctx"];
```

A local `str` named `a` is emitted as `&a`. Renaming the variable fixes the
program. Full reproduction: `docs/STDLIB_SURFACE_FINDINGS.md` F3.

### E1 — `Option` exists, but constructing one requires `unsafe` (row 3)

`std.Option` is a registered name (`docs/STDLIB_SURFACE_INVENTORY.md`) and
`match` over it works. Construction reaches through the representation:

```gust
// tests/e2e_std_option_basic.gst:1-6
mut opt_some: std.Option[int, ctx];
unsafe {
    opt_some.tag = 0;
    opt_some.Some.val = 42;
}
```

There is no `Some(42)` constructor. Writing an `Option` requires knowing it is a
tagged union with a `tag` field, and requires `unsafe` to say so. Filed as
issue #102.

This is the clearest instance of the representation leakage that `docs/VISION.md`
§0.7 Track A0 exists to remove, and it is directly relevant to OD-9: a model
cannot write idiomatic Gust against this surface, because there is no idiom —
there is only the layout.

### E2 — `Result` is not a builtin and `?` does not exist (row 4)

```
$ grep -rn '"Result"' src/typechecker/types.rs
(no matches — the sole hit in src/ is std::fmt::Result)
$ grep -n 'Question' src/lexer.rs
(no matches)
```

Tests that need a result type define their own:

```gust
// tests/e2e_adt_pressure_test.gst:1-4
type MyResult[T, E, ctx] enum {
    Ok { val: T },
    Err { error: E }
}
```

`docs/VISION.md` §11 and Consolidated Rule 16 describe `Result` and `?` as the
single failure convention. Neither exists. The convention in use today is
`guard … else` (row 5), which is implemented and tested
(`tests/e2e_fallible_guard_bootstrap.gst`, `tests/e2e_guard_hashmap_lookup.gst`,
and three others).

**This is the largest single gap between Part IV as written and the language as
built**, and unlike rows 21–26 it is core language rather than deferred platform.

### E3 — a bounds failure terminates the process (row 6)

```
$ grep -n 'exit(1)' src/runtime/strings.c
20:        exit(1);
30:        exit(1);
```

`std_str_slice` and `std_str_byte_at` call `exit(1)` on out-of-range input.
`docs/VISION.md` §34 requires a panic to terminate the current request, task, or
job — not the deployment. From a fiber, `exit(1)` takes the process down. Filed
as issue #91.

Recorded as D-5 in `docs/SHARED_SEMANTIC_ZONE.md` and as `TASK_STDLIB.md` CR-3,
which states the fix: route bounds failures through the §34 panic path rather
than adding `Result`-returning helper variants. **No owning phase has scheduled
it.**

### E4 — no macros, no operator overloading (rows 10, 11)

```
$ grep -in 'macro' src/parser.rs
(no matches)
$ grep -rin 'overload' src/ --include=*.rs
(no matches)
```

These two rows hold by construction: the facility was never added, so there is
nothing to remove. Worth recording precisely because it is the cheapest kind of
compliance and is easy to lose later.

### E5 — `str ==` is rejected with a diagnostic (row 13)

Landed by `354ff513` (#74). Both typecheckers reject `==` and `!=` when either
operand is `str`, with a byte-identical message naming `std.str_eq`.

This row was `VIOLATED` when the reconciliation was drafted — codegen emitted C
`==` over two `Slice_unsigned_char` structs, which is not valid C. It is now
`HOLDS` for the rejection. Making `==` *mean* content equality remains open as
`TASK_STDLIB.md` CR-1.

### E6 — one reference form, and it is mutable (row 14)

```
$ grep -c '"inout"' compiler/lexer.gst src/lexer.rs
compiler/lexer.gst:0
src/lexer.rs:0
```

`inout` is not a keyword in either lexer. `&T` resolves to a `Reference` type
carrying no mutability: writing through it with `(*r).field = value` is permitted
with no check and reaches the caller's value, and two `&T` arguments may alias
one value and both write through it.

Corrected in `docs/VISION.md` §26 on 2026-08-19 (#84), which now describes the
single form that exists. The evidence fixture is committed as
`tests/test_shared_mutable_aliasing_observed.gst`. Recorded as `TASK_STDLIB.md`
CR-6; enforcement is deferred and unscheduled.

The row is `DEFERRED`, not `VIOLATED`, and the distinction is deliberate. This
file is authoritative for whether a rule holds; `docs/VISION.md` is authoritative
for what the rule *is*. §26 no longer states the two-form model, so there is no
longer a rule here to violate — it was withdrawn to match the compiler. What
remains is a wanted containment property with nothing scheduled to deliver it.

An earlier draft of this row marked it `VIOLATED` against the withdrawn rule.
That was this file overriding `VISION.md` on what the rule is, which is exactly
the authority split it declares it will not cross.

The practical consequence is unchanged and is worth repeating: `&T[ctx]` must not
be cited as an immutability guarantee in documentation, in review, or in a safety
argument.

### E7 — `defer` parses; automatic resource lifecycle does not (rows 15, 16)

```
$ grep -n 'TokenType::Defer' src/parser.rs
81:                | TokenType::Defer
161:            TokenType::Defer => {
```

`defer` exists in both lexers and parses to a `Statement::Defer`.
`STEP52_RESOURCE_SEMANTICS.md` items 2 and 6 record that automatic resource
lifecycle enforcement and a full AST/typechecker representation for `defer` are
unmet; re-verified 2026-08-19 by `15334657` (#87), which records why `MutexGuard`
is blocked. Linear resources have move and borrow tracking (Phase 15) but do not
yet discharge cleanup obligations automatically.

### E8 — shared ownership was decided by implementation (row 17)

`docs/VISION.md` §27 marks shared ownership open as **OD-3** and says Gust "may
provide" a read-only `Rc[T, ctx]`. Three names are already registered:

```
$ grep -n 'std\.Rc' docs/STDLIB_SURFACE_INVENTORY.md
- `std.Rc`
- `std.RcNew`
- `std.RcNode`
```

An open decision with a shipped implementation is not open. Either §27 is
corrected to describe what exists, or the surface is justified against the
decision. Routed as `TASK_STDLIB.md` CR-9.

### E9 — the implemented concurrency model is the rejected one (rows 18, 19)

```
$ grep -c '"async"\|"await"\|"spawn"\|"scope"' compiler/lexer.gst src/lexer.rs
compiler/lexer.gst:0
src/lexer.rs:0
```

No suspension or task keyword exists in either lexer. Concurrency is a library
surface over the cooperative fibers in `src/runtime/fiber.c`:

```
$ grep -n 'std\.Spawn\|std\.Channel\|std\.Yield\|std\.Mutex' docs/STDLIB_SURFACE_INVENTORY.md
- `std.Channel`
- `std.ChannelNew`
- `std.Mutex`
- `std.MutexNew`
- `std.Spawn`
- `std.Yield`
```

`std.Spawn` starts work that no scope owns. There is no structured scope, no join
requirement, no cancellation propagation, and no task handle type — so a spawned
task cannot be awaited, cancelled, or transferred, and nothing prevents it
outliving the context whose data it captured.

That is detached spawn plus channels: **the Go concurrency model, which
`docs/VISION.md` §20, `async.md`, and `advice.md` each independently reject.**
`docs/VISION.md` §20 states that "fire-and-forget work is not permitted in normal
request code"; nothing enforces it, and the only primitive available is
fire-and-forget.

Filed as issue #101. Routed as `TASK_STDLIB.md` CR-8, which is a report rather
than a patch: the fix
is a Ring 1 semantic decision (OD-1) owned by the Cranelift lane under
`docs/SHARED_SEMANTIC_ZONE.md`'s "Fiber scheduling contract" row.

### E10 — effects do not exist (row 21)

```
$ grep -c '"uses"' compiler/lexer.gst src/lexer.rs
compiler/lexer.gst:0
src/lexer.rs:0
```

`docs/VISION.md` §17, §18, Consolidated Rules 4 and 12, and §0.7 Track A item 1
all rest on `uses` clauses. There is no such keyword. This is the differentiator
in §0.4 and it is unstarted; `docs/VISION.md` §0.6 says so.

---

### E11 — §32's entire numeric model is absent, and overflow is UB rather than trapping (rows 28, 29)

`docs/VISION.md` §32 makes four claims. None holds.

**Fixed-width integer types.** §32 lists `i32`, `u32`, `i64`, `u64`, `isize`,
`usize`. None is a type in either lexer:

```
$ for ty in i32 u32 i64 u64 isize usize; do
    printf '%-6s rs=%s gst=%s\n' "$ty" \
      "$(grep -c "\"$ty\"" src/lexer.rs)" "$(grep -c "\"$ty\"" compiler/lexer.gst)"
  done
i32    rs=0 gst=0
u32    rs=0 gst=0
i64    rs=0 gst=0
u64    rs=0 gst=0
isize  rs=0 gst=0
usize  rs=0 gst=0
```

There is one integer type, `int`.

**Overflow trapping.** §32: "Integer overflow traps by default in all builds.
This carries a measurable runtime cost and is accepted deliberately."

```
$ grep -rin 'overflow' src/codegen.rs src/typechecker/*.rs
(no matches)
```

No overflow handling exists anywhere in codegen or the typechecker. The cost is
not being paid because the check is not there.

It is worse than absent. `Type::Int` lowers to C `int` (`src/codegen.rs:239,443`),
and **signed overflow in C is undefined behaviour**. So on the default backend
the behaviour at overflow is not wraparound, which would merely be wrong — it is
UB, which is the class `README.md`'s two-backends section identifies as the
reason the Cranelift backend exists. §32 promises a trap and the compiler emits
the one construct that gives the optimiser licence.

Row 29 is `VIOLATED` rather than `ABSENT` for that reason: the rejected
behaviour is not just unprevented, it is what the compiler currently produces.

**Named arithmetic operations** (wrapping, saturating, checked) and the
**compiler-owned numeric and time types** (`Decimal`, `Money[Currency]`,
`Instant`, `Duration`, `Date`, `LocalTime`, `ZonedDateTime`) are absent:

```
$ grep -cE 'wrapping|saturating|checked_' docs/STDLIB_SURFACE_INVENTORY.md
0
$ grep -cE 'Decimal|Money|Instant|Duration|ZonedDateTime|LocalTime' docs/STDLIB_SURFACE_INVENTORY.md
0
```

Filed as issue #103.

## Maintenance

- A row changes status only with a reproduction, per `AGENTS.md`.
- A `VIOLATED` row is removed only when fixed, never because it is inconvenient.
- When a row's rule changes, `docs/VISION.md` changes first and this file follows.
