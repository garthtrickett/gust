#!/usr/bin/env bash
# Patch 19.3 focused parity: inferred and explicit branded types must construct
# the same canonical C name, including a namespaced arena identity.
set -euo pipefail

explicit_source="compiler/phase19_type_naming_explicit_source.gst"
inferred_source="compiler/phase19_type_naming_inferred_source.gst"
build_dir="build/guards/cranelift_phase19_type_naming"

if [ ! -x ./gust ]; then
  echo "Phase 19 type-naming parity requires the rebuilt ./gust compiler."
  exit 1
fi

normalise() {
  grep -v '^[[:space:]]*//' "$1" |
    sed 's/: NamingHolder\[lib_module__ctx\] :=/ :=/'
}

if ! diff <(normalise "$explicit_source") <(normalise "$inferred_source") >/dev/null; then
  echo "The inferred and explicit arms differ by more than the type annotation."
  diff -u <(normalise "$explicit_source") <(normalise "$inferred_source") || true
  exit 1
fi

rm -rf "$build_dir"
mkdir -p "$build_dir"

for arm in explicit inferred; do
  source_path="$explicit_source"
  if [ "$arm" = "inferred" ]; then
    source_path="$inferred_source"
  fi
  if ! ./gust "$source_path" >"$build_dir/$arm.c" 2>"$build_dir/$arm.compiler.stderr"; then
    echo "MIR-to-C rejected the $arm type-naming arm."
    cat "$build_dir/$arm.compiler.stderr"
    exit 1
  fi
  if [ -s "$build_dir/$arm.compiler.stderr" ]; then
    echo "MIR-to-C emitted diagnostics for the $arm type-naming arm."
    cat "$build_dir/$arm.compiler.stderr"
    exit 1
  fi
done

if ! diff -u "$build_dir/explicit.c" "$build_dir/inferred.c"; then
  echo "Inferred and explicit branded types emitted different C."
  exit 1
fi

if ! rg -x -F 'typedef struct NamingHolder NamingHolder;' "$build_dir/explicit.c" >/dev/null; then
  echo "The namespaced brand did not construct canonical type name NamingHolder."
  exit 1
fi
if rg -F 'NamingHolder_lib' "$build_dir/explicit.c" >/dev/null; then
  echo "Legacy partial namespaced-brand suffix surgery is still visible."
  exit 1
fi

cat src/runtime.c "$build_dir/explicit.c" >"$build_dir/explicit.final.c"
"${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
  "$build_dir/explicit.final.c" -o "$build_dir/explicit-program"
"$build_dir/explicit-program"

echo "guard-cranelift-phase19-type-naming-parity: ok (canonical inferred/explicit names, Level 2)"
