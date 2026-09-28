#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_computed_zero_raw_null"
rm -rf "$build_root"
mkdir -p "$build_root"
make build/gust-runtime-package.a
test -x ./gust
test -f build/gust-native-backend
driver="$PWD/build/gust-native-backend"

GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
  ./gust --backend cranelift -o "$build_root/typechecker" \
    compiler/phase26_computed_zero_test_entry.gst \
    >"$build_root/typechecker.compile.stdout" 2>"$build_root/typechecker.compile.stderr"
test ! -s "$build_root/typechecker.compile.stdout"
test ! -s "$build_root/typechecker.compile.stderr"
"$build_root/typechecker" >"$build_root/typechecker.stdout" 2>"$build_root/typechecker.stderr"
test ! -s "$build_root/typechecker.stderr"
printf 'SUCCESS: computed-zero raw-pointer safe-boundary value table and flow verified\n' >"$build_root/typechecker.expected"
cmp -s "$build_root/typechecker.expected" "$build_root/typechecker.stdout"

poison="$build_root/poison-driver"
marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
printf 'invoked\n' >"$GUST_PHASE26_COMPUTED_ZERO_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"

for case_name in sum_return sum_call local_call branch_call; do
  fixture="compiler/phase26_computed_zero_safe_${case_name}_source.gst"
  rm -f "$marker" "$build_root/$case_name"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_COMPUTED_ZERO_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$build_root/$case_name" "$fixture" \
      >"$build_root/$case_name.stdout" 2>"$build_root/$case_name.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  case "$case_name" in
    sum_return) anchor='line 2:22'; boundary='function return' ;;
    sum_call) anchor='line 3:26'; boundary='function argument' ;;
    local_call) anchor='line 3:37'; boundary='function argument' ;;
    branch_call) anchor='line 3:53'; boundary='function argument' ;;
  esac
  rg -F "TypeError in $fixture at $anchor" "$build_root/$case_name.stdout" >/dev/null
  rg -F "[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe $boundary" "$build_root/$case_name.stdout" >/dev/null
  if rg -F 'gust_native_capability_decision' "$build_root/$case_name.stdout" >/dev/null; then exit 1; fi
  test ! -s "$build_root/$case_name.stderr"
  test ! -e "$build_root/$case_name"
  test ! -e "$marker"
done

bash scripts/phase26_raw_null_safe_boundary.sh
echo 'Phase26.1E computed-zero raw-null safe-boundary and no-fallback evidence passed.'
