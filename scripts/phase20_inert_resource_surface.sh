#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase20_inert_resource_surface"
metadata_fixture="compiler/parser_phase20_inert_resource_surface_test_entry.gst"
transition_fixture="compiler/phase20_inert_resource_surface_source.gst"

python3 scripts/phase20_inert_resource_surface.py validate
just guard-positive "$metadata_fixture" phase20_inert_resource_surface_metadata

rm -rf "$build_root"
mkdir -p "$build_root"
set +e
./gust "$transition_fixture" >"$build_root/default.log" 2>&1
default_status="$?"
./gust --backend mir-to-c "$transition_fixture" \
  >"$build_root/explicit.log" 2>&1
explicit_status="$?"
./gust --backend cranelift -o "$build_root/native" "$transition_fixture" \
  >"$build_root/cranelift.log" 2>&1
native_status="$?"
set -e
test "$default_status" -ne 0
test "$explicit_status" = "$default_status"
test "$native_status" = "$default_status"
cmp -s "$build_root/default.log" "$build_root/explicit.log"
cmp -s "$build_root/default.log" "$build_root/cranelift.log"
test "$(rg -c 'Semantic Error:' "$build_root/default.log")" = 3
for diagnostic in OpaqueConstruction OpaqueRepresentationAccess PrivateDeclarationAccess; do
  test "$(rg -c "\[$diagnostic\]" "$build_root/default.log")" = 1
done
test ! -e "$build_root/native"

echo "✅ Phase 20 inert resource surface and enforcement transition passed"
