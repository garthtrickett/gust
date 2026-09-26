#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_ffi_repr_c_layout"
rm -rf "$build_root"
mkdir -p "$build_root"
make build/gust-runtime-package.a
test -x ./gust
test -f build/gust-native-backend
chmod +x build/gust-native-backend
driver="$PWD/build/gust-native-backend"

# The padded byte/int/byte aggregate has C offsets 0/4/8 and size 12.
# Its selected test host reads all three fields through the native pointer.
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
  ./gust --backend cranelift -o "$build_root/native" \
    compiler/phase26_ffi_repr_c_probe_source.gst \
    >"$build_root/positive.compile.stdout" 2>"$build_root/positive.compile.stderr"
test ! -s "$build_root/positive.compile.stdout"
test ! -s "$build_root/positive.compile.stderr"
"$build_root/native" >"$build_root/positive.stdout" 2>"$build_root/positive.stderr"
printf '24\n' >"$build_root/positive.expected"
cmp -s "$build_root/positive.expected" "$build_root/positive.stdout"
test ! -s "$build_root/positive.stderr"

poison="$build_root/poison-driver"
marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
printf 'invoked\n' >"$GUST_PHASE26_D2_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"

for case_name in missing order packed nested unknown_host enum; do
  output="$build_root/$case_name"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_D2_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" \
      "compiler/phase26_ffi_repr_c_${case_name}_source.gst" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
  rg -F 'reason_code=deferred_p26_ffi_borrowed_c_layout' "$output.stdout" >/dev/null
  rg -F 'expected_failure_stage=before_driver_discovery' "$output.stdout" >/dev/null
  rg -F "source=compiler/phase26_ffi_repr_c_${case_name}_source.gst" "$output.stdout" >/dev/null
  rg -F 'class=unsupported_native_capability' "$output.stdout" >/dev/null
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

# D1's independent by-value aggregate contract must still reject at source.
set +e
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
GUST_PHASE26_D2_POISON_MARKER="$PWD/$marker" \
GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
  ./gust --backend cranelift -o "$build_root/by-value" \
    compiler/phase26_ffi_aggregate_invalid.gst \
    >"$build_root/by-value.stdout" 2>"$build_root/by-value.stderr"
status=$?
set -e
test "$status" -ne 0
rg -F '[FFIByValueAggregateUnsupported]' "$build_root/by-value.stdout" >/dev/null
test ! -s "$build_root/by-value.stderr"
test ! -e "$build_root/by-value"
test ! -e "$marker"

echo 'Phase26.1D2 borrowed repr(C) native layout and no-fallback evidence passed.'
