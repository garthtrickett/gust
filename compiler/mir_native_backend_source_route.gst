import "ast.gst" as ast;
import "mir.gst" as mir;
import "mir_native_backend_capability.gst" as capability;
import "mir_native_backend_driver.gst" as driver;
import "mir_native_backend_generic_source.gst" as generic_source;
import "mir_native_backend_request.gst" as request;

// Compiler-owned source route.
//
// The generic semantic route now runs before the closed exact-shape
// recognizers. It lowers the already-resolved and typechecked AST into the
// frozen canonical v1/v2 bundle vocabulary, derives capabilities by traversing
// that bundle, and shadow-compares any overlapping legacy result byte for byte.
// The exact recognizers remain temporary compatibility paths. Direct,
// statically named acyclic calls now accept integer/boolean scalar signatures
// with multiple parameters and arguments. Source imports, multiple source
// modules, indirect calls, closures, and non-scalar ABIs remain deferred.
type MirNativeScalarSourceLowering[ctx] struct {
    supported: int,
    bundle: mir.MirProgramBundle[ctx],
    plan: capability.MirNativeBackendCapabilityPlan[ctx]
}

type MirNativeScalarSourceRouteResult[ctx] struct {
    status: int,
    diagnostic: str
}

func mir_native_scalar_source_route_result(status: int, diagnostic: str, ctx: &Arena) MirNativeScalarSourceRouteResult[ctx] {
    mut result: MirNativeScalarSourceRouteResult[ctx];
    result.status = status;
    result.diagnostic = std.Clone(ctx, diagnostic);
    return result;
}

func mir_native_scalar_source_append(output: str, value: str, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat(output, value));
}

func mir_native_scalar_source_empty_lowering(ctx: &Arena) MirNativeScalarSourceLowering[ctx] {
    mut lowering: MirNativeScalarSourceLowering[ctx];
    lowering.supported = 0;
    lowering.bundle = mir.mir_make_program_bundle("invalid", ctx);
    lowering.plan = capability.mir_native_backend_make_capability_plan(ctx);
    return lowering;
}

func mir_native_scalar_source_add_requirement(plan: capability.MirNativeBackendCapabilityPlan[ctx], kind_tag: int, source_path: str, ordinal: int, feature: str, ctx: &Arena) capability.MirNativeBackendCapabilityPlan[ctx] {
    return capability.mir_native_backend_capability_plan_with_requirement(
        plan,
        capability.mir_native_backend_make_requirement(
            kind_tag,
            source_path,
            "main",
            "entry",
            ordinal,
            feature,
            ctx
        ),
        ctx
    );
}

func mir_native_scalar_source_capabilities(ctx: &Arena) capability.MirNativeBackendCapabilitySet[ctx] {
    mut capabilities := capability.mir_native_backend_make_capability_set(ctx);
    capabilities = capability.mir_native_backend_capability_set_with_operation(
        capabilities,
        "ReturnI32",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_operation(
        capabilities,
        "LocalI32Set",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_operation(
        capabilities,
        "LocalI32Read",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_operation(
        capabilities,
        "AddI32",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_operation(
        capabilities,
        "SgtI32",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_operation(
        capabilities,
        "Jump",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_operation(
        capabilities,
        "Branch",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_operation(
        capabilities,
        "BlockParam",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_operation(
        capabilities,
        "LocalCallI32",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_operation(
        capabilities,
        "ImportedCallI32",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_type_or_abi(
        capabilities,
        "int",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_type_or_abi(
        capabilities,
        "bool",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_type_or_abi(
        capabilities,
        "()->int",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_type_or_abi(
        capabilities,
        "(int)->int",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_type_or_abi(
        capabilities,
        "direct_scalar_abi",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_runtime_import(
        capabilities,
        "abs",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_target_requirement(
        capabilities,
        "native_host",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_target_requirement(
        capabilities,
        "position_independent_code",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_target_requirement(
        capabilities,
        "native_executable_link",
        ctx
    );
    return capabilities;
}

func mir_native_scalar_source_lower(programs: std.Vector[ast.Program[ctx], ctx], module_paths: std.Vector[str, ctx], module_prefixes: std.Vector[str, ctx], ctx: &Arena) MirNativeScalarSourceLowering[ctx] {
    mut lowering := mir_native_scalar_source_empty_lowering(ctx);

    if len(programs) != 1 || len(module_paths) != 1 || len(module_prefixes) != 1 {
        return lowering;
    }
    if std.str_eq(module_prefixes[0], "") == 0 {
        return lowering;
    }

    mut source_path := module_paths[0];
    mut program := programs[0];
    mut top_level: std.Vector[ast.Statement[ctx], ctx] := ctx[program.statements];
    if len(top_level) != 1 {
        return lowering;
    }

    unsafe {
        mut function_statement := top_level[0];
        if function_statement.tag != 3 {
            return lowering;
        }
        if std.str_eq(function_statement.FunctionDecl.name, "main") == 0 {
            return lowering;
        }
        if function_statement.FunctionDecl.is_extern == 1 {
            return lowering;
        }

        mut parameters: std.Vector[ast.Parameter[ctx], ctx] :=
            ctx[function_statement.FunctionDecl.params];
        if len(parameters) != 0 {
            return lowering;
        }

        mut return_type := ctx[function_statement.FunctionDecl.return_type];
        if return_type.tag != 0 {
            return lowering;
        }

        mut body := ctx[function_statement.FunctionDecl.body];
        mut statements: std.Vector[ast.Statement[ctx], ctx] := ctx[body.statements];

        mut is_literal_return := 0;
        mut is_local_return := 0;
        mut return_value := 0;
        mut local_name := "";

        if len(statements) == 1 {
            mut return_statement := statements[0];
            if return_statement.tag == 12 {
                mut return_expression := ctx[return_statement.Return.expr];
                if return_expression.tag == 1 {
                    is_literal_return = 1;
                    return_value = return_expression.Integer.val;
                }
            }
        } else if len(statements) == 2 {
            mut local_statement := statements[0];
            mut return_statement := statements[1];

            if local_statement.tag == 4 && return_statement.tag == 12 {
                mut local_expression := ctx[local_statement.VarDecl.value];
                mut return_expression := ctx[return_statement.Return.expr];

                if local_expression.tag == 1 && return_expression.tag == 0 {
                    if std.str_eq(
                        local_statement.VarDecl.name,
                        return_expression.Identifier.name
                    ) == 1 {
                        if local_statement.VarDecl.var_type !=
                            empty[Index[ast.Type[ctx], ctx]]
                        {
                            mut declared_type := ctx[local_statement.VarDecl.var_type];
                            if declared_type.tag != 0 {
                                return lowering;
                            }
                        }

                        is_local_return = 1;
                        return_value = local_expression.Integer.val;
                        local_name = std.Clone(
                            ctx,
                            local_statement.VarDecl.name
                        );
                    }
                }
            }
        }

        if is_literal_return == 0 && is_local_return == 0 {
            return lowering;
        }

        mut canonical := "format: gust.compiler_mir_ingestion.v1\n";
        canonical = mir_native_scalar_source_append(
            canonical,
            "function: main\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "backend_symbol: main\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "parameter_count: 0\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "return_type: int\n",
            ctx
        );

        if is_local_return == 1 {
            canonical = mir_native_scalar_source_append(
                canonical,
                "local_count: 1\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "local_0_name: ",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                local_name,
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "\nlocal_0_type: int\n",
                ctx
            );
        } else {
            canonical = mir_native_scalar_source_append(
                canonical,
                "local_count: 0\n",
                ctx
            );
        }

        canonical = mir_native_scalar_source_append(
            canonical,
            "entry_block: entry\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "block_count: 1\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "block_0_label: entry\n",
            ctx
        );

        if is_local_return == 1 {
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_statement_count: 1\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_statement_0_kind: LocalI32Set\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_statement_0_local: ",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                local_name,
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "\nblock_0_statement_0_value: ",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                std.FormatInt(return_value),
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "\nblock_0_terminator_kind: ReturnLocalI32\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_terminator_local: ",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                local_name,
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "\nmetadata_count: 1\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "metadata_0_kind: provenance\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "metadata_0_attachment: statement:entry:0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "metadata_0_policy: ignored_with_proof\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "metadata_0_payload: kind=LocalBinding;local=",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                local_name,
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                ";origin=",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                source_path,
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "\n",
                ctx
            );
        } else {
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_statement_count: 0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_terminator_kind: ReturnI32\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_terminator_value: ",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                std.FormatInt(return_value),
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "\nmetadata_count: 0\n",
                ctx
            );
        }

        canonical = mir_native_scalar_source_append(
            canonical,
            "expected_exit: ",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            std.FormatInt(return_value),
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "\n",
            ctx
        );

        mut bundle := mir.mir_make_program_bundle("main", ctx);
        mut bundle_module := mir.mir_make_program_bundle_module(
            source_path,
            "",
            "phase10_scalar_module.o",
            "gust.compiler_mir_ingestion.v1",
            canonical,
            0,
            is_local_return,
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
        bundle = mir.mir_program_bundle_with_module(
            bundle,
            bundle_module,
            ctx
        );

        mut plan := capability.mir_native_backend_make_capability_plan(ctx);
        mut ordinal := 0;
        if is_local_return == 1 {
            plan = mir_native_scalar_source_add_requirement(
                plan,
                0,
                source_path,
                ordinal,
                "LocalI32Set",
                ctx
            );
            ordinal = ordinal + 1;
            plan = mir_native_scalar_source_add_requirement(
                plan,
                0,
                source_path,
                ordinal,
                "LocalI32Read",
                ctx
            );
            ordinal = ordinal + 1;
        }
        plan = mir_native_scalar_source_add_requirement(
            plan,
            0,
            source_path,
            ordinal,
            "ReturnI32",
            ctx
        );
        ordinal = ordinal + 1;
        plan = mir_native_scalar_source_add_requirement(
            plan,
            1,
            source_path,
            ordinal,
            "int",
            ctx
        );
        ordinal = ordinal + 1;
        plan = mir_native_scalar_source_add_requirement(
            plan,
            1,
            source_path,
            ordinal,
            "()->int",
            ctx
        );
        ordinal = ordinal + 1;
        plan = mir_native_scalar_source_add_requirement(
            plan,
            3,
            source_path,
            ordinal,
            "native_host",
            ctx
        );
        ordinal = ordinal + 1;
        plan = mir_native_scalar_source_add_requirement(
            plan,
            3,
            source_path,
            ordinal,
            "position_independent_code",
            ctx
        );
        ordinal = ordinal + 1;
        plan = mir_native_scalar_source_add_requirement(
            plan,
            3,
            source_path,
            ordinal,
            "native_executable_link",
            ctx
        );

        lowering.supported = 1;
        lowering.bundle = bundle;
        lowering.plan = plan;
        return lowering;
    }
}


func mir_native_cfg_source_lower(programs: std.Vector[ast.Program[ctx], ctx], module_paths: std.Vector[str, ctx], module_prefixes: std.Vector[str, ctx], ctx: &Arena) MirNativeScalarSourceLowering[ctx] {
    mut lowering := mir_native_scalar_source_empty_lowering(ctx);

    if len(programs) != 1 || len(module_paths) != 1 || len(module_prefixes) != 1 {
        return lowering;
    }
    if std.str_eq(module_prefixes[0], "") == 0 {
        return lowering;
    }

    mut source_path := module_paths[0];
    mut program := programs[0];
    mut top_level: std.Vector[ast.Statement[ctx], ctx] := ctx[program.statements];
    if len(top_level) != 1 {
        return lowering;
    }

    unsafe {
        mut function_statement := top_level[0];
        if function_statement.tag != 3 {
            return lowering;
        }
        if std.str_eq(function_statement.FunctionDecl.name, "main") == 0 {
            return lowering;
        }
        if function_statement.FunctionDecl.is_extern == 1 {
            return lowering;
        }

        mut parameters: std.Vector[ast.Parameter[ctx], ctx] :=
            ctx[function_statement.FunctionDecl.params];
        if len(parameters) != 0 {
            return lowering;
        }

        mut return_type := ctx[function_statement.FunctionDecl.return_type];
        if return_type.tag != 0 {
            return lowering;
        }

        mut body := ctx[function_statement.FunctionDecl.body];
        mut statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[body.statements];

        mut is_literal_cfg := 0;
        mut is_block_parameter_merge := 0;
        mut condition_value := 0;
        mut initial_value := 0;
        mut then_value := 0;
        mut else_value := 0;
        mut expected_exit := 0;
        mut local_name := "";

        if len(statements) == 1 {
            mut if_statement := statements[0];
            if if_statement.tag == 7 {
                mut condition := ctx[if_statement.If.condition];
                mut consequence := ctx[if_statement.If.consequence];
                mut alternative := ctx[if_statement.If.alternative];
                mut then_statements: std.Vector[ast.Statement[ctx], ctx] :=
                    ctx[consequence.statements];
                mut else_statements: std.Vector[ast.Statement[ctx], ctx] :=
                    ctx[alternative.statements];

                if condition.tag == 3 &&
                   len(then_statements) == 1 &&
                   len(else_statements) == 1
                {
                    mut then_return := then_statements[0];
                    mut else_return := else_statements[0];
                    if then_return.tag == 12 && else_return.tag == 12 {
                        mut then_expression := ctx[then_return.Return.expr];
                        mut else_expression := ctx[else_return.Return.expr];
                        if then_expression.tag == 1 &&
                           else_expression.tag == 1
                        {
                            is_literal_cfg = 1;
                            condition_value = condition.Bool.val;
                            then_value = then_expression.Integer.val;
                            else_value = else_expression.Integer.val;
                            expected_exit = else_value;
                            if condition_value != 0 {
                                expected_exit = then_value;
                            }
                        }
                    }
                }
            }
        } else if len(statements) == 3 {
            mut local_statement := statements[0];
            mut if_statement := statements[1];
            mut return_statement := statements[2];

            if local_statement.tag == 4 &&
               if_statement.tag == 7 &&
               return_statement.tag == 12
            {
                mut local_expression := ctx[local_statement.VarDecl.value];
                mut return_expression := ctx[return_statement.Return.expr];

                if local_statement.VarDecl.is_mut == 1 &&
                   local_expression.tag == 1 &&
                   return_expression.tag == 0
                {
                    local_name = std.Clone(
                        ctx,
                        local_statement.VarDecl.name
                    );

                    if std.str_eq(
                        local_name,
                        return_expression.Identifier.name
                    ) == 1 {
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

                        mut condition := ctx[if_statement.If.condition];
                        mut consequence := ctx[if_statement.If.consequence];
                        mut alternative := ctx[if_statement.If.alternative];
                        mut then_statements:
                            std.Vector[ast.Statement[ctx], ctx] :=
                                ctx[consequence.statements];
                        mut else_statements:
                            std.Vector[ast.Statement[ctx], ctx] :=
                                ctx[alternative.statements];

                        if declared_type_is_int == 1 &&
                           condition.tag == 10 &&
                           std.str_eq(condition.Binary.op, ">") == 1 &&
                           len(then_statements) == 1 &&
                           len(else_statements) == 1
                        {
                            mut condition_left :=
                                ctx[condition.Binary.left];
                            mut condition_right :=
                                ctx[condition.Binary.right];
                            mut then_assignment := then_statements[0];
                            mut else_assignment := else_statements[0];

                            if condition_left.tag == 0 &&
                               condition_right.tag == 1 &&
                               condition_right.Integer.val == 0 &&
                               std.str_eq(
                                   condition_left.Identifier.name,
                                   local_name
                               ) == 1 &&
                               then_assignment.tag == 5 &&
                               else_assignment.tag == 5
                            {
                                mut then_left :=
                                    ctx[then_assignment.Assignment.left];
                                mut then_expression :=
                                    ctx[then_assignment.Assignment.value];
                                mut else_left :=
                                    ctx[else_assignment.Assignment.left];
                                mut else_expression :=
                                    ctx[else_assignment.Assignment.value];

                                if then_left.tag == 0 &&
                                   else_left.tag == 0 &&
                                   then_expression.tag == 1 &&
                                   else_expression.tag == 1 &&
                                   std.str_eq(
                                       then_left.Identifier.name,
                                       local_name
                                   ) == 1 &&
                                   std.str_eq(
                                       else_left.Identifier.name,
                                       local_name
                                   ) == 1
                                {
                                    is_block_parameter_merge = 1;
                                    initial_value =
                                        local_expression.Integer.val;
                                    then_value =
                                        then_expression.Integer.val;
                                    else_value =
                                        else_expression.Integer.val;
                                    expected_exit = else_value;
                                    if initial_value > 0 {
                                        expected_exit = then_value;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        if is_literal_cfg == 0 && is_block_parameter_merge == 0 {
            return lowering;
        }

        mut canonical := "format: gust.compiler_mir_ingestion.v1\n";
        canonical = mir_native_scalar_source_append(
            canonical,
            "function: main\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "backend_symbol: main\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "parameter_count: 0\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "return_type: int\n",
            ctx
        );

        if is_block_parameter_merge == 1 {
            canonical = mir_native_scalar_source_append(
                canonical,
                "local_count: 1\nlocal_0_name: ",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                local_name,
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "\nlocal_0_type: int\n",
                ctx
            );
        } else {
            canonical = mir_native_scalar_source_append(
                canonical,
                "local_count: 0\n",
                ctx
            );
        }

        canonical = mir_native_scalar_source_append(
            canonical,
            "entry_block: entry\n",
            ctx
        );

        if is_literal_cfg == 1 {
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_count: 3\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_label: entry\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_parameter_count: 0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_statement_count: 0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_terminator_kind: BranchI32Literal\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_terminator_condition: ",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                std.FormatInt(condition_value),
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "\nblock_0_terminator_then: then\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_terminator_then_argument_count: 0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_terminator_else: else\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_terminator_else_argument_count: 0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_1_label: then\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_1_parameter_count: 0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_1_statement_count: 0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_1_terminator_kind: ReturnI32\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_1_terminator_value: ",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                std.FormatInt(then_value),
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "\nblock_2_label: else\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_2_parameter_count: 0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_2_statement_count: 0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_2_terminator_kind: ReturnI32\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_2_terminator_value: ",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                std.FormatInt(else_value),
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "\nmetadata_count: 0\n",
                ctx
            );
        } else {
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_count: 4\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_label: entry\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_parameter_count: 0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_statement_count: 1\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_statement_0_kind: LocalI32Set\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_statement_0_local: ",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                local_name,
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "\nblock_0_statement_0_value: ",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                std.FormatInt(initial_value),
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "\nblock_0_terminator_kind: BranchLocalI32Positive\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_terminator_local: ",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                local_name,
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "\nblock_0_terminator_then: then\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_terminator_then_argument_count: 0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_terminator_else: else\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_terminator_else_argument_count: 0\n",
                ctx
            );

            canonical = mir_native_scalar_source_append(
                canonical,
                "block_1_label: then\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_1_parameter_count: 0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_1_statement_count: 0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_1_terminator_kind: Jump\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_1_terminator_target: merge\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_1_terminator_argument_count: 1\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_1_terminator_argument_0_kind: I32Literal\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_1_terminator_argument_0_value: ",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                std.FormatInt(then_value),
                ctx
            );

            canonical = mir_native_scalar_source_append(
                canonical,
                "\nblock_2_label: else\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_2_parameter_count: 0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_2_statement_count: 0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_2_terminator_kind: Jump\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_2_terminator_target: merge\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_2_terminator_argument_count: 1\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_2_terminator_argument_0_kind: I32Literal\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_2_terminator_argument_0_value: ",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                std.FormatInt(else_value),
                ctx
            );

            canonical = mir_native_scalar_source_append(
                canonical,
                "\nblock_3_label: merge\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_3_parameter_count: 1\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_3_parameter_0_name: merged_value\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_3_parameter_0_type: int\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_3_statement_count: 0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_3_terminator_kind: ReturnBlockParamI32\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_3_terminator_block_param: merged_value\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "metadata_count: 1\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "metadata_0_kind: provenance\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "metadata_0_attachment: statement:entry:0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "metadata_0_policy: ignored_with_proof\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "metadata_0_payload: kind=LocalBinding;local=",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                local_name,
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                ";origin=",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                source_path,
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "\n",
                ctx
            );
        }

        canonical = mir_native_scalar_source_append(
            canonical,
            "expected_exit: ",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            std.FormatInt(expected_exit),
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "\n",
            ctx
        );

        mut object_name := "phase10_cfg_module.o";
        mut provenance_count := 0;
        mut block_parameter_count := 0;
        if is_block_parameter_merge == 1 {
            object_name = "phase10_block_parameter_module.o";
            provenance_count = 1;
            block_parameter_count = 1;
        }

        mut bundle := mir.mir_make_program_bundle("main", ctx);
        mut bundle_module := mir.mir_make_program_bundle_module(
            source_path,
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
        bundle = mir.mir_program_bundle_with_module(
            bundle,
            bundle_module,
            ctx
        );

        mut plan := capability.mir_native_backend_make_capability_plan(ctx);
        mut ordinal := 0;

        if is_block_parameter_merge == 1 {
            plan = mir_native_scalar_source_add_requirement(
                plan,
                0,
                source_path,
                ordinal,
                "LocalI32Set",
                ctx
            );
            ordinal = ordinal + 1;
            plan = mir_native_scalar_source_add_requirement(
                plan,
                0,
                source_path,
                ordinal,
                "LocalI32Read",
                ctx
            );
            ordinal = ordinal + 1;
            plan = mir_native_scalar_source_add_requirement(
                plan,
                0,
                source_path,
                ordinal,
                "SgtI32",
                ctx
            );
            ordinal = ordinal + 1;
        }

        plan = mir_native_scalar_source_add_requirement(
            plan,
            0,
            source_path,
            ordinal,
            "Branch",
            ctx
        );
        ordinal = ordinal + 1;

        if is_block_parameter_merge == 1 {
            plan = mir_native_scalar_source_add_requirement(
                plan,
                0,
                source_path,
                ordinal,
                "Jump",
                ctx
            );
            ordinal = ordinal + 1;
            plan = mir_native_scalar_source_add_requirement(
                plan,
                0,
                source_path,
                ordinal,
                "BlockParam",
                ctx
            );
            ordinal = ordinal + 1;
        }

        plan = mir_native_scalar_source_add_requirement(
            plan,
            0,
            source_path,
            ordinal,
            "ReturnI32",
            ctx
        );
        ordinal = ordinal + 1;
        plan = mir_native_scalar_source_add_requirement(
            plan,
            1,
            source_path,
            ordinal,
            "int",
            ctx
        );
        ordinal = ordinal + 1;
        if is_literal_cfg == 1 {
            plan = mir_native_scalar_source_add_requirement(
                plan,
                1,
                source_path,
                ordinal,
                "bool",
                ctx
            );
            ordinal = ordinal + 1;
        }
        plan = mir_native_scalar_source_add_requirement(
            plan,
            1,
            source_path,
            ordinal,
            "()->int",
            ctx
        );
        ordinal = ordinal + 1;
        plan = mir_native_scalar_source_add_requirement(
            plan,
            3,
            source_path,
            ordinal,
            "native_host",
            ctx
        );
        ordinal = ordinal + 1;
        plan = mir_native_scalar_source_add_requirement(
            plan,
            3,
            source_path,
            ordinal,
            "position_independent_code",
            ctx
        );
        ordinal = ordinal + 1;
        plan = mir_native_scalar_source_add_requirement(
            plan,
            3,
            source_path,
            ordinal,
            "native_executable_link",
            ctx
        );

        lowering.supported = 1;
        lowering.bundle = bundle;
        lowering.plan = plan;
        return lowering;
    }
}


func mir_native_call_import_source_lower(programs: std.Vector[ast.Program[ctx], ctx], module_paths: std.Vector[str, ctx], module_prefixes: std.Vector[str, ctx], ctx: &Arena) MirNativeScalarSourceLowering[ctx] {
    mut lowering := mir_native_scalar_source_empty_lowering(ctx);

    if len(programs) != 1 || len(module_paths) != 1 || len(module_prefixes) != 1 {
        return lowering;
    }
    if std.str_eq(module_prefixes[0], "") == 0 {
        return lowering;
    }

    mut source_path := module_paths[0];
    mut program := programs[0];
    mut top_level: std.Vector[ast.Statement[ctx], ctx] := ctx[program.statements];
    if len(top_level) != 2 {
        return lowering;
    }

    unsafe {
        mut first := top_level[0];
        mut second := top_level[1];
        if first.tag != 3 || second.tag != 3 {
            return lowering;
        }

        mut main_statement := second;
        if std.str_eq(main_statement.FunctionDecl.name, "main") == 0 ||
           main_statement.FunctionDecl.is_extern == 1
        {
            return lowering;
        }

        mut main_parameters: std.Vector[ast.Parameter[ctx], ctx] :=
            ctx[main_statement.FunctionDecl.params];
        if len(main_parameters) != 0 {
            return lowering;
        }
        mut main_return_type := ctx[main_statement.FunctionDecl.return_type];
        if main_return_type.tag != 0 {
            return lowering;
        }

        mut main_body := ctx[main_statement.FunctionDecl.body];
        mut main_statements: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[main_body.statements];

        mut is_local_call := 0;
        mut is_runtime_boundary := 0;
        mut call_value := 0;
        mut call_name := "";
        mut call_expression: ast.Expression[ctx];

        if first.FunctionDecl.is_extern == 0 {
            if std.str_eq(
                first.FunctionDecl.name,
                "phase10_local_identity"
            ) == 0 {
                return lowering;
            }

            mut helper_parameters: std.Vector[ast.Parameter[ctx], ctx] :=
                ctx[first.FunctionDecl.params];
            if len(helper_parameters) != 1 ||
               helper_parameters[0].param_type.tag != 0
            {
                return lowering;
            }
            mut helper_return_type := ctx[first.FunctionDecl.return_type];
            if helper_return_type.tag != 0 {
                return lowering;
            }

            mut helper_body := ctx[first.FunctionDecl.body];
            mut helper_statements: std.Vector[ast.Statement[ctx], ctx] :=
                ctx[helper_body.statements];
            if len(helper_statements) != 1 ||
               helper_statements[0].tag != 12
            {
                return lowering;
            }

            mut helper_return :=
                ctx[helper_statements[0].Return.expr];
            if helper_return.tag != 0 ||
               std.str_eq(
                   helper_return.Identifier.name,
                   helper_parameters[0].name
               ) == 0
            {
                return lowering;
            }

            if len(main_statements) != 1 ||
               main_statements[0].tag != 12
            {
                return lowering;
            }
            call_expression = ctx[main_statements[0].Return.expr];
            call_name = "phase10_local_identity";
            is_local_call = 1;
        } else {
            if std.str_eq(first.FunctionDecl.name, "abs") == 0 ||
               std.str_eq(first.FunctionDecl.extern_symbol_name, "abs") == 0 ||
               std.str_eq(first.FunctionDecl.extern_abi, "C") == 0
            {
                return lowering;
            }

            mut extern_parameters: std.Vector[ast.Parameter[ctx], ctx] :=
                ctx[first.FunctionDecl.params];
            if len(extern_parameters) != 1 ||
               extern_parameters[0].param_type.tag != 0
            {
                return lowering;
            }
            mut extern_return_type := ctx[first.FunctionDecl.return_type];
            if extern_return_type.tag != 0 {
                return lowering;
            }

            if len(main_statements) != 1 ||
               main_statements[0].tag != 10
            {
                return lowering;
            }
            mut unsafe_body := ctx[main_statements[0].UnsafeBlock.body];
            mut unsafe_statements: std.Vector[ast.Statement[ctx], ctx] :=
                ctx[unsafe_body.statements];
            if len(unsafe_statements) != 1 ||
               unsafe_statements[0].tag != 12
            {
                return lowering;
            }
            call_expression = ctx[unsafe_statements[0].Return.expr];
            call_name = "abs";
            is_runtime_boundary = 1;
        }

        if call_expression.tag != 12 {
            return lowering;
        }
        mut callee := ctx[call_expression.Call.function];
        if callee.tag != 0 ||
           std.str_eq(callee.Identifier.name, call_name) == 0
        {
            return lowering;
        }
        mut arguments: std.Vector[ast.Expression[ctx], ctx] :=
            ctx[call_expression.Call.arguments];
        if len(arguments) != 1 || arguments[0].tag != 1 {
            return lowering;
        }
        call_value = arguments[0].Integer.val;
        if call_value < 0 {
            return lowering;
        }

        mut canonical := "format: gust.compiler_mir_ingestion.v2\n";
        if is_local_call == 1 {
            canonical = mir_native_scalar_source_append(
                canonical,
                "module: phase10_local_call\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "import_count: 0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_count: 2\n",
                ctx
            );

            canonical = mir_native_scalar_source_append(
                canonical,
                "function_0_linkage: module_local\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_0_function: phase10_local_identity\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_0_backend_symbol: phase10_local_identity\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_0_parameter_count: 1\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_0_parameter_0_type: int\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_0_return_type: int\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_0_local_count: 1\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_0_local_0_name: param_value\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_0_local_0_type: int\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_0_entry_block: entry\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_0_block_count: 1\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_0_block_0_label: entry\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_0_block_0_parameter_count: 0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_0_block_0_statement_count: 1\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_0_block_0_statement_0_kind: LocalI32SetParam\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_0_block_0_statement_0_local: param_value\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_0_block_0_statement_0_param: 0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_0_block_0_terminator_kind: ReturnLocalI32\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_0_block_0_terminator_local: param_value\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_0_metadata_count: 0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_0_expected_exit: 0\n",
                ctx
            );
        } else {
            canonical = mir_native_scalar_source_append(
                canonical,
                "module: phase10_runtime_boundary\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "import_count: 1\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "import_0_name: abs\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "import_0_link_symbol: abs\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "import_0_linkage: imported_host\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "import_0_parameter_count: 1\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "import_0_parameter_0_type: int\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "import_0_return_type: int\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "function_count: 1\n",
                ctx
            );
        }

        mut main_index := 0;
        if is_local_call == 1 {
            main_index = 1;
        }
        mut function_prefix := "function_0_";
        if main_index == 1 {
            function_prefix = "function_1_";
        }

        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "linkage: exported_entry\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "function: main\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "backend_symbol: main\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "parameter_count: 0\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "return_type: int\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "local_count: 1\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "local_0_name: call_result\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "local_0_type: int\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "entry_block: entry\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "block_count: 1\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "block_0_label: entry\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "block_0_parameter_count: 0\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "block_0_statement_count: 1\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "block_0_statement_0_kind: LocalI32SetCall\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "block_0_statement_0_local: call_result\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        if is_local_call == 1 {
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_statement_0_callee_kind: LocalFunction\n",
                ctx
            );
        } else {
            canonical = mir_native_scalar_source_append(
                canonical,
                "block_0_statement_0_callee_kind: ImportedFunction\n",
                ctx
            );
        }
        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "block_0_statement_0_callee: ",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            call_name,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "block_0_statement_0_argument_count: 1\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "block_0_statement_0_argument_0_kind: I32Literal\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "block_0_statement_0_argument_0_value: ",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            std.FormatInt(call_value),
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "block_0_terminator_kind: ReturnLocalI32\n",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "block_0_terminator_local: call_result\n",
            ctx
        );

        if is_runtime_boundary == 1 {
            canonical = mir_native_scalar_source_append(
                canonical,
                function_prefix,
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "metadata_count: 1\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                function_prefix,
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "metadata_0_kind: native_boundary\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                function_prefix,
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "metadata_0_attachment: statement:entry:0\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                function_prefix,
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "metadata_0_policy: ignored_with_proof\n",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                function_prefix,
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "metadata_0_payload: kind=RuntimeCall;symbol=abs;origin=",
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                source_path,
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "\n",
                ctx
            );
        } else {
            canonical = mir_native_scalar_source_append(
                canonical,
                function_prefix,
                ctx
            );
            canonical = mir_native_scalar_source_append(
                canonical,
                "metadata_count: 0\n",
                ctx
            );
        }

        canonical = mir_native_scalar_source_append(
            canonical,
            function_prefix,
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "expected_exit: ",
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            std.FormatInt(call_value),
            ctx
        );
        canonical = mir_native_scalar_source_append(
            canonical,
            "\n",
            ctx
        );

        mut module_name := "phase10_local_call";
        mut object_name := "phase10_local_call_module.o";
        mut native_boundary_count := 0;
        if is_runtime_boundary == 1 {
            module_name = "phase10_runtime_boundary";
            object_name = "phase10_runtime_boundary_module.o";
            native_boundary_count = 1;
        }

        mut bundle := mir.mir_make_program_bundle("main", ctx);
        mut bundle_module := mir.mir_make_program_bundle_module(
            source_path,
            "",
            object_name,
            "gust.compiler_mir_ingestion.v2",
            canonical,
            0,
            0,
            native_boundary_count,
            ctx
        );

        if is_local_call == 1 {
            bundle_module = mir.mir_program_bundle_module_with_symbol(
                bundle_module,
                mir.mir_make_program_bundle_symbol(
                    "phase10_local_identity",
                    "phase10_local_identity",
                    "(int)->int",
                    1,
                    ctx
                ),
                ctx
            );
        } else {
            bundle_module = mir.mir_program_bundle_module_with_symbol(
                bundle_module,
                mir.mir_make_program_bundle_symbol(
                    "abs",
                    "abs",
                    "(int)->int",
                    2,
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
        bundle = mir.mir_program_bundle_with_module(
            bundle,
            bundle_module,
            ctx
        );

        mut plan := capability.mir_native_backend_make_capability_plan(ctx);
        mut ordinal := 0;
        plan = mir_native_scalar_source_add_requirement(
            plan,
            0,
            source_path,
            ordinal,
            "LocalI32Set",
            ctx
        );
        ordinal = ordinal + 1;
        plan = mir_native_scalar_source_add_requirement(
            plan,
            0,
            source_path,
            ordinal,
            "LocalI32Read",
            ctx
        );
        ordinal = ordinal + 1;
        if is_local_call == 1 {
            plan = mir_native_scalar_source_add_requirement(
                plan,
                0,
                source_path,
                ordinal,
                "LocalCallI32",
                ctx
            );
        } else {
            plan = mir_native_scalar_source_add_requirement(
                plan,
                0,
                source_path,
                ordinal,
                "ImportedCallI32",
                ctx
            );
        }
        ordinal = ordinal + 1;
        plan = mir_native_scalar_source_add_requirement(
            plan,
            0,
            source_path,
            ordinal,
            "ReturnI32",
            ctx
        );
        ordinal = ordinal + 1;
        plan = mir_native_scalar_source_add_requirement(
            plan,
            1,
            source_path,
            ordinal,
            "int",
            ctx
        );
        ordinal = ordinal + 1;
        plan = mir_native_scalar_source_add_requirement(
            plan,
            1,
            source_path,
            ordinal,
            "()->int",
            ctx
        );
        ordinal = ordinal + 1;
        plan = mir_native_scalar_source_add_requirement(
            plan,
            1,
            source_path,
            ordinal,
            "(int)->int",
            ctx
        );
        ordinal = ordinal + 1;
        if is_runtime_boundary == 1 {
            plan = mir_native_scalar_source_add_requirement(
                plan,
                2,
                source_path,
                ordinal,
                "abs",
                ctx
            );
            ordinal = ordinal + 1;
        }
        plan = mir_native_scalar_source_add_requirement(
            plan,
            3,
            source_path,
            ordinal,
            "native_host",
            ctx
        );
        ordinal = ordinal + 1;
        plan = mir_native_scalar_source_add_requirement(
            plan,
            3,
            source_path,
            ordinal,
            "position_independent_code",
            ctx
        );
        ordinal = ordinal + 1;
        plan = mir_native_scalar_source_add_requirement(
            plan,
            3,
            source_path,
            ordinal,
            "native_executable_link",
            ctx
        );

        lowering.supported = 1;
        lowering.bundle = bundle;
        lowering.plan = plan;
        return lowering;
    }
}

func mir_native_scalar_source_process(driver_path: str, command_name: str, request_path: str, include_request: int, ctx: &Arena) os.ProcessResult[ctx] {
    mut arguments: std.Vector[str, ctx] := std.VectorNew(ctx);
    arguments.Push(std.Clone(ctx, driver_path));
    arguments.Push(std.Clone(ctx, command_name));
    if include_request == 1 {
        arguments.Push(std.Clone(ctx, request_path));
    }
    return os.RunProcess(ctx, arguments);
}

func mir_native_scalar_source_compile(programs: std.Vector[ast.Program[ctx], ctx], module_paths: std.Vector[str, ctx], module_prefixes: std.Vector[str, ctx], output_path: str, ctx: &Arena) MirNativeScalarSourceRouteResult[ctx] {
    mut static_capabilities := mir_native_scalar_source_capabilities(ctx);
    mut generic_result := generic_source.mir_native_generic_source_lower(
        programs,
        module_paths,
        module_prefixes,
        static_capabilities,
        ctx
    );

    if generic_result.eligibility.tag == 3 {
        return mir_native_scalar_source_route_result(
            1,
            generic_result.diagnostic,
            ctx
        );
    }
    if generic_result.eligibility.tag == 2 {
        return mir_native_scalar_source_route_result(
            1,
            generic_result.diagnostic,
            ctx
        );
    }

    // The closed recognizers remain behind the generic attempt as a temporary
    // compatibility route and as byte-for-byte shadow evidence.
    mut lowering := mir_native_call_import_source_lower(
        programs,
        module_paths,
        module_prefixes,
        ctx
    );
    if lowering.supported == 0 {
        lowering = mir_native_cfg_source_lower(
            programs,
            module_paths,
            module_prefixes,
            ctx
        );
    }
    if lowering.supported == 0 {
        lowering = mir_native_scalar_source_lower(
            programs,
            module_paths,
            module_prefixes,
            ctx
        );
    }

    if generic_result.eligibility.tag == 0 {
        mut generic_serialized := mir.mir_serialize_program_bundle(
            generic_result.bundle,
            ctx
        );
        if std.str_eq(generic_serialized, "format: invalid\n") == 1 {
            return mir_native_scalar_source_route_result(
                1,
                "Native backend internal error: generic canonical MIR bundle validation failed",
                ctx
            );
        }

        if lowering.supported == 1 {
            mut legacy_serialized := mir.mir_serialize_program_bundle(
                lowering.bundle,
                ctx
            );
            if std.str_eq(legacy_serialized, "format: invalid\n") == 1 ||
               std.str_eq(generic_serialized, legacy_serialized) == 0
            {
                return mir_native_scalar_source_route_result(
                    1,
                    "Native backend internal error: generic and compatibility canonical MIR bundles differ",
                    ctx
                );
            }
        }

        lowering.supported = 1;
        lowering.bundle = generic_result.bundle;
        lowering.plan = generic_result.plan;
    }

    if lowering.supported == 0 {
        return mir_native_scalar_source_route_result(2, "", ctx);
    }

    mut static_result := capability.mir_native_backend_validate_capabilities(
        lowering.bundle,
        lowering.plan,
        static_capabilities,
        ctx
    );
    if static_result.classification.tag != 0 {
        return mir_native_scalar_source_route_result(
            1,
            capability.mir_native_backend_capability_diagnostic(
                static_result,
                ctx
            ),
            ctx
        );
    }

    mut explicit_driver := os.GetEnv(
        ctx,
        "GUST_NATIVE_BACKEND_DRIVER"
    );
    mut executable_path := os.ExecutablePath(ctx);
    mut executable_dir := os.PathDir(ctx, executable_path);
    mut sibling_driver := os.path_join(
        executable_dir,
        "gust-native-backend",
        ctx
    );

    mut discovery := driver.mir_native_backend_discover_driver(
        explicit_driver,
        os.FileExists(explicit_driver),
        os.FileExecutable(explicit_driver),
        sibling_driver,
        os.FileExists(sibling_driver),
        os.FileExecutable(sibling_driver),
        ctx
    );
    if discovery.classification.tag != 0 &&
        discovery.classification.tag != 1
    {
        mut diagnostic := std.Concat(
            "Native backend driver discovery error: ",
            discovery.detail
        );
        return mir_native_scalar_source_route_result(
            1,
            diagnostic,
            ctx
        );
    }

    mut handshake_process := mir_native_scalar_source_process(
        discovery.path,
        "phase10-driver-handshake",
        "",
        0,
        ctx
    );
    if handshake_process.status != 0 {
        mut diagnostic := handshake_process.stderr_text;
        if len(diagnostic) == 0 {
            diagnostic =
                "Native backend driver handshake process failed without diagnostics";
        }
        return mir_native_scalar_source_route_result(1, diagnostic, ctx);
    }

    mut handshake := driver.mir_native_backend_parse_driver_handshake(
        handshake_process.stdout_text,
        ctx
    );
    mut expected_target := os.NativeTargetTriple(ctx);
    mut expected_object_format := os.NativeObjectFormat(ctx);
    mut handshake_result :=
        driver.mir_native_backend_validate_driver_handshake(
            handshake,
            expected_target,
            expected_object_format,
            ctx
        );
    if handshake_result.classification.tag != 0 {
        return mir_native_scalar_source_route_result(
            1,
            driver.mir_native_backend_driver_handshake_diagnostic(
                handshake_result,
                ctx
            ),
            ctx
        );
    }

    mut advertised_capabilities :=
        driver.mir_native_backend_driver_capability_set(
            handshake,
            ctx
        );
    mut advertised_result :=
        capability.mir_native_backend_validate_capabilities(
            lowering.bundle,
            lowering.plan,
            advertised_capabilities,
            ctx
        );
    if advertised_result.classification.tag != 0 {
        return mir_native_scalar_source_route_result(
            1,
            capability.mir_native_backend_capability_diagnostic(
                advertised_result,
                ctx
            ),
            ctx
        );
    }

    mut absolute_output := os.PathAbsolute(ctx, output_path);
    if len(absolute_output) == 0 {
        return mir_native_scalar_source_route_result(
            1,
            "Native backend output error: could not resolve the executable path",
            ctx
        );
    }

    mut bundle_path := std.Clone(
        ctx,
        std.Concat(absolute_output, ".phase10.bundle")
    );
    mut request_path := std.Clone(
        ctx,
        std.Concat(absolute_output, ".phase10.request")
    );

    mut serialized_bundle := mir.mir_serialize_program_bundle(
        lowering.bundle,
        ctx
    );
    if std.str_eq(serialized_bundle, "format: invalid\n") == 1 {
        return mir_native_scalar_source_route_result(
            1,
            "Native backend internal error: canonical program MIR bundle validation failed",
            ctx
        );
    }

    mut backend_request := request.mir_native_backend_make_request(
        expected_target,
        expected_object_format,
        absolute_output,
        bundle_path,
        lowering.bundle,
        ctx
    );
    mut serialized_request :=
        request.mir_serialize_native_backend_request(
            backend_request,
            ctx
        );
    if std.str_eq(serialized_request, "format: invalid\n") == 1 {
        return mir_native_scalar_source_route_result(
            1,
            "Native backend internal error: generic backend request validation failed",
            ctx
        );
    }

    os.RemoveFile(bundle_path);
    os.RemoveFile(request_path);

    if os.WriteFile(bundle_path, serialized_bundle) == 0 {
        os.RemoveFile(bundle_path);
        return mir_native_scalar_source_route_result(
            1,
            "Native backend output error: could not write the canonical program MIR bundle",
            ctx
        );
    }
    if os.WriteFile(request_path, serialized_request) == 0 {
        os.RemoveFile(request_path);
        os.RemoveFile(bundle_path);
        return mir_native_scalar_source_route_result(
            1,
            "Native backend output error: could not write the generic backend request",
            ctx
        );
    }

    mut compile_process := mir_native_scalar_source_process(
        discovery.path,
        "phase10-backend-request-compile",
        request_path,
        1,
        ctx
    );

    os.RemoveFile(request_path);
    os.RemoveFile(bundle_path);

    if compile_process.status != 0 {
        mut diagnostic := compile_process.stderr_text;
        if len(diagnostic) == 0 {
            diagnostic =
                "Native backend compilation failed without diagnostics";
        }
        return mir_native_scalar_source_route_result(
            1,
            diagnostic,
            ctx
        );
    }

    return mir_native_scalar_source_route_result(0, "", ctx);
}
