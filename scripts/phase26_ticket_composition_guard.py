#!/usr/bin/env python3
"""Generic closed ticket composition under the unchanged production profile."""
from pathlib import Path
import argparse
import re
import phase26_ticket_publication_guard as ticket

ROOT = ticket.ROOT
SOURCE = ROOT / "tests/cranelift/phase26_ticket_composition.gst"
FIXTURE = ROOT / "compiler/experiments/cranelift/src/testdata/scoped_ticket_composition_producer.canonical"


def single(template):
    entry = ticket.SOURCE.read_text().split("\nfunc main()", 1)[1]
    return template.split("\nfunc main()", 1)[0] + "\nfunc main()" + entry


def cases(template):
    yield "source", template, 154
    prefix, nested = template.split("            match roundtrip {", 1)
    shadowed = prefix + "            match roundtrip {" + re.sub(
        r"\b(decoded|original)\b", lambda m: {"decoded": "copied", "original": "bytes"}[m[0]], nested)
    yield "lexical_shadow", shadowed, 154
    names = {"CopyOutcome": "Choice", "Completed": "Present", "Rejected": "Absent",
             "copy_bytes": "encode", "restore_bytes": "decode", "pool": "owner",
             "destination": "caller", "classify_failure": "classify"}
    renamed = re.sub(r"\b(" + "|".join(names) + r")\b", lambda m: names[m[0]], template)
    yield "renamed", renamed, 154
    yield "single_with_unused_producer", single(template), 10
    yield "short_second_output", template.replace(
        "restore_bytes(&destination, bytes, 2, 6)", "restore_bytes(&destination, bytes, 1, 6)"), 253
    yield "pure_error_arithmetic", template.replace(
        "result.Rejected.number = 0 - 5;", "result.Rejected.number = number - number - 5;"), 154
    # Exercise pure construction on a deterministic adapter failure, keeping
    # this generic probe on the production static-link path. This deliberately
    # maps that error to -5; it does not select the Stdlib error policy.
    classified = template.replace(
        "if produced < 0 { return reject_copy(pool, produced); }",
        "if produced < 0 { return classify_failure(pool, produced); }")
    yield "normalization_constructor", classified.replace(
        "copy_bytes(&destination, &input, 64, 6)", "copy_bytes(&destination, &input, 64, 10)"), 251
    scalar = "return 100 + len(original) * 10 + (original[0] as int) * 10 + (original[1] as int);"
    triple = """mut again := copy_bytes(&destination, original, 64, 6);
                    match again {
                        Completed { handle } => {
                            mut copied := *handle;
                            mut bytes := destination.get_ref(copied);
                            return 100 + len(bytes);
                        }
                        Rejected { number } => { return *number; }
                    }"""
    assert template.count(scalar) == 1
    yield "three_calls", template.replace(scalar, triple), 110


def rejections(template, imported=False):
    for name, source, expected in ticket.rejections(template, imported):
        if name == "unregistered_imported_adapter":
            # The second, registered adapter selects the package even though
            # this first adapter is unknown. Both admission routes must reject;
            # the predecessor's one-adapter expectation remains unchanged.
            yield "unregistered_adapter_with_registered_sibling", source, \
                "approved native package rejected: byte-span Call is outside selected package"
        else:
            yield name, source, expected
    yield "effect_after_borrow", template.replace(
        "            mut roundtrip :=", "            input.Push(9 as byte);\n            mut roundtrip :="), \
        "ticket success use has extra effects"
    yield "alias_after_borrow", template.replace(
        "            mut roundtrip :=", "            mut alias := bytes;\n            mut roundtrip :="), \
        "ticket success use has extra effects"
    yield "effectful_error_payload", template.replace(
        "result.Rejected.number = 0 - 5;", "result.Rejected.number = scalar_identity(number);").replace(
            "\nfunc main()", "\nfunc scalar_identity(number: int) int { return number; }\n\nfunc main()"), \
        "ticket constructor publishes another value or variant"
    yield "substituted_acquisition_status", template.replace(
        "classify_failure(pool, status)", "classify_failure(pool, 0 - 2)"), \
        "scoped failed Guard has an effectful or unrelated return"
    dead = ticket.SOURCE.read_text().split("\nfunc main()", 1)[1]
    yield "disconnected_caller", single(template) + "\nfunc disconnected()" + dead, \
        "collection scoped call is outside the entry graph"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", type=Path,
        default=ROOT / "build/guards/phase26_production_trust/candidate/package")
    parser.add_argument("--imported", action="store_true")
    args = parser.parse_args()
    scratch = ROOT / ("build/guards/phase26_ticket_composition_imported" if args.imported
                      else "build/guards/phase26_ticket_composition")
    ticket.qualify(args.package, args.imported, template_path=SOURCE,
        canonical_fixture=FIXTURE, scratch=scratch, positives=cases, negative_cases=rejections)


if __name__ == "__main__":
    main()
