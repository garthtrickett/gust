#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_ffi_isolated_write"
rm -rf "$build_root"
mkdir -p "$build_root"
make build/gust-runtime-package.a
test -x ./gust
test -f build/gust-native-backend
chmod +x build/gust-native-backend
driver="$PWD/build/gust-native-backend"

# The approved host writes only the temporary arena copy. Copy-back makes the
# changed Int and trailing Byte visible in the caller after arena cleanup.
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
  ./gust --backend cranelift -o "$build_root/native" \
    compiler/phase26_ffi_isolated_write_source.gst \
    >"$build_root/positive.compile.stdout" 2>"$build_root/positive.compile.stderr"
test ! -s "$build_root/positive.compile.stdout"
test ! -s "$build_root/positive.compile.stderr"
"$build_root/native" >"$build_root/positive.stdout" 2>"$build_root/positive.stderr"
printf '20\n30\n4\n' >"$build_root/positive.expected"
cmp -s "$build_root/positive.expected" "$build_root/positive.stdout"
test ! -s "$build_root/positive.stderr"

# Pin actual native call order: copy in, host write, copy back, and Free.
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
names = ["os_Arena_New", "os_ArenaAlloc", "memcpy", "tiny_host_write_repr_c_probe",
         "memcpy", "os_Arena_Free"]
found = {}
for name in set(names):
    found[name] = [index for index, line in enumerate(lines)
                   if re.search(r"<" + re.escape(name), line)]
for name, count in [("os_Arena_New", 1), ("os_ArenaAlloc", 1),
                    ("memcpy", 2), ("tiny_host_write_repr_c_probe", 1),
                    ("os_Arena_Free", 1)]:
    if len(found[name]) != count:
        raise SystemExit(f"isolated FFI write anchor {name}: expected {count}, found {len(found[name])}")
positions = [found["os_Arena_New"][0], found["os_ArenaAlloc"][0],
             found["memcpy"][0], found["tiny_host_write_repr_c_probe"][0],
             found["memcpy"][1], found["os_Arena_Free"][0]]
if positions != sorted(positions):
    raise SystemExit("isolated FFI write copy-in, host, copy-back or cleanup order drifted")
for offset, (index, name) in enumerate(zip(positions, names)):
    limit = positions[offset + 1] if offset + 1 < len(positions) else index + 6
    if not any(re.search(r"\bcall\s", line)
               for line in lines[index + 1:limit]):
        raise SystemExit(f"isolated FFI write anchor {name}: no call before next anchor")
logs = [index for index, line in enumerate(lines) if re.search(r"<os_LogInt", line)]
if len(logs) != 3 or not (logs[0] < positions[0] < positions[-1] < logs[1] < logs[2]):
    raise SystemExit("isolated FFI write caller observations straddle cleanup incorrectly")
print("Phase26.1D6 native copy-in, host write, copy-back and cleanup order passed.")
PY

poison="$build_root/poison-driver"
marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
printf 'invoked\n' >"$GUST_PHASE26_D6_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"

for case_name in missing order packed nested unknown_host enum; do
  output="$build_root/$case_name"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_D6_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" \
      "compiler/phase26_ffi_isolated_write_${case_name}_source.gst" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  if test "$case_name" = unknown_host; then
    # The generic variant admits a verified flat C layout for any host symbol.
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
  rg -F "source=compiler/phase26_ffi_isolated_write_${case_name}_source.gst" "$output.stdout" >/dev/null
  rg -F 'class=unsupported_native_capability' "$output.stdout" >/dev/null
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

for case_name in nonraw nonaggregate; do
  expected='[FFIWriteRequiresRawPointer]'
  if test "$case_name" = nonaggregate; then
    expected='[FFIIsolatedWriteRequiresAggregate]'
  fi
  output="$build_root/$case_name"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_D6_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" \
      "compiler/phase26_ffi_isolated_write_${case_name}_source.gst" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  rg -F "$expected" "$output.stdout" >/dev/null
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

echo 'Phase26.1D6 isolated repr(C) raw-pointer write, copy-back, cleanup and no-fallback evidence passed.'
