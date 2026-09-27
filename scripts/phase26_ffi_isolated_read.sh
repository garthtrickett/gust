#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_ffi_isolated_read"
rm -rf "$build_root"
mkdir -p "$build_root"
make build/gust-runtime-package.a
test -x ./gust
test -f build/gust-native-backend
chmod +x build/gust-native-backend
driver="$PWD/build/gust-native-backend"

# The approved read host sees a padded 12-byte repr(C) copy in a temporary
# arena. Its Int result survives the arena cleanup after the call.
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
  ./gust --backend cranelift -o "$build_root/native" \
    compiler/phase26_ffi_isolated_read_source.gst \
    >"$build_root/positive.compile.stdout" 2>"$build_root/positive.compile.stderr"
test ! -s "$build_root/positive.compile.stdout"
test ! -s "$build_root/positive.compile.stderr"
"$build_root/native" >"$build_root/positive.stdout" 2>"$build_root/positive.stderr"
printf '24\n' >"$build_root/positive.expected"
cmp -s "$build_root/positive.expected" "$build_root/positive.stdout"
test ! -s "$build_root/positive.stderr"

# Pin the native wrapper's lifetime: the host must receive the arena copy,
# then the arena must be freed before the result is used. Binutils is already
# part of the repository's native build toolchain.
command -v objdump >/dev/null
python3 - "$build_root/native" <<'PY'
import re
import subprocess
import sys

result = subprocess.run(
    ["objdump", "-d", "--disassemble=gust_phase21_program_main", sys.argv[1]],
    check=True, text=True, capture_output=True,
)
lines = result.stdout.splitlines()
anchors = ["os_Arena_New", "os_ArenaAlloc", "memcpy",
           "tiny_host_read_repr_c_probe", "os_Arena_Free", "os_LogInt"]
positions = []
for symbol in anchors:
    matches = [index for index, line in enumerate(lines)
               if re.search(r"<" + re.escape(symbol), line)]
    if len(matches) != 1:
        raise SystemExit(f"isolated FFI call anchor {symbol}: expected once, found {len(matches)}")
    positions.append(matches[0])
if positions != sorted(positions):
    raise SystemExit("isolated FFI native copy, host, cleanup or result order drifted")
for index, symbol in enumerate(anchors):
    position = positions[index]
    limit = positions[index + 1] if index + 1 < len(positions) else position + 6
    if not any(re.search(r"\bcall\s", line)
               for line in lines[position + 1:limit]):
        raise SystemExit(f"isolated FFI call anchor {symbol}: no call before next anchor")
print("Phase26.1D5 native copy, host, cleanup and result-call order passed.")
PY

poison="$build_root/poison-driver"
marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
printf 'invoked\n' >"$GUST_PHASE26_D5_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"

for case_name in missing_repr order packed nested enum unknown_host write_host; do
  output="$build_root/$case_name"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_D5_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" \
      "compiler/phase26_ffi_isolated_${case_name}_source.gst" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
  rg -F 'reason_code=deferred_p26_ffi_borrowed_c_layout' "$output.stdout" >/dev/null
  rg -F 'expected_failure_stage=before_driver_discovery' "$output.stdout" >/dev/null
  rg -F "source=compiler/phase26_ffi_isolated_${case_name}_source.gst" "$output.stdout" >/dev/null
  rg -F 'class=unsupported_native_capability' "$output.stdout" >/dev/null
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

for case_name in nonreference nonaggregate; do
  expected='[FFIIsolatedBorrowRequiresReference]'
  if test "$case_name" = nonaggregate; then
    expected='[FFIIsolatedBorrowRequiresAggregate]'
  fi
  output="$build_root/$case_name"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_D5_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" \
      "compiler/phase26_ffi_isolated_${case_name}_source.gst" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  rg -F "$expected" "$output.stdout" >/dev/null
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

echo 'Phase26.1D5 isolated borrowed repr(C) read and no-fallback evidence passed.'
