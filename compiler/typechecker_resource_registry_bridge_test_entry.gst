import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_resource_bridge := typechecker.env_new(ctx);

    typechecker.env_register_struct_linear_metadata(&env_resource_bridge, "main__BridgeLinearPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_resource_bridge, "main__BridgeLinearPayload", "close_bridge_linear_payload", ctx);
    typechecker.env_register_struct_linear_metadata(&env_resource_bridge, "main__BridgePlainPayload", 0, ctx);

    mut linear_payload_resource_bridge := typechecker.make_type_struct("main__BridgeLinearPayload", "", ctx);
    mut linear_resource_bridge := typechecker.make_type_resource(linear_payload_resource_bridge, ctx);

    if std.str_eq(typechecker.resource_type_payload_struct_name(linear_resource_bridge, ctx), "main__BridgeLinearPayload") == 0 {
        os.LogStr("Error: Resource payload struct-name helper failed for linear payload");
        os.Exit(1);
    }
    if typechecker.resource_type_payload_is_resource_tracking_eligible(&env_resource_bridge, linear_resource_bridge, ctx) != 1 {
        os.LogStr("Error: Resource payload eligibility helper failed for linear payload");
        os.Exit(1);
    }

    mut registered_linear_resource_bridge := typechecker.env_register_open_resource_value(&env_resource_bridge, "linear_resource_bridge", linear_resource_bridge, ctx);
    if registered_linear_resource_bridge != 1 {
        os.LogStr("Error: Resource[linear payload] value did not enter open_linear_resources registry");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_tracked(&env_resource_bridge, "linear_resource_bridge", ctx) != 1 {
        os.LogStr("Error: Resource[linear payload] tracking predicate failed");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_owned(&env_resource_bridge, "linear_resource_bridge", ctx) != 1 {
        os.LogStr("Error: Resource[linear payload] value must start in owned state");
        os.Exit(1);
    }
    if std.str_eq(typechecker.env_open_linear_resource_destructor_name(&env_resource_bridge, "linear_resource_bridge", ctx), "close_bridge_linear_payload") == 0 {
        os.LogStr("Error: Resource[linear payload] registration did not preserve payload destructor identity");
        os.Exit(1);
    }

    mut plain_payload_resource_bridge := typechecker.make_type_struct("main__BridgePlainPayload", "", ctx);
    mut plain_resource_bridge := typechecker.make_type_resource(plain_payload_resource_bridge, ctx);

    if typechecker.resource_type_payload_is_resource_tracking_eligible(&env_resource_bridge, plain_resource_bridge, ctx) != 0 {
        os.LogStr("Error: Resource[plain payload] must not be resource-tracking eligible");
        os.Exit(1);
    }
    if typechecker.env_register_open_resource_value(&env_resource_bridge, "plain_resource_bridge", plain_resource_bridge, ctx) != 0 {
        os.LogStr("Error: Resource[plain payload] must not enter open_linear_resources registry");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_tracked(&env_resource_bridge, "plain_resource_bridge", ctx) != 0 {
        os.LogStr("Error: Resource[plain payload] was tracked despite missing linear/destructor metadata");
        os.Exit(1);
    }

    mut missing_payload_resource_bridge := typechecker.make_type_struct("main__BridgeMissingPayload", "", ctx);
    mut missing_resource_bridge := typechecker.make_type_resource(missing_payload_resource_bridge, ctx);

    if typechecker.resource_type_payload_is_resource_tracking_eligible(&env_resource_bridge, missing_resource_bridge, ctx) != 0 {
        os.LogStr("Error: Resource[missing metadata payload] must not be resource-tracking eligible");
        os.Exit(1);
    }
    if typechecker.env_register_open_resource_value(&env_resource_bridge, "missing_resource_bridge", missing_resource_bridge, ctx) != 0 {
        os.LogStr("Error: Resource[missing metadata payload] must not enter open_linear_resources registry");
        os.Exit(1);
    }

    mut primitive_payload_resource_bridge := typechecker.make_type_int();
    mut primitive_resource_bridge := typechecker.make_type_resource(primitive_payload_resource_bridge, ctx);

    if len(typechecker.resource_type_payload_struct_name(primitive_resource_bridge, ctx)) != 0 {
        os.LogStr("Error: Resource[Int] payload struct-name helper must default to empty string");
        os.Exit(1);
    }
    if typechecker.resource_type_payload_is_resource_tracking_eligible(&env_resource_bridge, primitive_resource_bridge, ctx) != 0 {
        os.LogStr("Error: Resource[Int] must not be resource-tracking eligible");
        os.Exit(1);
    }
    if typechecker.env_register_open_resource_value(&env_resource_bridge, "primitive_resource_bridge", primitive_resource_bridge, ctx) != 0 {
        os.LogStr("Error: Resource[Int] must not enter open_linear_resources registry");
        os.Exit(1);
    }

    if len(typechecker.resource_type_payload_struct_name(linear_payload_resource_bridge, ctx)) != 0 {
        os.LogStr("Error: non-Resource struct payload-name helper must default to empty string");
        os.Exit(1);
    }
    if typechecker.resource_type_payload_is_resource_tracking_eligible(&env_resource_bridge, linear_payload_resource_bridge, ctx) != 0 {
        os.LogStr("Error: non-Resource type must not be resource-tracking eligible through Resource helper");
        os.Exit(1);
    }
    if typechecker.env_register_open_resource_value(&env_resource_bridge, "non_resource_bridge", linear_payload_resource_bridge, ctx) != 0 {
        os.LogStr("Error: non-Resource value must not enter open_linear_resources registry through Resource helper");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert Resource registry bridge helpers verified!");
}