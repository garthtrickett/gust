# Compiler architecture consolidation roadmap

**Status:** operator direction recorded; Phases 24, 24.5 and 25 remain inactive.

This document records the structural-debt sequence selected after the
thermo-nuclear code-quality review. It supplements `docs/ROADMAP_TAIL.md` without
changing or activating that file's phase authority. When a phase opens, its
active `TASK.md` owns exact patch boundaries and evidence.

The ordering rule is:

> Correct hidden behaviour first, delete the retiring backend second,
> consolidate the compiler that remains third, and only then begin native
> bootstrap work.

That order avoids polishing machinery Phase 24 will remove and avoids placing a
new bootstrap chain on top of known state-management and module-boundary debt.

---

## Phase 24 opening preflight — make compiler meaning explicit

Complete one narrow preflight before backend retirement:

- replace typechecker behaviour selected by source filename fragments such as
  `test_tcs_` and `test_index_` with an explicit compiler-owned mode where a
  compatibility fixture genuinely needs one, or with one canonical rule where
  it does not;
- add characterization tests that freeze the accepted and rejected behaviour on
  both sides of the current filename-selected branches before replacing them;
- inventory concrete stdlib and runtime names recognized directly by compiler
  code, classifying each occurrence by semantic role and eventual intrinsic
  owner; and
- avoid broader typechecker, native-driver, registry or CI restructuring in the
  preflight.

The invariant is simple: changing a source file's name must not change what the
program means.

**Exit gate:** no accepted or rejected Gust meaning depends on a test filename
substring, current behaviour is characterized explicitly, the string-recognized
intrinsic inventory is complete, and no broader architecture change has been
folded into the correction.

## Phase 24 — delete before restructuring

Retire the legacy compatibility backend and its obsolete production routes,
guards, registry rows, commands and workflows. Preserve historical fixtures only
where they still carry useful behaviour evidence.

Deletion is an architectural operation here. Phase 24 should reveal the smaller
compiler and evidence topology that actually remains rather than refactoring
components scheduled for removal.

**Exit gate:** the retired backend has no active build, test, package or release
route, and every surviving evidence owner protects a still-live invariant.

## Phase 24.5 — bounded compiler consolidation

**Purpose:** make the reduced native compiler easier to reason about before its
bootstrap chain depends on that structure.

This is a behaviour-preserving consolidation phase, not an open-ended rewrite
and not a feature phase. Work in dependency order:

1. assign compiler-owned semantic or intrinsic IDs during resolution and make
   later stages dispatch on those IDs rather than concrete stdlib or runtime
   spellings;
2. replace manual save-and-restore of function-checking state with one atomic
   `FunctionCheckFrame` boundary;
3. split `TypeEnvironment` into focused subcontexts with explicit ownership and
   narrow interfaces;
4. decompose expression and statement checking along semantic seams while
   preserving characterized behaviour;
5. split the native command monolith into domain modules behind a typed command
   registry, keeping production lowering separate from historical evidence
   commands;
6. express historical registry contracts as declarative phase specifications
   consumed by generic validation and projection machinery; and
7. consolidate CI setup and generate thin workflow wrappers only after obsolete
   workflows have disappeared, preserving every still-required evidence identity
   and independent gate.

The phase may reorganize ownership and representation of existing compiler
facts. It may not introduce new Gust semantics, canonical intermediate meaning,
ABI or layout, runtime symbols, stdlib API, backend fallback, weaker evidence or
repository-rule exceptions. Each slice must remain bootstrap-safe and
independently reviewable.

**Exit gate:** the surviving compiler has explicit intrinsic identity and
function-checking state boundaries, focused typechecking and command modules,
declarative registry validation, and non-duplicative CI orchestration; the full
required evidence remains green and the self-hosted compiler still converges.

## Phase 25 — native bootstrap after stability

Phase 25 begins only after the reduced compiler has completed Phase 24.5 and has
a stable, fully evidenced structure. Native-bootstrap work must not become the
mechanism by which consolidation is attempted.

The critical path is therefore:

```text
Phase 24 opening preflight
  → Phase 24 backend retirement
    → Phase 24.5 compiler consolidation
      → Phase 25 native bootstrap
```

This record changes no current phase status. It makes the predecessor relation
explicit so a future active roadmap cannot silently skip the consolidation gate.
