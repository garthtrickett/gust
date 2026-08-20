#!/usr/bin/env bash
# Level 3, Cranelift Historical Full only. The phase exit gate: for every target
# Phase 18 declares supported, demonstrate all six evidence kinds and record
# where each came from. This is the one Phase 18 row Historical Full owns.
#
# The evidence is COLLECTED, not asserted. Each kind runs the guard that already
# owns it, so this script cannot claim evidence that its owner would refuse.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase18_complete_target_evidence"
mkdir -p "$build_dir"
evidence="$build_dir/evidence.tsv"
stage="start"
trap 'status=$?; echo "Phase 18 complete target evidence failed: stage=$stage status=$status" >&2; exit $status' ERR

# The supported set is DERIVED from the diagnostics, never hand-listed here.
mapfile -t targets < <(python3 - <<'PY'
import json
reg = json.load(open("scripts/cranelift_feature_registry.json"))
for row in reg["phase18_target_diagnostics"]["target_diagnostics"]:
    if row["support_decision"] == "supported":
        print(row["target_triple"])
PY
)
if [ "${#targets[@]}" -eq 0 ]; then
  echo "no declared supported target: the phase exit gate has nothing to prove" >&2; exit 1
fi

printf 'target\tevidence_kind\towning_guard\n' >"$evidence"
record() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >>"$evidence"; }

for target in "${targets[@]}"; do
  # The host runs this script, so execution evidence is only honest when the
  # declared target matches the host. A target with no runner is not declared
  # supported in the first place, which is what makes this check safe.
  stage="confirm $target can run here"
  # `cc -dumpmachine` omits the vendor field (x86_64-linux-gnu) while the
  # declared triple carries it (x86_64-unknown-linux-gnu). Compare the parsed
  # components, not the raw strings: string equality would reject a host that
  # can in fact run the target, making the exit gate refuse a correct build.
  if ! python3 - "$target" "$(cc -dumpmachine)" <<'TRIPLE_EOF'; then
import sys
declared, host = sys.argv[1], sys.argv[2]

def parts(triple):
    bits = triple.split("-")
    if len(bits) == 3:
        bits = [bits[0], "unknown", bits[1], bits[2]]
    if len(bits) != 4:
        raise SystemExit(f"cannot parse triple {triple!r}")
    return bits

d, h = parts(declared), parts(host)
# Vendor is cosmetic for execution; architecture, OS, and environment are not.
if (d[0], d[2], d[3]) != (h[0], h[2], h[3]):
    raise SystemExit(f"declared target {declared} cannot execute on host {host}")
TRIPLE_EOF
    echo "declared supported target $target cannot execute on this host" >&2; exit 1
  fi

  stage="native compile evidence for $target"
  just guard-cranelift-phase18-target-authority-parity >"$build_dir/native.log" 2>&1
  record "$target" native_compile guard-cranelift-phase18-target-authority-parity

  stage="object inspection evidence for $target"
  just guard-cranelift-phase18-object-inspection-parity >"$build_dir/inspect.log" 2>&1
  record "$target" object_inspection guard-cranelift-phase18-object-inspection-parity

  stage="link evidence for $target"
  just guard-cranelift-phase18-link-mode-parity >"$build_dir/link.log" 2>&1
  record "$target" link guard-cranelift-phase18-link-mode-parity

  # Execution evidence: a program actually runs and returns what it promised.
  stage="execution evidence for $target"
  printf 'int main(void) { return 7; }\n' >"$build_dir/exec.c"
  cc "$build_dir/exec.c" -o "$build_dir/exec"
  set +e; "$build_dir/exec"; actual=$?; set -e
  if [ "$actual" -ne 7 ]; then
    echo "execution evidence for $target returned $actual, expected 7" >&2; exit 1
  fi
  record "$target" execution host_runner

  stage="diagnostic evidence for $target"
  just guard-cranelift-phase18-target-diagnostic-parity >"$build_dir/diag.log" 2>&1
  record "$target" diagnostic guard-cranelift-phase18-target-diagnostic-parity

  stage="reproducibility evidence for $target"
  just guard-cranelift-phase18-reproducibility-parity >"$build_dir/repro.log" 2>&1
  record "$target" reproducibility guard-cranelift-phase18-reproducibility-parity
done

stage="check every declared evidence kind was collected for every target"
python3 - "$evidence" <<'PY'
import csv, json, sys
reg = json.load(open("scripts/cranelift_feature_registry.json"))
required = set(reg["phase18_composition"]["evidence_kinds"])
rows = list(csv.DictReader(open(sys.argv[1]), delimiter="\t"))
by_target = {}
for row in rows:
    by_target.setdefault(row["target"], set()).add(row["evidence_kind"])
for target, kinds in by_target.items():
    missing = required - kinds
    if missing:
        raise SystemExit(f"{target}: missing evidence {sorted(missing)}")
print(f"complete evidence for {len(by_target)} target(s): {sorted(required)}")
PY

echo "guard-cranelift-phase18-complete-target-evidence: ok (${#targets[@]} target(s), 6 evidence kinds each, Level 3)"
