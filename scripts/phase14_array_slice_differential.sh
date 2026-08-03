#!/usr/bin/env bash
set -euo pipefail

validator="scripts/cranelift_registry.py"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
build_root="build/guards/phase14_array_slice"
cargo_target="$build_root/cargo-target"
all_targets="${PHASE14_ARRAY_SLICE_ALL_TARGETS:-${PHASE14_ALL_TARGETS:-0}}"

for required_file in \
  "$validator" "$rust_manifest" \
  compiler/mir_array_slice.gst \
  compiler/mir_array_slice_mir_to_c.gst \
  compiler/mir_array_slice_smoke_test_entry.gst \
  ./gust
do
  if [ ! -e "$required_file" ]; then
    echo "Phase 14 array/slice differential is missing $required_file" >&2
    exit 1
  fi
done
if [ ! -x ./gust ]; then
  echo "Phase 14 array/slice differential requires the rebuilt ./gust compiler." >&2
  exit 1
fi

rm -rf "$build_root"
mkdir -p "$build_root"
while IFS= read -r target; do
  [ -n "$target" ] || continue
  mkdir -p "$build_root/$target"
done < <(python3 "$validator" phase14-array-slice-targets)

just guard compiler/mir_array_slice_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 14 fixed arrays and bounded slices' to.log >/dev/null

CARGO_TARGET_DIR="$cargo_target" cargo build \
  --locked --quiet --manifest-path "$rust_manifest"
driver="$cargo_target/debug/gust-cranelift-experiment"
if [ ! -x "$driver" ]; then
  echo "Phase 14 array/slice differential did not build $driver" >&2
  exit 1
fi

source scripts/phase14_target_selection.sh
phase14_select_targets \
  "$validator" \
  "phase14-array-slice-targets" \
  "phase14-array-slice-primary-target" \
  "$all_targets"

poison_marker="$build_root/poison-driver-invoked"
poison_driver="$build_root/poison-driver"
cat >"$poison_driver" <<'EOF_POISON'
#!/usr/bin/env bash
set -euo pipefail
printf 'array/slice poison driver invoked\n' >"${GUST_PHASE14_ARRAY_SLICE_POISON_MARKER:?}"
exit 97
EOF_POISON
chmod +x "$poison_driver"
poison_driver_abs="$(cd "$(dirname "$poison_driver")" && pwd)/$(basename "$poison_driver")"

mutate_request() {
  local source="$1"
  local destination="$2"
  local old="$3"
  local new="$4"
  python3 - "$source" "$destination" "$old" "$new" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
old = sys.argv[3].encode("utf-8").decode("unicode_escape")
new = sys.argv[4].encode("utf-8").decode("unicode_escape")
if source.count(old) != 1:
    raise SystemExit(f"expected exactly one mutation token: {old!r}")
Path(sys.argv[2]).write_text(source.replace(old, new, 1))
PY
}

expect_worker_failure() {
  local request_path="$1"
  local context="$2"
  local case_dir="$3"
  local reason_code="$4"
  local protected_output="$case_dir/protected-output"
  mkdir -p "$case_dir"
  printf 'phase14-array-slice-output-sentinel\n' >"$protected_output"
  cp "$protected_output" "$protected_output.expected"
  python3 - "$request_path" "$protected_output" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
output = str(Path(sys.argv[2]).resolve())
lines = path.read_text().splitlines()
for index, line in enumerate(lines):
    if line.startswith("output_path: "):
        lines[index] = f"output_path: {output}"
        break
else:
    raise SystemExit("missing output_path")
path.write_text("\n".join(lines) + "\n")
PY
  rm -f "$poison_marker"
  set +e
  GUST_PHASE14_ARRAY_SLICE_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$poison_driver_abs" \
    "$driver" phase14-array-slice-witness "$request_path" \
      >"$case_dir/worker.stdout" 2>"$case_dir/worker.stderr"
  local status="$?"
  set -e
  if [ "$status" = "0" ]; then
    echo "Phase 14 array/slice negative unexpectedly passed: $context" >&2
    exit 1
  fi
  rg -n -F 'gust_backend_request_failure:' "$case_dir/worker.stderr" >/dev/null
  rg -n -F "$reason_code" "$case_dir/worker.stderr" >/dev/null
  if [ -e "$poison_marker" ]; then
    cat "$poison_marker" >&2
    echo "Invalid Phase 14 array/slice reached poisoned driver discovery: $context" >&2
    exit 1
  fi
  cmp -s "$protected_output.expected" "$protected_output"
  if find "$case_dir" -maxdepth 1 -type f \
      \( -name '*.o' -o -name '*.bundle' -o -name '*.tmp' \) \
      -print -quit | grep -q .
  then
    echo "Invalid Phase 14 array/slice created transient artifacts: $context" >&2
    exit 1
  fi
}

for target in "${targets[@]}"; do
  case_dir="$build_root/$target"
  request_path="$case_dir/array-slice.request"
  expected="$case_dir/expected.witness"
  c_source="$case_dir/mir-to-c-array-slice.c"
  for generated in "$request_path" "$expected" "$c_source"; do
    if [ ! -f "$generated" ] || [ -L "$generated" ]; then
      echo "Missing generated Phase 14 array/slice artifact: $generated" >&2
      exit 1
    fi
  done

  "$driver" phase14-array-slice-witness "$request_path" \
    >"$case_dir/cranelift.witness" 2>"$case_dir/cranelift.stderr"
  if [ -s "$case_dir/cranelift.stderr" ]; then
    cat "$case_dir/cranelift.stderr" >&2
    exit 1
  fi
  cmp -s "$expected" "$case_dir/cranelift.witness" || {
    diff -u "$expected" "$case_dir/cranelift.witness" >&2 || true
    echo "Cranelift array/slice witness differs for $target." >&2
    exit 1
  }

  if [ "$target" = "$primary_target" ]; then
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$c_source" -o "$case_dir/mir-to-c-array-slice"
    "$case_dir/mir-to-c-array-slice" \
      >"$case_dir/mir-to-c.witness" 2>"$case_dir/mir-to-c.stderr"
    if [ -s "$case_dir/mir-to-c.stderr" ]; then
      cat "$case_dir/mir-to-c.stderr" >&2
      exit 1
    fi
    cmp -s "$expected" "$case_dir/mir-to-c.witness" || {
      diff -u "$expected" "$case_dir/mir-to-c.witness" >&2 || true
      echo "MIR-to-C array/slice witness differs for $target." >&2
      exit 1
    }
    rg -n -F 'array_slice_operation: load_i32_first kind=element_load status=success value=11' "$expected" >/dev/null
    rg -n -F 'array_slice_operation: load_i32_middle kind=element_load status=success value=33' "$expected" >/dev/null
    rg -n -F 'array_slice_operation: load_i32_last kind=element_load status=success value=44' "$expected" >/dev/null
    rg -n -F 'array_slice_operation: slice_length_empty kind=slice_length status=success value=0' "$expected" >/dev/null
    rg -n -F 'array_slice_operation: nested_address_second kind=element_address status=success value=8 address_offset=8' "$expected" >/dev/null
    rg -n -F 'array_slice_operation: branch_join_index kind=bounded_index status=success value=33' "$expected" >/dev/null
  fi

  mutate_request "$request_path" "$case_dir/count-overflow.request" \
    'array_layout_0_element_count: 4\n' \
    'array_layout_0_element_count: 1048577\n'
  expect_worker_failure "$case_dir/count-overflow.request" "$target count overflow" "$case_dir/negative-count-overflow" "array_count_overflow"

  mutate_request "$request_path" "$case_dir/total-size-overflow.request" \
    'array_layout_0_total_size: 16\n' \
    'array_layout_0_total_size: 1073741825\n'
  expect_worker_failure "$case_dir/total-size-overflow.request" "$target total-size overflow" "$case_dir/negative-total-size-overflow" "array_total_size_overflow"

  mutate_request "$request_path" "$case_dir/invalid-stride.request" \
    'array_layout_0_element_stride: 4\n' \
    'array_layout_0_element_stride: 8\n'
  expect_worker_failure "$case_dir/invalid-stride.request" "$target invalid stride" "$case_dir/negative-invalid-stride" "array_stride_mismatch"

  mutate_request "$request_path" "$case_dir/out-of-bounds.request" \
    'array_slice_operation_6_index: 3\n' \
    'array_slice_operation_6_index: 4\n'
  expect_worker_failure "$case_dir/out-of-bounds.request" "$target out-of-bounds access" "$case_dir/negative-out-of-bounds" "array_slice_index_out_of_bounds"

  mutate_request "$request_path" "$case_dir/wrong-element-type.request" \
    'array_slice_operation_4_element_type_id: type:gust:i32\n' \
    'array_slice_operation_4_element_type_id: type:gust:u8\n'
  expect_worker_failure "$case_dir/wrong-element-type.request" "$target wrong element type" "$case_dir/negative-wrong-element-type" "array_slice_element_type_mismatch"

  mutate_request "$request_path" "$case_dir/null-nonempty.request" \
    'slice_0_data_known_null: 0\n' \
    'slice_0_data_known_null: 1\n'
  expect_worker_failure "$case_dir/null-nonempty.request" "$target invalid slice pointer/length pair" "$case_dir/negative-null-nonempty" "slice_null_nonempty"

  mutate_request "$request_path" "$case_dir/lifetime-escape.request" \
    'slice_0_lifetime_region: function:main\n' \
    'slice_0_lifetime_region: static_program\n'
  expect_worker_failure "$case_dir/lifetime-escape.request" "$target slice lifetime escape" "$case_dir/negative-lifetime" "slice_lifetime_escape"

  echo "✅ Phase 14 array/slice parity passed: $target"
done

if [ "$all_targets" = "1" ]; then
  echo "✅ Phase 14 array/slice all-target parity passed: targets=${#targets[@]}"
else
  echo "✅ Phase 14 array/slice focused parity passed: target=$primary_target"
fi
