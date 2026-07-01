CC = cc
CFLAGS = -O2 -Wall -pthread
INCLUDES = -Isrc
PREFIX = /usr/local

# Force make to use bash with pipefail to prevent silent pipeline errors
SHELL = bash
.SHELLFLAGS = -o pipefail -c

# Keep Make's explicit phony surface small. The Makefile remains the canonical
# build graph for core aggregate commands; focused guard/report discovery lives
# in justfile and concrete recipe names below rather than in a giant .PHONY list.
.PHONY: all clean test bootstrap install test_tree_sitter require_just

require_just:
	@command -v just >/dev/null 2>&1 || { echo "❌ just is required for focused Make guards. Run nix develop or install just."; exit 1; }

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

## just "make" doesnt do anything need to run "make gust"
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

test: gust require_just
	@CC="${CC}" CFLAGS="${CFLAGS}" INCLUDES="${INCLUDES}" just make-test-suite

test_tree_sitter:
	@echo "🔍 Running Tree-sitter corpus tests..."
	cd tree-sitter-gust && tree-sitter test
	@echo "🔍 Validating all Gust files parse with zero errors (including explicit reference-access tests)..."
	@for f in compiler/*.gst tests/*.gst; do \
		echo "Parsing $$f..."; \
		(cd tree-sitter-gust && tree-sitter parse ../$$f --quiet) || exit 1; \
	done
	@echo "✅ Tree-sitter parsing validation passed!"

JUST_REPORT_TARGETS = \
        report_phase4_formatter_tools \
        report_step51_raw_pointer_deref \
        report_step51_raw_pointer_casts \
        report_step51_address_escapes_focused \
        report_step51_ffi_calls \
        report_step51_ffi_focused \
        report_step51_unsafe_func_signatures \
        report_step51_raw_pointer_classified \
        report_step51_raw_pointer_safe_code_candidates \
        report_step51_phase_b_wrapping_status \
        report_step51_phase_c_basic_unsafe_status \
        report_step51_phase_d_ffi_status \
        report_step51_phase_e_address_escape_status \
        report_step51_phase_f_non_laundering_status \
        report_step51_deferred_unsafe_semantics_status \
        report_step51_status_matrix \
        report_step51_raw_pointer_safety_inventory \
        report_step51_final_validation \
        report_step52_linear_resource_inventory \
        report_step52_linear_resource_focused \
        report_step52_phase_a_status \
        report_step52_phase_b_destructor_status \
        report_step52_phase_c_resource_registry_status \
        report_step52_phase_d_transfer_status \
        report_step52_phase_e_enforcement_preconditions_status \
        report_step52_phase_f_closure_status \
        report_step52_status_matrix \
        report_step52_final_validation \
        report_step44_accessor_contract \
        report_step45_accessor_contract \
        report_step45_final_validation \
        report_compiler_get_opt_migration \
        report_high_level_raw_collection_casts \
        report_step45_subscript_lvalue_writes \
        report_step45_test_subscript_lvalue_writes \
        report_step45_subscript_lvalue_classified

$(JUST_REPORT_TARGETS): require_just
	@just $@

JUST_STEP51_GUARD_TARGETS = \
	guard_step51_report_only_lanes_not_in_test \
	guard_step51_raw_deref_unsafe_enforcement \
	guard_step51_raw_cast_unsafe_enforcement \
	guard_step51_pointer_arithmetic_unsafe_enforcement \
	guard_step51_unsafe_func_call_enforcement \
	guard_step51_raw_pointer_local_escape_enforcement \
	guard_step51_extern_func_parser_metadata \
	guard_step51_extern_func_call_enforcement \
	guard_step51_layout_metadata_defaults \
	guard_step51_layout_ffi_policy_helpers \
	guard_step51_layout_ffi_signature_helpers \
	guard_step51_sandbox_policy_defaults \
	guard_step51_address_origin_metadata \
	guard_step51_expression_provenance_carrier \
	guard_step51_safe_constructor_provenance \
	guard_step51_selector_safe_constructor_provenance \
	guard_step51_container_safe_constructor_provenance \
	guard_step51_container_method_provenance \
	guard_step51_arena_write_provenance \
	guard_step51_container_getref_provenance \
	guard_step51_hashmap_get_value_provenance \
	guard_step51_hashmap_get_value_field_provenance \
	guard_step51_std_vector_getref_provenance \
	guard_step51_std_hashmap_getref_provenance \
	guard_step51_std_hashmap_getref_selector_alias_provenance \
	guard_step51_std_vector_getref_selector_alias_provenance \
	guard_step51_reference_selector_alias_provenance \
	guard_step51_variable_provenance_bindings \
	guard_step51_return_provenance_capture \
	guard_step51_function_call_provenance \
	guard_step51_aggregate_field_provenance \
	guard_step51_container_provenance \
	guard_step51_non_laundering_return_enforcement \
	guard_step51_non_laundering_binding_enforcement \
	guard_step51_non_laundering_call_enforcement \
	guard_step51_non_laundering_field_enforcement \
	guard_step51_non_laundering_container_enforcement \
	guard_step51_non_laundering_container_method_enforcement \
	guard_step51_non_laundering_arena_write_enforcement \
	guard_step51_non_laundering_reference_selector_enforcement \
	guard_step51_non_laundering_hashmap_get_value_enforcement \
	guard_step51_non_laundering_hashmap_get_value_field_enforcement \
	guard_step51_basic_unsafe_enforcement

$(JUST_STEP51_GUARD_TARGETS): gust require_just
	@just $@

guard_step52_report_only_lanes_not_in_test:
	@echo "🔒 Guarding Step 5.2 report-only lanes are not direct just make-test-guards dependencies..."
	@test_deps="$$(awk 'capture == 1 && /^make-test-suite:/ { exit } /^make-test-guards:/ { capture = 1 } capture == 1 { print }' justfile)"; \
	if echo "$$test_deps" | grep -q 'report_step52_'; then \
	        echo "❌ Step 5.2 report-only target is wired into just make-test-guards:"; \
	        echo "$$test_deps"; \
	        exit 1; \
	fi
	@echo "✅ Step 5.2 report-only lanes are not direct just make-test-guards dependencies."

guard_step52_no_post_closure_report_churn:
	@echo "🔒 Guarding Step 5.2 report-only closure against new report target churn..."
	@allowed_reports='^(report_step52_linear_resource_inventory|report_step52_linear_resource_focused|report_step52_phase_a_status|report_step52_phase_b_destructor_status|report_step52_phase_c_resource_registry_status|report_step52_phase_d_transfer_status|report_step52_phase_e_enforcement_preconditions_status|report_step52_phase_f_closure_status|report_step52_status_matrix|report_step52_final_validation):$$'; \
	extra_reports="$$(grep -E '^report_step52_.*:' justfile-reports | grep -Ev "$$allowed_reports" || true)"; \
	if [ -n "$$extra_reports" ]; then \
	        echo "❌ Unexpected post-closure Step 5.2 report target(s):"; \
	        echo "$$extra_reports"; \
	        echo "Step 5.2F closed textual report churn; move to AST/typechecker design or update this whitelist intentionally."; \
	        exit 1; \
	fi
	@echo "✅ Step 5.2 report-only closure whitelist is unchanged."

JUST_STEP45_GUARD_TARGETS = \
	guard_step45_safe_subscript_write_enforcement

$(JUST_STEP45_GUARD_TARGETS): gust require_just
	@just $@

JUST_GUARD_TARGETS = \
	guard_step44_low_risk_entry_raw_casts \
	guard_step44_typechecker_aux_raw_casts \
	guard_step44_typechecker_types_raw_casts \
	guard_step44_codegen_initializer_raw_casts \
	guard_step44_typechecker_early_raw_casts \
	guard_step44_typechecker_methods_raw_casts \
	guard_step44_typechecker_pool_graph_raw_casts \
	guard_step44_typechecker_call_validation_raw_casts \
	guard_step44_typechecker_generic_helpers_raw_casts \
	guard_step44_typechecker_template_registration_raw_casts \
	guard_step44_typechecker_env_registration_raw_casts \
	guard_step44_typechecker_brand_helpers_raw_casts \
	guard_step44_typechecker_function_checks_raw_casts \
	guard_step44_typechecker_statement_traversal_raw_casts \
	guard_step44_codegen_early_helpers_raw_casts \
	guard_step44_codegen_dispatch_methods_raw_casts \
	guard_step44_codegen_pool_graph_std_raw_casts \
	guard_step44_codegen_std_alloc_helpers_raw_casts \
	guard_step44_codegen_runtime_tail_raw_casts \
	guard_step44_codegen_statement_emit_raw_casts \
	guard_step44_codegen_program_passes_raw_casts \
	guard_step44_no_high_level_raw_collection_casts \
	guard_parser_high_level_raw_casts

$(JUST_GUARD_TARGETS): require_just
	@just $@

clean:
	rm -rf gust_bootstrap gust build/

install: gust
	mkdir -p ${PREFIX}/bin
	cp gust ${PREFIX}/bin/gust
