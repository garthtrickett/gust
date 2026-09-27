#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_raw_cast_provenance"
rm -rf "$build_root"
mkdir -p "$build_root"
make build/gust-runtime-package.a
test -x ./gust
test -f build/gust-native-backend
chmod +x build/gust-native-backend
driver="$PWD/build/gust-native-backend"

GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
  ./gust --backend cranelift -o "$build_root/provenance" \
    compiler/phase26_raw_cast_provenance_test_entry.gst \
    >"$build_root/provenance.compile.stdout" 2>"$build_root/provenance.compile.stderr"
test ! -s "$build_root/provenance.compile.stdout"
test ! -s "$build_root/provenance.compile.stderr"
"$build_root/provenance" >"$build_root/provenance.stdout" 2>"$build_root/provenance.stderr"
printf 'SUCCESS: raw-pointer cast provenance, safe-brand rejection, and bare-null sentinel verified\n' \
  >"$build_root/provenance.expected"
cmp -s "$build_root/provenance.expected" "$build_root/provenance.stdout"
test ! -s "$build_root/provenance.stderr"

poison="$build_root/poison-driver"
marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
printf 'invoked\n' >"$GUST_PHASE26_E1_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"

# Direct source casts are still outside the qualified native source route.
# They must remain explicit pre-driver deferrals rather than C fallback.
for case_name in unsafe safe_brand_rejected; do
  output="$build_root/$case_name"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_E1_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" \
      "compiler/phase26_raw_cast_${case_name}_source.gst" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  if [ "$case_name" = "safe_brand_rejected" ]; then
    rg -F 'TypeError in compiler/phase26_raw_cast_safe_brand_rejected_source.gst at line 7:40' "$output.stdout" >/dev/null
    rg -F 'Semantic Error: Non-laundering violation. Binding raw-derived or sandbox-derived value as safe branded type Index("int", Some("ctx")) is prohibited' "$output.stdout" >/dev/null
    if rg -F 'decision=supported' "$output.stdout" >/dev/null; then exit 1; fi
  else
    rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
    rg -F 'reason_code=source_feature_not_represented' "$output.stdout" >/dev/null
    rg -F 'expected_failure_stage=before_driver_discovery' "$output.stdout" >/dev/null
    rg -F "source=compiler/phase26_raw_cast_${case_name}_source.gst" "$output.stdout" >/dev/null
    rg -F 'class=unsupported_native_capability' "$output.stdout" >/dev/null
  fi
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

echo 'Phase26.1E1 raw cast provenance, safe-brand rejection, and native no-fallback evidence passed.'
