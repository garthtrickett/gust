#!/usr/bin/env bash
set -euo pipefail

validator="scripts/cranelift_registry.py"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
build_root="build/guards/phase14_memory_access"
cargo_target="$build_root/cargo-target"
all_targets="${PHASE14_MEMORY_ACCESS_ALL_TARGETS:-${PHASE14_ALL_TARGETS:-0}}"

for required_file in \
  "$validator" "$rust_manifest" \
  compiler/mir_memory_access.gst \
  compiler/mir_memory_access_mir_to_c.gst \
  compiler/mir_memory_access_smoke_test_entry.gst \
  ./gust
do
  if [ ! -e "$required_file" ]; then
    echo "Phase 14 memory-access differential is missing $required_file" >&2
    exit 1
  fi
done
if [ ! -x ./gust ]; then
  echo "Phase 14 memory-access differential requires the rebuilt ./gust compiler." >&2
  exit 1
fi

rm -rf "$build_root"
mkdir -p "$build_root"
while IFS= read -r target; do
  [ -n "$target" ] || continue
  mkdir -p "$build_root/$target"
done < <(python3 "$validator" phase14-memory-access-targets)

just guard compiler/mir_memory_access_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 14 typed loads, stores, and memory-access validation' to.log >/dev/null

CARGO_TARGET_DIR="$cargo_target" cargo build \
  --locked --quiet --manifest-path "$rust_manifest"
driver="$cargo_target/debug/gust-cranelift-experiment"
if [ ! -x "$driver" ]; then
  echo "Phase 14 memory-access differential did not build $driver" >&2
  exit 1
fi

source scripts/phase14_target_selection.sh
phase14_select_targets \
  "$validator" \
  "phase14-memory-access-targets" \
  "phase14-memory-access-primary-target" \
  "$all_targets"

poison_marker="$build_root/poison-driver-invoked"
poison_driver="$build_root/poison-driver"
cat >"$poison_driver" <<'EOF_POISON'
#!/usr/bin/env bash
set -euo pipefail
printf 'invoked\n' >>"${GUST_PHASE14_MEMORY_ACCESS_POISON_MARKER:?}"
exit 97
EOF_POISON
chmod +x "$poison_driver"
poison_driver_abs="$(cd "$(dirname "$poison_driver")" && pwd)/$(basename "$poison_driver")"

expect_worker_failure() {
  local request_path="$1"
  local context="$2"
  local case_dir="$3"
  local reason_code="$4"
  local protected_output="$case_dir/protected-output"
  mkdir -p "$case_dir"
  printf 'phase14-memory-access-output-sentinel\n' >"$protected_output"
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
  GUST_PHASE14_MEMORY_ACCESS_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$poison_driver_abs" \
    "$driver" phase14-memory-access-witness "$request_path" \
      >"$case_dir/worker.stdout" 2>"$case_dir/worker.stderr"
  local status="$?"
  set -e
  if [ "$status" = "0" ]; then
    echo "Phase 14 memory-access negative unexpectedly passed: $context" >&2
    exit 1
  fi
  rg -n -F 'gust_backend_request_failure:' "$case_dir/worker.stderr" >/dev/null
  rg -n -F "$reason_code" "$case_dir/worker.stderr" >/dev/null
  if [ -e "$poison_marker" ]; then
    cat "$poison_marker" >&2
    echo "Invalid Phase 14 memory access reached poisoned driver discovery: $context" >&2
    exit 1
  fi
  cmp -s "$protected_output.expected" "$protected_output"
  if find "$case_dir" -maxdepth 1 -type f \
      \( -name '*.o' -o -name '*.bundle' -o -name '*.tmp' \) \
      -print -quit | grep -q .
  then
    echo "Invalid Phase 14 memory access created transient artifacts: $context" >&2
    exit 1
  fi
}

for target in "${targets[@]}"; do
  case_dir="$build_root/$target"
  request_path="$case_dir/memory-access.request"
  expected="$case_dir/expected.witness"
  c_source="$case_dir/mir-to-c-memory-access.c"
  for generated in "$request_path" "$expected" "$c_source"; do
    if [ ! -f "$generated" ] || [ -L "$generated" ]; then
      echo "Missing generated Phase 14 memory-access artifact: $generated" >&2
      exit 1
    fi
  done

  "$driver" phase14-memory-access-witness "$request_path" \
    >"$case_dir/cranelift.witness" 2>"$case_dir/cranelift.stderr"
  if [ -s "$case_dir/cranelift.stderr" ]; then
    cat "$case_dir/cranelift.stderr" >&2
    exit 1
  fi
  cmp -s "$expected" "$case_dir/cranelift.witness" || {
    diff -u "$expected" "$case_dir/cranelift.witness" >&2 || true
    echo "Cranelift memory-access witness differs for $target." >&2
    exit 1
  }

  if [ "$target" = "$primary_target" ]; then
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$c_source" -o "$case_dir/mir-to-c-memory-access"
    "$case_dir/mir-to-c-memory-access" \
      >"$case_dir/mir-to-c.witness" 2>"$case_dir/mir-to-c.stderr"
    if [ -s "$case_dir/mir-to-c.stderr" ]; then
      cat "$case_dir/mir-to-c.stderr" >&2
      exit 1
    fi
    cmp -s "$expected" "$case_dir/mir-to-c.witness" || {
      diff -u "$expected" "$case_dir/mir-to-c.witness" >&2 || true
      echo "MIR-to-C memory-access witness differs for $target." >&2
      exit 1
    }
  fi

  python3 - "$request_path" "$case_dir/wrong-width.request" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text().replace('memory_access_operation_0_byte_width: 4\n','memory_access_operation_0_byte_width: 8\n',1)
Path(sys.argv[2]).write_text(s)
PY
  expect_worker_failure "$case_dir/wrong-width.request" "$target wrong width" "$case_dir/negative-wrong-width" "memory_access_width_mismatch"

  python3 - "$request_path" "$case_dir/wrong-alignment.request" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text().replace('memory_access_operation_0_required_alignment: 4\n','memory_access_operation_0_required_alignment: 2\n',1)
Path(sys.argv[2]).write_text(s)
PY
  expect_worker_failure "$case_dir/wrong-alignment.request" "$target wrong alignment" "$case_dir/negative-wrong-alignment" "memory_access_alignment_mismatch"

  python3 - "$request_path" "$case_dir/wrong-pointee.request" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
mutated = source.replace(
    'memory_access_operation_2_accessed_type_id: type:gust:i32\n',
    'memory_access_operation_2_accessed_type_id: type:gust:wrong_pointee\n',
    1,
)
if mutated == source:
    raise SystemExit('missing pointer-origin i32 memory-access operation')
Path(sys.argv[2]).write_text(mutated)
PY
  expect_worker_failure "$case_dir/wrong-pointee.request" "$target wrong pointee type" "$case_dir/negative-wrong-pointee" "memory_access_pointee_type_mismatch"

  python3 - "$request_path" "$case_dir/immutable-store.request" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
s=s.replace('stack_slot_0_mutability: mutable\n','stack_slot_0_mutability: immutable\n',1)
s=s.replace('memory_access_operation_0_origin_mutability: mutable\n','memory_access_operation_0_origin_mutability: immutable\n',1)
Path(sys.argv[2]).write_text(s)
PY
  expect_worker_failure "$case_dir/immutable-store.request" "$target immutable store" "$case_dir/negative-immutable-store" "memory_access_store_immutable"

  python3 - "$request_path" "$case_dir/invalid-layout.request" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
old=next(x for x in s.splitlines() if x.startswith('memory_access_operation_0_accessed_layout_id: '))+'\n'
s=s.replace(old,'memory_access_operation_0_accessed_layout_id: layout:missing\n',1)
Path(sys.argv[2]).write_text(s)
PY
  expect_worker_failure "$case_dir/invalid-layout.request" "$target invalid layout ID" "$case_dir/negative-invalid-layout" "memory_access_layout_id_mismatch"

  python3 - "$request_path" "$case_dir/out-of-lifetime.request" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text().replace('memory_access_operation_0_lifetime_region: function:main:block:0-3\n','memory_access_operation_0_lifetime_region: function:main:block:9-10\n',1)
Path(sys.argv[2]).write_text(s)
PY
  expect_worker_failure "$case_dir/out-of-lifetime.request" "$target out-of-lifetime slot" "$case_dir/negative-out-of-lifetime" "memory_access_out_of_lifetime"

  python3 - "$request_path" "$case_dir/overlap.request" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text().replace('memory_access_operation_5_source_offset: 0\n','memory_access_operation_5_source_offset: 4\n',1)
Path(sys.argv[2]).write_text(s)
PY
  expect_worker_failure "$case_dir/overlap.request" "$target unsupported overlap" "$case_dir/negative-overlap" "memory_access_overlap_unsupported"

  echo "✅ Phase 14 memory-access parity passed: $target"
done

if [ "$all_targets" = "1" ]; then
  echo "✅ Phase 14 memory-access all-target parity passed: targets=${#targets[@]}"
else
  echo "✅ Phase 14 memory-access focused parity passed: target=$primary_target"
fi
