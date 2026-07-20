#!/usr/bin/env bash
set -euo pipefail

novel_source="compiler/phase12_5_route_novel_source.gst"
variant_source="compiler/phase12_5_route_variant_source.gst"
unsupported_source="compiler/phase12_5_route_unsupported_source.gst"
registry_json="scripts/cranelift_feature_registry.json"
legacy_registry="compiler/CRANELIFT_FEATURE_PARITY_REGISTRY.md"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
build_root="build/guards/cranelift_route_architecture"
cargo_target="$build_root/cargo-target"

for required_file in \
  "$novel_source" "$variant_source" "$unsupported_source" \
  "$registry_json" "$legacy_registry" "$rust_manifest" \
  src/runtime.c ./gust
do
  if [ ! -e "$required_file" ]; then
    echo "Route architecture evidence is missing $required_file" >&2
    exit 1
  fi
done
if [ ! -x ./gust ]; then
  echo "Route architecture evidence requires the rebuilt ./gust compiler." >&2
  exit 1
fi

for unregistered_source in "$novel_source" "$variant_source"; do
  if rg -n -F "$unregistered_source" "$registry_json" "$legacy_registry" >/dev/null; then
    echo "Route architecture probe must remain outside historical fixture inventories: $unregistered_source" >&2
    exit 1
  fi
done

rm -rf "$build_root"
mkdir -p "$build_root"

CARGO_TARGET_DIR="$cargo_target" cargo build \
  --locked \
  --quiet \
  --manifest-path "$rust_manifest"
driver_bin="$cargo_target/debug/gust-cranelift-experiment"
if [ ! -x "$driver_bin" ]; then
  echo "Route architecture evidence did not build $driver_bin" >&2
  exit 1
fi
driver_abs="$(cd "$(dirname "$driver_bin")" && pwd)/$(basename "$driver_bin")"
CC_BIN="${CC:-cc}"
CFLAGS_VAL="${CFLAGS:--O0 -w -pthread}"

execute_and_capture() {
  local binary="$1"
  local prefix="$2"
  set +e
  "$binary" >"$prefix.stdout" 2>"$prefix.stderr"
  local status="$?"
  set -e
  printf '%s\n' "$status" >"$prefix.status"
}

compile_mir_to_c_oracle() {
  local source_path="$1"
  local case_dir="$2"

  if ! ./gust --backend mir-to-c "$source_path" \
      >"$case_dir/oracle.c" \
      2>"$case_dir/oracle.compiler.stderr"; then
    cat "$case_dir/oracle.compiler.stderr" >&2
    echo "MIR-to-C oracle compilation failed for $source_path" >&2
    exit 1
  fi
  if [ -s "$case_dir/oracle.compiler.stderr" ]; then
    cat "$case_dir/oracle.compiler.stderr" >&2
    echo "MIR-to-C oracle emitted diagnostics for $source_path" >&2
    exit 1
  fi

  cat src/runtime.c "$case_dir/oracle.c" >"$case_dir/oracle.final.c"
  "$CC_BIN" $CFLAGS_VAL -Isrc \
    "$case_dir/oracle.final.c" \
    -o "$case_dir/oracle-program"
  execute_and_capture "$case_dir/oracle-program" "$case_dir/oracle"
}

compare_native_to_oracle() {
  local case_dir="$1"
  local expected_status="$2"

  execute_and_capture "$case_dir/native-program" "$case_dir/native"

  if [ "$(cat "$case_dir/oracle.status")" != "$expected_status" ]; then
    echo "MIR-to-C oracle status drifted: expected=$expected_status actual=$(cat "$case_dir/oracle.status")" >&2
    exit 1
  fi
  if [ "$(cat "$case_dir/native.status")" != "$expected_status" ]; then
    echo "Cranelift route status drifted: expected=$expected_status actual=$(cat "$case_dir/native.status")" >&2
    exit 1
  fi
  if ! cmp -s "$case_dir/oracle.stdout" "$case_dir/native.stdout"; then
    diff -u "$case_dir/oracle.stdout" "$case_dir/native.stdout" >&2 || true
    echo "Route architecture runtime stdout differs from MIR-to-C." >&2
    exit 1
  fi
  if ! cmp -s "$case_dir/oracle.stderr" "$case_dir/native.stderr"; then
    diff -u "$case_dir/oracle.stderr" "$case_dir/native.stderr" >&2 || true
    echo "Route architecture runtime stderr differs from MIR-to-C." >&2
    exit 1
  fi
}

novel_dir="$build_root/novel-source"
mkdir -p "$novel_dir"
compile_mir_to_c_oracle "$novel_source" "$novel_dir"

set +e
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  ./gust --backend mir-to-c "$novel_source" \
    >"$novel_dir/poisoned-mir-to-c.stdout" \
    2>"$novel_dir/poisoned-mir-to-c.stderr"
poisoned_mir_to_c_status="$?"
set -e
if [ "$poisoned_mir_to_c_status" = "0" ]; then
  echo "MIR-to-C poison did not make the fallback route unavailable." >&2
  exit 1
fi
cat "$novel_dir/poisoned-mir-to-c.stdout" \
    "$novel_dir/poisoned-mir-to-c.stderr" \
    >"$novel_dir/poisoned-mir-to-c.combined"
if ! rg -n -F \
    'MIR-to-C intentionally unavailable for route architecture evidence.' \
    "$novel_dir/poisoned-mir-to-c.combined" >/dev/null; then
  cat "$novel_dir/poisoned-mir-to-c.combined" >&2
  echo "MIR-to-C poison failure did not report the expected test-only diagnostic." >&2
  exit 1
fi
if rg -n -F 'int main(' "$novel_dir/poisoned-mir-to-c.stdout" >/dev/null; then
  echo "Poisoned MIR-to-C unexpectedly emitted generated C." >&2
  exit 1
fi

driver_log="$novel_dir/driver-argv.log"
captured_request="$novel_dir/captured.request"
captured_bundle="$novel_dir/captured.bundle"
recording_driver="$novel_dir/recording-driver"
cat >"$recording_driver" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail

: "${GUST_ROUTE_REAL_DRIVER:?}"
: "${GUST_ROUTE_DRIVER_LOG:?}"
: "${GUST_ROUTE_CAPTURE_REQUEST:?}"
: "${GUST_ROUTE_CAPTURE_BUNDLE:?}"

{
  printf 'call\n'
  printf 'argc=%s\n' "$#"
  index=0
  for argument in "$@"; do
    printf 'arg%s=%s\n' "$index" "$argument"
    index=$((index + 1))
  done
} >>"$GUST_ROUTE_DRIVER_LOG"

if [ "${1:-}" = "phase10-backend-request-compile" ]; then
  if [ "$#" != "2" ]; then
    echo "recording driver expected command plus one request path" >&2
    exit 91
  fi
  cp "$2" "$GUST_ROUTE_CAPTURE_REQUEST"
  bundle_path="$(
    awk -F': ' \
      '$1 == "program_mir_bundle_path" { print substr($0, index($0, ": ") + 2) }' \
      "$2"
  )"
  if [ -z "$bundle_path" ] || [ ! -f "$bundle_path" ]; then
    echo "recording driver could not resolve the canonical MIR bundle" >&2
    exit 92
  fi
  cp "$bundle_path" "$GUST_ROUTE_CAPTURE_BUNDLE"
fi

exec "$GUST_ROUTE_REAL_DRIVER" "$@"
WRAPPER
chmod +x "$recording_driver"
recording_driver_abs="$(cd "$(dirname "$recording_driver")" && pwd)/$(basename "$recording_driver")"

if ! GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
    GUST_NATIVE_BACKEND_DRIVER="$recording_driver_abs" \
    GUST_ROUTE_REAL_DRIVER="$driver_abs" \
    GUST_ROUTE_DRIVER_LOG="$driver_log" \
    GUST_ROUTE_CAPTURE_REQUEST="$captured_request" \
    GUST_ROUTE_CAPTURE_BUNDLE="$captured_bundle" \
    ./gust --backend cranelift \
      -o "$novel_dir/native-program" \
      "$novel_source" \
      >"$novel_dir/native.compiler.stdout" \
      2>"$novel_dir/native.compiler.stderr"; then
  cat "$novel_dir/native.compiler.stdout" \
      "$novel_dir/native.compiler.stderr" >&2
  echo "Novel unregistered source did not compile through the generic native route." >&2
  exit 1
fi
if [ -s "$novel_dir/native.compiler.stdout" ] ||
   [ -s "$novel_dir/native.compiler.stderr" ]; then
  cat "$novel_dir/native.compiler.stdout" \
      "$novel_dir/native.compiler.stderr" >&2
  echo "Successful novel-source native compilation emitted diagnostics." >&2
  exit 1
fi
if [ ! -x "$novel_dir/native-program" ]; then
  echo "Novel-source native compilation did not publish an executable." >&2
  exit 1
fi
compare_native_to_oracle "$novel_dir" "49"

if [ "$(rg -c -x -F 'call' "$driver_log")" != "2" ] ||
   [ "$(rg -c -x -F 'argc=1' "$driver_log")" != "1" ] ||
   [ "$(rg -c -x -F 'argc=2' "$driver_log")" != "1" ]; then
  cat "$driver_log" >&2
  echo "Native worker invocation did not remain handshake plus command/request-path only." >&2
  exit 1
fi
rg -n -x -F 'arg0=phase10-driver-handshake' "$driver_log" >/dev/null
rg -n -x -F 'arg0=phase10-backend-request-compile' "$driver_log" >/dev/null
if rg -n -F "$novel_source" "$driver_log" >/dev/null; then
  cat "$driver_log" >&2
  echo "Native worker argv exposed the Gust source path." >&2
  exit 1
fi

for captured_field in \
  format driver_protocol artifact_kind target_triple object_format \
  output_path program_mir_bundle_path
do
  rg -n -e "^${captured_field}: " "$captured_request" >/dev/null
done
if rg -n -e '^(source_path|source_text|source_bytes|ast_program):' \
    "$captured_request" >/dev/null; then
  cat "$captured_request" >&2
  echo "Published native worker request exposed raw Gust source fields." >&2
  exit 1
fi
if rg -n -F "$novel_source" "$captured_request" >/dev/null; then
  cat "$captured_request" >&2
  echo "Published native worker request exposed the Gust source path." >&2
  exit 1
fi
test -s "$captured_bundle"
test ! -e "$novel_dir/native-program.phase10.request"
test ! -e "$novel_dir/native-program.phase10.bundle"

variant_dir="$build_root/renamed-variant"
mkdir -p "$variant_dir"
compile_mir_to_c_oracle "$variant_source" "$variant_dir"
if ! GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
    GUST_NATIVE_BACKEND_DRIVER="$driver_abs" \
    ./gust --backend cranelift \
      -o "$variant_dir/native-program" \
      "$variant_source" \
      >"$variant_dir/native.compiler.stdout" \
      2>"$variant_dir/native.compiler.stderr"; then
  cat "$variant_dir/native.compiler.stdout" \
      "$variant_dir/native.compiler.stderr" >&2
  echo "Renamed-function and altered-literal source variant did not compile natively." >&2
  exit 1
fi
if [ -s "$variant_dir/native.compiler.stdout" ] ||
   [ -s "$variant_dir/native.compiler.stderr" ]; then
  cat "$variant_dir/native.compiler.stdout" \
      "$variant_dir/native.compiler.stderr" >&2
  echo "Successful source-variant native compilation emitted diagnostics." >&2
  exit 1
fi
test -x "$variant_dir/native-program"
compare_native_to_oracle "$variant_dir" "46"

unsupported_dir="$build_root/early-deferral"
mkdir -p "$unsupported_dir"
poison_marker="$unsupported_dir/driver.invoked"
poison_driver="$unsupported_dir/poison-driver"
cat >"$poison_driver" <<POISON
#!/usr/bin/env bash
printf 'invoked\n' >"$poison_marker"
exit 97
POISON
chmod +x "$poison_driver"
poison_driver_abs="$(cd "$(dirname "$poison_driver")" && pwd)/$(basename "$poison_driver")"

protected_output="$unsupported_dir/unsupported-program"
printf 'phase12.5-route-output-sentinel\n' >"$protected_output"
cp "$protected_output" "$protected_output.expected"

set +e
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
GUST_NATIVE_BACKEND_DRIVER="$poison_driver_abs" \
  ./gust --backend cranelift \
    -o "$protected_output" \
    "$unsupported_source" \
    >"$unsupported_dir/compiler.stdout" \
    2>"$unsupported_dir/compiler.stderr"
unsupported_status="$?"
set -e
if [ "$unsupported_status" = "0" ]; then
  echo "Unsupported source unexpectedly compiled through the native route." >&2
  exit 1
fi
if [ -e "$poison_marker" ]; then
  cat "$poison_marker" >&2
  echo "Early deferral invoked the poisoned native driver." >&2
  exit 1
fi
if ! cmp -s "$protected_output.expected" "$protected_output"; then
  echo "Early deferral changed the existing output." >&2
  exit 1
fi
if [ -e "$protected_output.phase10.request" ] ||
   [ -e "$protected_output.phase10.bundle" ]; then
  echo "Early deferral published a request or canonical bundle." >&2
  exit 1
fi
if find "$unsupported_dir" -maxdepth 1 \
    \( -name '.unsupported-program.phase10-source-route*' \
       -o -name '.unsupported-program.phase9g-link*' \
       -o -name '..unsupported-program.phase10-source-route*' \) \
    -print -quit | grep -q .; then
  find "$unsupported_dir" -maxdepth 1 -name '.*unsupported-program*' -print >&2
  echo "Early deferral created an object, link temporary, or linker log." >&2
  exit 1
fi
cat "$unsupported_dir/compiler.stdout" \
    "$unsupported_dir/compiler.stderr" \
    >"$unsupported_dir/compiler.combined"
if rg -n -F "$poison_driver_abs" "$unsupported_dir/compiler.combined" >/dev/null ||
   rg -n -F 'Native backend driver discovery error:' \
     "$unsupported_dir/compiler.combined" >/dev/null; then
  cat "$unsupported_dir/compiler.combined" >&2
  echo "Early deferral reached native driver discovery." >&2
  exit 1
fi
rg -n -F \
  'Experimental Cranelift backend selection is valid, but the source-level route is not connected yet.' \
  "$unsupported_dir/compiler.combined" >/dev/null

echo "✅ Route architecture behavioural evidence passed: novel and renamed sources use generic canonical MIR, MIR-to-C fallback is poisoned, worker input is isolated, and unsupported input defers before driver/request/object/output access."
