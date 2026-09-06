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
(`docs/STDLIB_SURFACE_FINDINGS.md`, verified 2026-08-19). Phase 19 has since
landed the CR-2 authority, and S1.6 can consume it. S1.4 and S1.5 verification
found narrower shared-zone defects, filed separately. The generic constructor
authority for CR-11 then landed in Cranelift Patch 20.3a, unblocking S1.4.
Cranelift Patches 20.3 and 20.5 subsequently resolved CR-12 and CR-13,
unblocking S1.5. Phase 20 later resolved CR-5's generic resource floor and
Patch 20.16d landed protected-access liveness. The first reusable S1.8 probe
then exposed CR-15: OD-2 forbids the user-written generic functions that the
selected module API would otherwise require, so a bounded compiler-owned
derivation had to land before S1.8 resumed. Cranelift Patch 24.0f closed that
authority and handed the selected backend-neutral module surface back to this
lane; S1.8 now consumes it without reopening OD-2.

| Delivered (9) | Ready in roadmap order (3) | Depends on the rest (1) |
| --- | --- | --- |
| S1.0, S1.1, S1.2, S1.3, S1.4, S1.5, S1.6, S1.7, S1.8 | S1.9, S1.10, S1.11 | S1.12 closure |

The lane does not idle at a blocked patch. It records the shared-zone defect and
takes the next independent item. That is why S1.6 was delivered while S1.4 and
S1.5 were blocked; each then resumed when its owning Cranelift authority landed.

This is a scheduling fact, not an objection to the two-lane model.

## Status

- [x] Patch S1.0 — Opening Inventory and Stdlib Surface Baseline — DONE
- [x] Patch S1.1 — `str` Equality Diagnostic — DONE
- [x] Patch S1.2 — String Surface Regression Suite — DONE
- [x] Patch S1.3 — HashMap Methods Through References — DONE
- [x] Patch S1.4 — Branded Collection Type Consistency — DONE
- [x] Patch S1.5 — Clone Arena Destination Normalization — DONE
- [x] Patch S1.6 — Stdlib Composition Regression Program — DONE
- [x] Patch S1.7 — MutexGuard Prerequisite Audit — DONE
- [x] Patch S1.8 — MutexGuard Prototype — DONE
- [x] Patch S1.9 — MutexGuard Scope and Resource Tests — DONE
- [x] Patch S1.10 — MutexGuard Fiber Contention Tests — DONE
- [x] Patch S1.11 — Realistic Example Migration — DONE
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

- `len(s)` accepts one argument and returns `int` —
  `compiler/typechecker.gst:3458-3471`; codegen reads the slice `.len` field.
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
- The self-hosted compiler infers arena brands from a hardcoded list of
  identifier spellings. A local named `a` has `&` prepended at call sites
  regardless of its type, and the list is present in the committed bootstrap
  seed. The generated `compiler/CRANELIFT_PHASE19_SPELLING_INVENTORY.md` owns
  the live site list.
- A method call on a reference receiver fails resolution:
  `func lookup(m: &std.HashMap[str, int, ctx]) int { return m.Get("k"); }` →
  `Semantic Error: Undefined function 'm.Get'`. `GEMINI.md` §D already records
  this as a known deferral.
- `std_str_slice` and `std_str_byte_at` handle out-of-range input with
  `printf` + `exit(1)`, terminating the process rather than the request or task
  as `VISION.md` §34 requires.
- `STEP52_RESOURCE_SEMANTICS.md` items 2 and 6 — automatic resource lifecycle
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
| `defer` has no AST/typechecker representation | **Superseded.** `defer` is an AST node; Phase 20 subsequently resolved CR-5's destructor, opacity, acquisition, and cleanup floor. Cranelift Patch 24.0f then closed CR-15's OD-2-compatible compiler-owned derivation, which S1.8 now consumes. |
| Rust and self-hosted brand matching diverge | **Closed by deletion.** PR #137 removed the deprecated Rust prototype on 2026-08-21; D-2 is recorded as closed in `docs/SHARED_SEMANTIC_ZONE.md`. Phase 19 subsequently closed CR-2/D-1. |

Still open from that baseline: the `exit(1)` bounds policy (CR-3, unscheduled).
S1 verification after CR-2 landed found the narrower CR-11 through CR-13 gaps.

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
2. **Existing limitation:** `==` and `!=` have no meaning on `str`, so the
   compiler rejects them and content comparison must be written as the call
   `std.str_eq(a, b)`. **The original miscompile is closed and is no longer the
   limitation** — Patch S1.1 (#74) replaced it with a stable diagnostic, as
   `docs/SHARED_SEMANTIC_ZONE.md` D-3 records. Restated 2026-09-04; the previous
   wording ("the typechecker accepts `str == str` and codegen emits `==` over
   two `Slice_unsigned_char` values, which is not valid C") described the
   pre-S1.1 state and would send the implementing lane looking for a defect that
   is no longer present.
3. **Smallest generic change:** define `==` and `!=` on `str` as content
   equality in the compiler-owned operator set, lowering to the existing
   `std_str_eq` semantics through canonical MIR. No new operator, no user-level
   overloading.
4. **Affected:** `compiler/typechecker.gst`, `compiler/codegen.gst`, canonical
   MIR equality lowering, and `src/runtime/strings.c` (unchanged if
   `std_str_eq` is reused).
5. **MIR-to-C:** yes.
6. **Cranelift:** yes — parity required, or the feature is deferred in both.
7. **Bootstrap:** yes — self-hosted compiler and seed.

`VISION.md` §16 makes the operator set compiler-owned, so this is Cranelift-lane
work by default even though the motivation is ergonomic. Patch S1.1 delivers the
non-semantic half — a stable diagnostic — so the miscompile stops immediately
whether or not CR-1 is scheduled.

**What this CR is actually worth — stated 2026-09-04, and corrected against
evidence.** `docs/STDLIB_FOUNDATIONS.md` §1.1 directs its argument here, as the
sharpest statement of why CR-1 matters: *"Users should not have to remember
`std.str_eq(name, "PING")`. That is implementation leakage."* The Stdlib lane
records the argument as directed, and records that **two of its premises do not
survive checking**:

- **`std.str_eq` is not compiler-internal.** It is public, inventoried Stdlib
  surface: `std_str_eq` is defined in `src/runtime/strings.c`, declared in
  `src/runtime/core_headers.h`, registered under feature
  `p17_allocation_string_runtime`, and listed in
  `docs/STDLIB_SURFACE_INVENTORY.md`. That the self-hosted compiler is its
  heaviest caller makes it well-exercised, not private. Nothing internal is
  leaking.
- **Users are not required to remember it.** The S1.1 diagnostic names the exact
  call form at the exact site: `Semantic Error: str does not support '==' or
  '!='. Use std.str_eq(a, b) to compare text.` It is pinned by
  `guard-stdlib-s1-str-equality-diagnostic`.

The corrected case is narrower and still sound, and it is the one the operator
should schedule from: **the compiler-owned operator set is incomplete for
`str`.** Every text comparison in every user program reads as a call rather than
as `==`, unlike every other comparable type. That is a completeness and
ergonomics argument about the operator set — not a claim that users are forced
onto an unsupported or hidden API, which they are not. CR-1's priority should be
weighed on that basis: today's state is safe, diagnosed, and documented, so this
is an ergonomics debt rather than a correctness hazard.

### CR-2 — Brand identity from types, not identifier spelling

1. **Intended behaviour:** whether a value is an arena, and whether an argument
   is passed by value or by address, follows from its resolved type. Renaming a
   variable never changes generated code.
2. **Existing limitation:** the self-hosted compiler tests identifier spelling
   against a hardcoded brand-name list at nine generated-inventory sites.
3. **Smallest generic change:** resolve arena-ness and argument representation
   from the type system; converge the self-hosted consumers, then delete the
   name list and make the concept unnecessary.
4. **Affected — see `compiler/CRANELIFT_PHASE19_OPENING.md`, which supersedes the
   list that stood here.** Phase 19.0 recomputed the sweep and produced a
   *generated, validated* inventory of the live self-hosted implementation: nine
   decisions across codegen and typechecking, with each vocabulary recorded
   verbatim at its location. A hand-maintained list in this file would now be a
   second answer to the same question, and a worse one.

   **Recording why it was replaced, because the two failure modes are different
   and only one of them is survivable.** The old list had drifted — by one or two
   lines throughout, and by roughly twenty in `compiler/typechecker.gst`, mostly
   from my own S1.1 and S1.3 edits to that file. Drift is anticipated:
   `docs/SHARED_SEMANTIC_ZONE.md` permits source `path:line` and tells the reader
   to confirm the construct still exists before acting.

   **The original dual-compiler sweep was also incomplete, and that is not
   survivable the same way.** It omitted five literal `"Arena"` tests in the
   now-removed prototype parser. No amount of confirming-before-acting surfaces
   a file that was never listed. The generated self-hosted inventory replaces
   that historical, omission-prone evidence rather than carrying it forward.
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
changes the self-hosted compiler and requires a seed regeneration — that it
reaches into Phase 16 ABI territory for argument representation, and that a
defect present in the committed seed deserves its own boundary and its own
evidence rather than arriving as a side effect of an ergonomics patch.

The Phase 19 roadmap is published separately, before any Phase 19 patch, in the
same way `TASK.md` was published before Patch 18.0.

**Resolved 2026-08-22:** Phase 19 removed the spelling authority and made
resolved types authoritative for brand identity, canonical naming, layout, and
argument representation. S1 verification then found two narrower defects that
the Phase 19 fixtures did not cover: nested `Graph` annotation consistency
(CR-11) and exact Clone-result brand matching (CR-12). Arena invalidation after
`Free` is the separate resource-semantic CR-13.

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

`std.X` resolves through the compiler's registered namespace and every exported
`std_*` symbol is a Phase 17 registry-owned runtime symbol whose registry
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
   mutability. `inout` is not a keyword in `compiler/lexer.gst` or
   `compiler/parser*.gst`. `&T` resolves to a
   `Reference` type; writing through it with `(*r).field = value` is permitted
   with no mutability check and reaches the caller's value. Two `&T` arguments
   may alias one value and both write through it; fixtures doing both compile and
   run.
3. **Smallest generic change:** restrict mutation through references, by
   reintroducing `inout` or another mechanism, and enforce non-aliasing.
4. **Affected:** the self-hosted lexer, parser, and typechecker; every `&T`
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

### CR-5 — Generic resource semantics sufficient for a scoped guard — **RESOLVED 2026-08-24**

1. **Intended behaviour:** `guard := mutex.Lock()` yields a move-only value that
   releases the lock exactly once on every scope exit, including early return,
   error return, and across fiber suspension.
2. **Existing limitation. Corrected 2026-08-20.** This previously said
   `STEP52_RESOURCE_SEMANTICS.md` items 2 and 6 were both unmet, that resource
   lifecycle enforcement was inert, and that `defer` had no AST/typechecker
   representation. Verified against the compiler, two of those are false and the
   third was contradicted by item 3 below. **Item 6 is met:** `Defer` is an AST
   node and the typechecker handles it. **Enforcement is not inert:** it runs at
   function exit and at `Return`, and rejects an unclosed directory handle. What
   remains is that the obligation is keyed to a hardcoded directory predicate and
   no user type can declare a destructor, so it cannot attach to a user resource.
   Item 2, the generic `Resource[ctx, T]` representation, is not re-verified here
   and is still recorded as open. `VISION.md` §27 marks shared ownership open as
   OD-3.
3. **Smallest generic change**, determined by Patch S1.7 on 2026-08-19, is two
   things:
   **(a) a way to declare destructor identity in source for a user-defined type.**
   `env_register_struct_linear_destructor` is called from exactly two places in
   `compiler/typechecker.gst`, both registering `os.CloseDir`, the second gated on
   a directory-handle predicate. No keyword, attribute, or annotation exists in
   the self-hosted lexer or parser for a user type to name its destructor.
   **(b) generalising the scope-exit obligation beyond its hardcoded predicate.**
   **Corrected 2026-08-20.** This item previously said the validator was called
   only from test entries and that an unclosed directory handle compiled clean.
   Both were wrong. `env_validate_linear_resource_scope_exit_cleanup` is called
   from the real typechecking path at function-declaration exit and at `Return`,
   and an unclosed directory handle is rejected — verified by compiling one. What
   is actually missing is generality: the obligation that fires is driven by
   `env_open_directory_resource_requires_cleanup`, a directory-specific
   predicate, so it cannot attach to a user type. This is smaller than the
   original item — enforcement need not be built, only widened once (a) exists.
   **(c) a way to make a type's constructor unavailable to user code.**
   **Added 2026-08-20.** S1.9 requires that constructing a fabricated guard is a
   compile error. S1.8 forbids compiler knowledge of `Mutex`, so `MutexGuard` is
   an ordinary struct and any caller can write one literally. Rejecting that
   needs some notion of a constructor private to the defining module — and
   **the compiler has no visibility concept at all**: `internal`, `private`,
   `public`, `pub` and `protected` appear zero times in `compiler/lexer.gst` and
   `compiler/parser.gst`, and nothing named `visibility`, `is_public` or
   `is_private` exists in the parser.

   Representation, transfer state, and `defer` are already present — `defer` in
   particular became an AST node after `STEP52_RESOURCE_SEMANTICS.md` was
   written. The gap is destructor declaration, enforcement, and constructor
   visibility — not modelling.
4. **Affected:** typechecker resource state, canonical MIR resource values,
   scope-exit cleanup, destructor scheduling, `src/runtime/*` mutex contract.
5. **MIR-to-C:** yes.
6. **Cranelift:** yes.
7. **Bootstrap:** likely.

No Mutex-specific compiler support may be added under any circumstances. If the
generic change is too large, `MutexGuard` is deferred and the `Lock(); defer
Unlock();` pattern remains the recommended form.

**Historical S1.7 verdict: S1.8 through S1.11 stayed blocked.** A `MutexGuard` needs a
destructor, and no user-defined type can declare one. Building it today would
require hardcoding `Mutex` into the compiler the way `os_Dir_ctx` is hardcoded to
`os.CloseDir`, which the paragraph above forbids. `Lock(); defer Unlock();`
remains the recommended form until CR-5 lands.

**Current correction.** Cranelift Patches 20.6–20.10 and 20.14a–20.16d landed
source-declared destructor identity, opacity/private cleanup authority,
acquisition-site obligations, generic scope cleanup, branded generic destructor
validation, same-brand reference capture, and guard-rooted protected-access
liveness. CR-5 is therefore resolved. The remaining S1.8 blocker is not resource
semantics: the selected reusable `MutexGuard[T, ctx]` module surface requires a
generic function shape which OD-2 deliberately excludes. That narrower current
gap is CR-15.

### CR-7 — No roadmap owns the demo deliverable

1. **Intended behaviour:** `VISION.md` §0.7 names four Track A items — `uses`
   clauses, effect checking across the call graph, typed Postgres query
   derivation, and tenant scope tracked through query construction. They are the
   stated deliverable and the thing being sold (§0.4).
2. **Existing limitation:** no roadmap owns any of them. `TASK.md` owns targets,
   objects, and linkers. This document owns the safe stdlib surface.
   `TASK.md` owns brand identity. All three are below the demo line, so
   the demo has no lane and no patch sequence.
3. **Smallest generic change:** none — this is a scheduling gap, not a semantic
   one. What is needed is a Track A roadmap, in the form the other lanes already
   use, with a patch sequence and an exit gate.
4. **Affected:** roadmap ownership only. `docs/DEMO_TARGET_PROGRAM.md` records
   the target program, the required diagnostic, and a ten-row prerequisite table
   with per-row status and owner; six of those rows are marked unowned.
5. **MIR-to-C:** eventually yes, for effects and query derivation.
6. **Cranelift:** eventually yes, for the same reasons and for parity.
7. **Bootstrap:** yes, once `uses` is a keyword in the self-hosted compiler.

Two prerequisites in that table are not scope creep and were worth pulling
forward regardless of when Track A is scheduled. CR-2 (brand identity) has
landed, removing identifier matching as memory-model authority. `std.Option`
still cannot be constructed without `unsafe`
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
   There is no `async`, `await`, `spawn`, or `scope` keyword in the lexer.
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

### CR-5 and CR-10 shared one absent primitive — **RESOLVED 2026-08-24**

**Recorded 2026-08-20.** These were raised separately, for unrelated features, by
different lanes. They reduce to one missing piece of language surface, and
neither request said so.

| | needs | so that |
| --- | --- | --- |
| **CR-5** item 3(c) | a constructor user code cannot call | a `MutexGuard` cannot be fabricated (S1.9) |
| **CR-10** / containment proposal 1 | a field user code cannot read | `std.Format(secret.value)` cannot sidestep `#[opaque]` on `Secret` |

Both are "restrict what user code may do with a type's internals", and the
language has no such construct at all. Verified against `main`: `pub`, `private`,
`public`, `internal`, `export` and `protected` each appear **zero** times in
`compiler/lexer.gst` and `compiler/parser.gst`, and no `visibility`, `is_public`
or `is_private` concept exists in the parser.
This is `docs/ONE_WAY_LEDGER.md` row 35.

**Why this is worth stating rather than leaving in two places.** Each request, read
alone, invites its own narrow workaround — constructor-only privacy for CR-5,
opacity that propagates through field reads for CR-10. Either would unblock its
own case and neither would unblock the other, and the repository would then hold
two bespoke half-mechanisms where one general one was wanted. That is precisely
the outcome `docs/ONE_WAY_LEDGER.md` exists to prevent: one way to do each thing.

**This observation does not select a visibility design.** Whether to build
visibility, and at what granularity, belongs to the shared-zone owner. CR-10
below now classifies that ownership; it does not choose between propagating
opacity and implementing `VISION.md` §73's visibility levels.

**Current correction.** Phase 20 subsequently landed `#[opaque]` construction
control and `#[private]` cleanup authority as generic source metadata. The
shared primitive this section identified is no longer absent. S1.9 must consume
that generic authority after CR-15; it must not add a guard-specific exception.

### CR-10 — Type-opacity ownership — **RESOLVED 2026-08-21**

Raised because `docs/UNBLOCKED_CONTAINMENT_WORK.md` proposal 1 could not start
until it was classified. This resolution assigns ownership only. It does not
approve an attribute spelling or an opacity/visibility design.

1. **Intended behaviour:** a type can declare that it has no readable string
   representation, and reading one of its fields cannot launder the value into
   something formattable. This is the half of `VISION.md` §81 that does not
   require effects.
2. **Existing limitation:** no opacity or visibility mechanism exists.
   `std.Format` already rejects a struct argument, so
   `std.Format("%s", secret)` is not the hole. A public `str` field remains
   readable and formattable as `std.Format("%s", secret.value)`, and every
   struct field is public because the compiler has no visibility concept.
3. **Smallest generic change:** the design owner must choose one general source
   construct that prevents field reads from laundering opacity — either opacity
   propagated through field access or general visibility with an inaccessible
   field. A formatter-only check and a `Secret`-specific rule are both too
   narrow. An opt-in attribute may be part of the selected design, but its
   existence, spelling, and propagation rules are semantic decisions rather
   than Stdlib implementation details.
4. **Affected:** both parsers and typecheckers, AST/type-environment metadata,
   field-access validation or provenance, and the bootstrap seed. No MIR, ABI,
   layout computation, runtime symbol, or backend lowering is required if the
   property is consumed entirely by the frontend.
5. **MIR-to-C:** no; rejected programs do not reach code generation.
6. **Cranelift:** no backend work, but **the Cranelift lane owns the compiler
   semantic design and implementation** under the shared-zone default-owner
   rule.
7. **Bootstrap:** yes — both compiler implementations and the checked-in seed
   must agree on the source construct and its enforcement.

**Ruling:** this is shared-zone work for both the decision and the compiler
implementation. It adds permanent source-language and type-system surface, and
the diagnostic carve-out in `docs/SHARED_SEMANTIC_ZONE.md` does not apply: the
programs to be rejected are valid under today's semantics, not miscompiled.
Opt-in status means existing programs need not change, but it does not make the
new construct non-semantic.

The Stdlib lane may propose requirements and, after the generic primitive lands,
owns safe wrappers, compile-fail tests, examples, and documentation. It must not
add `#[opaque]`, propagate opacity, implement visibility, or special-case
`std.Format` in the meantime. Nothing in Phase S1 is blocked on this ruling;
containment proposal 1 and CR-5 item 3(c) remain blocked on the shared generic
primitive.

### CR-11 — Explicit `Graph` annotation changes nested brand resolution — **RESOLVED 2026-08-23**

[Issue #158](https://github.com/garthtrickett/gust/issues/158) contains the
seven-point shared-zone report and minimal witness. An inferred graph returned
from a helper compiles, while adding the equivalent explicit annotation reports
a brand-nesting violation and degrades the declared type to `Void`. The smallest
generic change is for nested monomorphized brand validation to consume resolved
`BrandIdentity` metadata rather than cleaned flattened names. Cranelift Patch
20.3a / PR #175 landed the generic contextual constructor-result authority for
Vector, HashMap, Pool, Mutex, Channel, and Graph. Patch S1.4 consumes that
authority without changing compiler semantics. Issue #158 remained open when
S1.4 resumed; that registrar discrepancy does not change the landed technical
state. **Owner:** Cranelift lane (resolved); Stdlib validation delivered by S1.4.

### CR-12 — Clone result brand is not enforced — **RESOLVED 2026-08-23**

[Issue #159](https://github.com/garthtrickett/gust/issues/159) contains the
seven-point shared-zone report and minimal witness. A value cloned into a second
arena can currently be assigned to an `Index` explicitly branded for the source
arena. Exact resolved brand identity must survive assignment and annotation
matching. Cranelift Patch 20.3 landed exact brand matching across assignment,
call, return, field, and alias boundaries before S1.5 resumed. Issue #159
remained open at delivery time; that registrar discrepancy does not change the
landed technical state. **Owner:** Cranelift lane (resolved); Stdlib validation
delivered by S1.5.

### CR-13 — `Arena.Free` does not invalidate later allocation — **RESOLVED 2026-08-23**

[Issue #160](https://github.com/garthtrickett/gust/issues/160) contains the
seven-point shared-zone report and minimal witness. A directly freed arena is
still accepted as a `std.Clone` destination. Fixing it changes resource/move
semantics, so the Stdlib lane stopped rather than adding a Clone-only check.
Cranelift Patch 20.5 / PR #178 now rejects post-Free allocation, Clone
destination use, writes, repeated Free, and alias/field/parameter reuse before
backend selection. Issue #160 remained open at delivery time; that registrar
discrepancy does not change the landed technical state. **Owner:** Cranelift
lane (resolved); Stdlib validation delivered by S1.5.

### CR-14 — Enum variant construction, and who owns it

Raised because `docs/DEMO_TARGET_PROGRAM.md` row 3 assigns "a constructor for
`Option` — `Some(42)`" to **Stdlib (Track A0 scope)**, and investigating it
shows that label is wrong. Filed in the stop-and-report format so the ownership
question is answerable rather than assumed.

1. **Intended behaviour:** `Some(42)` constructs an `Option`, and the equivalent
   for any enum variant, without `unsafe`.
2. **Existing limitation:** there is **no variant-construction syntax at all**,
   and no struct-literal syntax either. Every enum value is built by writing the
   discriminant and payload by hand, and both writes require `unsafe` because
   direct variant access is rejected in safe code:

   ```gust
   unsafe { o1.tag = 0; o1.Some.val = r1; }   // tests/e2e_adt_pressure_test.gst
   ```

   `Some(42)` resolves through ordinary function lookup and fails with
   `Semantic Error: Undefined function 'Some'` — verified by compiling it. So
   there is no existing construct to normalise; this would introduce a new
   expression form.
3. **Smallest generic change — and it is not an `Option` constructor.**
   `docs/SHARED_SEMANTIC_ZONE.md` says "prefer the smallest generic semantic
   improvement; never a special case for one library type". `Option` is a
   synthesised enum template registered beside user enums, and user enums have
   exactly the same problem. **The generic change is enum variant construction
   for all enums**; an `Option`-only constructor is precisely the special case
   that rule forbids. Row 3 states the symptom, not the change.
4. **Affected:** both parsers (a new expression form), both typecheckers
   (resolution and the `T` → `Enum[T]` inference), both codegens, and the
   bootstrap seed.
5. **MIR-to-C:** yes.
6. **Cranelift:** yes.
7. **Bootstrap:** yes. The seed cannot compile a construct it does not know, so
   this needs the regeneration sequence, not a plain rebuild.

**Why this is not Stdlib work, despite row 3.** The default owner rule is "a
semantic, compiler, or MIR change belongs to Cranelift; a pure library or API
change belongs to Stdlib". There is no library-shaped path available: there is
no `.gst`-level stdlib module, `std.*` functions are C functions recognised by
name in the typechecker, and a generic `Some` cannot be a C function because C
has no generics. Every route is a compiler change.

Nor does the S1.3 precedent apply. That was accepted as Stdlib work because it
was pure frontend *resolution* producing identical canonical MIR to an existing
form. This has no existing form to be identical to — it makes programs compile
that are currently rejected, which is the opposite direction from the zone's
carve-out for diagnostics that *reject* what is currently miscompiled.

**What is asked:** a ruling on ownership, and if it is Cranelift's, sequencing —
the same shape as CR-5's. Nothing here proposes a syntax; that is the owning
lane's design decision.

**Not blocking anything today.** No S1 patch depends on it. It is recorded
because row 3 names the Stdlib lane as owner and the Stdlib lane cannot do it,
and a demo prerequisite assigned to a lane that cannot execute it will sit
untouched while appearing owned.

### CR-15 — Compiler-owned derivation for the generic MutexGuard surface

Raised by the first checked implementation probe after Patch 20.16d's generic
resource-rooted access authority landed. This request preserves OD-2: it does
not ask for user-written generic functions.

1. **Intended behaviour:** an ordinary program imports the safe synchronization
   module and writes `sync.lock(&mutex)`, receiving one inferred or explicitly
   typed `MutexGuard[T, ctx]`. `sync.get(&owner)` returns guard-rooted `&T` only
   while the owner is live. Moving the owner transfers the obligation and scope
   exit unlocks exactly once. The public surface contains no raw pointer or
   `unsafe` spelling.
2. **Existing limitation:** generic structs and enums monomorphize, but OD-2
   deliberately excludes user-written generic functions. The preserved
   `tests/stdlib_s1_mutex_guard_generic_derivation_rejected.gst` probe confirms
   the live consequence: `T` in the imported `lock`/`get` signatures remains a
   namespaced literal rather than being instantiated from
   `std.Mutex[Counter, arena]`; branded-nesting and destructor validation then
   reject the unresolved placeholder. Patch 20.16d's concrete protected-access
   oracle passes, so this is derivation breadth rather than resource liveness.
3. **Smallest generic change:** add one bounded compiler-owned derivation for
   protected Resource guard families. Given a concrete protected type and brand,
   it produces concrete acquisition, guard, destructor, and rooted-accessor
   identities equivalent to the selected module-level `lock`/`get` surface.
   The derivation must operate on resolved generic Resource/protected-access
   metadata, not on the spelling `Mutex`, and must not enable arbitrary
   user-written generic functions. A Mutex-only typechecker exception and a
   backend special case are both forbidden.
4. **Affected:** self-hosted typechecker derivation and concrete type/call
   registration, generic substitution, branded-nesting and destructor
   validation, canonical resource call/MIR evidence, focused source fixtures,
   and the bootstrap seed. The Stdlib module, tests, examples, and ergonomics
   resume after the checked compiler authority lands.
5. **MIR-to-C:** yes. Every derived concrete surface must lower through ordinary
   canonical calls and the existing Resource cleanup/access semantics.
6. **Cranelift:** yes for parity evidence, but no bespoke Mutex or guard lowering.
   Cranelift consumes the same canonical MIR and must never fall back.
7. **Bootstrap:** yes. The derivation is implemented in the self-hosted compiler;
   seed reconvergence remains an isolated compiler-lane patch.

**Operator ruling 2026-08-24:** compiler-owned derivation is selected over
reopening general-purpose user generic functions. The desired initial spelling
is the module-level `sync.lock` / `sync.get` API. User-defined extension-method
ergonomics such as `mutex.ScopedLock()` are explicitly deferred for later and
are not part of CR-15 or S1.8.

**Resolved 2026-09-03 by Cranelift Patch 24.0f / PR #310.** The checked
generic, backend-neutral derivation authority is merged and its post-merge
handoff is effective. S1.8 consumes the selected surface; arbitrary generic
functions, backend-specific lowering, and Mutex-spelling authority remain
outside the accepted contract.

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
  the compiler, and `&T` resolves to a `Reference` that carries no mutability
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

*Unblocked from its original dependency after CR-2 landed in Phase 19, then
delivered after Cranelift Patch 20.3a resolved the narrower CR-11 generically.
Issue #158 was still open when delivery resumed, a registrar-status discrepancy
recorded without reinterpreting the landed authority.*

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

**Delivered surface**

- The paired fixtures cover the six contextual branded constructor families:
  `Vector`, `HashMap`, `Pool`, `Graph`, `Mutex`, and `Channel`.
- Gust's live slice spelling is `[]T`, not `Slice[T, arena]`; `[]byte` is covered
  as a local and branded-struct field and lowers identically to
  `Slice_unsigned_char` in both halves.
- Gust has one `&T` reference form and it permits mutation. The pair covers both
  read and mutation positions through that form; it does not invent or claim an
  immutable-reference type that the language lacks.
- Nested `Vector` supplies the generic-use position, and `HashMap.Keys` supplies
  the collection-returned-by-stdlib-helper position.
- The inferred and explicitly annotated programs emit byte-identical C, compile
  and run with the same exit status, reject wrong-arena, moved, and
  incompatible-region values with pinned diagnostics, and require the same
  explicit Cranelift deferral before driver discovery without fallback.

**Exit Gate**

Adding an explicit annotation cannot alter the generated type, ABI, layout,
brand identity, or backend behaviour for any covered position.

### Patch S1.5 — Clone Arena Destination Normalization

*Unblocked from its original dependency after CR-2 landed in Phase 19, then
delivered after Cranelift Patches 20.3 and 20.5 resolved CR-12 and CR-13.
Issues #159 and #160 were still open when delivery resumed; their registrar
state is recorded without reinterpreting the landed authority.*

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

**Delivered surface**

- Paired inferred and explicit fixtures cover `Clone(local_arena, string)`,
  `Clone(&local_arena, string)`, a destination stored in a struct field, a
  reference to that field, and Clone through a helper taking `&Arena`.
- The pair emits byte-identical C. Owned and referenced source spellings lower
  to the same `os_Arena*` destination call; the helper consumes its already
  resolved parameter directly rather than producing an `Arena**`-shaped call.
- Both MIR-to-C programs return exit 65 with identical empty stdout/stderr.
  Generic direct source-to-MIR remains explicitly deferred before driver
  discovery for both halves, with no C fallback or native artifact.
- Focused compile-fail fixtures pin wrong destination brand, moved destination,
  and post-Free destination rejection. Patch 20.5's owning guard retains the
  broader repeated-Free and alias/field/parameter invalidation matrix.
- No raw pointer, lifetime conversion, brand cast, `unsafe` workaround, new
  runtime symbol, canonical MIR change, or backend-specific rule was added.

**Exit Gate**

Application code never needs to know about `Arena*`, `Arena**`, address-of
insertion, or backend arena representation in order to clone a value. Wrong-brand
and moved-arena destinations are still rejected.

### Patch S1.6 — Stdlib Composition Regression Program

*Delivered after the Phase 19 CR-2 authority landed.*

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

*Delivered after the merged Patch 24.0f CR-15 handoff.*

**Purpose**

Express a scoped lock as an ordinary Gust linear resource.

**Steps**

- The safe synchronization module exposes `sync.lock(&mutex)` returning a
  compiler-derived `MutexGuard[T, ctx]` representing exactly one acquisition.
- `sync.get(&owner)` returns context-branded protected access rooted in that
  live guard, as required by OD-13 and Patch 20.16d.
- The guard is move-only, non-copyable, and released exactly once on scope exit.
- Implement it with existing linear-resource metadata and registered destructor
  identity after CR-15 lands. The derivation consumes generic Resource and
  protected-access metadata; no compiler or backend rule may key on the spelling
  `Mutex` or `MutexGuard`.
- Keep raw `Mutex.Lock` and `Mutex.Unlock` public and unchanged.
- Keep explicit-unsafe raw `Lock(); defer Unlock();` working and documented as
  the low-level manual form, not as the safe default.
- Preserve OD-2: application and library authors do not gain generic functions.
  The bounded compiler-owned derivation emits concrete instances for the
  selected module surface.
- Defer user-defined extension methods, including `mutex.ScopedLock()`, to a
  later explicitly roadmapped ergonomics decision.
- Add `guard-stdlib-s1-mutex-guard`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

A compiler-derived `MutexGuard[T, ctx]` behaves as an ordinary linear resource,
provides protected access only while live, and releases exactly once at scope
exit. Derivation is frontend-generic and both backends consume ordinary
canonical Resource semantics without Mutex-specific lowering. Raw lock and
unlock are unchanged and remain explicit unsafe primitives.

### Patch S1.9 — MutexGuard Scope and Resource Tests

*Sequenced after S1.8.*

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
- Construction opacity/private cleanup authority landed with CR-5. Require the
  CR-15-derived guard constructor to preserve that authority so fabrication is
  rejected without a Mutex-specific rule.
- Add `guard-stdlib-s1-mutex-guard-scope`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Every listed positive case releases exactly once and every listed misuse is
rejected at compile time, or is recorded as an explicit documented limitation.

### Patch S1.10 — MutexGuard Fiber Contention Tests

*Sequenced after S1.9.*

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

*Sequenced after S1.10.*

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

## Closure gate

Phase S1 cannot close yet. This section records exactly what gates it, and
`guard-stdlib-s1-close` enforces that the record stays accurate — including
refusing to let S1.12 be marked `DONE` while anything below is outstanding.

### Delivered

| patch | what it delivered |
| --- | --- |
| S1.0 | `docs/STDLIB_SURFACE_INVENTORY.md`, generated from the compiler |
| S1.1 | `str == str` rejected with one self-hosted frontend diagnostic |
| S1.2 | the string surface pinned, 33 values asserted in order |
| S1.3 | collection methods resolve through a reference receiver |
| S1.4 | inferred and explicit branded collections emit byte-identical canonical C and behaviour |
| S1.5 | owned, referenced, field, and helper Clone destinations normalize without representation leakage |
| S1.6 | application-shaped `Vector`/`HashMap`/`Clone` composition, with explicit native deferral |
| S1.7 | the resource prerequisites re-verified; CR-5 made concrete |
| S1.8 | safe `sync.lock` / `sync.get` prototype over an opaque linear guard, with both-backend behavior |

### Outstanding, with owners

| patch | blocked by | owner |
| --- | --- | --- |
| S1.9 MutexGuard scope tests | next roadmap row | Stdlib lane |
| S1.10 MutexGuard fiber tests | S1.9 | Stdlib lane |
| S1.11 realistic migration | S1.10 | Stdlib lane |
| S1.12 closure | all of the above | Stdlib lane |

No deferral here is unowned. CR-11 through CR-13 and CR-15 are resolved; the
remaining rows are ordinary Stdlib work sequenced by this roadmap.

### Residue — what a normal program still cannot express safely

Recording this is the point of the phase, not an apology for it.

- **`command == "PING"` does not work.** S1.1 turned the miscompile into a
  diagnostic, but content equality is CR-1, and operator semantics are
  compiler-owned (`VISION.md` §16). Users write `std.str_eq(a, b)`.
- **An out-of-range string index kills the process**, not the request, which
  `VISION.md` §34 forbids. CR-3, and filed as issue #91.
- **The safe MutexGuard prototype now exists.** S1.8 exposes the selected
  `sync.lock` / `sync.get` surface through an opaque linear guard. S1.9 through
  S1.11 still own its complete control-flow, contention, and migration evidence.
- **References carry no mutability and are not analysed for aliasing.** Two `&T`
  arguments may alias one value and both write through it (`VISION.md` §26).
- **Raw Mutex access remains explicitly unsafe.** Patch 20.16d preserved the
  existing raw primitives and requires an `unsafe` block. S1.8 adds the safe
  scoped spelling without changing or hiding that low-level form.

### What closure requires

1. S1.4, S1.5, and S1.6 are done.
2. CR-15 resolved with bounded compiler-owned guard derivation that preserves
   OD-2 and lowers through ordinary backend-neutral Resource semantics — then
   S1.8 through S1.11.
3. The residue list above re-checked against the compiler, not from memory.
4. `guard-stdlib-s1-close` passing with S1.12 marked `DONE`.
5. **The Level 3 owner not failing, cited by run ID and conclusion.**
   `AGENTS.md` requires that a phase is not closed while its Level 3 owner is
   failing, and that the completion report cites the run. Phase S1 does not own a
   Level 3 suite — `Cranelift Historical Full` is the sole owner — so closure
   inherits its state rather than being independent of it.

   **Observed 2026-08-20:** the most recent *completed* run on `main` is
   `32330451344`, **conclusion `failure`**, terminated 07:23:17Z — its
   `Level 3 full history` job failed, six sibling jobs succeeded, and
   `Level 3 declared-target completion` was skipped.

   This is not a stale result or a one-off. Paginating the entire retained
   window — **34 concluded runs from 2026-07-21 to 2026-08-20, a full month** —
   gives **32 `failure`, 2 `cancelled`, and zero `success` at any depth**. There
   is therefore no green Level 3 evidence available to cite, rather than merely
   an out-of-date one.

   Recorded here rather than asserting the suite is available: a suite that
   exists and fails satisfies an availability check exactly, which is why the
   requirement is phrased as *not failing* rather than *present*. The diagnosis
   belongs to the Cranelift lane; Phase S1 may not close on top of it.

Phase S1 closure will not claim a complete standard library, a text or Unicode
API, networking, or production readiness.

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
→ **hand CR-15 compiler-owned protected-guard derivation to the Cranelift lane**
→ Patch S1.8 MutexGuard prototype
→ Patch S1.9 MutexGuard scope and resource tests
→ Patch S1.10 MutexGuard fiber contention tests
→ Patch S1.11 realistic example migration
→ Patch S1.12 closure.

S1.7 was placed early on purpose. It is report-only, it was unblocked, and its
output made CR-5 actionable. S1.6 then proceeded independently when S1.4 and
S1.5 verification found CR-11 through CR-13.

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

And without the implementation acquiring:

- new lifetime machinery;
- new ownership proof systems;
- backend-specific semantics;
- backend knowledge of any individual stdlib type. The CR-15 frontend
  derivation is bounded compiler-owned work over generic Resource and
  protected-access metadata; it is not user generic programming or a
  Mutex-named backend rule.

Phase S1 closure does not claim a complete standard library, a text or Unicode
API, networking, or production readiness.
