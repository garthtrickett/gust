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

while IFS=$'\t' read -r kind source_fixture expected_exit expected_hash
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
    generated_c_sha256)
      test ! -s "$case_root/stderr"
      actual_hash="$(sha256sum "$case_root/stdout" | cut -d' ' -f1)"
      ;;
    diagnostic_stdout_sha256)
      test ! -s "$case_root/stderr"
      actual_hash="$(sha256sum "$case_root/stdout" | cut -d' ' -f1)"
      ;;
    *)
      echo "unknown Patch 21.2 semantic-delta kind: $kind" >&2
      exit 1
      ;;
  esac
  test "$actual_hash" = "$expected_hash"
done < <(python3 scripts/phase21_inert_scoped_query_records.py semantic-delta-cases)

echo "✅ Phase 21.2 inert records passed: opaque/private round-trip and zero semantic delta"
