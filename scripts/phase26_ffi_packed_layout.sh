#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_ffi_packed_layout"
rm -rf "$build_root"
mkdir -p "$build_root"
make build/gust-runtime-package.a
test -x ./gust
test -f build/gust-native-backend
driver="$PWD/build/gust-native-backend"

GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
  ./gust --backend cranelift -o "$build_root/native" \
    compiler/phase26_ffi_packed_probe_source.gst \
    >"$build_root/positive.compile.stdout" 2>"$build_root/positive.compile.stderr"
test ! -s "$build_root/positive.compile.stdout"
test ! -s "$build_root/positive.compile.stderr"
"$build_root/native" >"$build_root/positive.stdout" 2>"$build_root/positive.stderr"
printf '20\n24\n' >"$build_root/positive.expected"
cmp -s "$build_root/positive.expected" "$build_root/positive.stdout"
test ! -s "$build_root/positive.stderr"

poison="$build_root/poison-driver"
marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
printf 'invoked\n' >"$GUST_PHASE26_PACKED_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"

for case_name in missing order nested enum unknown_host; do
  output="$build_root/$case_name"
  rm -f "$marker" "$output"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_PACKED_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" \
      "compiler/phase26_ffi_packed_${case_name}_source.gst" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  if test "$case_name" = unknown_host; then
    # Generic direct Call 4 admits this flat packed C layout and direct
    # address regardless of host spelling; the poison driver proves discovery.
    rg -F 'decision=supported capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
    rg -F 'class=driver_handshake_error' "$output.stdout" >/dev/null
    test -e "$marker"
    test ! -e "$output"
    rm "$marker"
    continue
  fi
  rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
  rg -F 'reason_code=deferred_p26_ffi_borrowed_c_layout' "$output.stdout" >/dev/null
  rg -F 'expected_failure_stage=before_driver_discovery' "$output.stdout" >/dev/null
  rg -F "source=compiler/phase26_ffi_packed_${case_name}_source.gst" "$output.stdout" >/dev/null
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

for case_name in by_value safe_field field_reference; do
  output="$build_root/$case_name"
  rm -f "$marker" "$output"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_PACKED_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" \
      "compiler/phase26_ffi_packed_${case_name}_source.gst" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  if [ "$case_name" = by_value ]; then
    rg -F '[FFIByValueAggregateUnsupported]' "$output.stdout" >/dev/null
  elif [ "$case_name" = safe_field ]; then
    rg -F '[PackedFieldUnsafe]' "$output.stdout" >/dev/null
  else
    rg -F '[PackedFieldReference]' "$output.stdout" >/dev/null
  fi
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

# The selected packed host must not regain legacy Call 0 admission by dropping
# the explicit direct-borrow plan from the compiler-produced canonical fixture.
canonical="compiler/fixtures/native_backend_phase26_packed_unknown_host_call4.mir"
"$driver" phase21-full-program-validate "$canonical" \
  >"$build_root/packed_call4.stdout"
python3 - "$canonical" "$build_root/legacy_packed_call0.mir" <<'PY'
from pathlib import Path
import sys

lines = Path(sys.argv[1]).read_text().splitlines()
assert any(line.startswith('layout: 1|46666950726f6265|') and '|1|1|43|' in line
           for line in lines), 'packed FfiProbe layout missing'
matches = [i for i, line in enumerate(lines)
           if line.startswith('node: ') and '|direct_call.v1|' in line]
assert len(matches) == 1, matches
fields = lines[matches[0]][len('node: '):].split('|')
assert fields[1] == '43616c6c' and fields[6] == '4'
tag = fields.index('direct_call.v1')
fields[6] = '0'
del fields[tag:]
lines[matches[0]] = 'node: ' + '|'.join(fields)
Path(sys.argv[2]).write_text('\n'.join(lines) + '\n')
PY
set +e
"$driver" phase21-full-program-object \
  "$build_root/legacy_packed_call0.mir" "$build_root/legacy_packed_call0.o" \
  >"$build_root/legacy_packed_call0.stdout" \
  2>"$build_root/legacy_packed_call0.stderr"
legacy_status=$?
set -e
test "$legacy_status" -ne 0
rg -F 'direct FFI Call is missing its canonical plan' \
  "$build_root/legacy_packed_call0.stderr" >/dev/null
test ! -e "$build_root/legacy_packed_call0.o"

echo 'Phase26 packed flat C layout, unaligned access, and no-fallback evidence passed.'
