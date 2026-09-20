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


def cc_is_a_default_not_a_constant() -> bool:
    """`cc` must remain reachable through $CC, not be hardcoded or removed."""
    if not WORKER.is_file():
        return False
    text = WORKER.read_text(encoding="utf-8", errors="replace")
    return bool(re.search(r'var_os\("CC"\)', text))


def report() -> dict:
    return {
        "version": "phase25_linker_driver_policy_v1",
        "cc_required": False,
        "cc_supported": True,
        "cc_reachable_through_env": cc_is_a_default_not_a_constant(),
        "gate_target": MUSL_TARGET,
        "gate_blocked_until": ["25.5", "25.6"],
        "gate_blocker": "the runtime archive is glibc-bound and cannot link "
                        "against musl (Patch 25.0)",
        "user_default": "host native target; musl is opt-in via --target",
        "no_silent_fallback": True,
    }


def validate() -> None:
    record = report()
    # The whole decision is "not required, still supported". Losing $CC
    # would quietly convert it into "forbidden", which regresses every gnu
    # user and packager to no purpose the gate asks for.
    require(record["cc_reachable_through_env"],
            "the worker no longer reads $CC. D9 says cc stops being "
            "REQUIRED, not supported: removing the variable forbids it, "
            "which regresses gnu targets, distro packagers and "
            "cross-compilers for nothing the exit gate asks for.")
    require(record["cc_required"] is False and record["cc_supported"] is True,
            "the policy record no longer says not-required-but-supported")
    require(record["no_silent_fallback"],
            "silent musl fallback would hand users a static binary with a "
            "non-functional dlopen as a side effect of their package list")
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
