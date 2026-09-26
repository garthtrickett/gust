#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_ffi_position_policy"
rm -rf "$build_root"
mkdir -p "$build_root"
make build/gust-runtime-package.a
test -x ./gust
# Actions artifacts preserve the driver bytes but strip executable mode.
test -f build/gust-native-backend
chmod +x build/gust-native-backend
test -x build/gust-native-backend
runtime_driver="$PWD/build/gust-native-backend"

# The compiler-owned metadata witness runs as an isolated native Gust program.
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
GUST_NATIVE_BACKEND_DRIVER="$runtime_driver" \
  ./gust --backend cranelift -o "$build_root/policy-metadata" \
    compiler/phase26_ffi_position_policy_test_entry.gst \
    >"$build_root/policy-metadata.compile.stdout" \
    2>"$build_root/policy-metadata.compile.stderr"
test ! -s "$build_root/policy-metadata.compile.stdout"
test ! -s "$build_root/policy-metadata.compile.stderr"
"$build_root/policy-metadata" >"$build_root/policy-metadata.stdout" \
  2>"$build_root/policy-metadata.stderr"
printf '%s\n' 'SUCCESS: FFI per-position ownership metadata verified' \
  >"$build_root/policy-metadata.expected"
cmp -s "$build_root/policy-metadata.expected" "$build_root/policy-metadata.stdout"
test ! -s "$build_root/policy-metadata.stderr"

# The already-qualified scalar extern path still executes with exact status.
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
GUST_NATIVE_BACKEND_DRIVER="$runtime_driver" \
  ./gust --backend cranelift -o "$build_root/scalar-native" \
    compiler/phase13_runtime_add_i32_source.gst \
    >"$build_root/scalar.compile.stdout" 2>"$build_root/scalar.compile.stderr"
test ! -s "$build_root/scalar.compile.stdout"
test ! -s "$build_root/scalar.compile.stderr"
set +e
"$build_root/scalar-native" >"$build_root/scalar.stdout" \
  2>"$build_root/scalar.stderr"
scalar_status=$?
set -e
test "$scalar_status" -eq 42
test ! -s "$build_root/scalar.stdout"
test ! -s "$build_root/scalar.stderr"

poison="$build_root/poison-driver"
poison_marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >"$GUST_PHASE26_D1_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"

# The annotated borrow call passes canonical typechecking. External string
# parameter lowering still has the pre-existing Phase 13 target ABI deferral.
set +e
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
GUST_PHASE26_D1_POISON_MARKER="$poison_marker" \
GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
  ./gust --backend cranelift -o "$build_root/borrow-read-native" \
    compiler/phase26_ffi_borrow_read_source.gst \
    >"$build_root/borrow-read.stdout" 2>"$build_root/borrow-read.stderr"
borrow_status=$?
set -e
test "$borrow_status" -ne 0
rg -F 'decision=deferred capability=phase13_generic_source_to_mir' \
  "$build_root/borrow-read.stdout" >/dev/null
rg -F 'reason_code=deferred_p13_parameter_argument_target_dependent_abi' \
  "$build_root/borrow-read.stdout" >/dev/null
rg -F 'expected_failure_stage=before_driver_discovery' \
  "$build_root/borrow-read.stdout" >/dev/null
rg -F 'class=unsupported_native_capability' \
  "$build_root/borrow-read.stdout" >/dev/null
test ! -s "$build_root/borrow-read.stderr"
test ! -e "$build_root/borrow-read-native"
test ! -e "$poison_marker"

negatives=(
  'unannotated_pointer|FFIBorrowPolicyRequired'
  'transfer|FFITransferRetainUnsupported'
  'retain|FFITransferRetainUnsupported'
  'callback|FFICallbackNativeErrorUnsupported'
  'native_error|FFICallbackNativeErrorUnsupported'
  'returned_pointer|FFIReturnedPointerUnsupported'
  'aggregate|FFIByValueAggregateUnsupported'
  'write_nonraw|FFIWriteRequiresRawPointer'
  'nonextern_attribute|FFIAttributeNonExtern'
  'unsafe_call|Direct external/native function calls require an explicit'
)
for entry in "${negatives[@]}"; do
  name="${entry%%|*}"
  reason="${entry#*|}"
  source="compiler/phase26_ffi_${name}_invalid.gst"
  test -f "$source"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_D1_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$build_root/$name-native" "$source" \
      >"$build_root/$name.stdout" 2>"$build_root/$name.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  rg -F 'TypeError in' "$build_root/$name.stdout" >/dev/null
  rg -F "$reason" "$build_root/$name.stdout" >/dev/null
  test ! -s "$build_root/$name.stderr"
  test ! -e "$build_root/$name-native"
  test ! -e "$poison_marker"
done
if find "$build_root" -maxdepth 1 -type f \
    \( -name '*.c' -o -name '*.phase10.bundle' -o -name '*.phase10.request' \) \
    -print -quit | grep -q .; then
  echo 'Phase 26 FFI position guard found C or transient MIR artifacts' >&2
  exit 1
fi
printf '%s\n' '✅ Phase 26.1D1 FFI position policy passed (native metadata and scalar execution; borrow ABI explicitly deferred)'
