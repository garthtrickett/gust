// Phase 17.1 compiler-owned native runtime boundary authority.
//
// This module is the sole semantic owner for runtime ABI identities, helper
// identities and classifications, component and package identities, program
// requirements, compatibility decisions, and the Phase 9G link-plan handoff.
// Canonical MIR, MIR-to-C, Cranelift, runtime packaging, diagnostics, and the
// artifact planner consume these records. Backends and linkers do not infer
// runtime semantics from generated C, unresolved symbols, or object contents.

type MirRuntimeAbiIdentity[ctx] struct {
    runtime_abi_id: str,
    abi_version: str,
    compatible_version_min: int,
    compatible_version_max: int,
    target_id: str,
    target_triple: str,
    calling_convention_id: str,
    layout_authority_id: str,
    function_abi_authority_id: str,
    resource_authority_id: str,
    visibility_policy: str,
    linkage_policy: str
}

type MirRuntimeHelperIdentity[ctx] struct {
    helper_id: str,
    operation_id: str,
    symbol_identity: str,
    source_location: str,
    target_applicability: str
}

type MirRuntimeHelperClassification[ctx] struct {
    classification_id: str,
    helper_id: str,
    classification: str,
    component_id: str,
    reason_code: str
}

type MirRuntimeSymbolIdentity[ctx] struct {
    symbol_id: str,
    helper_id: str,
    external_spelling: str,
    symbol_version: str,
    component_id: str,
    runtime_abi_id: str,
    function_abi_id: str,
    calling_convention_id: str,
    layout_id: str,
    resource_operation_id: str,
    target_id: str,
    target_triple: str,
    required: int,
    visibility: str,
    linkage: str,
    compatibility_policy: str
}

type MirRuntimeComponentIdentity[ctx] struct {
    component_id: str,
    component_kind: str,
    source_path: str,
    object_identity: str,
    target_id: str
}

// Phase 17.8 pure Gust runtime modules. These compile through the same generic
// canonical-MIR route as any other Gust code. The compiler and backend must not
// recognise a module by name or by source contents: if generic lowering cannot
// handle it, it is not a runtime module, it is a compiler special case.
type MirRuntimeGustModule[ctx] struct {
    gust_module_id: str,
    component_id: str,
    module_source_path: str,
    exported_symbol_ids: Index[std.Vector[str, ctx], ctx],
    imported_symbol_ids: Index[std.Vector[str, ctx], ctx],
    allowed_dependency_ids: Index[std.Vector[str, ctx], ctx],
    runtime_abi_id: str,
    target_id: str,
    target_applicability: str,
    lowering_route: str,
    initialization_policy: str,
    failure_policy: str
}

// Phase 17.7 retained C runtime components. C stays only as separately compiled,
// versioned, target-scoped components with a concrete retention reason and a
// stated removal criterion. It is never an implicit per-program layer, and no
// retained C source is ever derived from a compiled program's canonical MIR.
type MirRuntimeRetainedCComponent[ctx] struct {
    retained_component_id: str,
    component_id: str,
    owned_source_paths: Index[std.Vector[str, ctx], ctx],
    exported_symbol_ids: Index[std.Vector[str, ctx], ctx],
    imported_symbol_ids: Index[std.Vector[str, ctx], ctx],
    runtime_abi_id: str,
    target_id: str,
    target_applicability: str,
    build_inputs: str,
    retention_reason: str,
    removal_criterion: str,
    destination_phase: str
}

// Phase 17.6 Rust runtime components. Compiled independently of any program,
// exporting stable ABI-facing symbols. Rust-internal mangling is never a runtime
// contract, and the panic and allocation boundaries are declared, not assumed.
type MirRuntimeRustComponent[ctx] struct {
    rust_component_id: str,
    component_id: str,
    source_ownership: str,
    exported_symbol_ids: Index[std.Vector[str, ctx], ctx],
    imported_symbol_ids: Index[std.Vector[str, ctx], ctx],
    runtime_abi_id: str,
    target_id: str,
    target_applicability: str,
    object_form: str,
    panic_boundary: str,
    allocation_boundary: str
}

// Phase 17.5 import declarations are what Cranelift emits a direct call to. Each
// one names a compiler-owned versioned symbol and the package that exports it,
// so the backend never maintains its own symbol spelling or signature table.
type MirRuntimeImportDeclaration[ctx] struct {
    import_id: str,
    helper_id: str,
    symbol_id: str,
    external_spelling: str,
    symbol_version: str,
    function_abi_id: str,
    component_id: str,
    package_id: str,
    target_id: str,
    target_applicability: str,
    side_effect_policy: str,
    failure_policy: str
}

// Phase 17.4 packages are explicit manifests, not directories a linker scans.
// A package is identified by its runtime ABI version and exact target
// applicability, and every member, provided symbol, and permitted system import
// is enumerated before Phase 9G is allowed to execute the link plan.
type MirRuntimePackageIdentity[ctx] struct {
    package_id: str,
    package_version: str,
    target_id: str,
    available: int,
    manifest_format: str,
    package_form: str,
    runtime_abi_id: str,
    target_triple: str,
    build_authority_id: str,
    compatible_version_min: int,
    compatible_version_max: int
}

// One declared component placed at an explicit, deterministic link position.
type MirRuntimePackageMember[ctx] struct {
    member_id: str,
    package_id: str,
    component_id: str,
    link_order: int,
    object_identity: str
}

// A symbol the package provides, at the version it provides it.
type MirRuntimePackageProvidedSymbol[ctx] struct {
    provided_id: str,
    package_id: str,
    symbol_id: str,
    external_spelling: str,
    symbol_version: str,
    component_id: str
}

// A system import the package is permitted to reference. Anything outside this
// enumeration is undeclared surface rather than an implicit platform dependency.
type MirRuntimePackageSystemImport[ctx] struct {
    import_id: str,
    package_id: str,
    external_spelling: str,
    origin: str
}

// Phase 17.3 requirements are compiler-produced. One requirement covers every
// canonical MIR runtime operation that reaches the same helper in a program, so
// the request-side table deduplicates without the worker inventing ownership.
type MirRuntimeRequirement[ctx] struct {
    requirement_id: str,
    program_id: str,
    mir_operation_id: str,
    helper_id: str,
    runtime_abi_id: str,
    component_id: str,
    package_id: str,
    required: int,
    symbol_id: str,
    required_version_min: int,
    required_version_max: int,
    target_id: str,
    layout_id: str,
    resource_operation_id: str,
    function_abi_id: str,
    call_kind: str,
    package_mandatory: int
}

type MirRuntimeCompatibilityDecision[ctx] struct {
    decision_id: str,
    requirement_id: str,
    package_id: str,
    compatible: int,
    reason_code: str
}

type MirRuntimeLinkPlanHandoff[ctx] struct {
    link_plan_id: str,
    program_id: str,
    package_id: str,
    target_id: str,
    component_ids: Index[std.Vector[str, ctx], ctx],
    symbol_identities: Index[std.Vector[str, ctx], ctx],
    compatible: int,
    reason_code: str
}

// Canonical MIR runtime operations carry this metadata. Every reference names
// the owning requirement, so a runtime-facing operation can never reach the
// backend with its ownership left to linker or unresolved-symbol inference.
type MirRuntimeMirReference[ctx] struct {
    reference_id: str,
    mir_operation_id: str,
    helper_id: str,
    requirement_id: str,
    symbol_id: str,
    runtime_abi_id: str,
    required_version_min: int,
    required_version_max: int,
    target_applicability: str,
    layout_id: str,
    resource_operation_id: str,
    function_abi_id: str,
    call_kind: str
}

type MirRuntimeBoundaryAuthorityTable[ctx] struct {
    format: str,
    target_id: str,
    target_triple: str,
    semantic_authority: str,
    identity_policy: str,
    classification_policy: str,
    requirement_policy: str,
    link_plan_policy: str,
    runtime_abis: Index[std.Vector[MirRuntimeAbiIdentity[ctx], ctx], ctx],
    helpers: Index[std.Vector[MirRuntimeHelperIdentity[ctx], ctx], ctx],
    classifications: Index[std.Vector[MirRuntimeHelperClassification[ctx], ctx], ctx],
    symbols: Index[std.Vector[MirRuntimeSymbolIdentity[ctx], ctx], ctx],
    components: Index[std.Vector[MirRuntimeComponentIdentity[ctx], ctx], ctx],
    packages: Index[std.Vector[MirRuntimePackageIdentity[ctx], ctx], ctx],
    package_members: Index[std.Vector[MirRuntimePackageMember[ctx], ctx], ctx],
    package_provided_symbols: Index[std.Vector[MirRuntimePackageProvidedSymbol[ctx], ctx], ctx],
    package_system_imports: Index[std.Vector[MirRuntimePackageSystemImport[ctx], ctx], ctx],
    import_declarations: Index[std.Vector[MirRuntimeImportDeclaration[ctx], ctx], ctx],
    rust_components: Index[std.Vector[MirRuntimeRustComponent[ctx], ctx], ctx],
    retained_c_components: Index[std.Vector[MirRuntimeRetainedCComponent[ctx], ctx], ctx],
    gust_modules: Index[std.Vector[MirRuntimeGustModule[ctx], ctx], ctx],
    requirements: Index[std.Vector[MirRuntimeRequirement[ctx], ctx], ctx],
    compatibility_decisions: Index[std.Vector[MirRuntimeCompatibilityDecision[ctx], ctx], ctx],
    link_plans: Index[std.Vector[MirRuntimeLinkPlanHandoff[ctx], ctx], ctx],
    mir_references: Index[std.Vector[MirRuntimeMirReference[ctx], ctx], ctx]
}

type MirRuntimeHelperQuery[ctx] struct { found: int, value: MirRuntimeHelperIdentity[ctx] }
type MirRuntimeClassificationQuery[ctx] struct { found: int, value: MirRuntimeHelperClassification[ctx] }
type MirRuntimeAbiQuery[ctx] struct { found: int, value: MirRuntimeAbiIdentity[ctx] }
type MirRuntimeSymbolQuery[ctx] struct { found: int, value: MirRuntimeSymbolIdentity[ctx] }
type MirRuntimeComponentQuery[ctx] struct { found: int, value: MirRuntimeComponentIdentity[ctx] }
type MirRuntimePackageQuery[ctx] struct { found: int, value: MirRuntimePackageIdentity[ctx] }
type MirRuntimeCompatibilityQuery[ctx] struct { compatible: int, reason_code: str }
type MirRuntimeLinkPlanQuery[ctx] struct { found: int, value: MirRuntimeLinkPlanHandoff[ctx] }
type MirRuntimePackageSelection[ctx] struct { found: int, reason_code: str, value: MirRuntimePackageIdentity[ctx] }
type MirRuntimePackageManifestQuery[ctx] struct { valid: int, reason_code: str, member_count: int, provided_symbol_count: int, system_import_count: int }
type MirRuntimeGustModuleQuery[ctx] struct { found: int, value: MirRuntimeGustModule[ctx] }
type MirRuntimeRetainedCQuery[ctx] struct { found: int, value: MirRuntimeRetainedCComponent[ctx] }
type MirRuntimeRustComponentQuery[ctx] struct { found: int, value: MirRuntimeRustComponent[ctx] }
type MirRuntimeImportQuery[ctx] struct { found: int, value: MirRuntimeImportDeclaration[ctx] }
type MirRuntimeRequirementQuery[ctx] struct { found: int, value: MirRuntimeRequirement[ctx] }
type MirRuntimeMirReferenceQuery[ctx] struct { found: int, value: MirRuntimeMirReference[ctx] }
type MirRuntimeAuthorityValidation[ctx] struct { valid: int, reason_code: str }

func mir_runtime_empty_strings(ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut values: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_runtime_empty_abis(ctx: &Arena) Index[std.Vector[MirRuntimeAbiIdentity[ctx], ctx], ctx] { mut values: std.Vector[MirRuntimeAbiIdentity[ctx], ctx] := std.VectorNew(ctx); mut index: Index[std.Vector[MirRuntimeAbiIdentity[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index; }
func mir_runtime_empty_helpers(ctx: &Arena) Index[std.Vector[MirRuntimeHelperIdentity[ctx], ctx], ctx] { mut values: std.Vector[MirRuntimeHelperIdentity[ctx], ctx] := std.VectorNew(ctx); mut index: Index[std.Vector[MirRuntimeHelperIdentity[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index; }
func mir_runtime_empty_classifications(ctx: &Arena) Index[std.Vector[MirRuntimeHelperClassification[ctx], ctx], ctx] { mut values: std.Vector[MirRuntimeHelperClassification[ctx], ctx] := std.VectorNew(ctx); mut index: Index[std.Vector[MirRuntimeHelperClassification[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index; }
func mir_runtime_empty_symbols(ctx: &Arena) Index[std.Vector[MirRuntimeSymbolIdentity[ctx], ctx], ctx] { mut values: std.Vector[MirRuntimeSymbolIdentity[ctx], ctx] := std.VectorNew(ctx); mut index: Index[std.Vector[MirRuntimeSymbolIdentity[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index; }
func mir_runtime_empty_components(ctx: &Arena) Index[std.Vector[MirRuntimeComponentIdentity[ctx], ctx], ctx] { mut values: std.Vector[MirRuntimeComponentIdentity[ctx], ctx] := std.VectorNew(ctx); mut index: Index[std.Vector[MirRuntimeComponentIdentity[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index; }
func mir_runtime_empty_packages(ctx: &Arena) Index[std.Vector[MirRuntimePackageIdentity[ctx], ctx], ctx] { mut values: std.Vector[MirRuntimePackageIdentity[ctx], ctx] := std.VectorNew(ctx); mut index: Index[std.Vector[MirRuntimePackageIdentity[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index; }
func mir_runtime_empty_requirements(ctx: &Arena) Index[std.Vector[MirRuntimeRequirement[ctx], ctx], ctx] { mut values: std.Vector[MirRuntimeRequirement[ctx], ctx] := std.VectorNew(ctx); mut index: Index[std.Vector[MirRuntimeRequirement[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index; }
func mir_runtime_empty_package_members(ctx: &Arena) Index[std.Vector[MirRuntimePackageMember[ctx], ctx], ctx] { mut values: std.Vector[MirRuntimePackageMember[ctx], ctx] := std.VectorNew(ctx); mut index: Index[std.Vector[MirRuntimePackageMember[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index; }
func mir_runtime_empty_package_provided_symbols(ctx: &Arena) Index[std.Vector[MirRuntimePackageProvidedSymbol[ctx], ctx], ctx] { mut values: std.Vector[MirRuntimePackageProvidedSymbol[ctx], ctx] := std.VectorNew(ctx); mut index: Index[std.Vector[MirRuntimePackageProvidedSymbol[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index; }
func mir_runtime_empty_package_system_imports(ctx: &Arena) Index[std.Vector[MirRuntimePackageSystemImport[ctx], ctx], ctx] { mut values: std.Vector[MirRuntimePackageSystemImport[ctx], ctx] := std.VectorNew(ctx); mut index: Index[std.Vector[MirRuntimePackageSystemImport[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index; }
func mir_runtime_empty_gust_modules(ctx: &Arena) Index[std.Vector[MirRuntimeGustModule[ctx], ctx], ctx] { mut values: std.Vector[MirRuntimeGustModule[ctx], ctx] := std.VectorNew(ctx); mut index: Index[std.Vector[MirRuntimeGustModule[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index; }
func mir_runtime_empty_retained_c_components(ctx: &Arena) Index[std.Vector[MirRuntimeRetainedCComponent[ctx], ctx], ctx] { mut values: std.Vector[MirRuntimeRetainedCComponent[ctx], ctx] := std.VectorNew(ctx); mut index: Index[std.Vector[MirRuntimeRetainedCComponent[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index; }
func mir_runtime_empty_rust_components(ctx: &Arena) Index[std.Vector[MirRuntimeRustComponent[ctx], ctx], ctx] { mut values: std.Vector[MirRuntimeRustComponent[ctx], ctx] := std.VectorNew(ctx); mut index: Index[std.Vector[MirRuntimeRustComponent[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index; }
func mir_runtime_empty_import_declarations(ctx: &Arena) Index[std.Vector[MirRuntimeImportDeclaration[ctx], ctx], ctx] { mut values: std.Vector[MirRuntimeImportDeclaration[ctx], ctx] := std.VectorNew(ctx); mut index: Index[std.Vector[MirRuntimeImportDeclaration[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index; }
func mir_runtime_empty_compatibility(ctx: &Arena) Index[std.Vector[MirRuntimeCompatibilityDecision[ctx], ctx], ctx] { mut values: std.Vector[MirRuntimeCompatibilityDecision[ctx], ctx] := std.VectorNew(ctx); mut index: Index[std.Vector[MirRuntimeCompatibilityDecision[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index; }
func mir_runtime_empty_link_plans(ctx: &Arena) Index[std.Vector[MirRuntimeLinkPlanHandoff[ctx], ctx], ctx] { mut values: std.Vector[MirRuntimeLinkPlanHandoff[ctx], ctx] := std.VectorNew(ctx); mut index: Index[std.Vector[MirRuntimeLinkPlanHandoff[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index; }
func mir_runtime_empty_references(ctx: &Arena) Index[std.Vector[MirRuntimeMirReference[ctx], ctx], ctx] { mut values: std.Vector[MirRuntimeMirReference[ctx], ctx] := std.VectorNew(ctx); mut index: Index[std.Vector[MirRuntimeMirReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index; }

func mir_runtime_field_is_safe(value: str) int {
    if len(value) == 0 { return 0; }
    if std.str_find(value, "\n") != 0 - 1 { return 0; }
    if std.str_find(value, "\r") != 0 - 1 { return 0; }
    return 1;
}

func mir_runtime_helper_classification_is_valid(value: str) int {
    if std.str_eq(value, "stable_runtime_library_function") == 1 { return 1; }
    if std.str_eq(value, "rust_runtime_component") == 1 { return 1; }
    if std.str_eq(value, "retained_c_runtime_component") == 1 { return 1; }
    if std.str_eq(value, "pure_gust_runtime_component") == 1 { return 1; }
    if std.str_eq(value, "obsolete_helper") == 1 { return 1; }
    return 0;
}

// Only the generic route is a legal lowering path. A bespoke one would mean the
// compiler recognised this module, which is exactly what the patch forbids.
func mir_runtime_lowering_route_is_valid(value: str) int {
    if std.str_eq(value, "generic_parse_typecheck_canonical_mir_abi_cranelift") == 1 { return 1; }
    return 0;
}

func mir_runtime_initialization_policy_is_valid(value: str) int {
    if std.str_eq(value, "none_required_pure_functions") == 1 { return 1; }
    if std.str_eq(value, "explicit_caller_invoked_initializer") == 1 { return 1; }
    return 0;
}

func mir_runtime_gust_module_for(table: MirRuntimeBoundaryAuthorityTable[ctx], component_id: str, ctx: &Arena) MirRuntimeGustModuleQuery[ctx] { mut result: MirRuntimeGustModuleQuery[ctx]; result.found = 0; mut values: std.Vector[MirRuntimeGustModule[ctx], ctx] := ctx[table.gust_modules]; mut index := 0; while index < len(values) { if std.str_eq(values[index].component_id, component_id) == 1 { result.found = 1; result.value = values[index]; return result; } index = index + 1; } return result; }

// Retention must be justified and time-bounded, never open-ended.
func mir_runtime_retention_reason_is_valid(value: str) int {
    if std.str_eq(value, "awaiting_pure_gust_migration") == 1 { return 1; }
    if std.str_eq(value, "awaiting_rust_component_migration") == 1 { return 1; }
    if std.str_eq(value, "host_platform_primitive_no_gust_equivalent") == 1 { return 1; }
    return 0;
}

func mir_runtime_retained_c_for(table: MirRuntimeBoundaryAuthorityTable[ctx], component_id: str, ctx: &Arena) MirRuntimeRetainedCQuery[ctx] { mut result: MirRuntimeRetainedCQuery[ctx]; result.found = 0; mut values: std.Vector[MirRuntimeRetainedCComponent[ctx], ctx] := ctx[table.retained_c_components]; mut index := 0; while index < len(values) { if std.str_eq(values[index].component_id, component_id) == 1 { result.found = 1; result.value = values[index]; return result; } index = index + 1; } return result; }

// Unwinding must never cross back into compiled Gust. Only abort-style
// boundaries are supported, so a component declaring anything else is rejected.
func mir_runtime_panic_boundary_is_valid(value: str) int {
    if std.str_eq(value, "abort_no_unwind_across_ffi") == 1 { return 1; }
    if std.str_eq(value, "catch_unwind_converted_to_explicit_error") == 1 { return 1; }
    return 0;
}

func mir_runtime_allocation_boundary_is_valid(value: str) int {
    if std.str_eq(value, "no_allocation_caller_owns_all_memory") == 1 { return 1; }
    if std.str_eq(value, "allocates_in_caller_supplied_arena") == 1 { return 1; }
    return 0;
}

func mir_runtime_rust_object_form_is_valid(value: str) int {
    if std.str_eq(value, "static_library") == 1 { return 1; }
    if std.str_eq(value, "deterministic_object_set") == 1 { return 1; }
    return 0;
}

func mir_runtime_rust_component_for(table: MirRuntimeBoundaryAuthorityTable[ctx], component_id: str, ctx: &Arena) MirRuntimeRustComponentQuery[ctx] { mut result: MirRuntimeRustComponentQuery[ctx]; result.found = 0; mut values: std.Vector[MirRuntimeRustComponent[ctx], ctx] := ctx[table.rust_components]; mut index := 0; while index < len(values) { if std.str_eq(values[index].component_id, component_id) == 1 { result.found = 1; result.value = values[index]; return result; } index = index + 1; } return result; }

// Phase 17.4 package forms are explicitly enumerated. A form outside this set is
// rejected rather than handed to the linker as an unclassified native artifact.
func mir_runtime_package_form_is_valid(value: str) int {
    if std.str_eq(value, "static_archive") == 1 { return 1; }
    if std.str_eq(value, "deterministic_object_set") == 1 { return 1; }
    if std.str_eq(value, "explicit_native_library") == 1 { return 1; }
    return 0;
}

// Requirement identity survives every runtime-facing call shape Phase 16 already
// supports. A backend that meets an unlisted shape has no requirement to consume
// and is rejected rather than allowed to guess one.
func mir_runtime_call_kind_is_valid(value: str) int {
    if std.str_eq(value, "direct_call") == 1 { return 1; }
    if std.str_eq(value, "selected_indirect_call") == 1 { return 1; }
    if std.str_eq(value, "cleanup_or_destructor") == 1 { return 1; }
    if std.str_eq(value, "cross_module_composition") == 1 { return 1; }
    if std.str_eq(value, "runtime_module_call") == 1 { return 1; }
    return 0;
}

// Deterministic request-local identities derive only from compiler semantic
// state and stable request ordinals. Raw source, registry, generated-C,
// object, archive, linker-command, and Markdown bytes never participate.
func mir_runtime_abi_identity_id(module_id: str, target_id: str, request_ordinal: int, ctx: &Arena) str { mut value := "runtime_abi:v1:module="; value = std.Concat(value, module_id); value = std.Concat(value, ":target="); value = std.Concat(value, target_id); value = std.Concat(value, ":ordinal="); value = std.Concat(value, std.FormatInt(request_ordinal)); return std.Clone(ctx, value); }
func mir_runtime_helper_identity_id(operation_id: str, target_id: str, request_ordinal: int, ctx: &Arena) str { mut value := "runtime_helper:v1:operation="; value = std.Concat(value, operation_id); value = std.Concat(value, ":target="); value = std.Concat(value, target_id); value = std.Concat(value, ":ordinal="); value = std.Concat(value, std.FormatInt(request_ordinal)); return std.Clone(ctx, value); }
func mir_runtime_classification_id(helper_id: str, request_ordinal: int, ctx: &Arena) str { mut value := "runtime_classification:v1:helper="; value = std.Concat(value, helper_id); value = std.Concat(value, ":ordinal="); value = std.Concat(value, std.FormatInt(request_ordinal)); return std.Clone(ctx, value); }
func mir_runtime_symbol_identity_id(helper_id: str, symbol_version: str, target_id: str, request_ordinal: int, ctx: &Arena) str { mut value := "runtime_symbol:v1:helper="; value = std.Concat(value, helper_id); value = std.Concat(value, ":version="); value = std.Concat(value, symbol_version); value = std.Concat(value, ":target="); value = std.Concat(value, target_id); value = std.Concat(value, ":ordinal="); value = std.Concat(value, std.FormatInt(request_ordinal)); return std.Clone(ctx, value); }
func mir_runtime_component_identity_id(component_kind: str, target_id: str, request_ordinal: int, ctx: &Arena) str { mut value := "runtime_component:v1:kind="; value = std.Concat(value, component_kind); value = std.Concat(value, ":target="); value = std.Concat(value, target_id); value = std.Concat(value, ":ordinal="); value = std.Concat(value, std.FormatInt(request_ordinal)); return std.Clone(ctx, value); }
func mir_runtime_package_identity_id(target_id: str, package_version: str, request_ordinal: int, ctx: &Arena) str { mut value := "runtime_package:v1:target="; value = std.Concat(value, target_id); value = std.Concat(value, ":version="); value = std.Concat(value, package_version); value = std.Concat(value, ":ordinal="); value = std.Concat(value, std.FormatInt(request_ordinal)); return std.Clone(ctx, value); }
func mir_runtime_requirement_id(program_id: str, helper_id: str, request_ordinal: int, ctx: &Arena) str { mut value := "runtime_requirement:v1:program="; value = std.Concat(value, program_id); value = std.Concat(value, ":helper="); value = std.Concat(value, helper_id); value = std.Concat(value, ":ordinal="); value = std.Concat(value, std.FormatInt(request_ordinal)); return std.Clone(ctx, value); }
func mir_runtime_gust_module_id(component_id: str, runtime_abi_id: str, target_id: str, request_ordinal: int, ctx: &Arena) str { mut value := "runtime_gust_module:v1:component="; value = std.Concat(value, component_id); value = std.Concat(value, ":abi="); value = std.Concat(value, runtime_abi_id); value = std.Concat(value, ":target="); value = std.Concat(value, target_id); value = std.Concat(value, ":ordinal="); value = std.Concat(value, std.FormatInt(request_ordinal)); return std.Clone(ctx, value); }
func mir_runtime_retained_c_component_id(component_id: str, runtime_abi_id: str, target_id: str, request_ordinal: int, ctx: &Arena) str { mut value := "runtime_retained_c:v1:component="; value = std.Concat(value, component_id); value = std.Concat(value, ":abi="); value = std.Concat(value, runtime_abi_id); value = std.Concat(value, ":target="); value = std.Concat(value, target_id); value = std.Concat(value, ":ordinal="); value = std.Concat(value, std.FormatInt(request_ordinal)); return std.Clone(ctx, value); }
func mir_runtime_rust_component_id(component_id: str, runtime_abi_id: str, target_id: str, request_ordinal: int, ctx: &Arena) str { mut value := "runtime_rust_component:v1:component="; value = std.Concat(value, component_id); value = std.Concat(value, ":abi="); value = std.Concat(value, runtime_abi_id); value = std.Concat(value, ":target="); value = std.Concat(value, target_id); value = std.Concat(value, ":ordinal="); value = std.Concat(value, std.FormatInt(request_ordinal)); return std.Clone(ctx, value); }
func mir_runtime_import_declaration_id(helper_id: str, symbol_version: str, target_id: str, request_ordinal: int, ctx: &Arena) str { mut value := "runtime_import:v1:helper="; value = std.Concat(value, helper_id); value = std.Concat(value, ":version="); value = std.Concat(value, symbol_version); value = std.Concat(value, ":target="); value = std.Concat(value, target_id); value = std.Concat(value, ":ordinal="); value = std.Concat(value, std.FormatInt(request_ordinal)); return std.Clone(ctx, value); }
func mir_runtime_package_member_id(package_id: str, component_id: str, link_order: int, ctx: &Arena) str { mut value := "runtime_package_member:v1:package="; value = std.Concat(value, package_id); value = std.Concat(value, ":component="); value = std.Concat(value, component_id); value = std.Concat(value, ":link_order="); value = std.Concat(value, std.FormatInt(link_order)); return std.Clone(ctx, value); }
func mir_runtime_package_provided_symbol_id(package_id: str, symbol_id: str, request_ordinal: int, ctx: &Arena) str { mut value := "runtime_package_provided:v1:package="; value = std.Concat(value, package_id); value = std.Concat(value, ":symbol="); value = std.Concat(value, symbol_id); value = std.Concat(value, ":ordinal="); value = std.Concat(value, std.FormatInt(request_ordinal)); return std.Clone(ctx, value); }
func mir_runtime_package_system_import_id(package_id: str, external_spelling: str, request_ordinal: int, ctx: &Arena) str { mut value := "runtime_package_system_import:v1:package="; value = std.Concat(value, package_id); value = std.Concat(value, ":spelling="); value = std.Concat(value, external_spelling); value = std.Concat(value, ":ordinal="); value = std.Concat(value, std.FormatInt(request_ordinal)); return std.Clone(ctx, value); }
func mir_runtime_mir_reference_id(mir_operation_id: str, helper_id: str, request_ordinal: int, ctx: &Arena) str { mut value := "runtime_mir_reference:v1:operation="; value = std.Concat(value, mir_operation_id); value = std.Concat(value, ":helper="); value = std.Concat(value, helper_id); value = std.Concat(value, ":ordinal="); value = std.Concat(value, std.FormatInt(request_ordinal)); return std.Clone(ctx, value); }
func mir_runtime_compatibility_decision_id(requirement_id: str, package_id: str, request_ordinal: int, ctx: &Arena) str { mut value := "runtime_compatibility:v1:requirement="; value = std.Concat(value, requirement_id); value = std.Concat(value, ":package="); value = std.Concat(value, package_id); value = std.Concat(value, ":ordinal="); value = std.Concat(value, std.FormatInt(request_ordinal)); return std.Clone(ctx, value); }
func mir_runtime_link_plan_id(program_id: str, package_id: str, target_id: str, request_ordinal: int, ctx: &Arena) str { mut value := "runtime_link_plan:v1:program="; value = std.Concat(value, program_id); value = std.Concat(value, ":package="); value = std.Concat(value, package_id); value = std.Concat(value, ":target="); value = std.Concat(value, target_id); value = std.Concat(value, ":ordinal="); value = std.Concat(value, std.FormatInt(request_ordinal)); return std.Clone(ctx, value); }

func mir_runtime_make_empty_table(target_id: str, target_triple: str, ctx: &Arena) MirRuntimeBoundaryAuthorityTable[ctx] {
    mut table: MirRuntimeBoundaryAuthorityTable[ctx];
    table.format = std.Clone(ctx, "gust.compiler_runtime_boundary_authority_table.v1");
    table.target_id = std.Clone(ctx, target_id);
    table.target_triple = std.Clone(ctx, target_triple);
    table.semantic_authority = std.Clone(ctx, "compiler_owned_native_runtime_boundary_authority");
    table.identity_policy = std.Clone(ctx, "compiler_semantic_state_plus_request_ordinal_no_raw_hash");
    table.classification_policy = std.Clone(ctx, "exactly_one_of_five_compiler_owned_helper_classifications");
    table.requirement_policy = std.Clone(ctx, "compiler_produced_requirements_only_worker_must_not_invent");
    table.link_plan_policy = std.Clone(ctx, "phase9g_consumes_validated_runtime_handoff_no_unresolved_symbol_inference");
    table.runtime_abis = mir_runtime_empty_abis(ctx);
    table.helpers = mir_runtime_empty_helpers(ctx);
    table.classifications = mir_runtime_empty_classifications(ctx);
    table.symbols = mir_runtime_empty_symbols(ctx);
    table.components = mir_runtime_empty_components(ctx);
    table.packages = mir_runtime_empty_packages(ctx);
    table.package_members = mir_runtime_empty_package_members(ctx);
    table.package_provided_symbols = mir_runtime_empty_package_provided_symbols(ctx);
    table.package_system_imports = mir_runtime_empty_package_system_imports(ctx);
    table.import_declarations = mir_runtime_empty_import_declarations(ctx);
    table.rust_components = mir_runtime_empty_rust_components(ctx);
    table.retained_c_components = mir_runtime_empty_retained_c_components(ctx);
    table.gust_modules = mir_runtime_empty_gust_modules(ctx);
    table.requirements = mir_runtime_empty_requirements(ctx);
    table.compatibility_decisions = mir_runtime_empty_compatibility(ctx);
    table.link_plans = mir_runtime_empty_link_plans(ctx);
    table.mir_references = mir_runtime_empty_references(ctx);
    return table;
}

func mir_runtime_table_with_abi(table: MirRuntimeBoundaryAuthorityTable[ctx], value: MirRuntimeAbiIdentity[ctx], ctx: &Arena) MirRuntimeBoundaryAuthorityTable[ctx] { mut values: std.Vector[MirRuntimeAbiIdentity[ctx], ctx] := ctx[table.runtime_abis]; values.Push(value); ctx.Set(table.runtime_abis, values); return table; }
func mir_runtime_table_with_helper(table: MirRuntimeBoundaryAuthorityTable[ctx], value: MirRuntimeHelperIdentity[ctx], ctx: &Arena) MirRuntimeBoundaryAuthorityTable[ctx] { mut values: std.Vector[MirRuntimeHelperIdentity[ctx], ctx] := ctx[table.helpers]; values.Push(value); ctx.Set(table.helpers, values); return table; }
func mir_runtime_table_with_classification(table: MirRuntimeBoundaryAuthorityTable[ctx], value: MirRuntimeHelperClassification[ctx], ctx: &Arena) MirRuntimeBoundaryAuthorityTable[ctx] { mut values: std.Vector[MirRuntimeHelperClassification[ctx], ctx] := ctx[table.classifications]; values.Push(value); ctx.Set(table.classifications, values); return table; }
func mir_runtime_table_with_symbol(table: MirRuntimeBoundaryAuthorityTable[ctx], value: MirRuntimeSymbolIdentity[ctx], ctx: &Arena) MirRuntimeBoundaryAuthorityTable[ctx] { mut values: std.Vector[MirRuntimeSymbolIdentity[ctx], ctx] := ctx[table.symbols]; values.Push(value); ctx.Set(table.symbols, values); return table; }
func mir_runtime_table_with_component(table: MirRuntimeBoundaryAuthorityTable[ctx], value: MirRuntimeComponentIdentity[ctx], ctx: &Arena) MirRuntimeBoundaryAuthorityTable[ctx] { mut values: std.Vector[MirRuntimeComponentIdentity[ctx], ctx] := ctx[table.components]; values.Push(value); ctx.Set(table.components, values); return table; }
func mir_runtime_table_with_package(table: MirRuntimeBoundaryAuthorityTable[ctx], value: MirRuntimePackageIdentity[ctx], ctx: &Arena) MirRuntimeBoundaryAuthorityTable[ctx] { mut values: std.Vector[MirRuntimePackageIdentity[ctx], ctx] := ctx[table.packages]; values.Push(value); ctx.Set(table.packages, values); return table; }
func mir_runtime_table_with_package_member(table: MirRuntimeBoundaryAuthorityTable[ctx], value: MirRuntimePackageMember[ctx], ctx: &Arena) MirRuntimeBoundaryAuthorityTable[ctx] { mut values: std.Vector[MirRuntimePackageMember[ctx], ctx] := ctx[table.package_members]; values.Push(value); ctx.Set(table.package_members, values); return table; }
func mir_runtime_table_with_package_provided_symbol(table: MirRuntimeBoundaryAuthorityTable[ctx], value: MirRuntimePackageProvidedSymbol[ctx], ctx: &Arena) MirRuntimeBoundaryAuthorityTable[ctx] { mut values: std.Vector[MirRuntimePackageProvidedSymbol[ctx], ctx] := ctx[table.package_provided_symbols]; values.Push(value); ctx.Set(table.package_provided_symbols, values); return table; }
func mir_runtime_table_with_package_system_import(table: MirRuntimeBoundaryAuthorityTable[ctx], value: MirRuntimePackageSystemImport[ctx], ctx: &Arena) MirRuntimeBoundaryAuthorityTable[ctx] { mut values: std.Vector[MirRuntimePackageSystemImport[ctx], ctx] := ctx[table.package_system_imports]; values.Push(value); ctx.Set(table.package_system_imports, values); return table; }
func mir_runtime_table_with_gust_module(table: MirRuntimeBoundaryAuthorityTable[ctx], value: MirRuntimeGustModule[ctx], ctx: &Arena) MirRuntimeBoundaryAuthorityTable[ctx] { mut values: std.Vector[MirRuntimeGustModule[ctx], ctx] := ctx[table.gust_modules]; values.Push(value); ctx.Set(table.gust_modules, values); return table; }
func mir_runtime_table_with_retained_c_component(table: MirRuntimeBoundaryAuthorityTable[ctx], value: MirRuntimeRetainedCComponent[ctx], ctx: &Arena) MirRuntimeBoundaryAuthorityTable[ctx] { mut values: std.Vector[MirRuntimeRetainedCComponent[ctx], ctx] := ctx[table.retained_c_components]; values.Push(value); ctx.Set(table.retained_c_components, values); return table; }
func mir_runtime_table_with_rust_component(table: MirRuntimeBoundaryAuthorityTable[ctx], value: MirRuntimeRustComponent[ctx], ctx: &Arena) MirRuntimeBoundaryAuthorityTable[ctx] { mut values: std.Vector[MirRuntimeRustComponent[ctx], ctx] := ctx[table.rust_components]; values.Push(value); ctx.Set(table.rust_components, values); return table; }
func mir_runtime_table_with_import_declaration(table: MirRuntimeBoundaryAuthorityTable[ctx], value: MirRuntimeImportDeclaration[ctx], ctx: &Arena) MirRuntimeBoundaryAuthorityTable[ctx] { mut values: std.Vector[MirRuntimeImportDeclaration[ctx], ctx] := ctx[table.import_declarations]; values.Push(value); ctx.Set(table.import_declarations, values); return table; }
func mir_runtime_table_with_requirement(table: MirRuntimeBoundaryAuthorityTable[ctx], value: MirRuntimeRequirement[ctx], ctx: &Arena) MirRuntimeBoundaryAuthorityTable[ctx] { mut values: std.Vector[MirRuntimeRequirement[ctx], ctx] := ctx[table.requirements]; values.Push(value); ctx.Set(table.requirements, values); return table; }
func mir_runtime_table_with_compatibility(table: MirRuntimeBoundaryAuthorityTable[ctx], value: MirRuntimeCompatibilityDecision[ctx], ctx: &Arena) MirRuntimeBoundaryAuthorityTable[ctx] { mut values: std.Vector[MirRuntimeCompatibilityDecision[ctx], ctx] := ctx[table.compatibility_decisions]; values.Push(value); ctx.Set(table.compatibility_decisions, values); return table; }
func mir_runtime_table_with_link_plan(table: MirRuntimeBoundaryAuthorityTable[ctx], value: MirRuntimeLinkPlanHandoff[ctx], ctx: &Arena) MirRuntimeBoundaryAuthorityTable[ctx] { mut values: std.Vector[MirRuntimeLinkPlanHandoff[ctx], ctx] := ctx[table.link_plans]; values.Push(value); ctx.Set(table.link_plans, values); return table; }
func mir_runtime_table_with_mir_reference(table: MirRuntimeBoundaryAuthorityTable[ctx], value: MirRuntimeMirReference[ctx], ctx: &Arena) MirRuntimeBoundaryAuthorityTable[ctx] { mut values: std.Vector[MirRuntimeMirReference[ctx], ctx] := ctx[table.mir_references]; values.Push(value); ctx.Set(table.mir_references, values); return table; }

// runtime_helper_of(operation)
func mir_runtime_helper_of(table: MirRuntimeBoundaryAuthorityTable[ctx], operation_id: str, ctx: &Arena) MirRuntimeHelperQuery[ctx] { mut result: MirRuntimeHelperQuery[ctx]; result.found = 0; mut values: std.Vector[MirRuntimeHelperIdentity[ctx], ctx] := ctx[table.helpers]; mut index := 0; while index < len(values) { if std.str_eq(values[index].operation_id, operation_id) == 1 { result.found = 1; result.value = values[index]; return result; } index = index + 1; } return result; }

func mir_runtime_helper_by_id(table: MirRuntimeBoundaryAuthorityTable[ctx], helper_id: str, ctx: &Arena) MirRuntimeHelperQuery[ctx] { mut result: MirRuntimeHelperQuery[ctx]; result.found = 0; mut values: std.Vector[MirRuntimeHelperIdentity[ctx], ctx] := ctx[table.helpers]; mut index := 0; while index < len(values) { if std.str_eq(values[index].helper_id, helper_id) == 1 { result.found = 1; result.value = values[index]; return result; } index = index + 1; } return result; }

// classify_runtime_helper(helper)
func mir_classify_runtime_helper(table: MirRuntimeBoundaryAuthorityTable[ctx], helper_id: str, ctx: &Arena) MirRuntimeClassificationQuery[ctx] { mut result: MirRuntimeClassificationQuery[ctx]; result.found = 0; mut values: std.Vector[MirRuntimeHelperClassification[ctx], ctx] := ctx[table.classifications]; mut index := 0; while index < len(values) { if std.str_eq(values[index].helper_id, helper_id) == 1 { result.found = 1; result.value = values[index]; return result; } index = index + 1; } return result; }

// runtime_abi_for(target)
func mir_runtime_abi_for(table: MirRuntimeBoundaryAuthorityTable[ctx], target_id: str, ctx: &Arena) MirRuntimeAbiQuery[ctx] { mut result: MirRuntimeAbiQuery[ctx]; result.found = 0; mut values: std.Vector[MirRuntimeAbiIdentity[ctx], ctx] := ctx[table.runtime_abis]; mut index := 0; while index < len(values) { if std.str_eq(values[index].target_id, target_id) == 1 { result.found = 1; result.value = values[index]; return result; } index = index + 1; } return result; }

// runtime_symbol_for(helper, target)
func mir_runtime_symbol_for(table: MirRuntimeBoundaryAuthorityTable[ctx], helper_id: str, target_id: str, ctx: &Arena) MirRuntimeSymbolQuery[ctx] { mut result: MirRuntimeSymbolQuery[ctx]; result.found = 0; mut values: std.Vector[MirRuntimeSymbolIdentity[ctx], ctx] := ctx[table.symbols]; mut index := 0; while index < len(values) { if std.str_eq(values[index].helper_id, helper_id) == 1 && std.str_eq(values[index].target_id, target_id) == 1 { result.found = 1; result.value = values[index]; return result; } index = index + 1; } return result; }

func mir_runtime_symbol_by_id(table: MirRuntimeBoundaryAuthorityTable[ctx], symbol_id: str, ctx: &Arena) MirRuntimeSymbolQuery[ctx] { mut result: MirRuntimeSymbolQuery[ctx]; result.found = 0; mut values: std.Vector[MirRuntimeSymbolIdentity[ctx], ctx] := ctx[table.symbols]; mut index := 0; while index < len(values) { if std.str_eq(values[index].symbol_id, symbol_id) == 1 { result.found = 1; result.value = values[index]; return result; } index = index + 1; } return result; }

func mir_runtime_abi_by_id(table: MirRuntimeBoundaryAuthorityTable[ctx], runtime_abi_id: str, ctx: &Arena) MirRuntimeAbiQuery[ctx] { mut result: MirRuntimeAbiQuery[ctx]; result.found = 0; mut values: std.Vector[MirRuntimeAbiIdentity[ctx], ctx] := ctx[table.runtime_abis]; mut index := 0; while index < len(values) { if std.str_eq(values[index].runtime_abi_id, runtime_abi_id) == 1 { result.found = 1; result.value = values[index]; return result; } index = index + 1; } return result; }

func mir_runtime_validate_symbol_spelling(table: MirRuntimeBoundaryAuthorityTable[ctx], symbol_id: str, proposed_spelling: str, ctx: &Arena) MirRuntimeAuthorityValidation[ctx] { mut symbols: std.Vector[MirRuntimeSymbolIdentity[ctx], ctx] := ctx[table.symbols]; mut index := 0; while index < len(symbols) { if std.str_eq(symbols[index].symbol_id, symbol_id) == 1 { if std.str_eq(symbols[index].external_spelling, proposed_spelling) == 0 { return mir_runtime_validation(0, "runtime_symbol_backend_substitution", ctx); } return mir_runtime_validation(1, "runtime_symbol_spelling_valid", ctx); } index = index + 1; } return mir_runtime_validation(0, "runtime_symbol_unknown_abi", ctx); }

// runtime_requirements(program)
func mir_runtime_requirements(table: MirRuntimeBoundaryAuthorityTable[ctx], program_id: str, ctx: &Arena) Index[std.Vector[MirRuntimeRequirement[ctx], ctx], ctx] { mut result := mir_runtime_empty_requirements(ctx); mut output: std.Vector[MirRuntimeRequirement[ctx], ctx] := ctx[result]; mut values: std.Vector[MirRuntimeRequirement[ctx], ctx] := ctx[table.requirements]; mut index := 0; while index < len(values) { if std.str_eq(values[index].program_id, program_id) == 1 { output.Push(values[index]); } index = index + 1; } ctx.Set(result, output); return result; }

func mir_runtime_requirement_by_id(table: MirRuntimeBoundaryAuthorityTable[ctx], requirement_id: str, ctx: &Arena) MirRuntimeRequirementQuery[ctx] { mut result: MirRuntimeRequirementQuery[ctx]; result.found = 0; mut values: std.Vector[MirRuntimeRequirement[ctx], ctx] := ctx[table.requirements]; mut index := 0; while index < len(values) { if std.str_eq(values[index].requirement_id, requirement_id) == 1 { result.found = 1; result.value = values[index]; return result; } index = index + 1; } return result; }

// runtime_requirement_for(mir_operation) resolves the compiler-produced owner of
// one canonical MIR runtime operation through its reference record.
func mir_runtime_requirement_for(table: MirRuntimeBoundaryAuthorityTable[ctx], mir_operation_id: str, ctx: &Arena) MirRuntimeRequirementQuery[ctx] { mut result: MirRuntimeRequirementQuery[ctx]; result.found = 0; mut references: std.Vector[MirRuntimeMirReference[ctx], ctx] := ctx[table.mir_references]; mut index := 0; while index < len(references) { if std.str_eq(references[index].mir_operation_id, mir_operation_id) == 1 { return mir_runtime_requirement_by_id(table, references[index].requirement_id, ctx); } index = index + 1; } return result; }

func mir_runtime_mir_reference_for(table: MirRuntimeBoundaryAuthorityTable[ctx], mir_operation_id: str, ctx: &Arena) MirRuntimeMirReferenceQuery[ctx] { mut result: MirRuntimeMirReferenceQuery[ctx]; result.found = 0; mut values: std.Vector[MirRuntimeMirReference[ctx], ctx] := ctx[table.mir_references]; mut index := 0; while index < len(values) { if std.str_eq(values[index].mir_operation_id, mir_operation_id) == 1 { result.found = 1; result.value = values[index]; return result; } index = index + 1; } return result; }

// runtime_requirement_table(program) is the deterministic deduplicated table the
// native request carries. Order follows first appearance in the compiler-owned
// requirement inventory, and each symbol contributes exactly one row.
func mir_runtime_requirement_table(table: MirRuntimeBoundaryAuthorityTable[ctx], program_id: str, ctx: &Arena) Index[std.Vector[MirRuntimeRequirement[ctx], ctx], ctx] {
    mut result := mir_runtime_empty_requirements(ctx);
    mut output: std.Vector[MirRuntimeRequirement[ctx], ctx] := ctx[result];
    mut values: std.Vector[MirRuntimeRequirement[ctx], ctx] := ctx[table.requirements];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].program_id, program_id) == 1 {
            mut duplicate := 0;
            mut output_index := 0;
            while output_index < len(output) {
                if std.str_eq(output[output_index].symbol_id, values[index].symbol_id) == 1 { duplicate = 1; }
                output_index = output_index + 1;
            }
            if duplicate == 0 { output.Push(values[index]); }
        }
        index = index + 1;
    }
    ctx.Set(result, output);
    return result;
}

// runtime_import_for(helper, target) is the single source Cranelift consults to
// emit a direct external call. A backend that cannot find one here has no
// licence to invent a spelling or a signature for the symbol.
func mir_runtime_import_for(table: MirRuntimeBoundaryAuthorityTable[ctx], helper_id: str, target_id: str, ctx: &Arena) MirRuntimeImportQuery[ctx] { mut result: MirRuntimeImportQuery[ctx]; result.found = 0; mut values: std.Vector[MirRuntimeImportDeclaration[ctx], ctx] := ctx[table.import_declarations]; mut index := 0; while index < len(values) { if std.str_eq(values[index].helper_id, helper_id) == 1 && std.str_eq(values[index].target_id, target_id) == 1 { result.found = 1; result.value = values[index]; return result; } index = index + 1; } return result; }

func mir_runtime_import_by_id(table: MirRuntimeBoundaryAuthorityTable[ctx], import_id: str, ctx: &Arena) MirRuntimeImportQuery[ctx] { mut result: MirRuntimeImportQuery[ctx]; result.found = 0; mut values: std.Vector[MirRuntimeImportDeclaration[ctx], ctx] := ctx[table.import_declarations]; mut index := 0; while index < len(values) { if std.str_eq(values[index].import_id, import_id) == 1 { result.found = 1; result.value = values[index]; return result; } index = index + 1; } return result; }

// Side-effect and failure policies are enumerated so a backend cannot assume a
// runtime import is pure, or that it can never fail, in order to optimise it.
func mir_runtime_side_effect_policy_is_valid(value: str) int {
    if std.str_eq(value, "pure_scalar_no_side_effects") == 1 { return 1; }
    if std.str_eq(value, "observable_side_effects") == 1 { return 1; }
    if std.str_eq(value, "allocates_in_caller_arena") == 1 { return 1; }
    return 0;
}

func mir_runtime_failure_policy_is_valid(value: str) int {
    if std.str_eq(value, "total_cannot_fail") == 1 { return 1; }
    if std.str_eq(value, "returns_explicit_error") == 1 { return 1; }
    if std.str_eq(value, "aborts_process_on_failure") == 1 { return 1; }
    return 0;
}

// runtime_component_for(helper, target)
func mir_runtime_component_for(table: MirRuntimeBoundaryAuthorityTable[ctx], helper_id: str, target_id: str, ctx: &Arena) MirRuntimeComponentQuery[ctx] { mut result: MirRuntimeComponentQuery[ctx]; result.found = 0; mut classification := mir_classify_runtime_helper(table, helper_id, ctx); if classification.found == 0 { return result; } mut values: std.Vector[MirRuntimeComponentIdentity[ctx], ctx] := ctx[table.components]; mut index := 0; while index < len(values) { if std.str_eq(values[index].component_id, classification.value.component_id) == 1 && std.str_eq(values[index].target_id, target_id) == 1 { result.found = 1; result.value = values[index]; return result; } index = index + 1; } return result; }

// select_runtime_package(requirements, target)
func mir_select_runtime_package(table: MirRuntimeBoundaryAuthorityTable[ctx], requirements: Index[std.Vector[MirRuntimeRequirement[ctx], ctx], ctx], target_id: str, ctx: &Arena) MirRuntimePackageQuery[ctx] { mut result: MirRuntimePackageQuery[ctx]; result.found = 0; mut required_values: std.Vector[MirRuntimeRequirement[ctx], ctx] := ctx[requirements]; mut packages: std.Vector[MirRuntimePackageIdentity[ctx], ctx] := ctx[table.packages]; mut index := 0; while index < len(packages) { if packages[index].available == 1 && std.str_eq(packages[index].target_id, target_id) == 1 { mut all_match := 1; mut req_index := 0; while req_index < len(required_values) { if std.str_eq(required_values[req_index].package_id, packages[index].package_id) == 0 { all_match = 0; } req_index = req_index + 1; } if all_match == 1 { result.found = 1; result.value = packages[index]; return result; } } index = index + 1; } return result; }

func mir_runtime_package_by_id(table: MirRuntimeBoundaryAuthorityTable[ctx], package_id: str, ctx: &Arena) MirRuntimePackageQuery[ctx] { mut result: MirRuntimePackageQuery[ctx]; result.found = 0; mut values: std.Vector[MirRuntimePackageIdentity[ctx], ctx] := ctx[table.packages]; mut index := 0; while index < len(values) { if std.str_eq(values[index].package_id, package_id) == 1 { result.found = 1; result.value = values[index]; return result; } index = index + 1; } return result; }

func mir_runtime_package_provides_symbol(table: MirRuntimeBoundaryAuthorityTable[ctx], package_id: str, symbol_id: str, ctx: &Arena) int { mut values: std.Vector[MirRuntimePackageProvidedSymbol[ctx], ctx] := ctx[table.package_provided_symbols]; mut index := 0; while index < len(values) { if std.str_eq(values[index].package_id, package_id) == 1 && std.str_eq(values[index].symbol_id, symbol_id) == 1 { return 1; } index = index + 1; } return 0; }

// runtime_package_manifest(package) reports the enumerated manifest surface.
// Counts are derived from the declared records rather than stored, so a manifest
// can never claim more or fewer members than it actually enumerates.
func mir_runtime_package_manifest(table: MirRuntimeBoundaryAuthorityTable[ctx], package_id: str, ctx: &Arena) MirRuntimePackageManifestQuery[ctx] {
    mut result: MirRuntimePackageManifestQuery[ctx];
    result.valid = 0;
    result.member_count = 0;
    result.provided_symbol_count = 0;
    result.system_import_count = 0;
    mut package := mir_runtime_package_by_id(table, package_id, ctx);
    if package.found == 0 { result.reason_code = std.Clone(ctx, "runtime_package_target_mismatch"); return result; }
    mut members: std.Vector[MirRuntimePackageMember[ctx], ctx] := ctx[table.package_members];
    mut index := 0;
    while index < len(members) { if std.str_eq(members[index].package_id, package_id) == 1 { result.member_count = result.member_count + 1; } index = index + 1; }
    mut provided: std.Vector[MirRuntimePackageProvidedSymbol[ctx], ctx] := ctx[table.package_provided_symbols];
    index = 0;
    while index < len(provided) { if std.str_eq(provided[index].package_id, package_id) == 1 { result.provided_symbol_count = result.provided_symbol_count + 1; } index = index + 1; }
    mut imports: std.Vector[MirRuntimePackageSystemImport[ctx], ctx] := ctx[table.package_system_imports];
    index = 0;
    while index < len(imports) { if std.str_eq(imports[index].package_id, package_id) == 1 { result.system_import_count = result.system_import_count + 1; } index = index + 1; }
    result.valid = 1;
    result.reason_code = std.Clone(ctx, "runtime_package_manifest_valid");
    return result;
}

// select_runtime_package_for_target(requirements, target) is the compiler-owned
// compatibility decision. Exactly one available package must satisfy every
// requirement; zero and two are both rejections rather than a linker fallback.
func mir_runtime_select_package_for_target(table: MirRuntimeBoundaryAuthorityTable[ctx], requirements: Index[std.Vector[MirRuntimeRequirement[ctx], ctx], ctx], target_id: str, ctx: &Arena) MirRuntimePackageSelection[ctx] {
    mut result: MirRuntimePackageSelection[ctx];
    result.found = 0;
    result.reason_code = std.Clone(ctx, "runtime_package_missing_mandatory_symbol");
    mut required_values: std.Vector[MirRuntimeRequirement[ctx], ctx] := ctx[requirements];
    mut packages: std.Vector[MirRuntimePackageIdentity[ctx], ctx] := ctx[table.packages];
    mut candidate_count := 0;
    mut package_index := 0;
    while package_index < len(packages) {
        if packages[package_index].available == 1 && std.str_eq(packages[package_index].target_id, target_id) == 1 {
            mut satisfies := 1;
            mut requirement_index := 0;
            while requirement_index < len(required_values) {
                if mir_runtime_package_provides_symbol(table, packages[package_index].package_id, required_values[requirement_index].symbol_id, ctx) == 0 { satisfies = 0; }
                if std.str_eq(required_values[requirement_index].runtime_abi_id, packages[package_index].runtime_abi_id) == 0 { satisfies = 0; }
                if required_values[requirement_index].required_version_min < packages[package_index].compatible_version_min ||
                   required_values[requirement_index].required_version_max > packages[package_index].compatible_version_max
                {
                    satisfies = 0;
                }
                requirement_index = requirement_index + 1;
            }
            if satisfies == 1 {
                candidate_count = candidate_count + 1;
                if candidate_count == 1 { result.value = packages[package_index]; }
            }
        }
        package_index = package_index + 1;
    }
    if candidate_count > 1 { result.found = 0; result.reason_code = std.Clone(ctx, "runtime_package_ambiguous_selection"); return result; }
    if candidate_count == 0 { return result; }
    result.found = 1;
    result.reason_code = std.Clone(ctx, "runtime_package_selected");
    return result;
}

// validate_runtime_compatibility(requirements, package)
func mir_validate_runtime_compatibility(table: MirRuntimeBoundaryAuthorityTable[ctx], requirements: Index[std.Vector[MirRuntimeRequirement[ctx], ctx], ctx], package_id: str, ctx: &Arena) MirRuntimeCompatibilityQuery[ctx] { mut result: MirRuntimeCompatibilityQuery[ctx]; result.compatible = 0; result.reason_code = std.Clone(ctx, "runtime_compatibility_mismatch"); mut required_values: std.Vector[MirRuntimeRequirement[ctx], ctx] := ctx[requirements]; mut decisions: std.Vector[MirRuntimeCompatibilityDecision[ctx], ctx] := ctx[table.compatibility_decisions]; mut req_index := 0; while req_index < len(required_values) { mut found := 0; mut decision_index := 0; while decision_index < len(decisions) { if std.str_eq(decisions[decision_index].requirement_id, required_values[req_index].requirement_id) == 1 && std.str_eq(decisions[decision_index].package_id, package_id) == 1 && decisions[decision_index].compatible == 1 { found = 1; } decision_index = decision_index + 1; } if found == 0 { return result; } req_index = req_index + 1; } result.compatible = 1; result.reason_code = std.Clone(ctx, "runtime_compatible"); return result; }

// runtime_link_plan(program, package)
func mir_runtime_link_plan(table: MirRuntimeBoundaryAuthorityTable[ctx], program_id: str, package_id: str, ctx: &Arena) MirRuntimeLinkPlanQuery[ctx] { mut result: MirRuntimeLinkPlanQuery[ctx]; result.found = 0; mut values: std.Vector[MirRuntimeLinkPlanHandoff[ctx], ctx] := ctx[table.link_plans]; mut index := 0; while index < len(values) { if std.str_eq(values[index].program_id, program_id) == 1 && std.str_eq(values[index].package_id, package_id) == 1 { result.found = 1; result.value = values[index]; return result; } index = index + 1; } return result; }

func mir_runtime_validation(valid: int, reason_code: str, ctx: &Arena) MirRuntimeAuthorityValidation[ctx] { mut result: MirRuntimeAuthorityValidation[ctx]; result.valid = valid; result.reason_code = std.Clone(ctx, reason_code); return result; }

func mir_runtime_boundary_authority_table_validate(table: MirRuntimeBoundaryAuthorityTable[ctx], ctx: &Arena) MirRuntimeAuthorityValidation[ctx] {
    if std.str_eq(table.format, "gust.compiler_runtime_boundary_authority_table.v1") == 0 { return mir_runtime_validation(0, "runtime_authority_unknown_format", ctx); }
    if std.str_eq(table.semantic_authority, "compiler_owned_native_runtime_boundary_authority") == 0 || std.str_eq(table.classification_policy, "exactly_one_of_five_compiler_owned_helper_classifications") == 0 || std.str_eq(table.requirement_policy, "compiler_produced_requirements_only_worker_must_not_invent") == 0 || std.str_eq(table.link_plan_policy, "phase9g_consumes_validated_runtime_handoff_no_unresolved_symbol_inference") == 0 { return mir_runtime_validation(0, "runtime_authority_policy_mismatch", ctx); }
    if mir_runtime_field_is_safe(table.target_id) == 0 || mir_runtime_field_is_safe(table.target_triple) == 0 { return mir_runtime_validation(0, "runtime_target_mismatch", ctx); }
    mut helpers: std.Vector[MirRuntimeHelperIdentity[ctx], ctx] := ctx[table.helpers];
    mut abis: std.Vector[MirRuntimeAbiIdentity[ctx], ctx] := ctx[table.runtime_abis];
    mut classifications: std.Vector[MirRuntimeHelperClassification[ctx], ctx] := ctx[table.classifications];
    mut symbols: std.Vector[MirRuntimeSymbolIdentity[ctx], ctx] := ctx[table.symbols];
    mut components: std.Vector[MirRuntimeComponentIdentity[ctx], ctx] := ctx[table.components];
    mut packages: std.Vector[MirRuntimePackageIdentity[ctx], ctx] := ctx[table.packages];
    mut requirements: std.Vector[MirRuntimeRequirement[ctx], ctx] := ctx[table.requirements];
    mut decisions: std.Vector[MirRuntimeCompatibilityDecision[ctx], ctx] := ctx[table.compatibility_decisions];
    mut plans: std.Vector[MirRuntimeLinkPlanHandoff[ctx], ctx] := ctx[table.link_plans];
    mut references: std.Vector[MirRuntimeMirReference[ctx], ctx] := ctx[table.mir_references];
    mut abi_index := 0;
    while abi_index < len(abis) {
        if mir_runtime_field_is_safe(abis[abi_index].runtime_abi_id) == 0 || mir_runtime_field_is_safe(abis[abi_index].abi_version) == 0 || abis[abi_index].compatible_version_min < 1 || abis[abi_index].compatible_version_max < abis[abi_index].compatible_version_min { return mir_runtime_validation(0, "runtime_abi_version_mismatch", ctx); }
        if std.str_eq(abis[abi_index].target_id, table.target_id) == 0 || std.str_eq(abis[abi_index].target_triple, table.target_triple) == 0 { return mir_runtime_validation(0, "runtime_target_mismatch", ctx); }
        if std.str_eq(abis[abi_index].calling_convention_id, "gust_canonical_v1") == 0 || std.str_eq(abis[abi_index].layout_authority_id, "phase14_compiler_owned_type_and_target_layout") == 0 || std.str_eq(abis[abi_index].function_abi_authority_id, "phase16_compiler_owned_function_abi") == 0 || std.str_eq(abis[abi_index].resource_authority_id, "phase15_compiler_owned_resource_operations") == 0 { return mir_runtime_validation(0, "runtime_abi_authority_mismatch", ctx); }
        mut duplicate_abi_index := abi_index + 1; while duplicate_abi_index < len(abis) { if std.str_eq(abis[abi_index].runtime_abi_id, abis[duplicate_abi_index].runtime_abi_id) == 1 { return mir_runtime_validation(0, "runtime_duplicate_conflicting_abi", ctx); } duplicate_abi_index = duplicate_abi_index + 1; }
        abi_index = abi_index + 1;
    }
    mut helper_index := 0;
    while helper_index < len(helpers) {
        if mir_runtime_field_is_safe(helpers[helper_index].helper_id) == 0 || mir_runtime_field_is_safe(helpers[helper_index].operation_id) == 0 { return mir_runtime_validation(0, "runtime_unknown_helper_id", ctx); }
        mut duplicate_index := helper_index + 1; while duplicate_index < len(helpers) { if std.str_eq(helpers[helper_index].helper_id, helpers[duplicate_index].helper_id) == 1 || std.str_eq(helpers[helper_index].operation_id, helpers[duplicate_index].operation_id) == 1 { return mir_runtime_validation(0, "runtime_duplicate_conflicting_record", ctx); } duplicate_index = duplicate_index + 1; }
        mut classification_count := 0; mut classification_index := 0; while classification_index < len(classifications) { if std.str_eq(classifications[classification_index].helper_id, helpers[helper_index].helper_id) == 1 { classification_count = classification_count + 1; if mir_runtime_helper_classification_is_valid(classifications[classification_index].classification) == 0 { return mir_runtime_validation(0, "runtime_invalid_helper_classification", ctx); } } classification_index = classification_index + 1; }
        if classification_count == 0 { return mir_runtime_validation(0, "runtime_missing_helper_classification", ctx); }
        if classification_count > 1 { return mir_runtime_validation(0, "runtime_conflicting_helper_classification", ctx); }
        mut stable_import := 0; classification_index = 0; while classification_index < len(classifications) { if std.str_eq(classifications[classification_index].helper_id, helpers[helper_index].helper_id) == 1 && std.str_eq(classifications[classification_index].classification, "stable_runtime_library_function") == 1 { stable_import = 1; } classification_index = classification_index + 1; }
        if stable_import == 1 { mut selected_symbol_count := 0; mut selected_symbol_index := 0; while selected_symbol_index < len(symbols) { if std.str_eq(symbols[selected_symbol_index].helper_id, helpers[helper_index].helper_id) == 1 && std.str_eq(symbols[selected_symbol_index].target_id, table.target_id) == 1 { selected_symbol_count = selected_symbol_count + 1; } selected_symbol_index = selected_symbol_index + 1; } if selected_symbol_count == 0 { return mir_runtime_validation(0, "runtime_symbol_unversioned", ctx); } if selected_symbol_count > 1 { return mir_runtime_validation(0, "runtime_symbol_duplicate_conflict", ctx); } }
        helper_index = helper_index + 1;
    }
    mut classification_index := 0; while classification_index < len(classifications) { mut helper := mir_runtime_helper_by_id(table, classifications[classification_index].helper_id, ctx); if helper.found == 0 { return mir_runtime_validation(0, "runtime_unknown_helper_id", ctx); } mut component_found := 0; mut component_index := 0; while component_index < len(components) { if std.str_eq(components[component_index].component_id, classifications[classification_index].component_id) == 1 { component_found = 1; } component_index = component_index + 1; } if component_found == 0 { return mir_runtime_validation(0, "runtime_unknown_component_id", ctx); } classification_index = classification_index + 1; }
    mut symbol_index := 0;
    while symbol_index < len(symbols) {
        mut helper := mir_runtime_helper_by_id(table, symbols[symbol_index].helper_id, ctx);
        if helper.found == 0 { return mir_runtime_validation(0, "runtime_symbol_unknown_helper", ctx); }
        mut classification := mir_classify_runtime_helper(table, symbols[symbol_index].helper_id, ctx);
        if classification.found == 0 || std.str_eq(classification.value.component_id, symbols[symbol_index].component_id) == 0 || std.str_eq(helper.value.symbol_identity, symbols[symbol_index].external_spelling) == 0 { return mir_runtime_validation(0, "runtime_symbol_spelling_abi_conflict", ctx); }
        if mir_runtime_field_is_safe(symbols[symbol_index].symbol_id) == 0 || mir_runtime_field_is_safe(symbols[symbol_index].external_spelling) == 0 || mir_runtime_field_is_safe(symbols[symbol_index].symbol_version) == 0 || mir_runtime_field_is_safe(symbols[symbol_index].function_abi_id) == 0 || mir_runtime_field_is_safe(symbols[symbol_index].visibility) == 0 || mir_runtime_field_is_safe(symbols[symbol_index].linkage) == 0 || mir_runtime_field_is_safe(symbols[symbol_index].compatibility_policy) == 0 { return mir_runtime_validation(0, "runtime_symbol_unversioned", ctx); }
        if std.str_eq(symbols[symbol_index].target_id, table.target_id) == 0 || std.str_eq(symbols[symbol_index].target_triple, table.target_triple) == 0 || std.str_eq(symbols[symbol_index].layout_id, "layout:type:gust:i32") == 0 { return mir_runtime_validation(0, "runtime_symbol_target_or_layout_mismatch", ctx); }
        if std.str_eq(symbols[symbol_index].calling_convention_id, "gust_canonical_v1") == 0 { return mir_runtime_validation(0, "runtime_symbol_calling_convention_mismatch", ctx); }
        if symbols[symbol_index].required != 0 && symbols[symbol_index].required != 1 { return mir_runtime_validation(0, "runtime_symbol_required_policy_mismatch", ctx); }
        mut abi_found := 0; abi_index = 0; while abi_index < len(abis) { if std.str_eq(abis[abi_index].runtime_abi_id, symbols[symbol_index].runtime_abi_id) == 1 { abi_found = 1; } abi_index = abi_index + 1; } if abi_found == 0 { return mir_runtime_validation(0, "runtime_symbol_unknown_abi", ctx); }
        mut duplicate_symbol_index := symbol_index + 1; while duplicate_symbol_index < len(symbols) { if std.str_eq(symbols[symbol_index].symbol_id, symbols[duplicate_symbol_index].symbol_id) == 1 { return mir_runtime_validation(0, "runtime_symbol_duplicate_conflict", ctx); } if std.str_eq(symbols[symbol_index].external_spelling, symbols[duplicate_symbol_index].external_spelling) == 1 { if std.str_eq(symbols[symbol_index].runtime_abi_id, symbols[duplicate_symbol_index].runtime_abi_id) == 0 || std.str_eq(symbols[symbol_index].function_abi_id, symbols[duplicate_symbol_index].function_abi_id) == 0 { return mir_runtime_validation(0, "runtime_symbol_spelling_abi_conflict", ctx); } return mir_runtime_validation(0, "runtime_symbol_duplicate_conflict", ctx); } duplicate_symbol_index = duplicate_symbol_index + 1; }
        symbol_index = symbol_index + 1;
    }
    // Phase 17.4: freeze the package manifest before any requirement consults it.
    mut members: std.Vector[MirRuntimePackageMember[ctx], ctx] := ctx[table.package_members];
    mut provided: std.Vector[MirRuntimePackageProvidedSymbol[ctx], ctx] := ctx[table.package_provided_symbols];
    mut system_imports: std.Vector[MirRuntimePackageSystemImport[ctx], ctx] := ctx[table.package_system_imports];
    mut manifest_package_index := 0;
    while manifest_package_index < len(packages) {
        if mir_runtime_field_is_safe(packages[manifest_package_index].package_id) == 0 || mir_runtime_field_is_safe(packages[manifest_package_index].package_version) == 0 || mir_runtime_field_is_safe(packages[manifest_package_index].build_authority_id) == 0 { return mir_runtime_validation(0, "runtime_package_undeclared_member_or_system_import", ctx); }
        if std.str_eq(packages[manifest_package_index].manifest_format, "gust.runtime_package_manifest.v1") == 0 || mir_runtime_package_form_is_valid(packages[manifest_package_index].package_form) == 0 { return mir_runtime_validation(0, "runtime_package_undeclared_member_or_system_import", ctx); }

        // Package identity is target-exact: a package for another target is
        // never a fallback candidate.
        if std.str_eq(packages[manifest_package_index].target_id, table.target_id) == 0 || std.str_eq(packages[manifest_package_index].target_triple, table.target_triple) == 0 { return mir_runtime_validation(0, "runtime_package_target_mismatch", ctx); }
        mut package_abi := mir_runtime_abi_by_id(table, packages[manifest_package_index].runtime_abi_id, ctx);
        if package_abi.found == 0 { return mir_runtime_validation(0, "runtime_package_abi_version_incompatible", ctx); }
        if packages[manifest_package_index].compatible_version_min < package_abi.value.compatible_version_min ||
           packages[manifest_package_index].compatible_version_max > package_abi.value.compatible_version_max ||
           packages[manifest_package_index].compatible_version_max < packages[manifest_package_index].compatible_version_min
        {
            return mir_runtime_validation(0, "runtime_package_abi_version_incompatible", ctx);
        }
        mut duplicate_manifest_package_index := manifest_package_index + 1;
        while duplicate_manifest_package_index < len(packages) { if std.str_eq(packages[manifest_package_index].package_id, packages[duplicate_manifest_package_index].package_id) == 1 { return mir_runtime_validation(0, "runtime_package_duplicate_conflicting_component", ctx); } duplicate_manifest_package_index = duplicate_manifest_package_index + 1; }

        // Deterministic link order: the members of one package must occupy
        // exactly positions 0..n-1, declared in ascending order, with no
        // repeated component and no repeated position.
        mut expected_order := 0;
        mut member_index := 0;
        while member_index < len(members) {
            if std.str_eq(members[member_index].package_id, packages[manifest_package_index].package_id) == 1 {
                if members[member_index].link_order != expected_order { return mir_runtime_validation(0, "runtime_package_nondeterministic_component_order", ctx); }
                mut component_found := 0;
                mut component_index := 0;
                while component_index < len(components) { if std.str_eq(components[component_index].component_id, members[member_index].component_id) == 1 && std.str_eq(components[component_index].target_id, table.target_id) == 1 { component_found = 1; } component_index = component_index + 1; }
                if component_found == 0 { return mir_runtime_validation(0, "runtime_package_undeclared_member_or_system_import", ctx); }
                mut duplicate_member_index := member_index + 1;
                while duplicate_member_index < len(members) {
                    if std.str_eq(members[duplicate_member_index].package_id, packages[manifest_package_index].package_id) == 1 &&
                       (std.str_eq(members[member_index].component_id, members[duplicate_member_index].component_id) == 1 ||
                        members[member_index].link_order == members[duplicate_member_index].link_order)
                    {
                        return mir_runtime_validation(0, "runtime_package_duplicate_conflicting_component", ctx);
                    }
                    duplicate_member_index = duplicate_member_index + 1;
                }
                expected_order = expected_order + 1;
            }
            member_index = member_index + 1;
        }
        if expected_order == 0 { return mir_runtime_validation(0, "runtime_package_undeclared_member_or_system_import", ctx); }
        manifest_package_index = manifest_package_index + 1;
    }

    // Every provided symbol must be compiler-owned and come from a package
    // member; a package cannot provide a symbol from an unenumerated component.
    mut provided_index := 0;
    while provided_index < len(provided) {
        mut provided_package := mir_runtime_package_by_id(table, provided[provided_index].package_id, ctx);
        if provided_package.found == 0 { return mir_runtime_validation(0, "runtime_package_undeclared_member_or_system_import", ctx); }
        mut provided_symbol := mir_runtime_symbol_by_id(table, provided[provided_index].symbol_id, ctx);
        if provided_symbol.found == 0 { return mir_runtime_validation(0, "runtime_package_undeclared_member_or_system_import", ctx); }
        if std.str_eq(provided_symbol.value.external_spelling, provided[provided_index].external_spelling) == 0 ||
           std.str_eq(provided_symbol.value.symbol_version, provided[provided_index].symbol_version) == 0 ||
           std.str_eq(provided_symbol.value.component_id, provided[provided_index].component_id) == 0
        {
            return mir_runtime_validation(0, "runtime_package_missing_mandatory_symbol", ctx);
        }
        mut member_backed := 0;
        mut backing_index := 0;
        while backing_index < len(members) { if std.str_eq(members[backing_index].package_id, provided[provided_index].package_id) == 1 && std.str_eq(members[backing_index].component_id, provided[provided_index].component_id) == 1 { member_backed = 1; } backing_index = backing_index + 1; }
        if member_backed == 0 { return mir_runtime_validation(0, "runtime_package_undeclared_member_or_system_import", ctx); }
        mut duplicate_provided_index := provided_index + 1;
        while duplicate_provided_index < len(provided) {
            if std.str_eq(provided[provided_index].package_id, provided[duplicate_provided_index].package_id) == 1 &&
               (std.str_eq(provided[provided_index].symbol_id, provided[duplicate_provided_index].symbol_id) == 1 ||
                std.str_eq(provided[provided_index].external_spelling, provided[duplicate_provided_index].external_spelling) == 1)
            {
                return mir_runtime_validation(0, "runtime_package_duplicate_conflicting_component", ctx);
            }
            duplicate_provided_index = duplicate_provided_index + 1;
        }
        provided_index = provided_index + 1;
    }

    mut system_import_index := 0;
    while system_import_index < len(system_imports) {
        mut import_package := mir_runtime_package_by_id(table, system_imports[system_import_index].package_id, ctx);
        if import_package.found == 0 { return mir_runtime_validation(0, "runtime_package_undeclared_member_or_system_import", ctx); }
        if mir_runtime_field_is_safe(system_imports[system_import_index].external_spelling) == 0 || mir_runtime_field_is_safe(system_imports[system_import_index].origin) == 0 { return mir_runtime_validation(0, "runtime_package_undeclared_member_or_system_import", ctx); }
        mut duplicate_import_index := system_import_index + 1;
        while duplicate_import_index < len(system_imports) { if std.str_eq(system_imports[system_import_index].package_id, system_imports[duplicate_import_index].package_id) == 1 && std.str_eq(system_imports[system_import_index].external_spelling, system_imports[duplicate_import_index].external_spelling) == 1 { return mir_runtime_validation(0, "runtime_package_duplicate_conflicting_component", ctx); } duplicate_import_index = duplicate_import_index + 1; }
        system_import_index = system_import_index + 1;
    }

    mut requirement_index := 0;
    while requirement_index < len(requirements) {
        mut helper := mir_runtime_helper_by_id(table, requirements[requirement_index].helper_id, ctx);
        if helper.found == 0 { return mir_runtime_validation(0, "runtime_unknown_helper_id", ctx); }
        mut classification := mir_classify_runtime_helper(table, requirements[requirement_index].helper_id, ctx);
        if classification.found == 0 || std.str_eq(classification.value.component_id, requirements[requirement_index].component_id) == 0 { return mir_runtime_validation(0, "runtime_requirement_mismatch", ctx); }
        mut abi_found := 0;
        abi_index = 0;
        while abi_index < len(abis) { if std.str_eq(abis[abi_index].runtime_abi_id, requirements[requirement_index].runtime_abi_id) == 1 { abi_found = 1; } abi_index = abi_index + 1; }
        if abi_found == 0 { return mir_runtime_validation(0, "runtime_requirement_mismatch", ctx); }
        mut package_found := 0;
        mut package_index := 0;
        while package_index < len(packages) { if std.str_eq(packages[package_index].package_id, requirements[requirement_index].package_id) == 1 { package_found = 1; } package_index = package_index + 1; }
        if package_found == 0 { return mir_runtime_validation(0, "runtime_unknown_package_id", ctx); }

        // Phase 17.3: the requirement must name a compiler-owned symbol record.
        mut requirement_symbol := mir_runtime_symbol_by_id(table, requirements[requirement_index].symbol_id, ctx);
        if requirement_symbol.found == 0 { return mir_runtime_validation(0, "runtime_requirement_unknown_helper_or_symbol", ctx); }
        if std.str_eq(requirement_symbol.value.helper_id, requirements[requirement_index].helper_id) == 0 { return mir_runtime_validation(0, "runtime_requirement_unknown_helper_or_symbol", ctx); }

        // The selected symbol and the helper classification must agree on the
        // owning component, so a requirement cannot re-home a runtime operation.
        if std.str_eq(requirement_symbol.value.component_id, requirements[requirement_index].component_id) == 0 { return mir_runtime_validation(0, "runtime_requirement_classification_conflict", ctx); }
        if std.str_eq(classification.value.classification, "obsolete_helper") == 1 { return mir_runtime_validation(0, "runtime_requirement_classification_conflict", ctx); }

        // Requested version range must be non-empty and inside the ABI range.
        mut requirement_abi := mir_runtime_abi_by_id(table, requirements[requirement_index].runtime_abi_id, ctx);
        if requirement_abi.found == 0 { return mir_runtime_validation(0, "runtime_requirement_unknown_helper_or_symbol", ctx); }
        if std.str_eq(requirement_symbol.value.runtime_abi_id, requirements[requirement_index].runtime_abi_id) == 0 { return mir_runtime_validation(0, "runtime_requirement_symbol_version_incompatible", ctx); }
        if requirements[requirement_index].required_version_min < 1 ||
           requirements[requirement_index].required_version_max < requirements[requirement_index].required_version_min ||
           requirements[requirement_index].required_version_min < requirement_abi.value.compatible_version_min ||
           requirements[requirement_index].required_version_max > requirement_abi.value.compatible_version_max
        {
            return mir_runtime_validation(0, "runtime_requirement_symbol_version_incompatible", ctx);
        }

        // Target, layout, resource, and function ABI identities are carried, not
        // re-derived, so a mismatch is a compiler defect rather than a backend hint.
        if std.str_eq(requirements[requirement_index].target_id, table.target_id) == 0 ||
           std.str_eq(requirements[requirement_index].target_id, requirement_symbol.value.target_id) == 0 ||
           std.str_eq(requirements[requirement_index].layout_id, requirement_symbol.value.layout_id) == 0 ||
           std.str_eq(requirements[requirement_index].resource_operation_id, requirement_symbol.value.resource_operation_id) == 0 ||
           std.str_eq(requirements[requirement_index].function_abi_id, requirement_symbol.value.function_abi_id) == 0
        {
            return mir_runtime_validation(0, "runtime_requirement_target_or_layout_mismatch", ctx);
        }
        if mir_runtime_call_kind_is_valid(requirements[requirement_index].call_kind) == 0 { return mir_runtime_validation(0, "runtime_requirement_target_or_layout_mismatch", ctx); }
        if requirements[requirement_index].package_mandatory != 0 && requirements[requirement_index].package_mandatory != 1 { return mir_runtime_validation(0, "runtime_requirement_mismatch", ctx); }
        if requirements[requirement_index].required != 0 && requirements[requirement_index].required != 1 { return mir_runtime_validation(0, "runtime_requirement_mismatch", ctx); }
        if requirements[requirement_index].required == 1 && requirement_symbol.value.required == 0 { return mir_runtime_validation(0, "runtime_requirement_classification_conflict", ctx); }

        // Phase 17.4: once the requirement itself is well formed, the package it
        // names must actually provide the symbol, before Phase 9G executes any
        // link plan. This runs after symbol resolution so a malformed
        // requirement still reports its own defect rather than a package miss.
        if mir_runtime_package_provides_symbol(table, requirements[requirement_index].package_id, requirements[requirement_index].symbol_id, ctx) == 0 { return mir_runtime_validation(0, "runtime_package_missing_mandatory_symbol", ctx); }

        // Duplicate requirement identities, and two requirements claiming the
        // same symbol in one program, are conflicts rather than deduplication.
        mut duplicate_requirement_index := requirement_index + 1;
        while duplicate_requirement_index < len(requirements) {
            if std.str_eq(requirements[requirement_index].requirement_id, requirements[duplicate_requirement_index].requirement_id) == 1 { return mir_runtime_validation(0, "runtime_requirement_duplicate_conflict", ctx); }
            if std.str_eq(requirements[requirement_index].program_id, requirements[duplicate_requirement_index].program_id) == 1 &&
               std.str_eq(requirements[requirement_index].symbol_id, requirements[duplicate_requirement_index].symbol_id) == 1
            {
                return mir_runtime_validation(0, "runtime_requirement_duplicate_conflict", ctx);
            }
            duplicate_requirement_index = duplicate_requirement_index + 1;
        }

        // A requirement no canonical MIR operation reaches must be declared
        // package-mandatory; otherwise it is unexplained link-time surface.
        mut reference_count := 0;
        mut requirement_reference_index := 0;
        while requirement_reference_index < len(references) {
            if std.str_eq(references[requirement_reference_index].requirement_id, requirements[requirement_index].requirement_id) == 1 { reference_count = reference_count + 1; }
            requirement_reference_index = requirement_reference_index + 1;
        }
        if reference_count == 0 && requirements[requirement_index].package_mandatory == 0 { return mir_runtime_validation(0, "runtime_requirement_unused_without_package_mandate", ctx); }
        requirement_index = requirement_index + 1;
    }
    mut decision_index := 0; while decision_index < len(decisions) { mut requirement_found := 0; requirement_index = 0; while requirement_index < len(requirements) { if std.str_eq(requirements[requirement_index].requirement_id, decisions[decision_index].requirement_id) == 1 { requirement_found = 1; } requirement_index = requirement_index + 1; } if requirement_found == 0 { return mir_runtime_validation(0, "runtime_compatibility_mismatch", ctx); } decision_index = decision_index + 1; }
    mut plan_index := 0;
    while plan_index < len(plans) {
        if plans[plan_index].compatible == 0 { return mir_runtime_validation(0, "runtime_link_plan_unresolved", ctx); }
        if std.str_eq(plans[plan_index].target_id, table.target_id) == 0 { return mir_runtime_validation(0, "runtime_target_mismatch", ctx); }
        // Phase 17.4: Phase 9G executes the plan, but the component order in it
        // is the package's declared link order, not a linker-chosen sequence.
        mut plan_package := mir_runtime_package_by_id(table, plans[plan_index].package_id, ctx);
        if plan_package.found == 0 { return mir_runtime_validation(0, "runtime_unknown_package_id", ctx); }
        mut plan_components: std.Vector[str, ctx] := ctx[plans[plan_index].component_ids];
        mut ordered_index := 0;
        mut plan_member_index := 0;
        while plan_member_index < len(members) {
            if std.str_eq(members[plan_member_index].package_id, plans[plan_index].package_id) == 1 {
                if ordered_index >= len(plan_components) { return mir_runtime_validation(0, "runtime_package_nondeterministic_component_order", ctx); }
                if std.str_eq(plan_components[ordered_index], members[plan_member_index].component_id) == 0 { return mir_runtime_validation(0, "runtime_package_nondeterministic_component_order", ctx); }
                ordered_index = ordered_index + 1;
            }
            plan_member_index = plan_member_index + 1;
        }
        if ordered_index != len(plan_components) { return mir_runtime_validation(0, "runtime_package_nondeterministic_component_order", ctx); }
        plan_index = plan_index + 1;
    }
    // Phase 17.8: pure Gust runtime modules compile through the generic route.
    mut gust_modules: std.Vector[MirRuntimeGustModule[ctx], ctx] := ctx[table.gust_modules];
    mut gust_index := 0;
    while gust_index < len(gust_modules) {
        if mir_runtime_field_is_safe(gust_modules[gust_index].gust_module_id) == 0 || mir_runtime_field_is_safe(gust_modules[gust_index].module_source_path) == 0 { return mir_runtime_validation(0, "runtime_gust_missing_requirement", ctx); }

        // A bespoke lowering path means the compiler recognised this module.
        if mir_runtime_lowering_route_is_valid(gust_modules[gust_index].lowering_route) == 0 { return mir_runtime_validation(0, "runtime_gust_non_generic_lowering", ctx); }
        if mir_runtime_initialization_policy_is_valid(gust_modules[gust_index].initialization_policy) == 0 { return mir_runtime_validation(0, "runtime_gust_missing_requirement", ctx); }
        if mir_runtime_failure_policy_is_valid(gust_modules[gust_index].failure_policy) == 0 { return mir_runtime_validation(0, "runtime_gust_missing_requirement", ctx); }

        // Runtime Gust source is ordinary repository source, never generated C.
        if std.str_find(gust_modules[gust_index].module_source_path, "src/runtime/gust/") != 0 { return mir_runtime_validation(0, "runtime_gust_hidden_generated_c", ctx); }
        if std.str_find(gust_modules[gust_index].module_source_path, ".gst") == 0 - 1 { return mir_runtime_validation(0, "runtime_gust_hidden_generated_c", ctx); }

        mut gust_component_found := 0;
        mut gust_component_index := 0;
        while gust_component_index < len(components) { if std.str_eq(components[gust_component_index].component_id, gust_modules[gust_index].component_id) == 1 && std.str_eq(components[gust_component_index].target_id, table.target_id) == 1 { gust_component_found = 1; } gust_component_index = gust_component_index + 1; }
        if gust_component_found == 0 { return mir_runtime_validation(0, "runtime_gust_abi_or_target_mismatch", ctx); }
        if std.str_eq(gust_modules[gust_index].target_id, table.target_id) == 0 { return mir_runtime_validation(0, "runtime_gust_abi_or_target_mismatch", ctx); }
        mut gust_abi := mir_runtime_abi_by_id(table, gust_modules[gust_index].runtime_abi_id, ctx);
        if gust_abi.found == 0 { return mir_runtime_validation(0, "runtime_gust_abi_or_target_mismatch", ctx); }

        mut gust_exports: std.Vector[str, ctx] := ctx[gust_modules[gust_index].exported_symbol_ids];
        if len(gust_exports) == 0 { return mir_runtime_validation(0, "runtime_gust_missing_requirement", ctx); }
        mut gust_export_index := 0;
        while gust_export_index < len(gust_exports) {
            mut gust_symbol := mir_runtime_symbol_by_id(table, gust_exports[gust_export_index], ctx);
            if gust_symbol.found == 0 { return mir_runtime_validation(0, "runtime_gust_missing_requirement", ctx); }
            if std.str_eq(gust_symbol.value.component_id, gust_modules[gust_index].component_id) == 0 { return mir_runtime_validation(0, "runtime_gust_missing_requirement", ctx); }
            gust_export_index = gust_export_index + 1;
        }

        // A module may not depend on itself, directly or through its allowed
        // dependency list, without an explicit selected policy. Recursive
        // dependence on an unavailable version of the same component is the
        // failure this prevents.
        mut gust_dependencies: std.Vector[str, ctx] := ctx[gust_modules[gust_index].allowed_dependency_ids];
        mut gust_dependency_index := 0;
        while gust_dependency_index < len(gust_dependencies) {
            if std.str_eq(gust_dependencies[gust_dependency_index], gust_modules[gust_index].component_id) == 1 { return mir_runtime_validation(0, "runtime_gust_circular_dependency", ctx); }
            mut gust_imports: std.Vector[str, ctx] := ctx[gust_modules[gust_index].imported_symbol_ids];
            mut gust_import_index := 0;
            while gust_import_index < len(gust_imports) {
                mut imported_gust := mir_runtime_symbol_by_id(table, gust_imports[gust_import_index], ctx);
                if imported_gust.found == 1 && std.str_eq(imported_gust.value.component_id, gust_modules[gust_index].component_id) == 1 { return mir_runtime_validation(0, "runtime_gust_circular_dependency", ctx); }
                gust_import_index = gust_import_index + 1;
            }
            gust_dependency_index = gust_dependency_index + 1;
        }

        mut duplicate_gust_index := gust_index + 1;
        while duplicate_gust_index < len(gust_modules) {
            if std.str_eq(gust_modules[gust_index].gust_module_id, gust_modules[duplicate_gust_index].gust_module_id) == 1 ||
               std.str_eq(gust_modules[gust_index].component_id, gust_modules[duplicate_gust_index].component_id) == 1
            {
                return mir_runtime_validation(0, "runtime_gust_missing_requirement", ctx);
            }
            duplicate_gust_index = duplicate_gust_index + 1;
        }
        gust_index = gust_index + 1;
    }

    // Phase 17.7: retained C is a separately compiled, versioned, target-scoped
    // component with a justified retention reason and a stated exit criterion.
    mut retained_c: std.Vector[MirRuntimeRetainedCComponent[ctx], ctx] := ctx[table.retained_c_components];
    mut retained_index := 0;
    while retained_index < len(retained_c) {
        // An anonymous or unclassified C object is exactly what this patch bans.
        if mir_runtime_field_is_safe(retained_c[retained_index].retained_component_id) == 0 || mir_runtime_field_is_safe(retained_c[retained_index].component_id) == 0 || mir_runtime_field_is_safe(retained_c[retained_index].build_inputs) == 0 { return mir_runtime_validation(0, "runtime_retained_c_anonymous_object", ctx); }
        mut retained_declared := 0;
        mut retained_component_index := 0;
        while retained_component_index < len(components) { if std.str_eq(components[retained_component_index].component_id, retained_c[retained_index].component_id) == 1 && std.str_eq(components[retained_component_index].target_id, table.target_id) == 1 { retained_declared = 1; } retained_component_index = retained_component_index + 1; }
        if retained_declared == 0 { return mir_runtime_validation(0, "runtime_retained_c_anonymous_object", ctx); }

        // Retention is temporary by contract: both a reason and an exit.
        if mir_runtime_retention_reason_is_valid(retained_c[retained_index].retention_reason) == 0 { return mir_runtime_validation(0, "runtime_retained_c_anonymous_object", ctx); }
        if mir_runtime_field_is_safe(retained_c[retained_index].removal_criterion) == 0 || mir_runtime_field_is_safe(retained_c[retained_index].destination_phase) == 0 { return mir_runtime_validation(0, "runtime_retained_c_anonymous_object", ctx); }

        // Target assumptions are declared, never hidden in the source.
        if std.str_eq(retained_c[retained_index].target_id, table.target_id) == 0 { return mir_runtime_validation(0, "runtime_retained_c_hidden_target_assumption", ctx); }
        if std.str_eq(retained_c[retained_index].target_applicability, "all_declared_host_targets_from_phase14_target_authority") == 0 { return mir_runtime_validation(0, "runtime_retained_c_hidden_target_assumption", ctx); }
        mut retained_abi := mir_runtime_abi_by_id(table, retained_c[retained_index].runtime_abi_id, ctx);
        if retained_abi.found == 0 { return mir_runtime_validation(0, "runtime_retained_c_hidden_target_assumption", ctx); }

        // Owned sources are repository files, never fragments generated from a
        // program's canonical MIR.
        mut retained_sources: std.Vector[str, ctx] := ctx[retained_c[retained_index].owned_source_paths];
        if len(retained_sources) == 0 { return mir_runtime_validation(0, "runtime_retained_c_anonymous_object", ctx); }
        mut source_index := 0;
        while source_index < len(retained_sources) {
            if std.str_find(retained_sources[source_index], "src/runtime/") != 0 { return mir_runtime_validation(0, "runtime_retained_c_program_specific_generation", ctx); }
            if std.str_find(retained_sources[source_index], "generated") != 0 - 1 || std.str_find(retained_sources[source_index], "build/") != 0 - 1 { return mir_runtime_validation(0, "runtime_retained_c_program_specific_generation", ctx); }
            source_index = source_index + 1;
        }

        // Every export is a compiler-owned versioned symbol of this component.
        mut retained_exports: std.Vector[str, ctx] := ctx[retained_c[retained_index].exported_symbol_ids];
        if len(retained_exports) == 0 { return mir_runtime_validation(0, "runtime_retained_c_unversioned_export", ctx); }
        mut retained_export_index := 0;
        while retained_export_index < len(retained_exports) {
            mut retained_symbol := mir_runtime_symbol_by_id(table, retained_exports[retained_export_index], ctx);
            if retained_symbol.found == 0 { return mir_runtime_validation(0, "runtime_retained_c_unversioned_export", ctx); }
            if mir_runtime_field_is_safe(retained_symbol.value.symbol_version) == 0 { return mir_runtime_validation(0, "runtime_retained_c_unversioned_export", ctx); }
            if std.str_eq(retained_symbol.value.component_id, retained_c[retained_index].component_id) == 0 { return mir_runtime_validation(0, "runtime_retained_c_duplicate_provider", ctx); }

            // The component must reach the program through the selected package
            // manifest, never by direct linker inclusion.
            mut packaged := 0;
            mut retained_package_index := 0;
            while retained_package_index < len(packages) { if mir_runtime_package_provides_symbol(table, packages[retained_package_index].package_id, retained_exports[retained_export_index], ctx) == 1 { packaged = 1; } retained_package_index = retained_package_index + 1; }
            if packaged == 0 { return mir_runtime_validation(0, "runtime_retained_c_direct_linker_inclusion", ctx); }

            mut other_retained_index := 0;
            while other_retained_index < len(retained_c) {
                if other_retained_index != retained_index {
                    mut other_retained_exports: std.Vector[str, ctx] := ctx[retained_c[other_retained_index].exported_symbol_ids];
                    mut other_retained_export_index := 0;
                    while other_retained_export_index < len(other_retained_exports) {
                        if std.str_eq(other_retained_exports[other_retained_export_index], retained_exports[retained_export_index]) == 1 { return mir_runtime_validation(0, "runtime_retained_c_duplicate_provider", ctx); }
                        other_retained_export_index = other_retained_export_index + 1;
                    }
                }
                other_retained_index = other_retained_index + 1;
            }
            retained_export_index = retained_export_index + 1;
        }

        mut duplicate_retained_index := retained_index + 1;
        while duplicate_retained_index < len(retained_c) {
            if std.str_eq(retained_c[retained_index].retained_component_id, retained_c[duplicate_retained_index].retained_component_id) == 1 ||
               std.str_eq(retained_c[retained_index].component_id, retained_c[duplicate_retained_index].component_id) == 1
            {
                return mir_runtime_validation(0, "runtime_retained_c_duplicate_provider", ctx);
            }
            duplicate_retained_index = duplicate_retained_index + 1;
        }
        retained_index = retained_index + 1;
    }

    // Phase 17.6: Rust components are explicit, versioned package members whose
    // exports are compiler-owned symbols and whose boundaries are declared.
    mut rust_components: std.Vector[MirRuntimeRustComponent[ctx], ctx] := ctx[table.rust_components];
    mut rust_index := 0;
    while rust_index < len(rust_components) {
        if mir_runtime_field_is_safe(rust_components[rust_index].rust_component_id) == 0 || mir_runtime_field_is_safe(rust_components[rust_index].source_ownership) == 0 { return mir_runtime_validation(0, "runtime_rust_undeclared_export", ctx); }

        // The Rust component must be a declared component for this target.
        mut rust_component_found := 0;
        mut rust_component_index := 0;
        while rust_component_index < len(components) { if std.str_eq(components[rust_component_index].component_id, rust_components[rust_index].component_id) == 1 && std.str_eq(components[rust_component_index].target_id, table.target_id) == 1 { rust_component_found = 1; } rust_component_index = rust_component_index + 1; }
        if rust_component_found == 0 { return mir_runtime_validation(0, "runtime_rust_abi_or_target_mismatch", ctx); }
        if std.str_eq(rust_components[rust_index].target_id, table.target_id) == 0 { return mir_runtime_validation(0, "runtime_rust_abi_or_target_mismatch", ctx); }
        mut rust_abi := mir_runtime_abi_by_id(table, rust_components[rust_index].runtime_abi_id, ctx);
        if rust_abi.found == 0 { return mir_runtime_validation(0, "runtime_rust_abi_or_target_mismatch", ctx); }
        if mir_runtime_rust_object_form_is_valid(rust_components[rust_index].object_form) == 0 { return mir_runtime_validation(0, "runtime_rust_abi_or_target_mismatch", ctx); }

        // Unwinding across the FFI boundary is not a supported runtime contract.
        if mir_runtime_panic_boundary_is_valid(rust_components[rust_index].panic_boundary) == 0 { return mir_runtime_validation(0, "runtime_rust_unwind_boundary_violation", ctx); }
        if mir_runtime_allocation_boundary_is_valid(rust_components[rust_index].allocation_boundary) == 0 { return mir_runtime_validation(0, "runtime_rust_unwind_boundary_violation", ctx); }

        // Every export must be a compiler-owned symbol belonging to this
        // component. Rust-internal mangling is never the runtime contract.
        mut rust_exports: std.Vector[str, ctx] := ctx[rust_components[rust_index].exported_symbol_ids];
        if len(rust_exports) == 0 { return mir_runtime_validation(0, "runtime_rust_undeclared_export", ctx); }
        mut export_index := 0;
        while export_index < len(rust_exports) {
            mut exported := mir_runtime_symbol_by_id(table, rust_exports[export_index], ctx);
            if exported.found == 0 { return mir_runtime_validation(0, "runtime_rust_undeclared_export", ctx); }
            if std.str_eq(exported.value.component_id, rust_components[rust_index].component_id) == 0 { return mir_runtime_validation(0, "runtime_rust_undeclared_export", ctx); }

            // Two components claiming the same symbol is a link-time ambiguity
            // the compiler resolves here, not something the linker discovers.
            mut other_index := 0;
            while other_index < len(rust_components) {
                if other_index != rust_index {
                    mut other_exports: std.Vector[str, ctx] := ctx[rust_components[other_index].exported_symbol_ids];
                    mut other_export_index := 0;
                    while other_export_index < len(other_exports) {
                        if std.str_eq(other_exports[other_export_index], rust_exports[export_index]) == 1 { return mir_runtime_validation(0, "runtime_rust_duplicate_symbol_provider", ctx); }
                        other_export_index = other_export_index + 1;
                    }
                }
                other_index = other_index + 1;
            }
            export_index = export_index + 1;
        }

        // Imports must also be compiler-owned; a hidden dependency on generated
        // C glue is exactly what this phase exists to remove.
        mut rust_imports: std.Vector[str, ctx] := ctx[rust_components[rust_index].imported_symbol_ids];
        mut import_symbol_index := 0;
        while import_symbol_index < len(rust_imports) {
            if std.str_find(rust_imports[import_symbol_index], "generated_c_shim") != 0 - 1 { return mir_runtime_validation(0, "runtime_rust_generated_c_glue_dependency", ctx); }
            mut imported_symbol := mir_runtime_symbol_by_id(table, rust_imports[import_symbol_index], ctx);
            if imported_symbol.found == 0 { return mir_runtime_validation(0, "runtime_rust_generated_c_glue_dependency", ctx); }
            import_symbol_index = import_symbol_index + 1;
        }

        mut duplicate_rust_index := rust_index + 1;
        while duplicate_rust_index < len(rust_components) {
            if std.str_eq(rust_components[rust_index].rust_component_id, rust_components[duplicate_rust_index].rust_component_id) == 1 ||
               std.str_eq(rust_components[rust_index].component_id, rust_components[duplicate_rust_index].component_id) == 1
            {
                return mir_runtime_validation(0, "runtime_rust_duplicate_symbol_provider", ctx);
            }
            duplicate_rust_index = duplicate_rust_index + 1;
        }
        rust_index = rust_index + 1;
    }

    // Phase 17.5: every declared import must resolve to a compiler-owned symbol,
    // a stable-library classification, and a package that actually exports it.
    mut imports: std.Vector[MirRuntimeImportDeclaration[ctx], ctx] := ctx[table.import_declarations];
    mut import_index := 0;
    while import_index < len(imports) {
        mut import_helper := mir_runtime_helper_by_id(table, imports[import_index].helper_id, ctx);
        if import_helper.found == 0 { return mir_runtime_validation(0, "runtime_import_undeclared", ctx); }
        mut import_symbol := mir_runtime_symbol_by_id(table, imports[import_index].symbol_id, ctx);
        if import_symbol.found == 0 { return mir_runtime_validation(0, "runtime_import_missing_symbol", ctx); }
        if std.str_eq(import_symbol.value.helper_id, imports[import_index].helper_id) == 0 { return mir_runtime_validation(0, "runtime_import_missing_symbol", ctx); }

        // Only stable runtime-library functions are migrated by this patch.
        mut import_classification := mir_classify_runtime_helper(table, imports[import_index].helper_id, ctx);
        if import_classification.found == 0 || std.str_eq(import_classification.value.classification, "stable_runtime_library_function") == 0 { return mir_runtime_validation(0, "runtime_import_wrong_target_component", ctx); }
        if std.str_eq(import_classification.value.component_id, imports[import_index].component_id) == 0 || std.str_eq(import_symbol.value.component_id, imports[import_index].component_id) == 0 { return mir_runtime_validation(0, "runtime_import_wrong_target_component", ctx); }

        // The external spelling and version are the compiler's, not the backend's.
        if std.str_eq(import_symbol.value.external_spelling, imports[import_index].external_spelling) == 0 { return mir_runtime_validation(0, "runtime_import_undeclared", ctx); }
        if std.str_eq(import_symbol.value.symbol_version, imports[import_index].symbol_version) == 0 { return mir_runtime_validation(0, "runtime_import_incompatible_version", ctx); }
        if std.str_eq(import_symbol.value.function_abi_id, imports[import_index].function_abi_id) == 0 { return mir_runtime_validation(0, "runtime_import_abi_mismatch", ctx); }
        if std.str_eq(imports[import_index].target_id, table.target_id) == 0 || std.str_eq(import_symbol.value.target_id, imports[import_index].target_id) == 0 { return mir_runtime_validation(0, "runtime_import_wrong_target_component", ctx); }
        if std.str_eq(imports[import_index].target_applicability, import_helper.value.target_applicability) == 0 { return mir_runtime_validation(0, "runtime_import_wrong_target_component", ctx); }
        if mir_runtime_side_effect_policy_is_valid(imports[import_index].side_effect_policy) == 0 || mir_runtime_failure_policy_is_valid(imports[import_index].failure_policy) == 0 { return mir_runtime_validation(0, "runtime_import_undeclared", ctx); }

        // The runtime package must export the required symbol and version.
        mut import_package := mir_runtime_package_by_id(table, imports[import_index].package_id, ctx);
        if import_package.found == 0 { return mir_runtime_validation(0, "runtime_import_missing_symbol", ctx); }
        if mir_runtime_package_provides_symbol(table, imports[import_index].package_id, imports[import_index].symbol_id, ctx) == 0 { return mir_runtime_validation(0, "runtime_import_missing_symbol", ctx); }
        mut import_duplicate_index := import_index + 1;
        while import_duplicate_index < len(imports) {
            if std.str_eq(imports[import_index].import_id, imports[import_duplicate_index].import_id) == 1 ||
               (std.str_eq(imports[import_index].helper_id, imports[import_duplicate_index].helper_id) == 1 &&
                std.str_eq(imports[import_index].target_id, imports[import_duplicate_index].target_id) == 1) ||
               std.str_eq(imports[import_index].external_spelling, imports[import_duplicate_index].external_spelling) == 1
            {
                return mir_runtime_validation(0, "runtime_import_undeclared", ctx);
            }
            import_duplicate_index = import_duplicate_index + 1;
        }
        import_index = import_index + 1;
    }

    mut reference_index := 0;
    while reference_index < len(references) {
        mut helper := mir_runtime_helper_by_id(table, references[reference_index].helper_id, ctx);
        if helper.found == 0 { return mir_runtime_validation(0, "runtime_metadata_inconsistent_with_canonical_mir", ctx); }
        if mir_runtime_field_is_safe(references[reference_index].reference_id) == 0 || mir_runtime_field_is_safe(references[reference_index].mir_operation_id) == 0 { return mir_runtime_validation(0, "runtime_metadata_inconsistent_with_canonical_mir", ctx); }

        // Phase 17.3: a runtime-facing canonical MIR operation without exactly
        // one owning requirement never reaches the worker, driver, or linker.
        mut owning := mir_runtime_requirement_by_id(table, references[reference_index].requirement_id, ctx);
        if owning.found == 0 { return mir_runtime_validation(0, "runtime_requirement_missing_for_mir_operation", ctx); }
        if std.str_eq(owning.value.helper_id, references[reference_index].helper_id) == 0 { return mir_runtime_validation(0, "runtime_requirement_missing_for_mir_operation", ctx); }
        mut duplicate_reference_index := reference_index + 1;
        while duplicate_reference_index < len(references) {
            if std.str_eq(references[reference_index].reference_id, references[duplicate_reference_index].reference_id) == 1 ||
               std.str_eq(references[reference_index].mir_operation_id, references[duplicate_reference_index].mir_operation_id) == 1
            {
                return mir_runtime_validation(0, "runtime_requirement_duplicate_conflict", ctx);
            }
            duplicate_reference_index = duplicate_reference_index + 1;
        }

        // Reference metadata mirrors its requirement exactly. Divergence would
        // let a backend pick whichever copy suits the symbol it already resolved.
        mut reference_symbol := mir_runtime_symbol_by_id(table, references[reference_index].symbol_id, ctx);
        if reference_symbol.found == 0 || std.str_eq(references[reference_index].symbol_id, owning.value.symbol_id) == 0 { return mir_runtime_validation(0, "runtime_requirement_unknown_helper_or_symbol", ctx); }
        if std.str_eq(references[reference_index].runtime_abi_id, owning.value.runtime_abi_id) == 0 ||
           references[reference_index].required_version_min != owning.value.required_version_min ||
           references[reference_index].required_version_max != owning.value.required_version_max
        {
            return mir_runtime_validation(0, "runtime_requirement_symbol_version_incompatible", ctx);
        }
        if std.str_eq(references[reference_index].layout_id, owning.value.layout_id) == 0 ||
           std.str_eq(references[reference_index].resource_operation_id, owning.value.resource_operation_id) == 0 ||
           std.str_eq(references[reference_index].function_abi_id, owning.value.function_abi_id) == 0 ||
           std.str_eq(references[reference_index].target_applicability, helper.value.target_applicability) == 0
        {
            return mir_runtime_validation(0, "runtime_requirement_target_or_layout_mismatch", ctx);
        }
        if mir_runtime_call_kind_is_valid(references[reference_index].call_kind) == 0 ||
           std.str_eq(references[reference_index].call_kind, owning.value.call_kind) == 0
        {
            return mir_runtime_validation(0, "runtime_requirement_target_or_layout_mismatch", ctx);
        }
        reference_index = reference_index + 1;
    }
    return mir_runtime_validation(1, "runtime_authority_valid", ctx);
}

func mir_runtime_append_field(output: str, name: str, value: str, ctx: &Arena) str { mut result := std.Concat(output, name); result = std.Concat(result, ": "); result = std.Concat(result, value); result = std.Concat(result, "\n"); return std.Clone(ctx, result); }

func mir_serialize_runtime_boundary_authority_table_for_request(table: MirRuntimeBoundaryAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := mir_runtime_boundary_authority_table_validate(table, ctx);
    if validation.valid == 0 { mut invalid := "runtime_authority_format: invalid\nruntime_authority_reason: "; invalid = std.Concat(invalid, validation.reason_code); invalid = std.Concat(invalid, "\n"); return std.Clone(ctx, invalid); }
    mut output := "runtime_authority_format: gust.compiler_runtime_boundary_authority_table.v1\n";
    output = mir_runtime_append_field(output, "runtime_authority_target_id", table.target_id, ctx);
    output = mir_runtime_append_field(output, "runtime_authority_target_triple", table.target_triple, ctx);
    output = mir_runtime_append_field(output, "runtime_authority_semantic_owner", table.semantic_authority, ctx);
    mut helpers: std.Vector[MirRuntimeHelperIdentity[ctx], ctx] := ctx[table.helpers];
    mut classifications: std.Vector[MirRuntimeHelperClassification[ctx], ctx] := ctx[table.classifications];
    mut abis: std.Vector[MirRuntimeAbiIdentity[ctx], ctx] := ctx[table.runtime_abis];
    mut symbols: std.Vector[MirRuntimeSymbolIdentity[ctx], ctx] := ctx[table.symbols];
    mut abi_index := 0; while abi_index < len(abis) { output = mir_runtime_append_field(output, "runtime_abi_id", abis[abi_index].runtime_abi_id, ctx); output = mir_runtime_append_field(output, "runtime_abi_version", abis[abi_index].abi_version, ctx); abi_index = abi_index + 1; }
    mut index := 0; while index < len(helpers) { output = mir_runtime_append_field(output, "runtime_helper_id", helpers[index].helper_id, ctx); output = mir_runtime_append_field(output, "runtime_helper_operation", helpers[index].operation_id, ctx); index = index + 1; }
    index = 0; while index < len(classifications) { output = mir_runtime_append_field(output, "runtime_helper_classification", classifications[index].classification, ctx); index = index + 1; }
    index = 0; while index < len(symbols) { output = mir_runtime_append_field(output, "runtime_symbol_id", symbols[index].symbol_id, ctx); output = mir_runtime_append_field(output, "runtime_symbol_external_spelling", symbols[index].external_spelling, ctx); output = mir_runtime_append_field(output, "runtime_symbol_version", symbols[index].symbol_version, ctx); index = index + 1; }
    mut requirements: std.Vector[MirRuntimeRequirement[ctx], ctx] := ctx[table.requirements];
    mut references: std.Vector[MirRuntimeMirReference[ctx], ctx] := ctx[table.mir_references];
    index = 0;
    while index < len(requirements) {
        output = mir_runtime_append_field(output, "runtime_requirement_id", requirements[index].requirement_id, ctx);
        output = mir_runtime_append_field(output, "runtime_requirement_symbol_id", requirements[index].symbol_id, ctx);
        output = mir_runtime_append_field(output, "runtime_requirement_abi_id", requirements[index].runtime_abi_id, ctx);
        output = mir_runtime_append_field(output, "runtime_requirement_version_min", std.FormatInt(requirements[index].required_version_min), ctx);
        output = mir_runtime_append_field(output, "runtime_requirement_version_max", std.FormatInt(requirements[index].required_version_max), ctx);
        output = mir_runtime_append_field(output, "runtime_requirement_call_kind", requirements[index].call_kind, ctx);
        output = mir_runtime_append_field(output, "runtime_requirement_package_mandatory", std.FormatInt(requirements[index].package_mandatory), ctx);
        index = index + 1;
    }
    mut packages: std.Vector[MirRuntimePackageIdentity[ctx], ctx] := ctx[table.packages];
    mut members: std.Vector[MirRuntimePackageMember[ctx], ctx] := ctx[table.package_members];
    mut provided: std.Vector[MirRuntimePackageProvidedSymbol[ctx], ctx] := ctx[table.package_provided_symbols];
    mut system_imports: std.Vector[MirRuntimePackageSystemImport[ctx], ctx] := ctx[table.package_system_imports];
    index = 0;
    while index < len(packages) {
        output = mir_runtime_append_field(output, "runtime_package_id", packages[index].package_id, ctx);
        output = mir_runtime_append_field(output, "runtime_package_manifest_format", packages[index].manifest_format, ctx);
        output = mir_runtime_append_field(output, "runtime_package_form", packages[index].package_form, ctx);
        output = mir_runtime_append_field(output, "runtime_package_build_authority", packages[index].build_authority_id, ctx);
        output = mir_runtime_append_field(output, "runtime_package_target_triple", packages[index].target_triple, ctx);
        index = index + 1;
    }
    index = 0;
    while index < len(members) {
        output = mir_runtime_append_field(output, "runtime_package_member_id", members[index].member_id, ctx);
        output = mir_runtime_append_field(output, "runtime_package_member_link_order", std.FormatInt(members[index].link_order), ctx);
        index = index + 1;
    }
    index = 0;
    while index < len(provided) {
        output = mir_runtime_append_field(output, "runtime_package_provided_id", provided[index].provided_id, ctx);
        output = mir_runtime_append_field(output, "runtime_package_provided_spelling", provided[index].external_spelling, ctx);
        output = mir_runtime_append_field(output, "runtime_package_provided_version", provided[index].symbol_version, ctx);
        index = index + 1;
    }
    index = 0;
    while index < len(system_imports) {
        output = mir_runtime_append_field(output, "runtime_package_system_import_id", system_imports[index].import_id, ctx);
        output = mir_runtime_append_field(output, "runtime_package_system_import_spelling", system_imports[index].external_spelling, ctx);
        index = index + 1;
    }
    mut gust_modules: std.Vector[MirRuntimeGustModule[ctx], ctx] := ctx[table.gust_modules];
    index = 0;
    while index < len(gust_modules) {
        output = mir_runtime_append_field(output, "runtime_gust_module_id", gust_modules[index].gust_module_id, ctx);
        output = mir_runtime_append_field(output, "runtime_gust_source_path", gust_modules[index].module_source_path, ctx);
        output = mir_runtime_append_field(output, "runtime_gust_lowering_route", gust_modules[index].lowering_route, ctx);
        output = mir_runtime_append_field(output, "runtime_gust_initialization", gust_modules[index].initialization_policy, ctx);
        index = index + 1;
    }
    mut retained_c: std.Vector[MirRuntimeRetainedCComponent[ctx], ctx] := ctx[table.retained_c_components];
    index = 0;
    while index < len(retained_c) {
        output = mir_runtime_append_field(output, "runtime_retained_c_id", retained_c[index].retained_component_id, ctx);
        output = mir_runtime_append_field(output, "runtime_retained_c_retention_reason", retained_c[index].retention_reason, ctx);
        output = mir_runtime_append_field(output, "runtime_retained_c_removal_criterion", retained_c[index].removal_criterion, ctx);
        output = mir_runtime_append_field(output, "runtime_retained_c_destination_phase", retained_c[index].destination_phase, ctx);
        output = mir_runtime_append_field(output, "runtime_retained_c_build_inputs", retained_c[index].build_inputs, ctx);
        index = index + 1;
    }
    mut rust_components: std.Vector[MirRuntimeRustComponent[ctx], ctx] := ctx[table.rust_components];
    index = 0;
    while index < len(rust_components) {
        output = mir_runtime_append_field(output, "runtime_rust_component_id", rust_components[index].rust_component_id, ctx);
        output = mir_runtime_append_field(output, "runtime_rust_object_form", rust_components[index].object_form, ctx);
        output = mir_runtime_append_field(output, "runtime_rust_panic_boundary", rust_components[index].panic_boundary, ctx);
        output = mir_runtime_append_field(output, "runtime_rust_allocation_boundary", rust_components[index].allocation_boundary, ctx);
        output = mir_runtime_append_field(output, "runtime_rust_source_ownership", rust_components[index].source_ownership, ctx);
        index = index + 1;
    }
    mut imports: std.Vector[MirRuntimeImportDeclaration[ctx], ctx] := ctx[table.import_declarations];
    index = 0;
    while index < len(imports) {
        output = mir_runtime_append_field(output, "runtime_import_id", imports[index].import_id, ctx);
        output = mir_runtime_append_field(output, "runtime_import_spelling", imports[index].external_spelling, ctx);
        output = mir_runtime_append_field(output, "runtime_import_version", imports[index].symbol_version, ctx);
        output = mir_runtime_append_field(output, "runtime_import_function_abi", imports[index].function_abi_id, ctx);
        output = mir_runtime_append_field(output, "runtime_import_side_effects", imports[index].side_effect_policy, ctx);
        output = mir_runtime_append_field(output, "runtime_import_failure", imports[index].failure_policy, ctx);
        index = index + 1;
    }
    index = 0;
    while index < len(references) {
        output = mir_runtime_append_field(output, "runtime_mir_reference_id", references[index].reference_id, ctx);
        output = mir_runtime_append_field(output, "runtime_mir_reference_operation", references[index].mir_operation_id, ctx);
        output = mir_runtime_append_field(output, "runtime_mir_reference_requirement_id", references[index].requirement_id, ctx);
        output = mir_runtime_append_field(output, "runtime_mir_reference_call_kind", references[index].call_kind, ctx);
        index = index + 1;
    }
    return std.Clone(ctx, output);
}
