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

python3 scripts/phase24_frozen_oracle.py materialize \
  "$positive" "$build_root/mir-to-c" --kind exec
test ! -s "$build_root/mir-to-c.compile.stderr"
set +e
mir_status="$(cat "$build_root/mir-to-c.status")"
set -e
test "$mir_status" = 37

for negative in "${negatives[@]}"; do
  name="$(basename "$negative" .gst)"
  set +e
  set -e
  python3 scripts/phase24_frozen_oracle.py materialize \
    "$negative" "$build_root/$name" --kind reject
  cp "$build_root/$name.compile.stdout" "$build_root/$name.stdout"
  cp "$build_root/$name.compile.stderr" "$build_root/$name.stderr"
  status="$(cat "$build_root/$name.status")"
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
