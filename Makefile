CC = cc
CFLAGS = -O2 -Wall -pthread
INCLUDES = -Isrc
PREFIX = /usr/local

.PHONY: all clean test bootstrap install test_tree_sitter

all: gust

gust_bootstrap: gust_v4.c src/runtime.c
	mkdir -p build
	cat src/runtime.c gust_v4.c > build/gust_bootstrap_final.c
	${CC} ${CFLAGS} ${INCLUDES} build/gust_bootstrap_final.c -o gust_bootstrap

build/gust_compiler.c: gust_bootstrap compiler/test_runner_entry.gst
	mkdir -p build
	./gust_bootstrap compiler/test_runner_entry.gst | grep -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" > build/gust_compiler.c

gust: build/gust_compiler.c src/runtime.c
	cat src/runtime.c build/gust_compiler.c > build/gust_final.c
	${CC} ${CFLAGS} ${INCLUDES} build/gust_final.c -o gust

# Fixed-Point Bootstrap Verification
bootstrap: gust
	@echo "⚙️  Beginning fixed-point bootstrap verification..."
	@# Stage 2: Use the new 'gust' binary to compile the compiler again
	./gust compiler/test_runner_entry.gst | grep -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" > build/gust_stage2.c
	@cat src/runtime.c build/gust_stage2.c > build/gust_stage2_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/gust_stage2_final.c -o build/gust_stage2_bin
	@# Stage 3: Use the Stage 2 binary to compile the compiler a third time
	./build/gust_stage2_bin compiler/test_runner_entry.gst | grep -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" > build/gust_stage3.c
	@# Stage 4: Assert byte-by-byte identity between Stage 2 and Stage 3 C files
	@diff -u build/gust_stage2.c build/gust_stage3.c && echo "✅ Fixed-point bootstrap convergence achieved!"
	cp build/gust_stage3.c gust_v4.c

test: gust
	@mkdir -p build
	@echo "⚙️  Compiling native Gust test runner..."
	@./gust tests/test_runner.gst | grep -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" > build/test_runner.c
	@cat src/runtime.c build/test_runner.c > build/test_runner_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/test_runner_final.c -o build/test_runner_bin
	@echo "🏃 Running native Gust test runner..."
	@./build/test_runner_bin
	@$(MAKE) test_tree_sitter

test_tree_sitter:
	@echo "🔍 Running Tree-sitter corpus tests..."
	cd tree-sitter-gust && tree-sitter test
	@echo "🔍 Validating all Gust files parse with zero errors..."
	@for f in compiler/*.gst tests/*.gst; do \
		echo "Parsing $$f..."; \
		(cd tree-sitter-gust && tree-sitter parse ../$$f --quiet) || exit 1; \
	done
	@echo "✅ Tree-sitter parsing validation passed!"

clean:
	rm -rf gust_bootstrap gust build/

install: gust
	mkdir -p ${PREFIX}/bin
	cp gust ${PREFIX}/bin/gust
