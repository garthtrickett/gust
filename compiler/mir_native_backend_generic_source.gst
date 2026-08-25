import "ast.gst" as ast;
import "mir.gst" as mir;
import "mir_native_backend_capability.gst" as capability;
import "mir_native_backend_collection_string_source.gst" as collection_string;
import "mir_native_backend_filesystem_allocation_source.gst" as filesystem_allocation;
import "mir_native_backend_block_parameter_loop_source.gst" as block_parameter_loop;
import "mir_native_backend_capability.gst" as capability;
import "mir_native_backend_direct_call_source.gst" as direct_call;
import "mir_native_backend_local_state_source.gst" as local_state;
import "mir_native_backend_metadata_source.gst" as metadata_source;
import "mir_native_backend_module_import_source.gst" as module_import;
import "mir_native_backend_parameter_argument_source.gst" as parameter_argument;
import "mir_native_backend_structured_cfg_source.gst" as structured_cfg;
import "mir_native_backend_scalar_expression_source.gst" as scalar_expression;

// Compiler-owned generic source-to-canonical-MIR route.
//
// This module consumes the resolver/parser/typechecker output that is already
// available to the compiler entry. It recognizes semantic AST structure only;
// it never compares source paths, fixture names, or raw source text. The
// canonical v1/v2 serialization labels remain byte-compatible with the closed
// Phase 10 evidence, but production routing no longer constructs or compares a
// legacy exact-shape bundle.
type MirNativeGenericEligibility enum {
    LoweredAndEligible,
    SourceFeatureNotRepresented,
    NativeCapabilityUnsupported,
    InvalidCanonicalMir
}

type MirNativeGenericShape enum {
    LiteralReturn,
    LocalReturn,
    LiteralBranch,
    LocalMerge,
    LocalCall,
    ImportedCall,
    ScalarExpression,
    PositiveLocalBranch
}

type MirNativeGenericModel[ctx] struct {
    represented: int,
    shape: MirNativeGenericShape,
    source_path: str,
    local_name: str,
    call_name: str,
    call_link_name: str,
    literal_value: int,
    condition_value: int,
    initial_value: int,
    then_value: int,
    else_value: int,
    scalar_literal_total: int,
    scalar_add_count: int,
    scalar_uses_source_local: int
}

type MirNativeGenericScalarExpression struct {
    represented: int,
    uses_local: int,
    literal_total: int,
    add_count: int
}

type MirNativeGenericSourceResult[ctx] struct {
    eligibility: MirNativeGenericEligibility,
    bundle: mir.MirProgramBundle[ctx],
    plan: capability.MirNativeBackendCapabilityPlan[ctx],
    diagnostic: str,
    reason_code: str
}

func mir_native_generic_append(output: str, value: str, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat(output, value));
}

func mir_native_generic_empty_model(ctx: &Arena) MirNativeGenericModel[ctx] {
    mut model: MirNativeGenericModel[ctx];
    model.represented = 0;
    unsafe {
        model.shape.tag = 0;
    }
    model.source_path = std.Clone(ctx, "");
    model.local_name = std.Clone(ctx, "");
    model.call_name = std.Clone(ctx, "");
    model.call_link_name = std.Clone(ctx, "");
    model.literal_value = 0;
    model.condition_value = 0;
    model.initial_value = 0;
    model.then_value = 0;
    model.else_value = 0;
    model.scalar_literal_total = 0;
    model.scalar_add_count = 0;
    model.scalar_uses_source_local = 0;
    return model;
}

func mir_native_generic_empty_scalar_expression() MirNativeGenericScalarExpression {
    mut expression: MirNativeGenericScalarExpression;
    expression.represented = 0;
    expression.uses_local = 0;
    expression.literal_total = 0;
    expression.add_count = 0;
    return expression;
}

func mir_native_generic_scalar_expression(
    expression: ast.Expression[ctx],
    allowed_local: str,
    ctx: &Arena
) MirNativeGenericScalarExpression {
    mut lowered := mir_native_generic_empty_scalar_expression();
    unsafe {
        if expression.tag == 1 {
            lowered.represented = 1;
            lowered.literal_total = expression.Integer.val;
            return lowered;
        }

        if expression.tag == 0 &&
           len(allowed_local) > 0 &&
           std.str_eq(expression.Identifier.name, allowed_local) == 1
        {
            lowered.represented = 1;
            lowered.uses_local = 1;
            return lowered;
        }

        if expression.tag != 10 ||
           std.str_eq(expression.Binary.op, "+") == 0
        {
            return lowered;
        }

        mut left_expression := ctx[expression.Binary.left];
        mut right_expression := ctx[expression.Binary.right];
        mut left := mir_native_generic_scalar_expression(
            left_expression,
            allowed_local,
            ctx
        );
        mut right := mir_native_generic_scalar_expression(
            right_expression,
            allowed_local,
            ctx
        );
        if left.represented == 0 ||
           right.represented == 0 ||
           left.uses_local + right.uses_local > 1
        {
            return mir_native_generic_empty_scalar_expression();
        }

        lowered.represented = 1;
        lowered.uses_local = left.uses_local + right.uses_local;
        lowered.literal_total =
            left.literal_total + right.literal_total;
        lowered.add_count = left.add_count + right.add_count + 1;
        return lowered;
    }
}

func mir_native_generic_make_result(eligibility_tag: int, bundle: mir.MirProgramBundle[ctx], plan: capability.MirNativeBackendCapabilityPlan[ctx], diagnostic: str, ctx: &Arena) MirNativeGenericSourceResult[ctx] {
    mut result: MirNativeGenericSourceResult[ctx];
    unsafe {
        result.eligibility.tag = eligibility_tag;
    }
    result.bundle = bundle;
    result.plan = plan;
    result.diagnostic = std.Clone(ctx, diagnostic);
    result.reason_code = std.Clone(ctx, "");
    return result;
}

func mir_native_generic_empty_result(eligibility_tag: int, diagnostic: str, ctx: &Arena) MirNativeGenericSourceResult[ctx] {
    return mir_native_generic_make_result(
        eligibility_tag,
        mir.mir_make_program_bundle("invalid", ctx),
        capability.mir_native_backend_make_capability_plan(ctx),
        diagnostic,
        ctx
    );
}

func mir_native_generic_deferred_result(
    reason_code: str,
    diagnostic: str,
    ctx: &Arena
) MirNativeGenericSourceResult[ctx] {
    mut result := mir_native_generic_empty_result(1, diagnostic, ctx);
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_native_generic_function_is_zero_argument_int_entry(statement: ast.Statement[ctx], ctx: &Arena) int {
    unsafe {
        if statement.tag != 3 {
            return 0;
        }
        if std.str_eq(statement.FunctionDecl.name, "main") == 0 ||
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

// ---- Straight-line constant evaluation for the generic route ----
//
// Several Phase 14 fixtures are entirely literal-determined: every local is
// initialised and reassigned from literals, every predicate is decidable at
// compile time, and the returned expression reduces to one integer. Their
// declared canonical MIR says so -- e.g.
// native_backend_phase14_pointer_ingestion.mir is `ReturnI32 49` with no locals
// and one block. So the route is meant to FOLD them.
//
// This evaluator is tried LAST, after every existing shape has declined, so it
// can never shadow a shape that already has a dedicated emitter. It tracks at
// most a few int locals and declines the moment it meets anything it cannot
// prove: a call, a loop, a non-int local, an unknown operator, or any read of a
// local it has not seen assigned.

type MirNativeGenericConstEnv[ctx] struct {
    represented: int,
    names: Index[std.Vector[str, ctx], ctx],
    values: Index[std.Vector[int, ctx], ctx]
}

type MirNativeGenericConstValue struct {
    known: int,
    value: int
}

func mir_native_generic_const_lookup(
    env: MirNativeGenericConstEnv[ctx],
    name: str,
    ctx: &Arena
) MirNativeGenericConstValue {
    mut found: MirNativeGenericConstValue;
    found.known = 0;
    found.value = 0;
    mut names: std.Vector[str, ctx] := ctx[env.names];
    mut values: std.Vector[int, ctx] := ctx[env.values];
    mut index := 0;
    while index < len(names) {
        if std.str_eq(names[index], name) == 1 {
            found.known = 1;
            found.value = values[index];
        }
        index = index + 1;
    }
    return found;
}

func mir_native_generic_const_bind(
    env: MirNativeGenericConstEnv[ctx],
    name: str,
    value: int,
    ctx: &Arena
) MirNativeGenericConstEnv[ctx] {
    unsafe {
        mut names: std.Vector[str, ctx] := ctx[env.names];
        mut values: std.Vector[int, ctx] := ctx[env.values];
        mut index := 0;
        while index < len(names) {
            if std.str_eq(names[index], name) == 1 {
                values[index] = value;
                ctx.Set(env.values, values);
                return env;
            }
            index = index + 1;
        }
        names.Push(std.Clone(ctx, name));
        values.Push(value);
        ctx.Set(env.names, names);
        ctx.Set(env.values, values);
        return env;
    }
}

func mir_native_generic_const_eval(
    expression: ast.Expression[ctx],
    env: MirNativeGenericConstEnv[ctx],
    ctx: &Arena
) MirNativeGenericConstValue {
    mut result: MirNativeGenericConstValue;
    result.known = 0;
    result.value = 0;

    unsafe {
        if expression.tag == 1 {
            result.known = 1;
            result.value = expression.Integer.val;
            return result;
        }
        if expression.tag == 3 {
            result.known = 1;
            result.value = expression.Bool.val;
            return result;
        }
        if expression.tag == 0 {
            return mir_native_generic_const_lookup(
                env,
                expression.Identifier.name,
                ctx
            );
        }
        if expression.tag == 10 {
            mut left := mir_native_generic_const_eval(
                ctx[expression.Binary.left],
                env,
                ctx
            );
            mut right := mir_native_generic_const_eval(
                ctx[expression.Binary.right],
                env,
                ctx
            );
            if left.known == 0 || right.known == 0 {
                return result;
            }
            mut folded := scalar_expression.mir_native_scalar_const_binary(
                expression.Binary.op,
                left.value,
                right.value
            );
            if folded.known == 0 {
                return result;
            }
            result.known = 1;
            result.value = folded.value;
            return result;
        }
        if expression.tag == 14 { // Query (Phase 21.3 semantic no-op)
            return mir_native_generic_const_eval(
                ctx[expression.Query.terminal], env, ctx
            );
        }
        return result;
    }
}

// Walks a straight-line body, folding it to the integer it returns. Declines on
// the first statement it cannot prove, so an unsupported construct anywhere in
// the function means the whole function is not represented here.
func mir_native_generic_const_body(
    statements: std.Vector[ast.Statement[ctx], ctx],
    env: MirNativeGenericConstEnv[ctx],
    ctx: &Arena
) MirNativeGenericConstValue {
    mut outcome: MirNativeGenericConstValue;
    outcome.known = 0;
    outcome.value = 0;

    unsafe {
        mut index := 0;
        while index < len(statements) {
            mut statement := statements[index];

            if statement.tag == 4 {
                // Only int locals; anything else is outside this evaluator.
                mut declared_type := ctx[statement.VarDecl.var_type];
                if declared_type.tag != 0 {
                    return outcome;
                }
                // A name declared twice is a source-level error. Binding over
                // the first would quietly give this route an answer for a
                // program that must be refused, so decline instead.
                mut shadowed := mir_native_generic_const_lookup(
                    env,
                    statement.VarDecl.name,
                    ctx
                );
                if shadowed.known == 1 {
                    return outcome;
                }
                mut initial := mir_native_generic_const_eval(
                    ctx[statement.VarDecl.value],
                    env,
                    ctx
                );
                if initial.known == 0 {
                    return outcome;
                }
                env = mir_native_generic_const_bind(
                    env,
                    statement.VarDecl.name,
                    initial.value,
                    ctx
                );
                index = index + 1;
            } else if statement.tag == 5 {
                mut target := ctx[statement.Assignment.left];
                if target.tag != 0 {
                    return outcome;
                }
                // Likewise, assigning to a name this evaluator never saw
                // declared means the shape is not the one claimed here.
                mut existing := mir_native_generic_const_lookup(
                    env,
                    target.Identifier.name,
                    ctx
                );
                if existing.known == 0 {
                    return outcome;
                }
                mut assigned := mir_native_generic_const_eval(
                    ctx[statement.Assignment.value],
                    env,
                    ctx
                );
                if assigned.known == 0 {
                    return outcome;
                }
                env = mir_native_generic_const_bind(
                    env,
                    target.Identifier.name,
                    assigned.value,
                    ctx
                );
                index = index + 1;
            } else if statement.tag == 7 {
                mut condition := mir_native_generic_const_eval(
                    ctx[statement.If.condition],
                    env,
                    ctx
                );
                if condition.known == 0 {
                    return outcome;
                }
                // The predicate is decided here, so exactly one arm is live and
                // the other cannot affect the result.
                if condition.value != 0 {
                    mut consequence := ctx[statement.If.consequence];
                    mut then_statements: std.Vector[ast.Statement[ctx], ctx] :=
                        ctx[consequence.statements];
                    return mir_native_generic_const_body(
                        then_statements,
                        env,
                        ctx
                    );
                }
                if statement.If.alternative !=
                   empty[Index[ast.BlockStatement[ctx], ctx]] {
                    mut alternative := ctx[statement.If.alternative];
                    mut else_statements: std.Vector[ast.Statement[ctx], ctx] :=
                        ctx[alternative.statements];
                    mut taken := mir_native_generic_const_body(
                        else_statements,
                        env,
                        ctx
                    );
                    if taken.known == 1 {
                        return taken;
                    }
                }
                index = index + 1;
            } else if statement.tag == 12 {
                return mir_native_generic_const_eval(
                    ctx[statement.Return.expr],
                    env,
                    ctx
                );
            } else {
                return outcome;
            }
        }
        return outcome;
    }
}

func mir_native_generic_const_fold_entry(
    statement: ast.Statement[ctx],
    ctx: &Arena
) MirNativeGenericConstValue {
    mut outcome: MirNativeGenericConstValue;
    outcome.known = 0;
    outcome.value = 0;
    unsafe {
        mut env: MirNativeGenericConstEnv[ctx];
        mut names: std.Vector[str, ctx] := std.VectorNew(ctx);
        mut values: std.Vector[int, ctx] := std.VectorNew(ctx);
        mut name_index: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
        mut value_index: Index[std.Vector[int, ctx], ctx] := os.ArenaAlloc(ctx);
        ctx.Set(name_index, names);
        ctx.Set(value_index, values);
        env.represented = 1;
        env.names = name_index;
        env.values = value_index;

        mut body := ctx[statement.FunctionDecl.body];
        mut body_statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[body.statements];
        return mir_native_generic_const_body(body_statements, env, ctx);
    }
}

// The Phase 13 scalar-expression owner lowers nested arithmetic AND attaches
// the phase13_10 source metadata its parity guard checks for. Folding such an
// entry to a literal would reach the right exit status with an empty metadata
// record, so the fold stands aside wherever that owner can plan the value.
func mir_native_generic_entry_is_scalar_expression_owned(
    statement: ast.Statement[ctx],
    ctx: &Arena
) int {
    unsafe {
        mut body := ctx[statement.FunctionDecl.body];
        mut statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[body.statements];
        if len(statements) != 1 || statements[0].tag != 12 {
            return 0;
        }
        mut plan := scalar_expression.mir_native_scalar_expression_plan(
            ctx[statements[0].Return.expr],
            ctx
        );
        return plan.represented;
    }
}

func mir_native_generic_analyze_single_function(statement: ast.Statement[ctx], source_path: str, ctx: &Arena) MirNativeGenericModel[ctx] {
    mut model := mir_native_generic_empty_model(ctx);
    if mir_native_generic_function_is_zero_argument_int_entry(
        statement,
        ctx
    ) == 0 {
        return model;
    }

    unsafe {
        mut body := ctx[statement.FunctionDecl.body];
        mut statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[body.statements];

        if len(statements) == 1 {
            mut only_statement := statements[0];
            if only_statement.tag == 12 {
                mut expression := ctx[only_statement.Return.expr];
                if expression.tag == 1 {
                    model.represented = 1;
                    model.shape.tag = 0;
                    model.source_path = std.Clone(ctx, source_path);
                    model.literal_value = expression.Integer.val;
                    return model;
                }

                mut scalar_expression :=
                    mir_native_generic_scalar_expression(
                        expression,
                        "",
                        ctx
                    );
                if scalar_expression.represented == 1 &&
                   scalar_expression.add_count > 0
                {
                    model.represented = 1;
                    model.shape.tag = 6;
                    model.source_path = std.Clone(ctx, source_path);
                    model.local_name = std.Clone(
                        ctx,
                        "__gust_phase11_scalar_tmp"
                    );
                    model.scalar_literal_total =
                        scalar_expression.literal_total;
                    model.scalar_add_count =
                        scalar_expression.add_count;
                    model.scalar_uses_source_local = 0;
                    return model;
                }
            }

            if only_statement.tag == 7 {
                mut condition := ctx[only_statement.If.condition];
                mut consequence := ctx[only_statement.If.consequence];
                mut alternative := ctx[only_statement.If.alternative];
                mut then_statements: std.Vector[ast.Statement[ctx], ctx] :=
                    ctx[consequence.statements];
                mut else_statements: std.Vector[ast.Statement[ctx], ctx] :=
                    ctx[alternative.statements];

                if condition.tag == 3 &&
                   len(then_statements) == 1 &&
                   len(else_statements) == 1 &&
                   then_statements[0].tag == 12 &&
                   else_statements[0].tag == 12
                {
                    mut then_expression :=
                        ctx[then_statements[0].Return.expr];
                    mut else_expression :=
                        ctx[else_statements[0].Return.expr];
                    if then_expression.tag == 1 &&
                       else_expression.tag == 1
                    {
                        model.represented = 1;
                        model.shape.tag = 2;
                        model.source_path = std.Clone(ctx, source_path);
                        model.condition_value = condition.Bool.val;
                        model.then_value = then_expression.Integer.val;
                        model.else_value = else_expression.Integer.val;
                        return model;
                    }
                }
            }
        }

        if len(statements) == 2 {
            mut local_statement := statements[0];
            mut second_statement := statements[1];
            if local_statement.tag == 4 {
                mut local_expression := ctx[local_statement.VarDecl.value];
                mut declared_type_is_int := 1;
                if local_statement.VarDecl.var_type !=
                    empty[Index[ast.Type[ctx], ctx]]
                {
                    mut declared_type :=
                        ctx[local_statement.VarDecl.var_type];
                    if declared_type.tag != 0 {
                        declared_type_is_int = 0;
                    }
                }

                if declared_type_is_int == 1 &&
                   local_expression.tag == 1 &&
                   second_statement.tag == 12
                {
                    mut return_expression :=
                        ctx[second_statement.Return.expr];
                    if return_expression.tag == 0 &&
                       std.str_eq(
                           local_statement.VarDecl.name,
                           return_expression.Identifier.name
                       ) == 1
                    {
                        model.represented = 1;
                        model.shape.tag = 1;
                        model.source_path =
                            std.Clone(ctx, source_path);
                        model.local_name = std.Clone(
                            ctx,
                            local_statement.VarDecl.name
                        );
                        model.literal_value =
                            local_expression.Integer.val;
                        return model;
                    }

                    mut scalar_expression :=
                        mir_native_generic_scalar_expression(
                            return_expression,
                            local_statement.VarDecl.name,
                            ctx
                        );
                    if scalar_expression.represented == 1 &&
                       scalar_expression.uses_local == 1 &&
                       scalar_expression.add_count > 0
                    {
                        model.represented = 1;
                        model.shape.tag = 6;
                        model.source_path =
                            std.Clone(ctx, source_path);
                        model.local_name = std.Clone(
                            ctx,
                            local_statement.VarDecl.name
                        );
                        model.initial_value =
                            local_expression.Integer.val;
                        model.scalar_literal_total =
                            scalar_expression.literal_total;
                        model.scalar_add_count =
                            scalar_expression.add_count;
                        model.scalar_uses_source_local = 1;
                        return model;
                    }
                }

                if declared_type_is_int == 1 &&
                   local_expression.tag == 1 &&
                   second_statement.tag == 7
                {
                    mut condition := ctx[second_statement.If.condition];
                    mut consequence :=
                        ctx[second_statement.If.consequence];
                    mut alternative :=
                        ctx[second_statement.If.alternative];
                    mut then_statements:
                        std.Vector[ast.Statement[ctx], ctx] :=
                            ctx[consequence.statements];
                    mut else_statements:
                        std.Vector[ast.Statement[ctx], ctx] :=
                            ctx[alternative.statements];

                    if condition.tag == 10 &&
                       std.str_eq(condition.Binary.op, ">") == 1 &&
                       len(then_statements) == 1 &&
                       len(else_statements) == 1 &&
                       then_statements[0].tag == 12 &&
                       else_statements[0].tag == 12
                    {
                        mut condition_left :=
                            ctx[condition.Binary.left];
                        mut condition_right :=
                            ctx[condition.Binary.right];
                        mut then_expression :=
                            ctx[then_statements[0].Return.expr];
                        mut else_expression :=
                            ctx[else_statements[0].Return.expr];
                        mut then_return_represented := 0;
                        mut then_return_value := 0;
                        if then_expression.tag == 1 {
                            then_return_represented = 1;
                            then_return_value =
                                then_expression.Integer.val;
                        }
                        if then_expression.tag == 0 {
                            if std.str_eq(
                                then_expression.Identifier.name,
                                local_statement.VarDecl.name
                            ) == 1
                            {
                                then_return_represented = 1;
                                then_return_value =
                                    local_expression.Integer.val;
                            }
                        }

                        if condition_left.tag == 0 &&
                           condition_right.tag == 1 &&
                           condition_right.Integer.val == 0 &&
                           then_return_represented == 1 &&
                           else_expression.tag == 1 &&
                           std.str_eq(
                               condition_left.Identifier.name,
                               local_statement.VarDecl.name
                           ) == 1
                        {
                            model.represented = 1;
                            model.shape.tag = 7;
                            model.source_path =
                                std.Clone(ctx, source_path);
                            model.local_name = std.Clone(
                                ctx,
                                local_statement.VarDecl.name
                            );
                            model.initial_value =
                                local_expression.Integer.val;
                            model.then_value = then_return_value;
                            model.else_value =
                                else_expression.Integer.val;
                            return model;
                        }
                    }
                }
            }
        }

        if len(statements) == 3 {
            mut local_statement := statements[0];
            mut if_statement := statements[1];
            mut return_statement := statements[2];

            if local_statement.tag == 4 &&
               local_statement.VarDecl.is_mut == 1 &&
               if_statement.tag == 7 &&
               return_statement.tag == 12
            {
                mut local_expression := ctx[local_statement.VarDecl.value];
                mut return_expression := ctx[return_statement.Return.expr];
                mut declared_type_is_int := 1;
                if local_statement.VarDecl.var_type !=
                    empty[Index[ast.Type[ctx], ctx]]
                {
                    mut declared_type :=
                        ctx[local_statement.VarDecl.var_type];
                    if declared_type.tag != 0 {
                        declared_type_is_int = 0;
                    }
                }

                if declared_type_is_int == 1 &&
                   local_expression.tag == 1 &&
                   return_expression.tag == 0 &&
                   std.str_eq(
                       local_statement.VarDecl.name,
                       return_expression.Identifier.name
                   ) == 1
                {
                    mut condition := ctx[if_statement.If.condition];
                    mut consequence := ctx[if_statement.If.consequence];
                    mut alternative := ctx[if_statement.If.alternative];
                    mut then_statements:
                        std.Vector[ast.Statement[ctx], ctx] :=
                            ctx[consequence.statements];
                    mut else_statements:
                        std.Vector[ast.Statement[ctx], ctx] :=
                            ctx[alternative.statements];

                    if condition.tag == 10 &&
                       std.str_eq(condition.Binary.op, ">") == 1 &&
                       len(then_statements) == 1 &&
                       len(else_statements) == 1 &&
                       then_statements[0].tag == 5 &&
                       else_statements[0].tag == 5
                    {
                        mut condition_left := ctx[condition.Binary.left];
                        mut condition_right := ctx[condition.Binary.right];
                        mut then_left :=
                            ctx[then_statements[0].Assignment.left];
                        mut then_expression :=
                            ctx[then_statements[0].Assignment.value];
                        mut else_left :=
                            ctx[else_statements[0].Assignment.left];
                        mut else_expression :=
                            ctx[else_statements[0].Assignment.value];

                        if condition_left.tag == 0 &&
                           condition_right.tag == 1 &&
                           condition_right.Integer.val == 0 &&
                           then_left.tag == 0 &&
                           then_expression.tag == 1 &&
                           else_left.tag == 0 &&
                           else_expression.tag == 1 &&
                           std.str_eq(
                               condition_left.Identifier.name,
                               local_statement.VarDecl.name
                           ) == 1 &&
                           std.str_eq(
                               then_left.Identifier.name,
                               local_statement.VarDecl.name
                           ) == 1 &&
                           std.str_eq(
                               else_left.Identifier.name,
                               local_statement.VarDecl.name
                           ) == 1
                        {
                            model.represented = 1;
                            model.shape.tag = 3;
                            model.source_path =
                                std.Clone(ctx, source_path);
                            model.local_name = std.Clone(
                                ctx,
                                local_statement.VarDecl.name
                            );
                            model.initial_value =
                                local_expression.Integer.val;
                            model.then_value =
                                then_expression.Integer.val;
                            model.else_value =
                                else_expression.Integer.val;
                            return model;
                        }
                    }
                }
            }
        }
    }

    // Last resort: the whole entry may be literal-determined. Tried only after
    // every dedicated shape above has declined, so it cannot shadow one.
    // Guard the fold explicitly on the entry qualification rather than relying
    // on the early return above: a fold that claims a non-entry function
    // produces a bundle the emitter cannot lower, which crashes rather than
    // declining.
    mut folded: MirNativeGenericConstValue;
    folded.known = 0;
    folded.value = 0;
    if mir_native_generic_function_is_zero_argument_int_entry(statement, ctx) == 1 &&
       mir_native_generic_entry_is_scalar_expression_owned(statement, ctx) == 0
    {
        folded = mir_native_generic_const_fold_entry(statement, ctx);
    }
    if folded.known == 1 {
        unsafe {
            model.represented = 1;
            model.shape.tag = 0;
            model.source_path = std.Clone(ctx, source_path);
            model.literal_value = folded.value;
            return model;
        }
    }

    return model;
}

// ---- Phase 14 primitive-layout selector fold ----
//
// Recognises a two-function module whose entry calls a pure selector with
// literal arguments, and folds it to the literal the selector would return:
//
//     func choose(flag: bool, left: int, right: int) int {
//         if flag { return left; } else { return right; }
//     }
//     func main() int { return choose(true, 42, 7); }   =>   return 42
//
// The declared canonical MIR for this case
// (compiler/fixtures/native_backend_phase14_primitive_layout_ingestion.mir) is
// `ReturnI32 42` with no locals and one block, so the route is meant to FOLD
// here rather than to represent a bool parameter, a parameter branch, or a
// call. That is why this needs no new terminator kind: it reuses LiteralReturn.
//
// Every operand must be a literal. Nothing here evaluates a runtime value, so
// the fold cannot change observable behaviour -- it either matches exactly and
// yields the selected literal, or it declines and the route defers as before.
type MirNativeGenericSelectorFold struct {
    represented: int,
    value: int
}

// Evaluates one arm of the selector to a literal, given the literal arguments
// bound to the helper's parameters. Handles exactly three forms:
//   <int param>              -> the literal bound to that parameter
//   <int literal>            -> itself
//   <either of the above> <op> <int literal>, for the operators the
//   Phase 13 scalar-expression owner can resolve at compile time
// Anything else declines, so the fold declines with it.
func mir_native_generic_fold_arm(
    expression: ast.Expression[ctx],
    parameters: std.Vector[ast.Parameter[ctx], ctx],
    arguments: std.Vector[ast.Expression[ctx], ctx],
    ctx: &Arena
) MirNativeGenericSelectorFold {
    mut arm: MirNativeGenericSelectorFold;
    arm.represented = 0;
    arm.value = 0;

    unsafe {

        if expression.tag == 1 {
            arm.represented = 1;
            arm.value = expression.Integer.val;
            return arm;
        }
        if expression.tag == 0 {
            mut index := 1;
            while index < len(parameters) {
                if std.str_eq(
                    expression.Identifier.name,
                    parameters[index].name
                ) == 1 {
                    arm.represented = 1;
                    arm.value = arguments[index].Integer.val;
                    return arm;
                }
                index = index + 1;
            }
            return arm;
        }
        if expression.tag == 10 {
            mut right := ctx[expression.Binary.right];
            if right.tag != 1 {
                return arm;
            }
            mut left := ctx[expression.Binary.left];
            mut left_arm := mir_native_generic_fold_arm(
                left,
                parameters,
                arguments,
                ctx
            );
            if left_arm.represented == 0 {
                return arm;
            }
            mut folded := scalar_expression.mir_native_scalar_const_binary(
                expression.Binary.op,
                left_arm.value,
                right.Integer.val
            );
            if folded.known == 0 {
                return arm;
            }
            arm.represented = 1;
            arm.value = folded.value;
            return arm;
        }
        return arm;
    }
}

func mir_native_generic_selector_fold(
    helper_statement: ast.Statement[ctx],
    call_expression: ast.Expression[ctx],
    ctx: &Arena
) MirNativeGenericSelectorFold {
    mut fold: MirNativeGenericSelectorFold;
    fold.represented = 0;
    fold.value = 0;

    unsafe {
        mut parameters: std.Vector[ast.Parameter[ctx], ctx] :=
            ctx[helper_statement.FunctionDecl.params];
        mut return_type := ctx[helper_statement.FunctionDecl.return_type];
        // (bool, int) or (bool, int, int) -> int, and nothing else.
        if len(parameters) < 2 || len(parameters) > 3 ||
           parameters[0].param_type.tag != 2 ||
           return_type.tag != 0
        {
            return fold;
        }
        mut check := 1;
        while check < len(parameters) {
            if parameters[check].param_type.tag != 0 {
                return fold;
            }
            check = check + 1;
        }

        mut helper_body := ctx[helper_statement.FunctionDecl.body];
        mut helper_statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[helper_body.statements];
        if len(helper_statements) != 1 || helper_statements[0].tag != 7 {
            return fold;
        }

        mut condition := ctx[helper_statements[0].If.condition];
        // The predicate is the bool parameter itself, unnegated.
        if condition.tag != 0 ||
           std.str_eq(condition.Identifier.name, parameters[0].name) == 0
        {
            return fold;
        }

        if helper_statements[0].If.alternative ==
           empty[Index[ast.BlockStatement[ctx], ctx]]
        {
            return fold;
        }
        mut consequence := ctx[helper_statements[0].If.consequence];
        mut alternative := ctx[helper_statements[0].If.alternative];
        mut then_statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[consequence.statements];
        mut else_statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[alternative.statements];
        if len(then_statements) != 1 || then_statements[0].tag != 12 ||
           len(else_statements) != 1 || else_statements[0].tag != 12
        {
            return fold;
        }

        // Every argument must be a literal, or there is nothing to fold.
        mut arguments: std.Vector[ast.Expression[ctx], ctx] :=
            ctx[call_expression.Call.arguments];
        if len(arguments) != len(parameters) || arguments[0].tag != 3 {
            return fold;
        }
        mut probe := 1;
        while probe < len(arguments) {
            if arguments[probe].tag != 1 {
                return fold;
            }
            probe = probe + 1;
        }

        // The predicate is a literal, so exactly one arm is reachable. Fold
        // that arm and that arm only: the other is dead code, and evaluating
        // it would make this route answer questions about expressions the
        // program never runs.
        mut selected := ctx[else_statements[0].Return.expr];
        if arguments[0].Bool.val == 1 {
            selected = ctx[then_statements[0].Return.expr];
        }
        mut arm := mir_native_generic_fold_arm(
            selected,
            parameters,
            arguments,
            ctx
        );
        if arm.represented == 0 {
            return fold;
        }

        fold.value = arm.value;
        fold.represented = 1;
        return fold;
    }
}

func mir_native_generic_analyze_call_module(top_level: std.Vector[ast.Statement[ctx], ctx], source_path: str, ctx: &Arena) MirNativeGenericModel[ctx] {
    mut model := mir_native_generic_empty_model(ctx);
    if len(top_level) != 2 {
        return model;
    }

    unsafe {
        mut first := top_level[0];
        mut second := top_level[1];
        if first.tag != 3 || second.tag != 3 {
            return model;
        }

        mut main_statement := first;
        mut companion_statement := second;
        if std.str_eq(second.FunctionDecl.name, "main") == 1 {
            main_statement = second;
            companion_statement = first;
        } else if std.str_eq(first.FunctionDecl.name, "main") == 0 {
            return model;
        }

        if mir_native_generic_function_is_zero_argument_int_entry(
            main_statement,
            ctx
        ) == 0 {
            return model;
        }

        mut main_body := ctx[main_statement.FunctionDecl.body];
        mut main_statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[main_body.statements];

        mut call_expression: ast.Expression[ctx];
        mut call_is_present := 0;
        mut call_is_imported := 0;

        if companion_statement.FunctionDecl.is_extern == 0 {
            // Selector fold first: it accepts a three-parameter helper, which
            // the identity shape below rejects outright on parameter count.
            if len(main_statements) == 1 && main_statements[0].tag == 12 {
                mut fold_call := ctx[main_statements[0].Return.expr];
                if fold_call.tag == 12 {
                    mut fold_callee := ctx[fold_call.Call.function];
                    if fold_callee.tag == 0 &&
                       std.str_eq(
                           fold_callee.Identifier.name,
                           companion_statement.FunctionDecl.name
                       ) == 1
                    {
                        mut fold := mir_native_generic_selector_fold(
                            companion_statement,
                            fold_call,
                            ctx
                        );
                        if fold.represented == 1 {
                            model.represented = 1;
                            model.shape.tag = 0;
                            model.source_path = std.Clone(ctx, source_path);
                            model.literal_value = fold.value;
                            return model;
                        }
                    }
                }
            }

            mut helper_parameters: std.Vector[ast.Parameter[ctx], ctx] :=
                ctx[companion_statement.FunctionDecl.params];
            mut helper_return_type :=
                ctx[companion_statement.FunctionDecl.return_type];
            mut helper_body := ctx[companion_statement.FunctionDecl.body];
            mut helper_statements: std.Vector[ast.Statement[ctx], ctx] :=
                ctx[helper_body.statements];

            if len(helper_parameters) != 1 ||
               helper_parameters[0].param_type.tag != 0 ||
               helper_return_type.tag != 0 ||
               len(helper_statements) != 1 ||
               helper_statements[0].tag != 12 ||
               len(main_statements) != 1 ||
               main_statements[0].tag != 12
            {
                return model;
            }

            mut helper_return :=
                ctx[helper_statements[0].Return.expr];
            if helper_return.tag != 0 ||
               std.str_eq(
                   helper_return.Identifier.name,
                   helper_parameters[0].name
               ) == 0
            {
                return model;
            }

            call_expression = ctx[main_statements[0].Return.expr];
            call_is_present = 1;
            model.call_name = std.Clone(
                ctx,
                companion_statement.FunctionDecl.name
            );
            model.call_link_name = std.Clone(
                ctx,
                companion_statement.FunctionDecl.name
            );
        } else {
            mut extern_parameters: std.Vector[ast.Parameter[ctx], ctx] :=
                ctx[companion_statement.FunctionDecl.params];
            mut extern_return_type :=
                ctx[companion_statement.FunctionDecl.return_type];

            if len(extern_parameters) != 1 ||
               extern_parameters[0].param_type.tag != 0 ||
               extern_return_type.tag != 0 ||
               std.str_eq(
                   companion_statement.FunctionDecl.extern_abi,
                   "C"
               ) == 0 ||
               len(main_statements) != 1 ||
               main_statements[0].tag != 10
            {
                return model;
            }

            mut unsafe_body := ctx[main_statements[0].UnsafeBlock.body];
            mut unsafe_statements:
                std.Vector[ast.Statement[ctx], ctx] :=
                    ctx[unsafe_body.statements];
            if len(unsafe_statements) != 1 ||
               unsafe_statements[0].tag != 12
            {
                return model;
            }

            call_expression = ctx[unsafe_statements[0].Return.expr];
            call_is_present = 1;
            call_is_imported = 1;
            model.call_name = std.Clone(
                ctx,
                companion_statement.FunctionDecl.name
            );
            model.call_link_name = std.Clone(
                ctx,
                companion_statement.FunctionDecl.extern_symbol_name
            );
            if len(model.call_link_name) == 0 {
                model.call_link_name = std.Clone(
                    ctx,
                    companion_statement.FunctionDecl.name
                );
            }
        }

        if call_is_present == 0 || call_expression.tag != 12 {
            return model;
        }

        mut callee := ctx[call_expression.Call.function];
        mut arguments: std.Vector[ast.Expression[ctx], ctx] :=
            ctx[call_expression.Call.arguments];
        if callee.tag != 0 ||
           std.str_eq(callee.Identifier.name, model.call_name) == 0 ||
           len(arguments) != 1 ||
           arguments[0].tag != 1 ||
           arguments[0].Integer.val < 0
        {
            return mir_native_generic_empty_model(ctx);
        }

        if call_is_imported == 1 &&
           (std.str_eq(model.call_name, "abs") == 0 ||
            std.str_eq(model.call_link_name, "abs") == 0)
        {
            return mir_native_generic_empty_model(ctx);
        }

        model.represented = 1;
        model.source_path = std.Clone(ctx, source_path);
        model.literal_value = arguments[0].Integer.val;
        if call_is_imported == 1 {
            model.shape.tag = 5;
        } else {
            model.shape.tag = 4;
        }
        return model;
    }
}

func mir_native_generic_analyze(programs: std.Vector[ast.Program[ctx], ctx], module_paths: std.Vector[str, ctx], module_prefixes: std.Vector[str, ctx], ctx: &Arena) MirNativeGenericModel[ctx] {
    mut model := mir_native_generic_empty_model(ctx);
    if len(programs) != 1 ||
       len(module_paths) != 1 ||
       len(module_prefixes) != 1 ||
       std.str_eq(module_prefixes[0], "") == 0
    {
        return model;
    }

    mut program := programs[0];
    mut source_top_level: std.Vector[ast.Statement[ctx], ctx] :=
        ctx[program.statements];
    // Scoped entity declarations are compile-time query metadata. When a
    // scalar query terminal does not materialize the entity, the generic
    // source route may ignore that declaration without lowering a struct.
    mut top_level: std.Vector[ast.Statement[ctx], ctx] := std.VectorNew(ctx);
    mut source_top_index_phase21_4 := 0;
    unsafe {
        while source_top_index_phase21_4 < len(source_top_level) {
            mut source_statement_phase21_4 :=
                source_top_level[source_top_index_phase21_4];
            if source_statement_phase21_4.tag != 1 ||
               source_statement_phase21_4.StructDecl.is_scoped_entity == 0
            {
                top_level.Push(source_statement_phase21_4);
            }
            source_top_index_phase21_4 = source_top_index_phase21_4 + 1;
        }
    }

    if len(top_level) == 1 {
        return mir_native_generic_analyze_single_function(
            top_level[0],
            module_paths[0],
            ctx
        );
    }

    if len(top_level) == 2 {
        return mir_native_generic_analyze_call_module(
            top_level,
            module_paths[0],
            ctx
        );
    }

    return model;
}

func mir_native_generic_emit_scalar(model: MirNativeGenericModel[ctx], ctx: &Arena) mir.MirProgramBundle[ctx] {
    mut canonical := "format: gust.compiler_mir_ingestion.v1\nfunction: main\nbackend_symbol: main\nparameter_count: 0\nreturn_type: int\n";
    mut is_local := 0;
    if model.shape.tag == 1 {
        is_local = 1;
        canonical = mir_native_generic_append(
            canonical,
            "local_count: 1\nlocal_0_name: ",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            model.local_name,
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "\nlocal_0_type: int\n",
            ctx
        );
    } else {
        canonical = mir_native_generic_append(
            canonical,
            "local_count: 0\n",
            ctx
        );
    }

    canonical = mir_native_generic_append(
        canonical,
        "entry_block: entry\nblock_count: 1\nblock_0_label: entry\n",
        ctx
    );

    if is_local == 1 {
        canonical = mir_native_generic_append(
            canonical,
            "block_0_statement_count: 1\nblock_0_statement_0_kind: LocalI32Set\nblock_0_statement_0_local: ",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            model.local_name,
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "\nblock_0_statement_0_value: ",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            std.FormatInt(model.literal_value),
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "\nblock_0_terminator_kind: ReturnLocalI32\nblock_0_terminator_local: ",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            model.local_name,
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "\nmetadata_count: 1\nmetadata_0_kind: provenance\nmetadata_0_attachment: statement:entry:0\nmetadata_0_policy: ignored_with_proof\nmetadata_0_payload: kind=LocalBinding;local=",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            model.local_name,
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            ";codegen=none;proof=local_binding_metadata_is_diagnostic_only;origin=",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            model.source_path,
            ctx
        );
        canonical = mir_native_generic_append(canonical, "\n", ctx);
    } else {
        canonical = mir_native_generic_append(
            canonical,
            "block_0_statement_count: 0\nblock_0_terminator_kind: ReturnI32\nblock_0_terminator_value: ",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            std.FormatInt(model.literal_value),
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "\nmetadata_count: 0\n",
            ctx
        );
    }

    canonical = mir_native_generic_append(
        canonical,
        "expected_exit: ",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        std.FormatInt(model.literal_value),
        ctx
    );
    canonical = mir_native_generic_append(canonical, "\n", ctx);

    mut bundle := mir.mir_make_program_bundle("main", ctx);
    mut bundle_module := mir.mir_make_program_bundle_module(
        model.source_path,
        "",
        "phase10_scalar_module.o",
        "gust.compiler_mir_ingestion.v1",
        canonical,
        0,
        is_local,
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

func mir_native_generic_emit_scalar_expression(
    model: MirNativeGenericModel[ctx],
    ctx: &Arena
) mir.MirProgramBundle[ctx] {
    mut initial_value := 0;
    mut provenance_count := 0;
    if model.scalar_uses_source_local == 1 {
        initial_value = model.initial_value;
        provenance_count = 1;
    }
    mut expected_exit :=
        initial_value + model.scalar_literal_total;

    mut canonical :=
        "format: gust.compiler_mir_ingestion.v1\nfunction: main\nbackend_symbol: main\nparameter_count: 0\nreturn_type: int\nlocal_count: 1\nlocal_0_name: ";
    canonical = mir_native_generic_append(
        canonical,
        model.local_name,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "\nlocal_0_type: int\nentry_block: entry\nblock_count: 1\nblock_0_label: entry\nblock_0_parameter_count: 0\nblock_0_statement_count: 2\nblock_0_statement_0_kind: LocalI32Set\nblock_0_statement_0_local: ",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        model.local_name,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "\nblock_0_statement_0_value: ",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        std.FormatInt(initial_value),
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "\nblock_0_statement_1_kind: LocalI32AddI32Literal\nblock_0_statement_1_local: ",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        model.local_name,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "\nblock_0_statement_1_value: ",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        std.FormatInt(model.scalar_literal_total),
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "\nblock_0_terminator_kind: ReturnLocalI32\nblock_0_terminator_local: ",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        model.local_name,
        ctx
    );

    if provenance_count == 1 {
        canonical = mir_native_generic_append(
            canonical,
            "\nmetadata_count: 1\nmetadata_0_kind: provenance\nmetadata_0_attachment: statement:entry:0\nmetadata_0_policy: ignored_with_proof\nmetadata_0_payload: kind=LocalBinding;local=",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            model.local_name,
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            ";codegen=none;proof=local_binding_metadata_is_diagnostic_only;origin=",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            model.source_path,
            ctx
        );
    } else {
        canonical = mir_native_generic_append(
            canonical,
            "\nmetadata_count: 0",
            ctx
        );
    }

    canonical = mir_native_generic_append(
        canonical,
        "\nexpected_exit: ",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        std.FormatInt(expected_exit),
        ctx
    );
    canonical = mir_native_generic_append(canonical, "\n", ctx);

    mut bundle := mir.mir_make_program_bundle("main", ctx);
    mut bundle_module := mir.mir_make_program_bundle_module(
        model.source_path,
        "",
        "phase11_scalar_expression_module.o",
        "gust.compiler_mir_ingestion.v1",
        canonical,
        0,
        provenance_count,
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

func mir_native_generic_emit_positive_local_branch(
    model: MirNativeGenericModel[ctx],
    ctx: &Arena
) mir.MirProgramBundle[ctx] {
    mut expected_exit := model.else_value;
    if model.initial_value > 0 {
        expected_exit = model.then_value;
    }

    mut canonical :=
        "format: gust.compiler_mir_ingestion.v1\nfunction: main\nbackend_symbol: main\nparameter_count: 0\nreturn_type: int\nlocal_count: 1\nlocal_0_name: ";
    canonical = mir_native_generic_append(
        canonical,
        model.local_name,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "\nlocal_0_type: int\nentry_block: entry\nblock_count: 3\nblock_0_label: entry\nblock_0_parameter_count: 0\nblock_0_statement_count: 1\nblock_0_statement_0_kind: LocalI32Set\nblock_0_statement_0_local: ",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        model.local_name,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "\nblock_0_statement_0_value: ",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        std.FormatInt(model.initial_value),
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "\nblock_0_terminator_kind: BranchLocalI32Positive\nblock_0_terminator_local: ",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        model.local_name,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "\nblock_0_terminator_then: positive\nblock_0_terminator_then_argument_count: 0\nblock_0_terminator_else: non_positive\nblock_0_terminator_else_argument_count: 0\nblock_1_label: positive\nblock_1_parameter_count: 0\nblock_1_statement_count: 0\nblock_1_terminator_kind: ReturnI32\nblock_1_terminator_value: ",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        std.FormatInt(model.then_value),
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "\nblock_2_label: non_positive\nblock_2_parameter_count: 0\nblock_2_statement_count: 0\nblock_2_terminator_kind: ReturnI32\nblock_2_terminator_value: ",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        std.FormatInt(model.else_value),
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "\nmetadata_count: 1\nmetadata_0_kind: provenance\nmetadata_0_attachment: statement:entry:0\nmetadata_0_policy: ignored_with_proof\nmetadata_0_payload: kind=LocalBinding;local=",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        model.local_name,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        ";codegen=none;proof=local_binding_metadata_is_diagnostic_only;origin=",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        model.source_path,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "\nexpected_exit: ",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        std.FormatInt(expected_exit),
        ctx
    );
    canonical = mir_native_generic_append(canonical, "\n", ctx);

    mut bundle := mir.mir_make_program_bundle("main", ctx);
    mut bundle_module := mir.mir_make_program_bundle_module(
        model.source_path,
        "",
        "phase11_scalar_predicate_module.o",
        "gust.compiler_mir_ingestion.v1",
        canonical,
        0,
        1,
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

func mir_native_generic_emit_cfg(model: MirNativeGenericModel[ctx], ctx: &Arena) mir.MirProgramBundle[ctx] {
    mut canonical := "format: gust.compiler_mir_ingestion.v1\nfunction: main\nbackend_symbol: main\nparameter_count: 0\nreturn_type: int\n";
    mut is_merge := 0;
    mut expected_exit := model.else_value;
    mut object_name := "phase10_cfg_module.o";
    mut provenance_count := 0;
    mut block_parameter_count := 0;

    if model.shape.tag == 3 {
        is_merge = 1;
        object_name = "phase10_block_parameter_module.o";
        provenance_count = 1;
        block_parameter_count = 1;
        if model.initial_value > 0 {
            expected_exit = model.then_value;
        }
        canonical = mir_native_generic_append(
            canonical,
            "local_count: 1\nlocal_0_name: ",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            model.local_name,
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "\nlocal_0_type: int\n",
            ctx
        );
    } else {
        if model.condition_value != 0 {
            expected_exit = model.then_value;
        }
        canonical = mir_native_generic_append(
            canonical,
            "local_count: 0\n",
            ctx
        );
    }

    canonical = mir_native_generic_append(
        canonical,
        "entry_block: entry\n",
        ctx
    );

    if is_merge == 0 {
        canonical = mir_native_generic_append(
            canonical,
            "block_count: 3\nblock_0_label: entry\nblock_0_parameter_count: 0\nblock_0_statement_count: 0\nblock_0_terminator_kind: BranchI32Literal\nblock_0_terminator_condition: ",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            std.FormatInt(model.condition_value),
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "\nblock_0_terminator_then: then\nblock_0_terminator_then_argument_count: 0\nblock_0_terminator_else: else\nblock_0_terminator_else_argument_count: 0\nblock_1_label: then\nblock_1_parameter_count: 0\nblock_1_statement_count: 0\nblock_1_terminator_kind: ReturnI32\nblock_1_terminator_value: ",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            std.FormatInt(model.then_value),
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "\nblock_2_label: else\nblock_2_parameter_count: 0\nblock_2_statement_count: 0\nblock_2_terminator_kind: ReturnI32\nblock_2_terminator_value: ",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            std.FormatInt(model.else_value),
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "\nmetadata_count: 0\n",
            ctx
        );
    } else {
        canonical = mir_native_generic_append(
            canonical,
            "block_count: 4\nblock_0_label: entry\nblock_0_parameter_count: 0\nblock_0_statement_count: 1\nblock_0_statement_0_kind: LocalI32Set\nblock_0_statement_0_local: ",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            model.local_name,
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "\nblock_0_statement_0_value: ",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            std.FormatInt(model.initial_value),
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "\nblock_0_terminator_kind: BranchLocalI32Positive\nblock_0_terminator_local: ",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            model.local_name,
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "\nblock_0_terminator_then: then\nblock_0_terminator_then_argument_count: 0\nblock_0_terminator_else: else\nblock_0_terminator_else_argument_count: 0\nblock_1_label: then\nblock_1_parameter_count: 0\nblock_1_statement_count: 0\nblock_1_terminator_kind: Jump\nblock_1_terminator_target: merge\nblock_1_terminator_argument_count: 1\nblock_1_terminator_argument_0_kind: I32Literal\nblock_1_terminator_argument_0_value: ",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            std.FormatInt(model.then_value),
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "\nblock_2_label: else\nblock_2_parameter_count: 0\nblock_2_statement_count: 0\nblock_2_terminator_kind: Jump\nblock_2_terminator_target: merge\nblock_2_terminator_argument_count: 1\nblock_2_terminator_argument_0_kind: I32Literal\nblock_2_terminator_argument_0_value: ",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            std.FormatInt(model.else_value),
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "\nblock_3_label: merge\nblock_3_parameter_count: 1\nblock_3_parameter_0_name: merged_value\nblock_3_parameter_0_type: int\nblock_3_statement_count: 0\nblock_3_terminator_kind: ReturnBlockParamI32\nblock_3_terminator_block_param: merged_value\nmetadata_count: 1\nmetadata_0_kind: provenance\nmetadata_0_attachment: statement:entry:0\nmetadata_0_policy: ignored_with_proof\nmetadata_0_payload: kind=LocalBinding;local=",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            model.local_name,
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            ";codegen=none;proof=local_binding_metadata_is_diagnostic_only;origin=",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            model.source_path,
            ctx
        );
        canonical = mir_native_generic_append(canonical, "\n", ctx);
    }

    canonical = mir_native_generic_append(
        canonical,
        "expected_exit: ",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        std.FormatInt(expected_exit),
        ctx
    );
    canonical = mir_native_generic_append(canonical, "\n", ctx);

    mut bundle := mir.mir_make_program_bundle("main", ctx);
    mut bundle_module := mir.mir_make_program_bundle_module(
        model.source_path,
        "",
        object_name,
        "gust.compiler_mir_ingestion.v1",
        canonical,
        0,
        provenance_count,
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
    if block_parameter_count == 1 {
        bundle_module =
            mir.mir_program_bundle_module_with_block_parameter(
                bundle_module,
                mir.mir_make_program_bundle_block_parameter(
                    "main",
                    "merge",
                    0,
                    "merged_value",
                    "int",
                    ctx
                ),
                ctx
            );
    }
    return mir.mir_program_bundle_with_module(
        bundle,
        bundle_module,
        ctx
    );
}

func mir_native_generic_emit_call(model: MirNativeGenericModel[ctx], ctx: &Arena) mir.MirProgramBundle[ctx] {
    mut is_imported := 0;
    mut function_prefix := "function_1_";
    mut object_name := "phase10_local_call_module.o";
    mut native_boundary_count := 0;
    mut canonical := "format: gust.compiler_mir_ingestion.v2\n";

    if model.shape.tag == 5 {
        is_imported = 1;
        function_prefix = "function_0_";
        object_name = "phase10_runtime_boundary_module.o";
        native_boundary_count = 1;
        canonical = mir_native_generic_append(
            canonical,
            "module: phase10_runtime_boundary\nimport_count: 1\nimport_0_name: ",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            model.call_name,
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "\nimport_0_link_symbol: ",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            model.call_link_name,
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "\nimport_0_linkage: imported_host\nimport_0_parameter_count: 1\nimport_0_parameter_0_type: int\nimport_0_return_type: int\nfunction_count: 1\n",
            ctx
        );
    } else {
        canonical = mir_native_generic_append(
            canonical,
            "module: phase10_local_call\nimport_count: 0\nfunction_count: 2\nfunction_0_linkage: module_local\nfunction_0_function: ",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            model.call_name,
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "\nfunction_0_backend_symbol: ",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            model.call_name,
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "\nfunction_0_parameter_count: 1\nfunction_0_parameter_0_type: int\nfunction_0_return_type: int\nfunction_0_local_count: 1\nfunction_0_local_0_name: param_value\nfunction_0_local_0_type: int\nfunction_0_entry_block: entry\nfunction_0_block_count: 1\nfunction_0_block_0_label: entry\nfunction_0_block_0_parameter_count: 0\nfunction_0_block_0_statement_count: 1\nfunction_0_block_0_statement_0_kind: LocalI32SetParam\nfunction_0_block_0_statement_0_local: param_value\nfunction_0_block_0_statement_0_param: 0\nfunction_0_block_0_terminator_kind: ReturnLocalI32\nfunction_0_block_0_terminator_local: param_value\nfunction_0_metadata_count: 0\nfunction_0_expected_exit: 0\n",
            ctx
        );
    }

    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "linkage: exported_entry\n",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "function: main\n",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "backend_symbol: main\n",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "parameter_count: 0\n",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "return_type: int\n",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "local_count: 1\n",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "local_0_name: call_result\n",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "local_0_type: int\n",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "entry_block: entry\n",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "block_count: 1\n",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "block_0_label: entry\n",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "block_0_parameter_count: 0\n",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "block_0_statement_count: 1\n",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "block_0_statement_0_kind: LocalI32SetCall\n",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "block_0_statement_0_local: call_result\n",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    if is_imported == 1 {
        canonical = mir_native_generic_append(
            canonical,
            "block_0_statement_0_callee_kind: ImportedFunction\n",
            ctx
        );
    } else {
        canonical = mir_native_generic_append(
            canonical,
            "block_0_statement_0_callee_kind: LocalFunction\n",
            ctx
        );
    }
    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "block_0_statement_0_callee: ",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        model.call_name,
        ctx
    );
    canonical = mir_native_generic_append(canonical, "\n", ctx);
    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "block_0_statement_0_argument_count: 1\n",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "block_0_statement_0_argument_0_kind: I32Literal\n",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "block_0_statement_0_argument_0_value: ",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        std.FormatInt(model.literal_value),
        ctx
    );
    canonical = mir_native_generic_append(canonical, "\n", ctx);
    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "block_0_terminator_kind: ReturnLocalI32\n",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "block_0_terminator_local: call_result\n",
        ctx
    );

    if is_imported == 1 {
        canonical = mir_native_generic_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "metadata_count: 1\n",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "metadata_0_kind: native_boundary\n",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "metadata_0_attachment: statement:entry:0\n",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "metadata_0_policy: ignored_with_proof\n",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "metadata_0_payload: kind=RuntimeCall;symbol=",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            model.call_link_name,
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            ";codegen=none;proof=runtime_boundary_classification_is_registry_validated;origin=",
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            model.source_path,
            ctx
        );
        canonical = mir_native_generic_append(canonical, "\n", ctx);
    } else {
        canonical = mir_native_generic_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_generic_append(
            canonical,
            "metadata_count: 0\n",
            ctx
        );
    }

    canonical = mir_native_generic_append(
        canonical,
        function_prefix,
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        "expected_exit: ",
        ctx
    );
    canonical = mir_native_generic_append(
        canonical,
        std.FormatInt(model.literal_value),
        ctx
    );
    canonical = mir_native_generic_append(canonical, "\n", ctx);

    mut bundle := mir.mir_make_program_bundle("main", ctx);
    mut bundle_module := mir.mir_make_program_bundle_module(
        model.source_path,
        "",
        object_name,
        "gust.compiler_mir_ingestion.v2",
        canonical,
        0,
        0,
        native_boundary_count,
        ctx
    );

    if is_imported == 1 {
        bundle_module = mir.mir_program_bundle_module_with_symbol(
            bundle_module,
            mir.mir_make_program_bundle_symbol(
                model.call_name,
                model.call_link_name,
                "(int)->int",
                2,
                ctx
            ),
            ctx
        );
    } else {
        bundle_module = mir.mir_program_bundle_module_with_symbol(
            bundle_module,
            mir.mir_make_program_bundle_symbol(
                model.call_name,
                model.call_name,
                "(int)->int",
                1,
                ctx
            ),
            ctx
        );
    }

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

func mir_native_generic_emit_bundle(model: MirNativeGenericModel[ctx], ctx: &Arena) mir.MirProgramBundle[ctx] {
    if model.shape.tag == 0 || model.shape.tag == 1 {
        return mir_native_generic_emit_scalar(model, ctx);
    }
    if model.shape.tag == 2 || model.shape.tag == 3 {
        return mir_native_generic_emit_cfg(model, ctx);
    }
    if model.shape.tag == 4 || model.shape.tag == 5 {
        return mir_native_generic_emit_call(model, ctx);
    }
    if model.shape.tag == 6 {
        return mir_native_generic_emit_scalar_expression(model, ctx);
    }
    if model.shape.tag == 7 {
        return mir_native_generic_emit_positive_local_branch(model, ctx);
    }
    return mir.mir_make_program_bundle("invalid", ctx);
}

func mir_native_generic_plan_add(plan: capability.MirNativeBackendCapabilityPlan[ctx], kind_tag: int, module_path: str, ordinal: int, feature: str, ctx: &Arena) capability.MirNativeBackendCapabilityPlan[ctx] {
    return capability.mir_native_backend_capability_plan_with_requirement(
        plan,
        capability.mir_native_backend_make_requirement(
            kind_tag,
            module_path,
            "main",
            "entry",
            ordinal,
            feature,
            ctx
        ),
        ctx
    );
}

func mir_native_generic_contains(value: str, needle: str) int {
    if std.str_find(value, needle) == 0 - 1 {
        return 0;
    }
    return 1;
}

func mir_native_generic_plan_from_bundle(bundle: mir.MirProgramBundle[ctx], ctx: &Arena) capability.MirNativeBackendCapabilityPlan[ctx] {
    mut plan := capability.mir_native_backend_make_capability_plan(ctx);
    mut modules: std.Vector[mir.MirProgramBundleModule[ctx], ctx] :=
        ctx[bundle.modules];
    if len(modules) == 0 {
        return plan;
    }

    mut module_path := modules[0].module_path;
    mut has_local_set := 0;
    mut has_local_read := 0;
    mut has_add := 0;
    mut has_sub := 0;
    mut has_mul := 0;
    mut has_sgt := 0;
    mut has_jump := 0;
    mut has_branch := 0;
    mut has_block_param := 0;
    mut has_local_call := 0;
    mut has_imported_call := 0;
    mut has_imported_void_call := 0;
    mut has_local_string_set_call := 0;
    mut has_arena_init := 0;
    mut has_arena_store_i32 := 0;
    mut has_arena_load_i32 := 0;
    mut has_return := 0;
    mut has_int := 0;
    mut has_bool := 0;
    mut has_str := 0;
    mut has_arena := 0;
    mut has_usize := 0;
    mut has_zero_int_abi := 0;
    mut has_one_int_abi := 0;
    mut has_two_int_abi := 0;
    mut has_direct_scalar_abi := 0;

    mut module_index := 0;
    while module_index < len(modules) {
        mut module := modules[module_index];
        mut canonical := module.canonical_mir;

        if mir_native_generic_contains(canonical, "LocalI32Set") == 1 {
            has_local_set = 1;
        }
        if mir_native_generic_contains(canonical, "ReturnLocalI32") == 1 ||
           mir_native_generic_contains(
               canonical,
               "BranchLocalI32Positive"
           ) == 1
        {
            has_local_read = 1;
        }
        if mir_native_generic_contains(
            canonical,
            "LocalI32AddI32Literal"
        ) == 1 ||
           mir_native_generic_contains(
               canonical,
               "BlockParamI32AddI32Literal"
           ) == 1
        {
            has_add = 1;
        }
        if mir_native_generic_contains(
            canonical,
            "LocalI32SubI32Literal"
        ) == 1 {
            has_sub = 1;
        }
        if mir_native_generic_contains(
            canonical,
            "LocalI32MulI32Literal"
        ) == 1 {
            has_mul = 1;
        }
        if mir_native_generic_contains(
            canonical,
            "BranchLocalI32Positive"
        ) == 1 ||
           mir_native_generic_contains(
               canonical,
               "BranchBlockParamI32Positive"
           ) == 1
        {
            has_sgt = 1;
        }
        if mir_native_generic_contains(
            canonical,
            "terminator_kind: Jump"
        ) == 1 {
            has_jump = 1;
        }
        if mir_native_generic_contains(
            canonical,
            "BranchI32Literal"
        ) == 1 ||
           mir_native_generic_contains(
               canonical,
               "BranchLocalI32Positive"
           ) == 1 ||
           mir_native_generic_contains(
               canonical,
               "BranchBlockParamI32Positive"
           ) == 1
        {
            has_branch = 1;
        }
        mut block_parameters:
            std.Vector[mir.MirProgramBundleBlockParameter[ctx], ctx] :=
                ctx[module.block_parameters];
        if len(block_parameters) > 0 ||
           mir_native_generic_contains(
               canonical,
               "ReturnBlockParamI32"
           ) == 1
        {
            has_block_param = 1;
        }
        if mir_native_generic_contains(
            canonical,
            "callee_kind: LocalFunction"
        ) == 1 {
            has_local_call = 1;
            has_direct_scalar_abi = 1;
        }
        if mir_native_generic_contains(
            canonical,
            "callee_kind: ImportedFunction"
        ) == 1 &&
           mir_native_generic_contains(
               canonical,
               "kind: LocalI32SetCall"
           ) == 1 {
            has_imported_call = 1;
        }
        if mir_native_generic_contains(canonical, "kind: CallVoid") == 1 {
            has_imported_void_call = 1;
        }
        if mir_native_generic_contains(canonical, "kind: LocalStringSetCall") == 1 {
            has_local_string_set_call = 1;
        }
        if mir_native_generic_contains(canonical, "kind: ArenaInit") == 1 {
            has_arena_init = 1;
        }
        if mir_native_generic_contains(canonical, "kind: ArenaStoreI32") == 1 {
            has_arena_store_i32 = 1;
        }
        if mir_native_generic_contains(canonical, "kind: LocalI32SetArenaLoad") == 1 {
            has_arena_load_i32 = 1;
        }
        if mir_native_generic_contains(canonical, "ReturnI32") == 1 ||
           mir_native_generic_contains(canonical, "ReturnLocalI32") == 1 ||
           mir_native_generic_contains(
               canonical,
               "ReturnBlockParamI32"
           ) == 1
        {
            has_return = 1;
        }
        if mir_native_generic_contains(canonical, "type: int") == 1 ||
           mir_native_generic_contains(canonical, "return_type: int") == 1 {
            has_int = 1;
        }
        if mir_native_generic_contains(canonical, "type: bool") == 1 ||
           mir_native_generic_contains(
               canonical,
               "return_type: bool"
           ) == 1 ||
           mir_native_generic_contains(
               canonical,
               "BranchI32Literal"
           ) == 1 ||
           mir_native_generic_contains(
               canonical,
               "BranchLocalI32Positive"
           ) == 1 ||
           mir_native_generic_contains(
               canonical,
               "BranchBlockParamI32Positive"
           ) == 1
        {
            has_bool = 1;
        }
        if mir_native_generic_contains(canonical, "type: str") == 1 {
            has_str = 1;
        }
        if mir_native_generic_contains(canonical, "type: arena") == 1 ||
           mir_native_generic_contains(canonical, "return_type: arena") == 1 {
            has_arena = 1;
        }
        if mir_native_generic_contains(canonical, "type: usize") == 1 ||
           mir_native_generic_contains(canonical, "return_type: usize") == 1 {
            has_usize = 1;
        }

        mut symbols: std.Vector[mir.MirProgramBundleSymbol[ctx], ctx] :=
            ctx[module.symbols];
        mut symbol_index := 0;
        while symbol_index < len(symbols) {
            mut symbol := symbols[symbol_index];
            if std.str_eq(symbol.signature, "()->int") == 1 {
                has_zero_int_abi = 1;
            }
            if std.str_eq(symbol.signature, "(int)->int") == 1 {
                has_one_int_abi = 1;
            }
            if std.str_eq(symbol.signature, "(int,int)->int") == 1 {
                has_two_int_abi = 1;
            }
            symbol_index = symbol_index + 1;
        }

        module_index = module_index + 1;
    }

    mut ordinal := 0;
    if has_local_set == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            0,
            module_path,
            ordinal,
            "LocalI32Set",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_local_read == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            0,
            module_path,
            ordinal,
            "LocalI32Read",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_add == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            0,
            module_path,
            ordinal,
            "AddI32",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_sub == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            0,
            module_path,
            ordinal,
            "SubI32",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_mul == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            0,
            module_path,
            ordinal,
            "MulI32",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_sgt == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            0,
            module_path,
            ordinal,
            "SgtI32",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_jump == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            0,
            module_path,
            ordinal,
            "Jump",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_branch == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            0,
            module_path,
            ordinal,
            "Branch",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_block_param == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            0,
            module_path,
            ordinal,
            "BlockParam",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_local_call == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            0,
            module_path,
            ordinal,
            "LocalCallI32",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_imported_call == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            0,
            module_path,
            ordinal,
            "ImportedCallI32",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_imported_void_call == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            0,
            module_path,
            ordinal,
            "ImportedCallVoid",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_local_string_set_call == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            0,
            module_path,
            ordinal,
            "LocalStringSetCall",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_arena_init == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            0,
            module_path,
            ordinal,
            "ArenaInit",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_arena_store_i32 == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            0,
            module_path,
            ordinal,
            "ArenaStoreI32",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_arena_load_i32 == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            0,
            module_path,
            ordinal,
            "LocalI32SetArenaLoad",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_return == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            0,
            module_path,
            ordinal,
            "ReturnI32",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_int == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            1,
            module_path,
            ordinal,
            "int",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_bool == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            1,
            module_path,
            ordinal,
            "bool",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_str == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            1,
            module_path,
            ordinal,
            "str",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_arena == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            1,
            module_path,
            ordinal,
            "arena",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_usize == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            1,
            module_path,
            ordinal,
            "usize",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_zero_int_abi == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            1,
            module_path,
            ordinal,
            "()->int",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_one_int_abi == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            1,
            module_path,
            ordinal,
            "(int)->int",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_two_int_abi == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            1,
            module_path,
            ordinal,
            "(int,int)->int",
            ctx
        );
        ordinal = ordinal + 1;
    }
    if has_direct_scalar_abi == 1 {
        plan = mir_native_generic_plan_add(
            plan,
            1,
            module_path,
            ordinal,
            "direct_scalar_abi",
            ctx
        );
        ordinal = ordinal + 1;
    }

    module_index = 0;
    while module_index < len(modules) {
        mut module := modules[module_index];
        mut symbols: std.Vector[mir.MirProgramBundleSymbol[ctx], ctx] :=
            ctx[module.symbols];
        mut symbol_index := 0;
        while symbol_index < len(symbols) {
            mut symbol := symbols[symbol_index];
            if symbol.linkage.tag == 2 {
                plan = mir_native_generic_plan_add(
                    plan,
                    2,
                    module.module_path,
                    ordinal,
                    symbol.link_name,
                    ctx
                );
                ordinal = ordinal + 1;
            }
            symbol_index = symbol_index + 1;
        }
        module_index = module_index + 1;
    }

    plan = mir_native_generic_plan_add(
        plan,
        3,
        module_path,
        ordinal,
        "native_host",
        ctx
    );
    ordinal = ordinal + 1;
    plan = mir_native_generic_plan_add(
        plan,
        3,
        module_path,
        ordinal,
        "position_independent_code",
        ctx
    );
    ordinal = ordinal + 1;
    plan = mir_native_generic_plan_add(
        plan,
        3,
        module_path,
        ordinal,
        "native_executable_link",
        ctx
    );
    return plan;
}

func mir_native_generic_source_lower(programs: std.Vector[ast.Program[ctx], ctx], module_paths: std.Vector[str, ctx], module_prefixes: std.Vector[str, ctx], static_capabilities: capability.MirNativeBackendCapabilitySet[ctx], ctx: &Arena) MirNativeGenericSourceResult[ctx] {
    mut model := mir_native_generic_analyze(
        programs,
        module_paths,
        module_prefixes,
        ctx
    );
    mut bundle := mir.mir_make_program_bundle("invalid", ctx);
    if model.represented == 1 {
        bundle = mir_native_generic_emit_bundle(model, ctx);
    } else {
        mut metadata_source_result :=
            metadata_source.mir_native_metadata_source_lower(
                programs,
                module_paths,
                module_prefixes,
                ctx
            );
        if metadata_source_result.invalid == 1 {
            return mir_native_generic_empty_result(
                3,
                metadata_source_result.diagnostic,
                ctx
            );
        }
        if metadata_source_result.deferred == 1 {
            return mir_native_generic_deferred_result(
                metadata_source_result.reason_code,
                metadata_source_result.diagnostic,
                ctx
            );
        }
        if metadata_source_result.represented == 1 {
            bundle = metadata_source_result.bundle;
        } else {
        mut scalar_expression_result :=
            scalar_expression.mir_native_scalar_expression_source_lower(
                programs,
                module_paths,
                module_prefixes,
                ctx
            );
        if scalar_expression_result.invalid == 1 {
            return mir_native_generic_empty_result(
                3,
                scalar_expression_result.diagnostic,
                ctx
            );
        }
        if scalar_expression_result.represented == 1 {
            bundle = scalar_expression_result.bundle;
        } else {
            mut parameter_argument_result :=
                parameter_argument.mir_native_parameter_argument_source_lower(
                    programs,
                    module_paths,
                    module_prefixes,
                    ctx
                );
            if parameter_argument_result.invalid == 1 {
                return mir_native_generic_empty_result(
                    3,
                    parameter_argument_result.diagnostic,
                    ctx
                );
            }
            if parameter_argument_result.deferred == 1 {
                return mir_native_generic_deferred_result(
                    parameter_argument_result.reason_code,
                    parameter_argument_result.diagnostic,
                    ctx
                );
            }
            if parameter_argument_result.represented == 1 {
                bundle = parameter_argument_result.bundle;
            } else {
                mut module_import_result :=
                    module_import.mir_native_module_import_source_lower(
                        programs,
                        module_paths,
                        module_prefixes,
                        ctx
                    );
                if module_import_result.invalid == 1 {
                    return mir_native_generic_empty_result(
                        3,
                        module_import_result.diagnostic,
                        ctx
                    );
                }
                if module_import_result.represented == 1 {
                    bundle = module_import_result.bundle;
                } else {
                    mut direct_call_result :=
                    direct_call.mir_native_direct_call_source_lower(
                        programs,
                        module_paths,
                        module_prefixes,
                        ctx
                    );
                if direct_call_result.invalid == 1 {
                    return mir_native_generic_empty_result(
                        3,
                        direct_call_result.diagnostic,
                        ctx
                    );
                }
                if direct_call_result.deferred == 1 {
                    return mir_native_generic_deferred_result(
                        direct_call_result.reason_code,
                        direct_call_result.diagnostic,
                        ctx
                    );
                }
                if direct_call_result.represented == 1 {
                    bundle = direct_call_result.bundle;
                } else {
                    mut block_parameter_loop_result :=
                        block_parameter_loop.mir_native_block_parameter_loop_source_lower(
                            programs,
                            module_paths,
                            module_prefixes,
                            ctx
                        );
                    if block_parameter_loop_result.invalid == 1 {
                        return mir_native_generic_empty_result(
                            3,
                            block_parameter_loop_result.diagnostic,
                            ctx
                        );
                    }
                    if block_parameter_loop_result.deferred == 1 {
                        return mir_native_generic_deferred_result(
                            block_parameter_loop_result.reason_code,
                            block_parameter_loop_result.diagnostic,
                            ctx
                        );
                    }
                    if block_parameter_loop_result.represented == 1 {
                        bundle = block_parameter_loop_result.bundle;
                    } else {
                        mut collection_string_result :=
                            collection_string.mir_native_collection_string_source_lower(
                                programs,
                                module_paths,
                                module_prefixes,
                                ctx
                            );
                        if collection_string_result.invalid == 1 {
                            return mir_native_generic_empty_result(
                                3,
                                collection_string_result.diagnostic,
                                ctx
                            );
                        }
                        if collection_string_result.represented == 1 {
                            bundle = collection_string_result.bundle;
                        } else {
                        mut filesystem_allocation_result :=
                            filesystem_allocation.mir_native_filesystem_allocation_source_lower(
                                programs,
                                module_paths,
                                module_prefixes,
                                ctx
                            );
                        if filesystem_allocation_result.invalid == 1 {
                            return mir_native_generic_empty_result(
                                3,
                                filesystem_allocation_result.diagnostic,
                                ctx
                            );
                        }
                        if filesystem_allocation_result.represented == 1 {
                            bundle = filesystem_allocation_result.bundle;
                        } else {
                        mut structured_cfg_result :=
                            structured_cfg.mir_native_structured_cfg_source_lower(
                                programs,
                                module_paths,
                                module_prefixes,
                                ctx
                            );
                        if structured_cfg_result.invalid == 1 {
                            return mir_native_generic_empty_result(
                                3,
                                structured_cfg_result.diagnostic,
                                ctx
                            );
                        }
                        if structured_cfg_result.deferred == 1 {
                            return mir_native_generic_deferred_result(
                                structured_cfg_result.reason_code,
                                structured_cfg_result.diagnostic,
                                ctx
                            );
                        }
                        if structured_cfg_result.represented == 1 {
                            bundle = structured_cfg_result.bundle;
                        } else {
                            mut local_state_result :=
                                local_state.mir_native_local_state_source_lower(
                                    programs,
                                    module_paths,
                                    module_prefixes,
                                    ctx
                                );
                            if local_state_result.invalid == 1 {
                                return mir_native_generic_empty_result(
                                    3,
                                    local_state_result.diagnostic,
                                    ctx
                                );
                            }
                            if local_state_result.represented == 0 {
                                return mir_native_generic_empty_result(1, "", ctx);
                            }
                            bundle = local_state_result.bundle;
                        }
                        }
                    }
                }
            }
        }
    }
    }
    }

    mut serialized := mir.mir_serialize_program_bundle(bundle, ctx);
    if std.str_eq(serialized, "format: invalid\n") == 1 {
        return mir_native_generic_empty_result(
            3,
            "Native backend internal error: generic canonical MIR serialization is invalid",
            ctx
        );
    }

    mut plan := mir_native_generic_plan_from_bundle(bundle, ctx);
    mut capability_result :=
        capability.mir_native_backend_validate_capabilities(
            bundle,
            plan,
            static_capabilities,
            ctx
        );
    if capability_result.classification.tag == 5 {
        return mir_native_generic_make_result(
            3,
            bundle,
            plan,
            capability.mir_native_backend_capability_diagnostic(
                capability_result,
                ctx
            ),
            ctx
        );
    }
    if capability_result.classification.tag != 0 {
        return mir_native_generic_make_result(
            2,
            bundle,
            plan,
            capability.mir_native_backend_capability_diagnostic(
                capability_result,
                ctx
            ),
            ctx
        );
    }

    return mir_native_generic_make_result(
        0,
        bundle,
        plan,
        "",
        ctx
    );
}
