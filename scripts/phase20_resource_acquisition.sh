#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase20_resource_acquisition"
user_positive="compiler/phase20_resource_acquisition_source.gst"
directory_positive="compiler/phase20_resource_acquisition_directory_source.gst"
path_transfer_positive="compiler/phase20_resource_acquisition_path_transfer_source.gst"
negatives=(
  compiler/future/p20_issue106_bound_directory_current.gst
  compiler/future/p20_issue106_unbound_directory_current.gst
  compiler/phase20_resource_acquisition_user_bound_invalid.gst
  compiler/phase20_resource_acquisition_user_discarded_invalid.gst
  compiler/phase20_resource_acquisition_directory_discarded_invalid.gst
  compiler/phase20_resource_acquisition_conditional_close_invalid.gst
  compiler/phase20_resource_acquisition_loop_close_invalid.gst
  compiler/phase20_resource_acquisition_match_close_invalid.gst
  compiler/phase20_resource_acquisition_callee_drop_invalid.gst
)
expected=(
  ResourceAcquisitionLeak
  ResourceAcquisitionLeak
  ResourceAcquisitionLeak
  ResourceAcquisitionDiscarded
  ResourceAcquisitionDiscarded
  ResourceAcquisitionLeak
  ResourceAcquisitionLeak
  ResourceAcquisitionLeak
  ResourceAcquisitionLeak
)

python3 scripts/phase20_resource_acquisition.py validate
rm -rf "$build_root"
mkdir -p "$build_root"

run_mir_to_c_positive() {
  local source="$1"
  local stem="$2"
  local expected_status="$3"

  ./gust "$source" >"$build_root/$stem.default.c" \
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

run_mir_to_c_positive "$user_positive" user 168
run_mir_to_c_positive "$directory_positive" directory 0
run_mir_to_c_positive "$path_transfer_positive" path_transfer 42

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
  test "$(rg -c "\[${expected[$index]}\]" \
    "$build_root/$stem.default.log")" = 1
  test ! -e "$build_root/$stem.native"
  index=$((index + 1))
done

user_stem="$(basename "$user_positive" .gst)"
set +e
./gust --backend cranelift -o "$build_root/$user_stem.native" "$user_positive" \
  >"$build_root/$user_stem.native.stdout" \
  2>"$build_root/$user_stem.native.stderr"
user_native_status="$?"
set -e
test "$user_native_status" -ne 0
test ! -e "$build_root/$user_stem.native"
rg -F 'decision=source_or_type_failure capability=phase13_generic_source_to_mir' \
  "$build_root/$user_stem.native.stdout" >/dev/null
rg -F 'expected_failure_stage=before_driver_discovery' \
  "$build_root/$user_stem.native.stdout" >/dev/null
rg -F 'class=canonical_mir_verification_error' \
  "$build_root/$user_stem.native.stdout" >/dev/null
rg -F 'unsupported top-level statement in module/import cohort' \
  "$build_root/$user_stem.native.stderr" >/dev/null

directory_stem="$(basename "$directory_positive" .gst)"
set +e
./gust --backend cranelift -o "$build_root/$directory_stem.native" \
  "$directory_positive" >"$build_root/$directory_stem.native.stdout" \
  2>"$build_root/$directory_stem.native.stderr"
directory_native_status="$?"
set -e
test "$directory_native_status" -ne 0
test ! -e "$build_root/$directory_stem.native"
test ! -s "$build_root/$directory_stem.native.stderr"
rg -F 'decision=deferred' "$build_root/$directory_stem.native.stdout" >/dev/null
rg -F 'expected_failure_stage=before_driver_discovery' \
  "$build_root/$directory_stem.native.stdout" >/dev/null
rg -F 'class=unsupported_native_capability' \
  "$build_root/$directory_stem.native.stdout" >/dev/null

echo "✅ Phase 20 acquisition-site resource parity passed"
