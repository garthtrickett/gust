#!/usr/bin/env python3
'''Step 5.1 focused address-escape inventory helper.

This helper is intentionally textual and report-only. It separates likely
address-escape expressions from generated strings and comments before any
compiler-backed address-escape rule is designed. It is not an enforcement
mechanism.
'''

from __future__ import annotations

from pathlib import Path


SCAN_ROOTS = [Path('compiler'), Path('tests')]
SCAN_SUFFIXES = {'.gst'}


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


def has_indexed_address(line: str) -> bool:
    idx = 0
    while idx < len(line):
        amp = line.find('&', idx)
        if amp == -1:
            return False
        if amp + 1 >= len(line):
            return False
        next_ch = line[amp + 1]
        if next_ch.isalpha() or next_ch == '_':
            bracket = line.find('[', amp + 1)
            if bracket != -1:
                return True
        idx = amp + 1
    return False


def line_terms(line: str) -> str:
    found: list[str] = []
    if '&ctx[' in line:
        found.append('arena slot address')
    if has_indexed_address(line):
        found.append('indexed address')
    if ' as *' in line and '&' in line:
        found.append('address-to-raw cast')
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
    direct_source: list[tuple[Path, int, str, str]],
    generated_or_string: list[tuple[Path, int, str, str]],
    comment_only: list[tuple[Path, int, str, str]],
) -> None:
    print('Summary:')
    print(f'Direct source address-escape candidates: {len(direct_source)}')
    print(f'Generated string/template references: {len(generated_or_string)}')
    print(f'Comment-only references: {len(comment_only)}')
    print('Report-only: address-escape enforcement remains deferred until direct candidates are inspected semantically.')
    print()


def main() -> None:
    direct_source: list[tuple[Path, int, str, str]] = []
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

            add_entry(direct_source, path, line_no, raw, stripped_terms)

    print('Focused Step 5.1 address-escape inventory')
    print('==========================================')
    print()
    print_bucket('Direct source address-escape candidates:', direct_source)
    print_bucket('Generated string/template address references:', generated_or_string)
    print_bucket('Comment-only address references:', comment_only)
    print_summary(direct_source, generated_or_string, comment_only)
    print('Report-only: do not wire this helper into make test as an enforcement gate.')


if __name__ == '__main__':
    main()