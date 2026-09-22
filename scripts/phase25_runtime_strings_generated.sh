#!/usr/bin/env bash
# Patch 25.5: src/runtime/strings.c is GENERATED from compiler/runtime/strings.gst.
#
# The nine pure string functions moved to Gust. Getting them into every
# compiled program is the awkward half: programs are built as
# `cat src/runtime.c program.c`, so the definitions have to be inside
# src/runtime.c, and src/runtime.c is C.
#
# So the file keeps its path and its archive member name -- four separate
# places assert `strings.o` -- and changes provenance: hand-written C
# becomes C emitted from Gust. This script is the generator and the guard.
# With no argument it regenerates and DIFFS, which is what CI runs; with
# --write it updates the file.
#
# Why checked in rather than built: gust_bootstrap is built from gust_v4.c
# plus src/runtime.c, and emitting this file needs a compiler. A build-time
# rule is circular. It is a second generated artifact in the tree, like
# gust_v4.c, and the honest name for that is a second seed.
set -euo pipefail
cd "$(dirname "$0")/.."

SOURCE=compiler/runtime/strings.gst
TARGET=src/runtime/strings.c

if [ ! -x ./gust ]; then
	echo "❌ ./gust is required to regenerate $TARGET. Run: make gust"
	exit 2
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

{
	echo "/* GENERATED FILE -- DO NOT EDIT."
	echo " *"
	echo " * Emitted from $SOURCE by"
	echo " * scripts/phase25_runtime_strings_generated.sh --write."
	echo " *"
	echo " * Patch 25.5 moved the nine pure functions of the C string runtime"
	echo " * to Gust. This file is what the compiler makes of them, kept at"
	echo " * the path the hand-written original had so that src/runtime.c,"
	echo " * the phase21 archive member list and the registry rows all keep"
	echo " * naming strings.o. Editing it here is lost on the next"
	echo " * regeneration; edit the Gust and re-run the script."
	echo " *"
	echo " * std_Clone_str and std_str_split are NOT here. Both need N raw"
	echo " * bytes from a caller-supplied arena, which Gust cannot express,"
	echo " * and they live in src/runtime-rs under D2's per-file fallback."
	echo " */"
	# The hand-written strings.c opened with exactly this, and it is
	# load-bearing in a way the unity build hides. src/runtime.c includes
	# core_headers.h first, so inside that translation unit this is a
	# no-op -- but the phase21 archive compiles this file STANDALONE
	# (`cc -Isrc/runtime -c src/runtime/strings.c`), and without it that
	# fails on `unknown type name os_Arena`. Measured, after the first
	# generated version omitted it and compiled fine in the only place I
	# had thought to check.
	echo "#ifndef GUST_CORE_HEADERS_H"
	echo "#include \"core_headers.h\""
	echo "#endif"
	GUST_BOOTSTRAP_EMITTER=1 ./gust --backend bootstrap-emitter "$SOURCE" 2>&1 \
		| grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)"
} > "$work/strings.c"

if [ "${1:-}" = "--write" ]; then
	cp "$work/strings.c" "$TARGET"
	echo "guard-cranelift-phase25-runtime-strings-generated: wrote $TARGET"
	exit 0
fi

if diff -u "$TARGET" "$work/strings.c" > "$work/diff"; then
	echo "guard-cranelift-phase25-runtime-strings-generated: ok"
else
	echo "guard-cranelift-phase25-runtime-strings-generated: $TARGET is stale."
	echo "Regenerate with: scripts/phase25_runtime_strings_generated.sh --write"
	head -40 "$work/diff"
	exit 1
fi
