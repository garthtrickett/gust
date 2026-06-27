CC = cc
CFLAGS = -O2 -Wall -pthread
INCLUDES = -Isrc
PREFIX = /usr/local

# Force make to use bash with pipefail to prevent silent pipeline errors
SHELL = bash
.SHELLFLAGS = -o pipefail -c

.PHONY: all clean test bootstrap install test_tree_sitter report_step44_accessor_contract report_compiler_get_opt_migration report_high_level_raw_collection_casts guard_step44_low_risk_entry_raw_casts guard_step44_typechecker_aux_raw_casts guard_step44_typechecker_types_raw_casts guard_step44_codegen_initializer_raw_casts guard_step44_typechecker_early_raw_casts guard_step44_typechecker_methods_raw_casts guard_step44_typechecker_pool_graph_raw_casts guard_parser_high_level_raw_casts

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

test: gust guard_parser_high_level_raw_casts guard_step44_low_risk_entry_raw_casts guard_step44_typechecker_aux_raw_casts guard_step44_typechecker_types_raw_casts guard_step44_codegen_initializer_raw_casts guard_step44_typechecker_early_raw_casts guard_step44_typechecker_methods_raw_casts guard_step44_typechecker_pool_graph_raw_casts
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
