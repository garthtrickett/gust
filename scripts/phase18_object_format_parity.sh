#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase18_object_format"
request="/tmp/gust-phase18-objfmt.request"
mir_to_c="/tmp/gust-phase18-objfmt.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile object format fixture"
trap 'status=$?; echo "Phase 18.3 object format parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_object_format_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 18.3 object format smoke passed' to.log >/dev/null

stage="build Cranelift object format consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned object format witnesses"
"$worker" phase18-object-format-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

stage="confirm the witness records a target-derived format"
rg -n -F 'derived_from=operating_system_in_declared_target_identity' "$build_dir/cranelift.witness" >/dev/null
rg -n -F 'object_format=elf' "$build_dir/cranelift.witness" >/dev/null

# The worker recomputes the format from the operating system, so a descriptor
# claiming a format that os does not imply must be refused.
stage="reject a format the operating system does not imply"
sed 's/object_format=elf/object_format=macho/' "$request" >"$build_dir/wrong.request"
if "$worker" phase18-object-format-witness "$build_dir/wrong.request" >"$build_dir/wrong.witness" 2>"$build_dir/wrong.err"; then
  echo "worker accepted a format the operating system does not imply" >&2; exit 1
fi
rg -n -F 'object_format_disagrees_with_target_identity' "$build_dir/wrong.err" >/dev/null

stage="reject a format not derived from target identity"
sed 's/derived_from=operating_system_in_declared_target_identity/derived_from=host_default/' "$request" >"$build_dir/host.request"
if "$worker" phase18-object-format-witness "$build_dir/host.request" >"$build_dir/host.witness" 2>"$build_dir/host.err"; then
  echo "worker accepted a host default format" >&2; exit 1
fi
rg -n -F 'object_format_not_derived_from_target_identity' "$build_dir/host.err" >/dev/null

stage="reject an ELF section name that is not dot-prefixed"
sed 's/name=\.text;/name=text;/' "$request" >"$build_dir/name.request"
if "$worker" phase18-object-format-witness "$build_dir/name.request" >"$build_dir/name.witness" 2>"$build_dir/name.err"; then
  echo "worker accepted a malformed ELF section name" >&2; exit 1
fi
rg -n -F 'object_section_name_wrong_format' "$build_dir/name.err" >/dev/null

stage="reject a section aligned beyond the declared maximum"
sed 's/name=\.rodata;align=8;/name=.rodata;align=64;/' "$request" >"$build_dir/align.request"
if "$worker" phase18-object-format-witness "$build_dir/align.request" >"$build_dir/align.witness" 2>"$build_dir/align.err"; then
  echo "worker accepted a section aligned beyond the declared maximum" >&2; exit 1
fi
rg -n -F 'object_section_misaligned' "$build_dir/align.err" >/dev/null

echo "guard-cranelift-phase18-object-format-parity: ok (byte-identical witness, 4 refusals, Level 2)"
