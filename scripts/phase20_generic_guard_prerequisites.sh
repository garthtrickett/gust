#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase20_generic_guard_prerequisites"
positive="compiler/phase20_generic_guard_prerequisites_source.gst"
canonical_mir="compiler/fixtures/native_backend_phase20_generic_guard_prerequisites.mir"
worker="build/gust-native-backend"
negatives=(
  compiler/phase20_generic_resource_destructor_wrong_type_invalid.gst
  compiler/phase20_generic_resource_destructor_wrong_brand_invalid.gst
)

python3 scripts/phase20_generic_guard_prerequisites.py validate
rm -rf "$build_root"
mkdir -p "$build_root"

./gust --backend mir-to-c "$positive" \
  >"$build_root/mir-to-c.c" 2>"$build_root/mir-to-c.compiler.stderr"
test ! -s "$build_root/mir-to-c.compiler.stderr"
cat src/runtime.c "$build_root/mir-to-c.c" >"$build_root/mir-to-c.final.c"
"${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
  "$build_root/mir-to-c.final.c" -o "$build_root/mir-to-c-program"
set +e
"$build_root/mir-to-c-program" \
  >"$build_root/mir-to-c.stdout" 2>"$build_root/mir-to-c.stderr"
mir_status="$?"
set -e
test "$mir_status" = 37

for negative in "${negatives[@]}"; do
  name="$(basename "$negative" .gst)"
  set +e
  ./gust --backend mir-to-c "$negative" \
    >"$build_root/$name.stdout" 2>"$build_root/$name.stderr"
  status="$?"
  set -e
  test "$status" -ne 0
  rg -F '[ResourceDestructorSignature]' \
    "$build_root/$name.stdout" "$build_root/$name.stderr" >/dev/null
done

if [ ! -x "$worker" ]; then
  make build/gust-native-backend
fi
"$worker" compiler-mir-validate-fixture "$canonical_mir" \
  >"$build_root/native.validate.stdout" 2>"$build_root/native.validate.stderr"
"$worker" compiler-mir-ingestion-object "$canonical_mir" "$build_root/native.o" \
  >"$build_root/native.compile.stdout" 2>"$build_root/native.compile.stderr"
"${CC:-cc}" "$build_root/native.o" -o "$build_root/native-program"
set +e
"$build_root/native-program" \
  >"$build_root/native.stdout" 2>"$build_root/native.stderr"
native_status="$?"
set -e
test "$native_status" = "$mir_status"
cmp -s "$build_root/mir-to-c.stdout" "$build_root/native.stdout"
cmp -s "$build_root/mir-to-c.stderr" "$build_root/native.stderr"

echo "✅ Phase 20 generic guard prerequisite parity passed"
