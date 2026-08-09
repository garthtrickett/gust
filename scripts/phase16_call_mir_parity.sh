#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

build_dir="build/guards/phase16_call_mir"
request="/tmp/gust-phase16-call-mir.request"
mir_to_c_witness="/tmp/gust-phase16-call-mir.mir-to-c.witness"
worker_manifest="compiler/experiments/cranelift/Cargo.toml"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"

stage="compile and execute the compiler-owned call fixture"
on_error() {
  local status="$1" line="$2" command="$3"
  set +e
  echo "Phase 16.2 call MIR parity failed: stage=$stage status=$status line=$line command=$command" >&2
  for path in to.log build/gust-build.log build/mir_function_call_smoke_test_entry.compile.log "$build_dir/cargo-build.log" "$build_dir/cranelift.witness"; do
    if [ -f "$path" ]; then tail -n 160 "$path" >&2; fi
  done
  exit "$status"
}
trap 'on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

bash scripts/run-gust-file.sh compiler/mir_function_call_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 16.2 canonical call MIR smoke passed' to.log >/dev/null
test -s "$request"
test -s "$mir_to_c_witness"

stage="build the Cranelift call-MIR consumer"
cargo build --manifest-path "$worker_manifest" >"$build_dir/cargo-build.log" 2>&1

stage="compare MIR-to-C and Cranelift normalized call witnesses"
"$worker" phase16-call-mir-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c_witness" "$build_dir/cranelift.witness" || {
  diff -u "$mir_to_c_witness" "$build_dir/cranelift.witness" >&2 || true
  false
}

for token in \
  'action=function_abi_declaration' \
  'action=argument_materialization' \
  'action=direct_call' \
  'action=result_extraction' \
  'action=hidden_argument' \
  'action=hidden_result_storage' \
  'action=post_call_normalization' \
  'arguments=abi_placement:v1:phase16:add:param:0,abi_placement:v1:phase16:add:param:1' \
  'results=abi_placement:v1:phase16:add:result:0'
do
  rg -n -F "$token" "$build_dir/cranelift.witness" >/dev/null
done

reject_mutation() {
  local label="$1" reason="$2" expression="$3"
  local mutated="$build_dir/$label.request"
  local output="$build_dir/$label.output"
  local temporary="$output.tmp"
  cp "$request" "$mutated"
  sed -i "$expression" "$mutated"
  printf 'sentinel: preserve-existing-output\n' >"$output"
  if "$worker" phase16-call-mir-witness "$mutated" >"$temporary" 2>"$build_dir/$label.stderr"; then
    echo "mutation unexpectedly succeeded: $label" >&2
    false
  fi
  rg -n -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null
  rg -n -F 'sentinel: preserve-existing-output' "$output" >/dev/null
}

stage="reject malformed call metadata before output replacement"
reject_mutation unknown-abi call_mir_missing_abi_metadata 's/callee_abi=function_abi:v1:phase16:add/callee_abi=function_abi:v1:phase16:missing/'
reject_mutation argument-order call_mir_argument_count_or_order_mismatch '/^call_operation:/ s/arguments=abi_placement:v1:phase16:add:param:0,abi_placement:v1:phase16:add:param:1/arguments=abi_placement:v1:phase16:add:param:1,abi_placement:v1:phase16:add:param:0/'
reject_mutation result-count call_mir_result_count_mismatch '/^call_operation:/ s/results=abi_placement:v1:phase16:add:result:0/results=/'
reject_mutation hidden-value call_mir_unknown_hidden_value 's/input=operand:phase16:hidden-result/input=operand:phase16:missing-hidden/'
reject_mutation calling-convention call_mir_unsupported_calling_convention 's/cc=gust/cc=cdecl/'
reject_mutation target call_mir_target_mismatch 's/target=target:x86_64-unknown-linux-gnu/target=target:aarch64-unknown-linux-gnu/'

echo "guard-cranelift-phase16-call-mir-parity: ok (Level 2)"
