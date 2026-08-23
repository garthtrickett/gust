#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

inferred_fixture="tests/stdlib_s1_branded_collections_inferred.gst"
explicit_fixture="tests/stdlib_s1_branded_collections_explicit.gst"
wrong_arena_fixture="tests/stdlib_s1_branded_collections_wrong_arena_rejected.gst"
incompatible_value_fixture="tests/stdlib_s1_branded_collections_incompatible_value_rejected.gst"
moved_fixture="tests/test_hashmap_reference_use_after_move_rejected.gst"
build_dir="build/guards/stdlib_s1_branded_collections"
expected_status=64

if [ ! -x ./gust ]; then
  echo "S1.4 branded collection parity requires the rebuilt ./gust compiler." >&2
  exit 1
fi

for fixture in \
  "$inferred_fixture" \
  "$explicit_fixture" \
  "$wrong_arena_fixture" \
  "$incompatible_value_fixture" \
  "$moved_fixture"
do
  if [ ! -f "$fixture" ]; then
    echo "Missing S1.4 fixture: $fixture" >&2
    exit 1
  fi
done

# The pair covers every branded constructor family whose generic contextual
# result authority landed with CR-11, plus Gust's actual slice spelling.
for token in \
  'std.Vector[int, application_arena]' \
  'std.HashMap[str, int, application_arena]' \
  'std.Pool[S1BrandedItem, application_arena]' \
  'std.Graph[S1BrandedItem, application_arena]' \
  'std.Mutex[int, application_arena]' \
  'std.Channel[int, application_arena]' \
  'std.Vector[std.Vector[int, application_arena], application_arena]' \
  'std.Vector[str, application_arena]' \
  'bytes_value: []byte'
do
  rg -n -F "$token" "$explicit_fixture" >/dev/null
done
for token in \
  'mut vector_value := make_vector' \
  'mut mutex_value := make_mutex' \
  'mut keys_value := map_value.Keys' \
  'bytes_value := empty_bundle.bytes'
do
  rg -n -F "$token" "$inferred_fixture" >/dev/null
done

rm -rf "$build_dir"
mkdir -p "$build_dir"

./gust "$inferred_fixture" \
  >"$build_dir/inferred-default.c" 2>"$build_dir/inferred-default.stderr"
./gust --backend mir-to-c "$inferred_fixture" \
  >"$build_dir/inferred-explicit-backend.c" 2>"$build_dir/inferred-explicit-backend.stderr"
./gust "$explicit_fixture" \
  >"$build_dir/explicit-default.c" 2>"$build_dir/explicit-default.stderr"
./gust --backend mir-to-c "$explicit_fixture" \
  >"$build_dir/explicit-explicit-backend.c" 2>"$build_dir/explicit-explicit-backend.stderr"

for stderr_file in "$build_dir"/*.stderr; do
  test ! -s "$stderr_file"
done
cmp -s "$build_dir/inferred-default.c" "$build_dir/inferred-explicit-backend.c"
cmp -s "$build_dir/explicit-default.c" "$build_dir/explicit-explicit-backend.c"
cmp -s "$build_dir/inferred-default.c" "$build_dir/explicit-default.c"

# Exact generated C equality is the strongest current evidence for semantic
# type, ABI, layout, and brand equality: the annotation cannot change any type
# definition, function prototype, field, initializer, or call site.
generated="$build_dir/explicit-default.c"
for canonical in \
  'typedef struct std_Vector_int std_Vector_int;' \
  'typedef struct std_HashMap_str_int std_HashMap_str_int;' \
  'typedef struct std_Pool_S1BrandedItem std_Pool_S1BrandedItem;' \
  'typedef struct std_Graph_S1BrandedItem std_Graph_S1BrandedItem;' \
  'typedef struct std_Mutex_int std_Mutex_int;' \
  'typedef struct std_Channel_int std_Channel_int;' \
  'typedef struct std_Vector_std_Vector_int std_Vector_std_Vector_int;' \
  '    Slice_unsigned_char bytes;' \
  'std_Vector_int make_vector(os_Arena* ctx);' \
  'std_HashMap_str_int make_map(os_Arena* ctx);' \
  'std_Pool_S1BrandedItem make_pool(os_Arena* ctx);' \
  'std_Graph_S1BrandedItem make_graph(os_Arena* ctx);' \
  'std_Mutex_int make_mutex(os_Arena* ctx);' \
  'std_Channel_int make_channel(os_Arena* ctx);'
do
  rg -n -x -F "$canonical" "$generated" >/dev/null
done

if rg -n -e 'std_(Vector|HashMap|Pool|Graph|Mutex|Channel)_[A-Za-z0-9_]*application_arena' \
          -e '(std_)?(Vector|HashMap|Pool|Graph|Mutex|Channel)_Any' \
          "$generated" >/dev/null; then
  echo "An inferred placeholder or source arena spelling leaked into a canonical S1.4 type." >&2
  exit 1
fi

for variant in inferred explicit; do
  cat src/runtime.c "$build_dir/$variant-default.c" >"$build_dir/$variant-final.c"
  "${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
    "$build_dir/$variant-final.c" -o "$build_dir/$variant-program"
  if "$build_dir/$variant-program" \
      >"$build_dir/$variant-runtime.stdout" 2>"$build_dir/$variant-runtime.stderr"; then
    actual_status=0
  else
    actual_status=$?
  fi
  if [ "$actual_status" != "$expected_status" ]; then
    echo "S1.4 $variant MIR-to-C returned $actual_status, expected $expected_status." >&2
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
  if ./gust "$fixture" >"$output" 2>&1; then
    echo "$fixture must be rejected, but it compiled." >&2
    exit 1
  fi
  for token in "$@"; do
    rg -n -F "$token" "$output" >/dev/null
  done
}

assert_rejected "$wrong_arena_fixture" \
  'Semantic Error: [TypeMismatch] Explicit Type Annotation Mismatch.' \
  'std_Channel_int_destination_arena' \
  'std_Channel_int_ctx' \
  'source_arena'
assert_rejected "$incompatible_value_fixture" \
  'Semantic Error: Argument type mismatch for Vector.Push.' \
  'S1ForeignItem_collection_arena' \
  'S1ForeignItem_foreign_arena'
assert_rejected "$moved_fixture" \
  'Semantic Error: Use of moved variable m'

# Generic source-to-MIR is still outside the connected native cohort. Require
# the compiler-owned deferral for both halves before driver discovery, with no
# C fallback or native artifact.
for variant in inferred explicit; do
  fixture_var="${variant}_fixture"
  fixture="${!fixture_var}"
  if GUST_NATIVE_BACKEND_DRIVER="$build_dir/deliberately-absent-driver" \
      ./gust --backend cranelift -o "$build_dir/$variant-native-program" "$fixture" \
        >"$build_dir/$variant-native.stdout" 2>"$build_dir/$variant-native.stderr"; then
    echo "Explicit Cranelift unexpectedly accepted the deferred S1.4 $variant fixture." >&2
    exit 1
  fi
  for token in \
    'decision=deferred capability=phase13_generic_source_to_mir' \
    'reason_code=deferred_p13_parameter_argument_target_dependent_abi' \
    'expected_failure_stage=before_driver_discovery' \
    'class=unsupported_native_capability' \
    'source-level route is not connected yet'
  do
    rg -n -F "$token" "$build_dir/$variant-native.stdout" >/dev/null
  done
  test ! -e "$build_dir/$variant-native-program"
  test ! -s "$build_dir/$variant-native.stderr"
done

echo "guard-stdlib-s1-branded-collections: ok (byte-identical paired C, MIR-to-C exit $expected_status, misuse rejected, explicit Cranelift deferred without fallback; Level 1 + Level 2)"
