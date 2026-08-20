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
  As of 2026-08-20 every row does; a new row without one is incomplete.
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

### Which compiler a citation refers to

This matters for reading the evidence, because the repository contains more than
one thing called "the compiler":

| Path | What it is | Weight |
| --- | --- | --- |
| `compiler/*.gst` | the self-hosted compiler | **authoritative** — this is the compiler |
| `gust_v4.c` | the converged bootstrap seed | generated from the above |
| `src/runtime/*.c` | the runtime | live; linked into every program |
| `src/*.rs` | the **deprecated** Rust prototype | not authoritative; corroboration only |

`src/*.rs` has not compiled since 2026-06-22 (PR #82) and nothing builds it. A
claim resting only on it proves nothing about the language. Where both are cited
below, the self-hosted compiler is the claim and the prototype merely agrees.

Note also that the active direction is retiring the **C backend** in favour of
Cranelift. Where a finding is a property of C rather than of Gust — E11's
overflow behaviour is the clearest — that is called out, because those resolve
when the backend does.

---

## The ledger

| # | Concern | The one way | Rejected | Status |
| --- | --- | --- | --- | --- |
| 1 | Memory | Branded contexts and arenas | GC; malloc/free; refcount by default | **HOLDS** — E15 |
| 2 | Brand identity | Type-carried context brand | brand by naming convention | **VIOLATED** — D-1 |
| 3 | Absence | `Option[T]` | null in safe code | **PARTIAL** — E1 |
| 4 | Failure | `Result[T, E]` with `?` propagation | exceptions; error codes | **ABSENT** — E2 |
| 5 | Fallible binding | `guard x := … else { … }` | unchecked unwrap | **HOLDS** — E15 |
| 6 | Panic scope | Terminates request, task, or job | terminating the process | **VIOLATED** — E3 |
| 7 | Abstraction | Concrete structs, functions, explicit function tables | inheritance; broad traits; interface hierarchies | **HOLDS** — E15 |
| 8 | Dynamic dispatch | Data-oriented registry indexed by handle | per-object vtable pointers | **ABSENT** — design in `VISION_RECONCILIATION.md` App. B |
| 9 | Generics | Generic structs and enums; compiler-owned containers | user generic *functions*; HKT; specialization; trait bounds | **HOLDS** — E15 |
| 10 | Derivation | Bounded compiler-owned derivation | user macros; arbitrary compile-time execution; build scripts | **HOLDS** — E4 |
| 11 | Operators | Compiler-owned operator set | user overloading | **HOLDS** — E4 |
| 12 | Conversions | Explicit; only lossless widening implicit | implicit narrowing or lossy conversion | **ABSENT** — E15, vacuous |
| 13 | String equality | `std.str_eq` | `==` over `str` | **HOLDS** — E5 |
| 14 | Mutation | One reference form, `&T[ctx]`, which carries no mutability | *(restricting mutation through references: withdrawn, unscheduled)* | **DEFERRED** — E6 |
| 15 | Cleanup | `defer`, LIFO, plus registered destructors | manual close; finalizers; fallible destructors | **PARTIAL** — E7 |
| 16 | Resources | Linear, propagating transitively | ad-hoc handle discipline | **PARTIAL** — E7 |
| 17 | Shared ownership | Decided case-by-case; open as OD-3 | unrestricted interior mutability | **VIOLATED** — E8 |
| 18 | Suspension | Transparent; no function colouring | coloured `async`; Promises; raw futures | **ABSENT** — OD-1, E9 |
| 19 | Concurrency | Structured scopes, owned tasks, linear handles | detached spawn; actors as universal model | **VIOLATED** — E9 |
| 20 | Background work | Supervisor (long-lived) / job (durable) | fire-and-forget in request code | **ABSENT** — E16 |
| 21 | Authority | Declared effects on every function | ambient authority | **ABSENT** — E10 |
| 22 | Dependencies | Platform / certified provider / vendored source / escape hatch | resolver; transitive graph; registry by default | **ABSENT** — E16 |
| 23 | External services | Gust-owned capability interface | supplier SDK imports; in-process C libraries | **ABSENT** — E16 |
| 24 | Client↔server | Typed gustrpc calls | hand-written clients; duplicated schemas | **ABSENT** — E16 |
| 25 | Rendering and state | Lit-style compiled templates; SAM action→model→state→effect | VirtualDOM; ad-hoc stores; two-way binding | **ABSENT** — E16 |
| 26 | Schema | Postgres is source of truth; Gust derives types | ORM-first | **ABSENT** — E16 |
| 27 | Backend | Cranelift native — **the declared current priority** | generated C as a supported backend | **PARTIAL** — E17 |
| 28 | Integer types | Fixed-width `i32`, `u32`, `i64`, `u64`, `isize`, `usize` | a single unsized integer | **ABSENT** — E11 |
| 29 | Overflow | Traps by default in all builds; wrapping/saturating/checked are named operations | silent wraparound | **VIOLATED** — E11 |
| 30 | Exhaustiveness | All enum matching is exhaustive | unhandled variants | **HOLDS** — E12 |
| 31 | Copy vs move | A struct is copyable when every field is and the type is *explicitly marked* copyable | inferred copyability | **PARTIAL** — E13 |
| 32 | Null | Safe references are non-null; absence is `Option[T]` | `null` in safe code | **HOLDS** — E14 |
| 33 | Channel ownership | Channels transfer ownership of sent values | sender retaining a sent value | **VIOLATED** — E18 |
| 34 | Host access | Filesystem and process access are never silently available | ambient host authority | **VIOLATED** — E19 |
| 35 | Visibility | private-to-module by default, then package / application / public | everything visible everywhere | **ABSENT** — E19 |
| 36 | Cross-context movement | A shorter-lived value enters a longer-lived context only by cloning or explicit transfer | silently extending a lifetime | **PARTIAL** — E20 |
| 37 | Native code | Forbidden by default; only via signed adapter, capability, isolation | ungated native execution | **PARTIAL** — E21 |
| 38 | Packages | A package is a directory tree with a manifest; lockfiles record provenance | no package identity | **ABSENT** — E21 |
| 39 | Conformance checking | Generated checks substitute for reading | trusting unread output | **PARTIAL** — E22 |
| 40 | Machine-readable diagnostics | Structured form with a stable rule identifier and candidate edits | prose-only errors | **PARTIAL** — E23 |
| 41 | Reproducibility | A run is a clean observation; nondeterministic runs are discarded | averaging over noisy runs | **PARTIAL** — E24 |

Counts: 9 `HOLDS`, 10 `PARTIAL`, 7 `VIOLATED`, 1 `DEFERRED`, 14 `ABSENT`.

Row 27 is the one in motion. It is the declared priority and several other rows
resolve with it — see E17.

| Row | Rule | Status | Owner |
| --- | --- | --- | --- |
| 2 | Brand identity | VIOLATED | Phase 19 (`TASK_PHASE19.md`), staged |
| 6 | Panic scope | VIOLATED | `TASK_STDLIB.md` CR-3, issue #91 — unscheduled |
| 17 | Shared ownership | VIOLATED | `TASK_STDLIB.md` CR-9 — new |
| 19 | Concurrency | VIOLATED | `TASK_STDLIB.md` CR-8, issue #101 — new |
| 33 | Channel ownership | VIOLATED | issue #101 — same root cause |
| 34 | Host access | VIOLATED | unowned — closes with §0.7 Track A |
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

In the live compiler:

```
$ grep -n 'connCtx' compiler/codegen.gst
658:        brand_bases.Push("connCtx");
762:            if std.str_eq(name, "connCtx") == 1 { is_brand_name = 1; }
767:            if codegen_ends_with(name, "_connCtx") == 1 { is_brand_name = 1; }
896:  if std.str_eq(var_name, "ctx") == 1 || … || std.str_eq(var_name, "a") == 1 {
1101: if std.str_eq(var_name, "ctx") == 1 || … || std.str_eq(var_name, "a") == 1 {
```

`docs/STDLIB_SURFACE_FINDINGS.md` F3b lists the full set, including
`compiler/typechecker.gst:4953,5151`. The deprecated prototype carries the same
list at `src/codegen.rs:71` and `src/typechecker/types.rs:61`, but the live
compiler above is the claim.

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
$ grep -cE 'register.*"Result"|builtin.*Result' compiler/typechecker.gst
0
$ grep -cE '"\?"|Question' compiler/lexer.gst compiler/parser.gst
compiler/lexer.gst:0
compiler/parser.gst:0
```

The deprecated prototype agrees (`grep -rn '"Result"' src/typechecker/types.rs`
matches only `std::fmt::Result`), but the self-hosted compiler above is the
claim.

Tests that need a result type define their own:

```gust
// tests/e2e_adt_pressure_test.gst:1-4
type MyResult[T, E, ctx] enum {
    Ok { val: T },
    Err { error: E }
}
```

**So does the compiler.** `compiler/errors.gst:17` declares `Result` as an
ordinary user-level generic enum, exactly as any application would have to:

```gust
type Result[T, ctx] enum {
    Ok { val: T },
    Err { error: Index[CompilerError[ctx], ctx] }
}
```

That is the strongest available evidence for this row. §11 says "the language
includes `?`-style propagation"; the compiler that implements the language had to
hand-roll `Result` as a plain enum and propagate by hand.

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
$ grep -ci 'macro' compiler/parser.gst
0
$ grep -ci 'overload' compiler/typechecker.gst
0
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
$ grep -cE 'Defer' compiler/parser.gst compiler/ast.gst
compiler/parser.gst:5
compiler/ast.gst:4
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
    printf '%-6s gst=%s rs=%s\n' "$ty" \
      "$(grep -c "\"$ty\"" compiler/lexer.gst)" "$(grep -c "\"$ty\"" src/lexer.rs)"
  done
i32    gst=0 rs=0
u32    gst=0 rs=0
i64    gst=0 rs=0
u64    gst=0 rs=0
isize    gst=0 rs=0
usize    gst=0 rs=0
```

There is one integer type, `int`.

**Overflow trapping.** §32: "Integer overflow traps by default in all builds.
This carries a measurable runtime cost and is accepted deliberately."

```
$ grep -ci 'overflow' compiler/codegen.gst compiler/typechecker.gst
compiler/codegen.gst:0
compiler/typechecker.gst:0
```

No overflow handling exists anywhere in codegen or the typechecker. The cost is
not being paid because the check is not there.

It is worse than absent. Gust `int` lowers to C `int` in the self-hosted
compiler (`compiler/codegen.gst:61-62,1358,1382`; no `long long` or `int64_t`
appears anywhere in it), and **signed overflow in C is undefined behaviour**. So on the default backend
the behaviour at overflow is not wraparound, which would merely be wrong — it is
UB, which is the class `README.md`'s two-backends section identifies as the
reason the Cranelift backend exists. §32 promises a trap and the compiler emits
the one construct that gives the optimiser licence.

Row 29 is `VIOLATED` rather than `ABSENT` for that reason: the rejected
behaviour is not just unprevented, it is what the compiler currently produces.

This half is a property of the **C backend**, not of Gust, so it is one of the
findings that the Cranelift transition can resolve on its own — Cranelift has no
signed-overflow latitude to inherit. The other half, that §32's types and named
arithmetic do not exist, is unaffected by the backend and stays.

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

### E12 — match exhaustiveness is enforced, in both compilers (row 30)

Good news, recorded because a stale plan says otherwise. `compiler-plan.md`'s
IMMEDIATE ROADMAP still lists "Guarantee exhaustive match/switch checking for
enums" as outstanding. It is done.

```
$ grep -rin 'exhaust' compiler/typechecker.gst
10809: // Exhaustiveness check
10822: msg = std.Concat(msg, "' is not exhaustive. Missing variant '");
```

The live compiler checks it and names the missing variant. §31's rationale —
"exhaustiveness converts a whole class of generated-code omission into a compile
error" — is one of the few containment-shaped claims in the document that the
compiler actually makes good on today.

### E13 — copyability is inferred, never declared (row 31)

`docs/VISION.md` §23: "A user-defined struct is copyable only when every field is
copyable **and the type is explicitly marked copyable**."

The first half holds. The second half describes a mechanism that does not exist:

```
$ for k in copyable Copyable; do
    printf '%-10s gst=%s rs=%s\n' "$k" \
      "$(grep -c "\"$k\"" compiler/lexer.gst)" "$(grep -c "\"$k\"" src/lexer.rs)"
  done
copyable    gst=0 rs=0
Copyable    gst=0 rs=0
```

There is no marker. Copy-versus-move is decided structurally by `is_linear`
(`compiler/typechecker.gst:1761`, `typechecker_is_linear`; the deprecated prototype mirrors it at `src/typechecker.rs:219-250`):

| Type | Linear (moves) |
| --- | --- |
| `Int`, `Byte`, `Bool`, `Void`, `Index` | no — copies |
| `Arena`, `RawPointer`, `Slice`, `ByteSlice`, `Str`, `Generic` | yes |
| `Struct` | yes iff **any** field is linear, transitively |
| unregistered `Struct` | yes — conservative fallback |

**The consequence worth knowing.** Because linearity is structural, transitive,
and unannotated, *adding one `str` field to a plain struct silently converts that
struct from copy to move*, changing behaviour at every existing use site, with no
annotation at the declaration and no diagnostic at the edit. An explicit
`copyable` marker is precisely the mechanism that would turn that into a compile
error at the declaration, which is presumably why §23 specifies one.

The row is `PARTIAL`, not `VIOLATED`: the compiler's rule is a coherent design
and it enforces the field-transitivity half. What is missing is the declaration
that would make a change of category visible.

Note this is a different mechanism from the resource opt-in in §28. `is_linear`
here drives move tracking; resource semantics use separate `is_linear_resource`
metadata, which is registered only in the self-hosted compiler
(`STEP52_RESOURCE_SEMANTICS.md` verified state, item 1). Do not conflate them —
the two answer different questions and only one is opt-in.

### E14 — `null` does not exist in the language (row 32)

```
$ for k in null nil NULL; do
    printf '%-6s gst=%s rs=%s\n' "$k" \
      "$(grep -c "\"$k\"" compiler/lexer.gst)" "$(grep -c "\"$k\"" src/lexer.rs)"
  done
null    gst=0 rs=0
nil    gst=0 rs=0
NULL    gst=0 rs=0
```

§11's "safe references are non-null" holds by construction: there is no null
literal to write in either compiler. The restriction §11 describes — null
confined to raw pointers inside `unsafe`, FFI, and compiler-owned runtime
representations — is satisfied trivially rather than enforced, which is the
strongest form it could take.

### Addendum to E7 — cleanup validation runs, narrowly, and only in one compiler

E7 said `defer` parses and automatic resource lifecycle does not run. The second
half was too strong and is corrected here.

The self-hosted compiler invokes `env_validate_linear_resource_scope_exit_cleanup`
from two real typechecking paths — function exit
(`compiler/typechecker.gst:9859`, "Step 5.2Q") and explicit return (`:10976`,
"Step 5.2R") — added by `ce211321` on 2026-06-30.

It is narrow. `type_is_resource` (`compiler/typechecker.gst:7690`) keys on a
`Generic` type literally named `Resource` with one argument, so only
compiler-owned `Resource[T]` values are covered. A directory handle is not one,
which is why a program that leaks one still compiles clean.

This check corrected `STEP52_RESOURCE_SEMANTICS.md`, which had stated that
nothing on the real typechecking path invoked these functions.

Rows 15 and 16 stay `PARTIAL`: destructor declaration and enforcement for
user-defined types remain absent, which is what blocks `MutexGuard`
(`TASK_STDLIB.md` CR-5).

### E15 — the four language rows that held, and one that is vacuous (rows 1, 5, 7, 9, 12)

These held on inspection but carried no reproduction, which this file's own rule
forbids. Recorded together.

**Row 7 — no inheritance, traits, or interfaces.** Holds by construction; none
of the keywords exists in either lexer:

```
$ for k in class extends impl trait interface inherits; do
    printf '%-10s gst=%s rs=%s\n' "$k" \
      "$(grep -c "\"$k\"" compiler/lexer.gst)" "$(grep -c "\"$k\"" src/lexer.rs)"
  done
class    gst=0 rs=0
extends    gst=0 rs=0
impl    gst=0 rs=0
trait    gst=0 rs=0
interface    gst=0 rs=0
inherits    gst=0 rs=0
```

**Row 9 — generic structs and enums, no generic functions.** Generic types and
monomorphisation exist in the live compiler (`grep -ci 'monomorph'
compiler/typechecker.gst` → 62), and tests declare generic types (`tests/e2e_adt_pressure_test.gst`, `tests/test_generic_enum_typechecking.gst`).
No `func name[T](…)` form appears in any test or compiler source, so §14's
"user-written generic functions are not available initially" holds.

**Row 1 — arenas are the memory model.** `Arena` is a first-class AST type in
the live compiler (`compiler/ast.gst:38`), referenced 519 times in
`compiler/typechecker.gst`, and the arena surface is registered and
runtime-backed (`std.GenerationalSwap`, `src/runtime/arena.c`,
`src/runtime/scratch.c`). No GC and no user-facing allocator exist.

**Row 5 — `guard … else` is the fallible-binding form.** Implemented and covered
by seven fixtures (`ls tests/*guard*.gst`), including
`tests/e2e_fallible_guard_bootstrap.gst` and
`tests/test_guard_non_wrapper_rhs_rejected.gst`.

**Row 12 — the conversion rule is vacuous, not enforced.** §16 forbids implicit
narrowing and lossy conversion, and no narrowing, widening, or lossy-conversion
logic exists anywhere in the typechecker. That is not compliance: with a single
integer type (E11) there is nothing to narrow *between*. The rule becomes
testable only once §32's fixed-width types exist, and it should be re-checked
then rather than read as satisfied now.

### E16 — the platform surface does not exist (rows 20, 22–26)

Recorded once for all six rows rather than repeated. These are `ABSENT` because
the platform they describe is unbuilt, which `docs/VISION.md`'s Part status
markers already say — Parts XII, XIII, IX, and XI are DEFERRED or SPECULATIVE.
The reproduction matters anyway, because four of the nine source documents
describe this surface in the present tense.

The entire runtime is eight files:

```
$ ls src/runtime/*.c | xargs -n1 basename
approved_scalar_imports.c  arena.c  collections.c  fiber.c
file_io.c  host_io.c  scratch.c  strings.c
```

No HTTP, sockets, TLS, JSON, SQL, jobs, queues, mail, templates, or RPC. Nor is
any of it a registered name:

```
$ for k in Http Sql Postgres Json Rpc Job Queue Mail Route Template Socket Tls; do
    printf '%-10s %s\n' "$k" "$(grep -ci "$k" docs/STDLIB_SURFACE_INVENTORY.md)"
  done      # every one returns 0
```

Nor a language construct — none of `route`, `rpc`, `job`, `task`, `supervisor`,
`component`, `html`, or `migration` is a keyword in either lexer.

Row 22 (dependencies) is the one worth separating. It is `ABSENT` in a different
sense: there is no dependency *mechanism* at all — no manifest, no lockfile, no
resolver — so the rule is neither held nor broken. `docs/VISION_RECONCILIATION.md`
§5 describes what it should become, and the lockfile-diff artifact there is
`docs/VISION.md` §72, marked DEFERRED.

### E17 — the C backend is being retired, and that closes some rows for free (row 27)

The active direction is replacing generated C with Cranelift. `TASK.md` is
executing Phase 18 of the arc `mir-to-cranelift.md` lays out: target and linker
hardening, whole-program differential qualification, self-hosting through
Cranelift, the default flip, then deprecating and deleting MIR-to-C, and finally
the bootstrap seed. Phase 18 stood at 13 of 20 patches at `b47d0049`.

`PARTIAL` because both backends exist: Cranelift is real and under active
development, and MIR-to-C is still the default and the differential oracle
(`AGENTS.md`).

**Two rows in this ledger close when it does, without anyone working on them
directly.**

Row 29 — overflow is undefined behaviour rather than a trap — is a property of C
(E11). Cranelift has no signed-overflow latitude to inherit.

`GEMINI.md` §C is the same shape and is worth recording even though it is not a
row here, because it is the clearest live instance of representation leakage:

> All variables declared within a single function block must have completely
> unique names across that entire block, even if they reside in separate logical
> phases, test steps, or conditional structures.
>
> **Why:** The Gust-to-C transpiler outputs variable declarations directly into
> flat C function scopes.

Neither typechecker diagnoses a redeclaration — `grep -rniE 'redefin|already
declared|shadow|redeclar' compiler/typechecker.gst` returns only function
redefinition and directory-shadow resource tracking, nothing for local
variables. So a program that shadows a name in two disjoint blocks is accepted
by Gust and rejected by the C compiler against generated code, which is the same
diagnostic-quality failure that S1.1 fixed for `str ==`. It is a constraint C
imposes on Gust source, and a native backend has no reason to impose it.

That matters for OD-9 beyond tidiness: a generator must know the backend
flattens scopes in order to emit valid Gust, which is exactly what §0.7 Track A0
disqualifies.

Worth noting that Gust's own model is not the problem. The live typechecker has a
properly nested scope chain — `Scope[ctx]` with `parent` and `bindings`
(`compiler/typechecker.gst:695`), inserted at `:4720` and resolved outward at
`:4731`,`:4744` — which correctly permits shadowing in disjoint blocks. The
collision is introduced downstream, by the flat `variable_types` map (`:743`) and
by C's flat function scopes. The language is right and the backend is what
constrains it.

Filed as issue #105, with an implementation spec for the diagnostic in the
comments. It is unblocked Stdlib work rather than a coordination request, because
`docs/SHARED_SEMANTIC_ZONE.md` places "a diagnostic that rejects a program the
compiler currently miscompiles" outside the shared zone.

**What the transition does not close.** Every row marked `ABSENT` for want of
design rather than backend: 21 (effects), 4 (`Result` and `?`), 3 (`Option`
without `unsafe`), 19 (structured concurrency), 28 (fixed-width integers), and
the platform rows in E16. A native backend does not write any of those.

### E18 — `Channel.Send` does not transfer ownership (row 33)

`docs/VISION.md` §30: "Channels transfer ownership of sent values."

`Channel.Send` type-checks its argument against the channel's element type and
returns `Void` (`compiler/typechecker.gst:2823-2841`). It checks the type and
nothing else:

```gust
if std.str_eq(right_name, "Send") {
    // … arg_type := check_expression(arg0_idx, env, scope, ctx);
    if types_match(elem_type, arg_type, ctx) == 0 {
        // "Semantic Error: Argument type mismatch for Channel.Send…"
    }
}
mut t_void: ast.Type[ctx]; t_void.tag = 3; // Void
return t_void;
```

No move is recorded at the send site — nothing marks the argument moved, and
`grep -n 'Send' compiler/typechecker.gst | grep -iE 'move|linear|consume'`
returns nothing. So the sender keeps a usable binding to a value it has handed to
another fiber.

**Scope of this claim.** What is verified is that the typechecker records no move
at the send site. I did not build the compiler to confirm end-to-end that
send-then-use compiles clean; that is the negative fixture for whoever fixes it.

**Why it belongs beside row 19 rather than on its own.** The two are one gap.
Row 19 says no task owns spawned work; this says no ownership moves at the
boundary between tasks. Together they mean the only concurrency primitives
available — `std.Spawn` and `std.Channel` — provide neither task ownership nor
value ownership, while §20 and §30 describe both as though they were properties
of the system. For a linear value that is a use-after-transfer across fibers with
no diagnostic, which is the class §0.4 calls containment.

Recorded on issue #101 rather than filed separately, because the fix is the same
OD-1 decision.

### E19 — host authority is ambient, and there are no visibility levels (rows 34, 35)

**Row 34.** `docs/VISION.md` §74: "Never silently imported: database access,
networking, **filesystem access**, time, randomness, supplier capabilities."
§95: "Application code cannot access arbitrary host files or spawn arbitrary
processes." Consolidated Rule 4: "No code executes authority it did not declare."

The `os.*` surface is available to every program with no import and no
declaration. Files using it import nothing:

```
$ for g in $(grep -ln 'os\.\(ReadFile\|System\)' tests/*.gst | head -5); do
    printf '%-52s imports=%s\n' "$g" "$(grep -c '^import' $g)"
  done
tests/e2e_codegen_assertions.gst                     imports=0
tests/e2e_file_io_evaluation.gst                     imports=0
tests/e2e_os_system.gst                              imports=0
tests/e2e_filesystem_ops.gst                         imports=0
tests/test_runner.gst                                imports=0
```

The surface includes `os.ReadFile`, `os.WriteFile`, `os.RemoveFile`, `os.OpenDir`,
`os.ReadDir`, `os.GetEnv`, `os.Args`, `os.ExecutablePath`, `os.RunProcess`, and
`os.System` — which is arbitrary shell execution
(`src/runtime/file_io.c:573`):

```c
int os_System(Slice_unsigned_char cmd) {
    …
    char* argv[] = {"/bin/sh", "-c", buf, NULL};
    …
    int spawn_status = posix_spawn(&pid, "/bin/sh", NULL, NULL, argv, environ);
```

So today a Gust program can execute an arbitrary shell command with no import,
no signature annotation, and no declaration anywhere in the program or its build.
That is ambient authority in its strongest form, and it is the precise thing
§0.4 sells the language as eliminating.

**Stated fairly, this is not a defect report.** Gust is a self-hosted compiler
toolchain: it invokes `cc`, reads sources, and writes objects, so it needs these
facilities and there is no mechanism yet to scope them. Nobody made a mistake.
The finding is that the *application-facing* rules in §74 and §95 have no
enforcement, and that the gap is not merely "effects are unimplemented" (E10)
but that the current default is maximal ambient authority in the other
direction.

No issue filed, deliberately. It is not independently actionable — the fix is
the effect system in §0.7 Track A, which `docs/DEMO_TARGET_PROGRAM.md` already
tracks as unowned rows 5-8. A separate issue would restate that with more alarm
and no new action.

**Row 35.** §73's four visibility levels do not exist. No modifier keyword is
present in either lexer:

```
$ for k in pub private public internal export; do
    printf '%-9s gst=%s rs=%s\n' "$k" \
      "$(grep -c "\"$k\"" compiler/lexer.gst)" "$(grep -c "\"$k\"" src/lexer.rs)"
  done
pub       gst=0 rs=0
private   gst=0 rs=0
public    gst=0 rs=0
internal  gst=0 rs=0
export    gst=0 rs=0
```

`import` exists and imports are explicit, which is the half of §73 that holds.
There is no `private`-by-default and no package or application level, so every
declaration a module resolves is reachable. `ABSENT` rather than `VIOLATED`:
nothing claims to enforce it and no mechanism does the opposite.

### E20 — §28's resource opt-in is real; §25's enforcement inherits D-1 (rows 16, 36)

Two Part VII claims that check out better than the surrounding rows, with one
qualification each.

**§28's opt-in exists.** "Root resource types opt into resource semantics through
explicit linear metadata." There is a `#[linear]` layout attribute, parsed
alongside `repr(C)` and `packed` (`compiler/parser.gst:869-872`):

```gust
} else if std.str_eq(layout_attr_name, "packed") {
    is_packed_decl = 1;
} else if std.str_eq(layout_attr_name, "linear") {
    is_linear_resource_decl = 1;
```

It flows to `StructDecl.is_linear_resource` (`compiler/parser.gst:1021`,
`compiler/ast.gst:77`) and is registered by
`env_register_struct_linear_metadata` (`compiler/typechecker.gst:6801`, called
from `:8435`). So the mechanism §28 describes is wired end to end.

This also settles a distinction E13 warned about. `is_linear_resource` is
genuinely **opt-in via attribute**; `is_linear` is **inferred structurally**.
§28's "ordinary strings, slices, collections, and branded structs do not
automatically become resources" is therefore true *of resources*, even though
`str` and slices are automatically linear for move tracking. Same word, two
mechanisms, and only the resource one is opt-in — exactly as §28 says.

Row 16 stays `PARTIAL` for the reason CR-5 gives, not for this one: the opt-in
is real, and destructor *declaration* for user-defined types is what is missing.

**§25 is enforced, by a mechanism D-1 undermines.** Brands are part of the type,
so a value from one context is not assignable where another is expected, and the
typechecker emits dedicated diagnostics — `[BrandMismatch]` for `Arena.get_ref`
and `Arena.Set/Write` (`compiler/typechecker.gst:2661,2668,2676,2709`) and
"Brand Nesting. Mismatched nested brand" (`:1716,:1740`).

That is real enforcement, and it is why row 36 is `PARTIAL` rather than `ABSENT`.
The qualification is that the whole mechanism rests on brand *identity*, which
D-1 derives from identifier spelling rather than from the type. A rule enforced
by comparing brands is only as sound as the way brands are identified, so row 36
cannot be stronger than row 2 until Phase 19 lands.

### E21 — the FFI gate exists and the builtins bypass it (rows 37, 38)

**Row 37 — there is a real gate, and it is inverted.**

`docs/VISION.md` §93: "Native code is forbidden by default. Permitted only
through a signed adapter, an explicit native-code capability, and strong
isolation."

Part of this holds, and it is worth crediting. `extern` is a keyword in the live
lexer, `extern func` declarations parse (`compiler/parser.gst:1169-1199`), and
**calling one requires an explicit `unsafe` block** —
`compiler/typechecker.gst:4047`:

```
Semantic Error: Direct external/native function calls require an explicit 'unsafe' block
```

None of §93's governance exists — no signed adapter, no native-code capability,
no isolation, no separate process — so the row is `PARTIAL` rather than `HOLDS`.

**The asymmetry is the finding.** The built-in `os.*` surface bypasses that gate
entirely. `tests/e2e_os_system.gst` is the whole program:

```gust
func main() {
    mut code := os.System("echo 'FFI_SUBPROCESS_OK'");
    os.LogInt(code);
}
```

No `unsafe` block, no import, four lines, and it spawns `/bin/sh`
(`src/runtime/file_io.c:573`). So a *declared* FFI call is gated and *arbitrary
shell execution* is not. The dangerous path is the ungated one, and it is
ungated because it is built in rather than declared.

This narrows E19 into something actionable. E19 said host authority is ambient
and the fix was the whole effect system. This says the gate mechanism **already
exists** and simply is not applied to the builtins. Applying it is a policy
decision plus the wrap-then-gate sequencing `compiler-plan.md` Step 5.1 already
describes — wrap every existing call site in `unsafe` first, then turn on
enforcement — because the compiler and test runner use `os.*` throughout. Filed as issue #108, posing the question rather than prescribing the answer.

**Row 38 — packages do not exist as a concept.**

§70: "A package is one directory tree with a package manifest." §72: lockfiles
record source hashes, compiler compatibility, signatures, and capability
requirements.

No `package`, `module`, or `manifest` keyword exists in the live lexer, and there
is no manifest or lockfile format in the repository. The only `.toml` files are
`Cargo.toml`, which belongs to the deprecated prototype, and `treefmt.toml`.

What exists is `import` resolving one source file at a time, which makes §70's
"a module is one source file" true de facto. Package identity, the approved
package graph, the capability graph, and the lockfile diff that §72 calls a
primary product surface have no representation. `ABSENT` rather than `VIOLATED`:
nothing does the opposite, there is simply no mechanism.

**Row 37's sibling in §94 holds vacuously.** "Arbitrary networking is forbidden
by default" is true because there is no networking at all — no socket, no
`connect`, no `AF_INET` anywhere in `src/runtime/*.c`.

### E22 — Part XIV's categories are absent; the discipline it asks for exists elsewhere (row 39)

This row is `PARTIAL` for an unusual reason, and the reason is the finding.

**None of Part XIV's named surface exists.** §75's categories — RPC, policy,
migration, browser and component, tenant-isolation, deployment smoke — all
presuppose the platform (E16). §76's capability fakes require capabilities, which
do not exist (E10). §77's deterministic test scheduler is not present: the only
match for a scheduler is a filename,
`compiler/p15_destructor_scheduling_deferred_source.gst`. §78 needs a database.
§79's generated checks — RPC serialization, policy coverage, tenant scoping,
migration manifests, supplier contracts — need all of the above.

**But the discipline §79 argues for is already the strongest thing in the
repository.** Measured at `b47d0049`:

| | |
| --- | --- |
| test programs in `tests/` | 260 |
| named negative fixtures (`*_rejected`, `*_invalid`, …) | 115, of which 102 are `*reject*` |
| `guard-` recipes | 409 |
| parity / differential guards | 82 |
| CI workflows | 66 |

Roughly **44% of the test corpus is negative** — programs asserted *not* to
compile, such as `test_arena_get_ref_brand_mismatch_rejected.gst`. Plus a
differential-oracle regime between MIR-to-C and Cranelift, per-phase closure
guards, and a registry that pins runtime symbol identity.

§79 says generated checking "is not a testing convenience, it is the mechanism
that substitutes for reading", and should be resourced accordingly. That
mechanism exists and is well resourced — it is simply aimed at **the compiler**
rather than at **applications written in Gust**. Part XIV describes the second
and the repository has built the first.

That is worth stating precisely rather than scoring the Part as absent, because
it changes what the remaining work is. The project does not need to learn this
discipline or be argued into it; it needs to point an existing and demonstrably
sustained practice at a different target once there is a platform to aim it at.

`PARTIAL` records exactly that: the practice holds, the surface does not.

### E23 — diagnostics carry structure but no identity (row 40)

`docs/VISION.md` §109: "A diagnostic carries the rejected construct, the rule
violated, the minimal set of edits that would satisfy the rule, and **a stable
rule identifier**."

**What exists.** `CompilerError` is a real structured value
(`compiler/errors.gst:10-15`):

```gust
type CompilerError[ctx] struct {
    kind: ErrorKind,
    message: str,
    span: token.Span,
    file_path: str
}
```

So a diagnostic carries a kind (`ErrorKind`: `ParserError`, …), a source span,
and a file path. That is more than prose, and it satisfies §109's design
constraint that a diagnostic be actionable without whole-program context — spans
are precise.

**What does not exist.** There is no stable rule identifier: no error-code or
rule-id scheme anywhere in `compiler/errors.gst` or `compiler/typechecker.gst`,
and no machine-readable emission — no JSON form. The rule violated is encoded
only in English prose inside `message`, as `"Semantic Error: Brand Nesting
Restriction violated…"`. There are no candidate edits.

**The project has already felt the absence and worked around it.** Patch S1.1
needed a way to pin diagnostic identity, and did it by asserting the *prose is
byte-identical* in both compilers —
`guard-stdlib-s1-str-equality-diagnostic` (`justfile:21637-21642`) greps for the
exact sentence. Its own comment explains why:

> Both compilers must reject with the same words. A drift here means one
> backend's users get a different explanation for the same program.

That is a stable rule identifier implemented as an English sentence. It works,
and it is brittle in exactly the way an identifier exists to prevent: rewording
the message for clarity breaks the guard, so the message cannot be improved
without touching CI.

**Why this row matters more than its size suggests.** §0.5 layer 4 and
`docs/VISION_RECONCILIATION.md` §4 both name the machine interface as the moat —
the argument being that syntax is cheap for a model to learn but a compiler that
exposes structured understanding is not. Structured diagnostics are the most
basic component of that layer, and `docs/VISION.md` §0.7 lists them as demo
scope. `PARTIAL` is accurate: the payload has structure and precise spans; what
is missing is identity and a machine-readable form, which is the half an agent
needs.

### E24 — reproducibility is enforced, on the compiler rather than on runs (row 41)

§111 names four ingredients. One holds, two are absent, and one is absent for
now — but the repository enforces a *stronger* property that §111 does not
mention.

| §111 ingredient | State |
| --- | --- |
| No install-time execution (§15) | **Holds** — no macros, no build scripts, no compile-time execution (E4) |
| Content-addressed builds | Absent — no manifest, lockfile, or content addressing at all (row 38) |
| Virtualized time and randomness (§76) | Absent — requires capabilities (E10) |
| Deterministic scheduling (§77) | Absent (E22) |

**What is enforced instead.** `make bootstrap` requires the compiler to be a
fixed point of itself, byte for byte — `Makefile:199-202`:

```make
./build/gust_stage2_bin compiler/test_runner_entry.gst … > build/gust_stage3.c
diff -u build/gust_stage2.c build/gust_stage3.c && echo "✅ Fixed-point bootstrap convergence achieved!"
cp build/gust_stage3.c gust_v4.c
```

Stage 2 and stage 3 must be identical or the build fails, and the converged
output becomes the committed seed. Object-level reproducibility has its own guard
(`guard-cranelift-phase9g-object-reproducibility`), and Phase 18.15 extends it to
artifact output.

Byte-identical self-compilation is a demanding determinism property, checked on
every bootstrap. It is simply about *the compiler's output*, whereas §111 is
about *a program's run*.

### The recurring pattern — worth reading before concluding anything from the counts

E24 is the third instance of one shape, and it changes how the `ABSENT` and
`PARTIAL` counts should be read:

| Section | What it asks for | What exists |
| --- | --- | --- |
| §79 (E22) | Generated checks that substitute for reading | 409 guards, 82 differential, 115 negative fixtures — aimed at the compiler |
| §109 (E23) | Stable diagnostic identity | Identity pinned as byte-identical English prose in a guard |
| §111 (E24) | A run is a clean observation | Byte-identical fixed-point self-compilation, enforced every bootstrap |

In each case the *practice* VISION argues for is present, well resourced, and
sustained — and pointed at the compiler rather than at applications written in
Gust, because there are no applications written in Gust yet.

That is the difference between a project that has not learned a discipline and
one that has not yet had a second target to apply it to. The counts in this
ledger measure surface: how many rules the compiler enforces for user programs.
They do not measure whether the team can build the missing surface, and on the
evidence of these three rows that is not the open question.

## Maintenance

- A row changes status only with a reproduction, per `AGENTS.md`.
- A `VIOLATED` row is removed only when fixed, never because it is inconvenient.
- When a row's rule changes, `docs/VISION.md` changes first and this file follows.
