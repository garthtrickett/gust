#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_safe_reference_call"
rm -rf "$build_root"
mkdir -p "$build_root"
make build/gust-runtime-package.a
test -x ./gust
test -f build/gust-native-backend
driver="$PWD/build/gust-native-backend"

for case_name in source test_entry; do
  fixture="compiler/phase26_safe_reference_call_${case_name}.gst"
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
    ./gust --backend cranelift -o "$build_root/$case_name" "$fixture" \
      >"$build_root/$case_name.compile.stdout" 2>"$build_root/$case_name.compile.stderr"
  test ! -s "$build_root/$case_name.compile.stdout"
  test ! -s "$build_root/$case_name.compile.stderr"
  "$build_root/$case_name" >"$build_root/$case_name.stdout" 2>"$build_root/$case_name.stderr"
  test ! -s "$build_root/$case_name.stderr"
done
printf '42\n7\n' >"$build_root/source.expected"
cmp -s "$build_root/source.expected" "$build_root/source.stdout"
printf 'SUCCESS: safe-call Reference provenance boundary verified\n' >"$build_root/test_entry.expected"
cmp -s "$build_root/test_entry.expected" "$build_root/test_entry.stdout"

poison="$build_root/poison-driver"
marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
printf 'invoked\n' >"$GUST_PHASE26_E3_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"

set +e
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
GUST_PHASE26_E3_POISON_MARKER="$PWD/$marker" \
GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
  ./gust --backend cranelift -o "$build_root/escaped" \
    compiler/phase26_safe_reference_call_escape_source.gst \
    >"$build_root/escaped.stdout" 2>"$build_root/escaped.stderr"
status=$?
set -e
test "$status" -ne 0
rg -F 'TypeError in compiler/phase26_safe_reference_call_escape_source.gst at line 9:17' "$build_root/escaped.stdout" >/dev/null
rg -F '[UnsafeReferenceEscape] Raw-derived or isolated-origin Reference cannot cross a safe function call' "$build_root/escaped.stdout" >/dev/null
if rg -F 'gust_native_capability_decision' "$build_root/escaped.stdout" >/dev/null; then exit 1; fi
test ! -s "$build_root/escaped.stderr"
test ! -e "$build_root/escaped"
test ! -e "$marker"

set +e
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
GUST_PHASE26_E3_POISON_MARKER="$PWD/$marker" \
GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
  ./gust --backend cranelift -o "$build_root/mismatch" \
    compiler/phase26_safe_reference_call_mismatch_source.gst \
    >"$build_root/mismatch.stdout" 2>"$build_root/mismatch.stderr"
status=$?
set -e
test "$status" -ne 0
rg -F 'Argument type mismatch' "$build_root/mismatch.stdout" >/dev/null
if rg -F '[UnsafeReferenceEscape]' "$build_root/mismatch.stdout" >/dev/null; then exit 1; fi
if rg -F 'gust_native_capability_decision' "$build_root/mismatch.stdout" >/dev/null; then exit 1; fi
test ! -s "$build_root/mismatch.stderr"
test ! -e "$build_root/mismatch"
test ! -e "$marker"

echo 'Phase26.1E3 safe-call Reference provenance and no-fallback evidence passed.'
