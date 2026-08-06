#!/usr/bin/env bash
set -euo pipefail

request="/tmp/gust-phase15-scope-exit-cleanup.request"
mir_to_c_witness="/tmp/gust-phase15-scope-exit-cleanup.mir-to-c.witness"
build_dir="build/guards/phase15_scope_exit_cleanup"
worker_manifest="compiler/experiments/cranelift/Cargo.toml"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"

rm -rf "$build_dir"
rm -f "$request" "$mir_to_c_witness"
mkdir -p "$build_dir"

bash scripts/run-gust-file.sh compiler/mir_scope_exit_cleanup_state_smoke_test_entry.gst
grep -F 'SUCCESS: Phase 15.5 scope-exit cleanup state policy passed' to.log >/dev/null

bash scripts/run-gust-file.sh compiler/mir_scope_exit_cleanup_parity_smoke_test_entry.gst
grep -F 'SUCCESS: Phase 15.5 normal scope-exit cleanup parity smoke passed' to.log >/dev/null

for artifact in "$request" "$mir_to_c_witness"; do
  test -s "$artifact" || { echo "Phase 15.5 fixture did not produce $artifact" >&2; exit 1; }
done

cargo build --quiet --manifest-path "$worker_manifest"
"$worker" phase15-scope-exit-cleanup-witness "$request" >"$build_dir/cranelift.full.witness"

grep '^scope_exit_cleanup' "$mir_to_c_witness" >"$build_dir/mir-to-c.scope-exit.witness"
grep '^scope_exit_cleanup' "$build_dir/cranelift.full.witness" >"$build_dir/cranelift.scope-exit.witness"

if ! diff -u "$build_dir/mir-to-c.scope-exit.witness" "$build_dir/cranelift.scope-exit.witness"; then
  echo "Phase 15.5 MIR-to-C and Cranelift scope-exit cleanup witnesses differ." >&2
  exit 1
fi

for expected in \
  'scope_exit_cleanup_witness: accepted order_policy=reverse_declaration_order' \
  'scope_exit_cleanup_lowering_witness: accepted' \
  'scope=scope:phase15:scope-exit:block' \
  'scope=scope:phase15:scope-exit:nested' \
  'scope=scope:phase15:scope-exit:function' \
  'order=1 declaration_order=2' \
  'order=2 declaration_order=1' \
  'order=3 declaration_order=1' \
  'order=4 declaration_order=2' \
  'order=5 declaration_order=1' \
  'runtime_symbol=gust_phase15_scope_exit_resource_destroy' \
  'state=moved reason=moved_resource' \
  'state=manually_closed reason=manually_closed_resource' \
  'state=destroyed reason=already_destroyed_resource'
do
  grep -F "$expected" "$build_dir/cranelift.scope-exit.witness" >/dev/null
done

cp "$request" "$build_dir/base.request"

mutate_request() {
  local mutation="$1"
  local output="$2"
  python3 - "$build_dir/base.request" "$output" "$mutation" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
output = Path(sys.argv[2])
mutation = sys.argv[3]

def value(key: str) -> str:
    prefix = key + ": "
    for line in source.splitlines():
        if line.startswith(prefix):
            return line[len(prefix):]
    raise SystemExit(f"missing field {key}")

def replace(key: str, new: str) -> None:
    global source
    old = f"{key}: {value(key)}"
    source = source.replace(old, f"{key}: {new}", 1)

if mutation == "duplicate-insertion":
    replace(
        "scope_exit_cleanup_entry_1_cleanup_operation_id",
        value("scope_exit_cleanup_entry_0_cleanup_operation_id"),
    )
elif mutation == "missing-cleanup":
    replace("scope_exit_cleanup_entry_count", "4")
elif mutation == "moved-resource":
    replace("scope_exit_cleanup_entry_0_prior_state", "moved")
elif mutation == "wrong-scope":
    replace(
        "scope_exit_cleanup_entry_0_scope_id",
        "scope:phase15:scope-exit:function",
    )
elif mutation == "bad-order":
    replace("scope_exit_cleanup_entry_0_execution_order", "9")
elif mutation == "bad-destructor":
    replace(
        "scope_exit_cleanup_entry_0_destructor_id",
        "destructor:phase15:wrong",
    )
elif mutation == "missing-operation":
    replace(
        "scope_exit_cleanup_entry_0_cleanup_operation_id",
        "operation:scope-exit:destroy:missing",
    )
else:
    raise SystemExit(f"unknown mutation {mutation}")

output.write_text(source)
PY
}

expect_failure() {
  local mutation="$1"
  local reason="$2"
  local request_path="$build_dir/${mutation}.request"
  local stdout_path="$build_dir/${mutation}.stdout"
  local stderr_path="$build_dir/${mutation}.stderr"
  mutate_request "$mutation" "$request_path"
  if "$worker" phase15-scope-exit-cleanup-witness "$request_path" \
       >"$stdout_path" 2>"$stderr_path"
  then
    echo "Phase 15.5 mutation unexpectedly succeeded: $mutation" >&2
    exit 1
  fi
  grep -F "$reason" "$stderr_path" >/dev/null || {
    echo "Phase 15.5 mutation $mutation did not report $reason" >&2
    cat "$stderr_path" >&2
    exit 1
  }
}

expect_failure duplicate-insertion scope_exit_cleanup_duplicate_insertion
expect_failure missing-cleanup scope_exit_cleanup_live_resource_missing
expect_failure moved-resource scope_exit_cleanup_moved_resource
expect_failure wrong-scope scope_exit_cleanup_wrong_scope
expect_failure bad-order scope_exit_cleanup_order_invalid
expect_failure bad-destructor scope_exit_cleanup_destructor_mismatch
expect_failure missing-operation scope_exit_cleanup_operation_missing

echo "guard-cranelift-phase15-scope-exit-cleanup-parity: ok (Level 2)"