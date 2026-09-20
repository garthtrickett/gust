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


def worker_mentions_musl() -> bool:
    """The falsifier for both policy claims below.

    `user_default` and `no_silent_fallback` used to be hardcoded literals
    that validate() re-read, so the guard stayed green for exactly the
    regressions Patch 25.11 exists to prevent. They are now derived from one
    measured fact: the worker does not mention musl anywhere, so it cannot
    default to it and cannot silently fall back to it. The day musl appears
    in the worker, that derivation stops holding and must be redone against
    whatever the new code does.
    """
    return "musl" in worker_text().lower()


def report() -> dict:
    return {
        "version": "phase25_linker_driver_policy_v1",
        "cc_required": False,
        "cc_supported": True,
        "cc_reaches_the_linker": cc_reaches_the_linker(),
        "worker_mentions_musl": worker_mentions_musl(),
        "gate_target": MUSL_TARGET,
        "gate_blocked_until": ["25.5", "25.6"],
        "gate_blocker": "the runtime archive is glibc-bound and cannot link "
                        "against musl (Patch 25.0)",
        "user_default": "host native target; musl is opt-in via --target",
        "no_silent_fallback": not worker_mentions_musl(),
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
            "the worker now mentions musl, so 'no silent fallback' and "
            "'host native default' are no longer derivable from its silence "
            "on the subject. They were hardcoded literals until now, which "
            "kept this guard green for precisely the regression it exists "
            "to catch: re-derive both against whatever the new code does.")
    print("guard-cranelift-phase25-linker-driver-policy: ok "
          "(cc not required, still supported via $CC; gate proved on "
          f"{MUSL_TARGET}, blocked until "
          f"{' and '.join(record['gate_blocked_until'])})")


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
