#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase20_contextual_generic_constructor"
inferred="compiler/phase20_contextual_generic_constructor_inferred.gst"
explicit="compiler/phase20_contextual_generic_constructor_explicit.gst"
canonical_mir="compiler/fixtures/native_backend_phase20_contextual_generic_constructor.mir"
worker="build/gust-native-backend"
negatives=(
  compiler/phase20_contextual_generic_constructor_cross_template_invalid.gst
  compiler/phase20_contextual_generic_constructor_wrong_brand_invalid.gst
)

python3 scripts/phase20_contextual_generic_constructor.py validate
rm -rf "$build_root"
mkdir -p "$build_root"

# Patch 24.12: the inferred/explicit emit comparison and the three
# generated-C shape assertions (specialized constructor names present, no
# _Any specialization retained) are properties of the retired emitter's
# output text with no native counterpart, so they go with the backend rather
# than being frozen on both sides. Note the two sources are *different*
# fixtures, so each carries its own frozen vector.
python3 scripts/phase24_frozen_oracle.py materialize \
  "$inferred" "$build_root/mir-to-c" --kind exec
python3 scripts/phase24_frozen_oracle.py materialize \
  "$explicit" "$build_root/explicit-arm" --kind exec
test ! -s "$build_root/mir-to-c.compile.stderr"
test ! -s "$build_root/explicit-arm.compile.stderr"
mir_status="$(cat "$build_root/mir-to-c.status")"
test "$mir_status" = 31

for negative in "${negatives[@]}"; do
  name="$(basename "$negative" .gst)"
  set +e
  set -e
  python3 scripts/phase24_frozen_oracle.py materialize \
    "$negative" "$build_root/$name" --kind reject
  status="$(cat "$build_root/$name.status")"
  test "$status" -ne 0
  rg -F 'TypeMismatch' "$build_root/$name.log" >/dev/null
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

poison="$build_root/poison-driver"
poison_marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >"$GUST_PHASE20_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"
set +e
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
GUST_PHASE20_POISON_MARKER="$poison_marker" \
GUST_NATIVE_BACKEND_DRIVER="$poison" \
  ./gust --backend cranelift -o "$build_root/direct-native" "$inferred" \
  >"$build_root/direct.stdout" 2>"$build_root/direct.stderr"
direct_status="$?"
set -e
test "$direct_status" -ne 0
test ! -e "$poison_marker"
rg -F 'decision=deferred capability=phase13_generic_source_to_mir' \
  "$build_root/direct.stdout" >/dev/null
rg -F 'expected_failure_stage=before_driver_discovery' \
  "$build_root/direct.stdout" >/dev/null
rg -F 'class=unsupported_native_capability' "$build_root/direct.stdout" >/dev/null
test ! -e "$build_root/direct-native"

echo "✅ Phase 20 contextual generic constructor parity passed"
