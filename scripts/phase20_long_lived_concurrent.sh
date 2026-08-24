#!/usr/bin/env bash
set -euo pipefail

profile="${1:-small}"
case "$profile" in
  small) cycles=8; resource_runs=1 ;;
  full) cycles=128; resource_runs=4 ;;
  *) echo "unknown Patch 20.15 profile: $profile" >&2; exit 2 ;;
esac

python3 scripts/phase20_long_lived_concurrent.py validate
build_root="build/guards/phase20_long_lived_concurrent_$profile"
runtime_source="compiler/phase20_long_lived_concurrent_source.gst"
resource_source="compiler/phase20_long_lived_resource_source.gst"
probe="compiler/fixtures/phase20_long_lived_concurrent_probe.c"
canonical_mir="compiler/fixtures/native_backend_phase20_long_lived_concurrent.mir"
worker="build/gust-native-backend"
rm -rf "$build_root"
mkdir -p "$build_root"

./gust --backend mir-to-c "$runtime_source" \
  >"$build_root/runtime.c" 2>"$build_root/runtime.compiler.stderr"
test ! -s "$build_root/runtime.compiler.stderr"
cat src/runtime.c "$probe" "$build_root/runtime.c" \
  >"$build_root/runtime.final.c"
"${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
  "$build_root/runtime.final.c" -o "$build_root/mir-to-c-program"

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
  src/runtime.c "$probe" "$build_root/native.o" \
  -o "$build_root/native-program"

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

./gust --backend mir-to-c "$resource_source" \
  >"$build_root/resource.c" 2>"$build_root/resource.compiler.stderr"
test ! -s "$build_root/resource.compiler.stderr"
cat src/runtime.c "$build_root/resource.c" >"$build_root/resource.final.c"
"${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
  "$build_root/resource.final.c" -o "$build_root/resource-program"
: >"$build_root/resource.expected"
for token in $(seq 1 16); do
  printf '%s\n%s\n%s\n%s\n' \
    "$((token + 200))" "$((token + 100))" \
    "$((token + 300))" "$token" \
    >>"$build_root/resource.expected"
done
for run in $(seq 1 "$resource_runs"); do
  timeout 30s "$build_root/resource-program" \
    >"$build_root/resource.$run.stdout" \
    2>"$build_root/resource.$run.stderr"
  cmp -s "$build_root/resource.expected" \
    "$build_root/resource.$run.stdout"
  test ! -s "$build_root/resource.$run.stderr"
done

poison="$build_root/poison-driver"
poison_marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
set -euo pipefail
: >"$GUST_PHASE20_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"
for excluded_source in "$runtime_source" "$resource_source"; do
  rm -f "$poison_marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE20_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$poison" \
    ./gust --backend cranelift -o "$build_root/excluded-native" \
      "$excluded_source" >"$build_root/excluded.stdout" \
      2>"$build_root/excluded.stderr"
  excluded_status="$?"
  set -e
  test "$excluded_status" -ne 0
  test ! -e "$poison_marker"
  test ! -e "$build_root/excluded-native"
  rg -F 'expected_failure_stage=before_driver_discovery' \
    "$build_root/excluded.stdout" >/dev/null
done

echo "✅ Phase 20.15 profile=$profile cycles=$cycles resource-runs=$resource_runs passed"
