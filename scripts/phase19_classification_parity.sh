#!/usr/bin/env bash
# Patch 19.4 focused parity: all container and arena decisions must come from
# resolved types and registry metadata, while the compatibility override is
# present but unable to change an answer.
set -euo pipefail

build_dir="build/guards/cranelift_phase19_classification"
unit_source="compiler/phase19_classification_test_entry.gst"
runtime_source="compiler/phase19_classification_source.gst"
self_source="compiler/test_runner_entry.gst"

if [ ! -x ./gust ]; then
  echo "Phase 19 classification parity requires the rebuilt ./gust compiler."
  exit 1
fi

rm -rf "$build_dir"
mkdir -p "$build_dir"

compile_gust() {
  local label="$1"
  local source_path="$2"
  if ! ./gust --backend mir-to-c "$source_path" >"$build_dir/$label.c" 2>"$build_dir/$label.compiler.stderr"; then
    echo "MIR-to-C rejected Phase 19 classification input $source_path."
    cat "$build_dir/$label.compiler.stderr"
    exit 1
  fi
  if [ -s "$build_dir/$label.compiler.stderr" ]; then
    echo "MIR-to-C emitted diagnostics for $source_path."
    cat "$build_dir/$label.compiler.stderr"
    exit 1
  fi
}

compile_and_run() {
  local label="$1"
  local source_path="$2"
  compile_gust "$label" "$source_path"
  cat src/runtime.c "$build_dir/$label.c" >"$build_dir/$label.final.c"
  "${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
    "$build_dir/$label.final.c" -o "$build_dir/$label-program"
  "$build_dir/$label-program" >"$build_dir/$label.runtime.stdout" 2>"$build_dir/$label.runtime.stderr"
  if [ -s "$build_dir/$label.runtime.stderr" ]; then
    echo "Runtime diagnostics were emitted for $source_path."
    cat "$build_dir/$label.runtime.stderr"
    exit 1
  fi
}

compile_and_run unit "$unit_source"
if ! rg -F 'SUCCESS: Phase 19 type-derived classification verified' \
  "$build_dir/unit.runtime.stdout" >/dev/null; then
  echo "The classification authority unit did not report success."
  cat "$build_dir/unit.runtime.stdout"
  exit 1
fi

compile_and_run runtime "$runtime_source"

# The self-hosted compiler is the exhaustive compatibility-override witness:
# every compiler module is lowered, and the assertion terminates generation if
# a legacy spelling would change the resolved-type answer.
compile_gust self "$self_source"
if [ ! -s "$build_dir/self.c" ]; then
  echo "Self-compilation classification witness is empty."
  exit 1
fi

echo "guard-cranelift-phase19-classification-parity: ok (resolved types, registry metadata, redundant override, Level 2)"
