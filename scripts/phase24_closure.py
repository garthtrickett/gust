"""Patch 24.18: close the generated-C backend retirement, and nothing else.

Phase 24 had two closure generators and neither closed the phase:
`phase24_cr15_closure.py` closes 24.0f and `phase24_preflight_closure.py`
closes 24.4, both sub-phases *inside* the opening (#406). This is the
instrument that mechanically enforces *every retirement row is DONE*, and it
is the last thing that reads those rows.

Every defect filed against this phase concerns a row, an assertion, or a
population that a census failed to contain -- #390, #393, #395, #396, #401,
#402, #403, #404, #405, #411, #412, #415, #416, #419, #420, #422, #424, #425.
The final check on the ledger's own completeness was the one artifact never
scoped, so it is written as a patch rather than as bookkeeping.

THE ROW ORDER IS THE AMENDED ONE. Patch 24.15a's #404 amendment establishes
that 24.15a lands BEFORE 24.15, because 24.15's retirements are what remove
the cover masking the unsound reachability match, and a tool that fails by
reporting a retired guard as live is worst at the patch whose gate is "every
surviving evidence row protects a still-live invariant". A generator built
from the original numbering would silently re-assert the sequence that
amendment corrected. Ownership is not ordering (#402), and a row list is where
the two are easiest to confuse -- so the expected order is stated here once,
with the reason, and reordering it fails.
"""

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TASK = ROOT / "TASK.md"
REGISTRY = ROOT / "scripts" / "cranelift_feature_registry.json"
VIEW = ROOT / "docs" / "PHASE24_CLOSURE.md"
CONTRACT = ROOT / "tests" / "cranelift" / "phase24_closure_contract.tsv"

GUARD = "guard-cranelift-phase24-close"
VERSION = "phase24_closure_v1"

# The retirement rows, in the order they must appear. 24.15a precedes 24.15:
# see the module docstring. Missing, duplicated or reordered rows all fail,
# following the Phase 23 precedent at phase23_closure.py:170-179.
EXPECTED_ROWS = (
    ("24.10", "Retirement Roadmap Activation"),
    ("24.11", "Generated-C Consumer and Route Inventory"),
    ("24.12", "Frozen Expected-Behaviour Oracle Replacement"),
    ("24.12a", "Emitter-Only Parity Guard Retirement"),
    ("24.12b", "Python Parity Guard Conversion"),
    ("24.13", "Backend-Selection and Publication-Path Removal"),
    ("24.14", "C Toolchain Discovery, Error, and Temp-File Removal"),
    ("24.15a", "Reachability Instrument Repair"),
    ("24.15", "Package, Documentation, and Registry Retirement"),
    ("24.16", "Cross-Feature Residue Audit"),
    ("24.17", "Exact-Main Historical Full Qualification"),
    ("24.18", "Phase 24 Closure and Terminal State"),
)

ROW = re.compile(r"^- \[( |x)\] Patch (24\.\d+[a-z]?) — ([^—\n]+?)(?: — DONE)?$",
                 re.MULTILINE)

# The closure sentence and its boundary, stated together because the second
# half is what keeps Phase 25's scope from widening by implication.
CLOSURE_SENTENCE = (
    "Gust no longer emits C as a compiler backend; the repository still "
    "contains C under Phase 25 ownership."
)


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD}: {message}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def digest(value: object) -> str:
    return hashlib.sha256(
        json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()


def rows() -> list:
    """The retirement rows as TASK.md states them, in file order."""
    text = TASK.read_text(encoding="utf-8")
    found = []
    for mark, patch, title in ROW.findall(text):
        if patch.startswith("24.") and any(patch == p for p, _ in EXPECTED_ROWS):
            found.append((patch, title.strip(), mark == "x"))
    return found


def check_row_order() -> list:
    """Missing, duplicated or reordered rows all fail."""
    found = rows()
    seen = [patch for patch, _, _ in found]
    duplicated = sorted({p for p in seen if seen.count(p) > 1})
    require(not duplicated, f"retirement rows are duplicated: {duplicated}")

    expected = [patch for patch, _ in EXPECTED_ROWS]
    missing = [p for p in expected if p not in seen]
    require(not missing, f"retirement rows are missing: {missing}")
    extra = [p for p in seen if p not in expected]
    require(not extra, f"unexpected retirement rows: {extra}")

    require(
        seen == expected,
        "the retirement row ORDER drifted.\n"
        f"  expected: {expected}\n"
        f"  found   : {seen}\n"
        "24.15a precedes 24.15 by the #404 amendment: 24.15's retirements "
        "remove the cover masking the unsound reachability match, so the "
        "repair cannot land after them. Ownership is not ordering (#402).",
    )
    return found


def check_all_done(found: list) -> None:
    pending = [patch for patch, _, done in found if not done]
    require(
        not pending,
        f"retirement rows are not DONE: {pending}. This generator is the "
        "instrument that establishes the closure gate, not a record written "
        "alongside it, so a row that is not DONE fails here rather than being "
        "described as closed.",
    )


def check_population_accounting() -> dict:
    """#405: the Historical population, accounted member by member.

    A closure record citing a green Historical run INHERITS that run's
    population, so this is the natural -- and the last -- place the per-member
    accounting can be required rather than merely available.
    """
    accounting = ROOT / "scripts" / "phase24_native_population_accounting.py"
    require(accounting.is_file(),
            "the #405 population accounting instrument is missing")
    result = subprocess.run(
        ["python3", str(accounting), "validate"],
        cwd=ROOT, capture_output=True, text=True, check=False,
    )
    require(
        result.returncode == 0,
        "the #405 population accounting does not hold, so a closure citing a "
        f"green Historical run would inherit an unaccounted population: "
        f"{result.stdout.strip()[-300:] or result.stderr.strip()[-300:]}",
    )
    return json.loads(result.stdout[result.stdout.index("{"):
                                    result.stdout.rindex("}") + 1])


def check_historical_authority(registry: dict) -> dict:
    """The exact-main Historical Full run, recorded as identity not adjective."""
    node = registry.get("phase24_closure", {}).get(
        "authoritative_latest_historical_full")
    require(
        isinstance(node, dict),
        "no authoritative_latest_historical_full is registered. Patch 24.17 "
        "qualifies ONE run on the exact merged retirement main, and the "
        "closure cites that run by identity -- run id, full SHA, event, "
        "conclusion, job population and budgets -- because 'the run was "
        "green' is an adjective and cannot be checked later.",
    )
    for field in ("run_id", "head_sha", "event", "conclusion",
                  "unique_job_population", "budgets"):
        require(field in node,
                f"the Historical authority lacks {field}: a closure that "
                "cannot name the run it rests on rests on nothing")
    require(node["conclusion"] == "success",
            f"the authoritative Historical run did not succeed: "
            f"{node['conclusion']}")
    require(re.fullmatch(r"[0-9a-f]{40}", str(node["head_sha"])),
            "the Historical authority's head_sha must be a full SHA, not an "
            "abbreviation: an abbreviation can become ambiguous later")
    return node


def check_boundary() -> None:
    """Closing the backend is not closing Phase 25."""
    text = TASK.read_text(encoding="utf-8")
    require(
        CLOSURE_SENTENCE in text or VIEW.is_file(),
        "the closure sentence and its boundary must be stated together: "
        f"{CLOSURE_SENTENCE}",
    )


def validate() -> dict:
    found = check_row_order()
    check_all_done(found)
    population = check_population_accounting()
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    historical = check_historical_authority(registry)
    check_boundary()
    summary = {
        "version": VERSION,
        "rows": len(found),
        "order": [patch for patch, _, _ in found],
        "population": population,
        "historical_run": historical["run_id"],
        "closure_sentence": CLOSURE_SENTENCE,
    }
    summary["digest"] = digest(summary)
    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["validate", "rows"],
                        nargs="?", default="validate")
    arguments = parser.parse_args()
    if arguments.command == "rows":
        for patch, title, done in rows():
            print(f"{'DONE' if done else 'open'}\t{patch}\t{title}")
        return
    summary = validate()
    print(json.dumps(summary, indent=2, sort_keys=True))
    print(f"{GUARD}: ok")


if __name__ == "__main__":
    main()
