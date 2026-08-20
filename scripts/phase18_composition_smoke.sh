#!/usr/bin/env bash
# Patch 18.17 negative tests. Each case mutates the composition authority one
# way and requires the guard to refuse. Mutation is done in Python against the
# parsed JSON, never with sed: a sed range that fails to match edits nothing and
# the guard then "passes" against unmutated data, which reads as a green result.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

REGISTRY=scripts/cranelift_feature_registry.json
BACKUP="$(mktemp)"; cp "$REGISTRY" "$BACKUP"
trap 'cp "$BACKUP" "$REGISTRY"; rm -f "$BACKUP"' EXIT

fails=0
mutate() { # name  python-expression-over-`c`  expected-substring
    python3 - "$2" <<'PY'
import json, sys, pathlib
p = pathlib.Path("scripts/cranelift_feature_registry.json")
r = json.loads(p.read_text()); c = r["phase18_composition"]
exec(sys.argv[1])
p.write_text(json.dumps(r, indent=1) + "\n")
PY
    out="$(python3 scripts/phase18_composition.py --check 2>&1)"; status=$?
    if [ "$status" -eq 0 ]; then
        echo "FAIL $1: guard accepted the mutation"; fails=$((fails+1))
    elif ! grep -qF "$3" <<<"$out"; then
        echo "FAIL $1: refused for the wrong reason: $out"; fails=$((fails+1))
    else
        echo "ok   $1"
    fi
    cp "$BACKUP" "$REGISTRY"
}

# Drop an authority from every case: it must be reported as uncomposed.
mutate uncomposed_authority \
  'c["composition_cases"][0]["participating_authorities"].remove("phase18_object_format")' \
  "composition_authority_uncomposed"

mutate absent_authority \
  'c["composition_cases"][0]["participating_authorities"].append("phase18_not_a_real_authority")' \
  "composition_names_absent_authority"

mutate evidence_kind_missing \
  'c["per_target_evidence"][0]["evidence_kinds"].remove("reproducibility")' \
  "per_target_evidence_incomplete"

mutate execution_from_other_runner \
  'c["per_target_evidence"][0]["execution_runner"] = "some-other-target"' \
  "execution_evidence_from_another_runner"

mutate matrix_not_derived \
  'c["per_target_evidence"] = []' \
  "per_target_evidence_incomplete"

mutate runnerless_declared_supported \
  'c["targets_without_runner"][0]["target_id"] = c["per_target_evidence"][0]["target_id"]' \
  "runnerless_target_declared_supported"

mutate runner_policy_drift \
  'c["runner_policy"] = "runnerless_targets_are_fine"' \
  "runner policy drifted"

mutate inventory_derivation_drift \
  'c["inventory_derivation"] = "hand_written_list"' \
  "inventory derivation drifted"

# Sentinel: the guard passes on unmutated data, so a refusal above is caused by
# the mutation and not by a registry that was already invalid.
if python3 scripts/phase18_composition.py --check >/dev/null 2>&1; then
    echo "ok   sentinel_clean_registry_passes"
else
    echo "FAIL sentinel: the guard refuses unmutated data"; fails=$((fails+1))
fi

if [ "$fails" -ne 0 ]; then echo "$fails negative test(s) failed"; exit 1; fi
echo "all Patch 18.17 negative tests passed"
