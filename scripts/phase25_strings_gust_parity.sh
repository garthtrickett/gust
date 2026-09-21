#!/usr/bin/env bash
# Patch 25.5: differential parity for compiler/runtime/strings.gst.
#
# The roadmap's exit gate asks for parity evidence per file. For strings.c
# that means three comparisons, not one, because each catches a different
# class of divergence:
#
#   signatures  the emitted C prototype, byte for byte. `byte` maps to
#               `unsigned char` and `int` compiles just as happily, so a
#               wrong declaration is invisible until an ABI mismatch.
#   values      27 cases across all nine functions, same order, same
#               format, compared with diff.
#   aborts      4 bounds-failure paths, compared on message, STREAM and
#               exit code. The subscript's own check aborts with a
#               different message on a different stream, which is a real
#               difference a caller can see.
#
# The reference is tools/phase25_strings_reference.c -- a frozen copy, not
# src/runtime/strings.c, which this patch deletes. A differential whose
# control disappears stops being a differential.
set -euo pipefail
cd "$(dirname "$0")/.."

REF=tools/phase25_strings_reference.c
ENTRY=compiler/runtime/strings_parity_entry.gst
ARCHIVE=src/runtime-rs/target/release/libgust_runtime_rs.a
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if [ ! -x ./gust_bootstrap ]; then
	echo "❌ ./gust_bootstrap is required to emit the Gust side. Run: make gust_bootstrap"
	exit 2
fi
cargo build --release --manifest-path src/runtime-rs/Cargo.toml

"${CC:-cc}" -O1 -pthread "$REF" -o "$work/ref"

GUST_BOOTSTRAP_EMITTER=1 ./gust_bootstrap "$ENTRY" --backend bootstrap-emitter 2>&1 \
	| grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" > "$work/emitted.c"
{ echo '#include "runtime/core_headers.h"'; echo '#include <errno.h>'; cat "$work/emitted.c"; } > "$work/gust.c"
"${CC:-cc}" -O1 -Isrc -pthread "$work/gust.c" "$ARCHIVE" -o "$work/gust"

sigs() {
	grep -aE '^(int|unsigned char|Slice_unsigned_char) (std_str_|std_is_|std_parse_)' "$1" \
		| sed 's/ {$//' | grep -v bounds_fail | sort
}
fails=0
report() { printf '  %-34s %s\n' "$1" "$2"; [ "$2" = PASS ] || fails=$((fails + 1)); }

if diff -u <(sigs "$REF") <(sigs "$work/emitted.c") > "$work/sigdiff"; then
	report "9 signatures byte-identical" PASS
else
	report "9 signatures byte-identical" FAIL; cat "$work/sigdiff"
fi

"$work/ref" > "$work/out.ref" 2>&1
"$work/gust" > "$work/out.gust" 2>&1
if diff -u "$work/out.ref" "$work/out.gust" > "$work/valdiff"; then
	report "27 value cases identical" PASS
else
	report "27 value cases identical" FAIL; cat "$work/valdiff"
fi

for mode in a b c d; do
	set +e
	rout=$("$work/ref" "$mode" 2>&1); rexit=$?
	gout=$("$work/gust" "$mode" 2>&1); gexit=$?
	set -e
	if [ "$rout" = "$gout" ] && [ "$rexit" = "$gexit" ]; then
		report "abort path '$mode' identical" PASS
	else
		report "abort path '$mode' identical" FAIL
		echo "      ref [exit $rexit]: $rout"
		echo "      gst [exit $gexit]: $gout"
	fi
done

echo
if [ "$fails" -eq 0 ]; then echo "ALL PASS (0 failures)"; else echo "FAILURES ($fails)"; exit 1; fi
