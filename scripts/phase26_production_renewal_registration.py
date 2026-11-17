#!/usr/bin/env python3
"""Exact additive epoch2 successor; old epoch1 assertions retain their inputs.

Generation is a final, signature-required step. An unsigned working tree cannot
be enrolled or published by treating a placeholder as a public signature.
"""
from __future__ import annotations

import base64
import copy
from functools import lru_cache
import gzip
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
BASE = "9df2eb10291caa6a76e5cc1c2c20a7488a54e67d"
KEY = "production_epoch2_renewal_successor_v1"
GUARD = "guard-cranelift-phase26-production-renewal"
STATE = "GUST_LANE_STATE.md"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
HISTORY = "compiler/experiments/cranelift/production/epoch1/"
BASELINE = HISTORY + "predecessor-baseline-v3.json.gz"
BASELINE_SHA256 = "86f54ea30392f3cab6ffd05eabac6c109190814eda50b64dbb62cacf9939e03c"
CHANGED = (
    "TASK.md", "justfile", "scripts/cranelift_test_levels.json",
    "scripts/phase26_2_allocator_registration.py", "scripts/phase26_production_registration.py",
    "scripts/phase26_release_closure.py", "scripts/phase26_production_package.py",
    "compiler/experiments/cranelift/src/production_trust.rs",
    "compiler/experiments/cranelift/src/production_trust_tests.rs",
    "compiler/experiments/cranelift/production/manifest.txt",
    "compiler/experiments/cranelift/production/manifest.sig",
    "compiler/experiments/cranelift/production/snapshot.json",
    "compiler/experiments/cranelift/production/public-identity.json",
    ".github/workflows/phase26-release-closure.yml",
    ".github/workflows/stdlib-s26-native-bytes.yml",
    "scripts/phase26_r3_zlib_adapter_guard.sh",
    "scripts/fixture_reachability.py",
)
ADDED = tuple(HISTORY + name for name in (
    "manifest.txt", "manifest.sig", "snapshot.json", "production_trust.rs",
    "predecessor-baseline.json.gz", "predecessor-baseline-v2.json.gz",
    "predecessor-baseline-v3.json.gz", "public-identity.json")) + (
    ".github/workflows/phase26-github-release-signing.yml",
    "scripts/phase26_github_package_candidate.py",
    "scripts/phase26_github_issue.py",
    "compiler/experiments/cranelift/production/github-provenance.json",
    "compiler/experiments/cranelift/production/github-enrollment.json",
    "compiler/experiments/cranelift/production/renewal-assembly.json",
    "compiler/phase26-release/release-epoch2.json",
    "compiler/phase26-release/reachable-audit-epoch2.json",
    "scripts/phase26_production_renewal.py",
    "scripts/phase26_production_renewal_registration.py",
    "compiler/CRANELIFT_PHASE26_PRODUCTION_RENEWAL.md",
)
RECIPE = ("\n# Selected epoch2 worker renewal; no package-supplied trust updates.\n" + GUARD + ":\n"
    "    python3 scripts/phase26_production_renewal_registration.py validate\n"
    "    python3 scripts/phase26_production_renewal_registration.py inversions\n"
    "    python3 scripts/phase26_production_renewal.py validate\n")


def require(ok, message):
    if not ok:
        raise SystemExit(GUARD + ": " + message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def fingerprint(value):
    return sha(json.dumps(value, sort_keys=True, separators=(",", ":")).encode())


@lru_cache(maxsize=1)
def baseline():
    raw = (ROOT / BASELINE).read_bytes()
    require(sha(raw) == BASELINE_SHA256, "renewal predecessor bytes drifted")
    value = json.loads(gzip.decompress(raw))
    require(value["base"] == BASE, "renewal predecessor identity drifted")
    return value


def base_bytes(path):
    return base64.b64decode(baseline()["files"][path], validate=True)


def record(registry):
    return registry.get("phase26_activation_audit", {}).get(KEY)


def identity(registry):
    row = record(registry)
    require(row and row["predecessor_main"] == BASE and row["owner"] == "cranelift" and
            row["guard"] == GUARD and row["release_epoch"] == 2 and
            row["operational_state_excluded"] == STATE and
            row["od23"] == "OPEN; no observation alternative selected" and
            [p["path"] for p in row["changed_files"]] == list(CHANGED) and
            [p["path"] for p in row["added_files"]] == list(ADDED),
            "renewal identity or file population drifted")
    require((ROOT / STATE).is_file() and (ROOT / STATE).stat().st_size > 0,
            "operational lane state is absent")
    return row


def check_files(registry):
    row = identity(registry)
    for pin in row["changed_files"]:
        require(pin["previous_digest"] == sha(base_bytes(pin["path"])) and
                sha((ROOT / pin["path"]).read_bytes()) == pin["current_digest"],
                "R4 changed file drifted: " + pin["path"] + " (epoch2 renewal)")
    for pin in row["added_files"]:
        require(sha((ROOT / pin["path"]).read_bytes()) == pin["digest"],
                "renewal added file drifted: " + pin["path"])


def frozen_ancestor_images(kind):
    # Complete, hash-checked archived images only. Repeated old normalizers
    # must not promote an older image back to the immediate predecessor.
    import importlib
    values = [baseline()["projections"][kind]]
    for name in ("phase26_2_allocator_registration", "phase26_release_registration",
                 "phase26_readonly_input_copy_registration", "phase26_ticket_composition_registration",
                 "phase26_imported_native_registration", "phase26_ticket_publication_registration"):
        values.append(importlib.import_module(name).baseline()["projections"][kind])
    if kind == "r4_record":
        for value in list(values):
            live_state = copy.deepcopy(value)
            next(p for p in live_state["changed_files"] if p["path"] == STATE)[
                "current_digest"] = sha((ROOT / STATE).read_bytes())
            values.append(live_state)
    return values


def canonical_projection(kind, current):
    previous = baseline()["projections"][kind]
    if kind in ("text", "r4_text"):
        require(isinstance(current, list) and all(isinstance(p, dict) and "path" in p for p in current) and
                sum(p["path"] == STATE for p in current) <= 1,
                "R4 " + kind + " live projection drifted (renewal)")
        return sorted(copy.deepcopy([p for p in current if p["path"] != STATE] +
                      [p for p in previous if p["path"] == STATE]), key=lambda p: p["path"])
    if kind == "r4_record":
        require(isinstance(current, dict) and set(current) == set(previous) and
                isinstance(current.get("changed_files"), list) and
                sum(isinstance(p, dict) and p.get("path") == STATE
                    for p in current["changed_files"]) == 1,
                "R4 r4_record live projection drifted (renewal)")
        result = copy.deepcopy(current)
        state = next(p for p in result["changed_files"] if p["path"] == STATE)
        old = next(p for p in previous["changed_files"] if p["path"] == STATE)
        require(state["previous_digest"] == old["previous_digest"] and
                state["current_digest"] in (old["current_digest"], sha((ROOT / STATE).read_bytes())),
                "R4 r4_record live projection drifted (renewal)")
        state["current_digest"] = old["current_digest"]
        edge = result["projections"]["text"]
        if edge["current_digest"] != previous["projections"]["text"]["current_digest"]:
            import phase26_r3_zlib_adapter_registration as r3
            import phase26_r4_collection_registration as r4
            raw = r4.owned_text(r3.raw_text_surfaces())
            normalized = fingerprint(canonical_projection("r4_text", raw))
            require(edge["current_digest"] in (fingerprint(raw), normalized),
                    "R4 r4_record live projection drifted (renewal)")
            edge["current_digest"] = normalized
        return result
    return current


def prior_digest(registry, path, live):
    if not record(registry) or path not in CHANGED:
        return live
    pin = next(p for p in identity(registry)["changed_files"] if p["path"] == path)
    admitted = {pin["current_digest"], pin["previous_digest"]}
    predecessor = json.loads(base_bytes("scripts/cranelift_feature_registry.json"))
    # Only coordinates emitted by enclosing successors can reach this adapter.
    # Production's own before-state remains a rejected rollback, not an alias.
    for key in ("allocator_resource_liveness_successor_v1", "first_release_closure_successor_v1",
                "readonly_input_copy_successor_v1", "closed_ticket_composition_successor_v1",
                "imported_native_successor_v1", "scoped_ticket_publication_successor_v1"):
        for item in predecessor["phase26_activation_audit"][key]["changed_files"]:
            if item.get("path") == path:
                admitted.update(item[field] for field in ("current_digest", "previous_digest"))
    require(sha((ROOT / path).read_bytes()) == pin["current_digest"] and
            pin["previous_digest"] == sha(base_bytes(path)) and live in admitted,
            "R4 changed file drifted: " + path + " (epoch2 renewal)")
    return pin["previous_digest"]


def prior_bytes(registry, path, live):
    if not record(registry) or path not in CHANGED:
        return live
    prior_digest(registry, path, sha(live))
    return base_bytes(path)


def project(registry, kind, current):
    if not record(registry):
        return current
    row = identity(registry)
    previous = baseline()["projections"][kind]
    require(type(current) is type(previous), "R4 " + kind + " live projection drifted (renewal)")
    # Ancestor acceptance is never a physical rollback escape hatch.
    check_files(registry)
    if kind in ("text", "r4_text"):
        require(all(isinstance(p, dict) and "path" in p for p in current),
                "R4 " + kind + " live projection drifted (renewal)")
        owned = set(CHANGED + ADDED)
        subset = [p for p in current if p["path"] in owned]
        ancestor_subsets = [[p for p in value if p["path"] in owned]
                            for value in frozen_ancestor_images(kind)]
        if any(subset == value for value in ancestor_subsets):
            return copy.deepcopy(current)  # Preserve foreign order/duplicates too.
        current = canonical_projection(kind, current)
        old_subset = [p for p in previous if p["path"] in owned]
        require(fingerprint(subset) == row["owned_text"][kind],
                "R4 " + kind + " live projection drifted (renewal)")
        return sorted(copy.deepcopy([p for p in current if p["path"] not in owned] + old_subset),
                      key=lambda p: p["path"])
    if any(current == value for value in frozen_ancestor_images(kind)):
        return copy.deepcopy(current)
    current = canonical_projection(kind, current)
    require(fingerprint(current) == row["projections"][kind],
            "R4 " + kind + " live projection drifted (renewal)")
    result = copy.deepcopy(previous)
    if kind == "r4_record":
        next(p for p in result["changed_files"] if p["path"] == STATE)["current_digest"] = sha((ROOT / STATE).read_bytes())
    return result


def project_registry(registry):
    result = copy.deepcopy(registry)
    result.get("phase26_activation_audit", {}).pop(KEY, None)
    return result


def prior_render_digest(registry, live):
    if not record(registry):
        return live
    row = identity(registry)
    previous = json.loads(base_bytes("scripts/cranelift_feature_registry.json"))[
        "phase26_activation_audit"]["allocator_resource_liveness_successor_v1"]["spelling_render_current_digest"]
    require(live in (row["spelling_render_current_digest"], previous),
            "R4 current spelling review is stale or missing (renewal)")
    return previous


def current_projections():
    import phase26_2_allocator_registration as previous
    return previous.current_projections()


def build_record():
    import phase24_semantic_spelling_inventory as spelling
    values = current_projections()
    values = {kind: canonical_projection(kind, value) for kind, value in values.items()}
    sites = spelling.source_sites()
    return dict(predecessor_main=BASE, owner="cranelift", guard=GUARD, release_epoch=2,
        operational_state_excluded=STATE,
        od23="OPEN; no observation alternative selected",
        changed_files=[dict(path=p, previous_digest=sha(base_bytes(p)),
                           current_digest=sha((ROOT / p).read_bytes())) for p in CHANGED],
        added_files=[dict(path=p, digest=sha((ROOT / p).read_bytes())) for p in ADDED],
        owned_text={k: fingerprint([p for p in values[k] if p["path"] in CHANGED + ADDED])
                    for k in ("text", "r4_text")},
        projections={k: fingerprint(v) for k, v in values.items()},
        spelling_render_current_digest=sha(spelling.render(spelling.load_authority(), sites,
            spelling.manifest_summary(sites)).encode()))


def generate():
    import phase26_production_renewal as renewal
    renewal.validate()  # Requires real signature and actual valid wall-clock interval.
    registry = json.loads(REGISTRY.read_text())
    require(not record(registry), "generation requires an unregistered current successor")
    require(registry == json.loads(base_bytes("scripts/cranelift_feature_registry.json")),
            "generation would overwrite foreign or predecessor registry changes")
    # Update only the active successor authority; epoch1 records stay frozen.
    authority_path = ROOT / "compiler/phase26-release/release-epoch2.json"
    authority = json.loads(authority_path.read_text())
    pins = authority["source_pins"]
    for path in set(pins) | (set(CHANGED + ADDED) - {
            "TASK.md", "compiler/phase26-release/release-epoch2.json",
            "compiler/phase26-release/reachable-audit-epoch2.json"}):
        require(path not in ("TASK.md", "TASK_STDLIB.md", "GUST_LANE_STATE.md"),
                "operational source pin re-admitted")
        pins[path] = sha((ROOT / path).read_bytes())
    authority["snapshot"] = json.loads((renewal.PROFILE / "snapshot.json").read_text())
    authority["artifacts"] = [[p["kind"], p["name"], p["sha256"]] for p in
                              json.loads((renewal.PROFILE / "renewal-assembly.json").read_text())["artifacts"]]
    authority["renewal_status"] = "SIGNED; actual qualification and exact-head CI remain required"
    authority["production_files"] = {name: sha((renewal.PROFILE / name).read_bytes())
                                    for name in ("manifest.txt", "manifest.sig", "public-identity.json")}
    audit_path = ROOT / authority["reachable_audit"]
    audit = json.loads(audit_path.read_text())
    audit["source_pins"] = pins
    audit_path.write_text(json.dumps(audit, indent=2) + "\n")
    authority_path.write_text(json.dumps(authority, indent=2) + "\n")
    row = build_record()
    marker = '  "phase26_activation_audit": {\n'
    original = REGISTRY.read_text()
    require(original.count(marker) == 1, "renewal registry insertion anchor drifted")
    field = "\n".join("  " + line for line in json.dumps({KEY: row}, indent=2).splitlines()[1:-1])
    REGISTRY.write_text(original.replace(marker, marker + field + ",\n", 1))
    print("EPOCH2_EXACT_ADDITIVE_ENROLLMENT_GENERATED; not qualification")


def validate():
    import phase26_production_renewal as renewal
    renewal.validate()
    registry = json.loads(REGISTRY.read_text())
    row = identity(registry)
    require(project_registry(registry) == json.loads(base_bytes("scripts/cranelift_feature_registry.json")),
            "renewal changed predecessor or foreign registry rows")
    check_files(registry)
    require((ROOT / "justfile").read_bytes() == base_bytes("justfile") + RECIPE.encode(),
            "renewal owning recipe drifted")
    levels = json.loads((ROOT / "scripts/cranelift_test_levels.json").read_text())
    require(levels["guards"].pop(GUARD, None) == 2 and
            levels == json.loads(base_bytes("scripts/cranelift_test_levels.json")),
            "renewal test level or predecessor guard changed")
    for kind, value in current_projections().items():
        project(registry, kind, value)
    print("EPOCH2_EXACT_ADDITIVE_ENROLLMENT_PASS")


def fixture_inventory_controls():
    """Audit hashes never stand in for execution; retain the actual old ratchet."""
    import contextlib
    import io
    import subprocess
    from unittest.mock import patch
    import fixture_reachability as fixtures
    inventories = {"compiler/phase26-release/release-epoch2.json",
                   "compiler/phase26-release/reachable-audit-epoch2.json"}
    allowed = set(json.loads(fixtures.ALLOWLIST.read_text())["known_unexercised"])
    require({name for name, _ in fixtures.unexercised()} == allowed and allowed,
            "renewal changed the actual staged fixture population")
    external = "scripts/renewal-executing-fixture-control.py"
    require(fixtures.executing_references(sorted(inventories) + [external]) == [external],
            "source-only inventory or executing-reference classification changed")
    for path in inventories:
        require(fixtures.executing_references([path + ".executor"]) == [path + ".executor"],
                "inventory exemption widened beyond its exact path")
    def ratchet_refuses(label):
        stream = io.StringIO()
        with patch.object(sys, "argv", ["fixture_reachability.py"]), contextlib.redirect_stdout(stream):
            code = fixtures.main()
        require(code == 1 and "No longer unexercised" in stream.getvalue(),
                label + ": actual fixture ratchet failed to reject changed execution evidence")
        print(label + ": REJECTED (expected actual fixture ratchet)", flush=True)
    for path in sorted(inventories):
        with patch.object(fixtures, "NON_EXECUTING_INVENTORIES",
                          fixtures.NON_EXECUTING_INVENTORIES - {path}):
            ratchet_refuses("inventory-as-execution " + path)
    original = subprocess.run
    target = sorted(allowed)[0]
    def with_execution(args, *values, **kwargs):
        result = original(args, *values, **kwargs)
        if list(args) == ["git", "grep", "-l", "-F", target]:
            return subprocess.CompletedProcess(args, result.returncode,
                result.stdout + external + "\n", result.stderr)
        return result
    with patch.object(fixtures.subprocess, "run", with_execution):
        ratchet_refuses("actual external reference remains execution evidence")
    print("RENEWAL_SOURCE_ONLY_INVENTORY_CONTROLS_PASS", flush=True)


def predecessor_record_control():
    """Exercise the old record check through its actual imported module target."""
    from unittest.mock import patch
    import phase26_2_allocator_registration as predecessor
    registry = json.loads(REGISTRY.read_text())
    check_files(registry)  # Require this exact patched source before isolation.
    foreign_record = copy.deepcopy(predecessor.baseline()["projections"]["r4_record"])
    next(p for p in foreign_record["changed_files"] if p["path"] == STATE)[
        "current_digest"] = sha((ROOT / STATE).read_bytes())
    next(p for p in foreign_record["changed_files"] if p["path"] != STATE)[
        "current_digest"] = "0" * 64
    # __main__ is distinct from the module imported by the predecessor.
    target = predecessor.successor
    original_project = target.project
    isolated = []
    def isolate_foreign_record(registry, kind, value):
        if kind == "r4_record" and value is foreign_record:
            isolated.append(True)
            return copy.deepcopy(value)
        return original_project(registry, kind, value)
    with patch.object(target, "project", isolate_foreign_record):
        try:
            predecessor.project(registry, "r4_record", foreign_record)
        except SystemExit as error:
            require("live projection drifted (allocator successor)" in str(error),
                    "predecessor nested foreign record: REJECTED (different assertion): " + str(error))
            print("predecessor nested foreign record: REJECTED (expected assertion)", flush=True)
        else:
            raise SystemExit("predecessor nested foreign record: ACCEPTED")
    require(isolated == [True], "predecessor control did not isolate its exact input")
    print("PREDECESSOR_RECORD_CONTROL_ONLY_PASS; full inversions/census remain required", flush=True)


def inversions():
    validate()
    registry = json.loads(REGISTRY.read_text())
    from unittest.mock import patch
    def rejected(label, callback, expected):
        try:
            callback()
        except SystemExit as error:
            require(expected in str(error), label + ": REJECTED (different assertion): " + str(error))
            print(label + ": REJECTED (expected assertion): " + str(error), flush=True)
        else:
            raise SystemExit(label + ": ACCEPTED")
    production = json.loads(base_bytes("scripts/cranelift_feature_registry.json"))[
        "phase26_activation_audit"]["production_trust_successor_v1"]
    for pin in production["changed_files"]:
        if pin["path"] in CHANGED:
            rejected("unqualified production predecessor " + pin["path"],
                     lambda pin=pin: prior_digest(registry, pin["path"], pin["previous_digest"]),
                     "R4 changed file drifted")
    for path in CHANGED:
        rejected("substituted " + path, lambda path=path: prior_digest(registry, path, "0" * 64),
                 "R4 changed file drifted")
        original_read = Path.read_bytes
        for label, raw in (("physical rollback", base_bytes(path)),
                           ("physical substitution", original_read(ROOT / path) + b"\n")):
            with patch.object(Path, "read_bytes", lambda p, path=path, raw=raw:
                    raw if p == ROOT / path else original_read(p)):
                rejected(label + " " + path,
                         lambda path=path: prior_digest(registry, path, sha((ROOT / path).read_bytes())),
                         "R4 changed file drifted")
    original_read = Path.read_bytes
    for path in ADDED:
        with patch.object(Path, "read_bytes", lambda p, path=path:
                original_read(p) + b"\n" if p == ROOT / path else original_read(p)):
            expected = "immutable epoch1 history" if path.startswith(HISTORY) else "renewal added file drifted"
            rejected("physical added substitution " + path, validate, expected)
    values = current_projections()
    for kind in identity(registry)["projections"]:
        rejected("substituted " + kind, lambda kind=kind: project(registry, kind, "substituted"),
                 "live projection drifted")
        once = project(registry, kind, values[kind])
        require(project(registry, kind, once) == once, "renewal projection not idempotent: " + kind)
        import phase26_2_allocator_registration as predecessor
        composed = predecessor.project(registry, kind, project(registry, kind, values[kind]))
        require(project(registry, kind, composed) == composed,
                "renewal changed a projected predecessor image: " + kind)
        require(predecessor.project(registry, kind, composed) == composed,
                "renewal/predecessor composition is not idempotent: " + kind)
        for image in frozen_ancestor_images(kind):
            require(project(registry, kind, image) == image,
                    "renewal changed a complete frozen ancestor image: " + kind)
    for kind in ("text", "r4_text"):
        owned = next(p for p in values[kind] if p["path"] in CHANGED + ADDED)
        for label, changed in (("omitted", [p for p in values[kind] if p != owned]),
                               ("duplicate", values[kind] + [owned])):
            rejected(label + " " + kind, lambda kind=kind, changed=changed: project(registry, kind, changed),
                     "live projection drifted")
        foreign = next(p for p in values[kind] if p["path"] not in CHANGED + ADDED)
        changed = copy.deepcopy(values[kind])
        next(p for p in changed if p["path"] == foreign["path"])["renewal_foreign_mutation"] = True
        require(any(p.get("renewal_foreign_mutation") for p in project(registry, kind, changed)),
                "renewal swallowed foreign source mutation")
    foreign = copy.deepcopy(registry)
    foreign["renewal_foreign_mutation"] = True
    require(project_registry(foreign) != json.loads(base_bytes("scripts/cranelift_feature_registry.json")),
            "renewal swallowed foreign registry mutation")
    original_text = Path.read_text
    with patch.object(Path, "read_text", lambda p, *args, **kwargs:
            json.dumps(foreign) if p == REGISTRY else original_text(p, *args, **kwargs)):
        import phase26_2_allocator_registration as predecessor
        rejected("foreign mutation through predecessor validator", predecessor.validate,
                 "allocator changed frozen predecessor or foreign registry rows")
    predecessor_record_control()
    fixture_inventory_controls()
    print("EPOCH2_RENEWAL_ENROLLMENT_INVERSIONS_PASS")


if __name__ == "__main__":
    {"generate": generate, "validate": validate, "inversions": inversions,
     "predecessor-record-control": predecessor_record_control}[sys.argv[1]]()
