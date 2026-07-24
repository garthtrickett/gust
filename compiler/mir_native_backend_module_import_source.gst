import "ast.gst" as ast;
import "mir.gst" as mir;

// Compiler-owned module, import, and runtime-boundary lowering.
//
// This route consumes the resolver's topological module order and prefixes after
// normal parsing and typechecking. It preserves fully qualified function
// identities, separates local, bundle, and approved host imports, and emits no
// source-controlled linker flags, libraries, or environment overrides.
type MirNativeModuleImportArgument[ctx] struct {
    kind: int,
    value: int,
    parameter_index: int,
    local_name: str,
    value_type: str
}

type MirNativeModuleImportHost[ctx] struct {
    module_index: int,
    name: str,
    link_name: str,
    parameter_types: Index[std.Vector[str, ctx], ctx],
    return_type: str,
    boundary_kind: int
}

type MirNativeModuleImportFunction[ctx] struct {
    module_index: int,
    module_path: str,
    module_prefix: str,
    source_name: str,
    qualified_name: str,
    parameter_names: Index[std.Vector[str, ctx], ctx],
    parameter_types: Index[std.Vector[str, ctx], ctx],
    return_type: str,
    profile: int,
    first_parameter: int,
    second_parameter: int,
    callee_kind: int,
    callee_name: str,
    callee_link_name: str,
    boundary_kind: int,
    arguments: Index[std.Vector[MirNativeModuleImportArgument[ctx], ctx], ctx],
    second_arguments: Index[std.Vector[MirNativeModuleImportArgument[ctx], ctx], ctx],
    result_local_name: str,
    expression_add_value: int,
    branch_then_value: int,
    branch_else_value: int
}

type MirNativeModuleImportModel[ctx] struct {
    represented: int,
    invalid: int,
    diagnostic: str,
    module_paths: Index[std.Vector[str, ctx], ctx],
    module_prefixes: Index[std.Vector[str, ctx], ctx],
    functions: Index[std.Vector[MirNativeModuleImportFunction[ctx], ctx], ctx],
    hosts: Index[std.Vector[MirNativeModuleImportHost[ctx], ctx], ctx],
    entry_index: int,
    expected_exit: int
}

type MirNativeModuleImportHostCall[ctx] struct {
    valid: int,
    callee_name: str,
    callee_link_name: str,
    boundary_kind: int,
    arguments: Index[std.Vector[MirNativeModuleImportArgument[ctx], ctx], ctx]
}

type MirNativeModuleImportEvaluation struct {
    valid: int,
    value: int
}

type MirNativeModuleImportSourceResult[ctx] struct {
    represented: int,
    invalid: int,
    diagnostic: str,
    bundle: mir.MirProgramBundle[ctx]
}

func mir_native_module_import_append(output: str, value: str, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat(output, value));
}

func mir_native_module_import_append_int(output: str, value: int, ctx: &Arena) str {
    mut formatted := std.FormatInt(value);
    return std.Clone(ctx, std.Concat(output, formatted));
}

func mir_native_module_import_empty_argument_vector(ctx: &Arena) Index[std.Vector[MirNativeModuleImportArgument[ctx], ctx], ctx] {
    mut arguments: std.Vector[MirNativeModuleImportArgument[ctx], ctx] :=
        std.VectorNew(ctx);
    mut arguments_index:
        Index[std.Vector[MirNativeModuleImportArgument[ctx], ctx], ctx] :=
            os.ArenaAlloc(ctx);
    ctx.Set(arguments_index, arguments);
    return arguments_index;
}

func mir_native_module_import_empty_string_vector(ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut values: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut values_index: Index[std.Vector[str, ctx], ctx] :=
        os.ArenaAlloc(ctx);
    ctx.Set(values_index, values);
    return values_index;
}

func mir_native_module_import_empty_function_vector(ctx: &Arena) Index[std.Vector[MirNativeModuleImportFunction[ctx], ctx], ctx] {
    mut functions: std.Vector[MirNativeModuleImportFunction[ctx], ctx] :=
        std.VectorNew(ctx);
    mut functions_index:
        Index[std.Vector[MirNativeModuleImportFunction[ctx], ctx], ctx] :=
            os.ArenaAlloc(ctx);
    ctx.Set(functions_index, functions);
    return functions_index;
}

func mir_native_module_import_empty_host_vector(ctx: &Arena) Index[std.Vector[MirNativeModuleImportHost[ctx], ctx], ctx] {
    mut hosts: std.Vector[MirNativeModuleImportHost[ctx], ctx] :=
        std.VectorNew(ctx);
    mut hosts_index:
        Index[std.Vector[MirNativeModuleImportHost[ctx], ctx], ctx] :=
            os.ArenaAlloc(ctx);
    ctx.Set(hosts_index, hosts);
    return hosts_index;
}

func mir_native_module_import_clone_strings(values: std.Vector[str, ctx], ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut cloned: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut index := 0;
    while index < len(values) {
        cloned.Push(std.Clone(ctx, values[index]));
        index = index + 1;
    }
    mut cloned_index: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(cloned_index, cloned);
    return cloned_index;
}

func mir_native_module_import_empty_model(ctx: &Arena) MirNativeModuleImportModel[ctx] {
    mut model: MirNativeModuleImportModel[ctx];
    model.represented = 0;
    model.invalid = 0;
    model.diagnostic = std.Clone(ctx, "");
    model.module_paths = mir_native_module_import_empty_string_vector(ctx);
    model.module_prefixes = mir_native_module_import_empty_string_vector(ctx);
    model.functions = mir_native_module_import_empty_function_vector(ctx);
    model.hosts = mir_native_module_import_empty_host_vector(ctx);
    model.entry_index = 0 - 1;
    model.expected_exit = 0;
    return model;
}

func mir_native_module_import_empty_result(ctx: &Arena) MirNativeModuleImportSourceResult[ctx] {
    mut result: MirNativeModuleImportSourceResult[ctx];
    result.represented = 0;
    result.invalid = 0;
    result.diagnostic = std.Clone(ctx, "");
    result.bundle = mir.mir_make_program_bundle("invalid", ctx);
    return result;
}

func mir_native_module_import_invalid(model: MirNativeModuleImportModel[ctx], diagnostic: str, ctx: &Arena) MirNativeModuleImportModel[ctx] {
    mut invalid := model;
    invalid.represented = 1;
    invalid.invalid = 1;
    invalid.diagnostic = std.Clone(ctx, diagnostic);
    return invalid;
}

func mir_native_module_import_type_name(value_type: ast.Type[ctx], ctx: &Arena) str {
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

func mir_native_module_import_file_stem(path: str, ctx: &Arena) str {
    mut last_slash := 0 - 1;
    mut dot_index := 0 - 1;
    mut index := 0;
    while index < len(path) {
        mut value := std.str_byte_at(path, index);
        if value == 47 || value == 92 {
            last_slash = index;
        }
        if value == 46 {
            dot_index = index;
        }
        index = index + 1;
    }
    mut start := last_slash + 1;
    mut end := len(path);
    if dot_index > start {
        end = dot_index;
    }
    return std.Clone(ctx, std.str_slice(path, start, end));
}

func mir_native_module_import_module_name(path: str, ctx: &Arena) str {
    return mir_native_module_import_file_stem(path, ctx);
}

func mir_native_module_import_object_name(path: str, ctx: &Arena) str {
    mut name := mir_native_module_import_file_stem(path, ctx);
    name = mir_native_module_import_append(name, "_phase11_module_import.o", ctx);
    return std.Clone(ctx, name);
}

func mir_native_module_import_qualified(prefix: str, name: str, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat(prefix, name));
}

func mir_native_module_import_parameter_index(names: std.Vector[str, ctx], name: str, ctx: &Arena) int {
    mut index := 0;
    while index < len(names) {
        if std.str_eq(names[index], name) == 1 {
            return index;
        }
        index = index + 1;
    }
    return 0 - 1;
}

func mir_native_module_import_function_index(functions: std.Vector[MirNativeModuleImportFunction[ctx], ctx], name: str, ctx: &Arena) int {
    mut index := 0;
    while index < len(functions) {
        if std.str_eq(functions[index].qualified_name, name) == 1 {
            return index;
        }
        index = index + 1;
    }
    return 0 - 1;
}

func mir_native_module_import_host_index(hosts: std.Vector[MirNativeModuleImportHost[ctx], ctx], module_index: int, name: str, ctx: &Arena) int {
    mut index := 0;
    while index < len(hosts) {
        if hosts[index].module_index == module_index &&
           std.str_eq(hosts[index].name, name) == 1
        {
            return index;
        }
        index = index + 1;
    }
    return 0 - 1;
}

func mir_native_module_import_host_boundary(name: str, link_name: str, parameter_types: std.Vector[str, ctx], return_type: str, ctx: &Arena) int {
    if std.str_eq(return_type, "int") == 0 {
        return 0;
    }
    if len(parameter_types) == 1 &&
       std.str_eq(parameter_types[0], "int") == 1
    {
        if std.str_eq(name, "abs") == 1 &&
           std.str_eq(link_name, "abs") == 1
        {
            return 1;
        }
        if std.str_eq(name, "toupper") == 1 &&
           std.str_eq(link_name, "toupper") == 1
        {
            return 2;
        }
        if std.str_eq(name, "tiny_host_add_one_i32") == 1 &&
           std.str_eq(link_name, "tiny_host_add_one_i32") == 1
        {
            return 2;
        }
        if std.str_eq(name, "tiny_host_is_positive_i32") == 1 &&
           std.str_eq(link_name, "tiny_host_is_positive_i32") == 1
        {
            return 2;
        }
    }
    if len(parameter_types) == 2 &&
       std.str_eq(parameter_types[0], "int") == 1 &&
       std.str_eq(parameter_types[1], "int") == 1 &&
       std.str_eq(name, "tiny_host_add_i32") == 1 &&
       std.str_eq(link_name, "tiny_host_add_i32") == 1
    {
        return 2;
    }
    return 0;
}

func mir_native_module_import_signature_types(parameter_types: std.Vector[str, ctx], return_type: str, ctx: &Arena) str {
    mut signature := std.Clone(ctx, "(");
    mut index := 0;
    while index < len(parameter_types) {
        if index > 0 {
            signature = mir_native_module_import_append(signature, ",", ctx);
        }
        signature = mir_native_module_import_append(
            signature,
            parameter_types[index],
            ctx
        );
        index = index + 1;
    }
    signature = mir_native_module_import_append(signature, ")->", ctx);
    signature = mir_native_module_import_append(signature, return_type, ctx);
    return std.Clone(ctx, signature);
}

func mir_native_module_import_signature(function: MirNativeModuleImportFunction[ctx], ctx: &Arena) str {
    mut parameter_types: std.Vector[str, ctx] := ctx[function.parameter_types];
    mut signature := mir_native_module_import_signature_types(
        parameter_types,
        function.return_type,
        ctx
    );
    return std.Clone(ctx, signature);
}

func mir_native_module_import_host_signature(host: MirNativeModuleImportHost[ctx], ctx: &Arena) str {
    mut parameter_types: std.Vector[str, ctx] := ctx[host.parameter_types];
    mut signature := mir_native_module_import_signature_types(
        parameter_types,
        host.return_type,
        ctx
    );
    return std.Clone(ctx, signature);
}

func mir_native_module_import_analyze_argument(expression: ast.Expression[ctx], parameter_names: std.Vector[str, ctx], parameter_types: std.Vector[str, ctx], allowed_local: str, ctx: &Arena) MirNativeModuleImportArgument[ctx] {
    mut argument: MirNativeModuleImportArgument[ctx];
    argument.kind = 0 - 1;
    argument.value = 0;
    argument.parameter_index = 0 - 1;
    argument.local_name = std.Clone(ctx, "");
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
            mut parameter_index := mir_native_module_import_parameter_index(
                parameter_names,
                expression.Identifier.name,
                ctx
            );
            if parameter_index >= 0 {
                argument.kind = 2;
                argument.parameter_index = parameter_index;
                argument.value_type =
                    std.Clone(ctx, parameter_types[parameter_index]);
                return argument;
            }
            if len(allowed_local) > 0 &&
               std.str_eq(expression.Identifier.name, allowed_local) == 1
            {
                argument.kind = 3;
                argument.local_name = std.Clone(ctx, allowed_local);
                argument.value_type = std.Clone(ctx, "int");
                return argument;
            }
            return argument;
        }
    }
    return argument;
}

func mir_native_module_import_analyze_host_call(expression: ast.Expression[ctx], function: MirNativeModuleImportFunction[ctx], hosts: std.Vector[MirNativeModuleImportHost[ctx], ctx], allowed_local: str, ctx: &Arena) MirNativeModuleImportHostCall[ctx] {
    mut call: MirNativeModuleImportHostCall[ctx];
    call.valid = 0;
    call.callee_name = std.Clone(ctx, "");
    call.callee_link_name = std.Clone(ctx, "");
    call.boundary_kind = 0;
    call.arguments = mir_native_module_import_empty_argument_vector(ctx);

    unsafe {
        if expression.tag != 12 {
            return call;
        }
        mut callee := ctx[expression.Call.function];
        if callee.tag != 0 {
            return call;
        }
        mut host_index := mir_native_module_import_host_index(
            hosts,
            function.module_index,
            callee.Identifier.name,
            ctx
        );
        if host_index < 0 {
            return call;
        }
        mut host := hosts[host_index];
        if host.boundary_kind == 0 {
            return call;
        }

        mut parameter_names: std.Vector[str, ctx] :=
            ctx[function.parameter_names];
        mut parameter_types: std.Vector[str, ctx] :=
            ctx[function.parameter_types];
        mut arguments: std.Vector[MirNativeModuleImportArgument[ctx], ctx] :=
            std.VectorNew(ctx);
        mut source_arguments: std.Vector[ast.Expression[ctx], ctx] :=
            ctx[expression.Call.arguments];
        mut argument_index := 0;
        while argument_index < len(source_arguments) {
            mut argument := mir_native_module_import_analyze_argument(
                source_arguments[argument_index],
                parameter_names,
                parameter_types,
                allowed_local,
                ctx
            );
            if argument.kind < 0 {
                return call;
            }
            arguments.Push(argument);
            argument_index = argument_index + 1;
        }
        ctx.Set(call.arguments, arguments);
        call.valid = 1;
        call.callee_name = std.Clone(ctx, host.name);
        call.callee_link_name = std.Clone(ctx, host.link_name);
        call.boundary_kind = host.boundary_kind;
    }
    return call;
}

func mir_native_module_import_make_function_signature(statement: ast.Statement[ctx], module_index: int, module_path: str, module_prefix: str, ctx: &Arena) MirNativeModuleImportFunction[ctx] {
    mut function: MirNativeModuleImportFunction[ctx];
    function.module_index = module_index;
    function.module_path = std.Clone(ctx, module_path);
    function.module_prefix = std.Clone(ctx, module_prefix);
    function.source_name = std.Clone(ctx, "");
    function.qualified_name = std.Clone(ctx, "");
    function.parameter_names = mir_native_module_import_empty_string_vector(ctx);
    function.parameter_types = mir_native_module_import_empty_string_vector(ctx);
    function.return_type = std.Clone(ctx, "");
    function.profile = 0 - 1;
    function.first_parameter = 0 - 1;
    function.second_parameter = 0 - 1;
    function.callee_kind = 0 - 1;
    function.callee_name = std.Clone(ctx, "");
    function.callee_link_name = std.Clone(ctx, "");
    function.boundary_kind = 0;
    function.arguments = mir_native_module_import_empty_argument_vector(ctx);
    function.second_arguments = mir_native_module_import_empty_argument_vector(ctx);
    function.result_local_name = std.Clone(ctx, "return_value");
    function.expression_add_value = 0;
    function.branch_then_value = 0;
    function.branch_else_value = 0;

    unsafe {
        if statement.tag != 3 || statement.FunctionDecl.is_extern == 1 {
            return function;
        }
        function.source_name = std.Clone(ctx, statement.FunctionDecl.name);
        function.qualified_name = mir_native_module_import_qualified(
            module_prefix,
            statement.FunctionDecl.name,
            ctx
        );

        mut parameter_names: std.Vector[str, ctx] := std.VectorNew(ctx);
        mut parameter_types: std.Vector[str, ctx] := std.VectorNew(ctx);
        mut parameters: std.Vector[ast.Parameter[ctx], ctx] :=
            ctx[statement.FunctionDecl.params];
        mut parameter_index := 0;
        while parameter_index < len(parameters) {
            mut parameter := parameters[parameter_index];
            mut parameter_type := mir_native_module_import_type_name(
                parameter.param_type,
                ctx
            );
            if len(parameter_type) == 0 {
                function.source_name = std.Clone(ctx, "");
                function.qualified_name = std.Clone(ctx, "");
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
            mir_native_module_import_type_name(return_type_ast, ctx);
        if len(function.return_type) == 0 {
            function.source_name = std.Clone(ctx, "");
            function.qualified_name = std.Clone(ctx, "");
        }
    }
    return function;
}

func mir_native_module_import_make_host(statement: ast.Statement[ctx], module_index: int, ctx: &Arena) MirNativeModuleImportHost[ctx] {
    mut host: MirNativeModuleImportHost[ctx];
    host.module_index = module_index;
    host.name = std.Clone(ctx, "");
    host.link_name = std.Clone(ctx, "");
    host.parameter_types = mir_native_module_import_empty_string_vector(ctx);
    host.return_type = std.Clone(ctx, "");
    host.boundary_kind = 0;

    unsafe {
        if statement.tag != 3 || statement.FunctionDecl.is_extern == 0 {
            return host;
        }
        if std.str_eq(statement.FunctionDecl.extern_abi, "C") == 0 ||
           statement.FunctionDecl.requires_layout_metadata == 1 ||
           statement.FunctionDecl.requires_sandbox_arena == 1
        {
            return host;
        }
        host.name = std.Clone(ctx, statement.FunctionDecl.name);
        host.link_name = std.Clone(
            ctx,
            statement.FunctionDecl.extern_symbol_name
        );
        if len(host.link_name) == 0 {
            host.link_name = std.Clone(ctx, host.name);
        }

        mut parameter_types: std.Vector[str, ctx] := std.VectorNew(ctx);
        mut parameters: std.Vector[ast.Parameter[ctx], ctx] :=
            ctx[statement.FunctionDecl.params];
        mut parameter_index := 0;
        while parameter_index < len(parameters) {
            mut parameter_type := mir_native_module_import_type_name(
                parameters[parameter_index].param_type,
                ctx
            );
            if len(parameter_type) == 0 {
                host.name = std.Clone(ctx, "");
                return host;
            }
            parameter_types.Push(parameter_type);
            parameter_index = parameter_index + 1;
        }
        ctx.Set(host.parameter_types, parameter_types);
        mut return_type_ast := ctx[statement.FunctionDecl.return_type];
        host.return_type =
            mir_native_module_import_type_name(return_type_ast, ctx);
        if len(host.return_type) == 0 {
            host.name = std.Clone(ctx, "");
            return host;
        }
        host.boundary_kind = mir_native_module_import_host_boundary(
            host.name,
            host.link_name,
            parameter_types,
            host.return_type,
            ctx
        );
    }
    return host;
}

func mir_native_module_import_alias_prefix(top_level: std.Vector[ast.Statement[ctx], ctx], alias: str, module_prefixes: std.Vector[str, ctx], ctx: &Arena) str {
    mut statement_index := 0;
    while statement_index < len(top_level) {
        mut statement := top_level[statement_index];
        unsafe {
            if statement.tag == 0 &&
               std.str_eq(statement.Import.alias, alias) == 1
            {
                mut stem := mir_native_module_import_file_stem(
                    statement.Import.path,
                    ctx
                );
                mut expected_prefix := mir_native_module_import_append(
                    stem,
                    "__",
                    ctx
                );
                mut module_index := 0;
                while module_index < len(module_prefixes) {
                    if std.str_eq(
                        module_prefixes[module_index],
                        expected_prefix
                    ) == 1 {
                        return std.Clone(ctx, expected_prefix);
                    }
                    module_index = module_index + 1;
                }
                return std.Clone(ctx, "");
            }
        }
        statement_index = statement_index + 1;
    }
    return std.Clone(ctx, "");
}

func mir_native_module_import_analyze_host_composition(function: MirNativeModuleImportFunction[ctx], statements: std.Vector[ast.Statement[ctx], ctx], hosts: std.Vector[MirNativeModuleImportHost[ctx], ctx], ctx: &Arena) MirNativeModuleImportFunction[ctx] {
    mut analyzed := function;
    if len(statements) != 3 {
        return analyzed;
    }
    unsafe {
        if statements[0].tag != 4 ||
           statements[1].tag != 5 ||
           statements[2].tag != 12
        {
            return analyzed;
        }
        mut local_name := statements[0].VarDecl.name;
        mut assignment_left := ctx[statements[1].Assignment.left];
        if assignment_left.tag != 0 ||
           std.str_eq(assignment_left.Identifier.name, local_name) == 0
        {
            return analyzed;
        }

        mut first_expression := ctx[statements[0].VarDecl.value];
        mut first_call := mir_native_module_import_analyze_host_call(
            first_expression,
            function,
            hosts,
            "",
            ctx
        );
        if first_call.valid == 0 {
            return analyzed;
        }
        mut second_expression := ctx[statements[1].Assignment.value];
        mut second_call := mir_native_module_import_analyze_host_call(
            second_expression,
            function,
            hosts,
            local_name,
            ctx
        );
        if second_call.valid == 0 ||
           std.str_eq(first_call.callee_name, second_call.callee_name) == 0 ||
           std.str_eq(
               first_call.callee_link_name,
               second_call.callee_link_name
           ) == 0 ||
           first_call.boundary_kind != second_call.boundary_kind
        {
            return analyzed;
        }

        mut return_expression := ctx[statements[2].Return.expr];
        mut add_value := 0;
        if return_expression.tag == 0 {
            if std.str_eq(return_expression.Identifier.name, local_name) == 0 {
                return analyzed;
            }
        } else if return_expression.tag == 10 &&
                  std.str_eq(return_expression.Binary.op, "+") == 1
        {
            mut left := ctx[return_expression.Binary.left];
            mut right := ctx[return_expression.Binary.right];
            if left.tag == 0 && right.tag == 1 &&
               std.str_eq(left.Identifier.name, local_name) == 1
            {
                add_value = right.Integer.val;
            } else if left.tag == 1 && right.tag == 0 &&
                      std.str_eq(right.Identifier.name, local_name) == 1
            {
                add_value = left.Integer.val;
            } else {
                return analyzed;
            }
        } else {
            return analyzed;
        }

        analyzed.profile = 3;
        analyzed.callee_kind = 2;
        analyzed.callee_name = std.Clone(ctx, first_call.callee_name);
        analyzed.callee_link_name =
            std.Clone(ctx, first_call.callee_link_name);
        analyzed.boundary_kind = first_call.boundary_kind;
        analyzed.arguments = first_call.arguments;
        analyzed.second_arguments = second_call.arguments;
        analyzed.result_local_name = std.Clone(ctx, local_name);
        analyzed.expression_add_value = add_value;
    }
    return analyzed;
}

func mir_native_module_import_analyze_host_predicate_branch(function: MirNativeModuleImportFunction[ctx], statements: std.Vector[ast.Statement[ctx], ctx], hosts: std.Vector[MirNativeModuleImportHost[ctx], ctx], ctx: &Arena) MirNativeModuleImportFunction[ctx] {
    mut analyzed := function;
    if len(statements) != 3 {
        return analyzed;
    }
    unsafe {
        if statements[0].tag != 4 ||
           statements[1].tag != 7 ||
           statements[2].tag != 12
        {
            return analyzed;
        }
        mut local_name := statements[0].VarDecl.name;
        mut call_expression := ctx[statements[0].VarDecl.value];
        mut call := mir_native_module_import_analyze_host_call(
            call_expression,
            function,
            hosts,
            "",
            ctx
        );
        if call.valid == 0 ||
           std.str_eq(
               call.callee_link_name,
               "tiny_host_is_positive_i32"
           ) == 0
        {
            return analyzed;
        }

        mut condition := ctx[statements[1].If.condition];
        if condition.tag == 0 {
            if std.str_eq(condition.Identifier.name, local_name) == 0 {
                return analyzed;
            }
        } else if condition.tag == 10 &&
                  std.str_eq(condition.Binary.op, ">") == 1
        {
            mut left := ctx[condition.Binary.left];
            mut right := ctx[condition.Binary.right];
            if left.tag != 0 || right.tag != 1 || right.Integer.val != 0 ||
               std.str_eq(left.Identifier.name, local_name) == 0
            {
                return analyzed;
            }
        } else {
            return analyzed;
        }

        mut consequence := ctx[statements[1].If.consequence];
        mut consequence_statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[consequence.statements];
        if len(consequence_statements) != 1 ||
           consequence_statements[0].tag != 12
        {
            return analyzed;
        }
        mut then_expression := ctx[consequence_statements[0].Return.expr];
        mut else_expression := ctx[statements[2].Return.expr];
        if then_expression.tag != 1 || else_expression.tag != 1 {
            return analyzed;
        }

        mut alternative := ctx[statements[1].If.alternative];
        mut alternative_statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[alternative.statements];
        if len(alternative_statements) != 0 {
            return analyzed;
        }

        analyzed.profile = 4;
        analyzed.callee_kind = 2;
        analyzed.callee_name = std.Clone(ctx, call.callee_name);
        analyzed.callee_link_name = std.Clone(ctx, call.callee_link_name);
        analyzed.boundary_kind = call.boundary_kind;
        analyzed.arguments = call.arguments;
        analyzed.result_local_name = std.Clone(ctx, local_name);
        analyzed.branch_then_value = then_expression.Integer.val;
        analyzed.branch_else_value = else_expression.Integer.val;
    }
    return analyzed;
}

func mir_native_module_import_analyze_function_body(function: MirNativeModuleImportFunction[ctx], statement: ast.Statement[ctx], top_level: std.Vector[ast.Statement[ctx], ctx], module_prefixes: std.Vector[str, ctx], functions: std.Vector[MirNativeModuleImportFunction[ctx], ctx], hosts: std.Vector[MirNativeModuleImportHost[ctx], ctx], ctx: &Arena) MirNativeModuleImportFunction[ctx] {
    mut analyzed := function;
    mut parameter_names: std.Vector[str, ctx] := ctx[function.parameter_names];
    mut parameter_types: std.Vector[str, ctx] := ctx[function.parameter_types];

    unsafe {
        mut body := ctx[statement.FunctionDecl.body];
        mut statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[body.statements];
        if len(statements) == 1 && statements[0].tag == 10 {
            mut unsafe_body := ctx[statements[0].UnsafeBlock.body];
            mut unsafe_statements: std.Vector[ast.Statement[ctx], ctx] :=
                ctx[unsafe_body.statements];
            mut composition :=
                mir_native_module_import_analyze_host_composition(
                    function,
                    unsafe_statements,
                    hosts,
                    ctx
                );
            if composition.profile == 3 {
                return composition;
            }
            mut predicate_branch :=
                mir_native_module_import_analyze_host_predicate_branch(
                    function,
                    unsafe_statements,
                    hosts,
                    ctx
                );
            if predicate_branch.profile == 4 {
                return predicate_branch;
            }
        }
        if len(statements) != 1 {
            return analyzed;
        }

        mut return_statement := statements[0];
        mut is_unsafe_body := 0;
        if return_statement.tag == 10 {
            mut unsafe_body := ctx[return_statement.UnsafeBlock.body];
            mut unsafe_statements: std.Vector[ast.Statement[ctx], ctx] :=
                ctx[unsafe_body.statements];
            if len(unsafe_statements) != 1 ||
               unsafe_statements[0].tag != 12
            {
                return analyzed;
            }
            return_statement = unsafe_statements[0];
            is_unsafe_body = 1;
        }
        if return_statement.tag != 12 {
            return analyzed;
        }
        mut expression := ctx[return_statement.Return.expr];

        if expression.tag == 0 {
            mut return_parameter := mir_native_module_import_parameter_index(
                parameter_names,
                expression.Identifier.name,
                ctx
            );
            if return_parameter < 0 ||
               std.str_eq(
                   parameter_types[return_parameter],
                   function.return_type
               ) == 0 ||
               is_unsafe_body == 1
            {
                return analyzed;
            }
            analyzed.profile = 0;
            analyzed.first_parameter = return_parameter;
            return analyzed;
        }

        if expression.tag == 10 &&
           std.str_eq(expression.Binary.op, "+") == 1 &&
           std.str_eq(function.return_type, "int") == 1 &&
           is_unsafe_body == 0
        {
            mut left := ctx[expression.Binary.left];
            mut right := ctx[expression.Binary.right];
            if left.tag != 0 || right.tag != 0 {
                return analyzed;
            }
            mut left_parameter := mir_native_module_import_parameter_index(
                parameter_names,
                left.Identifier.name,
                ctx
            );
            mut right_parameter := mir_native_module_import_parameter_index(
                parameter_names,
                right.Identifier.name,
                ctx
            );
            if left_parameter < 0 || right_parameter < 0 ||
               std.str_eq(parameter_types[left_parameter], "int") == 0 ||
               std.str_eq(parameter_types[right_parameter], "int") == 0
            {
                return analyzed;
            }
            analyzed.profile = 1;
            analyzed.first_parameter = left_parameter;
            analyzed.second_parameter = right_parameter;
            return analyzed;
        }

        if expression.tag != 12 {
            return analyzed;
        }

        mut callee := ctx[expression.Call.function];
        if callee.tag == 0 {
            mut host_index := mir_native_module_import_host_index(
                hosts,
                function.module_index,
                callee.Identifier.name,
                ctx
            );
            if host_index >= 0 {
                if is_unsafe_body == 0 {
                    return analyzed;
                }
                mut host := hosts[host_index];
                analyzed.callee_kind = 2;
                analyzed.callee_name = std.Clone(ctx, host.name);
                analyzed.callee_link_name = std.Clone(ctx, host.link_name);
                analyzed.boundary_kind = host.boundary_kind;
            } else {
                if is_unsafe_body == 1 {
                    return analyzed;
                }
                analyzed.callee_kind = 0;
                analyzed.callee_name = mir_native_module_import_qualified(
                    function.module_prefix,
                    callee.Identifier.name,
                    ctx
                );
                analyzed.callee_link_name =
                    std.Clone(ctx, analyzed.callee_name);
            }
        } else if callee.tag == 11 {
            if is_unsafe_body == 1 {
                return analyzed;
            }
            mut selector_left := ctx[callee.Selector.left];
            if selector_left.tag != 0 {
                return analyzed;
            }
            mut target_prefix := mir_native_module_import_alias_prefix(
                top_level,
                selector_left.Identifier.name,
                module_prefixes,
                ctx
            );
            if len(target_prefix) == 0 {
                return analyzed;
            }
            analyzed.callee_kind = 1;
            analyzed.callee_name = mir_native_module_import_qualified(
                target_prefix,
                callee.Selector.right,
                ctx
            );
            analyzed.callee_link_name =
                std.Clone(ctx, analyzed.callee_name);
        } else {
            return analyzed;
        }

        mut arguments: std.Vector[MirNativeModuleImportArgument[ctx], ctx] :=
            std.VectorNew(ctx);
        mut source_arguments: std.Vector[ast.Expression[ctx], ctx] :=
            ctx[expression.Call.arguments];
        mut argument_index := 0;
        while argument_index < len(source_arguments) {
            mut argument := mir_native_module_import_analyze_argument(
                source_arguments[argument_index],
                parameter_names,
                parameter_types,
                "",
                ctx
            );
            if argument.kind < 0 {
                analyzed.callee_kind = 0 - 1;
                return analyzed;
            }
            arguments.Push(argument);
            argument_index = argument_index + 1;
        }
        ctx.Set(analyzed.arguments, arguments);
        analyzed.profile = 2;
    }
    return analyzed;
}

func mir_native_module_import_validate_calls(model: MirNativeModuleImportModel[ctx], ctx: &Arena) MirNativeModuleImportModel[ctx] {
    mut functions: std.Vector[MirNativeModuleImportFunction[ctx], ctx] :=
        ctx[model.functions];
    mut hosts: std.Vector[MirNativeModuleImportHost[ctx], ctx] :=
        ctx[model.hosts];
    mut caller_index := 0;
    while caller_index < len(functions) {
        mut caller := functions[caller_index];
        if caller.profile == 2 || caller.profile == 3 || caller.profile == 4 {
            mut expected_parameter_types: std.Vector[str, ctx] :=
                std.VectorNew(ctx);
            mut expected_return_type := std.Clone(ctx, "");
            if caller.profile >= 3 && caller.callee_kind != 2 {
                return mir_native_module_import_invalid(
                    model,
                    "Native backend canonical MIR verification failed: runtime-call composition requires an approved host target",
                    ctx
                );
            }
            if caller.callee_kind == 0 || caller.callee_kind == 1 {
                mut callee_index := mir_native_module_import_function_index(
                    functions,
                    caller.callee_name,
                    ctx
                );
                if callee_index < 0 {
                    return mir_native_module_import_invalid(
                        model,
                        "Native backend canonical MIR verification failed: unresolved module or local function symbol",
                        ctx
                    );
                }
                mut callee := functions[callee_index];
                expected_parameter_types = ctx[callee.parameter_types];
                expected_return_type = std.Clone(ctx, callee.return_type);
                if caller.callee_kind == 0 &&
                   callee.module_index != caller.module_index
                {
                    return mir_native_module_import_invalid(
                        model,
                        "Native backend canonical MIR verification failed: local call resolved outside its source module",
                        ctx
                    );
                }
                if caller.callee_kind == 1 &&
                   callee.module_index == caller.module_index
                {
                    return mir_native_module_import_invalid(
                        model,
                        "Native backend canonical MIR verification failed: imported module call resolved inside its source module",
                        ctx
                    );
                }
            } else if caller.callee_kind == 2 {
                mut host_index := mir_native_module_import_host_index(
                    hosts,
                    caller.module_index,
                    caller.callee_name,
                    ctx
                );
                if host_index < 0 {
                    return mir_native_module_import_invalid(
                        model,
                        "Native backend canonical MIR verification failed: unresolved declared external import",
                        ctx
                    );
                }
                mut host := hosts[host_index];
                if host.boundary_kind == 0 {
                    return mir_native_module_import_invalid(
                        model,
                        "Native backend canonical MIR verification failed: forbidden runtime or external import",
                        ctx
                    );
                }
                expected_parameter_types = ctx[host.parameter_types];
                expected_return_type = std.Clone(ctx, host.return_type);
                if std.str_eq(host.link_name, caller.callee_link_name) == 0 ||
                   host.boundary_kind != caller.boundary_kind
                {
                    return mir_native_module_import_invalid(
                        model,
                        "Native backend canonical MIR verification failed: external import boundary classification drifted",
                        ctx
                    );
                }
            } else {
                return mir_native_module_import_invalid(
                    model,
                    "Native backend canonical MIR verification failed: unsupported indirect or unresolved call target",
                    ctx
                );
            }

            mut arguments: std.Vector[MirNativeModuleImportArgument[ctx], ctx] :=
                ctx[caller.arguments];
            if len(arguments) != len(expected_parameter_types) {
                return mir_native_module_import_invalid(
                    model,
                    "Native backend canonical MIR verification failed: module/import call argument count does not match callee parameter count",
                    ctx
                );
            }
            mut argument_index := 0;
            while argument_index < len(arguments) {
                if std.str_eq(
                    arguments[argument_index].value_type,
                    expected_parameter_types[argument_index]
                ) == 0 {
                    return mir_native_module_import_invalid(
                        model,
                        "Native backend canonical MIR verification failed: module/import call argument type does not match callee parameter type",
                        ctx
                    );
                }
                argument_index = argument_index + 1;
            }
            if caller.profile == 3 {
                mut second_arguments: std.Vector[MirNativeModuleImportArgument[ctx], ctx] :=
                    ctx[caller.second_arguments];
                if len(second_arguments) != len(expected_parameter_types) {
                    return mir_native_module_import_invalid(
                        model,
                        "Native backend canonical MIR verification failed: composed imported call argument count does not match approved parameter count",
                        ctx
                    );
                }
                argument_index = 0;
                while argument_index < len(second_arguments) {
                    if std.str_eq(
                        second_arguments[argument_index].value_type,
                        expected_parameter_types[argument_index]
                    ) == 0 {
                        return mir_native_module_import_invalid(
                            model,
                            "Native backend canonical MIR verification failed: composed imported call argument type does not match approved parameter type",
                            ctx
                        );
                    }
                    argument_index = argument_index + 1;
                }
            }
            if std.str_eq(caller.return_type, expected_return_type) == 0 {
                return mir_native_module_import_invalid(
                    model,
                    "Native backend canonical MIR verification failed: module/import call return type does not match caller return type",
                    ctx
                );
            }
        }
        caller_index = caller_index + 1;
    }
    return model;
}

func mir_native_module_import_validate_host_registry(model: MirNativeModuleImportModel[ctx], ctx: &Arena) MirNativeModuleImportModel[ctx] {
    mut hosts: std.Vector[MirNativeModuleImportHost[ctx], ctx] :=
        ctx[model.hosts];
    mut host_index := 0;
    while host_index < len(hosts) {
        mut host := hosts[host_index];
        if host.boundary_kind == 0 {
            return mir_native_module_import_invalid(
                model,
                "Native backend canonical MIR verification failed: external declaration is not present in the approved import/runtime registry",
                ctx
            );
        }
        mut prior_index := 0;
        while prior_index < host_index {
            mut prior := hosts[prior_index];
            if std.str_eq(prior.link_name, host.link_name) == 1 {
                if std.str_eq(
                    mir_native_module_import_host_signature(prior, ctx),
                    mir_native_module_import_host_signature(host, ctx)
                ) == 0 ||
                   prior.boundary_kind != host.boundary_kind
                {
                    return mir_native_module_import_invalid(
                        model,
                        "Native backend canonical MIR verification failed: imported symbol declarations disagree on signature or boundary classification",
                        ctx
                    );
                }
            }
            prior_index = prior_index + 1;
        }
        host_index = host_index + 1;
    }
    return model;
}

func mir_native_module_import_validate_acyclic(model: MirNativeModuleImportModel[ctx], ctx: &Arena) MirNativeModuleImportModel[ctx] {
    mut functions: std.Vector[MirNativeModuleImportFunction[ctx], ctx] :=
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
        if function.profile == 2 &&
           (function.callee_kind == 0 || function.callee_kind == 1)
        {
            mut callee_index := mir_native_module_import_function_index(
                functions,
                function.callee_name,
                ctx
            );
            if callee_index < 0 {
                return mir_native_module_import_invalid(
                    model,
                    "Native backend canonical MIR verification failed: unresolved module or local function symbol",
                    ctx
                );
            }
            indegree.Set(callee_index, indegree[callee_index] + 1);
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
            return mir_native_module_import_invalid(
                model,
                "Native backend canonical MIR verification failed: module/import call graph must be acyclic",
                ctx
            );
        }
        removed.Set(selected, 1);
        visited = visited + 1;
        mut selected_function := functions[selected];
        if selected_function.profile == 2 &&
           (selected_function.callee_kind == 0 ||
            selected_function.callee_kind == 1)
        {
            mut selected_callee := mir_native_module_import_function_index(
                functions,
                selected_function.callee_name,
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

func mir_native_module_import_evaluate_host(link_name: str, boundary_kind: int, values: std.Vector[int, ctx], ctx: &Arena) MirNativeModuleImportEvaluation {
    mut evaluation: MirNativeModuleImportEvaluation;
    evaluation.valid = 0;
    evaluation.value = 0;
    if boundary_kind == 1 &&
       std.str_eq(link_name, "abs") == 1 &&
       len(values) == 1
    {
        mut value := values[0];
        if value < 0 {
            value = 0 - value;
        }
        evaluation.valid = 1;
        evaluation.value = value;
        return evaluation;
    }
    if boundary_kind == 2 &&
       std.str_eq(link_name, "toupper") == 1 &&
       len(values) == 1
    {
        mut value := values[0];
        if value >= 97 && value <= 122 {
            value = value - 32;
        }
        evaluation.valid = 1;
        evaluation.value = value;
        return evaluation;
    }
    if boundary_kind == 2 &&
       std.str_eq(link_name, "tiny_host_add_one_i32") == 1 &&
       len(values) == 1
    {
        evaluation.valid = 1;
        evaluation.value = values[0] + 1;
        return evaluation;
    }
    if boundary_kind == 2 &&
       std.str_eq(link_name, "tiny_host_add_i32") == 1 &&
       len(values) == 2
    {
        evaluation.valid = 1;
        evaluation.value = values[0] + values[1];
        return evaluation;
    }
    if boundary_kind == 2 &&
       std.str_eq(link_name, "tiny_host_is_positive_i32") == 1 &&
       len(values) == 1
    {
        evaluation.valid = 1;
        if values[0] > 0 {
            evaluation.value = 1;
        }
        return evaluation;
    }
    return evaluation;
}

func mir_native_module_import_evaluate(functions: std.Vector[MirNativeModuleImportFunction[ctx], ctx], function_index: int, parameter_values: std.Vector[int, ctx], depth: int, ctx: &Arena) MirNativeModuleImportEvaluation {
    mut evaluation: MirNativeModuleImportEvaluation;
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
        mut call_values: std.Vector[int, ctx] := std.VectorNew(ctx);
        mut arguments: std.Vector[MirNativeModuleImportArgument[ctx], ctx] :=
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

        if function.callee_kind == 2 {
            return mir_native_module_import_evaluate_host(
                function.callee_link_name,
                function.boundary_kind,
                call_values,
                ctx
            );
        }

        mut callee_index := mir_native_module_import_function_index(
            functions,
            function.callee_name,
            ctx
        );
        if callee_index < 0 {
            return evaluation;
        }
        return mir_native_module_import_evaluate(
            functions,
            callee_index,
            call_values,
            depth + 1,
            ctx
        );
    }

    if function.profile == 3 || function.profile == 4 {
        mut first_values: std.Vector[int, ctx] := std.VectorNew(ctx);
        mut first_arguments: std.Vector[MirNativeModuleImportArgument[ctx], ctx] :=
            ctx[function.arguments];
        mut argument_index := 0;
        while argument_index < len(first_arguments) {
            mut argument := first_arguments[argument_index];
            if argument.kind == 0 || argument.kind == 1 {
                first_values.Push(argument.value);
            } else if argument.kind == 2 &&
                      argument.parameter_index >= 0 &&
                      argument.parameter_index < len(parameter_values)
            {
                first_values.Push(parameter_values[argument.parameter_index]);
            } else {
                return evaluation;
            }
            argument_index = argument_index + 1;
        }
        mut first_result := mir_native_module_import_evaluate_host(
            function.callee_link_name,
            function.boundary_kind,
            first_values,
            ctx
        );
        if first_result.valid == 0 {
            return evaluation;
        }

        if function.profile == 4 {
            evaluation.valid = 1;
            if first_result.value > 0 {
                evaluation.value = function.branch_then_value;
            } else {
                evaluation.value = function.branch_else_value;
            }
            return evaluation;
        }

        mut second_values: std.Vector[int, ctx] := std.VectorNew(ctx);
        mut second_arguments: std.Vector[MirNativeModuleImportArgument[ctx], ctx] :=
            ctx[function.second_arguments];
        argument_index = 0;
        while argument_index < len(second_arguments) {
            mut argument := second_arguments[argument_index];
            if argument.kind == 0 || argument.kind == 1 {
                second_values.Push(argument.value);
            } else if argument.kind == 2 &&
                      argument.parameter_index >= 0 &&
                      argument.parameter_index < len(parameter_values)
            {
                second_values.Push(parameter_values[argument.parameter_index]);
            } else if argument.kind == 3 &&
                      std.str_eq(
                          argument.local_name,
                          function.result_local_name
                      ) == 1
            {
                second_values.Push(first_result.value);
            } else {
                return evaluation;
            }
            argument_index = argument_index + 1;
        }
        mut second_result := mir_native_module_import_evaluate_host(
            function.callee_link_name,
            function.boundary_kind,
            second_values,
            ctx
        );
        if second_result.valid == 0 {
            return evaluation;
        }
        evaluation.valid = 1;
        evaluation.value =
            second_result.value + function.expression_add_value;
        return evaluation;
    }

    return evaluation;
}

func mir_native_module_import_analyze(programs: std.Vector[ast.Program[ctx], ctx], module_paths: std.Vector[str, ctx], module_prefixes: std.Vector[str, ctx], ctx: &Arena) MirNativeModuleImportModel[ctx] {
    mut model := mir_native_module_import_empty_model(ctx);
    if len(programs) == 0 ||
       len(programs) != len(module_paths) ||
       len(programs) != len(module_prefixes)
    {
        return model;
    }

    mut module_identity_index := 0;
    while module_identity_index < len(programs) {
        if module_identity_index == len(programs) - 1 {
            if std.str_eq(
                module_prefixes[module_identity_index],
                ""
            ) == 0 {
                model.represented = 1;
                return mir_native_module_import_invalid(
                    model,
                    "Native backend canonical MIR verification failed: entry module prefix must be empty",
                    ctx
                );
            }
        } else {
            if len(module_prefixes[module_identity_index]) == 0 {
                model.represented = 1;
                return mir_native_module_import_invalid(
                    model,
                    "Native backend canonical MIR verification failed: dependency module prefix must be nonempty",
                    ctx
                );
            }
        }

        mut prior_module_identity_index := 0;
        while prior_module_identity_index < module_identity_index {
            if std.str_eq(
                module_paths[prior_module_identity_index],
                module_paths[module_identity_index]
            ) == 1 ||
               std.str_eq(
                   module_prefixes[prior_module_identity_index],
                   module_prefixes[module_identity_index]
               ) == 1 ||
               std.str_eq(
                   mir_native_module_import_object_name(
                       module_paths[prior_module_identity_index],
                       ctx
                   ),
                   mir_native_module_import_object_name(
                       module_paths[module_identity_index],
                       ctx
                   )
               ) == 1
            {
                model.represented = 1;
                return mir_native_module_import_invalid(
                    model,
                    "Native backend canonical MIR verification failed: duplicate module path, prefix, or object identity",
                    ctx
                );
            }
            prior_module_identity_index =
                prior_module_identity_index + 1;
        }
        module_identity_index = module_identity_index + 1;
    }

    mut functions: std.Vector[MirNativeModuleImportFunction[ctx], ctx] :=
        std.VectorNew(ctx);
    mut hosts: std.Vector[MirNativeModuleImportHost[ctx], ctx] :=
        std.VectorNew(ctx);
    mut has_module_import_surface := 0;
    mut module_index := 0;
    while module_index < len(programs) {
        mut program := programs[module_index];
        mut top_level: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[program.statements];
        mut statement_index := 0;
        while statement_index < len(top_level) {
            mut statement := top_level[statement_index];
            unsafe {
                if statement.tag == 0 {
                    has_module_import_surface = 1;
                } else if statement.tag == 3 {
                    if statement.FunctionDecl.is_extern == 1 {
                        has_module_import_surface = 1;
                        mut host := mir_native_module_import_make_host(
                            statement,
                            module_index,
                            ctx
                        );
                        if len(host.name) == 0 {
                            model.represented = 1;
                            return mir_native_module_import_invalid(
                                model,
                                "Native backend canonical MIR verification failed: unsupported external declaration shape",
                                ctx
                            );
                        }
                        hosts.Push(host);
                    } else {
                        mut function :=
                            mir_native_module_import_make_function_signature(
                                statement,
                                module_index,
                                module_paths[module_index],
                                module_prefixes[module_index],
                                ctx
                            );
                        if len(function.qualified_name) == 0 {
                            if has_module_import_surface == 1 ||
                               len(programs) > 1
                            {
                                model.represented = 1;
                                return mir_native_module_import_invalid(
                                    model,
                                    "Native backend canonical MIR verification failed: module function uses an unsupported scalar signature",
                                    ctx
                                );
                            }
                            return model;
                        }
                        if mir_native_module_import_function_index(
                            functions,
                            function.qualified_name,
                            ctx
                        ) >= 0 {
                            model.represented = 1;
                            return mir_native_module_import_invalid(
                                model,
                                "Native backend canonical MIR verification failed: duplicate fully qualified function symbol",
                                ctx
                            );
                        }
                        functions.Push(function);
                    }
                } else {
                    if has_module_import_surface == 1 || len(programs) > 1 {
                        model.represented = 1;
                        return mir_native_module_import_invalid(
                            model,
                            "Native backend canonical MIR verification failed: unsupported top-level statement in module/import cohort",
                            ctx
                        );
                    }
                    return model;
                }
            }
            statement_index = statement_index + 1;
        }
        module_index = module_index + 1;
    }

    if len(programs) > 1 {
        has_module_import_surface = 1;
    }
    if has_module_import_surface == 0 {
        return model;
    }
    model.represented = 1;
    model.module_paths =
        mir_native_module_import_clone_strings(module_paths, ctx);
    model.module_prefixes =
        mir_native_module_import_clone_strings(module_prefixes, ctx);
    ctx.Set(model.hosts, hosts);

    module_index = 0;
    while module_index < len(programs) {
        mut program := programs[module_index];
        mut top_level: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[program.statements];
        mut statement_index := 0;
        while statement_index < len(top_level) {
            mut statement := top_level[statement_index];
            unsafe {
                if statement.tag == 3 &&
                   statement.FunctionDecl.is_extern == 0
                {
                    mut qualified_name := mir_native_module_import_qualified(
                        module_prefixes[module_index],
                        statement.FunctionDecl.name,
                        ctx
                    );
                    mut function_index :=
                        mir_native_module_import_function_index(
                            functions,
                            qualified_name,
                            ctx
                        );
                    if function_index < 0 {
                        return mir_native_module_import_invalid(
                            model,
                            "Native backend canonical MIR verification failed: fully qualified function signature disappeared before body analysis",
                            ctx
                        );
                    }
                    mut analyzed :=
                        mir_native_module_import_analyze_function_body(
                            functions[function_index],
                            statement,
                            top_level,
                            module_prefixes,
                            functions,
                            hosts,
                            ctx
                        );
                    if analyzed.profile < 0 {
                        return mir_native_module_import_invalid(
                            model,
                            "Native backend canonical MIR verification failed: module/import function body is outside the initial direct scalar profile",
                            ctx
                        );
                    }
                    functions.Set(function_index, analyzed);
                }
            }
            statement_index = statement_index + 1;
        }
        module_index = module_index + 1;
    }
    ctx.Set(model.functions, functions);

    mut entry_index := 0 - 1;
    mut function_index := 0;
    while function_index < len(functions) {
        mut function := functions[function_index];
        if std.str_eq(function.qualified_name, "main") == 1 {
            if entry_index >= 0 {
                return mir_native_module_import_invalid(
                    model,
                    "Native backend canonical MIR verification failed: multiple exported entry functions",
                    ctx
                );
            }
            entry_index = function_index;
        }
        function_index = function_index + 1;
    }
    if entry_index < 0 {
        return mir_native_module_import_invalid(
            model,
            "Native backend canonical MIR verification failed: module bundle is missing main",
            ctx
        );
    }
    mut entry := functions[entry_index];
    mut entry_parameters: std.Vector[str, ctx] := ctx[entry.parameter_types];
    if entry.module_index != len(programs) - 1 ||
       len(entry_parameters) != 0 ||
       std.str_eq(entry.return_type, "int") == 0
    {
        return mir_native_module_import_invalid(
            model,
            "Native backend canonical MIR verification failed: entry module main must have signature ()->int",
            ctx
        );
    }
    model.entry_index = entry_index;

    model = mir_native_module_import_validate_host_registry(model, ctx);
    if model.invalid == 1 {
        return model;
    }
    model = mir_native_module_import_validate_calls(model, ctx);
    if model.invalid == 1 {
        return model;
    }
    model = mir_native_module_import_validate_acyclic(model, ctx);
    if model.invalid == 1 {
        return model;
    }

    mut no_arguments: std.Vector[int, ctx] := std.VectorNew(ctx);
    mut evaluation := mir_native_module_import_evaluate(
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
        return mir_native_module_import_invalid(
            model,
            "Native backend canonical MIR verification failed: module/import entry result is not a deterministic exit value in 0..=255",
            ctx
        );
    }
    model.expected_exit = evaluation.value;
    return model;
}
func mir_native_module_import_emit_argument(output: str, function_index: int, statement_index: int, argument_index: int, argument: MirNativeModuleImportArgument[ctx], ctx: &Arena) str {
    mut emitted := output;
    emitted = mir_native_module_import_append(emitted, "function_", ctx);
    emitted = mir_native_module_import_append_int(
        emitted,
        function_index,
        ctx
    );
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_statement_",
        ctx
    );
    emitted = mir_native_module_import_append_int(
        emitted,
        statement_index,
        ctx
    );
    emitted = mir_native_module_import_append(
        emitted,
        "_argument_",
        ctx
    );
    emitted = mir_native_module_import_append_int(
        emitted,
        argument_index,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "_kind: ", ctx);
    if argument.kind == 0 {
        emitted = mir_native_module_import_append(emitted, "I32Literal\n", ctx);
    } else if argument.kind == 1 {
        emitted = mir_native_module_import_append(emitted, "BoolLiteral\n", ctx);
    } else if argument.kind == 2 {
        emitted = mir_native_module_import_append(emitted, "FunctionParamI32\n", ctx);
    } else {
        emitted = mir_native_module_import_append(emitted, "LocalI32\n", ctx);
    }

    emitted = mir_native_module_import_append(emitted, "function_", ctx);
    emitted = mir_native_module_import_append_int(
        emitted,
        function_index,
        ctx
    );
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_statement_",
        ctx
    );
    emitted = mir_native_module_import_append_int(
        emitted,
        statement_index,
        ctx
    );
    emitted = mir_native_module_import_append(
        emitted,
        "_argument_",
        ctx
    );
    emitted = mir_native_module_import_append_int(
        emitted,
        argument_index,
        ctx
    );
    if argument.kind == 0 || argument.kind == 1 {
        emitted = mir_native_module_import_append(emitted, "_value: ", ctx);
        emitted = mir_native_module_import_append_int(
            emitted,
            argument.value,
            ctx
        );
    } else if argument.kind == 2 {
        emitted = mir_native_module_import_append(emitted, "_param: ", ctx);
        emitted = mir_native_module_import_append_int(
            emitted,
            argument.parameter_index,
            ctx
        );
    } else {
        emitted = mir_native_module_import_append(emitted, "_local: ", ctx);
        emitted = mir_native_module_import_append(
            emitted,
            argument.local_name,
            ctx
        );
    }
    emitted = mir_native_module_import_append(emitted, "\n", ctx);
    return std.Clone(ctx, emitted);
}

func mir_native_module_import_emit_call_statement(output: str, function: MirNativeModuleImportFunction[ctx], function_index: int, statement_index: int, local_name: str, arguments: std.Vector[MirNativeModuleImportArgument[ctx], ctx], ctx: &Arena) str {
    mut emitted := output;
    emitted = mir_native_module_import_append(emitted, "function_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_block_0_statement_", ctx);
    emitted = mir_native_module_import_append_int(emitted, statement_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_kind: LocalI32SetCall\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_block_0_statement_", ctx);
    emitted = mir_native_module_import_append_int(emitted, statement_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_local: ", ctx);
    emitted = mir_native_module_import_append(emitted, local_name, ctx);
    emitted = mir_native_module_import_append(emitted, "\nfunction_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_block_0_statement_", ctx);
    emitted = mir_native_module_import_append_int(emitted, statement_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_callee_kind: ImportedFunction\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_block_0_statement_", ctx);
    emitted = mir_native_module_import_append_int(emitted, statement_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_callee: ", ctx);
    emitted = mir_native_module_import_append(
        emitted,
        function.callee_name,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "\nfunction_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_block_0_statement_", ctx);
    emitted = mir_native_module_import_append_int(emitted, statement_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_argument_count: ",
        ctx
    );
    emitted = mir_native_module_import_append_int(
        emitted,
        len(arguments),
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "\n", ctx);
    mut argument_index := 0;
    while argument_index < len(arguments) {
        emitted = mir_native_module_import_emit_argument(
            emitted,
            function_index,
            statement_index,
            argument_index,
            arguments[argument_index],
            ctx
        );
        argument_index = argument_index + 1;
    }
    return std.Clone(ctx, emitted);
}

func mir_native_module_import_emit_boundary_metadata(output: str, function: MirNativeModuleImportFunction[ctx], function_index: int, metadata_index: int, statement_index: int, ctx: &Arena) str {
    mut emitted := output;
    emitted = mir_native_module_import_append(emitted, "function_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_metadata_", ctx);
    emitted = mir_native_module_import_append_int(emitted, metadata_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_kind: native_boundary\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_metadata_", ctx);
    emitted = mir_native_module_import_append_int(emitted, metadata_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_attachment: statement:entry:",
        ctx
    );
    emitted = mir_native_module_import_append_int(
        emitted,
        statement_index,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "\nfunction_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_metadata_", ctx);
    emitted = mir_native_module_import_append_int(emitted, metadata_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_policy: ignored_with_proof\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_metadata_", ctx);
    emitted = mir_native_module_import_append_int(emitted, metadata_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_payload: kind=", ctx);
    if function.boundary_kind == 1 {
        emitted = mir_native_module_import_append(emitted, "RuntimeCall", ctx);
    } else {
        emitted = mir_native_module_import_append(emitted, "ExternFunction", ctx);
    }
    emitted = mir_native_module_import_append(emitted, ";symbol=", ctx);
    emitted = mir_native_module_import_append(
        emitted,
        function.callee_link_name,
        ctx
    );
    emitted = mir_native_module_import_append(
        emitted,
        ";codegen=none;proof=runtime_boundary_classification_is_registry_validated;origin=",
        ctx
    );
    emitted = mir_native_module_import_append(
        emitted,
        function.module_path,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "\n", ctx);
    return std.Clone(ctx, emitted);
}

func mir_native_module_import_emit_special_header(output: str, function: MirNativeModuleImportFunction[ctx], function_index: int, linkage_name: str, block_count: int, ctx: &Arena) str {
    mut emitted := output;
    emitted = mir_native_module_import_append(emitted, "function_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_linkage: ", ctx);
    emitted = mir_native_module_import_append(emitted, linkage_name, ctx);
    emitted = mir_native_module_import_append(emitted, "\nfunction_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_function: ", ctx);
    emitted = mir_native_module_import_append(
        emitted,
        function.qualified_name,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "\nfunction_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_backend_symbol: ",
        ctx
    );
    emitted = mir_native_module_import_append(
        emitted,
        function.qualified_name,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "\nfunction_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    mut parameter_types: std.Vector[str, ctx] := ctx[function.parameter_types];
    emitted = mir_native_module_import_append(
        emitted,
        "_parameter_count: ",
        ctx
    );
    emitted = mir_native_module_import_append_int(
        emitted,
        len(parameter_types),
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "\n", ctx);
    mut parameter_index := 0;
    while parameter_index < len(parameter_types) {
        emitted = mir_native_module_import_append(emitted, "function_", ctx);
        emitted = mir_native_module_import_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            "_parameter_",
            ctx
        );
        emitted = mir_native_module_import_append_int(
            emitted,
            parameter_index,
            ctx
        );
        emitted = mir_native_module_import_append(emitted, "_type: ", ctx);
        emitted = mir_native_module_import_append(
            emitted,
            parameter_types[parameter_index],
            ctx
        );
        emitted = mir_native_module_import_append(emitted, "\n", ctx);
        parameter_index = parameter_index + 1;
    }
    emitted = mir_native_module_import_append(emitted, "function_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_return_type: ", ctx);
    emitted = mir_native_module_import_append(
        emitted,
        function.return_type,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "\nfunction_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_local_count: 1\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_local_0_name: ", ctx);
    emitted = mir_native_module_import_append(
        emitted,
        function.result_local_name,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "\nfunction_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_local_0_type: int\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_entry_block: entry\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_block_count: ", ctx);
    emitted = mir_native_module_import_append_int(emitted, block_count, ctx);
    emitted = mir_native_module_import_append(emitted, "\n", ctx);
    return std.Clone(ctx, emitted);
}

func mir_native_module_import_emit_host_composition_function(output: str, function: MirNativeModuleImportFunction[ctx], function_index: int, linkage_name: str, expected_exit: int, ctx: &Arena) str {
    mut emitted := mir_native_module_import_emit_special_header(
        output,
        function,
        function_index,
        linkage_name,
        1,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "function_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_label: entry\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_parameter_count: 0\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_statement_count: 3\n",
        ctx
    );
    mut first_arguments: std.Vector[MirNativeModuleImportArgument[ctx], ctx] :=
        ctx[function.arguments];
    emitted = mir_native_module_import_emit_call_statement(
        emitted,
        function,
        function_index,
        0,
        function.result_local_name,
        first_arguments,
        ctx
    );
    mut second_arguments: std.Vector[MirNativeModuleImportArgument[ctx], ctx] :=
        ctx[function.second_arguments];
    emitted = mir_native_module_import_emit_call_statement(
        emitted,
        function,
        function_index,
        1,
        function.result_local_name,
        second_arguments,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "function_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_statement_2_kind: LocalI32AddI32Literal\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_statement_2_local: ",
        ctx
    );
    emitted = mir_native_module_import_append(
        emitted,
        function.result_local_name,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "\nfunction_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_statement_2_value: ",
        ctx
    );
    emitted = mir_native_module_import_append_int(
        emitted,
        function.expression_add_value,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "\nfunction_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_terminator_kind: ReturnLocalI32\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_terminator_local: ",
        ctx
    );
    emitted = mir_native_module_import_append(
        emitted,
        function.result_local_name,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "\nfunction_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_metadata_count: 2\n",
        ctx
    );
    emitted = mir_native_module_import_emit_boundary_metadata(
        emitted,
        function,
        function_index,
        0,
        0,
        ctx
    );
    emitted = mir_native_module_import_emit_boundary_metadata(
        emitted,
        function,
        function_index,
        1,
        1,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "function_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_expected_exit: ", ctx);
    emitted = mir_native_module_import_append_int(emitted, expected_exit, ctx);
    emitted = mir_native_module_import_append(emitted, "\n", ctx);
    return std.Clone(ctx, emitted);
}

func mir_native_module_import_emit_host_predicate_function(output: str, function: MirNativeModuleImportFunction[ctx], function_index: int, linkage_name: str, expected_exit: int, ctx: &Arena) str {
    mut emitted := mir_native_module_import_emit_special_header(
        output,
        function,
        function_index,
        linkage_name,
        3,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "function_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_label: entry\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_parameter_count: 0\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_statement_count: 1\n",
        ctx
    );
    mut arguments: std.Vector[MirNativeModuleImportArgument[ctx], ctx] :=
        ctx[function.arguments];
    emitted = mir_native_module_import_emit_call_statement(
        emitted,
        function,
        function_index,
        0,
        function.result_local_name,
        arguments,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "function_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_terminator_kind: BranchLocalI32Positive\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_terminator_local: ",
        ctx
    );
    emitted = mir_native_module_import_append(
        emitted,
        function.result_local_name,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "\nfunction_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_terminator_then: host_positive\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_terminator_then_argument_count: 0\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_terminator_else: host_non_positive\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_terminator_else_argument_count: 0\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_1_label: host_positive\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_1_parameter_count: 0\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_1_statement_count: 0\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_1_terminator_kind: ReturnI32\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_1_terminator_value: ",
        ctx
    );
    emitted = mir_native_module_import_append_int(
        emitted,
        function.branch_then_value,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "\nfunction_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_2_label: host_non_positive\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_2_parameter_count: 0\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_2_statement_count: 0\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_2_terminator_kind: ReturnI32\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_2_terminator_value: ",
        ctx
    );
    emitted = mir_native_module_import_append_int(
        emitted,
        function.branch_else_value,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "\nfunction_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_metadata_count: 1\n",
        ctx
    );
    emitted = mir_native_module_import_emit_boundary_metadata(
        emitted,
        function,
        function_index,
        0,
        0,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "function_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_expected_exit: ", ctx);
    emitted = mir_native_module_import_append_int(emitted, expected_exit, ctx);
    emitted = mir_native_module_import_append(emitted, "\n", ctx);
    return std.Clone(ctx, emitted);
}

func mir_native_module_import_emit_function(output: str, function: MirNativeModuleImportFunction[ctx], function_index: int, linkage_name: str, expected_exit: int, ctx: &Arena) str {
    if function.profile == 3 {
        return mir_native_module_import_emit_host_composition_function(
            output,
            function,
            function_index,
            linkage_name,
            expected_exit,
            ctx
        );
    }
    if function.profile == 4 {
        return mir_native_module_import_emit_host_predicate_function(
            output,
            function,
            function_index,
            linkage_name,
            expected_exit,
            ctx
        );
    }
    mut emitted := output;
    emitted = mir_native_module_import_append(emitted, "function_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_linkage: ", ctx);
    emitted = mir_native_module_import_append(emitted, linkage_name, ctx);
    emitted = mir_native_module_import_append(emitted, "\n", ctx);
    emitted = mir_native_module_import_append(emitted, "function_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_function: ", ctx);
    emitted = mir_native_module_import_append(emitted, function.qualified_name, ctx);
    emitted = mir_native_module_import_append(emitted, "\nfunction_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_backend_symbol: ",
        ctx
    );
    emitted = mir_native_module_import_append(emitted, function.qualified_name, ctx);
    emitted = mir_native_module_import_append(emitted, "\nfunction_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);

    mut parameter_types: std.Vector[str, ctx] :=
        ctx[function.parameter_types];
    emitted = mir_native_module_import_append(
        emitted,
        "_parameter_count: ",
        ctx
    );
    emitted = mir_native_module_import_append_int(
        emitted,
        len(parameter_types),
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "\n", ctx);
    mut parameter_index := 0;
    while parameter_index < len(parameter_types) {
        emitted = mir_native_module_import_append(emitted, "function_", ctx);
        emitted = mir_native_module_import_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            "_parameter_",
            ctx
        );
        emitted = mir_native_module_import_append_int(
            emitted,
            parameter_index,
            ctx
        );
        emitted = mir_native_module_import_append(emitted, "_type: ", ctx);
        emitted = mir_native_module_import_append(
            emitted,
            parameter_types[parameter_index],
            ctx
        );
        emitted = mir_native_module_import_append(emitted, "\n", ctx);
        parameter_index = parameter_index + 1;
    }

    emitted = mir_native_module_import_append(emitted, "function_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(emitted, "_return_type: ", ctx);
    emitted = mir_native_module_import_append(
        emitted,
        function.return_type,
        ctx
    );
    emitted = mir_native_module_import_append(
        emitted,
        "\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_local_count: 1\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_local_0_name: return_value\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_local_0_type: ",
        ctx
    );
    emitted = mir_native_module_import_append(
        emitted,
        function.return_type,
        ctx
    );
    emitted = mir_native_module_import_append(
        emitted,
        "\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_entry_block: entry\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_count: 1\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_label: entry\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_parameter_count: 0\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);

    if function.profile == 0 {
        emitted = mir_native_module_import_append(
            emitted,
            "_block_0_statement_count: 1\nfunction_",
            ctx
        );
        emitted = mir_native_module_import_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            "_block_0_statement_0_kind: LocalI32SetParam\nfunction_",
            ctx
        );
        emitted = mir_native_module_import_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            "_block_0_statement_0_local: return_value\nfunction_",
            ctx
        );
        emitted = mir_native_module_import_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            "_block_0_statement_0_param: ",
            ctx
        );
        emitted = mir_native_module_import_append_int(
            emitted,
            function.first_parameter,
            ctx
        );
        emitted = mir_native_module_import_append(emitted, "\n", ctx);
    } else if function.profile == 1 {
        emitted = mir_native_module_import_append(
            emitted,
            "_block_0_statement_count: 2\nfunction_",
            ctx
        );
        emitted = mir_native_module_import_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            "_block_0_statement_0_kind: LocalI32SetParam\nfunction_",
            ctx
        );
        emitted = mir_native_module_import_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            "_block_0_statement_0_local: return_value\nfunction_",
            ctx
        );
        emitted = mir_native_module_import_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            "_block_0_statement_0_param: ",
            ctx
        );
        emitted = mir_native_module_import_append_int(
            emitted,
            function.first_parameter,
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            "\nfunction_",
            ctx
        );
        emitted = mir_native_module_import_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            "_block_0_statement_1_kind: LocalI32AddParam\nfunction_",
            ctx
        );
        emitted = mir_native_module_import_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            "_block_0_statement_1_local: return_value\nfunction_",
            ctx
        );
        emitted = mir_native_module_import_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            "_block_0_statement_1_param: ",
            ctx
        );
        emitted = mir_native_module_import_append_int(
            emitted,
            function.second_parameter,
            ctx
        );
        emitted = mir_native_module_import_append(emitted, "\n", ctx);
    } else {
        emitted = mir_native_module_import_append(
            emitted,
            "_block_0_statement_count: 1\nfunction_",
            ctx
        );
        emitted = mir_native_module_import_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            "_block_0_statement_0_kind: LocalI32SetCall\nfunction_",
            ctx
        );
        emitted = mir_native_module_import_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            "_block_0_statement_0_local: return_value\nfunction_",
            ctx
        );
        emitted = mir_native_module_import_append_int(
            emitted,
            function_index,
            ctx
        );
        if function.callee_kind == 0 {
            emitted = mir_native_module_import_append(
                emitted,
                "_block_0_statement_0_callee_kind: LocalFunction\nfunction_",
                ctx
            );
        } else {
            emitted = mir_native_module_import_append(
                emitted,
                "_block_0_statement_0_callee_kind: ImportedFunction\nfunction_",
                ctx
            );
        }
        emitted = mir_native_module_import_append_int(
            emitted,
            function_index,
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            "_block_0_statement_0_callee: ",
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            function.callee_name,
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            "\nfunction_",
            ctx
        );
        emitted = mir_native_module_import_append_int(
            emitted,
            function_index,
            ctx
        );
        mut arguments: std.Vector[MirNativeModuleImportArgument[ctx], ctx] :=
            ctx[function.arguments];
        emitted = mir_native_module_import_append(
            emitted,
            "_block_0_statement_0_argument_count: ",
            ctx
        );
        emitted = mir_native_module_import_append_int(
            emitted,
            len(arguments),
            ctx
        );
        emitted = mir_native_module_import_append(emitted, "\n", ctx);
        mut argument_index := 0;
        while argument_index < len(arguments) {
            emitted = mir_native_module_import_emit_argument(
                emitted,
                function_index,
                0,
                argument_index,
                arguments[argument_index],
                ctx
            );
            argument_index = argument_index + 1;
        }
    }

    emitted = mir_native_module_import_append(emitted, "function_", ctx);
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_terminator_kind: ReturnLocalI32\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    emitted = mir_native_module_import_append(
        emitted,
        "_block_0_terminator_local: return_value\nfunction_",
        ctx
    );
    emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    if function.callee_kind == 2 {
        emitted = mir_native_module_import_append(
            emitted,
            "_metadata_count: 1\nfunction_",
            ctx
        );
        emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
        emitted = mir_native_module_import_append(
            emitted,
            "_metadata_0_kind: native_boundary\nfunction_",
            ctx
        );
        emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
        emitted = mir_native_module_import_append(
            emitted,
            "_metadata_0_attachment: statement:entry:0\nfunction_",
            ctx
        );
        emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
        emitted = mir_native_module_import_append(
            emitted,
            "_metadata_0_policy: ignored_with_proof\nfunction_",
            ctx
        );
        emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
        emitted = mir_native_module_import_append(
            emitted,
            "_metadata_0_payload: kind=",
            ctx
        );
        if function.boundary_kind == 1 {
            emitted = mir_native_module_import_append(
                emitted,
                "RuntimeCall",
                ctx
            );
        } else {
            emitted = mir_native_module_import_append(
                emitted,
                "ExternFunction",
                ctx
            );
        }
        emitted = mir_native_module_import_append(
            emitted,
            ";symbol=",
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            function.callee_link_name,
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            ";codegen=none;proof=runtime_boundary_classification_is_registry_validated;origin=",
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            function.module_path,
            ctx
        );
        emitted = mir_native_module_import_append(emitted, "\nfunction_", ctx);
        emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    } else {
        emitted = mir_native_module_import_append(
            emitted,
            "_metadata_count: 0\nfunction_",
            ctx
        );
        emitted = mir_native_module_import_append_int(emitted, function_index, ctx);
    }
    emitted = mir_native_module_import_append(
        emitted,
        "_expected_exit: ",
        ctx
    );
    emitted = mir_native_module_import_append_int(
        emitted,
        expected_exit,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "\n", ctx);
    return std.Clone(ctx, emitted);
}

func mir_native_module_import_is_bundle_export(function: MirNativeModuleImportFunction[ctx], functions: std.Vector[MirNativeModuleImportFunction[ctx], ctx], ctx: &Arena) int {
    mut caller_index := 0;
    while caller_index < len(functions) {
        mut caller := functions[caller_index];
        if caller.profile == 2 &&
           caller.callee_kind == 1 &&
           std.str_eq(caller.callee_name, function.qualified_name) == 1
        {
            return 1;
        }
        caller_index = caller_index + 1;
    }
    return 0;
}

func mir_native_module_import_function_linkage(function: MirNativeModuleImportFunction[ctx], functions: std.Vector[MirNativeModuleImportFunction[ctx], ctx], ctx: &Arena) str {
    if std.str_eq(function.qualified_name, "main") == 1 {
        return std.Clone(ctx, "exported_entry");
    }
    if mir_native_module_import_is_bundle_export(
        function,
        functions,
        ctx
    ) == 1 {
        return std.Clone(ctx, "bundle_export");
    }
    return std.Clone(ctx, "module_local");
}

func mir_native_module_import_function_linkage_tag(function: MirNativeModuleImportFunction[ctx], functions: std.Vector[MirNativeModuleImportFunction[ctx], ctx], ctx: &Arena) int {
    if std.str_eq(function.qualified_name, "main") == 1 {
        return 0;
    }
    if mir_native_module_import_is_bundle_export(
        function,
        functions,
        ctx
    ) == 1 {
        return 3;
    }
    return 1;
}

func mir_native_module_import_is_first_import(function_index: int, functions: std.Vector[MirNativeModuleImportFunction[ctx], ctx], ctx: &Arena) int {
    mut function := functions[function_index];
    if function.profile < 2 ||
       (function.callee_kind != 1 && function.callee_kind != 2)
    {
        return 0;
    }
    mut prior_index := 0;
    while prior_index < function_index {
        mut prior := functions[prior_index];
        if prior.module_index == function.module_index &&
           prior.profile >= 2 &&
           prior.callee_kind == function.callee_kind &&
           std.str_eq(
               prior.callee_link_name,
               function.callee_link_name
           ) == 1
        {
            return 0;
        }
        prior_index = prior_index + 1;
    }
    return 1;
}

func mir_native_module_import_count_imports(module_index: int, functions: std.Vector[MirNativeModuleImportFunction[ctx], ctx], ctx: &Arena) int {
    mut count := 0;
    mut function_index := 0;
    while function_index < len(functions) {
        if functions[function_index].module_index == module_index &&
           mir_native_module_import_is_first_import(
               function_index,
               functions,
               ctx
           ) == 1
        {
            count = count + 1;
        }
        function_index = function_index + 1;
    }
    return count;
}

func mir_native_module_import_count_functions(module_index: int, functions: std.Vector[MirNativeModuleImportFunction[ctx], ctx], ctx: &Arena) int {
    mut count := 0;
    mut function_index := 0;
    while function_index < len(functions) {
        if functions[function_index].module_index == module_index {
            count = count + 1;
        }
        function_index = function_index + 1;
    }
    return count;
}

func mir_native_module_import_find_host_by_link(hosts: std.Vector[MirNativeModuleImportHost[ctx], ctx], module_index: int, link_name: str, ctx: &Arena) int {
    mut host_index := 0;
    while host_index < len(hosts) {
        if hosts[host_index].module_index == module_index &&
           std.str_eq(hosts[host_index].link_name, link_name) == 1
        {
            return host_index;
        }
        host_index = host_index + 1;
    }
    return 0 - 1;
}

func mir_native_module_import_emit_import(output: str, import_index: int, caller: MirNativeModuleImportFunction[ctx], functions: std.Vector[MirNativeModuleImportFunction[ctx], ctx], hosts: std.Vector[MirNativeModuleImportHost[ctx], ctx], ctx: &Arena) str {
    mut emitted := output;
    mut import_name := std.Clone(ctx, caller.callee_name);
    mut link_name := std.Clone(ctx, caller.callee_link_name);
    mut linkage_name := std.Clone(ctx, "imported_bundle");
    mut parameter_types: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut return_type := std.Clone(ctx, "");

    if caller.callee_kind == 1 {
        mut callee_index := mir_native_module_import_function_index(
            functions,
            caller.callee_name,
            ctx
        );
        if callee_index >= 0 {
            parameter_types = ctx[functions[callee_index].parameter_types];
            return_type = std.Clone(
                ctx,
                functions[callee_index].return_type
            );
        }
    } else {
        linkage_name = std.Clone(ctx, "imported_host");
        mut host_index := mir_native_module_import_find_host_by_link(
            hosts,
            caller.module_index,
            caller.callee_link_name,
            ctx
        );
        if host_index >= 0 {
            mut host := hosts[host_index];
            import_name = std.Clone(ctx, host.name);
            link_name = std.Clone(ctx, host.link_name);
            parameter_types = ctx[host.parameter_types];
            return_type = std.Clone(ctx, host.return_type);
        }
    }

    emitted = mir_native_module_import_append(emitted, "import_", ctx);
    emitted = mir_native_module_import_append_int(
        emitted,
        import_index,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "_name: ", ctx);
    emitted = mir_native_module_import_append(emitted, import_name, ctx);
    emitted = mir_native_module_import_append(emitted, "\nimport_", ctx);
    emitted = mir_native_module_import_append_int(
        emitted,
        import_index,
        ctx
    );
    emitted = mir_native_module_import_append(
        emitted,
        "_link_symbol: ",
        ctx
    );
    emitted = mir_native_module_import_append(emitted, link_name, ctx);
    emitted = mir_native_module_import_append(emitted, "\nimport_", ctx);
    emitted = mir_native_module_import_append_int(
        emitted,
        import_index,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "_linkage: ", ctx);
    emitted = mir_native_module_import_append(emitted, linkage_name, ctx);
    emitted = mir_native_module_import_append(emitted, "\nimport_", ctx);
    emitted = mir_native_module_import_append_int(
        emitted,
        import_index,
        ctx
    );
    emitted = mir_native_module_import_append(
        emitted,
        "_parameter_count: ",
        ctx
    );
    emitted = mir_native_module_import_append_int(
        emitted,
        len(parameter_types),
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "\n", ctx);

    mut parameter_index := 0;
    while parameter_index < len(parameter_types) {
        emitted = mir_native_module_import_append(emitted, "import_", ctx);
        emitted = mir_native_module_import_append_int(
            emitted,
            import_index,
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            "_parameter_",
            ctx
        );
        emitted = mir_native_module_import_append_int(
            emitted,
            parameter_index,
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            "_type: ",
            ctx
        );
        emitted = mir_native_module_import_append(
            emitted,
            parameter_types[parameter_index],
            ctx
        );
        emitted = mir_native_module_import_append(emitted, "\n", ctx);
        parameter_index = parameter_index + 1;
    }

    emitted = mir_native_module_import_append(emitted, "import_", ctx);
    emitted = mir_native_module_import_append_int(
        emitted,
        import_index,
        ctx
    );
    emitted = mir_native_module_import_append(
        emitted,
        "_return_type: ",
        ctx
    );
    emitted = mir_native_module_import_append(
        emitted,
        return_type,
        ctx
    );
    emitted = mir_native_module_import_append(emitted, "\n", ctx);
    return std.Clone(ctx, emitted);
}

func mir_native_module_import_emit_canonical_module(model: MirNativeModuleImportModel[ctx], module_index: int, ctx: &Arena) str {
    mut functions: std.Vector[MirNativeModuleImportFunction[ctx], ctx] :=
        ctx[model.functions];
    mut hosts: std.Vector[MirNativeModuleImportHost[ctx], ctx] :=
        ctx[model.hosts];
    mut module_paths: std.Vector[str, ctx] := ctx[model.module_paths];

    mut canonical :=
        "format: gust.compiler_mir_ingestion.v2\nmodule: ";
    canonical = mir_native_module_import_append(
        canonical,
        mir_native_module_import_module_name(
            module_paths[module_index],
            ctx
        ),
        ctx
    );
    canonical = mir_native_module_import_append(
        canonical,
        "\nimport_count: ",
        ctx
    );
    canonical = mir_native_module_import_append_int(
        canonical,
        mir_native_module_import_count_imports(
            module_index,
            functions,
            ctx
        ),
        ctx
    );
    canonical = mir_native_module_import_append(canonical, "\n", ctx);

    mut import_index := 0;
    mut global_function_index := 0;
    while global_function_index < len(functions) {
        if functions[global_function_index].module_index == module_index &&
           mir_native_module_import_is_first_import(
               global_function_index,
               functions,
               ctx
           ) == 1
        {
            canonical = mir_native_module_import_emit_import(
                canonical,
                import_index,
                functions[global_function_index],
                functions,
                hosts,
                ctx
            );
            import_index = import_index + 1;
        }
        global_function_index = global_function_index + 1;
    }

    canonical = mir_native_module_import_append(
        canonical,
        "function_count: ",
        ctx
    );
    canonical = mir_native_module_import_append_int(
        canonical,
        mir_native_module_import_count_functions(
            module_index,
            functions,
            ctx
        ),
        ctx
    );
    canonical = mir_native_module_import_append(canonical, "\n", ctx);

    mut local_function_index := 0;
    global_function_index = 0;
    while global_function_index < len(functions) {
        mut function := functions[global_function_index];
        if function.module_index == module_index {
            mut expected_exit := 0;
            if global_function_index == model.entry_index {
                expected_exit = model.expected_exit;
            }
            canonical = mir_native_module_import_emit_function(
                canonical,
                function,
                local_function_index,
                mir_native_module_import_function_linkage(
                    function,
                    functions,
                    ctx
                ),
                expected_exit,
                ctx
            );
            local_function_index = local_function_index + 1;
        }
        global_function_index = global_function_index + 1;
    }
    return std.Clone(ctx, canonical);
}

func mir_native_module_import_add_import_symbols(module: mir.MirProgramBundleModule[ctx], module_index: int, functions: std.Vector[MirNativeModuleImportFunction[ctx], ctx], hosts: std.Vector[MirNativeModuleImportHost[ctx], ctx], ctx: &Arena) mir.MirProgramBundleModule[ctx] {
    mut updated := module;
    mut function_index := 0;
    while function_index < len(functions) {
        mut caller := functions[function_index];
        if caller.module_index == module_index &&
           mir_native_module_import_is_first_import(
               function_index,
               functions,
               ctx
           ) == 1
        {
            if caller.callee_kind == 1 {
                mut callee_index := mir_native_module_import_function_index(
                    functions,
                    caller.callee_name,
                    ctx
                );
                if callee_index >= 0 {
                    updated = mir.mir_program_bundle_module_with_symbol(
                        updated,
                        mir.mir_make_program_bundle_symbol(
                            caller.callee_name,
                            caller.callee_link_name,
                            mir_native_module_import_signature(
                                functions[callee_index],
                                ctx
                            ),
                            4,
                            ctx
                        ),
                        ctx
                    );
                }
            } else {
                mut host_index := mir_native_module_import_find_host_by_link(
                    hosts,
                    caller.module_index,
                    caller.callee_link_name,
                    ctx
                );
                if host_index >= 0 {
                    mut host := hosts[host_index];
                    updated = mir.mir_program_bundle_module_with_symbol(
                        updated,
                        mir.mir_make_program_bundle_symbol(
                            host.name,
                            host.link_name,
                            mir_native_module_import_host_signature(
                                host,
                                ctx
                            ),
                            2,
                            ctx
                        ),
                        ctx
                    );
                }
            }
        }
        function_index = function_index + 1;
    }
    return updated;
}

func mir_native_module_import_emit_bundle(model: MirNativeModuleImportModel[ctx], ctx: &Arena) mir.MirProgramBundle[ctx] {
    mut bundle := mir.mir_make_program_bundle("main", ctx);
    mut module_paths: std.Vector[str, ctx] := ctx[model.module_paths];
    mut module_prefixes: std.Vector[str, ctx] := ctx[model.module_prefixes];
    mut functions: std.Vector[MirNativeModuleImportFunction[ctx], ctx] :=
        ctx[model.functions];
    mut hosts: std.Vector[MirNativeModuleImportHost[ctx], ctx] :=
        ctx[model.hosts];

    mut module_index := 0;
    while module_index < len(module_paths) {
        mut native_boundary_count := 0;
        mut function_index := 0;
        while function_index < len(functions) {
            if functions[function_index].module_index == module_index &&
               functions[function_index].callee_kind == 2
            {
                native_boundary_count = native_boundary_count + 1;
                if functions[function_index].profile == 3 {
                    native_boundary_count = native_boundary_count + 1;
                }
            }
            function_index = function_index + 1;
        }

        mut module := mir.mir_make_program_bundle_module(
            module_paths[module_index],
            module_prefixes[module_index],
            mir_native_module_import_object_name(
                module_paths[module_index],
                ctx
            ),
            "gust.compiler_mir_ingestion.v2",
            mir_native_module_import_emit_canonical_module(
                model,
                module_index,
                ctx
            ),
            0,
            0,
            native_boundary_count,
            ctx
        );
        module = mir_native_module_import_add_import_symbols(
            module,
            module_index,
            functions,
            hosts,
            ctx
        );

        function_index = 0;
        while function_index < len(functions) {
            mut function := functions[function_index];
            if function.module_index == module_index {
                module = mir.mir_program_bundle_module_with_symbol(
                    module,
                    mir.mir_make_program_bundle_symbol(
                        function.qualified_name,
                        function.qualified_name,
                        mir_native_module_import_signature(function, ctx),
                        mir_native_module_import_function_linkage_tag(
                            function,
                            functions,
                            ctx
                        ),
                        ctx
                    ),
                    ctx
                );
            }
            function_index = function_index + 1;
        }
        bundle = mir.mir_program_bundle_with_module(bundle, module, ctx);
        module_index = module_index + 1;
    }
    return bundle;
}

func mir_native_module_import_source_lower(programs: std.Vector[ast.Program[ctx], ctx], module_paths: std.Vector[str, ctx], module_prefixes: std.Vector[str, ctx], ctx: &Arena) MirNativeModuleImportSourceResult[ctx] {
    mut result := mir_native_module_import_empty_result(ctx);
    mut model := mir_native_module_import_analyze(
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
    result.bundle = mir_native_module_import_emit_bundle(model, ctx);
    return result;
}
