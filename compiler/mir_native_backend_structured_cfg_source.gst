import "ast.gst" as ast;
import "mir.gst" as mir;
import "mir_native_backend_local_state_source.gst" as local_state;

// Compiler-owned acyclic structured-CFG lowering.
//
// This route consumes typed AST structure only. It lowers nested positive-local
// if/else statements into an ordinary canonical MIR block graph, leaves join
// formation independent of any fixture topology, and deliberately declines
// loops/backedges for the Patch 7 successor.
type MirNativeStructuredCfgBlock[ctx] struct {
    writes: std.Vector[local_state.MirNativeLocalStateWrite, ctx],
    terminator_kind: int,
    condition_local_index: int,
    first_target_index: int,
    second_target_index: int,
    return_local_index: int
}

type MirNativeStructuredCfgState[ctx] struct {
    block_index: int,
    values: std.Vector[int, ctx],
    initialized: std.Vector[int, ctx],
    selected: int
}

type MirNativeStructuredCfgModel[ctx] struct {
    represented: int,
    invalid: int,
    diagnostic: str,
    source_path: str,
    local_names: std.Vector[str, ctx],
    local_values: std.Vector[int, ctx],
    local_initialized: std.Vector[int, ctx],
    local_mutable: std.Vector[int, ctx],
    blocks: std.Vector[MirNativeStructuredCfgBlock[ctx], ctx],
    provenance: std.Vector[local_state.MirNativeLocalStateProvenance, ctx],
    branch_count: int,
    maximum_branch_depth: int,
    expected_exit: int,
    expected_exit_set: int
}

type MirNativeStructuredCfgLowerResult[ctx] struct {
    represented: int,
    invalid: int,
    diagnostic: str,
    model: MirNativeStructuredCfgModel[ctx],
    states: std.Vector[MirNativeStructuredCfgState[ctx], ctx]
}

type MirNativeStructuredCfgSourceResult[ctx] struct {
    represented: int,
    invalid: int,
    diagnostic: str,
    bundle: mir.MirProgramBundle[ctx]
}

func mir_native_structured_cfg_append(
    output: str,
    value: str,
    ctx: &Arena
) str {
    return std.Clone(ctx, std.Concat(output, value));
}

func mir_native_structured_cfg_append_int(
    output: str,
    value: int,
    ctx: &Arena
) str {
    mut formatted := std.FormatInt(value);
    return std.Clone(ctx, std.Concat(output, formatted));
}

func mir_native_structured_cfg_empty_block(
    ctx: &Arena
) MirNativeStructuredCfgBlock[ctx] {
    mut block: MirNativeStructuredCfgBlock[ctx];
    block.writes = std.VectorNew(ctx);
    block.terminator_kind = 0;
    block.condition_local_index = 0 - 1;
    block.first_target_index = 0 - 1;
    block.second_target_index = 0 - 1;
    block.return_local_index = 0 - 1;
    return block;
}

func mir_native_structured_cfg_empty_model(
    ctx: &Arena
) MirNativeStructuredCfgModel[ctx] {
    mut model: MirNativeStructuredCfgModel[ctx];
    model.represented = 0;
    model.invalid = 0;
    model.diagnostic = std.Clone(ctx, "");
    model.source_path = std.Clone(ctx, "");
    model.local_names = std.VectorNew(ctx);
    model.local_values = std.VectorNew(ctx);
    model.local_initialized = std.VectorNew(ctx);
    model.local_mutable = std.VectorNew(ctx);
    model.blocks = std.VectorNew(ctx);
    model.provenance = std.VectorNew(ctx);
    model.branch_count = 0;
    model.maximum_branch_depth = 0;
    model.expected_exit = 0;
    model.expected_exit_set = 0;
    return model;
}

func mir_native_structured_cfg_empty_lower_result(
    ctx: &Arena
) MirNativeStructuredCfgLowerResult[ctx] {
    mut result: MirNativeStructuredCfgLowerResult[ctx];
    result.represented = 1;
    result.invalid = 0;
    result.diagnostic = std.Clone(ctx, "");
    result.model = mir_native_structured_cfg_empty_model(ctx);
    result.states = std.VectorNew(ctx);
    return result;
}

func mir_native_structured_cfg_empty_source_result(
    ctx: &Arena
) MirNativeStructuredCfgSourceResult[ctx] {
    mut result: MirNativeStructuredCfgSourceResult[ctx];
    result.represented = 0;
    result.invalid = 0;
    result.diagnostic = std.Clone(ctx, "");
    result.bundle = mir.mir_make_program_bundle("invalid", ctx);
    return result;
}

func mir_native_structured_cfg_make_state(
    block_index: int,
    values: std.Vector[int, ctx],
    initialized: std.Vector[int, ctx],
    selected: int
) MirNativeStructuredCfgState[ctx] {
    mut state: MirNativeStructuredCfgState[ctx];
    state.block_index = block_index;
    state.values = values;
    state.initialized = initialized;
    state.selected = selected;
    return state;
}

func mir_native_structured_cfg_block_label(
    block_index: int,
    ctx: &Arena
) str {
    mut label := std.Clone(ctx, "cfg_");
    return mir_native_structured_cfg_append_int(
        label,
        block_index,
        ctx
    );
}

func mir_native_structured_cfg_append_provenance(
    destination: std.Vector[local_state.MirNativeLocalStateProvenance, ctx],
    source: std.Vector[local_state.MirNativeLocalStateProvenance, ctx]
) std.Vector[local_state.MirNativeLocalStateProvenance, ctx] {
    mut output := destination;
    mut source_index := 0;
    while source_index < len(source) {
        output.Push(source[source_index]);
        source_index = source_index + 1;
    }
    return output;
}

func mir_native_structured_cfg_function_is_entry(
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

func mir_native_structured_cfg_condition_local(
    expression: ast.Expression[ctx],
    model: MirNativeStructuredCfgModel[ctx],
    initialized: std.Vector[int, ctx],
    ctx: &Arena
) int {
    unsafe {
        if expression.tag != 10 ||
           std.str_eq(expression.Binary.op, ">") == 0
        {
            return 0 - 1;
        }
        mut left := ctx[expression.Binary.left];
        mut right := ctx[expression.Binary.right];
        if left.tag != 0 ||
           right.tag != 1 ||
           right.Integer.val != 0
        {
            return 0 - 1;
        }
        mut local_index := local_state.mir_native_local_state_find_local(
            model.local_names,
            left.Identifier.name
        );
        if local_index < 0 {
            return 0 - 2;
        }
        if initialized[local_index] == 0 {
            return 0 - 3;
        }
        return local_index;
    }
}

func mir_native_structured_cfg_set_jump(
    model: MirNativeStructuredCfgModel[ctx],
    block_index: int,
    target_index: int
) MirNativeStructuredCfgModel[ctx] {
    mut updated := model;
    mut block := updated.blocks[block_index];
    block.terminator_kind = 2;
    block.first_target_index = target_index;
    updated.blocks.Set(block_index, block);
    return updated;
}

func mir_native_structured_cfg_merge_states(
    model: MirNativeStructuredCfgModel[ctx],
    states: std.Vector[MirNativeStructuredCfgState[ctx], ctx],
    ctx: &Arena
) MirNativeStructuredCfgLowerResult[ctx] {
    mut result := mir_native_structured_cfg_empty_lower_result(ctx);
    result.model = model;
    result.states = states;
    if len(states) <= 1 {
        return result;
    }

    mut join_index := len(result.model.blocks);
    result.model.blocks.Push(
        mir_native_structured_cfg_empty_block(ctx)
    );

    mut merged_initialized :=
        local_state.mir_native_local_state_clone_ints(
            states[0].initialized,
            ctx
        );
    mut merged_values :=
        local_state.mir_native_local_state_clone_ints(
            states[0].values,
            ctx
        );
    mut merged_selected := 0;
    mut selected_state_index := 0 - 1;
    mut state_index := 0;
    while state_index < len(states) {
        mut predecessor := states[state_index];
        mut predecessor_block :=
            result.model.blocks[predecessor.block_index];
        if predecessor_block.terminator_kind != 0 {
            result.invalid = 1;
            result.diagnostic = std.Clone(
                ctx,
                "Native backend internal error: structured CFG attempted to join a terminated block"
            );
            return result;
        }
        result.model = mir_native_structured_cfg_set_jump(
            result.model,
            predecessor.block_index,
            join_index
        );
        if predecessor.selected == 1 {
            merged_selected = 1;
            selected_state_index = state_index;
        }

        mut local_index := 0;
        while local_index < len(merged_initialized) {
            if predecessor.initialized[local_index] == 0 {
                merged_initialized.Set(local_index, 0);
            }
            local_index = local_index + 1;
        }
        state_index = state_index + 1;
    }

    if selected_state_index >= 0 {
        merged_values =
            local_state.mir_native_local_state_clone_ints(
                states[selected_state_index].values,
                ctx
            );
    }

    mut merged_states:
        std.Vector[MirNativeStructuredCfgState[ctx], ctx] :=
            std.VectorNew(ctx);
    merged_states.Push(
        mir_native_structured_cfg_make_state(
            join_index,
            merged_values,
            merged_initialized,
            merged_selected
        )
    );
    result.states = merged_states;
    return result;
}

func mir_native_structured_cfg_apply_assignment(
    model: MirNativeStructuredCfgModel[ctx],
    states: std.Vector[MirNativeStructuredCfgState[ctx], ctx],
    statement: ast.Statement[ctx],
    ctx: &Arena
) MirNativeStructuredCfgLowerResult[ctx] {
    mut result := mir_native_structured_cfg_empty_lower_result(ctx);
    result.model = model;
    result.states = states;
    mut updated_states:
        std.Vector[MirNativeStructuredCfgState[ctx], ctx] :=
            std.VectorNew(ctx);

    mut state_index := 0;
    while state_index < len(states) {
        mut state := states[state_index];
        mut block := result.model.blocks[state.block_index];
        mut no_provenance:
            std.Vector[local_state.MirNativeLocalStateProvenance, ctx] :=
                std.VectorNew(ctx);
        mut applied := local_state.mir_native_local_state_apply_assignment(
            statement,
            result.model.local_names,
            result.model.local_mutable,
            state.values,
            state.initialized,
            block.writes,
            no_provenance,
            state.block_index,
            ctx
        );
        if applied.invalid == 1 {
            result.invalid = 1;
            result.diagnostic = applied.diagnostic;
            return result;
        }
        if applied.represented == 0 {
            result.represented = 0;
            return result;
        }
        block.writes = applied.writes;
        result.model.blocks.Set(state.block_index, block);
        result.model.provenance =
            mir_native_structured_cfg_append_provenance(
                result.model.provenance,
                applied.provenance
            );
        state.values = applied.values;
        state.initialized = applied.initialized;
        updated_states.Push(state);
        state_index = state_index + 1;
    }
    result.states = updated_states;
    return result;
}

func mir_native_structured_cfg_lower_sequence(
    statements: std.Vector[ast.Statement[ctx], ctx],
    states: std.Vector[MirNativeStructuredCfgState[ctx], ctx],
    model: MirNativeStructuredCfgModel[ctx],
    branch_depth: int,
    ctx: &Arena
) MirNativeStructuredCfgLowerResult[ctx] {
    mut result := mir_native_structured_cfg_empty_lower_result(ctx);
    result.model = model;
    result.states = states;
    mut statement_index := 0;

    while statement_index < len(statements) {
        mut statement := statements[statement_index];
        if len(result.states) == 0 {
            result.represented = 0;
            return result;
        }

        if len(result.states) > 1 {
            mut joined := mir_native_structured_cfg_merge_states(
                result.model,
                result.states,
                ctx
            );
            if joined.invalid == 1 || joined.represented == 0 {
                return joined;
            }
            result.model = joined.model;
            result.states = joined.states;
        }

        if statement.tag == 5 {
            mut assigned := mir_native_structured_cfg_apply_assignment(
                result.model,
                result.states,
                statement,
                ctx
            );
            if assigned.invalid == 1 || assigned.represented == 0 {
                return assigned;
            }
            result.model = assigned.model;
            result.states = assigned.states;
            statement_index = statement_index + 1;
            continue;
        }

        if statement.tag == 7 {
            unsafe {
                mut consequence := ctx[statement.If.consequence];
                mut alternative := ctx[statement.If.alternative];
                mut then_statements:
                    std.Vector[ast.Statement[ctx], ctx] :=
                        ctx[consequence.statements];
                mut else_statements:
                    std.Vector[ast.Statement[ctx], ctx] :=
                        ctx[alternative.statements];
                mut source_state := result.states[0];
                mut condition := ctx[statement.If.condition];
                mut condition_local :=
                    mir_native_structured_cfg_condition_local(
                        condition,
                        result.model,
                        source_state.initialized,
                        ctx
                    );
                if condition_local == 0 - 2 {
                    result.invalid = 1;
                    result.diagnostic =
                        local_state.mir_native_local_state_invalid_diagnostic(
                            1,
                            ctx
                        );
                    return result;
                }
                if condition_local == 0 - 3 {
                    result.invalid = 1;
                    result.diagnostic =
                        local_state.mir_native_local_state_invalid_diagnostic(
                            2,
                            ctx
                        );
                    return result;
                }
                if condition_local < 0 {
                    result.represented = 0;
                    return result;
                }

                mut then_index := len(result.model.blocks);
                result.model.blocks.Push(
                    mir_native_structured_cfg_empty_block(ctx)
                );
                mut else_index := len(result.model.blocks);
                result.model.blocks.Push(
                    mir_native_structured_cfg_empty_block(ctx)
                );
                mut source_block :=
                    result.model.blocks[source_state.block_index];
                if source_block.terminator_kind != 0 {
                    result.invalid = 1;
                    result.diagnostic = std.Clone(
                        ctx,
                        "Native backend internal error: structured CFG branch source already has a terminator"
                    );
                    return result;
                }
                source_block.terminator_kind = 3;
                source_block.condition_local_index = condition_local;
                source_block.first_target_index = then_index;
                source_block.second_target_index = else_index;
                result.model.blocks.Set(
                    source_state.block_index,
                    source_block
                );
                result.model.branch_count =
                    result.model.branch_count + 1;
                if branch_depth + 1 >
                   result.model.maximum_branch_depth
                {
                    result.model.maximum_branch_depth = branch_depth + 1;
                }

                mut condition_value :=
                    source_state.values[condition_local];
                mut then_selected := 0;
                mut else_selected := 0;
                if source_state.selected == 1 {
                    if condition_value > 0 {
                        then_selected = 1;
                    } else {
                        else_selected = 1;
                    }
                }
                mut then_states:
                    std.Vector[MirNativeStructuredCfgState[ctx], ctx] :=
                        std.VectorNew(ctx);
                then_states.Push(
                    mir_native_structured_cfg_make_state(
                        then_index,
                        local_state.mir_native_local_state_clone_ints(
                            source_state.values,
                            ctx
                        ),
                        local_state.mir_native_local_state_clone_ints(
                            source_state.initialized,
                            ctx
                        ),
                        then_selected
                    )
                );
                mut else_states:
                    std.Vector[MirNativeStructuredCfgState[ctx], ctx] :=
                        std.VectorNew(ctx);
                else_states.Push(
                    mir_native_structured_cfg_make_state(
                        else_index,
                        local_state.mir_native_local_state_clone_ints(
                            source_state.values,
                            ctx
                        ),
                        local_state.mir_native_local_state_clone_ints(
                            source_state.initialized,
                            ctx
                        ),
                        else_selected
                    )
                );

                mut then_result :=
                    mir_native_structured_cfg_lower_sequence(
                        then_statements,
                        then_states,
                        result.model,
                        branch_depth + 1,
                        ctx
                    );
                if then_result.invalid == 1 ||
                   then_result.represented == 0
                {
                    return then_result;
                }
                mut else_result :=
                    mir_native_structured_cfg_lower_sequence(
                        else_statements,
                        else_states,
                        then_result.model,
                        branch_depth + 1,
                        ctx
                    );
                if else_result.invalid == 1 ||
                   else_result.represented == 0
                {
                    return else_result;
                }

                mut branch_states := else_result.states;
                mut then_state_index := 0;
                while then_state_index < len(then_result.states) {
                    branch_states.Push(
                        then_result.states[then_state_index]
                    );
                    then_state_index = then_state_index + 1;
                }
                result.model = else_result.model;
                result.states = branch_states;
                statement_index = statement_index + 1;
                continue;
            }
        }

        if statement.tag == 12 {
            if statement_index + 1 != len(statements) {
                result.represented = 0;
                return result;
            }
            unsafe {
                mut return_expression := ctx[statement.Return.expr];
                if return_expression.tag != 0 {
                    result.represented = 0;
                    return result;
                }
                mut return_local_index :=
                    local_state.mir_native_local_state_find_local(
                        result.model.local_names,
                        return_expression.Identifier.name
                    );
                if return_local_index < 0 {
                    result.invalid = 1;
                    result.diagnostic =
                        local_state.mir_native_local_state_invalid_diagnostic(
                            1,
                            ctx
                        );
                    return result;
                }

                mut return_state_index := 0;
                while return_state_index < len(result.states) {
                    mut return_state := result.states[return_state_index];
                    if return_state.initialized[return_local_index] == 0 {
                        result.invalid = 1;
                        result.diagnostic =
                            local_state.mir_native_local_state_invalid_diagnostic(
                                2,
                                ctx
                            );
                        return result;
                    }
                    mut return_block :=
                        result.model.blocks[return_state.block_index];
                    if return_block.terminator_kind != 0 {
                        result.invalid = 1;
                        result.diagnostic = std.Clone(
                            ctx,
                            "Native backend internal error: structured CFG return block already has a terminator"
                        );
                        return result;
                    }
                    return_block.terminator_kind = 1;
                    return_block.return_local_index =
                        return_local_index;
                    result.model.blocks.Set(
                        return_state.block_index,
                        return_block
                    );
                    if return_state.selected == 1 {
                        result.model.expected_exit =
                            return_state.values[return_local_index];
                        result.model.expected_exit_set = 1;
                    }
                    return_state_index = return_state_index + 1;
                }
                result.states = std.VectorNew(ctx);
                statement_index = statement_index + 1;
                continue;
            }
        }

        result.represented = 0;
        return result;
    }
    return result;
}

func mir_native_structured_cfg_analyze(
    programs: std.Vector[ast.Program[ctx], ctx],
    module_paths: std.Vector[str, ctx],
    module_prefixes: std.Vector[str, ctx],
    ctx: &Arena
) MirNativeStructuredCfgModel[ctx] {
    mut model := mir_native_structured_cfg_empty_model(ctx);
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
       mir_native_structured_cfg_function_is_entry(
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
        model.source_path = std.Clone(ctx, module_paths[0]);
        model.blocks.Push(
            mir_native_structured_cfg_empty_block(ctx)
        );

        mut first_control_statement := 0;
        while first_control_statement < len(statements) &&
              statements[first_control_statement].tag == 4
        {
            mut declaration := statements[first_control_statement];
            if local_state.mir_native_local_state_declared_type_is_int(
                declaration,
                ctx
            ) == 0 {
                return mir_native_structured_cfg_empty_model(ctx);
            }
            if local_state.mir_native_local_state_find_local(
                model.local_names,
                declaration.VarDecl.name
            ) >= 0 {
                model.represented = 1;
                model.invalid = 1;
                model.diagnostic =
                    local_state.mir_native_local_state_invalid_diagnostic(
                        1,
                        ctx
                    );
                return model;
            }

            mut local_index := len(model.local_names);
            model.local_names.Push(
                std.Clone(ctx, declaration.VarDecl.name)
            );
            model.local_values.Push(0);
            model.local_initialized.Push(0);
            model.local_mutable.Push(declaration.VarDecl.is_mut);
            model.provenance.Push(
                local_state.mir_native_local_state_make_provenance(
                    0,
                    local_index,
                    0,
                    0 - 1
                )
            );

            if declaration.VarDecl.value !=
               empty[Index[ast.Expression[ctx], ctx]]
            {
                mut initializer := ctx[declaration.VarDecl.value];
                mut lowered_initializer :=
                    local_state.mir_native_local_state_expression(
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
                        local_state.mir_native_local_state_invalid_diagnostic(
                            lowered_initializer.failure_tag,
                            ctx
                        );
                    return model;
                }
                if lowered_initializer.represented == 0 {
                    return mir_native_structured_cfg_empty_model(ctx);
                }
                mut entry_block := model.blocks[0];
                entry_block.writes.Push(
                    local_state.mir_native_local_state_make_write(
                        local_index,
                        0,
                        lowered_initializer.value
                    )
                );
                model.blocks.Set(0, entry_block);
                model.local_values.Set(
                    local_index,
                    lowered_initializer.value
                );
                model.local_initialized.Set(local_index, 1);
            }
            first_control_statement = first_control_statement + 1;
        }

        if len(model.local_names) == 0 ||
           first_control_statement >= len(statements)
        {
            return mir_native_structured_cfg_empty_model(ctx);
        }

        mut remaining_statements:
            std.Vector[ast.Statement[ctx], ctx] := std.VectorNew(ctx);
        mut remaining_index := first_control_statement;
        while remaining_index < len(statements) {
            remaining_statements.Push(statements[remaining_index]);
            remaining_index = remaining_index + 1;
        }
        mut initial_states:
            std.Vector[MirNativeStructuredCfgState[ctx], ctx] :=
                std.VectorNew(ctx);
        initial_states.Push(
            mir_native_structured_cfg_make_state(
                0,
                local_state.mir_native_local_state_clone_ints(
                    model.local_values,
                    ctx
                ),
                local_state.mir_native_local_state_clone_ints(
                    model.local_initialized,
                    ctx
                ),
                1
            )
        );
        mut lowered := mir_native_structured_cfg_lower_sequence(
            remaining_statements,
            initial_states,
            model,
            0,
            ctx
        );
        if lowered.invalid == 1 {
            lowered.model.represented = 1;
            lowered.model.invalid = 1;
            lowered.model.diagnostic = lowered.diagnostic;
            return lowered.model;
        }
        if lowered.represented == 0 ||
           len(lowered.states) != 0 ||
           lowered.model.expected_exit_set == 0 ||
           lowered.model.branch_count < 2
        {
            return mir_native_structured_cfg_empty_model(ctx);
        }

        mut block_index := 0;
        while block_index < len(lowered.model.blocks) {
            if lowered.model.blocks[block_index].terminator_kind == 0 {
                lowered.model.represented = 1;
                lowered.model.invalid = 1;
                lowered.model.diagnostic = std.Clone(
                    ctx,
                    "Native backend internal error: structured CFG block has no terminator"
                );
                return lowered.model;
            }
            block_index = block_index + 1;
        }
        lowered.model.represented = 1;
        return lowered.model;
    }
}

func mir_native_structured_cfg_emit_block(
    output: str,
    block_index: int,
    block: MirNativeStructuredCfgBlock[ctx],
    local_names: std.Vector[str, ctx],
    ctx: &Arena
) str {
    mut label := mir_native_structured_cfg_block_label(
        block_index,
        ctx
    );
    mut emitted :=
        local_state.mir_native_local_state_emit_block_header_and_writes(
            output,
            block_index,
            label,
            block.writes,
            local_names,
            ctx
        );
    emitted = mir_native_structured_cfg_append(
        emitted,
        "block_",
        ctx
    );
    emitted = mir_native_structured_cfg_append_int(
        emitted,
        block_index,
        ctx
    );

    if block.terminator_kind == 1 {
        emitted = mir_native_structured_cfg_append(
            emitted,
            "_terminator_kind: ReturnLocalI32\nblock_",
            ctx
        );
        emitted = mir_native_structured_cfg_append_int(
            emitted,
            block_index,
            ctx
        );
        emitted = mir_native_structured_cfg_append(
            emitted,
            "_terminator_local: ",
            ctx
        );
        emitted = mir_native_structured_cfg_append(
            emitted,
            local_names[block.return_local_index],
            ctx
        );
        return mir_native_structured_cfg_append(
            emitted,
            "\n",
            ctx
        );
    }

    if block.terminator_kind == 2 {
        emitted = mir_native_structured_cfg_append(
            emitted,
            "_terminator_kind: Jump\nblock_",
            ctx
        );
        emitted = mir_native_structured_cfg_append_int(
            emitted,
            block_index,
            ctx
        );
        emitted = mir_native_structured_cfg_append(
            emitted,
            "_terminator_target: ",
            ctx
        );
        emitted = mir_native_structured_cfg_append(
            emitted,
            mir_native_structured_cfg_block_label(
                block.first_target_index,
                ctx
            ),
            ctx
        );
        emitted = mir_native_structured_cfg_append(
            emitted,
            "\nblock_",
            ctx
        );
        emitted = mir_native_structured_cfg_append_int(
            emitted,
            block_index,
            ctx
        );
        return mir_native_structured_cfg_append(
            emitted,
            "_terminator_argument_count: 0\n",
            ctx
        );
    }

    emitted = mir_native_structured_cfg_append(
        emitted,
        "_terminator_kind: BranchLocalI32Positive\nblock_",
        ctx
    );
    emitted = mir_native_structured_cfg_append_int(
        emitted,
        block_index,
        ctx
    );
    emitted = mir_native_structured_cfg_append(
        emitted,
        "_terminator_local: ",
        ctx
    );
    emitted = mir_native_structured_cfg_append(
        emitted,
        local_names[block.condition_local_index],
        ctx
    );
    emitted = mir_native_structured_cfg_append(
        emitted,
        "\nblock_",
        ctx
    );
    emitted = mir_native_structured_cfg_append_int(
        emitted,
        block_index,
        ctx
    );
    emitted = mir_native_structured_cfg_append(
        emitted,
        "_terminator_then: ",
        ctx
    );
    emitted = mir_native_structured_cfg_append(
        emitted,
        mir_native_structured_cfg_block_label(
            block.first_target_index,
            ctx
        ),
        ctx
    );
    emitted = mir_native_structured_cfg_append(
        emitted,
        "\nblock_",
        ctx
    );
    emitted = mir_native_structured_cfg_append_int(
        emitted,
        block_index,
        ctx
    );
    emitted = mir_native_structured_cfg_append(
        emitted,
        "_terminator_then_argument_count: 0\nblock_",
        ctx
    );
    emitted = mir_native_structured_cfg_append_int(
        emitted,
        block_index,
        ctx
    );
    emitted = mir_native_structured_cfg_append(
        emitted,
        "_terminator_else: ",
        ctx
    );
    emitted = mir_native_structured_cfg_append(
        emitted,
        mir_native_structured_cfg_block_label(
            block.second_target_index,
            ctx
        ),
        ctx
    );
    emitted = mir_native_structured_cfg_append(
        emitted,
        "\nblock_",
        ctx
    );
    emitted = mir_native_structured_cfg_append_int(
        emitted,
        block_index,
        ctx
    );
    return mir_native_structured_cfg_append(
        emitted,
        "_terminator_else_argument_count: 0\n",
        ctx
    );
}

func mir_native_structured_cfg_emit_metadata(
    output: str,
    model: MirNativeStructuredCfgModel[ctx],
    ctx: &Arena
) str {
    mut emitted := mir_native_structured_cfg_append(
        output,
        "metadata_count: ",
        ctx
    );
    emitted = mir_native_structured_cfg_append_int(
        emitted,
        len(model.provenance) + 1,
        ctx
    );
    emitted = mir_native_structured_cfg_append(emitted, "\n", ctx);

    mut metadata_index := 0;
    while metadata_index < len(model.provenance) {
        mut event := model.provenance[metadata_index];
        emitted = mir_native_structured_cfg_append(
            emitted,
            "metadata_",
            ctx
        );
        emitted = mir_native_structured_cfg_append_int(
            emitted,
            metadata_index,
            ctx
        );
        emitted = mir_native_structured_cfg_append(
            emitted,
            "_kind: provenance\nmetadata_",
            ctx
        );
        emitted = mir_native_structured_cfg_append_int(
            emitted,
            metadata_index,
            ctx
        );
        emitted = mir_native_structured_cfg_append(
            emitted,
            "_attachment: ",
            ctx
        );
        if event.event_kind == 0 {
            emitted = mir_native_structured_cfg_append(
                emitted,
                "local:",
                ctx
            );
            emitted = mir_native_structured_cfg_append_int(
                emitted,
                event.local_index,
                ctx
            );
        } else {
            emitted = mir_native_structured_cfg_append(
                emitted,
                "statement:",
                ctx
            );
            emitted = mir_native_structured_cfg_append(
                emitted,
                mir_native_structured_cfg_block_label(
                    event.block_index,
                    ctx
                ),
                ctx
            );
            emitted = mir_native_structured_cfg_append(
                emitted,
                ":",
                ctx
            );
            emitted = mir_native_structured_cfg_append_int(
                emitted,
                event.statement_index,
                ctx
            );
        }
        emitted = mir_native_structured_cfg_append(
            emitted,
            "\nmetadata_",
            ctx
        );
        emitted = mir_native_structured_cfg_append_int(
            emitted,
            metadata_index,
            ctx
        );
        emitted = mir_native_structured_cfg_append(
            emitted,
            "_policy: recognized_preserved\nmetadata_",
            ctx
        );
        emitted = mir_native_structured_cfg_append_int(
            emitted,
            metadata_index,
            ctx
        );
        emitted = mir_native_structured_cfg_append(
            emitted,
            "_payload: kind=",
            ctx
        );
        if event.event_kind == 0 {
            emitted = mir_native_structured_cfg_append(
                emitted,
                "LocalDeclaration",
                ctx
            );
        } else {
            emitted = mir_native_structured_cfg_append(
                emitted,
                "LocalAssignment",
                ctx
            );
        }
        emitted = mir_native_structured_cfg_append(
            emitted,
            ";local=",
            ctx
        );
        emitted = mir_native_structured_cfg_append(
            emitted,
            model.local_names[event.local_index],
            ctx
        );
        emitted = mir_native_structured_cfg_append(
            emitted,
            ";index=",
            ctx
        );
        emitted = mir_native_structured_cfg_append_int(
            emitted,
            event.local_index,
            ctx
        );
        emitted = mir_native_structured_cfg_append(
            emitted,
            ";origin=",
            ctx
        );
        emitted = mir_native_structured_cfg_append(
            emitted,
            model.source_path,
            ctx
        );
        emitted = mir_native_structured_cfg_append(
            emitted,
            "\n",
            ctx
        );
        metadata_index = metadata_index + 1;
    }

    emitted = mir_native_structured_cfg_append(
        emitted,
        "metadata_",
        ctx
    );
    emitted = mir_native_structured_cfg_append_int(
        emitted,
        metadata_index,
        ctx
    );
    emitted = mir_native_structured_cfg_append(
        emitted,
        "_kind: provenance\nmetadata_",
        ctx
    );
    emitted = mir_native_structured_cfg_append_int(
        emitted,
        metadata_index,
        ctx
    );
    emitted = mir_native_structured_cfg_append(
        emitted,
        "_attachment: function\nmetadata_",
        ctx
    );
    emitted = mir_native_structured_cfg_append_int(
        emitted,
        metadata_index,
        ctx
    );
    emitted = mir_native_structured_cfg_append(
        emitted,
        "_policy: recognized_preserved\nmetadata_",
        ctx
    );
    emitted = mir_native_structured_cfg_append_int(
        emitted,
        metadata_index,
        ctx
    );
    emitted = mir_native_structured_cfg_append(
        emitted,
        "_payload: kind=StructuredCfg;reducibility=acyclic;block_count=",
        ctx
    );
    emitted = mir_native_structured_cfg_append_int(
        emitted,
        len(model.blocks),
        ctx
    );
    return mir_native_structured_cfg_append(emitted, "\n", ctx);
}

func mir_native_structured_cfg_emit_bundle(
    model: MirNativeStructuredCfgModel[ctx],
    ctx: &Arena
) mir.MirProgramBundle[ctx] {
    mut canonical :=
        "format: gust.compiler_mir_ingestion.v1\nfunction: main\nbackend_symbol: main\nparameter_count: 0\nreturn_type: int\nlocal_count: ";
    canonical = mir_native_structured_cfg_append_int(
        canonical,
        len(model.local_names),
        ctx
    );
    canonical = mir_native_structured_cfg_append(canonical, "\n", ctx);

    mut local_index := 0;
    while local_index < len(model.local_names) {
        canonical = mir_native_structured_cfg_append(
            canonical,
            "local_",
            ctx
        );
        canonical = mir_native_structured_cfg_append_int(
            canonical,
            local_index,
            ctx
        );
        canonical = mir_native_structured_cfg_append(
            canonical,
            "_name: ",
            ctx
        );
        canonical = mir_native_structured_cfg_append(
            canonical,
            model.local_names[local_index],
            ctx
        );
        canonical = mir_native_structured_cfg_append(
            canonical,
            "\nlocal_",
            ctx
        );
        canonical = mir_native_structured_cfg_append_int(
            canonical,
            local_index,
            ctx
        );
        canonical = mir_native_structured_cfg_append(
            canonical,
            "_type: int\n",
            ctx
        );
        local_index = local_index + 1;
    }

    canonical = mir_native_structured_cfg_append(
        canonical,
        "entry_block: cfg_0\nblock_count: ",
        ctx
    );
    canonical = mir_native_structured_cfg_append_int(
        canonical,
        len(model.blocks),
        ctx
    );
    canonical = mir_native_structured_cfg_append(canonical, "\n", ctx);

    mut block_index := 0;
    while block_index < len(model.blocks) {
        canonical = mir_native_structured_cfg_emit_block(
            canonical,
            block_index,
            model.blocks[block_index],
            model.local_names,
            ctx
        );
        block_index = block_index + 1;
    }

    canonical = mir_native_structured_cfg_emit_metadata(
        canonical,
        model,
        ctx
    );
    canonical = mir_native_structured_cfg_append(
        canonical,
        "expected_exit: ",
        ctx
    );
    canonical = mir_native_structured_cfg_append_int(
        canonical,
        model.expected_exit,
        ctx
    );
    canonical = mir_native_structured_cfg_append(canonical, "\n", ctx);

    mut bundle := mir.mir_make_program_bundle("main", ctx);
    mut bundle_module := mir.mir_make_program_bundle_module(
        model.source_path,
        "",
        "phase11_structured_cfg_module.o",
        "gust.compiler_mir_ingestion.v1",
        canonical,
        0,
        len(model.provenance) + 1,
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

func mir_native_structured_cfg_source_lower(
    programs: std.Vector[ast.Program[ctx], ctx],
    module_paths: std.Vector[str, ctx],
    module_prefixes: std.Vector[str, ctx],
    ctx: &Arena
) MirNativeStructuredCfgSourceResult[ctx] {
    mut result := mir_native_structured_cfg_empty_source_result(ctx);
    mut model := mir_native_structured_cfg_analyze(
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
    result.bundle = mir_native_structured_cfg_emit_bundle(model, ctx);
    return result;
}