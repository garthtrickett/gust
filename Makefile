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

guard_step51_report_only_lanes_not_in_test:
        @echo "🔒 Guarding Step 5.1 report-only lanes are not direct just make-test-guards dependencies..."
        @test_deps="$$(awk 'capture == 1 && /^make-test-suite:/ { exit } /^make-test-guards:/ { capture = 1 } capture == 1 { print }' justfile)"; \
        if echo "$$test_deps" | grep -q 'report_step51_'; then \
                echo "❌ Step 5.1 report-only target is wired into just make-test-guards:"; \
                echo "$$test_deps"; \
                exit 1; \
        fi
        @echo "✅ Step 5.1 report-only lanes are not direct just make-test-guards dependencies."

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

guard_step51_arena_write_provenance: gust
	@echo "🔒 Checking Step 5.1 Arena.Set/Write provenance metadata..."
	@mkdir -p build
	@./gust compiler/typechecker_arena_write_provenance_test_entry.gst > build/step51_arena_write_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 Arena.Set/Write provenance guard failed: compiler rejected the fixture."; \
		cat build/step51_arena_write_provenance.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_arena_write_provenance.log > build/typechecker_arena_write_provenance_test_entry.c
	@cat src/runtime.c build/typechecker_arena_write_provenance_test_entry.c > build/typechecker_arena_write_provenance_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_arena_write_provenance_test_entry_final.c -o build/typechecker_arena_write_provenance_test_entry_bin
	@./build/typechecker_arena_write_provenance_test_entry_bin >> build/step51_arena_write_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 Arena.Set/Write provenance guard failed at runtime."; \
		cat build/step51_arena_write_provenance.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 Arena.Set/Write provenance metadata guard passed."

guard_step51_container_getref_provenance: gust
	@echo "🔒 Checking Step 5.1 container GetRef provenance metadata..."
	@mkdir -p build
	@./gust compiler/typechecker_container_getref_provenance_test_entry.gst > build/step51_container_getref_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 container GetRef provenance guard failed: compiler rejected the fixture."; \
		cat build/step51_container_getref_provenance.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_container_getref_provenance.log > build/typechecker_container_getref_provenance_test_entry.c
	@cat src/runtime.c build/typechecker_container_getref_provenance_test_entry.c > build/typechecker_container_getref_provenance_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_container_getref_provenance_test_entry_final.c -o build/typechecker_container_getref_provenance_test_entry_bin
	@./build/typechecker_container_getref_provenance_test_entry_bin >> build/step51_container_getref_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 container GetRef provenance guard failed at runtime."; \
		cat build/step51_container_getref_provenance.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 container GetRef provenance metadata guard passed."

guard_step51_hashmap_get_value_provenance: gust
	@echo "🔒 Checking Step 5.1 HashMap.Get value provenance metadata..."
	@mkdir -p build
	@./gust compiler/typechecker_hashmap_get_value_provenance_test_entry.gst > build/step51_hashmap_get_value_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 HashMap.Get value provenance guard failed: compiler rejected the fixture."; \
		cat build/step51_hashmap_get_value_provenance.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_hashmap_get_value_provenance.log > build/typechecker_hashmap_get_value_provenance_test_entry.c
	@cat src/runtime.c build/typechecker_hashmap_get_value_provenance_test_entry.c > build/typechecker_hashmap_get_value_provenance_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_hashmap_get_value_provenance_test_entry_final.c -o build/typechecker_hashmap_get_value_provenance_test_entry_bin
	@./build/typechecker_hashmap_get_value_provenance_test_entry_bin >> build/step51_hashmap_get_value_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 HashMap.Get value provenance guard failed at runtime."; \
		cat build/step51_hashmap_get_value_provenance.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 HashMap.Get value provenance metadata guard passed."

guard_step51_hashmap_get_value_field_provenance: gust
	@echo "🔒 Checking Step 5.1 HashMap.Get value field provenance metadata..."
	@mkdir -p build
	@./gust compiler/typechecker_hashmap_get_value_field_provenance_test_entry.gst > build/step51_hashmap_get_value_field_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 HashMap.Get value field provenance guard failed: compiler rejected the fixture."; \
		cat build/step51_hashmap_get_value_field_provenance.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_hashmap_get_value_field_provenance.log > build/typechecker_hashmap_get_value_field_provenance_test_entry.c
	@cat src/runtime.c build/typechecker_hashmap_get_value_field_provenance_test_entry.c > build/typechecker_hashmap_get_value_field_provenance_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_hashmap_get_value_field_provenance_test_entry_final.c -o build/typechecker_hashmap_get_value_field_provenance_test_entry_bin
	@./build/typechecker_hashmap_get_value_field_provenance_test_entry_bin >> build/step51_hashmap_get_value_field_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 HashMap.Get value field provenance guard failed at runtime."; \
		cat build/step51_hashmap_get_value_field_provenance.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 HashMap.Get value field provenance metadata guard passed."

guard_step51_std_vector_getref_provenance: gust
	@echo "🔒 Checking Step 5.1 std.VectorGetRef provenance metadata..."
	@mkdir -p build
	@./gust compiler/typechecker_std_vector_getref_provenance_test_entry.gst > build/step51_std_vector_getref_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 std.VectorGetRef provenance guard failed: compiler rejected the fixture."; \
		cat build/step51_std_vector_getref_provenance.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_std_vector_getref_provenance.log > build/typechecker_std_vector_getref_provenance_test_entry.c
	@cat src/runtime.c build/typechecker_std_vector_getref_provenance_test_entry.c > build/typechecker_std_vector_getref_provenance_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_std_vector_getref_provenance_test_entry_final.c -o build/typechecker_std_vector_getref_provenance_test_entry_bin
	@./build/typechecker_std_vector_getref_provenance_test_entry_bin >> build/step51_std_vector_getref_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 std.VectorGetRef provenance guard failed at runtime."; \
		cat build/step51_std_vector_getref_provenance.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 std.VectorGetRef provenance metadata guard passed."

guard_step51_std_hashmap_getref_provenance: gust
	@echo "🔒 Checking Step 5.1 std.HashMapGetRef provenance metadata..."
	@mkdir -p build
	@./gust compiler/typechecker_std_hashmap_getref_provenance_test_entry.gst > build/step51_std_hashmap_getref_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 std.HashMapGetRef provenance guard failed: compiler rejected the fixture."; \
		cat build/step51_std_hashmap_getref_provenance.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_std_hashmap_getref_provenance.log > build/typechecker_std_hashmap_getref_provenance_test_entry.c
	@cat src/runtime.c build/typechecker_std_hashmap_getref_provenance_test_entry.c > build/typechecker_std_hashmap_getref_provenance_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_std_hashmap_getref_provenance_test_entry_final.c -o build/typechecker_std_hashmap_getref_provenance_test_entry_bin
	@./build/typechecker_std_hashmap_getref_provenance_test_entry_bin >> build/step51_std_hashmap_getref_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 std.HashMapGetRef provenance guard failed at runtime."; \
		cat build/step51_std_hashmap_getref_provenance.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 std.HashMapGetRef provenance metadata guard passed."

guard_step51_std_hashmap_getref_selector_alias_provenance: gust
	@echo "🔒 Checking Step 5.1 std.HashMapGetRef selector alias provenance metadata..."
	@mkdir -p build
	@./gust compiler/typechecker_std_hashmap_getref_selector_alias_provenance_test_entry.gst > build/step51_std_hashmap_getref_selector_alias_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 std.HashMapGetRef selector alias provenance guard failed: compiler rejected the fixture."; \
		cat build/step51_std_hashmap_getref_selector_alias_provenance.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_std_hashmap_getref_selector_alias_provenance.log > build/typechecker_std_hashmap_getref_selector_alias_provenance_test_entry.c
	@cat src/runtime.c build/typechecker_std_hashmap_getref_selector_alias_provenance_test_entry.c > build/typechecker_std_hashmap_getref_selector_alias_provenance_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_std_hashmap_getref_selector_alias_provenance_test_entry_final.c -o build/typechecker_std_hashmap_getref_selector_alias_provenance_test_entry_bin
	@./build/typechecker_std_hashmap_getref_selector_alias_provenance_test_entry_bin >> build/step51_std_hashmap_getref_selector_alias_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 std.HashMapGetRef selector alias provenance guard failed at runtime."; \
		cat build/step51_std_hashmap_getref_selector_alias_provenance.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 std.HashMapGetRef selector alias provenance metadata guard passed."

guard_step51_std_vector_getref_selector_alias_provenance: gust
	@echo "🔒 Checking Step 5.1 std.VectorGetRef selector alias provenance metadata..."
	@mkdir -p build
	@./gust compiler/typechecker_std_vector_getref_selector_alias_provenance_test_entry.gst > build/step51_std_vector_getref_selector_alias_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 std.VectorGetRef selector alias provenance guard failed: compiler rejected the fixture."; \
		cat build/step51_std_vector_getref_selector_alias_provenance.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_std_vector_getref_selector_alias_provenance.log > build/typechecker_std_vector_getref_selector_alias_provenance_test_entry.c
	@cat src/runtime.c build/typechecker_std_vector_getref_selector_alias_provenance_test_entry.c > build/typechecker_std_vector_getref_selector_alias_provenance_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_std_vector_getref_selector_alias_provenance_test_entry_final.c -o build/typechecker_std_vector_getref_selector_alias_provenance_test_entry_bin
	@./build/typechecker_std_vector_getref_selector_alias_provenance_test_entry_bin >> build/step51_std_vector_getref_selector_alias_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 std.VectorGetRef selector alias provenance guard failed at runtime."; \
		cat build/step51_std_vector_getref_selector_alias_provenance.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 std.VectorGetRef selector alias provenance metadata guard passed."

guard_step51_reference_selector_alias_provenance: gust
	@echo "🔒 Checking Step 5.1 reference selector alias provenance metadata..."
	@mkdir -p build
	@./gust compiler/typechecker_reference_selector_alias_provenance_test_entry.gst > build/step51_reference_selector_alias_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 reference selector alias provenance guard failed: compiler rejected the fixture."; \
		cat build/step51_reference_selector_alias_provenance.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_reference_selector_alias_provenance.log > build/typechecker_reference_selector_alias_provenance_test_entry.c
	@cat src/runtime.c build/typechecker_reference_selector_alias_provenance_test_entry.c > build/typechecker_reference_selector_alias_provenance_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_reference_selector_alias_provenance_test_entry_final.c -o build/typechecker_reference_selector_alias_provenance_test_entry_bin
	@./build/typechecker_reference_selector_alias_provenance_test_entry_bin >> build/step51_reference_selector_alias_provenance.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 reference selector alias provenance guard failed at runtime."; \
		cat build/step51_reference_selector_alias_provenance.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 reference selector alias provenance metadata guard passed."

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

guard_step51_non_laundering_reference_selector_enforcement: gust
	@echo "🔒 Checking Step 5.1 non-laundering safe-branded reference-selector enforcement..."
	@mkdir -p build
	@./gust compiler/typechecker_non_laundering_reference_selector_test_entry.gst > build/step51_non_laundering_reference_selector.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 non-laundering reference-selector guard failed: compiler rejected the fixture."; \
		cat build/step51_non_laundering_reference_selector.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_non_laundering_reference_selector.log > build/typechecker_non_laundering_reference_selector_test_entry.c
	@cat src/runtime.c build/typechecker_non_laundering_reference_selector_test_entry.c > build/typechecker_non_laundering_reference_selector_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_non_laundering_reference_selector_test_entry_final.c -o build/typechecker_non_laundering_reference_selector_test_entry_bin
	@./build/typechecker_non_laundering_reference_selector_test_entry_bin >> build/step51_non_laundering_reference_selector.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 non-laundering reference-selector guard failed at runtime."; \
		cat build/step51_non_laundering_reference_selector.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 non-laundering safe-branded reference-selector enforcement guard passed."

guard_step51_non_laundering_hashmap_get_value_enforcement: gust
	@echo "🔒 Checking Step 5.1 non-laundering safe-branded HashMap.Get value enforcement..."
	@mkdir -p build
	@./gust compiler/typechecker_non_laundering_hashmap_get_value_test_entry.gst > build/step51_non_laundering_hashmap_get_value.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 non-laundering HashMap.Get value guard failed: compiler rejected the fixture."; \
		cat build/step51_non_laundering_hashmap_get_value.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_non_laundering_hashmap_get_value.log > build/typechecker_non_laundering_hashmap_get_value_test_entry.c
	@cat src/runtime.c build/typechecker_non_laundering_hashmap_get_value_test_entry.c > build/typechecker_non_laundering_hashmap_get_value_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_non_laundering_hashmap_get_value_test_entry_final.c -o build/typechecker_non_laundering_hashmap_get_value_test_entry_bin
	@./build/typechecker_non_laundering_hashmap_get_value_test_entry_bin >> build/step51_non_laundering_hashmap_get_value.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 non-laundering HashMap.Get value guard failed at runtime."; \
		cat build/step51_non_laundering_hashmap_get_value.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 non-laundering safe-branded HashMap.Get value enforcement guard passed."

guard_step51_non_laundering_hashmap_get_value_field_enforcement: gust
	@echo "🔒 Checking Step 5.1 non-laundering safe-branded HashMap.Get value field enforcement..."
	@mkdir -p build
	@./gust compiler/typechecker_non_laundering_hashmap_get_value_field_test_entry.gst > build/step51_non_laundering_hashmap_get_value_field.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 non-laundering HashMap.Get value field guard failed: compiler rejected the fixture."; \
		cat build/step51_non_laundering_hashmap_get_value_field.log; \
		exit $$status; \
	fi
	@grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/step51_non_laundering_hashmap_get_value_field.log > build/typechecker_non_laundering_hashmap_get_value_field_test_entry.c
	@cat src/runtime.c build/typechecker_non_laundering_hashmap_get_value_field_test_entry.c > build/typechecker_non_laundering_hashmap_get_value_field_test_entry_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/typechecker_non_laundering_hashmap_get_value_field_test_entry_final.c -o build/typechecker_non_laundering_hashmap_get_value_field_test_entry_bin
	@./build/typechecker_non_laundering_hashmap_get_value_field_test_entry_bin >> build/step51_non_laundering_hashmap_get_value_field.log 2>&1; \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
		echo "❌ Step 5.1 non-laundering HashMap.Get value field guard failed at runtime."; \
		cat build/step51_non_laundering_hashmap_get_value_field.log; \
		exit $$status; \
	fi
	@echo "✅ Step 5.1 non-laundering safe-branded HashMap.Get value field enforcement guard passed."

guard_step51_basic_unsafe_enforcement: guard_step51_raw_deref_unsafe_enforcement guard_step51_raw_cast_unsafe_enforcement guard_step51_pointer_arithmetic_unsafe_enforcement guard_step51_unsafe_func_call_enforcement guard_step51_raw_pointer_local_escape_enforcement
	@echo "✅ Step 5.1 basic unsafe enforcement aggregate passed."

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
