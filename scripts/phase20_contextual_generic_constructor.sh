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

./gust --backend mir-to-c "$inferred" >"$build_root/inferred.c" 2>"$build_root/inferred.stderr"
./gust --backend mir-to-c "$explicit" \
  >"$build_root/explicit.c" 2>"$build_root/explicit.stderr"
test ! -s "$build_root/inferred.stderr"
test ! -s "$build_root/explicit.stderr"
cmp -s "$build_root/inferred.c" "$build_root/explicit.c"

rg -F 'std_Channel_int make_contextual_channel(os_Arena* ctx)' \
  "$build_root/inferred.c" >/dev/null
rg -F 'std_Vector_int make_contextual_vector(os_Arena* ctx)' \
  "$build_root/inferred.c" >/dev/null
if rg -F '_Any' "$build_root/inferred.c" >/dev/null; then
  echo "contextual constructor output retained an _Any specialization" >&2
  exit 1
fi

cat src/runtime.c "$build_root/inferred.c" >"$build_root/mir-to-c.final.c"
"${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
  "$build_root/mir-to-c.final.c" -o "$build_root/mir-to-c-program"
set +e
"$build_root/mir-to-c-program" \
  >"$build_root/mir-to-c.stdout" 2>"$build_root/mir-to-c.stderr"
mir_status="$?"
set -e
test "$mir_status" = 31

for negative in "${negatives[@]}"; do
  name="$(basename "$negative" .gst)"
  set +e
  ./gust --backend mir-to-c "$negative" >"$build_root/$name.log" 2>&1
  status="$?"
  set -e
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
