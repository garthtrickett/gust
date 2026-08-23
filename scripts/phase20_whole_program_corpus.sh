#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase20_whole_program_corpus"
worker="build/gust-native-backend"

python3 scripts/phase20_whole_program_corpus.py validate
rm -rf "$build_root"
mkdir -p "$build_root"

if [ ! -x "$worker" ]; then
  make build/gust-native-backend
fi
worker_abs="$(cd "$(dirname "$worker")" && pwd)/$(basename "$worker")"
cc_bin="${CC:-cc}"
cflags="${CFLAGS:--O0 -w -pthread}"

execute_and_capture() {
  local binary="$1"
  local prefix="$2"
  local workdir="$3"
  local binary_abs
  binary_abs="$(cd "$(dirname "$binary")" && pwd)/$(basename "$binary")"
  mkdir -p "$workdir"
  set +e
  (cd "$workdir" && "$binary_abs") >"$prefix.stdout" 2>"$prefix.stderr"
  local status="$?"
  set -e
  printf '%s\n' "$status" >"$prefix.status"
}

while IFS=$'\t' read -r case_id source_fixture compile_status exit_status \
  diagnostic resource_state side_effect_policy normalization
do
  test "$compile_status" = 0
  test "$diagnostic" = none
  test "$resource_state" = not_applicable_no_resource
  test "$side_effect_policy" = none
  test "$normalization" = none
  case_dir="$build_root/$case_id"
  mkdir -p "$case_dir"

  ./gust --backend mir-to-c "$source_fixture" \
    >"$case_dir/program.c" 2>"$case_dir/mir.compiler.stderr"
  test ! -s "$case_dir/mir.compiler.stderr"
  cat src/runtime.c "$case_dir/program.c" >"$case_dir/program.final.c"
  "$cc_bin" $cflags -Isrc "$case_dir/program.final.c" \
    -o "$case_dir/mir-program"

  recording_driver="$case_dir/recording-driver"
  captured_request="$case_dir/captured.request"
  captured_bundle="$case_dir/captured.bundle"
  cat >"$recording_driver" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
: "${GUST_P20_REAL_DRIVER:?}"
: "${GUST_P20_CAPTURE_REQUEST:?}"
: "${GUST_P20_CAPTURE_BUNDLE:?}"
if [ "${1:-}" = phase10-backend-request-compile ]; then
  test "$#" = 2
  cp "$2" "$GUST_P20_CAPTURE_REQUEST"
  bundle_path="$(awk -F': ' '$1 == "program_mir_bundle_path" { print substr($0, index($0, ": ") + 2) }' "$2")"
  test -n "$bundle_path"
  test -f "$bundle_path"
  cp "$bundle_path" "$GUST_P20_CAPTURE_BUNDLE"
fi
exec "$GUST_P20_REAL_DRIVER" "$@"
WRAPPER
  chmod +x "$recording_driver"
  recording_driver_abs="$(cd "$(dirname "$recording_driver")" && pwd)/$(basename "$recording_driver")"

  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_NATIVE_BACKEND_DRIVER="$recording_driver_abs" \
  GUST_P20_REAL_DRIVER="$worker_abs" \
  GUST_P20_CAPTURE_REQUEST="$captured_request" \
  GUST_P20_CAPTURE_BUNDLE="$captured_bundle" \
    ./gust --backend cranelift -o "$case_dir/native-program" "$source_fixture" \
      >"$case_dir/native.compiler.stdout" \
      2>"$case_dir/native.compiler.stderr"
  test ! -s "$case_dir/native.compiler.stdout"
  test ! -s "$case_dir/native.compiler.stderr"
  test -s "$captured_request"
  test -s "$captured_bundle"
  if rg -n -e '^(source_path|source_text|source_bytes|ast_program):' \
      "$captured_request" >/dev/null; then
    echo "Patch 20.12 canonical request exposed raw source: $case_id" >&2
    exit 1
  fi

  execute_and_capture "$case_dir/mir-program" "$case_dir/mir" \
    "$case_dir/mir-workdir"
  execute_and_capture "$case_dir/native-program" "$case_dir/native" \
    "$case_dir/native-workdir"
  test "$(cat "$case_dir/mir.status")" = "$exit_status"
  cmp -s "$case_dir/mir.status" "$case_dir/native.status"
  cmp -s "$case_dir/mir.stdout" "$case_dir/native.stdout"
  cmp -s "$case_dir/mir.stderr" "$case_dir/native.stderr"
  test ! -s "$case_dir/mir.stdout"
  test ! -s "$case_dir/mir.stderr"
  test -z "$(find "$case_dir/mir-workdir" -mindepth 1 -print -quit)"
  test -z "$(find "$case_dir/native-workdir" -mindepth 1 -print -quit)"
  test ! -e "$case_dir/native-program.phase10.bundle"
  test ! -e "$case_dir/native-program.phase10.request"
  echo "✅ Patch 20.12 runtime case passed: $case_id"
done < <(python3 scripts/phase20_whole_program_corpus.py runtime-cases)

poison="$build_root/poison-driver"
poison_marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >"$GUST_P20_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"
poison_abs="$(cd "$(dirname "$poison")" && pwd)/$(basename "$poison")"

while IFS=$'\t' read -r case_id source_fixture compile_status exit_status \
  diagnostic resource_state side_effect_policy normalization
do
  test "$compile_status" = 1
  test "$exit_status" = none
  test "$side_effect_policy" = none
  test "$normalization" = none
  case_dir="$build_root/$case_id"
  mkdir -p "$case_dir"
  set +e
  ./gust --backend mir-to-c "$source_fixture" \
    >"$case_dir/mir.compiler.stdout" 2>"$case_dir/mir.compiler.stderr"
  mir_status="$?"
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_P20_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$poison_abs" \
    ./gust --backend cranelift -o "$case_dir/native-program" "$source_fixture" \
      >"$case_dir/native.compiler.stdout" \
      2>"$case_dir/native.compiler.stderr"
  native_status="$?"
  set -e
  test "$mir_status" = "$compile_status"
  test "$native_status" = "$compile_status"
  test ! -e "$poison_marker"
  test ! -e "$case_dir/native-program"
  cmp -s "$case_dir/mir.compiler.stdout" "$case_dir/native.compiler.stdout"
  cmp -s "$case_dir/mir.compiler.stderr" "$case_dir/native.compiler.stderr"
  rg -F "$diagnostic" "$case_dir/mir.compiler.stdout" \
    "$case_dir/mir.compiler.stderr" >/dev/null
  test "$resource_state" = rejected_before_runtime_no_live_owner
  echo "✅ Patch 20.12 failure case passed: $case_id"
done < <(python3 scripts/phase20_whole_program_corpus.py failure-cases)

echo "✅ Phase 20 whole-program initial corpus parity passed"
