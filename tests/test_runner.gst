type Test struct {
    path: str,
    is_negative: int,
    expected: str
}

func run_test(ctx: &Arena, t: Test) int {
    mut path := t.path;
    mut is_neg := t.is_negative;
    mut exp := t.expected;
    mut status := 0;

    os.System("mkdir -p build");

    if is_neg == 1 {
        mut cmd := std.Concat("./gust ", path);
        cmd = std.Concat(cmd, " > build/test_temp.log 2>&1");
        status = os.System(cmd);

        if status == 0 {
            mut msg := std.Format("❌ FAIL: %s (Expected compilation failure, but it succeeded)", path);
            os.LogStr(msg);
            return 0;
        }

        mut log_content := os.ReadFile(ctx, "build/test_temp.log");
        mut found_err := std.str_find(log_content, exp);
        if found_err == 0 - 1 {
            mut msg := std.Format("❌ FAIL: %s (Compilation failed as expected, but could not find expected error substring '%s')", path, exp);
            os.LogStr(msg);
            return 0;
        }

        mut msg := std.Format("✅ PASS: %s (Compilation failed with expected error: '%s')", path, exp);
        os.LogStr(msg);
        return 1;
    } else {
        if std.str_find(path, "e2e_fallible_guard_bootstrap") != 0 - 1 {
            os.System("mkdir -p temp_e2e_guard_test_dir/nested && echo 'func main() {}' > temp_e2e_guard_test_dir/nested/file1.gst");
        }
        if std.str_find(path, "e2e_filesystem_ops") != 0 - 1 {
            os.System("mkdir -p temp_e2e_filesystem_dir && echo 'func main() {}' > temp_e2e_filesystem_dir/file1.gst && echo 'plain text' > temp_e2e_filesystem_dir/file2.txt");
        }

        mut cmd_comp := std.Concat("./gust ", path);
        cmd_comp = std.Concat(cmd_comp, " > build/test_temp.log 2>&1");
        status = os.System(cmd_comp);

        if status != 0 {
            mut msg := std.Format("❌ FAIL: %s (Compilation failed! See build/test_temp.log for errors)", path);
            os.LogStr(msg);
            return 0;
        }

        mut comp_output := os.ReadFile(ctx, "build/test_temp.log");
        mut lines := std.str_split(comp_output, "\n", ctx);
        mut clean_c := "";
        mut idx := 0;
        while idx < len(lines) {
            mut line := lines[idx];
            mut should_keep := 1;
            if len(line) > 0 {
                mut b := std.str_byte_at(line, 0);
                if b == 226 || b == 240 || b == 243 {
                    should_keep = 0;
                }
            }
            if should_keep == 1 {
                clean_c = std.Concat(clean_c, line);
                clean_c = std.Concat(clean_c, "\n");
            }
            idx = idx + 1;
        }

        os.WriteFile("build/test_temp_clean.c", clean_c);

        mut compile_c_cmd := "cc -O2 -Wall -pthread -Isrc src/runtime.c build/test_temp_clean.c -o build/test_temp_bin > build/test_c_comp.log 2>&1";
        status = os.System(compile_c_cmd);
        if status != 0 {
            mut msg := std.Format("❌ FAIL: %s (Native C compilation failed! See build/test_c_comp.log for errors)", path);
            os.LogStr(msg);
            return 0;
        }

        status = os.System("./build/test_temp_bin > build/test_run.log 2>&1");
        if status != 0 {
            mut msg := std.Format("❌ FAIL: %s (Execution crashed/failed! See build/test_run.log for errors)", path);
            os.LogStr(msg);
            return 0;
        }

        mut actual_output := os.ReadFile(ctx, "build/test_run.log");
        actual_output = std.str_trim(actual_output);
        mut trimmed_expected := std.str_trim(exp);

        if std.str_eq(actual_output, trimmed_expected) == 0 {
            mut msg := std.Format("❌ FAIL: %s (Output mismatch!)", path);
            os.LogStr(msg);
            os.LogStr("--- EXPECTED ---");
            os.LogStr(trimmed_expected);
            os.LogStr("--- ACTUAL ---");
            os.LogStr(actual_output);
            return 0;
        }

        if std.str_find(path, "e2e_fallible_guard_bootstrap") != 0 - 1 {
            os.System("rm -rf temp_e2e_guard_test_dir");
        }
        if std.str_find(path, "e2e_filesystem_ops") != 0 - 1 {
            os.System("rm -rf temp_e2e_filesystem_dir temp_e2e_filesystem_test.txt");
        }

        mut msg := std.Format("✅ PASS: %s (Compiled and ran successfully with expected output)", path);
        os.LogStr(msg);
        return 1;
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut tests: std.Vector[Test, ctx] := std.VectorNew(ctx);

    mut t1: Test;
    t1.path = "tests/e2e_collections_methods.gst";
    t1.is_negative = 0;
    t1.expected = "3\n30\n30\n2\n0\n2\n100\n200\n0\n2\napple\nbanana\n1\n0";
    tests.Push(t1);

    mut t2: Test;
    t2.path = "tests/e2e_definite_check_compound.gst";
    t2.is_negative = 0;
    t2.expected = "1337";
    tests.Push(t2);

    mut t3: Test;
    t3.path = "tests/e2e_fallible_guard_bootstrap.gst";
    t3.is_negative = 0;
    t3.expected = "42\n42\nfile1.gst";
    tests.Push(t3);

    mut t4: Test;
    t4.path = "tests/e2e_filesystem_ops.gst";
    t4.is_negative = 0;
    t4.expected = "1\nHello from self-hosted Gust compiler File System E2E!\n0\n../c\nfile1.gst";
    tests.Push(t4);

    mut t5: Test;
    t5.path = "tests/e2e_formatting_utilities.gst";
    t5.is_negative = 0;
    t5.expected = "Loop Num: 0 - ok\nLoop Num: 1 - ok\nLoop Num: 2 - ok\n42\nroot_node\n42\nroot_node";
    tests.Push(t5);

    mut t6: Test;
    t6.path = "tests/e2e_os_system.gst";
    t6.is_negative = 0;
    t6.expected = "FFI_SUBPROCESS_OK\n0";
    tests.Push(t6);

    mut t7: Test;
    t7.path = "tests/e2e_spawn_yield.gst";
    t7.is_negative = 0;
    t7.expected = "30";
    tests.Push(t7);

    mut t8: Test;
    t8.path = "tests/e2e_sync_primitives.gst";
    t8.is_negative = 0;
    t8.expected = "10";
    tests.Push(t8);

    mut t9: Test;
    t9.path = "tests/test_deref_non_pointer_rejected.gst";
    t9.is_negative = 1;
    t9.expected = "DereferenceNonPointer";
    tests.Push(t9);

    mut t10: Test;
    t10.path = "tests/test_unresolved_selector_rejected.gst";
    t10.is_negative = 1;
    t10.expected = "UnresolvedSelector";
    tests.Push(t10);

    mut t11: Test;
    t11.path = "tests/test_bool_wrapper_mismatch_rejected.gst";
    t11.is_negative = 1;
    t11.expected = "TypeMismatch";
    tests.Push(t11);

    mut t12: Test;
    t12.path = "tests/test_rc_leak_violation.gst";
    t12.is_negative = 1;
    t12.expected = "leak";
    tests.Push(t12);

    mut t13: Test;
    t13.path = "compiler/test_directory_leak_violation.gst";
    t13.is_negative = 1;
    t13.expected = "must be cleanly closed";
    tests.Push(t13);

    mut t14: Test;
    t14.path = "compiler/test_escape_return_violation.gst";
    t14.is_negative = 1;
    t14.expected = "Escape analysis violation";
    tests.Push(t14);

    mut t15: Test;
    t15.path = "compiler/test_scratch_storage_violation.gst";
    t15.is_negative = 1;
    t15.expected = "Cannot assign scratchpad-allocated view";
    tests.Push(t15);

    os.LogStr("🏃 Starting self-hosted Gust test suite...");
    mut passed_count := 0;
    mut failed_count := 0;

    mut i := 0;
    while i < len(tests) {
        mut t := tests[i];
        mut ok := run_test(ctx, t);
        if ok == 1 {
            passed_count = passed_count + 1;
        } else {
            failed_count = failed_count + 1;
        }
        os.ScratchReset();
        i = i + 1;
    }

    os.LogStr("-----------------------------------------");
    mut summary_msg := std.Format("🏁 Test Suite Finished. Passed: %d, Failed: %d", passed_count, failed_count);
    os.LogStr(summary_msg);

    os.System("rm -rf build/test_temp.log build/test_temp.c build/test_temp_clean.c build/test_temp_bin build/test_c_comp.log build/test_run.log");

    if failed_count > 0 {
        os.Exit(1);
    } else {
        os.Exit(0);
    }
}
type Test[ctx] struct {
    path: str,
    is_negative: int,
    expected: str
}

func run_test(ctx: &Arena, t: Test[ctx]) int {
    mut path := t.path;
    mut is_neg := t.is_negative;
    mut exp := t.expected;
    mut status := 0;

    os.System("mkdir -p build");

    if is_neg == 1 {
        mut cmd := std.Concat("./gust ", path);
        cmd = std.Concat(cmd, " > build/test_temp.log 2>&1");
        status = os.System(cmd);

        if status == 0 {
            mut msg := std.Format("❌ FAIL: %s (Expected compilation failure, but it succeeded)", path);
            os.LogStr(msg);
            return 0;
        }

        mut log_content := os.ReadFile(ctx, "build/test_temp.log");
        mut found_err := std.str_find(log_content, exp);
        if found_err == 0 - 1 {
            mut msg := std.Format("❌ FAIL: %s (Compilation failed as expected, but could not find expected error substring '%s')", path, exp);
            os.LogStr(msg);
            return 0;
        }

        mut msg := std.Format("✅ PASS: %s (Compilation failed with expected error: '%s')", path, exp);
        os.LogStr(msg);
        return 1;
    } else {
        if std.str_find(path, "e2e_fallible_guard_bootstrap") != 0 - 1 {
            os.System("mkdir -p temp_e2e_guard_test_dir/nested && echo 'func main() {}' > temp_e2e_guard_test_dir/nested/file1.gst");
        }
        if std.str_find(path, "e2e_filesystem_ops") != 0 - 1 {
            os.System("mkdir -p temp_e2e_filesystem_dir && echo 'func main() {}' > temp_e2e_filesystem_dir/file1.gst && echo 'plain text' > temp_e2e_filesystem_dir/file2.txt");
        }

        mut cmd_comp := std.Concat("./gust ", path);
        cmd_comp = std.Concat(cmd_comp, " > build/test_temp.log 2>&1");
        status = os.System(cmd_comp);

        if status != 0 {
            mut msg := std.Format("❌ FAIL: %s (Compilation failed! See build/test_temp.log for errors)", path);
            os.LogStr(msg);
            return 0;
        }

        mut comp_output := os.ReadFile(ctx, "build/test_temp.log");
        mut lines := std.str_split(comp_output, "\n", ctx);
        mut clean_c := "";
        mut idx := 0;
        while idx < len(lines) {
            mut line := lines[idx];
            mut should_keep := 1;
            if len(line) > 0 {
                mut b := std.str_byte_at(line, 0);
                if b == 226 || b == 240 || b == 243 {
                    should_keep = 0;
                }
            }
            if should_keep == 1 {
                clean_c = std.Concat(clean_c, line);
                clean_c = std.Concat(clean_c, "\n");
            }
            idx = idx + 1;
        }

        os.WriteFile("build/test_temp_clean.c", clean_c);

        mut compile_c_cmd := "cc -O2 -Wall -pthread -Isrc src/runtime.c build/test_temp_clean.c -o build/test_temp_bin > build/test_c_comp.log 2>&1";
        status = os.System(compile_c_cmd);
        if status != 0 {
            mut msg := std.Format("❌ FAIL: %s (Native C compilation failed! See build/test_c_comp.log for errors)", path);
            os.LogStr(msg);
            return 0;
        }

        status = os.System("./build/test_temp_bin > build/test_run.log 2>&1");
        if status != 0 {
            mut msg := std.Format("❌ FAIL: %s (Execution crashed/failed! See build/test_run.log for errors)", path);
            os.LogStr(msg);
            return 0;
        }

        mut actual_output := os.ReadFile(ctx, "build/test_run.log");
        actual_output = std.str_trim(actual_output);
        mut trimmed_expected := std.str_trim(exp);

        if std.str_eq(actual_output, trimmed_expected) == 0 {
            mut msg := std.Format("❌ FAIL: %s (Output mismatch!)", path);
            os.LogStr(msg);
            os.LogStr("--- EXPECTED ---");
            os.LogStr(trimmed_expected);
            os.LogStr("--- ACTUAL ---");
            os.LogStr(actual_output);
            return 0;
        }

        if std.str_find(path, "e2e_fallible_guard_bootstrap") != 0 - 1 {
            os.System("rm -rf temp_e2e_guard_test_dir");
        }
        if std.str_find(path, "e2e_filesystem_ops") != 0 - 1 {
            os.System("rm -rf temp_e2e_filesystem_dir temp_e2e_filesystem_test.txt");
        }

        mut msg := std.Format("✅ PASS: %s (Compiled and ran successfully with expected output)", path);
        os.LogStr(msg);
        return 1;
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut tests: std.Vector[Test[ctx], ctx] := std.VectorNew(ctx);

    mut t1: Test[ctx];
    t1.path = "tests/e2e_collections_methods.gst";
    t1.is_negative = 0;
    t1.expected = "3\n30\n30\n2\n0\n2\n100\n200\n0\n2\napple\nbanana\n1\n0";
    tests.Push(t1);

    mut t2: Test[ctx];
    t2.path = "tests/e2e_definite_check_compound.gst";
    t2.is_negative = 0;
    t2.expected = "1337";
    tests.Push(t2);

    mut t3: Test[ctx];
    t3.path = "tests/e2e_fallible_guard_bootstrap.gst";
    t3.is_negative = 0;
    t3.expected = "42\n42\nfile1.gst";
    tests.Push(t3);

    mut t4: Test[ctx];
    t4.path = "tests/e2e_filesystem_ops.gst";
    t4.is_negative = 0;
    t4.expected = "1\nHello from self-hosted Gust compiler File System E2E!\n0\n../c\nfile1.gst";
    tests.Push(t4);

    mut t5: Test[ctx];
    t5.path = "tests/e2e_formatting_utilities.gst";
    t5.is_negative = 0;
    t5.expected = "Loop Num: 0 - ok\nLoop Num: 1 - ok\nLoop Num: 2 - ok\n42\nroot_node\n42\nroot_node";
    tests.Push(t5);

    mut t6: Test[ctx];
    t6.path = "tests/e2e_os_system.gst";
    t6.is_negative = 0;
    t6.expected = "FFI_SUBPROCESS_OK\n0";
    tests.Push(t6);

    mut t7: Test[ctx];
    t7.path = "tests/e2e_spawn_yield.gst";
    t7.is_negative = 0;
    t7.expected = "30";
    tests.Push(t7);

    mut t8: Test[ctx];
    t8.path = "tests/e2e_sync_primitives.gst";
    t8.is_negative = 0;
    t8.expected = "10";
    tests.Push(t8);

    mut t9: Test[ctx];
    t9.path = "tests/test_deref_non_pointer_rejected.gst";
    t9.is_negative = 1;
    t9.expected = "DereferenceNonPointer";
    tests.Push(t9);

    mut t10: Test[ctx];
    t10.path = "tests/test_unresolved_selector_rejected.gst";
    t10.is_negative = 1;
    t10.expected = "UnresolvedSelector";
    tests.Push(t10);

    mut t11: Test[ctx];
    t11.path = "tests/test_bool_wrapper_mismatch_rejected.gst";
    t11.is_negative = 1;
    t11.expected = "TypeMismatch";
    tests.Push(t11);

    mut t12: Test[ctx];
    t12.path = "tests/test_rc_leak_violation.gst";
    t12.is_negative = 1;
    t12.expected = "leak";
    tests.Push(t12);

    mut t13: Test[ctx];
    t13.path = "compiler/test_directory_leak_violation.gst";
    t13.is_negative = 1;
    t13.expected = "must be cleanly closed";
    tests.Push(t13);

    mut t14: Test[ctx];
    t14.path = "compiler/test_escape_return_violation.gst";
    t14.is_negative = 1;
    t14.expected = "Escape analysis violation";
    tests.Push(t14);

    mut t15: Test[ctx];
    t15.path = "compiler/test_scratch_storage_violation.gst";
    t15.is_negative = 1;
    t15.expected = "Cannot assign scratchpad-allocated view";
    tests.Push(t15);

    os.LogStr("🏃 Starting self-hosted Gust test suite...");
    mut passed_count := 0;
    mut failed_count := 0;

    mut i := 0;
    while i < len(tests) {
        mut t := tests[i];
        mut ok := run_test(ctx, t);
        if ok == 1 {
            passed_count = passed_count + 1;
        } else {
            failed_count = failed_count + 1;
        }
        os.ScratchReset();
        i = i + 1;
    }

    os.LogStr("-----------------------------------------");
    mut summary_msg := std.Format("🏁 Test Suite Finished. Passed: %d, Failed: %d", passed_count, failed_count);
    os.LogStr(summary_msg);

    os.System("rm -rf build/test_temp.log build/test_temp.c build/test_temp_clean.c build/test_temp_bin build/test_c_comp.log build/test_run.log");

    if failed_count > 0 {
        os.Exit(1);
    } else {
        os.Exit(0);
    }
}
