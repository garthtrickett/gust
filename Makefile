CC = cc
CFLAGS = -O2 -Wall -pthread
INCLUDES = -Isrc
PREFIX = /usr/local

# Force make to use bash with pipefail to prevent silent pipeline errors
SHELL = bash
.SHELLFLAGS = -o pipefail -c

.PHONY: all clean test bootstrap install test_tree_sitter report_compiler_get_opt_migration guard_parser_high_level_raw_casts

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

test: gust guard_parser_high_level_raw_casts
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

report_compiler_get_opt_migration:
	@echo "📊 Reporting compiler .get_opt migration sites..."
	@rg -n '\.get_opt[[:space:]]*\(' compiler/*.gst || true

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
