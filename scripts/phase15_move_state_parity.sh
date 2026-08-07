#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

build_dir="build/guards/phase15_move_state"
request="/tmp/gust-phase15-move-state.request"
mir_to_c_witness="/tmp/gust-phase15-move-state.mir-to-c.witness"
worker_manifest="compiler/experiments/cranelift/Cargo.toml"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
rm -rf "$build_dir"
rm -f "$request" "$mir_to_c_witness"
mkdir -p "$build_dir"

phase15_move_state_stage="initialization"

phase15_move_state_dump_file() {
  local path="$1"
  if [ ! -f "$path" ]; then
    return
  fi
  echo "::group::Phase 15.3 diagnostic: $path" >&2
  if [ "$(wc -l < "$path" 2>/dev/null || printf '0')" -le 320 ]; then
    cat "$path" >&2
  else
    echo "--- first 80 lines ---" >&2
    head -n 80 "$path" >&2
    echo "--- last 240 lines ---" >&2
    tail -n 240 "$path" >&2
  fi
  echo "::endgroup::" >&2
}

phase15_move_state_on_error() {
  local status="$1"
  local line="$2"
  local command="$3"
  set +e
  echo "❌ Phase 15.3 move-state parity failed." >&2
  echo "stage=$phase15_move_state_stage" >&2
  echo "status=$status line=$line command=$command" >&2
  for path in \
    to.log \
    build/gust-build.log \
    build/mir_resource_move_state_smoke_test_entry.compile.log \
    build/mir_resource_move_parity_smoke_test_entry.compile.log \
    "$build_dir/cargo-build.log" \
    "$build_dir/worker.stderr" \
    "$mir_to_c_witness" \
    "$build_dir/cranelift.witness"
  do
    phase15_move_state_dump_file "$path"
  done
  exit "$status"
}

trap 'phase15_move_state_on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

phase15_move_state_stage="compile and execute the Phase 15.3 transition smoke"
bash scripts/run-gust-file.sh compiler/mir_resource_move_state_smoke_test_entry.gst
phase15_move_state_stage="verify the Phase 15.3 transition smoke success marker"
grep -F 'SUCCESS: Phase 15.3 move-state transitions and diagnostics passed' to.log >/dev/null
phase15_move_state_stage="compile and execute the Phase 15.3 parity smoke"
bash scripts/run-gust-file.sh compiler/mir_resource_move_parity_smoke_test_entry.gst
phase15_move_state_stage="verify the Phase 15.3 parity smoke success marker"
grep -F 'SUCCESS: Phase 15.3 move-state parity smoke passed' to.log >/dev/null

for artifact in "$request" "$mir_to_c_witness"; do
  if [ ! -s "$artifact" ]; then
    echo "Phase 15.3 move-state smoke did not produce $artifact" >&2
    exit 1
  fi
done

phase15_move_state_stage="build the Phase 15.3 Cranelift parity worker"
cargo build --manifest-path "$worker_manifest" >"$build_dir/cargo-build.log" 2>&1
phase15_move_state_stage="generate the Phase 15.3 Cranelift witness"
"$worker" phase15-resource-mir-witness "$request" >"$build_dir/cranelift.witness" 2>"$build_dir/worker.stderr"
phase15_move_state_stage="compare Phase 15.3 MIR-to-C and Cranelift witnesses"
cmp -s "$mir_to_c_witness" "$build_dir/cranelift.witness" || {
  diff -u "$mir_to_c_witness" "$build_dir/cranelift.witness" >&2 || true
  echo "Phase 15.3 MIR-to-C and Cranelift move-state witnesses differ." >&2
  exit 1
}

for token in \
  'resource_lowering: id=operation:move:a:local action=move' \
  'move_form=local_to_local' \
  'resource_lowering: id=operation:read:a:destination action=read' \
  'resource_lowering: id=operation:move:a:field action=move' \
  'move_form=local_to_aggregate_field' \
  'resource_lowering: id=operation:move:a:field_out action=move' \
  'move_form=aggregate_field_to_local' \
  'resource_lowering: id=operation:move:a:branch action=move' \
  'move_form=branch_edge_move' \
  'resource_lowering: id=operation:move:a:loop action=move' \
  'move_form=selected_loop_carried_move' \
  'resource_lowering: id=operation:initialize:b:fresh action=initialize' \
  'resource_edge: id=edge:a:then from=then to=join' \
  'resource_edge: id=edge:a:else from=else to=join' \
  'resource_edge: id=edge:a:loop from=loop_body to=loop_header'
do
  grep -F "$token" "$mir_to_c_witness" >/dev/null
done

mutate() {
  local source="$1"
  local destination="$2"
  local mode="$3"
  python3 - "$source" "$destination" "$mode" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1])
destination = Path(sys.argv[2])
mode = sys.argv[3]
lines = source.read_text().splitlines()


def split_field(line: str):
    if ": " not in line:
        return line, ""
    return line.split(": ", 1)


def set_field(key: str, value: str):
    for index, line in enumerate(lines):
        current, _ = split_field(line)
        if current == key:
            lines[index] = f"{key}: {value}"
            return
    raise SystemExit(f"missing field {key}")


def operation_index(operation_id: str) -> int:
    prefix = "resource_mir_operation_"
    suffix = "_operation_id"
    for line in lines:
        key, value = split_field(line)
        if key.startswith(prefix) and key.endswith(suffix) and value == operation_id:
            return int(key[len(prefix):-len(suffix)])
    raise SystemExit(f"missing operation {operation_id}")


def operation_field(operation_id: str, field: str) -> str:
    return f"resource_mir_operation_{operation_index(operation_id)}_{field}"


def mutate_after_first_move(kind: str, resulting_state: str, destination: str = ""):
    operation_id = "operation:read:a:destination"
    set_field(operation_field(operation_id, "kind"), kind)
    set_field(operation_field(operation_id, "source_carrier_id"), "carrier:a:source")
    set_field(operation_field(operation_id, "destination_carrier_id"), destination)
    set_field(operation_field(operation_id, "prior_state"), "live")
    set_field(operation_field(operation_id, "resulting_state"), resulting_state)


schedule_id = next(
    value for line in lines
    for key, value in [split_field(line)]
    if key.endswith("_cleanup_id") and value
)

if mode == "use-after-move":
    mutate_after_first_move("read", "live")
elif mode == "close-after-move":
    mutate_after_first_move("explicit_close", "manually_closed")
    set_field(operation_field("operation:read:a:destination", "close_capability_id"), "close:phase15:move_resource")
elif mode == "second-move":
    mutate_after_first_move("move", "moved", "carrier:a:field")
elif mode == "cleanup-after-move":
    mutate_after_first_move("schedule_cleanup", "cleanup_scheduled")
    set_field(operation_field("operation:read:a:destination", "cleanup_id"), schedule_id)
    set_field(operation_field("operation:read:a:destination", "destructor_id"), "destructor:phase15:move_resource")
elif mode == "destructor-after-move":
    mutate_after_first_move("invoke_destructor", "destroyed")
    set_field(operation_field("operation:read:a:destination", "cleanup_id"), schedule_id)
    set_field(operation_field("operation:read:a:destination", "destructor_id"), "destructor:phase15:move_resource")
elif mode == "move-from-uninitialized":
    operation_id = "operation:initialize:a"
    set_field(operation_field(operation_id, "kind"), "move")
    set_field(operation_field(operation_id, "source_carrier_id"), "carrier:a:source")
    set_field(operation_field(operation_id, "destination_carrier_id"), "carrier:a:destination")
    set_field(operation_field(operation_id, "prior_state"), "uninitialized")
    set_field(operation_field(operation_id, "resulting_state"), "moved")
elif mode == "copy-after-initialize":
    copy_operation = "operation:move:a:local"
    set_field(operation_field(copy_operation, "kind"), "copy")
    set_field(operation_field(copy_operation, "destination_carrier_id"), "")
    set_field(operation_field(copy_operation, "resulting_state"), "live")
elif mode == "inconsistent-join":
    edge_prefix = None
    for line in lines:
        key, value = split_field(line)
        if key.startswith("resource_mir_edge_") and key.endswith("_edge_id") and value == "edge:a:else":
            edge_prefix = key[:-len("_edge_id")]
            break
    if edge_prefix is None:
        raise SystemExit("missing edge:a:else")
    set_field(f"{edge_prefix}_state", "moved")
    for index, line in enumerate(lines):
        if ";point=a.edge.else;state=live" in line:
            lines[index] = line.replace(";point=a.edge.else;state=live", ";point=a.edge.else;state=moved", 1)
            break
    else:
        raise SystemExit("missing authority edge state")
else:
    raise SystemExit(f"unknown mutation {mode}")

destination.write_text("\n".join(lines) + "\n")
PY
}

expect_move_failure() {
  local request_path="$1"
  local reason="$2"
  local attempted="$3"
  local label="$4"
  phase15_move_state_stage="verify Phase 15.3 negative mutation: $label"
  if "$worker" phase15-resource-mir-witness "$request_path" \
      >"$build_dir/$label.stdout" 2>"$build_dir/$label.stderr"
  then
    echo "Expected Phase 15.3 move-state rejection for $label" >&2
    exit 1
  fi
  grep -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null
  grep -F 'resource_move_diagnostic:' "$build_dir/$label.stderr" >/dev/null
  grep -F 'declaration=' "$build_dir/$label.stderr" >/dev/null
  grep -F 'move_site=' "$build_dir/$label.stderr" >/dev/null
  grep -F 'invalid_use_site=' "$build_dir/$label.stderr" >/dev/null
  grep -F 'prior_state=' "$build_dir/$label.stderr" >/dev/null
  grep -F "attempted_operation=$attempted" "$build_dir/$label.stderr" >/dev/null
}

expect_reason_only() {
  local request_path="$1"
  local reason="$2"
  local label="$3"
  if "$worker" phase15-resource-mir-witness "$request_path" \
      >"$build_dir/$label.stdout" 2>"$build_dir/$label.stderr"
  then
    echo "Expected Phase 15.3 rejection for $label" >&2
    exit 1
  fi
  grep -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null
}

mutate "$request" "$build_dir/use-after-move.request" use-after-move
expect_move_failure "$build_dir/use-after-move.request" resource_use_after_move use use-after-move

mutate "$request" "$build_dir/close-after-move.request" close-after-move
expect_move_failure "$build_dir/close-after-move.request" resource_close_after_move manual_close close-after-move

mutate "$request" "$build_dir/second-move.request" second-move
expect_move_failure "$build_dir/second-move.request" resource_second_move move second-move

mutate "$request" "$build_dir/cleanup-after-move.request" cleanup-after-move
expect_move_failure "$build_dir/cleanup-after-move.request" resource_cleanup_after_move schedule_cleanup cleanup-after-move

mutate "$request" "$build_dir/destructor-after-move.request" destructor-after-move
expect_move_failure "$build_dir/destructor-after-move.request" resource_destructor_after_move invoke_destructor destructor-after-move

mutate "$request" "$build_dir/move-from-uninitialized.request" move-from-uninitialized
expect_move_failure "$build_dir/move-from-uninitialized.request" resource_move_from_uninitialized move move-from-uninitialized

mutate "$request" "$build_dir/copy-after-initialize.request" copy-after-initialize
expect_move_failure "$build_dir/copy-after-initialize.request" resource_copy_of_move_only copy copy-after-initialize

mutate "$request" "$build_dir/inconsistent-join.request" inconsistent-join
expect_move_failure "$build_dir/inconsistent-join.request" resource_move_join_state_inconsistent join_states inconsistent-join

poison_marker="$build_dir/poison-driver-invoked"
poison_driver="$build_dir/poison-driver"
cat >"$poison_driver" <<'EOF_POISON'
#!/usr/bin/env bash
set -euo pipefail
printf 'invoked\n' >>"${GUST_PHASE15_MOVE_POISON_MARKER:?}"
exit 97
EOF_POISON
chmod +x "$poison_driver"
poison_driver_abs="$(cd "$(dirname "$poison_driver")" && pwd)/$(basename "$poison_driver")"
protected_output="$build_dir/protected-output"
printf 'phase15-move-state-output-sentinel\n' >"$protected_output"
cp "$protected_output" "$protected_output.expected"
rm -f "$poison_marker" "$protected_output.phase10.bundle" "$protected_output.phase10.request"
phase15_move_state_stage="verify source-level use-after-move rejection before backend driver discovery"
set +e
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
GUST_PHASE15_MOVE_POISON_MARKER="$poison_marker" \
GUST_NATIVE_BACKEND_DRIVER="$poison_driver_abs" \
  ./gust --backend cranelift \
    -o "$protected_output" \
    tests/test_handoff_use_after_move_rejected.gst \
    >"$build_dir/compiler.stdout" \
    2>"$build_dir/compiler.stderr"
compiler_status="$?"
set -e
if [ "$compiler_status" = "0" ]; then
  echo "Phase 15.3 source use-after-move unexpectedly compiled." >&2
  exit 1
fi
cat "$build_dir/compiler.stdout" "$build_dir/compiler.stderr" >"$build_dir/compiler.combined"
grep -F 'Use of moved variable' "$build_dir/compiler.combined" >/dev/null
if [ -e "$poison_marker" ]; then
  cat "$poison_marker" >&2
  echo "Phase 15.3 use-after-move reached poisoned driver discovery." >&2
  exit 1
fi
cmp -s "$protected_output.expected" "$protected_output"
test ! -e "$protected_output.phase10.bundle"
test ! -e "$protected_output.phase10.request"

if find "$build_dir" -maxdepth 1 -type f \
    \( -name '*.o' -o -name '*.bundle' -o -name '*.tmp' \) \
    -print -quit | grep -q .
then
  echo "Phase 15.3 invalid move created worker or object artifacts." >&2
  exit 1
fi

echo "guard-cranelift-phase15-move-state-parity: ok (Level 2)"
