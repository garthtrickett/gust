# Executable language claims in Phase 26

A generator using a documented ownership rule needs a working example, the
reason a near miss fails, and the boundary of the guarantee. Start with one
resource-cleanup pair and use existing qualification receipts to describe
what it establishes. These are planned additions. The compiler owner schedules
compiler work in its roadmap. The existing Phase 26 exit gates and the OD-23
decision keep their own authority. [Gust vision §0.1](VISION.md#01-thesis) ·
[Phase 26 sequencing](PHASES_26_AND_27.md#execution-order)

The comparison is a source review of Matthew Berger's Frost at
`35e5868` against Gust at `1717c32`. The examples below specify Gust's
own behavior and acceptance criteria. [Frost revision](https://github.com/matthewjberger/frost/tree/35e5868b08d192e45e8db606538b4b7357ffc1b4) ·
[Gust review baseline](https://github.com/garthtrickett/gust/tree/1717c32fa34ed10a9024523f4f1915542856167f)

## Shipped examples

Docs/vision owns the published example and its status. For the Phase 26.2
pilot, Cranelift owns the reader's compiler invocation and diagnostic oracle.
Read the fenced source from Markdown. Distinguish a standalone program, a
fragment compiled in a specified wrapper, an expected frontend refusal, and a
design sketch. Include the wrapper and imports when reporting the tested
input. List sketches separately so the count of tested examples is auditable.
[Frost book test](https://github.com/matthewjberger/frost/blob/35e5868b08d192e45e8db606538b4b7357ffc1b4/tests/doctests.rs)

Start with the two blocks below. Compile the valid one and check its
existing native output. Compare the invalid one's complete diagnostic sequence
with the established expectation, including any frozen text. A second error
must fail even when the first error and exit status match. CR15 illustrates
why: the nominal type mismatch survived while an extra `LinearResourceLeak`
broke exact parity. Qualify the reader by changing the expected code and by
appending a spurious diagnostic to captured output. Both comparisons must fail.
[Owning fixture guard](../scripts/phase26_2_allocator_guard.py) ·
[CR15 wrong-brand fixture](../tests/phase24_cr15_qualification_wrong_brand_rejected.gst)

Both standalone inputs use the [protected-resource module](../compiler/phase20_protected_access_module.gst).
Resolve the import as the owning fixture does. The existing guard exercises
the fixture files. Mark a published block tested only after its own bytes pass
the reader. The [multi-tenant demo](DEMO_TARGET_PROGRAM.md#the-program) remains
a design target while individual examples qualify.

**Standalone program.** Consuming the owner logs its token and makes freeing
its arena valid. The native fixture exits successfully and prints `41` once.
[Existing positive fixture](../compiler/phase26_2_allocator_closed_free.gst)

```gust,standalone
import "phase20_protected_access_module.gst" as protected;
func main() int {
 mut ctx := os.Arena.New();
 mut next := os.Arena.New();
 mut value: protected.ProtectedValue[ctx];
 value.value = 7;
 mut owner := protected.acquire(&value, 41);
 protected.consume(owner); ctx.Free(); next.Free();
 return 0;
}
```

**Expected frontend refusal.** A scheduled consume leaves the owner live at
the immediate `ctx.Free()`. The expected diagnostic is `LinearResourceLeak`.
An unexpected acceptance, a different or additional error, or a refusal from
the backend fails the example. The negative case is compile-only.
[Existing negative fixture](../compiler/phase26_2_allocator_deferred_owner.gst)

```gust,refused
import "phase20_protected_access_module.gst" as protected;
func main() int {
 mut ctx := os.Arena.New();
 mut next := os.Arena.New();
 mut value: protected.ProtectedValue[ctx];
 value.value = 7;
 mut owner := protected.acquire(&value, 41);
 defer protected.consume(owner); ctx.Free();
 return 0;
}
```

## Scope of an ownership claim

For Phase 26.2, Cranelift supplies the receipts and Docs/vision describes the
claim they support. A read-only report should answer “Which cases failed in
the frontend, which successfully executed native cleanup, and which are still
undecided?” For each case show the rule, source revision, stage reached,
expected and observed result, and a reference to the receipt. When a rule is
covered through lowering, name the lowering. Distinguish a missing case from
one deliberately outside the claim. A stale or missing receipt leaves the
case unverified. Compute counts over the named population and keep open
decisions visible alongside them. [Gust assurance evidence inventory](SEMANTIC_CHANGE_ASSURANCE.md#124-expected-and-observed-evidence-inventory)

For example, the deferred-owner fixture can establish a frontend refusal,
while the closed-owner fixture has a native cleanup observation. OD-23
remains a decision about resource-valued slots. Keep those three entries
distinguishable even if every executed test passes. This report can consume
Gust's existing evidence directly. Frost's classifier distinguishes direct
model coverage, coverage through a named lowering, gaps and exclusions. Its
audit found that only **2 of 17 accepted corpus cases** satisfied every
hypothesis of the theorem it checked. That denominator belongs to Frost.
[Frost classifier](https://github.com/matthewjberger/frost/blob/35e5868b08d192e45e8db606538b4b7357ffc1b4/tests/core_coverage.rs) ·
[Proof limits](https://github.com/matthewjberger/frost/blob/35e5868b08d192e45e8db606538b4b7357ffc1b4/spec/README.md)

## Seeded lexical defer checks

Cranelift's Phase 26.2 differential pilot extends the fixed scalar controls.
Generate small, safe programs from a deterministic seed. Vary nested bindings
with the same spelling, the position of a later assignment, and early return
versus fallthrough. An independent evaluator for this fragment records the
lexical binding when the defer is scheduled and reads its current scalar value
at cleanup. With outer value 11 and inner value 22, returning from the inner
scope logs 11. Assigning 33 to the scheduled outer binding before exit logs
33. Derive the expected trace from the generated program independently of
either compiler route. [Gust composition differential](../scripts/phase17_composition_differential.sh) ·
[Existing lexical cases](../compiler/phase26-2-defer-lexical/cases.json)

Compare expected and observed traces at the same statement or cleanup point
on each supported route in the owning differential suite. Agreement between
both routes can still leave a shared bug. Retain the seed, generator version,
source, route, expected and observed values, and first differing observation.
Replaying a seed must reproduce the same source and observation sequence.
Use only routes supported by the owning roadmap for that revision.
[Frost seeded generator](https://github.com/matthewjberger/frost/blob/35e5868b08d192e45e8db606538b4b7357ffc1b4/tests/fuzz.rs) ·
[Frost trace validator](https://github.com/matthewjberger/frost/blob/35e5868b08d192e45e8db606538b4b7357ffc1b4/spec/FrostSpec/Validate.lean)

## Related locations for one ownership diagnostic

Start with the Phase 26.2 `LinearResourceLeak` in the deferred-owner example.
Cranelift's structured diagnostic should identify the immediate `Free()` as
the primary span, the acquisition that tied the owner to the arena, and the
deferred consume that runs too late. Test each span against the corresponding
source expression, including the two operations on the same line. Keep the
established error code, diagnostic order and frozen human-readable output
byte-for-byte where specified. The reader should be able to locate the
ordering mistake using structured output alone.
[Frost diagnostic representation](https://github.com/matthewjberger/frost/blob/35e5868b08d192e45e8db606538b4b7357ffc1b4/src/diagnostic.rs)

## Context lowering and slot reuse

- **Phase 26.3, Cranelift.** Pair an allowlisted call under `with ctx` and
  under function-level `using ctx` with its explicit-argument equivalent.
  Inspect the lowered call before typechecking and compare the resolved
  allocator argument. Include ambiguous competing contexts as a required
  refusal. Exercise the explicit-only boundaries for unsafe blocks, FFI,
  raw-pointer and isolated-arena APIs, and resource creation, drop and move.
  Frost's innermost-region choice illustrates why the ambiguous case needs its
  own Gust expectation. [Gust resolution rules](PHASES_26_AND_27.md#phase-263--implicit-context) ·
  [Frost lowering](https://github.com/matthewjberger/frost/blob/35e5868b08d192e45e8db606538b4b7357ffc1b4/src/lower/allocation_sources.rs) ·
  [Frost lowered fixture](https://github.com/matthewjberger/frost/blob/35e5868b08d192e45e8db606538b4b7357ffc1b4/tests/lowering/allocation_sources.core.txt)
- **Phase 26.2, OD-23.** Compare live, released and reused slots in the
  decision record. Ask separately whether the handle still identifies the
  acquisition, what it may observe and who owes cleanup. Docs/vision records
  the cases for the operator's ownership decision. OD-23 remains open and
  no representation has been selected. [Slot decision cases](RESOURCE_COLLECTION_SLOT_OWNERSHIP_DECISION.md#current-proposal-and-decision-boundary)

## Access while an arena is live

**Planned design work.** Keep explicit arena brands and lexical cleanup. They
tell a generator where an allocation belongs and when cleanup runs. Even while
the arena is live, a write through another argument can change the value a
caller sees, and collection growth can replace the storage a view designates.

| Roadmap item | Cases to compare | What to establish |
| --- | --- | --- |
| Overlapping writable arguments | Pass the same field to two parameters that write through their references. Repeat with two distinct scalar fields of the same record. | Record Gust’s current behavior for both calls. Evaluate a rule that rejects the overlapping call and accepts the disjoint one. |
| View across collection growth | Take a view, force growth that replaces its backing, then read through the old view. Compare with a view acquired after the same growth. Keep the arena live throughout. | Identify a safe public API that can express the sequence. Establish whether the old view stays valid, is rejected, or is unreachable through that API. Use the fresh view as the positive control. |

**Ownership and sequencing.** Cranelift owns the writable-argument design
study before any change to the borrow contract. Gust currently allows two
references to write to the same value. The existing aliasing fixture records
that behavior. For the collection case, use the Phase 26.5 Stdlib safety
audit to identify the operation and its backing-storage contract. If the
surface can expose a stale view, route the evidence to the compiler owner
before proposing a language rule. Keep unsafe candidate reads compile-only.
Implementation requires an owning-roadmap decision. OD-23 separately asks who
owns a linear value in a collection slot.

[Gust borrow contract](VISION.md#26-borrows) ·
[Current aliasing fixture](../tests/test_shared_mutable_aliasing_observed.gst) ·
[Frost call-site rules](https://github.com/matthewjberger/frost/blob/35e5868b08d192e45e8db606538b4b7357ffc1b4/docs/book/src/reference/ownership.md) ·
[Frost stale-view fixture](https://github.com/matthewjberger/frost/blob/35e5868b08d192e45e8db606538b4b7357ffc1b4/tests/memory/a-view-inside-an-element-after-a-growth.frost)
