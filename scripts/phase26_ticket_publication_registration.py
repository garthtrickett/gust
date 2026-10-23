#!/usr/bin/env python3
"""Additive exact registration over merged production trust, without history fetches."""
from __future__ import annotations
import base64
import copy
from functools import lru_cache
import gzip
import hashlib
import json
from pathlib import Path
import sys
import phase26_imported_native_registration as successor

ROOT = Path(__file__).resolve().parents[1]
BASE = "0c8e31c93c021453bf6088eec1375974a482bb9b"
KEY = "scoped_ticket_publication_successor_v1"
GUARD = "guard-cranelift-phase26-ticket-publication"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
BASELINE = "compiler/experiments/cranelift/ticket-publication/predecessor-baseline.json.gz"
BASELINE_SHA256 = "8f39dcfa55bd2276222fa8e0d5f8976c92ac1ce68a9a11a388f9ae56eb5ab0de"
CHANGED = (".github/workflows/pr-fast.yml", "justfile", "scripts/cranelift_test_levels.json",
    "scripts/phase26_production_registration.py", "compiler/mir_native_backend_parameter_argument_source.gst",
    "compiler/experiments/cranelift/src/main.rs", "compiler/experiments/cranelift/src/full_program.rs",
    "compiler/experiments/cranelift/src/scoped_byte_copy.rs", "compiler/experiments/cranelift/src/collection_provenance.rs")
ADDED = ("compiler/experiments/cranelift/src/ticket_result.rs",
    "compiler/experiments/cranelift/src/ticket_result_use.rs", "compiler/experiments/cranelift/src/ticket_result_tests.rs",
    "compiler/experiments/cranelift/src/testdata/scoped_ticket_publication_producer.canonical",
    "compiler/experiments/cranelift/src/testdata/scoped_ticket_content_producer.canonical",
    "tests/cranelift/phase26_ticket_publication.gst", "scripts/phase26_ticket_publication_guard.py",
    "scripts/phase26_ticket_publication_registration.py", BASELINE, "compiler/CRANELIFT_PHASE26_TICKET_PUBLICATION.md")
STEP = ("      - name: Phase 26 generic post-cleanup ticket publication\n"
        "        run: just guard-cranelift-phase26-ticket-publication\n\n"
        "      - name: Retain ticket publication source and native evidence\n"
        "        if: always()\n"
        "        uses: actions/upload-artifact@v4\n"
        "        with:\n"
        "          name: phase26-ticket-publication\n"
        "          path: build/guards/phase26_ticket_publication/\n\n")
ANCHOR = ("      - name: Phase 26 checked collection validity and copy preservation\n"
          "        run: just guard-cranelift-phase26-collection-validity\n\n")
RECIPE = ("\n# Generic completed-output publication after exact region cleanup.\n" + GUARD + ":\n"
    "    python3 scripts/phase26_ticket_publication_registration.py validate\n"
    "    python3 scripts/phase26_ticket_publication_registration.py inversions\n"
    "    cargo test --locked --manifest-path compiler/experiments/cranelift/Cargo.toml ticket_result_tests\n"
    "    python3 scripts/phase26_ticket_publication_guard.py\n")

def require(ok, message):
    if not ok:
        raise SystemExit(f"{GUARD}: {message}")

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def fingerprint(value):
    return sha(json.dumps(value, sort_keys=True, separators=(",", ":")).encode())

def decode_baseline(raw):
    require(sha(raw) == BASELINE_SHA256, "ticket predecessor baseline bytes drifted")
    return json.loads(gzip.decompress(raw))

@lru_cache(maxsize=1)
def baseline():
    return decode_baseline((ROOT / BASELINE).read_bytes())

def base_bytes(path):
    return base64.b64decode(baseline()["files"][path], validate=True)

def record(registry):
    return registry.get("phase26_activation_audit", {}).get(KEY)

def identity(registry):
    row = record(registry)
    require(row and row["predecessor_main"] == BASE and row["owner"] == "cranelift" and
        row["guard"] == GUARD and row["phase26_1_status"] == "OPEN" and
        [p["path"] for p in row["changed_files"]] == list(CHANGED) and
        [p["path"] for p in row["added_files"]] == list(ADDED), "ticket identity or pinned population drifted")
    return row

def prior_digest(registry, path, live):
    live = successor.prior_digest(registry, path, live)
    if not record(registry) or path not in CHANGED:
        return live
    pin = next(p for p in identity(registry)["changed_files"] if p["path"] == path)
    # Repeated predecessor normalization is harmless only while the physical
    # current bytes still match the successor. A rollback cannot pass this gate.
    require(successor.prior_digest(registry, path, sha((ROOT / path).read_bytes())) == pin["current_digest"] and
        pin["previous_digest"] == sha(base_bytes(path)) and
        live in (pin["current_digest"], pin["previous_digest"]), f"R4 changed file drifted: {path} (ticket successor)")
    return pin["previous_digest"]

def prior_bytes(registry, path, live):
    live = successor.prior_bytes(registry, path, live)
    if not record(registry) or path not in CHANGED:
        return live
    prior_digest(registry, path, sha(live))
    return base_bytes(path)

def project(registry, kind, current):
    current = successor.project(registry, kind, current)
    if not record(registry):
        return current
    if kind == "text":
        require(isinstance(current, list), "R4 text live projection drifted (ticket successor)")
        owned = set(CHANGED + ADDED)
        subset = [row for row in current if row["path"] in owned]
        require(fingerprint(subset) == identity(registry)["text_owned_digest"],
            "R4 text live projection drifted (ticket successor)")
        # Preserve foreign mutations for the predecessor's own checks. Only
        # this successor's changed/added rows may be normalized away.
        previous = [row for row in baseline()["projections"][kind] if row["path"] in owned]
        foreign = [row for row in current if row["path"] not in owned]
        return sorted(copy.deepcopy(foreign + previous), key=lambda row: row["path"])
    require(fingerprint(current) == identity(registry)["projections"][kind],
        f"R4 {kind} live projection drifted (ticket successor)")
    return copy.deepcopy(baseline()["projections"][kind])

def project_registry(registry):
    result = successor.project_registry(registry)
    result.get("phase26_activation_audit", {}).pop(KEY, None)
    return result

def workflow_predecessor(text):
    require(text.count(STEP) == 1, "ticket owning CI step drifted")
    return text.replace(STEP, "", 1)

def prior_render_digest(registry, live):
    live = successor.prior_render_digest(registry, live)
    if not record(registry):
        return live
    require(live == identity(registry)["spelling_render_current_digest"],
        "R4 current spelling review is stale or missing (ticket successor)")
    old = json.loads(base_bytes("scripts/cranelift_feature_registry.json"))
    return old["phase26_activation_audit"]["production_trust_successor_v1"]["spelling_render_current_digest"]

def current_projections():
    import phase26_r4_collection_registration as r4
    import phase26_r3_zlib_adapter_registration as r3
    result = {("r4_text" if key == "text" else key): edge["current"]
              for key, edge in r4.live_projections().items()}
    result["r4_record"] = r4.build_record()
    result["text"] = r3.raw_text_surfaces()
    return result

def build_record():
    import phase24_semantic_spelling_inventory as spelling
    sites = spelling.source_sites()
    projections = current_projections()
    return dict(predecessor_main=BASE, owner="cranelift", guard=GUARD, phase26_1_status="OPEN",
        changed_files=[dict(path=p, previous_digest=sha(base_bytes(p)), current_digest=sha((ROOT / p).read_bytes())) for p in CHANGED],
        added_files=[dict(path=p, digest=sha((ROOT / p).read_bytes())) for p in ADDED],
        text_owned_digest=fingerprint([row for row in projections["text"] if row["path"] in CHANGED + ADDED]),
        projections={key: fingerprint(value) for key, value in projections.items()},
        spelling_render_current_digest=sha(spelling.render(spelling.load_authority(), sites, spelling.manifest_summary(sites)).encode()))

def validate():
    registry = json.loads(REGISTRY.read_text())
    row = identity(registry)
    require(project_registry(registry) == json.loads(base_bytes("scripts/cranelift_feature_registry.json")),
        "ticket changed frozen predecessor or foreign registry rows")
    for pin in row["changed_files"]:
        prior_digest(registry, pin["path"], sha((ROOT / pin["path"]).read_bytes()))
    for pin in row["added_files"]:
        require(pin["digest"] == successor.prior_digest(registry, pin["path"], sha((ROOT / pin["path"]).read_bytes())), f"ticket added file drifted: {pin['path']}")
    old = base_bytes(".github/workflows/pr-fast.yml").decode()
    require(old.count(ANCHOR) == 1 and successor.prior_bytes(registry, ".github/workflows/pr-fast.yml", (ROOT / ".github/workflows/pr-fast.yml").read_bytes()).decode() == old.replace(ANCHOR, ANCHOR + STEP, 1),
        "ticket workflow changed predecessor obligations, deadlines or owning step")
    require(successor.prior_bytes(registry, "justfile", (ROOT / "justfile").read_bytes()) == base_bytes("justfile") + RECIPE.encode(), "ticket owning recipe drifted")
    levels = json.loads(successor.prior_bytes(registry, "scripts/cranelift_test_levels.json", (ROOT / "scripts/cranelift_test_levels.json").read_bytes()))
    require(levels["guards"].pop(GUARD, None) == 2 and levels == json.loads(base_bytes("scripts/cranelift_test_levels.json")),
        "ticket levels or predecessor guards drifted")
    for kind, value in current_projections().items():
        project(registry, kind, value)
    print(GUARD + ": exact additive registration PASS")

def inversions():
    validate()
    registry = json.loads(REGISTRY.read_text())
    def rejected(label, callback, expected):
        try:
            callback()
        except SystemExit as error:
            require(expected in str(error), f"{label}: REJECTED (different assertion): {error}")
            print(label + ": REJECTED (expected assertion)")
        else:
            raise SystemExit(label + ": ACCEPTED")
    rejected("substituted predecessor", lambda: decode_baseline(b"substituted"), "ticket predecessor baseline")
    for path in CHANGED:
        rejected("substituted " + path, lambda path=path: prior_digest(registry, path, "0" * 64), "R4 changed file drifted")
    from unittest.mock import patch
    original_read = Path.read_bytes
    for path in CHANGED:
        def old_bytes(candidate, path=path):
            return base_bytes(path) if candidate == ROOT / path else original_read(candidate)
        pin = next(p for p in identity(registry)["changed_files"] if p["path"] == path)
        require(pin["current_digest"] != pin["previous_digest"], "ticket pin did not move: " + path)
        with patch.object(Path, "read_bytes", old_bytes):
            rejected("rolled-back " + path,
                lambda path=path, pin=pin: prior_digest(registry, path, pin["previous_digest"]), "R4 changed file drifted")
    foreign = copy.deepcopy(registry)
    foreign["phase26_activation_audit"]["production_trust_successor_v1"]["phase26_1_status"] = "DONE"
    rejected("foreign production mutation", lambda: require(
        project_registry(foreign) == json.loads(base_bytes("scripts/cranelift_feature_registry.json")),
        "ticket changed frozen predecessor or foreign registry rows"), "ticket changed frozen predecessor")
    for kind in identity(registry)["projections"]:
        rejected("changed " + kind, lambda kind=kind: project(registry, kind, "substituted"), f"R4 {kind} live projection drifted")
    import phase26_r3_zlib_adapter_registration as r3
    raw = r3.raw_text_surfaces()
    owned = next(row for row in raw if row["path"] in CHANGED + ADDED)
    for label, changed in [
        ("substituted owned text", [dict(row, digest="0" * 64) if row == owned else row for row in raw]),
        ("omitted owned text", [row for row in raw if row != owned]),
        ("duplicated owned text", raw + [owned]),
    ]:
        rejected(label, lambda changed=changed: project(registry, "text", changed), "R4 text live projection drifted")
    foreign = next(row for row in raw if row["path"] not in CHANGED + ADDED)
    changed = [dict(row, digest="0" * 64) if row == foreign else row for row in raw]
    forwarded = project(registry, "text", changed)
    require(next(row for row in forwarded if row["path"] == foreign["path"])["digest"] == "0" * 64,
        "ticket projection hid foreign text substitution")
    require(sum(row["path"] == foreign["path"] for row in project(registry, "text", raw + [foreign])) == 2,
        "ticket projection hid foreign text duplication")
    workflow = (ROOT / ".github/workflows/pr-fast.yml").read_text()
    rejected("omitted owning CI step", lambda: workflow_predecessor(workflow.replace(STEP, "", 1)), "ticket owning CI step")
    rejected("conditional owning CI step", lambda: workflow_predecessor(workflow.replace(
        STEP, STEP.replace("        run:", "        if: false\n        run:"), 1)), "ticket owning CI step")
    print(GUARD + ": source, projection and owning-step inversions PASS")

if __name__ == "__main__":
    if sys.argv[1:] == ["validate"]:
        validate()
    elif sys.argv[1:] == ["inversions"]:
        inversions()
    else:
        raise SystemExit("usage: phase26_ticket_publication_registration.py validate|inversions")
