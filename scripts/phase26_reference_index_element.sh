#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_reference_index_element"
rm -rf "$build_root"
mkdir -p "$build_root"
test -x ./gust
test -x build/gust-native-backend
test -f build/gust-runtime-package.a
driver="$PWD/build/gust-native-backend"

compile_and_run() {
  local name="$1" source="$2" expected="$3"
  local case_dir="$build_root/$name"
  mkdir -p "$case_dir"
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
    ./gust --backend cranelift -o "$case_dir/program" "$source" \
      >"$case_dir/compile.stdout" 2>"$case_dir/compile.stderr"
  test -x "$case_dir/program"
  test ! -s "$case_dir/compile.stdout"
  test ! -s "$case_dir/compile.stderr"
  "$case_dir/program" >"$case_dir/stdout" 2>"$case_dir/stderr"
  test ! -s "$case_dir/stderr"
  printf '%s' "$expected" >"$case_dir/expected"
  cmp -s "$case_dir/expected" "$case_dir/stdout"
}

compile_and_run borrowed compiler/phase26_reference_index_element_source.gst ''
compile_and_run historical compiler/phase16_reference_receiver_source.gst \
  $'11\n2\n7\n5\nSUCCESS: native reference receivers\n'

marker="$build_root/poison-driver.invoked"
cat >"$build_root/poison-driver" <<'POISON'
#!/usr/bin/env bash
printf 'invoked\n' >"$GUST_PHASE26_R4_POISON_MARKER"
exit 97
POISON
chmod +x "$build_root/poison-driver"
set +e
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
GUST_PHASE26_R4_POISON_MARKER="$PWD/$marker" \
GUST_NATIVE_BACKEND_DRIVER="$PWD/$build_root/poison-driver" \
  ./gust --backend cranelift -o "$build_root/mismatch" \
    compiler/phase26_reference_index_element_mismatch.gst \
    >"$build_root/mismatch.stdout" 2>"$build_root/mismatch.stderr"
status=$?
set -e
test "$status" -ne 0
rg -F '[TypeMismatch] Explicit Type Annotation Mismatch. Declared Byte but got value Bool' \
  "$build_root/mismatch.stdout" >/dev/null
if rg -F 'gust_native_capability_decision' "$build_root/mismatch.stdout" >/dev/null; then exit 1; fi
test ! -s "$build_root/mismatch.stderr"
test ! -e "$build_root/mismatch"
test ! -e "$marker"

echo 'Phase 26 Reference index element identity and native stride passed.'
