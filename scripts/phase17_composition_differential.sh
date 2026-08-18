#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase17_composition"
request="/tmp/gust-phase17-composition.request"
mir_to_c="/tmp/gust-phase17-composition.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile composition fixture"
trap 'status=$?; echo "Phase 17.14 composition differential failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_composition_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 17.14 cross-feature composition smoke passed' to.log >/dev/null

stage="build Cranelift composition consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned composition witnesses"
"$worker" phase17-composition-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

# All eight nested combinations appear.
for kind in allocation_then_string_formatting_and_output \
            resource_bearing_aggregate_across_runtime_call \
            directory_acquire_branch_early_return_cleanup \
            gust_runtime_helper_calling_stable_import \
            rust_and_retained_c_in_one_package \
            thread_helper_using_resource_cleanup \
            compatible_package_from_target_candidates \
            incompatible_version_preserving_sentinel; do
  rg -n -F "kind=$kind;" "$build_dir/cranelift.witness" >/dev/null
done

# The differential inventory is derived from canonical registry ownership rather
# than hand-maintained: every phase17 authority block in the registry must appear
# as a participant in at least one composition case.
stage="confirm every registry-owned authority participates in a composition"
python3 - "$build_dir/cranelift.witness" <<'PY'
import json, re, sys
witness = open(sys.argv[1]).read()
registry = json.load(open("scripts/cranelift_feature_registry.json"))
# The composition authority is the composition; it does not participate in
# itself. The registry validator and the Level 1 contract exclude it the same
# way, so all three agree on what "covered" means.
authorities = {
    k for k in registry
    if k.startswith("phase17_") and k.endswith("_authority")
    and k != "phase17_composition_authority"
}
participants = set()
for row in re.findall(r'participants=([^;]*);', witness):
    participants.update(p for p in row.split(',') if p)
missing = sorted(authorities - participants)
if missing:
    raise SystemExit(f"authorities with no composition case: {missing}")
extra = sorted(participants - authorities)
if extra:
    raise SystemExit(f"composition names non-registry authorities: {extra}")
print(f"composition covers all {len(authorities)} registry-owned authorities")
PY

# The explicit Cranelift path carries no generated C shim artifact.
stage="confirm no generated C shim artifact in the composition path"
if rg -n -e 'generated_c_shim' -e 'gust_runtime_wrapper' -e '_pthread_wrapper' \
     "$build_dir/cranelift.witness" >/dev/null; then
  echo "a generated C shim artifact reached the composition path" >&2; false
fi

reject_mutation() {
  local label="$1" reason="$2" expression="$3"
  local mutated="$build_dir/$1.request" output="$build_dir/$1.output" temporary="$build_dir/$1.tmp"
  cp "$request" "$mutated"; sed -i "$expression" "$mutated"
  printf 'sentinel: preserve-existing-output\n' >"$output"
  if "$worker" phase17-composition-witness "$mutated" >"$temporary" 2>"$build_dir/$label.stderr"; then
    echo "mutation unexpectedly succeeded: $label" >&2; false
  fi
  rg -n -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null
  rg -n -F 'sentinel: preserve-existing-output' "$output" >/dev/null
}

stage="reject malformed composition cases before object or link access"
reject_mutation unknown_kind runtime_composition_unknown_kind \
  '0,/kind=allocation_then_string_formatting_and_output;/ s/kind=allocation_then_string_formatting_and_output;/kind=everything_at_once;/'
reject_mutation not_composed runtime_composition_not_composed \
  '0,/participants=phase17_runtime_authority,phase17_memory_runtime_authority,phase17_io_runtime_authority;/ s/participants=phase17_runtime_authority,phase17_memory_runtime_authority,phase17_io_runtime_authority;/participants=phase17_memory_runtime_authority;/'
reject_mutation no_owner runtime_composition_no_differential_owner \
  '0,/owner=compiler_memory_and_io_differential_owner;/ s/owner=compiler_memory_and_io_differential_owner;/owner=;/'
reject_mutation unknown_format runtime_composition_malformed_case \
  '0,/format: gust.compiler_composition.v1/ s/format: gust.compiler_composition.v1/format: gust.compiler_composition.v9/'

# Dropping the failure case must be caught: without it nothing proves existing
# output survives an incompatible runtime version.
stage="reject an inventory missing the sentinel-preserving failure case"
partial="$build_dir/partial.request"
rg -v -F 'kind=incompatible_version_preserving_sentinel' "$request" >"$partial" || true
if "$worker" phase17-composition-witness "$partial" >/dev/null 2>"$build_dir/partial.stderr"; then
  echo "inventory without the failure case unexpectedly accepted" >&2; false
fi
rg -n -F 'reason=runtime_composition_incomplete_inventory' "$build_dir/partial.stderr" >/dev/null

echo "guard-cranelift-phase17-composition-differential: ok (Level 2)"
