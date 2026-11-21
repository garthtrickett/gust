#!/usr/bin/env python3
"""Refusal controls for closed revisions of existing CI dependencies; no install."""
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
from unittest.mock import patch

import phase26_toolchain_compatibility as compatibility
import phase26_production_toolchain as toolchain

ROOT = Path(__file__).resolve().parents[1]


def transfer_controls(build, accepted, rejected):
    payload = b"pinned complete package"
    package = dict(package="fixture", filename="fixture.deb", url="https://example.invalid/pinned",
                   sha256=hashlib.sha256(payload).hexdigest())
    split = 7
    first = (0, 28, "200", "", payload[:split])
    last = len(payload) - 1
    resumed = f"bytes {split}-{last}/{len(payload)}"

    def exercise(label, replies, result, diagnostic=None):
        with tempfile.TemporaryDirectory(prefix="toolchain-transfer-", dir=build) as temporary:
            directory = Path(temporary) / "download"
            output = directory / "fixture.deb"
            partial = output.with_suffix(".deb.partial")
            pending = iter(replies)
            calls = []

            def fake_run(command, **kwargs):
                offset, code, status, content_range, more = next(pending)
                calls.append(command)
                assert not output.exists(), "unverified bytes gained the installation name"
                assert command[-1] == package["url"]
                assert command[command.index("--proto") + 1] == "=https"
                assert command[command.index("--tlsv1.2") + 1] == "--fail"
                assert command[command.index("--max-time") + 1] == "60"
                assert "--retry" not in command and command[command.index("-o") + 1] == str(partial)
                assert ("--continue-at" in command) == bool(offset)
                if offset:
                    assert command[command.index("--continue-at") + 1] == str(offset)
                    assert partial.read_bytes() == payload[:offset]
                if more:
                    with partial.open("ab") as stream:
                        stream.write(more)
                return subprocess.CompletedProcess(command, code, stdout=status + "\t" + content_range + "\n")

            def acquire():
                with patch.object(toolchain.subprocess, "run", side_effect=fake_run), \
                        patch.object(toolchain.time, "sleep") as backoff:
                    try:
                        return toolchain.fetch({"packages": [package]}, directory)
                    finally:
                        assert len(calls) == len(replies)
                        assert [call.args[0] for call in backoff.call_args_list] == [2 ** i for i in range(len(replies) - 1)]

            if result == "pass":
                accepted(label, lambda: require(acquire() == [str(output)]))
                assert output.read_bytes() == payload and not partial.exists()
            elif result == "exhausted":
                def exhausted():
                    try:
                        acquire()
                    except subprocess.CalledProcessError as error:
                        assert error.returncode == 28
                        raise SystemExit("production dependency download exhausted") from error
                rejected(label, exhausted, "production dependency download exhausted")
                assert not output.exists() and partial.is_file()
            else:
                rejected(label, acquire, diagnostic)
                assert not output.exists()

    exercise("complete pinned response", [(0, 0, "200", "", payload)], "pass")
    exercise("same-origin resume after timeout", [first, (split, 0, "206", resumed, payload[split:])], "pass")
    exercise("retryable response without bytes", [(0, 22, "503", "", b""),
             (0, 0, "200", "", payload)], "pass")
    exercise("download timeout stops after three attempts", [first, (split, 28, "000", "", b""),
             (split, 28, "000", "", b"")], "exhausted")
    exercise("server ignored resume range", [first, (split, 33, "200", "", b"")], "reject",
             "resume did not return a byte range")
    exercise("server supplied the wrong offset", [first, (split, 0, "206",
             f"bytes {split + 1}-{last}/{len(payload)}", payload[split:])], "reject",
             "resume returned an inconsistent byte range")
    exercise("server supplied incomplete bytes", [first, (split, 0, "206", resumed, payload[split:-1])], "reject",
             "resume ended with an incomplete byte range")
    exercise("assembled package has the wrong digest", [first, (split, 0, "206", resumed,
             payload[split:-1] + b"X")], "reject", "production dependency digest mismatch")


def main():
    pin_path = ROOT / "compiler/experiments/cranelift/production/build-toolchain.json"
    pins = json.loads(pin_path.read_text())
    digest = hashlib.sha256(pin_path.read_bytes()).hexdigest()
    document = json.loads(compatibility.COMPATIBILITY.read_text())
    before = {row["package"] + ":amd64": row["version"] for row in pins["packages"]}
    outcomes = []

    def accepted(label, action):
        action()
        outcomes.append(dict(label=label, outcome="ACCEPTED"))

    def rejected(label, action, expected):
        try:
            action()
        except SystemExit as error:
            outcome = "REJECTED (expected assertion)" if expected in str(error) else "REJECTED (different assertion)"
            outcomes.append(dict(label=label, outcome=outcome, diagnostic=str(error)))
            assert outcome == "REJECTED (expected assertion)", outcomes[-1]
        else:
            raise AssertionError("unexpected acceptance: " + label)

    def selection(state=before, value=document, canonical=digest):
        return compatibility.select(pins, canonical, value, state)

    accepted("absent compatibility packages stay absent", lambda: require(selection() == []))
    for name in sorted(compatibility.OPTIONAL):
        state = dict(before, **{name + ":amd64": "2.39-0ubuntu8.12"})
        accepted("only present " + name, lambda state=state, name=name:
                 require([row["package"] for row in selection(state)] == [name]))
    state = dict(before, **{name + ":amd64": "2.39-0ubuntu8.12" for name in compatibility.OPTIONAL})
    accepted("both present compatibility revisions", lambda: require(len(selection(state)) == 2))
    rejected("canonical pin binding", lambda: selection(canonical="0" * 64), "canonical pin binding changed")
    rejected("foreign installed architecture", lambda: selection(dict(before, **{"libc6-i386:i386": "1"})),
             "unsupported installed compatibility architecture")
    for label, key, value, diagnostic in (
            ("version", "version", "0", "version or architecture"),
            ("architecture", "architecture", "i386", "version or architecture"),
            ("archive identity", "filename", "../substitute.deb", "archive identity"),
            ("archive URL", "url", "https://example.invalid/substitute", "archive identity"),
            ("libc dependency", "depends", "libc6 (>= 1)", "libc dependency")):
        changed = copy.deepcopy(document)
        changed["packages"][0][key] = value
        rejected("metadata " + label, lambda changed=changed: selection(value=changed), diagnostic)
    changed = copy.deepcopy(document)
    changed["packages"].append(copy.deepcopy(changed["packages"][0]))
    rejected("expanded compatibility family", lambda: selection(value=changed), "allowlist changed")

    build = ROOT / "build/guards"
    build.mkdir(parents=True, exist_ok=True)
    transfer_controls(build, accepted, rejected)
    with tempfile.TemporaryDirectory(prefix="toolchain-control-", dir=build) as temporary:
        temporary = Path(temporary)
        package = temporary / "fixture"
        (package / "DEBIAN").mkdir(parents=True)
        name = "libc6-i386"
        version = next(row["version"] for row in pins["packages"] if row["package"] == "libc6")
        (package / "DEBIAN/control").write_text(
            "Package: " + name + "\nVersion: " + version + "\nArchitecture: amd64\n"
            "Maintainer: Gust test fixture <nobody@example.invalid>\n"
            "Description: Non-installed metadata refusal fixture\nDepends: libc6 (= " + version + ")\n")
        payload_name = "usr/share/gust-toolchain-test/sentinel"
        (package / payload_name).parent.mkdir(parents=True)
        (package / payload_name).write_bytes(b"original payload\n")
        os.link(package / payload_name, package / (payload_name + "-hard"))
        (package / (payload_name + "-link")).symlink_to("sentinel")
        archive = temporary / "fixture.deb"
        subprocess.run(["dpkg-deb", "--build", "--root-owner-group", str(package), str(archive)],
                       check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        row = dict(package=name, version=version, architecture="amd64", depends="libc6 (= " + version + ")",
                   size=archive.stat().st_size, sha256=hashlib.sha256(archive.read_bytes()).hexdigest())
        accepted("actual archive metadata", lambda: compatibility.check_archive(row, archive))
        fixture_pins = {"packages": [dict(package=name, version=version, sha256=row["sha256"])]}
        accepted("canonical archive bytes and metadata", lambda:
                 compatibility.check_canonical_archives(fixture_pins, [str(archive)]))
        changed = copy.deepcopy(fixture_pins)
        changed["packages"][0]["sha256"] = "0" * 64
        rejected("canonical archive substitution", lambda:
                 compatibility.check_canonical_archives(changed, [str(archive)]), "canonical archive bytes changed")
        for key, value in (("sha256", "0" * 64), ("size", 1), ("package", "other"),
                           ("version", "0"), ("architecture", "i386"), ("depends", "libc6 (>= 1)")):
            changed = dict(row, **{key: value})
            diagnostic = "archive bytes changed" if key in ("sha256", "size") else "archive control metadata changed"
            rejected("archive " + key, lambda changed=changed: compatibility.check_archive(changed, archive), diagnostic)
        link = temporary / "archive-link"
        link.symlink_to(archive)
        rejected("linked archive", lambda: compatibility.check_archive(row, link), "not a regular file")
        installed = temporary / "installed"
        payload = installed / payload_name
        payload.parent.mkdir(parents=True)
        payload.write_bytes(b"original payload\n")
        hardlink = installed / (payload_name + "-hard")
        os.link(payload, hardlink)
        (installed / (payload_name + "-link")).symlink_to("sentinel")
        accepted("actual installed payload", lambda: require(
            compatibility.installed_payloads([archive], installed)["payloads"][str(payload)] ==
            hashlib.sha256(b"original payload\n").hexdigest()))
        payload.unlink()
        payload.symlink_to("sentinel-hard")
        rejected("identical-byte regular node symlink substitution", lambda:
                 compatibility.installed_payloads([archive], installed), "installed payload bytes changed")
        payload.unlink()
        os.link(hardlink, payload)
        hardlink.unlink()
        hardlink.symlink_to("sentinel")
        rejected("identical-byte hardlink node symlink substitution", lambda:
                 compatibility.installed_payloads([archive], installed), "installed payload hardlink changed")
        hardlink.unlink()
        os.link(payload, hardlink)
        payload.write_bytes(b"substituted with unchanged package version\n")
        rejected("same-version payload substitution", lambda: compatibility.installed_payloads([archive], installed),
                 "installed payload bytes changed")
        rejected("unapproved active tool path", lambda: compatibility.active_resolution({"payloads": {}}),
                 "active tool/runtime outside approved payload")

    old = {"libc6:amd64": "old", "libc6-i386:amd64": "old", "unrelated:amd64": "7"}
    desired = {"libc6:amd64": version, "libc6-i386:amd64": version}
    plan = "\n".join("Inst " + key.split(":")[0] + " [old] (" + value + " local-deb [amd64])"
                     for key, value in desired.items())
    accepted("closed solver revision plan", lambda: require(compatibility.check_plan(plan, old, desired) == desired))
    for label, addition, diagnostic in (
            ("removal", "Remv unrelated [7]", "solver proposed removal"),
            ("purge", "Purg unrelated [7]", "solver proposed removal"),
            ("new package", "Inst new-package (1 local-deb [amd64])", "solver proposed new package"),
            ("unselected revision", "Inst unrelated [7] (8 local-deb [amd64])", "solver proposed unselected revision"),
            ("wrong version", "Inst libc6 [old] (0 local-deb [amd64])", "solver proposed unselected revision"),
            ("wrong architecture", "Inst libc6 [old] (" + version + " local-deb [i386])", "solver proposed new package"),
            ("duplicate operation", plan.splitlines()[0], "duplicate solver operation"),
            ("unknown operation", "Inst unexpected syntax", "unknown solver operation")):
        rejected("solver " + label, lambda addition=addition: compatibility.check_plan(plan + "\n" + addition, old, desired), diagnostic)
    rejected("solver omitted revision", lambda: compatibility.check_plan(plan.splitlines()[0], old, desired),
             "solver omitted selected revision")
    after = dict(old, **desired)
    accepted("exact installed population", lambda: compatibility.check_after(old, desired, after))
    for label, changed in (("unselected version", dict(after, **{"unrelated:amd64": "8"})),
                           ("new identity", dict(after, **{"new:amd64": "1"})),
                           ("removed identity", {key: value for key, value in after.items() if key != "unrelated:amd64"})):
        rejected("postcheck " + label, lambda changed=changed: compatibility.check_after(old, desired, changed),
                 "installed population or unselected versions changed")
    environment = {key: value for key, value in os.environ.items() if key not in ("GITHUB_ACTIONS", "GITHUB_REPOSITORY")}
    with patch.dict(os.environ, environment, clear=True):
        rejected("installer remains CI confined", lambda: compatibility.install(pins, [], build, None, digest),
                 "installation is confined to owning ephemeral CI")

    # Only process-local fake I/O: exercise the real install orchestration without
    # starting APT, fetching packages or asserting an actual CI environment.
    def orchestration(scenario):
        state = dict(before, **{name + ":amd64": "old" for name in compatibility.OPTIONAL},
                     **{"unrelated:amd64": "7"})
        desired = dict(before, **{name + ":amd64": version for name in compatibility.OPTIONAL})
        final = dict(state, **desired)
        if scenario == "postcheck":
            final["unrelated:amd64"] = "8"
        plan = "\n".join("Inst " + name + " [old] (" + version + " local-deb [amd64])"
                         for name in sorted(compatibility.OPTIONAL))
        if scenario == "solver":
            plan += "\nInst unrelated [7] (8 local-deb [amd64])"
        installed = False
        actual_commands = []
        canonical_paths = ["/fake/" + Path(row["filename"]).name for row in pins["packages"]]
        selected_paths = ["/fake/" + Path(row["filename"]).name for row in document["packages"]]

        def fake_fetch(selected, directory):
            assert selected == {"packages": document["packages"]}
            return selected_paths

        def fake_run(command, **kwargs):
            nonlocal installed
            if "--simulate" in command:
                assert "--no-download" in command and "--no-remove" in command
                return subprocess.CompletedProcess(command, 0, stdout=plan, stderr="")
            expected = ["sudo", "apt-get", "install", "-y", "--allow-downgrades",
                        "--no-install-recommends", "--no-remove", *canonical_paths, *selected_paths]
            assert command == expected and kwargs == {"check": True}, command
            actual_commands.append(command)
            installed = True
            return subprocess.CompletedProcess(command, 0)

        with tempfile.TemporaryDirectory(prefix="toolchain-orchestration-", dir=build) as temporary, \
                patch.dict(os.environ, {"GITHUB_ACTIONS": "true", "GITHUB_REPOSITORY": "garthtrickett/gust"}), \
                patch.object(compatibility, "installed_versions", side_effect=lambda: dict(final if installed else state)), \
                patch.object(compatibility, "check_canonical_archives") as canonical_check, \
                patch.object(compatibility, "check_archive") as archive_check, \
                patch.object(compatibility, "installed_payloads", return_value={"payloads": {}, "links": {}}) as payload_check, \
                patch.object(compatibility, "active_resolution", return_value={}) as resolution_check, \
                patch.object(compatibility.subprocess, "run", side_effect=fake_run):
            try:
                compatibility.install(pins, canonical_paths, Path(temporary), fake_fetch, digest)
            finally:
                if scenario == "solver":
                    assert actual_commands == [], "bad simulation reached installation"
            if scenario == "success":
                assert len(actual_commands) == 1
                canonical_check.assert_called_once_with(pins, canonical_paths)
                assert archive_check.call_count == 2
                payload_check.assert_called_once_with([*canonical_paths, *selected_paths])
                resolution_check.assert_called_once()
                assert json.loads((Path(temporary) / "installed-after.json").read_text()) == final

    accepted("actual installer closed orchestration and command", lambda: orchestration("success"))
    rejected("actual installer rejects bad solver before install", lambda: orchestration("solver"),
             "solver proposed unselected revision")
    rejected("actual installer rejects post-install drift", lambda: orchestration("postcheck"),
             "installed population or unselected versions changed")
    assert len({row["label"] for row in outcomes}) == len(outcomes)
    report = dict(status="PASS actual archive and closed-transaction controls; no package installation",
                  controls=outcomes)
    (build / "phase26_toolchain_controls.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report), flush=True)


def require(condition):
    assert condition


if __name__ == "__main__":
    main()
