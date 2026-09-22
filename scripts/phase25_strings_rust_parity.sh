#!/usr/bin/env bash
# Patch 25.10a: the nine pure string functions, Rust against the C they replace.
#
# WHAT THIS REPLACES. scripts/phase25_strings_gust_parity.sh proved the
# Gust-emitted C matched the hand-written C it displaced. Patch 25.10
# deletes the emitter, so that differential has no second side to run and
# the guard cannot be repaired -- it can only be re-aimed. The claim worth
# keeping is unchanged: whatever defines std_str_eq today behaves exactly
# as the C did. Only the "whatever" moved, from emitted C to Rust.
#
# THE ORACLE IS PINNED BY BLOB, NOT BY PATH. src/runtime/strings.c is
# deleted, so there is no file to compare against and "the version in the
# last commit" drifts the moment anything else lands. A git blob hash names
# the exact bytes forever and cannot be edited into agreement:
#
#   blob   8495f318a6033707f02925ad19d2853f7400534d
#   sha256 e23b8981097e6d9da4950cc2e7220450eb7b65134bd5867d0ce3e4b23530faad
#
# Both are checked below. Re-pinning either one is a deliberate act that
# shows up in review as exactly what it is.
#
# HOW BOTH SIDES COEXIST. The oracle defines the same ten symbols the
# runtime archive now exports, so it is compiled separately and every
# colliding name is renamed to oracle_* with objcopy before the link. The
# driver then calls both and compares -- which is the whole point, and is
# impossible if the linker is allowed to pick one.
set -euo pipefail
cd "$(dirname "$0")/.."

ORACLE_BLOB=8495f318a6033707f02925ad19d2853f7400534d
ORACLE_SHA256=e23b8981097e6d9da4950cc2e7220450eb7b65134bd5867d0ce3e4b23530faad
GUARD=guard-cranelift-phase25-strings-rust-parity

fail() { echo "$GUARD: $*" >&2; exit 1; }

if [ -e src/runtime/strings.c ]; then
	fail "src/runtime/strings.c is back. Patch 25.10a retired it into
src/runtime-rs; a file at that path means the second seed returned, and
this differential would then be comparing the oracle against itself."
fi

RUNTIME=build/gust-runtime-package.a
# Built here rather than required here. Two reasons, and the second is the
# one that changed my mind: the script becomes self-sufficient, and the C
# toolchain provenance guard can then resolve where the archive came from
# -- it follows `make <target>` one hop into the Makefile, but it cannot
# follow a sentence telling a human to run make. An input whose producer
# the guard cannot name reads as provenance-less, which for the one
# artifact this whole differential links against is the wrong answer.
make "$RUNTIME"
[ -f "$RUNTIME" ] || fail "$RUNTIME is missing and make did not build it"

# The archive must have NO C member. This is the property 25.11 needs and
# it is asserted here rather than inferred from the member list living in
# the registry, because the registry is what a patch edits.
members="$(ar t "$RUNTIME" | tr '\n' ' ')"
if [ "$members" != "gust_runtime_rs_exports.o " ]; then
	fail "runtime archive members are '$members', expected exactly
'gust_runtime_rs_exports.o '. A second member means C is back on the
runtime's critical path."
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

git cat-file blob "$ORACLE_BLOB" > "$work/oracle.c" 2>/dev/null \
	|| fail "blob $ORACLE_BLOB is not in this repository. The oracle is
the retired src/runtime/strings.c; a shallow clone without history cannot
run this differential."
got=$(sha256sum "$work/oracle.c" | cut -d' ' -f1)
[ "$got" = "$ORACLE_SHA256" ] || fail "oracle blob digest is $got, pinned
$ORACLE_SHA256 -- the blob hash and the content hash disagree, which git
does not do by accident."

SYMBOLS="std_str_eq std_str_byte_at std_is_alpha std_is_digit \
std_is_whitespace std_str_find std_parse_int std_str_slice std_str_trim \
std_str_bounds_fail"

"${CC:-cc}" -O2 -w -pthread -Isrc/runtime -c "$work/oracle.c" -o "$work/oracle.o"

redefines=""
for sym in $SYMBOLS; do
	redefines="$redefines --redefine-sym $sym=oracle_$sym"
done
# The emitter also produced <name>_pthread_wrapper for every function.
# They are not part of the exported surface -- they appear in neither
# PHASE25_RUNTIME_RS_EXPORTS nor the objcopy keep list -- but they are
# defined in this object and would collide with nothing, so they are left
# alone beyond following their renamed callees.
objcopy $redefines "$work/oracle.o" "$work/oracle_renamed.o"

cp scripts/phase25_strings_rust_parity_driver.c "$work/driver.c"
"${CC:-cc}" -O2 -w -pthread -Isrc/runtime -c "$work/driver.c" -o "$work/driver.o"
"${CC:-cc}" -pthread "$work/driver.o" "$work/oracle_renamed.o" "$RUNTIME" \
	-o "$work/parity"

"$work/parity" > "$work/out" 2>"$work/err" || {
	cat "$work/out" "$work/err" >&2
	fail "the Rust string runtime and the retired C disagree"
}
[ -s "$work/err" ] && { cat "$work/err" >&2; fail "parity driver wrote to stderr"; }

cases=$(cat "$work/out")
# A differential that runs zero cases passes. Name the number so the guard
# fails when the corpus is emptied rather than when it disagrees.
[ "$cases" -ge 400 ] || fail "only $cases comparisons ran; the corpus is
too small to be evidence. An existence test is not a currency test."
echo "$GUARD: ok ($cases comparisons, Rust == retired C, archive has no C member)"
