import "ast.gst" as ast;
import "mir.gst" as mir;

// Phase 13.6 compiler-owned scalar parameter and argument composition.
//
// This lowerer consumes typed AST structure only. It recognizes one source
// module containing a three-i32-parameter sum helper plus one zero-argument int
// entry in one of four bounded profiles:
//   * call result used as a branch condition;
//   * repeated multi-argument calls with a larger scalar expression;
//   * call results assigned in both branch arms and returned after a join;
//   * a bounded single-header loop whose carried state is updated by a call.
//
// It never inspects a source path, fixture name, or raw source text. Parameter
// identity, declaration order, scalar type, namespace, and source position are
// serialized as provenance metadata. Aggregate and target-dependent ABI shapes
// remain precise pre-driver deferrals.
type MirNativeParameterArgumentHelper[ctx] struct {
    represented: int,
    name: str,
    parameter_names: std.Vector[str, ctx],
    parameter_lines: std.Vector[int, ctx],
    parameter_columns: std.Vector[int, ctx]
}

type MirNativeParameterArgumentModel[ctx] struct {
    represented: int,
    invalid: int,
    deferred: int,
    reason_code: str,
    diagnostic: str,
    source_path: str,
    profile: int,
    helper: MirNativeParameterArgumentHelper[ctx],
    first_local: str,
    second_local: str,
    call_result_local: str,
    first_argument_0: int,
    first_argument_1: int,
    first_argument_2: int,
    second_argument_1: int,
    second_argument_2: int,
    else_value: int,
    final_add: int,
    loop_count: int,
    loop_initial: int,
    loop_argument_1: int,
    loop_argument_2: int,
    expected_exit: int
}

type MirNativeParameterArgumentSourceResult[ctx] struct {
    represented: int,
    invalid: int,
    deferred: int,
    reason_code: str,
    diagnostic: str,
    bundle: mir.MirProgramBundle[ctx]
}

func mir_native_parameter_argument_append(
    output: str,
    value: str,
    ctx: &Arena
) str {
    return std.Clone(ctx, std.Concat(output, value));
}

func mir_native_parameter_argument_append_int(
    output: str,
    value: int,
    ctx: &Arena
) str {
    mut formatted := std.FormatInt(value);
    return std.Clone(ctx, std.Concat(output, formatted));
}

func mir_native_parameter_argument_field(
    output: str,
    key: str,
    value: str,
    ctx: &Arena
) str {
    mut emitted := mir_native_parameter_argument_append(output, key, ctx);
    emitted = mir_native_parameter_argument_append(emitted, ": ", ctx);
    emitted = mir_native_parameter_argument_append(emitted, value, ctx);
    emitted = mir_native_parameter_argument_append(emitted, "\n", ctx);
    return std.Clone(ctx, emitted);
}

func mir_native_parameter_argument_int_field(
    output: str,
    key: str,
    value: int,
    ctx: &Arena
) str {
    mut formatted := std.FormatInt(value);
    mut emitted := mir_native_parameter_argument_field(
        output,
        key,
        formatted,
        ctx
    );
    return std.Clone(ctx, emitted);
}

func mir_native_parameter_argument_empty_helper(
    ctx: &Arena
) MirNativeParameterArgumentHelper[ctx] {
    mut helper: MirNativeParameterArgumentHelper[ctx];
    helper.represented = 0;
    helper.name = std.Clone(ctx, "");
    helper.parameter_names = std.VectorNew(ctx);
    helper.parameter_lines = std.VectorNew(ctx);
    helper.parameter_columns = std.VectorNew(ctx);
    return helper;
}

func mir_native_parameter_argument_empty_model(
    ctx: &Arena
) MirNativeParameterArgumentModel[ctx] {
    mut model: MirNativeParameterArgumentModel[ctx];
    model.represented = 0;
    model.invalid = 0;
    model.deferred = 0;
    model.reason_code = std.Clone(ctx, "");
    model.diagnostic = std.Clone(ctx, "");
    model.source_path = std.Clone(ctx, "");
    model.profile = 0 - 1;
    model.helper = mir_native_parameter_argument_empty_helper(ctx);
    model.first_local = std.Clone(ctx, "");
    model.second_local = std.Clone(ctx, "");
    model.call_result_local = std.Clone(ctx, "__gust_phase13_call_result");
    model.first_argument_0 = 0;
    model.first_argument_1 = 0;
    model.first_argument_2 = 0;
    model.second_argument_1 = 0;
    model.second_argument_2 = 0;
    model.else_value = 0;
    model.final_add = 0;
    model.loop_count = 0;
    model.loop_initial = 0;
    model.loop_argument_1 = 0;
    model.loop_argument_2 = 0;
    model.expected_exit = 0;
    return model;
}

func mir_native_parameter_argument_empty_result(
    ctx: &Arena
) MirNativeParameterArgumentSourceResult[ctx] {
    mut result: MirNativeParameterArgumentSourceResult[ctx];
    result.represented = 0;
    result.invalid = 0;
    result.deferred = 0;
    result.reason_code = std.Clone(ctx, "");
    result.diagnostic = std.Clone(ctx, "");
    result.bundle = mir.mir_make_program_bundle("invalid", ctx);
    return result;
}

func mir_native_parameter_argument_deferred_model(
    model: MirNativeParameterArgumentModel[ctx],
    reason_code: str,
    diagnostic: str,
    ctx: &Arena
) MirNativeParameterArgumentModel[ctx] {
    mut deferred := model;
    deferred.deferred = 1;
    deferred.reason_code = std.Clone(ctx, reason_code);
    deferred.diagnostic = std.Clone(ctx, diagnostic);
    return deferred;
}

func mir_native_parameter_argument_type_class(
    value_type: ast.Type[ctx],
    ctx: &Arena
) int {
    unsafe {
        if value_type.tag == 0 || value_type.tag == 2 {
            return 0;
        }
        if value_type.tag == 8 || value_type.tag == 10 {
            return 1;
        }
    }
    return 2;
}

func mir_native_parameter_argument_scan_deferred(
    programs: std.Vector[ast.Program[ctx], ctx],
    module_paths: std.Vector[str, ctx],
    module_prefixes: std.Vector[str, ctx],
    ctx: &Arena
) MirNativeParameterArgumentModel[ctx] {
    mut model := mir_native_parameter_argument_empty_model(ctx);
    if len(programs) != 1 ||
       len(module_paths) != 1 ||
       len(module_prefixes) != 1 ||
       std.str_eq(module_prefixes[0], "") == 0
    {
        return model;
    }

    mut program := programs[0];
    mut statements: std.Vector[ast.Statement[ctx], ctx] :=
        ctx[program.statements];
    mut index := 0;
    while index < len(statements) {
        mut statement := statements[index];
        unsafe {
            if statement.tag == 3 {
                mut parameters: std.Vector[ast.Parameter[ctx], ctx] :=
                    ctx[statement.FunctionDecl.params];
                mut parameter_index := 0;
                while parameter_index < len(parameters) {
                    mut parameter_class :=
                        mir_native_parameter_argument_type_class(
                            parameters[parameter_index].param_type,
                            ctx
                        );
                    if parameter_class == 1 {
                        model.source_path =
                            std.Clone(ctx, module_paths[0]);
                        return mir_native_parameter_argument_deferred_model(
                            model,
                            "deferred_p13_parameter_argument_aggregate_parameter",
                            "Phase 13.6 deferral: aggregate function parameters require later layout and ABI ownership",
                            ctx
                        );
                    }
                    if parameter_class == 2 {
                        model.source_path =
                            std.Clone(ctx, module_paths[0]);
                        return mir_native_parameter_argument_deferred_model(
                            model,
                            "deferred_p13_parameter_argument_target_dependent_abi",
                            "Phase 13.6 deferral: target-dependent or non-selected scalar parameter ABI",
                            ctx
                        );
                    }
                    parameter_index = parameter_index + 1;
                }
                mut return_type := ctx[statement.FunctionDecl.return_type];
                mut return_class :=
                    mir_native_parameter_argument_type_class(return_type, ctx);
                if return_class == 1 {
                    model.source_path = std.Clone(ctx, module_paths[0]);
                    return mir_native_parameter_argument_deferred_model(
                        model,
                        "deferred_p13_parameter_argument_aggregate_return",
                        "Phase 13.6 deferral: aggregate function returns require later layout and ABI ownership",
                        ctx
                    );
                }
                if return_class == 2 && return_type.tag != 3 {
                    model.source_path = std.Clone(ctx, module_paths[0]);
                    return mir_native_parameter_argument_deferred_model(
                        model,
                        "deferred_p13_parameter_argument_target_dependent_abi",
                        "Phase 13.6 deferral: target-dependent or non-selected scalar return ABI",
                        ctx
                    );
                }
            }
        }
        index = index + 1;
    }
    return model;
}

func mir_native_parameter_argument_parameter_index(
    names: std.Vector[str, ctx],
    name: str,
    ctx: &Arena
) int {
    mut index := 0;
    while index < len(names) {
        if std.str_eq(names[index], name) == 1 {
            return index;
        }
        index = index + 1;
    }
    return 0 - 1;
}

func mir_native_parameter_argument_analyze_helper(
    statement: ast.Statement[ctx],
    ctx: &Arena
) MirNativeParameterArgumentHelper[ctx] {
    mut helper := mir_native_parameter_argument_empty_helper(ctx);
    unsafe {
        if statement.tag != 3 || statement.FunctionDecl.is_extern == 1 {
            return helper;
        }
        mut parameters: std.Vector[ast.Parameter[ctx], ctx] :=
            ctx[statement.FunctionDecl.params];
        mut return_type := ctx[statement.FunctionDecl.return_type];
        if len(parameters) != 3 || return_type.tag != 0 {
            return helper;
        }

        mut parameter_names: std.Vector[str, ctx] := std.VectorNew(ctx);
        mut parameter_lines: std.Vector[int, ctx] := std.VectorNew(ctx);
        mut parameter_columns: std.Vector[int, ctx] := std.VectorNew(ctx);
        mut parameter_index := 0;
        while parameter_index < len(parameters) {
            if parameters[parameter_index].param_type.tag != 0 {
                return mir_native_parameter_argument_empty_helper(ctx);
            }
            if mir_native_parameter_argument_parameter_index(
                parameter_names,
                parameters[parameter_index].name,
                ctx
            ) >= 0 {
                return mir_native_parameter_argument_empty_helper(ctx);
            }
            parameter_names.Push(
                std.Clone(ctx, parameters[parameter_index].name)
            );
            parameter_lines.Push(
                parameters[parameter_index].span.start.line
            );
            parameter_columns.Push(
                parameters[parameter_index].span.start.column
            );
            parameter_index = parameter_index + 1;
        }

        mut body := ctx[statement.FunctionDecl.body];
        mut body_statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[body.statements];
        if len(body_statements) != 1 ||
           body_statements[0].tag != 12
        {
            return mir_native_parameter_argument_empty_helper(ctx);
        }

        mut expression := ctx[body_statements[0].Return.expr];
        if expression.tag != 10 ||
           std.str_eq(expression.Binary.op, "+") == 0
        {
            return mir_native_parameter_argument_empty_helper(ctx);
        }
        mut outer_left := ctx[expression.Binary.left];
        mut outer_right := ctx[expression.Binary.right];
        if outer_left.tag != 10 ||
           std.str_eq(outer_left.Binary.op, "+") == 0 ||
           outer_right.tag != 0 ||
           std.str_eq(
               outer_right.Identifier.name,
               parameter_names[2]
           ) == 0
        {
            return mir_native_parameter_argument_empty_helper(ctx);
        }
        mut inner_left := ctx[outer_left.Binary.left];
        mut inner_right := ctx[outer_left.Binary.right];
        if inner_left.tag != 0 ||
           inner_right.tag != 0 ||
           std.str_eq(
               inner_left.Identifier.name,
               parameter_names[0]
           ) == 0 ||
           std.str_eq(
               inner_right.Identifier.name,
               parameter_names[1]
           ) == 0
        {
            return mir_native_parameter_argument_empty_helper(ctx);
        }

        helper.represented = 1;
        helper.name = std.Clone(ctx, statement.FunctionDecl.name);
        helper.parameter_names = parameter_names;
        helper.parameter_lines = parameter_lines;
        helper.parameter_columns = parameter_columns;
        return helper;
    }
}

func mir_native_parameter_argument_call_three_literals(
    expression: ast.Expression[ctx],
    helper_name: str,
    ctx: &Arena
) MirNativeParameterArgumentModel[ctx] {
    mut model := mir_native_parameter_argument_empty_model(ctx);
    unsafe {
        if expression.tag != 12 {
            return model;
        }
        mut callee := ctx[expression.Call.function];
        mut arguments: std.Vector[ast.Expression[ctx], ctx] :=
            ctx[expression.Call.arguments];
        if callee.tag != 0 ||
           std.str_eq(callee.Identifier.name, helper_name) == 0 ||
           len(arguments) != 3 ||
           arguments[0].tag != 1 ||
           arguments[1].tag != 1 ||
           arguments[2].tag != 1
        {
            return model;
        }
        model.represented = 1;
        model.first_argument_0 = arguments[0].Integer.val;
        model.first_argument_1 = arguments[1].Integer.val;
        model.first_argument_2 = arguments[2].Integer.val;
        return model;
    }
}

func mir_native_parameter_argument_analyze_branch(
    statements: std.Vector[ast.Statement[ctx], ctx],
    helper: MirNativeParameterArgumentHelper[ctx],
    ctx: &Arena
) MirNativeParameterArgumentModel[ctx] {
    mut model := mir_native_parameter_argument_empty_model(ctx);
    if len(statements) != 3 {
        return model;
    }
    unsafe {
        mut declaration := statements[0];
        mut branch := statements[1];
        mut fallback := statements[2];
        if declaration.tag != 4 ||
           declaration.VarDecl.value ==
               empty[Index[ast.Expression[ctx], ctx]] ||
           branch.tag != 7 ||
           fallback.tag != 12
        {
            return model;
        }
        mut call_expression := ctx[declaration.VarDecl.value];
        mut call := mir_native_parameter_argument_call_three_literals(
            call_expression,
            helper.name,
            ctx
        );
        if call.represented == 0 {
            return model;
        }

        mut condition := ctx[branch.If.condition];
        mut consequence := ctx[branch.If.consequence];
        mut alternative := ctx[branch.If.alternative];
        mut then_statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[consequence.statements];
        mut else_statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[alternative.statements];
        mut fallback_expression := ctx[fallback.Return.expr];
        if condition.tag != 10 ||
           std.str_eq(condition.Binary.op, ">") == 0 ||
           len(then_statements) != 1 ||
           then_statements[0].tag != 12 ||
           len(else_statements) != 0 ||
           fallback_expression.tag != 1
        {
            return model;
        }
        mut condition_left := ctx[condition.Binary.left];
        mut condition_right := ctx[condition.Binary.right];
        mut then_expression := ctx[then_statements[0].Return.expr];
        if condition_left.tag != 0 ||
           condition_right.tag != 1 ||
           condition_right.Integer.val != 0 ||
           then_expression.tag != 0 ||
           std.str_eq(
               condition_left.Identifier.name,
               declaration.VarDecl.name
           ) == 0 ||
           std.str_eq(
               then_expression.Identifier.name,
               declaration.VarDecl.name
           ) == 0
        {
            return model;
        }

        model.represented = 1;
        model.profile = 0;
        model.helper = helper;
        model.first_local =
            std.Clone(ctx, declaration.VarDecl.name);
        model.first_argument_0 = call.first_argument_0;
        model.first_argument_1 = call.first_argument_1;
        model.first_argument_2 = call.first_argument_2;
        model.else_value = fallback_expression.Integer.val;
        model.expected_exit =
            model.first_argument_0 +
            model.first_argument_1 +
            model.first_argument_2;
        return model;
    }
}

func mir_native_parameter_argument_analyze_repeated(
    statements: std.Vector[ast.Statement[ctx], ctx],
    helper: MirNativeParameterArgumentHelper[ctx],
    ctx: &Arena
) MirNativeParameterArgumentModel[ctx] {
    mut model := mir_native_parameter_argument_empty_model(ctx);
    if len(statements) != 3 {
        return model;
    }
    unsafe {
        mut first := statements[0];
        mut second := statements[1];
        mut returned := statements[2];
        if first.tag != 4 ||
           second.tag != 4 ||
           returned.tag != 12 ||
           first.VarDecl.value ==
               empty[Index[ast.Expression[ctx], ctx]] ||
           second.VarDecl.value ==
               empty[Index[ast.Expression[ctx], ctx]]
        {
            return model;
        }

        mut first_expression := ctx[first.VarDecl.value];
        mut first_call := mir_native_parameter_argument_call_three_literals(
            first_expression,
            helper.name,
            ctx
        );
        mut second_expression := ctx[second.VarDecl.value];
        if first_call.represented == 0 ||
           second_expression.tag != 12
        {
            return model;
        }
        mut second_callee := ctx[second_expression.Call.function];
        mut second_arguments: std.Vector[ast.Expression[ctx], ctx] :=
            ctx[second_expression.Call.arguments];
        if second_callee.tag != 0 ||
           std.str_eq(second_callee.Identifier.name, helper.name) == 0 ||
           len(second_arguments) != 3 ||
           second_arguments[0].tag != 0 ||
           std.str_eq(
               second_arguments[0].Identifier.name,
               first.VarDecl.name
           ) == 0 ||
           second_arguments[1].tag != 1 ||
           second_arguments[2].tag != 1
        {
            return model;
        }

        mut return_expression := ctx[returned.Return.expr];
        if return_expression.tag != 10 ||
           std.str_eq(return_expression.Binary.op, "+") == 0
        {
            return model;
        }
        mut return_left := ctx[return_expression.Binary.left];
        mut return_right := ctx[return_expression.Binary.right];
        if return_left.tag != 0 ||
           std.str_eq(return_left.Identifier.name, second.VarDecl.name) == 0 ||
           return_right.tag != 1
        {
            return model;
        }

        model.represented = 1;
        model.profile = 1;
        model.helper = helper;
        model.first_local = std.Clone(ctx, first.VarDecl.name);
        model.second_local = std.Clone(ctx, second.VarDecl.name);
        model.first_argument_0 = first_call.first_argument_0;
        model.first_argument_1 = first_call.first_argument_1;
        model.first_argument_2 = first_call.first_argument_2;
        model.second_argument_1 = second_arguments[1].Integer.val;
        model.second_argument_2 = second_arguments[2].Integer.val;
        model.final_add = return_right.Integer.val;
        model.expected_exit =
            model.first_argument_0 +
            model.first_argument_1 +
            model.first_argument_2 +
            model.second_argument_1 +
            model.second_argument_2 +
            model.final_add;
        return model;
    }
}

func mir_native_parameter_argument_assignment_call(
    statement: ast.Statement[ctx],
    destination: str,
    helper_name: str,
    local_position: int,
    local_name: str,
    ctx: &Arena
) MirNativeParameterArgumentModel[ctx] {
    mut model := mir_native_parameter_argument_empty_model(ctx);
    unsafe {
        if statement.tag != 5 {
            return model;
        }
        mut left := ctx[statement.Assignment.left];
        mut value := ctx[statement.Assignment.value];
        if left.tag != 0 ||
           std.str_eq(left.Identifier.name, destination) == 0 ||
           value.tag != 12
        {
            return model;
        }
        mut callee := ctx[value.Call.function];
        mut arguments: std.Vector[ast.Expression[ctx], ctx] :=
            ctx[value.Call.arguments];
        if callee.tag != 0 ||
           std.str_eq(callee.Identifier.name, helper_name) == 0 ||
           len(arguments) != 3
        {
            return model;
        }
        mut index := 0;
        while index < 3 {
            if index == local_position {
                if arguments[index].tag != 0 ||
                   std.str_eq(
                       arguments[index].Identifier.name,
                       local_name
                   ) == 0
                {
                    return model;
                }
            } else if arguments[index].tag != 1 {
                return model;
            }
            index = index + 1;
        }
        model.represented = 1;
        if local_position == 0 {
            model.second_argument_1 = arguments[1].Integer.val;
            model.second_argument_2 = arguments[2].Integer.val;
        } else {
            model.second_argument_1 = arguments[0].Integer.val;
            model.second_argument_2 = arguments[2].Integer.val;
        }
        return model;
    }
}

func mir_native_parameter_argument_analyze_join(
    statements: std.Vector[ast.Statement[ctx], ctx],
    helper: MirNativeParameterArgumentHelper[ctx],
    ctx: &Arena
) MirNativeParameterArgumentModel[ctx] {
    mut model := mir_native_parameter_argument_empty_model(ctx);
    if len(statements) != 4 {
        return model;
    }
    unsafe {
        mut called := statements[0];
        mut result := statements[1];
        mut branch := statements[2];
        mut returned := statements[3];
        if called.tag != 4 ||
           result.tag != 4 ||
           branch.tag != 7 ||
           returned.tag != 12 ||
           called.VarDecl.value ==
               empty[Index[ast.Expression[ctx], ctx]] ||
           result.VarDecl.value ==
               empty[Index[ast.Expression[ctx], ctx]]
        {
            return model;
        }

        mut called_expression := ctx[called.VarDecl.value];
        mut first_call := mir_native_parameter_argument_call_three_literals(
            called_expression,
            helper.name,
            ctx
        );
        mut result_expression := ctx[result.VarDecl.value];
        mut return_expression := ctx[returned.Return.expr];
        if first_call.represented == 0 ||
           result_expression.tag != 1 ||
           return_expression.tag != 0 ||
           std.str_eq(
               return_expression.Identifier.name,
               result.VarDecl.name
           ) == 0
        {
            return model;
        }

        mut condition := ctx[branch.If.condition];
        mut consequence := ctx[branch.If.consequence];
        mut alternative := ctx[branch.If.alternative];
        mut then_statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[consequence.statements];
        mut else_statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[alternative.statements];
        if condition.tag != 10 ||
           std.str_eq(condition.Binary.op, ">") == 0 ||
           len(then_statements) != 1 ||
           len(else_statements) != 1
        {
            return model;
        }
        mut condition_left := ctx[condition.Binary.left];
        mut condition_right := ctx[condition.Binary.right];
        if condition_left.tag != 0 ||
           std.str_eq(
               condition_left.Identifier.name,
               called.VarDecl.name
           ) == 0 ||
           condition_right.tag != 1 ||
           condition_right.Integer.val != 0
        {
            return model;
        }

        mut then_call := mir_native_parameter_argument_assignment_call(
            then_statements[0],
            result.VarDecl.name,
            helper.name,
            0,
            called.VarDecl.name,
            ctx
        );
        mut else_call := mir_native_parameter_argument_assignment_call(
            else_statements[0],
            result.VarDecl.name,
            helper.name,
            1,
            called.VarDecl.name,
            ctx
        );
        if then_call.represented == 0 ||
           else_call.represented == 0
        {
            return model;
        }

        model.represented = 1;
        model.profile = 2;
        model.helper = helper;
        model.first_local = std.Clone(ctx, called.VarDecl.name);
        model.second_local = std.Clone(ctx, result.VarDecl.name);
        model.first_argument_0 = first_call.first_argument_0;
        model.first_argument_1 = first_call.first_argument_1;
        model.first_argument_2 = first_call.first_argument_2;
        model.second_argument_1 = then_call.second_argument_1;
        model.second_argument_2 = then_call.second_argument_2;
        model.else_value = else_call.second_argument_1;
        model.final_add = else_call.second_argument_2;
        model.expected_exit =
            model.first_argument_0 +
            model.first_argument_1 +
            model.first_argument_2 +
            model.second_argument_1 +
            model.second_argument_2;
        return model;
    }
}

func mir_native_parameter_argument_analyze_loop(
    statements: std.Vector[ast.Statement[ctx], ctx],
    helper: MirNativeParameterArgumentHelper[ctx],
    ctx: &Arena
) MirNativeParameterArgumentModel[ctx] {
    mut model := mir_native_parameter_argument_empty_model(ctx);
    if len(statements) != 4 {
        return model;
    }
    unsafe {
        mut remaining := statements[0];
        mut total := statements[1];
        mut loop_statement := statements[2];
        mut returned := statements[3];
        if remaining.tag != 4 ||
           total.tag != 4 ||
           loop_statement.tag != 6 ||
           returned.tag != 12 ||
           remaining.VarDecl.value ==
               empty[Index[ast.Expression[ctx], ctx]] ||
           total.VarDecl.value ==
               empty[Index[ast.Expression[ctx], ctx]]
        {
            return model;
        }
        mut remaining_value := ctx[remaining.VarDecl.value];
        mut total_value := ctx[total.VarDecl.value];
        mut return_expression := ctx[returned.Return.expr];
        if remaining_value.tag != 1 ||
           total_value.tag != 1 ||
           return_expression.tag != 0 ||
           std.str_eq(
               return_expression.Identifier.name,
               total.VarDecl.name
           ) == 0
        {
            return model;
        }

        mut condition := ctx[loop_statement.While.condition];
        mut loop_body := ctx[loop_statement.While.body];
        mut loop_statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[loop_body.statements];
        if condition.tag != 10 ||
           std.str_eq(condition.Binary.op, ">") == 0 ||
           len(loop_statements) != 2
        {
            return model;
        }
        mut condition_left := ctx[condition.Binary.left];
        mut condition_right := ctx[condition.Binary.right];
        if condition_left.tag != 0 ||
           std.str_eq(
               condition_left.Identifier.name,
               remaining.VarDecl.name
           ) == 0 ||
           condition_right.tag != 1 ||
           condition_right.Integer.val != 0
        {
            return model;
        }

        mut total_assignment := loop_statements[0];
        mut remaining_assignment := loop_statements[1];
        if total_assignment.tag != 5 ||
           remaining_assignment.tag != 5
        {
            return model;
        }
        mut total_left := ctx[total_assignment.Assignment.left];
        mut total_call := ctx[total_assignment.Assignment.value];
        if total_left.tag != 0 ||
           std.str_eq(total_left.Identifier.name, total.VarDecl.name) == 0 ||
           total_call.tag != 12
        {
            return model;
        }
        mut callee := ctx[total_call.Call.function];
        mut arguments: std.Vector[ast.Expression[ctx], ctx] :=
            ctx[total_call.Call.arguments];
        if callee.tag != 0 ||
           std.str_eq(callee.Identifier.name, helper.name) == 0 ||
           len(arguments) != 3 ||
           arguments[0].tag != 0 ||
           std.str_eq(
               arguments[0].Identifier.name,
               total.VarDecl.name
           ) == 0 ||
           arguments[1].tag != 1 ||
           arguments[2].tag != 1
        {
            return model;
        }

        mut remaining_left := ctx[remaining_assignment.Assignment.left];
        mut remaining_expression :=
            ctx[remaining_assignment.Assignment.value];
        if remaining_left.tag != 0 ||
           std.str_eq(
               remaining_left.Identifier.name,
               remaining.VarDecl.name
           ) == 0 ||
           remaining_expression.tag != 10 ||
           std.str_eq(remaining_expression.Binary.op, "-") == 0
        {
            return model;
        }
        mut decrement_left := ctx[remaining_expression.Binary.left];
        mut decrement_right := ctx[remaining_expression.Binary.right];
        if decrement_left.tag != 0 ||
           std.str_eq(
               decrement_left.Identifier.name,
               remaining.VarDecl.name
           ) == 0 ||
           decrement_right.tag != 1 ||
           decrement_right.Integer.val != 1
        {
            return model;
        }

        if remaining_value.Integer.val < 0 ||
           remaining_value.Integer.val > 1024
        {
            model.represented = 1;
            model.invalid = 1;
            model.diagnostic = std.Clone(
                ctx,
                "Native backend canonical MIR verification failed: Phase 13.6 loop-call composition requires a bounded iteration count in 0..=1024"
            );
            return model;
        }

        model.represented = 1;
        model.profile = 3;
        model.helper = helper;
        model.first_local = std.Clone(ctx, remaining.VarDecl.name);
        model.second_local = std.Clone(ctx, total.VarDecl.name);
        model.loop_count = remaining_value.Integer.val;
        model.loop_initial = total_value.Integer.val;
        model.loop_argument_1 = arguments[1].Integer.val;
        model.loop_argument_2 = arguments[2].Integer.val;
        model.expected_exit =
            model.loop_initial +
            model.loop_count *
                (model.loop_argument_1 + model.loop_argument_2);
        return model;
    }
}

func mir_native_parameter_argument_analyze(
    programs: std.Vector[ast.Program[ctx], ctx],
    module_paths: std.Vector[str, ctx],
    module_prefixes: std.Vector[str, ctx],
    ctx: &Arena
) MirNativeParameterArgumentModel[ctx] {
    mut deferred := mir_native_parameter_argument_scan_deferred(
        programs,
        module_paths,
        module_prefixes,
        ctx
    );
    if deferred.deferred == 1 {
        return deferred;
    }

    mut model := mir_native_parameter_argument_empty_model(ctx);
    if len(programs) != 1 ||
       len(module_paths) != 1 ||
       len(module_prefixes) != 1 ||
       std.str_eq(module_prefixes[0], "") == 0
    {
        return model;
    }

    mut program := programs[0];
    mut top_level: std.Vector[ast.Statement[ctx], ctx] :=
        ctx[program.statements];
    if len(top_level) != 2 {
        return model;
    }

    mut helper := mir_native_parameter_argument_empty_helper(ctx);
    mut main_statement: ast.Statement[ctx];
    mut main_found := 0;
    mut index := 0;
    while index < len(top_level) {
        mut statement := top_level[index];
        unsafe {
            if statement.tag != 3 ||
               statement.FunctionDecl.is_extern == 1
            {
                return model;
            }
            if std.str_eq(statement.FunctionDecl.name, "main") == 1 {
                mut parameters: std.Vector[ast.Parameter[ctx], ctx] :=
                    ctx[statement.FunctionDecl.params];
                mut return_type := ctx[statement.FunctionDecl.return_type];
                if len(parameters) != 0 || return_type.tag != 0 {
                    return model;
                }
                main_statement = statement;
                main_found = 1;
            } else {
                helper =
                    mir_native_parameter_argument_analyze_helper(
                        statement,
                        ctx
                    );
            }
        }
        index = index + 1;
    }
    if helper.represented == 0 || main_found == 0 {
        return model;
    }

    unsafe {
        mut body := ctx[main_statement.FunctionDecl.body];
        mut statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[body.statements];

        model = mir_native_parameter_argument_analyze_branch(
            statements,
            helper,
            ctx
        );
        if model.represented == 0 {
            model = mir_native_parameter_argument_analyze_repeated(
                statements,
                helper,
                ctx
            );
        }
        if model.represented == 0 {
            model = mir_native_parameter_argument_analyze_join(
                statements,
                helper,
                ctx
            );
        }
        if model.represented == 0 {
            model = mir_native_parameter_argument_analyze_loop(
                statements,
                helper,
                ctx
            );
        }
    }

    if model.represented == 1 {
        model.source_path = std.Clone(ctx, module_paths[0]);
    }
    return model;
}

func mir_native_parameter_argument_emit_call_literal(
    output: str,
    prefix: str,
    index: int,
    value: int,
    ctx: &Arena
) str {
    mut key := mir_native_parameter_argument_append(
        prefix,
        "_argument_",
        ctx
    );
    key = mir_native_parameter_argument_append_int(key, index, ctx);
    mut emitted := mir_native_parameter_argument_field(
        output,
        mir_native_parameter_argument_append(key, "_kind", ctx),
        "I32Literal",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        mir_native_parameter_argument_append(key, "_value", ctx),
        value,
        ctx
    );
    return std.Clone(ctx, emitted);
}

func mir_native_parameter_argument_emit_call_local(
    output: str,
    prefix: str,
    index: int,
    local_name: str,
    ctx: &Arena
) str {
    mut key := mir_native_parameter_argument_append(
        prefix,
        "_argument_",
        ctx
    );
    key = mir_native_parameter_argument_append_int(key, index, ctx);
    mut emitted := mir_native_parameter_argument_field(
        output,
        mir_native_parameter_argument_append(key, "_kind", ctx),
        "LocalI32",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        mir_native_parameter_argument_append(key, "_local", ctx),
        local_name,
        ctx
    );
    return std.Clone(ctx, emitted);
}

func mir_native_parameter_argument_emit_call_block_parameter(
    output: str,
    prefix: str,
    index: int,
    parameter_name: str,
    ctx: &Arena
) str {
    mut key := mir_native_parameter_argument_append(
        prefix,
        "_argument_",
        ctx
    );
    key = mir_native_parameter_argument_append_int(key, index, ctx);
    mut emitted := mir_native_parameter_argument_field(
        output,
        mir_native_parameter_argument_append(key, "_kind", ctx),
        "BlockParamI32",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        mir_native_parameter_argument_append(
            key,
            "_block_param",
            ctx
        ),
        parameter_name,
        ctx
    );
    return std.Clone(ctx, emitted);
}

func mir_native_parameter_argument_emit_call_header(
    output: str,
    prefix: str,
    local_name: str,
    helper_name: str,
    ctx: &Arena
) str {
    mut emitted := mir_native_parameter_argument_field(
        output,
        mir_native_parameter_argument_append(prefix, "_kind", ctx),
        "LocalI32SetCall",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        mir_native_parameter_argument_append(prefix, "_local", ctx),
        local_name,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        mir_native_parameter_argument_append(
            prefix,
            "_callee_kind",
            ctx
        ),
        "LocalFunction",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        mir_native_parameter_argument_append(prefix, "_callee", ctx),
        helper_name,
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        mir_native_parameter_argument_append(
            prefix,
            "_argument_count",
            ctx
        ),
        3,
        ctx
    );
    return std.Clone(ctx, emitted);
}

func mir_native_parameter_argument_emit_edge_literal(
    output: str,
    prefix: str,
    index: int,
    value: int,
    ctx: &Arena
) str {
    mut key := mir_native_parameter_argument_append(
        prefix,
        "_argument_",
        ctx
    );
    key = mir_native_parameter_argument_append_int(key, index, ctx);
    mut emitted := mir_native_parameter_argument_field(
        output,
        mir_native_parameter_argument_append(key, "_kind", ctx),
        "I32Literal",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        mir_native_parameter_argument_append(key, "_value", ctx),
        value,
        ctx
    );
    return std.Clone(ctx, emitted);
}

func mir_native_parameter_argument_emit_edge_block_parameter(
    output: str,
    prefix: str,
    index: int,
    parameter_name: str,
    delta: int,
    with_delta: int,
    ctx: &Arena
) str {
    mut key := mir_native_parameter_argument_append(
        prefix,
        "_argument_",
        ctx
    );
    key = mir_native_parameter_argument_append_int(key, index, ctx);
    mut kind := "BlockParamI32";
    if with_delta == 1 {
        kind = "BlockParamI32AddI32Literal";
    }
    mut emitted := mir_native_parameter_argument_field(
        output,
        mir_native_parameter_argument_append(key, "_kind", ctx),
        kind,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        mir_native_parameter_argument_append(
            key,
            "_block_param",
            ctx
        ),
        parameter_name,
        ctx
    );
    if with_delta == 1 {
        emitted = mir_native_parameter_argument_int_field(
            emitted,
            mir_native_parameter_argument_append(key, "_value", ctx),
            delta,
            ctx
        );
    }
    return std.Clone(ctx, emitted);
}

func mir_native_parameter_argument_emit_edge_local(
    output: str,
    prefix: str,
    index: int,
    local_name: str,
    ctx: &Arena
) str {
    mut key := mir_native_parameter_argument_append(
        prefix,
        "_argument_",
        ctx
    );
    key = mir_native_parameter_argument_append_int(key, index, ctx);
    mut emitted := mir_native_parameter_argument_field(
        output,
        mir_native_parameter_argument_append(key, "_kind", ctx),
        "LocalI32",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        mir_native_parameter_argument_append(key, "_local", ctx),
        local_name,
        ctx
    );
    return std.Clone(ctx, emitted);
}

func mir_native_parameter_argument_profile_name(
    profile: int,
    ctx: &Arena
) str {
    if profile == 0 {
        return std.Clone(ctx, "branch_condition");
    }
    if profile == 1 {
        return std.Clone(ctx, "repeated_calls_expression");
    }
    if profile == 2 {
        return std.Clone(ctx, "cfg_join");
    }
    return std.Clone(ctx, "loop_carried_call_state");
}

func mir_native_parameter_argument_emit_parameter_metadata(
    output: str,
    model: MirNativeParameterArgumentModel[ctx],
    parameter_index: int,
    ctx: &Arena
) str {
    mut names := model.helper.parameter_names;
    mut lines := model.helper.parameter_lines;
    mut columns := model.helper.parameter_columns;
    mut prefix := mir_native_parameter_argument_append(
        "function_0_metadata_",
        std.FormatInt(parameter_index),
        ctx
    );
    mut emitted := mir_native_parameter_argument_field(
        output,
        mir_native_parameter_argument_append(prefix, "_kind", ctx),
        "provenance",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        mir_native_parameter_argument_append(prefix, "_attachment", ctx),
        "function",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        mir_native_parameter_argument_append(prefix, "_policy", ctx),
        "recognized_preserved",
        ctx
    );

    mut payload := std.Clone(
        ctx,
        "kind=FunctionParameter;contract=phase13_6;namespace="
    );
    payload = mir_native_parameter_argument_append(
        payload,
        model.helper.name,
        ctx
    );
    payload = mir_native_parameter_argument_append(payload, ";name=", ctx);
    payload = mir_native_parameter_argument_append(
        payload,
        names[parameter_index],
        ctx
    );
    payload = mir_native_parameter_argument_append(payload, ";index=", ctx);
    payload = mir_native_parameter_argument_append_int(
        payload,
        parameter_index,
        ctx
    );
    payload = mir_native_parameter_argument_append(
        payload,
        ";type=int;origin=",
        ctx
    );
    payload = mir_native_parameter_argument_append(
        payload,
        model.source_path,
        ctx
    );
    payload = mir_native_parameter_argument_append(payload, ";line=", ctx);
    payload = mir_native_parameter_argument_append_int(
        payload,
        lines[parameter_index],
        ctx
    );
    payload = mir_native_parameter_argument_append(payload, ";column=", ctx);
    payload = mir_native_parameter_argument_append_int(
        payload,
        columns[parameter_index],
        ctx
    );
    payload = mir_native_parameter_argument_append(
        payload,
        ";codegen=preserved",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        mir_native_parameter_argument_append(prefix, "_payload", ctx),
        payload,
        ctx
    );
    return std.Clone(ctx, emitted);
}

func mir_native_parameter_argument_emit_helper(
    output: str,
    model: MirNativeParameterArgumentModel[ctx],
    ctx: &Arena
) str {
    mut emitted := output;
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_0_linkage",
        "module_local",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_0_function",
        model.helper.name,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_0_backend_symbol",
        model.helper.name,
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_0_parameter_count",
        3,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_0_parameter_0_type",
        "int",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_0_parameter_1_type",
        "int",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_0_parameter_2_type",
        "int",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_0_return_type",
        "int",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_0_local_count",
        1,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_0_local_0_name",
        "return_value",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_0_local_0_type",
        "int",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_0_entry_block",
        "entry",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_0_block_count",
        1,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_0_block_0_label",
        "entry",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_0_block_0_parameter_count",
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_0_block_0_statement_count",
        3,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_0_block_0_statement_0_kind",
        "LocalI32SetParam",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_0_block_0_statement_0_local",
        "return_value",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_0_block_0_statement_0_param",
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_0_block_0_statement_1_kind",
        "LocalI32AddParam",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_0_block_0_statement_1_local",
        "return_value",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_0_block_0_statement_1_param",
        1,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_0_block_0_statement_2_kind",
        "LocalI32AddParam",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_0_block_0_statement_2_local",
        "return_value",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_0_block_0_statement_2_param",
        2,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_0_block_0_terminator_kind",
        "ReturnLocalI32",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_0_block_0_terminator_local",
        "return_value",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_0_metadata_count",
        3,
        ctx
    );
    mut parameter_index := 0;
    while parameter_index < 3 {
        emitted = mir_native_parameter_argument_emit_parameter_metadata(
            emitted,
            model,
            parameter_index,
            ctx
        );
        parameter_index = parameter_index + 1;
    }
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_0_expected_exit",
        0,
        ctx
    );
    return std.Clone(ctx, emitted);
}

func mir_native_parameter_argument_emit_main_metadata(
    output: str,
    model: MirNativeParameterArgumentModel[ctx],
    ctx: &Arena
) str {
    mut emitted := mir_native_parameter_argument_int_field(
        output,
        "function_1_metadata_count",
        1,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_metadata_0_kind",
        "provenance",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_metadata_0_attachment",
        "function",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_metadata_0_policy",
        "recognized_preserved",
        ctx
    );
    mut payload := std.Clone(
        ctx,
        "kind=ParameterArgumentContract;contract=phase13_6;profile="
    );
    payload = mir_native_parameter_argument_append(
        payload,
        mir_native_parameter_argument_profile_name(model.profile, ctx),
        ctx
    );
    payload = mir_native_parameter_argument_append(
        payload,
        ";parameter_order=source;argument_order=source;namespace=single_module;origin=",
        ctx
    );
    payload = mir_native_parameter_argument_append(
        payload,
        model.source_path,
        ctx
    );
    payload = mir_native_parameter_argument_append(
        payload,
        ";line=1;column=1;codegen=preserved",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_metadata_0_payload",
        payload,
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_expected_exit",
        model.expected_exit,
        ctx
    );
    return std.Clone(ctx, emitted);
}

func mir_native_parameter_argument_emit_main_header(
    output: str,
    local_count: int,
    model: MirNativeParameterArgumentModel[ctx],
    ctx: &Arena
) str {
    mut emitted := output;
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_linkage",
        "exported_entry",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_function",
        "main",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_backend_symbol",
        "main",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_parameter_count",
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_return_type",
        "int",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_local_count",
        local_count,
        ctx
    );
    if local_count > 0 {
        mut local_0_name := model.first_local;
        if model.profile == 3 {
            local_0_name = model.call_result_local;
        }
        emitted = mir_native_parameter_argument_field(
            emitted,
            "function_1_local_0_name",
            local_0_name,
            ctx
        );
        emitted = mir_native_parameter_argument_field(
            emitted,
            "function_1_local_0_type",
            "int",
            ctx
        );
    }
    if local_count > 1 {
        emitted = mir_native_parameter_argument_field(
            emitted,
            "function_1_local_1_name",
            model.second_local,
            ctx
        );
        emitted = mir_native_parameter_argument_field(
            emitted,
            "function_1_local_1_type",
            "int",
            ctx
        );
    }
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_entry_block",
        "entry",
        ctx
    );
    return std.Clone(ctx, emitted);
}

func mir_native_parameter_argument_emit_first_call(
    output: str,
    prefix: str,
    local_name: str,
    model: MirNativeParameterArgumentModel[ctx],
    ctx: &Arena
) str {
    mut emitted := mir_native_parameter_argument_emit_call_header(
        output,
        prefix,
        local_name,
        model.helper.name,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_call_literal(
        emitted,
        prefix,
        0,
        model.first_argument_0,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_call_literal(
        emitted,
        prefix,
        1,
        model.first_argument_1,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_call_literal(
        emitted,
        prefix,
        2,
        model.first_argument_2,
        ctx
    );
    return std.Clone(ctx, emitted);
}

func mir_native_parameter_argument_emit_branch_profile(
    output: str,
    model: MirNativeParameterArgumentModel[ctx],
    ctx: &Arena
) str {
    mut emitted := mir_native_parameter_argument_emit_main_header(
        output,
        1,
        model,
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_count",
        3,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_0_label",
        "entry",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_0_parameter_count",
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_0_statement_count",
        1,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_first_call(
        emitted,
        "function_1_block_0_statement_0",
        model.first_local,
        model,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_0_terminator_kind",
        "BranchLocalI32Positive",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_0_terminator_local",
        model.first_local,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_0_terminator_then",
        "then",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_0_terminator_then_argument_count",
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_0_terminator_else",
        "else",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_0_terminator_else_argument_count",
        0,
        ctx
    );

    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_1_label",
        "then",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_1_parameter_count",
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_1_statement_count",
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_1_terminator_kind",
        "ReturnLocalI32",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_1_terminator_local",
        model.first_local,
        ctx
    );

    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_2_label",
        "else",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_2_parameter_count",
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_2_statement_count",
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_2_terminator_kind",
        "ReturnI32",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_2_terminator_value",
        model.else_value,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_main_metadata(
        emitted,
        model,
        ctx
    );
    return std.Clone(ctx, emitted);
}

func mir_native_parameter_argument_emit_repeated_profile(
    output: str,
    model: MirNativeParameterArgumentModel[ctx],
    ctx: &Arena
) str {
    mut emitted := mir_native_parameter_argument_emit_main_header(
        output,
        2,
        model,
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_count",
        1,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_0_label",
        "entry",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_0_parameter_count",
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_0_statement_count",
        3,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_first_call(
        emitted,
        "function_1_block_0_statement_0",
        model.first_local,
        model,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_call_header(
        emitted,
        "function_1_block_0_statement_1",
        model.second_local,
        model.helper.name,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_call_local(
        emitted,
        "function_1_block_0_statement_1",
        0,
        model.first_local,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_call_literal(
        emitted,
        "function_1_block_0_statement_1",
        1,
        model.second_argument_1,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_call_literal(
        emitted,
        "function_1_block_0_statement_1",
        2,
        model.second_argument_2,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_0_statement_2_kind",
        "LocalI32AddI32Literal",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_0_statement_2_local",
        model.second_local,
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_0_statement_2_value",
        model.final_add,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_0_terminator_kind",
        "ReturnLocalI32",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_0_terminator_local",
        model.second_local,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_main_metadata(
        emitted,
        model,
        ctx
    );
    return std.Clone(ctx, emitted);
}

func mir_native_parameter_argument_emit_join_profile(
    output: str,
    model: MirNativeParameterArgumentModel[ctx],
    ctx: &Arena
) str {
    mut emitted := mir_native_parameter_argument_emit_main_header(
        output,
        2,
        model,
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_count",
        4,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_0_label",
        "entry",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_0_parameter_count",
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_0_statement_count",
        2,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_first_call(
        emitted,
        "function_1_block_0_statement_0",
        model.first_local,
        model,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_0_statement_1_kind",
        "LocalI32Set",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_0_statement_1_local",
        model.second_local,
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_0_statement_1_value",
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_0_terminator_kind",
        "BranchLocalI32Positive",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_0_terminator_local",
        model.first_local,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_0_terminator_then",
        "then",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_0_terminator_then_argument_count",
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_0_terminator_else",
        "else",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_0_terminator_else_argument_count",
        0,
        ctx
    );

    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_1_label",
        "then",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_1_parameter_count",
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_1_statement_count",
        1,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_call_header(
        emitted,
        "function_1_block_1_statement_0",
        model.second_local,
        model.helper.name,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_call_local(
        emitted,
        "function_1_block_1_statement_0",
        0,
        model.first_local,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_call_literal(
        emitted,
        "function_1_block_1_statement_0",
        1,
        model.second_argument_1,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_call_literal(
        emitted,
        "function_1_block_1_statement_0",
        2,
        model.second_argument_2,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_1_terminator_kind",
        "Jump",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_1_terminator_target",
        "merge",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_1_terminator_argument_count",
        0,
        ctx
    );

    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_2_label",
        "else",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_2_parameter_count",
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_2_statement_count",
        1,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_call_header(
        emitted,
        "function_1_block_2_statement_0",
        model.second_local,
        model.helper.name,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_call_literal(
        emitted,
        "function_1_block_2_statement_0",
        0,
        model.else_value,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_call_local(
        emitted,
        "function_1_block_2_statement_0",
        1,
        model.first_local,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_call_literal(
        emitted,
        "function_1_block_2_statement_0",
        2,
        model.final_add,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_2_terminator_kind",
        "Jump",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_2_terminator_target",
        "merge",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_2_terminator_argument_count",
        0,
        ctx
    );

    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_3_label",
        "merge",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_3_parameter_count",
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_3_statement_count",
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_3_terminator_kind",
        "ReturnLocalI32",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_3_terminator_local",
        model.second_local,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_main_metadata(
        emitted,
        model,
        ctx
    );
    return std.Clone(ctx, emitted);
}

func mir_native_parameter_argument_emit_loop_profile(
    output: str,
    model: MirNativeParameterArgumentModel[ctx],
    ctx: &Arena
) str {
    mut emitted := mir_native_parameter_argument_emit_main_header(
        output,
        1,
        model,
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_count",
        4,
        ctx
    );

    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_0_label",
        "entry",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_0_parameter_count",
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_0_statement_count",
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_0_terminator_kind",
        "Jump",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_0_terminator_target",
        "loop_header",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_0_terminator_argument_count",
        2,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_edge_literal(
        emitted,
        "function_1_block_0_terminator",
        0,
        model.loop_count,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_edge_literal(
        emitted,
        "function_1_block_0_terminator",
        1,
        model.loop_initial,
        ctx
    );

    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_1_label",
        "loop_header",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_1_parameter_count",
        2,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_1_parameter_0_name",
        model.first_local,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_1_parameter_0_type",
        "int",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_1_parameter_1_name",
        model.second_local,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_1_parameter_1_type",
        "int",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_1_statement_count",
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_1_terminator_kind",
        "BranchBlockParamI32Positive",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_1_terminator_block_param",
        model.first_local,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_1_terminator_then",
        "loop_body",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_1_terminator_then_argument_count",
        2,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_edge_block_parameter(
        emitted,
        "function_1_block_1_terminator_then",
        0,
        model.first_local,
        0,
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_edge_block_parameter(
        emitted,
        "function_1_block_1_terminator_then",
        1,
        model.second_local,
        0,
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_1_terminator_else",
        "loop_exit",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_1_terminator_else_argument_count",
        2,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_edge_block_parameter(
        emitted,
        "function_1_block_1_terminator_else",
        0,
        model.first_local,
        0,
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_edge_block_parameter(
        emitted,
        "function_1_block_1_terminator_else",
        1,
        model.second_local,
        0,
        0,
        ctx
    );

    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_2_label",
        "loop_body",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_2_parameter_count",
        2,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_2_parameter_0_name",
        "body_remaining",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_2_parameter_0_type",
        "int",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_2_parameter_1_name",
        "body_total",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_2_parameter_1_type",
        "int",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_2_statement_count",
        1,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_call_header(
        emitted,
        "function_1_block_2_statement_0",
        model.call_result_local,
        model.helper.name,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_call_block_parameter(
        emitted,
        "function_1_block_2_statement_0",
        0,
        "body_total",
        ctx
    );
    emitted = mir_native_parameter_argument_emit_call_literal(
        emitted,
        "function_1_block_2_statement_0",
        1,
        model.loop_argument_1,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_call_literal(
        emitted,
        "function_1_block_2_statement_0",
        2,
        model.loop_argument_2,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_2_terminator_kind",
        "Jump",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_2_terminator_target",
        "loop_header",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_2_terminator_argument_count",
        2,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_edge_block_parameter(
        emitted,
        "function_1_block_2_terminator",
        0,
        "body_remaining",
        0 - 1,
        1,
        ctx
    );
    emitted = mir_native_parameter_argument_emit_edge_local(
        emitted,
        "function_1_block_2_terminator",
        1,
        model.call_result_local,
        ctx
    );

    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_3_label",
        "loop_exit",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_3_parameter_count",
        2,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_3_parameter_0_name",
        "exit_remaining",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_3_parameter_0_type",
        "int",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_3_parameter_1_name",
        "exit_total",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_3_parameter_1_type",
        "int",
        ctx
    );
    emitted = mir_native_parameter_argument_int_field(
        emitted,
        "function_1_block_3_statement_count",
        0,
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_3_terminator_kind",
        "ReturnBlockParamI32",
        ctx
    );
    emitted = mir_native_parameter_argument_field(
        emitted,
        "function_1_block_3_terminator_block_param",
        "exit_total",
        ctx
    );
    emitted = mir_native_parameter_argument_emit_main_metadata(
        emitted,
        model,
        ctx
    );
    return std.Clone(ctx, emitted);
}

func mir_native_parameter_argument_emit_bundle(
    model: MirNativeParameterArgumentModel[ctx],
    ctx: &Arena
) mir.MirProgramBundle[ctx] {
    mut canonical :=
        "format: gust.compiler_mir_ingestion.v2\nmodule: phase13_parameter_arguments\nimport_count: 0\nfunction_count: 2\n";
    canonical = mir_native_parameter_argument_emit_helper(
        canonical,
        model,
        ctx
    );
    if model.profile == 0 {
        canonical = mir_native_parameter_argument_emit_branch_profile(
            canonical,
            model,
            ctx
        );
    } else if model.profile == 1 {
        canonical = mir_native_parameter_argument_emit_repeated_profile(
            canonical,
            model,
            ctx
        );
    } else if model.profile == 2 {
        canonical = mir_native_parameter_argument_emit_join_profile(
            canonical,
            model,
            ctx
        );
    } else {
        canonical = mir_native_parameter_argument_emit_loop_profile(
            canonical,
            model,
            ctx
        );
    }

    mut bundle := mir.mir_make_program_bundle("main", ctx);
    mut module := mir.mir_make_program_bundle_module(
        model.source_path,
        "",
        "phase13_parameter_arguments_module.o",
        "gust.compiler_mir_ingestion.v2",
        canonical,
        0,
        4,
        0,
        ctx
    );
    module = mir.mir_program_bundle_module_with_symbol(
        module,
        mir.mir_make_program_bundle_symbol(
            model.helper.name,
            model.helper.name,
            "(int,int,int)->int",
            1,
            ctx
        ),
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

func mir_native_parameter_argument_source_lower(
    programs: std.Vector[ast.Program[ctx], ctx],
    module_paths: std.Vector[str, ctx],
    module_prefixes: std.Vector[str, ctx],
    ctx: &Arena
) MirNativeParameterArgumentSourceResult[ctx] {
    mut result := mir_native_parameter_argument_empty_result(ctx);
    mut model := mir_native_parameter_argument_analyze(
        programs,
        module_paths,
        module_prefixes,
        ctx
    );
    if model.deferred == 1 {
        result.deferred = 1;
        result.reason_code = model.reason_code;
        result.diagnostic = model.diagnostic;
        return result;
    }
    if model.represented == 0 {
        return result;
    }
    result.represented = 1;
    if model.invalid == 1 {
        result.invalid = 1;
        result.diagnostic = model.diagnostic;
        return result;
    }
    result.bundle = mir_native_parameter_argument_emit_bundle(model, ctx);
    return result;
}
