#!/usr/bin/env bash
set -euo pipefail

python3 scripts/phase21_collection_string_native_source.py validate

build_root="build/guards/phase21_collection_string_native_source"
rm -rf "$build_root"
mkdir -p "$build_root"

make build/gust-native-backend build/gust-runtime-package.a
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
rg -n ' T os_LogInt$' "$build_root/runtime-symbols.txt" >/dev/null
rg -n ' T os_LogStr$' "$build_root/runtime-symbols.txt" >/dev/null
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

execute_and_capture() {
  local executable="$1"
  local prefix="$2"
  set +e
  "$executable" >"$prefix.stdout" 2>"$prefix.stderr"
  local status=$?
  set -e
  printf '%s\n' "$status" >"$prefix.status"
}

while IFS=$'\t' read -r case_id source_fixture expected_stdout_hex expected_exit
do
  case_dir="$build_root/$case_id"
  mkdir -p "$case_dir"

  ./gust "$source_fixture" >"$case_dir/default.c" \
    2>"$case_dir/default.compile.stderr"
  ./gust --backend mir-to-c "$source_fixture" >"$case_dir/explicit.c" \
    2>"$case_dir/explicit.compile.stderr"
  test ! -s "$case_dir/default.compile.stderr"
  test ! -s "$case_dir/explicit.compile.stderr"
  cmp -s "$case_dir/default.c" "$case_dir/explicit.c"

  cat src/runtime.c "$case_dir/explicit.c" >"$case_dir/oracle.final.c"
  "${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
    "$case_dir/oracle.final.c" -o "$case_dir/oracle"
  execute_and_capture "$case_dir/oracle" "$case_dir/oracle"

  REAL_DRIVER="$real_driver" CAPTURE_PREFIX="$case_dir/capture" \
  GUST_NATIVE_BACKEND_DRIVER="$capture_driver" \
    ./gust --backend cranelift -o "$case_dir/native" "$source_fixture" \
      >"$case_dir/native.compile.stdout" \
      2>"$case_dir/native.compile.stderr"
  test ! -s "$case_dir/native.compile.stdout"
  test ! -s "$case_dir/native.compile.stderr"
  test -x "$case_dir/native"
  execute_and_capture "$case_dir/native" "$case_dir/native"

  printf '%s\n' "$expected_exit" >"$case_dir/expected.status"
  python3 -c 'import sys; sys.stdout.buffer.write(bytes.fromhex(sys.argv[1]))' \
    "$expected_stdout_hex" >"$case_dir/expected.stdout"
  cmp -s "$case_dir/expected.status" "$case_dir/oracle.status"
  cmp -s "$case_dir/expected.status" "$case_dir/native.status"
  cmp -s "$case_dir/expected.stdout" "$case_dir/oracle.stdout"
  cmp -s "$case_dir/expected.stdout" "$case_dir/native.stdout"
  test ! -s "$case_dir/oracle.stderr"
  test ! -s "$case_dir/native.stderr"

  test -s "$case_dir/capture.request"
  test -s "$case_dir/capture.bundle"
  rg -n -F "runtime_package_path: $capture_runtime_package" \
    "$case_dir/capture.request" >/dev/null
  for operation in LocalI32Set BranchLocalI32Positive CallVoid Jump ReturnI32
  do
    rg -n -F "$operation" "$case_dir/capture.bundle" >/dev/null
  done
  rg -n -F 'argument_0_kind: StringLiteralUtf8Hex' \
    "$case_dir/capture.bundle" >/dev/null
  rg -n -F 'import_0_link_symbol: os_LogInt' \
    "$case_dir/capture.bundle" >/dev/null
  rg -n -F 'import_1_link_symbol: os_LogStr' \
    "$case_dir/capture.bundle" >/dev/null
  rg -n -F 'codegen=none;proof=runtime_boundary_classification_is_registry_validated' \
    "$case_dir/capture.bundle" >/dev/null
  if rg -n -F 'c_source' "$case_dir/capture.request" \
      "$case_dir/capture.bundle" >/dev/null; then
    echo "Patch 21.9 canonical route carried generated C: $case_id" >&2
    exit 1
  fi
  test ! -e "$case_dir/native.phase10.bundle"
  test ! -e "$case_dir/native.phase10.request"
  echo "✅ Patch 21.9 differential passed: $case_id"
done < <(python3 scripts/phase21_collection_string_native_source.py case-lines)

while IFS=$'\t' read -r rejected_id rejected_source rejected_stage oracle_stdout_hex oracle_exit
do
  rejected_dir="$build_root/$rejected_id"
  mkdir -p "$rejected_dir"

  ./gust "$rejected_source" >"$rejected_dir/default.c" \
    2>"$rejected_dir/default.compile.stderr"
  ./gust --backend mir-to-c "$rejected_source" \
    >"$rejected_dir/explicit.c" \
    2>"$rejected_dir/explicit.compile.stderr"
  test ! -s "$rejected_dir/default.compile.stderr"
  test ! -s "$rejected_dir/explicit.compile.stderr"
  cmp -s "$rejected_dir/default.c" "$rejected_dir/explicit.c"
  cat src/runtime.c "$rejected_dir/explicit.c" \
    >"$rejected_dir/oracle.final.c"
  "${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
    "$rejected_dir/oracle.final.c" -o "$rejected_dir/oracle"
  execute_and_capture "$rejected_dir/oracle" "$rejected_dir/oracle"
  printf '%s\n' "$oracle_exit" >"$rejected_dir/oracle.expected.status"
  python3 -c 'import sys; sys.stdout.buffer.write(bytes.fromhex(sys.argv[1]))' \
    "$oracle_stdout_hex" >"$rejected_dir/oracle.expected.stdout"
  cmp -s "$rejected_dir/oracle.expected.status" "$rejected_dir/oracle.status"
  cmp -s "$rejected_dir/oracle.expected.stdout" "$rejected_dir/oracle.stdout"
  test ! -s "$rejected_dir/oracle.stderr"

  set +e
  REAL_DRIVER="$real_driver" CAPTURE_PREFIX="$rejected_dir/capture" \
  GUST_NATIVE_BACKEND_DRIVER="$capture_driver" \
    ./gust --backend cranelift -o "$rejected_dir/native" "$rejected_source" \
      >"$rejected_dir/compile.stdout" \
      2>"$rejected_dir/compile.stderr"
  rejected_status=$?
  set -e
  test "$rejected_status" -ne 0
  test ! -e "$rejected_dir/native"
  test ! -e "$rejected_dir/capture.request"
  test ! -e "$rejected_dir/capture.bundle"
  rg -n -F "expected_failure_stage=$rejected_stage" \
    "$rejected_dir/compile.stdout" >/dev/null
  rg -n -F 'class=unsupported_native_capability' \
    "$rejected_dir/compile.stdout" >/dev/null
  echo "✅ Patch 21.9 conservative rejection passed: $rejected_id"
done < <(python3 scripts/phase21_collection_string_native_source.py rejection-lines)

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
    compiler/phase20_component_collections_source.gst \
    >"$missing_dir/compile.stdout" 2>"$missing_dir/compile.stderr"
missing_status=$?
set -e
test "$missing_status" -ne 0
test ! -e "$missing_dir/native"
rg -n -F 'runtime package input does not exist' \
  "$missing_dir/compile.stderr" >/dev/null
rg -n -F 'class=object_link_publication_error' \
  "$missing_dir/compile.stdout" >/dev/null

echo "✅ Phase 21.9 collection/string canonical-MIR source parity passed"
