#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_ffi_packed_write"
rm -rf "$build_root"
mkdir -p "$build_root"
make build/gust-runtime-package.a
test -x ./gust
test -f build/gust-native-backend
driver="$PWD/build/gust-native-backend"

GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
  ./gust --backend cranelift -o "$build_root/native" \
    compiler/phase26_ffi_packed_write_source.gst \
    >"$build_root/positive.compile.stdout" 2>"$build_root/positive.compile.stderr"
test ! -s "$build_root/positive.compile.stdout"
test ! -s "$build_root/positive.compile.stderr"
"$build_root/native" >"$build_root/positive.stdout" 2>"$build_root/positive.stderr"
printf '20\n24\n4\n' >"$build_root/positive.expected"
cmp -s "$build_root/positive.expected" "$build_root/positive.stdout"
test ! -s "$build_root/positive.stderr"

# Pin the emitted test host's unaligned stores, not only the observed result.
objdump -d "$build_root/native" |
  sed -n '/<tiny_host_write_packed_probe>:/,/^$/p' >"$build_root/host.disassembly"
test "$(rg -c 'movb[[:space:]]' "$build_root/host.disassembly")" = 5
for offset in 1 2 3 4 5; do
  rg -F "0x$offset(%rdi)" "$build_root/host.disassembly" >/dev/null
done

poison="$build_root/poison-driver"
marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
printf 'invoked\n' >"$GUST_PHASE26_PACKED_WRITE_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"

for case_name in unknown_host wrong_policy; do
  output="$build_root/$case_name"
  rm -f "$marker" "$output"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_PACKED_WRITE_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" \
      "compiler/phase26_ffi_packed_write_${case_name}_source.gst" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
  rg -F 'reason_code=deferred_p26_ffi_borrowed_c_layout' "$output.stdout" >/dev/null
  rg -F 'expected_failure_stage=before_driver_discovery' "$output.stdout" >/dev/null
  rg -F "source=compiler/phase26_ffi_packed_write_${case_name}_source.gst" "$output.stdout" >/dev/null
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

echo 'Phase26 packed raw pointer write and no-fallback evidence passed.'
