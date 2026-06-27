#!/usr/bin/env python3
"""Step 5.1 raw pointer safety inventory helper.

This is intentionally textual and report-only. It narrows the broad Makefile
regexes by tracking explicit unsafe blocks and `unsafe func` bodies well enough
to separate likely safe-code migration candidates from sites already in unsafe
contexts. It is not an enforcement mechanism.
"""

from __future__ import annotations

from pathlib import Path
import re


RAW_PATTERNS = [
    ("raw deref", re.compile(r"(^|[^A-Za-z0-9_])\*\s*(\(|[A-Za-z_][A-Za-z0-9_]*)")),
    ("raw cast", re.compile(r"\bas\s+\*")),
    ("address escape", re.compile(r"&ctx\[|&[A-Za-z_][A-Za-z0-9_]*\[")),
]

TYPE_SYNTAX_HINT = re.compile(
    r":\s*\*|func[^(]*\([^)]*\*|func[^{]*\)\s*\*|[A-Za-z_][A-Za-z0-9_]*\[[^]]*\*|empty\[\*"
)

REFERENCE_SYNTAX_HINT = re.compile(
    r"\bas\s+&[A-Za-z_][A-Za-z0-9_]*(\[|$)|func[^{]*\)\s*&[A-Za-z_][A-Za-z0-9_]*(\[|$)|:\s*&[A-Za-z_][A-Za-z0-9_]*(\[|$)"
)

INTENTIONAL_RAW_GATING_FIXTURES = {
    Path("tests/test_deref_outside_unsafe_rejected.gst"),
    Path("tests/test_raw_pointer_deref_outside_unsafe_rejected.gst"),
    Path("tests/test_raw_pointer_cast_outside_unsafe_rejected.gst"),
    Path("tests/test_raw_pointer_arithmetic_outside_unsafe_rejected.gst"),
}


def strip_comments_and_strings(line: str) -> str:
    out: list[str] = []
    i = 0
    in_string = False
    quote = ""
    escaped = False

    while i < len(line):
        ch = line[i]
        nxt = line[i + 1] if i + 1 < len(line) else ""

        if in_string:
            out.append(" ")
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == quote:
                in_string = False
                quote = ""
            i += 1
            continue

        if ch == "/" and nxt == "/":
            break

        if ch == '"' or ch == "'":
            in_string = True
            quote = ch
            out.append(" ")
            i += 1
            continue

        out.append(ch)
        i += 1

    return "".join(out)


def line_has_raw_op(code: str) -> str:
    labels: list[str] = []
    for label, pattern in RAW_PATTERNS:
        if pattern.search(code):
            labels.append(label)
    return ", ".join(labels)


def line_is_inside_unsafe(code: str, unsafe_depth: int) -> bool:
    labels = []
    for _, pattern in RAW_PATTERNS:
        match = pattern.search(code)
        if match is None:
            continue
        prefix = code[: match.start()]
        labels.append(unsafe_depth > 0 or re.search(r"\bunsafe\s*\{", prefix) is not None)
    return bool(labels) and all(labels)


def update_unsafe_stack(code: str, stack: list[bool]) -> None:
    for idx, ch in enumerate(code):
        if ch == "{":
            prefix = code[:idx]
            is_unsafe = (
                re.search(r"\bunsafe\s*$", prefix) is not None
                or re.search(r"\bunsafe\s+func\b[^{]*$", prefix) is not None
            )
            stack.append(is_unsafe)
        elif ch == "}":
            if stack:
                stack.pop()


def scan_file(path: Path) -> tuple[list[str], list[str], list[str], list[str], list[str]]:
    safe_candidates: list[str] = []
    wrapped_candidates: list[str] = []
    type_syntax: list[str] = []
    reference_syntax: list[str] = []
    intentional_raw_fixtures: list[str] = []

    stack: list[bool] = []
    for line_no, raw_line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        code = strip_comments_and_strings(raw_line)
        labels = line_has_raw_op(code)
        if labels == "":
            update_unsafe_stack(code, stack)
            continue

        unsafe_depth = sum(1 for item in stack if item)
        entry = f"{path}:{line_no}: [{labels}] {raw_line.strip()}"

        if path in INTENTIONAL_RAW_GATING_FIXTURES:
            intentional_raw_fixtures.append(entry)
        elif REFERENCE_SYNTAX_HINT.search(code) and "raw cast" not in labels:
            reference_syntax.append(entry)
        elif TYPE_SYNTAX_HINT.search(code) and "raw cast" not in labels and "address escape" not in labels:
            type_syntax.append(entry)
        elif line_is_inside_unsafe(code, unsafe_depth):
            wrapped_candidates.append(entry)
        else:
            safe_candidates.append(entry)

        update_unsafe_stack(code, stack)

    return safe_candidates, wrapped_candidates, type_syntax, reference_syntax, intentional_raw_fixtures


def main() -> int:
    paths = sorted(Path("compiler").glob("*.gst")) + sorted(Path("tests").glob("*.gst"))

    all_safe: list[str] = []
    all_wrapped: list[str] = []
    all_type_syntax: list[str] = []
    all_reference_syntax: list[str] = []
    all_intentional_raw_fixtures: list[str] = []

    for path in paths:
        safe_candidates, wrapped_candidates, type_syntax, reference_syntax, intentional_raw_fixtures = scan_file(path)
        all_safe.extend(safe_candidates)
        all_wrapped.extend(wrapped_candidates)
        all_type_syntax.extend(type_syntax)
        all_reference_syntax.extend(reference_syntax)
        all_intentional_raw_fixtures.extend(intentional_raw_fixtures)

    print("📊 Step 5.1 focused raw pointer safety report")
    print("   Likely safe-code raw operation candidates:")
    if all_safe:
        for entry in all_safe:
            print(entry)
    else:
        print("   (none)")

    print("   Already wrapped unsafe raw operation candidates:")
    if all_wrapped:
        for entry in all_wrapped:
            print(entry)
    else:
        print("   (none)")

    print("   Raw pointer type syntax / declaration-only candidates:")
    if all_type_syntax:
        for entry in all_type_syntax:
            print(entry)
    else:
        print("   (none)")

    print("   Branded reference type/cast candidates, not raw pointer ops:")
    if all_reference_syntax:
        for entry in all_reference_syntax:
            print(entry)
    else:
        print("   (none)")

    print("   Intentional raw-gating negative fixtures:")
    if all_intentional_raw_fixtures:
        for entry in all_intentional_raw_fixtures:
            print(entry)
    else:
        print("   (none)")

    print("✅ Step 5.1 focused report complete. This tool is report-only and does not fail on findings.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
