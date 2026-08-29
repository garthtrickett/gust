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

./gust_bootstrap --backend mir-to-c "$fixture" >"$build_dir/prepatch.c" 2>"$build_dir/prepatch.stderr"
./gust --backend mir-to-c "$fixture" >"$build_dir/mir-to-c.c" 2>"$build_dir/mir-to-c.stderr"
./gust --backend c "$fixture" >"$build_dir/c.c" 2>"$build_dir/c.stderr"
if ! rg -F '"phase22_default_route_flip"' scripts/cranelift_feature_registry.json >/dev/null; then
  ./gust "$fixture" >"$build_dir/bare.c" 2>"$build_dir/bare.stderr"
fi
for stderr in "$build_dir"/*.stderr; do
  test ! -s "$stderr" || fail "an accepted C spelling emitted diagnostics: $stderr"
done
cmp -s "$build_dir/prepatch.c" "$build_dir/mir-to-c.c" || fail "explicit C bytes changed from the checked-in-seed compiler"
cmp -s "$build_dir/mir-to-c.c" "$build_dir/c.c" || fail "the c alias differs from mir-to-c"
if [ -f "$build_dir/bare.c" ]; then
  cmp -s "$build_dir/bare.c" "$build_dir/mir-to-c.c" || fail "bare and explicit mir-to-c bytes differ before the flip"
fi

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
rg -F 'gust --backend c <source.gst>' "$build_dir/help.stdout" >/dev/null || fail "c alias is absent from help"
rg -F -- '--backend <mir-to-c|c|cranelift>' "$build_dir/help.stdout" >/dev/null || fail "backend option help drifted"
if rg -F '"phase22_default_route_flip"' scripts/cranelift_feature_registry.json >/dev/null; then
  rg -F 'Compile to one native executable (default).' "$build_dir/help.stdout" >/dev/null || fail "successor default route is absent"
else
  rg -F 'Emit C source to stdout (default).' "$build_dir/help.stdout" >/dev/null || fail "default changed during no-op migration"
fi

./gust --backend c "$compiler_source" |
  grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" >"$build_dir/stage2.c"
cat src/runtime.c "$build_dir/stage2.c" >"$build_dir/stage2-final.c"
"${CC:-cc}" ${CFLAGS:--O2 -Wall -pthread} ${INCLUDES:--Isrc} \
  "$build_dir/stage2-final.c" -o "$build_dir/stage2-bin"
"$build_dir/stage2-bin" --backend c "$compiler_source" |
  grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" >"$build_dir/stage3.c"
cmp -s "$build_dir/stage2.c" "$build_dir/stage3.c" || fail "stage 2 and stage 3 C are not byte-identical"

seed_after="$(sha256sum gust_v4.c | awk '{print $1}')"
test "$seed_before" = "$seed_after" || fail "Patch 22.2 modified the checked-in bootstrap seed"

echo "$guard: ok"
