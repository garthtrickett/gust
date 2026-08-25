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
./gust --backend mir-to-c compiler/phase21_typed_query_noop_surface.gst \
  >"$surface_root/generated.c" 2>"$surface_root/compile.stderr"
test ! -s "$surface_root/compile.stderr"
cat src/runtime.c "$surface_root/generated.c" >"$surface_root/final.c"
"${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
  "$surface_root/final.c" -o "$surface_root/program"
set +e
"$surface_root/program" >"$surface_root/stdout" 2>"$surface_root/stderr"
surface_status="$?"
set -e
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
  ./gust --backend mir-to-c "$source_fixture" \
    >"$case_root/generated.c" 2>"$case_root/mir-to-c.compile.stderr"
  test ! -s "$case_root/mir-to-c.compile.stderr"
  cat src/runtime.c "$case_root/generated.c" >"$case_root/final.c"
  "${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
    "$case_root/final.c" -o "$case_root/mir-to-c-program"
  GUST_NATIVE_BACKEND_DRIVER="$worker_abs" \
    ./gust --backend cranelift -o "$case_root/native-program" \
      "$source_fixture" >"$case_root/native.compile.stdout" \
      2>"$case_root/native.compile.stderr"
  test ! -s "$case_root/native.compile.stdout"
  test ! -s "$case_root/native.compile.stderr"

  set +e
  "$case_root/mir-to-c-program" >"$case_root/mir-to-c.stdout" \
    2>"$case_root/mir-to-c.stderr"
  mir_status="$?"
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
