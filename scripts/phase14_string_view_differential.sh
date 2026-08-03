#!/usr/bin/env bash
set -euo pipefail

validator="scripts/cranelift_registry.py"
rust_manifest="compiler/experiments/cranelift/Cargo.toml"
build_root="build/guards/phase14_string_view"
cargo_target="$build_root/cargo-target"
all_targets="${PHASE14_STRING_VIEW_ALL_TARGETS:-${PHASE14_ALL_TARGETS:-0}}"

for required_file in \
  "$validator" "$rust_manifest" \
  compiler/mir_string_view.gst \
  compiler/mir_string_view_mir_to_c.gst \
  compiler/mir_string_view_smoke_test_entry.gst \
  ./gust
do
  if [ ! -e "$required_file" ]; then
    echo "Phase 14 string-view differential is missing $required_file" >&2
    exit 1
  fi
done
if [ ! -x ./gust ]; then
  echo "Phase 14 string-view differential requires the rebuilt ./gust compiler." >&2
  exit 1
fi

rm -rf "$build_root"
mkdir -p "$build_root"
while IFS= read -r target; do
  [ -n "$target" ] || continue
  mkdir -p "$build_root/$target"
done < <(python3 "$validator" phase14-string-view-targets)

just guard compiler/mir_string_view_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 14 string literals and borrowed views' to.log >/dev/null

CARGO_TARGET_DIR="$cargo_target" cargo build \
  --locked --quiet --manifest-path "$rust_manifest"
driver="$cargo_target/debug/gust-cranelift-experiment"
if [ ! -x "$driver" ]; then
  echo "Phase 14 string-view differential did not build $driver" >&2
  exit 1
fi

source scripts/phase14_target_selection.sh
phase14_select_targets \
  "$validator" \
  "phase14-string-view-targets" \
  "phase14-string-view-primary-target" \
  "$all_targets"

poison_marker="$build_root/poison-driver-invoked"
poison_driver="$build_root/poison-driver"
cat >"$poison_driver" <<'EOF_POISON'
#!/usr/bin/env bash
set -euo pipefail
printf 'invoked\n' >>"${GUST_PHASE14_STRING_VIEW_POISON_MARKER:?}"
exit 97
EOF_POISON
chmod +x "$poison_driver"
poison_driver_abs="$(cd "$(dirname "$poison_driver")" && pwd)/$(basename "$poison_driver")"

mutate_request() {
  local input="$1"
  local output="$2"
  local old="$3"
  local new="$4"
  python3 - "$input" "$output" "$old" "$new" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
old = sys.argv[3].replace('\\n', '\n')
new = sys.argv[4].replace('\\n', '\n')
if old not in source:
    raise SystemExit(f"missing mutation token: {old!r}")
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
  printf 'phase14-string-view-output-sentinel\n' >"$protected_output"
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
  GUST_PHASE14_STRING_VIEW_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$poison_driver_abs" \
    "$driver" phase14-string-view-witness "$request_path" \
      >"$case_dir/worker.stdout" 2>"$case_dir/worker.stderr"
  local status="$?"
  set -e
  if [ "$status" = "0" ]; then
    echo "Phase 14 string-view negative unexpectedly passed: $context" >&2
    exit 1
  fi
  rg -n -F 'gust_backend_request_failure:' "$case_dir/worker.stderr" >/dev/null
  rg -n -F "$reason_code" "$case_dir/worker.stderr" >/dev/null
  if [ -e "$poison_marker" ]; then
    cat "$poison_marker" >&2
    echo "Invalid Phase 14 string view reached poisoned driver discovery: $context" >&2
    exit 1
  fi
  cmp -s "$protected_output.expected" "$protected_output"
  if find "$case_dir" -maxdepth 1 -type f \
      \( -name '*.o' -o -name '*.bundle' -o -name '*.tmp' \) \
      -print -quit | grep -q .
  then
    echo "Invalid Phase 14 string view created transient artifacts: $context" >&2
    exit 1
  fi
}

for target in "${targets[@]}"; do
  case_dir="$build_root/$target"
  request_path="$case_dir/string-views.request"
  expected="$case_dir/expected.witness"
  c_source="$case_dir/mir-to-c-string-views.c"
  for generated in "$request_path" "$expected" "$c_source"; do
    if [ ! -f "$generated" ] || [ -L "$generated" ]; then
      echo "Missing generated Phase 14 string-view artifact: $generated" >&2
      exit 1
    fi
  done

  "$driver" phase14-string-view-witness "$request_path" \
    >"$case_dir/cranelift.witness" 2>"$case_dir/cranelift.stderr"
  if [ -s "$case_dir/cranelift.stderr" ]; then
    cat "$case_dir/cranelift.stderr" >&2
    exit 1
  fi
  cmp -s "$expected" "$case_dir/cranelift.witness" || {
    diff -u "$expected" "$case_dir/cranelift.witness" >&2 || true
    echo "Cranelift string-view witness differs for $target." >&2
    exit 1
  }

  if [ "$target" = "$primary_target" ]; then
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$c_source" -o "$case_dir/mir-to-c-string-views"
    "$case_dir/mir-to-c-string-views" \
      >"$case_dir/mir-to-c.witness" 2>"$case_dir/mir-to-c.stderr"
    if [ -s "$case_dir/mir-to-c.stderr" ]; then
      cat "$case_dir/mir-to-c.stderr" >&2
      exit 1
    fi
    cmp -s "$expected" "$case_dir/mir-to-c.witness" || {
      diff -u "$expected" "$case_dir/mir-to-c.witness" >&2 || true
      echo "MIR-to-C string-view witness differs for $target." >&2
      exit 1
    }
    rg -n -F 'string_literal: string_literal:v1:encoding=utf8:bytes=610062' "$expected" >/dev/null
    rg -n -F 'string_operation: byte_at_embedded_nul_1 kind=byte_at status=success value=0' "$expected" >/dev/null
  fi

  mutate_request "$request_path" "$case_dir/null-nonempty.request" \
    'string_view_view_1_data_known_null: 0\n' \
    'string_view_view_1_data_known_null: 1\n'
  expect_worker_failure "$case_dir/null-nonempty.request" "$target invalid pointer/length pair" "$case_dir/negative-null-nonempty" "string_view_null_nonempty"

  mutate_request "$request_path" "$case_dir/lifetime-escape.request" \
    'string_view_view_1_lifetime_region: static_program\n' \
    'string_view_view_1_lifetime_region: function:main\n'
  expect_worker_failure "$case_dir/lifetime-escape.request" "$target lifetime escape" "$case_dir/negative-lifetime" "string_view_lifetime_escape"

  mutate_request "$request_path" "$case_dir/mutation.request" \
    'string_view_operation_0_kind: literal_create\n' \
    'string_view_operation_0_kind: mutation\n'
  expect_worker_failure "$case_dir/mutation.request" "$target unsupported mutation" "$case_dir/negative-mutation" "string_mutation_unsupported"

  mutate_request "$request_path" "$case_dir/allocation.request" \
    'string_view_operation_0_kind: literal_create\n' \
    'string_view_operation_0_kind: allocation\n'
  expect_worker_failure "$case_dir/allocation.request" "$target unsupported allocation" "$case_dir/negative-allocation" "string_allocation_unsupported"

  mutate_request "$request_path" "$case_dir/concatenation.request" \
    'string_view_operation_0_kind: literal_create\n' \
    'string_view_operation_0_kind: concatenation\n'
  expect_worker_failure "$case_dir/concatenation.request" "$target unsupported concatenation" "$case_dir/negative-concatenation" "string_concatenation_unsupported"

  mutate_request "$request_path" "$case_dir/encoding.request" \
    'string_view_source_encoding: utf8\n' \
    'string_view_source_encoding: utf16\n'
  expect_worker_failure "$case_dir/encoding.request" "$target invalid encoding" "$case_dir/negative-encoding" "string_encoding_invalid"

  mutate_request "$request_path" "$case_dir/out-of-bounds.request" \
    'string_view_view_1_length: 4\n' \
    'string_view_view_1_length: 5\n'
  expect_worker_failure "$case_dir/out-of-bounds.request" "$target out-of-bounds view" "$case_dir/negative-bounds" "string_view_out_of_bounds"

  mutate_request "$request_path" "$case_dir/null-empty.request" \
    'string_view_view_0_data_known_null: 0\n' \
    'string_view_view_0_data_known_null: 1\n'
  expect_worker_failure "$case_dir/null-empty.request" "$target null empty view" "$case_dir/negative-null-empty" "string_view_empty_pointer_must_be_non_null"

  mutate_request "$request_path" "$case_dir/literal-identity.request" \
    'string_view_literal_1_id: string_literal:v1:encoding=utf8:bytes=67757374\n' \
    'string_view_literal_1_id: string_literal:v1:encoding=utf8:bytes=67757375\n'
  expect_worker_failure "$case_dir/literal-identity.request" "$target literal identity mismatch" "$case_dir/negative-literal-identity" "string_literal_identity_mismatch"

  echo "✅ Phase 14 string-view parity passed: $target"
done

if [ "$all_targets" = "1" ]; then
  echo "✅ Phase 14 string-view all-target parity passed: targets=${#targets[@]}"
else
  echo "✅ Phase 14 string-view focused parity passed: target=$primary_target"
fi
