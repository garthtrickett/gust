#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

inferred_fixture="tests/stdlib_s1_clone_destination_inferred.gst"
explicit_fixture="tests/stdlib_s1_clone_destination_explicit.gst"
wrong_brand_fixture="tests/stdlib_s1_clone_wrong_brand_rejected.gst"
moved_destination_fixture="tests/stdlib_s1_clone_moved_destination_rejected.gst"
freed_destination_fixture="tests/stdlib_s1_clone_freed_destination_rejected.gst"
build_dir="build/guards/stdlib_s1_clone_destination"

# Patch 25.6: src/runtime.c is no longer a complete runtime. fiber.c is
# deleted and its eighteen exports live in the runtime crate, and codegen
# emits a gust_yield() call in every loop of every compiled Gust program,
# so this link needs the crate object. Built through make so a stale one
# cannot be linked silently.
runtime_obj="build/phase25-runtime-rs/gust_runtime_rs_exports.o"
make "$runtime_obj"
expected_status=65

if [ ! -x ./gust ]; then
  echo "S1.5 clone destination parity requires the rebuilt ./gust compiler." >&2
  exit 1
fi

for fixture in \
  "$inferred_fixture" \
  "$explicit_fixture" \
  "$wrong_brand_fixture" \
  "$moved_destination_fixture" \
  "$freed_destination_fixture"
do
  if [ ! -f "$fixture" ]; then
    echo "Missing S1.5 fixture: $fixture" >&2
    exit 1
  fi
done

for token in \
  'mut owned_text: str := std.Clone(local_arena, "owned")' \
  'mut referenced_text: str := std.Clone(&local_arena, "reference")' \
  'mut helper_text: str := clone_text(&local_arena, "helper")' \
  'mut field_text: str := std.Clone(holder.destination, "field")' \
  'mut field_reference_text: str := std.Clone(&holder.destination, "field-ref")' \
  'mut record: S1CloneText[local_arena] := clone_record(&local_arena, "record")'
do
  rg -n -F "$token" "$explicit_fixture" >/dev/null
done
for token in \
  'mut owned_text := std.Clone(local_arena, "owned")' \
  'mut referenced_text := std.Clone(&local_arena, "reference")' \
  'mut helper_text := clone_text(&local_arena, "helper")' \
  'mut field_text := std.Clone(holder.destination, "field")' \
  'mut field_reference_text := std.Clone(&holder.destination, "field-ref")' \
  'mut record := clone_record(&local_arena, "record")'
do
  rg -n -F "$token" "$inferred_fixture" >/dev/null
done

if rg -n -e 'Arena\*' -e 'Arena\*\*' -e 'unsafe' \
    "$inferred_fixture" "$explicit_fixture" >/dev/null; then
  echo "The safe S1.5 source exposes a backend arena representation or unsafe workaround." >&2
  exit 1
fi

rm -rf "$build_dir"
mkdir -p "$build_dir"

# Issue #398: served from the frozen corpus instead of invoking the retired
# spelling. Each fixture was emitted TWICE with identical arguments, so the
# first two comparisons below compared the backend against itself and could
# not fail; one replay per fixture preserves everything they checked. The
# cross-fixture comparison is the real one and is kept.
python3 scripts/phase24_frozen_oracle.py materialize \
  "$inferred_fixture" "$build_dir/inferred" --kind exec
test "$(cat "$build_dir/inferred.compile.status")" = "0"
test ! -s "$build_dir/inferred.compile.stderr"
cp "$build_dir/inferred.compile.stdout" "$build_dir/inferred-default.c"
cp "$build_dir/inferred.compile.stdout" "$build_dir/inferred-explicit-backend.c"
python3 scripts/phase24_frozen_oracle.py materialize \
  "$explicit_fixture" "$build_dir/explicit" --kind exec
test "$(cat "$build_dir/explicit.compile.status")" = "0"
test ! -s "$build_dir/explicit.compile.stderr"
cp "$build_dir/explicit.compile.stdout" "$build_dir/explicit-default.c"
cp "$build_dir/explicit.compile.stdout" "$build_dir/explicit-explicit-backend.c"

for stderr_file in "$build_dir"/*.stderr; do
  test ! -s "$stderr_file"
done
cmp -s "$build_dir/inferred-default.c" "$build_dir/inferred-explicit-backend.c"
cmp -s "$build_dir/explicit-default.c" "$build_dir/explicit-explicit-backend.c"
cmp -s "$build_dir/inferred-default.c" "$build_dir/explicit-default.c"

# Exact C equality pins semantic type, ABI/layout, destination identity, and
# backend input. These lines also prove the frontend/codegen representation
# plan normalized owned Arena values and &Arena references before emission.
generated="$build_dir/explicit-default.c"
for canonical in \
  'S1CloneText clone_record(os_Arena* destination, Slice_unsigned_char input);' \
  'Slice_unsigned_char clone_text(os_Arena* destination, Slice_unsigned_char input);' \
  '    return std_Clone_str(destination, input);' \
  '    result.value = std_Clone_str(destination, input);' \
  '    Slice_unsigned_char owned_text = std_Clone_str(&(local_arena), ((Slice_unsigned_char){ (unsigned char*)"owned", 5 }));' \
  '    Slice_unsigned_char referenced_text = std_Clone_str(&(local_arena), ((Slice_unsigned_char){ (unsigned char*)"reference", 9 }));' \
  '    Slice_unsigned_char field_text = std_Clone_str(&(holder.destination), ((Slice_unsigned_char){ (unsigned char*)"field", 5 }));' \
  '    Slice_unsigned_char field_reference_text = std_Clone_str(&(holder.destination), ((Slice_unsigned_char){ (unsigned char*)"field-ref", 9 }));'
do
  rg -n -x -F "$canonical" "$generated" >/dev/null
done

if rg -n -F -e 'std_Clone_str(&(destination)' \
              -e 'std_Clone_str(&(&(local_arena))' \
              -e 'std_Clone_str(&(&(holder.destination))' \
              "$generated" >/dev/null; then
  echo "Clone destination normalization emitted an Arena**-shaped call." >&2
  exit 1
fi

for variant in inferred explicit; do
  # Patch 25.12b: src/runtime.c is gone. It had been reduced to exactly
  # two effective lines -- the two #includes below -- with its other 27
  # recording which files had already left. These frozen-replay guards
  # were its last three consumers.
  { printf '#include "runtime/core_headers.h"\n#include <errno.h>\n'; \
    cat "$build_dir/$variant-default.c"; } >"$build_dir/$variant-final.c"
  "${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
    "$build_dir/$variant-final.c" "$runtime_obj" \
    -o "$build_dir/$variant-program"
  if "$build_dir/$variant-program" \
      >"$build_dir/$variant-runtime.stdout" 2>"$build_dir/$variant-runtime.stderr"; then
    actual_status=0
  else
    actual_status=$?
  fi
  if [ "$actual_status" != "$expected_status" ]; then
    echo "S1.5 $variant MIR-to-C returned $actual_status, expected $expected_status." >&2
    exit 1
  fi
  test ! -s "$build_dir/$variant-runtime.stdout"
  test ! -s "$build_dir/$variant-runtime.stderr"
done

assert_rejected() {
  local fixture="$1"
  shift
  local name
  name="$(basename "$fixture" .gst)"
  local output="$build_dir/$name.output"
  # Issue #398: the refusal is replayed, not re-provoked.
  python3 scripts/phase24_frozen_oracle.py materialize \
    "$fixture" "$build_dir/$name.reject" --kind reject
  if [ "$(cat "$build_dir/$name.reject.compile.status")" = "0" ]; then
    echo "$fixture must be rejected, but the frozen record compiles." >&2
    exit 1
  fi
  cat "$build_dir/$name.reject.compile.stdout" "$build_dir/$name.reject.compile.stderr" >"$output"
  for token in "$@"; do
    rg -n -F "$token" "$output" >/dev/null
  done
}

assert_rejected "$wrong_brand_fixture" \
  'Semantic Error: [TypeMismatch] Explicit Type Annotation Mismatch.' \
  'S1CloneWrongBrandNode_source_arena' \
  'S1CloneWrongBrandNode_destination_arena'
assert_rejected "$moved_destination_fixture" \
  'Semantic Error: Use of moved variable destination'
assert_rejected "$freed_destination_fixture" \
  "Semantic Error: [ArenaUseAfterFree] Arena identity 'main::destination' is already freed; rejected Clone destination use"

# Generic source-to-MIR remains outside the connected native cohort. Require
# the compiler-owned deferral for both halves before driver discovery, with no
# C fallback or native artifact.
for variant in inferred explicit; do
  fixture_var="${variant}_fixture"
  fixture="${!fixture_var}"
  if GUST_NATIVE_BACKEND_DRIVER="$build_dir/deliberately-absent-driver" \
      ./gust --backend cranelift -o "$build_dir/$variant-native-program" "$fixture" \
        >"$build_dir/$variant-native.stdout" 2>"$build_dir/$variant-native.stderr"; then
    echo "Explicit Cranelift unexpectedly accepted the deferred S1.5 $variant fixture." >&2
    exit 1
  fi
  for token in \
    'decision=deferred capability=phase13_generic_source_to_mir' \
    'reason_code=deferred_p13_parameter_argument_aggregate_return' \
    'expected_failure_stage=before_driver_discovery' \
    'class=unsupported_native_capability' \
    'source-level route is not connected yet'
  do
    rg -n -F "$token" "$build_dir/$variant-native.stdout" >/dev/null
  done
  test ! -e "$build_dir/$variant-native-program"
  test ! -s "$build_dir/$variant-native.stderr"
done

echo "guard-stdlib-s1-clone-destination: ok (byte-identical paired C, MIR-to-C exit $expected_status, wrong/moved/freed destinations rejected, explicit Cranelift deferred without fallback; Level 1 + Level 2)"
