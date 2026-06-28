CC = cc
CFLAGS = -O2 -Wall -pthread
INCLUDES = -Isrc
PREFIX = /usr/local

# Force make to use bash with pipefail to prevent silent pipeline errors
SHELL = bash
.SHELLFLAGS = -o pipefail -c

.PHONY: all clean test bootstrap install test_tree_sitter report_step44_accessor_contract report_step45_accessor_contract report_step45_final_validation report_compiler_get_opt_migration report_high_level_raw_collection_casts report_step45_subscript_lvalue_writes report_step45_test_subscript_lvalue_writes guard_step44_low_risk_entry_raw_casts guard_step44_typechecker_aux_raw_casts guard_step44_typechecker_types_raw_casts guard_step44_codegen_initializer_raw_casts guard_step44_typechecker_early_raw_casts guard_step44_typechecker_methods_raw_casts guard_step44_typechecker_pool_graph_raw_casts guard_step44_typechecker_call_validation_raw_casts guard_step44_typechecker_generic_helpers_raw_casts guard_step44_typechecker_template_registration_raw_casts guard_step44_typechecker_env_registration_raw_casts guard_step44_typechecker_brand_helpers_raw_casts guard_step44_typechecker_function_checks_raw_casts guard_step44_typechecker_statement_traversal_raw_casts guard_step44_codegen_early_helpers_raw_casts guard_step44_codegen_dispatch_methods_raw_casts guard_step44_codegen_pool_graph_std_raw_casts guard_step44_codegen_std_alloc_helpers_raw_casts guard_step44_codegen_runtime_tail_raw_casts guard_step44_codegen_statement_emit_raw_casts guard_step44_codegen_program_passes_raw_casts guard_step44_no_high_level_raw_collection_casts guard_parser_high_level_raw_casts

.PHONY: report_step45_subscript_lvalue_classified guard_step45_safe_subscript_write_enforcement report_phase4_formatter_tools fmt_check_phase4_infra report_step51_raw_pointer_deref report_step51_raw_pointer_casts report_step51_address_escapes_focused report_step51_ffi_calls report_step51_ffi_focused report_step51_unsafe_func_signatures report_step51_raw_pointer_classified report_step51_raw_pointer_safe_code_candidates report_step51_phase_b_wrapping_status guard_step51_raw_deref_unsafe_enforcement guard_step51_raw_cast_unsafe_enforcement guard_step51_pointer_arithmetic_unsafe_enforcement guard_step51_unsafe_func_call_enforcement guard_step51_raw_pointer_local_escape_enforcement guard_step51_extern_func_parser_metadata guard_step51_extern_func_call_enforcement guard_step51_layout_metadata_defaults guard_step51_layout_ffi_policy_helpers guard_step51_layout_ffi_signature_helpers guard_step51_sandbox_policy_defaults guard_step51_address_origin_metadata guard_step51_basic_unsafe_enforcement guard_step51_report_only_lanes_not_in_test report_step51_phase_c_basic_unsafe_status report_step51_phase_d_ffi_status report_step51_phase_e_address_escape_status report_step51_phase_f_non_laundering_status report_step51_deferred_unsafe_semantics_status report_step51_status_matrix report_step51_raw_pointer_safety_inventory report_step51_final_validation report_step52_linear_resource_inventory report_step52_linear_resource_focused report_step52_phase_a_status report_step52_phase_b_destructor_status report_step52_phase_c_resource_registry_status report_step52_phase_d_transfer_status report_step52_phase_e_enforcement_preconditions_status report_step52_phase_f_closure_status report_step52_status_matrix guard_step52_report_only_lanes_not_in_test guard_step52_no_post_closure_report_churn report_step52_final_validation

# Track all compiler and runtime source files to ensure correct incremental builds
COMPILER_SRCS = $(wildcard compiler/*.gst)
RUNTIME_SRCS  = src/runtime.c $(wildcard src/runtime/*.c) $(wildcard src/runtime/*.h)

all: gust

gust_bootstrap: gust_v4.c $(RUNTIME_SRCS)
	mkdir -p build
	cat src/runtime.c gust_v4.c > build/gust_bootstrap_final.c
	${CC} ${CFLAGS} ${INCLUDES} build/gust_bootstrap_final.c -o gust_bootstrap

build/gust_compiler.c: gust_bootstrap $(COMPILER_SRCS)
	mkdir -p build
	./gust_bootstrap compiler/test_runner_entry.gst | grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" > build/gust_compiler.tmp
	mv build/gust_compiler.tmp build/gust_compiler.c
	sync

gust: build/gust_compiler.c $(RUNTIME_SRCS)
	cat src/runtime.c build/gust_compiler.c > build/gust_final.c
	${CC} ${CFLAGS} ${INCLUDES} build/gust_final.c -o gust

# Fixed-Point Bootstrap Verification
bootstrap: gust
	@echo "⚙️  Beginning fixed-point bootstrap verification..."
	@# Stage 2: Use the new 'gust' binary to compile the compiler again
	./gust compiler/test_runner_entry.gst | grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" > build/gust_stage2.c && sync
	@cat src/runtime.c build/gust_stage2.c > build/gust_stage2_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/gust_stage2_final.c -o build/gust_stage2_bin
	@# Stage 3: Use the Stage 2 binary to compile the compiler a third time
	./build/gust_stage2_bin compiler/test_runner_entry.gst | grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" > build/gust_stage3.c && sync
	@# Stage 4: Assert byte-by-byte identity between Stage 2 and Stage 3 C files
	@diff -u build/gust_stage2.c build/gust_stage3.c && echo "✅ Fixed-point bootstrap convergence achieved!"
	cp build/gust_stage3.c gust_v4.c
	cp build/gust_stage2_bin gust_bootstrap
	touch build/gust_compiler.c
	touch gust

test: gust guard_step45_safe_subscript_write_enforcement guard_step51_basic_unsafe_enforcement guard_step51_extern_func_parser_metadata guard_step51_extern_func_call_enforcement guard_step51_layout_metadata_defaults guard_step51_layout_ffi_policy_helpers guard_step51_layout_ffi_signature_helpers guard_step51_sandbox_policy_defaults guard_step51_address_origin_metadata guard_step51_expression_provenance_carrier guard_step51_safe_constructor_provenance guard_step51_selector_safe_constructor_provenance guard_step51_container_safe_constructor_provenance guard_step51_container_method_provenance guard_step51_variable_provenance_bindings guard_step51_return_provenance_capture guard_step51_function_call_provenance guard_step51_aggregate_field_provenance guard_step51_container_provenance guard_step51_non_laundering_return_enforcement guard_step51_non_laundering_binding_enforcement guard_step51_non_laundering_call_enforcement guard_step51_non_laundering_field_enforcement guard_step51_non_laundering_container_enforcement guard_step51_non_laundering_container_method_enforcement guard_step51_non_laundering_arena_write_enforcement guard_step51_report_only_lanes_not_in_test guard_step52_report_only_lanes_not_in_test guard_step52_no_post_closure_report_churn guard_parser_high_level_raw_casts guard_step44_low_risk_entry_raw_casts guard_step44_typechecker_aux_raw_casts guard_step44_typechecker_types_raw_casts guard_step44_codegen_initializer_raw_casts guard_step44_typechecker_early_raw_casts guard_step44_typechecker_methods_raw_casts guard_step44_typechecker_pool_graph_raw_casts guard_step44_typechecker_call_validation_raw_casts guard_step44_typechecker_generic_helpers_raw_casts guard_step44_typechecker_template_registration_raw_casts guard_step44_typechecker_env_registration_raw_casts guard_step44_typechecker_brand_helpers_raw_casts guard_step44_typechecker_function_checks_raw_casts guard_step44_typechecker_statement_traversal_raw_casts guard_step44_codegen_early_helpers_raw_casts guard_step44_codegen_dispatch_methods_raw_casts guard_step44_codegen_pool_graph_std_raw_casts guard_step44_codegen_std_alloc_helpers_raw_casts guard_step44_codegen_runtime_tail_raw_casts guard_step44_codegen_statement_emit_raw_casts guard_step44_codegen_program_passes_raw_casts guard_step44_no_high_level_raw_collection_casts
	@mkdir -p build
	@echo "⚙️  Compiling native Gust test runner..."
	@./gust tests/test_runner.gst | grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" > build/test_runner.c
	@cat src/runtime.c build/test_runner.c > build/test_runner_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/test_runner_final.c -o build/test_runner_bin
	@echo "🏃 Running native Gust test runner..."
	@./build/test_runner_bin
	@$(MAKE) test_tree_sitter

test_tree_sitter:
	@echo "🔍 Running Tree-sitter corpus tests..."
	cd tree-sitter-gust && tree-sitter test
	@echo "🔍 Validating all Gust files parse with zero errors (including explicit reference-access tests)..."
	@for f in compiler/*.gst tests/*.gst; do \
		echo "Parsing $$f..."; \
		(cd tree-sitter-gust && tree-sitter parse ../$$f --quiet) || exit 1; \
	done
	@echo "✅ Tree-sitter parsing validation passed!"

report_phase4_formatter_tools:
	@echo "🧰 Reporting Phase 4A formatter tooling scaffold..."
	@echo "   Do not run repo-wide formatting until Phase 4B after Phase 5/6."
	@if command -v treefmt >/dev/null 2>&1; then echo "   treefmt: $$(command -v treefmt)"; else echo "   treefmt: missing from current shell"; fi
	@if command -v topiary >/dev/null 2>&1; then echo "   topiary: $$(command -v topiary)"; else echo "   topiary: missing from current shell"; fi
	@if command -v clang-format >/dev/null 2>&1; then echo "   clang-format: $$(command -v clang-format)"; else echo "   clang-format: missing from current shell"; fi
	@if command -v rustfmt >/dev/null 2>&1; then echo "   rustfmt: $$(command -v rustfmt)"; else echo "   rustfmt: missing from current shell"; fi
	@echo "✅ Phase 4A formatter tool report complete. This target is report-only and does not format files."

fmt_check_phase4_infra:
	@echo "🔎 Checking Phase 4A formatter scaffold files..."
	@test -f treefmt.toml || (echo "❌ Missing treefmt.toml"; exit 1)
	@test -f topiary/languages.ncl || (echo "❌ Missing topiary/languages.ncl"; exit 1)
	@test -f topiary/queries/gust.scm || (echo "❌ Missing topiary/queries/gust.scm"; exit 1)
	@echo "✅ Phase 4A formatter scaffold files are present. No formatting was run."

report_step51_raw_pointer_deref:
	@echo "📊 Reporting Step 5.1 raw pointer dereference candidates..."
	@echo "   Broad regex inventory only; enforcement must be AST/typechecker-based later."
	@rg -n '(^|[^[:alnum:]_])\*[[:space:]]*(\(|[A-Za-z_][A-Za-z0-9_]*)' compiler/*.gst tests/*.gst || true
	@echo "✅ Step 5.1 raw pointer dereference report complete. This target is inventory-only and does not fail."

report_step51_raw_pointer_casts:
	@echo "📊 Reporting Step 5.1 raw pointer cast/address-escape candidates..."
	@echo "   Includes raw pointer casts and direct address-taking patterns that may need unsafe wrapping."
	@rg -n ' as \*|&ctx\[|&[A-Za-z_][A-Za-z0-9_]*\[' compiler/*.gst tests/*.gst || true
	@echo "✅ Step 5.1 raw pointer cast/address report complete. This target is inventory-only and does not fail."

report_step51_address_escapes_focused:
	@echo "📊 Reporting Step 5.1 focused reference-aware address-escape candidates..."
	@python3 tools/step51_address_escape_report.py || true
	@echo "✅ Step 5.1 focused address-escape report complete. This target is inventory-only and does not fail."

report_step51_ffi_calls:
	@echo "📊 Reporting Step 5.1 direct FFI / external-call candidates..."
	@echo "   Broad textual search across compiler, tests, and runtime sources."
	@rg -n 'extern|ffi|Foreign|C\.|ccall|c_call|dlsym|dlopen|syscall' compiler/*.gst tests/*.gst src || true
	@echo "✅ Step 5.1 FFI candidate report complete. This target is inventory-only and does not fail."

report_step51_ffi_focused:
	@echo "📊 Reporting Step 5.1 focused token-aware FFI/native-call candidates..."
	@python3 tools/step51_ffi_report.py || true
	@echo "✅ Step 5.1 focused FFI report complete. This target is inventory-only and does not fail."

report_step51_unsafe_func_signatures:
	@echo "📊 Reporting Step 5.1 unsafe function signature candidates..."
	@echo "   Phase 5.1A should add no-op parser/typechecker support before enforcement."
	@rg -n 'unsafe[[:space:]]+func|func[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\([^)]*\)[^{;]*unsafe' compiler/*.gst tests/*.gst || true
	@echo "✅ Step 5.1 unsafe function signature report complete. This target is inventory-only and does not fail."

report_step51_raw_pointer_classified:
	@echo "📊 Reporting Step 5.1 classified raw pointer inventory..."
	@echo "   Raw pointer dereference expression candidates:"
	@rg -n '(^|[^[:alnum:]_])\*[[:space:]]*(\(|[A-Za-z_][A-Za-z0-9_]*)' compiler/*.gst tests/*.gst | rg -v ':[[:space:]]*\*| as \*|func[^(]*\([^)]*\*' || true
	@echo "   Raw pointer type syntax / declarations:"
	@rg -n ':[[:space:]]*\*|func[^(]*\([^)]*\*|std\.Vector\[[^]]*\*|Index\[[^]]*\*' compiler/*.gst tests/*.gst || true
	@echo "   Raw pointer casts:"
	@rg -n ' as \*' compiler/*.gst tests/*.gst || true
	@echo "   Address escape candidates:"
	@rg -n '&ctx\[|&[A-Za-z_][A-Za-z0-9_]*\[' compiler/*.gst tests/*.gst || true
	@echo "   Generated C string / codegen template candidates:"
	@rg -n '"[^"]*(\*|&|->|\[[^]]+\][^"]*=)' compiler/codegen.gst || true
	@echo "   Test and intentional fixture candidates:"
	@rg -n '(unsafe|raw|pointer|ffi|violation|rejected)' tests/*.gst | rg '\*| as \*|&' || true
	@echo "   Unclassified migration candidates:"
	@rg -n '(^|[^[:alnum:]_])\*[[:space:]]*(\(|[A-Za-z_][A-Za-z0-9_]*)| as \*|&ctx\[|&[A-Za-z_][A-Za-z0-9_]*\[' compiler/*.gst tests/*.gst | rg -v 'compiler/codegen\.gst:.*"' | rg -v 'tests/.*(unsafe|raw|pointer|ffi|violation|rejected).*\.gst:' || true
	@echo "✅ Classified Step 5.1 raw pointer report complete. This target is inventory-only and does not fail."

report_step51_raw_pointer_safe_code_candidates:
	@echo "📊 Reporting Step 5.1 focused safe-code raw pointer candidates..."
	@python3 tools/step51_raw_pointer_report.py || true
	@echo "✅ Step 5.1 focused safe-code candidate report complete. This target is inventory-only and does not fail."

report_step51_phase_b_wrapping_status:
	@echo "🧭 Reporting Step 5.1B proactive wrapping status..."
	@echo "   Review the focused safe-code candidate bucket before enabling any new raw pointer enforcement."
	@$(MAKE) report_step51_raw_pointer_safe_code_candidates
	@echo "   Intentional raw-gating negative fixtures are expected to remain visible in their dedicated bucket."
	@echo "   Raw pointer enforcement and escape-analysis negative fixtures are not Phase 5.1B wrapping candidates."
	@echo "   If the focused report shows no likely safe-code raw operation candidates, Phase 5.1B wrapping is ready for the next enforcement-design slice."
	@echo "   This target is still report-only; it does not prove safety and must not replace AST/typechecker enforcement."
	@echo "✅ Step 5.1B wrapping status report complete. This target is report-only and does not fail."

report_step51_phase_c_basic_unsafe_status:
	@echo "🧭 Reporting Step 5.1C basic unsafe enforcement status..."
	@echo "   Enforced aggregate:"
	@echo "   make guard_step51_basic_unsafe_enforcement"
	@echo "   Covered compiler-backed subguards:"
	@echo "   make guard_step51_raw_deref_unsafe_enforcement"
	@echo "   make guard_step51_raw_cast_unsafe_enforcement"
	@echo "   make guard_step51_pointer_arithmetic_unsafe_enforcement"
	@echo "   make guard_step51_unsafe_func_call_enforcement"
	@echo "   make guard_step51_raw_pointer_local_escape_enforcement"
	@echo "   Deferred: address escapes, FFI gating, and broader non-laundering/provenance tracking."
	@echo "✅ Step 5.1C basic unsafe enforcement status report complete. This target is report-only and does not run guards."

report_step51_phase_d_ffi_status:
	@echo "🧭 Reporting Step 5.1D FFI gating status..."
	@echo "   Current direct FFI inventory targets:"
	@echo "   make report_step51_ffi_calls"
	@echo "   make report_step51_ffi_focused"
	@echo "   Next enforcement-design slice should inspect direct external-call syntax and runtime/native boundaries before adding any guard."
	@echo "   The focused report is token-aware to avoid substring noise such as suffix or generic_call."
	@echo "   If the focused report shows zero Direct Gust source candidates, do not add an FFI guard yet."
	@echo "   Do not wire broad textual FFI scans into make test; FFI enforcement must be compiler-backed and syntax-aware."
	@echo "   Still deferred: direct FFI gating, #[repr(C)] / #[packed] layout annotations, sandboxed FFI sub-arenas, address escapes, and broader non-laundering/provenance tracking."
	@echo "✅ Step 5.1D FFI/layout/sandboxing status report complete. This target is report-only and does not run guards."

report_step51_phase_e_address_escape_status:
	@echo "🧭 Reporting Step 5.1E address-escape status..."
	@echo "   Current address-escape inventory targets:"
	@echo "   make report_step51_raw_pointer_casts"
	@echo "   make report_step51_address_escapes_focused"
	@echo "   Inspect direct safe-code address-escape candidates before adding any guard."
	@echo "   The focused report is reference-aware so branded reference type/cast syntax is not treated as an address escape."
	@echo "   The focused report separates intentional raw-cast gating fixtures and already-unsafe address expressions from safe-code candidates."
	@echo "   Do not wire broad textual address scans into make test; address-escape enforcement must be compiler-backed and semantic."
	@echo "   Still deferred: address escapes and broader non-laundering/provenance tracking."
	@echo "✅ Step 5.1E address-escape status report complete. This target is report-only and does not run guards."

report_step51_phase_f_non_laundering_status:
	@echo "🧭 Reporting Step 5.1F non-laundering/provenance status..."
	@echo "   Current compiler-backed unsafe boundary aggregate:"
	@echo "   make guard_step51_basic_unsafe_enforcement"
	@echo "   Current report-only precursor targets:"
	@echo "   make report_step51_phase_d_ffi_status"
	@echo "   make report_step51_phase_e_address_escape_status"
	@echo "   make report_step51_raw_pointer_safe_code_candidates"
	@echo "   Provenance design anchor: STEP51_DEFERRED_UNSAFE_SEMANTICS.md"
	@echo "   Inert expression carrier: make guard_step51_expression_provenance_carrier"
	@echo "   Safe constructor provenance metadata: make guard_step51_safe_constructor_provenance"
	@echo "   Selector safe constructor provenance metadata: make guard_step51_selector_safe_constructor_provenance"
	@echo "   Container safe constructor provenance metadata: make guard_step51_container_safe_constructor_provenance"
	@echo "   Container method write provenance metadata: make guard_step51_container_method_provenance"
	@echo "   Inert variable binding/assignment metadata: make guard_step51_variable_provenance_bindings"
	@echo "   Inert return provenance capture: make guard_step51_return_provenance_capture"
	@echo "   Inert function-call return provenance: make guard_step51_function_call_provenance"
	@echo "   Inert aggregate-field provenance: make guard_step51_aggregate_field_provenance"
	@echo "   Inert container provenance: make guard_step51_container_provenance"
	@echo "   Narrow safe-branded return rejection: make guard_step51_non_laundering_return_enforcement"
	@echo "   Narrow safe-branded binding/assignment rejection: make guard_step51_non_laundering_binding_enforcement"
	@echo "   Narrow safe-branded call-argument rejection: make guard_step51_non_laundering_call_enforcement"
	@echo "   Narrow safe-branded aggregate-field rejection: make guard_step51_non_laundering_field_enforcement"
	@echo "   Narrow safe-branded container-element rejection: make guard_step51_non_laundering_container_enforcement"
	@echo "   Narrow safe-branded container method storage rejection: make guard_step51_non_laundering_container_method_enforcement"
	@echo "   Narrow safe-branded Arena.Set/Write rejection: make guard_step51_non_laundering_arena_write_enforcement"
	@echo "   Existing narrow escape-analysis coverage remains guarded by make guard_step51_raw_pointer_local_escape_enforcement."
	@echo "   Still deferred: broader non-laundering diagnostics beyond direct safe-branded storage/call/return targets, field writes, indexed container writes, and basic container storage methods."
	@echo "✅ Step 5.1F non-laundering/provenance status report complete. This target is report-only and does not run guards."

report_step51_deferred_unsafe_semantics_status:
	@echo "🧭 Reporting Step 5.1 deferred unsafe semantics checkpoint..."
	@echo "   Design anchor: STEP51_DEFERRED_UNSAFE_SEMANTICS.md"
	@echo "   Closed compiler-backed subset: make guard_step51_basic_unsafe_enforcement"
	@echo "   Deferred compiler-design lanes:"
	@echo "   - direct FFI/native-call syntax metadata and unsafe gating"
	@echo "   - #[repr(C)] / #[packed] layout attributes"
	@echo "   - sandboxed FFI sub-arenas"
	@echo "   - address-origin metadata and address-escape enforcement"
	@echo "   - broader raw-derived provenance/non-laundering rejection guards beyond direct safe-branded storage, call, return, field-write, indexed container-write, and basic container method targets"
	@echo "   Inert compiler carrier: FunctionSignature has direct FFI metadata fields."
	@echo "   Inert AST carrier: FunctionDecl carries matching direct FFI metadata defaults."
	@echo "   Inert extern syntax: parser accepts extern func with C ABI defaults and unsafe-call metadata."
	@echo "   Bodyless extern declarations: parser accepts extern func signatures terminated with ';' and synthesizes an empty AST body."
	@echo "   Compiler-backed FFI call-site gating: make guard_step51_extern_func_call_enforcement"
	@echo "   Layout attribute parser metadata: parser accepts #[repr(C)] and #[packed] into StructDecl only."
	@echo "   Payload-safe layout metadata store: TypeEnvironment keeps repr-C/packed/ABI maps separate from StructLayout."
	@echo "   Layout metadata query helpers: env_struct_is_repr_c / env_struct_is_packed / env_struct_layout_abi_is_c / env_struct_requires_layout_metadata."
	@echo "   Layout-aware FFI helper predicates: signatures and struct layout maps can be queried without enforcement."
	@echo "   Signature-level C FFI layout helpers: resolved params/returns can be checked without rejecting programs."
	@echo "   Sandboxed FFI semantics: transient sub-arena ownership/destruction is documented; wrapper codegen remains deferred."
	@echo "   Inert sandbox policy helpers: function signatures expose sandbox/aggregate FFI policy predicates."
	@echo "   Inert address-origin metadata: safe-arena, raw-derived, sandbox-derived, and unknown origins are represented."
	@echo "   Provenance propagation design: assignments, calls, returns, aggregate fields, and containers must preserve origin metadata."
	@echo "   Inert expression provenance carrier: make guard_step51_expression_provenance_carrier"
	@echo "   Inert variable binding/assignment/readback provenance: make guard_step51_variable_provenance_bindings"
	@echo "   Inert return provenance capture: make guard_step51_return_provenance_capture"
	@echo "   Inert function-call return provenance: make guard_step51_function_call_provenance"
	@echo "   Inert aggregate-field provenance: make guard_step51_aggregate_field_provenance"
	@echo "   Inert container provenance: make guard_step51_container_provenance"
	@echo "   Narrow safe-branded return rejection: make guard_step51_non_laundering_return_enforcement"
	@echo "   Narrow safe-branded binding/assignment rejection: make guard_step51_non_laundering_binding_enforcement"
	@echo "   Narrow safe-branded call-argument rejection: make guard_step51_non_laundering_call_enforcement"
	@echo "   Narrow safe-branded aggregate-field rejection: make guard_step51_non_laundering_field_enforcement"
	@echo "   Narrow safe-branded container-element rejection: make guard_step51_non_laundering_container_enforcement"
	@echo "   Narrow safe-branded container method storage rejection: make guard_step51_non_laundering_container_method_enforcement"
	@echo "   Next implementation checkpoint: extend non-laundering rejection through remaining wrapper/API-specific boundaries."
	@echo "   Keep Step 5.2 compiler-backed enforcement paused until these lanes are resolved or explicitly scoped as non-blocking."
	@echo "✅ Step 5.1 deferred unsafe semantics status complete. This target is report-only and does not run guards."

report_step51_status_matrix:
	@echo "🧭 Step 5.1 safety status matrix:"
	@echo "   Compiler-backed guards wired through make test:"
	@echo "   ✅ raw pointer dereference outside unsafe: make guard_step51_raw_deref_unsafe_enforcement"
	@echo "   ✅ raw pointer casts outside unsafe: make guard_step51_raw_cast_unsafe_enforcement"
	@echo "   ✅ pointer arithmetic outside unsafe: make guard_step51_pointer_arithmetic_unsafe_enforcement"
	@echo "   ✅ unsafe function calls outside unsafe: make guard_step51_unsafe_func_call_enforcement"
	@echo "   ✅ local raw-derived pointer return escape: make guard_step51_raw_pointer_local_escape_enforcement"
	@echo "   ✅ extern function parser metadata: make guard_step51_extern_func_parser_metadata"
	@echo "   ✅ extern function calls outside unsafe: make guard_step51_extern_func_call_enforcement"
	@echo "   ✅ layout metadata defaults, attributes, and registry helpers: make guard_step51_layout_metadata_defaults"
	@echo "   ✅ layout-aware FFI helper predicates: make guard_step51_layout_ffi_policy_helpers"
	@echo "   ✅ signature-level C FFI layout helpers: make guard_step51_layout_ffi_signature_helpers"
	@echo "   ✅ sandbox policy defaults and helpers: make guard_step51_sandbox_policy_defaults"
	@echo "   ✅ address-origin metadata helpers: make guard_step51_address_origin_metadata"
	@echo "   ✅ expression provenance carrier helpers: make guard_step51_expression_provenance_carrier"
	@echo "   ✅ safe constructor provenance metadata: make guard_step51_safe_constructor_provenance"
	@echo "   ✅ selector safe constructor provenance metadata: make guard_step51_selector_safe_constructor_provenance"
	@echo "   ✅ container safe constructor provenance metadata: make guard_step51_container_safe_constructor_provenance"
	@echo "   ✅ container method write provenance metadata: make guard_step51_container_method_provenance"
	@echo "   ✅ variable binding/assignment/readback provenance metadata: make guard_step51_variable_provenance_bindings"
	@echo "   ✅ return expression provenance capture: make guard_step51_return_provenance_capture"
	@echo "   ✅ function-call return provenance metadata: make guard_step51_function_call_provenance"
	@echo "   ✅ aggregate-field provenance metadata: make guard_step51_aggregate_field_provenance"
	@echo "   ✅ container provenance metadata: make guard_step51_container_provenance"
	@echo "   ✅ non-laundering safe-branded return rejection: make guard_step51_non_laundering_return_enforcement"
	@echo "   ✅ non-laundering safe-branded binding/assignment rejection: make guard_step51_non_laundering_binding_enforcement"
	@echo "   ✅ non-laundering safe-branded call-argument rejection: make guard_step51_non_laundering_call_enforcement"
	@echo "   ✅ non-laundering safe-branded aggregate-field rejection: make guard_step51_non_laundering_field_enforcement"
	@echo "   ✅ non-laundering safe-branded container-element rejection: make guard_step51_non_laundering_container_enforcement"
	@echo "   ✅ non-laundering safe-branded container method storage rejection: make guard_step51_non_laundering_container_method_enforcement"
	@echo "   ✅ non-laundering safe-branded Arena.Set/Write rejection: make guard_step51_non_laundering_arena_write_enforcement"
	@echo "   Aggregate: make guard_step51_basic_unsafe_enforcement"
	@echo "   Report-only / deferred lanes:"
	@echo "   🧭 FFI layout annotations and sandboxed FFI: make report_step51_phase_d_ffi_status"
	@echo "   🧭 address escapes: make report_step51_phase_e_address_escape_status"
	@echo "   🧭 broader non-laundering/provenance: make report_step51_phase_f_non_laundering_status"
	@echo "   🧭 deferred semantics checkpoint: make report_step51_deferred_unsafe_semantics_status"
	@echo "   Policy guard: make guard_step51_report_only_lanes_not_in_test"
	@echo "   Step 5.1 direct extern-call gating is compiler-backed; do not mark full Step 5.1 complete until layout/sandboxing, address escapes, and full provenance are compiler-backed."
	@echo "   Do not convert report-only lanes into make test guards until compiler-backed semantic rules exist."
	@echo "✅ Step 5.1 safety status matrix complete. This target is report-only and does not run guards."

guard_step51_report_only_lanes_not_in_test:
	@echo "🔒 Guarding Step 5.1 report-only lanes are not direct make test dependencies..."
	@test_deps="$$(awk 'capture == 1 && /^[[:space:]]*@/ { exit } /^test:/ { capture = 1 } capture == 1 { print }' Makefile)"; \
	if echo "$$test_deps" | grep -q 'report_step51_'; then \
		echo "❌ Step 5.1 report-only target is wired directly into make test:"; \
		echo "$$test_deps"; \
		exit 1; \
	fi
	@echo "✅ Step 5.1 report-only lanes are not direct make test dependencies."

report_step51_raw_pointer_safety_inventory:
	@echo "🧾 Step 5.1 raw pointer safety inventory checklist:"
	@echo "   make report_step51_raw_pointer_deref"
	@echo "   make report_step51_raw_pointer_casts"
	@echo "   make report_step51_address_escapes_focused"
	@echo "   make report_step51_ffi_calls"
	@echo "   make report_step51_ffi_focused"
	@echo "   make report_step51_unsafe_func_signatures"
	@echo "   make report_step51_raw_pointer_classified"
	@echo "   make report_step51_raw_pointer_safe_code_candidates"
	@echo "   make report_step51_phase_b_wrapping_status"
	@echo "   make report_step51_phase_c_basic_unsafe_status"
	@echo "   make report_step51_phase_d_ffi_status"
	@echo "   make report_step51_phase_e_address_escape_status"
	@echo "   make report_step51_phase_f_non_laundering_status"
	@echo "   make report_step51_deferred_unsafe_semantics_status"
	@echo "   make report_step51_status_matrix"
	@$(MAKE) report_step51_raw_pointer_deref
	@$(MAKE) report_step51_raw_pointer_casts
	@$(MAKE) report_step51_address_escapes_focused
	@$(MAKE) report_step51_ffi_calls
	@$(MAKE) report_step51_ffi_focused
	@$(MAKE) report_step51_unsafe_func_signatures
	@$(MAKE) report_step51_raw_pointer_classified
	@$(MAKE) report_step51_raw_pointer_safe_code_candidates
	@$(MAKE) report_step51_phase_b_wrapping_status
	@$(MAKE) report_step51_phase_c_basic_unsafe_status
	@$(MAKE) report_step51_phase_d_ffi_status
	@$(MAKE) report_step51_phase_e_address_escape_status
	@$(MAKE) report_step51_phase_f_non_laundering_status
	@$(MAKE) report_step51_deferred_unsafe_semantics_status
	@$(MAKE) report_step51_status_matrix
	@echo "✅ Step 5.1 raw pointer safety inventory complete. This target is report-only and does not fail."

report_step51_final_validation:
	@echo "🧾 Step 5.1 validation checklist:"
	@echo "   make report_step51_raw_pointer_safety_inventory"
	@echo "   make report_step51_raw_pointer_classified"
	@echo "   make report_step51_raw_pointer_safe_code_candidates"
	@echo "   make report_step51_phase_b_wrapping_status"
	@echo "   make report_step51_phase_c_basic_unsafe_status"
	@echo "   make report_step51_phase_d_ffi_status"
	@echo "   make report_step51_phase_e_address_escape_status"
	@echo "   make report_step51_phase_f_non_laundering_status"
	@echo "   make report_step51_deferred_unsafe_semantics_status"
	@echo "   make report_step51_status_matrix"
	@echo "   make guard_step51_report_only_lanes_not_in_test"
	@echo "   make report_step51_ffi_focused"
	@echo "   make report_step51_address_escapes_focused"
	@echo "   make guard_step51_basic_unsafe_enforcement"
	@echo "   make guard_step51_extern_func_parser_metadata"
	@echo "   make guard_step51_extern_func_call_enforcement"
	@echo "   make guard_step51_layout_metadata_defaults"
	@echo "   make guard_step51_layout_ffi_policy_helpers"
	@echo "   make guard_step51_layout_ffi_signature_helpers"
	@echo "   make guard_step51_sandbox_policy_defaults"
	@echo "   make guard_step51_address_origin_metadata"
	@echo "   make guard_step51_raw_deref_unsafe_enforcement"
	@echo "   make guard_step51_raw_cast_unsafe_enforcement"
	@echo "   make guard_step51_pointer_arithmetic_unsafe_enforcement"
	@echo "   make guard_step51_unsafe_func_call_enforcement"
	@echo "   make guard_step51_raw_pointer_local_escape_enforcement"
	@echo "   gt-one-gst tests/e2e_unsafe_func_body_raw_ops.gst"
	@echo "   gt-one-gst tests/e2e_unsafe_function_signature_noop.gst"
	@echo "   make report_step45_final_validation"
	@echo "   make report_phase4_formatter_tools"
	@echo "   make fmt_check_phase4_infra"
	@echo "   make"
	@echo "   make test"
	@echo "   make bootstrap"
	@echo "   git diff --check"
	@echo "✅ Step 5.1 validation checklist complete. Basic unsafe enforcement, direct extern-call gating, layout metadata helpers, inert layout-aware FFI predicates, inert signature-level layout checks, inert sandbox policy helpers, and address-origin metadata helpers are compiler-backed; call-site layout rejection, sandbox wrapper codegen, and broader non-laundering remain deferred lanes."

report_step52_linear_resource_inventory:
	@echo "📊 Reporting Step 5.2 generalized linear resource precursor inventory..."
	@echo "   Existing specialized directory tracking and resource-like syntax:"
	@rg -n 'open_directories|OpenDir|ReadDir|CloseDir|Dir|drop_func|linear|Resource|defer' compiler/*.gst tests/*.gst src || true
	@echo "   Native/runtime directory boundary candidates:"
	@rg -n 'DIR\*|opendir|readdir|closedir|os_OpenDir|os_ReadDir|os_CloseDir' src compiler/*.gst tests/*.gst || true
	@echo "✅ Step 5.2 linear resource precursor inventory complete. This target is report-only and does not fail."

report_step52_linear_resource_focused:
	@echo "📊 Reporting Step 5.2 focused linear resource precursor inventory..."
	@python3 tools/step52_linear_resource_report.py || true
	@echo "✅ Step 5.2 focused linear resource report complete. This target is inventory-only and does not fail."

report_step52_phase_a_status:
	@echo "🧭 Reporting Step 5.2A metadata opt-in status..."
	@echo "   Current precursor inventory targets:"
	@echo "   make report_step52_linear_resource_inventory"
	@echo "   make report_step52_linear_resource_focused"
	@echo "   Step 5.2A must stay metadata-opt-in so ordinary compiler structs, primitives, and unannotated collections bypass linear-resource analysis."
	@echo "   Do not replace open_directories or add generalized leak enforcement until future Resource[ctx, T] syntax, destructor registration, and open_linear_resources representation are designed."
	@echo "   Existing linear metadata/tests are not the same as the future generalized Resource[ctx, T] surface."
	@echo "   Existing directory tracking remains the legacy specialized resource lane until generalized linear-resource infrastructure exists."
	@echo "✅ Step 5.2A metadata opt-in status report complete. This target is report-only and does not run guards."

report_step52_phase_b_destructor_status:
	@echo "🧭 Reporting Step 5.2B destructor/defer status..."
	@echo "   Current precursor inventory target:"
	@echo "   make report_step52_linear_resource_focused"
	@echo "   Inspect the focused report's Destructor/defer syntax bucket before designing destructor registration."
	@echo "   Do not add destructor leak enforcement until Resource[ctx, T] ownership metadata and open_linear_resources tracking exist."
	@echo "   Do not add defer validation until defer has explicit AST/typechecker semantics rather than textual inventory matches."
	@echo "   Existing open_directories cleanup remains the legacy specialized lane, not generalized destructor registration."
	@echo "✅ Step 5.2B destructor/defer status report complete. This target is report-only and does not run guards."

report_step52_phase_c_resource_registry_status:
	@echo "🧭 Reporting Step 5.2C Resource/open-linear registry status..."
	@echo "   Current precursor inventory target:"
	@echo "   make report_step52_linear_resource_focused"
	@echo "   Inspect the focused report's Future Resource/open-linear registry bucket before designing Resource[ctx, T]."
	@echo "   Do not replace open_directories until open_linear_resources can track Resource[ctx, T] ownership by context, destructor, and transfer state."
	@echo "   Resource[ctx, T] must be compiler-backed metadata, not a textual alias for existing linear structs or directory handles."
	@echo "   Existing open_directories remains the legacy specialized lane until the generalized registry has equivalent directory-handle coverage."
	@echo "✅ Step 5.2C Resource/open-linear registry status report complete. This target is report-only and does not run guards."

report_step52_phase_d_transfer_status:
	@echo "🧭 Reporting Step 5.2D ownership-transfer status..."
	@echo "   Current precursor inventory targets:"
	@echo "   make report_step52_linear_resource_focused"
	@echo "   make report_step52_phase_c_resource_registry_status"
	@echo "   Do not add move/use-after-move or double-close enforcement until Resource[ctx, T] values carry explicit transfer state in the typechecker."
	@echo "   Transfer tracking must distinguish owned, moved, borrowed, closed, and destructor-scheduled resources semantically."
	@echo "   Existing open_directories cleanup is still specialized directory tracking, not generalized ownership-transfer analysis."
	@echo "✅ Step 5.2D ownership-transfer status report complete. This target is report-only and does not run guards."

report_step52_phase_e_enforcement_preconditions_status:
	@echo "🧭 Reporting Step 5.2E enforcement preconditions."
	@echo "   Generalized linear-resource guards must remain deferred until all semantic prerequisites exist:"
	@echo "   - explicit metadata opt-in for linear resource types"
	@echo "   - Resource[ctx, T] representation with ownership state"
	@echo "   - open_linear_resources registry with destructor identity"
	@echo "   - destructor registration and explicit defer AST/typechecker semantics"
	@echo "   - transfer-state validation for owned/moved/borrowed/closed/destructor-scheduled resources"
	@echo "   - directory-handle parity with the legacy open_directories lane"
	@echo "   Do not convert Step 5.2 textual inventories into make test guards before these preconditions are compiler-backed."
	@echo "✅ Step 5.2E enforcement preconditions report complete. This target is report-only and does not run guards."

report_step52_phase_f_closure_status:
	@echo "🧭 Reporting Step 5.2F report-only closure status..."
	@echo "   Step 5.2 report-only scaffold now covers:"
	@echo "   - broad and focused resource inventory"
	@echo "   - metadata opt-in handoff"
	@echo "   - destructor/defer handoff"
	@echo "   - Resource/open-linear registry handoff"
	@echo "   - ownership-transfer handoff"
	@echo "   - semantic enforcement preconditions"
	@echo "   Stop adding textual report churn unless a new compiler-backed design requirement appears."
	@echo "   Next implementation work must be AST/typechecker design for Resource[ctx, T], open_linear_resources, destructor identity, transfer state, and legacy open_directories parity."
	@echo "✅ Step 5.2F report-only closure status complete. This target is report-only and does not run guards."

report_step52_status_matrix:
	@echo "🧭 Step 5.2 linear resource status matrix:"
	@echo "   Legacy specialized lane still active:"
	@echo "   🧭 directory-handle tracking: open_directories / os.OpenDir / os.ReadDir / os.CloseDir"
	@echo "   Report-only precursor targets:"
	@echo "   🧭 broad inventory: make report_step52_linear_resource_inventory"
	@echo "   🧭 focused inventory: make report_step52_linear_resource_focused"
	@echo "   🧭 metadata opt-in status: make report_step52_phase_a_status"
	@echo "   🧭 destructor/defer status: make report_step52_phase_b_destructor_status"
	@echo "   🧭 Resource/open-linear registry status: make report_step52_phase_c_resource_registry_status"
	@echo "   🧭 ownership-transfer status: make report_step52_phase_d_transfer_status"
	@echo "   🧭 enforcement preconditions: make report_step52_phase_e_enforcement_preconditions_status"
	@echo "   🧭 report-only closure: make report_step52_phase_f_closure_status"
	@echo "   Policy guards wired through make test:"
	@echo "   ✅ report-only Step 5.2 targets stay out of test deps: make guard_step52_report_only_lanes_not_in_test"
	@echo "   ✅ no new post-closure Step 5.2 report target churn: make guard_step52_no_post_closure_report_churn"
	@echo "   Deferred generalized compiler-backed work:"
	@echo "   ⏳ linear metadata / #[linear] opt-in"
	@echo "   ⏳ Resource[ctx, T] representation"
	@echo "   ⏳ open_linear_resources registry"
	@echo "   ⏳ destructor registration and defer validation"
	@echo "   ⏳ ownership transfer state and use-after-move validation"
	@echo "   ⏳ compiler-backed enforcement preconditions before any Step 5.2 guard"
	@echo "   ⏳ AST/typechecker design before further Step 5.2 report churn"
	@echo "   Existing linear metadata/test coverage is inventory context, not generalized resource enforcement."
	@echo "   Do not purge open_directories or add generalized leak enforcement until the deferred pieces exist."
	@echo "✅ Step 5.2 linear resource status matrix complete. This target is report-only and does not run guards."

guard_step52_report_only_lanes_not_in_test:
	@echo "🔒 Guarding Step 5.2 report-only lanes are not direct make test dependencies..."
	@test_deps="$$(awk 'capture == 1 && /^[[:space:]]*@/ { exit } /^test:/ { capture = 1 } capture == 1 { print }' Makefile)"; \
	if echo "$$test_deps" | grep -q 'report_step52_'; then \
		echo "❌ Step 5.2 report-only target is wired directly into make test:"; \
		echo "$$test_deps"; \
		exit 1; \
	fi
	@echo "✅ Step 5.2 report-only lanes are not direct make test dependencies."

guard_step52_no_post_closure_report_churn:
	@echo "🔒 Guarding Step 5.2 report-only closure against new report target churn..."
	@allowed_reports='^(report_step52_linear_resource_inventory|report_step52_linear_resource_focused|report_step52_phase_a_status|report_step52_phase_b_destructor_status|report_step52_phase_c_resource_registry_status|report_step52_phase_d_transfer_status|report_step52_phase_e_enforcement_preconditions_status|report_step52_phase_f_closure_status|report_step52_status_matrix|report_step52_final_validation):$$'; \
	extra_reports="$$(grep -E '^report_step52_.*:' Makefile | grep -Ev "$$allowed_reports" || true)"; \
	if [ -n "$$extra_reports" ]; then \
		echo "❌ Unexpected post-closure Step 5.2 report target(s):"; \
		echo "$$extra_reports"; \
		echo "Step 5.2F closed textual report churn; move to AST/typechecker design or update this whitelist intentionally."; \
		exit 1; \
	fi
	@echo "✅ Step 5.2 report-only closure whitelist is unchanged."

report_step52_final_validation:
	@echo "🧾 Step 5.2 validation checklist:"
	@echo "   make report_step52_linear_resource_inventory"
	@echo "   make report_step52_linear_resource_focused"
	@echo "   make report_step52_phase_a_status"
	@echo "   make report_step52_phase_b_destructor_status"
	@echo "   make report_step52_phase_c_resource_registry_status"
	@echo "   make report_step52_phase_d_transfer_status"
	@echo "   make report_step52_phase_e_enforcement_preconditions_status"
	@echo "   make report_step52_phase_f_closure_status"
	@echo "   make report_step52_status_matrix"
	@echo "   make guard_step52_report_only_lanes_not_in_test"
	@echo "   make guard_step52_no_post_closure_report_churn"
	@echo "   make report_step51_status_matrix"
	@echo "   make guard_step51_report_only_lanes_not_in_test"
	@echo "   make guard_step51_basic_unsafe_enforcement"
	@echo "   make report_step51_final_validation"
	@echo "   make test"
	@echo "   make bootstrap"
	@echo "   git diff --check"
	@echo "✅ Step 5.2 validation checklist complete. Generalized linear resources are report-only/deferred; do not purge open_directories yet."

report_step44_accessor_contract:
	@echo "🧪 Step 4.4 accessor contract focused checks:"
	@echo "   gt-one-gst tests/e2e_collection_dual_signatures.gst"
	@echo "   gt-one-gst tests/e2e_vector_get_ref_alias.gst"
	@echo "   gt-one-gst tests/e2e_hashmap_get_ref.gst"
	@echo "   gt-one-gst tests/test_vector_get_ref_alias_bad_index_type_rejected.gst"
	@echo "   gt-one-gst tests/test_vector_get_ref_alias_non_vector_rejected.gst"
	@echo "   gt-one-gst tests/test_hashmap_get_ref_bad_key_rejected.gst"
	@echo "   gt-one-gst tests/test_hashmap_get_ref_missing_runtime_violation.gst"
	@echo "✅ Accessor contract list complete. Run these before make test/bootstrap for Step 4.4 patches."

report_step45_accessor_contract:
	@echo "🧪 Step 4.5A explicit write/read-copy contract focused checks:"
	@echo "   gt-one-gst tests/e2e_arena_explicit_set.gst"
	@echo "   gt-one-gst tests/e2e_vector_explicit_set.gst"
	@echo "   gt-one-gst tests/e2e_hashmap_explicit_write.gst"
	@echo "   gt-one-gst tests/e2e_arena_subscript_read_copy.gst"
	@echo "   gt-one-gst tests/e2e_vector_subscript_read_copy.gst"
	@echo "✅ Step 4.5A accessor contract list complete. Run these before make test/bootstrap for Step 4.5A patches."

report_step45_final_validation:
	@echo "🧾 Step 4.5 final validation checklist:"
	@echo "   make report_step45_accessor_contract"
	@echo "   gt-one-gst tests/e2e_arena_explicit_set.gst"
	@echo "   gt-one-gst tests/e2e_vector_explicit_set.gst"
	@echo "   gt-one-gst tests/e2e_hashmap_explicit_write.gst"
	@echo "   gt-one-gst tests/e2e_arena_subscript_read_copy.gst"
	@echo "   gt-one-gst tests/e2e_vector_subscript_read_copy.gst"
	@echo "   make report_step44_accessor_contract"
	@echo "   make report_high_level_raw_collection_casts"
	@echo "   make guard_step44_no_high_level_raw_collection_casts"
	@echo "   make report_step45_subscript_lvalue_writes"
	@echo "   make report_step45_test_subscript_lvalue_writes"
	@echo "   make report_step45_subscript_lvalue_classified"
	@echo "   make guard_step45_safe_subscript_write_enforcement"
	@echo "   make"
	@echo "   make test"
	@echo "   make bootstrap"
	@echo "   git diff --check"
	@echo "✅ Step 4.5 final validation checklist complete. This target is report-only and does not fail."

report_compiler_get_opt_migration:
	@echo "📊 Reporting compiler .get_opt migration sites..."
	@rg -n '\.get_opt[[:space:]]*\(' compiler/*.gst || true

report_high_level_raw_collection_casts:
	@echo "📊 Reporting Step 4.4 high-level raw collection/string cast migration sites..."
	@echo "   Direct arena-to-vector casts:"
	@rg -n '&ctx\[' compiler/*.gst | rg ' as \*std\.Vector' || true
	@echo "   Direct arena-to-hashmap casts:"
	@rg -n '&ctx\[' compiler/*.gst | rg ' as \*std\.HashMap' || true
	@echo "   Direct arena-to-string-view casts:"
	@rg -n '&ctx\[' compiler/*.gst | rg ' as \*str' || true
	@echo "✅ Report complete. This target is inventory-only and does not fail."

report_step45_subscript_lvalue_writes:
	@echo "📊 Reporting Step 4.5 direct subscript LHS write inventory..."
	@echo "   Direct subscript writes and field writes rooted at subscript expressions:"
	@rg -n '\[[^;\n]*\][^;\n]*[^:!<>=]=[^=]' compiler/*.gst tests/*.gst || true
	@echo "✅ Report complete. This target is inventory-only and does not fail."

report_step45_test_subscript_lvalue_writes:
	@echo "📊 Reporting Step 4.5 test-side direct subscript LHS write inventory..."
	@echo "   Test direct subscript writes and field writes rooted at subscript expressions:"
	@rg -n '\[[^;\n]*\][^;\n]*[^:!<>=]=[^=]' tests/*.gst || true
	@echo "✅ Test-side report complete. This target is inventory-only and does not fail."

report_step45_subscript_lvalue_classified:
	@echo "📊 Reporting Step 4.5 classified direct subscript LHS inventory..."
	@echo "   Generated C string false positives:"
	@rg -n '\[[^;\n]*\][^;\n]*[^:!<>=]=[^=]' compiler/codegen.gst | rg 'data\[_gust_vector_set_idx\] = |_buf\[_s1\.len \+ _s2\.len\] = 0' || true
	@echo "   Intentional safe-code rejection fixtures:"
	@rg -n '\[[^;\n]*\][^;\n]*[^:!<>=]=[^=]' tests/test_safe_*subscript*_rejected.gst || true
	@echo "   Intentional unsafe-positive fixtures:"
	@rg -n '\[[^;\n]*\][^;\n]*[^:!<>=]=[^=]' tests/e2e_unsafe_*subscript*write*.gst || true
	@echo "   Unexpected safe-code direct subscript writes:"
	@rg -n '\[[^;\n]*\][^;\n]*[^:!<>=]=[^=]' compiler/*.gst tests/*.gst | rg -v 'compiler/codegen\.gst:.*(data\[_gust_vector_set_idx\] = |_buf\[_s1\.len \+ _s2\.len\] = 0)' | rg -v 'tests/test_safe_.*subscript.*_rejected\.gst:' | rg -v 'tests/e2e_unsafe_.*subscript.*write.*\.gst:' || true
	@echo "✅ Classified Step 4.5 subscript LHS report complete. This target is inventory-only and does not fail."

guard_step45_safe_subscript_write_enforcement: gust
	@echo "🔒 Checking Step 4.5C safe subscript write enforcement..."
	@mkdir -p build
	@for f in \
		tests/test_safe_arena_subscript_write_rejected.gst \
		tests/test_safe_arena_subscript_field_write_rejected.gst \
		tests/test_safe_vector_subscript_write_rejected.gst \
		tests/test_safe_nested_selector_subscript_field_write_rejected.gst; do \
		echo "Checking $$f rejects safe direct subscript writes..."; \
		./gust $$f > build/step45c_guard.log 2>&1; \
		status=$$?; \
		if [ $$status -eq 0 ]; then \
			echo "❌ Step 4.5C guard failed: $$f compiled but should reject safe direct subscript writes."; \
			cat build/step45c_guard.log; \
			exit 1; \
		fi; \
		if ! rg -q "direct subscript writes require unsafe or explicit write APIs" build/step45c_guard.log; then \
			echo "❌ Step 4.5C guard failed: $$f rejected without the stable unsafe-subscript diagnostic."; \
			cat build/step45c_guard.log; \
			exit 1; \
		fi; \
	done
	@for f in \
		tests/e2e_unsafe_arena_subscript_write.gst \
		tests/e2e_unsafe_arena_subscript_field_write.gst \
		tests/e2e_unsafe_vector_subscript_write.gst \
		tests/e2e_unsafe_nested_selector_subscript_field_write.gst; do \
		echo "Checking $$f still accepts unsafe direct subscript writes..."; \
		./gust $$f > build/step45c_guard.log 2>&1; \
		status=$$?; \
		if [ $$status -ne 0 ]; then \
			echo "❌ Step 4.5C guard failed: $$f should compile inside unsafe."; \
			cat build/step45c_guard.log; \
			exit 1; \
		fi; \
	done
	@echo "✅ Step 4.5C safe subscript write enforcement guard passed."

guard_step51_raw_deref_unsafe_enforcement: gust
	@echo "🔒 Checking Step 5.1 raw pointer dereference unsafe enforcement..."
	@mkdir -p build
	@echo "Checking raw pointer dereference outside unsafe rejects..."
	@./gust tests/test_raw_pointer_deref_outside_unsafe_rejected.gst > build/step51_raw_deref_guard.log 2>&1; \
	status=$$?; \
	if [ $$status -eq 0 ]; then \
		echo "❌ Step 5.1 raw deref guard failed: outside-unsafe raw deref compiled but should reject."; \
		cat build/step51_raw_deref_guard.log; \
		exit 1; \
	fi; \
	if ! rg -q "Dereferencing raw pointers is strictly prohibited outside 'unsafe' blocks" build/step51_raw_deref_guard.log; then \
		echo "❌ Step 5.1 raw deref guard failed: rejection did not use the stable unsafe diagnostic."; \
		cat build/step51_raw_deref_guard.log; \
		exit 1; \
	fi
	@echo "Checking raw pointer dereference inside unsafe accepts..."
	@./gust tests/e2e_raw_pointer_deref_inside_unsafe.gst > build/step51_raw_deref_guard.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 raw deref guard failed: inside-unsafe raw deref should compile."; \
		cat build/step51_raw_deref_guard.log; \
		exit 1; \
	fi
	@echo "✅ Step 5.1 raw pointer dereference unsafe enforcement guard passed."

guard_step51_raw_cast_unsafe_enforcement: gust
	@echo "🔒 Checking Step 5.1 raw pointer cast unsafe enforcement..."
	@mkdir -p build
	@echo "Checking raw pointer cast outside unsafe rejects..."
	@./gust tests/test_raw_pointer_cast_outside_unsafe_rejected.gst > build/step51_raw_cast_guard.log 2>&1; \
	status=$$?; \
	if [ $$status -eq 0 ]; then \
		echo "❌ Step 5.1 raw cast guard failed: outside-unsafe raw cast compiled but should reject."; \
		cat build/step51_raw_cast_guard.log; \
		exit 1; \
	fi; \
	if ! rg -q "Raw pointer casts are strictly prohibited outside 'unsafe' blocks" build/step51_raw_cast_guard.log; then \
		echo "❌ Step 5.1 raw cast guard failed: rejection did not use the stable unsafe diagnostic."; \
		cat build/step51_raw_cast_guard.log; \
		exit 1; \
	fi
	@echo "Checking raw pointer cast inside unsafe accepts..."
	@./gust tests/e2e_raw_pointer_cast_inside_unsafe.gst > build/step51_raw_cast_guard.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 raw cast guard failed: inside-unsafe raw cast should compile."; \
		cat build/step51_raw_cast_guard.log; \
		exit 1; \
	fi
	@echo "✅ Step 5.1 raw pointer cast unsafe enforcement guard passed."

guard_step51_pointer_arithmetic_unsafe_enforcement: gust
	@echo "🔒 Checking Step 5.1 pointer arithmetic unsafe enforcement..."
	@mkdir -p build
	@echo "Checking pointer arithmetic outside unsafe rejects..."
	@./gust tests/test_raw_pointer_arithmetic_outside_unsafe_rejected.gst > build/step51_pointer_arithmetic_guard.log 2>&1; \
	status=$$?; \
	if [ $$status -eq 0 ]; then \
		echo "❌ Step 5.1 pointer arithmetic guard failed: outside-unsafe pointer arithmetic compiled but should reject."; \
		cat build/step51_pointer_arithmetic_guard.log; \
		exit 1; \
	fi; \
	if ! rg -q "Pointer arithmetic is strictly prohibited outside 'unsafe' blocks" build/step51_pointer_arithmetic_guard.log; then \
		echo "❌ Step 5.1 pointer arithmetic guard failed: rejection did not use the stable unsafe diagnostic."; \
		cat build/step51_pointer_arithmetic_guard.log; \
		exit 1; \
	fi
	@echo "Checking pointer arithmetic inside unsafe accepts..."
	@./gust tests/e2e_raw_pointer_arithmetic_inside_unsafe.gst > build/step51_pointer_arithmetic_guard.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 pointer arithmetic guard failed: inside-unsafe pointer arithmetic should compile."; \
		cat build/step51_pointer_arithmetic_guard.log; \
		exit 1; \
	fi
	@echo "✅ Step 5.1 pointer arithmetic unsafe enforcement guard passed."

guard_step51_unsafe_func_call_enforcement: gust
	@echo "🔒 Checking Step 5.1 unsafe function call enforcement..."
	@mkdir -p build
	@echo "Checking unsafe function call outside unsafe rejects..."
	@./gust tests/test_unsafe_func_call_outside_unsafe_rejected.gst > build/step51_unsafe_func_call_guard.log 2>&1; \
	status=$$?; \
	if [ $$status -eq 0 ]; then \
		echo "❌ Step 5.1 unsafe function call guard failed: unsafe function call compiled outside unsafe but should reject."; \
		cat build/step51_unsafe_func_call_guard.log; \
		exit 1; \
	fi; \
	if ! rg -q "Unsafe function calls require an explicit 'unsafe' block" build/step51_unsafe_func_call_guard.log; then \
		echo "❌ Step 5.1 unsafe function call guard failed: rejection did not use the stable unsafe-call diagnostic."; \
		cat build/step51_unsafe_func_call_guard.log; \
		exit 1; \
	fi
	@echo "Checking unsafe function call inside unsafe accepts..."
	@./gust tests/e2e_unsafe_func_call_inside_unsafe.gst > build/step51_unsafe_func_call_guard.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 unsafe function call guard failed: unsafe function call inside unsafe should compile."; \
		cat build/step51_unsafe_func_call_guard.log; \
		exit 1; \
	fi
	@echo "Checking unsafe function bodies accept raw operations without nested unsafe..."
	@./gust tests/e2e_unsafe_func_body_raw_ops.gst > build/step51_unsafe_func_call_guard.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 unsafe function call guard failed: unsafe function body raw operations should compile."; \
		cat build/step51_unsafe_func_call_guard.log; \
		exit 1; \
	fi
	@echo "✅ Step 5.1 unsafe function call enforcement guard passed."

guard_step51_raw_pointer_local_escape_enforcement: gust
	@echo "🔒 Checking Step 5.1 raw pointer local escape analysis..."
	@mkdir -p build
	@echo "Checking raw-derived local pointer returns reject..."
	@./gust tests/test_raw_pointer_return_derived_local_rejected.gst > build/step51_raw_pointer_local_escape_guard.log 2>&1; \
	status=$$?; \
	if [ $$status -eq 0 ]; then \
		echo "❌ Step 5.1 raw pointer local escape guard failed: raw-derived local pointer return compiled but should reject."; \
		cat build/step51_raw_pointer_local_escape_guard.log; \
		exit 1; \
	fi; \
	if ! rg -q "Returning ephemeral view of type RawPointer" build/step51_raw_pointer_local_escape_guard.log; then \
		echo "❌ Step 5.1 raw pointer local escape guard failed: rejection did not use the stable raw-pointer escape diagnostic."; \
		cat build/step51_raw_pointer_local_escape_guard.log; \
		exit 1; \
	fi
	@echo "✅ Step 5.1 raw pointer local escape analysis guard passed."

guard_step51_extern_func_parser_metadata: gust
	@echo "🔒 Checking Step 5.1 extern function parser metadata..."
	@mkdir -p build
	@./gust compiler/parser_ffi_metadata_test_entry.gst > build/step51_extern_func_parser_metadata.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 extern parser metadata guard failed: compiler rejected the parser metadata fixture."; \
		cat build/step51_extern_func_parser_metadata.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_extern_func_parser_metadata.log > build/parser_ffi_metadata_test_entry.c
	@cat src/runtime.c build/parser_ffi_metadata_test_entry.c > build/parser_ffi_metadata_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/parser_ffi_metadata_test_entry_final.c -o build/parser_ffi_metadata_test_entry_bin
	@./build/parser_ffi_metadata_test_entry_bin >> build/step51_extern_func_parser_metadata.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 extern parser metadata guard failed at runtime."; \
		cat build/step51_extern_func_parser_metadata.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 extern function parser metadata guard passed."

guard_step51_extern_func_call_enforcement: gust
	@echo "🔒 Checking Step 5.1 extern function call enforcement..."
	@mkdir -p build
	@echo "Checking extern function call outside unsafe rejects..."
	@./gust tests/test_extern_func_call_outside_unsafe_rejected.gst > build/step51_extern_func_call_guard.log 2>&1; \
	status=$$?; \
	if [ $$status -eq 0 ]; then \
		echo "❌ Step 5.1 extern function call guard failed: extern call compiled outside unsafe but should reject."; \
		cat build/step51_extern_func_call_guard.log; \
		exit 1; \
	fi; \
	if ! rg -q "Direct external/native function calls require an explicit 'unsafe' block" build/step51_extern_func_call_guard.log; then \
		echo "❌ Step 5.1 extern function call guard failed: rejection did not use the stable extern-call diagnostic."; \
		cat build/step51_extern_func_call_guard.log; \
		exit 1; \
	fi
	@echo "Checking extern function call inside unsafe accepts..."
	@./gust tests/e2e_extern_func_call_inside_unsafe.gst > build/step51_extern_func_call_guard.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 extern function call guard failed: extern call inside unsafe should compile."; \
		cat build/step51_extern_func_call_guard.log; \
		exit 1; \
	fi
	@echo "✅ Step 5.1 extern function call enforcement guard passed."

guard_step51_layout_metadata_defaults: gust
	@echo "🔒 Checking Step 5.1 layout metadata defaults, parser attributes, and registry helpers..."
	@mkdir -p build
	@./gust compiler/parser_layout_metadata_test_entry.gst > build/step51_layout_metadata_defaults.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
					echo "❌ Step 5.1 layout metadata guard failed: compiler rejected the parser metadata fixture."; \
		cat build/step51_layout_metadata_defaults.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_layout_metadata_defaults.log > build/parser_layout_metadata_test_entry.c
	@cat src/runtime.c build/parser_layout_metadata_test_entry.c > build/parser_layout_metadata_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/parser_layout_metadata_test_entry_final.c -o build/parser_layout_metadata_test_entry_bin
	@./build/parser_layout_metadata_test_entry_bin >> build/step51_layout_metadata_defaults.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
					echo "❌ Step 5.1 layout metadata guard failed at runtime."; \
		cat build/step51_layout_metadata_defaults.log; \
		exit $$status; \
	fi
	@./gust compiler/typechecker_layout_metadata_test_entry.gst > build/step51_layout_metadata_registry.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
					echo "❌ Step 5.1 layout metadata guard failed: compiler rejected the registry helper fixture."; \
		cat build/step51_layout_metadata_registry.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_layout_metadata_registry.log > build/typechecker_layout_metadata_test_entry.c
	@cat src/runtime.c build/typechecker_layout_metadata_test_entry.c > build/typechecker_layout_metadata_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_layout_metadata_test_entry_final.c -o build/typechecker_layout_metadata_test_entry_bin
	@./build/typechecker_layout_metadata_test_entry_bin >> build/step51_layout_metadata_registry.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
					echo "❌ Step 5.1 layout metadata registry guard failed at runtime."; \
		cat build/step51_layout_metadata_registry.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 layout metadata defaults, parser attributes, and registry helpers guard passed."

guard_step51_layout_ffi_policy_helpers: gust
	@echo "🔒 Checking Step 5.1 layout-aware FFI helper predicates..."
	@mkdir -p build
	@./gust compiler/typechecker_layout_ffi_policy_test_entry.gst > build/step51_layout_ffi_policy_helpers.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 layout-aware FFI helper guard failed: compiler rejected the layout FFI helper fixture."; \
		cat build/step51_layout_ffi_policy_helpers.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_layout_ffi_policy_helpers.log > build/typechecker_layout_ffi_policy_test_entry.c
	@cat src/runtime.c build/typechecker_layout_ffi_policy_test_entry.c > build/typechecker_layout_ffi_policy_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_layout_ffi_policy_test_entry_final.c -o build/typechecker_layout_ffi_policy_test_entry_bin
	@./build/typechecker_layout_ffi_policy_test_entry_bin >> build/step51_layout_ffi_policy_helpers.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 layout-aware FFI helper guard failed at runtime."; \
		cat build/step51_layout_ffi_policy_helpers.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 layout-aware FFI helper predicates guard passed."

guard_step51_layout_ffi_signature_helpers: gust
	@echo "🔒 Checking Step 5.1 signature-level C FFI layout helpers..."
	@mkdir -p build
	@./gust compiler/typechecker_layout_ffi_signature_test_entry.gst > build/step51_layout_ffi_signature_helpers.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 signature-level C FFI layout guard failed: compiler rejected the signature helper fixture."; \
		cat build/step51_layout_ffi_signature_helpers.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_layout_ffi_signature_helpers.log > build/typechecker_layout_ffi_signature_test_entry.c
	@cat src/runtime.c build/typechecker_layout_ffi_signature_test_entry.c > build/typechecker_layout_ffi_signature_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_layout_ffi_signature_test_entry_final.c -o build/typechecker_layout_ffi_signature_test_entry_bin
	@./build/typechecker_layout_ffi_signature_test_entry_bin >> build/step51_layout_ffi_signature_helpers.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 signature-level C FFI layout guard failed at runtime."; \
		cat build/step51_layout_ffi_signature_helpers.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 signature-level C FFI layout helpers guard passed."

guard_step51_sandbox_policy_defaults: gust
	@echo "🔒 Checking Step 5.1 sandbox FFI policy defaults..."
	@mkdir -p build
	@./gust compiler/typechecker_sandbox_policy_test_entry.gst > build/step51_sandbox_policy_defaults.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 sandbox policy guard failed: compiler rejected the sandbox policy fixture."; \
		cat build/step51_sandbox_policy_defaults.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_sandbox_policy_defaults.log > build/typechecker_sandbox_policy_test_entry.c
	@cat src/runtime.c build/typechecker_sandbox_policy_test_entry.c > build/typechecker_sandbox_policy_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_sandbox_policy_test_entry_final.c -o build/typechecker_sandbox_policy_test_entry_bin
	@./build/typechecker_sandbox_policy_test_entry_bin >> build/step51_sandbox_policy_defaults.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 sandbox policy guard failed at runtime."; \
		cat build/step51_sandbox_policy_defaults.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 sandbox FFI policy defaults guard passed."

guard_step51_address_origin_metadata: gust
	@echo "🔒 Checking Step 5.1 address-origin metadata helpers..."
	@mkdir -p build
	@./gust compiler/typechecker_address_origin_test_entry.gst > build/step51_address_origin_metadata.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 address-origin metadata guard failed: compiler rejected the address-origin fixture."; \
		cat build/step51_address_origin_metadata.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_address_origin_metadata.log > build/typechecker_address_origin_test_entry.c
	@cat src/runtime.c build/typechecker_address_origin_test_entry.c > build/typechecker_address_origin_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_address_origin_test_entry_final.c -o build/typechecker_address_origin_test_entry_bin
	@./build/typechecker_address_origin_test_entry_bin >> build/step51_address_origin_metadata.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 address-origin metadata guard failed at runtime."; \
		cat build/step51_address_origin_metadata.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 address-origin metadata helpers guard passed."

guard_step51_expression_provenance_carrier: gust
	@echo "🔒 Checking Step 5.1 expression provenance carrier helpers..."
	@mkdir -p build
	@./gust compiler/typechecker_expression_provenance_test_entry.gst > build/step51_expression_provenance_carrier.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 expression provenance carrier guard failed: compiler rejected the fixture."; \
		cat build/step51_expression_provenance_carrier.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_expression_provenance_carrier.log > build/typechecker_expression_provenance_test_entry.c
	@cat src/runtime.c build/typechecker_expression_provenance_test_entry.c > build/typechecker_expression_provenance_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_expression_provenance_test_entry_final.c -o build/typechecker_expression_provenance_test_entry_bin
	@./build/typechecker_expression_provenance_test_entry_bin >> build/step51_expression_provenance_carrier.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 expression provenance carrier guard failed at runtime."; \
		cat build/step51_expression_provenance_carrier.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 expression provenance carrier helpers guard passed."

guard_step51_safe_constructor_provenance: gust
	@echo "🔒 Checking Step 5.1 safe constructor provenance metadata..."
	@mkdir -p build
	@./gust compiler/typechecker_safe_constructor_provenance_test_entry.gst > build/step51_safe_constructor_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 safe constructor provenance guard failed: compiler rejected the fixture."; \
		cat build/step51_safe_constructor_provenance.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_safe_constructor_provenance.log > build/typechecker_safe_constructor_provenance_test_entry.c
	@cat src/runtime.c build/typechecker_safe_constructor_provenance_test_entry.c > build/typechecker_safe_constructor_provenance_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_safe_constructor_provenance_test_entry_final.c -o build/typechecker_safe_constructor_provenance_test_entry_bin
	@./build/typechecker_safe_constructor_provenance_test_entry_bin >> build/step51_safe_constructor_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 safe constructor provenance guard failed at runtime."; \
		cat build/step51_safe_constructor_provenance.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 safe constructor provenance metadata guard passed."

guard_step51_selector_safe_constructor_provenance: gust
	@echo "🔒 Checking Step 5.1 selector safe constructor provenance metadata..."
	@mkdir -p build
	@./gust compiler/typechecker_selector_safe_constructor_provenance_test_entry.gst > build/step51_selector_safe_constructor_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 selector safe constructor provenance guard failed: compiler rejected the fixture."; \
		cat build/step51_selector_safe_constructor_provenance.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_selector_safe_constructor_provenance.log > build/typechecker_selector_safe_constructor_provenance_test_entry.c
	@cat src/runtime.c build/typechecker_selector_safe_constructor_provenance_test_entry.c > build/typechecker_selector_safe_constructor_provenance_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_selector_safe_constructor_provenance_test_entry_final.c -o build/typechecker_selector_safe_constructor_provenance_test_entry_bin
	@./build/typechecker_selector_safe_constructor_provenance_test_entry_bin >> build/step51_selector_safe_constructor_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 selector safe constructor provenance guard failed at runtime."; \
		cat build/step51_selector_safe_constructor_provenance.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 selector safe constructor provenance metadata guard passed."

guard_step51_container_safe_constructor_provenance: gust
	@echo "🔒 Checking Step 5.1 container safe constructor provenance metadata..."
	@mkdir -p build
	@./gust compiler/typechecker_container_safe_constructor_provenance_test_entry.gst > build/step51_container_safe_constructor_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 container safe constructor provenance guard failed: compiler rejected the fixture."; \
		cat build/step51_container_safe_constructor_provenance.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_container_safe_constructor_provenance.log > build/typechecker_container_safe_constructor_provenance_test_entry.c
	@cat src/runtime.c build/typechecker_container_safe_constructor_provenance_test_entry.c > build/typechecker_container_safe_constructor_provenance_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_container_safe_constructor_provenance_test_entry_final.c -o build/typechecker_container_safe_constructor_provenance_test_entry_bin
	@./build/typechecker_container_safe_constructor_provenance_test_entry_bin >> build/step51_container_safe_constructor_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 container safe constructor provenance guard failed at runtime."; \
		cat build/step51_container_safe_constructor_provenance.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 container safe constructor provenance metadata guard passed."

guard_step51_container_method_provenance: gust
	@echo "🔒 Checking Step 5.1 container method write provenance metadata..."
	@mkdir -p build
	@./gust compiler/typechecker_container_method_provenance_test_entry.gst > build/step51_container_method_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 container method provenance guard failed: compiler rejected the fixture."; \
		cat build/step51_container_method_provenance.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_container_method_provenance.log > build/typechecker_container_method_provenance_test_entry.c
	@cat src/runtime.c build/typechecker_container_method_provenance_test_entry.c > build/typechecker_container_method_provenance_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_container_method_provenance_test_entry_final.c -o build/typechecker_container_method_provenance_test_entry_bin
	@./build/typechecker_container_method_provenance_test_entry_bin >> build/step51_container_method_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 container method provenance guard failed at runtime."; \
		cat build/step51_container_method_provenance.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 container method write provenance metadata guard passed."

guard_step51_variable_provenance_bindings: gust
	@echo "🔒 Checking Step 5.1 variable provenance binding/assignment/readback metadata..."
	@mkdir -p build
	@./gust compiler/typechecker_variable_provenance_test_entry.gst > build/step51_variable_provenance_bindings.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 variable provenance binding guard failed: compiler rejected the fixture."; \
		cat build/step51_variable_provenance_bindings.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_variable_provenance_bindings.log > build/typechecker_variable_provenance_test_entry.c
	@cat src/runtime.c build/typechecker_variable_provenance_test_entry.c > build/typechecker_variable_provenance_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_variable_provenance_test_entry_final.c -o build/typechecker_variable_provenance_test_entry_bin
	@./build/typechecker_variable_provenance_test_entry_bin >> build/step51_variable_provenance_bindings.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 variable provenance binding guard failed at runtime."; \
		cat build/step51_variable_provenance_bindings.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 variable provenance binding/assignment/readback metadata guard passed."

guard_step51_return_provenance_capture: gust
	@echo "🔒 Checking Step 5.1 inert return expression provenance capture..."
	@mkdir -p build
	@./gust compiler/typechecker_return_provenance_test_entry.gst > build/step51_return_provenance_capture.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 return provenance guard failed: compiler rejected the fixture."; \
		cat build/step51_return_provenance_capture.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_return_provenance_capture.log > build/typechecker_return_provenance_test_entry.c
	@cat src/runtime.c build/typechecker_return_provenance_test_entry.c > build/typechecker_return_provenance_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_return_provenance_test_entry_final.c -o build/typechecker_return_provenance_test_entry_bin
	@./build/typechecker_return_provenance_test_entry_bin >> build/step51_return_provenance_capture.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 return provenance guard failed at runtime."; \
		cat build/step51_return_provenance_capture.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 inert return expression provenance capture guard passed."

guard_step51_function_call_provenance: gust
	@echo "🔒 Checking Step 5.1 inert function-call return provenance metadata..."
	@mkdir -p build
	@./gust compiler/typechecker_function_call_provenance_test_entry.gst > build/step51_function_call_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 function-call provenance guard failed: compiler rejected the fixture."; \
		cat build/step51_function_call_provenance.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_function_call_provenance.log > build/typechecker_function_call_provenance_test_entry.c
	@cat src/runtime.c build/typechecker_function_call_provenance_test_entry.c > build/typechecker_function_call_provenance_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_function_call_provenance_test_entry_final.c -o build/typechecker_function_call_provenance_test_entry_bin
	@./build/typechecker_function_call_provenance_test_entry_bin >> build/step51_function_call_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 function-call provenance guard failed at runtime."; \
		cat build/step51_function_call_provenance.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 inert function-call return provenance metadata guard passed."

guard_step51_aggregate_field_provenance: gust
	@echo "🔒 Checking Step 5.1 inert aggregate-field provenance metadata..."
	@mkdir -p build
	@./gust compiler/typechecker_aggregate_field_provenance_test_entry.gst > build/step51_aggregate_field_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 aggregate-field provenance guard failed: compiler rejected the fixture."; \
		cat build/step51_aggregate_field_provenance.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_aggregate_field_provenance.log > build/typechecker_aggregate_field_provenance_test_entry.c
	@cat src/runtime.c build/typechecker_aggregate_field_provenance_test_entry.c > build/typechecker_aggregate_field_provenance_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_aggregate_field_provenance_test_entry_final.c -o build/typechecker_aggregate_field_provenance_test_entry_bin
	@./build/typechecker_aggregate_field_provenance_test_entry_bin >> build/step51_aggregate_field_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 aggregate-field provenance guard failed at runtime."; \
		cat build/step51_aggregate_field_provenance.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 inert aggregate-field provenance metadata guard passed."

guard_step51_container_provenance: gust
	@echo "🔒 Checking Step 5.1 inert container provenance metadata..."
	@mkdir -p build
	@./gust compiler/typechecker_container_provenance_test_entry.gst > build/step51_container_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 container provenance guard failed: compiler rejected the fixture."; \
		cat build/step51_container_provenance.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_container_provenance.log > build/typechecker_container_provenance_test_entry.c
	@cat src/runtime.c build/typechecker_container_provenance_test_entry.c > build/typechecker_container_provenance_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_container_provenance_test_entry_final.c -o build/typechecker_container_provenance_test_entry_bin
	@./build/typechecker_container_provenance_test_entry_bin >> build/step51_container_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 container provenance guard failed at runtime."; \
		cat build/step51_container_provenance.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 inert container provenance metadata guard passed."

guard_step51_non_laundering_return_enforcement: gust
	@echo "🔒 Checking Step 5.1 non-laundering safe-branded return enforcement..."
	@mkdir -p build
	@./gust compiler/typechecker_non_laundering_return_test_entry.gst > build/step51_non_laundering_return.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 non-laundering return guard failed: compiler rejected the fixture."; \
		cat build/step51_non_laundering_return.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_non_laundering_return.log > build/typechecker_non_laundering_return_test_entry.c
	@cat src/runtime.c build/typechecker_non_laundering_return_test_entry.c > build/typechecker_non_laundering_return_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_non_laundering_return_test_entry_final.c -o build/typechecker_non_laundering_return_test_entry_bin
	@./build/typechecker_non_laundering_return_test_entry_bin >> build/step51_non_laundering_return.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 non-laundering return guard failed at runtime."; \
		cat build/step51_non_laundering_return.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 non-laundering safe-branded return enforcement guard passed."

guard_step51_non_laundering_binding_enforcement: gust
	@echo "🔒 Checking Step 5.1 non-laundering safe-branded binding/assignment enforcement..."
	@mkdir -p build
	@./gust compiler/typechecker_non_laundering_binding_test_entry.gst > build/step51_non_laundering_binding.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 non-laundering binding guard failed: compiler rejected the fixture."; \
		cat build/step51_non_laundering_binding.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_non_laundering_binding.log > build/typechecker_non_laundering_binding_test_entry.c
	@cat src/runtime.c build/typechecker_non_laundering_binding_test_entry.c > build/typechecker_non_laundering_binding_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_non_laundering_binding_test_entry_final.c -o build/typechecker_non_laundering_binding_test_entry_bin
	@./build/typechecker_non_laundering_binding_test_entry_bin >> build/step51_non_laundering_binding.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 non-laundering binding guard failed at runtime."; \
		cat build/step51_non_laundering_binding.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 non-laundering safe-branded binding/assignment enforcement guard passed."

guard_step51_non_laundering_call_enforcement: gust
	@echo "🔒 Checking Step 5.1 non-laundering safe-branded call-argument enforcement..."
	@mkdir -p build
	@./gust compiler/typechecker_non_laundering_call_test_entry.gst > build/step51_non_laundering_call.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 non-laundering call guard failed: compiler rejected the fixture."; \
		cat build/step51_non_laundering_call.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_non_laundering_call.log > build/typechecker_non_laundering_call_test_entry.c
	@cat src/runtime.c build/typechecker_non_laundering_call_test_entry.c > build/typechecker_non_laundering_call_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_non_laundering_call_test_entry_final.c -o build/typechecker_non_laundering_call_test_entry_bin
	@./build/typechecker_non_laundering_call_test_entry_bin >> build/step51_non_laundering_call.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 non-laundering call guard failed at runtime."; \
		cat build/step51_non_laundering_call.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 non-laundering safe-branded call-argument enforcement guard passed."

guard_step51_non_laundering_field_enforcement: gust
	@echo "🔒 Checking Step 5.1 non-laundering safe-branded aggregate-field enforcement..."
	@mkdir -p build
	@./gust compiler/typechecker_non_laundering_field_test_entry.gst > build/step51_non_laundering_field.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 non-laundering field guard failed: compiler rejected the fixture."; \
		cat build/step51_non_laundering_field.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_non_laundering_field.log > build/typechecker_non_laundering_field_test_entry.c
	@cat src/runtime.c build/typechecker_non_laundering_field_test_entry.c > build/typechecker_non_laundering_field_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_non_laundering_field_test_entry_final.c -o build/typechecker_non_laundering_field_test_entry_bin
	@./build/typechecker_non_laundering_field_test_entry_bin >> build/step51_non_laundering_field.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 non-laundering field guard failed at runtime."; \
		cat build/step51_non_laundering_field.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 non-laundering safe-branded aggregate-field enforcement guard passed."

guard_step51_non_laundering_container_enforcement: gust
	@echo "🔒 Checking Step 5.1 non-laundering safe-branded container-element enforcement..."
	@mkdir -p build
	@./gust compiler/typechecker_non_laundering_container_test_entry.gst > build/step51_non_laundering_container.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 non-laundering container guard failed: compiler rejected the fixture."; \
		cat build/step51_non_laundering_container.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_non_laundering_container.log > build/typechecker_non_laundering_container_test_entry.c
	@cat src/runtime.c build/typechecker_non_laundering_container_test_entry.c > build/typechecker_non_laundering_container_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_non_laundering_container_test_entry_final.c -o build/typechecker_non_laundering_container_test_entry_bin
	@./build/typechecker_non_laundering_container_test_entry_bin >> build/step51_non_laundering_container.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 non-laundering container guard failed at runtime."; \
		cat build/step51_non_laundering_container.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 non-laundering safe-branded container-element enforcement guard passed."

guard_step51_non_laundering_container_method_enforcement: gust
	@echo "🔒 Checking Step 5.1 non-laundering safe-branded container method storage enforcement..."
	@mkdir -p build
	@./gust compiler/typechecker_non_laundering_container_method_test_entry.gst > build/step51_non_laundering_container_method.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 non-laundering container method guard failed: compiler rejected the fixture."; \
		cat build/step51_non_laundering_container_method.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_non_laundering_container_method.log > build/typechecker_non_laundering_container_method_test_entry.c
	@cat src/runtime.c build/typechecker_non_laundering_container_method_test_entry.c > build/typechecker_non_laundering_container_method_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_non_laundering_container_method_test_entry_final.c -o build/typechecker_non_laundering_container_method_test_entry_bin
	@./build/typechecker_non_laundering_container_method_test_entry_bin >> build/step51_non_laundering_container_method.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 non-laundering container method guard failed at runtime."; \
		cat build/step51_non_laundering_container_method.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 non-laundering safe-branded container method storage enforcement guard passed."

guard_step51_non_laundering_arena_write_enforcement: gust
	@echo "🔒 Checking Step 5.1 non-laundering safe-branded Arena.Set/Write enforcement..."
	@mkdir -p build
	@./gust compiler/typechecker_non_laundering_arena_write_test_entry.gst > build/step51_non_laundering_arena_write.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 non-laundering Arena.Set/Write guard failed: compiler rejected the fixture."; \
		cat build/step51_non_laundering_arena_write.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_non_laundering_arena_write.log > build/typechecker_non_laundering_arena_write_test_entry.c
	@cat src/runtime.c build/typechecker_non_laundering_arena_write_test_entry.c > build/typechecker_non_laundering_arena_write_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_non_laundering_arena_write_test_entry_final.c -o build/typechecker_non_laundering_arena_write_test_entry_bin
	@./build/typechecker_non_laundering_arena_write_test_entry_bin >> build/step51_non_laundering_arena_write.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 non-laundering Arena.Set/Write guard failed at runtime."; \
		cat build/step51_non_laundering_arena_write.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 non-laundering safe-branded Arena.Set/Write enforcement guard passed."

guard_step51_basic_unsafe_enforcement: guard_step51_raw_deref_unsafe_enforcement guard_step51_raw_cast_unsafe_enforcement guard_step51_pointer_arithmetic_unsafe_enforcement guard_step51_unsafe_func_call_enforcement guard_step51_raw_pointer_local_escape_enforcement
	@echo "✅ Step 5.1 basic unsafe enforcement aggregate passed."

guard_step44_low_risk_entry_raw_casts:
	@echo "🔒 Checking Step 4.4 migrated low-risk entry files for high-level raw collection/string casts..."
	@STEP44_LOW_RISK_FILES="compiler/type_dump_entry.gst compiler/test_runner_entry.gst compiler/parser_reference_access_test_entry.gst"; \
	if rg -n '&ctx\[' $$STEP44_LOW_RISK_FILES | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 low-risk entry guard failed: migrated entry files must not reintroduce direct arena collection/string casts."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 low-risk entry guard passed."; \
	fi

guard_step44_typechecker_aux_raw_casts:
	@echo "🔒 Checking Step 4.4 migrated typechecker auxiliary test entries for high-level raw collection/string casts..."
	@STEP44_TYPECHECKER_AUX_FILES="compiler/typechecker_templates_test_entry.gst compiler/typechecker_origins_test_entry.gst"; \
	if rg -n '&ctx\[' $$STEP44_TYPECHECKER_AUX_FILES | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 typechecker auxiliary guard failed: migrated test entries must not reintroduce direct arena collection/string casts."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 typechecker auxiliary guard passed."; \
	fi

guard_step44_typechecker_types_raw_casts:
	@echo "🔒 Checking Step 4.4 migrated typechecker types test entry for high-level raw collection/string casts..."
	@if rg -n '&ctx\[' compiler/typechecker_types_test_entry.gst | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 typechecker types guard failed: migrated test entry must not reintroduce direct arena collection/string casts."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 typechecker types guard passed."; \
	fi

guard_step44_codegen_initializer_raw_casts:
	@echo "🔒 Checking Step 4.4 migrated codegen initializer test entry for high-level raw collection/string casts..."
	@if rg -n '&ctx\[' compiler/codegen_initializer_test_entry.gst | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 codegen initializer guard failed: migrated test entry must not reintroduce direct arena collection/string casts."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 codegen initializer guard passed."; \
	fi

guard_step44_typechecker_early_raw_casts:
	@echo "🔒 Checking Step 4.4 migrated early typechecker slice for high-level raw collection/string casts..."
	@if sed -n '1,460p' compiler/typechecker.gst | rg '&ctx\[' | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 early typechecker guard failed: migrated early slice must not reintroduce direct arena collection/string casts."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 early typechecker guard passed."; \
	fi

guard_step44_typechecker_methods_raw_casts:
	@echo "🔒 Checking Step 4.4 migrated typechecker method-receiver slice for high-level raw collection/string casts..."
	@if sed -n '1030,1468p' compiler/typechecker.gst | rg '&ctx\[' | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 typechecker method guard failed: migrated method-receiver slice must not reintroduce direct arena collection/string casts."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 typechecker method guard passed."; \
	fi

guard_step44_typechecker_pool_graph_raw_casts:
	@echo "🔒 Checking Step 4.4 migrated typechecker Pool/Graph/top-level builtin slice for high-level raw collection/string casts..."
	@if sed -n '1469,1899p' compiler/typechecker.gst | rg '&ctx\[' | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 typechecker Pool/Graph guard failed: migrated slice must not reintroduce direct arena collection/string casts."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 typechecker Pool/Graph guard passed."; \
	fi

guard_step44_typechecker_call_validation_raw_casts:
	@echo "🔒 Checking Step 4.4 migrated typechecker call-validation slice for high-level raw collection/string casts..."
	@if sed -n '1900,2350p' compiler/typechecker.gst | rg '&ctx\[' | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 typechecker call-validation guard failed: migrated slice must not reintroduce direct arena collection/string casts."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 typechecker call-validation guard passed."; \
	fi

guard_step44_typechecker_generic_helpers_raw_casts:
	@echo "🔒 Checking Step 4.4 migrated typechecker generic-helper slice for high-level raw collection/string casts..."
	@if sed -n '2546,3196p' compiler/typechecker.gst | rg '&ctx\[' | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 typechecker generic-helper guard failed: migrated slice must not reintroduce direct arena collection/string casts."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 typechecker generic-helper guard passed."; \
	fi

guard_step44_typechecker_template_registration_raw_casts:
	@echo "🔒 Checking Step 4.4 migrated typechecker template-registration slice for high-level raw collection/string casts..."
	@if sed -n '3197,3524p' compiler/typechecker.gst | rg '&ctx\[' | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 typechecker template-registration guard failed: migrated slice must not reintroduce direct arena collection/string casts."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 typechecker template-registration guard passed."; \
	fi

guard_step44_typechecker_env_registration_raw_casts:
	@echo "🔒 Checking Step 4.4 migrated typechecker env-resolve/pre-registration slice for high-level raw collection/string casts..."
	@if sed -n '4363,4824p' compiler/typechecker.gst | rg '&ctx\[' | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 typechecker env-registration guard failed: migrated slice must not reintroduce direct arena collection/string casts."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 typechecker env-registration guard passed."; \
	fi

guard_step44_typechecker_brand_helpers_raw_casts:
	@echo "🔒 Checking Step 4.4 migrated typechecker block/string/brand helper slice for high-level raw collection/string casts..."
	@if sed -n '5000,5530p' compiler/typechecker.gst | rg '&ctx\[' | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 typechecker brand-helper guard failed: migrated slice must not reintroduce direct arena collection/string casts."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 typechecker brand-helper guard passed."; \
	fi

guard_step44_typechecker_function_checks_raw_casts:
	@echo "🔒 Checking Step 4.4 migrated typechecker function-check slice for high-level raw collection/string casts..."
	@if sed -n '5780,6005p' compiler/typechecker.gst | rg '&ctx\[' | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 typechecker function-check guard failed: migrated slice must not reintroduce direct arena collection/string casts."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 typechecker function-check guard passed."; \
	fi

guard_step44_typechecker_statement_traversal_raw_casts:
	@echo "🔒 Checking Step 4.4 migrated typechecker statement-traversal slice for high-level raw collection/string casts..."
	@if sed -n '6460,6990p' compiler/typechecker.gst | rg '&ctx\[' | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 typechecker statement-traversal guard failed: migrated slice must not reintroduce direct arena collection/string casts."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 typechecker statement-traversal guard passed."; \
	fi

guard_step44_codegen_early_helpers_raw_casts:
	@echo "🔒 Checking Step 4.4 migrated early codegen helper slice for high-level raw collection/string casts..."
	@if sed -n '120,1425p' compiler/codegen.gst | rg '&ctx\[' | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 codegen early-helper guard failed: migrated slice must not reintroduce direct arena collection/string casts."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 codegen early-helper guard passed."; \
	fi

guard_step44_codegen_dispatch_methods_raw_casts:
	@echo "🔒 Checking Step 4.4 migrated codegen method-dispatch slice for high-level raw collection/string casts..."
	@if sed -n '2175,2609p' compiler/codegen.gst | rg '&ctx\[' | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 codegen method-dispatch guard failed: migrated slice must not reintroduce direct arena collection/string casts."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 codegen method-dispatch guard passed."; \
	fi

guard_step44_codegen_pool_graph_std_raw_casts:
	@echo "🔒 Checking Step 4.4 migrated codegen Pool/Graph/std helper slice for high-level raw collection/string casts..."
	@if sed -n '2610,2988p' compiler/codegen.gst | rg '&ctx\[' | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 codegen Pool/Graph/std guard failed: migrated slice must not reintroduce direct arena collection/string casts."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 codegen Pool/Graph/std guard passed."; \
	fi

guard_step44_codegen_std_alloc_helpers_raw_casts:
	@echo "🔒 Checking Step 4.4 migrated codegen std/allocation helper slice for high-level raw collection/string casts..."
	@if sed -n '2989,3444p' compiler/codegen.gst | rg '&ctx\[' | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 codegen std/allocation helper guard failed: migrated slice must not reintroduce direct arena collection/string casts."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 codegen std/allocation helper guard passed."; \
	fi

guard_step44_codegen_runtime_tail_raw_casts:
	@echo "🔒 Checking Step 4.4 migrated codegen runtime-helper tail slice for high-level raw collection/string casts..."
	@if sed -n '3445,3772p' compiler/codegen.gst | rg '&ctx\[' | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 codegen runtime-helper tail guard failed: migrated slice must not reintroduce direct arena collection/string casts."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 codegen runtime-helper tail guard passed."; \
	fi

guard_step44_codegen_statement_emit_raw_casts:
	@echo "🔒 Checking Step 4.4 migrated codegen statement-emission slice for high-level raw collection/string casts..."
	@if sed -n '3773,4271p' compiler/codegen.gst | rg '&ctx\[' | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 codegen statement-emission guard failed: migrated slice must not reintroduce direct arena collection/string casts."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 codegen statement-emission guard passed."; \
	fi

guard_step44_codegen_program_passes_raw_casts:
	@echo "🔒 Checking Step 4.4 migrated codegen program-level passes for high-level raw collection/string casts..."
	@if sed -n '4720,4865p' compiler/codegen.gst | rg '&ctx\[' | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 codegen program-level guard failed: migrated slice must not reintroduce direct arena collection/string casts."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 codegen program-level guard passed."; \
	fi

guard_step44_no_high_level_raw_collection_casts:
	@echo "🔒 Checking Step 4.4 whole-compiler high-level raw collection/string cast migration..."
	@if rg -n '&ctx\[' compiler/*.gst | rg ' as \*(std\.Vector|std\.HashMap|str)'; then \
		echo "❌ Step 4.4 whole-compiler guard failed: direct arena collection/string casts must not be reintroduced."; \
		exit 1; \
	else \
		echo "✅ Step 4.4 whole-compiler high-level raw collection/string cast guard passed."; \
	fi

guard_parser_high_level_raw_casts:
	@echo "🔒 Checking parser raw casts are limited to lexer/token compatibility shims..."
	@if rg -n '&ctx\[' compiler/parser.gst; then \
		echo "❌ Parser guard failed: compiler/parser.gst must not use direct &ctx[...] arena casts."; \
		exit 1; \
	fi
	@if rg -n ' as \*' compiler/parser.gst | rg -v 'lexer\.Lexer|token\.Token'; then \
		echo "❌ Parser guard failed: compiler/parser.gst has a non-compat raw pointer cast."; \
		echo "   Only lexer/token compatibility casts should remain in parser.gst after Step 6B."; \
		exit 1; \
	else \
		echo "✅ Parser guard passed: only lexer/token compatibility casts remain."; \
	fi

clean:
	rm -rf gust_bootstrap gust build/

install: gust
	mkdir -p ${PREFIX}/bin
	cp gust ${PREFIX}/bin/gust
