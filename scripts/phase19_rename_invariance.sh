#!/usr/bin/env bash
# Phase 19.1 rename-invariance baseline.
#
# Two sources that differ only in the spelling of one arena parameter. Under
# D-1 they would emit equivalent C. They do not, and this records exactly how
# they differ so Phase 19.2 onward has a before picture.
#
# This guard asserts the CURRENT, DEFECTIVE behaviour. That is deliberate: it
# is a baseline, not a contract. When brand identity stops depending on
# spelling, this guard FAILS, and the patch that fixes it is expected to
# replace the baseline with an equality assertion. A silently passing guard
# after the fix would be worse than a failing one.
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

# Both arms compile with Gust. Only the branded arm survives the C compiler.
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

if [ "$renamed_status" = "0" ]; then
  echo "Baseline superseded: the renamed arm now compiles."
  echo "Brand identity no longer depends on the arena parameter spelling for this shape."
  echo "That is the Phase 19 goal. Replace this baseline with an equality assertion."
  exit 1
fi

# Pin the mechanism, not just the failure: the struct keeps its unerased brand
# suffix while the allocation site still casts to the erased name.
if ! rg -n -F 'Holder_scratch' "$build_dir/renamed.c" >/dev/null; then
  echo "Baseline drift: the renamed arm no longer emits an unerased Holder_scratch."
  exit 1
fi
if ! rg -n -F '(Holder*)' "$build_dir/renamed.c" >/dev/null; then
  echo "Baseline drift: the renamed arm no longer casts to the erased Holder*."
  exit 1
fi
if rg -n -x -F 'typedef struct Holder Holder;' "$build_dir/renamed.c" >/dev/null; then
  echo "Baseline drift: the renamed arm now declares Holder, so the cast resolves."
  exit 1
fi

echo "✅ Phase 19 rename-invariance baseline recorded: renaming the arena parameter from a"
echo "   brand-list name to any other name emits a struct as Holder_scratch while still"
echo "   casting to the erased Holder, which no translation unit declares, so the C"
echo "   compiler rejects it. Arm A compiles; arm B does not. This is the before picture."
