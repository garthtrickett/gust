import "ast.gst" as ast;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_resource_assignment := typechecker.env_new(ctx);

    typechecker.env_register_struct_linear_metadata(&env_resource_assignment, "main__AssignmentPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_resource_assignment, "main__AssignmentPayload", "close_assignment_payload", ctx);
    typechecker.env_register_struct_linear_metadata(&env_resource_assignment, "main__AssignmentOtherPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_resource_assignment, "main__AssignmentOtherPayload", "close_assignment_other_payload", ctx);
    typechecker.env_register_struct_linear_metadata(&env_resource_assignment, "main__AssignmentPlainPayload", 0, ctx);

    mut assignment_payload_struct := typechecker.make_type_struct("main__AssignmentPayload", "", ctx);
    mut assignment_resource_type := typechecker.make_type_resource(assignment_payload_struct, ctx);
    env_resource_assignment.variable_types.Insert(std.Clone(ctx, "assignment_resource_value"), assignment_resource_type);

    if typechecker.env_resource_assignment_type_matches_declaration(&env_resource_assignment, "assignment_resource_value", assignment_resource_type, ctx) != 1 {
        os.LogStr("Error: Resource assignment helper did not match identical Resource declaration");
        os.Exit(1);
    }
    if typechecker.env_resource_assignment_is_tracking_eligible(&env_resource_assignment, "assignment_resource_value", assignment_resource_type, ctx) != 1 {
        os.LogStr("Error: Resource assignment helper did not see eligible assigned Resource");
        os.Exit(1);
    }
    if typechecker.env_register_open_resource_assignment(&env_resource_assignment, "assignment_resource_value", assignment_resource_type, ctx) != 1 {
        os.LogStr("Error: Resource assignment helper did not register matching Resource value");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_owned(&env_resource_assignment, "assignment_resource_value", ctx) != 1 {
        os.LogStr("Error: registered Resource assignment did not start owned");
        os.Exit(1);
    }
    if std.str_eq(typechecker.env_open_linear_resource_destructor_name(&env_resource_assignment, "assignment_resource_value", ctx), "close_assignment_payload") == 0 {
        os.LogStr("Error: registered Resource assignment did not preserve destructor identity");
        os.Exit(1);
    }

    mut other_assignment_payload_struct := typechecker.make_type_struct("main__AssignmentOtherPayload", "", ctx);
    mut other_assignment_resource_type := typechecker.make_type_resource(other_assignment_payload_struct, ctx);

    if typechecker.env_resource_assignment_type_matches_declaration(&env_resource_assignment, "assignment_resource_value", other_assignment_resource_type, ctx) != 0 {
        os.LogStr("Error: Resource assignment helper must reject mismatched payload type");
        os.Exit(1);
    }
    if typechecker.env_resource_assignment_is_tracking_eligible(&env_resource_assignment, "assignment_resource_value", other_assignment_resource_type, ctx) != 0 {
        os.LogStr("Error: mismatched Resource assignment must not be tracking eligible");
        os.Exit(1);
    }
    if typechecker.env_register_open_resource_assignment(&env_resource_assignment, "assignment_resource_value", other_assignment_resource_type, ctx) != 0 {
        os.LogStr("Error: mismatched Resource assignment must not enter open_linear_resources registry");
        os.Exit(1);
    }

    mut primitive_assignment_payload := typechecker.make_type_int();
    mut primitive_assignment_resource_type := typechecker.make_type_resource(primitive_assignment_payload, ctx);
    env_resource_assignment.variable_types.Insert(std.Clone(ctx, "primitive_assignment_resource_value"), primitive_assignment_resource_type);

    if typechecker.env_resource_assignment_type_matches_declaration(&env_resource_assignment, "primitive_assignment_resource_value", primitive_assignment_resource_type, ctx) != 1 {
        os.LogStr("Error: Resource[Int] assignment should match its declaration shape");
        os.Exit(1);
    }
    if typechecker.env_resource_assignment_is_tracking_eligible(&env_resource_assignment, "primitive_assignment_resource_value", primitive_assignment_resource_type, ctx) != 0 {
        os.LogStr("Error: Resource[Int] assignment must not be tracking eligible");
        os.Exit(1);
    }
    if typechecker.env_register_open_resource_assignment(&env_resource_assignment, "primitive_assignment_resource_value", primitive_assignment_resource_type, ctx) != 0 {
        os.LogStr("Error: Resource[Int] assignment must not enter open_linear_resources registry");
        os.Exit(1);
    }

    mut plain_assignment_payload_struct := typechecker.make_type_struct("main__AssignmentPlainPayload", "", ctx);
    mut plain_assignment_resource_type := typechecker.make_type_resource(plain_assignment_payload_struct, ctx);
    env_resource_assignment.variable_types.Insert(std.Clone(ctx, "plain_assignment_resource_value"), plain_assignment_resource_type);

    if typechecker.env_resource_assignment_type_matches_declaration(&env_resource_assignment, "plain_assignment_resource_value", plain_assignment_resource_type, ctx) != 1 {
        os.LogStr("Error: Resource[plain payload] assignment should match its declaration shape");
        os.Exit(1);
    }
    if typechecker.env_resource_assignment_is_tracking_eligible(&env_resource_assignment, "plain_assignment_resource_value", plain_assignment_resource_type, ctx) != 0 {
        os.LogStr("Error: Resource[plain payload] assignment must not be tracking eligible");
        os.Exit(1);
    }
    if typechecker.env_register_open_resource_assignment(&env_resource_assignment, "plain_assignment_resource_value", plain_assignment_resource_type, ctx) != 0 {
        os.LogStr("Error: Resource[plain payload] assignment must not enter open_linear_resources registry");
        os.Exit(1);
    }

    env_resource_assignment.variable_types.Insert(std.Clone(ctx, "plain_struct_assignment_value"), assignment_payload_struct);
    if typechecker.env_resource_assignment_type_matches_declaration(&env_resource_assignment, "plain_struct_assignment_value", assignment_resource_type, ctx) != 0 {
        os.LogStr("Error: non-Resource declaration must not match Resource assignment helper");
        os.Exit(1);
    }
    if typechecker.env_register_open_resource_assignment(&env_resource_assignment, "plain_struct_assignment_value", assignment_resource_type, ctx) != 0 {
        os.LogStr("Error: non-Resource declaration must not register Resource assignment");
        os.Exit(1);
    }

    mut legacy_assignment_args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    legacy_assignment_args.Push(typechecker.make_type_str());
    legacy_assignment_args.Push(typechecker.make_type_struct("ctx", "", ctx));
    mut legacy_assignment_resource_type := typechecker.make_type_generic("Resource", legacy_assignment_args, ctx);
    env_resource_assignment.variable_types.Insert(std.Clone(ctx, "legacy_assignment_resource_value"), legacy_assignment_resource_type);

    if typechecker.env_resource_assignment_type_matches_declaration(&env_resource_assignment, "legacy_assignment_resource_value", legacy_assignment_resource_type, ctx) != 0 {
        os.LogStr("Error: legacy multi-arg Resource template must not match one-payload Resource assignment helper");
        os.Exit(1);
    }
    if typechecker.env_register_open_resource_assignment(&env_resource_assignment, "legacy_assignment_resource_value", legacy_assignment_resource_type, ctx) != 0 {
        os.LogStr("Error: legacy multi-arg Resource template must keep normal assignment behavior");
        os.Exit(1);
    }

    if typechecker.env_resource_assignment_type_matches_declaration(&env_resource_assignment, "missing_assignment_resource_value", assignment_resource_type, ctx) != 0 {
        os.LogStr("Error: missing declaration must not match Resource assignment helper");
        os.Exit(1);
    }
    if typechecker.env_register_open_resource_assignment(&env_resource_assignment, "missing_assignment_resource_value", assignment_resource_type, ctx) != 0 {
        os.LogStr("Error: missing declaration must not register Resource assignment");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert Resource assignment helper bridge verified!");
}