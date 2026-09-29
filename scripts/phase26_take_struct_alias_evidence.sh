#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_take_struct_alias_evidence"
mkdir -p "$build_root"
make build/gust-runtime-package.a
test -x ./gust
test -f build/gust-native-backend
driver="$PWD/build/gust-native-backend"

GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
  ./gust --backend cranelift -o "$build_root/typechecker" \
    compiler/phase26_take_struct_alias_test_entry.gst \
    >"$build_root/typechecker.compile.stdout" 2>"$build_root/typechecker.compile.stderr"
test ! -s "$build_root/typechecker.compile.stdout"
test ! -s "$build_root/typechecker.compile.stderr"
"$build_root/typechecker" >"$build_root/typechecker.stdout" 2>"$build_root/typechecker.stderr"
test ! -s "$build_root/typechecker.stderr"
printf 'SUCCESS: taken local Struct field evidence and controls verified\n' >"$build_root/typechecker.expected"
cmp -s "$build_root/typechecker.expected" "$build_root/typechecker.stdout"

poison="$build_root/poison-driver"
marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
printf 'invoked\n' >"$GUST_PHASE26_TAKE_STRUCT_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"
for case_name in decl assign nonzero; do
  fixture="compiler/phase26_take_struct_alias_${case_name}_source.gst"
  output="$build_root/$case_name"
  rm -f "$output" "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_TAKE_STRUCT_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" "$fixture" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  if [ "$case_name" = nonzero ]; then
    rg -F 'reason_code=deferred_p13_parameter_argument_target_dependent_abi' "$output.stdout" >/dev/null
    if rg -F 'TypeError in' "$output.stdout" >/dev/null; then exit 1; fi
  else
    if [ "$case_name" = decl ]; then line=5; else line=6; fi
    rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
    rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function argument' "$output.stdout" >/dev/null
    if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
  fi
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

bash scripts/phase26_take_zero_evidence.sh
echo 'Phase26.1E local Struct Take-alias evidence and no-fallback passed.'
