#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
build_dir="build/guards/phase16_aggregate_result"
request="/tmp/gust-phase16-aggregate-result.request"
mir_to_c_witness="/tmp/gust-phase16-aggregate-result.mir-to-c.witness"
worker_manifest="compiler/experiments/cranelift/Cargo.toml"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"

stage="compile and execute compiler aggregate-result fixture"
on_error() {
  local status="$1" line="$2" command="$3"
  set +e
  echo "Phase 16.4 aggregate result parity failed: stage=$stage status=$status line=$line command=$command" >&2
  for path in to.log build/gust-build.log build/mir_aggregate_result_abi_smoke_test_entry.compile.log "$build_dir/cargo-build.log" "$build_dir/cranelift.witness"; do
    if [ -f "$path" ]; then tail -n 180 "$path" >&2; fi
  done
  exit "$status"
}
trap 'on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

bash scripts/run-gust-file.sh compiler/mir_aggregate_result_abi_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 16.4 aggregate result ABI smoke passed' to.log >/dev/null
test -s "$request"
test -s "$mir_to_c_witness"

stage="build Cranelift aggregate-result consumer"
cargo build --manifest-path "$worker_manifest" >"$build_dir/cargo-build.log" 2>&1
stage="compare MIR-to-C and Cranelift aggregate-result witnesses"
"$worker" phase16-aggregate-result-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c_witness" "$build_dir/cranelift.witness" || {
  diff -u "$mir_to_c_witness" "$build_dir/cranelift.witness" >&2 || true
  false
}

for token in \
  'shape=struct_single_i32;mode=direct' \
  'shape=struct_pair_i32;mode=split' \
  'shape=struct_triple_i64;mode=hidden_pointer' \
  'owner=caller_compiler_plan;storage=aggregate_result_storage:caller:triple' \
  'kind=phase15_cleanup' \
  'plan=aggregate_result_plan:hidden;ordinal=2;offset=16;size=8;align=8;initialized=1;value=43'
do
  rg -n -F "$token" "$build_dir/cranelift.witness" >/dev/null
done

reject_mutation() {
  local label="$1" reason="$2" expression="$3"
  local mutated="$build_dir/$label.request" output="$build_dir/$label.output" temporary="$build_dir/$label.tmp"
  cp "$request" "$mutated"
  sed -i "$expression" "$mutated"
  printf 'sentinel: preserve-existing-output\n' >"$output"
  if "$worker" phase16-aggregate-result-witness "$mutated" >"$temporary" 2>"$build_dir/$label.stderr"; then
    echo "mutation unexpectedly succeeded: $label" >&2
    false
  fi
  rg -n -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null
  rg -n -F 'sentinel: preserve-existing-output' "$output" >/dev/null
}

stage="reject malformed aggregate result plans before output replacement"
reject_mutation missing-storage aggregate_result_missing_hidden_storage '0,/storage=aggregate_result_storage:caller:triple/ s/storage=aggregate_result_storage:caller:triple/storage=/'
reject_mutation duplicate-result aggregate_result_duplicate_identity '0,/result=result:split/ s/result=result:split/result=result:direct/'
reject_mutation layout aggregate_result_wrong_layout_or_alignment '0,/ResultDirectI32:target/ s/ResultDirectI32:target/ResultMissing:target/'
reject_mutation terminal-write aggregate_result_written_after_terminal '0,/kind=write_result_field;sequence=1;storage=;terminal=0/ s/terminal=0/terminal=1/'
reject_mutation caller-callee aggregate_result_caller_callee_disagreement '0,/id=aggregate_result_plan:split/ s/ordinal=0/ordinal=1/'
reject_mutation uninitialized aggregate_result_uninitialized_publication '0,/initialized=1;value=23/ s/initialized=1/initialized=0/'
reject_mutation invented-storage aggregate_result_backend_invented_storage '0,/owner=caller_compiler_plan/ s/owner=caller_compiler_plan/owner=backend_local/'

echo "guard-cranelift-phase16-aggregate-return-parity: ok (Level 2)"
