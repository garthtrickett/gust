#!/usr/bin/env python3
'''Step 5.1 focused address-escape inventory helper.

This helper is intentionally textual and report-only. It separates likely
safe-code address-escape expressions from already-unsafe address expressions,
reference type/cast syntax, intentional raw-cast gating fixtures, generated
strings, and comments before any compiler-backed address-escape rule is designed.
It is not an enforcement mechanism.
'''

from __future__ import annotations

from pathlib import Path
import re


SCAN_ROOTS = [Path('compiler'), Path('tests')]
SCAN_SUFFIXES = {'.gst'}
INTENTIONAL_RAW_CAST_GATING_FIXTURES = {
    Path('tests/test_deref_outside_unsafe_rejected.gst'),
    Path('tests/test_raw_pointer_cast_outside_unsafe_rejected.gst'),
}
REFERENCE_TYPE_HINT = re.compile(
    r'(^|[(:,]\s*|\)\s*|\bas\s+)&[A-Za-z_][A-Za-z0-9_.]*(\[[^]]+\])?'
)


def mask_reference_type_syntax(line: str) -> str:
    return REFERENCE_TYPE_HINT.sub(' ', line)


def line_reference_type_terms(line: str) -> str:
    if REFERENCE_TYPE_HINT.search(line) is None:
        return ''
    return 'reference type/cast syntax'


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
    masked = mask_reference_type_syntax(line)
    found: list[str] = []
    if '&ctx[' in masked:
        found.append('arena slot address')
    if has_indexed_address(masked):
        found.append('indexed address')
    if ' as *' in masked and '&' in masked:
        found.append('address-to-raw cast')
    return ', '.join(found)


def line_is_unsafe_context(code: str, stack: list[bool]) -> bool:
    if any(stack):
        return True
    if re.search(r'\bunsafe\s*\{', code) is not None:
        return True
    if re.search(r'\bunsafe\s+func\b[^{]*\{', code) is not None:
        return True
    return False


def update_unsafe_stack(code: str, stack: list[bool]) -> None:
    for idx, ch in enumerate(code):
        if ch == '{':
            prefix = code[:idx]
            is_unsafe = (
                any(stack)
                or re.search(r'\bunsafe\s*$', prefix) is not None
                or re.search(r'\bunsafe\s+func\b[^{]*$', prefix) is not None
            )
            stack.append(is_unsafe)
        elif ch == '}':
            if stack:
                stack.pop()


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
    safe_code_candidates: list[tuple[Path, int, str, str]],
    unsafe_context: list[tuple[Path, int, str, str]],
    reference_type_syntax: list[tuple[Path, int, str, str]],
    intentional_raw_cast_fixtures: list[tuple[Path, int, str, str]],
    generated_or_string: list[tuple[Path, int, str, str]],
    comment_only: list[tuple[Path, int, str, str]],
) -> None:
    print('Summary:')
    print(f'Direct safe-code address-escape candidates: {len(safe_code_candidates)}')
    print(f'Already-unsafe address expressions: {len(unsafe_context)}')
    print(f'Reference type/cast syntax entries: {len(reference_type_syntax)}')
    print(f'Intentional raw-cast gating fixtures: {len(intentional_raw_cast_fixtures)}')
    print(f'Generated string/template references: {len(generated_or_string)}')
    print(f'Comment-only references: {len(comment_only)}')
    if len(safe_code_candidates) == 0:
        print('No unclassified safe-code address-escape candidates were found; keep address-escape enforcement deferred until a real semantic rule is designed.')
    print('Report-only: address-escape enforcement remains deferred until safe-code candidates are inspected semantically.')
    print()


def main() -> None:
    safe_code_candidates: list[tuple[Path, int, str, str]] = []
    unsafe_context: list[tuple[Path, int, str, str]] = []
    reference_type_syntax: list[tuple[Path, int, str, str]] = []
    intentional_raw_cast_fixtures: list[tuple[Path, int, str, str]] = []
    generated_or_string: list[tuple[Path, int, str, str]] = []
    comment_only: list[tuple[Path, int, str, str]] = []

    for path in iter_source_files():
        try:
            lines = path.read_text(encoding='utf-8').splitlines()
        except UnicodeDecodeError:
            lines = path.read_text(errors='replace').splitlines()

        unsafe_stack: list[bool] = []
        for line_no, raw in enumerate(lines, start=1):
            stripped = strip_comments_and_strings(raw)
            raw_terms = line_terms(raw)
            raw_reference_terms = line_reference_type_terms(raw)
            if raw_terms == '' and raw_reference_terms == '':
                update_unsafe_stack(stripped, unsafe_stack)
                continue

            stripped_terms = line_terms(stripped)
            stripped_reference_terms = line_reference_type_terms(stripped)

            if stripped_terms == '':
                if stripped_reference_terms != '':
                    add_entry(reference_type_syntax, path, line_no, raw, stripped_reference_terms)
                elif '//' in raw:
                    add_entry(comment_only, path, line_no, raw, raw_terms)
                else:
                    add_entry(generated_or_string, path, line_no, raw, raw_terms)
                update_unsafe_stack(stripped, unsafe_stack)
                continue

            if path in INTENTIONAL_RAW_CAST_GATING_FIXTURES:
                add_entry(intentional_raw_cast_fixtures, path, line_no, raw, stripped_terms)
            elif line_is_unsafe_context(stripped, unsafe_stack):
                add_entry(unsafe_context, path, line_no, raw, stripped_terms)
            else:
                add_entry(safe_code_candidates, path, line_no, raw, stripped_terms)
            update_unsafe_stack(stripped, unsafe_stack)

    print('Focused Step 5.1 address-escape inventory')
    print('==========================================')
    print()
    print_bucket('Direct safe-code address-escape candidates:', safe_code_candidates)
    print_bucket('Already-unsafe address expressions:', unsafe_context)
    print_bucket('Reference type/cast syntax entries:', reference_type_syntax)
    print_bucket('Intentional raw-cast gating fixtures:', intentional_raw_cast_fixtures)
    print_bucket('Generated string/template address references:', generated_or_string)
    print_bucket('Comment-only address references:', comment_only)
    print_summary(safe_code_candidates, unsafe_context, reference_type_syntax, intentional_raw_cast_fixtures, generated_or_string, comment_only)
    print('Report-only: do not wire this helper into make test as an enforcement gate.')


if __name__ == '__main__':
    main()
