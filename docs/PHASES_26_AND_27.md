# Phase 26 — systems safety, implicit context, and consolidation

**Status:** activated by the operator on 2026-09-24; implementation increments
remain open. `TASK.md` now points to this plan as the active Cranelift roadmap.

## Status

- [ ] Patch 26.1 — Gated Raw Pointers, Unsafe Blocks, and FFI
- [ ] Patch 26.2 — Generalized Linear-Resource Enforcement
- [ ] Patch 26.3 — Implicit Context
- [ ] Patch 26.4 — One Spelling of Absence
- [ ] Patch 26.5 — Stdlib Safety-Surface Audit
- [ ] Patch 26.6 — Native Release-Bridge Promotion

These rows close only when their full exit gates below pass. Incremental
implementation inside a row does not mark the row done.

This is the canonical plan for Phase 26 — gated raw pointers and FFI, generalized
linear resources, implicit context, and the consolidation work that follows.
Phase 27 was retired on 2026-09-05; the rows that were properties rather than
tidying became Phases 26.5 and 26.6, and the rest moved to
`docs/OPPORTUNISTIC_CLEANUP.md`. **The filename is deliberately unchanged**:
guards, workflows, and `docs/ONE_WAY_LEDGER.md` reference this path, and renaming
it would churn them for no gain. It combines the former `PHASES_5_AND_6.md` plan with the ordering,
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
> Phase 26.1 through 26.6. Phase 27 is retired and is not current numbering
> either.

**Placement:** the operator directed on 2026-08-20 that this work occur after
the Cranelift migration completes and C is deprecated. Renumbering it after the
existing roadmap tail makes that order explicit: Phase 26 begins only after
Phase 25 closes, apart from the already-built foundations recorded below.

**Post-Phase-25 baseline (2026-09-24).** Phase 25 removed the checked-in C
compiler seed, `gust_v4.c`. Normal bootstrap obtains a published bridge compiler
whose digest is committed, and `make bootstrap` checks the native fixed point
over emitted objects. The Phase 25 closure proof is narrower than a complete
C-compiler-free Gust build: the C-free musl link probe passes, but no compatible
musl bridge has been published for a full Gust build there, and the GNU host link
still uses a C driver. Phase 26 planning must preserve that boundary; a green
Phase 25 closure is not evidence that the broader launch gate has passed.
The merged-main baseline is `ef60f765` (Historical Full run `35970098674` and
no-C falsifier run `35970086292`, both successful); the exact boundary is the
closure sentence in `scripts/phase25_closure.py`.

The execution order below was written before the cut-over. Its 2026-08-20
status snapshot is historical. Before activating the first Phase 26 increment,
compare each proposed step with the merged compiler and its guards, retain the
already enforced safety floor, and identify the first remaining obligation.
In particular, the A→B→C unsafe-syntax migration describes how that floor was
introduced; it is not a request to turn enforcement back into a no-op.

**Activation audit against merged `main` `f2738d56` (2026-09-24).** This audit
classifies implementation state, not phase completion. The existing compiler
already parses `unsafe` and `extern func`, rejects raw dereference and casts
outside unsafe, and enforces direct extern-call unsafe context. Its provenance
carrier and non-laundering checks cover safe constructors, local bindings,
returns, calls, aggregate fields, container methods/readback, and unknown-origin
safe-branded targets. These are an enforced floor; no Phase 26 patch may revert
them to the original A-stage identity scopes.

| Phase 26 work | Live evidence | First remaining obligation |
| --- | --- | --- |
| 26.1 FFI/native boundary | `compiler/typechecker.gst` has direct extern-call unsafe rejection and `FunctionSignature` FFI policy fields; `STEP51_DEFERRED_UNSAFE_SEMANTICS.md` calls ownership, escape, callback, and native-error policy unfinished | Specify and enforce a complete per-position FFI ownership and escape contract on the canonical path |
| 26.1 layout | `compiler/parser.gst` accepts `#[repr(C)]` and `#[packed]`; `compiler/typechecker.gst` holds layout metadata and inert missing-C-layout predicates; `compiler/mir_struct_layout.gst` still defers packed structs | Select one layout authority and enforce C/packed/enum representation at FFI boundaries, including packed access |
| 26.1 isolated arena and address escape | Provenance guards exist, but the design checkpoint says no wrapper codegen or transient arena API exists | Implement isolated-call allocation/lifetime and close the remaining escape and raw-null cases |
| 26.2 resources | `open_linear_resources`, `#[linear]`, destructor registration, transfer states, and scope cleanup exist in `compiler/typechecker.gst`; the directory-specific map remains as a frozen shadow | Verify the generic `Resource[ctx,T]`/linear-index contracts and close the remaining declared Phase 26.2 leak and allocator-move cases |
| 26.3 implicit context | No parser or lowering for `with ctx` or function `using ctx` appears in compiler source | Implement the one pre-semantic desugaring with the explicit-context exclusions below |
| 26.4 absence | `get_opt` and `Option[T]` coexist with `LookupResult_T`, `map.Get`, and `empty[T]` in compiler source | Migrate file by file, then remove both legacy spellings as one row |
| 26.5–26.6 safety audit and release | No completed Phase 26 stdlib audit or final-source native bridge promotion | Audit the three safe collection surfaces, then promote a verified tagged native bridge after final merged Phase 26 sources |

The first implementation increment is **26.1D's FFI/native-call contract**.
Start by enumerating external parameter and return positions and their existing
metadata and validation paths; bind an explicit ownership/escape policy to the
canonical signature before adding layout or isolated-arena behaviour. Keep
26.1's later layout, isolated-arena, address-escape, provenance, and raw-null
work as separate coherent increments with focused positive and negative
evidence. The S1 collection-receiver native-call deferral exposed by Stdlib
S2.0 is a separate Cranelift prerequisite and must not be folded into this
FFI increment.

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

The staging records the safe order for a self-hosted compiler. Recheck the live
implementation before assigning new patches: Phase 25 already used unsafe-gated
FFI and layout controls, so the original A→C steps cannot be assumed pending.
The remaining D→F contracts need a current-state audit rather than a replay of
the original no-op grammar stage.

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

**26.1D packed layout subset (operator authorized, 2026-09-27).** The native
path admits one exact test-only read host borrowing a flat scalar
`#[repr(C)] #[packed]` aggregate. Canonical FFI preflight proves its target
layout, field order, and exact host identity before driver discovery. On the
selected x86_64 target, the host and Gust lowering access the unaligned `Int`
field bytewise; Gust source access requires `unsafe`, and taking a Reference to
that field is rejected. The existing pointer ABI is unchanged. Missing C
representation, wrong order, nested fields, enum fields, by-value positions,
unapproved hosts, and unsupported packed policies fail closed. General packed
layout, enum representation, and the full 26.1 layout gate remain open.

**26.1D packed write successor (operator authorized, 2026-09-28).** The same
proven flat packed `FfiProbe` layout now admits an explicitly unsafe
`borrow_write_call` raw pointer to one exact test-only host. The host stores
the unaligned `Int` bytewise; Gust observes the changed fields through its
existing unsafe bytewise field access. The pointer ABI and packaged runtime
symbol surface do not change. Unknown hosts and policies fail before driver
discovery. This does not qualify nested, by-value, enum, isolated, retained,
transferred, or returned pointer positions, callbacks, native errors, or
general packed layout.

**26.1D packed isolated-read successor (operator authorized, 2026-09-28).**
An explicitly unsafe `borrow_read_isolated_call` may copy the same proven flat
packed `FfiProbe` into a transient arena, call the already approved test-only
packed read host, then free the arena on normal return. The copy is exactly six
bytes; the host reads its unaligned `Int` bytewise. The existing pointer ABI,
host-object slot, and packaged runtime symbols are unchanged. Wrong host or
policy, missing C representation, and nested fields fail before driver
discovery. Packed isolated writes, by-value and enum positions, retained or
returned pointers, callbacks, native errors, nonlocal-exit cleanup, and general
packed layout remain outside this increment; Phase 26.1 remains open.

**26.1D packed isolated-write successor (operator authorized, 2026-09-28).**
An explicitly unsafe `borrow_write_isolated_call` may copy the same proven
flat packed `FfiProbe` into a transient arena, call the approved test-only
packed write host, copy exactly six bytes back, then free the arena on normal
return. Native host stores and Gust field reads use bytewise unaligned access.
The existing pointer ABI, host-object slot, and packaged runtime symbols are
unchanged. Wrong host or policy, missing C representation, and nested fields
fail before driver discovery. Nonlocal exits, by-value and enum positions,
retained or returned pointers, callbacks, native errors, and general packed
layout remain open; Phase 26.1 remains open.

**26.1D owned native return and release authority (operator authorized,
2026-10-05).** An external result may transfer one native-owned pointer into
an existing linear, C-represented owner struct whose validated same-module
destructor is the release authority. The result remains raw-derived; ownership
does not make its address a safe branded reference or arena index. A paired
terminal release call consumes that owner exactly once. Canonical function
metadata records and validates the policy of every external parameter and
return position before native lowering; the native boundary must reject
missing, forged, mismatched, or unsupported ownership metadata. Existing
call-bounded borrows and unowned raw returns keep their meanings. General
transfer, retention, callbacks, and native-error contracts remain fail-closed.

**Exit gate:** A target-qualified native fixture proves one allocation is
released exactly once on ordinary scope exit, explicit early return,
guard/defer cleanup, and ownership transfer through a Gust return. Source and
canonical negative cases reject an unbound or discarded acquisition, overwrite
of a live owner, duplicate alias or release, use after release, wrong release
signature or identity, unsafe-origin branding, unsupported host or ABI, and
truncated or forged per-position policy before driver discovery. The semantic
owner and release rule must be type-derived rather than keyed to the fixture's
type or host name. Native unwinding and process termination are not claimed as
cleanup exits. Focused guards, the compiler build, fixed-point bootstrap,
relevant native/resource regressions, exact-head PR workflows, and review-thread
resolution are required before this increment merges. This increment does not
close the remaining D, E, F, or Phase 26.1 gates.

**26.1D owned native argument transfer (operator authorized, 2026-10-06).**
An explicitly unsafe external call may consume a qualified linear,
`#[repr(C)]` one-pointer owner by value under a typed `transfer_owned`
parameter policy. The existing generic terminal move state ends Gust's cleanup
obligation at the call; a native consumer receives the actual C struct value
and assumes its release obligation. The policy is tied to the canonical owner
layout and validated destructor/release authority, not to a fixture type or
host name. A transferred raw-derived address never becomes a safe branded
reference or index. Borrowed, retained, callback, and native-error positions
keep their existing fail-closed rules.

**Exit gate:** Two independently named owner/release pairs prove the target's
real by-value C aggregate argument ABI with native allocation and release
counters. A successful handoff invokes the native release once and suppresses
Gust's destructor, including calls in conditional, early-return, and
defer/scope routes. Source negatives reject unbound or discarded acquisition,
use after move, alias reuse, double transfer, mismatched owner or release,
and unsafe-origin branding. Canonical MIR mutations reject missing, forged,
truncated, wrong-position, wrong-type, wrong-layout, or unsupported-target
`transfer_owned` policy before native object emission. No new MIR operation,
new smart-pointer family, `std_*` symbol, retained-pointer permission, or
native-unwinding cleanup guarantee is introduced. Focused and adjacent guards,
the compiler build, native fixed-point bootstrap, registry projections,
exact-head PR workflows, and resolved review threads are required before this
increment merges; D, E, F, and Phase 26.1 remain open.

**26.1D generic isolated-call plan (ownership authorized, 2026-10-06).**
For an explicitly unsafe external call, canonical lowering may select several
`borrow_read_isolated_call` and `borrow_write_isolated_call` positions in one
versioned Call plan. Each selected position names its parameter index, direction,
canonical aggregate type, target triple, byte size, and alignment. The compiler
derives these from the verified external signature and target layout authority;
the plan also names direct local-address provenance for reads, untrusted raw
copy-back provenance for writes, and single-call-arena cleanup. The native
worker checks these against the argument nodes, canonical signature, and layout
rows before object emission. A single transient arena holds copies of all
selected values for the duration of one native call. Read positions are copied
in only; write positions are copied in and back before the arena is freed. The
accepted native parameter ABI remains a pointer to the C-represented aggregate.
The previous Call policy codes `0`, `1`, and `2` and their canonical row bytes
retain their meanings; the new tagged plan has its own version and code. It
does not permit retention, ordinary transfer, callback escape, or a trusted
branded provenance for a native address.
The first generic route supports an unbranded read borrowed directly from a
local flat aggregate, an unsafe raw write pointer, and scalar value positions
and result; other origins and positions remain explicit unsupported cases.

**Exit gate:** Two independently named native hosts and distinct target-proven
flat C aggregate layouts exercise multiple read and write positions, read
immutability, write copy-back, real C pointer ABI, and exactly one arena free
before Gust continuation on normal, return, guard, and defer paths. Source and
canonical negatives reject an unsupported target or aggregate shape, bad
direction/count/index/type/size/alignment/provenance, missing or forged policy,
truncated or unknown plan version, and an attempted native-retention route
before driver discovery. Legacy Call codes `0`/`1`/`2` retain their existing
positive and negative evidence. The stable-tree focused and adjacent guards,
compiler build, native fixed-point bootstrap, registry projections, exact-head
PR workflows, and resolved review threads must pass before merge. Native
unwinding, longjmp, and process termination are outside the cleanup claim;
D, E, F, and Phase 26.1 remain open.

**26.1D generic direct-borrow Call plan (ownership authorized, 2026-10-06).**
An explicitly unsafe external call may borrow several verified flat C
aggregates at their original addresses through `borrow_read_call` and
`borrow_write_call` positions. Canonical Call code `4` appends the distinct
`direct_call.v1` row suffix: target triple, `synchronous_call` scope, selected
position count, then index/direction/pointee type/size/alignment/provenance for
each selected position. The provenance is the direct address of a local.
Source preflight rejects
unsupported declarations and argument origins before driver discovery; the
worker independently validates the plan against the canonical extern signature,
argument nodes, layout rows, and target before object emission. Read borrows carry the unsafe
extern's declared nonmutation contract; this does not add a language-wide
immutable-reference guarantee. Write borrows use explicit unsafe raw pointers
and their permitted native effects remain visible on the original aggregate.
No transient copy, arena, retention permission, or trusted native provenance is
created. Existing Call variants `0`/`1`/`2`/`3` and their canonical bytes and
meanings remain intact. The first route accepts unbranded flat C aggregates
and scalar value positions/results on the qualified target; unsupported alias,
indirect origin, escape, layout, callback, and native-error forms fail closed.

**Exit gate:** Two independent C hosts and distinct target-proven flat layouts
exercise multiple read and write positions, the actual original-address
pointer ABI, unchanged read values, and visible permitted write effects through
normal, return, guard, and defer continuations. Source and canonical poison
negatives reject wrong target, missing/forged/truncated/unknown plan version,
wrong position/direction/count/type/size/alignment/provenance, unsafe alias or
indirect origin, and retention or escape before driver discovery. Legacy Call
variants `0`/`1`/`2`/`3` retain their positive and negative regression evidence.
Focused and adjacent guards, stable compiler build, fixed-point bootstrap,
exact registry and historical projections, all exact-head PR workflows, and
resolved review threads must pass before merge. Native unwind, longjmp, and
process termination remain outside the synchronous-call claim; D, E, F, and
Phase 26.1 stay open.

**26.1D native-owned retained lease (ownership authorized, 2026-10-06).**
An explicitly unsafe external registration may retain one raw pointer from a
live `owned_return` allocation only while its exact linear owner remains
stable. The opt-in `#[ffi(retain)]` position is bound to the owner's acquisition
identity, one-pointer C layout, native-origin raw field, validated destructor,
and paired release function. The first supported acquisition and registration
are adjacent statements in the same lexical block; an intervening alias,
move, or other statement is rejected. That release function's unsafe native contract
unregisters the pointer before freeing it; Gust's existing terminal destructor
call is the sole release authority. The compiler rejects any preexisting or
derived raw alias, and after registration rejects owner access, move, Take,
transfer, overwrite, return, and any escape until compiler-scheduled cleanup.
Conservative branch joins reject mismatched active-lease states. This does not
qualify retention of stack or arena storage, grant safe branded provenance,
change ordinary resource borrows, or imply native unwind cleanup.

The producer records a distinct tagged `retained_lease.v1` Call policy with the
selected position, target, owner type and storage, acquisition identity,
raw-field provenance, and destructor/release binding. The worker validates
this against the canonical extern policy, owned-result/release authority,
actual argument and acquisition nodes, and the ordered cleanup path before
driver discovery or object emission. Call variants `0` through `4` keep their
canonical bytes and meanings. The first route is one retained raw position,
Void result, and x86_64 Linux ELF; callback, native-error, arbitrary lifetime,
and other retained origins remain unsupported.

**Exit gate:** Two independently named owner/host/release pairs prove actual C
pointer ABI, retained use before unregister, and exactly one unregister before
free and Gust continuation on normal scope, early return, guard, and defer
routes. Source negatives reject preexisting/derived aliases, stack or arena
origin, owner access or transfer while leased, duplicate registration,
use-after-release, ambiguous joins, and wrong release identity. Canonical
poison cases reject missing/unknown/truncated plan versions, wrong position,
target, owner/acquisition/raw-field/release identity, missing/reordered/
substituted cleanup, and forged lifetime paths before driver discovery.
Legacy Call `0`–`4` positive and negative behavior and canonical bytes remain
unchanged. Focused and adjacent guards, stable compiler build, fixed-point
bootstrap, registry and historical projections, exact-head PR workflows, and
resolved review threads are required before merge. D, E, F, and Phase 26.1
remain open.

**26.1D synchronous native callback (ownership authorized, 2026-10-07).**
An `unsafe` extern may declare a `Callback[int,int] #[ffi(callback)]` parameter
and invoke a named, noncapturing Gust function with exactly one `int` parameter
and `int` result during that native call. `Callback` is a compiler-owned formal
signature in this annotated position only; a user or imported type of that
name, malformed generic arguments, a function value/alias, and callbacks in
ordinary parameters or returns do not gain authority. The first supported
target is x86_64 Linux ELF with a checked C-compatible scalar calling
convention. Other extern positions and the result are scalar values. The
contract is synchronous and call-bounded: native code must not retain the
address, capture Gust state, throw/unwind through Gust, or claim a native-error
policy. This does not add general first-class function-pointer semantics.

The producer resolves the exact function symbol and signature and emits an
additive tagged `callback_call.v1` Call variant 6 with a FunctionAddress child
only at its selected callback position. The worker validates the tagged
position, selected extern policy, target and ABI, exact function identity,
signature, source scope, and child use before driver discovery and object
emission. It lowers that child to the validated original function address;
ordinary Call variants 0–5 retain their canonical bytes and meanings. The
fixture-only raw-pointer-to-void FunctionAddress route remains separately
qualified.

**Exit gate:** Two independently named C hosts and Gust callbacks execute the
actual `int (*)(int)` ABI, including calls with the callback at different
positions and scalar neighbors. Source negatives reject callback type
collisions, malformed signatures, unannotated/general use, aliases, captures,
unsafe-boundary violations, and unsupported retain/error policies. Canonical
poison cases reject missing/truncated/unknown versions, wrong target/position,
symbol/signature/policy/child substitution, and FunctionAddress outside its
owning Call before driver discovery or object emission. Exact-main Call 0–5
canonical bytes and behavior, focused/adjacent guards, stable compiler build,
fixed-point bootstrap, registry and historical projections, all applicable
exact-head PR checks, and resolved review threads are required. Retention of
callback addresses, general callback signatures, native errors, and D/E/F
completion remain open.

**26.1D explicit native error status (ownership authorized, 2026-10-07).**
An `unsafe` direct C extern may mark its `int` result `#[ffi(native_error)]`.
The returned signed `Int` is preserved exactly: zero denotes success and every
nonzero value denotes failure under the declared native contract. Gust does
not implicitly throw, construct a `Result`, read `errno`, or run cleanup from
this annotation. This cohort has only scalar value parameters and one scalar
result; callbacks, borrowed or retained positions, ownership transfer,
isolated storage, pointers as error results, and native unwinding remain
unsupported combinations. The result annotation is opt-in, so existing
ordinary calls keep their source meaning and canonical bytes.

The producer resolves the exact extern and target-qualified `Int` layout from
the primitive layout table and emits additive `native_error_status.v1` Call
variant 7. Its tagged return-position row binds the selected result policy,
target, signed scalar ABI, and explicit zero/nonzero convention. The worker
cross-validates all of that against the canonical extern signature and target
before driver discovery or object emission. It returns the original scalar
value through the established call lowering. Call variants 0–6 retain their
canonical bytes and meanings.

**Exit gate:** Two independently named C hosts execute zero, positive,
negative, and both extrema of the resolved signed `Int` width. Source
negatives reject malformed native-error return annotations, an annotation on a
parameter, unsupported target or result shape, mixed callback/ownership/
borrow policies, and calls outside `unsafe`. Canonical mutations reject a
missing result policy for a forged Call7, truncated or unknown versions,
wrong target, position, size, alignment, policy, callee, or convention before
driver discovery and without an output artifact. Same-input Call
0–6 canonical bytes and adjacent runtime behavior, focused guards, stable
compiler build, fixed-point bootstrap, exact registry/historical projections,
all applicable exact-head PR checks, and resolved review threads are required.
This status cohort alone does not close native error handling or D/E/F.

**26.1D per-position borrow and native-status composition (ownership assigned,
2026-10-07).** An unsafe direct C extern may combine independently qualified
`borrow_read_call`, `borrow_write_call`, `borrow_read_isolated_call`, and
`borrow_write_isolated_call` parameters, scalar value parameters, and an
explicit signed `Int #[ffi(native_error)]` result. The target is x86_64 Linux
ELF with the existing proven flat C layouts, local-address and raw-provenance
rules. Read positions do not gain immutability guarantees beyond their declared
unsafe native contract. Direct positions use the original address; isolated
positions use one transient arena, with every write copyback before its single
free and before Gust continuation, including a nonzero status. The exact signed
status value survives unchanged; it does not select or skip cleanup.

The producer decides an additive `ffi_policy_vector_status.v1` Call variant 8
with ordered per-formal policies and target-qualified layouts, an independent
status-result row, origin and alias evidence, and an exact copy-in/copyback/free
schedule. The worker validates this decided plan against the canonical extern,
argument nodes, target layout authority, and unsafe owning scope before driver
discovery or object emission. Conflicting or aliased direct and isolated
origins fail closed. Call variants 0–7 keep their canonical bytes and meaning.
This increment does not qualify callbacks, retention, transfer, native unwind,
general lifetime or alias relations, or a new runtime ABI.

**Exit gate:** Two independent C hosts and distinct qualified layouts execute
mixed direct and isolated read/write and scalar positions with zero, positive,
negative, and both extrema of the signed status width. Runtime and object
evidence distinguishes original addresses from isolated copies, proves read
nonmutation and visible writes, and proves all copybacks then exactly one free
before normal, Gust return, guard, and defer continuations for both zero and
nonzero status. Source negatives reject unsupported targets/layouts, origins,
aliases, unsafe scope, and excluded policy mixes. Canonical mutations reject
missing, duplicate, reordered, unknown, and truncated parameter/result or
schedule rows, wrong version, target, layout, provenance, unsafe owner, and
callee before driver discovery with no artifact. Same-input Call 0–7 bytes and
adjacent behavior, stable compiler build, fixed-point bootstrap, exact
registration/historical projections, all applicable exact-head PR checks, and
resolved review threads are required. D/E/F and Phase 26.1 remain open.

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

**26.1E4 bounded increment.** A direct zero-to-raw-pointer cast carries a
conservative may-null origin through canonical typechecking. Declared-safe,
non-extern raw-pointer returns and arguments reject that origin before native
driver discovery, even when the cast occurs in a lexical `unsafe` block. This
increment preserves nonzero and unknown raw pointers, explicitly unsafe callees,
and the bare `null` Index sentinel. It does not establish general raw-pointer
nullability; unknown pointer values and computed zero addresses require a
separate nullability model before the full raw-null obligation can close.

**26.1E computed-zero subset (ownership authorized 2026-09-28).** A separate
value-evidence state distinguishes Unknown, Zero, Nonzero, and MayZero from
address origin. Integer literals, narrowly qualified zero-preserving `+`,
local bindings and assignments, casts and aliases, and `if`/`while` joins carry
that state to declared-safe non-extern raw-pointer return and argument gates.
Zero and MayZero reject after type matching and before native driver discovery;
unknown inputs, nonzero values, explicitly unsafe callees, and bare `null`
retain their prior behavior. MayZero is abstract evidence: joining infeasible
paths or combining MayZero values may conservatively reject a value whose
feasible executions are nonzero. Unsupported arithmetic, unknown values, and
cross-function or aggregate flows remain admitted unless another rule rejects
them. This subset does not establish general nullability or close Phase 26.1.

**26.1E local field subset (ownership authorized 2026-09-28).** Direct writes to
raw-pointer fields of local structs now preserve Zero/MayZero value evidence
through selector readback and explicit `if`/`while` joins. A known zero path
rejects at declared-safe non-extern raw-pointer argument and return boundaries
before native driver discovery. Definite nonzero overwrites and unproven field
values retain their previous acceptance; whole-object reassignment and local
copy aliases conservatively retain MayZero where a known zero path existed.
Other aggregate aliases, heap/container fields, and cross-function flows remain
outside this bounded evidence model. This is not general nullability or Phase
26.1 closure.

**26.1E nested local field subset (ownership authorized 2026-09-28).** A
selector chain rooted in a scoped, by-value Struct may carry the existing
Zero/MayZero evidence through by-value Struct fields to a final RawPointer
field. Known zero then rejects at declared-safe non-extern raw-pointer
argument and return boundaries before the native capability planner. The
existing joins and conservative subobject invalidation retain possible zero;
nonzero and unproven values keep their existing typechecking behavior.
Pointer, Reference, index, and call bases, heap or container aliases, and
cross-function transport remain outside this subset. Native source lowering
for nested selectors remains deferred; a native-executed typechecker harness
provides the positive evidence. This does not close general nullability or
Phase 26.1.

**26.1E arithmetic zero subset (ownership authorized 2026-09-28).** The
existing four-state value evidence now follows only already-typechecked
integer/byte subtraction and multiplication. Explicit transfer tables carry
provable zero through `0 - 0` and any zero multiplication factor, and retain
MayZero where an input has a known zero path. Unknown and unproven values keep
their existing behavior; no general constant evaluator or operator change is
introduced. A Zero or MayZero raw pointer rejects at a declared-safe
non-extern argument or return boundary before native planning, including
when the cast is inside `unsafe`. Nonzero values and explicitly unsafe callees
retain their prior acceptance. Physical ABI, MIR, runtime, and layout are
unchanged. General nullability and Phase 26.1 remain open.

**26.1E division zero subset (ownership authorized 2026-09-28).** For an
already-typechecked `Int` or `Byte` division, a Zero numerator divided by a
proved Nonzero denominator remains Zero, and a MayZero numerator divided by a
proved Nonzero denominator remains MayZero. Every other state pair stays
Unknown, including a zero, MayZero, or unknown denominator. The existing
declared-safe non-extern raw-pointer argument and return gates reject these
proved zero paths before native planning; explicitly unsafe callees retain
their prior behavior. This is a value-evidence rule, not a division-by-zero
policy or a general constant evaluator. Operator semantics, MIR, physical
ABI, layout, and runtime remain unchanged. General nullability and Phase
26.1 remain open.

**26.1E match-arm zero subset (ownership authorized 2026-09-28).** An
exhaustive enum `match` snapshots local raw-pointer value evidence before its
arms, checks each arm from that state, and joins the outcomes with the existing
Unknown/Zero/Nonzero/MayZero operation. A computed-zero path therefore cannot
disappear because a later arm writes an unknown value; arm order does not
change the declared-safe non-extern argument or return diagnostic. The join
conservatively includes the pre-match state, matching existing local-field
evidence. Unknown and nonzero paths and explicitly unsafe callees retain their
prior behavior. This does not summarize function returns, model aliases, alter
enum or resource semantics, or close general nullability or Phase 26.1.

**26.1E take zero subset (ownership authorized 2026-09-29).** The existing
`Take` expression carries its operand's Unknown/Zero/Nonzero/MayZero evidence
through direct calls and local assignment readback, matching the established
`Move` transfer. Computed-zero addresses then reject at declared-safe
non-extern raw-pointer calls before native capability planning; nonzero and
unknown values and explicitly unsafe callees retain their prior behavior.
This does not change take/move ownership, provenance, MIR, ABI, layout, or
runtime, and does not close general nullability or Phase 26.1.

**26.1E local Struct Take-alias subset (ownership authorized 2026-09-29).**
When a local by-value Struct is taken into a local declaration or assignment,
the existing conservative field-state alias rule now recognizes `Take` as its
source expression. A known-zero raw-pointer field therefore carries MayZero
evidence to the destination and rejects at a declared-safe non-extern call
before native capability planning. Nonzero and unknown fields, explicitly
unsafe callees, and the existing plain-alias path retain their behavior.
This does not alter Take ownership or provenance, generalize to pointer or
heap aliases, admit unsupported native source routes, or close Phase 26.1.

**26.1E Int narrowing cast subset (ownership authorized 2026-09-29).**
Already-typechecked casts from `Int` to `Byte` or `Bool` use their recorded
source type and the existing four-state value evidence. A narrowing cast turns
Nonzero into conservative MayZero because an integer such as 256 can become
zero at the smaller width; a direct in-range positive integer literal from 1
through 255 retains Nonzero. Zero, MayZero, Unknown, equal-width casts, and
widening casts retain their prior evidence. The existing declared-safe,
non-extern raw-pointer argument and return gates reject the proven may-zero
path before native driver discovery. This does not change cast operator
meaning, MIR, ABI, layout, runtime, or the native capability of accepted
source routes. Other narrowing cast families and general nullability remain
open; Phase 26.1 is not closed.

**26.1E Bool literal subset (ownership authorized 2026-09-29).** The parser's
canonical `false` and `true` values (0 and 1) seed the existing four-state
value evidence as Zero and Nonzero. Casts and local bindings carry that state
to the existing declared-safe non-extern raw-pointer argument and return
checks. A false-derived raw pointer rejects before native driver discovery;
true, unknown inputs, and explicitly unsafe callees retain their previous
behavior. Noncanonical Bool payloads remain Unknown. This does not change
Bool or cast semantics, MIR, physical ABI, layout, runtime, or native route
admission. General nullability and Phase 26.1 remain open.

**26.1E logical-result subset (ownership authorized 2026-09-29).** Already
typechecked logical `&&` and `||` expressions with Int or Bool operands carry
the existing four-state value evidence through their canonical Bool result.
For `&&`, a proved Zero operand decides Zero; for `||`, a proved Nonzero operand
decides Nonzero. Other table cells preserve only proved zero paths or definite
nonzero results, leaving unsupported combinations Unknown. A zero-derived raw
pointer from a logical result rejects at declared-safe non-extern argument or
return boundaries before native driver discovery. Nonzero and unknown inputs
and explicitly unsafe callees retain their prior behavior. This changes no
operator meaning, MIR, physical ABI, layout, runtime, or native route admission.
General nullability and Phase 26.1 remain open.

**26.1E equality-result subset (ownership authorized 2026-09-29).** Already
typechecked `==` and `!=` with matching Int or Bool operands return Int and
carry bounded zero evidence only when a proved Zero is compared with a proved
Zero or Nonzero. Every other pair remains Unknown. A proved false result cast
to a raw pointer rejects at a declared-safe non-extern argument or return
boundary before native driver discovery. Nonzero and unknown results and
explicitly unsafe callees preserve their prior behavior. This does not admit
the general source-level comparison route, change operator meaning, MIR,
physical ABI, layout, or runtime, or close general nullability or Phase 26.1.

**26.1E relational-result subset (ownership authorized 2026-09-29).** Already
typechecked `<`, `<=`, `>`, and `>=` with matching Int operands return Int.
Only proved Zero compared with proved Zero carries result evidence: strict
comparisons are Zero and inclusive comparisons are Nonzero. Every other
operand-evidence pair remains Unknown because Nonzero has no sign evidence.
Zero-derived raw pointers reject at declared-safe non-extern argument or return
boundaries before native driver discovery. Nonzero and unknown results and
explicitly unsafe callees preserve their prior behavior. Operator meaning,
MIR, physical ABI, layout, runtime, and native route admission do not change.
General nullability and Phase 26.1 remain open.

**26.1E explicit-brand prerequisite (ownership authorized 2026-09-29).**
The self-hosted `types_match` implementation previously passed a null raw
`TypeEnvironment` pointer to `get_type_brand` at eight sites to request only
the type's explicit brand. An explicit-brand helper with no environment
parameter now serves those sites; the environment-aware helper and its callers
retain registered-brand lookup. This is a bootstrap-safe preparation for a
separate zero-initialized raw-pointer boundary patch. It does not change the
current raw-null gate, type matching outcomes, MIR, ABI, layout, or runtime,
and does not close Phase 26.1.

**26.1E Empty raw-pointer subset (ownership authorized 2026-09-29).**
Canonical `empty[*T]` uses `ZeroInitialize`, which yields a zero raw pointer.
After typechecking resolves an `Empty` expression to `RawPointer`, the existing
four-state value evidence records Zero. A declared-safe, non-extern raw-pointer
argument or return rejects it before native driver discovery. Other `empty[T]`
expressions, including the separate `Index` absence sentinel, retain Unknown
evidence, and explicitly unsafe callees retain their existing behavior. This
increment adds no MIR operation or physical ABI/layout/runtime change. It does
not resolve computed values returned through calls, general nullability, or
Phase 26.1 closure.

**26.1E direct-call return subset (ownership authorized 2026-09-30).** A
concrete, non-generic raw-pointer function with no parameters and one
unconditional direct return records the existing four-state value evidence
after its body is checked. A type-matched direct Identifier call result crossing a
declared-safe non-extern raw-pointer argument or return is checked after all
function bodies, independent of declaration order, before native planning.
Known Zero or MayZero rejects with `[RawNullSafeBoundary]`; Nonzero and Unknown,
explicitly unsafe target callees, and prior type-error precedence remain as
before. Calls stored in locals, parameter-dependent returns, multiple-return
bodies, qualified selectors, cast/move/take wrapped callees, indirect or recursive calls, and call chains remain outside this
increment. It changes no MIR, physical ABI, layout, or runtime behavior and
does not establish general nullability or close Phase 26.1.

**26.1E one-local call result subset (ownership authorized 2026-09-30).**
The same concrete direct nullary raw-pointer call may be bound to one local
and passed as the sole direct argument of the next expression statement in
that lexical block. The typechecker retains the callee's deferred four-state
return evidence through that binding, then applies the declared-safe
non-extern argument check after all function bodies. An intervening statement,
overwrite, alias binding, nested block, branch, loop, or wrapped/indirect call
invalidates or excludes the candidate. A native-executed typechecker test pins
the direct-call and one-argument shape. Known Zero and MayZero reject before
native planning; Nonzero, Unknown, explicitly unsafe callees, and prior type
errors retain their existing behavior. This is a bounded source-level check,
not general interprocedural nullability or Phase 26.1 closure. MIR, physical
ABI, layout, and runtime symbols are unchanged.

**26.1E one-hop local alias subset (ownership authorized 2026-09-30).** An
eligible concrete direct nullary `*T` call may be bound to one local, copied by
value into exactly one immediately following same-block local, then passed by
that alias in the immediately following direct one-argument call. A declared-
safe, type-matched, non-extern callee rejects proven Zero or MayZero before
native planning, regardless of callee declaration order. An assignment,
intervening statement, second alias, nested scope, indirect call, or type error
does not acquire this deferred summary. Nonzero, Unknown, and explicitly unsafe
callees retain their existing behavior. The existing pointer ABI, MIR, layout,
and runtime surface are unchanged. This subset does not establish general alias
provenance, interprocedural nullability, or Phase 26.1 closure.

**26.1E consecutive local alias subset (ownership authorized 2026-09-30).**
An eligible concrete direct nullary `*T` call may be bound to one local, then
copied by value through consecutive, type-matched, same-block `*T` local
declarations that each name the immediate predecessor. A direct, declared-safe,
non-extern one-argument call immediately following that chain rejects proven
Zero or MayZero before native planning, regardless of declaration order.
Assignment, an intervening statement, nested scope, indirect call, or earlier
type error prevents this deferred summary. Nonzero, Unknown, and explicitly
unsafe callees retain their existing behavior. The existing pointer ABI, MIR,
layout, and runtime surface are unchanged. This subset does not establish
general alias provenance, interprocedural nullability, or Phase 26.1 closure.

**26.1E Take-alias subset (ownership authorized 2026-09-30).** One immediate
same-block by-value `*T` local initialized with `take` of an eligible concrete
direct-nullary-call candidate (including an existing consecutive plain alias)
may carry the existing Zero or MayZero return evidence
to the immediately following type-matched declared-safe non-extern one-arg
direct call. The Take alias is terminal: another alias, assignment, intervening
statement, or nested scope invalidates the candidate. Typechecking and current
Take/move behavior run unchanged before the alias is promoted. The direct
`accept_raw(take ptr)` argument shape remains outside this increment. Known
Zero and MayZero reject before native planning; Nonzero, Unknown, explicitly
unsafe callees, prior type errors, and existing safe-return escape diagnostics
retain their behavior. MIR, ABI, layout, runtime and general nullability are
unchanged; Phase 26.1 remains open.

**26.1E direct terminal Take argument subset (ownership authorized
2026-09-30).** A concrete direct-nullary `*T` call result held in the current
same-block local candidate, including consecutive plain aliases, may cross
exactly one terminal `take` in the immediately following direct one-argument
call. After ordinary typechecking, a type-matched declared-safe non-extern
callee rejects proven Zero or MayZero before native planning, independent of
declaration order. A prior Take alias, nested or second Take, intervening
statement, assignment, nested scope, indirect call, or mismatched argument
cannot acquire this deferred summary. Direct literal Take retains its existing
zero diagnostic; Nonzero, Unknown, explicitly unsafe callees, and prior type
errors retain their behavior. The accepted source routes may still defer in
the native planner. Take/move semantics, MIR, ABI, layout, runtime and operator
meaning are unchanged. This bounded evidence does not establish general
nullability or close Phase 26.1.

**26.1E direct terminal Move argument subset (ownership authorized
2026-10-01).** The same eligible concrete direct-nullary `*T` call result in
the current same-block local candidate, including consecutive plain aliases,
may cross exactly one terminal `move` in the immediately following direct,
type-matched, declared-safe non-extern one-argument call. The compiler checks
the ordinary Move and call semantics first, then applies the existing
four-state return summary after all function bodies and before native planning.
A prior terminal Take alias, nested or second Move, Move alias declaration,
intervening statement, overwrite, nested scope, indirect call, or mismatched
argument cannot acquire this summary. Literal zero through Move retains its
existing diagnostic; Nonzero, Unknown, explicitly unsafe callees, and prior
type errors retain their behavior. The accepted native source route may still
defer. This increment changes no Move or resource bookkeeping, MIR, ABI,
layout, runtime, or operator meaning; general nullability and Phase 26.1
remain open.

**26.1E one-wrapper Move(Call) boundary subset (ownership authorized
2026-10-01).** After ordinary argument or return typechecking and unsafe-call
gates, one syntactic `move` around an eligible concrete direct-nullary `*T`
call carries its existing four-state return evidence to a declared-safe
non-extern raw-pointer boundary. Proven Zero or MayZero rejects before native
planning in either declaration order. Nested Move, Take, wrapped or indirect
callees, generic calls, and local-candidate seeding remain outside this
subset. Nonzero, Unknown, explicitly unsafe calls, and prior errors retain
their behavior. Move and resource bookkeeping, MIR, ABI, layout, runtime,
and operator meaning are unchanged. General nullability and Phase 26.1
remain open.

**26.1E one-wrapper Take(Call) boundary subset (ownership authorized
2026-10-01).** After ordinary argument or return typechecking and unsafe-call
gates, one syntactic `take` around an eligible concrete direct-nullary `*T`
call carries its existing four-state return evidence to a declared-safe
non-extern raw-pointer boundary. Proven Zero or MayZero rejects before native
planning in either declaration order. Nested or second Take,
Move(Take(Call)), indirect or generic calls, and local-candidate seeding remain
outside this subset. Nonzero, Unknown, explicitly unsafe calls, and prior type
errors retain their behavior. Take and resource bookkeeping, MIR, ABI, layout,
runtime, and operator meaning are unchanged. General nullability and Phase
26.1 remain open.

**26.1E depth-two Move/Take call boundary subset (ownership authorized
2026-10-01).** After ordinary typechecking and unsafe-call gates, exactly two
syntactic Move/Take wrappers in any of the four pairs carry an eligible concrete
direct-nullary `*T` call's Zero or MayZero evidence to a declared-safe
non-extern raw-pointer argument or return boundary. Both declaration orders
reject before native planning. Depth three, indirect or generic calls, and
local-candidate seeding remain outside this subset. Nonzero, Unknown, unsafe
calls, and prior type errors retain their behavior. Move/Take bookkeeping,
MIR, ABI, layout, runtime, and operator meaning are unchanged. General
nullability and Phase 26.1 remain open.

**26.1E checked Move/Take wrapper-chain safe boundary subset (ownership
authorized 2026-10-01).** After ordinary typechecking and unsafe-call gates,
the post-typecheck safe-boundary helper follows a syntactic chain of Move and
Take expressions to the existing concrete direct-nullary `*T` call summary.
Zero and MayZero evidence rejects at type-matched declared-safe non-extern
argument and return boundaries before native planning, independent of callee
declaration order. The source proof covers all eight three-wrapper combinations
and a four-wrapper chain, while retaining one/two-wrapper regressions. Move/Take
resource bookkeeping, local candidate seeding, indirect and generic callees,
nonzero and unknown values, prior type errors, unsafe calls, MIR, ABI, layout,
runtime, and operator meaning stay unchanged. This does not establish general
nullability or close Phase 26.1.

**26.1E one checked RawPointer AsCast call-boundary subset (ownership
authorized 2026-10-01).** After ordinary typechecking and unsafe-call gates,
one outer `as *T` expression whose operand and target resolve to RawPointer
may carry the existing concrete direct-nullary call's Zero or MayZero return
summary to a type-matched declared-safe non-extern raw-pointer argument or
return. The existing `[RawNullSafeBoundary]` diagnostic rejects before native
planning regardless of declaration order. Missing source type evidence,
nested casts, Move/Take combinations, scalar-to-pointer casts, indirect or
generic calls, and local aliases do not acquire this summary. Nonzero and
Unknown values, unsafe targets, and earlier type errors retain their current
behavior. This adds no cast semantics, MIR, ABI, layout, or runtime change and
does not establish general nullability or close Phase 26.1.

**26.1E checked RawPointer AsCast-chain safe-boundary subset (ownership
authorized 2026-10-01).** The existing post-typecheck boundary check may peel a
syntactic sequence of `as *T` expressions around one eligible concrete direct
nullary call only when every cast's operand and target have resolved
RawPointer types. Its existing Zero/MayZero summary then rejects a type-matched
declared-safe non-extern raw-pointer argument or return before native planning,
independent of declaration order. Missing metadata, Move/Take mixed with casts,
scalar-to-pointer casts, indirect/generic calls, aliases, and branches do not
gain a summary. Nonzero/Unknown and unsafe controls preserve their behavior;
earlier type errors retain precedence. This is a source diagnostic only: no
cast, MIR, ABI, layout, or runtime meaning changes, and general nullability
and Phase 26.1 remain open.

**26.1E one-cast/one-Move-or-Take safe-boundary subset (ownership authorized
2026-10-01).** At an already type-matched declared-safe non-extern raw-pointer
argument or return, the post-typecheck check may recognize exactly one checked
RawPointer-to-RawPointer `as` cast and one syntactic `move` or `take` in either
order around an eligible concrete direct nullary call. The existing four-state
callee summary rejects Zero/MayZero before native planning, independent of
declaration order. Every cast operand and target needs resolved RawPointer
metadata; missing metadata gives no summary. Two mixed casts or wrappers,
scalar-to-pointer casts, indirect/generic calls, aliases, and branches remain
outside this subset. Earlier type errors retain precedence; nonzero/Unknown
and unsafe controls keep their prior behavior. Move/Take bookkeeping, cast
meaning, MIR, ABI, layout, and runtime are unchanged. General nullability and
Phase 26.1 remain open.

**26.1E checked mixed cast/Move-Take chain subset (ownership authorized
2026-10-01).** After the prior full compiler suite reached and passed the
Phase 21 native corpus, stopping only at the locally absent `tree-sitter` CLI,
the two exact-main deferred mixed controls were reproduced with a poison
driver. The post-typecheck safe argument/return check may walk a finite
syntactic chain containing at least one Move/Take and one `as` cast around the
same concrete direct nullary raw-pointer call. Every cast must have resolved
RawPointer operand and target metadata; missing or non-pointer metadata gives
no summary. The unchanged four-state callee summary rejects Zero/MayZero before
native planning in either declaration order. Pure wrapper and pure cast chains,
prior type errors, nonzero/Unknown and unsafe controls retain their behavior.
This subset changes no Move/Take bookkeeping, MIR, ABI, layout, runtime, or
stdlib semantics. Aliases, branches, indirect/generic calls, general
nullability, and Phase 26.1 closure remain separate obligations.

**26.1E one checked cast of an immediate local call result (ownership
authorized 2026-10-02).** A direct, same-block local holding the result of an
eligible concrete nullary raw-pointer call may pass through exactly one
checked RawPointer-to-RawPointer `as` cast as the immediate argument to a
type-matched declared-safe non-extern function. The statement-window check
retains only that syntax; after ordinary typechecking, resolved pointer types
for the operand and target are required before the existing Zero/MayZero
summary can reject the call ahead of native planning. Nonzero/Unknown and
unsafe controls keep their current route, and prior type and Move errors keep
precedence. Alias hops, extra statements, nested or Move/Take-wrapped casts,
scalar casts, indirect/generic calls, and safe returns remain outside this
increment. MIR, ABI, layout, runtime, general nullability, and Phase 26.1
closure remain unchanged.

**26.1E checked cast chain of an immediate local call result (ownership
authorized 2026-10-02).** The same-block concrete nullary-call local from the
preceding increment may be the immediate argument through a finite syntactic
chain of `as` casts. Each cast must have resolved RawPointer operand and target
types after unchanged typechecking; missing metadata supplies no summary.
The existing four-state summary rejects Zero/MayZero at a declared-safe
non-extern raw-pointer argument before native planning. Nonzero/Unknown,
unsafe calls, prior type and Move errors, alias hops, extra statements,
Move/Take-wrapped casts, scalar casts, indirect/generic calls, and safe returns
retain their existing paths. This does not change MIR, ABI, layout, runtime,
stdlib, general nullability, or Phase 26.1 closure.

**26.1E one Take and one checked cast of an immediate local call result
(ownership authorized 2026-10-02).** A same-block local holding an eligible
concrete nullary raw-pointer call result may be the immediate argument through
either `Take(ptr) as *T` or `Take(ptr as *T)`. The statement-window check admits
only one Take and one cast; after unchanged typechecking, resolved RawPointer
operand and target types are required before the existing four-state summary
rejects Zero/MayZero at a declared-safe non-extern argument boundary. The
prior moved-variable diagnostic for `(move ptr) as *T` remains authoritative;
`move (ptr as *T)` and nonzero/Unknown, unsafe, alias, extra-statement, nested,
second-Take, scalar-cast, indirect/generic, and safe-return controls retain
their prior routes. Move/Take bookkeeping, MIR, ABI, layout, runtime, stdlib,
general nullability, and Phase 26.1 closure remain unchanged.

**26.1E one Take at a checked local cast-chain edge (ownership authorized
2026-10-02).** An immediate same-block local holding an eligible concrete
nullary raw-pointer call result may cross a declared-safe argument boundary
through one `take` at either edge of a finite `as *T` chain. After unchanged
typechecking, every cast operand and target must resolve to RawPointer before
the existing Zero/MayZero summary rejects the call before driver discovery.
Nonzero/Unknown and unsafe callees retain their prior routes. Move, a second
Take, aliases, intervening statements, scalar casts, indirect/generic calls,
and safe returns are outside this increment. Take bookkeeping, MIR, ABI,
layout, runtime, stdlib, general nullability, and Phase 26.1 closure remain
unchanged.

**26.1E one outer Move around a checked local cast chain (ownership authorized
2026-10-02).** An immediate same-block local holding an eligible concrete
nullary raw-pointer call result may cross a declared-safe argument boundary
through exactly one outer `move` around a finite `as *T` chain. After unchanged
typechecking, every cast operand and target must resolve to RawPointer before
the existing Zero/MayZero summary rejects the call before driver discovery.
Inner or second Move, Take combinations, aliases, intervening statements,
branches, scalar casts, indirect/generic calls, and safe returns remain outside
this increment. Wrong-type and moved-variable errors retain precedence;
Move bookkeeping, MIR, ABI, layout, runtime, stdlib, general nullability, and
Phase 26.1 closure remain unchanged.

**26.1E one checked cast of an immediate plain alias (ownership authorized
2026-10-02).** A concrete nullary raw-pointer call result may be copied once
to a type-matched by-value local in the same block, then passed to a declared
safe non-extern one-argument function through exactly one checked
RawPointer-to-RawPointer `as` cast in the next statement. After unchanged
typechecking, the existing Zero/MayZero summary rejects that safe argument
before native planning. A second alias, cast chain, Take/Move wrapper,
intervening statement, branch, indirect or generic call, and safe return stay
outside this increment. Nonzero/Unknown and unsafe calls retain their paths;
type mismatches keep precedence. Candidate invalidation, pointer semantics,
MIR, ABI, layout, runtime, stdlib, general nullability, and Phase 26.1 closure
remain unchanged.

**26.1E checked cast chain of an immediate plain alias (ownership authorized
2026-10-02).** The same concrete nullary raw-pointer result and one immediate
same-block, type-matched, by-value plain alias may cross a finite syntactic
chain of RawPointer-to-RawPointer `as` casts in the next direct, declared-safe,
non-extern one-argument call. The unchanged typechecker must first prove every
cast operand and target has resolved RawPointer type. Its existing Zero or
MayZero summary then rejects the safe argument before native driver discovery;
Nonzero, Unknown, and unsafe calls retain their existing native deferrals.
This deliberately promotes the formerly deferred two-cast alias fixture while
keeping a second alias, Take or Move wrapper, scalar cast, intervening statement,
branch, indirect or generic call, and prior type error on their previous paths.
Candidate seeding and invalidation, four-state evidence, pointer semantics,
MIR, ABI, layout, runtime, stdlib, general nullability, and Phase 26.1 closure
remain unchanged.

**26.1E consecutive plain aliases with checked casts (ownership authorized
2026-10-03).** The existing same-block candidate may pass through a finite
sequence of immediately consecutive, type-matched, by-value `*T` plain aliases
before a direct declared-safe non-extern one-argument call. When that argument
is a finite chain of checked RawPointer-to-RawPointer casts of the final alias,
the existing Zero/MayZero summary rejects it before native planning. Each cast
still requires resolved RawPointer operand and target metadata after unchanged
typechecking. The formerly deferred second-alias cases are now source errors;
one-alias behavior remains covered. A Take or Move terminal, assignment or
other intervening statement, nested scope, scalar cast, indirect or generic
call, Nonzero or Unknown evidence, and unsafe target retain their existing
paths and diagnostic precedence. No general alias or nullability model, MIR,
ABI, layout, runtime, stdlib, or Phase 26.1 closure is claimed.

**26.1E one terminal Take alias with checked casts (ownership authorized
2026-10-03).** An eligible concrete nullary raw-pointer call result may move
once into an immediate, by-value, type-matched local `mut alias := take ptr`.
When the next statement passes that alias through a finite syntactic chain
of checked RawPointer-to-RawPointer casts to a direct declared-safe
non-extern one-argument call, the existing Zero/MayZero summary rejects it
before native planning. Each cast retains the post-typecheck resolved pointer
proof. A prior plain alias before Take, another alias or Take afterward,
Move combinations, intervening or nested statements, indirect or generic
calls, scalar casts, Nonzero or Unknown evidence, and unsafe targets retain
their existing routes and diagnostic precedence. Take bookkeeping, MIR, ABI,
layout, runtime, stdlib, general nullability, and Phase 26.1 closure remain
unchanged.

**26.1E one plain alias before terminal Take with checked casts (ownership
authorized 2026-10-03).** One immediate type-matched plain by-value
RawPointer alias may precede the terminal `Take` alias above. The next
declared-safe non-extern call rejects a proven Zero/MayZero result through a
finite chain of post-typecheck proven RawPointer-to-RawPointer casts. The
existing candidate invalidation and Take/move bookkeeping remain unchanged.
More than one plain alias before Take, aliases after Take, intervening or
nested statements, indirect or generic calls, Move combinations, scalar
casts, Nonzero or Unknown evidence, and unsafe targets retain their prior
routes and type-error precedence. This does not change MIR, ABI, layout,
runtime, stdlib, general nullability, or Phase 26.1 closure.

**26.1E consecutive plain aliases before terminal Take with checked casts
(ownership authorized 2026-10-03).** A finite consecutive same-block prefix
of type-matched plain by-value RawPointer aliases may precede exactly one
terminal `Take` alias. The immediately following declared-safe non-extern
argument call rejects proven Zero/MayZero through a finite chain of checked
RawPointer-to-RawPointer casts before native planning. Existing alias
transfer, statement invalidation, cast proof, four-state summary, and Take
bookkeeping are reused. Any alias after Take, second Take or Move,
intervening or nested statement, indirect or generic call, scalar or
unproven cast, Nonzero or Unknown evidence, unsafe target, and wrong-type
diagnostic keeps its prior route. No MIR, ABI, layout, runtime, stdlib, or
general nullability change is authorized by this subset. Phase 26.1 remains
open. Its after-Take alias classification is superseded by the bounded
successor below.

**26.1E plain aliases after one Take (ownership authorized 2026-10-03).**
After unchanged typechecking, a proven Zero/MayZero candidate may pass through
finite consecutive same-block type-matched plain by-value RawPointer aliases
following exactly one accepted Take. A validated plain prefix before Take is
also allowed. The immediate declared-safe non-extern argument call rejects the
candidate directly or through a finite checked RawPointer-to-RawPointer cast
chain before native planning. The existing candidate invalidation, four-state
summary, per-cast proof, and Take/move bookkeeping remain authoritative.
Second Take or Move, statement gaps, nested or indirect calls, generic calls,
scalar or unproven casts, wrong types, Nonzero/Unknown evidence, and unsafe
targets retain their prior classification. This subset changes no MIR, ABI,
layout, runtime, stdlib, or general nullability rule. Phase 26.1 remains open.

**26.1E repeated Take aliases (ownership authorized 2026-10-03).** After
unchanged typechecking, a proven Zero/MayZero local RawPointer candidate may
pass through finite consecutive same-block, type-matched by-value
`Take(Identifier)` aliases after the first Take. Qualified plain aliases may
occur between them. The immediate declared-safe non-extern argument call
rejects the candidate directly or through a finite checked
RawPointer-to-RawPointer cast chain before driver discovery. Existing
Take/move/drop bookkeeping, statement invalidation, cast proof, and the
four-state summary remain authoritative. Direct Take at the call, Move,
statement gaps, nested or indirect calls, generic calls, scalar casts,
wrong types, Nonzero/Unknown evidence, and unsafe callees retain their prior
classification. The earlier second-Take deferral is superseded only in this
bounded local chain. No MIR, ABI, layout, runtime, stdlib, or general
nullability change is claimed. Phase 26.1 remains open.

**26.1E terminal Take argument after an alias (ownership authorized 2026-10-03).**
After unchanged statement and call typechecking, an immediately following
declared-safe non-extern call rejects proven Zero/MayZero when its single
RawPointer argument is exactly `Take(Identifier)` naming the current candidate
after at least one qualified same-block alias and a terminal Take alias. This
promotes the earlier second-Take-at-call deferral while retaining TypeMismatch
precedence, immediate-window invalidation, the four-state finalizer, and
existing Take/move/resource bookkeeping. Move, nested Take, Take with casts,
statement gaps, Nonzero/Unknown evidence, and unsafe calls retain their prior
classification. The patch changes no MIR, ABI, layout, runtime, or stdlib rule.
Phase 26.1 and general nullability remain open.

**26.1E checked outer casts over a terminal Take argument (ownership authorized
2026-10-03).** After unchanged typechecking, the same immediate safe-call
boundary rejects Zero/MayZero when a finite chain of checked
RawPointer-to-RawPointer casts wraps exactly one `Take(Identifier)` of the
current candidate after a terminal Take alias. Every cast operand and target
must have resolved RawPointer metadata. The existing summary, statement-window
invalidation, diagnostic precedence, and Take/move/resource bookkeeping stay
authoritative. `Take(Cast)`, a second or nested Take, Move, scalar casts,
wrong types, statement gaps, indirect/generic calls, Nonzero/Unknown evidence,
and unsafe callees retain their prior classifications. No MIR, ABI, layout,
runtime, stdlib, or general nullability change is claimed. Phase 26.1 remains
open.

**26.1E checked inner casts under a terminal Take argument (ownership
authorized 2026-10-03).** After unchanged typechecking, the same immediate
safe-call boundary rejects Zero/MayZero when exactly one outer `Take` wraps a
finite chain of checked RawPointer-to-RawPointer casts ending at the current
Identifier after a terminal Take alias. Each cast operand and target must have
resolved RawPointer metadata. The existing four-state summary, candidate
invalidation, TypeMismatch precedence, and Take/move/resource bookkeeping
remain authoritative. Nonzero/Unknown, unsafe calls, gaps, nested Take, Move,
scalar casts, wrong types, and other call shapes retain their prior
classification. This closes one source-level address-escape gap under E; it
does not complete D's FFI/layout contract, E's broader escape enforcement,
F's provenance/non-laundering contract, or Phase 26.1.

**26.1E finite outer Take chain after a terminal Take alias (ownership
authorized 2026-10-04).** After unchanged typechecking, an immediate
declared-safe non-extern argument call rejects a proven Zero/MayZero raw
pointer carried through consecutive outer `Take` expressions over the current
same-block Identifier or a finite checked RawPointer-to-RawPointer cast chain.
Every cast operand and target must have resolved raw-pointer metadata. The
existing four-state summary, candidate invalidation, diagnostic precedence,
and Take/move/resource bookkeeping remain authoritative. Nonzero/Unknown,
unsafe calls, wrong types, and an outer Move retain their prior classifications.
Interleaved Take/cast syntax remained deferred at this increment. This is a
bounded E source diagnostic,
not admission of the deferred native route or completion of D, E, F, or
Phase 26.1.

**26.1E interleaved Take and checked raw casts after a terminal Take alias
(ownership authorized 2026-10-04).** At an already type-matched declared-safe
non-extern argument boundary, a finite syntactic chain of `Take` and checked
RawPointer-to-RawPointer casts can carry the current same-block Zero/MayZero
candidate to the existing four-state finalizer. Every cast operand and target
must have resolved raw-pointer metadata after unchanged typechecking. The
candidate window, prior error order, and Take/move/resource meaning are
unchanged. Nonzero/Unknown values, unsafe calls, wrong types, outer Move,
scalar casts, and intervening statements retain their prior classifications.
This remains a bounded source diagnostic; native execution, general
nullability, the other 26.1 D/E/F obligations, and 26.2–26.6 remain open.

**26.1E immediate local safe-return summary (ownership authorized
2026-10-04).** After unchanged typechecking, a concrete non-generic direct
nullary call returning `*T` may bind one local and be returned immediately by
Identifier from a declared-safe function. The existing four-state return
summary rejects Zero/MayZero before native planning. Prior return type and
ephemeral-escape errors retain precedence. Nonzero/Unknown, unsafe functions,
aliases, casts, wrappers, intervening statements, nested/indirect/generic
calls, and broader interprocedural flow keep their prior classifications.
This changes no Take/move/resource meaning, MIR, ABI, layout, runtime, or
stdlib semantics. D/E/F and Phase 26.1 remain open.

**26.1E consecutive plain-alias safe-return summary (ownership authorized
2026-10-04).** A concrete direct nullary `*T` result may pass through finite
consecutive immediate same-block, by-value, type-matched plain local aliases
and then return the current Identifier from a declared-safe function. The
existing four-state summary rejects Zero/MayZero before native planning.
Earlier return type and ephemeral-escape errors retain precedence; nonzero,
Unknown, unsafe, gaps, overwrites, Take, casts, branches, and indirect or
generic calls retain their prior classifications. This changes no provenance
model, Take/move/resource semantics, MIR, ABI, layout, runtime, or stdlib.
D/E/F and Phase 26.1 remain open.

**26.1E checked cast-chain plain-alias safe-return summary (ownership authorized
2026-10-04).** After unchanged typechecking, a finite chain of resolved
RawPointer-to-RawPointer casts may wrap the current Identifier of an immediate
same-block, by-value, type-matched plain alias of a concrete nullary `*T`
result. The existing four-state summary rejects MayZero before native planning;
direct Zero evidence already rejects through expression typing. Each cast must
prove a raw-pointer operand and target. Direct-local casts without a plain
alias, Take/Move, scalar-inner casts, gaps, overwrites, branches, indirect or
generic calls retain their prior classifications. Earlier return type and
ephemeral-escape diagnostics retain precedence. This changes no provenance
model, Take/move/resource semantics, MIR, ABI, layout, runtime, or stdlib.
D/E/F and Phase 26.1 remain open.

**26.1E Take-alias safe-return summary (ownership authorized 2026-10-04).**
After unchanged typechecking, an immediate safe return may carry the existing
concrete nullary-call `*T` Zero/MayZero candidate through a finite consecutive
same-block, type-matched by-value alias chain containing `Take`. The return
uses the current Identifier or a finite chain of resolved RawPointer-to-
RawPointer casts. Existing candidate invalidation, per-hop raw-pointer proof,
four-state summary, and finalizer reject the escape before native planning.
Take/move/resource bookkeeping and prior type or ephemeral-escape diagnostics
retain their meaning. `Return Take(expr)`, Move, scalar-inner casts, gaps,
overwrites, branches, indirect/generic calls, unsafe functions, nonzero and
Unknown results retain their prior classifications. This changes no MIR, ABI,
layout, runtime, stdlib, or fallback behavior. D/E/F and Phase 26.1 remain
open.

**26.1E one-Take safe-return wrapper (ownership authorized 2026-10-04).**
After unchanged return typechecking and safety checks, the immediate same-block
concrete nullary-call `*T` candidate may be returned through exactly one
syntactic `Take` around its current Identifier, with finite checked
RawPointer-to-RawPointer casts in either position. Casted local returns still
require an already validated alias. The existing Zero/MayZero summary and
finalizer reject the safe escape before native planning; every cast proves its
resolved raw-pointer operand and target. Take/move/resource bookkeeping, prior
type and ephemeral-escape diagnostics, candidate invalidation, and accepted
nonzero/Unknown/unsafe controls retain their meaning. Nested Take, Move,
gaps, overwrites, branches, indirect/generic calls, and broader provenance
flow remain excluded. This changes no MIR, ABI, layout, runtime, stdlib, or
fallback behavior. D/E/F and Phase 26.1 remain open.

**26.1E outer Move over one Take at a safe return (ownership authorized
2026-10-08).** After ordinary return typechecking and safety checks, the
existing immediate same-block concrete nullary-call `*T` candidate may reach a
declared-safe return through exactly one outer syntactic `Move` enclosing the
already qualified one-`Take` form. Finite checked RawPointer-to-RawPointer casts
may appear on either side of that Take, subject to the existing validated-alias
prerequisite. The existing Zero/MayZero finalizer rejects the escape before
native driver discovery. Move and Take keep their existing bookkeeping;
earlier type and ephemeral-escape diagnostics, candidate invalidation, and
nonzero, Unknown, and unsafe-function controls retain their meanings. A second
Move or Take, an inner Move, broader alias or interprocedural flow, and
aggregate transport remain outside this increment. No MIR, ABI, layout,
runtime, or fallback contract changes. D/E/F and Phase 26.1 remain open.

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
the old ways" priced it as cleanup. Phases 26.5 and 26.6 below were moved for the
same reason, and the move retired the phase entirely.

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

## Phase 26.5 — the stdlib safety surface is audited

| Step | Work |
| --- | --- |
| 26.5 | Audit the stdlib safety surface so raw-pointer work does not leak through `std.Vector`, `std.HashMap`, or `std.String` |

Formerly Phase 27.5. Moved for the same reason as 26.4: it is a safety property,
not tidying, and it is one of the things `docs/CRANELIFT_LAUNCH.md` advertises.
The repository already forbids *adding* a raw-pointer workaround inside a safe
stdlib surface; nothing asserts the property for the code already there, and this
audit is the only thing that does.

**Exit gate:** every raw-pointer use reachable from `std.Vector`, `std.HashMap`
and `std.String` is either behind `unsafe`, behind an explicitly unsafe API, or
removed; the audit records what it examined, not merely that it passed.

---

## Phase 26.6 — promote the native compiler through the release seed policy

| Step | Work |
| --- | --- |
| 26.6 | Publish the native bridge built from the final merged Phase 26 compiler sources as the next release's seed, with a committed digest, fixed-point proof, and explicit supported platforms |

Formerly the second half of Phase 27.6. **The two halves of that row were
separated deliberately.** The sum-type refactor of `Statement` and `Expression`
is cleanup and lives in `docs/OPPORTUNISTIC_CLEANUP.md`; native bridge promotion
is a property the Level-3 claim rests on. Phase 25 replaced the checked-in C
seed with a previous-release bridge and an independently published, digest-pinned
bridge escape. The compiler built from the final merged Phase 26 sources must
become a verified bridge for the following release; a stale bridge cannot stand
in as evidence about that compiler.

Written as *"promote the consolidated result"* the obligation was hostage to a
refactor that is now optional — no refactor, no consolidated result, no
obligation. Written as a property of the native release bridge it holds either
way. This row does not revive the deleted C seed or assert that a bridge for
the GNU host can bootstrap a musl host.

Use Phase 25's release manifest and N-1 bootstrap policy: publish a tagged
bridge and fixed-point proof, commit the artifact digest, verify the bridge
before use, and state its host-platform scope. The release publication and
manifest update are reviewed as their own change. A full no-C Gust build on a
musl host still requires a compatible published musl bridge and its own test;
the Phase 25 link-only probe does not satisfy that launch obligation.

**Exit gate:** `make bootstrap` reaches the native emitted-object fixed point
from the verified previous-release bridge; the compiler built from the final
merged Phase 26 sources is published as a new tagged bridge with an artifact
digest and fixed-point proof in the committed release manifest; its supported
hosts are named, and the published bridge passes digest verification and an
offline bootstrap. `gust_v4.c` remains absent.

---

## Phase 27 — retired

Phase 27 was *"remove the obsolete paths made unnecessary by the completed safety
model"*. Its four rows were adjudicated individually on 2026-09-05 rather than
retired as a block: 27.5 became Phase 26.5, the seed half of 27.6 became Phase
26.6, and 27.3, 27.4 and the sum-type half of 27.6 moved to
`docs/OPPORTUNISTIC_CLEANUP.md`, which gates nothing.

The reason the phase could not simply be re-keyed is recorded in that document:
`docs/CRANELIFT_LAUNCH.md` §1 demanded *"every Phase 20–27 status row is
closed"*, so it inherited Phase 27's four-clause exit gate by counting rather
than by naming any part of it. Deleting the phase number would have deleted four
obligations without anyone deciding to.

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
not current completion authority for Phase 26.

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
| `open_directories` purge (was 27.3) | still present with a `legacy_freeze` test entry | frozen, not purged — now `docs/OPPORTUNISTIC_CLEANUP.md` |

Phase 26.4 closes the `docs/ONE_WAY_LEDGER.md` violation where `empty[T]`
competes with `Option[T]` as a second spelling of absence. The remaining
`open_directories` migration item in `STEP52_RESOURCE_SEMANTICS.md` is closed by
the cleanup row that was Phase 27.3, which gates nothing — see
`docs/OPPORTUNISTIC_CLEANUP.md` for why that is not a launch obligation.

Phase 26.4's file-by-file bootstrap rule follows the same discipline as Phase
26.1's A→B→C sequence: never change the compiler's own idiom in one pass. A
failure here is not merely a test failure; it can leave the compiler unable to
build itself.
