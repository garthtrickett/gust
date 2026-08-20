#!/usr/bin/env bash
# Patch 18.18 negative tests. Each mutates the audit one way and requires a
# refusal. Mutation is done in Python against the parsed JSON: a sed range that
# fails to match edits nothing, and the guard then "passes" against unmutated
# data, which reads as a green result.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
REGISTRY=scripts/cranelift_feature_registry.json
BACKUP="$(mktemp)"; cp "$REGISTRY" "$BACKUP"
trap 'cp "$BACKUP" "$REGISTRY"; rm -f "$BACKUP"' EXIT

fails=0
mutate() { # name  python-over-`a`  expected-substring
    python3 - "$2" <<'PY'
import json, sys, pathlib
p = pathlib.Path("scripts/cranelift_feature_registry.json")
r = json.loads(p.read_text()); a = r["phase18_deferrals"]
exec(sys.argv[1])
p.write_text(json.dumps(r, indent=2) + "\n")
PY
    out="$(python3 scripts/phase18_deferrals.py --check 2>&1)"; status=$?
    if [ "$status" -eq 0 ]; then
        echo "FAIL $1: audit accepted the mutation"; fails=$((fails+1))
    elif ! grep -qF "$3" <<<"$out"; then
        echo "FAIL $1: refused for the wrong reason: $out"; fails=$((fails+1))
    else
        echo "ok   $1"
    fi
    cp "$BACKUP" "$REGISTRY"
}

# A declared class with no taxonomy entry is the original defect.
mutate class_without_taxonomy_entry \
  'a["rejection_taxonomy"] = [e for e in a["rejection_taxonomy"] if e["rejection_class"] != "publication_not_atomic"]' \
  "carry no taxonomy entry"

mutate taxonomy_names_undeclared_class \
  'a["rejection_taxonomy"].append({"rejection_class":"not_a_real_class","authority":"phase18_publication","kind":"emittable","justification":"x"})' \
  "not declared"

# Claiming a class is emittable when nothing emits it.
mutate emittable_but_never_emitted \
  '[e.update(kind="emittable") for e in a["rejection_taxonomy"] if e["rejection_class"]=="unknown_triple"]' \
  "no authority module emits it at a refusal site"

# A ban that a module actually raises is not a ban.
mutate ban_that_is_really_emitted \
  '[e.update(kind="architectural_ban", enforcing_guard="scripts/phase18_object_format.py") for e in a["rejection_taxonomy"] if e["rejection_class"]=="publication_not_atomic"]' \
  "emits it as a runtime refusal"

mutate ban_names_missing_guard \
  '[e.update(enforcing_guard="scripts/does_not_exist.py") for e in a["rejection_taxonomy"] if e["kind"]=="architectural_ban"]' \
  "names no guard file that exists"

mutate vocabulary_without_deferral \
  '[e.pop("deferral_id", None) for e in a["rejection_taxonomy"] if e["kind"]=="vocabulary_only"]' \
  "must name a deferral"

mutate deferral_row_that_does_not_exist \
  'a["deferrals"][0]["phase18_rows"] = ["p18_not_a_real_row"]' \
  "does not exist"

mutate deferral_planner_is_also_the_verifier \
  'a["deferrals"][0]["diagnostic_owner"] = a["deferrals"][0]["capability_owner"]' \
  "both plans and verifies"

mutate deferral_missing_prerequisite \
  'a["deferrals"][0]["prerequisite"] = ""' \
  "missing prerequisite"

mutate deferral_not_named_for_a_phase \
  'a["deferrals"][0]["deferral_id"] = "additional_target_triples"' \
  "must name the phase"

mutate unclassified_kind \
  '[e.update(kind="probably_fine") for e in a["rejection_taxonomy"][:1]]' \
  "unknown taxonomy kind"

# Sentinel: the audit passes on unmutated data, so every refusal above was
# caused by its mutation and not by an audit that was already failing.
if python3 scripts/phase18_deferrals.py --check >/dev/null 2>&1; then
    echo "ok   sentinel_clean_registry_passes"
else
    echo "FAIL sentinel: the audit refuses unmutated data"; fails=$((fails+1))
fi

if [ "$fails" -ne 0 ]; then echo "$fails negative test(s) failed"; exit 1; fi
echo "all Patch 18.18 negative tests passed"
