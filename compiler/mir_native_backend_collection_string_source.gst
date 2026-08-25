import "ast.gst" as ast;
import "mir.gst" as mir;

// Patch 21.9 compiler-side semantic lowering for the bounded collection and
// string source cohort.  This module consumes typed AST operations and emits
// ordinary canonical MIR imports, calls, and CFG.  The Cranelift worker sees no
// source path, stdlib type, fixture name, or raw Gust spelling beyond the
// compiler-owned canonical operation/import records.

type MirNativeCollectionStringEffect[ctx] struct {
    kind: int,
    int_value: int,
    string_value: str
}

type MirNativeCollectionStringIntValue struct {
    represented: int,
    value: int
}

type MirNativeCollectionStringStringValue[ctx] struct {
    represented: int,
    value: str
}

type MirNativeCollectionStringModel[ctx] struct {
    represented: int,
    invalid: int,
    source_path: str,
    condition_value: int,
    before: MirNativeCollectionStringEffect[ctx],
    then_effect: MirNativeCollectionStringEffect[ctx],
    else_effect: MirNativeCollectionStringEffect[ctx],
    after: MirNativeCollectionStringEffect[ctx],
    scheduled_defer: int,
    aggregate_result_call: int,
    enum_match: int,
    string_operation_count: int
}

type MirNativeCollectionStringSourceResult[ctx] struct {
    represented: int,
    invalid: int,
    diagnostic: str,
    bundle: mir.MirProgramBundle[ctx]
}

func mir_native_collection_string_empty_effect(ctx: &Arena) MirNativeCollectionStringEffect[ctx] {
    mut effect: MirNativeCollectionStringEffect[ctx];
    effect.kind = 0;
    effect.int_value = 0;
    effect.string_value = std.Clone(ctx, "");
    return effect;
}

func mir_native_collection_string_unrepresented_int_value() MirNativeCollectionStringIntValue {
    mut result: MirNativeCollectionStringIntValue;
    result.represented = 0;
    result.value = 0;
    return result;
}

func mir_native_collection_string_represented_int_value(value: int) MirNativeCollectionStringIntValue {
    mut result := mir_native_collection_string_unrepresented_int_value();
    result.represented = 1;
    result.value = value;
    return result;
}

func mir_native_collection_string_unrepresented_string_value(ctx: &Arena) MirNativeCollectionStringStringValue[ctx] {
    mut result: MirNativeCollectionStringStringValue[ctx];
    result.represented = 0;
    result.value = std.Clone(ctx, "");
    return result;
}

func mir_native_collection_string_represented_string_value(value: str, ctx: &Arena) MirNativeCollectionStringStringValue[ctx] {
    mut result := mir_native_collection_string_unrepresented_string_value(ctx);
    result.represented = 1;
    result.value = std.Clone(ctx, value);
    return result;
}

func mir_native_collection_string_int_effect(value: int, ctx: &Arena) MirNativeCollectionStringEffect[ctx] {
    mut effect := mir_native_collection_string_empty_effect(ctx);
    effect.kind = 1;
    effect.int_value = value;
    return effect;
}

func mir_native_collection_string_str_effect(value: str, ctx: &Arena) MirNativeCollectionStringEffect[ctx] {
    mut effect := mir_native_collection_string_empty_effect(ctx);
    effect.kind = 2;
    effect.string_value = std.Clone(ctx, value);
    return effect;
}

func mir_native_collection_string_empty_model(ctx: &Arena) MirNativeCollectionStringModel[ctx] {
    mut model: MirNativeCollectionStringModel[ctx];
    model.represented = 0;
    model.invalid = 0;
    model.source_path = std.Clone(ctx, "");
    model.condition_value = 0;
    model.before = mir_native_collection_string_empty_effect(ctx);
    model.then_effect = mir_native_collection_string_empty_effect(ctx);
    model.else_effect = mir_native_collection_string_empty_effect(ctx);
    model.after = mir_native_collection_string_empty_effect(ctx);
    model.scheduled_defer = 0;
    model.aggregate_result_call = 0;
    model.enum_match = 0;
    model.string_operation_count = 0;
    return model;
}

func mir_native_collection_string_empty_result(ctx: &Arena) MirNativeCollectionStringSourceResult[ctx] {
    mut result: MirNativeCollectionStringSourceResult[ctx];
    result.represented = 0;
    result.invalid = 0;
    result.diagnostic = std.Clone(ctx, "");
    result.bundle = mir.mir_make_program_bundle("invalid", ctx);
    return result;
}

func mir_native_collection_string_append(output: str, value: str, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat(output, value));
}

func mir_native_collection_string_append_int(output: str, value: int, ctx: &Arena) str {
    mut formatted := std.FormatInt(value);
    return std.Clone(ctx, std.Concat(output, formatted));
}

func mir_native_collection_string_hex_digit(value: int, ctx: &Arena) str {
    mut digits := "0123456789abcdef";
    return std.Clone(ctx, std.str_slice(digits, value, value + 1));
}

func mir_native_collection_string_hex_encode(value: str, ctx: &Arena) str {
    mut encoded := std.Clone(ctx, "");
    mut index := 0;
    while index < len(value) {
        mut byte_value := std.str_byte_at(value, index);
        mut high := byte_value / 16;
        mut low := byte_value - high * 16;
        encoded = mir_native_collection_string_append(
            encoded, mir_native_collection_string_hex_digit(high, ctx), ctx
        );
        encoded = mir_native_collection_string_append(
            encoded, mir_native_collection_string_hex_digit(low, ctx), ctx
        );
        index = index + 1;
    }
    return std.Clone(ctx, encoded);
}

func mir_native_collection_string_expression_path(expression: ast.Expression[ctx], ctx: &Arena) str {
    unsafe {
        if expression.tag == 0 {
            return std.Clone(ctx, expression.Identifier.name);
        }
        if expression.tag == 11 {
            mut left := ctx[expression.Selector.left];
            mut path := mir_native_collection_string_expression_path(left, ctx);
            if len(path) == 0 {
                return std.Clone(ctx, "");
            }
            path = mir_native_collection_string_append(path, ".", ctx);
            mut selected := mir_native_collection_string_append(
                path,
                expression.Selector.right,
                ctx
            );
            return std.Clone(ctx, selected);
        }
    }
    return std.Clone(ctx, "");
}

func mir_native_collection_string_call_name(expression: ast.Expression[ctx], ctx: &Arena) str {
    unsafe {
        if expression.tag != 12 {
            return std.Clone(ctx, "");
        }
        mut function := ctx[expression.Call.function];
        mut name := mir_native_collection_string_expression_path(function, ctx);
        return std.Clone(ctx, name);
    }
}

func mir_native_collection_string_find_name(names: std.Vector[str, ctx], name: str, ctx: &Arena) int {
    mut index := 0;
    while index < len(names) {
        if std.str_eq(names[index], name) == 1 {
            return index;
        }
        index = index + 1;
    }
    return 0 - 1;
}

func mir_native_collection_string_identifier_is(
    expression: ast.Expression[ctx],
    name: str
) int {
    unsafe {
        if expression.tag == 0 &&
           std.str_eq(expression.Identifier.name, name) == 1
        {
            return 1;
        }
    }
    return 0;
}

func mir_native_collection_string_known_string_operand(
    expression: ast.Expression[ctx],
    names: std.Vector[str, ctx],
    ctx: &Arena
) int {
    unsafe {
        if expression.tag == 2 {
            return 1;
        }
        if expression.tag == 0 &&
           mir_native_collection_string_find_name(
               names, expression.Identifier.name, ctx
           ) >= 0
        {
            return 1;
        }
    }
    return 0;
}

func mir_native_collection_string_string_value(
    expression: ast.Expression[ctx],
    names: std.Vector[str, ctx],
    values: std.Vector[str, ctx],
    ctx: &Arena
) MirNativeCollectionStringStringValue[ctx] {
    unsafe {
        if expression.tag == 2 {
            return mir_native_collection_string_represented_string_value(
                expression.String.val, ctx
            );
        }
        if expression.tag == 0 {
            mut index := mir_native_collection_string_find_name(
                names,
                expression.Identifier.name,
                ctx
            );
            if index >= 0 {
                return mir_native_collection_string_represented_string_value(
                    values[index], ctx
                );
            }
            return mir_native_collection_string_unrepresented_string_value(ctx);
        }
        if expression.tag == 12 &&
           std.str_eq(
               mir_native_collection_string_call_name(expression, ctx),
               "std.str_slice"
           ) == 1
        {
            mut arguments: std.Vector[ast.Expression[ctx], ctx] :=
                ctx[expression.Call.arguments];
            if len(arguments) != 3 || arguments[1].tag != 1 || arguments[2].tag != 1 {
                return mir_native_collection_string_unrepresented_string_value(ctx);
            }
            mut source := mir_native_collection_string_string_value(
                arguments[0], names, values, ctx
            );
            if source.represented == 0 {
                return mir_native_collection_string_unrepresented_string_value(ctx);
            }
            mut start := arguments[1].Integer.val;
            mut end := arguments[2].Integer.val;
            if start < 0 || end < start || end > len(source.value) {
                return mir_native_collection_string_unrepresented_string_value(ctx);
            }
            return mir_native_collection_string_represented_string_value(
                std.str_slice(source.value, start, end), ctx
            );
        }
    }
    return mir_native_collection_string_unrepresented_string_value(ctx);
}

func mir_native_collection_string_int_value(
    expression: ast.Expression[ctx],
    string_names: std.Vector[str, ctx],
    string_values: std.Vector[str, ctx],
    binding_name: str,
    binding_value: int,
    ctx: &Arena
) MirNativeCollectionStringIntValue {
    unsafe {
        if expression.tag == 1 {
            return mir_native_collection_string_represented_int_value(
                expression.Integer.val
            );
        }
        if expression.tag == 0 && len(binding_name) > 0 &&
           std.str_eq(expression.Identifier.name, binding_name) == 1
        {
            return mir_native_collection_string_represented_int_value(binding_value);
        }
        if expression.tag == 7 {
            mut inner := ctx[expression.Dereference.expr];
            return mir_native_collection_string_int_value(
                inner,
                string_names,
                string_values,
                binding_name,
                binding_value,
                ctx
            );
        }
        if expression.tag == 9 {
            mut inner := ctx[expression.AsCast.left];
            return mir_native_collection_string_int_value(
                inner,
                string_names,
                string_values,
                binding_name,
                binding_value,
                ctx
            );
        }
        if expression.tag == 12 {
            mut name := mir_native_collection_string_call_name(expression, ctx);
            mut arguments: std.Vector[ast.Expression[ctx], ctx] :=
                ctx[expression.Call.arguments];
            if std.str_eq(name, "std.str_eq") == 1 && len(arguments) == 2 {
                mut left := mir_native_collection_string_string_value(
                    arguments[0], string_names, string_values, ctx
                );
                mut right := mir_native_collection_string_string_value(
                    arguments[1], string_names, string_values, ctx
                );
                if left.represented == 1 && right.represented == 1 {
                    return mir_native_collection_string_represented_int_value(
                        std.str_eq(left.value, right.value)
                    );
                }
            }
            if std.str_eq(name, "std.str_byte_at") == 1 &&
               len(arguments) == 2 && arguments[1].tag == 1
            {
                mut source := mir_native_collection_string_string_value(
                    arguments[0], string_names, string_values, ctx
                );
                mut index := arguments[1].Integer.val;
                if source.represented == 1 &&
                   index >= 0 && index < len(source.value)
                {
                    return mir_native_collection_string_represented_int_value(
                        std.str_byte_at(source.value, index)
                    );
                }
            }
        }
    }
    return mir_native_collection_string_unrepresented_int_value();
}

func mir_native_collection_string_effect_from_expression(
    expression: ast.Expression[ctx],
    string_names: std.Vector[str, ctx],
    string_values: std.Vector[str, ctx],
    binding_name: str,
    binding_value: int,
    ctx: &Arena
) MirNativeCollectionStringEffect[ctx] {
    unsafe {
        if expression.tag != 12 {
            return mir_native_collection_string_empty_effect(ctx);
        }
        mut name := mir_native_collection_string_call_name(expression, ctx);
        mut arguments: std.Vector[ast.Expression[ctx], ctx] :=
            ctx[expression.Call.arguments];
        if len(arguments) != 1 {
            return mir_native_collection_string_empty_effect(ctx);
        }
        if std.str_eq(name, "os.LogInt") == 1 {
            mut value := mir_native_collection_string_int_value(
                arguments[0], string_names, string_values,
                binding_name, binding_value, ctx
            );
            if value.represented == 0 {
                return mir_native_collection_string_empty_effect(ctx);
            }
            return mir_native_collection_string_int_effect(
                value.value,
                ctx
            );
        }
        if std.str_eq(name, "os.LogStr") == 1 {
            mut value := mir_native_collection_string_string_value(
                arguments[0], string_names, string_values, ctx
            );
            if value.represented == 0 {
                return mir_native_collection_string_empty_effect(ctx);
            }
            return mir_native_collection_string_str_effect(value.value, ctx);
        }
    }
    return mir_native_collection_string_empty_effect(ctx);
}

func mir_native_collection_string_effect_from_statements(
    statements: std.Vector[ast.Statement[ctx], ctx],
    string_names: std.Vector[str, ctx],
    string_values: std.Vector[str, ctx],
    binding_name: str,
    binding_value: int,
    ctx: &Arena
) MirNativeCollectionStringEffect[ctx] {
    if len(statements) != 1 {
        return mir_native_collection_string_empty_effect(ctx);
    }
    mut statement := statements[0];
    unsafe {
        if statement.tag == 13 {
            mut expression := ctx[statement.Expression.expr];
            return mir_native_collection_string_effect_from_expression(
                expression, string_names, string_values,
                binding_name, binding_value, ctx
            );
        }
        if statement.tag == 10 {
            mut body := ctx[statement.UnsafeBlock.body];
            mut nested: std.Vector[ast.Statement[ctx], ctx] := ctx[body.statements];
            return mir_native_collection_string_effect_from_statements(
                nested, string_names, string_values,
                binding_name, binding_value, ctx
            );
        }
    }
    return mir_native_collection_string_empty_effect(ctx);
}

func mir_native_collection_string_analyze_collections(
    statements: std.Vector[ast.Statement[ctx], ctx],
    source_path: str,
    ctx: &Arena
) MirNativeCollectionStringModel[ctx] {
    mut model := mir_native_collection_string_empty_model(ctx);
    model.source_path = std.Clone(ctx, source_path);
    mut arena_name := std.Clone(ctx, "");
    mut vector_name := std.Clone(ctx, "");
    mut vector_values: std.Vector[int, ctx] := std.VectorNew(ctx);
    mut option_name := std.Clone(ctx, "");
    mut option_found := 0;
    mut option_value := 0;
    mut recognized_statement_count := 0;
    mut push_count := 0;
    mut set_thread_scratch_count := 0;
    mut string_names: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut string_values: std.Vector[str, ctx] := std.VectorNew(ctx);

    mut index := 0;
    while index < len(statements) {
        mut statement := statements[index];
        mut statement_recognized := 0;
        unsafe {
            if statement.tag == 11 {
                mut expression := ctx[statement.Defer.expr];
                if len(arena_name) > 0 &&
                   std.str_eq(
                       mir_native_collection_string_call_name(expression, ctx),
                       std.Concat(arena_name, ".Free")
                   ) == 1
                {
                    model.scheduled_defer = 1;
                    statement_recognized = 1;
                }
            }
            if statement.tag == 4 {
                mut value := ctx[statement.VarDecl.value];
                mut call_name := mir_native_collection_string_call_name(value, ctx);
                mut arguments: std.Vector[ast.Expression[ctx], ctx] :=
                    std.VectorNew(ctx);
                if value.tag == 12 {
                    arguments = ctx[value.Call.arguments];
                }
                if std.str_eq(call_name, "os.Arena.New") == 1 &&
                   len(arguments) == 0 && len(arena_name) == 0
                {
                    arena_name = std.Clone(ctx, statement.VarDecl.name);
                    statement_recognized = 1;
                } else if std.str_eq(call_name, "std.VectorNew") == 1 &&
                          len(arguments) == 1 && len(arena_name) > 0 &&
                          mir_native_collection_string_identifier_is(
                              arguments[0], arena_name
                          ) == 1 && len(vector_name) == 0
                {
                    vector_name = std.Clone(ctx, statement.VarDecl.name);
                    statement_recognized = 1;
                } else if len(vector_name) > 0 &&
                          std.str_eq(call_name, std.Concat(vector_name, ".get_opt")) == 1
                {
                    if len(arguments) == 1 && arguments[0].tag == 1 &&
                       len(option_name) == 0
                    {
                        mut selected := arguments[0].Integer.val;
                        option_name = std.Clone(ctx, statement.VarDecl.name);
                        if selected >= 0 && selected < len(vector_values) {
                            option_found = 1;
                            option_value = vector_values[selected];
                        }
                        model.aggregate_result_call = 1;
                        statement_recognized = 1;
                    }
                }
            }
            if statement.tag == 13 {
                mut expression := ctx[statement.Expression.expr];
                mut call_name := mir_native_collection_string_call_name(
                    expression, ctx
                );
                mut arguments: std.Vector[ast.Expression[ctx], ctx] :=
                    std.VectorNew(ctx);
                if expression.tag == 12 {
                    arguments = ctx[expression.Call.arguments];
                }
                if std.str_eq(call_name, "os.SetThreadScratch") == 1 &&
                   len(arguments) == 1 && len(arena_name) > 0 &&
                   mir_native_collection_string_identifier_is(
                       arguments[0], arena_name
                   ) == 1
                {
                    set_thread_scratch_count = set_thread_scratch_count + 1;
                    statement_recognized = 1;
                } else if expression.tag == 12 && len(vector_name) > 0 &&
                   std.str_eq(
                       call_name,
                       std.Concat(vector_name, ".Push")
                   ) == 1
                {
                    if len(arguments) == 1 && arguments[0].tag == 1 {
                        vector_values.Push(arguments[0].Integer.val);
                        push_count = push_count + 1;
                        statement_recognized = 1;
                    }
                }
            }
            if statement.tag == 8 && len(option_name) > 0 &&
               model.enum_match == 0
            {
                mut match_expression := ctx[statement.Match.expression];
                if match_expression.tag == 0 &&
                   std.str_eq(match_expression.Identifier.name, option_name) == 1
                {
                    mut cases: std.Vector[ast.MatchCase[ctx], ctx] := ctx[statement.Match.cases];
                    mut some_count := 0;
                    mut none_count := 0;
                    mut case_index := 0;
                    while case_index < len(cases) {
                        mut match_case := cases[case_index];
                        mut body := ctx[match_case.body];
                        mut body_statements: std.Vector[ast.Statement[ctx], ctx] := ctx[body.statements];
                        if std.str_eq(match_case.variant_name, "Some") == 1 {
                            mut fields: std.Vector[str, ctx] := ctx[match_case.fields];
                            mut binding := std.Clone(ctx, "");
                            if len(fields) == 1 { binding = fields[0]; }
                            model.then_effect = mir_native_collection_string_effect_from_statements(
                                body_statements, string_names, string_values,
                                binding, option_value, ctx
                            );
                            if len(fields) == 1 && model.then_effect.kind != 0 {
                                some_count = some_count + 1;
                            }
                        } else if std.str_eq(match_case.variant_name, "None") == 1 {
                            mut fields: std.Vector[str, ctx] := ctx[match_case.fields];
                            model.else_effect = mir_native_collection_string_effect_from_statements(
                                body_statements, string_names, string_values,
                                "", 0, ctx
                            );
                            if len(fields) == 0 && model.else_effect.kind != 0 {
                                none_count = none_count + 1;
                            }
                        }
                        case_index = case_index + 1;
                    }
                    if len(cases) == 2 && some_count == 1 && none_count == 1 {
                        model.enum_match = 1;
                        model.condition_value = option_found;
                        statement_recognized = 1;
                    }
                }
            }
        }
        recognized_statement_count = recognized_statement_count + statement_recognized;
        index = index + 1;
    }

    if recognized_statement_count == len(statements) && len(arena_name) > 0 &&
       len(vector_name) > 0 && push_count > 0 &&
       set_thread_scratch_count == 1 && model.aggregate_result_call == 1 &&
       model.enum_match == 1 && model.scheduled_defer == 1 &&
       model.then_effect.kind != 0 && model.else_effect.kind != 0
    {
        model.represented = 1;
    }
    return model;
}

func mir_native_collection_string_analyze_strings(
    statements: std.Vector[ast.Statement[ctx], ctx],
    source_path: str,
    ctx: &Arena
) MirNativeCollectionStringModel[ctx] {
    mut model := mir_native_collection_string_empty_model(ctx);
    model.source_path = std.Clone(ctx, source_path);
    mut string_names: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut string_values: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut saw_branch := 0;
    mut recognized_statement_count := 0;

    mut index := 0;
    while index < len(statements) {
        mut statement := statements[index];
        mut statement_recognized := 0;
        unsafe {
            if statement.tag == 4 {
                mut value := ctx[statement.VarDecl.value];
                mut resolved := mir_native_collection_string_string_value(
                    value, string_names, string_values, ctx
                );
                if resolved.represented == 1 && (value.tag == 2 ||
                   std.str_eq(
                       mir_native_collection_string_call_name(value, ctx),
                       "std.str_slice"
                   ) == 1)
                {
                    mut value_represented := 0;
                    if value.tag == 2 {
                        value_represented = 1;
                    }
                    if value.tag == 12 {
                        mut arguments: std.Vector[ast.Expression[ctx], ctx] :=
                            ctx[value.Call.arguments];
                        if len(arguments) == 3 &&
                           mir_native_collection_string_known_string_operand(
                               arguments[0], string_names, ctx
                           ) == 1 && arguments[1].tag == 1 &&
                           arguments[2].tag == 1
                        {
                            mut source_value :=
                                mir_native_collection_string_string_value(
                                    arguments[0], string_names,
                                    string_values, ctx
                                );
                            mut start := arguments[1].Integer.val;
                            mut end := arguments[2].Integer.val;
                            if source_value.represented == 1 &&
                               start >= 0 && end >= start &&
                               end <= len(source_value.value)
                            {
                                value_represented = 1;
                            }
                        }
                    }
                    if value_represented {
                        string_names.Push(std.Clone(ctx, statement.VarDecl.name));
                        string_values.Push(std.Clone(ctx, resolved.value));
                        statement_recognized = 1;
                        if value.tag == 12 {
                            model.string_operation_count = model.string_operation_count + 1;
                        }
                    }
                }
            }
            if statement.tag == 13 {
                mut expression := ctx[statement.Expression.expr];
                mut effect := mir_native_collection_string_effect_from_expression(
                    expression, string_names, string_values, "", 0, ctx
                );
                if effect.kind != 0 {
                    if saw_branch == 0 && model.before.kind == 0 {
                        if effect.kind == 2 {
                            model.before = effect;
                            statement_recognized = 1;
                        }
                    } else if saw_branch == 1 && model.after.kind == 0 &&
                              expression.tag == 12
                    {
                        mut arguments: std.Vector[ast.Expression[ctx], ctx] :=
                            ctx[expression.Call.arguments];
                        if effect.kind == 1 && len(arguments) == 1 &&
                           arguments[0].tag == 9
                        {
                            mut cast_inner := ctx[arguments[0].AsCast.left];
                            mut cast_target := ctx[arguments[0].AsCast.target_type];
                            mut byte_arguments: std.Vector[ast.Expression[ctx], ctx] :=
                                std.VectorNew(ctx);
                            if cast_inner.tag == 12 {
                                byte_arguments = ctx[cast_inner.Call.arguments];
                            }
                            if std.str_eq(
                                mir_native_collection_string_call_name(
                                    cast_inner, ctx
                                ),
                                "std.str_byte_at"
                            ) == 1 && cast_target.tag == 0 &&
                               arguments[0].AsCast.is_reference == 0 &&
                               len(byte_arguments) == 2 &&
                               mir_native_collection_string_known_string_operand(
                                   byte_arguments[0], string_names, ctx
                               ) == 1 && byte_arguments[1].tag == 1
                            {
                                mut byte_source :=
                                    mir_native_collection_string_string_value(
                                        byte_arguments[0], string_names,
                                        string_values, ctx
                                    );
                                mut byte_index := byte_arguments[1].Integer.val;
                                if byte_source.represented == 1 &&
                                   byte_index >= 0 &&
                                   byte_index < len(byte_source.value)
                                {
                                    model.after = effect;
                                    model.string_operation_count =
                                        model.string_operation_count + 1;
                                    statement_recognized = 1;
                                }
                            }
                        }
                    }
                }
            }
            if statement.tag == 7 && saw_branch == 0 {
                mut condition := ctx[statement.If.condition];
                mut condition_arguments: std.Vector[ast.Expression[ctx], ctx] :=
                    std.VectorNew(ctx);
                if condition.tag == 12 {
                    condition_arguments = ctx[condition.Call.arguments];
                }
                if std.str_eq(
                    mir_native_collection_string_call_name(condition, ctx),
                    "std.str_eq"
                ) == 1 && len(condition_arguments) == 2 &&
                   mir_native_collection_string_known_string_operand(
                       condition_arguments[0], string_names, ctx
                   ) == 1 &&
                   mir_native_collection_string_known_string_operand(
                       condition_arguments[1], string_names, ctx
                   ) == 1 &&
                   statement.If.alternative != empty[Index[ast.BlockStatement[ctx], ctx]]
                {
                    mut condition_value := mir_native_collection_string_int_value(
                        condition, string_names, string_values, "", 0, ctx
                    );
                    if condition_value.represented == 0 {
                        index = index + 1;
                        continue;
                    }
                    model.condition_value = condition_value.value;
                    mut consequence := ctx[statement.If.consequence];
                    mut then_statements: std.Vector[ast.Statement[ctx], ctx] :=
                        ctx[consequence.statements];
                    model.then_effect = mir_native_collection_string_effect_from_statements(
                        then_statements, string_names, string_values, "", 0, ctx
                    );
                    mut alternative := ctx[statement.If.alternative];
                    mut else_statements: std.Vector[ast.Statement[ctx], ctx] :=
                        ctx[alternative.statements];
                    model.else_effect = mir_native_collection_string_effect_from_statements(
                        else_statements, string_names, string_values, "", 0, ctx
                    );
                    if model.then_effect.kind == 1 &&
                       model.else_effect.kind == 1
                    {
                        model.string_operation_count =
                            model.string_operation_count + 1;
                        saw_branch = 1;
                        statement_recognized = 1;
                    }
                }
            }
        }
        recognized_statement_count = recognized_statement_count + statement_recognized;
        index = index + 1;
    }

    if recognized_statement_count == len(statements) &&
       saw_branch == 1 && model.before.kind == 2 &&
       model.then_effect.kind == 1 && model.else_effect.kind == 1 &&
       model.after.kind == 1 && model.string_operation_count >= 3
    {
        model.represented = 1;
    }
    return model;
}

func mir_native_collection_string_effect_symbol(effect: MirNativeCollectionStringEffect[ctx]) str {
    if effect.kind == 1 { return "os_LogInt"; }
    return "os_LogStr";
}

func mir_native_collection_string_emit_effect(
    output: str,
    prefix: str,
    effect: MirNativeCollectionStringEffect[ctx],
    ctx: &Arena
) str {
    mut updated := mir_native_collection_string_append(output, prefix, ctx);
    updated = mir_native_collection_string_append(updated, "_kind: CallVoid\n", ctx);
    updated = mir_native_collection_string_append(updated, prefix, ctx);
    updated = mir_native_collection_string_append(updated, "_callee_kind: ImportedFunction\n", ctx);
    updated = mir_native_collection_string_append(updated, prefix, ctx);
    updated = mir_native_collection_string_append(updated, "_callee: ", ctx);
    updated = mir_native_collection_string_append(
        updated, mir_native_collection_string_effect_symbol(effect), ctx
    );
    updated = mir_native_collection_string_append(updated, "\n", ctx);
    updated = mir_native_collection_string_append(updated, prefix, ctx);
    updated = mir_native_collection_string_append(updated, "_argument_count: 1\n", ctx);
    updated = mir_native_collection_string_append(updated, prefix, ctx);
    if effect.kind == 1 {
        updated = mir_native_collection_string_append(updated, "_argument_0_kind: I32Literal\n", ctx);
        updated = mir_native_collection_string_append(updated, prefix, ctx);
        updated = mir_native_collection_string_append(updated, "_argument_0_value: ", ctx);
        updated = mir_native_collection_string_append_int(updated, effect.int_value, ctx);
    } else {
        updated = mir_native_collection_string_append(updated, "_argument_0_kind: StringLiteralUtf8Hex\n", ctx);
        updated = mir_native_collection_string_append(updated, prefix, ctx);
        updated = mir_native_collection_string_append(updated, "_argument_0_value: ", ctx);
        updated = mir_native_collection_string_append(
            updated,
            mir_native_collection_string_hex_encode(effect.string_value, ctx),
            ctx
        );
    }
    updated = mir_native_collection_string_append(updated, "\n", ctx);
    return std.Clone(ctx, updated);
}

func mir_native_collection_string_emit_metadata(
    output: str,
    index: int,
    attachment: str,
    effect: MirNativeCollectionStringEffect[ctx],
    origin: str,
    ctx: &Arena
) str {
    mut updated := mir_native_collection_string_append(output, "function_0_metadata_", ctx);
    updated = mir_native_collection_string_append_int(updated, index, ctx);
    updated = mir_native_collection_string_append(updated, "_kind: native_boundary\nfunction_0_metadata_", ctx);
    updated = mir_native_collection_string_append_int(updated, index, ctx);
    updated = mir_native_collection_string_append(updated, "_attachment: ", ctx);
    updated = mir_native_collection_string_append(updated, attachment, ctx);
    updated = mir_native_collection_string_append(updated, "\nfunction_0_metadata_", ctx);
    updated = mir_native_collection_string_append_int(updated, index, ctx);
    updated = mir_native_collection_string_append(updated, "_policy: ignored_with_proof\nfunction_0_metadata_", ctx);
    updated = mir_native_collection_string_append_int(updated, index, ctx);
    updated = mir_native_collection_string_append(updated, "_payload: kind=RuntimeCall;symbol=", ctx);
    updated = mir_native_collection_string_append(
        updated, mir_native_collection_string_effect_symbol(effect), ctx
    );
    updated = mir_native_collection_string_append(
        updated,
        ";codegen=none;proof=runtime_boundary_classification_is_registry_validated;contract=phase21_9;origin=",
        ctx
    );
    updated = mir_native_collection_string_append(updated, origin, ctx);
    updated = mir_native_collection_string_append(updated, "\n", ctx);
    return std.Clone(ctx, updated);
}

func mir_native_collection_string_emit_bundle(
    model: MirNativeCollectionStringModel[ctx],
    ctx: &Arena
) mir.MirProgramBundle[ctx] {
    mut canonical := "format: gust.compiler_mir_ingestion.v2\nmodule: phase21_collection_string_source\nimport_count: 2\n";
    canonical = mir_native_collection_string_append(canonical, "import_0_name: os_LogInt\nimport_0_link_symbol: os_LogInt\nimport_0_linkage: imported_host\nimport_0_parameter_count: 1\nimport_0_parameter_0_type: int\nimport_0_return_type: void\n", ctx);
    canonical = mir_native_collection_string_append(canonical, "import_1_name: os_LogStr\nimport_1_link_symbol: os_LogStr\nimport_1_linkage: imported_host\nimport_1_parameter_count: 1\nimport_1_parameter_0_type: str\nimport_1_return_type: void\n", ctx);
    canonical = mir_native_collection_string_append(canonical, "function_count: 1\nfunction_0_linkage: exported_entry\nfunction_0_function: main\nfunction_0_backend_symbol: main\nfunction_0_parameter_count: 0\nfunction_0_return_type: int\nfunction_0_local_count: 1\nfunction_0_local_0_name: condition\nfunction_0_local_0_type: int\nfunction_0_entry_block: entry\nfunction_0_block_count: 4\nfunction_0_block_0_label: entry\nfunction_0_block_0_parameter_count: 0\nfunction_0_block_0_statement_count: ", ctx);
    mut entry_count := 1;
    if model.before.kind != 0 { entry_count = entry_count + 1; }
    canonical = mir_native_collection_string_append_int(canonical, entry_count, ctx);
    canonical = mir_native_collection_string_append(canonical, "\n", ctx);
    mut condition_statement_index := 0;
    if model.before.kind != 0 {
        canonical = mir_native_collection_string_emit_effect(
            canonical, "function_0_block_0_statement_0", model.before, ctx
        );
        condition_statement_index = 1;
    }
    mut condition_prefix := "function_0_block_0_statement_";
    canonical = mir_native_collection_string_append(canonical, condition_prefix, ctx);
    canonical = mir_native_collection_string_append_int(canonical, condition_statement_index, ctx);
    canonical = mir_native_collection_string_append(canonical, "_kind: LocalI32Set\n", ctx);
    canonical = mir_native_collection_string_append(canonical, condition_prefix, ctx);
    canonical = mir_native_collection_string_append_int(canonical, condition_statement_index, ctx);
    canonical = mir_native_collection_string_append(canonical, "_local: condition\n", ctx);
    canonical = mir_native_collection_string_append(canonical, condition_prefix, ctx);
    canonical = mir_native_collection_string_append_int(canonical, condition_statement_index, ctx);
    canonical = mir_native_collection_string_append(canonical, "_value: ", ctx);
    canonical = mir_native_collection_string_append_int(canonical, model.condition_value, ctx);
    canonical = mir_native_collection_string_append(canonical, "\nfunction_0_block_0_terminator_kind: BranchLocalI32Positive\nfunction_0_block_0_terminator_local: condition\nfunction_0_block_0_terminator_then: then_arm\nfunction_0_block_0_terminator_else: else_arm\n", ctx);

    canonical = mir_native_collection_string_append(canonical, "function_0_block_1_label: then_arm\nfunction_0_block_1_parameter_count: 0\nfunction_0_block_1_statement_count: 1\n", ctx);
    canonical = mir_native_collection_string_emit_effect(
        canonical, "function_0_block_1_statement_0", model.then_effect, ctx
    );
    canonical = mir_native_collection_string_append(canonical, "function_0_block_1_terminator_kind: Jump\nfunction_0_block_1_terminator_target: join\n", ctx);
    canonical = mir_native_collection_string_append(canonical, "function_0_block_2_label: else_arm\nfunction_0_block_2_parameter_count: 0\nfunction_0_block_2_statement_count: 1\n", ctx);
    canonical = mir_native_collection_string_emit_effect(
        canonical, "function_0_block_2_statement_0", model.else_effect, ctx
    );
    canonical = mir_native_collection_string_append(canonical, "function_0_block_2_terminator_kind: Jump\nfunction_0_block_2_terminator_target: join\n", ctx);
    canonical = mir_native_collection_string_append(canonical, "function_0_block_3_label: join\nfunction_0_block_3_parameter_count: 0\nfunction_0_block_3_statement_count: ", ctx);
    mut after_count := 0;
    if model.after.kind != 0 { after_count = 1; }
    canonical = mir_native_collection_string_append_int(canonical, after_count, ctx);
    canonical = mir_native_collection_string_append(canonical, "\n", ctx);
    if model.after.kind != 0 {
        canonical = mir_native_collection_string_emit_effect(
            canonical, "function_0_block_3_statement_0", model.after, ctx
        );
    }
    canonical = mir_native_collection_string_append(canonical, "function_0_block_3_terminator_kind: ReturnI32\nfunction_0_block_3_terminator_value: 0\n", ctx);

    mut metadata_count := 2;
    if model.before.kind != 0 { metadata_count = metadata_count + 1; }
    if model.after.kind != 0 { metadata_count = metadata_count + 1; }
    canonical = mir_native_collection_string_append(canonical, "function_0_metadata_count: ", ctx);
    canonical = mir_native_collection_string_append_int(canonical, metadata_count, ctx);
    canonical = mir_native_collection_string_append(canonical, "\n", ctx);
    mut metadata_index := 0;
    if model.before.kind != 0 {
        canonical = mir_native_collection_string_emit_metadata(
            canonical, metadata_index, "statement:entry:0", model.before,
            model.source_path, ctx
        );
        metadata_index = metadata_index + 1;
    }
    canonical = mir_native_collection_string_emit_metadata(
        canonical, metadata_index, "statement:then_arm:0", model.then_effect,
        model.source_path, ctx
    );
    metadata_index = metadata_index + 1;
    canonical = mir_native_collection_string_emit_metadata(
        canonical, metadata_index, "statement:else_arm:0", model.else_effect,
        model.source_path, ctx
    );
    metadata_index = metadata_index + 1;
    if model.after.kind != 0 {
        canonical = mir_native_collection_string_emit_metadata(
            canonical, metadata_index, "statement:join:0", model.after,
            model.source_path, ctx
        );
    }
    canonical = mir_native_collection_string_append(canonical, "function_0_expected_exit: 0\n", ctx);

    mut bundle := mir.mir_make_program_bundle("main", ctx);
    mut module := mir.mir_make_program_bundle_module(
        model.source_path,
        "",
        "phase21_collection_string_source.o",
        "gust.compiler_mir_ingestion.v2",
        canonical,
        0,
        0,
        metadata_count,
        ctx
    );
    module = mir.mir_program_bundle_module_with_symbol(
        module,
        mir.mir_make_program_bundle_symbol("main", "main", "()->int", 0, ctx),
        ctx
    );
    module = mir.mir_program_bundle_module_with_symbol(
        module,
        mir.mir_make_program_bundle_symbol("os_LogInt", "os_LogInt", "(int)->void", 2, ctx),
        ctx
    );
    module = mir.mir_program_bundle_module_with_symbol(
        module,
        mir.mir_make_program_bundle_symbol("os_LogStr", "os_LogStr", "(str)->void", 2, ctx),
        ctx
    );
    return mir.mir_program_bundle_with_module(bundle, module, ctx);
}

func mir_native_collection_string_source_lower(
    programs: std.Vector[ast.Program[ctx], ctx],
    module_paths: std.Vector[str, ctx],
    module_prefixes: std.Vector[str, ctx],
    ctx: &Arena
) MirNativeCollectionStringSourceResult[ctx] {
    mut result := mir_native_collection_string_empty_result(ctx);
    if len(programs) != 1 || len(module_paths) != 1 || len(module_prefixes) != 1 ||
       std.str_eq(module_prefixes[0], "") == 0
    {
        return result;
    }
    unsafe {
        mut program := programs[0];
        mut top_level: std.Vector[ast.Statement[ctx], ctx] := ctx[program.statements];
        if len(top_level) != 1 || top_level[0].tag != 3 ||
           top_level[0].FunctionDecl.is_extern == 1 ||
           std.str_eq(top_level[0].FunctionDecl.name, "main") == 0
        {
            return result;
        }
        mut parameters: std.Vector[ast.Parameter[ctx], ctx] :=
            ctx[top_level[0].FunctionDecl.params];
        mut return_type := ctx[top_level[0].FunctionDecl.return_type];
        if len(parameters) != 0 || return_type.tag != 3 {
            return result;
        }
        mut body := ctx[top_level[0].FunctionDecl.body];
        mut statements: std.Vector[ast.Statement[ctx], ctx] := ctx[body.statements];
        mut model := mir_native_collection_string_analyze_collections(
            statements, module_paths[0], ctx
        );
        if model.represented == 0 {
            model = mir_native_collection_string_analyze_strings(
                statements, module_paths[0], ctx
            );
        }
        if model.represented == 0 {
            return result;
        }
        result.represented = 1;
        result.bundle = mir_native_collection_string_emit_bundle(model, ctx);
        return result;
    }
}
