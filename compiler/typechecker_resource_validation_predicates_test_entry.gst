import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_validation_predicates := typechecker.env_new(ctx);

    typechecker.env_register_struct_linear_metadata(&env_validation_predicates, "main__ValidationPredicateResource", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_validation_predicates, "main__ValidationPredicateResource", "close_validation_predicate_resource", ctx);
    typechecker.env_register_struct_linear_metadata(&env_validation_predicates, "main__ValidationPredicateNoDestructorResource", 1, ctx);

    typechecker.env_register_open_linear_resource(&env_validation_predicates, "owned_validation_resource", "main__ValidationPredicateResource", ctx);
    if typechecker.env_open_linear_resource_can_be_used(&env_validation_predicates, "owned_validation_resource", ctx) != 1 {
        os.LogStr("Error: owned resource must be usable in inert validation predicates");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_can_be_closed(&env_validation_predicates, "owned_validation_resource", ctx) != 1 {
        os.LogStr("Error: owned resource must be closeable in inert validation predicates");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_can_be_moved(&env_validation_predicates, "owned_validation_resource", ctx) != 1 {
        os.LogStr("Error: owned resource must be movable in inert validation predicates");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_requires_cleanup(&env_validation_predicates, "owned_validation_resource", ctx) != 1 {
        os.LogStr("Error: owned resource must require cleanup in inert validation predicates");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_can_schedule_destructor(&env_validation_predicates, "owned_validation_resource", ctx) != 1 {
        os.LogStr("Error: owned resource with destructor must be destructor-schedulable");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_has_terminal_state(&env_validation_predicates, "owned_validation_resource", ctx) != 0 {
        os.LogStr("Error: owned resource must not start in terminal state");
        os.Exit(1);
    }

    typechecker.env_register_open_linear_resource(&env_validation_predicates, "borrowed_validation_resource", "main__ValidationPredicateResource", ctx);
    typechecker.env_mark_open_linear_resource_borrowed(&env_validation_predicates, "borrowed_validation_resource", ctx);
    if typechecker.env_open_linear_resource_can_be_used(&env_validation_predicates, "borrowed_validation_resource", ctx) != 1 {
        os.LogStr("Error: borrowed resource should remain usable in inert validation predicates");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_can_be_closed(&env_validation_predicates, "borrowed_validation_resource", ctx) != 0 {
        os.LogStr("Error: borrowed resource must not be closeable by owned-only predicate");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_can_be_moved(&env_validation_predicates, "borrowed_validation_resource", ctx) != 0 {
        os.LogStr("Error: borrowed resource must not be movable by owned-only predicate");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_requires_cleanup(&env_validation_predicates, "borrowed_validation_resource", ctx) != 0 {
        os.LogStr("Error: borrowed resource must not require owned cleanup");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_can_schedule_destructor(&env_validation_predicates, "borrowed_validation_resource", ctx) != 0 {
        os.LogStr("Error: borrowed resource must not schedule destructor through owned-only predicate");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_has_terminal_state(&env_validation_predicates, "borrowed_validation_resource", ctx) != 0 {
        os.LogStr("Error: borrowed resource must not be terminal");
        os.Exit(1);
    }

    typechecker.env_register_open_linear_resource(&env_validation_predicates, "moved_validation_resource", "main__ValidationPredicateResource", ctx);
    typechecker.env_mark_open_linear_resource_moved(&env_validation_predicates, "moved_validation_resource", ctx);
    if typechecker.env_open_linear_resource_can_be_used(&env_validation_predicates, "moved_validation_resource", ctx) != 0 {
        os.LogStr("Error: moved resource must not be usable");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_can_be_closed(&env_validation_predicates, "moved_validation_resource", ctx) != 0 {
        os.LogStr("Error: moved resource must not be closeable");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_can_be_moved(&env_validation_predicates, "moved_validation_resource", ctx) != 0 {
        os.LogStr("Error: moved resource must not be movable again");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_requires_cleanup(&env_validation_predicates, "moved_validation_resource", ctx) != 0 {
        os.LogStr("Error: moved resource must not require cleanup from old owner");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_can_schedule_destructor(&env_validation_predicates, "moved_validation_resource", ctx) != 0 {
        os.LogStr("Error: moved resource must not schedule destructor from old owner");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_has_terminal_state(&env_validation_predicates, "moved_validation_resource", ctx) != 1 {
        os.LogStr("Error: moved resource must be terminal");
        os.Exit(1);
    }

    typechecker.env_register_open_linear_resource(&env_validation_predicates, "closed_validation_resource", "main__ValidationPredicateResource", ctx);
    typechecker.env_mark_open_linear_resource_closed(&env_validation_predicates, "closed_validation_resource", ctx);
    if typechecker.env_open_linear_resource_can_be_used(&env_validation_predicates, "closed_validation_resource", ctx) != 0 {
        os.LogStr("Error: closed resource must not be usable");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_has_terminal_state(&env_validation_predicates, "closed_validation_resource", ctx) != 1 {
        os.LogStr("Error: closed resource must be terminal");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_requires_cleanup(&env_validation_predicates, "closed_validation_resource", ctx) != 0 {
        os.LogStr("Error: closed resource must not require cleanup");
        os.Exit(1);
    }

    typechecker.env_register_open_linear_resource(&env_validation_predicates, "scheduled_validation_resource", "main__ValidationPredicateResource", ctx);
    typechecker.env_mark_open_linear_resource_destructor_scheduled(&env_validation_predicates, "scheduled_validation_resource", ctx);
    if typechecker.env_open_linear_resource_can_be_used(&env_validation_predicates, "scheduled_validation_resource", ctx) != 0 {
        os.LogStr("Error: destructor-scheduled resource must not be usable");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_has_terminal_state(&env_validation_predicates, "scheduled_validation_resource", ctx) != 1 {
        os.LogStr("Error: destructor-scheduled resource must be terminal");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_can_schedule_destructor(&env_validation_predicates, "scheduled_validation_resource", ctx) != 0 {
        os.LogStr("Error: destructor-scheduled resource must not schedule destructor twice");
        os.Exit(1);
    }

    typechecker.env_register_open_linear_resource(&env_validation_predicates, "no_destructor_validation_resource", "main__ValidationPredicateNoDestructorResource", ctx);
    if typechecker.env_open_linear_resource_can_be_used(&env_validation_predicates, "no_destructor_validation_resource", ctx) != 1 {
        os.LogStr("Error: linear resource without destructor metadata should remain usable");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_can_schedule_destructor(&env_validation_predicates, "no_destructor_validation_resource", ctx) != 0 {
        os.LogStr("Error: resource without destructor identity must not be destructor-schedulable");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_requires_cleanup(&env_validation_predicates, "no_destructor_validation_resource", ctx) != 1 {
        os.LogStr("Error: owned linear resource without destructor identity still requires future cleanup design attention");
        os.Exit(1);
    }

    if typechecker.env_open_linear_resource_can_be_used(&env_validation_predicates, "missing_validation_resource", ctx) != 0 {
        os.LogStr("Error: missing resource must not be usable");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_can_be_closed(&env_validation_predicates, "missing_validation_resource", ctx) != 0 {
        os.LogStr("Error: missing resource must not be closeable");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_can_be_moved(&env_validation_predicates, "missing_validation_resource", ctx) != 0 {
        os.LogStr("Error: missing resource must not be movable");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_requires_cleanup(&env_validation_predicates, "missing_validation_resource", ctx) != 0 {
        os.LogStr("Error: missing resource must not require cleanup");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_can_schedule_destructor(&env_validation_predicates, "missing_validation_resource", ctx) != 0 {
        os.LogStr("Error: missing resource must not schedule destructor");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_has_terminal_state(&env_validation_predicates, "missing_validation_resource", ctx) != 0 {
        os.LogStr("Error: missing resource must not be terminal");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert linear resource validation predicates verified!");
}