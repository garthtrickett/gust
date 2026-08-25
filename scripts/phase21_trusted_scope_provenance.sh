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
./gust --backend mir-to-c "$positive" >"$build_root/positive.c" \
  2>"$build_root/positive.mir.compile.stderr"
test ! -s "$build_root/positive.mir.compile.stderr"
if rg -F 'trusted_scope_from_context' "$build_root/positive.c" >/dev/null; then
  echo "trusted compile-time intrinsic leaked into generated C" >&2
  exit 1
fi
cat src/runtime.c "$build_root/positive.c" >"$build_root/positive.final.c"
"${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
  "$build_root/positive.final.c" -o "$build_root/positive-mir"
GUST_NATIVE_BACKEND_DRIVER="$worker_abs" \
  ./gust --backend cranelift -o "$build_root/positive-native" "$positive" \
    >"$build_root/positive.native.compile.stdout" \
    2>"$build_root/positive.native.compile.stderr"
test ! -s "$build_root/positive.native.compile.stdout"
test ! -s "$build_root/positive.native.compile.stderr"
set +e
"$build_root/positive-mir" >"$build_root/positive.mir.stdout" \
  2>"$build_root/positive.mir.stderr"
mir_status="$?"
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
    set +e
    if [ "$backend" = cranelift ]; then
      GUST_NATIVE_BACKEND_DRIVER="$worker_abs" \
        ./gust --backend cranelift -o "$build_root/$kind-native" \
          "$source_fixture" >"$build_root/$kind.$backend.stdout" \
          2>"$build_root/$kind.$backend.stderr"
    else
      ./gust --backend mir-to-c "$source_fixture" \
        >"$build_root/$kind.$backend.stdout" \
        2>"$build_root/$kind.$backend.stderr"
    fi
    status="$?"
    set -e
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
  set +e
  ./gust --backend mir-to-c "$source_fixture" \
    >"$build_root/$kind.stdout" 2>"$build_root/$kind.stderr"
  status="$?"
  set -e
  test "$status" = 1
  test ! -s "$build_root/$kind.stderr"
  rg -F "Semantic Error: [$diagnostic_class]" \
    "$build_root/$kind.stdout" >/dev/null
done < <(python3 scripts/phase21_trusted_scope_provenance.py nonforgeability-cases)

echo "✅ Phase 21.4 trusted Scope provenance passed: positive parity, six query-site rejections, and non-forgeable compiler boundary"
