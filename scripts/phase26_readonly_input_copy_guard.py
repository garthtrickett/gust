#!/usr/bin/env python3
"""Qualify input-only collection copies using the pinned production profile."""
from pathlib import Path
import argparse
import re
import phase26_ticket_composition_guard as composition
import phase26_ticket_publication_guard as ticket

ROOT = ticket.ROOT
SOURCE = ROOT / "tests/cranelift/phase26_readonly_input_copy.gst"
FIXTURE = ROOT / "compiler/experiments/cranelift/src/testdata/scoped_readonly_input_copy_producer.canonical"
COPY = "    mut source_copy := input;"
CALL = "    mut result := copy_bytes(&destination, &source_copy, 64, 6);"


def cases(template):
    assert template.count(COPY) == template.count(CALL) == 1
    yield "source", template, 154
    names = {"source_copy": "borrowed_copy", "input": "original_value",
             "destination": "owner", "copy_bytes": "encode_bytes",
             "restore_bytes": "decode_bytes"}
    yield "renamed", re.sub(r"\b(" + "|".join(names) + r")\b",
        lambda match: names[match[0]], template), 154
    yield "typed_copy", template.replace(COPY,
        "    mut source_copy: std.Vector[byte, destination] := input;"), 154
    chain = template.replace(CALL,
        "    mut next_copy := source_copy;\n" + CALL.replace("&source_copy", "&next_copy"))
    yield "copy_chain", chain, 154
    # The original header grows past its initial capacity. The earlier copied
    # header must still read its own initialized prefix in nonmoving storage.
    growth = "\n".join(f"    input.Push({value} as byte);" for value in range(5, 12))
    yield "original_reallocates", template.replace(COPY, COPY + "\n" + growth), 154
    yield "chain_original_reallocates", chain.replace(COPY, COPY + "\n" + growth), 154
    empty = template.replace("    input.Push(3 as byte);\n    input.Push(4 as byte);", "")
    scalar = "return 100 + len(original) * 10 + (original[0] as int) * 10 + (original[1] as int);"
    assert empty.count(scalar) == 1
    yield "empty_copy", empty.replace(scalar, "return 100 + len(original);"), 100
    distinct = template.replace("input: &std.Vector[byte, pool]",
                                "input: &std.Vector[byte, input_ctx]")
    declaration = "    mut input: std.Vector[byte, destination] := std.VectorNew(&destination);"
    assert distinct.count(declaration) == 1
    distinct = distinct.replace(declaration,
        "    mut source_arena := os.Arena.New();\n    defer source_arena.Free();\n"
        "    mut input: std.Vector[byte, source_arena] := std.VectorNew(&source_arena);")
    yield "distinct_arenas", distinct, 154


def rejections(template, imported=False):
    for name, source, diagnostic in composition.rejections(template, imported):
        assert source != template, f"negative mechanism did not move: {name}"
        yield name, source, diagnostic
    for name, effect in [("copied_append", "source_copy.Push(9 as byte);"),
                         ("copied_clear", "source_copy.Clear();")]:
        yield name, template.replace(COPY, COPY + "\n    " + effect), \
            "collection caller local has an unproved initializer"
    yield "chain_append", template.replace(CALL,
        "    mut next_copy := source_copy;\n    next_copy.Push(9 as byte);\n" +
        CALL.replace("&source_copy", "&next_copy")), \
        "collection caller local has an unproved initializer"
    yield "copied_metadata_write", template.replace(COPY,
        COPY + "\n    unsafe { source_copy.len = 3; }"), \
        "collection caller has unsupported control or aliasing"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", type=Path,
        default=ROOT / "build/guards/phase26_production_trust/candidate/package")
    parser.add_argument("--imported", action="store_true")
    args = parser.parse_args()
    scratch = ROOT / ("build/guards/phase26_readonly_input_copy_imported" if args.imported
                      else "build/guards/phase26_readonly_input_copy")
    ticket.qualify(args.package, args.imported, template_path=SOURCE,
        canonical_fixture=FIXTURE, scratch=scratch, positives=cases, negative_cases=rejections)


if __name__ == "__main__":
    main()
