#!/usr/bin/env bash
set -euo pipefail

validator="scripts/cranelift_registry.py"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
build_root="build/guards/phase14_pointer"
cargo_target="$build_root/cargo-target"
all_targets="${PHASE14_POINTER_ALL_TARGETS:-0}"

for required_file in \
  "$validator" "$rust_manifest" \
  compiler/mir_pointer.gst \
  compiler/mir_pointer_mir_to_c.gst \
  compiler/mir_pointer_smoke_test_entry.gst \
  ./gust
do
  if [ ! -e "$required_file" ]; then
    echo "Phase 14 pointer differential is missing $required_file" >&2
    exit 1
  fi
done
if [ ! -x ./gust ]; then
  echo "Phase 14 pointer differential requires the rebuilt ./gust compiler." >&2
  exit 1
fi

rm -rf "$build_root"
mkdir -p "$build_root"
while IFS= read -r target; do
  [ -n "$target" ] || continue
  mkdir -p "$build_root/$target"
done < <(python3 "$validator" phase14-pointer-targets)

just guard compiler/mir_pointer_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 14 bounded typed pointers and nullability' to.log >/dev/null

CARGO_TARGET_DIR="$cargo_target" cargo build \
  --locked \
  --quiet \
  --manifest-path "$rust_manifest"
driver="$cargo_target/debug/gust-cranelift-experiment"
if [ ! -x "$driver" ]; then
  echo "Phase 14 pointer differential did not build $driver" >&2
  exit 1
fi

primary_target="$(python3 "$validator" phase14-pointer-primary-target)"
if [ "$all_targets" = "1" ]; then
  mapfile -t targets < <(python3 "$validator" phase14-pointer-targets)
else
  targets=("$primary_target")
fi
if [ "${#targets[@]}" = "0" ]; then
  echo "Phase 14 pointer differential selected no targets." >&2
  exit 1
fi

expect_worker_failure() {
  local request_path="$1"
  local context="$2"
  local stdout_path="$3"
  local stderr_path="$4"
  set +e
  "$driver" phase14-pointer-witness "$request_path" \
    >"$stdout_path" 2>"$stderr_path"
  local status="$?"
  set -e
  if [ "$status" = "0" ]; then
    echo "Phase 14 pointer negative unexpectedly passed: $context" >&2
    exit 1
  fi
  rg -n -F 'gust_backend_request_failure:' "$stderr_path" >/dev/null
}

for target in "${targets[@]}"; do
  case_dir="$build_root/$target"
  request_path="$case_dir/pointers.request"
  expected="$case_dir/expected.witness"
  c_source="$case_dir/mir-to-c-pointers.c"
  for generated in "$request_path" "$expected" "$c_source"; do
    if [ ! -f "$generated" ] || [ -L "$generated" ]; then
      echo "Missing generated Phase 14 pointer artifact: $generated" >&2
      exit 1
    fi
  done

  "$driver" phase14-pointer-witness "$request_path" \
    >"$case_dir/cranelift.witness" \
    2>"$case_dir/cranelift.stderr"
  if [ -s "$case_dir/cranelift.stderr" ]; then
    cat "$case_dir/cranelift.stderr" >&2
    exit 1
  fi
  if ! cmp -s "$expected" "$case_dir/cranelift.witness"; then
    diff -u "$expected" "$case_dir/cranelift.witness" >&2 || true
    echo "Cranelift pointer witness differs from compiler authority for $target." >&2
    exit 1
  fi

  if [ "$target" = "$primary_target" ]; then
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$c_source" -o "$case_dir/mir-to-c-pointers"
    "$case_dir/mir-to-c-pointers" \
      >"$case_dir/mir-to-c.witness" \
      2>"$case_dir/mir-to-c.stderr"
    if [ -s "$case_dir/mir-to-c.stderr" ]; then
      cat "$case_dir/mir-to-c.stderr" >&2
      exit 1
    fi
    if ! cmp -s "$expected" "$case_dir/mir-to-c.witness"; then
      diff -u "$expected" "$case_dir/mir-to-c.witness" >&2 || true
      echo "MIR-to-C pointer witness differs from compiler authority for $target." >&2
      exit 1
    fi
  fi

  python3 - "$request_path" "$case_dir/width-mismatch.request" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text(encoding="utf-8")
old = next(line for line in source.splitlines() if line.startswith("pointer_type_0_pointer_size: ")) + "\n"
value = int(old.split(": ", 1)[1])
Path(sys.argv[2]).write_text(
    source.replace(old, f"pointer_type_0_pointer_size: {value + 1}\n", 1),
    encoding="utf-8",
)
PY
  expect_worker_failure "$case_dir/width-mismatch.request" \
    "$target pointer width mismatch" \
    "$case_dir/width-mismatch.stdout" \
    "$case_dir/width-mismatch.stderr"

  python3 - "$request_path" "$case_dir/pointee-layout.request" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text(encoding="utf-8")
old = next(line for line in source.splitlines() if line.startswith("pointer_type_0_pointee_layout_id: ")) + "\n"
Path(sys.argv[2]).write_text(
    source.replace(old, "pointer_type_0_pointee_layout_id: layout:missing\n", 1),
    encoding="utf-8",
)
PY
  expect_worker_failure "$case_dir/pointee-layout.request" \
    "$target invalid pointee layout" \
    "$case_dir/pointee-layout.stdout" \
    "$case_dir/pointee-layout.stderr"

  python3 - "$request_path" "$case_dir/nullability.request" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text(encoding="utf-8")
old = "pointer_type_0_nullability: non_null\n"
if source.count(old) != 1:
    raise SystemExit("expected one first non-null pointer type")
Path(sys.argv[2]).write_text(
    source.replace(old, "pointer_type_0_nullability: maybe_null\n", 1),
    encoding="utf-8",
)
PY
  expect_worker_failure "$case_dir/nullability.request" \
    "$target invalid nullability" \
    "$case_dir/nullability.stdout" \
    "$case_dir/nullability.stderr"

  python3 - "$request_path" "$case_dir/address-space.request" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text(encoding="utf-8")
old = "pointer_default_address_space: default\n"
if source.count(old) != 1:
    raise SystemExit("expected one default address space")
Path(sys.argv[2]).write_text(
    source.replace(old, "pointer_default_address_space: address_space:1\n", 1),
    encoding="utf-8",
)
PY
  expect_worker_failure "$case_dir/address-space.request" \
    "$target unsupported address space" \
    "$case_dir/address-space.stdout" \
    "$case_dir/address-space.stderr"

  for unsupported_kind in pointer_arithmetic pointer_to_integer dereference; do
    output_request="$case_dir/${unsupported_kind}.request"
    python3 - "$request_path" "$output_request" "$unsupported_kind" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text(encoding="utf-8")
old = "pointer_operation_0_kind: address_of_local\n"
if source.count(old) != 1:
    raise SystemExit("expected one address-of operation")
Path(sys.argv[2]).write_text(
    source.replace(old, f"pointer_operation_0_kind: {sys.argv[3]}\n", 1),
    encoding="utf-8",
)
PY
    expect_worker_failure "$output_request" \
      "$target unsupported $unsupported_kind" \
      "$case_dir/${unsupported_kind}.stdout" \
      "$case_dir/${unsupported_kind}.stderr"
  done

  python3 - "$request_path" "$case_dir/unsized-pointee.request" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text(encoding="utf-8")
old = "pointer_type_0_pointee_type_id: type:gust:i32\n"
if source.count(old) != 1:
    raise SystemExit("expected one first i32 pointee")
Path(sys.argv[2]).write_text(
    source.replace(old, "pointer_type_0_pointee_type_id: type:gust:slice:i32\n", 1),
    encoding="utf-8",
)
PY
  expect_worker_failure "$case_dir/unsized-pointee.request" \
    "$target unsupported unsized pointee" \
    "$case_dir/unsized-pointee.stdout" \
    "$case_dir/unsized-pointee.stderr"

  python3 - "$request_path" "$case_dir/target-disagreement.request" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text(encoding="utf-8")
old = next(line for line in source.splitlines() if line.startswith("pointer_target_triple: ")) + "\n"
Path(sys.argv[2]).write_text(
    source.replace(old, "pointer_target_triple: phase14-mismatched-target\n", 1),
    encoding="utf-8",
)
PY
  expect_worker_failure "$case_dir/target-disagreement.request" \
    "$target request target/pointer disagreement" \
    "$case_dir/target-disagreement.stdout" \
    "$case_dir/target-disagreement.stderr"
  rg -n -F 'stage=target_validation kind=target_mismatch' \
    "$case_dir/target-disagreement.stderr" >/dev/null

  echo "✅ Phase 14 pointer parity passed: $target"
done

if [ "$all_targets" = "1" ]; then
  echo "✅ Phase 14 pointer all-target parity passed: targets=${#targets[@]}"
else
  echo "✅ Phase 14 pointer focused parity passed: target=$primary_target"
fi