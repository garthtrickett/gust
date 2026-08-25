import "ast.gst" as ast;
import "mir.gst" as mir;

// Patch 21.10 typed-AST lowering for the bounded filesystem and allocation
// cohort. Admission is structural: no source path, fixture name, or declared
// struct name is used to choose a backend path.

type MirNativeFilesystemAllocationModel[ctx] struct {
    represented: int,
    kind: int,
    source_path: str,
    arena_name: str,
    path_value: str,
    contents_value: str,
    write_local: str,
    read_local: str,
    index_local: str,
    loaded_local: str,
    allocation_size: int,
    stored_value: int
}

type MirNativeFilesystemAllocationResult[ctx] struct {
    represented: int,
    invalid: int,
    diagnostic: str,
    bundle: mir.MirProgramBundle[ctx]
}

func mir_native_filesystem_allocation_empty_model(ctx: &Arena) MirNativeFilesystemAllocationModel[ctx] {
    mut model: MirNativeFilesystemAllocationModel[ctx];
    model.represented = 0;
    model.kind = 0;
    model.source_path = std.Clone(ctx, "");
    model.arena_name = std.Clone(ctx, "");
    model.path_value = std.Clone(ctx, "");
    model.contents_value = std.Clone(ctx, "");
    model.write_local = std.Clone(ctx, "");
    model.read_local = std.Clone(ctx, "");
    model.index_local = std.Clone(ctx, "");
    model.loaded_local = std.Clone(ctx, "loaded");
    model.allocation_size = 0;
    model.stored_value = 0;
    return model;
}

func mir_native_filesystem_allocation_empty_result(ctx: &Arena) MirNativeFilesystemAllocationResult[ctx] {
    mut result: MirNativeFilesystemAllocationResult[ctx];
    result.represented = 0;
    result.invalid = 0;
    result.diagnostic = std.Clone(ctx, "");
    result.bundle = mir.mir_make_program_bundle("invalid", ctx);
    return result;
}

func mir_native_filesystem_allocation_append(output: str, value: str, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat(output, value));
}

func mir_native_filesystem_allocation_append_int(output: str, value: int, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat(output, std.FormatInt(value)));
}

func mir_native_filesystem_allocation_hex_digit(value: int, ctx: &Arena) str {
    mut digits := "0123456789abcdef";
    return std.Clone(ctx, std.str_slice(digits, value, value + 1));
}

func mir_native_filesystem_allocation_hex(value: str, ctx: &Arena) str {
    mut output := std.Clone(ctx, "");
    mut index := 0;
    while index < len(value) {
        mut byte_value := std.str_byte_at(value, index);
        mut high := byte_value / 16;
        mut low := byte_value - high * 16;
        output = mir_native_filesystem_allocation_append(
            output, mir_native_filesystem_allocation_hex_digit(high, ctx), ctx
        );
        output = mir_native_filesystem_allocation_append(
            output, mir_native_filesystem_allocation_hex_digit(low, ctx), ctx
        );
        index = index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_native_filesystem_allocation_expression_path(expression: ast.Expression[ctx], ctx: &Arena) str {
    unsafe {
        if expression.tag == 0 {
            return std.Clone(ctx, expression.Identifier.name);
        }
        if expression.tag == 11 {
            mut left := ctx[expression.Selector.left];
            mut prefix := mir_native_filesystem_allocation_expression_path(left, ctx);
            if len(prefix) == 0 { return std.Clone(ctx, ""); }
            prefix = mir_native_filesystem_allocation_append(prefix, ".", ctx);
            mut selected := mir_native_filesystem_allocation_append(
                prefix, expression.Selector.right, ctx
            );
            return std.Clone(ctx, selected);
        }
    }
    return std.Clone(ctx, "");
}

func mir_native_filesystem_allocation_call_name(expression: ast.Expression[ctx], ctx: &Arena) str {
    unsafe {
        if expression.tag != 12 { return std.Clone(ctx, ""); }
        return mir_native_filesystem_allocation_expression_path(
            ctx[expression.Call.function], ctx
        );
    }
}

func mir_native_filesystem_allocation_identifier_is(expression: ast.Expression[ctx], name: str) int {
    unsafe {
        if expression.tag == 0 && std.str_eq(expression.Identifier.name, name) == 1 {
            return 1;
        }
    }
    return 0;
}

func mir_native_filesystem_analyze(
    statements: std.Vector[ast.Statement[ctx], ctx],
    source_path: str,
    ctx: &Arena
) MirNativeFilesystemAllocationModel[ctx] {
    mut model := mir_native_filesystem_allocation_empty_model(ctx);
    model.source_path = std.Clone(ctx, source_path);
    if len(statements) != 7 { return model; }
    unsafe {
        if statements[0].tag != 4 || statements[1].tag != 11 ||
           statements[2].tag != 4 || statements[3].tag != 4 ||
           statements[4].tag != 13 || statements[5].tag != 4 ||
           statements[6].tag != 13
        {
            return model;
        }
        mut arena_call := ctx[statements[0].VarDecl.value];
        mut deferred_call := ctx[statements[1].Defer.expr];
        mut path_expression := ctx[statements[2].VarDecl.value];
        mut write_call := ctx[statements[3].VarDecl.value];
        mut log_write := ctx[statements[4].Expression.expr];
        mut read_call := ctx[statements[5].VarDecl.value];
        mut log_read := ctx[statements[6].Expression.expr];
        mut arena_name := statements[0].VarDecl.name;
        mut path_name := statements[2].VarDecl.name;
        mut write_name := statements[3].VarDecl.name;
        mut read_name := statements[5].VarDecl.name;
        if std.str_eq(mir_native_filesystem_allocation_call_name(arena_call, ctx), "os.Arena.New") == 0 ||
           std.str_eq(mir_native_filesystem_allocation_call_name(deferred_call, ctx), std.Concat(arena_name, ".Free")) == 0 ||
           path_expression.tag != 2 ||
           std.str_eq(mir_native_filesystem_allocation_call_name(write_call, ctx), "os.WriteFile") == 0 ||
           std.str_eq(mir_native_filesystem_allocation_call_name(log_write, ctx), "os.LogInt") == 0 ||
           std.str_eq(mir_native_filesystem_allocation_call_name(read_call, ctx), "os.ReadFile") == 0 ||
           std.str_eq(mir_native_filesystem_allocation_call_name(log_read, ctx), "os.LogStr") == 0
        {
            return model;
        }
        mut write_arguments: std.Vector[ast.Expression[ctx], ctx] := ctx[write_call.Call.arguments];
        mut log_write_arguments: std.Vector[ast.Expression[ctx], ctx] := ctx[log_write.Call.arguments];
        mut read_arguments: std.Vector[ast.Expression[ctx], ctx] := ctx[read_call.Call.arguments];
        mut log_read_arguments: std.Vector[ast.Expression[ctx], ctx] := ctx[log_read.Call.arguments];
        if len(write_arguments) != 2 || len(log_write_arguments) != 1 ||
           len(read_arguments) != 2 || len(log_read_arguments) != 1 ||
           mir_native_filesystem_allocation_identifier_is(write_arguments[0], path_name) == 0 ||
           write_arguments[1].tag != 2 ||
           mir_native_filesystem_allocation_identifier_is(log_write_arguments[0], write_name) == 0 ||
           mir_native_filesystem_allocation_identifier_is(read_arguments[0], arena_name) == 0 ||
           mir_native_filesystem_allocation_identifier_is(read_arguments[1], path_name) == 0 ||
           mir_native_filesystem_allocation_identifier_is(log_read_arguments[0], read_name) == 0
        {
            return model;
        }
        model.kind = 1;
        model.represented = 1;
        model.arena_name = std.Clone(ctx, arena_name);
        model.path_value = std.Clone(ctx, path_expression.String.val);
        model.contents_value = std.Clone(ctx, write_arguments[1].String.val);
        model.write_local = std.Clone(ctx, write_name);
        model.read_local = std.Clone(ctx, read_name);
        return model;
    }
}

func mir_native_allocation_analyze(
    statements: std.Vector[ast.Statement[ctx], ctx],
    field_name: str,
    source_path: str,
    ctx: &Arena
) MirNativeFilesystemAllocationModel[ctx] {
    mut model := mir_native_filesystem_allocation_empty_model(ctx);
    model.source_path = std.Clone(ctx, source_path);
    if len(statements) != 7 { return model; }
    unsafe {
        if statements[0].tag != 4 || statements[1].tag != 11 ||
           statements[2].tag != 4 || statements[3].tag != 4 ||
           statements[4].tag != 5 || statements[5].tag != 13 || statements[6].tag != 13
        { return model; }
        mut arena_call := ctx[statements[0].VarDecl.value];
        mut deferred_call := ctx[statements[1].Defer.expr];
        mut allocation_call := ctx[statements[2].VarDecl.value];
        mut assignment_left := ctx[statements[4].Assignment.left];
        mut assignment_value := ctx[statements[4].Assignment.value];
        mut set_call := ctx[statements[5].Expression.expr];
        mut log_call := ctx[statements[6].Expression.expr];
        mut arena_name := statements[0].VarDecl.name;
        mut index_name := statements[2].VarDecl.name;
        mut aggregate_name := statements[3].VarDecl.name;
        if std.str_eq(mir_native_filesystem_allocation_call_name(arena_call, ctx), "os.Arena.New") == 0 ||
           std.str_eq(mir_native_filesystem_allocation_call_name(deferred_call, ctx), std.Concat(arena_name, ".Free")) == 0 ||
           std.str_eq(mir_native_filesystem_allocation_call_name(allocation_call, ctx), "os.ArenaAlloc") == 0 ||
           assignment_left.tag != 11 || assignment_value.tag != 1 ||
           std.str_eq(assignment_left.Selector.right, field_name) == 0 ||
           std.str_eq(mir_native_filesystem_allocation_call_name(set_call, ctx), std.Concat(arena_name, ".Set")) == 0 ||
           std.str_eq(mir_native_filesystem_allocation_call_name(log_call, ctx), "os.LogInt") == 0
        { return model; }
        mut allocation_arguments: std.Vector[ast.Expression[ctx], ctx] := ctx[allocation_call.Call.arguments];
        mut set_arguments: std.Vector[ast.Expression[ctx], ctx] := ctx[set_call.Call.arguments];
        mut log_arguments: std.Vector[ast.Expression[ctx], ctx] := ctx[log_call.Call.arguments];
        mut assignment_owner := ctx[assignment_left.Selector.left];
        if len(allocation_arguments) != 1 || len(set_arguments) != 2 || len(log_arguments) != 1 ||
           mir_native_filesystem_allocation_identifier_is(allocation_arguments[0], arena_name) == 0 ||
           mir_native_filesystem_allocation_identifier_is(assignment_owner, aggregate_name) == 0 ||
           mir_native_filesystem_allocation_identifier_is(set_arguments[0], index_name) == 0 ||
           mir_native_filesystem_allocation_identifier_is(set_arguments[1], aggregate_name) == 0 ||
           log_arguments[0].tag != 11 || std.str_eq(log_arguments[0].Selector.right, field_name) == 0
        { return model; }
        mut indexed := ctx[log_arguments[0].Selector.left];
        if indexed.tag != 8 { return model; }
        mut indexed_arena := ctx[indexed.IndexAccess.allocator];
        mut indexed_value := ctx[indexed.IndexAccess.index];
        if mir_native_filesystem_allocation_identifier_is(indexed_arena, arena_name) == 0 ||
           mir_native_filesystem_allocation_identifier_is(indexed_value, index_name) == 0
        { return model; }
        model.kind = 2;
        model.represented = 1;
        model.arena_name = std.Clone(ctx, arena_name);
        model.index_local = std.Clone(ctx, index_name);
        model.allocation_size = 4;
        model.stored_value = assignment_value.Integer.val;
        return model;
    }
}

func mir_native_filesystem_allocation_emit_metadata(
    output: str,
    index: int,
    statement_index: int,
    symbol: str,
    origin: str,
    ctx: &Arena
) str {
    mut updated := mir_native_filesystem_allocation_append(output, "function_0_metadata_", ctx);
    updated = mir_native_filesystem_allocation_append_int(updated, index, ctx);
    updated = mir_native_filesystem_allocation_append(updated, "_kind: native_boundary\nfunction_0_metadata_", ctx);
    updated = mir_native_filesystem_allocation_append_int(updated, index, ctx);
    updated = mir_native_filesystem_allocation_append(updated, "_attachment: statement:entry:", ctx);
    updated = mir_native_filesystem_allocation_append_int(updated, statement_index, ctx);
    updated = mir_native_filesystem_allocation_append(updated, "\nfunction_0_metadata_", ctx);
    updated = mir_native_filesystem_allocation_append_int(updated, index, ctx);
    updated = mir_native_filesystem_allocation_append(updated, "_policy: ignored_with_proof\nfunction_0_metadata_", ctx);
    updated = mir_native_filesystem_allocation_append_int(updated, index, ctx);
    updated = mir_native_filesystem_allocation_append(updated, "_payload: kind=RuntimeCall;symbol=", ctx);
    updated = mir_native_filesystem_allocation_append(updated, symbol, ctx);
    updated = mir_native_filesystem_allocation_append(
        updated,
        ";codegen=none;proof=runtime_boundary_classification_is_registry_validated;contract=phase21_10;origin=",
        ctx
    );
    updated = mir_native_filesystem_allocation_append(updated, origin, ctx);
    return mir_native_filesystem_allocation_append(updated, "\n", ctx);
}

func mir_native_filesystem_allocation_emit(model: MirNativeFilesystemAllocationModel[ctx], ctx: &Arena) mir.MirProgramBundle[ctx] {
    mut canonical := "format: gust.compiler_mir_ingestion.v2\nmodule: phase21_filesystem_allocation_source\n";
    if model.kind == 1 {
        canonical = mir_native_filesystem_allocation_append(canonical, "import_count: 6\nimport_0_name: os_Arena_New\nimport_0_link_symbol: os_Arena_New\nimport_0_linkage: imported_host\nimport_0_parameter_count: 0\nimport_0_return_type: arena\nimport_1_name: os_Arena_Free\nimport_1_link_symbol: os_Arena_Free\nimport_1_linkage: imported_host\nimport_1_parameter_count: 1\nimport_1_parameter_0_type: arena\nimport_1_return_type: void\nimport_2_name: os_WriteFile\nimport_2_link_symbol: os_WriteFile\nimport_2_linkage: imported_host\nimport_2_parameter_count: 2\nimport_2_parameter_0_type: str\nimport_2_parameter_1_type: str\nimport_2_return_type: int\nimport_3_name: os_ReadFile\nimport_3_link_symbol: os_ReadFile\nimport_3_linkage: imported_host\nimport_3_parameter_count: 2\nimport_3_parameter_0_type: arena\nimport_3_parameter_1_type: str\nimport_3_return_type: str\nimport_4_name: os_LogInt\nimport_4_link_symbol: os_LogInt\nimport_4_linkage: imported_host\nimport_4_parameter_count: 1\nimport_4_parameter_0_type: int\nimport_4_return_type: void\nimport_5_name: os_LogStr\nimport_5_link_symbol: os_LogStr\nimport_5_linkage: imported_host\nimport_5_parameter_count: 1\nimport_5_parameter_0_type: str\nimport_5_return_type: void\nfunction_count: 1\nfunction_0_linkage: exported_entry\nfunction_0_function: main\nfunction_0_backend_symbol: main\nfunction_0_parameter_count: 0\nfunction_0_return_type: int\nfunction_0_local_count: 3\nfunction_0_local_0_name: ctx\nfunction_0_local_0_type: arena\nfunction_0_local_1_name: wrote\nfunction_0_local_1_type: int\nfunction_0_local_2_name: contents\nfunction_0_local_2_type: str\nfunction_0_entry_block: entry\nfunction_0_block_count: 1\nfunction_0_block_0_label: entry\nfunction_0_block_0_parameter_count: 0\nfunction_0_block_0_statement_count: 6\nfunction_0_block_0_statement_0_kind: ArenaInit\nfunction_0_block_0_statement_0_local: ctx\nfunction_0_block_0_statement_0_callee_kind: ImportedFunction\nfunction_0_block_0_statement_0_callee: os_Arena_New\nfunction_0_block_0_statement_1_kind: LocalI32SetCall\nfunction_0_block_0_statement_1_local: wrote\nfunction_0_block_0_statement_1_callee_kind: ImportedFunction\nfunction_0_block_0_statement_1_callee: os_WriteFile\nfunction_0_block_0_statement_1_argument_count: 2\nfunction_0_block_0_statement_1_argument_0_kind: StringLiteralUtf8Hex\nfunction_0_block_0_statement_1_argument_0_value: ", ctx);
        canonical = mir_native_filesystem_allocation_append(canonical, mir_native_filesystem_allocation_hex(model.path_value, ctx), ctx);
        canonical = mir_native_filesystem_allocation_append(canonical, "\nfunction_0_block_0_statement_1_argument_1_kind: StringLiteralUtf8Hex\nfunction_0_block_0_statement_1_argument_1_value: ", ctx);
        canonical = mir_native_filesystem_allocation_append(canonical, mir_native_filesystem_allocation_hex(model.contents_value, ctx), ctx);
        canonical = mir_native_filesystem_allocation_append(canonical, "\nfunction_0_block_0_statement_2_kind: CallVoid\nfunction_0_block_0_statement_2_callee_kind: ImportedFunction\nfunction_0_block_0_statement_2_callee: os_LogInt\nfunction_0_block_0_statement_2_argument_count: 1\nfunction_0_block_0_statement_2_argument_0_kind: LocalI32\nfunction_0_block_0_statement_2_argument_0_local: wrote\nfunction_0_block_0_statement_3_kind: LocalStringSetCall\nfunction_0_block_0_statement_3_local: contents\nfunction_0_block_0_statement_3_callee_kind: ImportedFunction\nfunction_0_block_0_statement_3_callee: os_ReadFile\nfunction_0_block_0_statement_3_argument_count: 2\nfunction_0_block_0_statement_3_argument_0_kind: ArenaAddress\nfunction_0_block_0_statement_3_argument_0_local: ctx\nfunction_0_block_0_statement_3_argument_1_kind: StringLiteralUtf8Hex\nfunction_0_block_0_statement_3_argument_1_value: ", ctx);
        canonical = mir_native_filesystem_allocation_append(canonical, mir_native_filesystem_allocation_hex(model.path_value, ctx), ctx);
        canonical = mir_native_filesystem_allocation_append(canonical, "\nfunction_0_block_0_statement_4_kind: CallVoid\nfunction_0_block_0_statement_4_callee_kind: ImportedFunction\nfunction_0_block_0_statement_4_callee: os_LogStr\nfunction_0_block_0_statement_4_argument_count: 1\nfunction_0_block_0_statement_4_argument_0_kind: LocalString\nfunction_0_block_0_statement_4_argument_0_local: contents\nfunction_0_block_0_statement_5_kind: CallVoid\nfunction_0_block_0_statement_5_callee_kind: ImportedFunction\nfunction_0_block_0_statement_5_callee: os_Arena_Free\nfunction_0_block_0_statement_5_argument_count: 1\nfunction_0_block_0_statement_5_argument_0_kind: ArenaAddress\nfunction_0_block_0_statement_5_argument_0_local: ctx\n", ctx);
    } else {
        canonical = mir_native_filesystem_allocation_append(canonical, "import_count: 4\nimport_0_name: os_Arena_New\nimport_0_link_symbol: os_Arena_New\nimport_0_linkage: imported_host\nimport_0_parameter_count: 0\nimport_0_return_type: arena\nimport_1_name: os_Arena_Free\nimport_1_link_symbol: os_Arena_Free\nimport_1_linkage: imported_host\nimport_1_parameter_count: 1\nimport_1_parameter_0_type: arena\nimport_1_return_type: void\nimport_2_name: os_ArenaAlloc\nimport_2_link_symbol: os_ArenaAlloc\nimport_2_linkage: imported_host\nimport_2_parameter_count: 2\nimport_2_parameter_0_type: arena\nimport_2_parameter_1_type: usize\nimport_2_return_type: int\nimport_3_name: os_LogInt\nimport_3_link_symbol: os_LogInt\nimport_3_linkage: imported_host\nimport_3_parameter_count: 1\nimport_3_parameter_0_type: int\nimport_3_return_type: void\nfunction_count: 1\nfunction_0_linkage: exported_entry\nfunction_0_function: main\nfunction_0_backend_symbol: main\nfunction_0_parameter_count: 0\nfunction_0_return_type: int\nfunction_0_local_count: 3\nfunction_0_local_0_name: ctx\nfunction_0_local_0_type: arena\nfunction_0_local_1_name: node\nfunction_0_local_1_type: int\nfunction_0_local_2_name: loaded\nfunction_0_local_2_type: int\nfunction_0_entry_block: entry\nfunction_0_block_count: 1\nfunction_0_block_0_label: entry\nfunction_0_block_0_parameter_count: 0\nfunction_0_block_0_statement_count: 6\nfunction_0_block_0_statement_0_kind: ArenaInit\nfunction_0_block_0_statement_0_local: ctx\nfunction_0_block_0_statement_0_callee_kind: ImportedFunction\nfunction_0_block_0_statement_0_callee: os_Arena_New\nfunction_0_block_0_statement_1_kind: LocalI32SetCall\nfunction_0_block_0_statement_1_local: node\nfunction_0_block_0_statement_1_callee_kind: ImportedFunction\nfunction_0_block_0_statement_1_callee: os_ArenaAlloc\nfunction_0_block_0_statement_1_argument_count: 2\nfunction_0_block_0_statement_1_argument_0_kind: ArenaAddress\nfunction_0_block_0_statement_1_argument_0_local: ctx\nfunction_0_block_0_statement_1_argument_1_kind: USizeLiteral\nfunction_0_block_0_statement_1_argument_1_value: 4\nfunction_0_block_0_statement_2_kind: ArenaStoreI32\nfunction_0_block_0_statement_2_arena: ctx\nfunction_0_block_0_statement_2_index_local: node\nfunction_0_block_0_statement_2_byte_offset: 0\nfunction_0_block_0_statement_2_value: ", ctx);
        canonical = mir_native_filesystem_allocation_append_int(canonical, model.stored_value, ctx);
        canonical = mir_native_filesystem_allocation_append(canonical, "\nfunction_0_block_0_statement_3_kind: LocalI32SetArenaLoad\nfunction_0_block_0_statement_3_local: loaded\nfunction_0_block_0_statement_3_arena: ctx\nfunction_0_block_0_statement_3_index_local: node\nfunction_0_block_0_statement_3_byte_offset: 0\nfunction_0_block_0_statement_4_kind: CallVoid\nfunction_0_block_0_statement_4_callee_kind: ImportedFunction\nfunction_0_block_0_statement_4_callee: os_LogInt\nfunction_0_block_0_statement_4_argument_count: 1\nfunction_0_block_0_statement_4_argument_0_kind: LocalI32\nfunction_0_block_0_statement_4_argument_0_local: loaded\nfunction_0_block_0_statement_5_kind: CallVoid\nfunction_0_block_0_statement_5_callee_kind: ImportedFunction\nfunction_0_block_0_statement_5_callee: os_Arena_Free\nfunction_0_block_0_statement_5_argument_count: 1\nfunction_0_block_0_statement_5_argument_0_kind: ArenaAddress\nfunction_0_block_0_statement_5_argument_0_local: ctx\n", ctx);
    }
    canonical = mir_native_filesystem_allocation_append(canonical, "function_0_block_0_terminator_kind: ReturnI32\nfunction_0_block_0_terminator_value: 0\n", ctx);
    mut metadata_count := 4;
    if model.kind == 1 { metadata_count = 6; }
    canonical = mir_native_filesystem_allocation_append(canonical, "function_0_metadata_count: ", ctx);
    canonical = mir_native_filesystem_allocation_append_int(canonical, metadata_count, ctx);
    canonical = mir_native_filesystem_allocation_append(canonical, "\n", ctx);
    canonical = mir_native_filesystem_allocation_emit_metadata(canonical, 0, 0, "os_Arena_New", model.source_path, ctx);
    if model.kind == 1 {
        canonical = mir_native_filesystem_allocation_emit_metadata(canonical, 1, 1, "os_WriteFile", model.source_path, ctx);
        canonical = mir_native_filesystem_allocation_emit_metadata(canonical, 2, 2, "os_LogInt", model.source_path, ctx);
        canonical = mir_native_filesystem_allocation_emit_metadata(canonical, 3, 3, "os_ReadFile", model.source_path, ctx);
        canonical = mir_native_filesystem_allocation_emit_metadata(canonical, 4, 4, "os_LogStr", model.source_path, ctx);
        canonical = mir_native_filesystem_allocation_emit_metadata(canonical, 5, 5, "os_Arena_Free", model.source_path, ctx);
    } else {
        canonical = mir_native_filesystem_allocation_emit_metadata(canonical, 1, 1, "os_ArenaAlloc", model.source_path, ctx);
        canonical = mir_native_filesystem_allocation_emit_metadata(canonical, 2, 4, "os_LogInt", model.source_path, ctx);
        canonical = mir_native_filesystem_allocation_emit_metadata(canonical, 3, 5, "os_Arena_Free", model.source_path, ctx);
    }
    canonical = mir_native_filesystem_allocation_append(canonical, "function_0_expected_exit: 0\n", ctx);
    mut bundle := mir.mir_make_program_bundle("main", ctx);
    mut module := mir.mir_make_program_bundle_module(model.source_path, "", "phase21_filesystem_allocation_source.o", "gust.compiler_mir_ingestion.v2", canonical, 0, 0, metadata_count, ctx);
    module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("main", "main", "()->int", 0, ctx), ctx);
    module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("os_Arena_New", "os_Arena_New", "()->arena", 2, ctx), ctx);
    module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("os_Arena_Free", "os_Arena_Free", "(arena)->void", 2, ctx), ctx);
    if model.kind == 1 {
        module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("os_WriteFile", "os_WriteFile", "(str,str)->int", 2, ctx), ctx);
        module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("os_ReadFile", "os_ReadFile", "(arena,str)->str", 2, ctx), ctx);
        module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("os_LogInt", "os_LogInt", "(int)->void", 2, ctx), ctx);
        module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("os_LogStr", "os_LogStr", "(str)->void", 2, ctx), ctx);
    } else {
        module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("os_ArenaAlloc", "os_ArenaAlloc", "(arena,usize)->int", 2, ctx), ctx);
        module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("os_LogInt", "os_LogInt", "(int)->void", 2, ctx), ctx);
    }
    return mir.mir_program_bundle_with_module(bundle, module, ctx);
}

func mir_native_filesystem_allocation_source_lower(
    programs: std.Vector[ast.Program[ctx], ctx],
    module_paths: std.Vector[str, ctx],
    module_prefixes: std.Vector[str, ctx],
    ctx: &Arena
) MirNativeFilesystemAllocationResult[ctx] {
    mut result := mir_native_filesystem_allocation_empty_result(ctx);
    if len(programs) != 1 || len(module_paths) != 1 || len(module_prefixes) != 1 || std.str_eq(module_prefixes[0], "") == 0 { return result; }
    unsafe {
        mut top_level: std.Vector[ast.Statement[ctx], ctx] := ctx[programs[0].statements];
        mut function_index := 0 - 1;
        mut field_name := std.Clone(ctx, "");
        mut function_count := 0;
        mut struct_count := 0;
        mut index := 0;
        while index < len(top_level) {
            if top_level[index].tag == 3 {
                function_count = function_count + 1;
                if std.str_eq(top_level[index].FunctionDecl.name, "main") == 1 { function_index = index; }
            }
            if top_level[index].tag == 1 {
                struct_count = struct_count + 1;
                mut fields: std.Vector[ast.FieldDef[ctx], ctx] := ctx[top_level[index].StructDecl.fields];
                if len(fields) == 1 && fields[0].field_type.tag == 0 { field_name = std.Clone(ctx, fields[0].name); }
            }
            index = index + 1;
        }
        if function_index < 0 { return result; }
        mut function := top_level[function_index];
        mut parameters: std.Vector[ast.Parameter[ctx], ctx] := ctx[function.FunctionDecl.params];
        mut return_type := ctx[function.FunctionDecl.return_type];
        if function.FunctionDecl.is_extern == 1 || len(parameters) != 0 || return_type.tag != 3 { return result; }
        mut body := ctx[function.FunctionDecl.body];
        mut statements: std.Vector[ast.Statement[ctx], ctx] := ctx[body.statements];
        mut model := mir_native_filesystem_analyze(statements, module_paths[0], ctx);
        if model.represented == 1 &&
           (len(top_level) != 1 || function_count != 1 || struct_count != 0)
        { return result; }
        if model.represented == 0 && len(field_name) > 0 {
            model = mir_native_allocation_analyze(statements, field_name, module_paths[0], ctx);
        }
        if model.represented == 1 && model.kind == 2 &&
           (len(top_level) != 2 || function_count != 1 || struct_count != 1)
        { return result; }
        if model.represented == 0 { return result; }
        result.represented = 1;
        result.bundle = mir_native_filesystem_allocation_emit(model, ctx);
        return result;
    }
}
