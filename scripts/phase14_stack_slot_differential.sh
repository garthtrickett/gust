#!/usr/bin/env bash
set -euo pipefail

validator="scripts/cranelift_registry.py"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
build_root="build/guards/phase14_stack_slot"
cargo_target="$build_root/cargo-target"
all_targets="${PHASE14_STACK_SLOT_ALL_TARGETS:-0}"

for required_file in \
  "$validator" "$rust_manifest" \
  compiler/mir_stack_slot.gst \
  compiler/mir_stack_slot_mir_to_c.gst \
  compiler/mir_stack_slot_smoke_test_entry.gst \
  ./gust
do
  if [ ! -e "$required_file" ]; then
    echo "Phase 14 stack-slot differential is missing $required_file" >&2
    exit 1
  fi
done
if [ ! -x ./gust ]; then
  echo "Phase 14 stack-slot differential requires the rebuilt ./gust compiler." >&2
  exit 1
fi

rm -rf "$build_root"
mkdir -p "$build_root"
while IFS= read -r target; do
  [ -n "$target" ] || continue
  mkdir -p "$build_root/$target"
done < <(python3 "$validator" phase14-stack-slot-targets)

just guard compiler/mir_stack_slot_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 14 deterministic stack slots and addressable locals' to.log >/dev/null

CARGO_TARGET_DIR="$cargo_target" cargo build \
  --locked --quiet --manifest-path "$rust_manifest"
driver="$cargo_target/debug/gust-cranelift-experiment"
if [ ! -x "$driver" ]; then
  echo "Phase 14 stack-slot differential did not build $driver" >&2
  exit 1
fi

primary_target="$(python3 "$validator" phase14-stack-slot-primary-target)"
if [ "$all_targets" = "1" ]; then
  mapfile -t targets < <(python3 "$validator" phase14-stack-slot-targets)
else
  targets=("$primary_target")
fi

expect_worker_failure() {
  local request_path="$1"
  local context="$2"
  local stdout_path="$3"
  local stderr_path="$4"
  local reason_code="$5"
  set +e
  "$driver" phase14-stack-slot-witness "$request_path" \
    >"$stdout_path" 2>"$stderr_path"
  local status="$?"
  set -e
  if [ "$status" = "0" ]; then
    echo "Phase 14 stack-slot negative unexpectedly passed: $context" >&2
    exit 1
  fi
  rg -n -F 'gust_backend_request_failure:' "$stderr_path" >/dev/null
  rg -n -F "$reason_code" "$stderr_path" >/dev/null
}

for target in "${targets[@]}"; do
  case_dir="$build_root/$target"
  request_path="$case_dir/stack-slots.request"
  expected="$case_dir/expected.witness"
  c_source="$case_dir/mir-to-c-stack-slots.c"
  for generated in "$request_path" "$expected" "$c_source"; do
    if [ ! -f "$generated" ] || [ -L "$generated" ]; then
      echo "Missing generated Phase 14 stack-slot artifact: $generated" >&2
      exit 1
    fi
  done

  "$driver" phase14-stack-slot-witness "$request_path" \
    >"$case_dir/cranelift.witness" 2>"$case_dir/cranelift.stderr"
  if [ -s "$case_dir/cranelift.stderr" ]; then
    cat "$case_dir/cranelift.stderr" >&2
    exit 1
  fi
  cmp -s "$expected" "$case_dir/cranelift.witness" || {
    diff -u "$expected" "$case_dir/cranelift.witness" >&2 || true
    echo "Cranelift stack-slot witness differs for $target." >&2
    exit 1
  }

  if [ "$target" = "$primary_target" ]; then
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$c_source" -o "$case_dir/mir-to-c-stack-slots"
    "$case_dir/mir-to-c-stack-slots" \
      >"$case_dir/mir-to-c.witness" 2>"$case_dir/mir-to-c.stderr"
    if [ -s "$case_dir/mir-to-c.stderr" ]; then
      cat "$case_dir/mir-to-c.stderr" >&2
      exit 1
    fi
    cmp -s "$expected" "$case_dir/mir-to-c.witness" || {
      diff -u "$expected" "$case_dir/mir-to-c.witness" >&2 || true
      echo "MIR-to-C stack-slot witness differs for $target." >&2
      exit 1
    }
  fi

  python3 - "$request_path" "$case_dir/uninitialized.request" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
s=s.replace('stack_slot_operation_4_kind: read\n','stack_slot_operation_4_kind: uninitialized_read\n',1)
Path(sys.argv[2]).write_text(s)
PY
  expect_worker_failure "$case_dir/uninitialized.request" "$target uninitialized read" "$case_dir/uninitialized.stdout" "$case_dir/uninitialized.stderr" "stack_slot_uninitialized_read"

  python3 - "$request_path" "$case_dir/duplicate.request" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
a=next(x for x in s.splitlines() if x.startswith('stack_slot_0_id: ')).split(': ',1)[1]
b=next(x for x in s.splitlines() if x.startswith('stack_slot_1_id: ')).split(': ',1)[1]
s=s.replace(f'stack_slot_1_id: {b}\n',f'stack_slot_1_id: {a}\n',1)
Path(sys.argv[2]).write_text(s)
PY
  expect_worker_failure "$case_dir/duplicate.request" "$target duplicate slot" "$case_dir/duplicate.stdout" "$case_dir/duplicate.stderr" "stack_slot_duplicate_identity"

  python3 - "$request_path" "$case_dir/wrong-type.request" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text().replace('stack_slot_0_contained_type_id: type:gust:i32\n','stack_slot_0_contained_type_id: type:gust:u64\n',1)
Path(sys.argv[2]).write_text(s)
PY
  expect_worker_failure "$case_dir/wrong-type.request" "$target wrong slot type" "$case_dir/wrong-type.stdout" "$case_dir/wrong-type.stderr" "stack_slot_type_mismatch"

  python3 - "$request_path" "$case_dir/under-aligned.request" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text().replace('stack_slot_0_alignment: 4\n','stack_slot_0_alignment: 1\n',1)
Path(sys.argv[2]).write_text(s)
PY
  expect_worker_failure "$case_dir/under-aligned.request" "$target under-aligned slot" "$case_dir/under-aligned.stdout" "$case_dir/under-aligned.stderr" "stack_slot_under_aligned"

  python3 - "$request_path" "$case_dir/lifetime.request" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text().replace('stack_slot_0_lifetime_region: function:main:block:0-3\n','stack_slot_0_lifetime_region: \n',1)
Path(sys.argv[2]).write_text(s)
PY
  expect_worker_failure "$case_dir/lifetime.request" "$target invalid lifetime" "$case_dir/lifetime.stdout" "$case_dir/lifetime.stderr" "stack_slot_lifetime_invalid"

  python3 - "$request_path" "$case_dir/escape.request" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text().replace('stack_slot_address_escape_policy: no_escape_outside_declared_lifetime\n','stack_slot_address_escape_policy: escape_to_caller\n',1)
Path(sys.argv[2]).write_text(s)
PY
  expect_worker_failure "$case_dir/escape.request" "$target escaping address" "$case_dir/escape.stdout" "$case_dir/escape.stderr" "stack_slot_address_escape_unsupported"

  python3 - "$request_path" "$case_dir/layout-id.request" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
old=next(x for x in s.splitlines() if x.startswith('stack_slot_0_contained_layout_id: '))+'\n'
s=s.replace(old,'stack_slot_0_contained_layout_id: layout:missing\n',1)
Path(sys.argv[2]).write_text(s)
PY
  expect_worker_failure "$case_dir/layout-id.request" "$target layout ID mismatch" "$case_dir/layout-id.stdout" "$case_dir/layout-id.stderr" "stack_slot_layout_id_mismatch"

  for unsupported_kind in dynamic_stack_allocation variable_sized_slot resource_bearing_local unsupported_aliasing; do
    python3 - "$request_path" "$case_dir/${unsupported_kind}.request" "$unsupported_kind" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text().replace('stack_slot_operation_0_kind: declare\n',f'stack_slot_operation_0_kind: {sys.argv[3]}\n',1)
Path(sys.argv[2]).write_text(s)
PY
    case "$unsupported_kind" in
      dynamic_stack_allocation) reason_code="stack_slot_dynamic_allocation_unsupported" ;;
      variable_sized_slot) reason_code="stack_slot_variable_size_unsupported" ;;
      resource_bearing_local) reason_code="stack_slot_resource_destructor_deferred" ;;
      unsupported_aliasing) reason_code="stack_slot_aliasing_unsupported" ;;
    esac
    expect_worker_failure "$case_dir/${unsupported_kind}.request" "$target unsupported $unsupported_kind" "$case_dir/${unsupported_kind}.stdout" "$case_dir/${unsupported_kind}.stderr" "$reason_code"
  done

  echo "✅ Phase 14 stack-slot parity passed: $target"
done

if [ "$all_targets" = "1" ]; then
  echo "✅ Phase 14 stack-slot all-target parity passed: targets=${#targets[@]}"
else
  echo "✅ Phase 14 stack-slot focused parity passed: target=$primary_target"
fi