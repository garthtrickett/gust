#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase18_target_package"
request="/tmp/gust-phase18-package.request"
mir_to_c="/tmp/gust-phase18-package.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile target package fixture"
trap 'status=$?; echo "Phase 18.6 target package parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_target_package_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 18.6 target package selection smoke passed' to.log >/dev/null

stage="build Cranelift target package consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned package selection witnesses"
"$worker" phase18-target-package-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

stage="confirm the witness records Phase 17 ownership and a static archive"
rg -n -F 'owner=phase17_runtime_package_authority' "$build_dir/cranelift.witness" >/dev/null
rg -n -F 'form=static_archive' "$build_dir/cranelift.witness" >/dev/null

# The package format must agree with the format Patch 18.3 derived. A package
# for a different object format belongs to a different target.
stage="reject a package format disagreeing with the descriptor"
sed 's/object_format=elf;/object_format=macho;/' "$request" >"$build_dir/format.request"
if "$worker" phase18-target-package-witness "$build_dir/format.request" >"$build_dir/format.witness" 2>"$build_dir/format.err"; then
  echo "worker accepted a package format disagreeing with the descriptor" >&2; exit 1
fi
rg -n -F 'target_package_object_format_mismatch' "$build_dir/format.err" >/dev/null

stage="reject a package Phase 18 claims to own"
sed 's/owner=phase17_runtime_package_authority;/owner=phase18_target_authority;/' "$request" >"$build_dir/owner.request"
if "$worker" phase18-target-package-witness "$build_dir/owner.request" >"$build_dir/owner.witness" 2>"$build_dir/owner.err"; then
  echo "worker accepted a package Phase 18 claims to own" >&2; exit 1
fi
rg -n -F 'target_package_defined_by_phase18' "$build_dir/owner.err" >/dev/null

stage="reject an unknown package form"
sed 's/form=static_archive;/form=loose_objects;/' "$request" >"$build_dir/form.request"
if "$worker" phase18-target-package-witness "$build_dir/form.request" >"$build_dir/form.witness" 2>"$build_dir/form.err"; then
  echo "worker accepted an unknown package form" >&2; exit 1
fi
rg -n -F 'target_package_wrong_target' "$build_dir/form.err" >/dev/null

echo "guard-cranelift-phase18-target-package-parity: ok (byte-identical witness, 3 refusals, Level 2)"
