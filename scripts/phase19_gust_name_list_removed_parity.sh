#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

build_dir="build/guards/phase19_name_list_removed"
ctx_source="compiler/phase19_name_list_removed_ctx_source.gst"
region_source="compiler/phase19_name_list_removed_region_source.gst"

if [ ! -x ./gust ]; then
  echo "Phase 19.8 name-list removal parity requires the rebuilt ./gust compiler." >&2
  exit 1
fi

rm -rf "$build_dir"
mkdir -p "$build_dir"

normalise_source() {
  grep -v '^[[:space:]]*//' "$1" | sed "s/\b$2\b/BRAND/g"
}

diff <(normalise_source "$ctx_source" ctx) \
     <(normalise_source "$region_source" region) >/dev/null || {
  echo "Phase 19.8 parity sources differ by more than the brand spelling." >&2
  exit 1
}

for arm in ctx region; do
  source_path="$ctx_source"
  if [ "$arm" = region ]; then source_path="$region_source"; fi
  ./gust "$source_path" >"$build_dir/$arm.c" 2>"$build_dir/$arm.compiler.stderr"
  test ! -s "$build_dir/$arm.compiler.stderr"
  cat src/runtime.c "$build_dir/$arm.c" >"$build_dir/$arm.final.c"
  "${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
    "$build_dir/$arm.final.c" -o "$build_dir/$arm.program"
  set +e
  "$build_dir/$arm.program"
  status=$?
  set -e
  if [ "$status" != 19 ]; then
    echo "Phase 19.8 $arm arm returned $status, expected 19." >&2
    exit 1
  fi
done

rg -n -F 'Phase19NameListHolder' "$build_dir/ctx.c" "$build_dir/region.c" >/dev/null
if rg -n -F 'phase19_legacy_brand_' "$build_dir/ctx.c" "$build_dir/region.c" >/dev/null; then
  echo "Generated parity output still contains the retired spelling authority." >&2
  exit 1
fi

echo "guard-cranelift-phase19-gust-name-list-removed-parity: ok (Level 2)"
