#!/usr/bin/env bash
set -euo pipefail

python3 scripts/phase21_trusted_scope_provenance.py validate
mkdir -p build/guards
build_root="$(mktemp -d build/guards/phase21_trusted_scope_provenance.XXXXXX)"
worker="build/gust-native-backend"
if [ ! -x "$worker" ]; then
  make "$worker"
fi
worker_abs="$PWD/$worker"

positive="compiler/phase21_trusted_scope_positive.gst"
python3 scripts/phase24_frozen_oracle.py materialize \
  "$positive" "$build_root/positive.mir" --kind exec
test ! -s "$build_root/positive.mir.compile.stderr"
GUST_NATIVE_BACKEND_DRIVER="$worker_abs" \
  ./gust --backend cranelift -o "$build_root/positive-native" "$positive" \
    >"$build_root/positive.native.compile.stdout" \
    2>"$build_root/positive.native.compile.stderr"
test ! -s "$build_root/positive.native.compile.stdout"
test ! -s "$build_root/positive.native.compile.stderr"
mir_status="$(cat "$build_root/positive.mir.status")"
set +e
"$build_root/positive-native" >"$build_root/positive.native.stdout" \
  2>"$build_root/positive.native.stderr"
native_status="$?"
set -e
test "$mir_status" = 41
test "$native_status" = 41
cmp -s "$build_root/positive.mir.stdout" "$build_root/positive.native.stdout"
cmp -s "$build_root/positive.mir.stderr" "$build_root/positive.native.stderr"

while IFS=$'\t' read -r kind source_fixture
do
  for backend in mir-to-c cranelift
  do
    if [ "$backend" = cranelift ]; then
      set +e
      GUST_NATIVE_BACKEND_DRIVER="$worker_abs" \
        ./gust --backend cranelift -o "$build_root/$kind-native" \
          "$source_fixture" >"$build_root/$kind.$backend.stdout" \
          2>"$build_root/$kind.$backend.stderr"
      status="$?"
      set -e
    else
      python3 scripts/phase24_frozen_oracle.py materialize \
        "$source_fixture" "$build_root/$kind.frozen" --kind reject
      cp "$build_root/$kind.frozen.compile.stdout" \
        "$build_root/$kind.$backend.stdout"
      cp "$build_root/$kind.frozen.compile.stderr" \
        "$build_root/$kind.$backend.stderr"
      status="$(cat "$build_root/$kind.frozen.status")"
    fi
    test "$status" = 1
    test ! -s "$build_root/$kind.$backend.stderr"
    rg -F 'Semantic Error: [TenantScopeProvenance] error: query lacks trusted tenant-scope provenance' \
      "$build_root/$kind.$backend.stdout" >/dev/null
  done
  cmp -s "$build_root/$kind.mir-to-c.stdout" \
    "$build_root/$kind.cranelift.stdout"
done < <(python3 scripts/phase21_trusted_scope_provenance.py negative-cases)

while IFS=$'\t' read -r kind source_fixture diagnostic_class
do
  python3 scripts/phase24_frozen_oracle.py materialize \
    "$source_fixture" "$build_root/$kind.frozen" --kind reject
  cp "$build_root/$kind.frozen.compile.stdout" "$build_root/$kind.stdout"
  cp "$build_root/$kind.frozen.compile.stderr" "$build_root/$kind.stderr"
  status="$(cat "$build_root/$kind.frozen.status")"
  test "$status" = 1
  test ! -s "$build_root/$kind.stderr"
  rg -F "Semantic Error: [$diagnostic_class]" \
    "$build_root/$kind.stdout" >/dev/null
done < <(python3 scripts/phase21_trusted_scope_provenance.py nonforgeability-cases)

echo "✅ Phase 21.4 trusted Scope provenance passed: positive parity, six query-site rejections, and non-forgeable compiler boundary"
