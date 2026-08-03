#!/usr/bin/env bash
set -euo pipefail

validator="scripts/cranelift_registry.py"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
build_root="build/guards/phase14_aggregate_transport"
cargo_target="$build_root/cargo-target"
all_targets="${PHASE14_AGGREGATE_ALL_TARGETS:-0}"

for required_file in \
  "$validator" "$rust_manifest" \
  compiler/mir_aggregate_transport.gst \
  compiler/mir_aggregate_transport_mir_to_c.gst \
  compiler/mir_aggregate_transport_smoke_test_entry.gst \
  ./gust
do
  if [ ! -e "$required_file" ]; then
    echo "Phase 14 aggregate differential is missing $required_file" >&2
    exit 1
  fi
done
if [ ! -x ./gust ]; then
  echo "Phase 14 aggregate differential requires the rebuilt ./gust compiler." >&2
  exit 1
fi

rm -rf "$build_root"
mkdir -p "$build_root"
while IFS= read -r target; do
  [ -n "$target" ] || continue
  mkdir -p "$build_root/$target"
done < <(python3 "$validator" phase14-aggregate-targets)

just guard compiler/mir_aggregate_transport_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 14 aggregate transport across basic blocks' to.log >/dev/null

CARGO_TARGET_DIR="$cargo_target" cargo build \
  --locked --quiet --manifest-path "$rust_manifest"
driver="$cargo_target/debug/gust-cranelift-experiment"
if [ ! -x "$driver" ]; then
  echo "Phase 14 aggregate differential did not build $driver" >&2
  exit 1
fi

primary_target="$(python3 "$validator" phase14-aggregate-primary-target)"
if [ "$all_targets" = "1" ]; then
  mapfile -t targets < <(python3 "$validator" phase14-aggregate-targets)
else
  targets=("$primary_target")
fi

poison_marker="$build_root/poison-driver-invoked"
poison_driver="$build_root/poison-driver"
cat >"$poison_driver" <<'EOF_POISON'
#!/usr/bin/env bash
set -euo pipefail
printf 'aggregate poison driver invoked\n' >"${GUST_PHASE14_AGGREGATE_POISON_MARKER:?}"
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
  printf 'phase14-aggregate-output-sentinel\n' >"$protected_output"
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
  GUST_PHASE14_AGGREGATE_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$poison_driver_abs" \
    "$driver" phase14-aggregate-witness "$request_path" \
      >"$case_dir/worker.stdout" 2>"$case_dir/worker.stderr"
  local status="$?"
  set -e
  if [ "$status" = "0" ]; then
    echo "Phase 14 aggregate negative unexpectedly passed: $context" >&2
    exit 1
  fi
  rg -n -F 'gust_backend_request_failure:' "$case_dir/worker.stderr" >/dev/null
  rg -n -F "$reason_code" "$case_dir/worker.stderr" >/dev/null
  if [ -e "$poison_marker" ]; then
    cat "$poison_marker" >&2
    echo "Invalid Phase 14 aggregate reached poisoned driver discovery: $context" >&2
    exit 1
  fi
  cmp -s "$protected_output.expected" "$protected_output"
  if find "$case_dir" -maxdepth 1 -type f \
      \( -name '*.o' -o -name '*.bundle' -o -name '*.tmp' \) \
      -print -quit | grep -q .
  then
    echo "Invalid Phase 14 aggregate created transient artifacts: $context" >&2
    exit 1
  fi
}

for target in "${targets[@]}"; do
  case_dir="$build_root/$target"
  request_path="$case_dir/aggregate.request"
  expected="$case_dir/expected.witness"
  c_source="$case_dir/mir-to-c-aggregate.c"
  for generated in "$request_path" "$expected" "$c_source"; do
    if [ ! -f "$generated" ] || [ -L "$generated" ]; then
      echo "Missing generated Phase 14 aggregate artifact: $generated" >&2
      exit 1
    fi
  done

  "$driver" phase14-aggregate-witness "$request_path" \
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
    "$CC_BIN" $CFLAGS_VAL "$c_source" -o "$case_dir/mir-to-c-aggregate"
    "$case_dir/mir-to-c-aggregate" \
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
    # Both transport policies, every selected class, joins, a loop backedge,
    # and the compiler-owned block-argument arity.
    rg -n -F 'aggregate_class: string_view transport=fieldwise_canonical_values' "$expected" >/dev/null
    rg -n -F 'aggregate_class: slice transport=fieldwise_canonical_values' "$expected" >/dev/null
    rg -n -F 'aggregate_class: struct transport=fieldwise_canonical_values' "$expected" >/dev/null
    rg -n -F 'aggregate_class: enum transport=fieldwise_canonical_values' "$expected" >/dev/null
    rg -n -F 'aggregate_class: fixed_array transport=layout_backed_stack_copy' "$expected" >/dev/null
    rg -n -F 'aggregate_class: nested transport=layout_backed_stack_copy' "$expected" >/dev/null
    rg -n -F 'aggregate_value: agg_array class=fixed_array' "$expected" >/dev/null
    rg -n -F 'components=4 arity=1' "$expected" >/dev/null
    rg -n -F 'aggregate_block: if_join join=1 loop_header=0 params=2 block_arguments=4' "$expected" >/dev/null
    rg -n -F 'aggregate_block: seq_block join=1 loop_header=0 params=1 block_arguments=2' "$expected" >/dev/null
    rg -n -F 'aggregate_block: loop_header join=1 loop_header=1 params=2 block_arguments=3' "$expected" >/dev/null
    rg -n -F 'aggregate_edge: then_block->if_join kind=fallthrough arguments=2' "$expected" >/dev/null
    rg -n -F 'aggregate_edge: else_block->if_join kind=fallthrough arguments=2' "$expected" >/dev/null
    rg -n -F 'aggregate_edge: loop_body->loop_header kind=backedge arguments=2' "$expected" >/dev/null
    rg -n -F 'aggregate_operation: observe_join_point_x kind=join_observe status=success value=3' "$expected" >/dev/null
    rg -n -F 'aggregate_operation: observe_join_point_y_else kind=join_observe status=success value=9 offset=4' "$expected" >/dev/null
    rg -n -F 'aggregate_operation: observe_loop_array_last kind=join_observe status=success value=44 offset=12 arity=1' "$expected" >/dev/null
    rg -n -F 'aggregate_operation: carry_loop_state kind=loop_carry status=success value=2 offset=0 arity=3' "$expected" >/dev/null
    rg -n -F 'aggregate_operation: early_return_scalar kind=early_return status=success value=65' "$expected" >/dev/null
    # The generated C must actually branch and loop, not straight-line the join.
    rg -n -F 'if (gust_cond)' "$c_source" >/dev/null
    rg -n -F 'for (int gust_iter' "$c_source" >/dev/null
  fi

  mutate_request "$request_path" "$case_dir/join-layout.request" \
    'aggregate_value_1_size: 8\n' \
    'aggregate_value_1_size: 12\n'
  expect_worker_failure "$case_dir/join-layout.request" "$target join layout mismatch" "$case_dir/negative-join-layout" "aggregate_join_layout_mismatch"

  mutate_request "$request_path" "$case_dir/field-count.request" \
    'aggregate_block_3_param_1_block_argument_count: 2\n' \
    'aggregate_block_3_param_1_block_argument_count: 1\n'
  expect_worker_failure "$case_dir/field-count.request" "$target field count mismatch" "$case_dir/negative-field-count" "aggregate_field_count_mismatch"

  mutate_request "$request_path" "$case_dir/variant.request" \
    'aggregate_value_3_variant_name: Some\n' \
    'aggregate_value_3_variant_name: None\n'
  expect_worker_failure "$case_dir/variant.request" "$target variant mismatch" "$case_dir/negative-variant" "aggregate_variant_mismatch"

  mutate_request "$request_path" "$case_dir/lifetime.request" \
    'aggregate_value_0_lifetime_region: function:main\n' \
    'aggregate_value_0_lifetime_region: static_program\n'
  expect_worker_failure "$case_dir/lifetime.request" "$target invalid lifetime" "$case_dir/negative-lifetime" "aggregate_invalid_lifetime"

  mutate_request "$request_path" "$case_dir/use-after-move.request" \
    'aggregate_value_6_movement_kind: copy\n' \
    'aggregate_value_6_movement_kind: move\n'
  expect_worker_failure "$case_dir/use-after-move.request" "$target use after move" "$case_dir/negative-use-after-move" "aggregate_use_after_move"

  mutate_request "$request_path" "$case_dir/resource-copy.request" \
    'aggregate_value_6_is_resource: 0\n' \
    'aggregate_value_6_is_resource: 1\n'
  expect_worker_failure "$case_dir/resource-copy.request" "$target resource-bearing copy" "$case_dir/negative-resource-copy" "aggregate_resource_copy_rejected"

  echo "✅ Phase 14 aggregate parity passed: $target"
done

if [ "$all_targets" = "1" ]; then
  echo "✅ Phase 14 aggregate all-target parity passed: targets=${#targets[@]}"
else
  echo "✅ Phase 14 aggregate focused parity passed: target=$primary_target"
fi
