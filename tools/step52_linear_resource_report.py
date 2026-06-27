#!/usr/bin/env python3
'''Step 5.2 focused linear-resource inventory helper.

This helper is intentionally textual and report-only. It separates the current
specialized directory-handle tracking lane and existing linear-type metadata
from future generalized resource syntax before any Resource[ctx, T], destructor
metadata, or leak enforcement is designed.
'''

from __future__ import annotations

from pathlib import Path


SCAN_ROOTS = [Path('compiler'), Path('tests'), Path('src')]
SCAN_SUFFIXES = {'.gst', '.c', '.h', '.rs'}
SPECIALIZED_DIRECTORY_TERMS = (
    'open_directories',
    'OpenDir',
    'ReadDir',
    'CloseDir',
    'os_OpenDir',
    'os_ReadDir',
    'os_CloseDir',
)
NATIVE_DIRECTORY_TERMS = (
    'DIR*',
    'DIR *',
    'opendir',
    'readdir',
    'closedir',
)
EXISTING_LINEAR_METADATA_TERMS = (
    '#[linear]',
    'is_linear',
    'linear',
)
FUTURE_RESOURCE_TERMS = (
    'Resource[',
    'open_linear_resources',
)
DESTRUCTOR_TERMS = (
    'drop_func',
    'defer',
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


def matching_terms(line: str, terms: tuple[str, ...]) -> str:
    found: list[str] = []
    for term in terms:
        if term in line:
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
    specialized_directory_tracking: list[tuple[Path, int, str, str]],
    native_directory_boundaries: list[tuple[Path, int, str, str]],
    existing_linear_metadata: list[tuple[Path, int, str, str]],
    future_resource_syntax: list[tuple[Path, int, str, str]],
    destructor_or_defer_syntax: list[tuple[Path, int, str, str]],
    generated_or_comment_only: list[tuple[Path, int, str, str]],
) -> None:
    print('Summary:')
    print(f'Specialized directory tracking entries: {len(specialized_directory_tracking)}')
    print(f'Native directory runtime boundary entries: {len(native_directory_boundaries)}')
    print(f'Existing linear metadata/test entries: {len(existing_linear_metadata)}')
    print(f'Future Resource/open-linear registry entries: {len(future_resource_syntax)}')
    print(f'Destructor/defer syntax entries: {len(destructor_or_defer_syntax)}')
    print(f'Generated string/comment-only references: {len(generated_or_comment_only)}')
    if len(future_resource_syntax) == 0:
        print('No Resource[ctx, T] or open_linear_resources syntax is present yet; keep generalized Step 5.2 enforcement deferred.')
    print()


def main() -> None:
    specialized_directory_tracking: list[tuple[Path, int, str, str]] = []
    native_directory_boundaries: list[tuple[Path, int, str, str]] = []
    existing_linear_metadata: list[tuple[Path, int, str, str]] = []
    future_resource_syntax: list[tuple[Path, int, str, str]] = []
    destructor_or_defer_syntax: list[tuple[Path, int, str, str]] = []
    generated_or_comment_only: list[tuple[Path, int, str, str]] = []

    for path in iter_source_files():
        try:
            lines = path.read_text(encoding='utf-8').splitlines()
        except UnicodeDecodeError:
            lines = path.read_text(errors='replace').splitlines()

        for line_no, raw in enumerate(lines, start=1):
            raw_specialized = matching_terms(raw, SPECIALIZED_DIRECTORY_TERMS)
            raw_native = matching_terms(raw, NATIVE_DIRECTORY_TERMS)
            raw_existing_linear = matching_terms(raw, EXISTING_LINEAR_METADATA_TERMS)
            raw_future_resource = matching_terms(raw, FUTURE_RESOURCE_TERMS)
            raw_destructor = matching_terms(raw, DESTRUCTOR_TERMS)
            if raw_specialized == '' and raw_native == '' and raw_existing_linear == '' and raw_future_resource == '' and raw_destructor == '':
                continue

            stripped = strip_comments_and_strings(raw)
            specialized_terms = matching_terms(stripped, SPECIALIZED_DIRECTORY_TERMS)
            native_terms = matching_terms(stripped, NATIVE_DIRECTORY_TERMS)
            existing_linear_terms = matching_terms(stripped, EXISTING_LINEAR_METADATA_TERMS)
            future_resource_terms = matching_terms(stripped, FUTURE_RESOURCE_TERMS)
            destructor_terms = matching_terms(stripped, DESTRUCTOR_TERMS)

            if specialized_terms == '' and native_terms == '' and existing_linear_terms == '' and future_resource_terms == '' and destructor_terms == '':
                raw_terms = ', '.join(term for term in [raw_specialized, raw_native, raw_existing_linear, raw_future_resource, raw_destructor] if term != '')
                add_entry(generated_or_comment_only, path, line_no, raw, raw_terms)
                continue

            if existing_linear_terms != '':
                add_entry(existing_linear_metadata, path, line_no, raw, existing_linear_terms)
            if future_resource_terms != '':
                add_entry(future_resource_syntax, path, line_no, raw, future_resource_terms)
            if destructor_terms != '':
                add_entry(destructor_or_defer_syntax, path, line_no, raw, destructor_terms)
            if native_terms != '':
                add_entry(native_directory_boundaries, path, line_no, raw, native_terms)
            if specialized_terms != '':
                add_entry(specialized_directory_tracking, path, line_no, raw, specialized_terms)

    print('Focused Step 5.2 linear-resource inventory')
    print('===========================================')
    print()
    print_bucket('Specialized directory tracking entries:', specialized_directory_tracking)
    print_bucket('Native directory runtime boundary entries:', native_directory_boundaries)
    print_bucket('Existing linear metadata/test entries:', existing_linear_metadata)
    print_bucket('Future Resource/open-linear registry entries:', future_resource_syntax)
    print_bucket('Destructor/defer syntax entries:', destructor_or_defer_syntax)
    print_bucket('Generated string/comment-only references:', generated_or_comment_only)
    print_summary(
        specialized_directory_tracking,
        native_directory_boundaries,
        existing_linear_metadata,
        future_resource_syntax,
        destructor_or_defer_syntax,
        generated_or_comment_only,
    )
    print('Report-only: do not wire this helper into make test as an enforcement gate.')


if __name__ == '__main__':
    main()
