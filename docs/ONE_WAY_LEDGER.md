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
| 45 | One spelling of absence | `Option[T]` | a second sentinel alongside it | **VIOLATED** — E14 |
| 33 | Channel ownership | Channels transfer ownership of sent values | sender retaining a sent value | **VIOLATED** — E18 |
| 34 | Host access | Filesystem and process access are never silently available | ambient host authority | **VIOLATED** — E19 |
| 35 | Visibility | private-to-module by default, then package / application / public | everything visible everywhere | **ABSENT** — E19 |
| 36 | Cross-context movement | A shorter-lived value enters a longer-lived context only by cloning or explicit transfer | silently extending a lifetime | **PARTIAL** — E20 |
| 37 | Native code | Forbidden by default; only via signed adapter, capability, isolation | ungated native execution | **PARTIAL** — E21 |
| 38 | Packages | A package is a directory tree with a manifest; lockfiles record provenance | no package identity | **ABSENT** — E21 |
| 39 | Conformance checking | Generated checks substitute for reading | trusting unread output | **ABSENT** — E22 |
| 40 | Machine-readable diagnostics | Structured form with a stable rule identifier and candidate edits | prose-only errors | **PARTIAL** — E23 |
| 41 | Reproducibility | A run is a clean observation; nondeterministic runs are discarded | averaging over noisy runs | **PARTIAL** — E24 |
| 42 | Execution traces | Every run emits a structured, versioned, machine-readable trace | logs | **ABSENT** — E25 |
| 43 | Editions | Source compatibility within an edition; editions are the controlled escape hatch | silent meaning changes | **ABSENT** — E25 |
| 44 | Opacity | A value can be made unprintable and unloggable by its type | secrets leaking into logs and errors | **ABSENT** — E26 |

Counts: 9 `HOLDS`, 9 `PARTIAL`, 8 `VIOLATED`, 1 `DEFERRED`, 18 `ABSENT`.

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

The typechecker carries the same list at `compiler/typechecker.gst:4975,5173`
and applies it at `:5629,5778,6713`. The deprecated prototype has it too
(`src/codegen.rs:71`, `src/typechecker/types.rs:61`), but the live compiler above
is the claim.

> **Citation correction, 2026-08-20.** An earlier revision of this row cited
> `compiler/typechecker.gst:4953,5151`, inherited from
> `docs/STDLIB_SURFACE_FINDINGS.md` F3b, which is pinned to `6c94728d`. Those
> lines have since drifted: `:4953` is now inside a Void-return path and `:5151`
> is `typechecker_matches_template_prefix`. Neither is brand matching. The
> defect is unchanged and the codegen citations were always correct — only the
> typechecker line numbers were stale, and they were propagated here without
> being re-read.

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
tagged union with a `tag` field. Filed as issue #102.

**"and requires `unsafe` to say so" is not established — refined 2026-08-20.**
All five `std.Option` tests use `unsafe`, which is consistent with the claim and
does not prove it: every test doing something one way shows a convention, not a
constraint. That is the shape that misled E26.

The typechecker demands `unsafe` in exactly six places, and none is about union
tags or field assignment:

```
$ grep -ohE '"Semantic Error: [^"]*unsafe[^"]*"' compiler/typechecker.gst
Dereferencing raw pointers is strictly prohibited outside 'unsafe' blocks
Direct external/native function calls require an explicit 'unsafe' block
Pointer arithmetic is strictly prohibited outside 'unsafe' blocks
Raw pointer casts are strictly prohibited outside 'unsafe' blocks
Unsafe function calls require an explicit 'unsafe' block
[UnsafeSubscriptWrite] direct subscript writes require unsafe or explicit write APIs
```

So a plain field write like `opt_some.tag = 0` matches none of the six on its
face. The `unsafe` in those tests may instead be carrying the `*val` dereference
in the match arm, which *is* rule one.

**What is established and what is not.** Established: there is no `Some(42)`
constructor, so writing an `Option` means naming its tag and payload field —
which is the representation leakage §0.7 Track A0 targets and the substance of
issue #102. Not established: that the compiler *rejects* the construction
without `unsafe`. Settling it needs a fixture that constructs an `Option` outside
an `unsafe` block, which this lane cannot write or run.

Row 3 stays `PARTIAL` on the established half. The unestablished half is marked
here rather than left in the row, because a reader deciding what #102 costs
should know which part is measured.

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
single form that exists.

The claim is demonstrated rather than inferred. `tests/test_shared_mutable_aliasing_observed.gst`
passes two `&Box[ctx]` arguments aliasing one value and writes through both:

```gust
func bump_twice(x: &Box[ctx], y: &Box[ctx]) {
    (*x).n = (*x).n + 10;
    (*y).n = (*y).n + 100;
}
```

It compiles and prints 111. Its header states the intent: "If mutation through
references is ever restricted, this program must stop compiling and this fixture
becomes a compile-fail test." That is the strongest evidence shape in this file —
an executable claim that fails loudly when the compiler changes under it. Recorded as `TASK_STDLIB.md`
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

**LIFO verified 2026-08-20**, previously asserted. Row 15 states "`defer`, LIFO"
and nothing had checked the ordering. Codegen collects deferred expressions into
a `defer_stack` in source order and emits them from the end backwards
(`compiler/codegen.gst:3908-3930`):

```gust
mut defer_stack: std.Vector[str, ctx] := std.VectorNew(ctx);
…
defer_stack.Push(std.Clone(ctx, formatted));
…
mut k := len(defer_stack) - 1;
…
mut defer_str := defer_stack[k];
chunks.Push(defer_str);
```

Reverse registration order, which is what LIFO means here. That half of row 15
holds and now rests on a construct rather than on the word appearing in a lexer.
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

The "no handle" half was re-verified by reading rather than inferred from the
absent keywords. The `std.Spawn` branch (`compiler/typechecker.gst:3691-3772`)
validates the argument count and that the spawned function takes exactly one
parameter, and produces no value to hold. No task or handle type is registered
anywhere: the only `task`-shaped name in the typechecker is the fixture type
`TestTaskArg_ctx`, and the sole `handle` is a field on the directory struct
(`:6194`).

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
all rest on `uses` clauses. There is no such keyword.

**Corrected 2026-08-20 — "unstarted" reached past the count, and the correction
is good news.** An earlier revision said no effect is "declared, checked, or
recorded anywhere". Something effect-shaped is recorded, in exactly the place an
effect system would put it. `FunctionSignature` (`compiler/typechecker.gst:633-645`)
carries per-function obligations alongside the types:

```gust
type FunctionSignature[ctx] struct {
    param_names: std.Vector[str, ctx],
    params: std.Vector[ast.Type[ctx], ctx],
    return_type: ast.Type[ctx],
    return_origins: Index[OriginSet[ctx], ctx],
    is_unsafe: int,
    is_extern: int,
    extern_symbol_name: str,
    extern_abi: str,
    requires_unsafe_call: int,
    requires_layout_metadata: int,
    requires_sandbox_arena: int
}
```

That is the structural shape §17 describes — a signature stating what a call
requires, not only what it transforms — at a much coarser grain than
`uses db.read<User>`, and one of these is enforced: calling an `extern` function
outside `unsafe` is rejected (E21).

**But two of the three `requires_*` fields are inert.**
`requires_layout_metadata` and `requires_sandbox_arena` are initialised to 0
(`:653-654`), never assigned 1 anywhere, and
`function_signature_requires_sandbox_arena` (`:658`) is defined and never
called — one occurrence in the file, its own definition.

So the accurate statement is narrower than either "effects exist" or "nothing
exists": **the carrier exists and is partly wired, with two fields already
reserved for obligations nothing yet sets.** That matters for §0.7 Track A item
1, because it means adding effects extends a struct that already has the right
shape and already anticipates more entries, rather than introducing the concept.

The row stays `ABSENT` — `uses` does not exist and no effect in §17's sense is
declared or checked. What changes is the estimate of what starting would cost.

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

There are two integer-ish scalars, `int` and `byte`, and neither is sized in
§32's sense. `byte` is spellable and used — `: byte` and `[]byte` appear in
`tests/*.gst` and `compiler/*.gst` — and is a distinct type tag resolved by the
typechecker. An earlier revision of this block said "there is one integer type,
`int`", which overstated the case; the §32 claim it supports is unaffected, since
none of the six fixed-width types exists either way.

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
compiler — `compiler/codegen.gst:61-62` for the named type and `:1358`
(`if erased_t.tag == 0 { // Int … return "int" }`) after erasure, with no
`long long` or `int64_t` anywhere in the file — and **signed overflow in C is
undefined behaviour**. So on the default backend
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

§11's "safe references are non-null" holds for *references*: there is no null
literal to write in either compiler.

**Corrected 2026-08-20 — the count did not support the whole claim.** An earlier
revision of this block concluded that the restriction is "satisfied trivially
rather than enforced, which is the strongest form it could take". That reached
past what the grep showed. `null`, `nil`, and `NULL` are absent, but **`empty` is
a keyword**, and `empty[T]` is a sentinel meaning *absent* for `Index[T, ctx]`
handles:

```gust
// compiler/typechecker.gst:885 — ordinary safe code, no unsafe block
if left.legacy_origins != empty[Index[OriginSet[ctx], ctx]] {
```

It appears 130 times in the typechecker alone and in 6 test programs, always in
safe code, and it is compared with `==` and `!=` exactly as a null check would
be.

So the language does have a null-equivalent for handles. §11 says absence is
represented with `Option[T]` and that null is confined to raw pointers inside
`unsafe`, FFI, and compiler-owned runtime representations. `empty[T]` is
arguably the last of those — a compiler-owned representation — but it is not
confined to a boundary: it is the ordinary way the compiler's own source spells
"no value", in preference to the `Option[T]` §11 nominates.

The row stays `HOLDS` because §11's sentence is about *references* and that part
is true. But it is narrower than "Gust has no null", and this file should not be
read as saying the stronger thing. `Option` and `empty[T]` are two spellings of
absence coexisting, which is itself a one-way-to-do-it problem — recorded as row
45 rather than left inside this block.

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

**Row 7 — no inheritance, traits, or interfaces.** Holds, and more strongly than
the keyword grep shows. There is no method-receiver syntax at all: `receiver`
appears nowhere in `compiler/parser.gst`, and no test defines a method on a
user type (`grep -rlE '^func \([a-z]' tests/*.gst` → nothing). **A user cannot
define a method on their own type**, so the collection methods that exist —
`Vector.Push`, `HashMap.Get` — are compiler builtins rather than a user-facing
dispatch mechanism.

That one fact settles three rows at once, which is why it is recorded here rather
than three times:

- **Row 7** — inheritance and traits are impossible, not merely unspelled.
- **Row 11** — operator overloading is impossible for the same reason: there is
  no user-supplied function for an operator to dispatch to. E4's grep found no
  "overload" string; this is why there is nothing to find.
- **Row 8** — the data-oriented interface registry in
  `docs/VISION_RECONCILIATION.md` Appendix B, and §12's "small explicit function
  tables", are **not currently expressible by a user**. They would be a compiler
  feature or nothing. That is worth knowing before either is proposed as a
  library pattern.

The keywords are absent as expected:

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

**Row 9 — generic structs and enums, no generic functions.** *Decided rather than
merely observed, as of 2026-08-20:* OD-2 resolved in favour of compiler-owned
derivation, so the absence of user-written generic functions is a settled rule
rather than a not-yet. That changes how this row reads — it is not a gap awaiting
closure, and a compiler that later grew generic functions would be *departing*
from §13 rather than completing it.

Generic types and
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

`PARTIAL` because both backends exist, and this now rests on the driver rather
than on a roadmap's status line. `compiler/test_runner_entry.gst` exposes the
choice to users directly:

```
gust --backend mir-to-c <source.gst>
gust --backend cranelift -o <output> <source.gst>
  --backend <mir-to-c|cranelift>  Select the backend explicitly.
  -o <output>                     Required only by the cranelift backend.
```

The driver also carries `backend_was_explicit` alongside the selection (`:17,20`),
which is the field the no-silent-fallback rule in `docs/SHARED_SEMANTIC_ZONE.md`
needs: an explicitly requested Cranelift build must fail rather than quietly
retry through C, and distinguishing explicit from defaulted is what makes that
expressible. MIR-to-C remains the default and the differential oracle.

**Row 29 closes when it does, without anyone working on it directly**, and
`GEMINI.md` §C is the same shape although it is not a row here.

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

`Send` itself records no move — nothing in that branch marks the argument moved.

**Corrected 2026-08-20 after reading the committed fixtures.** An earlier
revision of this block concluded from that grep that ownership transfer is
impossible and the sender always keeps a usable binding. That is too strong.
`move` is a keyword, and transfer at a send *is* tracked when the caller asks for
it — `tests/test_arena_moved_through_channel_invalid_rejected.gst`:

```gust
mut chan: std.Channel[Arena, ctx] := std.ChannelNew(ctx);
chan.Send(move ctx);
mut n_ref_after_move := ctx.get_ref(n);   // rejected: use after move
```

So the gap is narrower and different in kind than "no ownership transfer
exists". The mechanism exists and is enforced; it is **opt-in at the call site**
rather than a property of the channel. §30 says "channels transfer ownership of
sent values", which reads as automatic. A caller who omits `move` is not
transferring anything, and nothing at the send site requires it.

The row stays `VIOLATED` on that basis — §30 describes a property of channels and
the compiler provides a property of call sites — but the remedy is smaller than
the earlier text implied: require `move` for non-copy sends, rather than build
transfer semantics from nothing.

Two neighbouring fixtures bound the behaviour: `e2e_channel_ping_pong.gst` sends
a copy value with no `move` and is expected to pass, and
`test_channel_mismatched_send_rejected.gst` confirms the element-type check.
**Whether `chan.Send(x)` on a linear `x` without `move` is accepted is the open
question**, and it is the fixture whoever takes this on should write first.

### The fixture that would settle it — specified, not written

`tests/` belongs to the lanes that own it and is outside this lane's boundary, so
this is a specification rather than a patch. It is also deliberately not written
blind: the expected outcome is exactly what is unknown, so committing a fixture
that asserts one direction would be guessing, and a negative test asserting the
wrong direction is worse than no test.

Take `test_arena_moved_through_channel_invalid_rejected.gst` and delete one
keyword:

```gust
type CustomNode[ctx] struct { val: int }

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut n: Index[CustomNode, ctx] := os.ArenaAlloc(ctx);
    mut chan: std.Channel[Arena, ctx] := std.ChannelNew(ctx);
    chan.Send(ctx);                        // no `move`
    mut after := ctx.get_ref(n);           // does this still compile?
    after.val = 100;
}
```

The existing fixture is the same program with `move ctx`, and it is rejected. So
this one isolates a single variable: whether the send *requires* the keyword.

Both outcomes are informative, which is why it is worth running before anything
is scheduled:

- **Rejected** — `Send` already demands `move` for a linear argument. §30's
  claim is then substantially true in practice, row 33 narrows to a
  documentation correction, and the "require `move` for non-copy sends" work is
  already done.
- **Accepted** — the sender keeps a usable arena binding after handing it to
  another fiber, which is the gap as this row describes it, and the fixture
  becomes the compile-fail test for the eventual change.

Name it for whichever it turns out to be, following the convention in `tests/`:
`test_channel_send_without_move_rejected.gst` if it rejects, or
`e2e_channel_send_without_move_observed.gst` if it compiles — the latter shaped
like `test_shared_mutable_aliasing_observed.gst`, which records what the compiler
permits and says in its header what must change if that ever stops being true.

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

Row 16 stays `PARTIAL`, but for a wider reason than CR-5 alone, found while
auditing the `PARTIAL` rows.

**§28's transitivity claim does not hold for the opt-in.** The section says
"Linearity propagates transitively. Any struct containing a linear field is
itself linear." That is true of the *structural* linearity governing move-versus-
copy — `typechecker_is_linear` (`:1761`) walks a struct's fields through
`struct_registry` and returns linear if any field is. It is **not** true of the
`#[linear]` marker. `env_struct_is_linear_resource` has exactly two consumers
besides its own definition — a wrapper at `:6820` and
`env_struct_has_resource_tracking_metadata` at `:6850` — and neither walks
fields. Nothing propagates resource-ness from a field to its container.

Nor does the other mechanism pick it up: `typechecker_is_linear` never consults
the resource registry (zero references to `linear_resource` in its body), so it
classifies by type tag and field recursion alone. A `#[linear]` struct whose
fields are all `int` is therefore linear by neither route, and a plain struct
containing it does not become a resource.

So §28 states one rule over a word that names two mechanisms, and the rule holds
for the one it is not about. That is the same conflation E20 warned of, now with
a consequence rather than only a caution: **the marker is opt-in per type and
does not compose.**

`PARTIAL` is still right — the opt-in exists and is wired (E20) — but the row's
"propagating transitively" is the half that does not hold, alongside CR-5's
missing destructor declaration for user-defined types.

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

**Corrected 2026-08-20: this row was `PARTIAL` and should be `ABSENT`.** The
error was mine and it is worth naming, because it is a different failure from the
count-sweep ones.

The rule this row states is *generated checks substitute for reading*, and what
it governs is applications written in Gust. Nothing generates a check for one.
Scoring it `PARTIAL` credited a related practice aimed at a different target —
the compiler's own guards — which is scoring **the project** rather than **the
rule**. This file's own statement of purpose is that `docs/VISION.md` is
authoritative for what a rule is and this file is authoritative for whether it
holds; a status that reflects something other than the rule crosses exactly that
line, the same way row 14 did before it was corrected.

So the status is `ABSENT` and the observation stays here, where it belongs:

> The discipline §79 argues for exists, is well resourced, and is aimed at the
> compiler rather than at applications. The remaining work is aiming an existing
> practice at a new target, not establishing one.

That sentence is the useful part and it survives the correction intact. What it
is not is evidence that the rule partly holds.

**The general form, since row 41 sits next to it and stays `PARTIAL`.** A status
is `PARTIAL` when the rule is partly enforced *for the thing the rule governs* —
row 41 qualifies, because "no install-time execution" is one of the four
ingredients §111 names and it genuinely holds for any run. A status is not
`PARTIAL` because something admirable exists nearby.

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

### The `PARTIAL` audit, completed

All ten `PARTIAL` rows were re-tested against the question that moved row 39:
*does the evidence support the status, or does the status reach past it?*

| Row | Outcome |
| --- | --- |
| 39 Conformance | **Moved to `ABSENT`.** Its status credited the compiler's own guards — a practice aimed at a different target from the rule |
| 16 Resources | Kept, **wider reason**: §28's transitivity holds only for the mechanism the section is not about |
| 15 Cleanup | Kept, **half upgraded**: LIFO verified from `defer_stack` emission rather than asserted |
| 27 Backend | Kept, **evidence upgraded**: from a roadmap's status line to `--backend` in the driver |
| 3 Absence | Kept, **claim split**: no `Some(42)` constructor is established; "requires `unsafe`" was inferred |
| 41 Reproducibility | Kept — **and the reasoning tested, not assumed.** See below |
| 31, 36, 37, 40 | Kept. Each states a conjunction where part is enforced for the thing the rule governs: field-transitivity without the `copyable` marker (E13); brand diagnostics capped by D-1 (E20); `extern` gated by `unsafe` without §93's governance (E21); a structured `CompilerError` without identity or a machine form (E23) |

**Row 41 deserves its own note, because I used it as the contrast case when
correcting row 39 and had not applied the test to it.** The worry is that it
fails the same way: §111 governs *runs as observations*, and nothing observes a
run, so partial credit might be coming from outside the rule again.

It survives, and the distinction is real rather than convenient. Row 39's credit
came from a practice aimed at **a different target** — guards over the compiler,
where the rule is about applications. Row 41's credit comes from **one of §111's
own four enumerated ingredients**, aimed at the same target: no install-time
execution holds (E4, verified independently — no `const`, `comptime`, or
const-folding machinery anywhere), and it holds for any Gust program that ever
runs. A conjunct of the rule, for the thing the rule governs, is what `PARTIAL`
means.

Ten rows, and **not one was simply confirmed as written**. The yield was
*independent of which rows looked worth auditing* — none of the ten looked
suspicious beforehand, and the two largest findings (row 39's misfiled status,
row 16's transitivity gap) came from rows that read as settled. The same held
across the other sweeps: the citation defect had propagated into three
documents precisely because every document agreed, and the count corrections
landed on rows whose greps were accurate.

**So spot-checking the interesting rows is the move this file's own data
refutes.** If a set is worth auditing, audit the set. Four kept their status
with better evidence, four kept it with a corrected or narrowed reason, one split
into an established and an inferred half, and one moved. None of the ten looked
suspicious beforehand, which is the argument for auditing a whole set rather than
its interesting members.

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

### E25 — traces are a stubbed no-op; editions do not exist (rows 42, 43)

**Row 42.** §108: "Every run emits a structured, machine-readable trace. The
trace is a first-class artifact with a versioned schema, not a log format. It is
one of the three things humans actually read (§0.12)."

No run trace exists. The only thing in the compiler named "trace" is a
**no-op**:

```gust
// compiler/typechecker.gst:8618-8619
func typechecker_log_trace(emoji: str, message: str, ctx: &Arena) {
}
```

An empty body, with **40 call sites** that all compile to nothing. That is
compiler debug logging which has been stubbed out, not an execution trace, and it
records nothing about a *program's* run in any case.

Worth noting what the stub implies rather than only that it is empty: the
instrumentation *points* exist and are maintained through bootstrap, so they map
where the compiler does something worth recording.

They are **not** a substrate for a structured trace, and an earlier draft of
`docs/UNBLOCKED_CONTAINMENT_WORK.md` said otherwise. The signature is
`(emoji: str, message: str, ctx: &Arena)` and every caller passes prose —
`"scope_new: spawned root scope"`. Reusing them for structured emission means
changing 40 signatures. Treat them as a map, not as plumbing. That is unrelated to §108 — which needs
capability sets, exercised effects, denied authority attempts, and query
predicates, none of which exist (E10, E16) — but it is the difference between an
absent mechanism and an absent decision.

§108 is the only one of §0.12's three human-read artifacts that could exist
without the platform, and it is written up as a proposal in
`docs/UNBLOCKED_CONTAINMENT_WORK.md`, now with a versioned schema
(`gust.trace/1`) and a first-patch scope. The compiler already computes more than the
two expressible bullets need: `ExpressionProvenance` carries a resolved type and
an `AddressOriginMetadata` per expression, and all nine origin categories are
live (`compiler/typechecker.gst:5-24`). The capability manifest needs effects; the lockfile diff
needs packages (row 38). A trace of allocation and context lifetimes at region
granularity, and of typed error propagation, could be emitted today, because
regions and errors both exist. It is not, and nothing schedules it.

**Row 43.** §99 and §100 promise source compatibility within a language edition,
editions as the controlled escape hatch, and projects pinning an edition and a
platform release line.

There is no edition concept anywhere: `edition` and `version` are not keywords in
the live lexer and `edition` appears in no compiler source file. There is no
manifest to pin one in (row 38).

`ABSENT` rather than `VIOLATED` in both cases: nothing claims to do the opposite,
and Part XIX marks itself post-1.0 and not a commitment. Recorded because §103
calls compiler-assisted migrations "a core product feature", and every migration
mechanism it describes depends on an edition boundary that has no representation.

### E26 — §81 is half-mechanised: linear exists, opaque does not (row 44)

§81: "Secrets are opaque linear values. They have no readable string
representation in safe code. Secrets cannot be logged, serialized, formatted,
returned to clients, or compared except through approved operations."

Its rationale is one of the sharpest containment arguments in the document:

> an agent cannot leak a secret into a log line or an error message, because the
> type does not permit it. Among the most frequent mistakes in generated code and
> among the most expensive.

The claim splits into two mechanisms, and exactly one exists.

**Linear — exists.** `#[linear]` marks a type as a resource and the metadata is
wired end to end (E20). Whatever "secrets are linear values" would require, the
opt-in half of it is already there.

**Opaque — does not.** There is no `Secret` type in the typechecker or the
registered surface, and no opacity mechanism of any kind: nothing marks a type
as unprintable, unformattable, or unloggable
(`grep -ciE 'opaque|no_format|not_formattable' compiler/typechecker.gst` → 0).

**Correction, 2026-08-20.** An earlier revision of this block added that
"`std.Format` and `os.LogStr` will accept whatever they are given". That is
false. `std.Format` is strongly typed (`compiler/typechecker.gst:3810-3923`): it
requires a literal format string, parses its `%` specifiers, and checks each
argument — `%s` requires exactly `Str`, `%d` and `%r` require `Int`, `Byte`,
`Bool`, or `Index`. **A struct cannot be passed to it at all.**

That narrows the row rather than closing it. `std.Format("%s", secret)` is
already rejected; `std.Format("%s", secret.value)` is not, and that is the whole
leak. So the missing mechanism is not a predicate on a declaration but
propagation of opacity through a field read, which is a different and larger
change than the attribute this row originally implied.
`docs/UNBLOCKED_CONTAINMENT_WORK.md` proposal 1 carries both shapes.

So the row is `ABSENT`, but the gap is narrower than the section implies. What is
missing is a way for a type to refuse formatting — a property of the type system
rather than of the platform. It does not need effects, a database, or a supplier
model. `secret.use<"stripe">` does need effects; "this value has no string
representation" does not.

Recorded as its own rule rather than folded into E16 for that reason: unlike the
platform rows, this one is not blocked on the platform. Written up as a concrete
proposal in `docs/UNBLOCKED_CONTAINMENT_WORK.md` — a fourth layout attribute
beside `#[linear]`, `#[packed]`, and `#[repr(C)]`, checked at the two formatting
dispatch sites that already resolve `std.Format` by name.

### §22 and the platform rows

`transaction`, `tx`, and `savepoint` are not keywords in the live lexer. §22
joins the platform surface already covered by E16 and is not given a separate
row — a transaction block is meaningless without a database, and nothing about it
is checkable before one exists.

## Evidence shapes, strongest first

Rows in this file rest on evidence of four kinds. They are not equally durable,
and the difference matters when the compiler moves under them.

| Shape | Fails when the compiler changes? | Example |
| --- | --- | --- |
| **A committed guard** | Yes, in CI | `guard-stdlib-s1-str-equality-diagnostic` pins the `str ==` message in both compilers (E5) |
| **A committed fixture** | Yes, on the next run | `test_shared_mutable_aliasing_observed.gst` compiles and prints 111 (E6); `test_arena_moved_through_channel_invalid_rejected.gst` (E18) |
| **A quoted construct** | No — but a reader can check it | `type Scope[ctx]` at `compiler/typechecker.gst:695` (E17) |
| **A grep count** | No, and it silently rots | `grep -c '"uses"'` → 0 (E10) |

Every self-correction recorded in this file moved a claim *up* this table, and
the two that changed a finding's substance — E26 and E18 — were both grep counts
that a construct or a fixture later contradicted. A count proves a word is
absent; it does not prove the thing the word names is absent, because the thing
may be spelled differently or reached another way.

**The count sweep is complete: 11 of 11 examined.** Five corrected — E26
(`std.Format` is strongly typed), E18 (`move` exists and transfer is enforced),
E14 (`empty[T]` is a second spelling of absence), E10 (`FunctionSignature`
already carries per-function obligations), E11 (`byte` is a second integer-ish
scalar). Six confirmed, three of them after a real attempt to break them:

- **E12** — exhaustiveness is checked in both compilers.
- **E15** — no method-receiver syntax exists, so traits and operator overloading
  are impossible rather than unspelled.
- **E23** — `report_error`'s leading integer is a `kind_tag`, a category, not a
  per-rule identifier. The row could have died here and did not.
- **E4** — no `const`, `comptime`, `constexpr`, `static_assert`, or `eval`
  keyword, and no const-folding or compile-time-evaluation machinery in the
  typechecker or codegen. With E15, §15's ban on user-programmable compile-time
  execution holds by construction: there is no mechanism, not merely no macro
  syntax.
- **E16** — checked by an independent route rather than the same greps: the only
  libraries linked anywhere in the build are `pthread` and `m`. No TLS, no
  network, no database client is linked, which is a different kind of evidence
  from "no HTTP symbol is registered" and agrees with it.
- **E25** — no language-version or edition pin exists in `Makefile` or
  `flake.nix` either, so the absence is not merely of a keyword.

Of the five corrections: one changed a design (E26), three changed an estimate or
a scope (E18, E14, E10), and one changed only a sentence (E11). Recording that
split matters more than the raw count, because it says how far a count-backed row
can be trusted before it is re-read: usually the direction is right and the
boundary is wrong.

**How much weight a count-backed row carries, measured.** Six count-backed rows
have been re-examined against the code they summarise. Four had a claim that
reached past the count and were corrected — E26 (`std.Format` is strongly typed),
E18 (`move` exists and transfer is enforced), E14 (`empty[T]` is a second
spelling of absence), E10 (`FunctionSignature` already carries per-function
obligations). Two were confirmed and came out *stronger* than the count showed —
E12 (exhaustiveness is checked in both compilers) and E15 (users cannot define
methods at all, so traits and operator overloading are impossible rather than
unspelled).

Four corrected, two strengthened. The lesson is not that counts are usually
wrong; it is that **counts are where claims drift**, in either direction, because
a count answers a narrower question than the sentence built on it. Three of the
four corrections also made the underlying problem *smaller or better founded*
rather than larger.

**So prefer the strongest shape available, and say which one a row rests on.**
Absence claims are the hard case: nothing can be committed that fails when
something starts existing, so a grep count is often all there is. Where that is
true, say so explicitly rather than leaving the reader to assume a fixture backs
it — E10 and E16 are the large ones, and both are honest about resting on
absence.

## Examples invite capabilities the prose disclaims

A document can state a caveat correctly and still mislead, because a reader
copies the example rather than the paragraph above it. Every Gust code block in
this lane's documents was checked against what the compiler can express — 20
blocks across four files.

| File | Blocks | Result |
| --- | --- | --- |
| `ONE_WAY_LEDGER.md` | 13 | Clean by construction — all are verbatim quotes from `compiler/*.gst` or `tests/*.gst`, and their citations were checked in the citation sweep |
| `UNBLOCKED_CONTAINMENT_WORK.md` | 4 | Clean — two verbatim compiler quotes, one using real `std.Format` calls, and the JSON-writer signatures, which correctly write `func f(args) ReturnType` |
| `DEMO_TARGET_PROGRAM.md` | 2 | One defect, fixed: the program is written in method-call style and a user cannot define a method, so every call in it must be compiler- or platform-provided. Now says so |
| `VISION_RECONCILIATION.md` | 1 | One defect, fixed: `func … -> str`. **Gust has no arrow return syntax** |

The arrow is worth recording as its own instance. It was copied from
`full-stack-slice-0.md`, an uploaded document, and it is not Gust: a return type
follows the parameter list directly, the only arrow token in the lexer is
`FatArrow` (`=>`) for match arms, and every ` -> ` in `compiler/*.gst` is inside
a comment. That is the citation-propagation failure again in a new medium —
**syntax inherited from a source document, never checked against the grammar.**

The general rule this sweep produced:

> A caveat in the prose does not neutralise the capability an example invites.
> If a block shows something the compiler cannot express, say so *in the block's
> vicinity*, not only in a section elsewhere.

`DEMO_TARGET_PROGRAM.md` is the case that makes it concrete: §14 already said the
query builder is a compiler feature and not user-facing, and the demo still
invited the opposite reading by showing a method chain with no note attached.

## Verify the checker before believing it

Every verification script written while auditing this file was wrong on its first
run, and each one was wrong differently:

| Check | Reported | Actually |
| --- | --- | --- |
| §0.18 index vs evidence | 5 sections missing | 2 were cross-document `§` refs to `VISION_RECONCILIATION.md`; 3 were inside the range `§75–§79` |
| `std_*` symbol count | 21 symbols | 20 — the regex matched the summary row *describing* the symbols |
| Linked libraries | `-locked`, then `-ladder`/`-layout`/`-legacy` | `--locked` is a cargo flag and the rest are hyphenated recipe names; the real link set is `-lpthread -lm` |
| A paginated API read | 100 check-runs (88 success / 12 queued) | 119 — the un-paginated call silently truncated at the page limit, and the short answer looked complete |
| A denominator taken mid-creation | "54 total, so 54 outstanding" | 71 total — the run set was still being created, so the denominator itself was still growing |
| A gate check on an empty parse | "0 outstanding — proceed" | 4 outstanding; the parser mismatched its input format, read zero items, and zero-of-zero satisfied the go condition |
| An edit to this section | "ok" | nothing changed; the anchor existed but the replacement never matched |

Three distinct traps, one root cause: **each tool treated a structured document
as flat text.** These documents are not flat. A `§` belongs to whichever document
its sentence names. A table row may describe the table rather than belong to it.
A range compresses an enumeration. Generated files state their own counts, so
they necessarily contain rows that look like data and are not.

The scoreboard is worth holding before acting on a tool's complaint. Of 47
`path:line` citations, 3 were wrong. Of 11 measured counts, 1 was wrong. Of the
checkers, **every one was wrong on first run.** The documents here have been
roughly 93–96% accurate; the tools written to check them, none.

That asymmetry has a cause rather than being luck. The documents were written by
reading code; the checkers were written by pattern-matching text.

> When a checker disagrees with a document, investigate the checker first. Only
> after the checker survives scrutiny is its complaint evidence about the
> document.

**The silent direction is the expensive one.** A false positive costs the next
reader the time it took to write the check. A false negative — a check that
passes because its pattern never matched anything — costs nothing visible and
protects nothing. **In a sweep that is worse than in a gate: a gate that wrongly
refuses gets investigated; a sweep that wrongly reports clean ends the
investigation.** Observed, not reasoned — a shell `grep` returned nothing on a
line a Python regex found for the same pattern, and a dangling `D-6` citation
survived one search because only the other was believed. The third row above is that failure: an edit asserted its
anchor existed, reported success, and changed no bytes. Elsewhere in this
repository the same shape appeared as a regex missing `re.M` that reported
"sources parsed: 1".

**Adoption measures a rule's generality, not its coverage — and it was ranked
wrongly here.** The empty-set guard — the one added after a
malformed read returned zero runs and a go signal — was taken up by another
lane's checker, and an earlier revision of this file promoted "a rule another
tool adopts" to the top of the evidence-shape table above. That was a
misfiling, and it was tested almost immediately: the adopting lane, holding the
guard, still shipped a false conclusion — it reported that CI had stopped
entirely, from a momentary zero.

The guard was not defeated. It was answering a different question. It protects
against an **empty** set; the failure was a **transient** one. Both satisfy
"nothing is running" with identical confidence.

Two corrections follow. The shape table ranks evidence *for a row about the
compiler*, by whether it fails when the compiler changes; adoption is evidence
about a rule's reach and belongs nowhere in it, so the row is removed. And the
guard itself was incomplete:

> **Non-emptiness and persistence are different failure modes of the same
> shape.** A check whose passing condition can be satisfied by a momentary
> reading must require that reading to persist across genuinely spaced samples.

`/tmp/gate98.sh`, on which this lane's merge decision rests, had the identical
hole — its assertions proved the sets were non-empty, not that zero-outstanding
held twice. It now requires both, spaced far enough apart to span a dispatch gap.
The lesson generalises past CI: any count read from a live system can be
momentarily zero for reasons unrelated to the thing being measured.

### One rule, many instances: phrase a gate as presence, not absence

The guards above accumulated one patch at a time — assert the set is non-empty,
then assert the zero persisted — and that was the wrong shape. They are four
symptoms of a single fault, and each patch only closed the way it had already
failed.

The fault: **a condition phrased as an absence is satisfied by every kind of
nothing.** "No outstanding items", "no failures", "no violations" are all true of
a set with nothing in it, and nothing about such a set announces itself.

Every one of these was observed rather than constructed, and each read as a
confident clean pass:

| Nothing | Where it came from |
| --- | --- |
| An **empty** set | A parser mismatched its input format and read zero records; the gate reported zero outstanding and a go signal while four checks ran |
| A **truncated** set | An un-paginated read returned 100 of 119; internally consistent, wrong by nineteen |
| A **momentary** zero | A dispatch gap between admissions; two samples 90s apart landed inside the same gap and looked like persistence |
| A **stalled** unit | A run `queued` for 2h28m with nothing executing repo-wide — the status field reports the run's state correctly and says nothing about whether it will ever run |
| A **cancelled** wave | Three PRs with 63, 64 and 65 runs, every one `cancelled`, nothing queued or running — zero failures, zero pending, and dead |
| A **context-calibrated floor** | A gate asserting `len >= 30`, correct for a 34-run wave, refusing a legitimate 2-run wave permanently |
| A **field that misnames itself** | `run_started_at` on a CI run that has never executed — set at *creation*, so it equals `created_at` and reads as a start time on a run still `queued` |
| The **same floor, silent** | The watcher armed beside that gate carried `len(r) < 5: exit` — on a 2-run wave it reports nothing, and nothing is what a quiet watcher is meant to report |

The durable fix is not a fifth guard. It is inverting the predicate:

> **Gate on the presence of the thing you require, not on the absence of the
> thing you fear.** Require every unit to be *completed and successful*, and
> require the count to be plausible. Non-emptiness and persistence stop being
> separate patches, because an empty set, a truncated set, a momentarily quiet
> set and a wholly cancelled set all fail a presence test by construction.

**A sixth instance, and the only one this lane did not find in its own
instruments.** `AGENTS.md` § *A phase is not closed while its Level 3 owner is
failing* records the same fault, discovered independently and written down before
this file restated it:

> Every phase closure guard asserts that the Level 3 suite — `Cranelift
> Historical Full` — "remains available, registry-derived, and separately
> runnable". **None of them assert that it passes.** A suite that exists and
> fails satisfies that check exactly.

That is an existence test standing in for a success test — precisely the
inversion this section argues for, reached from a different direction.

**It is better evidence for the rule than the other five, and it is worth being
clear why.** The first five were all found by one lane in its own tools inside a
single session, which is a sample with an obvious common cause. This one is in a
different artifact, found by someone else, and it survived long enough to cost
something: `AGENTS.md` records the suite failing 30 of 30 nights from 2026-07-21
to 2026-08-19 while two phases closed citing Level 3 evidence. Verified
independently — run `32243700245` on `main`, `Cranelift Historical Full`,
2026-08-19T10:38:56Z, `completed/failure`.

**And it is the only instance that shipped a wrong conclusion rather than being
caught before one.** The other five were caught by the check that found them; a
month of unnoticed red was not. The cost of an absence-phrased gate is not that
it fails loudly — it is that it passes quietly for as long as nobody looks.

**And the red is worse than "the most recent run failed", which is how an
earlier revision of this block put it.** Counted independently across the
workflow's whole retained window on 2026-08-20, every run of `Cranelift
Historical Full` from 2026-07-21 to 2026-08-20:

| Conclusion | Runs |
| --- | --- |
| `failure` | 32 |
| `cancelled` | 2 |
| `in_progress` | 1 |
| **`success`** | **0** |

There is no green Level 3 evidence at any depth, not merely a stale one. A row
citing Level 3 is not citing something that has gone out of date; it is citing
something that has never existed in the retained window. Understating it made the
closure loophole look like a lag rather than a floor — the difference between a
suite that slipped and one that has never passed while phases closed on it.

Two notes on how the figure was obtained, both families this file already tracks.
A borrowed count put it at "fifteen runs across eleven days", short by twenty
runs and nineteen days, consistent with an un-paginated read. And the count was
totalled by conclusion rather than read down the list, because a list beginning
with twenty consecutive failures reads as conclusive well before it is complete.

The diagnosis of why that suite is red belongs to the Cranelift lane and is
already characterised there. What is recorded here is only the gate shape.

**Two further instances, and the second is a fault in the fix rather than in
what it replaced.**

`cancelled` is neither success nor pending. A gate counting only failures and
pending runs reads a wholly cancelled wave as clean.

Observed on 2026-08-20: three PRs sat with 63, 64 and 65 runs respectively, every
one `cancelled`, nothing queued and nothing running — zero failures, zero
pending, and dead. The state persisted roughly two hours before their lane
re-dispatched them, and it was invisible to an absence-phrased gate throughout.
Presence rejects it; absence cannot.

Stated in the past tense deliberately. Those PRs have since been rebased and now
carry live waves, which is what makes this a clean case study rather than a live
incident — and a present-tense claim about a repository that changes hourly is
the same defect as an inherited line citation, one row of which this file already
records against itself.

The other is subtler and was self-inflicted. The presence gate carried a
plausibility floor — assert the run set has at least 30 members, so an empty or
truncated read is refused. That floor was calibrated on a 34-run wave. The next
PR from this same lane changes only files under `docs/`, draws a far smaller
wave, and the assertion refuses it **forever**: not a false pass but a permanent
false refusal, which is the same fault pointing the other way.

**So a plausibility bound is itself a claim about context, and it rots like any
other.** The fix is to stop asserting a number and establish the denominator
empirically, reusing the persistence rule rather than inventing a second
mechanism:

> **A total is a denominator once it has stopped changing across spaced
> samples.** Before that it is a reading, and "2 outstanding" is
> indistinguishable from "2 of 35 registered so far".

**The same floor was in a second instrument, and it would have failed silently.**
Retiring the watcher armed alongside that gate showed it carried
`if len(r) < 5: exit` — the identical context-calibrated bound, written at the
same time, in the tool whose whole job is to report. On a two-run wave it would
never have fired: no false alarm, no error, just permanent silence
indistinguishable from "nothing to report".

That is the *check you run in passing* rule with a concrete second instance, and
it sharpens it. The gate was fixed carefully because it was the thing being
reasoned about; the watcher kept the bug because it was infrastructure around
that reasoning. **The defect does not live in the artifact you are examining — it
lives in the one you built to examine it with.**

It is also the worse direction of the two. A gate with a bad floor refuses
loudly and gets investigated. A *watcher* with a bad floor reports nothing, and
nothing is what a quiet watcher is supposed to report.

Deriving the expected wave from the workflow files instead was tried and
abandoned: a regex over `.github/workflows/*.yml` reported 11 unfiltered
workflows where a direct check found 5, because it only recognised a `paths:`
block directly beneath `pull_request:`. Structured text read as flat text, for
the third time in this area. The observed total, once stable, is the more
reliable denominator and needs no parser.

**The fifth instance is the one that tests the inversion, because it was
discovered after the rule was written.** A run `queued` for two and a half hours,
with zero runs executing anywhere in the repository, is a fifth kind of nothing —
and unlike the previous four it reports its own state accurately. `queued` is
true. It simply carries no information about whether the run will ever start.

Nothing was patched to handle it. A queued run is not a success, so the presence
gate rejected it by construction, without the case having been anticipated. That
is the difference between an inversion and a guard: **a guard closes the hole you
found, an inversion closes the ones you have not.** Four patches would have
needed a fifth; the presence phrasing needed none.

It also distinguishes two situations that look identical from a run's own status
field and have opposite correct responses — waiting behind other work, versus a
queue that is not draining at all. The run says `queued` in both. Telling them
apart requires looking at the *runner* side: whether anything is executing
repository-wide, and whether every queued item is aging together. Measured here —
zero self-hosted runners, five queued runs aged 73 to 94 minutes, nothing
`in_progress` — it is capacity, and the correct action is to keep waiting and
touch nothing, since re-dispatching would replace the run and destroy the age
evidence that identified the case.

`AGENTS.md` § *Merge policy* already says `completed success`. Every one of these
failures came from a gate that paraphrased it as "nothing outstanding, nothing
failed", which is not the same condition and is satisfied by strictly more
states. `/tmp/gate98.sh`, on which this lane's merge rests, was rewritten as a
presence test for exactly this reason, and it now rejects a wholly-cancelled run
set that its previous form would have passed.

> **A check for this, and an honest account of what it is worth.** The drift is
> narrow enough to grep: an enumerating numeral bound to a countable noun,
> outside tables and block quotes.
>
> ```
> NUM='(one|two|...|twelve|[0-9]+)'; NOUN='(instances?|artifacts?|rows?|entries|sweeps?)'
> # flag "$NUM $NOUN" in prose lines only — skip lines starting with | or >
> ```
>
> Run against this file it returned eight hits, of which **four were real** — a
> stale "three instances" listing a class that had since grown, a "six rows"
> bound to a group that can gain members, a "ten rows" pinned to the `PARTIAL`
> count, and a "two rows" whose own next paragraph says one of them is not a row.
> The other four name specific known rows and do not drift.
>
> **So it is a review prompt, not a gate.** At roughly half precision it would be
> ignored inside a week if it blocked anything, which this file's own artifact
> table says is worse than no check. It earns its place by being cheap to run
> deliberately, and it was verified to fail on a synthetic positive before being
> trusted on a real negative — a check that cannot fail is not a check.

> **Counts in prose were removed from this section on 2026-08-20, having drifted
> twice.** It claimed "twelve checker artifacts" against tables listing seven and
> six, said "four instances" of a table that had grown to six, and referenced
> "artifact eleven" after the numbering was dropped. The section also carried the
> same instance twice, as *a cancelled set* and *a wholly cancelled wave*, added
> months apart in attention if not in time.
>
> This file tells its own readers to recount rather than restate, and the section
> arguing that a checker is never the interesting row had itself gone
> uninspected. Descriptions now stand where numbers were, because a description
> does not drift when a row is added.

**Where these were found matters as much as what they were.** All four came from
checking the *instrument*, not the thing being measured, and in three the
instrument's author caught it only after shipping a wrong conclusion. Every artifact in the two tables
above was found this way, and **not once has the document been the thing that was
wrong on first run.** The companion to "audit the set, not its interesting members"
is that **the checker is never the interesting row.**

**And a sharper form of the same thing, which cost a real conclusion.** One of
these truncations was committed *one turn after* its author wrote the paragraph
warning about truncated sets, using the endpoint that paragraph named. Knowing
the rule did not produce applying it — because the reading was done in passing,
as background for a conclusion being reasoned about carefully.

That is the failure the previous sentence does not cover. "The checker is never
the interesting row" points at tools you set out to write. This points at
readings you do not think of as checks at all:

> **The check you run in passing is the one that isn't checked.** A number quoted
> as background gets none of the scrutiny given to the claim it supports — and it
> is load-bearing anyway, because conclusions get built on it.

In that instance the truncated figure produced a "dispatch has gone quiet"
conclusion and an instruction to investigate it, from a number nobody had treated
as a finding.

**A second instance, five hours later and from a different author, is what makes
this a rule rather than one person's bad afternoon.** A count of failing runs in
the repository was asserted as background — "one genuine failure exists" — from
an un-paginated query. Paginated, it was two failing workflows across four guard
steps. The rule about pagination had by then been established independently by
two lanes, written down, and cited in this file. It still did not survive contact
with a number gathered in passing.

So the failure is not ignorance of the rule and cannot be fixed by restating it.
Both instances share a shape: the author was reasoning carefully about something
else, and the defective reading was scenery for that reasoning rather than its
subject. **Scrutiny follows attention, and attention was elsewhere by
construction** — which is why "be more careful" is not a remedy and "notice that a
figure became evidence" is.

**A third instance is what makes the mechanism testable, because it is the
prediction the mechanism makes.** The same count was corrected twice more: "one
genuine failure exists in the repository" became two, then three. The third
failing run had been there throughout and was the root workflow the other two
chain through.

What matters is the sequence. By the third reading the pagination rule had been
established independently by two lanes, written into this file, cited in a
correction, and personally apologised for by the author who then read the number
un-paginated a fourth time. That eliminates the readings that would let the rule
be about competence: not ignorance, not a first slip after learning, not
carelessness in the ordinary sense.

If scrutiny follows attention, then a rule cannot protect a reading that
attention never lands on, however well the rule is known — and the same author
will reproduce the same defect at the same spot as often as the situation
recurs. That is a prediction, and these three are it being observed rather than
argued. It is also why the remedy has to be structural: the reading must stop
being background, either by being gathered with the same tool that gathers
findings, or by being labelled as unverified where it is quoted. The rule is not to check more; it is to notice that a figure has
become evidence the moment an argument rests on it, whatever it was gathered
for.

### A different mechanism: presentation is not meaning

Most of the artifacts above are **truncation** — a subset presented as the whole,
defeated by widening the query. One is not, and filing it with the others would
prescribe the wrong remedy.

`run_started_at` on a GitHub Actions run is set when the run is **created**, not
when it begins executing. Verified directly on this branch's own runs while both
sat `queued`:

```
Heavy Guards | status=queued | created=05:48:28Z | run_started_at=05:48:28Z
PR Fast      | status=queued | created=05:48:28Z | run_started_at=05:48:28Z
```

A run that has never executed carries a timestamp that reads as having started.
**No amount of pagination reaches this** — the full, untruncated record says the
same thing. The field is not incomplete; it means something other than what its
name asserts.

**The same field family fails in the opposite direction too, and recording only
one direction is worse than recording neither.** Run-level `status` reported
`queued` for both of these runs while their `build` job had already completed
successfully. So one field reads as *falsely started* and another as *falsely
stalled*, on the same two runs, at the same moment.

A reader who internalises only the first direction learns to distrust
`run_started_at` and to trust `status` — which is precisely the wrong lesson,
and worse than distrusting neither.

**Three readings of those two runs were taken within ten minutes and all three
were wrong.** "Never executed", from `run_started_at == created_at`. "Executing
now, 61 jobs dispatched", from a jobs query read as running. The truth needed
`status` *and* `conclusion` per job:

```
1 completed  success  build Gust and CI surface
N queued     -        (everything else)
```

The build job had succeeded and the fan-out was queued behind it, because these
workflows are `needs: build`. **A large queued count beside one success is the
normal shape of that structure, not a stall** — which no single field says.

So the remedy differs. Against truncation: widen the query. Against this:
**corroborate the field against a second, independent one that would have to
agree** — here `run_started_at` against `status`, `status` against the jobs view,
and job `status` against job `conclusion`. Each of those pairs alone still
misleads; it took all three.

The generalisation covering both is narrower than "paginate" and wider than
either:

> **A datum's presentation is not its meaning.** A name, a format, or a position
> in a table is a claim by whoever designed the record, and the check is always a
> second field that would have to agree with it.

**One observation about consequence, which is the useful half.** Reading that
field wrongly was harmless here for a structural reason rather than by luck: no
gate in this repository consumes `run_started_at`. The same misreading of a
*conclusion* field would have merged a PR. **Which readings are load-bearing is
a property of the gates, not of the data** — confirmed a second time here, since
none of the three wrong readings touched this lane's gate, which consumes
`conclusion` and saw `null` throughout — so the audit worth doing is not "is
every field read correctly" but "which fields does a decision actually rest on",
and those are the ones to corroborate.

### A fifth class, recorded at the strength it actually has

An invariant every lane here holds implicitly — *a PR's run set is fixed by its
push* — may not hold on this repository. Three PRs on one lane acquired
`attempt=1` `pull_request` runs whose creation timestamps do not match their last
push. That is the observation, and it is the whole of it.

**No mechanism is confirmed**, and two lanes checked their own PRs for the same
shape and did not find it: both this branch's runs and the verify lane's are
`attempt=1` created inside the same window as their pushes. So the class rests on
three observations from one lane, with a plausible cause — base movement in a
stacked chain re-dispatching downstream PRs — that nobody has demonstrated.

It is recorded at that strength deliberately. **A class that grows by lanes
assuming it applies to them is the drain-trend error in a new costume**: a run of
consistent observations extrapolated into a property. The correction that trimmed
this one arrived before it spread, which is the only reason it is one paragraph
rather than a rule.

**What follows for a gate is real even so, and does not depend on the mechanism.**
"Total stable across spaced samples" is a claim about a set assumed closed. If a
PR can acquire a run after its total has been stable, a gate can pass and then be
wrong — so keep sampling `total` up to the merge call rather than treating an
established denominator as a fixed one. **Established is not fixed**, even when
tonight's evidence says it has not moved. That is the same shape as an
absence-phrased check read as a permanent guarantee rather than a statement about
one moment.

**Assert that a check found what it was looking for, not merely that it ran.**
For an edit, compare the file before and after. For a search, assert a non-zero
match count. A check that cannot fail is not a check.

**And assert that it saw everything, and that everything exists yet.** These are
two different faults that produce the same plausible-looking answer:

- **A complete set reported short.** The pagination case: 100 results, all real,
  mutually consistent, wrong by 19, with nothing in the output indicating it was
  cut off.
- **An incomplete set reported as complete.** A denominator read while the set is
  still being created — 54 items when the true total will be 71. Every item is
  real and the total is simply not final yet.

The second is the more dangerous when computing a ratio, because *both* terms
move and the ratio looks stable while being wrong.

**And an empty set satisfies almost every condition worth checking.** "No
outstanding items", "no failures", "no violations" are all true of nothing. A
parser that mismatches its input and reads zero records reports a clean result
with total confidence — this happened here on a live gate check, where a
malformed read of a CI status returned zero runs, zero outstanding, and a
go signal while four checks were still running. It was caught by asserting the
set size before interpreting it:

```python
assert len(r) > 50, f'IMPLAUSIBLE SET SIZE {len(r)} — refusing to report'
```

That assertion is cheap and it is the difference between a wrong document and a
wrong action. **Any check whose passing condition can be satisfied by an empty
result must assert the result is non-empty first.** A total is only a denominator
once nothing further can join the set; until then, "outstanding" understates.
Where this file quotes a proportion — 44% of the test corpus is negative, 9 of 45
rules hold — the denominator was a directory listing or this file itself, both
closed sets. Any proportion taken from a growing set needs the set closed first. Any count in this file taken from a tool with a default
limit — an API page size, a `head`, a `grep -m` — needs the limit disabled or the
total asserted independently, because a silently truncated count is
indistinguishable from a complete one.

## Maintenance

- **Re-read the block, not the matching line.** Every defect this file has found
  in its own claims came from citing a `grep` hit without reading what surrounds
  it. Corrected in place each time: `typechecker_log_trace`'s 40 call
  sites described as an emitter substrate when they carry only prose;
  `typechecker.gst:1962` described as a formatting check when it is a provenance
  branch; and `#[opaque]` described as needing no prerequisite when field reads
  defeat it. Grep finds the word, not the meaning.
- **Re-verify inherited citations before propagating them.** `path:line` drifts.
  This file carried `compiler/typechecker.gst:4953,5151` for D-1, inherited from
  `docs/STDLIB_SURFACE_FINDINGS.md` (pinned to `6c94728d`); both had moved, and
  the error reached two other documents before anyone read the lines.
  `docs/SHARED_SEMANTIC_ZONE.md` already states the rule — "treat them as a
  starting point and confirm the construct still exists" — and it applies to
  citations copied *between* documents, not only to citations acted on.
- **`docs/VISION.md` §0.18 is derived from this file. Regenerate it when you add
  or renumber an evidence section**, or the two drift into agreeing with each
  other while the compiler has moved — the same failure as the inherited-citation
  defect above.

  The index maps a `docs/VISION.md` section to the evidence blocks that verify
  it, extracted from the `§` references inside each `### E<n>` block here:

  ```
  python3 - <<'EOF'
  import re, pathlib
  led = pathlib.Path('docs/ONE_WAY_LEDGER.md').read_text()
  ev = {}
  for m in re.finditer(r'^### (E\d+|D-1)[^\n]*\n(.*?)(?=^### |\Z)', led, re.S|re.M):
      eid, body = m.group(1), m.group(2)
      # drop cross-document refs before extracting, or you get false hits
      body = re.sub(r'`docs/[A-Z_]+\.md`[^.]{0,40}?§\d+', '', body)
      for s in set(re.findall(r'§(\d+|0\.\d+)', body)):
          if s != '0': ev.setdefault(s, set()).add(eid)
  for s in sorted(ev, key=lambda x: (float(x) if '.' in x else int(x))):
      print(f"§{s}: {', '.join(sorted(ev[s]))}")
  EOF
  ```

  **Assert both sides parsed before believing the result.** "No sections
  missing" is what a comparison of two empty sets reports, and both sides here
  are produced by regexes over documents that change. Re-run 2026-08-20 after
  many ledger edits: 34 sections carried evidence, 35 were indexed, and nothing
  was missing — a clean result worth trusting only because the two counts were
  checked first, and because dropping one indexed section was confirmed to make
  the check fail.

  **Two traps, both of which produced false positives the first time this was
  checked.** A naive comparison reported five missing sections and all five were
  artifacts:

  - **Cross-document `§` references.** `§4` and `§5` appear in E23 and E16 but
    refer to `docs/VISION_RECONCILIATION.md`, not to `docs/VISION.md`. Strip
    them before extracting, as the snippet does.
  - **Range notation.** §0.18 writes `§75–§79` as a range; a per-number regex
    finds 75 and 79 and reports 76, 77 and 78 as missing. Expand ranges before
    comparing, or compare by evidence id rather than by section.

  A checker that is wrong in this direction is worse than none, because it costs
  the next reader the same twenty minutes it cost to write.

- **Measured counts drift too. Re-measure before restating one.** Several rows
  and evidence blocks quote figures — test programs, guard recipes, negative
  fixtures, compiler size. They were correct when taken and are not
  self-updating. The commands, all run from the repository root:

  ```
  find tests -name '*.gst' | wc -l                            # test programs
  ls tests/ | grep -c 'reject'                                # *reject* fixtures
  ls tests/ | grep -cE 'reject|invalid|_fail|error|violation' # negative by name
  just --list | grep -c 'guard-'                              # guard recipes
  just --list | grep -ci 'parity\|differential'               # differential guards
  ls .github/workflows/*.yml | wc -l                          # workflows
  ls compiler/*.gst | wc -l ; cat compiler/*.gst | wc -l      # compiler size
  grep -c 'typechecker_log_trace(' compiler/typechecker.gst   # trace call sites
  ```

  For the `std.*` surface, **read the Summary table of
  `docs/STDLIB_SURFACE_INVENTORY.md` rather than grepping it.** That file is
  generated and states its own counts; a regex over its rows also matches the
  summary row describing them, which inflates the total by one. That mistake was
  made here and produced a phantom 21st runtime symbol against a true count of
  20.

- A row changes status only with a reproduction, per `AGENTS.md`.
- A `VIOLATED` row is removed only when fixed, never because it is inconvenient.
- When a row's rule changes, `docs/VISION.md` changes first and this file follows.
