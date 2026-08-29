#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase20_arena_free"
positive="compiler/phase20_arena_free_live_source.gst"
issue="compiler/future/p20_cr13_free_receiver_reuse_current.gst"
canonical_mir="compiler/fixtures/native_backend_phase20_arena_free.mir"
worker="build/gust-native-backend"
negatives=(
  "$issue"
  compiler/phase20_arena_free_allocation_invalid.gst
  compiler/phase20_arena_free_write_invalid.gst
  compiler/phase20_arena_free_repeat_invalid.gst
  compiler/phase20_arena_free_deferred_repeat_invalid.gst
  compiler/phase20_arena_free_alias_invalid.gst
  compiler/phase20_arena_free_field_invalid.gst
  compiler/phase20_arena_free_parameter_invalid.gst
)
expected_operations=(
  "Clone destination use"
  "allocation"
  "write"
  "repeated Free"
  "repeated Free"
  "Clone destination use"
  "Clone destination use"
  "Clone destination use"
)

python3 scripts/phase20_arena_free.py validate
rm -rf "$build_root"
mkdir -p "$build_root"

./gust --backend mir-to-c "$positive" >"$build_root/default.c" 2>"$build_root/default.compiler.stderr"
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
test "$mir_status" = 37
test ! -s "$build_root/mir-to-c.stdout"
test ! -s "$build_root/mir-to-c.stderr"

i=0
for negative in "${negatives[@]}"; do
  name="$(basename "$negative" .gst)"
  set +e
  ./gust --backend mir-to-c "$negative" >"$build_root/$name.default.log" 2>&1
  default_status="$?"
  ./gust --backend mir-to-c "$negative" >"$build_root/$name.mir-to-c.log" 2>&1
  explicit_status="$?"
  ./gust --backend cranelift -o "$build_root/$name.native" "$negative" \
    >"$build_root/$name.cranelift.log" 2>&1
  native_status="$?"
  set -e
  test "$default_status" -ne 0
  test "$explicit_status" = "$default_status"
  test "$native_status" = "$default_status"
  cmp -s "$build_root/$name.default.log" "$build_root/$name.mir-to-c.log"
  cmp -s "$build_root/$name.default.log" "$build_root/$name.cranelift.log"
  test "$(rg -c '\[ArenaUseAfterFree\]' "$build_root/$name.default.log")" = 1
  test "$(rg -c 'Semantic Error:' "$build_root/$name.default.log")" = 1
  rg -F "${expected_operations[$i]}" "$build_root/$name.default.log" >/dev/null
  test ! -e "$build_root/$name.native"
  i=$((i + 1))
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

echo "✅ Phase 20 Arena.Free invalidation parity passed"
