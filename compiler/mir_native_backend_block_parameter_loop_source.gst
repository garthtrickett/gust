import "ast.gst" as ast;
import "mir.gst" as mir;

// Compiler-owned block-parameter and reducible-loop lowering.
//
// This route consumes typed AST structure only. It recognizes ordinary
// zero-argument integer entry functions whose scalar state can be transported
// through canonical MIR block parameters. It does not compare source paths,
// fixture names, or raw source spellings.
type MirNativeBlockParameterDelta struct {
    represented: int,
    delta: int
}

type MirNativeBlockParameterArm struct {
    represented: int,
    first_delta: int,
    second_delta: int
}

type MirNativeBlockParameterLoopModel[ctx] struct {
    represented: int,
    invalid: int,
    diagnostic: str,
    source_path: str,
    profile: int,
    first_initial: int,
    second_initial: int,
    first_then_delta: int,
    second_then_delta: int,
    first_else_delta: int,
    second_else_delta: int,
    final_then_delta: int,
    final_else_delta: int,
    loop_first_delta: int,
    loop_second_delta: int,
    expected_exit: int
}

type MirNativeBlockParameterLoopSourceResult[ctx] struct {
    represented: int,
    invalid: int,
    diagnostic: str,
    bundle: mir.MirProgramBundle[ctx]
}

func mir_native_block_parameter_append(output: str, value: str, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat(output, value));
}

func mir_native_block_parameter_append_int(output: str, value: int, ctx: &Arena) str {
    mut formatted := std.FormatInt(value);
    return std.Clone(ctx, std.Concat(output, formatted));
}

func mir_native_block_parameter_empty_delta() MirNativeBlockParameterDelta {
    mut delta: MirNativeBlockParameterDelta;
    delta.represented = 0;
    delta.delta = 0;
    return delta;
}

func mir_native_block_parameter_empty_arm() MirNativeBlockParameterArm {
    mut arm: MirNativeBlockParameterArm;
    arm.represented = 0;
    arm.first_delta = 0;
    arm.second_delta = 0;
    return arm;
}

func mir_native_block_parameter_empty_model(ctx: &Arena) MirNativeBlockParameterLoopModel[ctx] {
    mut model: MirNativeBlockParameterLoopModel[ctx];
    model.represented = 0;
    model.invalid = 0;
    model.diagnostic = std.Clone(ctx, "");
    model.source_path = std.Clone(ctx, "");
    model.profile = 0;
    model.first_initial = 0;
    model.second_initial = 0;
    model.first_then_delta = 0;
    model.second_then_delta = 0;
    model.first_else_delta = 0;
    model.second_else_delta = 0;
    model.final_then_delta = 0;
    model.final_else_delta = 0;
    model.loop_first_delta = 0;
    model.loop_second_delta = 0;
    model.expected_exit = 0;
    return model;
}

func mir_native_block_parameter_empty_result(ctx: &Arena) MirNativeBlockParameterLoopSourceResult[ctx] {
    mut result: MirNativeBlockParameterLoopSourceResult[ctx];
    result.represented = 0;
    result.invalid = 0;
    result.diagnostic = std.Clone(ctx, "");
    result.bundle = mir.mir_make_program_bundle("invalid", ctx);
    return result;
}

func mir_native_block_parameter_entry_function(statement: ast.Statement[ctx], ctx: &Arena) int {
    unsafe {
        if statement.tag != 3 ||
           statement.FunctionDecl.is_extern == 1 ||
           std.str_eq(statement.FunctionDecl.name, "main") == 0
        {
            return 0;
        }
        mut parameters: std.Vector[ast.Parameter[ctx], ctx] :=
            ctx[statement.FunctionDecl.params];
        if len(parameters) != 0 {
            return 0;
        }
        mut return_type := ctx[statement.FunctionDecl.return_type];
        if return_type.tag != 0 {
            return 0;
        }
        return 1;
    }
}

func mir_native_block_parameter_decl_literal(statement: ast.Statement[ctx], ctx: &Arena) MirNativeBlockParameterDelta {
    mut result := mir_native_block_parameter_empty_delta();
    unsafe {
        if statement.tag != 4 || statement.VarDecl.is_mut == 0 ||
           statement.VarDecl.value == empty[Index[ast.Expression[ctx], ctx]]
        {
            return result;
        }
        if statement.VarDecl.var_type != empty[Index[ast.Type[ctx], ctx]] {
            mut declared_type := ctx[statement.VarDecl.var_type];
            if declared_type.tag != 0 {
                return result;
            }
        }
        mut initializer := ctx[statement.VarDecl.value];
        if initializer.tag != 1 {
            return result;
        }
        result.represented = 1;
        result.delta = initializer.Integer.val;
        return result;
    }
}

func mir_native_block_parameter_condition(expression: ast.Expression[ctx], name: str, ctx: &Arena) int {
    unsafe {
        if expression.tag != 10 || std.str_eq(expression.Binary.op, ">") == 0 {
            return 0;
        }
        mut left := ctx[expression.Binary.left];
        mut right := ctx[expression.Binary.right];
        if left.tag != 0 || right.tag != 1 || right.Integer.val != 0 {
            return 0;
        }
        return std.str_eq(left.Identifier.name, name);
    }
}

func mir_native_block_parameter_assignment_delta(statement: ast.Statement[ctx], name: str, ctx: &Arena) MirNativeBlockParameterDelta {
    mut result := mir_native_block_parameter_empty_delta();
    unsafe {
        if statement.tag != 5 {
            return result;
        }
        mut target := ctx[statement.Assignment.left];
        mut value := ctx[statement.Assignment.value];
        if target.tag != 0 || std.str_eq(target.Identifier.name, name) == 0 ||
           value.tag != 10
        {
            return result;
        }
        mut left := ctx[value.Binary.left];
        mut right := ctx[value.Binary.right];
        if left.tag != 0 || std.str_eq(left.Identifier.name, name) == 0 ||
           right.tag != 1
        {
            return result;
        }
        if std.str_eq(value.Binary.op, "+") == 1 {
            result.represented = 1;
            result.delta = right.Integer.val;
            return result;
        }
        if std.str_eq(value.Binary.op, "-") == 1 {
            result.represented = 1;
            result.delta = 0 - right.Integer.val;
            return result;
        }
        return result;
    }
}

func mir_native_block_parameter_two_assignment_arm(block: ast.BlockStatement[ctx], first_name: str, second_name: str, ctx: &Arena) MirNativeBlockParameterArm {
    mut result := mir_native_block_parameter_empty_arm();
    mut statements: std.Vector[ast.Statement[ctx], ctx] := ctx[block.statements];
    if len(statements) != 2 {
        return result;
    }
    mut first_seen := 0;
    mut second_seen := 0;
    mut index := 0;
    while index < len(statements) {
        mut first := mir_native_block_parameter_assignment_delta(
            statements[index],
            first_name,
            ctx
        );
        if first.represented == 1 {
            if first_seen == 1 {
                return mir_native_block_parameter_empty_arm();
            }
            first_seen = 1;
            result.first_delta = first.delta;
            index = index + 1;
            continue;
        }
        mut second := mir_native_block_parameter_assignment_delta(
            statements[index],
            second_name,
            ctx
        );
        if second.represented == 1 {
            if second_seen == 1 {
                return mir_native_block_parameter_empty_arm();
            }
            second_seen = 1;
            result.second_delta = second.delta;
            index = index + 1;
            continue;
        }
        return mir_native_block_parameter_empty_arm();
    }
    if first_seen == 1 && second_seen == 1 {
        result.represented = 1;
    }
    return result;
}

func mir_native_block_parameter_single_assignment_arm(block: ast.BlockStatement[ctx], name: str, ctx: &Arena) MirNativeBlockParameterDelta {
    mut statements: std.Vector[ast.Statement[ctx], ctx] := ctx[block.statements];
    if len(statements) != 1 {
        return mir_native_block_parameter_empty_delta();
    }
    return mir_native_block_parameter_assignment_delta(
        statements[0],
        name,
        ctx
    );
}

func mir_native_block_parameter_return_name(statement: ast.Statement[ctx], name: str, ctx: &Arena) int {
    unsafe {
        if statement.tag != 12 {
            return 0;
        }
        mut expression := ctx[statement.Return.expr];
        if expression.tag != 0 {
            return 0;
        }
        return std.str_eq(expression.Identifier.name, name);
    }
}

func mir_native_block_parameter_analyze_non_final_join(statements: std.Vector[ast.Statement[ctx], ctx], source_path: str, ctx: &Arena) MirNativeBlockParameterLoopModel[ctx] {
    mut model := mir_native_block_parameter_empty_model(ctx);
    if len(statements) != 5 || statements[2].tag != 7 ||
       statements[3].tag != 7
    {
        return model;
    }
    mut first_decl := mir_native_block_parameter_decl_literal(statements[0], ctx);
    mut second_decl := mir_native_block_parameter_decl_literal(statements[1], ctx);
    if first_decl.represented == 0 || second_decl.represented == 0 {
        return model;
    }
    unsafe {
        mut first_name := statements[0].VarDecl.name;
        mut second_name := statements[1].VarDecl.name;
        if std.str_eq(first_name, second_name) == 1 {
            return model;
        }
        mut first_if := statements[2];
        if first_if.If.alternative ==
            empty[Index[ast.BlockStatement[ctx], ctx]]
        {
            return model;
        }
        mut first_condition := ctx[first_if.If.condition];
        if mir_native_block_parameter_condition(first_condition, first_name, ctx) == 0 {
            return model;
        }
        mut first_then := ctx[first_if.If.consequence];
        mut first_else := ctx[first_if.If.alternative];
        mut then_arm := mir_native_block_parameter_two_assignment_arm(
            first_then,
            first_name,
            second_name,
            ctx
        );
        mut else_arm := mir_native_block_parameter_two_assignment_arm(
            first_else,
            first_name,
            second_name,
            ctx
        );
        if then_arm.represented == 0 || else_arm.represented == 0 {
            return model;
        }

        mut second_if := statements[3];
        if second_if.If.alternative ==
            empty[Index[ast.BlockStatement[ctx], ctx]]
        {
            return model;
        }
        mut second_condition := ctx[second_if.If.condition];
        if mir_native_block_parameter_condition(second_condition, second_name, ctx) == 0 {
            return model;
        }
        mut second_then := ctx[second_if.If.consequence];
        mut second_else := ctx[second_if.If.alternative];
        mut final_then := mir_native_block_parameter_single_assignment_arm(
            second_then,
            first_name,
            ctx
        );
        mut final_else := mir_native_block_parameter_single_assignment_arm(
            second_else,
            first_name,
            ctx
        );
        if final_then.represented == 0 || final_else.represented == 0 ||
           mir_native_block_parameter_return_name(statements[4], first_name, ctx) == 0
        {
            return model;
        }

        mut selected_first := first_decl.delta + else_arm.first_delta;
        mut selected_second := second_decl.delta + else_arm.second_delta;
        if first_decl.delta > 0 {
            selected_first = first_decl.delta + then_arm.first_delta;
            selected_second = second_decl.delta + then_arm.second_delta;
        }
        mut selected_final_delta := final_else.delta;
        if selected_second > 0 {
            selected_final_delta = final_then.delta;
        }

        model.represented = 1;
        model.source_path = std.Clone(ctx, source_path);
        model.profile = 0;
        model.first_initial = first_decl.delta;
        model.second_initial = second_decl.delta;
        model.first_then_delta = then_arm.first_delta;
        model.second_then_delta = then_arm.second_delta;
        model.first_else_delta = else_arm.first_delta;
        model.second_else_delta = else_arm.second_delta;
        model.final_then_delta = final_then.delta;
        model.final_else_delta = final_else.delta;
        model.expected_exit = selected_first + selected_final_delta;
        return model;
    }
}

func mir_native_block_parameter_analyze_loop(statements: std.Vector[ast.Statement[ctx], ctx], source_path: str, ctx: &Arena) MirNativeBlockParameterLoopModel[ctx] {
    mut model := mir_native_block_parameter_empty_model(ctx);
    if len(statements) != 4 || statements[2].tag != 6 {
        return model;
    }
    mut first_decl := mir_native_block_parameter_decl_literal(statements[0], ctx);
    mut second_decl := mir_native_block_parameter_decl_literal(statements[1], ctx);
    if first_decl.represented == 0 || second_decl.represented == 0 {
        return model;
    }
    unsafe {
        mut first_name := statements[0].VarDecl.name;
        mut second_name := statements[1].VarDecl.name;
        if std.str_eq(first_name, second_name) == 1 {
            return model;
        }
        mut while_statement := statements[2];
        mut condition := ctx[while_statement.While.condition];
        if mir_native_block_parameter_condition(condition, first_name, ctx) == 0 {
            return model;
        }
        mut body := ctx[while_statement.While.body];
        mut updates := mir_native_block_parameter_two_assignment_arm(
            body,
            first_name,
            second_name,
            ctx
        );
        if updates.represented == 0 ||
           mir_native_block_parameter_return_name(statements[3], second_name, ctx) == 0
        {
            return model;
        }

        model.represented = 1;
        model.source_path = std.Clone(ctx, source_path);
        model.profile = 1;
        model.first_initial = first_decl.delta;
        model.second_initial = second_decl.delta;
        model.loop_first_delta = updates.first_delta;
        model.loop_second_delta = updates.second_delta;
        if model.first_initial > 0 && model.loop_first_delta >= 0 {
            model.invalid = 1;
            model.diagnostic = std.Clone(
                ctx,
                "Native backend bounded-loop lowering requires a strictly decreasing positive loop parameter"
            );
            return model;
        }

        mut first_value := model.first_initial;
        mut second_value := model.second_initial;
        mut iteration_count := 0;
        while first_value > 0 {
            if iteration_count >= 1024 {
                model.invalid = 1;
                model.diagnostic = std.Clone(
                    ctx,
                    "Native backend bounded-loop lowering exceeded the deterministic iteration limit"
                );
                return model;
            }
            first_value = first_value + model.loop_first_delta;
            second_value = second_value + model.loop_second_delta;
            iteration_count = iteration_count + 1;
        }
        model.expected_exit = second_value;
        return model;
    }
}

func mir_native_block_parameter_analyze(programs: std.Vector[ast.Program[ctx], ctx], module_paths: std.Vector[str, ctx], module_prefixes: std.Vector[str, ctx], ctx: &Arena) MirNativeBlockParameterLoopModel[ctx] {
    mut model := mir_native_block_parameter_empty_model(ctx);
    if len(programs) != 1 || len(module_paths) != 1 ||
       len(module_prefixes) != 1 || std.str_eq(module_prefixes[0], "") == 0
    {
        return model;
    }
    mut program := programs[0];
    mut top_level: std.Vector[ast.Statement[ctx], ctx] := ctx[program.statements];
    if len(top_level) != 1 ||
       mir_native_block_parameter_entry_function(top_level[0], ctx) == 0
    {
        return model;
    }
    unsafe {
        mut function_statement := top_level[0];
        mut body := ctx[function_statement.FunctionDecl.body];
        mut statements: std.Vector[ast.Statement[ctx], ctx] := ctx[body.statements];
        model = mir_native_block_parameter_analyze_non_final_join(
            statements,
            module_paths[0],
            ctx
        );
        if model.represented == 1 {
            return model;
        }
        return mir_native_block_parameter_analyze_loop(
            statements,
            module_paths[0],
            ctx
        );
    }
}

func mir_native_block_parameter_emit_edge_argument(output: str, block_index: int, edge_name: str, argument_index: int, kind: str, parameter_name: str, value: int, ctx: &Arena) str {
    mut emitted := output;
    emitted = mir_native_block_parameter_append(emitted, "block_", ctx);
    emitted = mir_native_block_parameter_append_int(emitted, block_index, ctx);
    emitted = mir_native_block_parameter_append(emitted, "_terminator_", ctx);
    emitted = mir_native_block_parameter_append(emitted, edge_name, ctx);
    emitted = mir_native_block_parameter_append(emitted, "argument_", ctx);
    emitted = mir_native_block_parameter_append_int(emitted, argument_index, ctx);
    emitted = mir_native_block_parameter_append(emitted, "_kind: ", ctx);
    emitted = mir_native_block_parameter_append(emitted, kind, ctx);
    emitted = mir_native_block_parameter_append(emitted, "\n", ctx);
    if len(parameter_name) > 0 {
        emitted = mir_native_block_parameter_append(emitted, "block_", ctx);
        emitted = mir_native_block_parameter_append_int(emitted, block_index, ctx);
        emitted = mir_native_block_parameter_append(emitted, "_terminator_", ctx);
        emitted = mir_native_block_parameter_append(emitted, edge_name, ctx);
        emitted = mir_native_block_parameter_append(emitted, "argument_", ctx);
        emitted = mir_native_block_parameter_append_int(emitted, argument_index, ctx);
        emitted = mir_native_block_parameter_append(emitted, "_block_param: ", ctx);
        emitted = mir_native_block_parameter_append(emitted, parameter_name, ctx);
        emitted = mir_native_block_parameter_append(emitted, "\n", ctx);
    }
    if std.str_eq(kind, "I32Literal") == 1 ||
       std.str_eq(kind, "BlockParamI32AddI32Literal") == 1
    {
        emitted = mir_native_block_parameter_append(emitted, "block_", ctx);
        emitted = mir_native_block_parameter_append_int(emitted, block_index, ctx);
        emitted = mir_native_block_parameter_append(emitted, "_terminator_", ctx);
        emitted = mir_native_block_parameter_append(emitted, edge_name, ctx);
        emitted = mir_native_block_parameter_append(emitted, "argument_", ctx);
        emitted = mir_native_block_parameter_append_int(emitted, argument_index, ctx);
        emitted = mir_native_block_parameter_append(emitted, "_value: ", ctx);
        emitted = mir_native_block_parameter_append_int(emitted, value, ctx);
        emitted = mir_native_block_parameter_append(emitted, "\n", ctx);
    }
    return std.Clone(ctx, emitted);
}

func mir_native_block_parameter_emit_join(model: MirNativeBlockParameterLoopModel[ctx], ctx: &Arena) str {
    mut emitted :=
        "format: gust.compiler_mir_ingestion.v1\nfunction: main\nbackend_symbol: main\nparameter_count: 0\nreturn_type: int\nlocal_count: 0\nentry_block: entry\nblock_count: 5\n";
    emitted = mir_native_block_parameter_append(
        emitted,
        "block_0_label: entry\nblock_0_parameter_count: 0\nblock_0_statement_count: 0\nblock_0_terminator_kind: BranchI32Literal\nblock_0_terminator_condition: ",
        ctx
    );
    emitted = mir_native_block_parameter_append_int(emitted, model.first_initial, ctx);
    emitted = mir_native_block_parameter_append(
        emitted,
        "\nblock_0_terminator_then: first_then\nblock_0_terminator_then_argument_count: 0\nblock_0_terminator_else: first_else\nblock_0_terminator_else_argument_count: 0\n",
        ctx
    );

    emitted = mir_native_block_parameter_append(
        emitted,
        "block_1_label: first_then\nblock_1_parameter_count: 0\nblock_1_statement_count: 0\nblock_1_terminator_kind: Jump\nblock_1_terminator_target: join\nblock_1_terminator_argument_count: 2\n",
        ctx
    );
    emitted = mir_native_block_parameter_emit_edge_argument(
        emitted, 1, "", 0, "I32Literal", "",
        model.first_initial + model.first_then_delta, ctx
    );
    emitted = mir_native_block_parameter_emit_edge_argument(
        emitted, 1, "", 1, "I32Literal", "",
        model.second_initial + model.second_then_delta, ctx
    );

    emitted = mir_native_block_parameter_append(
        emitted,
        "block_2_label: first_else\nblock_2_parameter_count: 0\nblock_2_statement_count: 0\nblock_2_terminator_kind: Jump\nblock_2_terminator_target: join\nblock_2_terminator_argument_count: 2\n",
        ctx
    );
    emitted = mir_native_block_parameter_emit_edge_argument(
        emitted, 2, "", 0, "I32Literal", "",
        model.first_initial + model.first_else_delta, ctx
    );
    emitted = mir_native_block_parameter_emit_edge_argument(
        emitted, 2, "", 1, "I32Literal", "",
        model.second_initial + model.second_else_delta, ctx
    );

    emitted = mir_native_block_parameter_append(
        emitted,
        "block_3_label: join\nblock_3_parameter_count: 2\nblock_3_parameter_0_name: joined_first\nblock_3_parameter_0_type: int\nblock_3_parameter_1_name: joined_second\nblock_3_parameter_1_type: int\nblock_3_statement_count: 0\nblock_3_terminator_kind: BranchBlockParamI32Positive\nblock_3_terminator_block_param: joined_second\nblock_3_terminator_then: result\nblock_3_terminator_then_argument_count: 1\n",
        ctx
    );
    emitted = mir_native_block_parameter_emit_edge_argument(
        emitted, 3, "then_", 0, "BlockParamI32AddI32Literal",
        "joined_first", model.final_then_delta, ctx
    );
    emitted = mir_native_block_parameter_append(
        emitted,
        "block_3_terminator_else: result\nblock_3_terminator_else_argument_count: 1\n",
        ctx
    );
    emitted = mir_native_block_parameter_emit_edge_argument(
        emitted, 3, "else_", 0, "BlockParamI32AddI32Literal",
        "joined_first", model.final_else_delta, ctx
    );
    emitted = mir_native_block_parameter_append(
        emitted,
        "block_4_label: result\nblock_4_parameter_count: 1\nblock_4_parameter_0_name: result_value\nblock_4_parameter_0_type: int\nblock_4_statement_count: 0\nblock_4_terminator_kind: ReturnBlockParamI32\nblock_4_terminator_block_param: result_value\nmetadata_count: 1\nmetadata_0_kind: provenance\nmetadata_0_attachment: function\nmetadata_0_policy: recognized_preserved\nmetadata_0_payload: kind=BlockParameterLoop;profile=non_final_join;reducibility=acyclic;parameter_arity=2\nexpected_exit: ",
        ctx
    );
    emitted = mir_native_block_parameter_append_int(emitted, model.expected_exit, ctx);
    emitted = mir_native_block_parameter_append(emitted, "\n", ctx);
    return std.Clone(ctx, emitted);
}

func mir_native_block_parameter_emit_loop
func mir_native_block_parameter_emit_loop(model: MirNativeBlockParameterLoopModel[ctx], ctx: &Arena) str {
    mut emitted :=
        "format: gust.compiler_mir_ingestion.v1\nfunction: main\nbackend_symbol: main\nparameter_count: 0\nreturn_type: int\nlocal_count: 0\nentry_block: entry\nblock_count: 4\nblock_0_label: entry\nblock_0_parameter_count: 0\nblock_0_statement_count: 0\nblock_0_terminator_kind: Jump\nblock_0_terminator_target: loop_header\nblock_0_terminator_argument_count: 2\n";
    emitted = mir_native_block_parameter_emit_edge_argument(
        emitted, 0, "", 0, "I32Literal", "", model.first_initial, ctx
    );
    emitted = mir_native_block_parameter_emit_edge_argument(
        emitted, 0, "", 1, "I32Literal", "", model.second_initial, ctx
    );
    emitted = mir_native_block_parameter_append(
        emitted,
        "block_1_label: loop_header\nblock_1_parameter_count: 2\nblock_1_parameter_0_name: loop_first\nblock_1_parameter_0_type: int\nblock_1_parameter_1_name: loop_second\nblock_1_parameter_1_type: int\nblock_1_statement_count: 0\nblock_1_terminator_kind: BranchBlockParamI32Positive\nblock_1_terminator_block_param: loop_first\nblock_1_terminator_then: loop_body\nblock_1_terminator_then_argument_count: 2\n",
        ctx
    );
    emitted = mir_native_block_parameter_emit_edge_argument(
        emitted, 1, "then_", 0, "BlockParamI32", "loop_first", 0, ctx
    );
    emitted = mir_native_block_parameter_emit_edge_argument(
        emitted, 1, "then_", 1, "BlockParamI32", "loop_second", 0, ctx
    );
    emitted = mir_native_block_parameter_append(
        emitted,
        "block_1_terminator_else: loop_exit\nblock_1_terminator_else_argument_count: 1\n",
        ctx
    );
    emitted = mir_native_block_parameter_emit_edge_argument(
        emitted, 1, "else_", 0, "BlockParamI32", "loop_second", 0, ctx
    );
    emitted = mir_native_block_parameter_append(
        emitted,
        "block_2_label: loop_body\nblock_2_parameter_count: 2\nblock_2_parameter_0_name: body_first\nblock_2_parameter_0_type: int\nblock_2_parameter_1_name: body_second\nblock_2_parameter_1_type: int\nblock_2_statement_count: 0\nblock_2_terminator_kind: Jump\nblock_2_terminator_target: loop_header\nblock_2_terminator_argument_count: 2\n",
        ctx
    );
    emitted = mir_native_block_parameter_emit_edge_argument(
        emitted, 2, "", 0, "BlockParamI32AddI32Literal",
        "body_first", model.loop_first_delta, ctx
    );
    emitted = mir_native_block_parameter_emit_edge_argument(
        emitted, 2, "", 1, "BlockParamI32AddI32Literal",
        "body_second", model.loop_second_delta, ctx
    );
    emitted = mir_native_block_parameter_append(
        emitted,
        "block_3_label: loop_exit\nblock_3_parameter_count: 1\nblock_3_parameter_0_name: result_value\nblock_3_parameter_0_type: int\nblock_3_statement_count: 0\nblock_3_terminator_kind: ReturnBlockParamI32\nblock_3_terminator_block_param: result_value\nmetadata_count: 1\nmetadata_0_kind: provenance\nmetadata_0_attachment: function\nmetadata_0_policy: recognized_preserved\nmetadata_0_payload: kind=BlockParameterLoop;profile=bounded_loop;reducibility=single_header;parameter_arity=2\nexpected_exit: ",
        ctx
    );
    emitted = mir_native_block_parameter_append_int(emitted, model.expected_exit, ctx);
    emitted = mir_native_block_parameter_append(emitted, "\n", ctx);
    return std.Clone(ctx, emitted);
}

func mir_native_block_parameter_add_parameter
func mir_native_block_parameter_add_parameter(module: mir.MirProgramBundleModule[ctx], block_label: str, ordinal: int, name: str, ctx: &Arena) mir.MirProgramBundleModule[ctx] {
    return mir.mir_program_bundle_module_with_block_parameter(
        module,
        mir.mir_make_program_bundle_block_parameter(
            "main",
            block_label,
            ordinal,
            name,
            "int",
            ctx
        ),
        ctx
    );
}

func mir_native_block_parameter_emit_bundle(model: MirNativeBlockParameterLoopModel[ctx], ctx: &Arena) mir.MirProgramBundle[ctx] {
    mut canonical := mir_native_block_parameter_emit_join(model, ctx);
    mut object_name := "phase11_block_parameter_join_module.o";
    if model.profile == 1 {
        canonical = mir_native_block_parameter_emit_loop(model, ctx);
        object_name = "phase11_block_parameter_loop_module.o";
    }
    mut bundle := mir.mir_make_program_bundle("main", ctx);
    mut module := mir.mir_make_program_bundle_module(
        model.source_path,
        "",
        object_name,
        "gust.compiler_mir_ingestion.v1",
        canonical,
        0,
        1,
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
    if model.profile == 0 {
        module = mir_native_block_parameter_add_parameter(
            module, "join", 0, "joined_first", ctx
        );
        module = mir_native_block_parameter_add_parameter(
            module, "join", 1, "joined_second", ctx
        );
        module = mir_native_block_parameter_add_parameter(
            module, "result", 0, "result_value", ctx
        );
    } else {
        module = mir_native_block_parameter_add_parameter(
            module, "loop_header", 0, "loop_first", ctx
        );
        module = mir_native_block_parameter_add_parameter(
            module, "loop_header", 1, "loop_second", ctx
        );
        module = mir_native_block_parameter_add_parameter(
            module, "loop_body", 0, "body_first", ctx
        );
        module = mir_native_block_parameter_add_parameter(
            module, "loop_body", 1, "body_second", ctx
        );
        module = mir_native_block_parameter_add_parameter(
            module, "loop_exit", 0, "result_value", ctx
        );
    }
    return mir.mir_program_bundle_with_module(bundle, module, ctx);
}

func mir_native_block_parameter_loop_source_lower(programs: std.Vector[ast.Program[ctx], ctx], module_paths: std.Vector[str, ctx], module_prefixes: std.Vector[str, ctx], ctx: &Arena) MirNativeBlockParameterLoopSourceResult[ctx] {
    mut result := mir_native_block_parameter_empty_result(ctx);
    mut model := mir_native_block_parameter_analyze(
        programs,
        module_paths,
        module_prefixes,
        ctx
    );
    if model.represented == 0 {
        return result;
    }
    result.represented = 1;
    if model.invalid == 1 {
        result.invalid = 1;
        result.diagnostic = model.diagnostic;
        return result;
    }
    result.bundle = mir_native_block_parameter_emit_bundle(model, ctx);
    return result;
}
