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

        mut log_content := os.ReadFile(local_ctx, temp_log);
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
        if t.is_substring == 1 {
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

    mut t18: Test[ctx];
    t18.path = "tests/test_unresolved_selector_rejected.gst";
    t18.is_negative = 1;
    t18.expected = "UnresolvedSelector";
    tests.Push(t18);

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

    os.LogStr("🏃 Starting self-hosted Gust test suite...");
    mut chan: std.Channel[int, ctx] := std.ChannelNew(ctx);

    mut i := 0;
    while i < len(tests) {
        mut t := tests[i];
        mut arg: TestTaskArg[ctx];
        arg.test = t;
        arg.chan = chan;

        mut arg_idx := os.ArenaAlloc(ctx) as Index[TestTaskArg[ctx], ctx];
        ctx[arg_idx] = arg;

        std.Spawn(test_worker_task, &ctx[arg_idx]);
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
