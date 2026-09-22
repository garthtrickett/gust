#!/usr/bin/env bash
set -euo pipefail

guard="guard-cranelift-phase22-explicit-c-migration-evidence"
fixture="compiler/phase11_scalar_unsupported_multiply_source.gst"
compiler_source="compiler/test_runner_entry.gst"
build_dir="build/guards/cranelift_phase22_explicit_c_migration"

fail() {
  echo "$guard: $1" >&2
  exit 1
}

test -x ./gust || fail "requires the built ./gust compiler"
test -x ./gust_bootstrap || fail "requires the bootstrap compiler"

rm -rf "$build_dir"
mkdir -p "$build_dir"
# Patch 25.9: gust_v4.c is deleted, so this pair inverts with it. It read
# the seed's digest before and after, and compared them at the end, to
# assert "this guard did not modify the checked-in seed". `sha256sum` on a
# missing path does not return a digest, it exits 1 -- which is how this
# guard failed on the seed cut-over PR.
#
# The claim survives the deletion; only its polarity changes. What the
# guard must not do now is CREATE the seed: it bootstraps, and Patch 25.9
# removed the line that copied stage 3 output over gust_v4.c. If the file
# is back afterwards, that line is back.
test ! -e gust_v4.c || fail "gust_v4.c exists before this guard runs; Patch 25.9 deleted it"

# Patch 24.13: the explicit-C emission arms are retired with the spellings they
# exercised. This guard is Phase 22's record of migrating consumers TO explicit
# C -- byte-identity between `mir-to-c` and the `c` alias, and between those and
# the checked-in seed compiler. All of it is about spellings this patch removes.
#
# The seed arm is NOT retired for the reason the others are. ./gust_bootstrap
# is the seed binary and still carries mir-to-c; Phase 25 owns that, not this
# patch. What goes is the COMPARISON against ./gust, because the current
# compiler no longer has a spelling to compare with -- and the seed fixed-point
# it was checking is asserted directly by `make bootstrap`, which requires
# build/gust_stage2.c and build/gust_stage3.c to be byte-identical.
#
# So the claim survives with a different witness rather than being dropped.
#
# Patch 24.13 correction: this line used to read --backend mir-to-c, justified
# as "the pinned pre-patch binary Phase 25 owns". That held only while the seed
# predated the removal. This patch reconverges the seed, so gust_bootstrap is
# compiled from a 24.13 gust_v4.c and rejects the spelling it was pinned to --
# the same correction already made for all five Makefile bootstrap callers.
# The emitter is reached through the bootstrap-only entry instead, and the
# assertions below are unchanged: clean stderr, non-empty C.
# Patch 24.13: the bootstrap-emitter entry is authority-gated (review on
# #421). Exported once, ABOVE the first use -- it sat below the seed emitter
# when that line still spelled mir-to-c, and moving the line without moving
# the export would have left the first caller ungated.
export GUST_BOOTSTRAP_EMITTER=1
./gust_bootstrap --backend bootstrap-emitter "$fixture" >"$build_dir/prepatch.c" 2>"$build_dir/prepatch.stderr"
test ! -s "$build_dir/prepatch.stderr" || fail "the Phase-25-owned seed emitter emitted diagnostics"
test -s "$build_dir/prepatch.c" || fail "the Phase-25-owned seed emitter produced no C"

set +e
./gust --backend C "$fixture" >"$build_dir/invalid.stdout" 2>"$build_dir/invalid.stderr"
invalid_status="$?"
set -e
test "$invalid_status" -ne 0 || fail "unregistered case-variant C backend succeeded"
rg -F 'Compiler invocation error: unknown backend: C' "$build_dir/invalid.stdout" >/dev/null ||
  fail "unknown-backend diagnostic drifted"
test ! -s "$build_dir/invalid.stderr" || fail "unknown backend emitted stderr"

./gust --help >"$build_dir/help.stdout" 2>"$build_dir/help.stderr"
test ! -s "$build_dir/help.stderr" || fail "help emitted stderr"
# Patch 24.13 inverted these two to absence-pins and withdrew it: 28
# registered live-C cases still invoked the spelling, 24 of them
# Stdlib-owned, and rejecting it broke eight Stdlib S1 workflows green on
# main. Help had to keep advertising what the CLI still accepted.
#
# Issue #398 drained that surface, so the inversion lands -- and it is
# checked against LIVE help output, not against the help file, which is what
# makes it evidence rather than a second copy of a static assertion. Both
# halves: the retired wording gone AND the wording that replaced it there. A
# bare absence pin would pass on a compiler that printed no help at all.
rg -F 'gust --backend c <source.gst>' "$build_dir/help.stdout" >/dev/null &&
  fail "help still advertises the removed c alias"
rg -F -- '--backend <mir-to-c|c|cranelift>' "$build_dir/help.stdout" >/dev/null &&
  fail "the backend option help still offers the removed spellings"
rg -F -- '--backend <cranelift>' "$build_dir/help.stdout" >/dev/null ||
  fail "backend option help drifted"
rg -F 'The generated-C backend was REMOVED in Phase 24' "$build_dir/help.stdout" >/dev/null ||
  fail "help does not state that the generated-C backend was removed"

# No CLI probe here. The behaviour -- both spellings refused, each naming the
# removal -- is asserted by scripts/phase12_5_route_architecture.sh and
# scripts/phase22_opening.sh, and those two are the registered inverted
# probes the invocation census accounts for. A third would add a live-C row
# that every census then has to explain, in exchange for a claim two guards
# already make.
if rg -F '"phase22_default_route_flip"' scripts/cranelift_feature_registry.json >/dev/null; then
  rg -F 'Compile to one native executable (default).' "$build_dir/help.stdout" >/dev/null || fail "successor default route is absent"
else
  rg -F 'Emit C source to stdout (default).' "$build_dir/help.stdout" >/dev/null &&
    fail "help still offers C emission as the default route"
fi

# Patch 24.13: this is the BOOTSTRAP self-compilation fixed point, not a
# consumer of the explicit-C route, so it takes the bootstrap spelling rather
# than being retired. It mirrors Makefile:241 and :245 exactly -- same source
# (compiler/test_runner_entry.gst), same filter, same stage2/stage3 comparison
# -- and those two rows are the ones this patch moved to the bootstrap-only
# entry. Using bootstrap-emitter here is not overloading a bootstrap name for a
# non-bootstrap purpose; this arm IS bootstrap work.
./gust --backend bootstrap-emitter "$compiler_source" |
  grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" >"$build_dir/stage2.c"
cat src/runtime.c "$build_dir/stage2.c" >"$build_dir/stage2-final.c"
# Patch 25.6: src/runtime.c is no longer a complete runtime. fiber.c is
# deleted and its eighteen exports live in the runtime crate, and codegen
# emits a gust_yield() call in every loop of every compiled Gust program,
# so this link needs the crate object. Built through make so a stale one
# cannot be linked silently.
runtime_obj="build/phase25-runtime-rs/gust_runtime_rs_exports.o"
make "$runtime_obj"
"${CC:-cc}" ${CFLAGS:--O2 -Wall -pthread} ${INCLUDES:--Isrc} \
  "$build_dir/stage2-final.c" "$runtime_obj" -o "$build_dir/stage2-bin"
"$build_dir/stage2-bin" --backend bootstrap-emitter "$compiler_source" |
  grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" >"$build_dir/stage3.c"
cmp -s "$build_dir/stage2.c" "$build_dir/stage3.c" || fail "stage 2 and stage 3 C are not byte-identical"

test ! -e gust_v4.c || fail "this guard regenerated gust_v4.c. Patch 25.9 removed the copy of stage 3 output over the seed; if the file is back, so is that line."

echo "$guard: ok"
