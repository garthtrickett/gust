#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_ffi_raw_return"
rm -rf "$build_root"
mkdir -p "$build_root"
make build/gust-runtime-package.a
test -x ./gust
test -f build/gust-native-backend
chmod +x build/gust-native-backend
driver="$PWD/build/gust-native-backend"

GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
  ./gust --backend cranelift -o "$build_root/positive" \
    compiler/phase26_ffi_raw_return_source.gst \
    >"$build_root/positive.compile.stdout" 2>"$build_root/positive.compile.stderr"
test ! -s "$build_root/positive.compile.stdout"
test ! -s "$build_root/positive.compile.stderr"
"$build_root/positive" >"$build_root/positive.stdout" 2>"$build_root/positive.stderr"
printf '37\n' >"$build_root/positive.expected"
cmp -s "$build_root/positive.expected" "$build_root/positive.stdout"
test ! -s "$build_root/positive.stderr"

GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
  ./gust --backend cranelift -o "$build_root/provenance" \
    compiler/phase26_ffi_raw_return_policy_test_entry.gst \
    >"$build_root/provenance.compile.stdout" 2>"$build_root/provenance.compile.stderr"
test ! -s "$build_root/provenance.compile.stdout"
test ! -s "$build_root/provenance.compile.stderr"
"$build_root/provenance" >"$build_root/provenance.stdout" 2>"$build_root/provenance.stderr"
printf 'SUCCESS: unowned extern raw return remains raw-derived and unbrandable\n' >"$build_root/provenance.expected"
cmp -s "$build_root/provenance.expected" "$build_root/provenance.stdout"
test ! -s "$build_root/provenance.stderr"

poison="$build_root/poison-driver"
marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
printf 'invoked\n' >"$GUST_PHASE26_D4_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"

for case_name in missing unknown_host wrong_inner reference str slice transfer scalar_policy nonextern unsafe_call unsafe_deref; do
  output="$build_root/$case_name"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_D4_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" \
      "compiler/phase26_ffi_raw_return_${case_name}_source.gst" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  case "$case_name" in
    unknown_host|wrong_inner)
      rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
      rg -F 'reason_code=deferred_p26_ffi_raw_return_host_contract' "$output.stdout" >/dev/null
      rg -F 'expected_failure_stage=before_driver_discovery' "$output.stdout" >/dev/null
      rg -F "source=compiler/phase26_ffi_raw_return_${case_name}_source.gst" "$output.stdout" >/dev/null
      rg -F 'class=unsupported_native_capability' "$output.stdout" >/dev/null
      ;;
    missing|reference|str|slice|transfer)
      rg -F '[FFIReturnedPointerUnsupported]' "$output.stdout" >/dev/null
      ;;
    scalar_policy) rg -F '[FFIValuePolicy]' "$output.stdout" >/dev/null ;;
    nonextern) rg -F '[FFIAttributeNonExtern]' "$output.stdout" >/dev/null ;;
    unsafe_call) rg -F "Direct external/native function calls require an explicit 'unsafe' block" "$output.stdout" >/dev/null ;;
    unsafe_deref) rg -F "Dereferencing raw pointers is strictly prohibited outside 'unsafe' blocks" "$output.stdout" >/dev/null ;;
  esac
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

echo 'Phase26.1D4 unowned raw return, raw-derived provenance, and no-fallback evidence passed.'
