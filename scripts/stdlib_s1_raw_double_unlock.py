#!/usr/bin/env python3
"""Verify generated cleanup for the CR-16 compile-only limitation witness.

Inspect the executed prefix of the generated entry function, not declarations
or the unreachable cleanup suffix that codegen can emit after an explicit return.
This demonstrates acceptance plus two unlock paths without running either one.
"""

from pathlib import Path
import re
import sys


def body(source, name):
    match = re.search(r"^\w[^\n]*\b" + re.escape(name) + r"\([^;\n]*\) \{\n(.*?)^\}",
                      source, re.M | re.S)
    if not match:
        raise ValueError(f"Missing generated function body: {name}")
    return match[1]


def validate(source):
    entry = body(source, "gust_user_main_impl")
    prefix, returned, _ = entry.partition("return ")
    if not returned:
        raise ValueError("Missing explicit return in witness entry")
    raw = re.findall(r"std_Mutex_Unlock_impl\(mutex\.lock_state\);", prefix)
    cleanup = re.findall(r"\b(\w*release_mutex_guard\w*)\(owner\);", prefix)
    if len(raw) != 1 or len(cleanup) != 1:
        raise ValueError("Entry must retain one raw unlock and one owner cleanup before return")
    if prefix.index(raw[0]) >= prefix.index(cleanup[0] + "(owner);"):
        raise ValueError("Raw unlock must precede owner cleanup")
    release = body(source, cleanup[0])
    if len(re.findall(r"\bstd_Mutex_Unlock_impl\(", release)) != 1:
        raise ValueError("Registered cleanup must itself unlock exactly once")


if __name__ == "__main__":
    try:
        validate(Path(sys.argv[1]).read_text())
        print("CR-16: raw unlock and scoped cleanup both emitted; program never executed")
    except (ValueError, OSError) as error:
        sys.exit(f"CR-16 generated-cleanup witness: {error}")
