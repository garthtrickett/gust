"""Exact-head PR evidence for first-release closure; no monitoring or mutations."""
from __future__ import annotations

import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess
from urllib.parse import quote


def require(condition, message):
    if not condition:
        raise ValueError("release CI: " + message)


def path_matches(pattern, path):
    # The maintained workflow cohort uses only literals, * and **. Refuse new
    # syntax rather than silently deriving a smaller eligible population.
    require(not any(c in pattern for c in "?+[]!"), "unreviewed path-filter syntax")
    parts = []
    index = 0
    while index < len(pattern):
        if pattern[index:index + 3] == "**/":
            parts.append("(?:.*/)?")
            index += 3
        elif pattern[index:index + 2] == "**":
            parts.append(".*")
            index += 2
        elif pattern[index] == "*":
            parts.append("[^/]*")
            index += 1
        else:
            parts.append(re.escape(pattern[index]))
            index += 1
    return re.fullmatch("".join(parts), path) is not None


def workflow_trigger(text):
    """Read the repository's closed event/paths shape, not general YAML."""
    require(len(re.findall(r"^on:[ \t]*$", text, re.M)) == 1,
            "workflow event shape needs explicit review")
    lines = text.splitlines()
    start = next(i for i, line in enumerate(lines) if re.fullmatch(r"on:[ \t]*", line))
    events = []
    for line in lines[start + 1:]:
        if line and not line[0].isspace() and not line.startswith("#"):
            break
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line.startswith("  ") and not line.startswith("   "):
            require(re.fullmatch(r"  [A-Za-z_][A-Za-z_0-9-]*:[ \t]*", line),
                    "workflow event declaration needs explicit review")
        events.append(line)
    entries = [i for i, line in enumerate(events) if line == "  pull_request:"]
    require(len(entries) <= 1, "duplicated pull_request event")
    if not entries:
        return None
    block = []
    for line in events[entries[0] + 1:]:
        if line.startswith("  ") and not line.startswith("   "):
            break
        block.append(line)
    if not block:
        return []
    if block[0].startswith("    paths: ["):
        require(len(block) == 1, "inline path filter has extra keys")
        paths = ast.literal_eval(block[0].removeprefix("    paths: "))
        require(isinstance(paths, list) and paths and
                all(isinstance(value, str) and value for value in paths),
                "inline path filter is not a nonempty string list")
        for value in paths:
            path_matches(value, "")
        return paths
    require(block[0] == "    paths:" and len(block) > 1,
            "pull_request filter shape needs explicit review")
    paths = []
    for line in block[1:]:
        match = re.fullmatch(r"      - (.+)", line)
        require(match is not None, "pull_request path item needs explicit review")
        value = ast.literal_eval(match[1])
        require(isinstance(value, str) and value, "empty/non-string path filter")
        path_matches(value, "")
        paths.append(value)
    return paths


def eligible_workflows(root, changed_paths):
    names = {}
    for path in sorted((root / ".github/workflows").iterdir()):
        if path.suffix not in (".yml", ".yaml"):
            continue
        text = path.read_text()
        try:
            filters = workflow_trigger(text)
        except (ValueError, SyntaxError) as error:
            raise ValueError(str(path.relative_to(root)) + ": " + str(error)) from error
        if filters is None:
            continue
        match = re.search(r"^name:[ \t]+(.+)$", text, re.M)
        require(match is not None, "pull_request workflow has no name")
        name = ast.literal_eval(match[1]) if match[1][0] in "'\"" else match[1]
        require(name not in names, "duplicate workflow name")
        if not filters or any(path_matches(pattern, name) for name in changed_paths for pattern in filters):
            names[name] = dict(path=path.relative_to(root).as_posix(),
                               sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    require(names, "empty eligible PR workflow population")
    return names


def inversions():
    empty = "name: Example\non:\n  pull_request:\n  workflow_dispatch:\njobs:\n"
    block = "name: Example\non:\n  pull_request:\n    paths:\n      - 'compiler/**'\n      - 'scripts/*.py'\njobs:\n"
    inline = "name: Example\non:\n  pull_request:\n    paths: ['compiler/**','scripts/*.py']\njobs:\n"
    require(workflow_trigger(empty) == [] and
            workflow_trigger(block) == workflow_trigger(inline) == ["compiler/**", "scripts/*.py"],
            "workflow filter positive baseline failed")
    require(path_matches("compiler/**", "compiler/a/b.gst") and
            path_matches("**/x.gst", "x.gst") and path_matches("**/x.gst", "a/x.gst") and
            not path_matches("scripts/*.py", "scripts/nested/x.py"),
            "workflow path-match positive/negative baseline failed")
    for label, text in (
        ("new branch filter", block.replace("    paths:", "    branches:")),
        ("duplicated event", empty.replace("  pull_request:", "  pull_request:\n  pull_request:")),
        ("new event syntax", empty.replace("on:", "on: [pull_request]")),
        ("unreviewed glob", block.replace("'compiler/**'", "'compiler/?'")),
    ):
        try:
            workflow_trigger(text)
        except (ValueError, SyntaxError):
            print(label + ": REJECTED (expected unsupported trigger assertion)")
        else:
            raise ValueError(label + ": ACCEPTED")


def gh_json(*arguments):
    raw = subprocess.check_output(["gh", *arguments], text=True)
    return json.loads(raw)


def api(path):
    return gh_json("api", "repos/garthtrickett/gust/" + path)


def pages(path, field=None):
    rows = []
    page = 1
    while True:
        value = api(path + ("&" if "?" in path else "?") + f"per_page=100&page={page}")
        batch = value[field] if field else value
        require(isinstance(batch, list), "paginated API result is not a list")
        rows.extend(batch)
        if len(batch) < 100:
            return rows
        page += 1


def qualify_pull_request(root, number, qualified_tree, final_main):
    pr = api(f"pulls/{number}")
    require(pr.get("merged") is True and pr["base"]["ref"] == "main" and
            pr["merge_commit_sha"] == final_main and pr["head"]["ref"].startswith("codex/"),
            "closure PR is not the exact final-main merge")
    head = pr["head"]["sha"]
    require(api(f"git/commits/{head}")["tree"]["sha"] == qualified_tree,
            "closure PR head differs from the qualified release tree")
    files = pages(f"pulls/{number}/files")
    require(len(files) == pr["changed_files"], "PR changed-file census is incomplete")
    expected = eligible_workflows(root, [row["filename"] for row in files])
    runs = pages("actions/runs?head_sha=" + head + "&branch=" + quote(pr["head"]["ref"], safe=""),
                 "workflow_runs")
    exact = [r for r in runs if r["head_sha"] == head and r["head_branch"] == pr["head"]["ref"]]
    pull_requests = [r for r in exact if r["event"] == "pull_request"]
    require({r["name"] for r in pull_requests} == set(expected) and
            len(pull_requests) == len(expected) and
            all(r["status"] == "completed" and r["conclusion"] == "success" for r in pull_requests),
            "eligible exact-head PR workflow population did not all succeed")
    trusted = [r for r in exact if r["event"] == "push" and r["name"] == "Codex Trusted Gate"]
    require(trusted and all(r["status"] == "completed" and r["conclusion"] == "success" for r in trusted),
            "exact-head Trusted Actor workflow did not succeed")
    checks = pages(f"commits/{head}/check-runs", "check_runs")
    require(any(r["name"] == "Codex / Trusted actor" and r["head_sha"] == head and
                r["status"] == "completed" and r["conclusion"] == "success" for r in checks),
            "required Trusted Actor check did not succeed")
    query = """query($number:Int!,$cursor:String){
      repository(owner:"garthtrickett",name:"gust"){pullRequest(number:$number){
        headRefOid reviewThreads(first:100,after:$cursor){
          pageInfo{hasNextPage endCursor} nodes{isResolved}}}}}"""
    cursor = None
    thread_count = 0
    while True:
        arguments = ["api", "graphql", "-f", "query=" + query, "-F", "number=" + str(number)]
        if cursor is not None:
            arguments += ["-f", "cursor=" + cursor]
        value = gh_json(*arguments)["data"]["repository"]["pullRequest"]
        require(value["headRefOid"] == head, "PR head moved during review verification")
        threads = value["reviewThreads"]
        require(all(row["isResolved"] for row in threads["nodes"]), "unresolved review conversation")
        thread_count += len(threads["nodes"])
        if not threads["pageInfo"]["hasNextPage"]:
            break
        cursor = threads["pageInfo"]["endCursor"]
    decisions = {}
    for review in pages(f"pulls/{number}/reviews"):
        if review["state"] in ("APPROVED", "CHANGES_REQUESTED", "DISMISSED"):
            decisions[review["user"]["id"]] = review["state"]
    require("CHANGES_REQUESTED" not in decisions.values(), "unresolved requested review changes")
    return dict(pr=number, qualified_head=head, final_main=final_main,
                qualified_tree=qualified_tree, eligible_workflows=expected,
                workflows=[{key: r[key] for key in
                    ("id", "head_sha", "head_branch", "name", "event", "status", "conclusion")}
                    for r in pull_requests + trusted], resolved_threads=thread_count,
                rules=api("rules/branches/main"))
