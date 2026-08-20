# Step 5.2 Resource Semantics Design Checkpoint

> **Status: re-verified 2026-08-19 by Patch S1.7 of `TASK_STDLIB.md`.** The
> per-item findings are in "Verified state" immediately below. The original text
> is kept unchanged beneath it as the historical record.

## Verified state, 2026-08-19

Re-checked against the post-Phase-15 compiler. Item numbers match the original
list below.

| # | Requirement | Status |
| --- | --- | --- |
| 1 | Opt-in metadata | **met** — `is_linear_resource` metadata exists and is registered |
| 2 | Resource representation | **partly live** — helpers exist; no automatic declaration or assignment; scope-exit cleanup *is* validated for `Resource[T]` on two paths in the self-hosted compiler (corrected 2026-08-20) |
| 3 | Open-resource registry | **met** — `open_linear_resources` is a typed registry |
| 4 | Destructor identity | **not met for user types** — see below |
| 5 | Transfer state | **met** — owned, borrowed, moved, closed, destructor_scheduled all represented |
| 6 | Defer semantics | **met** — `Defer` is an AST node; this changed after the original text was written |
| 7 | Provenance eligibility | **partial** — Step 5.1 provenance machinery exists |
| 8 | Directory parity | **not met** — `open_directories` is still present and has not been retired |

Two findings matter more than the table.

**There is no way to declare a destructor in source.** `env_register_struct_linear_destructor` is called from exactly two places in `compiler/typechecker.gst`, both registering `os.CloseDir`, and the second is gated on a directory-handle predicate. There is no keyword, attribute, or annotation in `compiler/lexer.gst`, `compiler/parser*.gst`, `src/lexer.rs`, or `src/parser.rs` that lets a user-defined type name its destructor. The framework supports exactly one destructor, for one built-in type.

**Cleanup validation is wired, but only for `Resource[T]`.** *Corrected 2026-08-20 at `b47d0049` — see the note below.* `env_validate_linear_resource_scope_exit_cleanup` is invoked from two real typechecking paths in the self-hosted compiler: function exit (`compiler/typechecker.gst:9859`, "Step 5.2Q") and explicit return (`:10976`, "Step 5.2R"). Both call sites were added by `ce211321` on 2026-06-30, seven weeks before this audit.

What it validates is narrow. It delegates to `env_validate_linear_resource_cleanup_boundary`, and the surrounding machinery keys on the compiler-owned `Resource` generic specifically — `type_is_resource` requires a `Generic` type literally named `Resource` with one argument (`compiler/typechecker.gst:7690`). A directory handle is not a `Resource[T]`, so it is outside the check.

The behavioural finding below is therefore still correct and the mechanism claim was not: a program that opens a directory handle and never closes it compiles clean, because that type is not covered — not because nothing runs.

So the framework is further along than the original text says on representation, state, and `defer`, and further behind on enforcement: what exists is a set of helpers with test coverage, not a checker that runs.

---

## Original text, 2026-06-28

Retained unchanged. Read the verified state above first.

This checkpoint freezes the semantic design direction for generalized linear resources after the Step 5.2 report-only closure. It is not an enforcement patch and must not add new `report_step52_*` targets.

## Goal

Replace the specialized `open_directories` directory-handle lane with a generalized, metadata-driven linear-resource framework only after the compiler can represent resource ownership semantically.

## Non-goals

- Do not remove or weaken `open_directories` in the same patch that introduces generalized resource design.
- Do not infer resource safety from textual `linear`, `drop_func`, `defer`, `OpenDir`, or `CloseDir` matches.
- Do not wire textual inventories into `make test` as linear-resource enforcement.
- Do not add generalized leak, double-close, use-after-move, or defer validation until the AST/typechecker state exists.

## Required semantic state

A compiler-backed Resource design needs all of the following before enforcement:

1. **Opt-in metadata:** only explicitly linear/resource-marked types enter the generalized resource checker. Ordinary AST, typechecker, codegen, primitive, and collection types must bypass this path by default.
2. **Resource representation:** `Resource[ctx, T]` must carry enough type information to identify the branding context, payload kind, destructor identity, and transfer state. The current implementation has inert type-shape helpers for a one-payload `Resource` generic, a resolver bridge that preserves only `Resource[T]` without requiring a monomorphized `Resource` template, declaration-helper predicates over already-registered variable types, assignment-helper predicates for explicit Resource assignment modeling, lifecycle-operation helpers for manual state transitions, cleanup-query helpers for future leak checks, and registry-bridge helpers for resource-eligible payload structs, but no automatic declaration/assignment/lifecycle enforcement yet. Existing multi-argument `Resource[...]` templates remain legacy structs and must continue through normal monomorphization.
3. **Open-resource registry:** `open_linear_resources` must be a typed registry keyed by resource identity, not a textual replacement for `open_directories`.
4. **Destructor identity:** destructors must be registered semantically, so `drop_func` / `os.CloseDir`-style cleanup can be validated without string matching.
5. **Transfer state:** resources must distinguish at least owned, borrowed, moved, closed, and destructor-scheduled states.
6. **Defer semantics:** `defer` must have explicit AST/typechecker representation before it can satisfy cleanup obligations.
7. **Provenance eligibility:** trusted resource handles must originate from safe arena construction, validated OS-resource constructors, or a future explicit validation/copy API. Raw-derived, sandbox-derived, and unknown unsafe-origin values must not enter `open_linear_resources` as safe branded handles.
8. **Directory parity:** `open_linear_resources` must cover the existing directory-handle safety behavior before `open_directories` can be removed.

## Proposed inert metadata shape

The first compiler patch should add metadata carriers without changing diagnostics or enforcing new rules. The shape should be explicit enough that later patches can populate and validate it incrementally.

### Type metadata

Linear resource opt-in should live on type metadata, not on textual names:

- `is_linear_resource`: `0` by default for every existing type.
- `Resource` generic shape: currently accepted only by inert helper predicates when it has exactly one payload type.
- `Resource` resolver bridge: currently preserves only `Resource[T]` as a one-payload type shape instead of requiring a `Resource` template monomorphization; multi-argument `Resource[...]` forms keep normal template monomorphization.
- `Resource` declaration helper bridge: currently classifies already-registered variable types and can manually register eligible Resource declarations, but it is not automatic declaration integration.
- `Resource` assignment helper bridge: currently compares already-registered variable declarations with explicit assigned Resource types and can manually register matching eligible assignments, but it is not automatic assignment enforcement.
- Linear resource lifecycle operation helpers: currently perform explicit validated close, move, borrow, and destructor-schedule state transitions on `open_linear_resources`, but they do not emit diagnostics or enforce program semantics automatically.
- Linear resource cleanup query helpers: currently count and identify resources that still require owner cleanup, but they do not emit leak diagnostics or reject programs automatically.
- `Resource` registry bridge: currently allowed only for `Resource[T]` whose payload is a struct with explicit linear/destructor metadata.
- `resource_payload_kind`: empty/default until a type is explicitly modeled as a resource wrapper.
- `resource_destructor_name`: empty/default until a destructor is registered semantically.
- `resource_allows_defer`: `0` by default until `defer` is represented in the AST/typechecker.

Existing `linear` / `is_linear` metadata can inform this design, but it must not automatically imply generalized `Resource[ctx, T]` ownership.

### Resource value state

A generalized resource value should carry compiler-owned state rather than string-matched cleanup facts. The current implementation has inert `open_linear_resources` state helpers for these states, but they are metadata plumbing only until declaration/assignment integration and enforcement exist:

- `owned`: the current scope owns the resource and must release or transfer it.
- `borrowed`: the current expression observes the resource without taking ownership.
- `moved`: ownership has been transferred and later use must be rejected.
- `closed`: the registered destructor has already consumed the resource.
- `destructor_scheduled`: a validated `defer` or equivalent cleanup path owns the eventual destructor call.

Current inert validation predicates expose future enforcement questions without emitting diagnostics: usable, closeable, movable, requires-cleanup, destructor-schedulable, and terminal-state checks. Current inert diagnostic helpers map those predicate failures to stable message text but still do not report errors or reject programs. Current inert scope-state snapshot helpers clone `open_linear_resources` so function bodies and isolated guard-else checks can avoid leaking resource-state metadata across typechecker scopes before enforcement exists.

### Open-resource registry entry

Each future `open_linear_resources` entry should be keyed by semantic resource identity and store at least:

- owning variable or temporary identity
- branding context
- payload type
- destructor identity
- transfer state
- source span for diagnostics
- compatibility marker for legacy directory parity checks

### Directory parity mapping

The first parity implementation should mirror the existing directory lane without weakening it:

- `os.OpenDir` creates both an `open_directories` entry and a future generalized resource entry.
- `os.CloseDir` clears both lanes for the same semantic handle.
- leak diagnostics remain governed by the legacy lane until generalized diagnostics match exactly enough for a later cleanup-only removal.

## Migration order

1. Add inert AST/type metadata for resource ownership without changing enforcement.
2. Add inert resource value state and registry entry structures with default bypass behavior.
3. Add an internal `open_linear_resources` registry alongside `open_directories`.
4. Teach directory operations to populate both the legacy and generalized registries.
5. Validate generalized registry diagnostics in parallel with the existing directory diagnostics.
6. Add narrow compiler-backed guards only after parity is proven.
7. Remove `open_directories` in a later cleanup-only patch once generalized coverage is equivalent.

## Step 5.1 dependency

Generalized resource enforcement depends on the Step 5.1 provenance/non-laundering lane. Before `Resource[ctx, T]` can become a trusted linear handle, the typechecker must be able to distinguish safe arena or validated OS-resource origins from raw-derived, sandbox-derived, and unknown unsafe origins. This prevents a raw pointer, sandbox scratch address, or external native address from being laundered into the future `open_linear_resources` registry as if it were a compiler-verified safe handle.

Step 5.2 report-only scaffolding may stay in place, but compiler-backed Step 5.2 enforcement should remain paused until the Step 5.1 deferred unsafe lanes have semantic designs. Generalized resource ownership depends on knowing whether a handle or reference came from safe arena construction, raw pointer manipulation, address escape, or external FFI.

## Guardrails

`make guard_step52_no_post_closure_report_churn` should remain green throughout this design work. If new Step 5.2 reports are needed, update the closure whitelist intentionally and document why the new report is a compiler-design prerequisite rather than status churn.
