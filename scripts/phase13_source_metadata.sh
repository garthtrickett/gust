#!/usr/bin/env bash
set -euo pipefail

rust_manifest="compiler/experiments/cranelift/Cargo.toml"
valid_fixture="compiler/fixtures/phase13_source_metadata_valid_resource.mir"
build_root="build/guards/cranelift_phase13_source_metadata"
positive_cases=(
  'resource|compiler/phase13_source_resource_metadata_source.gst|31|resource|validated_preserved|preserved'
  'expression|compiler/phase13_scalar_nested_mixed_source.gst|21|provenance|validated_preserved|preserved'
  'cfg|compiler/phase13_nested_structured_cfg_source.gst|36|provenance|validated_preserved|preserved'
  'call|compiler/phase13_direct_call_graph_source.gst|14|provenance|validated_preserved|preserved'
  'import|compiler/phase13_runtime_multiple_calls_source.gst|42|native_boundary|validated_codegen_relevant|required'
)
malformed_cases=(
  'compiler/fixtures/phase13_source_metadata_missing_owner.mir|is missing owner'
  'compiler/fixtures/phase13_source_metadata_invalid_source_location.mir|has an invalid source location'
  'compiler/fixtures/phase13_source_metadata_incompatible_class.mir|has an incompatible class, classification, policy, or codegen claim'
  'compiler/fixtures/phase13_source_metadata_invalid_proof_state.mir|has an invalid proof state'
  'compiler/fixtures/phase13_source_metadata_incorrect_codegen_relevance.mir|has an incorrect codegen-relevance claim for provenance metadata'
  'compiler/fixtures/phase13_source_metadata_inconsistent_serialization.mir|has inconsistent Phase 13.10 serialization'
)

for required in \
  ./gust src/runtime.c "$rust_manifest" "$valid_fixture" \
  compiler/mir_native_backend_metadata_source.gst \
  compiler/mir_native_backend_generic_source.gst \
  compiler/experiments/cranelift/src/main.rs
 do
  test -e "$required"
done
for record in "${positive_cases[@]}"; do
  IFS='|' read -r _ source _ _ _ _ <<<"$record"
  test -f "$source"
done
for record in "${malformed_cases[@]}"; do
  IFS='|' read -r fixture _ <<<"$record"
  test -f "$fixture"
done

test -x ./gust
rm -rf "$build_root"
mkdir -p "$build_root"
cargo_target="$build_root/cargo-target"
CARGO_TARGET_DIR="$cargo_target" cargo build \
  --locked --quiet --manifest-path "$rust_manifest"
driver="$cargo_target/debug/gust-cranelift-experiment"
test -x "$driver"
driver_abs="$(cd "$(dirname "$driver")" && pwd)/$(basename "$driver")"
CC_BIN="${CC:-cc}"
CFLAGS_VAL="${CFLAGS:--O0 -w -pthread}"

capture_driver="$build_root/capture-driver"
cat >"$capture_driver" <<'EOF_CAPTURE'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  phase10-driver-handshake)
    exec "$REAL_DRIVER" "$@"
    ;;
  phase10-backend-request-compile)
    request_path="${2:?missing request path}"
    cp "$request_path" "$CAPTURE_PREFIX.request"
    bundle_path="$(sed -n 's/^program_mir_bundle_path: //p' "$request_path")"
    test -n "$bundle_path"
    cp "$bundle_path" "$CAPTURE_PREFIX.bundle"
    exec "$REAL_DRIVER" "$@"
    ;;
  *)
    exec "$REAL_DRIVER" "$@"
    ;;
esac
EOF_CAPTURE
chmod +x "$capture_driver"
capture_driver_abs="$(cd "$(dirname "$capture_driver")" && pwd)/$(basename "$capture_driver")"

execute_and_capture() {
  local executable="$1"
  local prefix="$2"
  set +e
  "$executable" >"$prefix.stdout" 2>"$prefix.stderr"
  local status="$?"
  set -e
  printf '%s\n' "$status" >"$prefix.status"
}

run_positive_case() {
  local name="$1"
  local source="$2"
  local expected="$3"
  local metadata_class="$4"
  local classification="$5"
  local codegen="$6"
  local case_dir="$build_root/$name"
  mkdir -p "$case_dir"

  ./gust "$source" >"$case_dir/default.c" 2>"$case_dir/default.stderr"
  ./gust --backend mir-to-c "$source" >"$case_dir/explicit.c" 2>"$case_dir/explicit.stderr"
  test ! -s "$case_dir/default.stderr"
  test ! -s "$case_dir/explicit.stderr"
  cmp -s "$case_dir/default.c" "$case_dir/explicit.c"

  cat src/runtime.c "$case_dir/default.c" >"$case_dir/mir-to-c.final.c"
  "$CC_BIN" $CFLAGS_VAL -Isrc "$case_dir/mir-to-c.final.c" -o "$case_dir/mir-to-c"
  execute_and_capture "$case_dir/mir-to-c" "$case_dir/mir"

  REAL_DRIVER="$driver_abs" \
  CAPTURE_PREFIX="$case_dir/capture" \
  GUST_NATIVE_BACKEND_DRIVER="$capture_driver_abs" \
    ./gust --backend cranelift -o "$case_dir/native" "$source" \
      >"$case_dir/native.compiler.stdout" \
      2>"$case_dir/native.compiler.stderr"
  test ! -s "$case_dir/native.compiler.stdout"
  test ! -s "$case_dir/native.compiler.stderr"
  test -x "$case_dir/native"
  execute_and_capture "$case_dir/native" "$case_dir/cranelift"

  printf '%s\n' "$expected" >"$case_dir/expected.status"
  cmp -s "$case_dir/expected.status" "$case_dir/mir.status"
  cmp -s "$case_dir/expected.status" "$case_dir/cranelift.status"
  cmp -s "$case_dir/mir.stdout" "$case_dir/cranelift.stdout"
  cmp -s "$case_dir/mir.stderr" "$case_dir/cranelift.stderr"

  test -s "$case_dir/capture.bundle"
  rg -n -F '_contract: phase13_10' "$case_dir/capture.bundle" >/dev/null
  rg -n -F "_kind: $metadata_class" "$case_dir/capture.bundle" >/dev/null
  rg -n -F "_classification: $classification" "$case_dir/capture.bundle" >/dev/null
  rg -n -F "_codegen_semantics: $codegen" "$case_dir/capture.bundle" >/dev/null
  rg -n -F '_source_origin: ' "$case_dir/capture.bundle" >/dev/null
  rg -n -F '_source_line: ' "$case_dir/capture.bundle" >/dev/null
  rg -n -F '_source_column: ' "$case_dir/capture.bundle" >/dev/null
  rg -n -F '_owner: ' "$case_dir/capture.bundle" >/dev/null
  rg -n -F '_proof: ' "$case_dir/capture.bundle" >/dev/null

  test ! -e "$case_dir/native.phase10.bundle"
  test ! -e "$case_dir/native.phase10.request"
}

for record in "${positive_cases[@]}"; do
  IFS='|' read -r name source expected metadata_class classification codegen <<<"$record"
  run_positive_case "$name" "$source" "$expected" "$metadata_class" "$classification" "$codegen"
done

"$driver_abs" compiler-mir-validate-fixture "$valid_fixture" \
  >"$build_root/valid.stdout" 2>"$build_root/valid.stderr"
test ! -s "$build_root/valid.stderr"
rg -n -F 'metadata_summary: 0:resource:function:validated_preserved:preserved:' \
  "$build_root/valid.stdout" >/dev/null

for record in "${malformed_cases[@]}"; do
  IFS='|' read -r fixture expected_diagnostic <<<"$record"
  name="$(basename "$fixture" .mir)"
  output="$build_root/$name.existing.o"
  printf 'phase13-source-metadata-output-sentinel\n' >"$output"
  cp "$output" "$output.expected"
  set +e
  "$driver_abs" compiler-mir-ingestion-object "$fixture" "$output" \
    >"$build_root/$name.stdout" 2>"$build_root/$name.stderr"
  status="$?"
  set -e
  if [ "$status" = 0 ]; then
    echo "Malformed Phase 13.10 metadata unexpectedly lowered: $fixture" >&2
    exit 1
  fi
  rg -n -F "$expected_diagnostic" "$build_root/$name.stderr" >/dev/null
  cmp -s "$output.expected" "$output"
  if find "$build_root" -maxdepth 1 -type f -name "$name*.tmp.o" -print -quit | grep -q .; then
    echo "Malformed metadata published a temporary object: $fixture" >&2
    exit 1
  fi
done

echo "✅ Phase 13.10 source-produced metadata parity passed: generic source records survive transport, strict validation rejects malformed envelopes before publication, and observable behavior remains differential."