import "ast.gst" as ast;
import "mir.gst" as mir;
import "mir_native_backend_capability.gst" as capability;
import "mir_native_backend_block_parameter_loop_source.gst" as block_parameter_loop;
import "mir_native_backend_capability.gst" as capability;
import "mir_native_backend_direct_call_source.gst" as direct_call;
import "mir_native_backend_local_state_source.gst" as local_state;
import "mir_native_backend_module_import_source.gst" as module_import;
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

    return model;
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
    mut top_level: std.Vector[ast.Statement[ctx], ctx] :=
        ctx[program.statements];

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
    mut has_return := 0;
    mut has_int := 0;
    mut has_bool := 0;
    mut has_zero_int_abi := 0;
    mut has_one_int_abi := 0;
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
        ) == 1 {
            has_imported_call = 1;
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
                    if block_parameter_loop_result.represented == 1 {
                        bundle = block_parameter_loop_result.bundle;
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
