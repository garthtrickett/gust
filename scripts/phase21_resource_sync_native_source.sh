#!/usr/bin/env bash
set -euo pipefail

python3 scripts/phase21_resource_sync_native_source.py validate
build_root="build/guards/phase21_resource_sync_native_source"
rm -rf "$build_root"
mkdir -p "$build_root"
make phase10-native-package
driver="$PWD/build/gust-native-backend"
runtime="$PWD/build/gust-runtime-package.a"
expected_runtime_members="arena.o host_io.o file_io.o scratch.o fiber.o "
full_compiler_live="$(python3 -c '
import json
record = json.load(open("scripts/cranelift_feature_registry.json"))
print(1 if record.get("phase21_full_compiler_native_qualification", {}).get("status") == "patch21_14_complete" else 0)
')"
if test "$full_compiler_live" = 1; then
  expected_runtime_members="$(python3 -c '
import json
record = json.load(open("scripts/cranelift_feature_registry.json"))
members = record["phase21_full_compiler_native_qualification"]["runtime_package"]["members"]
print(" ".join(members), end=" ")
')"
fi
test "$(ar t "$runtime" | tr '\n' ' ')" = "$expected_runtime_members"

fixture="compiler/fixtures/native_backend_phase21_threading_source.mir"
"$driver" compiler-mir-validate-fixture "$fixture" >"$build_root/fixture.validate"
"$driver" compiler-mir-ingestion-object "$fixture" "$build_root/threading.o"
"${CC:-cc}" ${CFLAGS:--O0 -w -pthread} "$build_root/threading.o" "$runtime" \
  -o "$build_root/threading"
"$build_root/threading" >"$build_root/threading.stdout" 2>"$build_root/threading.stderr"
printf '1\n' >"$build_root/threading.expected"
cmp -s "$build_root/threading.expected" "$build_root/threading.stdout"
test ! -s "$build_root/threading.stderr"

reject_fixture() {
  local id="$1" diagnostic="$2"
  set +e
  "$driver" compiler-mir-validate-fixture "$build_root/$id.mir" \
    >"$build_root/$id.stdout" 2>"$build_root/$id.stderr"
  local status=$?
  set -e
  test "$status" -ne 0
  test ! -s "$build_root/$id.stdout"
  rg -F "$diagnostic" "$build_root/$id.stderr" >/dev/null
}
sed 's/function_0_block_0_statement_1_byte_offset: 0/function_0_block_0_statement_1_byte_offset: -1/' \
  "$fixture" >"$build_root/raw-pointer-negative-offset.mir"
reject_fixture raw-pointer-negative-offset \
  'raw-pointer i32 load requires a non-negative offset'
sed 's/function_0_local_2_type: rawptr/function_0_local_2_type: int/' \
  "$fixture" >"$build_root/raw-pointer-result-type.mir"
reject_fixture raw-pointer-result-type \
  'raw-pointer call result requires rawptr local protected'
sed 's/function_0_block_0_statement_3_pointer_local: protected/function_0_block_0_statement_3_pointer_local: missing/' \
  "$fixture" >"$build_root/raw-pointer-unknown-local.mir"
reject_fixture raw-pointer-unknown-local \
  'raw-pointer i32 load requires a non-negative offset'
sed 's/function_0_block_0_statement_2_argument_1_byte_offset: 4/function_0_block_0_statement_2_argument_1_byte_offset: -1/' \
  "$fixture" >"$build_root/raw-pointer-argument-negative-offset.mir"
reject_fixture raw-pointer-argument-negative-offset \
  'raw-pointer offset must be non-negative'
sed 's/function_0_block_0_statement_5_byte_offset: 0/function_0_block_0_statement_5_byte_offset: -1/' \
  "$fixture" >"$build_root/raw-pointer-store-negative-offset.mir"
reject_fixture raw-pointer-store-negative-offset \
  'raw-pointer i32 store requires a non-negative offset'
sed 's/function_0_block_0_statement_5_value_local: value/function_0_block_0_statement_5_value_local: protected/' \
  "$fixture" >"$build_root/raw-pointer-store-value-type.mir"
reject_fixture raw-pointer-store-value-type \
  'raw-pointer i32 store requires a non-negative offset'
sed 's/function_1_block_0_statement_3_byte_offset: 0/function_1_block_0_statement_3_byte_offset: 8/' \
  "$fixture" >"$build_root/arena-local-store-out-of-range.mir"
reject_fixture arena-local-store-out-of-range \
  'arena access range 8..12 exceeds allocation size 8'

capture="$build_root/capture-driver"
cat >"$capture" <<'CAPTURE'
#!/usr/bin/env bash
set -euo pipefail
if test "${1:-}" = phase10-backend-request-compile; then
  request="${2:?missing request}"
  cp "$request" "$CAPTURE_PREFIX.request"
  bundle="$(sed -n 's/^program_mir_bundle_path: //p' "$request")"
  cp "$bundle" "$CAPTURE_PREFIX.bundle"
fi
exec "$REAL_DRIVER" "$@"
CAPTURE
chmod +x "$capture"
cp "$runtime" "$build_root/gust-runtime-package.a"
capture="$PWD/$capture"

while IFS=$'\t' read -r id source stdout_hex expected_exit; do
  dir="$build_root/$id"
  mkdir -p "$dir"
  ./gust --backend mir-to-c "$source" >"$dir/oracle.c" 2>"$dir/oracle.compile.stderr"
  test ! -s "$dir/oracle.compile.stderr"
  cat src/runtime.c "$dir/oracle.c" >"$dir/oracle.final.c"
  "${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc "$dir/oracle.final.c" -o "$dir/oracle"
  "$dir/oracle" >"$dir/oracle.stdout" 2>"$dir/oracle.stderr"
  REAL_DRIVER="$driver" CAPTURE_PREFIX="$PWD/$dir/capture" \
    GUST_NATIVE_BACKEND_DRIVER="$capture" \
    ./gust --backend cranelift -o "$dir/native" "$source" \
      >"$dir/native.compile.stdout" 2>"$dir/native.compile.stderr"
  "$dir/native" >"$dir/native.stdout" 2>"$dir/native.stderr"
  python3 -c 'import sys; sys.stdout.buffer.write(bytes.fromhex(sys.argv[1]))' \
    "$stdout_hex" >"$dir/expected.stdout"
  cmp -s "$dir/expected.stdout" "$dir/oracle.stdout"
  cmp -s "$dir/expected.stdout" "$dir/native.stdout"
  test ! -s "$dir/oracle.stderr"
  test ! -s "$dir/native.stderr"
  test -s "$dir/capture.request"
  test -s "$dir/capture.bundle"
  test "$expected_exit" = 0
  if test "$id" = threading_primary; then
    for marker in LocalRawPointerSetCall LocalI32SetRawPointerLoad \
      RawPointerStoreLocalI32 ArenaStoreLocalI32 FunctionAddress \
      ArenaAllocationAddress std_Mutex_Lock_impl gust_scheduler_spawn; do
      rg -F "$marker" "$dir/capture.bundle" >/dev/null
    done
    test "$(rg -c '_kind: native_boundary' "$dir/capture.bundle")" = 11
  fi
  ! rg -F 'c_source' "$dir/capture.request" "$dir/capture.bundle" >/dev/null
done < <(python3 scripts/phase21_resource_sync_native_source.py case-lines)

while IFS=$'\t' read -r id source stage stdout_hex expected_exit; do
  dir="$build_root/$id"
  mkdir -p "$dir"
  ./gust --backend mir-to-c "$source" >"$dir/oracle.c" 2>"$dir/oracle.compile.stderr"
  test ! -s "$dir/oracle.compile.stderr"
  cat src/runtime.c "$dir/oracle.c" >"$dir/oracle.final.c"
  "${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc "$dir/oracle.final.c" -o "$dir/oracle"
  "$dir/oracle" >"$dir/oracle.stdout" 2>"$dir/oracle.stderr"
  python3 -c 'import sys; sys.stdout.buffer.write(bytes.fromhex(sys.argv[1]))' \
    "$stdout_hex" >"$dir/expected.stdout"
  cmp -s "$dir/expected.stdout" "$dir/oracle.stdout"
  test ! -s "$dir/oracle.stderr"
  if test "$full_compiler_live" = 1; then
    REAL_DRIVER="$driver" CAPTURE_PREFIX="$PWD/$dir/capture" \
      GUST_NATIVE_BACKEND_DRIVER="$capture" \
      ./gust --backend cranelift -o "$dir/native" "$source" \
        >"$dir/native.compile.stdout" 2>"$dir/native.compile.stderr"
    test ! -s "$dir/native.compile.stdout"
    test ! -s "$dir/native.compile.stderr"
    "$dir/native" >"$dir/native.stdout" 2>"$dir/native.stderr"
    cmp -s "$dir/expected.stdout" "$dir/native.stdout"
    test ! -s "$dir/native.stderr"
    test -s "$dir/capture.request"
    test -s "$dir/capture.bundle"
    ! rg -F 'c_source' "$dir/capture.request" "$dir/capture.bundle" >/dev/null
  else
    set +e
    REAL_DRIVER="$driver" CAPTURE_PREFIX="$PWD/$dir/capture" \
      GUST_NATIVE_BACKEND_DRIVER="$capture" \
      ./gust --backend cranelift -o "$dir/native" "$source" \
        >"$dir/native.stdout" 2>"$dir/native.stderr"
    status=$?
    set -e
    test "$status" -ne 0
    test ! -e "$dir/capture.request"
    rg -F "expected_failure_stage=$stage" "$dir/native.stdout" >/dev/null
  fi
  test "$expected_exit" = 0
done < <(python3 scripts/phase21_resource_sync_native_source.py rejection-lines)

echo "✅ Phase 21.11 resource/synchronization native source parity passed"
