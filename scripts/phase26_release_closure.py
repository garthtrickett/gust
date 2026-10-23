#!/usr/bin/env python3
"""Check first-release evidence; only exact final-main history can close 26.1.

Local and PR qualification is deliberately distinct from final-main closure.
Neither the existence of a historical workflow nor an earlier green main is
evidence for a later source tree. Public signatures are inputs, never secrets.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROFILE = ROOT / "compiler/experiments/cranelift/production"
AUTHORITY = ROOT / "compiler/phase26-release/release.json"
SHARDS = ("phase9-core", "phase19", "phase20", "phase18", "phase9g",
          "phase15", "phase16", "phase10", "phase11", "phase17")
PUBLIC_EXITS = {
    "compressed_bytes": 101, "decoded_bytes": 101, "empty_compression": 108,
    "empty_zero_destination": 100, "nonempty_zero_destination": 253,
    "corrupt": 252, "truncated": 252, "short_compression": 253,
    "short_decompression": 253, "invalid_level": 255, "negative_capacity": 255,
    "oversized_capacity": 254, "incompressible": 101, "roundtrip": 101,
    "copied_input": 110, "distinct_output_arena": 110,
}
PUBLIC_REJECTIONS = {"wrong_arena", "error_ticket_rejected", "output_escape_rejected"}
PUBLIC_DIAGNOSTICS = {
    "wrong_arena": "[BrandMismatch] Arena.get_ref index brand",
    "error_ticket_rejected": "Field 'ticket' not found in enum variant Error",
    "output_escape_rejected": "[TypeMismatch] Return type mismatch",
}
FOLLOW_UPS = {"26.1-GENERAL", "26.1-ABI-EXT", "26.1-LIFECYCLE-EXT",
              "26.1-SQLITE", "26.1-DEPLOY"}
PUBLIC_KEY = "6778b05d2ef8f7af4f553918b2b5658eba1d7919536ab3b64c69e63fd5e0b550"
MANUAL_DIAGNOSTICS = {
    "actual_typed_scoped_call_links_and_runs_with_signed_test_adapter",
    "actual_five_argument_scoped_call_links_and_runs_with_signed_test_adapter",
    "source_produced_scoped_probe_records_owning_rejection",
}


class InvalidEvidence(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise InvalidEvidence(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path):
    return json.loads(path.read_text())


def checked_static_elf(path, expected_digest):
    require(path.is_file() and not path.is_symlink() and digest(path) == expected_digest,
            "native executable bytes disagree")
    with path.open("rb") as stream:
        header = stream.read(20)
    require(header[:6] == b"\x7fELF\x02\x01" and
            int.from_bytes(header[18:20], "little") == 62,
            "native executable is not little-endian ELF64 x86_64")
    headers = subprocess.check_output(["readelf", "-l", path], text=True,
                                     env={"PATH": "/usr/bin:/bin", "LC_ALL": "C"})
    require("INTERP" not in headers and "DYNAMIC" not in headers,
            "native executable acquired a dynamic dependency")


def checked_trust(snapshot, now):
    require(snapshot.get("signer") == "gust-native-release-1" and
            snapshot.get("public_key_hex") == PUBLIC_KEY and
            (snapshot.get("release_epoch"), snapshot.get("minimum_package_epoch"),
             snapshot.get("key_first_epoch"), snapshot.get("key_last_epoch")) == (1, 1, 1, 1),
            "initial production identity or epoch range disagrees")
    issued, expires = snapshot.get("issued_unix_seconds"), snapshot.get("expires_unix_seconds")
    require(type(issued) is int and type(expires) is int and
            snapshot.get("maximum_validity_seconds") == 604800 and
            0 < expires - issued <= 604800 and issued <= now < expires,
            "production snapshot is not currently valid within its maximum interval")


def checked_public_record(record, module_digest):
    require(record.get("status") == "PASS public native interface" and
            record.get("offline_network_namespace_verified") is True and
            record.get("module_sha256") == module_digest,
            "public result is partial, online or from another module")
    rows = record.get("cases", [])
    require(len(rows) == 19 and len({r.get("case") for r in rows}) == 19 and
            {r.get("case") for r in rows} == set(PUBLIC_EXITS) | PUBLIC_REJECTIONS,
            "public case population is incomplete or duplicated")
    for row in rows:
        name = row["case"]
        require(len(row.get("source_sha256", "")) == 64,
                "public case lacks emitted source identity")
        if name in PUBLIC_EXITS:
            require(row.get("exit") == PUBLIC_EXITS[name] and
                    len(row.get("elf_sha256", "")) == 64,
                    "public native exit or executable identity disagrees: " + name)
        else:
            require(row.get("verdict") == "REJECTED (expected assertion)" and
                    0 < row.get("exit", 0) < 128 and "elf_sha256" not in row,
                    "public rejection is accepted, killed or at another boundary: " + name)


def checked_historical_record(run, jobs, head, targets):
    require(run.get("name") == "Cranelift Historical Full" and
            run.get("path") == ".github/workflows/cranelift-historical-full.yml" and
            run.get("head_sha") == head and run.get("head_branch") == "main" and
            run.get("event") in ("workflow_dispatch", "schedule") and
            run.get("status") == "completed" and run.get("conclusion") == "success",
            "Historical Full is not successful on exact final main")
    expected = {"Project declared Phase 14 targets", "Build shared Gust artifact",
                "Level 3 declared-target completion"}
    expected.update("Level 3 history / " + shard for shard in SHARDS)
    expected.update("Phase 14 target / " + target for target in targets)
    require(len(jobs) == len(expected) and len({j.get("id") for j in jobs}) == len(jobs) and
            {j.get("name") for j in jobs} == expected,
            "Historical Full job population is incomplete, duplicated or changed")
    require(all(j.get("head_sha") == head and j.get("run_id") == run["id"] and
                j.get("status") == "completed" and j.get("conclusion") == "success"
                for j in jobs), "Historical Full contains another head, skipped or failed job")


def checked_reviews(record, head, tree):
    require(record.get("reviewed_head") == head and record.get("reviewed_tree") == tree,
            "independent reviews belong to another qualified source")
    rows = record.get("reviews", [])
    require(len(rows) == 2 and {row.get("axis") for row in rows} == {"Standards", "Spec"} and
            len({row.get("reviewer") for row in rows}) == 2 and
            all(row.get("status") == "PASS" and row.get("findings") == [] and
                row.get("reviewer") for row in rows),
            "independent Standards/Spec reviews are absent or have unresolved findings")


def checked_qualification_artifact(artifact, run, archive_digest, candidate, final_main):
    require(artifact.get("name") == "phase26-first-release-qualification" and
            artifact.get("expired") is False and
            artifact.get("digest") == "sha256:" + archive_digest and
            artifact.get("workflow_run", {}).get("id") == run.get("id") and
            artifact["workflow_run"].get("head_sha") == run.get("head_sha") and
            artifact["workflow_run"].get("repository_id") == 1263612197 and
            artifact["workflow_run"].get("head_repository_id") == 1263612197,
            "qualification archive is not the exact owning GitHub artifact")
    require(run.get("name") == "Cranelift Phase26 First Release" and
            run.get("path") == ".github/workflows/phase26-release-closure.yml" and
            run.get("status") == "completed" and run.get("conclusion") == "success" and
            ((run.get("head_sha") == candidate and run.get("event") == "pull_request") or
             (run.get("head_sha") == final_main and run.get("head_branch") == "main" and
              run.get("event") in ("push", "workflow_dispatch"))),
            "qualification artifact belongs to another head, workflow or failed owning run")



def checked_fixed_point_bindings(record):
    objects, bound = record.get("emitted_objects"), record.get("bound_artifacts", {})
    require(isinstance(objects, dict) and objects and
            all(isinstance(name, str) and Path(name).name == name and name.endswith(".o") and
                isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value)
                for name, value in objects.items()),
            "qualification has no exact emitted-object inventory")
    for stage in (1, 2):
        prefix = f"build/native-fp/stage{stage}/"
        actual = {name.removeprefix(prefix): value for name, value in bound.items()
                  if name.startswith(prefix) and name.endswith(".o")}
        require(actual == objects, "qualification emitted-object population or bytes differ")
    first, second = (bound.get("build/native-stage" + str(stage)) for stage in (1, 2))
    require(isinstance(first, str) and re.fullmatch(r"[0-9a-f]{64}", first) and first == second,
            "qualification linked fixed-point stages are absent or different")


def validate_sources():
    authority = load(AUTHORITY)
    require(authority.get("version") == 1 and
            authority.get("scope") == "Phase26.1 first-release zlib only" and
            authority.get("target") == "x86_64-unknown-linux-gnu",
            "release scope or profile disagrees")
    require(authority.get("follow_ups") == {name: "OPEN" for name in FOLLOW_UPS} and
            authority.get("od23") == "OPEN; resource admission deferred; transfer zeroing retained",
            "general-model or resource deferral was silently closed")
    pins = authority.get("source_pins", {})
    required = {"src/stdlib/native_bytes.gst", "scripts/stdlib_s26_1_native_bytes.py",
                ".github/workflows/stdlib-s26-native-bytes.yml",
                "compiler/experiments/cranelift/src/scoped_byte_copy.rs",
                "compiler/experiments/cranelift/src/collection_provenance.rs",
                "compiler/experiments/cranelift/src/ticket_result.rs",
                "src/runtime-rs/src/ffi_call_region.rs",
                ".github/workflows/cranelift-historical-full.yml"}
    require(required <= set(pins), "release is missing required source bindings")
    require(not ({"GUST_LANE_STATE.md", "TASK_STDLIB.md", "TASK.md"} & set(pins)),
            "release re-admitted an operational/living-roadmap byte pin")
    for path, expected in pins.items():
        require((ROOT / path).is_file() and digest(ROOT / path) == expected,
                "release source changed; audit and requalification required: " + path)
    require(authority.get("snapshot") == load(PROFILE / "snapshot.json"),
            "release trust snapshot differs from enrolled worker profile")
    checked_trust(authority["snapshot"], int(time.time()))
    for name in ("manifest.txt", "manifest.sig", "public-identity.json"):
        require(authority.get("production_files", {}).get(name) == digest(PROFILE / name),
                "release public package identity changed: " + name)
    gates = authority.get("merged_prerequisites", {})
    require(set(gates) == {"R1", "R2", "R3", "R4-wrapper"},
            "merged release prerequisite set is incomplete")
    for gate, commit in gates.items():
        require(isinstance(commit, str) and len(commit) == 40 and
                subprocess.run(["git", "merge-base", "--is-ancestor", commit, "HEAD"],
                               cwd=ROOT, capture_output=True).returncode == 0,
                "release prerequisite is not merged into this source: " + gate)
    audit = load(ROOT / authority["reachable_audit"])
    require(audit.get("general_model") == "OPEN; not the 63-cell completion map" and
            audit.get("source_pins") == pins,
            "targeted audit is absent or bound to different source")
    routes = audit.get("paths", [])
    require(len(routes) >= 12 and len({r.get("id") for r in routes}) == len(routes),
            "targeted reachable-path inventory is incomplete or duplicated")
    require({r.get("stage") for r in routes} >= {
        "input", "copy-in", "call", "count-validation", "copy-out", "cleanup",
        "error", "publication", "return", "alias", "invalidation", "unsupported"},
        "targeted audit omits a reachable release stage")
    for row in routes:
        require(all(row.get(k) for k in ("origin", "route", "authority", "positive",
                                        "negative", "rejecting_stage", "disposition")),
                "reachable path lacks authority or owning evidence: " + str(row.get("id")))
    for row in routes:
        bindings = row.get("test_bindings", [])
        require({binding.get("role") for binding in bindings} >= {"positive", "negative"},
                "reachable path lacks both owning test bindings: " + row["id"])
        for binding in bindings:
            path, anchor = binding.get("path"), binding.get("anchor")
            require(path in pins and isinstance(anchor, str) and anchor and
                    anchor in (ROOT / path).read_text(),
                    "reachable test binding is absent or not source-pinned: " + row["id"])
    ignored = set()
    for path in (ROOT / "compiler/experiments/cranelift/src").rglob("*.rs"):
        ignored.update(re.findall(r'(?m)^\s*#\[ignore[^\n]*\]\s*\n\s*fn\s+([A-Za-z_0-9]+)',
                                  path.read_text()))
    dispositions = authority.get("ignored_unit_dispositions", [])
    require(len(dispositions) == 15 and
            {row["test"].rsplit("::", 1)[-1] for row in dispositions} == ignored,
            "ignored-unit census differs from the unchanged explicit dispositions")
    levels = load(ROOT / "scripts/cranelift_test_levels.json")["guards"]
    for row in dispositions:
        name = row["test"].rsplit("::", 1)[-1]
        if name in MANUAL_DIAGNOSTICS:
            require(row.get("owner") is None and row.get("disposition") ==
                    "existing manual diagnostic; not release runtime evidence",
                    "manual diagnostic was promoted to runtime evidence")
        else:
            require(levels.get(row.get("owner")) == 2 and row.get("disposition") ==
                    "separate unchanged owning native guard",
                    "ignored integration test lost its actual owning native guard")
    return authority


def public_evidence(directory, authority):
    record = load(directory / "result.json")
    checked_public_record(record, authority["source_pins"]["src/stdlib/native_bytes.gst"])
    # Bind the report to the actual staged import sources and executables.
    import stdlib_s26_1_native_bytes as public
    sources = {name: source for name, source, _ in public.native_cases()}
    sources.update({name: (ROOT / f"tests/stdlib_s26_1_{name}.gst").read_text()
                    for name in PUBLIC_REJECTIONS})
    for row in record["cases"]:
        case_dir = directory / row["case"]
        source = case_dir / "case.gst"
        # The maintained guard stages at this fixed repository-relative path.
        # Artifact downloads may live elsewhere; that must not change what the
        # compiler actually saw on the runner.
        staged_dir = ROOT / "build/guards/stdlib_s26_1_public_qualification" / row["case"]
        expected = sources[row["case"]].replace('"../src/stdlib/native_bytes.gst"',
            json.dumps(os.path.relpath(ROOT / "src/stdlib/native_bytes.gst", staged_dir)))
        require(source.read_text() == expected and digest(source) == row["source_sha256"],
                "public emitted source does not match maintained generator")
        output = case_dir / "program"
        if row["case"] in PUBLIC_EXITS:
            checked_static_elf(output, row["elf_sha256"])
        else:
            require(not output.exists() and not output.is_symlink(),
                    "public source rejection left an executable")
            diagnostic = (case_dir / "stdout").read_text() + (case_dir / "stderr").read_text()
            require(PUBLIC_DIAGNOSTICS[row["case"]] in diagnostic,
                    "public rejection artifact has another actual diagnostic")
    return record


def qualification(public_dir, production_dir, regression_dir, output):
    public_dir, production_dir, regression_dir = (
        path.resolve() for path in (public_dir, production_dir, regression_dir))
    require(not subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True),
            "release qualification requires a committed clean candidate")
    authority = validate_sources()
    public_evidence(public_dir, authority)
    production = load(production_dir / "result.json")
    require(production.get("status") == "PASS production profile only; Phase26.1 OPEN" and
            production.get("snapshot") == authority["snapshot"] and
            production.get("offline_network_namespace_verified") is True,
            "production qualification is absent, stale or online")
    expected = {"compress": 10, "decompress": 2, "empty_decompress": 0}
    rows = production.get("cases", [])
    require(len(rows) == 3 and {r.get("case") for r in rows} == set(expected),
            "production native case population disagrees")
    for row in rows:
        executable = production_dir / ("offline-" + row["case"])
        require(row.get("exit") == expected[row["case"]] and
                executable.is_file() and digest(executable) == row.get("sha256"),
                "production executable or native exit differs")
        checked_static_elf(executable, row["sha256"])
    from phase26_ticket_publication_guard import checked_package
    checked_package(production_dir / "candidate/package")
    checked_package(public_dir / "tools/approved-packages/gust_zlib_1_3_2_production")
    for name, source in (("gust", ROOT / "gust"),
                         ("gust-native-backend", ROOT / "build/gust-native-backend"),
                         ("gust-runtime-package.a", ROOT / "build/gust-runtime-package.a")):
        require(digest(public_dir / "tools" / name) == digest(source),
                "staged public tool differs from this runner's actual build: " + name)
    from phase26_release_regression import COMMANDS, source_manifest
    regression = load(regression_dir / "result.json")
    require(regression.get("status") == "PASS compiler runtime and emitted-object fixed point" and
            regression.get("source_before") == regression.get("source_after") == source_manifest(),
            "compiler/runtime regression source binding differs")
    commands = regression.get("commands", [])
    require([row.get("command") for row in commands] == COMMANDS and
            all(row.get("exit") == 0 and (ROOT / row["log"]).is_file() and
                digest(ROOT / row["log"]) == row.get("log_sha256") for row in commands),
            "full compiler/runtime/fixed-point command or log evidence differs")
    population = authority["compiler_unit_test_population"]
    summary = ("test result: ok. " + str(population["passed"]) + " passed; 0 failed; " +
               str(population["ignored"]) + " ignored; 0 measured; 0 filtered out;")
    require(population == {"passed": 78, "ignored": 15} and
            summary in (ROOT / commands[0]["log"]).read_text(),
            "full compiler unit-test population did not execute")
    compiler_log = (ROOT / commands[0]["log"]).read_text()
    require(all(("test " + row["test"] + " ... ignored") in compiler_log
                for row in authority["ignored_unit_dispositions"]),
            "full compiler log differs from the declared ignored-test population")
    for name in ("zero_sizes_have_distinct_storage_and_no_readable_byte",
                 "allocation_failures_publish_no_owner", "output_requires_acceptance_and_validated_count"):
        require(("test ffi_call_region::tests::" + name + " ... ok") in
                (ROOT / commands[1]["log"]).read_text(),
                "required call-region runtime test did not execute: " + name)
    stages = []
    for number in (1, 2):
        directory = ROOT / f"build/native-fp/stage{number}"
        objects = {p.name: digest(p) for p in directory.glob("*.o")}
        require(objects, "native fixed point contains no emitted objects")
        stages.append(objects)
    require(stages[0] == stages[1], "native fixed-point emitted objects differ")
    require(digest(ROOT / "build/native-stage1") == digest(ROOT / "build/native-stage2"),
            "native fixed-point linked D4 observations differ")
    evidence = [public_dir / "result.json", production_dir / "result.json",
                regression_dir / "result.json"]
    bound = {}
    for directory in (public_dir, production_dir, regression_dir, ROOT / "build/native-fp"):
        for path in directory.rglob("*"):
            if path.is_file():
                require(not path.is_symlink(), "release evidence contains a symlink")
                bound[path.relative_to(ROOT).as_posix()] = digest(path)
    for name in ("native-stage1", "native-stage2"):
        path = ROOT / "build" / name
        require(not path.is_symlink(), "native fixed-point linked stage is a symlink")
        bound[path.relative_to(ROOT).as_posix()] = digest(path)
    require(bound, "release artifact binding is empty")
    require(validate_sources() == authority, "release source authority changed during qualification")
    record = dict(status="PASS exact-source first-release qualification",
                  qualified_head=subprocess.check_output(
                      ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                  qualified_tree=subprocess.check_output(
                      ["git", "rev-parse", "HEAD^{tree}"], cwd=ROOT, text=True).strip(),
                  source_pins=authority["source_pins"], emitted_objects=stages[0],
                  tool_hashes={name: digest(public_dir / "tools" / name)
                               for name in ("gust", "gust-native-backend", "gust-runtime-package.a")},
                  bound_artifacts=bound,
                  evidence=[dict(path=p.resolve().relative_to(ROOT).as_posix(), sha256=digest(p))
                            for p in evidence],
                  next_gate="all eligible exact-head PR CI/reviews/merge then final-main Historical Full",
                  phase26_1="OPEN")
    checked_fixed_point_bindings(record)
    require(not output.exists(), "qualification output already exists; preserve prior evidence")
    output.write_text(json.dumps(record, indent=2) + "\n")


def historical(run_id, artifact_id, archive, closure_pr, reviews_path, output):
    authority = validate_sources()
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    require(not subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True),
            "final-main closure requires a clean tracked source tree")
    from phase26_release_ci import api, qualify_pull_request
    require(api("commits/main")["sha"] == head, "checkout is not current final main")
    artifact = api(f"actions/artifacts/{artifact_id}")
    owning_run = api("actions/runs/" + str(artifact["workflow_run"]["id"]))
    require(artifact.get("digest") == "sha256:" + digest(archive),
            "qualification archive digest differs from GitHub")
    with zipfile.ZipFile(archive) as contents:
        names = contents.namelist()
        require(len(names) == len(set(names)), "qualification archive contains duplicate entries")
        qualified_bytes = contents.read("guards/phase26_release_qualification.json")
        qualified = json.loads(qualified_bytes)
        bound = qualified.get("bound_artifacts", {})
        require(bound, "qualification archive has no bound artifacts")
        checked_fixed_point_bindings(qualified)
        for path, expected in bound.items():
            require(path.startswith("build/") and ".." not in Path(path).parts and
                    not Path(path).is_absolute() and
                    hashlib.sha256(contents.read(path.removeprefix("build/"))).hexdigest() == expected,
                    "qualification executable, canonical, object, package or log bytes changed")
        require(len(qualified.get("evidence", [])) == 3 and
                all(bound.get(row["path"]) == row["sha256"] for row in qualified["evidence"]),
                "qualification input report bindings are incomplete or inconsistent")
    require(qualified.get("status") == "PASS exact-source first-release qualification" and
            qualified.get("source_pins") == authority["source_pins"] and
            qualified.get("qualified_tree") == subprocess.check_output(
                ["git", "rev-parse", "HEAD^{tree}"], cwd=ROOT, text=True).strip(),
            "final main differs from the public/compiler/runtime/fixed-point qualified tree")
    pr_evidence = qualify_pull_request(ROOT, closure_pr, qualified["qualified_tree"], head)
    checked_qualification_artifact(artifact, owning_run, digest(archive),
                                   pr_evidence["qualified_head"], head)
    require(api("git/commits/" + owning_run["head_sha"])["tree"]["sha"] == qualified["qualified_tree"],
            "owning qualification run used another source tree")
    reviews = load(reviews_path)
    checked_reviews(reviews, pr_evidence["qualified_head"], qualified["qualified_tree"])
    run = api(f"actions/runs/{run_id}")
    jobs = []
    page = 1
    while True:
        value = api(f"actions/runs/{run_id}/jobs?per_page=100&page={page}")
        require(value["jobs"], "Historical job pagination ended before the complete population")
        jobs.extend(value["jobs"])
        if len(jobs) >= value["total_count"]:
            break
        page += 1
    import phase14_composition
    targets = phase14_composition.declared_targets(load(ROOT / "scripts/cranelift_feature_registry.json"))
    checked_historical_record(run, jobs, head, targets)
    require(api("commits/main")["sha"] == head, "main moved during final closure verification")
    output.mkdir(parents=True, exist_ok=False)
    for name, value in (("run.json", run), ("jobs.json", jobs), ("pr-ci.json", pr_evidence),
                       ("qualification-artifact.json", artifact), ("qualification-run.json", owning_run),
                       ("qualification.json", qualified), ("independent-reviews.json", reviews),
                       ("result.json", {
            "status": "PASS exact-final-main first-release closure", "main": head,
            "run_id": run_id, "jobs": len(jobs), "targets": targets,
            "qualification_sha256": hashlib.sha256(qualified_bytes).hexdigest(),
            "qualification_archive_sha256": digest(archive),
            "owning_qualification_artifact": artifact_id, "owning_qualification_run": owning_run["id"],
            "independent_reviews_sha256": digest(reviews_path),
            "eligible_pr_workflows": len(pr_evidence["eligible_workflows"]),
            "closure_pr": closure_pr,
            "release_authority_sha256": digest(AUTHORITY),
            "production_snapshot": authority["snapshot"], "production_files": authority["production_files"],
            "scope": authority["scope"], "phase26_1_first_release": "DONE",
            "phase26_general_model": "OPEN"})):
        (output / name).write_text(json.dumps(value, indent=2) + "\n")


def inversions():
    """Exercise refusal boundaries without rewriting the source checkout."""
    head = "1" * 40
    public = dict(status="PASS public native interface", module_sha256="a" * 64,
                  offline_network_namespace_verified=True, cases=[
        dict(case=name, source_sha256="b" * 64, elf_sha256="c" * 64, exit=value)
        for name, value in PUBLIC_EXITS.items()] + [
        dict(case=name, source_sha256="b" * 64, exit=1,
             verdict="REJECTED (expected assertion)") for name in sorted(PUBLIC_REJECTIONS)])
    run = dict(id=42, name="Cranelift Historical Full", head_sha=head,
               head_branch="main", event="workflow_dispatch", status="completed",
               conclusion="success", path=".github/workflows/cranelift-historical-full.yml")
    targets = ["x86_64-unknown-linux-gnu", "aarch64-unknown-linux-gnu"]
    names = ["Project declared Phase 14 targets", "Build shared Gust artifact",
             "Level 3 declared-target completion"]
    names += ["Level 3 history / " + shard for shard in SHARDS]
    names += ["Phase 14 target / " + target for target in targets]
    jobs = [dict(id=i, run_id=42, name=name, head_sha=head, status="completed",
                 conclusion="success") for i, name in enumerate(names)]
    checked_public_record(public, "a" * 64)
    checked_historical_record(run, jobs, head, targets)
    reviews = dict(reviewed_head=head, reviewed_tree="b" * 40, reviews=[
        dict(axis=axis, status="PASS", findings=[], reviewer="synthetic-" + axis)
        for axis in ("Standards", "Spec")])
    checked_reviews(reviews, head, "b" * 40)
    qualification_run = dict(id=43, head_sha=head, head_branch="codex/phase26-example",
        name="Cranelift Phase26 First Release", path=".github/workflows/phase26-release-closure.yml",
        event="pull_request", status="completed", conclusion="success")
    artifact = dict(name="phase26-first-release-qualification", expired=False, digest="sha256:" + "a" * 64,
                    workflow_run=dict(id=43, head_sha=head, repository_id=1263612197,
                                      head_repository_id=1263612197))
    checked_qualification_artifact(artifact, qualification_run, "a" * 64, head, "f" * 40)

    def rejected(label, action, assertion):
        try:
            action()
        except InvalidEvidence as error:
            verdict = ("REJECTED (expected assertion)" if assertion in str(error)
                       else "REJECTED (different assertion)")
            print(label + ": " + verdict)
            require(verdict == "REJECTED (expected assertion)", label + ": " + str(error))
        else:
            raise InvalidEvidence(label + ": ACCEPTED")

    fixed_point = dict(emitted_objects={"module-0.o": "a" * 64}, bound_artifacts={
        "build/native-fp/stage1/module-0.o": "a" * 64,
        "build/native-fp/stage2/module-0.o": "a" * 64,
        "build/native-stage1": "b" * 64, "build/native-stage2": "b" * 64})
    checked_fixed_point_bindings(fixed_point)
    for key in tuple(fixed_point["bound_artifacts"]):
        for mutation in ("omit", "substitute"):
            changed = copy.deepcopy(fixed_point)
            if mutation == "omit":
                del changed["bound_artifacts"][key]
            else:
                changed["bound_artifacts"][key] = "c" * 64
            rejected("fixed-point-" + mutation + "-" + key,
                     lambda changed=changed: checked_fixed_point_bindings(changed),
                     "emitted-object" if key.endswith(".o") else "linked fixed-point")
    changed = copy.deepcopy(fixed_point)
    changed["bound_artifacts"]["build/native-fp/stage2/extra.o"] = "a" * 64
    rejected("fixed-point-extra-object", lambda: checked_fixed_point_bindings(changed),
             "emitted-object")
    changed = copy.deepcopy(fixed_point)
    changed["emitted_objects"] = {}
    rejected("fixed-point-empty-inventory", lambda: checked_fixed_point_bindings(changed),
             "emitted-object inventory")

    def bad_public(label, mutate, assertion):
        value = copy.deepcopy(public)
        mutate(value)
        require(value != public, "public inversion did not move its mechanism")
        rejected(label, lambda: checked_public_record(value, "a" * 64), assertion)

    for field, value in (("digest", "sha256:" + "d" * 64), ("expired", True),
                         ("name", "another-artifact")):
        changed = dict(artifact, **{field: value})
        rejected("artifact-" + field, lambda changed=changed:
                 checked_qualification_artifact(changed, qualification_run, "a" * 64, head, "f" * 40),
                 "exact owning GitHub artifact")
    for field, value in (("id", 44), ("repository_id", 1), ("head_repository_id", 1)):
        changed = copy.deepcopy(artifact)
        changed["workflow_run"][field] = value
        rejected("artifact-run-" + field, lambda changed=changed:
                 checked_qualification_artifact(changed, qualification_run, "a" * 64, head, "f" * 40),
                 "exact owning GitHub artifact")
    for field, value in (("conclusion", "failure"), ("status", "in_progress"),
                         ("path", "another-workflow.yml"), ("event", "workflow_dispatch")):
        changed = dict(qualification_run, **{field: value})
        rejected("artifact-workflow-" + field, lambda changed=changed:
                 checked_qualification_artifact(artifact, changed, "a" * 64, head, "f" * 40),
                 "failed owning run")

    for field, value in (("reviewed_head", "2" * 40), ("reviewed_tree", "c" * 40)):
        changed = dict(reviews, **{field: value})
        rejected("review-" + field, lambda changed=changed: checked_reviews(changed, head, "b" * 40),
                 "another qualified source")
    changed = copy.deepcopy(reviews)
    changed["reviews"].pop()
    rejected("review-missing-axis", lambda: checked_reviews(changed, head, "b" * 40), "absent")
    changed = copy.deepcopy(reviews)
    changed["reviews"][0]["findings"] = ["unresolved"]
    rejected("review-unresolved-finding", lambda: checked_reviews(changed, head, "b" * 40), "findings")

    snapshot = dict(signer="gust-native-release-1", public_key_hex=PUBLIC_KEY,
                    release_epoch=1, minimum_package_epoch=1, key_first_epoch=1,
                    key_last_epoch=1, issued_unix_seconds=100, expires_unix_seconds=604900,
                    maximum_validity_seconds=604800)
    checked_trust(snapshot, 100)
    checked_trust(snapshot, 604899)
    for now in (99, 604900, 604901):
        rejected("production-time-" + str(now), lambda now=now: checked_trust(snapshot, now),
                 "currently valid")
    for field, value, assertion in (("public_key_hex", "0" * 64, "identity"),
            ("key_last_epoch", 2, "epoch range"),
            ("maximum_validity_seconds", 604801, "maximum interval"),
            ("expires_unix_seconds", 604901, "maximum interval")):
        changed = dict(snapshot, **{field: value})
        rejected("production-" + field,
                 lambda changed=changed: checked_trust(changed, 101), assertion)

    bad_public("source-negatives-only", lambda x: x.update(status="PASS source negatives only"), "partial")
    bad_public("other-module", lambda x: x.update(module_sha256="d" * 64), "another module")
    bad_public("network-isolation-missing", lambda x: x.update(offline_network_namespace_verified=False), "online")
    bad_public("case-omitted", lambda x: x["cases"].pop(), "population")
    bad_public("case-duplicated", lambda x: x["cases"].append(x["cases"][0]), "population")
    bad_public("byte-equality-exit-changed", lambda x: x["cases"][0].update(exit=100), "native exit")
    bad_public("executable-unbound", lambda x: x["cases"][0].pop("elf_sha256"), "executable identity")
    bad_public("other-rejecting-stage", lambda x: x["cases"][-1].update(
        verdict="REJECTED (different assertion)"), "another boundary")
    bad_public("killed-negative", lambda x: x["cases"][-1].update(exit=137), "killed")

    for field, value in (("head_sha", "2" * 40), ("head_branch", "codex/old"),
                         ("event", "pull_request"), ("conclusion", "failure"),
                         ("status", "in_progress"), ("path", "other.yml")):
        changed = dict(run, **{field: value})
        rejected("historical-" + field,
                 lambda changed=changed: checked_historical_record(changed, jobs, head, targets),
                 "exact final main")
    rejected("historical-job-omitted", lambda: checked_historical_record(run, jobs[:-1], head, targets),
             "population")
    duplicate = copy.deepcopy(jobs)
    duplicate[-1] = copy.deepcopy(duplicate[0])
    rejected("historical-job-duplicated", lambda: checked_historical_record(run, duplicate, head, targets),
             "population")
    for field, value in (("head_sha", "2" * 40), ("run_id", 41),
                         ("conclusion", "skipped"), ("status", "in_progress")):
        changed = copy.deepcopy(jobs)
        changed[0][field] = value
        rejected("historical-job-" + field,
                 lambda changed=changed: checked_historical_record(run, changed, head, targets),
                 "skipped or failed job")
    print("CLOSURE_RECORD_INVERSIONS_PASS; synthetic records only, no release claim")
    from phase26_release_ci import inversions as ci_inversions
    ci_inversions()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("validate")
    sub.add_parser("inversions")
    public = sub.add_parser("public-evidence")
    public.add_argument("directory", type=Path)
    qualify = sub.add_parser("qualify")
    qualify.add_argument("public_directory", type=Path)
    qualify.add_argument("production_directory", type=Path)
    qualify.add_argument("regression_directory", type=Path)
    qualify.add_argument("output", type=Path)
    history = sub.add_parser("historical")
    history.add_argument("run_id", type=int)
    history.add_argument("qualification_artifact_id", type=int)
    history.add_argument("qualification_archive", type=Path)
    history.add_argument("closure_pr", type=int)
    history.add_argument("reviews", type=Path)
    history.add_argument("output", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "inversions":
            inversions()
        elif args.command == "historical":
            historical(args.run_id, args.qualification_artifact_id, args.qualification_archive,
                       args.closure_pr, args.reviews, args.output)
        elif args.command == "qualify":
            qualification(args.public_directory, args.production_directory,
                          args.regression_directory, args.output)
        elif args.command == "public-evidence":
            public_evidence(args.directory, validate_sources())
        else:
            validate_sources()
        print("PHASE26_RELEASE_EVIDENCE_PASS " + args.command)
    except (ValueError, OSError, KeyError, zipfile.BadZipFile) as error:
        raise SystemExit("guard-cranelift-phase26-release-closure: " + str(error)) from error


if __name__ == "__main__":
    main()
