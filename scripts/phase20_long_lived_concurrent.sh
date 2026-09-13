#!/usr/bin/env bash
set -euo pipefail

profile="${1:-small}"
gust_compiler="${GUST_COMPILER:-./gust}"
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

python3 scripts/phase24_frozen_oracle.py materialize \
  "$runtime_source" "$build_root/mir-to-c" --kind exec \
  --env "GUST_PHASE20_LONG_LIVED_CYCLES=$cycles"
test ! -s "$build_root/mir-to-c.compile.stderr"

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

mir_status="$(cat "$build_root/mir-to-c.status")"
set +e
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

python3 scripts/phase24_frozen_oracle.py materialize \
  "$resource_source" "$build_root/resource" --kind exec
test ! -s "$build_root/resource.compile.stderr"
: >"$build_root/resource.expected"
for token in $(seq 1 16); do
  printf '%s\n%s\n%s\n%s\n' \
    "$((token + 200))" "$((token + 100))" \
    "$((token + 300))" "$token" \
    >>"$build_root/resource.expected"
done
# The repeated-run evidence lives on the native side now: the frozen arm is
# one recorded run by construction, so re-serving it N times would prove
# nothing. Every live native run below is still compared against both the
# computed expectation and this frozen stdout.
test "$(cat "$build_root/resource.status")" = 0
cmp -s "$build_root/resource.expected" "$build_root/resource.stdout"
test ! -s "$build_root/resource.stderr"

poison="$build_root/poison-driver"
poison_marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
set -euo pipefail
: >"$GUST_PHASE20_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"
full_compiler_live="$(python3 -c '
import json
record = json.load(open("scripts/cranelift_feature_registry.json"))
print(1 if record.get("phase21_full_compiler_native_qualification", {}).get("status") == "patch21_14_complete" else 0)
')"
if test "$full_compiler_live" = 1; then
  excluded_sources=("$runtime_source")
else
  excluded_sources=("$runtime_source" "$resource_source")
fi
for excluded_source in "${excluded_sources[@]}"; do
  rm -f "$poison_marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE20_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    "$gust_compiler" --backend cranelift -o "$build_root/excluded-native" \
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

if test "$full_compiler_live" = 1; then
  make build/gust-runtime-package.a
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$worker" \
    "$gust_compiler" --backend cranelift -o "$build_root/resource-native" \
      "$resource_source" >"$build_root/resource-native.compile.stdout" \
      2>"$build_root/resource-native.compile.stderr"
  test ! -s "$build_root/resource-native.compile.stdout"
  test ! -s "$build_root/resource-native.compile.stderr"
  for run in $(seq 1 "$resource_runs"); do
    timeout 30s "$build_root/resource-native" \
      >"$build_root/resource-native.$run.stdout" \
      2>"$build_root/resource-native.$run.stderr"
    cmp -s "$build_root/resource.expected" \
      "$build_root/resource-native.$run.stdout"
    cmp -s "$build_root/resource.stdout" \
      "$build_root/resource-native.$run.stdout"
    test ! -s "$build_root/resource-native.$run.stderr"
  done
fi

echo "✅ Phase 20.15 profile=$profile cycles=$cycles resource-runs=$resource_runs passed"
