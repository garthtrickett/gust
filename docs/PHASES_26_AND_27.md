# Phases 26 and 27 — systems safety, implicit context, and consolidation

This is the canonical plan for Phase 26 — gated raw pointers and FFI, generalized
linear resources, and implicit context — and Phase 27, the consolidation that
follows it. It combines the former `PHASES_5_AND_6.md` plan with the ordering,
status, and placement rationale formerly held in `UNSAFE_FFI_SEQUENCE.md`.

`STEP51_DEFERRED_UNSAFE_SEMANTICS.md` and
`STEP52_RESOURCE_SEMANTICS.md` remain the detailed design checkpoints for parts
of this work. `docs/VISION.md` remains authoritative for language rationale and
decisions; this document owns execution order and patch planning.

> **Legacy identifiers:** before 2026-09-03 this roadmap was numbered Phases 5
> and 6. Existing filenames, guard targets, fixtures, comments, and historical
> labels such as `STEP51_*`, `STEP52_*`, `guard_step51_*`, `guard_step52_*`, and
> "Step 5.2Q" keep their names. They are stable implementation and historical
> identifiers, not current roadmap numbering. New human-facing planning uses
> Phase 26.1, 26.2, 26.3, 26.4, and Phase 27.

**Placement:** the operator directed on 2026-08-20 that this work occur after
the Cranelift migration completes and C is deprecated. Renumbering it after the
existing roadmap tail makes that order explicit: Phase 26 begins only after
Phase 25 closes, apart from the already-built foundations recorded below.

---

## Execution order

These are dependency gates, not a second roadmap numbering system. The final
column identifies the Phase 26 destination for each gate.

| Gate | Work | State at the 2026-08-20 audit | Roadmap destination |
| --- | --- | --- | --- |
| 0 | Complete the Cranelift transition and C-retirement tail | prerequisite | Phases 20–25 |
| 1 | Safe-constructor coverage and unknown-origin rejection | done | Phase 26.1 |
| 2 | Broader address-origin metadata | done | Phase 26.1 |
| 3 | Raw- and isolated-arena-derived provenance propagation | done | Phase 26.1 |
| 4 | Rich FFI and native-call boundary modelling | pending | Phase 26.1 |
| 5 | `#[repr(C)]`, `#[packed]`, and ABI layout enforcement | pending | Phase 26.1 |
| 6 | Isolated FFI allocation arenas | pending | Phase 26.1 |
| 7 | Generalized linear-resource enforcement | partial | Phase 26.2 |
| 8 | Implicit-context desugaring | pending | Phase 26.3 |

Gate 0 is stronger than sequencing convenience. C transpilation is a poor fit
for Gust's semantics precisely where this work lives: layout, aliasing, pointer
operations, cleanup, and ABI. A direct backend gives Gust authoritative control
over those concerns while type checking, ownership, provenance, and safety
validation remain outside the backend.

Gates 1–3 establish which operations create valid safe origins, attach one of
the nine origin categories — `safe`, `local_stack`, `arena`, `scratchpad`,
`ffi`, `sandbox`, `raw_unknown`, `borrowed_field`, and `container_element` — and
preserve provenance through expressions, assignments, arguments, returns,
fields, containers, casts, and selected stdlib helpers. Strict rejection becomes
checkable only after those facts survive every intermediate representation.

The completion gate between executable increments is: focused positive and
negative tests, isolated execution, the full compiler suite, Cranelift-native
bootstrap, normalized-IR or semantic fixed-point convergence, stable and
specific diagnostics, and a coherent bisectable commit before the next
increment starts.

### Why this order is required

- Provenance cannot be enforced strictly until safe origins are recognized
  (gates 1–3).
- An FFI boundary contract cannot classify a return until origins are meaningful
  (gates 2–4).
- Layout enforcement matters at a boundary whose ownership and escape policies
  are already defined (gates 4–5).
- Isolated arenas depend on the boundary and layout model they isolate
  (gates 4–6).
- Linear resources must not trust handles until provenance and non-laundering
  are established (gates 1–7).
- Implicit context comes last because contexts adjacent to unsafe, FFI, or
  resource authority must remain explicit (gates 4–8).

---

## Phase 26.1 — gated raw pointers, unsafe blocks, and FFI

The staging is the interesting part, and it generalizes beyond this phase.

**A — additive grammar and no-op parsing.** Parse `unsafe`, `unsafe {}` blocks,
and `unsafe func` signatures. Initially typecheck them as identity scopes with
zero enforcement. Stage 0 compiles the parser change; Stage 1 parses `unsafe`
natively and enforces nothing.

**B — proactive codebase wrapping.** Audit `compiler/*.gst` and the core
collections, and wrap every raw dereference, pointer arithmetic operation, raw
cast, and FFI call in `unsafe {}`. Because the active compiler treats those
blocks as identity scopes, the codebase keeps compiling and converging while the
migration completes.

**C — basic unsafe enforcement.** Reject raw dereference, pointer arithmetic,
raw casts, and calls to `unsafe func` outside an explicit unsafe context. Keep
local raw-pointer escape diagnostics stable. This is the first enforcement gate,
not proof of the later FFI, address-escape, or non-laundering contracts.

**D — FFI, layout, and isolated-arena policy.** Give every external parameter
and return position an explicit ownership and escape policy: which types may
cross; what native code may mutate; whether pointers are borrowed, transferred,
retained, or returned; which provenance a return receives; callback ownership
and lifetime; native error representation; and what must be copied rather than
borrowed. The distinction between a borrowed buffer and an owned returned
pointer must exist semantically even if syntax settles later.

Add `#[repr(C)]`, `#[packed]`, and explicit enum integer representation through
one authoritative layout engine shared by type checking, FFI validation,
Cranelift lowering, diagnostics, and compiler metadata. Ordinary Gust structs
are not assumed C-compatible. Packed field access requires explicit handling or
`unsafe`, never a silent aligned load. `#[packed]` remains specialized for
external formats, hardware interfaces, and legacy native APIs.

Use a transient isolated arena for memory handed to native code and destroy it
on return. *Isolated* is deliberately narrower than *sandboxed*: this bounds
memory lifetime and spread but cannot prevent native code from accessing process
memory, globals, syscalls, or retained external pointers. Real isolation
requires a process, hardware boundary, or WebAssembly.

**E — address-escape enforcement.** Track raw-address and reference escape
through assignments, returns, calls, and aggregates. Reject an unsafe-derived
address when it crosses into a safe lifetime or authority boundary that cannot
prove its origin.

**F — provenance and non-laundering.** Establish every operation that creates a
valid safe origin, carry the nine origin categories listed above, and preserve
that provenance through variables, fields, calls, containers, casts, and
returns. An unsafe block or function may not return or store a safe branded
`Index[T, ctx]` or `&T[ctx]` whose address came from a raw pointer, isolated
arena, external call, or manual allocation. Safe branded values are born only
through compiler-verified construction or explicit future validation/copy APIs.
The origin metadata, propagation, safe-constructor coverage, and unknown-origin
rejection foundations were verified live on 2026-08-20.

> **The A→B→C pattern is the self-hosted gating technique.** Add syntax as a
> no-op, migrate the codebase under that no-op, establish the semantic facts the
> rule needs, and only then enable the first rejection gate. Enforcing first
> cannot work when the compiler being migrated is also the compiler enforcing
> the new rule.

**Raw null inside safe boundaries** belongs here rather than with absence.
Restricting it is a gated-raw-pointer obligation — it is about what a pointer may
be, not about how absence is spelled — so it travels with 26.1's staging rather
than with Phase 26.4. It was previously written as the third clause of 27.2,
which conflated the two.

## Phase 26.2 — generalized linear-resource enforcement

**A — metadata opt-in and isolation.** The linear engine runs only on structs
annotated `#[linear]` or carrying a registered `drop_func`. Unannotated types,
primitives, and compiler-internal collections bypass the escape analyzer. This
prevents conservative analysis from turning ordinary compiler values such as
`Type`, `Statement`, or `Expression` into a self-hosting failure.

**B — infrastructure.** Replace the hardcoded `open_directories` map on
`TypeEnvironment` with an `open_linear_resources` registry, and introduce
`Resource[ctx, T]` for OS and hardware handles. An owned `Resource` cannot sit
untracked on the stack and must be bound to a registered destructor.

**C — linearity and index aliasing.** If `T` is linear, `Index[T, ctx]` inherits
linearity: no duplication or implicit copy, and transfer only by explicit move
or through its `drop_func`. `ctx.Free()` or a move of `ctx`, including
`std.GenerationalSwap`, is a compile-time leak error while a resource branded by
that allocator remains open.

**D — escape analysis and `defer` validation.** A linear handle must be returned
to transfer ownership, released by its `drop_func` on normal flow, or released
in a validated `defer`. Otherwise the compiler emits `LinearResourceLeak`.

## Phase 26.3 — implicit context

**Decided 2026-08-20: both spellings ship.** A block form and a function form:

```gust
with ctx {
    mut v := std.VectorNew();
    mut s := std.Clone(name);
}

func parse_type(parser: *Parser[ctx]) ast.Type[ctx] using ctx {
    mut fields := std.VectorNew();
    return std.Clone(type_name);
}
```

Both lower to today's explicit form before any semantic pass runs. The function
form desugars to the block form wrapped around the whole function body. It is one
mechanism with two placements; if the function form ever gains behavior the
block form cannot express, the pair must collapse.

The rules are:

1. Existing explicit `ctx` code keeps working forever.
2. Lower implicit `ctx` before typechecking and code-generation safety passes.
3. Only allowlisted arena-backed stdlib functions receive implicit context.
4. No implicit `ctx` inside `unsafe` blocks.
5. No implicit `ctx` in FFI, isolated-arena, or raw-pointer APIs.
6. No implicit `ctx` for `Resource[ctx, T]` creation, drop, or move.
7. Ambiguity is an error, not inference.
8. Do not mass-migrate compiler-core code.

**Staging:** A parses `with ctx` into the AST without lowering; B lowers
allowlisted zero-`ctx` calls inside `with ctx`; C adds function-level `using ctx`
as a desugaring; D proves no implicit context is accepted in unsafe, resource,
or FFI contexts; E permits the syntax in new helpers, tests, and application
code without mass-migrating compiler core.

Rules 4–6 preserve `docs/VISION.md` §24.1's reason this remains ergonomic rather
than authoritative: an arena is a destination, not a permission. When a context
is adjacent to authority, it is written explicitly. Rule 7 applies the same
principle to shadowing: prefer a diagnostic to clever inference.

---

## Phase 26.4 — one spelling of absence

Closes `docs/ONE_WAY_LEDGER.md` rule 45, **VIOLATED** — `empty[T]` competes with
`Option[T]` as a second spelling of absence. Moved out of Phase 27 because it is
a correctness obligation with a named ledger owner, and filing it under "delete
the old ways" priced it as cleanup.

| Step | Work |
| --- | --- |
| 26.4a | Migrate `map.Get`/`LookupResult_T` to `map.get_opt`/`Option[T]` file by file, bootstrapping after each rather than as one pass |
| 26.4b | Remove `empty[T]` sentinel parsing and synthesized `LookupResult_T` |

**These two are one row, not two, and cannot be separated.** You cannot remove
the synthesized `LookupResult_T` while callers still use it, so a gating removal
paired with an optional migration would be a gate that can never close. Rule 45's
violation is *"a second sentinel alongside `Option[T]`"* — deleting one spelling
while call sites still use the other does not discharge it.

The file-by-file bootstrap rule follows the same discipline as 26.1's A→B→C
staging: never change the compiler's own idiom in one pass. A failure here is not
merely a test failure; it can leave the compiler unable to rebuild itself.

**Exit gate:** `map.Get`/`LookupResult_T` and `empty[T]` sentinel parsing are
gone, `Option[T]` is the only spelling of absence, rule 45 reads `HOLDS` with a
reproduction, and bootstrap converges after each file rather than once at the
end.

---

## Phase 27 — consolidation

| Step | Work |
| --- | --- |
| 27.3 | Delete `open_directories` from `TypeEnvironment`; directories become `Resource[ctx, Directory]` |
| 27.4 | Delete split LHS/RHS subscript codegen branches: subscripts are read-only copies and mutation uses explicit references; keep parser LHS validation robust |
| 27.5 | Audit the stdlib safety surface so raw-pointer work does not leak through `std.Vector`, `std.HashMap`, or `std.String` |
| 27.6 | Refactor `Statement` and `Expression` into true sum-type enums, migrate tag tests to `match`, and promote the consolidated result as the next bootstrap seed |

---

## Detailed design anchors

| Work | Design recorded in |
| --- | --- |
| FFI/native-call metadata and policy | `STEP51_DEFERRED_UNSAFE_SEMANTICS.md` |
| Layout-aware FFI validation | `STEP51_DEFERRED_UNSAFE_SEMANTICS.md` |
| Isolated FFI arena checkpoint | `STEP51_DEFERRED_UNSAFE_SEMANTICS.md` under its legacy “sandboxed” name |
| Address-origin metadata and non-laundering | `STEP51_DEFERRED_UNSAFE_SEMANTICS.md` |
| Linear-resource semantics | `STEP52_RESOURCE_SEMANTICS.md` and `TASK_STDLIB.md` CR-5 |
| Implicit context | `docs/VISION.md` §24.1 and Phase 26.3 above |

## Scheduling consequence for the demo

Implicit context was once listed as row 4 of `docs/DEMO_TARGET_PROGRAM.md`. The
placement directive means it cannot be a demo prerequisite: Phase 26.3 arrives
after the C-retirement tail, so the demo must thread contexts explicitly.

That is semantically harmless but ergonomically measurable. OD-9 evaluates
whether a model can write Gust well against the surface it actually sees; until
Phase 26.3, that surface carries explicit context parameters on allocating
functions. The demo should measure that cost rather than assume it is harmless.
The older Phase 19 brand-resolution dependency is moot by Phase 26.

## Status snapshot from 2026-08-20

This table preserves the original live audit; it is evidence about foundations,
not current completion authority for Phases 26 or 27.

| Item | Evidence | State |
| --- | --- | --- |
| 26.1B — codebase wrapped in `unsafe` | `unsafe {` in `typechecker.gst` ×155, `mir.gst` ×49, `parser.gst` ×45, `codegen.gst` ×39, and about 130 further files | done or nearly done |
| 26.1F — origin and provenance foundations | `AddressOriginMetadata`, `ExpressionProvenance`, `variable_origins`, and `return_origins` were live | exists |
| 26.2B — generalized registry | `open_linear_resources` ×32 in `typechecker.gst` | exists |
| 26.2A — `#[linear]` opt-in | parsed in `parser.gst`, carried as `is_linear_resource`, and registered through linear metadata | exists |
| 26.2D — cleanup validation | invoked on two paths in the self-hosted compiler | partly live (`STEP52` items Q/R) |
| 26.2 — destructor declaration | one built-in destructor and no source syntax to declare another | missing at the snapshot (`TASK_STDLIB.md` CR-5) |
| 26.4a — `Option` migration | `get_opt` present in compiler modules while `LookupResult` remained in `typechecker.gst` | partly migrated |
| 26.4b — `empty[T]` removal | 130 uses in `typechecker.gst` alone | not started |
| 27.3 — purge `open_directories` | still present with a `legacy_freeze` test entry | frozen, not purged |

Phase 26.4 closes the `docs/ONE_WAY_LEDGER.md` violation where `empty[T]`
competes with `Option[T]` as a second spelling of absence. Phase 27.3 closes the
remaining `open_directories` migration item in
`STEP52_RESOURCE_SEMANTICS.md`.

Phase 26.4's file-by-file bootstrap rule follows the same discipline as Phase
26.1's A→B→C sequence: never change the compiler's own idiom in one pass. A
failure here is not merely a test failure; it can leave the compiler unable to
build itself.
