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

# REGISTRATION NOTE (24.18): this guard has no justfile recipe, no test
# level and no workflow YET, and that is deliberate. It is designed to
# REFUSE until every retirement row is DONE, so wiring it into PR CI now
# would turn every pull request red -- including the six that have to
# merge before the rows CAN be DONE. Registering a must-fail guard ahead
# of the work it gates blocks the work it gates.
#
# It is registered in the atomic closure PR, which is the first moment
# its passing is possible. The Phase 23 precedent reads the same way:
# guard-cranelift-phase23-close is Level 1 and green because Phase 23 is
# closed, not because it was wired up early.

import argparse
import hashlib
import importlib.util
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
    # Surfaced by the review fix above: both landed (#429, #435) and both sit
    # in the Status block between 24.12b and 24.13, but neither was in this
    # expected set. While `rows()` filtered to EXPECTED_ROWS they were simply
    # invisible here -- two retirement patches a closure instrument is meant
    # to account for and could not see.
    ("24.12c", "Frozen Oracle Capture for the Uncovered Population"),
    ("24.12d", "Frozen Oracle Capture for the Default-Route Flip"),
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
# The sentence Phase 24 was scoped to say was "Gust no longer emits C as a
# compiler backend". Measured on the merged retirement main, that is FALSE:
# `./gust --backend mir-to-c` emits C. Closing on it would make the repository
# assert something its own compiler contradicts, which is the defect this
# phase spent five patches removing.
#
# What the phase DID achieve, verified rather than asserted:
#   ./gust <src>                            -> native, emits no C
#   ./gust --backend bootstrap-emitter      -> REFUSED without the authority
#   GUST_BOOTSTRAP_EMITTER=1 ... emitter    -> emits C, bootstrap-only
#   ./gust --backend mir-to-c               -> emits C, deprecated, retained
#
# So the publication path is closed and the default route is native; what
# survives is the deprecated explicit spelling, retained because 28 registered
# live-C cases still invoke it and 25 of them are Stdlib-owned (AGENTS.md
# line 98). Their removal is sequenced after issue #398.
#
# The sentence is narrowed to what is true and the residue is bounded below,
# so the claim cannot quietly widen. A later patch restores the unqualified
# sentence when #398 closes.
CLOSURE_SENTENCE = (
    "Gust no longer emits C on any default or publication route: the default "
    "route is native and the bootstrap emitter is refused without its "
    "authority. The deprecated explicit spellings are retained for 28 "
    "registered live-C cases pending issue #398, and the repository still "
    "contains C under Phase 25 ownership."
)
RETAINED_LIVE_C_CASES = 28
# The boundary half of the closure sentence, required in TASK.md in its own
# right so "the sentence and its boundary are stated together" is checked
# rather than assumed.
PHASE25_BOUNDARY = "the repository still contains C under Phase 25 ownership"


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
    # Raised in review on #427: filtering to EXPECTED_ROWS here dropped any
    # unexpected Phase 24 row BEFORE check_row_order() computed `extra`, so
    # that check was permanently empty and a new retirement patch could be
    # added to the roadmap and ignored by check_all_done().
    #
    # Every row in Phase 24's own `## Status` block is collected instead, and
    # the comparison against EXPECTED_ROWS happens where it can fail. Scoped
    # to that block rather than to the whole file: Phase 24's pre-retirement
    # patches (24.0 through 24.4) carry status rows elsewhere and are not
    # retirement rows, so collecting them would report thirty "unexpected"
    # rows that are nothing of the kind.
    start = text.find("# Phase 24 — Generated-C Backend Retirement")
    require(start != -1, "the Phase 24 roadmap header is missing from TASK.md")
    status = text.find("\n## Status", start)
    require(status != -1, "the Phase 24 status block is missing from TASK.md")
    end = text.find("\n## ", status + 1)
    block = text[status:end if end != -1 else len(text)]
    for mark, patch, title in ROW.findall(block):
        if patch.startswith("24."):
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


def check_retained_residue() -> dict:
    """The retained explicit spellings are bounded, not open-ended.

    The closure sentence admits an exception, so the exception has to be
    measured here or it is an escape hatch. The live-C surface is the same
    population Patch 23.10 froze and every retirement patch has reduced; if it
    grows, the narrowed sentence stops being true and this closure fails
    rather than ageing into a false claim.
    """
    spec = importlib.util.spec_from_file_location(
        "_frozen_surface", ROOT / "scripts" / "phase23_mir_to_c_frozen_surface.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    cases = module.live_c_case_rows()
    require(
        len(cases) == RETAINED_LIVE_C_CASES,
        f"the retained live-C surface is {len(cases)}, not "
        f"{RETAINED_LIVE_C_CASES}. The closure sentence names an exact "
        "residue; a different one means the exception moved and the sentence "
        "has to be re-derived, not re-pinned.",
    )
    owners = sorted({str(row.get("owner", "?")) for row in cases})
    return {"retained_live_c_cases": len(cases), "owners": owners}


def check_boundary() -> None:
    """Closing the backend is not closing Phase 25.

    Raised in review on #438: this was `CLOSURE_SENTENCE in text or
    VIEW.is_file()`, and once 24.18 started requiring the view to exist the
    `or` was permanently satisfied -- the TASK.md half became unenforced and
    the sentence could be deleted from the roadmap with every authoritative
    check still green. The closure contract names TASK.md as the boundary
    evidence, so that row was claiming something nothing verified.

    Required independently now. The view comparison proves the sentence is in
    the generated record; this proves it is in the roadmap the record is
    generated from.
    """
    text = TASK.read_text(encoding="utf-8")
    require(
        CLOSURE_SENTENCE in text,
        "the closure sentence is not stated in TASK.md, so the roadmap does "
        "not carry the claim this closure rests on: "
        f"{CLOSURE_SENTENCE}",
    )
    require(
        PHASE25_BOUNDARY in text,
        "the closure sentence is stated without its Phase 25 boundary: "
        "closing the generated-C backend is not closing the bootstrap C that "
        f"Phase 25 owns. Expected: {PHASE25_BOUNDARY}",
    )


def validate() -> dict:
    found = check_row_order()
    check_all_done(found)
    population = check_population_accounting()
    residue = check_retained_residue()
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    historical = check_historical_authority(registry)
    check_boundary()
    summary = {
        "version": VERSION,
        "rows": len(found),
        "order": [patch for patch, _, _ in found],
        "population": population,
        "retained_residue": residue,
        "historical_run": historical["run_id"],
        "closure_sentence": CLOSURE_SENTENCE,
    }
    summary["digest"] = digest(summary)
    return summary



def contract_rows() -> list:
    """The closure contract, read from its TSV rather than duplicated here."""
    require(CONTRACT.is_file(),
            f"the closure contract is missing: {CONTRACT.name}. The gate has "
            "to be stated where it can be read, not only asserted in code.")
    lines = [l for l in CONTRACT.read_text(encoding="utf-8").splitlines() if l.strip()]
    require(lines and lines[0].split("\t") == ["kind", "requirement", "evidence", "level"],
            "the closure contract header drifted")
    rows_out = []
    for line in lines[1:]:
        cells = line.split("\t")
        require(len(cells) == 4,
                f"the closure contract row is malformed: {line[:60]}")
        rows_out.append(dict(zip(("kind", "requirement", "evidence", "level"), cells)))
    return rows_out


def render(summary: dict, closure: dict) -> str:
    """The closure view, generated from registry authority."""
    historical = closure["authoritative_latest_historical_full"]
    lines = [
        "# Phase 24 Closure — Generated-C Backend Retirement",
        "",
        "<!-- Generated by scripts/phase24_closure.py from the Cranelift feature",
        "     registry. Do not edit by hand; edit the registry and regenerate. -->",
        "",
        f"Status: `{closure.get('status', 'unknown')}`",
        "",
        CLOSURE_SENTENCE,
        "",
        "## Retirement rows",
        "",
        "| Patch | Title | State |",
        "| --- | --- | --- |",
    ]
    for patch, title, done in rows():
        lines.append(f"| `{patch}` | {title} | {'DONE' if done else 'open'} |")
    lines += [
        "",
        "## Authoritative Historical Full run",
        "",
        f"- Run: `{historical['run_id']}`",
        f"- Head SHA: `{historical['head_sha']}`",
        f"- Event: `{historical['event']}`",
        f"- Conclusion: `{historical['conclusion']}`",
        f"- Unique job population: `{historical['unique_job_population']}`",
        f"- Budgets: `{historical['budgets']}`",
        "",
        "## Closure gate",
        "",
        "| Kind | Requirement | Evidence | Level |",
        "| --- | --- | --- | --- |",
    ]
    for row in contract_rows():
        lines.append(
            f"| `{row['kind']}` | {row['requirement']} | {row['evidence']} | "
            f"{row['level']} |")
    lines += [
        "",
        "## Population",
        "",
        f"- Baseline members: `{summary['population'].get('baseline', '?')}`",
        f"- Live members: `{summary['population'].get('live', '?')}`",
        "",
        f"Digest: `{summary['digest']}`",
        "",
    ]
    return "\n".join(lines) + "\n"

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["validate", "rows", "project"],
                        nargs="?", default="validate")
    arguments = parser.parse_args()
    if arguments.command == "rows":
        for patch, title, done in rows():
            print(f"{'DONE' if done else 'open'}\t{patch}\t{title}")
        return
    summary = validate()
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    view = render(summary, registry["phase24_closure"])
    if arguments.command == "project":
        VIEW.write_text(view, encoding="utf-8")
        print(f"{GUARD}: projected {VIEW.name}")
        return
    # Staleness: the view is authority-derived or it is decoration. A closure
    # record edited by hand can say anything, which is the failure this whole
    # phase has been removing.
    require(VIEW.is_file(),
            f"the closure view is missing: {VIEW.name}. Run `project`.")
    require(VIEW.read_text(encoding="utf-8") == view,
            f"the closure view is stale: {VIEW.name} was not generated from "
            "the registry authority it cites. Run `project`.")
    print(json.dumps(summary, indent=2, sort_keys=True))
    print(f"{GUARD}: ok")


if __name__ == "__main__":
    main()
