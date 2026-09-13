#!/usr/bin/env bash
set -euo pipefail

python3 scripts/phase21_typed_query_noop_surface.py validate

build_root="build/guards/phase21_typed_query_noop_surface"
rm -rf "$build_root"
mkdir -p "$build_root"

just guard-positive \
  compiler/parser_phase21_typed_query_noop_surface_test_entry.gst \
  phase21_typed_query_noop_parser

surface_root="$build_root/complete-surface"
mkdir -p "$surface_root"
python3 scripts/phase24_frozen_oracle.py materialize \
  compiler/phase21_typed_query_noop_surface.gst "$surface_root/frozen" \
  --kind exec
test ! -s "$surface_root/frozen.compile.stderr"
cp "$surface_root/frozen.stdout" "$surface_root/stdout"
cp "$surface_root/frozen.stderr" "$surface_root/stderr"
surface_status="$(cat "$surface_root/frozen.status")"
test "$surface_status" = 37
test ! -s "$surface_root/stdout"
test ! -s "$surface_root/stderr"

worker="build/gust-native-backend"
if [ ! -x "$worker" ]; then
  make "$worker"
fi
worker_abs="$PWD/$worker"

while IFS=$'\t' read -r source_fixture expected_exit
do
  case_name="$(basename "$source_fixture" .gst)"
  case_root="$build_root/$case_name"
  mkdir -p "$case_root"
  python3 scripts/phase24_frozen_oracle.py materialize \
    "$source_fixture" "$case_root/mir-to-c" --kind exec
  test ! -s "$case_root/mir-to-c.compile.stderr"
  GUST_NATIVE_BACKEND_DRIVER="$worker_abs" \
    ./gust --backend cranelift -o "$case_root/native-program" \
      "$source_fixture" >"$case_root/native.compile.stdout" \
      2>"$case_root/native.compile.stderr"
  test ! -s "$case_root/native.compile.stdout"
  test ! -s "$case_root/native.compile.stderr"

  mir_status="$(cat "$case_root/mir-to-c.status")"
  set +e
  "$case_root/native-program" >"$case_root/native.stdout" \
    2>"$case_root/native.stderr"
  native_status="$?"
  set -e
  test "$mir_status" = "$expected_exit"
  test "$native_status" = "$expected_exit"
  cmp -s "$case_root/mir-to-c.stdout" "$case_root/native.stdout"
  cmp -s "$case_root/mir-to-c.stderr" "$case_root/native.stderr"
done < <(python3 scripts/phase21_typed_query_noop_surface.py witness-cases)

echo "✅ Phase 21.3 typed-query no-op surface passed: complete syntax, seed-built parser, and preserved backend observations"
