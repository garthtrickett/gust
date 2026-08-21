#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

build_dir="build/guards/phase19_rule_convergence"
source_path="$build_dir/cases.gst"

if [ ! -x ./gust ]; then
  echo "Phase 19.6 rule convergence parity requires the rebuilt ./gust compiler." >&2
  exit 1
fi

rm -rf "$build_dir"
mkdir -p "$build_dir"

python3 scripts/phase19_rule_convergence.py emit-fixture >"$source_path"
./gust "$source_path" >"$build_dir/cases.c" 2>"$build_dir/compiler.stderr"
test ! -s "$build_dir/compiler.stderr"
cat src/runtime.c "$build_dir/cases.c" >"$build_dir/cases.final.c"
"${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc "$build_dir/cases.final.c" -o "$build_dir/cases.program"
"$build_dir/cases.program"

echo "guard-cranelift-phase19-rule-convergence-parity: ok (Level 2)"
