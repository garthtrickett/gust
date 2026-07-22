import "ast.gst" as ast;
import "mir.gst" as mir;

// Compiler-owned ordinary-source local-state lowering.
//
// This helper is invoked only after the existing generic scalar/CFG/call
// recognizers decline a semantic AST. It traverses typed statements and
// expressions, assigns local indices in declaration order, and emits the
// existing frozen canonical MIR v1 schema. It never reads source text or
// compares source paths, fixture names, or literal program spellings.
type MirNativeLocalStateWrite struct {
    target_index: int,
    kind: int,
    value: int
}

type MirNativeLocalStateProvenance struct {
    event_kind: int,
    local_index: int,
    block_index: int,
    statement_index: int,
    line: int,
    column: int
}

type MirNativeLocalStateExpression struct {
    represented: int,
    invalid: int,
    failure_tag: int,
    value: int,
    local_read_count: int,
    target_read_count: int,
    literal_total: int,
    add_count: int,
    target_literal_operation_kind: int,
    target_literal_operation_value: int
}

type MirNativeLocalStateBlockResult[ctx] struct {
    represented: int,
    invalid: int,
    diagnostic: str,
    values: std.Vector[int, ctx],
    initialized: std.Vector[int, ctx],
    writes: std.Vector[MirNativeLocalStateWrite, ctx],
    provenance: std.Vector[MirNativeLocalStateProvenance, ctx]
}

type MirNativeLocalStateModel[ctx] struct {
    represented: int,
    invalid: int,
    diagnostic: str,
    source_path: str,
    local_names: std.Vector[str, ctx],
    local_values: std.Vector[int, ctx],
    local_initialized: std.Vector[int, ctx],
    local_mutable: std.Vector[int, ctx],
    entry_writes: std.Vector[MirNativeLocalStateWrite, ctx],
    then_writes: std.Vector[MirNativeLocalStateWrite, ctx],
    else_writes: std.Vector[MirNativeLocalStateWrite, ctx],
    merge_writes: std.Vector[MirNativeLocalStateWrite, ctx],
    provenance: std.Vector[MirNativeLocalStateProvenance, ctx],
    has_branch: int,
    condition_local_index: int,
    return_local_index: int,
    expected_exit: int
}

type MirNativeLocalStateSourceResult[ctx] struct {
    represented: int,
    invalid: int,
    diagnostic: str,
    bundle: mir.MirProgramBundle[ctx]
}

func mir_native_local_state_append(output: str, value: str, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat(output, value));
}

func mir_native_local_state_append_int(output: str, value: int, ctx: &Arena) str {
    mut formatted := std.FormatInt(value);
    mut updated := std.Concat(output, formatted);
    return std.Clone(ctx, updated);
}

func mir_native_local_state_empty_expression() MirNativeLocalStateExpression {
    mut result: MirNativeLocalStateExpression;
    result.represented = 0;
    result.invalid = 0;
    result.failure_tag = 0;
    result.value = 0;
    result.local_read_count = 0;
    result.target_read_count = 0;
    result.literal_total = 0;
    result.add_count = 0;
    result.target_literal_operation_kind = 0;
    result.target_literal_operation_value = 0;
    return result;
}

func mir_native_local_state_empty_model(ctx: &Arena) MirNativeLocalStateModel[ctx] {
    mut model: MirNativeLocalStateModel[ctx];
    model.represented = 0;
    model.invalid = 0;
    model.diagnostic = std.Clone(ctx, "");
    model.source_path = std.Clone(ctx, "");
    model.local_names = std.VectorNew(ctx);
    model.local_values = std.VectorNew(ctx);
    model.local_initialized = std.VectorNew(ctx);
    model.local_mutable = std.VectorNew(ctx);
    model.entry_writes = std.VectorNew(ctx);
    model.then_writes = std.VectorNew(ctx);
    model.else_writes = std.VectorNew(ctx);
    model.merge_writes = std.VectorNew(ctx);
    model.provenance = std.VectorNew(ctx);
    model.has_branch = 0;
    model.condition_local_index = 0 - 1;
    model.return_local_index = 0 - 1;
    model.expected_exit = 0;
    return model;
}

func mir_native_local_state_empty_block_result(ctx: &Arena) MirNativeLocalStateBlockResult[ctx] {
    mut result: MirNativeLocalStateBlockResult[ctx];
    result.represented = 1;
    result.invalid = 0;
    result.diagnostic = std.Clone(ctx, "");
    result.values = std.VectorNew(ctx);
    result.initialized = std.VectorNew(ctx);
    result.writes = std.VectorNew(ctx);
    result.provenance = std.VectorNew(ctx);
    return result;
}

func mir_native_local_state_empty_result(ctx: &Arena) MirNativeLocalStateSourceResult[ctx] {
    mut result: MirNativeLocalStateSourceResult[ctx];
    result.represented = 0;
    result.invalid = 0;
    result.diagnostic = std.Clone(ctx, "");
    result.bundle = mir.mir_make_program_bundle("invalid", ctx);
    return result;
}

func mir_native_local_state_clone_ints(
    values: std.Vector[int, ctx],
    ctx: &Arena
) std.Vector[int, ctx] {
    mut cloned: std.Vector[int, ctx] := std.VectorNew(ctx);
    mut value_index := 0;
    while value_index < len(values) {
        cloned.Push(values[value_index]);
        value_index = value_index + 1;
    }
    return cloned;
}

func mir_native_local_state_find_local(
    names: std.Vector[str, ctx],
    name: str
) int {
    mut local_index := 0;
    while local_index < len(names) {
        if std.str_eq(names[local_index], name) == 1 {
            return local_index;
        }
        local_index = local_index + 1;
    }
    return 0 - 1;
}

func mir_native_local_state_declared_type_is_int(
    statement: ast.Statement[ctx],
    ctx: &Arena
) int {
    unsafe {
        if statement.tag != 4 {
            return 0;
        }
        if statement.VarDecl.var_type ==
            empty[Index[ast.Type[ctx], ctx]]
        {
            return 1;
        }
        mut declared_type := ctx[statement.VarDecl.var_type];
        if declared_type.tag == 0 {
            return 1;
        }
        return 0;
    }
}

func mir_native_local_state_expression(
    expression: ast.Expression[ctx],
    names: std.Vector[str, ctx],
    values: std.Vector[int, ctx],
    initialized: std.Vector[int, ctx],
    target_index: int,
    ctx: &Arena
) MirNativeLocalStateExpression {
    mut lowered := mir_native_local_state_empty_expression();
    unsafe {
        if expression.tag == 1 {
            lowered.represented = 1;
            lowered.value = expression.Integer.val;
            lowered.literal_total = expression.Integer.val;
            return lowered;
        }

        if expression.tag == 0 {
            mut local_index := mir_native_local_state_find_local(
                names,
                expression.Identifier.name
            );
            if local_index < 0 {
                lowered.invalid = 1;
                lowered.failure_tag = 1;
                return lowered;
            }
            if initialized[local_index] == 0 {
                lowered.invalid = 1;
                lowered.failure_tag = 2;
                return lowered;
            }

            lowered.represented = 1;
            lowered.value = values[local_index];
            lowered.local_read_count = 1;
            if local_index == target_index {
                lowered.target_read_count = 1;
            }
            return lowered;
        }

        if expression.tag != 10 {
            return lowered;
        }
        mut operation_kind := 0;
        if std.str_eq(expression.Binary.op, "+") == 1 {
            operation_kind = 1;
        } else if std.str_eq(expression.Binary.op, "-") == 1 {
            operation_kind = 2;
        } else if std.str_eq(expression.Binary.op, "*") == 1 {
            operation_kind = 3;
        } else {
            return lowered;
        }

        mut left_expression := ctx[expression.Binary.left];
        mut right_expression := ctx[expression.Binary.right];
        mut left := mir_native_local_state_expression(
            left_expression,
            names,
            values,
            initialized,
            target_index,
            ctx
        );
        mut right := mir_native_local_state_expression(
            right_expression,
            names,
            values,
            initialized,
            target_index,
            ctx
        );
        if left.invalid == 1 {
            return left;
        }
        if right.invalid == 1 {
            return right;
        }
        if left.represented == 0 || right.represented == 0 {
            return lowered;
        }

        lowered.represented = 1;
        if operation_kind == 1 {
            lowered.value = left.value + right.value;
            lowered.literal_total =
                left.literal_total + right.literal_total;
            lowered.add_count = left.add_count + right.add_count + 1;
        } else if operation_kind == 2 {
            lowered.value = left.value - right.value;
            lowered.literal_total =
                left.literal_total - right.literal_total;
            lowered.add_count = left.add_count + right.add_count;
        } else {
            lowered.value = left.value * right.value;
            lowered.literal_total =
                left.literal_total * right.literal_total;
            lowered.add_count = left.add_count + right.add_count;
        }
        lowered.local_read_count =
            left.local_read_count + right.local_read_count;
        lowered.target_read_count =
            left.target_read_count + right.target_read_count;

        if left.local_read_count == 1 &&
           left.target_read_count == 1 &&
           right.local_read_count == 0
        {
            lowered.target_literal_operation_kind = operation_kind;
            lowered.target_literal_operation_value = right.value;
        }
        return lowered;
    }
}

func mir_native_local_state_invalid_diagnostic(
    failure_tag: int,
    ctx: &Arena
) str {
    if failure_tag == 1 {
        return std.Clone(
            ctx,
            "Native backend internal error: generic local-state MIR references an unknown local"
        );
    }
    if failure_tag == 2 {
        return std.Clone(
            ctx,
            "Native backend internal error: generic local-state MIR read before definite assignment"
        );
    }
    if failure_tag == 3 {
        return std.Clone(
            ctx,
            "Native backend internal error: generic local-state MIR assigns an immutable local"
        );
    }
    if failure_tag == 4 {
        return std.Clone(
            ctx,
            "Native backend internal error: generic local-state MIR uses an invalid join state"
        );
    }
    if failure_tag == 5 {
        return std.Clone(
            ctx,
            "Native backend internal error: generic local-state MIR contains a duplicate local declaration"
        );
    }
    return std.Clone(
        ctx,
        "Native backend internal error: generic local-state MIR is invalid"
    );
}

func mir_native_local_state_make_write(
    target_index: int,
    kind: int,
    value: int
) MirNativeLocalStateWrite {
    mut write: MirNativeLocalStateWrite;
    write.target_index = target_index;
    write.kind = kind;
    write.value = value;
    return write;
}

func mir_native_local_state_make_provenance(
    event_kind: int,
    local_index: int,
    block_index: int,
    statement_index: int,
    line: int,
    column: int
) MirNativeLocalStateProvenance {
    mut provenance: MirNativeLocalStateProvenance;
    provenance.event_kind = event_kind;
    provenance.local_index = local_index;
    provenance.block_index = block_index;
    provenance.statement_index = statement_index;
    provenance.line = line;
    provenance.column = column;
    return provenance;
}

func mir_native_local_state_append_provenance(
    destination: std.Vector[MirNativeLocalStateProvenance, ctx],
    source: std.Vector[MirNativeLocalStateProvenance, ctx]
) std.Vector[MirNativeLocalStateProvenance, ctx] {
    mut output := destination;
    mut source_index := 0;
    while source_index < len(source) {
        output.Push(source[source_index]);
        source_index = source_index + 1;
    }
    return output;
}

func mir_native_local_state_apply_assignment(
    statement: ast.Statement[ctx],
    names: std.Vector[str, ctx],
    mutable_flags: std.Vector[int, ctx],
    values: std.Vector[int, ctx],
    initialized: std.Vector[int, ctx],
    writes: std.Vector[MirNativeLocalStateWrite, ctx],
    provenance: std.Vector[MirNativeLocalStateProvenance, ctx],
    block_index: int,
    ctx: &Arena
) MirNativeLocalStateBlockResult[ctx] {
    mut result := mir_native_local_state_empty_block_result(ctx);
    result.values = values;
    result.initialized = initialized;
    result.writes = writes;
    result.provenance = provenance;

    unsafe {
        if statement.tag != 5 {
            result.represented = 0;
            return result;
        }

        mut left := ctx[statement.Assignment.left];
        if left.tag != 0 {
            result.invalid = 1;
            result.diagnostic = mir_native_local_state_invalid_diagnostic(
                1,
                ctx
            );
            return result;
        }

        mut target_index := mir_native_local_state_find_local(
            names,
            left.Identifier.name
        );
        if target_index < 0 {
            result.invalid = 1;
            result.diagnostic = mir_native_local_state_invalid_diagnostic(
                1,
                ctx
            );
            return result;
        }
        if mutable_flags[target_index] == 0 {
            result.invalid = 1;
            result.diagnostic = mir_native_local_state_invalid_diagnostic(
                3,
                ctx
            );
            return result;
        }

        mut value_expression := ctx[statement.Assignment.value];
        mut lowered := mir_native_local_state_expression(
            value_expression,
            names,
            result.values,
            result.initialized,
            target_index,
            ctx
        );
        if lowered.invalid == 1 {
            result.invalid = 1;
            result.diagnostic = mir_native_local_state_invalid_diagnostic(
                lowered.failure_tag,
                ctx
            );
            return result;
        }
        if lowered.represented == 0 {
            result.represented = 0;
            return result;
        }

        mut write_kind := 0;
        mut write_value := lowered.value;
        if result.initialized[target_index] == 1 &&
           lowered.target_literal_operation_kind > 0
        {
            write_kind = lowered.target_literal_operation_kind;
            write_value = lowered.target_literal_operation_value;
        }

        mut statement_index := len(result.writes);
        result.writes.Push(
            mir_native_local_state_make_write(
                target_index,
                write_kind,
                write_value
            )
        );
        result.provenance.Push(
            mir_native_local_state_make_provenance(
                1,
                target_index,
                block_index,
                statement_index,
                statement.Assignment.span.start.line,
                statement.Assignment.span.start.column
            )
        );
        result.values.Set(target_index, lowered.value);
        result.initialized.Set(target_index, 1);
        return result;
    }
}

func mir_native_local_state_apply_branch_block(
    statements: std.Vector[ast.Statement[ctx], ctx],
    names: std.Vector[str, ctx],
    mutable_flags: std.Vector[int, ctx],
    starting_values: std.Vector[int, ctx],
    starting_initialized: std.Vector[int, ctx],
    block_index: int,
    ctx: &Arena
) MirNativeLocalStateBlockResult[ctx] {
    mut result := mir_native_local_state_empty_block_result(ctx);
    result.values = mir_native_local_state_clone_ints(
        starting_values,
        ctx
    );
    result.initialized = mir_native_local_state_clone_ints(
        starting_initialized,
        ctx
    );

    mut statement_index := 0;
    while statement_index < len(statements) {
        mut applied := mir_native_local_state_apply_assignment(
            statements[statement_index],
            names,
            mutable_flags,
            result.values,
            result.initialized,
            result.writes,
            result.provenance,
            block_index,
            ctx
        );
        if applied.represented == 0 || applied.invalid == 1 {
            return applied;
        }
        result = applied;
        statement_index = statement_index + 1;
    }
    return result;
}

func mir_native_local_state_function_is_entry(
    statement: ast.Statement[ctx],
    ctx: &Arena
) int {
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

func mir_native_local_state_analyze(
    programs: std.Vector[ast.Program[ctx], ctx],
    module_paths: std.Vector[str, ctx],
    module_prefixes: std.Vector[str, ctx],
    ctx: &Arena
) MirNativeLocalStateModel[ctx] {
    mut model := mir_native_local_state_empty_model(ctx);
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
    if len(top_level) != 1 ||
       mir_native_local_state_function_is_entry(
           top_level[0],
           ctx
       ) == 0
    {
        return model;
    }

    unsafe {
        mut function_statement := top_level[0];
        mut body := ctx[function_statement.FunctionDecl.body];
        mut statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[body.statements];
        mut saw_local_state_feature := 0;
        mut saw_return := 0;
        mut branch_closed := 0;
        mut statement_index := 0;

        model.source_path = std.Clone(ctx, module_paths[0]);

        while statement_index < len(statements) {
            mut statement := statements[statement_index];

            if statement.tag == 4 {
                if branch_closed == 1 || saw_return == 1 {
                    return mir_native_local_state_empty_model(ctx);
                }
                if mir_native_local_state_declared_type_is_int(
                    statement,
                    ctx
                ) == 0 {
                    return mir_native_local_state_empty_model(ctx);
                }
                if mir_native_local_state_find_local(
                    model.local_names,
                    statement.VarDecl.name
                ) >= 0 {
                    model.represented = 1;
                    model.invalid = 1;
                    model.diagnostic =
                        mir_native_local_state_invalid_diagnostic(5, ctx);
                    return model;
                }

                mut local_index := len(model.local_names);
                model.local_names.Push(
                    std.Clone(ctx, statement.VarDecl.name)
                );
                model.local_values.Push(0);
                model.local_initialized.Push(0);
                model.local_mutable.Push(statement.VarDecl.is_mut);
                model.provenance.Push(
                    mir_native_local_state_make_provenance(
                        0,
                        local_index,
                        0,
                        0 - 1,
                        statement.VarDecl.span.start.line,
                        statement.VarDecl.span.start.column
                    )
                );

                if statement.VarDecl.value !=
                    empty[Index[ast.Expression[ctx], ctx]]
                {
                    mut initializer := ctx[statement.VarDecl.value];
                    mut lowered_initializer :=
                        mir_native_local_state_expression(
                            initializer,
                            model.local_names,
                            model.local_values,
                            model.local_initialized,
                            local_index,
                            ctx
                        );
                    if lowered_initializer.invalid == 1 {
                        model.represented = 1;
                        model.invalid = 1;
                        model.diagnostic =
                            mir_native_local_state_invalid_diagnostic(
                                lowered_initializer.failure_tag,
                                ctx
                            );
                        return model;
                    }
                    if lowered_initializer.represented == 0 {
                        return mir_native_local_state_empty_model(ctx);
                    }

                    model.entry_writes.Push(
                        mir_native_local_state_make_write(
                            local_index,
                            0,
                            lowered_initializer.value
                        )
                    );
                    model.local_values.Set(
                        local_index,
                        lowered_initializer.value
                    );
                    model.local_initialized.Set(local_index, 1);
                }

                if len(model.local_names) > 1 ||
                   statement.VarDecl.value ==
                       empty[Index[ast.Expression[ctx], ctx]]
                {
                    saw_local_state_feature = 1;
                }
                statement_index = statement_index + 1;
                continue;
            }

            if statement.tag == 5 {
                if saw_return == 1 {
                    return mir_native_local_state_empty_model(ctx);
                }
                saw_local_state_feature = 1;
                mut target_writes := model.entry_writes;
                mut target_block_index := 0;
                if branch_closed == 1 {
                    target_writes = model.merge_writes;
                    target_block_index = 3;
                }
                mut assignment_result :=
                    mir_native_local_state_apply_assignment(
                        statement,
                        model.local_names,
                        model.local_mutable,
                        model.local_values,
                        model.local_initialized,
                        target_writes,
                        model.provenance,
                        target_block_index,
                        ctx
                    );
                if assignment_result.invalid == 1 {
                    model.represented = 1;
                    model.invalid = 1;
                    model.diagnostic = assignment_result.diagnostic;
                    return model;
                }
                if assignment_result.represented == 0 {
                    return mir_native_local_state_empty_model(ctx);
                }
                model.local_values = assignment_result.values;
                model.local_initialized = assignment_result.initialized;
                if branch_closed == 1 {
                    model.merge_writes = assignment_result.writes;
                } else {
                    model.entry_writes = assignment_result.writes;
                }
                model.provenance = assignment_result.provenance;
                statement_index = statement_index + 1;
                continue;
            }

            if statement.tag == 7 {
                if model.has_branch == 1 ||
                   branch_closed == 1 ||
                   saw_return == 1
                {
                    return mir_native_local_state_empty_model(ctx);
                }
                saw_local_state_feature = 1;

                mut condition := ctx[statement.If.condition];
                if condition.tag != 10 ||
                   std.str_eq(condition.Binary.op, ">") == 0
                {
                    return mir_native_local_state_empty_model(ctx);
                }
                mut condition_left := ctx[condition.Binary.left];
                mut condition_right := ctx[condition.Binary.right];
                if condition_left.tag != 0 ||
                   condition_right.tag != 1 ||
                   condition_right.Integer.val != 0
                {
                    return mir_native_local_state_empty_model(ctx);
                }

                mut condition_local_index :=
                    mir_native_local_state_find_local(
                        model.local_names,
                        condition_left.Identifier.name
                    );
                if condition_local_index < 0 {
                    model.represented = 1;
                    model.invalid = 1;
                    model.diagnostic =
                        mir_native_local_state_invalid_diagnostic(1, ctx);
                    return model;
                }
                if model.local_initialized[condition_local_index] == 0 {
                    model.represented = 1;
                    model.invalid = 1;
                    model.diagnostic =
                        mir_native_local_state_invalid_diagnostic(2, ctx);
                    return model;
                }

                mut consequence := ctx[statement.If.consequence];
                mut alternative := ctx[statement.If.alternative];
                mut then_statements:
                    std.Vector[ast.Statement[ctx], ctx] :=
                        ctx[consequence.statements];
                mut else_statements:
                    std.Vector[ast.Statement[ctx], ctx] :=
                        ctx[alternative.statements];

                mut then_result :=
                    mir_native_local_state_apply_branch_block(
                        then_statements,
                        model.local_names,
                        model.local_mutable,
                        model.local_values,
                        model.local_initialized,
                        1,
                        ctx
                    );
                if then_result.invalid == 1 {
                    model.represented = 1;
                    model.invalid = 1;
                    model.diagnostic = then_result.diagnostic;
                    return model;
                }
                if then_result.represented == 0 {
                    return mir_native_local_state_empty_model(ctx);
                }

                mut else_result :=
                    mir_native_local_state_apply_branch_block(
                        else_statements,
                        model.local_names,
                        model.local_mutable,
                        model.local_values,
                        model.local_initialized,
                        2,
                        ctx
                    );
                if else_result.invalid == 1 {
                    model.represented = 1;
                    model.invalid = 1;
                    model.diagnostic = else_result.diagnostic;
                    return model;
                }
                if else_result.represented == 0 {
                    return mir_native_local_state_empty_model(ctx);
                }

                model.has_branch = 1;
                model.condition_local_index = condition_local_index;
                model.then_writes = then_result.writes;
                model.else_writes = else_result.writes;
                model.provenance =
                    mir_native_local_state_append_provenance(
                        model.provenance,
                        then_result.provenance
                    );
                model.provenance =
                    mir_native_local_state_append_provenance(
                        model.provenance,
                        else_result.provenance
                    );

                mut local_index_after_branch := 0;
                while local_index_after_branch <
                    len(model.local_names)
                {
                    mut definitely_initialized :=
                        then_result.initialized[
                            local_index_after_branch
                        ];
                    if else_result.initialized[
                        local_index_after_branch
                    ] == 0 {
                        definitely_initialized = 0;
                    }
                    model.local_initialized.Set(
                        local_index_after_branch,
                        definitely_initialized
                    );
                    if model.local_values[condition_local_index] > 0 {
                        model.local_values.Set(
                            local_index_after_branch,
                            then_result.values[
                                local_index_after_branch
                            ]
                        );
                    } else {
                        model.local_values.Set(
                            local_index_after_branch,
                            else_result.values[
                                local_index_after_branch
                            ]
                        );
                    }
                    local_index_after_branch =
                        local_index_after_branch + 1;
                }

                branch_closed = 1;
                statement_index = statement_index + 1;
                continue;
            }

            if statement.tag == 12 {
                if saw_return == 1 ||
                   statement_index + 1 != len(statements)
                {
                    return mir_native_local_state_empty_model(ctx);
                }
                mut return_expression := ctx[statement.Return.expr];
                if return_expression.tag != 0 {
                    return mir_native_local_state_empty_model(ctx);
                }
                mut return_local_index :=
                    mir_native_local_state_find_local(
                        model.local_names,
                        return_expression.Identifier.name
                    );
                if return_local_index < 0 {
                    model.represented = 1;
                    model.invalid = 1;
                    model.diagnostic =
                        mir_native_local_state_invalid_diagnostic(1, ctx);
                    return model;
                }
                if model.local_initialized[return_local_index] == 0 {
                    model.represented = 1;
                    model.invalid = 1;
                    model.diagnostic =
                        mir_native_local_state_invalid_diagnostic(2, ctx);
                    return model;
                }
                model.return_local_index = return_local_index;
                model.expected_exit =
                    model.local_values[return_local_index];
                saw_return = 1;
                statement_index = statement_index + 1;
                continue;
            }

            return mir_native_local_state_empty_model(ctx);
        }

        if saw_return == 0 ||
           saw_local_state_feature == 0 ||
           len(model.local_names) == 0
        {
            return mir_native_local_state_empty_model(ctx);
        }

        model.represented = 1;
        return model;
    }
}

func mir_native_local_state_block_label(
    block_index: int,
    ctx: &Arena
) str {
    if block_index == 0 {
        return std.Clone(ctx, "entry");
    }
    if block_index == 1 {
        return std.Clone(ctx, "then");
    }
    if block_index == 2 {
        return std.Clone(ctx, "else");
    }
    return std.Clone(ctx, "merge");
}

func mir_native_local_state_emit_write(
    canonical: str,
    block_index: int,
    statement_index: int,
    write: MirNativeLocalStateWrite,
    names: std.Vector[str, ctx],
    ctx: &Arena
) str {
    mut output := canonical;
    output = mir_native_local_state_append(output, "block_", ctx);
    output = mir_native_local_state_append_int(
        output,
        block_index,
        ctx
    );
    output = mir_native_local_state_append(output, "_statement_", ctx);
    output = mir_native_local_state_append_int(
        output,
        statement_index,
        ctx
    );
    output = mir_native_local_state_append(output, "_kind: ", ctx);
    if write.kind == 1 {
        output = mir_native_local_state_append(
            output,
            "LocalI32AddI32Literal\n",
            ctx
        );
    } else if write.kind == 2 {
        output = mir_native_local_state_append(
            output,
            "LocalI32SubI32Literal\n",
            ctx
        );
    } else if write.kind == 3 {
        output = mir_native_local_state_append(
            output,
            "LocalI32MulI32Literal\n",
            ctx
        );
    } else {
        output = mir_native_local_state_append(
            output,
            "LocalI32Set\n",
            ctx
        );
    }

    output = mir_native_local_state_append(output, "block_", ctx);
    output = mir_native_local_state_append_int(
        output,
        block_index,
        ctx
    );
    output = mir_native_local_state_append(output, "_statement_", ctx);
    output = mir_native_local_state_append_int(
        output,
        statement_index,
        ctx
    );
    output = mir_native_local_state_append(output, "_local: ", ctx);
    output = mir_native_local_state_append(
        output,
        names[write.target_index],
        ctx
    );
    output = mir_native_local_state_append(output, "\nblock_", ctx);
    output = mir_native_local_state_append_int(
        output,
        block_index,
        ctx
    );
    output = mir_native_local_state_append(output, "_statement_", ctx);
    output = mir_native_local_state_append_int(
        output,
        statement_index,
        ctx
    );
    output = mir_native_local_state_append(output, "_value: ", ctx);
    output = mir_native_local_state_append_int(
        output,
        write.value,
        ctx
    );
    output = mir_native_local_state_append(output, "\n", ctx);
    return std.Clone(ctx, output);
}

func mir_native_local_state_emit_block_header_and_writes(
    canonical: str,
    block_index: int,
    label: str,
    writes: std.Vector[MirNativeLocalStateWrite, ctx],
    names: std.Vector[str, ctx],
    ctx: &Arena
) str {
    mut output := canonical;
    output = mir_native_local_state_append(output, "block_", ctx);
    output = mir_native_local_state_append_int(
        output,
        block_index,
        ctx
    );
    output = mir_native_local_state_append(output, "_label: ", ctx);
    output = mir_native_local_state_append(output, label, ctx);
    output = mir_native_local_state_append(output, "\nblock_", ctx);
    output = mir_native_local_state_append_int(
        output,
        block_index,
        ctx
    );
    output = mir_native_local_state_append(
        output,
        "_parameter_count: 0\nblock_",
        ctx
    );
    output = mir_native_local_state_append_int(
        output,
        block_index,
        ctx
    );
    output = mir_native_local_state_append(
        output,
        "_statement_count: ",
        ctx
    );
    output = mir_native_local_state_append_int(
        output,
        len(writes),
        ctx
    );
    output = mir_native_local_state_append(output, "\n", ctx);

    mut statement_index := 0;
    while statement_index < len(writes) {
        output = mir_native_local_state_emit_write(
            output,
            block_index,
            statement_index,
            writes[statement_index],
            names,
            ctx
        );
        statement_index = statement_index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_native_local_state_emit_return(
    canonical: str,
    block_index: int,
    return_local_index: int,
    names: std.Vector[str, ctx],
    ctx: &Arena
) str {
    mut output := canonical;
    output = mir_native_local_state_append(output, "block_", ctx);
    output = mir_native_local_state_append_int(
        output,
        block_index,
        ctx
    );
    output = mir_native_local_state_append(
        output,
        "_terminator_kind: ReturnLocalI32\nblock_",
        ctx
    );
    output = mir_native_local_state_append_int(
        output,
        block_index,
        ctx
    );
    output = mir_native_local_state_append(
        output,
        "_terminator_local: ",
        ctx
    );
    output = mir_native_local_state_append(
        output,
        names[return_local_index],
        ctx
    );
    output = mir_native_local_state_append(output, "\n", ctx);
    return std.Clone(ctx, output);
}

func mir_native_local_state_emit_metadata(
    canonical: str,
    model: MirNativeLocalStateModel[ctx],
    ctx: &Arena
) str {
    mut output := canonical;
    output = mir_native_local_state_append(
        output,
        "metadata_count: ",
        ctx
    );
    output = mir_native_local_state_append_int(
        output,
        len(model.provenance),
        ctx
    );
    output = mir_native_local_state_append(output, "\n", ctx);

    mut metadata_index := 0;
    while metadata_index < len(model.provenance) {
        mut event := model.provenance[metadata_index];
        output = mir_native_local_state_append(output, "metadata_", ctx);
        output = mir_native_local_state_append_int(
            output,
            metadata_index,
            ctx
        );
        output = mir_native_local_state_append(
            output,
            "_kind: provenance\nmetadata_",
            ctx
        );
        output = mir_native_local_state_append_int(
            output,
            metadata_index,
            ctx
        );
        output = mir_native_local_state_append(
            output,
            "_attachment: ",
            ctx
        );
        if event.event_kind == 0 {
            output = mir_native_local_state_append(
                output,
                "local:",
                ctx
            );
            output = mir_native_local_state_append_int(
                output,
                event.local_index,
                ctx
            );
        } else {
            output = mir_native_local_state_append(
                output,
                "statement:",
                ctx
            );
            output = mir_native_local_state_append(
                output,
                mir_native_local_state_block_label(
                    event.block_index,
                    ctx
                ),
                ctx
            );
            output = mir_native_local_state_append(output, ":", ctx);
            output = mir_native_local_state_append_int(
                output,
                event.statement_index,
                ctx
            );
        }

        output = mir_native_local_state_append(
            output,
            "\nmetadata_",
            ctx
        );
        output = mir_native_local_state_append_int(
            output,
            metadata_index,
            ctx
        );
        output = mir_native_local_state_append(
            output,
            "_policy: recognized_preserved\nmetadata_",
            ctx
        );
        output = mir_native_local_state_append_int(
            output,
            metadata_index,
            ctx
        );
        output = mir_native_local_state_append(
            output,
            "_payload: kind=",
            ctx
        );
        if event.event_kind == 0 {
            output = mir_native_local_state_append(
                output,
                "LocalDeclaration",
                ctx
            );
        } else {
            output = mir_native_local_state_append(
                output,
                "LocalAssignment",
                ctx
            );
        }
        output = mir_native_local_state_append(
            output,
            ";local=",
            ctx
        );
        output = mir_native_local_state_append(
            output,
            model.local_names[event.local_index],
            ctx
        );
        output = mir_native_local_state_append(
            output,
            ";index=",
            ctx
        );
        output = mir_native_local_state_append_int(
            output,
            event.local_index,
            ctx
        );
        output = mir_native_local_state_append(
            output,
            ";origin=",
            ctx
        );
        output = mir_native_local_state_append(
            output,
            model.source_path,
            ctx
        );
        output = mir_native_local_state_append(
            output,
            ";line=",
            ctx
        );
        output = mir_native_local_state_append_int(
            output,
            event.line,
            ctx
        );
        output = mir_native_local_state_append(
            output,
            ";column=",
            ctx
        );
        output = mir_native_local_state_append_int(
            output,
            event.column,
            ctx
        );
        output = mir_native_local_state_append(output, "\n", ctx);
        metadata_index = metadata_index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_native_local_state_emit_bundle(
    model: MirNativeLocalStateModel[ctx],
    ctx: &Arena
) mir.MirProgramBundle[ctx] {
    mut canonical :=
        "format: gust.compiler_mir_ingestion.v1\nfunction: main\nbackend_symbol: main\nparameter_count: 0\nreturn_type: int\nlocal_count: ";
    canonical = mir_native_local_state_append_int(
        canonical,
        len(model.local_names),
        ctx
    );
    canonical = mir_native_local_state_append(canonical, "\n", ctx);

    mut local_index := 0;
    while local_index < len(model.local_names) {
        canonical = mir_native_local_state_append(
            canonical,
            "local_",
            ctx
        );
        canonical = mir_native_local_state_append_int(
            canonical,
            local_index,
            ctx
        );
        canonical = mir_native_local_state_append(
            canonical,
            "_name: ",
            ctx
        );
        canonical = mir_native_local_state_append(
            canonical,
            model.local_names[local_index],
            ctx
        );
        canonical = mir_native_local_state_append(
            canonical,
            "\nlocal_",
            ctx
        );
        canonical = mir_native_local_state_append_int(
            canonical,
            local_index,
            ctx
        );
        canonical = mir_native_local_state_append(
            canonical,
            "_type: int\n",
            ctx
        );
        local_index = local_index + 1;
    }

    canonical = mir_native_local_state_append(
        canonical,
        "entry_block: entry\nblock_count: ",
        ctx
    );
    if model.has_branch == 1 {
        canonical = mir_native_local_state_append(
            canonical,
            "4\n",
            ctx
        );
    } else {
        canonical = mir_native_local_state_append(
            canonical,
            "1\n",
            ctx
        );
    }

    canonical = mir_native_local_state_emit_block_header_and_writes(
        canonical,
        0,
        "entry",
        model.entry_writes,
        model.local_names,
        ctx
    );

    if model.has_branch == 1 {
        canonical = mir_native_local_state_append(
            canonical,
            "block_0_terminator_kind: BranchLocalI32Positive\nblock_0_terminator_local: ",
            ctx
        );
        canonical = mir_native_local_state_append(
            canonical,
            model.local_names[model.condition_local_index],
            ctx
        );
        canonical = mir_native_local_state_append(
            canonical,
            "\nblock_0_terminator_then: then\nblock_0_terminator_then_argument_count: 0\nblock_0_terminator_else: else\nblock_0_terminator_else_argument_count: 0\n",
            ctx
        );

        canonical =
            mir_native_local_state_emit_block_header_and_writes(
                canonical,
                1,
                "then",
                model.then_writes,
                model.local_names,
                ctx
            );
        canonical = mir_native_local_state_append(
            canonical,
            "block_1_terminator_kind: Jump\nblock_1_terminator_target: merge\nblock_1_terminator_argument_count: 0\n",
            ctx
        );

        canonical =
            mir_native_local_state_emit_block_header_and_writes(
                canonical,
                2,
                "else",
                model.else_writes,
                model.local_names,
                ctx
            );
        canonical = mir_native_local_state_append(
            canonical,
            "block_2_terminator_kind: Jump\nblock_2_terminator_target: merge\nblock_2_terminator_argument_count: 0\n",
            ctx
        );

        canonical =
            mir_native_local_state_emit_block_header_and_writes(
                canonical,
                3,
                "merge",
                model.merge_writes,
                model.local_names,
                ctx
            );
        canonical = mir_native_local_state_emit_return(
            canonical,
            3,
            model.return_local_index,
            model.local_names,
            ctx
        );
    } else {
        canonical = mir_native_local_state_emit_return(
            canonical,
            0,
            model.return_local_index,
            model.local_names,
            ctx
        );
    }

    canonical = mir_native_local_state_emit_metadata(
        canonical,
        model,
        ctx
    );
    canonical = mir_native_local_state_append(
        canonical,
        "expected_exit: ",
        ctx
    );
    canonical = mir_native_local_state_append_int(
        canonical,
        model.expected_exit,
        ctx
    );
    canonical = mir_native_local_state_append(canonical, "\n", ctx);

    mut bundle := mir.mir_make_program_bundle("main", ctx);
    mut bundle_module := mir.mir_make_program_bundle_module(
        model.source_path,
        "",
        "phase11_local_state_module.o",
        "gust.compiler_mir_ingestion.v1",
        canonical,
        0,
        len(model.provenance),
        0,
        ctx
    );
    bundle_module = mir.mir_program_bundle_module_with_symbol(
        bundle_module,
        mir.mir_make_program_bundle_symbol(
            "main",
            "main",
            "()->int",
            0,
            ctx
        ),
        ctx
    );
    return mir.mir_program_bundle_with_module(
        bundle,
        bundle_module,
        ctx
    );
}

func mir_native_local_state_source_lower(
    programs: std.Vector[ast.Program[ctx], ctx],
    module_paths: std.Vector[str, ctx],
    module_prefixes: std.Vector[str, ctx],
    ctx: &Arena
) MirNativeLocalStateSourceResult[ctx] {
    mut result := mir_native_local_state_empty_result(ctx);
    mut model := mir_native_local_state_analyze(
        programs,
        module_paths,
        module_prefixes,
        ctx
    );

    if model.invalid == 1 {
        result.represented = 1;
        result.invalid = 1;
        result.diagnostic = model.diagnostic;
        return result;
    }
    if model.represented == 0 {
        return result;
    }

    result.represented = 1;
    result.bundle = mir_native_local_state_emit_bundle(model, ctx);
    return result;
}
