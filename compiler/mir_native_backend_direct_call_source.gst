import "ast.gst" as ast;
import "mir.gst" as mir;
import "mir_native_backend_metadata_source.gst" as metadata_source;

// Compiler-owned direct-function and scalar-ABI lowering.
//
// This route consumes typed AST structure only. It accepts one source module
// containing statically named direct functions, integer and boolean scalar ABI
// values, arbitrary supported parameter counts, and an acyclic call graph.
// Indirect calls, closures, extern imports, recursion, and non-scalar ABI values
// remain explicitly deferred.
type MirNativeDirectCallArgument[ctx] struct {
    kind: int,
    value: int,
    parameter_index: int,
    value_type: str
}

type MirNativeDirectCallFunction[ctx] struct {
    name: str,
    source_line: int,
    source_column: int,
    parameter_names: Index[std.Vector[str, ctx], ctx],
    parameter_types: Index[std.Vector[str, ctx], ctx],
    return_type: str,
    profile: int,
    first_parameter: int,
    second_parameter: int,
    callee: str,
    arguments: Index[std.Vector[MirNativeDirectCallArgument[ctx], ctx], ctx],
    sequence_first_local: str,
    sequence_second_local: str,
    sequence_initial_value: int,
    sequence_before_add: int,
    sequence_after_add: int,
    graph_first_local: str,
    graph_second_local: str,
    graph_first_callee: str,
    graph_second_callee: str,
    graph_first_argument: int,
    graph_after_add: int
}

type MirNativeDirectCallModel[ctx] struct {
    represented: int,
    invalid: int,
    deferred: int,
    reason_code: str,
    diagnostic: str,
    source_path: str,
    functions: Index[std.Vector[MirNativeDirectCallFunction[ctx], ctx], ctx],
    entry_index: int,
    expected_exit: int,
    graph_profile: int
}

type MirNativeDirectCallEvaluation struct {
    valid: int,
    value: int
}

type MirNativeDirectCallSourceResult[ctx] struct {
    represented: int,
    invalid: int,
    deferred: int,
    reason_code: str,
    diagnostic: str,
    bundle: mir.MirProgramBundle[ctx]
}

func mir_native_direct_call_append(output: str, value: str, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat(output, value));
}

func mir_native_direct_call_append_int(output: str, value: int, ctx: &Arena) str {
    mut formatted := std.FormatInt(value);
    return std.Clone(ctx, std.Concat(output, formatted));
}

func mir_native_direct_call_empty_argument_vector(ctx: &Arena) Index[std.Vector[MirNativeDirectCallArgument[ctx], ctx], ctx] {
    mut arguments: std.Vector[MirNativeDirectCallArgument[ctx], ctx] :=
        std.VectorNew(ctx);
    mut arguments_index:
        Index[std.Vector[MirNativeDirectCallArgument[ctx], ctx], ctx] :=
            os.ArenaAlloc(ctx);
    ctx.Set(arguments_index, arguments);
    return arguments_index;
}

func mir_native_direct_call_empty_string_vector(ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut values: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut values_index: Index[std.Vector[str, ctx], ctx] :=
        os.ArenaAlloc(ctx);
    ctx.Set(values_index, values);
    return values_index;
}

func mir_native_direct_call_empty_function_vector(ctx: &Arena) Index[std.Vector[MirNativeDirectCallFunction[ctx], ctx], ctx] {
    mut functions: std.Vector[MirNativeDirectCallFunction[ctx], ctx] :=
        std.VectorNew(ctx);
    mut functions_index:
        Index[std.Vector[MirNativeDirectCallFunction[ctx], ctx], ctx] :=
            os.ArenaAlloc(ctx);
    ctx.Set(functions_index, functions);
    return functions_index;
}

func mir_native_direct_call_empty_model(ctx: &Arena) MirNativeDirectCallModel[ctx] {
    mut model: MirNativeDirectCallModel[ctx];
    model.represented = 0;
    model.invalid = 0;
    model.deferred = 0;
    model.reason_code = std.Clone(ctx, "");
    model.diagnostic = std.Clone(ctx, "");
    model.source_path = std.Clone(ctx, "");
    model.functions = mir_native_direct_call_empty_function_vector(ctx);
    model.entry_index = 0 - 1;
    model.expected_exit = 0;
    model.graph_profile = 0;
    return model;
}

func mir_native_direct_call_empty_result(ctx: &Arena) MirNativeDirectCallSourceResult[ctx] {
    mut result: MirNativeDirectCallSourceResult[ctx];
    result.represented = 0;
    result.invalid = 0;
    result.deferred = 0;
    result.reason_code = std.Clone(ctx, "");
    result.diagnostic = std.Clone(ctx, "");
    result.bundle = mir.mir_make_program_bundle("invalid", ctx);
    return result;
}

func mir_native_direct_call_invalid(model: MirNativeDirectCallModel[ctx], diagnostic: str, ctx: &Arena) MirNativeDirectCallModel[ctx] {
    mut invalid := model;
    invalid.represented = 1;
    invalid.invalid = 1;
    invalid.diagnostic = std.Clone(ctx, diagnostic);
    return invalid;
}

func mir_native_direct_call_deferred(
    model: MirNativeDirectCallModel[ctx],
    reason_code: str,
    diagnostic: str,
    ctx: &Arena
) MirNativeDirectCallModel[ctx] {
    mut deferred := model;
    deferred.represented = 1;
    deferred.deferred = 1;
    deferred.reason_code = std.Clone(ctx, reason_code);
    deferred.diagnostic = std.Clone(ctx, diagnostic);
    return deferred;
}

func mir_native_direct_call_type_name(value_type: ast.Type[ctx], ctx: &Arena) str {
    unsafe {
        if value_type.tag == 0 {
            return std.Clone(ctx, "int");
        }
        if value_type.tag == 2 {
            return std.Clone(ctx, "bool");
        }
    }
    return std.Clone(ctx, "");
}

func mir_native_direct_call_parameter_index(names: std.Vector[str, ctx], name: str, ctx: &Arena) int {
    mut index := 0;
    while index < len(names) {
        if std.str_eq(names[index], name) == 1 {
            return index;
        }
        index = index + 1;
    }
    return 0 - 1;
}

func mir_native_direct_call_function_index(functions: std.Vector[MirNativeDirectCallFunction[ctx], ctx], name: str, ctx: &Arena) int {
    mut index := 0;
    while index < len(functions) {
        if std.str_eq(functions[index].name, name) == 1 {
            return index;
        }
        index = index + 1;
    }
    return 0 - 1;
}

func mir_native_direct_call_analyze_argument(expression: ast.Expression[ctx], parameter_names: std.Vector[str, ctx], parameter_types: std.Vector[str, ctx], ctx: &Arena) MirNativeDirectCallArgument[ctx] {
    mut argument: MirNativeDirectCallArgument[ctx];
    argument.kind = 0 - 1;
    argument.value = 0;
    argument.parameter_index = 0 - 1;
    argument.value_type = std.Clone(ctx, "");
    unsafe {
        if expression.tag == 1 {
            argument.kind = 0;
            argument.value = expression.Integer.val;
            argument.value_type = std.Clone(ctx, "int");
            return argument;
        }
        if expression.tag == 3 {
            argument.kind = 1;
            argument.value = expression.Bool.val;
            argument.value_type = std.Clone(ctx, "bool");
            return argument;
        }
        if expression.tag == 0 {
            mut parameter_index := mir_native_direct_call_parameter_index(
                parameter_names,
                expression.Identifier.name,
                ctx
            );
            if parameter_index < 0 {
                return argument;
            }
            argument.kind = 2;
            argument.parameter_index = parameter_index;
            argument.value_type =
                std.Clone(ctx, parameter_types[parameter_index]);
            return argument;
        }
    }
    return argument;
}

func mir_native_direct_call_analyze_function(statement: ast.Statement[ctx], ctx: &Arena) MirNativeDirectCallFunction[ctx] {
    mut function: MirNativeDirectCallFunction[ctx];
    function.name = std.Clone(ctx, "");
    function.source_line = 0;
    function.source_column = 0;
    function.parameter_names = mir_native_direct_call_empty_string_vector(ctx);
    function.parameter_types = mir_native_direct_call_empty_string_vector(ctx);
    function.return_type = std.Clone(ctx, "");
    function.profile = 0 - 1;
    function.first_parameter = 0 - 1;
    function.second_parameter = 0 - 1;
    function.callee = std.Clone(ctx, "");
    function.arguments = mir_native_direct_call_empty_argument_vector(ctx);
    function.sequence_first_local = std.Clone(ctx, "");
    function.sequence_second_local = std.Clone(ctx, "");
    function.sequence_initial_value = 0;
    function.sequence_before_add = 0;
    function.sequence_after_add = 0;
    function.graph_first_local = std.Clone(ctx, "");
    function.graph_second_local = std.Clone(ctx, "");
    function.graph_first_callee = std.Clone(ctx, "");
    function.graph_second_callee = std.Clone(ctx, "");
    function.graph_first_argument = 0;
    function.graph_after_add = 0;

    unsafe {
        if statement.tag != 3 || statement.FunctionDecl.is_extern == 1 {
            return function;
        }
        function.name = std.Clone(ctx, statement.FunctionDecl.name);
        function.source_line = statement.FunctionDecl.span.start.line;
        function.source_column = statement.FunctionDecl.span.start.column;

        mut parameter_names: std.Vector[str, ctx] := std.VectorNew(ctx);
        mut parameter_types: std.Vector[str, ctx] := std.VectorNew(ctx);
        mut parameters: std.Vector[ast.Parameter[ctx], ctx] :=
            ctx[statement.FunctionDecl.params];
        mut parameter_index := 0;
        while parameter_index < len(parameters) {
            mut parameter := parameters[parameter_index];
            mut parameter_type := mir_native_direct_call_type_name(
                parameter.param_type,
                ctx
            );
            if len(parameter_type) == 0 {
                return function;
            }
            parameter_names.Push(std.Clone(ctx, parameter.name));
            parameter_types.Push(parameter_type);
            parameter_index = parameter_index + 1;
        }
        ctx.Set(function.parameter_names, parameter_names);
        ctx.Set(function.parameter_types, parameter_types);

        mut return_type_ast := ctx[statement.FunctionDecl.return_type];
        function.return_type =
            mir_native_direct_call_type_name(return_type_ast, ctx);
        if len(function.return_type) == 0 {
            return function;
        }

        mut body := ctx[statement.FunctionDecl.body];
        mut statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[body.statements];

        if std.str_eq(function.name, "main") == 1 &&
           len(parameter_names) == 0 &&
           std.str_eq(function.return_type, "int") == 1 &&
           len(statements) == 4 &&
           statements[0].tag == 4 &&
           statements[1].tag == 4 &&
           statements[2].tag == 5 &&
           statements[3].tag == 12
        {
            mut first_decl := statements[0];
            mut second_decl := statements[1];
            mut after_assignment := statements[2];
            mut return_statement := statements[3];
            if first_decl.VarDecl.is_mut == 0 ||
               second_decl.VarDecl.is_mut == 0 ||
               first_decl.VarDecl.value ==
                   empty[Index[ast.Expression[ctx], ctx]] ||
               second_decl.VarDecl.value ==
                   empty[Index[ast.Expression[ctx], ctx]]
            {
                return function;
            }
            if first_decl.VarDecl.var_type !=
                   empty[Index[ast.Type[ctx], ctx]] &&
               ctx[first_decl.VarDecl.var_type].tag != 0
            {
                return function;
            }
            if second_decl.VarDecl.var_type !=
                   empty[Index[ast.Type[ctx], ctx]] &&
               ctx[second_decl.VarDecl.var_type].tag != 0
            {
                return function;
            }
            if std.str_eq(
                   first_decl.VarDecl.name,
                   second_decl.VarDecl.name
               ) == 1
            {
                return function;
            }

            mut first_call := ctx[first_decl.VarDecl.value];
            mut second_call := ctx[second_decl.VarDecl.value];
            mut assignment_left := ctx[after_assignment.Assignment.left];
            mut assignment_value := ctx[after_assignment.Assignment.value];
            mut return_expression := ctx[return_statement.Return.expr];
            if first_call.tag != 12 ||
               second_call.tag != 12 ||
               assignment_left.tag != 0 ||
               std.str_eq(
                   assignment_left.Identifier.name,
                   second_decl.VarDecl.name
               ) == 0 ||
               assignment_value.tag != 10 ||
               std.str_eq(assignment_value.Binary.op, "+") == 0 ||
               return_expression.tag != 0 ||
               std.str_eq(
                   return_expression.Identifier.name,
                   second_decl.VarDecl.name
               ) == 0
            {
                return function;
            }

            mut first_callee := ctx[first_call.Call.function];
            mut second_callee := ctx[second_call.Call.function];
            mut first_arguments: std.Vector[ast.Expression[ctx], ctx] :=
                ctx[first_call.Call.arguments];
            mut second_arguments: std.Vector[ast.Expression[ctx], ctx] :=
                ctx[second_call.Call.arguments];
            mut add_left := ctx[assignment_value.Binary.left];
            mut add_right := ctx[assignment_value.Binary.right];
            if first_callee.tag != 0 ||
               second_callee.tag != 0 ||
               len(first_arguments) != 1 ||
               first_arguments[0].tag != 1 ||
               len(second_arguments) != 1 ||
               second_arguments[0].tag != 0 ||
               std.str_eq(
                   second_arguments[0].Identifier.name,
                   first_decl.VarDecl.name
               ) == 0 ||
               add_left.tag != 0 ||
               std.str_eq(
                   add_left.Identifier.name,
                   second_decl.VarDecl.name
               ) == 0 ||
               add_right.tag != 1
            {
                return function;
            }

            function.profile = 4;
            function.graph_first_local =
                std.Clone(ctx, first_decl.VarDecl.name);
            function.graph_second_local =
                std.Clone(ctx, second_decl.VarDecl.name);
            function.graph_first_callee =
                std.Clone(ctx, first_callee.Identifier.name);
            function.graph_second_callee =
                std.Clone(ctx, second_callee.Identifier.name);
            function.graph_first_argument =
                first_arguments[0].Integer.val;
            function.graph_after_add = add_right.Integer.val;
            return function;
        }

        if std.str_eq(function.name, "main") == 1 &&
           len(parameter_names) == 0 &&
           std.str_eq(function.return_type, "int") == 1 &&
           len(statements) == 5 &&
           statements[0].tag == 4 &&
           statements[1].tag == 5 &&
           statements[2].tag == 4 &&
           statements[3].tag == 5 &&
           statements[4].tag == 12
        {
            mut first_decl := statements[0];
            mut before_assignment := statements[1];
            mut second_decl := statements[2];
            mut after_assignment := statements[3];
            mut return_statement := statements[4];

            if first_decl.VarDecl.is_mut == 0 ||
               second_decl.VarDecl.is_mut == 0 ||
               first_decl.VarDecl.value ==
                   empty[Index[ast.Expression[ctx], ctx]] ||
               second_decl.VarDecl.value ==
                   empty[Index[ast.Expression[ctx], ctx]]
            {
                return function;
            }
            if first_decl.VarDecl.var_type !=
                   empty[Index[ast.Type[ctx], ctx]] &&
               ctx[first_decl.VarDecl.var_type].tag != 0
            {
                return function;
            }
            if second_decl.VarDecl.var_type !=
                   empty[Index[ast.Type[ctx], ctx]] &&
               ctx[second_decl.VarDecl.var_type].tag != 0
            {
                return function;
            }
            if std.str_eq(
                   first_decl.VarDecl.name,
                   second_decl.VarDecl.name
               ) == 1
            {
                return function;
            }

            mut initial_expression := ctx[first_decl.VarDecl.value];
            mut before_left := ctx[before_assignment.Assignment.left];
            mut before_value := ctx[before_assignment.Assignment.value];
            mut call_expression := ctx[second_decl.VarDecl.value];
            mut after_left := ctx[after_assignment.Assignment.left];
            mut after_value := ctx[after_assignment.Assignment.value];
            mut return_expression := ctx[return_statement.Return.expr];
            if initial_expression.tag != 1 ||
               before_left.tag != 0 ||
               std.str_eq(
                   before_left.Identifier.name,
                   first_decl.VarDecl.name
               ) == 0 ||
               before_value.tag != 10 ||
               std.str_eq(before_value.Binary.op, "+") == 0 ||
               call_expression.tag != 12 ||
               after_left.tag != 0 ||
               std.str_eq(
                   after_left.Identifier.name,
                   second_decl.VarDecl.name
               ) == 0 ||
               after_value.tag != 10 ||
               std.str_eq(after_value.Binary.op, "+") == 0 ||
               return_expression.tag != 0 ||
               std.str_eq(
                   return_expression.Identifier.name,
                   second_decl.VarDecl.name
               ) == 0
            {
                return function;
            }

            mut before_add_left := ctx[before_value.Binary.left];
            mut before_add_right := ctx[before_value.Binary.right];
            mut after_add_left := ctx[after_value.Binary.left];
            mut after_add_right := ctx[after_value.Binary.right];
            mut callee_expression := ctx[call_expression.Call.function];
            mut call_arguments: std.Vector[ast.Expression[ctx], ctx] :=
                ctx[call_expression.Call.arguments];
            if before_add_left.tag != 0 ||
               std.str_eq(
                   before_add_left.Identifier.name,
                   first_decl.VarDecl.name
               ) == 0 ||
               before_add_right.tag != 1 ||
               after_add_left.tag != 0 ||
               std.str_eq(
                   after_add_left.Identifier.name,
                   second_decl.VarDecl.name
               ) == 0 ||
               after_add_right.tag != 1 ||
               callee_expression.tag != 0 ||
               len(call_arguments) != 1 ||
               call_arguments[0].tag != 0 ||
               std.str_eq(
                   call_arguments[0].Identifier.name,
                   first_decl.VarDecl.name
               ) == 0
            {
                return function;
            }

            function.profile = 3;
            function.callee =
                std.Clone(ctx, callee_expression.Identifier.name);
            function.sequence_first_local =
                std.Clone(ctx, first_decl.VarDecl.name);
            function.sequence_second_local =
                std.Clone(ctx, second_decl.VarDecl.name);
            function.sequence_initial_value = initial_expression.Integer.val;
            function.sequence_before_add = before_add_right.Integer.val;
            function.sequence_after_add = after_add_right.Integer.val;

            mut arguments: std.Vector[MirNativeDirectCallArgument[ctx], ctx] :=
                std.VectorNew(ctx);
            mut local_argument: MirNativeDirectCallArgument[ctx];
            local_argument.kind = 3;
            local_argument.value = 0;
            local_argument.parameter_index = 0 - 1;
            local_argument.value_type = std.Clone(ctx, "int");
            arguments.Push(local_argument);
            ctx.Set(function.arguments, arguments);
            return function;
        }

        if len(statements) != 1 || statements[0].tag != 12 {
            return function;
        }
        mut expression := ctx[statements[0].Return.expr];

        if expression.tag == 0 {
            mut return_parameter := mir_native_direct_call_parameter_index(
                parameter_names,
                expression.Identifier.name,
                ctx
            );
            if return_parameter < 0 ||
               std.str_eq(
                   parameter_types[return_parameter],
                   function.return_type
               ) == 0
            {
                return function;
            }
            function.profile = 0;
            function.first_parameter = return_parameter;
            return function;
        }

        if expression.tag == 10 &&
           std.str_eq(expression.Binary.op, "+") == 1 &&
           std.str_eq(function.return_type, "int") == 1
        {
            mut left := ctx[expression.Binary.left];
            mut right := ctx[expression.Binary.right];
            if left.tag != 0 || right.tag != 0 {
                return function;
            }
            mut left_parameter := mir_native_direct_call_parameter_index(
                parameter_names,
                left.Identifier.name,
                ctx
            );
            mut right_parameter := mir_native_direct_call_parameter_index(
                parameter_names,
                right.Identifier.name,
                ctx
            );
            if left_parameter < 0 || right_parameter < 0 ||
               std.str_eq(parameter_types[left_parameter], "int") == 0 ||
               std.str_eq(parameter_types[right_parameter], "int") == 0
            {
                return function;
            }
            function.profile = 1;
            function.first_parameter = left_parameter;
            function.second_parameter = right_parameter;
            return function;
        }

        if expression.tag == 12 {
            mut callee := ctx[expression.Call.function];
            if callee.tag != 0 {
                return function;
            }
            function.profile = 2;
            function.callee = std.Clone(ctx, callee.Identifier.name);
            mut arguments: std.Vector[MirNativeDirectCallArgument[ctx], ctx] :=
                std.VectorNew(ctx);
            mut source_arguments: std.Vector[ast.Expression[ctx], ctx] :=
                ctx[expression.Call.arguments];
            mut argument_index := 0;
            while argument_index < len(source_arguments) {
                mut argument := mir_native_direct_call_analyze_argument(
                    source_arguments[argument_index],
                    parameter_names,
                    parameter_types,
                    ctx
                );
                if argument.kind < 0 {
                    function.profile = 0 - 1;
                    return function;
                }
                arguments.Push(argument);
                argument_index = argument_index + 1;
            }
            ctx.Set(function.arguments, arguments);
            return function;
        }
    }

    return function;
}

func mir_native_direct_call_validate_calls(model: MirNativeDirectCallModel[ctx], ctx: &Arena) MirNativeDirectCallModel[ctx] {
    mut functions: std.Vector[MirNativeDirectCallFunction[ctx], ctx] :=
        ctx[model.functions];
    mut caller_index := 0;
    while caller_index < len(functions) {
        mut caller := functions[caller_index];
        if caller.profile == 2 || caller.profile == 3 {
            mut callee_index := mir_native_direct_call_function_index(
                functions,
                caller.callee,
                ctx
            );
            if callee_index < 0 {
                return mir_native_direct_call_invalid(
                    model,
                    "Native backend canonical MIR verification failed: missing direct-call symbol",
                    ctx
                );
            }
            mut callee := functions[callee_index];
            mut callee_parameter_types: std.Vector[str, ctx] :=
                ctx[callee.parameter_types];
            mut arguments: std.Vector[MirNativeDirectCallArgument[ctx], ctx] :=
                ctx[caller.arguments];
            if len(arguments) != len(callee_parameter_types) {
                return mir_native_direct_call_invalid(
                    model,
                    "Native backend canonical MIR verification failed: direct-call argument count does not match callee parameter count",
                    ctx
                );
            }
            mut argument_index := 0;
            while argument_index < len(arguments) {
                if std.str_eq(
                    arguments[argument_index].value_type,
                    callee_parameter_types[argument_index]
                ) == 0 {
                    return mir_native_direct_call_invalid(
                        model,
                        "Native backend canonical MIR verification failed: direct-call argument type does not match callee parameter type",
                        ctx
                    );
                }
                argument_index = argument_index + 1;
            }
            if std.str_eq(caller.return_type, callee.return_type) == 0 {
                return mir_native_direct_call_invalid(
                    model,
                    "Native backend canonical MIR verification failed: direct-call return type does not match caller return type",
                    ctx
                );
            }
        } else if caller.profile == 4 {
            mut first_index := mir_native_direct_call_function_index(
                functions,
                caller.graph_first_callee,
                ctx
            );
            mut second_index := mir_native_direct_call_function_index(
                functions,
                caller.graph_second_callee,
                ctx
            );
            if first_index < 0 || second_index < 0 {
                return mir_native_direct_call_invalid(
                    model,
                    "Native backend canonical MIR verification failed: missing direct-call graph symbol",
                    ctx
                );
            }
            mut first_callee := functions[first_index];
            mut second_callee := functions[second_index];
            mut first_parameters: std.Vector[str, ctx] :=
                ctx[first_callee.parameter_types];
            mut second_parameters: std.Vector[str, ctx] :=
                ctx[second_callee.parameter_types];
            if len(first_parameters) != 1 ||
               len(second_parameters) != 1 ||
               std.str_eq(first_parameters[0], "int") == 0 ||
               std.str_eq(second_parameters[0], "int") == 0 ||
               std.str_eq(first_callee.return_type, "int") == 0 ||
               std.str_eq(second_callee.return_type, "int") == 0 ||
               std.str_eq(caller.return_type, "int") == 0
            {
                return mir_native_direct_call_invalid(
                    model,
                    "Native backend canonical MIR verification failed: direct-call graph declarations are incompatible",
                    ctx
                );
            }
        }
        caller_index = caller_index + 1;
    }
    return model;
}

func mir_native_direct_call_validate_acyclic(model: MirNativeDirectCallModel[ctx], ctx: &Arena) MirNativeDirectCallModel[ctx] {
    mut functions: std.Vector[MirNativeDirectCallFunction[ctx], ctx] :=
        ctx[model.functions];
    mut indegree: std.Vector[int, ctx] := std.VectorNew(ctx);
    mut removed: std.Vector[int, ctx] := std.VectorNew(ctx);
    mut index := 0;
    while index < len(functions) {
        indegree.Push(0);
        removed.Push(0);
        index = index + 1;
    }

    index = 0;
    while index < len(functions) {
        mut function := functions[index];
        if function.profile == 2 || function.profile == 3 {
            mut callee_index := mir_native_direct_call_function_index(
                functions,
                function.callee,
                ctx
            );
            if callee_index < 0 {
                return mir_native_direct_call_invalid(
                    model,
                    "Native backend canonical MIR verification failed: missing direct-call symbol",
                    ctx
                );
            }
            if callee_index == index {
                return mir_native_direct_call_deferred(
                    model,
                    "deferred_p13_recursive_direct_call_policy",
                    "Native backend direct-call graph must be acyclic: direct recursion remains deferred in Phase 13.7",
                    ctx
                );
            }
            indegree.Set(callee_index, indegree[callee_index] + 1);
        } else if function.profile == 4 {
            mut first_index := mir_native_direct_call_function_index(
                functions,
                function.graph_first_callee,
                ctx
            );
            mut second_index := mir_native_direct_call_function_index(
                functions,
                function.graph_second_callee,
                ctx
            );
            if first_index < 0 || second_index < 0 {
                return mir_native_direct_call_invalid(
                    model,
                    "Native backend canonical MIR verification failed: missing direct-call graph symbol",
                    ctx
                );
            }
            if first_index == index || second_index == index {
                return mir_native_direct_call_deferred(
                    model,
                    "deferred_p13_recursive_direct_call_policy",
                    "Native backend direct-call graph must be acyclic: direct recursion remains deferred in Phase 13.7",
                    ctx
                );
            }
            indegree.Set(first_index, indegree[first_index] + 1);
            indegree.Set(second_index, indegree[second_index] + 1);
        }
        index = index + 1;
    }

    mut visited := 0;
    while visited < len(functions) {
        mut selected := 0 - 1;
        index = 0;
        while index < len(functions) {
            if removed[index] == 0 && indegree[index] == 0 {
                selected = index;
                break;
            }
            index = index + 1;
        }
        if selected < 0 {
            return mir_native_direct_call_deferred(
                model,
                "deferred_p13_mutual_recursive_direct_call_policy",
                "Native backend direct-call graph must be acyclic: mutual recursion remains deferred in Phase 13.7",
                ctx
            );
        }
        removed.Set(selected, 1);
        visited = visited + 1;
        mut selected_function := functions[selected];
        if selected_function.profile == 2 ||
           selected_function.profile == 3
        {
            mut selected_callee := mir_native_direct_call_function_index(
                functions,
                selected_function.callee,
                ctx
            );
            indegree.Set(
                selected_callee,
                indegree[selected_callee] - 1
            );
        } else if selected_function.profile == 4 {
            mut first_callee := mir_native_direct_call_function_index(
                functions,
                selected_function.graph_first_callee,
                ctx
            );
            mut second_callee := mir_native_direct_call_function_index(
                functions,
                selected_function.graph_second_callee,
                ctx
            );
            indegree.Set(
                first_callee,
                indegree[first_callee] - 1
            );
            indegree.Set(
                second_callee,
                indegree[second_callee] - 1
            );
        }
    }
    return model;
}

func mir_native_direct_call_evaluate(functions: std.Vector[MirNativeDirectCallFunction[ctx], ctx], function_index: int, parameter_values: std.Vector[int, ctx], depth: int, ctx: &Arena) MirNativeDirectCallEvaluation {
    mut evaluation: MirNativeDirectCallEvaluation;
    evaluation.valid = 0;
    evaluation.value = 0;
    if function_index < 0 || function_index >= len(functions) ||
       depth > len(functions)
    {
        return evaluation;
    }

    mut function := functions[function_index];
    mut parameter_types: std.Vector[str, ctx] := ctx[function.parameter_types];
    if len(parameter_values) != len(parameter_types) {
        return evaluation;
    }

    if function.profile == 0 {
        if function.first_parameter < 0 ||
           function.first_parameter >= len(parameter_values)
        {
            return evaluation;
        }
        evaluation.valid = 1;
        evaluation.value = parameter_values[function.first_parameter];
        return evaluation;
    }

    if function.profile == 1 {
        if function.first_parameter < 0 ||
           function.second_parameter < 0 ||
           function.first_parameter >= len(parameter_values) ||
           function.second_parameter >= len(parameter_values)
        {
            return evaluation;
        }
        evaluation.valid = 1;
        evaluation.value =
            parameter_values[function.first_parameter] +
            parameter_values[function.second_parameter];
        return evaluation;
    }

    if function.profile == 2 {
        mut callee_index := mir_native_direct_call_function_index(
            functions,
            function.callee,
            ctx
        );
        if callee_index < 0 {
            return evaluation;
        }
        mut call_values: std.Vector[int, ctx] := std.VectorNew(ctx);
        mut arguments: std.Vector[MirNativeDirectCallArgument[ctx], ctx] :=
            ctx[function.arguments];
        mut argument_index := 0;
        while argument_index < len(arguments) {
            mut argument := arguments[argument_index];
            if argument.kind == 0 || argument.kind == 1 {
                call_values.Push(argument.value);
            } else if argument.kind == 2 &&
                      argument.parameter_index >= 0 &&
                      argument.parameter_index < len(parameter_values)
            {
                call_values.Push(
                    parameter_values[argument.parameter_index]
                );
            } else {
                return evaluation;
            }
            argument_index = argument_index + 1;
        }
        return mir_native_direct_call_evaluate(
            functions,
            callee_index,
            call_values,
            depth + 1,
            ctx
        );
    }

    if function.profile == 3 {
        mut callee_index := mir_native_direct_call_function_index(
            functions,
            function.callee,
            ctx
        );
        if callee_index < 0 {
            return evaluation;
        }
        mut call_values: std.Vector[int, ctx] := std.VectorNew(ctx);
        call_values.Push(
            function.sequence_initial_value +
            function.sequence_before_add
        );
        mut called := mir_native_direct_call_evaluate(
            functions,
            callee_index,
            call_values,
            depth + 1,
            ctx
        );
        if called.valid == 0 {
            return evaluation;
        }
        evaluation.valid = 1;
        evaluation.value = called.value + function.sequence_after_add;
        return evaluation;
    }

    if function.profile == 4 {
        mut first_index := mir_native_direct_call_function_index(
            functions,
            function.graph_first_callee,
            ctx
        );
        mut second_index := mir_native_direct_call_function_index(
            functions,
            function.graph_second_callee,
            ctx
        );
        if first_index < 0 || second_index < 0 {
            return evaluation;
        }
        mut first_values: std.Vector[int, ctx] := std.VectorNew(ctx);
        first_values.Push(function.graph_first_argument);
        mut first_called := mir_native_direct_call_evaluate(
            functions,
            first_index,
            first_values,
            depth + 1,
            ctx
        );
        if first_called.valid == 0 {
            return evaluation;
        }
        mut second_values: std.Vector[int, ctx] := std.VectorNew(ctx);
        second_values.Push(first_called.value);
        mut second_called := mir_native_direct_call_evaluate(
            functions,
            second_index,
            second_values,
            depth + 1,
            ctx
        );
        if second_called.valid == 0 {
            return evaluation;
        }
        evaluation.valid = 1;
        evaluation.value =
            second_called.value + function.graph_after_add;
        return evaluation;
    }

    return evaluation;
}

func mir_native_direct_call_analyze(programs: std.Vector[ast.Program[ctx], ctx], module_paths: std.Vector[str, ctx], module_prefixes: std.Vector[str, ctx], ctx: &Arena) MirNativeDirectCallModel[ctx] {
    mut model := mir_native_direct_call_empty_model(ctx);
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
    if len(top_level) < 2 {
        return model;
    }

    mut functions: std.Vector[MirNativeDirectCallFunction[ctx], ctx] :=
        std.VectorNew(ctx);
    mut has_call := 0;
    mut entry_index := 0 - 1;
    mut index := 0;
    while index < len(top_level) {
        mut function := mir_native_direct_call_analyze_function(
            top_level[index],
            ctx
        );
        if len(function.name) == 0 || function.profile < 0 {
            return model;
        }
        if mir_native_direct_call_function_index(
            functions,
            function.name,
            ctx
        ) >= 0 {
            model.functions = mir_native_direct_call_empty_function_vector(ctx);
            return mir_native_direct_call_invalid(
                model,
                "Native backend canonical MIR verification failed: duplicate direct-call function name",
                ctx
            );
        }
        if std.str_eq(function.name, "main") == 1 {
            if entry_index >= 0 {
                model.functions =
                    mir_native_direct_call_empty_function_vector(ctx);
                return mir_native_direct_call_invalid(
                    model,
                    "Native backend canonical MIR verification failed: multiple direct-call entry functions",
                    ctx
                );
            }
            entry_index = index;
        }
        if function.profile == 2 ||
           function.profile == 3 ||
           function.profile == 4
        {
            has_call = 1;
        }
        if function.profile == 4 {
            model.graph_profile = 1;
        }
        functions.Push(function);
        index = index + 1;
    }

    if has_call == 0 || entry_index < 0 {
        return model;
    }
    mut entry := functions[entry_index];
    mut entry_parameters: std.Vector[str, ctx] :=
        ctx[entry.parameter_types];
    if len(entry_parameters) != 0 ||
       std.str_eq(entry.return_type, "int") == 0
    {
        model.functions = mir_native_direct_call_empty_function_vector(ctx);
        return mir_native_direct_call_invalid(
            model,
            "Native backend canonical MIR verification failed: direct-call entry must have signature ()->int",
            ctx
        );
    }

    model.represented = 1;
    model.source_path = std.Clone(ctx, module_paths[0]);
    model.entry_index = entry_index;
    ctx.Set(model.functions, functions);

    model = mir_native_direct_call_validate_calls(model, ctx);
    if model.invalid == 1 {
        return model;
    }
    model = mir_native_direct_call_validate_acyclic(model, ctx);
    if model.invalid == 1 {
        return model;
    }

    mut no_arguments: std.Vector[int, ctx] := std.VectorNew(ctx);
    mut evaluation := mir_native_direct_call_evaluate(
        functions,
        entry_index,
        no_arguments,
        0,
        ctx
    );
    if evaluation.valid == 0 ||
       evaluation.value < 0 ||
       evaluation.value > 255
    {
        return mir_native_direct_call_invalid(
            model,
            "Native backend canonical MIR verification failed: direct-call entry result is not a deterministic exit value in 0..=255",
            ctx
        );
    }
    model.expected_exit = evaluation.value;
    return model;
}

func mir_native_direct_call_signature(function: MirNativeDirectCallFunction[ctx], ctx: &Arena) str {
    mut signature := std.Clone(ctx, "(");
    mut parameter_types: std.Vector[str, ctx] :=
        ctx[function.parameter_types];
    mut index := 0;
    while index < len(parameter_types) {
        if index > 0 {
            signature = mir_native_direct_call_append(
                signature,
                ",",
                ctx
            );
        }
        signature = mir_native_direct_call_append(
            signature,
            parameter_types[index],
            ctx
        );
        index = index + 1;
    }
    signature = mir_native_direct_call_append(signature, ")->", ctx);
    signature = mir_native_direct_call_append(
        signature,
        function.return_type,
        ctx
    );
    return std.Clone(ctx, signature);
}

func mir_native_direct_call_backend_symbol(
    function: MirNativeDirectCallFunction[ctx],
    graph_profile: int,
    ctx: &Arena
) str {
    if graph_profile == 1 &&
       std.str_eq(function.name, "main") == 0
    {
        return mir_native_direct_call_append(
            "phase13_direct_call_graph__",
            function.name,
            ctx
        );
    }
    return std.Clone(ctx, function.name);
}

func mir_native_direct_call_emit_argument(output: str, function_index: int, argument_index: int, argument: MirNativeDirectCallArgument[ctx], ctx: &Arena) str {
    mut emitted := output;
    emitted = mir_native_direct_call_append(emitted, "function_", ctx);
    emitted = mir_native_direct_call_append_int(
        emitted,
        function_index,
        ctx
    );
    emitted = mir_native_direct_call_append(
        emitted,
        "_block_0_statement_0_argument_",
        ctx
    );
    emitted = mir_native_direct_call_append_int(
        emitted,
        argument_index,
        ctx
    );
    emitted = mir_native_direct_call_append(emitted, "_kind: ", ctx);
    if argument.kind == 0 {
        emitted = mir_native_direct_call_append(
            emitted,
            "I32Literal\n",
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "function_", ctx);
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_0_argument_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            argument_index,
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "_value: ", ctx);
        emitted = mir_native_direct_call_append_int(
            emitted,
            argument.value,
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "\n", ctx);
    } else if argument.kind == 1 {
        emitted = mir_native_direct_call_append(
            emitted,
            "BoolLiteral\n",
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "function_", ctx);
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_0_argument_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            argument_index,
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "_value: ", ctx);
        emitted = mir_native_direct_call_append_int(
            emitted,
            argument.value,
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "\n", ctx);
    } else {
        emitted = mir_native_direct_call_append(
            emitted,
            "FunctionParamI32\n",
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "function_", ctx);
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_0_argument_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            argument_index,
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "_param: ", ctx);
        emitted = mir_native_direct_call_append_int(
            emitted,
            argument.parameter_index,
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "\n", ctx);
    }
    return std.Clone(ctx, emitted);
}

func mir_native_direct_call_statement_prefix(
    output: str,
    function_index: int,
    statement_index: int,
    ctx: &Arena
) str {
    mut emitted := mir_native_direct_call_append(
        output,
        "function_",
        ctx
    );
    emitted = mir_native_direct_call_append_int(
        emitted,
        function_index,
        ctx
    );
    emitted = mir_native_direct_call_append(
        emitted,
        "_block_0_statement_",
        ctx
    );
    emitted = mir_native_direct_call_append_int(
        emitted,
        statement_index,
        ctx
    );
    return mir_native_direct_call_append(emitted, "_", ctx);
}

func mir_native_direct_call_emit_graph_call_literal(
    output: str,
    function_index: int,
    statement_index: int,
    result_local: str,
    callee: str,
    value: int,
    ctx: &Arena
) str {
    mut prefix := mir_native_direct_call_statement_prefix(
        "",
        function_index,
        statement_index,
        ctx
    );
    mut emitted := mir_native_direct_call_append(
        output,
        prefix,
        ctx
    );
    emitted = mir_native_direct_call_append(
        emitted,
        "kind: LocalI32SetCall\n",
        ctx
    );
    emitted = mir_native_direct_call_append(emitted, prefix, ctx);
    emitted = mir_native_direct_call_append(emitted, "local: ", ctx);
    emitted = mir_native_direct_call_append(emitted, result_local, ctx);
    emitted = mir_native_direct_call_append(emitted, "\n", ctx);
    emitted = mir_native_direct_call_append(emitted, prefix, ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        "callee_kind: LocalFunction\n",
        ctx
    );
    emitted = mir_native_direct_call_append(emitted, prefix, ctx);
    emitted = mir_native_direct_call_append(emitted, "callee: ", ctx);
    emitted = mir_native_direct_call_append(emitted, callee, ctx);
    emitted = mir_native_direct_call_append(emitted, "\n", ctx);
    emitted = mir_native_direct_call_append(emitted, prefix, ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        "argument_count: 1\n",
        ctx
    );
    emitted = mir_native_direct_call_append(emitted, prefix, ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        "argument_0_kind: I32Literal\n",
        ctx
    );
    emitted = mir_native_direct_call_append(emitted, prefix, ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        "argument_0_value: ",
        ctx
    );
    emitted = mir_native_direct_call_append_int(emitted, value, ctx);
    return mir_native_direct_call_append(emitted, "\n", ctx);
}

func mir_native_direct_call_emit_graph_call_local(
    output: str,
    function_index: int,
    statement_index: int,
    result_local: str,
    callee: str,
    argument_local: str,
    ctx: &Arena
) str {
    mut prefix := mir_native_direct_call_statement_prefix(
        "",
        function_index,
        statement_index,
        ctx
    );
    mut emitted := mir_native_direct_call_append(
        output,
        prefix,
        ctx
    );
    emitted = mir_native_direct_call_append(
        emitted,
        "kind: LocalI32SetCall\n",
        ctx
    );
    emitted = mir_native_direct_call_append(emitted, prefix, ctx);
    emitted = mir_native_direct_call_append(emitted, "local: ", ctx);
    emitted = mir_native_direct_call_append(emitted, result_local, ctx);
    emitted = mir_native_direct_call_append(emitted, "\n", ctx);
    emitted = mir_native_direct_call_append(emitted, prefix, ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        "callee_kind: LocalFunction\n",
        ctx
    );
    emitted = mir_native_direct_call_append(emitted, prefix, ctx);
    emitted = mir_native_direct_call_append(emitted, "callee: ", ctx);
    emitted = mir_native_direct_call_append(emitted, callee, ctx);
    emitted = mir_native_direct_call_append(emitted, "\n", ctx);
    emitted = mir_native_direct_call_append(emitted, prefix, ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        "argument_count: 1\n",
        ctx
    );
    emitted = mir_native_direct_call_append(emitted, prefix, ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        "argument_0_kind: LocalI32\n",
        ctx
    );
    emitted = mir_native_direct_call_append(emitted, prefix, ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        "argument_0_local: ",
        ctx
    );
    emitted = mir_native_direct_call_append(
        emitted,
        argument_local,
        ctx
    );
    return mir_native_direct_call_append(emitted, "\n", ctx);
}

func mir_native_direct_call_emit_function(
    output: str,
    function: MirNativeDirectCallFunction[ctx],
    function_index: int,
    expected_exit: int,
    graph_profile: int,
    source_path: str,
    ctx: &Arena
) str {
    mut emitted := output;
    emitted = mir_native_direct_call_append(emitted, "function_", ctx);
    emitted = mir_native_direct_call_append_int(emitted, function_index, ctx);
    if std.str_eq(function.name, "main") == 1 {
        emitted = mir_native_direct_call_append(
            emitted,
            "_linkage: exported_entry\n",
            ctx
        );
    } else {
        emitted = mir_native_direct_call_append(
            emitted,
            "_linkage: module_local\n",
            ctx
        );
    }
    emitted = mir_native_direct_call_append(emitted, "function_", ctx);
    emitted = mir_native_direct_call_append_int(emitted, function_index, ctx);
    emitted = mir_native_direct_call_append(emitted, "_function: ", ctx);
    emitted = mir_native_direct_call_append(emitted, function.name, ctx);
    emitted = mir_native_direct_call_append(emitted, "\nfunction_", ctx);
    emitted = mir_native_direct_call_append_int(emitted, function_index, ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        "_backend_symbol: ",
        ctx
    );
    emitted = mir_native_direct_call_append(
        emitted,
        mir_native_direct_call_backend_symbol(
            function,
            graph_profile,
            ctx
        ),
        ctx
    );
    emitted = mir_native_direct_call_append(emitted, "\nfunction_", ctx);
    emitted = mir_native_direct_call_append_int(emitted, function_index, ctx);

    mut parameter_types: std.Vector[str, ctx] :=
        ctx[function.parameter_types];
    emitted = mir_native_direct_call_append(
        emitted,
        "_parameter_count: ",
        ctx
    );
    emitted = mir_native_direct_call_append_int(
        emitted,
        len(parameter_types),
        ctx
    );
    emitted = mir_native_direct_call_append(emitted, "\n", ctx);
    mut parameter_index := 0;
    while parameter_index < len(parameter_types) {
        emitted = mir_native_direct_call_append(emitted, "function_", ctx);
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_parameter_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            parameter_index,
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "_type: ", ctx);
        emitted = mir_native_direct_call_append(
            emitted,
            parameter_types[parameter_index],
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "\n", ctx);
        parameter_index = parameter_index + 1;
    }

    emitted = mir_native_direct_call_append(emitted, "function_", ctx);
    emitted = mir_native_direct_call_append_int(emitted, function_index, ctx);
    emitted = mir_native_direct_call_append(emitted, "_return_type: ", ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        function.return_type,
        ctx
    );
    emitted = mir_native_direct_call_append(
        emitted,
        "\nfunction_",
        ctx
    );
    emitted = mir_native_direct_call_append_int(emitted, function_index, ctx);
    mut first_local_name := function.sequence_first_local;
    mut second_local_name := function.sequence_second_local;
    if function.profile == 4 {
        first_local_name = function.graph_first_local;
        second_local_name = function.graph_second_local;
    }
    if function.profile == 3 || function.profile == 4 {
        emitted = mir_native_direct_call_append(
            emitted,
            "_local_count: 2\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_local_0_name: ",
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            first_local_name,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_local_0_type: int\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_local_1_name: ",
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            second_local_name,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_local_1_type: int\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
    } else {
        emitted = mir_native_direct_call_append(
            emitted,
            "_local_count: 1\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_local_0_name: return_value\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_local_0_type: ",
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            function.return_type,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
    }
    emitted = mir_native_direct_call_append(
        emitted,
        "_entry_block: entry\nfunction_",
        ctx
    );
    emitted = mir_native_direct_call_append_int(emitted, function_index, ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        "_block_count: 1\nfunction_",
        ctx
    );
    emitted = mir_native_direct_call_append_int(emitted, function_index, ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        "_block_0_label: entry\nfunction_",
        ctx
    );
    emitted = mir_native_direct_call_append_int(emitted, function_index, ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        "_block_0_parameter_count: 0\nfunction_",
        ctx
    );
    emitted = mir_native_direct_call_append_int(emitted, function_index, ctx);

    if function.profile == 0 {
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_count: 1\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_0_kind: LocalI32SetParam\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_0_local: return_value\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_0_param: ",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function.first_parameter,
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "\n", ctx);
    } else if function.profile == 1 {
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_count: 2\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_0_kind: LocalI32SetParam\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_0_local: return_value\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_0_param: ",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function.first_parameter,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_1_kind: LocalI32AddParam\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_1_local: return_value\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_1_param: ",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function.second_parameter,
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "\n", ctx);
    } else if function.profile == 3 {
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_count: 4\n",
            ctx
        );

        emitted = mir_native_direct_call_statement_prefix(
            emitted,
            function_index,
            0,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "kind: LocalI32Set\n",
            ctx
        );
        emitted = mir_native_direct_call_statement_prefix(
            emitted,
            function_index,
            0,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "local: ",
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            function.sequence_first_local,
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "\n", ctx);
        emitted = mir_native_direct_call_statement_prefix(
            emitted,
            function_index,
            0,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "value: ",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function.sequence_initial_value,
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "\n", ctx);

        emitted = mir_native_direct_call_statement_prefix(
            emitted,
            function_index,
            1,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "kind: LocalI32AddI32Literal\n",
            ctx
        );
        emitted = mir_native_direct_call_statement_prefix(
            emitted,
            function_index,
            1,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "local: ",
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            function.sequence_first_local,
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "\n", ctx);
        emitted = mir_native_direct_call_statement_prefix(
            emitted,
            function_index,
            1,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "value: ",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function.sequence_before_add,
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "\n", ctx);

        emitted = mir_native_direct_call_statement_prefix(
            emitted,
            function_index,
            2,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "kind: LocalI32SetCall\n",
            ctx
        );
        emitted = mir_native_direct_call_statement_prefix(
            emitted,
            function_index,
            2,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "local: ",
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            function.sequence_second_local,
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "\n", ctx);
        emitted = mir_native_direct_call_statement_prefix(
            emitted,
            function_index,
            2,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "callee_kind: LocalFunction\n",
            ctx
        );
        emitted = mir_native_direct_call_statement_prefix(
            emitted,
            function_index,
            2,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "callee: ",
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            function.callee,
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "\n", ctx);
        emitted = mir_native_direct_call_statement_prefix(
            emitted,
            function_index,
            2,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "argument_count: 1\n",
            ctx
        );
        emitted = mir_native_direct_call_statement_prefix(
            emitted,
            function_index,
            2,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "argument_0_kind: LocalI32\n",
            ctx
        );
        emitted = mir_native_direct_call_statement_prefix(
            emitted,
            function_index,
            2,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "argument_0_local: ",
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            function.sequence_first_local,
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "\n", ctx);

        emitted = mir_native_direct_call_statement_prefix(
            emitted,
            function_index,
            3,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "kind: LocalI32AddI32Literal\n",
            ctx
        );
        emitted = mir_native_direct_call_statement_prefix(
            emitted,
            function_index,
            3,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "local: ",
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            function.sequence_second_local,
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "\n", ctx);
        emitted = mir_native_direct_call_statement_prefix(
            emitted,
            function_index,
            3,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "value: ",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function.sequence_after_add,
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "\n", ctx);
    } else if function.profile == 4 {
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_count: 3\n",
            ctx
        );
        emitted = mir_native_direct_call_emit_graph_call_literal(
            emitted,
            function_index,
            0,
            function.graph_first_local,
            function.graph_first_callee,
            function.graph_first_argument,
            ctx
        );
        emitted = mir_native_direct_call_emit_graph_call_local(
            emitted,
            function_index,
            1,
            function.graph_second_local,
            function.graph_second_callee,
            function.graph_first_local,
            ctx
        );
        mut add_prefix := mir_native_direct_call_statement_prefix(
            "",
            function_index,
            2,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            add_prefix,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "kind: LocalI32AddI32Literal\n",
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            add_prefix,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "local: ",
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            function.graph_second_local,
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "\n", ctx);
        emitted = mir_native_direct_call_append(
            emitted,
            add_prefix,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "value: ",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function.graph_after_add,
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "\n", ctx);
    } else {
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_count: 1\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_0_kind: LocalI32SetCall\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_0_local: return_value\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_0_callee_kind: LocalFunction\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_0_callee: ",
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            function.callee,
            ctx
        );
        emitted = mir_native_direct_call_append(
            emitted,
            "\nfunction_",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            function_index,
            ctx
        );
        mut arguments: std.Vector[MirNativeDirectCallArgument[ctx], ctx] :=
            ctx[function.arguments];
        emitted = mir_native_direct_call_append(
            emitted,
            "_block_0_statement_0_argument_count: ",
            ctx
        );
        emitted = mir_native_direct_call_append_int(
            emitted,
            len(arguments),
            ctx
        );
        emitted = mir_native_direct_call_append(emitted, "\n", ctx);
        mut argument_index := 0;
        while argument_index < len(arguments) {
            emitted = mir_native_direct_call_emit_argument(
                emitted,
                function_index,
                argument_index,
                arguments[argument_index],
                ctx
            );
            argument_index = argument_index + 1;
        }
    }

    emitted = mir_native_direct_call_append(emitted, "function_", ctx);
    emitted = mir_native_direct_call_append_int(emitted, function_index, ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        "_block_0_terminator_kind: ReturnLocalI32\nfunction_",
        ctx
    );
    emitted = mir_native_direct_call_append_int(emitted, function_index, ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        "_block_0_terminator_local: ",
        ctx
    );
    if function.profile == 3 {
        emitted = mir_native_direct_call_append(
            emitted,
            function.sequence_second_local,
            ctx
        );
    } else if function.profile == 4 {
        emitted = mir_native_direct_call_append(
            emitted,
            function.graph_second_local,
            ctx
        );
    } else {
        emitted = mir_native_direct_call_append(
            emitted,
            "return_value",
            ctx
        );
    }
    emitted = mir_native_direct_call_append(
        emitted,
        "\nfunction_",
        ctx
    );
    emitted = mir_native_direct_call_append_int(emitted, function_index, ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        "_metadata_count: 1\n",
        ctx
    );
    mut metadata_prefix := mir_native_direct_call_append(
        "function_",
        std.FormatInt(function_index),
        ctx
    );
    metadata_prefix = mir_native_direct_call_append(
        metadata_prefix,
        "_metadata_0",
        ctx
    );
    emitted = mir_native_direct_call_append(
        emitted,
        metadata_prefix,
        ctx
    );
    emitted = mir_native_direct_call_append(
        emitted,
        "_kind: provenance\n",
        ctx
    );
    emitted = mir_native_direct_call_append(emitted, metadata_prefix, ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        "_attachment: function\n",
        ctx
    );
    emitted = mir_native_direct_call_append(emitted, metadata_prefix, ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        "_policy: recognized_preserved\n",
        ctx
    );
    emitted = metadata_source.mir_native_metadata_emit_contract(
        emitted,
        metadata_prefix,
        source_path,
        function.source_line,
        function.source_column,
        "function",
        "validated_preserved",
        "preserved",
        "direct_call_graph_and_scalar_abi_are_validated_before_lowering",
        ctx
    );
    emitted = mir_native_direct_call_append(emitted, metadata_prefix, ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        "_payload: kind=DirectCallGraph;contract=phase13_7;codegen=preserved\nfunction_",
        ctx
    );
    emitted = mir_native_direct_call_append_int(emitted, function_index, ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        "_expected_exit: ",
        ctx
    );
    emitted = mir_native_direct_call_append_int(
        emitted,
        expected_exit,
        ctx
    );
    emitted = mir_native_direct_call_append(emitted, "\n", ctx);
    return std.Clone(ctx, emitted);
}

func mir_native_direct_call_emit_bundle(model: MirNativeDirectCallModel[ctx], ctx: &Arena) mir.MirProgramBundle[ctx] {
    mut functions: std.Vector[MirNativeDirectCallFunction[ctx], ctx] :=
        ctx[model.functions];
    mut module_name := std.Clone(ctx, "phase11_direct_call_abi");
    mut object_name := std.Clone(
        ctx,
        "phase11_direct_call_abi_module.o"
    );
    if model.graph_profile == 1 {
        module_name = std.Clone(ctx, "phase13_direct_call_graph");
        object_name = std.Clone(
            ctx,
            "phase13_direct_call_graph_module.o"
        );
    }
    mut canonical :=
        "format: gust.compiler_mir_ingestion.v2\nmodule: ";
    canonical = mir_native_direct_call_append(
        canonical,
        module_name,
        ctx
    );
    canonical = mir_native_direct_call_append(
        canonical,
        "\nimport_count: 0\nfunction_count: ",
        ctx
    );
    canonical = mir_native_direct_call_append_int(
        canonical,
        len(functions),
        ctx
    );
    canonical = mir_native_direct_call_append(canonical, "\n", ctx);

    mut function_index := 0;
    while function_index < len(functions) {
        mut expected_exit := 0;
        if function_index == model.entry_index {
            expected_exit = model.expected_exit;
        }
        canonical = mir_native_direct_call_emit_function(
            canonical,
            functions[function_index],
            function_index,
            expected_exit,
            model.graph_profile,
            model.source_path,
            ctx
        );
        function_index = function_index + 1;
    }

    mut bundle := mir.mir_make_program_bundle("main", ctx);
    mut module := mir.mir_make_program_bundle_module(
        model.source_path,
        "",
        object_name,
        "gust.compiler_mir_ingestion.v2",
        canonical,
        0,
        len(functions),
        0,
        ctx
    );
    function_index = 0;
    while function_index < len(functions) {
        mut function := functions[function_index];
        mut linkage := 1;
        if std.str_eq(function.name, "main") == 1 {
            linkage = 0;
        }
        module = mir.mir_program_bundle_module_with_symbol(
            module,
            mir.mir_make_program_bundle_symbol(
                function.name,
                mir_native_direct_call_backend_symbol(
                    function,
                    model.graph_profile,
                    ctx
                ),
                mir_native_direct_call_signature(function, ctx),
                linkage,
                ctx
            ),
            ctx
        );
        function_index = function_index + 1;
    }
    return mir.mir_program_bundle_with_module(bundle, module, ctx);
}

func mir_native_direct_call_source_lower(programs: std.Vector[ast.Program[ctx], ctx], module_paths: std.Vector[str, ctx], module_prefixes: std.Vector[str, ctx], ctx: &Arena) MirNativeDirectCallSourceResult[ctx] {
    mut result := mir_native_direct_call_empty_result(ctx);
    mut model := mir_native_direct_call_analyze(
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
    result.bundle = mir_native_direct_call_emit_bundle(model, ctx);
    return result;
}
