CC = cc
CFLAGS = -O2 -Wall -pthread
INCLUDES = -Isrc
PREFIX = /usr/local

.PHONY: all clean test install

all: gust

gust_bootstrap: gust_v4.c
	${CC} ${CFLAGS} gust_v4.c -o gust_bootstrap

build/gust_compiler.c: gust_bootstrap compiler/test_runner_entry.gst
	mkdir -p build
	./gust_bootstrap compiler/test_runner_entry.gst | grep -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" > build/gust_compiler.c

gust: build/gust_compiler.c src/runtime.c
	cat src/runtime.c build/gust_compiler.c > build/gust_final.c
	${CC} ${CFLAGS} ${INCLUDES} build/gust_final.c -o gust

test: gust
	@mkdir -p build
	@# Collections Test
	./gust tests/e2e_collections_methods.gst | grep -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" > build/test_collections.c
	cat src/runtime.c build/test_collections.c > build/test_collections_final.c
	${CC} ${CFLAGS} ${INCLUDES} build/test_collections_final.c -o build/test_collections_bin
	./build/test_collections_bin > build/test_collections.log
	@printf "3\n30\n30\n2\n0\n2\n100\n200\n0\n2\napple\nbanana\n1\n0\n" > build/expected_collections.log
	@diff -u build/expected_collections.log build/test_collections.log && echo "✅ Collections E2E Passed"
	@# Formatting/Arena Test
	./gust tests/e2e_formatting_utilities.gst | grep -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" > build/test_formatting.c
	cat src/runtime.c build/test_formatting.c > build/test_formatting_final.c
	${CC} ${CFLAGS} ${INCLUDES} build/test_formatting_final.c -o build/test_formatting_bin
	./build/test_formatting_bin > build/test_formatting.log
	@printf "Loop Num: 0 - ok\nLoop Num: 1 - ok\nLoop Num: 2 - ok\n42\nroot_node\n42\nroot_node\n" > build/expected_formatting.log
	@diff -u build/expected_formatting.log build/test_formatting.log && echo "✅ Formatting & Arena E2E Passed"

clean:
	rm -rf gust_bootstrap gust 

install: gust
	mkdir -p ${PREFIX}/bin
	cp gust ${PREFIX}/bin/gust
