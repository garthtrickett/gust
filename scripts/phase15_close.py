#!/usr/bin/env python3
from __future__ import annotations
import argparse, csv, json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase15-close"
CONTRACT = ROOT / "tests/cranelift/phase15_close_contract.tsv"
REVIEW = ROOT / "tests/cranelift/phase15_close_review.txt"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
REQUIRED_AUTHORITIES = {
    "compiler/mir_resource_authority.gst", "phase15_specialized_resource_authority",
    "phase15_failure_cleanup_authority", "phase15_resource_composition_authority",
    "phase15_deferred_residue_audit",
}
REQUIRED_LEVEL1 = {
    "guard-cranelift-phase15-opening-contract", "guard-cranelift-phase15-resource-authority-contract",
    "guard-cranelift-phase15-resource-mir-contract", "guard-cranelift-phase15-move-state-contract",
    "guard-cranelift-phase15-resource-reassignment-contract", "guard-cranelift-phase15-scope-exit-cleanup-contract",
    "guard-cranelift-phase15-early-return-cleanup-contract", "guard-cranelift-phase15-destructor-scheduling-contract",
    "guard-cranelift-phase15-manual-close-contract", "guard-cranelift-phase15-resource-cfg-contract",
    "guard-cranelift-phase15-resource-metadata-contract", "guard-cranelift-phase15-specialized-resource-contract",
    "guard-cranelift-phase15-failure-cleanup-contract", "guard-cranelift-phase15-resource-composition-contract",
    "guard-cranelift-phase15-deferred-residue-audit", "guard-cranelift-phase15-close",
}

def fail(message: str) -> None: raise SystemExit(f"{GUARD}: {message}")
def rows() -> list[dict[str, str]]:
    with CONTRACT.open(newline="") as handle: values = list(csv.DictReader(handle, delimiter="\t"))
    if not values or set(values[0]) != {"kind", "requirement", "evidence", "level"}: fail("contract schema mismatch")
    if any(row["level"] != "1" or not row["evidence"] for row in values): fail("closure rows must be Level 1")
    return values
def render(values: list[dict[str, str]]) -> str:
    return "Patch 15.15 — Phase 15 Closure\n\n" + "".join(f"{r['kind']}\t{r['requirement']}\t{r['evidence']}\tLevel {r['level']}\n" for r in values)

def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    closure = registry.get("phase15_closure")
    if not isinstance(closure, dict) or closure.get("status") != "phase15_closed_resource_and_lifetime_semantics": fail("semantic closure status missing")
    if set(closure.get("required_authorities", [])) != REQUIRED_AUTHORITIES: fail("required authority coverage drifted")
    expected_counts = {"opening_entry_count": 13, "migrated_entry_count": 13, "excluded_item_count": 1, "narrow_deferred_row_count": 3}
    if any(closure.get(key) != value for key, value in expected_counts.items()): fail("closure totals drifted")
    audit = registry.get("phase15_deferred_residue_audit", {})
    if len(audit.get("opening_dispositions", [])) != 13 or any(row.get("disposition") != "migrated" for row in audit.get("opening_dispositions", [])): fail("opening disposition closure incomplete")
    if len(audit.get("narrow_deferred_rows", [])) != 3 or len(audit.get("excluded_items", [])) != 1: fail("residue closure incomplete")
    for key in REQUIRED_AUTHORITIES - {"compiler/mir_resource_authority.gst"}:
        if key not in registry: fail(f"missing registry authority {key}")
    if not (ROOT / "compiler/mir_resource_authority.gst").is_file(): fail("generic resource authority missing")

    task = (ROOT / "TASK.md").read_text()
    done = {int(match.group(1)) for match in re.finditer(r"^- \[x\] Patch 15\.(\d+).+— DONE$", task, re.MULTILINE)}
    if done != set(range(16)): fail(f"TASK.md Phase 15 status incomplete: {sorted(done)}")

    levels = json.loads((ROOT / "scripts/cranelift_test_levels.json").read_text())["guards"]
    if any(levels.get(guard) != 1 for guard in REQUIRED_LEVEL1): fail("Level 1 closure mapping incomplete")
    if levels.get("guard-cranelift-phase15-complete-resource-evidence") != 3: fail("complete evidence is not Level 3")
    historical = (ROOT / ".github/workflows/cranelift-historical-full.yml").read_text()
    if historical.count("just guard-cranelift-phase15-complete-resource-evidence") != 1: fail("Historical Full does not solely own complete resource evidence")

    opening = (ROOT / "compiler/CRANELIFT_PHASE15_OPENING.md").read_text()
    manifest = (ROOT / "compiler/CRANELIFT_EXPERIMENT_MANIFEST.md").read_text()
    justfile = (ROOT / "justfile").read_text()
    required_tokens = [
        (opening, "MIR-to-C remains the default differential oracle"),
        (opening, "Phase 9G retains object, link, temporary-artifact cleanup, and atomic publication ownership"),
        (manifest, "explicit_cranelift_success_deferral_or_failure_terminates_without_MIR-to-C_codegen"),
        (justfile, "guard-cranelift-route-architecture-contract"),
        (justfile, "guard-cranelift-phase9g-close"),
        (justfile, "guard-cranelift-phase14-close"),
        (justfile, "guard-cranelift-phase15-close"),
    ]
    for text, token in required_tokens:
        if token not in text: fail(f"missing closure dependency token {token}")
    if closure.get("worker_policy") != "isolated_worker_consumes_only_validated_request_canonical_mir_layout_and_resource_metadata": fail("worker isolation policy drifted")
    if closure.get("failure_policy") != "invalid_or_deferred_stops_before_driver_and_artifact_access_with_output_preserved": fail("deferral/preservation policy drifted")
    values = rows()
    if not REVIEW.is_file() or REVIEW.read_text() != render(values): fail("generated closure review is stale; run --write")
    print(f"{GUARD}: ok (opening=13 migrated=13 deferred=3 excluded=1, Level 1)")

def main() -> None:
    parser = argparse.ArgumentParser(); parser.add_argument("--write", action="store_true"); parser.add_argument("--check", action="store_true"); args = parser.parse_args()
    if args.write: REVIEW.write_text(render(rows()))
    check()
if __name__ == "__main__": main()
