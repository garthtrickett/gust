#!/usr/bin/env bash
set -euo pipefail

guard="guard-cranelift-phase22-postflip-qualification-evidence"
package_bin="build/phase10-package/bin"
build_dir="build/guards/cranelift_phase22_postflip_qualification"
source_fixture="compiler/phase10_scalar_return_source.gst"

fail() {
  echo "$guard: $1" >&2
  exit 1
}

run_status() {
  local executable="$1"
  local prefix="$2"
  set +e
  "$executable" >"$prefix.stdout" 2>"$prefix.stderr"
  local status="$?"
  set -e
  printf '%s\n' "$status"
}

for artifact in gust gust-native-backend gust-runtime-package.a; do
  test -e "$package_bin/$artifact" || fail "default package is missing $artifact"
done
rm -rf "$build_dir"
mkdir -p "$build_dir"
install_root="$(mktemp -d "$PWD/build/phase22-postflip-install.XXXXXX")"
trap 'rm -rf "$install_root"' EXIT

source_copy="$build_dir/default.gst"
cp "$source_fixture" "$source_copy"
env -u GUST_NATIVE_BACKEND_DRIVER "$package_bin/gust" -o "$build_dir/bare" "$source_copy" \
  >"$build_dir/bare.build.stdout" 2>"$build_dir/bare.build.stderr"
env -u GUST_NATIVE_BACKEND_DRIVER "$package_bin/gust" --backend cranelift \
  -o "$build_dir/explicit" "$source_copy" \
  >"$build_dir/explicit.build.stdout" 2>"$build_dir/explicit.build.stderr"
cmp -s "$build_dir/bare" "$build_dir/explicit" ||
  fail "bare and explicit native artifacts differ"
test "$(run_status "$build_dir/bare" "$build_dir/bare.run")" = "7" ||
  fail "bare native behavior drifted"
test "$(run_status "$build_dir/explicit" "$build_dir/explicit.run")" = "7" ||
  fail "explicit native behavior drifted"
cmp -s "$build_dir/bare.run.stdout" "$build_dir/explicit.run.stdout" ||
  fail "bare and explicit native stdout differ"
cmp -s "$build_dir/bare.run.stderr" "$build_dir/explicit.run.stderr" ||
  fail "bare and explicit native stderr differ"

"$package_bin/gust" --backend c "$source_copy" >"$build_dir/c.c" 2>"$build_dir/c.stderr"
"$package_bin/gust" --backend mir-to-c "$source_copy" \
  >"$build_dir/mir-to-c.c" 2>"$build_dir/mir-to-c.stderr"
cmp -s "$build_dir/c.c" "$build_dir/mir-to-c.c" ||
  fail "explicit C spellings are not byte-identical"
cat src/runtime.c "$build_dir/c.c" >"$build_dir/oracle-final.c"
"${CC:-cc}" ${CFLAGS:--O2 -Wall -pthread} ${INCLUDES:--Isrc} \
  "$build_dir/oracle-final.c" -o "$build_dir/oracle"
test "$(run_status "$build_dir/oracle" "$build_dir/oracle.run")" = "7" ||
  fail "explicit-C oracle behavior drifted"
cmp -s "$build_dir/bare.run.stdout" "$build_dir/oracle.run.stdout" ||
  fail "default native stdout differs from explicit-C oracle"
cmp -s "$build_dir/bare.run.stderr" "$build_dir/oracle.run.stderr" ||
  fail "default native stderr differs from explicit-C oracle"

make install DESTDIR="$install_root" PREFIX=/opt/gust \
  >"$build_dir/install.stdout" 2>"$build_dir/install.stderr"
installed_bin="$install_root/opt/gust/bin"
installed_inventory="$(find "$installed_bin" -mindepth 1 -maxdepth 1 -type f -printf '%f\n' | sort)"
test "$installed_inventory" = $'gust\ngust-native-backend\ngust-runtime-package.a' ||
  fail "installed package is not the exact sibling set"
installed_source="$build_dir/installed.gst"
cp "$source_fixture" "$installed_source"
env -u GUST_NATIVE_BACKEND_DRIVER "$installed_bin/gust" "$installed_source" \
  >"$build_dir/installed.build.stdout" 2>"$build_dir/installed.build.stderr"
test -x "$build_dir/installed" || fail "installed bare default produced no executable"
test "$(run_status "$build_dir/installed" "$build_dir/installed.run")" = "7" ||
  fail "installed bare default behavior drifted"

relocated_bin="$build_dir/relocated/bin"
mkdir -p "$(dirname "$relocated_bin")"
cp -a "$installed_bin" "$relocated_bin"
relocated_source="$build_dir/relocated-program.gst"
cp "$source_fixture" "$relocated_source"
env -u GUST_NATIVE_BACKEND_DRIVER "$relocated_bin/gust" "$relocated_source" \
  >"$build_dir/relocated.build.stdout" 2>"$build_dir/relocated.build.stderr"
test -x "$build_dir/relocated-program" || fail "relocated bare default produced no executable"
test "$(run_status "$build_dir/relocated-program" "$build_dir/relocated.run")" = "7" ||
  fail "relocated bare default behavior drifted"

missing_bin="$build_dir/missing-worker/bin"
mkdir -p "$missing_bin"
cp "$installed_bin/gust" "$missing_bin/gust"
missing_source="$build_dir/missing.gst"
cp "$source_fixture" "$missing_source"
printf '%s\n' phase22-postflip-sentinel >"$build_dir/missing"
cp "$build_dir/missing" "$build_dir/missing.expected"
set +e
env -u GUST_NATIVE_BACKEND_DRIVER PATH="$installed_bin:$PATH" \
  "$missing_bin/gust" "$missing_source" \
  >"$build_dir/missing.stdout" 2>"$build_dir/missing.stderr"
missing_status="$?"
set -e
test "$missing_status" -ne 0 || fail "bare default silently found a PATH worker"
cmp -s "$build_dir/missing" "$build_dir/missing.expected" ||
  fail "failed bare default replaced the requested output"
cat "$build_dir/missing.stdout" "$build_dir/missing.stderr" >"$build_dir/missing.diagnostic"
rg -F 'Native backend driver discovery error:' "$build_dir/missing.diagnostic" >/dev/null ||
  fail "missing-worker diagnostic drifted"
! rg -F '#include' "$build_dir/missing.stdout" >/dev/null ||
  fail "failed bare default emitted fallback C"
"$missing_bin/gust" --backend c "$missing_source" >"$build_dir/missing-explicit.c" \
  2>"$build_dir/missing-explicit.stderr"
cmp -s "$build_dir/c.c" "$build_dir/missing-explicit.c" ||
  fail "explicit rollback depends on native siblings"

echo "$guard: ok"
