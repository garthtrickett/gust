#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

fixture="tests/stdlib_s2_byte_text.gst"
module="src/stdlib/byte_text.gst"
build_dir="build/guards/stdlib_s2_byte_text"
test -f "$fixture"
test -f "$module"

rm -rf "$build_dir"
mkdir -p "$build_dir"
make gust build/gust-native-backend build/gust-runtime-package.a

GUST_NATIVE_BACKEND_DRIVER="$PWD/build/gust-native-backend" \
  ./gust --backend cranelift -o "$build_dir/native" "$fixture" \
  >"$build_dir/compile.stdout" 2>"$build_dir/compile.stderr"
test ! -s "$build_dir/compile.stdout"
test ! -s "$build_dir/compile.stderr"
test -x "$build_dir/native"
"$build_dir/native" >"$build_dir/native.stdout" 2>"$build_dir/native.stderr"
test ! -s "$build_dir/native.stderr"
printf '%s\n' 1 1 1 0 0 0 1 1 1 1 1 1 1 1 1 0 0 0 1 1 1 \
  >"$build_dir/expected.stdout"
cmp "$build_dir/expected.stdout" "$build_dir/native.stdout"

# Explicit Cranelift must fail when its driver is absent, without producing an
# executable through another backend.
if GUST_NATIVE_BACKEND_DRIVER="$PWD/$build_dir/absent-driver" \
  ./gust --backend cranelift -o "$build_dir/absent-driver-output" "$fixture" \
  >"$build_dir/absent.stdout" 2>"$build_dir/absent.stderr"; then
  echo "S2.1 unexpectedly compiled without the native driver." >&2
  exit 1
fi
rg -q -F 'driver_handshake_error' "$build_dir/absent.stdout"
rg -q -F 'Native backend driver discovery error' "$build_dir/absent.stderr"
test ! -e "$build_dir/absent-driver-output"
test ! -e "$build_dir/absent-driver-output.c"
echo "guard-stdlib-s2-byte-text: ok (21 byte predicate cases, native execution, no fallback)"
