#!/usr/bin/env bash
set -euo pipefail

python3 scripts/phase21_inert_scoped_query_records.py validate

build_root="build/guards/phase21_inert_scoped_query_records"
rm -rf "$build_root"
mkdir -p "$build_root"

just guard-positive \
  compiler/typed_query_semantic_records_test_entry.gst \
  phase21_inert_scoped_query_records_round_trip
just guard-compile-fail \
  compiler/typed_query_semantic_records_forge_invalid.gst \
  OpaqueConstruction \
  phase21_inert_scoped_query_records_ordinary_forge
just guard-compile-fail \
  compiler/typed_query_semantic_records_private_constructor_invalid.gst \
  PrivateDeclarationAccess \
  phase21_inert_scoped_query_records_private_constructor

while IFS=$'\t' read -r kind source_fixture expected_exit expected_runtime diagnostic generated_c_golden
do
  case_name="$(basename "$source_fixture" .gst)"
  case_root="$build_root/$case_name"
  mkdir -p "$case_root"
  set +e
  ./gust --backend mir-to-c "$source_fixture" \
    >"$case_root/stdout" 2>"$case_root/stderr"
  actual_exit="$?"
  set -e
  test "$actual_exit" = "$expected_exit"
  case "$kind" in
    generated_c_golden_and_runtime_observation)
      test ! -s "$case_root/stderr"
      cmp -s \
        <(perl -0pe 's/\n+\z/\n/' "$case_root/stdout") \
        "$generated_c_golden"
      cat src/runtime.c "$case_root/stdout" >"$case_root/final.c"
      "${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
        "$case_root/final.c" -o "$case_root/program"
      set +e
      "$case_root/program" >"$case_root/runtime.stdout" \
        2>"$case_root/runtime.stderr"
      actual_runtime="$?"
      set -e
      test "$actual_runtime" = "$expected_runtime"
      test ! -s "$case_root/runtime.stdout"
      test ! -s "$case_root/runtime.stderr"
      ;;
    unchanged_source_and_exact_diagnostic)
      test ! -s "$case_root/stderr"
      rg -F "Semantic Error: [OpaqueConstruction] $diagnostic" \
        "$case_root/stdout" >/dev/null
      ;;
    *)
      echo "unknown Patch 21.2 semantic-delta kind: $kind" >&2
      exit 1
      ;;
  esac
done < <(python3 scripts/phase21_inert_scoped_query_records.py semantic-delta-cases)

echo "✅ Phase 21.2 inert records passed: opaque/private round-trip and zero semantic delta"
