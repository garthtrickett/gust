#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase18_relocation"
request="/tmp/gust-phase18-reloc.request"
mir_to_c="/tmp/gust-phase18-reloc.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile relocation fixture"
trap 'status=$?; echo "Phase 18.4 relocation parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_relocation_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 18.4 relocation model smoke passed' to.log >/dev/null

stage="build Cranelift relocation consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned relocation witnesses"
"$worker" phase18-relocation-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

stage="confirm the witness records validation before publication"
rg -n -F 'stage=before_object_publication_and_before_linker_invocation' "$build_dir/cranelift.witness" >/dev/null

stage="reject a relocation in a section that holds no bytes"
sed 's/section=text;/section=zero_initialised_data;/' "$request" >"$build_dir/bss.request"
if "$worker" phase18-relocation-witness "$build_dir/bss.request" >"$build_dir/bss.witness" 2>"$build_dir/bss.err"; then
  echo "worker accepted a relocation in zero-initialised data" >&2; exit 1
fi
rg -n -F 'relocation_in_disallowed_section' "$build_dir/bss.err" >/dev/null

stage="reject a relocation kind spelled for another object format"
sed 's/kind=R_X86_64_64;/kind=X86_64_RELOC_UNSIGNED;/' "$request" >"$build_dir/kind.request"
if "$worker" phase18-relocation-witness "$build_dir/kind.request" >"$build_dir/kind.witness" 2>"$build_dir/kind.err"; then
  echo "worker accepted a Mach-O relocation kind in an ELF model" >&2; exit 1
fi
rg -n -F 'relocation_kind_unknown' "$build_dir/kind.err" >/dev/null

# The worker recomputes absoluteness from the kind, so a mislabelled relocation
# cannot smuggle an addend past the addend policy.
stage="reject a claimed absoluteness that disagrees with the kind"
sed 's/absolute=1;/absolute=0;/' "$request" >"$build_dir/absolute.request"
if "$worker" phase18-relocation-witness "$build_dir/absolute.request" >"$build_dir/absolute.witness" 2>"$build_dir/absolute.err"; then
  echo "worker accepted a claimed absoluteness disagreeing with the kind" >&2; exit 1
fi
rg -n -F 'relocation_addend_malformed' "$build_dir/absolute.err" >/dev/null

stage="reject validation deferred past object publication"
sed 's/stage=before_object_publication_and_before_linker_invocation;/stage=during_output_replacement;/' "$request" >"$build_dir/late.request"
if "$worker" phase18-relocation-witness "$build_dir/late.request" >"$build_dir/late.witness" 2>"$build_dir/late.err"; then
  echo "worker accepted relocation validation deferred past publication" >&2; exit 1
fi
rg -n -F 'relocation_validated_too_late' "$build_dir/late.err" >/dev/null

stage="reject a relocation with no symbol"
sed 's/symbol=gust_rt_symbol;/symbol=;/' "$request" >"$build_dir/symbol.request"
if "$worker" phase18-relocation-witness "$build_dir/symbol.request" >"$build_dir/symbol.witness" 2>"$build_dir/symbol.err"; then
  echo "worker accepted a relocation with no symbol" >&2; exit 1
fi
rg -n -F 'relocation_symbol_missing' "$build_dir/symbol.err" >/dev/null

echo "guard-cranelift-phase18-relocation-parity: ok (byte-identical witness, 5 refusals, Level 2)"
