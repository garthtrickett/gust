#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_nested_field_zero_evidence"
mkdir -p "$build_root"
make build/gust-runtime-package.a
test -x ./gust
test -f build/gust-native-backend
driver="$PWD/build/gust-native-backend"

GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
  ./gust --backend cranelift -o "$build_root/typechecker" \
    compiler/phase26_nested_field_zero_test_entry.gst \
    >"$build_root/typechecker.compile.stdout" 2>"$build_root/typechecker.compile.stderr"
test ! -s "$build_root/typechecker.compile.stdout"
test ! -s "$build_root/typechecker.compile.stderr"
"$build_root/typechecker" >"$build_root/typechecker.stdout" 2>"$build_root/typechecker.stderr"
test ! -s "$build_root/typechecker.stderr"
printf 'SUCCESS: nested local by-value field zero evidence and exclusions verified\n' >"$build_root/typechecker.expected"
cmp -s "$build_root/typechecker.expected" "$build_root/typechecker.stdout"

poison="$build_root/poison-driver"
marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
printf 'invoked\n' >"$GUST_PHASE26_NESTED_ZERO_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"

for case_name in safe_call if_join while_join subobject safe_return; do
  fixture="compiler/phase26_nested_field_zero_${case_name}_source.gst"
  output="$build_root/$case_name"
  rm -f "$output" "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_NESTED_ZERO_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" "$fixture" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  line=6
  rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
  if [ "$case_name" = safe_return ]; then
    boundary='function return'
    rg -F "Escape analysis violation. Returning ephemeral view of type RawPointer(Int) whose origin traces back to local stack variable 'outer'" "$output.stdout" >/dev/null
  else
    boundary='function argument'
  fi
  rg -F "[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe $boundary" "$output.stdout" >/dev/null
  if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

# The native nested-selector route is still unsupported. Keep the pre-driver
# classification explicit while the typechecker-only positive runs natively.
unsupported="$build_root/unsupported_nonzero"
rm -f "$unsupported" "$marker"
set +e
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
GUST_PHASE26_NESTED_ZERO_POISON_MARKER="$PWD/$marker" \
GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
  ./gust --backend cranelift -o "$unsupported" \
    compiler/phase26_nested_field_zero_nonzero_source.gst \
    >"$unsupported.stdout" 2>"$unsupported.stderr"
status=$?
set -e
test "$status" -ne 0
rg -F 'reason_code=source_feature_not_represented expected_failure_stage=before_driver_discovery' "$unsupported.stdout" >/dev/null
test ! -s "$unsupported.stderr"
test ! -e "$unsupported"
test ! -e "$marker"

bash scripts/phase26_field_zero_evidence.sh
echo 'Phase26.1E nested local field value evidence and no-fallback passed.'
