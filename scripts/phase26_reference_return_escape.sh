#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_reference_return_escape"
rm -rf "$build_root"
mkdir -p "$build_root"
make build/gust-runtime-package.a
test -x ./gust
test -f build/gust-native-backend
driver="$PWD/build/gust-native-backend"

GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
  ./gust --backend cranelift -o "$build_root/typechecker" \
    compiler/phase26_reference_return_escape_test_entry.gst \
    >"$build_root/typechecker.compile.stdout" 2>"$build_root/typechecker.compile.stderr"
test ! -s "$build_root/typechecker.compile.stdout"
test ! -s "$build_root/typechecker.compile.stderr"
"$build_root/typechecker" >"$build_root/typechecker.stdout" 2>"$build_root/typechecker.stderr"
printf 'SUCCESS: unbranded Reference return escape boundary verified\n' >"$build_root/typechecker.expected"
cmp -s "$build_root/typechecker.expected" "$build_root/typechecker.stdout"
test ! -s "$build_root/typechecker.stderr"

poison="$build_root/poison-driver"
marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
printf 'invoked\n' >"$GUST_PHASE26_E2_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"

set +e
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
GUST_PHASE26_E2_POISON_MARKER="$PWD/$marker" \
GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
  ./gust --backend cranelift -o "$build_root/escaped" \
    compiler/phase26_reference_return_escape_source.gst \
    >"$build_root/escaped.stdout" 2>"$build_root/escaped.stderr"
status=$?
set -e
test "$status" -ne 0
rg -F 'TypeError in compiler/phase26_reference_return_escape_source.gst at line 5:16' "$build_root/escaped.stdout" >/dev/null
rg -F '[UnsafeReferenceEscape] Raw-derived or isolated-origin Reference cannot escape through a function return' "$build_root/escaped.stdout" >/dev/null
if rg -F 'gust_native_capability_decision' "$build_root/escaped.stdout" >/dev/null; then exit 1; fi
if rg -F 'decision=supported' "$build_root/escaped.stdout" >/dev/null; then exit 1; fi
test ! -s "$build_root/escaped.stderr"
test ! -e "$build_root/escaped"
test ! -e "$marker"

set +e
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
GUST_PHASE26_E2_POISON_MARKER="$PWD/$marker" \
GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
  ./gust --backend cranelift -o "$build_root/safe" \
    compiler/phase26_reference_return_safe_source.gst \
    >"$build_root/safe.stdout" 2>"$build_root/safe.stderr"
status=$?
set -e
test "$status" -ne 0
rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$build_root/safe.stdout" >/dev/null
rg -F 'reason_code=deferred_p13_parameter_argument_target_dependent_abi' "$build_root/safe.stdout" >/dev/null
rg -F 'expected_failure_stage=before_driver_discovery' "$build_root/safe.stdout" >/dev/null
if rg -F '[UnsafeReferenceEscape]' "$build_root/safe.stdout" >/dev/null; then exit 1; fi
test ! -s "$build_root/safe.stderr"
test ! -e "$build_root/safe"
test ! -e "$marker"

echo 'Phase26.1E2 Reference return escape and no-fallback evidence passed.'
