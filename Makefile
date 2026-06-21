CC = cc
CFLAGS = -O2 -Wall -pthread
INCLUDES = -Isrc
PREFIX = /usr/local

.PHONY: all clean test bootstrap install

all: gust

gust_bootstrap: gust_v4.c
	${CC} ${CFLAGS} gust_v4.c -o gust_bootstrap

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

test: gust
	@mkdir -p build
	
	@# === 1. CORE E2E FUNCTIONAL TESTS ===
	@# Collections Test
	./gust tests/e2e_collections_methods.gst | grep -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" > build/test_collections.c
	@cat src/runtime.c build/test_collections.c > build/test_collections_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/test_collections_final.c -o build/test_collections_bin
	@./build/test_collections_bin > build/test_collections.log
	@printf "3\n30\n30\n2\n0\n2\n100\n200\n0\n2\napple\nbanana\n1\n0\n" > build/expected_collections.log
	@diff -u build/expected_collections.log build/test_collections.log && echo "✅ Collections E2E Passed"
	
	@# Formatting/Arena Test
	./gust tests/e2e_formatting_utilities.gst | grep -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" > build/test_formatting.c
	@cat src/runtime.c build/test_formatting.c > build/test_formatting_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/test_formatting_final.c -o build/test_formatting_bin
	@./build/test_formatting_bin > build/test_formatting.log
	@printf "Loop Num: 0 - ok\nLoop Num: 1 - ok\nLoop Num: 2 - ok\n42\nroot_node\n42\nroot_node\n" > build/expected_formatting.log
	@diff -u build/expected_formatting.log build/test_formatting.log && echo "✅ Formatting & Arena E2E Passed"

	@# === 2. PHASE 1: BEDROCK STRICT TYPECHECKING TESTS ===
	@# Negative Check: Assert dereferencing a non-pointer fails compilation
	@if ./gust tests/test_deref_non_pointer_rejected.gst > build/test_deref_err.log 2>&1; then \
		echo "❌ FAIL: Expected dereference violation to fail compilation"; exit 1; \
	else \
		grep -q "DereferenceNonPointer" build/test_deref_err.log && echo "✅ Dereference fallback violation caught successfully"; \
	fi

	@# Negative Check: Assert unresolved selectors/missing fields fail compilation
	@if ./gust tests/test_unresolved_selector_rejected.gst > build/test_selector_err.log 2>&1; then \
		echo "❌ FAIL: Expected selector field violation to fail compilation"; exit 1; \
	else \
		grep -q -E "(FieldNotFound|UnresolvedSelector)" build/test_selector_err.log && echo "✅ Selector fallback violation caught successfully"; \
	fi

	@# Negative Check: Assert success wrapper Bool vs Int mismatches fail compilation
	@if ./gust tests/test_bool_wrapper_mismatch_rejected.gst > build/test_bool_err.log 2>&1; then \
		echo "❌ FAIL: Expected wrapper type mismatch to fail compilation"; exit 1; \
	else \
		grep -q "TypeMismatch" build/test_bool_err.log && echo "✅ Success wrapper TypeMismatch caught successfully"; \
	fi

	@# === 3. PHASE 2: LOOP SAFEPOINT TIMEOUT TESTS ===
	@./gust tests/e2e_starvation_safepoints.gst | grep -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" > build/test_safepoint.c
	@cat src/runtime.c build/test_safepoint.c > build/test_safepoint_final.c
	@${CC} ${CFLAGS} ${INCLUDES} build/test_safepoint_final.c -o build/test_safepoint_bin
	@# Run with a 5-second timeout to verify loops cooperatively yield
	@timeout 5s ./build/test_safepoint_bin > build/test_safepoint.log && echo "✅ Thread-Local Loop Safepoint yield verified"

	@# === 4. PHASE 5: GENERALIZED LINEAR RESOURCE LEAK TESTS ===
	@# Negative Check: Assert unreleased linear resources trigger compile-time errors
	@if ./gust tests/test_rc_leak_violation.gst > build/test_rc_leak.log 2>&1; then \
		echo "❌ FAIL: Expected linear resource leak to fail compilation"; exit 1; \
	else \
		grep -q "leak" build/test_rc_leak.log && echo "✅ Linear resource leak caught successfully"; \
	fi

clean:
	rm -rf gust_bootstrap gust build/

install: gust
	mkdir -p ${PREFIX}/bin
	cp gust ${PREFIX}/bin/gust
