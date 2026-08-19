#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase18_link_mode"
request="/tmp/gust-phase18-linkmode.request"
mir_to_c="/tmp/gust-phase18-linkmode.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile link mode fixture"
trap 'status=$?; echo "Phase 18.8 link mode parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_link_mode_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 18.8 link mode smoke passed' to.log >/dev/null

stage="build Cranelift link mode consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned link mode witnesses"
"$worker" phase18-link-mode-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

stage="confirm the witness records a static archive backing a static link"
rg -n -F 'package_form=static_archive' "$build_dir/cranelift.witness" >/dev/null
rg -n -F 'selected_mode=static;derived_mode=static;' "$build_dir/cranelift.witness" >/dev/null

# Dynamic is unavailable because no shared library package exists. Requesting it
# must be refused rather than downgraded to static.
stage="reject dynamic when only a static archive exists"
sed 's/selected_mode=static;/selected_mode=dynamic;/' "$request" >"$build_dir/dynamic.request"
if "$worker" phase18-link-mode-witness "$build_dir/dynamic.request" >"$build_dir/dynamic.witness" 2>"$build_dir/dynamic.err"; then
  echo "worker accepted dynamic linking with no shared library package" >&2; exit 1
fi
rg -n -F 'link_mode_unavailable_for_target' "$build_dir/dynamic.err" >/dev/null

# A request cannot declare its own availability; the worker recomputes it.
stage="reject a claimed derived mode disagreeing with the package form"
sed 's/derived_mode=static;/derived_mode=dynamic;/' "$request" >"$build_dir/claimed.request"
if "$worker" phase18-link-mode-witness "$build_dir/claimed.request" >"$build_dir/claimed.witness" 2>"$build_dir/claimed.err"; then
  echo "worker accepted a claimed derived mode disagreeing with the package form" >&2; exit 1
fi
rg -n -F 'link_mode_silently_substituted' "$build_dir/claimed.err" >/dev/null

stage="reject a package form that provides no mode"
sed 's/package_form=static_archive;/package_form=loose_objects;/' "$request" >"$build_dir/form.request"
if "$worker" phase18-link-mode-witness "$build_dir/form.request" >"$build_dir/form.witness" 2>"$build_dir/form.err"; then
  echo "worker accepted a package form that provides no mode" >&2; exit 1
fi
rg -n -F 'link_mode_package_form_mismatch' "$build_dir/form.err" >/dev/null

echo "guard-cranelift-phase18-link-mode-parity: ok (byte-identical witness, 3 refusals, Level 2)"
