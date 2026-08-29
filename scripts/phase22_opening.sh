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

./gust "$fixture" > "$build_dir/bare.c" 2> "$build_dir/bare.stderr"
./gust --backend mir-to-c "$fixture" > "$build_dir/explicit.c" 2> "$build_dir/explicit.stderr"
test -s "$build_dir/bare.c" || fail "bare route emitted no C"
test ! -s "$build_dir/bare.stderr" || fail "bare route emitted stderr"
test ! -s "$build_dir/explicit.stderr" || fail "explicit MIR-to-C emitted stderr"
cmp -s "$build_dir/bare.c" "$build_dir/explicit.c" ||
  fail "bare and explicit MIR-to-C output differ"

set +e
./gust --backend c "$fixture" > "$build_dir/c-alias.stdout" 2> "$build_dir/c-alias.stderr"
c_alias_status="$?"
set -e
if rg -F '"phase22_explicit_c_migration"' scripts/cranelift_feature_registry.json >/dev/null; then
  test "$c_alias_status" -eq 0 || fail "the registered C alias failed"
  test ! -s "$build_dir/c-alias.stderr" || fail "the C alias emitted stderr"
  cmp -s "$build_dir/bare.c" "$build_dir/c-alias.stdout" ||
    fail "the registered C alias differs from MIR-to-C"
else
  test "$c_alias_status" -ne 0 || fail "the not-yet-introduced C alias unexpectedly succeeded"
  rg -F 'Compiler invocation error: unknown backend: c' "$build_dir/c-alias.stdout" >/dev/null ||
    fail "the current C-alias rejection diagnostic drifted"
  test ! -s "$build_dir/c-alias.stderr" || fail "rejected C alias emitted stderr"
fi

set +e
./gust --backend cranelift "$fixture" > "$build_dir/missing-output.stdout" 2> "$build_dir/missing-output.stderr"
missing_output_status="$?"
set -e
test "$missing_output_status" -ne 0 || fail "Cranelift without -o unexpectedly succeeded"
rg -F 'Compiler invocation error: the experimental backend requires exactly one -o <output> value' \
  "$build_dir/missing-output.stdout" >/dev/null ||
  fail "the current Cranelift -o diagnostic drifted"
test ! -s "$build_dir/missing-output.stderr" || fail "missing-output rejection emitted stderr"

./build/phase10-package/bin/gust --help > "$build_dir/help.stdout" 2> "$build_dir/help.stderr"
test ! -s "$build_dir/help.stderr" || fail "help emitted stderr"
rg -F 'gust <source.gst>' "$build_dir/help.stdout" >/dev/null || fail "bare help route is missing"
rg -F 'Emit C source to stdout (default).' "$build_dir/help.stdout" >/dev/null ||
  fail "help no longer identifies the current default"
rg -F 'Required only by the cranelift backend.' "$build_dir/help.stdout" >/dev/null ||
  fail "help no longer records the Cranelift output contract"
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
