#!/usr/bin/env python3
"""Check the bounded S2 source contract and run its native behavior guard."""

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

from stdlib_s1_close import latest_historical, validate_successful_historical

ROOT = Path(__file__).resolve().parent.parent
ROADMAP = ROOT / "TASK_STDLIB.md"
MODULE = ROOT / "src/stdlib/byte_text.gst"
CONSUMER = ROOT / "tests/stdlib_s2_byte_text.gst"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"

TITLES = {
    0: "Opening Inventory and Boundary",
    1: "Importable Byte String Predicates",
    2: "Closure Evidence",
}
PREDICATES = {"starts_with", "ends_with", "contains"}
PRIMITIVES = {"str_eq", "str_slice", "str_find"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def check_roadmap():
    text = ROADMAP.read_text(encoding="utf-8")
    phase = text.split("## Phase S2 — Byte String Composition\n", 1)
    require(len(phase) == 2, "S2 phase heading is missing")
    status = phase[1].split("### Status\n", 1)
    require(len(status) == 2, "S2 status heading is missing")
    rows = re.findall(r"^- \[([ x])\] Patch S2\.(\d+) — (.+)$",
                      status[1].split("\n### ", 1)[0], re.M)
    require(len(rows) == 3, "S2 must have exactly three status rows")
    actual = {int(number): (mark, title) for mark, number, title in rows}
    require(set(actual) == set(TITLES), "S2 status rows must be S2.0–S2.2")
    for number, title in TITLES.items():
        require(actual[number] == ("x", f"{title} — DONE"),
                f"S2.{number} is not DONE with its declared title")
    require("### Closure record and residue\n" in phase[1],
            "S2 closure residue is missing")


def check_source_and_symbols():
    module = MODULE.read_text(encoding="utf-8")
    consumer = CONSUMER.read_text(encoding="utf-8")
    imports = re.findall(r'^import "([^"]+)" as ([A-Za-z_][A-Za-z_0-9]*);$',
                         consumer, re.M)
    require(len(imports) == 1, "S2 consumer must import one source module")
    import_path, alias = imports[0]
    require((CONSUMER.parent / import_path).resolve() == MODULE.resolve(),
            "S2 consumer import does not resolve to the byte-text module")
    calls = set(re.findall(r"\b" + re.escape(alias) +
                           r"\.([A-Za-z_][A-Za-z_0-9]*)\s*\(", consumer))
    require(calls == PREDICATES, "S2 consumer must exercise all three predicates")
    declared = set(re.findall(
        r"^func ([A-Za-z_][A-Za-z_0-9]*)\(haystack: str, needle: str\) int \{",
        module, re.M))
    require(declared == PREDICATES,
            "S2 module must expose exactly the three byte predicates")
    primitives = set(re.findall(r"\bstd\.([A-Za-z_][A-Za-z_0-9]*)\s*\(", module))
    require(primitives == PRIMITIVES, "S2 module changed its registered primitive set")
    require(not re.search(r"\b(?:unsafe|extern|std_[A-Za-z_0-9]+)\b", module),
            "S2 module added an unsafe, extern, or raw runtime symbol spelling")

    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    helpers = registry["opening_snapshots"]["phase17"]["helper_inventory"]
    for primitive in primitives:
        symbol = f"std_{primitive}"
        matches = [entry for entry in helpers if entry.get("id") == f"p17_helper_{symbol}"]
        require(len(matches) == 1 and
                matches[0].get("symbol_identity") == symbol and
                matches[0].get("source_path") == "src/runtime-rs/src/strings.rs" and
                matches[0].get("reachability") == "runtime_public_surface",
                f"{symbol} lacks its existing public Phase 17 helper registration")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--static", action="store_true",
                        help="check source contracts without rebuilding the native fixture")
    args = parser.parse_args()
    check_roadmap()
    check_source_and_symbols()
    if not args.static:
        subprocess.run(["bash", "scripts/stdlib_s2_byte_text_native.sh"],
                       cwd=ROOT, check=True)
    # The native build can take minutes; sample the live Level 3 owner after it
    # finishes so a newer queued or failed run cannot hide behind an older green.
    historical = latest_historical()
    validate_successful_historical(historical)
    print(f"guard-stdlib-s2-close: ok (Historical Full {historical['id']} "
          f"{historical['conclusion']} on main {historical['head_sha']})")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        sys.exit(f"guard-stdlib-s2-close: {error}")
