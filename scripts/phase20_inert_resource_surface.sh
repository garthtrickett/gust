#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase20_inert_resource_surface"
metadata_fixture="compiler/parser_phase20_inert_resource_surface_test_entry.gst"
noop_fixture="compiler/phase20_inert_resource_surface_source.gst"

python3 scripts/phase20_inert_resource_surface.py validate
just guard-positive "$metadata_fixture" phase20_inert_resource_surface_metadata

rm -rf "$build_root"
mkdir -p "$build_root"
./gust "$noop_fixture" >"$build_root/default.c" 2>"$build_root/default.stderr"
./gust --backend mir-to-c "$noop_fixture" \
  >"$build_root/explicit.c" 2>"$build_root/explicit.stderr"
test ! -s "$build_root/default.stderr"
test ! -s "$build_root/explicit.stderr"
cmp -s "$build_root/default.c" "$build_root/explicit.c"

cat src/runtime.c "$build_root/default.c" >"$build_root/final.c"
"${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
  "$build_root/final.c" -o "$build_root/program"
set +e
"$build_root/program" >"$build_root/stdout" 2>"$build_root/stderr"
status="$?"
set -e
test "$status" = 42
test ! -s "$build_root/stdout"
test ! -s "$build_root/stderr"

echo "✅ Phase 20 inert resource declaration surface passed"
