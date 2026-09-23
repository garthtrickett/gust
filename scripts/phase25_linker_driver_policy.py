#!/usr/bin/env python3
"""Patch 25.11: cc stops being REQUIRED. It does not stop being SUPPORTED.

D9, restated after the measurement corrected it twice.

`cc` is a linker DRIVER, not a linker. It computes a link line and invokes
`ld`/`ld.lld`. So this was never "C linker versus Rust linker" -- both
routes end in a linker, possibly the same one. The question is who computes
the link line: a C compiler that already knows crt object locations,
library search paths, the dynamic-linker path, libgcc and PIE/relro
defaults per distro and architecture, or Gust.

Measured by poisoning cc, gcc, clang, c++, g++, ld and cc1 to exit 99:

  rustc (gnu, default)                    cc IS invoked
  rustc --target ...-musl (default)       cc IS invoked -- self-contained
                                          crt, still driven by cc
  gnu + rust-lld + ld.lld flavor          FAILS: -lc -lm -ldl -lpthread
                                          -lrt -lutil -lgcc_s unfound
  musl + rust-lld + ld.lld flavor         WORKS: static-pie, exit 7

So there is no stock C-free link on gnu, and "link with rustc" removes
nothing by itself. The C-free link that works is musl.

Patch 25.0 then found the harder half: the runtime archive is glibc-bound
-- __printf_chk, __fprintf_chk, __memcpy_chk, __isoc23_strtol, __stack_chk
-- so it cannot link against musl at all. THE GATE IS NOT PROVABLE UNTIL
THE RUNTIME STOPS BEING C. This patch's exit gate therefore depends on
25.5 and 25.6, which is D1's runtime-first ordering being right for a
second, independently measured reason.

USER DEFAULT: the host's native target (O6). Defaulting to musl would hand
users a static binary with a non-functional dlopen and different name
resolution as a side effect of how Gust's CI proves a gate. On a gnu host
with no C compiler the driver PROBES and then ERRORS naming the musl
target -- it never silently switches, because a binary the user did not ask
for is worse than an error they can act on (P10).
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKER = ROOT / "compiler" / "experiments" / "cranelift" / "src" / "main.rs"

MUSL_TARGET = "x86_64-unknown-linux-musl"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"guard-cranelift-phase25-linker-driver-policy: {message}")
        raise SystemExit(1)


def worker_text() -> str:
    if not WORKER.is_file():
        return ""
    return WORKER.read_text(encoding="utf-8", errors="replace")


def cc_reaches_the_linker() -> bool:
    """$CC must reach the linker invocation, not merely be read somewhere.

    A bare search for `var_os("CC")` is satisfied by a refactor that reads
    the variable into an unused binding and hardcodes the driver -- the
    contract would be broken and the guard still green. So both ends of the
    data flow are checked: the read must BIND `linker_driver`, and the
    command must be constructed FROM that binding.
    """
    text = worker_text()
    binds = re.search(
        r'let\s+linker_driver\s*(?::[^=]+)?=\s*\n?\s*env::var_os\("CC"\)',
        text)
    invokes = "Command::new(&request.linker_driver)" in text
    return bool(binds) and invokes


FLAVOUR_GATE = 'env::var("GUST_NATIVE_LINK_FLAVOR")'
FLAVOUR_VALUE = 'Ok("rustc-lld")'
FLAVOUR_BRANCH = "let linker_driver = if rustc_lld {"


def worker_mentions_musl() -> bool:
    """Kept as a measurement, no longer as the derivation.

    Patch 25.11 derived `no_silent_fallback` from the worker's SILENCE on
    musl: it could not default to what it never named. Patch 25.12b gives
    the backend a C-free link route, so musl is named now and that
    derivation is spent -- exactly as the note here said it would be.
    """
    return MUSL_TARGET in worker_text()


def musl_is_opt_in_only() -> bool:
    r"""The re-derivation: musl is reachable ONLY behind an explicit opt-in.

    Silence is gone, so the claim has to be measured against what the code
    actually does. Three facts, and all three must hold:

      * the flavour gate exists and reads GUST_NATIVE_LINK_FLAVOR, matching
        the single literal "rustc-lld" -- so nothing selects musl by
        inference from a target triple, a host probe or a missing cc;
      * EVERY mention of the musl target lies inside the branch that gate
        guards, computed by brace-matching from the branch head rather than
        by proximity, so a musl default added elsewhere in 37,000 lines
        fails here;
      * the else arm binds the $CC-derived driver, so the default path is
        unchanged.

    This is strictly weaker than the silence it replaces and says so. What
    it still forbids is the regression Patch 25.11 cared about: a build that
    quietly hands a user a static musl binary with a non-functional dlopen
    because no C compiler was found (P10). Opting in is a deliberate act.
    """
    text = worker_text()
    if text.count(FLAVOUR_GATE) != 1 or FLAVOUR_VALUE not in text:
        return False
    head = text.find(FLAVOUR_BRANCH)
    if head < 0:
        return False
    start = head + len(FLAVOUR_BRANCH) - 1
    depth, end = 0, None
    for index in range(start, len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                end = index
                break
    if end is None:
        return False
    inside = text[start:end]
    occurrences = text.count(MUSL_TARGET)
    if occurrences == 0 or inside.count(MUSL_TARGET) != occurrences:
        return False
    tail = text[end:end + 400]
    return "} else {" in tail and "linker_driver" in tail


def report() -> dict:
    return {
        "version": "phase25_linker_driver_policy_v1",
        "cc_required": False,
        "cc_supported": True,
        "cc_reaches_the_linker": cc_reaches_the_linker(),
        "worker_mentions_musl": worker_mentions_musl(),
        "gate_target": MUSL_TARGET,
        # Patch 25.12b: the blocker is gone. 25.5, 25.6 and 25.10a moved the
        # runtime into src/runtime-rs, so the archive is pure Rust and builds
        # for musl; scripts/phase25_musl_c_free_link.py links a program that
        # CALLS into it with nine C drivers poisoned and runs the result as
        # static-pie. Kept as a record of what blocked it rather than deleted,
        # because "blocked until 25.5 and 25.6" was the reason D1's
        # runtime-first ordering was right and that is worth not losing.
        "gate_blocked_until": [],
        "gate_was_blocked_until": ["25.5", "25.6"],
        "gate_blocker": None,
        "gate_was_blocked_by": "the runtime archive was glibc-bound and could "
                               "not link against musl (Patch 25.0); cleared "
                               "by Patch 25.12b",
        "gate_proof": "scripts/phase25_musl_c_free_link.py",
        "user_default": "host native target; musl is opt-in via GUST_NATIVE_LINK_FLAVOR=rustc-lld",
        "musl_is_opt_in_only": musl_is_opt_in_only(),
        "no_silent_fallback": musl_is_opt_in_only(),
    }


def validate() -> None:
    record = report()
    # The whole decision is "not required, still supported". Losing $CC
    # would quietly convert it into "forbidden", which regresses every gnu
    # user and packager to no purpose the gate asks for.
    require(record["cc_reaches_the_linker"],
            "$CC no longer reaches the linker invocation. D9 says cc stops "
            "being REQUIRED, not supported: losing the variable forbids it, "
            "which regresses gnu targets, distro packagers and "
            "cross-compilers for nothing the exit gate asks for. Both ends "
            "are checked -- the read must bind `linker_driver` and the "
            "command must be built from that binding -- because reading $CC "
            "into an unused binding satisfied the previous test.")
    require(record["cc_required"] is False and record["cc_supported"] is True,
            "the policy record no longer says not-required-but-supported")
    require(record["no_silent_fallback"],
            "musl is no longer reachable ONLY behind the explicit "
            "GUST_NATIVE_LINK_FLAVOR=rustc-lld opt-in. Patch 25.11 derived "
            "this from the worker's silence on musl; Patch 25.12b gives the "
            "backend a C-free route, so it is derived from the code instead: "
            "one flavour gate, every musl mention inside the branch that "
            "gate guards, and an else arm that binds the $CC-derived driver. "
            "One of those stopped holding, which is how a silent musl "
            "default would look -- P10 says a binary the user did not ask "
            "for is worse than an error they can act on.")
    blocked = record["gate_blocked_until"]
    standing = (f"blocked until {' and '.join(blocked)}" if blocked
                else f"PROVED by {record['gate_proof']}")
    print("guard-cranelift-phase25-linker-driver-policy: ok "
          "(cc not required, still supported via $CC; musl reachable only "
          f"via GUST_NATIVE_LINK_FLAVOR=rustc-lld; gate on {MUSL_TARGET} "
          f"{standing})")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["report", "validate"])
    args = parser.parse_args()
    if args.command == "report":
        print(json.dumps(report(), indent=2, sort_keys=True))
    else:
        validate()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
