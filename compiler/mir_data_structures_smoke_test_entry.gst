import "mir.gst" as mir;

func fail(msg: str) {
    os.LogStr(msg);
    os.Exit(1);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut span := mir.mir_make_empty_span();

    mut program := mir.mir_make_program(ctx);
    if len(ctx[program.functions]) != 0 {
        fail("MIR smoke: new program should start with zero functions");
    }
    if len(ctx[program.resource_metadata]) != 0 {
        fail("MIR smoke: new program should start with zero resource metadata records");
    }
    if len(ctx[program.provenance_metadata]) != 0 {
        fail("MIR smoke: new program should start with zero provenance metadata records");
    }
    if len(ctx[program.native_boundary_metadata]) != 0 {
        fail("MIR smoke: new program should start with zero native-boundary metadata records");
    }

    mut function := mir.mir_make_function("mir_smoke", "int", span, ctx);
    if std.str_eq(function.name, "mir_smoke") == 0 {
        fail("MIR smoke: function name constructor field drifted");
    }
    if std.str_eq(function.return_type, "int") == 0 {
        fail("MIR smoke: function return_type constructor field drifted");
    }
    if function.entry_block != 0 {
        fail("MIR smoke: function entry_block should default to zero");
    }
    if len(ctx[function.params]) != 0 {
        fail("MIR smoke: new function should start with zero params");
    }
    if len(ctx[function.locals]) != 0 {
        fail("MIR smoke: new function should start with zero locals");
    }
    if len(ctx[function.blocks]) != 0 {
        fail("MIR smoke: new function should start with zero blocks");
    }

    mut local := mir.mir_make_local(0, "x", "int", span, ctx);
    if local.id != 0 {
        fail("MIR smoke: local id constructor field drifted");
    }
    if std.str_eq(local.name, "x") == 0 {
        fail("MIR smoke: local name constructor field drifted");
    }
    if std.str_eq(local.local_type, "int") == 0 {
        fail("MIR smoke: local type constructor field drifted");
    }

    mut local_read: mir.MirValue[ctx] := mir.mir_make_value_local_read(local.id, "int", span, ctx);
    if local_read.tag != 3 {
        fail("MIR smoke: local-read value tag drifted");
    }
    unsafe {
        if local_read.LocalRead.local_id != 0 {
            fail("MIR smoke: local-read local_id field drifted");
        }
        if std.str_eq(local_read.LocalRead.value_type, "int") == 0 {
            fail("MIR smoke: local-read value_type field drifted");
        }
    }

    mut local_read_idx := mir.mir_alloc_value(local_read, ctx);
    mut local_set: mir.MirStmt[ctx] := mir.mir_make_stmt_local_set(local.id, local_read_idx, span);
    if local_set.tag != 1 {
        fail("MIR smoke: local-set statement tag drifted");
    }
    unsafe {
        if local_set.LocalSet.local_id != 0 {
            fail("MIR smoke: local-set local_id field drifted");
        }
    }

    mut linear_resource_kind: mir.MirResourceKind;
    mut owned_resource_state: mir.MirResourceState;
    mut local_binding_provenance: mir.MirProvenanceKind;
    mut runtime_boundary_kind: mir.MirNativeBoundaryKind;
    unsafe {
        linear_resource_kind.tag = 1;
        owned_resource_state.tag = 1;
        local_binding_provenance.tag = 1;
        runtime_boundary_kind.tag = 1;
    }

    mut resource_metadata := mir.mir_make_resource_metadata(local.id, linear_resource_kind, owned_resource_state, span);
    if resource_metadata.local_id != 0 {
        fail("MIR smoke: resource metadata local_id field drifted");
    }
    if std.str_eq(mir.mir_debug_resource_kind(resource_metadata.resource_kind), "MirResourceKind.LinearResource") == 0 {
        fail("MIR smoke: resource metadata kind field drifted");
    }
    if std.str_eq(mir.mir_debug_resource_state(resource_metadata.resource_state), "MirResourceState.Owned") == 0 {
        fail("MIR smoke: resource metadata state field drifted");
    }

    mut provenance_metadata := mir.mir_make_provenance_metadata(local_read_idx, local_binding_provenance, "x", span);
    if provenance_metadata.value == empty[Index[mir.MirValue[ctx], ctx]] {
        fail("MIR smoke: provenance metadata value field should be allocated");
    }
    if std.str_eq(mir.mir_debug_provenance_kind(provenance_metadata.provenance_kind), "MirProvenanceKind.LocalBinding") == 0 {
        fail("MIR smoke: provenance metadata kind field drifted");
    }
    if std.str_eq(provenance_metadata.origin_name, "x") == 0 {
        fail("MIR smoke: provenance metadata origin_name field drifted");
    }

    mut native_boundary_metadata := mir.mir_make_native_boundary_metadata("mir_smoke", runtime_boundary_kind, span);
    if std.str_eq(native_boundary_metadata.function_name, "mir_smoke") == 0 {
        fail("MIR smoke: native-boundary metadata function_name field drifted");
    }
    if std.str_eq(mir.mir_debug_native_boundary_kind(native_boundary_metadata.boundary_kind), "MirNativeBoundaryKind.RuntimeCall") == 0 {
        fail("MIR smoke: native-boundary metadata kind field drifted");
    }

    mut resource_metadata_records: std.Vector[mir.MirResourceMetadata[ctx], ctx] := ctx[program.resource_metadata];
    resource_metadata_records.Push(resource_metadata);
    ctx.Set(program.resource_metadata, resource_metadata_records);
    if len(ctx[program.resource_metadata]) != 1 {
        fail("MIR smoke: resource metadata side table should accept one record");
    }

    mut provenance_metadata_records: std.Vector[mir.MirProvenanceMetadata[ctx], ctx] := ctx[program.provenance_metadata];
    provenance_metadata_records.Push(provenance_metadata);
    ctx.Set(program.provenance_metadata, provenance_metadata_records);
    if len(ctx[program.provenance_metadata]) != 1 {
        fail("MIR smoke: provenance metadata side table should accept one record");
    }

    mut native_boundary_metadata_records: std.Vector[mir.MirNativeBoundaryMetadata[ctx], ctx] := ctx[program.native_boundary_metadata];
    native_boundary_metadata_records.Push(native_boundary_metadata);
    ctx.Set(program.native_boundary_metadata, native_boundary_metadata_records);
    if len(ctx[program.native_boundary_metadata]) != 1 {
        fail("MIR smoke: native-boundary metadata side table should accept one record");
    }

    mut return_terminator: mir.MirTerminator[ctx] := mir.mir_make_terminator_return(local_read_idx, span);
    if return_terminator.tag != 1 {
        fail("MIR smoke: return terminator tag drifted");
    }

    mut jump_terminator: mir.MirTerminator[ctx] := mir.mir_make_terminator_jump(1, span, ctx);
    if jump_terminator.tag != 2 {
        fail("MIR smoke: jump terminator tag drifted");
    }
    unsafe {
        if jump_terminator.Jump.target_block != 1 {
            fail("MIR smoke: jump target_block field drifted");
        }
    }

    mut branch_terminator: mir.MirTerminator[ctx] := mir.mir_make_terminator_branch(local_read_idx, 1, 2, span);
    if branch_terminator.tag != 3 {
        fail("MIR smoke: branch terminator tag drifted");
    }
    unsafe {
        if branch_terminator.Branch.condition == empty[Index[mir.MirValue[ctx], ctx]] {
            fail("MIR smoke: branch condition field should be allocated");
        }
        if branch_terminator.Branch.then_block != 1 {
            fail("MIR smoke: branch then_block field drifted");
        }
        if branch_terminator.Branch.else_block != 2 {
            fail("MIR smoke: branch else_block field drifted");
        }
    }

    mut return_terminator_idx := mir.mir_alloc_terminator(return_terminator, ctx);
    mut block := mir.mir_make_block(0, return_terminator_idx, span, ctx);
    if block.id != 0 {
        fail("MIR smoke: block id constructor field drifted");
    }
    if len(ctx[block.statements]) != 0 {
        fail("MIR smoke: new block should start with zero statements");
    }
    if block.terminator == empty[Index[mir.MirTerminator[ctx], ctx]] {
        fail("MIR smoke: block terminator should be allocated");
    }

    // Phase 10 canonical whole-program bundle smoke.
    mut bundle_phase10 := mir.mir_make_program_bundle("main", ctx);
    mut library_record_phase10 := "format: gust.compiler_mir_ingestion.v1\nfunction: math_helper\nbackend_symbol: math__helper\n";
    mut library_module_phase10 := mir.mir_make_program_bundle_module(
        "lib/math.gst",
        "math__",
        "math.o",
        "gust.compiler_mir_ingestion.v1",
        library_record_phase10,
        0,
        0,
        0,
        ctx
    );
    mut library_symbol_phase10 := mir.mir_make_program_bundle_symbol(
        "helper",
        "math__helper",
        "(int)->int",
        1,
        ctx
    );
    library_module_phase10 = mir.mir_program_bundle_module_with_symbol(
        library_module_phase10,
        library_symbol_phase10,
        ctx
    );
    mut library_block_parameter_phase10 := mir.mir_make_program_bundle_block_parameter(
        "math__helper",
        "merge",
        0,
        "value",
        "int",
        ctx
    );
    library_module_phase10 = mir.mir_program_bundle_module_with_block_parameter(
        library_module_phase10,
        library_block_parameter_phase10,
        ctx
    );
    bundle_phase10 = mir.mir_program_bundle_with_module(
        bundle_phase10,
        library_module_phase10,
        ctx
    );

    mut entry_record_phase10 := "format: gust.compiler_mir_ingestion.v2\nmodule: app\nimport_count: 1\nfunction_count: 1\n";
    mut entry_module_phase10 := mir.mir_make_program_bundle_module(
        "app.gst",
        "",
        "app.o",
        "gust.compiler_mir_ingestion.v2",
        entry_record_phase10,
        1,
        1,
        1,
        ctx
    );
    mut entry_symbol_phase10 := mir.mir_make_program_bundle_symbol(
        "main",
        "main",
        "()->int",
        0,
        ctx
    );
    entry_module_phase10 = mir.mir_program_bundle_module_with_symbol(
        entry_module_phase10,
        entry_symbol_phase10,
        ctx
    );
    mut imported_symbol_phase10 := mir.mir_make_program_bundle_symbol(
        "host_add",
        "gust_host_add_i32",
        "(int,int)->int",
        2,
        ctx
    );
    entry_module_phase10 = mir.mir_program_bundle_module_with_symbol(
        entry_module_phase10,
        imported_symbol_phase10,
        ctx
    );
    bundle_phase10 = mir.mir_program_bundle_with_module(
        bundle_phase10,
        entry_module_phase10,
        ctx
    );

    if mir.mir_program_bundle_is_valid(bundle_phase10, ctx) == 0 {
        fail("MIR bundle smoke: canonical two-module bundle should validate");
    }

    mut serialized_bundle_phase10_a := mir.mir_serialize_program_bundle(bundle_phase10, ctx);
    mut serialized_bundle_phase10_b := mir.mir_serialize_program_bundle(bundle_phase10, ctx);
    if std.str_eq(serialized_bundle_phase10_a, serialized_bundle_phase10_b) == 0 {
        fail("MIR bundle smoke: repeated serialization must be byte-identical");
    }
    if std.str_find(serialized_bundle_phase10_a, "format: gust.compiler_program_mir_bundle.v1\n") != 0 {
        fail("MIR bundle smoke: bundle format header drifted");
    }
    if std.str_find(serialized_bundle_phase10_a, "entry_symbol: main\n") == 0 - 1 {
        fail("MIR bundle smoke: entry symbol missing");
    }
    if std.str_find(serialized_bundle_phase10_a, "module_count: 2\n") == 0 - 1 {
        fail("MIR bundle smoke: module count missing");
    }
    mut library_position_phase10 := std.str_find(serialized_bundle_phase10_a, "module_0_path: lib/math.gst\n");
    mut entry_position_phase10 := std.str_find(serialized_bundle_phase10_a, "module_1_path: app.gst\n");
    if library_position_phase10 == 0 - 1 || entry_position_phase10 == 0 - 1 || library_position_phase10 >= entry_position_phase10 {
        fail("MIR bundle smoke: resolver order must be preserved");
    }
    if std.str_find(serialized_bundle_phase10_a, "module_1_symbol_0_linkage: exported_entry\n") == 0 - 1 {
        fail("MIR bundle smoke: exported entry linkage missing");
    }
    if std.str_find(serialized_bundle_phase10_a, "module_1_symbol_1_linkage: imported_host\n") == 0 - 1 {
        fail("MIR bundle smoke: imported host linkage missing");
    }
    if std.str_find(serialized_bundle_phase10_a, "module_0_block_parameter_0_name: value\n") == 0 - 1 {
        fail("MIR bundle smoke: block parameter contract missing");
    }
    if std.str_find(serialized_bundle_phase10_a, "module_1_resource_metadata_count: 1\n") == 0 - 1 {
        fail("MIR bundle smoke: resource metadata count missing");
    }
    if std.str_find(serialized_bundle_phase10_a, "module_1_canonical_format: gust.compiler_mir_ingestion.v2\n") == 0 - 1 {
        fail("MIR bundle smoke: frozen v2 module format missing");
    }

    mut reversed_bundle_phase10 := mir.mir_make_program_bundle("main", ctx);
    reversed_bundle_phase10 = mir.mir_program_bundle_with_module(
        reversed_bundle_phase10,
        entry_module_phase10,
        ctx
    );
    reversed_bundle_phase10 = mir.mir_program_bundle_with_module(
        reversed_bundle_phase10,
        library_module_phase10,
        ctx
    );
    mut serialized_reversed_bundle_phase10 := mir.mir_serialize_program_bundle(reversed_bundle_phase10, ctx);
    if std.str_eq(serialized_bundle_phase10_a, serialized_reversed_bundle_phase10) == 1 {
        fail("MIR bundle smoke: module order must be explicit rather than hash-derived");
    }

    mut invalid_bundle_phase10 := mir.mir_make_program_bundle("main", ctx);
    mut invalid_record_phase10 := "format: gust.compiler_mir_ingestion.v3\n";
    mut invalid_module_phase10 := mir.mir_make_program_bundle_module(
        "invalid.gst",
        "",
        "invalid.o",
        "gust.compiler_mir_ingestion.v3",
        invalid_record_phase10,
        0,
        0,
        0,
        ctx
    );
    mut invalid_entry_symbol_phase10 := mir.mir_make_program_bundle_symbol(
        "main",
        "main",
        "()->int",
        0,
        ctx
    );
    invalid_module_phase10 = mir.mir_program_bundle_module_with_symbol(
        invalid_module_phase10,
        invalid_entry_symbol_phase10,
        ctx
    );
    invalid_bundle_phase10 = mir.mir_program_bundle_with_module(
        invalid_bundle_phase10,
        invalid_module_phase10,
        ctx
    );
    if mir.mir_program_bundle_is_valid(invalid_bundle_phase10, ctx) == 1 {
        fail("MIR bundle smoke: v3 module syntax must reject");
    }
    if std.str_eq(mir.mir_serialize_program_bundle(invalid_bundle_phase10, ctx), "format: invalid\n") == 0 {
        fail("MIR bundle smoke: invalid bundle serialization must be stable");
    }

    os.LogStr("SUCCESS: canonical whole-program MIR bundle smoke");
    os.LogStr("SUCCESS: mir data structures smoke");
}
