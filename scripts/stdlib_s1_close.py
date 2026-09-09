#!/usr/bin/env python3
"""Check S1 closure bookkeeping; runtime contracts remain with their own guards.

The old shell check searched forty lines past each CR heading, allowing the next
request to supply its owner, and stopped enumerating at CR-15. Its closure-only
branch also accepted a failed Historical Full citation. Parse bounded sections
and require live successful evidence when S1.12 is actually marked DONE.
"""

import json
import os
from pathlib import Path
import re
import sys
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent.parent
REPO = "garthtrickett/gust"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def section(text, heading):
    match = re.search(r"^" + re.escape(heading) + r"\n(.*?)(?=^#{1,3} |\Z)",
                      text, re.M | re.S)
    require(match is not None, f"Missing section: {heading}")
    return match[1]


def validate_roadmap(text):
    status = section(text, "## Status")
    rows = re.findall(r"^- \[([ x])\] Patch S1\.(\d+) — (.+)$", status, re.M)
    require(len(rows) == 13 and {int(row[1]) for row in rows} == set(range(13)),
            "Status must contain S1.0 through S1.12 exactly once")
    require(all(title.endswith(" — DONE") == (mark == "x")
                for mark, _, title in rows), "Status DONE suffix disagrees with checkbox")
    pending = {int(number) for mark, number, _ in rows if mark == " "}
    closed = 12 not in pending
    require(not closed or not pending, "S1.12 DONE while another patch is pending")
    section(text, "## Closure gate")
    outstanding = section(text, "### Outstanding, with owners")
    owned = re.findall(r"^\| S1\.(\d+) [^|]+\|[^|]+\| ([^|]+)\|$", outstanding, re.M)
    require(len(owned) == len(pending) and
            {int(number) for number, _ in owned} == pending and
            all(owner.strip() == "Stdlib lane" for _, owner in owned),
            "Outstanding table must name exactly the pending patches and their owner")
    require(section(text, "### Residue — what a normal program still cannot express safely").strip(),
            "Residue list is empty")
    section(text, "### What closure requires")

    requests = re.findall(r"^### CR-(\d+) — ", text, re.M)
    require(len(requests) == len(set(requests)) and
            set(map(int, requests)) >= set(range(1, 22)),
            "Coordination request sections are missing or duplicated")
    dispositions = section(text, "### Coordination dispositions")
    entries = re.findall(r"^\| CR-(\d+) \| ([^|]+) \| ([^|]+) \| ([^|]+) \|$",
                         dispositions, re.M)
    require(len(entries) == len(requests) and {r[0] for r in entries} == set(requests),
            "Every CR section must have exactly one disposition row")
    for number, state, owner, destination in entries:
        require(state in {"RESOLVED", "SUPERSEDED", "SCHEDULED", "DEFERRED", "BLOCKING"},
                f"CR-{number} has an invalid disposition")
        require(owner.strip().lower() not in {"", "-", "none", "unowned", "unknown", "tbd"} and destination.strip() and
                re.search(r"Phase\s*S?\d|Track A|CR-\d", destination),
                f"CR-{number} needs an owner and named phase or successor")
        require(not closed or state != "BLOCKING", f"S1.12 DONE while CR-{number} blocks")

    if not closed:
        return pending, None
    evidence = section(text, "### Level 3 evidence")
    runs = re.findall(r"^\| Cranelift Historical Full \| ([1-9][0-9]*) \| ([0-9a-f]{40})"
                      r" \| completed \| success \|$", evidence, re.M)
    require(len(runs) == 1 and evidence.count("| Cranelift Historical Full |") == 1,
            "Closure needs one paired Level 3 run ID, SHA, completed success")
    return pending, runs[0]


def validate_historical(citation, run):
    require(str(run.get("id")) == citation[0] and run.get("head_sha") == citation[1],
            "Level 3 citation differs from the cited run")
    validate_successful_historical(run)


def validate_successful_historical(run):
    require(run.get("head_branch") == "main" and
            run.get("path") == ".github/workflows/cranelift-historical-full.yml" and
            run.get("status") == "completed" and run.get("conclusion") == "success",
            "Main Historical Full has not completed successfully")


def github_api(path):
    url = f"https://api.github.com/repos/{REPO}/actions/{path}"
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "gust-stdlib-s1-close"}
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    with urlopen(Request(url, headers=headers), timeout=30) as response:
        return json.load(response)


def latest_historical():
    runs = github_api("workflows/cranelift-historical-full.yml/runs?branch=main&per_page=1")["workflow_runs"]
    require(len(runs) == 1, "No main Historical Full run exists")
    return runs[0]


def main():
    pending, citation = validate_roadmap((ROOT / "TASK_STDLIB.md").read_text())
    if citation:
        validate_historical(citation, github_api(f"runs/{citation[0]}"))
        # The closure citation is historical. A later successful nightly must
        # not force every future PR to rewrite it, but a new red/queued run
        # cannot be hidden behind the older green citation.
        validate_successful_historical(latest_historical())
    print(f"S1 closure bookkeeping: {len(pending)} pending patches; every CR accounted for")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError) as error:
        sys.exit(f"guard-stdlib-s1-close: {error}")
