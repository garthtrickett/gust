#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase20_resource_acquisition"
negatives=(
  compiler/phase20_resource_acquisition_user_discarded_invalid.gst
  compiler/phase20_resource_acquisition_directory_discarded_invalid.gst
  compiler/phase20_resource_acquisition_conditional_close_invalid.gst
  compiler/phase20_resource_acquisition_loop_close_invalid.gst
  compiler/phase20_resource_acquisition_match_close_invalid.gst
)
expected=(
  ResourceAcquisitionDiscarded
  ResourceAcquisitionDiscarded
  ResourceAcquisitionLeak
  ResourceAcquisitionLeak
  ResourceAcquisitionLeak
)

make phase10-native-package
native_driver="$(pwd)/build/phase10-package/bin/gust-native-backend"

python3 scripts/phase20_resource_acquisition.py validate
python3 scripts/phase23_resource_acquisition_parity.py validate
test -x "$native_driver"
rm -rf "$build_root"
mkdir -p "$build_root"

run_mir_to_c_positive() {
  local source="$1"
  local stem="$2"
  local expected_status="$3"

  ./gust --backend mir-to-c "$source" >"$build_root/$stem.default.c" \
    2>"$build_root/$stem.default.stderr"
  ./gust --backend mir-to-c "$source" >"$build_root/$stem.explicit.c" \
    2>"$build_root/$stem.explicit.stderr"
  test ! -s "$build_root/$stem.default.stderr"
  test ! -s "$build_root/$stem.explicit.stderr"
  cmp -s "$build_root/$stem.default.c" "$build_root/$stem.explicit.c"

  cat src/runtime.c "$build_root/$stem.default.c" \
    >"$build_root/$stem.final.c"
  "${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
    "$build_root/$stem.final.c" -o "$build_root/$stem.program"
  set +e
  "$build_root/$stem.program" >"$build_root/$stem.stdout" \
    2>"$build_root/$stem.stderr"
  local status="$?"
  set -e
  test "$status" = "$expected_status"
  test ! -s "$build_root/$stem.stdout"
  test ! -s "$build_root/$stem.stderr"
}

run_native_positive() {
  local source="$1"
  local stem="$2"
  local expected_status="$3"

  GUST_NATIVE_BACKEND_DRIVER="$native_driver" \
    ./gust --backend cranelift -o "$build_root/$stem.native" "$source" \
      >"$build_root/$stem.native.compile.stdout" \
      2>"$build_root/$stem.native.compile.stderr"
  test ! -s "$build_root/$stem.native.compile.stdout"
  test ! -s "$build_root/$stem.native.compile.stderr"
  test -x "$build_root/$stem.native"
  test -s "$build_root/$stem.native"
  set +e
  "$build_root/$stem.native" >"$build_root/$stem.native.stdout" \
    2>"$build_root/$stem.native.stderr"
  local status="$?"
  set -e
  test "$status" = "$expected_status"
  cmp -s "$build_root/$stem.stdout" "$build_root/$stem.native.stdout"
  cmp -s "$build_root/$stem.stderr" "$build_root/$stem.native.stderr"
}

positive_count=0
while IFS=$'\t' read -r id source expected_status; do
  test -n "$id"
  run_mir_to_c_positive "$source" "$id" "$expected_status"
  run_native_positive "$source" "$id" "$expected_status"
  positive_count=$((positive_count + 1))
done < <(python3 scripts/phase23_resource_acquisition_parity.py positive-cases)
test "$positive_count" = 3

index=0
for negative in "${negatives[@]}"; do
  stem="$(basename "$negative" .gst)"
  set +e
  ./gust --backend mir-to-c "$negative" >"$build_root/$stem.default.log" 2>&1
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
  test "$(rg -c "\[${expected[$index]}\]" \
    "$build_root/$stem.default.log")" = 1
  test ! -e "$build_root/$stem.native"
  index=$((index + 1))
done

missing_output="$build_root/missing-driver-output"
missing_driver="$(pwd)/$build_root/deliberately-missing-driver"
printf '%s\n' phase23-resource-acquisition-missing-driver-sentinel >"$missing_output"
cp "$missing_output" "$missing_output.expected"
set +e
GUST_NATIVE_BACKEND_DRIVER="$missing_driver" \
  ./gust --backend cranelift -o "$missing_output" \
  compiler/phase20_resource_acquisition_source.gst \
  >"$build_root/missing-driver.stdout" 2>"$build_root/missing-driver.stderr"
missing_driver_status="$?"
set -e
test "$missing_driver_status" -ne 0
cmp -s "$missing_output.expected" "$missing_output"
cat "$build_root/missing-driver.stdout" "$build_root/missing-driver.stderr" \
  >"$build_root/missing-driver.combined"
rg -F 'Native backend driver discovery error:' \
  "$build_root/missing-driver.combined" >/dev/null
rg -F 'explicit native backend driver path is unavailable or not executable' \
  "$build_root/missing-driver.combined" >/dev/null

echo "✅ Phase 20 acquisition-site resource parity passed"
