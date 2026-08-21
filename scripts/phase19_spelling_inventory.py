#!/usr/bin/env python3
"""Validate and project the Patch 19.1 identifier-spelling decision inventory.

Report-only. Nothing here changes behaviour; it records every place the two
compilers decide brand identity, arena-ness, or argument representation from an
identifier's spelling, so Patch 19.2 onward works from a list.

The validator deliberately re-derives rather than trusts:

  * every cited line is re-read and must still hold a brand spelling, because
    CR-2's own citations had drifted by one to two lines -- and by roughly
    twenty in compiler/typechecker.gst -- before this inventory was written;
  * the regression surface is a dated measurement, reported and re-derived but
    NOT asserted. An earlier version required the recorded counts to equal the
    live ones. That was wrong: compiler/*.gst is shared, so any lane adding an
    Index[...] anywhere turned this Level 1 guard red on a PR that had nothing
    to do with Phase 19 -- which it did, within an hour of landing. A shared
    counter is not an invariant one lane may assert.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase19-spelling-inventory"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE19_SPELLING_INVENTORY.md"
REVIEW_PATH = "compiler/CRANELIFT_PHASE19_SPELLING_INVENTORY.md"

SITE_FIELDS = {
    "id", "compiler", "source_path", "line", "classification", "decision",
    "available_type_information", "sufficiency", "counterpart", "divergence",
}
COMPILERS = {"rust_host", "self_hosted"}
CLASSIFICATIONS = {"type_name_erasure", "classification_override"}
# Ordered least to most work: an inventory that classified everything as the
# cheapest option would be suspicious, so the projection reports the spread.
SUFFICIENCY = {
    "available_in_scope",
    "available_after_resolution",
    "requires_new_authority",
    "unavailable_at_this_stage",
}
DIVERGENCES = {"none", "scan_order", "suffix_set", "absent_in_counterpart"}

BRAND_SPELLING = re.compile(r'"(arena|ctx|connCtx|Arena|Any|a|os_Arena|main_ctx)"')


class Error(Exception):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def measure_surface() -> dict:
    """Recount the regression surface from the tree, every run."""
    files = sorted(ROOT.joinpath("compiler").glob("*.gst"))
    occurrences = 0
    declaration_files = 0
    branded = 0
    for path in files:
        text = path.read_text(encoding="utf-8")
        count = len(re.findall(r"Index\[", text))
        occurrences += count
        if count:
            declaration_files += 1
        branded += len(re.findall(r"Index\[[A-Za-z_.]+,\s*ctx\]", text))
    return {
        "measured_by": f"{GUARD}",
        "gst_files_scanned": len(files),
        "index_declaration_files": declaration_files,
        "index_occurrences": occurrences,
        "brand_parameterised_index_declarations": branded,
    }


def validate(registry: dict) -> dict:
    snap = registry.get("phase19_spelling_inventory")
    require(isinstance(snap, dict), "Phase 19 spelling inventory missing")

    require(snap["inventory_version"] == "phase19_spelling_inventory_v1",
            "Phase 19 spelling inventory version drifted")
    require(snap["status"] == "ready_for_patch19_2", "Phase 19 spelling inventory status drifted")
    require(snap["next_patch"] == "19.2", "Phase 19 spelling inventory next patch drifted")
    require(snap["policy"] == "report_only_no_behaviour_change",
            "Patch 19.1 must remain report-only")
    require(snap["review_view"] == REVIEW_PATH, "Phase 19 spelling review view drifted")

    # The inventory hangs off the opening it rebases on.
    opening = registry.get("opening_snapshots", {}).get("phase19", {})
    require(opening.get("opening_version") == snap["opening_version"],
            "Phase 19 spelling inventory does not trace to the Phase 19 opening")

    sites = snap["sites"]
    require(sites, "Phase 19 spelling inventory records no sites")
    ids = set()
    for site in sites:
        name = site.get("id")
        require(set(site) == SITE_FIELDS, f"site {name!r} has unexpected fields")
        require(name not in ids, f"duplicate site {name!r}")
        ids.add(name)
        require(site["compiler"] in COMPILERS, f"site {name!r} names an unknown compiler")
        require(site["classification"] in CLASSIFICATIONS,
                f"site {name!r} has an unknown classification")
        require(site["sufficiency"] in SUFFICIENCY, f"site {name!r} has an unknown sufficiency")
        require(site["divergence"] in DIVERGENCES, f"site {name!r} has an unknown divergence")

        # Re-read the cited line. Citations rot; this is how we find out.
        path = ROOT / site["source_path"]
        require(path.is_file(), f"site {name!r} cites a missing file {site['source_path']}")
        lines = path.read_text(encoding="utf-8").split("\n")
        index = site["line"] - 1
        require(0 <= index < len(lines),
                f"site {name!r} cites line {site['line']} beyond {site['source_path']}")
        window = "\n".join(lines[max(0, index - 2):index + 3])
        require(BRAND_SPELLING.search(window) is not None,
                f"site {name!r} cites {site['source_path']}:{site['line']}, "
                "which no longer holds a brand spelling -- the citation has drifted")

    for site in sites:
        counterpart = site["counterpart"]
        if counterpart is None:
            require(site["divergence"] == "absent_in_counterpart",
                    f"site {site['id']!r} has no counterpart but does not say so")
            continue
        require(counterpart in ids, f"site {site['id']!r} names unknown counterpart {counterpart!r}")
        other = next(s for s in sites if s["id"] == counterpart)
        require(other["compiler"] != site["compiler"],
                f"site {site['id']!r} names a counterpart in its own compiler")

    require({site["compiler"] for site in sites} == COMPILERS,
            "the inventory must cover both compilers")

    # The surface is a dated observation, not an invariant. It is re-derived for
    # the projection so the review always shows the live figure, and the recorded
    # figure is kept beside it as the value at the time of the inventory. Neither
    # is asserted against the other: this file is shared with every other lane.
    recorded = snap["regression_surface"]
    require(recorded["measured_at_commit_subject"],
            "the recorded surface must say when it was measured")
    for key in ("gst_files_scanned", "index_declaration_files",
                "index_occurrences", "brand_parameterised_index_declarations"):
        require(isinstance(recorded[key], int) and recorded[key] > 0,
                f"recorded surface {key} is not a positive count")

    return snap


def render(snap: dict) -> str:
    sites = snap["sites"]
    surface = snap["regression_surface"]

    def tally(field):
        counts = {}
        for site in sites:
            counts[site[field]] = counts.get(site[field], 0) + 1
        return counts

    lines = [
        "# Cranelift Phase 19 Identifier-Spelling Decision Inventory",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase19_spelling_inventory.py project`. Do not edit by hand.",
        "",
        "Report-only. Nothing in Patch 19.1 changes behaviour.",
        "",
        f"- Inventory version: `{snap['inventory_version']}`",
        f"- Status: `{snap['status']}`",
        f"- Sites: `{len(sites)}`",
        "",
        "## Regression surface",
        "",
        "A dated measurement, not an invariant. `compiler/*.gst` is shared with",
        "every lane, so these counts move for reasons that have nothing to do",
        "with Phase 19 and are reported rather than asserted.",
        "",
        f"Measured at {surface['measured_at_commit_subject']}. Run",
        "`scripts/phase19_spelling_inventory.py surface` for the live figures;",
        "they are deliberately not baked in here, because a generated artifact",
        "holding a live count is checked for staleness and so is just the same",
        "brittleness one step removed.",
        "",
        "| Measure | Count |",
        "| --- | --- |",
        f"| `compiler/*.gst` files scanned | {surface['gst_files_scanned']} |",
        f"| Files declaring `Index[...]` | {surface['index_declaration_files']} |",
        f"| `Index[...]` occurrences | {surface['index_occurrences']} |",
        f"| Brand-parameterised `Index[T, ctx]` | {surface['brand_parameterised_index_declarations']} |",
        "",
        "## Where the type information already is",
        "",
        "| Sufficiency | Sites | Meaning |",
        "| --- | --- | --- |",
    ]
    meaning = {
        "available_in_scope": "the resolved type is already at the site; the spelling is used anyway",
        "available_after_resolution": "the type exists by this stage but is not threaded to the site",
        "requires_new_authority": "no declared brand or arena kind exists to consult yet",
        "unavailable_at_this_stage": "the decision runs before type resolution",
    }
    counts = tally("sufficiency")
    for key in ("available_in_scope", "available_after_resolution",
                "requires_new_authority", "unavailable_at_this_stage"):
        lines.append(f"| `{key}` | {counts.get(key, 0)} | {meaning[key]} |")

    lines += ["", "## Cross-compiler divergence", "",
              "| Divergence | Sites | Meaning |", "| --- | --- | --- |"]
    dmeaning = {
        "none": "the two compilers make this decision the same way",
        "scan_order": "same names, different scan order, and both scan first-match-wins",
        "suffix_set": "the two sites accept different suffix sets",
        "absent_in_counterpart": "one compiler makes this decision and the other does not",
    }
    dcounts = tally("divergence")
    for key in ("none", "scan_order", "suffix_set", "absent_in_counterpart"):
        lines.append(f"| `{key}` | {dcounts.get(key, 0)} | {dmeaning[key]} |")

    lines += ["", "## Sites", "",
              "| ID | Compiler | Source | Kind | Type information available | Sufficiency | Divergence |",
              "| --- | --- | --- | --- | --- | --- | --- |"]
    for site in sites:
        lines.append(
            f"| `{site['id']}` | {site['compiler']} "
            f"| `{site['source_path']}:{site['line']}` | {site['classification']} "
            f"| {site['available_type_information']} | `{site['sufficiency']}` "
            f"| `{site['divergence']}` |")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review", "surface"))
    args = parser.parse_args()
    registry = json.loads(REGISTRY.read_text())
    try:
        snap = validate(registry)
        if args.command == "project":
            REVIEW.write_text(render(snap), encoding="utf-8")
        elif args.command == "surface":
            recorded = snap["regression_surface"]
            for key, value in measure_surface().items():
                if key == "measured_by":
                    continue
                print(f"{key}: recorded={recorded[key]} live={value}")
        elif args.command == "check-review":
            require(REVIEW.is_file(), f"missing generated review: {REVIEW_PATH}")
            require(REVIEW.read_text(encoding="utf-8") == render(snap),
                    "generated Phase 19 spelling inventory is stale; run `project`")
    except Error as error:
        print(f"{GUARD}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
