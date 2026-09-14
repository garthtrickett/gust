#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

build_dir="build/guards/phase19_representation"
a_source="compiler/phase19_argument_representation_a_source.gst"
b_source="compiler/phase19_argument_representation_b_source.gst"

if [ ! -x ./gust ]; then
  echo "Phase 19.5 representation parity requires the rebuilt ./gust compiler." >&2
  exit 1
fi

rm -rf "$build_dir"
mkdir -p "$build_dir"

normalise_source() {
  grep -v '^[[:space:]]*//' "$1" | sed "s/\\b$2\\b/LOCAL/g"
}

diff <(normalise_source "$a_source" a) <(normalise_source "$b_source" b) >/dev/null || {
  echo "Phase 19.5 argument fixtures differ by more than the local spelling." >&2
  exit 1
}

for arm in a b; do
  source_path="$a_source"
  local_name="a"
  if [ "$arm" = "b" ]; then source_path="$b_source"; local_name="b"; fi
  python3 scripts/phase24_frozen_oracle.py materialize "$source_path" "$build_dir/$arm" --kind exec
  test ! -s "$build_dir/$arm.compile.stderr"
  status="$(cat "$build_dir/$arm.status")"
  if [ "$status" != "7" ]; then
    echo "Phase 19.5 $arm arm returned $status, expected 7." >&2
    exit 1
  fi
done

# Patch 24.12: two assertions about the generated C text were removed here,
# both invariants of the retired emitter with no native counterpart:
# renaming a by-value str local must not change the emitted C, and MIR-to-C
# must not prepend address-of to a by-value str source expression. Freezing
# either would have compared a frozen digest against itself. The
# representation evidence that survives is the MIR-to-C witness compared
# against the explicit Cranelift consumer below.

# The Phase 16 parity driver now carries the Phase 19.5 representation fields.
# It compares the compiler MIR-to-C witness with the explicit Cranelift consumer
# and also retains the original malformed-call rejection family.
bash scripts/phase16_call_mir_parity.sh
witness="build/guards/phase16_call_mir/cranelift.witness"
for token in \
  'passing_mode=direct materialization=by_value value_type=type:gust:str' \
  'passing_mode=indirect_by_reference materialization=by_address value_type=type:gust:Arena' \
  'passing_mode=hidden_pointer materialization=by_address value_type=type:gust:int'
do
  rg -n -F "$token" "$witness" >/dev/null
done

worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
request="/tmp/gust-phase16-call-mir.request"
mutated="$build_dir/representation-mismatch.request"
cp "$request" "$mutated"
sed -i '0,/materialization=by_value/ s/materialization=by_value/materialization=by_address/' "$mutated"
if "$worker" phase16-call-mir-witness "$mutated" >"$build_dir/mutated.stdout" 2>"$build_dir/mutated.stderr"; then
  echo "Cranelift accepted a call-MIR representation disagreement." >&2
  exit 1
fi
rg -n -F 'reason=call_mir_representation_mismatch' "$build_dir/mutated.stderr" >/dev/null

echo "guard-cranelift-phase19-representation-parity: ok (Level 2)"
