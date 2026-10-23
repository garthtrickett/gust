#!/usr/bin/env python3
"""Additive imported byte-boundary qualification over merged ticket support."""
from __future__ import annotations
import base64
import copy
from functools import lru_cache
import gzip
import hashlib
import json
from pathlib import Path
import sys
import phase26_ticket_composition_registration as successor

ROOT = Path(__file__).resolve().parents[1]
BASE = "a695662da8805d89ac7b592227231a7fef98ec2a"
KEY = "imported_native_successor_v1"
GUARD = "guard-cranelift-phase26-imported-native"
STATE = "GUST_LANE_STATE.md"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
BASELINE = "compiler/experiments/cranelift/imported-native/predecessor-baseline.json.gz"
BASELINE_SHA256 = "ef579491548fd501925745575dd59a4a3f969c5e4c261514c3603fa0270886fb"
CHANGED = (".github/workflows/pr-fast.yml", "justfile", "scripts/cranelift_test_levels.json",
    "scripts/phase26_ticket_publication_registration.py", "scripts/phase26_ticket_publication_guard.py",
    "compiler/mir_native_backend_module_import_source.gst", "compiler/mir_native_backend_full_program_source.gst")
ADDED = ("scripts/phase26_imported_native_registration.py", BASELINE,
    "compiler/CRANELIFT_PHASE26_IMPORTED_NATIVE.md")
STEP = ("      - name: Phase 26 imported native byte-boundary qualification\n"
        "        run: just guard-cranelift-phase26-imported-native\n\n"
        "      - name: Retain imported native source and execution evidence\n"
        "        if: always()\n"
        "        uses: actions/upload-artifact@v4\n"
        "        with:\n"
        "          name: phase26-imported-native\n"
        "          path: build/guards/phase26_imported_native/\n\n")
RECIPE = ("\n# Ordinary imported byte-boundary declarations retain independent package authority.\n"
    + GUARD + ":\n"
    "    python3 scripts/phase26_imported_native_registration.py validate\n"
    "    python3 scripts/phase26_imported_native_registration.py inversions\n"
    "    python3 scripts/phase26_ticket_publication_guard.py --imported\n")

def require(ok, message):
    if not ok:
        raise SystemExit(f"{GUARD}: {message}")

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def fingerprint(value):
    return sha(json.dumps(value, sort_keys=True, separators=(",", ":")).encode())

@lru_cache(maxsize=1)
def baseline():
    raw = (ROOT / BASELINE).read_bytes()
    require(sha(raw) == BASELINE_SHA256, "import predecessor baseline bytes drifted")
    value = json.loads(gzip.decompress(raw))
    require(value["base"] == BASE, "import predecessor identity drifted")
    return value

def base_bytes(path):
    return base64.b64decode(baseline()["files"][path], validate=True)

def record(registry):
    return registry.get("phase26_activation_audit", {}).get(KEY)

def identity(registry):
    row = record(registry)
    require(row and row["predecessor_main"] == BASE and row["owner"] == "cranelift" and
        row["guard"] == GUARD and row["phase26_1_status"] == "OPEN" and
        row["operational_state_excluded"] == STATE and
        [p["path"] for p in row["changed_files"]] == list(CHANGED) and
        [p["path"] for p in row["added_files"]] == list(ADDED),
        "import identity, file population or operational-state retirement drifted")
    require((ROOT / STATE).is_file() and (ROOT / STATE).stat().st_size > 0,
        "operational lane state is absent")
    return row

def prior_digest(registry, path, live):
    live = successor.prior_digest(registry, path, live)
    if not record(registry) or path not in CHANGED:
        return live
    pin = next(p for p in identity(registry)["changed_files"] if p["path"] == path)
    admitted = {pin["current_digest"], pin["previous_digest"]}
    predecessor = json.loads(base_bytes("scripts/cranelift_feature_registry.json"))
    ticket = predecessor["phase26_activation_audit"]["scoped_ticket_publication_successor_v1"]
    # Production's raw_digest already runs the ticket projection before its
    # prior_digest runs it again. Admit only that exact frozen ticket coordinate;
    # the physical file must still match this successor, even on a repeated pass.
    admitted.update(item["previous_digest"] for item in ticket["changed_files"] if item["path"] == path)
    require(successor.prior_digest(registry, path, sha((ROOT / path).read_bytes())) == pin["current_digest"] and
        pin["previous_digest"] == sha(base_bytes(path)) and
        live in admitted,
        f"R4 changed file drifted: {path} (import successor)")
    return pin["previous_digest"]

def prior_bytes(registry, path, live):
    live = successor.prior_bytes(registry, path, live)
    if not record(registry) or path not in CHANGED:
        return live
    prior_digest(registry, path, sha(live))
    return base_bytes(path)

def operational_text(current, previous, message):
    require(isinstance(current, list) and all(isinstance(row, dict) and "path" in row for row in current), message)
    require(sum(row["path"] == STATE for row in current) <= 1, message)
    return sorted(copy.deepcopy([row for row in current if row["path"] != STATE] +
        [row for row in previous if row["path"] == STATE]), key=lambda row: row["path"])

def operational_projection(kind, current):
    previous = baseline()["projections"][kind]
    message = f"R4 {kind} live projection drifted (import successor)"
    if kind in ("text", "r4_text"):
        return operational_text(current, previous, message)
    if kind == "r4_record":
        require(isinstance(current, dict) and set(current) == set(previous), message)
        result = copy.deepcopy(current)
        rows = result.get("changed_files")
        require(isinstance(rows, list) and sum(row.get("path") == STATE for row in rows) == 1, message)
        old_state = next(row for row in previous["changed_files"] if row["path"] == STATE)
        state = next(row for row in rows if row["path"] == STATE)
        # Only the operational current digest is retired. Its predecessor,
        # membership and every other file/projection remain independently pinned.
        require(set(state) == set(old_state) and state["previous_digest"] == old_state["previous_digest"] and
            state["current_digest"] in (sha((ROOT / STATE).read_bytes()), old_state["current_digest"]), message)
        state["current_digest"] = old_state["current_digest"]
        import phase26_r4_collection_registration as r4
        import phase26_r3_zlib_adapter_registration as r3
        live_text = r4.owned_text(r3.raw_text_surfaces())
        # The enclosing record may already be normalized to this predecessor.
        # Recomputed text must cross the same checked successor boundary before
        # this module retires only its operational-state digest.
        live_text = successor.project(json.loads(REGISTRY.read_text()), "r4_text", live_text)
        expected_text = operational_projection("r4_text", live_text)
        edge = result["projections"]["text"]
        require(edge["previous_digest"] == previous["projections"]["text"]["previous_digest"] and
            edge["current_digest"] in (fingerprint(live_text), fingerprint(expected_text)), message)
        edge["current_digest"] = fingerprint(expected_text)
        return result
    return current

def project(registry, kind, current):
    current = successor.project(registry, kind, current)
    if not record(registry):
        return current
    row = identity(registry)
    current = operational_projection(kind, current)
    if kind == "text":
        owned = set(CHANGED + ADDED)
        subset = [item for item in current if item["path"] in owned]
        require(fingerprint(subset) == row["text_owned_digest"], "R4 text live projection drifted (import successor)")
        previous = [item for item in baseline()["projections"][kind] if item["path"] in owned]
        foreign = [item for item in current if item["path"] not in owned]
        return sorted(copy.deepcopy(foreign + previous), key=lambda item: item["path"])
    require(fingerprint(current) == row["projections"][kind], f"R4 {kind} live projection drifted (import successor)")
    return copy.deepcopy(baseline()["projections"][kind])

def project_registry(registry):
    result = successor.project_registry(registry)
    result.get("phase26_activation_audit", {}).pop(KEY, None)
    return result

def prior_render_digest(registry, live):
    live = successor.prior_render_digest(registry, live)
    if not record(registry):
        return live
    require(live == identity(registry)["spelling_render_current_digest"],
        "R4 current spelling review is stale or missing (import successor)")
    old = json.loads(base_bytes("scripts/cranelift_feature_registry.json"))
    return old["phase26_activation_audit"]["scoped_ticket_publication_successor_v1"]["spelling_render_current_digest"]

def workflow_predecessor(text):
    if successor.record(json.loads(REGISTRY.read_text())):
        text = successor.workflow_predecessor(text)
    require(text.count(STEP) == 1, "import owning CI step drifted")
    return text.replace(STEP, "", 1)

def current_projections():
    import phase26_ticket_publication_registration as ticket
    return ticket.current_projections()

def build_record():
    import phase24_semantic_spelling_inventory as spelling
    sites = spelling.source_sites()
    projections = current_projections()
    return dict(predecessor_main=BASE, owner="cranelift", guard=GUARD, phase26_1_status="OPEN",
        operational_state_excluded=STATE,
        changed_files=[dict(path=p, previous_digest=sha(base_bytes(p)), current_digest=sha((ROOT / p).read_bytes())) for p in CHANGED],
        added_files=[dict(path=p, digest=sha((ROOT / p).read_bytes())) for p in ADDED],
        text_owned_digest=fingerprint([row for row in projections["text"] if row["path"] in CHANGED + ADDED]),
        projections={kind: fingerprint(operational_projection(kind, value)) for kind, value in projections.items()},
        spelling_render_current_digest=sha(spelling.render(spelling.load_authority(), sites, spelling.manifest_summary(sites)).encode()))

def validate():
    registry = json.loads(REGISTRY.read_text())
    row = identity(registry)
    require(project_registry(registry) == json.loads(base_bytes("scripts/cranelift_feature_registry.json")),
        "import changed frozen predecessor or foreign registry rows")
    for pin in row["changed_files"]:
        prior_digest(registry, pin["path"], sha((ROOT / pin["path"]).read_bytes()))
    for pin in row["added_files"]:
        require(pin["digest"] == successor.prior_digest(registry, pin["path"], sha((ROOT / pin["path"]).read_bytes())), "import added file drifted: " + pin["path"])
    import phase26_ticket_publication_registration as ticket
    old = base_bytes(".github/workflows/pr-fast.yml").decode()
    require(old.count(ticket.STEP) == 1 and successor.prior_bytes(registry, ".github/workflows/pr-fast.yml", (ROOT / ".github/workflows/pr-fast.yml").read_bytes()).decode() ==
        old.replace(ticket.STEP, ticket.STEP + STEP, 1), "import workflow changed predecessor commands or budgets")
    require(successor.prior_bytes(registry, "justfile", (ROOT / "justfile").read_bytes()) == base_bytes("justfile") + RECIPE.encode(), "import owning recipe drifted")
    levels = json.loads(successor.prior_bytes(registry, "scripts/cranelift_test_levels.json", (ROOT / "scripts/cranelift_test_levels.json").read_bytes()))
    require(levels["guards"].pop(GUARD, None) == 2 and levels == json.loads(base_bytes("scripts/cranelift_test_levels.json")),
        "import owning test level drifted")
    projections = current_projections()
    for kind, value in projections.items():
        project(registry, kind, value)
    print(GUARD + ": exact additive registration PASS")
    return projections

def inversions():
    projections = validate()
    registry = json.loads(REGISTRY.read_text())
    from unittest.mock import patch

    def rejected(label, callback, expected):
        try:
            callback()
        except SystemExit as error:
            verdict = "REJECTED (expected assertion)" if expected in str(error) else "REJECTED (different assertion)"
            print(label + ": " + verdict, flush=True)
            require(verdict == "REJECTED (expected assertion)", str(error))
        else:
            raise SystemExit(label + ": ACCEPTED")

    # First prove the successor is loaded and its physical patch is pinned.
    original_read = Path.read_bytes
    import phase26_ticket_publication_registration as ticket
    for pin in identity(registry)["changed_files"]:
        path = pin["path"]
        require(pin["current_digest"] != pin["previous_digest"], "import pin did not move: " + path)
        rejected("substituted " + path,
            lambda path=path: prior_digest(registry, path, "0" * 64), "R4 changed file drifted")
        def rolled_back(candidate, path=path):
            return base_bytes(path) if candidate == ROOT / path else original_read(candidate)
        with patch.object(Path, "read_bytes", rolled_back):
            rejected("rolled back " + path,
                lambda pin=pin: prior_digest(registry, pin["path"], pin["previous_digest"]), "R4 changed file drifted")
        once = ticket.prior_digest(registry, path, pin["current_digest"])
        require(ticket.prior_digest(registry, path, once) == once,
            "repeated ticket projection changed its frozen coordinate: " + path)

    changed = copy.deepcopy(registry)
    changed["phase26_activation_audit"][KEY]["changed_files"].append(dict(path=STATE))
    rejected("re-admitted operational byte pin", lambda: identity(changed), "operational-state retirement")
    changed = copy.deepcopy(registry)
    changed["phase26_activation_audit"][KEY]["operational_state_excluded"] = ""
    rejected("retired operational exclusion", lambda: identity(changed), "operational-state retirement")
    original_is_file = Path.is_file
    with patch.object(Path, "is_file", lambda p: False if p == ROOT / STATE else original_is_file(p)):
        rejected("missing operational state", lambda: identity(registry), "operational lane state is absent")
    original_stat = Path.stat
    from types import SimpleNamespace
    with patch.object(Path, "is_file", lambda p: True if p == ROOT / STATE else original_is_file(p)), \
         patch.object(Path, "stat", lambda p, **kw: SimpleNamespace(st_size=0) if p == ROOT / STATE else original_stat(p, **kw)):
        rejected("empty operational state", lambda: identity(registry), "operational lane state is absent")

    for kind in identity(registry)["projections"]:
        rejected("substituted " + kind, lambda kind=kind: project(registry, kind, "substituted"),
            f"R4 {kind} live projection drifted")
    for kind in ("text", "r4_text"):
        text = projections[kind]
        state = next(item for item in text if item["path"] == STATE)
        changed = [dict(item, digest="0" * 64) if item["path"] == STATE else item for item in text]
        require(project(registry, kind, changed) == project(registry, kind, text), "operational prose is still byte pinned")
        require(project(registry, kind, [item for item in text if item["path"] != STATE]) ==
            project(registry, kind, text), "operational text match count is still pinned")
        rejected("duplicated operational row " + kind, lambda kind=kind, text=text, state=state:
            project(registry, kind, text + [state]), f"R4 {kind} live projection drifted")
    text = projections["r4_text"]
    protected = next(item for item in text if item["path"] != STATE)
    for label, changed in (
        ("substitution", [dict(item, digest="0" * 64) if item == protected else item for item in text]),
        ("omission", [item for item in text if item != protected]),
        ("duplication", text + [protected]),
    ):
        rejected("protected R4 text " + label, lambda changed=changed:
            project(registry, "r4_text", changed), "R4 r4_text live projection drifted")
    text = projections["text"]
    owned = next(item for item in text if item["path"] in CHANGED + ADDED)
    for label, changed in (
        ("substitution", [dict(item, digest="0" * 64) if item == owned else item for item in text]),
        ("omission", [item for item in text if item != owned]),
        ("duplication", text + [owned]),
    ):
        rejected("protected import text " + label, lambda changed=changed:
            project(registry, "text", changed), "R4 text live projection drifted")
    foreign = next(item for item in text if item["path"] not in CHANGED + ADDED + (STATE,))
    changed = [dict(item, digest="0" * 64) if item == foreign else item for item in text]
    require(next(item for item in project(registry, "text", changed) if item["path"] == foreign["path"])["digest"] == "0" * 64,
        "import hid a foreign text mutation")
    require(sum(item["path"] == foreign["path"] for item in project(registry, "text", text + [foreign])) == 2,
        "import hid a foreign text duplication")
    changed = copy.deepcopy(projections["r4_record"])
    next(item for item in changed["changed_files"] if item["path"] == STATE)["previous_digest"] = "0" * 64
    rejected("historical operational predecessor mutation", lambda: project(registry, "r4_record", changed),
        "R4 r4_record live projection drifted")
    changed = copy.deepcopy(registry)
    changed["phase26_activation_audit"]["scoped_ticket_publication_successor_v1"]["phase26_1_status"] = "DONE"
    rejected("foreign ticket mutation", lambda: require(
        project_registry(changed) == json.loads(base_bytes("scripts/cranelift_feature_registry.json")),
        "import changed frozen predecessor"), "import changed frozen predecessor")
    workflow = (ROOT / ".github/workflows/pr-fast.yml").read_text()
    for label, changed in (
        ("omitted", workflow.replace(STEP, "", 1)),
        ("duplicated", workflow.replace(STEP, STEP + STEP, 1)),
        ("conditional", workflow.replace(STEP, STEP.replace("        run:", "        if: false\n        run:"), 1)),
    ):
        rejected(label + " import owning CI step", lambda changed=changed:
            workflow_predecessor(changed), "import owning CI step drifted")
    print(GUARD + ": pin, operational retirement and protected projection inversions PASS")

if __name__ == "__main__":
    if sys.argv[1:] == ["validate"]:
        validate()
    elif sys.argv[1:] == ["inversions"]:
        inversions()
    else:
        raise SystemExit("usage: phase26_imported_native_registration.py validate|inversions")
