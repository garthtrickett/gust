import "ast.gst" as ast;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_scheduled := typechecker.env_new(ctx);
    env_scheduled.current_prefix = "main__";
    mut scope_scheduled := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_scheduled, "main__ScheduledPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_scheduled, "main__ScheduledPayload", "main__close_scheduled_payload", ctx);
    typechecker.env_register_open_linear_resource(&env_scheduled, "main__scheduled_resource", "main__ScheduledPayload", ctx);

    if typechecker.env_try_schedule_open_linear_resource_destructor(&env_scheduled, "main__scheduled_resource", ctx) != 1 {
        os.LogStr("Error: scheduled-resource fixture failed to schedule destructor");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_destructor_scheduled(&env_scheduled, "main__scheduled_resource", ctx) != 1 {
        os.LogStr("Error: scheduled-resource fixture must start destructor-scheduled");
        os.Exit(1);
    }

    mut span_scheduled: token.Span;
    mut close_arg_expr_scheduled: ast.Expression[ctx];
    unsafe {
        close_arg_expr_scheduled.tag = 0; // Identifier
        close_arg_expr_scheduled.Identifier.name = "scheduled_resource";
        close_arg_expr_scheduled.Identifier.span = span_scheduled;
    }
    mut close_args_scheduled: std.Vector[ast.Expression[ctx], ctx] := std.VectorNew(ctx);
    close_args_scheduled.Push(close_arg_expr_scheduled);
    mut close_args_idx_scheduled: Index[std.Vector[ast.Expression[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(close_args_idx_scheduled, close_args_scheduled);

    if typechecker.env_track_resource_destructor_call_if_applicable(&env_scheduled, "main__close_scheduled_payload", close_args_idx_scheduled, scope_scheduled, ctx) != 0 {
        os.LogStr("Error: destructor call must not close a destructor-scheduled tracked resource");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_destructor_scheduled(&env_scheduled, "main__scheduled_resource", ctx) != 1 {
        os.LogStr("Error: rejected destructor-scheduled close must leave scheduled state intact");
        os.Exit(1);
    }
    if len(env_scheduled.errors) == 0 {
        os.LogStr("Error: destructor call on scheduled resource must report LinearResourceDestructorAlreadyScheduled");
        os.Exit(1);
    }
    if std.str_find(env_scheduled.errors[0].message, "LinearResourceDestructorAlreadyScheduled") == 0 - 1 {
        os.LogStr("Error: destructor call on scheduled resource emitted wrong diagnostic");
        os.LogStr(env_scheduled.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource destructor-scheduled rejection verified!");
}