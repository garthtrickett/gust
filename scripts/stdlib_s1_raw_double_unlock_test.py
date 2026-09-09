#!/usr/bin/env python3
"""Inversions for the compile-only CR-16 emitted-cleanup check."""

import unittest

from stdlib_s1_raw_double_unlock import validate


VALID = """
void module_release_mutex_guard(Guard owner);
void module_release_mutex_guard(Guard owner) {
    std_Mutex_Unlock_impl(owner.mutex->lock_state);
}
int gust_user_main_impl(void* arg) {
    Guard owner = module_lock(&mutex);
    std_Mutex_Unlock_impl(mutex.lock_state);
    module_release_mutex_guard(owner);
    return 0;
    module_release_mutex_guard(owner);
}
"""


class CleanupTests(unittest.TestCase):
    def test_positive_with_unreachable_cleanup_suffix(self):
        validate(VALID)

    def test_missing_raw_call_not_supplied_by_destructor(self):
        with self.assertRaisesRegex(ValueError, "Entry must retain"):
            validate(VALID.replace("    std_Mutex_Unlock_impl(mutex.lock_state);\n", ""))

    def test_missing_cleanup_not_supplied_by_unreachable_suffix(self):
        with self.assertRaisesRegex(ValueError, "Entry must retain"):
            validate(VALID.replace("    module_release_mutex_guard(owner);\n", "", 1))

    def test_empty_destructor(self):
        with self.assertRaisesRegex(ValueError, "cleanup must itself unlock"):
            validate(VALID.replace("    std_Mutex_Unlock_impl(owner.mutex->lock_state);\n", ""))

    def test_reverse_order(self):
        with self.assertRaisesRegex(ValueError, "must precede"):
            validate(VALID.replace("    std_Mutex_Unlock_impl(mutex.lock_state);\n"
                                   "    module_release_mutex_guard(owner);",
                                   "    module_release_mutex_guard(owner);\n"
                                   "    std_Mutex_Unlock_impl(mutex.lock_state);"))


if __name__ == "__main__":
    unittest.main()
