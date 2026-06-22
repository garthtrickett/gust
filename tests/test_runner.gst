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

    // Generate a unique identifier for this test based on its path
    mut test_id := "";
    mut char_idx := 0;
    while char_idx < len(path) {
        mut b := std.str_byte_at(path, char_idx);
        if b == 47 || b == 46 { // '/' or '.'
            test_id = std.Concat(test_id, "_");
        } else {
            test_id = std.Concat(test_id, std.str_slice(path, char_idx, char_idx + 1));
        }
        char_idx = char_idx + 1;
    }

    mut temp_log := std.Concat("build/", test_id);
    temp_log = std.Concat(temp_log, "_temp.log");

    mut clean_c := std.Concat("build/", test_id);
    clean_c = std.Concat(clean_c, "_clean.c");

    mut final_c := std.Concat("build/", test_id);
    final_c = std.Concat(final_c, "_final.c");

    mut c_comp_log := std.Concat("build/", test_id);
    c_comp_log = std.Concat(c_comp_log, "_c_comp.log");

    mut run_log := std.Concat("build/", test_id);
    run_log = std.Concat(run_log, "_run.log");

    mut bin_path := std.Concat("build/", test_id);
    bin_path = std.Concat(bin_path, "_bin");

    if is_neg == 1 {
        mut cmd := std.Concat("./gust ", path);
        cmd = std.Concat(cmd, " > ");
        cmd = std.Concat(cmd, temp_log);
        cmd = std.Concat(cmd, " 2>&1");
        status = os.System(cmd);

        if status == 0 {
            mut msg := std.Format("❌ FAIL: %s (Expected compilation failure, but it succeeded)", path);
            os.LogStr(msg);
            return 0;
        }

        mut log_content := os.ReadFile(ctx, temp_log);
        mut found_err := std.str_find(log_content, exp);
        if found_err == 0 - 1 {
            mut msg := std.Format("❌ FAIL: %s (Compilation failed as expected, but could not find expected error substring '%s')", path, exp);
            os.LogStr(msg);
            return 0;
        }

        // Cleanup on PASS
        mut rm_cmd := std.Concat("rm -f ", temp_log);
        os.System(rm_cmd);

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
        cmd_comp = std.Concat(cmd_comp, " > ");
        cmd_comp = std.Concat(cmd_comp, temp_log);
        cmd_comp = std.Concat(cmd_comp, " 2>&1");
        status = os.System(cmd_comp);

        if status != 0 {
            mut msg := std.Format("❌ FAIL: %s (Compilation failed! See %s for errors)", path, temp_log);
            os.LogStr(msg);
            return 0;
        }

        mut comp_output := os.ReadFile(ctx, temp_log);
        mut lines := std.str_split(comp_output, "\n", ctx);
        mut clean_c_content := "";
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
                clean_c_content = std.Concat(clean_c_content, line);
                clean_c_content = std.Concat(clean_c_content, "\n");
            }
            idx = idx + 1;
        }

        os.WriteFile(clean_c, clean_c_content);

        // Prepend src/runtime.c content to the cleaned C to form a unified translation unit
        mut runtime_content := os.ReadFile(ctx, "src/runtime.c");
        mut final_c_content := std.Concat(runtime_content, "\n\n");
        final_c_content = std.Concat(final_c_content, clean_c_content);
        os.WriteFile(final_c, final_c_content);

        mut compile_c_cmd := std.Concat("cc -O2 -Wall -pthread -Isrc ", final_c);
        compile_c_cmd = std.Concat(compile_c_cmd, " -o ");
        compile_c_cmd = std.Concat(compile_c_cmd, bin_path);
        compile_c_cmd = std.Concat(compile_c_cmd, " > ");
        compile_c_cmd = std.Concat(compile_c_cmd, c_comp_log);
        compile_c_cmd = std.Concat(compile_c_cmd, " 2>&1");
        status = os.System(compile_c_cmd);
        if status != 0 {
            mut msg := std.Format("❌ FAIL: %s (Native C compilation failed! See %s for errors)", path, c_comp_log);
            os.LogStr(msg);
            return 0;
        }

        mut run_cmd := std.Concat("./", bin_path);
        run_cmd = std.Concat(run_cmd, " > ");
        run_cmd = std.Concat(run_cmd, run_log);
        run_cmd = std.Concat(run_cmd, " 2>&1");
        status = os.System(run_cmd);
        if status != 0 {
            mut msg := std.Format("❌ FAIL: %s (Execution crashed/failed! See %s for errors)", path, run_log);
            os.LogStr(msg);
            return 0;
        }

        mut actual_output := os.ReadFile(ctx, run_log);
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

        // Cleanup on PASS
        mut rm_cmd := std.Concat("rm -f ", temp_log);
        rm_cmd = std.Concat(rm_cmd, " ");
        rm_cmd = std.Concat(rm_cmd, c_comp_log);
        rm_cmd = std.Concat(rm_cmd, " ");
        rm_cmd = std.Concat(rm_cmd, run_log);
        rm_cmd = std.Concat(rm_cmd, " ");
        rm_cmd = std.Concat(rm_cmd, clean_c);
        rm_cmd = std.Concat(rm_cmd, " ");
        rm_cmd = std.Concat(rm_cmd, final_c);
        rm_cmd = std.Concat(rm_cmd, " ");
        rm_cmd = std.Concat(rm_cmd, bin_path);
        os.System(rm_cmd);

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

    if failed_count > 0 {
        os.Exit(1);
    } else {
        os.Exit(0);
    }
}
