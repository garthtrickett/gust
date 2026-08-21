#!/usr/bin/env bash
# Phase 19 rename-invariance transition evidence.
#
# Two sources differ only in one arena-parameter spelling. Patch 19.1 recorded
# that the renamed arm emitted an undeclared canonical allocation target and
# failed in C. Patch 19.3 makes each arm internally consistent: both compile,
# while the custom `scratch` identity still remains in its C type name. Later
# classification/convergence patches own eliminating that remaining rename
# difference.
#
# The guard must change again when both normalized arms become equal. A silent
# pass after that later transition would hide the point where D-1 actually
# closes.
set -euo pipefail

brand_source="compiler/phase19_rename_invariance_brand_source.gst"
renamed_source="compiler/phase19_rename_invariance_renamed_source.gst"
build_dir="build/guards/cranelift_phase19_rename_invariance"

echo "🔒 Recording the Phase 19 rename-invariance baseline..."

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
normalise() {
  grep -v '^[[:space:]]*//' "$1" | sed "s/\\b$2\\b/BRAND/g"
}
if ! diff <(normalise "$brand_source" ctx) \
          <(normalise "$renamed_source" scratch) >/dev/null; then
  echo "The two rename-invariance arms differ by more than the arena spelling."
  diff -u <(normalise "$brand_source" ctx) \
          <(normalise "$renamed_source" scratch) || true
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

# Patch 19.3 removes the declaration/allocation disagreement but does not yet
# remove custom brand identities from canonical names.
if ! rg -n -F 'Holder_scratch' "$build_dir/renamed.c" >/dev/null; then
  echo "Transition drift: the renamed arm no longer records Holder_scratch."
  exit 1
fi
if ! rg -n -F '(Holder_scratch*)' "$build_dir/renamed.c" >/dev/null; then
  echo "Transition drift: the renamed allocation does not use Holder_scratch*."
  exit 1
fi
if ! rg -n -x -F 'typedef struct Holder_scratch Holder_scratch;' "$build_dir/renamed.c" >/dev/null; then
  echo "Transition drift: the renamed arm does not declare Holder_scratch."
  exit 1
fi
if diff -u "$build_dir/brand.c" "$build_dir/renamed.c" >/dev/null; then
  echo "Transition superseded: the two raw C outputs are now equal."
  echo "Update this guard to the final normalized rename-invariance assertion."
  exit 1
fi

echo "✅ Phase 19.3 rename transition verified: both arms compile with internally"
echo "   consistent type names; custom scratch branding remains visible for the"
echo "   later type-derived classification and convergence patches."
