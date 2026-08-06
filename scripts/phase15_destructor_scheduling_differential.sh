#!/usr/bin/env bash
set -euo pipefail

validator="scripts/cranelift_registry.py"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
build_root="build/guards/phase15_destructor_scheduling"
cargo_target="$build_root/cargo-target"
all_targets="${PHASE15_DESTRUCTOR_SCHEDULING_ALL_TARGETS:-0}"

for required_file in \
  "$validator" "$rust_manifest" \
  compiler/mir_destructor_scheduling.gst \
  compiler/mir_destructor_scheduling_mir_to_c.gst \
  compiler/mir_destructor_scheduling_smoke_test_entry.gst \
  ./gust
do
  if [ ! -e "$required_file" ]; then
    echo "Phase 15 destructor scheduling differential is missing $required_file" >&2
    exit 1
  fi
done
if [ ! -x ./gust ]; then
  echo "Phase 15 destructor scheduling differential requires the rebuilt ./gust compiler." >&2
  exit 1
fi

rm -rf "$build_root"
mkdir -p "$build_root"
while IFS= read -r target; do
  [ -n "$target" ] || continue
  mkdir -p "$build_root/$target"
done < <(python3 "$validator" phase15-destructor-scheduling-targets)

just guard compiler/mir_destructor_scheduling_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 15 destructor scheduling and exactly-once destruction' to.log >/dev/null

CARGO_TARGET_DIR="$cargo_target" cargo build \
  --locked --quiet --manifest-path "$rust_manifest"
driver="$cargo_target/debug/gust-cranelift-experiment"
if [ ! -x "$driver" ]; then
  echo "Phase 15 destructor scheduling differential did not build $driver" >&2
  exit 1
fi

primary_target="$(python3 "$validator" phase15-destructor-scheduling-primary-target)"
if [ "$all_targets" = "1" ]; then
  mapfile -t targets < <(python3 "$validator" phase15-destructor-scheduling-targets)
else
  targets=("$primary_target")
fi

poison_marker="$build_root/poison-driver-invoked"
poison_driver="$build_root/poison-driver"
cat >"$poison_driver" <<'EOF_POISON'
#!/usr/bin/env bash
set -euo pipefail
printf 'destructor-scheduling poison driver invoked\n' >"${GUST_PHASE15_DESTRUCTOR_SCHEDULING_POISON_MARKER:?}"
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
  printf 'phase15-destructor-scheduling-output-sentinel\n' >"$protected_output"
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
  GUST_PHASE15_DESTRUCTOR_SCHEDULING_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$poison_driver_abs" \
    "$driver" phase15-destructor-scheduling-witness "$request_path" \
      >"$case_dir/worker.stdout" 2>"$case_dir/worker.stderr"
  local status="$?"
  set -e
  if [ "$status" = "0" ]; then
    echo "Phase 15 destructor scheduling negative unexpectedly passed: $context" >&2
    exit 1
  fi
  rg -n -F 'gust_backend_request_failure:' "$case_dir/worker.stderr" >/dev/null
  rg -n -F "$reason_code" "$case_dir/worker.stderr" >/dev/null
  if [ -e "$poison_marker" ]; then
    cat "$poison_marker" >&2
    echo "Invalid Phase 15 destructor scheduling reached poisoned driver discovery: $context" >&2
    exit 1
  fi
  cmp -s "$protected_output.expected" "$protected_output"
  if find "$case_dir" -maxdepth 1 -type f \
      \( -name '*.o' -o -name '*.bundle' -o -name '*.tmp' \) \
      -print -quit | grep -q .
  then
    echo "Invalid Phase 15 destructor scheduling created transient artifacts: $context" >&2
    exit 1
  fi
}

for target in "${targets[@]}"; do
  case_dir="$build_root/$target"
  request_path="$case_dir/destructor-scheduling.request"
  expected="$case_dir/expected.witness"
  c_source="$case_dir/mir-to-c-destructor-scheduling.c"
  for generated in "$request_path" "$expected" "$c_source"; do
    if [ ! -f "$generated" ] || [ -L "$generated" ]; then
      echo "Missing generated Phase 15 destructor scheduling artifact: $generated" >&2
      exit 1
    fi
  done

  "$driver" phase15-destructor-scheduling-witness "$request_path" \
    >"$case_dir/cranelift.witness" 2>"$case_dir/cranelift.stderr"
  if [ -s "$case_dir/cranelift.stderr" ]; then
    cat "$case_dir/cranelift.stderr" >&2
    exit 1
  fi
  cmp -s "$expected" "$case_dir/cranelift.witness" || {
    diff -u "$expected" "$case_dir/cranelift.witness" >&2 || true
    echo "Cranelift destructor scheduling witness differs for $target." >&2
    exit 1
  }

  if [ "$target" = "$primary_target" ]; then
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$c_source" -o "$case_dir/mir-to-c-destructor-scheduling"
    "$case_dir/mir-to-c-destructor-scheduling" \
      >"$case_dir/mir-to-c.witness" 2>"$case_dir/mir-to-c.stderr"
    if [ -s "$case_dir/mir-to-c.stderr" ]; then
      cat "$case_dir/mir-to-c.stderr" >&2
      exit 1
    fi
    cmp -s "$expected" "$case_dir/mir-to-c.witness" || {
      diff -u "$expected" "$case_dir/mir-to-c.witness" >&2 || true
      echo "MIR-to-C destructor scheduling witness differs for $target." >&2
      exit 1
    }
    rg -n -F 'destructor_operation: execute_log kind=execute_destructor status=success resource=resource_log_handle state=executed schedule_count=1 execution_count=1 order=1' "$expected" >/dev/null
    rg -n -F 'destructor_operation: transfer_net kind=cancel_schedule status=success resource=resource_net_connection state=cancelled schedule_count=0 execution_count=0 order=0' "$expected" >/dev/null
    rg -n -F 'destructor_operation: mark_scratch kind=mark_destroyed status=success resource=resource_temp_scratch state=destroyed schedule_count=1 execution_count=1 order=4' "$expected" >/dev/null
    rg -n -F 'destructor_exactly_once: resource_log_handle status=exactly_once schedule_count=1 execution_count=1 order=1' "$expected" >/dev/null
    rg -n -F 'destructor_exactly_once: resource_net_connection status=exactly_once schedule_count=1 execution_count=1 order=3' "$expected" >/dev/null
  fi

  mutate_request "$request_path" "$case_dir/duplicate-schedule.request" \
    'destructor_operation_5_resource_id: resource_net_connection\n' \
    'destructor_operation_5_resource_id: resource_log_handle\n'
  expect_worker_failure "$case_dir/duplicate-schedule.request" "$target duplicate schedule" "$case_dir/negative-duplicate-schedule" "duplicate_schedule"

  mutate_request "$request_path" "$case_dir/execute-without-schedule.request" \
    'destructor_operation_9_resource_id: resource_temp_scratch\n' \
    'destructor_operation_9_resource_id: resource_config_buffer\n'
  expect_worker_failure "$case_dir/execute-without-schedule.request" "$target execute without schedule" "$case_dir/negative-execute-without-schedule" "execute_without_schedule"

  mutate_request "$request_path" "$case_dir/schedule-after-destruction.request" \
    'destructor_operation_10_kind: mark_destroyed\n' \
    'destructor_operation_10_kind: schedule_destructor\n'
  mutate_request "$case_dir/schedule-after-destruction.request" "$case_dir/schedule-after-destruction.request" \
    ':name=mark_log:kind=mark_destroyed' \
    ':name=mark_log:kind=schedule_destructor'
  expect_worker_failure "$case_dir/schedule-after-destruction.request" "$target schedule after destruction" "$case_dir/negative-schedule-after-destruction" "schedule_after_destruction"

  mutate_request "$request_path" "$case_dir/destructor-mismatch.request" \
    'destructor_operation_7_destructor_id: destructor_free_config\n' \
    'destructor_operation_7_destructor_id: destructor_close_log\n'
  expect_worker_failure "$case_dir/destructor-mismatch.request" "$target destructor mismatch" "$case_dir/negative-destructor-mismatch" "destructor_mismatch"

  mutate_request "$request_path" "$case_dir/skipped-destruction.request" \
    'destructor_operation_9_kind: execute_destructor\n' \
    'destructor_operation_9_kind: mark_destroyed\n'
  mutate_request "$case_dir/skipped-destruction.request" "$case_dir/skipped-destruction.request" \
    ':name=execute_scratch:kind=execute_destructor' \
    ':name=execute_scratch:kind=mark_destroyed'
  expect_worker_failure "$case_dir/skipped-destruction.request" "$target skipped destruction" "$case_dir/negative-skipped-destruction" "skipped_destruction"

  mutate_request "$request_path" "$case_dir/destruction-after-move.request" \
    'destructor_operation_5_kind: schedule_destructor\n' \
    'destructor_operation_5_kind: execute_destructor\n'
  mutate_request "$case_dir/destruction-after-move.request" "$case_dir/destruction-after-move.request" \
    ':name=reschedule_net:kind=schedule_destructor' \
    ':name=reschedule_net:kind=execute_destructor'
  expect_worker_failure "$case_dir/destruction-after-move.request" "$target destruction after move" "$case_dir/negative-destruction-after-move" "destruction_after_move"

  mutate_request "$request_path" "$case_dir/destruction-order-drift.request" \
    'destructor_operation_9_expected_order: 4\n' \
    'destructor_operation_9_expected_order: 1\n'
  expect_worker_failure "$case_dir/destruction-order-drift.request" "$target destruction order drift" "$case_dir/negative-destruction-order-drift" "destruction_order_drift"

  echo "✅ Phase 15 destructor scheduling parity passed: $target"
done

if [ "$all_targets" = "1" ]; then
  echo "✅ Phase 15 destructor scheduling all-target parity passed: targets=${#targets[@]}"
else
  echo "✅ Phase 15 destructor scheduling focused parity passed: target=$primary_target"
fi
