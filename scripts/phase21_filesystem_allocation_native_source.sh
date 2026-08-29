#!/usr/bin/env bash
set -euo pipefail

python3 scripts/phase21_filesystem_allocation_native_source.py validate

build_root="build/guards/phase21_filesystem_allocation_native_source"
rm -rf "$build_root"
mkdir -p "$build_root"

make phase10-native-package
real_driver="$PWD/build/gust-native-backend"
runtime_package="$PWD/build/gust-runtime-package.a"
test -x "$real_driver"
test -f "$runtime_package"
full_compiler_live="$(python3 -c '
import json
record = json.load(open("scripts/cranelift_feature_registry.json"))
print(1 if record.get("phase21_full_compiler_native_qualification", {}).get("status") == "patch21_14_complete" else 0)
')"
expected_runtime_members="arena.o host_io.o file_io.o scratch.o fiber.o "
successor_runtime_symbols=()
if test "$full_compiler_live" = 1; then
  expected_runtime_members="$(python3 -c '
import json
record = json.load(open("scripts/cranelift_feature_registry.json"))
members = record["phase21_full_compiler_native_qualification"]["runtime_package"]["members"]
print(" ".join(members), end=" ")
')"
  successor_runtime_symbols=(
    os_HashMapClear_impl os_HashMapContains_impl os_HashMapRef_impl
    os_HashMapRemove_impl std_Clone_str std_PoolAlloc_impl std_PoolFree_impl
    std_is_alpha std_is_digit std_is_whitespace std_parse_int
    std_str_byte_at std_str_eq std_str_find std_str_slice std_str_split
    std_str_trim tiny_host_add_i32 tiny_host_add_one_i32
    tiny_host_is_positive_i32
  )
fi
test "$(ar t "$runtime_package" | tr '\n' ' ')" = "$expected_runtime_members"
nm -g --defined-only "$runtime_package" >"$build_root/runtime-symbols.txt"
actual_runtime_symbols="$(awk 'NF == 3 && ($2 == "T" || $2 == "B") {print $3}' \
  "$build_root/runtime-symbols.txt" | sort)"
expected_runtime_symbols="$(printf '%s\n' \
  get_num_threads_to_use gust_context_switch gust_fiber_create \
  gust_fiber_entry_wrapper gust_fiber_exit gust_fiber_free gust_fiber_switch \
  gust_scheduler_destroy gust_scheduler_init gust_scheduler_spawn \
  gust_shard_loop gust_yield \
  os_ArenaAlloc os_Arena_Free os_Arena_New os_Arena_Validate os_Args \
  os_CloseDir os_ExecutablePath os_FileExecutable os_FileExists os_GetEnv \
  os_GetThreadScratch_raw os_LogError os_LogInt os_LogStr os_MockPayload \
  os_NativeObjectFormat \
  os_NativeTargetTriple os_OpenDir os_PathAbsolute os_PathDir os_ReadDir \
  os_ReadFile os_RemoveFile os_RunProcess os_ScratchAlloc os_ScratchReset \
  os_SetThreadScratch os_System os_WriteFile os_argc os_argv os_path_join \
  std_Channel_Alloc std_Channel_Recv_impl std_Channel_Send_impl \
  std_GenerationalSwap std_Mutex_Alloc std_Mutex_Lock_impl \
  std_Mutex_Unlock_impl "${successor_runtime_symbols[@]}" | sort)"
test "$actual_runtime_symbols" = "$expected_runtime_symbols"

capture_driver="$build_root/capture-driver"
cat >"$capture_driver" <<'CAPTURE'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  phase10-backend-request-compile)
    request_path="${2:?missing backend request}"
    cp "$request_path" "$CAPTURE_PREFIX.request"
    bundle_path="$(sed -n 's/^program_mir_bundle_path: //p' "$request_path")"
    test -n "$bundle_path"
    cp "$bundle_path" "$CAPTURE_PREFIX.bundle"
    ;;
esac
exec "$REAL_DRIVER" "$@"
CAPTURE
chmod +x "$capture_driver"
capture_driver="$PWD/$capture_driver"
capture_runtime_package="$PWD/$build_root/gust-runtime-package.a"
cp "$runtime_package" "$capture_runtime_package"
cmp -s "$runtime_package" "$capture_runtime_package"

execute_in_case_dir() {
  local case_dir="$1"
  local executable="$2"
  local prefix="$3"
  set +e
  (cd "$case_dir" && "./$executable" >"$prefix.stdout" 2>"$prefix.stderr")
  local status=$?
  set -e
  printf '%s\n' "$status" >"$case_dir/$prefix.status"
}

for worker_case in filesystem allocation
do
  worker_dir="$build_root/worker_$worker_case"
  fixture="compiler/fixtures/native_backend_phase21_${worker_case}_source.mir"
  mkdir -p "$worker_dir"
  "$real_driver" compiler-mir-validate-fixture "$fixture"
  "$real_driver" compiler-mir-ingestion-object "$fixture" \
    "$worker_dir/program.o"
  "${CC:-cc}" ${CFLAGS:--O0 -w -pthread} "$worker_dir/program.o" \
    "$runtime_package" -o "$worker_dir/program"
  execute_in_case_dir "$worker_dir" program program
  test ! -s "$worker_dir/program.stderr"
  if test "$worker_case" = filesystem; then
    printf '1\nphase21\n' >"$worker_dir/expected.stdout"
    printf 'phase21' >"$worker_dir/expected.file"
    cmp -s "$worker_dir/expected.file" "$worker_dir/phase21-file.txt"
  else
    printf '49\n' >"$worker_dir/expected.stdout"
  fi
  printf '0\n' >"$worker_dir/expected.status"
  cmp -s "$worker_dir/expected.status" "$worker_dir/program.status"
  cmp -s "$worker_dir/expected.stdout" "$worker_dir/program.stdout"
  echo "✅ Patch 21.10 canonical worker fixture passed: $worker_case"
done

allocation_fixture="compiler/fixtures/native_backend_phase21_allocation_source.mir"
assert_arena_fixture_rejected() {
  local case_id="$1"
  local diagnostic="$2"
  local fixture_path="$build_root/$case_id.mir"
  local stdout_path="$build_root/$case_id.stdout"
  local stderr_path="$build_root/$case_id.stderr"
  set +e
  "$real_driver" compiler-mir-validate-fixture "$fixture_path" \
    >"$stdout_path" 2>"$stderr_path"
  local status=$?
  set -e
  test "$status" -ne 0
  test ! -s "$stdout_path"
  rg -n -F "$diagnostic" "$stderr_path" >/dev/null
  echo "✅ Patch 21.10 malformed arena MIR rejected: $case_id"
}

sed 's/function_0_block_0_statement_2_byte_offset: 0/function_0_block_0_statement_2_byte_offset: -4/' \
  "$allocation_fixture" >"$build_root/arena-negative-offset.mir"
assert_arena_fixture_rejected arena-negative-offset \
  'canonical compiler MIR arena access byte offset must be non-negative'

sed 's/function_0_block_0_statement_3_byte_offset: 0/function_0_block_0_statement_3_byte_offset: 4/' \
  "$allocation_fixture" >"$build_root/arena-out-of-range.mir"
assert_arena_fixture_rejected arena-out-of-range \
  'canonical compiler MIR arena access range 4..8 exceeds allocation size 4'

sed 's/os_ArenaAlloc/not_an_allocator/g' "$allocation_fixture" \
  >"$build_root/arena-missing-provenance.mir"
assert_arena_fixture_rejected arena-missing-provenance \
  'canonical compiler MIR arena access requires same-block os_ArenaAlloc provenance'

sed \
  -e 's/function_0_block_0_statement_count: 6/function_0_block_0_statement_count: 7/' \
  -e 's/function_0_block_0_statement_5_/function_0_block_0_statement_6_/g' \
  -e 's/function_0_block_0_statement_4_/function_0_block_0_statement_5_/g' \
  -e 's/function_0_block_0_statement_3_/function_0_block_0_statement_4_/g' \
  -e 's/function_0_block_0_statement_2_/function_0_block_0_statement_3_/g' \
  -e '/function_0_block_0_statement_1_argument_1_value: 4/a\
function_0_block_0_statement_2_kind: LocalI32Set\
function_0_block_0_statement_2_local: node\
function_0_block_0_statement_2_value: 0' \
  "$allocation_fixture" >"$build_root/arena-index-reassigned.mir"
assert_arena_fixture_rejected arena-index-reassigned \
  'canonical compiler MIR arena access requires same-block os_ArenaAlloc provenance'

sed \
  -e 's/function_0_block_0_statement_count: 6/function_0_block_0_statement_count: 7/' \
  -e 's/function_0_block_0_statement_5_/function_0_block_0_statement_6_/g' \
  -e 's/function_0_block_0_statement_4_/function_0_block_0_statement_5_/g' \
  -e 's/function_0_block_0_statement_3_/function_0_block_0_statement_4_/g' \
  -e 's/function_0_block_0_statement_2_/function_0_block_0_statement_3_/g' \
  -e '/function_0_block_0_statement_1_argument_1_value: 4/a\
function_0_block_0_statement_2_kind: CallVoid\
function_0_block_0_statement_2_callee_kind: ImportedFunction\
function_0_block_0_statement_2_callee: os_Arena_Free\
function_0_block_0_statement_2_argument_count: 1\
function_0_block_0_statement_2_argument_0_kind: ArenaAddress\
function_0_block_0_statement_2_argument_0_local: ctx' \
  "$allocation_fixture" >"$build_root/arena-access-after-free.mir"
assert_arena_fixture_rejected arena-access-after-free \
  'canonical compiler MIR arena access requires same-block os_ArenaAlloc provenance'

sed \
  -e 's/function_0_block_0_statement_count: 6/function_0_block_0_statement_count: 7/' \
  -e 's/function_0_block_0_statement_5_/function_0_block_0_statement_6_/g' \
  -e 's/function_0_block_0_statement_4_/function_0_block_0_statement_5_/g' \
  -e 's/function_0_block_0_statement_3_/function_0_block_0_statement_4_/g' \
  -e 's/function_0_block_0_statement_2_/function_0_block_0_statement_3_/g' \
  -e '/function_0_block_0_statement_1_argument_1_value: 4/a\
function_0_block_0_statement_2_kind: ArenaInit\
function_0_block_0_statement_2_local: ctx\
function_0_block_0_statement_2_callee_kind: ImportedFunction\
function_0_block_0_statement_2_callee: os_Arena_New' \
  "$allocation_fixture" >"$build_root/arena-access-after-reinit.mir"
assert_arena_fixture_rejected arena-access-after-reinit \
  'canonical compiler MIR arena access requires same-block os_ArenaAlloc provenance'

sed 's/function_0_block_0_statement_1_argument_1_value: 4/function_0_block_0_statement_1_argument_1_value: 18446744073709551615/' \
  "$allocation_fixture" >"$build_root/arena-allocation-alignment-overflow.mir"
assert_arena_fixture_rejected arena-allocation-alignment-overflow \
  'canonical compiler MIR os_ArenaAlloc size overflows runtime alignment'

while IFS=$'\t' read -r case_id source_fixture expected_stdout_hex expected_exit expected_file expected_file_hex
do
  case_dir="$build_root/$case_id"
  mkdir -p "$case_dir"

  ./gust --backend mir-to-c "$source_fixture" >"$case_dir/default.c" \
    2>"$case_dir/default.compile.stderr"
  ./gust --backend mir-to-c "$source_fixture" >"$case_dir/explicit.c" \
    2>"$case_dir/explicit.compile.stderr"
  test ! -s "$case_dir/default.compile.stderr"
  test ! -s "$case_dir/explicit.compile.stderr"
  cmp -s "$case_dir/default.c" "$case_dir/explicit.c"
  cat src/runtime.c "$case_dir/explicit.c" >"$case_dir/oracle.final.c"
  "${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
    "$case_dir/oracle.final.c" -o "$case_dir/oracle"
  execute_in_case_dir "$case_dir" oracle oracle

  REAL_DRIVER="$real_driver" CAPTURE_PREFIX="$PWD/$case_dir/capture" \
  GUST_NATIVE_BACKEND_DRIVER="$capture_driver" \
    ./gust --backend cranelift -o "$case_dir/native" "$source_fixture" \
      >"$case_dir/native.compile.stdout" \
      2>"$case_dir/native.compile.stderr"
  test ! -s "$case_dir/native.compile.stdout"
  test ! -s "$case_dir/native.compile.stderr"
  test -x "$case_dir/native"
  execute_in_case_dir "$case_dir" native native

  printf '%s\n' "$expected_exit" >"$case_dir/expected.status"
  python3 -c 'import sys; sys.stdout.buffer.write(bytes.fromhex(sys.argv[1]))' \
    "$expected_stdout_hex" >"$case_dir/expected.stdout"
  cmp -s "$case_dir/expected.status" "$case_dir/oracle.status"
  cmp -s "$case_dir/expected.status" "$case_dir/native.status"
  cmp -s "$case_dir/expected.stdout" "$case_dir/oracle.stdout"
  cmp -s "$case_dir/expected.stdout" "$case_dir/native.stdout"
  test ! -s "$case_dir/oracle.stderr"
  test ! -s "$case_dir/native.stderr"
  if test -n "${expected_file:-}"; then
    python3 -c 'import sys; sys.stdout.buffer.write(bytes.fromhex(sys.argv[1]))' \
      "$expected_file_hex" >"$case_dir/expected.file"
    cmp -s "$case_dir/expected.file" "$case_dir/$expected_file"
  fi

  test -s "$case_dir/capture.request"
  test -s "$case_dir/capture.bundle"
  rg -n -F "runtime_package_path: $capture_runtime_package" \
    "$case_dir/capture.request" >/dev/null
  for operation in ArenaInit CallVoid ReturnI32
  do
    rg -n -F "$operation" "$case_dir/capture.bundle" >/dev/null
  done
  if [[ "$case_id" == filesystem_* ]]; then
    rg -n -F 'LocalStringSetCall' "$case_dir/capture.bundle" >/dev/null
    rg -n -F 'StringLiteralUtf8Hex' "$case_dir/capture.bundle" >/dev/null
    rg -n -F 'os_WriteFile' "$case_dir/capture.bundle" >/dev/null
    rg -n -F 'os_ReadFile' "$case_dir/capture.bundle" >/dev/null
  else
    rg -n -F 'ArenaStoreI32' "$case_dir/capture.bundle" >/dev/null
    rg -n -F 'LocalI32SetArenaLoad' "$case_dir/capture.bundle" >/dev/null
    rg -n -F 'os_ArenaAlloc' "$case_dir/capture.bundle" >/dev/null
  fi
  rg -n -F 'contract=phase21_10' "$case_dir/capture.bundle" >/dev/null
  if rg -n -F 'c_source' "$case_dir/capture.request" \
      "$case_dir/capture.bundle" >/dev/null; then
    echo "Patch 21.10 canonical route carried generated C: $case_id" >&2
    exit 1
  fi
  test ! -e "$case_dir/native.phase10.bundle"
  test ! -e "$case_dir/native.phase10.request"
  echo "✅ Patch 21.10 differential passed: $case_id"
done < <(python3 scripts/phase21_filesystem_allocation_native_source.py case-lines)

while IFS=$'\t' read -r rejected_id source_fixture expected_stage oracle_stdout_hex oracle_exit oracle_file oracle_file_hex
do
  case_dir="$build_root/$rejected_id"
  mkdir -p "$case_dir"
  ./gust --backend mir-to-c "$source_fixture" >"$case_dir/oracle.c" \
    2>"$case_dir/oracle.compile.stderr"
  test ! -s "$case_dir/oracle.compile.stderr"
  cat src/runtime.c "$case_dir/oracle.c" >"$case_dir/oracle.final.c"
  "${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
    "$case_dir/oracle.final.c" -o "$case_dir/oracle"
  execute_in_case_dir "$case_dir" oracle oracle
  printf '%s\n' "$oracle_exit" >"$case_dir/expected.status"
  python3 -c 'import sys; sys.stdout.buffer.write(bytes.fromhex(sys.argv[1]))' \
    "$oracle_stdout_hex" >"$case_dir/expected.stdout"
  cmp -s "$case_dir/expected.status" "$case_dir/oracle.status"
  cmp -s "$case_dir/expected.stdout" "$case_dir/oracle.stdout"
  test ! -s "$case_dir/oracle.stderr"
  if test -n "${oracle_file:-}"; then
    python3 -c 'import sys; sys.stdout.buffer.write(bytes.fromhex(sys.argv[1]))' \
      "$oracle_file_hex" >"$case_dir/expected.file"
    cmp -s "$case_dir/expected.file" "$case_dir/$oracle_file"
  fi

  set +e
  REAL_DRIVER="$real_driver" CAPTURE_PREFIX="$PWD/$case_dir/capture" \
  GUST_NATIVE_BACKEND_DRIVER="$capture_driver" \
    ./gust --backend cranelift -o "$case_dir/native" "$source_fixture" \
      >"$case_dir/native.compile.stdout" \
      2>"$case_dir/native.compile.stderr"
  rejected_status=$?
  set -e
  test "$rejected_status" -ne 0
  test ! -e "$case_dir/native"
  test ! -e "$case_dir/capture.request"
  test ! -e "$case_dir/capture.bundle"
  rg -n -F "expected_failure_stage=$expected_stage" \
    "$case_dir/native.compile.stdout" >/dev/null
  rg -n -F 'class=unsupported_native_capability' \
    "$case_dir/native.compile.stdout" >/dev/null
  echo "✅ Patch 21.10 conservative rejection passed: $rejected_id"
done < <(python3 scripts/phase21_filesystem_allocation_native_source.py rejection-lines)

missing_dir="$build_root/missing-runtime-package"
mkdir -p "$missing_dir"
missing_driver="$missing_dir/gust-native-backend"
cat >"$missing_driver" <<'MISSING'
#!/usr/bin/env bash
set -euo pipefail
exec "$REAL_DRIVER" "$@"
MISSING
chmod +x "$missing_driver"
set +e
REAL_DRIVER="$real_driver" GUST_NATIVE_BACKEND_DRIVER="$PWD/$missing_driver" \
  ./gust --backend cranelift -o "$missing_dir/native" \
    compiler/phase20_component_filesystem_source.gst \
    >"$missing_dir/compile.stdout" 2>"$missing_dir/compile.stderr"
missing_status=$?
set -e
test "$missing_status" -ne 0
test ! -e "$missing_dir/native"
rg -n -F 'runtime package input does not exist' \
  "$missing_dir/compile.stderr" >/dev/null
rg -n -F 'class=object_link_publication_error' \
  "$missing_dir/compile.stdout" >/dev/null

echo "✅ Phase 21.10 filesystem/allocation canonical-MIR source parity passed"
