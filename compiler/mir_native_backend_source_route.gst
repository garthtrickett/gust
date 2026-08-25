import "ast.gst" as ast;
import "mir.gst" as mir;
import "mir_native_backend_capability.gst" as capability;
import "mir_native_backend_driver.gst" as driver;
import "mir_native_backend_generic_source.gst" as generic_source;
import "mir_native_backend_request.gst" as request;

// Compiler-owned native source route.
//
// Patch 11 retires the Phase 10 exact-shape compatibility implementation.
// Every supported source program is lowered by the registry-owned generic
// canonical-MIR pipeline before capability validation or driver discovery.
// Phase 13 maps every generic route attempt to one compiler-owned supported,
// deferred, or source/type-failure decision before any driver or artifact access.
type MirNativeDiagnosticClass enum {
    SourceTypeError,
    CanonicalMirVerificationError,
    UnsupportedNativeCapability,
    DriverHandshakeError,
    WorkerLoweringError,
    ObjectLinkPublicationError
}

type MirNativeDiagnosticLocation[ctx] struct {
    source_path: str,
    line: int,
    column: int
}

type MirNativeScalarSourceRouteResult[ctx] struct {
    status: int,
    diagnostic: str,
    source_path: str,
    line: int,
    column: int,
    decision: capability.MirNativeBackendRouteDecision[ctx]
}

func mir_native_scalar_source_route_result(status: int, diagnostic: str, ctx: &Arena) MirNativeScalarSourceRouteResult[ctx] {
    mut result: MirNativeScalarSourceRouteResult[ctx];
    result.status = status;
    result.diagnostic = std.Clone(ctx, diagnostic);
    result.source_path = std.Clone(ctx, "");
    result.line = 1;
    result.column = 1;
    // Direct route results occur only after static capability planning has
    // selected the supported lane. Deferred and source/type failures use the
    // dedicated constructors below.
    result.decision =
        capability.mir_native_backend_supported_route_decision(ctx);
    return result;
}

func mir_native_scalar_source_deferred_result(reason_code: str, diagnostic: str, ctx: &Arena) MirNativeScalarSourceRouteResult[ctx] {
    mut result := mir_native_scalar_source_route_result(2, diagnostic, ctx);
    result.decision =
        capability.mir_native_backend_deferred_route_decision(
            reason_code,
            ctx
        );
    return result;
}

func mir_native_scalar_source_failure_result(reason_code: str, diagnostic: str, ctx: &Arena) MirNativeScalarSourceRouteResult[ctx] {
    mut result := mir_native_scalar_source_route_result(1, diagnostic, ctx);
    result.decision =
        capability.mir_native_backend_source_or_type_failure_route_decision(
            reason_code,
            ctx
        );
    return result;
}

func mir_native_scalar_source_contains(value: str, needle: str) int {
    if std.str_find(value, needle) == 0 - 1 {
        return 0;
    }
    return 1;
}

func mir_native_scalar_source_diagnostic_class(result: MirNativeScalarSourceRouteResult[ctx]) MirNativeDiagnosticClass {
    mut classification: MirNativeDiagnosticClass;
    unsafe {
        classification.tag = 4;
    }

    if result.status == 2 {
        unsafe {
            classification.tag = 2;
        }
        return classification;
    }
    if mir_native_scalar_source_contains(
        result.diagnostic,
        "class=canonical_mir_verification_error"
    ) == 1 {
        unsafe {
            classification.tag = 1;
        }
        return classification;
    }
    if mir_native_scalar_source_contains(
        result.diagnostic,
        "class=unsupported_native_capability"
    ) == 1 {
        unsafe {
            classification.tag = 2;
        }
        return classification;
    }
    if mir_native_scalar_source_contains(
        result.diagnostic,
        "class=driver_handshake_error"
    ) == 1 {
        unsafe {
            classification.tag = 3;
        }
        return classification;
    }
    if mir_native_scalar_source_contains(
        result.diagnostic,
        "class=worker_lowering_error"
    ) == 1 {
        unsafe {
            classification.tag = 4;
        }
        return classification;
    }
    if mir_native_scalar_source_contains(
        result.diagnostic,
        "class=object_link_publication_error"
    ) == 1 {
        unsafe {
            classification.tag = 5;
        }
        return classification;
    }

    if mir_native_scalar_source_contains(
        result.diagnostic,
        "Native backend capability error"
    ) == 1 {
        unsafe {
            classification.tag = 2;
        }
        return classification;
    }
    if mir_native_scalar_source_contains(
        result.diagnostic,
        "driver discovery"
    ) == 1 ||
       mir_native_scalar_source_contains(
           result.diagnostic,
           "handshake"
       ) == 1
    {
        unsafe {
            classification.tag = 3;
        }
        return classification;
    }
    if mir_native_scalar_source_contains(
        result.diagnostic,
        "output error"
    ) == 1 ||
       mir_native_scalar_source_contains(
           result.diagnostic,
           "object_link_publication"
       ) == 1
    {
        unsafe {
            classification.tag = 5;
        }
        return classification;
    }
    if mir_native_scalar_source_contains(
        result.diagnostic,
        "canonical"
    ) == 1 ||
       mir_native_scalar_source_contains(
           result.diagnostic,
           "Native backend internal error"
       ) == 1 ||
       mir_native_scalar_source_contains(
           result.diagnostic,
           "Native backend direct-call"
       ) == 1 ||
       mir_native_scalar_source_contains(
           result.diagnostic,
           "Native backend module/import"
       ) == 1
    {
        unsafe {
            classification.tag = 1;
        }
        return classification;
    }
    return classification;
}

func mir_native_scalar_source_diagnostic_class_name(classification: MirNativeDiagnosticClass) str {
    if classification.tag == 0 {
        return "source_type_error";
    }
    if classification.tag == 1 {
        return "canonical_mir_verification_error";
    }
    if classification.tag == 2 {
        return "unsupported_native_capability";
    }
    if classification.tag == 3 {
        return "driver_handshake_error";
    }
    if classification.tag == 4 {
        return "worker_lowering_error";
    }
    if classification.tag == 5 {
        return "object_link_publication_error";
    }
    return "worker_lowering_error";
}

func mir_native_scalar_source_capability_decision_line(result: MirNativeScalarSourceRouteResult[ctx], ctx: &Arena) str {
    return capability.mir_native_backend_route_decision_line(
        result.decision,
        ctx
    );
}

func mir_native_scalar_source_diagnostic_line(result: MirNativeScalarSourceRouteResult[ctx], ctx: &Arena) str {
    mut classification :=
        mir_native_scalar_source_diagnostic_class(result);
    mut source_path := result.source_path;
    if len(source_path) == 0 {
        source_path = "<source>";
    }
    return std.Clone(
        ctx,
        std.Format(
            "gust_backend_parity_diagnostic: taxonomy=gust.backend_parity.diagnostic.v1 class=%s source=%s line=%d column=%d",
            mir_native_scalar_source_diagnostic_class_name(classification),
            source_path,
            result.line,
            result.column
        )
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
        "SubI32",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_operation(
        capabilities,
        "MulI32",
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
    capabilities = capability.mir_native_backend_capability_set_with_operation(
        capabilities,
        "ImportedCallVoid",
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
        "str",
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
        "(int,int)->int",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_type_or_abi(
        capabilities,
        "direct_scalar_abi",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_runtime_import(
        capabilities,
        "tiny_host_add_one_i32",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_runtime_import(
        capabilities,
        "tiny_host_add_i32",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_runtime_import(
        capabilities,
        "tiny_host_is_positive_i32",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_runtime_import(
        capabilities,
        "abs",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_runtime_import(
        capabilities,
        "toupper",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_runtime_import(
        capabilities,
        "os_LogInt",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_runtime_import(
        capabilities,
        "os_LogStr",
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

func mir_native_scalar_source_process(driver_path: str, command_name: str, request_path: str, include_request: int, ctx: &Arena) os.ProcessResult[ctx] {
    mut arguments: std.Vector[str, ctx] := std.VectorNew(ctx);
    arguments.Push(std.Clone(ctx, driver_path));
    arguments.Push(std.Clone(ctx, command_name));
    if include_request == 1 {
        arguments.Push(std.Clone(ctx, request_path));
    }
    return os.RunProcess(ctx, arguments);
}

func mir_native_scalar_source_requires_retained_runtime_package(
    plan: capability.MirNativeBackendCapabilityPlan[ctx],
    ctx: &Arena
) int {
    mut requirements: std.Vector[capability.MirNativeBackendRequirement[ctx], ctx] :=
        ctx[plan.requirements];
    mut index := 0;
    while index < len(requirements) {
        mut requirement := requirements[index];
        if requirement.kind.tag == 2 &&
           (std.str_eq(requirement.feature, "os_LogInt") == 1 ||
            std.str_eq(requirement.feature, "os_LogStr") == 1)
        {
            return 1;
        }
        index = index + 1;
    }
    return 0;
}

func mir_native_scalar_source_compile_inner(programs: std.Vector[ast.Program[ctx], ctx], module_paths: std.Vector[str, ctx], module_prefixes: std.Vector[str, ctx], output_path: str, ctx: &Arena) MirNativeScalarSourceRouteResult[ctx] {
    mut static_capabilities := mir_native_scalar_source_capabilities(ctx);
    mut generic_result := generic_source.mir_native_generic_source_lower(
        programs,
        module_paths,
        module_prefixes,
        static_capabilities,
        ctx
    );

    if generic_result.eligibility.tag == 3 {
        return mir_native_scalar_source_failure_result(
            "source_or_type_failure",
            generic_result.diagnostic,
            ctx
        );
    }
    if generic_result.eligibility.tag == 2 {
        return mir_native_scalar_source_deferred_result(
            "native_capability_unsupported",
            generic_result.diagnostic,
            ctx
        );
    }

    if generic_result.eligibility.tag == 1 {
        mut reason_code := generic_result.reason_code;
        if len(reason_code) == 0 {
            reason_code = "source_feature_not_represented";
        }
        return mir_native_scalar_source_deferred_result(
            reason_code,
            generic_result.diagnostic,
            ctx
        );
    }

    mut serialized_generic_bundle := mir.mir_serialize_program_bundle(
        generic_result.bundle,
        ctx
    );
    if std.str_eq(serialized_generic_bundle, "format: invalid\n") == 1 {
        return mir_native_scalar_source_failure_result(
            "invalid_canonical_mir",
            "Native backend internal error: generic canonical MIR bundle validation failed",
            ctx
        );
    }

    mut static_result := capability.mir_native_backend_validate_capabilities(
        generic_result.bundle,
        generic_result.plan,
        static_capabilities,
        ctx
    );
    if static_result.classification.tag == 5 {
        return mir_native_scalar_source_failure_result(
            "invalid_compiler_mir",
            capability.mir_native_backend_capability_diagnostic(
                static_result,
                ctx
            ),
            ctx
        );
    }
    if static_result.classification.tag != 0 {
        return mir_native_scalar_source_deferred_result(
            "native_capability_unsupported",
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
            generic_result.bundle,
            generic_result.plan,
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

    mut serialized_bundle := std.Clone(ctx, serialized_generic_bundle);

    mut backend_request := request.mir_native_backend_make_request(
        expected_target,
        expected_object_format,
        absolute_output,
        bundle_path,
        generic_result.bundle,
        ctx
    );
    if mir_native_scalar_source_requires_retained_runtime_package(
        generic_result.plan,
        ctx
    ) == 1 {
        mut runtime_package_path := os.path_join(
            os.PathDir(ctx, discovery.path),
            "gust-runtime-package.a",
            ctx
        );
        backend_request = request.mir_native_backend_request_with_runtime_package(
            backend_request,
            runtime_package_path,
            ctx
        );
    }
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

func mir_native_scalar_source_entry_location(programs: std.Vector[ast.Program[ctx], ctx], module_paths: std.Vector[str, ctx], module_prefixes: std.Vector[str, ctx], ctx: &Arena) MirNativeDiagnosticLocation[ctx] {
    mut location: MirNativeDiagnosticLocation[ctx];
    location.source_path = std.Clone(ctx, "<source>");
    location.line = 1;
    location.column = 1;

    mut module_index := 0;
    while module_index < len(programs) &&
          module_index < len(module_paths) &&
          module_index < len(module_prefixes)
    {
        if std.str_eq(module_prefixes[module_index], "") == 1 {
            location.source_path = std.Clone(
                ctx,
                module_paths[module_index]
            );
            mut statements: std.Vector[ast.Statement[ctx], ctx] :=
                ctx[programs[module_index].statements];
            mut statement_index := 0;
            while statement_index < len(statements) {
                mut statement := statements[statement_index];
                unsafe {
                    if statement.tag == 3 &&
                       std.str_eq(
                           statement.FunctionDecl.name,
                           "main"
                       ) == 1
                    {
                        location.line =
                            statement.FunctionDecl.span.start.line;
                        location.column =
                            statement.FunctionDecl.span.start.column;
                        return location;
                    }
                }
                statement_index = statement_index + 1;
            }
            return location;
        }
        module_index = module_index + 1;
    }

    if len(module_paths) > 0 {
        location.source_path = std.Clone(ctx, module_paths[0]);
    }
    return location;
}

func mir_native_scalar_source_compile(programs: std.Vector[ast.Program[ctx], ctx], module_paths: std.Vector[str, ctx], module_prefixes: std.Vector[str, ctx], output_path: str, ctx: &Arena) MirNativeScalarSourceRouteResult[ctx] {
    mut result := mir_native_scalar_source_compile_inner(
        programs,
        module_paths,
        module_prefixes,
        output_path,
        ctx
    );
    mut location := mir_native_scalar_source_entry_location(
        programs,
        module_paths,
        module_prefixes,
        ctx
    );
    result.source_path = std.Clone(ctx, location.source_path);
    result.line = location.line;
    result.column = location.column;
    result.decision =
        capability.mir_native_backend_route_decision_with_location(
            result.decision,
            location.source_path,
            location.line,
            location.column,
            ctx
        );
    return result;
}
