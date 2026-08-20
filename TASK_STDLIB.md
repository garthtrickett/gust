# Stdlib Phase S1 — Safe Standard-Library Surface

**Lane:** Stdlib. Branch prefix `codex/stdlib-`.

Workflow, Monitoring, Merge, Phase Completion, Runner, and Git Authorization
policies are defined once in `AGENTS.md` and apply to both lanes. Ownership
boundaries and the shared coordination zone are defined in `AGENTS.md` and
`docs/SHARED_SEMANTIC_ZONE.md`. This document defines only what is specific to
Phase S1.

The parallel Cranelift lane is described by `TASK.md`. Phase S1 does not own,
schedule, or validate any work in that roadmap.

Phase numbering is deliberately `S`-prefixed. Cranelift phases are numbered
`14`–`18` and their guards are named `guard-cranelift-phase<N>-*`. Stdlib guards
are named `guard-stdlib-s1-*` so no guard, workflow, script, or registry key can
be mistaken for the other lane's.

## Roadmap Activation

Phase S1 implementation begins only after an explicit operator request to start
Phase S1. Once activated, the Phase Completion Loop in `AGENTS.md` authorizes
autonomous work through Patch S1.12, subject to the patch boundaries, validation
requirements, and stop conditions in this document.

Activating Phase S1 does not activate the Cranelift lane, and vice versa.

## Parallelism Warning — read before activating

Phase S1 was scoped after checking its premises against the compiler
(`docs/STDLIB_SURFACE_FINDINGS.md`, verified 2026-08-19). Five of the thirteen patches are
unblocked today. The rest depend on coordination requests that only the
Cranelift lane can land.

| Unblocked now (5) | Blocked (7) | Depends on the rest (1) |
| --- | --- | --- |
| S1.0, S1.1, S1.2, S1.3, S1.7 | S1.4, S1.5, S1.6 — CR-2 · S1.8, S1.9, S1.10, S1.11 — CR-5 | S1.12 closure |

Activating both lanes on day one therefore does **not** produce two independent
streams of work. It produces roughly one PR-week of stdlib work followed by a
block. Either sequence CR-2 into the Cranelift roadmap first, or accept that the
Stdlib lane idles after S1.3.

This is a scheduling fact, not an objection to the two-lane model.

## Status

- [x] Patch S1.0 — Opening Inventory and Stdlib Surface Baseline — DONE
- [x] Patch S1.1 — `str` Equality Diagnostic — DONE
- [x] Patch S1.2 — String Surface Regression Suite — DONE
- [x] Patch S1.3 — HashMap Methods Through References — DONE
- [ ] Patch S1.4 — Branded Collection Type Consistency
- [ ] Patch S1.5 — Clone Arena Destination Normalization
- [ ] Patch S1.6 — Stdlib Composition Regression Program
- [x] Patch S1.7 — MutexGuard Prerequisite Audit — DONE
- [ ] Patch S1.8 — MutexGuard Prototype
- [ ] Patch S1.9 — MutexGuard Scope and Resource Tests
- [ ] Patch S1.10 — MutexGuard Fiber Contention Tests
- [ ] Patch S1.11 — Realistic Example Migration
- [ ] Patch S1.12 — Phase S1 Closure

Status rows are machine-parsed, exactly as the Cranelift guards parse `TASK.md`
(`scripts/phase15_close.py:51` matches `^- \[x\] Patch 15\.(\d+).+— DONE$`).
Keep each row in the form `- [ ] Patch S1.N — <Title>` / `- [x] Patch S1.N — <Title> — DONE`
with no trailing annotation. Which patches are blocked is recorded in the
Parallelism Warning table above and in the Coordination Requests section, never
inline in a Status row.

## Purpose

Phase S1 makes Gust's existing safe primitives usable by ordinary application
code without representation-aware workarounds.

The governing rule is that **the stdlib consumes Gust semantics; it does not
define them**. Phase S1 composes `Arena`, `Mutex`, `Channel`, `Fiber`, `Move`,
`Index`, and scope-exit resource semantics into safe abstractions. It does not
grow the core language sideways to make a library convenient.

The phase covers:

- a `str` surface an ordinary program can use without knowing `str` is a slice
  struct;
- collection methods reachable through references, so wrapper types are possible;
- one canonical branded type per collection regardless of source spelling;
- an arena-clone destination that does not leak `Arena*` versus `Arena**`;
- a scoped `MutexGuard` built from generic resource semantics rather than
  compiler knowledge of `Mutex`.

Phase S1 closes only the declared stdlib surface. It does not claim a complete
standard library, a text or Unicode API, networking, or production readiness.

## Starting State

Verified 2026-08-19 against `6c94728d`. Evidence and reproductions:
`docs/STDLIB_SURFACE_FINDINGS.md`.

Already present, contrary to the originating handoff document:

- `len(s)` accepts `str` and returns byte length — `src/typechecker/visitor.rs:3084`.
  This already satisfies the byte-length requirement and agrees with
  `VISION.md` §33.
- `std.str_slice(s, start, end)` — `src/runtime/strings.c:16`.
- `std.str_byte_at(s, idx)` — `src/runtime/strings.c:27`.
- `std.str_eq(a, b)`, `std.str_find`, `std.str_trim`, `std.str_split` —
  `src/runtime/strings.c:10,35,46,61`.
- All three string helpers are registry-owned Phase 17 runtime symbols
  (`p17_helper_std_str_eq`, `p17_helper_std_str_slice`,
  `p17_helper_std_str_byte_at`).

Confirmed defects:

- `str == str` typechecks and emits `(a == b)` over two C structs, which is not
  valid C. The failure surfaces from the host C compiler.
- Both compilers infer arena brands from a hardcoded list of identifier
  spellings — `["connCtx", "arena", "ctx", "Any", "a", "main_ctx", "bg_ctx", "file_ctx"]`
  at `src/codegen.rs:71` and `src/typechecker/types.rs:61`. A local named `a` has
  `&` prepended at call sites regardless of its type. The Rust and self-hosted
  compilers use different matching rules for the same list (`ends_with` versus
  substring), and the list is present in the committed bootstrap seed.
- A method call on a reference receiver fails resolution:
  `func lookup(m: &std.HashMap[str, int, ctx]) int { return m.Get("k"); }` →
  `Semantic Error: Undefined function 'm.Get'`. `GEMINI.md` §D already records
  this as a known deferral.
- `std_str_slice` and `std_str_byte_at` handle out-of-range input with
  `printf` + `exit(1)`, terminating the process rather than the request or task
  as `VISION.md` §34 requires.
- `STEP52_RESOURCE_SEMANTICS.md:20-27` items 2 and 6 — automatic resource lifecycle
  enforcement, and an AST/typechecker representation for `defer` — are unmet.
  That document was last modified 2026-06-28, before Phase 15 closed.

### Since this snapshot

The list above is a dated baseline and is deliberately not rewritten. Three of
its confirmed defects have since been closed; an agent reading the baseline as
current would re-open work that is done.

| Defect in the baseline | State |
| --- | --- |
| `str == str` typechecks and emits invalid C | **Closed** by S1.1 (#74). Both compilers now reject `==` and `!=` on `str` with a byte-identical diagnostic naming `std.str_eq`. Making `==` *mean* content equality is still open as CR-1. |
| A method call on a reference receiver fails resolution | **Closed** by S1.3 (#86). |
| `defer` has no AST/typechecker representation | **Superseded.** `defer` is an AST node; `STEP52_RESOURCE_SEMANTICS.md` predates that. The remaining gap is destructor declaration and enforcement, re-verified by S1.7 (#87) and stated in CR-5. |

Still open exactly as recorded: the brand-spelling defect (CR-2, owned by
`TASK_PHASE19.md`) and the `exit(1)` bounds policy (CR-3, unscheduled).

`docs/ONE_WAY_LEDGER.md` carries the current status of each of these against the
compiler, with reproductions, and is the file to check before assuming a
baseline entry still holds.

Contracts Phase S1 consumes and must not redefine:

- Phase 14 owns type layout, target layout, and memory-access validation.
- Phase 15 owns resource identity, move state, cleanup obligations, destruction.
- Phase 16 owns signatures, placement, call plans, frame plans, compatibility.
- Phase 17 owns runtime ABI identity, runtime symbol identity and version,
  runtime components and packages. **Every `std.*` name is a Phase 17 runtime
  symbol.**
- MIR-to-C is the default backend and differential oracle.
- Explicit Cranelift selection has no fallback.
- `GEMINI.md` §A–§D govern branding, ephemeral views in structs, flat function
  scope, and arena-stored collection access in Gust sources.

## Phase Boundary

Phase S1 may implement:

- stable Gust-level diagnostics for stdlib misuse that currently escapes to the
  C compiler;
- regression and compile-fail suites over the existing stdlib surface;
- method resolution through reference receivers where the resolved canonical
  type and canonical MIR are unchanged;
- safe library wrappers composed from existing primitives;
- examples and documentation;
- one scoped `MutexGuard` expressed as an ordinary Gust linear resource.

Phase S1 must not silently absorb:

- a new or changed `std_*` runtime symbol without a Phase 17 registry row;
- new lifetime syntax, lifetime relations, or lifetime casts;
- arena-brand escape hatches or brand casts;
- new smart-pointer families;
- `Mutex[T]`, `Guard[T]`, or a protected-value borrowing system;
- removal or weakening of raw `Mutex.Lock` / `Mutex.Unlock`;
- removal or weakening of the `Lock(); defer Unlock();` pattern;
- operator semantics changes;
- a new MIR operation, or a changed meaning for an existing one;
- resource, drop, or move semantics changes;
- ABI, layout, or runtime-ABI changes;
- compiler knowledge of `Mutex`, `HashMap`, or any other individual stdlib type;
- backend-specific stdlib behaviour, in either backend;
- a silent Cranelift-to-C fallback for an unsupported stdlib feature;
- `std.net`, sockets, or scheduler-aware networking;
- Unicode scalar, grapheme, or validated-UTF-8 APIs;
- an owned `String[ctx]` type.

## Coordination Requests

These are shared-zone changes Phase S1 cannot make. Each is stated in the
seven-point format from `AGENTS.md`. They are scheduled by the operator into the
Cranelift lane, not by this roadmap.

### CR-1 — Content equality for `str ==`

1. **Intended behaviour:** `if command == "PING"` compares contents; `!=` is its
   negation.
2. **Existing limitation:** the typechecker accepts `str == str` and codegen
   emits `==` over two `Slice_unsigned_char` values, which is not valid C.
3. **Smallest generic change:** define `==` and `!=` on `str` as content
   equality in the compiler-owned operator set, lowering to the existing
   `std_str_eq` semantics through canonical MIR. No new operator, no user-level
   overloading.
4. **Affected:** `src/typechecker/visitor.rs`, `src/codegen.rs`,
   `compiler/typechecker.gst`, `compiler/codegen.gst`, canonical MIR equality
   lowering, `src/runtime/strings.c` (unchanged if `std_str_eq` is reused).
5. **MIR-to-C:** yes.
6. **Cranelift:** yes — parity required, or the feature is deferred in both.
7. **Bootstrap:** yes — dual compiler and seed.

`VISION.md` §16 makes the operator set compiler-owned, so this is Cranelift-lane
work by default even though the motivation is ergonomic. Patch S1.1 delivers the
non-semantic half — a stable diagnostic — so the miscompile stops immediately
whether or not CR-1 is scheduled.

### CR-2 — Brand identity from types, not identifier spelling

1. **Intended behaviour:** whether a value is an arena, and whether an argument
   is passed by value or by address, follows from its resolved type. Renaming a
   variable never changes generated code.
2. **Existing limitation:** both compilers test identifier spelling against a
   hardcoded brand-name list, and the two compilers use different matching rules
   for it.
3. **Smallest generic change:** resolve arena-ness and argument representation
   from the type system; delete the name list from both compilers; make the two
   matching rules identical or make the concept unnecessary.
4. **Affected:** `src/codegen.rs:71,128,1762,1808,1843`,
   `src/typechecker/types.rs:61,439`, `src/typechecker.rs:135,172`,
   `src/typechecker/monomorphize.rs:234,254,268,599,722`,
   `compiler/codegen.gst:658,762,896,1101,1851`,
   `compiler/typechecker.gst:4953,5151`, `gust_v4.c`.
5. **MIR-to-C:** yes.
6. **Cranelift:** yes — argument representation is Phase 16 ABI territory.
7. **Bootstrap:** yes, and this is the highest-risk element. The seed encodes
   the current behaviour.

CR-2 is the single common root cause of the originating document's Task 3
(branded collection consistency) and Task 4 (Clone arena references). It blocks
S1.4, S1.5, and S1.6. It is not a "small frontend fix", and the Stdlib lane must
not attempt it.

**Placement — decided 2026-08-19:** CR-2 is assigned to a narrow **Phase 19**
owning brand and argument representation, and nothing else. It is not folded into
Phase 18, whose boundary is targets, objects, and linkers, and it is not carried
inside a Stdlib patch. The reasons are that it is bootstrap-sensitive — it
changes both compilers and requires a seed regeneration — that it reaches into
Phase 16 ABI territory for argument representation, and that a defect present in
the committed seed deserves its own boundary and its own evidence rather than
arriving as a side effect of an ergonomics patch.

The Phase 19 roadmap is published separately, before any Phase 19 patch, in the
same way `TASK.md` was published before Patch 18.0.

### CR-3 — String bounds-failure policy

1. **Intended behaviour:** an out-of-range `str` index or slice fails the
   current request, task, or job — not the process.
2. **Existing limitation:** `std_str_slice` and `std_str_byte_at` call
   `printf` + `exit(1)`.
3. **Smallest generic change:** route runtime bounds failures through the
   existing panic path defined by `VISION.md` §34, rather than adding a
   `Result`-returning variant of each helper.
4. **Affected:** `src/runtime/strings.c`, the Phase 17 helper rows for both
   symbols, the fiber scheduler's failure path.
5. **MIR-to-C:** yes.
6. **Cranelift:** yes.
7. **Bootstrap:** no, if the symbol signatures are unchanged.

**Observed 2026-08-20 by Patch S1.2.** Confirmed by running a compiled program:
`std.str_byte_at("abc", 99)` prints `std.str_byte_at bounds check failed` and the
process exits with status 1. The program's own output stops there — `before` is
printed, `after` is not. So the failure terminates the process rather than the
request, task, or job, which is what `VISION.md` §34 requires. S1.2 records this
and does not change it; the regression suite deliberately does not exercise an
out-of-range index, because doing so would terminate the suite instead of
reporting a failure.

### CR-4 — Protocol for adding a `std.*` symbol — **RESOLVED 2026-08-19**

`std.X` resolves to the C symbol `std_X` (`src/typechecker/visitor.rs:1017`), and
every such symbol is a Phase 17 registry-owned runtime symbol whose registry
`AGENTS.md` assigns to the Cranelift lane. The Stdlib lane cannot add a stdlib
function without touching a Cranelift-owned file.

**Resolution — the three-step protocol:**

1. **Stdlib proposes.** The Stdlib patch states the symbol name, signature,
   semantics, failure behaviour, and which of its Exit Gates requires it. It
   writes no registry entry.
2. **Cranelift admits.** The Cranelift lane adds the helper row to
   `scripts/cranelift_feature_registry.json` with `symbol_identity`,
   `symbol_kind`, `source_path`, `reachability`, `inventory_owner`,
   `diagnostic_owner`, `owning_phase17_entry_id`, classification, and
   `target_applicability`, and refreshes
   `compiler/CRANELIFT_FEATURE_PARITY_REGISTRY.md` and
   `docs/CRANELIFT_FEATURE_REGISTRY.md`. This is a narrow PR of its own.
3. **Stdlib implements.** Only after the row exists does the Stdlib lane add the
   runtime implementation, the compiler-side binding, and the tests.

**Standing rules:**

- The Stdlib lane never edits `scripts/cranelift_feature_registry.json`,
  `scripts/cranelift_feature_registry.schema.json`,
  `compiler/CRANELIFT_FEATURE_PARITY_REGISTRY.md`, or
  `docs/CRANELIFT_FEATURE_REGISTRY.md`. Not to add a row, not to fix a typo.
- A Stdlib patch that discovers mid-flight that it needs a new symbol stops and
  files the step-1 proposal. It does not add the symbol and backfill the row.
- Composing existing registered symbols into a safe wrapper requires no
  proposal. Only a new or changed `std_*` symbol does.
- Changing the *behaviour* of an existing symbol — for example CR-3 — is the
  same three-step protocol, because the registry records its classification.

Phase S1 as scoped needs no new `std.*` symbol. The protocol exists so that the
first patch which does need one already knows the answer.

### CR-6 — The borrow model, or a restatement of it

1. **Intended behaviour:** `&T[ctx]` is a shared immutable borrow; `inout T[ctx]`
   is exclusive mutation; shared mutable references are rejected. That is what
   `VISION.md` §26 and Consolidated Rule 25 describe.
2. **Existing limitation:** one reference form exists and it carries no
   mutability. `inout` is not a keyword in `compiler/lexer.gst`,
   `compiler/parser*.gst`, `src/lexer.rs`, or `src/parser.rs`. `&T` resolves to a
   `Reference` type; writing through it with `(*r).field = value` is permitted
   with no mutability check and reaches the caller's value. Two `&T` arguments
   may alias one value and both write through it; fixtures doing both compile and
   run.
3. **Smallest generic change:** restrict mutation through references, by
   reintroducing `inout` or another mechanism, and enforce non-aliasing.
4. **Affected:** lexer, parser, and typechecker in both compilers; every `&T`
   signature in `compiler/*.gst` and `tests/*.gst`; the bootstrap seed.
5. **MIR-to-C:** yes, if mutability becomes a type property.
6. **Cranelift:** yes, for the same reason.
7. **Bootstrap:** yes.

**Resolved 2026-08-19 as a documentation correction.** `VISION.md` §26 described
a two-form borrow model that was never implemented; it now describes the single
mutable reference form that exists, and §30 and Consolidated Rule 25 are
corrected to match. Enforcement is deferred and unscheduled — it is a containment
property, so taking it up later needs a design decision and real enforcement, not
a wording change. Nothing in the Stdlib lane waits on it, and S1.3 shipped
without it.

### CR-5 — Generic resource semantics sufficient for a scoped guard

1. **Intended behaviour:** `guard := mutex.Lock()` yields a move-only value that
   releases the lock exactly once on every scope exit, including early return,
   error return, and across fiber suspension.
2. **Existing limitation:** `STEP52_RESOURCE_SEMANTICS.md` items 2 and 6 are
   unmet — resource lifecycle enforcement is inert, and `defer` has no
   AST/typechecker representation. `VISION.md` §27 marks shared ownership open
   as OD-3.
3. **Smallest generic change**, determined by Patch S1.7 on 2026-08-19, is two
   things:
   **(a) a way to declare destructor identity in source for a user-defined type.**
   `env_register_struct_linear_destructor` is called from exactly two places in
   `compiler/typechecker.gst`, both registering `os.CloseDir`, the second gated on
   a directory-handle predicate. No keyword, attribute, or annotation exists in
   either compiler's lexer or parser for a user type to name its destructor.
   **(b) wiring the existing scope-exit cleanup validator into typechecking.**
   `env_validate_linear_resource_scope_exit_cleanup` is called only from test
   entries. A program that opens a directory handle and never closes it compiles
   clean, so even the one supported resource type is unenforced.
   Representation, transfer state, and `defer` are already present — `defer` in
   particular became an AST node after `STEP52_RESOURCE_SEMANTICS.md` was
   written. The gap is destructor declaration and enforcement, not modelling.
4. **Affected:** typechecker resource state, canonical MIR resource values,
   scope-exit cleanup, destructor scheduling, `src/runtime/*` mutex contract.
5. **MIR-to-C:** yes.
6. **Cranelift:** yes.
7. **Bootstrap:** likely.

No Mutex-specific compiler support may be added under any circumstances. If the
generic change is too large, `MutexGuard` is deferred and the `Lock(); defer
Unlock();` pattern remains the recommended form.

**S1.7 verdict: S1.8 through S1.11 stay blocked.** A `MutexGuard` needs a
destructor, and no user-defined type can declare one. Building it today would
require hardcoding `Mutex` into the compiler the way `os_Dir_ctx` is hardcoded to
`os.CloseDir`, which the paragraph above forbids. `Lock(); defer Unlock();`
remains the recommended form until CR-5 lands.

### CR-7 — No roadmap owns the demo deliverable

1. **Intended behaviour:** `VISION.md` §0.7 names four Track A items — `uses`
   clauses, effect checking across the call graph, typed Postgres query
   derivation, and tenant scope tracked through query construction. They are the
   stated deliverable and the thing being sold (§0.4).
2. **Existing limitation:** no roadmap owns any of them. `TASK.md` owns targets,
   objects, and linkers. This document owns the safe stdlib surface.
   `TASK_PHASE19.md` owns brand identity. All three are below the demo line, so
   the demo has no lane and no patch sequence.
3. **Smallest generic change:** none — this is a scheduling gap, not a semantic
   one. What is needed is a Track A roadmap, in the form the other lanes already
   use, with a patch sequence and an exit gate.
4. **Affected:** roadmap ownership only. `docs/DEMO_TARGET_PROGRAM.md` records
   the target program, the required diagnostic, and a ten-row prerequisite table
   with per-row status and owner; six of those rows are marked unowned.
5. **MIR-to-C:** eventually yes, for effects and query derivation.
6. **Cranelift:** eventually yes, for the same reasons and for parity.
7. **Bootstrap:** yes, once `uses` is a keyword in both compilers.

Two prerequisites in that table are not scope creep and are worth pulling
forward regardless of when Track A is scheduled. CR-2 (brand identity) must land
because the memory model is approximated by identifier matching until it does.
And `std.Option` cannot be constructed without `unsafe`
(`docs/ONE_WAY_LEDGER.md` E1), which means OD-9 — can a model write Gust — would
currently be measuring whether a model can reproduce a tagged-union layout.
Testing OD-9 before that is fixed measures the wrong thing.

This CR carries no authorization. It exists so that "the demo is unowned" is
recorded somewhere a lane will read, rather than rediscovered per agent.

### CR-8 — Concurrency is detached, which is the rejected model

1. **Intended behaviour:** `VISION.md` §20 — spawned tasks belong to a lexical
   scope; leaving the scope waits for completed children, cancels unfinished
   ones, and prevents detached work from leaking. "Fire-and-forget work is not
   permitted in normal request code."
2. **Existing limitation:** the only primitive available *is* fire-and-forget.
   There is no `async`, `await`, `spawn`, or `scope` keyword in either lexer.
   Concurrency is `std.Spawn`, `std.Channel`, `std.Mutex`, and `std.Yield` over
   the fibers in `src/runtime/fiber.c`. `std.Spawn` starts work no scope owns:
   no join requirement, no cancellation propagation, and no task handle type, so
   a spawned task cannot be awaited, cancelled, or transferred, and nothing stops
   it outliving the context whose data it captured.
3. **Smallest generic change:** none is small. This is OD-1, a Ring 1 decision.
   The recommendation recorded in `VISION.md` §21 is transparent suspension over
   the existing scheduler, with structured scopes and linear task handles —
   Go's suspension model, not Go's task model. Resource machinery from Phase 15
   supplies the linear handle; the scheduler already exists.
4. **Affected:** both lexers and parsers, the typechecker's scope and escape
   analysis, canonical MIR task operations, `src/runtime/fiber.c`, and every
   current `std.Spawn` call site.
5. **MIR-to-C:** yes.
6. **Cranelift:** yes.
7. **Bootstrap:** yes.

Filed as issue #101.

**Owner: Cranelift lane.** `docs/SHARED_SEMANTIC_ZONE.md` assigns the fiber
scheduling contract there, and this changes it. The Stdlib lane must not add a
scope-like wrapper over `std.Spawn` in the meantime — that would be a
library-shaped answer to a semantic question, which the shared-zone protocol
forbids.

This is a report, not a patch. Nothing in Phase S1 is blocked on it. It is filed
because the gap between §20 and `std.Spawn` is invisible from either roadmap:
§20 reads as though it describes the implementation, and it does not.

### CR-9 — OD-3 was decided by implementation

1. **Intended behaviour:** `VISION.md` §27 marks shared ownership an open
   decision (OD-3) and says Gust "may provide" an explicit compiler-owned
   read-only shared ownership type such as `Rc[T, ctx]`, with safe application
   code receiving no unrestricted interior mutability.
2. **Existing limitation:** `std.Rc`, `std.RcNew`, and `std.RcNode` are already
   registered names (`docs/STDLIB_SURFACE_INVENTORY.md`). An open decision with a
   shipped implementation is not open, and §27's read-only qualifier is not
   obviously enforced given CR-6 — the single reference form carries no
   mutability.
3. **Smallest generic change:** none required if the answer is documentation.
   Either §27 is corrected to describe the surface that exists and OD-3 is closed
   or narrowed, or the existing surface is justified against the open decision
   and its read-only property is stated and tested.
4. **Affected:** `docs/VISION.md` §27 and the OD-3 row in §0.15; possibly a
   compile-fail fixture asserting that `std.Rc` does not yield mutable aliasing.
5. **MIR-to-C:** no, if resolved as documentation.
6. **Cranelift:** no, if resolved as documentation.
7. **Bootstrap:** no.

Precedent: CR-6 was resolved the same way — `VISION.md` §26 described a borrow
model that was never implemented and was corrected to the one that exists.

### CR-10 — Is an opt-in layout attribute shared-zone work?

Raised because `docs/UNBLOCKED_CONTAINMENT_WORK.md` proposal 1 cannot start until
it is classified, and classifying it wrongly in either direction is worse than
asking. This is a **classification question**, not a request to implement.

1. **Intended behaviour:** a type can declare that it has no readable string
   representation, so passing it to `std.Format` is a compile error. This is the
   half of `VISION.md` §81 that does not require effects — the §81 rationale is
   that an agent cannot leak a secret into a log line because the type forbids
   it.
2. **Existing limitation:** nothing marks a type unformattable.
   `grep -ciE 'opaque|no_format|not_formattable' compiler/typechecker.gst`
   returns 0, and `std.Format` accepts whatever it is given.
3. **Smallest generic change:** a fourth layout attribute beside `#[linear]`,
   `#[packed]`, and `#[repr(C)]` — one arm in the attribute chain at
   `compiler/parser.gst:869-872`, one field on `StructDecl`, one registry map
   mirroring `struct_linear_resource`, and one check at the formatting dispatch
   sites `compiler/typechecker.gst:1962-1963` and `:3810`, which already resolve
   `std_Format` / `std.Format` / `std_FormatInt` by name.
4. **Affected:** both parsers, both typecheckers, and the bootstrap seed. No MIR,
   no ABI, no layout computation, no runtime symbol.
5. **MIR-to-C:** no. The attribute is consumed entirely in the frontend; codegen
   never sees it, because a program using it either compiles unchanged or is
   rejected.
6. **Cranelift:** no, for the same reason.
7. **Bootstrap:** yes — dual compiler and seed regeneration, since both
   typecheckers must agree.

**The question.** `docs/SHARED_SEMANTIC_ZONE.md` places outside the zone "a
diagnostic that **rejects** a program the compiler currently miscompiles,
provided no accepted program changes meaning". This satisfies the second clause —
no existing type carries the attribute, so no currently-accepted program changes
meaning — but not the first: the programs it would reject are not miscompiled
today, they are correct, and formatting a would-be-secret works fine.

So it is neither clearly in the zone nor clearly out of it. Two readings, both
defensible:

- **Out of zone / Stdlib.** It adds no semantics to any existing construct, is
  opt-in, touches no MIR or ABI, and is the same size and shape as S1.1.
- **In zone / Cranelift.** It adds language surface — a new attribute is a
  permanent grammar commitment, and `VISION.md` §16 makes the operator and
  attribute surface compiler-owned.

**Recommendation, weakly held:** treat it as in-zone for the *decision* and
out-of-zone for the *work* — the owner rules on whether the attribute exists and
what it is called, and the implementation then proceeds as ordinary Stdlib-lane
work under that ruling. That matches how CR-1 was handled: `VISION.md` §16 made
the semantics Cranelift's call while S1.1 shipped the non-semantic half.

Nothing in Phase S1 is blocked on the answer. The proposal is, which is why it is
recorded here rather than left in a document nobody is assigned to read.

## Verification Policy

### Level 1 — Fast contracts

Level 1 guards may validate:

- the stdlib surface inventory and its agreement with the Phase 17 helper rows;
- stable diagnostic text and diagnostic ownership;
- compile-fail expectations;
- canonical type identity for paired inferred and explicit programs;
- brand propagation through references;
- resource state expectations where applicable;
- absence of new `std_*` symbols without a registry row;
- absence of backend-specific stdlib behaviour;
- test-level and workflow ownership.

Level 1 guards must not build every target, run the full historical suite, or
execute fiber contention matrices.

### Level 2 — Focused differential families

Level 2 compares, for each applicable case:

- default MIR-to-C;
- explicit MIR-to-C;
- explicit Cranelift, where the feature is inside the supported cohort;
- runtime values, stdout, stderr where declared stable, and exit status;
- mutation results;
- failure classification.

Equivalence means equivalent observable semantics, not identical machine code.

A feature outside Cranelift's current cohort is recorded as explicitly deferred.
It is never silently validated on MIR-to-C alone and never falls back.

Proposed family vocabulary:

- `stdlib-str-surface`;
- `stdlib-str-equality`;
- `stdlib-collection-receivers`;
- `stdlib-branded-collections`;
- `stdlib-clone-destination`;
- `stdlib-composition`;
- `stdlib-mutex-guard`.

### Level 3 — Historical evidence

Cranelift Historical Full remains the sole Level 3 owner. Phase S1 does not
create a second historical suite. Stdlib fixtures that require Level 3 coverage
are handed to the Cranelift lane as a coordination request and land in the
existing suite.

## Standard Definition of Done for Every Phase S1 Patch

A Phase S1 capability is done only when all of the following are true:

- The supported source shape is precisely bounded.
- The change composes existing Gust semantics and introduces no new semantic
  concept.
- No new or changed `std_*` runtime symbol exists without a Phase 17 registry
  row added by the Cranelift lane.
- Canonical type identity is unchanged, or the change is a scheduled
  coordination request.
- Canonical MIR is unchanged, or the change is a scheduled coordination request.
- A paired inferred-type and explicit-type program produces the same semantic
  type, ABI, layout, brand identity, and behaviour.
- A positive source test exists.
- A negative compile-fail test exists with stable diagnostic text.
- A runtime behaviour test exists.
- MIR-to-C behaviour is validated.
- Cranelift behaviour is validated where the feature is inside the supported
  cohort, and explicitly deferred where it is not.
- Brand misuse is rejected: wrong arena, use after move, mutation through an
  immutable receiver, value from an incompatible region.
- Resource misuse is rejected where the patch involves resources: copy, double
  release, use after move, two owners for one acquisition, fabricated guard.
- No raw-pointer or `unsafe` workaround appears in a user-facing safe surface.
- No backend learns about the feature independently.
- Explicit Cranelift still cannot fall back to MIR-to-C.
- Bootstrap remains safe: no construct the checked-in seed cannot compile.
- `GEMINI.md` guidance that the patch invalidates is updated in the same PR.
- The owning CI family contains focused evidence.
- The new guards are assigned to the correct test level.

## Patch Sequence

### Patch S1.0 — Opening Inventory and Stdlib Surface Baseline

**Purpose**

Establish the exact stdlib surface and its defects as a checked artifact, so no
later patch is scoped from assumption.

**Steps**

- Enumerate every `std.*` name reachable from user code, its C symbol, its
  signature, and its Phase 17 helper row.
- Record which names have no helper row.
- Record, per name, whether it is inside Cranelift's supported cohort.
- Record the confirmed defects from `docs/STDLIB_SURFACE_FINDINGS.md` as inventory rows
  with owners: CR-1, CR-2, CR-3, CR-5.
- Record the `GEMINI.md` §D deferral as an inventory row owned by S1.3.
- Resolve CR-4 (the symbol-addition protocol) before any later patch.
- Add `guard-stdlib-s1-surface-inventory`.

**Test Level**

Level 1.

**Exit Gate**

The stdlib surface inventory exists, is generated rather than hand-written,
agrees with the Phase 17 helper rows, and names an owner for every confirmed
defect. No behaviour changes.

### Patch S1.1 — `str` Equality Diagnostic

**Purpose**

Stop `str == str` from reaching the C compiler.

**Steps**

- Reject `==` and `!=` between two `str` operands in the typechecker with a
  stable diagnostic that names `std.str_eq` as the current form.
- Emit the diagnostic from both the Rust and self-hosted typecheckers with
  identical text.
- Add compile-fail fixtures for `==` and `!=`, for locals, parameters, return
  values, and struct fields.
- Confirm no existing source in `compiler/`, `tests/`, or `src/` relies on the
  previously accepted form.
- Add `guard-stdlib-s1-str-equality-diagnostic`.

**Test Level**

Level 1.

**Exit Gate**

`str == str` produces a stable Gust diagnostic at the source span. No program
reaches the C compiler with `==` over two slice structs. Behaviour of
`std.str_eq` is unchanged. This patch does not make `==` mean content equality;
that is CR-1.

### Patch S1.2 — String Surface Regression Suite

**Purpose**

Pin the existing string surface before anything else changes it.

**Steps**

- Cover `len`, `std.str_byte_at`, `std.str_slice`, `std.str_find`,
  `std.str_trim`, `std.str_eq`, `std.str_split`.
- Cover the value positions: local, function parameter, return value, struct
  field, arena-cloned string, string produced by split.
- Cover the boundary matrix: empty, whole, prefix, suffix, middle, first byte,
  final byte.
- Record current out-of-range behaviour as an observed fact referencing CR-3.
  Do not change it.
- Observe `GEMINI.md` §A: a struct holding a `str` field must be a branded
  template. Observe §C: unique local names within a function.
- Add a MIR-to-C and Cranelift differential family `stdlib-str-surface`, with
  any out-of-cohort case explicitly deferred.
- Add `guard-stdlib-s1-str-surface`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Every string operation has positive, boundary, and position coverage on
MIR-to-C, with Cranelift parity or an explicit deferral. Out-of-range behaviour
is recorded, not altered.

### Patch S1.3 — HashMap Methods Through References

**Purpose**

Make collections usable inside abstractions by resolving methods on reference
receivers.

**Steps**

- Normalize the receiver before method lookup so a reference receiver resolves the
  same methods a value receiver does.
- Cover `Get`, `Keys`, `Insert`, `Set`, `Remove`, `len`, `get_opt`, `GetRef`.
  **`Contains` is not in the list**: it does not exist as a HashMap method on a
  value receiver either, so it was never a reference-receiver gap. The original
  list was wrong.
- **Scope correction, 2026-08-19.** This patch originally required an immutable
  reference to resolve read methods and a mutable one to resolve read and
  mutation methods. That distinction does not exist: `inout` is not a keyword in
  either compiler, and `&T` resolves to a `Reference` that carries no mutability
  at all. See CR-6 and `VISION.md` §26. The patch therefore delivers resolution
  only, and adds no immutability guarantee.
- Require that the resolved canonical type and canonical MIR are identical to
  the value-receiver form. If they are not, stop: this becomes a coordination
  request.
- Preserve brand identity through the reference: no erasure, no substitution, no
  invented brand relation, no wrong-arena insertion.
- Add compile-fail tests: wrong arena brand, use after move, use of a moved map
  through a reference, value inserted from an incompatible region. Mutation
  through an immutable receiver is **not** testable — there is no immutable
  receiver, and enforcement is deferred (`VISION.md` §26).
- Update `GEMINI.md` §D, which currently defers this exact migration.
- Add `guard-stdlib-s1-collection-receivers`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

A helper taking a map by reference can call the same methods a value receiver
can, without copying the container. The value-receiver and reference-receiver
forms produce identical canonical types and canonical MIR. Brand misuse is still
rejected. Mutability is unchanged: `&T` was already mutable, so this grants no
new mutation capability — it makes an existing one reachable.

### Patch S1.4 — Branded Collection Type Consistency

*Blocked by CR-2.*

**Purpose**

Make an explicit type annotation semantically invisible.

**Steps**

- For `Vector[T, arena]`, `Slice[T, arena]`, `HashMap[K, V, arena]`, and every
  other branded collection, establish one canonical semantic representation
  produced by type resolution and consumed unchanged by both backends.
- Build paired programs: Program A with the type inferred, Program B with the
  same type written explicitly.
- Cover: inferred local, explicit local, function parameter, function return
  type, struct field, immutable reference, mutable reference, generic use,
  collection returned from a stdlib helper.
- Assert the pairs agree on semantic type, ABI, layout, brand identity, and
  behaviour.
- Neither backend reconstructs branding.
- Add `guard-stdlib-s1-branded-collections`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Adding an explicit annotation cannot alter the generated type, ABI, layout,
brand identity, or backend behaviour for any covered position.

### Patch S1.5 — Clone Arena Destination Normalization

*Blocked by CR-2.*

**Purpose**

Let application code express "clone this value into this region" without knowing
how the arena is represented.

**Steps**

- Accept an owned arena and a valid arena reference as the same destination when
  the type system says they denote the same arena.
- Resolve the destination in the frontend; hand codegen a resolved destination
  representation rather than a source expression to decorate.
- Cover: `Clone(local_arena, string)`, `Clone(valid_arena_reference, string)`,
  clone into an arena stored in a struct, clone via a helper function.
- Reject: wrong brand, moved arena, and freed or invalid arena where statically
  detectable.
- Introduce no arena pointers, brand casts, lifetime conversions, or raw-pointer
  escape hatches. Brand identity remains authoritative.
- Add `guard-stdlib-s1-clone-destination`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Application code never needs to know about `Arena*`, `Arena**`, address-of
insertion, or backend arena representation in order to clone a value. Wrong-brand
and moved-arena destinations are still rejected.

### Patch S1.6 — Stdlib Composition Regression Program

*Blocked by CR-2.*

**Purpose**

Prove the core ergonomics hold together in something shaped like an application.

**Steps**

- Write one program combining arenas, `str`, `Vector`, `HashMap`, `Clone`,
  references, function calls, and both explicit and inferred branded types.
- Shape it as a small parser or key-value workload, not as a synthetic compiler
  fixture.
- Require MIR-to-C success and correct execution.
- Require Cranelift parity where the current phase supports it, and an explicit
  deferral where it does not.
- Require no backend-specific source.
- Add `guard-stdlib-s1-composition`.

**Test Level**

Level 2.

**Exit Gate**

The composition program compiles and runs correctly with identical observable
behaviour on both backends, or with an explicitly recorded Cranelift deferral,
and contains no representation-aware code.

### Patch S1.7 — MutexGuard Prerequisite Audit

**Purpose**

Determine whether generic resource semantics can already express a scoped guard,
before any guard is written. Report-only.

**Steps**

- Re-verify each of the eight required semantic states in
  `STEP52_RESOURCE_SEMANTICS.md` against the post-Phase-15 compiler.
- Record which are met, which are inert, and which are absent.
- Refresh or supersede `STEP52_RESOURCE_SEMANTICS.md`, which predates Phase 15
  closure.
- State whether `VISION.md` §27 OD-3 must resolve before a guard can exist.
- Populate CR-5 item 3 with the smallest generic change actually required.
- Change no behaviour and add no enforcement.
- Add `guard-stdlib-s1-resource-prerequisites`.

**Test Level**

Level 1.

**Exit Gate**

A checked report states precisely which generic resource capabilities exist and
which are missing, and CR-5 names a concrete smallest change. If everything
required already exists, S1.8 proceeds; otherwise S1.8 is blocked and CR-5 is
handed to the Cranelift lane.

### Patch S1.8 — MutexGuard Prototype

*Blocked by CR-5.*

**Purpose**

Express a scoped lock as an ordinary Gust linear resource.

**Steps**

- `mutex.Lock()` returns a `MutexGuard` representing exactly one acquisition.
- The guard is move-only, non-copyable, and released exactly once on scope exit.
- Implement it with existing linear-resource metadata and registered destructor
  identity. No compiler knowledge of `Mutex`.
- Keep raw `Mutex.Lock` and `Mutex.Unlock` public and unchanged.
- Keep `Lock(); defer Unlock();` working and documented as the safer manual form.
- Do not introduce `Mutex[T]`, `Guard[T]`, or protected-value borrowing. The
  guard represents lock ownership only; shared data stays separate.
- Add `guard-stdlib-s1-mutex-guard`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

A `MutexGuard` exists as an ordinary linear resource type, releases exactly once
at scope exit, and required no Mutex-specific compiler support. Raw lock and
unlock are unchanged.

### Patch S1.9 — MutexGuard Scope and Resource Tests

*Blocked by CR-5.*

**Purpose**

Validate the guard against control flow, not just the happy path.

**Steps**

- Positive: normal scope exit, early return, nested scope, error return, guard
  move, guard passed into a helper, guard returned where legal.
- Compile-fail: copy the guard, double release, use after move, two owners for
  one acquisition, construct a fabricated guard, release the underlying mutex and
  then let the guard release again.
- Where preventing raw double-unlock would require a broad compiler semantic
  change, document it as a limitation rather than expanding scope.
- Add `guard-stdlib-s1-mutex-guard-scope`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Every listed positive case releases exactly once and every listed misuse is
rejected at compile time, or is recorded as an explicit documented limitation.

### Patch S1.10 — MutexGuard Fiber Contention Tests

*Blocked by CR-5.*

**Purpose**

Validate the guard under real fibers without altering mutex runtime semantics.

**Steps**

- Fiber A acquires a guard, yields; fiber B attempts acquisition and suspends;
  fiber A resumes; the guard leaves scope; fiber B wakes and acquires.
- Many fibers increment a shared integer; the final count is exact.
- Assert the guard abstraction does not change existing mutex runtime semantics.
- Record multi-shard scheduler and real parallel contention as future coverage if
  CI cannot run them.
- Add `guard-stdlib-s1-mutex-guard-fibers`.

**Test Level**

Level 2.

**Exit Gate**

Contention, suspension, and wakeup behave identically with and without the
guard, and the shared-counter result is exact.

### Patch S1.11 — Realistic Example Migration

*Blocked by CR-5.*

**Purpose**

Show the abstraction pays for itself in code that already exists.

**Steps**

- Convert one existing realistic test or example from manual `Lock()` / `Unlock()`
  to a scoped guard. A shared `HashMap`, a concurrent counter, or a small
  key-value workload is a good candidate.
- Require fewer manual cleanup paths, identical observable behaviour, identical
  synchronization guarantees, no `unsafe`, and no raw-pointer workaround.
- Add `guard-stdlib-s1-migration`.

**Test Level**

Level 2.

**Exit Gate**

The migrated program has strictly fewer manual cleanup paths and identical
observable behaviour and synchronization guarantees.

### Patch S1.12 — Phase S1 Closure

**Purpose**

Close the declared stdlib surface without overclaiming.

**Steps**

- Confirm every Status row is `DONE` or explicitly deferred with an owner.
- Confirm every coordination request is resolved, scheduled, or deferred with a
  named owning phase.
- Confirm no new `std_*` symbol lacks a Phase 17 registry row.
- Confirm no backend-specific stdlib behaviour exists in either backend.
- Confirm no fallback exists.
- Confirm `GEMINI.md` reflects the delivered behaviour.
- Record the residue: what a normal program still cannot express safely.
- Add `guard-stdlib-s1-close`.

**Test Level**

Level 1.

**Exit Gate**

Phase S1 is closed with an explicit residue list, no unowned deferrals, and no
claim of a complete standard library.

## Recommended Implementation Order

Patch S1.0 opening inventory and surface baseline
→ resolve CR-4
→ Patch S1.1 `str` equality diagnostic
→ Patch S1.2 string surface regression suite
→ Patch S1.3 HashMap methods through references
→ Patch S1.7 MutexGuard prerequisite audit
→ **hand CR-2 and CR-5 to the Cranelift lane**
→ Patch S1.4 branded collection type consistency
→ Patch S1.5 Clone arena destination normalization
→ Patch S1.6 stdlib composition regression program
→ Patch S1.8 MutexGuard prototype
→ Patch S1.9 MutexGuard scope and resource tests
→ Patch S1.10 MutexGuard fiber contention tests
→ Patch S1.11 realistic example migration
→ Patch S1.12 closure.

S1.7 is placed early on purpose. It is report-only, it is unblocked, and its
output is what makes CR-5 actionable. Running it before the block is reached
turns idle time into the information the other lane needs.

## Phase S1 Success Criteria

Phase S1 succeeds when ordinary safe Gust code can express strings, collections,
references to collections, arena cloning, shared synchronized state, and scoped
mutex locking without the author knowing:

- that `str` is a slice struct;
- the difference between `Arena*` and `Arena**`;
- how to reconstruct a brand by hand;
- which variable names the compiler treats as arenas;
- any backend detail;
- any manual unlock path;
- any Cranelift limitation.

And without the compiler acquiring:

- new lifetime machinery;
- new ownership proof systems;
- backend-specific semantics;
- knowledge of any individual stdlib type.

Phase S1 closure does not claim a complete standard library, a text or Unicode
API, networking, or production readiness.
