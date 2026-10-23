#!/usr/bin/env python3
"""Exact additive registration for OD20 checked collection operations."""
from __future__ import annotations
import copy
import hashlib
import json
import subprocess
import sys
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = "6bca6cdde2a3966758fc3fb40e04fc3115e270ad"
KEY = "collection_validity_r4_successor"
VERSION = "phase26_1r4_collection_validity_v1"
GUARD = "guard-cranelift-phase26-collection-validity"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
CI_STEP = ("      - name: Phase 26 checked collection validity and copy preservation\n"
           "        run: just guard-cranelift-phase26-collection-validity\n\n")
REBUILD_STEP = ("      - name: Phase 21 native rebuild reproducibility authority\n"
                "        run: just guard-cranelift-phase21-native-rebuild-reproducibility-contract\n")
BUNDLE_STEP = ("      - name: Full-program bundle validation smoke\n"
               "        run: just guard-mir-native-full-program-bundle-validation-smoke\n\n")
SHARD_STEP = ('      - name: Run PR fast shard\n'
              '        run: just guard-pr-fast-shard "${{ matrix.shard }}"\n\n')
QUALIFICATION_STEPS = '''      - name: Run PR fast shard
        if: matrix.shard == 'routed-return-int'
        run: just guard-pr-fast-shard "${{ matrix.shard }}"

      - name: Prepare native compiler qualification package
        if: matrix.shard == 'native-compiler-qualification'
        run: |
          chmod +x ./gust build/gust-native-backend
          install -d build/phase10-package/bin
          install -m 0755 gust build/phase10-package/bin/gust
          install -m 0755 build/gust-native-backend build/phase10-package/bin/gust-native-backend
          install -m 0644 build/gust-runtime-package.a build/phase10-package/bin/gust-runtime-package.a
          test -x build/phase10-package/bin/gust
          test -x build/phase10-package/bin/gust-native-backend

      - name: Phase 21 native rebuild reproducibility authority
        if: matrix.shard == 'native-compiler-qualification'
        run: just guard-cranelift-phase21-native-rebuild-reproducibility-contract

      - name: Full-program bundle validation smoke
        if: matrix.shard == 'native-compiler-qualification'
        run: just guard-mir-native-full-program-bundle-validation-smoke

'''
CHANGED = (
    "GUST_LANE_STATE.md", ".github/workflows/pr-fast.yml", "justfile",
    ".github/workflows/phase21-typed-query-noop-surface.yml",
    "scripts/cranelift_test_levels.json",
    "compiler/typechecker.gst", "compiler/mir_native_backend_full_program_source.gst",
    "compiler/mir_native_backend_generic_source.gst",
    "compiler/mir_native_backend_collection_string_source.gst",
    "compiler/mir_native_backend_filesystem_allocation_source.gst",
    "compiler/mir_native_backend_module_import_source.gst",
    "compiler/mir_native_backend_resource_sync_source.gst",
    "compiler/mir_native_backend_structured_cfg_source.gst",
    "compiler/experiments/cranelift/src/full_program.rs",
    "scripts/phase26_r2_scoped_copy_registration.py",
    "scripts/phase26_r2_scoped_copy.sh",
    "scripts/phase26_r3_zlib_adapter_registration.py",
    "scripts/phase24_semantic_spelling_inventory.py",
)
ADDED = (
    "compiler/experiments/cranelift/src/checked_collection.rs",
    "compiler/experiments/cranelift/src/checked_collection_tests.rs",
    "compiler/typechecker_phase26_collection_authority_test_entry.gst",
    "compiler/CRANELIFT_PHASE26_COLLECTION_SPELLING_INVENTORY.md",
    "compiler/CRANELIFT_PHASE26_COLLECTION_VALIDITY.md",
    "scripts/phase26_r4_collection_registration.py",
    "scripts/phase26_r4_collection_guard.py",
    "scripts/phase26_r4_frontend_rejection.py",
    "tests/cranelift/phase26_r4_default_collection_rejected.gst",
    "tests/cranelift/phase26_r4_inferred_scalar.gst",
    "tests/cranelift/phase26_r4_metadata_reference_rejected.gst",
    "tests/cranelift/phase26_r4_metadata_write_rejected.gst",
)
ARTIFACT_MAXIMUM = 10616832

def require(ok: bool, message: str) -> None:
    if not ok: raise SystemExit(f"{GUARD}: {message}")

@lru_cache(maxsize=1)
def ensure_base() -> None:
    if subprocess.run(["git", "cat-file", "-e", BASE + "^{commit}"], cwd=ROOT,
                      stderr=subprocess.DEVNULL).returncode != 0:
        subprocess.run(["git", "fetch", "--no-tags", "--depth=1", "origin", BASE],
                       cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
        actual = subprocess.check_output(["git", "rev-parse", "FETCH_HEAD"], cwd=ROOT, text=True).strip()
        require(actual == BASE, "R4 predecessor fetch changed identity")
    actual = subprocess.check_output(["git", "rev-parse", BASE + "^{commit}"], cwd=ROOT, text=True).strip()
    require(actual == BASE, "R4 predecessor identity changed")

@lru_cache(maxsize=None)
def base_bytes(path: str) -> bytes:
    ensure_base()
    return subprocess.check_output(["git", "show", f"{BASE}:{path}"], cwd=ROOT)

def sha(raw: bytes) -> str: return hashlib.sha256(raw).hexdigest()
def digest(path: str) -> str: return sha((ROOT / path).read_bytes())
def base_registry() -> dict: return json.loads(base_bytes("scripts/cranelift_feature_registry.json"))
def record(registry: dict) -> dict: return registry.get("phase26_activation_audit", {}).get(KEY, {})

def expected_workflow() -> str:
    """Partition two live compiler checks; preserve every predecessor command."""
    text = base_bytes(".github/workflows/pr-fast.yml").decode()
    for before, after in [
        ("      - name: Phase 26 FFI position policy\n", CI_STEP + "      - name: Phase 26 FFI position policy\n"),
        (REBUILD_STEP, ""),
        (BUNDLE_STEP, ""),
        ("          - routed-return-int\n", "          - routed-return-int\n          - native-compiler-qualification\n"),
        (SHARD_STEP, QUALIFICATION_STEPS),
    ]:
        require(text.count(before) == 1, "R4 CI partition predecessor anchor drifted")
        text = text.replace(before, after, 1)
    return text

def check_workflow(text: str) -> None:
    import phase26_production_registration as production
    if text == (ROOT / ".github/workflows/pr-fast.yml").read_text():
        text = production.project(json.loads(REGISTRY.read_text()), "workflow", text)
    require(text == expected_workflow(), "R4 CI partition or owning step drifted")

def identity(registry: dict) -> dict:
    value = record(registry)
    require(value.get("contract_version") == VERSION and value.get("predecessor_main_sha") == BASE and
            value.get("owner") == "cranelift" and value.get("owning_guard") == GUARD and
            value.get("release_status") == "capability_only_wrapper_and_release_open" and
            value.get("failure_scope") == "deterministic_process_native_trap_no_unwind" and
            value.get("allocator_abi") == "u32_offset_encoded_in_i32_exhaustion_aborts" and
            value.get("new_i32_allocation_byte_ceiling") is False and
            value.get("compiler_artifact_maximum_unchanged") == ARTIFACT_MAXIMUM,
            "R4 identity or selected semantic boundary drifted")
    require([row["path"] for row in value.get("changed_files", [])] == list(CHANGED) and
            [row["path"] for row in value.get("added_files", [])] == list(ADDED),
            "R4 pinned file population drifted")
    return value

def prior_digest(registry: dict, path: str, live: str) -> str:
    import phase26_production_registration as production
    live = production.prior_digest(registry, path, live)
    if not record(registry): return live
    rows = [row for row in identity(registry)["changed_files"] if row["path"] == path]
    if not rows: return live
    row = rows[0]
    require(row["current_digest"] == live and row["previous_digest"] == sha(base_bytes(path)),
            f"R4 changed file drifted: {path}")
    return row["previous_digest"]

def projection_digest(value) -> str:
    return sha(json.dumps(value, sort_keys=True, separators=(",", ":")).encode())

def owned_text(rows: list[dict]) -> list[dict]:
    return [row for row in rows if row["path"] in CHANGED or row["path"] in ADDED]

def previous_owned_text() -> list[dict]:
    import phase23_mir_to_c_deprecation_opening as p23
    rows = []
    for path in sorted(CHANGED):
        raw = base_bytes(path)
        counts = {name: len(pattern.findall(raw.decode())) for name, pattern in p23.SURFACE_PATTERNS.items()}
        if not any(counts.values()): continue
        classification, action, removal, falsifier = p23.classify_surface(path)
        rows.append({"path": path, "digest": sha(raw), "match_counts": counts,
            "classification": classification, "owner": p23.owner_for_path(path),
            "current_route": "tracked_MIR_to_C_or_generated_C_surface",
            "deprecation_action": action, "removal_phase": removal, "falsifier": falsifier})
    return rows

def project_text(registry: dict, current: list[dict]) -> list[dict]:
    value = identity(registry)["projections"]["text"]
    require(isinstance(current, list) and projection_digest(owned_text(current)) == value["current_digest"],
            "R4 text live projection drifted")
    before = previous_owned_text()
    require(projection_digest(before) == value["previous_digest"], "R4 text predecessor drifted")
    prior = {row["path"]: row for row in before}
    rows = []
    for row in current:
        path = row["path"]
        if path in CHANGED or path in ADDED:
            if path in prior: rows.append(copy.deepcopy(prior.pop(path)))
        else:
            # Foreign rows, including their order and duplicates, belong to
            # their existing validators. Never normalize or freeze them here.
            rows.append(copy.deepcopy(row))
    for path, row in sorted(prior.items()):
        index = next((i for i, item in enumerate(rows) if item["path"] > path), len(rows))
        rows.insert(index, copy.deepcopy(row))
    return rows

def project(registry: dict, kind: str, current):
    import phase26_production_registration as production
    current = production.project(registry, kind, current)
    if not record(registry): return current
    if kind == "text": return project_text(registry, current)
    value = identity(registry)["projections"][kind]
    require(projection_digest(current) == value["current_digest"], f"R4 {kind} live projection drifted")
    baseline = base_registry()["phase26_activation_audit"]
    if kind == "spelling": expected = baseline["zlib_adapter_r3_successor"]["spelling_inventory_successor"]["current_inventory_summary"]
    elif kind == "filename": expected = baseline["scoped_byte_copy_r2_successor"]["filename_site_successor"]["current_sites"]
    elif kind == "r3_record": expected = baseline["zlib_adapter_r3_successor"]
    elif kind == "workflow": expected = base_bytes(".github/workflows/pr-fast.yml").decode()
    elif kind == "production": expected = baseline["zlib_adapter_r3_successor"]["production_audit_successor"]["current_audit"]
    else: raise SystemExit(f"unknown R4 projection: {kind}")
    require(value["previous_digest"] == projection_digest(expected), f"R4 {kind} predecessor drifted")
    before = expected
    if kind == "filename":
        without_line = lambda row: {key: value for key, value in row.items() if key != "line"}
        require(len(current) == len(before) == 3 and
                all(without_line(now) == without_line(old) for now, old in zip(current, before)),
                "R4 filename selectors changed beyond line shifts")
    return copy.deepcopy(before)

def project_registry(registry: dict) -> dict:
    import phase26_production_registration as production
    historical = production.project_registry(registry)
    historical.get("phase26_activation_audit", {}).pop(KEY, None)
    return historical

def spelling_review_path(registry: dict, predecessor: Path) -> Path:
    if not record(registry): return predecessor
    identity(registry)
    relative = predecessor.relative_to(ROOT).as_posix()
    require(predecessor.read_bytes() == base_bytes(relative),
            "R4 rewrote the frozen predecessor spelling review")
    return ROOT / "compiler/CRANELIFT_PHASE26_COLLECTION_SPELLING_INVENTORY.md"

def spelling_review_text(registry: dict, full_review: str) -> str:
    if not record(registry): return full_review
    return ("# Phase 26 collection spelling inventory successor\n\n"
            "Generated from the complete live source scan; no historical review is rewritten.\n\n"
            f"- Predecessor main: `{BASE}`\n"
            f"- Complete current rendered inventory SHA-256: `{__import__('phase26_production_registration').prior_render_digest(registry, sha(full_review.encode()))}`\n"
            f"- Frozen predecessor review SHA-256: `{sha(base_bytes('compiler/CRANELIFT_PHASE24_SEMANTIC_SPELLING_INVENTORY.md'))}`\n\n"
            "The owning registration separately binds the complete source-site manifest, classification\n"
            "counts, exact source changes and source-file population. The full current scan and its\n"
            "stale-line, omission, duplication and classification falsifiers remain enforced.\n"
            "Reproduce the full current report with `python3 scripts/phase26_r4_collection_registration.py spelling-full`.\n")

def check_spelling_review(registry: dict, full_review: str) -> None:
    path = spelling_review_path(registry, ROOT / "compiler/CRANELIFT_PHASE24_SEMANTIC_SPELLING_INVENTORY.md")
    require(path.is_file() and path.read_text() == spelling_review_text(registry, full_review),
            "R4 current spelling review is stale or missing")

def live_projections() -> dict:
    import phase26_r3_zlib_adapter_registration as r3
    from phase24_semantic_spelling_inventory import source_sites, manifest_summary
    from phase24_filename_behavior_characterization import source_sites as filename_sites
    from phase23_production_release_audit import scan as production_scan
    old = base_registry()["phase26_activation_audit"]
    current_text = r3.raw_text_surfaces()
    production = production_scan()
    edges = {
            "text": {"previous": previous_owned_text(), "current": owned_text(current_text)},
            "spelling": {"previous": old["zlib_adapter_r3_successor"]["spelling_inventory_successor"]["current_inventory_summary"], "current": manifest_summary(source_sites())},
            "filename": {"previous": old["scoped_byte_copy_r2_successor"]["filename_site_successor"]["current_sites"], "current": filename_sites()},
            "r3_record": {"previous": old["zlib_adapter_r3_successor"], "current": r3.build_record()},
            "production": {"previous": old["zlib_adapter_r3_successor"]["production_audit_successor"]["current_audit"], "current": production},
            "workflow": {"previous": base_bytes(".github/workflows/pr-fast.yml").decode(), "current": (ROOT / ".github/workflows/pr-fast.yml").read_text()},
        }
    return edges

def build_record() -> dict:
    return {"contract_version": VERSION, "predecessor_main_sha": BASE, "owner": "cranelift", "owning_guard": GUARD,
        "release_status": "capability_only_wrapper_and_release_open",
        "failure_scope": "deterministic_process_native_trap_no_unwind",
        "allocator_abi": "u32_offset_encoded_in_i32_exhaustion_aborts", "new_i32_allocation_byte_ceiling": False,
        "compiler_artifact_maximum_unchanged": ARTIFACT_MAXIMUM,
        "changed_files": [{"path": path, "previous_digest": sha(base_bytes(path)), "current_digest": digest(path)} for path in CHANGED],
        "added_files": [{"path": path, "digest": digest(path)} for path in ADDED],
        "projections": {kind: {"previous_digest": projection_digest(edge["previous"]),
            "current_digest": projection_digest(edge["current"])}
            for kind, edge in live_projections().items()}}

def write_record(value: dict) -> None:
    # Insert only the successor. Preserve historical registry bytes, including
    # deliberately retained formatting, instead of reserializing the ledger.
    marker = '  "phase26_activation_audit": {\n'
    baseline = base_bytes("scripts/cranelift_feature_registry.json").decode()
    require(baseline.count(marker) == 1, "R4 registry insertion anchor drifted")
    field = "\n".join("  " + line for line in json.dumps({KEY: value}, indent=2).splitlines()[1:-1])
    REGISTRY.write_text(baseline.replace(marker, marker + field + ",\n", 1))

def validate() -> None:
    registry = json.loads(REGISTRY.read_text()); value = identity(registry)
    import phase26_production_registration as production
    require(value == production.project(registry, "r4_record", build_record()), "R4 registration or live census drifted")
    require(project_registry(registry) == base_registry(), "R4 changed a frozen registry field")
    workflow = (ROOT / ".github/workflows/pr-fast.yml").read_text()
    check_workflow(workflow)
    import phase26_production_registration as production
    just = production.prior_bytes(registry, "justfile", (ROOT / "justfile").read_bytes()).decode()
    suffix = "\n# OD20 registered collection validity, process traps, and copy preservation.\n" + GUARD + ":\n    python3 scripts/phase26_r4_collection_registration.py validate\n    python3 scripts/phase26_r4_collection_registration.py inversions\n    python3 scripts/phase26_r4_collection_guard.py\n"
    require(just == base_bytes("justfile").decode() + suffix, "R4 owning recipe or predecessor recipes drifted")
    levels = json.loads(production.prior_bytes(registry, "scripts/cranelift_test_levels.json", (ROOT / "scripts/cranelift_test_levels.json").read_bytes()))
    require(levels["guards"].get(GUARD) == 2, "R4 owning test level drifted")
    del levels["guards"][GUARD]
    require(levels == json.loads(base_bytes("scripts/cranelift_test_levels.json")), "R4 changed predecessor test levels")
    for kind, edge in live_projections().items():
        if kind == "text" and production.record(registry):
            # This census is already restricted to the R4-owned text subset.
            # Validate that exact subset before its predecessor projection.
            project_text(registry, production.project(registry, "r4_text", edge["current"]))
        else:
            project(registry, kind, edge["current"])
    import phase24_semantic_spelling_inventory as spelling
    rows = spelling.source_sites()
    check_spelling_review(registry, spelling.render(spelling.load_authority(), rows, spelling.manifest_summary(rows)))
    print(f"{GUARD}: exact additive registration ok")

def inversions() -> None:
    registry = json.loads(REGISTRY.read_text()); validate()
    def rejected(label, callback, expected):
        try: callback()
        except SystemExit as error:
            require(expected in str(error), f"{label}: REJECTED (different assertion): {error}")
            print(f"{label}: REJECTED (expected assertion)")
        else: raise SystemExit(f"{GUARD}: {label}: ACCEPTED")
    for path in CHANGED:
        # Operational prose is explicitly retired by the enrollment successor;
        # its owning inversions reject re-admission into compiler byte pins.
        if path == "GUST_LANE_STATE.md" and __import__("phase26_production_registration").record(registry):
            continue
        rejected(f"substituted {path}", lambda path=path: prior_digest(registry, path, "0" * 64), f"R4 changed file drifted: {path}")
        rejected(f"old state {path}", lambda path=path: prior_digest(registry, path, sha(base_bytes(path))), f"R4 changed file drifted: {path}")
    for kind in identity(registry)["projections"]:
        rejected(f"missing {kind}", lambda kind=kind: project(registry, kind, None), f"R4 {kind} live projection drifted")
    workflow = expected_workflow()
    changes = [
        ("missing qualification shard", "          - native-compiler-qualification\n", ""),
        ("duplicate qualification shard", "          - native-compiler-qualification\n", "          - native-compiler-qualification\n" * 2),
        ("missing native rebuild command", "        run: just guard-cranelift-phase21-native-rebuild-reproducibility-contract\n", ""),
        ("duplicate native rebuild command", "        run: just guard-cranelift-phase21-native-rebuild-reproducibility-contract\n", "        run: just guard-cranelift-phase21-native-rebuild-reproducibility-contract\n" * 2),
        ("substituted native rebuild command", "        run: just guard-cranelift-phase21-native-rebuild-reproducibility-contract\n", "        run: true\n"),
        ("missing bundle smoke command", "        run: just guard-mir-native-full-program-bundle-validation-smoke\n", ""),
        ("substituted bundle smoke command", "        run: just guard-mir-native-full-program-bundle-validation-smoke\n", "        run: true\n"),
        ("duplicate bundle smoke", "        run: just guard-mir-native-full-program-bundle-validation-smoke\n", "        run: just guard-mir-native-full-program-bundle-validation-smoke\n" * 2),
        ("unprepared package", "          install -m 0755 gust build/phase10-package/bin/gust\n", ""),
        ("missing executable worker", "          test -x build/phase10-package/bin/gust-native-backend\n", ""),
        ("changed shard selection", "        if: matrix.shard == 'routed-return-int'\n", "        if: false\n"),
        ("missing final shard dependency", "needs: [guard, level1, phase20-nested-brand-annotation, phase26-ffi-position]", "needs: [level1, phase20-nested-brand-annotation, phase26-ffi-position]"),
        ("increased Level1 deadline", "    timeout-minutes: 120\n", "    timeout-minutes: 121\n"),
        ("weakened shard build dependency", "    name: guard / ${{ matrix.shard }}\n    runs-on: ubuntu-latest\n    timeout-minutes: 60\n    needs: build\n", "    name: guard / ${{ matrix.shard }}\n    runs-on: ubuntu-latest\n    timeout-minutes: 60\n    needs: []\n"),
        ("increased shard deadline", "    name: guard / ${{ matrix.shard }}\n    runs-on: ubuntu-latest\n    timeout-minutes: 60\n", "    name: guard / ${{ matrix.shard }}\n    runs-on: ubuntu-latest\n    timeout-minutes: 61\n"),
    ]
    for label, before, after in changes:
        require(workflow.count(before) == 1, f"{label} inversion lost its mechanism")
        changed = workflow.replace(before, after, 1)
        require(changed != workflow, f"{label} inversion did not change the workflow")
        rejected(label, lambda changed=changed: check_workflow(changed), "R4 CI partition or owning step drifted")
    for name in ("Prepare native compiler qualification package", "Phase 21 native rebuild reproducibility authority", "Full-program bundle validation smoke"):
        before = f"      - name: {name}\n        if: matrix.shard == 'native-compiler-qualification'\n"
        require(workflow.count(before) == 1, "qualification condition inversion lost its mechanism")
        changed = workflow.replace(before, f"      - name: {name}\n        if: false\n", 1)
        rejected(f"disabled {name}", lambda changed=changed: check_workflow(changed), "R4 CI partition or owning step drifted")
    import phase26_r3_zlib_adapter_registration as r3
    text = r3.raw_text_surfaces()
    selected = next(row for row in owned_text(text) if row["path"] != "GUST_LANE_STATE.md")
    for label, changed in [
        ("substituted registered text", [dict(row, digest="0" * 64) if row["path"] == selected["path"] else row for row in text]),
        ("omitted registered text", [row for row in text if row["path"] != selected["path"]]),
        ("duplicated registered text", text + [selected]),
    ]:
        rejected(label, lambda changed=changed: project(registry, "text", changed), "R4 text live projection drifted")
    foreign = next(row for row in text if row["path"] not in CHANGED and row["path"] not in ADDED)
    altered_foreign = dict(foreign, digest="0" * 64)
    changed = [altered_foreign if row["path"] == foreign["path"] else row for row in text]
    forwarded = project(registry, "text", changed)
    require(next(row for row in forwarded if row["path"] == foreign["path"]) == altered_foreign,
            "R4 rewrote a foreign text row")
    duplicate_foreign = project(registry, "text", changed + [altered_foreign])
    require(sum(row["path"] == foreign["path"] for row in duplicate_foreign) == 2,
            "R4 hid a foreign duplicate from its owner")
    path = "scripts/phase26_call_cast_alias_finite_cast_plain_terminal_cast_chain_return_registration.py"
    require(path not in CHANGED and any(row["path"] == path for row in text), "R3 tamper probe lost its foreign mechanism")
    tampered = [dict(row, digest="0" * 64) if row["path"] == path else row for row in text]
    rejected("foreign forbidden tamper retains R3 rejection", lambda: r3.normalize_text_predecessor(
        registry, project(registry, "text", tampered)), "R3 text surface")
    print(f"{GUARD}: foreign rows and duplicates forwarded unchanged to predecessor owners")
    changed_sites = copy.deepcopy(live_projections()["filename"]["current"])
    changed_sites[0]["line"] += 1
    rejected("unregistered filename coordinate", lambda: project(registry, "filename", changed_sites), "R4 filename live projection drifted")
    rejected("stale current spelling view", lambda: check_spelling_review(registry, "substituted rendered report"), "R4 current spelling review is stale or missing")
    altered = copy.deepcopy(registry); altered["phase26_activation_audit"][KEY]["compiler_artifact_maximum_unchanged"] += 1
    rejected("changed live artifact budget", lambda: identity(altered), "R4 identity or selected semantic boundary drifted")
    from phase21_cranelift_built_compiler_programs import compiler_artifact_within_live_budget
    predecessor = registry["phase21_cranelift_built_compiler_programs"]
    require(compiler_artifact_within_live_budget(registry, predecessor, ARTIFACT_MAXIMUM) and
            not compiler_artifact_within_live_budget(registry, predecessor, ARTIFACT_MAXIMUM + 1) and
            compiler_artifact_within_live_budget(project_registry(registry), predecessor, ARTIFACT_MAXIMUM),
            "R4 live artifact boundary is absent")
    print(f"{GUARD}: additive inversions ok")

if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) == 2 else "validate"
    if command == "generate":
        write_record(build_record())
    elif command == "spelling-full":
        import phase24_semantic_spelling_inventory as spelling
        rows = spelling.source_sites()
        print(spelling.render(spelling.load_authority(), rows, spelling.manifest_summary(rows)))
    elif command == "validate": validate()
    elif command == "inversions": inversions()
    else: raise SystemExit("expected generate|validate|inversions")
