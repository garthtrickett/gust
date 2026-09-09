#!/usr/bin/env python3
"""Exercise the closed-phase branches using in-memory roadmap mutations.

Never edit or restore the worktree: a failed inversion must leave caller edits
alone. Positive closed control first, so early pending-patch rejection cannot
masquerade as coverage of the CR or Historical Full checks.
"""

from pathlib import Path
import re
import unittest

from stdlib_s1_close import validate_historical, validate_roadmap


class ClosureTests(unittest.TestCase):
    def setUp(self):
        text = (Path(__file__).resolve().parent.parent / "TASK_STDLIB.md").read_text()
        text = re.sub(r"^- \[ \] (Patch S1\.[0-9]+ — .+)$", r"- [x] \1 — DONE", text, flags=re.M)
        text = re.sub(r"^\| S1\.[0-9]+ [^\n]+\n", "", text, flags=re.M)
        text = text.replace("| BLOCKING |", "| RESOLVED |")
        heading = "### Level 3 evidence\n"
        start = text.index(heading)
        end_match = re.search(r"^#{1,3} ", text[start + len(heading):], re.M)
        end = start + len(heading) + end_match.start() if end_match else len(text)
        self.row = "| Cranelift Historical Full | 12345 | " + "a" * 40 + " | completed | success |\n"
        self.closed = text[:start] + heading + "\n" + self.row + text[end:]
        self.citation = ("12345", "a" * 40)
        self.run = dict(id=12345, head_sha="a" * 40, head_branch="main",
                        path=".github/workflows/cranelift-historical-full.yml",
                        status="completed", conclusion="success")
        self.assertEqual(validate_roadmap(self.closed), (set(), self.citation))

    def test_closed_positive(self):
        validate_historical(self.citation, self.run)

    def test_missing_and_duplicate_requests(self):
        for number in (1, 16, 19, 21):
            line = re.search(rf"^\| CR-{number} \| .+$", self.closed, re.M)[0]
            for changed in (self.closed.replace(line, ""), self.closed.replace(line, line + "\n" + line)):
                with self.subTest(number=number), self.assertRaisesRegex(ValueError, "Every CR section"):
                    validate_roadmap(changed)

    def test_new_request_requires_disposition(self):
        with self.assertRaisesRegex(ValueError, "Every CR section"):
            validate_roadmap(self.closed + "\n### CR-22 — New request\n")

    def test_request_cannot_borrow_neighbor_owner(self):
        changed = self.closed.replace("| CR-16 | RESOLVED | Cranelift registration / Stdlib witness |",
                                      "| CR-16 | RESOLVED | unowned |")
        with self.assertRaisesRegex(ValueError, "CR-16 needs an owner"):
            validate_roadmap(changed)

    def test_blocking_request(self):
        changed = self.closed.replace("| CR-19 | RESOLVED |", "| CR-19 | BLOCKING |")
        with self.assertRaisesRegex(ValueError, "CR-19 blocks"):
            validate_roadmap(changed)

    def test_pending_patch(self):
        changed = re.sub(r"^- \[x\] (Patch S1\.11 — .+) — DONE$", r"- [ ] \1", self.closed, flags=re.M)
        with self.assertRaisesRegex(ValueError, "another patch is pending"):
            validate_roadmap(changed)

    def test_inadequate_citations(self):
        for replacement in ("", self.row.replace("success", "failure"),
                            self.row.replace("completed", "queued"),
                            self.row.replace("12345", "unknown"), self.row * 2):
            with self.subTest(row=replacement), self.assertRaisesRegex(ValueError, "paired Level 3"):
                validate_roadmap(self.closed.replace(self.row, replacement))

    def test_wrong_live_run(self):
        for key, value in (("id", 67890), ("head_sha", "b" * 40),
                           ("status", "queued"), ("conclusion", "failure"),
                           ("head_branch", "codex/unrelated"),
                           ("path", ".github/workflows/pr-fast.yml")):
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate_historical(self.citation, {**self.run, key: value})


if __name__ == "__main__":
    unittest.main()
