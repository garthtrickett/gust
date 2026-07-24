#!/usr/bin/env bash
set -euo pipefail

registry_json="scripts/cranelift_feature_registry.json"
family_runner="scripts/cranelift_ci_family.py"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
generic_source="compiler/mir_native_backend_generic_source.gst"
route_source="compiler/mir_native_backend_source_route.gst"
build_root="build/guards/cranelift_phase13_broader_imported_runtime_calls"

positive_cases=(
  'abs|compiler/phase10_runtime_boundary_source.gst|53'
  'toupper|compiler/phase11_declared_external_import_source.gst|65'
  'add-one|compiler/phase13_runtime_add_one_source.gst|42'
  'add-two-args|compiler/phase13_runtime_add_i32_source.gst|42'
  'multiple-calls|compiler/phase13_runtime_multiple_calls_source.gst|42'
  'predicate-branch|compiler/phase13_runtime_predicate_branch_source.gst|42'
  'module-host-composition|compiler/phase13_runtime_module_main_source.gst|42'
)
negative_cases=(
  'unapproved|compiler/phase11_module_import_forbidden_runtime_source.gst'
  'wrong-arity|compiler/phase13_runtime_wrong_arity_source.gst'
  'wrong-type|compiler/phase13_runtime_wrong_type_source.gst'
  'wrong-signature|compiler/phase13_runtime_wrong_signature_source.gst'
)

for required_file in \
  "$registry_json" "$family_runner" "$rust_manifest" \
  scripts/cranelift_registry.py \
  "$generic_source" "$route_source" \
  compiler/mir_native_backend_module_import_source.gst \
  compiler/experiments/cranelift/src/main.rs \
  src/runtime.c src/runtime/approved_scalar_imports.c \
  compiler/phase13_runtime_module_helper_source.gst
 do
  test -f "$required_file"
done
for case_record in "${positive_cases[@]}"; do
  IFS='|' read -r _ source_path _ <<<"$case_record"
  test -f "$source_path"
done
for case_record in "${negative_cases[@]}"; do
  IFS='|' read -r _ source_path <<<"$case_record"
  test -f "$source_path"
done

capability_body="$(
  sed -n \
    '/^func mir_native_scalar_source_capabilities(/,/^func mir_native_scalar_source_process(/p' \
    "$route_source"
)"
for approved_import in \
  tiny_host_add_one_i32 \
  tiny_host_add_i32 \
  tiny_host_is_positive_i32 \
  abs \
  toupper
do
  approved_import_count="$(
    printf '%s\n' "$capability_body" |
      rg -c -F "\"$approved_import\"" || true
  )"
  if [ "$approved_import_count" != "1" ]; then
    echo "Compiler-owned static capabilities must advertise approved runtime import exactly once: $approved_import"
    exit 1
  fi
done
approved_two_int_abi_count="$(
  printf '%s\n' "$capability_body" |
    rg -c -F '"(int,int)->int"' || true
)"
if [ "$approved_two_int_abi_count" != "1" ]; then
  echo "Compiler-owned static capabilities must advertise (int,int)->int exactly once."
  exit 1
fi

plan_body="$(
  sed -n \
    '/^func mir_native_generic_plan_from_bundle(/,/^func mir_native_generic_source_lower(/p' \
    "$generic_source"
)"
required_plan_symbols=(
  'mut has_two_int_abi := 0;'
  'if std.str_eq(symbol.signature, "(int,int)->int") == 1 {'
  'if has_two_int_abi == 1 {'
)

predicate_analyzer_body="$(
  sed -n \
    '/^func mir_native_module_import_analyze_host_predicate_branch(/,/^func mir_native_module_import_analyze_function_body(/p' \
    compiler/mir_native_backend_module_import_source.gst
)"
for required_predicate_symbol in \
  'empty[Index[ast.BlockStatement[ctx], ctx]]' \
  'alternative_statements = ctx[alternative.statements];' \
  'analyzed.profile = 4;'
do
  if ! printf '%s\n' "$predicate_analyzer_body" |
      rg -n -F "$required_predicate_symbol" >/dev/null; then
    echo "Predicate imported-call analyzer is missing fall-through branch handling: $required_predicate_symbol"
    exit 1
  fi
done
for required_plan_symbol in "${required_plan_symbols[@]}"; do
  if ! printf '%s\n' "$plan_body" |
      rg -n -F "$required_plan_symbol" >/dev/null; then
    echo "Generic capability planning is missing the two-int ABI seam: $required_plan_symbol"
    exit 1
  fi
done
plan_two_int_abi_count="$(
  printf '%s\n' "$plan_body" |
    rg -c -F '"(int,int)->int"' || true
)"
if [ "$plan_two_int_abi_count" != "2" ]; then
  echo "Generic capability planning must detect and require (int,int)->int exactly once each."
  exit 1
fi

test -x ./gust
rm -rf "$build_root"
mkdir -p "$build_root"
cargo_target="$build_root/cargo-target"
CARGO_TARGET_DIR="$cargo_target" cargo build \
  --locked --quiet --manifest-path "$rust_manifest"
driver_bin="$cargo_target/debug/gust-cranelift-experiment"
driver_abs="$(cd "$(dirname "$driver_bin")" && pwd)/$(basename "$driver_bin")"
CC_BIN="${CC:-cc}"
CFLAGS_VAL="${CFLAGS:--O0 -w -pthread}"

capture_driver="$build_root/capture-driver"
cat >"$capture_driver" <<'EOF_CAPTURE'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  phase10-driver-handshake)
    exec "$REAL_DRIVER" "$@"
    ;;
  phase10-backend-request-compile)
    request_path="${2:?missing backend request path}"
    cp "$request_path" "$CAPTURE_PREFIX.request"
    bundle_path="$(sed -n 's/^program_mir_bundle_path: //p' "$request_path")"
    test -n "$bundle_path"
    cp "$bundle_path" "$CAPTURE_PREFIX.bundle"
    exec "$REAL_DRIVER" "$@"
    ;;
  *)
    exec "$REAL_DRIVER" "$@"
    ;;
esac
EOF_CAPTURE
chmod +x "$capture_driver"
capture_driver_abs="$(cd "$(dirname "$capture_driver")" && pwd)/$(basename "$capture_driver")"

execute_and_capture() {
  local binary="$1"
  local prefix="$2"
  set +e
  "$binary" >"$prefix.stdout" 2>"$prefix.stderr"
  local status="$?"
  set -e
  printf '%s\n' "$status" >"$prefix.status"
}

run_positive_case() {
  local name="$1"
  local source_path="$2"
  local expected_exit="$3"
  local case_dir="$build_root/$name"
  local output="$case_dir/native-program"
  mkdir -p "$case_dir"
  echo "▶ Phase 13.9 approved scalar runtime case: $name"

  set +e
  ./gust "$source_path" \
    >"$case_dir/default.c" \
    2>"$case_dir/default.compiler.stderr"
  local default_status="$?"
  ./gust --backend mir-to-c "$source_path" \
    >"$case_dir/explicit.c" \
    2>"$case_dir/explicit.compiler.stderr"
  local explicit_status="$?"
  set -e
  test "$default_status" = 0
  test "$explicit_status" = 0
  test ! -s "$case_dir/default.compiler.stderr"
  test ! -s "$case_dir/explicit.compiler.stderr"
  cmp -s "$case_dir/default.c" "$case_dir/explicit.c"

  cat src/runtime.c "$case_dir/default.c" >"$case_dir/mir-to-c.final.c"
  "$CC_BIN" $CFLAGS_VAL -Isrc \
    "$case_dir/mir-to-c.final.c" \
    -o "$case_dir/mir-to-c-program"
  execute_and_capture "$case_dir/mir-to-c-program" "$case_dir/mir-to-c"

  set +e
  REAL_DRIVER="$driver_abs" \
  CAPTURE_PREFIX="$case_dir/capture" \
  GUST_NATIVE_BACKEND_DRIVER="$capture_driver_abs" \
    ./gust --backend cranelift -o "$output" "$source_path" \
      >"$case_dir/native.compiler.stdout" \
      2>"$case_dir/native.compiler.stderr"
  local native_compile_status="$?"
  set -e
  test "$native_compile_status" = 0
  test ! -s "$case_dir/native.compiler.stdout"
  test ! -s "$case_dir/native.compiler.stderr"
  test -x "$output"
  execute_and_capture "$output" "$case_dir/native"

  printf '%s\n' "$expected_exit" >"$case_dir/expected.status"
  cmp -s "$case_dir/expected.status" "$case_dir/mir-to-c.status"
  cmp -s "$case_dir/expected.status" "$case_dir/native.status"
  cmp -s "$case_dir/mir-to-c.stdout" "$case_dir/native.stdout"
  cmp -s "$case_dir/mir-to-c.stderr" "$case_dir/native.stderr"
  test ! -s "$case_dir/native.stdout"
  test ! -s "$case_dir/native.stderr"

  test -s "$case_dir/capture.request"
  test -s "$case_dir/capture.bundle"
  rg -n -F 'format: gust.compiler_program_mir_bundle.v1' \
    "$case_dir/capture.bundle" >/dev/null
  rg -n -F 'additional_libraries' "$case_dir/capture.request" >/dev/null || true
  if rg -n -e '^library:' -e '^link_arg:' -e '^env:' \
      "$case_dir/capture.request" >/dev/null; then
    echo "Approved scalar runtime case exposed forbidden linker expansion: $name"
    exit 1
  fi
  if find "$case_dir" -maxdepth 1 -type f \
      \( -name '.native-program.phase10-source-route*.o' \
         -o -name '.native-program.phase13-approved-scalar-host.o' \
         -o -name 'native-program.phase10.bundle' \
         -o -name 'native-program.phase10.request' \) | grep -q .; then
    echo "Approved scalar runtime case left transient native artifacts: $name"
    find "$case_dir" -maxdepth 1 -type f | sort
    exit 1
  fi

  case "$name" in
    add-two-args)
      rg -n -F 'import_0_link_symbol: tiny_host_add_i32' \
        "$case_dir/capture.bundle" >/dev/null
      rg -n -F 'import_0_parameter_count: 2' \
        "$case_dir/capture.bundle" >/dev/null
      ;;
    multiple-calls)
      test "$(rg -c -F 'kind: LocalI32SetCall' "$case_dir/capture.bundle")" -ge 2
      rg -n -F 'argument_0_kind: LocalI32' \
        "$case_dir/capture.bundle" >/dev/null
      rg -n -F 'metadata_count: 2' \
        "$case_dir/capture.bundle" >/dev/null
      ;;
    predicate-branch)
      rg -n -F 'terminator_kind: BranchLocalI32Positive' \
        "$case_dir/capture.bundle" >/dev/null
      rg -n -F 'link_symbol: tiny_host_is_positive_i32' \
        "$case_dir/capture.bundle" >/dev/null
      ;;
    module-host-composition)
      rg -n -F 'module_count: 2' "$case_dir/capture.bundle" >/dev/null
      rg -n -F 'link_symbol: phase13_runtime_module_helper_source__lift' \
        "$case_dir/capture.bundle" >/dev/null
      rg -n -F 'link_symbol: tiny_host_add_i32' \
        "$case_dir/capture.bundle" >/dev/null
      ;;
  esac
}

for case_record in "${positive_cases[@]}"; do
  IFS='|' read -r case_name source_path expected_exit <<<"$case_record"
  run_positive_case "$case_name" "$source_path" "$expected_exit"
done

poison_marker="$build_root/poison-driver-invoked"
poison_driver="$build_root/poison-driver"
cat >"$poison_driver" <<'EOF_POISON'
#!/usr/bin/env bash
set -euo pipefail
: >"${GUST_PHASE13_RUNTIME_POISON_MARKER:?missing poison marker}"
exit 97
EOF_POISON
chmod +x "$poison_driver"
poison_driver_abs="$(cd "$(dirname "$poison_driver")" && pwd)/$(basename "$poison_driver")"

expect_source_failure() {
  local name="$1"
  local source_path="$2"
  local case_dir="$build_root/negative-$name"
  local output="$case_dir/existing-output"
  mkdir -p "$case_dir"
  rm -f "$poison_marker"
  printf 'phase13-runtime-output-sentinel\n' >"$output"
  cp "$output" "$output.expected"
  set +e
  GUST_PHASE13_RUNTIME_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$poison_driver_abs" \
    ./gust --backend cranelift -o "$output" "$source_path" \
      >"$case_dir/compiler.stdout" \
      2>"$case_dir/compiler.stderr"
  local status="$?"
  set -e
  if [ "$status" = 0 ]; then
    echo "Invalid approved-runtime source unexpectedly compiled: $name"
    exit 1
  fi
  test ! -e "$poison_marker"
  cmp -s "$output.expected" "$output"
  test ! -e "$output.phase10.bundle"
  test ! -e "$output.phase10.request"
  if find "$case_dir" -maxdepth 1 -type f \
      \( -name '.existing-output.phase10-source-route*.o' \
         -o -name '.existing-output.phase13-approved-scalar-host.o' \) | grep -q .; then
    echo "Invalid approved-runtime source left transient objects: $name"
    exit 1
  fi
  cat "$case_dir/compiler.stdout" "$case_dir/compiler.stderr" \
    >"$case_dir/compiler.combined"
  rg -n -F 'gust_backend_parity_diagnostic:' \
    "$case_dir/compiler.combined" >/dev/null
}

for case_record in "${negative_cases[@]}"; do
  IFS='|' read -r case_name source_path <<<"$case_record"
  expect_source_failure "$case_name" "$source_path"
done

python3 "$family_runner" differential-rows imports |
  rg -n -F 'p13_imported_predicate_update_branch_source_route' >/dev/null
python3 scripts/cranelift_registry.py \
  verify-phase13-broader-runtime-call-contract >/dev/null

printf '%s\n' \
  '✅ Phase 13.9 broader imported/runtime-call evidence passed: exact five-symbol scalar ABI authority, two-argument calls, repeated calls, local assignment, expression and CFG composition, module composition, fixed worker-owned host object cleanup, and pre-driver rejection of unsupported source forms.'
