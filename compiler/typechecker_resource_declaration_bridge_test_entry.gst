import "ast.gst" as ast;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_resource_declaration := typechecker.env_new(ctx);

    typechecker.env_register_struct_linear_metadata(&env_resource_declaration, "main__DeclarationPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_resource_declaration, "main__DeclarationPayload", "close_declaration_payload", ctx);
    typechecker.env_register_struct_linear_metadata(&env_resource_declaration, "main__DeclarationPlainPayload", 0, ctx);

    mut payload_struct_resource_declaration := typechecker.make_type_struct("main__DeclarationPayload", "", ctx);
    mut resource_type_resource_declaration := typechecker.make_type_resource(payload_struct_resource_declaration, ctx);
    env_resource_declaration.variable_types.Insert(std.Clone(ctx, "declared_resource_value"), resource_type_resource_declaration);

    if typechecker.env_resource_variable_type_is_resource(&env_resource_declaration, "declared_resource_value", ctx) != 1 {
        os.LogStr("Error: Resource declaration helper did not recognize Resource variable type");
        os.Exit(1);
    }
    if std.str_eq(typechecker.env_resource_variable_payload_struct_name(&env_resource_declaration, "declared_resource_value", ctx), "main__DeclarationPayload") == 0 {
        os.LogStr("Error: Resource declaration helper did not expose payload struct name");
        os.Exit(1);
    }
    if typechecker.env_resource_variable_is_tracking_eligible(&env_resource_declaration, "declared_resource_value", ctx) != 1 {
        os.LogStr("Error: Resource declaration helper did not see tracking-eligible payload");
        os.Exit(1);
    }
    if typechecker.env_register_open_resource_declaration(&env_resource_declaration, "declared_resource_value", ctx) != 1 {
        os.LogStr("Error: Resource declaration helper did not register open resource value");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_owned(&env_resource_declaration, "declared_resource_value", ctx) != 1 {
        os.LogStr("Error: registered Resource declaration did not start owned");
        os.Exit(1);
    }
    if std.str_eq(typechecker.env_open_linear_resource_destructor_name(&env_resource_declaration, "declared_resource_value", ctx), "close_declaration_payload") == 0 {
        os.LogStr("Error: registered Resource declaration did not preserve destructor identity");
        os.Exit(1);
    }

    mut primitive_payload_resource_declaration := typechecker.make_type_int();
    mut primitive_resource_type_declaration := typechecker.make_type_resource(primitive_payload_resource_declaration, ctx);
    env_resource_declaration.variable_types.Insert(std.Clone(ctx, "primitive_resource_value"), primitive_resource_type_declaration);

    if typechecker.env_resource_variable_type_is_resource(&env_resource_declaration, "primitive_resource_value", ctx) != 1 {
        os.LogStr("Error: Resource[Int] declaration should still be recognized as Resource shape");
        os.Exit(1);
    }
    if len(typechecker.env_resource_variable_payload_struct_name(&env_resource_declaration, "primitive_resource_value", ctx)) != 0 {
        os.LogStr("Error: Resource[Int] declaration must not expose payload struct name");
        os.Exit(1);
    }
    if typechecker.env_resource_variable_is_tracking_eligible(&env_resource_declaration, "primitive_resource_value", ctx) != 0 {
        os.LogStr("Error: Resource[Int] declaration must not be tracking eligible");
        os.Exit(1);
    }
    if typechecker.env_register_open_resource_declaration(&env_resource_declaration, "primitive_resource_value", ctx) != 0 {
        os.LogStr("Error: Resource[Int] declaration must not enter open_linear_resources registry");
        os.Exit(1);
    }

    mut plain_payload_struct_declaration := typechecker.make_type_struct("main__DeclarationPlainPayload", "", ctx);
    mut plain_resource_type_declaration := typechecker.make_type_resource(plain_payload_struct_declaration, ctx);
    env_resource_declaration.variable_types.Insert(std.Clone(ctx, "plain_resource_value"), plain_resource_type_declaration);

    if typechecker.env_resource_variable_is_tracking_eligible(&env_resource_declaration, "plain_resource_value", ctx) != 0 {
        os.LogStr("Error: Resource[plain payload] declaration must not be tracking eligible");
        os.Exit(1);
    }
    if typechecker.env_register_open_resource_declaration(&env_resource_declaration, "plain_resource_value", ctx) != 0 {
        os.LogStr("Error: Resource[plain payload] declaration must not enter open_linear_resources registry");
        os.Exit(1);
    }

    env_resource_declaration.variable_types.Insert(std.Clone(ctx, "plain_struct_value"), payload_struct_resource_declaration);
    if typechecker.env_resource_variable_type_is_resource(&env_resource_declaration, "plain_struct_value", ctx) != 0 {
        os.LogStr("Error: non-Resource struct declaration must not be recognized as Resource variable type");
        os.Exit(1);
    }
    if typechecker.env_register_open_resource_declaration(&env_resource_declaration, "plain_struct_value", ctx) != 0 {
        os.LogStr("Error: non-Resource struct declaration must not enter open_linear_resources registry through Resource helper");
        os.Exit(1);
    }

    mut legacy_args_resource_declaration: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    legacy_args_resource_declaration.Push(typechecker.make_type_str());
    legacy_args_resource_declaration.Push(typechecker.make_type_struct("ctx", "", ctx));
    mut legacy_generic_resource_declaration := typechecker.make_type_generic("Resource", legacy_args_resource_declaration, ctx);
    env_resource_declaration.variable_types.Insert(std.Clone(ctx, "legacy_resource_value"), legacy_generic_resource_declaration);

    if typechecker.env_resource_variable_type_is_resource(&env_resource_declaration, "legacy_resource_value", ctx) != 0 {
        os.LogStr("Error: legacy multi-arg Resource template must not be treated as one-payload Resource declaration");
        os.Exit(1);
    }
    if typechecker.env_register_open_resource_declaration(&env_resource_declaration, "legacy_resource_value", ctx) != 0 {
        os.LogStr("Error: legacy multi-arg Resource template must keep normal non-linear declaration behavior");
        os.Exit(1);
    }

    if typechecker.env_resource_variable_type_is_resource(&env_resource_declaration, "missing_resource_value", ctx) != 0 {
        os.LogStr("Error: missing declaration must not be recognized as Resource variable type");
        os.Exit(1);
    }
    if typechecker.env_resource_variable_is_tracking_eligible(&env_resource_declaration, "missing_resource_value", ctx) != 0 {
        os.LogStr("Error: missing declaration must not be tracking eligible");
        os.Exit(1);
    }
    if typechecker.env_register_open_resource_declaration(&env_resource_declaration, "missing_resource_value", ctx) != 0 {
        os.LogStr("Error: missing declaration must not enter open_linear_resources registry");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert Resource declaration helper bridge verified!");
}