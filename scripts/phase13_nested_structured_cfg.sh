#!/usr/bin/env bash
set -euo pipefail

registry_json="scripts/cranelift_feature_registry.json"
family_runner="scripts/cranelift_ci_family.py"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
canonical_fixture="compiler/fixtures/native_backend_phase13_nested_structured_cfg_ingestion.mir"
missing_target_fixture="compiler/fixtures/native_backend_phase13_nested_cfg_missing_target.mir"
invalid_join_fixture="compiler/fixtures/native_backend_phase13_nested_cfg_invalid_join.mir"
incorrect_arguments_fixture="compiler/fixtures/native_backend_phase13_nested_cfg_incorrect_arguments.mir"
malformed_parameters_fixture="compiler/fixtures/native_backend_phase13_nested_cfg_malformed_block_parameters.mir"
unterminated_fixture="compiler/fixtures/native_backend_phase13_nested_cfg_unterminated.mir"
invalid_early_return_fixture="compiler/fixtures/native_backend_phase13_nested_cfg_invalid_early_return.mir"
loop_deferred="compiler/phase11_structured_cfg_deferred_loop_source.gst"
short_circuit_deferred="compiler/phase13_structured_cfg_short_circuit_deferred_source.gst"
condition_deferred="compiler/phase13_structured_cfg_condition_deferred_source.gst"
build_root="build/guards/cranelift_phase13_nested_structured_cfg"
cargo_target="$build_root/cargo-target"

positive_cases=(
  'compiler/phase13_nested_structured_cfg_source.gst|36|nested-positive|1'
  'compiler/phase13_nested_structured_cfg_negative_source.gst|18|nested-negative|0'
  'compiler/phase13_sequential_structured_cfg_source.gst|29|sequential|0'
  'compiler/phase13_early_return_structured_cfg_source.gst|12|early-return|0'
  'compiler/phase13_branch_local_structured_cfg_source.gst|14|branch-local|0'
  'compiler/phase13_nested_condition_structured_cfg_source.gst|32|nested-condition|0'
)

for required_file in \
  "$registry_json" "$family_runner" "$rust_manifest" \
  "$canonical_fixture" "$missing_target_fixture" \
  "$invalid_join_fixture" "$incorrect_arguments_fixture" \
  "$malformed_parameters_fixture" "$unterminated_fixture" \
  "$invalid_early_return_fixture" "$loop_deferred" \
  "$short_circuit_deferred" "$condition_deferred" \
  src/runtime.c ./gust
do
  if [ ! -e "$required_file" ]; then
    echo "Phase 13.4 structured-CFG evidence is missing $required_file" >&2
    exit 1
  fi
done
for case_record in "${positive_cases[@]}"; do
  IFS='|' read -r source_path _ _ _ <<<"$case_record"
  if [ ! -f "$source_path" ]; then
    echo "Phase 13.4 structured-CFG evidence is missing $source_path" >&2
    exit 1
  fi
done
if [ ! -x ./gust ]; then
  echo "Phase 13.4 structured-CFG evidence requires the rebuilt ./gust compiler." >&2
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
  echo "Phase 13.4 structured-CFG evidence did not build $driver_bin" >&2
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
    echo "Invalid Phase 13.4 structured-CFG MIR unexpectedly validated: $name" >&2
    exit 1
  fi
  cat "$build_root/$name.stdout" "$build_root/$name.stderr" \
    >"$build_root/$name.combined"
  rg -n -F "$expected" "$build_root/$name.combined" >/dev/null
}

expect_invalid_fixture \
  missing-target \
  "$missing_target_fixture" \
  'unknown canonical compiler MIR jump target missing_cfg from block cfg_5'
expect_invalid_fixture \
  invalid-join \
  "$invalid_join_fixture" \
  'returns local value before definite assignment'
expect_invalid_fixture \
  incorrect-block-arguments \
  "$incorrect_arguments_fixture" \
  'passes 0 argument(s), but target declares 1 block parameter(s)'
expect_invalid_fixture \
  malformed-block-parameters \
  "$malformed_parameters_fixture" \
  'duplicate canonical compiler MIR block parameter joined in block cfg_1'
expect_invalid_fixture \
  reachable-unterminated \
  "$unterminated_fixture" \
  'missing canonical compiler MIR fixture field: block_4_terminator_kind'
expect_invalid_fixture \
  invalid-early-return-path \
  "$invalid_early_return_fixture" \
  'Phase 13.4 CFG block cfg_3 termination metadata is inconsistent'

if find "$build_root" -maxdepth 1 -type f -name '*.o' -print -quit | grep -q .; then
  echo "Phase 13.4 fixture validation emitted an object before acceptance." >&2
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
    echo "Phase 13.4 parity status mismatch for $case_name: MIR-to-C=$mir_status Cranelift=$native_status expected=$expected_status" >&2
    exit 1
  fi
  cmp -s "$case_dir/mir-to-c.stdout" "$case_dir/native.stdout"
  cmp -s "$case_dir/mir-to-c.stderr" "$case_dir/native.stderr"
  if [ -e "$case_dir/native-program.phase10.bundle" ] ||
     [ -e "$case_dir/native-program.phase10.request" ]; then
    echo "Phase 13.4 positive case left transient request artifacts: $case_name" >&2
    exit 1
  fi
}

for case_record in "${positive_cases[@]}"; do
  IFS='|' read -r source_path expected_status case_name capture <<<"$case_record"
  run_positive_case "$source_path" "$expected_status" "$case_name" "$capture"
done

selected_bundle="$build_root/nested-positive/capture.bundle"
test -f "$selected_bundle"
rg -n -F 'entry_block: cfg_0' "$selected_bundle" >/dev/null
rg -n -F 'block_count: 7' "$selected_bundle" >/dev/null
rg -n -F 'kind=StructuredCfg;reducibility=acyclic;block_count=7;contract=phase13_4;branch_count=2;maximum_depth=2;' \
  "$selected_bundle" >/dev/null
rg -n -e 'kind=CfgBlock;index=[0-9]+;label=cfg_[0-9]+;predecessors=[^;]+;termination=(branch|jump|return);parameter_owner=none;origin=[^;]+;line=[1-9][0-9]*;column=[1-9][0-9]*' \
  "$selected_bundle" >/dev/null
rg -n -F 'label=cfg_5;predecessors=cfg_3,cfg_4;termination=jump' \
  "$selected_bundle" >/dev/null
rg -n -F 'label=cfg_6;predecessors=cfg_5,cfg_2;termination=return' \
  "$selected_bundle" >/dev/null

poison_marker="$build_root/poison-driver-invoked"
poison_driver="$build_root/poison-driver"
cat >"$poison_driver" <<'EOF_POISON'
#!/usr/bin/env bash
set -euo pipefail
printf 'invoked\n' >>"${GUST_PHASE13_CFG_POISON_MARKER:?}"
exit 97
EOF_POISON
chmod +x "$poison_driver"
poison_driver_abs="$(cd "$(dirname "$poison_driver")" && pwd)/$(basename "$poison_driver")"

assert_deferred_before_driver() {
  local source_path="$1"
  local case_name="$2"
  local reason_code="$3"
  local case_dir="$build_root/$case_name"
  local output="$case_dir/existing-output"
  mkdir -p "$case_dir"
  printf 'phase13-structured-cfg-output-sentinel\n' >"$output"
  cp "$output" "$output.expected"
  rm -f "$poison_marker"

  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE13_CFG_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$poison_driver_abs" \
    ./gust --backend cranelift \
      -o "$output" \
      "$source_path" \
      >"$case_dir/compiler.stdout" \
      2>"$case_dir/compiler.stderr"
  local status="$?"
  set -e
  if [ "$status" = "0" ]; then
    echo "Unsupported Phase 13.4 control-flow shape unexpectedly compiled: $case_name" >&2
    exit 1
  fi
  if [ -e "$poison_marker" ]; then
    echo "Deferred Phase 13.4 control-flow shape reached driver discovery: $case_name" >&2
    cat "$poison_marker" >&2
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
  if [ -e "$output.phase10.bundle" ] ||
     [ -e "$output.phase10.request" ] ||
     find "$case_dir" -maxdepth 1 -type f \
       -name '.existing-output.phase10-source-route*.o' -print -quit | grep -q .
  then
    echo "Deferred Phase 13.4 control-flow shape created transient artifacts: $case_name" >&2
    exit 1
  fi
}

assert_deferred_before_driver \
  "$loop_deferred" \
  loop-or-backedge \
  deferred_p13_structured_cfg_loop_or_backedge
assert_deferred_before_driver \
  "$short_circuit_deferred" \
  short-circuit \
  deferred_p13_structured_cfg_short_circuit
assert_deferred_before_driver \
  "$condition_deferred" \
  unselected-condition \
  deferred_p13_structured_cfg_condition_operator

python3 "$family_runner" differential-rows cfg |
  rg -n -F 'p13_nested_local_update_branch_source_route' >/dev/null

echo "✅ Phase 13.4 nested structured-CFG evidence passed: positive/negative nesting, sequential joins, early returns, branch-local state, expression conditions, block origin/predecessor metadata, six malformed CFG classes, and precise pre-driver deferrals."