#!/usr/bin/env bash
set -euo pipefail

guard="guard-cranelift-phase22-opening-evidence"
fixture="compiler/phase11_scalar_unsupported_multiply_source.gst"
package_dir="build/phase10-package/bin"
build_dir="build/guards/cranelift_phase22_opening"

fail() {
  echo "$guard: $1" >&2
  exit 1
}

test -x ./gust || fail "requires the built ./gust compiler"
test -x "$package_dir/gust" || fail "requires the packaged gust compiler"
test -x "$package_dir/gust-native-backend" || fail "requires the packaged native driver"
test -f "$package_dir/gust-runtime-package.a" || fail "requires the packaged runtime archive"
test -x "$package_dir/gust" || fail "packaged compiler mode drifted"
test -x "$package_dir/gust-native-backend" || fail "packaged driver mode drifted"
test ! -x "$package_dir/gust-runtime-package.a" || fail "runtime archive must not be executable"

rm -rf "$build_dir"
mkdir -p "$build_dir"

# Patch 24.13: the explicit MIR-to-C emission is retired. Everything it fed --
# the byte comparison against the bare route, and the c-alias comparison below
# -- compared two spellings this patch removes. The post-flip branch is
# unaffected: it compares bare against explicit CRANELIFT, which is the
# comparison this file exists to make now.
if rg -F '"phase22_default_route_flip"' scripts/cranelift_feature_registry.json >/dev/null; then
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$package_dir/gust-native-backend" \
    ./gust -o "$build_dir/bare-program" "$fixture" > "$build_dir/bare.stdout" 2> "$build_dir/bare.stderr"
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$package_dir/gust-native-backend" \
    ./gust --backend cranelift -o "$build_dir/explicit-program" "$fixture" > "$build_dir/native-explicit.stdout" 2> "$build_dir/native-explicit.stderr"
  cmp -s "$build_dir/bare-program" "$build_dir/explicit-program" || fail "bare and explicit native output differ"
  test ! -s "$build_dir/bare.stderr" || fail "bare native route emitted stderr"
else
  # Patch 24.13: the pre-flip branch compared the bare route's emitted C
  # against explicit MIR-to-C. Both are gone, and reaching this branch would
  # mean the flip was unregistered after the backend was removed.
  fail "the default-route flip is unregistered but the generated-C backend is already removed"
fi

set +e
./gust --backend c "$fixture" > "$build_dir/c-alias.stdout" 2> "$build_dir/c-alias.stderr"
c_alias_status="$?"
set -e
# Patch 24.13: INVERTED. Phase 22 introduced the `c` alias and this block
# asserted it worked; the alias is now removed, so what must hold is that it is
# REJECTED. Asserting absence-by-rejection rather than deleting the block keeps
# a live falsifier: if the alias comes back, this fails.
test "$c_alias_status" -ne 0 || fail "the removed C alias still succeeds"
rg -F 'the generated-C backend was removed in Phase 24' "$build_dir/c-alias.stdout" >/dev/null ||
  fail "the C-alias rejection does not name the Phase 24 removal"
test ! -s "$build_dir/c-alias.stderr" || fail "rejected C alias emitted stderr"

if rg -F '"phase22_native_implicit_output"' scripts/cranelift_feature_registry.json >/dev/null; then
  rg -F 'invocation.output_path = compiler_native_implicit_output_path(invocation.source_path, ctx);' \
    compiler/test_runner_entry.gst >/dev/null ||
    fail "the successor implicit-output route is absent"
else
  set +e
  ./gust --backend cranelift "$fixture" > "$build_dir/missing-output.stdout" 2> "$build_dir/missing-output.stderr"
  missing_output_status="$?"
  set -e
  test "$missing_output_status" -ne 0 || fail "Cranelift without -o unexpectedly succeeded"
  rg -F 'Compiler invocation error: the experimental backend requires exactly one -o <output> value' \
    "$build_dir/missing-output.stdout" >/dev/null ||
    fail "the current Cranelift -o diagnostic drifted"
  test ! -s "$build_dir/missing-output.stderr" || fail "missing-output rejection emitted stderr"
fi

./build/phase10-package/bin/gust --help > "$build_dir/help.stdout" 2> "$build_dir/help.stderr"
test ! -s "$build_dir/help.stderr" || fail "help emitted stderr"
rg -F 'gust <source.gst>' "$build_dir/help.stdout" >/dev/null || fail "bare help route is missing"
if rg -F '"phase22_default_route_flip"' scripts/cranelift_feature_registry.json >/dev/null; then
  rg -F 'Compile to one native executable (default).' "$build_dir/help.stdout" >/dev/null ||
    fail "help no longer identifies the successor default"
else
  rg -F 'Emit C source to stdout (default).' "$build_dir/help.stdout" >/dev/null ||
    fail "help no longer identifies the current default"
fi
if rg -F '"phase22_native_implicit_output"' scripts/cranelift_feature_registry.json >/dev/null; then
  rg -F 'Optional Cranelift output; defaults to the source stem.' "$build_dir/help.stdout" >/dev/null ||
    fail "help no longer records the successor implicit-output contract"
else
  rg -F 'Required only by the cranelift backend.' "$build_dir/help.stdout" >/dev/null ||
    fail "help no longer records the Cranelift output contract"
fi
rg -F 'fallback to MIR-to-C.' "$build_dir/help.stdout" >/dev/null ||
  fail "help no longer records no fallback"

native_output="$build_dir/native-program"
GUST_NATIVE_BACKEND_DRIVER="$PWD/$package_dir/gust-native-backend" \
  ./build/phase10-package/bin/gust --backend cranelift -o "$native_output" "$fixture" \
  > "$build_dir/native-compile.stdout" 2> "$build_dir/native-compile.stderr"
test -x "$native_output" || fail "explicit packaged Cranelift produced no executable"
test ! -s "$build_dir/native-compile.stdout" || fail "successful Cranelift compilation emitted stdout"
test ! -s "$build_dir/native-compile.stderr" || fail "successful Cranelift compilation emitted stderr"

set +e
"$native_output" > "$build_dir/native.stdout" 2> "$build_dir/native.stderr"
native_status="$?"
set -e
test "$native_status" -eq 12 || fail "native fixture status drifted from the MIR-to-C oracle"
test ! -s "$build_dir/native.stdout" || fail "native fixture emitted stdout"
test ! -s "$build_dir/native.stderr" || fail "native fixture emitted stderr"

echo "$guard: ok"
