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
  python3 scripts/phase24_frozen_oracle.py materialize \
    "$source_fixture" "$build_root/$kind.mir" --kind exec
  test ! -s "$build_root/$kind.mir.compile.stderr"
  mir_status="$(cat "$build_root/$kind.mir.status")"
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
