#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase18_linker_policy"
request="/tmp/gust-phase18-linker.request"
mir_to_c="/tmp/gust-phase18-linker.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile linker policy fixture"
trap 'status=$?; echo "Phase 18.7 linker policy parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_linker_policy_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 18.7 linker policy smoke passed' to.log >/dev/null

stage="build Cranelift linker policy consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned linker policy witnesses"
"$worker" phase18-linker-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

stage="confirm the witness records Phase 9G invocation ownership"
rg -n -F 'invocation_owner=phase9g_artifact_planner' "$build_dir/cranelift.witness" >/dev/null
rg -n -F 'discovery=discovered' "$build_dir/cranelift.witness" >/dev/null

# An undiscovered linker may be reported but never used, so the four targets
# with no cross linker cannot slip into a link plan.
stage="reject an undiscovered linker"
sed 's/discovery=discovered;/discovery=undiscovered_no_cross_linker_declared;/' "$request" >"$build_dir/undiscovered.request"
if "$worker" phase18-linker-witness "$build_dir/undiscovered.request" >"$build_dir/undiscovered.witness" 2>"$build_dir/undiscovered.err"; then
  echo "worker accepted an undiscovered linker" >&2; exit 1
fi
rg -n -F 'linker_undiscovered' "$build_dir/undiscovered.err" >/dev/null

stage="reject a linker that does not support the target object format"
sed 's/object_format=elf;/object_format=macho;/' "$request" >"$build_dir/format.request"
if "$worker" phase18-linker-witness "$build_dir/format.request" >"$build_dir/format.witness" 2>"$build_dir/format.err"; then
  echo "worker accepted a linker for the wrong object format" >&2; exit 1
fi
rg -n -F 'linker_unsupported_object_format' "$build_dir/format.err" >/dev/null

stage="reject Phase 18 claiming linker invocation"
sed 's/invocation_owner=phase9g_artifact_planner;/invocation_owner=phase18_target_authority;/' "$request" >"$build_dir/owner.request"
if "$worker" phase18-linker-witness "$build_dir/owner.request" >"$build_dir/owner.witness" 2>"$build_dir/owner.err"; then
  echo "worker accepted Phase 18 claiming linker invocation" >&2; exit 1
fi
rg -n -F 'linker_invoked_by_phase18' "$build_dir/owner.err" >/dev/null

stage="reject an argument outside the declared vocabulary"
sed 's/argument=-o;/argument=--wl,-rpath;/' "$request" >"$build_dir/argument.request"
if "$worker" phase18-linker-witness "$build_dir/argument.request" >"$build_dir/argument.witness" 2>"$build_dir/argument.err"; then
  echo "worker accepted an argument outside the declared vocabulary" >&2; exit 1
fi
rg -n -F 'linker_argument_outside_vocabulary' "$build_dir/argument.err" >/dev/null

echo "guard-cranelift-phase18-linker-policy-parity: ok (byte-identical witness, 4 refusals, Level 2)"
