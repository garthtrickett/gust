#!/usr/bin/env bash
set -euo pipefail

registry_json="scripts/cranelift_feature_registry.json"
family_runner="scripts/cranelift_ci_family.py"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
canonical_fixture="compiler/fixtures/native_backend_phase13_general_loop_ingestion.mir"
missing_backedge_fixture="compiler/fixtures/native_backend_phase13_general_loop_missing_backedge_argument.mir"
wrong_type_fixture="compiler/fixtures/native_backend_phase13_general_loop_wrong_argument_type.mir"
invalid_header_fixture="compiler/fixtures/native_backend_phase13_general_loop_invalid_header.mir"
missing_exit_fixture="compiler/fixtures/native_backend_phase13_general_loop_missing_exit.mir"
malformed_state_fixture="compiler/fixtures/native_backend_phase13_general_loop_malformed_state.mir"
irreducible_fixture="compiler/fixtures/native_backend_phase13_general_loop_irreducible.mir"
selected_source="compiler/phase11_structured_cfg_deferred_loop_source.gst"
countdown_source="compiler/phase11_block_parameter_countdown_loop_source.gst"
stride_source="compiler/phase11_block_parameter_stride_loop_source.gst"
non_decreasing_source="compiler/phase13_loop_non_decreasing_invalid_source.gst"
early_return_deferred="compiler/phase13_loop_early_return_deferred_source.gst"
nested_loop_deferred="compiler/phase13_loop_nested_deferred_source.gst"
body_control_flow_deferred="compiler/phase13_loop_body_control_flow_deferred_source.gst"
condition_deferred="compiler/phase13_loop_condition_deferred_source.gst"
build_root="build/guards/cranelift_phase13_general_loop"
cargo_target="$build_root/cargo-target"

positive_cases=(
  "$selected_source|0|single-carried|1"
  "$countdown_source|8|countdown-two-carried|0"
  "$stride_source|10|stride-two-carried|0"
)

for required_file in \
  "$registry_json" "$family_runner" "$rust_manifest" \
  "$canonical_fixture" "$missing_backedge_fixture" \
  "$wrong_type_fixture" "$invalid_header_fixture" \
  "$missing_exit_fixture" "$malformed_state_fixture" \
  "$irreducible_fixture" "$non_decreasing_source" \
  "$early_return_deferred" "$nested_loop_deferred" \
  "$body_control_flow_deferred" "$condition_deferred" \
  src/runtime.c ./gust
do
  if [ ! -e "$required_file" ]; then
    echo "Phase 13.5 general-loop evidence is missing $required_file" >&2
    exit 1
  fi
done
for case_record in "${positive_cases[@]}"; do
  IFS='|' read -r source_path _ _ _ <<<"$case_record"
  if [ ! -f "$source_path" ]; then
    echo "Phase 13.5 general-loop evidence is missing $source_path" >&2
    exit 1
  fi
done
if [ ! -x ./gust ]; then
  echo "Phase 13.5 general-loop evidence requires the rebuilt ./gust compiler." >&2
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
  echo "Phase 13.5 general-loop evidence did not build $driver_bin" >&2
  exit 1
fi
driver_abs="$(cd "$(dirname "$driver_bin")" && pwd)/$(basename "$driver_bin")"
CC_BIN="${CC:-cc}"
CFLAGS_VAL="${CFLAGS:--O0 -w -pthread}"

"$driver_abs" compiler-mir-validate-fixture "$canonical_fixture" \
  >"$build_root/canonical-fixture.stdout" \
  2>"$build_root/canonical-fixture.stderr"
rg -n -F \
  'validated canonical compiler MIR fixture: main -> main' \
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
    echo "Invalid Phase 13.5 general-loop MIR unexpectedly validated: $name" >&2
    exit 1
  fi
  cat "$build_root/$name.stdout" "$build_root/$name.stderr" \
    >"$build_root/$name.combined"
  rg -n -F "$expected" "$build_root/$name.combined" >/dev/null
}

expect_invalid_fixture \
  missing-backedge-argument \
  "$missing_backedge_fixture" \
  'passes 0 argument(s), but target declares 1 block parameter(s)'
expect_invalid_fixture \
  wrong-backedge-argument-type \
  "$wrong_type_fixture" \
  'does not match target block parameter loop_value in block loop_header'
expect_invalid_fixture \
  invalid-loop-header \
  "$invalid_header_fixture" \
  'Phase 13.5 general-loop loop-header metadata is inconsistent'
expect_invalid_fixture \
  missing-reachable-exit \
  "$missing_exit_fixture" \
  'canonical compiler MIR fixture entry graph has no reachable Return terminator'
expect_invalid_fixture \
  malformed-loop-carried-state \
  "$malformed_state_fixture" \
  'Phase 13.5 general-loop loop-carried state metadata is inconsistent'
expect_invalid_fixture \
  irreducible-graph \
  "$irreducible_fixture" \
  'irreducible cycle or a backedge whose target does not dominate its source'

if find "$build_root" -maxdepth 1 -type f -name '*.o' -print -quit | grep -q .; then
  echo "Phase 13.5 fixture validation emitted an object before acceptance." >&2
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

  if ! ./gust "$source_path" \
      >"$case_dir/default.c" \
      2>"$case_dir/default.compiler.stderr"; then
    cat "$case_dir/default.compiler.stderr" >&2
    echo "Default MIR-to-C compilation failed for $case_name." >&2
    exit 1
  fi
  if ! ./gust --backend mir-to-c "$source_path" \
      >"$case_dir/explicit.c" \
      2>"$case_dir/explicit.compiler.stderr"; then
    cat "$case_dir/explicit.compiler.stderr" >&2
    echo "Explicit MIR-to-C compilation failed for $case_name." >&2
    exit 1
  fi
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
  if ! REAL_DRIVER="$driver_abs" \
      CAPTURE_PREFIX="$case_dir/capture" \
      GUST_NATIVE_BACKEND_DRIVER="$native_driver" \
      ./gust --backend cranelift \
        -o "$case_dir/native-program" \
        "$source_path" \
        >"$case_dir/native.compiler.stdout" \
        2>"$case_dir/native.compiler.stderr"; then
    cat "$case_dir/native.compiler.stdout" \
        "$case_dir/native.compiler.stderr" >&2
    echo "Explicit Cranelift compilation failed for $case_name." >&2
    exit 1
  fi
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
    echo "Phase 13.5 parity status mismatch for $case_name: MIR-to-C=$mir_status Cranelift=$native_status expected=$expected_status" >&2
    exit 1
  fi
  cmp -s "$case_dir/mir-to-c.stdout" "$case_dir/native.stdout"
  cmp -s "$case_dir/mir-to-c.stderr" "$case_dir/native.stderr"
  if [ -e "$case_dir/native-program.phase10.bundle" ] ||
     [ -e "$case_dir/native-program.phase10.request" ]; then
    echo "Phase 13.5 positive case left transient request artifacts: $case_name" >&2
    exit 1
  fi
}

for case_record in "${positive_cases[@]}"; do
  IFS='|' read -r source_path expected_status case_name capture <<<"$case_record"
  run_positive_case "$source_path" "$expected_status" "$case_name" "$capture"
done

selected_bundle="$build_root/single-carried/capture.bundle"
test -f "$selected_bundle"
rg -n -F 'entry_block: entry' "$selected_bundle" >/dev/null
rg -n -F 'block_count: 4' "$selected_bundle" >/dev/null
rg -n -F 'block_1_label: loop_header' "$selected_bundle" >/dev/null
rg -n -F 'block_1_parameter_count: 1' "$selected_bundle" >/dev/null
rg -n -F 'block_2_terminator_target: loop_header' "$selected_bundle" >/dev/null
rg -n -F 'block_2_terminator_argument_0_kind: BlockParamI32AddI32Literal' \
  "$selected_bundle" >/dev/null
rg -n -F 'kind=BlockParameterLoop;profile=general_loop;reducibility=single_header;parameter_arity=1;contract=phase13_5;loop_header=loop_header;backedge_count=1;reachable_exit=loop_exit;termination=bounded;' \
  "$selected_bundle" >/dev/null

poison_marker="$build_root/poison-driver-invoked"
poison_driver="$build_root/poison-driver"
cat >"$poison_driver" <<'EOF_POISON'
#!/usr/bin/env bash
set -euo pipefail
printf 'invoked\n' >>"${GUST_PHASE13_LOOP_POISON_MARKER:?}"
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
  printf 'phase13-general-loop-output-sentinel\n' >"$output"
  cp "$output" "$output.expected"
  rm -f "$poison_marker"

  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE13_LOOP_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$poison_driver_abs" \
    ./gust --backend cranelift \
      -o "$output" \
      "$source_path" \
      >"$case_dir/compiler.stdout" \
      2>"$case_dir/compiler.stderr"
  local status="$?"
  set -e
  if [ "$status" = "0" ]; then
    echo "Unsupported or invalid Phase 13.5 loop unexpectedly compiled: $case_name" >&2
    exit 1
  fi
  if [ -e "$poison_marker" ]; then
    echo "Phase 13.5 pre-driver failure reached driver discovery: $case_name" >&2
    cat "$poison_marker" >&2
    exit 1
  fi
  cat "$case_dir/compiler.stdout" "$case_dir/compiler.stderr" \
    >"$case_dir/compiler.combined"
  rg -n -F "decision=$decision" "$case_dir/compiler.combined" >/dev/null
  rg -n -F "$expected" "$case_dir/compiler.combined" >/dev/null
  rg -n -F 'expected_failure_stage=before_driver_discovery' \
    "$case_dir/compiler.combined" >/dev/null
  cmp -s "$output.expected" "$output"
  if [ -e "$output.phase10.bundle" ] ||
     [ -e "$output.phase10.request" ] ||
     find "$case_dir" -maxdepth 1 -type f \
       -name '.existing-output.phase10-source-route*.o' -print -quit | grep -q .
  then
    echo "Phase 13.5 pre-driver failure created transient artifacts: $case_name" >&2
    exit 1
  fi
}

assert_preserved_pre_driver_failure \
  "$non_decreasing_source" \
  non-decreasing-loop \
  'strictly decreasing positive loop parameter' \
  source_or_type_failure
assert_preserved_pre_driver_failure \
  "$early_return_deferred" \
  early-return \
  deferred_p13_general_loop_early_return \
  deferred
assert_preserved_pre_driver_failure \
  "$nested_loop_deferred" \
  nested-loop \
  deferred_p13_general_loop_nested_loop \
  deferred
assert_preserved_pre_driver_failure \
  "$body_control_flow_deferred" \
  body-control-flow \
  deferred_p13_general_loop_body_control_flow \
  deferred
assert_preserved_pre_driver_failure \
  "$condition_deferred" \
  condition-operator \
  deferred_p13_general_loop_condition_operator \
  deferred

python3 "$family_runner" differential-rows block-params |
  rg -n -F 'p13_general_loop_backedge_source_route' >/dev/null

echo "✅ Phase 13.5 general-loop evidence passed: one- and two-value loop-carried state, conditional header exit, bounded execution, natural-backedge validation, six malformed MIR classes, one invalid loop, and four precise residual deferrals."