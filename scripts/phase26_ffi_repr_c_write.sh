#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_ffi_repr_c_write"
rm -rf "$build_root"
mkdir -p "$build_root"
make build/gust-runtime-package.a
test -x ./gust
test -f build/gust-native-backend
chmod +x build/gust-native-backend
driver="$PWD/build/gust-native-backend"

# The selected test-only host writes through the existing raw-pointer ABI.
# Before/after observations prove that the 4-byte Int at offset 4 and the
# trailing Byte at offset 8 changed in the caller's original repr(C) object.
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
  ./gust --backend cranelift -o "$build_root/native" \
    compiler/phase26_ffi_repr_c_write_source.gst \
    >"$build_root/positive.compile.stdout" 2>"$build_root/positive.compile.stderr"
test ! -s "$build_root/positive.compile.stdout"
test ! -s "$build_root/positive.compile.stderr"
"$build_root/native" >"$build_root/positive.stdout" 2>"$build_root/positive.stderr"
printf '20\n30\n4\n' >"$build_root/positive.expected"
cmp -s "$build_root/positive.expected" "$build_root/positive.stdout"
test ! -s "$build_root/positive.stderr"

poison="$build_root/poison-driver"
marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
printf 'invoked\n' >"$GUST_PHASE26_D3_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"

for case_name in missing order packed nested unknown_host enum; do
  output="$build_root/$case_name"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_D3_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" \
      "compiler/phase26_ffi_repr_c_write_${case_name}_source.gst" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  if test "$case_name" = unknown_host; then
    # This fixture passes a local raw-pointer alias. Generic direct Call 4
    # rejects that origin during canonical validation, before driver use.
    rg -F 'decision=source_or_type_failure capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
    rg -F 'class=canonical_mir_verification_error' "$output.stdout" >/dev/null
    rg -F 'Native backend canonical MIR verification failed' "$output.stderr" >/dev/null
    test ! -e "$output"
    test ! -e "$marker"
    continue
  fi
  rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
  rg -F 'reason_code=deferred_p26_ffi_borrowed_c_layout' "$output.stdout" >/dev/null
  rg -F 'expected_failure_stage=before_driver_discovery' "$output.stdout" >/dev/null
  rg -F "source=compiler/phase26_ffi_repr_c_write_${case_name}_source.gst" "$output.stdout" >/dev/null
  rg -F 'class=unsupported_native_capability' "$output.stdout" >/dev/null
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

echo 'Phase26.1D3 borrowed repr(C) raw-pointer write and no-fallback evidence passed.'
