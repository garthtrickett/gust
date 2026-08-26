import "ast.gst" as ast;
import "mir.gst" as mir;

// Patch 21.11 bounded typed-AST admission for source-declared Resource cleanup
// and synchronization. Selection is structural and uses resolved AST identity;
// source paths, fixture names, declared type names, and local spellings never
// select this route.

type MirNativeResourceSyncModel[ctx] struct {
    represented: int,
    kind: int,
    source_path: str,
    worker_name: str,
    effects: Index[std.Vector[int, ctx], ctx],
    cleanup_kinds: Index[std.Vector[int, ctx], ctx]
}

type MirNativeResourceFunctionEffect[ctx] struct {
    represented: int,
    name: str,
    first: int,
    second: int,
    count: int,
    return_present: int,
    return_value: int,
    cleanup_kind: int
}

type MirNativeResourceModule[ctx] struct {
    represented: int,
    prefix: str,
    acquire_name: str,
    consume_name: str
}

type MirNativeResourceSyncResult[ctx] struct {
    represented: int,
    invalid: int,
    diagnostic: str,
    bundle: mir.MirProgramBundle[ctx]
}

func mir_native_resource_sync_empty_int_vector(ctx: &Arena) Index[std.Vector[int, ctx], ctx] {
    mut values: std.Vector[int, ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[int, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_native_resource_sync_empty_model(ctx: &Arena) MirNativeResourceSyncModel[ctx] {
    mut model: MirNativeResourceSyncModel[ctx];
    model.represented = 0;
    model.kind = 0;
    model.source_path = std.Clone(ctx, "");
    model.worker_name = std.Clone(ctx, "");
    model.effects = mir_native_resource_sync_empty_int_vector(ctx);
    model.cleanup_kinds = mir_native_resource_sync_empty_int_vector(ctx);
    return model;
}

func mir_native_resource_sync_empty_effect(ctx: &Arena) MirNativeResourceFunctionEffect[ctx] {
    mut effect: MirNativeResourceFunctionEffect[ctx];
    effect.represented = 0;
    effect.name = std.Clone(ctx, "");
    effect.first = 0;
    effect.second = 0;
    effect.count = 0;
    effect.return_present = 0;
    effect.return_value = 0;
    effect.cleanup_kind = 1;
    return effect;
}

func mir_native_resource_sync_empty_module(ctx: &Arena) MirNativeResourceModule[ctx] {
    mut module: MirNativeResourceModule[ctx];
    module.represented = 0;
    module.prefix = std.Clone(ctx, "");
    module.acquire_name = std.Clone(ctx, "");
    module.consume_name = std.Clone(ctx, "");
    return module;
}

func mir_native_resource_sync_empty_result(ctx: &Arena) MirNativeResourceSyncResult[ctx] {
    mut result: MirNativeResourceSyncResult[ctx];
    result.represented = 0;
    result.invalid = 0;
    result.diagnostic = std.Clone(ctx, "");
    result.bundle = mir.mir_make_program_bundle("invalid", ctx);
    return result;
}

func mir_native_resource_sync_append(output: str, value: str, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat(output, value));
}

func mir_native_resource_sync_append_int(output: str, value: int, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat(output, std.FormatInt(value)));
}

func mir_native_resource_sync_expression_path(expression: ast.Expression[ctx], ctx: &Arena) str {
    unsafe {
        if expression.tag == 0 {
            return std.Clone(ctx, expression.Identifier.name);
        }
        if expression.tag == 11 {
            mut left := ctx[expression.Selector.left];
            mut prefix := mir_native_resource_sync_expression_path(left, ctx);
            if len(prefix) == 0 { return std.Clone(ctx, ""); }
            prefix = mir_native_resource_sync_append(prefix, ".", ctx);
            mut selected := mir_native_resource_sync_append(
                prefix, expression.Selector.right, ctx
            );
            return std.Clone(ctx, selected);
        }
    }
    return std.Clone(ctx, "");
}

func mir_native_resource_sync_call_name(expression: ast.Expression[ctx], ctx: &Arena) str {
    unsafe {
        if expression.tag != 12 { return std.Clone(ctx, ""); }
        return mir_native_resource_sync_expression_path(ctx[expression.Call.function], ctx);
    }
}

func mir_native_resource_sync_call_selector(expression: ast.Expression[ctx], ctx: &Arena) str {
    unsafe {
        if expression.tag != 12 { return std.Clone(ctx, ""); }
        mut function := ctx[expression.Call.function];
        if function.tag != 11 { return std.Clone(ctx, ""); }
        return std.Clone(ctx, function.Selector.right);
    }
}

func mir_native_resource_sync_call_literal(expression: ast.Expression[ctx], call_name: str, ctx: &Arena) int {
    unsafe {
        if expression.tag != 12 ||
           std.str_eq(mir_native_resource_sync_call_name(expression, ctx), call_name) == 0
        { return 0 - 1; }
        mut arguments: std.Vector[ast.Expression[ctx], ctx] := ctx[expression.Call.arguments];
        if len(arguments) != 1 || arguments[0].tag != 1 { return 0 - 1; }
        return arguments[0].Integer.val;
    }
}

func mir_native_resource_sync_qualified(prefix: str, name: str, ctx: &Arena) str {
    if len(prefix) == 0 { return std.Clone(ctx, name); }
    mut qualified := mir_native_resource_sync_append(prefix, ".", ctx);
    qualified = mir_native_resource_sync_append(qualified, name, ctx);
    return std.Clone(ctx, qualified);
}

func mir_native_resource_sync_module_analyze(
    program: ast.Program[ctx],
    prefix: str,
    ctx: &Arena
) MirNativeResourceModule[ctx] {
    mut model := mir_native_resource_sync_empty_module(ctx);
    if len(prefix) == 0 { return model; }
    mut statements: std.Vector[ast.Statement[ctx], ctx] := ctx[program.statements];
    mut resource_name := std.Clone(ctx, "");
    mut destructor_name := std.Clone(ctx, "");
    mut index := 0;
    while index < len(statements) {
        mut statement := statements[index];
        unsafe {
            if statement.tag == 1 && statement.StructDecl.is_linear_resource == 1 &&
               statement.StructDecl.is_opaque == 1 && len(resource_name) == 0
            {
                mut fields: std.Vector[ast.FieldDef[ctx], ctx] := ctx[statement.StructDecl.fields];
                if len(fields) != 1 || fields[0].field_type.tag != 0 ||
                   len(statement.StructDecl.declared_destructor_name) == 0
                { return model; }
                resource_name = std.Clone(ctx, statement.StructDecl.name);
                destructor_name = std.Clone(ctx, statement.StructDecl.declared_destructor_name);
            }
        }
        index = index + 1;
    }
    if len(resource_name) == 0 { return model; }

    mut destructor_valid := 0;
    mut acquire_count := 0;
    mut consume_count := 0;
    index = 0;
    while index < len(statements) {
        mut statement := statements[index];
        unsafe {
            if statement.tag == 3 {
                mut parameters: std.Vector[ast.Parameter[ctx], ctx] := ctx[statement.FunctionDecl.params];
                mut return_type := ctx[statement.FunctionDecl.return_type];
                mut body := ctx[statement.FunctionDecl.body];
                mut body_statements: std.Vector[ast.Statement[ctx], ctx] := ctx[body.statements];
                if std.str_eq(statement.FunctionDecl.name, destructor_name) == 1 &&
                   statement.FunctionDecl.is_private == 1 && len(parameters) == 1 &&
                   parameters[0].param_type.tag == 8 && return_type.tag == 3 &&
                   len(body_statements) == 1 && body_statements[0].tag == 13
                {
                    mut expression := ctx[body_statements[0].Expression.expr];
                    if std.str_eq(mir_native_resource_sync_call_name(expression, ctx), "os.LogInt") == 1 {
                        destructor_valid = 1;
                    }
                } else if len(parameters) == 1 && parameters[0].param_type.tag == 0 &&
                          return_type.tag == 8 && len(body_statements) == 3
                {
                    model.acquire_name = std.Clone(ctx, statement.FunctionDecl.name);
                    acquire_count = acquire_count + 1;
                } else if len(parameters) == 1 && parameters[0].param_type.tag == 8 &&
                          return_type.tag == 3 && len(body_statements) == 1 &&
                          body_statements[0].tag == 13
                {
                    mut expression := ctx[body_statements[0].Expression.expr];
                    if std.str_eq(mir_native_resource_sync_call_name(expression, ctx), destructor_name) == 1 {
                        model.consume_name = std.Clone(ctx, statement.FunctionDecl.name);
                        consume_count = consume_count + 1;
                    }
                }
            }
        }
        index = index + 1;
    }
    if destructor_valid == 0 || acquire_count != 1 || consume_count != 1 {
        return mir_native_resource_sync_empty_module(ctx);
    }
    model.represented = 1;
    model.prefix = std.Clone(ctx, prefix);
    return model;
}

func mir_native_resource_sync_effect_from_function(
    statement: ast.Statement[ctx],
    acquire_name: str,
    consume_name: str,
    ctx: &Arena
) MirNativeResourceFunctionEffect[ctx] {
    mut effect := mir_native_resource_sync_empty_effect(ctx);
    unsafe {
        if statement.tag != 3 || std.str_eq(statement.FunctionDecl.name, "main") == 1 {
            return effect;
        }
        effect.name = std.Clone(ctx, statement.FunctionDecl.name);
        mut parameters: std.Vector[ast.Parameter[ctx], ctx] := ctx[statement.FunctionDecl.params];
        if len(parameters) != 0 { return mir_native_resource_sync_empty_effect(ctx); }
        mut body := ctx[statement.FunctionDecl.body];
        mut statements: std.Vector[ast.Statement[ctx], ctx] := ctx[body.statements];

        if len(statements) == 2 && statements[0].tag == 4 && statements[1].tag == 7 {
            mut outer := mir_native_resource_sync_call_literal(ctx[statements[0].VarDecl.value], acquire_name, ctx);
            mut consequence := ctx[statements[1].If.consequence];
            mut nested: std.Vector[ast.Statement[ctx], ctx] := ctx[consequence.statements];
            if outer >= 0 && len(nested) == 1 && nested[0].tag == 4 {
                mut inner := mir_native_resource_sync_call_literal(ctx[nested[0].VarDecl.value], acquire_name, ctx);
                if inner >= 0 {
                    effect.represented = 1; effect.first = inner; effect.second = outer; effect.count = 2;
                    return effect;
                }
            }
        }

        if len(statements) == 3 && statements[0].tag == 4 &&
           statements[1].tag == 5 && statements[2].tag == 5
        {
            mut first := mir_native_resource_sync_call_literal(ctx[statements[1].Assignment.value], acquire_name, ctx);
            mut second := mir_native_resource_sync_call_literal(ctx[statements[2].Assignment.value], acquire_name, ctx);
            if first >= 0 && second >= 0 {
                effect.represented = 1; effect.first = second; effect.second = first; effect.count = 2;
                return effect;
            }
        }

        if len(statements) == 2 && statements[0].tag == 4 && statements[1].tag == 12 {
            mut token := mir_native_resource_sync_call_literal(ctx[statements[0].VarDecl.value], acquire_name, ctx);
            mut returned := ctx[statements[1].Return.expr];
            if token >= 0 && returned.tag == 1 {
                effect.represented = 1; effect.first = token; effect.count = 1;
                effect.return_present = 1; effect.return_value = returned.Integer.val;
                return effect;
            }
        }

        if len(statements) == 2 && statements[0].tag == 4 && statements[1].tag == 11 {
            mut token := mir_native_resource_sync_call_literal(ctx[statements[0].VarDecl.value], acquire_name, ctx);
            mut deferred := ctx[statements[1].Defer.expr];
            if token >= 0 && std.str_eq(mir_native_resource_sync_call_name(deferred, ctx), consume_name) == 1 {
                effect.represented = 1; effect.first = token; effect.count = 1; effect.cleanup_kind = 2;
                return effect;
            }
        }

        if len(statements) == 2 && statements[0].tag == 4 && statements[1].tag == 6 {
            mut loop_body := ctx[statements[1].While.body];
            mut nested: std.Vector[ast.Statement[ctx], ctx] := ctx[loop_body.statements];
            if len(nested) == 2 && nested[0].tag == 4 {
                mut token := mir_native_resource_sync_call_literal(ctx[nested[0].VarDecl.value], acquire_name, ctx);
                if token >= 0 {
                    effect.represented = 1; effect.first = token; effect.count = 1;
                    return effect;
                }
            }
        }

        if len(statements) == 3 && statements[0].tag == 4 &&
           statements[1].tag == 10 && statements[2].tag == 8
        {
            mut choice_name := statements[0].VarDecl.name;
            mut unsafe_body := ctx[statements[1].UnsafeBlock.body];
            mut unsafe_statements: std.Vector[ast.Statement[ctx], ctx] :=
                ctx[unsafe_body.statements];
            mut matched := ctx[statements[2].Match.expression];
            mut cases: std.Vector[ast.MatchCase[ctx], ctx] := ctx[statements[2].Match.cases];
            if len(unsafe_statements) == 1 && unsafe_statements[0].tag == 5 &&
               matched.tag == 0 &&
               std.str_eq(matched.Identifier.name, choice_name) == 1
            {
                mut assigned := unsafe_statements[0];
                mut target := ctx[assigned.Assignment.left];
                mut value := ctx[assigned.Assignment.value];
                mut selected_index := 0 - 1;
                if target.tag == 11 &&
                   std.str_eq(target.Selector.right, "tag") == 1 &&
                   value.tag == 1
                {
                    mut target_base := ctx[target.Selector.left];
                    if target_base.tag == 0 &&
                       std.str_eq(target_base.Identifier.name, choice_name) == 1
                    {
                        selected_index = value.Integer.val;
                    }
                }
                if selected_index < 0 || selected_index >= len(cases) {
                    return mir_native_resource_sync_empty_effect(ctx);
                }
                mut selected_body := ctx[cases[selected_index].body];
                mut selected: std.Vector[ast.Statement[ctx], ctx] := ctx[selected_body.statements];
                if len(selected) == 1 && selected[0].tag == 4 {
                    mut token := mir_native_resource_sync_call_literal(ctx[selected[0].VarDecl.value], acquire_name, ctx);
                    if token >= 0 {
                        effect.represented = 1; effect.first = token; effect.count = 1;
                        return effect;
                    }
                }
            }
        }

        if len(statements) == 2 && statements[0].tag == 4 && statements[1].tag == 13 {
            mut token := mir_native_resource_sync_call_literal(ctx[statements[0].VarDecl.value], acquire_name, ctx);
            mut consumed := ctx[statements[1].Expression.expr];
            if token >= 0 && std.str_eq(mir_native_resource_sync_call_name(consumed, ctx), consume_name) == 1 {
                effect.represented = 1; effect.first = token; effect.count = 1; effect.cleanup_kind = 3;
                return effect;
            }
        }
    }
    return mir_native_resource_sync_empty_effect(ctx);
}

func mir_native_resource_sync_find_effect(
    effects: std.Vector[MirNativeResourceFunctionEffect[ctx], ctx],
    name: str,
    ctx: &Arena
) MirNativeResourceFunctionEffect[ctx] {
    mut index := 0;
    while index < len(effects) {
        if std.str_eq(effects[index].name, name) == 1 { return effects[index]; }
        index = index + 1;
    }
    return mir_native_resource_sync_empty_effect(ctx);
}

func mir_native_resource_sync_push_effect(
    model: MirNativeResourceSyncModel[ctx],
    value: int,
    cleanup_kind: int,
    ctx: &Arena
) MirNativeResourceSyncModel[ctx] {
    mut updated := model;
    mut values: std.Vector[int, ctx] := ctx[updated.effects];
    mut kinds: std.Vector[int, ctx] := ctx[updated.cleanup_kinds];
    values.Push(value);
    kinds.Push(cleanup_kind);
    ctx.Set(updated.effects, values);
    ctx.Set(updated.cleanup_kinds, kinds);
    return updated;
}

func mir_native_resource_sync_resource_analyze(
    programs: std.Vector[ast.Program[ctx], ctx],
    module_paths: std.Vector[str, ctx],
    module_prefixes: std.Vector[str, ctx],
    ctx: &Arena
) MirNativeResourceSyncModel[ctx] {
    mut model := mir_native_resource_sync_empty_model(ctx);
    if len(programs) != 2 || len(module_paths) != 2 || len(module_prefixes) != 2 {
        return model;
    }
    mut entry_index := 0 - 1;
    mut resource_index := 0 - 1;
    mut resource_module := mir_native_resource_sync_empty_module(ctx);
    mut index := 0;
    while index < len(programs) {
        if len(module_prefixes[index]) == 0 {
            entry_index = index;
        } else {
            mut candidate := mir_native_resource_sync_module_analyze(
                programs[index], module_prefixes[index], ctx
            );
            if candidate.represented == 1 {
                resource_index = index;
                resource_module = candidate;
            }
        }
        index = index + 1;
    }
    if entry_index < 0 || resource_index < 0 { return model; }
    mut entry := programs[entry_index];
    mut top_level: std.Vector[ast.Statement[ctx], ctx] := ctx[entry.statements];
    mut resource_alias := std.Clone(ctx, "");
    mut import_count := 0;
    index = 0;
    while index < len(top_level) {
        mut statement := top_level[index];
        unsafe {
            if statement.tag == 0 {
                import_count = import_count + 1;
                resource_alias = std.Clone(ctx, statement.Import.alias);
            }
        }
        index = index + 1;
    }
    if import_count != 1 || len(resource_alias) == 0 {
        return mir_native_resource_sync_empty_model(ctx);
    }
    mut acquire_name := mir_native_resource_sync_qualified(
        resource_alias, resource_module.acquire_name, ctx
    );
    mut consume_name := mir_native_resource_sync_qualified(
        resource_alias, resource_module.consume_name, ctx
    );
    mut effects: std.Vector[MirNativeResourceFunctionEffect[ctx], ctx] := std.VectorNew(ctx);
    mut main_index := 0 - 1;
    index = 0;
    while index < len(top_level) {
        mut statement := top_level[index];
        unsafe {
            if statement.tag == 3 && std.str_eq(statement.FunctionDecl.name, "main") == 1 {
                main_index = index;
            } else if statement.tag == 3 {
                mut effect := mir_native_resource_sync_effect_from_function(
                    statement, acquire_name, consume_name, ctx
                );
                if effect.represented == 0 { return mir_native_resource_sync_empty_model(ctx); }
                effects.Push(effect);
            } else if statement.tag != 0 && statement.tag != 2 {
                return mir_native_resource_sync_empty_model(ctx);
            }
        }
        index = index + 1;
    }
    if main_index < 0 || len(effects) != 7 { return model; }
    unsafe {
        mut main_statement := top_level[main_index];
        mut parameters: std.Vector[ast.Parameter[ctx], ctx] := ctx[main_statement.FunctionDecl.params];
        mut return_type := ctx[main_statement.FunctionDecl.return_type];
        mut body := ctx[main_statement.FunctionDecl.body];
        mut statements: std.Vector[ast.Statement[ctx], ctx] := ctx[body.statements];
        if len(parameters) != 0 || return_type.tag != 0 || len(statements) != 8 ||
           statements[7].tag != 12 || ctx[statements[7].Return.expr].tag != 1 ||
           ctx[statements[7].Return.expr].Integer.val != 0
        { return model; }
        mut call_index := 0;
        while call_index < 7 {
            if statements[call_index].tag != 13 { return mir_native_resource_sync_empty_model(ctx); }
            mut expression := ctx[statements[call_index].Expression.expr];
            mut selected := mir_native_resource_sync_empty_effect(ctx);
            mut logs_return := 0;
            if std.str_eq(mir_native_resource_sync_call_name(expression, ctx), "os.LogInt") == 1 {
                mut arguments: std.Vector[ast.Expression[ctx], ctx] := ctx[expression.Call.arguments];
                if len(arguments) != 1 || arguments[0].tag != 12 {
                    return mir_native_resource_sync_empty_model(ctx);
                }
                selected = mir_native_resource_sync_find_effect(
                    effects, mir_native_resource_sync_call_name(arguments[0], ctx), ctx
                );
                logs_return = 1;
            } else {
                selected = mir_native_resource_sync_find_effect(
                    effects, mir_native_resource_sync_call_name(expression, ctx), ctx
                );
            }
            if selected.represented == 0 { return mir_native_resource_sync_empty_model(ctx); }
            if selected.count >= 1 {
                model = mir_native_resource_sync_push_effect(
                    model, selected.first, selected.cleanup_kind, ctx
                );
            }
            if selected.count == 2 {
                model = mir_native_resource_sync_push_effect(
                    model, selected.second, selected.cleanup_kind, ctx
                );
            }
            if logs_return == 1 {
                if selected.return_present == 0 { return mir_native_resource_sync_empty_model(ctx); }
                model = mir_native_resource_sync_push_effect(
                    model, selected.return_value, 0, ctx
                );
            }
            call_index = call_index + 1;
        }
    }
    mut values: std.Vector[int, ctx] := ctx[model.effects];
    if len(values) != 10 { return mir_native_resource_sync_empty_model(ctx); }
    model.represented = 1;
    model.kind = 1;
    model.source_path = std.Clone(ctx, module_paths[entry_index]);
    return model;
}

func mir_native_resource_sync_threading_analyze(
    programs: std.Vector[ast.Program[ctx], ctx],
    module_paths: std.Vector[str, ctx],
    module_prefixes: std.Vector[str, ctx],
    ctx: &Arena
) MirNativeResourceSyncModel[ctx] {
    mut model := mir_native_resource_sync_empty_model(ctx);
    if len(programs) != 1 || len(module_paths) != 1 || len(module_prefixes) != 1 ||
       len(module_prefixes[0]) != 0
    { return model; }
    mut top_level: std.Vector[ast.Statement[ctx], ctx] := ctx[programs[0].statements];
    mut worker_name := std.Clone(ctx, "");
    mut worker_index := 0 - 1;
    mut main_index := 0 - 1;
    mut struct_count := 0;
    mut function_count := 0;
    mut index := 0;
    while index < len(top_level) {
        mut statement := top_level[index];
        unsafe {
            if statement.tag == 1 {
                struct_count = struct_count + 1;
            } else if statement.tag == 3 {
                function_count = function_count + 1;
                mut parameters: std.Vector[ast.Parameter[ctx], ctx] := ctx[statement.FunctionDecl.params];
                mut return_type := ctx[statement.FunctionDecl.return_type];
                if std.str_eq(statement.FunctionDecl.name, "main") == 1 {
                    main_index = index;
                } else if len(parameters) == 1 && parameters[0].param_type.tag == 9 &&
                          return_type.tag == 3
                {
                    worker_name = std.Clone(ctx, statement.FunctionDecl.name);
                    worker_index = index;
                }
            } else {
                return model;
            }
        }
        index = index + 1;
    }
    if struct_count != 2 || function_count != 2 || main_index < 0 ||
       worker_index < 0 || len(worker_name) == 0
    {
        return model;
    }
    unsafe {
        mut worker_statement := top_level[worker_index];
        mut worker_body := ctx[worker_statement.FunctionDecl.body];
        mut worker_statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[worker_body.statements];
        if len(worker_statements) != 1 || worker_statements[0].tag != 10 {
            return model;
        }
        mut worker_unsafe_body := ctx[worker_statements[0].UnsafeBlock.body];
        mut worker_unsafe_statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[worker_unsafe_body.statements];
        if len(worker_unsafe_statements) != 3 ||
           worker_unsafe_statements[0].tag != 4 ||
           worker_unsafe_statements[1].tag != 5 ||
           worker_unsafe_statements[2].tag != 13 ||
           std.str_eq(
               mir_native_resource_sync_call_selector(
                   ctx[worker_unsafe_statements[0].VarDecl.value], ctx
               ),
               "Lock"
           ) == 0 ||
           std.str_eq(
               mir_native_resource_sync_call_selector(
                   ctx[worker_unsafe_statements[2].Expression.expr], ctx
               ),
               "Unlock"
           ) == 0
        {
            return model;
        }

        mut main_statement := top_level[main_index];
        mut parameters: std.Vector[ast.Parameter[ctx], ctx] := ctx[main_statement.FunctionDecl.params];
        mut return_type := ctx[main_statement.FunctionDecl.return_type];
        mut body := ctx[main_statement.FunctionDecl.body];
        mut statements: std.Vector[ast.Statement[ctx], ctx] := ctx[body.statements];
        if len(parameters) != 0 || return_type.tag != 3 || len(statements) != 11 {
            return model;
        }
        mut arena_name := std.Clone(ctx, "");
        mut argument_name := std.Clone(ctx, "");
        mut saw_free := 0;
        mut saw_mutex := 0;
        mut saw_arena_store := 0;
        mut saw_spawn := 0;
        mut saw_yield := 0;
        mut saw_wait := 0;
        mut saw_log := 0;
        index = 0;
        while index < len(statements) {
            mut statement := statements[index];
            if statement.tag == 4 {
                mut value := ctx[statement.VarDecl.value];
                mut call_name := mir_native_resource_sync_call_name(value, ctx);
                if std.str_eq(call_name, "os.Arena.New") == 1 {
                    arena_name = std.Clone(ctx, statement.VarDecl.name);
                } else if std.str_eq(call_name, "std.MutexNew") == 1 {
                    saw_mutex = saw_mutex + 1;
                } else if std.str_eq(call_name, "os.ArenaAlloc") == 1 {
                    argument_name = std.Clone(ctx, statement.VarDecl.name);
                }
            } else if statement.tag == 11 {
                mut deferred := ctx[statement.Defer.expr];
                if len(arena_name) > 0 && std.str_eq(
                    mir_native_resource_sync_call_name(deferred, ctx),
                    std.Concat(arena_name, ".Free")
                ) == 1 { saw_free = saw_free + 1; }
            } else if statement.tag == 13 {
                mut expression := ctx[statement.Expression.expr];
                mut selector := mir_native_resource_sync_call_selector(expression, ctx);
                if std.str_eq(selector, "Set") == 1 {
                    saw_arena_store = saw_arena_store + 1;
                } else if std.str_eq(selector, "LogInt") == 1 {
                    saw_log = saw_log + 1;
                }
            } else if statement.tag == 10 {
                mut unsafe_body := ctx[statement.UnsafeBlock.body];
                mut nested: std.Vector[ast.Statement[ctx], ctx] :=
                    ctx[unsafe_body.statements];
                if len(nested) == 1 && nested[0].tag == 13 {
                    mut expression := ctx[nested[0].Expression.expr];
                    mut selector := mir_native_resource_sync_call_selector(expression, ctx);
                    if std.str_eq(selector, "Spawn") == 1 {
                    mut arguments: std.Vector[ast.Expression[ctx], ctx] := ctx[expression.Call.arguments];
                    if len(arguments) == 2 && arguments[0].tag == 0 &&
                       std.str_eq(arguments[0].Identifier.name, worker_name) == 1 &&
                       arguments[1].tag == 6
                        {
                            mut addressed := ctx[arguments[1].AddressOf.expr];
                            if addressed.tag == 8 {
                                saw_spawn = saw_spawn + 1;
                            }
                        }
                    }
                }
            } else if statement.tag == 6 {
                mut loop_body := ctx[statement.While.body];
                mut nested: std.Vector[ast.Statement[ctx], ctx] :=
                    ctx[loop_body.statements];
                if len(nested) == 2 && nested[0].tag == 10 && nested[1].tag == 7 {
                    mut wait_unsafe_body := ctx[nested[0].UnsafeBlock.body];
                    mut wait_unsafe: std.Vector[ast.Statement[ctx], ctx] :=
                        ctx[wait_unsafe_body.statements];
                    mut consequence := ctx[nested[1].If.consequence];
                    mut wait_branch: std.Vector[ast.Statement[ctx], ctx] :=
                        ctx[consequence.statements];
                    if len(wait_unsafe) == 3 && wait_unsafe[0].tag == 4 &&
                       wait_unsafe[1].tag == 5 && wait_unsafe[2].tag == 13 &&
                       std.str_eq(
                           mir_native_resource_sync_call_selector(
                               ctx[wait_unsafe[0].VarDecl.value], ctx
                           ),
                           "Lock"
                       ) == 1 &&
                       std.str_eq(
                           mir_native_resource_sync_call_selector(
                               ctx[wait_unsafe[2].Expression.expr], ctx
                           ),
                           "Unlock"
                       ) == 1 &&
                       len(wait_branch) == 1 && wait_branch[0].tag == 13 &&
                       std.str_eq(
                           mir_native_resource_sync_call_selector(
                               ctx[wait_branch[0].Expression.expr], ctx
                           ),
                           "Yield"
                       ) == 1
                    {
                        saw_wait = saw_wait + 1;
                        saw_yield = saw_yield + 1;
                    }
                }
            }
            index = index + 1;
        }
        if len(arena_name) == 0 || saw_free != 1 || saw_mutex != 1 ||
           len(argument_name) == 0 || saw_arena_store != 1 || saw_spawn != 1 ||
           saw_wait != 1 || saw_yield != 1 || saw_log != 1
        { return mir_native_resource_sync_empty_model(ctx); }
    }
    model.represented = 1;
    model.kind = 2;
    model.source_path = std.Clone(ctx, module_paths[0]);
    model.worker_name = std.Clone(ctx, worker_name);
    return model;
}

func mir_native_resource_sync_emit_native_metadata(
    output: str,
    function_index: int,
    metadata_index: int,
    statement_index: int,
    symbol: str,
    source_path: str,
    ctx: &Arena
) str {
    mut prefix := std.Concat("function_", std.FormatInt(function_index));
    prefix = mir_native_resource_sync_append(prefix, "_metadata_", ctx);
    prefix = mir_native_resource_sync_append_int(prefix, metadata_index, ctx);
    mut attachment := std.Concat("statement:entry:", std.FormatInt(statement_index));
    mut updated := mir_native_resource_sync_append(output, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_kind: native_boundary\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_attachment: ", ctx);
    updated = mir_native_resource_sync_append(updated, attachment, ctx);
    updated = mir_native_resource_sync_append(updated, "\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_policy: recognized_preserved\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_contract: phase13_10\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_source_origin: ", ctx);
    updated = mir_native_resource_sync_append(updated, source_path, ctx);
    updated = mir_native_resource_sync_append(updated, "\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_source_line: 1\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_source_column: 1\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_owner: ", ctx);
    updated = mir_native_resource_sync_append(updated, attachment, ctx);
    updated = mir_native_resource_sync_append(updated, "\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_classification: validated_codegen_relevant\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_codegen_semantics: required\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_proof: phase17_runtime_import_is_registry_approved\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_payload: kind=RuntimeCall;symbol=", ctx);
    updated = mir_native_resource_sync_append(updated, symbol, ctx);
    updated = mir_native_resource_sync_append(updated, ";codegen=required;contract=phase21_11\n", ctx);
    return std.Clone(ctx, updated);
}

func mir_native_resource_sync_emit_resource_metadata(
    output: str,
    metadata_index: int,
    statement_index: int,
    value: int,
    cleanup_kind: int,
    source_path: str,
    ctx: &Arena
) str {
    mut prefix := std.Concat("function_0_metadata_", std.FormatInt(metadata_index));
    mut attachment := std.Concat("statement:entry:", std.FormatInt(statement_index));
    mut updated := mir_native_resource_sync_append(output, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_kind: resource\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_attachment: ", ctx);
    updated = mir_native_resource_sync_append(updated, attachment, ctx);
    updated = mir_native_resource_sync_append(updated, "\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_policy: recognized_preserved\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_contract: phase13_10\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_source_origin: ", ctx);
    updated = mir_native_resource_sync_append(updated, source_path, ctx);
    updated = mir_native_resource_sync_append(updated, "\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_source_line: 1\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_source_column: 1\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_owner: ", ctx);
    updated = mir_native_resource_sync_append(updated, attachment, ctx);
    updated = mir_native_resource_sync_append(updated, "\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_classification: validated_preserved\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_codegen_semantics: preserved\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_proof: typechecker_resource_cleanup_plan_materialized_in_cfg_order\n", ctx);
    updated = mir_native_resource_sync_append(updated, prefix, ctx);
    updated = mir_native_resource_sync_append(updated, "_payload: kind=LinearResource;state=Destroyed;token=", ctx);
    updated = mir_native_resource_sync_append_int(updated, value, ctx);
    updated = mir_native_resource_sync_append(updated, ";cleanup_kind=", ctx);
    updated = mir_native_resource_sync_append_int(updated, cleanup_kind, ctx);
    updated = mir_native_resource_sync_append(updated, ";cleanup_required=false;codegen=preserved\n", ctx);
    return std.Clone(ctx, updated);
}

func mir_native_resource_sync_emit_resource(
    model: MirNativeResourceSyncModel[ctx],
    ctx: &Arena
) mir.MirProgramBundle[ctx] {
    mut values: std.Vector[int, ctx] := ctx[model.effects];
    mut kinds: std.Vector[int, ctx] := ctx[model.cleanup_kinds];
    mut cleanup_count := 0;
    mut index := 0;
    while index < len(kinds) {
        if kinds[index] != 0 { cleanup_count = cleanup_count + 1; }
        index = index + 1;
    }
    mut metadata_count := len(values) + cleanup_count;
    mut canonical := "format: gust.compiler_mir_ingestion.v2\nmodule: phase21_resource_source\nimport_count: 1\nimport_0_name: os_LogInt\nimport_0_link_symbol: os_LogInt\nimport_0_linkage: imported_host\nimport_0_parameter_count: 1\nimport_0_parameter_0_type: int\nimport_0_return_type: void\nfunction_count: 1\nfunction_0_linkage: exported_entry\nfunction_0_function: main\nfunction_0_backend_symbol: main\nfunction_0_parameter_count: 0\nfunction_0_return_type: int\nfunction_0_local_count: 0\nfunction_0_entry_block: entry\nfunction_0_block_count: 1\nfunction_0_block_0_label: entry\nfunction_0_block_0_parameter_count: 0\nfunction_0_block_0_statement_count: ";
    canonical = mir_native_resource_sync_append_int(canonical, len(values), ctx);
    canonical = mir_native_resource_sync_append(canonical, "\n", ctx);
    index = 0;
    while index < len(values) {
        mut prefix := std.Concat("function_0_block_0_statement_", std.FormatInt(index));
        canonical = mir_native_resource_sync_append(canonical, prefix, ctx);
        canonical = mir_native_resource_sync_append(canonical, "_kind: CallVoid\n", ctx);
        canonical = mir_native_resource_sync_append(canonical, prefix, ctx);
        canonical = mir_native_resource_sync_append(canonical, "_callee_kind: ImportedFunction\n", ctx);
        canonical = mir_native_resource_sync_append(canonical, prefix, ctx);
        canonical = mir_native_resource_sync_append(canonical, "_callee: os_LogInt\n", ctx);
        canonical = mir_native_resource_sync_append(canonical, prefix, ctx);
        canonical = mir_native_resource_sync_append(canonical, "_argument_count: 1\n", ctx);
        canonical = mir_native_resource_sync_append(canonical, prefix, ctx);
        canonical = mir_native_resource_sync_append(canonical, "_argument_0_kind: I32Literal\n", ctx);
        canonical = mir_native_resource_sync_append(canonical, prefix, ctx);
        canonical = mir_native_resource_sync_append(canonical, "_argument_0_value: ", ctx);
        canonical = mir_native_resource_sync_append_int(canonical, values[index], ctx);
        canonical = mir_native_resource_sync_append(canonical, "\n", ctx);
        index = index + 1;
    }
    canonical = mir_native_resource_sync_append(canonical, "function_0_block_0_terminator_kind: ReturnI32\nfunction_0_block_0_terminator_value: 0\nfunction_0_metadata_count: ", ctx);
    canonical = mir_native_resource_sync_append_int(canonical, metadata_count, ctx);
    canonical = mir_native_resource_sync_append(canonical, "\n", ctx);
    mut metadata_index := 0;
    index = 0;
    while index < len(values) {
        canonical = mir_native_resource_sync_emit_native_metadata(
            canonical, 0, metadata_index, index, "os_LogInt", model.source_path, ctx
        );
        metadata_index = metadata_index + 1;
        if kinds[index] != 0 {
            canonical = mir_native_resource_sync_emit_resource_metadata(
                canonical, metadata_index, index, values[index], kinds[index], model.source_path, ctx
            );
            metadata_index = metadata_index + 1;
        }
        index = index + 1;
    }
    canonical = mir_native_resource_sync_append(canonical, "function_0_expected_exit: 0\n", ctx);
    mut bundle := mir.mir_make_program_bundle("main", ctx);
    mut module := mir.mir_make_program_bundle_module(
        model.source_path, "", "phase21_resource_source.o",
        "gust.compiler_mir_ingestion.v2", canonical,
        cleanup_count, 0, len(values), ctx
    );
    module = mir.mir_program_bundle_module_with_symbol(
        module, mir.mir_make_program_bundle_symbol("main", "main", "()->int", 0, ctx), ctx
    );
    module = mir.mir_program_bundle_module_with_symbol(
        module, mir.mir_make_program_bundle_symbol("os_LogInt", "os_LogInt", "(int)->void", 2, ctx), ctx
    );
    return mir.mir_program_bundle_with_module(bundle, module, ctx);
}

func mir_native_resource_sync_emit_threading(
    model: MirNativeResourceSyncModel[ctx],
    ctx: &Arena
) mir.MirProgramBundle[ctx] {
    mut canonical := "format: gust.compiler_mir_ingestion.v2\nmodule: phase21_threading_source\nimport_count: 11\nimport_0_name: os_Arena_New\nimport_0_link_symbol: os_Arena_New\nimport_0_linkage: imported_host\nimport_0_parameter_count: 0\nimport_0_return_type: arena\nimport_1_name: os_Arena_Free\nimport_1_link_symbol: os_Arena_Free\nimport_1_linkage: imported_host\nimport_1_parameter_count: 1\nimport_1_parameter_0_type: arena\nimport_1_return_type: void\nimport_2_name: os_ArenaAlloc\nimport_2_link_symbol: os_ArenaAlloc\nimport_2_linkage: imported_host\nimport_2_parameter_count: 2\nimport_2_parameter_0_type: arena\nimport_2_parameter_1_type: usize\nimport_2_return_type: int\nimport_3_name: std_Mutex_Alloc\nimport_3_link_symbol: std_Mutex_Alloc\nimport_3_linkage: imported_host\nimport_3_parameter_count: 0\nimport_3_return_type: int\nimport_4_name: std_Mutex_Lock_impl\nimport_4_link_symbol: std_Mutex_Lock_impl\nimport_4_linkage: imported_host\nimport_4_parameter_count: 2\nimport_4_parameter_0_type: int\nimport_4_parameter_1_type: rawptr\nimport_4_return_type: rawptr\nimport_5_name: std_Mutex_Unlock_impl\nimport_5_link_symbol: std_Mutex_Unlock_impl\nimport_5_linkage: imported_host\nimport_5_parameter_count: 1\nimport_5_parameter_0_type: int\nimport_5_return_type: void\nimport_6_name: os_LogInt\nimport_6_link_symbol: os_LogInt\nimport_6_linkage: imported_host\nimport_6_parameter_count: 1\nimport_6_parameter_0_type: int\nimport_6_return_type: void\nimport_7_name: gust_scheduler_init\nimport_7_link_symbol: gust_scheduler_init\nimport_7_linkage: imported_host\nimport_7_parameter_count: 1\nimport_7_parameter_0_type: int\nimport_7_return_type: void\nimport_8_name: gust_scheduler_spawn\nimport_8_link_symbol: gust_scheduler_spawn\nimport_8_linkage: imported_host\nimport_8_parameter_count: 3\nimport_8_parameter_0_type: usize\nimport_8_parameter_1_type: fnptr\nimport_8_parameter_2_type: rawptr\nimport_8_return_type: void\nimport_9_name: gust_yield\nimport_9_link_symbol: gust_yield\nimport_9_linkage: imported_host\nimport_9_parameter_count: 0\nimport_9_return_type: void\nimport_10_name: gust_scheduler_destroy\nimport_10_link_symbol: gust_scheduler_destroy\nimport_10_linkage: imported_host\nimport_10_parameter_count: 0\nimport_10_return_type: void\nfunction_count: 2\nfunction_0_linkage: module_local\nfunction_0_function: phase21_worker\nfunction_0_backend_symbol: phase21_worker\nfunction_0_parameter_count: 1\nfunction_0_parameter_0_type: rawptr\nfunction_0_return_type: void\nfunction_0_local_count: 4\nfunction_0_local_0_name: argument\nfunction_0_local_0_type: rawptr\nfunction_0_local_1_name: mutex\nfunction_0_local_1_type: int\nfunction_0_local_2_name: protected\nfunction_0_local_2_type: rawptr\nfunction_0_local_3_name: value\nfunction_0_local_3_type: int\nfunction_0_entry_block: entry\nfunction_0_block_count: 1\nfunction_0_block_0_label: entry\nfunction_0_block_0_parameter_count: 0\nfunction_0_block_0_statement_count: 7\nfunction_0_block_0_statement_0_kind: LocalRawPointerSetParam\nfunction_0_block_0_statement_0_local: argument\nfunction_0_block_0_statement_0_param: 0\nfunction_0_block_0_statement_1_kind: LocalI32SetRawPointerLoad\nfunction_0_block_0_statement_1_local: mutex\nfunction_0_block_0_statement_1_pointer_local: argument\nfunction_0_block_0_statement_1_byte_offset: 0\nfunction_0_block_0_statement_2_kind: LocalRawPointerSetCall\nfunction_0_block_0_statement_2_local: protected\nfunction_0_block_0_statement_2_callee_kind: ImportedFunction\nfunction_0_block_0_statement_2_callee: std_Mutex_Lock_impl\nfunction_0_block_0_statement_2_argument_count: 2\nfunction_0_block_0_statement_2_argument_0_kind: LocalI32\nfunction_0_block_0_statement_2_argument_0_local: mutex\nfunction_0_block_0_statement_2_argument_1_kind: LocalRawPointerOffset\nfunction_0_block_0_statement_2_argument_1_local: argument\nfunction_0_block_0_statement_2_argument_1_byte_offset: 4\nfunction_0_block_0_statement_3_kind: LocalI32SetRawPointerLoad\nfunction_0_block_0_statement_3_local: value\nfunction_0_block_0_statement_3_pointer_local: protected\nfunction_0_block_0_statement_3_byte_offset: 0\nfunction_0_block_0_statement_4_kind: LocalI32AddI32Literal\nfunction_0_block_0_statement_4_local: value\nfunction_0_block_0_statement_4_value: 1\nfunction_0_block_0_statement_5_kind: RawPointerStoreLocalI32\nfunction_0_block_0_statement_5_pointer_local: protected\nfunction_0_block_0_statement_5_byte_offset: 0\nfunction_0_block_0_statement_5_value_local: value\nfunction_0_block_0_statement_6_kind: CallVoid\nfunction_0_block_0_statement_6_callee_kind: ImportedFunction\nfunction_0_block_0_statement_6_callee: std_Mutex_Unlock_impl\nfunction_0_block_0_statement_6_argument_count: 1\nfunction_0_block_0_statement_6_argument_0_kind: LocalI32\nfunction_0_block_0_statement_6_argument_0_local: mutex\nfunction_0_block_0_terminator_kind: ReturnVoid\nfunction_0_metadata_count: 2\nfunction_0_expected_exit: 0\nfunction_1_linkage: exported_entry\nfunction_1_function: main\nfunction_1_backend_symbol: main\nfunction_1_parameter_count: 0\nfunction_1_return_type: int\nfunction_1_local_count: 4\nfunction_1_local_0_name: ctx\nfunction_1_local_0_type: arena\nfunction_1_local_1_name: argument\nfunction_1_local_1_type: int\nfunction_1_local_2_name: mutex\nfunction_1_local_2_type: int\nfunction_1_local_3_name: observed\nfunction_1_local_3_type: int\nfunction_1_entry_block: entry\nfunction_1_block_count: 1\nfunction_1_block_0_label: entry\nfunction_1_block_0_parameter_count: 0\nfunction_1_block_0_statement_count: 12\nfunction_1_block_0_statement_0_kind: ArenaInit\nfunction_1_block_0_statement_0_local: ctx\nfunction_1_block_0_statement_0_callee_kind: ImportedFunction\nfunction_1_block_0_statement_0_callee: os_Arena_New\nfunction_1_block_0_statement_1_kind: LocalI32SetCall\nfunction_1_block_0_statement_1_local: argument\nfunction_1_block_0_statement_1_callee_kind: ImportedFunction\nfunction_1_block_0_statement_1_callee: os_ArenaAlloc\nfunction_1_block_0_statement_1_argument_count: 2\nfunction_1_block_0_statement_1_argument_0_kind: ArenaAddress\nfunction_1_block_0_statement_1_argument_0_local: ctx\nfunction_1_block_0_statement_1_argument_1_kind: USizeLiteral\nfunction_1_block_0_statement_1_argument_1_value: 8\nfunction_1_block_0_statement_2_kind: LocalI32SetCall\nfunction_1_block_0_statement_2_local: mutex\nfunction_1_block_0_statement_2_callee_kind: ImportedFunction\nfunction_1_block_0_statement_2_callee: std_Mutex_Alloc\nfunction_1_block_0_statement_2_argument_count: 0\nfunction_1_block_0_statement_3_kind: ArenaStoreLocalI32\nfunction_1_block_0_statement_3_arena: ctx\nfunction_1_block_0_statement_3_index_local: argument\nfunction_1_block_0_statement_3_byte_offset: 0\nfunction_1_block_0_statement_3_value_local: mutex\nfunction_1_block_0_statement_4_kind: ArenaStoreI32\nfunction_1_block_0_statement_4_arena: ctx\nfunction_1_block_0_statement_4_index_local: argument\nfunction_1_block_0_statement_4_byte_offset: 4\nfunction_1_block_0_statement_4_value: 0\nfunction_1_block_0_statement_5_kind: CallVoid\nfunction_1_block_0_statement_5_callee_kind: ImportedFunction\nfunction_1_block_0_statement_5_callee: gust_scheduler_init\nfunction_1_block_0_statement_5_argument_count: 1\nfunction_1_block_0_statement_5_argument_0_kind: I32Literal\nfunction_1_block_0_statement_5_argument_0_value: 1\nfunction_1_block_0_statement_6_kind: CallVoid\nfunction_1_block_0_statement_6_callee_kind: ImportedFunction\nfunction_1_block_0_statement_6_callee: gust_scheduler_spawn\nfunction_1_block_0_statement_6_argument_count: 3\nfunction_1_block_0_statement_6_argument_0_kind: USizeLiteral\nfunction_1_block_0_statement_6_argument_0_value: 8388608\nfunction_1_block_0_statement_6_argument_1_kind: FunctionAddress\nfunction_1_block_0_statement_6_argument_1_function: phase21_worker\nfunction_1_block_0_statement_6_argument_2_kind: ArenaAllocationAddress\nfunction_1_block_0_statement_6_argument_2_arena: ctx\nfunction_1_block_0_statement_6_argument_2_index_local: argument\nfunction_1_block_0_statement_6_argument_2_byte_offset: 0\nfunction_1_block_0_statement_6_argument_2_byte_length: 8\nfunction_1_block_0_statement_7_kind: CallVoid\nfunction_1_block_0_statement_7_callee_kind: ImportedFunction\nfunction_1_block_0_statement_7_callee: gust_yield\nfunction_1_block_0_statement_7_argument_count: 0\nfunction_1_block_0_statement_8_kind: CallVoid\nfunction_1_block_0_statement_8_callee_kind: ImportedFunction\nfunction_1_block_0_statement_8_callee: gust_scheduler_destroy\nfunction_1_block_0_statement_8_argument_count: 0\nfunction_1_block_0_statement_9_kind: LocalI32SetArenaLoad\nfunction_1_block_0_statement_9_local: observed\nfunction_1_block_0_statement_9_arena: ctx\nfunction_1_block_0_statement_9_index_local: argument\nfunction_1_block_0_statement_9_byte_offset: 4\nfunction_1_block_0_statement_10_kind: CallVoid\nfunction_1_block_0_statement_10_callee_kind: ImportedFunction\nfunction_1_block_0_statement_10_callee: os_LogInt\nfunction_1_block_0_statement_10_argument_count: 1\nfunction_1_block_0_statement_10_argument_0_kind: LocalI32\nfunction_1_block_0_statement_10_argument_0_local: observed\nfunction_1_block_0_statement_11_kind: CallVoid\nfunction_1_block_0_statement_11_callee_kind: ImportedFunction\nfunction_1_block_0_statement_11_callee: os_Arena_Free\nfunction_1_block_0_statement_11_argument_count: 1\nfunction_1_block_0_statement_11_argument_0_kind: ArenaAddress\nfunction_1_block_0_statement_11_argument_0_local: ctx\nfunction_1_block_0_terminator_kind: ReturnI32\nfunction_1_block_0_terminator_value: 0\nfunction_1_metadata_count: 9\nfunction_1_expected_exit: 0\n";

    canonical = mir_native_resource_sync_emit_native_metadata(
        canonical, 0, 0, 2, "std_Mutex_Lock_impl", model.source_path, ctx
    );
    canonical = mir_native_resource_sync_emit_native_metadata(
        canonical, 0, 1, 6, "std_Mutex_Unlock_impl", model.source_path, ctx
    );
    canonical = mir_native_resource_sync_emit_native_metadata(
        canonical, 1, 0, 0, "os_Arena_New", model.source_path, ctx
    );
    canonical = mir_native_resource_sync_emit_native_metadata(
        canonical, 1, 1, 1, "os_ArenaAlloc", model.source_path, ctx
    );
    canonical = mir_native_resource_sync_emit_native_metadata(
        canonical, 1, 2, 2, "std_Mutex_Alloc", model.source_path, ctx
    );
    canonical = mir_native_resource_sync_emit_native_metadata(
        canonical, 1, 3, 5, "gust_scheduler_init", model.source_path, ctx
    );
    canonical = mir_native_resource_sync_emit_native_metadata(
        canonical, 1, 4, 6, "gust_scheduler_spawn", model.source_path, ctx
    );
    canonical = mir_native_resource_sync_emit_native_metadata(
        canonical, 1, 5, 7, "gust_yield", model.source_path, ctx
    );
    canonical = mir_native_resource_sync_emit_native_metadata(
        canonical, 1, 6, 8, "gust_scheduler_destroy", model.source_path, ctx
    );
    canonical = mir_native_resource_sync_emit_native_metadata(
        canonical, 1, 7, 10, "os_LogInt", model.source_path, ctx
    );
    canonical = mir_native_resource_sync_emit_native_metadata(
        canonical, 1, 8, 11, "os_Arena_Free", model.source_path, ctx
    );

    mut bundle := mir.mir_make_program_bundle("main", ctx);
    mut module := mir.mir_make_program_bundle_module(
        model.source_path, "", "phase21_threading_source.o",
        "gust.compiler_mir_ingestion.v2", canonical, 0, 0, 11, ctx
    );
    module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("phase21_worker", "phase21_worker", "(rawptr)->void", 1, ctx), ctx);
    module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("main", "main", "()->int", 0, ctx), ctx);
    module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("os_Arena_New", "os_Arena_New", "()->arena", 2, ctx), ctx);
    module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("os_Arena_Free", "os_Arena_Free", "(arena)->void", 2, ctx), ctx);
    module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("os_ArenaAlloc", "os_ArenaAlloc", "(arena,usize)->int", 2, ctx), ctx);
    module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("std_Mutex_Alloc", "std_Mutex_Alloc", "()->int", 2, ctx), ctx);
    module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("std_Mutex_Lock_impl", "std_Mutex_Lock_impl", "(int,rawptr)->rawptr", 2, ctx), ctx);
    module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("std_Mutex_Unlock_impl", "std_Mutex_Unlock_impl", "(int)->void", 2, ctx), ctx);
    module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("os_LogInt", "os_LogInt", "(int)->void", 2, ctx), ctx);
    module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("gust_scheduler_init", "gust_scheduler_init", "(int)->void", 2, ctx), ctx);
    module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("gust_scheduler_spawn", "gust_scheduler_spawn", "(usize,fnptr,rawptr)->void", 2, ctx), ctx);
    module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("gust_yield", "gust_yield", "()->void", 2, ctx), ctx);
    module = mir.mir_program_bundle_module_with_symbol(module, mir.mir_make_program_bundle_symbol("gust_scheduler_destroy", "gust_scheduler_destroy", "()->void", 2, ctx), ctx);
    return mir.mir_program_bundle_with_module(bundle, module, ctx);
}

func mir_native_resource_sync_source_lower(
    programs: std.Vector[ast.Program[ctx], ctx],
    module_paths: std.Vector[str, ctx],
    module_prefixes: std.Vector[str, ctx],
    ctx: &Arena
) MirNativeResourceSyncResult[ctx] {
    mut result := mir_native_resource_sync_empty_result(ctx);
    mut resource := mir_native_resource_sync_resource_analyze(
        programs, module_paths, module_prefixes, ctx
    );
    if resource.represented == 1 {
        result.represented = 1;
        result.bundle = mir_native_resource_sync_emit_resource(resource, ctx);
        return result;
    }
    mut threading := mir_native_resource_sync_threading_analyze(
        programs, module_paths, module_prefixes, ctx
    );
    if threading.represented == 1 {
        result.represented = 1;
        result.bundle = mir_native_resource_sync_emit_threading(threading, ctx);
        return result;
    }
    return result;
}
