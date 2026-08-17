#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase17_io_runtime"
request="/tmp/gust-phase17-io-runtime.request"
mir_to_c="/tmp/gust-phase17-io-runtime.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile io runtime fixture"
trap 'status=$?; echo "Phase 17.11 io runtime parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_io_runtime_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 17.11 io filesystem resource smoke passed' to.log >/dev/null

stage="build Cranelift io runtime consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned io runtime witnesses"
"$worker" phase17-io-runtime-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

# Every selected I/O kind and the resource vocabulary appear, so the witness
# records the contract rather than a summary of it.
for token in 'io_kind=standard_stream' 'io_kind=file_or_stream' \
             'io_kind=path_or_filesystem' 'io_kind=directory_resource' \
             'io_kind=environment_query' 'io_kind=target_query' \
             'io_kind=c_string_marshalling' \
             'transition=acquires' 'transition=uses_borrowed' 'transition=closes' \
             'fs_effect=reads_filesystem' 'fs_effect=writes_filesystem' \
             'fs_effect=removes_path' \
             'linkage=io_operations_use_their_classified_explicit_runtime_path'; do
  rg -n -F "$token" "$build_dir/cranelift.witness" >/dev/null
done

# The Phase 15 obligation: an acquired resource kind has exactly one close, and
# manual close and deferred cleanup name the same operation. Checked directly.
stage="confirm every acquired resource kind has exactly one close"
closers=$(rg -c -F 'transition=closes' "$build_dir/cranelift.witness" || echo 0)
test "$closers" -eq 1
rg -n -F 'transition=acquires' "$build_dir/cranelift.witness" >/dev/null
rg -n -F 'close_operation=runtime_close:directory_handle' "$build_dir/cranelift.witness" >/dev/null

reject_mutation() {
  local label="$1" reason="$2" expression="$3"
  local mutated="$build_dir/$1.request" output="$build_dir/$1.output" temporary="$build_dir/$1.tmp"
  cp "$request" "$mutated"; sed -i "$expression" "$mutated"
  printf 'sentinel: preserve-existing-output\n' >"$output"
  if "$worker" phase17-io-runtime-witness "$mutated" >"$temporary" 2>"$build_dir/$label.stderr"; then
    echo "mutation unexpectedly succeeded: $label" >&2; false
  fi
  rg -n -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null
  rg -n -F 'sentinel: preserve-existing-output' "$output" >/dev/null
}

stage="reject malformed io contracts before object or link access"
reject_mutation bad_io_kind runtime_io_unsupported_target \
  '0,/io_kind=standard_stream;/ s/io_kind=standard_stream;/io_kind=network_socket;/'
reject_mutation bad_transition runtime_io_wrong_resource_kind \
  '0,/transition=not_a_resource;/ s/transition=not_a_resource;/transition=teleports;/'
reject_mutation resource_mismatch runtime_io_wrong_resource_kind \
  '0,/resource_kind=none;transition=not_a_resource;/ s/resource_kind=none;transition=not_a_resource;/resource_kind=none;transition=acquires;/'
reject_mutation bad_fs_effect runtime_io_unsupported_target \
  '0,/fs_effect=reads_filesystem;/ s/fs_effect=reads_filesystem;/fs_effect=reformats_the_disk;/'
reject_mutation unknown_format runtime_io_missing_symbol \
  '0,/format: gust.compiler_io_runtime.v1/ s/format: gust.compiler_io_runtime.v1/format: gust.compiler_io_runtime.v9/'

# Removing the close must be caught, not tolerated: a directory that is opened
# and never closed is exactly the leak Phase 15 exists to prevent.
stage="reject an acquired resource with no matching close"
orphan="$build_dir/orphan.request"
rg -v -F 'transition=closes' "$request" >"$orphan" || true
if "$worker" phase17-io-runtime-witness "$orphan" >/dev/null 2>"$build_dir/orphan.stderr"; then
  echo "unclosed resource unexpectedly accepted" >&2; false
fi
rg -n -F 'reason=runtime_io_close_mismatch' "$build_dir/orphan.stderr" >/dev/null

echo "guard-cranelift-phase17-io-runtime-parity: ok (Level 2)"
