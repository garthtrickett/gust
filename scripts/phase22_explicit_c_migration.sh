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
test -x ./gust_bootstrap || fail "requires the checked-in-seed compiler"

rm -rf "$build_dir"
mkdir -p "$build_dir"
seed_before="$(sha256sum gust_v4.c | awk '{print $1}')"

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
# Patch 24.13 briefly inverted these two to absence-pins. Withdrawn with the
# removal itself: 25 registered live-C cases still invoke the spelling, and
# rejecting it broke 8 Stdlib S1 workflows green on main. Help must keep
# advertising what the CLI still accepts until the live-C surface drains
# (issue #398).
rg -F 'gust --backend c <source.gst>' "$build_dir/help.stdout" >/dev/null || fail "c alias is absent from help"
rg -F -- '--backend <mir-to-c|c|cranelift>' "$build_dir/help.stdout" >/dev/null || fail "backend option help drifted"
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
"${CC:-cc}" ${CFLAGS:--O2 -Wall -pthread} ${INCLUDES:--Isrc} \
  "$build_dir/stage2-final.c" -o "$build_dir/stage2-bin"
"$build_dir/stage2-bin" --backend bootstrap-emitter "$compiler_source" |
  grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" >"$build_dir/stage3.c"
cmp -s "$build_dir/stage2.c" "$build_dir/stage3.c" || fail "stage 2 and stage 3 C are not byte-identical"

seed_after="$(sha256sum gust_v4.c | awk '{print $1}')"
test "$seed_before" = "$seed_after" || fail "Patch 22.2 modified the checked-in bootstrap seed"

echo "$guard: ok"
