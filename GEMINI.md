## 10. Gust Style Guide: Branding & Ephemeral Views Consistency

When writing or editing Gust (`.gst`) programs, you must strictly adhere to the following memory-safety and type-safety constraints enforced by the Gust typechecker.

### A. Ephemeral View Constraints on Structs
* **Rule:** Unbranded structs **cannot** contain ephemeral view types (such as `str` or `[]byte`). 
* **Action:** If a struct contains a `str` or slice field, it **must** be declared as a branded struct template.

```gust
// ❌ Incorrect (Typechecker will reject due to unbranded 'str' field)
type Test struct {
    path: str
}

// ✅ Correct (Branded template allowed to hold ephemeral views)
type Test[ctx] struct {
    path: str
}
```

### B. Strict Brand Propagation Rule
* **Rule:** Once a struct is declared with a brand parameter (e.g., `MyStruct[ctx]`), **every single reference** to that struct in the program must propagate the brand argument.
* **Why:** Referencing the raw template name `MyStruct` without its brand inside variable declarations, function parameters, or container types (like `std.Vector`) strips the brand. The compiler resolves it with an empty brand (`None`), triggering a **Brand Nesting Restriction violation** or an unbranded ephemeral error.

```gust
// ❌ Incorrect (RHS/LHS and vectors use unbranded 'Test' names)
type Test[ctx] struct {
    path: str
}
func run_test(ctx: &Arena, t: Test) int { ... } // ERROR: Unbranded parameter
func main() {
    mut tests: std.Vector[Test, ctx] := std.VectorNew(ctx); // ERROR: Unbranded vector element
    mut t1: Test; // ERROR: Unbranded variable
}

// ✅ Correct (All types propagate '[ctx]')
type Test[ctx] struct {
    path: str
}
func run_test(ctx: &Arena, t: Test[ctx]) int { ... } // CORRECT: Branded parameter
func main() {
    mut tests: std.Vector[Test[ctx], ctx] := std.VectorNew(ctx); // CORRECT: Branded vector element
    mut t1: Test[ctx]; // CORRECT: Branded variable
}
```
### C. Flat Function Scope & C-Redefinition Invariants
* **Rule:** All variables declared within a single function block (such as `func main()`) must have completely unique names across that entire block, even if they reside in separate logical phases, test steps, or conditional structures.
* **Why:** The Gust-to-C transpiler outputs variable declarations directly into flat C function scopes. Unlike more permissive high-level languages, C strictly prohibits redefining a variable name within the same block scope [2]. Attempting to declare `mut x` twice within the same function will compile cleanly in the Gust parser but trigger a fatal C compiler `redefinition of 'x'` error during the native compilation phase [2].
* **Action:** 
  * Never copy-paste test scaffolding blocks that reuse identical variable names (e.g., `empty_prog_vec` or `empty_prefixes`) [2].
  * Always append descriptive, context-specific suffixes to temporary test variables (e.g., use `empty_prog_vec_tl` and `empty_prefixes_tl` for thread-local tests, and `empty_prog_vec_dup` for deduplication tests) [2].

```gust
// ❌ Incorrect (Will transpile to C redefinitions in main's flat scope)
func main() {
    // Step 1
    mut empty_prog_vec: std.Vector[ast.Program[ctx], ctx] := std.VectorNew(ctx);
    ...
    // Step 2 (Scaffolding copy-pasted)
    mut empty_prog_vec: std.Vector[ast.Program[ctx], ctx] := std.VectorNew(ctx); // C ERROR: Redefinition
}

// ✅ Correct (Unique names per logical context)
func main() {
    // Step 1
    mut empty_prog_vec_dup: std.Vector[ast.Program[ctx], ctx] := std.VectorNew(ctx);
    ...
    // Step 2 
    mut empty_prog_vec_tl: std.Vector[ast.Program[ctx], ctx] := std.VectorNew(ctx); // Safe C transpilation
}

```

### D. Arena-Stored Vector Accessor Migration Pattern
* **Rule:** High-level compiler logic should not introduce new direct arena-to-vector casts such as `&ctx[some_index] as *std.Vector[...]` when a safe branded reference accessor can express the same operation.
* **Why:** Step 4.4 standardizes collection access around compiler-verified references before the later unsafe-gating phase. This keeps compiler traversal code aligned with branded lifetime checks while avoiding a broad raw-cast ban before Step 5.1.
* **Action:** In current compiler code, prefer a simple safe value-read pattern first: copy the arena-stored vector through `ctx[vector_index]`, then use normal vector indexing. Keep `ctx.get_ref(...).GetRef(...)` migration deferred until method lookup on branded reference receivers is fully supported in compiler sources. Keep low-level legacy casts only where a later migration step has not reached that file yet.

```gust
// ❌ Legacy migration target
unsafe {
    mut statements_vec := &ctx[prog.statements] as *std.Vector[ast.Statement[ctx], ctx];
    mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx[stmt_idx] = (*statements_vec)[0];
}

// ✅ Preferred Step 4.4 compiler-source pattern for now
mut statements_vec: std.Vector[ast.Statement[ctx], ctx] := ctx[prog.statements];
mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
ctx[stmt_idx] = statements_vec[0];
```

### E. Step 4.4 Checkpoint Validation Discipline
* **Rule:** Step 4.4 migration patches should be medium-sized coherent checkpoints, not microscopic edits. Each checkpoint must be large enough to justify the full validation cost, but small enough to revert or bisect cleanly.
* **Accessor Contract:** Before migrating compiler internals, keep the additive accessor surface stable: legacy `.Get()`, additive `.get_opt()`, `Vector.GetRef`, `std.VectorGetRef`, and `HashMap.GetRef` must continue to coexist.
* **Inventory Before Enforcement:** Use `make report_high_level_raw_collection_casts` to inventory remaining high-level compiler raw casts. This target is report-only during Step 4.4. Do not convert it into a failing guard until the relevant file or migration slice is clean.
* **Migrated Slice Guards:** Once a coherent migration slice is clean, add a narrow guard for only that slice and wire it into `make test`. For example, `guard_step44_low_risk_entry_raw_casts` protects the first low-risk entrypoint slice, `guard_step44_typechecker_aux_raw_casts` protects migrated typechecker auxiliary test entries, `guard_step44_typechecker_types_raw_casts` protects the typechecker type-regression entry, `guard_step44_codegen_initializer_raw_casts` protects the codegen initializer regression entry, `guard_step44_typechecker_early_raw_casts` protects the first production typechecker slice, `guard_step44_typechecker_methods_raw_casts` protects the migrated method-receiver slice, `guard_step44_typechecker_pool_graph_raw_casts` protects the Pool/Graph/top-level builtin slice, `guard_step44_typechecker_call_validation_raw_casts` protects the general call-validation slice, `guard_step44_typechecker_generic_helpers_raw_casts` protects type construction/generic substitution helpers, `guard_step44_typechecker_template_registration_raw_casts` protects template monomorphization/registration, `guard_step44_typechecker_env_registration_raw_casts` protects env type resolution plus struct/enum/function pre-registration, `guard_step44_typechecker_brand_helpers_raw_casts` protects block/string/brand helper traversal, `guard_step44_typechecker_function_checks_raw_casts` protects type matching plus function body/inout checks, `guard_step44_typechecker_statement_traversal_raw_casts` protects late statement traversal, `guard_step44_codegen_early_helpers_raw_casts` protects early codegen helper traversal/type-erasure, `guard_step44_codegen_dispatch_methods_raw_casts` protects codegen Channel/Vector/HashMap method dispatch, `guard_step44_codegen_pool_graph_std_raw_casts` protects codegen Pool/Graph/std helper overrides, `guard_step44_codegen_std_alloc_helpers_raw_casts` protects std formatting/allocation helper overrides, `guard_step44_codegen_runtime_tail_raw_casts` protects runtime helper tail plus generic call fallback, `guard_step44_codegen_statement_emit_raw_casts` protects codegen block/function/guard/match statement emission, `guard_step44_codegen_program_passes_raw_casts` protects final codegen program-level passes, and `guard_step44_no_high_level_raw_collection_casts` protects the completed whole-compiler high-level raw collection/string accessor migration.
* **Checkpoint Commands:** Before committing any Step 4.4 patch that touches compiler, runtime, tests, Makefile validation, or bootstrap-sensitive files, run:

```bash
make
make report_step44_accessor_contract
# Run the focused gt-one-gst commands printed by report_step44_accessor_contract.
make test
make bootstrap
git diff --check
```

* **Known Red Tests:** If the full suite has pre-existing failures, they must be explicitly documented before the checkpoint. A Step 4.4 patch may only proceed when it introduces no new full-suite failures and `make bootstrap` still converges.

### F. Step 4.5A Read-Only Subscript & Explicit Write Boundary
* **Rule:** Subscript indexing syntax such as `ctx[index]`, `vec[i]`, and `map_like[key]` is a safe read expression. It should be treated as copy-by-default in high-level compiler and user code, not as an implicit mutable borrow.
* **Transitional Write Boundary:** Direct subscript writes such as `ctx[index] = value` are still allowed during Step 4.5A because the compiler and tests have not yet been migrated to explicit write APIs. These writes are transitional inventory targets, not the long-term safe-code style.
* **Future Safe-Code Mutation Form:** Safe code should move toward explicit write-back APIs such as `ctx.Set(index, value)` / `ctx.Write(index, value)` and container-level write APIs such as `vec.Set(i, value)` or `map.Insert(key, value)` / `map.Set(key, value)` where replacement is required. Direct mutation through a borrowed reference should use explicit reference-access methods such as `ctx.get_ref(index)`, `vec.GetRef(i)`, or `map.GetRef(key)`.
* **Deferred Enforcement:** Do not add the typechecker ban for subscript expressions on the assignment LHS in Step 4.5A. Enforcement belongs to the later Step 4.5C/unsafe-boundary work, after explicit write APIs exist and compiler sources have been migrated. When enforcement lands, it must reject direct subscript LHS assignment only in safe code and continue to permit low-level direct subscript writes inside explicit unsafe blocks where required.
* **Inventory Before Enforcement:** Use `make report_step45_subscript_lvalue_writes` to inventory remaining direct subscript writes. This target is report-only during Step 4.5A and must not be wired as a failing guard until the write API and compiler migration steps are complete.
* **Accessor Contract:** Use `make report_step45_accessor_contract` to list the focused Step 4.5A checks for explicit arena writes, vector writes, hash map writes, and read-copy subscript semantics. Run the listed `gt-one-gst` commands before `make test` / `make bootstrap` on Step 4.5A patches.
* **Final Validation Checklist:** Use `make report_step45_final_validation` before closing Step 4.5. This target prints the focused Step 4.5A accessor checks, Step 4.4 regression checks, Step 4.5 subscript-write inventories, the Step 4.5C unsafe-boundary enforcement guard, full `make test`, bootstrap, and diff whitespace checks. It is report-only; enforcement belongs to the compiler-backed Step 4.5C guard rather than raw regex inventory alone.
* **Step 4.5B Bootstrap-Safe Migration:** Migrate user-facing tests and examples to explicit write APIs first. For compiler sources that are compiled by `gust_bootstrap`, do not introduce `ctx.Set(...)` until the bootstrap compiler has converged with the fixed Arena `Set` / `Write` codegen. In compiler sources, prefer explicit field borrows such as `ctx.get_ref(index).field = value` where possible, or leave direct full-slot writes as transitional inventory until a dedicated bootstrap-safe migration checkpoint.
* **Test-Side Inventory:** Use `make report_step45_test_subscript_lvalue_writes` to confirm test files remain clean of direct subscript LHS writes after Step 4.5B test migration. This target is report-only and must not be wired as a failing guard until enforcement policy is finalized.
* **Step 4.5C Enforcement Guard:** Once safe-code subscript LHS enforcement lands, use `make guard_step45_safe_subscript_write_enforcement` to prove the compiler rejects safe direct subscript writes with the stable diagnostic `direct subscript writes require unsafe or explicit write APIs`, while still accepting the same assignment forms inside explicit `unsafe` blocks. Use `make report_step45_subscript_lvalue_classified` for human-readable inventory triage across generated C string false positives, intentional safe-code rejection fixtures, intentional unsafe-positive fixtures, and unexpected safe-code direct writes. Regex inventory targets remain informational because generated C string literals and intentional enforcement fixtures can appear in simple text scans.

### G. Phase 4A Autoformatter Infrastructure
* **Scope:** Phase 4A is tooling scaffolding only. Add treefmt, Topiary, rustfmt, and clang-format availability checks plus checked-in placeholder config files, but do not run repo-wide formatting yet.
* **No Formatting Churn:** Do not run repo-wide formatting until Phase 4B after Phase 5/6. Formatting rollout should happen as a dedicated formatting-only commit so compiler safety work remains easy to bisect and patch.
* **Targets:** Use `make report_phase4_formatter_tools` to report formatter binary availability in the current shell. Use `make fmt_check_phase4_infra` to verify scaffold files exist. These targets must not format files and must not be wired into `make test` during Phase 4A.
* **Deferred Phase 4B Work:** Complete `topiary/languages.ncl`, write the Gust Topiary query file, enable `treefmt.toml` formatter blocks, add formatter golden/sample checks, and only then perform a controlled repo-wide formatting rollout.

### H. Step 5.1 Raw Pointer Safety Inventory Discipline
* **Scope:** Step 5.1 introduces gated raw pointers, unsafe blocks/functions, and sandboxed FFI. The first checkpoint is inventory-only: identify raw pointer dereferences, raw pointer casts/address escapes, direct FFI candidates, and unsafe function signature syntax needs before enforcing anything.
* **Bootstrap Sequencing:** Do not enable strict raw pointer, raw cast, or FFI gating until the compiler source and standard-library collection internals have been proactively wrapped in explicit `unsafe { ... }` blocks. Phase A parser/typechecker work must remain additive and no-op so bootstrap can converge while migration proceeds.
* **Inventory Targets:** Use `make report_step51_raw_pointer_safety_inventory` for the combined report. Individual report-only targets are `make report_step51_raw_pointer_deref`, `make report_step51_raw_pointer_casts`, `make report_step51_address_escapes_focused`, `make report_step51_ffi_calls`, `make report_step51_ffi_focused`, `make report_step51_unsafe_func_signatures`, `make report_step51_raw_pointer_classified`, `make report_step51_raw_pointer_safe_code_candidates`, `make report_step51_phase_b_wrapping_status`, `make report_step51_phase_c_basic_unsafe_status`, `make report_step51_phase_d_ffi_status`, `make report_step51_phase_e_address_escape_status`, `make report_step51_phase_f_non_laundering_status`, `make report_step51_deferred_unsafe_semantics_status`, and `make report_step51_status_matrix`.
* **No Regex Enforcement:** These Step 5.1 inventory targets are broad textual scans and must not be wired into `make test` as failing guards. Later enforcement must be AST/typechecker-based so pointer syntax inside type expressions, generated C strings, comments, and intentional unsafe fixtures does not create false positives. Use the classified report to triage likely expression dereferences, type syntax, raw casts, address escapes, generated C/codegen templates, intentional tests, and unclassified migration candidates before wrapping code. Use the focused safe-code candidate report to separate likely outside-unsafe raw operations from sites already in explicit unsafe contexts, including both `unsafe { ... }` blocks and `unsafe func` bodies; keep that helper report-only and treat it as migration guidance, not proof of safety. Its reference/type/intentional-fixture buckets are classification aids, not enforcement exemptions.
* **Unsafe Function Semantics:** Prefer Rust-like semantics for `unsafe func`: the function body may perform unsafe operations, and call sites must be inside an explicit unsafe context unless the unsafe operation is internally wrapped behind a safe API. Add parser/typechecker no-op support before requiring this rule.
* **Phase 5.1A No-Op Support:** During Phase 5.1A, `unsafe func` syntax is parsed and stored as function metadata, but call-site enforcement remains deferred. The legacy positive fixture `tests/e2e_unsafe_function_signature_noop.gst` continues to validate unsafe function signature parsing and typechecking, but after Phase 5.1C unsafe-call enforcement its call site must be inside an explicit `unsafe { ... }` block.
* **Phase 5.1B Wrapping Order:** Start proactive wrapping with low-risk compiler test-entry files and explicit test fixtures before production parser/typechecker/codegen slices. Wrap actual raw pointer dereferences, raw pointer casts, and address escapes in `unsafe { ... }`, but leave type syntax, generated C strings, comments, and intentional future negative fixtures alone. For existing negative tests whose purpose is not raw pointer gating, wrap downstream dereferences in `unsafe` so future Step 5.1C diagnostics do not mask the original expected error. Once `make report_step51_phase_b_wrapping_status` shows no likely safe-code raw operation candidates, stop regex-driven wrapping churn and move to AST/typechecker enforcement design.
* **Phase 5.1C Raw Deref Guard:** `make guard_step51_raw_deref_unsafe_enforcement` is the first narrow compiler-backed enforcement guard. It must prove raw pointer dereference outside `unsafe` rejects with the stable diagnostic `Dereferencing raw pointers is strictly prohibited outside 'unsafe' blocks`, while the same dereference inside explicit `unsafe` still compiles. Raw deref negative fixtures such as `tests/test_raw_pointer_deref_outside_unsafe_rejected.gst` belong in the focused report's intentional raw-gating bucket, not the safe-code wrapping bucket.
* **Phase 5.1C Raw Cast Guard:** `make guard_step51_raw_cast_unsafe_enforcement` is the second narrow compiler-backed enforcement guard. It must prove casts to raw pointer types outside `unsafe` reject with the stable diagnostic `Raw pointer casts are strictly prohibited outside 'unsafe' blocks`, while the same cast inside explicit `unsafe` still compiles. Raw cast negative fixtures such as `tests/test_raw_pointer_cast_outside_unsafe_rejected.gst` belong in the focused report's intentional raw-gating bucket.
* **Phase 5.1C Pointer Arithmetic Guard:** `make guard_step51_pointer_arithmetic_unsafe_enforcement` guards the existing pointer arithmetic unsafe boundary. It must prove pointer arithmetic outside `unsafe` rejects with the stable diagnostic `Pointer arithmetic is strictly prohibited outside 'unsafe' blocks`, while the same operation inside explicit `unsafe` still compiles. The positive fixture should consume the derived pointer locally rather than returning it, because returning raw-derived values is covered by the separate escape/non-laundering boundary.
* **Phase 5.1C Unsafe Function Call Guard:** `make guard_step51_unsafe_func_call_enforcement` enforces the Rust-like `unsafe func` call boundary. Calling an `unsafe func` outside explicit `unsafe` must reject with the stable diagnostic `Unsafe function calls require an explicit 'unsafe' block`, while calling the same function inside explicit `unsafe` still compiles. Unsafe function bodies are checked as unsafe contexts so they may contain raw dereferences, raw casts, and pointer arithmetic without an additional nested `unsafe { ... }`; `tests/e2e_unsafe_func_body_raw_ops.gst` guards this body-context behavior. The focused safe-code report must classify raw operations inside `unsafe func` bodies as already unsafe-context sites, not safe-code wrapping candidates. Existing positive unsafe-function fixtures must call unsafe functions from an unsafe context once this guard is enabled. Address escapes, FFI gating, and non-laundering remain separate follow-up milestones.
* **Phase 5.1C Raw Pointer Local Escape Guard:** `make guard_step51_raw_pointer_local_escape_enforcement` guards the existing escape-analysis boundary for raw-derived local pointer values. Returning a local raw-derived pointer must reject with a diagnostic containing `Returning ephemeral view of type RawPointer`. This is a narrow guard for local raw pointer escape analysis, not the full unsafe non-laundering milestone. Its negative fixture `tests/test_raw_pointer_return_derived_local_rejected.gst` belongs in the focused report's intentional raw-gating bucket, not the safe-code wrapping bucket.
* **Phase 5.1C Basic Unsafe Enforcement Aggregate:** `make guard_step51_basic_unsafe_enforcement` groups the compiler-backed Step 5.1C subguards for raw dereference, raw cast, pointer arithmetic, unsafe-function calls, and raw-pointer local escape analysis. `make test` should depend on this aggregate so the basic unsafe boundary is enforced as one coherent gate while keeping the individual subguards available for focused diagnosis. Use `make report_step51_phase_c_basic_unsafe_status` for a report-only summary of the covered subguards and the still-deferred address-escape, FFI, and broader non-laundering milestones.
* **Step 5.1 Basic Closure Snapshot:** Treat Step 5.1 basic unsafe enforcement as closed once `make guard_step51_basic_unsafe_enforcement` passes: unsafe syntax, unsafe-block contexts, unsafe-function call gating, raw dereference gating, raw pointer cast gating, pointer-arithmetic gating, unsafe-function body contexts, and narrow local raw-derived pointer return escape are compiler-backed. Do not mark the full Step 5.1 objective complete yet; direct FFI gating, layout annotations, sandboxed FFI sub-arenas, address-escape enforcement, and full non-laundering/provenance tracking remain deferred compiler-design work.
* **Step 5.1 Deferred Unsafe Semantics Checkpoint:** `STEP51_DEFERRED_UNSAFE_SEMANTICS.md` is the sequencing anchor for finishing Step 5.1 before Step 5.2 compiler-backed enforcement resumes. `make report_step51_deferred_unsafe_semantics_status` is the report-only Makefile handoff for that checkpoint. Keep both focused on direct FFI syntax, layout attributes, sandbox sub-arenas, address-origin metadata, and raw-derived provenance/non-laundering. This file and status target must remain visible in `a.txt` through `c.sh` / `concat.config` so follow-up patches can reason from the same Step 5.1 design checkpoint.
* **Phase 5.1D FFI Status:** `make report_step51_phase_d_ffi_status` is the report-only handoff into the FFI gating, layout-annotation, and sandboxed-FFI milestones. Keep both `make report_step51_ffi_calls` and `make report_step51_ffi_focused` visible in `a.txt` before designing compiler-backed FFI enforcement. The focused helper separates direct Gust source candidates from native runtime boundary hits, generated string/template references, and comment-only references, then prints summary counts. It must use token-aware matching so ordinary identifiers like `suffix` and `generic_call` do not appear as `ffi` or `c_call` candidates. If the focused helper reports zero direct Gust source candidates, do not invent an FFI guard; keep enforcement deferred until a real direct external/native-call syntax surface exists. Do not wire broad or focused FFI text scans into `make test`; the eventual guard must be syntax-aware and should only enforce direct external/native-call forms that the compiler can classify reliably. `#[repr(C)]`, `#[packed]`, and sandbox sub-arena support are also deferred until parser/typechecker/codegen semantics exist.
* **Step 5.1D Direct FFI Syntax Surface:** The first FFI design checkpoint is semantic metadata, not enforcement: direct external/native function declarations should eventually carry fields such as `is_extern`, `extern_symbol_name`, `extern_abi`, `requires_unsafe_call`, `requires_layout_metadata`, and `requires_sandbox_arena`. `FunctionSignature[ctx]` may carry those fields inertly, and compiler-created signatures should call `init_function_signature_ffi_defaults` so ordinary functions remain non-extern with no layout/sandbox requirements. `FunctionDecl` may also carry the same inert fields through the AST; ordinary functions should initialize as non-extern, while explicit `extern func` syntax may populate `is_extern = 1`, default `extern_symbol_name` to the function name, default `extern_abi` to `C`, and set `requires_unsafe_call = 1`. Bodyless `extern func ...;` signatures are allowed only as inert declarations: the parser synthesizes an empty AST body so the typechecker can register metadata, but no C emission or linking behavior is implied. `make guard_step51_extern_func_parser_metadata` guards both bodyful and bodyless parser metadata handoffs. `make guard_step51_extern_func_call_enforcement` guards compiler-backed direct extern/native call-site gating with the stable diagnostic `Direct external/native function calls require an explicit 'unsafe' block`. `StructDecl` may carry inert layout metadata fields shaped for `#[repr(C)]` and `#[packed]`; `StructLayout` must remain payload-small while existing `struct_registry.get_opt(...)` / `Some { val }` codegen paths return it by value. The parser accepts `#[repr(C)]`, `#[packed]`, and their combination before `type ... struct` declarations. `TypeEnvironment` should store layout metadata in payload-safe primitive/string maps keyed by namespaced struct name instead of enlarging `StructLayout`; helpers such as `env_struct_is_repr_c`, `env_struct_is_packed`, `env_struct_layout_abi_is_c`, and `env_struct_requires_layout_metadata` should be used for later layout-aware validation so raw ABI strings do not escape lookup wrappers. `make guard_step51_layout_metadata_defaults` guards ordinary defaults, explicit attribute metadata, and registry helper lookups. Sandboxed FFI sub-arena semantics are documented at the design-checkpoint level: a sandbox arena is a transient external-call wrapper, is destroyed on return, and must not leak raw-derived or sandbox-origin values into safe branded caller references. `FunctionSignature[ctx]` may expose inert helper predicates such as `function_signature_requires_sandbox_arena`, `function_signature_requires_sandbox_policy`, and `function_signature_requires_ffi_policy`; `make guard_step51_sandbox_policy_defaults` guards that these helpers only reflect explicit metadata and do not imply sandboxing for ordinary extern calls. `AddressOriginMetadata` may classify safe-arena, raw-derived, sandbox-derived, and unknown origins; `make guard_step51_address_origin_metadata` guards the inert helper predicates for safe-branding eligibility and unsafe-boundary requirements. Layout-aware FFI helper predicates such as `function_signature_requires_layout_policy`, `env_struct_has_explicit_ffi_layout`, `env_struct_satisfies_c_ffi_layout`, and `env_struct_missing_c_ffi_layout` may connect signature layout requirements to the payload-safe struct layout registry without rejecting programs; `make guard_step51_layout_ffi_policy_helpers` guards that helper layer. Type/signature-level helpers such as `env_type_requires_explicit_c_ffi_layout`, `env_type_satisfies_c_ffi_layout`, `env_type_missing_c_ffi_layout`, and `function_signature_missing_c_ffi_layout` may scan resolved params and return types for missing C FFI layout when layout policy is active; `make guard_step51_layout_ffi_signature_helpers` guards those helpers without enabling declaration or call-site rejection. Codegen layout changes, layout-aware call-site rejection, sandbox wrapper implementation, runtime arena APIs, propagation through assignments/calls/returns/containers, and broader provenance enforcement remain deferred. Only parsed Gust source declarations/calls with direct FFI metadata should become FFI enforcement candidates. Runtime C `extern` declarations, generated C snippets, comments, and safe wrapper APIs are not direct user-facing FFI candidates by themselves.
* **Phase 5.1E Address Escape Status:** `make report_step51_phase_e_address_escape_status` is the report-only handoff into the address-escape milestone. Keep `make report_step51_address_escapes_focused` visible in `a.txt` before designing compiler-backed address-escape enforcement. The focused helper separates direct safe-code address/indexed-address candidates from already-unsafe address expressions, branded reference type/cast syntax, intentional raw-cast gating fixtures, generated string/template references, and comment-only references, then prints summary counts. Do not treat `&Type[ctx]`, `env: &SomeType[ctx]`, function return reference syntax, or casts like `payload as &CustomNode[ctx]` as address escapes; those are reference type/cast classification aids. Raw-cast negative fixtures such as `tests/test_deref_outside_unsafe_rejected.gst` and `tests/test_raw_pointer_cast_outside_unsafe_rejected.gst` belong in the intentional raw-cast gating bucket, not the safe-code address-escape bucket. Do not treat address expressions inside `unsafe { ... }` or `unsafe func` bodies as safe-code enforcement candidates; they are still useful inventory but belong in the already-unsafe bucket. Do not wire broad or focused address-escape text scans into `make test`; the eventual guard must be compiler-backed and semantic because address-taking can be safe reference construction, raw pointer materialization, or generated/runtime plumbing depending on context.
* **Phase 5.1F Non-Laundering Status:** `make report_step51_phase_f_non_laundering_status` is the report-only handoff into broader unsafe non-laundering/provenance tracking. The existing `make guard_step51_raw_pointer_local_escape_enforcement` guard is intentionally narrow; it protects the current local raw-derived return escape boundary but does not prove full non-laundering. `ExpressionProvenance[ctx]` is now the inert typechecker-side carrier for this lane, `TypeEnvironment.variable_provenance` records local declaration/assignment metadata, `TypeEnvironment.current_function_return_provenance` captures return-expression metadata, `TypeEnvironment.function_return_provenance` preserves return metadata for call-expression readback, `TypeEnvironment.field_provenance` preserves selector-field assignment/readback metadata, and `TypeEnvironment.container_provenance` preserves indexed container-cell assignment/readback metadata. `make guard_step51_non_laundering_return_enforcement` covers safe-branded return boundaries, `make guard_step51_non_laundering_binding_enforcement` covers direct safe-branded local bindings/assignments, `make guard_step51_non_laundering_call_enforcement` covers direct safe-branded call-argument boundaries, `make guard_step51_non_laundering_field_enforcement` covers direct safe-branded selector-field writes, `make guard_step51_non_laundering_container_enforcement` covers direct safe-branded indexed container writes, `make guard_step51_non_laundering_container_method_enforcement` covers basic safe-branded container storage methods, `make guard_step51_non_laundering_arena_write_enforcement` covers explicit safe-branded `Arena.Set` / `Arena.Write` storage, `make guard_step51_non_laundering_reference_selector_enforcement` covers safe-branded reference-selector field writes, `make guard_step51_non_laundering_hashmap_get_value_enforcement` covers safe-branded `HashMap.Get(key).Val` copied value readback, and `make guard_step51_non_laundering_hashmap_get_value_field_enforcement` covers safe-branded `HashMap.Get(key).Val.field` copied field readback. Unknown-origin safe-branded rejection remains deferred until compiler-internal safe constructors and parser/typechecker return indexes have complete provenance classification. Broader diagnostics beyond these direct safe-branded storage/call/return/reference-selector/HashMap.Get-value/HashMap.Get-value-field boundaries remain deferred.
* **Step 5.1 Provenance Carrier Guard:** `make guard_step51_expression_provenance_carrier` verifies the inert expression provenance carrier, address-origin join behavior, legacy `OriginSet[ctx]` compatibility, and the non-enforcing `check_expression_with_provenance` bridge. This guard may be wired into `make test` because it validates helper behavior only; it must not emit non-laundering diagnostics or replace the later narrow enforcement fixture.
* **Step 5.1 Safe Constructor Provenance Guard:** `make guard_step51_safe_constructor_provenance` verifies that compiler-recognized safe constructors such as `os.ArenaAlloc(ctx)` and `ctx.get_ref(safe_index)` produce safe-arena provenance metadata, while `ctx.get_ref(raw_index)` does not become eligible for safe branding. This guard is metadata-only and does not enable unknown-origin rejection.
* **Step 5.1 Selector Safe Constructor Provenance Guard:** `make guard_step51_selector_safe_constructor_provenance` verifies that selector-field assignment/readback preserves safe constructor provenance into `ctx.get_ref(holder.safe_index)`, while raw-derived selector-field provenance remains unsafe-derived through `ctx.get_ref(holder.raw_index)` and does not become eligible for safe branding. This guard is metadata-only and does not enable unknown-origin rejection.
* **Step 5.1 Container Safe Constructor Provenance Guard:** `make guard_step51_container_safe_constructor_provenance` verifies that indexed container-cell assignment/readback preserves safe constructor provenance into `ctx.get_ref(values[i])`, while raw-derived container-cell provenance remains unsafe-derived and does not become eligible for safe branding. This guard is metadata-only and does not enable unknown-origin rejection.
* **Step 5.1 Container Method Provenance Guard:** `make guard_step51_container_method_provenance` verifies that keyed storage methods such as `Vector.Set` and `HashMap.Insert/Set` record inert container-cell provenance for later indexed readback. This guard is metadata-only and does not enable unknown-origin rejection.
* **Step 5.1 Arena Write Provenance Guard:** `make guard_step51_arena_write_provenance` verifies that explicit `Arena.Set` / `Arena.Write` APIs record inert arena-slot provenance for later `ctx[index]` readback. This guard is metadata-only and does not enable unknown-origin rejection.
* **Step 5.1 Container GetRef Provenance Guard:** `make guard_step51_container_getref_provenance` verifies that `Vector.GetRef` and `HashMap.GetRef` derive inert reference provenance from recorded container-cell metadata, preserving safe-arena origins and raw/sandbox-derived origins without falling back to unknown provenance. This guard is metadata-only and does not enable unknown-origin rejection.
* **Step 5.1 HashMap.Get Value Provenance Guard:** `make guard_step51_hashmap_get_value_provenance` verifies that copied safe-branded values read through `HashMap.Get(key).Val` derive inert provenance from the same recorded container-cell metadata as `map[key]`, preserving safe-arena origins and raw/sandbox-derived origins without falling back to unknown provenance. This guard is metadata-only and does not enable unknown-origin rejection.
* **Step 5.1 HashMap.Get Value Field Provenance Guard:** `make guard_step51_hashmap_get_value_field_provenance` verifies that copied field reads through `HashMap.Get(key).Val.field` derive inert provenance from canonical `map[key].field` metadata, preserving safe-arena origins and raw/sandbox-derived origins without falling back to unknown provenance. This guard is metadata-only and does not enable unknown-origin rejection.
* **Step 5.1 std.VectorGetRef Provenance Guard:** `make guard_step51_std_vector_getref_provenance` verifies that function-style `std.VectorGetRef(vec, i)` derives inert reference provenance from the same recorded container-cell metadata as `vec.GetRef(i)`, preserving safe-arena origins and raw/sandbox-derived origins without falling back to unknown provenance. This guard is metadata-only and does not enable unknown-origin rejection.
* **Step 5.1 std.HashMapGetRef Provenance Guard:** `make guard_step51_std_hashmap_getref_provenance` verifies that function-style `std.HashMapGetRef(map, key)` derives inert reference provenance from the same recorded container-cell metadata as `map.GetRef(key)`, preserving safe-arena origins and raw/sandbox-derived origins without falling back to unknown provenance. This guard is metadata-only and does not enable unknown-origin rejection.
* **Step 5.1 std.HashMapGetRef Selector Alias Provenance Guard:** `make guard_step51_std_hashmap_getref_selector_alias_provenance` verifies that selector writes through function-style `std.HashMapGetRef(map, key).field` record canonical field-provenance aliases for later `map[key].field` readback. This guard is metadata-only and does not enable unknown-origin rejection.
* **Step 5.1 std.VectorGetRef Selector Alias Provenance Guard:** `make guard_step51_std_vector_getref_selector_alias_provenance` verifies that selector writes through function-style `std.VectorGetRef(vec, i).field` record canonical field-provenance aliases for later `values[i].field` readback. This guard is metadata-only and does not enable unknown-origin rejection.
* **Step 5.1 Reference Selector Alias Provenance Guard:** `make guard_step51_reference_selector_alias_provenance` verifies that selector writes through reference accessors such as `ctx.get_ref(index).field`, `Vector.GetRef(i).field`, and `HashMap.GetRef(key).field` also record canonical field-provenance aliases for later `ctx[index].field` / `values[i].field` / `map[key].field` readback. This guard is metadata-only and does not enable unknown-origin rejection.
* **Step 5.1 Variable Provenance Guard:** `make guard_step51_variable_provenance_bindings` verifies that local variable declarations and assignment targets populate `TypeEnvironment.variable_provenance`, and that identifier expressions read back that provenance through `check_expression_with_provenance`. This preserves both legacy origin sets and inert address-origin metadata across local aliasing/assignment chains. This guard is intentionally metadata-only and must not emit non-laundering diagnostics.
* **Step 5.1 Return Provenance Guard:** `make guard_step51_return_provenance_capture` verifies that return statements capture expression provenance into `TypeEnvironment.current_function_return_provenance` while preserving the existing legacy `current_function_return_origins` behavior. This guard is intentionally metadata-only and must not emit non-laundering diagnostics.
* **Step 5.1 Function Call Provenance Guard:** `make guard_step51_function_call_provenance` verifies that call expressions read inert return provenance from `TypeEnvironment.function_return_provenance` and preserve it into local variable provenance. This guard is intentionally metadata-only and must not emit non-laundering diagnostics.
* **Step 5.1 Aggregate Field Provenance Guard:** `make guard_step51_aggregate_field_provenance` verifies that selector-field assignments record inert provenance in `TypeEnvironment.field_provenance` and selector reads preserve that metadata into local variable provenance. This guard is intentionally metadata-only and must not emit non-laundering diagnostics.
* **Step 5.1 Container Provenance Guard:** `make guard_step51_container_provenance` verifies that indexed container-cell assignments record inert provenance in `TypeEnvironment.container_provenance` and indexed reads preserve that metadata into local variable provenance. This guard is intentionally metadata-only and must not emit non-laundering diagnostics.
* **Step 5.1 Non-Laundering Return Guard:** `make guard_step51_non_laundering_return_enforcement` verifies that raw-derived or sandbox-derived values cannot be returned as safe branded `Index[T, ctx]` or `&T[ctx]` values. This is the first narrow non-laundering diagnostic guard; broader call, aggregate, and container rejection policies remain follow-up work.
* **Step 5.1 Non-Laundering Binding Guard:** `make guard_step51_non_laundering_binding_enforcement` verifies that raw-derived or sandbox-derived values cannot be bound or assigned into direct safe branded `Index[T, ctx]` or `&T[ctx]` targets. This guard covers local declarations and direct assignments only; API-specific aggregate/container rejection remains follow-up work.
* **Step 5.1 Non-Laundering Call Guard:** `make guard_step51_non_laundering_call_enforcement` verifies that raw-derived or sandbox-derived values cannot be passed into direct safe branded `Index[T, ctx]` or `&T[ctx]` function parameters. This guard covers safe Gust call-argument boundaries only; aggregate/container method-specific rejection remains follow-up work.
* **Step 5.1 Non-Laundering Field Guard:** `make guard_step51_non_laundering_field_enforcement` verifies that raw-derived or sandbox-derived values cannot be assigned into direct safe branded selector-field targets. This guard covers aggregate field writes whose resolved field type is a safe branded `Index[T, ctx]` or `&T[ctx]`; container method-specific rejection remains follow-up work.
* **Step 5.1 Non-Laundering Container Guard:** `make guard_step51_non_laundering_container_enforcement` verifies that raw-derived or sandbox-derived values cannot be assigned into direct safe branded indexed container elements. This guard covers struct-backed indexed writes whose resolved `data`/`values` element type is a safe branded `Index[T, ctx]` or `&T[ctx]`; container method-specific API rejection remains follow-up work.
* **Step 5.1 Non-Laundering Container Method Guard:** `make guard_step51_non_laundering_container_method_enforcement` verifies that raw-derived or sandbox-derived values cannot be stored through `Vector.Push`, `Vector.Set`, or `HashMap.Insert/Set` when the stored element/value type is a safe branded `Index[T, ctx]` or `&T[ctx]`. This guard covers basic storage methods only; remaining wrapper/API-specific rejection remains follow-up work.
* **Step 5.1 Non-Laundering Arena Write Guard:** `make guard_step51_non_laundering_arena_write_enforcement` verifies that raw-derived or sandbox-derived values cannot be stored through explicit `Arena.Set` / `Arena.Write` APIs when the write target index is a safe branded `Index[T, ctx]`. This guard covers explicit arena write APIs only; remaining wrapper/API-specific rejection remains follow-up work.
* **Step 5.1 Non-Laundering Reference Selector Guard:** `make guard_step51_non_laundering_reference_selector_enforcement` verifies that raw-derived or sandbox-derived values cannot be assigned through reference selector accessors such as `ctx.get_ref(index).field`, `Vector.GetRef(i).field`, `HashMap.GetRef(key).field`, `std.VectorGetRef(vec, i).field`, or `std.HashMapGetRef(map, key).field` when the resolved field type is a safe branded `Index[T, ctx]` or `&T[ctx]`. This guard covers reference-selector field writes only; remaining wrapper/API-specific rejection remains follow-up work.
* **Step 5.1 Non-Laundering HashMap.Get Value Guard:** `make guard_step51_non_laundering_hashmap_get_value_enforcement` verifies that raw-derived or sandbox-derived values cannot be rebound through copied `HashMap.Get(key).Val` readback when the resolved value type is a safe branded `Index[T, ctx]` or `&T[ctx]`. This guard covers `HashMap.Get(...).Val` binding/assignment readback only; remaining wrapper/API-specific rejection remains follow-up work.
* **Step 5.1 Non-Laundering HashMap.Get Value Field Guard:** `make guard_step51_non_laundering_hashmap_get_value_field_enforcement` verifies that raw-derived or sandbox-derived values cannot be rebound through copied `HashMap.Get(key).Val.field` readback when the resolved field type is a safe branded `Index[T, ctx]` or `&T[ctx]`. This guard covers `HashMap.Get(...).Val.field` binding/assignment readback only; remaining wrapper/API-specific rejection remains follow-up work.
* **Step 5.1 Unknown-Origin Deferral:** Unknown-origin rejection for safe branded `Index[T, ctx]` and `&T[ctx]` boundaries remains deferred. The current enforcement helper rejects raw-derived and sandbox-derived provenance only; tightening unknown-origin policy requires broader safe-origin classification for compiler-internal constructors, parser/typechecker helper returns, selector readback, and reference construction first. `make guard_step51_safe_constructor_provenance`, `make guard_step51_selector_safe_constructor_provenance`, `make guard_step51_container_safe_constructor_provenance`, `make guard_step51_container_method_provenance`, `make guard_step51_arena_write_provenance`, `make guard_step51_container_getref_provenance`, `make guard_step51_hashmap_get_value_provenance`, `make guard_step51_hashmap_get_value_field_provenance`, `make guard_step51_std_vector_getref_provenance`, `make guard_step51_std_hashmap_getref_provenance`, `make guard_step51_std_hashmap_getref_selector_alias_provenance`, `make guard_step51_std_vector_getref_selector_alias_provenance`, and `make guard_step51_reference_selector_alias_provenance` lock the first safe-constructor/container/arena-write/reference metadata subsets without changing that enforcement policy.
* **Step 5.1 Provenance Propagation Design:** `STEP51_DEFERRED_UNSAFE_SEMANTICS.md` defines the broad non-laundering propagation checkpoint. Safe branded `Index[T, ctx]` and `&T[ctx]` values may only be born from compiler-verified arena construction or future explicit validation/copy APIs. Unsafe blocks do not authorize rebranding raw-derived, sandbox-derived, or unknown unsafe-origin addresses as safe arena values. Containers, aggregate fields, function calls, and wrapper APIs must preserve origin metadata rather than laundering it through safe-looking types.
* **Step 5.1 Status Matrix:** `make report_step51_status_matrix` is the compact report-only checkpoint for Step 5.1. It must list the compiler-backed guards that are aggregated through `make guard_step51_basic_unsafe_enforcement` separately from the report-only/deferred FFI/layout/sandboxing, address-escape, broader non-laundering, and deferred-semantics checkpoint lanes. Keep this target informational; it must not run guards or replace `make test`.
* **Step 5.1 Report-Only Lane Guard:** `make guard_step51_report_only_lanes_not_in_test` is a Makefile policy guard wired into `make test`. It scans the full `test:` dependency stanza and fails if any `report_step51_*` target is added as a direct dependency, including if the dependency list is later wrapped across multiple lines. This protects the report-only contract for FFI, address-escape, non-laundering, and inventory/status targets; it does not prove compiler safety or replace AST/typechecker enforcement.
* **Deferred Non-Laundering:** Treat the broader unsafe non-laundering boundary as a later compiler-backed enforcement milestone after basic raw pointer/cast/unsafe-call guarding and the FFI/address-escape report lanes have a semantic design. It likely requires provenance/origin tracking beyond simple syntax detection, including assignments, calls, returns, and container storage. The existing local raw-derived pointer return guard is useful but does not prove the full non-laundering boundary.

### I. Step 5.2 Generalized Linear Resource Enforcement Discipline
* **Scope:** Step 5.2 replaces specialized directory-handle tracking with a generalized, metadata-driven linear-resource framework. Start with report-only inventory and status targets; do not add leak enforcement, destructor validation, or `Resource[ctx, T]` semantics until the compiler has explicit opt-in metadata and a reversible design checkpoint. Keep Step 5.2 compiler-backed enforcement paused while Step 5.1 deferred unsafe lanes are still unresolved, because resource ownership and destructor safety depend on the raw/FFI/provenance boundary.
* **Inventory Targets:** Use `make report_step52_linear_resource_inventory` for the broad precursor scan. Use `make report_step52_linear_resource_focused` to separate specialized directory tracking, native directory runtime boundaries, existing linear metadata/test references, future generalized `Resource[ctx, T]` / `open_linear_resources` syntax, destructor/defer syntax, and generated/comment-only references. Use `make report_step52_phase_a_status` for the metadata opt-in handoff. Use `make report_step52_phase_b_destructor_status` for the destructor/defer handoff. Use `make report_step52_phase_c_resource_registry_status` for the Resource/open-linear registry handoff. Use `make report_step52_phase_d_transfer_status` for the ownership-transfer handoff. Use `make report_step52_phase_e_enforcement_preconditions_status` for the enforcement-preconditions handoff. Use `make report_step52_phase_f_closure_status` for the report-only closure handoff. Use `make report_step52_status_matrix` for the compact legacy-vs-generalized resource summary. Use `make report_step52_final_validation` as the report-only checklist for this phase. Keep these reports and the Step 5.2 policy guard outputs visible in `a.txt` through `c.sh` so follow-up patches can reason from the same Step 5.2 snapshot.
* **Metadata Opt-In First:** Linear checks must only apply to explicitly annotated linear structs or types with registered destructors. Ordinary compiler AST/typechecker/codegen structs, primitives, and high-level collections must bypass Step 5.2 analysis by default so the compiler does not regress from conservative escape analysis. Existing `linear` / `is_linear` metadata and tests are inventory context for this phase, not proof that the future generalized `Resource[ctx, T]` wrapper or `open_linear_resources` registry exists.
* **Do Not Purge `open_directories` Yet:** Treat the existing hardcoded directory tracking as the legacy specialized lane until generalized `open_linear_resources`, destructor registration, and `Resource[ctx, T]` representation exist. Do not remove or weaken the current directory safety path in the same patch that introduces report-only Step 5.2 scaffolding.
* **Phase 5.2B Destructor/Defer Status:** `make report_step52_phase_b_destructor_status` is the report-only handoff into destructor registration and `defer` validation. Keep it report-only until `Resource[ctx, T]` ownership metadata, `open_linear_resources` tracking, destructor registration, and explicit `defer` AST/typechecker semantics exist. Do not infer generalized destructor safety from textual `drop_func` or `defer` matches alone.
* **Phase 5.2C Resource Registry Status:** `make report_step52_phase_c_resource_registry_status` is the report-only handoff into the generalized `Resource[ctx, T]` wrapper and `open_linear_resources` registry. Keep it report-only until the compiler can represent resource ownership by branding context, destructor, and transfer state. Do not replace `open_directories` until `open_linear_resources` can provide equivalent directory-handle coverage and future OS/hardware resource coverage.
* **Phase 5.2D Ownership Transfer Status:** `make report_step52_phase_d_transfer_status` is the report-only handoff into move/use-after-move and double-close semantics for generalized resources. Keep it report-only until `Resource[ctx, T]` values carry compiler-backed transfer state such as owned, moved, borrowed, closed, and destructor-scheduled. Do not infer transfer safety from textual `linear`, `drop_func`, `defer`, or directory API matches alone.
* **Phase 5.2E Enforcement Preconditions:** `make report_step52_phase_e_enforcement_preconditions_status` is the report-only checklist for the semantic prerequisites required before any generalized Step 5.2 guard can be added. Enforcement must wait for explicit metadata opt-in, `Resource[ctx, T]` ownership representation, `open_linear_resources` registry state, destructor identity, explicit `defer` AST/typechecker semantics, transfer-state validation, and parity with the legacy `open_directories` directory-handle lane.
* **Phase 5.2F Report-Only Closure:** `make report_step52_phase_f_closure_status` is the handoff that freezes Step 5.2 textual/report-only scaffolding unless a new compiler-backed design requirement appears. After this point, Step 5.2 work should move to AST/typechecker design for resource metadata, ownership state, destructor identity, `defer` semantics, transfer-state validation, and `open_directories` parity rather than adding more text scans or status-only targets.
* **Step 5.2 Semantic Design Checkpoint:** `STEP52_RESOURCE_SEMANTICS.md` is the post-closure design anchor for generalized linear-resource semantics. Keep it focused on AST/typechecker state, inert metadata shape, registry entry structure, migration order, and `open_directories` parity. Updating this document is allowed after closure when it clarifies compiler-backed design; adding more `report_step52_*` status targets is not.
* **Step 5.2 Status Matrix:** `make report_step52_status_matrix` is the compact report-only checkpoint for Step 5.2. It must list the active legacy `open_directories` / directory-handle tracking lane separately from the deferred generalized `Resource[ctx, T]`, `open_linear_resources`, destructor registration, ownership transfer state, enforcement preconditions, report-only closure, and defer-validation work. Keep this target informational; it must not run guards, replace `make test`, or imply generalized linear-resource enforcement exists.
* **Step 5.2 Report-Only Lane Guard:** `make guard_step52_report_only_lanes_not_in_test` is a Makefile policy guard wired into `make test`. It scans the full `test:` dependency stanza and fails if any `report_step52_*` target is added as a direct dependency, including if the dependency list is later wrapped across multiple lines. This protects the report-only contract for generalized linear-resource inventory/status targets; it does not prove linear-resource safety or replace future AST/typechecker enforcement.
* **Step 5.2 Post-Closure Report Churn Guard:** `make guard_step52_no_post_closure_report_churn` is a Makefile policy guard wired into `make test`. It whitelists the report targets that existed at Step 5.2F closure and fails if a new `report_step52_*` target is added without intentionally updating the closure whitelist. This keeps Step 5.2 from drifting into more textual reports after closure; the next work should be AST/typechecker design or compiler-backed guards.
* **Deferred Enforcement:** Generalized linear-resource enforcement must be compiler-backed and semantic. Textual reports must not be wired into `make test` as failing guards; they exist to scope the migration before parser/type metadata, type environment state, destructor registration, ownership-transfer state, and defer validation are implemented. If `make report_step52_linear_resource_focused` shows no `Resource[ctx, T]` or `open_linear_resources` syntax, do not invent generalized resource enforcement yet; keep `open_directories` as the legacy specialized lane and treat existing `linear` metadata as separate context.

### J. Project Command Runner Split
* **Layering Rule:** Keep `flake.nix` focused on the reproducible toolchain/dev shell, keep `Makefile` as the canonical build graph for `gust`, `bootstrap`, generated artifacts, and aggregate `test` dependency wiring, and use `justfile` for human-friendly aliases, focused workflows, argument-handling convenience, and command-only guard implementations.
* **Make/Just Boundary:** `make test` may depend on `just` for focused command-only guards. `make gust` and `make bootstrap` must not depend on `just`; those targets remain the plain Make/self-hosting boundary. `make test` should stay as a thin wrapper around `just make-test-suite`, with the long validation order owned by `justfile`. Make targets that remain for compatibility but do not produce build artifacts should delegate to same-named `justfile` recipes, imported `justfile-*` modules, or shared scripts.
* **No Build Graph Duplication:** `justfile` recipes should call `make` for canonical build/test/bootstrap targets rather than reimplementing Make's dependency graph. Use `just` to reduce `.PHONY` command sprawl and improve discoverability, not to create a second source of truth for generated artifacts. Keep Make's explicit `.PHONY` declarations limited to high-level aggregate commands, `require_just`, and compatibility wrappers.
* **Report Modules:** `report_*` implementations belong in imported `justfile-reports`. Makefile may retain same-name compatibility wrappers that call `just`, but report bodies should not live in Makefile.
* **Reusable Focused Runner:** Shared self-hosted Gust compile/build/run plumbing belongs in `scripts/run-gust-file.sh`. Shell helpers and `justfile` aliases should call that script instead of copy-pasting the three-phase compile-C-run sequence. Regex/textual guard implementations that do not produce artifacts should live in `justfile` / imported `justfile-*` modules and be invoked from Make only as aggregate-test wrappers.
* **Nix Role:** The dev shell should install command-runner tools such as `just` alongside Rust, C, Python, tree-sitter, and formatting tools. It should not become a large task runner full of duplicated guard scripts.

## TOOL USE CONSTRAINTS & DISCIPLINE
- **Prohibition of Execution Tools**: You are strictly prohibited from calling any command execution, bash shell, terminal, or system-running tools (such as `vm_shell:execute_bash` or any equivalent system command triggers).
- **Allowed Tool Scope**: You must only use information-retrieval and text-generation tools (such as `google:search` and `browsing:browse` to gather context, and text responses to supply code patches). 
- **User-Led Verification**: All compilation, tests, and command execution must be left entirely to the user. Do not attempt to run tests or compile code yourself.

# GEMINI.md: Code Patching & Diff Guidelines

## IMPORTANT
For each change write out a json patch in a code block according to below format outlined in "Step 2: Update Parser and Codegen to Transpile References as C Pointers"
If there is more than one block of changes write out more than one code block with a json patch in it for each change in that file


## CRITICAL: JSON DIFF FORMATTING RULES
When providing file updates, you must output a single JSON payload. The pipeline executes updates transactionally: if any single search block fails to match, or if syntax errors are introduced, **the entire patch is aborted and no files are modified on disk**.

---

### 1. Root Structure Rules
* The root of your response MUST be a single, valid JSON object. Do NOT wrap it in a root array.
* If you are editing multiple files, include all of them in the single `"files"` array.

---

### 2. The `"summary"` Field (Git Commit Message)
* The `"summary"` string at the root of your JSON is automatically extracted and used as the **Git commit message** by the pipeline.
* Make this summary clear, concise, and professional (e.g., following Conventional Commits, such as `feat: add auth check middleware` or `fix: resolve crash in user loop`).

---

### 3. Search / Replace Blocks (`code_diff`)
Within the `"code_diff"` string of each file entry, use Aider-style `<<<<<<< SEARCH` and `>>>>>>> REPLACE` blocks.

```json
{
  "summary": "feat: implement rate limiting middleware",
  "files": [
    {
      "file_path": "src/middleware/rate_limit.ts",
      "code_diff": "<<<<<<< SEARCH\nexport function setup(app) {\n  // old logic\n}\n=======\nexport function setup(app) {\n  // new rate limit logic\n}\n>>>>>>> REPLACE"
    }
  ]
}
```

---

### 4. Advanced Block Matching Features

#### A. Elision via Ellipses (`...`)
To avoid outputting large, unchanged blocks of code, you can use `...` in both the SEARCH and REPLACE blocks to skip unchanged lines.
* **Rule**: You must use the exact same number of `...` markers in both the SEARCH and REPLACE blocks.
* **Rule**: The text immediately before and after the `...` must be unique and substantial enough to anchor the match safely. Avoid putting `...` directly next to common characters like single closing braces `}` which are not unique in the file.

*Example:*
```text
<<<<<<< SEARCH
function processUserData(user) {
  console.log("Processing...");
  ...
  saveToDatabase(user);
}
=======
function processUserData(user) {
  console.log("Processing active user...");
  ...
  saveToDatabase(user);
}
>>>>>>> REPLACE
```

#### B. JavaScript / TypeScript AST Fallback (Tier 3.5)
For `.js`, `.jsx`, `.ts`, and `.tsx` files, the patcher features an AST-node fallback. If literal text matching fails, it will attempt to match structural declarations (functions, methods, classes, interfaces) by their names and replace them.
* When editing TS/JS, ensure your search blocks cleanly cover semantic entities (like an entire function or class method) to allow the AST fallback to succeed if the raw text is slightly misaligned.

#### C. Rust AST Fallback (Tier 3.6)
For `.rs` files, the patcher provides AST-node fallback resolution. If literal search matching fails, it attempts to resolve matched item blocks structurally for Rust declarations:
* **Tracked Entities**: Functions (`function_item`), structs (`struct_item`), enums (`enum_item`), traits (`trait_item`), module structures (`mod_item`), and implementation blocks (`impl_item`).
* **Rule**: When targeting Rust, attempt to isolate edits within complete functional bounds or structural items. This ensures that if indentation is shifted or minor line adjustments fail, the patcher can safely find the target entity inside the Rust AST.

#### D. Indentation-Adjusted Match Fallback (Tier 2)
The patcher will automatically adjust leading whitespace differences if your block indentation does not match the file's current nesting structure. However, matching the target indentation exactly is still the safest path to ensure accurate patches.

---

### 5. Syntax Validation & Transactional Safety
The patching tool uses Tree-sitter to validate the syntax of JavaScript, TypeScript, JSX, TSX, and Rust files after applying modifications.
* **Rule**: Do not introduce incomplete or broken syntax. If Tree-sitter detects any syntax errors after applying your patch, the entire transaction will fail, roll back, and abort.
* Ensure every block is completely precise. If you output changes for multiple files and one block fails, none of the files will be modified on disk.



Updating tree sitter for helix
git add .
git commit
cd ~/nixos-config  # or cd /etc/nixos
nix flake update tree-sitter-gust
rebuild
reopen helix

make gust to.log 2>&1


42069

# Rust Style Guide: Sovereign Core & Gust Compiler

This document defines the architectural patterns, coding standards, and style guidelines for Rust development within this project. It is heavily inspired by our functional TypeScript and Kotlin Gatekeeper style guides—focusing on minimal abstraction, locality of behavior, strict expression-based flow, and robust error handling without exception/panic mechanics.

---

## 1. Core Philosophy

### Grug-Brained Simplicity
* **Locality of Behavior (LoB):** The effort required to understand a section of code should be proportional to its physical size. Avoid deep modular nesting or splitting a single logical flow across five files.
* **Minimal Abstraction Principle:** Do not abstract until you have repeated a pattern at least three times. It is significantly cheaper to have duplicate lines than to struggle against the wrong abstraction.
* **Generics Caution:** Restrict the use of generics. Only use them for true container/utility types (e.g., AST structures, Collections, Monads). If a concrete type works, use the concrete type.

### Smart Core, Dumb Shell (Headless SAM)
* **Zero-Copy Performance:** Ensure boundary transfers utilize direct memory access, serialized raw vectors (`Vec<f32>`, `Vec<u32>`), or raw buffers where applicable to bypass garbage collection overhead.

---

## 2. Functional Rust & Expression-Based Flow

Rust is natively expression-based. Capitalize on this to eliminate mutable intermediate state (`mut`) and state-tracking flags.

### Implicit Returns & Bindings
Avoid initializing variables with `let mut` only to assign them inside conditional statements. Assign the conditional block directly to a `let` binding.

**✅ Correct:**
```rust
let value = if condition {
    compute_primary()
} else {
    compute_fallback()
};
```

**❌ Incorrect:**
```rust
let mut value = 0;
if condition {
    value = compute_primary();
} else {
    value = compute_fallback();
}
```

### Pure Calculation vs. Execution (The "Vat" Rule)
* **Mathematical Vats:** Core transformations (Lexing, Parsing, Typechecking, Codegen, Mesh computation) must be mathematically pure. Given the same inputs, they must return the exact same outputs.
* **No Side-Effects in Logic:** Pure logical calculations must never perform disk I/O, access system clocks, or make network calls. Isolate these actions to the outermost caller (e.g., `main.rs`, Web Worker orchestrator).

---

## 3. The "Anti-Manager" Pattern

We do not write object-oriented code disguised as Rust.

* **No Stateless "Service" Structs:** Avoid creating instantiable helper structures like `ValidationManager`, `FormatHelper`, or `CompilerService` that hold zero long-running state.
* **Top-Level and Pure Functions:** Use top-level modular functions or implement pure methods directly on the target data structure (`impl StructName`).

**✅ Correct:**
```rust
pub fn validate_type(expected: &Type, actual: &Type) -> bool {
    // Top-level, stateless, pure calculation
    expected == actual
}
```

**❌ Incorrect:**
```rust
pub struct ValidationManager;

impl ValidationManager {
    pub fn new() -> Self { Self }
    pub fn validate(&self, expected: &Type, actual: &Type) -> bool {
        expected == actual
    }
}
```

---

## 4. Error Handling: Railway Oriented Programming (ROP)

Do not use panics, `unwrap()`, or `expect()` for routine flow control. If a function can fail, that failure is a *valid return type*.

### Error Monads
Functions that can fail must return a `Result<T, E>` or `Option<T>`. Callers are forced by the compiler to handle both the happy and unhappy paths.

**✅ Correct:**
```rust
pub fn resolve_type(&self, t: &Type) -> Result<Type, TypeError> {
    match t {
        Type::Generic(name, args) => {
            let resolved_args = self.resolve_generic_arguments(args)?;
            self.monomorphize(name, &resolved_args)
        }
        _ => Ok(t.clone()),
    }
}
```

**❌ Incorrect:**
```rust
pub fn resolve_type(&self, t: &Type) -> Type {
    match t {
        Type::Generic(name, args) => {
            self.monomorphize(name, args).unwrap() // Catastrophic panic risk
        }
        _ => t.clone(),
    }
}
```

### Domain-Specific Error Types
Define explicit, descriptive error enums with `#[derive(Debug, Clone, PartialEq, Eq)]`.

---

## 5. Unhappy Path First (Flat Control Flow)

Keep your code flat. Use guard clauses, pattern matching, and early returns (`return Err(...)` or `return None`) to prevent your code from drifting into nested indentation hell.

**✅ Correct:**
```rust
pub fn check_expression(&mut self, expr: &Expression) -> Result<Type, TypeError> {
    let Expression::Identifier(name) = expr else {
        return self.fallback_evaluation(expr);
    };

    if self.moved_vars.contains(name) {
        return Err(TypeError {
            kind: TypeErrorKind::UseOfMovedVariable,
            message: format!("Use of moved variable: {name}"),
        });
    }

    self.symbol_table.get(name).cloned().ok_or_else(|| TypeError {
        kind: TypeErrorKind::UndefinedVariable,
        message: format!("Undefined variable: {name}"),
    })
}
```

**❌ Incorrect:**
```rust
pub fn check_expression(&mut self, expr: &Expression) -> Result<Type, TypeError> {
    if let Expression::Identifier(name) = expr {
        if !self.moved_vars.contains(name) {
            if let Some(t) = self.symbol_table.get(name) {
                Ok(t.clone())
            } else {
                Err(TypeError { ... })
            }
        } else {
            Err(TypeError { ... })
        }
    } else {
        self.fallback_evaluation(expr)
    }
}
```

---

## 6. Functional Iterators

Prefer functional combinators (`map`, `filter`, `fold`, `any`, `all`) over imperative `for` loops ONLY WHEN where they enhance clarity. Do not hesitate to revert to simple imperative loops if the functional pipeline becomes overly complex.

**✅ Correct:**
```rust
let resolved_args: Result<Vec<Type>, TypeError> = args
    .iter()
    .map(|arg| self.resolve_type(arg))
    .collect();
```

---

## 7. Logging & Debugging Standards

We use structured logging with high visibility. All major logical branch transitions (especially inside core calculations) should be logged. We employ an emoji-guided schema to enable rapid parsing of terminal traces.

Instead of trying to guess why a complex monomorphization failed, we can write localized, diagnostic-heavy tracing::debug! calls that dump the entire local variable table, the expected vs. actual type layouts, and active memory origin sets at the precise boundary of failure.
By executing the tests with RUST_LOG=debug cargo test -- --nocapture, we will get a complete step-by-step diagnostic trace leading right up to the panic or failure.

### How to Enable Tracing
The `tracing` and `tracing-subscriber` frameworks are fully integrated. To view structured logs during compilation or testing:
1. Set the `RUST_LOG` environment variable (e.g. `export RUST_LOG=debug` or `export RUST_LOG=info`).
2. Run your cargo commands:
   * **Run tests with logs**: `RUST_LOG=debug cargo test -- --nocapture`
   * **Run compiler with logs**: `RUST_LOG=debug cargo run -- input.gst`

### Logging Initialization
Logging is initialized globally via `gust_lexer::init_logging()`. In test suites and binary entry-points, this is called safely (preventing multiple registrations via `try_init()`).

### Emoji Legend
* `📥` **Action Dispatched:** Event incoming to Worker/Engine boundary.
* `🔄` **State Changed:** State transitions or monomorphization resolutions.
* `⚙️` **Execution:** Side effects (file writes, arena growth allocations).
* `🗄️` **Memory / Registry:** Type additions to registry tables or variable scoping modifications.
* `✅` **Verification:** Successful verification, parser compliance, or compile completion.
* `❌` **Error:** Caught compile validation or runtime issues.
* `👁️` **Tracing:** Localized diagnostics.

**Example Implementation Pattern:**
```rust
pub fn check_program(&mut self, program: &Program) -> Result<(), TypeError> {
    tracing::debug!("📥 Starting validation pass for program structure.");
    for stmt in &program.statements {
        self.check_statement(stmt).map_err(|e| {
            tracing::error!("❌ Validation failed: {}", e.message);
            e
        })?;
    }
    tracing::info!("✅ Program validation complete. System is safe.");
    Ok(())
}
```

---

## 8. Testing Standards

Maintain a multi-layered testing topology:

* **Layer 1: Unit Tests (`cargo test`):** Put unit tests in the same file as the tested components using a `tests` module block with `#[cfg(test)]`. Target pure calculations and lexer/parser invariants.
* **Layer 2: Integration / E2E Tests:** Keep integration and end-to-end user flows inside a separate `/tests` directory (e.g., `tests/compile_tests.rs`, `tests/e2e_tests.rs`).
* **Strict Assertion of Invariants:** Use `assert_eq!`, `assert!`, and `matches!` pattern testing directly rather than mock structures. Avoid mocking libraries unless strictly testing I/O boundaries.

---

## 9. Diagnostic CLI Flags & Self-Hosting Roadmap

The `gust_v1` compiler provides two diagnostic command-line flags to assist with ground-truth verification during the self-hosting phase:

### `--dump-ast`
* **Purpose**: Intercepts the pipeline directly after parsing.
* **Behavior**: Walking the parsed Abstract Syntax Tree (AST), this flag serializes it into a highly deterministic, stable, human-readable indented text structure. Volatile spans are stripped to ensure the output remains perfectly diffable against the self-hosted parser in Phase 3.
* **Usage**:
  ```bash
  cargo run -- --dump-ast src/main.gst
  ```

### `--dump-types`
* **Purpose**: Intercepts the pipeline directly after typechecking.
* **Behavior**: Extracts the populated type checking databases (including resolved variable types, alphabetically sorted struct layouts, enum variant listings, and alphabetically sorted function signatures) and serializes them. This acts as our semantic ground-truth reference database for the self-hosted typechecker in Phase 4.
* **Usage**:
  ```bash
  cargo run -- --dump-types src/main.gst
  ```
