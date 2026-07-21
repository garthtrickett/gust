#!/usr/bin/env bash
set -euo pipefail

supported_source="compiler/phase12_5_route_novel_source.gst"
deferred_source="compiler/phase12_5_route_unsupported_source.gst"
malformed_source="tests/test_multi_parser_errors_rejected.gst"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
route_build_root="build/guards/cranelift_route_architecture"
route_cargo_target="$route_build_root/cargo-target"
driver_bin="$route_cargo_target/debug/gust-cranelift-experiment"
build_root="build/guards/cranelift_phase13_capability_deferral"

for required_file in \
  "$supported_source" "$deferred_source" "$malformed_source" \
  "$rust_manifest" ./gust
do
  if [ ! -e "$required_file" ]; then
    echo "Phase 13 capability evidence is missing $required_file" >&2
    exit 1
  fi
done
if [ ! -x ./gust ]; then
  echo "Phase 13 capability evidence requires the rebuilt ./gust compiler." >&2
  exit 1
fi

if [ ! -x "$driver_bin" ]; then
  mkdir -p "$route_cargo_target"
  CARGO_TARGET_DIR="$route_cargo_target" cargo build \
    --locked \
    --quiet \
    --manifest-path "$rust_manifest"
fi
if [ ! -x "$driver_bin" ]; then
  echo "Phase 13 capability evidence did not build $driver_bin" >&2
  exit 1
fi
driver_abs="$(cd "$(dirname "$driver_bin")" && pwd)/$(basename "$driver_bin")"

rm -rf "$build_root"
mkdir -p "$build_root"

assert_preserved_output() {
  local output_path="$1"
  local expected_path="$2"

  if ! cmp -s "$expected_path" "$output_path"; then
    echo "Phase 13 capability failure changed existing output: $output_path" >&2
    diff -u "$expected_path" "$output_path" >&2 || true
    exit 1
  fi
  if [ -e "$output_path.phase10.request" ] ||
     [ -e "$output_path.phase10.bundle" ]; then
    echo "Phase 13 capability failure left request artifacts for $output_path" >&2
    ls -la "$(dirname "$output_path")" >&2
    exit 1
  fi
  if find "$(dirname "$output_path")"       -maxdepth 1       -type f       -name ".$(basename "$output_path").phase10-source-route*.o" |
      grep -q .; then
    echo "Phase 13 capability failure left a hidden temporary object." >&2
    exit 1
  fi
}

assert_no_mir_to_c_fallback() {
  local combined_log="$1"
  local stdout_log="$2"

  if rg -n -F \
      'MIR-to-C intentionally unavailable for route architecture evidence.' \
      "$combined_log" >/dev/null; then
    cat "$combined_log" >&2
    echo "Explicit Cranelift failure reached the MIR-to-C poison." >&2
    exit 1
  fi
  if rg -n -F 'int main(' "$stdout_log" >/dev/null; then
    cat "$stdout_log" >&2
    echo "Explicit Cranelift failure emitted MIR-to-C output." >&2
    exit 1
  fi
}

default_c="$build_root/default.c"
explicit_c="$build_root/explicit.c"
default_stderr="$build_root/default.stderr"
explicit_stderr="$build_root/explicit.stderr"
./gust "$supported_source" >"$default_c" 2>"$default_stderr"
./gust --backend mir-to-c "$supported_source" \
  >"$explicit_c" 2>"$explicit_stderr"
if [ -s "$default_stderr" ] || [ -s "$explicit_stderr" ]; then
  cat "$default_stderr" "$explicit_stderr" >&2
  echo "Default or explicit MIR-to-C emitted unexpected diagnostics." >&2
  exit 1
fi
if ! cmp -s "$default_c" "$explicit_c"; then
  diff -u "$default_c" "$explicit_c" >&2 || true
  echo "Default and explicit MIR-to-C no longer share one oracle path." >&2
  exit 1
fi

supported_dir="$build_root/supported"
mkdir -p "$supported_dir"
supported_output="$supported_dir/native-program"
if ! GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
    GUST_NATIVE_BACKEND_DRIVER="$driver_abs" \
    ./gust --backend cranelift \
      -o "$supported_output" \
      "$supported_source" \
      >"$supported_dir/compiler.stdout" \
      2>"$supported_dir/compiler.stderr"; then
  cat "$supported_dir/compiler.stdout" \
      "$supported_dir/compiler.stderr" >&2
  echo "Supported capability did not proceed through the native request path." >&2
  exit 1
fi
if [ -s "$supported_dir/compiler.stdout" ] ||
   [ -s "$supported_dir/compiler.stderr" ]; then
  cat "$supported_dir/compiler.stdout" \
      "$supported_dir/compiler.stderr" >&2
  echo "Supported capability emitted unexpected compiler diagnostics." >&2
  exit 1
fi
test -x "$supported_output"
test ! -e "$supported_output.phase10.request"
test ! -e "$supported_output.phase10.bundle"

deferred_dir="$build_root/deferred"
mkdir -p "$deferred_dir"
deferred_marker="$deferred_dir/driver.invoked"
deferred_marker_abs="$(pwd)/$deferred_marker"
deferred_driver="$deferred_dir/poison-driver"
cat >"$deferred_driver" <<POISON
#!/usr/bin/env bash
printf 'invoked\n' >"$deferred_marker_abs"
exit 97
POISON
chmod +x "$deferred_driver"
deferred_driver_abs="$(cd "$(dirname "$deferred_driver")" && pwd)/$(basename "$deferred_driver")"

deferred_output="$deferred_dir/native-program"
printf 'phase13-deferred-output-sentinel\n' >"$deferred_output"
cp "$deferred_output" "$deferred_output.expected"
set +e
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
GUST_NATIVE_BACKEND_DRIVER="$deferred_driver_abs" \
  ./gust --backend cranelift \
    -o "$deferred_output" \
    "$deferred_source" \
    >"$deferred_dir/compiler.stdout" \
    2>"$deferred_dir/compiler.stderr"
deferred_status="$?"
set -e
if [ "$deferred_status" = "0" ]; then
  echo "Explicitly deferred source unexpectedly compiled natively." >&2
  exit 1
fi
if [ -e "$deferred_marker" ]; then
  cat "$deferred_marker" >&2
  echo "Deferred capability invoked the poisoned native driver." >&2
  exit 1
fi
assert_preserved_output "$deferred_output" "$deferred_output.expected"
cat "$deferred_dir/compiler.stdout" \
    "$deferred_dir/compiler.stderr" \
    >"$deferred_dir/compiler.combined"
for deferred_token in \
  'contract=gust.native_backend.capability.v1' \
  'decision=deferred' \
  'capability=phase13_generic_source_to_mir' \
  'owner=compiler_generic_native_capability_planner' \
  'reason_code=source_feature_not_represented' \
  'expected_failure_stage=before_driver_discovery' \
  "source=$deferred_source" \
  'class=unsupported_native_capability'
do
  rg -n -F "$deferred_token" \
    "$deferred_dir/compiler.combined" >/dev/null
done
rg -n -e 'line=[1-9][0-9]* column=[1-9][0-9]*' \
  "$deferred_dir/compiler.combined" >/dev/null
if rg -n -F 'Native backend driver discovery error:' \
    "$deferred_dir/compiler.combined" >/dev/null; then
  cat "$deferred_dir/compiler.combined" >&2
  echo "Deferred capability reached native driver discovery." >&2
  exit 1
fi
assert_no_mir_to_c_fallback \
  "$deferred_dir/compiler.combined" \
  "$deferred_dir/compiler.stdout"

malformed_dir="$build_root/source-failure"
mkdir -p "$malformed_dir"
rm -f "$deferred_marker"
malformed_output="$malformed_dir/native-program"
printf 'phase13-source-failure-output-sentinel\n' >"$malformed_output"
cp "$malformed_output" "$malformed_output.expected"
set +e
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
GUST_NATIVE_BACKEND_DRIVER="$deferred_driver_abs" \
  ./gust --backend cranelift \
    -o "$malformed_output" \
    "$malformed_source" \
    >"$malformed_dir/compiler.stdout" \
    2>"$malformed_dir/compiler.stderr"
malformed_status="$?"
set -e
if [ "$malformed_status" = "0" ]; then
  echo "Malformed source unexpectedly compiled." >&2
  exit 1
fi
if [ -e "$deferred_marker" ]; then
  cat "$deferred_marker" >&2
  echo "Source failure invoked the poisoned native driver." >&2
  exit 1
fi
assert_preserved_output "$malformed_output" "$malformed_output.expected"
cat "$malformed_dir/compiler.stdout" \
    "$malformed_dir/compiler.stderr" \
    >"$malformed_dir/compiler.combined"
rg -n -F 'ParserError' "$malformed_dir/compiler.combined" >/dev/null
if rg -n -F 'decision=deferred' \
    "$malformed_dir/compiler.combined" >/dev/null; then
  cat "$malformed_dir/compiler.combined" >&2
  echo "Source failure was incorrectly reported as deliberate deferral." >&2
  exit 1
fi
assert_no_mir_to_c_fallback \
  "$malformed_dir/compiler.combined" \
  "$malformed_dir/compiler.stdout"

run_supported_failure() {
  local case_name="$1"
  local diagnostic_class="$2"
  local pipeline_stage="$3"
  local case_dir="$build_root/$case_name"
  local wrapper="$case_dir/failure-driver"
  local marker="$case_dir/compile.invoked"
  local marker_abs
  local output_path="$case_dir/native-program"

  mkdir -p "$case_dir"
  marker_abs="$(pwd)/$marker"
  cat >"$wrapper" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  phase10-driver-handshake)
    exec "$PHASE13_REAL_DRIVER" "$@"
    ;;
  phase10-backend-request-compile)
    printf 'invoked\n' >"$PHASE13_FAILURE_MARKER"
    printf 'gust_backend_parity_diagnostic: taxonomy=gust.backend_parity.diagnostic.v1 class=%s stage=%s\n' \
      "$PHASE13_FAILURE_CLASS" \
      "$PHASE13_FAILURE_STAGE" >&2
    exit 2
    ;;
  *)
    exec "$PHASE13_REAL_DRIVER" "$@"
    ;;
esac
WRAPPER
  chmod +x "$wrapper"
  local wrapper_abs
  wrapper_abs="$(cd "$(dirname "$wrapper")" && pwd)/$(basename "$wrapper")"

  printf 'phase13-supported-failure-output-sentinel\n' >"$output_path"
  cp "$output_path" "$output_path.expected"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_NATIVE_BACKEND_DRIVER="$wrapper_abs" \
  PHASE13_REAL_DRIVER="$driver_abs" \
  PHASE13_FAILURE_MARKER="$marker_abs" \
  PHASE13_FAILURE_CLASS="$diagnostic_class" \
  PHASE13_FAILURE_STAGE="$pipeline_stage" \
    ./gust --backend cranelift \
      -o "$output_path" \
      "$supported_source" \
      >"$case_dir/compiler.stdout" \
      2>"$case_dir/compiler.stderr"
  local case_status="$?"
  set -e

  if [ "$case_status" = "0" ]; then
    echo "$case_name unexpectedly succeeded." >&2
    exit 1
  fi
  if [ ! -e "$marker" ]; then
    echo "$case_name did not reach the supported native worker path." >&2
    exit 1
  fi
  assert_preserved_output "$output_path" "$output_path.expected"
  cat "$case_dir/compiler.stdout" \
      "$case_dir/compiler.stderr" \
      >"$case_dir/compiler.combined"
  for supported_failure_token in \
    'decision=supported' \
    'capability=phase13_generic_source_to_mir' \
    'owner=compiler_generic_native_capability_planner' \
    'reason_code=supported' \
    'expected_failure_stage=none_supported' \
    "source=$supported_source" \
    "class=$diagnostic_class" \
    "stage=$pipeline_stage"
  do
    rg -n -F "$supported_failure_token" \
      "$case_dir/compiler.combined" >/dev/null
  done
  assert_no_mir_to_c_fallback \
    "$case_dir/compiler.combined" \
    "$case_dir/compiler.stdout"
}

run_supported_failure \
  worker-failure \
  worker_lowering_error \
  worker_lowering
run_supported_failure \
  object-failure \
  object_link_publication_error \
  object_build
run_supported_failure \
  link-failure \
  object_link_publication_error \
  native_link

echo "✅ Phase 13 capability and deferral evidence passed: supported, deferred, and source-failure lanes are distinct; planning precedes driver and artifact access; default MIR-to-C is unchanged; and explicit Cranelift never falls back after worker, object, or link failure."