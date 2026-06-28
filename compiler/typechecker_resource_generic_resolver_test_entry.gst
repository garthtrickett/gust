import "ast.gst" as ast;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_resource_generic_resolution := typechecker.env_new(ctx);
    env_resource_generic_resolution.current_prefix = "main__";

    typechecker.env_register_struct_linear_metadata(&env_resource_generic_resolution, "main__ResolverPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_resource_generic_resolution, "main__ResolverPayload", "close_resolver_payload", ctx);

    mut payload_resource_generic_resolution := typechecker.make_type_struct("ResolverPayload", "", ctx);
    mut args_resource_generic_resolution: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    args_resource_generic_resolution.Push(payload_resource_generic_resolution);
    mut unresolved_resource_generic_resolution := typechecker.make_type_generic("Resource", args_resource_generic_resolution, ctx);

    mut resolved_resource_generic_resolution := typechecker.env_resolve_type(&env_resource_generic_resolution, unresolved_resource_generic_resolution, ctx);
    if typechecker.type_is_resource(resolved_resource_generic_resolution, ctx) != 1 {
        os.LogStr("Error: env_resolve_type did not preserve Resource generic shape");
        os.Exit(1);
    }
    if std.str_eq(typechecker.resource_type_payload_struct_name(resolved_resource_generic_resolution, ctx), "main__ResolverPayload") == 0 {
        os.LogStr("Error: env_resolve_type did not resolve Resource payload struct name");
        os.Exit(1);
    }
    if typechecker.resource_type_payload_is_resource_tracking_eligible(&env_resource_generic_resolution, resolved_resource_generic_resolution, ctx) != 1 {
        os.LogStr("Error: resolved Resource payload was not resource-tracking eligible");
        os.Exit(1);
    }
    if typechecker.env_register_open_resource_value(&env_resource_generic_resolution, "resolved_resource_value", resolved_resource_generic_resolution, ctx) != 1 {
        os.LogStr("Error: resolved Resource value did not enter open_linear_resources registry");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_owned(&env_resource_generic_resolution, "resolved_resource_value", ctx) != 1 {
        os.LogStr("Error: resolved Resource value did not start owned");
        os.Exit(1);
    }
    if std.str_eq(typechecker.env_open_linear_resource_destructor_name(&env_resource_generic_resolution, "resolved_resource_value", ctx), "close_resolver_payload") == 0 {
        os.LogStr("Error: resolved Resource value did not preserve destructor identity");
        os.Exit(1);
    }

    mut primitive_resource_payload_resolution := typechecker.make_type_int();
    mut primitive_args_resource_resolution: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    primitive_args_resource_resolution.Push(primitive_resource_payload_resolution);
    mut primitive_generic_resource_resolution := typechecker.make_type_generic("Resource", primitive_args_resource_resolution, ctx);
    mut resolved_primitive_resource_resolution := typechecker.env_resolve_type(&env_resource_generic_resolution, primitive_generic_resource_resolution, ctx);
    if typechecker.type_is_resource(resolved_primitive_resource_resolution, ctx) != 1 {
        os.LogStr("Error: Resource[Int] should remain a Resource type shape after resolution");
        os.Exit(1);
    }
    if len(typechecker.resource_type_payload_struct_name(resolved_primitive_resource_resolution, ctx)) != 0 {
        os.LogStr("Error: Resource[Int] payload struct-name helper must remain empty after resolution");
        os.Exit(1);
    }
    if typechecker.env_register_open_resource_value(&env_resource_generic_resolution, "primitive_resource_value", resolved_primitive_resource_resolution, ctx) != 0 {
        os.LogStr("Error: Resource[Int] must not enter open_linear_resources registry after resolution");
        os.Exit(1);
    }

    if len(env_resource_generic_resolution.errors) != 0 {
        os.LogStr("Error: one-payload Resource generic resolution must not require a monomorphized Resource template");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert Resource generic resolver bridge verified!");
}
