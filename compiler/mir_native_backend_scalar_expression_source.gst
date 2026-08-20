import "ast.gst" as ast;
import "mir.gst" as mir;
import "mir_native_backend_metadata_source.gst" as metadata_source;

// Phase 13 compiler-owned bounded scalar-expression lowering.
//
// This lowerer consumes typed AST structure only. It accepts a deliberately
// small left-associated grammar whose first operand and every right operand are
// bounded non-negative i32 literals:
//
//   expression := literal (("+" | "-" | "*") literal)*
//
// At least one selected Phase 13 operation (`-` or `*`) must be present. The
// existing add-only route remains owned by the Phase 11 generic scalar model.
// Every intermediate result must remain in 0..255, which preserves the existing
// scalar model without adding wider layout, target-dependent casts, or a new
// overflow policy. A comparison form may use the bounded expression as the
// left side of `> 0` and return one literal from each branch.
type MirNativeScalarExpressionStepKind enum {
    AddI32Literal,
    SubI32Literal,
    MulI32Literal
}

type MirNativeScalarExpressionStep struct {
    kind: MirNativeScalarExpressionStepKind,
    value: int
}

type MirNativeScalarExpressionPlan[ctx] struct {
    represented: int,
    source_path: str,
    initial_value: int,
    expected_value: int,
    add_count: int,
    sub_count: int,
    mul_count: int,
    steps: std.Vector[MirNativeScalarExpressionStep, ctx]
}

type MirNativeScalarExpressionModel[ctx] struct {
    represented: int,
    source_path: str,
    source_line: int,
    source_column: int,
    plan: MirNativeScalarExpressionPlan[ctx],
    is_comparison_branch: int,
    then_value: int,
    else_value: int
}

type MirNativeScalarExpressionSourceResult[ctx] struct {
    represented: int,
    invalid: int,
    diagnostic: str,
    bundle: mir.MirProgramBundle[ctx]
}

func mir_native_scalar_expression_empty_plan(
    ctx: &Arena
) MirNativeScalarExpressionPlan[ctx] {
    mut plan: MirNativeScalarExpressionPlan[ctx];
    plan.represented = 0;
    plan.source_path = std.Clone(ctx, "");
    plan.initial_value = 0;
    plan.expected_value = 0;
    plan.add_count = 0;
    plan.sub_count = 0;
    plan.mul_count = 0;
    plan.steps = std.VectorNew(ctx);
    return plan;
}

func mir_native_scalar_expression_empty_model(
    ctx: &Arena
) MirNativeScalarExpressionModel[ctx] {
    mut model: MirNativeScalarExpressionModel[ctx];
    model.represented = 0;
    model.source_path = std.Clone(ctx, "");
    model.source_line = 0;
    model.source_column = 0;
    model.plan = mir_native_scalar_expression_empty_plan(ctx);
    model.is_comparison_branch = 0;
    model.then_value = 0;
    model.else_value = 0;
    return model;
}

func mir_native_scalar_expression_result(
    represented: int,
    invalid: int,
    diagnostic: str,
    bundle: mir.MirProgramBundle[ctx],
    ctx: &Arena
) MirNativeScalarExpressionSourceResult[ctx] {
    mut result: MirNativeScalarExpressionSourceResult[ctx];
    result.represented = represented;
    result.invalid = invalid;
    result.diagnostic = std.Clone(ctx, diagnostic);
    result.bundle = bundle;
    return result;
}

func mir_native_scalar_expression_value_is_bounded(value: int) int {
    if value < 0 || value > 255 {
        return 0;
    }
    return 1;
}

func mir_native_scalar_expression_step(
    kind_tag: int,
    value: int
) MirNativeScalarExpressionStep {
    mut step: MirNativeScalarExpressionStep;
    unsafe {
        step.kind.tag = kind_tag;
    }
    step.value = value;
    return step;
}

func mir_native_scalar_expression_plan(
    expression: ast.Expression[ctx],
    ctx: &Arena
) MirNativeScalarExpressionPlan[ctx] {
    mut empty_plan := mir_native_scalar_expression_empty_plan(ctx);
    unsafe {
        if expression.tag == 1 {
            if mir_native_scalar_expression_value_is_bounded(
                expression.Integer.val
            ) == 0 {
                return empty_plan;
            }
            empty_plan.represented = 1;
            empty_plan.initial_value = expression.Integer.val;
            empty_plan.expected_value = expression.Integer.val;
            return empty_plan;
        }

        if expression.tag != 10 {
            return empty_plan;
        }

        mut left_expression := ctx[expression.Binary.left];
        mut right_expression := ctx[expression.Binary.right];
        if right_expression.tag != 1 ||
           mir_native_scalar_expression_value_is_bounded(
               right_expression.Integer.val
           ) == 0
        {
            return empty_plan;
        }

        mut left_plan :=
            mir_native_scalar_expression_plan(left_expression, ctx);
        if left_plan.represented == 0 {
            return empty_plan;
        }

        mut right_value := right_expression.Integer.val;
        mut next_value := left_plan.expected_value;
        mut step_kind_tag := 0;
        if std.str_eq(expression.Binary.op, "+") == 1 {
            next_value = left_plan.expected_value + right_value;
            step_kind_tag = 0;
        } else if std.str_eq(expression.Binary.op, "-") == 1 {
            next_value = left_plan.expected_value - right_value;
            step_kind_tag = 1;
        } else if std.str_eq(expression.Binary.op, "*") == 1 {
            next_value = left_plan.expected_value * right_value;
            step_kind_tag = 2;
        } else {
            return empty_plan;
        }

        if mir_native_scalar_expression_value_is_bounded(next_value) == 0 {
            return empty_plan;
        }

        left_plan.steps.Push(
            mir_native_scalar_expression_step(
                step_kind_tag,
                right_value
            )
        );
        left_plan.expected_value = next_value;
        if step_kind_tag == 0 {
            left_plan.add_count = left_plan.add_count + 1;
        } else if step_kind_tag == 1 {
            left_plan.sub_count = left_plan.sub_count + 1;
        } else {
            left_plan.mul_count = left_plan.mul_count + 1;
        }
        return left_plan;
    }
}

func mir_native_scalar_expression_selected(
    plan: MirNativeScalarExpressionPlan[ctx]
) int {
    if plan.represented == 1 &&
       plan.sub_count + plan.mul_count > 0
    {
        return 1;
    }
    return 0;
}

func mir_native_scalar_expression_return_literal(
    statement: ast.Statement[ctx],
    ctx: &Arena
) int {
    unsafe {
        if statement.tag != 12 {
            return 0 - 1;
        }
        mut expression := ctx[statement.Return.expr];
        if expression.tag != 1 ||
           mir_native_scalar_expression_value_is_bounded(
               expression.Integer.val
           ) == 0
        {
            return 0 - 1;
        }
        return expression.Integer.val;
    }
}

func mir_native_scalar_expression_entry_function(
    statement: ast.Statement[ctx],
    ctx: &Arena
) int {
    unsafe {
        if statement.tag != 3 ||
           std.str_eq(statement.FunctionDecl.name, "main") == 0 ||
           statement.FunctionDecl.is_extern == 1
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

func mir_native_scalar_expression_analyze_function(
    statement: ast.Statement[ctx],
    source_path: str,
    ctx: &Arena
) MirNativeScalarExpressionModel[ctx] {
    mut model := mir_native_scalar_expression_empty_model(ctx);
    if mir_native_scalar_expression_entry_function(
        statement,
        ctx
    ) == 0 {
        return model;
    }

    unsafe {
        model.source_line = statement.FunctionDecl.span.start.line;
        model.source_column = statement.FunctionDecl.span.start.column;
        mut body := ctx[statement.FunctionDecl.body];
        mut statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[body.statements];
        if len(statements) != 1 {
            return model;
        }

        mut only_statement := statements[0];
        if only_statement.tag == 12 {
            mut return_expression := ctx[only_statement.Return.expr];
            mut return_plan :=
                mir_native_scalar_expression_plan(
                    return_expression,
                    ctx
                );
            if mir_native_scalar_expression_selected(return_plan) == 0 {
                return model;
            }
            return_plan.source_path = std.Clone(ctx, source_path);
            model.represented = 1;
            model.source_path = std.Clone(ctx, source_path);
            model.plan = return_plan;
            return model;
        }

        if only_statement.tag != 7 {
            return model;
        }

        mut condition := ctx[only_statement.If.condition];
        if condition.tag != 10 ||
           std.str_eq(condition.Binary.op, ">") == 0
        {
            return model;
        }
        mut condition_right := ctx[condition.Binary.right];
        if condition_right.tag != 1 ||
           condition_right.Integer.val != 0
        {
            return model;
        }
        mut condition_left := ctx[condition.Binary.left];
        mut condition_plan :=
            mir_native_scalar_expression_plan(
                condition_left,
                ctx
            );
        if mir_native_scalar_expression_selected(
            condition_plan
        ) == 0 {
            return model;
        }

        mut consequence := ctx[only_statement.If.consequence];
        mut alternative := ctx[only_statement.If.alternative];
        mut then_statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[consequence.statements];
        mut else_statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[alternative.statements];
        if len(then_statements) != 1 ||
           len(else_statements) != 1
        {
            return model;
        }

        mut then_value :=
            mir_native_scalar_expression_return_literal(
                then_statements[0],
                ctx
            );
        mut else_value :=
            mir_native_scalar_expression_return_literal(
                else_statements[0],
                ctx
            );
        if then_value < 0 || else_value < 0 {
            return model;
        }

        condition_plan.source_path = std.Clone(ctx, source_path);
        model.represented = 1;
        model.source_path = std.Clone(ctx, source_path);
        model.plan = condition_plan;
        model.is_comparison_branch = 1;
        model.then_value = then_value;
        model.else_value = else_value;
        return model;
    }
}

func mir_native_scalar_expression_analyze(
    programs: std.Vector[ast.Program[ctx], ctx],
    module_paths: std.Vector[str, ctx],
    module_prefixes: std.Vector[str, ctx],
    ctx: &Arena
) MirNativeScalarExpressionModel[ctx] {
    mut model := mir_native_scalar_expression_empty_model(ctx);
    mut module_index := 0;
    while module_index < len(programs) &&
          module_index < len(module_paths) &&
          module_index < len(module_prefixes)
    {
        if std.str_eq(module_prefixes[module_index], "") == 1 {
            mut top_level: std.Vector[ast.Statement[ctx], ctx] :=
                ctx[programs[module_index].statements];
            if len(top_level) != 1 {
                return model;
            }
            return mir_native_scalar_expression_analyze_function(
                top_level[0],
                module_paths[module_index],
                ctx
            );
        }
        module_index = module_index + 1;
    }
    return model;
}

func mir_native_scalar_expression_append(
    output: str,
    value: str,
    ctx: &Arena
) str {
    return std.Clone(ctx, std.Concat(output, value));
}

func mir_native_scalar_expression_append_int(
    output: str,
    value: int,
    ctx: &Arena
) str {
    mut formatted := std.FormatInt(value);
    return std.Clone(ctx, std.Concat(output, formatted));
}

func mir_native_scalar_expression_step_kind_name(
    step: MirNativeScalarExpressionStep
) str {
    if step.kind.tag == 0 {
        return "LocalI32AddI32Literal";
    }
    if step.kind.tag == 1 {
        return "LocalI32SubI32Literal";
    }
    return "LocalI32MulI32Literal";
}

func mir_native_scalar_expression_emit(
    model: MirNativeScalarExpressionModel[ctx],
    ctx: &Arena
) mir.MirProgramBundle[ctx] {
    mut statement_count := len(model.plan.steps) + 1;
    mut canonical :=
        "format: gust.compiler_mir_ingestion.v1\nfunction: main\nbackend_symbol: main\nparameter_count: 0\nreturn_type: int\nlocal_count: 1\nlocal_0_name: __gust_phase13_scalar_tmp\nlocal_0_type: int\nentry_block: entry\n";
    if model.is_comparison_branch == 1 {
        canonical = mir_native_scalar_expression_append(
            canonical,
            "block_count: 3\n",
            ctx
        );
    } else {
        canonical = mir_native_scalar_expression_append(
            canonical,
            "block_count: 1\n",
            ctx
        );
    }
    canonical = mir_native_scalar_expression_append(
        canonical,
        "block_0_label: entry\nblock_0_parameter_count: 0\nblock_0_statement_count: ",
        ctx
    );
    canonical = mir_native_scalar_expression_append_int(
        canonical,
        statement_count,
        ctx
    );
    canonical = mir_native_scalar_expression_append(
        canonical,
        "\nblock_0_statement_0_kind: LocalI32Set\nblock_0_statement_0_local: __gust_phase13_scalar_tmp\nblock_0_statement_0_value: ",
        ctx
    );
    canonical = mir_native_scalar_expression_append_int(
        canonical,
        model.plan.initial_value,
        ctx
    );
    canonical = mir_native_scalar_expression_append(
        canonical,
        "\n",
        ctx
    );

    mut step_index := 0;
    while step_index < len(model.plan.steps) {
        mut statement_index := step_index + 1;
        mut step := model.plan.steps[step_index];
        canonical = mir_native_scalar_expression_append(
            canonical,
            "block_0_statement_",
            ctx
        );
        canonical = mir_native_scalar_expression_append_int(
            canonical,
            statement_index,
            ctx
        );
        canonical = mir_native_scalar_expression_append(
            canonical,
            "_kind: ",
            ctx
        );
        canonical = mir_native_scalar_expression_append(
            canonical,
            mir_native_scalar_expression_step_kind_name(step),
            ctx
        );
        canonical = mir_native_scalar_expression_append(
            canonical,
            "\nblock_0_statement_",
            ctx
        );
        canonical = mir_native_scalar_expression_append_int(
            canonical,
            statement_index,
            ctx
        );
        canonical = mir_native_scalar_expression_append(
            canonical,
            "_local: __gust_phase13_scalar_tmp\nblock_0_statement_",
            ctx
        );
        canonical = mir_native_scalar_expression_append_int(
            canonical,
            statement_index,
            ctx
        );
        canonical = mir_native_scalar_expression_append(
            canonical,
            "_value: ",
            ctx
        );
        canonical = mir_native_scalar_expression_append_int(
            canonical,
            step.value,
            ctx
        );
        canonical = mir_native_scalar_expression_append(
            canonical,
            "\n",
            ctx
        );
        step_index = step_index + 1;
    }

    mut expected_exit := model.plan.expected_value;
    if model.is_comparison_branch == 1 {
        expected_exit = model.else_value;
        if model.plan.expected_value > 0 {
            expected_exit = model.then_value;
        }
        canonical = mir_native_scalar_expression_append(
            canonical,
            "block_0_terminator_kind: BranchLocalI32Positive\nblock_0_terminator_local: __gust_phase13_scalar_tmp\nblock_0_terminator_then: positive\nblock_0_terminator_then_argument_count: 0\nblock_0_terminator_else: non_positive\nblock_0_terminator_else_argument_count: 0\nblock_1_label: positive\nblock_1_parameter_count: 0\nblock_1_statement_count: 0\nblock_1_terminator_kind: ReturnI32\nblock_1_terminator_value: ",
            ctx
        );
        canonical = mir_native_scalar_expression_append_int(
            canonical,
            model.then_value,
            ctx
        );
        canonical = mir_native_scalar_expression_append(
            canonical,
            "\nblock_2_label: non_positive\nblock_2_parameter_count: 0\nblock_2_statement_count: 0\nblock_2_terminator_kind: ReturnI32\nblock_2_terminator_value: ",
            ctx
        );
        canonical = mir_native_scalar_expression_append_int(
            canonical,
            model.else_value,
            ctx
        );
        canonical = mir_native_scalar_expression_append(
            canonical,
            "\n",
            ctx
        );
    } else {
        canonical = mir_native_scalar_expression_append(
            canonical,
            "block_0_terminator_kind: ReturnLocalI32\nblock_0_terminator_local: __gust_phase13_scalar_tmp\n",
            ctx
        );
    }

    canonical = mir_native_scalar_expression_append(
        canonical,
        "metadata_count: 1\nmetadata_0_kind: provenance\nmetadata_0_attachment: function\nmetadata_0_policy: recognized_preserved\n",
        ctx
    );
    canonical = metadata_source.mir_native_metadata_emit_contract(
        canonical,
        "metadata_0",
        model.source_path,
        model.source_line,
        model.source_column,
        "function",
        "validated_preserved",
        "preserved",
        "bounded_scalar_expression_shape_and_result_are_validated_before_lowering",
        ctx
    );
    canonical = mir_native_scalar_expression_append(
        canonical,
        "metadata_0_payload: kind=ScalarExpression;contract=phase13_2;codegen=preserved\nexpected_exit: ",
        ctx
    );
    canonical = mir_native_scalar_expression_append_int(
        canonical,
        expected_exit,
        ctx
    );
    canonical = mir_native_scalar_expression_append(
        canonical,
        "\n",
        ctx
    );

    mut bundle := mir.mir_make_program_bundle("main", ctx);
    mut module := mir.mir_make_program_bundle_module(
        model.source_path,
        "",
        "phase13_scalar_expression_module.o",
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
    return mir.mir_program_bundle_with_module(
        bundle,
        module,
        ctx
    );
}

func mir_native_scalar_expression_source_lower(
    programs: std.Vector[ast.Program[ctx], ctx],
    module_paths: std.Vector[str, ctx],
    module_prefixes: std.Vector[str, ctx],
    ctx: &Arena
) MirNativeScalarExpressionSourceResult[ctx] {
    mut model := mir_native_scalar_expression_analyze(
        programs,
        module_paths,
        module_prefixes,
        ctx
    );
    if model.represented == 0 {
        return mir_native_scalar_expression_result(
            0,
            0,
            "",
            mir.mir_make_program_bundle("invalid", ctx),
            ctx
        );
    }

    mut bundle := mir_native_scalar_expression_emit(model, ctx);
    if mir.mir_program_bundle_is_valid(bundle, ctx) == 0 {
        return mir_native_scalar_expression_result(
            0,
            1,
            "Native backend scalar-expression error: generated canonical MIR bundle is invalid",
            mir.mir_make_program_bundle("invalid", ctx),
            ctx
        );
    }
    return mir_native_scalar_expression_result(
        1,
        0,
        "",
        bundle,
        ctx
    );
}

// Compile-time evaluation of one bounded integer binary operation.
//
// Phase 13 already owns subtraction and multiplication here -- they are the
// operations this module lowers as SubI32Literal and MulI32Literal -- so the
// arithmetic that resolves them at compile time belongs here too, next to the
// lowering it mirrors. Callers that only need a folded literal ask for one and
// never learn which operator produced it.
//
// Division is absent: no phase has connected it, and a fold that resolved it
// would connect it by another name.
type MirNativeScalarConstBinary struct {
    known: int,
    value: int
}

func mir_native_scalar_const_binary(
    op: str,
    left: int,
    right: int
) MirNativeScalarConstBinary {
    mut folded: MirNativeScalarConstBinary;
    folded.known = 1;
    folded.value = 0;

    if std.str_eq(op, "+") == 1 {
        folded.value = left + right;
        return folded;
    }
    if std.str_eq(op, "-") == 1 {
        folded.value = left - right;
        return folded;
    }
    if std.str_eq(op, "*") == 1 {
        folded.value = left * right;
        return folded;
    }
    // Comparisons yield the canonical boolean values 0 and 1.
    if std.str_eq(op, "==") == 1 {
        if left == right { folded.value = 1; }
        return folded;
    }
    if std.str_eq(op, "!=") == 1 {
        if left != right { folded.value = 1; }
        return folded;
    }
    if std.str_eq(op, ">") == 1 {
        if left > right { folded.value = 1; }
        return folded;
    }
    if std.str_eq(op, "<") == 1 {
        if left < right { folded.value = 1; }
        return folded;
    }
    if std.str_eq(op, ">=") == 1 {
        if left >= right { folded.value = 1; }
        return folded;
    }
    if std.str_eq(op, "<=") == 1 {
        if left <= right { folded.value = 1; }
        return folded;
    }

    folded.known = 0;
    return folded;
}
