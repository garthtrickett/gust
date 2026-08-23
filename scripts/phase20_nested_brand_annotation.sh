#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase20_nested_brand_annotation"
positive="compiler/phase20_nested_brand_annotation_source.gst"
issue="compiler/future/p20_cr11_explicit_graph_annotation_current.gst"
negative="compiler/phase20_nested_brand_annotation_invalid.gst"
canonical_mir="compiler/fixtures/native_backend_phase20_nested_brand_annotation.mir"
worker="build/gust-native-backend"

python3 scripts/phase20_nested_brand_annotation.py validate
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
test "$mir_status" = 20

./gust "$issue" >"$build_root/issue.c" 2>"$build_root/issue.stderr"
test ! -s "$build_root/issue.stderr"
if rg -n 'Brand Nesting|Declared Void|TypeMismatch' "$build_root/issue.c" >/dev/null; then
  echo "CR-11 accepted fixture retained a semantic diagnostic" >&2
  exit 1
fi

set +e
./gust "$negative" >"$build_root/negative.log" 2>&1
negative_status="$?"
set -e
test "$negative_status" -ne 0
test "$(rg -c 'Semantic Error: Brand Nesting\.' "$build_root/negative.log")" = 1
rg -F "expected arena identity 'outer_arena' but found 'inner_arena'" \
  "$build_root/negative.log" >/dev/null
if rg -F 'Declared Void' "$build_root/negative.log" >/dev/null; then
  echo "illegal nesting produced a secondary Void mismatch" >&2
  exit 1
fi

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

echo "✅ Phase 20 nested brand annotation parity passed"
