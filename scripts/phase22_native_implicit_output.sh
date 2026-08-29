#!/usr/bin/env bash
set -euo pipefail

guard="guard-cranelift-phase22-native-implicit-output-evidence"
build_dir="build/guards/cranelift_phase22_native_implicit_output"
fixture="compiler/phase11_scalar_unsupported_multiply_source.gst"
driver="build/phase10-package/bin/gust-native-backend"

fail() {
  echo "$guard: $1" >&2
  exit 1
}

test -x ./gust || fail "requires the built ./gust compiler"
test -x "$driver" || fail "requires the packaged native driver"

rm -rf "$build_dir"
mkdir -p "$build_dir"
cp "$fixture" "$build_dir/implicit.gst"
driver_abs="$PWD/$driver"

# The inferred intent and its equivalent explicit spelling share one route and
# publish byte-identical native executables with the MIR-to-C oracle behavior.
GUST_NATIVE_BACKEND_DRIVER="$driver_abs" \
  ./gust --backend cranelift "$build_dir/implicit.gst" \
  >"$build_dir/inferred.stdout" 2>"$build_dir/inferred.stderr"
test -x "$build_dir/implicit" || fail "inferred output was not published beside its source"
test ! -s "$build_dir/inferred.stdout" || fail "inferred compilation emitted stdout"
test ! -s "$build_dir/inferred.stderr" || fail "inferred compilation emitted stderr"
cp "$build_dir/implicit" "$build_dir/inferred.reference"

GUST_NATIVE_BACKEND_DRIVER="$driver_abs" \
  ./gust --backend cranelift -o "$build_dir/implicit" "$build_dir/implicit.gst" \
  >"$build_dir/explicit.stdout" 2>"$build_dir/explicit.stderr"
test ! -s "$build_dir/explicit.stdout" || fail "equivalent explicit compilation emitted stdout"
test ! -s "$build_dir/explicit.stderr" || fail "equivalent explicit compilation emitted stderr"
cmp -s "$build_dir/inferred.reference" "$build_dir/implicit" ||
  fail "inferred and equivalent explicit executables differ"

./gust --backend mir-to-c "$build_dir/implicit.gst" >"$build_dir/oracle.c" 2>"$build_dir/oracle.stderr"
test ! -s "$build_dir/oracle.stderr" || fail "MIR-to-C oracle emitted diagnostics"
cat src/runtime.c "$build_dir/oracle.c" >"$build_dir/oracle-final.c"
"${CC:-cc}" ${CFLAGS:--O2 -Wall -pthread} ${INCLUDES:--Isrc} \
  "$build_dir/oracle-final.c" -o "$build_dir/oracle"

set +e
"$build_dir/implicit" >"$build_dir/native.stdout" 2>"$build_dir/native.stderr"
native_status="$?"
"$build_dir/oracle" >"$build_dir/oracle.stdout" 2>"$build_dir/oracle.runtime.stderr"
oracle_status="$?"
set -e
test "$native_status" -eq "$oracle_status" || fail "native exit status differs from MIR-to-C"
cmp -s "$build_dir/native.stdout" "$build_dir/oracle.stdout" || fail "native stdout differs from MIR-to-C"
cmp -s "$build_dir/native.stderr" "$build_dir/oracle.runtime.stderr" || fail "native stderr differs from MIR-to-C"

# Existing inferred outputs are replaceable on success. Explicit output paths
# remain opaque, including names that happen to carry a .gst suffix.
printf '%s\n' 'phase22-success-replacement-sentinel' >"$build_dir/implicit"
GUST_NATIVE_BACKEND_DRIVER="$driver_abs" \
  ./gust --backend cranelift "$build_dir/implicit.gst" \
  >"$build_dir/replace.stdout" 2>"$build_dir/replace.stderr"
test -x "$build_dir/implicit" || fail "successful inference did not replace the existing output"
! rg -F 'phase22-success-replacement-sentinel' "$build_dir/implicit" >/dev/null ||
  fail "successful inference preserved the old sentinel"

opaque_output="$build_dir/explicit.opaque.gst"
GUST_NATIVE_BACKEND_DRIVER="$driver_abs" \
  ./gust --backend cranelift -o "$opaque_output" "$build_dir/implicit.gst" \
  >"$build_dir/opaque.stdout" 2>"$build_dir/opaque.stderr"
test -x "$opaque_output" || fail "explicit -o was not treated as opaque and authoritative"

# A driver failure must preserve an existing inferred final path and clean its
# request/bundle intermediates.
failure_marker="$build_dir/failure-driver.invoked"
failure_driver="$build_dir/failure-driver"
cat >"$failure_driver" <<'EOF_FAILURE_DRIVER'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' invoked >"${GUST_PHASE22_FAILURE_MARKER:?}"
exit 71
EOF_FAILURE_DRIVER
chmod +x "$failure_driver"
printf '%s\n' 'phase22-failure-preservation-sentinel' >"$build_dir/implicit"
cp "$build_dir/implicit" "$build_dir/implicit.sentinel"
set +e
GUST_PHASE22_FAILURE_MARKER="$PWD/$failure_marker" \
GUST_NATIVE_BACKEND_DRIVER="$PWD/$failure_driver" \
  ./gust --backend cranelift "$build_dir/implicit.gst" \
  >"$build_dir/driver-failure.stdout" 2>"$build_dir/driver-failure.stderr"
driver_failure_status="$?"
set -e
test "$driver_failure_status" -ne 0 || fail "failing driver unexpectedly succeeded"
test -f "$failure_marker" || fail "driver-failure witness did not reach the driver"
cmp -s "$build_dir/implicit.sentinel" "$build_dir/implicit" ||
  fail "driver failure changed the existing inferred output"

# Malformed or colliding inferred intents reject in invocation parsing, before
# source, native-driver, or artifact access.
reject_marker="$build_dir/reject-driver.invoked"
reject_driver="$build_dir/reject-driver"
cat >"$reject_driver" <<'EOF_REJECT_DRIVER'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' invoked >"${GUST_PHASE22_REJECT_MARKER:?}"
exit 72
EOF_REJECT_DRIVER
chmod +x "$reject_driver"

reject_intent() {
  local case_name="$1"
  local source_path="$2"
  local diagnostic="$3"
  set +e
  GUST_PHASE22_REJECT_MARKER="$PWD/$reject_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$reject_driver" \
    ./gust --backend cranelift "$source_path" \
    >"$build_dir/$case_name.stdout" 2>"$build_dir/$case_name.stderr"
  local status="$?"
  set -e
  test "$status" -ne 0 || fail "$case_name unexpectedly succeeded"
  rg -F "$diagnostic" "$build_dir/$case_name.stdout" >/dev/null ||
    fail "$case_name diagnostic drifted"
  test ! -s "$build_dir/$case_name.stderr" || fail "$case_name emitted stderr"
  test ! -e "$reject_marker" || fail "$case_name reached native-driver discovery"
}

reject_intent wrong-suffix "$build_dir/program.GST" \
  'Compiler invocation error: implicit Cranelift output requires a source path ending in .gst'
reject_intent empty-stem "$build_dir/.gst" \
  'Compiler invocation error: implicit Cranelift output requires a non-empty portable source stem'
reject_intent dotdot-stem "$build_dir/...gst" \
  'Compiler invocation error: implicit Cranelift output requires a non-empty portable source stem'
reject_intent source-collision "$build_dir/program.gst.gst" \
  'Compiler invocation error: implicit Cranelift output would collide with a Gust source path'

missing_source="$build_dir/missing/parent/program.gst"
set +e
GUST_PHASE22_REJECT_MARKER="$PWD/$reject_marker" \
GUST_NATIVE_BACKEND_DRIVER="$PWD/$reject_driver" \
  ./gust --backend cranelift "$missing_source" \
  >"$build_dir/missing-source.stdout" 2>"$build_dir/missing-source.stderr"
missing_status="$?"
set -e
test "$missing_status" -ne 0 || fail "missing inferred source unexpectedly succeeded"
test ! -e "$build_dir/missing" || fail "inference created a missing source/output directory"
test ! -e "$reject_marker" || fail "missing source reached native-driver discovery"

# Bare selection remains the unchanged C route.
./gust "$build_dir/implicit.gst" >"$build_dir/bare.c" 2>"$build_dir/bare.stderr"
./gust --backend c "$build_dir/implicit.gst" >"$build_dir/explicit-c.c" 2>"$build_dir/explicit-c.stderr"
cmp -s "$build_dir/bare.c" "$build_dir/explicit-c.c" || fail "bare selection no longer matches explicit C"
test ! -s "$build_dir/bare.stderr" || fail "bare C emitted diagnostics"
test ! -s "$build_dir/explicit-c.stderr" || fail "explicit C emitted diagnostics"

owned_residue="$(find "$build_dir" -type f \( -name '*.phase10.bundle' -o -name '*.phase10.request' -o -name '*.partial' -o -name '*.tmp' -o -name '*.o' \) -print)"
test -z "$owned_residue" || fail "native route left owned intermediate artifacts: $owned_residue"

echo "$guard: ok"
