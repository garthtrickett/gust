#!/usr/bin/env bash
set -euo pipefail

registry_json="scripts/cranelift_feature_registry.json"
family_runner="scripts/cranelift_ci_family.py"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
canonical_fixture="compiler/fixtures/native_backend_phase13_scalar_expression_ingestion.mir"
malformed_fixture="compiler/fixtures/native_backend_phase13_scalar_expression_malformed.mir"
unsupported_divide="compiler/phase13_scalar_unsupported_divide_source.gst"
invalid_operand="compiler/phase13_scalar_invalid_operand_source.gst"
unsupported_conversion="compiler/phase13_scalar_unsupported_conversion_source.gst"
layout_deferred="compiler/phase13_scalar_layout_deferred_source.gst"
build_root="build/guards/cranelift_phase13_scalar_expression"
cargo_target="$build_root/cargo-target"

for required_file in \
  "$registry_json" "$family_runner" "$rust_manifest" \
  "$canonical_fixture" "$malformed_fixture" \
  "$unsupported_divide" "$invalid_operand" \
  "$unsupported_conversion" "$layout_deferred" \
  src/runtime.c ./gust
do
  if [ ! -e "$required_file" ]; then
    echo "Phase 13 scalar-expression evidence is missing $required_file" >&2
    exit 1
  fi
done
if [ ! -x ./gust ]; then
  echo "Phase 13 scalar-expression evidence requires the rebuilt ./gust compiler." >&2
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
  echo "Phase 13 scalar-expression evidence did not build $driver_bin" >&2
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

set +e
"$driver_abs" compiler-mir-validate-fixture "$malformed_fixture" \
  >"$build_root/malformed-fixture.stdout" \
  2>"$build_root/malformed-fixture.stderr"
malformed_status="$?"
set -e
if [ "$malformed_status" = "0" ]; then
  echo "Malformed Phase 13 scalar-expression MIR unexpectedly validated." >&2
  exit 1
fi
cat "$build_root/malformed-fixture.stdout" \
    "$build_root/malformed-fixture.stderr" \
    >"$build_root/malformed-fixture.combined"
rg -n -F \
  'missing required canonical compiler MIR fixture field: block_0_statement_1_value' \
  "$build_root/malformed-fixture.combined" >/dev/null
if find "$build_root" -maxdepth 1 -type f -name '*.o' -print -quit | grep -q .; then
  echo "Scalar-expression fixture validation emitted an object before acceptance." >&2
  exit 1
fi

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
  local case_dir="$build_root/$case_name"
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
  if [ -s "$case_dir/default.compiler.stderr" ] ||
     [ -s "$case_dir/explicit.compiler.stderr" ]; then
    cat "$case_dir/default.compiler.stderr" \
        "$case_dir/explicit.compiler.stderr" >&2
    echo "Successful MIR-to-C compilation emitted diagnostics for $case_name." >&2
    exit 1
  fi
  cmp -s "$case_dir/default.c" "$case_dir/explicit.c"

  cat src/runtime.c "$case_dir/default.c" >"$case_dir/mir-to-c.final.c"
  "$CC_BIN" $CFLAGS_VAL -Isrc \
    "$case_dir/mir-to-c.final.c" \
    -o "$case_dir/mir-to-c-program"
  execute_and_capture \
    "$case_dir/mir-to-c-program" \
    "$case_dir/mir-to-c"

  if ! GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
      GUST_NATIVE_BACKEND_DRIVER="$driver_abs" \
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
  if [ -s "$case_dir/native.compiler.stdout" ] ||
     [ -s "$case_dir/native.compiler.stderr" ]; then
    cat "$case_dir/native.compiler.stdout" \
        "$case_dir/native.compiler.stderr" >&2
    echo "Successful Cranelift compilation emitted diagnostics for $case_name." >&2
    exit 1
  fi
  test -x "$case_dir/native-program"
  execute_and_capture \
    "$case_dir/native-program" \
    "$case_dir/native"

  mir_status="$(cat "$case_dir/mir-to-c.status")"
  native_status="$(cat "$case_dir/native.status")"
  if [ "$mir_status" != "$expected_status" ] ||
     [ "$native_status" != "$expected_status" ]; then
    echo "Scalar-expression status mismatch for $case_name: expected=$expected_status MIR-to-C=$mir_status Cranelift=$native_status" >&2
    exit 1
  fi
  cmp -s "$case_dir/mir-to-c.stdout" "$case_dir/native.stdout"
  cmp -s "$case_dir/mir-to-c.stderr" "$case_dir/native.stderr"
  test ! -e "$case_dir/native-program.phase10.bundle"
  test ! -e "$case_dir/native-program.phase10.request"
}

run_positive_case \
  compiler/phase11_scalar_unsupported_multiply_source.gst \
  12 \
  multiply
run_positive_case \
  compiler/phase13_scalar_subtract_source.gst \
  12 \
  subtract
run_positive_case \
  compiler/phase13_scalar_nested_mixed_source.gst \
  21 \
  nested-mixed
run_positive_case \
  compiler/phase13_scalar_arithmetic_comparison_source.gst \
  29 \
  arithmetic-comparison

poison_driver="$build_root/poison-driver"
poison_marker="$build_root/poison-driver.invoked"
cat >"$poison_driver" <<'POISON'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$GUST_PHASE13_SCALAR_POISON_MARKER"
exit 97
POISON
chmod +x "$poison_driver"
poison_driver_abs="$(cd "$(dirname "$poison_driver")" && pwd)/$(basename "$poison_driver")"

assert_deferred_before_driver() {
  local source_path="$1"
  local case_name="$2"
  local case_dir="$build_root/$case_name"
  local protected_output="$case_dir/existing-output"
  mkdir -p "$case_dir"
  rm -f "$poison_marker"
  printf 'phase13-scalar-output-sentinel\n' >"$protected_output"
  cp "$protected_output" "$protected_output.expected"

  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE13_SCALAR_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$poison_driver_abs" \
    ./gust --backend cranelift \
      -o "$protected_output" \
      "$source_path" \
      >"$case_dir/compiler.stdout" \
      2>"$case_dir/compiler.stderr"
  local status="$?"
  set -e
  if [ "$status" = "0" ]; then
    echo "Unselected scalar expression unexpectedly compiled: $case_name" >&2
    exit 1
  fi
  if [ -e "$poison_marker" ]; then
    cat "$poison_marker" >&2
    echo "Deferred scalar expression invoked the native driver: $case_name" >&2
    exit 1
  fi
  cmp -s "$protected_output.expected" "$protected_output"
  test ! -e "$protected_output.phase10.bundle"
  test ! -e "$protected_output.phase10.request"
  if find "$case_dir" -maxdepth 1 -type f \
      -name ".$(basename "$protected_output").phase10-source-route*.o" |
      grep -q .; then
    echo "Deferred scalar expression created a hidden object: $case_name" >&2
    exit 1
  fi

  cat "$case_dir/compiler.stdout" "$case_dir/compiler.stderr" \
    >"$case_dir/compiler.combined"
  rg -n -F \
    'gust_native_capability_decision: contract=gust.native_backend.capability.v1 decision=deferred capability=phase13_generic_source_to_mir owner=compiler_generic_native_capability_planner reason_code=source_feature_not_represented' \
    "$case_dir/compiler.combined" >/dev/null
  rg -n -F 'expected_failure_stage=before_driver_discovery' \
    "$case_dir/compiler.combined" >/dev/null
  if rg -n -F \
      'MIR-to-C intentionally unavailable for route architecture evidence.' \
      "$case_dir/compiler.combined" >/dev/null; then
    echo "Explicit Cranelift fell through to MIR-to-C for $case_name." >&2
    exit 1
  fi
}

assert_deferred_before_driver "$unsupported_divide" unsupported-divide
assert_deferred_before_driver "$unsupported_conversion" unsupported-conversion
assert_deferred_before_driver "$layout_deferred" layout-deferred

invalid_dir="$build_root/invalid-operand"
mkdir -p "$invalid_dir"
invalid_output="$invalid_dir/existing-output"
rm -f "$poison_marker"
printf 'phase13-scalar-invalid-output-sentinel\n' >"$invalid_output"
cp "$invalid_output" "$invalid_output.expected"
set +e
GUST_PHASE13_SCALAR_POISON_MARKER="$poison_marker" \
GUST_NATIVE_BACKEND_DRIVER="$poison_driver_abs" \
  ./gust --backend cranelift \
    -o "$invalid_output" \
    "$invalid_operand" \
    >"$invalid_dir/compiler.stdout" \
    2>"$invalid_dir/compiler.stderr"
invalid_status="$?"
set -e
if [ "$invalid_status" = "0" ]; then
  echo "Invalid scalar operands unexpectedly compiled." >&2
  exit 1
fi
if [ -e "$poison_marker" ]; then
  cat "$poison_marker" >&2
  echo "Source/type failure reached native driver discovery." >&2
  exit 1
fi
cmp -s "$invalid_output.expected" "$invalid_output"
cat "$invalid_dir/compiler.stdout" "$invalid_dir/compiler.stderr" \
  >"$invalid_dir/compiler.combined"
rg -n -F 'TypeError' "$invalid_dir/compiler.combined" >/dev/null
if rg -n -F 'kind=deferred' "$invalid_dir/compiler.combined" >/dev/null; then
  echo "Source/type failure was mislabeled as deliberate backend deferral." >&2
  exit 1
fi

echo "✅ Phase 13 scalar-expression evidence passed: MulI32 and SubI32 lower through the generic source route, compose with AddI32 and SgtI32, malformed MIR rejects before objects, and unselected conversions, layout-sensitive expressions, and operators defer before driver discovery."