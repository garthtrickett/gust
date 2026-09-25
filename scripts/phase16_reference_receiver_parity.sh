#!/usr/bin/env bash
set -euo pipefail

output_root="${1:?missing output directory}"
python3 scripts/phase26_reference_receiver_registration.py
mkdir -p "$output_root"
if ! make phase10-native-package >"$output_root/package.log" 2>&1; then
  cat "$output_root/package.log" >&2
  exit 1
fi
driver="$PWD/build/gust-native-backend"
test -x "$driver"
test -f build/gust-runtime-package.a

run_reference_case() {
  local source="$1"
  local name="$2"
  local expected="$3"
  local case_dir="$output_root/$name"
  mkdir -p "$case_dir"

  # The removed C backend must never be selected as a route or fallback.
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_NATIVE_BACKEND_DRIVER="$driver" \
    ./gust --backend cranelift -o "$case_dir/program" "$source" \
      >"$case_dir/compile.stdout" 2>"$case_dir/compile.stderr"
  test -x "$case_dir/program"
  test ! -s "$case_dir/compile.stdout"
  test ! -s "$case_dir/compile.stderr"
  "$case_dir/program" >"$case_dir/stdout" 2>"$case_dir/stderr"
  test ! -s "$case_dir/stderr"
  printf '%s' "$expected" >"$case_dir/expected"
  if ! cmp -s "$case_dir/expected" "$case_dir/stdout"; then
    diff -u "$case_dir/expected" "$case_dir/stdout" >&2 || true
    echo "Native reference receiver output drifted: $source" >&2
    exit 1
  fi
  if find "$case_dir" -maxdepth 1 -type f \
      \( -name '*.c' -o -name '*.phase10.bundle' -o -name '*.phase10.request' \) \
      -print -quit | grep -q .; then
    echo "Native reference receiver left a C or transient MIR artifact: $source" >&2
    exit 1
  fi
}

run_reference_case \
  tests/test_hashmap_reference_receiver.gst hashmap \
  $'7\n2\n5\nSUCCESS: HashMap reference receiver\n'
run_reference_case \
  compiler/phase16_reference_receiver_source.gst aggregate-and-vector \
  $'11\n2\n7\n5\nSUCCESS: native reference receivers\n'
run_reference_case \
  compiler/phase16_string_clone_source.gst string-clone \
  $'native string clone\nSUCCESS: native string clone\n'
run_reference_case \
  compiler/phase26_runtime_formal_signature_source.gst runtime-formal-signature \
  $'1\n65\n1\n'
run_reference_case \
  compiler/phase26_str_direct_call_source.gst str-direct-call \
  $'11\ndirect return\ncloned return\n'

echo "✅ Native reference receivers, Str Clone, runtime formals, and direct Str calls match exact output."
