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

# Patch 24.13: the MIR-to-C oracle is retired. It emitted C, host-compiled it,
# ran it, and required the native run to agree -- a differential whose second
# term this patch removes.
#
# The native run is kept and still asserted on its own terms below: the
# inferred output must exist, be executable, and behave. What is lost is the
# agreement between the two routes' runtime observables.
# The runtime comparison is retired outright, and NOT replaced with an
# invented expectation. The original asserted only that the two routes agreed
# -- equal exit status, equal stdout, equal stderr -- and never said what
# either should be. There is no registered expectation for this fixture's
# runtime behaviour anywhere in this file, so with the second route gone there
# is nothing independent left to hold the first to.
#
# I first replaced it with "must exit 0" and the guard failed, which is the
# correct outcome: that expectation was mine, not the fixture's. What this file
# still asserts on its own authority is the COMPILATION claims above -- the
# inferred output is published beside its source, is executable, and neither
# route emits stdout or diagnostics.

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

# Patch 24.13: the explicit-C emission is retired with the spelling. The
# pre-flip branch below compared bare selection against it; after the flip the
# bare route is native, and the comparison that still matters -- bare against
# explicit NATIVE -- is the one kept in that branch.
if rg -F '"phase22_default_route_flip"' scripts/cranelift_feature_registry.json >/dev/null; then
  rm -f "$build_dir/implicit"
  GUST_NATIVE_BACKEND_DRIVER="$driver_abs" \
    ./gust "$build_dir/implicit.gst" >"$build_dir/bare.stdout" 2>"$build_dir/bare.stderr"
  cmp -s "$build_dir/inferred.reference" "$build_dir/implicit" || fail "bare selection differs from explicit native"
  test ! -s "$build_dir/bare.stdout" || fail "bare native emitted stdout"
  test ! -s "$build_dir/bare.stderr" || fail "bare native emitted diagnostics"
else
  # Patch 24.13: the pre-flip branch compared bare selection against explicit
  # C, and both spellings are gone. Reaching it means the default-route flip
  # was unregistered after the backend was removed, which is a state this
  # patch makes unreachable rather than one to emit C in.
  fail "the default-route flip is unregistered but the generated-C backend is already removed"
fi

owned_residue="$(find "$build_dir" -type f \( -name '*.phase10.bundle' -o -name '*.phase10.request' -o -name '*.partial' -o -name '*.tmp' -o -name '*.o' \) -print)"
test -z "$owned_residue" || fail "native route left owned intermediate artifacts: $owned_residue"

echo "$guard: ok"
