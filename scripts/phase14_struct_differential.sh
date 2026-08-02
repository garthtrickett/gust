#!/usr/bin/env bash
set -euo pipefail

validator="scripts/cranelift_registry.py"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
build_root="build/guards/phase14_struct"
cargo_target="$build_root/cargo-target"
all_targets="${PHASE14_STRUCT_ALL_TARGETS:-0}"

for required_file in \
  "$validator" "$rust_manifest" \
  compiler/mir_struct_layout.gst \
  compiler/mir_struct_layout_mir_to_c.gst \
  compiler/mir_struct_layout_smoke_test_entry.gst \
  ./gust
do
  if [ ! -e "$required_file" ]; then
    echo "Phase 14 struct differential is missing $required_file" >&2
    exit 1
  fi
done
if [ ! -x ./gust ]; then
  echo "Phase 14 struct differential requires the rebuilt ./gust compiler." >&2
  exit 1
fi

rm -rf "$build_root"
mkdir -p "$build_root"
while IFS= read -r target; do
  [ -n "$target" ] || continue
  mkdir -p "$build_root/$target"
done < <(python3 "$validator" phase14-struct-targets)

just guard compiler/mir_struct_layout_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 14 declaration-order struct layout' to.log >/dev/null

CARGO_TARGET_DIR="$cargo_target" cargo build \
  --locked --quiet --manifest-path "$rust_manifest"
driver="$cargo_target/debug/gust-cranelift-experiment"
if [ ! -x "$driver" ]; then
  echo "Phase 14 struct differential did not build $driver" >&2
  exit 1
fi

primary_target="$(python3 "$validator" phase14-struct-primary-target)"
if [ "$all_targets" = "1" ]; then
  mapfile -t targets < <(python3 "$validator" phase14-struct-targets)
else
  targets=("$primary_target")
fi

poison_marker="$build_root/poison-driver-invoked"
poison_driver="$build_root/poison-driver"
cat >"$poison_driver" <<'EOF_POISON'
#!/usr/bin/env bash
set -euo pipefail
printf 'struct poison driver invoked\n' >"${GUST_PHASE14_STRUCT_POISON_MARKER:?}"
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
  printf 'phase14-struct-output-sentinel\n' >"$protected_output"
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
  GUST_PHASE14_STRUCT_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$poison_driver_abs" \
    "$driver" phase14-struct-witness "$request_path" \
      >"$case_dir/worker.stdout" 2>"$case_dir/worker.stderr"
  local status="$?"
  set -e
  if [ "$status" = "0" ]; then
    echo "Phase 14 struct negative unexpectedly passed: $context" >&2
    exit 1
  fi
  rg -n -F 'gust_backend_request_failure:' "$case_dir/worker.stderr" >/dev/null
  rg -n -F "$reason_code" "$case_dir/worker.stderr" >/dev/null
  if [ -e "$poison_marker" ]; then
    cat "$poison_marker" >&2
    echo "Invalid Phase 14 struct reached poisoned driver discovery: $context" >&2
    exit 1
  fi
  cmp -s "$protected_output.expected" "$protected_output"
  if find "$case_dir" -maxdepth 1 -type f \
      \( -name '*.o' -o -name '*.bundle' -o -name '*.tmp' \) \
      -print -quit | grep -q .
  then
    echo "Invalid Phase 14 struct created transient artifacts: $context" >&2
    exit 1
  fi
}

for target in "${targets[@]}"; do
  case_dir="$build_root/$target"
  request_path="$case_dir/struct.request"
  expected="$case_dir/expected.witness"
  c_source="$case_dir/mir-to-c-struct.c"
  for generated in "$request_path" "$expected" "$c_source"; do
    if [ ! -f "$generated" ] || [ -L "$generated" ]; then
      echo "Missing generated Phase 14 struct artifact: $generated" >&2
      exit 1
    fi
  done

  "$driver" phase14-struct-witness "$request_path" \
    >"$case_dir/cranelift.witness" 2>"$case_dir/cranelift.stderr"
  if [ -s "$case_dir/cranelift.stderr" ]; then
    cat "$case_dir/cranelift.stderr" >&2
    exit 1
  fi
  cmp -s "$expected" "$case_dir/cranelift.witness" || {
    diff -u "$expected" "$case_dir/cranelift.witness" >&2 || true
    echo "Cranelift struct witness differs for $target." >&2
    exit 1
  }

  if [ "$target" = "$primary_target" ]; then
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    # The generated C declares real structs, so its _Static_asserts fail to
    # compile if a compiler-owned offset, size, or alignment is wrong.
    "$CC_BIN" $CFLAGS_VAL "$c_source" -o "$case_dir/mir-to-c-struct"
    "$case_dir/mir-to-c-struct" \
      >"$case_dir/mir-to-c.witness" 2>"$case_dir/mir-to-c.stderr"
    if [ -s "$case_dir/mir-to-c.stderr" ]; then
      cat "$case_dir/mir-to-c.stderr" >&2
      exit 1
    fi
    cmp -s "$expected" "$case_dir/mir-to-c.witness" || {
      diff -u "$expected" "$case_dir/mir-to-c.witness" >&2 || true
      echo "MIR-to-C struct witness differs for $target." >&2
      exit 1
    }
    rg -n -F 'offsetof(' "$c_source" >/dev/null
    # Declaration order, inter-field padding, dense packing, tail padding,
    # bounded nesting, and a value crossing a branch join.
    rg -n -F 'type=type:gust:struct:Point size=8 alignment=4 nesting=1' "$expected" >/dev/null
    rg -n -F 'type=type:gust:struct:Header size=8 alignment=4 nesting=1' "$expected" >/dev/null
    rg -n -F 'type=type:gust:struct:Flags size=3 alignment=1 nesting=1' "$expected" >/dev/null
    rg -n -F 'type=type:gust:struct:Padded size=8 alignment=4 nesting=1' "$expected" >/dev/null
    rg -n -F 'type=type:gust:struct:Nested size=12 alignment=4 nesting=2' "$expected" >/dev/null
    rg -n -F 'struct_field: type:gust:struct:Header.tag declaration_index=0 type=type:gust:u8 offset=0 size=1 alignment=1 aggregate=0' "$expected" >/dev/null
    rg -n -F 'struct_field: type:gust:struct:Header.value declaration_index=1 type=type:gust:i32 offset=4 size=4 alignment=4 aggregate=0' "$expected" >/dev/null
    rg -n -F 'struct_field: type:gust:struct:Flags.c declaration_index=2 type=type:gust:u8 offset=2 size=1 alignment=1 aggregate=0' "$expected" >/dev/null
    rg -n -F 'struct_field: type:gust:struct:Nested.head declaration_index=0 type=type:gust:struct:Header offset=0 size=8 alignment=4 aggregate=1' "$expected" >/dev/null
    rg -n -F 'struct_leaf: type:gust:struct:Nested.head.value type=type:gust:i32 offset=4 size=4' "$expected" >/dev/null
    rg -n -F 'struct_operation: address_header_value kind=field_address status=success value=4 offset=4' "$expected" >/dev/null
    rg -n -F 'struct_operation: load_flags_b kind=field_load status=success value=2 offset=1' "$expected" >/dev/null
    rg -n -F 'struct_operation: load_padded_flag kind=field_load status=success value=9 offset=4' "$expected" >/dev/null
    rg -n -F 'struct_operation: load_nested_head_value kind=field_load status=success value=2200 offset=4' "$expected" >/dev/null
    rg -n -F 'struct_operation: load_nested_extra kind=field_load status=success value=42 offset=8' "$expected" >/dev/null
    rg -n -F 'struct_value: struct_local_point layout=' "$expected" >/dev/null
    rg -n -F 'flow=branch_join:block1:block2:block3' "$expected" >/dev/null
    rg -n -F 'struct_operation: load_local_point_y kind=field_load status=success value=91 offset=4' "$expected" >/dev/null
  fi

  mutate_request "$request_path" "$case_dir/duplicate-field.request" \
    'struct_layout_2_field_1_name: b\n' \
    'struct_layout_2_field_1_name: a\n'
  expect_worker_failure "$case_dir/duplicate-field.request" "$target duplicate field" "$case_dir/negative-duplicate-field" "struct_duplicate_field"

  mutate_request "$request_path" "$case_dir/misaligned-field.request" \
    'struct_layout_1_field_1_offset: 4\n' \
    'struct_layout_1_field_1_offset: 6\n'
  expect_worker_failure "$case_dir/misaligned-field.request" "$target misaligned field" "$case_dir/negative-misaligned-field" "struct_field_misaligned"

  mutate_request "$request_path" "$case_dir/field-overlap.request" \
    'struct_layout_0_field_1_offset: 4\n' \
    'struct_layout_0_field_1_offset: 0\n'
  expect_worker_failure "$case_dir/field-overlap.request" "$target overlapping fields" "$case_dir/negative-field-overlap" "struct_field_overlap"

  mutate_request "$request_path" "$case_dir/wrong-field-type.request" \
    'struct_layout_1_field_1_type_id: type:gust:i32\n' \
    'struct_layout_1_field_1_type_id: type:gust:u8\n'
  expect_worker_failure "$case_dir/wrong-field-type.request" "$target wrong field type" "$case_dir/negative-wrong-field-type" "struct_field_type_mismatch"

  mutate_request "$request_path" "$case_dir/size-alignment.request" \
    'struct_layout_0_size: 8\n' \
    'struct_layout_0_size: 12\n'
  expect_worker_failure "$case_dir/size-alignment.request" "$target size/alignment mismatch" "$case_dir/negative-size-alignment" "struct_size_alignment_mismatch"

  mutate_request "$request_path" "$case_dir/unknown-field.request" \
    'struct_operation_3_field_path: x\n' \
    'struct_operation_3_field_path: zzz\n'
  expect_worker_failure "$case_dir/unknown-field.request" "$target unknown field path" "$case_dir/negative-unknown-field" "struct_field_unknown"

  echo "✅ Phase 14 struct parity passed: $target"
done

if [ "$all_targets" = "1" ]; then
  echo "✅ Phase 14 struct all-target parity passed: targets=${#targets[@]}"
else
  echo "✅ Phase 14 struct focused parity passed: target=$primary_target"
fi
