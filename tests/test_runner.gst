type Test[ctx] struct {
    path: str,
    is_negative: int,
    is_substring: int,
    expected: str
}

type TestTaskArg[ctx] struct {
    test: Test[ctx],
    chan: std.Channel[int, ctx]
}

type StringHeader struct {
    data: *byte,
    len: int
}

func join_lines(lines: std.Vector[str, ctx], ctx: &Arena) str {
    mut total_len := 0;
    mut i := 0;
    while i < len(lines) {
        total_len = total_len + len(lines[i]) + 1; // +1 for '\n'
        i = i + 1;
    }
    if total_len == 0 {
        return "";
    }

    unsafe {
        mut dest := os.ScratchAlloc(total_len);
        mut write_idx := 0;

        mut j := 0;
        while j < len(lines) {
            mut line := lines[j];
            mut line_len := len(line);

            mut header := &line as *StringHeader;
            mut src := (*header).data;

            mut k := 0;
            while k < line_len {
                *(dest + write_idx) = *(src + k);
                write_idx = write_idx + 1;
                k = k + 1;
            }
            *(dest + write_idx) = 10; // '\n' = 10
            write_idx = write_idx + 1;
            j = j + 1;
        }

        mut res_header_alloc := os.ScratchAlloc(16);
        mut res_header := (res_header_alloc + 0) as *StringHeader;
        (*res_header).data = dest;
        (*res_header).len = total_len;
        return *(((res_header as *str) + 0) as *str);
    }
}

func run_system_cmd(cmd: str) int {
    return os.System(cmd);
}

func test_worker_task(arg: *TestTaskArg[ctx]) {
    mut local_ctx := os.Arena.New();
    defer local_ctx.Free();
    os.SetThreadScratch(&local_ctx);

    unsafe {
        mut t := (*arg).test;
        mut ok := run_test(t);
        (*arg).chan.Send(ok);
    }
}


func run_test(t: Test[ctx]) int {
    mut tl := os.GetThreadScratch();
    mut local_ctx := tl.arena;
    mut path := t.path;
    mut is_neg := t.is_negative;
    mut exp := t.expected;
    mut status := 0;

    run_system_cmd("mkdir -p build");

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
        status = run_system_cmd(cmd);

        if status == 0 {
            mut msg := std.Format("❌ FAIL: %s (Expected compilation failure, but it succeeded)", path);
            os.LogStr(msg);
            return 0;
        }

        mut log_content := os.ReadFile(local_ctx, temp_log);
        mut found_err := std.str_find(log_content, exp);
        if found_err == 0 - 1 {
            mut msg := std.Format("❌ FAIL: %s (Compilation failed as expected, but could not find expected error substring '%s')", path, exp);
            os.LogStr(msg);
            return 0;
        }

        // Cleanup on PASS
        mut rm_cmd := std.Concat("rm -f ", temp_log);
        run_system_cmd(rm_cmd);

        mut msg := std.Format("✅ PASS: %s (Compilation failed with expected error: '%s')", path, exp);
        os.LogStr(msg);
        return 1;
    } else {
        if std.str_find(path, "e2e_fallible_guard_bootstrap") != 0 - 1 {
            run_system_cmd("mkdir -p temp_e2e_guard_test_dir/nested && echo 'func main() {}' > temp_e2e_guard_test_dir/nested/file1.gst");
        }
        if std.str_find(path, "e2e_filesystem_ops") != 0 - 1 {
            run_system_cmd("mkdir -p temp_e2e_filesystem_dir && echo 'func main() {}' > temp_e2e_filesystem_dir/file1.gst && echo 'plain text' > temp_e2e_filesystem_dir/file2.txt");
        }

        mut cmd_comp := std.Concat("./gust ", path);
        cmd_comp = std.Concat(cmd_comp, " > ");
        cmd_comp = std.Concat(cmd_comp, temp_log);
        cmd_comp = std.Concat(cmd_comp, " 2>&1");
        status = run_system_cmd(cmd_comp);

        if status != 0 {
            mut msg := std.Format("❌ FAIL: %s (Compilation failed! See %s for errors)", path, temp_log);
            os.LogStr(msg);
            return 0;
        }

        mut comp_output := os.ReadFile(local_ctx, temp_log);
        mut lines := std.str_split(comp_output, "\n", local_ctx);

        mut clean_lines: std.Vector[str, local_ctx] := std.VectorNew(local_ctx);
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
                clean_lines.Push(line);
            }
            idx = idx + 1;
        }
        mut clean_c_content := join_lines(clean_lines, local_ctx);

        os.WriteFile(clean_c, clean_c_content);

        // Prepend src/runtime.c content to the cleaned C to form a unified translation unit
        mut runtime_content := os.ReadFile(local_ctx, "src/runtime.c");
        mut final_c_content := std.Concat(runtime_content, "\n\n");
        final_c_content = std.Concat(final_c_content, clean_c_content);
        os.WriteFile(final_c, final_c_content);

        mut compile_c_cmd := std.Concat("cc -O2 -Wall -pthread -Isrc ", final_c);
        if is_neg == 2 || std.str_find(path, "canary") != 0 - 1 || std.str_find(path, "sanitizer") != 0 - 1 {
            compile_c_cmd = std.Concat(compile_c_cmd, " -fsanitize=address -DGUST_DEBUG");
        }
        compile_c_cmd = std.Concat(compile_c_cmd, " -o ");
        compile_c_cmd = std.Concat(compile_c_cmd, bin_path);
        compile_c_cmd = std.Concat(compile_c_cmd, " > ");
        compile_c_cmd = std.Concat(compile_c_cmd, c_comp_log);
        compile_c_cmd = std.Concat(compile_c_cmd, " 2>&1");
        status = run_system_cmd(compile_c_cmd);
        if status != 0 {
            mut msg := std.Format("❌ FAIL: %s (Native C compilation failed! See %s for errors)", path, c_comp_log);
            os.LogStr(msg);

            // SYSTEMATIC DIAGNOSTIC DUMP
            os.LogStr("🚨 --- SYSTEMATIC DIAGNOSTICS FOR NATIVE C FAILURE ---");
            mut temp_out := os.ReadFile(local_ctx, temp_log);
            os.LogStr(std.Format("Temp Log Length: %d bytes", len(temp_out)));
            if len(temp_out) > 0 {
                os.LogStr("--- Last 15 Lines of Temp Log ---");
                mut t_lines := std.str_split(temp_out, "\n", local_ctx);
                mut start_line := len(t_lines) - 15;
                if start_line < 0 { start_line = 0; }
                mut line_idx := start_line;
                while line_idx < len(t_lines) {
                    os.LogStr(t_lines[line_idx]);
                    line_idx = line_idx + 1;
                }
            }
            os.LogStr("------------------------------------------------------");

            return 0;
        }

        mut run_cmd := std.Concat("./", bin_path);
        run_cmd = std.Concat(run_cmd, " > ");
        run_cmd = std.Concat(run_cmd, run_log);
        run_cmd = std.Concat(run_cmd, " 2>&1");
        status = run_system_cmd(run_cmd);

        if is_neg == 2 {
            if status == 0 {
                mut msg := std.Format("❌ FAIL: %s (Expected runtime crash/failure, but it exited cleanly with status 0)", path);
                os.LogStr(msg);
                return 0;
            }
        } else {
            if status != 0 {
                mut msg := std.Format("❌ FAIL: %s (Execution crashed/failed! See %s for errors)", path, run_log);
                os.LogStr(msg);
                return 0;
            }
        }

        mut actual_output := os.ReadFile(local_ctx, run_log);

        // Filter out emoji-prefixed logging lines from runtime execution
        mut run_lines := std.str_split(actual_output, "\n", local_ctx);
        mut clean_run_lines: std.Vector[str, local_ctx] := std.VectorNew(local_ctx);
        mut r_idx := 0;
        while r_idx < len(run_lines) {
            mut line := run_lines[r_idx];
            mut should_keep := 1;
            if len(line) > 0 {
                mut b := std.str_byte_at(line, 0);
                if b == 226 || b == 240 || b == 243 {
                    should_keep = 0;
                }
            }
            if should_keep == 1 {
                clean_run_lines.Push(line);
            }
            r_idx = r_idx + 1;
        }
        mut clean_run_content := join_lines(clean_run_lines, local_ctx);
        mut trimmed_actual := std.str_trim(clean_run_content);
        mut trimmed_expected := std.str_trim(exp);

        mut is_match := 0;
        if t.is_substring == 1 || is_neg == 2 {
            if std.str_find(trimmed_actual, trimmed_expected) != 0 - 1 {
                is_match = 1;
            }
        } else {
            if std.str_eq(trimmed_actual, trimmed_expected) == 1 {
                is_match = 1;
            }
        }

        if is_match == 0 {
            mut msg := std.Format("❌ FAIL: %s (Output mismatch!)", path);
            os.LogStr(msg);
            os.LogStr("--- EXPECTED ---");
            os.LogStr(trimmed_expected);
            os.LogStr("--- ACTUAL ---");
            os.LogStr(trimmed_actual);
            return 0;
        }

        if std.str_find(path, "e2e_fallible_guard_bootstrap") != 0 - 1 {
            run_system_cmd("rm -rf temp_e2e_guard_test_dir");
        }
        if std.str_find(path, "e2e_filesystem_ops") != 0 - 1 {
            run_system_cmd("rm -rf temp_e2e_filesystem_dir temp_e2e_filesystem_test.txt");
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
        run_system_cmd(rm_cmd);

        mut msg := "";
        if is_neg == 2 {
            msg = std.Format("✅ PASS: %s (Runtime crashed as expected: '%s')", path, exp);
        } else {
            msg = std.Format("✅ PASS: %s (Compiled and ran successfully with expected output)", path);
        }
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

    mut t16: Test[ctx];
    t16.path = "compiler/resolver_test_entry.gst";
    t16.is_negative = 0;
    t16.expected = "2\nstd\nos";
    tests.Push(t16);

    mut t17: Test[ctx];
    t17.path = "compiler/typechecker_scope_test_entry.gst";
    t17.is_negative = 0;
    t17.expected = "0\n3\n1\n2";
    tests.Push(t17);

    mut t19: Test[ctx];
    t19.path = "tests/test_sentinel_positive_sample.gst";
    t19.is_negative = 0;
    t19.is_substring = 1;
    t19.expected = "SUCCESS SENTINEL MATCHED!";
    tests.Push(t19);

    mut t20: Test[ctx];
    t20.path = "compiler/typechecker_origins_test_entry.gst";
    t20.is_negative = 0;
    t20.is_substring = 1;
    t20.expected = "get_type_brand nested pointer lookup OK";
    tests.Push(t20);

    mut t21: Test[ctx];
    t21.path = "compiler/typechecker_types_test_entry.gst";
    t21.is_negative = 0;
    t21.is_substring = 1;
    t21.expected = "Any brand element correctly allowed inside parent brand 'ctx'!";
    tests.Push(t21);

    mut t22: Test[ctx];
    t22.path = "compiler/codegen_initializer_test_entry.gst";
    t22.is_negative = 0;
    t22.is_substring = 1;
    t22.expected = "os_GetThreadScratch function definition generated correctly!";
    tests.Push(t22);

    mut t23: Test[ctx];
    t23.path = "compiler/typechecker_templates_test_entry.gst";
    t23.is_negative = 0;
    t23.is_substring = 1;
    t23.expected = "std_RcGet(rc_ptr)";
    tests.Push(t23);

    mut t24: Test[ctx];
    t24.path = "tests/test_brand_nesting_violation_rejected.gst";
    t24.is_negative = 1;
    t24.expected = "TypeMismatch";
    tests.Push(t24);

    mut t25: Test[ctx];
    t25.path = "tests/test_stack_escape_rejected.gst";
    t25.is_negative = 1;
    t25.expected = "Escape analysis violation";
    tests.Push(t25);

    mut t26: Test[ctx];
    t26.path = "tests/test_double_move_rejected.gst";
    t26.is_negative = 1;
    t26.expected = "already been moved";
    tests.Push(t26);

    mut t27: Test[ctx];
    t27.path = "tests/test_dangling_index_rejected.gst";
    t27.is_negative = 1;
    t27.expected = "Allocator moved or freed";
    tests.Push(t27);

    mut t28: Test[ctx];
    t28.path = "tests/test_unbranded_struct_view_rejected.gst";
    t28.is_negative = 1;
    t28.expected = "cannot contain ephemeral slice or view";
    tests.Push(t28);

    mut t29: Test[ctx];
    t29.path = "tests/test_branded_struct_mismatch_rejected.gst";
    t29.is_negative = 1;
    t29.expected = "Mismatched nested brand";
    tests.Push(t29);

    mut t30: Test[ctx];
    t30.path = "tests/test_large_enum_variant_payload_rejected.gst";
    t30.is_negative = 1;
    t30.expected = "large enum variant payload";
    tests.Push(t30);

    mut t31: Test[ctx];
    t31.path = "tests/test_unchecked_cast_access_rejected.gst";
    t31.is_negative = 1;
    t31.expected = "Accessing the .Val payload of an unchecked result wrapper";
    tests.Push(t31);

    mut t32: Test[ctx];
    t32.path = "tests/test_unchecked_lookup_access_rejected.gst";
    t32.is_negative = 1;
    t32.expected = "Accessing the .Val payload of an unchecked result wrapper";
    tests.Push(t32);

    mut t33: Test[ctx];
    t33.path = "tests/test_unchecked_else_access_rejected.gst";
    t33.is_negative = 1;
    t33.expected = "Accessing the .Val payload of an unchecked result wrapper";
    tests.Push(t33);

    mut t34: Test[ctx];
    t34.path = "tests/test_mismatched_logical_check_rejected.gst";
    t34.is_negative = 1;
    t34.expected = "Accessing the .Val payload of an unchecked result wrapper";
    tests.Push(t34);

    mut t35: Test[ctx];
    t35.path = "tests/test_deref_outside_unsafe_rejected.gst";
    t35.is_negative = 1;
    t35.expected = "prohibited outside 'unsafe' blocks";
    tests.Push(t35);

    mut t36: Test[ctx];
    t36.path = "tests/test_match_non_exhaustive_rejected.gst";
    t36.is_negative = 1;
    t36.expected = "is not exhaustive";
    tests.Push(t36);

    mut t37: Test[ctx];
    t37.path = "tests/test_match_invalid_variant_rejected.gst";
    t37.is_negative = 1;
    t37.expected = "is not a valid variant of enum";
    tests.Push(t37);

    mut t38: Test[ctx];
    t38.path = "tests/test_logical_operators_invalid.gst";
    t38.is_negative = 1;
    t38.expected = "Left operand of logical";
    tests.Push(t38);

    mut t39: Test[ctx];
    t39.path = "tests/e2e_zero_copy_network_processor.gst";
    t39.is_negative = 0;
    t39.expected = "42";
    tests.Push(t39);

    mut t40: Test[ctx];
    t40.path = "tests/e2e_generational_arena_wrapper_migration.gst";
    t40.is_negative = 0;
    t40.expected = "499500\n1998";
    tests.Push(t40);

    mut t41: Test[ctx];
    t41.path = "tests/e2e_unordered_adt_compilation.gst";
    t41.is_negative = 0;
    t41.expected = "42\n84";
    tests.Push(t41);

    mut t42: Test[ctx];
    t42.path = "tests/e2e_recursive_branded_linked_list.gst";
    t42.is_negative = 0;
    t42.expected = "30";
    tests.Push(t42);

    mut t43: Test[ctx];
    t43.path = "tests/e2e_else_if_comparisons.gst";
    t43.is_negative = 0;
    t43.expected = "1\n2\n3";
    tests.Push(t43);

    mut t44: Test[ctx];
    t44.path = "tests/e2e_rich_formatting_basic.gst";
    t44.is_negative = 0;
    t44.expected = "Welcome to Gust version 1!";
    tests.Push(t44);

    mut t45: Test[ctx];
    t45.path = "tests/e2e_rich_formatting_bounds.gst";
    t45.is_negative = 0;
    t45.expected = "String: ThisIsALargeStringWithManyCharactersToTestThatOurCalculationsAreExtremelyRobustAndPreventAnyPotentialBufferOverflowInTranspiledC, Neg: -2147483648, Max: 2147483647";
    tests.Push(t45);

    mut t46: Test[ctx];
    t46.path = "tests/e2e_rich_formatting_loop.gst";
    t46.is_negative = 0;
    t46.expected = "Index: 0\nIndex: 1\nIndex: 2\nIndex: 3\nIndex: 4\nIndex: 5\nIndex: 6\nIndex: 7\nIndex: 8\nIndex: 9";
    tests.Push(t46);

    mut t47: Test[ctx];
    t47.path = "tests/e2e_bool_primitive.gst";
    t47.is_negative = 0;
    t47.expected = "1\n0\n1";
    tests.Push(t47);

    mut t48: Test[ctx];
    t48.path = "tests/e2e_string_escape_sequences.gst";
    t48.is_negative = 0;
    t48.expected = "line1\nline2\ttab\\backslash\"quote";
    tests.Push(t48);

    mut t49: Test[ctx];
    t49.path = "tests/e2e_arithmetic_logic.gst";
    t49.is_negative = 0;
    t49.expected = "50\n1";
    tests.Push(t49);

    mut t50: Test[ctx];
    t50.path = "tests/e2e_loops_mutation.gst";
    t50.is_negative = 0;
    t50.expected = "0\n1\n2\n3\n4";
    tests.Push(t50);

    mut t51: Test[ctx];
    t51.path = "tests/e2e_mock_payload_slicing.gst";
    t51.is_negative = 0;
    t51.expected = "42\n1024";
    tests.Push(t51);

    mut t52: Test[ctx];
    t52.path = "tests/e2e_native_collections_evaluation.gst";
    t52.is_negative = 0;
    t52.expected = "3\n10\n20\n30\n2\n42\n84\n999";
    tests.Push(t52);

    mut t53: Test[ctx];
    t53.path = "tests/e2e_adt_match_evaluation.gst";
    t53.is_negative = 0;
    t53.expected = "42\n30\n123";
    tests.Push(t53);

    mut t54: Test[ctx];
    t54.path = "tests/e2e_adt_match_destructuring_evaluation.gst";
    t54.is_negative = 0;
    t54.expected = "42\n30\n123";
    tests.Push(t54);

    mut t55: Test[ctx];
    t55.path = "tests/e2e_file_io_evaluation.gst";
    t55.is_negative = 0;
    t55.expected = "1\nHello from Gust Compiler File I/O!\n34";
    tests.Push(t55);

    mut t56: Test[ctx];
    t56.path = "tests/e2e_fallible_lookup_evaluation.gst";
    t56.is_negative = 0;
    t56.expected = "1\n42\n0\n0";
    tests.Push(t56);

    mut t57: Test[ctx];
    t57.path = "tests/e2e_is_valid_invariant_validation.gst";
    t57.is_negative = 0;
    t57.expected = "1\n0";
    tests.Push(t57);

    mut t58: Test[ctx];
    t58.path = "tests/e2e_enum_indirection_pattern.gst";
    t58.is_negative = 0;
    t58.expected = "60";
    tests.Push(t58);

    mut t59: Test[ctx];
    t59.path = "tests/e2e_universal_move_semantics_monomorphized.gst";
    t59.is_negative = 0;
    t59.expected = "100\n100";
    tests.Push(t59);

    mut t60: Test[ctx];
    t60.path = "tests/e2e_relaxed_monomorphized_pod_performance.gst";
    t60.is_negative = 0;
    t60.expected = "101\n42\n101\n42";
    tests.Push(t60);

    mut t61: Test[ctx];
    t61.path = "tests/e2e_take_and_empty_reinitialization.gst";
    t61.is_negative = 0;
    t61.expected = "World\n2\nHello\n1";
    tests.Push(t61);

    mut t62: Test[ctx];
    t62.path = "tests/e2e_sentinel_null_protection.gst";
    t62.is_negative = 0;
    t62.expected = "1";
    tests.Push(t62);

    mut t63: Test[ctx];
    t63.path = "tests/e2e_namespaced_collections.gst";
    t63.is_negative = 0;
    t63.expected = "2\n111\n222\n2\n888\n999";
    tests.Push(t63);

    mut t64: Test[ctx];
    t64.path = "tests/e2e_string_utilities_evaluation.gst";
    t64.is_negative = 0;
    t64.expected = "Hello\nWorld\n1\n0\n87";
    tests.Push(t64);

    mut t65: Test[ctx];
    t65.path = "tests/e2e_pool_allocation_recycling.gst";
    t65.is_negative = 0;
    t65.expected = "0\n111\n1\n222\n2\n333\n2\n444";
    tests.Push(t65);

    mut t66: Test[ctx];
    t66.path = "tests/e2e_generational_arena_loop.gst";
    t66.is_negative = 0;
    t66.expected = "499500";
    tests.Push(t66);

    mut t67: Test[ctx];
    t67.path = "tests/e2e_rc_reference_counting.gst";
    t67.is_negative = 0;
    t67.expected = "0\n42\n0\n1\n0";
    tests.Push(t67);

    mut t68: Test[ctx];
    t68.path = "tests/e2e_graph_cyclic_relationship.gst";
    t68.is_negative = 0;
    t68.expected = "10\n20\n30\n10\n20\n30";
    tests.Push(t68);

    mut t69: Test[ctx];
    t69.path = "tests/e2e_lexical_scope_tree.gst";
    t69.is_negative = 0;
    t69.expected = "100\n1\n-1
100\n2\n200\n42";
    tests.Push(t69);

    mut t70: Test[ctx];
    t70.path = "tests/e2e_logical_and_or_operators.gst";
    t70.is_negative = 0;
    t70.expected = "0\n1\n1\n2\n100";
    tests.Push(t70);

    mut t71: Test[ctx];
    t71.path = "tests/e2e_adt_pressure_test.gst";
    t71.is_negative = 0;
    t71.expected = "42\nsomething went wrong\nNone";
    tests.Push(t71);

    mut t72: Test[ctx];
    t72.path = "tests/e2e_thread_local_scratchpad.gst";
    t72.is_negative = 0;
    t72.expected = "42\n84\n42";
    tests.Push(t72);

    mut t73: Test[ctx];
    t73.path = "tests/e2e_scratchpad_formatting_loop.gst";
    t73.is_negative = 0;
    t73.expected = "Num: 0\nNum: 1\nNum: 2\nNum: 3\nNum: 4";
    tests.Push(t73);

    mut t74: Test[ctx];
    t74.path = "tests/e2e_multithreaded_scratch_isolation.gst";
    t74.is_negative = 0;
    t74.expected = "42\n100";
    tests.Push(t74);

    mut t75: Test[ctx];
    t75.path = "tests/e2e_arena_canary_normal_debug.gst";
    t75.is_negative = 0;
    t75.expected = "42\n84";
    tests.Push(t75);

    mut t76: Test[ctx];
    t76.path = "tests/e2e_arena_canary_corruption_detection.gst";
    t76.is_negative = 2;
    t76.expected = "boundary corruption detected";
    tests.Push(t76);

    mut t77: Test[ctx];
    t77.path = "tests/e2e_sanitizer_detection_of_corrupt_memory.gst";
    t77.is_negative = 2;
    t77.expected = "AddressSanitizer";
    tests.Push(t77);

    mut t78: Test[ctx];
    t78.path = "tests/e2e_line_preprocessor_validation.gst";
    t78.is_negative = 0;
    t78.expected = "10";
    tests.Push(t78);

    mut t79: Test[ctx];
    t79.path = "tests/app.gst";
    t79.is_negative = 0;
    t79.expected = "42\n100";
    tests.Push(t79);

    mut t80: Test[ctx];
    t80.path = "compiler/typechecker_mismatch_test_entry.gst";
    t80.is_negative = 0;
    t80.expected = "Argument mismatch correctly detected!\nSemantic Error: Template 'std.Vector' expects 2 generic arguments but got 1";
    tests.Push(t80);

    mut t81: Test[ctx];
    t81.path = "compiler/ast_test_entry.gst";
    t81.is_negative = 0;
    t81.expected = "";
    tests.Push(t81);

    mut t82: Test[ctx];
    t82.path = "compiler/ast_dump_entry.gst";
    t82.is_negative = 2;
    t82.expected = "Usage: ast_dump <file>";
    tests.Push(t82);

    mut t83: Test[ctx];
    t83.path = "compiler/parser_full_test_entry.gst";
    t83.is_negative = 0;
    t83.expected = "3\nadd\n8\n11\n10";
    tests.Push(t83);

    mut t84: Test[ctx];
    t84.path = "compiler/parser_primitive_index_test_entry.gst";
    t84.is_negative = 0;
    t84.expected = "7\nstr\nint\nstd_Vector_int_ctx";
    tests.Push(t84);

    mut t85: Test[ctx];
    t85.path = "compiler/parser_statement_test_entry.gst";
    t85.is_negative = 0;
    t85.expected = "";
    tests.Push(t85);

    mut t86: Test[ctx];
    t86.path = "compiler/parser_type_test_entry.gst";
    t86.is_negative = 0;
    t86.expected = "1\nMyStruct\n2\nMyEnum";
    tests.Push(t86);

    mut t_ref_access: Test[ctx];
    t_ref_access.path = "compiler/parser_reference_access_test_entry.gst";
    t_ref_access.is_negative = 0;
    t_ref_access.expected = "SUCCESS: Explicit reference-access method call parsing verified!";
    tests.Push(t_ref_access);

    mut t_ref_passive: Test[ctx];
    t_ref_passive.path = "tests/test_reference_access_parsing_accepted.gst";
    t_ref_passive.is_negative = 0;
    t_ref_passive.is_substring = 0;
    t_ref_passive.expected = "";
    tests.Push(t_ref_passive);

    mut t_collection_dual_signatures: Test[ctx];
    t_collection_dual_signatures.path = "tests/e2e_collection_dual_signatures.gst";
    t_collection_dual_signatures.is_negative = 0;
    t_collection_dual_signatures.is_substring = 0;
    t_collection_dual_signatures.expected = "11\n20\n25\nNone\n100\nlegacy miss\n200\nNone";
    tests.Push(t_collection_dual_signatures);

    mut t87: Test[ctx];
    t87.path = "tests/e2e_program_b_safe_arena_cyclic_graph.gst";
    t87.is_negative = 0;
    t87.expected = "10\n20\n30\n10\n20\n30";
    tests.Push(t87);

    mut t88: Test[ctx];
    t88.path = "tests/e2e_program_c_universal_ownership_operators.gst";
    t88.is_negative = 0;
    t88.expected = "100\n42\n1024";
    tests.Push(t88);

    mut t89: Test[ctx];
    t89.path = "tests/e2e_mutex_concurrency.gst";
    t89.is_negative = 0;
    t89.expected = "300";
    tests.Push(t89);

    mut t90: Test[ctx];
    t90.path = "tests/e2e_channel_ping_pong.gst";
    t90.is_negative = 0;
    t90.expected = "142";
    tests.Push(t90);

    mut t91: Test[ctx];
    t91.path = "tests/e2e_parallel_zero_copy_parsing.gst";
    t91.is_negative = 0;
    t91.expected = "250";
    tests.Push(t91);

    mut t92: Test[ctx];
    t92.path = "tests/e2e_fiber_channel_pipeline.gst";
    t92.is_negative = 0;
    t92.expected = "242";
    tests.Push(t92);

    mut t93: Test[ctx];
    t93.path = "tests/e2e_process_args_and_exit.gst";
    t93.is_negative = 0;
    t93.expected = "3\ncompile\nfile.gst";
    tests.Push(t93);

    mut t94: Test[ctx];
    t94.path = "tests/e2e_thread_local_dynamic_swapping.gst";
    t94.is_negative = 0;
    t94.expected = "0\n16";
    tests.Push(t94);

    mut t96: Test[ctx];
    t96.path = "tests/e2e_hashmap_extended_utilities.gst";
    t96.is_negative = 0;
    t96.expected = "3\n600\n2\n0\n0";
    tests.Push(t96);

    mut t97: Test[ctx];
    t97.path = "tests/e2e_character_classification_and_parsing.gst";
    t97.is_negative = 0;
    t97.expected = "-84138";
    tests.Push(t97);

    mut t98: Test[ctx];
    t98.path = "tests/e2e_vector_stack_lifo_parser.gst";
    t98.is_negative = 0;
    t98.expected = "30\n35\n20\n2\n0";
    tests.Push(t98);

    mut t99: Test[ctx];
    t99.path = "tests/e2e_str_find_and_trim.gst";
    t99.is_negative = 0;
    t99.expected = "hello\n2\n-1";
    tests.Push(t99);

    mut t100: Test[ctx];
    t100.path = "tests/e2e_str_split.gst";
    t100.is_negative = 0;
    t100.expected = "4\na\nb\nc\nd\n3\nx\ny\nz\n1\na,b,c,d";
    tests.Push(t100);

    mut t101: Test[ctx];
    t101.path = "tests/e2e_path_join.gst";
    t101.is_negative = 0;
    t101.expected = "a/b/c\na/c\na/b/d\n/a/b/c\n../c";
    tests.Push(t101);

    mut t102: Test[ctx];
    t102.path = "tests/e2e_guard_hashmap_lookup.gst";
    t102.is_negative = 0;
    t102.expected = "100";
    tests.Push(t102);

    mut t103: Test[ctx];
    t103.path = "tests/e2e_guard_mutability.gst";
    t103.is_negative = 0;
    t103.expected = "100";
    tests.Push(t103);

    mut t104: Test[ctx];
    t104.path = "tests/e2e_guard_cast.gst";
    t104.is_negative = 0;
    t104.expected = "42";
    tests.Push(t104);

    mut t105: Test[ctx];
    t105.path = "tests/test_thread_local_context_registration_valid.gst";
    t105.is_negative = 0;
    t105.expected = "";
    tests.Push(t105);

    mut t106: Test[ctx];
    t106.path = "tests/test_safe_branding_substitution.gst";
    t106.is_negative = 0;
    t106.expected = "";
    tests.Push(t106);

    mut t107: Test[ctx];
    t107.path = "tests/test_arena_validate_type_checking_valid.gst";
    t107.is_negative = 0;
    t107.expected = "";
    tests.Push(t107);

    mut t108: Test[ctx];
    t108.path = "tests/test_dereference_inside_unsafe_accepted.gst";
    t108.is_negative = 0;
    t108.expected = "42";
    tests.Push(t108);

    mut t109: Test[ctx];
    t109.path = "tests/test_take_pod_struct_accepted.gst";
    t109.is_negative = 0;
    t109.expected = "";
    tests.Push(t109);

    mut t110: Test[ctx];
    t110.path = "tests/test_take_linear_struct_accepted.gst";
    t110.is_negative = 0;
    t110.expected = "";
    tests.Push(t110);

    mut t111: Test[ctx];
    t111.path = "tests/test_string_view_type_safety_accepted.gst";
    t111.is_negative = 0;
    t111.expected = "Hello Arena\n11";
    tests.Push(t111);

    mut t112: Test[ctx];
    t112.path = "tests/test_branded_struct_containing_slice_accepted.gst";
    t112.is_negative = 0;
    t112.expected = "";
    tests.Push(t112);

    mut t113: Test[ctx];
    t113.path = "tests/test_branded_generic_instantiated_with_view_accepted.gst";
    t113.is_negative = 0;
    t113.expected = "";
    tests.Push(t113);

    mut t114: Test[ctx];
    t114.path = "tests/test_identical_nested_brands_accepted.gst";
    t114.is_negative = 0;
    t114.expected = "";
    tests.Push(t114);

    mut t115: Test[ctx];
    t115.path = "tests/test_view_and_pod_in_branded_collection_accepted.gst";
    t115.is_negative = 0;
    t115.expected = "";
    tests.Push(t115);

    mut t116: Test[ctx];
    t116.path = "tests/test_handoff_safe_accepted.gst";
    t116.is_negative = 0;
    t116.expected = "";
    tests.Push(t116);

    mut t117: Test[ctx];
    t117.path = "tests/test_return_parameter_view_accepted.gst";
    t117.is_negative = 0;
    t117.expected = "";
    tests.Push(t117);

    mut t118: Test[ctx];
    t118.path = "tests/test_return_static_literal_view_accepted.gst";
    t118.is_negative = 0;
    t118.expected = "";
    tests.Push(t118);

    mut t119: Test[ctx];
    t119.path = "tests/test_checked_results_scoping.gst";
    t119.is_negative = 0;
    t119.expected = "42";
    tests.Push(t119);

    mut t120: Test[ctx];
    t120.path = "tests/test_definite_check_inside_if_accepted.gst";
    t120.is_negative = 0;
    t120.expected = "42";
    tests.Push(t120);

    mut t_safe_sel_rej: Test[ctx];
    t_safe_sel_rej.path = "tests/test_enum_safe_selector_rejected.gst";
    t_safe_sel_rej.is_negative = 1;
    t_safe_sel_rej.expected = "DirectEnumAccessForbidden";
    tests.Push(t_safe_sel_rej);

    mut t_safe_tag_rej: Test[ctx];
    t_safe_tag_rej.path = "tests/test_enum_safe_tag_write_rejected.gst";
    t_safe_tag_rej.is_negative = 1;
    t_safe_tag_rej.expected = "EnumMutationForbidden";
    tests.Push(t_safe_tag_rej);

    mut t_unsafe_acc_acc: Test[ctx];
    t_unsafe_acc_acc.path = "tests/test_enum_unsafe_access_accepted.gst";
    t_unsafe_acc_acc.is_negative = 0;
    t_unsafe_acc_acc.expected = "";
    tests.Push(t_unsafe_acc_acc);

    mut t_match_dest_ref_rej: Test[ctx];
    t_match_dest_ref_rej.path = "tests/test_match_destructure_type_is_reference_rejected.gst";
    t_match_dest_ref_rej.is_negative = 1;
    t_match_dest_ref_rej.expected = "type mismatch";
    tests.Push(t_match_dest_ref_rej);

    mut t_match_dest_deref_acc: Test[ctx];
    t_match_dest_deref_acc.path = "tests/test_match_destructure_deref_accepted.gst";
    t_match_dest_deref_acc.is_negative = 0;
    t_match_dest_deref_acc.expected = "42";
    tests.Push(t_match_dest_deref_acc);

    mut t121: Test[ctx];
    t121.path = "tests/test_definite_check_lookup_inside_if_accepted.gst";
    t121.is_negative = 0;
    t121.expected = "100";
    tests.Push(t121);

    mut t122: Test[ctx];
    t122.path = "tests/test_definite_check_compound_and_accepted.gst";
    t122.is_negative = 0;
    t122.expected = "42";
    tests.Push(t122);

    mut t123: Test[ctx];
    t123.path = "tests/test_nested_scoping_definite_checks_accepted.gst";
    t123.is_negative = 0;
    t123.expected = "";
    tests.Push(t123);

    mut t124: Test[ctx];
    t124.path = "tests/test_pool_type_checking_valid.gst";
    t124.is_negative = 0;
    t124.expected = "";
    tests.Push(t124);

    mut t125: Test[ctx];
    t125.path = "tests/test_brand_crossing_cloning.gst";
    t125.is_negative = 0;
    t125.expected = "";
    tests.Push(t125);

    mut t126: Test[ctx];
    t126.path = "tests/test_rc_and_graph_type_checking_valid.gst";
    t126.is_negative = 0;
    t126.expected = "";
    tests.Push(t126);

    mut t127: Test[ctx];
    t127.path = "tests/test_safety_escape_rejected.gst";
    t127.is_negative = 1;
    t127.expected = "cannot be used because its backing origin";
    tests.Push(t127);

    mut t128: Test[ctx];
    t128.path = "tests/test_conditional_origin_union_rejected.gst";
    t128.is_negative = 1;
    t128.expected = "cannot be used because its backing origin";
    tests.Push(t128);

    mut t129: Test[ctx];
    t129.path = "tests/test_function_view_origin_propagation_rejected.gst";
    t129.is_negative = 1;
    t129.expected = "cannot be used because its backing origin";
    tests.Push(t129);

    mut t130: Test[ctx];
    t130.path = "tests/test_view_invalidated_on_parent_reassignment_rejected.gst";
    t130.is_negative = 1;
    t130.expected = "Use of moved variable";
    tests.Push(t130);

    mut t131: Test[ctx];
    t131.path = "tests/test_view_invalidated_on_parent_field_mutation_rejected.gst";
    t131.is_negative = 1;
    t131.expected = "Use of moved variable";
    tests.Push(t131);

    mut t132: Test[ctx];
    t132.path = "tests/test_brand_lifetime_mismatch_rejected.gst";
    t132.is_negative = 1;
    t132.expected = "BrandMismatch";
    tests.Push(t132);

    mut t133: Test[ctx];
    t133.path = "tests/test_branded_vector_safety_rejected.gst";
    t133.is_negative = 1;
    t133.expected = "BrandMismatch";
    tests.Push(t133);

    mut t134: Test[ctx];
    t134.path = "tests/test_branded_hashmap_safety_rejected.gst";
    t134.is_negative = 1;
    t134.expected = "BrandMismatch";
    tests.Push(t134);

    mut t135: Test[ctx];
    t135.path = "tests/test_unbranded_generic_instantiated_with_view_rejected.gst";
    t135.is_negative = 1;
    t135.expected = "cannot contain ephemeral slice";
    tests.Push(t135);

    mut t136: Test[ctx];
    t136.path = "tests/test_nested_different_brands_rejected.gst";
    t136.is_negative = 1;
    t136.expected = "Mismatched nested brand";
    tests.Push(t136);

    mut t137: Test[ctx];
    t137.path = "tests/test_unbranded_linear_struct_in_branded_collection_rejected.gst";
    t137.is_negative = 1;
    t137.expected = "Brand Nesting Restriction";
    tests.Push(t137);

    mut t138: Test[ctx];
    t138.path = "tests/test_handoff_isolation_violation_rejected.gst";
    t138.is_negative = 1;
    t138.expected = "preventing safe handoff";
    tests.Push(t138);

    mut t139: Test[ctx];
    t139.path = "tests/test_handoff_use_after_move_rejected.gst";
    t139.is_negative = 1;
    t139.expected = "Use of moved variable";
    tests.Push(t139);

    mut t140: Test[ctx];
    t140.path = "tests/test_move_linear_type_invalidates_rejected.gst";
    t140.is_negative = 1;
    t140.expected = "Use of moved variable";
    tests.Push(t140);

    mut t141: Test[ctx];
    t141.path = "tests/test_monomorphized_linear_collection_is_linear_rejected.gst";
    t141.is_negative = 1;
    t141.expected = "Use of moved variable";
    tests.Push(t141);

    mut t142: Test[ctx];
    t142.path = "tests/test_generic_definition_enforces_strict_linear_safety_rejected.gst";
    t142.is_negative = 1;
    t142.expected = "Use of moved variable";
    tests.Push(t142);

    mut t143: Test[ctx];
    t143.path = "tests/test_uninitialized_inout_parameter_rejected.gst";
    t143.is_negative = 1;
    t143.expected = "was moved but never re-initialized";
    tests.Push(t143);

    mut t144: Test[ctx];
    t144.path = "tests/test_fiber_scratchpad_escape_across_yield_boundary_rejected.gst";
    t144.is_negative = 1;
    t144.expected = "Cannot assign scratchpad-allocated view";
    tests.Push(t144);

    mut t145: Test[ctx];
    t145.path = "tests/test_arena_moved_through_channel_invalid_rejected.gst";
    t145.is_negative = 1;
    t145.expected = "moved";
    tests.Push(t145);

    mut t146: Test[ctx];
    t146.path = "tests/test_guard_non_diverging_else_rejected.gst";
    t146.is_negative = 1;
    t146.expected = "must diverge";
    tests.Push(t146);

    mut t147: Test[ctx];
    t147.path = "tests/test_guard_non_wrapper_rhs_rejected.gst";
    t147.is_negative = 1;
    t147.expected = "must evaluate to a fallible wrapper type";
    tests.Push(t147);

    mut t148: Test[ctx];
    t148.path = "tests/test_guard_escape_analysis_and_borrow_invalidation_rejected.gst";
    t148.is_negative = 1;
    t148.expected = "backing origin";
    tests.Push(t148);

    mut t149: Test[ctx];
    t149.path = "tests/test_directory_leak_violation_use_after_ctx_move.gst";
    t149.is_negative = 1;
    t149.expected = "moved";
    tests.Push(t149);

    mut t150: Test[ctx];
    t150.path = "tests/test_directory_leak_violation_move_open_directory.gst";
    t150.is_negative = 1;
    t150.expected = "cannot be moved while open";
    tests.Push(t150);

    mut t151: Test[ctx];
    t151.path = "tests/test_directory_invalid_field_access.gst";
    t151.is_negative = 1;
    t151.expected = "not found";
    tests.Push(t151);

    mut t152: Test[ctx];
    t152.path = "tests/test_directory_invalid_func_access.gst";
    t152.is_negative = 1;
    t152.expected = "Undefined function";
    tests.Push(t152);

    mut t153: Test[ctx];
    t153.path = "tests/test_vector_pop_linear_ownership_enforced_rejected.gst";
    t153.is_negative = 1;
    t153.expected = "moved";
    tests.Push(t153);

    mut t154: Test[ctx];
    t154.path = "tests/test_hashmap_keys_brand_lifetime_violation_invalid_arg.gst";
    t154.is_negative = 1;
    t154.expected = "HashMap.Keys";
    tests.Push(t154);

    mut t155: Test[ctx];
    t155.path = "tests/test_hashmap_keys_brand_lifetime_violation_mismatched_assignment.gst";
    t155.is_negative = 1;
    t155.expected = "TypeMismatch";
    tests.Push(t155);

    mut t156: Test[ctx];
    t156.path = "tests/test_concurrency_template_argument_mismatch_rejected.gst";
    t156.is_negative = 1;
    t156.expected = "generic arguments";
    tests.Push(t156); 

    mut t157: Test[ctx];
    t157.path = "tests/test_channel_mismatched_send_rejected.gst";
    t157.is_negative = 1;
    t157.expected = "type mismatch";
    tests.Push(t157);

    mut t158: Test[ctx];
    t158.path = "tests/test_spawn_invalid_function_non_existent.gst";
    t158.is_negative = 1;
    t158.expected = "Undefined function";
    tests.Push(t158);

    mut t159: Test[ctx];
    t159.path = "tests/test_spawn_invalid_function_multi_param.gst";
    t159.is_negative = 1;
    t159.expected = "must accept exactly";
    tests.Push(t159);

    mut t160: Test[ctx];
    t160.path = "tests/test_take_primitive_rejected.gst";
    t160.is_negative = 1;
    t160.expected = "strictly banned on primitive";
    tests.Push(t160);

    mut t161: Test[ctx];
    t161.path = "tests/test_string_view_logint_rejected.gst";
    t161.is_negative = 1;
    t161.expected = "expects an Int/Byte";
    tests.Push(t161);

    mut t162: Test[ctx];
    t162.path = "tests/test_dangling_vector_use_rejected.gst";
    t162.is_negative = 1;
    t162.expected = "moved or freed";
    tests.Push(t162);

    mut t163: Test[ctx];
    t163.path = "tests/test_tuple_assignment_rejected.gst";
    t163.is_negative = 1;
    t163.expected = "Syntax Error";
    tests.Push(t163);

    mut t164: Test[ctx];
    t164.path = "tests/test_malformed_empty_intrinsic_rejected.gst";
    t164.is_negative = 1;
    t164.expected = "Syntax Error";
    tests.Push(t164);

    mut t165: Test[ctx];
    t165.path = "tests/test_definite_check_nested_scoping_cleanliness_rejected.gst";
    t165.is_negative = 1;
    t165.expected = "unchecked result wrapper";
    tests.Push(t165);

    mut t166: Test[ctx];
    t166.path = "tests/test_nested_scoping_definite_checks_rejected.gst";
    t166.is_negative = 1;
    t166.expected = "unchecked result wrapper";
    tests.Push(t166);

    mut t167: Test[ctx];
    t167.path = "tests/test_move_propagated_linear_struct_invalidates_rejected.gst";
    t167.is_negative = 1;
    t167.expected = "moved";
    tests.Push(t167);

    mut t168: Test[ctx];
    t168.path = "tests/test_move_propagated_linear_enum_invalidates_rejected.gst";
    t168.is_negative = 1;
    t168.expected = "moved";
    tests.Push(t168);

    mut t169: Test[ctx];
    t169.path = "tests/test_pool_type_checking_invalid_alloc_rejected.gst";
    t169.is_negative = 1;
    t169.expected = "type mismatch";
    tests.Push(t169);

    mut t170: Test[ctx];
    t170.path = "tests/test_pool_type_checking_invalid_free_rejected.gst";
    t170.is_negative = 1;
    t170.expected = "type mismatch";
    tests.Push(t170);

    mut t171: Test[ctx];
    t171.path = "tests/test_rc_and_graph_type_checking_invalid_rc_rejected.gst";
    t171.is_negative = 1;
    t171.expected = "TypeMismatch";
    tests.Push(t171);

    mut t172: Test[ctx];
    t172.path = "tests/test_rc_and_graph_type_checking_invalid_graph_rejected.gst";
    t172.is_negative = 1;
    t172.expected = "type mismatch";
    tests.Push(t172);

    mut t173: Test[ctx];
    t173.path = "tests/test_arena_validate_type_checking_invalid_rejected.gst";
    t173.is_negative = 1;
    t173.expected = "type mismatch";
    tests.Push(t173);

    mut t174: Test[ctx];
    t174.path = "tests/test_match_pattern_destructuring_field_not_found_rejected.gst";
    t174.is_negative = 1;
    t174.expected = "not found";
    tests.Push(t174);

    mut t175: Test[ctx];
    t175.path = "tests/test_match_pattern_destructuring_origin_invalidated_rejected.gst";
    t175.is_negative = 1;
    t175.expected = "backing origin";
    tests.Push(t175);

    mut t176: Test[ctx];
    t176.path = "tests/test_move_pod_type_does_not_invalidate.gst";
    t176.is_negative = 0;
    t176.expected = "10\n42";
    tests.Push(t176);

    mut t177: Test[ctx];
    t177.path = "tests/test_monomorphized_pod_collection_is_copyable.gst";
    t177.is_negative = 0;
    t177.expected = "42";
    tests.Push(t177);

    mut t178: Test[ctx];
    t178.path = "tests/test_reinitialized_inout_parameter_accepted.gst";
    t178.is_negative = 0;
    t178.expected = "OK";
    tests.Push(t178);

    mut t179: Test[ctx];
    t179.path = "tests/test_brand_erasure_utility_functions.gst";
    t179.is_negative = 0;
    t179.expected = "1";
    tests.Push(t179);

    mut t180: Test[ctx];
    t180.path = "tests/test_vector_back_mutability_accepted.gst";
    t180.is_negative = 0;
    t180.expected = "20";
    tests.Push(t180);

    mut t181: Test[ctx];
    t181.path = "tests/test_generic_enum_typechecking.gst";
    t181.is_negative = 0;
    t181.expected = "42";
    tests.Push(t181);

    mut t182: Test[ctx];
    t182.path = "compiler/e2e_complex_bootstrap_target.gst";
    t182.is_negative = 0;
    t182.expected = "Active: E2E_Bootstrap\n3\n1";
    tests.Push(t182);

    mut t183: Test[ctx];
    t183.path = "tests/e2e_codegen_assertions.gst";
    t183.is_negative = 0;
    t183.expected = "ALL SELF-HOSTED CODEGEN ASSERTIONS PASSED!";
    tests.Push(t183);

    mut t184: Test[ctx];
    t184.path = "tests/e2e_safe_branding.gst";
    t184.is_negative = 0;
    t184.expected = "100\nHello Arena\n11";
    tests.Push(t184);

    mut t185: Test[ctx];
    t185.path = "compiler/type_dump_entry.gst";
    t185.is_negative = 2;
    t185.expected = "Usage: type_dump <file>";
    tests.Push(t185);

    mut t186: Test[ctx];
    t186.path = "tests/test_scratchpad_origin_propagation.gst";
    t186.is_negative = 0;
    t186.expected = "";
    tests.Push(t186);

    mut t187: Test[ctx];
    t187.path = "tests/test_scratch_assignment_to_branded_field_rejected.gst";
    t187.is_negative = 1;
    t187.expected = "Cannot assign scratchpad-allocated view";
    tests.Push(t187);

    mut t188: Test[ctx];
    t188.path = "tests/test_scratch_return_rejected.gst";
    t188.is_negative = 1;
    t188.expected = "Escape analysis violation";
    tests.Push(t188);

    mut t189: Test[ctx];
    t189.path = "tests/test_scratch_cloned_to_arena_accepted.gst";
    t189.is_negative = 0;
    t189.expected = "";
    tests.Push(t189);

    mut t190: Test[ctx];
    t190.path = "tests/test_field_not_found_rejected.gst";
    t190.is_negative = 1;
    t190.expected = "FieldNotFound";
    tests.Push(t190);

    mut t191: Test[ctx];
    t191.path = "tests/test_bool_wrapper_alignment_rejected.gst";
    t191.is_negative = 1;
    t191.expected = "TypeMismatch";
    tests.Push(t191);

    mut t_path_diag: Test[ctx];
    t_path_diag.path = "tests/test_path_error_diagnostic_rejected.gst";
    t_path_diag.is_negative = 1;
    t_path_diag.is_substring = 1;
    t_path_diag.expected = "TypeError in tests/test_path_error_diagnostic_rejected.gst at line 2:5";
    tests.Push(t_path_diag);

    mut t_imported_path_diag: Test[ctx];
    t_imported_path_diag.path = "tests/test_imported_path_error_rejected.gst";
    t_imported_path_diag.is_negative = 1;
    t_imported_path_diag.is_substring = 1;
    t_imported_path_diag.expected = "TypeError in tests/test_imported_path_error_violating.gst at line 2:5";
    tests.Push(t_imported_path_diag);


    mut t_ctx_reassign: Test[ctx];
    t_ctx_reassign.path = "tests/test_ctx_reassignment_rejected.gst";
    t_ctx_reassign.is_negative = 1;
    t_ctx_reassign.expected = "Reassignment of immutable shared allocator reference";
    tests.Push(t_ctx_reassign);

    mut t_ctx_mut: Test[ctx];
    t_ctx_mut.path = "tests/test_ctx_interior_mutability_valid.gst";
    t_ctx_mut.is_negative = 0;
    t_ctx_mut.expected = "42";
    tests.Push(t_ctx_mut);


    mut t_bool_align_acc: Test[ctx];
    t_bool_align_acc.path = "tests/test_bool_wrapper_alignment_accepted.gst";
    t_bool_align_acc.is_negative = 0;
    t_bool_align_acc.expected = "100";
    tests.Push(t_bool_align_acc);

    mut t_multi_syntax: Test[ctx];
    t_multi_syntax.path = "tests/test_multi_parser_errors_rejected.gst";
    t_multi_syntax.is_negative = 1;
    t_multi_syntax.is_substring = 1;
    t_multi_syntax.expected = "ParserError in tests/test_multi_parser_errors_rejected.gst at line";
    tests.Push(t_multi_syntax);

    mut t_tcs_rejected: Test[ctx];
    t_tcs_rejected.path = "tests/test_tcs_non_pod_on_stack_rejected.gst";
    t_tcs_rejected.is_negative = 1;
    t_tcs_rejected.is_substring = 1;
    t_tcs_rejected.expected = "StackAllocationViolation";
    tests.Push(t_tcs_rejected);

    mut t_fairness_loop: Test[ctx];
    t_fairness_loop.path = "tests/e2e_scheduler_fairness_verification.gst";
    t_fairness_loop.is_negative = 0;
    t_fairness_loop.is_substring = 0;
    t_fairness_loop.expected = "COOPERATIVE_FAIRNESS_SUCCEEDED";
    tests.Push(t_fairness_loop);

    mut t_fairness_rec: Test[ctx];
    t_fairness_rec.path = "tests/e2e_scheduler_recursion_fairness.gst";
    t_fairness_rec.is_negative = 0;
    t_fairness_rec.is_substring = 0;
    t_fairness_rec.expected = "RECURSION_FAIRNESS_SUCCEEDED";
    tests.Push(t_fairness_rec);

    mut t_unbranded_struct_ref_rej: Test[ctx];
    t_unbranded_struct_ref_rej.path = "tests/test_unbranded_struct_reference_rejected.gst";
    t_unbranded_struct_ref_rej.is_negative = 1;
    t_unbranded_struct_ref_rej.expected = "cannot contain ephemeral slice or view field";
    tests.Push(t_unbranded_struct_ref_rej);

    mut t_escape_ref_rej: Test[ctx];
    t_escape_ref_rej.path = "tests/test_escape_reference_rejected.gst";
    t_escape_ref_rej.is_negative = 1;
    t_escape_ref_rej.expected = "Escape analysis violation";
    tests.Push(t_escape_ref_rej);

    mut t_safe_ref_comp: Test[ctx];
    t_safe_ref_comp.path = "tests/test_safe_references_comprehensive_accepted.gst";
    t_safe_ref_comp.is_negative = 0;
    t_safe_ref_comp.expected = "42\n42\n100\n200";
    tests.Push(t_safe_ref_comp);

    mut t_ref_mismatch_rej: Test[ctx];
    t_ref_mismatch_rej.path = "tests/test_reference_mismatched_brand_rejected.gst";
    t_ref_mismatch_rej.is_negative = 1;
    t_ref_mismatch_rej.expected = "Explicit Type Annotation Mismatch";
    tests.Push(t_ref_mismatch_rej);

    mut t_string_esc_viol: Test[ctx];
    t_string_esc_viol.path = "tests/test_string_escape_return_violation_rejected.gst";
    t_string_esc_viol.is_negative = 1;
    t_string_esc_viol.expected = "Escape analysis violation";
    tests.Push(t_string_esc_viol);

    mut t_string_no_ctx: Test[ctx];
    t_string_no_ctx.path = "tests/test_string_concat_no_ctx_rejected.gst";
    t_string_no_ctx.is_negative = 1;
    t_string_no_ctx.expected = "type mismatch";
    tests.Push(t_string_no_ctx);

    mut t_arena_get_ref_e2e: Test[ctx];
    t_arena_get_ref_e2e.path = "tests/e2e_arena_get_ref.gst";
    t_arena_get_ref_e2e.is_negative = 0;
    t_arena_get_ref_e2e.is_substring = 0;
    t_arena_get_ref_e2e.expected = "41\n42";
    tests.Push(t_arena_get_ref_e2e);

    mut t_vector_get_ref_e2e: Test[ctx];
    t_vector_get_ref_e2e.path = "tests/e2e_vector_get_ref.gst";
    t_vector_get_ref_e2e.is_negative = 2;
    t_vector_get_ref_e2e.is_substring = 1;
    t_vector_get_ref_e2e.expected = "Vector bounds check failed";
    tests.Push(t_vector_get_ref_e2e);

    mut t_arena_get_ref_brand_rej: Test[ctx];
    t_arena_get_ref_brand_rej.path = "tests/test_arena_get_ref_brand_mismatch_rejected.gst";
    t_arena_get_ref_brand_rej.is_negative = 1;
    t_arena_get_ref_brand_rej.is_substring = 0;
    t_arena_get_ref_brand_rej.expected = "BrandMismatch";
    tests.Push(t_arena_get_ref_brand_rej);

    mut t_vector_get_ref_escape_rej: Test[ctx];
    t_vector_get_ref_escape_rej.path = "tests/test_vector_get_ref_escape_rejected.gst";
    t_vector_get_ref_escape_rej.is_negative = 1;
    t_vector_get_ref_escape_rej.is_substring = 0;
    t_vector_get_ref_escape_rej.expected = "Escape analysis violation";
    tests.Push(t_vector_get_ref_escape_rej);

    mut t_vector_get_ref_non_vec_rej: Test[ctx];
    t_vector_get_ref_non_vec_rej.path = "tests/test_vector_get_ref_non_vector_rejected.gst";
    t_vector_get_ref_non_vec_rej.is_negative = 1;
    t_vector_get_ref_non_vec_rej.is_substring = 0;
    t_vector_get_ref_non_vec_rej.expected = "Undefined function";
    tests.Push(t_vector_get_ref_non_vec_rej);

    mut t_vector_get_ref_alias_e2e: Test[ctx];
    t_vector_get_ref_alias_e2e.path = "tests/e2e_vector_get_ref_alias.gst";
    t_vector_get_ref_alias_e2e.is_negative = 0;
    t_vector_get_ref_alias_e2e.is_substring = 0;
    t_vector_get_ref_alias_e2e.expected = "22\n44";
    tests.Push(t_vector_get_ref_alias_e2e);

    mut t_vector_get_ref_alias_bad_index_rej: Test[ctx];
    t_vector_get_ref_alias_bad_index_rej.path = "tests/test_vector_get_ref_alias_bad_index_type_rejected.gst";
    t_vector_get_ref_alias_bad_index_rej.is_negative = 1;
    t_vector_get_ref_alias_bad_index_rej.is_substring = 1;
    t_vector_get_ref_alias_bad_index_rej.expected = "std.VectorGetRef expected int or Index argument";
    tests.Push(t_vector_get_ref_alias_bad_index_rej);

    mut t_vector_get_ref_alias_non_vec_rej: Test[ctx];
    t_vector_get_ref_alias_non_vec_rej.path = "tests/test_vector_get_ref_alias_non_vector_rejected.gst";
    t_vector_get_ref_alias_non_vec_rej.is_negative = 1;
    t_vector_get_ref_alias_non_vec_rej.is_substring = 1;
    t_vector_get_ref_alias_non_vec_rej.expected = "std.VectorGetRef first argument must be std.Vector receiver";
    tests.Push(t_vector_get_ref_alias_non_vec_rej);

    mut t_hashmap_get_ref_e2e: Test[ctx];
    t_hashmap_get_ref_e2e.path = "tests/e2e_hashmap_get_ref.gst";
    t_hashmap_get_ref_e2e.is_negative = 0;
    t_hashmap_get_ref_e2e.is_substring = 0;
    t_hashmap_get_ref_e2e.expected = "10\n15\n20";
    tests.Push(t_hashmap_get_ref_e2e);

    mut t_hashmap_get_ref_bad_key_rej: Test[ctx];
    t_hashmap_get_ref_bad_key_rej.path = "tests/test_hashmap_get_ref_bad_key_rejected.gst";
    t_hashmap_get_ref_bad_key_rej.is_negative = 1;
    t_hashmap_get_ref_bad_key_rej.is_substring = 1;
    t_hashmap_get_ref_bad_key_rej.expected = "Key type mismatch for HashMap.GetRef";
    tests.Push(t_hashmap_get_ref_bad_key_rej);

    mut t_hashmap_get_ref_missing_runtime: Test[ctx];
    t_hashmap_get_ref_missing_runtime.path = "tests/test_hashmap_get_ref_missing_runtime_violation.gst";
    t_hashmap_get_ref_missing_runtime.is_negative = 2;
    t_hashmap_get_ref_missing_runtime.is_substring = 1;
    t_hashmap_get_ref_missing_runtime.expected = "HashMap GetRef missing key";
    tests.Push(t_hashmap_get_ref_missing_runtime);

    mut t_safe_arena_subscript_write_rej: Test[ctx];
    t_safe_arena_subscript_write_rej.path = "tests/test_safe_arena_subscript_write_rejected.gst";
    t_safe_arena_subscript_write_rej.is_negative = 1;
    t_safe_arena_subscript_write_rej.is_substring = 1;
    t_safe_arena_subscript_write_rej.expected = "direct subscript writes require unsafe or explicit write APIs";
    tests.Push(t_safe_arena_subscript_write_rej);

    mut t_safe_arena_subscript_field_write_rej: Test[ctx];
    t_safe_arena_subscript_field_write_rej.path = "tests/test_safe_arena_subscript_field_write_rejected.gst";
    t_safe_arena_subscript_field_write_rej.is_negative = 1;
    t_safe_arena_subscript_field_write_rej.is_substring = 1;
    t_safe_arena_subscript_field_write_rej.expected = "direct subscript writes require unsafe or explicit write APIs";
    tests.Push(t_safe_arena_subscript_field_write_rej);

    mut t_safe_vector_subscript_write_rej: Test[ctx];
    t_safe_vector_subscript_write_rej.path = "tests/test_safe_vector_subscript_write_rejected.gst";
    t_safe_vector_subscript_write_rej.is_negative = 1;
    t_safe_vector_subscript_write_rej.is_substring = 1;
    t_safe_vector_subscript_write_rej.expected = "direct subscript writes require unsafe or explicit write APIs";
    tests.Push(t_safe_vector_subscript_write_rej);

    mut t_safe_nested_selector_subscript_write_rej: Test[ctx];
    t_safe_nested_selector_subscript_write_rej.path = "tests/test_safe_nested_selector_subscript_field_write_rejected.gst";
    t_safe_nested_selector_subscript_write_rej.is_negative = 1;
    t_safe_nested_selector_subscript_write_rej.is_substring = 1;
    t_safe_nested_selector_subscript_write_rej.expected = "direct subscript writes require unsafe or explicit write APIs";
    tests.Push(t_safe_nested_selector_subscript_write_rej);

    mut t_unsafe_arena_subscript_write_ok: Test[ctx];
    t_unsafe_arena_subscript_write_ok.path = "tests/e2e_unsafe_arena_subscript_write.gst";
    t_unsafe_arena_subscript_write_ok.is_negative = 0;
    t_unsafe_arena_subscript_write_ok.is_substring = 0;
    t_unsafe_arena_subscript_write_ok.expected = "";
    tests.Push(t_unsafe_arena_subscript_write_ok);

    mut t_unsafe_arena_subscript_field_write_ok: Test[ctx];
    t_unsafe_arena_subscript_field_write_ok.path = "tests/e2e_unsafe_arena_subscript_field_write.gst";
    t_unsafe_arena_subscript_field_write_ok.is_negative = 0;
    t_unsafe_arena_subscript_field_write_ok.is_substring = 0;
    t_unsafe_arena_subscript_field_write_ok.expected = "";
    tests.Push(t_unsafe_arena_subscript_field_write_ok);

    mut t_unsafe_vector_subscript_write_ok: Test[ctx];
    t_unsafe_vector_subscript_write_ok.path = "tests/e2e_unsafe_vector_subscript_write.gst";
    t_unsafe_vector_subscript_write_ok.is_negative = 0;
    t_unsafe_vector_subscript_write_ok.is_substring = 0;
    t_unsafe_vector_subscript_write_ok.expected = "";
    tests.Push(t_unsafe_vector_subscript_write_ok);

    mut t_unsafe_nested_selector_subscript_write_ok: Test[ctx];
    t_unsafe_nested_selector_subscript_write_ok.path = "tests/e2e_unsafe_nested_selector_subscript_field_write.gst";
    t_unsafe_nested_selector_subscript_write_ok.is_negative = 0;
    t_unsafe_nested_selector_subscript_write_ok.is_substring = 0;
    t_unsafe_nested_selector_subscript_write_ok.expected = "";
    tests.Push(t_unsafe_nested_selector_subscript_write_ok);

    mut t_unsafe_function_signature_noop: Test[ctx];
    t_unsafe_function_signature_noop.path = "tests/e2e_unsafe_function_signature_noop.gst";
    t_unsafe_function_signature_noop.is_negative = 0;
    t_unsafe_function_signature_noop.is_substring = 0;
    t_unsafe_function_signature_noop.expected = "";
    tests.Push(t_unsafe_function_signature_noop);

    mut t_step51_raw_pointer_deref_rej: Test[ctx];
    t_step51_raw_pointer_deref_rej.path = "tests/test_raw_pointer_deref_outside_unsafe_rejected.gst";
    t_step51_raw_pointer_deref_rej.is_negative = 1;
    t_step51_raw_pointer_deref_rej.is_substring = 1;
    t_step51_raw_pointer_deref_rej.expected = "Dereferencing raw pointers is strictly prohibited outside 'unsafe' blocks";
    tests.Push(t_step51_raw_pointer_deref_rej);

    mut t_step51_raw_pointer_deref_ok: Test[ctx];
    t_step51_raw_pointer_deref_ok.path = "tests/e2e_raw_pointer_deref_inside_unsafe.gst";
    t_step51_raw_pointer_deref_ok.is_negative = 0;
    t_step51_raw_pointer_deref_ok.is_substring = 0;
    t_step51_raw_pointer_deref_ok.expected = "42";
    tests.Push(t_step51_raw_pointer_deref_ok);

    mut t_step51_raw_pointer_cast_rej: Test[ctx];
    t_step51_raw_pointer_cast_rej.path = "tests/test_raw_pointer_cast_outside_unsafe_rejected.gst";
    t_step51_raw_pointer_cast_rej.is_negative = 1;
    t_step51_raw_pointer_cast_rej.is_substring = 1;
    t_step51_raw_pointer_cast_rej.expected = "Raw pointer casts are strictly prohibited outside 'unsafe' blocks";
    tests.Push(t_step51_raw_pointer_cast_rej);

    mut t_step51_raw_pointer_cast_ok: Test[ctx];
    t_step51_raw_pointer_cast_ok.path = "tests/e2e_raw_pointer_cast_inside_unsafe.gst";
    t_step51_raw_pointer_cast_ok.is_negative = 0;
    t_step51_raw_pointer_cast_ok.is_substring = 0;
    t_step51_raw_pointer_cast_ok.expected = "";
    tests.Push(t_step51_raw_pointer_cast_ok);

    mut t_step51_pointer_arithmetic_rej: Test[ctx];
    t_step51_pointer_arithmetic_rej.path = "tests/test_raw_pointer_arithmetic_outside_unsafe_rejected.gst";
    t_step51_pointer_arithmetic_rej.is_negative = 1;
    t_step51_pointer_arithmetic_rej.is_substring = 1;
    t_step51_pointer_arithmetic_rej.expected = "Pointer arithmetic is strictly prohibited outside 'unsafe' blocks";
    tests.Push(t_step51_pointer_arithmetic_rej);

    mut t_step51_pointer_arithmetic_ok: Test[ctx];
    t_step51_pointer_arithmetic_ok.path = "tests/e2e_raw_pointer_arithmetic_inside_unsafe.gst";
    t_step51_pointer_arithmetic_ok.is_negative = 0;
    t_step51_pointer_arithmetic_ok.is_substring = 0;
    t_step51_pointer_arithmetic_ok.expected = "42";
    tests.Push(t_step51_pointer_arithmetic_ok);

    mut t_step51_unsafe_func_call_rej: Test[ctx];
    t_step51_unsafe_func_call_rej.path = "tests/test_unsafe_func_call_outside_unsafe_rejected.gst";
    t_step51_unsafe_func_call_rej.is_negative = 1;
    t_step51_unsafe_func_call_rej.is_substring = 1;
    t_step51_unsafe_func_call_rej.expected = "Unsafe function calls require an explicit 'unsafe' block";
    tests.Push(t_step51_unsafe_func_call_rej);

    mut t_step51_unsafe_func_call_ok: Test[ctx];
    t_step51_unsafe_func_call_ok.path = "tests/e2e_unsafe_func_call_inside_unsafe.gst";
    t_step51_unsafe_func_call_ok.is_negative = 0;
    t_step51_unsafe_func_call_ok.is_substring = 0;
    t_step51_unsafe_func_call_ok.expected = "42";
    tests.Push(t_step51_unsafe_func_call_ok);

    mut t_step51_unsafe_func_body_raw_ops_ok: Test[ctx];
    t_step51_unsafe_func_body_raw_ops_ok.path = "tests/e2e_unsafe_func_body_raw_ops.gst";
    t_step51_unsafe_func_body_raw_ops_ok.is_negative = 0;
    t_step51_unsafe_func_body_raw_ops_ok.is_substring = 0;
    t_step51_unsafe_func_body_raw_ops_ok.expected = "42";
    tests.Push(t_step51_unsafe_func_body_raw_ops_ok);

    mut t_step51_raw_pointer_local_escape_rej: Test[ctx];
    t_step51_raw_pointer_local_escape_rej.path = "tests/test_raw_pointer_return_derived_local_rejected.gst";
    t_step51_raw_pointer_local_escape_rej.is_negative = 1;
    t_step51_raw_pointer_local_escape_rej.is_substring = 1;
    t_step51_raw_pointer_local_escape_rej.expected = "Returning ephemeral view of type RawPointer";
    tests.Push(t_step51_raw_pointer_local_escape_rej);

    mut t_step51_extern_func_call_rej: Test[ctx];
    t_step51_extern_func_call_rej.path = "tests/test_extern_func_call_outside_unsafe_rejected.gst";
    t_step51_extern_func_call_rej.is_negative = 1;
    t_step51_extern_func_call_rej.is_substring = 1;
    t_step51_extern_func_call_rej.expected = "Direct external/native function calls require an explicit 'unsafe' block";
    tests.Push(t_step51_extern_func_call_rej);

    mut t_step51_extern_func_call_ok: Test[ctx];
    t_step51_extern_func_call_ok.path = "tests/e2e_extern_func_call_inside_unsafe.gst";
    t_step51_extern_func_call_ok.is_negative = 0;
    t_step51_extern_func_call_ok.is_substring = 0;
    t_step51_extern_func_call_ok.expected = "41";
    tests.Push(t_step51_extern_func_call_ok);

    mut t_step51_extern_func_parser_metadata: Test[ctx];
    t_step51_extern_func_parser_metadata.path = "compiler/parser_ffi_metadata_test_entry.gst";
    t_step51_extern_func_parser_metadata.is_negative = 0;
    t_step51_extern_func_parser_metadata.is_substring = 1;
    t_step51_extern_func_parser_metadata.expected = "SUCCESS: extern function parser metadata verified!";
    tests.Push(t_step51_extern_func_parser_metadata);

    mut t_step51_layout_metadata_defaults_1: Test[ctx];
    t_step51_layout_metadata_defaults_1.path = "compiler/parser_layout_metadata_test_entry.gst";
    t_step51_layout_metadata_defaults_1.is_negative = 0;
    t_step51_layout_metadata_defaults_1.is_substring = 1;
    t_step51_layout_metadata_defaults_1.expected = "SUCCESS: struct layout metadata defaults and attributes verified!";
    tests.Push(t_step51_layout_metadata_defaults_1);

    mut t_step51_layout_metadata_defaults_2: Test[ctx];
    t_step51_layout_metadata_defaults_2.path = "compiler/typechecker_layout_metadata_test_entry.gst";
    t_step51_layout_metadata_defaults_2.is_negative = 0;
    t_step51_layout_metadata_defaults_2.is_substring = 1;
    t_step51_layout_metadata_defaults_2.expected = "SUCCESS: payload-safe layout metadata registry helpers verified!";
    tests.Push(t_step51_layout_metadata_defaults_2);

    mut t_step51_layout_ffi_policy_helpers: Test[ctx];
    t_step51_layout_ffi_policy_helpers.path = "compiler/typechecker_layout_ffi_policy_test_entry.gst";
    t_step51_layout_ffi_policy_helpers.is_negative = 0;
    t_step51_layout_ffi_policy_helpers.is_substring = 1;
    t_step51_layout_ffi_policy_helpers.expected = "SUCCESS: inert layout-aware FFI validation helpers verified!";
    tests.Push(t_step51_layout_ffi_policy_helpers);

    mut t_step51_layout_ffi_signature_helpers: Test[ctx];
    t_step51_layout_ffi_signature_helpers.path = "compiler/typechecker_layout_ffi_signature_test_entry.gst";
    t_step51_layout_ffi_signature_helpers.is_negative = 0;
    t_step51_layout_ffi_signature_helpers.is_substring = 1;
    t_step51_layout_ffi_signature_helpers.expected = "SUCCESS: inert signature-level C FFI layout helpers verified!";
    tests.Push(t_step51_layout_ffi_signature_helpers);

    mut t_step51_sandbox_policy_defaults: Test[ctx];
    t_step51_sandbox_policy_defaults.path = "compiler/typechecker_sandbox_policy_test_entry.gst";
    t_step51_sandbox_policy_defaults.is_negative = 0;
    t_step51_sandbox_policy_defaults.is_substring = 1;
    t_step51_sandbox_policy_defaults.expected = "SUCCESS: inert sandbox FFI policy helpers verified!";
    tests.Push(t_step51_sandbox_policy_defaults);

    mut t_step51_address_origin_metadata: Test[ctx];
    t_step51_address_origin_metadata.path = "compiler/typechecker_address_origin_test_entry.gst";
    t_step51_address_origin_metadata.is_negative = 0;
    t_step51_address_origin_metadata.is_substring = 1;
    t_step51_address_origin_metadata.expected = "SUCCESS: inert address-origin metadata helpers verified!";
    tests.Push(t_step51_address_origin_metadata);

    mut t_step51_expression_provenance_carrier: Test[ctx];
    t_step51_expression_provenance_carrier.path = "compiler/typechecker_expression_provenance_test_entry.gst";
    t_step51_expression_provenance_carrier.is_negative = 0;
    t_step51_expression_provenance_carrier.is_substring = 1;
    t_step51_expression_provenance_carrier.expected = "SUCCESS: inert expression provenance carrier verified!";
    tests.Push(t_step51_expression_provenance_carrier);

    mut t_step51_safe_constructor_provenance: Test[ctx];
    t_step51_safe_constructor_provenance.path = "compiler/typechecker_safe_constructor_provenance_test_entry.gst";
    t_step51_safe_constructor_provenance.is_negative = 0;
    t_step51_safe_constructor_provenance.is_substring = 1;
    t_step51_safe_constructor_provenance.expected = "SUCCESS: safe constructor provenance metadata verified!";
    tests.Push(t_step51_safe_constructor_provenance);

    mut t_step51_selector_safe_constructor_provenance: Test[ctx];
    t_step51_selector_safe_constructor_provenance.path = "compiler/typechecker_selector_safe_constructor_provenance_test_entry.gst";
    t_step51_selector_safe_constructor_provenance.is_negative = 0;
    t_step51_selector_safe_constructor_provenance.is_substring = 1;
    t_step51_selector_safe_constructor_provenance.expected = "SUCCESS: selector safe constructor provenance metadata verified!";
    tests.Push(t_step51_selector_safe_constructor_provenance);

    mut t_step51_container_safe_constructor_provenance: Test[ctx];
    t_step51_container_safe_constructor_provenance.path = "compiler/typechecker_container_safe_constructor_provenance_test_entry.gst";
    t_step51_container_safe_constructor_provenance.is_negative = 0;
    t_step51_container_safe_constructor_provenance.is_substring = 1;
    t_step51_container_safe_constructor_provenance.expected = "SUCCESS: container safe constructor provenance metadata verified!";
    tests.Push(t_step51_container_safe_constructor_provenance);

    mut t_step51_container_method_provenance: Test[ctx];
    t_step51_container_method_provenance.path = "compiler/typechecker_container_method_provenance_test_entry.gst";
    t_step51_container_method_provenance.is_negative = 0;
    t_step51_container_method_provenance.is_substring = 1;
    t_step51_container_method_provenance.expected = "SUCCESS: container method write provenance metadata verified!";
    tests.Push(t_step51_container_method_provenance);

    mut t_step51_arena_write_provenance: Test[ctx];
    t_step51_arena_write_provenance.path = "compiler/typechecker_arena_write_provenance_test_entry.gst";
    t_step51_arena_write_provenance.is_negative = 0;
    t_step51_arena_write_provenance.is_substring = 1;
    t_step51_arena_write_provenance.expected = "SUCCESS: Arena.Set/Write provenance metadata verified!";
    tests.Push(t_step51_arena_write_provenance);

    mut t_step51_container_getref_provenance: Test[ctx];
    t_step51_container_getref_provenance.path = "compiler/typechecker_container_getref_provenance_test_entry.gst";
    t_step51_container_getref_provenance.is_negative = 0;
    t_step51_container_getref_provenance.is_substring = 1;
    t_step51_container_getref_provenance.expected = "SUCCESS: container GetRef provenance metadata verified!";
    tests.Push(t_step51_container_getref_provenance);

    mut t_step51_hashmap_get_value_provenance: Test[ctx];
    t_step51_hashmap_get_value_provenance.path = "compiler/typechecker_hashmap_get_value_provenance_test_entry.gst";
    t_step51_hashmap_get_value_provenance.is_negative = 0;
    t_step51_hashmap_get_value_provenance.is_substring = 1;
    t_step51_hashmap_get_value_provenance.expected = "SUCCESS: HashMap.Get value provenance metadata verified!";
    tests.Push(t_step51_hashmap_get_value_provenance);

    mut t_step51_hashmap_get_value_field_provenance: Test[ctx];
    t_step51_hashmap_get_value_field_provenance.path = "compiler/typechecker_hashmap_get_value_field_provenance_test_entry.gst";
    t_step51_hashmap_get_value_field_provenance.is_negative = 0;
    t_step51_hashmap_get_value_field_provenance.is_substring = 1;
    t_step51_hashmap_get_value_field_provenance.expected = "SUCCESS: HashMap.Get value field provenance metadata verified!";
    tests.Push(t_step51_hashmap_get_value_field_provenance);

    mut t_step51_std_vector_getref_provenance: Test[ctx];
    t_step51_std_vector_getref_provenance.path = "compiler/typechecker_std_vector_getref_provenance_test_entry.gst";
    t_step51_std_vector_getref_provenance.is_negative = 0;
    t_step51_std_vector_getref_provenance.is_substring = 1;
    t_step51_std_vector_getref_provenance.expected = "SUCCESS: std.VectorGetRef provenance metadata verified!";
    tests.Push(t_step51_std_vector_getref_provenance);

    mut t_step51_std_hashmap_getref_provenance: Test[ctx];
    t_step51_std_hashmap_getref_provenance.path = "compiler/typechecker_std_hashmap_getref_provenance_test_entry.gst";
    t_step51_std_hashmap_getref_provenance.is_negative = 0;
    t_step51_std_hashmap_getref_provenance.is_substring = 1;
    t_step51_std_hashmap_getref_provenance.expected = "SUCCESS: std.HashMapGetRef provenance metadata verified!";
    tests.Push(t_step51_std_hashmap_getref_provenance);

    mut t_step51_std_hashmap_getref_selector_alias_provenance: Test[ctx];
    t_step51_std_hashmap_getref_selector_alias_provenance.path = "compiler/typechecker_std_hashmap_getref_selector_alias_provenance_test_entry.gst";
    t_step51_std_hashmap_getref_selector_alias_provenance.is_negative = 0;
    t_step51_std_hashmap_getref_selector_alias_provenance.is_substring = 1;
    t_step51_std_hashmap_getref_selector_alias_provenance.expected = "SUCCESS: std.HashMapGetRef selector alias provenance metadata verified!";
    tests.Push(t_step51_std_hashmap_getref_selector_alias_provenance);

    mut t_step51_std_vector_getref_selector_alias_provenance: Test[ctx];
    t_step51_std_vector_getref_selector_alias_provenance.path = "compiler/typechecker_std_vector_getref_selector_alias_provenance_test_entry.gst";
    t_step51_std_vector_getref_selector_alias_provenance.is_negative = 0;
    t_step51_std_vector_getref_selector_alias_provenance.is_substring = 1;
    t_step51_std_vector_getref_selector_alias_provenance.expected = "SUCCESS: std.VectorGetRef selector alias provenance metadata verified!";
    tests.Push(t_step51_std_vector_getref_selector_alias_provenance);

    mut t_step51_reference_selector_alias_provenance: Test[ctx];
    t_step51_reference_selector_alias_provenance.path = "compiler/typechecker_reference_selector_alias_provenance_test_entry.gst";
    t_step51_reference_selector_alias_provenance.is_negative = 0;
    t_step51_reference_selector_alias_provenance.is_substring = 1;
    t_step51_reference_selector_alias_provenance.expected = "SUCCESS: reference selector alias provenance metadata verified!";
    tests.Push(t_step51_reference_selector_alias_provenance);

    mut t_step51_variable_provenance_bindings: Test[ctx];
    t_step51_variable_provenance_bindings.path = "compiler/typechecker_variable_provenance_test_entry.gst";
    t_step51_variable_provenance_bindings.is_negative = 0;
    t_step51_variable_provenance_bindings.is_substring = 1;
    t_step51_variable_provenance_bindings.expected = "SUCCESS: inert variable provenance binding/assignment metadata verified!";
    tests.Push(t_step51_variable_provenance_bindings);

    mut t_step51_return_provenance_capture: Test[ctx];
    t_step51_return_provenance_capture.path = "compiler/typechecker_return_provenance_test_entry.gst";
    t_step51_return_provenance_capture.is_negative = 0;
    t_step51_return_provenance_capture.is_substring = 1;
    t_step51_return_provenance_capture.expected = "SUCCESS: inert return expression provenance metadata verified!";
    tests.Push(t_step51_return_provenance_capture);

    mut t_step51_function_call_provenance: Test[ctx];
    t_step51_function_call_provenance.path = "compiler/typechecker_function_call_provenance_test_entry.gst";
    t_step51_function_call_provenance.is_negative = 0;
    t_step51_function_call_provenance.is_substring = 1;
    t_step51_function_call_provenance.expected = "SUCCESS: inert function-call return provenance metadata verified!";
    tests.Push(t_step51_function_call_provenance);

    mut t_step51_aggregate_field_provenance: Test[ctx];
    t_step51_aggregate_field_provenance.path = "compiler/typechecker_aggregate_field_provenance_test_entry.gst";
    t_step51_aggregate_field_provenance.is_negative = 0;
    t_step51_aggregate_field_provenance.is_substring = 1;
    t_step51_aggregate_field_provenance.expected = "SUCCESS: inert aggregate-field provenance metadata verified!";
    tests.Push(t_step51_aggregate_field_provenance);

    mut t_step51_container_provenance: Test[ctx];
    t_step51_container_provenance.path = "compiler/typechecker_container_provenance_test_entry.gst";
    t_step51_container_provenance.is_negative = 0;
    t_step51_container_provenance.is_substring = 1;
    t_step51_container_provenance.expected = "SUCCESS: inert container provenance metadata verified!";
    tests.Push(t_step51_container_provenance);

    mut t_step51_non_laundering_return_enforcement: Test[ctx];
    t_step51_non_laundering_return_enforcement.path = "compiler/typechecker_non_laundering_return_test_entry.gst";
    t_step51_non_laundering_return_enforcement.is_negative = 0;
    t_step51_non_laundering_return_enforcement.is_substring = 1;
    t_step51_non_laundering_return_enforcement.expected = "SUCCESS: non-laundering branded return enforcement verified!";
    tests.Push(t_step51_non_laundering_return_enforcement);

    mut t_step51_non_laundering_binding_enforcement: Test[ctx];
    t_step51_non_laundering_binding_enforcement.path = "compiler/typechecker_non_laundering_binding_test_entry.gst";
    t_step51_non_laundering_binding_enforcement.is_negative = 0;
    t_step51_non_laundering_binding_enforcement.is_substring = 1;
    t_step51_non_laundering_binding_enforcement.expected = "SUCCESS: non-laundering safe-branded binding enforcement verified!";
    tests.Push(t_step51_non_laundering_binding_enforcement);

    mut t_step51_non_laundering_call_enforcement: Test[ctx];
    t_step51_non_laundering_call_enforcement.path = "compiler/typechecker_non_laundering_call_test_entry.gst";
    t_step51_non_laundering_call_enforcement.is_negative = 0;
    t_step51_non_laundering_call_enforcement.is_substring = 1;
    t_step51_non_laundering_call_enforcement.expected = "SUCCESS: non-laundering safe-branded call argument enforcement verified!";
    tests.Push(t_step51_non_laundering_call_enforcement);

    mut t_step51_non_laundering_field_enforcement: Test[ctx];
    t_step51_non_laundering_field_enforcement.path = "compiler/typechecker_non_laundering_field_test_entry.gst";
    t_step51_non_laundering_field_enforcement.is_negative = 0;
    t_step51_non_laundering_field_enforcement.is_substring = 1;
    t_step51_non_laundering_field_enforcement.expected = "SUCCESS: non-laundering safe-branded aggregate field enforcement verified!";
    tests.Push(t_step51_non_laundering_field_enforcement);

    mut t_step51_non_laundering_container_enforcement: Test[ctx];
    t_step51_non_laundering_container_enforcement.path = "compiler/typechecker_non_laundering_container_test_entry.gst";
    t_step51_non_laundering_container_enforcement.is_negative = 0;
    t_step51_non_laundering_container_enforcement.is_substring = 1;
    t_step51_non_laundering_container_enforcement.expected = "SUCCESS: non-laundering safe-branded container element enforcement verified!";
    tests.Push(t_step51_non_laundering_container_enforcement);

    mut t_step51_non_laundering_container_method_enforcement: Test[ctx];
    t_step51_non_laundering_container_method_enforcement.path = "compiler/typechecker_non_laundering_container_method_test_entry.gst";
    t_step51_non_laundering_container_method_enforcement.is_negative = 0;
    t_step51_non_laundering_container_method_enforcement.is_substring = 1;
    t_step51_non_laundering_container_method_enforcement.expected = "SUCCESS: non-laundering safe-branded container method raw/sandbox/safe Push/Set/Insert storage enforcement verified!";
    tests.Push(t_step51_non_laundering_container_method_enforcement);

    mut t_step51_non_laundering_arena_write_enforcement: Test[ctx];
    t_step51_non_laundering_arena_write_enforcement.path = "compiler/typechecker_non_laundering_arena_write_test_entry.gst";
    t_step51_non_laundering_arena_write_enforcement.is_negative = 0;
    t_step51_non_laundering_arena_write_enforcement.is_substring = 1;
    t_step51_non_laundering_arena_write_enforcement.expected = "SUCCESS: non-laundering Arena.Set/Write raw/sandbox enforcement verified!";
    tests.Push(t_step51_non_laundering_arena_write_enforcement);

    mut t_step51_non_laundering_reference_selector_enforcement: Test[ctx];
    t_step51_non_laundering_reference_selector_enforcement.path = "compiler/typechecker_non_laundering_reference_selector_test_entry.gst";
    t_step51_non_laundering_reference_selector_enforcement.is_negative = 0;
    t_step51_non_laundering_reference_selector_enforcement.is_substring = 1;
    t_step51_non_laundering_reference_selector_enforcement.expected = "SUCCESS: reference selector raw/sandbox non-laundering enforcement verified!";
    tests.Push(t_step51_non_laundering_reference_selector_enforcement);

    mut t_step51_non_laundering_hashmap_get_value_enforcement: Test[ctx];
    t_step51_non_laundering_hashmap_get_value_enforcement.path = "compiler/typechecker_non_laundering_hashmap_get_value_test_entry.gst";
    t_step51_non_laundering_hashmap_get_value_enforcement.is_negative = 0;
    t_step51_non_laundering_hashmap_get_value_enforcement.is_substring = 1;
    t_step51_non_laundering_hashmap_get_value_enforcement.expected = "SUCCESS: HashMap.Get value non-laundering enforcement verified!";
    tests.Push(t_step51_non_laundering_hashmap_get_value_enforcement);

    mut t_step51_non_laundering_hashmap_get_value_field_enforcement: Test[ctx];
    t_step51_non_laundering_hashmap_get_value_field_enforcement.path = "compiler/typechecker_non_laundering_hashmap_get_value_field_test_entry.gst";
    t_step51_non_laundering_hashmap_get_value_field_enforcement.is_negative = 0;
    t_step51_non_laundering_hashmap_get_value_field_enforcement.is_substring = 1;
    t_step51_non_laundering_hashmap_get_value_field_enforcement.expected = "SUCCESS: HashMap.Get value field non-laundering enforcement verified!";
    tests.Push(t_step51_non_laundering_hashmap_get_value_field_enforcement);

    mut t_step52_linear_resource_metadata: Test[ctx];
    t_step52_linear_resource_metadata.path = "compiler/typechecker_linear_resource_metadata_test_entry.gst";
    t_step52_linear_resource_metadata.is_negative = 0;
    t_step52_linear_resource_metadata.is_substring = 1;
    t_step52_linear_resource_metadata.expected = "SUCCESS: inert linear resource metadata opt-in verified!";
    tests.Push(t_step52_linear_resource_metadata);

    mut t_step52_linear_destructor_metadata: Test[ctx];
    t_step52_linear_destructor_metadata.path = "compiler/typechecker_linear_destructor_metadata_test_entry.gst";
    t_step52_linear_destructor_metadata.is_negative = 0;
    t_step52_linear_destructor_metadata.is_substring = 1;
    t_step52_linear_destructor_metadata.expected = "SUCCESS: inert linear destructor metadata verified!";
    tests.Push(t_step52_linear_destructor_metadata);

    mut t_step52_linear_resource_registry: Test[ctx];
    t_step52_linear_resource_registry.path = "compiler/typechecker_linear_resource_registry_test_entry.gst";
    t_step52_linear_resource_registry.is_negative = 0;
    t_step52_linear_resource_registry.is_substring = 1;
    t_step52_linear_resource_registry.expected = "SUCCESS: inert open linear resource registry verified!";
    tests.Push(t_step52_linear_resource_registry);

    mut t_step52_linear_transfer_state: Test[ctx];
    t_step52_linear_transfer_state.path = "compiler/typechecker_linear_transfer_state_test_entry.gst";
    t_step52_linear_transfer_state.is_negative = 0;
    t_step52_linear_transfer_state.is_substring = 1;
    t_step52_linear_transfer_state.expected = "SUCCESS: inert linear transfer-state metadata verified!";
    tests.Push(t_step52_linear_transfer_state);

    mut t_step52_resource_type_shape: Test[ctx];
    t_step52_resource_type_shape.path = "compiler/typechecker_resource_type_shape_test_entry.gst";
    t_step52_resource_type_shape.is_negative = 0;
    t_step52_resource_type_shape.is_substring = 1;
    t_step52_resource_type_shape.expected = "SUCCESS: inert Resource type-shape helpers verified!";
    tests.Push(t_step52_resource_type_shape);

    mut t_step52_resource_registry_bridge: Test[ctx];
    t_step52_resource_registry_bridge.path = "compiler/typechecker_resource_registry_bridge_test_entry.gst";
    t_step52_resource_registry_bridge.is_negative = 0;
    t_step52_resource_registry_bridge.is_substring = 1;
    t_step52_resource_registry_bridge.expected = "SUCCESS: inert Resource registry bridge helpers verified!";
    tests.Push(t_step52_resource_registry_bridge);

    mut t_step52_resource_validation_predicates: Test[ctx];
    t_step52_resource_validation_predicates.path = "compiler/typechecker_resource_validation_predicates_test_entry.gst";
    t_step52_resource_validation_predicates.is_negative = 0;
    t_step52_resource_validation_predicates.is_substring = 1;
    t_step52_resource_validation_predicates.expected = "SUCCESS: inert linear resource validation predicates verified!";
    tests.Push(t_step52_resource_validation_predicates);

    mut t_step52_resource_diagnostics: Test[ctx];
    t_step52_resource_diagnostics.path = "compiler/typechecker_resource_diagnostics_test_entry.gst";
    t_step52_resource_diagnostics.is_negative = 0;
    t_step52_resource_diagnostics.is_substring = 1;
    t_step52_resource_diagnostics.expected = "SUCCESS: inert linear resource diagnostics verified!";
    tests.Push(t_step52_resource_diagnostics);

    mut t_step52_linear_resource_scope_state: Test[ctx];
    t_step52_linear_resource_scope_state.path = "compiler/typechecker_linear_resource_scope_state_test_entry.gst";
    t_step52_linear_resource_scope_state.is_negative = 0;
    t_step52_linear_resource_scope_state.is_substring = 1;
    t_step52_linear_resource_scope_state.expected = "SUCCESS: inert linear resource scope-state snapshots verified!";
    tests.Push(t_step52_linear_resource_scope_state);

    mut t_step52_resource_generic_resolver: Test[ctx];
    t_step52_resource_generic_resolver.path = "compiler/typechecker_resource_generic_resolver_test_entry.gst";
    t_step52_resource_generic_resolver.is_negative = 0;
    t_step52_resource_generic_resolver.is_substring = 1;
    t_step52_resource_generic_resolver.expected = "SUCCESS: inert Resource generic resolver bridge verified!";
    tests.Push(t_step52_resource_generic_resolver);

    mut t_step52_resource_declaration_bridge: Test[ctx];
    t_step52_resource_declaration_bridge.path = "compiler/typechecker_resource_declaration_bridge_test_entry.gst";
    t_step52_resource_declaration_bridge.is_negative = 0;
    t_step52_resource_declaration_bridge.is_substring = 1;
    t_step52_resource_declaration_bridge.expected = "SUCCESS: inert Resource declaration helper bridge verified!";
    tests.Push(t_step52_resource_declaration_bridge);

    mut t_step52_resource_assignment_bridge: Test[ctx];
    t_step52_resource_assignment_bridge.path = "compiler/typechecker_resource_assignment_bridge_test_entry.gst";
    t_step52_resource_assignment_bridge.is_negative = 0;
    t_step52_resource_assignment_bridge.is_substring = 1;
    t_step52_resource_assignment_bridge.expected = "SUCCESS: inert Resource assignment helper bridge verified!";
    tests.Push(t_step52_resource_assignment_bridge);

    mut t_step52_resource_decl_assignment_tracking: Test[ctx];
    t_step52_resource_decl_assignment_tracking.path = "compiler/typechecker_resource_decl_assignment_tracking_test_entry.gst";
    t_step52_resource_decl_assignment_tracking.is_negative = 0;
    t_step52_resource_decl_assignment_tracking.is_substring = 1;
    t_step52_resource_decl_assignment_tracking.expected = "SUCCESS: compiler-backed Resource declaration/assignment tracking verified!";
    tests.Push(t_step52_resource_decl_assignment_tracking);

    mut t_step52_resource_move_assignment_tracking: Test[ctx];
    t_step52_resource_move_assignment_tracking.path = "compiler/typechecker_resource_move_assignment_tracking_test_entry.gst";
    t_step52_resource_move_assignment_tracking.is_negative = 0;
    t_step52_resource_move_assignment_tracking.is_substring = 1;
    t_step52_resource_move_assignment_tracking.expected = "SUCCESS: compiler-backed Resource move assignment tracking verified!";
    tests.Push(t_step52_resource_move_assignment_tracking);

    mut t_step52_resource_destructor_call_tracking: Test[ctx];
    t_step52_resource_destructor_call_tracking.path = "compiler/typechecker_resource_destructor_call_tracking_test_entry.gst";
    t_step52_resource_destructor_call_tracking.is_negative = 0;
    t_step52_resource_destructor_call_tracking.is_substring = 1;
    t_step52_resource_destructor_call_tracking.expected = "SUCCESS: compiler-backed Resource destructor call tracking verified!";
    tests.Push(t_step52_resource_destructor_call_tracking);

    mut t_step52_resource_double_close_rejected: Test[ctx];
    t_step52_resource_double_close_rejected.path = "compiler/typechecker_resource_double_close_rejected_test_entry.gst";
    t_step52_resource_double_close_rejected.is_negative = 0;
    t_step52_resource_double_close_rejected.is_substring = 1;
    t_step52_resource_double_close_rejected.expected = "SUCCESS: compiler-backed Resource double-close rejection verified!";
    tests.Push(t_step52_resource_double_close_rejected);

    mut t_step52_resource_close_after_move_rejected: Test[ctx];
    t_step52_resource_close_after_move_rejected.path = "compiler/typechecker_resource_close_after_move_rejected_test_entry.gst";
    t_step52_resource_close_after_move_rejected.is_negative = 0;
    t_step52_resource_close_after_move_rejected.is_substring = 1;
    t_step52_resource_close_after_move_rejected.expected = "SUCCESS: compiler-backed Resource close-after-move rejection verified!";
    tests.Push(t_step52_resource_close_after_move_rejected);

    mut t_step52_resource_destructor_scheduled_rejected: Test[ctx];
    t_step52_resource_destructor_scheduled_rejected.path = "compiler/typechecker_resource_destructor_scheduled_rejected_test_entry.gst";
    t_step52_resource_destructor_scheduled_rejected.is_negative = 0;
    t_step52_resource_destructor_scheduled_rejected.is_substring = 1;
    t_step52_resource_destructor_scheduled_rejected.expected = "SUCCESS: compiler-backed Resource destructor-scheduled rejection verified!";
    tests.Push(t_step52_resource_destructor_scheduled_rejected);

    mut t_step52_resource_missing_cleanup_diagnostic: Test[ctx];
    t_step52_resource_missing_cleanup_diagnostic.path = "compiler/typechecker_resource_missing_cleanup_diagnostic_test_entry.gst";
    t_step52_resource_missing_cleanup_diagnostic.is_negative = 0;
    t_step52_resource_missing_cleanup_diagnostic.is_substring = 1;
    t_step52_resource_missing_cleanup_diagnostic.expected = "SUCCESS: compiler-backed Resource missing-cleanup diagnostic helper verified!";
    tests.Push(t_step52_resource_missing_cleanup_diagnostic);

    mut t_step52_resource_missing_cleanup_first_report: Test[ctx];
    t_step52_resource_missing_cleanup_first_report.path = "compiler/typechecker_resource_missing_cleanup_first_report_test_entry.gst";
    t_step52_resource_missing_cleanup_first_report.is_negative = 0;
    t_step52_resource_missing_cleanup_first_report.is_substring = 1;
    t_step52_resource_missing_cleanup_first_report.expected = "SUCCESS: compiler-backed Resource first pending cleanup report helper verified!";
    tests.Push(t_step52_resource_missing_cleanup_first_report);

    mut t_step52_resource_cleanup_boundary_validation: Test[ctx];
    t_step52_resource_cleanup_boundary_validation.path = "compiler/typechecker_resource_cleanup_boundary_validation_test_entry.gst";
    t_step52_resource_cleanup_boundary_validation.is_negative = 0;
    t_step52_resource_cleanup_boundary_validation.is_substring = 1;
    t_step52_resource_cleanup_boundary_validation.expected = "SUCCESS: compiler-backed Resource cleanup boundary validation helper verified!";
    tests.Push(t_step52_resource_cleanup_boundary_validation);

    mut t_step52_resource_cleanup_boundary_terminal_states: Test[ctx];
    t_step52_resource_cleanup_boundary_terminal_states.path = "compiler/typechecker_resource_cleanup_boundary_terminal_states_test_entry.gst";
    t_step52_resource_cleanup_boundary_terminal_states.is_negative = 0;
    t_step52_resource_cleanup_boundary_terminal_states.is_substring = 1;
    t_step52_resource_cleanup_boundary_terminal_states.expected = "SUCCESS: compiler-backed Resource cleanup boundary terminal-state coverage verified!";
    tests.Push(t_step52_resource_cleanup_boundary_terminal_states);

    mut t_step52_resource_cleanup_boundary_mixed_states: Test[ctx];
    t_step52_resource_cleanup_boundary_mixed_states.path = "compiler/typechecker_resource_cleanup_boundary_mixed_states_test_entry.gst";
    t_step52_resource_cleanup_boundary_mixed_states.is_negative = 0;
    t_step52_resource_cleanup_boundary_mixed_states.is_substring = 1;
    t_step52_resource_cleanup_boundary_mixed_states.expected = "SUCCESS: compiler-backed Resource cleanup boundary mixed-state coverage verified!";
    tests.Push(t_step52_resource_cleanup_boundary_mixed_states);

    mut t_step52_resource_scope_exit_cleanup_boundary: Test[ctx];
    t_step52_resource_scope_exit_cleanup_boundary.path = "compiler/typechecker_resource_scope_exit_cleanup_boundary_test_entry.gst";
    t_step52_resource_scope_exit_cleanup_boundary.is_negative = 0;
    t_step52_resource_scope_exit_cleanup_boundary.is_substring = 1;
    t_step52_resource_scope_exit_cleanup_boundary.expected = "SUCCESS: compiler-backed Resource scope-exit cleanup boundary helper verified!";
    tests.Push(t_step52_resource_scope_exit_cleanup_boundary);

    mut t_step52_resource_function_exit_cleanup_integration: Test[ctx];
    t_step52_resource_function_exit_cleanup_integration.path = "compiler/typechecker_resource_function_exit_cleanup_integration_test_entry.gst";
    t_step52_resource_function_exit_cleanup_integration.is_negative = 0;
    t_step52_resource_function_exit_cleanup_integration.is_substring = 1;
    t_step52_resource_function_exit_cleanup_integration.expected = "SUCCESS: compiler-backed Resource function-exit cleanup integration verified!";
    tests.Push(t_step52_resource_function_exit_cleanup_integration);

    mut t_step52_resource_return_cleanup_integration: Test[ctx];
    t_step52_resource_return_cleanup_integration.path = "compiler/typechecker_resource_return_cleanup_integration_test_entry.gst";
    t_step52_resource_return_cleanup_integration.is_negative = 0;
    t_step52_resource_return_cleanup_integration.is_substring = 1;
    t_step52_resource_return_cleanup_integration.expected = "SUCCESS: compiler-backed Resource return cleanup integration verified!";
    tests.Push(t_step52_resource_return_cleanup_integration);

    mut t_step52_resource_missing_cleanup_dedup: Test[ctx];
    t_step52_resource_missing_cleanup_dedup.path = "compiler/typechecker_resource_missing_cleanup_dedup_test_entry.gst";
    t_step52_resource_missing_cleanup_dedup.is_negative = 0;
    t_step52_resource_missing_cleanup_dedup.is_substring = 1;
    t_step52_resource_missing_cleanup_dedup.expected = "SUCCESS: compiler-backed Resource missing-cleanup dedup verified!";
    tests.Push(t_step52_resource_missing_cleanup_dedup);

    mut t_step52_resource_return_cleanup_dedup_integration: Test[ctx];
    t_step52_resource_return_cleanup_dedup_integration.path = "compiler/typechecker_resource_return_cleanup_dedup_integration_test_entry.gst";
    t_step52_resource_return_cleanup_dedup_integration.is_negative = 0;
    t_step52_resource_return_cleanup_dedup_integration.is_substring = 1;
    t_step52_resource_return_cleanup_dedup_integration.expected = "SUCCESS: compiler-backed Resource return cleanup dedup integration verified!";
    tests.Push(t_step52_resource_return_cleanup_dedup_integration);

    mut t_step52_resource_return_cleanup_terminal_states: Test[ctx];
    t_step52_resource_return_cleanup_terminal_states.path = "compiler/typechecker_resource_return_cleanup_terminal_states_test_entry.gst";
    t_step52_resource_return_cleanup_terminal_states.is_negative = 0;
    t_step52_resource_return_cleanup_terminal_states.is_substring = 1;
    t_step52_resource_return_cleanup_terminal_states.expected = "SUCCESS: compiler-backed Resource return cleanup terminal-state integration verified!";
    tests.Push(t_step52_resource_return_cleanup_terminal_states);

    mut t_step52_resource_return_cleanup_moved_terminal_states: Test[ctx];
    t_step52_resource_return_cleanup_moved_terminal_states.path = "compiler/typechecker_resource_return_cleanup_moved_terminal_states_test_entry.gst";
    t_step52_resource_return_cleanup_moved_terminal_states.is_negative = 0;
    t_step52_resource_return_cleanup_moved_terminal_states.is_substring = 1;
    t_step52_resource_return_cleanup_moved_terminal_states.expected = "SUCCESS: compiler-backed Resource return cleanup moved terminal-state integration verified!";
    tests.Push(t_step52_resource_return_cleanup_moved_terminal_states);

    mut t_step52_resource_function_exit_terminal_states: Test[ctx];
    t_step52_resource_function_exit_terminal_states.path = "compiler/typechecker_resource_function_exit_terminal_states_test_entry.gst";
    t_step52_resource_function_exit_terminal_states.is_negative = 0;
    t_step52_resource_function_exit_terminal_states.is_substring = 1;
    t_step52_resource_function_exit_terminal_states.expected = "SUCCESS: compiler-backed Resource function-exit terminal-state integration verified!";
    tests.Push(t_step52_resource_function_exit_terminal_states);

    mut t_step52_resource_function_exit_moved_terminal_states: Test[ctx];
    t_step52_resource_function_exit_moved_terminal_states.path = "compiler/typechecker_resource_function_exit_moved_terminal_states_test_entry.gst";
    t_step52_resource_function_exit_moved_terminal_states.is_negative = 0;
    t_step52_resource_function_exit_moved_terminal_states.is_substring = 1;
    t_step52_resource_function_exit_moved_terminal_states.expected = "SUCCESS: compiler-backed Resource function-exit moved terminal-state integration verified!";
    tests.Push(t_step52_resource_function_exit_moved_terminal_states);

    mut t_step52_resource_return_cleanup_mixed_terminal_states: Test[ctx];
    t_step52_resource_return_cleanup_mixed_terminal_states.path = "compiler/typechecker_resource_return_cleanup_mixed_terminal_states_test_entry.gst";
    t_step52_resource_return_cleanup_mixed_terminal_states.is_negative = 0;
    t_step52_resource_return_cleanup_mixed_terminal_states.is_substring = 1;
    t_step52_resource_return_cleanup_mixed_terminal_states.expected = "SUCCESS: compiler-backed Resource return cleanup mixed terminal-state integration verified!";
    tests.Push(t_step52_resource_return_cleanup_mixed_terminal_states);

    mut t_step52_resource_function_exit_mixed_terminal_states: Test[ctx];
    t_step52_resource_function_exit_mixed_terminal_states.path = "compiler/typechecker_resource_function_exit_mixed_terminal_states_test_entry.gst";
    t_step52_resource_function_exit_mixed_terminal_states.is_negative = 0;
    t_step52_resource_function_exit_mixed_terminal_states.is_substring = 1;
    t_step52_resource_function_exit_mixed_terminal_states.expected = "SUCCESS: compiler-backed Resource function-exit mixed terminal-state integration verified!";
    tests.Push(t_step52_resource_function_exit_mixed_terminal_states);

    mut t_step52_resource_use_after_move_pass: Test[ctx];
    t_step52_resource_use_after_move_pass.path = "compiler/typechecker_resource_use_after_move_pass_test_entry.gst";
    t_step52_resource_use_after_move_pass.is_negative = 0;
    t_step52_resource_use_after_move_pass.is_substring = 1;
    t_step52_resource_use_after_move_pass.expected = "SUCCESS: compiler-backed Resource use-after-move pass path verified!";
    tests.Push(t_step52_resource_use_after_move_pass);

    mut t_step52_resource_use_after_move_rejected: Test[ctx];
    t_step52_resource_use_after_move_rejected.path = "compiler/typechecker_resource_use_after_move_rejected_test_entry.gst";
    t_step52_resource_use_after_move_rejected.is_negative = 0;
    t_step52_resource_use_after_move_rejected.is_substring = 1;
    t_step52_resource_use_after_move_rejected.expected = "SUCCESS: compiler-backed Resource use-after-move rejection verified!";
    tests.Push(t_step52_resource_use_after_move_rejected);

    mut t_step52_resource_lifecycle_ops: Test[ctx];
    t_step52_resource_lifecycle_ops.path = "compiler/typechecker_resource_lifecycle_ops_test_entry.gst";
    t_step52_resource_lifecycle_ops.is_negative = 0;
    t_step52_resource_lifecycle_ops.is_substring = 1;
    t_step52_resource_lifecycle_ops.expected = "SUCCESS: inert linear resource lifecycle operation helpers verified!";
    tests.Push(t_step52_resource_lifecycle_ops);

    mut t_step52_resource_cleanup_queries: Test[ctx];
    t_step52_resource_cleanup_queries.path = "compiler/typechecker_resource_cleanup_queries_test_entry.gst";
    t_step52_resource_cleanup_queries.is_negative = 0;
    t_step52_resource_cleanup_queries.is_substring = 1;
    t_step52_resource_cleanup_queries.expected = "SUCCESS: inert linear resource cleanup query helpers verified!";
    tests.Push(t_step52_resource_cleanup_queries);

    os.LogStr("🏃 Starting self-hosted Gust test suite...");
    mut chan: std.Channel[int, ctx] := std.ChannelNew(ctx);

    mut i := 0;
    while i < len(tests) { 
        mut t := tests[i];
        mut arg: TestTaskArg[ctx];
        arg.test = t;
        arg.chan = chan;

        mut arg_idx := os.ArenaAlloc(ctx) as Index[TestTaskArg[ctx], ctx];
        ctx.Set(arg_idx, arg);

        unsafe {
            std.Spawn(test_worker_task, &ctx[arg_idx]);
        }
        i = i + 1;
    }

    mut passed_count := 0;
    mut failed_count := 0;

    mut j := 0;
    while j < len(tests) {
        mut ok := chan.Recv();
        if ok == 1 {
            passed_count = passed_count + 1;
        } else {
            failed_count = failed_count + 1;
        }
        j = j + 1;
    }

    mut summary_msg := std.Format("🏁 Test Suite Finished. Passed: %d, Failed: %d", passed_count, failed_count);
    os.LogStr(summary_msg);
    os.LogStr("-----------------------------------------");

    if failed_count > 0 {
        os.Exit(1);
    } else {
        os.Exit(0);
    }
}
