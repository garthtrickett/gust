# The unsafe/FFI sequence — ordering, status, and where it sits

`STEP51_DEFERRED_UNSAFE_SEMANTICS.md` already holds the *design* for most of this
work: FFI declaration syntax, the sandboxed sub-arena checkpoint, address-origin
metadata, provenance propagation and non-laundering, and layout-aware FFI
validation. **What was not written down anywhere is the order, the completion
status, and where the whole sequence sits relative to C retirement.** This file
records those three things and does not restate the designs.

**Operator placement directive, 2026-08-20:**

> **All of this happens after the Cranelift migration completes and C is
> deprecated.**

That is the load-bearing sentence, and §4 below draws the consequence nobody had
drawn from it.

---

## 1. The sequence

**Step 0 — complete the Cranelift backend transition.** *Prerequisite for
everything below.* C transpilation is a poor fit for Gust's semantics precisely
where this work lives: layout, aliasing, pointer operations, cleanup, and ABI.
A direct backend gives Gust authoritative control over those. Deliverables
include a backend-neutral lowered IR between the typed representation and
Cranelift IR; type checking, ownership, provenance and safety validation staying
**outside** the backend; concrete layouts defined for every builtin form; C
retained temporarily as a bootstrap bridge and differential reference, compared
by **observable behaviour rather than generated-code equality**.

**Step 1 — safe constructor coverage and unknown-origin rejection. DONE.**
Ordered first because strictness has to follow recognition: establish which
operations create valid safe origins, *then* reject safe-branded values whose
origin cannot be proven.

**Step 2 — broader address-origin metadata. DONE.** Nine categories: `safe`,
`local_stack`, `arena`, `scratchpad`, `ffi`, `sandbox`, `raw_unknown`,
`borrowed_field`, `container_element`. Metadata correctness only — no broad
enforcement at this stage.

**Step 3 — broad raw- and sandbox-derived provenance propagation. DONE.**
Through expressions, assignments, arguments, returns, field reads and writes,
container reads and writes, casts, and selected stdlib helpers. The point is
non-laundering: an unsafe-derived reference must not become safe by passing
through an intermediate variable, field, function, or container.

> **Steps 1–3 verified live 2026-08-20.** `AddressOriginMetadata` and all nine
> categories are present and in use at `compiler/typechecker.gst:5-24`, with
> `ExpressionProvenance` carrying per-expression records and `variable_origins`
> and `return_origins` on `TypeEnvironment`. `docs/UNBLOCKED_CONTAINMENT_WORK.md`
> re-verified those citations the same day. **The DONE markers are real.**

**Step 4 — richer FFI and native-call boundary modelling.** Which types may cross;
which arguments require `unsafe`; what native code may mutate; whether pointers
are borrowed, transferred, retained, or returned; which returns get `ffi`,
`raw_unknown` or `sandbox` provenance; whether a pointer may be retained after
the call; callback ownership and lifetime; how native errors are represented;
what must be copied rather than borrowed. **Every parameter and return position
gets an explicit ownership and escape policy** — the distinction between
`borrowed buffer: *u8` and `-> owned *u8` must exist semantically even if the
syntax is settled later.

**Step 5 — `#[repr(C)]`, `#[packed]`, and ABI layout enforcement.** After step 4,
because layout compatibility matters most where values cross. **One authoritative
layout engine** shared by type checking, FFI validation, Cranelift lowering,
diagnostics, and compiler metadata — the typechecker and backend must not compute
layouts independently. Ordinary Gust structs are **not** assumed C-compatible and
are rejected at C ABI boundaries unless explicitly approved. Packed field access
requires handling or `unsafe` rather than a silent aligned load. Enums crossing
FFI need an explicit integer representation.

> `#[packed]` stays a specialised tool for external binary formats, hardware
> interfaces, and legacy native APIs. **It must not become the default
> representation for Gust data.**

**Step 6 — isolated FFI allocation arenas.** Last, because it is the most
runtime-heavy part and most likely to change once the boundary model is tested.
The name matters: **isolated**, not sandboxed. It bounds the lifetime and spread
of memory handed to native code and does **not** prevent native code from
touching unrelated process memory, using globals, making syscalls, retaining
external pointers, or corrupting memory through another pointer. Real isolation
needs process boundaries, hardware protection, or WebAssembly.

**Step 7 — generalised linear-resource enforcement.**

**Step 8 — Phase 5.3, implicit-context desugaring.**

**The completion gate between steps**, applied to every one: focused positive and
negative tests, isolated run, full compiler suite, **Cranelift-native bootstrap**,
normalised-IR or semantic fixed-point convergence, stable and specific
diagnostics, and a coherent bisectable commit before the next step starts.

---

## 2. Why the order is this order

Each step is the precondition for the next being *checkable*, not merely for it
being convenient.

- Provenance cannot be enforced strictly until safe origins are recognised
  (1 → 3).
- The FFI boundary contract has nothing to say about a return value until origins
  are meaningful (2, 3 → 4).
- Layout enforcement matters most where values cross a boundary that step 4
  defines (4 → 5).
- Isolated arenas depend on the boundary model they are isolating (4, 5 → 6).

**And all of it depends on step 0** for a reason stronger than sequencing
convenience: while C is the backend, layout, aliasing, cleanup and ABI behaviour
are partly C's decisions rather than Gust's. **Enforcing an ABI rule on a backend
that does not own the ABI is enforcing it against a compiler quirk.**

---

## 3. Where the designs already live

| Step | Design recorded in |
| --- | --- |
| 4 | `STEP51_DEFERRED_UNSAFE_SEMANTICS.md` — "Direct FFI/native-call syntax surface", "Semantic declaration shape" |
| 5 | same — "Layout-aware FFI validation helper checkpoint", classification and enforcement rules |
| 6 | same — "Sandboxed FFI sub-arena design checkpoint" (the name predates the *isolated* correction above) |
| 2, 3 | same — "Address-origin metadata checkpoint", "Provenance propagation and non-laundering design checkpoint" |
| 7 | `STEP52_RESOURCE_SEMANTICS.md`, and `TASK_STDLIB.md` CR-5 for the live blocker |
| 8 | `docs/VISION.md` §24.1 |

---

## 4. The consequence of the placement directive

The directive puts this sequence after C deprecation, which is **Phase 23** in
`docs/ROADMAP_TAIL.md`. Step 8 is Phase 5.3, implicit-context desugaring. And
implicit context is **row 4 of `docs/DEMO_TARGET_PROGRAM.md`**, listed there as a
demo prerequisite.

> **Row 4 therefore cannot be a demo prerequisite.** The demo is a four-month
> plan (§0.14); Phase 23 is the far end of the roadmap. Under this directive,
> implicit context arrives long after the demo does.

**This is a resolution rather than a contradiction, and the resolution was
already implied.** `docs/VISION.md` §24.1 records that implicit context is
ergonomic rather than semantic — an arena is a destination, not a permission —
and that it matters most for **OD-9**, model fluency. So the demo can be written
without it. The handler threads its context explicitly and is more verbose.

**What that costs, stated so it is a choice rather than a surprise:** OD-9 asks
whether a model can write Gust well, and the answer is measured against the
surface a model actually sees. Deferring row 4 means that surface carries an
explicit context parameter on every allocating function for the whole demo
period. That is not fatal — it is *more* explicit, which §17's philosophy
generally favours — but **it should be measured against OD-9 rather than
assumed harmless.**

Two smaller consequences worth noting. **Row 4's Phase 19 dependency becomes
moot** — §24.1 found that implicit context needs D-1's brand resolution, and
under this directive Phase 19 will be long finished. And **step 7 is CR-5**: the
missing destructor declaration that blocks `MutexGuard` and, per §54.0, the
Postgres capability. Placing step 7 after C deprecation places those with it.
