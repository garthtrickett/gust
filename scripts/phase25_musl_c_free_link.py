#!/usr/bin/env python3
"""Patch 25.12b: prove the C-free link, with the Gust runtime archive in it.

Patch 25.11 measured that there is no stock C-free link on gnu, and that the
one that works is `musl + rust-lld + ld.lld flavor`, static-pie, exit 7. It
could not finish the argument, because Patch 25.0 had found the harder half:
`build/gust-runtime-package.a` was glibc-bound -- __printf_chk, __fprintf_chk,
__memcpy_chk, __isoc23_strtol, __stack_chk -- so it could not link against
musl AT ALL, and the expected-failure entry `runtime-archive-is-glibc-bound`
recorded exactly that. 25.11's own note says it: THE GATE IS NOT PROVABLE
UNTIL THE RUNTIME STOPS BEING C.

The runtime has stopped being C. 25.5, 25.6 and 25.10a moved every file into
src/runtime-rs, PHASE21_RUNTIME_OBJECTS is empty, and the archive is `ar rcs`
over one Rust object. So the missing half can now be measured, and this guard
measures it rather than arguing it.

WHAT IT PROVES, end to end, with every C driver poisoned to exit 99:

  * the runtime crate BUILDS for x86_64-unknown-linux-musl;
  * a program that CALLS one of its exports LINKS, via rust-lld, with
    self-contained crt objects and no C driver on the link line;
  * that program RUNS and exits with the sentinel;
  * the result is static-pie -- no INTERP segment, so no dynamic loader.

WHY IT CALLS A SYMBOL RATHER THAN JUST DECLARING ONE. Two different things,
and the first draft of this comment ran them together.

The CALL is what makes the link line have to resolve the archive: an `extern`
block nobody calls leaves no undefined reference, `--gc-sections` drops it,
and the probe would link identically with no archive present at all. Verified
by mutation -- removing `-L native=<archive>` fails with "unable to find
library", and an earlier draft that named a symbol the archive does not
export failed with "undefined symbol", which is the same check firing.

The EXIT CODE is a separate claim: that `gust_tick` actually ran in the
linked binary rather than merely resolving at link time. Both are asserted
because neither implies the other.

WHY THE POISON IS CHECKED FIRST. An instrument that cannot tell "no C
compiler was needed" from "the shim was never on PATH" reports the same
success either way. The first thing this does is run `cc` and REQUIRE exit
99. A first draft of this probe linked /usr/bin/true over `cargo` while
building the poison directory, and cargo then "succeeded" in 0.0s, printed
nothing, and produced no binary -- an exit-0 that meant nothing had run.

WHAT IT DOES NOT PROVE. Not that `make gust` is C-free on gnu: 25.11 decided
the user default stays the host target (O6), and that a gnu host with no C
compiler ERRORS naming musl rather than silently switching (P10). This is the
musl proof the phase always said it would be, and nothing here changes the
gnu default.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = "x86_64-unknown-linux-musl"
RUNTIME_MANIFEST = ROOT / "src" / "runtime-rs" / "Cargo.toml"
# Poisoned so the link cannot quietly use one. `ld` and its flavours are here
# because rust-lld is invoked by name; if a C driver crept back onto the line
# it would reach for these.
POISONED = ("cc", "gcc", "clang", "c++", "g++", "cc1", "ld", "ld.gold", "ld.bfd")
PROBE_SYMBOL = "gust_tick"
SENTINEL = 7
BUILD = ROOT / "build" / "phase25-musl-c-free-link"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"guard-cranelift-phase25-musl-c-free-link: {message}")
        raise SystemExit(1)


def poison_dir() -> Path:
    """A PATH entry where every C driver exits 99, and nothing else lives."""
    out = BUILD / "poison"
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    for name in POISONED:
        shim = out / name
        shim.write_text(
            "#!/bin/sh\n"
            f'echo "POISONED: {name} invoked" >&2\n'
            "exit 99\n"
        )
        shim.chmod(0o755)
    return out


def probe_crate() -> Path:
    """Generated, not tracked: a Cargo crate in the tree would join the
    workspace and every cargo command in the repo would start building it."""
    crate = BUILD / "probe"
    (crate / "src").mkdir(parents=True, exist_ok=True)
    (crate / "Cargo.toml").write_text(
        '[package]\nname = "gust-musl-link-probe"\nversion = "0.1.0"\n'
        'edition = "2021"\n\n[[bin]]\nname = "probe"\npath = "src/main.rs"\n'
        "\n[workspace]\n"
    )
    (crate / "src" / "main.rs").write_text(
        "// Calls the symbol so --gc-sections cannot strip the archive away\n"
        "// and leave this guard passing on a link that resolved nothing.\n"
        f'#[link(name = "gust_runtime_rs", kind = "static")]\n'
        f"extern \"C\" {{ fn {PROBE_SYMBOL}(); }}\n"
        "fn main() {\n"
        f"    unsafe {{ {PROBE_SYMBOL}() }};\n"
        f"    std::process::exit({SENTINEL});\n"
        "}\n"
    )
    return crate


def env_with(poison: Path) -> dict:
    env = dict(os.environ)
    cargo_bin = str(Path.home() / ".cargo" / "bin")
    # The poison directory goes FIRST so its shims win, and the real cargo
    # and rustc must still be reachable behind it.
    env["PATH"] = os.pathsep.join([str(poison), cargo_bin, "/usr/bin", "/bin"])
    return env


def validate() -> None:
    BUILD.mkdir(parents=True, exist_ok=True)
    poison = poison_dir()
    env = env_with(poison)

    # ARM THE INSTRUMENT before trusting anything it says.
    probe = subprocess.run(["cc", "--version"], env=env,
                           capture_output=True, text=True)
    require(probe.returncode == 99,
            "the poisoned cc did not fire, so a successful link here would "
            f"prove nothing: cc exited {probe.returncode}")
    for tool in ("cargo", "rustc"):
        require(shutil.which(tool, path=env["PATH"]) is not None,
                f"{tool} is not reachable behind the poison directory, so "
                "this guard would measure a missing toolchain, not a C-free "
                "link")

    installed = subprocess.run(["rustup", "target", "list", "--installed"],
                               env=env, capture_output=True, text=True)
    require(TARGET in installed.stdout,
            f"the {TARGET} target is not installed; the C-free link this "
            "phase proves is the musl one, so without it there is nothing "
            "to measure")

    built = subprocess.run(
        ["cargo", "build", "--release", "--target", TARGET,
         "--manifest-path", str(RUNTIME_MANIFEST)],
        env=env, capture_output=True, text=True, cwd=ROOT)
    require(built.returncode == 0,
            "the runtime crate does not build for musl, which is the claim "
            f"`runtime-archive-is-glibc-bound` rests on:\n{built.stderr[-1500:]}")

    archive = (RUNTIME_MANIFEST.parent / "target" / TARGET / "release"
               / "libgust_runtime_rs.a")
    require(archive.is_file(), f"no musl archive at {archive}")

    crate = probe_crate()
    link_env = dict(env)
    link_env["RUSTFLAGS"] = (
        "-C linker=rust-lld -C linker-flavor=ld.lld "
        "-C target-feature=+crt-static "
        f"-L native={archive.parent}")
    linked = subprocess.run(
        ["cargo", "build", "--release", "--target", TARGET],
        env=link_env, capture_output=True, text=True, cwd=crate)
    require(linked.returncode == 0,
            "the C-free musl link FAILED with every C driver poisoned:\n"
            f"{linked.stderr[-2000:]}")

    binary = crate / "target" / TARGET / "release" / "probe"
    require(binary.is_file(),
            "the link reported success but produced no binary -- an exit-0 "
            "that means nothing ran")

    ran = subprocess.run([str(binary)], capture_output=True)
    require(ran.returncode == SENTINEL,
            f"the C-free binary ran but exited {ran.returncode}, not "
            f"{SENTINEL}: the archive linked but {PROBE_SYMBOL} did not run")

    readelf = subprocess.run(["readelf", "-l", str(binary)],
                             capture_output=True, text=True)
    require("interpreter" not in readelf.stdout.lower(),
            "the C-free binary carries an INTERP segment, so it wants a "
            "dynamic loader and is not the static-pie this phase measured")

    print("guard-cranelift-phase25-musl-c-free-link: ok. With "
          f"{', '.join(POISONED)} all poisoned to exit 99, the runtime crate "
          f"builds for {TARGET}, a program calling {PROBE_SYMBOL} links "
          f"through rust-lld, runs, and exits {SENTINEL} as a static-pie.")


def report() -> None:
    print(json.dumps({
        "version": "phase25_musl_c_free_link_v1",
        "target": TARGET,
        "poisoned": list(POISONED),
        "probe_symbol": PROBE_SYMBOL,
        "sentinel_exit": SENTINEL,
    }, indent=2))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["validate", "report"])
    args = parser.parse_args()
    {"validate": validate, "report": report}[args.command]()
    return 0


if __name__ == "__main__":
    sys.exit(main())
