#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

source_fixture="tests/stdlib_s1_composition.gst"
build_dir="build/guards/stdlib_s1_composition"
expected_status=76

if [ ! -x ./gust ]; then
  echo "S1.6 composition parity requires the rebuilt ./gust compiler." >&2
  exit 1
fi

for token in \
  'std.HashMap[str, int, application_arena]' \
  'mut keys := setting_keys' \
  'std.Vector[str, application_arena]' \
  'std.Clone(destination, key)' \
  'settings: &std.HashMap[str, int, ctx]' \
  'return settings.Keys(destination)'
do
  rg -n -F "$token" "$source_fixture" >/dev/null
done

rm -rf "$build_dir"
mkdir -p "$build_dir"

./gust "$source_fixture" >"$build_dir/default.c" 2>"$build_dir/default.stderr"
./gust --backend mir-to-c "$source_fixture" \
  >"$build_dir/explicit.c" 2>"$build_dir/explicit.stderr"
test ! -s "$build_dir/default.stderr"
test ! -s "$build_dir/explicit.stderr"
cmp -s "$build_dir/default.c" "$build_dir/explicit.c"

# Phase 19 makes arena spelling invisible to generated collection types. These
# canonical names cover layout and ABI consumers without reconstructing brands
# in this stdlib guard.
for canonical in \
  'typedef struct std_HashMap_str_int std_HashMap_str_int;' \
  'std_Vector_str setting_keys(std_HashMap_str_int* settings, os_Arena* destination);'
do
  rg -n -x -F "$canonical" "$build_dir/explicit.c" >/dev/null
done
if rg -n -e 'std_HashMap_str_int_application_arena' \
           -e 'std_Vector_str_application_arena' \
           "$build_dir/explicit.c" >/dev/null; then
  echo "A source arena spelling leaked into a canonical collection type." >&2
  exit 1
fi

cat src/runtime.c "$build_dir/explicit.c" >"$build_dir/final.c"
"${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
  "$build_dir/final.c" -o "$build_dir/mir-to-c-program"
if "$build_dir/mir-to-c-program" \
    >"$build_dir/runtime.stdout" 2>"$build_dir/runtime.stderr"; then
  actual_status=0
else
  actual_status=$?
fi
if [ "$actual_status" != "$expected_status" ]; then
  echo "S1.6 MIR-to-C returned $actual_status, expected $expected_status." >&2
  exit 1
fi
test ! -s "$build_dir/runtime.stdout"
test ! -s "$build_dir/runtime.stderr"

# Generic source-to-MIR is still outside the connected native cohort. Require
# the compiler-owned deferral before driver discovery and prove there is no C
# fallback or native artifact.
if GUST_NATIVE_BACKEND_DRIVER="$build_dir/deliberately-absent-driver" \
    ./gust --backend cranelift -o "$build_dir/native-program" "$source_fixture" \
      >"$build_dir/native.stdout" 2>"$build_dir/native.stderr"; then
  echo "Explicit Cranelift unexpectedly accepted the deferred S1.6 fixture." >&2
  exit 1
fi
for token in \
  'decision=deferred capability=phase13_generic_source_to_mir' \
  'reason_code=deferred_p13_parameter_argument_target_dependent_abi' \
  'expected_failure_stage=before_driver_discovery' \
  'class=unsupported_native_capability' \
  'source-level route is not connected yet'
do
  rg -n -F "$token" "$build_dir/native.stdout" >/dev/null
done
test ! -e "$build_dir/native-program"
test ! -s "$build_dir/native.stderr"

echo "guard-stdlib-s1-composition: ok (MIR-to-C exit $expected_status; explicit Cranelift deferred without fallback, Level 2)"
