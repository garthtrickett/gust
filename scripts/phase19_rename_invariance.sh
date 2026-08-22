#!/usr/bin/env bash
# Phase 19 rename-invariance evidence.
#
# Two sources differ only in one arena-parameter spelling. Patch 19.1 recorded
# that the renamed arm emitted an undeclared canonical allocation target and
# failed in C. Patch 19.3 makes each arm internally consistent: both compile,
# while the custom `scratch` identity still remained in its C type name. The
# later type-derived convergence and name-list removal patches eliminated that
# remaining semantic difference. This final guard requires canonical type names
# and byte-identical generated C after normalizing the deliberately renamed
# source local.
set -euo pipefail

brand_source="compiler/phase19_rename_invariance_brand_source.gst"
renamed_source="compiler/phase19_rename_invariance_renamed_source.gst"
build_dir="build/guards/cranelift_phase19_rename_invariance"

echo "🔒 Verifying Phase 19 rename invariance..."

if [ ! -x ./gust ]; then
  echo "Phase 19 rename-invariance guard requires the rebuilt ./gust compiler."
  exit 1
fi

rm -rf "$build_dir"
mkdir -p "$build_dir"

CC_BIN="${CC:-cc}"
CFLAGS_VAL="${CFLAGS:--O0 -w -pthread}"

# The two sources must differ only in the arena parameter spelling. If someone
# edits one arm, the baseline stops meaning anything, so prove it first.
# Comments explain each arm and are expected to differ; the code must not.
normalise_source() {
  grep -v '^[[:space:]]*//' "$1" | sed "s/\\b$2\\b/BRAND/g"
}
if ! diff <(normalise_source "$brand_source" ctx) \
          <(normalise_source "$renamed_source" scratch) >/dev/null; then
  echo "The two rename-invariance arms differ by more than the arena spelling."
  diff -u <(normalise_source "$brand_source" ctx) \
          <(normalise_source "$renamed_source" scratch) || true
  exit 1
fi

for arm in brand renamed; do
  case "$arm" in
    brand)   source_path="$brand_source" ;;
    renamed) source_path="$renamed_source" ;;
  esac
  if ! ./gust "$source_path" >"$build_dir/$arm.c" 2>"$build_dir/$arm.compiler.stderr"; then
    echo "MIR-to-C rejected $arm arm $source_path."
    cat "$build_dir/$arm.compiler.stderr"
    exit 1
  fi
  if [ -s "$build_dir/$arm.compiler.stderr" ]; then
    echo "MIR-to-C emitted diagnostics for the $arm arm."
    cat "$build_dir/$arm.compiler.stderr"
    exit 1
  fi
  cat src/runtime.c "$build_dir/$arm.c" >"$build_dir/$arm.final.c"
done

# Both arms compile with Gust and must now survive the C compiler.
set +e
"$CC_BIN" $CFLAGS_VAL -Isrc "$build_dir/brand.final.c" -o "$build_dir/brand-program" \
  2>"$build_dir/brand.cc.stderr"
brand_status=$?
"$CC_BIN" $CFLAGS_VAL -Isrc "$build_dir/renamed.final.c" -o "$build_dir/renamed-program" \
  2>"$build_dir/renamed.cc.stderr"
renamed_status=$?
set -e

if [ "$brand_status" != "0" ]; then
  echo "Baseline drift: the branded arm no longer compiles. It did when this was recorded."
  cat "$build_dir/brand.cc.stderr"
  exit 1
fi

if [ "$renamed_status" != "0" ]; then
  echo "Patch 19.3 regression: the renamed arm no longer compiles with its constructed type name."
  cat "$build_dir/renamed.cc.stderr"
  exit 1
fi

# The arena parameter spelling must not participate in the canonical C type
# identity. Keep explicit negative checks so a normalization step cannot hide a
# regression in the type name itself.
if rg -n -e 'Holder_(ctx|scratch)' \
    "$build_dir/brand.c" "$build_dir/renamed.c" >/dev/null; then
  echo "Rename regression: an arena parameter spelling escaped into Holder's C type identity."
  exit 1
fi
for arm in brand renamed; do
  rg -n -x -F 'typedef struct Holder Holder;' "$build_dir/$arm.c" >/dev/null
  rg -n -F 'sizeof(Holder)' "$build_dir/$arm.c" >/dev/null
done

sed 's/\bctx\b/BRAND/g' "$build_dir/brand.c" >"$build_dir/brand.normalized.c"
sed 's/\bscratch\b/BRAND/g' "$build_dir/renamed.c" >"$build_dir/renamed.normalized.c"
if ! cmp -s "$build_dir/brand.normalized.c" "$build_dir/renamed.normalized.c"; then
  echo "Rename regression: normalized generated C differs between the two arms."
  diff -u "$build_dir/brand.normalized.c" \
          "$build_dir/renamed.normalized.c" || true
  exit 1
fi

echo "✅ Phase 19 rename invariance verified: both arms compile, both use the"
echo "   canonical Holder type identity, and normalized generated C is byte-identical."
