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

## Direct FFI/native-call syntax surface

The first deferred lane to design is direct user-facing FFI. Enforcement must key off parsed function metadata, not textual mentions of `extern`, `ffi`, `c_call`, generated C snippets, runtime headers, or codegen trace strings.

### Semantic declaration shape

A direct external/native function surface should eventually produce function-signature metadata with at least:

- `is_extern`: marks the signature as implemented outside Gust.
- `extern_symbol_name`: stores the symbol name used at the C/native boundary.
- `extern_abi`: defaults to the C ABI until a richer ABI model exists.
- `requires_unsafe_call`: defaults to `1` for direct external/native calls.
- `requires_layout_metadata`: records whether argument or return types need explicit layout attributes.
- `requires_sandbox_arena`: records whether the call must execute through a transient sandbox arena wrapper.

This metadata may be introduced inertly before enforcement. It must not change ordinary Gust function calls, method calls, generated runtime helper calls, or codegen string generation.

### Inert compiler carrier checkpoint

`FunctionSignature[ctx]` may carry the direct FFI metadata fields before any parser or typechecker path populates them:

- `is_extern`
- `extern_symbol_name`
- `extern_abi`
- `requires_unsafe_call`
- `requires_layout_metadata`
- `requires_sandbox_arena`

`init_function_signature_ffi_defaults` initializes these fields for compiler-created signatures. Existing Gust functions, builtins, methods, and generated runtime helper calls continue to behave as non-extern signatures because the defaults are `is_extern = 0`, `extern_abi = "C"`, and all FFI/layout/sandbox requirements disabled. Parser population and enforcement remain deferred.

### Classification rule

Only parsed Gust source declarations/calls that carry direct external/native metadata should become FFI enforcement candidates. These are not direct user-facing FFI candidates:

- C `extern` declarations in runtime `.c` / `.h` files
- codegen trace strings containing labels such as `FFI override`
- generated C snippets emitted by compiler codegen
- comments or documentation
- safe Gust wrapper functions that internally contain their own explicit `unsafe` implementation

### Enforcement rule

Once the metadata exists, the compiler-backed guard should reject direct external/native calls outside an explicit unsafe context with a stable diagnostic. Safe wrappers may expose a safe API only if their implementation body contains the required unsafe boundary and does not launder raw-derived values into safe branded references or arena indices.

## Design order

1. Add inert direct FFI/native-call signature metadata fields to `FunctionSignature[ctx]` without parser population or enforcement.
2. Add default initialization for compiler-created direct FFI/native-call signature metadata without parser population or enforcement.
3. Add parser population for direct FFI/native-call signature metadata and classify existing runtime/native boundaries separately from user-facing Gust source calls.
4. Add inert AST/type metadata for layout attributes without changing codegen.
5. Define sandbox sub-arena ownership and destruction semantics for external calls.
6. Define address-origin metadata that separates safe branded references from raw-derived addresses.
7. Extend provenance tracking so raw-derived values cannot be laundered into safe `Index[T, ctx]` or `&T[ctx]` through assignments, calls, returns, or containers.
8. Add narrow compiler-backed guards only after each semantic lane has a stable representation and focused positive/negative fixtures.

## Step 5.2 sequencing rule

Step 5.2 report-only scaffolding may remain in place, but Step 5.2 compiler-backed resource enforcement should not advance beyond inert design until these Step 5.1 deferred lanes are resolved or explicitly scoped as non-blocking. Resource ownership, destructor safety, and generalized handle tracking depend on knowing whether a value originated from safe arena construction, raw pointer manipulation, or external FFI.

## Guardrails

- Do not add regex-only failing guards for FFI, address escapes, layout annotations, sandbox arenas, or provenance laundering.
- Do not treat generated C strings, comments, type syntax, or runtime implementation details as direct user-facing unsafe operations.
- Do not mark the full Step 5.1 objective complete until FFI/layout/sandboxing, address-escape, and full provenance/non-laundering have compiler-backed semantics or an explicit deferral record.
