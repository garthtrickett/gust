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
#   * Byte-identity is only meaningful over the artifact set Patch 25.2
#     fixed. Comparing the binaries is the strongest available form of it.
set -euo pipefail
cd "$(dirname "$0")/.."

ENTRY=compiler/test_runner_entry.gst
PKG=build/phase10-package/bin
DRIVER="$PWD/$PKG/gust-native-backend"
STAGE1=build/native-stage1
STAGE2=build/native-stage2

if [ ! -x "$PKG/gust" ] || [ ! -x "$DRIVER" ]; then
	echo "native package missing; building it"
	make phase10-native-package
fi

echo "== stage 1: the packaged compiler builds the compiler natively =="
"$PKG/gust" --backend cranelift -o "$STAGE1" "$ENTRY"
test -x "$STAGE1"

echo "== stage 2: the native compiler builds the compiler again =="
GUST_NATIVE_BACKEND_DRIVER="$DRIVER" "$STAGE1" --backend cranelift -o "$STAGE2" "$ENTRY"
test -x "$STAGE2"

echo "== fixed point =="
s1=$(sha256sum "$STAGE1" | cut -d' ' -f1)
s2=$(sha256sum "$STAGE2" | cut -d' ' -f1)
echo "  stage1 $s1"
echo "  stage2 $s2"
if [ "$s1" != "$s2" ]; then
	echo "guard-cranelift-phase25-native-fixed-point: stage1 != stage2"
	cmp -l "$STAGE1" "$STAGE2" | head -20 || true
	exit 1
fi

# A fixed point between two IDENTICAL inputs proves nothing if stage 1 was
# never a working compiler. Stage 2 succeeding is that check: a binary that
# could not compile the compiler could not have produced stage 2 at all.
echo "guard-cranelift-phase25-native-fixed-point: ok (stage_n == stage_n+1)"
