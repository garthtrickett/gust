# Containment Work That Does Not Wait on the Platform

`docs/ONE_WAY_LEDGER.md` records 45 design rules, of which 10 hold. Most of the
rest are absent because the platform they describe is unbuilt, and correctly
deferred.

**Two are not.** Both are containment properties `docs/VISION.md` states as
product claims, both are reachable without the platform — no effects, no
database, no job runner, no backend work — and neither is scheduled by any
roadmap. One of the two carries a frontend prerequisite, stated in full under
proposal 1 rather than glossed here. This document exists so they stop
being footnotes in an evidence section.

It proposes; it does not decide. Each entry names what exists, the smallest
change, and the ownership question it raises.

**Written 2026-08-20 against `b47d0049`.** Every claim about the compiler has a
citation; none of it was built or benchmarked.

> **Re-verified 2026-08-20 08:33 UTC against `0b96ddff`, and every citation still resolves.**
> Checked mechanically rather than by re-reading: each cited range was opened and
> searched for the construct it was cited for, and the construct's true line
> numbers were listed alongside. All eleven hold — `AddressOriginMetadata` and the
> nine origin categories at `compiler/typechecker.gst:5-24`, the `std.Format`
> validation at `:3810`, `return_origins` at `:637` and `variable_origins` at
> `:748`, `env_register_struct_linear_metadata` at `:6801`, the attribute chain at
> `compiler/parser.gst:869-872`, `is_linear_resource` at `compiler/ast.gst:77`,
> `serialize_type` at `:247`, `CompilerError` at `compiler/errors.gst:10`, and
> `Span` at `compiler/token.gst:60`.
>
> The two load-bearing negatives hold too: **there is still no JSON writer
> anywhere in `compiler/`**, so proposal 2's only genuinely new code is still new;
> and `typechecker_log_trace` still has exactly **40 callers**, so the correction
> about those call sites not being a substrate still stands.
>
> **Why this check is worth its cost.** A proposal document pinned to a commit
> invites a reader to discount it without checking, and "written against an old
> HEAD" is indistinguishable from "stale" at a glance. It was not stale: `main`
> moved from `b47d0049` to `0b96ddff` and none of the cited structure moved with it.
> The citations most likely to rot are the ones inside a lane's active phase, and
> none of these are. Re-run this check before scheduling either proposal, not
> before reading them.

---

## Why these two and not the other thirty-five

The test is `docs/VISION.md` §0.12, which names three artifacts humans actually
read, and asks which could exist before the platform does:

| Artifact | Needs | Available today |
| --- | --- | --- |
| Capability manifest | effects (§17) | **No** — no `uses` keyword (E10) |
| Lockfile diff | packages, manifests (§70, §72) | **No** — no package concept (row 38) |
| Execution trace | regions, typed errors | **Yes** — both exist |

And separately, §81's secrets claim splits into two mechanisms of which one
already ships:

| Half of §81 | Needs | Available today |
| --- | --- | --- |
| `secret.use<"stripe">` | effects | **No** |
| "no readable string representation" | a type-system property | **Partly** — the formatter already rejects struct arguments, so the remaining leak is a `str` extracted from a secret. Closing it needs propagation, not an attribute. See proposal 1. |

That is the whole selection criterion. Everything else in the ledger marked
`ABSENT` waits on a database, an HTTP server, a job runner, or an effect system.

---

## Proposal 1 — type opacity (§81's other half)

**The claim.** §81: "Secrets are opaque linear values. They have no readable
string representation in safe code. Secrets cannot be logged, serialized,
formatted, returned to clients, or compared except through approved operations."

Its rationale is one of the strongest containment arguments in the document:

> an agent cannot leak a secret into a log line or an error message, because the
> type does not permit it. Among the most frequent mistakes in generated code and
> among the most expensive.

**What exists.** The *linear* half is done — `#[linear]` is parsed as a layout
attribute (`compiler/parser.gst:869-872`), carried on `StructDecl`
(`compiler/ast.gst:77`), and registered via `env_register_struct_linear_metadata`
(`compiler/typechecker.gst:6801`). `#[repr(C)]` and `#[packed]` use the same
path, so the attribute mechanism is established and has three users.

**What is missing — restated 2026-08-20 after reading the formatter.** An
earlier version of this proposal said `std.Format` "accepts whatever it is
given". That is false, and it changes the design.

`std.Format` is strongly typed (`compiler/typechecker.gst:3810-3923`). It
requires a string *literal* format, parses the `%` specifiers out of it, builds
an expected-type vector, checks the argument count against it, and then checks
each argument:

- `%s` requires exactly `Str` (tag 5) — "std.Format argument %d expected Str,
  but got %s";
- `%d` and `%r` require `Int`, `Byte`, `Bool`, or `Index` (tags 0, 1, 2, 7).

**A struct cannot be passed to `std.Format` at all.** There is no specifier for
one, and tag 8 satisfies neither branch. So:

```gust
std.Format("%s", secret)        // already a compile error today
std.Format("%s", secret.value)  // compiles — and this is the whole leak
```

That removes most of the value from an `#[opaque]` attribute on a struct. The
thing the attribute would forbid is already forbidden by the formatter's type
check. What is unrestricted is extracting a `str` out of the struct and
formatting *that*, and an attribute on the type does not reach it — a point the
previous revision recorded as a prerequisite when it is in fact the entire
feature.

**Consequence: the mechanism should probably not be an attribute at all.**

Blocking a leak requires that a `str` *derived from* an opaque value stay opaque
through the field read. That is propagation, not a predicate on a declaration —
and the compiler already has propagation machinery. `ExpressionProvenance`
carries an `AddressOriginMetadata` through expressions, and nine origin
categories are live and maintained (`compiler/typechecker.gst:5-24`, and
proposal 2 below). An `opaque` origin that propagates through field access, with
one check at the formatter, is closer to how the compiler already thinks than a
layout attribute is.

That is a larger and less certain change than what follows, and it is not this
document's call to make. Both shapes are kept below: the attribute, which is
small and mostly redundant, and the provenance route, which is the one that would
actually close the hole.

**Shape A — the attribute.** Small, and now known to add little on its own, since
the formatter already rejects struct arguments. A fourth layout attribute
alongside the existing three:

1. **Parse** — one more arm in the attribute chain at
   `compiler/parser.gst:869-872`, identical in shape to `linear`.
2. **Carry** — one field on `StructDecl`, mirroring `is_linear_resource`.
3. **Register** — one map on `TypeEnvironment`, mirroring `struct_linear_resource`
   (`compiler/typechecker.gst:737`).
4. **Reject** — at `compiler/typechecker.gst:3810`, which validates `std.Format`
   arguments and is the natural hook.

Message shaped like S1.1's, byte-identical across both typecheckers, with a guard
mirroring `guard-stdlib-s1-str-equality-diagnostic`.

> **Correction to an earlier draft of this document.** It cited
> `compiler/typechecker.gst:1962-1963` as a second formatting dispatch site and
> claimed "one check there covers the formatting surface". Re-read: `:1962` is
> not a formatting check at all. It is a provenance branch that groups
> `std_Format`, `std_FormatInt`, `std_Concat`, and `os_ScratchAlloc` together to
> compute an origin set (`mut s := set_init(ctx)`). Only `:3810` validates
> `std.Format` arguments. The hook is one site, not two, and the earlier sentence
> overstated how centralised the surface is.

**Shape B — an opaque provenance origin.** Reuses the machinery proposal 2
describes rather than adding a parallel one: mark the origin at the declaration,
propagate it through field reads and assignments as the existing origin
categories already propagate, and check it where the formatter checks types
(`:3908-3917`). It closes the actual leak. It is also a semantic change to
provenance, which is squarely shared-zone work, so it needs the same ownership
ruling CR-10 asks for — and probably a firmer one.

### The prerequisite this proposal originally missed

`#[opaque]` on a struct stops `std.Format(secret)`. It does **not** stop
`std.Format(secret.value)`.

Attributes attach to type declarations, so a realistic secret is a struct
wrapping bytes — `#[opaque] struct Secret { value: str }`. There are no
visibility modifiers in the language (row 35: `pub`, `private`, `public`,
`internal`, and `export` are all absent from both lexers), so every field of
every struct is readable everywhere. An agent that cannot write
`std.Format(secret)` can write `std.Format(secret.value)` and the guarantee is
gone.

So this proposal is **not** unblocked in the way the summary table above claims.
It has one prerequisite, and it is a language-surface one:

| Needs | State |
| --- | --- |
| an attribute mechanism | exists — three users |
| a rejection at the `std.Format` hook | one site, straightforward |
| **field-level privacy, or opacity that propagates to field reads** | **absent (row 35)** |

Two ways to close it, and choosing between them is a design decision for the
owning lane rather than something this document should assume:

- **Propagate opacity through field access.** Reading a field of an `#[opaque]`
  type yields a value that is itself opaque. No visibility system required, and
  it keeps the change inside the same attribute. It is also strictly narrower
  than §73's four visibility levels, so it does not pre-empt that design.
- **Implement §73's visibility levels** and make the field private. Larger, and
  it is a separate absent rule with its own row.

The first is the smaller change and is the one this document would propose if
asked, but it is genuinely a decision.

**What this does to the proposal's status.** It remains far less blocked than
anything needing effects, a database, or a backend — everything it needs is in
the frontend and none of it is platform. But "expressible against the compiler
exactly as it stands" was too strong, and the summary table at the top of this
document is corrected accordingly.

**What it does not do.** It does not implement secrets. It does not stop a value
being written to a file, sent over a channel, or read byte-wise — those need
effects and row 33's channel-transfer semantics. It closes exactly one hole: a
value whose type says "not printable" cannot reach a formatting call.

That hole is worth closing on its own terms, because §81 identifies logging a
secret as among the most frequent and most expensive mistakes in generated code,
and this is the half of the defence that does not wait on Part V.

**Ownership question — raised formally as `TASK_STDLIB.md` CR-10.**

The carve-out in `docs/SHARED_SEMANTIC_ZONE.md` covers "a diagnostic that
**rejects** a program the compiler currently miscompiles, provided no accepted
program changes meaning". This proposal satisfies the second clause and not the
first: no existing type carries the attribute, so nothing accepted changes
meaning — but the programs it would reject are not miscompiled today, they are
correct.

So it is neither clearly in nor clearly out, and CR-10 states both readings in
the seven-point format rather than assuming one. The recommendation there,
weakly held, is to treat it as in-zone for the *decision* and out-of-zone for the
*work*, following how CR-1 was handled: the owner rules on whether the attribute
exists and what it is called, and implementation then proceeds as ordinary
Stdlib-lane work under that ruling.

It touches no MIR, no ABI, no layout computation, and no runtime symbol; the
attribute is consumed entirely in the frontend, so codegen never sees it.

---

## Proposal 2 — a provenance trace (§108's expressible subset)

**The claim.** §108 wants every run to emit a structured, versioned,
machine-readable trace, and calls it one of the three things humans actually
read. Most of its contents need the platform: capability sets, exercised effects,
denied authority, query predicates.

**Two of its bullets do not.** §108 asks a trace to record "allocation and
context lifetimes at region granularity" and "typed error values with propagation
path". Regions and typed errors both exist.

**What exists — more than the section assumes.** The compiler already computes a
provenance record per expression and per variable:

```gust
// compiler/typechecker.gst:5-24
type OriginSet[ctx] struct { map: std.HashMap[str, int, ctx] }

type AddressOriginMetadata struct {
    is_safe_arena: int,
    is_raw_derived: int,
    is_sandbox_derived: int,
    is_unknown: int
}

type ExpressionProvenance[ctx] struct {
    resolved_type: ast.Type[ctx],
    address_origin: AddressOriginMetadata,
    legacy_origins: Index[OriginSet[ctx], ctx]
}
```

All nine origin categories from `compiler-plan.md` are live and in use: `safe`,
`local_stack`, `arena`, `scratchpad`, `ffi`, `sandbox`, `raw_unknown`,
`borrowed_field`, `container_element`. `TypeEnvironment` carries
`variable_origins`, `return_origins`, and
`current_function_return_origins` (`compiler/typechecker.gst:637,748,757`).

This is *stronger* than what §108's two bullets ask for. It is not merely region
lifetime; it is where every address came from, classified.

**The 40 trace call sites are not a substrate — correcting an earlier draft of
this document.** `typechecker_log_trace` has an empty body and 40 callers, but
its signature is `(emoji: str, message: str, ctx: &Arena)` and every caller
passes prose:

```gust
typechecker_log_trace("🗄️", "scope_new: spawned root scope", ctx);
typechecker_log_trace('🔍', 'substitute_generics Index: before reading brand', ctx);
```

They mark *where* the compiler does something interesting, which is useful for
choosing emission points, but they carry no data. Reusing them means changing 40
signatures. Treat them as a map, not as plumbing.

### What is actually available to build on

Everything the schema below needs already exists as a compiler value:

| Need | Available | Where |
| --- | --- | --- |
| type rendering | `ast.serialize_type(t, ctx) -> str` | `compiler/ast.gst:247` |
| source location | `token.Span { start, end }` over `Position { line, column, offset }` | `compiler/token.gst:54-63` |
| origin classification | `AddressOriginMetadata`, nine `OriginSet` categories | `compiler/typechecker.gst:5-24` |
| per-variable provenance | `variable_origins`, `return_origins` | `compiler/typechecker.gst:748,637` |
| error type and site | `CompilerError { kind, message, span, file_path }` | `compiler/errors.gst:10-15` |

There is **no JSON writer anywhere in `compiler/*.gst`**, so emission is the one
genuinely new piece of code. It is small — the values above are strings, ints,
and enums — but it should be written once as a shared helper rather than
open-coded per record type.

### The schema

Versioned from the first commit, because §108 requires a versioned schema and
because the moment a guard consumes this it becomes an interface (row 40).

```json
{
  "schema": "gust.trace/1",
  "unit": "compiler/typechecker.gst",
  "functions": [
    {
      "name": "env_register_struct_linear_metadata",
      "span": {"start": {"line": 6801, "column": 1, "offset": 0},
               "end":   {"line": 6807, "column": 2, "offset": 0}},
      "bindings": [
        {
          "name": "msg",
          "type": "Str",
          "brand": null,
          "origin": {"category": "arena",
                     "is_safe_arena": true,  "is_raw_derived": false,
                     "is_sandbox_derived": false, "is_unknown": false},
          "span": {"start": {"line": 6805, "column": 9, "offset": 0},
                   "end":   {"line": 6805, "column": 12, "offset": 0}}
        }
      ],
      "returns": {"type": "Void", "origin": null},
      "errors": []
    }
  ]
}
```

Three properties matter more than the exact field names:

1. **`origin.category` is drawn from the nine live categories** — `safe`,
   `local_stack`, `arena`, `scratchpad`, `ffi`, `sandbox`, `raw_unknown`,
   `borrowed_field`, `container_element` — not invented for the trace. The
   compiler already computes them, so the schema reports rather than derives.
2. **`brand` is nullable and is the honest field.** Phase 19 closed D-1 and
   removed identifier spelling as brand authority. A trace must therefore emit
   the compiler's canonical type-carried brand, not reconstruct one from source
   names. CR-11/#158 and CR-12/#159 still limit exact matching at two boundaries;
   the trace must expose those values faithfully rather than claiming the wider
   cross-context rule already holds.
3. **`schema` is a version string, not a hash.** Consumers pin the major; the
   emitter may add fields within it.

### Scope of a first patch

- Emit for one unit, behind a flag, defaulting off.
- `bindings` and `returns` only. **Not** `errors` — §108's "propagation path"
  needs `?`-style propagation to have a path to describe, and neither `Result`
  nor `?` exists (E2). Emitting an always-empty `errors` array is honest; a
  fabricated one is not.
- One guard asserting the emitted document parses and its `schema` field matches
  the expected major.

That is the whole of it: read values the compiler already holds, render them
through `serialize_type` and `Span`, write JSON, version the top.

### The JSON writer, specified

The only new code. Written out here so the owning lane implements rather than
designs. Signatures follow the conventions already in `compiler/*.gst` — explicit
`ctx: &Arena` last, `str` returns built with `std.Concat`.

```gust
// Escapes per RFC 8259: " \ and the C0 controls. Gust str is byte-based
// (VISION §33), so emit bytes >= 0x80 unchanged rather than \u-escaping —
// the input is already UTF-8 source text.
func json_escape(s: str, ctx: &Arena) str

// Primitives. json_int covers line/column/offset; json_bool covers the four
// AddressOriginMetadata fields.
func json_str(s: str, ctx: &Arena) str
func json_int(v: int, ctx: &Arena) str
func json_bool(v: int, ctx: &Arena) str
func json_null(ctx: &Arena) str

// Composition. Callers assemble members and elements as already-encoded
// fragments, which keeps the writer free of any schema knowledge.
func json_member(key: str, encoded_value: str, ctx: &Arena) str
func json_object(members: std.Vector[str, ctx], ctx: &Arena) str
func json_array(elements: std.Vector[str, ctx], ctx: &Arena) str
```

Seven functions, no state, no dependency beyond `std.Concat` and
`std.Vector`. Deliberately schema-agnostic: it knows nothing about traces, so it
is reusable by anything else that later needs machine-readable output — which
row 40 says is currently nothing at all.

**Ownership.** `compiler/*.gst` is the Cranelift lane's under `AGENTS.md`, and
adding a writer is a dual-compiler change requiring a seed regeneration. It is
therefore **not** Stdlib-lane work and not documentation-lane work, whatever its
size. It needs scheduling by the owning lane, and this specification exists so
that scheduling it costs a reading rather than a design.

**Test shape.** `json_escape` over the five escapes and a control byte;
`json_object` over empty, one member, and nested; one round-trip asserting the
emitted document parses. None of it needs the trace to exist.

**Why this is worth more than its size.** `docs/VISION.md` §0.5 layer 4 and
`docs/VISION_RECONCILIATION.md` §4 both argue the machine interface is the moat —
that syntax is cheap for a model to learn and structured compiler understanding
is not. Nothing in that layer exists today (rows 40, 42). This would be the first
piece, it would be built from analysis the compiler already performs, and it
would give `docs/DEMO_TARGET_PROGRAM.md` something to show that is not a
rejection message.

**Ownership question.** Emitting a new artifact from existing analysis changes no
program's meaning and adds no semantics. But it is compiler output, and if the
record is ever consumed by a guard it becomes an interface. **Treat the schema as
the durable part and version it from the first commit.**

---

## Scope discipline

Both proposals are bounded by the same rule `docs/VISION.md` §0.7 Track A0 sets:
work that makes something newly *writable* or newly *inspectable* using
mechanisms that already exist, never work that adds expressive power.

Explicitly out of scope for both:

- effects, `uses` clauses, or any capability surface — that is Track A;
- a `Secret` type, key storage, or rotation — that is Part XV;
- run-time tracing of a *program*'s execution, as opposed to compile-time facts;
- anything touching MIR, ABI, layout, or the runtime symbol surface.

If either proposal starts to need one of those, it has left this document and
belongs in the owning lane's roadmap under the stop-and-report protocol.
