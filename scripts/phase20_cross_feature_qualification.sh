#!/usr/bin/env bash
set -euo pipefail

profile="${1:-small}"
case "$profile" in
  small) cycles=8 ;;
  full) cycles=128 ;;
  *) echo "unknown Patch 20.16 profile: $profile" >&2; exit 2 ;;
esac

python3 scripts/phase20_cross_feature_qualification.py validate
build_root="build/guards/phase20_cross_feature_qualification_$profile"
source_fixture="compiler/phase20_cross_feature_qualification_source.gst"
probe="compiler/fixtures/phase20_cross_feature_probe.c"
concurrent_probe="compiler/fixtures/phase20_long_lived_concurrent_probe.c"
canonical_mir="compiler/fixtures/native_backend_phase20_cross_feature_qualification.mir"
worker="build/gust-native-backend"
rm -rf "$build_root"
mkdir -p "$build_root"

./gust --backend mir-to-c "$source_fixture" \
  >"$build_root/source.c" 2>"$build_root/source.compiler.stderr"
test ! -s "$build_root/source.compiler.stderr"
rg -F 'tiny_host_add_i32(value, 12)' "$build_root/source.c" >/dev/null
rg -F 'destroy_cross_feature_resource(inner)' "$build_root/source.c" >/dev/null
rg -F 'destroy_cross_feature_resource(outer)' "$build_root/source.c" >/dev/null
rg -F 'os_Arena_Free(&(destination))' "$build_root/source.c" >/dev/null
rg -F 'os_Arena_Free(&(origin))' "$build_root/source.c" >/dev/null
cat src/runtime.c "$concurrent_probe" "$probe" \
  "$build_root/source.c" >"$build_root/source.final.c"
"${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
  "$build_root/source.final.c" -o "$build_root/mir-to-c-program"

if [ ! -x "$worker" ]; then
  make "$worker"
fi
"$worker" compiler-mir-validate-fixture "$canonical_mir" \
  >"$build_root/native.validate.stdout" \
  2>"$build_root/native.validate.stderr"
"$worker" compiler-mir-ingestion-object "$canonical_mir" \
  "$build_root/native.o" >"$build_root/native.compile.stdout" \
  2>"$build_root/native.compile.stderr"
"${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
  src/runtime.c "$concurrent_probe" "$probe" \
  "$build_root/native.o" -o "$build_root/native-program"

set +e
GUST_PHASE20_LONG_LIVED_CYCLES="$cycles" timeout 30s \
  "$build_root/mir-to-c-program" >"$build_root/mir-to-c.stdout" \
  2>"$build_root/mir-to-c.stderr"
mir_status="$?"
GUST_PHASE20_LONG_LIVED_CYCLES="$cycles" timeout 30s \
  "$build_root/native-program" >"$build_root/native.stdout" \
  2>"$build_root/native.stderr"
native_status="$?"
set -e
test "$mir_status" = 47
test "$native_status" = "$mir_status"
cmp -s "$build_root/mir-to-c.stdout" "$build_root/native.stdout"
cmp -s "$build_root/mir-to-c.stderr" "$build_root/native.stderr"
test ! -s "$build_root/mir-to-c.stdout"
test ! -s "$build_root/mir-to-c.stderr"

poison="$build_root/poison-driver"
poison_marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
set -euo pipefail
: >"$GUST_PHASE20_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"
poison_abs="$(cd "$(dirname "$poison")" && pwd)/$(basename "$poison")"

while IFS=$'\t' read -r category residue_source decision reason_code \
  diagnostic failure_stage owner destination
do
  case_root="$build_root/residue-$category"
  mkdir -p "$case_root"
  ./gust --backend mir-to-c "$residue_source" \
    >"$case_root/mir-to-c.c" 2>"$case_root/mir-to-c.stderr"
  test ! -s "$case_root/mir-to-c.stderr"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE20_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$poison_abs" \
    ./gust --backend cranelift -o "$case_root/native" \
      "$residue_source" >"$case_root/native.stdout" \
      2>"$case_root/native.stderr"
  residue_status="$?"
  set -e
  test "$residue_status" -ne 0
  test ! -e "$poison_marker"
  test ! -e "$case_root/native"
  rg -F "decision=$decision" "$case_root/native.stdout" >/dev/null
  rg -F "reason_code=$reason_code" "$case_root/native.stdout" >/dev/null
  rg -F "expected_failure_stage=$failure_stage" \
    "$case_root/native.stdout" >/dev/null
  case "$diagnostic" in
    stdout:*) rg -F "${diagnostic#stdout:}" "$case_root/native.stdout" >/dev/null ;;
    stderr:*) rg -F "${diagnostic#stderr:}" "$case_root/native.stderr" >/dev/null ;;
    *) echo "unknown Patch 20.16 diagnostic owner: $diagnostic" >&2; exit 1 ;;
  esac
  test "$owner" = phase13_generic_source_to_mir
  test "$destination" = phase21_opening
done < <(python3 scripts/phase20_cross_feature_qualification.py residue-cases)

set +e
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
GUST_PHASE20_POISON_MARKER="$poison_marker" \
GUST_NATIVE_BACKEND_DRIVER="$poison_abs" \
  ./gust --backend cranelift -o "$build_root/excluded-native" \
    "$source_fixture" >"$build_root/excluded.stdout" \
    2>"$build_root/excluded.stderr"
excluded_status="$?"
set -e
test "$excluded_status" -ne 0
test ! -e "$poison_marker"
test ! -e "$build_root/excluded-native"
rg -F 'decision=source_or_type_failure' "$build_root/excluded.stdout" >/dev/null
rg -F 'reason_code=source_or_type_failure' "$build_root/excluded.stdout" >/dev/null
rg -F 'expected_failure_stage=before_driver_discovery' \
  "$build_root/excluded.stdout" >/dev/null
active_module_import_diagnostic="$(
  python3 scripts/phase21_opening.py active-module-import-diagnostic
)"
rg -F "$active_module_import_diagnostic" \
  "$build_root/excluded.stderr" >/dev/null

echo "✅ Phase 20.16 profile=$profile cycles=$cycles cross-feature qualification passed"
