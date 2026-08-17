#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase17_availability"
request="/tmp/gust-phase17-availability.request"
mir_to_c="/tmp/gust-phase17-availability.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile availability fixture"
trap 'status=$?; echo "Phase 17.13 availability parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_availability_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 17.13 availability diagnostics smoke passed' to.log >/dev/null

stage="build Cranelift availability consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned availability witnesses"
"$worker" phase17-availability-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

# All eight frozen decisions appear in order, with their stage boundaries.
for order in 0 1 2 3 4 5 6 7; do
  rg -n -F "order=$order;" "$build_dir/cranelift.witness" >/dev/null
done
for token in 'step=package_manifest_format' 'step=target_identity' \
             'step=required_symbol_presence_and_version' \
             'step=deterministic_component_and_link_ordering' \
             'stage=before_worker_execution' \
             'stage=after_target_selection_before_linker_invocation' \
             'linkage=all_compatibility_decisions_complete_before_any_output_could_exist'; do
  rg -n -F "$token" "$build_dir/cranelift.witness" >/dev/null
done

# No decision may be deferred past the point output could exist. Any stage
# naming the linker, a temporary output, or a replacement is a late decision.
stage="confirm no decision is deferred past an output-producing stage"
if rg -n -e 'stage=during_' -e 'stage=after_linker' -e 'stage=.*output_replacement' \
     "$build_dir/cranelift.witness" >/dev/null; then
  echo "a compatibility decision is deferred past an output-producing stage" >&2
  false
fi

reject_mutation() {
  local label="$1" reason="$2" expression="$3"
  local mutated="$build_dir/$1.request" output="$build_dir/$1.output" temporary="$build_dir/$1.tmp"
  cp "$request" "$mutated"; sed -i "$expression" "$mutated"
  printf 'sentinel: preserve-existing-output\n' >"$output"
  if "$worker" phase17-availability-witness "$mutated" >"$temporary" 2>"$build_dir/$label.stderr"; then
    echo "mutation unexpectedly succeeded: $label" >&2; false
  fi
  rg -n -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null
  rg -n -F 'sentinel: preserve-existing-output' "$output" >/dev/null
}

stage="reject malformed availability decisions before object or link access"
reject_mutation order_drift runtime_availability_decision_order_drift \
  '0,/order=0;step=package_manifest_format;/ s/order=0;step=package_manifest_format;/order=5;step=package_manifest_format;/'
reject_mutation late_decision runtime_availability_late_decision \
  '0,/stage=before_worker_execution;/ s/stage=before_worker_execution;/stage=during_output_replacement;/'
reject_mutation unclassified runtime_availability_unclassified_rejection \
  '0,/rejection=runtime_manifest_malformed;/ s/rejection=runtime_manifest_malformed;/rejection=something_went_wrong;/'
reject_mutation unknown_step runtime_availability_malformed_decision \
  '0,/step=target_identity;/ s/step=target_identity;/step=guess_and_hope;/'
reject_mutation unknown_format runtime_availability_malformed_decision \
  '0,/format: gust.compiler_availability.v1/ s/format: gust.compiler_availability.v1/format: gust.compiler_availability.v9/'

# Dropping a decision must be caught: a partial order means some compatibility
# question was never asked at all.
stage="reject a partial decision order"
partial="$build_dir/partial.request"
rg -v -F 'step=deterministic_component_and_link_ordering' "$request" >"$partial" || true
if "$worker" phase17-availability-witness "$partial" >/dev/null 2>"$build_dir/partial.stderr"; then
  echo "partial decision order unexpectedly accepted" >&2; false
fi
rg -n -F 'reason=runtime_availability_incomplete_order' "$build_dir/partial.stderr" >/dev/null

echo "guard-cranelift-phase17-availability-parity: ok (Level 2)"
