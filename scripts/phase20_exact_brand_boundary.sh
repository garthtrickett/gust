#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase20_exact_brand_boundary"
positive="compiler/phase20_exact_brand_boundary_source.gst"
issue="compiler/future/p20_cr12_wrong_brand_clone_current.gst"
canonical_mir="compiler/fixtures/native_backend_phase20_exact_brand_boundary.mir"
worker="build/gust-native-backend"
negatives=(
  "$issue"
  compiler/phase20_exact_brand_assignment_invalid.gst
  compiler/phase20_exact_brand_call_invalid.gst
  compiler/phase20_exact_brand_return_invalid.gst
  compiler/phase20_exact_brand_field_invalid.gst
  compiler/phase20_exact_brand_alias_invalid.gst
)

python3 scripts/phase20_exact_brand_boundary.py validate
rm -rf "$build_root"
mkdir -p "$build_root"

./gust "$positive" >"$build_root/default.c" 2>"$build_root/default.compiler.stderr"
./gust --backend mir-to-c "$positive" \
  >"$build_root/explicit.c" 2>"$build_root/explicit.compiler.stderr"
test ! -s "$build_root/default.compiler.stderr"
test ! -s "$build_root/explicit.compiler.stderr"
cmp -s "$build_root/default.c" "$build_root/explicit.c"

cat src/runtime.c "$build_root/default.c" >"$build_root/mir-to-c.final.c"
"${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
  "$build_root/mir-to-c.final.c" -o "$build_root/mir-to-c-program"
set +e
"$build_root/mir-to-c-program" \
  >"$build_root/mir-to-c.stdout" 2>"$build_root/mir-to-c.stderr"
mir_status="$?"
set -e
test "$mir_status" = 23

for negative in "${negatives[@]}"; do
  name="$(basename "$negative" .gst)"
  set +e
  ./gust "$negative" >"$build_root/$name.log" 2>&1
  status="$?"
  set -e
  test "$status" -ne 0
  test "$(rg -c 'Semantic Error:' "$build_root/$name.log")" = 1
  rg -F 'TypeMismatch' "$build_root/$name.log" >/dev/null || \
    rg -F 'Argument type mismatch' "$build_root/$name.log" >/dev/null
  rg -F 'origin' "$build_root/$name.log" >/dev/null
  rg -F 'destination' "$build_root/$name.log" >/dev/null
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
full_compiler_live="$(python3 -c '
import json
record = json.load(open("scripts/cranelift_feature_registry.json"))
print(1 if record.get("phase21_full_compiler_native_qualification", {}).get("status") == "patch21_14_complete" else 0)
')"
if test "$full_compiler_live" = 1; then
  make build/gust-runtime-package.a
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$worker" \
    ./gust --backend cranelift -o "$build_root/direct-native" "$positive" \
      >"$build_root/direct.compile.stdout" \
      2>"$build_root/direct.compile.stderr"
  test ! -s "$build_root/direct.compile.stdout"
  test ! -s "$build_root/direct.compile.stderr"
  set +e
  "$build_root/direct-native" >"$build_root/direct.stdout" \
    2>"$build_root/direct.stderr"
  direct_status="$?"
  set -e
  test "$direct_status" = "$mir_status"
  cmp -s "$build_root/mir-to-c.stdout" "$build_root/direct.stdout"
  cmp -s "$build_root/mir-to-c.stderr" "$build_root/direct.stderr"
else
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE20_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$poison" \
    ./gust --backend cranelift -o "$build_root/direct-native" "$positive" \
    >"$build_root/direct.stdout" 2>"$build_root/direct.stderr"
  direct_status="$?"
  set -e
  test "$direct_status" -ne 0
  test ! -e "$poison_marker"
  rg -F 'decision=source_or_type_failure capability=phase13_generic_source_to_mir' \
    "$build_root/direct.stdout" >/dev/null
  rg -F 'expected_failure_stage=before_driver_discovery' \
    "$build_root/direct.stdout" >/dev/null
  rg -F 'class=canonical_mir_verification_error' "$build_root/direct.stdout" >/dev/null
  test ! -e "$build_root/direct-native"
fi

echo "✅ Phase 20 exact branded boundary parity passed"
