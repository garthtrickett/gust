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

The helper predicates classify whether an origin allows safe branding, whether it requires an unsafe boundary, and whether it is raw-or-sandbox-derived. These helpers are inert metadata utilities only. They do not yet replace the existing narrow local raw-derived pointer return guard. `make guard_step51_safe_constructor_provenance` verifies that compiler-recognized safe constructors such as `os.ArenaAlloc(ctx)` and `ctx.get_ref(safe_index)` are classified as safe-arena provenance while `ctx.get_ref(raw_index)` does not become eligible for safe branding. `make guard_step51_selector_safe_constructor_provenance` extends that metadata coverage through selector-field storage/readback so `ctx.get_ref(holder.safe_index)` preserves safe constructor provenance while `ctx.get_ref(holder.raw_index)` preserves unsafe-derived metadata instead of falling back to unknown provenance. `make guard_step51_container_safe_constructor_provenance` extends the same metadata coverage through indexed container-cell storage/readback so `ctx.get_ref(values[i])` preserves safe constructor provenance without laundering unsafe-derived container-cell metadata. `make guard_step51_container_method_provenance` verifies that keyed container storage methods such as `Vector.Set` and `HashMap.Insert/Set` also populate the inert container provenance map for later indexed readback. `make guard_step51_arena_write_provenance` verifies that explicit arena write APIs such as `Arena.Set` and `Arena.Write` populate the same inert container provenance map for `ctx[index]` readback. `make guard_step51_container_getref_provenance` verifies that `Vector.GetRef` and `HashMap.GetRef` classify reference provenance from the recorded container-cell metadata rather than treating container references as unknown-origin values. `make guard_step51_std_vector_getref_provenance` verifies that the function-style `std.VectorGetRef(vec, i)` accessor uses the same recorded container-cell provenance as `vec.GetRef(i)`. `make guard_step51_std_vector_getref_selector_alias_provenance` verifies that selector writes through `std.VectorGetRef(vec, i).field` populate canonical `values[i].field` readback aliases. `make guard_step51_reference_selector_alias_provenance` verifies that selector writes through reference accessors such as `ctx.get_ref(index).field` and `Vector.GetRef(i).field` also populate canonical `ctx[index].field` / `values[i].field` readback aliases.

### Provenance propagation and non-laundering design checkpoint

This checkpoint freezes the semantic propagation plan for broad unsafe non-laundering before Step 5.2 compiler-backed resource enforcement resumes. It is still a design checkpoint, not a diagnostic patch: no new rejection is enabled until the typechecker carries provenance state and focused guards exist.

The future typechecker should attach origin metadata to expression-check results, variable bindings, temporary values, return values, and container payload observations. The propagation model is conservative:

- `safe_arena` may only be produced by compiler-verified safe arena construction, safe arena reads, safe branded index access, or explicit future copy/validation APIs.
- `raw_derived` is produced by raw pointer casts, raw pointer dereferences that materialize an address-like value, pointer arithmetic, manual allocation, direct native address materialization, or values returned from direct external/native calls without a validated copy boundary.
- `sandbox_derived` is produced by transient sandbox-FFI storage, sandbox marshalling buffers, and values returned from sandbox calls before explicit caller-arena copying/validation.
- `unknown` is the conservative default for values whose origin cannot be proven. Unknown values are not eligible for safe branding until a later rule proves otherwise.

The join rule should never downgrade tainted origins into safe origins. Combining safe and raw-derived values yields raw-derived. Combining safe and sandbox-derived values yields sandbox-derived. Combining raw-derived and sandbox-derived values yields an unsafe-derived origin that must be treated as non-brandable; until a distinct combined tag exists, this may be represented as `unknown` plus a `requires_unsafe_boundary` predicate that returns true.

Propagation points for the first compiler-backed implementation should be:

1. **Expression results:** every checked expression returns both its resolved type and origin metadata. Existing pure value expressions default to safe or unknown according to their construction path.
2. **Assignments and local bindings:** assigning `rhs` to `lhs` copies or joins the RHS origin into the variable's tracked provenance state. Safe-looking target types do not erase raw-derived or sandbox-derived origin.
3. **Field writes and aggregate construction:** writing a tainted value into a struct, enum payload, `Option`, `LookupResult`, or other aggregate marks the stored field/payload tainted. Later field or payload reads recover that taint.
4. **Container storage:** storing tainted values in `std.Vector`, `std.HashMap`, or future containers marks the element/cell provenance. Reads through `.Get()`, `.get_opt()`, subscript copies, or reference accessors must preserve the stored origin rather than laundering it through the container API.
5. **Function calls:** direct external/native calls produce raw-derived or sandbox-derived return origins according to signature metadata and sandbox policy. Safe Gust calls propagate from declared or inferred return provenance. A safe wrapper may return safe-branded data only after an explicit validated copy into caller-owned safe arena storage.
6. **Returns:** returning raw-derived, sandbox-derived, or unknown unsafe-origin values as `Index[T, ctx]` or `&T[ctx]` must eventually reject with a non-laundering diagnostic. Returning raw pointers remains governed by unsafe context and existing escape-analysis rules until the broader guard lands.
7. **Brand construction:** safe branded `Index[T, ctx]` and `&T[ctx]` values can only be constructed from formal compiler-verified arena operations or later explicit validation/copy APIs. Unsafe blocks do not grant permission to rebrand raw-derived addresses as safe arena values.

The first implementation slice adds an inert `ExpressionProvenance[ctx]` carrier and helper functions only: expression-origin result plumbing, address-origin join predicates, default-safe/default-unknown/default-raw/default-sandbox constructors, and a compatibility bridge over the existing legacy `OriginSet[ctx]` root tracker. This slice is guarded by `make guard_step51_expression_provenance_carrier` and intentionally does not reject new programs.

The second inert implementation slice records expression provenance for local variable declarations and assignment targets in `TypeEnvironment.variable_provenance`, while continuing to mirror the established `variable_origins` behavior. Identifier expressions now read back `variable_provenance` through `check_expression_with_provenance`, so address-origin metadata can survive local aliasing and assignment chains without introducing diagnostics. This slice is guarded by `make guard_step51_variable_provenance_bindings` and remains non-enforcing: it records and reads address-origin/legacy-origin metadata but does not yet emit non-laundering diagnostics.

The third inert implementation slice records the provenance of return expressions in `TypeEnvironment.current_function_return_provenance` while continuing to update the legacy `current_function_return_origins` set. This slice is guarded by `make guard_step51_return_provenance_capture` and remains non-enforcing: it captures return-expression address-origin/legacy-origin metadata but does not yet reject safe-branded returns.

The fourth inert implementation slice records function return provenance in `TypeEnvironment.function_return_provenance` and lets call expressions read that metadata through `check_expression_with_provenance`. This slice is guarded by `make guard_step51_function_call_provenance` and remains non-enforcing: it preserves return-origin metadata across safe Gust call boundaries but does not yet reject laundering.

The fifth inert implementation slice records selector-field assignment provenance in `TypeEnvironment.field_provenance` and lets selector reads recover that metadata through `check_expression_with_provenance`. This slice is guarded by `make guard_step51_aggregate_field_provenance` and remains non-enforcing: it preserves address-origin/legacy-origin metadata through aggregate field storage and readback without rejecting laundering.

The sixth inert implementation slice records indexed container-cell assignment provenance in `TypeEnvironment.container_provenance` and lets indexed reads recover that metadata through `check_expression_with_provenance`. This slice is guarded by `make guard_step51_container_provenance` and remains non-enforcing: it preserves address-origin/legacy-origin metadata through container storage and readback without rejecting laundering.

The first enforcement slice is narrow and fixture-backed: returning a raw-derived or sandbox-derived value as a safe branded `Index[T, ctx]` or `&T[ctx]` now rejects with the stable diagnostic `Non-laundering violation`. This slice is guarded by `make guard_step51_non_laundering_return_enforcement` and intentionally applies only at return boundaries.

The second enforcement slice rejects binding or assigning raw-derived/sandbox-derived provenance into direct safe-branded `Index[T, ctx]` or `&T[ctx]` targets. This slice is guarded by `make guard_step51_non_laundering_binding_enforcement` and covers local variable declarations plus direct assignment targets without attempting API-specific aggregate/container rejection yet.

The third enforcement slice rejects passing raw-derived/sandbox-derived provenance into safe-branded `Index[T, ctx]` or `&T[ctx]` function parameters. This slice is guarded by `make guard_step51_non_laundering_call_enforcement` and covers direct safe Gust call-argument boundaries without attempting aggregate/container method-specific rejection yet.

The fourth enforcement slice guards aggregate field storage: assigning raw-derived/sandbox-derived provenance into a selector field whose resolved type is a safe-branded `Index[T, ctx]` or `&T[ctx]` rejects with the stable `Non-laundering violation` diagnostic. This slice is guarded by `make guard_step51_non_laundering_field_enforcement`; the typechecker applies a selector-storage target check so this does not depend on generic expression readback.

The fifth enforcement slice guards indexed container storage: assigning raw-derived/sandbox-derived provenance into an indexed container element whose resolved element type is a safe-branded `Index[T, ctx]` or `&T[ctx]` rejects with the stable `Non-laundering violation` diagnostic. This slice is guarded by `make guard_step51_non_laundering_container_enforcement`; the typechecker applies an indexed-storage target check for struct-backed containers with `data`/`values` element storage.

The sixth enforcement slice guards basic container storage methods: passing raw-derived/sandbox-derived provenance into `Vector.Push`, `Vector.Set`, or `HashMap.Insert/Set` where the stored element/value type is a safe-branded `Index[T, ctx]` or `&T[ctx]` rejects with the stable `Non-laundering violation` diagnostic. This slice is guarded by `make guard_step51_non_laundering_container_method_enforcement`.

The seventh enforcement slice guards explicit arena write APIs: passing raw-derived/sandbox-derived provenance through `Arena.Set` or `Arena.Write` where the write target index is a safe-branded `Index[T, ctx]` rejects with the stable `Non-laundering violation` diagnostic before ordinary element type compatibility is checked. This slice is guarded by `make guard_step51_non_laundering_arena_write_enforcement`. Unknown-origin safe-branded rejection remains deferred until compiler-internal safe constructors, parser/typechecker return indexes, field readback, and reference construction all have complete provenance classification. Broader enforcement can then be added incrementally after the variable provenance map, identifier readback path, return-provenance capture, function-call readback path, aggregate-field readback path, container readback path, indexed container write boundary, basic container method boundary, and explicit arena write boundary are stable.

### Layout-aware FFI validation helper checkpoint

The compiler now has inert layout-aware FFI helper predicates that connect direct FFI metadata to the payload-safe struct layout registry without rejecting programs yet. `function_signature_requires_layout_policy` reports whether a signature explicitly requires layout metadata. `env_struct_has_explicit_ffi_layout` reports whether a namespaced struct has any explicit layout metadata. `env_struct_satisfies_c_ffi_layout` reports whether a struct has `repr(C)` metadata with C ABI, and `env_struct_missing_c_ffi_layout` is the negative predicate for future diagnostics.

These helpers are guardable building blocks for later call-site validation. Type-level helpers now classify whether a resolved `ast.Type[ctx]` requires explicit C FFI layout, satisfies C FFI layout, or is missing C FFI layout. Signature-level helpers can scan resolved parameters and return types for missing C FFI layout when `requires_layout_metadata = 1`. They still do not reject extern declarations, emit C prototypes, alter struct layout codegen, or infer layout policy from broad text scans.

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
15. Add inert type/signature-level C FFI layout helpers over resolved params and return types without rejecting declarations.
16. Add an inert typechecker-side expression provenance carrier so resolved types can travel with `safe_arena`, `raw_derived`, `sandbox_derived`, or `unknown` origin metadata.
17. Propagate provenance through assignments, aggregate fields, container storage, function calls, returns, and safe-branding construction points without rejecting programs yet.
18. Add the first narrow non-laundering guard only after propagation is represented: reject raw-derived or sandbox-derived values returned as safe `Index[T, ctx]` or `&T[ctx]`.
19. Add further compiler-backed guards only after each semantic lane has a stable representation and focused positive/negative fixtures.

## Step 5.2 sequencing rule

Step 5.2 report-only scaffolding may remain in place, but Step 5.2 compiler-backed resource enforcement should not advance beyond inert design until these Step 5.1 deferred lanes are resolved or explicitly scoped as non-blocking. Resource ownership, destructor safety, and generalized handle tracking depend on knowing whether a value originated from safe arena construction, raw pointer manipulation, sandbox storage, or external FFI. In particular, `Resource[ctx, T]` handles and their future linear `Index[T, ctx]` aliases must only be born from safe arena or validated OS-resource constructors; raw-derived, sandbox-derived, and unknown unsafe-origin values must not be allowed to enter the generalized resource registry as trusted safe handles.

## Guardrails

- Do not add regex-only failing guards for FFI, address escapes, layout annotations, sandbox arenas, or provenance laundering.
- Do not treat generated C strings, comments, type syntax, or runtime implementation details as direct user-facing unsafe operations.
- Do not mark the full Step 5.1 objective complete until FFI/layout/sandboxing, address-escape, and full provenance/non-laundering have compiler-backed semantics or an explicit deferral record.
