#!/usr/bin/env bash
set -euo pipefail

validator="scripts/cranelift_registry.py"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
build_root="build/guards/phase14_enum"
cargo_target="$build_root/cargo-target"
all_targets="${PHASE14_ENUM_ALL_TARGETS:-${PHASE14_ALL_TARGETS:-0}}"

for required_file in \
  "$validator" "$rust_manifest" \
  compiler/mir_enum.gst \
  compiler/mir_enum_mir_to_c.gst \
  compiler/mir_enum_smoke_test_entry.gst \
  ./gust
do
  if [ ! -e "$required_file" ]; then
    echo "Phase 14 enum differential is missing $required_file" >&2
    exit 1
  fi
done
if [ ! -x ./gust ]; then
  echo "Phase 14 enum differential requires the rebuilt ./gust compiler." >&2
  exit 1
fi

rm -rf "$build_root"
mkdir -p "$build_root"
while IFS= read -r target; do
  [ -n "$target" ] || continue
  mkdir -p "$build_root/$target"
done < <(python3 "$validator" phase14-enum-targets)

just guard compiler/mir_enum_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 14 enums and tagged unions' to.log >/dev/null

CARGO_TARGET_DIR="$cargo_target" cargo build \
  --locked --quiet --manifest-path "$rust_manifest"
driver="$cargo_target/debug/gust-cranelift-experiment"
if [ ! -x "$driver" ]; then
  echo "Phase 14 enum differential did not build $driver" >&2
  exit 1
fi

source scripts/phase14_target_selection.sh
phase14_select_targets \
  "$validator" \
  "phase14-enum-targets" \
  "phase14-enum-primary-target" \
  "$all_targets"

poison_marker="$build_root/poison-driver-invoked"
poison_driver="$build_root/poison-driver"
cat >"$poison_driver" <<'EOF_POISON'
#!/usr/bin/env bash
set -euo pipefail
printf 'enum poison driver invoked\n' >"${GUST_PHASE14_ENUM_POISON_MARKER:?}"
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
  printf 'phase14-enum-output-sentinel\n' >"$protected_output"
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
  GUST_PHASE14_ENUM_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$poison_driver_abs" \
    "$driver" phase14-enum-witness "$request_path" \
      >"$case_dir/worker.stdout" 2>"$case_dir/worker.stderr"
  local status="$?"
  set -e
  if [ "$status" = "0" ]; then
    echo "Phase 14 enum negative unexpectedly passed: $context" >&2
    exit 1
  fi
  rg -n -F 'gust_backend_request_failure:' "$case_dir/worker.stderr" >/dev/null
  rg -n -F "$reason_code" "$case_dir/worker.stderr" >/dev/null
  if [ -e "$poison_marker" ]; then
    cat "$poison_marker" >&2
    echo "Invalid Phase 14 enum reached poisoned driver discovery: $context" >&2
    exit 1
  fi
  cmp -s "$protected_output.expected" "$protected_output"
  if find "$case_dir" -maxdepth 1 -type f \
      \( -name '*.o' -o -name '*.bundle' -o -name '*.tmp' \) \
      -print -quit | grep -q .
  then
    echo "Invalid Phase 14 enum created transient artifacts: $context" >&2
    exit 1
  fi
}

for target in "${targets[@]}"; do
  case_dir="$build_root/$target"
  request_path="$case_dir/enum.request"
  expected="$case_dir/expected.witness"
  c_source="$case_dir/mir-to-c-enum.c"
  for generated in "$request_path" "$expected" "$c_source"; do
    if [ ! -f "$generated" ] || [ -L "$generated" ]; then
      echo "Missing generated Phase 14 enum artifact: $generated" >&2
      exit 1
    fi
  done

  "$driver" phase14-enum-witness "$request_path" \
    >"$case_dir/cranelift.witness" 2>"$case_dir/cranelift.stderr"
  if [ -s "$case_dir/cranelift.stderr" ]; then
    cat "$case_dir/cranelift.stderr" >&2
    exit 1
  fi
  cmp -s "$expected" "$case_dir/cranelift.witness" || {
    diff -u "$expected" "$case_dir/cranelift.witness" >&2 || true
    echo "Cranelift enum witness differs for $target." >&2
    exit 1
  }

  if [ "$target" = "$primary_target" ]; then
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$c_source" -o "$case_dir/mir-to-c-enum"
    "$case_dir/mir-to-c-enum" \
      >"$case_dir/mir-to-c.witness" 2>"$case_dir/mir-to-c.stderr"
    if [ -s "$case_dir/mir-to-c.stderr" ]; then
      cat "$case_dir/mir-to-c.stderr" >&2
      exit 1
    fi
    cmp -s "$expected" "$case_dir/mir-to-c.witness" || {
      diff -u "$expected" "$case_dir/mir-to-c.witness" >&2 || true
      echo "MIR-to-C enum witness differs for $target." >&2
      exit 1
    }
    # Compiler-assigned and explicit discriminants, both selected tag widths,
    # scalar and aggregate payloads, locals, and a branch join.
    rg -n -F 'enum_layout: enum_layout:v1:target=' "$expected" >/dev/null
    rg -n -F 'type=type:gust:enum:Color tag_type=type:gust:u8 tag_width=1 tag_offset=0 assignment=compiler_assigned payload_offset=1 max_payload_size=0 max_payload_alignment=1 size=1 alignment=1' "$expected" >/dev/null
    rg -n -F 'type=type:gust:enum:Status tag_type=type:gust:i32 tag_width=4 tag_offset=0 assignment=explicit payload_offset=4 max_payload_size=0 max_payload_alignment=1 size=4 alignment=4' "$expected" >/dev/null
    rg -n -F 'type=type:gust:enum:MaybeI32 tag_type=type:gust:u8 tag_width=1 tag_offset=0 assignment=compiler_assigned payload_offset=4 max_payload_size=4 max_payload_alignment=4 size=8 alignment=4' "$expected" >/dev/null
    rg -n -F 'type=type:gust:enum:Packet tag_type=type:gust:u8 tag_width=1 tag_offset=0 assignment=compiler_assigned payload_offset=4 max_payload_size=4 max_payload_alignment=4 size=8 alignment=4' "$expected" >/dev/null
    rg -n -F 'type=type:gust:enum:Batch tag_type=type:gust:u8 tag_width=1 tag_offset=0 assignment=compiler_assigned payload_offset=4 max_payload_size=8 max_payload_alignment=4 size=12 alignment=4' "$expected" >/dev/null
    rg -n -F 'enum_operation: tag_read_color_green kind=tag_read status=success value=1 offset=0 tag=1 arm_index=1' "$expected" >/dev/null
    rg -n -F 'enum_operation: tag_read_status_retry kind=tag_read status=success value=200 offset=0 tag=200 arm_index=1' "$expected" >/dev/null
    rg -n -F 'enum_operation: variant_test_color_green_false kind=variant_test status=success value=0' "$expected" >/dev/null
    rg -n -F 'enum_operation: match_packet_large kind=match_branch status=success value=2 offset=0 tag=2 arm_index=2' "$expected" >/dev/null
    rg -n -F 'enum_operation: payload_project_maybe_some kind=payload_project status=success value=77 offset=4' "$expected" >/dev/null
    rg -n -F 'enum_operation: payload_project_packet_small kind=payload_project status=success value=200 offset=4' "$expected" >/dev/null
    rg -n -F 'enum_operation: payload_project_batch_pair_second kind=payload_project status=success value=9 offset=8' "$expected" >/dev/null
    rg -n -F 'enum_value: enum_local_maybe type=type:gust:enum:MaybeI32 variant=Some discriminant=1 storage=function:main flow=local:slot0' "$expected" >/dev/null
    rg -n -F 'enum_value: enum_branch_maybe type=type:gust:enum:MaybeI32 variant=Some discriminant=1 storage=function:main flow=branch_join:block1:block2:block3' "$expected" >/dev/null
    rg -n -F 'enum_operation: payload_project_branch_maybe kind=payload_project status=success value=91 offset=4' "$expected" >/dev/null
  fi

  mutate_request "$request_path" "$case_dir/duplicate-discriminant.request" \
    'enum_layout_0_variant_1_discriminant: 1\n' \
    'enum_layout_0_variant_1_discriminant: 0\n'
  expect_worker_failure "$case_dir/duplicate-discriminant.request" "$target duplicate discriminant" "$case_dir/negative-duplicate-discriminant" "enum_duplicate_discriminant"

  mutate_request "$request_path" "$case_dir/discriminant-out-of-range.request" \
    'enum_layout_0_variant_2_discriminant: 2\n' \
    'enum_layout_0_variant_2_discriminant: 300\n'
  expect_worker_failure "$case_dir/discriminant-out-of-range.request" "$target discriminant out of range" "$case_dir/negative-discriminant-out-of-range" "enum_discriminant_out_of_range"

  mutate_request "$request_path" "$case_dir/invalid-tag.request" \
    'enum_value_0_discriminant: 1\n' \
    'enum_value_0_discriminant: 7\n'
  expect_worker_failure "$case_dir/invalid-tag.request" "$target invalid tag value" "$case_dir/negative-invalid-tag" "enum_invalid_tag_value"

  mutate_request "$request_path" "$case_dir/wrong-payload-type.request" \
    'enum_layout_2_variant_1_payload_element_type_id: type:gust:i32\n' \
    'enum_layout_2_variant_1_payload_element_type_id: type:gust:u8\n'
  expect_worker_failure "$case_dir/wrong-payload-type.request" "$target wrong payload type" "$case_dir/negative-wrong-payload-type" "enum_payload_type_mismatch"

  mutate_request "$request_path" "$case_dir/invalid-projection.request" \
    'enum_operation_9_payload_index: 0\n' \
    'enum_operation_9_payload_index: 5\n'
  expect_worker_failure "$case_dir/invalid-projection.request" "$target invalid payload projection" "$case_dir/negative-invalid-projection" "enum_invalid_payload_projection"

  mutate_request "$request_path" "$case_dir/inconsistent-variant-layout.request" \
    'enum_layout_2_variant_1_payload_size: 4\n' \
    'enum_layout_2_variant_1_payload_size: 8\n'
  expect_worker_failure "$case_dir/inconsistent-variant-layout.request" "$target inconsistent variant layout" "$case_dir/negative-inconsistent-variant-layout" "enum_inconsistent_variant_layout"

  echo "✅ Phase 14 enum parity passed: $target"
done

if [ "$all_targets" = "1" ]; then
  echo "✅ Phase 14 enum all-target parity passed: targets=${#targets[@]}"
else
  echo "✅ Phase 14 enum focused parity passed: target=$primary_target"
fi
