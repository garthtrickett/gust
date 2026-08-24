# Shared Semantic Zone

Two lanes work in parallel: Cranelift (`TASK.md`) and Stdlib (`TASK_STDLIB.md`).
This document lists the concepts neither lane may change unilaterally, names the
document or registry that owns each one, and defines what to do when a task
requires one.

It exists because "stop and coordinate" is unenforceable if an agent cannot tell
which zone a change lands in. Everything below is in the zone. Everything not
below is ordinary lane work.

## The invariant this protects

```
source
  → frontend / typechecker
    → canonical semantics
      → canonical MIR
        → backend  ├─ MIR-to-C
                   └─ Cranelift
```

Backends consume decided semantics. A backend must never independently
reconstruct arena brands, ownership, resource state, lifetime rules, mutation
legality, or type identity. No feature may mean one thing through MIR-to-C and
another through Cranelift.

## The zone

| Concept | Authority | Default owner | Evidence |
| --- | --- | --- | --- |
| Type representation and canonical type identity | `TASK.md` Phase 14 record; `compiler/typechecker.gst` | Cranelift | `TASK.md` Starting State |
| Aggregate layout | Phase 14 layout authority | Cranelift | `compiler/CRANELIFT_PHASE14_LAYOUT_AUTHORITY.md` |
| Arena and brand semantics | `GEMINI.md` §A–§B; Phase 14 | Cranelift | `TASK.md` Phase 19 closure record |
| Argument representation (by value vs by address) | Phase 16 ABI authority | Cranelift | `TASK.md` Phase 16 record and Phase 19.5 |
| Resource ownership and identity | Phase 15 authority; `STEP52_RESOURCE_SEMANTICS.md`; `VISION.md` §28 | Cranelift | `TASK.md` "Immutable Phase 15 Completion Record"; see **D-4** |
| Scope-exit and drop semantics | Phase 15; `VISION.md` §29 | Cranelift | `VISION.md` §29 |
| Move semantics | Phase 15 (Patch 15.3 move state) | Cranelift | `TASK.md` "Immutable Phase 15 Completion Record", Patch 15.3 |
| New MIR operations | `compiler/mir.gst`; Phase 13–18 records | Cranelift | — |
| Meaning of an existing MIR operation | same | Cranelift | — |
| ABI representation | Phase 16 authority | Cranelift | `TASK.md` Phase 16 record |
| Native runtime ABI, runtime symbol identity and version | Phase 17 authority | Cranelift | `scripts/cranelift_feature_registry.json` |
| The `std_*` runtime symbol surface | Phase 17 helper inventory | Cranelift adds the row; Stdlib proposes — see the three-step protocol at `TASK_STDLIB.md` CR-4 | `scripts/cranelift_feature_registry.json` Phase 17 helper rows |
| Native-boundary metadata | Phase 17; Phase 18 request validation | Cranelift | `TASK.md` Request and MIR Ownership |
| Pointer and provenance semantics | `STEP51_DEFERRED_UNSAFE_SEMANTICS.md`; `README.md` two-backends rationale | Cranelift | `README.md:47` |
| Tenant-scoped typed-query obligations and trusted `Scope` provenance | `VISION.md` §56.2; `TASK.md` Phase 21 | Cranelift | OD-8 is `DESIGN SET / EVIDENCE OPEN`; Phase 21 Patches 21.2–21.7 |
| Operator semantics | `VISION.md` §16 | Cranelift | `VISION.md` §16 — "the operator set is compiler-owned" |
| Fiber scheduling contract | `src/runtime/fiber.c`; `VISION.md` §20–§21 | Cranelift | — |
| Mutex and synchronization runtime contract | Phase 17.12 thread runtime audit | Cranelift | `TASK.md` "Immutable Phase 17 Completion Record", Patch 17.12 |
| Mutex protected-access semantics | `VISION.md` §26.1; `phase20_protected_access_liveness` registry authority | Cranelift owns the generic semantic floor; Stdlib owns API ergonomics after the checked handoff | `TASK.md` Patches 20.16a–20.16e; see **D-4** |
| Target, object format, relocation, linker, link mode | Phase 18 authority | Cranelift | `TASK.md` Phase Boundary |
| Differential oracle status of MIR-to-C | `AGENTS.md`; every phase's Success Criteria | Cranelift | `AGENTS.md` Repository rules |
| Explicit-Cranelift no-fallback | same | Cranelift | same |
| The bootstrap seed (`gust_v4.c`) and fixed-point convergence | `AGENTS.md` "Bootstrap seed"; `README.md` "The Non-Rust Bootstrap Chain" | Cranelift | `make bootstrap` asserts stage 2 and stage 3 byte-identical |

**OD-8's shared-zone boundary is deliberately narrow.** The operator selected
the §56.2 provenance model on 2026-08-24, but the thesis-invalidating soundness
verdict remains evidence-open. A scoped entity creates a compile-time obligation
that only matching, non-forgeable typed Scope provenance from the trusted
request boundary may discharge. Every scoped join root and nested query owns its
own obligation; deliberate cross-tenant access is explicit, capability-gated,
and visible at the call site; rejection occurs at the query. This authority
covers only the compiler-owned typed-query path. Caches, non-query reads,
multi-step flows, unsafe/raw SQL, and establishment of trusted request context
remain outside its guarantee. `TASK.md` Phase 21 owns implementation and the
predefined adversarial verdict gate.

**The seed is a serialized resource, not merely a shared one.** Any lane may *run*
`make bootstrap` to validate its own change — that is ordinary validation and needs
no coordination. **Regenerating and committing the seed is the Cranelift lane's**,
in its own commit and pull request per `AGENTS.md`, because there is no meaningful
merge of two bootstrapped compilers: a second regeneration in flight does not
conflict textually, it silently supersedes.

A lane whose patch requires a regeneration stops and reports it as item 7 of the
seven-point format, and continues down the ladder rather than regenerating itself.

## Not in the zone

To keep the zone credible, these are ordinary Stdlib-lane work and need no
coordination:

- adding tests, compile-fail fixtures, and examples;
- documentation, including corrections to `GEMINI.md` guidance the lane's own
  patch invalidates;
- a safe wrapper composed only from already-public, already-registered
  primitives;
- a diagnostic that **rejects** a program the compiler currently miscompiles,
  provided no accepted program changes meaning;
- method resolution changes that provably produce the identical canonical type
  and canonical MIR as an already-supported spelling.

The last two are the narrow ones. If a "resolution-only" change turns out to
alter canonical MIR, it was in the zone all along — stop at that point, do not
finish it.

## Stop-and-report protocol

When a task requires a zone change: stop the task. Do not route around it, and do
not implement a narrower version of it inside one lane. Report:

1. intended user behaviour;
2. the existing limitation;
3. the smallest generic semantic change required;
4. files and layers affected;
5. whether it affects MIR-to-C;
6. whether it affects Cranelift;
7. whether it affects bootstrap.

Then wait for an ownership decision. Default owner: a semantic, compiler, or MIR
change belongs to Cranelift; a pure library or API change belongs to Stdlib.

Prefer the smallest generic semantic improvement. Never a special case for one
library type.

### Worked example — accepted as Stdlib work

> "`&HashMap` cannot call `Get` because method receiver resolution does not
> normalize a valid reference receiver."

If the fix is purely frontend resolution and yields the identical canonical type
and canonical MIR as the value-receiver form, the Stdlib lane may own it. It must
prove the identity, not assume it.

### Worked example — refused, escalated

> "`MutexGuard` cannot be implemented because scope-exit does not support this
> resource form."

Stop. The generic resource-semantic change lands in the Cranelift lane first.
The Stdlib lane resumes `MutexGuard` afterwards. No Mutex-specific compiler
support, ever.

## Open zone defects

Known, verified breaches of the invariant. Evidence and reproductions:
`docs/STDLIB_SURFACE_FINDINGS.md`.

### D-3 — `str ==` has no defined meaning — **miscompile closed 2026-08-19, semantics still open**

Originally: accepted by the typechecker and lowered to `==` over two
`Slice_unsigned_char` structs, which is not valid C, so the failure surfaced
from the host C compiler against generated code rather than from Gust against
the user's source.

**The miscompile is closed.** Patch S1.1 (#74) made the self-hosted compiler
reject `==` and `!=` when either operand is `str`, with a stable message naming
`std.str_eq`. `guard-stdlib-s1-str-equality-diagnostic` pins that frontend
diagnostic; both backends consume the same accepted source semantics.

**The row stays open** because rejecting an operator is not deciding what it
means. `VISION.md` §16 makes the operator set compiler-owned, so defining `==`
on `str` as content equality remains zone work, tracked as `TASK_STDLIB.md`
CR-1. Until it lands, `std.str_eq(a, b)` is the only spelling.

### D-4 — Resource and provenance semantics remain incomplete for generic branded guards

`STEP52_RESOURCE_SEMANTICS.md` items 2 and 6 in its "Verified state" table —
resource representation (originally "automatic resource lifecycle enforcement")
and `defer` semantics (originally "an AST/typechecker representation for
`defer`") — were recorded as unmet, when that document predated Phase 15's
closure. `VISION.md` §27 marks shared ownership open as OD-3.

> **Citation corrected 2026-08-20.** This row cited those items as "lines 20–27"
> and stated the document was "last modified 2026-06-28". Both were true when
> written and both are now false: `STEP52_RESOURCE_SEMANTICS.md` gained a
> "Verified state" section at its head in #87 (`15334657`) and a
> cleanup-validation correction in #98 (`017fec42`), so items 2 and 6 now sit at
> lines 15 and 19 and the file's last modification is 2026-08-20 (`2cd40718`,
> #97). The row now cites the table by name rather than by line, per this
> document's own rule against line numbers in a document that is still being
> edited.
>
> Recorded rather than silently fixed because of how it survived: the line
> citation was inherited, carried through an edit to this very row that added the
> #87 re-verification below, and not re-checked at that point. That is precisely
> the failure the "Citing evidence" section names — *confirm a citation before
> copying it, not only before acting on it* — committed in the row that documents
> the defect it describes.
>
> **Both descriptions of items 2 and 6 are kept, 2026-08-20.** #97 and this
> lane's audit named the same two items differently — #97 from the original
> requirement text, this row from the "Verified state" table that superseded it.
> Neither was wrong and the conflict was wording, not substance. Keeping both
> spellings costs one clause and means a reader arriving from either document
> recognises the row.

**Re-verified 2026-08-19 by Patch S1.7 (#87), and corrected again 2026-08-20.**
Item 6 is superseded: `defer` is an AST node the typechecker handles. Item 2's
generic `Resource[ctx, T]` representation has *not* been re-verified and stays
open.

Enforcement is not absent, and it is not one mechanism. The `Resource[T]`
scope-exit validator does run on the real typechecking path, but keys on the
compiler-owned `Resource` generic, so a directory handle falls outside it. A
*separate* directory-specific predicate enforces directory handles: an unclosed
one bound to a local is rejected, verified by compiling and running it. Two
audits each found one half. The remaining gap is that no user type can declare a
destructor, so no user-defined resource carries any obligation — stated in full
as `TASK_STDLIB.md` CR-5 and pinned by
`guard-stdlib-s1-resource-prerequisites`. The obligation is also keyed to the
*binding* rather than the acquisition (issue #106).

One part of the row has since been decided by implementation rather than by
decision: OD-3 is still marked open in `VISION.md` §27 while `std.Rc`,
`std.RcNew`, and `std.RcNode` already ship. Tracked as `TASK_STDLIB.md` CR-9.

> **Phase 20 correction, 2026-08-24.** The historical limitation above is no
> longer current in full. Patches 20.6–20.10 added source-declared destructor
> identity, construction opacity/private cleanup authority, acquisition-site
> obligations, transfer joins, and automatic generic scope cleanup. A preserved
> S1.8 probe then exposed two narrower compiler defects: the declaration
> validator compares a branded generic destructor parameter's monomorphized
> struct name with the unsubstituted template name, and non-laundering
> provenance misclassifies a direct safe same-brand reference parameter when it
> is stored in a same-brand aggregate field. Patch 20.14a owns those generic
> corrections. They do not authorize a Mutex-specific exception.
>
> The third probe result required a decision rather than a local wrapper. OD-13
> was resolved by the operator on 2026-08-24: safe acquisition returns one
> move-only linear guard that both owns automatic exactly-once unlock and is the
> authority for context-branded protected access while live. Raw-pointer/manual
> unlock may remain only behind an explicit unsafe or compiler-internal
> boundary, and there is no separate compiler-owned access token.
>
> Patch 20.16d implements the remaining generic compiler floor as the registry's
> `phase20_protected_access_liveness` authority: resource-rooted access cannot
> detach from, escape, or survive the guard that authorizes it, raw Mutex
> primitives require explicit unsafe, and automatic lifecycle cleanup is checked
> across the selected exit forms. Its generated handoff permits the registrar
> to resume Stdlib S1.8. Patch 20.16e completed the isolated seed reconvergence,
> and Phase 20 closed only after the exact merged-seed Historical Full passed.
> No patch may add a Mutex-specific
> Resource exception or choose the Stdlib spelling, representation, re-entrancy,
> or accessor ergonomics.

The original entry cited line numbers in a living document, which this file
forbids elsewhere; it now cites the item.

### D-5 — String bounds failures terminate the process

`std_str_slice` and `std_str_byte_at` call `exit(1)` on out-of-range input
(`src/runtime/strings.c:16,27`). `VISION.md` §34 requires a panic to terminate
the request, task, or job — not the deployment.

Still open, confirmed 2026-08-20 at `b47d0049` (`src/runtime/strings.c:20,30`).
Stated as `TASK_STDLIB.md` CR-3 and filed as issue #91. No phase has scheduled
it.


## Citing evidence

Source citations in this document are `path:line` pinned to the commit that
introduced them. They drift as the code moves; treat them as a starting point and
confirm the construct still exists before acting on it. An open defect's
citations are only guaranteed correct until that defect is fixed, at which point
the row is deleted.

Never cite a line number in a living document — `TASK.md`, `TASK_STDLIB.md`,
`docs/VISION.md`, `AGENTS.md`. Their Status lists and section bodies grow with
every patch, so a line reference silently becomes a reference to something else.
Cite the section heading or the numbered section instead.

### Two rules learned the hard way

Both were derived from defects found in this repository's own documents, and
both cost real rework. They generalise the paragraph above rather than repeating
it.

**Confirm a citation before *copying* it, not only before acting on it.** The
rule above says to confirm a construct still exists before acting on a citation.
That is necessary and not sufficient. The former brand-identity defect's
`compiler/typechecker.gst` line numbers were copied from
`docs/STDLIB_SURFACE_FINDINGS.md` — correct when pinned at `6c94728d` — into this
document and two others. By 2026-08-20 both lines had moved to unrelated code,
and every document agreed with every other document, which is precisely why
nobody noticed. A citation inherited from another document is not evidence; it
is a claim about evidence, and it decays at the same rate as the code.

**Read the block, not the matching line.** A `grep` hit tells you a word appears,
not what the code does. Four separate claims in this repository's documents were
wrong this way: `typechecker.gst:1962` was described as a formatting check when
it computes a provenance set; `typechecker_log_trace`'s 40 call sites were
described as an emitter substrate when they carry only prose; a proposal was
described as having no prerequisite when field reads defeated it; and
`codegen.gst:1382` was cited for the `Int` lowering when it is the `Index`
lowering. In each case the grep was accurate and the conclusion was not.

## Maintenance

### Closed defect record

- **D-2 — Rust/self-hosted brand-rule divergence — closed 2026-08-21.** PR #137
  removed the deprecated root Rust prototype compiler (merge
  `7e82494c8eeeca772530ba2eae699fbed978d87f`). With one compiler frontend there
  is no second matching implementation and therefore no cross-compiler
  divergence.

- **D-6 — Generic brand arguments lacked declaration-level role metadata —
  closed by Phase 19.8 on 2026-08-21.** Struct and enum templates now record a
  `brand_parameter_index`; built-ins declare it explicitly and user templates
  infer it structurally from field and variant-payload use. Resolution and
  monomorphization consume that role through existing AST brand metadata. No
  syntax, MIR, layout, ABI, runtime symbol, or backend-specific rule changed.

A row is added here when a change is found to have two owners, or none. A row is
removed only when the concept genuinely leaves the shared surface — not because a
lane found it inconvenient.

Open defects are removed when fixed, and their fix is recorded in the owning
phase's roadmap.

A defect that is *partly* fixed is narrowed in place rather than deleted, and the
narrowing states what closed, what remains, and the evidence for each. D-3 is the
worked example: the miscompile closed and the semantic question did not, and
deleting the row would have lost the half that is still true.
