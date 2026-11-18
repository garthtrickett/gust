#!/usr/bin/env python3
"""Closed revisions of existing runner packages coupled to pinned libc."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[1]
COMPATIBILITY = ROOT / "compiler/experiments/cranelift/production/ci-toolchain-compatibility.json"
OPTIONAL = {"libc6-dbg", "libc6-i386"}


def require(condition, message):
    if not condition:
        raise SystemExit("production compatibility: " + message)


def installed_versions():
    raw = subprocess.check_output([
        "dpkg-query", "-W", "-f=${Package}\t${Architecture}\t${Version}\t${db:Status-Status}\n"
    ], text=True)
    result = {}
    for line in raw.splitlines():
        name, architecture, version, status = line.split("\t")
        if status != "installed":
            continue
        key = name + ":" + architecture
        require(key not in result, "duplicate installed package identity")
        result[key] = version
    return result


def select(pins, canonical_sha256, document, before):
    require(document["schema"] == "gust.production.ci_compatibility.v1", "unknown metadata schema")
    require(document["canonical_toolchain_sha256"] == canonical_sha256, "canonical pin binding changed")
    libc = next(row for row in pins["packages"] if row["package"] == "libc6")
    origin = libc["url"].removesuffix(libc["filename"])
    rows = document["packages"]
    require(len(rows) == 2 and {row["package"] for row in rows} == OPTIONAL,
            "compatibility allowlist changed")
    selected = []
    for row in rows:
        name = row["package"]
        require(row["architecture"] == "amd64" and row["version"] == libc["version"],
                "compatibility version or architecture changed")
        filename = "pool/main/g/glibc/" + name + "_" + libc["version"] + "_amd64.deb"
        require(row["filename"] == filename and row["url"] == origin + filename,
                "compatibility archive identity changed")
        require(re.fullmatch(r"[0-9a-f]{64}", row["sha256"]) and row["size"] > 0,
                "invalid archive digest or size")
        require(row["depends"] == "libc6 (= " + libc["version"] + ")",
                "compatibility libc dependency changed")
        identities = [key for key in before if key.split(":")[0] == name]
        require(not identities or identities == [name + ":amd64"],
                "unsupported installed compatibility architecture")
        if identities:
            selected.append(row)
    return selected


def check_archive(row, path):
    require(path.is_file() and not path.is_symlink(), "archive is not a regular file")
    require(path.stat().st_size == row["size"] and
            hashlib.sha256(path.read_bytes()).hexdigest() == row["sha256"],
            "archive bytes changed")
    for field, expected in (("Package", row["package"]), ("Architecture", row["architecture"]),
                            ("Version", row["version"]), ("Depends", row["depends"])):
        actual = subprocess.check_output(["dpkg-deb", "-f", str(path), field], text=True).strip()
        require(actual == expected, "archive control metadata changed: " + field)


def check_plan(text, before, desired):
    operations = {}
    for line in text.splitlines():
        require(not line.startswith(("Remv ", "Purg ")), "solver proposed removal")
        if not line.startswith("Inst "):
            continue
        match = re.fullmatch(r"Inst (\S+)(?: \[[^]]+\])? \(([^ ]+) .*\[([^]]+)\]\)(?: \[.*\])?", line)
        require(match is not None, "unknown solver operation")
        package, version, architecture = match.groups()
        name, separator, suffix = package.partition(":")
        require(not separator or suffix == architecture, "solver architecture disagrees")
        key = name + ":" + architecture
        require(key in before, "solver proposed new package")
        require(key in desired and desired[key] == version, "solver proposed unselected revision")
        require(key not in operations, "duplicate solver operation")
        operations[key] = version
    changed = {key: version for key, version in desired.items() if before[key] != version}
    require(all(operations.get(key) == version for key, version in changed.items()),
            "solver omitted selected revision")
    return operations


def check_after(before, desired, after):
    expected = dict(before)
    expected.update(desired)
    require(after == expected, "installed population or unselected versions changed")


def check_canonical_archives(pins, packages):
    require(len(packages) == len(pins["packages"]), "canonical archive population changed")
    for row, filename in zip(pins["packages"], packages, strict=True):
        path = Path(filename)
        require(path.is_file() and not path.is_symlink() and
                hashlib.sha256(path.read_bytes()).hexdigest() == row["sha256"],
                "canonical archive bytes changed")
        for field, expected in (("Package", row["package"]), ("Version", row["version"]),
                                ("Architecture", "amd64")):
            actual = subprocess.check_output(["dpkg-deb", "-f", str(path), field], text=True).strip()
            require(actual == expected, "canonical archive metadata changed")


def file_digest(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def installed_payloads(archives, root=Path("/")):
    """Read actual installed bytes against every supplied, approved Debian payload."""
    payloads, links = {}, {}
    for filename in archives:
        process = subprocess.Popen(["dpkg-deb", "--fsys-tarfile", str(filename)], stdout=subprocess.PIPE)
        complete = False
        try:
            with tarfile.open(fileobj=process.stdout, mode="r|") as archive:
                for entry in archive:
                    name = entry.name.removeprefix("./")
                    require(not Path(name).is_absolute() and ".." not in Path(name).parts,
                            "unsafe archive payload path")
                    path = root / name
                    if entry.isdir():
                        continue
                    if entry.issym():
                        require(path.is_symlink() and os.readlink(path) == entry.linkname,
                                "installed payload link changed: " + name)
                        links[name] = dict(kind="symlink", target=entry.linkname)
                    elif entry.islnk():
                        target = entry.linkname.removeprefix("./")
                        require(not Path(target).is_absolute() and ".." not in Path(target).parts,
                                "unsafe archive hardlink path")
                        require(path.is_file() and not path.is_symlink() and
                                not (root / target).is_symlink() and path.samefile(root / target),
                                "installed payload hardlink changed: " + name)
                        links[name] = dict(kind="hardlink", target=target, sha256=file_digest(path))
                    else:
                        require(entry.isfile(), "unsupported archive payload kind")
                        stream = archive.extractfile(entry)
                        expected = hashlib.sha256()
                        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                            expected.update(chunk)
                        require(path.is_file() and not path.is_symlink() and
                                file_digest(path) == expected.hexdigest(),
                                "installed payload bytes changed: " + name)
                        payloads[str(path.resolve())] = expected.hexdigest()
            for _ in iter(lambda: process.stdout.read(1024 * 1024), b""):
                pass
            complete = True
        finally:
            process.stdout.close()
            if not complete and process.poll() is None:
                process.terminate()
            result = process.wait(timeout=10)
        require(result == 0, "package payload reader failed")
    return dict(payloads=payloads, links=links)


def active_resolution(provenance):
    approved = provenance["payloads"]

    def checked(path):
        require(path is not None, "active tool/runtime missing")
        path = Path(path).resolve()
        require(str(path) in approved and file_digest(path) == approved[str(path)],
                "active tool/runtime outside approved payload: " + str(path))
        return dict(path=str(path), sha256=approved[str(path)])

    active = {name: checked(path) for name, path in (
        ("cc", "/usr/bin/cc"), ("ld", "/usr/bin/ld"), ("ar", "/usr/bin/ar"),
        ("ranlib", "/usr/bin/ranlib"), ("libc", "/usr/lib/x86_64-linux-gnu/libc.so.6"),
        ("loader", "/usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2"))}
    for name in ("cc1", "collect2", "as", "ld"):
        selected = subprocess.check_output(["/usr/bin/cc", "-print-prog-name=" + name], text=True).strip()
        active["gcc_" + name] = checked(selected if "/" in selected else shutil.which(selected))
    for name in ("crt1.o", "crti.o", "crtn.o", "Scrt1.o", "libc.a", "libc_nonshared.a", "libgcc.a"):
        active[name] = checked(subprocess.check_output(["/usr/bin/cc", "-print-file-name=" + name], text=True).strip())
    return active


def install(pins, packages, directory, fetch, canonical_sha256):
    require(os.environ.get("GITHUB_ACTIONS") == "true" and
            os.environ.get("GITHUB_REPOSITORY") == "garthtrickett/gust",
            "installation is confined to owning ephemeral CI")
    before = installed_versions()
    check_canonical_archives(pins, packages)
    desired = {row["package"] + ":amd64": row["version"] for row in pins["packages"]}
    require(all(key in before for key in desired), "canonical existing package absent")
    document = json.loads(COMPATIBILITY.read_text())
    selected = select(pins, canonical_sha256, document, before)
    compatibility_paths = fetch({"packages": selected}, directory / "compatibility") if selected else []
    for row, path in zip(selected, compatibility_paths, strict=True):
        check_archive(row, Path(path))
        desired[row["package"] + ":amd64"] = row["version"]
    archives = [*packages, *compatibility_paths]
    command = ["sudo", "apt-get", "install", "-y", "--allow-downgrades",
               "--no-install-recommends", "--no-remove", *archives]
    (directory / "installed-before.json").write_text(json.dumps(before, indent=2) + "\n")
    require(installed_versions() == before, "package population changed during preparation")
    simulated = subprocess.run([*command[:2], "--simulate", "--no-download", *command[2:]],
                               text=True, capture_output=True)
    (directory / "apt-simulation.stdout").write_text(simulated.stdout)
    (directory / "apt-simulation.stderr").write_text(simulated.stderr)
    require(simulated.returncode == 0, "closed solver transaction refused")
    operations = check_plan(simulated.stdout, before, desired)
    (directory / "selected-transaction.json").write_text(json.dumps({
        "selected_compatibility": selected, "desired": desired, "operations": operations,
        "command": command,
    }, indent=2) + "\n")
    require(installed_versions() == before, "package population changed before installation")
    subprocess.run(command, check=True)
    after = installed_versions()
    (directory / "installed-after.json").write_text(json.dumps(after, indent=2) + "\n")
    check_after(before, desired, after)
    provenance = installed_payloads(archives)
    provenance["active"] = active_resolution(provenance)
    (directory / "installed-payload-provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
