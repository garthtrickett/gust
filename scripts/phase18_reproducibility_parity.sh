#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase18_reproducibility"
request="/tmp/gust-phase18-repro.request"
mir_to_c="/tmp/gust-phase18-repro.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile reproducibility fixture"
trap 'status=$?; echo "Phase 18.15 reproducibility parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_reproducible_build_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 18.15 reproducibility smoke passed' to.log >/dev/null

stage="build Cranelift reproducibility consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned reproducibility witnesses"
"$worker" phase18-reproducible-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

stage="confirm the witness records a byte-for-byte comparison of two builds"
rg -n -F 'comparison=two_builds_compared_byte_for_byte_over_the_reproducible_fields' "$build_dir/cranelift.witness" >/dev/null

# A reproducibility claim made from a single build is a claim about nothing.
stage="reject a claim made without a repeated build"
head -3 "$request" >"$build_dir/single.request"
if "$worker" phase18-reproducible-witness "$build_dir/single.request" >"$build_dir/single.witness" 2>"$build_dir/single.err"; then
  echo "worker accepted a reproducibility claim from one build" >&2; exit 1
fi
rg -n -F 'reproducibility_claimed_without_a_repeated_build' "$build_dir/single.err" >/dev/null

stage="reject a reproducible field that varied between builds"
sed '$ s/field_value=0x40;/field_value=0x48;/' "$request" >"$build_dir/varied.request"
if "$worker" phase18-reproducible-witness "$build_dir/varied.request" >"$build_dir/varied.witness" 2>"$build_dir/varied.err"; then
  echo "worker accepted a reproducible field that varied" >&2; exit 1
fi
rg -n -F 'reproducible_field_varied_between_builds' "$build_dir/varied.err" >/dev/null

stage="reject an embedded path that was not normalised"
sed 's/path_form=relative_to_source_root;/path_form=absolute_host_path;/' "$request" >"$build_dir/path.request"
if "$worker" phase18-reproducible-witness "$build_dir/path.request" >"$build_dir/path.witness" 2>"$build_dir/path.err"; then
  echo "worker accepted an unnormalised embedded path" >&2; exit 1
fi
rg -n -F 'normalisation_rule_not_applied' "$build_dir/path.err" >/dev/null

stage="reject order taken from a source that is not the compiler's own"
sed 's/order_source=compiler_produced_order;/order_source=hash_table_iteration;/' "$request" >"$build_dir/order.request"
if "$worker" phase18-reproducible-witness "$build_dir/order.request" >"$build_dir/order.witness" 2>"$build_dir/order.err"; then
  echo "worker accepted nondeterministic order in a reproducible field" >&2; exit 1
fi
rg -n -F 'nondeterministic_order_in_a_reproducible_field' "$build_dir/order.err" >/dev/null

stage="reject an excluded field that does not say why it is excluded"
sed 's/excluded_reason=[^;]*;/excluded_reason=;/' "$request" >"$build_dir/excluded.request"
if "$worker" phase18-reproducible-witness "$build_dir/excluded.request" >"$build_dir/excluded.witness" 2>"$build_dir/excluded.err"; then
  echo "worker accepted an excluded field with no declared reason" >&2; exit 1
fi
rg -n -F 'excluded_field_not_declared' "$build_dir/excluded.err" >/dev/null

echo "guard-cranelift-phase18-reproducibility-parity: ok (byte-identical witness, 5 refusals, Level 2)"
