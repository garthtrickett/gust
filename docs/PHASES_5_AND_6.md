# Phases 5 and 6 — systems safety, implicit context, and consolidation

The plan for Phase 5 (5.1 gated raw pointers and sandboxed FFI, 5.2 generalized
linear resources, 5.3 implicit context) and Phase 6 (consolidation) was in no
file here. `STEP51_DEFERRED_UNSAFE_SEMANTICS.md` and
`STEP52_RESOURCE_SEMANTICS.md` hold checkpoints against parts of it;
`docs/UNSAFE_FFI_SEQUENCE.md` holds the ordering. This holds the plan itself, and
**a status column read from the live compiler on 2026-08-20**, because a plan
whose completed steps are indistinguishable from its pending ones invites the
work to be redone.

**Placement:** per the 2026-08-20 directive recorded in
`docs/UNSAFE_FFI_SEQUENCE.md`, this sits after the Cranelift migration completes
and C is deprecated — with the exception of the parts already built, listed below.

---

## Step 5.1 — gated raw pointers, unsafe blocks, sandboxed FFI

The staging is the interesting part, and it generalises well beyond this step.

**A — additive grammar, no-op parsing.** Parse `unsafe`, `unsafe {}` blocks, and
`unsafe func` signatures. Typecheck them as **identity scopes with zero
enforcement**. Stage 0 compiles the parser change; Stage 1 parses `unsafe`
natively and enforces nothing.

**B — proactive codebase wrapping.** Audit `compiler/*.gst` and the core
collections, and wrap every raw dereference, pointer arithmetic, raw cast, and
FFI call in `unsafe {}`. **Because the active compiler treats those blocks as
identity, the whole codebase keeps compiling and converging** — so 100% of the
low-level logic migrates before any rule turns on.

**C — strict enforcement.** Only now add the typechecker rules: a compile-time
error for raw dereference, pointer arithmetic, or FFI call outside `unsafe`; and
the **non-laundering boundary** — an unsafe block or function may not return a
safe branded `Index[T, ctx]` or `&T[ctx]` whose address came from a raw pointer
or manual allocation. Safe types are constructible only through compiler-verified
arena allocators. **Enforcement activates with zero compilation errors, because
the wrapping already happened.**

**D — layouts, sandboxing, banned raw casts.** `#[repr(C)]` and `#[packed]`; the
transient sandbox sub-arena for external calls, destroyed on return; and a strict
error when a branded `Index` is cast directly to `*T` outside `unsafe`.

> **The A→B→C pattern deserves a name, because it is how a self-hosted compiler
> changes a rule without deadlocking on itself.** Add the syntax as a no-op,
> migrate the entire codebase under the no-op, then switch enforcement on. The
> alternative — enforce first, then fix the fallout — cannot work when the
> compiler being fixed is the one enforcing the rule. Every future gating change
> should use this shape, and it is worth stating as a repository technique rather
> than as a detail of Step 5.1.

## Step 5.2 — generalized linear resource enforcement

**A — metadata opt-in, and the isolation rule.** The linear engine runs **only**
on structs annotated `#[linear]` (`is_linear` on `StructLayout` and
`StructTemplate`) or carrying a registered `drop_func`. Everything else —
unannotated types, primitives, compiler-internal collections — bypasses the
escape analyser entirely. **This is the guard against a big-bang failure** where
conservative analysis flags `Type`, `Statement`, or `Expression` and the compiler
stops building itself.

**B — infrastructure.** Replace the hardcoded `open_directories` map on
`TypeEnvironment` with a generalized `open_linear_resources` registry, and
introduce `Resource[ctx, T]` for OS and hardware handles. A `Resource` cannot sit
on the stack as an owned value and must be bound to a registered destructor.

**C — linearity and index aliasing.** If `T` is linear, `Index[T, ctx]` inherits
linearity: no duplication, no implicit copy, passed only by explicit move or
handed to its `drop_func`. **`ctx.Free()` or a move of `ctx` — including
`std.GenerationalSwap` — is a compile-time leak error if any resource branded
with that allocator is still open.**

**D — escape analysis and `defer` validation.** A linear value's handle must be
returned (transferring ownership), released by its `drop_func` in normal flow, or
released in a validated `defer`. Otherwise: `LinearResourceLeak`.

## Step 5.3 — implicit context

**Decided 2026-08-20: both spellings ship.** A block form and a function form:

```
with ctx {
    mut v := std.VectorNew();
    mut s := std.Clone(name);
}

func parse_type(parser: *Parser[ctx]) ast.Type[ctx] using ctx {
    mut fields := std.VectorNew();
    return std.Clone(type_name);
}
```

Both lower to today's explicit form before any semantic pass runs.

> **Why two spellings is not a §13 violation, stated because it looks like one.**
> The function form **desugars to the block form wrapped around the whole body**.
> It is one mechanism with two placements, not two mechanisms — the same
> structure §117.1 uses for the intent layer. If the function form ever acquires
> behaviour the block form cannot express, it has become a second mechanism and
> the pair should collapse.

**The eight rules, as given:**

1. Existing explicit `ctx` code keeps working forever.
2. Lower implicit `ctx` **before** typechecking and codegen safety passes.
3. Only allowlisted arena-backed stdlib functions receive implicit context.
4. **No implicit `ctx` inside `unsafe` blocks.**
5. **No implicit `ctx` in FFI, sandbox, or raw-pointer APIs.**
6. **No implicit `ctx` for `Resource[ctx, T]` creation, drop, or move.**
7. **Ambiguity is an error, not inference.**
8. Do not mass-migrate compiler-core code.

**Staging:** A parse `with ctx` into the AST with no lowering; B lower allowlisted
zero-`ctx` calls inside `with ctx`; C add function-level `using ctx` as a
desugaring; D add a guard that no implicit `ctx` is accepted in unsafe, resource,
or FFI contexts; **E do not mass-migrate** — allow it in new non-core helper,
test, and application code, and keep unsafe, provenance, resource, and
compiler-core code explicit.

> Rules 4–6 sharpen `docs/VISION.md` §24.1's argument rather than merely
> restricting it. §24.1 says implicit context is safe because **an arena is a
> destination, not a permission**. These three rules are the boundary that keeps
> that true: the moment a context is adjacent to authority — unsafe, FFI, a
> resource handle — it goes back to being written out. Rule 7 is §24.1's
> shadowing rule generalised: **prefer a diagnostic to a clever inference.**

## Phase 6 — consolidation

| Step | Work |
| --- | --- |
| 6.1 | Migrate `map.Get`/`LookupResult_T` to `map.get_opt`/`Option[T]` **file by file**, bootstrapping after each, never as one pass |
| 6.2 | Strip `empty[T]` sentinel parsing, delete synthesized `LookupResult_T`, restrict raw null within safe boundaries |
| 6.3 | Delete `open_directories` from `TypeEnvironment`; directories become `Resource[ctx, Directory]` |
| 6.4 | Delete the split LHS/RHS subscript codegen branches — subscripts are read-only copies, mutation goes through explicit references. **Keep parser LHS validation robust** |
| 6.5 | Stdlib safety audit — no raw pointer work leaks into the safe public interface of `std.Vector`, `std.HashMap`, `std.String` |
| 6.6 | Refactor `Statement` and `Expression` into true sum-type enums; migrate `if stmt.tag == X` to `match`. Then promote the consolidated output as the next bootstrap seed |

---

## Status, read from the compiler on 2026-08-20

| Item | Evidence | State |
| --- | --- | --- |
| 5.1 B — codebase wrapped in `unsafe` | `unsafe {` in `typechecker.gst` ×155, `mir.gst` ×49, `parser.gst` ×45, `codegen.gst` ×39, and ~130 further files | **done or nearly** |
| 5.2 B — generalized registry | `open_linear_resources` ×32 in `typechecker.gst` | **exists** |
| 5.2 A — `#[linear]` opt-in | parsed at `parser.gst:869-872`, carried as `is_linear_resource` at `ast.gst:77`, registered via `env_register_struct_linear_metadata` | **exists** |
| 5.2 D — cleanup validation | invoked on two paths in the self-hosted compiler | **partly live** (`STEP52` item 2) |
| 5.2 — destructor **declaration** | one built-in destructor, no source syntax to declare another | **missing** — `TASK_STDLIB.md` CR-5 |
| 6.1 — `Option` migration | `get_opt` present in `codegen.gst`, `resolver.gst`, `typechecker.gst`; `LookupResult` still ×14 in `typechecker.gst` | **partly migrated** |
| 6.2 — `empty[T]` removal | 130 uses in `typechecker.gst` alone | **not started** |
| 6.3 — purge `open_directories` | still ×15, plus a `legacy_freeze` test entry | **frozen, not purged** |

**Two connections worth making explicit.**

**Step 6.2 is the fix for a ledger violation, not just cleanup.**
`docs/ONE_WAY_LEDGER.md` E14, rows 32 and 45, record that `empty[T]` is a second
spelling of absence competing with `Option[T]` — 130 uses in the typechecker
alone, in ordinary safe code, compared with `==` exactly as a null check would
be. **Step 6.2 closes that row.** It is currently written as tidying; it is
actually the remedy for a one-way-to-do-it breach the ledger already scores.

**Step 6.3 closes `STEP52_RESOURCE_SEMANTICS.md` item 8**, the only remaining
"not met" in that table that is not the destructor gap. `open_directories` is
frozen behind a legacy test rather than removed, which is the correct
intermediate state and is not the end state.

**And one caution.** Step 6.1's file-by-file rule with a bootstrap after each file
is the same discipline as Step 5.1's A→B→C: **never change the compiler's own
idiom in one pass**, because the failure is not a test failure, it is a compiler
that no longer builds itself. Both rules exist for that reason and neither should
be read as excessive caution.
