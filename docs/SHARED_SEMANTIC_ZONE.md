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
| Type representation and canonical type identity | `TASK.md` Phase 14 record; `src/typechecker/types.rs` | Cranelift | `TASK.md` Starting State |
| Aggregate layout | Phase 14 layout authority | Cranelift | `compiler/CRANELIFT_PHASE14_LAYOUT_AUTHORITY.md` |
| Arena and brand semantics | `GEMINI.md` §A–§B; Phase 14 | Cranelift | see **Open defect D-1** |
| Argument representation (by value vs by address) | Phase 16 ABI authority | Cranelift | `TASK.md` Phase 16 record; see **D-1** |
| Resource ownership and identity | Phase 15 authority; `STEP52_RESOURCE_SEMANTICS.md`; `VISION.md` §28 | Cranelift | `TASK.md` "Immutable Phase 15 Completion Record"; see **D-4** |
| Scope-exit and drop semantics | Phase 15; `VISION.md` §29 | Cranelift | `VISION.md` §29 |
| Move semantics | Phase 15 (Patch 15.3 move state) | Cranelift | `TASK.md` "Immutable Phase 15 Completion Record", Patch 15.3 |
| New MIR operations | `compiler/mir.gst`; Phase 13–18 records | Cranelift | — |
| Meaning of an existing MIR operation | same | Cranelift | — |
| ABI representation | Phase 16 authority | Cranelift | `TASK.md` Phase 16 record |
| Native runtime ABI, runtime symbol identity and version | Phase 17 authority | Cranelift | `scripts/cranelift_feature_registry.json` |
| The `std_*` runtime symbol surface | Phase 17 helper inventory | Cranelift adds the row; Stdlib proposes — see the three-step protocol at `TASK_STDLIB.md` CR-4 | `src/typechecker/visitor.rs:1017` maps `std.` → `std_` |
| Native-boundary metadata | Phase 17; Phase 18 request validation | Cranelift | `TASK.md` Request and MIR Ownership |
| Pointer and provenance semantics | `STEP51_DEFERRED_UNSAFE_SEMANTICS.md`; `README.md` two-backends rationale | Cranelift | `README.md:47` |
| Operator semantics | `VISION.md` §16 | Cranelift | `VISION.md` §16 — "the operator set is compiler-owned" |
| Fiber scheduling contract | `src/runtime/fiber.c`; `VISION.md` §20–§21 | Cranelift | — |
| Mutex and synchronization runtime contract | Phase 17.12 thread runtime audit | Cranelift | `TASK.md` "Immutable Phase 17 Completion Record", Patch 17.12 |
| Target, object format, relocation, linker, link mode | Phase 18 authority | Cranelift | `TASK.md` Phase Boundary |
| Differential oracle status of MIR-to-C | `AGENTS.md`; every phase's Success Criteria | Cranelift | `AGENTS.md` Repository rules |
| Explicit-Cranelift no-fallback | same | Cranelift | same |

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

### D-1 — Brand identity is inferred from identifier spelling

**Owner: Phase 19** (decided 2026-08-19). A narrow phase covering brand and
argument representation and nothing else. Not Phase 18, whose boundary is
targets, objects, and linkers; not a Stdlib patch, because it changes both
compilers and requires a seed regeneration.


Both compilers hardcode
`["connCtx", "arena", "ctx", "Any", "a", "main_ctx", "bg_ctx", "file_ctx"]`
as arena brand names and prepend `&` at call sites for any matching identifier,
regardless of type. `src/codegen.rs:71`, `src/typechecker/types.rs:61`, and
seven other sites; also `compiler/codegen.gst:658,896,1101,1851` and
`compiler/typechecker.gst:4953,5151`.

A local `str` named `a` is emitted as `&a` and fails to compile in C. Renaming it
fixes the program.

### D-2 — The two compilers disagree on the matching rule for D-1

Rust uses `ends_with(".a")` (`src/codegen.rs:1766`); the self-hosted compiler
uses a substring search (`compiler/codegen.gst:1854`). The same source can be
classified differently by the two compilers. This is a semantics divergence
inside the bootstrap chain.

### D-3 — `str ==` has no defined meaning — **miscompile closed 2026-08-19, semantics still open**

Originally: accepted by the typechecker and lowered to `==` over two
`Slice_unsigned_char` structs, which is not valid C, so the failure surfaced
from the host C compiler against generated code rather than from Gust against
the user's source.

**The miscompile is closed.** Patch S1.1 (#74) made both compilers reject `==`
and `!=` when either operand is `str`, with a byte-identical message naming
`std.str_eq`. Verified 2026-08-20 at `b47d0049`: the string is present in
`src/typechecker/visitor.rs` and `compiler/typechecker.gst`, and
`guard-stdlib-s1-str-equality-diagnostic` asserts both, precisely so the two
backends cannot drift into different explanations of the same program.

**The row stays open** because rejecting an operator is not deciding what it
means. `VISION.md` §16 makes the operator set compiler-owned, so defining `==`
on `str` as content equality remains zone work, tracked as `TASK_STDLIB.md`
CR-1. Until it lands, `std.str_eq(a, b)` is the only spelling.

### D-4 — Resource obligations cannot attach to a user type

`STEP52_RESOURCE_SEMANTICS.md` items 2 and 6 — automatic resource lifecycle
enforcement, and an AST/typechecker representation for `defer` — were recorded as
unmet. That document predates Phase 15 closure. `VISION.md` §27 marks shared
ownership open as OD-3.

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

## Maintenance

A row is added here when a change is found to have two owners, or none. A row is
removed only when the concept genuinely leaves the shared surface — not because a
lane found it inconvenient.

Open defects are removed when fixed, and their fix is recorded in the owning
phase's roadmap.

A defect that is *partly* fixed is narrowed in place rather than deleted, and the
narrowing states what closed, what remains, and the evidence for each. D-3 is the
worked example: the miscompile closed and the semantic question did not, and
deleting the row would have lost the half that is still true.
