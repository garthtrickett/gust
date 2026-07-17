import "ast.gst" as ast;
import "mir.gst" as mir;

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
    parameter_names: Index[std.Vector[str, ctx], ctx],
    parameter_types: Index[std.Vector[str, ctx], ctx],
    return_type: str,
    profile: int,
    first_parameter: int,
    second_parameter: int,
    callee: str,
    arguments: Index[std.Vector[MirNativeDirectCallArgument[ctx], ctx], ctx]
}

type MirNativeDirectCallModel[ctx] struct {
    represented: int,
    invalid: int,
    diagnostic: str,
    source_path: str,
    functions: Index[std.Vector[MirNativeDirectCallFunction[ctx], ctx], ctx],
    entry_index: int,
    expected_exit: int
}

type MirNativeDirectCallEvaluation struct {
    valid: int,
    value: int
}

type MirNativeDirectCallSourceResult[ctx] struct {
    represented: int,
    invalid: int,
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
    model.diagnostic = std.Clone(ctx, "");
    model.source_path = std.Clone(ctx, "");
    model.functions = mir_native_direct_call_empty_function_vector(ctx);
    model.entry_index = -1;
    model.expected_exit = 0;
    return model;
}

func mir_native_direct_call_empty_result(ctx: &Arena) MirNativeDirectCallSourceResult[ctx] {
    mut result: MirNativeDirectCallSourceResult[ctx];
    result.represented = 0;
    result.invalid = 0;
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
    return -1;
}

func mir_native_direct_call_function_index(functions: std.Vector[MirNativeDirectCallFunction[ctx], ctx], name: str, ctx: &Arena) int {
    mut index := 0;
    while index < len(functions) {
        if std.str_eq(functions[index].name, name) == 1 {
            return index;
        }
        index = index + 1;
    }
    return -1;
}

func mir_native_direct_call_analyze_argument(expression: ast.Expression[ctx], parameter_names: std.Vector[str, ctx], parameter_types: std.Vector[str, ctx], ctx: &Arena) MirNativeDirectCallArgument[ctx] {
    mut argument: MirNativeDirectCallArgument[ctx];
    argument.kind = -1;
    argument.value = 0;
    argument.parameter_index = -1;
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
    function.parameter_names = mir_native_direct_call_empty_string_vector(ctx);
    function.parameter_types = mir_native_direct_call_empty_string_vector(ctx);
    function.return_type = std.Clone(ctx, "");
    function.profile = -1;
    function.first_parameter = -1;
    function.second_parameter = -1;
    function.callee = std.Clone(ctx, "");
    function.arguments = mir_native_direct_call_empty_argument_vector(ctx);

    unsafe {
        if statement.tag != 3 || statement.FunctionDecl.is_extern == 1 {
            return function;
        }
        function.name = std.Clone(ctx, statement.FunctionDecl.name);

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
                    function.profile = -1;
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
        if caller.profile == 2 {
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
        if function.profile == 2 {
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
            indegree.Set(callee_index, indegree[callee_index] + 1);
        }
        index = index + 1;
    }

    mut visited := 0;
    while visited < len(functions) {
        mut selected := -1;
        index = 0;
        while index < len(functions) {
            if removed[index] == 0 && indegree[index] == 0 {
                selected = index;
                break;
            }
            index = index + 1;
        }
        if selected < 0 {
            return mir_native_direct_call_invalid(
                model,
                "Native backend canonical MIR verification failed: direct-call graph must be acyclic",
                ctx
            );
        }
        removed.Set(selected, 1);
        visited = visited + 1;
        mut selected_function := functions[selected];
        if selected_function.profile == 2 {
            mut selected_callee := mir_native_direct_call_function_index(
                functions,
                selected_function.callee,
                ctx
            );
            indegree.Set(
                selected_callee,
                indegree[selected_callee] - 1
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
    mut entry_index := -1;
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
        if function.profile == 2 {
            has_call = 1;
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

func mir_native_direct_call_emit_function(output: str, function: MirNativeDirectCallFunction[ctx], function_index: int, expected_exit: int, ctx: &Arena) str {
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
    emitted = mir_native_direct_call_append(emitted, function.name, ctx);
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
    emitted = mir_native_direct_call_append(
        emitted,
        "_local_count: 1\nfunction_",
        ctx
    );
    emitted = mir_native_direct_call_append_int(emitted, function_index, ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        "_local_0_name: return_value\nfunction_",
        ctx
    );
    emitted = mir_native_direct_call_append_int(emitted, function_index, ctx);
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
    emitted = mir_native_direct_call_append_int(emitted, function_index, ctx);
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
        "_block_0_terminator_local: return_value\nfunction_",
        ctx
    );
    emitted = mir_native_direct_call_append_int(emitted, function_index, ctx);
    emitted = mir_native_direct_call_append(
        emitted,
        "_metadata_count: 0\nfunction_",
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
    mut canonical :=
        "format: gust.compiler_mir_ingestion.v2\nmodule: phase11_direct_call_abi\nimport_count: 0\nfunction_count: ";
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
            ctx
        );
        function_index = function_index + 1;
    }

    mut bundle := mir.mir_make_program_bundle("main", ctx);
    mut module := mir.mir_make_program_bundle_module(
        model.source_path,
        "",
        "phase11_direct_call_abi_module.o",
        "gust.compiler_mir_ingestion.v2",
        canonical,
        0,
        0,
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
                function.name,
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