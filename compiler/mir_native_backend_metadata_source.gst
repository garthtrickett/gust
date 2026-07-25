import "ast.gst" as ast;
import "mir.gst" as mir;

// Phase 13.10 source-produced metadata contract.
//
// The helpers in this module write the structured metadata envelope consumed
// by the native worker. The payload remains available for class-specific
// details, while origin, owner, location, proof, classification, and bounded
// code-generation relevance are transported as independent canonical-MIR
// fields. Legacy fixtures without this envelope remain readable; production
// source lowering emits the strict phase13_10 contract.
type MirNativeMetadataSourceResult[ctx] struct {
    represented: int,
    invalid: int,
    deferred: int,
    reason_code: str,
    diagnostic: str,
    bundle: mir.MirProgramBundle[ctx]
}

func mir_native_metadata_append(output: str, value: str, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat(output, value));
}

func mir_native_metadata_append_int(output: str, value: int, ctx: &Arena) str {
    mut formatted := std.FormatInt(value);
    mut emitted := std.Concat(output, formatted);
    return std.Clone(ctx, emitted);
}

func mir_native_metadata_field(output: str, key: str, value: str, ctx: &Arena) str {
    mut emitted := mir_native_metadata_append(output, key, ctx);
    emitted = mir_native_metadata_append(emitted, ": ", ctx);
    emitted = mir_native_metadata_append(emitted, value, ctx);
    emitted = mir_native_metadata_append(emitted, "\n", ctx);
    return std.Clone(ctx, emitted);
}

func mir_native_metadata_int_field(output: str, key: str, value: int, ctx: &Arena) str {
    mut formatted := std.FormatInt(value);
    mut emitted := mir_native_metadata_field(
        output,
        key,
        formatted,
        ctx
    );
    return std.Clone(ctx, emitted);
}

func mir_native_metadata_emit_contract(
    output: str,
    prefix: str,
    source_origin: str,
    source_line: int,
    source_column: int,
    owner: str,
    classification: str,
    codegen_semantics: str,
    proof: str,
    ctx: &Arena
) str {
    mut emitted := mir_native_metadata_field(
        output,
        std.Concat(prefix, "_contract"),
        "phase13_10",
        ctx
    );
    emitted = mir_native_metadata_field(
        emitted,
        std.Concat(prefix, "_source_origin"),
        source_origin,
        ctx
    );
    emitted = mir_native_metadata_int_field(
        emitted,
        std.Concat(prefix, "_source_line"),
        source_line,
        ctx
    );
    emitted = mir_native_metadata_int_field(
        emitted,
        std.Concat(prefix, "_source_column"),
        source_column,
        ctx
    );
    emitted = mir_native_metadata_field(
        emitted,
        std.Concat(prefix, "_owner"),
        owner,
        ctx
    );
    emitted = mir_native_metadata_field(
        emitted,
        std.Concat(prefix, "_classification"),
        classification,
        ctx
    );
    emitted = mir_native_metadata_field(
        emitted,
        std.Concat(prefix, "_codegen_semantics"),
        codegen_semantics,
        ctx
    );
    emitted = mir_native_metadata_field(
        emitted,
        std.Concat(prefix, "_proof"),
        proof,
        ctx
    );
    return std.Clone(ctx, emitted);
}

func mir_native_metadata_empty_result(ctx: &Arena) MirNativeMetadataSourceResult[ctx] {
    mut result: MirNativeMetadataSourceResult[ctx];
    result.represented = 0;
    result.invalid = 0;
    result.deferred = 0;
    result.reason_code = std.Clone(ctx, "");
    result.diagnostic = std.Clone(ctx, "");
    result.bundle = mir.mir_make_program_bundle("invalid", ctx);
    return result;
}

func mir_native_metadata_deferred_result(
    reason_code: str,
    diagnostic: str,
    ctx: &Arena
) MirNativeMetadataSourceResult[ctx] {
    mut result := mir_native_metadata_empty_result(ctx);
    result.deferred = 1;
    result.reason_code = std.Clone(ctx, reason_code);
    result.diagnostic = std.Clone(ctx, diagnostic);
    return result;
}

func mir_native_metadata_simple_int_main(
    statement: ast.Statement[ctx],
    ctx: &Arena
) int {
    unsafe {
        if statement.tag != 3 ||
           std.str_eq(statement.FunctionDecl.name, "main") == 0 ||
           statement.FunctionDecl.is_extern == 1
        {
            return 0 - 1;
        }
        mut parameters: std.Vector[ast.Parameter[ctx], ctx] :=
            ctx[statement.FunctionDecl.params];
        mut return_type := ctx[statement.FunctionDecl.return_type];
        mut body := ctx[statement.FunctionDecl.body];
        mut statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[body.statements];
        if len(parameters) != 0 ||
           return_type.tag != 0 ||
           len(statements) != 1 ||
           statements[0].tag != 12
        {
            return 0 - 1;
        }
        mut expression := ctx[statements[0].Return.expr];
        if expression.tag != 1 {
            return 0 - 1;
        }
        return expression.Integer.val;
    }
}

func mir_native_metadata_emit_resource_bundle(
    source_path: str,
    resource_name: str,
    source_line: int,
    source_column: int,
    expected_exit: int,
    ctx: &Arena
) mir.MirProgramBundle[ctx] {
    mut canonical :=
        "format: gust.compiler_mir_ingestion.v1\nfunction: main\nbackend_symbol: main\nparameter_count: 0\nreturn_type: int\nlocal_count: 0\nentry_block: entry\nblock_count: 1\nblock_0_label: entry\nblock_0_parameter_count: 0\nblock_0_statement_count: 0\nblock_0_terminator_kind: ReturnI32\nblock_0_terminator_value: ";
    canonical = mir_native_metadata_append_int(
        canonical,
        expected_exit,
        ctx
    );
    canonical = mir_native_metadata_append(
        canonical,
        "\nmetadata_count: 1\nmetadata_0_kind: resource\nmetadata_0_attachment: function\nmetadata_0_policy: recognized_preserved\n",
        ctx
    );
    canonical = mir_native_metadata_emit_contract(
        canonical,
        "metadata_0",
        source_path,
        source_line,
        source_column,
        "function",
        "validated_preserved",
        "preserved",
        "linear_resource_declaration_is_inert_until_resource_runtime_lowering",
        ctx
    );
    canonical = mir_native_metadata_append(
        canonical,
        "metadata_0_payload: kind=LinearResourceDeclaration;type=",
        ctx
    );
    canonical = mir_native_metadata_append(
        canonical,
        resource_name,
        ctx
    );
    canonical = mir_native_metadata_append(
        canonical,
        ";state=Untracked;movement=deferred;cleanup=deferred;destruction=deferred\nexpected_exit: ",
        ctx
    );
    canonical = mir_native_metadata_append_int(
        canonical,
        expected_exit,
        ctx
    );
    canonical = mir_native_metadata_append(canonical, "\n", ctx);

    mut bundle := mir.mir_make_program_bundle("main", ctx);
    mut module := mir.mir_make_program_bundle_module(
        source_path,
        "",
        "phase13_source_resource_metadata.o",
        "gust.compiler_mir_ingestion.v1",
        canonical,
        1,
        0,
        0,
        ctx
    );
    module = mir.mir_program_bundle_module_with_symbol(
        module,
        mir.mir_make_program_bundle_symbol(
            "main",
            "main",
            "()->int",
            0,
            ctx
        ),
        ctx
    );
    return mir.mir_program_bundle_with_module(bundle, module, ctx);
}

func mir_native_metadata_source_lower(
    programs: std.Vector[ast.Program[ctx], ctx],
    module_paths: std.Vector[str, ctx],
    module_prefixes: std.Vector[str, ctx],
    ctx: &Arena
) MirNativeMetadataSourceResult[ctx] {
    mut result := mir_native_metadata_empty_result(ctx);
    if len(programs) != 1 ||
       len(module_paths) != 1 ||
       len(module_prefixes) != 1 ||
       std.str_eq(module_prefixes[0], "") == 0
    {
        return result;
    }

    mut program := programs[0];
    mut statements: std.Vector[ast.Statement[ctx], ctx] :=
        ctx[program.statements];
    mut linear_struct_count := 0;
    mut linear_struct_name := std.Clone(ctx, "");
    mut linear_struct_line := 0;
    mut linear_struct_column := 0;
    mut main_value := 0 - 1;
    mut statement_index := 0;
    while statement_index < len(statements) {
        mut statement := statements[statement_index];
        unsafe {
            if statement.tag == 1 &&
               statement.StructDecl.is_linear_resource == 1
            {
                linear_struct_count = linear_struct_count + 1;
                linear_struct_name = std.Clone(
                    ctx,
                    statement.StructDecl.name
                );
                linear_struct_line = statement.StructDecl.span.start.line;
                linear_struct_column =
                    statement.StructDecl.span.start.column;
            }
            if statement.tag == 3 &&
               std.str_eq(statement.FunctionDecl.name, "main") == 1
            {
                main_value = mir_native_metadata_simple_int_main(
                    statement,
                    ctx
                );
            }
        }
        statement_index = statement_index + 1;
    }

    if linear_struct_count == 0 {
        return result;
    }
    if linear_struct_count != 1 ||
       len(statements) != 2 ||
       main_value < 0
    {
        return mir_native_metadata_deferred_result(
            "deferred_p13_resource_runtime_semantics",
            "Native backend resource metadata deferral: resource movement, values, cleanup, destructor scheduling, and destruction lowering remain outside Patch 13.10",
            ctx
        );
    }
    if linear_struct_line <= 0 || linear_struct_column <= 0 {
        result.invalid = 1;
        result.diagnostic = std.Clone(
            ctx,
            "Native backend metadata error: linear resource declaration has an invalid source location"
        );
        return result;
    }

    result.represented = 1;
    result.bundle = mir_native_metadata_emit_resource_bundle(
        module_paths[0],
        linear_struct_name,
        linear_struct_line,
        linear_struct_column,
        main_value,
        ctx
    );
    return result;
}
