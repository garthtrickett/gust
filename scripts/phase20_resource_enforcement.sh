#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase20_resource_enforcement"
positive="compiler/phase20_resource_enforcement_source.gst"
negatives=(
  compiler/phase20_resource_external_construction_invalid.gst
  compiler/phase20_resource_empty_forge_invalid.gst
  compiler/phase20_resource_external_field_invalid.gst
  compiler/phase20_directory_external_construction_invalid.gst
  compiler/phase20_directory_external_field_invalid.gst
  compiler/phase20_resource_private_call_invalid.gst
  compiler/phase20_resource_private_reference_invalid.gst
  compiler/phase20_resource_destructor_missing_invalid.gst
  compiler/phase20_resource_destructor_borrowed_invalid.gst
  compiler/phase20_resource_destructor_wrong_type_invalid.gst
  compiler/phase20_resource_destructor_arity_invalid.gst
  compiler/phase20_resource_destructor_result_invalid.gst
  compiler/phase20_resource_destructor_unsafe_invalid.gst
  compiler/phase20_resource_destructor_extern_invalid.gst
  compiler/phase20_resource_destructor_owner_invalid.gst
)
expected=(
  OpaqueConstruction
  OpaqueConstruction
  OpaqueRepresentationAccess
  OpaqueConstruction
  OpaqueRepresentationAccess
  PrivateDeclarationAccess
  PrivateDeclarationAccess
  ResourceDestructorMissing
  ResourceDestructorSignature
  ResourceDestructorSignature
  ResourceDestructorSignature
  ResourceDestructorSignature
  ResourceDestructorStatus
  ResourceDestructorStatus
  ResourceDestructorModuleMismatch
)

python3 scripts/phase20_resource_enforcement.py validate
rm -rf "$build_root"
mkdir -p "$build_root"

./gust "$positive" >"$build_root/default.c" 2>"$build_root/default.stderr"
./gust --backend mir-to-c "$positive" \
  >"$build_root/explicit.c" 2>"$build_root/explicit.stderr"
test ! -s "$build_root/default.stderr"
test ! -s "$build_root/explicit.stderr"
cmp -s "$build_root/default.c" "$build_root/explicit.c"

cat src/runtime.c "$build_root/default.c" >"$build_root/final.c"
"${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
  "$build_root/final.c" -o "$build_root/program"
set +e
"$build_root/program" >"$build_root/stdout" 2>"$build_root/stderr"
positive_status="$?"
set -e
test "$positive_status" = 47
test ! -s "$build_root/stdout"
test ! -s "$build_root/stderr"

index=0
for negative in "${negatives[@]}"; do
  stem="$(basename "$negative" .gst)"
  set +e
  ./gust "$negative" >"$build_root/$stem.default.log" 2>&1
  default_status="$?"
  ./gust --backend mir-to-c "$negative" \
    >"$build_root/$stem.mir-to-c.log" 2>&1
  explicit_status="$?"
  ./gust --backend cranelift -o "$build_root/$stem.native" "$negative" \
    >"$build_root/$stem.cranelift.log" 2>&1
  native_status="$?"
  set -e
  test "$default_status" -ne 0
  test "$explicit_status" = "$default_status"
  test "$native_status" = "$default_status"
  cmp -s "$build_root/$stem.default.log" "$build_root/$stem.mir-to-c.log"
  cmp -s "$build_root/$stem.default.log" "$build_root/$stem.cranelift.log"
  test "$(rg -c 'Semantic Error:' "$build_root/$stem.default.log")" = 1
  test "$(rg -c "\[${expected[$index]}\]" "$build_root/$stem.default.log")" = 1
  test ! -e "$build_root/$stem.native"
  index=$((index + 1))
done

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
rg -F 'class=canonical_mir_verification_error' \
  "$build_root/direct.stdout" >/dev/null
test ! -e "$build_root/direct-native"

echo "✅ Phase 20 resource declaration enforcement parity passed"
