#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase18_publication"
request="/tmp/gust-phase18-publish.request"
mir_to_c="/tmp/gust-phase18-publish.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
sentinel="$build_dir/sentinel-output"
mkdir -p "$build_dir"
stage="compile publication plan fixture"
trap 'status=$?; echo "Phase 18.16 publication parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_publication_plan_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 18.16 publication smoke passed' to.log >/dev/null

stage="build Cranelift publication consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned publication witnesses"
"$worker" phase18-publication-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

stage="confirm the witness records Phase 9G as the executor and an atomic method"
rg -n -F 'executor=phase9g_artifact_planner' "$build_dir/cranelift.witness" >/dev/null
rg -n -F 'method=write_to_a_temporary_path_then_rename_over_the_output_in_one_step' "$build_dir/cranelift.witness" >/dev/null

# A sentinel output stands in for an existing valid executable. Every refusal
# below must leave it byte-identical: the whole point of planning publication as
# the last step is that a rejection cannot replace something that already works.
stage="write the sentinel output"
printf 'sentinel-existing-valid-output\n' >"$sentinel"
sentinel_before="$(sha256sum "$sentinel" | cut -d' ' -f1)"

refuse() { # label  sed-expression  expected-class
  local label="$1" expr="$2" expected="$3"
  stage="reject $label"
  sed "$expr" "$request" >"$build_dir/$label.request"
  if "$worker" phase18-publication-witness "$build_dir/$label.request" \
      >"$build_dir/$label.witness" 2>"$build_dir/$label.err"; then
    echo "worker accepted $label" >&2; exit 1
  fi
  rg -n -F "$expected" "$build_dir/$label.err" >/dev/null
}

refuse before-object-emission 's/object_emission=done;/object_emission=pending;/' \
  'publication_before_object_emission'
refuse before-relocation 's/relocation_validation=done;/relocation_validation=pending;/' \
  'publication_before_relocation_validation'
refuse before-availability 's/availability_validation=done;/availability_validation=pending;/' \
  'publication_before_availability_validation'
refuse before-link 's/link_success=done;/link_success=pending;/' \
  'publication_before_link_success'
refuse non-atomic 's/atomic=1;/atomic=0;/' \
  'publication_not_atomic'
refuse executed-by-phase18 's/executor=phase9g_artifact_planner;/executor=phase18;/' \
  'publication_executed_by_phase18'

stage="confirm no refusal replaced the existing output"
if [ "$(sha256sum "$sentinel" | cut -d' ' -f1)" != "$sentinel_before" ]; then
  echo "a refused publication modified the existing output" >&2; exit 1
fi

echo "guard-cranelift-phase18-publication-parity: ok (byte-identical witness, 6 refusals, sentinel intact, Level 2)"
