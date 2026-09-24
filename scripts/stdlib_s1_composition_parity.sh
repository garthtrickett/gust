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

# Issue #398: served from the frozen corpus instead of invoking the retired
# spelling. The two emissions this replaced were byte-identical invocations --
# the `cmp` between them compared the backend against itself and could not
# fail, which is why replaying one record loses nothing. What the guard is
# actually for is the canonical-name assertions below, and those read the
# recorded C.
python3 scripts/phase24_frozen_oracle.py materialize \
  "$source_fixture" "$build_dir/explicit" --kind exec
test "$(cat "$build_dir/explicit.compile.status")" = "0"
test ! -s "$build_dir/explicit.compile.stderr"
cp "$build_dir/explicit.compile.stdout" "$build_dir/explicit.c"

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

# Patch 25.12b: src/runtime.c is gone. It had been reduced to exactly
# two effective lines -- the two #includes below -- with its other 27
# recording which files had already left. These frozen-replay guards
# were its last three consumers.
{ printf '#include "runtime/core_headers.h"\n#include <errno.h>\n'; \
  cat "$build_dir/explicit.c"; } >"$build_dir/final.c"
# Patch 25.6: src/runtime.c is no longer a complete runtime. fiber.c is
# deleted and its eighteen exports live in the runtime crate, and codegen
# emits a gust_yield() call in every loop of every compiled Gust program,
# so this link needs the crate object. Built through make so a stale one
# cannot be linked silently.
runtime_obj="build/phase25-runtime-rs/gust_runtime_rs_exports.o"
make "$runtime_obj"
"${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
  "$build_dir/final.c" "$runtime_obj" -o "$build_dir/mir-to-c-program"
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
