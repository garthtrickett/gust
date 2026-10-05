#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_ffi_repr_int"
rm -rf "$build_root"
mkdir -p "$build_root"
test -x ./gust
test -f build/gust-native-backend
driver="$PWD/build/gust-native-backend"

GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
  ./gust --backend cranelift -o "$build_root/native" \
    compiler/phase26_ffi_repr_int_source.gst \
    >"$build_root/positive.stdout" 2>"$build_root/positive.stderr"
test ! -s "$build_root/positive.stdout"
test ! -s "$build_root/positive.stderr"
set +e
"$build_root/native" >"$build_root/runtime.stdout" 2>"$build_root/runtime.stderr"
status=$?
set -e
test "$status" -eq 42
test ! -s "$build_root/runtime.stdout"
test ! -s "$build_root/runtime.stderr"

poison="$build_root/poison-driver"
marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
printf 'invoked\n' >"$GUST_PHASE26_REPR_INT_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"

# An unannotated enum keeps its old layout and has no external value ABI.
sed 's/^#\[repr(int)\] //' compiler/phase26_ffi_repr_int_source.gst >"$build_root/plain.gst"
# Host selection is a separate proof from integer layout selection.
sed 's/tiny_host_echo_repr_int/tiny_host_unapproved_repr_int/g' \
  compiler/phase26_ffi_repr_int_source.gst >"$build_root/unknown_host.gst"
# A payload variant cannot acquire an integer-only physical layout.
sed 's/Zero, One/Zero { payload: int }, One/' \
  compiler/phase26_ffi_repr_int_source.gst >"$build_root/payload.gst"

for case_name in plain unknown_host payload; do
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_REPR_INT_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$build_root/$case_name" \
      "$build_root/$case_name.gst" \
      >"$build_root/$case_name.stdout" 2>"$build_root/$case_name.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  case "$case_name" in
    plain) rg -F '[FFIByValueAggregateUnsupported]' "$build_root/$case_name.stdout" >/dev/null ;;
    unknown_host)
      rg -F 'reason_code=deferred_p26_ffi_borrowed_c_layout' "$build_root/$case_name.stdout" >/dev/null
      rg -F 'expected_failure_stage=before_driver_discovery' "$build_root/$case_name.stdout" >/dev/null
      ;;
    payload) rg -F 'repr(int) enum variants cannot have payload fields' "$build_root/$case_name.stdout" >/dev/null ;;
  esac
  test ! -s "$build_root/$case_name.stderr"
  test ! -e "$build_root/$case_name"
  test ! -e "$marker"
done

echo 'Phase26.1D repr(int) enum native layout, FFI host, and no-fallback evidence passed.'
