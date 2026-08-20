#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase18_debug_info"
request="/tmp/gust-phase18-debug.request"
mir_to_c="/tmp/gust-phase18-debug.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile debug plan fixture"
trap 'status=$?; echo "Phase 18.12 debug information parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_debug_plan_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 18.12 debug information smoke passed' to.log >/dev/null

stage="build Cranelift debug plan consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned debug plan witnesses"
"$worker" phase18-debug-plan-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

stage="confirm the witness records a compiler-selected plan"
rg -n -F 'derived_from=object_format_in_the_phase18_object_format_authority' "$build_dir/cranelift.witness" >/dev/null
rg -n -F 'level=line_tables_only' "$build_dir/cranelift.witness" >/dev/null

# A plan the backend inferred is not a compiler-selected plan.
stage="reject a debug plan inferred by the backend"
sed 's/derived_from=object_format_in_the_phase18_object_format_authority;/derived_from=backend_default;/' "$request" >"$build_dir/inferred.request"
if "$worker" phase18-debug-plan-witness "$build_dir/inferred.request" >"$build_dir/inferred.witness" 2>"$build_dir/inferred.err"; then
  echo "worker accepted a debug plan inferred by the backend" >&2; exit 1
fi
rg -n -F 'debug_plan_inferred_by_backend' "$build_dir/inferred.err" >/dev/null

stage="reject a debug level outside the declared vocabulary"
sed 's/level=line_tables_only;/level=full;/' "$request" >"$build_dir/level.request"
if "$worker" phase18-debug-plan-witness "$build_dir/level.request" >"$build_dir/level.witness" 2>"$build_dir/level.err"; then
  echo "worker accepted a debug level outside the declared vocabulary" >&2; exit 1
fi
rg -n -F 'debug_level_unknown' "$build_dir/level.err" >/dev/null

# A plan that states only its inclusions leaves its gaps implicit.
stage="reject a plan that does not say what it omits"
sed 's/excluded=variable_location;/excluded=;/' "$request" >"$build_dir/silent.request"
if "$worker" phase18-debug-plan-witness "$build_dir/silent.request" >"$build_dir/silent.witness" 2>"$build_dir/silent.err"; then
  echo "worker accepted a plan that does not say what it omits" >&2; exit 1
fi
rg -n -F 'debug_record_kind_undeclared' "$build_dir/silent.err" >/dev/null

stage="reject a record kind both included and excluded"
sed 's/excluded=variable_location;/excluded=line_table;/' "$request" >"$build_dir/both.request"
if "$worker" phase18-debug-plan-witness "$build_dir/both.request" >"$build_dir/both.witness" 2>"$build_dir/both.err"; then
  echo "worker accepted a record kind both included and excluded" >&2; exit 1
fi
rg -n -F 'debug_record_kind_undeclared' "$build_dir/both.err" >/dev/null

# AUDIT (18.18): two declared classes the worker emits that nothing forced.
stage="reject a debug format the object format does not imply"
sed 's/debug_format=dwarf;/debug_format=codeview;/' "$request" >"$build_dir/format.request"
if "$worker" phase18-debug-plan-witness "$build_dir/format.request" >"$build_dir/format.witness" 2>"$build_dir/format.err"; then
  echo "worker accepted a debug format ELF does not imply" >&2; exit 1
fi
rg -n -F 'debug_format_disagrees_with_object_format' "$build_dir/format.err" >/dev/null

stage="reject a declared target carrying no debug plan"
grep -v '^debug_plan:' "$request" >"$build_dir/planless.request"
if "$worker" phase18-debug-plan-witness "$build_dir/planless.request" >"$build_dir/planless.witness" 2>"$build_dir/planless.err"; then
  echo "worker accepted a request with no debug plan" >&2; exit 1
fi
rg -n -F 'debug_plan_missing_for_declared_target' "$build_dir/planless.err" >/dev/null

echo "guard-cranelift-phase18-debug-info-parity: ok (byte-identical witness, 6 refusals, Level 2)"
