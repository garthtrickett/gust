"""Pure captured-output counterexamples; no compiler or user program is run."""
import unittest
from stdlib_s1_mutex_guard_scope_refusal import validate

CLEAN = (
    b"TypeError in original.gst: Semantic Error: [LinearResourceLeak] "
    b"Deferred allocator Free executes before dependent cleanup or invalidates "
    b"a returned owner\n"
)


class FrontendRefusalTests(unittest.TestCase):
    def test_exact_frontend_refusal_is_accepted(self):
        validate(1, CLEAN, b"", False, False)

    def test_mixed_cleanup_stdout_and_backend_stderr_is_rejected(self):
        # The V2 combined-stream substring check would accept this counterexample.
        with self.assertRaises(ValueError):
            validate(1, CLEAN, b"handshake process failed\n", False, False)

    def test_worker_reached_refusal_in_stdout_is_rejected(self):
        for marker in (b"driver_handshake", b"handshake process failed",
                       b"gust_native_capability_decision"):
            with self.subTest(marker=marker), self.assertRaises(ValueError):
                validate(1, CLEAN + marker + b"\n", b"", False, False)

    def test_even_blank_stderr_is_rejected(self):
        with self.assertRaises(ValueError):
            validate(1, CLEAN, b"\n", False, False)

    def test_diagnostic_on_stderr_is_not_a_frontend_control(self):
        with self.assertRaises(ValueError):
            validate(1, b"", CLEAN, False, False)

    def test_other_exit_status_is_rejected(self):
        for status in (0, 2, 124, 137):
            with self.subTest(status=status), self.assertRaises(ValueError):
                validate(status, CLEAN, b"", False, False)

    def test_missing_or_different_cleanup_reason_is_rejected(self):
        for stdout in (b"", b"[LinearResourceLeak] another failure\n"):
            with self.subTest(stdout=stdout), self.assertRaises(ValueError):
                validate(1, stdout, b"", False, False)

    def test_output_and_dangling_symlink_are_rejected(self):
        for exists, symlink in ((True, False), (False, True), (True, True)):
            with self.subTest(exists=exists, symlink=symlink), self.assertRaises(ValueError):
                validate(1, CLEAN, b"", exists, symlink)


if __name__ == "__main__":
    unittest.main()
