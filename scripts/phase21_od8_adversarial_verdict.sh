#!/usr/bin/env bash
set -euo pipefail

python3 scripts/phase21_od8_adversarial_verdict.py validate
mkdir -p build/guards
build_root="$(mktemp -d build/guards/phase21_od8_adversarial_verdict.XXXXXX)"
worker="build/gust-native-backend"
if [ ! -x "$worker" ]; then
  make "$worker"
fi
worker_abs="$PWD/$worker"

while IFS=$'\t' read -r attack_id kind source_fixture mir_exit native_exit
do
  ./gust --backend mir-to-c "$source_fixture" \
    >"$build_root/$attack_id.$kind.c" \
    2>"$build_root/$attack_id.$kind.mir.compile.stderr"
  test ! -s "$build_root/$attack_id.$kind.mir.compile.stderr"
  if rg -F 'trusted_scope_from_context' \
       "$build_root/$attack_id.$kind.c" >/dev/null || \
     rg -F 'cross_tenant_capability_from_host' \
       "$build_root/$attack_id.$kind.c" >/dev/null
  then
    echo "compile-time OD-8 authority leaked into generated C: $attack_id/$kind" >&2
    exit 1
  fi
  cat src/runtime.c "$build_root/$attack_id.$kind.c" \
    >"$build_root/$attack_id.$kind.final.c"
  "${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
    "$build_root/$attack_id.$kind.final.c" \
    -o "$build_root/$attack_id.$kind-mir"
  set +e
  "$build_root/$attack_id.$kind-mir" \
    >"$build_root/$attack_id.$kind.mir.stdout" \
    2>"$build_root/$attack_id.$kind.mir.stderr"
  mir_status="$?"
  set -e
  test "$mir_status" = "$mir_exit"
  test ! -s "$build_root/$attack_id.$kind.mir.stdout"
  test ! -s "$build_root/$attack_id.$kind.mir.stderr"

  if [ "$native_exit" != "-" ]; then
    GUST_NATIVE_BACKEND_DRIVER="$worker_abs" \
      ./gust --backend cranelift \
        -o "$build_root/$attack_id.$kind-native" "$source_fixture" \
        >"$build_root/$attack_id.$kind.native.compile.stdout" \
        2>"$build_root/$attack_id.$kind.native.compile.stderr"
    test ! -s "$build_root/$attack_id.$kind.native.compile.stdout"
    test ! -s "$build_root/$attack_id.$kind.native.compile.stderr"
    set +e
    "$build_root/$attack_id.$kind-native" \
      >"$build_root/$attack_id.$kind.native.stdout" \
      2>"$build_root/$attack_id.$kind.native.stderr"
    native_status="$?"
    set -e
    test "$native_status" = "$native_exit"
    cmp -s "$build_root/$attack_id.$kind.mir.stdout" \
      "$build_root/$attack_id.$kind.native.stdout"
    cmp -s "$build_root/$attack_id.$kind.mir.stderr" \
      "$build_root/$attack_id.$kind.native.stderr"
  fi
done < <(python3 scripts/phase21_od8_adversarial_verdict.py positive-cases)

while IFS=$'\t' read -r attack_id kind source_fixture diagnostic
do
  for backend in mir-to-c cranelift
  do
    artifact="$build_root/$attack_id.$kind.$backend-program"
    set +e
    if [ "$backend" = cranelift ]; then
      GUST_NATIVE_BACKEND_DRIVER="$worker_abs" \
        ./gust --backend cranelift -o "$artifact" "$source_fixture" \
          >"$build_root/$attack_id.$kind.$backend.stdout" \
          2>"$build_root/$attack_id.$kind.$backend.stderr"
    else
      ./gust --backend mir-to-c "$source_fixture" \
        >"$build_root/$attack_id.$kind.$backend.stdout" \
        2>"$build_root/$attack_id.$kind.$backend.stderr"
    fi
    status="$?"
    set -e
    test "$status" = 1
    test ! -s "$build_root/$attack_id.$kind.$backend.stderr"
    rg -F "$diagnostic" \
      "$build_root/$attack_id.$kind.$backend.stdout" >/dev/null
    test ! -e "$artifact"
  done
  cmp -s "$build_root/$attack_id.$kind.mir-to-c.stdout" \
    "$build_root/$attack_id.$kind.cranelift.stdout"
done < <(python3 scripts/phase21_od8_adversarial_verdict.py negative-cases)

echo "✅ Phase 21.7 OD-8 attack suite passed: 27 in-scope attempts, 0 counterexamples, bounded typed-query verdict"
