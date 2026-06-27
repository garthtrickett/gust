# Step 5.2 Resource Semantics Design Checkpoint

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
2. **Resource representation:** `Resource[ctx, T]` must carry enough type information to identify the branding context, payload kind, destructor identity, and transfer state.
3. **Open-resource registry:** `open_linear_resources` must be a typed registry keyed by resource identity, not a textual replacement for `open_directories`.
4. **Destructor identity:** destructors must be registered semantically, so `drop_func` / `os.CloseDir`-style cleanup can be validated without string matching.
5. **Transfer state:** resources must distinguish at least owned, borrowed, moved, closed, and destructor-scheduled states.
6. **Defer semantics:** `defer` must have explicit AST/typechecker representation before it can satisfy cleanup obligations.
7. **Directory parity:** `open_linear_resources` must cover the existing directory-handle safety behavior before `open_directories` can be removed.

## Proposed inert metadata shape

The first compiler patch should add metadata carriers without changing diagnostics or enforcing new rules. The shape should be explicit enough that later patches can populate and validate it incrementally.

### Type metadata

Linear resource opt-in should live on type metadata, not on textual names:

- `is_linear_resource`: `0` by default for every existing type.
- `resource_payload_kind`: empty/default until a type is explicitly modeled as a resource wrapper.
- `resource_destructor_name`: empty/default until a destructor is registered semantically.
- `resource_allows_defer`: `0` by default until `defer` is represented in the AST/typechecker.

Existing `linear` / `is_linear` metadata can inform this design, but it must not automatically imply generalized `Resource[ctx, T]` ownership.

### Resource value state

A generalized resource value should carry compiler-owned state rather than string-matched cleanup facts:

- `owned`: the current scope owns the resource and must release or transfer it.
- `borrowed`: the current expression observes the resource without taking ownership.
- `moved`: ownership has been transferred and later use must be rejected.
- `closed`: the registered destructor has already consumed the resource.
- `destructor_scheduled`: a validated `defer` or equivalent cleanup path owns the eventual destructor call.

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

## Guardrails

`make guard_step52_no_post_closure_report_churn` should remain green throughout this design work. If new Step 5.2 reports are needed, update the closure whitelist intentionally and document why the new report is a compiler-design prerequisite rather than status churn.
