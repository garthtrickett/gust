import "typechecker.gst" as typechecker;
import "ast.gst" as ast;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_int_51g := typechecker.make_type_int();

    mut safe_origin_51g: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_safe_arena(&safe_origin_51g);
    if typechecker.step51g_address_origin_is_safe_arena_only(safe_origin_51g) != 1 {
        os.LogStr("Error: safe arena origin was not classified as trusted safe arena");
        os.Exit(1);
    }
    if typechecker.step51g_address_origin_blocks_safe_brand(safe_origin_51g) != 0 {
        os.LogStr("Error: safe arena origin unexpectedly blocked safe branding");
        os.Exit(1);
    }

    mut raw_origin_51g: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_raw_derived(&raw_origin_51g);
    if typechecker.step51g_address_origin_blocks_safe_brand(raw_origin_51g) != 1 {
        os.LogStr("Error: raw-derived origin did not block safe branding");
        os.Exit(1);
    }

    mut sandbox_origin_51g: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_sandbox_derived(&sandbox_origin_51g);
    if typechecker.step51g_address_origin_blocks_safe_brand(sandbox_origin_51g) != 1 {
        os.LogStr("Error: sandbox-derived origin did not block safe branding");
        os.Exit(1);
    }

    mut unknown_origin_51g: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_unknown(&unknown_origin_51g);
    if typechecker.step51g_address_origin_blocks_safe_brand(unknown_origin_51g) != 1 {
        os.LogStr("Error: unknown origin did not block safe branding");
        os.Exit(1);
    }

    mut joined_safe_safe_51g := typechecker.step51g_join_address_origin(safe_origin_51g, safe_origin_51g);
    if typechecker.step51g_address_origin_is_safe_arena_only(joined_safe_safe_51g) != 1 {
        os.LogStr("Error: safe+safe origin join did not remain safe arena only");
        os.Exit(1);
    }

    mut joined_safe_raw_51g := typechecker.step51g_join_address_origin(safe_origin_51g, raw_origin_51g);
    if typechecker.step51g_address_origin_blocks_safe_brand(joined_safe_raw_51g) != 1 {
        os.LogStr("Error: safe+raw origin join did not block safe branding");
        os.Exit(1);
    }
    if joined_safe_raw_51g.is_raw_derived != 1 {
        os.LogStr("Error: safe+raw origin join did not preserve raw-derived metadata");
        os.Exit(1);
    }

    mut joined_raw_sandbox_51g := typechecker.step51g_join_address_origin(raw_origin_51g, sandbox_origin_51g);
    if joined_raw_sandbox_51g.is_raw_derived != 1 {
        os.LogStr("Error: raw+sandbox origin join lost raw-derived metadata");
        os.Exit(1);
    }
    if joined_raw_sandbox_51g.is_sandbox_derived != 1 {
        os.LogStr("Error: raw+sandbox origin join lost sandbox-derived metadata");
        os.Exit(1);
    }

    mut safe_prov_51g: typechecker.ExpressionProvenance[ctx];
    safe_prov_51g.resolved_type = t_int_51g;
    safe_prov_51g.address_origin = safe_origin_51g;
    safe_prov_51g.legacy_origins = typechecker.set_init(ctx);
    if typechecker.step51g_expression_provenance_allows_safe_brand(safe_prov_51g, ctx) != 1 {
        os.LogStr("Error: safe provenance did not allow safe branding");
        os.Exit(1);
    }

    mut raw_prov_51g: typechecker.ExpressionProvenance[ctx];
    raw_prov_51g.resolved_type = t_int_51g;
    raw_prov_51g.address_origin = raw_origin_51g;
    raw_prov_51g.legacy_origins = typechecker.set_init(ctx);
    if typechecker.step51g_expression_provenance_blocks_safe_brand(raw_prov_51g, ctx) != 1 {
        os.LogStr("Error: raw provenance did not block safe branding");
        os.Exit(1);
    }

    mut arena_ref_param_type_51g := typechecker.make_type_reference(typechecker.make_type_arena(), "ctx", ctx);
    if typechecker.env_type_is_safe_parameter_origin(arena_ref_param_type_51g, ctx) != 1 {
        os.LogStr("Error: ctx: &Arena parameter was not classified as a safe parameter origin");
        os.Exit(1);
    }

    mut arena_ptr_param_type_51g := typechecker.make_type_pointer(typechecker.make_type_arena(), ctx);
    if typechecker.env_type_is_safe_parameter_origin(arena_ptr_param_type_51g, ctx) != 1 {
        os.LogStr("Error: raw-pointer Arena compatibility parameter was not classified as a safe parameter origin");
        os.Exit(1);
    }

    mut branded_ref_param_type_51g := typechecker.make_type_reference(t_int_51g, "ctx", ctx);
    if typechecker.env_type_is_safe_parameter_origin(branded_ref_param_type_51g, ctx) != 1 {
        os.LogStr("Error: branded reference parameter was not classified as a safe parameter origin");
        os.Exit(1);
    }

    mut branded_index_param_type_51g := typechecker.make_type_index("int", "ctx", ctx);
    if typechecker.env_type_is_safe_parameter_origin(branded_index_param_type_51g, ctx) != 1 {
        os.LogStr("Error: branded index parameter was not classified as a safe parameter origin");
        os.Exit(1);
    }

    mut internal_origin_set_index_51g := typechecker.make_type_index("typechecker__OriginSet_ctx", "ctx", ctx);
    if typechecker.step51g_non_laundering_type_is_safe_brand_target(internal_origin_set_index_51g, ctx) != 0 {
        os.LogStr("Error: internal OriginSet metadata index should not be a non-laundering enforcement target");
        os.Exit(1);
    }

    mut internal_string_index_51g := typechecker.make_type_index("str", "ctx", ctx);
    if typechecker.step51g_non_laundering_type_is_safe_brand_target(internal_string_index_51g, ctx) != 0 {
        os.LogStr("Error: internal string metadata index should not be a non-laundering enforcement target");
        os.Exit(1);
    }

    mut internal_ast_expression_index_51g := typechecker.make_type_index("ast__Expression_ctx", "ctx", ctx);
    if typechecker.step51g_non_laundering_type_is_safe_brand_target(internal_ast_expression_index_51g, ctx) != 0 {
        os.LogStr("Error: internal AST expression index should not be a non-laundering enforcement target");
        os.Exit(1);
    }

    mut internal_compiler_error_index_51g := typechecker.make_type_index("errors__CompilerError_ctx", "ctx", ctx);
    if typechecker.step51g_non_laundering_type_is_safe_brand_target(internal_compiler_error_index_51g, ctx) != 0 {
        os.LogStr("Error: internal compiler error index should not be a non-laundering enforcement target");
        os.Exit(1);
    }

    mut internal_vector_string_index_51g := typechecker.make_type_index("std_Vector_str_ctx", "ctx", ctx);
    if typechecker.step51g_non_laundering_type_is_safe_brand_target(internal_vector_string_index_51g, ctx) != 0 {
        os.LogStr("Error: internal string vector index should not be a non-laundering enforcement target");
        os.Exit(1);
    }

    mut internal_vector_ast_statement_ref_51g := typechecker.make_type_reference(typechecker.make_type_struct("std_Vector_ast__Statement_ctx_ctx", "ctx", ctx), "ctx", ctx);
    if typechecker.step51g_non_laundering_type_is_safe_brand_target(internal_vector_ast_statement_ref_51g, ctx) != 0 {
        os.LogStr("Error: internal AST statement vector reference should not be a non-laundering enforcement target");
        os.Exit(1);
    }

    mut internal_graph_node_ref_51g := typechecker.make_type_reference(typechecker.make_type_struct("std_GraphNode_str_ctx", "ctx", ctx), "ctx", ctx);
    if typechecker.step51g_non_laundering_type_is_safe_brand_target(internal_graph_node_ref_51g, ctx) != 0 {
        os.LogStr("Error: internal GraphNode reference should not be a non-laundering enforcement target");
        os.Exit(1);
    }

    mut internal_test_task_arg_index_51g := typechecker.make_type_index("TestTaskArg_ctx", "ctx", ctx);
    if typechecker.step51g_non_laundering_type_is_safe_brand_target(internal_test_task_arg_index_51g, ctx) != 0 {
        os.LogStr("Error: internal test runner task argument index should not be a non-laundering enforcement target");
        os.Exit(1);
    }

    mut branded_task_arg_struct_51g := typechecker.make_type_struct("TaskArg_arena", "arena", ctx);
    mut branded_task_arg_ptr_51g := typechecker.make_type_pointer(branded_task_arg_struct_51g, ctx);
    if typechecker.env_type_is_safe_parameter_origin(branded_task_arg_ptr_51g, ctx) != 1 {
        os.LogStr("Error: raw pointer to branded struct parameter was not classified as a safe parameter origin");
        os.Exit(1);
    }

    mut internal_prefix_entry_ref_51g := typechecker.make_type_reference(typechecker.make_type_struct("typechecker__PrefixMapEntry_ctx", "ctx", ctx), "ctx", ctx);
    if typechecker.step51g_non_laundering_type_is_safe_brand_target(internal_prefix_entry_ref_51g, ctx) != 0 {
        os.LogStr("Error: internal PrefixMapEntry reference should not be a non-laundering enforcement target");
        os.Exit(1);
    }

    mut explicit_safe_cell_index_51g := typechecker.make_type_index("SafeCellUnknown", "ctx", ctx);
    if typechecker.step51g_non_laundering_type_is_safe_brand_target(explicit_safe_cell_index_51g, ctx) != 1 {
        os.LogStr("Error: ordinary safe-branded indexes must remain non-laundering enforcement targets");
        os.Exit(1);
    }

    mut branded_struct_param_type_51g := typechecker.make_type_struct("ast__MatchCase_ctx", "ctx", ctx);
    if typechecker.env_type_is_safe_parameter_origin(branded_struct_param_type_51g, ctx) != 1 {
        os.LogStr("Error: branded struct aggregate parameter was not classified as a safe parameter origin");
        os.Exit(1);
    }

    mut readback_origins_51g := typechecker.set_init(ctx);
    typechecker.set_add(readback_origins_51g, "safe_readback_base", ctx);
    mut safe_readback_prov_51g := typechecker.expression_provenance_inherit_readback(safe_prov_51g, branded_index_param_type_51g, readback_origins_51g, ctx);
    if typechecker.step51g_expression_provenance_allows_safe_brand(safe_readback_prov_51g, ctx) != 1 {
        os.LogStr("Error: safe aggregate readback did not preserve safe provenance");
        os.Exit(1);
    }
    if typechecker.set_contains(safe_readback_prov_51g.legacy_origins, "safe_readback_base", ctx) != 1 {
        os.LogStr("Error: safe aggregate readback did not merge legacy origins");
        os.Exit(1);
    }

    mut raw_readback_prov_51g := typechecker.expression_provenance_inherit_readback(raw_prov_51g, branded_index_param_type_51g, readback_origins_51g, ctx);
    if typechecker.step51g_expression_provenance_blocks_safe_brand(raw_readback_prov_51g, ctx) != 1 {
        os.LogStr("Error: raw aggregate readback did not preserve unsafe provenance");
        os.Exit(1);
    }

    mut null_value_prov_51g := typechecker.expression_provenance_null_value(branded_index_param_type_51g, ctx);
    if typechecker.step51g_expression_provenance_allows_safe_brand(null_value_prov_51g, ctx) != 1 {
        os.LogStr("Error: null sentinel provenance did not allow safe-branded assignment");
        os.Exit(1);
    }
    if typechecker.set_contains(null_value_prov_51g.legacy_origins, "null", ctx) != 1 {
        os.LogStr("Error: null sentinel provenance did not preserve null legacy origin marker");
        os.Exit(1);
    }

    mut literal_int_prov_51g := typechecker.expression_provenance_literal_value(t_int_51g, "literal.int", ctx);
    if typechecker.step51g_expression_provenance_allows_safe_brand(literal_int_prov_51g, ctx) != 1 {
        os.LogStr("Error: literal int provenance did not allow safe-branded Arena.Set");
        os.Exit(1);
    }
    if typechecker.set_contains(literal_int_prov_51g.legacy_origins, "literal.int", ctx) != 0 {
        os.LogStr("Error: literal int provenance should not pollute legacy escape origins");
        os.Exit(1);
    }

    mut empty_index_prov_51g := typechecker.expression_provenance_empty_value(branded_index_param_type_51g, ctx);
    if typechecker.step51g_expression_provenance_allows_safe_brand(empty_index_prov_51g, ctx) != 1 {
        os.LogStr("Error: empty[Index] sentinel provenance did not allow safe-branded binding");
        os.Exit(1);
    }

    mut clone_constructed_prov_51g := typechecker.expression_provenance_safe_arena(branded_index_param_type_51g, ctx);
    typechecker.set_add(clone_constructed_prov_51g.legacy_origins, "std.Clone", ctx);
    if typechecker.step51g_expression_provenance_allows_safe_brand(clone_constructed_prov_51g, ctx) != 1 {
        os.LogStr("Error: std.Clone constructed provenance did not allow safe-branded binding");
        os.Exit(1);
    }

    mut pool_alloc_constructed_prov_51g := typechecker.expression_provenance_safe_arena(branded_index_param_type_51g, ctx);
    typechecker.set_add(pool_alloc_constructed_prov_51g.legacy_origins, "Pool.Alloc", ctx);
    if typechecker.step51g_expression_provenance_allows_safe_brand(pool_alloc_constructed_prov_51g, ctx) != 1 {
        os.LogStr("Error: Pool.Alloc constructed provenance did not allow safe-branded binding");
        os.Exit(1);
    }

    mut unsafe_ref_binding_env_51g := typechecker.env_new(ctx);
    unsafe_ref_binding_env_51g.in_unsafe_block = 1;
    mut branded_ref_int_51g := typechecker.make_type_reference(t_int_51g, "ctx", ctx);
    if typechecker.step51g_non_laundering_unsafe_block_allows_local_reference_binding(&unsafe_ref_binding_env_51g, branded_ref_int_51g, "Binding raw-derived or sandbox-derived value") != 1 {
        os.LogStr("Error: unsafe-block local reference binding escape hatch did not allow explicit unsafe address binding");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_unsafe_block_allows_local_reference_binding(&unsafe_ref_binding_env_51g, branded_index_param_type_51g, "Binding raw-derived or sandbox-derived value") != 0 {
        os.LogStr("Error: unsafe-block local reference binding escape hatch incorrectly allowed Index laundering");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_unsafe_block_allows_local_reference_binding(&unsafe_ref_binding_env_51g, branded_ref_int_51g, "Assigning raw-derived or sandbox-derived value") != 0 {
        os.LogStr("Error: unsafe-block local reference binding escape hatch incorrectly allowed non-binding contexts");
        os.Exit(1);
    }
    unsafe_ref_binding_env_51g.in_unsafe_block = 0;
    if typechecker.step51g_non_laundering_unsafe_block_allows_local_reference_binding(&unsafe_ref_binding_env_51g, branded_ref_int_51g, "Binding raw-derived or sandbox-derived value") != 0 {
        os.LogStr("Error: unsafe-block local reference binding escape hatch incorrectly allowed safe-context reference binding");
        os.Exit(1);
    }

    mut sig_return_seed_51g: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&sig_return_seed_51g);
    sig_return_seed_51g.return_type = branded_index_param_type_51g;
    sig_return_seed_51g.is_extern = 0;
    mut seeded_return_prov_51g := typechecker.expression_provenance_for_function_signature_return(sig_return_seed_51g, ctx);
    if typechecker.step51g_expression_provenance_allows_safe_brand(seeded_return_prov_51g, ctx) != 1 {
        os.LogStr("Error: safe-branded non-extern function return seed was not classified as safe provenance");
        os.Exit(1);
    }

    sig_return_seed_51g.is_extern = 1;
    mut extern_seeded_return_prov_51g := typechecker.expression_provenance_for_function_signature_return(sig_return_seed_51g, ctx);
    if typechecker.step51g_expression_provenance_blocks_safe_brand(extern_seeded_return_prov_51g, ctx) != 1 {
        os.LogStr("Error: extern safe-branded function return seed did not remain unknown before FFI boundary modeling");
        os.Exit(1);
    }

    if typechecker.env_type_is_safe_parameter_origin(t_int_51g, ctx) != 0 {
        os.LogStr("Error: plain int parameter was incorrectly classified as a safe branded parameter origin");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: Step 5.1G provenance-origin spine helpers verified!");
}
