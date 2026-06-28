import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_destructor_meta := typechecker.env_new(ctx);

    typechecker.env_register_struct_linear_metadata(&env_destructor_meta, "main__PlainDestructorMetadata", 0, ctx);
    if typechecker.env_struct_is_linear_resource(&env_destructor_meta, "main__PlainDestructorMetadata", ctx) != 0 {
        os.LogStr("Error: ordinary struct must remain non-linear after inert destructor metadata setup");
        os.Exit(1);
    }
    if typechecker.env_struct_has_linear_destructor(&env_destructor_meta, "main__PlainDestructorMetadata", ctx) != 0 {
        os.LogStr("Error: ordinary struct must not have destructor metadata before registration");
        os.Exit(1);
    }
    if typechecker.env_struct_has_resource_tracking_metadata(&env_destructor_meta, "main__PlainDestructorMetadata", ctx) != 0 {
        os.LogStr("Error: ordinary struct must not enter resource tracking without linear or destructor metadata");
        os.Exit(1);
    }

    typechecker.env_register_struct_linear_metadata(&env_destructor_meta, "main__LinearDestructorMetadata", 1, ctx);
    if typechecker.env_struct_is_linear_resource(&env_destructor_meta, "main__LinearDestructorMetadata", ctx) != 1 {
        os.LogStr("Error: linear metadata must remain enabled before destructor registration");
        os.Exit(1);
    }
    if typechecker.env_struct_has_resource_tracking_metadata(&env_destructor_meta, "main__LinearDestructorMetadata", ctx) != 1 {
        os.LogStr("Error: linear metadata must make resource tracking metadata visible");
        os.Exit(1);
    }
    if typechecker.env_struct_has_linear_destructor(&env_destructor_meta, "main__LinearDestructorMetadata", ctx) != 0 {
        os.LogStr("Error: linear metadata alone must not invent destructor identity");
        os.Exit(1);
    }

    typechecker.env_register_struct_linear_destructor(&env_destructor_meta, "main__LinearDestructorMetadata", "close_linear_destructor_metadata", ctx);
    if typechecker.env_struct_has_linear_destructor(&env_destructor_meta, "main__LinearDestructorMetadata", ctx) != 1 {
        os.LogStr("Error: linear destructor metadata predicate failed");
        os.Exit(1);
    }
    if std.str_eq(typechecker.env_struct_linear_destructor_name(&env_destructor_meta, "main__LinearDestructorMetadata", ctx), "close_linear_destructor_metadata") == 0 {
        os.LogStr("Error: linear destructor metadata lookup returned wrong destructor name");
        os.Exit(1);
    }
    if typechecker.env_struct_has_resource_tracking_metadata(&env_destructor_meta, "main__LinearDestructorMetadata", ctx) != 1 {
        os.LogStr("Error: destructor metadata must keep resource tracking metadata visible");
        os.Exit(1);
    }

    typechecker.env_register_struct_linear_destructor(&env_destructor_meta, "main__DestructorOnlyMetadata", "close_destructor_only_metadata", ctx);
    if typechecker.env_struct_is_linear_resource(&env_destructor_meta, "main__DestructorOnlyMetadata", ctx) != 0 {
        os.LogStr("Error: destructor registration alone must not mutate #[linear] metadata");
        os.Exit(1);
    }
    if typechecker.env_struct_has_linear_destructor(&env_destructor_meta, "main__DestructorOnlyMetadata", ctx) != 1 {
        os.LogStr("Error: destructor-only metadata predicate failed");
        os.Exit(1);
    }
    if typechecker.env_struct_has_resource_tracking_metadata(&env_destructor_meta, "main__DestructorOnlyMetadata", ctx) != 1 {
        os.LogStr("Error: destructor-only metadata must be resource-tracking eligible");
        os.Exit(1);
    }

    if typechecker.env_struct_has_linear_destructor(&env_destructor_meta, "main__MissingDestructorMetadata", ctx) != 0 {
        os.LogStr("Error: missing destructor metadata must default to disabled");
        os.Exit(1);
    }
    if std.str_eq(typechecker.env_struct_linear_destructor_name(&env_destructor_meta, "main__MissingDestructorMetadata", ctx), "") == 0 {
        os.LogStr("Error: missing destructor metadata name must default to empty string");
        os.Exit(1);
    }
    if typechecker.env_struct_has_resource_tracking_metadata(&env_destructor_meta, "main__MissingDestructorMetadata", ctx) != 0 {
        os.LogStr("Error: missing resource metadata must not be resource-tracking eligible");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert linear destructor metadata verified!");
}