#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

build_dir="build/guards/phase16_aggregate_parameter"
request="/tmp/gust-phase16-aggregate-parameter.request"
mir_to_c_witness="/tmp/gust-phase16-aggregate-parameter.mir-to-c.witness"
worker_manifest="compiler/experiments/cranelift/Cargo.toml"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"

stage="compile and execute compiler aggregate-parameter fixture"
on_error() {
  local status="$1" line="$2" command="$3"
  set +e
  echo "Phase 16.3 aggregate parameter parity failed: stage=$stage status=$status line=$line command=$command" >&2
  for path in to.log build/gust-build.log build/mir_aggregate_parameter_abi_smoke_test_entry.compile.log "$build_dir/cargo-build.log" "$build_dir/cranelift.witness"; do
    if [ -f "$path" ]; then tail -n 180 "$path" >&2; fi
  done
  exit "$status"
}
trap 'on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

bash scripts/run-gust-file.sh compiler/mir_aggregate_parameter_abi_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 16.3 aggregate parameter ABI smoke passed' to.log >/dev/null
test -s "$request"
test -s "$mir_to_c_witness"

stage="build Cranelift aggregate-parameter consumer"
cargo build --manifest-path "$worker_manifest" >"$build_dir/cargo-build.log" 2>&1

stage="compare MIR-to-C and Cranelift aggregate-parameter witnesses"
"$worker" phase16-aggregate-parameter-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c_witness" "$build_dir/cranelift.witness" || {
  diff -u "$mir_to_c_witness" "$build_dir/cranelift.witness" >&2 || true
  false
}

for token in \
  'shape=struct_single_i32;mode=direct' \
  'shape=struct_pair_i32;mode=split' \
  'shape=struct_triple_i64;mode=indirect_by_value' \
  'initialized=0..4,4..8' \
  'ordinal=1;location=canonical_value:3;offset=4;size=4;align=4;value=17' \
  'ordinal=0;location=caller_owned_readonly_slot:4;offset=0;size=24;align=8;value=19'
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
  if "$worker" phase16-aggregate-parameter-witness "$mutated" >"$temporary" 2>"$build_dir/$label.stderr"; then
    echo "mutation unexpectedly succeeded: $label" >&2
    false
  fi
  rg -n -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null
  rg -n -F 'sentinel: preserve-existing-output' "$output" >/dev/null
}

stage="reject malformed aggregate parameter plans before output replacement"
reject_mutation unsupported aggregate_parameter_unsupported_shape '0,/shape=struct_single_i32/ s/shape=struct_single_i32/shape=struct_unknown/'
reject_mutation layout aggregate_parameter_invalid_layout_identity '0,/layout=layout:v1:type=type:phase16:DirectI32/ s/layout=layout:v1:type=type:phase16:DirectI32/layout=layout:v1:type=type:phase16:MissingDirect/'
reject_mutation split-boundary aggregate_parameter_illegal_split_boundary '/aggregate_parameter_location:.*plan=aggregate_parameter_plan:split;ordinal=1/ s/offset=4/offset=2/'
reject_mutation alignment aggregate_parameter_insufficient_alignment '/aggregate_parameter_location:.*plan=aggregate_parameter_plan:split;ordinal=1/ s/align=4/align=2/'
reject_mutation overlap aggregate_parameter_overlapping_placements '/aggregate_parameter_location:.*plan=aggregate_parameter_plan:split;ordinal=1/ s/offset=4/offset=0/'
reject_mutation caller-callee aggregate_parameter_caller_callee_disagreement '0,/callee=join_initialized_fields/ s/callee=join_initialized_fields/callee=canonical_value/'
reject_mutation move-only aggregate_parameter_move_only_copy_rejected '0,/resource=non_resource;transfer=copy;resource_id=/ s/resource=non_resource;transfer=copy;resource_id=/resource=move_only;transfer=copy;resource_id=resource:phase16/'
reject_mutation argument-order aggregate_parameter_argument_order_mismatch '0,/ordinal=2;type=/ s/ordinal=2;type=/ordinal=1;type=/'

echo "guard-cranelift-phase16-aggregate-parameter-parity: ok (Level 2)"
