#!/usr/bin/env bash
set -euo pipefail

python3 scripts/phase21_per_root_obligations.py validate
mkdir -p build/guards
build_root="$(mktemp -d build/guards/phase21_per_root_obligations.XXXXXX)"
worker="build/gust-native-backend"
if [ ! -x "$worker" ]; then
  make "$worker"
fi
worker_abs="$PWD/$worker"

while IFS=$'\t' read -r kind source_fixture mir_exit native_exit
do
  ./gust --backend mir-to-c "$source_fixture" >"$build_root/$kind.c" \
    2>"$build_root/$kind.mir.compile.stderr"
  test ! -s "$build_root/$kind.mir.compile.stderr"
  if rg -F 'trusted_scope_from_context' "$build_root/$kind.c" >/dev/null; then
    echo "trusted compile-time intrinsic leaked into generated C for $kind" >&2
    exit 1
  fi
  cat src/runtime.c "$build_root/$kind.c" >"$build_root/$kind.final.c"
  "${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
    "$build_root/$kind.final.c" -o "$build_root/$kind-mir"
  set +e
  "$build_root/$kind-mir" >"$build_root/$kind.mir.stdout" \
    2>"$build_root/$kind.mir.stderr"
  mir_status="$?"
  set -e
  test "$mir_status" = "$mir_exit"

  if [ "$native_exit" != "-" ]; then
    GUST_NATIVE_BACKEND_DRIVER="$worker_abs" \
      ./gust --backend cranelift -o "$build_root/$kind-native" \
        "$source_fixture" >"$build_root/$kind.native.compile.stdout" \
        2>"$build_root/$kind.native.compile.stderr"
    test ! -s "$build_root/$kind.native.compile.stdout"
    test ! -s "$build_root/$kind.native.compile.stderr"
    set +e
    "$build_root/$kind-native" >"$build_root/$kind.native.stdout" \
      2>"$build_root/$kind.native.stderr"
    native_status="$?"
    set -e
    test "$native_status" = "$native_exit"
    cmp -s "$build_root/$kind.mir.stdout" "$build_root/$kind.native.stdout"
    cmp -s "$build_root/$kind.mir.stderr" "$build_root/$kind.native.stderr"
  fi
done < <(python3 scripts/phase21_per_root_obligations.py positive-cases)

while IFS=$'\t' read -r kind source_fixture root_kind binding
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
    rg -F "($root_kind binding '$binding')" \
      "$build_root/$kind.$backend.stdout" >/dev/null
    if [ "$backend" = cranelift ]; then
      test ! -e "$build_root/$kind-native"
    fi
  done
  cmp -s "$build_root/$kind.mir-to-c.stdout" \
    "$build_root/$kind.cranelift.stdout"
done < <(python3 scripts/phase21_per_root_obligations.py negative-cases)

echo "✅ Phase 21.5 per-root obligations passed: independent joins, nested boundaries, and conservative query-value flow"
