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
BASELINE = HISTORY + "predecessor-baseline.json.gz"
BASELINE_SHA256 = "73089a2c9dbadb629efc24d28f9d42aacfe73e6ea9374a74513935ebb524e54d"
CHANGED = (
    "TASK.md", "justfile", "scripts/cranelift_test_levels.json",
    "scripts/phase26_2_allocator_registration.py", "scripts/phase26_production_registration.py",
    "scripts/phase26_release_closure.py", "scripts/phase26_production_package.py",
    "compiler/experiments/cranelift/src/production_trust.rs",
    "compiler/experiments/cranelift/src/production_trust_tests.rs",
    "compiler/experiments/cranelift/production/manifest.txt",
    "compiler/experiments/cranelift/production/manifest.sig",
    "compiler/experiments/cranelift/production/snapshot.json",
)
ADDED = tuple(HISTORY + name for name in (
    "manifest.txt", "manifest.sig", "snapshot.json", "production_trust.rs",
    "predecessor-baseline.json.gz")) + (
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
    return row


def canonical_projection(kind, current):
    previous = baseline()["projections"][kind]
    if kind in ("text", "r4_text"):
        require(isinstance(current, list) and all(isinstance(p, dict) and "path" in p for p in current) and
                sum(p["path"] == STATE for p in current) <= 1,
                "R4 " + kind + " live projection drifted (renewal)")
        return sorted(copy.deepcopy([p for p in current if p["path"] != STATE] +
                      [p for p in previous if p["path"] == STATE]), key=lambda p: p["path"])
    if kind == "r4_record":
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
    for row in predecessor["phase26_activation_audit"].values():
        if not isinstance(row, dict):
            continue
        for item in row.get("changed_files", []):
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
    current = canonical_projection(kind, current)
    if kind in ("text", "r4_text"):
        owned = set(CHANGED + ADDED)
        subset = [p for p in current if p["path"] in owned]
        old_subset = [p for p in previous if p["path"] in owned]
        require(fingerprint(subset) in (row["owned_text"][kind], fingerprint(old_subset)),
                "R4 " + kind + " live projection drifted (renewal)")
        return sorted(copy.deepcopy([p for p in current if p["path"] not in owned] + old_subset),
                      key=lambda p: p["path"])
    require(fingerprint(current) in (row["projections"][kind], fingerprint(previous)),
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
    for p in row["changed_files"]:
        prior_digest(registry, p["path"], sha((ROOT / p["path"]).read_bytes()))
    for p in row["added_files"]:
        require(p["digest"] == sha((ROOT / p["path"]).read_bytes()), "renewal added file drifted: " + p["path"])
    require((ROOT / "justfile").read_bytes() == base_bytes("justfile") + RECIPE.encode(),
            "renewal owning recipe drifted")
    levels = json.loads((ROOT / "scripts/cranelift_test_levels.json").read_text())
    require(levels["guards"].pop(GUARD, None) == 2 and
            levels == json.loads(base_bytes("scripts/cranelift_test_levels.json")),
            "renewal test level or predecessor guard changed")
    for kind, value in current_projections().items():
        project(registry, kind, value)
    print("EPOCH2_EXACT_ADDITIVE_ENROLLMENT_PASS")


def inversions():
    validate()
    registry = json.loads(REGISTRY.read_text())
    def rejected(label, callback, expected):
        try:
            callback()
        except SystemExit as error:
            require(expected in str(error), label + ": REJECTED (different assertion): " + str(error))
            print(label + ": REJECTED (expected assertion): " + str(error), flush=True)
        else:
            raise SystemExit(label + ": ACCEPTED")
    for path in CHANGED:
        rejected("substituted " + path, lambda path=path: prior_digest(registry, path, "0" * 64),
                 "R4 changed file drifted")
    values = current_projections()
    for kind in identity(registry)["projections"]:
        rejected("substituted " + kind, lambda kind=kind: project(registry, kind, "substituted"),
                 "live projection drifted")
        once = project(registry, kind, values[kind])
        require(project(registry, kind, once) == once, "renewal projection not idempotent: " + kind)
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
    print("EPOCH2_RENEWAL_ENROLLMENT_INVERSIONS_PASS")


if __name__ == "__main__":
    {"generate": generate, "validate": validate, "inversions": inversions}[sys.argv[1]]()
