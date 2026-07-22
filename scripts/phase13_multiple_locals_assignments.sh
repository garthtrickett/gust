#!/usr/bin/env bash
set -euo pipefail

registry_json="scripts/cranelift_feature_registry.json"
family_runner="scripts/cranelift_ci_family.py"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
canonical_fixture="compiler/fixtures/native_backend_phase13_multiple_locals_assignments_ingestion.mir"
invalid_index_fixture="compiler/fixtures/native_backend_phase13_multiple_locals_invalid_index.mir"
duplicate_local_fixture="compiler/fixtures/native_backend_phase13_multiple_locals_duplicate_local.mir"
invalid_join_fixture="compiler/fixtures/native_backend_phase13_multiple_locals_invalid_join.mir"
selected_source="compiler/phase13_multiple_locals_assignments_source.gst"
call_source="compiler/phase13_multiple_locals_call_sequence_source.gst"
duplicate_source="compiler/phase13_multiple_locals_duplicate_source.gst"
type_mismatch_source="compiler/phase13_multiple_locals_type_mismatch_source.gst"
invalid_join_source="compiler/phase13_multiple_locals_invalid_join_source.gst"
uninitialized_source="compiler/phase11_local_state_uninitialized_read_source.gst"
unknown_local_source="compiler/phase11_local_state_invalid_local_source.gst"
loop_source="compiler/phase11_block_parameter_countdown_loop_source.gst"
build_root="build/guards/cranelift_phase13_multiple_locals_assignments"
cargo_target="$build_root/cargo-target"

for required_file in \
  "$registry_json" "$family_runner" "$rust_manifest" \
  "$canonical_fixture" "$invalid_index_fixture" \
  "$duplicate_local_fixture" "$invalid_join_fixture" \
  "$selected_source" "$call_source" "$duplicate_source" \
  "$type_mismatch_source" "$invalid_join_source" \
  "$uninitialized_source" "$unknown_local_source" "$loop_source" \
  src/runtime.c ./gust
do
  if [ ! -e "$required_file" ]; then
    echo "Phase 13.3 local-state evidence is missing $required_file" >&2
    exit 1
  fi
done
if [ ! -x ./gust ]; then
  echo "Phase 13.3 local-state evidence requires the rebuilt ./gust compiler." >&2
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
  echo "Phase 13.3 local-state evidence did not build $driver_bin" >&2
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
    echo "Invalid Phase 13.3 local-state MIR unexpectedly validated: $name" >&2
    exit 1
  fi
  cat "$build_root/$name.stdout" "$build_root/$name.stderr" \
    >"$build_root/$name.combined"
  rg -n -F "$expected" "$build_root/$name.combined" >/dev/null
}

expect_invalid_fixture \
  invalid-local-index \
  "$invalid_index_fixture" \
  'local declaration provenance does not match the serialized local inventory'
expect_invalid_fixture \
  duplicate-local \
  "$duplicate_local_fixture" \
  'duplicate canonical compiler MIR local name'
expect_invalid_fixture \
  invalid-join-state \
  "$invalid_join_fixture" \
  'returns local value before definite assignment'

if find "$build_root" -maxdepth 1 -type f -name '*.o' -print -quit | grep -q .; then
  echo "Phase 13.3 fixture validation emitted an object before acceptance." >&2
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
    echo "Phase 13.3 parity status mismatch for $case_name: MIR-to-C=$mir_status Cranelift=$native_status expected=$expected_status" >&2
    exit 1
  fi
  cmp -s "$case_dir/mir-to-c.stdout" "$case_dir/native.stdout"
  cmp -s "$case_dir/mir-to-c.stderr" "$case_dir/native.stderr"
  if [ -e "$case_dir/native-program.phase10.bundle" ] ||
     [ -e "$case_dir/native-program.phase10.request" ]; then
    echo "Phase 13.3 positive case left transient request artifacts: $case_name" >&2
    exit 1
  fi
}

run_positive_case "$selected_source" 20 multiple-locals 1
run_positive_case \
  compiler/phase11_local_state_straight_line_source.gst \
  2 \
  repeated-sequencing \
  0
run_positive_case "$call_source" 12 before-after-call 0
run_positive_case "$loop_source" 8 supported-loop-state 0

selected_bundle="$build_root/multiple-locals/capture.bundle"
test -f "$selected_bundle"
rg -n -F 'local_count: 4' "$selected_bundle" >/dev/null
rg -n -F 'local_0_name: gate' "$selected_bundle" >/dev/null
rg -n -F 'local_1_name: left' "$selected_bundle" >/dev/null
rg -n -F 'local_2_name: right' "$selected_bundle" >/dev/null
rg -n -F 'local_3_name: total' "$selected_bundle" >/dev/null
rg -n -F 'block_3_statement_0_kind: LocalI32SubI32Literal' "$selected_bundle" >/dev/null
rg -n -F 'block_3_statement_1_kind: LocalI32Set' "$selected_bundle" >/dev/null
rg -n -e 'kind=LocalDeclaration;local=[^;]+;index=[0-9]+;origin=[^;]+;line=[1-9][0-9]*;column=[1-9][0-9]*' \
  "$selected_bundle" >/dev/null
rg -n -e 'kind=LocalAssignment;local=[^;]+;index=[0-9]+;origin=[^;]+;line=[1-9][0-9]*;column=[1-9][0-9]*' \
  "$selected_bundle" >/dev/null

poison_marker="$build_root/poison-driver-invoked"
poison_driver="$build_root/poison-driver"
cat >"$poison_driver" <<'EOF_POISON'
#!/usr/bin/env bash
set -euo pipefail
printf 'invoked\n' >>"${GUST_PHASE13_LOCAL_STATE_POISON_MARKER:?}"
exit 97
EOF_POISON
chmod +x "$poison_driver"
poison_driver_abs="$(cd "$(dirname "$poison_driver")" && pwd)/$(basename "$poison_driver")"

assert_rejected_before_driver() {
  local source_path="$1"
  local case_name="$2"
  local expected="$3"
  local case_dir="$build_root/$case_name"
  local output="$case_dir/existing-output"
  mkdir -p "$case_dir"
  printf 'phase13-local-state-output-sentinel\n' >"$output"
  cp "$output" "$output.expected"
  rm -f "$poison_marker"

  set +e
  GUST_PHASE13_LOCAL_STATE_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$poison_driver_abs" \
    ./gust --backend cranelift \
      -o "$output" \
      "$source_path" \
      >"$case_dir/compiler.stdout" \
      2>"$case_dir/compiler.stderr"
  local status="$?"
  set -e
  if [ "$status" = "0" ]; then
    echo "Negative Phase 13.3 local-state case unexpectedly compiled: $case_name" >&2
    exit 1
  fi
  if [ -e "$poison_marker" ]; then
    echo "Negative Phase 13.3 local-state case reached driver discovery: $case_name" >&2
    cat "$poison_marker" >&2
    exit 1
  fi
  cat "$case_dir/compiler.stdout" "$case_dir/compiler.stderr" \
    >"$case_dir/compiler.combined"
  if [ -n "$expected" ]; then
    rg -n -F "$expected" "$case_dir/compiler.combined" >/dev/null
  fi
  cmp -s "$output.expected" "$output"
  if [ -e "$output.phase10.bundle" ] ||
     [ -e "$output.phase10.request" ] ||
     find "$case_dir" -maxdepth 1 -type f -name '.existing-output.phase10-source-route*.o' -print -quit | grep -q .
  then
    echo "Negative Phase 13.3 local-state case created transient artifacts: $case_name" >&2
    exit 1
  fi
}

assert_rejected_before_driver \
  "$uninitialized_source" \
  uninitialized-read \
  'generic local-state MIR read before definite assignment'
assert_rejected_before_driver \
  "$unknown_local_source" \
  unknown-local \
  ''
assert_rejected_before_driver \
  "$duplicate_source" \
  duplicate-declaration \
  'generic local-state MIR contains a duplicate local declaration'
assert_rejected_before_driver \
  "$type_mismatch_source" \
  type-mismatched-assignment \
  'TypeError'
assert_rejected_before_driver \
  "$invalid_join_source" \
  invalid-join-state-source \
  'generic local-state MIR read before definite assignment'

echo "✅ Phase 13.3 multiple-local evidence passed: declaration-order indices, repeated assignment, multi-local expressions, branch-arm and post-join sequencing, local operations around a direct call, supported loop state, source-location provenance, and six negative state contracts."
