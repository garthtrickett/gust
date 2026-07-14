import "ast.gst" as ast;
import "mir.gst" as mir;
import "mir_native_backend_capability.gst" as capability;
import "mir_native_backend_driver.gst" as driver;
import "mir_native_backend_request.gst" as request;

// Phase 10 scalar and metadata source route.
//
// This is the first production-connected native cohort. It is intentionally
// narrow: one source module, one zero-argument `main() int`, and either a
// literal return or one integer local initialized from a literal and returned.
// The local form carries compiler-owned provenance metadata. Calls, imports,
// CFG, block parameters, and broader scalar expressions remain deferred.
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
    capabilities = capability.mir_native_backend_capability_set_with_type_or_abi(
        capabilities,
        "int",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_type_or_abi(
        capabilities,
        "()->int",
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
    mut lowering := mir_native_scalar_source_lower(
        programs,
        module_paths,
        module_prefixes,
        ctx
    );
    if lowering.supported == 0 {
        return mir_native_scalar_source_route_result(2, "", ctx);
    }

    mut static_capabilities := mir_native_scalar_source_capabilities(ctx);
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