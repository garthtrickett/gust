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

python3 scripts/phase24_frozen_oracle.py materialize \
  "$positive" "$build_root/mir-to-c" --kind exec
test ! -s "$build_root/mir-to-c.compile.stderr"
mir_status="$(cat "$build_root/mir-to-c.status")"
test "$mir_status" = 20

# Patch 24.12: grepping the emitted C for a leaked semantic diagnostic is an
# assertion about the retired emitter's output text with no native
# counterpart. What stays live is that the frozen oracle accepts the CR-11
# fixture cleanly.
python3 scripts/phase24_frozen_oracle.py materialize \
  "$issue" "$build_root/issue" --kind exec
test ! -s "$build_root/issue.compile.stderr"

set +e
python3 scripts/phase24_frozen_oracle.py materialize \
  "$negative" "$build_root/negative" --kind reject
negative_status="$(cat "$build_root/negative.status")"
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

echo "✅ Phase 20 nested brand annotation parity passed"
