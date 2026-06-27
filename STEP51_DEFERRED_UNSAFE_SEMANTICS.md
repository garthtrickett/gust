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

`init_function_signature_ffi_defaults` initializes these fields for compiler-created signatures. `FunctionDecl` also carries the same inert metadata through the parsed AST, and the parser initializes ordinary function declarations as non-extern with C ABI defaults and all FFI/layout/sandbox requirements disabled. The parser accepts explicit `extern func` metadata and also accepts bodyless extern signatures terminated with `;`, synthesizing an empty AST body so typechecking can register the signature without inventing codegen behavior. The typechecker copies those AST fields into `FunctionSignature[ctx]`, and direct extern/native calls now reject outside explicit unsafe contexts. `StructDecl` carries inert layout metadata fields for `#[repr(C)]` and `#[packed]` attributes, but `StructLayout` intentionally remains payload-small because it is returned through `struct_registry.get_opt(...)` and `Some { val }` in existing codegen paths. The parser accepts `#[repr(C)]`, `#[packed]`, and their combination before `type ... struct` declarations. `TypeEnvironment` stores layout metadata in payload-safe primitive/string maps keyed by namespaced struct name, separate from `StructLayout`, and exposes query helpers for repr-C, packed, ABI, and combined requires-layout checks. Codegen layout changes, sandbox arena implementation, and broader provenance remain deferred.

### Sandboxed FFI sub-arena design checkpoint

A future direct external/native call may opt into `requires_sandbox_arena = 1`. That flag means the call should execute through a transient arena boundary rather than directly borrowing the caller's safe arena state.

The sandbox semantics are:

- The compiler creates or selects a temporary sandbox arena for the duration of one external/native call.
- The sandbox arena owns any scratch allocations used to marshal external inputs, receive external outputs, or isolate native-side corruption.
- The sandbox arena is destroyed or invalidated after the call boundary returns.
- Values whose origin traces to the sandbox arena must not be rebranded as safe caller-arena `Index[T, ctx]` or `&T[ctx]` values unless a later compiler-backed copy/validation rule explicitly permits it.
- Raw-derived pointers or addresses observed inside the sandbox must not be laundered into safe branded references through assignments, returns, calls, or containers.
- Safe wrapper functions may hide an external call only if their implementation contains the explicit unsafe boundary and copies validated data into caller-owned safe storage before returning.

This checkpoint defines ownership and destruction semantics only. `FunctionSignature[ctx]` now has inert helper predicates for sandbox policy and aggregate FFI policy classification, but these helpers only read existing metadata fields. They do not add wrapper codegen, runtime arena APIs, layout-aware marshalling, or provenance enforcement.

### Address-origin metadata checkpoint

The compiler now has an inert `AddressOriginMetadata` carrier for classifying where an address-like value came from before any broad non-laundering enforcement is enabled. The initial metadata categories are:

- `safe_arena`: a value whose origin is trusted arena-managed storage and may be eligible for safe branded `Index[T, ctx]` / `&T[ctx]` use.
- `raw_derived`: a value whose origin traces to raw pointer casts, pointer arithmetic, dereference materialization, or native address materialization.
- `sandbox_derived`: a value whose origin traces to transient sandbox-FFI storage and must not be rebranded into caller-owned safe storage without an explicit future copy/validation rule.
- `unknown`: an intentionally conservative default for values whose address origin has not yet been classified.

The helper predicates classify whether an origin allows safe branding, whether it requires an unsafe boundary, and whether it is raw-or-sandbox-derived. These helpers are inert metadata utilities only. They do not yet propagate through assignments, calls, returns, or containers, and they do not replace the existing narrow local raw-derived pointer return guard.

### Layout-aware FFI validation helper checkpoint

The compiler now has inert layout-aware FFI helper predicates that connect direct FFI metadata to the payload-safe struct layout registry without rejecting programs yet. `function_signature_requires_layout_policy` reports whether a signature explicitly requires layout metadata. `env_struct_has_explicit_ffi_layout` reports whether a namespaced struct has any explicit layout metadata. `env_struct_satisfies_c_ffi_layout` reports whether a struct has `repr(C)` metadata with C ABI, and `env_struct_missing_c_ffi_layout` is the negative predicate for future diagnostics.

These helpers are guardable building blocks for later call-site validation. They do not yet inspect function argument or return types, reject extern declarations, emit C prototypes, alter struct layout codegen, or infer layout policy from broad text scans.

### Classification rule

Only parsed Gust source declarations/calls that carry direct external/native metadata should become FFI enforcement candidates. These are not direct user-facing FFI candidates:

- C `extern` declarations in runtime `.c` / `.h` files
- codegen trace strings containing labels such as `FFI override`
- generated C snippets emitted by compiler codegen
- comments or documentation
- safe Gust wrapper functions that internally contain their own explicit `unsafe` implementation

### Enforcement rule

Direct external/native calls reject outside an explicit unsafe context with the stable diagnostic `Direct external/native function calls require an explicit 'unsafe' block`. Safe wrappers may expose a safe API only if their implementation body contains the required unsafe boundary and does not launder raw-derived values into safe branded references or arena indices.

## Design order

1. Add inert direct FFI/native-call signature metadata fields to `FunctionSignature[ctx]` without parser population or enforcement.
2. Add default initialization for compiler-created direct FFI/native-call signature metadata without parser population or enforcement.
3. Add inert `FunctionDecl` AST metadata, parser defaults, and typechecker propagation into `FunctionSignature[ctx]` without extern syntax or enforcement.
4. Add parser population for explicit `extern func` metadata while keeping codegen and enforcement disabled.
5. Add bodyless extern declaration handling for `extern func ...;` signatures while synthesizing an empty AST body.
6. Enforce direct extern/native calls require explicit unsafe contexts.
7. Classify existing runtime/native boundaries separately from user-facing Gust source calls.
8. Add inert AST-side metadata carriers for layout attributes without changing `StructLayout` payload shape or codegen.
9. Add explicit `#[repr(C)]` / `#[packed]` parser syntax and populate `StructDecl` layout metadata.
10. Add a payload-safe layout metadata store separate from `StructLayout`, with query helpers guarded by a focused registry fixture.
11. Define sandbox sub-arena ownership and destruction semantics for external calls without adding wrapper codegen or runtime behavior.
12. Add inert sandbox policy helper carriers over `FunctionSignature[ctx]` without changing parser syntax, runtime behavior, or codegen.
13. Define inert address-origin metadata that separates safe-arena, raw-derived, sandbox-derived, and unknown origins.
14. Add inert layout-aware FFI helper predicates that connect signature layout requirements to payload-safe struct layout metadata.
15. Extend provenance tracking so raw-derived and sandbox-derived values cannot be laundered into safe `Index[T, ctx]` or `&T[ctx]` through assignments, calls, returns, or containers.
16. Add narrow compiler-backed guards only after each semantic lane has a stable representation and focused positive/negative fixtures.

## Step 5.2 sequencing rule

Step 5.2 report-only scaffolding may remain in place, but Step 5.2 compiler-backed resource enforcement should not advance beyond inert design until these Step 5.1 deferred lanes are resolved or explicitly scoped as non-blocking. Resource ownership, destructor safety, and generalized handle tracking depend on knowing whether a value originated from safe arena construction, raw pointer manipulation, or external FFI.

## Guardrails

- Do not add regex-only failing guards for FFI, address escapes, layout annotations, sandbox arenas, or provenance laundering.
- Do not treat generated C strings, comments, type syntax, or runtime implementation details as direct user-facing unsafe operations.
- Do not mark the full Step 5.1 objective complete until FFI/layout/sandboxing, address-escape, and full provenance/non-laundering have compiler-backed semantics or an explicit deferral record.
