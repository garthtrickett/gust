#!/usr/bin/env bash
set -euo pipefail

registry_json="scripts/cranelift_feature_registry.json"
family_runner="scripts/cranelift_ci_family.py"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
canonical_fixture="compiler/fixtures/native_backend_phase13_direct_call_graph_ingestion.mir"
duplicate_fixture="compiler/fixtures/native_backend_phase13_direct_call_graph_duplicate_declaration.mir"
missing_fixture="compiler/fixtures/native_backend_phase13_direct_call_graph_missing_callee.mir"
incompatible_fixture="compiler/fixtures/native_backend_phase13_direct_call_graph_incompatible_declaration.mir"
invalid_signature_fixture="compiler/fixtures/native_backend_phase13_direct_call_graph_invalid_signature.mir"
invalid_result_fixture="compiler/fixtures/native_backend_phase13_direct_call_graph_invalid_result_use.mir"
direct_recursion_fixture="compiler/fixtures/native_backend_phase13_direct_call_graph_direct_recursion.mir"
mutual_recursion_fixture="compiler/fixtures/native_backend_phase13_direct_call_graph_mutual_recursion.mir"
selected_source="compiler/phase13_direct_call_graph_source.gst"
branch_source="compiler/phase13_parameter_argument_branch_source.gst"
join_source="compiler/phase13_parameter_argument_join_source.gst"
loop_source="compiler/phase13_parameter_argument_loop_source.gst"
direct_recursion_source="compiler/phase11_direct_call_recursion_source.gst"
mutual_recursion_source="compiler/phase13_direct_call_mutual_recursion_source.gst"
build_root="build/guards/cranelift_phase13_direct_call_graph"
cargo_target="$build_root/cargo-target"

positive_cases=(
  "$selected_source|14|multi-function-graph|1"
  "$branch_source|42|branch-composition|0"
  "$join_source|12|join-composition|0"
  "$loop_source|7|loop-composition|0"
)

for required_file in \
  "$registry_json" "$family_runner" "$rust_manifest" \
  "$canonical_fixture" "$duplicate_fixture" "$missing_fixture" \
  "$incompatible_fixture" "$invalid_signature_fixture" \
  "$invalid_result_fixture" "$direct_recursion_fixture" \
  "$mutual_recursion_fixture" "$selected_source" "$branch_source" \
  "$join_source" "$loop_source" "$direct_recursion_source" \
  "$mutual_recursion_source" src/runtime.c ./gust
do
  if [ ! -e "$required_file" ]; then
    echo "Phase 13.7 direct-call graph evidence is missing $required_file" >&2
    exit 1
  fi
done
if [ ! -x ./gust ]; then
  echo "Phase 13.7 direct-call graph evidence requires the rebuilt ./gust compiler." >&2
  exit 1
fi

rm -rf "$build_root"
mkdir -p "$build_root"

CARGO_TARGET_DIR="$cargo_target" cargo build \
  --locked \
  --quiet \
  --manifest-path "$rust_manifest"
driver_bin="$cargo_target/debug/gust-cranelift-experiment"
if [ ! -x "$driver_bin" ]; then
  echo "Phase 13.7 direct-call graph evidence did not build $driver_bin" >&2
  exit 1
fi
driver_abs="$(cd "$(dirname "$driver_bin")" && pwd)/$(basename "$driver_bin")"
CC_BIN="${CC:-cc}"
CFLAGS_VAL="${CFLAGS:--O0 -w -pthread}"

"$driver_abs" compiler-mir-validate-fixture "$canonical_fixture" \
  >"$build_root/canonical-fixture.stdout" \
  2>"$build_root/canonical-fixture.stderr"
rg -n -F \
  'validated canonical compiler MIR module: phase13_direct_call_graph (4 defined, 0 imported)' \
  "$build_root/canonical-fixture.stdout" >/dev/null

expect_invalid_fixture() {
  local name="$1"
  local fixture_path="$2"
  local expected="$3"
  set +e
  "$driver_abs" compiler-mir-validate-fixture "$fixture_path" \
    >"$build_root/$name.stdout" \
    2>"$build_root/$name.stderr"
  local status="$?"
  set -e
  if [ "$status" = "0" ]; then
    echo "Invalid Phase 13.7 direct-call graph MIR unexpectedly validated: $name" >&2
    exit 1
  fi
  cat "$build_root/$name.stdout" "$build_root/$name.stderr" \
    >"$build_root/$name.combined"
  rg -n -F "$expected" "$build_root/$name.combined" >/dev/null
}

expect_invalid_fixture \
  duplicate-declaration \
  "$duplicate_fixture" \
  'duplicate canonical compiler MIR local function name: phase13_graph_left'
expect_invalid_fixture \
  missing-callee \
  "$missing_fixture" \
  'unknown canonical compiler MIR local callee phase13_graph_missing in function main'
expect_invalid_fixture \
  incompatible-declaration \
  "$incompatible_fixture" \
  'duplicate canonical compiler MIR emitted backend symbol: phase13_direct_call_graph__phase13_graph_left'
expect_invalid_fixture \
  invalid-signature \
  "$invalid_signature_fixture" \
  'canonical compiler MIR defined function phase13_graph_leaf must use int/bool/rawptr parameters and an int/bool/void return'
expect_invalid_fixture \
  invalid-result-use \
  "$invalid_result_fixture" \
  'canonical compiler MIR call result type mismatch for local first in function main at block entry statement 0'
expect_invalid_fixture \
  direct-recursion \
  "$direct_recursion_fixture" \
  'canonical compiler MIR local call graph must not contain recursion or mutual recursion'
expect_invalid_fixture \
  mutual-recursion \
  "$mutual_recursion_fixture" \
  'canonical compiler MIR local call graph must not contain recursion or mutual recursion'

if find "$build_root" -maxdepth 1 -type f -name '*.o' -print -quit | grep -q .; then
  echo "Phase 13.7 fixture validation emitted an object before acceptance." >&2
  exit 1
fi

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

  ./gust "$source_path" \
    >"$case_dir/default.c" \
    2>"$case_dir/default.compiler.stderr"
  ./gust --backend mir-to-c "$source_path" \
    >"$case_dir/explicit.c" \
    2>"$case_dir/explicit.compiler.stderr"
  test ! -s "$case_dir/default.compiler.stderr"
  test ! -s "$case_dir/explicit.compiler.stderr"
  cmp -s "$case_dir/default.c" "$case_dir/explicit.c"

  cat src/runtime.c "$case_dir/default.c" >"$case_dir/mir-to-c.final.c"
  "$CC_BIN" $CFLAGS_VAL -Isrc \
    "$case_dir/mir-to-c.final.c" \
    -o "$case_dir/mir-to-c-program"
  execute_and_capture "$case_dir/mir-to-c-program" "$case_dir/mir-to-c"

  if [ "$capture" = "1" ]; then
    native_driver="$capture_driver_abs"
  fi
  REAL_DRIVER="$driver_abs" \
  CAPTURE_PREFIX="$case_dir/capture" \
  GUST_NATIVE_BACKEND_DRIVER="$native_driver" \
    ./gust --backend cranelift \
      -o "$case_dir/native-program" \
      "$source_path" \
      >"$case_dir/native.compiler.stdout" \
      2>"$case_dir/native.compiler.stderr"
  test ! -s "$case_dir/native.compiler.stdout"
  test ! -s "$case_dir/native.compiler.stderr"
  test -x "$case_dir/native-program"
  execute_and_capture "$case_dir/native-program" "$case_dir/native"

  local mir_status
  local native_status
  mir_status="$(cat "$case_dir/mir-to-c.status")"
  native_status="$(cat "$case_dir/native.status")"
  if [ "$mir_status" != "$expected_status" ] ||
     [ "$native_status" != "$expected_status" ]; then
    echo "Phase 13.7 parity status mismatch for $case_name: MIR-to-C=$mir_status Cranelift=$native_status expected=$expected_status" >&2
    exit 1
  fi
  cmp -s "$case_dir/mir-to-c.stdout" "$case_dir/native.stdout"
  cmp -s "$case_dir/mir-to-c.stderr" "$case_dir/native.stderr"
  test ! -e "$case_dir/native-program.phase10.bundle"
  test ! -e "$case_dir/native-program.phase10.request"
}

for case_record in "${positive_cases[@]}"; do
  IFS='|' read -r source_path expected_status case_name capture <<<"$case_record"
  run_positive_case "$source_path" "$expected_status" "$case_name" "$capture"
done

selected_bundle="$build_root/multi-function-graph/capture.bundle"
test -f "$selected_bundle"
rg -n -F 'module: phase13_direct_call_graph' "$selected_bundle" >/dev/null
rg -n -F 'function_count: 4' "$selected_bundle" >/dev/null
rg -n -F 'function_0_block_0_statement_count: 3' "$selected_bundle" >/dev/null
rg -n -F 'function_0_block_0_statement_1_argument_0_kind: LocalI32' \
  "$selected_bundle" >/dev/null
rg -n -F 'function_1_backend_symbol: phase13_direct_call_graph__phase13_graph_left' \
  "$selected_bundle" >/dev/null
rg -n -F 'function_2_backend_symbol: phase13_direct_call_graph__phase13_graph_right' \
  "$selected_bundle" >/dev/null
rg -n -F 'function_3_backend_symbol: phase13_direct_call_graph__phase13_graph_leaf' \
  "$selected_bundle" >/dev/null

poison_marker="$build_root/poison-driver-invoked"
poison_driver="$build_root/poison-driver"
cat >"$poison_driver" <<'EOF_POISON'
#!/usr/bin/env bash
set -euo pipefail
printf 'invoked\n' >>"${GUST_PHASE13_GRAPH_POISON_MARKER:?}"
exit 97
EOF_POISON
chmod +x "$poison_driver"
poison_driver_abs="$(cd "$(dirname "$poison_driver")" && pwd)/$(basename "$poison_driver")"

assert_deferred_graph() {
  local source_path="$1"
  local case_name="$2"
  local reason_code="$3"
  local case_dir="$build_root/$case_name"
  local output="$case_dir/existing-output"
  mkdir -p "$case_dir"
  printf 'phase13-direct-call-graph-output-sentinel\n' >"$output"
  cp "$output" "$output.expected"
  rm -f "$poison_marker"

  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE13_GRAPH_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$poison_driver_abs" \
    ./gust --backend cranelift \
      -o "$output" \
      "$source_path" \
      >"$case_dir/compiler.stdout" \
      2>"$case_dir/compiler.stderr"
  local status="$?"
  set -e
  if [ "$status" = "0" ]; then
    echo "Unsupported recursive Phase 13.7 graph unexpectedly compiled: $case_name" >&2
    exit 1
  fi
  if [ -e "$poison_marker" ]; then
    echo "Phase 13.7 recursive graph reached driver discovery: $case_name" >&2
    exit 1
  fi
  cat "$case_dir/compiler.stdout" "$case_dir/compiler.stderr" \
    >"$case_dir/compiler.combined"
  rg -n -F 'decision=deferred' "$case_dir/compiler.combined" >/dev/null
  rg -n -F "reason_code=$reason_code" "$case_dir/compiler.combined" >/dev/null
  rg -n -F 'expected_failure_stage=before_driver_discovery' \
    "$case_dir/compiler.combined" >/dev/null
  rg -n -F 'class=unsupported_native_capability' \
    "$case_dir/compiler.combined" >/dev/null
  cmp -s "$output.expected" "$output"
  test ! -e "$output.phase10.bundle"
  test ! -e "$output.phase10.request"
}

assert_deferred_graph \
  "$direct_recursion_source" \
  direct-recursion-source \
  deferred_p13_recursive_direct_call_policy
assert_deferred_graph \
  "$mutual_recursion_source" \
  mutual-recursion-source \
  deferred_p13_mutual_recursive_direct_call_policy

python3 "$family_runner" differential-rows direct-calls |
  rg -n -F 'p13_multi_function_direct_call_graph_source_route' >/dev/null

echo "✅ Phase 13.7 direct-call graph evidence passed: four-function forward graphs, multiple calls and callers, call-result composition, inherited branch/join/loop composition, seven malformed MIR contracts, and explicit direct/mutual recursion deferrals."
