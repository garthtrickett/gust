#!/usr/bin/env bash
set -euo pipefail

registry_json="scripts/cranelift_feature_registry.json"
family_runner="scripts/cranelift_ci_family.py"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
canonical_fixture="compiler/fixtures/native_backend_phase13_parameter_argument_ingestion.mir"
wrong_arity_fixture="compiler/fixtures/native_backend_phase13_parameter_argument_wrong_arity.mir"
wrong_order_fixture="compiler/fixtures/native_backend_phase13_parameter_argument_wrong_order.mir"
wrong_type_fixture="compiler/fixtures/native_backend_phase13_parameter_argument_wrong_type.mir"
result_type_fixture="compiler/fixtures/native_backend_phase13_parameter_argument_result_type.mir"
metadata_order_fixture="compiler/fixtures/native_backend_phase13_parameter_argument_metadata_order.mir"
namespace_fixture="compiler/fixtures/native_backend_phase13_parameter_argument_namespace.mir"
selected_source="compiler/phase13_parameter_argument_branch_source.gst"
repeated_source="compiler/phase13_parameter_argument_repeated_source.gst"
join_source="compiler/phase13_parameter_argument_join_source.gst"
loop_source="compiler/phase13_parameter_argument_loop_source.gst"
direct_source="compiler/phase11_direct_call_nested_source.gst"
imported_source="compiler/phase11_module_import_main_source.gst"
wrong_arity_source="compiler/phase11_direct_call_wrong_arity_source.gst"
wrong_type_source="compiler/phase11_direct_call_wrong_type_source.gst"
aggregate_parameter_source="compiler/phase13_parameter_argument_aggregate_parameter_source.gst"
aggregate_return_source="compiler/phase13_parameter_argument_aggregate_return_source.gst"
target_abi_source="compiler/phase13_parameter_argument_target_abi_source.gst"
build_root="build/guards/cranelift_phase13_parameter_argument"
cargo_target="$build_root/cargo-target"

positive_cases=(
  "$selected_source|42|three-argument-branch|1"
  "$repeated_source|17|repeated-calls-expression|0"
  "$join_source|12|call-result-join|0"
  "$loop_source|7|call-result-loop-state|0"
  "$direct_source|48|inherited-direct-multi-argument|0"
  "$imported_source|42|inherited-imported-multi-argument|0"
)

for required_file in \
  "$registry_json" "$family_runner" "$rust_manifest" \
  "$canonical_fixture" "$wrong_arity_fixture" "$wrong_order_fixture" \
  "$wrong_type_fixture" "$result_type_fixture" \
  "$metadata_order_fixture" "$namespace_fixture" \
  "$selected_source" "$repeated_source" "$join_source" "$loop_source" \
  "$direct_source" "$imported_source" "$wrong_arity_source" \
  "$wrong_type_source" "$aggregate_parameter_source" \
  "$aggregate_return_source" "$target_abi_source" src/runtime.c ./gust
do
  if [ ! -e "$required_file" ]; then
    echo "Phase 13.6 parameter/argument evidence is missing $required_file" >&2
    exit 1
  fi
done
if [ ! -x ./gust ]; then
  echo "Phase 13.6 parameter/argument evidence requires the rebuilt ./gust compiler." >&2
  exit 1
fi

rm -rf "$build_root"
mkdir -p "$build_root"

CARGO_TARGET_DIR="$cargo_target" cargo build \
  --locked --quiet --manifest-path "$rust_manifest"
driver_bin="$cargo_target/debug/gust-cranelift-experiment"
if [ ! -x "$driver_bin" ]; then
  echo "Phase 13.6 parameter/argument evidence did not build $driver_bin" >&2
  exit 1
fi
driver_abs="$(cd "$(dirname "$driver_bin")" && pwd)/$(basename "$driver_bin")"
CC_BIN="${CC:-cc}"
CFLAGS_VAL="${CFLAGS:--O0 -w -pthread}"

"$driver_abs" compiler-mir-validate-fixture "$canonical_fixture" \
  >"$build_root/canonical-fixture.stdout" \
  2>"$build_root/canonical-fixture.stderr"
rg -n -F \
  'validated canonical compiler MIR module: phase13_parameter_arguments (2 defined, 0 imported)' \
  "$build_root/canonical-fixture.stdout" >/dev/null

expect_invalid_fixture() {
  local name="$1"
  local fixture="$2"
  local expected="$3"
  set +e
  "$driver_abs" compiler-mir-validate-fixture "$fixture" \
    >"$build_root/$name.stdout" \
    2>"$build_root/$name.stderr"
  local status="$?"
  set -e
  if [ "$status" = "0" ]; then
    echo "Invalid Phase 13.6 parameter/argument MIR unexpectedly validated: $name" >&2
    exit 1
  fi
  cat "$build_root/$name.stdout" "$build_root/$name.stderr" \
    >"$build_root/$name.combined"
  rg -n -F "$expected" "$build_root/$name.combined" >/dev/null
}

expect_invalid_fixture wrong-arity "$wrong_arity_fixture" \
  'passes 2 argument(s), but callee declares 3 parameter(s)'
expect_invalid_fixture wrong-order "$wrong_order_fixture" \
  'call argument type mismatch'
expect_invalid_fixture wrong-type "$wrong_type_fixture" \
  'call argument type mismatch'
expect_invalid_fixture result-type "$result_type_fixture" \
  'call result type mismatch'
expect_invalid_fixture metadata-order "$metadata_order_fixture" \
  'parameter provenance drifted at declaration-order index 0'
expect_invalid_fixture namespace "$namespace_fixture" \
  'parameter provenance drifted at declaration-order index 0'

capture_driver="$build_root/capture-driver"
cat >"$capture_driver" <<'EOF_CAPTURE'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  phase10-driver-handshake)
    exec "$REAL_DRIVER" "$@"
    ;;
  phase10-backend-request-compile)
    request_path="${2:?missing request path}"
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
  local source_path="$1"
  local expected_status="$2"
  local case_name="$3"
  local capture="$4"
  local case_dir="$build_root/$case_name"
  local native_driver="$driver_abs"
  mkdir -p "$case_dir"

  ./gust --backend mir-to-c "$source_path" \
    >"$case_dir/default.c" \
    2>"$case_dir/default.compiler.stderr"
  ./gust --backend mir-to-c "$source_path" \
    >"$case_dir/explicit.c" \
    2>"$case_dir/explicit.compiler.stderr"
  test ! -s "$case_dir/default.compiler.stderr"
  test ! -s "$case_dir/explicit.compiler.stderr"
  cmp -s "$case_dir/default.c" "$case_dir/explicit.c"

  cat src/runtime.c "$case_dir/default.c" >"$case_dir/mir-to-c.final.c"
  "$CC_BIN" $CFLAGS_VAL -Isrc "$case_dir/mir-to-c.final.c" \
    -o "$case_dir/mir-to-c-program"
  execute_and_capture "$case_dir/mir-to-c-program" "$case_dir/mir-to-c"

  if [ "$capture" = "1" ]; then
    native_driver="$capture_driver_abs"
  fi
  REAL_DRIVER="$driver_abs" \
  CAPTURE_PREFIX="$case_dir/capture" \
  GUST_NATIVE_BACKEND_DRIVER="$native_driver" \
    ./gust --backend cranelift \
      -o "$case_dir/native-program" "$source_path" \
      >"$case_dir/native.compiler.stdout" \
      2>"$case_dir/native.compiler.stderr"
  test ! -s "$case_dir/native.compiler.stdout"
  test ! -s "$case_dir/native.compiler.stderr"
  test -x "$case_dir/native-program"
  execute_and_capture "$case_dir/native-program" "$case_dir/native"

  local mir_status native_status
  mir_status="$(cat "$case_dir/mir-to-c.status")"
  native_status="$(cat "$case_dir/native.status")"
  if [ "$mir_status" != "$expected_status" ] ||
     [ "$native_status" != "$expected_status" ]; then
    echo "Phase 13.6 parity status mismatch for $case_name: MIR-to-C=$mir_status Cranelift=$native_status expected=$expected_status" >&2
    exit 1
  fi
  cmp -s "$case_dir/mir-to-c.stdout" "$case_dir/native.stdout"
  cmp -s "$case_dir/mir-to-c.stderr" "$case_dir/native.stderr"
  if [ -e "$case_dir/native-program.phase10.bundle" ] ||
     [ -e "$case_dir/native-program.phase10.request" ]; then
    echo "Phase 13.6 positive case left transient request artifacts: $case_name" >&2
    exit 1
  fi
}

for case_record in "${positive_cases[@]}"; do
  IFS='|' read -r source_path expected_status case_name capture <<<"$case_record"
  run_positive_case "$source_path" "$expected_status" "$case_name" "$capture"
done

selected_bundle="$build_root/three-argument-branch/capture.bundle"
test -f "$selected_bundle"
rg -n -F 'module: phase13_parameter_arguments' "$selected_bundle" >/dev/null
rg -n -F 'function_0_parameter_count: 3' "$selected_bundle" >/dev/null
rg -n -F 'function_1_block_0_statement_0_argument_count: 3' "$selected_bundle" >/dev/null
rg -n -F 'function_1_block_0_terminator_kind: BranchLocalI32Positive' \
  "$selected_bundle" >/dev/null
for index in 0 1 2; do
  rg -n -F "kind=FunctionParameter;contract=phase13_6;namespace=phase13_parameter_sum;" \
    "$selected_bundle" >/dev/null
  rg -n -F "index=$index;type=int;origin=compiler/phase13_parameter_argument_branch_source.gst;" \
    "$selected_bundle" >/dev/null
done
rg -n -F \
  'kind=ParameterArgumentContract;contract=phase13_6;profile=branch_condition;parameter_order=source;argument_order=source;namespace=single_module;' \
  "$selected_bundle" >/dev/null

poison_marker="$build_root/poison-driver-invoked"
poison_driver="$build_root/poison-driver"
cat >"$poison_driver" <<'EOF_POISON'
#!/usr/bin/env bash
set -euo pipefail
printf 'invoked\n' >>"${GUST_PHASE13_PARAMETER_POISON_MARKER:?}"
exit 97
EOF_POISON
chmod +x "$poison_driver"
poison_driver_abs="$(cd "$(dirname "$poison_driver")" && pwd)/$(basename "$poison_driver")"

assert_preserved_pre_driver_failure() {
  local source_path="$1"
  local case_name="$2"
  local expected="$3"
  local decision="$4"
  local case_dir="$build_root/$case_name"
  local output="$case_dir/existing-output"
  mkdir -p "$case_dir"
  printf 'phase13-parameter-argument-output-sentinel\n' >"$output"
  cp "$output" "$output.expected"
  rm -f "$poison_marker"

  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE13_PARAMETER_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$poison_driver_abs" \
    ./gust --backend cranelift -o "$output" "$source_path" \
      >"$case_dir/compiler.stdout" \
      2>"$case_dir/compiler.stderr"
  local status="$?"
  set -e
  if [ "$status" = "0" ]; then
    echo "Unsupported or invalid Phase 13.6 parameter case unexpectedly compiled: $case_name" >&2
    exit 1
  fi
  if [ -e "$poison_marker" ]; then
    echo "Phase 13.6 pre-driver failure reached driver discovery: $case_name" >&2
    exit 1
  fi
  cat "$case_dir/compiler.stdout" "$case_dir/compiler.stderr" \
    >"$case_dir/compiler.combined"
  rg -n -F "$expected" "$case_dir/compiler.combined" >/dev/null
  case "$decision" in
    deferred)
      rg -n -F 'decision=deferred' "$case_dir/compiler.combined" >/dev/null
      rg -n -F 'expected_failure_stage=before_driver_discovery' \
        "$case_dir/compiler.combined" >/dev/null
      ;;
    source_or_type_failure)
      if rg -n -F 'decision=deferred' \
          "$case_dir/compiler.combined" >/dev/null; then
        cat "$case_dir/compiler.combined" >&2
        echo "Phase 13.6 source/type failure was incorrectly reported as deliberate deferral: $case_name" >&2
        exit 1
      fi
      ;;
    *)
      echo "Unknown Phase 13.6 negative decision expectation: $decision" >&2
      exit 1
      ;;
  esac
  cmp -s "$output.expected" "$output"
  if [ -e "$output.phase10.bundle" ] ||
     [ -e "$output.phase10.request" ] ||
     find "$case_dir" -maxdepth 1 -type f \
       -name '.existing-output.phase10-source-route*.o' -print -quit | grep -q .
  then
    echo "Phase 13.6 pre-driver failure created transient artifacts: $case_name" >&2
    exit 1
  fi
}

assert_preserved_pre_driver_failure \
  "$wrong_arity_source" wrong-arity-source TypeError source_or_type_failure
assert_preserved_pre_driver_failure \
  "$wrong_type_source" wrong-type-source TypeError source_or_type_failure
assert_preserved_pre_driver_failure \
  "$aggregate_parameter_source" aggregate-parameter \
  deferred_p13_parameter_argument_aggregate_parameter deferred
assert_preserved_pre_driver_failure \
  "$aggregate_return_source" aggregate-return \
  deferred_p13_parameter_argument_aggregate_return deferred
assert_preserved_pre_driver_failure \
  "$target_abi_source" target-dependent-abi \
  deferred_p13_parameter_argument_target_dependent_abi deferred

python3 "$family_runner" differential-rows direct-calls |
  rg -n -F 'p13_parameterized_local_call_branch_source_route' >/dev/null

echo "✅ Phase 13.6 parameter/argument evidence passed: ordered three-parameter identities, direct and imported multi-argument calls, repeated/expression/CFG/loop composition, six malformed MIR contracts, source type failures, and three precise ABI deferrals."
