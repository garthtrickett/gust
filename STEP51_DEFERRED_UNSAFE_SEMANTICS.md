# Step 5.1 Deferred Unsafe Semantics Checkpoint

This checkpoint returns sequencing to Step 5.1 before any compiler-backed Step 5.2 linear-resource enforcement continues. Basic unsafe enforcement is compiler-backed, but the full Step 5.1 objective is not complete until the deferred unsafe, FFI, layout, sandboxing, address-escape, and provenance lanes have semantic designs and guards.

## Current closed subset

The basic unsafe boundary is considered closed when `make guard_step51_basic_unsafe_enforcement` passes. That aggregate covers:

- raw pointer dereference outside `unsafe`
- raw pointer casts outside `unsafe`
- pointer arithmetic outside `unsafe`
- unsafe function calls outside explicit unsafe context
- unsafe function bodies as unsafe contexts
- narrow local raw-derived pointer return escape

This closed subset is necessary but not sufficient for the full Step 5.1 objective.

## Deferred lanes

The following lanes remain intentionally deferred:

1. **Direct FFI gating:** the compiler needs a stable Gust syntax surface for direct external/native calls before it can reject them outside unsafe contexts.
2. **Layout annotations:** `#[repr(C)]` and `#[packed]` need parser, AST, type metadata, and codegen semantics before they can be used for FFI or hardware layouts.
3. **Sandboxed FFI sub-arenas:** external calls should be able to operate inside a transient arena whose corruption or lifetime cannot contaminate the caller's safe arena state.
4. **Address-escape enforcement:** the compiler must distinguish safe reference construction from raw pointer materialization and generated/runtime plumbing.
5. **Full unsafe non-laundering:** raw-derived provenance must be tracked through assignments, returns, calls, and container storage, not just direct local raw-derived pointer returns.

## Design order

1. Define the direct FFI/native-call syntax surface and classify existing runtime/native boundaries separately from user-facing Gust source calls.
2. Add inert AST/type metadata for layout attributes without changing codegen.
3. Define sandbox sub-arena ownership and destruction semantics for external calls.
4. Define address-origin metadata that separates safe branded references from raw-derived addresses.
5. Extend provenance tracking so raw-derived values cannot be laundered into safe `Index[T, ctx]` or `&T[ctx]` through assignments, calls, returns, or containers.
6. Add narrow compiler-backed guards only after each semantic lane has a stable representation and focused positive/negative fixtures.

## Step 5.2 sequencing rule

Step 5.2 report-only scaffolding may remain in place, but Step 5.2 compiler-backed resource enforcement should not advance beyond inert design until these Step 5.1 deferred lanes are resolved or explicitly scoped as non-blocking. Resource ownership, destructor safety, and generalized handle tracking depend on knowing whether a value originated from safe arena construction, raw pointer manipulation, or external FFI.

## Guardrails

- Do not add regex-only failing guards for FFI, address escapes, layout annotations, sandbox arenas, or provenance laundering.
- Do not treat generated C strings, comments, type syntax, or runtime implementation details as direct user-facing unsafe operations.
- Do not mark the full Step 5.1 objective complete until FFI/layout/sandboxing, address-escape, and full provenance/non-laundering have compiler-backed semantics or an explicit deferral record.