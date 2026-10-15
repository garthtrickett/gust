#!/usr/bin/env python3
"""Check decoded lexer bytes/spans and bounded scratch use on native output."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUT = ROOT / "build/guards/phase26_lexer_scratch_sizing"
RAW_INPUT_DIR = Path("build/guards/phase26_lexer_scratch_sizing_inputs")


def source_literal(value: str) -> str:
    return json.dumps(value, ensure_ascii=True)


def check(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def semantic_source() -> str:
    pieces = [
        (r'"a\n\t"', [97, 10, 9]),
        (r"'b\r'", [98, 13]),
        ('""', []),
        (r"'\q'", [113]),
        (r'"z\"y"', [122, 34, 121]),
    ]
    text = " ".join(piece for piece, _ in pieces)
    lines = [
        'import "lexer.gst" as lexer;',
        'import "token.gst" as token;',
        "func main() {",
        "    mut ctx := os.Arena.New();",
        "    defer ctx.Free();",
        "    mut l: lexer.Lexer[ctx];",
        f"    lexer.init_lexer(&l, {source_literal(text)});",
        "    mut t: token.Token[ctx];",
    ]
    offset = 0
    for case, (piece, decoded) in enumerate(pieces, 1):
        end = offset + len(piece)
        lines.append("    lexer.next_token(&l, &t);")
        lines.append(
            f"    if t.token_type.tag != 4 || len(t.literal) != {len(decoded)} ||"
        )
        lines.append(
            f"        t.span.start.offset != {offset} || t.span.end.offset != {end} ||"
        )
        lines.append(
            f"        t.span.start.line != 1 || t.span.end.line != 1 ||"
        )
        lines.append(
            f"        t.span.start.column != {offset + 1} ||"
            f" t.span.end.column != {end + 1} {{ os.Exit({case}); }}"
        )
        for idx, byte in enumerate(decoded):
            lines.append(
                f"    if std.str_byte_at(t.literal, {idx}) != {byte} {{"
                f" os.Exit({case + 10}); }}"
            )
        offset = end + 1
    lines += [
        "    lexer.next_token(&l, &t);",
        "    if t.token_type.tag != 0 { os.Exit(30); }",
        # Preserve the existing unterminated-literal and escaped-EOF behavior.
        f"    lexer.init_lexer(&l, {source_literal(chr(34) + 'abc')});",
        "    lexer.next_token(&l, &t);",
        "    if t.token_type.tag != 4 || len(t.literal) != 3 ||",
        "        std.str_byte_at(t.literal, 0) != 97 ||",
        "        std.str_byte_at(t.literal, 1) != 98 ||",
        "        std.str_byte_at(t.literal, 2) != 99 ||",
        "        t.span.start.offset != 0 || t.span.start.line != 1 ||",
        "        t.span.start.column != 1 || t.span.end.offset != 5 ||",
        "        t.span.end.line != 1 || t.span.end.column != 6 {",
        "        os.Exit(31);",
        "    }",
        "    lexer.next_token(&l, &t);",
        "    if t.token_type.tag != 0 || t.span.start.offset != 5 ||",
        "        t.span.end.offset != 5 || t.span.start.line != 1 ||",
        "        t.span.end.line != 1 || t.span.start.column != 6 ||",
        "        t.span.end.column != 6 { os.Exit(34); }",
        f"    lexer.init_lexer(&l, {source_literal(chr(34) + 'a' + chr(92))});",
        "    lexer.next_token(&l, &t);",
        "    if t.token_type.tag != 4 || len(t.literal) != 2 ||",
        "        t.span.start.offset != 0 || t.span.end.offset != 5 ||",
        "        t.span.start.line != 1 || t.span.end.line != 1 ||",
        "        t.span.start.column != 1 || t.span.end.column != 6 ||",
        "        std.str_byte_at(t.literal, 0) != 97 ||",
        "        std.str_byte_at(t.literal, 1) != 0 { os.Exit(32); }",
        "    lexer.next_token(&l, &t);",
        "    if t.token_type.tag != 0 || t.span.start.offset != 5 ||",
        "        t.span.end.offset != 5 || t.span.start.line != 1 ||",
        "        t.span.end.line != 1 || t.span.start.column != 6 ||",
        "        t.span.end.column != 6 { os.Exit(35); }",
        f"    lexer.init_lexer(&l, {source_literal(chr(34) + 'a' + chr(10) + 'b' + chr(34))});",
        "    lexer.next_token(&l, &t);",
        "    if t.token_type.tag != 4 || len(t.literal) != 3 ||",
        "        t.span.start.line != 1 || t.span.start.column != 1 ||",
        "        t.span.end.offset != 5 || t.span.end.line != 2 ||",
        "        t.span.end.column != 3 ||",
        "        std.str_byte_at(t.literal, 1) != 10 { os.Exit(33); }",
        '    os.LogStr("SUCCESS: lexer literal bytes and spans");',
        "}",
    ]
    return "\n".join(lines) + "\n"


def raw_byte_source() -> str:
    raw_path = str(RAW_INPUT_DIR / "unescaped_nul.bin")
    escaped_path = str(RAW_INPUT_DIR / "escaped_nul.bin")
    lines = [
        'import "lexer.gst" as lexer;',
        'import "token.gst" as token;',
        "func main() {",
        "    mut ctx := os.Arena.New();",
        "    defer ctx.Free();",
        "    mut l: lexer.Lexer[ctx];",
        "    mut t: token.Token[ctx];",
        f"    mut raw := os.ReadFile(ctx, {source_literal(raw_path)});",
        "    lexer.init_lexer(&l, raw);",
        "    lexer.next_token(&l, &t);",
        "    if t.token_type.tag != 4 || len(t.literal) != 1 ||",
        "        std.str_byte_at(t.literal, 0) != 97 ||",
        "        t.span.start.offset != 0 || t.span.start.column != 1 ||",
        "        t.span.end.offset != 3 || t.span.end.column != 4 ||",
        "        t.span.start.line != 1 || t.span.end.line != 1 {",
        "        os.Exit(51);",
        "    }",
        "    lexer.next_token(&l, &t);",
        "    if t.token_type.tag != 0 || t.span.start.offset != 3 ||",
        "        t.span.end.offset != 3 || t.span.start.column != 4 ||",
        "        t.span.end.column != 4 || t.span.start.line != 1 ||",
        "        t.span.end.line != 1 {",
        "        os.Exit(52);",
        "    }",
        f"    mut escaped := os.ReadFile(ctx, {source_literal(escaped_path)});",
        "    lexer.init_lexer(&l, escaped);",
        "    lexer.next_token(&l, &t);",
        "    if t.token_type.tag != 4 || len(t.literal) != 3 ||",
        "        std.str_byte_at(t.literal, 0) != 97 ||",
        "        std.str_byte_at(t.literal, 1) != 0 ||",
        "        std.str_byte_at(t.literal, 2) != 98 ||",
        "        t.span.start.offset != 0 || t.span.start.column != 1 ||",
        "        t.span.end.offset != 6 || t.span.end.column != 7 ||",
        "        t.span.start.line != 1 || t.span.end.line != 1 {",
        "        os.Exit(53);",
        "    }",
        "    lexer.next_token(&l, &t);",
        "    if t.token_type.tag != 0 || t.span.start.offset != 6 ||",
        "        t.span.end.offset != 6 || t.span.start.column != 7 ||",
        "        t.span.end.column != 7 || t.span.start.line != 1 ||",
        "        t.span.end.line != 1 {",
        "        os.Exit(54);",
        "    }",
        '    os.LogStr("SUCCESS: lexer raw NUL and EOF spans");',
        "}",
    ]
    return "\n".join(lines) + "\n"


def stress_source() -> str:
    count = 70
    text = '"a" ' * count + "//" + "x" * 2048
    lines = [
        'import "lexer.gst" as lexer;',
        'import "token.gst" as token;',
        "func main() {",
        "    mut ctx := os.Arena.New();",
        "    defer ctx.Free();",
        "    mut l: lexer.Lexer[ctx];",
        f"    lexer.init_lexer(&l, {source_literal(text)});",
        "    mut t: token.Token[ctx];",
        "    mut i := 0;",
        f"    while i < {count} {{",
        "        lexer.next_token(&l, &t);",
        "        if t.token_type.tag != 4 || len(t.literal) != 1 ||",
        "            std.str_byte_at(t.literal, 0) != 97 ||",
        "            t.span.start.offset != i * 4 ||",
        "            t.span.end.offset != i * 4 + 3 { os.Exit(41); }",
        "        i = i + 1;",
        "    }",
        "    lexer.next_token(&l, &t);",
        "    if t.token_type.tag != 0 { os.Exit(42); }",
        '    os.LogStr("SUCCESS: short literals before long tail");',
        "}",
    ]
    return "\n".join(lines) + "\n"


def run_case(compiler: Path, out: Path, src_dir: Path, name: str, source: str,
             expected: str, expect_exhaustion: bool = False) -> dict:
    source_path = src_dir / f"{name}.gst"
    source_path.write_text(source)
    binary = out / name
    compile_result = subprocess.run(
        [str(compiler), "--backend", "cranelift", "-o",
         str(binary), str(source_path)],
        cwd=ROOT, capture_output=True, text=True, timeout=180,
    )
    check(compile_result.returncode == 0, f"{name} compile exit "
          f"{compile_result.returncode}: {compile_result.stdout} "
          f"{compile_result.stderr}")
    check(not compile_result.stdout and not compile_result.stderr,
          f"{name} compile streams were not empty")
    check(binary.is_file(), f"{name} compiler produced no binary")
    run_result = subprocess.run(
        [str(binary)], cwd=ROOT, capture_output=True, text=True, timeout=30,
    )
    if expect_exhaustion:
        check(run_result.returncode == 1 and not run_result.stdout and
              run_result.stderr.startswith(
                  "Out of thread-local scratch memory! Size requested: "),
              f"{name} baseline exhaustion mismatch: "
              f"{run_result.returncode} {run_result.stdout!r} "
              f"{run_result.stderr!r}")
    else:
        check(run_result.returncode == 0, f"{name} run exit "
              f"{run_result.returncode}: {run_result.stdout} "
              f"{run_result.stderr}")
        check(run_result.stdout == expected and not run_result.stderr,
              f"{name} output mismatch: {run_result.stdout!r}, "
              f"{run_result.stderr!r}")
    return {
        "source_sha256": hashlib.sha256(source_path.read_bytes()).hexdigest(),
        "binary_sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
        "compile_exit": compile_result.returncode,
        "run_exit": run_result.returncode,
        "stdout": run_result.stdout,
        "stderr": run_result.stderr,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", default="./gust_bootstrap")
    parser.add_argument("--lexer", default="compiler/lexer.gst")
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--expect-stress-exhaustion", action="store_true")
    args = parser.parse_args()
    compiler = (ROOT / args.compiler).resolve()
    lexer = (ROOT / args.lexer).resolve()
    out = (ROOT / args.out).resolve()
    check(compiler.is_file(), f"compiler unavailable: {compiler}")
    check(lexer.is_file(), f"lexer unavailable: {lexer}")
    out.mkdir(parents=True, exist_ok=True)
    src_dir = out / "src"
    src_dir.mkdir(exist_ok=True)
    shutil.copyfile(lexer, src_dir / "lexer.gst")
    shutil.copyfile(ROOT / "compiler/token.gst", src_dir / "token.gst")
    raw_input_dir = ROOT / RAW_INPUT_DIR
    raw_input_dir.mkdir(parents=True, exist_ok=True)
    raw_inputs = {
        "unescaped_nul.bin": b'"a\x00',
        "escaped_nul.bin": b'"a\\\x00b"',
    }
    for name, payload in raw_inputs.items():
        (raw_input_dir / name).write_bytes(payload)
    results = {
        "compiler_sha256": hashlib.sha256(compiler.read_bytes()).hexdigest(),
        "lexer_sha256": hashlib.sha256(
            (src_dir / "lexer.gst").read_bytes()).hexdigest(),
        "raw_input_sha256": {
            name: hashlib.sha256(payload).hexdigest()
            for name, payload in raw_inputs.items()
        },
        "semantic": run_case(
            compiler, out, src_dir, "semantic", semantic_source(),
            "SUCCESS: lexer literal bytes and spans\n"),
        "raw_bytes": run_case(
            compiler, out, src_dir, "raw_bytes", raw_byte_source(),
            "SUCCESS: lexer raw NUL and EOF spans\n"),
        "stress": run_case(
            compiler, out, src_dir, "stress", stress_source(),
            "SUCCESS: short literals before long tail\n",
            args.expect_stress_exhaustion),
    }
    (out / "manifest.json").write_text(
        json.dumps(results, indent=2, sort_keys=True) + "\n")
    print("Phase26 lexer sizing semantic and bounded stress classified.")


if __name__ == "__main__":
    main()
