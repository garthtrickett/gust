#!/usr/bin/env python3
"""Validate the Patch 18.18 deferral audit and rejection-class reachability."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase18-deferral-audit"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
REVIEW = ROOT / "tests/cranelift/phase18_deferral_review.txt"

REQUIRED_FIELDS = ("capability_owner", "diagnostic_owner", "reason",
                   "prerequisite", "rejection_code", "phase18_rows")


def read_corpus(patterns: tuple[str, ...], code_only: bool = False) -> str:
    """Concatenate every file matching the patterns, so a class can be looked for.

    With code_only, comment lines are dropped first. A class named only in a
    comment is not forced by anything -- and since this file is full of comments
    that name classes, a plain substring search over the test corpus would
    happily accept prose as proof. That is the very confusion the audit exists
    to remove, one level up.
    """
    chunks = []
    for pattern in patterns:
        for path in sorted(ROOT.glob(pattern)):
            if not path.is_file():
                continue
            text = path.read_text()
            if code_only:
                text = "\n".join(
                    line for line in text.splitlines()
                    if not line.lstrip().startswith(("//", "#"))
                )
            chunks.append(text)
    return "\n".join(chunks)


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD}: {message}")


def check() -> None:
    registry = json.loads(REGISTRY.read_text())
    authority = registry.get("phase18_deferrals")
    if not isinstance(authority, dict) or authority.get("version") != "phase18_deferrals_v1":
        fail("deferral authority missing")

    opening_rows = {row["id"] for row in
                    registry["opening_snapshots"]["phase18"]["entries"]}

    deferrals = authority["deferrals"]
    if not deferrals:
        fail("the audit declares no deferrals; Phase 18 does not close everything")

    seen_ids: set[str] = set()
    for entry in deferrals:
        identifier = entry.get("deferral_id", "<unnamed>")
        for field in REQUIRED_FIELDS:
            if not entry.get(field):
                fail(f"{identifier}: missing {field}")
        if not identifier.startswith("p19_"):
            fail(f"{identifier}: a deferral must name the phase that will carry it")
        if identifier in seen_ids:
            fail(f"{identifier}: declared twice")
        seen_ids.add(identifier)

        # A deferral is only narrow if it points at the Phase 18 rows it comes
        # from. A deferral attached to no row is an open-ended promise.
        #
        # These are Patch 18.0 OPENING-ROW ids, a separate namespace from the
        # phase18_* authority keys. An earlier version of this check mapped
        # p18_x -> phase18_x and looked in the registry root, which is simply the
        # wrong namespace: it made correct rows look broken.
        for row in entry["phase18_rows"]:
            if row not in opening_rows:
                fail(f"{identifier}: names Phase 18 opening row {row}, which does not exist")
        # Planner and verifier must be distinct: the component that plans a
        # capability may not also be the one that certifies it arrived.
        if entry["capability_owner"] == entry["diagnostic_owner"]:
            fail(f"{identifier}: the same owner both plans and verifies the capability")

    # Reachability audit. `relocation_symbol_missing` was declared policy that no
    # input could ever reach, because a shared helper rejected the empty value
    # first. A declared rejection class nothing can force is that same defect
    # wearing a different name.
    #
    # "Emitted" means emitted AT A REFUSAL SITE. An earlier draft of this guard
    # tested for the class name anywhere in the sources, and passed classes that
    # appear only inside the worker's REJECTION_CLASSES vocabulary array -- a
    # declaration of the word, not a use of it. That is exactly the confusion the
    # audit exists to catch, so the match is anchored to the emission syntax.
    #
    # There is deliberately no bare allowlist. Every declared class is one of
    # four things, and each carries its own obligation.
    taxonomy = authority["rejection_taxonomy"]
    gst = (ROOT / "compiler/mir_target_authority.gst").read_text()
    rust = (ROOT / "compiler/experiments/cranelift/src/target_authority.rs").read_text()
    # Everything that can FORCE a class: the Gust smoke entries, the Level 2
    # parity scripts, and the shell negative-test suites that drive the
    # registry-level contract guards.
    forced = read_corpus(("compiler/*smoke_test_entry.gst",
                          "scripts/phase18_*parity*",
                          "scripts/phase18_*smoke*"), code_only=True)
    registry_text = json.dumps(registry)

    def emitted_at_a_refusal_site(name: str) -> bool:
        return (f'reason_code = std.Clone(ctx, "{name}")' in gst
                or re.search(r'error\(\s*"' + re.escape(name) + r'"', rust) is not None)

    declared: set[str] = set()
    for key, value in registry.items():
        if key.startswith("phase18_") and isinstance(value, dict):
            declared.update(value.get("rejection_classes", []))

    classified = {entry["rejection_class"] for entry in taxonomy}
    if classified != declared:
        missing = sorted(declared - classified)
        if missing:
            fail(f"these rejection classes carry no taxonomy entry: {missing}")
        fail(f"the taxonomy classifies classes that are not declared: "
             f"{sorted(classified - declared)}")

    deferral_ids = {entry["deferral_id"] for entry in deferrals}
    for entry in taxonomy:
        name, kind = entry["rejection_class"], entry["kind"]
        if not entry.get("justification"):
            fail(f"{name}: classified {kind} with no justification")

        if kind == "emittable":
            if not emitted_at_a_refusal_site(name):
                fail(f"{name}: classified emittable but no authority module emits it "
                     "at a refusal site")
            if name not in forced:
                fail(f"{name}: classified emittable but no negative test forces it")

        elif kind == "architectural_ban":
            if emitted_at_a_refusal_site(name):
                fail(f"{name}: classified an architectural ban but an authority module "
                     "emits it as a runtime refusal; classify it emittable")
            # The named guard must exist AND mention the ban it claims to enforce.
            # Naming a guard that never refers to the class is the same empty
            # gesture as declaring the class and never using it.
            guard = entry.get("enforcing_guard", "")
            guard_path = ROOT / guard if guard else None
            if not guard or guard_path is None or not guard_path.is_file():
                fail(f"{name}: architectural ban names no guard file that exists")
            if name not in guard_path.read_text():
                fail(f"{name}: guard {guard} does not mention the ban it enforces")

        elif kind == "guard_enforced":
            # A registry-level property no compiler refusal can raise. The named
            # contract guard must exist and actually raise the class, and a
            # negative test must still force it -- being enforced by a guard is
            # not an excuse for going untested.
            guard = entry.get("enforcing_guard", "")
            guard_path = ROOT / guard if guard else None
            if not guard or guard_path is None or not guard_path.is_file():
                fail(f"{name}: guard-enforced but names no guard file that exists")
            if name not in guard_path.read_text():
                fail(f"{name}: guard {guard} does not raise the class it is said to raise")
            if name not in forced:
                fail(f"{name}: guard-enforced but no negative test forces it")

        elif kind == "diagnostic_value":
            # Not a refusal: a value declared rows carry. It must actually be
            # carried by one, or it is vocabulary pretending to be in use.
            if f'": "{name}"' not in registry_text:
                fail(f"{name}: classified a diagnostic value but no declared row carries it")

        elif kind == "vocabulary_only":
            if emitted_at_a_refusal_site(name):
                fail(f"{name}: classified vocabulary-only but something emits it")
            if entry.get("deferral_id") not in deferral_ids:
                fail(f"{name}: vocabulary with no instance must name a deferral that "
                     "would introduce one")

        else:
            fail(f"{name}: unknown taxonomy kind {kind!r}")

    if authority["audit_policy"] != (
        "a_deferral_names_its_carrying_phase_its_capability_owner_its_diagnostic_owner_"
        "and_the_phase18_rows_it_comes_from"
    ):
        fail("audit policy drifted")

    rendered = render(authority)
    if not REVIEW.is_file() or REVIEW.read_text() != rendered:
        fail("generated review is stale; run --write")
    print(f"{GUARD}: ok ({len(deferrals)} narrow deferrals, "
          f"{len(taxonomy)} rejection classes each emitted+forced, banned, carried, or deferred, level1)")


def render(authority: dict) -> str:
    taxonomy = authority["rejection_taxonomy"]
    counts: dict[str, int] = {}
    for entry in taxonomy:
        counts[entry["kind"]] = counts.get(entry["kind"], 0) + 1
    lines = ["Patch 18.18 — Phase 18 Deferral Audit\n",
             f"deferrals\t{len(authority['deferrals'])}\n",
             f"rejection_classes_classified\t{len(taxonomy)}\n"]
    # The breakdown is the headline finding, so it belongs in the generated
    # evidence rather than only in a commit message that nothing checks.
    for kind in sorted(counts):
        lines.append(f"kind:{kind}\t{counts[kind]}\n")
    lines.append("\n")
    for entry in authority["deferrals"]:
        lines.append(
            f"{entry['deferral_id']}\n"
            f"\treason\t{entry['reason']}\n"
            f"\tprerequisite\t{entry['prerequisite']}\n"
            f"\tcapability owner\t{entry['capability_owner']}\n"
            f"\tdiagnostic owner\t{entry['diagnostic_owner']}\n"
            f"\trejection code\t{entry['rejection_code']}\n"
            f"\tfrom rows\t{', '.join(entry['phase18_rows'])}\n"
        )
    return "".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write:
        registry = json.loads(REGISTRY.read_text())
        REVIEW.write_text(render(registry["phase18_deferrals"]))
    check()


if __name__ == "__main__":
    main()
