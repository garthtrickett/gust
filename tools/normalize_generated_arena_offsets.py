#!/usr/bin/env python3
'''Normalize legacy-generated Gust arena pointer arithmetic.

The checked-in bootstrap predates unsigned arena-offset pointer formation. It
can compile the backend-neutral stage-one bridge, but the emitted C still uses
signed `int` Index values directly in `BaseAddress + index` expressions. This
tool rewrites only actual C tokens, never comments or string/character
literals, and is intentionally applied only to the transitional stage-one C.
'''

from __future__ import annotations

import argparse
import os
from pathlib import Path
import sys
import tempfile


MARKER = "BaseAddress"
SAFE_PREFIXES = (
    "GUST_ARENA_OFFSET(",
    "(size_t)(uint32_t)(",
)


class NormalizeError(RuntimeError):
    pass


def _skip_quoted(source: str, index: int, quote: str) -> int:
    index += 1
    while index < len(source):
        char = source[index]
        if char == "\\":
            index += 2
            continue
        index += 1
        if char == quote:
            return index
    raise NormalizeError("unterminated quoted literal")


def _skip_line_comment(source: str, index: int) -> int:
    newline = source.find("\n", index + 2)
    return len(source) if newline < 0 else newline + 1


def _skip_block_comment(source: str, index: int) -> int:
    end = source.find("*/", index + 2)
    if end < 0:
        raise NormalizeError("unterminated block comment")
    return end + 2


def _operand_end(source: str, start: int) -> int:
    paren_depth = 0
    bracket_depth = 0
    brace_depth = 0
    index = start

    while index < len(source):
        char = source[index]

        if char == '"':
            index = _skip_quoted(source, index, '"')
            continue
        if char == "'":
            index = _skip_quoted(source, index, "'")
            continue
        if source.startswith("//", index):
            index = _skip_line_comment(source, index)
            continue
        if source.startswith("/*", index):
            index = _skip_block_comment(source, index)
            continue

        if char == "(":
            paren_depth += 1
        elif char == ")":
            if paren_depth == 0 and bracket_depth == 0 and brace_depth == 0:
                return index
            paren_depth -= 1
            if paren_depth < 0:
                raise NormalizeError("unbalanced parenthesis in arena offset")
        elif char == "[":
            bracket_depth += 1
        elif char == "]":
            if paren_depth == 0 and bracket_depth == 0 and brace_depth == 0:
                return index
            bracket_depth -= 1
            if bracket_depth < 0:
                raise NormalizeError("unbalanced bracket in arena offset")
        elif char == "{":
            brace_depth += 1
        elif char == "}":
            if paren_depth == 0 and bracket_depth == 0 and brace_depth == 0:
                return index
            brace_depth -= 1
            if brace_depth < 0:
                raise NormalizeError("unbalanced brace in arena offset")
        elif (
            char in ";,"
            and paren_depth == 0
            and bracket_depth == 0
            and brace_depth == 0
        ):
            return index

        index += 1

    raise NormalizeError("arena offset expression has no terminating delimiter")


def normalize_legacy_generated_c(source: str) -> tuple[str, int]:
    output: list[str] = []
    index = 0
    rewrites = 0

    while index < len(source):
        if source[index] == '"':
            end = _skip_quoted(source, index, '"')
            output.append(source[index:end])
            index = end
            continue
        if source[index] == "'":
            end = _skip_quoted(source, index, "'")
            output.append(source[index:end])
            index = end
            continue
        if source.startswith("//", index):
            end = _skip_line_comment(source, index)
            output.append(source[index:end])
            index = end
            continue
        if source.startswith("/*", index):
            end = _skip_block_comment(source, index)
            output.append(source[index:end])
            index = end
            continue

        if source.startswith(MARKER, index):
            before = source[index - 1] if index > 0 else ""
            after_index = index + len(MARKER)
            after = source[after_index] if after_index < len(source) else ""
            if (
                (before.isalnum() or before == "_")
                or (after.isalnum() or after == "_")
            ):
                output.append(source[index])
                index += 1
                continue

            plus_index = after_index
            while plus_index < len(source) and source[plus_index].isspace():
                plus_index += 1
            if plus_index >= len(source) or source[plus_index] != "+":
                output.append(MARKER)
                index = after_index
                continue

            operand_start = plus_index + 1
            while (
                operand_start < len(source)
                and source[operand_start].isspace()
            ):
                operand_start += 1

            if source.startswith(SAFE_PREFIXES, operand_start):
                output.append(source[index:operand_start])
                index = operand_start
                continue

            end = _operand_end(source, operand_start)
            raw_operand = source[operand_start:end]
            operand = raw_operand.rstrip()
            trailing = raw_operand[len(operand):]
            if not operand:
                raise NormalizeError("empty arena offset expression")

            output.append(source[index:operand_start])
            output.append("GUST_ARENA_OFFSET(")
            output.append(operand)
            output.append(")")
            output.append(trailing)
            index = end
            rewrites += 1
            continue

        output.append(source[index])
        index += 1

    return "".join(output), rewrites


def _self_test() -> None:
    fixture = r'''
void f(os_Arena* ctx, int idx, int other) {
    int a = *((int*)((char*)ctx->BaseAddress + idx));
    int b = *((int*)((char*)ctx->BaseAddress + (idx + other)));
    int c = *((int*)((char*)ctx->BaseAddress + GUST_ARENA_OFFSET(idx)));
    int d = *((int*)((char*)ctx->BaseAddress + (size_t)(uint32_t)(idx)));
    const char* text = "BaseAddress + idx";
    // BaseAddress + idx
    /* BaseAddress + idx */
}
'''
    normalized, rewrites = normalize_legacy_generated_c(fixture)
    if rewrites != 2:
        raise NormalizeError(
            f"self-test expected 2 rewrites, observed {rewrites}"
        )
    if "BaseAddress + GUST_ARENA_OFFSET(idx)" not in normalized:
        raise NormalizeError("self-test did not normalize a simple index")
    if (
        "BaseAddress + GUST_ARENA_OFFSET((idx + other))"
        not in normalized
    ):
        raise NormalizeError("self-test did not normalize a compound index")
    if '"BaseAddress + idx"' not in normalized:
        raise NormalizeError("self-test changed a string literal")
    if "// BaseAddress + idx" not in normalized:
        raise NormalizeError("self-test changed a line comment")
    if "/* BaseAddress + idx */" not in normalized:
        raise NormalizeError("self-test changed a block comment")

    second, remaining = normalize_legacy_generated_c(normalized)
    if remaining != 0 or second != normalized:
        raise NormalizeError("normalization is not idempotent")


def _atomic_write(path: Path, contents: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.",
        suffix=".tmp",
        dir=path.parent,
        text=True,
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as handle:
            handle.write(contents)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("input", nargs="?")
    parser.add_argument("output", nargs="?")
    args = parser.parse_args()

    try:
        if args.self_test:
            if args.input is not None or args.output is not None:
                parser.error("--self-test does not accept paths")
            _self_test()
            print("legacy arena-offset normalizer self-test passed")
            return 0

        if args.input is None or args.output is None:
            parser.error("input and output paths are required")

        input_path = Path(args.input)
        output_path = Path(args.output)
        if input_path.resolve() == output_path.resolve():
            raise NormalizeError("input and output paths must differ")

        source = input_path.read_text(encoding="utf-8")
        normalized, rewrites = normalize_legacy_generated_c(source)
        if rewrites == 0:
            raise NormalizeError(
                "legacy-generated C contained no unsafe arena additions"
            )

        repeated, remaining = normalize_legacy_generated_c(normalized)
        if remaining != 0 or repeated != normalized:
            raise NormalizeError(
                "legacy-generated C normalization is not idempotent"
            )

        _atomic_write(output_path, normalized)
        print(
            "normalized "
            f"{rewrites} legacy generated arena pointer additions",
            file=sys.stderr,
        )
        return 0
    except (OSError, NormalizeError) as error:
        print(
            f"legacy arena-offset normalization failed: {error}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())