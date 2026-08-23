#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase20_resource_declaration_migration"
fixtures=(
  "compiler/phase13_composition_resource_metadata_source.gst:17"
  "compiler/phase13_source_resource_metadata_source.gst:31"
  "compiler/phase13_resource_cleanup_deferred_source.gst:7"
  "compiler/future/phase14_resource_cleanup_source.gst:9"
)

python3 scripts/phase20_resource_declaration_migration.py validate
rm -rf "$build_root"
mkdir -p "$build_root"

for fixture_entry in "${fixtures[@]}"; do
  fixture="${fixture_entry%%:*}"
  expected="${fixture_entry##*:}"
  stem="$(basename "$fixture" .gst)"
  ./gust "$fixture" >"$build_root/$stem.default.c" \
    2>"$build_root/$stem.default.stderr"
  ./gust --backend mir-to-c "$fixture" \
    >"$build_root/$stem.explicit.c" \
    2>"$build_root/$stem.explicit.stderr"
  test ! -s "$build_root/$stem.default.stderr"
  test ! -s "$build_root/$stem.explicit.stderr"
  cmp -s "$build_root/$stem.default.c" "$build_root/$stem.explicit.c"
  cat src/runtime.c "$build_root/$stem.default.c" >"$build_root/$stem.final.c"
  "${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
    "$build_root/$stem.final.c" -o "$build_root/$stem.program"
  set +e
  "$build_root/$stem.program" \
    >"$build_root/$stem.stdout" 2>"$build_root/$stem.stderr"
  status="$?"
  set -e
  test "$status" = "$expected"
  test ! -s "$build_root/$stem.stdout"
  test ! -s "$build_root/$stem.stderr"
done

echo "✅ Phase 20 resource declaration migration passed"
