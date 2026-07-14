import "mir.gst" as mir;
import "mir_native_backend_capability.gst" as capability;

func fail(msg: str) {
    os.LogStr(msg);
    os.Exit(1);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut bundle := mir.mir_make_program_bundle("main", ctx);
    mut canonical_record := "format: gust.compiler_mir_ingestion.v2\nmodule: app\nimport_count: 2\nfunction_count: 1\n";
    mut module := mir.mir_make_program_bundle_module(
        "app.gst",
        "",
        "app.o",
        "gust.compiler_mir_ingestion.v2",
        canonical_record,
        0,
        0,
        0,
        ctx
    );

    mut entry_symbol := mir.mir_make_program_bundle_symbol(
        "main",
        "main",
        "()->int",
        0,
        ctx
    );
    module = mir.mir_program_bundle_module_with_symbol(module, entry_symbol, ctx);

    mut supported_import_symbol := mir.mir_make_program_bundle_symbol(
        "host_add",
        "tiny_host_add_i32",
        "(int,int)->int",
        2,
        ctx
    );
    module = mir.mir_program_bundle_module_with_symbol(
        module,
        supported_import_symbol,
        ctx
    );

    mut unsupported_import_symbol := mir.mir_make_program_bundle_symbol(
        "host_unknown",
        "tiny_host_unknown_i32",
        "(int)->int",
        2,
        ctx
    );
    module = mir.mir_program_bundle_module_with_symbol(
        module,
        unsupported_import_symbol,
        ctx
    );

    bundle = mir.mir_program_bundle_with_module(bundle, module, ctx);
    if mir.mir_program_bundle_is_valid(bundle, ctx) == 0 {
        fail("Capability smoke: canonical bundle should validate before capability checking");
    }

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
    capabilities = capability.mir_native_backend_capability_set_with_runtime_import(
        capabilities,
        "tiny_host_add_i32",
        ctx
    );
    capabilities = capability.mir_native_backend_capability_set_with_target_requirement(
        capabilities,
        "native_host",
        ctx
    );

    mut supported_plan := capability.mir_native_backend_make_capability_plan(ctx);
    supported_plan = capability.mir_native_backend_capability_plan_with_requirement(
        supported_plan,
        capability.mir_native_backend_make_requirement(
            0,
            "app.gst",
            "main",
            "entry",
            0,
            "ReturnI32",
            ctx
        ),
        ctx
    );
    supported_plan = capability.mir_native_backend_capability_plan_with_requirement(
        supported_plan,
        capability.mir_native_backend_make_requirement(
            1,
            "app.gst",
            "main",
            "",
            1,
            "()->int",
            ctx
        ),
        ctx
    );
    supported_plan = capability.mir_native_backend_capability_plan_with_requirement(
        supported_plan,
        capability.mir_native_backend_make_requirement(
            2,
            "app.gst",
            "main",
            "entry",
            2,
            "tiny_host_add_i32",
            ctx
        ),
        ctx
    );
    supported_plan = capability.mir_native_backend_capability_plan_with_requirement(
        supported_plan,
        capability.mir_native_backend_make_requirement(
            3,
            "app.gst",
            "main",
            "",
            3,
            "native_host",
            ctx
        ),
        ctx
    );

    mut supported_result := capability.mir_native_backend_validate_capabilities(
        bundle,
        supported_plan,
        capabilities,
        ctx
    );
    if supported_result.classification.tag != 0 {
        fail("Capability smoke: supported plan should validate");
    }
    if std.str_eq(
        capability.mir_native_backend_capability_diagnostic(supported_result, ctx),
        "Native backend capability validation: supported"
    ) == 0 {
        fail("Capability smoke: supported diagnostic drifted");
    }

    mut operation_plan := capability.mir_native_backend_make_capability_plan(ctx);
    operation_plan = capability.mir_native_backend_capability_plan_with_requirement(
        operation_plan,
        capability.mir_native_backend_make_requirement(
            0,
            "app.gst",
            "main",
            "entry",
            0,
            "ReturnI32",
            ctx
        ),
        ctx
    );
    operation_plan = capability.mir_native_backend_capability_plan_with_requirement(
        operation_plan,
        capability.mir_native_backend_make_requirement(
            0,
            "app.gst",
            "main",
            "entry",
            1,
            "StringLiteral",
            ctx
        ),
        ctx
    );
    operation_plan = capability.mir_native_backend_capability_plan_with_requirement(
        operation_plan,
        capability.mir_native_backend_make_requirement(
            1,
            "app.gst",
            "main",
            "",
            2,
            "str",
            ctx
        ),
        ctx
    );

    mut operation_result := capability.mir_native_backend_validate_capabilities(
        bundle,
        operation_plan,
        capabilities,
        ctx
    );
    if operation_result.classification.tag != 1 {
        fail("Capability smoke: unsupported operation classification drifted");
    }
    if operation_result.ordinal != 1 {
        fail("Capability smoke: first unsupported requirement must win");
    }
    if std.str_eq(operation_result.module_path, "app.gst") == 0 {
        fail("Capability smoke: unsupported operation module context drifted");
    }
    if std.str_eq(operation_result.function_name, "main") == 0 {
        fail("Capability smoke: unsupported operation function context drifted");
    }
    if std.str_eq(operation_result.block_label, "entry") == 0 {
        fail("Capability smoke: unsupported operation block context drifted");
    }
    if std.str_eq(operation_result.feature, "StringLiteral") == 0 {
        fail("Capability smoke: unsupported operation feature drifted");
    }
    if std.str_eq(
        capability.mir_native_backend_capability_diagnostic(operation_result, ctx),
        "Native backend capability error [unsupported_operation] module=app.gst function=main block=entry requirement=1 feature=StringLiteral: native backend does not support this canonical MIR operation"
    ) == 0 {
        fail("Capability smoke: unsupported operation diagnostic drifted");
    }

    mut type_plan := capability.mir_native_backend_make_capability_plan(ctx);
    type_plan = capability.mir_native_backend_capability_plan_with_requirement(
        type_plan,
        capability.mir_native_backend_make_requirement(
            1,
            "app.gst",
            "main",
            "",
            0,
            "str",
            ctx
        ),
        ctx
    );
    mut type_result := capability.mir_native_backend_validate_capabilities(
        bundle,
        type_plan,
        capabilities,
        ctx
    );
    if type_result.classification.tag != 2 {
        fail("Capability smoke: unsupported type/ABI classification drifted");
    }

    mut import_plan := capability.mir_native_backend_make_capability_plan(ctx);
    import_plan = capability.mir_native_backend_capability_plan_with_requirement(
        import_plan,
        capability.mir_native_backend_make_requirement(
            2,
            "app.gst",
            "main",
            "entry",
            0,
            "tiny_host_unknown_i32",
            ctx
        ),
        ctx
    );
    mut import_result := capability.mir_native_backend_validate_capabilities(
        bundle,
        import_plan,
        capabilities,
        ctx
    );
    if import_result.classification.tag != 3 {
        fail("Capability smoke: unsupported runtime import classification drifted");
    }

    mut target_plan := capability.mir_native_backend_make_capability_plan(ctx);
    target_plan = capability.mir_native_backend_capability_plan_with_requirement(
        target_plan,
        capability.mir_native_backend_make_requirement(
            3,
            "app.gst",
            "main",
            "",
            0,
            "wasm32",
            ctx
        ),
        ctx
    );
    mut target_result := capability.mir_native_backend_validate_capabilities(
        bundle,
        target_plan,
        capabilities,
        ctx
    );
    if target_result.classification.tag != 4 {
        fail("Capability smoke: unsupported target classification drifted");
    }

    mut invalid_bundle := mir.mir_make_program_bundle("main", ctx);
    mut invalid_bundle_result := capability.mir_native_backend_validate_capabilities(
        invalid_bundle,
        supported_plan,
        capabilities,
        ctx
    );
    if invalid_bundle_result.classification.tag != 5 {
        fail("Capability smoke: invalid compiler MIR classification drifted");
    }
    if std.str_eq(invalid_bundle_result.feature, "structural_validation") == 0 {
        fail("Capability smoke: invalid bundle feature context drifted");
    }

    mut missing_module_plan := capability.mir_native_backend_make_capability_plan(ctx);
    missing_module_plan = capability.mir_native_backend_capability_plan_with_requirement(
        missing_module_plan,
        capability.mir_native_backend_make_requirement(
            0,
            "missing.gst",
            "main",
            "entry",
            0,
            "ReturnI32",
            ctx
        ),
        ctx
    );
    mut missing_module_result := capability.mir_native_backend_validate_capabilities(
        bundle,
        missing_module_plan,
        capabilities,
        ctx
    );
    if missing_module_result.classification.tag != 5 {
        fail("Capability smoke: absent requirement module must be an internal MIR failure");
    }

    os.LogStr("SUCCESS: MIR native backend capability validation smoke");
}