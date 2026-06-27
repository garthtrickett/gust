#!/usr/bin/env python3
'''Step 5.1 focused FFI inventory helper.

This helper is intentionally textual and report-only. It narrows the broad
Makefile FFI regex by separating direct source tokens from generated strings,
comments, and native runtime boundary files before any compiler-backed FFI
gating is designed. Its summary makes the no-direct-Gust-candidate state
explicit so the FFI lane does not invent an enforcement surface prematurely.
'''

from __future__ import annotations

from pathlib import Path
import re


SCAN_ROOTS = [Path('compiler'), Path('tests'), Path('src')]
SCAN_SUFFIXES = {'.gst', '.c', '.h'}
FFI_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ('extern', re.compile(r'\bextern\b')),
    ('ffi', re.compile(r'\bffi\b', re.IGNORECASE)),
    ('Foreign', re.compile(r'\bForeign\b')),
    ('C.', re.compile(r'\bC\.')),
    ('ccall', re.compile(r'\bccall\b')),
    ('c_call', re.compile(r'\bc_call\b')),
    ('dlsym', re.compile(r'\bdlsym\b')),
    ('dlopen', re.compile(r'\bdlopen\b')),
    ('syscall', re.compile(r'\bsyscall\b')),
)


def strip_comments_and_strings(line: str) -> str:
    out: list[str] = []
    i = 0
    in_string = False
    quote = ''
    escaped = False

    while i < len(line):
        ch = line[i]
        nxt = line[i + 1] if i + 1 < len(line) else ''

        if in_string:
            out.append(' ')
            if escaped:
                escaped = False
            elif ch == chr(92):
                escaped = True
            elif ch == quote:
                in_string = False
                quote = ''
            i += 1
            continue

        if ch == '/' and nxt == '/':
            break

        if ch == chr(34) or ch == chr(39):
            in_string = True
            quote = ch
            out.append(' ')
            i += 1
            continue

        out.append(ch)
        i += 1

    return ''.join(out)


def line_terms(line: str) -> str:
    found: list[str] = []
    for term, pattern in FFI_PATTERNS:
        if pattern.search(line) is not None:
            found.append(term)
    return ', '.join(found)


def iter_source_files() -> list[Path]:
    files: list[Path] = []
    for root in SCAN_ROOTS:
        if not root.exists():
            continue
        for path in root.rglob('*'):
            if path.is_file() and path.suffix in SCAN_SUFFIXES:
                files.append(path)
    return sorted(files)


def add_entry(bucket: list[tuple[Path, int, str, str]], path: Path, line_no: int, line: str, terms: str) -> None:
    bucket.append((path, line_no, line.strip(), terms))


def print_bucket(title: str, entries: list[tuple[Path, int, str, str]]) -> None:
    print(title)
    if len(entries) == 0:
        print('(none)')
        print()
        return

    for path, line_no, line, terms in entries:
        print(f'{path}:{line_no}: {line} [{terms}]')
    print()


def print_summary(
    direct_gust: list[tuple[Path, int, str, str]],
    native_runtime: list[tuple[Path, int, str, str]],
    generated_or_string: list[tuple[Path, int, str, str]],
    comment_only: list[tuple[Path, int, str, str]],
) -> None:
    print('Summary:')
    print(f'Direct Gust source candidates: {len(direct_gust)}')
    print(f'Native runtime boundary candidates: {len(native_runtime)}')
    print(f'Generated string/template references: {len(generated_or_string)}')
    print(f'Comment-only references: {len(comment_only)}')
    if len(direct_gust) == 0:
        print('No direct Gust source FFI/native-call candidates were found; keep compiler-backed FFI enforcement deferred until a real syntax surface exists.')
    print()


def main() -> None:
    direct_gust: list[tuple[Path, int, str, str]] = []
    native_runtime: list[tuple[Path, int, str, str]] = []
    generated_or_string: list[tuple[Path, int, str, str]] = []
    comment_only: list[tuple[Path, int, str, str]] = []

    for path in iter_source_files():
        try:
            lines = path.read_text(encoding='utf-8').splitlines()
        except UnicodeDecodeError:
            lines = path.read_text(errors='replace').splitlines()

        for line_no, raw in enumerate(lines, start=1):
            raw_terms = line_terms(raw)
            if raw_terms == '':
                continue

            stripped = strip_comments_and_strings(raw)
            stripped_terms = line_terms(stripped)

            if stripped_terms == '':
                if '//' in raw:
                    add_entry(comment_only, path, line_no, raw, raw_terms)
                else:
                    add_entry(generated_or_string, path, line_no, raw, raw_terms)
                continue

            if str(path).startswith('src/'):
                add_entry(native_runtime, path, line_no, raw, stripped_terms)
            elif path.suffix == '.gst':
                add_entry(direct_gust, path, line_no, raw, stripped_terms)
            else:
                add_entry(native_runtime, path, line_no, raw, stripped_terms)

    print('Focused Step 5.1 FFI inventory')
    print('================================')
    print()
    print_bucket('Direct Gust source FFI/native-call candidates:', direct_gust)
    print_bucket('Native runtime boundary candidates:', native_runtime)
    print_bucket('Generated string/template FFI references:', generated_or_string)
    print_bucket('Comment-only FFI references:', comment_only)
    print_summary(direct_gust, native_runtime, generated_or_string, comment_only)
    print('Report-only: do not wire this helper into make test as an enforcement gate.')


if __name__ == '__main__':
    main()
