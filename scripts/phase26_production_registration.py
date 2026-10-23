#!/usr/bin/env python3
"""Exact additive production enrollment over the merged R4 capability.

Operational lane-state prose is retired from compiler byte pins. Every code,
workflow, source inventory and signed artifact constraint remains enforced.
"""
from __future__ import annotations
import copy
import hashlib
import json
import re
import base64
import gzip
from functools import lru_cache
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = "c6916d3ede29d407f35e63fe222fcc8e01a80150"
KEY = "production_trust_successor_v1"
GUARD = "guard-cranelift-phase26-production-trust"
STATE = "GUST_LANE_STATE.md"
CHANGED = (
    ".github/workflows/pr-fast.yml", "justfile", "scripts/cranelift_test_levels.json",
    "compiler/experiments/cranelift/src/approved_package.rs",
    "compiler/experiments/cranelift/src/main.rs",
    "scripts/phase26_r4_collection_registration.py",
    "scripts/phase26_r3_zlib_adapter_registration.py",
    "scripts/phase26_r3_zlib_adapter_guard.sh",
)
ADDED = (
    "compiler/experiments/cranelift/src/production_trust.rs",
    "compiler/experiments/cranelift/src/production_trust_tests.rs",
    "compiler/experiments/cranelift/production/manifest.txt",
    "compiler/experiments/cranelift/production/manifest.sig",
    "compiler/experiments/cranelift/production/snapshot.json",
    "compiler/experiments/cranelift/production/public-identity.json",
    "compiler/experiments/cranelift/production/build-toolchain.json",
    "compiler/experiments/cranelift/production/predecessor-baseline.json.gz",
    "scripts/phase26_production_package.py",
    "scripts/phase26_production_toolchain.py",
    "scripts/phase26_production_registration.py",
    "scripts/phase26_production_guard.py",
    "compiler/CRANELIFT_PHASE26_PRODUCTION_TRUST.md",
)
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"

def require(ok, reason):
    if not ok: raise SystemExit(f"{GUARD}: {reason}")

def sha(raw): return hashlib.sha256(raw).hexdigest()
def fingerprint(value): return sha(json.dumps(value, sort_keys=True, separators=(",", ":")).encode())
BASELINE = "compiler/experiments/cranelift/production/predecessor-baseline.json.gz"
BASELINE_SHA256 = "c34040c36e98be10e2ad3deee025477455c598fe735dbd9124369a16e33099bb"

def decode_baseline(raw):
    require(sha(raw) == BASELINE_SHA256, "production predecessor baseline bytes drifted")
    return json.loads(gzip.decompress(raw))

@lru_cache(maxsize=1)
def baseline():
    return decode_baseline((ROOT / BASELINE).read_bytes())

def base_bytes(path):
    return base64.b64decode(baseline()[path], validate=True)
def raw_digest(path): return sha((ROOT / path).read_bytes())
def record(registry): return registry.get("phase26_activation_audit", {}).get(KEY)

def identity(registry):
    row = record(registry)
    require(row and row["predecessor_main"] == BASE and row["owner"] == "cranelift" and
            row["guard"] == GUARD and row["phase26_1_status"] == "OPEN" and
            row["operational_state_excluded"] == STATE and
            [p["path"] for p in row["changed_files"]] == list(CHANGED) and
            [p["path"] for p in row["added_files"]] == list(ADDED),
            "production identity, pinned population, or operational-state retirement drifted")
    return row

def prior_digest(registry, path, live):
    if not record(registry): return live
    row = identity(registry)
    if path == STATE:
        require((ROOT / STATE).is_file() and (ROOT / STATE).stat().st_size > 0,
                "operational lane state is absent")
        return sha(base_bytes(path))
    match = [p for p in row["changed_files"] if p["path"] == path]
    if not match: return live
    pin = match[0]
    require(pin["current_digest"] == live and pin["previous_digest"] == sha(base_bytes(path)),
            f"R4 changed file drifted: {path} (production successor)")
    return pin["previous_digest"]

def prior_bytes(registry, path, live):
    if not record(registry): return live
    prior_digest(registry, path, sha(live))
    return base_bytes(path) if path in CHANGED else live

def old_text(path):
    from phase23_mir_to_c_deprecation_opening import SURFACE_PATTERNS, classify_surface, owner_for_path
    if path in ADDED: return None
    raw = base_bytes(path)
    counts = {n: len(p.findall(raw.decode())) for n, p in SURFACE_PATTERNS.items()}
    if not any(counts.values()): return None
    classification, action, removal, falsifier = classify_surface(path)
    return dict(path=path, digest=sha(raw), match_counts=counts, classification=classification,
                owner=owner_for_path(path), current_route="tracked_MIR_to_C_or_generated_C_surface",
                deprecation_action=action, removal_phase=removal, falsifier=falsifier)

def project(registry, kind, current):
    if not record(registry): return current
    row = identity(registry)
    if kind == "text":
        require(isinstance(current, list), "R4 text live projection drifted (production successor)")
        owned = set(CHANGED + ADDED)
        subset = [r for r in current if r["path"] in owned]
        require(fingerprint(subset) == row["text_current_digest"], "R4 text live projection drifted (production successor)")
        before = [old_text(path) for path in CHANGED + (STATE,)]
        before = [r for r in before if r is not None]
        result = [copy.deepcopy(r) for r in current if r["path"] not in owned and r["path"] != STATE]
        result += before
        return sorted(result, key=lambda r: r["path"])
    edge = row["projections"][kind]
    require(fingerprint(current) == edge["current_digest"], f"R4 {kind} live projection drifted (production successor)")
    previous = edge["previous"]
    if kind == "workflow":
        require(previous == base_bytes(".github/workflows/pr-fast.yml").decode(), "production workflow predecessor drifted")
    else:
        old = json.loads(base_bytes("scripts/cranelift_feature_registry.json"))
        frozen_row = old["phase26_activation_audit"]["collection_validity_r4_successor"]
        expected = (fingerprint(frozen_row) if kind == "r4_record" else
                    frozen_row["projections"]["text" if kind == "r4_text" else kind]["current_digest"])
        require(fingerprint(previous) == expected,
                f"production {kind} predecessor drifted")
    return copy.deepcopy(previous)

def project_registry(registry):
    result = copy.deepcopy(registry)
    result.get("phase26_activation_audit", {}).pop(KEY, None)
    return result

def prior_render_digest(registry, live):
    if not record(registry): return live
    row = identity(registry)
    require(row["spelling_render_current_digest"] == live, "R4 current spelling review is stale or missing (production successor)")
    old = base_bytes("compiler/CRANELIFT_PHASE26_COLLECTION_SPELLING_INVENTORY.md").decode()
    return re.search(r"Complete current rendered inventory SHA-256: `([0-9a-f]{64})`", old)[1]

def normalize_edges(registry, edges):
    if not record(registry): return edges
    for kind, edge in edges.items():
        edge["current"] = project(registry, "r4_text" if kind == "text" else kind, edge["current"])
    return edges

def production_policy(registry):
    identity(registry)
    profile = ROOT / "compiler/experiments/cranelift/production"
    public = json.loads((profile / "public-identity.json").read_text())
    snapshot = json.loads((profile / "snapshot.json").read_text())
    key = "6778b05d2ef8f7af4f553918b2b5658eba1d7919536ab3b64c69e63fd5e0b550"
    require(public["public_key_hex"] == snapshot["public_key_hex"] == key and
            public["key_id"] == snapshot["signer"] == "gust-native-release-1" and
            public["release_signing_custody_withdrawal_owner"] == "garthtrickett",
            "production public enrollment identity changed")
    require([snapshot[n] for n in ("release_epoch", "minimum_package_epoch", "key_first_epoch", "key_last_epoch")] == [1,1,1,1] and
            snapshot["maximum_validity_seconds"] == 604800 and
            snapshot["expires_unix_seconds"] - snapshot["issued_unix_seconds"] == 604800 and
            sha((profile / "manifest.txt").read_bytes()) == snapshot["manifest_sha256"],
            "production pinned epoch, validity or manifest binding changed")
    worker = (ROOT / "compiler/experiments/cranelift/src/production_trust.rs").read_text()
    array = re.search(r"public_key: \[(.*?)\]", worker, re.S)[1]
    actual = bytes(int(n, 16) for n in re.findall(r"0x([0-9a-f]{2})", array)).hex()
    require(actual == key and all(f"{name}: {snapshot[name]}" in worker for name in
            ("issued_unix_seconds", "expires_unix_seconds")),
            "production worker public key or actual validity differs from receipt")
    source = (ROOT / "compiler/experiments/cranelift/src/approved_package.rs").read_text()
    require("PRODUCTION_REGISTRY: &[RegisteredPackage] = production_trust::REGISTRY" in source,
            "enrolled production registry missing")
    return True

def expected_workflow():
    text = base_bytes(".github/workflows/pr-fast.yml").decode()
    replacements = [
        ("    name: build Gust and CI surface\n    runs-on: ubuntu-latest",
         "    name: build Gust and CI surface\n    runs-on: ubuntu-24.04"),
        ("    name: Phase 26 FFI position policy\n    runs-on: ubuntu-latest",
         "    name: Phase 26 FFI position policy\n    runs-on: ubuntu-24.04"),
        ("      - name: Build Gust\n        run: make gust",
         "      - name: Pin existing production build dependencies\n"
         "        run: python3 scripts/phase26_production_toolchain.py install-ci build/production-build-toolchain\n\n"
         "      - name: Build Gust\n        run: make gust"),
        ("      - name: Phase 26 approved signed package and linker boundary\n",
         "      - name: Pin existing production qualification dependencies\n"
         "        run: python3 scripts/phase26_production_toolchain.py install-ci build/production-test-toolchain\n\n"
         "      - name: Phase 26 approved signed package and linker boundary\n"),
        ("      - name: Phase 26 checked collection validity and copy preservation\n",
         "      - name: Phase 26 enrolled production package offline qualification\n"
         "        run: just guard-cranelift-phase26-production-trust\n\n"
         "      - name: Retain production qualification candidate and evidence\n"
         "        if: always()\n        uses: actions/upload-artifact@v4\n        with:\n"
         "          name: phase26-production-qualification\n"
         "          path: build/guards/phase26_production_trust/\n"
         "          if-no-files-found: error\n\n"
         "      - name: Phase 26 checked collection validity and copy preservation\n"),
    ]
    for before, after in replacements:
        require(text.count(before) == 1, "production workflow predecessor obligation drifted")
        text = text.replace(before, after, 1)
    return text

def check_workflow(text):
    require(text == expected_workflow(), "production owning CI step, toolchain or evidence obligation drifted")

def build_record(previous):
    import phase26_r4_collection_registration as r4
    import phase26_r3_zlib_adapter_registration as r3
    import phase24_semantic_spelling_inventory as spelling
    edges = r4.live_projections()
    edges["r4_record"] = {"current": r4.build_record()}
    rows = r3.raw_text_surfaces()
    sites = spelling.source_sites()
    return dict(predecessor_main=BASE, owner="cranelift", guard=GUARD,
        phase26_1_status="OPEN", operational_state_excluded=STATE,
        changed_files=[dict(path=p, previous_digest=sha(base_bytes(p)), current_digest=raw_digest(p)) for p in CHANGED],
        added_files=[dict(path=p, digest=raw_digest(p)) for p in ADDED],
        text_current_digest=fingerprint([r for r in rows if r["path"] in CHANGED + ADDED]),
        spelling_render_current_digest=sha(spelling.render(spelling.load_authority(), sites, spelling.manifest_summary(sites)).encode()),
        projections={('r4_text' if k == 'text' else k): dict(previous=previous[k]["current"], current_digest=fingerprint(e["current"])) for k,e in edges.items()})

def check_files(registry):
    row = identity(registry)
    for pin in row["changed_files"]: prior_digest(registry, pin["path"], raw_digest(pin["path"]))
    for pin in row["added_files"]:
        require(pin["digest"] == raw_digest(pin["path"]), f"production added file drifted: {pin['path']}")

def validate():
    registry = json.loads(REGISTRY.read_text()); identity(registry)
    check_files(registry)
    require(project_registry(registry) == json.loads(base_bytes("scripts/cranelift_feature_registry.json")),
            "production changed predecessor registry")
    production_policy(registry)
    check_workflow((ROOT / ".github/workflows/pr-fast.yml").read_text())
    require((ROOT / "justfile").read_text() == base_bytes("justfile").decode() +
            "\n# Operator-enrolled production signing and exact offline static package profile.\n" +
            GUARD + ":\n    python3 scripts/phase26_production_registration.py validate\n"
            "    python3 scripts/phase26_production_registration.py inversions\n"
            "    python3 scripts/phase26_production_guard.py\n", "production owning recipe drifted")
    levels = json.loads((ROOT / "scripts/cranelift_test_levels.json").read_text())
    require(levels["guards"].pop(GUARD, None) == 2 and
            levels == json.loads(base_bytes("scripts/cranelift_test_levels.json")),
            "production test level or predecessor levels drifted")
    print(f"{GUARD}: exact enrollment registration PASS")

def inversions():
    validate()
    registry = json.loads(REGISTRY.read_text())
    import phase26_r4_collection_registration as r4
    import phase26_r3_zlib_adapter_registration as r3
    def rejected(label, callback, assertion):
        try: callback()
        except SystemExit as error:
            require(assertion in str(error), f"{label}: REJECTED (different assertion): {error}")
            print(f"{label}: REJECTED (expected assertion): {error}")
        else: raise SystemExit(f"{label}: ACCEPTED")
    rejected("substituted predecessor baseline", lambda: decode_baseline(b"substituted"),
             "production predecessor baseline bytes drifted")
    for path in CHANGED:
        rejected("substituted " + path, lambda path=path: prior_digest(registry, path, "0" * 64),
                 "R4 changed file drifted")
        rejected("old state " + path, lambda path=path: prior_digest(registry, path, sha(base_bytes(path))),
                 "R4 changed file drifted")
    for path in ADDED:
        altered_file = copy.deepcopy(registry)
        next(p for p in altered_file["phase26_activation_audit"][KEY]["added_files"]
             if p["path"] == path)["digest"] = "0" * 64
        rejected("substituted added " + path, lambda altered_file=altered_file: check_files(altered_file),
                 "production added file drifted")
    altered = copy.deepcopy(registry)
    altered["phase26_activation_audit"][KEY]["changed_files"].append(dict(path=STATE))
    rejected("re-admitted operational byte pin", lambda: identity(altered), "operational-state retirement")
    require(prior_digest(registry, STATE, "0" * 64) == sha(base_bytes(STATE)),
            "operational state remains a compiler byte pin")
    raw = r3.raw_text_surfaces()
    owned = next(r for r in raw if r["path"] in CHANGED)
    for label, changed in [
        ("substituted source row", [dict(r, digest="0" * 64) if r == owned else r for r in raw]),
        ("omitted source row", [r for r in raw if r != owned]),
        ("duplicate source row", raw + [owned]),
    ]:
        rejected(label, lambda changed=changed: project(registry, "text", changed), "R4 text live projection")
    foreign = next(r for r in raw if r["path"] not in CHANGED + ADDED + (STATE,))
    changed = [dict(r, digest="0" * 64) if r == foreign else r for r in raw]
    forwarded = project(registry, "text", changed)
    require(next(r for r in forwarded if r["path"] == foreign["path"])["digest"] == "0" * 64,
            "foreign source substitution hidden")
    require(sum(r["path"] == foreign["path"] for r in project(registry, "text", raw + [foreign])) == 2,
            "foreign duplicate hidden")
    edges = r4.live_projections()
    edges["r4_record"] = {"current": r4.build_record()}
    for name, edge in edges.items():
        kind = "r4_text" if name == "text" else name
        rejected("substituted " + kind, lambda kind=kind: project(registry, kind, None),
                 "live projection drifted")
    workflow = expected_workflow()
    for command in ["just " + GUARD,
                    "python3 scripts/phase26_production_toolchain.py install-ci build/production-build-toolchain",
                    "python3 scripts/phase26_production_toolchain.py install-ci build/production-test-toolchain"]:
        require(workflow.count("        run: " + command + "\n") == 1, "CI inversion mechanism absent")
        for replacement in ["", "        run: true\n"]:
            changed = workflow.replace("        run: " + command + "\n", replacement, 1)
            require(changed != workflow, "CI inversion did not change a command")
            rejected("removed/substituted " + command, lambda changed=changed: check_workflow(changed),
                     "production owning CI step")
    changed = workflow.replace("        run: just " + GUARD + "\n",
                               "        if: false\n        run: just " + GUARD + "\n", 1)
    rejected("disabled production qualification", lambda: check_workflow(changed), "production owning CI step")
    print(f"{GUARD}: production source pins, foreign forwarding and operational retirement inversions PASS")

if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "generate":
        require(not record(json.loads(REGISTRY.read_text())), "generation requires unregistered successor")
        opening_evidence = json.loads(Path(sys.argv[2]).read_text())
        previous = opening_evidence["edges"]
        previous["r4_record"] = {"current": opening_evidence["r4_record"]}
        value = build_record(previous)
        text = REGISTRY.read_text(); marker = '  "phase26_activation_audit": {\n'
        field = "\n".join("  " + l for l in json.dumps({KEY: value}, indent=2).splitlines()[1:-1])
        require(text.count(marker) == 1, "registry insertion anchor")
        REGISTRY.write_text(text.replace(marker, marker + field + ",\n", 1))
    elif len(sys.argv) == 2 and sys.argv[1] == "inversions": inversions()
    else: validate()
