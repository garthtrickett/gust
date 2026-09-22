#!/usr/bin/env bash
# Patch 25.7: the NATIVE fixed point -- stage_n == stage_n+1, no C compiler
# in the loop.
#
# The bootstrap fixed point (`make bootstrap`) compiles the compiler to C,
# builds it with cc, and asserts stage2.c == stage3.c. This is the same
# assertion one layer down: the Cranelift backend compiles the compiler to an
# EXECUTABLE, that executable compiles the compiler again, and the two
# binaries must be byte-identical.
#
# Two things make this work that are easy to get wrong:
#
#   * The stage-1 binary must be told where its Cranelift worker is.
#     Discovery prefers an explicit absolute path from
#     GUST_NATIVE_BACKEND_DRIVER and falls back to a SIBLING of the binary
#     on disk. A stage binary in build/ has no sibling worker, so without
#     the variable stage 2 dies at driver discovery -- after ~94 seconds of
#     successful compilation, which makes it look like a compiler failure.
#
#   * Byte-identity is only meaningful over the artifact set Patch 25.2 fixed,
#     and this guard used to compare the wrong thing. It hashed the two stage
#     BINARIES and called that "the strongest available form" of the artifact
#     set. It is not: 25.2's set excludes them by name -- "linked executables
#     -- would prove the linker deterministic (D4)". Comparing binaries can
#     pass a broken compiler when the objects differ only in sections the
#     linker normalises, and can fail a sound one on linker nondeterminism.
#     The objects existed all along; the driver wrote them as siblings of the
#     output and deleted them after linking, so nothing could hash them.
#     GUST_NATIVE_KEEP_OBJECTS retains them per stage, and THAT comparison is
#     the gate. The binary comparison is kept below, named as the separate D4
#     observation it always was.
set -euo pipefail
cd "$(dirname "$0")/.."

ENTRY=compiler/test_runner_entry.gst
PKG=build/phase10-package/bin
DRIVER="$PWD/$PKG/gust-native-backend"
STAGE1=build/native-stage1
STAGE2=build/native-stage2

# ALWAYS build, never "build only if missing". make is a no-op when the
# package is current, and the existence test is not a currency test: it left a
# stale worker in place after its source changed, so this guard ran the old
# compiler and reported on it. Measured -- the retention hook added to
# compiler/experiments/cranelift/src/main.rs was absent from
# build/phase10-package/bin/gust-native-backend while present in the crate's
# own target dir, and the guard had no way to notice.
make phase10-native-package

OBJ1=build/native-fp/stage1
OBJ2=build/native-fp/stage2
rm -rf build/native-fp

echo "== stage 1: the packaged compiler builds the compiler natively =="
GUST_NATIVE_KEEP_OBJECTS="$PWD/$OBJ1" "$PKG/gust" --backend cranelift -o "$STAGE1" "$ENTRY"
test -x "$STAGE1"

echo "== stage 2: the native compiler builds the compiler again =="
GUST_NATIVE_KEEP_OBJECTS="$PWD/$OBJ2" GUST_NATIVE_BACKEND_DRIVER="$DRIVER" \
	"$STAGE1" --backend cranelift -o "$STAGE2" "$ENTRY"
test -x "$STAGE2"

echo "== fixed point: objects the compiler emitted for its own sources =="
# A comparison over an empty set passes and says nothing. 25.2's artifact set
# exists precisely so the population is not assumed, so require one.
n1=$(find "$OBJ1" -name '*.o' | wc -l)
n2=$(find "$OBJ2" -name '*.o' | wc -l)
if [ "$n1" -eq 0 ] || [ "$n2" -eq 0 ]; then
	echo "guard-cranelift-phase25-native-fixed-point: no objects were retained"
	echo "  stage1=$n1 stage2=$n2 -- GUST_NATIVE_KEEP_OBJECTS is not being honoured,"
	echo "  so the comparison below would have compared nothing and passed."
	exit 1
fi
( cd "$OBJ1" && sha256sum *.o | sort -k2 ) > build/native-fp/stage1.sha
( cd "$OBJ2" && sha256sum *.o | sort -k2 ) > build/native-fp/stage2.sha
echo "  $n1 objects per stage"
if ! diff -u build/native-fp/stage1.sha build/native-fp/stage2.sha; then
	echo "guard-cranelift-phase25-native-fixed-point: emitted objects differ between stages"
	exit 1
fi
echo "  objects identical"

echo "== D4 observation: the linked executables, which are NOT the artifact set =="
s1=$(sha256sum "$STAGE1" | cut -d' ' -f1)
s2=$(sha256sum "$STAGE2" | cut -d' ' -f1)
echo "  stage1 $s1"
echo "  stage2 $s2"
if [ "$s1" != "$s2" ]; then
	echo "guard-cranelift-phase25-native-fixed-point: linked stage1 != stage2 (D4, linker determinism -- the OBJECT comparison above already passed, so this is the linker, not the compiler)"
	cmp -l "$STAGE1" "$STAGE2" | head -20 || true
	exit 1
fi

# A fixed point between two IDENTICAL inputs proves nothing if stage 1 was
# never a working compiler. Stage 2 succeeding is that check: a binary that
# could not compile the compiler could not have produced stage 2 at all.
echo "guard-cranelift-phase25-native-fixed-point: ok (stage_n == stage_n+1)"
