# Phase 20 — Whole-Program Differential Qualification

**Lane:** Cranelift. Branches follow the existing `codex/phase<N>-<patch>-<slug>` pattern.

Workflow, Monitoring, Merge, Phase Completion, Runner, and Git Authorization
policies are defined once in `AGENTS.md`. Ownership boundaries and the shared
coordination zone are defined in `AGENTS.md` and
`docs/SHARED_SEMANTIC_ZONE.md`. This document defines only what is specific to
Phase 20.

Phase 20 closes the known compiler-owned semantic blockers that prevent a
representative whole program from entering the differential cohort, then
qualifies that cohort through MIR-to-C and Cranelift. The prerequisites are
bounded to CR-11/#158, CR-12/#159, CR-13/#160, the checked contextual generic
constructor-result gap blocking Stdlib S1.4, and the generic
resource/destructor/scope/construction requirements represented by CR-5 and
#106. They come before qualification because a corpus that cannot express safe
library resources, whose constructor changes type at a contextual boundary, or
whose meaning changes with a brand annotation is not representative evidence.

The phase does not adopt a general lifetime algebra, arbitrary brand
relationships, async destructors, fallible implicit cleanup, a complete
package/application visibility system, new smart-pointer families, or any
backend-specific stdlib rule. It does not change a stdlib API. Those remain
separate decisions and separate lane work.

## Roadmap Activation

Phase 19 is fully closed. Its authoritative Historical Full run was
`32586399260`, event `workflow_dispatch`, completed `success` with 17/17 jobs on
exact merged `main` `a95e40d8f1cd4e6d31212e98105026d38b488c9b`. The generated
closure record correction subsequently merged, and the operator independently
verified `origin/main` at
`f9c1cf412f9705519fe78ac8fea174c7e75c3bc2`, with no open pull request.

On 2026-08-22 the operator explicitly activated this Phase 20 roadmap and its
implementation loop. After the roadmap pull request merges, the Phase
Completion Loop in `AGENTS.md` authorizes autonomous work through Patch 20.17,
subject to the patch boundaries, validation requirements, shared-zone rules,
and stop conditions below.

On 2026-08-23, after Patch 20.3 merged as
`3aa27d4fd6618293ecd3942f251f0e8b576e5280`, a checked Stdlib S1.4 seven-point
report established a new compiler-owned contextual generic constructor-result
gap. The operator directed Cranelift to triage it at this clean patch boundary
without folding it into Patch 20.3. This amendment inserts it as Patch 20.3a,
using the established lettered-patch convention and leaving every untouched
20.4–20.17 identity unchanged; the existing Phase 20 activation and completion
loop continue through closure.

Later on 2026-08-23, two P1 review threads filed after Patch 20.9 had already
merged demonstrated that conditional obligation state was not joined and that
by-value transfer did not establish the callee's obligation. The operator
directed Cranelift to verify and correct both findings before Patch 20.10. This
amendment inserts Patch 20.9a without widening it into the automatic cleanup
work reserved for Patch 20.10.

On 2026-08-24, after Patch 20.13, the preserved Stdlib S1.8 probe exposed two
generic compiler defects and one separate open design question: branded generic
Resource destructors fail declaration validation, a direct safe same-brand
reference parameter is misclassified as raw-derived when stored in an
aggregate, and `Mutex.Lock()` still has the compiler-owned
`RawPointer(T)`/explicit-`Unlock()` contract. The operator directed Cranelift to
record and triage the handoff without widening Patch 20.14 or deciding the
Stdlib API. This amendment inserts Patch 20.14a for only the two generic
compiler defects and registers the protected-access choice as OD-13 in
`docs/VISION.md` §0.15. Patch 20.14 remains unchanged.

On 2026-08-24, after Patch 20.16 merged as
`65bbc59b7b2f4ffe5e4134b7835803275c9a6aba`, the operator resolved OD-13 in
favour of one move-only linear guard carrying safe context-branded protected
access and owning automatic exactly-once unlock. This amendment inserts Patches
20.16a–20.16e before closure. They preserve the required inert-support,
whole-tree-migration, then enforcement sequence; keep raw access only as an
explicit unsafe/internal primitive; and leave the Stdlib type, spelling,
representation, re-entrancy, and accessor ergonomics to the Stdlib lane.

Activation is Cranelift-only. It does not authorize edits to `TASK_STDLIB.md`,
does not activate another lane, and does not authorize Phase 21.

## Status

- [x] Patch 20.0 — Opening Evidence and Qualification Authority — DONE
- [x] Patch 20.1 — Canonical Brand-Matching Primitives — DONE
- [x] Patch 20.2 — Nested Brand Annotation Correction (CR-11/#158) — DONE
- [x] Patch 20.3 — Exact Branded Assignment and Annotation (CR-12/#159) — DONE
- [x] Patch 20.3a — Contextual Generic Constructor Result Authority — DONE
- [x] Patch 20.4 — Arena Lifecycle State Authority — DONE
- [x] Patch 20.5 — Arena.Free Receiver Invalidation (CR-13/#160) — DONE
- [x] Patch 20.6 — Inert Resource Declaration and Visibility Surface — DONE
- [x] Patch 20.7 — Resource Declaration Migration Under the No-op — DONE
- [x] Patch 20.8 — Resource Declaration and Construction Enforcement — DONE
- [x] Patch 20.9 — Acquisition-Site Resource Obligations (#106) — DONE
- [x] Patch 20.9a — Obligation Path Join and Callee Ownership Correction — DONE
- [x] Patch 20.10 — Generic Scope and Destructor Enforcement (CR-5) — DONE
- [x] Patch 20.11 — Bootstrap Seed Regeneration and Fixed-Point Convergence — DONE
- [x] Patch 20.12 — Whole-Program Corpus and Observable Contract — DONE
- [x] Patch 20.13 — Stdlib and Runtime Component Differential — DONE
- [x] Patch 20.14 — Generated-MIR, Scale, and Resource-Use Qualification — DONE
- [x] Patch 20.14h — Phase-Frozen Historical Accounting — DONE
- [x] Patch 20.14a — Generic Guard Prerequisite Corrections — DONE
- [x] Patch 20.14b — Post-Prerequisite Bootstrap Seed Reconvergence — DONE
- [x] Patch 20.15 — Long-Lived and Concurrent Resource Differential — DONE
- [x] Patch 20.16 — Cross-Feature Qualification and Residue Audit — DONE
- [x] Patch 20.16a — Mutex Guard Decision and Implementation Authority — DONE
- [x] Patch 20.16b — Inert Resource-Rooted Access Authority — DONE
- [x] Patch 20.16c — Explicit-Unsafe Mutex Primitive Migration — DONE
- [x] Patch 20.16d — Protected-Access Liveness Enforcement — DONE
- [ ] Patch 20.16e — Protected-Access Bootstrap Seed Reconvergence
- [ ] Patch 20.17 — Phase 20 Closure

Status rows are machine-parsed in the same form the Phase 15–19 close guards
parse `TASK.md`. Keep each row as `- [ ] Patch 20.N — <Title>` or
`- [x] Patch 20.N — <Title> — DONE`, with no trailing annotation. An inserted
amendment may append one lowercase letter to `N`, as Patch 20.3a does here.

## Immutable Phase 19 Completion Record

These rows describe the closed parent phase and are not active Phase 20 work.
They remain in `TASK.md` because historical guards consume them.

- [x] Patch 19.0 — Opening Inventory and Phase 18 Residual Rebase — DONE
- [x] Patch 19.1 — Identifier-Spelling Decision Inventory — DONE
- [x] Patch 19.2 — Compiler-Owned Brand Identity Authority — DONE
- [x] Patch 19.3 — Canonical Branded Type Naming Without a Brand Vocabulary — DONE
- [x] Patch 19.4 — Type-Derived Container and Arena Classification — DONE
- [x] Patch 19.5 — Argument and Index Representation From the Type System — DONE
- [x] Patch 19.6 — Self-Hosted Rule Convergence — DONE
- [x] Patch 19.7 — Retired Prototype Absence Contract — DONE
- [x] Patch 19.8 — Name-List Removal From the Self-Hosted Compiler — DONE
- [x] Patch 19.9 — Seed Regeneration and Fixed-Point Convergence — DONE
- [x] Patch 19.10 — Generated-C Equivalence Over the Compiler's Own Sources — DONE
- [x] Patch 19.11 — Cross-Feature Composition and Complete Differential — DONE
- [x] Patch 19.12 — Phase 19 Closure — DONE

## Immutable Phase 18 Completion Record

The Phase 19 opening and closure guards consume this historical record. These rows describe the already-closed parent phase and are not active Phase 19 work.

- [x] Patch 18.0 — Opening Inventory and Phase 17 Residual Rebase — DONE
- [x] Patch 18.1 — Compiler-Owned Target Authority and Declared Target Triples — DONE
- [x] Patch 18.2 — Complete Target Support Tuple and Support Decisions — DONE
- [x] Patch 18.3 — Object Format, Section, and Symbol Binding Authority — DONE
- [x] Patch 18.4 — Relocation Model and Validation — DONE
- [x] Patch 18.5 — Target-Specific ABI Selection — DONE
- [x] Patch 18.6 — Target-Specific Runtime Package Selection — DONE
- [x] Patch 18.7 — Linker Discovery, Selection, and Invocation Policy — DONE
- [x] Patch 18.8 — Static and Dynamic Runtime Linking Modes — DONE
- [x] Patch 18.9 — Cross-Compilation Policy and Host/Target Separation — DONE
- [x] Patch 18.10 — Unsupported-Target Detection and Diagnostics — DONE
- [x] Patch 18.11 — Symbol and Relocation Inspection Evidence — DONE
- [x] Patch 18.12 — Debug Information Strategy — DONE
- [x] Patch 18.13 — Source-Location Preservation — DONE
- [x] Patch 18.14 — Optimisation-Level Policy — DONE
- [x] Patch 18.15 — Reproducible Object and Artifact Output — DONE
- [x] Patch 18.16 — Atomic Executable Publication Under Phase 9G — DONE
- [x] Patch 18.17 — Cross-Target Composition and Complete Per-Target Evidence — DONE
- [x] Patch 18.18 — Deferred Residue and Target-Coverage Audit — DONE
- [x] Patch 18.19 — Phase 18 Closure — DONE

## Immutable Phase 17 Completion Record

The Phase 18 opening and closure guards consume this historical record. These rows describe the already-closed parent phase and are not active Phase 18 work.

- [x] Patch 17.0 — Opening Inventory and Phase 16 Residual Rebase — DONE
- [x] Patch 17.1 — Compiler-Owned Runtime Boundary and Helper Classification Authority — DONE
- [x] Patch 17.2 — Supported Runtime ABI, Symbol Identity, and Versioning — DONE
- [x] Patch 17.3 — Runtime Requirements in Canonical MIR and Native Requests — DONE
- [x] Patch 17.4 — Explicit Runtime Packages and Target-Specific Selection — DONE
- [x] Patch 17.5 — Stable Runtime-Library Imports for Cranelift — DONE
- [x] Patch 17.6 — Rust Runtime Components and Native Object Integration — DONE
- [x] Patch 17.7 — Explicit Retained C Runtime Objects — DONE
- [x] Patch 17.8 — Pure Gust Runtime Modules Compiled Through MIR — DONE
- [x] Patch 17.9 — Generated C Shim Elimination and Obsolete Helper Removal — DONE
- [x] Patch 17.10 — Allocation, String, and Core Memory Runtime Audit — DONE
- [x] Patch 17.11 — I/O, Filesystem, and Resource Runtime Audit — DONE
- [x] Patch 17.12 — Threading and Synchronization Runtime Audit — DONE
- [x] Patch 17.13 — Runtime Availability, Compatibility, and Diagnostic Enforcement — DONE
- [x] Patch 17.14 — Cross-Feature Runtime Composition and Complete Differential — DONE
- [x] Patch 17.15 — Deferred Residue and Runtime-Coverage Audit — DONE
- [x] Patch 17.16 — Phase 17 Closure — DONE

## Immutable Phase 16 Completion Record

The Phase 18 closure guard consumes this historical record transitively. These rows describe the already-closed Phase 16 parent and are not active Phase 18 work.

- [x] Patch 16.0 — Opening Inventory and Phase 15 Residual Rebase — DONE
- [x] Patch 16.1 — Compiler-Owned Function ABI Authority — DONE
- [x] Patch 16.2 — Canonical MIR Signature, Call, and Result Transport — DONE
- [x] Patch 16.3 — Aggregate Parameter Classification and Passing — DONE
- [x] Patch 16.4 — Aggregate Return Classification and Hidden Result Transport — DONE
- [x] Patch 16.5 — Caller/Callee Placement and Direct-Call Agreement — DONE
- [x] Patch 16.6 — Typed Indirect Calls and Function-Value ABI — DONE
- [x] Patch 16.7 — Fat-Pointer and Selected Trait-Object Call ABI — DONE
- [x] Patch 16.8 — Unsized Value Parameter, Return, and Storage Contract — DONE
- [x] Patch 16.9 — Bounded Dynamic Stack Frames and Variable-Sized Storage — DONE
- [x] Patch 16.10 — Resource-Bearing Aggregate Call ABI — DONE
- [x] Patch 16.11 — Selected Cross-Module Aggregate and Resource ABI — DONE
- [x] Patch 16.12 — ABI Metadata and Native Request Validation — DONE
- [x] Patch 16.13 — Cross-Feature ABI Composition and Complete Differential — DONE
- [x] Patch 16.14 — Deferred Residue and ABI-Coverage Audit — DONE
- [x] Patch 16.15 — Phase 16 Closure — DONE

## Immutable Phase 15 Completion Record

The Phase 16 closure guard consumes this historical record transitively. These rows describe the already-closed Phase 15 parent and are not active Phase 18 work.

- [x] Patch 15.0 — Opening Inventory and Phase 14 Residual Rebase — DONE
- [x] Patch 15.1 — Compiler-Owned Resource and Lifetime Authority — DONE
- [x] Patch 15.2 — Resource Values in Canonical MIR — DONE
- [x] Patch 15.3 — Move-State Transitions and Use-After-Move Enforcement — DONE
- [x] Patch 15.4 — Resource Reassignment Semantics — DONE
- [x] Patch 15.5 — Cleanup Insertion at Normal Scope Exits — DONE
- [x] Patch 15.6 — Cleanup at Early Returns and Structured Exits — DONE
- [x] Patch 15.7 — Destructor Scheduling and Exactly-Once Destruction — DONE
- [x] Patch 15.8 — Manual Close Versus Deferred Cleanup — DONE
- [x] Patch 15.9 — Conditional and Loop-Carried Resource States — DONE
- [x] Patch 15.10 — Resource Metadata and Request Validation — DONE
- [x] Patch 15.11 — Directory and Selected Specialized Resource Kinds — DONE
- [x] Patch 15.12 — Panic and Failure Cleanup Policy — DONE
- [x] Patch 15.13 — Cross-Feature Resource Composition and Complete Differential — DONE
- [x] Patch 15.14 — Deferred Residue and Resource-Coverage Audit — DONE
- [x] Patch 15.15 — Phase 15 Closure — DONE

---

## Purpose

Phase 20 turns backend parity from a collection of feature witnesses into a
qualification claim about representative Gust software. It first removes the
six known compiler-owned reasons that the required corpus cannot yet be
expressed faithfully:

- CR-11/#158: explicit Graph annotations use spelling-derived nesting checks,
  reject valid nested brands, and lose the intended type after the diagnostic;
- CR-12/#159: assignment and annotation matching erase exact brand identity, so
  a destination branded for one arena can accept a value from another;
- the Stdlib S1.4 constructor-result gap: a contextual generic constructor can
  typecheck as its declared result while MIR-to-C reconstructs an `_Any`
  aggregate from the constructor spelling;
- CR-13/#160: `Arena.Free` returns `Void` but does not invalidate the live arena
  identity, so later allocation into the freed receiver type-checks;
- CR-5: user-defined linear resources lack source-declared destructor identity,
  general construction opacity, and complete generic scope enforcement; and
- #106: resource obligations begin at a named binding rather than at the
  acquisition expression, so an ignored `os.OpenDir(...)` leaks without a
  diagnostic.

The phase then exercises multi-file programs, existing stdlib and runtime
components, nested and mixed features, generated canonical MIR, large
functions/modules, long-lived processes, and concurrent resource use. For each
supported cohort, MIR-to-C remains the semantic oracle and Cranelift remains an
explicit no-fallback backend.

## Live Starting State

The roadmap was derived from exact `main`
`f9c1cf412f9705519fe78ac8fea174c7e75c3bc2`, not from issue summaries alone.
Focused compiler-backed probes on 2026-08-22 established:

- the CR-11 fixture exits 1 with three `Brand Nesting Restriction` diagnostics
  followed by the secondary `Declared Void` annotation mismatch;
- the CR-12 wrong-brand Clone destination exits 0;
- paired inferred and explicit Stdlib S1.4 witnesses typecheck and emit
  byte-identical MIR-to-C, but host C rejects `std_Channel_Any` returned from a
  helper whose canonical signature is `std_Channel_int`;
- the CR-13 allocation through a freed arena receiver exits 0;
- an ignored `os.OpenDir(...)` acquisition exits 0; and
- the same directory value assigned to a local exits 1 with the existing
  resource-leak diagnostic.

The compiler already has canonical `BrandIdentity` records, but
`env_check_brand_nesting`, `env_is_element_allowed_in_brand`, and portions of
`types_match` still reconstruct identity through stripped type-name strings.
`Arena.Free` has no live-state transition. The Step 5.1 status matrix confirms
that compiler-backed provenance and focused non-laundering coverage are green.
The Step 5.2 matrix confirms real Resource declaration/assignment registration,
move transitions, defer scheduling, cleanup-boundary validation, and directory
parity routing; its own report still classifies generalized lifecycle
enforcement as deferred. Phase 20 extends those paths rather than creating a
second resource system.

## Semantic Decisions Made by This Roadmap

These are Cranelift-lane decisions under `docs/VISION.md` §0.15. They are
recorded here so implementation does not reopen them patch by patch.

### Exact brands

Brand equality and legal nesting compare resolved `BrandIdentity` values.
Canonical printed type names remain diagnostics/code-generation material, not
semantic keys. A failed match preserves both resolved operand types so later
diagnostics cannot convert the expression to an unrelated `Void` mismatch.

### Contextual generic constructors

A generic constructor expression uses an already-resolved, structurally
compatible contextual result type at annotation, assignment, argument, and
return boundaries. That resolved semantic type is the single authority for
MIR-to-C and Cranelift lowering; a backend may not reconstruct a different
`Any` specialization from the constructor spelling. Context does not permit a
cross-template conversion, a brand cast, or a type-specific constructor rule.

### Arena liveness

Arena liveness belongs to the resolved arena identity, not a local spelling.
`Arena.Free` consumes that live identity. Every alias and field path resolving
to it observes the same terminal state. A second free and an allocation, clone,
or write through a freed identity are rejected before backend selection.

### User-declared resources

The additive source surface is:

```gust
#[linear]
#[destructor(close_guard)]
#[opaque]
type Guard {
    token: int,
}

#[private]
func close_guard(value: Guard) Void {
    // synchronous, infallible cleanup
}
```

`#[destructor(name)]` registers one same-module destructor for a linear type.
It must accept exactly one owned value of that type and return `Void`; it cannot
be extern, unsafe, generic over a different resource, asynchronous, or fallible.
`#[opaque]` makes construction and direct representation access module-owned.
`#[private]` makes a declaration callable only from its defining module, except
for the compiler's validated cleanup invocation. These are opt-in module
boundaries, not a default-visibility change and not the full package/application
visibility system described elsewhere.

The syntax lands inert, every compiler-owned in-scope declaration and use is
migrated under that no-op, and only then does enforcement turn on. No patch may
combine those three stages.

### Acquisition and cleanup

A resource obligation begins when a tracking-eligible value is acquired, even
if it is never bound. Binding, assignment, return, aggregate transport, and
payload extraction transfer the same obligation; they do not create an
unrelated one. A discarded temporary must be consumed or scheduled by the end
of its full expression. Lexical automatic cleanup is synchronous and
infallible, runs once in reverse declaration order, and recursively cleans
resource fields in reverse field order. Existing explicit close, move, defer,
return, and failure policies remain authoritative.

## Scope Boundary

Included:

- exact brand nesting/matching and diagnostic type preservation for CR-11;
- exact branded assignment/annotation/call boundaries for CR-12;
- generic contextual constructor results across annotations, assignments,
  arguments, and returns, including the checked S1.4 helper witness;
- identity-keyed arena liveness and `Arena.Free` invalidation for CR-13;
- the inert/migrate/enforce sequence for destructor declaration, type opacity,
  and private cleanup declarations;
- acquisition-time resource identity, generic transfer, lexical scope cleanup,
  and nested resource-field destruction for CR-5/#106;
- representative multi-file, stdlib/runtime, generated-MIR, scale,
  long-lived, concurrent, and cross-feature differential qualification; and
- explicit registry decisions for every selected, deferred, or unsupported
  cohort, with zero unexplained divergence.

Excluded:

- edits to `TASK_STDLIB.md` or implementation of a stdlib-owned patch;
- general lifetime syntax, brand algebra, arbitrary casts, or escape hatches;
- async or fallible implicit destructors;
- default-private modules or package/application visibility tiers;
- a new MIR instruction or a change to existing MIR meaning;
- ABI, layout, runtime-symbol, target, or linker changes not forced by a
  separately registered decision; and
- Phase 21 self-hosting work.

If implementation proves that one of the included behaviours requires an
excluded semantic expansion, register the decision-tree node and follow the
shared-zone authority process. Difficulty or patch size alone is not a stop
condition.

## Validation Model

- Level 1 guards validate source authority, registry/schema consistency,
  diagnostic identity, deterministic fixtures, and absence of fallback.
- Level 2 differentials compile the same canonical MIR through MIR-to-C and
  Cranelift and compare the observables selected by each patch.
- Level 3 remains `Cranelift Historical Full`; it is run separately and is
  required green on exact merged `main` before Phase 20 closure.
- Bootstrap-sensitive patches run `make gust` and the focused semantic tests.
  Patch 20.11 alone owns the generated `gust_v4.c` seed update and proves the
  three-stage fixed point with `make bootstrap`.
- Local validation uses focused guards. The broad historical suite is not a
  substitute for exact-head pull-request CI and is not run locally by default.

Each new guard must be registered at its real test level. Level 1 and selected
Level 2 guards enter normal pull-request workflows. Costly stress, generated
corpus, and long-lived cases remain Level 3 where the registry says so; no
closure text may claim that merely being runnable means they pass.

---

## Patch 20.0 — Opening Evidence and Qualification Authority

**Purpose**

Freeze the verified starting state and define one compiler-owned manifest for
the Phase 20 qualification cohort before changing semantics.

**Steps**

- Add a Phase 20 opening guard and registry/schema rows.
- Encode the five focused starting probes above as stable negative/positive
  evidence without altering their current verdicts.
- Inventory every existing whole-program, composition, deferred-source, and
  Historical Full pair by feature owner and test level.
- Define the qualification-observable vocabulary: compile result, exit status,
  stdout, stderr/diagnostic code and span, resource terminal state, and
  sandboxed filesystem effects.
- Record selected, deferred, and unsupported cohorts with owner, reason, and
  falsifier; no unnamed bucket is permitted.

**Test Level:** Level 1.

**Exit Gate**

The live baseline is reproducible, the qualification cohort is generated from
one authority, and this patch changes no Gust program meaning.

## Patch 20.1 — Canonical Brand-Matching Primitives

**Purpose**

Provide one resolved-identity comparison path before changing CR-11 or CR-12
behaviour.

**Steps**

- Centralize equality, nesting-membership, and mismatch-description operations
  over `BrandIdentity`.
- Route shadow/instrumentation checks through the new operations while leaving
  current acceptance and diagnostics authoritative.
- Prove nested identities, distinct same-shaped arenas, fields, aliases, and
  generic substitutions retain their identity through resolution.
- Freeze the remaining string-cleaning callers so later patches remove rather
  than duplicate them.

**Test Level:** Level 1.

**Exit Gate**

All inputs needed by CR-11 and CR-12 have a canonical identity comparison, and
the patch is behaviour-neutral.

## Patch 20.2 — Nested Brand Annotation Correction (CR-11/#158)

**Purpose**

Make explicit nested Graph annotations use the same resolved brand identities
as inference.

**Steps**

- Replace spelling/stripping decisions in brand nesting with Patch 20.1
  identity operations.
- Preserve the resolved expression and declared types after a primary nesting
  diagnostic; do not synthesize the secondary `Void` mismatch.
- Cover two and three nested brands, explicit and inferred declarations,
  aliases, fields, and a genuinely illegal escape.
- Run the same accepted program through MIR-to-C and Cranelift.

**Test Level:** Levels 1 and 2.

**Exit Gate**

Issue #158's valid explicit Graph annotation compiles with the same meaning as
the inferred form; invalid nesting still fails once with the intended code.

## Patch 20.3 — Exact Branded Assignment and Annotation (CR-12/#159)

**Purpose**

Reject values whose structure matches but whose resolved brand identity does
not.

**Steps**

- Make assignment, annotation, argument, return, and relevant generic matching
  compare exact identities after normal substitution.
- Keep wildcard/unbranded compatibility only where the existing type rule
  explicitly authorizes it.
- Add the wrong-brand Clone destination from #159 plus direct assignment,
  Index, field, alias, and call-boundary variants.
- Do not special-case Clone, Index, Graph, or an individual stdlib type.

**Test Level:** Levels 1 and 2.

**Exit Gate**

The #159 program is rejected by the generic type boundary, same-brand programs
remain accepted, and both backends receive identical canonical MIR.

## Patch 20.3a — Contextual Generic Constructor Result Authority

**Purpose**

Make a generic constructor consume the already-resolved contextual result type
instead of allowing code generation to reconstruct an unrelated `Any`
specialization.

**Steps**

- Carry expected result context generically through annotation, assignment,
  argument, and return expression checking without a Channel-specific branch.
- Accept context only when normal template, payload, and brand compatibility
  holds; do not introduce a cast or relax Patch 20.3 exact-brand boundaries.
- Preserve the resolved constructor result for MIR-to-C lowering so emitted
  expression type, function ABI, and registered aggregate layout agree.
- Add inferred/explicit paired witnesses, including a helper return and at
  least one non-Channel generic constructor control.
- Keep the direct Cranelift source route as an explicit pre-driver deferral with
  no C fallback, and compare supported canonical MIR through both backends.
- Treat the compiler change as bootstrap-sensitive, but leave generated seed
  publication to the isolated Patch 20.11 seed patch.

**Test Level:** Levels 1 and 2 plus `make gust`.

**Exit Gate**

The checked S1.4 helper emits host-compilable MIR-to-C with one canonical
constructor/result type, inferred and explicit forms agree, no individual
stdlib type is special-cased, and backend policy remains explicit.

## Patch 20.4 — Arena Lifecycle State Authority

**Purpose**

Represent arena liveness by canonical identity before rejecting new programs.

**Steps**

- Add live/freed lifecycle state keyed by resolved arena identity.
- Propagate the identity through locals, aliases, fields, parameters, and
  generic substitutions.
- Instrument allocation, clone, write, and free sites against the state while
  preserving current acceptance.
- Prove two distinct arenas and multiple aliases do not collapse into one
  spelling-derived state.

**Test Level:** Level 1.

**Exit Gate**

Every CR-13 operation resolves to one arena identity and lifecycle state, with
no behavioural enforcement yet.

## Patch 20.5 — Arena.Free Receiver Invalidation (CR-13/#160)

**Purpose**

Make `Arena.Free` consume the receiver's live arena identity.

**Steps**

- Transition the Patch 20.4 identity to freed on `Arena.Free`.
- Reject later allocation, Clone destination use, write, and repeated Free
  through any alias or field resolving to that identity.
- Preserve other independently live arenas.
- Emit one stable semantic diagnostic before either backend and add accepted
  and rejected differential fixtures.

**Test Level:** Levels 1 and 2.

**Exit Gate**

Issue #160 is rejected, alias laundering cannot revive the receiver, and the
accepted live-arena cohort remains backend-identical.

## Patch 20.6 — Inert Resource Declaration and Visibility Surface

**Purpose**

Add the source vocabulary required for user resources without changing any
program's permissions or cleanup behaviour.

**Steps**

- Parse and preserve `#[destructor(name)]`, `#[opaque]`, and `#[private]`.
- Store the declarations in AST and type metadata, but deliberately do not
  enforce signature, access, construction, or cleanup rules.
- Add parser round-trip, malformed-attribute, duplicate/conflict, and metadata
  tests.
- Add a guard proving all three attributes are still semantic no-ops in this
  patch.

**Test Level:** Level 1 plus `make gust`.

**Exit Gate**

The checked-in seed can compile the extended self-hosted parser/typechecker,
the new surface is inert, and no enforcement is enabled early.

## Patch 20.7 — Resource Declaration Migration Under the No-op

**Purpose**

Migrate the complete compiler-owned in-scope resource cohort while the new
surface remains inert.

**Steps**

- Annotate compiler-owned linear-resource fixtures with their destructor,
  opacity, and private cleanup declarations.
- Represent the directory parity resource through the same canonical metadata
  bridge while preserving its existing source compatibility and diagnostics.
- Update every compiler-owned construction, field access, explicit close, and
  defer site that enforcement will affect.
- Add an inventory guard proving no in-scope declaration or use remains on an
  unclassified migration path.

**Test Level:** Level 1 plus `make gust` and focused existing Resource guards.

**Exit Gate**

The entire compiler-owned cohort builds under the no-op syntax and behaviour is
unchanged. Enforcement is still off.

## Patch 20.8 — Resource Declaration and Construction Enforcement

**Purpose**

Enable the declaration, destructor-signature, opacity, and private-call rules
only after the migration is complete.

**Steps**

- Validate destructor existence, same-module ownership, exact owned parameter,
  `Void` result, and synchronous/infallible/non-extern status.
- Reject construction or direct representation access to an opaque type outside
  its defining module.
- Reject ordinary calls/references to private declarations outside that module,
  while allowing the compiler's validated cleanup invocation.
- Cover same-module success, cross-module construction/field/call failures,
  forged resource rejection, and backend-neutral diagnostics.

**Test Level:** Levels 1 and 2 plus `make gust`.

**Exit Gate**

A library can expose an acquirer and safe methods without exposing a forgeable
constructor or cleanup primitive, using generic type/module rules.

## Patch 20.9 — Acquisition-Site Resource Obligations (#106)

**Purpose**

Attach linear-resource ownership to acquisition rather than to a later local
binding.

**Steps**

- Allocate a stable expression/resource identity when a tracking-eligible
  acquisition succeeds.
- Transfer that identity through binding, assignment, return, aggregate
  transport, and payload extraction.
- Require an ignored temporary acquisition to be consumed or scheduled by the
  end of its full expression.
- Cover both #106 variants, conditional acquisition, returned resources,
  payloads, aliases, and a non-resource temporary control.
- Use the same path for directory and user-declared resources.

**Test Level:** Levels 1 and 2.

**Exit Gate**

Both bound and unbound leaking acquisitions fail through one generic obligation
path, while valid transfers do not acquire duplicate obligations.

## Patch 20.9a — Obligation Path Join and Callee Ownership Correction

**Purpose**

Correct the two post-merge Patch 20.9 ownership gaps before automatic cleanup
is introduced.

**Steps**

- Join acquisition-obligation terminal state across `if`, `match`, and
  zero-iteration loop paths so one consuming branch cannot discharge another
  reachable path.
- Establish a pending callee obligation for every owned resource parameter,
  while treating the validated destructor itself as the terminal operation.
- Preserve valid all-path consumption, by-value pass-through, return transfer,
  diagnostic deduplication, and backend-neutral rejection.
- Do not insert destructor calls or change cleanup order; those remain Patch
  20.10.

**Test Level:** Levels 1 and 2 plus `make gust`.

**Exit Gate**

A one-branch or loop-only close and an empty by-value callee reject through the
generic acquisition-obligation path, while all-path close and callee return or
consumption remain accepted.

## Patch 20.10 — Generic Scope and Destructor Enforcement (CR-5)

**Purpose**

Complete generic exactly-once resource cleanup across lexical scopes and
resource-bearing aggregates.

**Steps**

- Invoke registered destructors for owned resources on normal scope exit and
  preserve the established return, structured-exit, and failure policies.
- Run cleanup in reverse declaration order and resource-field cleanup in reverse
  field order.
- Preserve explicit close/defer interactions, move terminal states,
  reassignment rules, and diagnostic deduplication.
- Generalize directory parity fully; retain compatibility storage only where a
  guard proves it has no enforcement read.
- Add nested scopes, branches, loops, early returns, aggregates, manual close,
  scheduled cleanup, double close, use-after-move, and constructor-opacity
  composition fixtures through both backends.

**Test Level:** Levels 1 and 2 plus focused Resource suites.

**Exit Gate**

CR-5's compiler prerequisites are available generically: source-declared
destructor identity, non-forgeable construction, acquisition-time ownership,
scope cleanup, and exactly-once destruction all agree through MIR-to-C and
Cranelift.

## Patch 20.11 — Bootstrap Seed Regeneration and Fixed-Point Convergence

**Purpose**

Regenerate the C bootstrap seed after the self-hosted semantic cluster, in an
isolated seed-only patch.

**Steps**

- Start from merged Patch 20.10.
- Run `make bootstrap` and require stage 2 and stage 3 byte identity.
- Commit only the generated `gust_v4.c` change and seed-specific authority.
- Re-run the focused Phase 20 semantic guards with the converged seed.

**Test Level:** Level 1 plus bootstrap convergence.

**Exit Gate**

The seed is generated, not hand-edited; the patch contains no capability
change; and the three-stage compiler is at a fixed point.

## Patch 20.12 — Whole-Program Corpus and Observable Contract

**Purpose**

Define representative programs and a reproducible comparison contract before
claiming whole-program parity.

**Steps**

- Add selected multi-file programs combining modules, generics, brands,
  resources, aggregates, control flow, I/O, and failure diagnostics.
- Capture compile result, process exit status, stdout, stderr/diagnostics,
  resource terminal state, and sandboxed filesystem effects.
- Normalize only explicitly declared environmental noise; never normalize a
  semantic difference.
- Run each selected program from the same canonical MIR through MIR-to-C and
  Cranelift with no fallback.

**Test Level:** Level 2, with costly cases registered Level 3.

**Exit Gate**

The corpus and observable contract are registry-derived, deterministic, and
produce no unexplained difference for the selected initial cohort.

## Patch 20.13 — Stdlib and Runtime Component Differential

**Purpose**

Qualify existing safe library and runtime components as program building blocks
without changing their APIs.

**Steps**

- Select currently implemented collection, string, filesystem, allocation,
  threading/synchronization, and runtime-boundary components whose Cranelift
  routes are declared supported.
- Exercise them across module boundaries and in resource-bearing programs.
- Compare outputs, status, cleanup, filesystem effects, and diagnostics.
- Declare every excluded component with its existing owner/reason/falsifier;
  do not silently shrink the cohort or use C fallback.

**Test Level:** Levels 2 and 3 according to cost.

**Exit Gate**

Every selected component has a whole-program differential, and every excluded
component is an explicit registry decision rather than an unexplained hole.

## Patch 20.14 — Generated-MIR, Scale, and Resource-Use Qualification

**Purpose**

Test canonical MIR combinations and compiler scale beyond hand-written source
fixtures.

**Steps**

- Add a deterministic, dependency-free generator for valid canonical MIR
  combinations within declared feature constraints.
- Compare both backends over a recorded seed set and preserve minimized failing
  cases as fixtures.
- Add large-function and large-module cohorts.
- Record compile time and peak memory with a reproducible measurement protocol,
  baseline, sample count, and explicit threshold policy.

**Test Level:** Level 2 for small deterministic samples; Level 3 for the full
generated and scale cohorts.

**Exit Gate**

The bounded generated set has zero unexplained divergence, stress cases finish
inside their declared resource budgets, and no threshold can drift silently.

## Patch 20.14h — Phase-Frozen Historical Accounting

**Purpose**

Keep the closed Phase 19 self-compilation differential reproducible after
later phases legitimately change compiler sources and regenerate the bootstrap
seed.

**Steps**

- Freeze the final Phase 19 comparison at the registry-named Phase 19.11 seed
  commit instead of repository `HEAD`.
- Continue reconstructing and attributing every Phase 19 compiler-changing
  boundary with the existing full-history fetch requirement.
- Record that Phase 20 and later compiler changes and seeds belong to their own
  phase history and do not retroactively alter Phase 19 evidence.
- Preserve the existing baseline-to-Phase-19 insertion/deletion totals and zero
  unexplained-difference requirement.

**Test Level:** Level 1 for registry/generated contract; Level 3 for the frozen
historical reconstruction.

**Exit Gate**

The Phase 19 Historical Full shard reconstructs the named Phase 19 boundaries,
matches the named Phase 19.11 seed, and remains green when later-phase compiler
sources or seeds differ from that frozen result.

## Patch 20.14a — Generic Guard Prerequisite Corrections

**Purpose**

Correct the two generic frontend defects independently blocking a branded
Resource guard, without choosing or changing the Mutex protected-access API.

**Steps**

- Match a declared Resource destructor's single owned parameter against the
  canonical generic/template type after brand substitution, not against an
  unsubstituted struct-name spelling.
- Preserve the existing non-laundering boundary while carrying safe-reference
  parameter provenance through a same-brand aggregate field assignment and
  return.
- Add positive generic/branded witnesses and negative wrong-type,
  wrong-brand, raw-derived, and sandbox-derived witnesses; prove accepted
  programs retain identical MIR-to-C and supported Cranelift meaning.
- At this patch's historical boundary, keep `Mutex.Lock() -> RawPointer(T)` and
  explicit `Unlock()` unchanged while OD-13 is open. Do not add a Mutex-specific
  destructor exception, raw-pointer
  wrapper, Stdlib API, MIR instruction, ABI/layout change, or runtime symbol.

**Test Level:** Levels 1 and 2.

**Exit Gate**

Generic/branded Resource destructor validation and safe same-brand reference
capture work through canonical type/provenance authority, all unsafe-derived
negative cases remain rejected, and OD-13 remains an explicit shared-zone
block at this patch's historical boundary rather than an implicit API choice.

Because this correction changes the self-hosted typechecker after the earlier
Patch 20.11 fixed point, generated seed publication remains isolated. Patch
20.14b is the required seed-only follow-up; it is not part of this capability
patch.

## Patch 20.14b — Post-Prerequisite Bootstrap Seed Reconvergence

**Purpose**

Restore the checked-in bootstrap fixed point after Patch 20.14a without hiding
generated seed churn inside the semantic correction.

**Steps**

- Start from merged Patch 20.14a and run `make bootstrap`, requiring stage 2 and
  stage 3 byte identity.
- Commit only the generated `gust_v4.c` change and seed-specific authority.
- Re-run the Patch 20.14a Level 1 contract with the converged seed.
- Preserve OD-13 and all compiler, MIR, ABI, layout, runtime-symbol, and Stdlib
  semantics unchanged.

**Test Level:** Level 1 plus bootstrap convergence.

**Exit Gate**

The seed-only diff reaches a three-stage fixed point, accounts for Patch
20.14a, and contains no capability or API change.

## Patch 20.15 — Long-Lived and Concurrent Resource Differential

**Purpose**

Qualify lifecycle semantics where bugs appear only after repetition or across
threads.

**Steps**

- Exercise repeated acquire/transfer/close cycles, nested resource aggregates,
  and bounded long-lived allocation.
- Exercise selected threading and synchronization paths with deterministic
  invariants rather than scheduler-order output.
- Compare exactly-once cleanup, terminal states, exit status, and externally
  visible effects across both backends.
- Keep unsupported concurrency/resource combinations explicit and diagnostic;
  do not weaken them into backend-specific behaviour.

**Test Level:** Level 3, with small deterministic smoke cases at Level 2.

**Exit Gate**

The selected long-lived and concurrent cohort completes without leak,
double-destruction, deadlock, fallback, or unexplained backend divergence.

## Patch 20.16 — Cross-Feature Qualification and Residue Audit

**Purpose**

Compose the full Phase 20 cohort and make every remaining difference explicit.

**Steps**

- Run brand identity/liveness, user resources, modules, stdlib/runtime, scale,
  and concurrency in mixed programs.
- Audit source-to-MIR and canonical-MIR-to-backend registries for stale,
  duplicated, orphaned, or unowned rows.
- Resolve every selected-cohort divergence or register a bounded deferral with
  owner, reason, diagnostic, and falsifier.
- Prove no selected route falls back from Cranelift to generated C.
- Generate the Phase 20 readiness record from its compiler-owned source.

**Test Level:** Levels 1, 2, and the registered Level 3 composition cohort.

**Exit Gate**

All selected pairs pass, all exclusions are explained and owned, there are zero
unexplained divergences, and the generated record says Phase 20 is ready for an
authoritative Historical Full run.

## Patch 20.16a — Mutex Guard Decision and Implementation Authority

**Purpose**

Record the operator's OD-13 decision and establish the smallest generic,
bootstrap-safe implementation sequence without changing compiler behaviour.

**Steps**

- Make `docs/VISION.md` §26.1 normative: safe lock acquisition returns one
  move-only linear guard carrying context-branded protected access and owning
  automatic exactly-once unlock on every scope exit.
- Record that raw-pointer/manual unlock may remain only explicit unsafe or
  compiler-internal machinery and that no separate compiler-owned access token
  is introduced.
- Assign generic resource-rooted access provenance and liveness to Cranelift
  while leaving guard spelling, representation, re-entrancy, and accessor
  ergonomics to Stdlib.
- Update the compiler-owned registry and generated review so the former OD-13
  open state remains identifiable as Patch 20.14a history but cannot be mistaken
  for current authority.

**Test Level:** Level 1 registry/generated contract.

**Exit Gate**

OD-13 is resolved coherently in the decision register, normative section,
shared-zone map, roadmap, registry, and generated review; no compiler, MIR,
ABI, layout, runtime-symbol, bootstrap-seed, or Stdlib behaviour changes.

## Patch 20.16b — Inert Resource-Rooted Access Authority

**Purpose**

Add the generic compiler representation needed to associate protected access
with a live linear Resource guard, while preserving all accepted and rejected
source behaviour.

**Steps**

- Add canonical frontend state and queries for a reference whose access
  authority is rooted in one linear Resource value; do not add a Mutex-specific
  typechecker or backend path.
- Carry the root identity through bindings and guard moves without enforcing a
  new rejection yet. Moving the guard transfers the one identity; close and
  destruction identify its terminal state.
- Add inert positive witnesses and inventory guards proving the new authority
  is recorded but cannot change program meaning in this patch.
- Preserve canonical MIR meaning, MIR-to-C parity, explicit Cranelift
  no-fallback, runtime symbols, ABI, and layout.

**Test Level:** Level 1 contract and Level 2 unchanged-meaning differential.

**Exit Gate**

The self-hosted compiler and seed accept the inert authority, the full selected
source cohort retains its declared observable, and no protected-access
rejection is enabled.

## Patch 20.16c — Explicit-Unsafe Mutex Primitive Migration

**Purpose**

Migrate every existing compiler-owned use of raw Mutex lock/unlock primitives
under the still-inert rule before safe-call enforcement changes.

**Steps**

- Inventory every Gust call to the compiler-owned raw `Lock()` and `Unlock()`
  primitives, including compiler fixtures, bootstrap targets, and tests.
- Place the whole inventory behind the language's existing explicit unsafe
  boundary while safe calls remain temporarily accepted, so this patch is a
  semantic no-op.
- Add an exhaustive migration guard that rejects unclassified raw primitive
  call sites and records which ones are transitional test coverage.
- Do not add the Stdlib guard API or choose its naming, representation,
  re-entrancy, or accessor form.

**Test Level:** Levels 1 and 2 plus bootstrap buildability.

**Exit Gate**

Every compiler-owned raw lock/unlock call site is classified and explicitly
unsafe, all previous observables and backend parity remain unchanged, and the
compiler still builds itself before enforcement is enabled.

## Patch 20.16d — Protected-Access Liveness Enforcement

**Purpose**

Enable the resolved generic safe contract after the inert authority and
whole-tree migration are complete.

**Steps**

- Make a live move-only Resource guard the sole safe authority for its rooted
  context-branded protected access; moving the guard transfers both authority
  and its acquisition obligation.
- Reject access detached from the guard, escape or storage beyond the guard,
  and use after guard move, explicit close, destructor, or any scope exit.
- Require the existing raw Mutex lock/unlock primitives to be called only from
  an explicit unsafe boundary; keep their runtime ABI internal and unchanged.
- Prove automatic cleanup unlocks exactly once on normal, early-return,
  conditional, and failure exits, with positive and negative source tests,
  MIR-to-C tests, and supported Cranelift differential tests.
- Preserve non-laundering, use no separate access token, add no Mutex-specific
  Resource exception, and add no new MIR operation, ABI/layout rule, or runtime
  symbol.
- Publish checked implementation authority and notify the registrar so Stdlib
  S1.8 may re-derive its blocked work without prescribing its API ergonomics.

**Test Level:** Levels 1 and 2, with the registered lifecycle composition at
Level 3.

**Exit Gate**

Safe access is possible exactly while its live guard exists, cannot escape or
survive it, raw/manual access is explicit unsafe only, exactly-once cleanup and
backend parity hold, and the generated handoff says implementation authority
has landed.

## Patch 20.16e — Protected-Access Bootstrap Seed Reconvergence

**Purpose**

Restore the checked-in bootstrap fixed point after the protected-access
compiler changes without hiding generated seed churn in a semantic patch.

**Steps**

- Start from merged Patch 20.16d and run `make bootstrap`, requiring stage 2 and
  stage 3 byte identity.
- Commit only generated `gust_v4.c` and seed-specific authority.
- Re-run the Patch 20.16d Level 1 contract with the converged seed.
- Preserve the resolved contract and all runtime, ABI, layout, MIR, and Stdlib
  boundaries unchanged.

**Test Level:** Level 1 plus bootstrap convergence.

**Exit Gate**

The seed-only diff reaches a three-stage fixed point, accounts for Patch
20.16d, and contains no capability or API change.

## Patch 20.17 — Phase 20 Closure

**Purpose**

Close the phase only after exact merged-main authoritative evidence exists.

**Steps**

- Confirm every Phase 20 Status row is `DONE` and every criterion below is met.
- Confirm all compiler-owned issue scenarios are resolved by focused guards;
  issue/coordination bookkeeping follows its owning lane and is not simulated by
  editing `TASK_STDLIB.md`.
- Run `Cranelift Historical Full` against the exact merged `main` containing
  Patch 20.16e.
- Require the full run to complete successfully, cite run ID, event, exact
  40-character head SHA, and job population, then update the generated closure
  source and artifact coherently.
- Add and pass the Phase 20 closure guard and record terminal lane state.

**Test Level:** Level 1 closure guard plus authoritative Level 3.

**Exit Gate**

The most recent applicable Historical Full run on exact merged `main` is green,
the generated closure record agrees with the terminal record, all review
conversations are resolved, and Phase 20 is closed. A merely available or still
running Level 3 suite does not satisfy this gate.

## Recommended Implementation Order

20.0 evidence/authority
→ 20.1 inert brand primitives
→ 20.2 CR-11
→ 20.3 CR-12
→ 20.3a contextual generic constructor results
→ 20.4 inert arena lifecycle authority
→ 20.5 CR-13
→ 20.6 inert declaration surface
→ 20.7 full no-op migration
→ 20.8 declaration/visibility enforcement
→ 20.9 acquisition identity
→ 20.9a path join and callee ownership correction
→ 20.10 generic cleanup
→ 20.11 seed convergence
→ 20.12 observable corpus
→ 20.13 stdlib/runtime components
→ 20.14 generated MIR and scale
→ 20.14h phase-frozen historical accounting
→ 20.14a generic guard prerequisites
→ 20.14b post-prerequisite seed reconvergence
→ 20.15 long-lived/concurrent resources
→ 20.16 complete qualification
→ 20.16a Mutex guard decision authority
→ 20.16b inert resource-rooted access authority
→ 20.16c explicit-unsafe raw primitive migration
→ 20.16d protected-access liveness enforcement
→ 20.16e protected-access seed reconvergence
→ 20.17 closure.

The no-op boundaries at 20.1/20.2, 20.4/20.5, and especially
20.6/20.7/20.8 are load-bearing. They prevent the self-hosted compiler from
having to understand and enforce a new idiom in the same bootstrap step.

## Phase 20 Success Criteria

Phase 20 succeeds when:

- explicit and inferred nested brand forms have identical meaning;
- wrong-brand assignments, annotations, arguments, and returns are rejected by
  exact resolved identity rather than by callee-specific checks;
- contextual generic constructors retain one resolved type through typechecking,
  MIR-to-C, and supported Cranelift lowering without an `_Any` reconstruction;
- `Arena.Free` invalidates its canonical receiver identity through all aliases;
- user-defined linear resources declare a validated destructor and can keep
  construction, representation, and cleanup authority inside their module;
- resource obligations begin at acquisition and transfer exactly once through
  binding, aggregates, returns, close, defer, and lexical cleanup;
- automatic cleanup is synchronous, infallible, deterministic, reverse-order,
  and backend-identical;
- representative multi-file software and selected existing stdlib/runtime
  components match in outputs, status, diagnostics, resource state, and
  sandboxed filesystem effects;
- generated canonical MIR, large functions/modules, and bounded resource-use
  cohorts pass their declared budgets;
- long-lived and concurrent selected programs have deterministic invariants and
  no leak, double destruction, deadlock, fallback, or unexplained divergence;
- safe Mutex acquisition is represented by one move-only linear guard whose
  live resource identity authorizes context-branded protected access and whose
  cleanup unlocks exactly once on every scope exit;
- protected access cannot detach from, escape, or survive its guard, while raw
  lock/unlock primitives are available only behind an explicit unsafe/internal
  boundary and have identical meaning through both backends;
- every unsupported or deferred cohort is registry-owned with a reason and
  falsifier, and the selected cohort has zero unexplained differences;
- the bootstrap seed is regenerated alone and reaches a three-stage fixed
  point; and
- an authoritative `Cranelift Historical Full` run completes successfully on
  the exact merged Phase 20 head and is cited in both closure and terminal
  records.

Phase 20 does not claim universal language coverage or Phase 21 self-hosting.
It claims that the declared representative cohort is semantically coherent,
fully explained, and differentially qualified.

---

## Immutable Phase 19 Detailed Record

The remaining sections are the detailed record of the closed parent phase.
They are retained because Phase 19 guards consume its exact closure evidence.

## Phase 19 Purpose

Phase 19 makes brand identity and value representation follow from the type
system rather than from how a variable happens to be spelled.

Today the self-hosted compiler carries a hardcoded list of identifier names
treated as arena brands. The generated inventory is authoritative; representative
sites are:

```text
compiler/codegen.gst:658,762,896,1101,1851
compiler/typechecker.gst:159,2279,4975,5172
```

The list serves two distinct purposes, and the phase must separate them before it
can remove either:

**Type-name erasure.** Generated C type names such as
`std_Vector_lib_module__ctx` are reduced to a canonical form by stripping known
brand suffixes. This is canonical type identity expressed through string
surgery on a fixed vocabulary.

**Classification override.** At index and call sites, the compiler derives
`is_slice`, `is_ptr`, `is_vector`, `is_hashmap`, and `is_pool` from the resolved
type and the struct registry — and then `is_arena_override`, computed purely
from the identifier's spelling, forcibly clears all five
(`compiler/codegen.gst:1851-1863`).

That second one is the important discovery. **The type system already computes
the classification; a name check overrules it.** The override exists because the
type-derived path is not trusted in some cases. Making it trustworthy is the
work of this phase; deleting the override is the consequence.

The user-visible defect this produces:

```gust
func probe(s: str) int { return std.str_byte_at(s, 0); }
func main() {
    mut a: str := "PING";      // name is in brand_bases
    os.LogInt(probe(a));       // emits probe(&a) — rejected by cc
}
```

Renaming `a` to `b` fixes the program. Nothing about the type changed.

## Starting State

Verified 2026-08-19. Evidence: `docs/STDLIB_SURFACE_FINDINGS.md`, findings F3,
F3a, F3b.

- The generated `compiler/CRANELIFT_PHASE19_SPELLING_INVENTORY.md` records nine
  live decision sites: five in `compiler/codegen.gst` and four in
  `compiler/typechecker.gst`.
- The former Rust/self-hosted rule divergence was D-2. It closed on 2026-08-21
  when the deprecated Rust prototype was removed; it is historical evidence,
  not a second implementation Phase 19 must preserve or reconcile.
- **The blast radius is the compiler itself.** `compiler/*.gst` contains roughly
  2,312 declarations named `ctx`, `arena`, `a`, or `connCtx`, and roughly 2,183
  `ctx[...]` index sites. Every one is currently classified by name. A
  type-derived replacement must produce identical output for all of them or the
  compiler will not bootstrap.
- `gust_v4.c` encodes the current behaviour. Phase 19 cannot land without a seed
  regeneration.
- A converged seed regeneration was performed 2026-08-19 and is append-only
  relative to the committed seed (1,920 insertions, 0 deletions), confirming the
  bootstrap chain is healthy before this phase begins.

Contracts Phase 19 consumes and must not redefine:

- Phase 14 owns type layout, target layout, and memory-access validation.
- Phase 15 owns resource identity, move state, cleanup, destruction.
- Phase 16 owns signatures, parameter and result placement, and call plans.
  **Argument representation is Phase 16 territory**; Phase 19 makes the compiler
  ask Phase 16 rather than guess from a name.
- Phase 17 owns runtime ABI and symbol identity.
- Phase 18 owns target, object format, relocation, linker, and link mode.
- MIR-to-C remains the default backend and differential oracle.
- Explicit Cranelift selection has no fallback.

## Phase Boundary

Phase 19 may implement:

- a compiler-owned brand identity record derived from resolved types;
- canonical branded type naming that does not depend on a brand-word vocabulary;
- type-derived container and arena classification sufficient to retire the
  spelling override;
- argument and index representation decisions sourced from Phase 16;
- convergence of the self-hosted compiler's spelling consumers on one rule
  before the rule is removed;
- removal of the hardcoded name list from the self-hosted compiler;
- a seed regeneration proving fixed-point convergence under the new rules;
- byte-level generated-C equivalence evidence over the compiler's own sources.

Phase 19 must not silently absorb:

- new lifetime syntax, lifetime relations, or lifetime casts;
- arbitrary brand relationships, brand casts, or brand escape hatches;
- new ABI classification rules — Phase 19 selects, Phase 16 defines;
- new MIR operations, or changed meaning for existing ones;
- resource, drop, or move semantics changes;
- changes to layout or the runtime ABI;
- stdlib API design — that is `TASK_STDLIB.md`;
- renaming variables in `compiler/*.gst` to work around the defect;
- any change that makes the compiler's generated C differ without an explained,
  evidenced reason.

## Compiler-Owned Brand and Representation Authority

- The compiler produces a brand identity record for every branded type: brand
  origin, arena identity, and whether the value denotes an arena.
- Arena-ness is a property of the resolved type. It is never inferred from an
  identifier, a field name, or a substring of a generated expression.
- Canonical branded type identity is produced once by type resolution and
  consumed unchanged by both backends. Neither backend reconstructs branding.
- Container classification is produced from the resolved type and the struct
  registry, with no spelling-derived override.
- Argument representation — by value or by address — is a Phase 16 ABI decision
  recorded in canonical MIR, not a codegen-time string transformation.

## Architectural Invariants

- Renaming a local variable never changes generated code.
- Every self-hosted spelling consumer applies one classification rule until the
  spelling rule is removed.
- No component decides arena-ness, container kind, or argument representation
  from an identifier spelling, a substring, or a generated expression's text.
- Canonical MIR carries the representation decision; codegen consumes it.
- The bootstrap seed compiles the post-change compiler sources, and the compiler
  reaches a three-stage fixed point.
- MIR-to-C remains an independent differential oracle.
- Explicit Cranelift has no fallback.
- No exact-source, fixture-name, or identifier-name recognizer is introduced to
  replace the one being removed.

## Verification Policy

### Level 1 — Fast contracts

Level 1 guards may validate:

- the Phase 18 closure record and Phase 19 opening traceability;
- absence of the brand-name list in each compiler as its removal patch lands;
- absence of any spelling-derived classification override;
- brand identity record schemas;
- canonical branded type identity for paired inferred and explicit programs;
- agreement among the self-hosted compiler's classification consumers;
- representation decisions present in canonical MIR;
- generated projection freshness.

### Level 2 — Focused differential families

Proposed family vocabulary:

- `brand-identity`;
- `branded-type-naming`;
- `container-classification`;
- `argument-representation`;
- `rename-invariance`.

`rename-invariance` is the family that would have caught this defect. For a
fixture, compile it, rename every local to a fresh name, compile again, and
require byte-identical generated C. Add it early — Patch 19.1 — so it is
measuring throughout the phase rather than confirming at the end.

### Level 3 — Historical and complete evidence

Cranelift Historical Full remains the sole Level 3 owner. Phase 19 adds the
compiler-self-compilation differential described in Patch 19.10 to that suite;
it does not create a second historical suite.

## Standard Definition of Done for Every Phase 19 Capability Patch

- The supported source shape is precisely bounded.
- The decision it changes is sourced from a resolved type, never a spelling.
- The self-hosted type authority and both backends agree, and a guard proves it.
- Canonical MIR carries the decision where the decision is semantic.
- Paired programs differing only in variable names produce byte-identical C.
- Paired inferred-type and explicit-type programs produce the same canonical
  type, ABI, layout, and behaviour.
- MIR-to-C output is byte-identical to the pre-patch output, or every difference
  is enumerated with a reason.
- Cranelift behaviour is compared where the feature is in the supported cohort,
  and explicitly deferred where it is not.
- `make bootstrap` reaches a three-stage fixed point.
- The seed is regenerated only by Patch 19.9, never as a side effect.
- Brand misuse is still rejected: wrong arena, moved arena, incompatible region.
- No identifier-, fixture-, or substring-based recognizer was introduced.
- The owning CI family contains focused evidence.
- New guards are assigned to the correct test level.

## Patch Sequence

### Patch 19.0 — Opening Inventory and Phase 18 Residual Rebase

**Purpose**

Establish the exact Phase 19 input from the closed Phase 18 state without
changing behaviour.

**Steps**

- Add a semantic Phase 19 opening snapshot to the canonical registry.
- Preserve parent traceability to Phase 18 migrated and deferred rows.
- Inventory every host assumption reachable from brand resolution, type naming,
  container classification, and argument representation.
- Record CR-2 and D-1 as owned rows, with D-2 retained as historical opening
  evidence until its removal closure is recorded.
- Add `guard-cranelift-phase19-opening-contract`.

**Test Level**

Level 1.

**Exit Gate**

The opening snapshot exists, is registry-derived, and traces to Phase 18
closure. No behaviour changes.

### Patch 19.1 — Identifier-Spelling Decision Inventory

**Purpose**

Enumerate every decision currently made from a spelling, before changing any of
them. Report-only.

**Steps**

- Enumerate each site in the self-hosted compiler, classified as type-name
  erasure or classification override.
- For each, record what type information is available at that point and whether
  it is sufficient.
- Record the historical Rust/self-hosted divergence separately from the live
  self-hosted inventory.
- Count affected declarations and index sites in `compiler/*.gst` so the
  regression surface is a measured number, not an estimate.
- Add the `rename-invariance` Level 2 family and record its current failures as
  the phase's baseline.
- Add `guard-cranelift-phase19-spelling-inventory`.

**Test Level**

Level 1, with a Level 2 family.

**Exit Gate**

A generated inventory names every spelling-derived decision, states whether type
information suffices to replace it, and `rename-invariance` runs with its
current failures recorded as a baseline. No behaviour changes.

### Patch 19.2 — Compiler-Owned Brand Identity Authority

**Purpose**

Give the compiler one authoritative answer to "is this value an arena, and which
one?", derived from the resolved type.

**Steps**

- Add the brand identity record: brand origin, arena identity, arena-ness.
- Populate it during type resolution for every branded type.
- Require public API boundaries to carry explicit brands, per `VISION.md` §26.
- Compare the record against the existing spelling rule on the whole compiler
  source and enumerate every disagreement.
- Change no codegen yet.
- Add `guard-cranelift-phase19-brand-authority-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Every branded type has a brand identity record, and the disagreements between
the record and the spelling rule are enumerated with a reason for each. Behaviour
is unchanged.

### Patch 19.3 — Canonical Branded Type Naming Without a Brand Vocabulary

**Purpose**

Produce canonical branded type names from the brand identity record rather than
by stripping known brand words from a string.

**Steps**

- Replace suffix-stripping with construction from the record.
- Preserve the existing generated names exactly, or enumerate each change.
- Cover the namespaced forms the current code special-cases, such as
  `std_Vector_lib_module__ctx`.
- Require paired inferred and explicit programs to produce the same name.
- Add `guard-cranelift-phase19-type-naming-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Canonical branded type names are constructed from brand identity, not string
surgery, and generated C type names are byte-identical or every change is
enumerated.

### Patch 19.4 — Type-Derived Container and Arena Classification

**Purpose**

Make the type-derived classification correct enough that the spelling override
becomes redundant. This is the load-bearing patch of the phase.

**Steps**

- Establish that `is_slice`, `is_ptr`, `is_vector`, `is_hashmap`, `is_pool`, and
  arena-ness are decided from the resolved type and the struct registry.
- For every case where the override currently changes the answer, determine why
  the type-derived path was wrong and fix the type-derived path.
- Keep the override in place and assert it never fires — a guard that fails if
  the override would have changed a classification.
- Add `guard-cranelift-phase19-classification-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

The spelling override is provably redundant: across the compiler's own sources
and every fixture, it never changes a classification. It is still present, and
still asserted never to fire.

### Patch 19.5 — Argument and Index Representation From the Type System

**Purpose**

Make by-value versus by-address a recorded decision rather than a codegen-time
string edit.

**Steps**

- Source the decision from the Phase 16 ABI authority.
- Record it in canonical MIR.
- Forbid codegen from prepending an address-of to a source expression.
- Cover the failing case directly: a local `str` named `a` passed to a by-value
  `str` parameter must compile and behave identically to one named `b`.
- Add `guard-cranelift-phase19-representation-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Argument and index representation is carried in canonical MIR and consumed by
both backends. `rename-invariance` passes for every fixture in the family.

### Patch 19.6 — Self-Hosted Rule Convergence

**Purpose**

Eliminate disagreement among the self-hosted spelling consumers before removing
the rule.

**Steps**

- Make the self-hosted codegen and typechecker consumers identical, or prove the
  concept is unnecessary at every site.
- Add a guard comparing every consumer against a shared case table, including
  suffix, substring, `->ctx`, and `->a` forms.
- Add `guard-cranelift-phase19-rule-convergence`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

Every live consumer classifies every case in the shared table identically.

### Patch 19.7 — Retired Prototype Absence Contract

**Purpose**

Make the one-compiler repository shape an enforced input to the remaining phase.

**Steps**

- Assert the removed root Rust package and its thirteen prototype compiler
  sources cannot return.
- Explicitly preserve `src/runtime.c`, `src/runtime/*.c`, `src/runtime/rust/`,
  and `compiler/experiments/cranelift/`.
- Require Phase 19 projections and documentation to cite only live compiler
  sources for current semantics.
- Add `guard-cranelift-phase19-retired-prototype-absent`.

**Test Level**

Level 1.

**Exit Gate**

The deprecated prototype cannot silently return, and the active runtime and
Cranelift Rust crates remain explicitly outside the removal boundary.

### Patch 19.8 — Name-List Removal From the Self-Hosted Compiler

**Purpose**

Delete the list from `compiler/*.gst`.

**Steps**

- Remove the list and its consumers, including the substring forms.
- Compile the compiler with the committed seed and require success — this is the
  bootstrap-safety gate.
- Require generated C for the compiler's own sources to be byte-identical to the
  pre-removal output, or enumerate each difference.
- Add `guard-cranelift-phase19-gust-name-list-removed`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

No spelling-derived decision remains in `compiler/*.gst`, the committed seed
still compiles the compiler, and generated C is unchanged or every change is
enumerated.

### Patch 19.9 — Seed Regeneration and Fixed-Point Convergence

**Purpose**

Move the corrected behaviour into the bootstrap seed, in its own commit, per the
Bootstrap seed rule in `AGENTS.md`.

**Steps**

- Run `make bootstrap` and require the three-stage fixed point.
- Commit `gust_v4.c` with no other change in the same commit.
- Record the diff size and confirm every change is explained by Patches 19.3
  through 19.8.
- Add `guard-cranelift-phase19-seed-convergence`.

**Test Level**

Level 1.

**Exit Gate**

`make bootstrap` reports fixed-point convergence, the seed is committed alone,
and its diff is accounted for.

### Patch 19.10 — Generated-C Equivalence Over the Compiler's Own Sources

**Purpose**

Prove the change is safe at the scale that matters: roughly 2,183 index sites in
the compiler itself.

**Steps**

- Compile every `compiler/*.gst` before and after and compare generated C.
- Enumerate every difference with the patch that caused it.
- Require zero unexplained differences.
- Hand this evidence to Cranelift Historical Full as the Level 3 owner.
- Add `guard-cranelift-phase19-self-compilation-differential`.

**Test Level**

Level 3, invoked by Historical Full.

**Exit Gate**

Generated C for the compiler's own sources has no unexplained difference, and
the evidence lives in the Level 3 suite.

### Patch 19.11 — Cross-Feature Composition and Complete Differential

**Purpose**

Prove brands, containers, resources, ABI, and targets still compose.

**Steps**

- Compose branded collections, arena clones, references, resources, and calls in
  one fixture.
- Compare MIR-to-C and explicit Cranelift.
- Confirm Phase 14–18 authorities are unaffected.
- Add `guard-cranelift-phase19-composition-contract`.

**Test Level**

Level 1, with a Level 2 parity family.

**Exit Gate**

The composition fixture behaves identically on both backends, or the Cranelift
half is explicitly deferred.

### Patch 19.12 — Phase 19 Closure

**Purpose**

Close brand identity and value representation.

**Steps**

- Confirm every Status row is `DONE` or explicitly deferred with an owner.
- Confirm no spelling-derived decision remains in the self-hosted compiler.
- Confirm `rename-invariance` passes for every family.
- Remove D-1 from `docs/SHARED_SEMANTIC_ZONE.md` and record the fix; preserve the
  earlier D-2 closure record.
- Mark CR-2 resolved in `TASK_STDLIB.md`, releasing S1.4, S1.5, and S1.6
  specifically from CR-2 while preserving any newer blockers.
- Record the residue.
- Add `guard-cranelift-phase19-close`.

**Test Level**

Level 1.

**Exit Gate**

The repository closure artifacts are complete, CR-2 is resolved, the Stdlib
patches are released specifically from CR-2, and the shared-zone defects are
removed rather than merely documented. Authoritative Historical Full run
**32586399260** passed on exact merged `main`
**a95e40d8f1cd4e6d31212e98105026d38b488c9b**, with **17/17** jobs completed
successfully; Phase 19 is closed.

## Phase 19 Recommended Implementation Order

Patch 19.0 opening inventory
→ 19.1 spelling inventory and the `rename-invariance` baseline
→ 19.2 brand identity authority
→ 19.3 canonical branded type naming
→ 19.4 type-derived classification
→ 19.5 argument and index representation
→ 19.6 self-hosted rule convergence
→ 19.7 retired-prototype absence contract
→ 19.8 self-hosted name-list removal
→ 19.9 seed regeneration
→ 19.10 self-compilation differential
→ 19.11 cross-feature composition
→ 19.12 closure.

19.4 is the load-bearing patch. If the type-derived classification cannot be made
correct without new lifetime or brand machinery, stop there and report — that is
a shared-zone escalation, not a licence to expand the phase.

## Phase 19 Success Criteria

Phase 19 succeeds when:

- Renaming a local variable cannot change generated code.
- Arena-ness follows from the resolved type, never from a spelling.
- Canonical branded type identity is produced once and reconstructed by neither
  backend.
- Container classification is type-derived with no override.
- Argument representation is a Phase 16 decision recorded in canonical MIR.
- The self-hosted type authority and both backends apply the same decided rule,
  and a guard proves it.
- The bootstrap seed reaches a three-stage fixed point under the new rules.
- Generated C for the compiler's own sources has no unexplained difference.
- MIR-to-C remains an independent differential oracle, and Cranelift has no
  fallback.
- CR-2 is resolved and `TASK_STDLIB.md` records S1.4, S1.5, and S1.6 as released
  from CR-2; their current CR-11, CR-12, and CR-13 blockers are preserved.
- D-1 is removed from the shared semantic zone; D-2 remains recorded as closed
  by prototype removal.
- Authoritative Historical Full run **32586399260** passes all **17/17** jobs on
  exact merged `main` **a95e40d8f1cd4e6d31212e98105026d38b488c9b**.

Phase 19 closure does not claim a general lifetime system, a brand algebra, or
any expansion of what brands can express. It claims only that the existing model
is decided by types instead of by names.

## Phase 19 Closure Record

- D-1 fix: identifier spelling is no longer semantic authority. Canonical
  branded identity, arena and container classification, and call argument
  representation follow compiler-owned type records. The defect row is removed
  from `docs/SHARED_SEMANTIC_ZONE.md`; the historical D-2 closure record remains.
- CR-2 release: the compiler prerequisite is resolved, and the Stdlib-owned
  roadmap records S1.4, S1.5, and S1.6 as released specifically from CR-2.
  S1.4 remains blocked by CR-11, S1.5 remains blocked by CR-12 and CR-13, and
  S1.6 has been delivered.
- Rename invariance is registered across brand identity, canonical type naming,
  type-derived classification, argument representation, and name-list removal.
  The broad brand-identity pair remains Level 3 evidence owned by Cranelift
  Historical Full.
- Residue: explicit Cranelift lowering of the generic-source composition fixture
  remains owned by `phase13_generic_source_to_mir`, deferred before driver
  discovery with reason
  `deferred_p13_parameter_argument_target_dependent_abi`. There is no C fallback.
- Phase 19 adds no lifetime syntax, brand algebra, MIR operation, ABI or layout
  meaning, runtime symbol, target policy, linker policy, or backend-specific
  semantics.
- The authoritative closure gate is satisfied: Historical Full run
  **32586399260**, event `workflow_dispatch`, completed `success` on exact merged
  `main` **a95e40d8f1cd4e6d31212e98105026d38b488c9b**, with **17/17** successful
  jobs. The matching terminal state is recorded in `GUST_LANE_STATE.md`.
